;;; wf-manager.el --- Service-mode transport for wf.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 John Wiegley

;; Author: John Wiegley <johnw@newartisans.com>
;; Maintainer: John Wiegley <johnw@newartisans.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: tools, comm
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

;; The transport of the service mode of `wf.el'.  This file has no user
;; interface and uses only libraries that are part of Emacs.
;;
;; `wf-manager-profile-load' loads a version 1 client profile of the
;; agent-cat workflow manager.  The rules are the rules of
;; `ext-pi/src/manager/profile.ts' and of the client profile section of
;; `doc/api/README.md' in agent-cat.  A profile is a JSON object with
;; exactly the fields `version', `endpoint', `credentialFile' and `caFile'.
;; The endpoint is an https URL whose path is /v1, with no user
;; information, query or fragment.  Both files have absolute paths.
;;
;; The loader reads the credential file once, when the profile loads, and
;; keeps the bearer in the `credential' slot of the profile record.  Only
;; `wf-manager-authorization' reads that slot, to build the one
;; Authorization header of a request.
;;
;; `wf-manager-json-decode' and `wf-manager-json-encode' are an exact JSON
;; codec over `json-parse-string' and `json-serialize', with the rules of
;; `ext-pi/src/manager/json.ts'.  JSON false, JSON null and an absent
;; member are three distinct things: :false, :null and nil.  Each number
;; keeps its source text in a `wf-manager-json-number', so that an integer
;; above 2^53, 123456789012345678901234567890 and 1e400 keep their value.
;; `wf-manager-json-equal' compares numbers by exact decimal value and
;; objects without regard to the order of their members.
;;
;; The decoders of the events section of `test/manager_client_vectors.json'
;; in agent-cat follow `ext-pi/src/manager/events.ts': invalidations, event
;; batches, route records, cursors, entity tags and problem responses.  An
;; entity tag is an opaque token, equal to another tag only as text.
;;
;; The resource decoders follow the draft, preparation, receipt,
;; decision, control and run decoders of `ext-pi/src/manager/resources.ts'
;; and pass the drafts, requests, preparations, receipts, decisions,
;; controls and runs vectors of the resources section: requests,
;; readiness, declared and supplied inputs, input errors, preparations,
;; reviews, review inputs, lineages, edits, command receipts, decisions,
;; run controls, runs and the request, preparation, run and decision
;; members of the overview.  Each decoder returns a record.  The encoder of
;; a record gives its canonical JSON value.
;; `wf-manager-decision-projection', `wf-manager-control-projection' and
;; `wf-manager-run-projection' give the projection of a decision, of the
;; controls of a run and of a run.  A command receipt is valid only when
;; its state agrees with its dispatch attempt time, its acknowledgement,
;; its effect and its refusal.  The runtime summary, the supervision, the
;; integrity and the verification of a run are separate fields.
;;
;; `wf-manager-answer-value' builds the typed answer of a decision from the
;; text of a person, and `wf-manager-answer-body' builds the answer body
;; from that answer.  The answer "no" to a flag question is JSON false.  A
;; structured answer must agree with the editor schema of its decision.
;; The builder passes the answers vectors of the resources section, and it
;; refuses an answer with `wf-manager-invalid-answer' before any command is
;; built.
;;
;; The refresh coordinator follows `ext-pi/src/manager/refresh.ts' and
;; passes the sequences, backoff, jitter and reconciliation vectors of the
;; refresh section.  It performs no I/O.  `wf-manager-refresh-invalidate'
;; and `wf-manager-refresh-complete' return the next state and the
;; actions of the caller.  Each resource has at most one fetch in flight,
;; and invalidations during that fetch give one later fetch.
;; `wf-manager-refresh-advance' advances the generation after a
;; resnapshot or an endpoint switch, and a completed fetch of an earlier
;; generation installs nothing.  `wf-manager-reconnect-delay' and
;; `wf-manager-jittered-microseconds' give the reconnection backoff and
;; its jitter.  `wf-manager-reconcile-read' and `wf-manager-reconcile'
;; reconcile an uncertain command with one read of its receipt, of its
;; target or of a supplied resource.  No action and no report is a send,
;; and an uncertain command keeps its exact bytes, key and precondition.
;;
;; The HTTP transport sends each request with `url-retrieve' over the
;; GnuTLS of Emacs, so the wait for a response does not block editing.
;; The connection and its TLS handshake open before `url-retrieve'
;; returns, as `wf-manager--retrieve' explains.
;; `wf-manager-transport-open' makes the transport of a profile.
;; `wf-manager-get', `wf-manager-post' and `wf-manager-poll-events'
;; return a cancellable `wf-manager-exchange' and call their callback one
;; time with the result or a failure (CONDITION . DATA).
;; `wf-manager-cancel' ends one request, and `wf-manager-transport-close'
;; ends every pending request and removes its url.el processes and
;; buffers.  A request has exactly one Authorization header and one
;; Accept header, and url.el adds no other negotiation header.  A
;; response body above its bound ends the request.  `wf-manager-connect'
;; binds a transport by GET /v1/capabilities, checked by
;; `wf-manager-check-capabilities' as checkCapabilities of
;; `ext-pi/src/manager/session.ts' checks it, with a fresh random
;; endpoint identity.  `wf-manager-command-key' gives the idempotency
;; keys of a connection, <authorityEpoch>.<nonce>.
;;
;; url.el calls its callback one time, after the complete response, and
;; it has no supported facility that delivers an open response as it
;; arrives.  The client therefore reads /v1/events in the bounded
;; polling mode, named `poll', and not as server-sent events.
;;
;; `wf-manager-session-start' starts a session on a connection, as
;; ManagerSession of `ext-pi/src/manager/session.ts' does.  The session
;; assembles the complete overview page set of /v1/snapshot by following
;; its next tokens, restarts the assembly after a 410 view-expired page,
;; and installs the overview.  Every member reference carries the
;; endpoint identity of the connection.  The session then follows
;; /v1/events from the overview cursor with polling batches on timers and
;; the reconnection backoff.  An invalidation marks the watched resources
;; that it concerns, and the refresh coordinator reads each of them
;; again.  A 410 refusal of a batch advances the generation, reads the
;; overview again and reads every watched resource again.  A read of an
;; earlier generation installs nothing.  `wf-manager-session-switch'
;; binds the session to the endpoint of another profile, as
;; switchEndpoint of ext-pi does, and commits only after the complete
;; overview of the new binding has loaded.  A switch that fails keeps the
;; earlier binding.  `wf-manager-session-close' ends every request and
;; timer of the session and sends no command.
;;
;; Each refusal signals a condition below `wf-manager-error'.  The data of
;; the condition is (FIELD REASON).  For a profile, FIELD is the JSON name
;; of the profile field that the refusal is about, or "profile" for the
;; profile file itself.  For a response, FIELD names the kind of value,
;; such as "invalidation" or "route record".  For an answer, FIELD is
;; "answer".  REASON is a sentence for a person.  The one exception is
;; `wf-manager-refused', the refusal of a problem response, whose data is
;; (STATUS CODE).

;;; Code:

(require 'cl-lib)
(require 'gnutls)
(require 'nsm)
(require 'url)
(require 'url-cache)
(require 'parse-time)
(require 'url-http)

(defconst wf-manager-profile-file-bytes 16384
  "The largest client profile file, in bytes.")

(defconst wf-manager-ca-file-bytes 1048576
  "The largest CA file of a client profile, in bytes.")

(defconst wf-manager-credential-max-bytes 512
  "The largest credential, in bytes.")

(defconst wf-manager-credential-min-bytes 32
  "The smallest credential, in bytes.")

(defconst wf-manager--path-bytes 4096
  "The longest file path of a client profile, in UTF-8 bytes.")

(defconst wf-manager--endpoint-characters 8192
  "The longest endpoint of a client profile, in characters.")

(defconst wf-manager--profile-fields
  '("version" "endpoint" "credentialFile" "caFile")
  "The fields of a version 1 client profile, all of them required.")

(define-error 'wf-manager-error "Manager client failure")
(define-error 'wf-manager-invalid-profile
              "Invalid client profile" 'wf-manager-error)
(define-error 'wf-manager-file-unavailable
              "Client file unavailable" 'wf-manager-error)
(define-error 'wf-manager-invalid-endpoint
              "Invalid manager endpoint" 'wf-manager-error)
(define-error 'wf-manager-credential-unavailable
              "Credential unavailable" 'wf-manager-error)
(define-error 'wf-manager-invalid-response
              "Invalid manager response" 'wf-manager-error)
(define-error 'wf-manager-response-too-large
              "Manager response too large" 'wf-manager-error)
(define-error 'wf-manager-refused
              "Refused by the manager" 'wf-manager-error)
(define-error 'wf-manager-invalid-answer
              "Invalid answer" 'wf-manager-error)
(define-error 'wf-manager-transport-unavailable
              "Manager transport unavailable" 'wf-manager-error)
(define-error 'wf-manager-redirect-refused
              "Manager redirect refused" 'wf-manager-error)
(define-error 'wf-manager-unsupported-version
              "Unsupported manager version" 'wf-manager-error)
(define-error 'wf-manager-invalid-request
              "Invalid manager request" 'wf-manager-error)
(define-error 'wf-manager-closed
              "Manager client closed" 'wf-manager-error)
(define-error 'wf-manager-wrong-endpoint
              "Reference of another endpoint" 'wf-manager-error)

(cl-defstruct (wf-manager-endpoint
               (:constructor wf-manager--endpoint-make)
               (:copier nil))
  "The endpoint of a client profile.
URL is the endpoint text of the profile.  HOST is the host name or
address, without brackets.  PORT is the TCP port.  BASE is the path
\"/v1\" that every route of the manager starts with."
  (url nil :read-only t)
  (host nil :read-only t)
  (port nil :read-only t)
  (base "/v1" :read-only t))

(cl-defstruct (wf-manager-profile
               (:constructor wf-manager--profile-make)
               (:copier nil))
  "One loaded client profile.
FILE is the profile file.  ENDPOINT is a `wf-manager-endpoint'.  CA-FILE
is the CA file, which holds the only trust anchors of the session.
CREDENTIAL-FILE is the credential file, and CREDENTIAL is the bearer
that the loader read from it.  Only `wf-manager-authorization' reads
CREDENTIAL."
  (file nil :read-only t)
  (endpoint nil :read-only t)
  (ca-file nil :read-only t)
  (credential-file nil :read-only t)
  (credential nil :read-only t))

(defun wf-manager--fail (condition field reason &rest args)
  "Signal CONDITION about FIELD, with REASON formatted with ARGS."
  (signal condition (list field (apply #'format reason args))))

(defun wf-manager-valid-path-p (path)
  "Return non-nil when PATH is a valid file path of a client profile.
A valid path is a string that starts with a slash, has at most 4096
UTF-8 bytes and holds no NUL, line feed or carriage return."
  (and (stringp path)
       (string-prefix-p "/" path)
       (not (string-match-p "[\0\n\r]" path))
       (<= (string-bytes (encode-coding-string path 'utf-8-unix))
           wf-manager--path-bytes)))

(defun wf-manager--read-file (field path limit private)
  "Return for FIELD the bytes of the local file PATH as a unibyte string.
The file is a regular file and not a symbolic link.  It has at most
LIMIT bytes, and no group or other user can write it.  When PRIVATE is
non-nil, the file also belongs to the user, has no group or other
permission bits and has one link.  Every other file signals
`wf-manager-file-unavailable' about FIELD."
  (let* ((file-name-handler-alist nil)
         (attributes (file-attributes path 'integer))
         (modes (and attributes (file-modes path 'nofollow))))
    (cond
     ((null attributes)
      (wf-manager--fail 'wf-manager-file-unavailable field
                        "%s does not exist" path))
     ((not (eq (aref (file-attribute-modes attributes) 0) ?-))
      (wf-manager--fail 'wf-manager-file-unavailable field
                        "%s is not a regular file" path))
     ((> (file-attribute-size attributes) limit)
      (wf-manager--fail 'wf-manager-file-unavailable field
                        "%s has more than %d bytes" path limit))
     ((/= (logand modes #o022) 0)
      (wf-manager--fail 'wf-manager-file-unavailable field
                        "a group or other user can write %s" path))
     ((and private (/= (file-attribute-user-id attributes) (user-uid)))
      (wf-manager--fail 'wf-manager-file-unavailable field
                        "%s does not belong to this user" path))
     ((and private (/= (logand modes #o077) 0))
      (wf-manager--fail 'wf-manager-file-unavailable field
                        "%s has group or other permissions, not mode 0600"
                        path))
     ((and private (/= (file-attribute-link-number attributes) 1))
      (wf-manager--fail 'wf-manager-file-unavailable field
                        "%s has more than one link" path)))
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (condition-case failure
          (insert-file-contents-literally path nil 0 (1+ limit))
        (file-error
         (wf-manager--fail 'wf-manager-file-unavailable field
                           "%s cannot be read: %s" path
                           (error-message-string failure))))
      (when (> (buffer-size) limit)
        (wf-manager--fail 'wf-manager-file-unavailable field
                          "%s has more than %d bytes" path limit))
      (buffer-string))))

(defun wf-manager--utf-8 (condition field bytes)
  "Signal CONDITION about FIELD unless BYTES are UTF-8.
Return the text of BYTES, decoded as UTF-8."
  (let ((text (decode-coding-string bytes 'utf-8-unix t)))
    (unless (wf-manager--unicode-p text)
      (wf-manager--fail condition field "the bytes are not UTF-8"))
    text))

(defun wf-manager--unicode-p (text)
  "Return non-nil when every character of TEXT is a Unicode character.
A raw byte that is not part of a UTF-8 sequence is not a Unicode
character."
  (not (cl-find-if (lambda (char) (> char (max-char t))) text)))

(defun wf-manager--profile-fields (text)
  "Return the field values of profile TEXT as an alist from name to value.
TEXT is one JSON object with exactly the fields of
`wf-manager--profile-fields', each one time.  `version' is the integer
1, and the other fields are strings.  `credentialFile' and `caFile'
are valid paths in the sense of `wf-manager-valid-path-p'.  Any other
TEXT signals `wf-manager-invalid-profile'."
  (let ((value (condition-case nil
                   (json-parse-string text :object-type 'alist
                                      :null-object :null :false-object :false)
                 (json-error
                  (wf-manager--fail 'wf-manager-invalid-profile "profile"
                                    "the file is not one JSON value"))))
        (fields nil))
    (unless (listp value)
      (wf-manager--fail 'wf-manager-invalid-profile "profile"
                        "the file is not a JSON object"))
    (dolist (pair value)
      (let ((name (symbol-name (car pair))))
        (cond
         ((not (member name wf-manager--profile-fields))
          (wf-manager--fail 'wf-manager-invalid-profile name
                            "%s is not a field of a version 1 profile" name))
         ((assoc name fields)
          (wf-manager--fail 'wf-manager-invalid-profile name
                            "%s occurs more than one time" name)))
        (push (cons name (cdr pair)) fields)))
    (dolist (name wf-manager--profile-fields)
      (unless (assoc name fields)
        (wf-manager--fail 'wf-manager-invalid-profile name
                          "the profile has no %s field" name)))
    (unless (eql (cdr (assoc "version" fields)) 1)
      (wf-manager--fail 'wf-manager-invalid-profile "version"
                        "version is not the integer 1"))
    (unless (stringp (cdr (assoc "endpoint" fields)))
      (wf-manager--fail 'wf-manager-invalid-profile "endpoint"
                        "endpoint is not a string"))
    (dolist (name '("credentialFile" "caFile"))
      (unless (wf-manager-valid-path-p (cdr (assoc name fields)))
        (wf-manager--fail 'wf-manager-invalid-profile name
                          "%s is not an absolute path" name)))
    fields))

(defun wf-manager-parse-endpoint (text)
  "Return the `wf-manager-endpoint' of endpoint TEXT.
TEXT has at most 8192 characters and starts with \"https://\".  It
holds no space, control character, \"@\", \"?\", \"#\" or backslash.
The authority is an ASCII host name or a bracketed IPv6 address, with
an optional port from 1 to 65535.  The path is \"/v1\" or \"/v1/\".
Any other TEXT signals `wf-manager-invalid-endpoint' about the field
\"endpoint\"."
  (unless (and (stringp text)
               (<= (length text) wf-manager--endpoint-characters)
               (string-prefix-p "https://" text))
    (wf-manager--fail 'wf-manager-invalid-endpoint "endpoint"
                      "the endpoint is not an https URL"))
  (when (string-match-p "[\0- @?#\\]" text)
    (wf-manager--fail 'wf-manager-invalid-endpoint "endpoint"
                      "the endpoint holds a user part, query, fragment, space or control character"))
  (let* ((rest (substring text (length "https://")))
         (slash (string-search "/" rest))
         (authority (if slash (substring rest 0 slash) rest))
         (path (if slash (substring rest slash) "")))
    (unless (member path '("/v1" "/v1/"))
      (wf-manager--fail 'wf-manager-invalid-endpoint "endpoint"
                        "the endpoint path is not /v1"))
    (unless (string-match
             (rx bos
                 (or (seq "[" (group (* (any "0-9A-Fa-f.")) ":"
                                     (* (any "0-9A-Fa-f:.")))
                          "]")
                     (group (+ (any "A-Za-z0-9" "-._~!$&'()*+,;="))))
                 (? ":" (group (* digit)))
                 eos)
             authority)
      (wf-manager--fail 'wf-manager-invalid-endpoint "endpoint"
                        "the endpoint host is not a host name or IPv6 address"))
    (let ((host (downcase (or (match-string 1 authority)
                              (match-string 2 authority))))
          (port (match-string 3 authority)))
      (setq port (if (member port '(nil "")) 443 (string-to-number port)))
      (unless (<= 1 port 65535)
        (wf-manager--fail 'wf-manager-invalid-endpoint "endpoint"
                          "the endpoint port is not from 1 to 65535"))
      (wf-manager--endpoint-make :url text :host host :port port))))

(defun wf-manager--check-certificates (text)
  "Signal `wf-manager-invalid-profile' unless CA TEXT has certificates.
TEXT holds at least one PEM certificate block, and the base64 body of
each block decodes to a DER sequence.  The TLS handshake validates the
certificates themselves."
  (let ((count 0))
    (with-temp-buffer
      (insert text)
      (goto-char (point-min))
      (while (search-forward "-----BEGIN CERTIFICATE-----" nil t)
        (let* ((start (point))
               (end (if (search-forward "-----END CERTIFICATE-----" nil t)
                        (match-beginning 0)
                      (wf-manager--fail 'wf-manager-invalid-profile "caFile"
                                        "a certificate block has no end line")))
               (body (replace-regexp-in-string
                      "[ \t\r\n]+" "" (buffer-substring-no-properties start end)))
               (der (condition-case nil
                        (base64-decode-string body)
                      (error nil))))
          (unless (and der (> (length der) 0) (eq (aref der 0) #x30))
            (wf-manager--fail 'wf-manager-invalid-profile "caFile"
                              "a certificate block is not a DER certificate"))
          (setq count (1+ count)))))
    (when (= count 0)
      (wf-manager--fail 'wf-manager-invalid-profile "caFile"
                        "the CA file holds no PEM certificate"))))

(defun wf-manager--credential (bytes)
  "Return the bearer of credential BYTES.
The bearer is 32 to 512 visible ASCII bytes other than the comma.  Any
other BYTES signal `wf-manager-credential-unavailable' about the
field \"credentialFile\"."
  (unless (<= wf-manager-credential-min-bytes (length bytes)
              wf-manager-credential-max-bytes)
    (wf-manager--fail 'wf-manager-credential-unavailable "credentialFile"
                      "the credential has %d bytes, not %d to %d"
                      (length bytes) wf-manager-credential-min-bytes
                      wf-manager-credential-max-bytes))
  (unless (cl-every (lambda (byte) (and (< 32 byte 127) (/= byte ?,))) bytes)
    (wf-manager--fail 'wf-manager-credential-unavailable "credentialFile"
                      "the credential holds a byte that is not visible ASCII or is a comma"))
  bytes)

(defun wf-manager-profile-load (file)
  "Load the client profile at the absolute path FILE.
Return a `wf-manager-profile'.  The profile file is private, has at
most `wf-manager-profile-file-bytes' bytes and holds a version 1
profile.  The CA file is a regular file of at most
`wf-manager-ca-file-bytes' bytes that holds at least one PEM
certificate.  The credential file is private and holds the bearer.  A
private file is a regular file of the user with no group or other
permission bits, such as mode 0600, and one link.

Each refusal happens before any request and signals a condition below
`wf-manager-error' with the data (FIELD REASON):
`wf-manager-invalid-profile' for a profile that does not parse or has
other fields, `wf-manager-invalid-endpoint' for the endpoint,
`wf-manager-file-unavailable' for a file that is missing, too large,
not regular or not private, and `wf-manager-credential-unavailable' for
credential bytes outside the bounds."
  (unless (wf-manager-valid-path-p file)
    (wf-manager--fail 'wf-manager-invalid-profile "profile"
                      "the profile file is not an absolute path"))
  (let* ((fields (wf-manager--profile-fields
                  (wf-manager--utf-8
                   'wf-manager-invalid-profile "profile"
                   (wf-manager--read-file "profile" file
                                          wf-manager-profile-file-bytes t))))
         (endpoint (wf-manager-parse-endpoint (cdr (assoc "endpoint" fields))))
         (ca-file (cdr (assoc "caFile" fields)))
         (credential-file (cdr (assoc "credentialFile" fields))))
    (wf-manager--check-certificates
     (wf-manager--utf-8
      'wf-manager-invalid-profile "caFile"
      (wf-manager--read-file "caFile" ca-file
                                      wf-manager-ca-file-bytes nil)))
    (wf-manager--profile-make
     :file file
     :endpoint endpoint
     :ca-file ca-file
     :credential-file credential-file
     :credential (wf-manager--credential
                  (wf-manager--read-file "credentialFile" credential-file
                                         wf-manager-credential-max-bytes t)))))

(defun wf-manager-authorization (profile)
  "Return the Authorization header of one request with PROFILE.
The value is a cons of the header name and the header value."
  (cons "Authorization"
        (concat "Bearer " (wf-manager-profile-credential profile))))

;;;; Exact JSON values

(defconst wf-manager-response-bytes 1048576
  "The largest response body that `wf-manager-json-decode' parses, in bytes.")

(defconst wf-manager--word64-max 18446744073709551615
  "The largest unsigned 64-bit integer.")

(defconst wf-manager--json-number-regexp
  "-?\\(?:0\\|[1-9][0-9]*\\)\\(?:\\.[0-9]+\\)?\\(?:[eE][-+]?[0-9]+\\)?"
  "The grammar of a JSON number.")

(cl-defstruct (wf-manager-json-number
               (:constructor wf-manager--json-number-make (source))
               (:copier nil))
  "One JSON number, held as its source text.
SOURCE is a number of the JSON grammar.  `wf-manager-json-encode' writes
SOURCE back unchanged, so that no number loses its value."
  (source nil :read-only t))

(defun wf-manager--matches-p (regexp string)
  "Return non-nil when REGEXP matches all of STRING, with case."
  (let ((case-fold-search nil))
    (string-match-p (concat "\\`\\(?:" regexp "\\)\\'") string)))

(defun wf-manager-json-number (source)
  "Return the JSON number whose source text is the string SOURCE.
SOURCE that is not a number of the JSON grammar signals
`wrong-type-argument'."
  (unless (and (stringp source)
               (wf-manager--matches-p wf-manager--json-number-regexp source))
    (signal 'wrong-type-argument (list 'wf-manager-json-number source)))
  (wf-manager--json-number-make source))

(defun wf-manager-json-integer (integer)
  "Return the JSON number of the Lisp INTEGER, exactly."
  (unless (integerp integer)
    (signal 'wrong-type-argument (list 'integerp integer)))
  (wf-manager--json-number-make (number-to-string integer)))

(defun wf-manager--json-mark (text)
  "Return TEXT with each string token and each number token marked.
Each string token gains the character S after its opening quote.  Each
number token becomes a string token of the character N and the number
text.  `json-parse-string' then keeps the source text of every number,
and `wf-manager--json-unmark' tells the two kinds of string apart.  A
string token with no closing quote signals
`wf-manager-invalid-response'.  Other text that is not JSON stays text
that is not JSON."
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (let ((case-fold-search nil))
      (while (progn (skip-chars-forward "^\"0-9-") (not (eobp)))
        (cond
         ((eq (char-after) ?\")
          (forward-char 1)
          (insert "S")
          (while (progn (skip-chars-forward "^\"\\\\") (eq (char-after) ?\\))
            (goto-char (min (point-max) (+ (point) 2))))
          (when (eobp)
            (wf-manager--fail 'wf-manager-invalid-response "JSON"
                              "a string has no closing quote"))
          (forward-char 1))
         ((looking-at wf-manager--json-number-regexp)
          (replace-match (concat "\"N" (match-string 0) "\"") t t))
         (t (forward-char 1)))))
    (buffer-string)))

(defun wf-manager--json-unmark (value)
  "Return the JSON value of VALUE, a value of marked text.
VALUE is the result of `json-parse-string' over the text of
`wf-manager--json-mark'.  A number in the place of an object member name
signals `wf-manager-invalid-response'."
  (cond
   ((stringp value)
    (if (eq (aref value 0) ?N)
        (wf-manager--json-number-make (substring value 1))
      (substring value 1)))
   ((vectorp value) (cl-map 'vector #'wf-manager--json-unmark value))
   ((hash-table-p value)
    (let ((object (make-hash-table :test #'equal
                                   :size (hash-table-count value))))
      (maphash (lambda (name member)
                 (when (eq (aref name 0) ?N)
                   (wf-manager--fail 'wf-manager-invalid-response "JSON"
                                     "a number is the name of a member"))
                 (puthash (substring name 1) (wf-manager--json-unmark member)
                          object))
               value)
      object))
   (t value)))

(defun wf-manager-json-decode (text &optional limit)
  "Return the JSON value of TEXT, with every number exact.
TEXT is a unibyte string of UTF-8 bytes or a multibyte string.  It holds
one JSON value, with optional white space around it.

A JSON object becomes a hash table with the test `equal' and string
keys, an array a vector, a string a string, a number a
`wf-manager-json-number', true t, false :false and null :null.  No JSON
value is nil, so `gethash' gives nil only for an absent member.  When an
object has a name more than one time, the last member counts.

TEXT of more than LIMIT bytes, by default `wf-manager-response-bytes',
signals `wf-manager-response-too-large' before any parsing.  TEXT that
is not UTF-8 or not JSON signals `wf-manager-invalid-response'."
  (unless (stringp text)
    (signal 'wrong-type-argument (list 'stringp text)))
  (let ((limit (or limit wf-manager-response-bytes)))
    (when (> (string-bytes text) limit)
      (wf-manager--fail 'wf-manager-response-too-large "JSON"
                        "the text has more than %d bytes" limit)))
  (let ((source (if (multibyte-string-p text)
                    text
                  (wf-manager--utf-8 'wf-manager-invalid-response "JSON" text))))
    (unless (wf-manager--unicode-p source)
      (wf-manager--fail 'wf-manager-invalid-response "JSON"
                        "the text is not Unicode"))
    (wf-manager--json-unmark
     (condition-case nil
         (json-parse-string (wf-manager--json-mark source)
                            :object-type 'hash-table :array-type 'array
                            :null-object :null :false-object :false)
       (json-error
        (wf-manager--fail 'wf-manager-invalid-response "JSON"
                          "the text is not one JSON value"))))))

(defun wf-manager--json-names (object)
  "Return the member names of OBJECT in the order of their UTF-16 code units."
  (let ((names nil))
    (maphash (lambda (name _member) (push name names)) object)
    (sort names (lambda (a b)
                  (string< (encode-coding-string a 'utf-16be)
                           (encode-coding-string b 'utf-16be))))))

(defun wf-manager--json-insert (value)
  "Insert the compact JSON text of VALUE at point, as UTF-8 bytes."
  (cond
   ((eq value t) (insert "true"))
   ((eq value :false) (insert "false"))
   ((eq value :null) (insert "null"))
   ((stringp value) (insert (json-serialize value)))
   ((wf-manager-json-number-p value)
    (insert (wf-manager-json-number-source value)))
   ((vectorp value)
    (insert "[")
    (dotimes (index (length value))
      (when (> index 0) (insert ","))
      (wf-manager--json-insert (aref value index)))
    (insert "]"))
   ((hash-table-p value)
    (insert "{")
    (let ((first t))
      (dolist (name (wf-manager--json-names value))
        (unless first (insert ","))
        (setq first nil)
        (insert (json-serialize name) ":")
        (wf-manager--json-insert (gethash name value))))
    (insert "}"))
   (t (signal 'wrong-type-argument (list 'wf-manager-json-value value)))))

(defun wf-manager-json-encode (value)
  "Return the compact JSON text of VALUE as a unibyte string of UTF-8 bytes.
VALUE is a JSON value in the sense of `wf-manager-json-decode'.  The
text has no white space, the members of each object are in the order
of the UTF-16 code units of their names, and each number is its source
text.  Any other VALUE signals `wrong-type-argument'."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (wf-manager--json-insert value)
    (buffer-string)))

(defun wf-manager--decimal (number)
  "Return the exact decimal value of the JSON NUMBER.
The value is a list (NEGATIVE DIGITS EXPONENT): NEGATIVE is non-nil for
a value below zero, DIGITS is the coefficient without leading or
trailing zeros, and EXPONENT is a power of ten.  Zero is (nil \"0\" 0),
so -0 equals 0."
  (let ((source (wf-manager-json-number-source number)))
    (string-match (concat "\\`\\(-?\\)\\(0\\|[1-9][0-9]*\\)"
                          "\\(?:\\.\\([0-9]+\\)\\)?\\(?:[eE]\\([-+]?[0-9]+\\)\\)?\\'")
                  source)
    (let* ((negative (equal (match-string 1 source) "-"))
           (fraction (or (match-string 3 source) ""))
           (digits (replace-regexp-in-string
                    "\\`0+" "" (concat (match-string 2 source) fraction)))
           (exponent (- (string-to-number (or (match-string 4 source) "0"))
                        (length fraction))))
      (if (equal digits "")
          (list nil "0" 0)
        (let ((trimmed (replace-regexp-in-string "0+\\'" "" digits)))
          (list negative trimmed
                (+ exponent (- (length digits) (length trimmed)))))))))

(defun wf-manager--bounded-integer (value minimum maximum)
  "Return the integer of VALUE, or nil.
VALUE is a JSON number whose value is integral and from MINIMUM to
MAXIMUM.  7.0 and 70e-1 give 7.  7.5, 1e400 and every value outside the
range give nil."
  (when (wf-manager-json-number-p value)
    (pcase-let ((`(,negative ,digits ,exponent) (wf-manager--decimal value)))
      (when (and (>= exponent 0)
                 (<= (+ (length digits) exponent)
                     (max (length (number-to-string minimum))
                          (length (number-to-string maximum)))))
        (let* ((magnitude (* (string-to-number digits) (expt 10 exponent)))
               (integer (if negative (- magnitude) magnitude)))
          (and (<= minimum integer maximum) integer))))))

(defun wf-manager--word64 (value)
  "Return the unsigned 64-bit integer of the JSON VALUE, or nil."
  (wf-manager--bounded-integer value 0 wf-manager--word64-max))

(defun wf-manager-json-equal (a b)
  "Return non-nil when the JSON values A and B are equal.
Numbers are equal by exact decimal value, arrays element by element,
and objects by their sets of members.  :false, :null and t are three
distinct values."
  (cond
   ((or (wf-manager-json-number-p a) (wf-manager-json-number-p b))
    (and (wf-manager-json-number-p a) (wf-manager-json-number-p b)
         (equal (wf-manager--decimal a) (wf-manager--decimal b))))
   ((and (stringp a) (stringp b)) (string= a b))
   ((and (vectorp a) (vectorp b))
    (and (= (length a) (length b)) (cl-every #'wf-manager-json-equal a b)))
   ((and (hash-table-p a) (hash-table-p b))
    (and (= (hash-table-count a) (hash-table-count b))
         (catch 'differ
           (maphash (lambda (name member)
                      (let ((other (gethash name b)))
                        (unless (and other (wf-manager-json-equal member other))
                          (throw 'differ nil))))
                    a)
           t)))
   (t (eq a b))))

(defun wf-manager-json-object (&rest members)
  "Return a JSON object of MEMBERS, which alternate names and values."
  (let ((object (make-hash-table :test #'equal)))
    (while members
      (puthash (pop members) (pop members) object))
    object))

;;;; Event decoders

(defconst wf-manager-event-names
  '("request.changed" "preparation.changed" "run.changed"
    "decision.changed" "command.changed" "artifact.changed"
    "service.changed")
  "The seven event names of the /v1/events stream.")

(defconst wf-manager-route-schemas
  '("start" "control" "question" "answer" "engine-start" "turn" "steer"
    "done" "event" "permission" "command" "receipt" "review" "relay"
    "notice")
  "The schemas of route records.")

(defconst wf-manager--id-regexp "[A-Za-z0-9_-]\\{1,128\\}"
  "The grammar of a bounded identifier.")

(defconst wf-manager--batch-events 256
  "The largest number of events in one polling batch.")

(defun wf-manager-valid-id-p (value)
  "Return non-nil when VALUE is a bounded identifier.
A bounded identifier is 1 to 128 ASCII letters, digits, `_' and `-'."
  (and (stringp value) (wf-manager--matches-p wf-manager--id-regexp value)))

(defun wf-manager-valid-resource-p (value)
  "Return non-nil when VALUE is a resource path below /v1/.
The path has 5 to 8192 characters, all of them ASCII letters, digits or
one of `_-/?=&.%'."
  (and (stringp value)
       (< 4 (length value) 8193)
       (string-prefix-p "/v1/" value)
       (wf-manager--matches-p "[A-Za-z0-9_/?=&.%-]*" value)))

(defun wf-manager-valid-cursor-p (value)
  "Return non-nil when VALUE is a canonical event cursor.
A cursor is a bounded identifier, a dot and a canonical unsigned 64-bit
decimal.  Event, route and manager-route cursors share this syntax."
  (and (stringp value)
       (let ((case-fold-search nil))
         (string-match (concat "\\`" wf-manager--id-regexp
                               "\\.\\(0\\|[1-9][0-9]\\{0,19\\}\\)\\'")
                       value))
       (<= (string-to-number (match-string 1 value)) wf-manager--word64-max)))

(defun wf-manager-valid-etag-p (value)
  "Return non-nil when VALUE is a strong entity tag, a quoted identifier."
  (and (stringp value)
       (wf-manager--matches-p (concat "\"" wf-manager--id-regexp "\"") value)))

(defun wf-manager-etag-equal (a b)
  "Return non-nil when the entity tags A and B match.
A tag is an opaque token: two tags match only when they are equal as
text, and a tag carries no order."
  (and (stringp a) (stringp b) (string= a b)))

(cl-defstruct (wf-manager-invalidation
               (:constructor wf-manager-invalidation-make)
               (:copier nil))
  "A versioned resource invalidation.
RESOURCE is a resource path below /v1/.  REVISION is an equality token."
  (resource nil :read-only t)
  (revision nil :read-only t))

(cl-defstruct (wf-manager-invalidation-event
               (:constructor wf-manager-invalidation-event-make)
               (:copier nil))
  "One event of a polling batch or of the /v1/events stream.
ID is the cursor of the event.  NAME is one of `wf-manager-event-names'.
DATA is a `wf-manager-invalidation'."
  (id nil :read-only t)
  (name nil :read-only t)
  (data nil :read-only t))

(cl-defstruct (wf-manager-event-batch
               (:constructor wf-manager-event-batch-make)
               (:copier nil))
  "One JSON polling batch of /v1/events.
CURSOR and OLDEST-CURSOR are cursors, used as supplied.  EVENTS is a
list of `wf-manager-invalidation-event'.  HAS-MORE is non-nil when the
manager has more events after CURSOR."
  (cursor nil :read-only t)
  (oldest-cursor nil :read-only t)
  (events nil :read-only t)
  (has-more nil :read-only t))

(cl-defstruct (wf-manager-route-record
               (:constructor wf-manager-route-record-make)
               (:copier nil))
  "One record of a run route or of the manager route.
ID is the cursor of the next position.  CLASS is \"public\" or
\"actor\".  POSITION is an integer.  SCHEMA is one of
`wf-manager-route-schemas'.  FROM is \"manager\" or a JSON object, TO is
\"public\" or a JSON object, and ABOUT is a JSON object.  REPLY-TO is an
integer, or nil for JSON null.  AT is the time text.  PAYLOAD is one of
\(body VALUE), with VALUE an exact JSON value, (claim SHA256 BYTES) and
\(event SEQUENCE)."
  (id nil :read-only t)
  (class nil :read-only t)
  (position nil :read-only t)
  (schema nil :read-only t)
  (from nil :read-only t)
  (to nil :read-only t)
  (about nil :read-only t)
  (reply-to nil :read-only t)
  (at nil :read-only t)
  (payload nil :read-only t))

(defun wf-manager--closed (value names)
  "Return VALUE when it is a JSON object whose member names are NAMES."
  (and (hash-table-p value)
       (= (hash-table-count value) (length names))
       (cl-every (lambda (name) (gethash name value)) names)
       value))

(defun wf-manager--text (value)
  "Return VALUE when it is a string, otherwise nil."
  (and (stringp value) value))

(defun wf-manager--version-one-p (fields)
  "Return non-nil when the `version' member of FIELDS is the number 1."
  (let ((version (gethash "version" fields)))
    (and (wf-manager-json-number-p version)
         (equal (wf-manager--decimal version) '(nil "1" 0)))))

(defun wf-manager--cursor-field (fields name)
  "In the object FIELDS, return the member NAME when it is a cursor.
Otherwise return nil."
  (let ((value (gethash name fields)))
    (and (wf-manager-valid-cursor-p value) value)))

(defun wf-manager--decided (kind value)
  "For a value of KIND, return VALUE when it is non-nil.
A nil VALUE signals `wf-manager-invalid-response' about KIND."
  (or value
      (wf-manager--fail 'wf-manager-invalid-response kind
                        "the value is not a valid %s" kind)))

(defun wf-manager--parse-invalidation (value)
  "Return the `wf-manager-invalidation' of the JSON VALUE, or nil."
  (let ((fields (wf-manager--closed value '("version" "resource" "revision"))))
    (when (and fields (wf-manager--version-one-p fields))
      (let ((resource (gethash "resource" fields))
            (revision (gethash "revision" fields)))
        (when (and (wf-manager-valid-resource-p resource)
                   (wf-manager-valid-id-p revision))
          (wf-manager-invalidation-make :resource resource
                                        :revision revision))))))

(defun wf-manager--parse-invalidation-event (value)
  "Return the `wf-manager-invalidation-event' of the JSON VALUE, or nil."
  (let ((fields (wf-manager--closed value '("id" "event" "data"))))
    (when fields
      (let ((id (wf-manager--cursor-field fields "id"))
            (name (car (member (gethash "event" fields) wf-manager-event-names)))
            (data (wf-manager--parse-invalidation (gethash "data" fields))))
        (when (and id name data)
          (wf-manager-invalidation-event-make :id id :name name :data data))))))

(defun wf-manager--parse-event-batch (value)
  "Return the `wf-manager-event-batch' of the JSON VALUE, or nil."
  (let ((fields (wf-manager--closed
                 value '("version" "cursor" "oldestCursor" "events" "hasMore"))))
    (when (and fields (wf-manager--version-one-p fields))
      (let ((cursor (wf-manager--cursor-field fields "cursor"))
            (oldest (wf-manager--cursor-field fields "oldestCursor"))
            (listed (gethash "events" fields))
            (has-more (gethash "hasMore" fields)))
        (when (and cursor oldest (vectorp listed)
                   (<= (length listed) wf-manager--batch-events)
                   (memq has-more '(t :false)))
          (let ((events (mapcar #'wf-manager--parse-invalidation-event listed)))
            (unless (memq nil events)
              (wf-manager-event-batch-make :cursor cursor :oldest-cursor oldest
                                           :events events
                                           :has-more (eq has-more t)))))))))

(defun wf-manager--parse-route-payload (name value)
  "Return the payload of the route record member NAME with VALUE, or nil."
  (pcase name
    ("body" (list 'body value))
    ("claim"
     (let* ((claim (wf-manager--closed value '("sha256" "bytes")))
            (sha256 (and claim (gethash "sha256" claim)))
            (bytes (and claim (wf-manager--word64 (gethash "bytes" claim)))))
       (when (and (stringp sha256) (wf-manager--matches-p "[0-9a-f]\\{64\\}" sha256)
                  bytes)
         (list 'claim sha256 bytes))))
    ("event"
     (let* ((event (wf-manager--closed value '("sequence")))
            (sequence (and event (wf-manager--word64 (gethash "sequence" event)))))
       (when sequence
         (list 'event sequence))))))

(defconst wf-manager--route-header
  '("id" "class" "position" "schema" "from" "to" "about" "replyTo" "at")
  "The members of a route record other than its payload.")

(defun wf-manager--parse-route-record (value)
  "Return the `wf-manager-route-record' of the JSON VALUE, or nil."
  (let* ((bodies (and (hash-table-p value)
                      (cl-remove-if-not (lambda (name) (gethash name value))
                                        '("body" "claim" "event"))))
         (fields (and (= (length bodies) 1)
                      (wf-manager--closed value (cons (car bodies)
                                                      wf-manager--route-header)))))
    (when fields
      (let* ((id (wf-manager--cursor-field fields "id"))
             (class (car (member (gethash "class" fields) '("public" "actor"))))
             (position (wf-manager--word64 (gethash "position" fields)))
             (schema (car (member (gethash "schema" fields)
                                  wf-manager-route-schemas)))
             (from (gethash "from" fields))
             (to (gethash "to" fields))
             (about (gethash "about" fields))
             (reply (gethash "replyTo" fields))
             (reply-to (if (eq reply :null) :null (wf-manager--word64 reply)))
             (at (wf-manager--text (gethash "at" fields))))
        (when (and id class position schema reply-to at
                   (< position wf-manager--word64-max)
                   (equal (substring id (1+ (string-search "." id)))
                          (number-to-string (1+ position)))
                   (or (equal from "manager") (hash-table-p from))
                   (or (equal to "public") (hash-table-p to))
                   (hash-table-p about))
          (let ((payload (wf-manager--parse-route-payload
                          (car bodies) (gethash (car bodies) fields))))
            (when payload
              (wf-manager-route-record-make
               :id id :class class :position position :schema schema
               :from from :to to :about about
               :reply-to (and (integerp reply-to) reply-to)
               :at at :payload payload))))))))

(defun wf-manager-decode-invalidation (value)
  "Return the `wf-manager-invalidation' of the JSON VALUE.
VALUE is an object of exactly `version' 1, `resource' and `revision'.
Any other VALUE signals `wf-manager-invalid-response'."
  (wf-manager--decided "invalidation" (wf-manager--parse-invalidation value)))

(defun wf-manager-encode-invalidation (invalidation)
  "Return the JSON value of INVALIDATION, a `wf-manager-invalidation'."
  (wf-manager-json-object
   "version" (wf-manager-json-integer 1)
   "resource" (wf-manager-invalidation-resource invalidation)
   "revision" (wf-manager-invalidation-revision invalidation)))

(defun wf-manager-decode-invalidation-event (value)
  "Return the `wf-manager-invalidation-event' of the JSON VALUE.
VALUE is an object of exactly `id', `event' and `data'.  Any other VALUE
signals `wf-manager-invalid-response'."
  (wf-manager--decided "invalidation event"
                       (wf-manager--parse-invalidation-event value)))

(defun wf-manager-encode-invalidation-event (event)
  "Return the JSON value of EVENT, a `wf-manager-invalidation-event'."
  (wf-manager-json-object
   "id" (wf-manager-invalidation-event-id event)
   "event" (wf-manager-invalidation-event-name event)
   "data" (wf-manager-encode-invalidation
           (wf-manager-invalidation-event-data event))))

(defun wf-manager-decode-event-batch (value)
  "Return the `wf-manager-event-batch' of the JSON VALUE.
VALUE is a version 1 polling batch of at most 256 events.  Any other
VALUE signals `wf-manager-invalid-response'."
  (wf-manager--decided "event batch" (wf-manager--parse-event-batch value)))

(defun wf-manager-encode-event-batch (batch)
  "Return the JSON value of BATCH, a `wf-manager-event-batch'."
  (wf-manager-json-object
   "version" (wf-manager-json-integer 1)
   "cursor" (wf-manager-event-batch-cursor batch)
   "oldestCursor" (wf-manager-event-batch-oldest-cursor batch)
   "events" (apply #'vector (mapcar #'wf-manager-encode-invalidation-event
                                    (wf-manager-event-batch-events batch)))
   "hasMore" (if (wf-manager-event-batch-has-more batch) t :false)))

(defun wf-manager-decode-route-record (value)
  "Return the `wf-manager-route-record' of the JSON VALUE.
VALUE has the route header members and exactly one of `body', `claim'
and `event'.  The record at position P has the identifier of position
P+1.  An inline body stays an exact JSON value.  Any other VALUE signals
`wf-manager-invalid-response'."
  (wf-manager--decided "route record" (wf-manager--parse-route-record value)))

(defun wf-manager-encode-route-record (record)
  "Return the JSON value of RECORD, a `wf-manager-route-record'."
  (let ((reply-to (wf-manager-route-record-reply-to record))
        (payload (wf-manager-route-record-payload record))
        (object (wf-manager-json-object
                 "id" (wf-manager-route-record-id record)
                 "class" (wf-manager-route-record-class record)
                 "position" (wf-manager-json-integer
                             (wf-manager-route-record-position record))
                 "schema" (wf-manager-route-record-schema record)
                 "from" (wf-manager-route-record-from record)
                 "to" (wf-manager-route-record-to record)
                 "about" (wf-manager-route-record-about record)
                 "at" (wf-manager-route-record-at record))))
    (puthash "replyTo" (if reply-to (wf-manager-json-integer reply-to) :null)
             object)
    (pcase payload
      (`(body ,value) (puthash "body" value object))
      (`(claim ,sha256 ,bytes)
       (puthash "claim" (wf-manager-json-object
                         "sha256" sha256 "bytes" (wf-manager-json-integer bytes))
                object))
      (`(event ,sequence)
       (puthash "event" (wf-manager-json-object
                         "sequence" (wf-manager-json-integer sequence))
                object)))
    object))

(defun wf-manager-problem-failure (status body)
  "Return the failure of a problem response with HTTP STATUS and BODY.
BODY is the decoded JSON body.  The failure is a list (CONDITION . DATA)
for `signal'.  A BODY whose `status' member equals the integer STATUS
and whose `code' member is a bounded identifier gives
\(wf-manager-refused STATUS CODE), so a 410 problem with the code
view-expired or cursor-expired gives a refusal 410 with its code.  Every
other BODY gives a `wf-manager-invalid-response' failure."
  (let ((stated (and (hash-table-p body) (gethash "status" body)))
        (code (and (hash-table-p body) (gethash "code" body))))
    (if (and (integerp status)
             (wf-manager-json-number-p stated)
             (equal (wf-manager--decimal stated)
                    (wf-manager--decimal (wf-manager-json-integer status)))
             (wf-manager-valid-id-p code))
        (list 'wf-manager-refused status code)
      (list 'wf-manager-invalid-response "problem"
            (format "the problem body does not state the status %s and a code"
                    status)))))

;;;; Resource decoders

;; The decoders below follow the draft and preparation decoders of
;; `ext-pi/src/manager/resources.ts' in agent-cat.  Each parser returns a
;; record or throws to the tag `wf-manager--refusal', and each public
;; decoder turns that throw into `wf-manager-invalid-response'.

(defconst wf-manager-input-sources '("prompt" "command-tail" "stdin")
  "The sources of a declared workflow input.")

(defconst wf-manager-input-error-codes
  '("unknown-input" "invalid-input" "capture-unavailable" "size-limit")
  "The codes of an input error.")

(defconst wf-manager-request-phases
  '("draft" "queued" "preparing" "review" "start-pending" "associated"
    "withdrawn" "refused")
  "The phases of a request.")

(defconst wf-manager-admission-states
  '("not-queued" "waiting" "reserved" "released" "refused")
  "The admission states of a request.")

(defconst wf-manager-admission-reasons
  '("missing-inputs" "profile-busy" "workspace-busy" "target-busy"
    "store-busy" "capacity" "quarantined" "storage-quota")
  "The reasons that block the admission of a request.")

(defconst wf-manager-lineage-operations '("restart" "resume" "fork")
  "The lineage operations of a request or a review.")

(defconst wf-manager-preparation-states '("live" "consumed" "invalidated")
  "The states of a preparation.")

(defconst wf-manager-preparation-reasons
  '("expired" "input-changed" "profile-changed" "worker-lost" "discarded"
    "authority-changed" "consumed")
  "The reasons of a preparation that is no longer live.")

(defconst wf-manager--draft-fields
  '("version" "id" "revision" "workflowId" "descriptorRevision" "profileId"
    "profileRevision" "phase" "readiness" "admission" "preparationId" "runId"
    "parentRunId" "lineage" "links")
  "The members of a request resource.")

(defconst wf-manager--preparation-fields
  '("version" "id" "revision" "requestId" "requestRevision" "profileId"
    "profileRevision" "descriptorRevision" "state" "expiresAt" "reviewDigest"
    "processGeneration" "review" "reason")
  "The members of a preparation.")

(defconst wf-manager--review-fields
  '("programHash" "personAnswering" "policy" "workflowId" "profileId"
    "workspaceLabel" "targetLabel" "inputs" "plan" "runFacts" "pins"
    "warnings" "resultCode" "lineage")
  "The members of a review.  Only `lineage' is optional.")

(defconst wf-manager--policy-fields
  '("kind" "default" "coverage" "routes" "pollMs" "timeoutMs" "verbose"
    "realizations" "routingVersion" "persona" "personaSource" "policyDigest"
    "personAnswers")
  "The members that a routed policy can have.")

(defconst wf-manager--realization-fields
  '("profile" "axis" "rung" "backend" "router" "provider" "model" "thinking"
    "maxOutput" "executionFingerprint" "modelAlias" "engine")
  "The members that a realization of a routed policy can have.")

(defconst wf-manager--thinking-levels
  '("off" "minimal" "low" "medium" "high" "xhigh" "max")
  "The thinking levels of a realization.")

(defconst wf-manager--persona-sources
  '("command-line" "environment" "project" "user-default")
  "The sources of the persona of a routed policy.")

(defconst wf-manager--semantic-primitives
  '("null" "boolean" "integer" "number" "string" "object")
  "The primitive types of a semantic schema.")

(defconst wf-manager--primitive-codes '("text" "verdict" "flag" "receipt")
  "The primitive observation codes.")

(defconst wf-manager--review-depth '(2 . 64)
  "The depth rule of the semantic schema of a review.
The car is the depth step of each nesting level, and the cdr is the
deepest depth accepted.")

(defconst wf-manager--int32-max 2147483647
  "The largest signed 32-bit integer.")

(defconst wf-manager--int64-min (- (expt 2 63))
  "The smallest signed 64-bit integer.")

(defconst wf-manager--int64-max (1- (expt 2 63))
  "The largest signed 64-bit integer.")

(cl-defstruct (wf-manager-input-declaration
               (:constructor wf-manager-input-declaration-make)
               (:copier nil))
  "One declared workflow input, a required string input without description.
NAME is the input name.  SOURCE is one of `wf-manager-input-sources'."
  (name nil :read-only t)
  (source nil :read-only t))

(cl-defstruct (wf-manager-supplied-input
               (:constructor wf-manager-supplied-input-make)
               (:copier nil))
  "One supplied input.
NAME is the input name.  SOURCE is \"literal\" or \"capture\".  A literal
input has the text VALUE.  A capture input has the opaque selector
CAPTURE-ID."
  (name nil :read-only t)
  (source nil :read-only t)
  (value nil :read-only t)
  (capture-id nil :read-only t))

(cl-defstruct (wf-manager-input-error
               (:constructor wf-manager-input-error-make)
               (:copier nil))
  "One input error.
NAME is the input name.  CODE is one of `wf-manager-input-error-codes'."
  (name nil :read-only t)
  (code nil :read-only t))

(cl-defstruct (wf-manager-readiness
               (:constructor wf-manager-readiness-make)
               (:copier nil))
  "The readiness of a request.
DECLARATIONS is a list of `wf-manager-input-declaration', SUPPLIED a list
of `wf-manager-supplied-input', MISSING the list of the names of the
declarations without a supplied input, in declaration order, and ERRORS a
list of `wf-manager-input-error'."
  (declarations nil :read-only t)
  (supplied nil :read-only t)
  (missing nil :read-only t)
  (errors nil :read-only t))

(cl-defstruct (wf-manager-draft
               (:constructor wf-manager-draft-make)
               (:copier nil))
  "One versioned request resource.
ID, REVISION, WORKFLOW-ID, DESCRIPTOR-REVISION, PROFILE-ID and
PROFILE-REVISION are bounded identifiers.  PHASE is one of
`wf-manager-request-phases'.  READINESS is a `wf-manager-readiness'.
ADMISSION is one of `wf-manager-admission-states', POSITION the queue
position from 1 to 100 or nil, and REASONS the list of the reasons that
block the admission.  PREPARATION-ID, RUN-ID and PARENT-RUN-ID are bounded
identifiers or nil, and LINEAGE is one of `wf-manager-lineage-operations'
or nil."
  (id nil :read-only t)
  (revision nil :read-only t)
  (workflow-id nil :read-only t)
  (descriptor-revision nil :read-only t)
  (profile-id nil :read-only t)
  (profile-revision nil :read-only t)
  (phase nil :read-only t)
  (readiness nil :read-only t)
  (admission nil :read-only t)
  (position nil :read-only t)
  (reasons nil :read-only t)
  (preparation-id nil :read-only t)
  (run-id nil :read-only t)
  (parent-run-id nil :read-only t)
  (lineage nil :read-only t))

(cl-defstruct (wf-manager-review-input
               (:constructor wf-manager-review-input-make)
               (:copier nil))
  "One input of a review.
NAME is the input name, SOURCE is \"literal\" or \"capture\", BYTES is the
exact byte count and SHA256 the lowercase SHA-256 digest of the bytes."
  (name nil :read-only t)
  (source nil :read-only t)
  (bytes nil :read-only t)
  (sha256 nil :read-only t))

(cl-defstruct (wf-manager-review-edit
               (:constructor wf-manager-review-edit-make)
               (:copier nil))
  "One answer edit of a fork.
OPERATION is \"drop\" or \"replace\".  OCCURRENCE-ID is an unsigned 64-bit
integer.  A replacement has SHA256, the digest of its answer, and never
the answer itself.  A drop has a nil SHA256."
  (operation nil :read-only t)
  (occurrence-id nil :read-only t)
  (sha256 nil :read-only t))

(cl-defstruct (wf-manager-review-lineage
               (:constructor wf-manager-review-lineage-make)
               (:copier nil))
  "The lineage of a restart, resume or fork preparation.
PARENT-RUN-ID is a bounded identifier, OPERATION one of
`wf-manager-lineage-operations', and EDITS a list of
`wf-manager-review-edit'.  Only a fork has edits."
  (parent-run-id nil :read-only t)
  (operation nil :read-only t)
  (edits nil :read-only t))

(cl-defstruct (wf-manager-review
               (:constructor wf-manager-review-make)
               (:copier nil))
  "The bounded consent facts of one preparation.
PROGRAM-HASH is a SHA-256 digest.  PERSON-ANSWERING is \"engine\" or
\"local-control\".  POLICY and RESULT-CODE are their validated exact JSON
values.  WORKFLOW-ID and PROFILE-ID are bounded identifiers.
WORKSPACE-LABEL, TARGET-LABEL and PLAN are text.  INPUTS is a list of
`wf-manager-review-input'.  RUN-FACTS, PINS and WARNINGS are lists of
text.  LINEAGE is a `wf-manager-review-lineage', or nil for a root
review."
  (program-hash nil :read-only t)
  (person-answering nil :read-only t)
  (policy nil :read-only t)
  (workflow-id nil :read-only t)
  (profile-id nil :read-only t)
  (workspace-label nil :read-only t)
  (target-label nil :read-only t)
  (inputs nil :read-only t)
  (plan nil :read-only t)
  (run-facts nil :read-only t)
  (pins nil :read-only t)
  (warnings nil :read-only t)
  (result-code nil :read-only t)
  (lineage nil :read-only t))

(cl-defstruct (wf-manager-preparation
               (:constructor wf-manager-preparation-make)
               (:copier nil))
  "One versioned preparation.  It is not a live worker and not an approval.
ID, REVISION, REQUEST-ID, REQUEST-REVISION, PROFILE-ID, PROFILE-REVISION,
DESCRIPTOR-REVISION and PROCESS-GENERATION are bounded identifiers.
STATE is one of `wf-manager-preparation-states'.  EXPIRES-AT is an RFC
3339 time.  REVIEW-DIGEST is the SHA-256 digest of REVIEW, a
`wf-manager-review'.  REASON is one of `wf-manager-preparation-reasons'
or nil."
  (id nil :read-only t)
  (revision nil :read-only t)
  (request-id nil :read-only t)
  (request-revision nil :read-only t)
  (profile-id nil :read-only t)
  (profile-revision nil :read-only t)
  (descriptor-revision nil :read-only t)
  (state nil :read-only t)
  (expires-at nil :read-only t)
  (review-digest nil :read-only t)
  (process-generation nil :read-only t)
  (review nil :read-only t)
  (reason nil :read-only t))

(cl-defstruct (wf-manager-overview-member
               (:constructor wf-manager-overview-member-make)
               (:copier nil))
  "One member of the overview page set.
KIND is \"request\", \"preparation\", \"run\" or \"decision\".  VALUE
is a `wf-manager-draft', a `wf-manager-preparation', a `wf-manager-run'
or a `wf-manager-decision'."
  (kind nil :read-only t)
  (value nil :read-only t))

(defconst wf-manager-operations
  '("create" "capture" "set-input" "remove-input" "enqueue" "withdraw" "approve"
    "discard" "cancel" "steer" "retry" "choose-recovery" "redirect" "answer"
    "export" "restart" "resume" "fork")
  "The command operations.")

(defconst wf-manager-command-states
  '("accepted" "dispatch-attempted" "acknowledged" "effect-observed" "refused"
    "unresolved")
  "The states of a command receipt.")

(defconst wf-manager-receipt-refusals
  '("state-conflict" "stale-revision" "unsupported-operation"
    "ownership-unavailable" "supervision-unavailable" "invalid-answer"
    "invalid-lineage-edit" "export-conflict" "storage-unavailable")
  "The refusal codes of a refused command receipt.")

(defconst wf-manager-effect-kinds
  '("started" "cancelled" "steered" "retried" "recovery-chosen" "redirected"
    "answer-accepted" "input-changed" "enqueued" "withdrawn" "discarded"
    "exported" "lineage-created")
  "The kinds of the observed effect of a command.")

(defconst wf-manager--acknowledgement-states
  '("accepted" "queued" "delivered" "rejected-stale" "unsupported" "failed")
  "The states of a runtime acknowledgement.")

(defconst wf-manager--acknowledged-commands
  '("cancel" "steer" "retry" "choose-recovery" "redirect" "answer")
  "The commands that a runtime acknowledgement names.")

(defconst wf-manager--receipt-fields
  '("version" "id" "profileId" "operation" "requiredScopes" "resource" "state"
    "acceptedAt" "dispatchAttemptedAt" "acknowledgement" "effect" "refusal"
    "links")
  "The members of a command receipt.")

(defconst wf-manager--word32-max 4294967295
  "The largest unsigned 32-bit integer.")

(defconst wf-manager-decision-states
  '("pending" "submitting" "resolved" "invalidated")
  "The states of a decision.")

(defconst wf-manager--decision-fields
  '("version" "id" "revision" "runId" "profileId" "generation" "address" "state"
    "position" "observedSequence" "queue" "kind")
  "The members that every decision has.")

(defconst wf-manager--decision-depth '(1 . 63)
  "The depth rule of the semantic schema of a decision.
The rule has the form of `wf-manager--review-depth'.")

(defconst wf-manager--editor-types
  '("null" "boolean" "integer" "number" "string" "array" "object")
  "The types of an editor schema.")

(defconst wf-manager-person-answer-bytes 1048576
  "The largest JSON answer text, in UTF-8 bytes.")

(defun wf-manager-required-scopes (operation)
  "Return the profile scopes that OPERATION requires, in their fixed order."
  (pcase operation
    ((or "create" "capture" "set-input" "remove-input" "enqueue" "withdraw")
     '("submit"))
    ((or "approve" "discard") '("submit" "control"))
    ((or "cancel" "steer" "retry" "choose-recovery" "redirect" "answer")
     '("control"))
    ("export" '("observe" "export"))
    ((or "restart" "resume" "fork") '("observe" "submit"))))

(cl-defstruct (wf-manager-command-receipt
               (:constructor wf-manager-command-receipt-make)
               (:copier nil))
  "One command receipt.
ID and PROFILE-ID are bounded identifiers.  OPERATION is one of
`wf-manager-operations', and RESOURCE is a resource path below /v1/.
STATE is one of `wf-manager-command-states'.  ACCEPTED-AT is an RFC 3339
time, and DISPATCH-ATTEMPTED-AT is one or nil.  ACKNOWLEDGEMENT and
EFFECT are their validated exact JSON values, or nil.  REFUSAL is one of
`wf-manager-receipt-refusals', or nil.  Accepted intent is not an
attempted or acknowledged delivery."
  (id nil :read-only t)
  (profile-id nil :read-only t)
  (operation nil :read-only t)
  (resource nil :read-only t)
  (state nil :read-only t)
  (accepted-at nil :read-only t)
  (dispatch-attempted-at nil :read-only t)
  (acknowledgement nil :read-only t)
  (effect nil :read-only t)
  (refusal nil :read-only t))

(cl-defstruct (wf-manager-recovery-option
               (:constructor wf-manager-recovery-option-make)
               (:copier nil))
  "One recovery choice.
CHOICE is \"retry\", \"failover\" or \"abandon\".  TARGET is the target
text of a failover, or nil.  Only a failover names a target."
  (choice nil :read-only t)
  (target nil :read-only t))

(cl-defstruct (wf-manager-editor-schema
               (:constructor wf-manager-editor-schema-make)
               (:copier nil))
  "The editor schema of a question.
TYPE is one of `wf-manager--editor-types'.  An array schema has the item
schema ITEMS.  An object schema has PROPERTIES, an alist of each property
name and its schema, in the order of the UTF-16 code units of the names.
Each property of an object schema is required, and an object has no
other property."
  (type nil :read-only t)
  (items nil :read-only t)
  (properties nil :read-only t))

(cl-defstruct (wf-manager-question
               (:constructor wf-manager-question-make)
               (:copier nil))
  "The content of a question decision.
CODE is the exact JSON value of its observation code.  EDITOR is a
`wf-manager-editor-schema', or nil when the manager gives none.  PROMPT
is the prompt text."
  (code nil :read-only t)
  (editor nil :read-only t)
  (prompt nil :read-only t))

(cl-defstruct (wf-manager-recovery
               (:constructor wf-manager-recovery-make)
               (:copier nil))
  "The content of a recovery decision.
GAP and MESSAGE are text.  CHOICES is a list of
`wf-manager-recovery-option'."
  (gap nil :read-only t)
  (message nil :read-only t)
  (choices nil :read-only t))

(cl-defstruct (wf-manager-decision
               (:constructor wf-manager-decision-make)
               (:copier nil))
  "One decision.
ID, REVISION, RUN-ID, PROFILE-ID and GENERATION are bounded identifiers.
OCCURRENCE-ID and OBSERVED-SEQUENCE are unsigned 64-bit integers.  STATE
is one of `wf-manager-decision-states'.  POSITION is the queue position,
from 0 to 2047.  CONTENT is a `wf-manager-question' or a
`wf-manager-recovery'.  VALUE is the exact JSON value that was decoded.
A decision grants no control authority."
  (id nil :read-only t)
  (revision nil :read-only t)
  (run-id nil :read-only t)
  (profile-id nil :read-only t)
  (generation nil :read-only t)
  (occurrence-id nil :read-only t)
  (state nil :read-only t)
  (position nil :read-only t)
  (observed-sequence nil :read-only t)
  (content nil :read-only t)
  (value nil :read-only t))

(defconst wf-manager-supervision-states
  '("owned" "cleanup-pending" "lost" "observer")
  "The supervision states of a run.")

(defconst wf-manager-offer-operations
  '("steer" "retry" "choose-recovery" "redirect" "answer")
  "The operations of a control offer.
Cancellation is not an offer.  The controls of a run state it apart.")

(defconst wf-manager-steer-timings '("interrupt-now" "next-boundary")
  "The timings of a steer offer.")

(defconst wf-manager-run-statuses
  '("starting" "running" "cancelling" "succeeded" "failed" "cancelled" "orphaned")
  "The runtime statuses of a run.")

(defconst wf-manager-unreadable-categories
  '("manifest-unavailable" "malformed-manifest" "unsupported-manifest")
  "The public categories of a catalogue entry whose manifest is unreadable.")

(defconst wf-manager-run-integrities '("valid" "corrupt" "incomplete" "unknown")
  "The integrity states of the journal of a run.")

(defconst wf-manager-run-limitations
  '("legacy" "foreign-owner" "corrupt-journal" "incompatible-invocation"
    "quarantined" "lost-supervision")
  "The limitations of a run.")

(defconst wf-manager-unavailable-reasons
  '("missing" "corrupt" "unsupported-version" "size-limit" "ownership-unavailable")
  "The reasons for an unavailable verification.")

(defconst wf-manager--run-fields
  '("version" "id" "revision" "profileId" "workflowId" "requestId" "parentRunId"
    "lineage" "manifest" "runtime" "supervision" "integrity" "verification"
    "limitations" "links")
  "The members of a run whose manifest the manager read.")

(cl-defstruct (wf-manager-control-offer
               (:constructor wf-manager-control-offer-make)
               (:copier nil))
  "One control offer of a run.
OPERATION is one of `wf-manager-offer-operations'.  OCCURRENCE-ID is an
unsigned 64-bit integer.  ATTEMPT-ID is an unsigned 32-bit integer for
a steer offer, and nil for every other offer.  GENERATION is a bounded
identifier, or nil.  TIMINGS is a list of distinct
`wf-manager-steer-timings'.  CHOICES is a list of
`wf-manager-recovery-option'.  TARGETS is a list of target texts."
  (operation nil :read-only t)
  (occurrence-id nil :read-only t)
  (attempt-id nil :read-only t)
  (generation nil :read-only t)
  (timings nil :read-only t)
  (choices nil :read-only t)
  (targets nil :read-only t))

(cl-defstruct (wf-manager-control
               (:constructor wf-manager-control-make)
               (:copier nil))
  "The controls of one run.
RUN-ID and REVISION are bounded identifiers.  SUPERVISION is one of
`wf-manager-supervision-states'.  CANCEL-ALLOWED is t or nil.
DECISION-HEAD-ID is the bounded identifier of the first pending
decision, or nil.  OFFERS is a list of `wf-manager-control-offer'.
VALUE is the exact JSON value that was decoded.  The controls are
display data and grant no control authority."
  (run-id nil :read-only t)
  (revision nil :read-only t)
  (supervision nil :read-only t)
  (cancel-allowed nil :read-only t)
  (decision-head-id nil :read-only t)
  (offers nil :read-only t)
  (value nil :read-only t))

(cl-defstruct (wf-manager-run-runtime
               (:constructor wf-manager-run-runtime-make)
               (:copier nil))
  "The runtime summary of a run.
STATUS is one of `wf-manager-run-statuses'.  LAST-SEQUENCE is an
unsigned 64-bit integer.  PROTOCOL-VERSION is 1, 2 or 3."
  (status nil :read-only t)
  (last-sequence nil :read-only t)
  (protocol-version nil :read-only t))

(cl-defstruct (wf-manager-verification
               (:constructor wf-manager-verification-make)
               (:copier nil))
  "The verification of the result of a run.
STATE is \"absent\", \"referenced\", \"verified\" or \"unavailable\".
ARTIFACT-ID is a bounded identifier for a referenced or verified result,
a bounded identifier or nil for an unavailable result, and nil for an
absent result.  REASON is one of `wf-manager-unavailable-reasons' for an
unavailable result, and nil otherwise."
  (state nil :read-only t)
  (artifact-id nil :read-only t)
  (reason nil :read-only t))

(cl-defstruct (wf-manager-known-run
               (:constructor wf-manager-known-run-make)
               (:copier nil))
  "The content of a run whose manifest the manager read.
WORKFLOW-ID is a bounded identifier.  REQUEST-ID and PARENT-RUN-ID are
bounded identifiers or nil.  LINEAGE is one of
`wf-manager-lineage-operations', or nil.  MANIFEST-VERSION is 2 or 3,
or nil for a legacy manifest.  RUNTIME is a `wf-manager-run-runtime', or
nil without validated native evidence.  SUPERVISION is one of
`wf-manager-supervision-states', INTEGRITY is one of
`wf-manager-run-integrities', and VERIFICATION is a
`wf-manager-verification'.  These are separate dimensions: no one of
them gives another.  LIMITATIONS is a list of distinct
`wf-manager-run-limitations'."
  (workflow-id nil :read-only t)
  (request-id nil :read-only t)
  (parent-run-id nil :read-only t)
  (lineage nil :read-only t)
  (manifest-version nil :read-only t)
  (runtime nil :read-only t)
  (supervision nil :read-only t)
  (integrity nil :read-only t)
  (verification nil :read-only t)
  (limitations nil :read-only t))

(cl-defstruct (wf-manager-unreadable-run
               (:constructor wf-manager-unreadable-run-make)
               (:copier nil))
  "The content of a catalogue entry whose manifest the manager cannot read.
CATEGORY is one of `wf-manager-unreadable-categories'."
  (category nil :read-only t))

(cl-defstruct (wf-manager-run
               (:constructor wf-manager-run-make)
               (:copier nil))
  "One item of the run collection, or the run of one overview member.
ID, REVISION and PROFILE-ID are bounded identifiers.  CONTENT is a
`wf-manager-known-run' or a `wf-manager-unreadable-run'.  A run is
display data and grants no supervision, control or signalling
authority."
  (id nil :read-only t)
  (revision nil :read-only t)
  (profile-id nil :read-only t)
  (content nil :read-only t))

;;;;; Field readers

(defun wf-manager--refuse ()
  "Refuse the value of the current parser."
  (throw 'wf-manager--refusal nil))

(defun wf-manager--ensure (value)
  "Return VALUE when it is non-nil, and refuse it otherwise."
  (or value (wf-manager--refuse)))

(defun wf-manager--member (object name)
  "In OBJECT, return the member NAME, or nil when OBJECT is not an object."
  (and (hash-table-p object) (gethash name object)))

(defun wf-manager--exact (value names)
  "Return VALUE when it is an object whose member names are NAMES.
Refuse any other VALUE."
  (wf-manager--ensure (wf-manager--closed value names)))

(defun wf-manager--within-p (value names)
  "Return VALUE when it is an object whose member names are all in NAMES."
  (and (hash-table-p value)
       (catch 'outside
         (maphash (lambda (name _member)
                    (unless (member name names) (throw 'outside nil)))
                  value)
         value)))

(defun wf-manager--within (value names)
  "Return VALUE when its member names are all in NAMES, and refuse otherwise."
  (wf-manager--ensure (wf-manager--within-p value names)))

(defun wf-manager--bounded-text-p (value lower upper)
  "Return non-nil when VALUE is text of LOWER to UPPER characters."
  (and (stringp value) (<= lower (length value) upper)))

(defun wf-manager--bounded-text (value lower upper)
  "Return VALUE when it is text of LOWER to UPPER characters.
Refuse any other VALUE."
  (if (wf-manager--bounded-text-p value lower upper) value (wf-manager--refuse)))

(defun wf-manager--string (value)
  "Return VALUE when it is a string, and refuse it otherwise."
  (if (stringp value) value (wf-manager--refuse)))

(defun wf-manager--identifier (value)
  "Return VALUE when it is a bounded identifier, and refuse it otherwise."
  (if (wf-manager-valid-id-p value) value (wf-manager--refuse)))

(defun wf-manager--choice-p (value choices)
  "Return VALUE when it is one of the strings CHOICES, otherwise nil."
  (and (stringp value) (car (member value choices))))

(defun wf-manager--choice (value choices)
  "Return VALUE when it is one of the strings CHOICES, and refuse otherwise."
  (wf-manager--ensure (wf-manager--choice-p value choices)))

(defun wf-manager--nullable (value parse)
  "Return nil for the JSON null VALUE, and the result of PARSE otherwise.
An absent VALUE refuses."
  (cond ((null value) (wf-manager--refuse))
        ((eq value :null) nil)
        (t (funcall parse value))))

(defun wf-manager--items (value parse &optional limit)
  "For the array VALUE, return the list of PARSE applied to each item.
An array of more than LIMIT items, or a VALUE that is not an array,
refuses."
  (if (and (vectorp value) (or (null limit) (<= (length value) limit)))
      (mapcar parse value)
    (wf-manager--refuse)))

(defun wf-manager--integer (value minimum maximum)
  "Return the integer of the JSON number VALUE from MINIMUM to MAXIMUM.
Refuse any other VALUE."
  (wf-manager--ensure (wf-manager--bounded-integer value minimum maximum)))

(defun wf-manager--unique-p (strings)
  "Return non-nil when no string occurs in STRINGS more than one time."
  (= (length (delete-dups (copy-sequence strings))) (length strings)))

(defun wf-manager--digest-p (value)
  "Return non-nil when VALUE is a lowercase hexadecimal SHA-256 digest."
  (and (stringp value) (wf-manager--matches-p "[0-9a-f]\\{64\\}" value)))

(defun wf-manager--digest (value)
  "Return VALUE when it is a SHA-256 digest, and refuse it otherwise."
  (if (wf-manager--digest-p value) value (wf-manager--refuse)))

(defun wf-manager--decimal-value (value digits maximum)
  "Return the integer of VALUE, a canonical unsigned decimal text, or nil.
VALUE has 1 to DIGITS digits and no leading zero.  When MAXIMUM is
non-nil, the integer is at most MAXIMUM."
  (and (stringp value)
       (<= 1 (length value) digits)
       (wf-manager--matches-p "0\\|[1-9][0-9]*" value)
       (let ((number (string-to-number value)))
         (and (or (null maximum) (<= number maximum)) number))))

(defun wf-manager--word64-text (value)
  "Return the integer of VALUE, a canonical unsigned 64-bit decimal text.
Refuse any other VALUE."
  (wf-manager--ensure (wf-manager--decimal-value value 20 wf-manager--word64-max)))

(defun wf-manager--leap-year-p (year)
  "Return non-nil when YEAR is a Gregorian leap year."
  (and (= (% year 4) 0) (or (/= (% year 100) 0) (= (% year 400) 0))))

(defun wf-manager-valid-timestamp-p (value)
  "Return non-nil when VALUE is an RFC 3339 time that the protocol accepts.
VALUE has 20 to 64 characters: a valid Gregorian date with a year other
than 0, a time below 24:00:00 with optional fraction digits, and Z or an
offset below 24:00.  The letters T and Z can be lowercase."
  (and (wf-manager--bounded-text-p value 20 64)
       (let ((case-fold-search nil))
         (string-match
          (concat "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)"
                  "[Tt]\\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\)"
                  "\\(?:\\.[0-9]+\\)?"
                  "\\(?:[Zz]\\|[-+]\\([0-9]\\{2\\}\\):\\([0-9]\\{2\\}\\)\\)\\'")
          value))
       (let* ((part (lambda (group)
                      (string-to-number (or (match-string group value) "0"))))
              (year (funcall part 1))
              (month (funcall part 2))
              (day (funcall part 3)))
         (and (/= year 0)
              (<= 1 month 12)
              (<= 1 day (if (and (= month 2) (not (wf-manager--leap-year-p year)))
                            28
                          (aref [31 29 31 30 31 30 31 31 30 31 30 31] (1- month))))
              (< (funcall part 4) 24)
              (< (funcall part 5) 60)
              (< (funcall part 6) 60)
              (< (funcall part 7) 24)
              (< (funcall part 8) 60)))))

;;;;; Requests and readiness

(defun wf-manager--input-name-p (value)
  "Return non-nil when VALUE is 1 to 1024 characters of text without NUL."
  (and (wf-manager--bounded-text-p value 1 1024)
       (not (string-search "\0" value))))

(defun wf-manager--input-name (value)
  "Return VALUE when it is an input name, and refuse it otherwise."
  (if (wf-manager--input-name-p value) value (wf-manager--refuse)))

(defun wf-manager--string-schema ()
  "Return the JSON schema of a string input, {\"type\":\"string\"}."
  (wf-manager-json-object "type" "string"))

(defun wf-manager--parse-input-declaration (value)
  "Return the `wf-manager-input-declaration' of the JSON VALUE, or refuse."
  (let ((fields (wf-manager--exact
                 value '("name" "source" "description" "required" "schema"))))
    (unless (and (eq (gethash "description" fields) :null)
                 (eq (gethash "required" fields) t)
                 (wf-manager-json-equal (gethash "schema" fields)
                                        (wf-manager--string-schema)))
      (wf-manager--refuse))
    (wf-manager-input-declaration-make
     :name (wf-manager--input-name (gethash "name" fields))
     :source (wf-manager--choice (gethash "source" fields)
                                 wf-manager-input-sources))))

(defun wf-manager--parse-supplied-input (value)
  "Return the `wf-manager-supplied-input' of the JSON VALUE, or refuse."
  (let ((name (wf-manager--input-name (wf-manager--member value "name")))
        (source (wf-manager--member value "source")))
    (pcase source
      ("literal"
       (let ((fields (wf-manager--exact value '("name" "source" "value"))))
         (wf-manager-supplied-input-make
          :name name :source source
          :value (wf-manager--bounded-text (gethash "value" fields) 0 2097152))))
      ("capture"
       (let ((fields (wf-manager--exact value '("name" "source" "captureId"))))
         (wf-manager-supplied-input-make
          :name name :source source
          :capture-id (wf-manager--identifier (gethash "captureId" fields)))))
      (_ (wf-manager--refuse)))))

(defun wf-manager--parse-input-error (value)
  "Return the `wf-manager-input-error' of the JSON VALUE, or refuse."
  (let ((fields (wf-manager--exact value '("name" "code"))))
    (wf-manager-input-error-make
     :name (wf-manager--input-name (gethash "name" fields))
     :code (wf-manager--choice (gethash "code" fields)
                               wf-manager-input-error-codes))))

(defun wf-manager--parse-readiness (value)
  "Return the `wf-manager-readiness' of the JSON VALUE, or refuse.
Each list has at most 256 items.  The declared names are unique, each
supplied input names one declaration one time, and MISSING names each
declaration without a supplied input, in declaration order."
  (let* ((fields (wf-manager--exact
                  value '("declarations" "supplied" "missing" "errors")))
         (declarations (wf-manager--items (gethash "declarations" fields)
                                          #'wf-manager--parse-input-declaration))
         (supplied (wf-manager--items (gethash "supplied" fields)
                                      #'wf-manager--parse-supplied-input))
         (missing (wf-manager--items (gethash "missing" fields)
                                     #'wf-manager--string))
         (errors (wf-manager--items (gethash "errors" fields)
                                    #'wf-manager--parse-input-error))
         (names (mapcar #'wf-manager-input-declaration-name declarations))
         (present (mapcar #'wf-manager-supplied-input-name supplied)))
    (unless (and (cl-every (lambda (items) (<= (length items) 256))
                           (list names present missing errors))
                 (wf-manager--unique-p names)
                 (wf-manager--unique-p present)
                 (cl-every (lambda (name) (member name names)) present)
                 (equal missing (cl-remove-if (lambda (name) (member name present))
                                              names)))
      (wf-manager--refuse))
    (wf-manager-readiness-make :declarations declarations :supplied supplied
                               :missing missing :errors errors)))

(defun wf-manager--parse-draft (value)
  "Return the `wf-manager-draft' of the JSON VALUE, or refuse."
  (let* ((fields (wf-manager--exact value wf-manager--draft-fields))
         (admission (wf-manager--exact (gethash "admission" fields)
                                       '("state" "position" "reasons")))
         (identity (lambda (name)
                     (wf-manager--identifier (gethash name fields))))
         (optional (lambda (name)
                     (wf-manager--nullable (gethash name fields)
                                           #'wf-manager--identifier)))
         (id (funcall identity "id"))
         (reasons (wf-manager--items
                   (gethash "reasons" admission)
                   (lambda (reason)
                     (wf-manager--choice reason wf-manager-admission-reasons))
                   8)))
    (unless (and (wf-manager--version-one-p fields)
                 (wf-manager--unique-p reasons)
                 (wf-manager-json-equal (gethash "links" fields)
                                        (wf-manager-json-object
                                         "self" (concat "/v1/requests/" id))))
      (wf-manager--refuse))
    (wf-manager-draft-make
     :id id
     :revision (funcall identity "revision")
     :workflow-id (funcall identity "workflowId")
     :descriptor-revision (funcall identity "descriptorRevision")
     :profile-id (funcall identity "profileId")
     :profile-revision (funcall identity "profileRevision")
     :phase (wf-manager--choice (gethash "phase" fields)
                                wf-manager-request-phases)
     :readiness (wf-manager--parse-readiness (gethash "readiness" fields))
     :admission (wf-manager--choice (gethash "state" admission)
                                    wf-manager-admission-states)
     :position (wf-manager--nullable
                (gethash "position" admission)
                (lambda (number) (wf-manager--integer number 1 100)))
     :reasons reasons
     :preparation-id (funcall optional "preparationId")
     :run-id (funcall optional "runId")
     :parent-run-id (funcall optional "parentRunId")
     :lineage (wf-manager--nullable
               (gethash "lineage" fields)
               (lambda (operation)
                 (wf-manager--choice operation wf-manager-lineage-operations))))))

;;;;; Preparations and reviews

(defun wf-manager--semantic-schema-p (value depth rule)
  "Return non-nil when VALUE is a semantic schema at DEPTH under RULE.
A semantic schema is a primitive name, {\"array\":{\"items\":S}} with a
semantic schema S, or a semantic object.  RULE is a cons of the depth
step of each level and the deepest depth accepted."
  (cond
   ((> depth (cdr rule)) nil)
   ((stringp value) (wf-manager--choice-p value wf-manager--semantic-primitives))
   ((wf-manager--member value "array")
    (let* ((array (wf-manager--closed
                   (wf-manager--member (wf-manager--closed value '("array"))
                                       "array")
                   '("items")))
           (items (wf-manager--member array "items")))
      (and items (wf-manager--semantic-schema-p items (+ depth (car rule)) rule))))
   (t (wf-manager--semantic-object-p value depth nil rule))))

(defun wf-manager--semantic-object-p (value depth seen rule)
  "Return non-nil when VALUE is a semantic object at DEPTH.
A semantic object is \"object\", or a chain of properties
{\"property\":{\"name\":N,\"schema\":S,\"rest\":R}} whose names are
unique and not in SEEN, with a semantic schema S and a semantic object R.
RULE is the depth rule of `wf-manager--semantic-schema-p'."
  (cond
   ((> depth (cdr rule)) nil)
   ((equal value "object") t)
   (t
    (let* ((property (wf-manager--closed
                      (wf-manager--member (wf-manager--closed value '("property"))
                                          "property")
                      '("name" "schema" "rest")))
           (name (wf-manager--member property "name")))
      (and property
           (wf-manager--bounded-text-p name 0 1024)
           (not (member name seen))
           (wf-manager--semantic-schema-p (gethash "schema" property)
                                          (+ depth (car rule)) rule)
           (wf-manager--semantic-object-p (gethash "rest" property)
                                          (+ depth (car rule))
                                          (cons name seen) rule))))))

(defun wf-manager--observation-code-p (value rule)
  "Return non-nil when VALUE is an observation code under the depth RULE.
An observation code is one of `wf-manager--primitive-codes', or
{\"json\":{\"schema\":S}} with a semantic schema S."
  (if (stringp value)
      (wf-manager--choice-p value wf-manager--primitive-codes)
    (let ((schema (wf-manager--member
                   (wf-manager--closed
                    (wf-manager--member (wf-manager--closed value '("json")) "json")
                    '("schema"))
                   "schema")))
      (and schema (wf-manager--semantic-schema-p schema 0 rule)))))

(defun wf-manager--policy-label-p (value)
  "Return non-nil when VALUE is a policy label of at most 1024 characters."
  (wf-manager--bounded-text-p value 0 1024))

(defun wf-manager--nullable-positive-p (value)
  "Return non-nil when VALUE is JSON null or an integer from 1 to 2^31-1.
An absent VALUE gives nil."
  (or (eq value :null)
      (wf-manager--bounded-integer value 1 wf-manager--int32-max)))

(defun wf-manager--realization-p (value)
  "Return non-nil when VALUE is a realization of a routed policy."
  (let ((fields (wf-manager--within-p value wf-manager--realization-fields)))
    (and fields
         (cl-every (lambda (name) (wf-manager--policy-label-p (gethash name fields)))
                   '("profile" "axis" "backend" "router" "provider" "model"))
         (wf-manager--bounded-integer (gethash "rung" fields)
                                      0 wf-manager--int32-max)
         (wf-manager--choice-p (gethash "thinking" fields)
                               wf-manager--thinking-levels)
         (wf-manager--nullable-positive-p (gethash "maxOutput" fields))
         (cl-every (lambda (name)
                     (let ((label (gethash name fields)))
                       (or (null label) (wf-manager--policy-label-p label))))
                   '("modelAlias" "engine"))
         (let ((fingerprint (gethash "executionFingerprint" fields)))
           (or (null fingerprint) (wf-manager--digest-p fingerprint))))))

(defun wf-manager--person-answers-p (value)
  "Return non-nil when VALUE is a list of 1 to 256 answer addresses.
An address is 1 to 1024 characters, \"model:\" or \"tool:\" and a name."
  (and (vectorp value)
       (<= 1 (length value) 256)
       (cl-every (lambda (address)
                   (and (wf-manager--bounded-text-p address 1 1024)
                        (cl-some (lambda (prefix)
                                   (and (string-prefix-p prefix address)
                                        (> (length address) (length prefix))))
                                 '("model:" "tool:"))))
                 value)))

(defun wf-manager--policy-p (value)
  "Return non-nil when VALUE is the frozen policy of one preparation.
The policy is {\"kind\":\"scripted\"} or a routed policy with exactly one
of `default' and `coverage' \"full\", at most 64 routes, poll and timeout
intervals, a boolean `verbose', at most 256 realizations, optional person
answer addresses and an optional complete persona."
  (pcase (wf-manager--member value "kind")
    ("scripted" (and (wf-manager--within-p value '("kind")) t))
    ("routed"
     (let ((default (gethash "default" value))
           (coverage (gethash "coverage" value))
           (routes (gethash "routes" value))
           (realizations (gethash "realizations" value))
           (answers (gethash "personAnswers" value))
           (persona (cl-remove-if-not
                     (lambda (name) (gethash name value))
                     '("routingVersion" "persona" "personaSource" "policyDigest"))))
       (and (wf-manager--within-p value wf-manager--policy-fields)
            (if default
                (and (null coverage) (wf-manager--policy-label-p default))
              (equal coverage "full"))
            (vectorp routes)
            (<= (length routes) 64)
            (cl-every (lambda (route)
                        (let ((fields (wf-manager--within-p route '("name" "backend"))))
                          (and fields
                               (wf-manager--policy-label-p (gethash "name" fields))
                               (wf-manager--policy-label-p (gethash "backend" fields)))))
                      routes)
            (wf-manager--nullable-positive-p (gethash "pollMs" value))
            (wf-manager--nullable-positive-p (gethash "timeoutMs" value))
            (memq (gethash "verbose" value) '(t :false))
            (vectorp realizations)
            (<= (length realizations) 256)
            (cl-every #'wf-manager--realization-p realizations)
            (or (null answers) (wf-manager--person-answers-p answers))
            (or (null persona)
                (and (= (length persona) 4)
                     (eql (wf-manager--bounded-integer
                           (gethash "routingVersion" value)
                           wf-manager--int64-min wf-manager--int64-max)
                          2)
                     (wf-manager--policy-label-p (gethash "persona" value))
                     (wf-manager--choice-p (gethash "personaSource" value)
                                           wf-manager--persona-sources)
                     (wf-manager--digest-p (gethash "policyDigest" value)))))))
    (_ nil)))

(defun wf-manager--parse-review-input (value)
  "Return the `wf-manager-review-input' of the JSON VALUE, or refuse."
  (let ((fields (wf-manager--within value '("name" "source" "bytes" "sha256"))))
    (wf-manager-review-input-make
     :name (wf-manager--bounded-text (gethash "name" fields) 1 1024)
     :source (wf-manager--choice (gethash "source" fields) '("literal" "capture"))
     :bytes (wf-manager--word64-text (gethash "bytes" fields))
     :sha256 (wf-manager--digest (gethash "sha256" fields)))))

(defun wf-manager--parse-review-edit (value)
  "Return the `wf-manager-review-edit' of the JSON VALUE, or refuse."
  (pcase (wf-manager--member value "operation")
    ("drop"
     (let ((fields (wf-manager--within value '("operation" "occurrenceId"))))
       (wf-manager-review-edit-make
        :operation "drop"
        :occurrence-id (wf-manager--word64-text (gethash "occurrenceId" fields)))))
    ("replace"
     (let ((fields (wf-manager--within value '("operation" "occurrenceId" "sha256"))))
       (wf-manager-review-edit-make
        :operation "replace"
        :occurrence-id (wf-manager--word64-text (gethash "occurrenceId" fields))
        :sha256 (wf-manager--digest (gethash "sha256" fields)))))
    (_ (wf-manager--refuse))))

(defun wf-manager--parse-review-lineage (value)
  "Return the `wf-manager-review-lineage' of the JSON VALUE, or refuse.
A lineage has at most 2048 edits, and only a fork has edits."
  (let* ((fields (wf-manager--within value '("parentRunId" "operation" "edits")))
         (operation (wf-manager--choice (gethash "operation" fields)
                                        wf-manager-lineage-operations))
         (edits (wf-manager--items (gethash "edits" fields)
                                   #'wf-manager--parse-review-edit 2048)))
    (unless (or (null edits) (equal operation "fork"))
      (wf-manager--refuse))
    (wf-manager-review-lineage-make
     :parent-run-id (wf-manager--identifier (gethash "parentRunId" fields))
     :operation operation
     :edits edits)))

(defun wf-manager--texts (value)
  "Return the list of at most 256 texts of at most 4096 characters in VALUE.
Refuse any other VALUE."
  (wf-manager--items value (lambda (item) (wf-manager--bounded-text item 0 4096))
                     256))

(defun wf-manager--parse-review (value)
  "Return the `wf-manager-review' of the JSON VALUE, or refuse.
An absent lineage is a root review, and a null lineage refuses."
  (let* ((fields (wf-manager--within value wf-manager--review-fields))
         (policy (gethash "policy" fields))
         (result-code (gethash "resultCode" fields))
         (lineage (gethash "lineage" fields)))
    (unless (and (wf-manager--policy-p policy)
                 (wf-manager--observation-code-p result-code
                                                 wf-manager--review-depth))
      (wf-manager--refuse))
    (wf-manager-review-make
     :program-hash (wf-manager--digest (gethash "programHash" fields))
     :person-answering (wf-manager--choice (gethash "personAnswering" fields)
                                           '("engine" "local-control"))
     :policy policy
     :workflow-id (wf-manager--identifier (gethash "workflowId" fields))
     :profile-id (wf-manager--identifier (gethash "profileId" fields))
     :workspace-label (wf-manager--bounded-text (gethash "workspaceLabel" fields)
                                                0 4096)
     :target-label (wf-manager--bounded-text (gethash "targetLabel" fields) 0 4096)
     :inputs (wf-manager--items (gethash "inputs" fields)
                                #'wf-manager--parse-review-input 256)
     :plan (wf-manager--bounded-text (gethash "plan" fields) 0 524288)
     :run-facts (wf-manager--texts (gethash "runFacts" fields))
     :pins (wf-manager--texts (gethash "pins" fields))
     :warnings (wf-manager--texts (gethash "warnings" fields))
     :result-code result-code
     :lineage (and lineage (wf-manager--parse-review-lineage lineage)))))

(defun wf-manager--parse-preparation (value)
  "Return the `wf-manager-preparation' of the JSON VALUE, or refuse."
  (let* ((fields (wf-manager--within value wf-manager--preparation-fields))
         (identity (lambda (name)
                     (wf-manager--identifier (gethash name fields))))
         (expires-at (gethash "expiresAt" fields)))
    (unless (and (wf-manager--version-one-p fields)
                 (wf-manager-valid-timestamp-p expires-at))
      (wf-manager--refuse))
    (wf-manager-preparation-make
     :id (funcall identity "id")
     :revision (funcall identity "revision")
     :request-id (funcall identity "requestId")
     :request-revision (funcall identity "requestRevision")
     :profile-id (funcall identity "profileId")
     :profile-revision (funcall identity "profileRevision")
     :descriptor-revision (funcall identity "descriptorRevision")
     :state (wf-manager--choice (gethash "state" fields)
                                wf-manager-preparation-states)
     :expires-at expires-at
     :review-digest (wf-manager--digest (gethash "reviewDigest" fields))
     :process-generation (funcall identity "processGeneration")
     :review (wf-manager--parse-review (gethash "review" fields))
     :reason (wf-manager--nullable
              (gethash "reason" fields)
              (lambda (reason)
                (wf-manager--choice reason wf-manager-preparation-reasons))))))

;;;;; Command receipts

(defun wf-manager--optional-decimal-p (value digits maximum)
  "Return non-nil when VALUE is JSON null or a decimal text of the bounds.
The bounds DIGITS and MAXIMUM are those of `wf-manager--decimal-value'.
An absent VALUE gives nil."
  (or (eq value :null) (wf-manager--decimal-value value digits maximum)))

(defun wf-manager--encoded-bytes (value)
  "Return the number of UTF-8 bytes of the compact JSON text of VALUE."
  (length (wf-manager-json-encode value)))

(defun wf-manager--acknowledgement-p (value)
  "Return non-nil when the JSON VALUE is a valid runtime acknowledgement.
An attempt needs an occurrence.  The acknowledgement of an answer names
an occurrence and no attempt.  The compact text has at most 32768
bytes."
  (let* ((fields (wf-manager--closed value '("commandId" "state" "message" "command"
                                              "occurrenceId" "attemptId")))
         (command (wf-manager--member fields "command"))
         (occurrence (wf-manager--member fields "occurrenceId"))
         (attempt (wf-manager--member fields "attemptId"))
         (message (wf-manager--member fields "message")))
    (and fields
         (wf-manager-valid-id-p (gethash "commandId" fields))
         (wf-manager--choice-p (gethash "state" fields)
                               wf-manager--acknowledgement-states)
         (wf-manager--bounded-text-p message 0 4096)
         (or (eq command :null)
             (wf-manager--choice-p command wf-manager--acknowledged-commands))
         (wf-manager--optional-decimal-p occurrence 20 wf-manager--word64-max)
         (wf-manager--optional-decimal-p attempt 10 wf-manager--word32-max)
         (or (eq attempt :null) (not (eq occurrence :null)))
         (or (not (equal command "answer"))
             (and (not (eq occurrence :null)) (eq attempt :null)))
         (<= (wf-manager--encoded-bytes value) 32768))))

(defun wf-manager--effect-address-p (value)
  "Return non-nil when the JSON VALUE is the address of an observed effect.
The address is JSON null, an occurrence, or an occurrence and an attempt."
  (or (eq value :null)
      (let ((fields (if (wf-manager--member value "attemptId")
                        (wf-manager--closed value '("occurrenceId" "attemptId"))
                      (wf-manager--closed value '("occurrenceId")))))
        (and fields
             (wf-manager--decimal-value (gethash "occurrenceId" fields)
                                        20 wf-manager--word64-max)
             (or (null (gethash "attemptId" fields))
                 (wf-manager--decimal-value (gethash "attemptId" fields)
                                            10 wf-manager--word32-max))))))

(defun wf-manager--effect-p (value)
  "Return non-nil when the JSON VALUE is valid evidence of an observed effect.
The compact text has at most 16384 bytes."
  (let ((fields (wf-manager--closed value '("kind" "runtimeSequence" "address"
                                             "resource"))))
    (and fields
         (wf-manager--choice-p (gethash "kind" fields) wf-manager-effect-kinds)
         (wf-manager--optional-decimal-p (gethash "runtimeSequence" fields)
                                         20 wf-manager--word64-max)
         (wf-manager-valid-resource-p (gethash "resource" fields))
         (wf-manager--effect-address-p (gethash "address" fields))
         (<= (wf-manager--encoded-bytes value) 16384))))

(defun wf-manager--receipt-state-p (state attempted acknowledged observed refused)
  "Return non-nil when the receipt STATE agrees with its evidence.
ATTEMPTED, ACKNOWLEDGED, OBSERVED and REFUSED are non-nil when the
receipt has a dispatch attempt time, an acknowledgement, an effect and a
refusal.  An accepted receipt has none of them.  A dispatch-attempted
receipt has only the attempt.  An acknowledged receipt has the attempt
and the acknowledgement, and no effect or refusal.  An effect-observed
receipt has an effect and no refusal, a refused receipt a refusal and no
effect, and an unresolved receipt neither of the two."
  (pcase state
    ("accepted" (not (or attempted acknowledged observed refused)))
    ("dispatch-attempted" (and attempted (not (or acknowledged observed refused))))
    ("acknowledged" (and attempted acknowledged (not (or observed refused))))
    ("effect-observed" (and observed (not refused)))
    ("refused" (and refused (not observed)))
    ("unresolved" (not (or observed refused)))))

(defun wf-manager--parse-command-receipt (value)
  "Return the `wf-manager-command-receipt' of the JSON VALUE, or refuse.
The required scopes and the links agree with the operation, the
identifier and the resource, and the state agrees with the evidence as
`wf-manager--receipt-state-p' states it."
  (let* ((fields (wf-manager--exact value wf-manager--receipt-fields))
         (id (wf-manager--identifier (gethash "id" fields)))
         (operation (wf-manager--choice (gethash "operation" fields)
                                        wf-manager-operations))
         (resource (gethash "resource" fields))
         (state (wf-manager--choice (gethash "state" fields)
                                    wf-manager-command-states))
         (accepted-at (gethash "acceptedAt" fields))
         (attempted-at (wf-manager--nullable
                        (gethash "dispatchAttemptedAt" fields)
                        (lambda (time)
                          (if (wf-manager-valid-timestamp-p time)
                              time
                            (wf-manager--refuse)))))
         (acknowledgement (wf-manager--nullable
                           (gethash "acknowledgement" fields)
                           (lambda (evidence)
                             (wf-manager--ensure
                              (and (wf-manager--acknowledgement-p evidence)
                                   evidence)))))
         (effect (wf-manager--nullable
                  (gethash "effect" fields)
                  (lambda (evidence)
                    (wf-manager--ensure
                     (and (wf-manager--effect-p evidence) evidence)))))
         (refusal (wf-manager--nullable
                   (gethash "refusal" fields)
                   (lambda (code)
                     (wf-manager--choice code wf-manager-receipt-refusals)))))
    (unless (and (wf-manager--version-one-p fields)
                 (wf-manager-valid-resource-p resource)
                 (wf-manager-valid-timestamp-p accepted-at)
                 (wf-manager-json-equal
                  (gethash "requiredScopes" fields)
                  (apply #'vector (wf-manager-required-scopes operation)))
                 (wf-manager-json-equal
                  (gethash "links" fields)
                  (wf-manager-json-object "self" (concat "/v1/commands/" id)
                                          "resource" resource))
                 (wf-manager--receipt-state-p state attempted-at acknowledgement
                                              effect refusal))
      (wf-manager--refuse))
    (wf-manager-command-receipt-make
     :id id
     :profile-id (wf-manager--identifier (gethash "profileId" fields))
     :operation operation
     :resource resource
     :state state
     :accepted-at accepted-at
     :dispatch-attempted-at attempted-at
     :acknowledgement acknowledgement
     :effect effect
     :refusal refusal)))

;;;;; Decisions

(defun wf-manager--parse-recovery-option (value)
  "Return the `wf-manager-recovery-option' of the JSON VALUE, or refuse.
Only a failover names a target."
  (let* ((fields (wf-manager--exact value '("choice" "target")))
         (choice (wf-manager--choice (gethash "choice" fields)
                                     '("retry" "failover" "abandon")))
         (target (wf-manager--nullable
                  (gethash "target" fields)
                  (lambda (text) (wf-manager--bounded-text text 0 1024)))))
    (when (and target (not (equal choice "failover")))
      (wf-manager--refuse))
    (wf-manager-recovery-option-make :choice choice :target target)))

(defun wf-manager--parse-editor-schema (value depth)
  "Return the `wf-manager-editor-schema' of the JSON VALUE at DEPTH, or refuse.
A schema at depth 64 or deeper refuses.  An object schema has at most
256 properties, each of them required, and no additional property."
  (unless (and (hash-table-p value) (< depth 64))
    (wf-manager--refuse))
  (let ((type (wf-manager--choice (gethash "type" value) wf-manager--editor-types)))
    (pcase type
      ("array"
       (let ((fields (wf-manager--exact value '("type" "items"))))
         (wf-manager-editor-schema-make
          :type type
          :items (wf-manager--parse-editor-schema (gethash "items" fields)
                                                  (1+ depth)))))
      ("object"
       (let* ((fields (wf-manager--exact value '("type" "properties" "required"
                                                 "additionalProperties")))
              (properties (gethash "properties" fields))
              (names (if (hash-table-p properties)
                         (wf-manager--json-names properties)
                       (wf-manager--refuse)))
              (required (wf-manager--items
                         (gethash "required" fields)
                         (lambda (name) (wf-manager--bounded-text name 0 1024))
                         256)))
         (unless (and (<= (length names) 256)
                      (cl-every (lambda (name) (wf-manager--bounded-text-p name 0 1024))
                                names)
                      (wf-manager--unique-p required)
                      (eq (gethash "additionalProperties" fields) :false)
                      (= (length required) (length names))
                      (cl-every (lambda (name) (member name required)) names))
           (wf-manager--refuse))
         (wf-manager-editor-schema-make
          :type type
          :properties (mapcar (lambda (name)
                                (cons name (wf-manager--parse-editor-schema
                                            (gethash name properties) (1+ depth))))
                              names))))
      (_ (wf-manager--exact value '("type"))
         (wf-manager-editor-schema-make :type type)))))

(defun wf-manager--parse-question (value)
  "Return the `wf-manager-question' of the JSON VALUE, or refuse.
The semantic schema is JSON null or a semantic schema, and a structured
code states the same schema."
  (let* ((fields (wf-manager--exact value '("code" "semanticSchema" "editorSchema"
                                            "addressee" "scope" "draw" "prompt")))
         (code (gethash "code" fields))
         (schema (gethash "semanticSchema" fields))
         (scope (wf-manager--exact (gethash "scope" fields) '("model" "mode")))
         (label (lambda (text) (wf-manager--bounded-text text 0 1024))))
    (unless (and (wf-manager--observation-code-p code wf-manager--decision-depth)
                 (or (eq schema :null)
                     (wf-manager--semantic-schema-p schema 0 wf-manager--decision-depth))
                 (or (stringp code)
                     (wf-manager-json-equal (gethash "schema" (gethash "json" code))
                                            schema))
                 (wf-manager--decimal-value (gethash "draw" fields) 4096 nil))
      (wf-manager--refuse))
    (wf-manager--bounded-text (gethash "addressee" fields) 0 1024)
    (wf-manager--nullable (gethash "model" scope) label)
    (wf-manager--nullable (gethash "mode" scope) label)
    (wf-manager-question-make
     :code code
     :editor (wf-manager--nullable
              (gethash "editorSchema" fields)
              (lambda (editor) (wf-manager--parse-editor-schema editor 0)))
     :prompt (wf-manager--bounded-text (gethash "prompt" fields) 0 524288))))

(defun wf-manager--parse-recovery (fields)
  "Return the `wf-manager-recovery' of the decision FIELDS, or refuse."
  (wf-manager-recovery-make
   :gap (wf-manager--bounded-text (gethash "gap" fields) 0 4096)
   :message (wf-manager--bounded-text (gethash "message" fields) 0 4096)
   :choices (wf-manager--items (gethash "choices" fields)
                               #'wf-manager--parse-recovery-option 16)))

(defun wf-manager--parse-decision (value)
  "Return the `wf-manager-decision' of the JSON VALUE, or refuse.
A question has the member `question', and a recovery has the members
`gap', `message' and `choices'.  The queue names the decisions of the
run of the decision."
  (let* ((kind (wf-manager--choice (wf-manager--member value "kind")
                                   '("question" "recovery")))
         (fields (wf-manager--exact
                  value (append wf-manager--decision-fields
                                (if (equal kind "question")
                                    '("question")
                                  '("gap" "message" "choices")))))
         (run-id (wf-manager--identifier (gethash "runId" fields)))
         (identity (lambda (name)
                     (wf-manager--identifier (gethash name fields)))))
    (unless (and (wf-manager--version-one-p fields)
                 (equal (gethash "queue" fields)
                        (concat "/v1/decisions?runId=" run-id)))
      (wf-manager--refuse))
    (wf-manager-decision-make
     :id (funcall identity "id")
     :revision (funcall identity "revision")
     :run-id run-id
     :profile-id (funcall identity "profileId")
     :generation (funcall identity "generation")
     :occurrence-id (wf-manager--parse-occurrence-address (gethash "address" fields))
     :state (wf-manager--choice (gethash "state" fields) wf-manager-decision-states)
     :position (wf-manager--integer (gethash "position" fields) 0 2047)
     :observed-sequence (wf-manager--word64-text (gethash "observedSequence" fields))
     :content (if (equal kind "question")
                  (wf-manager--parse-question (gethash "question" fields))
                (wf-manager--parse-recovery fields))
     :value value)))

;;;;; Run controls

(defun wf-manager--boolean (value)
  "Return t for JSON true VALUE and nil for JSON false, and refuse otherwise."
  (cond ((eq value t) t)
        ((eq value :false) nil)
        (t (wf-manager--refuse))))

(defun wf-manager--word32-text (value)
  "Return the integer of VALUE, a canonical unsigned 32-bit decimal text.
Refuse any other VALUE."
  (wf-manager--ensure (wf-manager--decimal-value value 10 wf-manager--word32-max)))

(defun wf-manager--parse-occurrence-address (value)
  "Return the occurrence of the JSON address VALUE, or refuse.
VALUE has exactly the member `occurrenceId', a canonical unsigned 64-bit
decimal text."
  (wf-manager--word64-text
   (gethash "occurrenceId" (wf-manager--exact value '("occurrenceId")))))

(defun wf-manager--parse-offer (value)
  "Return the `wf-manager-control-offer' of the JSON VALUE, or refuse.
The address of a steer offer is an occurrence and an attempt.  The
address of every other offer is an occurrence alone."
  (let* ((fields (wf-manager--exact value '("operation" "address" "generation"
                                            "timings" "choices" "targets")))
         (operation (wf-manager--choice (gethash "operation" fields)
                                        wf-manager-offer-operations))
         (steer (and (equal operation "steer")
                     (wf-manager--exact (gethash "address" fields)
                                        '("occurrenceId" "attemptId"))))
         (timings (wf-manager--items
                   (gethash "timings" fields)
                   (lambda (timing) (wf-manager--choice timing wf-manager-steer-timings))
                   2)))
    (unless (wf-manager--unique-p timings)
      (wf-manager--refuse))
    (wf-manager-control-offer-make
     :operation operation
     :occurrence-id (if steer
                        (wf-manager--word64-text (gethash "occurrenceId" steer))
                      (wf-manager--parse-occurrence-address (gethash "address" fields)))
     :attempt-id (and steer (wf-manager--word32-text (gethash "attemptId" steer)))
     :generation (wf-manager--nullable (gethash "generation" fields)
                                       #'wf-manager--identifier)
     :timings timings
     :choices (wf-manager--items (gethash "choices" fields)
                                 #'wf-manager--parse-recovery-option 16)
     :targets (wf-manager--items (gethash "targets" fields)
                                 (lambda (target) (wf-manager--bounded-text target 0 1024))
                                 256))))

(defun wf-manager--parse-control (value)
  "Return the `wf-manager-control' of the JSON VALUE, or refuse.
The decision head is JSON null or a bounded identifier, and it is never
absent.  A run has at most 512 offers."
  (let ((fields (wf-manager--exact value '("version" "runId" "revision" "supervision"
                                           "cancelAllowed" "offers" "decisionHeadId"))))
    (unless (wf-manager--version-one-p fields)
      (wf-manager--refuse))
    (wf-manager-control-make
     :run-id (wf-manager--identifier (gethash "runId" fields))
     :revision (wf-manager--identifier (gethash "revision" fields))
     :supervision (wf-manager--choice (gethash "supervision" fields)
                                      wf-manager-supervision-states)
     :cancel-allowed (wf-manager--boolean (gethash "cancelAllowed" fields))
     :decision-head-id (wf-manager--nullable (gethash "decisionHeadId" fields)
                                             #'wf-manager--identifier)
     :offers (wf-manager--items (gethash "offers" fields) #'wf-manager--parse-offer 512)
     :value value)))

;;;;; Runs

(defun wf-manager--parse-verification (value)
  "Return the `wf-manager-verification' of the JSON VALUE, or refuse.
An absent result has only its state.  A referenced or verified result
names its artifact.  An unavailable result names its artifact or JSON
null, and its reason."
  (let ((state (wf-manager--choice (wf-manager--member value "state")
                                   '("absent" "referenced" "verified" "unavailable"))))
    (pcase state
      ("absent"
       (wf-manager--exact value '("state"))
       (wf-manager-verification-make :state state))
      ((or "referenced" "verified")
       (wf-manager-verification-make
        :state state
        :artifact-id (wf-manager--identifier
                      (gethash "artifactId"
                               (wf-manager--exact value '("state" "artifactId"))))))
      (_
       (let ((fields (wf-manager--exact value '("state" "artifactId" "reason"))))
         (wf-manager-verification-make
          :state state
          :artifact-id (wf-manager--nullable (gethash "artifactId" fields)
                                             #'wf-manager--identifier)
          :reason (wf-manager--choice (gethash "reason" fields)
                                      wf-manager-unavailable-reasons)))))))

(defun wf-manager--parse-runtime (value)
  "Return the `wf-manager-run-runtime' of the JSON VALUE, or refuse.
The last sequence is canonical unsigned 64-bit decimal text, and the
protocol version is 1, 2 or 3."
  (let ((fields (wf-manager--exact value '("status" "lastSequence" "protocolVersion"))))
    (wf-manager-run-runtime-make
     :status (wf-manager--choice (gethash "status" fields) wf-manager-run-statuses)
     :last-sequence (wf-manager--word64-text (gethash "lastSequence" fields))
     :protocol-version (wf-manager--integer (gethash "protocolVersion" fields) 1 3))))

(defun wf-manager--parse-manifest (value)
  "Return the frontend manifest version of the JSON manifest VALUE, or refuse.
A versioned manifest gives 2 or 3.  A legacy manifest has no version
and gives nil."
  (if (equal (wf-manager--choice (wf-manager--member value "kind")
                                 '("legacy" "versioned"))
             "legacy")
      (progn (wf-manager--exact value '("kind")) nil)
    (wf-manager--integer
     (gethash "frontendManifestVersion"
              (wf-manager--exact value '("kind" "frontendManifestVersion")))
     2 3)))

(defun wf-manager--parse-unreadable-run (fields self)
  "Return the `wf-manager-unreadable-run' of the run FIELDS, or refuse.
The only link is the link SELF."
  (let ((fields (wf-manager--exact fields '("version" "kind" "id" "revision"
                                            "profileId" "category" "links"))))
    (unless (and (equal (gethash "kind" fields) "unreadable-manifest")
                 (wf-manager-json-equal (gethash "links" fields)
                                        (wf-manager-json-object "self" self)))
      (wf-manager--refuse))
    (wf-manager-unreadable-run-make
     :category (wf-manager--choice (gethash "category" fields)
                                   wf-manager-unreadable-categories))))

(defun wf-manager--parse-known-run (fields self)
  "Return the `wf-manager-known-run' of the run FIELDS, or refuse.
The links are SELF and its snapshot, control, outputs, exports and
lineage request links.  The limitations are distinct."
  (let* ((fields (wf-manager--exact fields wf-manager--run-fields))
         (limitations (wf-manager--items
                       (gethash "limitations" fields)
                       (lambda (limitation)
                         (wf-manager--choice limitation wf-manager-run-limitations))
                       6)))
    (unless (and (wf-manager--unique-p limitations)
                 (wf-manager-json-equal
                  (gethash "links" fields)
                  (wf-manager-json-object
                   "self" self
                   "snapshot" (concat self "/snapshot")
                   "control" (concat self "/control")
                   "outputs" (concat self "/outputs")
                   "exports" (concat self "/exports")
                   "lineageRequests" (concat self "/lineage-requests"))))
      (wf-manager--refuse))
    (wf-manager-known-run-make
     :workflow-id (wf-manager--identifier (gethash "workflowId" fields))
     :request-id (wf-manager--nullable (gethash "requestId" fields)
                                       #'wf-manager--identifier)
     :parent-run-id (wf-manager--nullable (gethash "parentRunId" fields)
                                          #'wf-manager--identifier)
     :lineage (wf-manager--nullable
               (gethash "lineage" fields)
               (lambda (operation)
                 (wf-manager--choice operation wf-manager-lineage-operations)))
     :manifest-version (wf-manager--parse-manifest (gethash "manifest" fields))
     :runtime (wf-manager--nullable (gethash "runtime" fields) #'wf-manager--parse-runtime)
     :supervision (wf-manager--choice (gethash "supervision" fields)
                                      wf-manager-supervision-states)
     :integrity (wf-manager--choice (gethash "integrity" fields)
                                    wf-manager-run-integrities)
     :verification (wf-manager--parse-verification (gethash "verification" fields))
     :limitations limitations)))

(defun wf-manager--parse-run (value)
  "Return the `wf-manager-run' of the JSON VALUE, or refuse.
VALUE is a version 1 run, or a version 1 catalogue entry of the kind
\"unreadable-manifest\" with only its public category."
  (unless (and (hash-table-p value) (wf-manager--version-one-p value))
    (wf-manager--refuse))
  (let* ((id (wf-manager--identifier (gethash "id" value)))
         (self (concat "/v1/runs/" id)))
    (wf-manager-run-make
     :id id
     :revision (wf-manager--identifier (gethash "revision" value))
     :profile-id (wf-manager--identifier (gethash "profileId" value))
     :content (if (gethash "kind" value)
                  (wf-manager--parse-unreadable-run value self)
                (wf-manager--parse-known-run value self)))))

;;;;; Overview members

(defconst wf-manager--overview-kinds
  '(("request" wf-manager--parse-draft wf-manager-encode-draft)
    ("preparation" wf-manager--parse-preparation wf-manager-encode-preparation)
    ("run" wf-manager--parse-run wf-manager-run-projection)
    ("decision" wf-manager--parse-decision wf-manager-decision-projection))
  "The overview member kinds.
Each entry is (KIND PARSER ENCODER).  The encoder of a run or a
decision gives its projection.")

(defun wf-manager--parse-overview-member (value)
  "Return the `wf-manager-overview-member' of the JSON VALUE, or refuse.
VALUE is {\"kind\":K,K:MEMBER}."
  (let* ((kind (wf-manager--member value "kind"))
         (entry (wf-manager--ensure (and (stringp kind)
                                         (assoc kind wf-manager--overview-kinds))))
         (fields (wf-manager--exact value (list "kind" kind))))
    (wf-manager-overview-member-make
     :kind kind :value (funcall (nth 1 entry) (gethash kind fields)))))

;;;;; Public decoders and encoders

(defun wf-manager--decode-resource (kind parse value)
  "For a value of KIND, return the record that PARSE gives for VALUE.
A refusal of PARSE signals `wf-manager-invalid-response' about KIND."
  (wf-manager--decided kind (catch 'wf-manager--refusal (funcall parse value))))

(defun wf-manager--json-list (encode items)
  "Return the JSON array of ENCODE applied to each of ITEMS."
  (apply #'vector (mapcar encode items)))

(defun wf-manager--json-nullable (value)
  "Return VALUE, or JSON null when VALUE is nil."
  (or value :null))

(defun wf-manager-decode-input-declaration (value)
  "Return the `wf-manager-input-declaration' of the JSON VALUE.
VALUE has exactly `name', `source', a null `description', a true
`required' and the schema {\"type\":\"string\"}.  Any other VALUE signals
`wf-manager-invalid-response'."
  (wf-manager--decode-resource "input declaration"
                               #'wf-manager--parse-input-declaration value))

(defun wf-manager-encode-input-declaration (declaration)
  "Return the JSON value of DECLARATION, a `wf-manager-input-declaration'."
  (wf-manager-json-object
   "name" (wf-manager-input-declaration-name declaration)
   "source" (wf-manager-input-declaration-source declaration)
   "description" :null
   "required" t
   "schema" (wf-manager--string-schema)))

(defun wf-manager-decode-supplied-input (value)
  "Return the `wf-manager-supplied-input' of the JSON VALUE.
VALUE is a literal input with text of at most 2097152 characters or a
capture input with a bounded identifier.  Any other VALUE signals
`wf-manager-invalid-response'."
  (wf-manager--decode-resource "supplied input"
                               #'wf-manager--parse-supplied-input value))

(defun wf-manager-encode-supplied-input (input)
  "Return the JSON value of INPUT, a `wf-manager-supplied-input'."
  (if (equal (wf-manager-supplied-input-source input) "literal")
      (wf-manager-json-object "name" (wf-manager-supplied-input-name input)
                              "source" "literal"
                              "value" (wf-manager-supplied-input-value input))
    (wf-manager-json-object "name" (wf-manager-supplied-input-name input)
                            "source" "capture"
                            "captureId" (wf-manager-supplied-input-capture-id input))))

(defun wf-manager-decode-input-error (value)
  "Return the `wf-manager-input-error' of the JSON VALUE.
Any VALUE other than exactly `name' and a known `code' signals
`wf-manager-invalid-response'."
  (wf-manager--decode-resource "input error" #'wf-manager--parse-input-error value))

(defun wf-manager-encode-input-error (input-error)
  "Return the JSON value of INPUT-ERROR, a `wf-manager-input-error'."
  (wf-manager-json-object "name" (wf-manager-input-error-name input-error)
                          "code" (wf-manager-input-error-code input-error)))

(defun wf-manager-decode-readiness (value)
  "Return the `wf-manager-readiness' of the JSON VALUE.
Any VALUE that breaks a readiness rule signals
`wf-manager-invalid-response'."
  (wf-manager--decode-resource "readiness" #'wf-manager--parse-readiness value))

(defun wf-manager-encode-readiness (readiness)
  "Return the JSON value of READINESS, a `wf-manager-readiness'."
  (wf-manager-json-object
   "declarations" (wf-manager--json-list #'wf-manager-encode-input-declaration
                                         (wf-manager-readiness-declarations readiness))
   "supplied" (wf-manager--json-list #'wf-manager-encode-supplied-input
                                     (wf-manager-readiness-supplied readiness))
   "missing" (apply #'vector (wf-manager-readiness-missing readiness))
   "errors" (wf-manager--json-list #'wf-manager-encode-input-error
                                   (wf-manager-readiness-errors readiness))))

(defun wf-manager-decode-draft (value)
  "Return the `wf-manager-draft' of the JSON VALUE.
VALUE is a version 1 request resource, or one item of the request
collection, whose self link names its own identifier.  Any other VALUE
signals `wf-manager-invalid-response'."
  (wf-manager--decode-resource "request" #'wf-manager--parse-draft value))

(defun wf-manager-encode-draft (draft)
  "Return the JSON value of DRAFT, a `wf-manager-draft'."
  (let ((position (wf-manager-draft-position draft)))
    (wf-manager-json-object
     "version" (wf-manager-json-integer 1)
     "id" (wf-manager-draft-id draft)
     "revision" (wf-manager-draft-revision draft)
     "workflowId" (wf-manager-draft-workflow-id draft)
     "descriptorRevision" (wf-manager-draft-descriptor-revision draft)
     "profileId" (wf-manager-draft-profile-id draft)
     "profileRevision" (wf-manager-draft-profile-revision draft)
     "phase" (wf-manager-draft-phase draft)
     "readiness" (wf-manager-encode-readiness (wf-manager-draft-readiness draft))
     "admission" (wf-manager-json-object
                  "state" (wf-manager-draft-admission draft)
                  "position" (if position (wf-manager-json-integer position) :null)
                  "reasons" (apply #'vector (wf-manager-draft-reasons draft)))
     "preparationId" (wf-manager--json-nullable (wf-manager-draft-preparation-id draft))
     "runId" (wf-manager--json-nullable (wf-manager-draft-run-id draft))
     "parentRunId" (wf-manager--json-nullable (wf-manager-draft-parent-run-id draft))
     "lineage" (wf-manager--json-nullable (wf-manager-draft-lineage draft))
     "links" (wf-manager-json-object
              "self" (concat "/v1/requests/" (wf-manager-draft-id draft))))))

(defun wf-manager-decode-review-input (value)
  "Return the `wf-manager-review-input' of the JSON VALUE.
The byte count is canonical unsigned 64-bit decimal text.  Any other
VALUE signals `wf-manager-invalid-response'."
  (wf-manager--decode-resource "review input" #'wf-manager--parse-review-input value))

(defun wf-manager-encode-review-input (input)
  "Return the JSON value of INPUT, a `wf-manager-review-input'."
  (wf-manager-json-object
   "name" (wf-manager-review-input-name input)
   "source" (wf-manager-review-input-source input)
   "bytes" (number-to-string (wf-manager-review-input-bytes input))
   "sha256" (wf-manager-review-input-sha256 input)))

(defun wf-manager-decode-review-edit (value)
  "Return the `wf-manager-review-edit' of the JSON VALUE.
The occurrence is canonical unsigned 64-bit decimal text.  Any other
VALUE signals `wf-manager-invalid-response'."
  (wf-manager--decode-resource "review edit" #'wf-manager--parse-review-edit value))

(defun wf-manager-encode-review-edit (edit)
  "Return the JSON value of EDIT, a `wf-manager-review-edit'."
  (let ((object (wf-manager-json-object
                 "operation" (wf-manager-review-edit-operation edit)
                 "occurrenceId" (number-to-string
                                 (wf-manager-review-edit-occurrence-id edit)))))
    (when (wf-manager-review-edit-sha256 edit)
      (puthash "sha256" (wf-manager-review-edit-sha256 edit) object))
    object))

(defun wf-manager-decode-review-lineage (value)
  "Return the `wf-manager-review-lineage' of the JSON VALUE.
Any VALUE that breaks a lineage rule signals
`wf-manager-invalid-response'."
  (wf-manager--decode-resource "review lineage"
                               #'wf-manager--parse-review-lineage value))

(defun wf-manager-encode-review-lineage (lineage)
  "Return the JSON value of LINEAGE, a `wf-manager-review-lineage'."
  (wf-manager-json-object
   "parentRunId" (wf-manager-review-lineage-parent-run-id lineage)
   "operation" (wf-manager-review-lineage-operation lineage)
   "edits" (wf-manager--json-list #'wf-manager-encode-review-edit
                                  (wf-manager-review-lineage-edits lineage))))

(defun wf-manager-decode-review (value)
  "Return the `wf-manager-review' of the JSON VALUE.
An absent lineage is a root review, and a null lineage refuses.  Any
VALUE that breaks a review rule signals `wf-manager-invalid-response'."
  (wf-manager--decode-resource "review" #'wf-manager--parse-review value))

(defun wf-manager-encode-review (review)
  "Return the JSON value of REVIEW, a `wf-manager-review'.
A root review has no `lineage' member."
  (let ((object (wf-manager-json-object
                 "programHash" (wf-manager-review-program-hash review)
                 "personAnswering" (wf-manager-review-person-answering review)
                 "policy" (wf-manager-review-policy review)
                 "workflowId" (wf-manager-review-workflow-id review)
                 "profileId" (wf-manager-review-profile-id review)
                 "workspaceLabel" (wf-manager-review-workspace-label review)
                 "targetLabel" (wf-manager-review-target-label review)
                 "inputs" (wf-manager--json-list #'wf-manager-encode-review-input
                                                 (wf-manager-review-inputs review))
                 "plan" (wf-manager-review-plan review)
                 "runFacts" (apply #'vector (wf-manager-review-run-facts review))
                 "pins" (apply #'vector (wf-manager-review-pins review))
                 "warnings" (apply #'vector (wf-manager-review-warnings review))
                 "resultCode" (wf-manager-review-result-code review))))
    (when (wf-manager-review-lineage review)
      (puthash "lineage" (wf-manager-encode-review-lineage
                          (wf-manager-review-lineage review))
               object))
    object))

(defun wf-manager-decode-preparation (value)
  "Return the `wf-manager-preparation' of the JSON VALUE.
VALUE is a version 1 preparation with a valid expiry time, a lowercase
review digest and a valid review.  Any other VALUE signals
`wf-manager-invalid-response'."
  (wf-manager--decode-resource "preparation" #'wf-manager--parse-preparation value))

(defun wf-manager-encode-preparation (preparation)
  "Return the JSON value of PREPARATION, a `wf-manager-preparation'."
  (wf-manager-json-object
   "version" (wf-manager-json-integer 1)
   "id" (wf-manager-preparation-id preparation)
   "revision" (wf-manager-preparation-revision preparation)
   "requestId" (wf-manager-preparation-request-id preparation)
   "requestRevision" (wf-manager-preparation-request-revision preparation)
   "profileId" (wf-manager-preparation-profile-id preparation)
   "profileRevision" (wf-manager-preparation-profile-revision preparation)
   "descriptorRevision" (wf-manager-preparation-descriptor-revision preparation)
   "state" (wf-manager-preparation-state preparation)
   "expiresAt" (wf-manager-preparation-expires-at preparation)
   "reviewDigest" (wf-manager-preparation-review-digest preparation)
   "processGeneration" (wf-manager-preparation-process-generation preparation)
   "review" (wf-manager-encode-review (wf-manager-preparation-review preparation))
   "reason" (wf-manager--json-nullable (wf-manager-preparation-reason preparation))))

(defun wf-manager-decode-command-receipt (value)
  "Return the `wf-manager-command-receipt' of the JSON VALUE.
The required scopes and the links agree with the operation, the
identifier and the resource.  The state agrees with the dispatch attempt
time, the acknowledgement, the effect and the refusal.  Any other VALUE
signals `wf-manager-invalid-response'."
  (wf-manager--decode-resource "command receipt"
                               #'wf-manager--parse-command-receipt value))

(defun wf-manager-encode-command-receipt (receipt)
  "Return the JSON value of RECEIPT, a `wf-manager-command-receipt'."
  (let ((id (wf-manager-command-receipt-id receipt))
        (operation (wf-manager-command-receipt-operation receipt))
        (resource (wf-manager-command-receipt-resource receipt)))
    (wf-manager-json-object
     "version" (wf-manager-json-integer 1)
     "id" id
     "profileId" (wf-manager-command-receipt-profile-id receipt)
     "operation" operation
     "requiredScopes" (apply #'vector (wf-manager-required-scopes operation))
     "resource" resource
     "state" (wf-manager-command-receipt-state receipt)
     "acceptedAt" (wf-manager-command-receipt-accepted-at receipt)
     "dispatchAttemptedAt" (wf-manager--json-nullable
                            (wf-manager-command-receipt-dispatch-attempted-at receipt))
     "acknowledgement" (wf-manager--json-nullable
                        (wf-manager-command-receipt-acknowledgement receipt))
     "effect" (wf-manager--json-nullable (wf-manager-command-receipt-effect receipt))
     "refusal" (wf-manager--json-nullable (wf-manager-command-receipt-refusal receipt))
     "links" (wf-manager-json-object "self" (concat "/v1/commands/" id)
                                     "resource" resource))))

(defun wf-manager-decode-decision (value)
  "Return the `wf-manager-decision' of the JSON VALUE.
The decision keeps VALUE itself.  Any VALUE that breaks a decision rule
signals `wf-manager-invalid-response'."
  (wf-manager--decode-resource "decision" #'wf-manager--parse-decision value))

(defun wf-manager--recovery-option-json (option)
  "Return the JSON value of OPTION, a `wf-manager-recovery-option'."
  (wf-manager-json-object
   "choice" (wf-manager-recovery-option-choice option)
   "target" (wf-manager--json-nullable (wf-manager-recovery-option-target option))))

(defun wf-manager-decision-projection (decision)
  "Return the JSON projection of the decoded fields of DECISION.
DECISION is a `wf-manager-decision'.  The occurrence and the observed
sequence are canonical decimal text.  The content of a question is its
code and prompt, and the content of a recovery is its gap, message and
choices."
  (let ((content (wf-manager-decision-content decision)))
    (wf-manager-json-object
     "id" (wf-manager-decision-id decision)
     "revision" (wf-manager-decision-revision decision)
     "runId" (wf-manager-decision-run-id decision)
     "profileId" (wf-manager-decision-profile-id decision)
     "generation" (wf-manager-decision-generation decision)
     "occurrenceId" (number-to-string (wf-manager-decision-occurrence-id decision))
     "state" (wf-manager-decision-state decision)
     "position" (wf-manager-json-integer (wf-manager-decision-position decision))
     "observedSequence" (number-to-string
                         (wf-manager-decision-observed-sequence decision))
     "content"
     (if (wf-manager-question-p content)
         (wf-manager-json-object "kind" "question"
                                 "code" (wf-manager-question-code content)
                                 "prompt" (wf-manager-question-prompt content))
       (wf-manager-json-object
        "kind" "recovery"
        "gap" (wf-manager-recovery-gap content)
        "message" (wf-manager-recovery-message content)
        "choices" (wf-manager--json-list #'wf-manager--recovery-option-json
                                         (wf-manager-recovery-choices content)))))))

(defun wf-manager-decode-control (value)
  "Return the `wf-manager-control' of the JSON VALUE.
The controls keep VALUE itself.  Any VALUE that breaks a control rule
signals `wf-manager-invalid-response'."
  (wf-manager--decode-resource "run control" #'wf-manager--parse-control value))

(defun wf-manager--offer-projection (offer)
  "Return the JSON projection of OFFER, a `wf-manager-control-offer'."
  (let ((attempt (wf-manager-control-offer-attempt-id offer)))
    (wf-manager-json-object
     "operation" (wf-manager-control-offer-operation offer)
     "occurrenceId" (number-to-string (wf-manager-control-offer-occurrence-id offer))
     "attemptId" (if attempt (number-to-string attempt) :null)
     "generation" (wf-manager--json-nullable (wf-manager-control-offer-generation offer))
     "timings" (apply #'vector (wf-manager-control-offer-timings offer))
     "choices" (wf-manager--json-list #'wf-manager--recovery-option-json
                                      (wf-manager-control-offer-choices offer))
     "targets" (apply #'vector (wf-manager-control-offer-targets offer)))))

(defun wf-manager-control-projection (control)
  "Return the JSON projection of the decoded fields of CONTROL.
CONTROL is a `wf-manager-control'.  Each occurrence and attempt is
canonical decimal text, and an offer without an attempt has a null
attempt."
  (wf-manager-json-object
   "runId" (wf-manager-control-run-id control)
   "revision" (wf-manager-control-revision control)
   "supervision" (wf-manager-control-supervision control)
   "cancelAllowed" (if (wf-manager-control-cancel-allowed control) t :false)
   "decisionHeadId" (wf-manager--json-nullable (wf-manager-control-decision-head-id control))
   "offers" (wf-manager--json-list #'wf-manager--offer-projection
                                   (wf-manager-control-offers control))))

(defun wf-manager-decode-run (value)
  "Return the `wf-manager-run' of the JSON VALUE.
VALUE is one item of the run collection whose links name its own
identifier, or a catalogue entry whose manifest is unreadable.  Any
VALUE that breaks a run rule signals `wf-manager-invalid-response'."
  (wf-manager--decode-resource "run" #'wf-manager--parse-run value))

(defun wf-manager--verification-projection (verification)
  "Return the JSON projection of VERIFICATION, a `wf-manager-verification'."
  (let ((state (wf-manager-verification-state verification))
        (artifact (wf-manager-verification-artifact-id verification)))
    (pcase state
      ("absent" (wf-manager-json-object "state" state))
      ("unavailable"
       (wf-manager-json-object "state" state
                               "artifactId" (wf-manager--json-nullable artifact)
                               "reason" (wf-manager-verification-reason verification)))
      (_ (wf-manager-json-object "state" state "artifactId" artifact)))))

(defun wf-manager--known-run-projection (known)
  "Return the JSON projection of KNOWN, a `wf-manager-known-run'."
  (let ((runtime (wf-manager-known-run-runtime known))
        (manifest (wf-manager-known-run-manifest-version known)))
    (wf-manager-json-object
     "kind" "known"
     "workflowId" (wf-manager-known-run-workflow-id known)
     "requestId" (wf-manager--json-nullable (wf-manager-known-run-request-id known))
     "parentRunId" (wf-manager--json-nullable (wf-manager-known-run-parent-run-id known))
     "lineage" (wf-manager--json-nullable (wf-manager-known-run-lineage known))
     "manifestVersion" (if manifest (wf-manager-json-integer manifest) :null)
     "runtime" (if runtime
                   (wf-manager-json-object
                    "status" (wf-manager-run-runtime-status runtime)
                    "lastSequence" (number-to-string
                                    (wf-manager-run-runtime-last-sequence runtime))
                    "protocolVersion" (wf-manager-json-integer
                                       (wf-manager-run-runtime-protocol-version runtime)))
                 :null)
     "supervision" (wf-manager-known-run-supervision known)
     "integrity" (wf-manager-known-run-integrity known)
     "verification" (wf-manager--verification-projection
                     (wf-manager-known-run-verification known))
     "limitations" (apply #'vector (wf-manager-known-run-limitations known)))))

(defun wf-manager-run-projection (run)
  "Return the JSON projection of the decoded fields of RUN, a `wf-manager-run'.
The last sequence is canonical decimal text.  The runtime, the
supervision, the integrity and the verification of a known run are
separate members."
  (let ((content (wf-manager-run-content run)))
    (wf-manager-json-object
     "id" (wf-manager-run-id run)
     "revision" (wf-manager-run-revision run)
     "profileId" (wf-manager-run-profile-id run)
     "content" (if (wf-manager-unreadable-run-p content)
                   (wf-manager-json-object
                    "kind" "unreadable"
                    "category" (wf-manager-unreadable-run-category content))
                 (wf-manager--known-run-projection content)))))

(defun wf-manager-decode-overview-member (value)
  "Return the `wf-manager-overview-member' of the JSON VALUE.
VALUE is {\"kind\":K,K:MEMBER} for a kind of
`wf-manager--overview-kinds'.  Any other VALUE signals
`wf-manager-invalid-response'."
  (wf-manager--decode-resource "overview member"
                               #'wf-manager--parse-overview-member value))

(defun wf-manager-encode-overview-member (member)
  "Return the JSON value of MEMBER, a `wf-manager-overview-member'."
  (let ((kind (wf-manager-overview-member-kind member)))
    (wf-manager-json-object
     "kind" kind
     kind (funcall (nth 2 (assoc kind wf-manager--overview-kinds))
                   (wf-manager-overview-member-value member)))))

;;;; Typed answers

;; The answer builder follows `answerValue' and `answerBody' of
;; `ext-pi/src/manager/resources.ts' in agent-cat.  It refuses an answer
;; with `wf-manager-invalid-answer' before any command is built.

(defconst wf-manager--space
  "[\t\n\v\f\r    -   　]+"
  "White space as the Haskell `isSpace' names it.
This is tab to carriage return and the Unicode space separators.")

(defun wf-manager--refuse-answer (reason &rest args)
  "Signal `wf-manager-invalid-answer' with the REASON formatted with ARGS."
  (apply #'wf-manager--fail 'wf-manager-invalid-answer "answer" reason args))

(defun wf-manager--strip (text)
  "Return TEXT without the white space at its two ends."
  (string-trim text wf-manager--space wf-manager--space))

(defun wf-manager--json-answer (input)
  "Return the exact JSON value of the answer text INPUT.
INPUT of more than `wf-manager-person-answer-bytes' bytes, and INPUT
that is not JSON, signal `wf-manager-invalid-answer'."
  (when (> (string-bytes input) wf-manager-person-answer-bytes)
    (wf-manager--refuse-answer "person answer exceeds %d UTF-8 bytes"
                               wf-manager-person-answer-bytes))
  (condition-case nil
      (wf-manager-json-decode input wf-manager-person-answer-bytes)
    (wf-manager-error (wf-manager--refuse-answer "answer is not JSON"))))

(defun wf-manager--person-answer (code input)
  "Return the JSON answer for the primitive CODE of the text INPUT.
A flag takes yes, no, true or false in any letter case, and y or n, and
gives t or :false.  A receipt takes empty input and gives :null.  A text
answer is INPUT itself.  A verdict takes JSON text.  Other INPUT signals
`wf-manager-invalid-answer'."
  (pcase code
    ("text" input)
    ("flag"
     ;; Upper case and then lower case folds the letters of these words as
     ;; full case folding does.
     (let ((word (downcase (upcase (wf-manager--strip input)))))
       (cond ((member word '("y" "yes" "true")) t)
             ((member word '("n" "no" "false")) :false)
             (t (wf-manager--refuse-answer
                 "a flag answer must be yes, no, true, or false")))))
    ("receipt"
     (if (equal (wf-manager--strip input) "")
         :null
       (wf-manager--refuse-answer "a receipt answer must be empty")))
    ("verdict" (wf-manager--json-answer input))
    (_ (wf-manager--refuse-answer "unsupported person answer code %s" code))))

(defun wf-manager--editor-noun (type)
  "Return the noun phrase of the editor schema TYPE."
  (pcase type
    ("null" "null")
    ((or "integer" "array" "object") (concat "an " type))
    (_ (concat "a " type))))

(defun wf-manager--editor-problem (schema value place)
  "Return the first disagreement of the editor SCHEMA with the JSON VALUE.
Return nil when SCHEMA accepts VALUE.  PLACE names VALUE in the
reason, for example \"answer field ok\", so a reason reads
\"answer field ok must be a boolean\"."
  (let* ((type (wf-manager-editor-schema-type schema))
         (wrong (format "%s must be %s" place (wf-manager--editor-noun type))))
    (pcase type
      ("null" (unless (eq value :null) wrong))
      ("boolean" (unless (memq value '(t :false)) wrong))
      ("integer" (unless (and (wf-manager-json-number-p value)
                              (>= (nth 2 (wf-manager--decimal value)) 0))
                   wrong))
      ("number" (unless (wf-manager-json-number-p value) wrong))
      ("string" (unless (stringp value) wrong))
      ("array"
       (if (not (vectorp value))
           wrong
         (cl-loop for item across value
                  for index from 0
                  thereis (wf-manager--editor-problem
                           (wf-manager-editor-schema-items schema) item
                           (format "%s item %d" place index)))))
      ("object"
       (if (not (hash-table-p value))
           wrong
         (let ((properties (wf-manager-editor-schema-properties schema)))
           (or (cl-loop for (name . _) in properties
                        unless (gethash name value)
                        return (format "%s lacks the field %s" place name))
               (cl-loop for name in (wf-manager--json-names value)
                        unless (assoc name properties)
                        return (format "%s has the unknown field %s" place name))
               (cl-loop for (name . field) in properties
                        thereis (wf-manager--editor-problem
                                 field (gethash name value)
                                 (format "%s field %s" place name))))))))))

(defun wf-manager-answer-value (decision input)
  "Return the typed JSON answer for DECISION of the text INPUT.
DECISION is a `wf-manager-decision'.  A question with a primitive code
converts INPUT by its code, so the flag input \"no\" gives :false, JSON
false, and an empty receipt gives :null.  A structured question takes
JSON text that agrees with the editor schema of the decision.  A
structured question without an editor schema, a recovery decision, and
INPUT that does not agree with the code, signal
`wf-manager-invalid-answer' before any command is built."
  (let ((content (wf-manager-decision-content decision)))
    (cond
     ((wf-manager-recovery-p content)
      (wf-manager--refuse-answer "a recovery decision takes no answer"))
     ((stringp (wf-manager-question-code content))
      (wf-manager--person-answer (wf-manager-question-code content) input))
     ((null (wf-manager-question-editor content))
      (wf-manager--refuse-answer
       "the decision gives no editor schema for its structured answer"))
     (t
      (let* ((value (wf-manager--json-answer input))
             (problem (wf-manager--editor-problem
                       (wf-manager-question-editor content) value "answer")))
        (if problem (wf-manager--refuse-answer "%s" problem) value))))))

(defun wf-manager-answer-body (decision value)
  "Return the closed answer body of DECISION with the typed answer VALUE.
The body names the operation, the occurrence of DECISION as canonical
decimal text, the generation of DECISION and VALUE.  VALUE is a result
of `wf-manager-answer-value'."
  (wf-manager-json-object
   "operation" "answer"
   "occurrenceId" (number-to-string (wf-manager-decision-occurrence-id decision))
   "generation" (wf-manager-decision-generation decision)
   "value" value))

;;;; Refresh coordination

;; The functions below follow `ext-pi/src/manager/refresh.ts' and
;; `Agentic.Manager.Client.Refresh' in agent-cat.  They perform no I/O.
;; Each one returns the next state and the actions that the caller
;; performs, and no action and no report is a send.

(cl-defstruct (wf-manager-flight
               (:constructor wf-manager-flight-make)
               (:copier nil))
  "The one fetch in flight for a resource.
GENERATION is the generation of the fetch.  DIRTY is non-nil when an
invalidation arrived after the fetch started."
  (generation 0 :read-only t)
  (dirty nil :read-only t))

(cl-defstruct (wf-manager-refresh
               (:constructor wf-manager-refresh--make)
               (:copier nil))
  "The refresh state of one client session.
GENERATION is the current generation, a non-negative integer.  FLIGHTS
is an alist from a resource key to its `wf-manager-flight'.  Keys are
compared with `equal'.  A key without a flight is idle.  A state is
never changed in place."
  (generation 0 :read-only t)
  (flights nil :read-only t))

(cl-defstruct (wf-manager-refresh-step
               (:constructor wf-manager-refresh-step-make)
               (:copier nil))
  "The result of one refresh step.
STATE is the next `wf-manager-refresh'.  ACTIONS is the list of the
actions of the step, in order.  An action is (KIND KEY GENERATION),
where KIND is `fetch', `install' or `discard'.  The caller starts one
fetch of KEY for GENERATION on `fetch', installs the result of the
completed fetch, a value or a refusal, on `install', and drops the
result of the completed fetch on `discard'."
  (state nil :read-only t)
  (actions nil :read-only t))

(defun wf-manager-refresh-new ()
  "Return the refresh state of generation zero with every resource idle."
  (wf-manager-refresh--make :generation 0 :flights nil))

(defun wf-manager-refresh-flight (key state)
  "Return the `wf-manager-flight' of the resource KEY in STATE, or nil."
  (cdr (assoc key (wf-manager-refresh-flights state))))

(defun wf-manager--refresh-with (state key flight)
  "Return STATE with KEY idle for a nil FLIGHT, or with FLIGHT as its flight."
  (let ((others (cl-remove key (wf-manager-refresh-flights state)
                           :key #'car :test #'equal)))
    (wf-manager-refresh--make
     :generation (wf-manager-refresh-generation state)
     :flights (if flight (cons (cons key flight) others) others))))

(defun wf-manager-refresh-invalidate (key state)
  "Return the `wf-manager-refresh-step' of an invalidation of KEY in STATE.
An idle resource starts a fetch of the current generation.  A resource
with a fetch in flight only becomes dirty, so any number of
invalidations during one fetch give one later fetch."
  (let ((flight (wf-manager-refresh-flight key state))
        (current (wf-manager-refresh-generation state)))
    (if flight
        (wf-manager-refresh-step-make
         :state (wf-manager--refresh-with
                 state key (wf-manager-flight-make
                            :generation (wf-manager-flight-generation flight)
                            :dirty t))
         :actions nil)
      (wf-manager-refresh-step-make
       :state (wf-manager--refresh-with
               state key (wf-manager-flight-make :generation current :dirty nil))
       :actions (list (list 'fetch key current))))))

(defun wf-manager-refresh-complete (key generation state)
  "Return the `wf-manager-refresh-step' of a completed fetch.
The fetch is of the resource KEY for GENERATION, and STATE is the
refresh state.  Only the fetch in flight of the current generation
installs.  When that resource is dirty, exactly one further fetch
starts, and otherwise the resource becomes idle.  Every other
completion, in particular one of an earlier generation, is discarded
and changes nothing."
  (let ((current (wf-manager-refresh-generation state))
        (flight (wf-manager-refresh-flight key state)))
    (cond
     ((not (and flight (eql generation current)
                (eql (wf-manager-flight-generation flight) current)))
      (wf-manager-refresh-step-make
       :state state :actions (list (list 'discard key generation))))
     ((wf-manager-flight-dirty flight)
      (wf-manager-refresh-step-make
       :state (wf-manager--refresh-with
               state key (wf-manager-flight-make :generation current :dirty nil))
       :actions (list (list 'install key generation) (list 'fetch key current))))
     (t
      (wf-manager-refresh-step-make
       :state (wf-manager--refresh-with state key nil)
       :actions (list (list 'install key generation)))))))

(defun wf-manager-refresh-advance (state)
  "Return STATE after a resnapshot or an endpoint switch.
A resnapshot follows a 410 refusal or a new overview.  The generation
advances and every resource becomes idle, so each fetch still in
flight is discarded when it completes."
  (wf-manager-refresh--make
   :generation (1+ (wf-manager-refresh-generation state)) :flights nil))

(defconst wf-manager-reconnect-backoff-max-seconds 30
  "The `reconnectBackoffMaxSeconds' limit of /capabilities, in seconds.")

(defconst wf-manager-initial-backoff 1
  "The first reconnection delay, in seconds.
A connection that delivered an event resets the backoff to it.")

(defun wf-manager-reconnect-delay (backoff)
  "Return the delay of a reconnection with BACKOFF, and the next backoff.
BACKOFF is a delay in seconds.  The result is (DELAY . NEXT).  The
delay doubles from one second up to
`wf-manager-reconnect-backoff-max-seconds' and then stays there."
  (cons backoff (min wf-manager-reconnect-backoff-max-seconds (* 2 backoff))))

(defun wf-manager-jittered-microseconds (seconds fraction)
  "Return the jittered wait in microseconds for a delay and a fraction.
SECONDS is the delay in seconds.  FRACTION is a number from zero to
one.  The wait is between half the delay and the whole delay, so it
never passes `wf-manager-reconnect-backoff-max-seconds'.  A FRACTION
outside that range is clamped, and a FRACTION that is not a number
counts as zero."
  (let ((clamped (cond ((not (numberp fraction)) 0)
                       ((>= fraction 1) 1)
                       ((> fraction 0) fraction)
                       (t 0))))
    (floor (* seconds 1000000 (+ 0.5 (* 0.5 clamped))))))

(cl-defstruct (wf-manager-uncertain
               (:constructor wf-manager-uncertain-make)
               (:copier nil))
  "A sent command whose outcome is uncertain.
COMMAND is the exact pending command, with its bytes, its idempotency
key and its precondition.  TARGET is the location of the target
resource.  PRECONDITION is the entity tag of the precondition, or nil.
RECEIPT is the location of the command receipt when an earlier
response gave one, or nil."
  (command nil :read-only t)
  (target nil :read-only t)
  (precondition nil :read-only t)
  (receipt nil :read-only t))

(cl-defstruct (wf-manager-reconcile-target
               (:constructor wf-manager-reconcile-target-make)
               (:copier nil))
  "The resource that reconciles an uncertain command in place of its target.
A command whose target no longer serves its effect, such as an
answered decision that reads as 404, names this resource.  LOCATION is
the location of the resource.  PRECONDITION is the entity tag of that
resource from before the send, or nil."
  (location nil :read-only t)
  (precondition nil :read-only t))

(defun wf-manager--reconcile-basis (uncertain supplied)
  "Return the uncertain command that the rules compare for UNCERTAIN.
SUPPLIED is a `wf-manager-reconcile-target' or nil.  Without a receipt
location, SUPPLIED replaces the target and the precondition, so that
the rules compare the entity tags of one resource."
  (if (or (null supplied) (wf-manager-uncertain-receipt uncertain))
      uncertain
    (wf-manager-uncertain-make
     :command (wf-manager-uncertain-command uncertain)
     :target (wf-manager-reconcile-target-location supplied)
     :precondition (wf-manager-reconcile-target-precondition supplied)
     :receipt nil)))

(defun wf-manager-reconcile-read (uncertain &optional supplied)
  "Return the one read that reconciles UNCERTAIN.
UNCERTAIN is a `wf-manager-uncertain'.  The read is (receipt LOCATION)
for the receipt location when one is known, and otherwise
\(target LOCATION) for the target resource.  SUPPLIED is an optional
`wf-manager-reconcile-target'.  Without a receipt location, its
location replaces the target."
  (let ((basis (wf-manager--reconcile-basis uncertain supplied)))
    (if (wf-manager-uncertain-receipt basis)
        (list 'receipt (wf-manager-uncertain-receipt basis))
      (list 'target (wf-manager-uncertain-target basis)))))

(defun wf-manager-reconcile (uncertain observation &optional supplied)
  "Return the report of the reconciliation of UNCERTAIN with OBSERVATION.
OBSERVATION is the result of the read of `wf-manager-reconcile-read'
with the same SUPPLIED: (receipt STATE) with the state of the receipt,
\(target ETAG VISIBLE) with the entity tag of the read resource and
whether the caller sees the effect of the command in it, or
\(failure FAILURE) for a refused or failed read, where FAILURE is a
list (CONDITION . DATA).

With a receipt location, only the receipt decides: the state
effect-observed gives the report (effect-observed), the state refused
gives (refused), and every other state stays uncertain.  Without one,
the target observes the effect only when VISIBLE is non-nil and ETAG
differs from the precondition.  When SUPPLIED is a
`wf-manager-reconcile-target', its precondition is the precondition
of that comparison.  A failed read and an observation of the other
read stay uncertain.  The report of a command that stays uncertain is
\(uncertain UNCERTAIN), with UNCERTAIN itself, so its exact bytes, key
and precondition remain for an explicit exact resend.  No report
carries a send."
  (let ((basis (wf-manager--reconcile-basis uncertain supplied)))
    (pcase observation
      ((and `(receipt ,state)
            (guard (wf-manager-uncertain-receipt basis))
            (guard (member state '("effect-observed" "refused"))))
       (list (intern state)))
      ((and `(target ,etag ,visible)
            (guard (null (wf-manager-uncertain-receipt basis)))
            (guard visible)
            (guard (not (equal etag (wf-manager-uncertain-precondition basis)))))
       (list 'effect-observed))
      (_ (list 'uncertain uncertain)))))

;;;; HTTP transport

;; The transport sends each request with `url-retrieve' over the GnuTLS
;; of Emacs, so the wait for a response does not block editing.  The
;; response arrives through a process filter and a callback, and timers
;; run while a request waits.  The connection and its TLS handshake open
;; before `url-retrieve' returns.  At each call, the transport binds the url.el, GnuTLS
;; and network security manager variables that `wf-manager--retrieve'
;; names.  The CA file of the profile is the only trust file, and
;; certificate verification failures are errors.  No proxy, redirect,
;; keepalive, cookie, cache or history applies, and url.el adds no
;; negotiation header of its own.
;;
;; url-http sends the Accept header of `url-mime-accept-string' with
;; every request, and the manager refuses a repeated Accept with 400
;; malformed-request.  The transport therefore binds that variable to
;; the Accept value of the request and never puts Accept in
;; `url-request-extra-headers'.  The Authorization header is always in
;; the extra headers, so `url-http-handle-authentication' consults no
;; authentication source on a 401 and the response comes back as a
;; typed refusal.  `url-request-noninteractive' and `nsm-noninteractive'
;; are t, so no request prompts.  `wf-manager--nsm-verify' binds
;; `nsm-noninteractive' and `nsm-settings-file' again for each process
;; of a transport, both while its connection opens inside `url-retrieve'
;; and for each later security check of that process.  It also binds `network-security-level' to
;; `low', so the network security manager adds no check of its own.  The
;; GnuTLS verification of the handshake against the CA file of the
;; profile, with `gnutls-verify-error' t, is the trust decision.  The
;; network security manager would refuse a self-signed server
;; certificate even when the CA file holds that certificate, which is
;; the certificate that a local manager generates.
;;
;; url.el gives its callback the complete response one time, and it has
;; no supported facility that delivers the bytes of an open response to
;; a caller as they arrive.  The client therefore follows /v1/events in
;; the bounded polling mode, which this file names `poll':
;; `wf-manager-poll-events' sends Accept application/json and the cursor
;; in the query parameter `after'.

;; url-http declares these buffer-local variables of its buffers only
;; inside its own file.
(defvar url-http-end-of-headers)
(defvar url-http-response-status)
(defvar url-http-content-length)
(defvar url-http-no-retry)

(defconst wf-manager-response-seconds 15
  "The longest wait for a complete response, in seconds.")

(defconst wf-manager-command-bytes 2097152
  "The largest command body, in bytes.")

(defconst wf-manager--header-count 100
  "The largest number of response header lines.")

(defconst wf-manager--header-bytes 16384
  "The largest response header size, in bytes.")

(defconst wf-manager--unique-headers
  '("content-type" "content-length" "transfer-encoding" "content-encoding"
    "etag" "location" "cache-control" "content-disposition")
  "The response headers that occur at most one time.")

(defconst wf-manager--nonce-bytes 16
  "The number of random bytes of one idempotency key nonce.
Their unpadded base64url text has 22 characters.")

(defconst wf-manager--epoch-characters 105
  "The longest authority epoch, in characters.")

(defvar wf-manager--scheme "https"
  "The URL scheme of the requests of a transport.
A client profile always names an https endpoint.  The offline tests of
`wf-manager-tests.el' bind this variable to \"http\" so that a plain
local listener receives the exact request bytes.")

(cl-defstruct (wf-manager-transport
               (:constructor wf-manager--transport-make)
               (:copier nil))
  "The HTTP transport of one manager session.
PROFILE is the `wf-manager-profile' of the session.  DIRECTORY is the
isolated directory of the session.  It holds the settings file of the
network security manager and the cache directory of url.el, which
stays empty.  OWNED is non-nil when the transport made DIRECTORY, and
`wf-manager-transport-close' then removes it.  EXCHANGES is the list of
the pending `wf-manager-exchange' records.  CLOSED is non-nil after
`wf-manager-transport-close'."
  (profile nil :read-only t)
  (directory nil :read-only t)
  (owned nil :read-only t)
  (exchanges nil)
  (closed nil))

(cl-defstruct (wf-manager-exchange
               (:constructor wf-manager--exchange-make)
               (:copier nil))
  "One request of a transport, a handle that `wf-manager-cancel' takes.
TRANSPORT is the `wf-manager-transport'.  DECODE turns the received
response into the result of the request.  CALLBACK receives that
result or a failure.  LIMIT is the bound of the response body, in
bytes.  BUFFER and PROCESS are the url.el buffer and network process
of the request.  TIMER is the response timer.  SETTLED is non-nil
after the request has its outcome."
  (transport nil :read-only t)
  (decode nil :read-only t)
  (callback nil :read-only t)
  (limit nil :read-only t)
  (buffer nil)
  (process nil)
  (timer nil)
  (settled nil))

(cl-defstruct (wf-manager-reply
               (:constructor wf-manager--reply-make)
               (:copier nil))
  "One bounded JSON response of the manager.
STATUS is the HTTP status, from 200 to 299.  VALUE is the decoded JSON
body, an object whose `version' is 1.  ETAG is the strong entity tag of
the response, or nil.  LOCATION is the resource of the Location header,
or nil.  SIZE is the number of body bytes."
  (status nil :read-only t)
  (value nil :read-only t)
  (etag nil :read-only t)
  (location nil :read-only t)
  (size nil :read-only t))

(defun wf-manager-failure-p (value)
  "Return non-nil when VALUE is a failure of this client.
A failure is a list (CONDITION . DATA) whose CONDITION is below
`wf-manager-error'."
  (and (consp value)
       (symbolp (car value))
       (memq 'wf-manager-error (get (car value) 'error-conditions))
       t))

(defvar wf-manager--opening nil
  "The settings file of the transport whose connection opens now, or nil.
`wf-manager--retrieve' binds it while `url-retrieve' opens the
connection of a request and verifies its TLS handshake.")

(defun wf-manager--nsm-verify (verify process &rest arguments)
  "Call VERIFY with PROCESS and ARGUMENTS, without a prompt for a transport.
This function is :around advice of `nsm-verify-connection'.  When
PROCESS belongs to a transport, it carries the settings file of that
transport, or it opens while `wf-manager--opening' names that file.
VERIFY then runs with `nsm-noninteractive' bound to t,
`nsm-settings-file' bound to that file and `network-security-level'
bound to `low'.  The handshake of the process has already verified the
server certificate against the CA file of the profile."
  (let ((file (or (and (processp process)
                       (process-get process 'wf-manager-nsm-settings-file))
                  wf-manager--opening)))
    (if file
        (let ((nsm-noninteractive t)
              (nsm-settings-file file)
              (network-security-level 'low))
          (apply verify process arguments))
      (apply verify process arguments))))

(defun wf-manager-transport-open (profile &optional directory)
  "Return a new `wf-manager-transport' for the loaded PROFILE.
DIRECTORY is the absolute name of an existing directory of the session.
When DIRECTORY is nil, the transport makes a private temporary
directory and removes it on close.  A DIRECTORY that is not an
existing absolute directory and a temporary directory that cannot be
made each signal `wf-manager-file-unavailable'."
  (unless (wf-manager-profile-p profile)
    (signal 'wrong-type-argument (list 'wf-manager-profile-p profile)))
  (when (and directory
             (not (and (stringp directory)
                       (file-name-absolute-p directory)
                       (file-directory-p directory))))
    (wf-manager--fail 'wf-manager-file-unavailable "directory"
                      "%s is not an absolute directory" directory))
  (let ((made
         (or directory
             (condition-case failure
                 (make-temp-file "wf-manager-session" t)
               (file-error
                (wf-manager--fail 'wf-manager-file-unavailable "directory"
                                  "the temporary directory cannot be made: %s"
                                  (error-message-string failure)))))))
    (advice-add 'nsm-verify-connection :around #'wf-manager--nsm-verify)
    (wf-manager--transport-make
     :profile profile
     :directory (file-name-as-directory made)
     :owned (null directory))))

(defun wf-manager-transport-close (transport)
  "Close TRANSPORT and end each of its pending requests.
Each pending request receives the failure (wf-manager-closed
\"transport\" REASON), and its url.el process and buffer are gone when
this function returns.  A later request on TRANSPORT signals
`wf-manager-closed'.  A directory that the transport made is removed."
  (unless (wf-manager-transport-closed transport)
    (setf (wf-manager-transport-closed transport) t)
    (dolist (exchange (copy-sequence (wf-manager-transport-exchanges transport)))
      (wf-manager--conclude exchange
                            (list 'wf-manager-closed "transport"
                                  "the transport was closed")))
    (when (wf-manager-transport-owned transport)
      (delete-directory (wf-manager-transport-directory transport) t))))

(defun wf-manager-cancel (exchange)
  "Cancel the request EXCHANGE.
A pending request receives the failure (wf-manager-closed \"request\"
REASON), and its url.el process and buffer are gone when this function
returns.  A request that already has its outcome does not change."
  (wf-manager--conclude exchange
                        (list 'wf-manager-closed "request"
                              "the request was cancelled")))

(defun wf-manager--release (exchange)
  "Stop the timer of EXCHANGE, and delete its process and its buffer."
  (let ((buffer (wf-manager-exchange-buffer exchange))
        (timer (wf-manager-exchange-timer exchange))
        (transport (wf-manager-exchange-transport exchange)))
    (when timer
      (cancel-timer timer))
    (dolist (process (delete-dups
                      (delq nil (list (wf-manager-exchange-process exchange)
                                      (and (buffer-live-p buffer)
                                           (get-buffer-process buffer))))))
      (set-process-query-on-exit-flag process nil)
      (delete-process process))
    (when (buffer-live-p buffer)
      (kill-buffer buffer))
    (setf (wf-manager-transport-exchanges transport)
          (delq exchange (wf-manager-transport-exchanges transport)))))

(defun wf-manager--conclude (exchange outcome)
  "Give EXCHANGE the OUTCOME when it has none yet.
Release the url.el process and buffer of EXCHANGE, then call its
callback with OUTCOME."
  (unless (wf-manager-exchange-settled exchange)
    (setf (wf-manager-exchange-settled exchange) t)
    (wf-manager--release exchange)
    (funcall (wf-manager-exchange-callback exchange) outcome)))

(defun wf-manager--too-large (what limit)
  "Return the failure of a response WHAT above LIMIT bytes."
  (list 'wf-manager-response-too-large "response"
        (format "the response %s has more than %d bytes" what limit)))

(defun wf-manager--watch (exchange)
  "End EXCHANGE as soon as its response passes a bound.
This function runs after each output of the url.el process.  A header
above `wf-manager--header-bytes', a declared length above the limit
of EXCHANGE and received body bytes above that limit each end the
request with a `wf-manager-response-too-large' failure."
  (let ((buffer (wf-manager-exchange-buffer exchange))
        (limit (wf-manager-exchange-limit exchange)))
    (when (and (not (wf-manager-exchange-settled exchange))
               (buffer-live-p buffer))
      (let ((failure
             (with-current-buffer buffer
               (save-restriction
                 (widen)
                 (cond
                  ((markerp url-http-end-of-headers)
                   (cond
                    ((and (integerp url-http-content-length)
                          (> url-http-content-length limit))
                     (wf-manager--too-large "body" limit))
                    ((> (- (point-max) (1+ url-http-end-of-headers)) limit)
                     (wf-manager--too-large "body" limit))))
                  ((> (buffer-size) wf-manager--header-bytes)
                   (wf-manager--too-large "header" wf-manager--header-bytes)))))))
        (when failure
          (wf-manager--conclude exchange failure))))))

(defun wf-manager--url (endpoint resource)
  "Return the URL at ENDPOINT, a `wf-manager-endpoint', of RESOURCE."
  (let ((host (wf-manager-endpoint-host endpoint)))
    (format "%s://%s:%d%s" wf-manager--scheme
            (if (string-search ":" host) (concat "[" host "]") host)
            (wf-manager-endpoint-port endpoint)
            resource)))

(defun wf-manager--request-settings (transport accept)
  "Return the url.el settings of one request of TRANSPORT with ACCEPT.
The value is an alist from a variable to its value.  url-http reads
these variables when it writes the request and when it parses the
response, which it does in the url.el buffer after `url-retrieve'
returns.  The settings make
url.el send ACCEPT as the one Accept value and no other negotiation,
agent, extension or cache header, follow no redirect, keep no
connection alive, store nothing in a cache, and never prompt."
  (let ((directory (wf-manager-transport-directory transport)))
    `((url-mime-accept-string . ,accept)
      (url-mime-charset-string . nil)
      (url-mime-language-string . nil)
      (url-mime-encoding-string . nil)
      (url-user-agent . nil)
      (url-extensions-header . nil)
      (url-max-redirections . 0)
      (url-http-attempt-keepalives . nil)
      (url-automatic-caching . nil)
      (url-cache-directory . ,(expand-file-name "url-cache" directory))
      (url-request-noninteractive . t)
      (nsm-noninteractive . t)
      (nsm-settings-file . ,(expand-file-name "network-security.data" directory)))))

(defun wf-manager--retrieve (transport url request callback)
  "For TRANSPORT, start the retrieval of URL and return its url.el buffer.
REQUEST is (METHOD HEADERS BODY ACCEPT): the method, the extra headers
as an alist, the unibyte body or nil, and the Accept value.  CALLBACK
is the callback of `url-retrieve'.  The call binds the settings of
`wf-manager--request-settings' and the variables of the connection: no
proxy, no connection of another caller, no cookie, no history, the CA
file of the profile as the only trust file, and verification failures
as errors.  It then gives the url.el buffer the same settings as
buffer-local values.

The connection and its TLS handshake open before `url-retrieve'
returns, because `url-asynchronous' is nil.  A connection of Emacs
30 on macOS that opens without waiting starts its TLS handshake at
once, and when the peer refuses the connection at once, that handshake
writes to the refused socket and the signal SIGPIPE ends the Emacs
process.  A connection that opens before the call returns gives such a
refusal as a `file-error' instead.  The wait for the response still
does not block."
  ;; The setup of url.el reads proxy settings from the environment one
  ;; time.  It runs here, before the bindings, so that it cannot change
  ;; them.
  (url-do-setup)
  (pcase-let* ((`(,method ,headers ,body ,accept) request)
               (settings (wf-manager--request-settings transport accept))
               (buffer
                (cl-progv (mapcar #'car settings) (mapcar #'cdr settings)
                  (let ((url-request-method method)
                        (url-request-extra-headers headers)
                        (url-request-data body)
                        (url-current-lastloc nil)
                        (url-proxy-services nil)
                        (url-http-open-connections (make-hash-table :test #'equal))
                        (url-history-track nil)
                        (url-asynchronous nil)
                        (wf-manager--opening
                         (expand-file-name "network-security.data"
                                           (wf-manager-transport-directory transport)))
                        (gnutls-trustfiles
                         (list (wf-manager-profile-ca-file
                                (wf-manager-transport-profile transport))))
                        (gnutls-verify-error t))
                    (url-retrieve url callback nil t t)))))
    (with-current-buffer buffer
      (dolist (setting settings)
        (set (make-local-variable (car setting)) (cdr setting))))
    buffer))

(defun wf-manager--unibyte-header (header)
  "Return HEADER, a cons of a name and a value, with unibyte strings.
url-http joins the extra headers and the body of a request without an
encoding, and it refuses a request that is multibyte text.  A
multibyte header value, such as an entity tag of a parsed response or
an authority epoch of a decoded body, would make the request multibyte
when the body has a byte above 127.  Each header of a request is
ASCII text."
  (cons (encode-coding-string (car header) 'utf-8)
        (encode-coding-string (cdr header) 'utf-8)))

(defun wf-manager--send (transport request decode limit callback)
  "On TRANSPORT, send REQUEST and return its `wf-manager-exchange'.
REQUEST is (METHOD RESOURCE HEADERS BODY ACCEPT).  RESOURCE is a
resource path below /v1/.  HEADERS are the extra headers without
Authorization, which this function adds from the profile.  DECODE
turns the response (STATUS HEADERS BODY) into the result, or signals a
condition below `wf-manager-error'.  LIMIT bounds the response body,
in bytes.  CALLBACK runs exactly one time, after this function
returns, with the result or a failure (CONDITION . DATA)."
  (pcase-let ((`(,method ,resource ,headers ,body ,accept) request))
    (when (wf-manager-transport-closed transport)
      (signal 'wf-manager-closed (list "transport" "the transport is closed")))
    (unless (wf-manager-valid-resource-p resource)
      (wf-manager--fail 'wf-manager-invalid-endpoint "resource"
                        "%S is not a resource path below /v1/" resource))
    (let* ((profile (wf-manager-transport-profile transport))
           (exchange (wf-manager--exchange-make
                      :transport transport :decode decode
                      :callback callback :limit limit)))
      (push exchange (wf-manager-transport-exchanges transport))
      (condition-case failure
          (let* ((buffer (wf-manager--retrieve
                          transport
                          (wf-manager--url (wf-manager-profile-endpoint profile)
                                           resource)
                          (list method
                                (mapcar #'wf-manager--unibyte-header
                                        (cons (wf-manager-authorization profile)
                                              headers))
                                body accept)
                          (lambda (status)
                            (wf-manager--received exchange status))))
                 (process (get-buffer-process buffer)))
            (setf (wf-manager-exchange-buffer exchange) buffer
                  (wf-manager-exchange-process exchange) process)
            ;; url-http sends a request again when a reused connection
            ;; closes before a response.  No request of this transport
            ;; is ever sent again.
            (with-current-buffer buffer
              (setq url-http-no-retry t))
            (when process
              (set-process-query-on-exit-flag process nil)
              (process-put process 'wf-manager-nsm-settings-file
                           (expand-file-name
                            "network-security.data"
                            (wf-manager-transport-directory transport)))
              (add-function :after (process-filter process)
                            (lambda (_process _output)
                              (wf-manager--watch exchange))))
            (setf (wf-manager-exchange-timer exchange)
                  (run-at-time wf-manager-response-seconds nil
                               #'wf-manager--conclude exchange
                               (list 'wf-manager-transport-unavailable "response"
                                     (format "no complete response within %d seconds"
                                             wf-manager-response-seconds)))))
        ;; The connection and its TLS handshake open inside
        ;; `url-retrieve'.  A refused or failed connection signals a
        ;; `file-error'.  A failed handshake signals `gnutls-error'.  A
        ;; certificate that the CA file does not verify signals a plain
        ;; `error' of GnuTLS, and url-http signals a plain `error' when
        ;; it has no connection.  Each one ends the request after this
        ;; function returns.  An error of another condition is a defect
        ;; of this client and is signaled again.
        ((file-error gnutls-error)
         (wf-manager--unopened exchange failure))
        (error
         (unless (eq (car failure) 'error)
           (signal (car failure) (cdr failure)))
         (wf-manager--unopened exchange failure)))
      exchange)))

(defun wf-manager--unopened (exchange failure)
  "End EXCHANGE, whose connection did not open, from a timer.
FAILURE is the error of the connection.  The timer runs after the
caller has returned, and it concludes EXCHANGE with a
`wf-manager-transport-unavailable' failure."
  (setf (wf-manager-exchange-timer exchange)
        (run-at-time 0 nil #'wf-manager--conclude exchange
                     (list 'wf-manager-transport-unavailable "connection"
                           (error-message-string failure)))))

(defun wf-manager--received (exchange status)
  "Conclude EXCHANGE with the response in the current url.el buffer.
STATUS is the status list that `url-retrieve' gives its callback."
  (unless (wf-manager-exchange-settled exchange)
    (wf-manager--conclude
     exchange
     (if (not (and (integerp url-http-response-status)
                   (markerp url-http-end-of-headers)))
         (list 'wf-manager-transport-unavailable "connection"
               (format "no complete response: %S" (plist-get status :error)))
       (save-restriction
         (widen)
         (condition-case failure
             (funcall (wf-manager-exchange-decode exchange)
                      (wf-manager--response
                       (wf-manager-exchange-limit exchange)))
           (wf-manager-error failure)))))))

(defun wf-manager--header (headers name)
  "In HEADERS, return the value of the header NAME, or nil."
  (cdr (assoc name headers)))

(defun wf-manager--response (limit)
  "Return the response in the current url.el buffer as (STATUS HEADERS BODY).
HEADERS is an alist from lowercase names to values, in order.  BODY is
a unibyte string.  The response has at most `wf-manager--header-count'
header lines of at most `wf-manager--header-bytes' bytes and at most
LIMIT body bytes, or it signals `wf-manager-response-too-large'.  A
repeated framing header, `Transfer-Encoding' together with
`Content-Length', and a `Content-Encoding' signal
`wf-manager-invalid-response'.  A redirect status signals
`wf-manager-redirect-refused'.  A body shorter than its declared length
signals `wf-manager-transport-unavailable'."
  (let* ((end (marker-position url-http-end-of-headers))
         (lines (cdr (split-string
                      (buffer-substring-no-properties (point-min) end) "\n" t)))
         (body (string-to-unibyte
                (buffer-substring-no-properties (min (1+ end) (point-max))
                                                (point-max))))
         (status url-http-response-status)
         (size 0)
         (headers nil))
    (dolist (line lines)
      (setq size (+ size (length line) 2))
      (when (string-match "\\`\\([^: \t]+\\):[ \t]*\\(.*?\\)[ \t]*\\'" line)
        (push (cons (downcase (match-string 1 line)) (match-string 2 line))
              headers)))
    (setq headers (nreverse headers))
    (let ((declared (wf-manager--header headers "content-length")))
      (cond
       ((or (> (length lines) wf-manager--header-count)
            (> size wf-manager--header-bytes))
        (signal (car (wf-manager--too-large "header" wf-manager--header-bytes))
                (cdr (wf-manager--too-large "header" wf-manager--header-bytes))))
       ((or (cl-some (lambda (name)
                       (> (cl-count name headers :key #'car :test #'equal) 1))
                     wf-manager--unique-headers)
            (and declared (wf-manager--header headers "transfer-encoding")))
        (wf-manager--fail 'wf-manager-invalid-response "headers"
                          "a framing header occurs more than one time"))
       ((<= 300 status 399)
        (wf-manager--fail 'wf-manager-redirect-refused "response"
                          "the manager answered with the redirect status %d"
                          status))
       ((wf-manager--header headers "content-encoding")
        (wf-manager--fail 'wf-manager-invalid-response "headers"
                          "the response has a content coding"))
       ((> (length body) limit)
        (signal (car (wf-manager--too-large "body" limit))
                (cdr (wf-manager--too-large "body" limit))))
       ((and declared (/= (string-to-number declared) (length body)))
        (wf-manager--fail 'wf-manager-transport-unavailable "response"
                          "the response ended before its declared length"))))
    (list status headers body)))

(defun wf-manager--media-type (headers)
  "Return the media type of the Content-Type header in HEADERS, or nil."
  (let ((value (wf-manager--header headers "content-type")))
    (and value (car (split-string value ";")))))

(defun wf-manager--problem (status headers body)
  "Signal the failure of the problem response with STATUS, HEADERS and BODY.
The response has the media type application/problem+json and
`Cache-Control: no-store'.  The failure is the one of
`wf-manager-problem-failure'."
  (unless (and (equal (wf-manager--media-type headers) "application/problem+json")
               (equal (wf-manager--header headers "cache-control") "no-store"))
    (wf-manager--fail 'wf-manager-invalid-response "problem"
                      "the status %d response is not a problem response" status))
  (let ((failure (wf-manager-problem-failure status (wf-manager-json-decode body))))
    (signal (car failure) (cdr failure))))

(defun wf-manager--json-reply (response)
  "Return the `wf-manager-reply' of RESPONSE, a list (STATUS HEADERS BODY).
A status outside 200 to 299 signals the failure of its problem
response.  A 2xx response has the media type application/json,
`Cache-Control: no-store' and a JSON object whose `version' is 1, or
it signals `wf-manager-invalid-response' or
`wf-manager-unsupported-version'.  Its ETag is a strong entity tag and
its Location a resource below /v1/, when present."
  (pcase-let ((`(,status ,headers ,body) response))
    (unless (<= 200 status 299)
      (wf-manager--problem status headers body))
    (unless (and (equal (wf-manager--media-type headers) "application/json")
                 (equal (wf-manager--header headers "cache-control") "no-store"))
      (wf-manager--fail 'wf-manager-invalid-response "response"
                        "the response is not application/json with no-store"))
    (let ((value (wf-manager-json-decode body))
          (etag (wf-manager--header headers "etag"))
          (location (wf-manager--header headers "location")))
      (unless (and (hash-table-p value) (wf-manager--version-one-p value))
        (wf-manager--fail 'wf-manager-unsupported-version "response"
                          "the response version is not 1"))
      (unless (and (or (null etag) (wf-manager-valid-etag-p etag))
                   (or (null location) (wf-manager-valid-resource-p location)))
        (wf-manager--fail 'wf-manager-invalid-response "response"
                          "the ETag or the Location is not valid"))
      (wf-manager--reply-make :status status :value value :etag etag
                              :location location :size (length body)))))

(defun wf-manager-get (transport resource callback)
  "On TRANSPORT, send one GET of RESOURCE and return its exchange.
RESOURCE is a resource path below /v1/.  The request has exactly one
Authorization header and the Accept value application/json.  CALLBACK
runs one time with a `wf-manager-reply' or a failure (CONDITION . DATA).
A closed TRANSPORT signals `wf-manager-closed', and an invalid RESOURCE
signals `wf-manager-invalid-endpoint'."
  (wf-manager--send transport (list "GET" resource nil nil "application/json")
                    #'wf-manager--json-reply wf-manager-response-bytes callback))

(defun wf-manager-valid-key-p (key)
  "Return non-nil when KEY is a valid idempotency key.
A valid key is 1 to 128 visible ASCII characters."
  (and (stringp key) (wf-manager--matches-p "[!-~]\\{1,128\\}" key)))

(defun wf-manager-post (transport resource body key if-match callback)
  "On TRANSPORT, send one POST to RESOURCE of the JSON BODY.
Return the exchange.  KEY is the idempotency key, and IF-MATCH is a
strong entity tag or nil.  The request has the headers Authorization,
Accept, Content-Type, Idempotency-Key and, when IF-MATCH is non-nil,
If-Match.  The transport sends it one time and never sends it again.
CALLBACK runs one time with a `wf-manager-reply' or a failure.  A body
of more than `wf-manager-command-bytes' bytes, an invalid KEY and an
invalid IF-MATCH signal `wf-manager-invalid-request' before any send."
  (let ((bytes (wf-manager-json-encode body)))
    (when (> (length bytes) wf-manager-command-bytes)
      (wf-manager--fail 'wf-manager-invalid-request "command"
                        "the command has more than %d bytes"
                        wf-manager-command-bytes))
    (unless (wf-manager-valid-key-p key)
      (wf-manager--fail 'wf-manager-invalid-request "Idempotency-Key"
                        "the key is not 1 to 128 visible ASCII characters"))
    (unless (or (null if-match) (wf-manager-valid-etag-p if-match))
      (wf-manager--fail 'wf-manager-invalid-request "If-Match"
                        "the precondition is not a strong entity tag"))
    (wf-manager--send transport
                      (list "POST" resource
                            `(("Content-Type" . "application/json")
                              ,@(and if-match (list (cons "If-Match" if-match)))
                              ("Idempotency-Key" . ,key))
                            bytes "application/json")
                      #'wf-manager--json-reply wf-manager-response-bytes callback)))

(defun wf-manager-poll-events (transport cursor callback)
  "On TRANSPORT, read one polling batch of /v1/events after CURSOR.
Return the exchange.  This is the `poll' delivery of the client: the
request has the Accept value application/json and the cursor in the
query parameter `after'.  CALLBACK runs one time with a
`wf-manager-event-batch' or a failure.  A 410 refusal, view-expired or
cursor-expired, requires a new snapshot.  An invalid CURSOR signals
`wf-manager-invalid-request' before any send."
  (unless (wf-manager-valid-cursor-p cursor)
    (wf-manager--fail 'wf-manager-invalid-request "cursor"
                      "%S is not an event cursor" cursor))
  (wf-manager--send transport
                    (list "GET" (concat "/v1/events?after=" cursor) nil nil
                          "application/json")
                    (lambda (response)
                      (let ((reply (wf-manager--json-reply response)))
                        (unless (= (wf-manager-reply-status reply) 200)
                          (wf-manager--fail 'wf-manager-invalid-response "event batch"
                                            "the batch status is not 200"))
                        (wf-manager-decode-event-batch (wf-manager-reply-value reply))))
                    wf-manager-response-bytes callback))

;;;; Capabilities

(defconst wf-manager--capability-fields
  '("version" "authorityEpoch" "streamId" "versions" "scopes" "profileIds"
    "transports" "limits")
  "The fields of the capabilities document.")

(defconst wf-manager--numeric-versions
  '(("api" 1) ("snapshot" 1) ("event" 1) ("descriptor" 2 3)
    ("frontendSession" 1 2) ("control" 1 2) ("runtimeProtocol" 1 2 3)
    ("runtimeStore" 1 2) ("managerStore" 1 2 3 4 5 6 7 8 9 10 11 12)
    ("invocation" 1))
  "Each numeric version list of the capabilities and the values it supports.")

(defconst wf-manager--frontend-manifests '("legacy" "2" "3")
  "The frontend manifest versions that this client supports.")

(defconst wf-manager--fixed-limits
  '(("requestTargetBytes" . 8192) ("headerBytes" . 16384) ("headerFields" . 100)
    ("jsonBodyBytes" . 2097152) ("jsonDepth" . 64)
    ("nativeControlBytes" . 1048576) ("captureBytes" . 67108864)
    ("aggregateInputBytes" . 67108864) ("artifactBytes" . 67108864)
    ("sseBlockBytes" . 16384) ("pageBytes" . 1048576)
    ("pageSetBytes" . 67108864) ("pageSetsPerClient" . 2)
    ("pageSetLifetimeSeconds" . 60) ("queuedRequests" . 100)
    ("maxReservations" . 16) ("reviewLifetimeSeconds" . 600)
    ("sseReadersPerClient" . 2) ("ssePendingBytesPerReader" . 1048576)
    ("replaySeconds" . 604800) ("replayBytes" . 268435456)
    ("heartbeatSeconds" . 15) ("reconnectIdleSeconds" . 45)
    ("reconnectBackoffMaxSeconds" . 30) ("ordinaryMutationsPerMinute" . 30))
  "Each fixed limit of the capabilities and its value.")

(defconst wf-manager--configured-limits
  '(("drafts" . 2147483647) ("globalDrafts" . 2147483647)
    ("globalCaptureBytes" . 2147483647) ("globalPageSets" . 2147483647)
    ("globalConnections" . 2147483647) ("globalDatabaseReaders" . 2147483647)
    ("globalMutationLedgerBytes" . 2147483647)
    ("safetyControlsPerMinute" . 2147483647) ("executionReservations" . 16))
  "Each configured limit of the capabilities and its largest value.")

(cl-defstruct (wf-manager-capabilities
               (:constructor wf-manager--capabilities-make)
               (:copier nil))
  "The checked capabilities of a manager.
FIELDS is the decoded capabilities object.  EPOCH is its authority
epoch, the first part of each idempotency key."
  (fields nil :read-only t)
  (epoch nil :read-only t))

(defun wf-manager--strings-p (value)
  "Return non-nil when VALUE is a JSON array of strings."
  (and (vectorp value) (cl-every #'stringp value)))

(defun wf-manager--int32-list (value)
  "Return the integers of the JSON array VALUE, or nil.
Each item is an integer from -2^31 to 2^31-1."
  (and (vectorp value)
       (let ((items (mapcar (lambda (item)
                              (wf-manager--bounded-integer
                               item (- (1+ wf-manager--int32-max))
                               wf-manager--int32-max))
                            value)))
         (and (not (memq nil items)) items))))

(defun wf-manager--limit (limits name)
  "In LIMITS, return the integer of the limit NAME, or nil."
  (wf-manager--bounded-integer (gethash name limits)
                               wf-manager--int64-min wf-manager--int64-max))

(defun wf-manager--versions-supported-p (versions)
  "Return non-nil when this client supports the VERSIONS object.
VERSIONS has exactly the frontend manifest list and the numeric version
lists.  Each list is non-empty and distinct, and each value is one that
this client supports."
  (let ((manifests (and versions (gethash "frontendManifest" versions))))
    (and versions
         (wf-manager--strings-p manifests)
         (> (length manifests) 0)
         (wf-manager--unique-p (append manifests nil))
         (cl-every (lambda (name) (member name wf-manager--frontend-manifests))
                   manifests)
         (cl-every (lambda (entry)
                     (let ((values (wf-manager--int32-list
                                    (gethash (car entry) versions))))
                       (and values
                            (wf-manager--unique-p values)
                            (cl-every (lambda (value) (memq value (cdr entry)))
                                      values))))
                   wf-manager--numeric-versions))))

(defun wf-manager--limits-valid-p (limits)
  "Return non-nil when LIMITS states exactly the limits of this client.
Each fixed limit has its value, and each configured limit is above zero
and at most its largest value."
  (and limits
       (cl-every (lambda (entry)
                   (eql (wf-manager--limit limits (car entry)) (cdr entry)))
                 wf-manager--fixed-limits)
       (cl-every (lambda (entry)
                   (let ((configured (wf-manager--limit limits (car entry))))
                     (and configured (< 0 configured) (<= configured (cdr entry)))))
                 wf-manager--configured-limits)))

(defun wf-manager-check-capabilities (value)
  "Return the `wf-manager-capabilities' of the capabilities document VALUE.
The rules are the rules of checkCapabilities in
`ext-pi/src/manager/session.ts' in agent-cat.  VALUE has exactly the
fields of `wf-manager--capability-fields'.  Versions outside
`wf-manager--numeric-versions' and `wf-manager--frontend-manifests'
signal `wf-manager-unsupported-version'.  Every other break of a rule,
in the version, the authority epoch, the stream, the scopes, the
profiles, the transports or the limits, signals
`wf-manager-invalid-response' about \"capabilities\"."
  (let ((fields (wf-manager--closed value wf-manager--capability-fields)))
    (unless fields
      (wf-manager--fail 'wf-manager-invalid-response "capabilities"
                        "the capabilities do not have exactly their fields"))
    (unless (wf-manager--versions-supported-p
             (wf-manager--closed (gethash "versions" fields)
                                 (cons "frontendManifest"
                                       (mapcar #'car wf-manager--numeric-versions))))
      (wf-manager--fail 'wf-manager-unsupported-version "capabilities"
                        "the manager versions are not versions of this client"))
    (let ((epoch (gethash "authorityEpoch" fields))
          (scopes (gethash "scopes" fields))
          (profiles (gethash "profileIds" fields))
          (transports (gethash "transports" fields)))
      (unless (and (wf-manager--bounded-integer (gethash "version" fields) 1 1)
                   (wf-manager-valid-id-p epoch)
                   (<= (length epoch) wf-manager--epoch-characters)
                   (wf-manager-valid-id-p (gethash "streamId" fields))
                   (wf-manager--strings-p scopes)
                   (<= (length scopes) 4)
                   (wf-manager--unique-p (append scopes nil))
                   (cl-every (lambda (scope)
                               (member scope '("observe" "submit" "control" "export")))
                             scopes)
                   (wf-manager--strings-p profiles)
                   (<= (length profiles) 256)
                   (cl-every #'wf-manager-valid-id-p profiles)
                   (wf-manager--unique-p (append profiles nil))
                   (wf-manager--strings-p transports)
                   (= (length transports) 2)
                   (wf-manager--unique-p (append transports nil))
                   (cl-every (lambda (name) (member name '("sse" "polling")))
                             transports)
                   (wf-manager--limits-valid-p
                    (wf-manager--closed (gethash "limits" fields)
                                        (mapcar #'car
                                                (append wf-manager--fixed-limits
                                                        wf-manager--configured-limits)))))
        (wf-manager--fail 'wf-manager-invalid-response "capabilities"
                          "the capabilities break a rule of this client"))
      (wf-manager--capabilities-make :fields fields :epoch epoch))))

(cl-defstruct (wf-manager-connection
               (:constructor wf-manager--connection-make)
               (:copier nil))
  "One transport bound to the checked capabilities of its manager.
TRANSPORT is the `wf-manager-transport'.  IDENTITY is the random
endpoint identity of the binding, 32 lowercase hexadecimal digits.
CAPABILITIES is the `wf-manager-capabilities' of the binding.  NONCES
holds each idempotency key nonce of the binding, so that no nonce
occurs two times."
  (transport nil :read-only t)
  (identity nil :read-only t)
  (capabilities nil :read-only t)
  (nonces nil :read-only t))

(defun wf-manager--random-bytes (count)
  "Return COUNT random bytes as a unibyte string.
The generator is seeded from the entropy of the system at each call."
  (random t)
  (apply #'unibyte-string (cl-loop repeat count collect (random 256))))

(defun wf-manager-connection-epoch (connection)
  "Return the authority epoch of the capabilities of CONNECTION."
  (wf-manager-capabilities-epoch (wf-manager-connection-capabilities connection)))

(defun wf-manager-connect (profile callback &optional directory)
  "Bind a new transport for PROFILE by one GET of /v1/capabilities.
Return the exchange of that request.  CALLBACK runs one time with a
`wf-manager-connection' that has a fresh random endpoint identity and
the checked capabilities, or with a failure.  A status other than 200
and capabilities that `wf-manager-check-capabilities' refuses are
failures.  After a failure, the transport is closed.  DIRECTORY is the
optional session directory of `wf-manager-transport-open'.  A transport
that cannot open signals `wf-manager-file-unavailable', and no request
starts."
  (let ((transport (wf-manager-transport-open profile directory)))
    (wf-manager--send
     transport (list "GET" "/v1/capabilities" nil nil "application/json")
     (lambda (response)
       (let ((reply (wf-manager--json-reply response)))
         (unless (= (wf-manager-reply-status reply) 200)
           (wf-manager--fail 'wf-manager-invalid-response "capabilities"
                             "the capabilities status is not 200"))
         (wf-manager--connection-make
          :transport transport
          :identity (mapconcat (lambda (byte) (format "%02x" byte))
                               (wf-manager--random-bytes 16) "")
          :capabilities (wf-manager-check-capabilities (wf-manager-reply-value reply))
          :nonces (make-hash-table :test #'equal))))
     wf-manager-response-bytes
     (lambda (outcome)
       (when (wf-manager-failure-p outcome)
         (wf-manager-transport-close transport))
       (funcall callback outcome)))))

(defun wf-manager-command-key (connection)
  "Return a new idempotency key of CONNECTION.
The key is the authority epoch of the capabilities, a dot and a nonce:
16 random bytes in unpadded base64url, 22 characters.  No two keys of
one connection have the same nonce."
  (let ((nonces (wf-manager-connection-nonces connection))
        (nonce nil))
    (while (or (null nonce) (gethash nonce nonces))
      (setq nonce (base64url-encode-string
                   (wf-manager--random-bytes wf-manager--nonce-bytes) t)))
    (puthash nonce t nonces)
    (concat (wf-manager-connection-epoch connection) "." nonce)))

;;;; Sessions

;; A session follows `ManagerSession' of `ext-pi/src/manager/session.ts'
;; in agent-cat, with the poll delivery of this client.  It is bound to
;; one `wf-manager-connection' at a time and to the endpoint identity of
;; that connection.  `wf-manager-session-switch' replaces the connection
;; after the complete overview of the new connection has loaded.  `wf-manager-session-start' assembles the complete
;; overview page set of /v1/snapshot and installs it, and then follows
;; /v1/events from the cursor of that overview with JSON polling
;; batches on timers.  An invalidation marks each watched resource that
;; it concerns, and the refresh coordinator above reads each marked
;; resource again.  A 410 refusal of a batch advances the generation,
;; reads the overview again, invalidates every watched resource and
;; follows from the new cursor.  A read of an earlier generation
;; installs nothing.  No read and no poll is a command, and a session
;; sends no command.

(defconst wf-manager-overview-resource "/v1/snapshot"
  "The first page of the overview page set, and its refresh key.")

(defconst wf-manager--member-collections
  '(("request" . "requests") ("preparation" . "preparations")
    ("run" . "runs") ("decision" . "decisions"))
  "The collection of the detail resource of each overview member kind.")

(defconst wf-manager--page-fields
  '("setId" "revision" "expiresAt" "index" "totalItems" "next")
  "The members of the page object of one page of a page set.")

(defconst wf-manager--page-items 256
  "The largest number of items of one page.")

(defconst wf-manager--page-set-bytes 67108864
  "The largest number of body bytes of one page set.")

(defconst wf-manager-page-set-restarts 3
  "The largest number of restarts of one page set assembly.
A page that the manager refuses with 410 view-expired restarts the
assembly at the first page.")

(defvar wf-manager-poll-seconds 1
  "The interval between two polling batches of a new session, in seconds.
The offline tests of `wf-manager-tests.el' bind it to a shorter
interval.")

(defconst wf-manager--reread-seconds 0.1
  "The wait before a watched resource is read again, in seconds.
The wait follows an installed read that the manager refused with 429
storage-quota or 503 storage-unavailable, because no invalidation
follows such a refusal.")

(cl-defstruct (wf-manager-reference
               (:constructor wf-manager-reference-make)
               (:copier nil))
  "A resource of one binding.
ENDPOINT is the endpoint identity of the binding.  URI is the resource
path below /v1/."
  (endpoint nil :read-only t)
  (uri nil :read-only t))

(cl-defstruct (wf-manager-page-set
               (:constructor wf-manager--page-set-make)
               (:copier nil))
  "One complete page set.
METADATA is the JSON object of the members that every page repeats,
without `page' and `items'.  ITEMS is the list of the items of every
page, in order.  PAGES is the number of pages."
  (metadata nil :read-only t)
  (items nil :read-only t)
  (pages nil :read-only t))

(cl-defstruct (wf-manager-overview-item
               (:constructor wf-manager--overview-item-make)
               (:copier nil))
  "One member of the overview.
MEMBER is the `wf-manager-overview-member'.  REFERENCE is the
`wf-manager-reference' of its detail resource, which is the resource of
its invalidations.  REVISION is its revision."
  (member nil :read-only t)
  (reference nil :read-only t)
  (revision nil :read-only t))

(cl-defstruct (wf-manager-overview
               (:constructor wf-manager--overview-make)
               (:copier nil))
  "One complete overview.
CURSOR is the event cursor of its database boundary, and OLDEST-CURSOR
the oldest resume boundary.  ITEMS is the list of its
`wf-manager-overview-item' records.  PAGES is the number of pages of
its page set."
  (cursor nil :read-only t)
  (oldest-cursor nil :read-only t)
  (items nil :read-only t)
  (pages nil :read-only t))

(cl-defstruct (wf-manager-session
               (:constructor wf-manager--session-make)
               (:copier nil))
  "One manager session, bound to one `wf-manager-connection' at a time.
CONNECTION is the current connection, which
`wf-manager-session-switch' replaces.  SWITCHES is the list of the
transports of the endpoint switches in flight.  INTERVAL is the wait between two polling
batches, in seconds.  ON-CHANGE is nil or a function of the session that
runs after each install, each change of the delivery state, the end of
the follow loop and the close.  REFRESH is the `wf-manager-refresh'
state.  WATCHED is the list of the watched resource paths, which always
holds `wf-manager-overview-resource' after the start.  INSTALLED maps
each watched resource path other than the overview to its last
installed read, a `wf-manager-reply' or a failure.  OVERVIEW is the
installed `wf-manager-overview', a failure, or nil before the first
read.  CURSOR is the cursor of the next polling batch.  DELIVERY is
`connecting' before the first batch, `poll' after a batch that the
manager delivered and `unreachable' after a batch that failed.  BACKOFF
is the next reconnection backoff, in seconds.  FOLLOW-END is nil while
the follow loop runs, and then (KIND FAILURE), where KIND is `refused',
`resnapshot' or `closed'.  POLLS is the number of completed polling
batches.  TIMERS is the list of the pending timers.  CLOSED is non-nil
after `wf-manager-session-close'."
  (connection nil)
  (switches nil)
  (interval nil :read-only t)
  (on-change nil :read-only t)
  (refresh (wf-manager-refresh-new))
  (watched nil)
  (installed (make-hash-table :test #'equal))
  (overview nil)
  (cursor nil)
  (delivery 'connecting)
  (backoff wf-manager-initial-backoff)
  (follow-end nil)
  (polls 0)
  (timers nil)
  (closed nil))

(defun wf-manager-session-transport (session)
  "Return the `wf-manager-transport' of SESSION."
  (wf-manager-connection-transport (wf-manager-session-connection session)))

(defun wf-manager-session-identity (session)
  "Return the endpoint identity of the binding of SESSION."
  (wf-manager-connection-identity (wf-manager-session-connection session)))

(defun wf-manager-session-generation (session)
  "Return the current refresh generation of SESSION."
  (wf-manager-refresh-generation (wf-manager-session-refresh session)))

(defun wf-manager-session-reference (session uri)
  "For the binding of SESSION, return the `wf-manager-reference' of URI.
A URI that is not a resource below /v1/ signals
`wf-manager-invalid-endpoint'."
  (unless (wf-manager-valid-resource-p uri)
    (wf-manager--fail 'wf-manager-invalid-endpoint "resource"
                      "%S is not a resource below /v1/" uri))
  (wf-manager-reference-make :endpoint (wf-manager-session-identity session)
                             :uri uri))

(defun wf-manager--session-refusal (session identity)
  "Return the failure of a read of SESSION for the endpoint IDENTITY, or nil.
A closed session and an identity of another binding refuse."
  (cond ((wf-manager-session-closed session)
         (list 'wf-manager-closed "session" "the session was closed"))
        ((not (equal identity (wf-manager-session-identity session)))
         (list 'wf-manager-wrong-endpoint "reference"
               "the reference names another endpoint"))))

(defun wf-manager--session-changed (session)
  "Run the change function of SESSION, when it has one."
  (let ((function (wf-manager-session-on-change session)))
    (when function (funcall function session))))

(defun wf-manager--session-later (session seconds function &rest arguments)
  "Unless SESSION is closed, call after SECONDS FUNCTION with ARGUMENTS.
The timer is pending until it runs, and `wf-manager-session-close'
cancels it."
  (unless (wf-manager-session-closed session)
    (let ((timer nil))
      (setq timer
            (run-at-time
             seconds nil
             (lambda ()
               (setf (wf-manager-session-timers session)
                     (delq timer (wf-manager-session-timers session)))
               (unless (wf-manager-session-closed session)
                 (apply function arguments)))))
      (push timer (wf-manager-session-timers session)))))

(defun wf-manager--session-get (connection uri callback)
  "On the transport of CONNECTION, send one GET of URI.
CALLBACK runs one time with the `wf-manager-reply' or a failure.  A
reply whose status is not 200 is `wf-manager-invalid-response'.  A send
that signals gives its failure to CALLBACK from a timer."
  (let ((received
         (lambda (outcome)
           (funcall callback
                    (if (and (wf-manager-reply-p outcome)
                             (/= (wf-manager-reply-status outcome) 200))
                        (list 'wf-manager-invalid-response "response"
                              "the status of the read is not 200")
                      outcome)))))
    (condition-case failure
        (wf-manager-get (wf-manager-connection-transport connection) uri received)
      (wf-manager-error (run-at-time 0 nil received failure) nil))))

;;;;; Page sets

(defun wf-manager--page-info (value)
  "Return the page object VALUE of one page as a plist, or nil.
The plist has the keys :set-id, :revision, :expires-at, :expiry,
:index, :total and :next.  :expiry is the Lisp time of :expires-at,
and :next is a resource path or nil."
  (let ((fields (wf-manager--closed value wf-manager--page-fields)))
    (when fields
      (let* ((set-id (gethash "setId" fields))
             (revision (gethash "revision" fields))
             (expires (gethash "expiresAt" fields))
             (index (wf-manager--bounded-integer (gethash "index" fields) 0 65535))
             (total (wf-manager--bounded-integer (gethash "totalItems" fields)
                                                 0 1048576))
             (next (gethash "next" fields))
             (expiry (and (stringp expires) (<= (length expires) 40)
                          (ignore-errors (parse-iso8601-time-string (upcase expires))))))
        (when (and (wf-manager-valid-id-p set-id) (wf-manager-valid-id-p revision)
                   expiry index total
                   (or (eq next :null) (wf-manager-valid-resource-p next)))
          (list :set-id set-id :revision revision :expires-at expires
                :expiry expiry :index index :total total
                :next (and (stringp next) next)))))))

(defun wf-manager--page-scope (uri)
  "Return the path of URI with its sorted query pairs without pageToken.
Return nil when a query name occurs two times.  Each page of one page
set has the scope of its first page."
  (let* ((mark (string-search "?" uri))
         (pairs (and mark
                     (mapcar (lambda (pair)
                               (let ((equal (string-search "=" pair)))
                                 (if equal
                                     (cons (substring pair 0 equal)
                                           (substring pair (1+ equal)))
                                   (cons pair ""))))
                             (split-string (substring uri (1+ mark)) "&" t)))))
    (when (wf-manager--unique-p (mapcar #'car pairs))
      (cons (if mark (substring uri 0 mark) uri)
            (sort (cl-remove "pageToken" pairs :key #'car :test #'equal)
                  (lambda (a b)
                    (or (string< (car a) (car b))
                        (and (string= (car a) (car b))
                             (string< (cdr a) (cdr b))))))))))

(defun wf-manager--page-repeated (value)
  "Return a copy of the page VALUE without its members page and items."
  (let ((copy (copy-hash-table value)))
    (remhash "page" copy)
    (remhash "items" copy)
    copy))

(defun wf-manager-session-page-set (session first callback)
  "Assemble the page set of SESSION whose first page is FIRST.
FIRST is a `wf-manager-reference' of the binding of SESSION.  Return
nil.  CALLBACK runs one time with the complete `wf-manager-page-set'
or a failure, and no partial set is given.  The rules are the rules of
`pageSet' in `ext-pi/src/manager/session.ts': every page repeats the
set identity, the revision, the expiry, the total and the other
members of the first page, the indexes follow each other, each page
has at most 256 items, the set holds at most 64 MiB, every page arrives
before the expiry, and each `next' token keeps the path and the query
of the first page.  Any other page gives `wf-manager-invalid-response'.
A page that the manager refuses with 410 view-expired restarts the
assembly at the first page, at most `wf-manager-page-set-restarts'
times."
  (let ((identity (wf-manager-reference-endpoint first)))
    (wf-manager--page-set (wf-manager-session-connection session)
                          (lambda () (wf-manager--session-refusal session identity))
                          first wf-manager-page-set-restarts callback)))

(defun wf-manager--page-set (connection refusal first restarts callback)
  "Assemble a page set on CONNECTION with REFUSAL from FIRST.
RESTARTS is the number of restarts left.  REFUSAL is a function
without arguments.  It returns nil while the
reads of CONNECTION belong to their session, and otherwise the failure
that ends the assembly.  It runs before each page is sent and after
each page arrives.  CALLBACK receives the set or a failure, as for
`wf-manager-session-page-set'."
  (let* ((scope (wf-manager--page-scope (wf-manager-reference-uri first)))
         (items nil) (count 0) (stamp nil) (metadata nil) (used 0) (index 0))
    (cl-labels
        ((invalid ()
           (funcall callback (list 'wf-manager-invalid-response "page set"
                                   "the page set breaks a rule of this client")))
         (fetch-page (location)
           (let ((refused (funcall refusal)))
             (cond (refused (funcall callback refused))
                   ((not (equal (wf-manager--page-scope location) scope)) (invalid))
                   (t (wf-manager--session-get connection location #'received)))))
         (received (outcome)
           (let ((refused (funcall refusal)))
             (cond
              (refused (funcall callback refused))
              ((and (equal outcome '(wf-manager-refused 410 "view-expired"))
                    (> restarts 0))
               (wf-manager--page-set connection refusal first (1- restarts) callback))
              ((wf-manager-failure-p outcome) (funcall callback outcome))
              (t (page outcome)))))
         (page (reply)
           (let* ((value (wf-manager-reply-value reply))
                  (info (wf-manager--page-info (gethash "page" value)))
                  (page-items (gethash "items" value))
                  (repeated (wf-manager--page-repeated value)))
             (if (not (and info (vectorp page-items)))
                 (invalid)
               (setq used (+ used (wf-manager-reply-size reply))
                     count (+ count (length page-items)))
               (dolist (item (append page-items nil)) (push item items))
               (cond
                ((or (/= (plist-get info :index) index)
                     (not (time-less-p nil (plist-get info :expiry)))
                     (> (length page-items) wf-manager--page-items)
                     (> count (plist-get info :total))
                     (> used wf-manager--page-set-bytes)
                     (and stamp
                          (not (and (equal (plist-get stamp :set-id) (plist-get info :set-id))
                                    (equal (plist-get stamp :revision) (plist-get info :revision))
                                    (equal (plist-get stamp :expires-at)
                                           (plist-get info :expires-at))
                                    (eql (plist-get stamp :total) (plist-get info :total)))))
                     (and metadata (not (wf-manager-json-equal metadata repeated))))
                 (invalid))
                ((null (plist-get info :next))
                 (if (= count (plist-get info :total))
                     (funcall callback (wf-manager--page-set-make
                                        :metadata repeated :items (nreverse items)
                                        :pages (1+ index)))
                   (invalid)))
                ((or (zerop (length page-items))
                     (>= count (plist-get info :total))
                     (>= index 65535))
                 (invalid))
                (t (setq stamp info metadata repeated index (1+ index))
                   (fetch-page (plist-get info :next))))))))
      (if scope
          (fetch-page (wf-manager-reference-uri first))
        (run-at-time 0 nil #'invalid)))))

;;;;; Overview

(defun wf-manager-member-identity (member)
  "Return the identifier and the revision of MEMBER as (ID . REVISION).
MEMBER is a `wf-manager-overview-member'."
  (let ((value (wf-manager-overview-member-value member)))
    (pcase (wf-manager-overview-member-kind member)
      ("request" (cons (wf-manager-draft-id value) (wf-manager-draft-revision value)))
      ("preparation" (cons (wf-manager-preparation-id value)
                           (wf-manager-preparation-revision value)))
      ("run" (cons (wf-manager-run-id value) (wf-manager-run-revision value)))
      ("decision" (cons (wf-manager-decision-id value)
                        (wf-manager-decision-revision value))))))

(defun wf-manager--overview-of (identity set)
  "For the endpoint IDENTITY, return the overview of the page SET.
Return the `wf-manager-overview' or a failure.  Every member reference
carries IDENTITY.  The metadata of
SET has exactly the members `version' 1, `snapshotVersion' 1, `cursor'
and `oldestCursor', and each item decodes as an overview member."
  (or (catch 'wf-manager--refusal
        (let* ((fields (wf-manager--exact (wf-manager-page-set-metadata set)
                                          '("version" "snapshotVersion" "cursor"
                                            "oldestCursor")))
               (cursor (progn
                         (wf-manager--integer (gethash "version" fields) 1 1)
                         (wf-manager--integer (gethash "snapshotVersion" fields) 1 1)
                         (wf-manager--ensure (wf-manager--cursor-field fields "cursor"))))
               (oldest (wf-manager--ensure
                        (wf-manager--cursor-field fields "oldestCursor")))
               (items
                (mapcar
                 (lambda (value)
                   (let* ((member (wf-manager--parse-overview-member value))
                          (ident (wf-manager-member-identity member))
                          (uri (concat "/v1/"
                                       (cdr (assoc (wf-manager-overview-member-kind member)
                                                   wf-manager--member-collections))
                                       "/" (car ident))))
                     (wf-manager--ensure (and (wf-manager-valid-id-p (car ident))
                                              (wf-manager-valid-id-p (cdr ident))
                                              (wf-manager-valid-resource-p uri)))
                     (wf-manager--overview-item-make
                      :member member
                      :reference (wf-manager-reference-make :endpoint identity :uri uri)
                      :revision (cdr ident))))
                 (wf-manager-page-set-items set))))
          (wf-manager--overview-make :cursor cursor :oldest-cursor oldest
                                     :items items
                                     :pages (wf-manager-page-set-pages set))))
      (list 'wf-manager-invalid-response "overview"
            "the overview breaks a rule of this client")))

(defun wf-manager-session-load-overview (session callback)
  "Assemble the overview page set of /v1/snapshot on SESSION.
Return nil.  CALLBACK runs one time with the `wf-manager-overview' or a
failure, as `loadOverview' of `ext-pi/src/manager/session.ts' gives
it.  The assembly follows every `next' token before the overview
exists, and a 410 view-expired restarts it at the first page.  Every
member reference carries the endpoint identity of the binding of
SESSION.  This read installs nothing."
  (let ((identity (wf-manager-session-identity session)))
    (wf-manager--overview-load (wf-manager-session-connection session)
                               (lambda () (wf-manager--session-refusal session identity))
                               callback)))

(defun wf-manager--overview-load (connection refusal callback)
  "Assemble the overview page set of /v1/snapshot on CONNECTION.
REFUSAL is the refusal function of `wf-manager--page-set'.  CALLBACK
runs one time with the `wf-manager-overview' or a failure.  Every member
reference carries the endpoint identity of CONNECTION, so the overview
that `wf-manager-session-switch' reads before its commit is valid for
the session after the commit."
  (let ((identity (wf-manager-connection-identity connection)))
    (wf-manager--page-set
     connection refusal
     (wf-manager-reference-make :endpoint identity :uri wf-manager-overview-resource)
     wf-manager-page-set-restarts
     (lambda (outcome)
       (funcall callback (if (wf-manager-failure-p outcome)
                             outcome
                           (wf-manager--overview-of identity outcome)))))))

;;;;; Follow loop and watched resources

(defun wf-manager-session-start (connection callback &optional on-change)
  "Start a session on CONNECTION and return the `wf-manager-session'.
The session installs the complete overview and then follows /v1/events
from its cursor with JSON polling batches, one batch each
`wf-manager-poll-seconds' or at once while the manager has more.
CALLBACK runs one time with the first overview read, a
`wf-manager-overview' or a failure.  After a failure, the session does
not follow.  ON-CHANGE is nil or a function of the session that runs
after each install, each change of the delivery state, the end of the
follow loop and the close.

A delivered batch sets the delivery state to `poll' and resets the
backoff, and each invalidation of the batch marks the watched
resources that it concerns.  A failed batch sets the delivery state to
`unreachable' and waits for the jittered backoff of
`wf-manager-reconnect-delay' before the next batch.  A 410 refusal
advances the generation, reads the overview again, invalidates every
watched resource and follows from the new cursor.  A 401 refusal ends
the follow loop with `refused'."
  (let ((session (wf-manager--session-make :connection connection
                                           :interval wf-manager-poll-seconds
                                           :on-change on-change)))
    (wf-manager--session-bootstrap
     session
     (lambda (outcome)
       (unless (wf-manager-failure-p outcome)
         (wf-manager--session-follow session (wf-manager-overview-cursor outcome) 0))
       (funcall callback outcome)))
    session))

(defun wf-manager--session-bootstrap (session callback)
  "Watch the overview of SESSION, read it, and install it.
The read installs only when the generation has not changed during the
read.  CALLBACK receives the overview or the failure."
  (cl-pushnew wf-manager-overview-resource (wf-manager-session-watched session)
              :test #'equal)
  (let ((generation (wf-manager-session-generation session)))
    (wf-manager-session-load-overview
     session
     (lambda (outcome)
       (when (and (not (wf-manager-session-closed session))
                  (eql generation (wf-manager-session-generation session)))
         (setf (wf-manager-session-overview session) outcome)
         (wf-manager--session-changed session))
       (funcall callback outcome)))))

(defun wf-manager--session-follow (session cursor seconds)
  "Send the next polling batch of SESSION from CURSOR after SECONDS.
The batch goes to the current connection of SESSION."
  (setf (wf-manager-session-cursor session) cursor)
  (wf-manager--session-later session seconds #'wf-manager--session-poll
                             session (wf-manager-session-connection session)))

(defun wf-manager--session-poll (session connection)
  "Send one polling batch of SESSION on CONNECTION from its cursor.
Nothing is sent when CONNECTION is no longer the connection of SESSION."
  (when (eq connection (wf-manager-session-connection session))
    (condition-case failure
        (wf-manager-poll-events (wf-manager-connection-transport connection)
                                (wf-manager-session-cursor session)
                                (lambda (outcome)
                                  (wf-manager--session-polled session connection outcome)))
      (wf-manager-error (wf-manager--session-polled session connection failure)))))

(defun wf-manager--session-delivery (session state)
  "Set the delivery state of SESSION to STATE."
  (unless (eq state (wf-manager-session-delivery session))
    (setf (wf-manager-session-delivery session) state)
    (wf-manager--session-changed session)))

(defun wf-manager--session-end (session kind failure)
  "End the follow loop of SESSION with KIND and FAILURE."
  (setf (wf-manager-session-follow-end session) (list kind failure))
  (wf-manager--session-changed session))

(defun wf-manager--session-polled (session connection outcome)
  "For SESSION and CONNECTION, handle OUTCOME, the result of one batch.
A batch of a connection that an endpoint switch has replaced changes
nothing."
  (when (and (not (wf-manager-session-closed session))
             (eq connection (wf-manager-session-connection session)))
    (cl-incf (wf-manager-session-polls session))
    (if (wf-manager-event-batch-p outcome)
        (progn
          (setf (wf-manager-session-backoff session) wf-manager-initial-backoff)
          (wf-manager--session-delivery session 'poll)
          (dolist (event (wf-manager-event-batch-events outcome))
            (wf-manager--session-invalidated session event))
          (wf-manager--session-follow
           session (wf-manager-event-batch-cursor outcome)
           (if (wf-manager-event-batch-has-more outcome)
               0
             (wf-manager-session-interval session))))
      (pcase outcome
        (`(wf-manager-refused 410 ,_)
         (wf-manager--session-resnapshot session outcome))
        ((or `(wf-manager-refused 401 ,_) `(wf-manager-credential-unavailable . ,_))
         (wf-manager--session-end session 'refused outcome))
        (`(wf-manager-closed . ,_)
         (wf-manager--session-end session 'closed outcome))
        (_
         (wf-manager--session-delivery session 'unreachable)
         (pcase-let ((`(,delay . ,next)
                      (wf-manager-reconnect-delay (wf-manager-session-backoff session))))
           (setf (wf-manager-session-backoff session) next)
           (wf-manager--session-follow
            session (wf-manager-session-cursor session)
            (/ (wf-manager-jittered-microseconds delay (/ (random 1000000) 1e6))
               1e6))))))))

(defun wf-manager--session-resnapshot (session failure)
  "Take a new overview of SESSION after the 410 refusal FAILURE.
The generation advances first, so each read still in flight installs
nothing.  After the overview installs, every other watched resource is
read again and the follow loop continues from the new cursor.  When
the overview read fails, the follow loop ends with `resnapshot'."
  (setf (wf-manager-session-refresh session)
        (wf-manager-refresh-advance (wf-manager-session-refresh session)))
  (let ((connection (wf-manager-session-connection session)))
    (wf-manager--session-bootstrap
     session
     (lambda (outcome)
       (wf-manager--session-resnapshotted session connection failure outcome)))))

(defun wf-manager--session-resnapshotted (session connection failure outcome)
  "Continue SESSION on CONNECTION after a resnapshot.
FAILURE is the 410 refusal that started the resnapshot, and OUTCOME
is the overview read of the resnapshot.  An endpoint
switch that replaced CONNECTION during the read has started a follow
loop of its own, so the outcome then changes nothing."
  (cond
   ((or (wf-manager-session-closed session)
        (not (eq connection (wf-manager-session-connection session)))))
   ((wf-manager-failure-p outcome)
    (wf-manager--session-end session 'resnapshot failure))
   (t
    (dolist (key (reverse (wf-manager-session-watched session)))
      (unless (equal key wf-manager-overview-resource)
        (wf-manager--session-invalidate session key)))
    (wf-manager--session-follow session (wf-manager-overview-cursor outcome) 0))))

(defun wf-manager--member-resource-p (resource)
  "Return non-nil when RESOURCE is an overview member or lies below one."
  (let ((parts (split-string resource "/")))
    (and (>= (length parts) 4)
         (equal (nth 0 parts) "")
         (equal (nth 1 parts) "v1")
         (rassoc (nth 2 parts) wf-manager--member-collections)
         (not (equal (nth 3 parts) ""))
         t)))

(defun wf-manager--related-p (one other)
  "Return non-nil when the resources ONE and OTHER are equal or nested.
The query of a resource is not part of the comparison."
  (let ((a (car (split-string one "?")))
        (b (car (split-string other "?"))))
    (or (equal a b)
        (string-prefix-p (concat b "/") a)
        (string-prefix-p (concat a "/") b))))

(defun wf-manager--session-invalidated (session event)
  "Mark each watched resource of SESSION that the EVENT concerns.
An invalidation concerns a resource that it equals or that lies above
or below it, and an invalidation of a member resource concerns the
overview."
  (let ((resource (wf-manager-invalidation-resource
                   (wf-manager-invalidation-event-data event))))
    (dolist (key (reverse (wf-manager-session-watched session)))
      (when (if (equal key wf-manager-overview-resource)
                (wf-manager--member-resource-p resource)
              (wf-manager--related-p key resource))
        (wf-manager--session-invalidate session key)))))

(defun wf-manager--session-invalidate (session key)
  "For SESSION, apply one invalidation of the resource KEY."
  (let ((step (wf-manager-refresh-invalidate key (wf-manager-session-refresh session))))
    (setf (wf-manager-session-refresh session) (wf-manager-refresh-step-state step))
    (wf-manager--session-perform session (wf-manager-refresh-step-actions step))))

(defun wf-manager--session-perform (session actions)
  "On SESSION, start the fetch of each `fetch' action of ACTIONS."
  (dolist (action actions)
    (when (eq (car action) 'fetch)
      (wf-manager--session-fetch session (nth 1 action) (nth 2 action)))))

(defun wf-manager--session-fetch (session key generation)
  "On SESSION, read the resource KEY for GENERATION."
  (if (equal key wf-manager-overview-resource)
      (wf-manager-session-load-overview
       session
       (lambda (outcome)
         (wf-manager--session-complete
          session key generation outcome
          (lambda () (setf (wf-manager-session-overview session) outcome)))))
    (wf-manager--session-get
     (wf-manager-session-connection session) key
     (lambda (outcome)
       (wf-manager--session-complete
        session key generation outcome
        (lambda () (puthash key outcome (wf-manager-session-installed session))))))))

(defun wf-manager--transient-read-p (outcome)
  "Return non-nil when OUTCOME is a refusal that a later read can clear."
  (member outcome '((wf-manager-refused 429 "storage-quota")
                    (wf-manager-refused 503 "storage-unavailable"))))

(defun wf-manager--session-complete (session key generation outcome install)
  "On SESSION, complete the read of KEY for GENERATION with OUTCOME.
INSTALL is a function that installs OUTCOME.  It runs only when the
refresh coordinator gives the action `install'.  A read of an earlier
generation installs nothing."
  (unless (wf-manager-session-closed session)
    (let ((step (wf-manager-refresh-complete key generation
                                             (wf-manager-session-refresh session))))
      (setf (wf-manager-session-refresh session) (wf-manager-refresh-step-state step))
      (when (assq 'install (wf-manager-refresh-step-actions step))
        (funcall install)
        (wf-manager--session-changed session)
        (when (wf-manager--transient-read-p outcome)
          (wf-manager--session-later
           session wf-manager--reread-seconds
           (lambda ()
             (when (and (eql generation (wf-manager-session-generation session))
                        (member key (wf-manager-session-watched session)))
               (wf-manager--session-invalidate session key))))))
      (wf-manager--session-perform session (wf-manager-refresh-step-actions step)))))

(defun wf-manager-session-watch (session reference)
  "On SESSION, watch the resource REFERENCE and return nil.
The session reads the resource now and again after each invalidation
that concerns it.  A REFERENCE of another endpoint signals
`wf-manager-wrong-endpoint', and a closed SESSION signals
`wf-manager-closed'."
  (let ((refusal (wf-manager--session-refusal
                  session (wf-manager-reference-endpoint reference)))
        (key (wf-manager-reference-uri reference)))
    (when refusal (signal (car refusal) (cdr refusal)))
    (unless (member key (wf-manager-session-watched session))
      (push key (wf-manager-session-watched session))
      (wf-manager--session-invalidate session key))
    nil))

(defun wf-manager-session-current (session reference)
  "On SESSION, return the last installed read of the watched REFERENCE.
The read is a `wf-manager-reply' or a failure, or nil before the first
read.  A REFERENCE of another endpoint gives the failure
`wf-manager-wrong-endpoint'."
  (if (equal (wf-manager-reference-endpoint reference)
             (wf-manager-session-identity session))
      (gethash (wf-manager-reference-uri reference)
               (wf-manager-session-installed session))
    (list 'wf-manager-wrong-endpoint "reference"
          "the reference names another endpoint")))

(defun wf-manager-session-switch (session profile callback)
  "Bind SESSION to the endpoint of the loaded PROFILE, and return nil.
This is `switchEndpoint' of `ext-pi/src/manager/session.ts'.  The new
binding reads its capabilities with `wf-manager-connect', receives a new
endpoint identity, and assembles its complete overview through its own
transport, with every member reference bound to the new identity.  Only
then does the switch commit: the generation advances, so each read in
flight installs nothing and each reference of the earlier binding gives
`wf-manager-wrong-endpoint'.  The watched resources become the overview
alone, the installed reads are cleared, the new overview is installed,
the earlier transport is closed, and the follow loop starts again from
the cursor of the new overview.  CALLBACK then runs one time with the
new overview.

A refused or failed connection, a transport that cannot open, a failed
overview read, a close and a commit of another switch before the
commit each close the new transport and keep the earlier binding, its
watched resources, its installed reads and its follow loop.  CALLBACK
then runs one time, after this function returns, with the failure: the
failure of the connection, of the transport or of the read, the failure
`wf-manager-closed' after a close, or the failure
`wf-manager-wrong-endpoint' after the commit of another switch.  A
switch sends no command."
  (if (wf-manager-session-closed session)
      (progn (run-at-time 0 nil callback
                          (list 'wf-manager-closed "session" "the session was closed"))
             nil)
    (let* ((earlier (wf-manager-session-connection session))
           (transport nil)
           (refusal
            (lambda ()
              (cond ((wf-manager-session-closed session)
                     (list 'wf-manager-closed "session" "the session was closed"))
                    ((not (eq earlier (wf-manager-session-connection session)))
                     (list 'wf-manager-wrong-endpoint "switch"
                           "another binding replaced the binding of the switch")))))
           (finish
            (lambda (outcome)
              (setf (wf-manager-session-switches session)
                    (delq transport (wf-manager-session-switches session)))
              (funcall callback outcome))))
      (condition-case failure
          (setq transport
                (wf-manager-exchange-transport
                 (wf-manager-connect
                  profile
                  (lambda (connection)
                    (if (wf-manager-failure-p connection)
                        (funcall finish connection)
                      (wf-manager--overview-load
                       connection refusal
                       (lambda (overview)
                         (let ((refused (funcall refusal)))
                           (cond
                            ((or refused (wf-manager-failure-p overview))
                             (wf-manager-transport-close
                              (wf-manager-connection-transport connection))
                             (funcall finish
                                      (if (and (wf-manager-failure-p overview)
                                               (not (wf-manager-session-closed session)))
                                          overview
                                        refused)))
                            (t
                             (wf-manager--session-commit session connection overview)
                             (funcall finish overview)))))))))))
        ;; The connect signals before it sends a request when the
        ;; transport cannot open.  The switch then ends after this
        ;; function returns, and it keeps the earlier binding.
        (wf-manager-error
         (run-at-time 0 nil finish failure)))
      (when transport
        (push transport (wf-manager-session-switches session)))
      nil)))

(defun wf-manager--session-commit (session connection overview)
  "Commit the endpoint switch of SESSION to CONNECTION with OVERVIEW.
The earlier connection and its pending timers end, and the follow loop
starts on CONNECTION from the cursor of OVERVIEW."
  (let ((earlier (wf-manager-session-connection session)))
    (setf (wf-manager-session-connection session) connection)
    (mapc #'cancel-timer (wf-manager-session-timers session))
    (setf (wf-manager-session-timers session) nil
          (wf-manager-session-refresh session)
          (wf-manager-refresh-advance (wf-manager-session-refresh session))
          (wf-manager-session-watched session) (list wf-manager-overview-resource)
          (wf-manager-session-installed session) (make-hash-table :test #'equal)
          (wf-manager-session-overview session) overview
          (wf-manager-session-delivery session) 'connecting
          (wf-manager-session-backoff session) wf-manager-initial-backoff
          (wf-manager-session-follow-end session) nil)
    (wf-manager-transport-close (wf-manager-connection-transport earlier))
    (wf-manager--session-follow session (wf-manager-overview-cursor overview) 0)
    (wf-manager--session-changed session)))

(defun wf-manager-session-close (session)
  "Close SESSION: cancel its timers and close its transports.
Each pending request of the session ends, the requests of an endpoint
switch in flight included, and no read installs after the close.  The
follow loop ends with `closed' when it has not ended before.  The close
sends no command, and the runs and requests of the manager do not
change."
  (unless (wf-manager-session-closed session)
    (setf (wf-manager-session-closed session) t)
    (mapc #'cancel-timer (wf-manager-session-timers session))
    (setf (wf-manager-session-timers session) nil)
    (wf-manager-transport-close (wf-manager-session-transport session))
    (mapc #'wf-manager-transport-close
          (copy-sequence (wf-manager-session-switches session)))
    (unless (wf-manager-session-follow-end session)
      (setf (wf-manager-session-follow-end session) (list 'closed nil)))
    (wf-manager--session-changed session)))

(provide 'wf-manager)

;;; wf-manager.el ends here
