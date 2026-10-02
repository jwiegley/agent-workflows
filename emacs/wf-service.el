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
;;   service  The command has a manager behavior.  `wf-run' creates a
;;            request of a catalogue workflow, supplies its inputs from
;;            the setup form, enqueues it and shows the exact review of
;;            its preparation, `wf-refresh' reads the request of a setup
;;            form again, `wf-help' shows the help text of a catalogue
;;            workflow, and `wf-diagnostics' shows the diagnostics of the
;;            session.
;;   pending  The command has no manager behavior yet, and it refuses
;;            with a message that says so.
;;   local    The command reads the local runner or its store, and it
;;            refuses in service mode with a message that names the
;;            service equivalent when one exists.  It sends nothing.
;;
;; `wf-run' in service mode follows these steps:
;;
;;   1. It reads a ready profile and one workflow of its catalogue, and
;;      it creates a request of that workflow with POST /v1/requests.
;;   2. The setup form of `wf--setup-mode' edits the missing inputs of
;;      the request, with the same widgets and sources as local mode.
;;      A Literal or Multiline input is sent with set-input as its exact
;;      text.  A File, Buffer or Region input is uploaded as exact
;;      UTF-8 bytes with POST /v1/captures, and set-input then binds the
;;      capture.  The manager receives the bytes and never a file name.
;;      `wf-refresh' in the form reads the request again and draws the
;;      form again, and every draft stays.
;;   3. It enqueues the request and follows its admission, with the
;;      queue position and the blocking reasons, until the preparation
;;      of the request is live.
;;   4. The review buffer of `wf-service-review-mode' shows the exact
;;      review of GET /v1/preparations/{id}: the approval selectors, the
;;      entity tag that approve binds as If-Match and every consent fact
;;      of the review.  It is the review of the manager and not a plan of
;;      this client.  \`a' asks `wf-confirm-function', and only a yes sends
;;      approve with the selectors and the entity tag.  A no and \`q'
;;      decline and send nothing.  \`d' discards the preparation, and \`w'
;;      withdraws the request.
;;
;; No step sends a command again by itself.  A command whose outcome is
;; uncertain stops the command with a message, and nothing is sent again.

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
    (wf-refresh service wf-service--refresh)
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
  "Create a request of a catalogue workflow and show its exact review.
Each read is fresh, so the prefix argument of `wf-run' changes nothing.
The steps are the steps of the commentary of this file.  A cancel of
the setup form leaves the request a draft of the manager."
  (let* ((session (wf-service--session))
         (row (wf-service--read-workflow "Workflow: "))
         (draft (wf-service--create session row))
         (reference (wf-manager-session-reference
                     session (concat "/v1/requests/" (wf-manager-draft-id draft))))
         (specs (wf-service--setup session row draft reference)))
    (dolist (spec specs)
      (wf-service--supply session reference (wf-manager-draft-id draft) spec))
    (wf-service--enqueue session reference)
    (wf-service--open-review session reference)))

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


;;; Commands of the manager

(defconst wf-service--wait-seconds 120
  "The longest wait for a receipt, a review or a run, in seconds.")

(defconst wf-service--poll-seconds 0.25
  "The wait between two reads of a resource that a command follows.")

(defconst wf-service--open-phases '("draft" "queued" "preparing" "review")
  "The phases of a request before its start intent.")

(defconst wf-service--selectors
  '(("reviewDigest" . wf-manager-preparation-review-digest)
    ("requestRevision" . wf-manager-preparation-request-revision)
    ("profileRevision" . wf-manager-preparation-profile-revision)
    ("descriptorRevision" . wf-manager-preparation-descriptor-revision)
    ("processGeneration" . wf-manager-preparation-process-generation))
  "The approval selectors of a preparation and their accessors.")

(defun wf-service--decode (decode value what)
  "Return DECODE of the JSON VALUE, or refuse for WHAT."
  (condition-case failure
      (funcall decode value)
    (wf-manager-error (wf-service--refuse (format "The %s does not decode" what) failure))))

(defun wf-service--read (session uri)
  "On SESSION, return the `wf-manager-reply' of one GET of URI, or refuse."
  (let ((reply (wf-service--await
                (lambda (callback)
                  (wf-manager-session-read
                   session (wf-manager-session-reference session uri) callback)
                  nil))))
    (when (wf-manager-failure-p reply)
      (wf-service--refuse (format "The read of %s failed" uri) reply))
    reply))

