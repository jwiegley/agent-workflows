;;; wf-manager-live.el --- Live checks of wf-manager.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 John Wiegley

;; Author: John Wiegley <johnw@newartisans.com>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The live check of the transport `wf-manager.el' against a running
;; agent-cat workflow manager.  The emacs-client mode of
;; `manager/test/service_http.py' in agent-cat starts the manager with
;; its mixed fixture, issues the client credential with the scopes
;; observe, submit, control and export and writes its version 1 client
;; profile.  It then runs this file in a batch Emacs with an isolated
;; home directory and `user-emacs-directory':
;;
;;     WF_MANAGER_PROFILE=/path/to/client-profile.json \
;;     WF_MANAGER_REPORT=/path/to/report.json \
;;     WF_MANAGER_RUN=/path/to/run.json \
;;     WF_MANAGER_REVOKE=/path/to/revoke.json \
;;       "$EMACS" -Q --batch -L ./emacs -l wf-manager-live \
;;       -f ert-run-tests-batch-and-exit
;;
;; `ci/emacs.sh' compiles and checks this file, and it does not run it.
;; The one test runs the steps of one session in order:
;;
;;   1. bind: `wf-manager-connect' binds a transport by GET
;;      /v1/capabilities over TLS, with the CA file of the profile as the
;;      only trust file.
;;   2. draft: a POST of a draft of the workflow `mixed-controls' with an
;;      idempotency key gives 201, and the same key with the same body
;;      gives the same draft.
;;   3. stale: a set-input command with the entity tag of the draft
;;      supplies `wf-manager-live-literal' and reaches its effect.  A
;;      second set-input with that earlier entity tag gives the typed
;;      refusal 412 stale-revision.
;;   4. pages: three more drafts of the workflow each receive a literal
;;      input of `wf-manager-live--page-characters' characters, so that
;;      the overview of the credential does not fit on one page.
;;   5. overview: `wf-manager-session-start' assembles the overview page
;;      set over all its pages and installs it, and the session then
;;      follows /v1/events with polling batches.
;;   6. follow: the test writes the file that WF_MANAGER_RUN names and
;;      waits for that name with the suffix .done, which the harness
;;      writes after it creates and approves a run with its own
;;      credential.  The run must then appear in the installed overview
;;      of the session through an event poll, with no other read by the
;;      test, and the delivery state must be `poll'.
;;   7. revoke: the test writes the file that WF_MANAGER_REVOKE names and
;;      waits for that name with the suffix .done, which the harness
;;      writes after it revokes the credential of the profile.  The
;;      follow loop of the session then ends with `refused', and the
;;      next GET gives the typed refusal 401 unauthenticated.
;;   8. close: `wf-manager-session-close' leaves no network process, no
;;      url.el buffer and no session directory.
;;
;; No step may prompt.  Each prompt function of
;; `wf-manager-live--prompt-functions' counts a call and signals an
;; error.  The test writes the report to the file that
;; WF_MANAGER_REPORT names, also when a step fails.  The report is one
;; JSON object with these fields:
;;
;;   harnessVersion    `wf-manager-live-harness-version'
;;   steps             the names of the completed steps, in order
;;   prompts           the number of prompts
;;   scheme            the URL scheme of the transport
;;   endpointIdentity  the endpoint identity of the binding
;;   authorityEpoch    the authority epoch of the capabilities
;;   workflowId        the workflow of the draft
;;   requestId         the identifier of the draft
;;   createStatus      the status of the first POST of the draft
;;   replayStatus      the status of the POST with the same key
;;   replayEqual       true when the two responses are equal JSON
;;   inputName         the name of the input of the set-input command
;;   literal           `wf-manager-live-literal'
;;   setInputCommand   the receipt resource of the set-input command
;;   setInputState     the state that the receipt reached
;;   staleTag          the entity tag of the draft before set-input
;;   currentTag        the entity tag of the draft after set-input
;;   staleRefusal      [412, CODE], the refusal of the stale command
;;   pageRequests      the identifiers of the three drafts of the pages step
;;   overviewPages     the number of pages of the first overview
;;   overviewRequests  the sorted identifiers of its request members
;;   overviewCursor    the event cursor of the first overview
;;   followRunId       the run that the harness created
;;   deliveryState     the delivery state when the run appeared
;;   polls             the number of polling batches until then
;;   generation        the refresh generation when the run appeared
;;   followEnd         the end of the follow loop after the revocation
;;   revokedRefusal    [401, CODE], the refusal after the revocation
;;   processesAfterClose  the number of new processes after close
;;   buffersAfterClose    the names of the new buffers after close
;;   directoryRemoved  true when the session directory is gone
;;
;; The harness compares `harnessVersion' with its own constant and
;; refuses a report of another version, so that a mismatched pair of the
;; two repositories fails with one sentence.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'wf-manager)

