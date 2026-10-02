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
;; The resource decoders follow the draft, preparation, receipt and
;; decision decoders of `ext-pi/src/manager/resources.ts' and pass the
;; drafts, requests, preparations, receipts and decisions vectors of the
;; resources section: requests, readiness, declared and supplied inputs,
;; input errors, preparations, reviews, review inputs, lineages, edits,
;; command receipts, decisions and the request, preparation and decision
;; members of the overview.  Each decoder returns a record.  The encoder of
;; a record gives its canonical JSON value, and
;; `wf-manager-decision-projection' gives the projection of a decision.  A
;; command receipt is valid only when its state agrees with its dispatch
;; attempt time, its acknowledgement, its effect and its refusal.
;;
;; `wf-manager-answer-value' builds the typed answer of a decision from the
;; text of a person, and `wf-manager-answer-body' builds the answer body
;; from that answer.  The answer "no" to a flag question is JSON false.  A
;; structured answer must agree with the editor schema of its decision.
;; The builder passes the answers vectors of the resources section, and it
;; refuses an answer with `wf-manager-invalid-answer' before any command is
;; built.
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
KIND is \"request\", \"preparation\" or \"decision\".  VALUE is a
`wf-manager-draft', a `wf-manager-preparation' or a `wf-manager-decision'."
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
         (address (wf-manager--exact (gethash "address" fields) '("occurrenceId")))
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
     :occurrence-id (wf-manager--word64-text (gethash "occurrenceId" address))
     :state (wf-manager--choice (gethash "state" fields) wf-manager-decision-states)
     :position (wf-manager--integer (gethash "position" fields) 0 2047)
     :observed-sequence (wf-manager--word64-text (gethash "observedSequence" fields))
     :content (if (equal kind "question")
                  (wf-manager--parse-question (gethash "question" fields))
                (wf-manager--parse-recovery fields))
     :value value)))

;;;;; Overview members

(defconst wf-manager--overview-kinds
  '(("request" wf-manager--parse-draft wf-manager-encode-draft)
    ("preparation" wf-manager--parse-preparation wf-manager-encode-preparation)
    ("decision" wf-manager--parse-decision wf-manager-decision-projection))
  "The overview member kinds that this client decodes.
Each entry is (KIND PARSER ENCODER).  The encoder of a decision gives
its projection.  The manager also serves the kind \"run\", which this
client refuses until it has its decoder.")

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
        "choices" (wf-manager--json-list
                   (lambda (option)
                     (wf-manager-json-object
                      "choice" (wf-manager-recovery-option-choice option)
                      "target" (wf-manager--json-nullable
                                (wf-manager-recovery-option-target option))))
                   (wf-manager-recovery-choices content)))))))

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

(provide 'wf-manager)

;;; wf-manager.el ends here
