;;; wf.el --- Pick, price and run agent-workflows rows  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 John Wiegley

;; Author: John Wiegley <johnw@newartisans.com>
;; Maintainer: John Wiegley <johnw@newartisans.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: tools, processes
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

;; A front end for the `wf' binary of the agent-workflows repository, which
;; is agent-cat's CLI over that repository's registry of priced programs.
;;
;; Six commands.  Four of them are entry points, and this file binds no key
;; to any of the four:
;;
;;   `wf-run'      pick a row, give it its inputs, pick a transport, read the
;;                 price, confirm it, and watch the run in its own buffer.
;;   `wf-plan'     pick a row and read `wf plan' for it.
;;   `wf-cost'     pick a row and read `wf cost' for it.
;;   `wf-refresh'  forget the cached row listing.
;;
;; The other two belong to the run buffer and are bound there, by
;; `wf-run-mode-map', because a buffer with a process in it is the only place
;; either one means anything:
;;
;;   `wf-kill'     C-c C-k — interrupt the run in this buffer.
;;   `wf-rerun'    g — ask the price again and start the same run over.
;;
;; The house thesis is the price gate.  A workflow here is a program whose
;; worst case is a number known before anything runs, so `wf-run' will not
;; start one until that number has been shown and a question naming it, and
;; the transport it is the price of, has been answered:
;;
;;   Run wiggum via acp:claude (branch, at most 44 consultations over 34
;;   paths)? (yes or no)
;;
;; The word is typed out because the plan is on screen beside the question,
;; and SPC — the key for reading on — is `y' to `y-or-n-p'.  See
;; `wf-confirm-function' to trade that back for one key.
;;
;; Everything this file reads from `wf' comes from `--json'.  No human-facing
;; CLI prose is parsed; the plan text is displayed and never scraped.
;;
;; Remote work needs no configuration.  Every subprocess is started with
;; `process-file' or `start-file-process' and inherits the current buffer's
;; `default-directory', so calling `wf-run' from a TRAMP buffer on a host runs
;; `wf' on that host — which is how the agent-deck sessions living there are
;; driven.  See the URL above, "The Emacs interface".

;;; Code:

(require 'ansi-color)

(defgroup wf nil
  "Pick, price and run the programs behind the `wf' binary."
  :group 'tools
  :prefix "wf-")

