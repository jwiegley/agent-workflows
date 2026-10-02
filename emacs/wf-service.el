;;; wf-service.el --- Service mode of wf.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 John Wiegley

;; Author: John Wiegley <johnw@newartisans.com>
;; Maintainer: John Wiegley <johnw@newartisans.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: tools, processes
;; URL: https://github.com/jwiegley/agent-workflows

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The service mode of `wf.el', in which the commands of `wf.el' are
;; clients of an agent-cat workflow manager through `wf-manager.el'.
;;
;; The mode is explicit.  Local mode is the default.  `wf-service'
;; selects one client profile of `wf-manager-profiles', binds a
;; connection to its manager and starts a session, which installs the
;; complete overview and follows the events of the manager in the
;; `poll' delivery.  `wf-local' closes that session and returns the
;; commands to local mode.  The close sends no command, so the runs and
;; requests of the manager continue.
;;
;; In service mode, each public interactive command of `wf.el' runs the
;; behavior that `wf-service-commands' states for it.  The private
;; commands of the local setup form have no entry, because only local
;; mode makes that form.  Service mode never
;; starts the `wf' binary or a local frontend worker, and it never reads
;; a file system path of the manager.  The table has three kinds of
;; entry:
;;
;;   service  The command has a manager behavior.  `wf-run' reads the
;;            catalogue of the manager, `wf-help' shows the help text of
;;            a catalogue workflow, and `wf-diagnostics' shows the
;;            diagnostics of the session.
;;   pending  The command has no manager behavior yet, and it refuses
;;            with a message that says so.
;;   local    The command reads the local runner or its store, and it
;;            refuses in service mode with a message that names the
;;            service equivalent when one exists.  It sends nothing.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'wf)
(require 'wf-manager)

(defcustom wf-manager-profiles nil
  "The client profile files of service mode.
Each item is the absolute name of a version 1 client profile of an
agent-cat workflow manager.  `wf-service' selects one of them.  The
list does not select service mode by itself: local mode stays the
default until `wf-service' runs."
  :type '(repeat (file :must-match t))
  :group 'wf)

(defconst wf-service-commands
  '((wf-run service wf-service--run)
    (wf-help service wf-service--help)
    (wf-diagnostics service wf-service--diagnostics)
    (wf-refresh pending)
    (wf-runs pending)
    (wf-answer pending)
    (wf-control pending)
    (wf-result pending)
    (wf-kill pending)
    (wf-history pending)
    (wf-history-refresh pending)
    (wf-history-open pending)
    (wf-restart pending)
    (wf-resume pending)
    (wf-fork pending)
    (wf-fork-submit pending)
    (wf-rerun pending)
    (wf-plan local "the review of `wf-run'")
    (wf-cost local "the review of `wf-run'")
    (wf-lineage-compare local nil)
    (wf-observer-result local nil)
    (wf-observer-refresh local nil))
  "The service behavior of each public interactive command of `wf.el'.
Each entry is (COMMAND KIND DETAIL).  KIND `service' runs the function
DETAIL with the arguments of COMMAND.  KIND `pending' refuses with the
message of `wf-service-refusal', because COMMAND has no manager
behavior yet.  KIND `local' refuses with that message too, and DETAIL is
the text that names the service equivalent of COMMAND, or nil when
there is none.  No refusal sends a request or starts a process.")

(cl-defstruct (wf-service--state
               (:constructor wf-service--state-make)
               (:copier nil))
  "The binding of service mode.
FILE is the client profile file of the current binding.  SESSION is
the `wf-manager-session'.  PROBLEM is the text of the last problem of
service mode, or nil."
  (file nil)
  (session nil)
  (problem nil))

(defvar wf-service--current nil
  "The `wf-service--state' of service mode, or nil in local mode.")

(defun wf-service-refusal (command)
  "Return the refusal message of COMMAND in service mode, or nil.
A COMMAND of kind `service' has no refusal."
  (pcase (alist-get command wf-service-commands)
    (`(pending)
     (format "%s is not yet available in service mode" command))
    (`(local ,equivalent)
     (if equivalent
         (format "%s works only in local mode.  In service mode, use %s instead"
                 command (substitute-command-keys equivalent))
       (format "%s works only in local mode.  Service mode has no equivalent"
               command)))))

(defun wf-service--dispatch (command &rest arguments)
  "Run the service behavior of COMMAND with ARGUMENTS.
`wf-service-commands' states the behavior.  A COMMAND outside that
table signals an error, because the table states every command."
  (pcase (alist-get command wf-service-commands)
    (`(service ,function) (apply function arguments))
    ((or `(pending) `(local ,_)) (user-error "%s" (wf-service-refusal command)))
    (_ (error "`wf-service-commands' states no behavior for %s" command))))


;;; Waiting for the manager

(defun wf-service--await (start)
  "Call START with a callback and return the one outcome of the callback.
START returns nil or a function of no arguments that cancels the
request.  The command waits for the outcome while timers and processes
run, and \\[keyboard-quit] ends the wait, after which the cancel
function runs."
  (let ((outcome nil) (done nil) (cancel nil))
    (unwind-protect
        (progn
          (setq cancel (funcall start (lambda (value) (setq outcome value done t))))
          (while (not done)
            (accept-process-output nil 0.05)))
      (when (and (not done) cancel)
        (funcall cancel)))
    outcome))

(defun wf-service--failure-text (failure)
  "Return the text of the manager FAILURE, a (CONDITION . DATA) list."
  (pcase failure
    (`(wf-manager-refused ,status ,code)
     (format "the manager refused with %s %s" status code))
    (`(,condition ,field ,reason)
     (format "%s (%s): %s" (or (get condition 'error-message) condition) field reason))
    (_ (format "%S" failure))))

(defun wf-service--problem (text)
  "Record TEXT as the last problem of service mode and return TEXT."
  (when wf-service--current
    (setf (wf-service--state-problem wf-service--current) text))
  text)

(defun wf-service--refuse (what failure)
  "For WHAT, record its FAILURE as the last problem and signal a `user-error'."
  (user-error "%s" (wf-service--problem
                    (format "%s: %s" what (wf-service--failure-text failure)))))


;;; Mode selection

(defun wf-service--read-profile-file ()
  "Read one file of `wf-manager-profiles' in the minibuffer."
  (unless wf-manager-profiles
    (user-error "Set `wf-manager-profiles' to the client profile files of service mode"))
  (completing-read (format-prompt "Client profile" (car wf-manager-profiles))
                   wf-manager-profiles nil t nil nil (car wf-manager-profiles)))

(defun wf-service--changed (session)
  "Record the delivery and the end of the follow loop of SESSION.
This is the change function of the session of service mode."
  (when (and wf-service--current
             (eq session (wf-service--state-session wf-service--current)))
    (pcase (wf-manager-session-follow-end session)
      (`(refused ,failure)
       (wf-service--problem (format "the follow loop ended: %s"
                                    (wf-service--failure-text failure))))
      (_ (when (eq (wf-manager-session-delivery session) 'unreachable)
           (wf-service--problem "a polling batch did not reach the manager"))))))

(defun wf-service--connect (profile)
  "Bind a connection for the loaded PROFILE and start its session.
Return the `wf-manager-session' after its first overview installed."
  (let* ((connection
          (condition-case failure
              (wf-service--await
               (lambda (callback)
                 (let ((exchange (wf-manager-connect profile callback)))
                   (lambda () (wf-manager-cancel exchange)))))
            (wf-manager-error (wf-service--refuse "The transport cannot open" failure)))))
    (when (wf-manager-failure-p connection)
      (wf-service--refuse "The manager cannot be reached" connection))
    (let* ((session nil)
           (overview (wf-service--await
                      (lambda (callback)
                        (setq session (wf-manager-session-start
                                       connection callback #'wf-service--changed))
                        (lambda () (wf-manager-session-close session))))))
      (when (wf-manager-failure-p overview)
        (wf-manager-session-close session)
        (wf-service--refuse "The overview of the manager cannot be read" overview))
      session)))

(defun wf-service--switch (state file profile)
  "Switch the session of STATE to FILE, whose loaded profile is PROFILE.
The session commits only after the complete overview of the new
binding loaded.  A switch that fails keeps the earlier binding."
  (let ((session (wf-service--state-session state)))
    (let ((outcome (wf-service--await
                    (lambda (callback)
                      (wf-manager-session-switch
                       session profile
                       (lambda (value)
                         (unless (wf-manager-failure-p value)
                           (setf (wf-service--state-file state) file))
                         (funcall callback value)))
                      nil))))
      (when (wf-manager-failure-p outcome)
        (wf-service--refuse (format "The switch to %s failed, and the earlier binding stays"
                                    file)
                            outcome)))))

;;;###autoload
(defun wf-service (file)
  "Select the client profile FILE and connect service mode to its manager.
FILE is one of `wf-manager-profiles'.  The commands of `wf.el' then
act on the manager, as `wf-service-commands' states.  When service
mode already has a session, the session switches to the endpoint of
FILE, and a switch that fails keeps the earlier binding."
  (interactive (list (wf-service--read-profile-file)))
  (let ((profile (condition-case failure
                     (wf-manager-profile-load file)
                   (wf-manager-error
                    (user-error "The client profile %s cannot be used: %s"
                                file (wf-service--failure-text failure))))))
    (if (and wf-service--current
             (not (wf-manager-session-closed (wf-service--state-session wf-service--current))))
        (wf-service--switch wf-service--current file profile)
      (let ((session (wf-service--connect profile)))
        (setq wf-service--current (wf-service--state-make :file file :session session))))
    (setq wf--service-dispatch #'wf-service--dispatch)
    (message "wf: service mode, endpoint %s"
             (wf-manager-endpoint-url (wf-manager-profile-endpoint profile)))))

;;;###autoload
(defun wf-local ()
  "Return the commands of `wf.el' to local mode.
Close the session of service mode.  The close sends no command, so the
runs and requests of the manager continue."
  (interactive)
  (when wf-service--current
    (wf-manager-session-close (wf-service--state-session wf-service--current)))
  (setq wf-service--current nil
        wf--service-dispatch nil)
  (message "wf: local mode"))


;;; The catalogue

(defun wf-service--session ()
  "Return the session of service mode."
  (unless wf-service--current
    (user-error "Service mode has no session.  Select a profile with `wf-service'"))
  (wf-service--state-session wf-service--current))

(defun wf-service--collection (session uri what)
  "On SESSION, return the items of the complete page set URI.
WHAT names the collection in the message of a failure."
  (let ((set (wf-service--await
              (lambda (callback)
                (wf-manager-session-page-set
                 session (wf-manager-session-reference session uri) callback)
                nil))))
    (when (wf-manager-failure-p set)
      (wf-service--refuse (format "The %s cannot be read" what) set))
    (wf-manager-page-set-items set)))

(defun wf-service--number (value)
  "Return the Lisp number of the JSON number VALUE, or nil for JSON null."
  (and (wf-manager-json-number-p value)
       (string-to-number (wf-manager-json-number-source value))))

(defun wf-service--read-profile (session)
  "Read one ready profile of the manager of SESSION in the minibuffer.
Return its identifier."
  (let* ((profiles (cl-remove-if-not
                    (lambda (item) (equal (gethash "readiness" item) "ready"))
                    (wf-service--collection session "/v1/profiles" "manager profiles")))
         (alist (mapcar (lambda (item) (cons (gethash "id" item) item)) profiles))
         (annotate (lambda (id)
                     (let ((item (cdr (assoc id alist))))
                       (when item
                         (format "  %s  —  %s" (gethash "workspaceLabel" item)
                                 (gethash "targetLabel" item))))))
         (table (lambda (string pred action)
                  (if (eq action 'metadata)
                      `(metadata (annotation-function . ,annotate)
                                 (category . wf-profile))
                    (complete-with-action action alist string pred)))))
    (unless alist
      (user-error "The manager offers no ready profile to this credential"))
    (completing-read (format-prompt "Profile" (caar alist)) table nil t nil nil (caar alist))))

(defun wf-service--rows (session profile)
  "On SESSION, return the catalogue of PROFILE as rows of `wf--read-row'.
Each row is an alist with the fields that `wf--read-row' shows, the
identity fields of the workflow and `item', the decoded catalogue
item."
  (delq nil
        (mapcar
         (lambda (item)
           (when (equal (gethash "profileId" item) profile)
             `((name . ,(gethash "name" item))
               (blurb . ,(gethash "blurb" item))
               (level . ,(gethash "level" item))
               (maxFold . ,(wf-service--number (gethash "maxFold" item)))
               (paths . ,(wf-service--number (gethash "paths" item)))
               (id . ,(gethash "id" item))
               (revision . ,(gethash "revision" item))
               (profileId . ,profile)
               (profileRevision . ,(gethash "profileRevision" item))
               (help . ,(gethash "help" item))
               (item . ,item))))
         (wf-service--collection session (concat "/v1/workflows?profileId=" profile)
                                 (format "catalogue of %s" profile)))))

(defun wf-service--read-workflow (prompt)
  "Read a ready profile and one workflow of its catalogue, with PROMPT.
The workflow completion is `wf--read-row'.  Return the row."
  (let* ((session (wf-service--session))
         (profile (wf-service--read-profile session))
         (rows (wf-service--rows session profile)))
    (unless rows
      (user-error "The catalogue of profile %s lists no workflow" profile))
    (wf--read-row prompt nil rows)))

(defun wf-service--run (&optional _refresh)
  "Read the catalogue of the manager and select one workflow.
Each read is fresh, so the prefix argument of `wf-run' changes nothing.
Service mode does not yet create a request, so the command then
refuses."
  (let ((row (wf-service--read-workflow "Workflow: ")))
    (user-error "Service mode does not yet create a request of %s in %s"
                (alist-get 'name row) (alist-get 'profileId row))))

(defun wf-service--help (&optional _refresh)
  "Show the help text that the manager catalogue states for a workflow."
  (let ((row (wf-service--read-workflow "Help on workflow: ")))
    (pop-to-buffer
     (wf--show (format "*wf help: %s/%s*" (alist-get 'profileId row) (alist-get 'name row))
               (concat (format "Workflow %s of profile %s, revision %s\n\n"
                               (alist-get 'name row) (alist-get 'profileId row)
                               (alist-get 'revision row))
                       (alist-get 'help row))
               default-directory))))


;;; Diagnostics

(defun wf-service-diagnostics-text ()
  "Return the diagnostics text of the session of service mode."
  (let* ((state wf-service--current)
         (session (wf-service--session))
         (connection (wf-manager-session-connection session))
         (fields (wf-manager-capabilities-fields
                  (wf-manager-connection-capabilities connection)))
         (profile (wf-manager-transport-profile (wf-manager-session-transport session)))
         (end (wf-manager-session-follow-end session)))
    (concat
     "Mode: service\n"
     (format "Profile file: %s\n" (wf-service--state-file state))
     (format "Endpoint: %s\n" (wf-manager-endpoint-url (wf-manager-profile-endpoint profile)))
     (format "Endpoint identity: %s\n" (wf-manager-session-identity session))
     (format "Authority epoch: %s\n" (wf-manager-connection-epoch connection))
     (format "Scopes: %s\n" (string-join (append (gethash "scopes" fields) nil) ", "))
     (format "Profiles: %s\n" (string-join (append (gethash "profileIds" fields) nil) ", "))
     (format "Delivery state: %s\n" (wf-manager-session-delivery session))
     (format "Generation: %s\n" (wf-manager-session-generation session))
     (format "Polling batches: %s\n" (wf-manager-session-polls session))
     (format "Follow loop: %s\n"
             (pcase end
               ('nil "running")
               (`(,kind nil) (format "ended %s" kind))
               (`(,kind ,failure) (format "ended %s: %s" kind (wf-service--failure-text failure)))))
     (format "Last problem: %s\n" (or (wf-service--state-problem state) "none")))))

(defun wf-service--diagnostics ()
  "Show the diagnostics of the session of service mode."
  (pop-to-buffer (wf--show "*wf service diagnostics*" (wf-service-diagnostics-text)
                           default-directory)))

(provide 'wf-service)

;;; wf-service.el ends here
