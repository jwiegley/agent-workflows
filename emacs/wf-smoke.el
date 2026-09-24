;;; wf-smoke.el --- Batch smoke for wf.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 John Wiegley

;; Author: John Wiegley <johnw@newartisans.com>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The third gate of `ci/emacs.sh', after byte-compilation and checkdoc, and
;; the only one of the three that runs any of this code.  It loads `wf.el',
;; asks the REAL `wf' binary for the row listing, and asserts the facts the
;; package's contract rests on — the ones a reworded prompt or a moved number
;; would not move, and a wrong refactor would:
;;
;;   * the listing parses, is cached per connection, and `wf-refresh' forgets it
;;   * `@' hands off to file-name completion, and does so after the `@'
;;   * the agent-deck listing keeps stdout and stderr apart, so a narrated
;;     line on stderr costs no session
;;   * a missing or silent agent-deck degrades to nil AND says why
;;   * native preparation freezes the reviewed root, and approval starts that
;;     same process; refusal creates no run files
;;   * a row and an input are joined into a history symbol by something
;;     neither name can contain
;;
;; Not covered, and honestly: the per-input `M-p' history and the last-answer
;; default.  Emacs records no minibuffer history in batch, so what runs here is
;; the shape of the histories and not the walking of them.  See the README.
;;
;; Run it through the gate:
;;
;;     ./ci/emacs.sh
;;
;; or by hand, from the repository root, with the binary named:
;;
;;     WF=$PWD/dist-newstyle/…/wf "$EMACS" -Q --batch -l emacs/wf-smoke.el

;;; Code:

(require 'seq)
(require 'subr-x)
;; For `cl-letf' alone: one command here reads its row from the minibuffer, and
;; batch has no minibuffer to read from.  `wf.el' itself requires neither.
(require 'cl-lib)
(require 'ert)

;; An error out of `wf.el' itself — no binary, no JSON — is a sentence that
;; package took care to write, and batch Emacs would otherwise bury it under a
;; backtrace holding the macroexpansion of this whole file.
(setq backtrace-on-error-noninteractive nil)

;; Self-locating, so that `-l emacs/wf-smoke.el' is enough from anywhere: the
;; package under test is the one beside this file, never one already installed.
(defvar wf-smoke-dir
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "The directory this smoke lives in, which is also `wf.el's.")

(add-to-list 'load-path wf-smoke-dir)
(require 'wf)

(defvar wf-smoke-checks 0
  "How many facts this run has asserted so far.")

(defun wf-smoke-assert (ok fact &rest args)
  "Unless OK, stop the gate, having reported FACT formatted with ARGS.
A held fact prints one line and a failed one prints one line and exits
1.  This is deliberately not `cl-assert': in batch that prints the
macroexpansion of every form around the failure, which buries the one
sentence a reader needs.  Each fact is therefore written to name the
value it claims, and to read correctly whether or not it held."
  (let ((said (apply #'format fact args)))
    (cond
     (ok (setq wf-smoke-checks (1+ wf-smoke-checks))
         (princ (format "  ok    %s\n" said)))
     (t (princ (format "  FAIL  %s\n" said))
        (kill-emacs 1)))))

(defun wf-smoke-binary ()
  "The `wf' binary to test against, or a `user-error' naming how to get one.
$WF wins, so the gate can name a binary it just built.  Failing that,
the build tree beside this package is globbed — which is where a
`cabal build' leaves it, and the only place worth guessing."
  (let ((named (getenv "WF")))
    (cond
     ((and named (not (equal named "")) (file-executable-p named))
      (expand-file-name named))
     ((and named (not (equal named "")))
      (user-error "WF names `%s', which is not an executable file" named))
     (t
      (let* ((root (expand-file-name ".." wf-smoke-dir))
             (glob (expand-file-name
                    "dist-newstyle/build/*/*/*/x/wf/build/wf/wf" root))
             (found (seq-filter #'file-executable-p
                                (file-expand-wildcards glob))))
        (or (car found)
            (user-error
             "No `wf' binary: set $WF, or `cabal build exe:wf' to leave one at %s"
             (file-relative-name glob root))))))))

(defun wf-smoke-control-binary ()
  "Return the explicit native human/control fixture required by this gate."
  (let ((runner (or (getenv "WF_CONTROL_RUNNER")
                    (executable-find "routing-fixed-point-probe"))))
    (unless (and runner (file-executable-p runner))
      (user-error "Set $WF_CONTROL_RUNNER to a compatible routing-fixed-point-probe"))
    (expand-file-name runner)))

(defun wf-smoke-fake-deck (script)
  "Write SCRIPT to a temporary executable file and return its name.
Stands in for `agent-deck' so that this gate can decide for itself what
the listing says on each of its two streams."
  (let ((file (make-temp-file "wf-smoke-deck" nil ".sh" script)))
    (set-file-modes file #o755)
    file))


;;; Native setup component

(defun wf-smoke-setup (row edit)
  "Drive ROW's real form with EDIT in place of its recursive command loop.
Forbid process creation throughout setup; existing CLI smoke runs separately."
  (cl-letf (((symbol-function 'recursive-edit) edit)
            ((symbol-function 'process-file) (lambda (&rest _) (ert-fail "process-file")))
            ((symbol-function 'call-process) (lambda (&rest _) (ert-fail "call-process")))
            ((symbol-function 'start-process) (lambda (&rest _) (ert-fail "start-process")))
            ((symbol-function 'start-file-process)
             (lambda (&rest _) (ert-fail "start-file-process")))
            ((symbol-function 'make-process) (lambda (&rest _) (ert-fail "make-process"))))
    (wf--setup-inputs row)))

(ert-deftest wf-setup-specs-and-history ()
  "Return all fields in order, preserving exact text and explicit literal @."
  (let* ((wf--input-histories (obarray-make))
         (row '((name . "setup") (inputs . (((name . "first")) ((name . "second"))))))
         (text "line one\n\tλ雪\r\nlast\n")
         (hist (wf--input-history "setup" "first")))
    (set hist '("@previous" "older"))
    (should
     (equal
      (wf-smoke-setup
       row
       (lambda ()
         (should (eq major-mode 'wf--setup-mode))
         (should-not electric-indent-mode)
         (should (= (length wf--setup-fields) 2))
         (let* ((first (car wf--setup-fields))
                (second (cadr wf--setup-fields))
                (widget (plist-get first :widget)))
           (should (equal (widget-value widget) "@previous"))
           (cl-letf (((symbol-function 'completing-read)
                      (lambda (_prompt collection &rest _)
                        (should (equal collection '("@previous" "older")))
                        "older")))
             (wf--setup-history first))
           (should (equal (widget-value widget) "older"))
           (widget-value-set widget "@literal-not-a-file")
           (widget-forward 1)
           (widget-backward 1)
           (goto-char (point-min))
           (search-forward "\nSource" nil nil 2)
           (let ((selector (widget-at (- (point) 2))))
             (widget-value-set selector 'multiline)
             (widget-apply selector :notify selector))
           (should (eq (plist-get second :source) 'multiline))
           (should (eq (plist-get first :source) 'literal))
           (widget-value-set (plist-get second :widget) text)
           (should (equal (widget-value (plist-get first :widget))
                          "@literal-not-a-file"))
           (wf--setup-submit))))
      `(((name . "first") (source . "literal") (value . "@literal-not-a-file"))
        ((name . "second") (source . "literal") (value . ,text)))))
    (should (equal (car (symbol-value hist)) "@literal-not-a-file"))
    (should (equal (symbol-value (wf--input-history "setup" "second"))
                   (list text)))))