(defcustom wf-program "wf"
  "The agent-workflows binary.
Looked up on the variable `exec-path' locally and on the remote PATH
when `default-directory' is remote, so the plain name is usually right."
  :type 'string
  :group 'wf)

(defcustom wf-agent-deck-program "agent-deck"
  "The agent-deck binary, asked for the sessions a run may be sent to.
Only ever invoked as a listing; nothing here starts or stops a session."
  :type 'string
  :group 'wf)

(defcustom wf-confirm-function #'yes-or-no-p
  "How the price gate asks whether to start a run.
`yes-or-no-p' wants the word typed, and so cannot be answered by the
stray \\`SPC' that a plan buffer on screen invites: under `y-or-n-p'
that key is `act', which is to say `y'.  Set this to `y-or-n-p' to
answer with one key, or to any function of a prompt that returns
non-nil for yes."
  :type '(choice (const :tag "Type yes or no" yes-or-no-p)
                 (const :tag "One key" y-or-n-p)
                 (function :tag "Other"))
  :group 'wf)


;;; Talking to the binary

(defun wf--ensure-program (dir)
  "Signal a `user-error' unless `wf-program' can be found from DIR.
`process-file' answers a missing program with `file-missing', a
backtrace where every other degradation here is a sentence.  Ask
first, and name what fixes it: over TRAMP that is `tramp-remote-path'
as much as `wf-program'."
  (unless (or (file-name-absolute-p wf-program)
              (let ((default-directory dir))
                (executable-find wf-program 'remote)))
    (user-error "No `%s' on %s's PATH (see `wf-program'%s)"
                wf-program
                (or (file-remote-p dir 'host) "this machine")
                (if (file-remote-p dir) " and `tramp-remote-path'" ""))))

(defun wf--stderr-text (file)
  "Return the contents of FILE, trimmed, or \"\" when it cannot be read."
  (or (ignore-errors
        (with-temp-buffer
          (insert-file-contents file)
          (string-trim (buffer-string))))
      ""))

(defun wf--first-line (text)
  "The first line of TEXT, short enough to sit inside a prompt.
A program that fails at length still fails for one reason, and it is
on the first line; the rest would push the question off the echo area."
  (let ((line (car (split-string (string-trim text) "\n"))))
    (if (> (length line) 70)
        (concat (substring line 0 69) "…")
      line)))

(defun wf--call (&rest args)
  "Run `wf-program' with ARGS in `default-directory' and return its stdout.
The two streams are kept apart, as the binary's contract keeps them:
stdout carries the answer and stderr carries prose, so a narrated line
can never reach the JSON reader.  Signal a `user-error' quoting what
stderr said when it exits non-zero."
  (let ((dir default-directory))
    (wf--ensure-program dir)
    (let ((err (make-nearby-temp-file "wf-err")))
      (unwind-protect
          (with-temp-buffer
            (setq default-directory dir)
            (let* ((coding-system-for-read 'utf-8-unix)
                   (coding-system-for-write 'utf-8-unix)
                   (status (apply #'process-file wf-program nil (list t err)
                                  nil args)))
              (unless (eq status 0)
                (user-error "%s %s failed (%s): %s"
                            wf-program (combine-and-quote-strings args) status
                            (wf--stderr-text err)))
              (buffer-string)))
        (ignore-errors (delete-file err))))))

(defun wf--call-json (&rest args)
  "Run `wf-program' with ARGS and read its output as JSON.
Objects come back as alists with symbol keys, arrays as lists, and
both null and false as nil."
  (let ((out (apply #'wf--call args)))
    (condition-case nil
        (json-parse-string out :object-type 'alist :array-type 'list
                           :null-object nil :false-object nil)
      (error
       (user-error "%s %s did not answer with JSON: %s"
                   wf-program (combine-and-quote-strings args)
                   (string-trim out))))))


;;; The row listing, cached per connection

(defvar wf--rows-cache nil
  "Alist mapping a connection key to the rows `wf list --json' gave for it.
The key is built by `wf--cache-key', so a listing fetched over TRAMP is
never served to a local buffer or to another host.")

(defun wf--cache-key ()
  "The key under which this buffer's row listing is cached.
A connection and a binary together decide which registry answers."
  (cons (or (file-remote-p default-directory) "") wf-program))

(defun wf--rows (&optional refresh)
  "Return the rows of `wf list --json', as a list of alists.
The listing is cached per connection for the session; a non-nil
REFRESH fetches it again.  This is the only place the row set is read."
  (let ((key (wf--cache-key)))
    (when refresh
      (setq wf--rows-cache (assoc-delete-all key wf--rows-cache)))
    (or (cdr (assoc key wf--rows-cache))
        (let ((rows (wf--call-json "list" "--json")))
          (push (cons key rows) wf--rows-cache)
          rows))))

;;;###autoload
(defun wf-refresh ()
  "Forget every cached row listing, so the next command fetches it again."
  (interactive)
  (setq wf--rows-cache nil)
  (message "wf: row listing forgotten"))

(defun wf--bound (n)
  "Render N, a ceiling on consultations, the way the CLI renders it.
A program with no path through it has no ceiling, so N is nil there.
The CLI prints an em dash for that, and so does this, rather than
showing a reader of prices the word \"nil\"."
  (if n (number-to-string n) "—"))

(defun wf--price (row)
  "The one-line ceiling ROW promises: its level, its fold and its paths."
  (format "%s · at most %s over %s path%s"
          (alist-get 'level row)
          (wf--bound (alist-get 'maxFold row))
          (alist-get 'paths row)
          (if (eql 1 (alist-get 'paths row)) "" "s")))

(defun wf--read-row (prompt &optional refresh)
  "Read one row with PROMPT and return it.
Each candidate is annotated with its price and its blurb.  REFRESH is
passed to `wf--rows'."
  (let* ((rows (wf--rows refresh))
         (alist (mapcar (lambda (row) (cons (alist-get 'name row) row)) rows))
         (width (apply #'max 0 (mapcar (lambda (c) (length (car c))) alist)))
         (annotate
          (lambda (cand)
            (let ((row (cdr (assoc cand alist))))
              (when row
                (format "%s  %s  —  %s"
                        (make-string (max 1 (- width (length cand))) ?\s)
                        (wf--price row)
                        (alist-get 'blurb row))))))
         (table
          (lambda (string pred action)
            (if (eq action 'metadata)
                `(metadata (annotation-function . ,annotate)
                           (category . wf-workflow))
              (complete-with-action action alist string pred)))))
    (unless alist
      (user-error "%s listed no rows" wf-program))
    (cdr (assoc (completing-read prompt table nil t) alist))))


;;; Inputs

(defun wf--input-table (string pred action)
  "Completion table for the value of a workflow input.
A STRING beginning with `@' completes as a file name from the `@'
onwards, in `default-directory' — which is the remote host's when the
calling buffer is remote.  Anything else takes no completion and is
handed to the binary as typed.  PRED and ACTION are as for any
completion table."
  (if (string-prefix-p "@" string)
      (completion-table-with-context
       "@" #'completion-file-name-table (substring string 1) pred action)
    (unless (or (eq action 'metadata) (eq (car-safe action) 'boundaries))
      (complete-with-action action nil string pred))))

(defvar wf--input-histories (obarray-make)
  "The minibuffer histories of workflow inputs, one per row and input.
Each symbol interned here is named ROW, a NUL, then INPUT, and its
value is that input's history list, so that `wiggum's `plan' never
offers back what was last given to its `base'.  The histories last as
long as the Emacs session; `wf--input-history' is what reaches into
this.")

(defun wf--input-history (name input)
  "Return the minibuffer history symbol of row NAME's input INPUT.
It is interned in `wf--input-histories', starts out empty, and is fit
to be the HIST argument of `completing-read'.

The two names are joined by a NUL and not by a printable character.  No
row is named with a `/' today, but nothing refuses one: the registry's
naming rule is about which word a row gets — the owner's own — and says
nothing about which characters, and punctuation is in use in the input
namespace already, the runner's own reserved names being `run.backends'
and the rest.  Any printable separator could therefore be read two ways
and hand one input another's history, while a NUL can occur in neither
name, because both have to survive being typed as words of a command
line."
  (let ((sym (intern (format "%s\0%s" name input) wf--input-histories)))
    (unless (boundp sym)
      (set sym nil))
    sym))

(defun wf--read-inputs (row)
  "Prompt for each input ROW declares and return the flags they mean.
The declared inputs are asked one by one, in order.  Each input keeps a
history of its own, so \\`M-p' walks back through what this input was
given before in this session and the last answer is offered as the
default.  An empty answer where there is no default is allowed and
becomes an empty value, which the binary accepts.  An answer beginning
with `@' names a file: `@notes.md' becomes
`--input-file NAME=notes.md', and everything else becomes
`--input-arg NAME=VALUE'.  The file is named on the machine `wf' will
run on, so `@~/notes.md' from a remote buffer is that host's home
directory, and a file on the other machine is refused rather than
guessed at.  Reserved run facts are never asked for; the runner binds
those itself."
  (let ((name (alist-get 'name row))
        (flags nil))
    (dolist (input (alist-get 'inputs row) (nreverse flags))
      (let* ((hist (wf--input-history name input))
             (prev (let ((recent (car (symbol-value hist))))
                     (and (stringp recent) (not (equal recent "")) recent)))
             (prompt (if prev
                         (format-prompt
                          (format "%s: %s (@FILE for a file)" name input)
                          prev)
                       (format
                        "%s: %s (@FILE for a file, empty to leave empty): "
                        name input)))
             (value (completing-read prompt #'wf--input-table
                                     nil nil nil hist prev)))
        (cond
         ((equal value "@")
          (user-error "`@' with no file name after it, for input %s" input))
         ((string-prefix-p "@" value)
          (let* ((raw (substring value 1))
                 (here (file-remote-p default-directory))
                 (file (expand-file-name
                        (if (and here (string-prefix-p "~" raw))
                            (concat here raw)
                          raw))))
            (unless (equal here (file-remote-p file))
              (user-error "%s is on %s, but `%s' runs on %s" raw
                          (or (file-remote-p file 'host) "this machine")
                          wf-program
                          (or (file-remote-p default-directory 'host)
                              "this machine")))
            (push "--input-file" flags)
            (push (format "%s=%s" input (file-local-name file)) flags)))
         (t
          (push "--input-arg" flags)
          (push (format "%s=%s" input value) flags)))))))


;;; Transports

(defvar wf--deck-complaint nil
  "Why the last agent-deck listing came back empty, in one line.
Set by `wf--deck-output' from what agent-deck said on stderr, and read
by `wf--read-session' when it has no sessions to offer: a prompt that
degrades to typing an id by hand should say what went wrong, since the
listing is the only thing that could have told it.")

(defun wf--deck-complain (how said)
  "Record HOW an agent-deck listing failed, SAID being its stderr.
The first line of SAID is quoted when there is one, because that line
is the reason and HOW alone is only the shape of the failure."
  (setq wf--deck-complaint
        (if (equal (string-trim said) "")
            how
          (format "%s: %s" how (wf--first-line said)))))

(defun wf--deck-output (&rest args)
  "Run `wf-agent-deck-program' with ARGS and return its stdout, or nil.
The two streams are kept apart exactly as `wf--call' keeps them, and
for a sharper reason: with stderr merged into the same buffer, one
narrated line makes the JSON unreadable and the table unparsable, and
every session is silently lost to a fallback.  Return nil when the
program is missing or exits non-zero, leaving why in
`wf--deck-complaint'.  Nothing here signals."
  (let ((dir default-directory)
        (err (make-nearby-temp-file "wf-deck-err")))
    (unwind-protect
        (with-temp-buffer
          (setq default-directory dir)
          (condition-case failure
              (let* ((coding-system-for-read 'utf-8-unix)
                     (coding-system-for-write 'utf-8-unix)
                     (status (apply #'process-file wf-agent-deck-program
                                    nil (list t err) nil args)))
                (if (eq status 0)
                    (buffer-string)
                  (wf--deck-complain
                   (format "%s %s exited %s" wf-agent-deck-program
                           (combine-and-quote-strings args) status)
                   (wf--stderr-text err))
                  nil))
            (error
             (wf--deck-complain (error-message-string failure)
                                (wf--stderr-text err))
             nil)))
      (ignore-errors (delete-file err)))))

(defun wf--deck-sessions ()
  "Return the agent-deck sessions as a list of (LABEL ID ANNOTATION).
Read from `wf-agent-deck-program', preferring its JSON listing and
falling back to a lenient parse of its table, in which the field that
is a whole session id is the id and the rest of the line is the title.
Return nil rather than signalling when the sessions cannot be read, so
that a caller can degrade to reading an id as a plain string; why it
came back empty is left in `wf--deck-complaint' for that caller to
quote."
  (setq wf--deck-complaint nil)
  (condition-case nil
      (let* ((raw (wf--deck-output "list" "-json"))
             (sessions (or (and raw (wf--deck-sessions-from-json raw))
                           (wf--deck-sessions-from-table))))
        (cond (sessions (setq wf--deck-complaint nil))
              ((null wf--deck-complaint)
               (setq wf--deck-complaint
                     (format "%s listed no sessions" wf-agent-deck-program))))
        (wf--label-sessions sessions))
    (error nil)))

(defun wf--deck-sessions-from-json (raw)
  "Read RAW, the output of an agent-deck JSON listing, as (ID TITLE NOTE).
Return nil when RAW is not a JSON array of objects carrying an id."
  (condition-case nil
      (delq nil
            (mapcar
             (lambda (session)
               (let ((id (alist-get 'id session))
                     (title (alist-get 'title session)))
                 (when (and (stringp id) (not (equal id "")))
                   (list id
                         (if (and (stringp title) (not (equal title "")))
                             title
                           id)
                         (format "%s  %s"
                                 (or (alist-get 'status session) "?")
                                 (or (alist-get 'path session) ""))))))
             (json-parse-string raw :object-type 'alist :array-type 'list
                                :null-object nil :false-object nil)))
    (error nil)))

(defun wf--deck-sessions-from-table ()
  "Read the plain table of `wf-agent-deck-program' as (ID TITLE NOTE).
Every line is split on whitespace.  The field that is a whole session
id is taken as the id and the remaining fields as the title.  A line
carrying no whole id is skipped rather than guessed at, because the
table ellipsizes that column and a truncated id selects nothing;
returning fewer sessions lets the caller fall back to reading an id as
a string, where returning a plausible wrong one would not.  Only
stdout is read — a narrated line on stderr is not a session and never
reaches this parse.  Nothing here signals."
  (condition-case nil
      (let ((raw (wf--deck-output "list")))
        (when raw
          (with-temp-buffer
            (insert raw)
            (goto-char (point-min))
            (let ((found nil))
              (while (not (eobp))
                (let* ((line (buffer-substring-no-properties
                              (line-beginning-position) (line-end-position)))
                       (fields (split-string line "[ \t]+" t)))
                  (unless (or (< (length fields) 2)
                              (string-match-p "\\`[-=]+\\'" (car fields))
                              (member (car fields) '("TITLE" "ID" "Profile:")))
                    (let ((id (seq-find #'wf--session-id-p fields)))
                      (when id
                        (let ((rest (delete id (copy-sequence fields))))
                          (push (list id
                                      (if rest (string-join rest " ") id)
                                      nil)
                                found))))))
                (forward-line 1))
              (nreverse found)))))
    (error nil)))

(defun wf--session-id-p (field)
  "Return non-nil when FIELD is a whole agent-deck session id.
A run of hex, a hyphen, and ten or more digits.  The digits are what
make this strict: the plain table ellipsizes its id column to twelve
characters, which cuts into them, and a truncated id selects no
session at all."
  (and (stringp field)
       (string-match-p "\\`[[:xdigit:]]\\{6,\\}-[[:digit:]]\\{10,\\}\\'"
                       field)))

(defun wf--label-sessions (sessions)
  "Give each of SESSIONS a completion label, and return them so labelled.
SESSIONS is a list of (ID TITLE NOTE); the result is a list of
\(LABEL ID NOTE).  A title shared by two sessions carries its id."
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (session sessions)
      (puthash (nth 1 session) (1+ (gethash (nth 1 session) seen 0)) seen))
    (mapcar (lambda (session)
              (let ((id (nth 0 session))
                    (title (nth 1 session)))
                (list (if (> (gethash title seen 0) 1)
                          (format "%s (%s)" title id)
                        title)
                      id
                      (nth 2 session))))
            sessions)))

(defun wf--read-session ()
  "Read an agent-deck session and return its id.
Offer the sessions `wf--deck-sessions' found; when it found none, read
the id as a plain string instead — and say in the prompt why there was
nothing to offer, quoting the first line agent-deck said on stderr.  A
prompt that degrades in silence looks like a package with no session
listing in it at all, and the reason is usually one sentence long."
  (let ((sessions (wf--deck-sessions)))
    (if (null sessions)
        (read-string (format "agent-deck session id (%s): "
                             (or wf--deck-complaint "no sessions listed")))
      (let* ((annotate (lambda (cand)
                         (let ((note (nth 2 (assoc cand sessions))))
                           (and note (concat "  " note)))))
             (table (lambda (string pred action)
                      (if (eq action 'metadata)
                          `(metadata (annotation-function . ,annotate)
                                     (category . wf-deck-session))
                        (complete-with-action action sessions string pred)))))
        (nth 1 (assoc (completing-read "agent-deck session: " table nil t)
                      sessions))))))

(defun wf--read-adapter ()
  "Read the ACP adapter to start, and return it.
`claude' and `codex' are looked for on PATH and then at their
machine-local pins; anything else is taken as a path to a program."
  (completing-read (format-prompt "ACP adapter (or a path)" "claude")
                   '("claude" "codex") nil nil nil nil "claude"))

;; TODO: per-pin pane selection, for a routed run.
;;
;; A row whose `wf plan <row> --json' reports a non-empty `pins' array declares
;; serving models that `--route NAME=deck:ID' may name — `wiggum-duet' names its
;; own two `worker' and `partner', and the whole point of that row is that the
;; judgment lands in a pane the work never reaches.  This function emits exactly
;; one backend and contains no `--route' anywhere, so the duet is not reachable
;; from `M-x wf-run' today: it has to be typed at a shell.
;;
;; One trap for whoever builds it: `pins' is EVERY pinned serving model the
;; program reaches, borrowed callees included — at `wiggum-duet' it is six, of
;; which `fable', `opus', `gpt-5.5-pro' and `gemini-3.1-pro-preview' are the
;; fail-over ladder's rungs and belong on the default.  Routing a ladder rung
;; away moves borrowed work into somebody else's pane, and if that pane is the
;; judge's then THE GATE REFUSES IT: `Workflows.Deciders.judgeIsElsewhere'
;; compares the judge's backend against every other pin's and against the
;; default, so a picker that filled all six fields with panes would produce
;; refused runs rather than contaminated ones.  Offer them, but say which are the
;; row's own, and default every one of them to blank — a filled field the operator
;; did not mean is a run that will not start.
;;
;; What it wants, in one sentence: after the default transport has been chosen,
;; offer one agent-deck session completion per declared pin name — reusing
;; `wf--read-session' for each — and emit the resulting `--route NAME=deck:ID'
;; flags alongside the default `--session', skipping any pin the operator leaves
;; blank so that a partially-routed run stays expressible.  `wf--transport-label'
;; then has to name both panes, because the price gate's question is about a run
;; and a routed run is two answerers.
;;
;; Deliberately not built with the row: the design of record
;; (`doc/research/duet-design.md' §5.2) states it as a requirement and the row
;; landed with the shell invocation as its interface, so this comment is the
;; requirement recorded where whoever implements it will be standing, rather
;; than a half-built picker nobody has driven.

(defun wf--read-transport ()
  "Read how the run should be answered, and return the flags that say so.
`scripted' answers from the row's canned table and reaches nobody,
`acp' starts an adapter of its own, and `deck' sends every question to a
live agent-deck session somebody else started.

A routed run — one default answerer plus a `--route' per declared pin —
is not offered here yet; see the TODO above this function."
  (pcase (completing-read (format-prompt "Transport" "scripted")
                          '("scripted" "acp" "deck") nil t nil nil "scripted")
    ("scripted" (list "--scripted"))
    ("acp" (list "--engine" "acp" "--adapter" (wf--read-adapter)))
    ("deck" (list "--session" (wf--read-session)))
    (other (user-error "No such transport: %s" other))))

(defun wf--transport-label (flags)
  "Say in words which transport FLAGS chose, for the price gate to name.
FLAGS is a transport as `wf--read-transport' returned it.  The gate
asks about a run, and a run is a transport as much as a row: the same
ceiling is forty-four consultations under `acp' and none at all under
`--scripted', so the question has to name which of the two is about to
happen.

A list with no transport in it at all is not a run with a default one —
the binary has no default and refuses such a command line — so the
question says that rather than inventing a transport to name.
`wf--read-transport' always returns one of the three, which leaves the
last branch here for a mangled `wf--args' and nothing else."
  (cond
   ((member "--scripted" flags) "as a rehearsal (scripted)")
   ((member "--session" flags)
    (format "via agent-deck session %s" (cadr (member "--session" flags))))
   ((member "--adapter" flags)
    (format "via acp:%s" (cadr (member "--adapter" flags))))
   ((member "--engine" flags)
    (format "via %s" (cadr (member "--engine" flags))))
   (t (format "with no transport, which %s refuses" wf-program))))


;;; Reading output

(defun wf--buffer-name (what name)
  "The name of the WHAT buffer for the row NAME, on this connection.
WHAT is the kind of buffer — \"wf\", \"wf plan\", \"wf cost\".  The row
listing is cached per connection, and the buffers holding what came
back are named per connection for the same reason: a row run here and
on a remote host must not collide, and the buffer should say which
host answered."
  (let ((host (file-remote-p default-directory 'host)))
    (format "*%s: %s%s*" what (if host (concat host ":") "") name)))

(defun wf--show (bufname text dir)
  "Fill the read-only buffer BUFNAME with TEXT and return that buffer.
DIR becomes the buffer's `default-directory', so a plan read over TRAMP
keeps saying which host answered."
  (let ((buf (get-buffer-create bufname)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert text))
      (special-mode)
      (setq default-directory dir)
      (goto-char (point-min)))
    buf))


;;; The price gate

(defun wf--gate (row inputs transport)
  "Show what ROW costs under INPUTS over TRANSPORT and ask whether to run it.
INPUTS is the list of input flags `wf--read-inputs' returned and
TRANSPORT the flags `wf--read-transport' returned.  This is asked last,
after both, because the ceiling means one thing over `acp' and another
over `--scripted', and a question answered before the transport was
picked would have been a promise about a run nobody had described yet.
The plan is displayed as the binary prints it, for reading; the ceiling
in the question comes from the same plan asked for as JSON, never from
that text.  The question is put by `wf-confirm-function', which by
default will not take a stray \\`SPC' for a yes.  Return non-nil when
the run was confirmed."
  (let* ((name (alist-get 'name row))
         (priced (apply #'wf--call-json "plan" name "--json" inputs))
         (level (alist-get 'level priced))
         (fold (alist-get 'maxFold priced))
         (paths (alist-get 'paths priced))
         (where (wf--transport-label transport))
         (buf (wf--show (wf--buffer-name "wf plan" name)
                        (apply #'wf--call "plan" name inputs)
                        default-directory)))
    (save-window-excursion
      (display-buffer buf)
      (funcall
       wf-confirm-function
       (if (member "--scripted" transport)
           ;; A rehearsal has the row's paths and none of its price: the
           ;; ceiling would be the only false number in the question.
           (format "Run %s %s: consults nobody (%s, %s path%s)? "
                   name where level
                   paths (if (eql 1 paths) "" "s"))
         (format "Run %s %s (%s, at most %s consultation%s over %s path%s)? "
                 name where level
                 (wf--bound fold) (if (eql 1 fold) "" "s")
                 paths (if (eql 1 paths) "" "s")))))))


;;; The run buffer

(defvar-local wf--row nil
  "The row this run buffer last ran.")

(defvar-local wf--args nil
  "The arguments `wf-program' was last given in this run buffer.")

(defvar-keymap wf-run-mode-map
  :doc "Keymap for `wf-run-mode'."
  "C-c C-k" #'wf-kill
  "g" #'wf-rerun)

(define-derived-mode wf-run-mode special-mode "wf-run"
  "Major mode for the buffer of a running workflow.
The buffer is read-only, escape sequences in the run's output are
rendered rather than shown, \\[wf-kill] interrupts the run and
\\[wf-rerun] asks the price again and starts it over.

\\{wf-run-mode-map}"
  (setq-local scroll-conservatively 101))

(defun wf-kill ()
  "Interrupt the run in this buffer."
  (interactive)
  (let ((proc (get-buffer-process (current-buffer))))
    (unless (process-live-p proc)
      (user-error "No run here to interrupt"))
    (interrupt-process proc)
    (message "wf: interrupted")))

(defun wf-rerun ()
  "Run this buffer's workflow again, after asking its price again."
  (interactive)
  (unless wf--row
    (user-error "This buffer has no run to repeat"))
  (let ((row wf--row)
        (args wf--args))
    (when (wf--gate row (wf--inputs-of args) (wf--transport-of args))
      (wf--start row (cdr (cdr args))))))

(defun wf--inputs-of (args)
  "The input flags among ARGS, an argument list of the `wf--args' shape.
That shape is the whole command line after the binary — the verb
\"run\", the row name, and then the flags — and not the shorter list
`wf--start' was called with, because what a rerun has to work from is
what was stored."
  (let ((rest (cdr (cdr args)))
        (inputs nil))
    (while rest
      (if (member (car rest) '("--input-file" "--input-arg"))
          (progn (push (car rest) inputs)
                 (push (cadr rest) inputs)
                 (setq rest (cdr (cdr rest))))
        (setq rest (cdr rest))))
    (nreverse inputs)))

(defun wf--transport-of (args)
  "The transport flags among ARGS, an argument list of the `wf--args' shape.
Everything after the verb and the row name that is not an input flag
or an input flag's value, which is what `wf--read-transport' put there.
Recovered rather than remembered so that \\[wf-rerun] names the same
transport in the price gate as the run it is repeating."
  (let ((rest (cdr (cdr args)))
        (transport nil))
    (while rest
      (if (member (car rest) '("--input-file" "--input-arg"))
          (setq rest (cdr (cdr rest)))
        (push (car rest) transport)
        (setq rest (cdr rest))))
    (nreverse transport)))

(defun wf--filter (proc string)
  "Give PROC's buffer the output STRING, at its end, with colours applied.
A window showing the buffer follows the output only while it is already
at the end, so that scrolling back to re-read a consultation is not
undone by the next chunk."
  (when (buffer-live-p (process-buffer proc))
    (with-current-buffer (process-buffer proc)
      (let* ((inhibit-read-only t)
             (mark (process-mark proc))
             (start (marker-position mark))
             (at-end (= (point) mark)))
        (save-excursion
          (goto-char mark)
          (insert string)
          (ansi-color-apply-on-region start (point))
          (set-marker mark (point)))
        (when at-end (goto-char mark))
        (dolist (win (get-buffer-window-list (current-buffer) nil t))
          (when (= (window-point win) start)
            (set-window-point win mark)))))))

(defun wf--sentinel (proc event)
  "Note the end of the run PROC, EVENT being how it ended."
  (let ((how (string-trim event)))
    (when (buffer-live-p (process-buffer proc))
      (with-current-buffer (process-buffer proc)
        (let ((inhibit-read-only t))
          (save-excursion
            (goto-char (point-max))
            (insert (format "\nwf: %s\n" how))))))
    (message "%s %s" (process-name proc) how)))

(defun wf--start (row args)
  "Start ROW with ARGS in its own buffer, and display that buffer.
ARGS are the flags after the verb and the name — the inputs and the
transport.  The process is started with `start-file-process' in the
calling buffer's `default-directory', so a remote directory runs it
remotely, and the buffer is named for that connection."
  (let* ((name (alist-get 'name row))
         (dir default-directory)
         (all (append (list "run" name) args))
         (buf (get-buffer-create (wf--buffer-name "wf" name))))
    (wf--ensure-program dir)
    (with-current-buffer buf
      (let ((old (get-buffer-process buf)))
        (when (process-live-p old)
          (unless (yes-or-no-p (format "A run of %s is still going; kill it? "
                                       name))
            (user-error "Left the running %s alone" name))
          (kill-process old)
          (let ((waited 0))
            (while (and (process-live-p old) (< waited 50))
              (accept-process-output old 0.1)
              (setq waited (1+ waited))))
          (when (process-live-p old)
            (delete-process old))))
      (wf-run-mode)
      (setq default-directory dir
            wf--row row
            wf--args all)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%s %s\n  in %s\n\n"
                        (shell-quote-argument wf-program)
                        (mapconcat #'shell-quote-argument all " ")
                        dir)))
      (let* ((coding-system-for-read 'utf-8-unix)
             (coding-system-for-write 'utf-8-unix)
             (proc (apply #'start-file-process
                          (format "wf %s" name) buf wf-program all)))
        (set-marker (process-mark proc) (point-max) buf)
        (set-process-filter proc #'wf--filter)
        (set-process-sentinel proc #'wf--sentinel)
        (set-process-query-on-exit-flag proc t)))
    (display-buffer buf)
    buf))


;;; Commands

;;;###autoload
(defun wf-run (&optional refresh)
  "Pick a workflow, price it, confirm the price, and run it.

The rows come from `wf list --json' and are cached for the session; a
prefix argument, REFRESH, fetches the listing again.  Each candidate is
annotated with its blurb and its ceiling — its level, and the most
consultations any path through it can make.

Every input the chosen row declares is then asked for, in order, each
with a history of its own: \\`M-p' recalls what that input was given
before in this session, and the last answer is the default.  An empty
answer where there is no default passes an empty value.  An answer
beginning with `@' names a file, with file-name completion after the
`@': `@notes.md' passes `--input-file NAME=notes.md' and anything else
passes `--input-arg NAME=VALUE'.  The reserved `run.' facts are never
asked for — the runner binds those itself.

Then the transport: `scripted' answers from the row's canned table and
reaches nobody, `acp' starts an adapter of its own, and `deck' sends
every question to a live agent-deck session, chosen from the sessions
`wf-agent-deck-program' lists.

The price gate comes last, after the transport and not before it, and
names it: the same ceiling is forty-four consultations over `acp' and
nobody at all under `scripted', so a question asked first would have
priced a run that had not been described yet.  Nothing is started until
`wf plan' has been shown and that question answered.

The run itself is a process in a buffer of its own, started in this
buffer's `default-directory'.  Call this from a TRAMP buffer on a host
and `wf' runs on that host, with no further configuration — which is how
the agent-deck sessions living there are driven."
  (interactive "P")
  (let* ((row (wf--read-row "Run workflow: " refresh))
         (inputs (wf--read-inputs row))
         (transport (wf--read-transport)))
    (if (wf--gate row inputs transport)
        (wf--start row (append inputs transport))
      (message "wf: not run"))))

;;;###autoload
(defun wf-plan (&optional refresh)
  "Pick a workflow and read `wf plan' for it, without running anything.
A prefix argument, REFRESH, fetches the row listing again."
  (interactive "P")
  (let ((row (wf--read-row "Plan workflow: " refresh)))
    (pop-to-buffer
     (wf--show (wf--buffer-name "wf plan" (alist-get 'name row))
               (wf--call "plan" (alist-get 'name row))
               default-directory))))

;;;###autoload
(defun wf-cost (&optional refresh)
  "Pick a workflow and read `wf cost' for it, without running anything.
A prefix argument, REFRESH, fetches the row listing again."
  (interactive "P")
  (let ((row (wf--read-row "Cost workflow: " refresh)))
    (pop-to-buffer
     (wf--show (wf--buffer-name "wf cost" (alist-get 'name row))
               (wf--call "cost" (alist-get 'name row))
               default-directory))))

(provide 'wf)

;;; wf.el ends here
