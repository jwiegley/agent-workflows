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
;; a file system path of the manager.  The table has two kinds of
;; entry:
;;
;;   service  The command has a manager behavior.  `wf-run' creates a
;;            request of a catalogue workflow, supplies its inputs from
;;            the setup form, enqueues it and shows the exact review of
;;            its preparation, `wf-refresh' reads the request of a setup
;;            form again, `wf-help' shows the help text of a catalogue
;;            workflow, `wf-diagnostics' shows the diagnostics of the
;;            session, `wf-runs' opens the view of a local or a service
;;            run, `wf-answer' answers the head decision of a run,
;;            `wf-control' sends one control that the controls of a run
;;            offer, `wf-kill' cancels a run after a confirmation,
;;            `wf-result' saves the verified result of a run to a new
;;            file, `wf-history', `wf-history-refresh' and
;;            `wf-history-open' list and open the runs of the manager,
;;            and `wf-restart', `wf-resume', `wf-fork' and `wf-rerun'
;;            create a lineage child of a run and show its exact review.
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
;;
;; A service run view of `wf-service-run-mode' follows one run of the
;; manager.  The view is keyed by the endpoint identity of the session
;; and the run identifier, so each window follows its own run.  The
;; session watches the run, its snapshot, its controls and its decision
;; queue, and each read that the session installs draws the view again.
;; The view shows the runtime status, the supervision, the verification,
;; the pending decisions and the offered controls on separate lines, and
;; it ends with the Terminal and Result lines.  The Result lines of a
;; succeeded run name the size and the SHA-256 digest of the verified
;; download of its result.  `wf-answer' answers the head decision of the
;; run of the view through `wf--answer-editor'.  The typed text goes
;; through `wf-manager-answer-value', so the answer no to a flag question
;; is JSON false, and the answer binds the entity tag of the decision as
;; If-Match.  A 412 refusal keeps the draft and reports it.  An uncertain
;; answer is reconciled one time, with the reads of
;; `wf-manager-session-answer-reconciliation', and it is never sent again.
;; The kill of a view or of any other buffer sends no command, and the
;; function of `kill-emacs-hook' closes only the transport.
;;
;; `wf-control' reads the controls of the run of the view, the head
;; decision that they name and, for a redirect offer, the run snapshot.
;; It lists only what the controls offer: a cancel when the owned
;; controls allow it, each timing of each steer offer, each target of
;; each redirect offer, and the retry, abandon and fail-over choices of
;; a recovery head.  A cancel asks `wf-confirm-function', and only a yes
;; sends it.  `wf-kill' reaches the same cancel.  A steer opens an
;; editor, and its text is sent with the offered timing.  Cancel, steer,
;; redirect and retry bind the entity tag of the controls as If-Match.
;; A recovery choice binds the entity tag of its decision.  Each control
;; is sent one time.  An uncertain send is reconciled one time with
;; `wf-manager-session-reconcile', and it is never sent again.
;;
;; `wf-result' reads GET /v1/runs/{id}/outputs for the run of the view,
;; or for a run that the session knows, and downloads the verified
;; artifact of the result with the verified download of the session.
;; It saves the exact bytes to a new file with mode 0600.  The creation
;; is exclusive, so a second save to the same file refuses and the file
;; stays as it is.
;;
;; `wf-history' lists every run of /v1/runs over every page in a buffer
;; of `wf-service-history-mode', in the order of the collection, managed
;; runs and legacy observer entries alike.  Each row keeps the reference
;; of its run on the binding that listed it.  RET opens the run view of
;; the row with that reference.  After a switch to another endpoint, the
;; reference refuses with `wf-manager-wrong-endpoint', nothing is sent,
;; and the row is never opened on the new endpoint.  Local mode keeps
;; `wf-history' and the observer over the local stores.
;;
;; `wf-restart', `wf-resume' and `wf-fork' create a child request of a
;; run with POST /v1/runs/{id}/lineage-requests, and `wf-rerun' is a
;; restart in service mode.  The run is the run of the run view, the run
;; of the history row at point, or a run that the session knows.  The
;; command reads the first page of the lineage collection of the run, and
;; it sends the request only when the page lists the operation as
;; eligible, with the entity tag of the page as If-Match.  A fork first
;; collects its edits from the run snapshot, as `forkTargets' of
;; `ext-pi/src/manager-ui.ts' does: each completed or reused occurrence
;; keeps, drops or replaces its answer, and a replacement is typed by the
;; code of the occurrence.  The child takes its inputs from the parent,
;; so the command enqueues it at once and shows its exact review, whose
;; lineage lines name the parent, the operation and the edits.  Only the
;; approval of that review starts the child run.
;;
;; `wf-export' exports the verified result of a run under a name with
;; POST /v1/runs/{id}/exports and the entity tag of the first page of
;; the export collection as If-Match.  After the effect `exported', it
;; reads the export receipt, downloads the exported bytes with the
;; verified download of the session, and shows the receipt, the
;; verified size and digest and the export collection of the run.
;; Local mode has no export, so `wf-export' refuses there.
;;
;; A lineage request and an export are each sent one time.  An uncertain
;; send is reconciled with one read of its collection, and it is never
;; sent again.

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
    (wf-runs service wf-service--runs)
    (wf-answer service wf-service--answer)
    (wf-control service wf-service--control)
    (wf-kill service wf-service--kill)
    (wf-result service wf-service--result)
    (wf-history service wf-service--history)
    (wf-history-refresh service wf-service-history-refresh)
    (wf-history-open service wf-service-history-open)
    (wf-restart service wf-service--restart)
    (wf-resume service wf-service--resume)
    (wf-fork service wf-service--fork)
    (wf-rerun service wf-service--rerun)
    (wf-fork-submit local "`wf-fork'")
    (wf-plan local "the review of `wf-run'")
    (wf-cost local "the review of `wf-run'")
    (wf-lineage-compare local nil)
    (wf-observer-result local nil)
    (wf-observer-refresh local nil))
  "The service behavior of each public interactive command of `wf.el'.
Each entry is (COMMAND KIND DETAIL).  KIND `service' runs the function
DETAIL with the arguments of COMMAND.  KIND `local' refuses with the
message of `wf-service-refusal', and DETAIL is the text that names the
service equivalent of COMMAND, or nil when there is none.  No refusal
sends a request or starts a process.")

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
    (`(local ,_) (user-error "%s" (wf-service-refusal command)))
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
           (wf-service--problem "a polling batch did not reach the manager")))))
  (wf-service--views-changed session))

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

(defun wf-service--page-set (session uri what)
  "On SESSION, return the complete `wf-manager-page-set' of URI.
WHAT names the collection in the message of a failure."
  (let ((set (wf-service--await
              (lambda (callback)
                (wf-manager-session-page-set
                 session (wf-manager-session-reference session uri) callback)
                nil))))
    (when (wf-manager-failure-p set)
      (wf-service--refuse (format "The %s cannot be read" what) set))
    set))

(defun wf-service--collection (session uri what)
  "On SESSION, return the items of the complete page set URI.
WHAT names the collection in the message of a failure."
  (wf-manager-page-set-items (wf-service--page-set session uri what)))

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

