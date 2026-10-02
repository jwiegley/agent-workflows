;;; wf-manager-tests.el --- ERT tests for wf-manager.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 John Wiegley

;; Author: John Wiegley <johnw@newartisans.com>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The fourth pass of `ci/emacs.sh'.  These tests load client profiles
;; from temporary files and check the rules of `wf-manager-profile-load':
;; the four fields, the endpoint, the absolute paths, the size bounds, the
;; private credential file and the typed refusals.  They check the exact
;; JSON codec: false, null and absent members, exact numbers, Unicode and
;; the byte bound.  They also run the invalidations, batches, routeRecords,
;; cursors, etags and problems vectors of the events section of
;; `test/manager_client_vectors.json' in agent-cat, which the environment
;; variable WF_MANAGER_VECTORS names.  A failure lists each vector that
;; does not give its stated result.  The tests start no process and contact
;; no host.
;;
;; Run them by hand, from the repository root:
;;
;;     WF_MANAGER_VECTORS=/path/to/agent-cat/test/manager_client_vectors.json \
;;       "$EMACS" -Q --batch -L ./emacs -l ./emacs/wf-manager-tests.el \
;;       -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'wf-manager)

(defconst wf-manager-tests--ca
  "-----BEGIN CERTIFICATE-----
MIIBjTCCATOgAwIBAgIUSUQSzJbJigxwa6nurBKkucIrG5wwCgYIKoZIzj0EAwIw
GzEZMBcGA1UEAwwQd2YtbWFuYWdlci10ZXN0czAgFw0yNjEwMDIwNjM1MTJaGA8y
MTI2MDkwODA2MzUxMlowGzEZMBcGA1UEAwwQd2YtbWFuYWdlci10ZXN0czBZMBMG
ByqGSM49AgEGCCqGSM49AwEHA0IABP1RdadHLtXrmR0a75AJDOfrSPdgnL01gYyO
HMmu7wuL3rBXR9NXVuYgOMTOOgIkuDKGOf748DIUvLU7Bu6TrlqjUzBRMB0GA1Ud
DgQWBBQcqEZkqpuCZ2bdAdgLyhGIKP4RSDAfBgNVHSMEGDAWgBQcqEZkqpuCZ2bd
AdgLyhGIKP4RSDAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIBqT
/+r4x/H3BGlccCa/D/PqXf1jWg66zTZQg9F++cx9AiEA0p9s5ebZYhLLHITpbEfb
Uoxoju8sJtVj//R245UuXiQ=
-----END CERTIFICATE-----
"
  "A self-signed test certificate, the CA file of the fixtures.")

(defconst wf-manager-tests--credential
  "wfm-test-credential-0123456789abcdefghijklmn"
  "The credential of the fixtures, 44 visible ASCII bytes.")

(defun wf-manager-tests--write (file bytes mode)
  "Write to FILE the BYTES, without conversion, and give FILE the MODE."
  (let ((coding-system-for-write 'no-conversion))
    (write-region bytes nil file nil 'silent))
  (set-file-modes file mode)
  file)

(defun wf-manager-tests--fields (dir)
  "Return the fields of a valid profile whose files are in DIR."
  `((version . 1)
    (endpoint . "https://127.0.0.1:8443/v1")
    (credentialFile . ,(expand-file-name "credential" dir))
    (caFile . ,(expand-file-name "ca.pem" dir))))

