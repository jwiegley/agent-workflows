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
;; Each refusal signals a condition below `wf-manager-error'.  The data of
;; the condition is (FIELD REASON).  For a profile, FIELD is the JSON name
;; of the profile field that the refusal is about, or "profile" for the
;; profile file itself.  For a response, FIELD names the kind of value,
;; such as "invalidation" or "route record".  REASON is a sentence for a
;; person.  The one exception is `wf-manager-refused', the refusal of a
;; problem response, whose data is (STATUS CODE).

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

(provide 'wf-manager)

;;; wf-manager.el ends here