(defconst wf-manager-live-harness-version 2
  "The version of the report of this file.
The emacs-client mode of agent-cat states the same version.")

(defconst wf-manager-live-workflow "mixed-controls"
  "The name of the workflow of the draft of the live session.")

(defconst wf-manager-live-literal "Emacs \u03bb \u96ea\U0001F600 input."
  "The literal input that the set-input command supplies.")

(defconst wf-manager-live--seconds 40
  "The longest wait of one step of the live session, in seconds.")

(defconst wf-manager-live--run-seconds 150
  "The longest wait for the run of the harness, in seconds.")

(defconst wf-manager-live--page-drafts 3
  "The number of drafts of the pages step.")

(defconst wf-manager-live--page-characters 600000
  "The number of characters of the literal input of each page draft.
One such draft fills more than half of a page of 1048576 bytes.")

(defconst wf-manager-live--prompt-functions
  '(read-string read-passwd read-from-minibuffer yes-or-no-p y-or-n-p
    read-multiple-choice read-char-choice)
  "The functions that would ask a person a question.")

(defvar wf-manager-live--prompts 0
  "The number of prompts of the live session.")

(defun wf-manager-live--prompted (&rest _arguments)
  "Count one prompt of the live session and signal an error."
  (cl-incf wf-manager-live--prompts)
  (error "The live session prompted"))

(defun wf-manager-live--variable (name)
  "Return the value of the environment variable NAME.
An unset or empty variable signals an error that names it."
  (let ((value (getenv name)))
    (if (and value (not (string-empty-p value)))
        value
      (error "The environment variable %s is unset" name))))

(defun wf-manager-live--await (start)
  "Call START with a callback and return the one outcome of the callback.
Wait at most `wf-manager-live--seconds' for the outcome."
  (let ((outcomes nil)
        (deadline (+ (float-time) wf-manager-live--seconds)))
    (funcall start (lambda (outcome) (push outcome outcomes)))
    (while (and (null outcomes) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (should outcomes)
    (should (= (length outcomes) 1))
    (car outcomes)))

(defun wf-manager-live--get (connection resource)
  "On CONNECTION, return the `wf-manager-reply' of one GET of RESOURCE.
A failure fails the test."
  (let ((outcome (wf-manager-live--await
                  (lambda (callback)
                    (wf-manager-get (wf-manager-connection-transport connection)
                                    resource callback)))))
    (should-not (wf-manager-failure-p outcome))
    outcome))

(defun wf-manager-live--post (connection resource body key if-match)
  "On CONNECTION, send one POST to RESOURCE of BODY and return its outcome.
KEY is the idempotency key, and IF-MATCH the entity tag or nil.  The
outcome is a `wf-manager-reply' or a failure."
  (wf-manager-live--await
   (lambda (callback)
     (wf-manager-post (wf-manager-connection-transport connection)
                      resource body key if-match callback))))

(defun wf-manager-live--integer (integer)
  "Return the JSON number of INTEGER."
  (wf-manager-json-integer integer))

(defun wf-manager-live--refusal (failure)
  "Return the JSON array [STATUS, CODE] of the refusal FAILURE."
  (should (eq (car failure) 'wf-manager-refused))
  (vector (wf-manager-live--integer (nth 1 failure)) (nth 2 failure)))

(defun wf-manager-live--bind (profile report)
  "Bind a connection for PROFILE and record it in REPORT.
Return the `wf-manager-connection'."
  (let ((connection (wf-manager-live--await
                     (lambda (callback) (wf-manager-connect profile callback)))))
    (should-not (wf-manager-failure-p connection))
    (should (string-match-p "\\`[0-9a-f]\\{32\\}\\'"
                            (wf-manager-connection-identity connection)))
    (puthash "scheme" wf-manager--scheme report)
    (puthash "endpointIdentity" (wf-manager-connection-identity connection) report)
    (puthash "authorityEpoch" (wf-manager-connection-epoch connection) report)
    connection))

(defun wf-manager-live--workflow (connection)
  "Return the catalogue item of `wf-manager-live-workflow' on CONNECTION."
  (let* ((capabilities (wf-manager-capabilities-fields
                        (wf-manager-connection-capabilities connection)))
         (profile-id (aref (gethash "profileIds" capabilities) 0))
         (catalogue (wf-manager-reply-value
                     (wf-manager-live--get
                      connection (concat "/v1/workflows?profileId=" profile-id))))
         (item (cl-find wf-manager-live-workflow (gethash "items" catalogue)
                        :key (lambda (item) (gethash "name" item))
                        :test #'equal)))
    (should item)
    item))

(defun wf-manager-live--draft (connection workflow report)
  "On CONNECTION, create a draft of WORKFLOW two times with one key.
Record the two statuses in REPORT, and return the decoded draft."
  (let* ((body (wf-manager-json-object
                "workflowId" (gethash "id" workflow)
                "descriptorRevision" (gethash "revision" workflow)
                "profileId" (gethash "profileId" workflow)
                "profileRevision" (gethash "profileRevision" workflow)))
         (key (wf-manager-command-key connection))
         (created (wf-manager-live--post connection "/v1/requests" body key nil))
         (replayed (progn
                     (should-not (wf-manager-failure-p created))
                     (wf-manager-live--post connection "/v1/requests" body key nil)))
         (draft (progn
                  (should-not (wf-manager-failure-p replayed))
                  (wf-manager-decode-draft (wf-manager-reply-value created))))
         (again (wf-manager-decode-draft (wf-manager-reply-value replayed)))
         (equal (wf-manager-json-equal (wf-manager-reply-value created)
                                       (wf-manager-reply-value replayed))))
    (puthash "workflowId" (gethash "id" workflow) report)
    (puthash "requestId" (wf-manager-draft-id draft) report)
    (puthash "createStatus" (wf-manager-live--integer (wf-manager-reply-status created)) report)
    (puthash "replayStatus" (wf-manager-live--integer (wf-manager-reply-status replayed)) report)
    (puthash "replayEqual" (if equal t :false) report)
    (should (= (wf-manager-reply-status created) 201))
    (should (= (wf-manager-reply-status replayed) 201))
    (should (equal (wf-manager-draft-id again) (wf-manager-draft-id draft)))
    (should equal)
    draft))

(defun wf-manager-live--settle (connection resource)
  "On CONNECTION, read the command receipt RESOURCE until it settles.
Return the decoded `wf-manager-command-receipt'."
  (let ((deadline (+ (float-time) wf-manager-live--seconds))
        (receipt nil))
    (while (progn
             (setq receipt (wf-manager-decode-command-receipt
                            (wf-manager-reply-value
                             (wf-manager-live--get connection resource))))
             (and (not (member (wf-manager-command-receipt-state receipt)
                               '("effect-observed" "refused" "unresolved")))
                  (< (float-time) deadline)))
      (accept-process-output nil 0.05))
    receipt))

(defun wf-manager-live--stale (connection workflow draft report)
  "On CONNECTION, supply the input of WORKFLOW to DRAFT, then send it stale.
Record the command, the two entity tags and the refusal in REPORT."
  (let* ((resource (concat "/v1/requests/" (wf-manager-draft-id draft)))
         (name (gethash "name" (aref (gethash "inputs" workflow) 0)))
         (body (wf-manager-json-object
                "operation" "set-input"
                "input" (wf-manager-json-object
                         "name" name "source" "literal"
                         "value" wf-manager-live-literal)))
         (stale (wf-manager-reply-etag (wf-manager-live--get connection resource)))
         (accepted (wf-manager-live--post connection resource body
                                          (wf-manager-command-key connection) stale)))
    (puthash "inputName" name report)
    (puthash "literal" wf-manager-live-literal report)
    (puthash "staleTag" stale report)
    (should-not (wf-manager-failure-p accepted))
    (should (= (wf-manager-reply-status accepted) 202))
    (let* ((command (wf-manager-reply-location accepted))
           (receipt (wf-manager-live--settle connection command))
           (current (wf-manager-live--get connection resource))
           (supplied (wf-manager-readiness-supplied
                      (wf-manager-draft-readiness
                       (wf-manager-decode-draft (wf-manager-reply-value current))))))
      (puthash "setInputCommand" command report)
      (puthash "setInputState" (wf-manager-command-receipt-state receipt) report)
      (puthash "currentTag" (wf-manager-reply-etag current) report)
      (should (equal (wf-manager-command-receipt-state receipt) "effect-observed"))
      (should-not (equal (wf-manager-reply-etag current) stale))
      (should (equal (mapcar #'wf-manager-supplied-input-value supplied)
                     (list wf-manager-live-literal))))
    (let ((refused (wf-manager-live--post connection resource body
                                          (wf-manager-command-key connection) stale)))
      (puthash "staleRefusal" (wf-manager-live--refusal refused) report)
      (should (equal refused '(wf-manager-refused 412 "stale-revision"))))))

(defun wf-manager-live--handshake (connection file seconds)
  "For CONNECTION, write FILE for the harness and return its answer.
FILE names the endpoint identity of CONNECTION.  The answer is the
JSON value of FILE with the suffix .done, which the harness writes
when it has acted.  Wait at most SECONDS for it."
  (let ((done (concat file ".done"))
        (deadline (+ (float-time) seconds)))
    (wf-manager-live--write
     file (wf-manager-json-object
           "endpointIdentity" (wf-manager-connection-identity connection)))
    (while (and (not (file-exists-p done)) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (should (file-exists-p done))
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (insert-file-contents-literally done)
      (wf-manager-json-decode (buffer-string)))))

(defun wf-manager-live--pages (connection workflow report)
  "On CONNECTION, create the drafts of WORKFLOW of the pages step.
Each draft receives a literal input of
`wf-manager-live--page-characters' characters.  Record the drafts in
REPORT."
  (let ((name (gethash "name" (aref (gethash "inputs" workflow) 0)))
        (literal (make-string wf-manager-live--page-characters ?x))
        (drafts nil))
    (dotimes (_ wf-manager-live--page-drafts)
      (let* ((created (wf-manager-live--post
                       connection "/v1/requests"
                       (wf-manager-json-object
                        "workflowId" (gethash "id" workflow)
                        "descriptorRevision" (gethash "revision" workflow)
                        "profileId" (gethash "profileId" workflow)
                        "profileRevision" (gethash "profileRevision" workflow))
                       (wf-manager-command-key connection) nil))
             (draft (progn
                      (should-not (wf-manager-failure-p created))
                      (should (= (wf-manager-reply-status created) 201))
                      (wf-manager-decode-draft (wf-manager-reply-value created))))
             (resource (concat "/v1/requests/" (wf-manager-draft-id draft)))
             (accepted (wf-manager-live--post
                        connection resource
                        (wf-manager-json-object
                         "operation" "set-input"
                         "input" (wf-manager-json-object
                                  "name" name "source" "literal" "value" literal))
                        (wf-manager-command-key connection)
                        (wf-manager-reply-etag (wf-manager-live--get connection resource)))))
        (should-not (wf-manager-failure-p accepted))
        (should (= (wf-manager-reply-status accepted) 202))
        (should (equal (wf-manager-command-receipt-state
                        (wf-manager-live--settle connection
                                                 (wf-manager-reply-location accepted)))
                       "effect-observed"))
        (push (wf-manager-draft-id draft) drafts)))
    (puthash "pageRequests" (vconcat (nreverse drafts)) report)))

(defun wf-manager-live--members (overview kind)
  "Return the sorted identifiers of the members of OVERVIEW of KIND."
  (sort (delq nil (mapcar (lambda (item)
                            (let ((member (wf-manager-overview-item-member item)))
                              (when (equal (wf-manager-overview-member-kind member) kind)
                                (car (wf-manager-member-identity member)))))
                          (wf-manager-overview-items overview)))
        #'string<))

(defun wf-manager-live--overview (connection report)
  "Start a session on CONNECTION and record its first overview in REPORT.
Return the `wf-manager-session'."
  (let* ((session nil)
         (overview (wf-manager-live--await
                    (lambda (callback)
                      (setq session (wf-manager-session-start connection callback))))))
    (should (wf-manager-overview-p overview))
    (should (eq (wf-manager-session-overview session) overview))
    (puthash "overviewPages" (wf-manager-live--integer (wf-manager-overview-pages overview))
             report)
    (puthash "overviewRequests" (vconcat (wf-manager-live--members overview "request"))
             report)
    (puthash "overviewCursor" (wf-manager-overview-cursor overview) report)
    ;; Each page draft fills more than half of a page, so each one has a
    ;; page of its own.
    (should (>= (wf-manager-overview-pages overview) wf-manager-live--page-drafts))
    (dolist (item (wf-manager-overview-items overview))
      (should (equal (wf-manager-reference-endpoint (wf-manager-overview-item-reference item))
                     (wf-manager-connection-identity connection))))
    session))

(defun wf-manager-live--follow (session connection file report)
  "Have the harness create a run, and wait for that run in SESSION.
CONNECTION is the connection of SESSION, and FILE the handshake file.
The test reads nothing itself: only the follow loop of SESSION reads
the overview again.  Record the run and the delivery state in REPORT."
  (let* ((answer (wf-manager-live--handshake connection file
                                             wf-manager-live--run-seconds))
         (run (gethash "runId" answer))
         (deadline (+ (float-time) wf-manager-live--seconds))
         (shown (lambda ()
                  (let ((overview (wf-manager-session-overview session)))
                    (and (wf-manager-overview-p overview)
                         (member run (wf-manager-live--members overview "run")))))))
    (puthash "followRunId" run report)
    (should (wf-manager-valid-id-p run))
    (while (and (not (funcall shown)) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (puthash "deliveryState" (symbol-name (wf-manager-session-delivery session)) report)
    (puthash "polls" (wf-manager-live--integer (wf-manager-session-polls session)) report)
    (puthash "generation" (wf-manager-live--integer (wf-manager-session-generation session))
             report)
    (should (funcall shown))
    (should (eq (wf-manager-session-delivery session) 'poll))
    (should (> (wf-manager-session-polls session) 0))))

(defun wf-manager-live--revoke (session connection file report)
  "For SESSION, have the harness revoke the credential of CONNECTION.
Write FILE, wait for FILE with the suffix .done, wait for the end of
the follow loop of SESSION, and record that end and the refusal of the
next GET in REPORT."
  (wf-manager-live--handshake connection file wf-manager-live--seconds)
  (let ((deadline (+ (float-time) wf-manager-live--seconds)))
    (while (and (null (wf-manager-session-follow-end session))
                (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (puthash "followEnd" (symbol-name (or (car (wf-manager-session-follow-end session))
                                          'running))
             report)
    (should (equal (car (wf-manager-session-follow-end session)) 'refused)))
  (let ((refused (wf-manager-live--await
                  (lambda (callback)
                    (wf-manager-get (wf-manager-connection-transport connection)
                                    "/v1/snapshot" callback)))))
    (puthash "revokedRefusal" (wf-manager-live--refusal refused) report)
    (should (equal refused '(wf-manager-refused 401 "unauthenticated")))))

(defun wf-manager-live--close (session processes buffers report)
  "Close SESSION and record what remains.
PROCESSES and BUFFERS are the processes and the buffers before the
session.  The record goes to REPORT."
  (let* ((transport (wf-manager-session-transport session))
         (directory (wf-manager-transport-directory transport)))
    (wf-manager-session-close session)
    (should (null (wf-manager-session-timers session)))
    (let ((new-processes (cl-set-difference (process-list) processes))
          (new-buffers (cl-set-difference (buffer-list) buffers)))
      (puthash "processesAfterClose" (wf-manager-live--integer (length new-processes)) report)
      (puthash "buffersAfterClose" (vconcat (mapcar #'buffer-name new-buffers)) report)
      (puthash "directoryRemoved" (if (file-exists-p directory) :false t) report)
      (should (null new-processes))
      (should (null new-buffers))
      (should-not (file-exists-p directory)))))

(defun wf-manager-live--write (file value)
  "Write to FILE the JSON VALUE."
  (let ((coding-system-for-write 'no-conversion))
    (write-region (wf-manager-json-encode value) nil file nil 'silent)))

(ert-deftest wf-manager-live-session ()
  "Run the eight steps of one live session against the manager."
  (let* ((profile (wf-manager-profile-load
                   (wf-manager-live--variable "WF_MANAGER_PROFILE")))
         (report-file (wf-manager-live--variable "WF_MANAGER_REPORT"))
         (run-file (wf-manager-live--variable "WF_MANAGER_RUN"))
         (revoke-file (wf-manager-live--variable "WF_MANAGER_REVOKE"))
         (report (wf-manager-json-object
                  "harnessVersion"
                  (wf-manager-live--integer wf-manager-live-harness-version)))
         (processes (process-list))
         (buffers (buffer-list))
         (steps nil))
    (setq wf-manager-live--prompts 0)
    (dolist (function wf-manager-live--prompt-functions)
      (advice-add function :around #'wf-manager-live--prompted))
    (unwind-protect
        (let ((connection (wf-manager-live--bind profile report)))
          (push "bind" steps)
          (let* ((workflow (wf-manager-live--workflow connection))
                 (draft (wf-manager-live--draft connection workflow report)))
            (push "draft" steps)
            (wf-manager-live--stale connection workflow draft report)
            (push "stale" steps)
            (wf-manager-live--pages connection workflow report)
            (push "pages" steps))
          (let ((session (wf-manager-live--overview connection report)))
            (push "overview" steps)
            (wf-manager-live--follow session connection run-file report)
            (push "follow" steps)
            (wf-manager-live--revoke session connection revoke-file report)
            (push "revoke" steps)
            (wf-manager-live--close session processes buffers report)
            (push "close" steps)))
      (dolist (function wf-manager-live--prompt-functions)
        (advice-remove function #'wf-manager-live--prompted))
      (puthash "prompts" (wf-manager-live--integer wf-manager-live--prompts) report)
      (puthash "steps" (vconcat (reverse steps)) report)
      (wf-manager-live--write report-file report))
    (should (= wf-manager-live--prompts 0))))

(provide 'wf-manager-live)

;;; wf-manager-live.el ends here
