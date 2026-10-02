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
;; cursors, etags and problems vectors of the events section and the
;; drafts, requests, preparations, receipts, decisions, answers, controls
;; and runs vectors of the resources section and the sequences, backoff,
;; jitter and reconciliation vectors of the refresh section of
;; `test/manager_client_vectors.json' in agent-cat, which the environment variable WF_MANAGER_VECTORS names.  A
;; failure names each vector that does not give its stated result.
;;
;; The transport tests start a plain HTTP listener on 127.0.0.1 in the
;; same Emacs with `make-network-process'.  The listener keeps the exact
;; bytes of each request and answers with canned responses.  The tests
;; check the exact header set, the exact UTF-8 bytes of a command body
;; with non-ASCII text, a 401 refusal with no prompt, a 412
;; problem, a refused redirect, an oversized body cut at its bound,
;; cancellation, the cleanup of processes and buffers on cancel and on
;; close, a timer that runs while a response is pending, the polling
;; batch and the capability binding.  The session tests answer by
;; request target, and they can hold a request open to order two reads.
;; They check the overview over two pages, its restart after a 410
;; view-expired page and the bound of those restarts, the resnapshot
;; after a 410 cursor refusal, a read of the earlier generation that
;; installs nothing, and one later read for the invalidations during one
;; read, the endpoint switch and its failures, and the close of a
;; session with a switch in flight.  For a server certificate that the
;; CA file of the profile does not verify, a request, a connect and a
;; switch contact a TLS server on 127.0.0.1 that a python3 process from
;; PATH runs.  The capability checks follow
;; checkCapabilities of `ext-pi/src/manager/session.ts' over the canned
;; capabilities document of the ext-pi tests.  No other host is
;; contacted.
;;
;; Run them by hand, from the repository root:
;;
;;     WF_MANAGER_VECTORS=/path/to/agent-cat/test/manager_client_vectors.json \
;;       "$EMACS" -Q --batch -L ./emacs -l ./emacs/wf-manager-tests.el \
;;       -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
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
  '(("events.invalidations" . 16) ("events.batches" . 13)
    ("events.routeRecords" . 17) ("events.cursors" . 16) ("events.etags" . 6)
    ("events.problems" . 10) ("resources.drafts" . 39)
    ("resources.requests" . 11) ("resources.preparations" . 40)
    ("resources.receipts" . 36) ("resources.decisions" . 20)
    ("resources.answers" . 22) ("resources.controls" . 16)
    ("resources.runs" . 24))
  "The number of cases of each subsection of the vector file that runs here.
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
  "Return the cases of SECTION as a list, with their stated count.
SECTION is the dotted path of a subsection, such as \"events.batches\"."
  (let ((cases (append (cl-reduce (lambda (object name) (gethash name object))
                                  (split-string section "\\.")
                                  :initial-value (wf-manager-tests--vectors))
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
                  "events.invalidations"
                  (lambda (vector)
                    (wf-manager-tests--json-vector-passes
                     vector #'wf-manager-decode-invalidation
                     #'wf-manager-encode-invalidation)))
                 nil)))

(ert-deftest wf-manager-vectors-batches ()
  "Decode and re-encode every event batch vector as it states."
  (should (equal (wf-manager-tests--wrong
                  "events.batches"
                  (lambda (vector)
                    (wf-manager-tests--json-vector-passes
                     vector #'wf-manager-decode-event-batch
                     #'wf-manager-encode-event-batch)))
                 nil)))

(ert-deftest wf-manager-vectors-route-records ()
  "Decode and re-encode every route record vector as it states."
  (should (equal (wf-manager-tests--wrong
                  "events.routeRecords"
                  (lambda (vector)
                    (wf-manager-tests--json-vector-passes
                     vector #'wf-manager-decode-route-record
                     #'wf-manager-encode-route-record)))
                 nil)))

(ert-deftest wf-manager-vectors-route-record-body ()
  "Keep false, null, large numbers and Unicode of an inline body, and its bytes."
  (let* ((vector (car (wf-manager-tests--cases "events.routeRecords")))
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
                  "events.cursors"
                  (lambda (vector)
                    (eq (and (wf-manager-valid-cursor-p (gethash "cursor" vector)) t)
                        (eq (gethash "valid" vector) t))))
                 nil)))

(ert-deftest wf-manager-vectors-etags ()
  "Check the syntax and the text equality of every entity tag vector."
  (should (equal (wf-manager-tests--wrong
                  "events.etags"
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
                  "events.problems"
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

;;;; Resource vectors

(defconst wf-manager-tests--resource-outcomes
  '(("resources.drafts" 12 27) ("resources.requests" 4 7)
    ("resources.preparations" 13 27) ("resources.receipts" 19 17)
    ("resources.decisions" 6 14) ("resources.answers" 12 10)
    ("resources.controls" 3 13) ("resources.runs" 6 18))
  "The number of projections and of refusals that each section states.")

(defconst wf-manager-tests--typed-decoders
  '(("resources.drafts"
     ("DraftView" wf-manager-decode-draft wf-manager-encode-draft)
     ("Readiness" wf-manager-decode-readiness wf-manager-encode-readiness)
     ("InputDeclaration" wf-manager-decode-input-declaration
      wf-manager-encode-input-declaration)
     ("SuppliedInput" wf-manager-decode-supplied-input
      wf-manager-encode-supplied-input)
     ("InputError" wf-manager-decode-input-error wf-manager-encode-input-error))
    ("resources.preparations"
     ("Preparation" wf-manager-decode-preparation wf-manager-encode-preparation)
     ("Review" wf-manager-decode-review wf-manager-encode-review)
     ("ReviewInput" wf-manager-decode-review-input wf-manager-encode-review-input)
     ("ReviewLineage" wf-manager-decode-review-lineage
      wf-manager-encode-review-lineage)
     ("ReviewEdit" wf-manager-decode-review-edit wf-manager-encode-review-edit))
    ("resources.requests"
     ("item" wf-manager-decode-draft wf-manager-encode-draft)
     ("overview" wf-manager-decode-overview-member
      wf-manager-encode-overview-member))
    ("resources.receipts"
     ("CommandReceipt" wf-manager-decode-command-receipt
      wf-manager-encode-command-receipt))
    ("resources.decisions"
     ("item" wf-manager-tests--decode-decision wf-manager-decision-projection)
     ("overview" wf-manager-decode-overview-member
      wf-manager-encode-overview-member))
    ("resources.controls"
     (nil wf-manager-tests--decode-control wf-manager-control-projection))
    ("resources.runs"
     ("item" wf-manager-decode-run wf-manager-run-projection)
     ("overview" wf-manager-decode-overview-member
      wf-manager-encode-overview-member)))
  "The decoder and encoder of each case of a resources section.
A case names its decoder by its `type' member, or for the requests,
decisions and runs sections by its `from' member.  A case of the
controls section names no decoder, and the entry nil applies to it.")

(defun wf-manager-tests--decode-decision (value)
  "Return the decision of the JSON VALUE, and check that VALUE stays in it."
  (let ((decision (wf-manager-decode-decision value)))
    (should (eq (wf-manager-decision-value decision) value))
    decision))

(defun wf-manager-tests--decode-control (value)
  "Return the controls of the JSON VALUE, and check that VALUE stays in them."
  (let ((control (wf-manager-decode-control value)))
    (should (eq (wf-manager-control-value control) value))
    control))

(defun wf-manager-tests--resource-outcome (section vector)
  "In SECTION, return the outcome of the resource VECTOR.
The outcome is (projected TEXT) with the JSON text of the encoded
record, or the symbol `refused' for `wf-manager-invalid-response'."
  (let* ((selector (or (gethash "type" vector) (gethash "from" vector)))
         (entry (or (assoc selector (cdr (assoc section wf-manager-tests--typed-decoders)))
                    (error "%s names no decoder of its section"
                           (wf-manager-tests--label section vector))))
         (value (wf-manager-json-decode (gethash "json" vector))))
    (condition-case nil
        (list 'projected
              (wf-manager-json-encode
               (funcall (nth 2 entry) (funcall (nth 1 entry) value))))
      (wf-manager-invalid-response 'refused))))

(defun wf-manager-tests--resource-stated (section vector)
  "In SECTION, return the outcome that the resource VECTOR states.
The outcome is (projected TEXT) with the JSON text of the projection, or
the symbol `refused' for the refusal InvalidResponse."
  (let ((projection (gethash "projection" vector))
        (refusal (gethash "refusal" vector)))
    (cond
     ((and (stringp projection) (null refusal))
      (list 'projected (wf-manager-json-encode (wf-manager-json-decode projection))))
     ((and (null projection) (equal refusal "InvalidResponse")) 'refused)
     (t (error "%s states neither one projection nor one refusal"
               (wf-manager-tests--label section vector))))))

(defun wf-manager-tests--resource-section (section)
  "Check every case of the resources SECTION and return its tally.
A case that does not give its stated outcome fails the test with its
label.  The tally is (SECTION PROJECTED REFUSED)."
  (let ((projected 0) (refused 0))
    (dolist (vector (wf-manager-tests--cases section))
      (let ((outcome (wf-manager-tests--resource-outcome section vector)))
        (should (equal (cons (wf-manager-tests--label section vector) outcome)
                       (cons (wf-manager-tests--label section vector)
                             (wf-manager-tests--resource-stated section vector))))
        (if (eq outcome 'refused)
            (setq refused (1+ refused))
          (setq projected (1+ projected)))))
    (list section projected refused)))

(ert-deftest wf-manager-vectors-drafts ()
  "Decode every request, readiness and input vector to its projection or refusal."
  (should (equal (wf-manager-tests--resource-section "resources.drafts")
                 (assoc "resources.drafts" wf-manager-tests--resource-outcomes))))

(ert-deftest wf-manager-vectors-requests ()
  "Decode every request item and overview member vector to its projection or refusal."
  (should (equal (wf-manager-tests--resource-section "resources.requests")
                 (assoc "resources.requests" wf-manager-tests--resource-outcomes))))

(ert-deftest wf-manager-vectors-preparations ()
  "Decode every preparation, review, input, lineage and edit vector as it states."
  (should (equal (wf-manager-tests--resource-section "resources.preparations")
                 (assoc "resources.preparations" wf-manager-tests--resource-outcomes))))

(ert-deftest wf-manager-vectors-receipts ()
  "Decode every command receipt vector to its projection or refusal."
  (should (equal (wf-manager-tests--resource-section "resources.receipts")
                 (assoc "resources.receipts" wf-manager-tests--resource-outcomes))))

(ert-deftest wf-manager-vectors-decisions ()
  "Decode every decision item and overview member vector as it states."
  (should (equal (wf-manager-tests--resource-section "resources.decisions")
                 (assoc "resources.decisions" wf-manager-tests--resource-outcomes))))

(ert-deftest wf-manager-vectors-controls ()
  "Decode every run control vector to its projection or refusal."
  (should (equal (wf-manager-tests--resource-section "resources.controls")
                 (assoc "resources.controls" wf-manager-tests--resource-outcomes))))

(ert-deftest wf-manager-vectors-runs ()
  "Decode every run item and overview member vector to its projection or refusal."
  (should (equal (wf-manager-tests--resource-section "resources.runs")
                 (assoc "resources.runs" wf-manager-tests--resource-outcomes))))

(defun wf-manager-tests--answer-outcome (vector)
  "Return the outcome of the answer VECTOR.
The outcome is (projected TEXT) with the JSON text of the answer body,
or the symbol `refused' for `wf-manager-invalid-answer'.  The body is
built only from the value that `wf-manager-answer-value' returns."
  (let ((decision (wf-manager-decode-decision
                   (wf-manager-json-decode (gethash "decision" vector)))))
    (condition-case nil
        (let ((value (wf-manager-answer-value decision (gethash "input" vector))))
          (list 'projected
                (wf-manager-json-encode (wf-manager-answer-body decision value))))
      (wf-manager-invalid-answer 'refused))))

(defun wf-manager-tests--answer-stated (vector)
  "Return the outcome that the answer VECTOR states.
The outcome is (projected TEXT) with the JSON text of the answer body,
or the symbol `refused' for the refusal InvalidAnswer."
  (let ((projection (gethash "projection" vector))
        (refusal (gethash "refusal" vector)))
    (cond
     ((and (stringp projection) (null refusal))
      (list 'projected (wf-manager-json-encode (wf-manager-json-decode projection))))
     ((and (null projection) (equal refusal "InvalidAnswer")) 'refused)
     (t (error "%s states neither one projection nor one refusal"
               (wf-manager-tests--label "resources.answers" vector))))))

(ert-deftest wf-manager-vectors-answers ()
  "Give the answer body of every answer vector, or refuse it before any body."
  (let ((projected 0) (refused 0))
    (dolist (vector (wf-manager-tests--cases "resources.answers"))
      (let ((label (wf-manager-tests--label "resources.answers" vector))
            (outcome (wf-manager-tests--answer-outcome vector)))
        (should (equal (cons label outcome)
                       (cons label (wf-manager-tests--answer-stated vector))))
        (if (eq outcome 'refused)
            (setq refused (1+ refused))
          (setq projected (1+ projected)))))
    (should (equal (list "resources.answers" projected refused)
                   (assoc "resources.answers" wf-manager-tests--resource-outcomes)))))

(defun wf-manager-tests--answer-decision (name)
  "Return the decoded decision of the answer vector NAME."
  (wf-manager-decode-decision
   (wf-manager-json-decode
    (gethash "decision"
             (or (cl-find name (wf-manager-tests--cases "resources.answers")
                          :key (lambda (vector) (gethash "name" vector))
                          :test #'equal)
                 (error "Section resources.answers has no case %s" name))))))

(ert-deftest wf-manager-answers-flag-false ()
  "Give JSON false, not null or text, for the flag answer no."
  (let* ((decision (wf-manager-tests--answer-decision "flag no is false"))
         (value (wf-manager-answer-value decision "no"))
         (body (wf-manager-answer-body decision value)))
    (should (eq value :false))
    (should (eq (gethash "value" body) :false))
    (should (equal (wf-manager-json-encode body)
                   (concat "{\"generation\":\"generation_3\",\"occurrenceId\":\"0\","
                           "\"operation\":\"answer\",\"value\":false}")))
    (should (eq (wf-manager-answer-value decision " FALSE\t") :false))
    (should (eq (wf-manager-answer-value decision "\u3000Yes\u00a0") t))
    (should (equal (wf-manager-tests--refusal-of #'wf-manager-answer-value
                                                 decision "maybe")
                   'wf-manager-invalid-answer))))

(ert-deftest wf-manager-answers-refuse-before-a-body ()
  "Refuse a structured answer that disagrees with its code, with its reason."
  (let ((decision (wf-manager-tests--answer-decision
                   "structured array item of the wrong type refuses")))
    (should (equal (condition-case failure
                       (wf-manager-answer-value decision "{\"notes\":[1],\"ok\":true}")
                     (wf-manager-invalid-answer (cdr failure)))
                   '("answer" "answer field notes item 0 must be a string")))
    (should (equal (condition-case failure
                       (wf-manager-answer-value decision "{\"ok\":true}")
                     (wf-manager-invalid-answer (cdr failure)))
                   '("answer" "answer lacks the field notes")))))

(defun wf-manager-tests--case (section name)
  "In SECTION, return the decoded JSON value of the case NAME."
  (wf-manager-json-decode
   (gethash "json" (or (cl-find name (wf-manager-tests--cases section)
                                :key (lambda (vector) (gethash "name" vector))
                                :test #'equal)
                       (error "%s has no case %s" section name)))))

(ert-deftest wf-manager-resources-draft-fields ()
  "Keep the queue position, the blocking reasons, the selectors and literal text."
  (let* ((draft (wf-manager-decode-draft
                 (wf-manager-tests--case
                  "resources.drafts"
                  "review request keeps Unicode, NUL and newline literal text and a capture")))
         (supplied (wf-manager-readiness-supplied (wf-manager-draft-readiness draft))))
    (should (equal (wf-manager-draft-phase draft) "review"))
    (should (equal (wf-manager-draft-admission draft) "waiting"))
    (should (eql (wf-manager-draft-position draft) 100))
    (should (equal (wf-manager-draft-reasons draft) '("profile-busy" "capacity")))
    (should (equal (wf-manager-draft-preparation-id draft) "prep_9"))
    (should (null (wf-manager-draft-run-id draft)))
    (should (equal (mapcar #'wf-manager-supplied-input-source supplied)
                   '("literal" "capture")))
    (should (equal (wf-manager-supplied-input-value (car supplied))
                   "雪\U0001F600 \0 first line\nsecond line"))
    (should (equal (wf-manager-supplied-input-capture-id (cadr supplied)) "capture_7"))
    (should (null (wf-manager-readiness-missing (wf-manager-draft-readiness draft))))))

(ert-deftest wf-manager-resources-preparation-fields ()
  "Keep the review digest, the input digests, the lineage edits and the policy."
  (let* ((preparation (wf-manager-decode-preparation
                       (wf-manager-tests--case
                        "resources.preparations"
                        "fork preparation keeps lineage edits and Unicode labels")))
         (review (wf-manager-preparation-review preparation))
         (input (car (wf-manager-review-inputs review)))
         (lineage (wf-manager-review-lineage review))
         (edits (wf-manager-review-lineage-edits lineage)))
    (should (equal (wf-manager-preparation-review-digest preparation)
                   (make-string 64 ?a)))
    (should (equal (wf-manager-preparation-state preparation) "live"))
    (should (null (wf-manager-preparation-reason preparation)))
    (should (equal (wf-manager-review-workspace-label review) "作業 雪\U0001F600"))
    (should (equal (list (wf-manager-review-input-name input)
                         (wf-manager-review-input-source input)
                         (wf-manager-review-input-bytes input))
                   '("subject" "capture" 10)))
    (should (equal (wf-manager-review-lineage-operation lineage) "fork"))
    (should (equal (mapcar #'wf-manager-review-edit-occurrence-id edits)
                   '(0 18446744073709551615)))
    (should (equal (wf-manager-review-edit-sha256 (cadr edits))
                   "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"))
    (should (equal (wf-manager-json-encode (wf-manager-review-policy review))
                   "{\"kind\":\"scripted\"}")))
  (let ((policy (wf-manager-review-policy
                 (wf-manager-preparation-review
                  (wf-manager-decode-preparation
                   (wf-manager-tests--case
                    "resources.preparations"
                    "routed policy keeps false verbose and null poll interval"))))))
    (should (eq (gethash "verbose" policy) :false))
    (should (eq (gethash "pollMs" policy) :null))))

(ert-deftest wf-manager-resources-receipt-fields ()
  "Keep the state, the acknowledgement, the effect and the refusal of a receipt."
  (let ((receipt (wf-manager-decode-command-receipt
                  (wf-manager-tests--case "resources.receipts"
                                          "refused answer receipt"))))
    (should (equal (wf-manager-command-receipt-state receipt) "refused"))
    (should (equal (wf-manager-command-receipt-refusal receipt) "invalid-answer"))
    (should (null (wf-manager-command-receipt-effect receipt)))
    (should (equal (gethash "attemptId" (wf-manager-command-receipt-acknowledgement receipt))
                   :null)))
  (let ((effect (wf-manager-command-receipt-effect
                 (wf-manager-decode-command-receipt
                  (wf-manager-tests--case "resources.receipts"
                                          "effect-observed steered receipt")))))
    (should (equal (gethash "kind" effect) "steered"))
    (should (equal (wf-manager-json-encode (gethash "address" effect))
                   "{\"attemptId\":\"4294967295\",\"occurrenceId\":\"18446744073709551615\"}")))
  (should (equal (wf-manager-required-scopes "export") '("observe" "export"))))

(ert-deftest wf-manager-resources-decision-fields ()
  "Keep the question, the recovery choices and the exact occurrence of a decision."
  (let* ((decision (wf-manager-decode-decision
                    (wf-manager-tests--case
                     "resources.decisions"
                     "occurrence and sequence at 2^64-1 stay exact")))
         (question (wf-manager-decision-content decision)))
    (should (eql (wf-manager-decision-occurrence-id decision) 18446744073709551615))
    (should (eql (wf-manager-decision-observed-sequence decision) 18446744073709551615))
    (should (equal (wf-manager-question-code question) "flag"))
    (should (null (wf-manager-question-editor question)))
    (should (equal (wf-manager-question-prompt question) "Proceed with 雪\U0001F600?")))
  (let ((editor (wf-manager-question-editor
                 (wf-manager-decision-content
                  (wf-manager-decode-decision
                   (wf-manager-tests--case
                    "resources.decisions"
                    "structured question keeps its schema code, false and null"))))))
    (should (equal (wf-manager-editor-schema-type editor) "object"))
    (should (equal (mapcar (lambda (property)
                             (cons (car property)
                                   (wf-manager-editor-schema-type (cdr property))))
                           (wf-manager-editor-schema-properties editor))
                   '(("ok" . "boolean")))))
  (let ((recovery (wf-manager-decision-content
                   (wf-manager-decode-decision
                    (wf-manager-tests--case
                     "resources.decisions"
                     "recovery decision keeps null and named targets")))))
    (should (equal (wf-manager-recovery-gap recovery) "transport"))
    (should (equal (mapcar (lambda (option)
                             (list (wf-manager-recovery-option-choice option)
                                   (wf-manager-recovery-option-target option)))
                           (wf-manager-recovery-choices recovery))
                   '(("retry" nil) ("failover" "scripted-backup") ("abandon" nil))))))

(ert-deftest wf-manager-resources-control-fields ()
  "Keep the offers, the decision head, cancellation and the exact addresses."
  (let* ((control (wf-manager-decode-control
                   (wf-manager-tests--case
                    "resources.controls"
                    "steer, redirect, recovery and retry offers keep maximum addresses and Unicode targets")))
         (offers (wf-manager-control-offers control))
         (steer (nth 0 offers))
         (redirect (nth 1 offers))
         (recovery (nth 2 offers)))
    (should (equal (wf-manager-control-supervision control) "owned"))
    (should (eq (wf-manager-control-cancel-allowed control) t))
    (should (equal (wf-manager-control-decision-head-id control) "decision_3"))
    (should (equal (mapcar #'wf-manager-control-offer-operation offers)
                   '("steer" "redirect" "choose-recovery" "retry")))
    (should (eql (wf-manager-control-offer-occurrence-id steer) 18446744073709551615))
    (should (eql (wf-manager-control-offer-attempt-id steer) 4294967295))
    (should (null (wf-manager-control-offer-generation steer)))
    (should (equal (wf-manager-control-offer-timings steer)
                   '("interrupt-now" "next-boundary")))
    (should (null (wf-manager-control-offer-attempt-id redirect)))
    (should (equal (wf-manager-control-offer-targets redirect)
                   '("agent 雪 [model:alt]" "")))
    (should (equal (wf-manager-control-offer-generation recovery) "generation_4"))
    (should (equal (mapcar (lambda (option)
                             (list (wf-manager-recovery-option-choice option)
                                   (wf-manager-recovery-option-target option)))
                           (wf-manager-control-offer-choices recovery))
                   '(("retry" nil) ("failover" "backup")))))
  (let ((control (wf-manager-decode-control
                  (wf-manager-tests--case
                   "resources.controls"
                   "lost controls keep false cancellation and a null head"))))
    (should (equal (wf-manager-control-supervision control) "lost"))
    (should (null (wf-manager-control-cancel-allowed control)))
    (should (null (wf-manager-control-decision-head-id control)))
    (should (null (wf-manager-control-offers control)))
    (should (eq (gethash "cancelAllowed" (wf-manager-control-projection control))
                :false))))

(ert-deftest wf-manager-resources-run-fields ()
  "Keep runtime, supervision, integrity and verification as separate fields."
  (let* ((run (wf-manager-decode-run
               (wf-manager-tests--case
                "resources.runs"
                "fork run keeps sequence 2^64-1 and an unavailable result")))
         (known (wf-manager-run-content run))
         (runtime (wf-manager-known-run-runtime known))
         (verification (wf-manager-known-run-verification known)))
    (should (equal (wf-manager-run-id run) "run_21"))
    (should (equal (list (wf-manager-known-run-parent-run-id known)
                         (wf-manager-known-run-lineage known)
                         (wf-manager-known-run-manifest-version known))
                   '("run_20" "fork" 3)))
    (should (equal (list (wf-manager-run-runtime-status runtime)
                         (wf-manager-run-runtime-last-sequence runtime)
                         (wf-manager-run-runtime-protocol-version runtime))
                   '("succeeded" 18446744073709551615 3)))
    (should (equal (wf-manager-known-run-supervision known) "cleanup-pending"))
    (should (equal (wf-manager-known-run-integrity known) "valid"))
    (should (equal (list (wf-manager-verification-state verification)
                         (wf-manager-verification-artifact-id verification)
                         (wf-manager-verification-reason verification))
                   '("unavailable" nil "missing")))
    (should (equal (wf-manager-known-run-limitations known) '("quarantined"))))
  (let ((known (wf-manager-run-content
                (wf-manager-decode-run
                 (wf-manager-tests--case
                  "resources.runs" "legacy entry keeps null runtime and request")))))
    (should (null (wf-manager-known-run-runtime known)))
    (should (null (wf-manager-known-run-manifest-version known)))
    (should (null (wf-manager-known-run-request-id known)))
    (should (equal (wf-manager-known-run-supervision known) "observer"))
    (should (equal (wf-manager-known-run-integrity known) "corrupt"))
    (should (equal (list (wf-manager-verification-state
                          (wf-manager-known-run-verification known))
                         (wf-manager-verification-artifact-id
                          (wf-manager-known-run-verification known)))
                   '("verified" "artifact_4"))))
  (let* ((member (wf-manager-decode-overview-member
                  (wf-manager-tests--case "resources.runs"
                                          "overview unreadable run member")))
         (content (wf-manager-run-content (wf-manager-overview-member-value member))))
    (should (equal (wf-manager-overview-member-kind member) "run"))
    (should (equal (wf-manager-unreadable-run-category content) "malformed-manifest"))))

(ert-deftest wf-manager-resources-timestamps ()
  "Accept the RFC 3339 times that the protocol accepts and refuse the others."
  (dolist (time '("2026-09-03T00:10:00Z" "2024-02-29t23:59:59.125z"
                  "2026-09-03T00:10:00+23:59"))
    (should (equal (list time (and (wf-manager-valid-timestamp-p time) t))
                   (list time t))))
  (dolist (time '("2026-02-29T00:00:00Z" "1900-02-29T00:00:00Z" "0000-01-01T00:00:00Z"
                  "2026-13-01T00:00:00Z" "2026-09-03T24:00:00Z" "2026-09-03T00:10:00+24:00"
                  "2026-09-03 00:10:00Z" "2026-09-03T00:10Z"))
    (should (equal (list time (wf-manager-valid-timestamp-p time)) (list time nil)))))

;;;; Refresh vectors

(defconst wf-manager-tests--refresh-counts
  '(("refresh.sequences" . 13) ("refresh.backoff" . 4) ("refresh.jitter" . 5)
    ("refresh.reconciliation" . 17))
  "The number of cases of each subsection of the refresh section.")

(defun wf-manager-tests--refresh-cases (section)
  "Return the cases of the refresh SECTION, with their stated count."
  (let ((cases (append (cl-reduce (lambda (object name) (gethash name object))
                                  (split-string section "\\.")
                                  :initial-value (wf-manager-tests--vectors))
                       nil)))
    (should (equal (cons section (length cases))
                   (assoc section wf-manager-tests--refresh-counts)))
    cases))

(defun wf-manager-tests--integer (value)
  "Return the integer of the JSON number VALUE."
  (should (wf-manager-json-number-p value))
  (let ((number (string-to-number (wf-manager-json-number-source value))))
    (should (integerp number))
    number))

(defun wf-manager-tests--stated-actions (actions)
  "Return the stated ACTIONS of a sequence step as (KIND KEY GENERATION)."
  (mapcar (lambda (action)
            (should (= (length action) 3))
            (list (intern (aref action 0)) (aref action 1)
                  (wf-manager-tests--integer (aref action 2))))
          (append actions nil)))

(defun wf-manager-tests--run-sequence (vector)
  "Run the refresh sequence VECTOR and return its step count.
Each step gives its exact actions.  Each step also keeps the rules of
the coordinator: an install has the current generation, a completion
of an earlier generation installs nothing and discards its result, an
invalidation of a resource in flight starts nothing, a completion
starts at most one fetch, and an advance leaves every resource idle."
  (let ((state (wf-manager-refresh-new))
        (index 0)
        (name (wf-manager-tests--label "refresh.sequences" vector)))
    (dolist (step (append (gethash "steps" vector) nil))
      (setq index (1+ index))
      (let* ((label (format "%s step %d" name index))
             (current (wf-manager-refresh-generation state))
             (expected (wf-manager-tests--stated-actions (gethash "actions" step)))
             (invalidated (gethash "invalidate" step))
             (completed (gethash "complete" step))
             (advanced (or (eq (gethash "resnapshot" step) t)
                           (eq (gethash "endpointSwitch" step) t)))
             next rule)
        (cond
         ((and (stringp invalidated) (not completed) (not advanced))
          (let ((in-flight (wf-manager-refresh-flight invalidated state)))
            (setq next (wf-manager-refresh-invalidate invalidated state))
            (setq rule (if in-flight
                           (null (wf-manager-refresh-step-actions next))
                         (equal (wf-manager-refresh-step-actions next)
                                (list (list 'fetch invalidated current)))))))
         ((and (stringp completed) (not invalidated) (not advanced))
          (let ((generation (wf-manager-tests--integer (gethash "generation" step))))
            (setq next (wf-manager-refresh-complete completed generation state))
            (let* ((actions (wf-manager-refresh-step-actions next))
                   (installs (cl-remove-if-not (lambda (a) (eq (car a) 'install)) actions))
                   (fetches (cl-remove-if-not (lambda (a) (eq (car a) 'fetch)) actions)))
              (setq rule (and (cl-every (lambda (a) (eql (nth 2 a) current)) installs)
                              (or (eql generation current) (null installs))
                              (or (>= generation current)
                                  (and (equal actions
                                              (list (list 'discard completed generation)))
                                       (eq (wf-manager-refresh-step-state next) state)))
                              (<= (length fetches) 1))))))
         ((and advanced (not invalidated) (not completed))
          (setq next (wf-manager-refresh-step-make
                      :state (wf-manager-refresh-advance state) :actions nil))
          (setq rule (let ((advanced-state (wf-manager-refresh-step-state next)))
                       (and (null (wf-manager-refresh-flights advanced-state))
                            (eql (wf-manager-tests--integer (gethash "generation" step))
                                 (1+ current))
                            (eql (wf-manager-refresh-generation advanced-state)
                                 (1+ current))))))
         (t (error "%s names no single step kind" label)))
        (should (equal (cons label (wf-manager-refresh-step-actions next))
                       (cons label expected)))
        (should (equal (list label 'rules rule) (list label 'rules t)))
        (setq state (wf-manager-refresh-step-state next))))
    index))

(ert-deftest wf-manager-vectors-refresh-sequences ()
  "Run every coordinator sequence with its exact actions and the rules."
  (let ((steps (mapcar #'wf-manager-tests--run-sequence
                       (wf-manager-tests--refresh-cases "refresh.sequences"))))
    (should (equal (length steps) 13))
    (should (equal (apply #'+ steps) 87))))

(ert-deftest wf-manager-vectors-refresh-backoff ()
  "Double the delay up to the cap and reset it after a delivered event."
  (let ((total 0))
    (dolist (vector (wf-manager-tests--refresh-cases "refresh.backoff"))
      (let ((backoff wf-manager-initial-backoff)
            (delivered nil)
            (delays nil)
            (name (wf-manager-tests--label "refresh.backoff" vector)))
        (dolist (step (append (gethash "steps" vector) nil))
          (pcase step
            ("failure"
             (let ((result (wf-manager-reconnect-delay backoff)))
               (should (not (and delivered (/= (car result) 1))))
               (push (car result) delays)
               (setq backoff (cdr result) delivered nil)))
            ("delivered" (setq backoff wf-manager-initial-backoff delivered t))
            (_ (error "%s has an unknown step" name))))
        (setq delays (nreverse delays))
        (should (equal (cons name delays)
                       (cons name (mapcar #'wf-manager-tests--integer
                                          (append (gethash "delays" vector) nil)))))
        (should (cl-every (lambda (delay)
                            (<= 1 delay wf-manager-reconnect-backoff-max-seconds))
                          delays))
        (setq total (+ total (length delays)))))
    (should (equal total 24))))

(ert-deftest wf-manager-vectors-refresh-jitter ()
  "Jitter each wait between half the delay and the whole delay."
  (dolist (vector (wf-manager-tests--refresh-cases "refresh.jitter"))
    (let* ((name (wf-manager-tests--label "refresh.jitter" vector))
           (seconds (wf-manager-tests--integer (gethash "seconds" vector)))
           (fraction (string-to-number
                      (wf-manager-json-number-source (gethash "fraction" vector))))
           (waited (wf-manager-jittered-microseconds seconds fraction)))
      (should (equal (cons name waited)
                     (cons name (wf-manager-tests--integer
                                 (gethash "microseconds" vector)))))
      (should (<= waited (* 1000000 wf-manager-reconnect-backoff-max-seconds)))
      (should (>= (* 2 waited) (* 1000000 seconds))))))

(defun wf-manager-tests--failure (value)
  "Return the failure (CONDITION . DATA) that the vector VALUE names."
  (pcase value
    ("InvalidResponse"
     (list 'wf-manager-invalid-response "target" "the response gives no entity tag"))
    ("TransportUnavailable"
     (list 'wf-manager-transport-unavailable "transport" "the connection failed"))
    ((pred hash-table-p)
     (let ((refused (append (gethash "refused" value) nil)))
       (should (= (length refused) 2))
       (list 'wf-manager-refused (wf-manager-tests--integer (car refused))
             (cadr refused))))
    (_ (error "Unknown failure %S" value))))

(defun wf-manager-tests--observation (vector)
  "Return the reconciliation observation of VECTOR."
  (let* ((observation (gethash "observation" vector))
         (state (gethash "receiptState" observation))
         (etag (gethash "targetETag" observation))
         (failure (gethash "failure" observation)))
    (cond
     ((and (stringp state) (null etag) (null failure))
      (should (member state wf-manager-command-states))
      (list 'receipt state))
     ((and (null state) (stringp etag) (null failure))
      (list 'target etag (eq (gethash "effectVisible" observation) t)))
     ((and (null state) (null etag) failure)
      (list 'failure (wf-manager-tests--failure failure)))
     (t (error "%s has a malformed observation"
               (wf-manager-tests--label "refresh.reconciliation" vector))))))

(defun wf-manager-tests--nullable-text (value)
  "Return VALUE as text, or nil for JSON null."
  (if (eq value :null) nil value))

(defun wf-manager-tests--run-reconciliation (vector)
  "Run the reconciliation VECTOR and return its report kind.
The read is the receipt location when one is known and otherwise the
target.  A command that stays uncertain comes back as the same record
with its exact bytes, key and precondition, and no report sends."
  (let* ((name (wf-manager-tests--label "refresh.reconciliation" vector))
         (command (gethash "command" vector))
         (bytes (wf-manager-json-encode command))
         (target (gethash "target" vector))
         (receipt (wf-manager-tests--nullable-text (gethash "receipt" vector)))
         (uncertain (wf-manager-uncertain-make
                     :command command :target target
                     :precondition (wf-manager-tests--nullable-text
                                    (gethash "precondition" vector))
                     :receipt receipt))
         (read (wf-manager-reconcile-read uncertain))
         (report (wf-manager-reconcile uncertain
                                       (wf-manager-tests--observation vector))))
    (should (equal (cons name read)
                   (cons name (if receipt (list 'receipt receipt) (list 'target target)))))
    (should (equal (cons name (symbol-name (car read)))
                   (cons name (gethash "read" vector))))
    (should (equal (cons name (symbol-name (car report)))
                   (cons name (gethash "report" vector))))
    (should (equal (list name 'no-send (length report))
                   (list name 'no-send (if (eq (car report) 'uncertain) 2 1))))
    (when (eq (car report) 'uncertain)
      (should (eq (nth 1 report) uncertain))
      (should (eq (wf-manager-uncertain-command (nth 1 report)) command))
      (should (equal (wf-manager-json-encode (wf-manager-uncertain-command (nth 1 report)))
                     bytes)))
    (car report)))

(ert-deftest wf-manager-vectors-refresh-reconciliation ()
  "Reconcile each uncertain command by one read and keep an uncertain one."
  (let ((reports (mapcar #'wf-manager-tests--run-reconciliation
                         (wf-manager-tests--refresh-cases "refresh.reconciliation"))))
    (should (equal (mapcar (lambda (kind) (cons kind (cl-count kind reports)))
                           '(effect-observed refused uncertain))
                   '((effect-observed . 3) (refused . 1) (uncertain . 13))))))

(ert-deftest wf-manager-refresh-reconcile-supplied-read ()
  "Reconcile through a supplied read in place of a target without its effect."
  (let* ((command (wf-manager-json-object "operation" "answer"))
         (uncertain (wf-manager-uncertain-make
                     :command command :target "/v1/decisions/decision_1"
                     :precondition "\"dec_1\"" :receipt nil))
         (supplied (wf-manager-reconcile-target-make
                    :location "/v1/runs/run_1/snapshot" :precondition "\"snap_1\"")))
    (should (equal (wf-manager-reconcile-read uncertain supplied)
                   '(target "/v1/runs/run_1/snapshot")))
    (should (equal (wf-manager-reconcile uncertain '(target "\"snap_2\"" t) supplied)
                   '(effect-observed)))
    (let ((report (wf-manager-reconcile uncertain '(target "\"snap_1\"" t) supplied)))
      (should (eq (car report) 'uncertain))
      (should (eq (nth 1 report) uncertain)))
    (let ((report (wf-manager-reconcile uncertain '(target "\"dec_1\"" t) supplied)))
      (should (equal report '(effect-observed))))
    (let ((report (wf-manager-reconcile
                   uncertain '(failure (wf-manager-refused 404 "resource-unavailable"))
                   supplied)))
      (should (eq (nth 1 report) uncertain))))
  (let* ((uncertain (wf-manager-uncertain-make
                     :command (wf-manager-json-object "operation" "cancel")
                     :target "/v1/runs/run_1/control" :precondition "\"rev_1\""
                     :receipt "/v1/commands/command_1"))
         (supplied (wf-manager-reconcile-target-make
                    :location "/v1/runs/run_1/snapshot" :precondition "\"snap_1\"")))
    (should (equal (wf-manager-reconcile-read uncertain supplied)
                   '(receipt "/v1/commands/command_1")))
    (should (eq (car (wf-manager-reconcile uncertain '(target "\"snap_2\"" t) supplied))
                'uncertain))
    (should (equal (wf-manager-reconcile uncertain '(receipt "effect-observed") supplied)
                   '(effect-observed)))))

(ert-deftest wf-manager-refresh-states-are-not-changed ()
  "Return new refresh states and never change the state that a step receives."
  (let* ((start (wf-manager-refresh-new))
         (fetched (wf-manager-refresh-invalidate "/v1/runs/run_1" start))
         (dirty (wf-manager-refresh-invalidate
                 "/v1/runs/run_1" (wf-manager-refresh-step-state fetched)))
         (completed (wf-manager-refresh-complete
                     "/v1/runs/run_1" 0 (wf-manager-refresh-step-state dirty)))
         (advanced (wf-manager-refresh-advance
                    (wf-manager-refresh-step-state completed))))
    (should (null (wf-manager-refresh-flights start)))
    (should (null (wf-manager-flight-dirty
                   (wf-manager-refresh-flight
                    "/v1/runs/run_1" (wf-manager-refresh-step-state fetched)))))
    (should (wf-manager-flight-dirty
             (wf-manager-refresh-flight
              "/v1/runs/run_1" (wf-manager-refresh-step-state dirty))))
    (should (null (wf-manager-flight-dirty
                   (wf-manager-refresh-flight
                    "/v1/runs/run_1" (wf-manager-refresh-step-state completed)))))
    (should (= (wf-manager-refresh-generation (wf-manager-refresh-step-state completed)) 0))
    (should (= (wf-manager-refresh-generation advanced) 1))
    (should (null (wf-manager-refresh-flights advanced)))))

;;;; HTTP transport

;; These tests start a plain HTTP listener on 127.0.0.1 in the same
;; Emacs, made with `make-network-process', and bind `wf-manager--scheme'
;; to "http".  The listener keeps the exact bytes of each request and
;; answers with canned responses.  No other host is contacted.

(cl-defstruct (wf-manager-tests--listener
               (:constructor wf-manager-tests--listener-make)
               (:copier nil))
  "A local plain HTTP listener of the transport tests.
PROCESS is the server process.  RESPOND is called with each accepted
connection and the exact bytes of its complete request.  REQUESTS is
the list of the complete requests, newest first.  PARTIAL maps each
connection to the bytes of its incomplete request.  CONNECTIONS is the
list of the accepted connections."
  (process nil)
  (respond nil)
  (requests nil)
  (partial (make-hash-table :test #'eq))
  (connections nil))

(defun wf-manager-tests--request-complete-p (bytes)
  "Return the length of the complete request at the start of BYTES, or nil."
  (let ((end (string-search "\r\n\r\n" bytes)))
    (when end
      (let* ((case-fold-search t)
             (length (if (string-match "^content-length: *\\([0-9]+\\)\r?$"
                                       (substring bytes 0 end))
                         (string-to-number (match-string 1 (substring bytes 0 end)))
                       0))
             (total (+ end 4 length)))
        (and (>= (length bytes) total) total)))))

(defun wf-manager-tests--receive (listener connection bytes)
  "For LISTENER, keep from CONNECTION the BYTES and answer each request.
A request is answered when it is complete."
  (cl-pushnew connection (wf-manager-tests--listener-connections listener))
  (let* ((partial (wf-manager-tests--listener-partial listener))
         (data (concat (gethash connection partial "") bytes))
         (total (wf-manager-tests--request-complete-p data)))
    (if (not total)
        (puthash connection data partial)
      (remhash connection partial)
      (push (substring data 0 total) (wf-manager-tests--listener-requests listener))
      (funcall (wf-manager-tests--listener-respond listener)
               connection (substring data 0 total)))))

(defun wf-manager-tests--listen (respond)
  "Start a local listener that answers each request with RESPOND."
  (let ((listener (wf-manager-tests--listener-make :respond respond)))
    (setf (wf-manager-tests--listener-process listener)
          (make-network-process
           :name "wf-manager-tests-listener" :server t :host "127.0.0.1"
           :service t :family 'ipv4 :coding 'binary :noquery t
           :filter (lambda (connection bytes)
                     (wf-manager-tests--receive listener connection bytes))
           :sentinel #'ignore))
    listener))

(defun wf-manager-tests--stop (listener)
  "Delete LISTENER and each connection that it accepted."
  (dolist (connection (wf-manager-tests--listener-connections listener))
    (delete-process connection))
  (delete-process (wf-manager-tests--listener-process listener)))

(defun wf-manager-tests--new-processes (listener before)
  "Return the processes that are not of LISTENER and not in BEFORE."
  (cl-set-difference (process-list)
                     (append before
                             (list (wf-manager-tests--listener-process listener))
                             (wf-manager-tests--listener-connections listener))))

(defun wf-manager-tests--port (listener)
  "Return the TCP port of LISTENER."
  (process-contact (wf-manager-tests--listener-process listener) :service))

(defun wf-manager-tests--http (status headers body)
  "Return an HTTP/1.1 response with STATUS, HEADERS and BODY.
HEADERS is a list of header lines without their line ends.  The
response has a Content-Length header for BODY."
  (concat (format "HTTP/1.1 %d Status\r\n" status)
          (mapconcat (lambda (line) (concat line "\r\n")) headers "")
          (format "Content-Length: %d\r\n\r\n" (string-bytes body))
          body))

(defun wf-manager-tests--json (status body &optional headers)
  "Return a JSON response with STATUS, BODY and the extra HEADERS."
  (wf-manager-tests--http
   status
   (append (list (if (<= 200 status 299)
                     "Content-Type: application/json"
                   "Content-Type: application/problem+json")
                 "Cache-Control: no-store")
           headers)
   body))

(defun wf-manager-tests--answer (response)
  "Return a responder that sends RESPONSE and closes the connection."
  (lambda (connection _request)
    (process-send-string connection response)
    (delete-process connection)))

(defun wf-manager-tests--wait (predicate &optional seconds)
  "Wait for PREDICATE to be non-nil, at most SECONDS, by default 10.
Return the value of PREDICATE."
  (let ((deadline (+ (float-time) (or seconds 10))))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.02))
    (funcall predicate)))

(defun wf-manager-tests--request-headers (request)
  "Return the header lines of REQUEST as a list of (NAME . VALUE).
NAME is lowercase."
  (let ((head (substring request 0 (string-search "\r\n\r\n" request))))
    (mapcar (lambda (line)
              (string-match "\\`\\([^:]+\\): \\(.*\\)\\'" line)
              (cons (downcase (match-string 1 line)) (match-string 2 line)))
            (cdr (split-string head "\r\n")))))

(defun wf-manager-tests--call-transport (respond function)
  "With a listener that answers with RESPOND, call FUNCTION.
FUNCTION receives the listener and a loaded profile, whose endpoint
names the port of the listener.  The listener stops after FUNCTION returns or
signals, and `wf-manager--scheme' is \"http\" during the call."
  (wf-manager-tests--call
   (lambda (dir)
     (let ((listener (wf-manager-tests--listen respond))
           (wf-manager--scheme "http"))
       (unwind-protect
           (funcall function listener
                    (wf-manager-profile-load
                     (wf-manager-tests--profile
                      dir (wf-manager-tests--with-field
                           dir 'endpoint
                           (format "https://127.0.0.1:%d/v1"
                                   (wf-manager-tests--port listener))))))
         (wf-manager-tests--stop listener))))))

(defun wf-manager-tests--outcome (start)
  "Call START with a callback, wait for its one outcome, and return it.
Each later call of the callback fails the test."
  (let ((outcomes nil))
    (funcall start (lambda (outcome) (push outcome outcomes)))
    (should (wf-manager-tests--wait (lambda () outcomes)))
    (accept-process-output nil 0.1)
    (should (= (length outcomes) 1))
    (car outcomes)))

(defconst wf-manager-tests--problem-401
  "{\"version\":1,\"status\":401,\"code\":\"unauthorized\",\"title\":\"Unauthorized\"}"
  "The body of a 401 problem response.")

(ert-deftest wf-manager-transport-exact-headers ()
  "Send exactly one Accept and one Authorization and no negotiation header."
  (wf-manager-tests--call-transport
   (wf-manager-tests--answer
    (wf-manager-tests--json 200 "{\"version\":1,\"ok\":true}" '("ETag: \"rev_1\"")))
   (lambda (listener profile)
     (let* ((transport (wf-manager-transport-open profile))
            ;; Settings of a user configuration that url.el would send.
            (url-mime-accept-string "text/html")
            (url-mime-charset-string "utf-8")
            (url-mime-language-string "en")
            (url-mime-encoding-string "gzip")
            (url-user-agent "Agent/1")
            (reply (wf-manager-tests--outcome
                    (lambda (callback)
                      (wf-manager-get transport "/v1/runs/run_1" callback))))
            (headers (wf-manager-tests--request-headers
                      (car (wf-manager-tests--listener-requests listener)))))
       (should (wf-manager-reply-p reply))
       (should (= (wf-manager-reply-status reply) 200))
       (should (equal (wf-manager-reply-etag reply) "\"rev_1\""))
       (should (eq (gethash "ok" (wf-manager-reply-value reply)) t))
       (should (string-prefix-p "GET /v1/runs/run_1 HTTP/1.1\r\n"
                                (car (wf-manager-tests--listener-requests listener))))
       (should (equal (sort (mapcar #'car headers) #'string<)
                      '("accept" "authorization" "connection" "host" "mime-version")))
       (should (equal (cl-remove "accept" headers :key #'car :test-not #'equal)
                      '(("accept" . "application/json"))))
       (should (equal (cl-remove "authorization" headers :key #'car :test-not #'equal)
                      (list (cons "authorization"
                                  (concat "Bearer " wf-manager-tests--credential)))))
       (should (equal (cdr (assoc "connection" headers)) "close"))
       (wf-manager-transport-close transport)))))

(ert-deftest wf-manager-transport-post-headers ()
  "Send a command with exactly its headers, its bytes and one Accept."
  (wf-manager-tests--call-transport
   (wf-manager-tests--answer
    (wf-manager-tests--json 202 "{\"version\":1}" '("Location: /v1/commands/c_1")))
   (lambda (listener profile)
     (let* ((transport (wf-manager-transport-open profile))
            (reply (wf-manager-tests--outcome
                    (lambda (callback)
                      (wf-manager-post transport "/v1/runs/run_1/control"
                                       (wf-manager-json-object "operation" "cancel")
                                       "epoch_1.AAAAAAAAAAAAAAAAAAAAAA" "\"rev_1\""
                                       callback))))
            (request (car (wf-manager-tests--listener-requests listener)))
            (headers (wf-manager-tests--request-headers request)))
       (should (equal (wf-manager-reply-location reply) "/v1/commands/c_1"))
       (should (string-prefix-p "POST /v1/runs/run_1/control HTTP/1.1\r\n" request))
       (should (string-suffix-p "\r\n\r\n{\"operation\":\"cancel\"}" request))
       (should (equal (sort (mapcar #'car headers) #'string<)
                      '("accept" "authorization" "connection" "content-length"
                        "content-type" "host" "idempotency-key" "if-match"
                        "mime-version")))
       (should (equal (cdr (assoc "accept" headers)) "application/json"))
       (should (equal (cdr (assoc "content-type" headers)) "application/json"))
       (should (equal (cdr (assoc "if-match" headers)) "\"rev_1\""))
       (should (equal (cdr (assoc "idempotency-key" headers))
                      "epoch_1.AAAAAAAAAAAAAAAAAAAAAA"))
       (should-error (wf-manager-post transport "/v1/runs/run_1/control"
                                      (wf-manager-json-object) "" nil #'ignore)
                     :type 'wf-manager-invalid-request)
       (should-error (wf-manager-post transport "/v1/runs/run_1/control"
                                      (wf-manager-json-object) "k" "rev_1" #'ignore)
                     :type 'wf-manager-invalid-request)
       (should (= (length (wf-manager-tests--listener-requests listener)) 1))
       (wf-manager-transport-close transport)))))

(ert-deftest wf-manager-transport-post-unicode-body ()
  "Send a command whose body has non-ASCII text as its exact UTF-8 bytes.
The key and the entity tag are multibyte strings, as the values of a
decoded response and of a parsed header are.  url-http joins the extra
headers and the body without an encoding, so the transport sends
unibyte header values."
  (wf-manager-tests--call-transport
   (wf-manager-tests--answer
    (wf-manager-tests--json 202 "{\"version\":1}" '("Location: /v1/commands/c_1")))
   (lambda (listener profile)
     (let* ((transport (wf-manager-transport-open profile))
            (body (wf-manager-json-object "operation" "set-input"
                                          "value" "\u03bb \u96ea\U0001F600"))
            (reply (wf-manager-tests--outcome
                    (lambda (callback)
                      (wf-manager-post transport "/v1/requests/request_1" body
                                       (string-to-multibyte "epoch_1.AAAAAAAAAAAAAAAAAAAAAA")
                                       (string-to-multibyte "\"rev_1\"")
                                       callback))))
            (request (car (wf-manager-tests--listener-requests listener)))
            (headers (wf-manager-tests--request-headers request)))
       (should (equal (wf-manager-reply-location reply) "/v1/commands/c_1"))
       (should (string-suffix-p (concat "\r\n\r\n" (wf-manager-json-encode body)) request))
       (should (equal (cdr (assoc "if-match" headers)) "\"rev_1\""))
       (should (equal (cdr (assoc "content-length" headers))
                      (number-to-string (length (wf-manager-json-encode body)))))
       (wf-manager-transport-close transport)))))

(ert-deftest wf-manager-transport-401-refusal ()
  "Give a 401 response as a typed refusal, with no prompt and no resend."
  (wf-manager-tests--call-transport
   (wf-manager-tests--answer
    (wf-manager-tests--json 401 wf-manager-tests--problem-401
                            '("WWW-Authenticate: Basic realm=\"manager\"")))
   (lambda (listener profile)
     (cl-letf (((symbol-function 'read-string)
                (lambda (&rest _) (error "The transport prompted")))
               ((symbol-function 'read-passwd)
                (lambda (&rest _) (error "The transport prompted"))))
       (let ((transport (wf-manager-transport-open profile)))
         (should (equal (wf-manager-tests--outcome
                         (lambda (callback)
                           (wf-manager-get transport "/v1/snapshot" callback)))
                        '(wf-manager-refused 401 "unauthorized")))
         (should (= (length (wf-manager-tests--listener-requests listener)) 1))
         (wf-manager-transport-close transport))))))

(ert-deftest wf-manager-transport-412-problem ()
  "Give a 412 problem response as a typed refusal with its code."
  (wf-manager-tests--call-transport
   (wf-manager-tests--answer
    (wf-manager-tests--json
     412 "{\"version\":1,\"status\":412,\"code\":\"precondition-failed\"}"))
   (lambda (_listener profile)
     (let ((transport (wf-manager-transport-open profile)))
       (should (equal (wf-manager-tests--outcome
                       (lambda (callback)
                         (wf-manager-post transport "/v1/decisions/d_1/answer"
                                          (wf-manager-json-object "operation" "answer")
                                          "epoch_1.BBBBBBBBBBBBBBBBBBBBBB" "\"rev_1\""
                                          callback)))
                      '(wf-manager-refused 412 "precondition-failed")))
       (wf-manager-transport-close transport)))))

(ert-deftest wf-manager-transport-redirect-refused ()
  "Refuse a redirect and send no second request."
  (wf-manager-tests--call-transport
   (wf-manager-tests--answer
    (wf-manager-tests--http 302 '("Location: /v1/other" "Cache-Control: no-store") ""))
   (lambda (listener profile)
     (let ((transport (wf-manager-transport-open profile)))
       (should (eq (car (wf-manager-tests--outcome
                         (lambda (callback)
                           (wf-manager-get transport "/v1/snapshot" callback))))
                   'wf-manager-redirect-refused))
       (accept-process-output nil 0.2)
       (should (= (length (wf-manager-tests--listener-requests listener)) 1))
       (wf-manager-transport-close transport)))))

(defun wf-manager-tests--stream (connection head total sent)
  "To CONNECTION, send HEAD and then TOTAL body bytes in 65536-byte parts.
SENT is a cons whose car counts the body bytes sent.  Sending stops
when the peer closes the connection."
  (process-send-string connection head)
  (let ((part (make-string 65536 ?x)))
    (cl-labels ((next ()
                  (when (and (process-live-p connection) (< (car sent) total))
                    (condition-case nil
                        (progn
                          (process-send-string connection part)
                          (setcar sent (+ (car sent) (length part)))
                          (run-at-time 0.01 nil #'next))
                      (file-error (delete-process connection))))))
      (next))))

(ert-deftest wf-manager-transport-oversized-body ()
  "Cut a response body at its bound and give a typed failure."
  (let* ((sent (list 0))
         (total (* 4 wf-manager-response-bytes)))
    (wf-manager-tests--call-transport
     (lambda (connection _request)
       ;; No Content-Length: the body ends when the connection closes.
       (wf-manager-tests--stream
        connection
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n"
        total sent))
     (lambda (_listener profile)
       (let ((transport (wf-manager-transport-open profile))
             (before (buffer-list)))
         (should (equal (wf-manager-tests--outcome
                         (lambda (callback)
                           (wf-manager-get transport "/v1/snapshot" callback)))
                        (list 'wf-manager-response-too-large "response"
                              (format "the response body has more than %d bytes"
                                      wf-manager-response-bytes))))
         (should (< (car sent) total))
         (should (null (cl-set-difference (buffer-list) before)))
         (wf-manager-transport-close transport))))))

(ert-deftest wf-manager-transport-declared-length-too-large ()
  "Refuse a response whose declared length passes the bound."
  (let ((sent (list 0)))
    (wf-manager-tests--call-transport
     (lambda (connection _request)
       (wf-manager-tests--stream
        connection
        (format "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nContent-Length: %d\r\n\r\n"
                (* 2 wf-manager-response-bytes))
        (* 2 wf-manager-response-bytes) sent))
     (lambda (_listener profile)
       (let ((transport (wf-manager-transport-open profile)))
         (should (eq (car (wf-manager-tests--outcome
                           (lambda (callback)
                             (wf-manager-get transport "/v1/snapshot" callback))))
                     'wf-manager-response-too-large))
         (should (< (car sent) (* 2 wf-manager-response-bytes)))
         (wf-manager-transport-close transport))))))

(defun wf-manager-tests--silent (_connection _request)
  "Answer no request, so that each request stays pending."
  nil)

(ert-deftest wf-manager-transport-cancel-cleans-up ()
  "Leave no url.el process or buffer after a cancelled request."
  (wf-manager-tests--call-transport
   #'wf-manager-tests--silent
   (lambda (listener profile)
     (let* ((processes (process-list))
            (buffers (buffer-list))
            (transport (wf-manager-transport-open profile))
            (outcomes nil)
            (exchange (wf-manager-get transport "/v1/snapshot"
                                      (lambda (outcome) (push outcome outcomes)))))
       (should (wf-manager-tests--wait
                (lambda () (wf-manager-tests--listener-requests listener))))
       (should (process-live-p (wf-manager-exchange-process exchange)))
       (should (buffer-live-p (wf-manager-exchange-buffer exchange)))
       (should (equal (process-get (wf-manager-exchange-process exchange)
                                   'wf-manager-nsm-settings-file)
                      (expand-file-name "network-security.data"
                                        (wf-manager-transport-directory transport))))
       (wf-manager-cancel exchange)
       (should (equal outcomes
                      '((wf-manager-closed "request" "the request was cancelled"))))
       (wf-manager-cancel exchange)
       (accept-process-output nil 0.1)
       (should (= (length outcomes) 1))
       (should (null (wf-manager-tests--new-processes listener processes)))
       (should (null (cl-set-difference (buffer-list) buffers)))
       (should (null (wf-manager-transport-exchanges transport)))
       (wf-manager-transport-close transport)))))

(ert-deftest wf-manager-transport-close-cleans-up ()
  "End every pending request on close and leave no process or buffer."
  (wf-manager-tests--call-transport
   #'wf-manager-tests--silent
   (lambda (listener profile)
     (let* ((processes (process-list))
            (buffers (buffer-list))
            (transport (wf-manager-transport-open profile))
            (directory (wf-manager-transport-directory transport))
            (outcomes nil))
       (dotimes (_ 2)
         (wf-manager-get transport "/v1/snapshot"
                         (lambda (outcome) (push outcome outcomes))))
       (should (wf-manager-tests--wait
                (lambda () (= (length (wf-manager-tests--listener-requests listener)) 2))))
       (should (file-directory-p directory))
       (wf-manager-transport-close transport)
       (should (equal outcomes
                      '((wf-manager-closed "transport" "the transport was closed")
                        (wf-manager-closed "transport" "the transport was closed"))))
       (should (null (wf-manager-tests--new-processes listener processes)))
       (should (null (cl-set-difference (buffer-list) buffers)))
       (should-not (file-exists-p directory))
       (should-error (wf-manager-get transport "/v1/snapshot" #'ignore)
                     :type 'wf-manager-closed)))))

(ert-deftest wf-manager-transport-timer-runs-while-pending ()
  "Run a timer while a delayed response is pending."
  (wf-manager-tests--call-transport
   (lambda (connection _request)
     (run-at-time 0.5 nil
                  (lambda ()
                    (process-send-string
                     connection (wf-manager-tests--json 200 "{\"version\":1}"))
                    (delete-process connection))))
   (lambda (_listener profile)
     (let* ((transport (wf-manager-transport-open profile))
            (ticks 0)
            (ticks-at-outcome nil)
            (timer (run-at-time 0.05 0.05 (lambda () (setq ticks (1+ ticks)))))
            (outcome nil))
       (unwind-protect
           (progn
             (wf-manager-get transport "/v1/snapshot"
                             (lambda (value)
                               (setq outcome value
                                     ticks-at-outcome ticks)))
             ;; A blocking request would have run its callback by now.
             (should (null outcome))
             (should (wf-manager-tests--wait (lambda () outcome)))
             (should (wf-manager-reply-p outcome))
             (should (>= ticks-at-outcome 5)))
         (cancel-timer timer)
         (wf-manager-transport-close transport))))))

(ert-deftest wf-manager-transport-poll-events ()
  "Read one polling batch with the cursor in the query and Accept JSON."
  (wf-manager-tests--call-transport
   (wf-manager-tests--answer
    (wf-manager-tests--json
     200 (concat "{\"version\":1,\"cursor\":\"s.9\",\"oldestCursor\":\"s.0\","
                 "\"events\":[{\"id\":\"s.5\",\"event\":\"run.changed\","
                 "\"data\":{\"version\":1,\"resource\":\"/v1/runs/run_1\","
                 "\"revision\":\"r1\"}}],\"hasMore\":false}")))
   (lambda (listener profile)
     (let* ((transport (wf-manager-transport-open profile))
            (batch (wf-manager-tests--outcome
                    (lambda (callback)
                      (wf-manager-poll-events transport "s.0" callback))))
            (request (car (wf-manager-tests--listener-requests listener))))
       (should (wf-manager-event-batch-p batch))
       (should (equal (wf-manager-event-batch-cursor batch) "s.9"))
       (should (string-prefix-p "GET /v1/events?after=s.0 HTTP/1.1\r\n" request))
       (should (equal (cdr (assoc "accept" (wf-manager-tests--request-headers request)))
                      "application/json"))
       (should-not (assoc "last-event-id" (wf-manager-tests--request-headers request)))
       (should-error (wf-manager-poll-events transport "bad" #'ignore)
                     :type 'wf-manager-invalid-request)
       (wf-manager-transport-close transport)))))

(ert-deftest wf-manager-transport-nsm-binding ()
  "Check a transport connection with the low security level and no prompt.
The GnuTLS verification against the CA file of the profile is the trust
decision, so the network security manager adds no check of its own,
such as the self-signed warning of a CA file that holds the server
certificate itself.  Another process keeps the settings of the user."
  (let ((process (make-pipe-process :name "wf-manager-tests-nsm" :noquery t))
        (seen nil))
    (unwind-protect
        (let ((verify (lambda (_process &rest _arguments)
                        (setq seen (list nsm-noninteractive nsm-settings-file
                                         network-security-level)))))
          (let ((nsm-noninteractive nil)
                (network-security-level 'medium))
            (wf-manager--nsm-verify verify process "host" 443)
            (should (equal seen (list nil nsm-settings-file 'medium)))
            ;; A connection that opens inside `url-retrieve' has no
            ;; property yet, and the transport names its file.
            (let ((wf-manager--opening "/tmp/opening/nsm.data"))
              (wf-manager--nsm-verify verify process "host" 443))
            (should (equal seen '(t "/tmp/opening/nsm.data" low)))
            (process-put process 'wf-manager-nsm-settings-file "/tmp/session/nsm.data")
            (wf-manager--nsm-verify verify process "host" 443)
            (should (equal seen '(t "/tmp/session/nsm.data" low)))))
      (delete-process process))))

(defconst wf-manager-tests--other-key
  "-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg79eaz2RWMzJoT2aV
ErBfcZrQ7xGbdMks6dR6qHDrTA6hRANCAAReQucnj88Ya26oI9HslAcNskB3fxmT
QizU6hjQHJnY8SXRlolu2smKZ/cOYD7zPErCqvDR9rpyld1cs4+B7A5e
-----END PRIVATE KEY-----
"
  "The private key of `wf-manager-tests--other-certificate'.")

(defconst wf-manager-tests--other-certificate
  "-----BEGIN CERTIFICATE-----
MIIBqjCCAVCgAwIBAgIUFUNzzOfZ8HKtW8Gu++mDV4so9p8wCgYIKoZIzj0EAwIw
ITEfMB0GA1UEAwwWd2YtbWFuYWdlci10ZXN0cy1vdGhlcjAgFw0yNjEwMDIwOTE2
MzdaGA8yMTI2MDkwODA5MTYzN1owITEfMB0GA1UEAwwWd2YtbWFuYWdlci10ZXN0
cy1vdGhlcjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABF5C5yePzxhrbqgj0eyU
Bw2yQHd/GZNCLNTqGNAcmdjxJdGWiW7ayYpn9w5gPvM8SsKq8NH2unKV3Vyzj4Hs
Dl6jZDBiMB0GA1UdDgQWBBTlrqQ80ANdL8PbE1m+TrIqdcRPzDAfBgNVHSMEGDAW
gBTlrqQ80ANdL8PbE1m+TrIqdcRPzDAPBgNVHRMBAf8EBTADAQH/MA8GA1UdEQQI
MAaHBH8AAAEwCgYIKoZIzj0EAwIDSAAwRQIhALR6lerMOj/rVJ2f7hE8ja+EFMaf
CFJFWH18iVxWGl7zAiBh3B8G0OXb1mSUjjpGSOdrsACCo9CGNAU4raunGNrP0g==
-----END CERTIFICATE-----
"
  "A self-signed certificate for 127.0.0.1 that the fixture CA does not sign.")

(defconst wf-manager-tests--tls-server
  "import socket, ssl, sys
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(sys.argv[1], sys.argv[2])
server = socket.socket()
server.bind(('127.0.0.1', 0))
server.listen(8)
print(server.getsockname()[1], flush=True)
while True:
    connection, _ = server.accept()
    try:
        context.wrap_socket(connection, server_side=True).close()
    except (ssl.SSLError, OSError):
        connection.close()
"
  "A Python TLS server that prints its port and completes no request.
The first argument is the certificate file and the second argument is
the key file.")

(defun wf-manager-tests--call-tls (function)
  "Call FUNCTION with the port of a local TLS server of another CA.
The server presents `wf-manager-tests--other-certificate', so the
verification of a profile with the fixture CA fails.  The server is a
python3 process from PATH.  It stops after FUNCTION returns or signals."
  (let* ((dir (make-temp-file "wf-manager-tests-tls" t))
         (certificate (wf-manager-tests--write
                       (expand-file-name "other.crt" dir)
                       wf-manager-tests--other-certificate #o644))
         (key (wf-manager-tests--write (expand-file-name "other.key" dir)
                                       wf-manager-tests--other-key #o600))
         (output "")
         (server (make-process
                  :name "wf-manager-tests-tls" :buffer nil :noquery t
                  :connection-type 'pipe :coding 'utf-8
                  :command (list "python3" "-B" "-c" wf-manager-tests--tls-server
                                 certificate key)
                  :filter (lambda (_process text) (setq output (concat output text)))
                  :sentinel #'ignore)))
    (unwind-protect
        (progn
          (should (wf-manager-tests--wait
                   (lambda () (string-match-p "\\`[0-9]+\n" output))))
          (funcall function (string-to-number output)))
      (delete-process server)
      (delete-directory dir t))))

(defun wf-manager-tests--profile-at (profile port)
  "Return a loaded copy of PROFILE whose endpoint is 127.0.0.1 at PORT.
The profile file is removed after the load."
  (let ((file (make-temp-file "wf-manager-tests-profile" nil ".json")))
    (unwind-protect
        (progn
          (wf-manager-tests--write
           file
           (json-serialize
            `((version . 1)
              (endpoint . ,(format "https://127.0.0.1:%d/v1" port))
              (credentialFile . ,(wf-manager-profile-credential-file profile))
              (caFile . ,(wf-manager-profile-ca-file profile))))
           #o600)
          (wf-manager-profile-load file))
      (delete-file file))))

(ert-deftest wf-manager-transport-ca-mismatch ()
  "End a request to a server of another CA with one typed failure.
The connection and its TLS handshake open inside `url-retrieve', and
the verification against the CA file of the profile fails there.  The
request and the connect each call back exactly one time, after the
call returns, with `wf-manager-transport-unavailable'.  No process,
buffer or exchange of the transport remains."
  (wf-manager-tests--call
   (lambda (dir)
     (wf-manager-tests--call-tls
      (lambda (port)
        (let* ((profile (wf-manager-tests--profile-at
                         (wf-manager-profile-load (wf-manager-tests--profile dir))
                         port))
               (processes (process-list))
               (buffers (buffer-list))
               (transport (wf-manager-transport-open profile)))
          (dolist (start (list (lambda (callback)
                                 (wf-manager-get transport "/v1/snapshot" callback))
                               (lambda (callback)
                                 (wf-manager-connect profile callback))))
            (let* ((returned nil)
                   (early nil)
                   (outcome (wf-manager-tests--outcome
                             (lambda (callback)
                               (funcall start (lambda (outcome)
                                                (unless returned (setq early t))
                                                (funcall callback outcome)))
                               (setq returned t)))))
              (should-not early)
              (should (eq (car outcome) 'wf-manager-transport-unavailable))
              (should (equal (nth 1 outcome) "connection"))))
          (should (null (wf-manager-transport-exchanges transport)))
          (should (null (cl-set-difference (process-list) processes)))
          (should (null (cl-set-difference (buffer-list) buffers)))
          (wf-manager-transport-close transport)))))))

;;;; Capabilities

(defun wf-manager-tests--capabilities (&optional edit)
  "Return the canned capabilities document of ext-pi as a JSON value.
EDIT, when non-nil, is called with the decoded value and changes it."
  (let ((value (wf-manager-json-decode
                (concat
                 "{\"version\":1,\"authorityEpoch\":\"epoch-1\",\"streamId\":\"s\","
                 "\"scopes\":[\"observe\",\"submit\"],\"profileIds\":[\"profile_1\"],"
                 "\"transports\":[\"sse\",\"polling\"],\"limits\":{"
                 "\"requestTargetBytes\":8192,\"headerBytes\":16384,\"headerFields\":100,"
                 "\"jsonBodyBytes\":2097152,\"jsonDepth\":64,\"nativeControlBytes\":1048576,"
                 "\"captureBytes\":67108864,\"aggregateInputBytes\":67108864,"
                 "\"artifactBytes\":67108864,\"sseBlockBytes\":16384,\"pageBytes\":1048576,"
                 "\"pageSetBytes\":67108864,\"pageSetsPerClient\":2,"
                 "\"pageSetLifetimeSeconds\":60,\"queuedRequests\":100,\"maxReservations\":16,"
                 "\"reviewLifetimeSeconds\":600,\"sseReadersPerClient\":2,"
                 "\"ssePendingBytesPerReader\":1048576,\"replaySeconds\":604800,"
                 "\"replayBytes\":268435456,\"heartbeatSeconds\":15,"
                 "\"reconnectIdleSeconds\":45,\"reconnectBackoffMaxSeconds\":30,"
                 "\"ordinaryMutationsPerMinute\":30,\"drafts\":100,\"globalDrafts\":100,"
                 "\"globalCaptureBytes\":67108864,\"globalPageSets\":2,"
                 "\"globalConnections\":8,\"globalDatabaseReaders\":2,"
                 "\"globalMutationLedgerBytes\":16777216,\"safetyControlsPerMinute\":100,"
                 "\"executionReservations\":1},\"versions\":{\"api\":[1],\"snapshot\":[1],"
                 "\"event\":[1],\"descriptor\":[2,3],\"frontendSession\":[1,2],"
                 "\"control\":[1,2],\"runtimeProtocol\":[1,2,3],\"runtimeStore\":[1,2],"
                 "\"managerStore\":[1,2,3,4,5,6,7,8,9,10,11,12],\"invocation\":[1],"
                 "\"frontendManifest\":[\"legacy\",\"2\",\"3\"]}}"))))
    (when edit (funcall edit value))
    value))

(defun wf-manager-tests--capability-refusal (edit)
  "Return the condition of the refusal of the capabilities after EDIT.
Return the symbol `accepted' when the capabilities pass."
  (condition-case failure
      (progn (wf-manager-check-capabilities (wf-manager-tests--capabilities edit))
             'accepted)
    (wf-manager-error (car failure))))

(defun wf-manager-tests--number (integer)
  "Return the JSON number of INTEGER."
  (wf-manager-json-integer integer))

(ert-deftest wf-manager-capabilities-parity ()
  "Check capabilities as checkCapabilities of ext-pi checks them."
  (let ((capabilities (wf-manager-check-capabilities (wf-manager-tests--capabilities))))
    (should (equal (wf-manager-capabilities-epoch capabilities) "epoch-1")))
  (dolist (case
           `((nil accepted)
             (,(lambda (v) (puthash "managerStore"
                                    (vconcat (list (wf-manager-tests--number 13))
                                             (gethash "managerStore" (gethash "versions" v)))
                                    (gethash "versions" v)))
              wf-manager-unsupported-version)
             (,(lambda (v) (puthash "frontendManifest" [] (gethash "versions" v)))
              wf-manager-unsupported-version)
             (,(lambda (v) (puthash "frontendManifest" ["4"] (gethash "versions" v)))
              wf-manager-unsupported-version)
             (,(lambda (v) (puthash "api" (vector (wf-manager-tests--number 1)
                                                  (wf-manager-tests--number 1))
                                    (gethash "versions" v)))
              wf-manager-unsupported-version)
             (,(lambda (v) (remhash "invocation" (gethash "versions" v)))
              wf-manager-unsupported-version)
             (,(lambda (v) (puthash "extra" t v)) wf-manager-invalid-response)
             (,(lambda (v) (puthash "version" (wf-manager-tests--number 2) v))
              wf-manager-invalid-response)
             (,(lambda (v) (puthash "authorityEpoch" (make-string 106 ?e) v))
              wf-manager-invalid-response)
             (,(lambda (v) (puthash "authorityEpoch" (make-string 105 ?e) v)) accepted)
             (,(lambda (v) (puthash "streamId" "s.1" v)) wf-manager-invalid-response)
             (,(lambda (v) (puthash "scopes" [] v)) accepted)
             (,(lambda (v) (puthash "scopes" ["observe" "observe"] v))
              wf-manager-invalid-response)
             (,(lambda (v) (puthash "scopes" ["admin"] v)) wf-manager-invalid-response)
             (,(lambda (v) (puthash "profileIds" ["a b"] v)) wf-manager-invalid-response)
             (,(lambda (v) (puthash "transports" ["sse"] v)) wf-manager-invalid-response)
             (,(lambda (v) (puthash "transports" ["sse" "sse"] v))
              wf-manager-invalid-response)
             (,(lambda (v) (puthash "headerBytes" (wf-manager-tests--number 1)
                                    (gethash "limits" v)))
              wf-manager-invalid-response)
             (,(lambda (v) (puthash "executionReservations" (wf-manager-tests--number 17)
                                    (gethash "limits" v)))
              wf-manager-invalid-response)
             (,(lambda (v) (puthash "drafts" (wf-manager-tests--number 0)
                                    (gethash "limits" v)))
              wf-manager-invalid-response)
             (,(lambda (v) (puthash "executionReservations" (wf-manager-tests--number 16)
                                    (gethash "limits" v)))
              accepted)
             (,(lambda (v) (remhash "drafts" (gethash "limits" v)))
              wf-manager-invalid-response)))
    (should (equal (list (car case) (wf-manager-tests--capability-refusal (car case)))
                   (list (car case) (cadr case))))))

(ert-deftest wf-manager-connect-binds-capabilities ()
  "Bind a connection by GET /v1/capabilities with a fresh identity and keys."
  (wf-manager-tests--call-transport
   (lambda (connection _request)
     (process-send-string
      connection
      (wf-manager-tests--json 200 (wf-manager-json-encode (wf-manager-tests--capabilities))))
     (delete-process connection))
   (lambda (listener profile)
     (let* ((first (wf-manager-tests--outcome
                    (lambda (callback) (wf-manager-connect profile callback))))
            (second (wf-manager-tests--outcome
                     (lambda (callback) (wf-manager-connect profile callback))))
            (keys (make-hash-table :test #'equal)))
       (should (wf-manager-connection-p first))
       (should (string-prefix-p "GET /v1/capabilities HTTP/1.1\r\n"
                                (car (wf-manager-tests--listener-requests listener))))
       (should (equal (wf-manager-connection-epoch first) "epoch-1"))
       (should (string-match-p "\\`[0-9a-f]\\{32\\}\\'" (wf-manager-connection-identity first)))
       (should-not (equal (wf-manager-connection-identity first)
                          (wf-manager-connection-identity second)))
       (dotimes (_ 1000)
         (let ((key (wf-manager-command-key first)))
           (should (string-match-p "\\`epoch-1\\.[A-Za-z0-9_-]\\{22\\}\\'" key))
           (should (wf-manager-valid-key-p key))
           (should-not (gethash key keys))
           (puthash key t keys)))
       (wf-manager-transport-close (wf-manager-connection-transport first))
       (wf-manager-transport-close (wf-manager-connection-transport second))))))

(ert-deftest wf-manager-connect-refuses-capabilities ()
  "Refuse unsupported capabilities and close the transport."
  (wf-manager-tests--call-transport
   (wf-manager-tests--answer
    (wf-manager-tests--json
     200 (wf-manager-json-encode
          (wf-manager-tests--capabilities
           (lambda (v) (puthash "managerStore" (vector (wf-manager-tests--number 13))
                                (gethash "versions" v)))))))
   (lambda (_listener profile)
     (let ((buffers (buffer-list)))
       (should (eq (car (wf-manager-tests--outcome
                         (lambda (callback) (wf-manager-connect profile callback))))
                   'wf-manager-unsupported-version))
       (should (null (cl-set-difference (buffer-list) buffers)))))))

;;;; Sessions

;; These tests run a session against the local listener.  A router
;; answers each request by its request target from a table of canned
;; responses.  The response `hold' keeps the connection open with no
;; answer, so that a test controls the order of two reads.

(defvar wf-manager-tests--held nil
  "The held connections of the router, oldest first, as (TARGET . CONNECTION).")

(defun wf-manager-tests--target (request)
  "Return the request target of the request line of REQUEST."
  (nth 1 (split-string (substring request 0 (string-search "\r\n" request)) " ")))

(defun wf-manager-tests--router (routes)
  "Return a responder that answers each request from ROUTES.
ROUTES is a hash table from a request target to the list of its
responses.  Each request takes the first response of its target, and
the last response stays for each later request.  A response is the
text of an HTTP response or the symbol `hold'.  A held connection goes
to `wf-manager-tests--held'.  A target without a route receives 404."
  (lambda (connection request)
    (let* ((target (wf-manager-tests--target request))
           (responses (gethash target routes))
           (response (car responses)))
      (when (cdr responses) (puthash target (cdr responses) routes))
      (cond ((eq response 'hold)
             (setq wf-manager-tests--held
                   (append wf-manager-tests--held (list (cons target connection)))))
            (t (process-send-string
                connection
                (or response
                    (wf-manager-tests--json
                     404 "{\"version\":1,\"status\":404,\"code\":\"not-found\",\"title\":\"Not found\"}")))
               (delete-process connection))))))

(defun wf-manager-tests--release (target response)
  "Answer the oldest held connection of TARGET with RESPONSE."
  (let ((held (assoc target wf-manager-tests--held)))
    (should held)
    (setq wf-manager-tests--held (delq held wf-manager-tests--held))
    (process-send-string (cdr held) response)
    (delete-process (cdr held))))

(defun wf-manager-tests--targets (listener target)
  "Return the number of the requests of LISTENER for TARGET."
  (cl-count target (wf-manager-tests--listener-requests listener)
            :key #'wf-manager-tests--target :test #'equal))

(defun wf-manager-tests--draft-json (id revision)
  "Return the JSON text of a draft request ID with REVISION."
  (concat "{\"version\":1,\"id\":\"" id "\",\"revision\":\"" revision "\","
          "\"workflowId\":\"wf_review\",\"descriptorRevision\":\"catalogue_17\","
          "\"profileId\":\"profile_main\",\"profileRevision\":\"profile_rev_4\","
          "\"phase\":\"draft\",\"readiness\":{\"declarations\":[{\"name\":\"subject\","
          "\"source\":\"command-tail\",\"description\":null,\"required\":true,"
          "\"schema\":{\"type\":\"string\"}}],\"supplied\":[],\"missing\":[\"subject\"],"
          "\"errors\":[]},\"admission\":{\"state\":\"not-queued\",\"position\":null,"
          "\"reasons\":[\"missing-inputs\"]},\"preparationId\":null,\"runId\":null,"
          "\"parentRunId\":null,\"lineage\":null,\"links\":{\"self\":\"/v1/requests/" id "\"}}"))

(defun wf-manager-tests--overview-page (cursor ids index total next)
  "Return the response of one overview page.
CURSOR is the event cursor, IDS the identifiers of the draft members of
the page, INDEX the page index, TOTAL the total item count and NEXT the
next page or nil."
  (wf-manager-tests--json
   200
   (concat "{\"version\":1,\"snapshotVersion\":1,\"cursor\":\"" cursor "\","
           "\"oldestCursor\":\"s.0\",\"page\":{\"setId\":\"set_1\",\"revision\":\"rev_1\","
           "\"expiresAt\":\"2999-01-01T00:00:00Z\",\"index\":" (number-to-string index)
           ",\"totalItems\":" (number-to-string total) ",\"next\":"
           (if next (concat "\"" next "\"") "null") "},\"items\":["
           (mapconcat (lambda (id)
                        (concat "{\"kind\":\"request\",\"request\":"
                                (wf-manager-tests--draft-json id "request_rev_1") "}"))
                      ids ",")
           "]}")))

(defun wf-manager-tests--batch (cursor &rest resources)
  "Return the response of a polling batch up to CURSOR.
The batch has one request.changed invalidation of each of RESOURCES."
  (wf-manager-tests--json
   200
   (concat "{\"version\":1,\"cursor\":\"" cursor "\",\"oldestCursor\":\"s.0\",\"events\":["
           (let ((number 1))
             (mapconcat (lambda (resource)
                          (cl-incf number)
                          (format (concat "{\"id\":\"s.%d\",\"event\":\"request.changed\","
                                          "\"data\":{\"version\":1,\"resource\":\"%s\","
                                          "\"revision\":\"r%d\"}}")
                                  number resource number))
                        resources ","))
           "],\"hasMore\":false}")))

(defun wf-manager-tests--gone (code)
  "Return a 410 problem response with CODE."
  (wf-manager-tests--json
   410 (format "{\"version\":1,\"status\":410,\"code\":\"%s\",\"title\":\"Gone\"}" code)))

(defun wf-manager-tests--call-session (routes function)
  "With a router of ROUTES, bind a connection and call FUNCTION.
FUNCTION receives the listener and the `wf-manager-connection'.  The
router answers /v1/capabilities, and polling batches come every 0.05
seconds."
  (puthash "/v1/capabilities"
           (list (wf-manager-tests--json
                  200 (wf-manager-json-encode (wf-manager-tests--capabilities))))
           routes)
  (setq wf-manager-tests--held nil)
  (wf-manager-tests--call-transport
   (wf-manager-tests--router routes)
   (lambda (listener profile)
     (let ((wf-manager-poll-seconds 0.05)
           (connection (wf-manager-tests--outcome
                        (lambda (callback) (wf-manager-connect profile callback)))))
       (should (wf-manager-connection-p connection))
       (funcall function listener connection)))))

(defun wf-manager-tests--routes (&rest pairs)
  "Return the routes of PAIRS, which alternate targets and response lists."
  (let ((routes (make-hash-table :test #'equal)))
    (while pairs (puthash (pop pairs) (pop pairs) routes))
    routes))

(defun wf-manager-tests--draft-revision (session uri)
  "For SESSION, return the revision of the installed draft read URI, or nil."
  (let ((read (wf-manager-session-current
               session (wf-manager-session-reference session uri))))
    (and (wf-manager-reply-p read)
         (wf-manager-draft-revision
          (wf-manager-decode-draft (wf-manager-reply-value read))))))

(ert-deftest wf-manager-session-overview-view-expired-restarts ()
  "Assemble the overview over its pages, and restart it after view-expired."
  (wf-manager-tests--call-session
   (wf-manager-tests--routes
    "/v1/snapshot"
    (list (wf-manager-tests--overview-page "s.1" '("req_a") 0 2 "/v1/snapshot?pageToken=t1"))
    "/v1/snapshot?pageToken=t1"
    (list (wf-manager-tests--gone "view-expired")
          (wf-manager-tests--overview-page "s.1" '("req_b") 1 2 nil))
    "/v1/events?after=s.1" (list (wf-manager-tests--batch "s.1")))
   (lambda (listener connection)
     (let* ((session nil)
            (overview (wf-manager-tests--outcome
                       (lambda (callback)
                         (setq session (wf-manager-session-start connection callback))))))
       (unwind-protect
           (progn
             (should (wf-manager-overview-p overview))
             (should (eq (wf-manager-session-overview session) overview))
             (should (= (wf-manager-overview-pages overview) 2))
             (should (equal (wf-manager-overview-cursor overview) "s.1"))
             (should (equal (mapcar (lambda (item)
                                      (let ((reference (wf-manager-overview-item-reference item)))
                                        (list (wf-manager-overview-member-kind
                                               (wf-manager-overview-item-member item))
                                              (wf-manager-reference-uri reference)
                                              (equal (wf-manager-reference-endpoint reference)
                                                     (wf-manager-connection-identity connection))
                                              (wf-manager-overview-item-revision item))))
                                    (wf-manager-overview-items overview))
                            '(("request" "/v1/requests/req_a" t "request_rev_1")
                              ("request" "/v1/requests/req_b" t "request_rev_1"))))
             ;; The refused continuation restarted the set at its first
             ;; page, and the polling batches follow these five requests.
             (should (equal (cl-subseq (reverse (mapcar #'wf-manager-tests--target
                                                        (wf-manager-tests--listener-requests
                                                         listener)))
                                       0 5)
                            (list "/v1/capabilities" "/v1/snapshot" "/v1/snapshot?pageToken=t1"
                                  "/v1/snapshot" "/v1/snapshot?pageToken=t1")))
             ;; The follow loop polls from the overview cursor.
             (should (wf-manager-tests--wait
                      (lambda () (>= (wf-manager-session-polls session) 2))))
             (should (eq (wf-manager-session-delivery session) 'poll))
             (should (null (wf-manager-session-follow-end session))))
         (wf-manager-session-close session))
       (should (equal (wf-manager-session-follow-end session) '(closed nil)))))))

(ert-deftest wf-manager-session-overview-view-expired-bounded ()
  "Give the 410 view-expired failure after the last restart of the overview."
  (wf-manager-tests--call-session
   (wf-manager-tests--routes
    "/v1/snapshot"
    (list (wf-manager-tests--overview-page "s.1" '("req_a") 0 2 "/v1/snapshot?pageToken=t1"))
    "/v1/snapshot?pageToken=t1" (list (wf-manager-tests--gone "view-expired")))
   (lambda (listener connection)
     (let* ((session nil)
            (overview (wf-manager-tests--outcome
                       (lambda (callback)
                         (setq session (wf-manager-session-start connection callback))))))
       (unwind-protect
           (progn
             (should (equal overview '(wf-manager-refused 410 "view-expired")))
             (should (= (wf-manager-tests--targets listener "/v1/snapshot")
                        (1+ wf-manager-page-set-restarts)))
             ;; A session without an overview does not follow.
             (accept-process-output nil 0.2)
             (should (= (wf-manager-session-polls session) 0)))
         (wf-manager-session-close session))))))

(ert-deftest wf-manager-session-cursor-refusal-resnapshots ()
  "Advance the generation, read the overview again and read every watched resource.
The read of the earlier generation completes last and installs nothing."
  (wf-manager-tests--call-session
   (wf-manager-tests--routes
    "/v1/snapshot"
    (list (wf-manager-tests--overview-page "s.1" '("req_a") 0 1 nil)
          (wf-manager-tests--overview-page "s.5" '("req_a" "req_b") 0 2 nil))
    "/v1/events?after=s.1" (list 'hold)
    "/v1/events?after=s.5" (list (wf-manager-tests--batch "s.5"))
    "/v1/requests/req_a"
    (list 'hold (wf-manager-tests--json 200 (wf-manager-tests--draft-json "req_a" "request_rev_2"))))
   (lambda (listener connection)
     (let* ((session nil)
            (overview (wf-manager-tests--outcome
                       (lambda (callback)
                         (setq session (wf-manager-session-start connection callback)))))
            (resource "/v1/requests/req_a"))
       (unwind-protect
           (progn
             (should (wf-manager-overview-p overview))
             (should (= (wf-manager-session-generation session) 0))
             (wf-manager-session-watch session (wf-manager-session-reference session resource))
             (should (wf-manager-tests--wait
                      (lambda () (and (assoc resource wf-manager-tests--held)
                                      (assoc "/v1/events?after=s.1" wf-manager-tests--held)))))
             (wf-manager-tests--release "/v1/events?after=s.1"
                                        (wf-manager-tests--gone "cursor-expired"))
             ;; The new overview, the second read of the watched resource
             ;; and a batch from the new cursor follow.
             (should (wf-manager-tests--wait
                      (lambda ()
                        (and (equal (wf-manager-tests--draft-revision session resource)
                                    "request_rev_2")
                             (>= (wf-manager-tests--targets listener "/v1/events?after=s.5") 1)))))
             (should (= (wf-manager-session-generation session) 1))
             (should (= (wf-manager-tests--targets listener "/v1/snapshot") 2))
             (should (= (wf-manager-tests--targets listener resource) 2))
             (should (equal (wf-manager-overview-cursor (wf-manager-session-overview session)) "s.5"))
             (should (= (length (wf-manager-overview-items (wf-manager-session-overview session))) 2))
             ;; The read of generation zero completes now and installs nothing.
             (wf-manager-tests--release
              resource (wf-manager-tests--json
                        200 (wf-manager-tests--draft-json "req_a" "request_rev_1")))
             (accept-process-output nil 0.3)
             (should (equal (wf-manager-tests--draft-revision session resource) "request_rev_2"))
             (should (= (wf-manager-tests--targets listener resource) 2))
             (should (eq (wf-manager-session-delivery session) 'poll))
             (should (null (wf-manager-session-follow-end session))))
         (wf-manager-session-close session))))))

(ert-deftest wf-manager-session-invalidation-during-read ()
  "Give exactly one later read for the invalidations during one read."
  (wf-manager-tests--call-session
   (wf-manager-tests--routes
    "/v1/snapshot" (list (wf-manager-tests--overview-page "s.1" '("req_a") 0 1 nil))
    "/v1/events?after=s.1" (list 'hold)
    "/v1/events?after=s.3" (list (wf-manager-tests--batch "s.3"))
    "/v1/requests/req_a"
    (list 'hold (wf-manager-tests--json 200 (wf-manager-tests--draft-json "req_a" "request_rev_2"))))
   (lambda (listener connection)
     (let* ((session nil)
            (overview (wf-manager-tests--outcome
                       (lambda (callback)
                         (setq session (wf-manager-session-start connection callback)))))
            (resource "/v1/requests/req_a"))
       (unwind-protect
           (progn
             (should (wf-manager-overview-p overview))
             (wf-manager-session-watch session (wf-manager-session-reference session resource))
             ;; A second watch of the same resource starts no read.
             (wf-manager-session-watch session (wf-manager-session-reference session resource))
             (should (wf-manager-tests--wait
                      (lambda () (and (assoc resource wf-manager-tests--held)
                                      (assoc "/v1/events?after=s.1" wf-manager-tests--held)))))
             ;; Two invalidations of the resource arrive during its read.
             (wf-manager-tests--release "/v1/events?after=s.1"
                                        (wf-manager-tests--batch "s.3" resource resource))
             (should (wf-manager-tests--wait
                      (lambda () (>= (wf-manager-tests--targets listener "/v1/events?after=s.3") 1))))
             (should (= (wf-manager-tests--targets listener resource) 1))
             (wf-manager-tests--release
              resource (wf-manager-tests--json
                        200 (wf-manager-tests--draft-json "req_a" "request_rev_1")))
             (should (wf-manager-tests--wait
                      (lambda () (equal (wf-manager-tests--draft-revision session resource)
                                        "request_rev_2"))))
             ;; Further batches without invalidations start no read.
             (let ((polls (wf-manager-session-polls session)))
               (should (wf-manager-tests--wait
                        (lambda () (>= (wf-manager-session-polls session) (+ polls 3))))))
             (should (= (wf-manager-tests--targets listener resource) 2))
             ;; The two member invalidations also gave the overview exactly
             ;; one read and one later read, after its first read.
             (should (= (wf-manager-tests--targets listener "/v1/snapshot") 3))
             ;; A reference of another endpoint refuses.
             (should-error (wf-manager-session-watch
                            session (wf-manager-reference-make :endpoint "other" :uri resource))
                           :type 'wf-manager-wrong-endpoint))
         (wf-manager-session-close session))))))

(defun wf-manager-tests--profile-of (connection)
  "Return the loaded profile of the transport of CONNECTION."
  (wf-manager-transport-profile (wf-manager-connection-transport connection)))

(defun wf-manager-tests--unreachable-profile (profile)
  "Return a loaded copy of PROFILE whose endpoint has no listener.
The port of the endpoint belonged to a listener that is deleted before
the profile loads."
  (let* ((closed (make-network-process
                  :name "wf-manager-tests-closed" :server t :host "127.0.0.1"
                  :service t :family 'ipv4 :noquery t))
         (port (process-contact closed :service)))
    (delete-process closed)
    (wf-manager-tests--profile-at profile port)))

(defun wf-manager-tests--posts (listener)
  "Return the number of the POST requests of LISTENER."
  (cl-count-if (lambda (request) (string-prefix-p "POST " request))
               (wf-manager-tests--listener-requests listener)))

(defun wf-manager-tests--problem (status code)
  "Return a problem response with STATUS and CODE."
  (wf-manager-tests--json
   status (format "{\"version\":1,\"status\":%d,\"code\":\"%s\",\"title\":\"Problem\"}"
                  status code)))

(ert-deftest wf-manager-session-switch-commits-after-overview ()
  "Commit a switch only after its overview, and never retarget a reference.
The read and the polling batch of the earlier binding are in flight
at the commit, and they install nothing."
  (wf-manager-tests--call-session
   (wf-manager-tests--routes
    "/v1/snapshot"
    (list (wf-manager-tests--overview-page "s.1" '("req_a") 0 1 nil)
          (wf-manager-tests--overview-page "s.7" '("req_a" "req_b") 0 2 nil))
    "/v1/events?after=s.1" (list 'hold)
    "/v1/events?after=s.7" (list (wf-manager-tests--batch "s.7"))
    "/v1/requests/req_a"
    (list 'hold (wf-manager-tests--json 200 (wf-manager-tests--draft-json "req_a" "request_rev_2"))))
   (lambda (listener connection)
     (let* ((session nil)
            (overview (wf-manager-tests--outcome
                       (lambda (callback)
                         (setq session (wf-manager-session-start connection callback)))))
            (resource "/v1/requests/req_a")
            (earlier (wf-manager-session-reference session resource))
            (earlier-transport (wf-manager-connection-transport connection)))
       (unwind-protect
           (progn
             (should (wf-manager-overview-p overview))
             (wf-manager-session-watch session earlier)
             (should (wf-manager-tests--wait
                      (lambda () (and (assoc resource wf-manager-tests--held)
                                      (assoc "/v1/events?after=s.1" wf-manager-tests--held)))))
             (let ((switched (wf-manager-tests--outcome
                              (lambda (callback)
                                (wf-manager-session-switch
                                 session (wf-manager-tests--profile-of connection) callback)))))
               (should (wf-manager-overview-p switched))
               (should (eq (wf-manager-session-overview session) switched))
               (should (equal (wf-manager-overview-cursor switched) "s.7"))
               (should-not (eq (wf-manager-session-connection session) connection))
               (should-not (equal (wf-manager-session-identity session)
                                  (wf-manager-connection-identity connection)))
               (should (= (wf-manager-session-generation session) 1))
               (should (equal (wf-manager-session-watched session)
                              (list wf-manager-overview-resource)))
               ;; Every member reference of the new overview carries the
               ;; new endpoint identity.
               (should (equal (mapcar (lambda (item)
                                        (wf-manager-reference-endpoint
                                         (wf-manager-overview-item-reference item)))
                                      (wf-manager-overview-items switched))
                              (make-list 2 (wf-manager-session-identity session))))
               ;; The earlier transport is closed, and its read in flight
               ;; installed nothing.
               (should (wf-manager-transport-closed earlier-transport))
               (should-not (file-exists-p (wf-manager-transport-directory earlier-transport)))
               (should (null (gethash resource (wf-manager-session-installed session))))
               ;; A reference of the earlier binding is refused and never
               ;; sent to the new binding.
               (should-error (wf-manager-session-watch session earlier)
                             :type 'wf-manager-wrong-endpoint)
               (should (eq (car (wf-manager-session-current session earlier))
                           'wf-manager-wrong-endpoint))
               (should (= (wf-manager-tests--targets listener resource) 1))
               ;; The follow loop continues from the new cursor.
               (should (wf-manager-tests--wait
                        (lambda () (>= (wf-manager-tests--targets listener "/v1/events?after=s.7") 1))))
               (should (wf-manager-tests--wait
                        (lambda () (eq (wf-manager-session-delivery session) 'poll))))
               (should (null (wf-manager-session-follow-end session)))
               ;; The reference of the new overview resolves.
               (wf-manager-session-watch
                session (wf-manager-overview-item-reference
                         (car (wf-manager-overview-items switched))))
               (should (wf-manager-tests--wait
                        (lambda () (equal (wf-manager-tests--draft-revision session resource)
                                          "request_rev_2"))))
               (should (= (wf-manager-tests--targets listener "/v1/capabilities") 2))
               (should (= (wf-manager-tests--posts listener) 0))))
         (wf-manager-session-close session))))))

(ert-deftest wf-manager-session-switch-keeps-binding ()
  "Keep the earlier binding after a switch that fails before its commit.
One switch names an endpoint with no listener.  One switch names a TLS
server whose certificate the CA of the profile does not sign.  The
transport of one switch cannot make its directory, so the connect
signals before it sends a request.  The overview read of another switch
fails.  Each switch calls back one time, after the call returns, with
its failure.  The earlier binding keeps its identity, its watched
resource, its installed read and its follow loop."
  (wf-manager-tests--call-session
   (wf-manager-tests--routes
    "/v1/snapshot"
    (list (wf-manager-tests--overview-page "s.1" '("req_a") 0 1 nil)
          (wf-manager-tests--problem 503 "storage-unavailable"))
    "/v1/events?after=s.1" (list (wf-manager-tests--batch "s.1"))
    "/v1/requests/req_a"
    (list (wf-manager-tests--json 200 (wf-manager-tests--draft-json "req_a" "request_rev_1"))))
   (lambda (listener connection)
     (wf-manager-tests--call-tls
      (lambda (tls-port)
        (let* ((processes (process-list))
               (session nil)
               (overview (wf-manager-tests--outcome
                          (lambda (callback)
                            (setq session (wf-manager-session-start connection callback)))))
               (resource "/v1/requests/req_a")
               (reference (wf-manager-session-reference session resource))
               (profile (wf-manager-tests--profile-of connection))
               (missing (expand-file-name "missing" (wf-manager-transport-directory
                                                     (wf-manager-connection-transport
                                                      connection)))))
          (unwind-protect
              (progn
                (should (wf-manager-overview-p overview))
                (wf-manager-session-watch session reference)
                (should (wf-manager-tests--wait
                         (lambda () (wf-manager-reply-p (wf-manager-session-current session reference)))))
                (let ((read (wf-manager-session-current session reference)))
                  ;; Each case is the profile, the expected condition, the
                  ;; scheme of the connect and the temporary directory.
                  (dolist (case (list (list (wf-manager-tests--unreachable-profile profile)
                                            'wf-manager-transport-unavailable
                                            wf-manager--scheme temporary-file-directory)
                                      (list (wf-manager-tests--profile-at profile tls-port)
                                            'wf-manager-transport-unavailable
                                            "https" temporary-file-directory)
                                      (list profile 'wf-manager-file-unavailable
                                            wf-manager--scheme missing)
                                      (list profile 'wf-manager-refused
                                            wf-manager--scheme temporary-file-directory)))
                    (let* ((polls (wf-manager-session-polls session))
                           (returned nil)
                           (early nil)
                           (outcome (wf-manager-tests--outcome
                                     (lambda (callback)
                                       (let ((wf-manager--scheme (nth 2 case))
                                             (temporary-file-directory (nth 3 case)))
                                         (wf-manager-session-switch
                                          session (car case)
                                          (lambda (outcome)
                                            (unless returned (setq early t))
                                            (funcall callback outcome))))
                                       (setq returned t)))))
                      (should-not early)
                      (should (eq (car outcome) (nth 1 case)))
                      (should (eq (wf-manager-session-connection session) connection))
                      (should (eq (wf-manager-session-overview session) overview))
                      (should (eq (wf-manager-session-current session reference) read))
                      (should (= (wf-manager-session-generation session) 0))
                      (should (null (wf-manager-session-switches session)))
                      (should (member resource (wf-manager-session-watched session)))
                      ;; The follow loop of the earlier binding continues.
                      (should (wf-manager-tests--wait
                               (lambda () (>= (wf-manager-session-polls session) (+ polls 2)))))
                      (should (eq (wf-manager-session-delivery session) 'poll))
                      (should (null (wf-manager-session-follow-end session))))))
                (should (equal (wf-manager-tests--refusal-of
                                #'wf-manager-session-watch session reference)
                               'accepted))
                (should (= (wf-manager-tests--targets listener "/v1/capabilities") 2))
                (should (= (wf-manager-tests--posts listener) 0)))
            (wf-manager-session-close session))
          (should (null (wf-manager-tests--new-processes listener processes)))))))))

(defvar-local wf-manager-tests--held-reference nil
  "The session and the reference that a test buffer holds.")

(ert-deftest wf-manager-session-close-ends-switch ()
  "End a switch in flight, every request and every timer on close.
The close sends no command.  The client has no hook on the kill of a
buffer, so the check that the kill of a buffer that holds a session
reference sends nothing guards against a future hook that would."
  (wf-manager-tests--call-session
   (wf-manager-tests--routes
    "/v1/snapshot"
    (list (wf-manager-tests--overview-page "s.1" '("req_a") 0 1 nil) 'hold)
    "/v1/events?after=s.1" (list (wf-manager-tests--batch "s.1")))
   (lambda (listener connection)
     (let* ((processes (process-list))
            (buffers (buffer-list))
            (session nil)
            (overview (wf-manager-tests--outcome
                       (lambda (callback)
                         (setq session (wf-manager-session-start connection callback)))))
            (outcomes nil))
       (should (wf-manager-overview-p overview))
       (with-current-buffer (get-buffer-create " wf-manager-tests-reference")
         (setq wf-manager-tests--held-reference
               (list session (wf-manager-overview-item-reference
                              (car (wf-manager-overview-items overview)))))
         (kill-buffer))
       ;; The session continues after the kill, and nothing was posted.
       (let ((polls (wf-manager-session-polls session)))
         (should (wf-manager-tests--wait
                  (lambda () (>= (wf-manager-session-polls session) (+ polls 2))))))
       (should (null (wf-manager-session-follow-end session)))
       (should (= (wf-manager-tests--posts listener) 0))
       (wf-manager-session-switch session (wf-manager-tests--profile-of connection)
                                  (lambda (outcome) (push outcome outcomes)))
       (should (wf-manager-tests--wait
                (lambda () (assoc "/v1/snapshot" wf-manager-tests--held))))
       (should (= (length (wf-manager-session-switches session)) 1))
       (let ((switch (car (wf-manager-session-switches session))))
         (wf-manager-session-close session)
         (should (wf-manager-transport-closed switch))
         (should-not (file-exists-p (wf-manager-transport-directory switch))))
       (should (= (length outcomes) 1))
       (should (eq (car (car outcomes)) 'wf-manager-closed))
       (should (null (wf-manager-session-switches session)))
       (should (null (wf-manager-session-timers session)))
       (should (equal (wf-manager-session-follow-end session) '(closed nil)))
       (let ((polls (wf-manager-session-polls session))
             (requests (length (wf-manager-tests--listener-requests listener))))
         (accept-process-output nil 0.3)
         (should (= (wf-manager-session-polls session) polls))
         (should (= (length (wf-manager-tests--listener-requests listener)) requests)))
       (should (eq (wf-manager-session-connection session) connection))
       (should (null (wf-manager-tests--new-processes listener processes)))
       (should (null (cl-set-difference (buffer-list) buffers)))
       (should (= (wf-manager-tests--posts listener) 0))))))

(provide 'wf-manager-tests)

;;; wf-manager-tests.el ends here
