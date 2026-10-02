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
;; Each refusal signals a condition below `wf-manager-error'.  The data of
;; the condition is (FIELD REASON).  FIELD is the JSON name of the profile
;; field that the refusal is about, or "profile" for the profile file
;; itself.  REASON is a sentence for a person.

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

(defun wf-manager--utf-8 (field bytes)
  "Return for FIELD the BYTES decoded as UTF-8.
Bytes that are not UTF-8 signal `wf-manager-invalid-profile'."
  (let ((text (decode-coding-string bytes 'utf-8-unix t)))
    (when (cl-find-if (lambda (char) (eq (char-charset char) 'eight-bit)) text)
      (wf-manager--fail 'wf-manager-invalid-profile field "the file is not UTF-8"))
    text))

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
                   "profile"
                   (wf-manager--read-file "profile" file
                                          wf-manager-profile-file-bytes t))))
         (endpoint (wf-manager-parse-endpoint (cdr (assoc "endpoint" fields))))
         (ca-file (cdr (assoc "caFile" fields)))
         (credential-file (cdr (assoc "credentialFile" fields))))
    (wf-manager--check-certificates
     (wf-manager--utf-8
      "caFile" (wf-manager--read-file "caFile" ca-file
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

(provide 'wf-manager)

;;; wf-manager.el ends here