(defun wf-manager-tests--profile (dir &optional fields)
  "Write to DIR a profile with FIELDS and return its path.
FIELDS is an alist for `json-serialize'.  When FIELDS is a string, it
is the text of the profile.  The default is the valid profile of
`wf-manager-tests--fields'."
  (wf-manager-tests--write
   (expand-file-name "profile.json" dir)
   (if (stringp fields)
       fields
     (json-serialize (or fields (wf-manager-tests--fields dir))))
   #o600))

(defun wf-manager-tests--call (function)
  "Call FUNCTION with a fixture directory that has a CA and a credential.
The directory is removed after FUNCTION returns or signals."
  (let ((dir (make-temp-file "wf-manager-tests" t)))
    (unwind-protect
        (progn
          (wf-manager-tests--write (expand-file-name "ca.pem" dir)
                                   wf-manager-tests--ca #o644)
          (wf-manager-tests--write (expand-file-name "credential" dir)
                                   wf-manager-tests--credential #o600)
          (funcall function dir))
      (delete-directory dir t))))

(defun wf-manager-tests--refusal (path)
  "Return the condition symbol and field of the refusal of the profile PATH.
Return the symbol `loaded' when the profile loads."
  (condition-case failure
      (progn (wf-manager-profile-load path) 'loaded)
    (wf-manager-error (list (car failure) (nth 1 failure)))))

(defun wf-manager-tests--with-field (dir name value)
  "Return the valid fields of DIR with the field NAME set to VALUE."
  (cons (cons name value)
        (assq-delete-all name (wf-manager-tests--fields dir))))

(ert-deftest wf-manager-profile-loads ()
  "Load a valid profile with its endpoint, CA path and credential."
  (wf-manager-tests--call
   (lambda (dir)
     (let* ((profile (wf-manager-profile-load (wf-manager-tests--profile dir)))
            (endpoint (wf-manager-profile-endpoint profile)))
       (should (equal (wf-manager-endpoint-url endpoint) "https://127.0.0.1:8443/v1"))
       (should (equal (wf-manager-endpoint-host endpoint) "127.0.0.1"))
       (should (equal (wf-manager-endpoint-port endpoint) 8443))
       (should (equal (wf-manager-endpoint-base endpoint) "/v1"))
       (should (equal (wf-manager-profile-ca-file profile)
                      (expand-file-name "ca.pem" dir)))
       (should (equal (wf-manager-profile-credential-file profile)
                      (expand-file-name "credential" dir)))
       (should (= (length (wf-manager-profile-credential profile))
                  (length wf-manager-tests--credential)))
       (should (equal (wf-manager-authorization profile)
                      (cons "Authorization"
                            (concat "Bearer " wf-manager-tests--credential))))))))

(ert-deftest wf-manager-profile-endpoint-forms ()
  "Accept an IPv6 host, the default port, a trailing slash and a name."
  (should (equal (wf-manager-endpoint-host (wf-manager-parse-endpoint "https://[::1]/v1/"))
                 "::1"))
  (should (equal (wf-manager-endpoint-port (wf-manager-parse-endpoint "https://[::1]/v1/"))
                 443))
  (should (equal (wf-manager-endpoint-host
                  (wf-manager-parse-endpoint "https://Manager.Example:9443/v1"))
                 "manager.example")))

(ert-deftest wf-manager-profile-refuses-fields ()
  "Refuse an extra, missing, repeated or wrongly typed field by its name."
  (wf-manager-tests--call
   (lambda (dir)
     (let ((fields (wf-manager-tests--fields dir)))
       (should (equal (wf-manager-tests--refusal
                       (wf-manager-tests--profile dir (cons '(extra . "x") fields)))
                      '(wf-manager-invalid-profile "extra")))
       (should (equal (wf-manager-tests--refusal
                       (wf-manager-tests--profile dir (assq-delete-all 'caFile (copy-sequence fields))))
                      '(wf-manager-invalid-profile "caFile")))
       (should (equal (wf-manager-tests--refusal
                       (wf-manager-tests--profile
                        dir (concat "{\"version\":1,\"version\":1,"
                                    (substring (json-serialize (cdr fields)) 1))))
                      '(wf-manager-invalid-profile "version")))
       (dolist (version '(2 "1" 1.0))
         (should (equal (wf-manager-tests--refusal
                         (wf-manager-tests--profile
                          dir (wf-manager-tests--with-field dir 'version version)))
                        '(wf-manager-invalid-profile "version"))))
       (should (equal (wf-manager-tests--refusal
                       (wf-manager-tests--profile
                        dir (wf-manager-tests--with-field dir 'endpoint 7)))
                      '(wf-manager-invalid-profile "endpoint")))
       (dolist (text '("{" "[]" "\"profile\"" "{}"))
         (should (memq (car (wf-manager-tests--refusal (wf-manager-tests--profile dir text)))
                       '(wf-manager-invalid-profile))))
       (should (equal (wf-manager-tests--refusal
                       (wf-manager-tests--profile dir (concat "{\"endpoint\":\"\377\"}")))
                      '(wf-manager-invalid-profile "profile")))))))

(ert-deftest wf-manager-profile-refuses-endpoints ()
  "Refuse an endpoint that is not https, not /v1 or has a user, query or fragment."
  (wf-manager-tests--call
   (lambda (dir)
     (dolist (endpoint '("http://127.0.0.1:8443/v1"
                         "HTTPS://127.0.0.1/v1"
                         "https://127.0.0.1:8443/v2"
                         "https://127.0.0.1:8443/v1/runs"
                         "https://127.0.0.1:8443/"
                         "https://127.0.0.1:8443"
                         "https://user@127.0.0.1:8443/v1"
                         "https://user:secret@127.0.0.1:8443/v1"
                         "https://127.0.0.1:8443/v1?limit=1"
                         "https://127.0.0.1:8443/v1#top"
                         "https://127.0.0.1:99999/v1"
                         "https://127.0.0.1:0/v1"
                         "https://127.0.0.1:port/v1"
                         "https:///v1"
                         "https://local host/v1"
                         "https://[::1/v1"))
       (should (equal (wf-manager-tests--refusal
                       (wf-manager-tests--profile
                        dir (wf-manager-tests--with-field dir 'endpoint endpoint)))
                      '(wf-manager-invalid-endpoint "endpoint")))))))

(ert-deftest wf-manager-profile-refuses-relative-paths ()
  "Refuse a relative profile, credential or CA path by its field."
  (wf-manager-tests--call
   (lambda (dir)
     (should (equal (wf-manager-tests--refusal "profile.json")
                    '(wf-manager-invalid-profile "profile")))
     (should (equal (wf-manager-tests--refusal
                     (wf-manager-tests--profile
                      dir (wf-manager-tests--with-field dir 'credentialFile "credential")))
                    '(wf-manager-invalid-profile "credentialFile")))
     (should (equal (wf-manager-tests--refusal
                     (wf-manager-tests--profile
                      dir (wf-manager-tests--with-field dir 'caFile "~/ca.pem")))
                    '(wf-manager-invalid-profile "caFile")))
     (should (equal (wf-manager-tests--refusal
                     (wf-manager-tests--profile
                      dir (wf-manager-tests--with-field
                           dir 'caFile (concat dir "/ca\n.pem"))))
                    '(wf-manager-invalid-profile "caFile"))))))

(ert-deftest wf-manager-profile-refuses-oversized-files ()
  "Refuse a profile or CA file above its bound and accept one at the bound."
  (wf-manager-tests--call
   (lambda (dir)
     (let* ((text (json-serialize (wf-manager-tests--fields dir)))
            (pad (lambda (size) (concat text (make-string (- size (length text)) ?\s)))))
       (should (eq (wf-manager-tests--refusal
                    (wf-manager-tests--profile dir (funcall pad wf-manager-profile-file-bytes)))
                   'loaded))
       (should (equal (wf-manager-tests--refusal
                       (wf-manager-tests--profile dir (funcall pad (1+ wf-manager-profile-file-bytes))))
                      '(wf-manager-file-unavailable "profile")))
       (let ((ca (expand-file-name "ca.pem" dir))
             (profile (wf-manager-tests--profile dir)))
         (wf-manager-tests--write
          ca (concat wf-manager-tests--ca
                     (make-string (- (1+ wf-manager-ca-file-bytes)
                                     (length wf-manager-tests--ca))
                                  ?\n))
          #o644)
         (should (equal (wf-manager-tests--refusal profile)
                        '(wf-manager-file-unavailable "caFile"))))))))

(ert-deftest wf-manager-profile-refuses-files ()
  "Refuse a shared profile, a missing or writable CA and a CA without certificates."
  (wf-manager-tests--call
   (lambda (dir)
     (let ((profile (wf-manager-tests--profile dir))
           (ca (expand-file-name "ca.pem" dir)))
       (set-file-modes profile #o644)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-file-unavailable "profile")))
       (set-file-modes profile #o600)
       (set-file-modes ca #o664)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-file-unavailable "caFile")))
       (wf-manager-tests--write ca "no certificate here\n" #o644)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-invalid-profile "caFile")))
       (wf-manager-tests--write
        ca "-----BEGIN CERTIFICATE-----\n!!!!\n-----END CERTIFICATE-----\n" #o644)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-invalid-profile "caFile")))
       (delete-file ca)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-file-unavailable "caFile")))))))

(ert-deftest wf-manager-credential-file-rules ()
  "Refuse a credential file that is shared, not regular, linked or of the wrong size."
  (wf-manager-tests--call
   (lambda (dir)
     (let ((profile (wf-manager-tests--profile dir))
           (credential (expand-file-name "credential" dir))
           (other (expand-file-name "other" dir)))
       (dolist (mode '(#o644 #o640 #o604 #o660))
         (set-file-modes credential mode)
         (should (equal (wf-manager-tests--refusal profile)
                        '(wf-manager-file-unavailable "credentialFile"))))
       (set-file-modes credential #o400)
       (should (eq (wf-manager-tests--refusal profile) 'loaded))
       (set-file-modes credential #o600)
       (add-name-to-file credential other)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-file-unavailable "credentialFile")))
       (delete-file other)
       (rename-file credential other)
       (make-symbolic-link other credential)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-file-unavailable "credentialFile")))
       (delete-file credential)
       (make-directory credential)
       (set-file-modes credential #o700)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-file-unavailable "credentialFile")))
       (delete-directory credential)
       (dolist (case `((,(make-string 31 ?k) wf-manager-credential-unavailable)
                       (,(make-string 32 ?k) loaded)
                       (,(make-string 512 ?k) loaded)
                       (,(make-string 513 ?k) wf-manager-file-unavailable)
                       (,(concat wf-manager-tests--credential "\n")
                        wf-manager-credential-unavailable)
                       (,(concat wf-manager-tests--credential ",x")
                        wf-manager-credential-unavailable)
                       (,(concat wf-manager-tests--credential " x")
                        wf-manager-credential-unavailable)))
         (wf-manager-tests--write credential (car case) #o600)
         (should (equal (wf-manager-tests--refusal profile)
                        (if (eq (cadr case) 'loaded)
                            'loaded
                          (list (cadr case) "credentialFile")))))
       (delete-file credential)
       (should (equal (wf-manager-tests--refusal profile)
                      '(wf-manager-file-unavailable "credentialFile")))))))

;;;; Exact JSON codec

(defun wf-manager-tests--refusal-of (function &rest arguments)
  "Return the condition symbol of the refusal of FUNCTION with ARGUMENTS.
Return the symbol `accepted' when FUNCTION returns."
  (condition-case failure
      (progn (apply function arguments) 'accepted)
    (wf-manager-error (car failure))))

(ert-deftest wf-manager-json-false-null-absent ()
  "Keep JSON false, JSON null and an absent member distinct, and their bytes."
  (let* ((text "{\"a\":false,\"b\":null,\"c\":[false,null,true],\"d\":{}}")
         (value (wf-manager-json-decode text)))
    (should (eq (gethash "a" value) :false))
    (should (eq (gethash "b" value) :null))
    (should (null (gethash "e" value)))
    (should (equal (gethash "c" value) [:false :null t]))
    (should (hash-table-p (gethash "d" value)))
    (should-not (wf-manager-json-equal :false :null))
    (should-not (wf-manager-json-equal (wf-manager-json-decode "{\"a\":1}")
                                       (wf-manager-json-decode "{\"a\":1,\"b\":null}")))
    (should (equal (wf-manager-json-encode value) text))
    (should (equal (wf-manager-json-encode :false) "false"))
    (should (equal (wf-manager-json-encode :null) "null"))))

(ert-deftest wf-manager-json-exact-numbers ()
  "Keep each number exact and compare numbers by decimal value."
  (let ((text "[9007199254740993,18446744073709551615,1.0,10e-1,-0,1e400,123456789012345678901234567890]"))
    (should (equal (wf-manager-json-encode (wf-manager-json-decode text)) text)))
  (should (wf-manager-json-equal (wf-manager-json-decode "[1,0,1e400]")
                                 (wf-manager-json-decode "[1.0,-0,10e399]")))
  (should-not (wf-manager-json-equal (wf-manager-json-decode "9007199254740993")
                                     (wf-manager-json-decode "9007199254740992")))
  (should (wf-manager-json-equal (wf-manager-json-decode "{\"a\":1,\"b\":[true]}")
                                 (wf-manager-json-decode "{\"b\":[true],\"a\":1.0}")))
  (should (equal (wf-manager-json-encode (wf-manager-json-integer 18446744073709551615))
                 "18446744073709551615"))
  (should (equal (wf-manager-json-encode (wf-manager-json-decode "{\"b\":1,\"a\":2}"))
                 "{\"a\":2,\"b\":1}")))

(ert-deftest wf-manager-json-unicode ()
  "Keep Unicode text from UTF-8 bytes and from multibyte text."
  (let* ((bytes (encode-coding-string "[\"h\u00e9llo \u2713 \U0001D11E\",\"\\u00e9\"]" 'utf-8))
         (value (wf-manager-json-decode bytes)))
    (should (equal (aref value 0) "h\u00e9llo \u2713 \U0001D11E"))
    (should (equal (aref value 1) "\u00e9"))
    (should (equal (wf-manager-json-encode value)
                   (encode-coding-string "[\"h\u00e9llo \u2713 \U0001D11E\",\"\u00e9\"]"
                                         'utf-8))))
  (should (equal (wf-manager-json-decode "\"\\ud834\\udd1e\"") "\U0001D11E")))

(ert-deftest wf-manager-json-byte-bound ()
  "Refuse text over the byte bound before parsing it, and parse text at the bound."
  (should (eq (wf-manager-tests--refusal-of #'wf-manager-json-decode "[1,2]" 4)
              'wf-manager-response-too-large))
  (should (eq (wf-manager-tests--refusal-of #'wf-manager-json-decode "[1,2]" 5) 'accepted))
  (should (eq (wf-manager-tests--refusal-of #'wf-manager-json-decode "\"\u00e9\"" 3)
              'wf-manager-response-too-large))
  (should (eq (wf-manager-tests--refusal-of #'wf-manager-json-decode "\"\u00e9\"" 4) 'accepted))
  ;; Text that is not JSON shows that the bound comes before the parser.
  (should (eq (wf-manager-tests--refusal-of #'wf-manager-json-decode "{{{{{" 4)
              'wf-manager-response-too-large))
  (should (eq (wf-manager-tests--refusal-of
               #'wf-manager-json-decode
               (concat "\"" (make-string (- wf-manager-response-bytes 1) ?x) "\""))
              'wf-manager-response-too-large))
  (should (eq (wf-manager-tests--refusal-of
               #'wf-manager-json-decode
               (concat "\"" (make-string (- wf-manager-response-bytes 2) ?x) "\""))
              'accepted)))

(ert-deftest wf-manager-json-refuses-text ()
  "Refuse text that is not one JSON value in UTF-8."
  (dolist (text (list "{\"a\":1,}" "1 2" "{1:2}" "\"abc" "\"a\\" "01" "-" "1." "[1e]"
                      "[.5]" "{\"a\" 1}" "tru" "" "\"\\x\""
                      (string-to-unibyte "\"\377\"")))
    (should (equal (list text (wf-manager-tests--refusal-of #'wf-manager-json-decode text))
                   (list text 'wf-manager-invalid-response)))))

;;;; Event vectors

(defconst wf-manager-tests--vector-counts
  '(("invalidations" . 16) ("batches" . 13) ("routeRecords" . 17)
    ("cursors" . 16) ("etags" . 6) ("problems" . 10))
  "The number of cases of each events subsection of the vector file.
A change to the vector file changes these counts.")

(defvar wf-manager-tests--vectors nil
  "The decoded vector file, read once.")

(defun wf-manager-tests--vectors ()
  "Return the decoded vector file that WF_MANAGER_VECTORS names."
  (or wf-manager-tests--vectors
      (let ((file (getenv "WF_MANAGER_VECTORS")))
        (unless (and file (file-readable-p file))
          (error "Set $WF_MANAGER_VECTORS to test/manager_client_vectors.json of agent-cat"))
        (setq wf-manager-tests--vectors
              (with-temp-buffer
                (set-buffer-multibyte nil)
                (insert-file-contents-literally file)
                (wf-manager-json-decode (buffer-string)))))))

(defun wf-manager-tests--cases (section)
  "Return the cases of the events SECTION as a list, with their stated count."
  (let ((cases (append (gethash section (gethash "events" (wf-manager-tests--vectors)))
                       nil)))
    (should (equal (cons section (length cases))
                   (assoc section wf-manager-tests--vector-counts)))
    cases))

(defun wf-manager-tests--label (section vector)
  "Return the label for a failure report of SECTION and its VECTOR."
  (format "%s: %s" section
          (or (gethash "name" vector) (gethash "cursor" vector)
              (wf-manager-json-encode vector))))

(defun wf-manager-tests--json-vector-passes (vector decode encode)
  "Return non-nil when VECTOR gives its stated result with DECODE and ENCODE.
A valid case decodes and encodes back to an equal value.  An invalid
case refuses with `wf-manager-invalid-response'."
  (let* ((value (wf-manager-json-decode (gethash "json" vector)))
         (valid (eq (gethash "valid" vector) t))
         (decoded (condition-case nil
                      (list (funcall decode value))
                    (wf-manager-invalid-response 'refused))))
    (if (eq decoded 'refused)
        (not valid)
      (and valid (wf-manager-json-equal (funcall encode (car decoded)) value)))))

(defun wf-manager-tests--wrong (section passes)
  "Return the labels of the cases of SECTION for which PASSES gives nil."
  (let ((wrong nil))
    (dolist (vector (wf-manager-tests--cases section))
      (unless (funcall passes vector)
        (push (wf-manager-tests--label section vector) wrong)))
    (nreverse wrong)))

(ert-deftest wf-manager-vectors-invalidations ()
  "Decode and re-encode every invalidation vector as it states."
  (should (equal (wf-manager-tests--wrong
                  "invalidations"
                  (lambda (vector)
                    (wf-manager-tests--json-vector-passes
                     vector #'wf-manager-decode-invalidation
                     #'wf-manager-encode-invalidation)))
                 nil)))

(ert-deftest wf-manager-vectors-batches ()
  "Decode and re-encode every event batch vector as it states."
  (should (equal (wf-manager-tests--wrong
                  "batches"
                  (lambda (vector)
                    (wf-manager-tests--json-vector-passes
                     vector #'wf-manager-decode-event-batch
                     #'wf-manager-encode-event-batch)))
                 nil)))

(ert-deftest wf-manager-vectors-route-records ()
  "Decode and re-encode every route record vector as it states."
  (should (equal (wf-manager-tests--wrong
                  "routeRecords"
                  (lambda (vector)
                    (wf-manager-tests--json-vector-passes
                     vector #'wf-manager-decode-route-record
                     #'wf-manager-encode-route-record)))
                 nil)))

(ert-deftest wf-manager-vectors-route-record-body ()
  "Keep false, null, large numbers and Unicode of an inline body, and its bytes."
  (let* ((vector (car (wf-manager-tests--cases "routeRecords")))
         (value (wf-manager-json-decode (gethash "json" vector)))
         (record (wf-manager-decode-route-record value))
         (body (cadr (wf-manager-route-record-payload record))))
    (should (eq (car (wf-manager-route-record-payload record)) 'body))
    (should (equal (wf-manager-json-encode (wf-manager-encode-route-record record))
                   (wf-manager-json-encode value)))
    (should (equal (gethash "text" body) "h\u00e9llo \u2713 \U0001D11E"))
    (should (eq (gethash "flag" body) :false))
    (should (eq (gethash "none" body) :null))
    (should (equal (wf-manager-json-number-source (gethash "big" body))
                   "123456789012345678901234567890"))
    (should (equal (wf-manager-json-number-source (gethash "huge" body)) "1e400"))
    (should (equal (wf-manager-json-encode (gethash "nested" body))
                   "{\"list\":[false,null,0]}"))))

(ert-deftest wf-manager-vectors-cursors ()
  "Check the syntax of every cursor vector."
  (should (equal (wf-manager-tests--wrong
                  "cursors"
                  (lambda (vector)
                    (eq (and (wf-manager-valid-cursor-p (gethash "cursor" vector)) t)
                        (eq (gethash "valid" vector) t))))
                 nil)))

(ert-deftest wf-manager-vectors-etags ()
  "Check the syntax and the text equality of every entity tag vector."
  (should (equal (wf-manager-tests--wrong
                  "etags"
                  (lambda (vector)
                    (let ((a (gethash "a" vector))
                          (b (gethash "b" vector))
                          (valid (gethash "valid" vector)))
                      (equal (list (and (wf-manager-valid-etag-p a) t)
                                   (and (wf-manager-valid-etag-p b) t)
                                   (and (wf-manager-etag-equal a b) t))
                             (list (eq (aref valid 0) t) (eq (aref valid 1) t)
                                   (eq (gethash "equal" vector) t))))))
                 nil))
  (should-not (wf-manager-etag-equal "\"10\"" "\"010\"")))

(ert-deftest wf-manager-vectors-problems ()
  "Map every problem vector to its stated failure."
  (should (equal (wf-manager-tests--wrong
                  "problems"
                  (lambda (vector)
                    (let* ((status (wf-manager--bounded-integer
                                    (gethash "status" vector) 100 599))
                           (stated (gethash "expected" vector))
                           (failure (wf-manager-problem-failure
                                     status (gethash "body" vector))))
                      (if (equal stated "InvalidResponse")
                          (eq (car failure) 'wf-manager-invalid-response)
                        (let ((refused (gethash "refused" stated)))
                          (equal failure
                                 (list 'wf-manager-refused
                                       (wf-manager--bounded-integer (aref refused 0) 100 599)
                                       (aref refused 1))))))))
                 nil)))

(provide 'wf-manager-tests)

;;; wf-manager-tests.el ends here