(defun wf-service--read-draft (session reference)
  "On SESSION, return (DRAFT . ETAG) of one read of the request REFERENCE."
  (let ((reply (wf-service--read session (wf-manager-reference-uri reference))))
    (cons (wf-service--decode #'wf-manager-decode-draft (wf-manager-reply-value reply)
                              "request")
          (wf-manager-reply-etag reply))))

(defun wf-service--prepare (session uri body if-match)
  "On SESSION, prepare for URI the command BODY with IF-MATCH, or refuse."
  (condition-case failure
      (wf-manager-session-prepare session (wf-manager-session-reference session uri)
                                  body if-match)
    (wf-manager-error (wf-service--refuse "The command cannot be prepared" failure))))

(defun wf-service--send (session command what)
  "On SESSION, send the `wf-manager-pending' COMMAND one time.
WHAT names the command in a message.  Return the delivered
`wf-manager-sent'.  A refused command refuses, and an uncertain
command stops with a message, and nothing is sent again."
  (let* ((sent (wf-service--await
                (lambda (callback) (wf-manager-session-send session command callback) nil)))
         (failure (wf-manager-sent-failure sent)))
    (pcase (wf-manager-sent-kind sent)
      ('delivered sent)
      ('refused (wf-service--refuse (format "The manager refused the %s command" what)
                                    failure))
      (_ (user-error "%s" (wf-service--problem
                           (format "The outcome of the %s command is uncertain%s.  Nothing was sent again"
                                   what (if failure
                                            (concat ": " (wf-service--failure-text failure))
                                          ""))))))))

(defun wf-service--settle (session sent what)
  "On SESSION, read the receipt of the delivered SENT until it settles.
WHAT names the command in a message.  Return the receipt when it
reached effect-observed, and refuse otherwise."
  (let ((deadline (+ (float-time) wf-service--wait-seconds))
        (receipt (wf-manager-sent-receipt sent)))
    (while (not (member (and receipt (wf-manager-command-receipt-state receipt))
                        '("effect-observed" "refused" "unresolved")))
      (when (> (float-time) deadline)
        (user-error "%s" (wf-service--problem
                          (format "The %s command did not settle in %d seconds"
                                  what wf-service--wait-seconds))))
      (accept-process-output nil wf-service--poll-seconds)
      (let ((read (wf-service--await
                   (lambda (callback)
                     (wf-manager-session-receipt session (wf-manager-sent-location sent)
                                                 callback)
                     nil))))
        (when (wf-manager-failure-p read)
          (wf-service--refuse (format "The receipt of the %s command cannot be read" what)
                              read))
        (setq receipt read)))
    (unless (equal (wf-manager-command-receipt-state receipt) "effect-observed")
      (user-error "%s" (wf-service--problem
                        (format "The %s command ended %s%s" what
                                (wf-manager-command-receipt-state receipt)
                                (if (wf-manager-command-receipt-refusal receipt)
                                    (format " (%s)" (wf-manager-command-receipt-refusal receipt))
                                  "")))))
    receipt))

(defun wf-service--command (session uri body if-match what)
  "On SESSION, send to URI the command BODY with IF-MATCH and settle it.
WHAT names the command in a message.  Return the settled receipt."
  (wf-service--settle session
                      (wf-service--send session (wf-service--prepare session uri body if-match)
                                        what)
                      what))

(defun wf-service-admission-line (draft)
  "Return the admission line of the request DRAFT.
The line names the phase, the admission state, the queue position, the
blocking reasons and the missing inputs, as `admissionLine' of
`ext-pi/src/manager-ui.ts' does."
  (let ((position (wf-manager-draft-position draft))
        (reasons (wf-manager-draft-reasons draft))
        (missing (wf-manager-readiness-missing (wf-manager-draft-readiness draft))))
    (string-join
     (delq nil
           (list (format "Request %s: %s" (wf-manager-draft-id draft) (wf-manager-draft-phase draft))
                 (format "admission %s" (wf-manager-draft-admission draft))
                 (and position (format "queue position %d" position))
                 (and reasons (format "waiting for %s" (string-join reasons ", ")))
                 (and missing (format "missing inputs %s" (string-join missing ", ")))))
     ", ")))

;;;; Requests and setup

(defun wf-service--create (session row)
  "On SESSION, create a request of the catalogue ROW and return its draft."
  (let* ((body (wf-manager-json-object
                "workflowId" (alist-get 'id row)
                "descriptorRevision" (alist-get 'revision row)
                "profileId" (alist-get 'profileId row)
                "profileRevision" (alist-get 'profileRevision row)))
         (sent (wf-service--send session (wf-service--prepare session "/v1/requests" body nil)
                                 "create"))
         (reply (wf-manager-sent-reply sent)))
    (unless (= (wf-manager-reply-status reply) 201)
      (user-error "%s" (wf-service--problem
                        (format "The create command gave the status %d and not 201"
                                (wf-manager-reply-status reply)))))
    (wf-service--decode #'wf-manager-decode-draft (wf-manager-reply-value reply) "request")))

(defun wf-service--setup-header (draft)
  "Return the header of the setup form of the request DRAFT."
  (concat (format "Manager request %s of workflow %s in profile %s.\n"
                  (wf-manager-draft-id draft) (wf-manager-draft-workflow-id draft)
                  (wf-manager-draft-profile-id draft))
          (wf-service-admission-line draft) ".\n"
          "Submit sends each input to the manager and enqueues the request.\n"
          "Literal and Multiline send the exact text.  File, Buffer and Region\n"
          "upload exact bytes as a capture.  M-x wf-refresh reads the request again."))

(defun wf-service--file-bytes (raw)
  "Return the exact bytes of the file RAW as a unibyte string.
The file is a readable regular file of `default-directory'.  The bytes
go to the manager, and the file name does not."
  (when (equal raw "")
    (user-error "Choose a file for the file source"))
  (let ((file (expand-file-name raw)))
    (unless (and (file-regular-p file) (file-readable-p file))
      (user-error "Input file must exist and be a readable regular file"))
    (when (> (file-attribute-size (file-attributes file)) wf-manager-capture-bytes)
      (user-error "Input file has more than %d bytes" wf-manager-capture-bytes))
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (insert-file-contents-literally file)
      (buffer-string))))