(defun wf-service--receipt-final-p (receipt)
  "Return non-nil when the state of RECEIPT is final.
The final states are effect-observed, refused and unresolved."
  (member (wf-manager-command-receipt-state receipt)
          '("effect-observed" "refused" "unresolved")))

(defun wf-service--await-receipt (session sent what settled)
  "On SESSION, read the receipt of the delivered SENT until it settles.
WHAT names the command in a message.  SETTLED is a function of a
`wf-manager-command-receipt', and the receipt settles when it returns
non-nil.  Return the settled receipt.  The command is never sent
again."
  (let ((deadline (+ (float-time) wf-service--wait-seconds))
        (receipt (wf-manager-sent-receipt sent)))
    (while (not (and receipt (funcall settled receipt)))
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
    receipt))

(defun wf-service--settle (session sent what)
  "On SESSION, read the receipt of the delivered SENT until it settles.
WHAT names the command in a message.  Return the receipt when it
reached effect-observed, and refuse otherwise."
  (let ((receipt (wf-service--await-receipt session sent what
                                            #'wf-service--receipt-final-p)))
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


;;; Run views

(defconst wf-service--view-resources
  '((run "/v1/runs/%s" wf-manager-decode-run)
    (snapshot "/v1/runs/%s/snapshot" wf-service--decode-object)
    (control "/v1/runs/%s/control" wf-manager-decode-control)
    (queue "/v1/decisions?runId=%s" wf-service--decode-queue))
  "The watched resources of a run view.
Each entry is (NAME FORMAT DECODE): the name of the resource, the
format of its path with the run identifier, and the function that
decodes the JSON value of a read of it.")

(defconst wf-service--terminal-statuses '("succeeded" "failed" "cancelled" "orphaned")
  "The terminal runtime statuses of a run.")

(cl-defstruct (wf-service--view
               (:constructor wf-service--view-make)
               (:copier nil))
  "The state of one service run view.
SESSION is the session, IDENTITY the endpoint identity of its binding
and RUN the run identifier.  BUFFER is the view buffer.  REFERENCES maps
each name of `wf-service--view-resources' to its `wf-manager-reference'.
KEPT maps each name to the value of its last read that decoded, and
ETAGS to the entity tag of that read.  FAILURES maps each name to the
text of the failure of its latest read, when that read failed.
DELIVERY is the delivery state of the session at the last take.
RESULT is the retrieval of the verified result: nil before it starts,
`waiting', `retrieving', (verified BYTES SHA256) or (failed TEXT).
ATTEMPTED is the entity tag of the snapshot at the last retrieval."
  session identity run buffer references kept etags failures delivery result attempted)

(defvar wf-service--views (make-hash-table :test #'equal)
  "The live run views of service mode, keyed by (IDENTITY . RUN).")

(defvar-local wf-service--view-state nil
  "The `wf-service--view' of this run view.")

(defvar-keymap wf-service-run-mode-map
  :doc "Keys of a service run view."
  :parent wf-run-mode-map
  "E" #'wf-export)

(define-derived-mode wf-service-run-mode wf-run-mode "Workflow service"
  "Display a run of the manager in service mode.
The keys are those of `wf-run-mode', and \\`E' runs `wf-export'.  The
view sends no command by itself, and the kill of the view sends no
command.

\\{wf-service-run-mode-map}")

(defun wf-service--decode-object (value)
  "Return the JSON object VALUE, or signal `wf-manager-invalid-response'."
  (if (hash-table-p value)
      value
    (signal 'wf-manager-invalid-response '("snapshot" "the snapshot is not an object"))))

(defun wf-service--decode-queue (value)
  "Return the decisions of the decision queue page VALUE as a vector."
  (let ((items (and (hash-table-p value) (gethash "items" value))))
    (unless (vectorp items)
      (signal 'wf-manager-invalid-response '("queue" "the queue has no items")))
    (vconcat (mapcar #'wf-manager-decode-decision items))))

(defun wf-service--one-line (text)
  "Return TEXT with each run of line ends replaced by one space."
  (replace-regexp-in-string "[\n\r]+" " " (or text "")))

(defun wf-service--member (object name)
  "Return the member of the JSON OBJECT named NAME, or nil for JSON null or none."
  (let ((value (and (hash-table-p object) (gethash name object))))
    (unless (eq value :null) value)))

(defun wf-service--view-take (view)
  "Copy into VIEW what the session of VIEW installed for its resources.
A read that decodes replaces the kept value of its resource.  A failed
read keeps the earlier value and records its failure."
  (let ((session (wf-service--view-session view)))
    (setf (wf-service--view-delivery view)
          (if (wf-manager-session-closed session) 'closed (wf-manager-session-delivery session)))
    (pcase-dolist (`(,name ,_ ,decode) wf-service--view-resources)
      (let ((installed (wf-manager-session-current
                        session (alist-get name (wf-service--view-references view)))))
        (cond
         ((null installed))
         ((wf-manager-failure-p installed)
          (setf (alist-get name (wf-service--view-failures view))
                (wf-service--failure-text installed)))
         (t
          (let ((value (condition-case nil
                           (funcall decode (wf-manager-reply-value installed))
                         (wf-manager-error nil))))
            (if (null value)
                (setf (alist-get name (wf-service--view-failures view))
                      "the read does not decode")
              (setf (alist-get name (wf-service--view-kept view)) value
                    (alist-get name (wf-service--view-etags view))
                    (wf-manager-reply-etag installed)
                    (alist-get name (wf-service--view-failures view) nil 'remove)
                    nil)))))))))

(defun wf-service--snapshot-status (snapshot)
  "Return the runtime status of the run SNAPSHOT, or nil."
  (wf-service--member (wf-service--member snapshot "runtime") "status"))

(defun wf-service--decision-line (decision)
  "Return the line of DECISION in a run view."
  (let ((place (if (= (wf-manager-decision-position decision) 0)
                   (format "Head %s" (wf-manager-decision-id decision))
                 (format "%s at position %d" (wf-manager-decision-id decision)
                         (wf-manager-decision-position decision))))
        (content (wf-manager-decision-content decision)))
    (if (wf-manager-question-p content)
        (let ((code (wf-manager-question-code content)))
          (format "  %s: %s question (%s): %s" place (wf-manager-decision-state decision)
                  (pcase code
                    ("flag" "flag: yes, no, true or false")
                    ("receipt" "receipt: empty")
                    ((pred stringp) code)
                    (_ "structured JSON"))
                  (wf-service--one-line (wf-manager-question-prompt content))))
      (format "  %s: %s recovery (%s): %s, choices %s" place (wf-manager-decision-state decision)
              (wf-manager-recovery-gap content)
              (wf-service--one-line (wf-manager-recovery-message content))
              (or (mapconcat (lambda (option)
                               (if (wf-manager-recovery-option-target option)
                                   (format "%s to %s" (wf-manager-recovery-option-choice option)
                                           (wf-manager-recovery-option-target option))
                                 (wf-manager-recovery-option-choice option)))
                             (wf-manager-recovery-choices content) ", ")
                  "none")))))

(defun wf-service--observation-line (view)
  "Return the observation line of VIEW."
  (let* ((names (mapcar #'car wf-service--view-resources))
         (kept (cl-every (lambda (name) (alist-get name (wf-service--view-kept view))) names))
         (failure (cl-some (lambda (name) (alist-get name (wf-service--view-failures view))) names)))
    (cond ((and (null failure) kept) "Observation: current")
          ((null failure) "Observation: reading")
          (kept (format "Observation: stale (%s).  The last complete observation is kept" failure))
          (t (format "Observation: refused (%s).  No complete observation is installed" failure)))))

(defun wf-service--outcome-lines (view)
  "Return the Terminal and Result lines of VIEW."
  (let* ((snapshot (alist-get 'snapshot (wf-service--view-kept view)))
         (status (wf-service--snapshot-status snapshot))
         (result (wf-service--view-result view)))
    (cond
     ((not (member status wf-service--terminal-statuses))
      (list (format "Terminal: not yet (%s)" (or status "not yet observed"))
            "Result: none until the run succeeds"))
     ((not (equal status "succeeded"))
      (delq nil (list (format "Terminal: %s" status)
                      (let ((failure (wf-service--member snapshot "failure")))
                        (and failure
                             (format "Failure: %s: %s"
                                     (or (wf-service--member snapshot "failureClass") "unclassified")
                                     (wf-service--one-line failure))))
                      "Result: no download for a run that did not succeed")))
     (t
      (cons "Terminal: succeeded"
            (pcase result
              (`(verified ,bytes ,sha256)
               (list (format "Result: verified %d bytes" bytes)
                     (format "Result SHA-256: %s" sha256)))
              (`(failed ,text)
               (list (format "Result: not retrieved (%s).  The next change of the run retries" text)))
              ('waiting (list "Result: waiting for the verification of the manager"))
              (_ (let ((verification (wf-service--member
                                      (wf-service--member snapshot "verification") "state")))
                   (list (if (member verification '("verified" "referenced"))
                             "Result: retrieving the verified bytes"
                           (format "Result: no download, the verification is %s"
                                   (or verification "absent"))))))))))))

(defun wf-service-view-lines (view)
  "Return the lines of the run VIEW, a `wf-service--view'.
The lines name the run and its workflow, the endpoint identity, the
delivery state and the freshness of the observation.  The runtime
status, the supervision, the verification, the pending decisions with
the head first and the offered controls follow on separate lines.  The
Terminal and Result lines end the list."
  (let* ((kept (wf-service--view-kept view))
         (run (alist-get 'run kept))
         (content (and run (wf-manager-run-content run)))
         (known (and (wf-manager-known-run-p content) content))
         (snapshot (alist-get 'snapshot kept))
         (control (alist-get 'control kept))
         (queue (alist-get 'queue kept))
         (workflow (wf-service--member snapshot "workflow"))
         (verification (and known (wf-manager-known-run-verification known)))
         (pending (sort (cl-remove-if-not
                         (lambda (decision)
                           (member (wf-manager-decision-state decision) '("pending" "submitting")))
                         (append queue nil))
                        (lambda (a b) (< (wf-manager-decision-position a)
                                         (wf-manager-decision-position b))))))
    (append
     (list (format "Service run %s%s" (wf-service--view-run view)
                   (if workflow (format ", workflow %s" workflow) ""))
           (format "Endpoint identity: %s" (wf-service--view-identity view))
           (format "Delivery: %s" (wf-service--view-delivery view))
           (wf-service--observation-line view)
           (format "Runtime: %s" (or (wf-service--snapshot-status snapshot) "not yet observed"))
           (format "Supervision: %s"
                   (cond (known (wf-manager-known-run-supervision known))
                         (content (format "unreadable (%s)"
                                          (wf-manager-unreadable-run-category content)))
                         (t "not yet observed")))
           (format "Verification: %s"
                   (if verification
                       (concat (wf-manager-verification-state verification)
                               (if (wf-manager-verification-reason verification)
                                   (format " (%s)" (wf-manager-verification-reason verification))
                                 ""))
                     "not yet observed")))
     (cond ((null queue) (list "Decisions: not yet observed"))
           ((null pending) (list "Decisions: none pending"))
           (t (cons (format "Decisions: %d pending" (length pending))
                    (mapcar #'wf-service--decision-line pending))))
     (list (format "Offers: %s"
                   (if (null control)
                       "not yet observed"
                     (let ((operations (delete-dups
                                        (append (mapcar #'wf-manager-control-offer-operation
                                                        (wf-manager-control-offers control))
                                                (and (wf-manager-control-cancel-allowed control)
                                                     (list "cancel"))))))
                       (if operations (string-join operations ", ") "none")))))
     (wf-service--outcome-lines view))))

(defun wf-service--view-text (view)
  "Return the text of the buffer of VIEW."
  (let ((lines (wf-service-view-lines view)))
    (concat (car lines) "\n"
            "a answer the head decision · c control · C-c C-k cancel · r save the verified result\n"
            "R restart · S resume · F fork · g rerun as a restart · E export\n"
            "H history · d diagnostics · q bury (does not cancel)\n"
            "The kill of this buffer sends no command.\n\n"
            (mapconcat (lambda (line) (concat line "\n")) (cdr lines) ""))))

(defun wf-service--verified-artifact (outputs)
  "Return (DOWNLOAD BYTES SHA256) of the verified result of OUTPUTS, or nil.
OUTPUTS is the JSON value of the outputs of a run.  The artifact must
be the one that the verification of the result names."
  (cl-some
   (lambda (item)
     (let* ((verification (wf-service--member item "verification"))
            (artifact (wf-service--member item "artifact"))
            (size (wf-service--member artifact "bytes"))
            (bytes (cond ((and (stringp size) (string-match-p "\\`[0-9]+\\'" size))
                          (string-to-number size))
                         ((wf-manager-json-number-p size) (wf-service--number size)))))
       (and (equal (wf-service--member item "kind") "result")
            (equal (wf-service--member verification "state") "verified")
            (stringp (wf-service--member artifact "id"))
            (equal (wf-service--member artifact "id")
                   (wf-service--member verification "artifactId"))
            (stringp (wf-service--member artifact "download"))
            (stringp (wf-service--member artifact "sha256"))
            (integerp bytes)
            (list (wf-service--member artifact "download") bytes
                  (wf-service--member artifact "sha256")))))
   (let ((items (wf-service--member outputs "items")))
     (and (vectorp items) (append items nil)))))

(defun wf-service--view-retrieve (view)
  "Read the outputs of the run of VIEW and download its verified result.
The download checks the size and the SHA-256 digest, and VIEW keeps
only the size and the digest.  A result that the manager has not
verified yet waits for the next change of the snapshot."
  (let* ((session (wf-service--view-session view))
         (run (wf-service--view-run view))
         (finish (lambda (result)
                   (setf (wf-service--view-result view) result)
                   (wf-service--view-render view))))
    (setf (wf-service--view-result view) 'retrieving)
    (wf-manager-session-read
     session (wf-manager-session-reference session (format "/v1/runs/%s/outputs" run))
     (lambda (outcome)
       (cond
        ((not (buffer-live-p (wf-service--view-buffer view))))
        ((wf-manager-failure-p outcome)
         (funcall finish (list 'failed (wf-service--failure-text outcome))))
        (t
         (pcase (wf-service--verified-artifact (wf-manager-reply-value outcome))
           ('nil (funcall finish 'waiting))
           (`(,download ,bytes ,sha256)
            (condition-case failure
                (wf-manager-session-download
                 session (wf-manager-session-reference session download) bytes sha256
                 (lambda (downloaded)
                   (when (buffer-live-p (wf-service--view-buffer view))
                     (funcall finish
                              (if (wf-manager-failure-p downloaded)
                                  (list 'failed (wf-service--failure-text downloaded))
                                (list 'verified (length downloaded) sha256))))))
              (wf-manager-error
               (funcall finish (list 'failed (wf-service--failure-text failure)))))))))))))

(defun wf-service--view-render (view)
  "Update VIEW from its session, start its result retrieval and draw it."
  (let ((buffer (wf-service--view-buffer view)))
    (when (buffer-live-p buffer)
      (wf-service--view-take view)
      (let* ((kept (wf-service--view-kept view))
             (snapshot (alist-get 'snapshot kept))
             (etag (alist-get 'snapshot (wf-service--view-etags view)))
             (verification (wf-service--member (wf-service--member snapshot "verification")
                                               "state")))
        (when (and (equal (wf-service--snapshot-status snapshot) "succeeded")
                   (member verification '("verified" "referenced"))
                   (not (eq (wf-service--view-result view) 'retrieving))
                   (not (eq (car-safe (wf-service--view-result view)) 'verified))
                   (not (wf-manager-session-closed (wf-service--view-session view)))
                   (not (equal etag (wf-service--view-attempted view))))
          (setf (wf-service--view-attempted view) etag)
          (wf-service--view-retrieve view)))
      (with-current-buffer buffer
        (let ((inhibit-read-only t)
              (line (line-number-at-pos)))
          (erase-buffer)
          (insert (wf-service--view-text view))
          (goto-char (point-min))
          (forward-line (1- line)))
        (set-buffer-modified-p nil)))))

(defun wf-service--views-changed (session)
  "Draw again each run view of SESSION."
  (maphash (lambda (_key buffer)
             (when (buffer-live-p buffer)
               (let ((view (buffer-local-value 'wf-service--view-state buffer)))
                 (when (and view (eq (wf-service--view-session view) session))
                   (wf-service--view-render view)))))
           wf-service--views))

(defun wf-service--view-killed ()
  "Forget the run view of this buffer and stop the watches of its resources.
Nothing is sent, so the run continues."
  (let ((view wf-service--view-state))
    (when view
      (let ((key (cons (wf-service--view-identity view) (wf-service--view-run view))))
        (when (eq (gethash key wf-service--views) (current-buffer))
          (remhash key wf-service--views)))
      (dolist (reference (wf-service--view-references view))
        (wf-manager-session-unwatch (wf-service--view-session view) (cdr reference))))))

(defun wf-service-open-view (session run)
  "On SESSION, open the run view of RUN, select it and return its buffer.
The view of the endpoint identity of SESSION and RUN is reused when
it is live.  The session watches the resources of the run."
  (unless (wf-manager-valid-id-p run)
    (user-error "%S is not a run identifier" run))
  (let* ((identity (wf-manager-session-identity session))
         (key (cons identity run))
         (buffer (gethash key wf-service--views))
         (view (and (buffer-live-p buffer) (buffer-local-value 'wf-service--view-state buffer))))
    (unless (and view (eq (wf-service--view-session view) session))
      (unless (buffer-live-p buffer)
        (setq buffer (generate-new-buffer (format "*wf service run %s*" run))))
      (setq view (wf-service--view-make
                  :session session :identity identity :run run :buffer buffer
                  :references (mapcar (pcase-lambda (`(,name ,path ,_))
                                        (cons name (wf-manager-session-reference
                                                    session (format path run))))
                                      wf-service--view-resources)))
      (with-current-buffer buffer
        (wf-service-run-mode)
        (setq wf-service--view-state view)
        (add-hook 'kill-buffer-hook #'wf-service--view-killed nil t))
      (puthash key buffer wf-service--views)
      (dolist (reference (wf-service--view-references view))
        (condition-case failure
            (wf-manager-session-watch session (cdr reference))
          (wf-manager-error (wf-service--refuse "The run cannot be followed" failure)))))
    (wf-service--view-render view)
    (pop-to-buffer buffer)
    buffer))

(defun wf-service--service-runs (session)
  "Return the run identifiers that SESSION knows, the oldest view first.
They are the runs of the open views of SESSION and the run members of
its installed overview."
  (let ((runs nil)
        (overview (wf-manager-session-overview session)))
    (maphash (lambda (_key buffer)
               (let ((view (and (buffer-live-p buffer)
                                (buffer-local-value 'wf-service--view-state buffer))))
                 (when (and view (eq (wf-service--view-session view) session))
                   (push (wf-service--view-run view) runs))))
             wf-service--views)
    (when (wf-manager-overview-p overview)
      (dolist (item (wf-manager-overview-items overview))
        (let ((member (wf-manager-overview-item-member item)))
          (when (equal (wf-manager-overview-member-kind member) "run")
            (push (wf-manager-run-id (wf-manager-overview-member-value member)) runs)))))
    (delete-dups (nreverse runs))))

(defun wf-service-runs-choices (session)
  "Return the choices of `wf-runs' in service mode for SESSION.
Each choice is (LABEL KIND . VALUE).  A local choice has the label
\"local:RUN — DIRECTORY\" and its `wf--session' of `wf--sessions'.  A
service choice has the label \"service:RUN\" and its run identifier.
The prefix of a label has no space, so a label can be typed in the
minibuffer."
  (append
   (mapcar (lambda (local)
             (cons (format "local:%s — %s" (alist-get 'runId (wf--session-prepared local))
                           (wf--session-directory local))
                   (cons 'local local)))
           wf--sessions)
   (mapcar (lambda (run) (cons (concat "service:" run) (cons 'service run)))
           (wf-service--service-runs session))))

(defun wf-service--runs ()
  "Open the view of a local session or of a run of the manager.
The choices are the local sessions of `wf--sessions' and the runs of
the session of service mode."
  (let* ((session (wf-service--session))
         (choices (wf-service-runs-choices session)))
    (unless choices
      (user-error "No local session and no run of the manager is known"))
    (pcase (cdr (assoc (completing-read "Run: " choices nil t) choices))
      (`(local . ,local) (wf--view local))
      (`(service . ,run) (wf-service-open-view session run)))))

;;;; Answers

(defvar wf-service--answer-drafts (make-hash-table :test #'equal)
  "The kept answer drafts, keyed by (IDENTITY DECISION-ID).")

(defun wf-service-answer-draft (identity decision)
  "Return the kept answer draft at the endpoint IDENTITY of DECISION, or nil."
  (gethash (list identity decision) wf-service--answer-drafts))

(defun wf-service--answer-run (session)
  "Return the run whose head decision `wf-answer' answers on SESSION.
In a run view of SESSION, this is the run of the view.  Elsewhere, read
one run with a pending decision of the installed overview."
  (let ((view wf-service--view-state)
        (overview (wf-manager-session-overview session)))
    (if (and view (eq (wf-service--view-session view) session))
        (wf-service--view-run view)
      (let ((runs (and (wf-manager-overview-p overview)
                       (delete-dups
                        (delq nil
                              (mapcar (lambda (item)
                                        (let* ((member (wf-manager-overview-item-member item))
                                               (decision (wf-manager-overview-member-value member)))
                                          (and (equal (wf-manager-overview-member-kind member) "decision")
                                               (equal (wf-manager-decision-state decision) "pending")
                                               (wf-manager-decision-run-id decision))))
                                      (wf-manager-overview-items overview)))))))
        (unless runs
          (user-error "No run of the manager has a pending decision"))
        (completing-read "Run whose decision to answer: " runs nil t)))))

(defun wf-service--head (session run)
  "On SESSION, read the pending head decision of RUN and the controls of RUN.
Return (DECISION DECISION-REPLY CONTROL CONTROL-REPLY).  The head is
the pending decision at position 0 of the decision queue of RUN."
  (let* ((items (wf-service--collection session (concat "/v1/decisions?runId=" run)
                                        (format "decision queue of run %s" run)))
         (head (cl-find-if (lambda (decision)
                             (and (= (wf-manager-decision-position decision) 0)
                                  (equal (wf-manager-decision-state decision) "pending")))
                           (mapcar (lambda (item)
                                     (wf-service--decode #'wf-manager-decode-decision item "decision"))
                                   items))))
    (unless head
      (user-error "Run %s has no pending decision head" run))
    (let* ((decision-reply (wf-service--read session (concat "/v1/decisions/" (wf-manager-decision-id head))))
           (control-reply (wf-service--read session (concat "/v1/runs/" run "/control"))))
      (list (wf-service--decode #'wf-manager-decode-decision (wf-manager-reply-value decision-reply)
                                "decision")
            decision-reply
            (wf-service--decode #'wf-manager-decode-control (wf-manager-reply-value control-reply)
                                "controls")
            control-reply))))

(defun wf-service--decision-offers (control decision)
  "Return the items of the controls CONTROL for the head DECISION.
This is `decisionOffers' of `ext-pi/src/manager-ui.ts'.  The controls
must be owned and name DECISION as their head, and DECISION must be
the pending decision at position 0.  An offer of DECISION addresses
its occurrence with no attempt and its generation."
  (and (equal (wf-manager-control-run-id control) (wf-manager-decision-run-id decision))
       (equal (wf-manager-control-supervision control) "owned")
       (equal (wf-manager-control-decision-head-id control) (wf-manager-decision-id decision))
       (equal (wf-manager-decision-state decision) "pending")
       (= (wf-manager-decision-position decision) 0)
       (cl-remove-if-not
        (lambda (offer)
          (and (equal (wf-manager-control-offer-occurrence-id offer)
                      (wf-manager-decision-occurrence-id decision))
               (null (wf-manager-control-offer-attempt-id offer))
               (equal (wf-manager-control-offer-generation offer)
                      (wf-manager-decision-generation decision))))
        (wf-manager-control-offers control))))

(defun wf-service--answer-offered-p (control decision)
  "Return non-nil when the controls CONTROL offer an answer of the head DECISION."
  (and (cl-some (lambda (offer) (equal (wf-manager-control-offer-operation offer) "answer"))
                (wf-service--decision-offers control decision))
       t))

(defun wf-service--answer ()
  "Answer the head decision of a run of the manager in the answer editor.
The editor is `wf--answer-editor' with the kept draft of the decision.
Its text is sent by `wf-service--answer-send'."
  (let* ((session (wf-service--session))
         (run (wf-service--answer-run session)))
    (pcase-let ((`(,decision ,decision-reply ,control ,_) (wf-service--head session run)))
      (let ((content (wf-manager-decision-content decision))
            (identity (wf-manager-session-identity session))
            (stale nil))
        (unless (wf-manager-question-p content)
          (user-error "The head decision %s of run %s is a recovery decision.  Nothing was sent"
                      (wf-manager-decision-id decision) run))
        (unless (wf-service--answer-offered-p control decision)
          (user-error "The manager offers no answer for decision %s of run %s.  Nothing was sent"
                      (wf-manager-decision-id decision) run))
        (unless (wf-manager-reply-etag decision-reply)
          (user-error "Decision %s has no entity tag, so no answer can bind it"
                      (wf-manager-decision-id decision)))
        (wf--answer-editor
         nil nil nil
         (lambda (text)
           (when stale
             (user-error "Decision %s changed before this answer arrived.  M-x wf-answer reads the head again"
                         (wf-manager-decision-id decision)))
           (wf-service--answer-send session run decision decision-reply text
                                    (lambda () (setq stale t))))
         (or (wf-service-answer-draft identity (wf-manager-decision-id decision)) "")
         (format "Answer of decision %s (%s): %s — C-c C-c sends, C-c C-k abandons"
                 (wf-manager-decision-id decision)
                 (let ((code (wf-manager-question-code content)))
                   (if (stringp code) code "structured JSON"))
                 (wf-service--one-line (wf-manager-question-prompt content))))))))

(defun wf-service--answer-send (session run decision reply text stale)
  "On SESSION, send for RUN the answer of DECISION one time.
REPLY is the read of DECISION, whose entity tag the answer binds as
If-Match, and TEXT is the typed answer.  TEXT is kept as the draft of
DECISION until the answer reaches its effect.  A 412 refusal calls the
function STALE, reports the kept draft and signals.  An uncertain send
is reconciled with one read, and nothing is sent again.  Return nil
after the effect."
  (let* ((identity (wf-manager-session-identity session))
         (id (wf-manager-decision-id decision))
         (value (condition-case failure
                    (wf-manager-answer-value decision text)
                  (wf-manager-error
                   (user-error "%s" (wf-service--problem
                                     (format "The answer is refused before any send: %s.  The draft is kept"
                                             (nth 2 failure))))))))
    (puthash (list identity id) text wf-service--answer-drafts)
    (let* ((control (wf-service--read session (concat "/v1/runs/" run "/control")))
           (reconciliation
            (wf-service--await
             (lambda (callback)
               (wf-manager-session-answer-reconciliation
                session decision value
                (wf-manager-reconcile-target-make
                 :location (wf-manager-session-reference session (concat "/v1/runs/" run "/control"))
                 :precondition (wf-manager-reply-etag control))
                callback)
               nil)))
           (command (wf-service--prepare session (concat "/v1/decisions/" id)
                                         (wf-manager-answer-body decision value)
                                         (wf-manager-reply-etag reply)))
           (sent (wf-service--await
                  (lambda (callback) (wf-manager-session-send session command callback) nil)))
           (answer (wf-service--json-text value)))
      (pcase (wf-manager-sent-kind sent)
        ('delivered (wf-service--settle session sent "answer"))
        ('refused
         (if (equal (wf-manager-sent-failure sent) '(wf-manager-refused 412 "stale-revision"))
             (progn (funcall stale)
                    (wf-service--answer-stale session run decision text))
           (wf-service--refuse "The manager refused the answer" (wf-manager-sent-failure sent))))
        (_
         (pcase (wf-service--await
                 (lambda (callback)
                   (wf-manager-session-reconcile session (wf-manager-sent-uncertain sent)
                                                 reconciliation callback)
                   nil))
           ('(effect-observed) nil)
           ('(refused)
            (user-error "%s" (wf-service--problem
                              (format "The manager refused the answer of decision %s.  The draft is kept" id))))
           (_ (user-error "%s" (wf-service--problem
                                (format "The outcome of the answer %s of decision %s is uncertain after one read.  Nothing was sent again, and the draft is kept"
                                        answer id)))))))
      (remhash (list identity id) wf-service--answer-drafts)
      (message "wf: answer %s reached decision %s of run %s" answer id run)
      nil)))

(defun wf-service--answer-stale (session run decision text)
  "On SESSION, report the 412 refusal of an answer for RUN and signal.
The answer of DECISION was TEXT.  One read of DECISION tells whether
it is still the pending head.  The draft stays, and nothing is sent
again."
  (let* ((id (wf-manager-decision-id decision))
         (again (wf-service--await
                 (lambda (callback)
                   (wf-manager-session-read
                    session (wf-manager-session-reference session (concat "/v1/decisions/" id))
                    callback)
                   nil)))
         (current (and (wf-manager-reply-p again)
                       (condition-case nil (wf-manager-decode-decision (wf-manager-reply-value again))
                         (wf-manager-error nil)))))
    (user-error
     "%s"
     (wf-service--problem
      (concat
       (format "Decision %s changed before the answer arrived (412 stale-revision).  Nothing was sent again.  The draft %S is kept.  "
               id text)
       (if (and current (equal (wf-manager-decision-state current) "pending")
                (= (wf-manager-decision-position current) 0))
           (format "Decision %s is still the pending head, and M-x wf-answer opens the editor again with the draft" id)
         (format "Decision %s is no longer the pending head (%s), so the kept draft is not sent.  M-x wf-answer in the view of run %s acts on the next head"
                 id
                 (pcase again
                   (`(wf-manager-refused ,status ,code) (format "%s %s" status code))
                   ((pred wf-manager-failure-p) (wf-service--failure-text again))
                   (_ (if current
                          (format "state %s, position %d" (wf-manager-decision-state current)
                                  (wf-manager-decision-position current))
                        "the read does not decode")))
                 run)))))))

;;;; Controls

(defconst wf-service--accepting '("accepted" "queued" "delivered")
  "The acknowledgement states that accept, queue or deliver a control.")

(defconst wf-service--rejecting '("rejected-stale" "unsupported" "failed")
  "The acknowledgement states that end a control without an effect.")

(defun wf-service--acknowledgement (receipt)
  "Return (STATE MESSAGE) of the runtime acknowledgement of RECEIPT, or nil."
  (let ((acknowledgement (wf-manager-command-receipt-acknowledgement receipt)))
    (and (stringp (wf-service--member acknowledgement "state"))
         (list (wf-service--member acknowledgement "state")
               (wf-service--member acknowledgement "message")))))

(defun wf-service-control-settled-p (operation receipt)
  "Return non-nil when the control OPERATION has a settled RECEIPT.
This is `controlSettled' of `ext-pi/src/manager-ui.ts'.  Every receipt
settles at effect-observed, refused or unresolved.  An acknowledgement
that rejects the control settles it without an effect.  A cancel also
settles on an acknowledgement that accepts it, because the runtime
cancellation names no control, so its receipt records no effect."
  (or (and (wf-service--receipt-final-p receipt) t)
      (let ((state (car (wf-service--acknowledgement receipt))))
        (and (equal (wf-manager-command-receipt-state receipt) "acknowledged")
             state
             (or (member state wf-service--rejecting)
                 (and (equal operation "cancel") (member state wf-service--accepting)))
             t))))

(defun wf-service-acknowledgement-line (receipt)
  "Return the report of the runtime acknowledgement of RECEIPT.
The report names the state and the message of the acknowledgement
verbatim."
  (pcase (wf-service--acknowledgement receipt)
    (`(,state ,text) (format "Acknowledgement of command %s: %s: %s"
                             (wf-manager-command-receipt-id receipt) state (or text "")))
    (_ (format "Command %s has no runtime acknowledgement (receipt %s)"
               (wf-manager-command-receipt-id receipt)
               (wf-manager-command-receipt-state receipt)))))

(defun wf-service--cancel-offered-p (control)
  "Return non-nil when the owned controls CONTROL allow a cancel."
  (and (equal (wf-manager-control-supervision control) "owned")
       (wf-manager-control-cancel-allowed control)
       t))

(defun wf-service--offers (control operation)
  "Return the items of the owned controls CONTROL for OPERATION."
  (and (equal (wf-manager-control-supervision control) "owned")
       (cl-remove-if-not (lambda (offer)
                           (equal (wf-manager-control-offer-operation offer) operation))
                         (wf-manager-control-offers control))))

(defun wf-service-redirect-place (snapshot occurrence)
  "Return the place in the run SNAPSHOT of the redirect of OCCURRENCE.
This is `redirectPlace' of `ext-pi/src/manager-ui.ts'.  SNAPSHOT is the
JSON object of the snapshot, or nil.  The place is the open dispatch
window of the occurrence, its one attempt in flight, or neither."
  (let* ((items (wf-service--member snapshot "items"))
         (item (and (vectorp items)
                    (cl-find-if (lambda (item)
                                  (equal (wf-service--member item "occurrenceId")
                                         (number-to-string occurrence)))
                                (append items nil))))
         (attempts (wf-service--member item "attempts"))
         (running (and (vectorp attempts)
                       (cl-remove-if-not (lambda (attempt)
                                           (equal (wf-service--member attempt "state") "running"))
                                         (append attempts nil)))))
    (cond ((null item) "place not published")
          ((eq (wf-service--member (wf-service--member item "dispatch") "open") t)
           "dispatch window open")
          ((= (length running) 1)
           (format "attempt %s in flight"
                   (wf-service--member (wf-service--member (car running) "address") "attemptId")))
          (t "place not published"))))

(defun wf-service--recovery-actions (control decision)
  "Return the recovery actions of CONTROL for the head DECISION.
This is `recoveryActions' of `ext-pi/src/manager-ui.ts'.  Each action
is a plist with :operation, :option and :decision, in the order of the
choices of DECISION.  The choice retry is offered by a retry offer of
DECISION, and its operation is retry.  Another choice is offered by a
choose-recovery offer of DECISION with the same choice and target, and
its operation is choose-recovery.  A choice without an offer is not
listed, and a question has no recovery action."
  (let ((content (and decision (wf-manager-decision-content decision))))
    (when (wf-manager-recovery-p content)
      (let ((offers (wf-service--decision-offers control decision)))
        (delq nil
              (mapcar
               (lambda (option)
                 (let ((choice (wf-manager-recovery-option-choice option))
                       (target (wf-manager-recovery-option-target option)))
                   (cond
                    ((and (equal choice "retry")
                          (cl-some (lambda (offer)
                                     (equal (wf-manager-control-offer-operation offer) "retry"))
                                   offers))
                     (list :operation "retry" :option option :decision decision))
                    ((cl-some (lambda (offer)
                                (and (equal (wf-manager-control-offer-operation offer)
                                            "choose-recovery")
                                     (cl-some (lambda (item)
                                                (and (equal (wf-manager-recovery-option-choice item)
                                                            choice)
                                                     (equal (wf-manager-recovery-option-target item)
                                                            target)))
                                              (wf-manager-control-offer-choices offer))))
                              offers)
                     (list :operation "choose-recovery" :option option :decision decision)))))
               (wf-manager-recovery-choices content)))))))

(defun wf-service-control-choices (run control decision snapshot)
  "Return the choices of `wf-control' for RUN.
CONTROL is the `wf-manager-control' of one read of the controls of
RUN.  DECISION is the `wf-manager-decision' of the head that CONTROL
names, or nil.  SNAPSHOT is the JSON object of the run snapshot, or
nil, and it names the place of each redirect.  Each choice is (LABEL
DESCRIPTION . ACTION).  LABEL has no space, so it can be typed in the
minibuffer.  ACTION is a plist whose :operation is the operation of
the command.  The choices are only what CONTROL offers, in this order:
cancel when the owned controls allow it, one steer:N for each timing of
each steer offer with an attempt, one redirect:N for each target of
each redirect offer, and the recovery actions of the head DECISION:
retry, abandon and one failover:N for each failover choice."
  (let ((choices nil) (steers 0) (redirects 0) (failovers 0))
    (when (wf-service--cancel-offered-p control)
      (push (cons "cancel" (cons (format "cancel run %s after a confirmation" run)
                                 (list :operation "cancel")))
            choices))
    (dolist (offer (wf-service--offers control "steer"))
      (when (wf-manager-control-offer-attempt-id offer)
        (dolist (timing (wf-manager-control-offer-timings offer))
          (push (cons (format "steer:%d" (cl-incf steers))
                      (cons (format "steer occurrence %d attempt %d, %s"
                                    (wf-manager-control-offer-occurrence-id offer)
                                    (wf-manager-control-offer-attempt-id offer) timing)
                            (list :operation "steer" :offer offer :timing timing)))
                choices))))
    (dolist (offer (wf-service--offers control "redirect"))
      (dolist (target (wf-manager-control-offer-targets offer))
        (push (cons (format "redirect:%d" (cl-incf redirects))
                    (cons (format "redirect occurrence %d to %s, %s"
                                  (wf-manager-control-offer-occurrence-id offer) target
                                  (wf-service-redirect-place
                                   snapshot (wf-manager-control-offer-occurrence-id offer)))
                          (list :operation "redirect" :offer offer :target target)))
              choices)))
    (dolist (action (wf-service--recovery-actions control decision))
      (let* ((option (plist-get action :option))
             (choice (wf-manager-recovery-option-choice option))
             (target (wf-manager-recovery-option-target option)))
        (push (cons (if (equal choice "failover")
                        (format "failover:%d" (cl-incf failovers))
                      choice)
                    (cons (format "%s%s of decision %s, occurrence %d" choice
                                  (if target (format " to %s" target) "")
                                  (wf-manager-decision-id decision)
                                  (wf-manager-decision-occurrence-id decision))
                          action))
              choices)))
    (nreverse choices)))

(defun wf-service--controls (session run)
  "On SESSION, read the controls of RUN one time.
Return (CONTROL . REPLY): the `wf-manager-control' and the
`wf-manager-reply' whose entity tag a control binds as If-Match."
  (let* ((reply (wf-service--read session (concat "/v1/runs/" run "/control")))
         (control (wf-service--decode #'wf-manager-decode-control
                                      (wf-manager-reply-value reply) "controls")))
    (unless (equal (wf-manager-control-run-id control) run)
      (user-error "The controls of run %s name run %s.  Nothing was sent"
                  run (wf-manager-control-run-id control)))
    (unless (wf-manager-reply-etag reply)
      (user-error "The controls of run %s have no entity tag, so no control can bind them" run))
    (cons control reply)))

(defun wf-service--read-optional (session uri decode)
  "On SESSION, return (VALUE . REPLY) of one read of URI, or nil.
VALUE is DECODE of the JSON value of the read.  A failed read and a
value that does not decode give nil."
  (let ((reply (wf-service--await
                (lambda (callback)
                  (wf-manager-session-read
                   session (wf-manager-session-reference session uri) callback)
                  nil))))
    (and (wf-manager-reply-p reply)
         (let ((value (condition-case nil (funcall decode (wf-manager-reply-value reply))
                        (wf-manager-error nil))))
           (and value (cons value reply))))))

(defun wf-service--control-command (session run operation uri body if-match reconciliation)
  "On SESSION, send for RUN the control OPERATION one time and settle it.
The command sends to URI the BODY with IF-MATCH.  A delivered command
waits until `wf-service-control-settled-p' holds for its receipt.  A
cancel must then have an acknowledgement that accepts it, and every
other control must have reached effect-observed.  A refused command
refuses.  An uncertain command is reconciled with one read under the
`wf-manager-reconciliation' RECONCILIATION, and it is never sent again.
Return the settled receipt, or the symbol `effect-observed' for an
uncertain command whose effect the read observed."
  (let* ((command (wf-service--prepare session uri body if-match))
         (sent (wf-service--await
                (lambda (callback) (wf-manager-session-send session command callback) nil)))
         (failure (wf-manager-sent-failure sent)))
    (pcase (wf-manager-sent-kind sent)
      ('delivered
       (let* ((receipt (wf-service--await-receipt
                        session sent operation
                        (lambda (receipt) (wf-service-control-settled-p operation receipt))))
              (accepted (car (wf-service--acknowledgement receipt))))
         (unless (if (equal operation "cancel")
                     (and (equal (wf-manager-command-receipt-state receipt) "acknowledged")
                          (member accepted wf-service--accepting))
                   (equal (wf-manager-command-receipt-state receipt) "effect-observed"))
           (user-error "%s" (wf-service--problem
                             (format "The %s of run %s did not reach its effect: receipt %s%s.  %s.  Nothing was sent again"
                                     operation run (wf-manager-command-receipt-state receipt)
                                     (if (wf-manager-command-receipt-refusal receipt)
                                         (format " (%s)" (wf-manager-command-receipt-refusal receipt))
                                       "")
                                     (wf-service-acknowledgement-line receipt)))))
         receipt))
      ('refused
       (wf-service--refuse (format "The manager refused the %s of run %s.  Nothing was sent again"
                                   operation run)
                           failure))
      (_
       (pcase (wf-service--await
               (lambda (callback)
                 (wf-manager-session-reconcile session (wf-manager-sent-uncertain sent)
                                               reconciliation callback)
                 nil))
         ('(effect-observed)
          (message "wf: the send of the %s of run %s was uncertain, and one read observes its effect.  It was not sent again"
                   operation run)
          'effect-observed)
         ('(refused)
          (user-error "%s" (wf-service--problem
                            (format "The send of the %s of run %s was uncertain, and its receipt states refused"
                                    operation run))))
         (_ (user-error "%s" (wf-service--problem
                              (format "The outcome of the %s of run %s is uncertain after one read%s.  Nothing was sent again"
                                      operation run
                                      (if failure
                                          (concat " (" (wf-service--failure-text failure) ")")
                                        ""))))))))))

(defun wf-service--no-effect ()
  "Return the reconciliation of a control whose target never states its effect.
The one read of an uncertain cancel, steer or redirect observes its
effect only through its receipt, so it otherwise stays uncertain."
  (wf-manager-reconciliation-make :visible #'ignore))

(defun wf-service--cancel (session run reply)
  "On SESSION, cancel RUN after a confirmation.
REPLY is the read of the controls of RUN, whose entity tag the cancel
binds as If-Match.  `wf-confirm-function' asks, and only a yes sends
the cancel.  The cancel completes on the runtime acknowledgement."
  (if (not (funcall wf-confirm-function (format "Cancel run %s of the manager? " run)))
      (message "wf: no cancel was sent for run %s" run)
    (let ((receipt (wf-service--control-command
                    session run "cancel" (concat "/v1/runs/" run "/control")
                    (wf-manager-json-object "operation" "cancel")
                    (wf-manager-reply-etag reply) (wf-service--no-effect))))
      (message "wf: the runtime accepted the cancel of run %s.  %s" run
               (if (wf-manager-command-receipt-p receipt)
                   (wf-service-acknowledgement-line receipt)
                 "The receipt was not read")))))

(defun wf-service--steer-editor (session run offer timing reply)
  "On SESSION, open for RUN the steer editor of OFFER with TIMING.
REPLY is the read of the controls of RUN, whose entity tag the steer
binds as If-Match.  The send key of the editor sends its text one
time, and empty text sends nothing.  After the send, a second send
refuses, so nothing is sent again.  The abandon key closes the editor.
The header line of the editor names both keys."
  (let ((buffer (generate-new-buffer (format "*wf steer %s*" run)))
        (sent nil)
        (occurrence (wf-manager-control-offer-occurrence-id offer))
        (attempt (wf-manager-control-offer-attempt-id offer)))
    (with-current-buffer buffer
      (text-mode)
      (use-local-map (make-sparse-keymap))
      (setq-local header-line-format
                  (format "Steer %s of occurrence %d attempt %d of run %s — C-c C-c sends, C-c C-k abandons"
                          timing occurrence attempt run))
      (local-set-key
       (kbd "C-c C-c")
       (lambda ()
         (interactive)
         (let ((text (buffer-substring-no-properties (point-min) (point-max))))
           (when sent
             (user-error "This steer was sent one time.  Nothing was sent again.  M-x wf-control reads the controls again"))
           (when (string-blank-p text)
             (user-error "The steering text is empty.  Nothing was sent"))
           (setq sent t)
           (wf-service--control-command
            session run "steer" (concat "/v1/runs/" run "/control")
            (wf-manager-json-object "operation" "steer"
                                    "occurrenceId" (number-to-string occurrence)
                                    "attemptId" (number-to-string attempt)
                                    "timing" timing "text" text)
            (wf-manager-reply-etag reply) (wf-service--no-effect))
           (kill-buffer buffer)
           (message "wf: steer %s reached occurrence %d attempt %d of run %s"
                    timing occurrence attempt run))))
      (local-set-key (kbd "C-c C-k") (lambda () (interactive) (kill-buffer buffer))))
    (pop-to-buffer buffer '(display-buffer-pop-up-window))))

(defun wf-service--control-act (session run action reply)
  "On SESSION, act for RUN on the chosen control ACTION.
ACTION is the plist of a choice of `wf-service-control-choices'.  REPLY
is the read of the controls of RUN."
  (let ((control-uri (concat "/v1/runs/" run "/control"))
        (etag (wf-manager-reply-etag reply))
        (offer (plist-get action :offer))
        (decision (plist-get action :decision)))
    (pcase (plist-get action :operation)
      ("cancel" (wf-service--cancel session run reply))
      ("steer" (wf-service--steer-editor session run offer (plist-get action :timing) reply))
      ("redirect"
       (wf-service--control-command
        session run "redirect" control-uri
        (wf-manager-json-object "operation" "redirect"
                                "occurrenceId" (number-to-string
                                                (wf-manager-control-offer-occurrence-id offer))
                                "target" (plist-get action :target))
        etag (wf-service--no-effect))
       (message "wf: redirected occurrence %d of run %s to %s"
                (wf-manager-control-offer-occurrence-id offer) run (plist-get action :target)))
      ("retry"
       (wf-service--control-command
        session run "retry" control-uri
        (wf-manager-json-object "operation" "retry"
                                "occurrenceId" (number-to-string
                                                (wf-manager-decision-occurrence-id decision))
                                "generation" (wf-manager-decision-generation decision))
        etag
        (wf-manager-reconciliation-make
         :visible (lambda (observed) (wf-manager-control-passed observed decision 'recovery))))
       (message "wf: retry reached decision %s of run %s" (wf-manager-decision-id decision) run))
      ("choose-recovery"
       (let* ((id (wf-manager-decision-id decision))
              (read (wf-service--read session (concat "/v1/decisions/" id)))
              (choice (wf-manager-recovery-option-choice (plist-get action :option))))
         (unless (wf-manager-reply-etag read)
           (user-error "Decision %s has no entity tag, so no recovery choice can bind it" id))
         ;; The manager serves only pending decisions, so the controls of
         ;; the run reconcile the choice.
         (wf-service--control-command
          session run "choose-recovery" (concat "/v1/decisions/" id)
          (wf-manager-json-object "operation" "choose-recovery"
                                  "occurrenceId" (number-to-string
                                                  (wf-manager-decision-occurrence-id decision))
                                  "generation" (wf-manager-decision-generation decision)
                                  "choice" choice)
          (wf-manager-reply-etag read)
          (wf-manager-recovery-reconciliation
           decision (wf-manager-reconcile-target-make
                     :location (wf-manager-session-reference session control-uri)
                     :precondition etag)))
         (message "wf: %s reached decision %s of run %s" choice id run))))))

(defun wf-service-control-read (session run)
  "On SESSION, read the choices of `wf-control' for RUN.
Read the controls of RUN, the head decision that they name and, for a
redirect offer, the run snapshot, one time each.  Return (CHOICES .
REPLY): the choices of `wf-service-control-choices' and the read of the
controls, whose entity tag a control binds as If-Match."
  (pcase-let* ((`(,control . ,reply) (wf-service--controls session run))
               (head (wf-manager-control-decision-head-id control))
               (decision (and head (car (wf-service--read-optional
                                         session (concat "/v1/decisions/" head)
                                         #'wf-manager-decode-decision))))
               (snapshot (and (wf-service--offers control "redirect")
                              (car (wf-service--read-optional
                                    session (concat "/v1/runs/" run "/snapshot")
                                    #'wf-service--decode-object)))))
    (cons (wf-service-control-choices run control decision snapshot) reply)))

(defun wf-service--control ()
  "Send one control of a run of the manager that its controls offer.
In a run view, the run is the run of the view.  The command lists only
what the controls offer, as `wf-service-control-read' reads it, and
acts on the chosen control: a cancel after a confirmation, a steer
through its editor, or a redirect, a retry or a recovery choice at
once.  Each control is sent one time, and an uncertain send is
reconciled with one read and never sent again."
  (let* ((session (wf-service--session))
         (run (wf-service--run-here session "Run to control: ")))
    (pcase-let ((`(,choices . ,reply) (wf-service-control-read session run)))
      (unless choices
        (user-error "The manager offers no control for run %s.  Nothing was sent" run))
      (let* ((completion-extra-properties
              (list :annotation-function
                    (lambda (label) (concat "  " (cadr (assoc label choices))))))
             (label (completing-read (format "Control of run %s: " run) choices nil t)))
        (wf-service--control-act session run (cddr (assoc label choices)) reply)))))

(defun wf-service--kill ()
  "Cancel a run of the manager after a confirmation.
In a run view, the run is the run of the view.  The command reads the
controls of the run, and it refuses when they do not allow a cancel."
  (let* ((session (wf-service--session))
         (run (wf-service--run-here session "Run to cancel: ")))
    (pcase-let ((`(,control . ,reply) (wf-service--controls session run)))
      (unless (wf-service--cancel-offered-p control)
        (user-error "The manager offers no cancel for run %s.  Nothing was sent" run))
      (wf-service--cancel session run reply))))

(defun wf-service--kill-emacs ()
  "Close the transport of service mode when Emacs exits.
The close sends no command, so the runs and requests of the manager
continue."
  (when wf-service--current
    (wf-manager-session-close (wf-service--state-session wf-service--current))))

(add-hook 'kill-emacs-hook #'wf-service--kill-emacs)


;;; Results and history

(defun wf-service-save-exact (file bytes)
  "Save as the new FILE the unibyte BYTES unchanged, with mode 0600.
The creation is exclusive, so an existing FILE, a directory included,
refuses the save and stays as it is.  The bytes are written with no
coding conversion."
  (when (multibyte-string-p bytes)
    (error "The bytes of a saved result must be a unibyte string"))
  (condition-case failure
      (with-file-modes #o600
        (let ((coding-system-for-write 'no-conversion)
              (write-region-annotate-functions nil)
              (write-region-post-annotation-function nil))
          (write-region bytes nil file nil 'silent nil 'excl)))
    (file-already-exists
     (user-error "%s" (wf-service--problem
                       (format "%s exists, so the result was not saved.  Choose a new file"
                               file))))
    (file-error
     (user-error "%s" (wf-service--problem
                       (format "The result cannot be saved to %s: %s"
                               file (error-message-string failure)))))))

(defun wf-service--download (session download size sha256)
  "On SESSION, download the artifact DOWNLOAD and return its verified bytes.
SIZE and SHA256 are the size and the digest that the manager states.
A failure refuses."
  (let ((bytes (wf-service--await
                (lambda (callback)
                  (condition-case failure
                      (wf-manager-session-download
                       session (wf-manager-session-reference session download)
                       size sha256 callback)
                    (wf-manager-error (funcall callback failure)))
                  nil))))
    (when (wf-manager-failure-p bytes)
      (wf-service--refuse (format "The download of %s failed" download) bytes))
    bytes))

(defun wf-service--result ()
  "Save the verified result of a run of the manager to a new file.
The command reads GET /v1/runs/{id}/outputs, downloads the verified
artifact of the result with the verified download of the session and
then reads the name of a new file.  It saves the exact bytes there with
`wf-service-save-exact'.  A run with no verified result refuses, and
it sends nothing."
  (let* ((session (wf-service--session))
         (run (wf-service--run-here session "Run whose result to save: "))
         (outputs (wf-service--read session (format "/v1/runs/%s/outputs" run)))
         (artifact (wf-service--verified-artifact (wf-manager-reply-value outputs))))
    (unless artifact
      (user-error "%s" (wf-service--problem
                        (format "Run %s has no verified result to save" run))))
    (pcase-let* ((`(,download ,size ,sha256) artifact)
                 (bytes (wf-service--download session download size sha256))
                 (file (expand-file-name
                        (read-file-name
                         (format "Save the verified result of run %s to new file: " run)))))
      (wf-service-save-exact file bytes)
      (message "wf: saved the verified %d bytes of run %s to %s, SHA-256 %s"
               (length bytes) run file sha256)
      file)))

(cl-defstruct (wf-service--history
               (:constructor wf-service--history-make)
               (:copier nil))
  "The listing of one service history buffer.
IDENTITY is the endpoint identity of the binding that read it.  RUNS
is the list of its `wf-manager-run' records in the order of the
collection.  PAGES is the number of pages of the page set."
  identity runs pages)

(defvar-local wf-service--history-state nil
  "The `wf-service--history' of this service history buffer.")

(defvar-keymap wf-service-history-mode-map
  :doc "The keys of a service history buffer."
  :parent tabulated-list-mode-map
  "RET" #'wf-service-history-open
  "g" #'wf-service-history-refresh)

(define-derived-mode wf-service-history-mode tabulated-list-mode "wf-service-history"
  "Browse every run of the run collection of the manager.
The rows are in the order of the collection, managed runs and legacy
entries alike.  `wf-service-history-open' opens the run view of a row,
and `wf-service-history-refresh' reads the collection again.  Each row
keeps the reference of the endpoint that listed it, and a row is never
opened on another endpoint.

\\{wf-service-history-mode-map}"
  (setq tabulated-list-format [("Run" 54 nil) ("Workflow" 20 nil) ("Profile" 12 nil)
                               ("Status" 18 nil) ("Supervision" 34 nil)
                               ("Lineage" 24 nil) ("Result" 12 nil)]
        tabulated-list-sort-key nil)
  (tabulated-list-init-header))

(defun wf-service-history-row (run)
  "Return the columns of the `wf-manager-run' RUN in a service history.
The columns are the run, the workflow, the profile, the runtime status,
the supervision, the lineage and the verification of the result.  A
legacy entry has the supervision `observer' and is labelled as a
read-only observer entry."
  (let ((content (wf-manager-run-content run)))
    (if (wf-manager-unreadable-run-p content)
        (vector (wf-manager-run-id run) "" (wf-manager-run-profile-id run)
                (format "unreadable (%s)" (wf-manager-unreadable-run-category content))
                "" "" "")
      (let ((runtime (wf-manager-known-run-runtime content))
            (supervision (wf-manager-known-run-supervision content))
            (parent (wf-manager-known-run-parent-run-id content)))
        (vector (wf-manager-run-id run)
                (wf-manager-known-run-workflow-id content)
                (wf-manager-run-profile-id run)
                (if runtime (wf-manager-run-runtime-status runtime) "no runtime evidence")
                (if (equal supervision "observer")
                    "observer (legacy entry, read only)"
                  supervision)
                (if (and parent (wf-manager-known-run-lineage content))
                    (format "%s of %s" (wf-manager-known-run-lineage content) parent)
                  "root")
                (wf-manager-verification-state
                 (wf-manager-known-run-verification content)))))))

(defun wf-service-history-observers (history)
  "Return the number of the legacy observer entries of HISTORY."
  (cl-count-if (lambda (run)
                 (let ((content (wf-manager-run-content run)))
                   (and (wf-manager-known-run-p content)
                        (equal (wf-manager-known-run-supervision content) "observer"))))
               (wf-service--history-runs history)))

(defun wf-service--history-load (session)
  "Read every page of the run collection on SESSION and draw this history.
Each row keeps the `wf-manager-reference' of its run on the binding of
SESSION.  A failure refuses and keeps the earlier rows."
  (let* ((set (wf-service--page-set session "/v1/runs" "run history"))
         (runs (mapcar (lambda (item)
                         (wf-service--decode #'wf-manager-decode-run item "run history"))
                       (wf-manager-page-set-items set)))
         (history (wf-service--history-make
                   :identity (wf-manager-session-identity session) :runs runs
                   :pages (wf-manager-page-set-pages set))))
    (setq wf-service--history-state history
          tabulated-list-entries
          (mapcar (lambda (run)
                    (list (cons (wf-manager-session-reference
                                 session (concat "/v1/runs/" (wf-manager-run-id run)))
                                run)
                          (wf-service-history-row run)))
                  runs))
    (tabulated-list-print t)
    (message "wf: history of %d managed runs and %d observer entries over %d pages"
             (- (length runs) (wf-service-history-observers history))
             (wf-service-history-observers history) (wf-service--history-pages history))))

(defun wf-service--history ()
  "Show every run of the run collection of the manager in a new history.
The buffer of `wf-service-history-mode' lists the runs over every page
of the collection, in its order.  A failure refuses and shows no
buffer."
  (let ((session (wf-service--session))
        (buffer (generate-new-buffer "*wf service history*"))
        (shown nil))
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (wf-service-history-mode)
            (wf-service--history-load session))
          (setq shown t))
      (unless shown (kill-buffer buffer)))
    (pop-to-buffer buffer)
    buffer))

(defun wf-service--history-here ()
  "Return the `wf-service--history' of this buffer, or refuse."
  (unless (and (derived-mode-p 'wf-service-history-mode) wf-service--history-state)
    (user-error "This buffer is not a service history.  Open one with `wf-history'"))
  wf-service--history-state)

(defun wf-service--run-here (session prompt)
  "Return the run that a command of SESSION acts on, reading it with PROMPT.
In a run view of SESSION, this is the run of the view.  In a service
history of the endpoint of SESSION, it is the run of the row at point.
Elsewhere, read one run that SESSION knows.  A history of another
endpoint refuses and reads nothing."
  (let ((view wf-service--view-state)
        (history (and (derived-mode-p 'wf-service-history-mode) wf-service--history-state))
        (row (and (derived-mode-p 'wf-service-history-mode) (tabulated-list-get-id))))
    (cond
     ((and view (eq (wf-service--view-session view) session))
      (wf-service--view-run view))
     ((and history row)
      (unless (equal (wf-service--history-identity history)
                     (wf-manager-session-identity session))
        (user-error "%s" (wf-service--problem
                          (format "This history lists the runs of endpoint %s, and service mode is bound to endpoint %s.  Nothing was sent"
                                  (wf-service--history-identity history)
                                  (wf-manager-session-identity session)))))
      (wf-manager-run-id (cdr row)))
     (t
      (let ((runs (wf-service--service-runs session)))
        (unless runs
          (user-error "No run of the manager is known.  Open a run with `wf-history' first"))
        (completing-read prompt runs nil t))))))

(defun wf-service-history-refresh ()
  "Read every page of the run collection again and draw this history again.
The history is read only on the endpoint that listed it.  When service
mode is bound to another endpoint, the command refuses and reads
nothing."
  (interactive)
  (let ((history (wf-service--history-here))
        (session (wf-service--session)))
    (unless (equal (wf-service--history-identity history)
                   (wf-manager-session-identity session))
      (user-error "%s" (wf-service--problem
                        (format "This history lists the runs of endpoint %s, and service mode is bound to endpoint %s.  Nothing was read"
                                (wf-service--history-identity history)
                                (wf-manager-session-identity session)))))
    (wf-service--history-load session)))

(defun wf-service-history-open ()
  "Open the run view of the history row at point.
The command reads the run with the reference that the row keeps, and
it then opens the view of the run with `wf-service-open-view'.  A
reference of another endpoint refuses with `wf-manager-wrong-endpoint'
and sends nothing, so the row is never opened on another endpoint."
  (interactive)
  (wf-service--history-here)
  (let ((entry (tabulated-list-get-id)))
    (unless entry
      (user-error "Select a run of the history"))
    (pcase-let* ((`(,reference . ,run) entry)
                 (session (wf-service--session))
                 (reply (wf-service--await
                         (lambda (callback)
                           (wf-manager-session-read session reference callback)
                           nil))))
      (when (wf-manager-failure-p reply)
        (wf-service--refuse (format "The history row of run %s cannot be opened"
                                    (wf-manager-run-id run))
                            reply))
      (wf-service-open-view session (wf-manager-run-id run)))))


;;; Lineage and exports

(defun wf-service--first-page (session uri decode run-of revision-of run what)
  "On SESSION, read the first page of the run collection URI one time.
DECODE decodes the JSON value of the page, RUN-OF gives the run of the
decoded page and REVISION-OF its revision.  The page must name RUN, and
its entity tag must be the strong tag of its revision, which a command
of the collection binds as If-Match.  WHAT names the collection in a
message.  Return (PAGE . ETAG)."
  (let* ((reply (wf-service--read session uri))
         (page (wf-service--decode decode (wf-manager-reply-value reply) what))
         (etag (wf-manager-reply-etag reply)))
    (unless (and (equal (funcall run-of page) run)
                 (equal etag (format "\"%s\"" (funcall revision-of page))))
      (user-error "%s" (wf-service--problem
                        (format "The %s does not name run %s with the entity tag of its revision.  Nothing was sent"
                                what run))))
    (cons page etag)))

(defun wf-service--reconciled-command (session uri body if-match what visible)
  "On SESSION, send to URI the command BODY with IF-MATCH one time and settle it.
WHAT names the command in a message.  VISIBLE is a function of the JSON
value of one read of URI, and it returns non-nil when that value shows
the effect of the command.  Return the receipt that reached
effect-observed, or the symbol `effect-observed' for an uncertain send
whose effect one read of URI observed.  A refused command refuses.  An
uncertain send is reconciled with that one read, and it is never sent
again."
  (let* ((command (wf-service--prepare session uri body if-match))
         (sent (wf-service--await
                (lambda (callback) (wf-manager-session-send session command callback) nil)))
         (failure (wf-manager-sent-failure sent)))
    (pcase (wf-manager-sent-kind sent)
      ('delivered (wf-service--settle session sent what))
      ('refused
       (wf-service--refuse (format "The manager refused the %s command.  Nothing was sent again" what)
                           failure))
      (_
       (pcase (wf-service--await
               (lambda (callback)
                 (wf-manager-session-reconcile
                  session (wf-manager-sent-uncertain sent)
                  (wf-manager-reconciliation-make
                   :visible visible
                   :supplied (wf-manager-reconcile-target-make
                              :location (wf-manager-session-reference session uri)
                              :precondition if-match))
                  callback)
                 nil))
         ('(effect-observed)
          (message "wf: the send of the %s command was uncertain, and one read observes its effect.  It was not sent again"
                   what)
          'effect-observed)
         ('(refused)
          (user-error "%s" (wf-service--problem
                            (format "The send of the %s command was uncertain, and its receipt states refused"
                                    what))))
         (_ (user-error "%s" (wf-service--problem
                              (format "The outcome of the %s command is uncertain after one read%s.  Nothing was sent again"
                                      what (if failure
                                               (concat " (" (wf-service--failure-text failure) ")")
                                             ""))))))))))

(defun wf-service--effect (receipt kind)
  "Return the resource of the effect of RECEIPT when its kind is KIND.
Return nil otherwise.  RECEIPT is a `wf-manager-command-receipt' or the
symbol `effect-observed' of a reconciled send, which names no effect."
  (let ((effect (and (wf-manager-command-receipt-p receipt)
                     (wf-manager-command-receipt-effect receipt))))
    (and (equal (wf-service--member effect "kind") kind)
         (wf-service--member effect "resource"))))

(defun wf-service-fork-targets (snapshot)
  "Return the fork targets of the run SNAPSHOT, in occurrence order.
SNAPSHOT is the JSON object of a run snapshot, or nil.  A target is an
occurrence that the runtime completed or reused, so its answer is
persisted.  This is `forkTargets' of `ext-pi/src/manager-ui.ts'.  Each
target is a plist with :occurrence, the occurrence number, :code, the
observation code, :intent, the intent text, and :answer, the published
answer text or nil."
  (let ((items (wf-service--member snapshot "items"))
        (targets nil))
    (when (vectorp items)
      (dolist (item (append items nil))
        (let ((id (wf-service--member item "occurrenceId"))
              (code (wf-service--member item "code"))
              (intent (wf-service--member item "intent"))
              (answer (wf-service--member item "answer")))
          (when (and (stringp id)
                     (string-match-p "\\`\\(?:0\\|[1-9][0-9]*\\)\\'" id)
                     (stringp code)
                     (member (wf-service--member item "state") '("completed" "reused")))
            (push (list :occurrence (string-to-number id) :code code
                        :intent (if (stringp intent) intent "")
                        :answer (and (stringp answer) answer))
                  targets)))))
    (sort targets (lambda (a b) (< (plist-get a :occurrence) (plist-get b :occurrence))))))

(defun wf-service--edit-label (edit)
  "Return the text of the fork EDIT of an occurrence, or keep for nil."
  (cond ((null edit) "keep")
        ((equal (wf-manager-fork-edit-operation edit) "drop") "drop")
        (t (concat "replace with " (wf-service--json-text (wf-manager-fork-edit-answer edit))))))

(defun wf-service--fork-replacement (run target current)
  "For RUN, read the replacement answer of the fork TARGET in the minibuffer.
TARGET is a plist of `wf-service-fork-targets', and CURRENT is the
earlier edit of its occurrence, or nil.  The minibuffer starts with the
answer of CURRENT, or else with the published answer of TARGET.
`wf-manager-fork-replacement-value' types the text by the code of
TARGET, and a refused text is read again with the text.  Return the
replace edit."
  (let* ((occurrence (plist-get target :occurrence))
         (code (plist-get target :code))
         (text (if (and current (equal (wf-manager-fork-edit-operation current) "replace"))
                   (let ((answer (wf-manager-fork-edit-answer current)))
                     (if (and (stringp answer) (equal code "text"))
                         answer
                       (wf-service--json-text answer)))
                 (or (plist-get target :answer) "")))
         (edit nil))
    (while (not edit)
      (setq text (read-from-minibuffer
                  (format "Replacement answer of occurrence %d (%s) of run %s: " occurrence code run)
                  text))
      (condition-case failure
          (setq edit (wf-manager-fork-edit-make
                      :operation "replace" :occurrence-id occurrence
                      :answer (wf-manager-fork-replacement-value code text)))
        (wf-manager-invalid-answer
         (message "wf: the replacement is refused before any send: %s.  The text is read again"
                  (nth 2 failure)))))
    edit))

(defun wf-service--fork-edits (session run)
  "On SESSION, collect the edits of a fork of RUN from its snapshot.
For each target of `wf-service-fork-targets', the choice keep, drop or
replace edits its answer, and a replacement is read by
`wf-service--fork-replacement'.  The label `send' returns the list of
the `wf-manager-fork-edit' records, and the label `stop' refuses with
nothing sent."
  (let* ((snapshot (car (wf-service--read-optional
                         session (format "/v1/runs/%s/snapshot" run) #'wf-service--decode-object)))
         (targets (wf-service-fork-targets snapshot))
         (edits nil)
         (done nil))
    (unless snapshot
      (user-error "%s" (wf-service--problem
                        (format "The snapshot of run %s cannot be read.  Nothing was sent" run))))
    (unless targets
      (user-error "Run %s has no completed occurrence whose answer a fork edits.  Nothing was sent" run))
    (while (not done)
      (let* ((choices (append
                       (mapcar (lambda (target)
                                 (let ((occurrence (plist-get target :occurrence)))
                                   (list (format "occurrence:%d" occurrence)
                                         (format "(%s): %s; %s" (plist-get target :code)
                                                 (wf-service--edit-label
                                                  (alist-get occurrence edits nil nil #'eql))
                                                 (wf-service--one-line (plist-get target :intent)))
                                         target)))
                               targets)
                       (list (list "send" "send the fork with these edits")
                             (list "stop" "stop without a fork"))))
             (completion-extra-properties
              (list :annotation-function
                    (lambda (label) (concat "  " (cadr (assoc label choices))))))
             (label (completing-read (format "Fork edits of run %s: " run) choices nil t)))
        (pcase label
          ("send" (setq done t))
          ("stop" (user-error "No fork was sent for run %s" run))
          (_
           (let* ((target (nth 2 (assoc label choices)))
                  (occurrence (plist-get target :occurrence))
                  (current (alist-get occurrence edits nil nil #'eql))
                  (action (completing-read (format "Answer of occurrence %d of run %s: " occurrence run)
                                           '("keep" "drop" "replace") nil t)))
             (setq edits (cl-remove occurrence edits :key #'car :test #'eql))
             (pcase action
               ("drop" (push (cons occurrence (wf-manager-fork-edit-make
                                               :operation "drop" :occurrence-id occurrence))
                             edits))
               ("replace" (push (cons occurrence (wf-service--fork-replacement run target current))
                                edits))))))))
    (mapcar #'cdr edits)))

(defun wf-service--continue (session reference)
  "On SESSION, enqueue the child request REFERENCE and show its exact review.
The child takes its inputs from its parent run, so a draft is enqueued
at once.  A request that has left the open phases refuses with its
admission line."
  (let ((draft (car (wf-service--read-draft session reference))))
    (when (equal (wf-manager-draft-phase draft) "draft")
      (wf-service--enqueue session reference)
      (setq draft (car (wf-service--read-draft session reference))))
    (unless (member (wf-manager-draft-phase draft) wf-service--open-phases)
      (user-error "%s" (wf-service--problem (wf-service-admission-line draft))))
    (wf-service--open-review session reference)))

(defun wf-service--lineage (operation)
  "Create a child request of OPERATION for a run and show its exact review.
OPERATION is restart, resume or fork.  The run is chosen by
`wf-service--run-here'.  The command reads the first page of the
lineage collection of the run and refuses unless the page lists
OPERATION as eligible.  A fork collects its edits with
`wf-service--fork-edits'.  The lineage request binds the entity tag of
the page as If-Match, and it is sent one time.  After the effect
lineage-created, the child request is enqueued, and its exact review
shows its lineage.  Only the approval of that review starts the child
run."
  (let* ((session (wf-service--session))
         (run (wf-service--run-here session (format "Run to %s: " operation)))
         (uri (format "/v1/runs/%s/lineage-requests" run)))
    (pcase-let ((`(,page . ,etag)
                 (wf-service--first-page session uri #'wf-manager-decode-lineage-collection
                                         #'wf-manager-lineage-collection-run-id
                                         #'wf-manager-lineage-collection-revision run
                                         (format "lineage collection of run %s" run))))
      (let ((eligible (wf-manager-lineage-collection-eligible page)))
        (unless (member operation eligible)
          (user-error "%s" (wf-service--problem
                            (if eligible
                                (format "%s is not eligible: the manager lists only %s for run %s.  Nothing was sent"
                                        operation (string-join eligible ", ") run)
                              (format "%s is not eligible: the manager lists no lineage operation for run %s, refusal %s.  Nothing was sent"
                                      operation run (wf-manager-lineage-collection-refusal page)))))))
      (let* ((edits (and (equal operation "fork") (wf-service--fork-edits session run)))
             (known (mapcar #'wf-manager-draft-id (wf-manager-lineage-collection-children page)))
             (receipt (wf-service--reconciled-command
                       session uri (wf-manager-lineage-body operation edits) etag operation
                       (lambda (value)
                         (let ((current (condition-case nil
                                            (wf-manager-decode-lineage-collection value)
                                          (wf-manager-error nil))))
                           (and current
                                (cl-some (lambda (child)
                                           (and (not (member (wf-manager-draft-id child) known))
                                                (equal (wf-manager-draft-lineage child) operation)))
                                         (wf-manager-lineage-collection-children current)))))))
             (resource (wf-service--effect receipt "lineage-created")))
        (unless (and (stringp resource) (string-prefix-p "/v1/requests/" resource))
          (user-error "%s" (wf-service--problem
                            (format "The %s of run %s created a child request, and no receipt names it.  The lineage collection of run %s lists it"
                                    operation run run))))
        (message "wf: %s of run %s created child request %s.  Its inputs come from the parent run"
                 operation run (substring resource (length "/v1/requests/")))
        (wf-service--continue session (wf-manager-session-reference session resource))))))

(defun wf-service--restart ()
  "Create a restart child of a run of the manager and show its exact review."
  (wf-service--lineage "restart"))

(defun wf-service--resume ()
  "Create a resume child of a run of the manager and show its exact review."
  (wf-service--lineage "resume"))

(defun wf-service--fork ()
  "Create a fork child of a run of the manager with edits and show its review."
  (wf-service--lineage "fork"))

(defun wf-service--rerun ()
  "Run a run of the manager again as a restart child.
The manager has no fresh root setup of the directory of a run, so the
rerun of service mode is the restart of `wf-service--restart'."
  (wf-service--lineage "restart"))

(defun wf-service-export-lines (receipt downloaded collection)
  "Return the lines of the export RECEIPT, its DOWNLOADED size and COLLECTION.
DOWNLOADED is the number of the verified bytes of the download, and
COLLECTION is the `wf-manager-export-collection' of the run.  This is
`exportLines' of `ext-pi/src/manager-ui.ts' with the export list."
  (append
   (list (format "Export %s: %s state %s, command %s" (wf-manager-export-receipt-name receipt)
                 (wf-manager-export-receipt-id receipt) (wf-manager-export-receipt-state receipt)
                 (wf-manager-export-receipt-command-id receipt))
         (format "Export download: verified %d bytes, SHA-256 %s" downloaded
                 (or (wf-manager-export-receipt-sha256 receipt) "none"))
         (format "Exports of run %s: %d" (wf-manager-export-collection-run-id collection)
                 (length (wf-manager-export-collection-items collection))))
   (mapcar (lambda (item)
             (format "  %s  %s  %s  %s  SHA-256 %s" (wf-manager-export-receipt-name item)
                     (wf-manager-export-receipt-id item) (wf-manager-export-receipt-state item)
                     (if (wf-manager-export-receipt-bytes item)
                         (format "%d bytes" (wf-manager-export-receipt-bytes item))
                       "no size")
                     (or (wf-manager-export-receipt-sha256 item) "none")))
           (wf-manager-export-collection-items collection))))

;;;###autoload
(defun wf-export ()
  "Export the verified result of a run of the manager under a new name.
The run is chosen by `wf-service--run-here'.  The name is one ASCII
component of `wf-manager-export-name-valid-p'.  The command sends POST
/v1/runs/{id}/exports one time, with the entity tag of the first page
of the export collection as If-Match.  After the effect exported, it
reads the export receipt, downloads the exported bytes with the
verified download of the session, and shows the receipt, the verified
size and digest and the export collection in the buffer
`*wf export RUN/NAME*'.  Return that buffer.  Local mode has no export,
so the command refuses there and sends nothing."
  (interactive)
  (unless wf--service-dispatch
    (user-error "The command wf-export works only in service mode.  Select a profile with `wf-service'"))
  (let* ((session (wf-service--session))
         (run (wf-service--run-here session "Run whose result to export: "))
         (name (read-string (format "Export name for the verified result of run %s: " run)))
         (uri (format "/v1/runs/%s/exports" run))
         (what (format "export collection of run %s" run)))
    (unless (wf-manager-export-name-valid-p name)
      (user-error "The export name must be 1 to 128 ASCII letters, digits, dots, underscores or hyphens that start with a letter or a digit.  Nothing was sent"))
    (pcase-let* ((`(,_ . ,etag)
                  (wf-service--first-page session uri #'wf-manager-decode-export-collection
                                          #'wf-manager-export-collection-run-id
                                          #'wf-manager-export-collection-revision run what))
                 (receipt (wf-service--reconciled-command
                           session uri (wf-manager-json-object "name" name) etag "export"
                           (lambda (value)
                             (let ((current (condition-case nil
                                                (wf-manager-decode-export-collection value)
                                              (wf-manager-error nil))))
                               (and current
                                    (cl-some (lambda (item)
                                               (and (equal (wf-manager-export-receipt-name item) name)
                                                    (equal (wf-manager-export-receipt-state item)
                                                           "published")))
                                             (wf-manager-export-collection-items current)))))))
                 (command (and (wf-manager-command-receipt-p receipt)
                               (wf-manager-command-receipt-id receipt)))
                 (resource (and command (concat "/v1/exports/export_" command))))
      (unless (and resource (equal (wf-service--effect receipt "exported") resource))
        (user-error "%s" (wf-service--problem
                          (format "The export %s of run %s reached its effect, and no receipt names its export.  The export collection of run %s lists it"
                                  name run run))))
      (let ((detail (wf-service--decode #'wf-manager-decode-export-receipt
                                        (wf-manager-reply-value (wf-service--read session resource))
                                        "export receipt")))
        (unless (and (equal (wf-manager-export-receipt-id detail) (concat "export_" command))
                     (equal (wf-manager-export-receipt-command-id detail) command)
                     (equal (wf-manager-export-receipt-run-id detail) run)
                     (equal (wf-manager-export-receipt-name detail) name)
                     (equal (wf-manager-export-receipt-state detail) "published")
                     (wf-manager-export-receipt-bytes detail)
                     (wf-manager-export-receipt-sha256 detail)
                     (wf-manager-export-receipt-download detail))
          (user-error "%s" (wf-service--problem
                            (format "The export receipt %s does not state the published export %s of run %s"
                                    resource name run))))
        (let* ((bytes (wf-service--download session (wf-manager-export-receipt-download detail)
                                            (wf-manager-export-receipt-bytes detail)
                                            (wf-manager-export-receipt-sha256 detail)))
               (collection (car (wf-service--first-page
                                 session uri #'wf-manager-decode-export-collection
                                 #'wf-manager-export-collection-run-id
                                 #'wf-manager-export-collection-revision run what)))
               (lines (wf-service-export-lines detail (length bytes) collection))
               (buffer (wf--show (format "*wf export %s/%s*" run name)
                                 (mapconcat (lambda (line) (concat line "\n")) lines "")
                                 default-directory)))
          (pop-to-buffer buffer)
          (message "wf: %s" (car lines))
          buffer)))))


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
