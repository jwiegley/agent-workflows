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
;; session with a switch in flight.  The command tests send an answer
;; whose connection the listener closes after the request, so the send is
;; uncertain, and they check that the listener receives exactly one send
;; and that one read reconciles it to effect-observed from the run
;; snapshot, keeps it uncertain, or reconciles it from the controls when
;; the snapshot read fails.  The download tests check the exact bytes and
;; the refusal of a wrong digest, a wrong size and an inline disposition.  For a server certificate that the
;; CA file of the profile does not verify, a request, a connect and a
;; switch contact a TLS server on 127.0.0.1 that a python3 process from
;; PATH runs.  The capability checks follow
;; checkCapabilities of `ext-pi/src/manager/session.ts' over the canned
;; capabilities document of the ext-pi tests.  The service-mode tests
;; check that `wf-service-commands' states each public command of
;; `wf.el' once, that local mode is the default, and that each pending
;; and local-only command refuses in service mode with its message and
;; starts no process and sends no request.  No other host is contacted.
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
(require 'wf-service)

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
text of an HTTP response or the symbol `hold' or `drop'.  A held
connection goes to `wf-manager-tests--held'.  The response `drop'
closes the connection with no answer.  A target without a route
receives 404."
  (lambda (connection request)
    (let* ((target (wf-manager-tests--target request))
           (responses (gethash target routes))
           (response (car responses)))
      (when (cdr responses) (puthash target (cdr responses) routes))
      (cond ((eq response 'hold)
             (setq wf-manager-tests--held
                   (append wf-manager-tests--held (list (cons target connection)))))
            ((eq response 'drop)
             (delete-process connection))
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

;;;; Commands, reconciliation and downloads

;; These tests send commands of a session to the local listener.  The
;; router response `drop' closes the connection of a request with no
;; answer, so the send is uncertain after the manager may have received
;; it.

(defconst wf-manager-tests--decision-uri "/v1/decisions/decision_3"
  "The decision resource of the flag decision of the answers vectors.")

(defconst wf-manager-tests--run-snapshot-uri "/v1/runs/run_21/snapshot"
  "The run snapshot of the run of that decision.")

(defconst wf-manager-tests--control-uri "/v1/runs/run_21/control"
  "The controls of the run of that decision.")

(defun wf-manager-tests--run-snapshot (etag state pending answer)
  "Return a run snapshot response with ETAG and one occurrence 0.
The occurrence has STATE, waits on decision_3 when PENDING is non-nil,
and stores ANSWER, a string or nil for JSON null."
  (wf-manager-tests--json
   200
   (concat "{\"version\":1,\"items\":[{\"occurrenceId\":\"0\",\"state\":\"" state "\","
           "\"personPending\":" (if pending "true" "false") ","
           "\"decisionId\":" (if pending "\"decision_3\"" "null") ","
           "\"answer\":" (if answer (concat "\"" answer "\"") "null") "}]}")
   (list (concat "ETag: \"" etag "\""))))

(defun wf-manager-tests--run-control (etag cancel head)
  "Return a controls response of run_21 with ETAG.
CANCEL is non-nil when the run can be cancelled, and HEAD is the
decision head or nil."
  (wf-manager-tests--json
   200
   (concat "{\"version\":1,\"runId\":\"run_21\",\"revision\":\"controlrev_3\","
           "\"supervision\":\"owned\",\"cancelAllowed\":" (if cancel "true" "false") ","
           "\"offers\":[],\"decisionHeadId\":" (if head (concat "\"" head "\"") "null") "}")
   (list (concat "ETag: \"" etag "\""))))

(defun wf-manager-tests--with-commands (routes function)
  "Start a session on a router of ROUTES and call FUNCTION.
ROUTES are the pairs of `wf-manager-tests--routes' without the overview
and the polling batch, which the router answers with an empty
overview.  The router closes each POST to the decision of the flag
answer vector with no answer.  FUNCTION receives the listener, the
session and that decision."
  (wf-manager-tests--call-session
   (apply #'wf-manager-tests--routes
          "/v1/snapshot" (list (wf-manager-tests--overview-page "s.1" nil 0 0 nil))
          "/v1/events?after=s.1" (list (wf-manager-tests--batch "s.1"))
          wf-manager-tests--decision-uri (list 'drop)
          routes)
   (lambda (listener connection)
     (let* ((session nil)
            (overview (wf-manager-tests--outcome
                       (lambda (callback)
                         (setq session (wf-manager-session-start connection callback))))))
       (unwind-protect
           (progn
             (should (wf-manager-overview-p overview))
             (funcall function listener session
                      (wf-manager-tests--answer-decision "flag no is false")))
         (wf-manager-session-close session))))))

(defun wf-manager-tests--send-answer (session decision input)
  "On SESSION, prepare and send to DECISION the answer INPUT.
The precondition is the revision of DECISION.  Return (COMMAND . SENT),
the `wf-manager-pending' and its `wf-manager-sent'."
  (let* ((value (wf-manager-answer-value decision input))
         (command (wf-manager-session-prepare
                   session (wf-manager-session-reference session wf-manager-tests--decision-uri)
                   (wf-manager-answer-body decision value)
                   (concat "\"" (wf-manager-decision-revision decision) "\""))))
    (cons command
          (wf-manager-tests--outcome
           (lambda (callback) (wf-manager-session-send session command callback))))))

(defun wf-manager-tests--control-target (session)
  "Return the reconcile target of the controls of run_21 on SESSION."
  (wf-manager-reconcile-target-make
   :location (wf-manager-session-reference session wf-manager-tests--control-uri)
   :precondition "\"control_1\""))

(defun wf-manager-tests--check-uncertain (listener command sent posts)
  "Check the uncertain send of LISTENER for COMMAND.
SENT is the `wf-manager-sent' of COMMAND, and it must be uncertain.
LISTENER must have received exactly POSTS sends, and its last POST has
the exact bytes, key and precondition of COMMAND."
  (let* ((posted (car (cl-remove-if-not (lambda (request) (string-prefix-p "POST " request))
                                        (wf-manager-tests--listener-requests listener))))
         (headers (wf-manager-tests--request-headers posted)))
    (should (eq (wf-manager-sent-kind sent) 'uncertain))
    (should (eq (car (wf-manager-sent-failure sent)) 'wf-manager-transport-unavailable))
    (should (eq (wf-manager-uncertain-command (wf-manager-sent-uncertain sent)) command))
    (should (= (wf-manager-tests--posts listener) posts))
    (should (equal (substring posted (+ 4 (string-search "\r\n\r\n" posted)))
                   (wf-manager-pending-bytes command)))
    (should (equal (cdr (assoc "idempotency-key" headers)) (wf-manager-pending-key command)))
    (should (equal (cdr (assoc "if-match" headers)) (wf-manager-pending-if-match command)))))

(ert-deftest wf-manager-session-uncertain-answer-observed ()
  "Reconcile an uncertain answer from the run snapshot to effect-observed.
The connection closes after the request, so the send is uncertain.  The
reconciliation reads the run snapshot before the send, and one read
after it shows the occurrence completed with the stored answer.  The
listener receives exactly one send, and nobody reads the decision or
the controls."
  (wf-manager-tests--with-commands
   (list wf-manager-tests--run-snapshot-uri
         (list (wf-manager-tests--run-snapshot "snap_1" "waiting" t nil)
               (wf-manager-tests--run-snapshot "snap_2" "completed" nil "no")))
   (lambda (listener session decision)
     (let* ((reconciliation
             (wf-manager-tests--outcome
              (lambda (callback)
                (wf-manager-session-answer-reconciliation
                 session decision :false (wf-manager-tests--control-target session) callback))))
            (supplied (wf-manager-reconciliation-supplied reconciliation)))
       (should (equal (wf-manager-reference-uri (wf-manager-reconcile-target-location supplied))
                      wf-manager-tests--run-snapshot-uri))
       (should (equal (wf-manager-reconcile-target-precondition supplied) "\"snap_1\""))
       (pcase-let ((`(,command . ,sent) (wf-manager-tests--send-answer session decision "no")))
         (wf-manager-tests--check-uncertain listener command sent 1)
         (should (equal (wf-manager-tests--outcome
                         (lambda (callback)
                           (wf-manager-session-reconcile
                            session (wf-manager-sent-uncertain sent) reconciliation callback)))
                        '(effect-observed)))
         (accept-process-output nil 0.2)
         (should (= (wf-manager-tests--posts listener) 1))
         (should (= (wf-manager-tests--targets listener wf-manager-tests--decision-uri) 1))
         (should (= (wf-manager-tests--targets listener wf-manager-tests--run-snapshot-uri) 2))
         (should (= (wf-manager-tests--targets listener wf-manager-tests--control-uri) 0)))))))

(ert-deftest wf-manager-session-uncertain-answer-stays-uncertain ()
  "Keep an uncertain answer uncertain when the snapshot shows no effect.
The one read after the send shows a new entity tag, and the occurrence
still waits on the decision.  The report keeps the uncertain command
with its exact bytes, key and precondition, and nothing is sent again."
  (wf-manager-tests--with-commands
   (list wf-manager-tests--run-snapshot-uri
         (list (wf-manager-tests--run-snapshot "snap_1" "waiting" t nil)
               (wf-manager-tests--run-snapshot "snap_2" "waiting" t nil)))
   (lambda (listener session decision)
     (let ((reconciliation
            (wf-manager-tests--outcome
             (lambda (callback)
               (wf-manager-session-answer-reconciliation
                session decision :false (wf-manager-tests--control-target session) callback)))))
       (pcase-let* ((`(,command . ,sent) (wf-manager-tests--send-answer session decision "no"))
                    (uncertain (wf-manager-sent-uncertain sent)))
         (wf-manager-tests--check-uncertain listener command sent 1)
         (let ((report (wf-manager-tests--outcome
                        (lambda (callback)
                          (wf-manager-session-reconcile session uncertain reconciliation
                                                        callback)))))
           (should (eq (car report) 'uncertain))
           (should (eq (nth 1 report) uncertain))
           (should (eq (wf-manager-uncertain-command (nth 1 report)) command))
           (should (equal (wf-manager-uncertain-precondition (nth 1 report))
                          (wf-manager-pending-if-match command))))
         (accept-process-output nil 0.2)
         (should (= (wf-manager-tests--posts listener) 1))
         (should (= (wf-manager-tests--targets listener wf-manager-tests--decision-uri) 1))
         (should (= (wf-manager-tests--targets listener wf-manager-tests--run-snapshot-uri) 2)))))))

(ert-deftest wf-manager-session-uncertain-answer-control-fallback ()
  "Reconcile an answer from the controls only when the snapshot fails.
The run snapshot reads as 404, so the controls reconcile each answer.
The controls of a run that still runs with a later head show the
effect.  The controls of a run that no longer runs and has no head
leave the second answer uncertain.  Each answer has exactly one send."
  (wf-manager-tests--with-commands
   (list wf-manager-tests--control-uri
         (list (wf-manager-tests--run-control "control_2" t "decision_4")
               (wf-manager-tests--run-control "control_3" nil nil)))
   (lambda (listener session decision)
     (let ((reconciliation
            (wf-manager-tests--outcome
             (lambda (callback)
               (wf-manager-session-answer-reconciliation
                session decision :false (wf-manager-tests--control-target session) callback)))))
       (should (equal (wf-manager-reference-uri
                       (wf-manager-reconcile-target-location
                        (wf-manager-reconciliation-supplied reconciliation)))
                      wf-manager-tests--control-uri))
       (pcase-let ((`(,command . ,sent) (wf-manager-tests--send-answer session decision "no")))
         (wf-manager-tests--check-uncertain listener command sent 1)
         (should (equal (wf-manager-tests--outcome
                         (lambda (callback)
                           (wf-manager-session-reconcile
                            session (wf-manager-sent-uncertain sent) reconciliation callback)))
                        '(effect-observed))))
       (pcase-let ((`(,command . ,sent) (wf-manager-tests--send-answer session decision "no")))
         (wf-manager-tests--check-uncertain listener command sent 2)
         (should (eq (car (wf-manager-tests--outcome
                           (lambda (callback)
                             (wf-manager-session-reconcile
                              session (wf-manager-sent-uncertain sent) reconciliation
                              callback))))
                     'uncertain)))
       (accept-process-output nil 0.2)
       (should (= (wf-manager-tests--posts listener) 2))
       (should (= (wf-manager-tests--targets listener wf-manager-tests--control-uri) 2))))))

(ert-deftest wf-manager-stored-answer-text-rules ()
  "Name the stored text of an answer only when no other answer stores it."
  (let ((flag (wf-manager-tests--answer-decision "flag no is false")))
    (should (equal (wf-manager-stored-answer-text flag :false) "no"))
    (should (equal (wf-manager-stored-answer-text flag t) "yes"))
    (should (null (wf-manager-stored-answer-text flag :null)))))

(defconst wf-manager-tests--artifact (unibyte-string 0 1 127 128 200 255 10 13)
  "The bytes of the artifact of the download tests.")

(defun wf-manager-tests--artifact-response (&optional headers)
  "Return the download response of `wf-manager-tests--artifact'.
HEADERS replace the headers of a verified download."
  (wf-manager-tests--http
   200 (or headers '("Content-Type: application/octet-stream" "Cache-Control: no-store"
                     "X-Content-Type-Options: nosniff" "Content-Disposition: attachment"))
   wf-manager-tests--artifact))

(ert-deftest wf-manager-download-verifies-bytes ()
  "Give the exact bytes of a download only when its size and digest agree.
A wrong digest, a wrong size and an inline disposition each refuse the
bytes.  An invalid stated digest signals before any request."
  (let ((digest (secure-hash 'sha256 wf-manager-tests--artifact))
        (size (length wf-manager-tests--artifact)))
    (wf-manager-tests--call-transport
     (wf-manager-tests--answer (wf-manager-tests--artifact-response))
     (lambda (listener profile)
       (let* ((transport (wf-manager-transport-open profile))
              (download (lambda (size digest)
                          (wf-manager-tests--outcome
                           (lambda (callback)
                             (wf-manager-download transport "/v1/artifacts/artifact_1"
                                                  size digest callback)))))
              (bytes (funcall download size digest)))
         (should (equal bytes wf-manager-tests--artifact))
         (should-not (multibyte-string-p bytes))
         (should (equal (cdr (assoc "accept" (wf-manager-tests--request-headers
                                              (car (wf-manager-tests--listener-requests
                                                    listener)))))
                        "application/octet-stream"))
         (should (eq (car (funcall download size (make-string 64 ?0)))
                     'wf-manager-invalid-response))
         (should (eq (car (funcall download (1+ size) digest))
                     'wf-manager-invalid-response))
         (should-error (wf-manager-download transport "/v1/artifacts/artifact_1"
                                            size "ABC" #'ignore)
                       :type 'wf-manager-invalid-request)
         (should (= (length (wf-manager-tests--listener-requests listener)) 3))
         (wf-manager-transport-close transport))))
    (wf-manager-tests--call-transport
     (wf-manager-tests--answer
      (wf-manager-tests--artifact-response
       '("Content-Type: application/octet-stream" "Cache-Control: no-store"
         "X-Content-Type-Options: nosniff" "Content-Disposition: inline")))
     (lambda (_listener profile)
       (let ((transport (wf-manager-transport-open profile)))
         (should (eq (car (wf-manager-tests--outcome
                           (lambda (callback)
                             (wf-manager-download transport "/v1/artifacts/artifact_1"
                                                  size digest callback))))
                     'wf-manager-invalid-response))
         (wf-manager-transport-close transport))))))

;;;; Service mode of wf.el

(defconst wf-manager-tests--spawners
  '(make-process process-file call-process start-file-process url-retrieve
    wf-manager-get wf-manager-post-bytes wf-manager-poll-events)
  "The functions that start a process or send a request.")

(defun wf-manager-tests--wf-commands ()
  "Return the sorted public interactive commands of `wf.el'.
The major modes and the private commands of the local setup form are
not in the list."
  (let ((commands nil))
    (mapatoms
     (lambda (symbol)
       (let ((name (symbol-name symbol)))
         (when (and (commandp symbol)
                    (string-prefix-p "wf-" name)
                    (not (string-prefix-p "wf--" name))
                    (not (string-suffix-p "-mode" name))
                    (equal (file-name-base (or (symbol-file symbol 'defun) "")) "wf"))
           (push symbol commands)))))
    (sort commands #'string<)))

(ert-deftest wf-service-table-states-every-command ()
  "`wf-service-commands' states each public command of `wf.el' once."
  (let ((commands (wf-manager-tests--wf-commands))
        (stated (mapcar #'car wf-service-commands)))
    (should (memq 'wf-run commands))
    (should (equal (sort (copy-sequence stated) #'string<) commands))
    (should (= (length stated) (length (delete-dups (copy-sequence stated)))))))

(ert-deftest wf-service-local-mode-is-the-default ()
  "Without `wf-service', every command keeps its local behavior."
  (should-not wf--service-dispatch)
  (should-not wf-service--current)
  (should-not (wf--service 'wf-plan)))

(ert-deftest wf-service-refusals-send-nothing ()
  "In service mode, each local-only command refuses and sends nothing."
  (let* ((wf--service-dispatch #'wf-service--dispatch)
         (wf-service--current nil)
         (calls nil)
         (count (lambda (function)
                  (lambda (&rest _) (push function calls)))))
    (let ((advices (mapcar (lambda (function) (cons function (funcall count function)))
                           wf-manager-tests--spawners)))
      (unwind-protect
          (progn
            (dolist (advice advices)
              (advice-add (car advice) :before (cdr advice)))
            (dolist (entry wf-service-commands)
              (unless (eq (nth 1 entry) 'service)
                (let ((refusal (should-error (call-interactively (car entry))
                                             :type 'user-error)))
                  (should (equal (cadr refusal) (wf-service-refusal (car entry))))
                  (should (string-prefix-p (symbol-name (car entry)) (cadr refusal))))))
            (should (string-match-p "review of .wf-run" (wf-service-refusal 'wf-plan)))
            (should (string-match-p "review of .wf-run" (wf-service-refusal 'wf-cost)))
            (should (string-match-p "no equivalent" (wf-service-refusal 'wf-lineage-compare)))
            (should (string-match-p "use .wf-fork. instead" (wf-service-refusal 'wf-fork-submit)))
            (should-not (wf-service-refusal 'wf-restart))
            ;; A service command with no session refuses before any read.
            (should-error (call-interactively 'wf-diagnostics) :type 'user-error)
            (should-error (call-interactively 'wf-run) :type 'user-error)
            (should-error (call-interactively 'wf-runs) :type 'user-error)
            (should-error (call-interactively 'wf-answer) :type 'user-error)
            (should-error (call-interactively 'wf-control) :type 'user-error)
            (should-error (call-interactively 'wf-kill) :type 'user-error)
            (should-error (call-interactively 'wf-result) :type 'user-error)
            (should-error (call-interactively 'wf-history) :type 'user-error)
            (dolist (command '(wf-restart wf-resume wf-fork wf-rerun wf-export))
              (should-error (call-interactively command) :type 'user-error))
            (should (null calls)))
        (dolist (advice advices)
          (advice-remove (car advice) (cdr advice)))))))

;;;; Captures, setup and the exact review

(defconst wf-manager-tests--capture-receipt
  (concat "{\"version\":1,\"id\":\"capture_1\",\"requestId\":\"req_8\","
          "\"profileId\":\"profile_main\",\"bytes\":\"5\",\"sha256\":\""
          (make-string 64 ?a) "\"}")
  "The JSON text of a capture receipt of five bytes.")

(defun wf-manager-tests--capture-refusal (edit)
  "Return the condition of a decode of the capture receipt after EDIT.
EDIT changes the decoded object in place."
  (let ((value (wf-manager-json-decode wf-manager-tests--capture-receipt)))
    (funcall edit value)
    (car (should-error (wf-manager-decode-capture-receipt value)))))

(ert-deftest wf-manager-capture-receipt-decoding ()
  "Decode a capture receipt, and refuse each receipt that breaks a rule."
  (let ((receipt (wf-manager-decode-capture-receipt
                  (wf-manager-json-decode wf-manager-tests--capture-receipt))))
    (should (equal (wf-manager-capture-receipt-id receipt) "capture_1"))
    (should (equal (wf-manager-capture-receipt-request-id receipt) "req_8"))
    (should (equal (wf-manager-capture-receipt-profile-id receipt) "profile_main"))
    (should (= (wf-manager-capture-receipt-bytes receipt) 5))
    (should (equal (wf-manager-capture-receipt-sha256 receipt) (make-string 64 ?a))))
  (dolist (edit (list (lambda (value) (puthash "version" (wf-manager-json-integer 2) value))
                      (lambda (value) (puthash "bytes" "05" value))
                      (lambda (value) (puthash "bytes" "67108865" value))
                      (lambda (value) (puthash "sha256" (make-string 64 ?A) value))
                      (lambda (value) (puthash "id" "a b" value))
                      (lambda (value) (puthash "extra" "x" value))
                      (lambda (value) (remhash "profileId" value))))
    (should (eq (wf-manager-tests--capture-refusal edit) 'wf-manager-invalid-response))))

(ert-deftest wf-manager-session-capture-send ()
  "Send the exact bytes of a capture once and decode its capture receipt.
The POST has the media type application/octet-stream, an idempotency
key and no If-Match.  An identifier that is not bounded and bytes that
are not UTF-8 refuse before any send."
  (let ((bytes (encode-coding-string "Café λ\r\n" 'utf-8-unix)))
    (wf-manager-tests--with-commands
     (list "/v1/captures?requestId=req_8"
           (list (wf-manager-tests--json 202 wf-manager-tests--capture-receipt
                                         (list "Location: /v1/commands/command_9"))))
     (lambda (listener session _decision)
       (should (eq (car (should-error (wf-manager-session-prepare-capture session "a b" bytes)))
                   'wf-manager-invalid-endpoint))
       (should (eq (car (should-error (wf-manager-session-prepare-capture
                                       session "req_8" (unibyte-string #xff #xfe))))
                   'wf-manager-invalid-response))
       (should (eq (car (should-error (wf-manager-session-prepare-capture
                                       session "req_8" "λ")))
                   'wf-manager-invalid-response))
       (should (= (wf-manager-tests--posts listener) 0))
       (let* ((command (wf-manager-session-prepare-capture session "req_8" bytes))
              (sent (wf-manager-tests--outcome
                     (lambda (callback) (wf-manager-session-send session command callback))))
              (posted (car (cl-remove-if-not (lambda (request) (string-prefix-p "POST " request))
                                             (wf-manager-tests--listener-requests listener))))
              (headers (wf-manager-tests--request-headers posted)))
         (should (= (wf-manager-tests--posts listener) 1))
         (should (equal (wf-manager-tests--target posted) "/v1/captures?requestId=req_8"))
         (should (equal (cdr (assoc "content-type" headers)) "application/octet-stream"))
         (should (equal (cdr (assoc "idempotency-key" headers)) (wf-manager-pending-key command)))
         (should-not (assoc "if-match" headers))
         (should (equal (substring posted (+ 4 (string-search "\r\n\r\n" posted))) bytes))
         (should (eq (wf-manager-sent-kind sent) 'delivered))
         (should (equal (wf-manager-reference-uri (wf-manager-sent-location sent))
                        "/v1/commands/command_9"))
         (should (equal (wf-manager-capture-receipt-id (wf-manager-sent-capture sent))
                        "capture_1")))))))

(ert-deftest wf-service-setup-refresh-keeps-drafts ()
  "Draw a service setup form again and keep every draft and the point.
The specs of the form are the specs of its spec function."
  (let* ((row '((name . "service-setup") (inputs . (((name . "first")) ((name . "second"))))))
         (specs nil))
    (cl-letf (((symbol-function 'recursive-edit)
               (lambda ()
                 (should (eq major-mode 'wf--setup-mode))
                 (should (string-search "Request one" (buffer-string)))
                 (let ((first (car wf--setup-fields))
                       (second (cadr wf--setup-fields)))
                   (goto-char (widget-field-start (plist-get first :widget)))
                   (insert "Café λ")
                   (goto-char (widget-field-start (plist-get second :widget)))
                   (insert "two")
                   (backward-char 1)
                   (let ((widget (plist-get first :widget)))
                     (wf--setup-refresh "Request two")
                     (should-not (eq widget (plist-get first :widget))))
                   (should (string-search "Request two" (buffer-string)))
                   (should-not (string-search "Request one" (buffer-string)))
                   (should (equal (widget-value (plist-get first :widget)) "Café λ"))
                   (should (equal (widget-value (plist-get second :widget)) "two"))
                   (should (= (point) (+ 2 (widget-field-start (plist-get second :widget)))))
                   (should (equal wf--setup-context '(:request "req_8")))
                   (wf--setup-submit)))))
      (setq specs (wf--setup-inputs row (lambda (name source text) (list name source text))
                                    "Request one" '(:request "req_8"))))
    (should (equal specs '(("first" literal "Café λ") ("second" literal "two"))))))

(ert-deftest wf-service-setup-spec-sources ()
  "Literal and Multiline give literals, and the other sources give exact bytes."
  (should (equal (wf-service--setup-spec "input" 'literal "λ")
                 '((name . "input") (source . "literal") (value . "λ"))))
  (should (equal (wf-service--setup-spec "input" 'multiline "a\nb")
                 '((name . "input") (source . "literal") (value . "a\nb"))))
  (let ((spec (wf-service--setup-spec "input" 'buffer "Ü\r\n")))
    (should (equal (alist-get 'source spec) "capture"))
    (should (equal (alist-get 'bytes spec) (encode-coding-string "Ü\r\n" 'utf-8-unix)))
    (should-not (multibyte-string-p (alist-get 'bytes spec))))
  (let ((file (make-temp-file "wf-capture-")))
    (unwind-protect
        (let ((bytes (encode-coding-string "line λ\r\nnext\n" 'utf-8-unix)))
          (let ((coding-system-for-write 'no-conversion))
            (write-region bytes nil file nil 'silent))
          (should (equal (alist-get 'bytes (wf-service--setup-spec "input" 'file file)) bytes))
          (should-error (wf-service--setup-spec "input" 'file "") :type 'user-error)
          (should-error (wf-service--setup-spec "input" 'file (concat file ".absent"))
                        :type 'user-error))
      (delete-file file))))

(ert-deftest wf-service-review-text-is-the-exact-review ()
  "The review text states every selector, the entity tag and the admission."
  (let* ((case (cl-find "live preparation with scripted policy"
                        (wf-manager-tests--cases "resources.preparations")
                        :key (lambda (vector) (gethash "name" vector)) :test #'equal))
         (preparation (wf-manager-decode-preparation
                       (wf-manager-json-decode (gethash "json" case))))
         (draft (wf-manager-decode-draft
                 (wf-manager-json-decode (wf-manager-tests--draft-json "req_8" "request_rev_1"))))
         (review (wf-service--review-make :draft draft :lines '("Request req_8: queued")
                                          :preparation preparation :etag "\"prep_rev\""))
         (text (wf-service-review-text review)))
    (dolist (selector wf-service--selectors)
      (should (string-search (format "  %s: %s\n" (car selector) (funcall (cdr selector) preparation))
                             text)))
    (should (string-search "  If-Match: \"prep_rev\"\n" text))
    (should (string-search (format "Program SHA-256: %s\n"
                                   (wf-manager-review-program-hash (wf-manager-preparation-review preparation)))
                           text))
    (should (string-search "  Request req_8: queued\n" text))
    (should (string-search "Blocking reasons: missing-inputs\n" text))
    (should (string-search "Queue position: none\n" text))
    (should (string-search
             (concat "  " (car (split-string (wf-manager-review-plan
                                              (wf-manager-preparation-review preparation))
                                             "\n")))
             text))))

;; The JSON text of a hello plan, as the review of the manager states it.
(defconst wf-manager-tests--hello-plan
  (concat "{\"askNodes\":3,\"codes\":[\"text\",\"text\",\"receipt\"],\"level\":\"pipeline\","
          "\"maxFold\":3,\"minFold\":3,\"name\":\"hello\",\"paths\":1,"
          "\"program\":{\"fns\":[]},\"result\":\"receipt\",\"size\":4}")
  "The plan text of a review of the hello workflow.")

(defun wf-manager-tests--preparation (&optional plan)
  "Return the live preparation prep_9 of request req_8, with PLAN when given."
  (let ((value (wf-manager-tests--resource "resources.preparations"
                                           "live preparation with scripted policy")))
    (when plan
      (puthash "plan" plan (gethash "review" value)))
    (wf-manager-decode-preparation value)))

(defun wf-manager-tests--review (session preparation)
  "Return a review on SESSION of PREPARATION for the draft request req_8."
  (wf-service--review-make
   :session session
   :draft (wf-manager-decode-draft
           (wf-manager-json-decode (wf-manager-tests--draft-json "req_8" "request_rev_1")))
   :lines '("Request req_8: queued") :preparation preparation :etag "\"prep_rev\""))

(ert-deftest wf-service-catalogue-annotation-states-the-price ()
  "The catalogue annotation states the price of the decimal catalogue fields.
The path count of /v1/workflows is a string of digits.  A row without
a path count shows its blurb alone, and no annotation shows nil."
  (should (= (wf-service--number "43") 43))
  (should (= (wf-service--number (wf-manager-json-integer 24)) 24))
  (should-not (wf-service--number :null))
  (should-not (wf-service--number "4x"))
  (let* ((item (wf-manager-json-decode
                (concat "{\"id\":\"wf_stack\",\"profileId\":\"scripted\",\"name\":\"stack-prs\","
                        "\"blurb\":\"stack the work\",\"level\":\"branch\",\"maxFold\":24,"
                        "\"paths\":\"43\",\"revision\":\"rev_1\",\"profileRevision\":\"prev_1\","
                        "\"help\":\"help\"}")))
         (rows (cl-letf (((symbol-function 'wf-service--collection)
                          (lambda (&rest _) (list item))))
                 (wf-service--rows nil "scripted")))
         (annotations nil))
    (should (eql (alist-get 'paths (car rows)) 43))
    (cl-letf (((symbol-function 'completing-read)
               (lambda (_prompt table &rest _)
                 (let ((annotate (alist-get 'annotation-function
                                            (cdr (funcall table "" nil 'metadata)))))
                   (setq annotations (list (funcall annotate "stack-prs")
                                           (funcall annotate "bare"))))
                 "stack-prs")))
      (wf--read-row "Workflow: " nil
                    (append rows '(((name . "bare") (blurb . "no price") (level . "batch"))))))
    (should (string-search "branch · at most 24 over 43 paths  —  stack the work"
                           (car annotations)))
    (should (string-match-p "\\` +no price\\'" (cadr annotations)))
    (dolist (annotation annotations)
      (should-not (string-search "nil" annotation)))))

(ert-deftest wf-service-review-names-the-workflow-and-summarizes-the-plan ()
  "The approval prompt names the workflow, the profile and the target.
The review buffer keeps the selectors, and its plan summary comes
before the raw program.  A plan that is not JSON names the workflow
identifier."
  (let* ((preparation (wf-manager-tests--preparation wf-manager-tests--hello-plan))
         (text (wf-service-review-text (wf-manager-tests--review nil preparation)))
         (summary (string-search "Plan summary: workflow hello, level pipeline, size 4, askNodes 3\n"
                                 text))
         (program (string-search "Program (the exact plan text of the manager):\n" text)))
    (should (equal (wf-service-approval-prompt preparation)
                   "Start hello in profile_main (Deterministic worker)? "))
    (should (string-search "Workflow: hello (wf_review)\n" text))
    (should (string-search "  Price: minFold 3, maxFold 3, over 1 path\n" text))
    (should (string-search "  Codes: text, text, receipt, result receipt\n" text))
    (should (and summary program (< summary program)))
    (should (string-search (concat "  " wf-manager-tests--hello-plan "\n") text))
    (should (string-search "  reviewDigest: " text))
    (should (string-search "d: decline (discard the preparation)" text)))
  (let ((preparation (wf-manager-tests--preparation)))
    (should (equal (wf-service-approval-prompt preparation)
                   "Start wf_review in profile_main (Deterministic worker)? "))
    (should (string-search "Plan summary: none, because the plan is not a JSON object\n"
                           (wf-service-review-text (wf-manager-tests--review nil preparation))))))

(ert-deftest wf-service-review-text-states-the-started-run ()
  "A review whose approval started a run names that run.
Before the approval the review states that no run has started.  After
it the review names the run instead, and offers no approval key."
  (let* ((review (wf-manager-tests--review nil (wf-manager-tests--preparation))))
    (should (string-search "no run has started" (wf-service-review-text review)))
    (setf (wf-service--review-run review) "run_5")
    (let ((text (wf-service-review-text review)))
      (should (string-prefix-p "Exact review of the manager — approved.  Run run_5 started.\n" text))
      (should-not (string-search "no run has started" text))
      (should-not (string-search "a: approve" text)))))

(ert-deftest wf-service-review-quit-discards-after-a-yes ()
  "\\`q' in a review asks whether to discard the preparation.
A no sends nothing and leaves the request in review.  A yes sends one
discard with the entity tag of the preparation as If-Match, so the
declined review holds no execution reservation."
  (wf-manager-tests--with-view
   (list "/v1/preparations/prep_9"
         (list (wf-manager-tests--json
                202 (wf-manager-tests--vector-json "resources.receipts"
                                                   "effect-observed discarded receipt")
                '("Location: /v1/commands/cmd_11"))))
   (lambda (listener session)
     (let ((prompts nil)
           (reviews nil))
       (unwind-protect
           (dolist (answer '(nil t))
             (let ((buffer (generate-new-buffer "*wf review test*")))
               (push buffer reviews)
               (switch-to-buffer buffer)
               (wf-service-review-mode)
               (setq wf-service--review-state
                     (wf-manager-tests--review session (wf-manager-tests--preparation)))
               (should (eq (lookup-key wf-service-review-mode-map "q") #'wf-service-review-decline))
               (should (eq (lookup-key wf-service-review-mode-map "d") #'wf-service-review-discard))
               (let ((wf-confirm-function (lambda (prompt) (push prompt prompts) answer)))
                 (wf-service-review-decline))
               (should (= (wf-manager-tests--posts listener) (if answer 1 0)))
               (should (equal (mapcar #'car (wf-service--review-outcomes
                                             (buffer-local-value 'wf-service--review-state buffer)))
                              (if answer '("discard") nil)))))
         (mapc #'kill-buffer reviews))
       (should (equal prompts (make-list 2 "Discard the preparation of this review, so that it holds no execution reservation? ")))
       (let ((posted (car (cl-remove-if-not (lambda (request) (string-prefix-p "POST " request))
                                            (wf-manager-tests--listener-requests listener)))))
         (should (equal (wf-manager-tests--target posted) "/v1/preparations/prep_9"))
         (should (equal (cdr (assoc "if-match" (wf-manager-tests--request-headers posted)))
                        "\"prep_rev\""))
         (should (equal (substring posted (+ 4 (string-search "\r\n\r\n" posted)))
                        "{\"operation\":\"discard\"}")))))))

(ert-deftest wf-service-requests-lists-open-requests-and-opens-the-review ()
  "`wf-requests' lists the requests in draft or review by workflow name.
The choice of a request in review opens its review, and the command
sends nothing."
  (wf-manager-tests--with-view
   (list "/v1/requests"
         (list (wf-manager-tests--items-page
                (wf-manager-tests--draft-json "req_a" "request_rev_1")
                (string-replace "\"req_8\"" "\"req_r\""
                                (string-replace "/v1/requests/req_8" "/v1/requests/req_r"
                                                (wf-manager-tests--vector-json
                                                 "resources.requests"
                                                 "request collection item keeps literal Unicode and NUL text")))))
         "/v1/workflows?profileId=profile_main"
         (list (wf-manager-tests--items-page
                "{\"id\":\"wf_review\",\"profileId\":\"profile_main\",\"name\":\"review\"}")))
   (lambda (listener _session)
     (let ((labels nil)
           (annotation nil)
           (opened nil))
       (cl-letf (((symbol-function 'completing-read)
                  (lambda (_prompt choices &rest _)
                    (setq labels (mapcar #'car choices)
                          annotation (funcall (plist-get completion-extra-properties
                                                         :annotation-function)
                                              "review/req_r"))
                    "review/req_r"))
                 ((symbol-function 'wf-service--open-review)
                  (lambda (_session reference)
                    (setq opened (wf-manager-reference-uri reference)))))
         (call-interactively #'wf-requests))
       (should (equal labels '("review/req_r" "review/req_a")))
       (should (string-prefix-p "  profile profile_main, review, admission " annotation))
       (should (equal opened "/v1/requests/req_r"))
       (should (= (wf-manager-tests--posts listener) 0))))))

(ert-deftest wf-local-history-row-prints-no-nil ()
  "A local history row of a root run without a persona shows no Lisp nil."
  (with-temp-buffer
    (wf-history-mode)
    (let ((wf--store 'store))
      (cl-letf (((symbol-function 'wf--store-query)
                 (lambda (&rest _)
                   `((runs . [((kind . "run") (runId . "native-1") (runnerId . "agentic-run")
                               (workflow . "hello") (lineage) (parentRunId) (persona)
                               (targetKind . "scripted") (ownership . "terminal")
                               (createdAt . "2026-10-04T00:00:00Z")
                               (snapshot (status . "succeeded") (billFresh . 3)
                                         (billMemo . 3)))])))))
        (wf-history-refresh)))
    (let ((row (append (cadr (car tabulated-list-entries)) nil)))
      (should (equal (nth 4 row) "root"))
      (should (equal (nth 6 row) "none / scripted"))
      (dolist (column row)
        (should-not (string-search "nil" column))))))

;;;; Run views and answers

(defun wf-manager-tests--resource (section name)
  "In SECTION, return the decoded JSON value of the case NAME."
  (wf-manager-json-decode
   (gethash "json" (or (cl-find name (wf-manager-tests--cases section)
                                :key (lambda (vector) (gethash "name" vector))
                                :test #'equal)
                       (error "Section %s has no case %s" section name)))))

(defconst wf-manager-tests--flag-decision "flag question keeps null scope and Unicode prompt"
  "The decisions vector of the flag question decision_3 of run_21.")

(defun wf-manager-tests--queue-page (&rest decisions)
  "Return the JSON text of the decision queue page of run_21 with DECISIONS.
Each item of DECISIONS is the JSON text of one decision."
  (concat "{\"version\":1,\"runId\":\"run_21\",\"page\":{\"setId\":\"set_q\",\"revision\":\"rev_q\","
          "\"expiresAt\":\"2999-01-01T00:00:00Z\",\"index\":0,\"totalItems\":"
          (number-to-string (length decisions)) ",\"next\":null},\"items\":["
          (string-join decisions ",") "]}"))

(defun wf-manager-tests--vector-json (section name)
  "In SECTION, return the JSON text of the case NAME."
  (gethash "json" (cl-find name (wf-manager-tests--cases section)
                           :key (lambda (vector) (gethash "name" vector))
                           :test #'equal)))

(defun wf-manager-tests--view (snapshot result)
  "Return a run view of run_21 with the JSON text SNAPSHOT and RESULT.
The run has lost supervision and an absent verification, the controls
offer an answer, and the queue holds the flag question at its head."
  (wf-service--view-make
   :identity "endpoint_1" :run "run_21" :delivery 'poll :result result
   :kept (list (cons 'run (wf-manager-decode-run
                           (wf-manager-tests--resource
                            "resources.runs"
                            "managed run with lost supervision keeps a sequence beyond 2^53")))
               (cons 'snapshot (wf-manager-json-decode snapshot))
               (cons 'control (wf-manager-decode-control
                               (wf-manager-tests--resource
                                "resources.controls" "owned controls with an answer offer")))
               (cons 'queue (vector (wf-manager-decode-decision
                                     (wf-manager-tests--resource
                                      "resources.decisions" wf-manager-tests--flag-decision)))))))

(ert-deftest wf-service-view-lines-state-each-dimension ()
  "A run view states each dimension on its own line and ends with the outcome."
  (let ((lines (wf-service-view-lines
                (wf-manager-tests--view
                 "{\"runtime\":{\"status\":\"running\"},\"workflow\":\"review λ\"}" nil))))
    (should (equal (car lines) "Service run run_21, workflow review λ"))
    (should (equal (cadr lines) "Lineage: root"))
    (dolist (line '("Endpoint identity: endpoint_1" "Delivery: poll" "Observation: current"
                    "Runtime: running" "Supervision: lost" "Verification: absent"
                    "Decisions: 1 pending"
                    "  Head decision_3: pending question (flag: yes, no, true or false): Proceed with 雪😀?"
                    "Offers: answer, cancel"))
      (should (member line lines)))
    (should (equal (last lines 2) '("Terminal: not yet (running)"
                                    "Result: none until the run succeeds"))))
  (let ((digest (make-string 64 ?a)))
    (should (equal (last (wf-service-view-lines
                          (wf-manager-tests--view
                           (concat "{\"runtime\":{\"status\":\"succeeded\"},"
                                   "\"verification\":{\"state\":\"verified\"}}")
                           (list 'verified 8 digest)))
                         3)
                   (list "Terminal: succeeded" "Result: verified 8 bytes"
                         (concat "Result SHA-256: " digest)))))
  (should (equal (last (wf-service-view-lines
                        (wf-manager-tests--view
                         (concat "{\"runtime\":{\"status\":\"failed\"},\"failure\":\"gap\\nend\","
                                 "\"failureClass\":\"transport\"}")
                         nil))
                       3)
                 '("Terminal: failed" "Failure: transport: gap end"
                   "Result: no download for a run that did not succeed"))))

(ert-deftest wf-service-view-lines-state-the-lineage ()
  "A run view of a lineage child names its operation and its parent run."
  (let ((view (wf-manager-tests--view "{\"runtime\":{\"status\":\"succeeded\"}}" nil)))
    (setf (alist-get 'run (wf-service--view-kept view))
          (wf-manager-decode-run
           (wf-manager-tests--resource
            "resources.runs" "fork run keeps sequence 2^64-1 and an unavailable result")))
    (should (equal (cadr (wf-service-view-lines view)) "Lineage: fork of run run_20")))
  (let ((view (wf-manager-tests--view "{}" nil)))
    (setf (alist-get 'run (wf-service--view-kept view) nil 'remove) nil)
    (should (equal (cadr (wf-service-view-lines view)) "Lineage: not yet observed"))))

(ert-deftest wf-service-runs-lists-local-and-service-runs ()
  "`wf-runs' in service mode offers the local sessions and the service runs."
  (let* ((local (wf--session-create :prepared '((runId . "local_1")) :directory "/tmp/wf-local/"))
         (wf--sessions (list local))
         (run (wf-manager-decode-run
               (wf-manager-tests--resource
                "resources.runs" "managed run with lost supervision keeps a sequence beyond 2^53")))
         (session (wf-manager--session-make
                   :connection (wf-manager--connection-make :identity "endpoint_1")
                   :overview (wf-manager--overview-make
                              :items (list (wf-manager--overview-item-make
                                            :member (wf-manager-overview-member-make
                                                     :kind "run" :value run))))))
         (wf-service--known-runs nil)
         (choices (wf-service-runs-choices session)))
    (should (equal (mapcar #'car choices) '("local:local_1 — /tmp/wf-local/" "service:run_21")))
    (should (eq (cddr (nth 0 choices)) local))
    (should (equal (cdr (nth 1 choices)) '(service . "run_21")))
    ;; A run whose view this Emacs opened stays a choice after it leaves
    ;; the overview, and a run of another endpoint is not a choice.
    (setq wf-service--known-runs '(("endpoint_other" . "run_9") ("endpoint_1" . "run_7")))
    (should (equal (mapcar #'car (wf-service-runs-choices session))
                   '("local:local_1 — /tmp/wf-local/" "service:run_7" "service:run_21")))
    (setq wf--sessions nil
          wf-service--known-runs nil)
    (setf (wf-manager-session-overview session) nil)
    (let ((wf--service-dispatch #'wf-service--dispatch)
          (wf-service--current (wf-service--state-make :file "profile" :session session)))
      (should (string-search "M-x wf-history lists every run"
                             (cadr (should-error (call-interactively #'wf-runs)
                                                 :type 'user-error)))))))

(defun wf-manager-tests--with-view (routes function)
  "Start service mode on a router of ROUTES and call FUNCTION.
The router answers the overview and the polling batches.  FUNCTION
receives the listener and the session, and service mode ends after it."
  (wf-manager-tests--call-session
   (apply #'wf-manager-tests--routes
          "/v1/snapshot" (list (wf-manager-tests--overview-page "s.1" nil 0 0 nil))
          "/v1/events?after=s.1" (list (wf-manager-tests--batch "s.1"))
          routes)
   (lambda (listener connection)
     (let* ((session nil)
            (overview (wf-manager-tests--outcome
                       (lambda (callback)
                         (setq session (wf-manager-session-start
                                        connection callback #'wf-service--changed)))))
            (wf-service--current (wf-service--state-make :file "profile" :session session))
            (wf--service-dispatch #'wf-service--dispatch))
       (should (wf-manager-overview-p overview))
       (unwind-protect
           (funcall function listener session)
         (wf-manager-session-close session))))))

(ert-deftest wf-service-view-follows-and-kill-sends-nothing ()
  "A run view follows a succeeded run to its verified result.
The kill of the view stops its watches and sends nothing, and the
function of `kill-emacs-hook' closes the transport and sends nothing."
  (let* ((digest (secure-hash 'sha256 wf-manager-tests--artifact))
         (run (replace-regexp-in-string
               "\"verification\":{\"state\":\"absent\"}"
               "\"verification\":{\"state\":\"verified\",\"artifactId\":\"artifact_1\"}"
               (wf-manager-tests--vector-json
                "resources.runs" "managed run with lost supervision keeps a sequence beyond 2^53")
               t t)))
    (wf-manager-tests--with-view
     (list "/v1/runs/run_21" (list (wf-manager-tests--json 200 run '("ETag: \"run_1\"")))
           "/v1/runs/run_21/snapshot"
           (list (wf-manager-tests--json
                  200 (concat "{\"version\":1,\"runtime\":{\"status\":\"succeeded\"},\"workflow\":\"wf_review\","
                              "\"verification\":{\"state\":\"verified\",\"artifactId\":\"artifact_1\"}}")
                  '("ETag: \"snap_1\"")))
           "/v1/runs/run_21/control"
           (list (wf-manager-tests--json
                  200 (wf-manager-tests--vector-json
                       "resources.controls" "lost controls keep false cancellation and a null head")
                  '("ETag: \"control_1\"")))
           "/v1/decisions?runId=run_21"
           (list (wf-manager-tests--json 200 (wf-manager-tests--queue-page)))
           "/v1/runs/run_21/outputs"
           (list (wf-manager-tests--json
                  200 (concat "{\"version\":1,\"runId\":\"run_21\",\"items\":[{\"kind\":\"result\","
                              "\"verification\":{\"state\":\"verified\",\"artifactId\":\"artifact_1\"},"
                              "\"artifact\":{\"id\":\"artifact_1\",\"download\":\"/v1/artifacts/artifact_1\","
                              "\"bytes\":\"" (number-to-string (length wf-manager-tests--artifact))
                              "\",\"sha256\":\"" digest "\"}}]}")))
           "/v1/artifacts/artifact_1" (list (wf-manager-tests--artifact-response)))
     (lambda (listener session)
       (let* ((buffer (wf-service-open-view session "run_21"))
              (view (buffer-local-value 'wf-service--view-state buffer)))
         (should (eq (buffer-local-value 'major-mode buffer) 'wf-service-run-mode))
         (should (eq (lookup-key wf-service-run-mode-map (kbd "a")) #'wf-answer))
         (should (eq (gethash (cons (wf-manager-session-identity session) "run_21") wf-service--views)
                     buffer))
         (should (eq (wf-service-open-view session "run_21") buffer))
         (unless (wf-manager-tests--wait
                  (lambda () (equal (car (last (wf-service-view-lines view)))
                                    (concat "Result SHA-256: " digest))))
           (ert-fail (list (wf-service-view-lines view) (wf-service--view-failures view)
                           (wf-manager-tests--listener-requests listener))))
         (with-current-buffer buffer
           (should (string-search "Supervision: lost\nVerification: verified\nDecisions: none pending\nOffers: none\nTerminal: succeeded\n"
                                  (buffer-string))))
         (should (= (wf-manager-tests--targets listener "/v1/artifacts/artifact_1") 1))
         (kill-buffer buffer)
         (should-not (gethash (cons (wf-manager-session-identity session) "run_21") wf-service--views))
         (should (equal (wf-manager-session-watched session) (list wf-manager-overview-resource)))
         (should (memq #'wf-service--kill-emacs kill-emacs-hook))
         (wf-service--kill-emacs)
         (should (wf-manager-session-closed session))
         (should (wf-manager-transport-closed (wf-manager-session-transport session)))
         (should (= (wf-manager-tests--posts listener) 0)))))))

(defun wf-manager-tests--answer-routes (decision-responses snapshot-responses)
  "Return the routes of an answer of decision_3 of run_21.
DECISION-RESPONSES and SNAPSHOT-RESPONSES are the responses of the
decision and of the run snapshot, in order."
  (list "/v1/decisions?runId=run_21"
        (list (wf-manager-tests--json
               200 (wf-manager-tests--queue-page
                    (wf-manager-tests--vector-json "resources.decisions"
                                                   wf-manager-tests--flag-decision))))
        wf-manager-tests--decision-uri decision-responses
        wf-manager-tests--control-uri
        (list (wf-manager-tests--json
               200 (wf-manager-tests--vector-json "resources.controls"
                                                  "owned controls with an answer offer")
               '("ETag: \"control_1\"")))
        wf-manager-tests--run-snapshot-uri snapshot-responses))

(defun wf-manager-tests--open-answer (session)
  "Run `wf-answer' in a view of run_21 on SESSION and return the editor.
The editor holds the text no."
  (clrhash wf-service--answer-drafts)
  (with-temp-buffer
    (setq-local wf-service--view-state
                (wf-service--view-make :session session :run "run_21"))
    (call-interactively #'wf-answer))
  (let ((editor (cl-find-if (lambda (buffer)
                              (string-prefix-p "*wf answer JSON*" (buffer-name buffer)))
                            (buffer-list))))
    (should editor)
    (with-current-buffer editor
      (should (equal (buffer-string) ""))
      (should (string-search "Answer of decision decision_3 (flag)" header-line-format))
      (insert "no"))
    editor))

(defun wf-manager-tests--submit (editor)
  "Submit the answer EDITOR and return its `user-error' or nil.
The submit is the command of the key that sends in the editor."
  (with-current-buffer editor
    (condition-case failure
        (progn (call-interactively (key-binding (kbd "C-c C-c"))) nil)
      (user-error (cadr failure)))))

(ert-deftest wf-service-answer-stale-keeps-draft ()
  "A 412 answer keeps the draft, reports it and sends nothing again.
The answer no is JSON false with the entity tag of the decision as
If-Match.  The decision then reads 404, so the report says that it is no
longer the head, and a second submit sends nothing."
  (wf-manager-tests--with-view
   (wf-manager-tests--answer-routes
    (list (wf-manager-tests--json
           200 (wf-manager-tests--vector-json "resources.decisions" wf-manager-tests--flag-decision)
           '("ETag: \"decision_1\""))
          (wf-manager-tests--json
           412 "{\"version\":1,\"status\":412,\"code\":\"stale-revision\",\"title\":\"Stale\"}")
          (wf-manager-tests--json
           404 "{\"version\":1,\"status\":404,\"code\":\"unavailable-resource\",\"title\":\"Gone\"}"))
    (list (wf-manager-tests--run-snapshot "snap_1" "waiting" t nil)))
   (lambda (listener session)
     (let* ((editor (wf-manager-tests--open-answer session))
            (report (wf-manager-tests--submit editor))
            (posted (car (cl-remove-if-not (lambda (request) (string-prefix-p "POST " request))
                                           (wf-manager-tests--listener-requests listener)))))
       (should (string-search "Decision decision_3 changed before the answer arrived (412 stale-revision).  Nothing was sent again.  The draft \"no\" is kept." report))
       (should (string-search "no longer the pending head (404 unavailable-resource), so the kept draft is not sent" report))
       (should (equal (wf-service-answer-draft (wf-manager-session-identity session) "decision_3") "no"))
       (should (= (wf-manager-tests--posts listener) 1))
       (should (equal (cdr (assoc "if-match" (wf-manager-tests--request-headers posted))) "\"decision_1\""))
       (should (equal (substring posted (+ 4 (string-search "\r\n\r\n" posted)))
                      "{\"generation\":\"generation_3\",\"occurrenceId\":\"0\",\"operation\":\"answer\",\"value\":false}"))
       (should (buffer-live-p editor))
       (should (string-search "changed before this answer arrived" (wf-manager-tests--submit editor)))
       (should (= (wf-manager-tests--posts listener) 1))
       (kill-buffer editor)
       (clrhash wf-service--answer-drafts)))))

(ert-deftest wf-service-answer-uncertain-reconciles-once ()
  "An uncertain answer is reconciled with one read and never sent again.
The connection of the answer closes with no response.  The run snapshot
after the send stores no, so the answer reached its effect, the editor
closes and the draft is gone."
  (wf-manager-tests--with-view
   (wf-manager-tests--answer-routes
    (list (wf-manager-tests--json
           200 (wf-manager-tests--vector-json "resources.decisions" wf-manager-tests--flag-decision)
           '("ETag: \"decision_1\""))
          'drop)
    (list (wf-manager-tests--run-snapshot "snap_1" "waiting" t nil)
          (wf-manager-tests--run-snapshot "snap_2" "completed" nil "no")))
   (lambda (listener session)
     (let ((editor (wf-manager-tests--open-answer session)))
       (should-not (wf-manager-tests--submit editor))
       (accept-process-output nil 0.2)
       (should-not (buffer-live-p editor))
       (should (= (wf-manager-tests--posts listener) 1))
       (should (= (wf-manager-tests--targets listener wf-manager-tests--run-snapshot-uri) 2))
       (should-not (wf-service-answer-draft (wf-manager-session-identity session) "decision_3"))))))

;;;; Results and history

(defun wf-manager-tests--outputs-response ()
  "Return the outputs response of run_21 with the verified test artifact."
  (wf-manager-tests--json
   200 (concat "{\"version\":1,\"runId\":\"run_21\",\"items\":[{\"kind\":\"result\","
               "\"verification\":{\"state\":\"verified\",\"artifactId\":\"artifact_1\"},"
               "\"artifact\":{\"id\":\"artifact_1\",\"download\":\"/v1/artifacts/artifact_1\","
               "\"bytes\":\"" (number-to-string (length wf-manager-tests--artifact))
               "\",\"sha256\":\"" (secure-hash 'sha256 wf-manager-tests--artifact) "\"}}]}")))

(defun wf-manager-tests--file-bytes (file)
  "Return the exact bytes of FILE as a unibyte string."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file)
    (buffer-string)))

(ert-deftest wf-service-result-saves-exact-bytes-once ()
  "`wf-result' saves the verified bytes unchanged to a new file with mode 0600.
A second save to the same file refuses, and the file stays as it is.
Neither save sends a command."
  (let* ((directory (make-temp-file "wf-result-" t))
         (file (expand-file-name "result.bin" directory)))
    (unwind-protect
        (wf-manager-tests--with-view
         (list "/v1/runs/run_21/outputs" (list (wf-manager-tests--outputs-response))
               "/v1/artifacts/artifact_1" (list (wf-manager-tests--artifact-response)))
         (lambda (listener session)
           (let ((view (generate-new-buffer " *wf result test*")))
             (unwind-protect
                 (with-current-buffer view
                   (setq-local wf-service--view-state
                               (wf-service--view-make :session session :run "run_21"))
                   (cl-letf (((symbol-function 'read-file-name) (lambda (&rest _) file)))
                     (should (equal (call-interactively #'wf-result) nil))
                     (should (equal (wf-manager-tests--file-bytes file) wf-manager-tests--artifact))
                     (should (= (file-modes file) #o600))
                     (should (= (file-attribute-size (file-attributes file))
                                (length wf-manager-tests--artifact)))
                     (let ((refusal (should-error (call-interactively #'wf-result)
                                                  :type 'user-error)))
                       (should (string-search "exists, so the result was not saved"
                                              (cadr refusal))))
                     (should (equal (wf-manager-tests--file-bytes file)
                                    wf-manager-tests--artifact))
                     (should (= (file-modes file) #o600))))
               (kill-buffer view))
             (should (= (wf-manager-tests--targets listener "/v1/runs/run_21/outputs") 2))
             (should (= (wf-manager-tests--posts listener) 0)))))
      (delete-directory directory t))))

(defun wf-manager-tests--run-json (case id)
  "Return the JSON text of the run vector CASE with the identifier ID."
  (string-replace "run_21" id (wf-manager-tests--vector-json "resources.runs" case)))

(defun wf-manager-tests--runs-page (index next &rest runs)
  "Return the response of page INDEX of a run page set of four items.
NEXT is the next page or nil, and RUNS are the JSON texts of the items."
  (wf-manager-tests--json
   200 (concat "{\"version\":1,\"page\":{\"setId\":\"set_r\",\"revision\":\"rev_r\","
               "\"expiresAt\":\"2999-01-01T00:00:00Z\",\"index\":" (number-to-string index)
               ",\"totalItems\":4,\"next\":" (if next (concat "\"" next "\"") "null")
               "},\"items\":[" (string-join runs ",") "]}")))

(defun wf-manager-tests--items-page (&rest items)
  "Return the response of a page set of one page with the JSON texts ITEMS."
  (wf-manager-tests--json
   200 (concat "{\"version\":1,\"page\":{\"setId\":\"set_i\",\"revision\":\"rev_i\","
               "\"expiresAt\":\"2999-01-01T00:00:00Z\",\"index\":0,\"totalItems\":"
               (number-to-string (length items)) ",\"next\":null},\"items\":["
               (string-join items ",") "]}")))

(defun wf-manager-tests--history-ids (buffer)
  "Return the run identifiers of the rows of the history BUFFER, top first."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (let ((ids nil))
        (while (not (eobp))
          (let ((entry (tabulated-list-get-id)))
            (when entry (push (wf-manager-run-id (cdr entry)) ids)))
          (forward-line 1))
        (nreverse ids)))))

(ert-deftest wf-service-history-lists-pages-and-keeps-the-endpoint ()
  "`wf-history' lists every run over every page in the order of the collection.
RET opens the view of a row with the reference of the row.  A row whose
reference names another endpoint refuses and sends nothing, and so
does a refresh of a history of another endpoint."
  (wf-manager-tests--with-view
   (list "/v1/runs"
         (list (wf-manager-tests--runs-page
                0 "/v1/runs?pageToken=p1"
                (wf-manager-tests--vector-json
                 "resources.runs" "managed run with lost supervision keeps a sequence beyond 2^53")
                (wf-manager-tests--run-json "legacy entry keeps null runtime and request"
                                            "run_legacy")))
         "/v1/runs?pageToken=p1"
         (list (wf-manager-tests--runs-page
                1 nil
                (wf-manager-tests--run-json
                 "fork run keeps sequence 2^64-1 and an unavailable result" "run_fork")
                (wf-manager-tests--vector-json "resources.runs" "unreadable manifest entry")))
         "/v1/runs/run_21"
         (list (wf-manager-tests--json
                200 (wf-manager-tests--vector-json
                     "resources.runs"
                     "managed run with lost supervision keeps a sequence beyond 2^53")))
         "/v1/workflows?profileId=profile_main"
         (list (wf-manager-tests--items-page
                "{\"id\":\"wf_review\",\"profileId\":\"profile_main\",\"name\":\"review\"}")))
   (lambda (listener session)
     (let ((history (progn (call-interactively #'wf-history) (current-buffer)))
           (identity (wf-manager-session-identity session)))
       (unwind-protect
           (progn
             (should (eq (buffer-local-value 'major-mode history) 'wf-service-history-mode))
             (should (equal (wf-manager-tests--history-ids history)
                            '("run_21" "run_legacy" "run_fork" "run_unreadable")))
             (with-current-buffer history
               (should (= (wf-service--history-pages wf-service--history-state) 2))
               (should (= (wf-service-history-observers wf-service--history-state) 1))
               (should (equal (mapcar (lambda (entry) (append (cadr entry) nil))
                                      tabulated-list-entries)
                              '(("run_21" "review" "profile_main" "running" "lost" "root" "absent")
                                ("run_legacy" "review" "profile_main" "no runtime evidence"
                                 "observer (legacy entry, read only)" "root" "verified")
                                ("run_fork" "review" "profile_main" "succeeded"
                                 "cleanup-pending" "fork of run_20" "unavailable")
                                ("run_unreadable" "" "profile_main"
                                 "unreadable (malformed-manifest)" "" "" ""))))
               (should (eq (lookup-key wf-service-history-mode-map (kbd "RET"))
                           #'wf-service-history-open))
               ;; RET on the first row opens the view of its run.
               (goto-char (point-min))
               (let ((view (wf-service-history-open)))
                 (should (eq (gethash (cons identity "run_21") wf-service--views) view))
                 ;; The read of the row, then the read of the watch of the view.
                 (should (wf-manager-tests--wait
                          (lambda () (= (wf-manager-tests--targets listener "/v1/runs/run_21") 2))))
                 (kill-buffer view)
                 ;; The open selected the view, so the history is made current again.
                 (set-buffer history))
               ;; A row of another endpoint refuses and reads nothing.
               (let ((reads (wf-manager-tests--targets listener "/v1/runs/run_21")))
                 (setf (car (car tabulated-list-entries))
                       (cons (wf-manager-reference-make :endpoint "endpoint_other"
                                                        :uri "/v1/runs/run_21")
                             (cdr (car (car tabulated-list-entries)))))
                 (tabulated-list-print t)
                 (goto-char (point-min))
                 (let ((refusal (should-error (wf-service-history-open) :type 'user-error)))
                   (should (string-search "Reference of another endpoint" (cadr refusal))))
                 (should-not (gethash (cons identity "run_21") wf-service--views))
                 (setf (wf-service--history-identity wf-service--history-state) "endpoint_other")
                 (let ((refusal (should-error (wf-service-history-refresh) :type 'user-error)))
                   (should (string-search "Nothing was read" (cadr refusal))))
                 (should (= (wf-manager-tests--targets listener "/v1/runs/run_21") reads))
                 (should (= (wf-manager-tests--targets listener "/v1/runs") 1))))
             (should (= (wf-manager-tests--posts listener) 0)))
         (kill-buffer history))))))

;;;; Controls

(defconst wf-manager-tests--offers-control
  "steer, redirect, recovery and retry offers keep maximum addresses and Unicode targets"
  "The controls vector of run_21 with steer, redirect, recovery and retry offers.")

(defun wf-manager-tests--offered-recovery ()
  "Return the JSON text of the recovery head of the controls with every offer.
It is the recovery decisions vector at occurrence 3 and generation_4,
whose fail-over target is backup, as the offers of that control state."
  (let ((text (wf-manager-tests--vector-json
               "resources.decisions" "recovery decision keeps null and named targets")))
    (dolist (edit '(("{\"occurrenceId\":\"0\"}" . "{\"occurrenceId\":\"3\"}")
                    ("\"generation_3\"" . "\"generation_4\"")
                    ("\"scripted-backup\"" . "\"backup\"")))
      (setq text (string-replace (car edit) (cdr edit) text)))
    text))

(defun wf-manager-tests--control-view (session)
  "Return a temporary buffer whose run view of run_21 is on SESSION."
  (let ((buffer (generate-new-buffer " *wf control test*")))
    (with-current-buffer buffer
      (setq-local wf-service--view-state (wf-service--view-make :session session :run "run_21")))
    buffer))

(ert-deftest wf-service-control-choices-are-the-offers ()
  "`wf-control' lists only what the controls offer.
The owned controls allow a cancel, offer two timings of one steer, two
targets of one redirect, and the retry and the fail-over to backup of
the recovery head.  The head also names abandon, which no offer
carries, so it is not listed.  A question head and lost controls give
no recovery choice and no control."
  (let* ((control (wf-manager-decode-control
                   (wf-manager-tests--resource "resources.controls" wf-manager-tests--offers-control)))
         (decision (wf-manager-decode-decision
                    (wf-manager-json-decode (wf-manager-tests--offered-recovery))))
         (snapshot (wf-manager-json-decode
                    (concat "{\"items\":[{\"occurrenceId\":\"4\",\"dispatch\":{\"open\":false},"
                            "\"attempts\":[{\"state\":\"running\",\"address\":"
                            "{\"occurrenceId\":\"4\",\"attemptId\":\"2\"}}]}]}"))))
    (should (equal (mapcar (lambda (choice)
                             (list (car choice) (cadr choice) (plist-get (cddr choice) :operation)))
                           (wf-service-control-choices "run_21" control decision snapshot))
                   '(("cancel" "cancel run run_21 after a confirmation" "cancel")
                     ("steer:1" "steer occurrence 18446744073709551615 attempt 4294967295, interrupt-now" "steer")
                     ("steer:2" "steer occurrence 18446744073709551615 attempt 4294967295, next-boundary" "steer")
                     ("redirect:1" "redirect occurrence 4 to agent 雪 [model:alt], attempt 2 in flight" "redirect")
                     ("redirect:2" "redirect occurrence 4 to , attempt 2 in flight" "redirect")
                     ("retry" "retry of decision decision_3, occurrence 3" "retry")
                     ("failover:1" "failover to backup of decision decision_3, occurrence 3"
                      "choose-recovery"))))
    (should (equal (mapcar #'car (wf-service-control-choices
                                  "run_21" control
                                  (wf-manager-decode-decision
                                   (wf-manager-tests--resource "resources.decisions"
                                                               wf-manager-tests--flag-decision))
                                  nil))
                   '("cancel" "steer:1" "steer:2" "redirect:1" "redirect:2")))
    (should-not (wf-service-control-choices
                 "run_21"
                 (wf-manager-decode-control
                  (wf-manager-tests--resource "resources.controls"
                                              "lost controls keep false cancellation and a null head"))
                 nil nil))))

(ert-deftest wf-service-kill-confirms-before-the-cancel ()
  "`wf-kill' sends the cancel only after a yes to its confirmation.
A no sends nothing.  A yes sends one cancel with the entity tag of the
controls as If-Match, and the cancel completes on the runtime
acknowledgement that accepts it."
  (wf-manager-tests--with-view
   (list wf-manager-tests--control-uri
         (let ((control (wf-manager-tests--json
                         200 (wf-manager-tests--vector-json "resources.controls"
                                                            "owned controls with an answer offer")
                         '("ETag: \"control_1\""))))
           (list control control
                 (wf-manager-tests--json
                  202 (string-replace
                       "\"command\":\"steer\",\"occurrenceId\":\"18446744073709551615\",\"attemptId\":\"4294967295\""
                       "\"command\":\"cancel\",\"occurrenceId\":null,\"attemptId\":null"
                       (string-replace
                        "\"state\":\"delivered\"" "\"state\":\"accepted\""
                        (string-replace
                         "\"operation\":\"steer\"" "\"operation\":\"cancel\""
                         (wf-manager-tests--vector-json
                          "resources.receipts" "acknowledged steer receipt keeps maximum addresses"))))
                  '("Location: /v1/commands/cmd_11")))))
   (lambda (listener session)
     (let ((view (wf-manager-tests--control-view session))
           (prompts nil))
       (unwind-protect
           (with-current-buffer view
             (let ((wf-confirm-function (lambda (prompt) (push prompt prompts) nil)))
               (call-interactively #'wf-kill))
             (should (= (wf-manager-tests--posts listener) 0))
             (let ((wf-confirm-function (lambda (prompt) (push prompt prompts) t)))
               (call-interactively #'wf-kill))
             (should (equal prompts (make-list 2 "Cancel run run_21 of the manager? ")))
             (should (= (wf-manager-tests--posts listener) 1))
             (let ((posted (car (cl-remove-if-not (lambda (request) (string-prefix-p "POST " request))
                                                  (wf-manager-tests--listener-requests listener)))))
               (should (equal (cdr (assoc "if-match" (wf-manager-tests--request-headers posted)))
                              "\"control_1\""))
               (should (equal (substring posted (+ 4 (string-search "\r\n\r\n" posted)))
                              "{\"operation\":\"cancel\"}"))))
         (kill-buffer view))))))

(ert-deftest wf-service-control-steer-uncertain-reconciles-once ()
  "An uncertain steer is reconciled with one read and never sent again.
`wf-control' lists the offered controls, and the chosen steer opens its
editor.  The connection of the steer closes with no response, and one
read of the controls shows no effect, so the steer stays uncertain.  A
second send key in the editor refuses and sends nothing."
  (wf-manager-tests--with-view
   (list wf-manager-tests--control-uri
         (list (wf-manager-tests--json
                200 (wf-manager-tests--vector-json "resources.controls" wf-manager-tests--offers-control)
                '("ETag: \"control_1\""))
               'drop
               (wf-manager-tests--json
                200 (wf-manager-tests--vector-json "resources.controls" wf-manager-tests--offers-control)
                '("ETag: \"control_2\"")))
         wf-manager-tests--decision-uri
         (list (wf-manager-tests--json 200 (wf-manager-tests--offered-recovery)
                                       '("ETag: \"decision_1\"")))
         wf-manager-tests--run-snapshot-uri
         (list (wf-manager-tests--run-snapshot "snap_1" "waiting" nil nil)))
   (lambda (listener session)
     (let ((view (wf-manager-tests--control-view session))
           (listed nil)
           (editor nil))
       (unwind-protect
           (progn
             (with-current-buffer view
               (cl-letf (((symbol-function 'completing-read)
                          (lambda (_prompt collection &rest _)
                            (setq listed (mapcar #'car collection))
                            "steer:1")))
                 (call-interactively #'wf-control)))
             (should (equal listed '("cancel" "steer:1" "steer:2" "redirect:1" "redirect:2"
                                     "retry" "failover:1")))
             (setq editor (get-buffer "*wf steer run_21*"))
             (should editor)
             (with-current-buffer editor
               (should (string-search "Steer interrupt-now of occurrence 18446744073709551615 attempt 4294967295"
                                      header-line-format))
               (insert "Focus on the patch."))
             (should (string-search "The outcome of the steer of run run_21 is uncertain after one read"
                                    (wf-manager-tests--submit editor)))
             (accept-process-output nil 0.2)
             (should (= (wf-manager-tests--posts listener) 1))
             (let ((posted (car (cl-remove-if-not (lambda (request) (string-prefix-p "POST " request))
                                                  (wf-manager-tests--listener-requests listener)))))
               (should (equal (cdr (assoc "if-match" (wf-manager-tests--request-headers posted)))
                              "\"control_1\""))
               (should (equal (substring posted (+ 4 (string-search "\r\n\r\n" posted)))
                              (concat "{\"attemptId\":\"4294967295\",\"occurrenceId\":\"18446744073709551615\","
                                      "\"operation\":\"steer\",\"text\":\"Focus on the patch.\","
                                      "\"timing\":\"interrupt-now\"}"))))
             (should (= (wf-manager-tests--targets listener wf-manager-tests--control-uri) 3))
             (should (buffer-live-p editor))
             (should (string-search "sent one time" (wf-manager-tests--submit editor)))
             (should (= (wf-manager-tests--posts listener) 1)))
         (kill-buffer view)
         (when (buffer-live-p editor) (kill-buffer editor)))))))

;;;; Lineage and exports

(defun wf-manager-tests--collection-page (run revision fields items)
  "Return the JSON text of the first page of a collection of RUN.
REVISION is the page revision, FIELDS the JSON text of the other members
after the run, each with a leading comma, and ITEMS the JSON texts of
the items."
  (concat "{\"version\":1,\"runId\":\"" run "\"" fields ",\"page\":{\"setId\":\"set_c\","
          "\"revision\":\"" revision "\",\"expiresAt\":\"2999-01-01T00:00:00Z\",\"index\":0,"
          "\"totalItems\":" (number-to-string (length items)) ",\"next\":null},\"items\":["
          (string-join items ",") "]}"))

(defun wf-manager-tests--lineage-page (revision eligible refusal &rest children)
  "Return the response of the lineage collection of run_21 with REVISION.
ELIGIBLE is the JSON text of the eligible operations, REFUSAL the JSON
text of the refusal, and CHILDREN the JSON texts of the child requests.
The entity tag is the strong tag of REVISION."
  (wf-manager-tests--json
   200 (wf-manager-tests--collection-page
        "run_21" revision (concat ",\"eligible\":" eligible ",\"refusal\":" refusal) children)
   (list (concat "ETag: \"" revision "\""))))

(defun wf-manager-tests--child-json (phase)
  "Return the JSON text of the fork child req_9 of run_21 in PHASE.
Its one input comes from the parent run, so no input is missing."
  (let ((draft (wf-manager-tests--vector-json "resources.drafts"
                                              "associated lineage request keeps empty literal text")))
    (dolist (edit `(("req_8" . "req_9")
                    ("\"phase\":\"associated\"" . ,(format "\"phase\":\"%s\"" phase))
                    ("\"state\":\"reserved\"" . ,(if (equal phase "draft")
                                                     "\"state\":\"not-queued\""
                                                   "\"state\":\"waiting\""))
                    ("\"preparationId\":\"prep_9\",\"runId\":\"run_22\""
                     . "\"preparationId\":null,\"runId\":null"))
                  draft)
      (should (string-search (car edit) draft))
      (setq draft (string-replace (car edit) (cdr edit) draft)))))

(defconst wf-manager-tests--fork-snapshot
  (concat "{\"version\":1,\"runtime\":{\"status\":\"succeeded\"},\"items\":["
          "{\"occurrenceId\":\"2\",\"state\":\"waiting\",\"code\":\"text\",\"intent\":\"Later\",\"answer\":null},"
          "{\"occurrenceId\":\"1\",\"state\":\"reused\",\"code\":\"flag\",\"intent\":\"Approve?\",\"answer\":\"yes\"},"
          "{\"occurrenceId\":\"0\",\"state\":\"completed\",\"code\":\"text\",\"intent\":\"Ask\\nagain\",\"answer\":\"old\"},"
          "{\"occurrenceId\":\"01\",\"state\":\"completed\",\"code\":\"text\",\"intent\":\"Bad\",\"answer\":\"x\"}]}")
  "The JSON text of a run snapshot with two fork targets, 0 and 1.
Occurrence 2 still waits, and the identifier 01 is not canonical.")

(defun wf-manager-tests--post-body (listener &optional target)
  "Return the body of the last POST of LISTENER and its If-Match.
With TARGET, the POST is the last POST of that request target."
  (let ((posted (car (cl-remove-if-not
                      (lambda (request)
                        (string-prefix-p (concat "POST " (or target "")) request))
                      (wf-manager-tests--listener-requests listener)))))
    (list (substring posted (+ 4 (string-search "\r\n\r\n" posted)))
          (cdr (assoc "if-match" (wf-manager-tests--request-headers posted))))))

(ert-deftest wf-manager-lineage-and-export-decoders ()
  "Decode the lineage and export collections and build their bodies.
A lineage page states a refusal exactly when it lists no eligible
operation, and each child names the parent.  An export receipt has a
valid single-component name.  The fork body orders its edits by
occurrence, and a fork replacement is typed by the code of its
occurrence."
  (let* ((child (wf-manager-tests--child-json "draft"))
         (page (wf-manager-decode-lineage-collection
                (wf-manager-json-decode
                 (wf-manager-tests--collection-page
                  "run_21" "lineage_rev_1" ",\"eligible\":[\"restart\",\"fork\"],\"refusal\":null"
                  (list child))))))
    (should (equal (wf-manager-lineage-collection-run-id page) "run_21"))
    (should (equal (wf-manager-lineage-collection-revision page) "lineage_rev_1"))
    (should (equal (wf-manager-lineage-collection-eligible page) '("restart" "fork")))
    (should (null (wf-manager-lineage-collection-refusal page)))
    (should (equal (mapcar #'wf-manager-draft-id (wf-manager-lineage-collection-children page))
                   '("req_9")))
    (should (equal (wf-manager-lineage-collection-refusal
                    (wf-manager-decode-lineage-collection
                     (wf-manager-json-decode
                      (wf-manager-tests--collection-page
                       "run_21" "lineage_rev_1" ",\"eligible\":[],\"refusal\":\"quarantined\"" nil))))
                   "quarantined"))
    (dolist (fields '(",\"eligible\":[],\"refusal\":null"
                      ",\"eligible\":[\"restart\"],\"refusal\":\"quarantined\""
                      ",\"eligible\":[\"restart\",\"restart\"],\"refusal\":null"
                      ",\"eligible\":[\"rerun\"],\"refusal\":null"))
      (should (eq (car (should-error
                        (wf-manager-decode-lineage-collection
                         (wf-manager-json-decode
                          (wf-manager-tests--collection-page "run_21" "lineage_rev_1" fields nil)))))
                  'wf-manager-invalid-response)))
    ;; A child of another parent refuses.
    (should-error (wf-manager-decode-lineage-collection
                   (wf-manager-json-decode
                    (wf-manager-tests--collection-page
                     "run_7" "lineage_rev_1" ",\"eligible\":[\"restart\"],\"refusal\":null"
                     (list child))))
                  :type 'wf-manager-invalid-response))
  (let* ((digest (make-string 64 ?b))
         (item (concat "{\"version\":1,\"id\":\"export_cmd_11\",\"runId\":\"run_21\","
                       "\"commandId\":\"cmd_11\",\"name\":\"result.v1_x-y\",\"code\":\"text\","
                       "\"state\":\"published\",\"sha256\":\"" digest "\",\"bytes\":\"67108864\","
                       "\"download\":\"/v1/artifacts/artifact_1\"}"))
         (page (wf-manager-decode-export-collection
                (wf-manager-json-decode
                 (wf-manager-tests--collection-page "run_21" "export_rev_1" "" (list item)))))
         (receipt (car (wf-manager-export-collection-items page))))
    (should (equal (wf-manager-export-collection-revision page) "export_rev_1"))
    (should (equal (wf-manager-export-receipt-name receipt) "result.v1_x-y"))
    (should (equal (wf-manager-export-receipt-sha256 receipt) digest))
    (should (equal (wf-manager-export-receipt-download receipt) "/v1/artifacts/artifact_1"))
    (should (equal (wf-manager-export-receipt-bytes receipt) 67108864))
    ;; A size above the largest exported document refuses.
    (dolist (edit '(("result.v1_x-y" . "../result") ("\"published\"" . "\"lost\"")
                    ("\"sha256\":\"b" . "\"sha256\":\"B") ("67108864" . "67108865")))
      (should-error (wf-manager-decode-export-receipt
                     (wf-manager-json-decode (string-replace (car edit) (cdr edit) item)))
                    :type 'wf-manager-invalid-response))
    (should-error (wf-manager-decode-export-collection
                   (wf-manager-json-decode
                    (wf-manager-tests--collection-page "run_7" "export_rev_1" "" (list item))))
                  :type 'wf-manager-invalid-response))
  (should (wf-manager-export-name-valid-p "a"))
  (should (wf-manager-export-name-valid-p (make-string 128 ?z)))
  (dolist (name (list "" ".hidden" "a/b" "a b" "é" (make-string 129 ?z)))
    (should-not (wf-manager-export-name-valid-p name)))
  (should (equal (wf-manager-json-encode (wf-manager-lineage-body "restart"))
                 "{\"operation\":\"restart\"}"))
  (should (equal (wf-manager-json-encode
                  (wf-manager-lineage-body
                   "fork" (list (wf-manager-fork-edit-make :operation "drop"
                                                           :occurrence-id 18446744073709551615)
                                (wf-manager-fork-edit-make :operation "replace" :occurrence-id 2
                                                           :answer :false))))
                 (concat "{\"edits\":[{\"answer\":false,\"occurrenceId\":\"2\",\"operation\":\"replace\"},"
                         "{\"occurrenceId\":\"18446744073709551615\",\"operation\":\"drop\"}],"
                         "\"operation\":\"fork\"}")))
  (should (equal (wf-manager-fork-replacement-value "text" " as typed ") " as typed "))
  (should (eq (wf-manager-fork-replacement-value "flag" "No") :false))
  (should (eq (wf-manager-fork-replacement-value "ack" "") :null))
  (should (wf-manager-json-equal (wf-manager-fork-replacement-value "structured" "{\"a\":[1]}")
                                 (wf-manager-json-decode "{\"a\":[1]}")))
  (should-error (wf-manager-fork-replacement-value "flag" "maybe") :type 'wf-manager-invalid-answer)
  (should-error (wf-manager-fork-replacement-value "ack" "x") :type 'wf-manager-invalid-answer))

(ert-deftest wf-service-fork-sends-the-snapshot-edits-and-opens-the-review ()
  "`wf-fork' edits the answers of the fork targets of the snapshot.
The targets are the completed and reused occurrences in occurrence
order.  A replacement starts from the published answer, and a refused
text is read again.  The one lineage request carries the typed edits in
occurrence order and binds the entity tag of the lineage collection.
The child is enqueued without set-input, and its exact review opens."
  (let ((reviewed nil) (labels nil) (prompts nil) (initials nil))
    (wf-manager-tests--with-view
     (list "/v1/runs/run_21/lineage-requests"
           (list (wf-manager-tests--lineage-page "lineage_rev_1" "[\"restart\",\"resume\",\"fork\"]" "null")
                 (wf-manager-tests--json
                  202 (wf-manager-tests--vector-json "resources.receipts"
                                                     "effect-observed lineage-created receipt")
                  '("Location: /v1/commands/cmd_11")))
           "/v1/runs/run_21/snapshot"
           (list (wf-manager-tests--json 200 wf-manager-tests--fork-snapshot '("ETag: \"snap_1\"")))
           "/v1/requests/req_9"
           (let ((draft (wf-manager-tests--json 200 (wf-manager-tests--child-json "draft")
                                                '("ETag: \"request_rev_1\""))))
             (list draft draft
                   (wf-manager-tests--json
                    202 (string-replace "req_8" "req_9"
                                        (wf-manager-tests--vector-json "resources.receipts"
                                                                       "effect-observed enqueued receipt"))
                    '("Location: /v1/commands/cmd_11"))
                   (wf-manager-tests--json 200 (wf-manager-tests--child-json "queued")
                                           '("ETag: \"request_rev_2\"")))))
     (lambda (listener session)
       (let ((view (wf-manager-tests--control-view session))
             (picks (list "occurrence:1" "drop" "occurrence:1" "keep" "occurrence:0" "replace"
                          "occurrence:1" "replace" "occurrence:0" "replace" "send"))
             (typed (list "Forked text" "maybe" "no" "Forked again")))
         (unwind-protect
             (with-current-buffer view
               (cl-letf (((symbol-function 'completing-read)
                          (lambda (prompt collection &rest _)
                            (push prompt prompts)
                            (push (mapcar (lambda (choice) (if (consp choice) (car choice) choice))
                                          collection)
                                  labels)
                            (pop picks)))
                         ((symbol-function 'read-from-minibuffer)
                          (lambda (_prompt initial &rest _)
                            (push initial initials)
                            (pop typed)))
                         ((symbol-function 'wf-service--open-review)
                          (lambda (_session reference)
                            (setq reviewed (wf-manager-reference-uri reference)))))
                 (call-interactively #'wf-fork)))
           (kill-buffer view))
         (should (equal reviewed "/v1/requests/req_9"))
         (should (equal (car (last labels)) '("occurrence:0" "occurrence:1" "send" "stop")))
         (should (equal (car (last prompts)) "Fork edits of run run_21: "))
         (should (member "Answer of occurrence 1 of run run_21: " prompts))
         ;; The first replacement of occurrence 0 starts from its answer,
         ;; the second from the first replacement.  The refused flag text
         ;; is read again with the text.
         (should (equal (reverse initials) '("old" "yes" "maybe" "Forked text")))
         (should (= (wf-manager-tests--posts listener) 2))
         (let ((requests (wf-manager-tests--listener-requests listener)))
           (should (equal (wf-manager-tests--post-body listener "/v1/runs/run_21/lineage-requests ")
                          (list (concat "{\"edits\":[{\"answer\":\"Forked again\",\"occurrenceId\":\"0\","
                                        "\"operation\":\"replace\"},{\"answer\":false,\"occurrenceId\":\"1\","
                                        "\"operation\":\"replace\"}],\"operation\":\"fork\"}")
                                "\"lineage_rev_1\"")))
           (should (equal (car (wf-manager-tests--post-body listener))
                          "{\"operation\":\"enqueue\"}"))
           (should (= (cl-count-if (lambda (request) (string-prefix-p "POST /v1/requests/req_9" request))
                                   requests)
                      1))))))))

(ert-deftest wf-service-lineage-refuses-an-operation-that-is-not-eligible ()
  "`wf-restart' and `wf-rerun' send nothing when the manager lists no restart."
  (wf-manager-tests--with-view
   (list "/v1/runs/run_21/lineage-requests"
         (list (wf-manager-tests--lineage-page "lineage_rev_1" "[]" "\"quarantined\"")))
   (lambda (listener session)
     (let ((view (wf-manager-tests--control-view session)))
       (unwind-protect
           (with-current-buffer view
             (dolist (command '(wf-restart wf-rerun))
               (should (string-search
                        "restart is not eligible: the manager lists no lineage operation for run run_21, refusal quarantined"
                        (cadr (should-error (call-interactively command) :type 'user-error))))))
         (kill-buffer view))
       (should (= (wf-manager-tests--targets listener "/v1/runs/run_21/lineage-requests") 2))
       (should (= (wf-manager-tests--posts listener) 0))))))

(ert-deftest wf-service-lineage-reads-again-after-a-transient-refusal ()
  "`wf-restart' reads the lineage collection again after 429 storage-quota.
The manager refuses the first read because the client holds its two
active page sets.  The second read gives the page, and the command acts
on it.  Nothing is sent."
  (wf-manager-tests--with-view
   (list "/v1/runs/run_21/lineage-requests"
         (list (wf-manager-tests--json
                429 "{\"version\":1,\"status\":429,\"code\":\"storage-quota\",\"title\":\"Too Many Requests\"}")
               (wf-manager-tests--lineage-page "lineage_rev_1" "[]" "\"quarantined\"")))
   (lambda (listener session)
     (let ((view (wf-manager-tests--control-view session)))
       (unwind-protect
           (with-current-buffer view
             (should (string-search
                      "restart is not eligible: the manager lists no lineage operation for run run_21, refusal quarantined"
                      (cadr (should-error (call-interactively #'wf-restart) :type 'user-error)))))
         (kill-buffer view))
       (should (= (wf-manager-tests--targets listener "/v1/runs/run_21/lineage-requests") 2))
       (should (= (wf-manager-tests--posts listener) 0))))))

(ert-deftest wf-service-export-shows-the-receipt-and-the-verified-download ()
  "`wf-export' exports a run with the entity tag of its export collection.
A name that is not one component refuses before any read.  The export
is sent one time, and the command shows the published receipt, the
verified download and the export collection.  Local mode refuses."
  (let* ((digest (secure-hash 'sha256 wf-manager-tests--artifact))
         (item (concat "{\"version\":1,\"id\":\"export_cmd_11\",\"runId\":\"run_21\","
                       "\"commandId\":\"cmd_11\",\"name\":\"result.json\",\"code\":\"text\","
                       "\"state\":\"published\",\"sha256\":\"" digest "\",\"bytes\":\""
                       (number-to-string (length wf-manager-tests--artifact)) "\","
                       "\"download\":\"/v1/artifacts/artifact_1\"}")))
    (should (string-search "works only in service mode"
                           (cadr (should-error (let ((wf--service-dispatch nil))
                                                 (call-interactively #'wf-export))
                                               :type 'user-error))))
    (wf-manager-tests--with-view
     (list "/v1/runs/run_21/exports"
           (list (wf-manager-tests--json
                  200 (wf-manager-tests--collection-page "run_21" "export_rev_1" "" nil)
                  '("ETag: \"export_rev_1\""))
                 (wf-manager-tests--json
                  202 (wf-manager-tests--vector-json "resources.receipts" "effect-observed exported receipt")
                  '("Location: /v1/commands/cmd_11"))
                 (wf-manager-tests--json
                  200 (wf-manager-tests--collection-page "run_21" "export_rev_2" "" (list item))
                  '("ETag: \"export_rev_2\"")))
           "/v1/exports/export_cmd_11" (list (wf-manager-tests--json 200 item))
           "/v1/artifacts/artifact_1" (list (wf-manager-tests--artifact-response)))
     (lambda (listener session)
       (let ((view (wf-manager-tests--control-view session))
             (names (list "../result" "result.json"))
             (buffer nil))
         (unwind-protect
             (with-current-buffer view
               (cl-letf (((symbol-function 'read-string) (lambda (&rest _) (pop names))))
                 (should (string-search "The export name must be 1 to 128"
                                        (cadr (should-error (call-interactively #'wf-export)
                                                            :type 'user-error))))
                 (should (= (wf-manager-tests--targets listener "/v1/runs/run_21/exports") 0))
                 (setq buffer (call-interactively #'wf-export))))
           (kill-buffer view))
         (should (equal (buffer-name buffer) "*wf export run_21/result.json*"))
         (should (equal (with-current-buffer buffer
                          (buffer-substring-no-properties (point-min) (point-max)))
                        (concat "Export result.json: export_cmd_11 state published, command cmd_11\n"
                                "Export download: verified 8 bytes, SHA-256 " digest "\n"
                                "Exports of run run_21: 1\n"
                                "  result.json  export_cmd_11  published  8 bytes  SHA-256 " digest "\n")))
         (kill-buffer buffer)
         (should (= (wf-manager-tests--posts listener) 1))
         (should (equal (wf-manager-tests--post-body listener)
                        (list "{\"name\":\"result.json\"}" "\"export_rev_1\"")))
         (should (= (wf-manager-tests--targets listener "/v1/artifacts/artifact_1") 1)))))))

(ert-deftest wf-service-export-uncertain-reconciles-once ()
  "An uncertain export is reconciled with one read and never sent again.
The connection of the export closes with no response.  One read of the
export collection lists the published export of the name with a new
entity tag, so the effect is observed, and the command reports that no
receipt names the export."
  (let ((item (concat "{\"version\":1,\"id\":\"export_cmd_11\",\"runId\":\"run_21\","
                      "\"commandId\":\"cmd_11\",\"name\":\"result.json\",\"code\":\"text\","
                      "\"state\":\"published\",\"sha256\":\"" (make-string 64 ?c) "\",\"bytes\":\"8\","
                      "\"download\":\"/v1/artifacts/artifact_1\"}")))
    (wf-manager-tests--with-view
     (list "/v1/runs/run_21/exports"
           (list (wf-manager-tests--json
                  200 (wf-manager-tests--collection-page "run_21" "export_rev_1" "" nil)
                  '("ETag: \"export_rev_1\""))
                 'drop
                 (wf-manager-tests--json
                  200 (wf-manager-tests--collection-page "run_21" "export_rev_2" "" (list item))
                  '("ETag: \"export_rev_2\""))))
     (lambda (listener session)
       (let ((view (wf-manager-tests--control-view session)))
         (unwind-protect
             (with-current-buffer view
               (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "result.json")))
                 (should (string-search "reached its effect, and no receipt names its export"
                                        (cadr (should-error (call-interactively #'wf-export)
                                                            :type 'user-error))))))
           (kill-buffer view))
         (accept-process-output nil 0.2)
         (should (= (wf-manager-tests--posts listener) 1))
         (should (= (wf-manager-tests--targets listener "/v1/runs/run_21/exports") 3))
         (should (= (wf-manager-tests--targets listener "/v1/exports/export_cmd_11") 0)))))))

(provide 'wf-manager-tests)

;;; wf-manager-tests.el ends here
