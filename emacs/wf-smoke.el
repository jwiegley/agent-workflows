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
;;   * the price gate names the transport it is the price of, and says
;;     "consults nobody" for a rehearsal rather than quoting a ceiling
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

(defun wf-smoke-fake-deck (script)
  "Write SCRIPT to a temporary executable file and return its name.
Stands in for `agent-deck' so that this gate can decide for itself what
the listing says on each of its two streams."
  (let ((file (make-temp-file "wf-smoke-deck" nil ".sh" script)))
    (set-file-modes file #o755)
    file))


;;; The listing

(setq wf-program (wf-smoke-binary))
(princ (format "wf-smoke: %s\n" wf-program))

(let* ((rows (wf--rows t))
       (wiggum (seq-find (lambda (r) (equal (alist-get 'name r) "wiggum")) rows))
       (hello (seq-find (lambda (r) (equal (alist-get 'name r) "hello")) rows)))

  (wf-smoke-assert (= (length rows) 74)
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
                          "branch · at most 44 over 34 paths")
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

  ;; The two halves of a stored argument list, which is all `wf-rerun' has.
  (let ((args '("run" "wiggum" "--input-arg" "plan=x" "--input-file" "base=b"
                "--engine" "acp" "--adapter" "claude")))
    (wf-smoke-assert (equal (wf--inputs-of args)
                            '("--input-arg" "plan=x" "--input-file" "base=b"))
                     "a stored argv yields its inputs, %S"
                     (wf--inputs-of args))
    (wf-smoke-assert (equal (wf--transport-of args)
                            '("--engine" "acp" "--adapter" "claude"))
                     "and its transport, %S" (wf--transport-of args)))

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


  ;;; The price gate

  ;; The question names the transport it is the price of.  Both shapes are
  ;; asked of the real binary, through the real gate, with the confirmation
  ;; refused so that nothing runs.
  (let* ((asked nil)
         (wf-confirm-function (lambda (prompt) (setq asked prompt) nil)))
    (wf-smoke-assert (null (wf--gate hello nil '("--scripted")))
                     "a refused gate runs nothing")
    (wf-smoke-assert
     (equal asked
            (concat "Run hello as a rehearsal (scripted): "
                    "consults nobody (pipeline, 1 path)? "))
     "and had asked: %s" (string-trim (or asked "nothing")))
    (wf-smoke-assert (null (wf--gate hello nil
                                     '("--engine" "acp" "--adapter" "claude")))
                     "the same row over acp is a different question")
    (wf-smoke-assert
     (equal asked
            (concat "Run hello via acp:claude "
                    "(pipeline, at most 4 consultations over 1 path)? "))
     "namely: %s" (string-trim (or asked "nothing"))))

  ;; A confirmed gate answers with the confirmation, which is what `wf-run'
  ;; branches on before it starts anything.
  (let ((wf-confirm-function (lambda (_prompt) t)))
    (wf-smoke-assert (wf--gate hello nil '("--scripted"))
                     "a confirmed gate answers yes, and only then does wf-run start"))

  ;; And the plan buffer left behind is the CLI's own prose, unparsed.
  (let ((buf (get-buffer (wf--buffer-name "wf plan" "hello"))))
    (wf-smoke-assert
     (and buf (with-current-buffer buf
                (string-match-p "hello, as elaborated:" (buffer-string))))
     "the plan buffer holds `wf plan' prose, which is read and never scraped"))

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

  (princ (format "\nwf-smoke: %d facts, 0 failed\n" wf-smoke-checks)))

(provide 'wf-smoke)

;;; wf-smoke.el ends here