(ert-deftest wf-setup-source-drafts ()
  "Retain independent drafts across source changes and return edited captures."
  (let ((wf--input-histories (obarray-make))
        (row '((name . "drafts") (inputs . (((name . "input")))))))
    (should
     (equal
      (wf-smoke-setup
       row
       (lambda ()
         (let ((field (car wf--setup-fields)))
           (dolist (source '(literal multiline file))
             (wf--setup-source field source)
             (widget-value-set (plist-get field :widget) (symbol-name source)))
           (dolist (source '(literal multiline file literal))
             (wf--setup-source field source)
             (should (equal (widget-value (plist-get field :widget))
                            (symbol-name source)))))
         (wf--setup-submit)))
      '(((name . "input") (source . "literal") (value . "literal")))))))

(ert-deftest wf-setup-explicit-captures ()
  "Capture only a chosen buffer or region, retaining text until recaptured."
  (let ((wf--input-histories (obarray-make))
        (origin (generate-new-buffer " *wf-smoke-origin*"))
        (chosen (generate-new-buffer " *wf-smoke-chosen*"))
        (row '((name . "capture") (inputs . (((name . "input"))))))
        (reads 0))
    (unwind-protect
        (progn
          (with-current-buffer chosen
            (insert "prefix α\t\r\n雪 suffix")
            (narrow-to-region 8 13)
            (goto-char (point-min))
            (set-mark (point-max)))
          (with-current-buffer origin
            (should
             (equal
              (wf-smoke-setup
               row
               (lambda ()
                 (should (= reads 0))
                 (let ((field (car wf--setup-fields)))
                   (cl-letf (((symbol-function 'read-buffer)
                              (lambda (&rest _)
                                (setq reads (1+ reads))
                                (buffer-name chosen))))
                     (wf--setup-source field 'buffer)
                     (should (= reads 1))
                     (should (equal (widget-value (plist-get field :widget)) "α\t\r\n雪"))
                     (with-current-buffer chosen
                       (goto-char (point-min))
                       (insert "new "))
                     (wf--setup-source field 'literal)
                     (wf--setup-source field 'buffer)
                     (should (= reads 1))
                     (should (equal (widget-value (plist-get field :widget)) "α\t\r\n雪"))
                     (wf--setup-source field 'buffer t)
                     (should (= reads 2))
                     (should (equal (widget-value (plist-get field :widget)) "new α\t\r\n雪"))
                     (with-current-buffer chosen
                       (goto-char (point-min))
                       (set-mark (+ (point-min) 4)))
                     (wf--setup-source field 'region)
                     (should (= reads 3))
                     (should (equal (widget-value (plist-get field :widget)) "new "))
                     (with-current-buffer chosen (erase-buffer))
                     (wf--setup-source field 'buffer)
                     (wf--setup-source field 'region)
                     (should (= reads 3))
                     (should (equal (widget-value (plist-get field :widget)) "new "))
                     (widget-value-set (plist-get field :widget) "edited capture\n")))
                 (wf--setup-submit)))
              '(((name . "input") (source . "literal") (value . "edited capture\n")))))))
      (kill-buffer origin)
      (kill-buffer chosen))))

(ert-deftest wf-setup-failed-capture ()
  "Keep the menu and retained draft consistent when explicit capture fails."
  (let ((chosen (generate-new-buffer " *wf-smoke-no-mark*"))
        (wf--input-histories (obarray-make)))
    (unwind-protect
        (should
         (equal
          (wf-smoke-setup
           '((name . "failed-capture") (inputs . (((name . "input")))))
           (lambda ()
             (let ((field (car wf--setup-fields)))
               (widget-value-set (plist-get field :widget) "retained")
               (goto-char (point-min))
               (search-forward "\nSource")
               (let ((selector (widget-at (- (point) 2))))
                 (widget-value-set selector 'region)
                 (cl-letf (((symbol-function 'read-buffer)
                            (lambda (&rest _) (buffer-name chosen))))
                   (should-error (widget-apply selector :notify selector)
                                 :type 'user-error)))
               (should (eq (plist-get field :source) 'literal))
               (should (equal (widget-value (plist-get field :widget)) "retained"))
               (goto-char (point-min))
               (search-forward "\nSource")
               (should (eq (widget-value (widget-at (- (point) 2))) 'literal)))
             (wf--setup-submit)))
          '(((name . "input") (source . "literal") (value . "retained")))))
      (kill-buffer chosen))))

(ert-deftest wf-setup-file-specs ()
  "Return file references without reading bytes, with native file completion."
  (let* ((wf--input-histories (obarray-make))
         (file (make-temp-file "wf-setup-"))
         (default-directory (file-name-directory file))
         (row '((name . "file") (inputs . (((name . "input")))))))
    (unwind-protect
        (cl-letf (((symbol-function 'insert-file-contents)
                   (lambda (&rest _) (ert-fail "File bytes read")))
                  ((symbol-function 'insert-file-contents-literally)
                   (lambda (&rest _) (ert-fail "File bytes read literally"))))
          (should
           (equal
            (wf-smoke-setup
             row
             (lambda ()
               (let ((field (car wf--setup-fields)))
                 (wf--setup-source field 'file)
                 (let ((widget (plist-get field :widget)))
                   (should (eq (widget-type widget) 'file))
                   (should (widget-get widget :completions))
                   (widget-value-set widget (file-name-nondirectory file))))
               (wf--setup-submit)))
            `(((name . "input") (source . "file") (path . ,file))))))
      (delete-file file))))

(ert-deftest wf-setup-invalid-paths ()
  "Reject empty, missing, directory and foreign-machine paths before capture."
  (let ((default-directory temporary-file-directory))
    (dolist (raw (list "" "wf-setup-missing/no-file" temporary-file-directory
                       "/ssh:wf-other.invalid:/tmp/input"))
      (should-error (wf--setup-file raw) :type 'user-error)))
  (let ((default-directory "/ssh:wf-runner.invalid:/work/")
        (checked nil))
    (cl-letf (((symbol-function 'file-regular-p)
               (lambda (file) (push file checked) t))
              ((symbol-function 'file-readable-p) (lambda (_) t)))
      (should (equal (wf--setup-file "input") "/work/input"))
      (should (equal checked '("/ssh:wf-runner.invalid:/work/input")))
      (should-error (wf--setup-file "/ssh:other.invalid:/tmp/input") :type 'user-error)
      (should-error (wf--setup-file "/:/tmp/input") :type 'user-error)
      (should (= (length checked) 1)))))

(ert-deftest wf-setup-cancellation-and-validation ()
  "Cancel, quit and killing the form leave no history, buffers or processes."
  (let* ((wf--input-histories (obarray-make))
         (row '((name . "cancel") (inputs . (((name . "input"))))))
         (hist (wf--input-history "cancel" "input"))
         form)
    (dolist (action (list #'wf--setup-cancel
                         (lambda () (signal 'quit nil))
                         (lambda () (kill-buffer (current-buffer)))))
      (should
       (eq (condition-case nil
               (wf-smoke-setup
                row
                (lambda ()
                  (setq form (current-buffer))
                  (let ((field (car wf--setup-fields)))
                    (wf--setup-source field 'file)
                    (should-error (wf--setup-submit) :type 'user-error)
                    (should (null (symbol-value hist)))
                    (widget-value-set (plist-get field :widget) "unsubmitted"))
                  (funcall action)))
             (quit 'quit))
           'quit))
      (should-not (buffer-live-p form))
      (should-not (symbol-value hist)))))

(ert-deftest wf-setup-zero-inputs ()
  "Skip the form and all processes for rows without inputs."
  (cl-letf (((symbol-function 'display-buffer)
             (lambda (&rest _) (ert-fail "Unnecessary form"))))
    (should-not (wf-smoke-setup '((name . "empty") (inputs))
                               (lambda () (ert-fail "Unnecessary recursive edit"))))))


;;; Native process sessions

(defun wf-smoke-wait (predicate)
  "Wait at most ten seconds for PREDICATE while servicing native pipes."
  (let ((deadline (+ (float-time) 10)))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.02))
    (should (funcall predicate))))

(defun wf-smoke-native (directory &optional row inputs)
  "Prepare a scripted root in DIRECTORY with optional ROW and INPUTS."
  (let ((wf-state-directory (expand-file-name "state" directory)))
    (let ((session (wf--prepare (or row '((name . "hello-world")))
                                (or inputs '(((name . "language") (source . "literal")
                                              (value . "PRIVATE-@literal-λ\n"))))
                                '("--scripted") directory)))
      (wf-smoke-wait (lambda () (not (eq (wf--session-phase session) 'preparing))))
      (should-not (wf--session-error session))
      (should (eq (wf--session-phase session) 'prepared))
      session)))

(defun wf-smoke-decision (session operation)
  "Send SESSION the matching prepared OPERATION on its existing process."
  (setf (wf--session-phase session) (if (equal operation "start") 'running 'discarded))
  (wf--send session `((version . 1) (operation . ,operation)
                      (approvalId . ,(alist-get 'approvalId (wf--session-prepared session))))))

(ert-deftest wf-native-real-prepare-discard ()
  "Prepare sensitive literals over stdin, then discard without run files."
  (let* ((directory (make-temp-file "wf-native-" t))
         (session (wf-smoke-native directory)))
    (unwind-protect
        (progn
          (should (equal (process-command (wf--session-process session))
                         (list wf-program "frontend")))
          (should-not (process-buffer (wf--session-process session)))
          (should-not (file-exists-p (expand-file-name "state/runs" directory)))
          (let (prompt)
            (let ((wf-confirm-function (lambda (text) (setq prompt text) nil)))
              (should-not (wf--review session)))
            (should (string-match-p "Start prepared run" prompt))
            (should-not (string-match-p "PRIVATE" prompt)))
          (wf-smoke-decision session "discard")
          (wf-smoke-wait (lambda () (not (process-live-p (wf--session-process session)))))
          (should-not (file-exists-p (expand-file-name "state/runs" directory))))
      (when (process-live-p (wf--session-process session))
        (delete-process (wf--session-process session)))
      (delete-directory directory t))))

(ert-deftest wf-native-wf-run-integration ()
  "Exercise actual wf-run through setup, target, review and same-process start."
  (let* ((default-directory (make-temp-file "wf-native-command-" t))
         (wf-state-directory (expand-file-name "state" default-directory))
         (wf--sessions nil) prepared-process
         (wf-confirm-function (lambda (prompt)
                                (should (string-match-p "Start prepared run" prompt))
                                (setq prepared-process (wf--session-process (car wf--sessions)))
                                t)))
    (unwind-protect
        (cl-letf (((symbol-function 'wf--read-row) (lambda (&rest _) '((name . "hello-world"))))
                  ((symbol-function 'wf--setup-inputs)
                   (lambda (_) '(((name . "language") (source . "literal") (value . "French")))))
                  ((symbol-function 'wf--read-transport) (lambda (&optional _) '("--scripted"))))
          (save-window-excursion (wf-run))
          (let ((session (car wf--sessions)))
            (should (eq prepared-process (wf--session-process session)))
            (wf-smoke-wait (lambda () (and (not (process-live-p prepared-process))
                                           (not (eq (wf--session-phase session) 'running)))))
            (should-not (wf--session-error session))
            (should (eq (wf--session-phase session) 'completed))))
      (dolist (session wf--sessions)
        (when (process-live-p (wf--session-process session)) (delete-process (wf--session-process session)))
        (when (buffer-live-p (wf--session-view session)) (kill-buffer (wf--session-view session))))
      (delete-directory default-directory t))))

(ert-deftest wf-native-independent-views-and-result ()
  "Keep two same-workflow identities alive; verify results only through IO."
  (let* ((directory (make-temp-file "wf-native-views-" t))
         (one (wf-smoke-native directory)) (two (wf-smoke-native directory)))
    (unwind-protect
        (progn
          (should-not (equal (alist-get 'runId (wf--session-prepared one))
                             (alist-get 'runId (wf--session-prepared two))))
          (save-window-excursion (wf--view one) (wf--view two))
          (should-not (eq (wf--session-view one) (wf--session-view two)))
          (kill-buffer (wf--session-view one))
          (should (process-live-p (wf--session-process one)))
          (wf-smoke-decision one "start")
          (wf-smoke-decision two "start")
          (wf-smoke-wait (lambda () (and (not (process-live-p (wf--session-process one)))
                                         (not (process-live-p (wf--session-process two))))))
          (dolist (session (list one two))
            (wf-smoke-wait (lambda () (not (eq (wf--session-phase session) 'running))))
            (should-not (wf--session-error session))
            (should (eq (wf--session-phase session) 'completed))
            (should (wf--session-result session)))
          (save-window-excursion (wf--view one))
          (with-current-buffer (wf--session-view one)
            (should (string-match-p "run.completed" (buffer-string))))
          (let (result)
            (let ((process (wf--artifact one "read-result" (wf--session-result one)
                                         (lambda (value) (setq result value)))))
              (wf-smoke-wait (lambda () (not (process-live-p process))))
              (wf-smoke-wait (lambda () result))
              (should (assq 'value result))))
          (let ((reference (copy-tree (wf--session-result one))) called refusal)
            (setf (alist-get 'sha256 reference) (make-string 64 ?a))
            (cl-letf (((symbol-function 'wf--notice) (lambda (_ text _) (setq refusal text))))
              (let ((process (wf--artifact one "read-result" reference (lambda (_) (setq called t)))))
                (wf-smoke-wait (lambda () (not (process-live-p process)))))
              (wf-smoke-wait (lambda () refusal)))
            (should-not called)
            (should (string-match-p "verification refused" refusal))))
      (dolist (session (list one two))
        (when (process-live-p (wf--session-process session)) (delete-process (wf--session-process session)))
        (when (buffer-live-p (wf--session-view session)) (kill-buffer (wf--session-view session))))
      (delete-directory directory t))))

(defun wf-smoke-envelope (sequence event)
  "Construct a protocol-v2 SEQUENCE and EVENT for validation."
  `((protocolVersion . 2) (runId . "test-run") (sequence . ,(number-to-string sequence))
    (timestamp . "2026-09-03T00:00:00Z") (event . ,event)))

(defun wf-smoke-session ()
  "Create a process-free running session for framing and reduction."
  (wf--session-create :phase 'running :prepared '((runId . "test-run"))))

(ert-deftest wf-native-framing-utf8-and-bounds ()
  "Reject malformed, invalid UTF-8, foreign and out-of-order envelopes."
  (dolist (chunk (list "not JSON\n" (concat (unibyte-string 255) "\n")
                       (wf--encode (wf-smoke-envelope 1 '((type . "run.started"))))
                       (wf--encode '((protocolVersion . 2) (runId . "foreign")))
                       (wf--encode (wf-smoke-envelope 0 '((type . "unknown"))))))
    (let ((session (wf-smoke-session)))
      (wf--filter session chunk)
      (should (wf--session-error session))
      (should-not (wf--session-events session))))
  (let* ((session (wf-smoke-session))
         (frame (wf--encode (wf-smoke-envelope 0 '((type . "run.started")
                                                 (workflow . "λ") (target . "scripted")
                                                 (personAnswering . "local-control"))))))
    (dotimes (index (length frame)) (wf--filter session (substring frame index (1+ index))))
    (should-not (wf--session-error session))
    (should (= (wf--session-sequence session) 1))
    (wf--filter session frame)
    (should (wf--session-error session)))
  (let ((session (wf-smoke-session)) (wf--stream-limit 5))
    (wf--filter session "123456")
    (should (string-match-p "capture limit" (wf--session-error session))))
  (should-not (wf--timestamp-p "2026-02-31T00:00:00Z"))
  (should-error (wf--progress '((kind . "message") (text . 42))))
  (should-error (wf--encode (make-string (* 2 1024 1024) ?x)) :type 'user-error))

(ert-deftest wf-native-phase-tail-and-eof ()
  "Preserve a partial next-phase frame and reject truncated EOF."
  (let* ((directory (make-temp-file "wf-native-tail-" t))
         (prepared (wf-smoke-native directory))
         (preview (wf--session-prepared prepared))
         (session (wf--session-create))
         (event (wf-smoke-envelope 0 '((type . "run.started") (workflow . "hello-world")
                                      (target . "scripted") (personAnswering . "local-control")))))
    (unwind-protect
        (progn
          (setf (alist-get 'runId event) (alist-get 'runId preview))
          (let* ((frame (wf--encode event)) (half (/ (length frame) 2)))
            (wf--filter session (concat (wf--encode preview) (substring frame 0 half)))
            (should (eq (wf--session-phase session) 'prepared))
            (should (equal (wf--session-wire session) (substring frame 0 half)))
            (setf (wf--session-phase session) 'running)
            (wf--filter session (substring frame half))
            (should-not (wf--session-error session))
            (should (= (wf--session-sequence session) 1)))
          (wf--filter session "{\"partial\"")
          (cl-letf (((symbol-function 'process-status) (lambda (_) 'exit)))
            (wf--sentinel session nil))
          (should (equal (wf--session-error session) "Truncated native JSON frame"))
          (let ((broken (copy-tree preview)))
            (setf (alist-get 'inputs broken) nil)
            (should-not (wf--prepared-p broken))))
      (wf-smoke-decision prepared "discard")
      (wf-smoke-wait (lambda () (not (process-live-p (wf--session-process prepared)))))
      (delete-directory directory t))))

(ert-deftest wf-native-wf-run-refusal-and-quit ()
  "Refuse or quit actual wf-run review without starting a root."
  (dolist (decision '(refuse quit))
    (let* ((default-directory (make-temp-file "wf-native-no-start-" t))
           (wf-state-directory (expand-file-name "state" default-directory))
           (wf--sessions nil)
           (wf-confirm-function (lambda (_)
                                  (should (get-buffer-window "*wf prepared review*"))
                                  (if (eq decision 'quit) (signal 'quit nil) nil))))
      (unwind-protect
          (cl-letf (((symbol-function 'wf--read-row) (lambda (&rest _) '((name . "hello"))))
                    ((symbol-function 'wf--setup-inputs) (lambda (_) nil))
                    ((symbol-function 'wf--read-transport) (lambda (&optional _) '("--scripted"))))
            (condition-case nil (save-window-excursion (wf-run)) (quit nil))
            (let ((session (car wf--sessions)))
              (wf-smoke-wait (lambda () (not (process-live-p (wf--session-process session)))))
              (should (eq (wf--session-phase session) 'discarded))
              (should-not (wf--session-events session))
              (should-not (file-exists-p (expand-file-name "state/runs" default-directory)))))
        (delete-directory default-directory t)))))

(ert-deftest wf-native-view-follow-policy ()
  "Follow only views whose point was already at bottom."
  (let* ((session (wf-smoke-session)) (wf--sessions (list session)))
    (setf (wf--session-directory session) default-directory)
    (unwind-protect
        (save-window-excursion
          (wf--view session)
          (goto-char (point-min))
          (wf--render session)
          (should (= (point) (point-min)))
          (goto-char (point-max))
          (push (wf-smoke-envelope 0 '((type . "run.started"))) (wf--session-events session))
          (wf--render session)
          (should (= (point) (point-max))))
      (kill-buffer (wf--session-view session)))))

(ert-deftest wf-native-controls-correlation-and-fifo ()
  "Preserve FIFO pending decisions, typed false, and reject foreign controls."
  (let* ((session (wf-smoke-session)) (wf--sessions (list session)) sent)
    (wf--event session (wf-smoke-envelope 0 '((type . "run.started") (workflow . "test")
                                            (target . "scripted") (personAnswering . "local-control"))))
    (dotimes (n 2)
      (let ((id (number-to-string n)))
        (wf--event session (wf-smoke-envelope (1+ (* 2 n))
                           `((type . "occurrence.started") (occurrenceId . ,id)
                             (code . "flag") (intent . "consult") (addressee . "person owner") (prompt . "?"))))
        (wf--event session (wf-smoke-envelope (+ 2 (* 2 n))
                           `((type . "occurrence.person-answer-pending") (occurrenceId . ,id)
                             (question . ((artifactVersion . 1) (path . "person/questions/0.json")
                                          (sha256 . ,(make-string 64 ?a)) (bytes . "10"))))))))
    (should (equal (wf--session-pending session) '("0" "1")))
    (cl-letf (((symbol-function 'process-live-p) (lambda (_) t))
              ((symbol-function 'wf--send-frame) (lambda (_ frame) (setq sent (wf--json frame)))))
      (should-error (wf--control-send session '((type . "answerPerson") (answer . t)) "1") :type 'user-error)
      (should-error (wf--control-send session '((type . "answerPerson") (answer . t)) "foreign") :type 'user-error)
      (wf--control-send session '((type . "answerPerson") (answer . :false)) "0")
      (should (string-match-p "\"answer\":false" (wf--encode sent)))
      (should-error (wf--control-send session '((type . "answerPerson") (answer . nil)) "0") :type 'user-error))
    (let ((ack (copy-tree '((type . "control.ack") (controlId . "emacs-1") (state . "accepted")
                            (message . "accepted") (command . "answerPerson") (occurrenceId . "0") (attemptId)))))
      (let ((foreign (copy-tree ack)))
        (setf (alist-get 'occurrenceId foreign) "1")
        (should-error (wf--event session (wf-smoke-envelope 5 foreign))))
      (wf--event session (wf-smoke-envelope 5 ack))
      (should (equal (wf--session-pending session) '("0" "1")))
      (setf (alist-get 'state ack) "delivered")
      (wf--event session (wf-smoke-envelope 6 ack)))
    (should (equal (wf--session-pending session) '("1")))
    (should (eq (wf--json "false") :false))
    (should-not (wf--json "null"))
    (should (equal (wf--encode (wf--json "[]")) "[]\n"))))

(ert-deftest wf-native-live-control-context ()
  "Check steering, recovery, redirect, cancellation and attempt correlation."
  (let* ((session (wf-smoke-session)) (wf--sessions (list session)) sent)
    (setf (wf--session-occurrences session)
          '(("0" :attempt "0") ("1" :targets ["acp:stub"])
            ("2" :pending ((type . "occurrence.recovery-pending")
                           (choices . [((choice . "retry")) ((choice . "abandon"))]))))
          (wf--session-pending session) '("2"))
    (cl-letf (((symbol-function 'process-live-p) (lambda (_) t))
              ((symbol-function 'wf--send-frame) (lambda (_ frame) (setq sent (wf--json frame)))))
      (wf--control-send session '((type . "steerOccurrence") (timing . "interrupt-now") (text . "steer")) "0")
      (should (equal (alist-get 'attemptNumber (alist-get 'expectedAttemptId sent)) "0"))
      (wf--ack session '((controlId . "emacs-1") (state . "accepted") (message . "ok")
                         (command . "steerOccurrence") (occurrenceId . "0")
                         (attemptId . ((attemptNumber . "0") (occurrenceId . "0")))))
      (wf--control-send session '((type . "redirectOccurrence") (target . "acp:stub")) "1")
      (should-error (wf--control-send session '((type . "redirectOccurrence") (target . "foreign")) "1") :type 'user-error)
      (should-error (wf--control-send session '((type . "failoverOccurrence")) "2") :type 'user-error)
      (wf--control-send session '((type . "retryOccurrence")) "2")
      (wf--control-send session '((type . "cancelRun")) nil)
      (should-not (alist-get 'expectedOccurrenceId sent))
      (setf (wf--session-phase session) 'completed)
      (should-error (wf--control-send session '((type . "cancelRun")) nil) :type 'user-error))))

(ert-deftest wf-native-json-answer-shapes ()
  "Round-trip every JSON answer shape without changing false, null or objects."
  (dolist (text '("false" "null" "true" "{}" "[]" "[{},null,false]" "{\"nested\":{}}"))
    (should (equal (string-trim (wf--encode (wf--json text))) text)))
  (let ((session (wf-smoke-session)) (old-map (copy-keymap text-mode-map)))
    (save-window-excursion
      (wf--answer-editor session "0" '((question . ((code . "flag")))))
      (unwind-protect
          (progn
            (should (equal (buffer-string) "true"))
            (should-not (eq (current-local-map) text-mode-map))
            (should (equal text-mode-map old-map)))
        (kill-buffer (current-buffer))))))

(ert-deftest wf-native-control-byte-bounds ()
  "Refuse oversized controls before reserving a pending decision."
  (dolist (size (list (+ (* 1024 1024) 100) (+ (* 2 1024 1024) 100)))
    (let* ((session (wf-smoke-session)) (wf--sessions (list session)) sent)
      (setf (wf--session-occurrences session)
            '(("0" :pending ((type . "occurrence.person-answer-pending"))))
            (wf--session-pending session) '("0"))
      (cl-letf (((symbol-function 'process-live-p) (lambda (_) t))
                ((symbol-function 'process-send-string) (lambda (_ frame) (setq sent frame))))
        (should-error (wf--control-send session `((type . "answerPerson") (answer . ,(make-string size ?x))) "0")
                      :type 'user-error)
        (should-not sent)
        (should-not (wf--session-controls session))
        (should-not (wf--decision-inflight-p session "0"))
        (wf--control-send session '((type . "answerPerson") (answer . "corrected")) "0")
        (should (equal (alist-get 'answer (alist-get 'command (wf--json sent))) "corrected"))))))

(ert-deftest wf-native-control-write-failure ()
  "Resolve a reserved control when its transport write fails."
  (let* ((session (wf-smoke-session)) (wf--sessions (list session)))
    (setf (wf--session-occurrences session)
          '(("0" :pending ((type . "occurrence.person-answer-pending"))))
          (wf--session-pending session) '("0"))
    (cl-letf (((symbol-function 'process-live-p) (lambda (_) t))
              ((symbol-function 'process-send-string) (lambda (&rest _) (error "Write failed")))
              ((symbol-function 'delete-process) #'ignore))
      (should-error (wf--control-send session '((type . "answerPerson") (answer . t)) "0"))
      (should (equal (plist-get (cdar (wf--session-controls session)) :state) "failed"))
      (should-not (wf--decision-inflight-p session "0")))))

(ert-deftest wf-native-steer-unsupported-after-acceptance ()
  "Accept the runtime's correlated steering-handler disappearance race."
  (let ((session (wf-smoke-session)))
    (setf (wf--session-controls session)
          '(("steer-1" :state "accepted"
             :control ((controlId . "steer-1") (expectedOccurrenceId . "0")
                       (expectedAttemptId . ((occurrenceId . "0") (attemptNumber . "0")))
                       (command . ((type . "steerOccurrence")))))))
    (wf--ack session '((controlId . "steer-1") (state . "unsupported")
                        (message . "Steering handler disappeared") (command . "steerOccurrence")
                        (occurrenceId . "0") (attemptId . ((occurrenceId . "0") (attemptNumber . "0")))))
    (should (equal (plist-get (cdar (wf--session-controls session)) :state) "unsupported"))
    (should (eq (wf--session-phase session) 'running))))

(ert-deftest wf-native-completion-requires-trace ()
  "Require one complete authored trace before accepting run completion."
  (let ((completed `((type . "run.completed") (billFresh . "0") (billMemo . "0")
                     (result . ((artifactVersion . 1) (path . "result.json")
                                (sha256 . ,(make-string 64 ?a)) (bytes . "1") (code . "ack") (preview . ""))))))
    (dolist (occurrences '(nil (("0" :terminal t :complete t))))
      (let ((session (wf-smoke-session)))
        (wf--event session (wf-smoke-envelope 0 '((type . "run.started") (workflow . "test")
                                                (target . "scripted") (personAnswering . "local-control"))))
        (setf (wf--session-occurrences session) occurrences)
        (should-error (wf--event session (wf-smoke-envelope 1 completed)))
        (when occurrences
          (should-error (wf--event session (wf-smoke-envelope 1 '((type . "trace.ordered") (occurrenceIds . []))))))
        (wf--event session (wf-smoke-envelope 1 `((type . "trace.ordered")
                                                (occurrenceIds . ,(if occurrences ["0"] [])))))
        (should-error (wf--event session (wf-smoke-envelope 2 `((type . "trace.ordered")
                                                              (occurrenceIds . ,(if occurrences ["0"] []))))))
        (wf--event session (wf-smoke-envelope 2 completed))
        (should (eq (wf--session-phase session) 'completed))))))

(ert-deftest wf-native-failed-occurrence-is-not-complete ()
  "Refuse an authored success trace after an occurrence has failed."
  (let ((session (wf-smoke-session)))
    (wf--event session (wf-smoke-envelope 0 '((type . "run.started") (workflow . "test")
                                            (target . "scripted") (personAnswering . "local-control"))))
    (wf--event session (wf-smoke-envelope 1 '((type . "occurrence.started") (occurrenceId . "0")
                                            (code . "text") (intent . "consult") (addressee . "model test") (prompt . "?"))))
    (wf--event session (wf-smoke-envelope 2 '((type . "occurrence.failed") (occurrenceId . "0")
                                            (failure . "decode") (message . "Failed"))))
    (should-error (wf--event session (wf-smoke-envelope 3 '((type . "trace.ordered") (occurrenceIds . ["0"])))))))

(ert-deftest wf-native-real-human-answers ()
  "Verify and answer the real two-question Boolean human fixture in FIFO order."
  (let ((runner (wf-smoke-control-binary)))
    (let* ((wf-program runner) (directory (make-temp-file "wf-native-human-" t))
           (session (wf-smoke-native directory '((name . "person-controlled"))
                                      '(((name . "input") (source . "literal") (value . "native question"))))))
      (unwind-protect
          (progn
            (wf-smoke-decision session "start")
            (dotimes (index 2)
              (wf-smoke-wait (lambda () (or (wf--session-pending session) (wf--session-error session))))
              (should-not (wf--session-error session))
              (let* ((id (car (wf--session-pending session)))
                     (occ (cdr (assoc id (wf--session-occurrences session))))
                     (reference (alist-get 'question (plist-get occ :pending))) question)
                (should (equal id (number-to-string index)))
                (wf--artifact session "read-question" reference (lambda (value) (setq question value)) id "flag")
                (wf-smoke-wait (lambda () question))
                (should (string-suffix-p "native question" (alist-get 'prompt (alist-get 'question question))))
                (when (zerop index)
                  (wf--control-send session '((type . "answerPerson") (answer . nil)) id)
                  (wf-smoke-wait (lambda () (equal (plist-get (cdar (wf--session-controls session)) :state) "failed")))
                  (should (equal id (car (wf--session-pending session)))))
                (wf--control-send session `((type . "answerPerson") (answer . ,(if (zerop index) :false t))) id)
                (wf-smoke-wait (lambda () (not (member id (wf--session-pending session)))))))
            (wf-smoke-wait (lambda () (not (process-live-p (wf--session-process session)))))
            (wf-smoke-wait (lambda () (not (eq (wf--session-phase session) 'running))))
            (should-not (wf--session-error session))
            (should (eq (wf--session-phase session) 'completed))
            (should-not (cl-some (lambda (frame) (string-prefix-p "attempt." (alist-get 'type (alist-get 'event frame))))
                                (wf--session-events session))))
        (when (process-live-p (wf--session-process session)) (delete-process (wf--session-process session)))
        (delete-directory directory t)))))

(ert-deftest wf-native-real-local-cancel ()
  "Cancel a real live human session using the run view's native command."
  (let ((runner (wf-smoke-control-binary)))
    (let* ((wf-program runner) (directory (make-temp-file "wf-native-cancel-" t))
           (session (wf-smoke-native directory '((name . "person-controlled"))
                                      '(((name . "input") (source . "literal") (value . "cancel fixture"))))))
      (unwind-protect
          (progn
            (wf-smoke-decision session "start")
            (wf-smoke-wait (lambda () (wf--session-pending session)))
            (save-window-excursion
              (wf--view session)
              (kill-buffer (current-buffer))
              (should (process-live-p (wf--session-process session)))
              (should (eq (wf--session-phase session) 'running))
              (wf--view session)
              (wf-kill))
            (wf-smoke-wait (lambda () (and (eq (wf--session-phase session) 'cancelled)
                                           (not (process-live-p (wf--session-process session))))))
            (should-not (wf--session-error session))
            (with-current-buffer (wf--session-view session)
              (should-error (wf-kill) :type 'user-error)))
        (when (process-live-p (wf--session-process session)) (delete-process (wf--session-process session)))
        (when (buffer-live-p (wf--session-view session)) (kill-buffer (wf--session-view session)))
        (delete-directory directory t)))))

(ert-deftest wf-native-real-recovery-controls ()
  "Exercise native retry, abandonment, dispatch and failover with ACP fixtures."
  (let ((adapters (getenv "WF_CONTROL_ADAPTERS"))
        (python (executable-find "python3")))
    (unless (and adapters python
                 (file-readable-p (expand-file-name "retry_adapter.py" adapters))
                 (file-executable-p (expand-file-name "stub_adapter.py" adapters)))
      (user-error "Set $WF_CONTROL_ADAPTERS to the agent-cat engine/acp/test directory"))
    (dolist (command '("retryOccurrence" "abandonOccurrence" "redirectOccurrence" "failoverOccurrence"))
      (ert-info ((format "Native control %s" command))
        (let* ((directory (make-temp-file "wf-native-recovery-" t))
               (wf-program (wf-smoke-control-binary))
               (wf-state-directory (expand-file-name "state" directory))
               (wf--sessions nil)
               (process-environment (copy-sequence process-environment))
               (routed (member command '("redirectOccurrence" "failoverOccurrence")))
               (arguments (append (list "--engine" "acp" "--adapter" python "--adapter-arg"
                                        (expand-file-name "retry_adapter.py" adapters) "--timeout" "10000")
                                  (when routed
                                    (list "--route" (concat "spare=acp:" (expand-file-name "stub_adapter.py" adapters))))))
               session)
          (setenv "TMPDIR" directory)
          (unwind-protect
              (cl-labels
                  ((choose (type &optional target)
                     (save-window-excursion
                       (wf--view session)
                       (let ((answers (append (list type "0") (when target (list target)))))
                         (cl-letf (((symbol-function 'completing-read)
                                    (lambda (&rest _) (or (pop answers) (ert-fail "Unexpected control prompt")))))
                           (wf-control))
                         (should-not answers)))))
                (setq session
                      (wf--prepare `((name . ,(if routed "controlled" "controlled-single")))
                                   '(((name . "input") (source . "literal") (value . "native controls")))
                                   arguments directory))
                (wf-smoke-wait (lambda () (not (eq (wf--session-phase session) 'preparing))))
                (should-not (wf--session-error session))
                (should (eq (wf--session-phase session) 'prepared))
                (wf-smoke-decision session "start")
                (when routed
                  (wf-smoke-wait
                   (lambda () (or (plist-get (cdr (assoc "0" (wf--session-occurrences session))) :targets)
                                  (wf--session-error session))))
                  (should-not (wf--session-error session))
                  (let ((targets (plist-get (cdr (assoc "0" (wf--session-occurrences session))) :targets)))
                    (choose "redirectOccurrence"
                            (aref targets (if (equal command "redirectOccurrence") (1- (length targets)) 0)))))
                (unless (equal command "redirectOccurrence")
                  (wf-smoke-wait (lambda () (or (wf--session-pending session) (wf--session-error session))))
                  (should-not (wf--session-error session))
                  (choose command))
                (wf-smoke-wait (lambda () (and (not (process-live-p (wf--session-process session)))
                                               (not (eq (wf--session-phase session) 'running)))))
                (should-not (wf--session-error session))
                (should (eq (wf--session-phase session) (if (equal command "abandonOccurrence") 'failed 'completed)))
                (should (equal (plist-get (cdar (wf--session-controls session)) :state) "delivered"))
                (should (cl-find (pcase command
                                   ("abandonOccurrence" "occurrence.recovery-chosen")
                                   ("redirectOccurrence" "occurrence.redirected")
                                   (_ "occurrence.retried"))
                                 (wf--session-events session) :test #'equal
                                 :key (lambda (frame) (alist-get 'type (alist-get 'event frame))))))
            (when session
              (when (process-live-p (wf--session-process session)) (delete-process (wf--session-process session)))
              (when (buffer-live-p (wf--session-view session)) (kill-buffer (wf--session-view session))))
            (delete-directory directory t)))))))

;;; Persistent native history and lineage

(defun wf-smoke-store (session)
  "Return the actual store identity belonging to SESSION."
  (wf--store-create :program (wf--session-program session)
                    :directory (wf--session-directory session)
                    :path (wf--session-state-path session)
                    :root (alist-get 'rootIdentity (wf--session-prepared session))))

(defun wf-smoke-finish (session)
  "Wait for SESSION's successful native completion and process exit."
  (wf-smoke-wait (lambda () (and (not (process-live-p (wf--session-process session)))
                                 (not (eq (wf--session-phase session) 'running)))))
  (should-not (wf--session-error session))
  (should (eq (wf--session-phase session) 'completed)))

(ert-deftest wf-native-history-reopen-corrupt-and-refusal ()
  "Reopen persisted history without sessions; keep corrupt siblings and refusals."
  (let* ((directory (make-temp-file "wf-history-" t))
         (session (wf-smoke-native directory))
         (store (wf-smoke-store session))
         (id (alist-get 'runId (wf--session-prepared session))))
    (unwind-protect
        (progn
          (wf-smoke-decision session "start") (wf-smoke-finish session)
          (make-directory (expand-file-name "state/runs/broken" directory))
          (set-file-modes (expand-file-name "state/runs/broken" directory) #o700)
          (let ((wf--sessions nil) (default-directory directory)
                (wf-state-directory (wf--store-path store)))
            (save-window-excursion
              (wf-history)
              (unwind-protect
                  (progn
                    (should (= (length tabulated-list-entries) 2))
                    (should (string-match-p "CORRUPT" (buffer-string)))
                    (should (string-match-p "succeeded" (buffer-string)))
                    (let ((entries tabulated-list-entries))
                      (cl-letf (((symbol-function 'wf--store-query)
                                 (lambda (&rest _) (user-error "Torn journal"))))
                        (should-error (wf-history-refresh) :type 'user-error))
                      (should (equal entries tabulated-list-entries))))
                (kill-buffer (current-buffer))))
            (save-window-excursion
              (wf--observe store (wf--read-record store id))
              (unwind-protect
                  (progn
                    (should (eq major-mode 'wf-observer-mode))
                    (should-not wf--session)
                    (should (string-match-p "OBSERVER ONLY" (buffer-string)))
                    (should-error (wf-kill) :type 'user-error)
                    (should-error (wf-answer) :type 'user-error)
                    (should-error (wf-control) :type 'user-error)
                    (wf-observer-refresh)
                    (let (result)
                      (cl-letf (((symbol-function 'wf--notice)
                                 (lambda (_ text _) (setq result text))))
                        (wf-observer-result)
                        (wf-smoke-wait (lambda () result)))
                      (should (stringp result))))
                (kill-buffer (current-buffer))))))
      (delete-directory directory t))))

(ert-deftest wf-native-history-live-ownership ()
  "Only exact locally held process identity grants live reopening."
  (let* ((wf-program (wf-smoke-control-binary))
         (directory (make-temp-file "wf-history-owner-" t))
         (session (wf-smoke-native directory '((name . "person-controlled"))
                                   '(((name . "input") (source . "literal") (value . "history")))))
         (store (wf-smoke-store session)))
    (unwind-protect
        (progn
          (wf-smoke-decision session "start")
          (wf-smoke-wait (lambda () (wf--session-pending session)))
          (let ((record (wf--read-record store (alist-get 'runId (wf--session-prepared session)))))
            (should (equal (alist-get 'ownership record) "owned-elsewhere"))
            (should (eq (wf--owned-session store record) session))
            (dolist (slot '(program directory root))
              (let ((foreign (copy-wf--store store)))
                (pcase slot
                  ('program (setf (wf--store-program foreign) "other-runner"))
                  ('directory (setf (wf--store-directory foreign) "/ssh:other:/tmp/"))
                  ('root (setf (wf--store-root foreign) "other-root")))
                (should-not (wf--owned-session foreign record))))
            (let ((wf--sessions nil))
              (save-window-excursion
                (wf--observe store record)
                (should (eq major-mode 'wf-observer-mode))
                (should-error (wf-kill) :type 'user-error)
                (kill-buffer (current-buffer))))
            (should (process-live-p (wf--session-process session)))
            (wf--control-send session '((type . "cancelRun")) nil)
            (wf-smoke-wait (lambda () (not (process-live-p (wf--session-process session)))))))
      (when (process-live-p (wf--session-process session)) (delete-process (wf--session-process session)))
      (delete-directory directory t))))

(ert-deftest wf-native-lineage-restart-resume-fork-and-compare ()
  "Use real lineage preparation, immutable parent captures and authoritative comparison."
  (let* ((directory (make-temp-file "wf-lineage-" t))
         (source (expand-file-name "source.txt" directory))
         (parent (progn
                   (with-temp-file source (insert "Captured once, not reopened"))
                   (wf-smoke-native directory nil
                                    `(((name . "language") (source . "file") (path . ,source))))))
         (store (wf-smoke-store parent))
         (id (alist-get 'runId (wf--session-prepared parent))) children)
    (unwind-protect
        (progn
          (wf-smoke-decision parent "start") (wf-smoke-finish parent)
          (with-temp-file source (insert "Changed after parent captured input"))
          (let ((record (wf--read-record store id)))
            (dolist (kind '("restart" "resume" "fork"))
              (let* ((child (wf--prepare-request
                             `((version . 1) (operation . "prepare-lineage")
                               (stateDirectory . ,(wf--store-path store)) (parentRunId . ,id)
                               (lineage . ,kind) (personAnswering . "local-control") (edits . [])) directory))
                     (process (wf--session-process child)))
                (push child children)
                (wf-smoke-wait (lambda () (not (eq (wf--session-phase child) 'preparing))))
                (should-not (wf--session-error child))
                (should (equal (alist-get 'parentRunId (wf--session-prepared child)) id))
                (should (equal (alist-get 'inputs (wf--session-prepared parent))
                               (alist-get 'inputs (wf--session-prepared child))))
                (let ((wf-confirm-function (lambda (_) t)))
                  (save-window-excursion (wf--approve child)))
                (should (eq process (wf--session-process child)))
                (wf-smoke-finish child)
                (should (equal record (wf--read-record store id)))
                (let ((wf--store store)
                      (wf--record (wf--read-record store (alist-get 'runId (wf--session-prepared child))))
                      comparison)
                  (cl-letf (((symbol-function 'wf--notice)
                             (lambda (_ text _) (setq comparison text))))
                    (wf-lineage-compare))
                  (should (string-match-p "PARENT (read-only record and snapshot)" comparison))
                  (should (string-match-p "CHILD (read-only record and snapshot)" comparison)))))
            (let ((wf--store store) (wf--record record)
                  (wf-confirm-function (lambda (_) nil)))
              (wf-restart)
              (should (eq (wf--session-phase (car wf--sessions)) 'discarded))
              (should (= (length (alist-get 'runs (wf--store-query store "list-runs"))) 4)))))
      (dolist (session (cons parent children))
        (when (process-live-p (wf--session-process session)) (delete-process (wf--session-process session)))
        (when (buffer-live-p (wf--session-view session)) (kill-buffer (wf--session-view session))))
      (delete-directory directory t))))

(ert-deftest wf-native-lineage-false-replacement ()
  "Fork real Boolean answers with false replacement and a dropped occurrence."
  (let* ((wf-program (wf-smoke-control-binary))
         (directory (make-temp-file "wf-lineage-false-" t))
         (parent (wf-smoke-native directory '((name . "person-controlled"))
                                  '(((name . "input") (source . "literal") (value . "fork")))))
         (store (wf-smoke-store parent)) child)
    (unwind-protect
        (progn
          (wf-smoke-decision parent "start")
          (dotimes (index 2)
            (wf-smoke-wait (lambda () (equal (car (wf--session-pending parent)) (number-to-string index))))
            (wf--control-send parent '((type . "answerPerson") (answer . t)) (number-to-string index)))
          (wf-smoke-finish parent)
          (let* ((id (alist-get 'runId (wf--session-prepared parent)))
                 (before (wf--read-record store id))
                 (edits (wf--json "[{\"operation\":\"replace\",\"occurrenceId\":\"0\",\"answer\":false},{\"operation\":\"drop\",\"occurrenceId\":\"1\"}]")))
            (should (wf--fork-edits-p edits))
            (should (eq (alist-get 'answer (aref edits 0)) :false))
            (setq child (wf--prepare-request
                         `((version . 1) (operation . "prepare-lineage")
                           (stateDirectory . ,(wf--store-path store)) (parentRunId . ,id)
                           (lineage . "fork") (personAnswering . "local-control") (edits . ,edits)) directory))
            (wf-smoke-wait (lambda () (not (eq (wf--session-phase child) 'preparing))))
            (should-not (wf--session-error child))
            (wf-smoke-decision child "start")
            (wf-smoke-wait (lambda () (or (wf--session-pending child) (wf--session-error child))))
            (should-not (wf--session-error child))
            (should (equal (wf--session-pending child) '("1")))
            (wf--control-send child '((type . "answerPerson") (answer . :false)) "1")
            (wf-smoke-finish child)
            (should (equal before (wf--read-record store id)))
            (should (cl-some (lambda (frame) (equal (alist-get 'type (alist-get 'event frame)) "occurrence.reused"))
                             (wf--session-events child)))))
      (dolist (session (delq nil (list parent child)))
        (when (process-live-p (wf--session-process session)) (delete-process (wf--session-process session))))
      (delete-directory directory t))))

(ert-deftest wf-native-routing-sanitized-selection ()
  "Keep persona precedence, producer launch words, and routes without engines."
  (let ((fixture '((version . 2) (persona (name . "home") (source . "environment"))
                   (availablePersonas . ("home" "work"))
                   (engines . (((name . "opaque")
                                (launch (arguments . ("--engine" "future" "--route" "pin=deck:abc"))
                                        (fingerprint . "cli-digest"))))))) calls)
    (cl-letf (((symbol-function 'wf--call)
               (lambda (&rest args) (push args calls) (json-encode fixture)))
              ((symbol-function 'completing-read)
               (lambda (prompt collection &rest _)
                 (if (equal prompt "Persona: ") (car collection) "opaque"))))
      (should (equal (wf--read-routing)
                     '("--engine" "future" "--route" "pin=deck:abc" "--expect-routing-fingerprint" "cli-digest")))
      (should (equal calls '(("--routing" "--json" "--offline")))))
    (setq calls nil)
    (cl-letf (((symbol-function 'wf--call)
               (lambda (&rest args) (push args calls) (json-encode fixture)))
              ((symbol-function 'completing-read)
               (lambda (prompt &rest _) (if (equal prompt "Persona: ") "work" "opaque"))))
      (should (member "--persona" (wf--read-routing)))
      (should (equal (car calls) '("--routing" "--json" "--offline" "--persona" "work"))))
    (setf (alist-get 'engines fixture) nil)
    (cl-letf (((symbol-function 'wf--call) (lambda (&rest _) (json-encode fixture)))
              ((symbol-function 'completing-read)
               (lambda (_ collection &rest _) (car collection)))
              ((symbol-function 'read-string)
               (lambda (&rest _) "--session inherited --route pin=deck:other")))
      (should (equal (wf--read-routing) '("--session" "inherited" "--route" "pin=deck:other"))))))

(ert-deftest wf-native-fork-editor-confirmation ()
  "Exercise native fork editor and confirmation while retaining JSON false."
  (let* ((store (wf--store-create :directory default-directory))
         (record '((runId . "parent"))) called)
    (save-window-excursion
      (cl-letf (((symbol-function 'wf--lineage-context) (lambda () (list store record))))
        (wf-fork))
      (unwind-protect
          (progn
            (should (equal (buffer-string) "[]\n"))
            (should (eq (key-binding (kbd "C-c C-c")) #'wf-fork-submit))
            (erase-buffer)
            (insert "[{\"operation\":\"replace\",\"occurrenceId\":\"0\",\"answer\":false}]")
            (cl-letf (((symbol-function 'wf--lineage)
                       (lambda (kind edits) (setq called (list kind edits)))))
              (let ((wf-confirm-function (lambda (_) nil))) (wf-fork-submit))
              (should-not called)
              (let ((wf-confirm-function (lambda (_) t))) (wf-fork-submit))
              (should (equal (car called) "fork"))
              (should (eq (alist-get 'answer (aref (cadr called) 0)) :false)))
            (erase-buffer) (insert "[{\"operation\":\"replace\",\"occurrenceId\":\"0\"}]")
            (should-error (wf-fork-submit) :type 'user-error))
        (kill-buffer (current-buffer))))))

(ert-deftest wf-native-recorded-output-readable ()
  "Keep recorded and verified text readable without JSON newline escapes."
  (let ((snapshot '((workflow . "fixture") (status . "succeeded")
                    (billFresh . "1") (billMemo . "1")
                    (occurrences . [((id . "0") (state . "completed") (code . "text")
                                     (addressee . "model example") (answer . "first\nsecond")
                                     (attempts . [((id . "0") (state . "completed")
                                                    (target . "scripted") (output . "live\ntext"))]))]))))
    (let ((text (wf--snapshot-output snapshot)))
      (should (string-prefix-p "fixture — succeeded" text))
      (should (string-match-p "Recorded answer:\nfirst\nsecond" text))
      (should (string-match-p "live\ntext" text)))
    (should (equal (wf--display-value "first\nsecond") "first\nsecond"))
    (should (equal (wf--display-value :false) "false"))))

(ert-deftest wf-native-pretty-preserves-unicode ()
  "Decode JSON transport bytes before displaying Unicode in a text buffer."
  (let* ((value '((text . "α — λ雪\nsecond")))
         (pretty (wf--pretty value)))
    (should (string-match-p "α — λ雪" pretty))
    (should (equal (wf--json (encode-coding-string pretty 'utf-8-unix)) value))))

(ert-deftest wf-native-query-startup-cleanup ()
  "Close allocated stderr buffers and processes after startup errors and quits."
  (dolist (stage '(spawn send))
    (dolist (kind '(error quit))
      (let ((allocate (symbol-function 'wf--stderr-buffer)) buffers processes)
        (unwind-protect
            (cl-letf (((symbol-function 'wf--stderr-buffer)
                       (lambda (&rest args)
                         (let ((buffer (apply allocate args))) (push buffer buffers) buffer)))
                      ((symbol-function 'make-process)
                       (lambda (&rest _)
                         (if (eq stage 'spawn) (signal kind '("Fixture startup refusal"))
                           (let ((process (make-pipe-process :name "wf query startup fixture" :noquery t)))
                             (push process processes) process))))
                      ((symbol-function 'process-send-string)
                       (lambda (&rest _) (signal kind '("Fixture send refusal")))))
              (condition-case nil
                  (wf--io "fixture" default-directory '((version . 1) (operation . "open-root") (path . "/fixture")) #'ignore)
                ((error quit) nil))
              (should buffers)
              (should-not (cl-some #'buffer-live-p buffers))
              (should-not (cl-some #'process-live-p processes)))
          (dolist (buffer buffers) (wf--close-stderr buffer))
          (dolist (process processes) (when (process-live-p process) (delete-process process))))))))

(ert-deftest wf-native-stderr-buffer-bytes ()
  "Capture stderr only after startup without deleting transport buffer data."
  (let* ((bytes (encode-coding-string "α雪\r\n" 'utf-8-unix)) captured
         (buffer (wf--stderr-buffer "test" (lambda (_ chunk) (push chunk captured)))))
    (unwind-protect
        (progn
          (with-current-buffer buffer (insert bytes))
          (should-not captured)
          (wf--activate-stderr buffer)
          (should (equal captured (list bytes)))
          (with-current-buffer buffer (insert "next"))
          (should (equal (car captured) "next"))
          (should (equal (with-current-buffer buffer (buffer-string)) (concat bytes "next"))))
      (wf--close-stderr buffer))))

(ert-deftest wf-native-tramp-pipe-settings-are-local ()
  "Request direct SSH pipes without changing stored profiles or method data."
  (let ((default-directory "/ssh:fixture@localhost:/tmp/")
        (methods (copy-tree tramp-methods))
        (profiles (copy-tree connection-local-profile-alist))
        (criteria (copy-tree connection-local-criteria-alist)) called)
    (cl-letf (((symbol-function 'make-process)
               (lambda (&rest args)
                 (should (apply #'tramp-direct-async-process-p args))
                 (should (eq (tramp-get-method-parameter
                              (tramp-dissect-file-name default-directory) 'tramp-direct-async) t))
                 (setq called t) 'fixture)))
      (should (eq (wf--make-process :name "fixture" :command '("wf" "frontend")
                                   :connection-type 'pipe :file-handler t) 'fixture)))
    (should called)
    (should (equal methods tramp-methods))
    (should (equal profiles connection-local-profile-alist))
    (should (equal criteria connection-local-criteria-alist))))

(ert-deftest wf-native-stderr-survives-stop-and-continue ()
  "Keep diagnostics connected when a live worker stops and continues."
  (let ((allocate (symbol-function 'wf--stderr-buffer)) buffer session
        (directory (make-temp-file "wf-stop-" t)))
    (unwind-protect
        (cl-letf (((symbol-function 'wf--stderr-buffer)
                   (lambda (&rest args) (setq buffer (apply allocate args)))))
          (setq session (wf-smoke-native directory))
          (let ((process (wf--session-process session)))
            (signal-process process 'SIGSTOP)
            (wf-smoke-wait (lambda () (eq (process-status process) 'stop)))
            (accept-process-output nil 0.05)
            (should (buffer-live-p buffer))
            (should (process-live-p (get-buffer-process buffer)))
            (continue-process process)
            (wf-smoke-wait (lambda () (eq (process-status process) 'run)))
            (should (buffer-live-p buffer))
            (wf-smoke-decision session "discard")
            (wf-smoke-wait (lambda () (not (process-live-p process))))
            (should-not (buffer-live-p buffer))))
      (when (and session (process-live-p (wf--session-process session)))
        (when (eq (process-status (wf--session-process session)) 'stop)
          (continue-process (wf--session-process session)))
        (delete-process (wf--session-process session)))
      (when (buffer-live-p buffer) (wf--close-stderr buffer))
      (delete-directory directory t))))

;;; The listing

(setq wf-program (wf-smoke-binary))
(princ (format "wf-smoke: %s\n" wf-program))

(let* ((rows (wf--rows t))
       (wiggum (seq-find (lambda (r) (equal (alist-get 'name r) "wiggum")) rows))
       (hello (seq-find (lambda (r) (equal (alist-get 'name r) "hello")) rows)))

  (wf-smoke-assert (= (length rows) 75)
                   "%d rows, parsed from --json and nothing else"
                   (length rows))
  (wf-smoke-assert wiggum "the listing has a `wiggum' row to ask about")
  (wf-smoke-assert (equal (mapcar (lambda (input) (alist-get 'name input))
                                      (alist-get 'inputs wiggum))
                          '("plan" "base" "observations" "parity"))
                   "wiggum declares the inputs %S"
                   (alist-get 'inputs wiggum))
  (wf-smoke-assert (equal (alist-get 'runFacts wiggum)
                          '("run.backends" "run.engine" "run.routes"
                            "run.sentinel"))
                   "wiggum's run facts %S are never prompted for"
                   (alist-get 'runFacts wiggum))
  (wf-smoke-assert (equal (wf--price wiggum)
                          "branch · at most 48 over 34 paths")
                   "wiggum's annotation reads `%s'" (wf--price wiggum))

  ;; The em dash, not the word "nil", for a program with no path through it.
  (wf-smoke-assert (equal (wf--bound nil) "—")
                   "a row with no path prices as `%s', as the CLI prints it"
                   (wf--bound nil))

  ;; The cache is per connection, and holds after the first fetch.
  (wf-smoke-assert (eq rows (wf--rows)) "the listing is fetched once")
  (wf-smoke-assert (equal (wf--cache-key) (cons "" wf-program))
                   "cached per connection, here under %S" (wf--cache-key))
  (wf-refresh)
  (wf-smoke-assert (null wf--rows-cache) "wf-refresh forgets every listing")


  ;;; Inputs

  ;; File-name completion begins after the `@', not at the start of the field.
  (wf-smoke-assert
   (equal (completion-boundaries "@/usr/lo" #'wf--input-table nil "") '(6 . 0))
   "@-completion starts its field after the @ and delegates to files")

  ;; The row and the input are joined by something neither name can carry, so
  ;; two different pairs cannot share a history.  Under `/' these two were
  ;; both the symbol `a/b/c', and one input would answer with the other's past.
  (wf-smoke-assert (not (eq (wf--input-history "a/b" "c")
                            (wf--input-history "a" "b/c")))
                   "the histories of (%S %S) and (%S %S) are distinct symbols"
                   "a/b" "c" "a" "b/c")
  (wf-smoke-assert (eq (wf--input-history "wiggum" "plan")
                       (wf--input-history "wiggum" "plan"))
                   "one input keeps one history")
  (wf-smoke-assert (null (symbol-value (wf--input-history "wiggum" "plan")))
                   "a history nobody has used yet is empty")


  ;;; Transports

  (wf-smoke-assert (equal (wf--transport-label '("--scripted"))
                          "as a rehearsal (scripted)")
                   "the scripted transport says `%s'"
                   (wf--transport-label '("--scripted")))
  (wf-smoke-assert (equal (wf--transport-label
                           '("--engine" "acp" "--adapter" "claude"))
                          "via acp:claude")
                   "the acp transport says `%s'"
                   (wf--transport-label
                    '("--engine" "acp" "--adapter" "claude")))
  (wf-smoke-assert (equal (wf--transport-label
                           '("--session" "abc123-1234567890"))
                          "via agent-deck session abc123-1234567890")
                   "the deck transport says `%s'"
                   (wf--transport-label '("--session" "abc123-1234567890")))
  ;; The binary has no default transport — `wf run hello' with no flag is a
  ;; refusal — so no transport at all must not read as one.
  (wf-smoke-assert (equal (wf--transport-label '("--require-pinned"))
                          (format "with no transport, which %s refuses"
                                  wf-program))
                   "and no transport at all says so: `%s'"
                   (wf--transport-label '("--require-pinned")))

  (wf-smoke-assert (not (fboundp 'wf--inputs-of))
                   "native sessions no longer recover sensitive inputs from argv")

  ;; Stdout and stderr are kept apart, so a narrated line costs no session.
  ;; The note in the label is the proof: only the JSON listing carries one, so
  ;; had the stderr line reached the reader this would have fallen back to the
  ;; plain table and the note would be nil.
  (let* ((wf-agent-deck-program
          (wf-smoke-fake-deck
           (concat "#!/bin/sh\n"
                   "echo 'agent-deck: profile \"default\" is stale' >&2\n"
                   "case \"$2\" in\n"
                   "  -json) printf '[{\"id\":\"abc123-1234567890\","
                   "\"title\":\"ct\",\"status\":\"live\","
                   "\"path\":\"/tmp\"}]\\n' ;;\n"
                   "  *) printf 'TITLE ID\\nct abc123-1234567890\\n' ;;\n"
                   "esac\n")))
         (sessions (wf--deck-sessions)))
    (unwind-protect
        (progn
          (wf-smoke-assert
           (equal sessions '(("ct" "abc123-1234567890" "live  /tmp")))
           "a line on stderr costs no session: %S" sessions)
          (wf-smoke-assert (null wf--deck-complaint)
                           "and a listing that worked leaves no complaint"))
      (ignore-errors (delete-file wf-agent-deck-program))))

  ;; A missing agent-deck degrades rather than signalling — and says why.
  (let ((wf-agent-deck-program "definitely-not-a-program"))
    (wf-smoke-assert (null (wf--deck-sessions))
                     "a missing agent-deck is nil, not an error")
    (wf-smoke-assert (and wf--deck-complaint
                          (string-match-p "definitely-not-a-program"
                                          wf--deck-complaint))
                     "and the prompt can say why: `%s'" wf--deck-complaint))

  ;; A program that answers with nothing is not a program that failed, and the
  ;; reason has to say that rather than quoting an empty stderr.
  (let ((wf-agent-deck-program "/usr/bin/true"))
    (wf-smoke-assert (null (wf--deck-sessions)) "an empty listing is nil too")
    (wf-smoke-assert (equal wf--deck-complaint
                            "/usr/bin/true listed no sessions")
                     "and says `%s'" wf--deck-complaint))

  (wf-smoke-assert
   (equal (wf--label-sessions '(("aaaaaa-1" "ct" nil)
                                ("bbbbbb-2" "ct" nil)
                                ("cccccc-3" "cuda" nil)))
          '(("ct (aaaaaa-1)" "aaaaaa-1" nil)
            ("ct (bbbbbb-2)" "bbbbbb-2" nil)
            ("cuda" "cccccc-3" nil)))
   "a title two sessions share carries its id; a unique one does not")

  ;; A truncated id selects no session, so it is not offered as one.
  (wf-smoke-assert (and (wf--session-id-p "abc123-1234567890")
                        (not (wf--session-id-p "abc123-12345")))
                   "only a whole session id counts as one")


  ;; Native approval is exercised above against the same prepared process.
  (cl-letf (((symbol-function 'wf--read-row) (lambda (&rest _) hello)))
    (save-window-excursion (wf-plan)))
  (let ((buf (get-buffer (wf--buffer-name "wf plan" "hello"))))
    (wf-smoke-assert
     (and buf (with-current-buffer buf
                (string-match-p "hello, as elaborated:" (buffer-string))))
     "the plan buffer holds CLI prose, read and never scraped"))

  ;; `wf-help' is the same arrangement over the fifth verb: the binary's own
  ;; stdout in a read-only buffer, displayed and never parsed.  The page has no
  ;; `--json' spelling by design, so a front end that scraped it would be
  ;; reading the one output in this CLI that is explicitly not a contract.
  ;;
  ;; The row is picked interactively, which batch cannot do, so the picker is
  ;; answered by binding it — what is under test is what `wf-help' does with the
  ;; row, which is the half a person cannot check by reading the code.
  (cl-letf (((symbol-function 'wf--read-row) (lambda (&rest _) hello)))
    (let ((buf (save-window-excursion (wf-help))))
      (wf-smoke-assert
       (buffer-live-p buf)
       "wf-help leaves a buffer behind")
      (with-current-buffer buf
        (wf-smoke-assert
         (string-match-p "\\*\\*Transport\\.\\*\\*" (buffer-string))
         "…holding the row's page, `wf help' \\='s own bytes")
        (wf-smoke-assert
         buffer-read-only
         "…read-only, like the plan and cost buffers")
        (wf-smoke-assert
         (eq major-mode 'special-mode)
         "…in special-mode, so q buries it"))))

  (let ((stats (ert-run-tests-batch "^wf-\\(setup\\|native\\)-")))
    (wf-smoke-assert (zerop (ert-stats-completed-unexpected stats))
                     "native setup component regressions pass"))
  (princ (format "\nwf-smoke: %d facts, 0 failed\n" wf-smoke-checks)))

(provide 'wf-smoke)

;;; wf-smoke.el ends here
