;;; wf-manager-tests.el --- ERT tests for wf-manager.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 John Wiegley

;; Author: John Wiegley <johnw@newartisans.com>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The fourth pass of `ci/emacs.sh'.  These tests load client profiles
;; from temporary files and check the rules of `wf-manager-profile-load':
;; the four fields, the endpoint, the absolute paths, the size bounds, the
;; private credential file and the typed refusals.  They start no process
;; and contact no host.
;;
;; Run them by hand, from the repository root:
;;
;;     "$EMACS" -Q --batch -L ./emacs -l ./emacs/wf-manager-tests.el \
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

(provide 'wf-manager-tests)

;;; wf-manager-tests.el ends here
