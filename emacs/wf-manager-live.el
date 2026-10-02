;;; wf-manager-live.el --- Live checks of wf-manager.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 John Wiegley

;; Author: John Wiegley <johnw@newartisans.com>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The live check of the transport `wf-manager.el' and of the service
;; mode of `wf-service.el' against a running agent-cat workflow manager.  The emacs-client mode of
;; `manager/test/service_http.py' in agent-cat starts the manager with
;; its mixed fixture, issues two client credentials with the scopes
;; observe, submit, control and export and writes the version 1 client
;; profile of each.  It also writes a third profile with the second
;; credential, whose endpoint names a local port with no listener.  It
;; then runs this file in a batch Emacs with an isolated home directory
;; and `user-emacs-directory':
;;
;;     WF_MANAGER_PROFILE=/path/to/client-profile.json \
;;     WF_MANAGER_SECOND_PROFILE=/path/to/second-profile.json \
;;     WF_MANAGER_UNREACHABLE_PROFILE=/path/to/unreachable-profile.json \
;;     WF_MANAGER_REPORT=/path/to/report.json \
;;     WF_MANAGER_RUN=/path/to/run.json \
;;     WF_MANAGER_REVOKE=/path/to/revoke.json \
;;     WF_MANAGER_FINISH=/path/to/finish.json \
;;     WF_MANAGER_DOWNLOAD=/path/to/download.bin \
;;       "$EMACS" -Q --batch -L ./emacs -l wf-manager-live \
;;       -f ert-run-tests-batch-and-exit
;;
;; `ci/emacs.sh' compiles and checks this file, and it does not run it.
;; The one test runs these thirteen steps in order:
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
;;   7. unreachable: `wf-manager-session-switch' to the profile of
;;      WF_MANAGER_UNREACHABLE_PROFILE fails with
;;      `wf-manager-transport-unavailable'.  The session keeps its
;;      connection, its endpoint identity, its watched resources and its
;;      overview, and its follow loop sends at least two more polling
;;      batches with the delivery state `poll'.
;;   8. switch: the session watches the first draft and one page draft
;;      on the first binding.  The read of the page draft completes, and
;;      advice of `wf-manager--session-complete' delays its delivery.
;;      `wf-manager-session-switch' to the profile of
;;      WF_MANAGER_SECOND_PROFILE then commits with a new endpoint
;;      identity and the complete overview of the second credential.
;;      Each member reference of that overview resolves to a 200 read.
;;      The delayed read of the earlier generation is then delivered, and
;;      it changes neither the newer read of the page draft nor the
;;      overview.  A reference of the first binding gives
;;      `wf-manager-wrong-endpoint', both for a watch and for the current
;;      read, and the follow loop polls on the second binding.
;;   9. revoke: the test writes the file that WF_MANAGER_REVOKE names and
;;      waits for that name with the suffix .done, which the harness
;;      writes after it revokes the second credential.  The follow loop
;;      of the session then ends with `refused', and the next GET gives
;;      the typed refusal 401 unauthenticated.
;;  10. close: a buffer that holds the session and a reference of the run
;;      is killed, and `wf-manager-session-close' then leaves no network
;;      process, no url.el buffer, no timer and no session directory of
;;      either binding.
;;  11. export: a new connection binds with the profile of
;;      WF_MANAGER_PROFILE.  The test writes the file that
;;      WF_MANAGER_FINISH names and waits for that name with the suffix
;;      .done.  Before it acts, the harness reads that the run of the
;;      harness has not ended and that the check sent no command after
;;      the run handshake.  It then drives the run to its terminal
;;      success and writes the .done file.  A new session of the
;;      connection prepares the export command of that run with
;;      `wf-manager-session-prepare', with the entity tag of the first
;;      page of its export collection as the precondition, and sends it
;;      one time with `wf-manager-session-send'.  The reply is a 202
;;      receipt, and `wf-manager-session-receipt' reads the receipt at
;;      the Location until it settles with effect-observed.  The test
;;      reads the export of the effect and downloads its artifact with
;;      `wf-manager-session-download' against the stated size and
;;      SHA-256 digest, and it writes the bytes to the file that
;;      WF_MANAGER_DOWNLOAD names.  A download with a wrong digest and a
;;      download with a wrong size each give
;;      `wf-manager-invalid-response'.  The test then closes the session.
;;  12. service: the test drives the commands of `wf.el' with keyboard
;;      macros through `execute-kbd-macro', with the profile of
;;      WF_MANAGER_PROFILE as the one item of `wf-manager-profiles'.
;;      M-x wf-service selects the profile and connects service mode.
;;      M-x wf-run lists the ready profiles and then the catalogue of
;;      the selected profile in *Completions*, and the test keeps each
;;      listing with a key of its own.  \`C-g' in the workflow prompt
;;      then ends `wf-run' with no refusal, before any request exists.
;;      M-x wf-help shows the help text of that workflow.  Each command
;;      of `wf-manager-live--local-commands' refuses with the message of
;;      `wf-service-refusal' and starts no process and sends no request.
;;      M-x wf-diagnostics shows the diagnostics of the session with the
;;      delivery state `poll', and M-x wf-local closes the session and
;;      returns to local mode.
;;  13. requests: the keys select the profile of WF_MANAGER_PROFILE with
;;      M-x wf-service again and run M-x wf-run three times.  The first
;;      request, of the workflow prompt-source, receives
;;      `wf-manager-live-mixed-text' through the Multiline source of the
;;      setup form.  M-x wf-refresh in the open form reads the request
;;      again and draws the form again, and a probe key keeps the value
;;      of the input before and after.  The second request, of the
;;      workflow captured-input, uploads the bytes of a file of
;;      `wf-manager-live-captured' through the File source.  The test
;;      approves each review with \`a' and the answer yes, and a probe key
;;      keeps the text and the state of each review buffer.  The third
;;      request, of prompt-source, receives `wf-manager-live-declined'.
;;      Its review is declined with \`a' and the answer no, which sends
;;      nothing, then discarded with \`d' and withdrawn with \`w'.  Advice of
;;      `wf-manager-session-send' keeps every command that the step sends.
;;      M-x wf-local then closes the session.
;;
;; No step before the service step may prompt.  Each prompt function of
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
;;   unreachableFailure  the condition of the unreachable switch
;;   unreachableKept   true when the session kept its binding
;;   pollsBeforeUnreachable  the polling batches before that switch
;;   pollsAfterUnreachable   the polling batches after it
;;   switchIdentity    the endpoint identity of the second binding
;;   switchEpoch       the authority epoch of the second binding
;;   switchGeneration  the refresh generation after the switch
;;   switchOverviewRequests  the sorted request members of its overview
;;   switchOverviewRuns      the sorted run members of its overview
;;   overviewItems     the number of members of that overview
;;   resolvedReferences  the number of those members that read 200
;;   delayedReads      the number of delayed reads of the earlier binding
;;   delayedOverwrote  true when a delayed read changed the newer state
;;   earlierRefusal    the conditions of a watch and of the current read
;;                     of a reference of the first binding
;;   switchDelivery    the delivery state of the second binding
;;   followEnd         the end of the follow loop after the revocation
;;   revokedRefusal    [401, CODE], the refusal after the revocation
;;   processesAfterClose  the number of new processes after close
;;   buffersAfterClose    the names of the new buffers after close
;;   timersAfterClose  the number of new timers after close
;;   bufferKilled      true after the kill of the reference buffer
;;   directoryRemoved  true when the directories of both bindings are gone
;;   exportSent        the kind of the `wf-manager-sent' of the export
;;   exportCommand     the Location of the export command
;;   exportState       the state that its receipt reached
;;   exportResource    the resource of the effect of the receipt
;;   exportDownload    the download resource of the export
;;   downloadBytes     the number of the downloaded bytes
;;   downloadSha256    the SHA-256 digest of the downloaded bytes
;;   wrongDigestRefusal  the condition of the download with a wrong digest
;;   wrongSizeRefusal  the condition of the download with a wrong size
;;   serviceIdentity   the endpoint identity of the service-mode session
;;   serviceProfiles   the sorted profile candidates that wf-run listed
;;   serviceWorkflows  the sorted workflow candidates that wf-run listed
;;   serviceRunRefusal the refusal of wf-run after the listings, null
;;   serviceHelp       the text of the help buffer of wf-help
;;   serviceRefusals   an object that maps each local-only command to
;;                     its refusal
;;   serviceLocalCalls the number of process starts and requests of the
;;                     local-only commands
;;   serviceDiagnostics  the text of the diagnostics buffer
;;   serviceLocal      true when wf-local closed the session and
;;                     returned to local mode
;;   editorBefore      the value of the input before the refresh
;;   editorAfter       the value of the input after the refresh
;;   editorRedrawn     true when the refresh drew new widgets
;;   literalRequestId, literalPreparationId, literalReviewDigest,
;;   literalEtag, literalReviewText, literalRunId, literalOutcomes
;;                     the request, the preparation, the review digest,
;;                     the entity tag, the text of the review buffer, the
;;                     run and the sent operations of the first review.
;;                     The fields with the prefixes captured and declined
;;                     are those of the second and the third review.
;;   capturedBytes     the number of the bytes of the captured file
;;   capturedSha256    the SHA-256 digest of those bytes
;;   declinedSentAfterNo  the operations that the third review had sent
;;                     after the answer no
;;   requestCommands   each command of the requests step in order, with
;;                     its resource, media type, If-Match and body.  A
;;                     capture body is its byte count and SHA-256 digest.
;;
;; The harness compares `harnessVersion' with its own constant and
;; refuses a report of another version, so that a mismatched pair of the
;; two repositories fails with one sentence.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'url)
(require 'wf-manager)
(require 'wf-service)

(defconst wf-manager-live-harness-version 6
  "The version of the report of this file.
The emacs-client mode of agent-cat states the same version.")

(defconst wf-manager-live-workflow "mixed-controls"
  "The name of the workflow of the draft of the live session.")

(defconst wf-manager-live-literal "Emacs \u03bb \u96ea\U0001F600 input."
  "The literal input that the set-input command supplies.")

(defconst wf-manager-live-export-name "emacs-export.json"
  "The name of the export of the run of the harness.")

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
CONNECTION is the current connection of SESSION.
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

(defvar-local wf-manager-live--held nil
  "The session and the reference that the reference buffer holds.")

(defun wf-manager-live--close (session state directories report)
  "Kill a buffer with a reference of SESSION, close SESSION, and check.
STATE is (PROCESSES BUFFERS TIMERS), the processes, the buffers and the
timers before the session.  DIRECTORIES are the transport directories
of the bindings of SESSION.  The record goes to REPORT."
  (pcase-let ((`(,processes ,buffers ,timers) state)
              (buffer (generate-new-buffer " wf-manager-live-reference")))
    (with-current-buffer buffer
      (setq wf-manager-live--held
            (list session (wf-manager-session-reference
                           session (concat "/v1/runs/" (gethash "followRunId" report))))))
    (kill-buffer buffer)
    (puthash "bufferKilled" (if (buffer-live-p buffer) :false t) report)
    (wf-manager-session-close session)
    (should (null (wf-manager-session-timers session)))
    (let ((new-processes (cl-set-difference (process-list) processes))
          (new-buffers (cl-set-difference (buffer-list) buffers))
          (new-timers (cl-set-difference timer-list timers)))
      (puthash "processesAfterClose" (wf-manager-live--integer (length new-processes)) report)
      (puthash "buffersAfterClose" (vconcat (mapcar #'buffer-name new-buffers)) report)
      (puthash "timersAfterClose" (wf-manager-live--integer (length new-timers)) report)
      (puthash "directoryRemoved"
               (if (cl-some #'file-exists-p directories) :false t) report)
      (should-not (buffer-live-p buffer))
      (should (null new-processes))
      (should (null new-buffers))
      (should (null new-timers))
      (should-not (cl-some #'file-exists-p directories)))))

(defun wf-manager-live--wait (predicate)
  "Wait at most `wf-manager-live--seconds' for PREDICATE to be non-nil.
Return the value of PREDICATE."
  (let ((deadline (+ (float-time) wf-manager-live--seconds)))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (funcall predicate)))

(defun wf-manager-live--unreachable (session profile report)
  "Switch SESSION to PROFILE, whose endpoint has no listener.
Require that SESSION keeps its binding and its follow loop, and record
the failure and the polling batches in REPORT."
  (let* ((connection (wf-manager-session-connection session))
         (identity (wf-manager-session-identity session))
         (watched (copy-sequence (wf-manager-session-watched session)))
         (before (wf-manager-session-polls session))
         (outcome (wf-manager-live--await
                   (lambda (callback)
                     (wf-manager-session-switch session profile callback))))
         (polled (wf-manager-live--wait
                  (lambda () (>= (wf-manager-session-polls session) (+ before 2)))))
         (overview (wf-manager-session-overview session))
         (kept (and (eq connection (wf-manager-session-connection session))
                    (equal identity (wf-manager-session-identity session))
                    (equal watched (wf-manager-session-watched session))
                    (wf-manager-overview-p overview)
                    (cl-every (lambda (item)
                                (equal (wf-manager-reference-endpoint
                                        (wf-manager-overview-item-reference item))
                                       identity))
                              (wf-manager-overview-items overview))
                    (null (wf-manager-session-switches session))
                    (null (wf-manager-session-follow-end session))
                    (eq (wf-manager-session-delivery session) 'poll))))
    (puthash "unreachableFailure"
             (symbol-name (if (wf-manager-failure-p outcome) (car outcome) 'none)) report)
    (puthash "unreachableKept" (if kept t :false) report)
    (puthash "pollsBeforeUnreachable" (wf-manager-live--integer before) report)
    (puthash "pollsAfterUnreachable"
             (wf-manager-live--integer (wf-manager-session-polls session)) report)
    (should (eq (car-safe outcome) 'wf-manager-transport-unavailable))
    (should polled)
    (should kept)))

(defun wf-manager-live--condition (function)
  "Call FUNCTION and return the name of the condition that it gives.
FUNCTION signals a condition or returns a failure.  Return \"none\"
when it does neither."
  (condition-case failure
      (let ((value (funcall function)))
        (symbol-name (if (wf-manager-failure-p value) (car value) 'none)))
    (wf-manager-error (symbol-name (car failure)))))

(defun wf-manager-live--switch (session profile report)
  "Switch SESSION to PROFILE with a delayed read of the earlier binding.
Return the transport directory of the earlier binding.  Record the
switch, the delayed read and the refusal of an earlier reference in
REPORT."
  (let* ((generation (wf-manager-session-generation session))
         (draft-uri (concat "/v1/requests/" (gethash "requestId" report)))
         (page-uri (concat "/v1/requests/" (aref (gethash "pageRequests" report) 0)))
         (earlier (wf-manager-session-reference session draft-uri))
         (directory (wf-manager-transport-directory (wf-manager-session-transport session)))
         (held nil)
         (resolved nil)
         (total nil)
         (hold (lambda (original &rest arguments)
                 ;; The arguments are SESSION KEY GENERATION OUTCOME INSTALL.
                 (if (and (equal (nth 1 arguments) page-uri)
                          (eql (nth 2 arguments) generation))
                     (push (cons original arguments) held)
                   (apply original arguments)))))
    (wf-manager-session-watch session earlier)
    (should (wf-manager-live--wait
             (lambda () (wf-manager-reply-p (wf-manager-session-current session earlier)))))
    (advice-add 'wf-manager--session-complete :around hold)
    (unwind-protect
        (progn
          (wf-manager-session-watch session (wf-manager-session-reference session page-uri))
          (should (wf-manager-live--wait (lambda () held)))
          (let* ((overview (wf-manager-live--await
                            (lambda (callback)
                              (wf-manager-session-switch session profile callback))))
                 (items (progn (should (wf-manager-overview-p overview))
                               (wf-manager-overview-items overview)))
                 (references (mapcar #'wf-manager-overview-item-reference items))
                 (page (cl-find page-uri references
                                :key #'wf-manager-reference-uri :test #'equal)))
            (puthash "switchIdentity" (wf-manager-session-identity session) report)
            (puthash "switchEpoch"
                     (wf-manager-connection-epoch (wf-manager-session-connection session))
                     report)
            (puthash "switchGeneration"
                     (wf-manager-live--integer (wf-manager-session-generation session)) report)
            (puthash "switchOverviewRequests"
                     (vconcat (wf-manager-live--members overview "request")) report)
            (puthash "switchOverviewRuns" (vconcat (wf-manager-live--members overview "run"))
                     report)
            (puthash "overviewItems" (wf-manager-live--integer (length items)) report)
            (should page)
            ;; Each member reference of the new overview resolves.
            (dolist (reference references)
              (wf-manager-session-watch session reference))
            (should (wf-manager-live--wait
                     (lambda ()
                       (cl-every (lambda (reference)
                                   (wf-manager-session-current session reference))
                                 references))))
            (setq resolved (cl-count-if (lambda (reference)
                                          (wf-manager-reply-p
                                           (wf-manager-session-current session reference)))
                                        references)
                  total (length references))
            (puthash "resolvedReferences" (wf-manager-live--integer resolved) report)
            ;; The delayed read of the earlier generation arrives last.
            (let ((newer (wf-manager-session-current session page)))
              (puthash "delayedReads" (wf-manager-live--integer (length held)) report)
              (dolist (entry (reverse held))
                (apply (car entry) (cdr entry)))
              (setq held nil)
              (accept-process-output nil 0.2)
              (let* ((installed (wf-manager-session-overview session))
                     (overwrote
                      (not (and (eq (wf-manager-session-current session page) newer)
                                (wf-manager-overview-p installed)
                                (cl-every (lambda (item)
                                            (equal (wf-manager-reference-endpoint
                                                    (wf-manager-overview-item-reference item))
                                                   (wf-manager-session-identity session)))
                                          (wf-manager-overview-items installed))))))
                (puthash "delayedOverwrote" (if overwrote t :false) report)
                (should (wf-manager-reply-p newer))
                (should-not overwrote)))))
      (advice-remove 'wf-manager--session-complete hold))
    (puthash "earlierRefusal"
             (vector (wf-manager-live--condition
                      (lambda () (wf-manager-session-watch session earlier)))
                     (wf-manager-live--condition
                      (lambda () (wf-manager-session-current session earlier))))
             report)
    (should (wf-manager-live--wait
             (lambda () (eq (wf-manager-session-delivery session) 'poll))))
    (puthash "switchDelivery" (symbol-name (wf-manager-session-delivery session)) report)
    (should (equal (gethash "earlierRefusal" report)
                   ["wf-manager-wrong-endpoint" "wf-manager-wrong-endpoint"]))
    (should (eql resolved total))
    directory))

(defun wf-manager-live--receipt (session location)
  "On SESSION, read the receipt at LOCATION until it settles.
LOCATION is the `wf-manager-reference' of a command.  Return the
decoded `wf-manager-command-receipt'.  A failure fails the test."
  (let ((deadline (+ (float-time) wf-manager-live--seconds))
        (receipt nil))
    (while (progn
             (setq receipt (wf-manager-live--await
                            (lambda (callback)
                              (wf-manager-session-receipt session location callback))))
             (should (wf-manager-command-receipt-p receipt))
             (and (not (member (wf-manager-command-receipt-state receipt)
                               '("effect-observed" "refused" "unresolved")))
                  (< (float-time) deadline)))
      (accept-process-output nil 0.05))
    receipt))

(defun wf-manager-live--download (session reference size digest)
  "On SESSION, download REFERENCE against SIZE and DIGEST, and return it.
The result is the unibyte bytes or a failure."
  (wf-manager-live--await
   (lambda (callback)
     (wf-manager-session-download session reference size digest callback))))

(defun wf-manager-live--export (profile finish-file download-file report)
  "Export the run of the harness on a new session of PROFILE, and download it.
FINISH-FILE is the handshake file after which the run has ended, and
DOWNLOAD-FILE receives the downloaded bytes.  Record the command, its
receipt and the downloads in REPORT."
  (let* ((connection (wf-manager-live--await
                      (lambda (callback) (wf-manager-connect profile callback))))
         (run (gethash "followRunId" report))
         (session nil))
    (should (wf-manager-connection-p connection))
    (wf-manager-live--handshake connection finish-file wf-manager-live--run-seconds)
    (unwind-protect
        (let* ((overview (wf-manager-live--await
                          (lambda (callback)
                            (setq session (wf-manager-session-start connection callback)))))
               (collection (progn
                             (should (wf-manager-overview-p overview))
                             (wf-manager-session-reference
                              session (concat "/v1/runs/" run "/exports"))))
               (page (wf-manager-live--get connection (wf-manager-reference-uri collection)))
               (command (wf-manager-session-prepare
                         session collection
                         (wf-manager-json-object "name" wf-manager-live-export-name)
                         (wf-manager-reply-etag page)))
               (sent (wf-manager-live--await
                      (lambda (callback) (wf-manager-session-send session command callback)))))
          (puthash "exportSent" (symbol-name (wf-manager-sent-kind sent)) report)
          (should (eq (wf-manager-sent-kind sent) 'delivered))
          (should (wf-manager-command-receipt-p (wf-manager-sent-receipt sent)))
          (let* ((location (wf-manager-sent-location sent))
                 (receipt (wf-manager-live--receipt session location))
                 (effect (wf-manager-command-receipt-effect receipt))
                 (resource (and (hash-table-p effect) (gethash "resource" effect))))
            (puthash "exportCommand" (wf-manager-reference-uri location) report)
            (puthash "exportState" (wf-manager-command-receipt-state receipt) report)
            (puthash "exportResource" (or resource :null) report)
            (should (equal (wf-manager-command-receipt-state receipt) "effect-observed"))
            (should (stringp resource))
            (let* ((export (wf-manager-reply-value (wf-manager-live--get connection resource)))
                   (download (gethash "download" export))
                   (size (string-to-number (gethash "bytes" export)))
                   (digest (gethash "sha256" export))
                   (reference (wf-manager-session-reference session download))
                   (bytes (wf-manager-live--download session reference size digest))
                   (wrong (concat (if (eq (aref digest 0) ?0) "1" "0") (substring digest 1))))
              (puthash "exportDownload" download report)
              (should (stringp bytes))
              (should-not (multibyte-string-p bytes))
              (let ((coding-system-for-write 'no-conversion))
                (write-region bytes nil download-file nil 'silent))
              (puthash "downloadBytes" (wf-manager-live--integer (length bytes)) report)
              (puthash "downloadSha256" (secure-hash 'sha256 bytes) report)
              (puthash "wrongDigestRefusal"
                       (wf-manager-live--condition
                        (lambda () (wf-manager-live--download session reference size wrong)))
                       report)
              (puthash "wrongSizeRefusal"
                       (wf-manager-live--condition
                        (lambda () (wf-manager-live--download session reference (1+ size) digest)))
                       report)
              (should (= (length bytes) size))
              (should (equal (gethash "wrongDigestRefusal" report) "wf-manager-invalid-response"))
              (should (equal (gethash "wrongSizeRefusal" report) "wf-manager-invalid-response")))))
      (when session (wf-manager-session-close session)))))

;;;; The service step

(defconst wf-manager-live--local-commands
  '(wf-plan wf-cost wf-lineage-compare wf-observer-result wf-observer-refresh)
  "The local-only commands that the service step runs in service mode.")

(defconst wf-manager-live--spawners
  '(make-process process-file call-process start-file-process url-retrieve
    wf-manager-post-bytes)
  "The functions that start a process or send a request.")

(defvar wf-manager-live--captures nil
  "The completion captures of the service step, the newest first.
Each capture is (CANDIDATES TEXT): the candidates of the completion
table of the minibuffer and the text of the *Completions* buffer.")

(defun wf-manager-live--capture ()
  "Keep the candidates of the minibuffer and the text of *Completions*."
  (interactive)
  (let ((buffer (get-buffer "*Completions*")))
    (push (list (all-completions "" minibuffer-completion-table
                                 minibuffer-completion-predicate)
                (and buffer (with-current-buffer buffer
                              (buffer-substring-no-properties (point-min) (point-max)))))
          wf-manager-live--captures)))

(defun wf-manager-live--keys (&rest keys)
  "Run KEYS as one keyboard macro.
Each item of KEYS is a string of `kbd' syntax or a vector of literal
events.  Return the message of the `user-error' that ends the macro, or
nil."
  (condition-case failure
      (progn
        (execute-kbd-macro
         (apply #'vconcat (mapcar (lambda (key) (if (stringp key) (kbd key) key)) keys)))
        nil)
    (user-error (error-message-string failure))))

(defun wf-manager-live--listed (capture)
  "Return the sorted candidates of CAPTURE.
Each candidate must appear in the text of the *Completions* buffer."
  (pcase-let ((`(,candidates ,text) capture))
    (should (stringp text))
    (dolist (candidate candidates)
      (should (string-search candidate text)))
    (sort (copy-sequence candidates) #'string<)))

(defun wf-manager-live--buffer-text (name)
  "Return the text of the buffer NAME, which must exist."
  (let ((buffer (get-buffer name)))
    (should buffer)
    (with-current-buffer buffer
      (buffer-substring-no-properties (point-min) (point-max)))))

(defun wf-manager-live--service (file report)
  "Drive the commands of `wf.el' in service mode with keys, for FILE.
FILE is the client profile file.  The keys select FILE with
`wf-service', list the catalogue through `wf-run', show the help text
of a workflow, run each local-only command, show the diagnostics and
return to local mode with `wf-local'.  The step answers its prompts
with keys, so it lifts the refusal of the prompt functions.  Record
the listings, the refusals and the diagnostics in REPORT."
  (dolist (function wf-manager-live--prompt-functions)
    (advice-remove function #'wf-manager-live--prompted))
  (setq wf-manager-live--captures nil)
  (define-key minibuffer-local-must-match-map (kbd "<f9>") #'wf-manager-live--capture)
  (let ((wf-manager-profiles (list file))
        (suggest-key-bindings nil)
        (extended-command-suggest-shorter nil)
        (calls nil))
    (unwind-protect
        (progn
          (should-not (wf-manager-live--keys "M-x wf-service RET" (vconcat file) "RET"))
          (should (eq wf--service-dispatch #'wf-service--dispatch))
          (let ((session (wf-service--state-session wf-service--current)))
            (should (wf-manager-overview-p (wf-manager-session-overview session)))
            (puthash "serviceIdentity" (wf-manager-session-identity session) report)
            ;; The catalogue: the profile prompt, then the workflow prompt
            ;; of `wf--read-row'.  Each ? lists the candidates in
            ;; *Completions*, and <f9> keeps them.
            (let ((refusal (wf-manager-live--keys "M-x wf-run RET ? <f9> RET ? <f9> C-g")))
              (should (= (length wf-manager-live--captures) 2))
              (let ((workflows (wf-manager-live--listed (nth 0 wf-manager-live--captures)))
                    (profiles (wf-manager-live--listed (nth 1 wf-manager-live--captures))))
                (puthash "serviceProfiles" (vconcat profiles) report)
                (puthash "serviceWorkflows" (vconcat workflows) report)
                (puthash "serviceRunRefusal" (or refusal :null) report)
                (should (member wf-manager-live-workflow workflows))
                (should-not refusal)
                ;; wf-help shows the help text of the catalogue.
                (should-not (wf-manager-live--keys "M-x wf-help RET RET"
                                                   (vconcat wf-manager-live-workflow) "RET"))
                (puthash "serviceHelp"
                         (wf-manager-live--buffer-text
                          (format "*wf help: %s/%s*" (car profiles) wf-manager-live-workflow))
                         report)))
            ;; Each local-only command refuses and sends nothing.
            (let ((refusals (make-hash-table :test #'equal))
                  (count (lambda (function) (lambda (&rest _) (push function calls)))))
              (let ((advices (mapcar (lambda (function) (cons function (funcall count function)))
                                     wf-manager-live--spawners)))
                (unwind-protect
                    (progn
                      (dolist (advice advices)
                        (advice-add (car advice) :before (cdr advice)))
                      (dolist (command wf-manager-live--local-commands)
                        (puthash (symbol-name command)
                                 (or (wf-manager-live--keys (format "M-x %s RET" command)) :null)
                                 refusals)))
                  (dolist (advice advices)
                    (advice-remove (car advice) (cdr advice)))))
              (puthash "serviceRefusals" refusals report)
              (puthash "serviceLocalCalls" (wf-manager-live--integer (length calls)) report)
              (dolist (command wf-manager-live--local-commands)
                (should (equal (gethash (symbol-name command) refusals)
                               (wf-service-refusal command))))
              (should (null calls)))
            ;; The diagnostics of the session.
            (should (wf-manager-live--wait
                     (lambda () (eq (wf-manager-session-delivery session) 'poll))))
            (should-not (wf-manager-live--keys "M-x wf-diagnostics RET"))
            (let ((text (wf-manager-live--buffer-text "*wf service diagnostics*")))
              (puthash "serviceDiagnostics" text report)
              (should (string-search "Delivery state: poll\n" text))
              (should (string-search (format "Endpoint identity: %s\n"
                                             (wf-manager-session-identity session))
                                     text)))
            ;; Local mode again.
            (should-not (wf-manager-live--keys "M-x wf-local RET"))
            (puthash "serviceLocal" (if (and (null wf--service-dispatch)
                                             (wf-manager-session-closed session))
                                        t :false)
                     report)
            (should-not wf--service-dispatch)
            (should (wf-manager-session-closed session))))
      (define-key minibuffer-local-must-match-map (kbd "<f9>") nil)
      (when wf-service--current
        (wf-local)))))

;;;; The requests step

(defconst wf-manager-live-mixed-text "Café λ — explicit false.\nSecond line."
  "The literal of the setup form of the requests step.
MIXED_TEXT of `manager/test/service_http.py' states the same text.")

(defconst wf-manager-live-captured "Emacs captured Ünïcode λ\r\nsecond line\n"
  "The text of the file that the captured input of the requests step uploads.
EMACS_CAPTURED of `manager/test/service_http.py' states the same text.")

(defconst wf-manager-live-declined "Emacs decline λ."
  "The literal of the request whose review the requests step declines.")

(defvar wf-manager-live--editor nil
  "The probes of the setup form of the requests step, the newest first.
Each probe is (VALUES WIDGETS HEADER): the values and the widgets of the
inputs of the form and its header.")

(defvar wf-manager-live--reviews nil
  "The probes of the review buffers of the requests step, the newest first.
Each probe is (TEXT REVIEW OUTCOMES): the text of the buffer, its
`wf-service--review' and the operations that the review had sent at
the probe, the oldest first.")

(defvar wf-manager-live--sent nil
  "The commands that the requests step sent, the newest first.
Each item is (RESOURCE MEDIA IF-MATCH BYTES) of one
`wf-manager-pending'.")

(defun wf-manager-live--probe-editor ()
  "Keep the values, the widgets and the header of this setup form."
  (interactive)
  (push (list (mapcar (lambda (field) (widget-value (plist-get field :widget))) wf--setup-fields)
              (mapcar (lambda (field) (plist-get field :widget)) wf--setup-fields)
              wf--setup-header)
        wf-manager-live--editor))

(defun wf-manager-live--probe-review ()
  "Keep the text and the review of this review buffer."
  (interactive)
  (push (list (buffer-substring-no-properties (point-min) (point-max))
              wf-service--review-state
              (mapcar #'car (reverse (wf-service--review-outcomes wf-service--review-state))))
        wf-manager-live--reviews))

(defun wf-manager-live--record-send (_session command _callback)
  "Keep the resource, the media type, the precondition and the bytes of COMMAND."
  (push (list (wf-manager-reference-uri (wf-manager-pending-reference command))
              (wf-manager-pending-media command)
              (wf-manager-pending-if-match command)
              (wf-manager-pending-bytes command))
        wf-manager-live--sent))

(defun wf-manager-live--review-fields (probe prefix report)
  "Record the review PROBE with field names that start with PREFIX.
The fields go into REPORT."
  (pcase-let* ((`(,text ,review ,outcomes) probe)
               (preparation (wf-service--review-preparation review)))
    (puthash (concat prefix "RequestId") (wf-manager-preparation-request-id preparation) report)
    (puthash (concat prefix "PreparationId") (wf-manager-preparation-id preparation) report)
    (puthash (concat prefix "ReviewDigest") (wf-manager-preparation-review-digest preparation) report)
    (puthash (concat prefix "Etag") (wf-service--review-etag review) report)
    (puthash (concat prefix "ReviewText") text report)
    (puthash (concat prefix "RunId") (or (wf-service--review-run review) :null) report)
    (puthash (concat prefix "Outcomes") (vconcat outcomes) report)))

(defun wf-manager-live--requests (file report)
  "Create, set up, review and approve or decline three requests with keys.
FILE is the client profile file.  The keys select FILE with
`wf-service' and run `wf-run' three times.  The first request of
prompt-source receives `wf-manager-live-mixed-text' through the
Multiline source, and `wf-refresh' reads the request again while the
form is open.  The second request of captured-input uploads the file of
`wf-manager-live-captured' through the File source.  Both reviews are
approved with \\`a' and the answer yes.  The third request of
prompt-source receives `wf-manager-live-declined', and its review is
declined with \\`a' and the answer no, then discarded with \\`d' and
withdrawn with \\`w'.  Record the probes and the sent commands in
REPORT."
  (setq wf-manager-live--editor nil
        wf-manager-live--reviews nil
        wf-manager-live--sent nil)
  (let* ((wf-manager-profiles (list file))
         (suggest-key-bindings nil)
         (extended-command-suggest-shorter nil)
         (captured (expand-file-name "emacs-captured.txt" temporary-file-directory))
         (bytes (encode-coding-string wf-manager-live-captured 'utf-8-unix))
         (history (wf--input-history "prompt-source" "input")))
    (let ((coding-system-for-write 'no-conversion))
      (write-region bytes nil captured nil 'silent))
    (global-set-key (kbd "<f7>") #'wf-manager-live--probe-editor)
    (global-set-key (kbd "<f8>") #'wf-manager-live--probe-review)
    (advice-add 'wf-manager-session-send :before #'wf-manager-live--record-send)
    (unwind-protect
        (progn
          (should-not (wf-manager-live--keys "M-x wf-service RET" (vconcat file) "RET"))
          ;; The literal: the Multiline source is item 1 of the source
          ;; menu, two widgets before the value.  RET inserts the line end.
          (set history nil)
          (let ((lines (split-string wf-manager-live-mixed-text "\n")))
            (should-not (wf-manager-live--keys
                         "M-x wf-run RET RET prompt-source RET <backtab> <backtab> RET 1"
                         (vconcat (nth 0 lines)) "RET" (vconcat (nth 1 lines))
                         "<f7> M-x wf-refresh RET <f7> C-c C-c <f8> a" (vconcat "yes") "RET <f8>")))
          (should (= (length wf-manager-live--editor) 2))
          (pcase-let ((`((,after ,after-widgets ,after-header) (,before ,before-widgets ,_))
                       wf-manager-live--editor))
            (puthash "editorBefore" (car before) report)
            (puthash "editorAfter" (car after) report)
            (puthash "editorRedrawn" (if (and (not (eq (car before-widgets) (car after-widgets)))
                                              (stringp after-header))
                                         t :false)
                     report)
            (should (equal (car before) wf-manager-live-mixed-text))
            (should (equal (car after) wf-manager-live-mixed-text)))
          (should (= (length wf-manager-live--reviews) 2))
          (should (equal (nth 2 (nth 1 wf-manager-live--reviews)) nil))
          (wf-manager-live--review-fields (car wf-manager-live--reviews) "literal" report)
          (should (stringp (gethash "literalRunId" report)))
          ;; The capture: the File source is item 2 of the source menu.
          (should-not (wf-manager-live--keys
                       "M-x wf-run RET RET captured-input RET <backtab> <backtab> RET 2"
                       (vconcat captured) "C-c C-c <f8> a" (vconcat "yes") "RET <f8>"))
          (should (= (length wf-manager-live--reviews) 4))
          (wf-manager-live--review-fields (car wf-manager-live--reviews) "captured" report)
          (puthash "capturedBytes" (wf-manager-live--integer (length bytes)) report)
          (puthash "capturedSha256" (secure-hash 'sha256 bytes) report)
          (should (stringp (gethash "capturedRunId" report)))
          ;; The declined review, then its discard and the withdrawal.
          (set history nil)
          (should-not (wf-manager-live--keys
                       "M-x wf-run RET RET prompt-source RET" (vconcat wf-manager-live-declined)
                       "C-c C-c <f8> a" (vconcat "no") "RET <f8> d <f8> w <f8>"))
          (should (= (length wf-manager-live--reviews) 8))
          (wf-manager-live--review-fields (car wf-manager-live--reviews) "declined" report)
          (puthash "declinedSentAfterNo" (vconcat (nth 2 (nth 2 wf-manager-live--reviews)))
                   report)
          (should (equal (gethash "declinedOutcomes" report) ["discard" "withdraw"]))
          (should (equal (gethash "declinedSentAfterNo" report) []))
          (puthash "requestCommands"
                   (vconcat
                    (mapcar (pcase-lambda (`(,resource ,media ,if-match ,body))
                              (wf-manager-json-object
                               "resource" resource
                               "media" (or media "application/json")
                               "ifMatch" (or if-match :null)
                               "body" (if media
                                          (wf-manager-json-object
                                           "bytes" (wf-manager-live--integer (length body))
                                           "sha256" (secure-hash 'sha256 body))
                                        (wf-manager-json-decode body))))
                            (reverse wf-manager-live--sent)))
                   report)
          (should-not (wf-manager-live--keys "M-x wf-local RET")))
      (advice-remove 'wf-manager-session-send #'wf-manager-live--record-send)
      (global-set-key (kbd "<f7>") nil)
      (global-set-key (kbd "<f8>") nil)
      (when wf-service--current
        (wf-local))
      (delete-file captured))))

(defun wf-manager-live--write (file value)
  "Write to FILE the JSON VALUE."
  (let ((coding-system-for-write 'no-conversion))
    (write-region (wf-manager-json-encode value) nil file nil 'silent)))

(ert-deftest wf-manager-live-session ()
  "Run the thirteen steps of one live session against the manager."
  (let* ((profile (wf-manager-profile-load
                   (wf-manager-live--variable "WF_MANAGER_PROFILE")))
         (second (wf-manager-profile-load
                  (wf-manager-live--variable "WF_MANAGER_SECOND_PROFILE")))
         (unreachable (wf-manager-profile-load
                       (wf-manager-live--variable "WF_MANAGER_UNREACHABLE_PROFILE")))
         (report-file (wf-manager-live--variable "WF_MANAGER_REPORT"))
         (run-file (wf-manager-live--variable "WF_MANAGER_RUN"))
         (revoke-file (wf-manager-live--variable "WF_MANAGER_REVOKE"))
         (finish-file (wf-manager-live--variable "WF_MANAGER_FINISH"))
         (download-file (wf-manager-live--variable "WF_MANAGER_DOWNLOAD"))
         (report (wf-manager-json-object
                  "harnessVersion"
                  (wf-manager-live--integer wf-manager-live-harness-version)))
         (state (progn
                  ;; The one setup of url.el adds the global timer that
                  ;; saves its cookies.  It runs before the state is
                  ;; taken, so that a timer after the close is a timer of
                  ;; the session.
                  (url-do-setup)
                  (list (process-list) (buffer-list) (copy-sequence timer-list))))
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
            (wf-manager-live--unreachable session unreachable report)
            (push "unreachable" steps)
            (let ((earlier (wf-manager-live--switch session second report)))
              (push "switch" steps)
              (wf-manager-live--revoke session (wf-manager-session-connection session)
                                       revoke-file report)
              (push "revoke" steps)
              (wf-manager-live--close
               session state
               (list earlier (wf-manager-transport-directory
                              (wf-manager-session-transport session)))
               report)
              (push "close" steps)
              (wf-manager-live--export profile finish-file download-file report)
              (push "export" steps)
              (wf-manager-live--service (wf-manager-live--variable "WF_MANAGER_PROFILE")
                                        report)
              (push "service" steps)
              (wf-manager-live--requests (wf-manager-live--variable "WF_MANAGER_PROFILE")
                                         report)
              (push "requests" steps))))
      (dolist (function wf-manager-live--prompt-functions)
        (advice-remove function #'wf-manager-live--prompted))
      (puthash "prompts" (wf-manager-live--integer wf-manager-live--prompts) report)
      (puthash "steps" (vconcat (reverse steps)) report)
      (wf-manager-live--write report-file report))
    (should (= wf-manager-live--prompts 0))))

(provide 'wf-manager-live)

;;; wf-manager-live.el ends here