(defun wf-service--setup-spec (name source text)
  "Return the service spec of the input NAME with SOURCE and its draft TEXT.
A literal spec has the exact TEXT.  A capture spec has the exact bytes:
the bytes of the file TEXT for the File source, and the UTF-8 bytes of
TEXT for the Buffer and Region sources."
  (pcase source
    ((or 'literal 'multiline)
     `((name . ,name) (source . "literal") (value . ,text)))
    ('file
     `((name . ,name) (source . "capture") (bytes . ,(wf-service--file-bytes text))))
    (_
     `((name . ,name) (source . "capture")
       (bytes . ,(encode-coding-string text 'utf-8-unix))))))

(defun wf-service--setup (session row draft reference)
  "On SESSION, edit the missing inputs of ROW and return their specs.
DRAFT is the request of ROW, and REFERENCE its reference.  A request
without a missing input opens no form."
  (let ((missing (wf-manager-readiness-missing (wf-manager-draft-readiness draft))))
    (when missing
      (wf--setup-inputs `((name . ,(alist-get 'name row))
                          (inputs . ,(mapcar (lambda (name) `((name . ,name))) missing)))
                        #'wf-service--setup-spec
                        (wf-service--setup-header draft)
                        (list :session session :reference reference)))))

(defun wf-service--setup-reread ()
  "Read the request of this setup form again and draw the form again.
Every draft of the form stays."
  (let* ((context wf--setup-context)
         (draft (car (wf-service--read-draft (plist-get context :session)
                                             (plist-get context :reference)))))
    (wf--setup-refresh (wf-service--setup-header draft))
    (message "wf: %s" (wf-service-admission-line draft))))

(defun wf-service--refresh ()
  "In a setup form of service mode, read its request again.
The form is drawn again with every draft of every source.  Elsewhere,
service mode keeps no row listing to forget, and the command sends
nothing."
  (if (and (derived-mode-p 'wf--setup-mode) wf--setup-context)
      (wf-service--setup-reread)
    (message "wf: service mode keeps no row listing, and its session follows the manager")))

(defun wf-service--supply (session reference request-id spec)
  "On SESSION, supply the input to the request REFERENCE.
REQUEST-ID is the identifier of the request, and SPEC the input.  A
capture spec is uploaded first, and set-input then binds the capture.
The set-input binds the entity tag of a read of the request."
  (let* ((name (alist-get 'name spec))
         (input
          (if (equal (alist-get 'source spec) "capture")
              (let* ((command (condition-case failure
                                  (wf-manager-session-prepare-capture
                                   session request-id (alist-get 'bytes spec))
                                (wf-manager-error
                                 (wf-service--refuse (format "The capture of %s cannot be prepared" name)
                                                     failure))))
                     (capture (wf-manager-sent-capture
                               (wf-service--send session command "capture"))))
                (wf-manager-json-object "name" name "source" "capture"
                                        "captureId" (wf-manager-capture-receipt-id capture)))
            (wf-manager-json-object "name" name "source" "literal"
                                    "value" (alist-get 'value spec))))
         (etag (cdr (wf-service--read-draft session reference))))
    (wf-service--command session (wf-manager-reference-uri reference)
                         (wf-manager-json-object "operation" "set-input" "input" input)
                         etag "set-input")))

(defun wf-service--enqueue (session reference)
  "On SESSION, enqueue the request REFERENCE once no input is missing."
  (pcase-let ((`(,draft . ,etag) (wf-service--read-draft session reference)))
    (let ((readiness (wf-manager-draft-readiness draft)))
      (when (or (wf-manager-readiness-missing readiness) (wf-manager-readiness-errors readiness))
        (user-error "%s" (wf-service--problem (wf-service-admission-line draft)))))
    (wf-service--command session (wf-manager-reference-uri reference)
                         (wf-manager-json-object "operation" "enqueue") etag "enqueue")))

(defun wf-service--await-review (session reference)
  "On SESSION, follow the request REFERENCE until its preparation exists.
Return (DRAFT . LINES), with the request in review and the admission
lines that the wait showed, the oldest first.  A request that leaves
the open phases refuses with its admission line."
  (let ((deadline (+ (float-time) wf-service--wait-seconds))
        (lines nil)
        (draft nil))
    (while (progn
             (setq draft (car (wf-service--read-draft session reference)))
             (let ((line (wf-service-admission-line draft)))
               (unless (equal line (car lines))
                 (push line lines)
                 (message "wf: %s" line)))
             (and (not (and (equal (wf-manager-draft-phase draft) "review")
                            (wf-manager-draft-preparation-id draft)))
                  (member (wf-manager-draft-phase draft) wf-service--open-phases)))
      (when (> (float-time) deadline)
        (user-error "%s" (wf-service--problem
                          (format "The request did not reach review in %d seconds: %s"
                                  wf-service--wait-seconds (car lines)))))
      (accept-process-output nil wf-service--poll-seconds))
    (unless (equal (wf-manager-draft-phase draft) "review")
      (user-error "%s" (wf-service--problem (car lines))))
    (cons draft (nreverse lines))))

;;;; The exact review

(cl-defstruct (wf-service--review
               (:constructor wf-service--review-make)
               (:copier nil))
  "The state of one review buffer.
SESSION is the session, and REQUEST the `wf-manager-reference' of the
request.  DRAFT is the last read of the request, and LINES the
admission lines of the wait for the review.  PREPARATION is the last
read `wf-manager-preparation', and ETAG its entity tag.  OUTCOMES is the
list of the commands that the buffer sent, the newest first, each one
\(OPERATION TEXT).  RUN is the run of the approved request, or nil."
  session request draft lines preparation etag outcomes run)

(defvar-local wf-service--review-state nil
  "The `wf-service--review' of this review buffer.")

(defvar-keymap wf-service-review-mode-map
  :doc "Keys of the review buffer of service mode."
  :parent special-mode-map
  "a" #'wf-service-review-approve
  "d" #'wf-service-review-discard
  "w" #'wf-service-review-withdraw
  "g" #'wf-service-review-refresh
  "q" #'wf-service-review-decline)

(define-derived-mode wf-service-review-mode special-mode "wf-review"
  "The exact review of a manager preparation.
\\{wf-service-review-mode-map}")

(defun wf-service--json-text (value)
  "Return the JSON text of VALUE as a string."
  (decode-coding-string (wf-manager-json-encode value) 'utf-8))

(defun wf-service-review-text (review)
  "Return the text of the review buffer of REVIEW, a `wf-service--review'.
The text is the complete exact review of the preparation, as
`reviewLines' of `ext-pi/src/manager-ui.ts' shows it: every approval
selector, the entity tag that approve binds as If-Match and every
consent fact.  Nothing is shortened.  The admission of the request, its
queue position and its blocking reasons come first."
  (let* ((preparation (wf-service--review-preparation review))
         (facts (wf-manager-preparation-review preparation))
         (draft (wf-service--review-draft review))
         (lineage (wf-manager-review-lineage facts)))
    (concat
     "Exact review of the manager — no run has started.\n"
     "Approval starts the run of THIS review.  An edit needs a new request.\n"
     "a: approve after confirmation  d: discard  w: withdraw  g: read again  q: decline\n\n"
     "Admission:\n"
     (mapconcat (lambda (line) (concat "  " line "\n")) (wf-service--review-lines review) "")
     (format "Current: %s\n" (wf-service-admission-line draft))
     (format "Queue position: %s\n" (or (wf-manager-draft-position draft) "none"))
     (format "Blocking reasons: %s\n\n" (if (wf-manager-draft-reasons draft)
                                            (string-join (wf-manager-draft-reasons draft) ", ")
                                          "none"))
     (format "Review of request %s, preparation %s (%s, expires %s)\n"
             (wf-manager-preparation-request-id preparation) (wf-manager-preparation-id preparation)
             (wf-manager-preparation-state preparation) (wf-manager-preparation-expires-at preparation))
     "Approval selectors:\n"
     (mapconcat (lambda (selector)
                  (format "  %s: %s\n" (car selector) (funcall (cdr selector) preparation)))
                wf-service--selectors "")
     (format "  If-Match: %s\n" (wf-service--review-etag review))
     (format "Program SHA-256: %s\n" (wf-manager-review-program-hash facts))
     (format "Person answering: %s\n" (wf-manager-review-person-answering facts))
     (format "Workflow: %s\n" (wf-manager-review-workflow-id facts))
     (format "Profile: %s\n" (wf-manager-review-profile-id facts))
     (format "Workspace: %s\n" (wf-manager-review-workspace-label facts))
     (format "Target: %s\n" (wf-manager-review-target-label facts))
     (format "Policy: %s\n" (wf-service--json-text (wf-manager-review-policy facts)))
     (format "Result code: %s\n" (wf-service--json-text (wf-manager-review-result-code facts)))
     (if (wf-manager-review-inputs facts) "Inputs:\n" "Inputs: none\n")
     (mapconcat (lambda (input)
                  (format "  %s: %s, %d bytes, SHA-256 %s\n" (wf-manager-review-input-name input)
                          (wf-manager-review-input-source input) (wf-manager-review-input-bytes input)
                          (wf-manager-review-input-sha256 input)))
                (wf-manager-review-inputs facts) "")
     "Plan:\n"
     (mapconcat (lambda (line) (concat "  " line "\n"))
                (split-string (wf-manager-review-plan facts) "\n") "")
     (format "Run facts: %s\n" (if (wf-manager-review-run-facts facts)
                                   (string-join (wf-manager-review-run-facts facts) ", ")
                                 "none"))
     (format "Pins: %s\n" (if (wf-manager-review-pins facts)
                              (string-join (wf-manager-review-pins facts) ", ")
                            "none"))
     (if (wf-manager-review-warnings facts)
         (concat "Warnings:\n" (mapconcat (lambda (warning) (concat "  " warning "\n"))
                                         (wf-manager-review-warnings facts) ""))
       "Warnings: none\n")
     (if lineage
         (concat (format "Lineage: %s of run %s\n" (wf-manager-review-lineage-operation lineage)
                         (wf-manager-review-lineage-parent-run-id lineage))
                 (mapconcat (lambda (edit)
                              (if (equal (wf-manager-review-edit-operation edit) "drop")
                                  (format "  drop occurrence %d\n" (wf-manager-review-edit-occurrence-id edit))
                                (format "  replace occurrence %d with the answer of SHA-256 %s\n"
                                        (wf-manager-review-edit-occurrence-id edit)
                                        (wf-manager-review-edit-sha256 edit))))
                            (wf-manager-review-lineage-edits lineage) ""))
       "")
     (if (wf-service--review-outcomes review)
         (concat "\nSent:\n" (mapconcat (lambda (outcome) (format "  %s: %s\n" (car outcome) (cadr outcome)))
                                       (reverse (wf-service--review-outcomes review)) ""))
       ""))))

(defun wf-service--review-render (review)
  "Draw the review buffer of REVIEW again."
  (let ((inhibit-read-only t)
        (line (line-number-at-pos)))
    (erase-buffer)
    (insert (wf-service-review-text review))
    (goto-char (point-min))
    (forward-line (1- line))))

(defun wf-service--read-preparation (session id)
  "On SESSION, return (PREPARATION . ETAG) of one read of the preparation ID."
  (let ((reply (wf-service--read session (concat "/v1/preparations/" id))))
    (cons (wf-service--decode #'wf-manager-decode-preparation (wf-manager-reply-value reply)
                              "preparation")
          (wf-manager-reply-etag reply))))

(defun wf-service--open-review (session reference)
  "On SESSION, follow the request REFERENCE to its review and show it."
  (pcase-let* ((`(,draft . ,lines) (wf-service--await-review session reference))
               (`(,preparation . ,etag)
                (wf-service--read-preparation session (wf-manager-draft-preparation-id draft))))
    (unless (equal (wf-manager-preparation-state preparation) "live")
      (user-error "%s" (wf-service--problem
                        (format "Preparation %s is %s (%s)" (wf-manager-preparation-id preparation)
                                (wf-manager-preparation-state preparation)
                                (or (wf-manager-preparation-reason preparation) "no reason")))))
    (unless etag
      (user-error "%s" (wf-service--problem
                        "The preparation has no entity tag, so no approval can bind it")))
    (let ((buffer (get-buffer-create (format "*wf review: %s*" (wf-manager-draft-id draft))))
          (review (wf-service--review-make :session session :request reference :draft draft
                                           :lines lines :preparation preparation :etag etag)))
      (with-current-buffer buffer
        (wf-service-review-mode)
        (setq wf-service--review-state review)
        (wf-service--review-render review))
      (pop-to-buffer buffer)
      (message "wf: the exact review of request %s.  a approves after confirmation"
               (wf-manager-draft-id draft)))))

(defun wf-service--review-here (&rest closed)
  "Return the review of this buffer.
Refuse when the review has sent one of the operations CLOSED."
  (let ((review wf-service--review-state))
    (unless review
      (user-error "This buffer shows no review of service mode"))
    (dolist (outcome (wf-service--review-outcomes review))
      (when (member (car outcome) closed)
        (user-error "This review already sent %s" (car outcome))))
    review))

(defun wf-service--review-sent (review operation text)
  "Record that REVIEW sent OPERATION with TEXT, and draw it again."
  (push (list operation text) (wf-service--review-outcomes review))
  (wf-service--review-render review)
  (message "wf: %s" text))

(defun wf-service-review-approve ()
  "Approve this exact review after `wf-confirm-function' agrees.
Only a yes sends approve, with the approval selectors of the
preparation and its entity tag as If-Match.  A no sends nothing."
  (interactive)
  (let* ((review (wf-service--review-here "approve" "discard" "withdraw"))
         (session (wf-service--review-session review))
         (preparation (wf-service--review-preparation review))
         (etag (wf-service--review-etag review)))
    (if (not (funcall wf-confirm-function
                      (format "Approve preparation %s of request %s with review digest %s and If-Match %s? "
                              (wf-manager-preparation-id preparation)
                              (wf-manager-preparation-request-id preparation)
                              (wf-manager-preparation-review-digest preparation) etag)))
        (message "wf: review declined.  No approval was sent, and request %s stays in review"
                 (wf-manager-preparation-request-id preparation))
      (let* ((body (apply #'wf-manager-json-object "operation" "approve"
                          (cl-mapcan (lambda (selector)
                                       (list (car selector) (funcall (cdr selector) preparation)))
                                     wf-service--selectors)))
             (sent (wf-service--send
                    session
                    (wf-service--prepare session
                                         (concat "/v1/preparations/" (wf-manager-preparation-id preparation))
                                         body etag)
                    "approve"))
             (receipt (wf-manager-sent-receipt sent)))
        (when (or (null receipt) (equal (wf-manager-command-receipt-state receipt) "refused"))
          (user-error "%s" (wf-service--problem "The manager did not accept the approval")))
        (wf-service--review-sent review "approve"
                                 (format "command %s" (wf-manager-reference-uri
                                                       (wf-manager-sent-location sent))))
        (let ((run (wf-service--await-run session (wf-service--review-request review))))
          (setf (wf-service--review-run review) run)
          (wf-service--review-sent review "run"
                                   (format "the manager started run %s for request %s"
                                           run (wf-manager-preparation-request-id preparation))))))))

(defun wf-service--await-run (session reference)
  "On SESSION, return the run of the approved request REFERENCE."
  (let ((deadline (+ (float-time) wf-service--wait-seconds))
        (draft nil))
    (while (progn
             (setq draft (car (wf-service--read-draft session reference)))
             (and (null (wf-manager-draft-run-id draft))
                  (not (member (wf-manager-draft-phase draft) '("withdrawn" "refused")))))
      (when (> (float-time) deadline)
        (user-error "%s" (wf-service--problem
                          (format "Request %s names no run after %d seconds"
                                  (wf-manager-draft-id draft) wf-service--wait-seconds))))
      (accept-process-output nil wf-service--poll-seconds))
    (or (wf-manager-draft-run-id draft)
        (user-error "%s" (wf-service--problem (wf-service-admission-line draft))))))

(defun wf-service-review-discard ()
  "Discard the preparation of this review.
The request returns to a draft, and no run starts."
  (interactive)
  (let* ((review (wf-service--review-here "approve" "discard" "withdraw"))
         (preparation (wf-service--review-preparation review)))
    (wf-service--command (wf-service--review-session review)
                         (concat "/v1/preparations/" (wf-manager-preparation-id preparation))
                         (wf-manager-json-object "operation" "discard")
                         (wf-service--review-etag review) "discard")
    (wf-service--review-sent review "discard"
                             (format "preparation %s is discarded, and request %s is a draft again"
                                     (wf-manager-preparation-id preparation)
                                     (wf-manager-preparation-request-id preparation)))))

(defun wf-service-review-withdraw ()
  "Withdraw the request of this review.
A withdrawn request has no run."
  (interactive)
  (let* ((review (wf-service--review-here "approve" "withdraw"))
         (session (wf-service--review-session review))
         (reference (wf-service--review-request review))
         (etag (cdr (wf-service--read-draft session reference))))
    (wf-service--command session (wf-manager-reference-uri reference)
                         (wf-manager-json-object "operation" "withdraw") etag "withdraw")
    (wf-service--review-sent review "withdraw"
                             (format "request %s is withdrawn"
                                     (wf-manager-preparation-request-id
                                      (wf-service--review-preparation review))))))

(defun wf-service-review-refresh ()
  "Read the request and the preparation of this review again."
  (interactive)
  (let* ((review (wf-service--review-here))
         (session (wf-service--review-session review))
         (draft (car (wf-service--read-draft session (wf-service--review-request review))))
         (read (wf-service--read-preparation
                session (wf-manager-preparation-id (wf-service--review-preparation review)))))
    (setf (wf-service--review-draft review) draft
          (wf-service--review-preparation review) (car read)
          (wf-service--review-etag review) (cdr read))
    (wf-service--review-render review)
    (message "wf: %s" (wf-service-admission-line draft))))

(defun wf-service-review-decline ()
  "Decline this review and quit its window.  Nothing is sent.
A review that sent no command leaves its request in review."
  (interactive)
  (let ((review (wf-service--review-here)))
    (quit-window)
    (unless (wf-service--review-outcomes review)
      (message "wf: review declined.  No approval was sent, and request %s stays in review"
               (wf-manager-preparation-request-id (wf-service--review-preparation review))))))


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
