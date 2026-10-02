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
;; `wf-run' discovers descriptor-v3 inputs, edits them in a native form,
;; selects an existing transport, and reviews a frozen root preparation.
;; Only explicit approval starts that same pipe process.  Inputs never enter
;; process arguments.  The runner owns capture, hashing, stores and cleanup.
;; `wf-plan', `wf-cost' and `wf-help' remain read-only discovery commands.
;;
;; Native protocol-v2 sessions live independently of buffers.  `wf-runs'
;; reopens their views for this Emacs lifetime; q or killing a view does not
;; cancel.  Local controls and verified question/result reads use pipe JSON.
;; `wf-rerun' opens new root setup; `wf-history' queries persistent records.
;; Observed records never grant control.  Restart, resume and fork prepare
;; on one worker and require explicit approval before that worker starts.
;;
;; The mode is explicit.  Local mode is the default.  `wf-service' of
;; `wf-service.el' selects a client profile of an agent-cat workflow
;; manager, and each command of this file then runs the service behavior
;; that `wf-service-commands' states for it, through `wf--service'.
;; `wf-local' returns the commands to local mode.
;;
;; Discovery preserves TRAMP connection conventions.  Native processes use
;; call-local direct-async pipe settings and separate stderr buffers.
;; SSH is tested through an isolated loopback server on Emacs 30.2.
;; Unsupported direct-pipe connections fail closed.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'wid-edit)
(require 'tabulated-list)
(require 'tramp-sh)
(require 'files-x)

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


;;; Mode selection

(defvar wf--service-dispatch nil
  "The function that runs the commands of this file in service mode, or nil.
Local mode is the default, and this variable is nil there.  The
command `wf-service' of `wf-service.el' sets it and `wf-local' clears
it.  The function receives the command symbol and the arguments of the
command, and it runs the service behavior of that command.")

(defun wf--service (command &rest arguments)
  "In service mode, run COMMAND with ARGUMENTS there and return non-nil.
In local mode, do nothing and return nil, so the caller runs its local
behavior."
  (when wf--service-dispatch
    (apply wf--service-dispatch command arguments)
    t))


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
        (let ((rows (wf--call-json "list" "--json" "--descriptor-version" "3")))
          (push (cons key rows) wf--rows-cache)
          rows))))

;;;###autoload
(defun wf-refresh ()
  "Forget every cached row listing, so the next command fetches it again."
  (interactive)
  (unless (wf--service 'wf-refresh)
    (setq wf--rows-cache nil)
    (message "wf: row listing forgotten")))

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

(defun wf--read-row (prompt &optional refresh rows)
  "Read one row with PROMPT and return it.
Each candidate is annotated with its price and its blurb.  REFRESH is
passed to `wf--rows'.  ROWS, when non-nil, are the candidate rows in
place of the rows of `wf--rows', and REFRESH is then unused.  The
service mode of `wf-service.el' gives the catalogue of a manager
profile as ROWS."
  (let* ((rows (or rows (wf--rows refresh)))
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

;;; Native input setup

(defvar-local wf--setup-fields nil
  "Declaration-ordered input states in the setup buffer.
Each plist holds its name, history symbol, selected source, source drafts,
and current value widget.  Drafts distinguish absent captures from empty text.")

(defvar-local wf--setup-origin nil
  "Buffer from which input setup was opened, offered only by explicit capture.")

(defvar-local wf--setup-tag nil
  "Catch tag through which this setup buffer returns its result.")

(defvar-keymap wf--setup-mode-map
  :doc "Keys for the native input setup form."
  :parent widget-keymap
  "C-c C-c" #'wf--setup-submit
  "C-c C-k" #'wf--setup-cancel
  "C-g" #'wf--setup-cancel)

(define-derived-mode wf--setup-mode fundamental-mode "wf-setup"
  "Edit initial workflow inputs together, without starting a run.
Use \\[widget-forward] and \\[widget-backward] to navigate widgets.
Use \\[quoted-insert] to insert literal tabs and carriage returns.
Submit with \\[wf--setup-submit], cancel with \\[wf--setup-cancel]."
  (setq-local buffer-undo-list t)
  (electric-indent-local-mode -1))

(defun wf--setup-save ()
  "Save every visible field into its selected source draft."
  (dolist (field wf--setup-fields)
    (setf (alist-get (plist-get field :source) (plist-get field :drafts))
          (substring-no-properties (widget-value (plist-get field :widget))))))

(defun wf--setup-capture (source)
  "Explicitly choose a buffer and return its logical text for SOURCE.
For `region', capture the chosen buffer's point-to-mark range, even if
inactive.  For `buffer', capture its accessible (possibly narrowed) text.
No buffer contents are read before the user chooses that buffer."
  (let ((buffer (get-buffer
                 (read-buffer
                  (if (eq source 'region)
                      "Capture region (point to mark) in buffer: "
                    "Capture text from buffer: ")
                  (and (buffer-live-p wf--setup-origin) wf--setup-origin) t))))
    (unless (buffer-live-p buffer)
      (user-error "Choose a live buffer to capture"))
    (with-current-buffer buffer
      (if (eq source 'region)
          (progn
            (unless (mark t)
              (user-error "Chosen buffer has no marked region"))
            (buffer-substring-no-properties (region-beginning) (region-end)))
        (buffer-substring-no-properties (point-min) (point-max))))))

(defun wf--setup-source (field source &optional recapture)
  "Switch FIELD to SOURCE, retaining all drafts.
Capture a buffer or region only on first selection or explicit RECAPTURE."
  (wf--setup-save)
  (unwind-protect
      (progn
        (when (and (memq source '(buffer region))
                   (or recapture (not (assq source (plist-get field :drafts)))))
          (setf (alist-get source (plist-get field :drafts))
                (wf--setup-capture source)))
        (setf (plist-get field :source) source))
    ;; A failed capture must not leave the menu claiming a different source.
    (wf--setup-render field)))

(defun wf--setup-history (field)
  "Choose a past value for FIELD without changing its explicit source."
  (let* ((history (symbol-value (plist-get field :history)))
         (value (if history
                    (completing-read "Input history: " history nil t)
                  (user-error "No history for this input"))))
    (widget-value-set (plist-get field :widget) value)
    (widget-setup)))

(defun wf--setup-render (&optional focus)
  "Render all input widgets, placing point in FOCUS when supplied.
Call `wf--setup-save' before redrawing an existing form."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (remove-overlays)
    (setq widget-field-list nil widget-field-new nil)
    (widget-insert "Initial inputs — Submit returns sources; it does not run.\n"
                   "TAB/backtab: navigate  M-TAB: file completion\n"
                   "C-c C-c: Submit  C-c C-k / C-g: Cancel\n"
                   "Multiline: RET inserts newline; C-q TAB / C-q C-m preserve tabs / CR.\n"
                   "Buffer captures use accessible text; Region uses point to mark.\n\n")
    (dolist (field wf--setup-fields)
      (let* ((source (plist-get field :source))
             (multiline (memq source '(multiline buffer region)))
             (map (make-sparse-keymap)))
        (set-keymap-parent map (if multiline widget-text-keymap
                                widget-field-keymap))
        (define-key map (kbd "C-c C-c") #'wf--setup-submit)
        (define-key map (kbd "C-c C-k") #'wf--setup-cancel)
        (define-key map (kbd "C-g") #'wf--setup-cancel)
        (widget-insert (concat (plist-get field :name) "\n"))
        (widget-create
         'menu-choice :tag "Source" :value source
         :notify (lambda (widget &rest _)
                   (wf--setup-source field (widget-value widget)))
         '(const :tag "Literal" literal)
         '(const :tag "Multiline" multiline)
         '(const :tag "File" file)
         '(const :tag "Buffer" buffer)
         '(const :tag "Region" region))
        (widget-insert "  ")
        (widget-create 'push-button :notify (lambda (&rest _)
                                             (wf--setup-history field))
                       "History")
        (when (memq source '(buffer region))
          (widget-insert "  ")
          (widget-create 'push-button
                         :notify (lambda (&rest _)
                                   (wf--setup-source field source t))
                         "Recapture"))
        (widget-insert "\n")
        (setf (plist-get field :widget)
              (widget-create (cond ((eq source 'file) 'file)
                                   (multiline 'text)
                                   (t 'editable-field))
                             :format "Value: %v" :size nil :keymap map
                             :value (or (alist-get source
                                                   (plist-get field :drafts))
                                        "")))
        (widget-insert "\n")))
    (widget-create 'push-button :notify (lambda (&rest _) (wf--setup-submit))
                   "Submit")
    (widget-insert "  ")
    (widget-create 'push-button :notify (lambda (&rest _) (wf--setup-cancel))
                   "Cancel")
    (widget-insert "\n")
    (widget-setup)
    (goto-char (widget-field-start
                (plist-get (or focus (car wf--setup-fields)) :widget)))
    (set-buffer-modified-p nil)))

(defun wf--setup-file (raw)
  "Validate RAW on this workflow's machine; return its absolute local path.
Only file metadata is checked here.  The runner, not Lisp, captures bytes."
  (when (equal raw "")
    (user-error "Choose a file for the file source"))
  (let* ((here (file-remote-p default-directory))
         (file (expand-file-name
                (if (and here (string-prefix-p "~" raw))
                    (concat here raw)
                  raw))))
    (unless (equal here (file-remote-p file))
      (user-error "Input file must be on the workflow's machine"))
    (unless (and (file-regular-p file) (file-readable-p file))
      (user-error "Input file must exist and be a readable regular file"))
    (file-local-name file)))

(defun wf--setup-specs ()
  "Return validated, declaration-ordered specs from the current setup form."
  (wf--setup-save)
  (mapcar (lambda (field)
            (let* ((source (plist-get field :source))
                   (value (alist-get source (plist-get field :drafts))))
              (append `((name . ,(plist-get field :name)))
                      (if (eq source 'file)
                          `((source . "file") (path . ,(wf--setup-file value)))
                        `((source . "literal") (value . ,value))))))
          wf--setup-fields))

(defun wf--setup-submit ()
  "Validate all inputs and return source specs to the setup caller."
  (interactive)
  (let ((specs (wf--setup-specs)))
    (dolist (field wf--setup-fields)
      (add-to-history (plist-get field :history)
                      (alist-get (plist-get field :source)
                                 (plist-get field :drafts))))
    (throw wf--setup-tag specs)))

(defun wf--setup-cancel ()
  "Cancel input setup, causing its caller to signal `quit'."
  (interactive)
  (throw wf--setup-tag 'cancel))

(defun wf--setup-inputs (row)
  "Edit ROW's declared initial inputs together and return source specs.
Specs are declaration-ordered alists with name, source and value (literal)
or path (file).  File paths are absolute on the runner's machine.  Literal
text, including a leading @, is never interpreted as a file reference.
The latest per-input history is the literal default.  Each source retains
its own draft; buffer/region text stays frozen until edited or recaptured.
Cancel, \\`C-g', or killing the form signals `quit'.  No workflow subprocess
is called.  With no declared inputs, return nil without opening a form."
  (when (alist-get 'inputs row)
    (let ((dir default-directory)
          (origin (current-buffer))
          (tag (make-symbol "wf-setup"))
          (buf (generate-new-buffer
                (wf--buffer-name "wf setup" (alist-get 'name row)))))
      (unwind-protect
          (save-window-excursion
            (with-current-buffer buf
              (wf--setup-mode)
              (setq default-directory dir
                    wf--setup-origin origin
                    wf--setup-tag tag
                    wf--setup-fields
                    (mapcar
                     (lambda (input)
                       (let* ((name (alist-get 'name input))
                              (hist (wf--input-history (alist-get 'name row) name))
                              (recent (car (symbol-value hist))))
                         (list :name name :history hist :source 'literal
                               :drafts (list (cons 'literal
                                                   (if (stringp recent) recent "")))
                               :widget nil)))
                     (alist-get 'inputs row)))
              (wf--setup-render))
            (let ((result
                   (catch tag
                     (with-current-buffer buf
                       (add-hook 'kill-buffer-hook #'wf--setup-cancel nil t))
                     (select-window (display-buffer buf))
                     (recursive-edit)
                     'cancel)))
              (if (eq result 'cancel) (signal 'quit nil) result)))
        (when (buffer-live-p buf)
          (with-current-buffer buf
            (remove-hook 'kill-buffer-hook #'wf--setup-cancel t)
            (set-buffer-modified-p nil))
          (kill-buffer buf))))))


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

(defun wf--routing-inspection (&optional persona)
  "Read sanitized routing for PERSONA without refreshing live inventories."
  (wf--json
   (apply #'wf--call
          (append '("--routing" "--json" "--offline")
                  (when persona (list "--persona" persona))))))

(defun wf--read-routing ()
  "Choose a persona and CLI-produced launch arguments, retaining opaque targets.
An inherited persona stays inherited; selecting a name is an explicit override.
Inspection is offline.  The prepared worker remains authoritative for charges."
  (let* ((inspection (wf--routing-inspection))
         (selected (alist-get 'persona inspection))
         (inherit (format "Inherit: %s (%s)" (alist-get 'name selected) (alist-get 'source selected)))
         (choice (completing-read "Persona: "
                                  (cons inherit (append (alist-get 'availablePersonas inspection) nil))
                                  nil t nil nil inherit))
         (persona (unless (equal choice inherit) choice)))
    (when persona (setq inspection (wf--routing-inspection persona)))
    (display-buffer
     (wf--show (generate-new-buffer-name "*wf routing inspection*")
               (wf--pretty inspection) default-directory))
    (let* ((engines (mapcar (lambda (engine) (cons (alist-get 'name engine) engine))
                            (alist-get 'engines inspection)))
           (opaque "Explicit target arguments (retain configured routing)")
           (name (completing-read "Configured engine: " (append (mapcar #'car engines) (list opaque)) nil t))
           (launch (alist-get 'launch (cdr (assoc name engines))))
           (arguments (if (equal name opaque)
                          (split-string-and-unquote
                           (read-string "Target arguments (CLI words, not shell): "))
                        (append (alist-get 'arguments launch) nil))))
      (unless (and arguments (listp arguments) (cl-every #'stringp arguments))
        (user-error "No launch arguments; use explicit supported target arguments"))
      (append arguments (when persona (list "--persona" persona))
              (when (alist-get 'fingerprint launch)
                (list "--expect-routing-fingerprint" (alist-get 'fingerprint launch)))))))

(defun wf--read-transport (&optional row)
  "Choose a transport supported by ROW's declared routing capabilities.
Configured routes also accept supported opaque CLI target words unchanged."
  (pcase (completing-read (format-prompt "Transport" "scripted")
                          (append '("scripted" "acp" "deck" "arguments")
                                  (when (or (null row)
                                            (eq (alist-get 'routingInspection (alist-get 'capabilities row)) t))
                                    '("configured"))) nil t nil nil "scripted")
    ("scripted" (list "--scripted"))
    ("acp" (list "--engine" "acp" "--adapter" (wf--read-adapter)))
    ("deck" (list "--session" (wf--read-session)))
    ("configured" (wf--read-routing))
    ("arguments" (split-string-and-unquote (read-string "Target arguments (CLI words, not shell): ")))
    (other (user-error "No such transport: %s" other))))

(defun wf--transport-label (flags)
  "Describe common transport FLAGS without resolving their routing policy.
Unknown choices retain their explicit engine label or report no transport."
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
WHAT is the kind of buffer — \"wf\", \"wf plan\", \"wf cost\",
\"wf help\".  The row listing is cached per connection, and the
buffers holding what came back are named per connection for the
same reason: a row run here and on a remote host must not collide,
and the buffer should say which host answered."
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


;;; Native root sessions

(defcustom wf-state-directory "~/.local/state/agent-workflows"
  "Private runner state directory on the workflow's machine.
An unqualified absolute path or ~ is resolved on that machine, including
TRAMP.  An explicitly remote name must match the workflow connection.
The runner creates and checks private directories; Lisp writes no artifacts."
  :type 'directory
  :group 'wf)

(cl-defstruct (wf--session (:constructor wf--session-create))
  "Execution state independent of every display buffer."
  process directory program state-path prepared (phase 'preparing) error
  (wire "") rejected (bytes 0) (sequence 0) events diagnostics
  occurrences pending controls trace result view)

(defvar wf--sessions nil
  "Native sessions retained independently of views for this Emacs lifetime.
This is not persistent history, ownership discovery, or semantic lineage.")

(defvar-local wf--session nil
  "Session projected by this buffer; killing the view does not cancel it.")

(defconst wf--stream-limit (+ (* 64 1024 1024) 4096)
  "Maximum captured bytes per native output stream before truthful failure.")

(defun wf--json-alists (value)
  "Convert JSON VALUE to alists, retaining empty objects as hash tables."
  (cond
   ((and (hash-table-p value) (> (hash-table-count value) 0))
    (let (fields)
      (maphash (lambda (key item) (push (cons (intern key) (wf--json-alists item)) fields)) value)
      (nreverse fields)))
   ((vectorp value) (apply #'vector (mapcar #'wf--json-alists value)))
   (t value)))

(defun wf--json (text)
  "Parse UTF-8 JSON TEXT, preserving false, null, empty objects and arrays."
  (wf--json-alists
   (json-parse-string text :object-type 'hash-table :array-type 'array
                      :null-object nil :false-object :false)))

(defun wf--encode (value &optional limit)
  "Encode VALUE as one UTF-8 JSON line within byte LIMIT.
LIMIT excludes the terminating newline and defaults to 2 MiB."
  (let* ((bound (or limit (* 2 1024 1024)))
         (frame (encode-coding-string
                 (json-serialize value :null-object nil :false-object :false)
                 'utf-8-unix)))
    (when (> (string-bytes frame) bound)
      (user-error "Native JSON frame exceeds %d bytes" bound))
    (concat frame "\n")))

(defun wf--send (session value)
  "Send on SESSION's existing pipe the JSON VALUE, never through argv."
  (wf--send-frame session (wf--encode value)))

(defun wf--send-frame (session frame)
  "Send through SESSION's private pipe an already encoded FRAME."
  (process-send-string (wf--session-process session) frame))

(defun wf--state-path ()
  "Return the configured runner-local absolute private state path."
  (let* ((remote (file-remote-p default-directory))
         (path (expand-file-name
                (if (and remote (not (file-remote-p wf-state-directory)))
                    (concat remote wf-state-directory)
                  wf-state-directory))))
    (unless (equal remote (file-remote-p path))
      (user-error "State directory must be on the workflow's machine"))
    (file-local-name path)))

(defun wf--fail (session reason)
  "Mark SESSION failed with REASON and close its protocol process.
Closing the pipe delegates descendant cleanup to the runner."
  (setf (wf--session-error session) reason
        (wf--session-phase session) 'failed)
  (when (process-live-p (wf--session-process session))
    (delete-process (wf--session-process session)))
  (wf--render session))

(defun wf--decimal-p (value)
  "Return non-nil if VALUE is a canonical unsigned decimal Word64 string."
  (and (stringp value) (<= (length value) 20)
       (string-match-p "\\`\\(?:0\\|[1-9][0-9]*\\)\\'" value)
       (<= (string-to-number value) (1- (expt 2 64)))))

(defun wf--reference-p (value &optional result)
  "Validate an artifact reference VALUE; RESULT requires result fields."
  (and (listp value) (eq (alist-get 'artifactVersion value) 1)
       (let ((path (alist-get 'path value)))
         (and (stringp path)
              (if result (equal path "result.json")
                (string-match-p "\\`person/questions/[0-9]+\\.json\\'" path))))
       (let ((hash (alist-get 'sha256 value)))
         (and (stringp hash) (string-match-p "\\`[0-9a-f]\\{64\\}\\'" hash)))
       (wf--decimal-p (alist-get 'bytes value))
       (< 0 (string-to-number (alist-get 'bytes value)) (1+ (* 64 1024 1024)))
       (or (not result) (and (assq 'code value)
                             (stringp (alist-get 'preview value))
                             (<= (length (alist-get 'preview value)) 500)
                             (not (string-match-p "[\n\r]" (alist-get 'preview value)))))))

(defun wf--recovery-p (option)
  "Return non-nil for a runtime recovery OPTION."
  (and (member (alist-get 'choice option) '("retry" "failover" "abandon"))
       (or (null (alist-get 'target option))
           (and (equal (alist-get 'choice option) "failover")
                (stringp (alist-get 'target option))))))

(defun wf--event-fields (event)
  "Check EVENT's required string and enumeration fields."
  (let ((type (alist-get 'type event)))
    (dolist (key (cdr (assoc type
                            '(("attempt.started" target) ("attempt.completed" source)
                              ("attempt.failed" message) ("occurrence.failed" message)
                              ("run.failed" message) ("run.cancelled" message)
                              ("occurrence.reused" answerGroup)
                              ("occurrence.recovery-pending" gap message)
                              ("occurrence.retried" controlId)
                              ("occurrence.recovery-chosen" controlId choice)
                              ("occurrence.redirected" controlId target)
                              ("attempt.steered" controlId timing text)
                              ("occurrence.completed" source answer)))))
      (unless (stringp (alist-get key event)) (error "Invalid event field %s" key)))
    (when (string-suffix-p ".failed" type)
      (unless (member (alist-get 'failure event) '("setup" "transport" "decode" "protocol" "cancelled" "runtime"))
        (error "Invalid failure class")))
    (when (equal type "attempt.steered")
      (unless (member (alist-get 'timing event) '("interrupt-now" "next-boundary"))
        (error "Invalid steering timing")))))

(defun wf--bounded-text-p (value limit)
  "Return non-nil for nonempty string VALUE within character LIMIT."
  (and (stringp value) (< 0 (length value)) (<= (length value) limit)))

(defun wf--progress (progress)
  "Validate protocol-v2 public PROGRESS without interpreting worker execution."
  (unless
      (pcase (alist-get 'kind progress)
        ((or "message" "reasoning-summary") (wf--bounded-text-p (alist-get 'text progress) 4096))
        ("tool"
         (let* ((tool (alist-get 'tool progress)) (id (alist-get 'id tool)))
           (and (wf--bounded-text-p id 128)
                (string-match-p "\\`[[:alnum:]._:-]+\\'" id)
                (cl-every (lambda (spec)
                            (let ((value (alist-get (car spec) tool)))
                              (or (null value) (wf--bounded-text-p value (cdr spec)))))
                          '((title . 1024) (toolKind . 128) (summary . 4096)))
                (or (null (alist-get 'status tool))
                    (member (alist-get 'status tool) '("pending" "in_progress" "completed" "failed" "cancelled"))))))
        ("todos"
         (let ((items (alist-get 'items progress)))
           (and (vectorp items) (<= (length items) 128)
                (cl-every (lambda (item)
                            (and (wf--bounded-text-p (alist-get 'content item) 1024)
                                 (member (alist-get 'priority item) '("high" "medium" "low"))
                                 (member (alist-get 'status item) '("pending" "in_progress" "completed")))) items))))
        ("usage"
         (let* ((usage (alist-get 'usage progress)) (used (alist-get 'used usage)) (size (alist-get 'size usage)))
           (and (wf--decimal-p used) (wf--decimal-p size)
                (> (string-to-number size) 0)
                (<= (string-to-number used) (string-to-number size))))))
    (error "Invalid public progress")))

(defun wf--timestamp-p (value)
  "Check VALUE's UTC calendar and clock fields after canonical shape validation."
  (condition-case nil
      (let* ((base (concat (substring value 0 19) "Z"))
             (date (if (equal (substring base 17 19) "60")
                       (concat (substring base 0 17) "59Z") base)))
        (equal date (format-time-string "%Y-%m-%dT%H:%M:%SZ" (date-to-time date) t)))
    (error nil)))

(defun wf--event (session envelope)
  "Reduce SESSION's native protocol projection after validating ENVELOPE.
This tracks identities and controls, not workflow execution semantics."
  (let* ((event (alist-get 'event envelope))
         (type (alist-get 'type event))
         (id (alist-get 'occurrenceId event))
         (entry (assoc id (wf--session-occurrences session)))
         (occ (cdr entry))
         (attempt (alist-get 'attempt event)))
    (unless (and (eq (wf--session-phase session) 'running)
                 (eq (alist-get 'protocolVersion envelope) 2)
                 (equal (alist-get 'runId envelope)
                        (alist-get 'runId (wf--session-prepared session)))
                 (wf--decimal-p (alist-get 'sequence envelope))
                 (= (string-to-number (alist-get 'sequence envelope))
                    (wf--session-sequence session))
                 (stringp (alist-get 'timestamp envelope))
                 (string-match-p
                  "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}\\(?:\\.[0-9]+\\)?Z\\'"
                  (alist-get 'timestamp envelope))
                 (wf--timestamp-p (alist-get 'timestamp envelope))
                 (member type '("run.started" "run.completed" "run.failed"
                                "run.cancelled" "occurrence.started"
                                "occurrence.completed" "occurrence.failed"
                                "occurrence.person-answer-pending" "occurrence.reused"
                                "occurrence.recovery-pending" "occurrence.recovery-chosen"
                                "occurrence.retried" "occurrence.dispatch-pending"
                                "occurrence.redirected" "attempt.started" "attempt.steered"
                                "attempt.output" "attempt.progress" "attempt.completed"
                                "attempt.failed" "control.ack"
                                "trace.ordered")))
      (error "Invalid runtime envelope or identity/sequence/phase"))
    (when (and (= (wf--session-sequence session) 0)
               (not (equal type "run.started")))
      (error "First event is not run.started"))
    (when (and (> (wf--session-sequence session) 0) (equal type "run.started"))
      (error "Duplicate run.started"))
    (when (or (string-prefix-p "occurrence." type)
              (string-prefix-p "attempt." type))
      (unless (and (wf--decimal-p id)
                   (if (equal type "occurrence.started") (not entry)
                     (and entry (not (plist-get occ :terminal)))))
        (error "Unknown, duplicate or terminal occurrence")))
    (when (string-prefix-p "attempt." type)
      (unless (and (wf--decimal-p attempt)
                   (<= (string-to-number attempt) (1- (expt 2 32)))
                   (if (equal type "attempt.started")
                       (and (not (plist-get occ :attempt))
                            (= (string-to-number attempt) (or (plist-get occ :attempt-count) 0)))
                     (equal attempt (plist-get occ :attempt))))
        (error "Invalid or stale attempt")))
    (wf--event-fields event)
    (pcase type
      ("run.started"
       (unless (and (stringp (alist-get 'workflow event))
                    (or (null (alist-get 'descriptor (wf--session-prepared session)))
                        (equal (alist-get 'workflow event)
                               (alist-get 'name (alist-get 'descriptor (wf--session-prepared session)))))
                    (stringp (alist-get 'target event))
                    (equal (alist-get 'personAnswering event) "local-control"))
         (error "Invalid run start")))
      ("occurrence.started"
       (dolist (field '(code intent addressee prompt))
         (unless (stringp (alist-get field event)) (error "Invalid occurrence field")))
       (push (cons id (list :event event)) (wf--session-occurrences session)))
      ("attempt.started"
       (setf (plist-get (cdr entry) :attempt) attempt
             (plist-get (cdr entry) :attempt-count) (1+ (string-to-number attempt))
             (plist-get (cdr entry) :targets) nil))
      ((or "attempt.completed" "attempt.failed")
       (setf (plist-get (cdr entry) :attempt) nil))
      ("attempt.output"
       (unless (and (stringp (alist-get 'chunk event))
                    (equal (alist-get 'stream event) "transport-text"))
         (error "Invalid attempt output")))
      ("attempt.progress" (wf--progress (alist-get 'progress event)))
      ((or "occurrence.person-answer-pending" "occurrence.recovery-pending")
       (when (plist-get occ :pending) (error "Duplicate pending decision"))
       (if (equal type "occurrence.person-answer-pending")
           (unless (wf--reference-p (alist-get 'question event))
             (error "Invalid question reference"))
         (let ((choices (alist-get 'choices event)))
           (unless (and (vectorp choices) (> (length choices) 0)
                        (= (length choices) (length (delete-dups (mapcar (lambda (choice) (alist-get 'choice choice)) choices))))
                        (cl-every #'wf--recovery-p choices))
             (error "Invalid recovery decision"))))
       (setf (plist-get (cdr entry) :pending) event
             (wf--session-pending session)
             (append (wf--session-pending session) (list id))))
      ("occurrence.dispatch-pending"
       (let ((targets (alist-get 'targets event)))
         (unless (and (vectorp targets) (> (length targets) 0)
                      (cl-every #'stringp targets)
                      (= (length targets) (length (delete-dups (append targets nil)))))
           (error "Invalid dispatch targets"))
         (setf (plist-get (cdr entry) :targets) targets)))
      ((or "occurrence.redirected" "occurrence.retried" "occurrence.recovery-chosen" "attempt.steered")
       (let* ((control (plist-get (cdr (assoc (alist-get 'controlId event) (wf--session-controls session))) :control))
              (command (alist-get 'type (alist-get 'command control))))
         (unless (and control (equal id (alist-get 'expectedOccurrenceId control))
                      (member command (pcase type
                                        ("attempt.steered" '("steerOccurrence"))
                                        ("occurrence.redirected" '("redirectOccurrence"))
                                        ("occurrence.retried" '("retryOccurrence" "failoverOccurrence"))
                                        (_ '("retryOccurrence" "failoverOccurrence" "abandonOccurrence")))))
           (error "Uncorrelated control effect")))
       (when (equal type "occurrence.redirected")
         (setf (plist-get (cdr entry) :targets) nil))
       (when (equal type "occurrence.recovery-chosen")
         (unless (wf--recovery-p event) (error "Invalid recovery choice"))))
      ("occurrence.reused"
       (setf (plist-get (cdr entry) :complete) t))
      ((or "occurrence.completed" "occurrence.failed")
       (when (and (equal type "occurrence.completed")
                  (equal (alist-get 'type (plist-get occ :pending))
                         "occurrence.person-answer-pending")
                  (not (plist-get occ :answered)))
         (error "Person completed without accepted answer"))
       (setf (plist-get (cdr entry) :terminal) t
             (plist-get (cdr entry) :complete) (equal type "occurrence.completed")
             (wf--session-pending session) (delete id (wf--session-pending session))))
      ("control.ack" (wf--ack session event))
      ("trace.ordered"
       (unless (and (not (wf--session-trace session))
                    (vectorp (alist-get 'occurrenceIds event))
                    (= (length (alist-get 'occurrenceIds event))
                       (length (wf--session-occurrences session)))
                    (cl-every (lambda (item) (plist-get (cdr item) :complete))
                              (wf--session-occurrences session))
                    (= (length (alist-get 'occurrenceIds event))
                       (length (delete-dups (append (alist-get 'occurrenceIds event) nil))))
                    (cl-every (lambda (oid) (assoc oid (wf--session-occurrences session)))
                              (alist-get 'occurrenceIds event)))
         (error "Invalid or incomplete authored trace"))
       (setf (wf--session-trace session) (alist-get 'occurrenceIds event)))
      ("run.completed"
       (unless (and (vectorp (wf--session-trace session))
                    (= (length (wf--session-trace session))
                       (length (wf--session-occurrences session)))
                    (wf--decimal-p (alist-get 'billFresh event))
                    (wf--decimal-p (alist-get 'billMemo event))
                    (wf--reference-p (alist-get 'result event) t)
                    (cl-every (lambda (item) (plist-get (cdr item) :complete))
                              (wf--session-occurrences session)))
         (error "Invalid completed result"))
       (setf (wf--session-result session) (alist-get 'result event)
             (wf--session-phase session) 'completed))
      ((or "run.failed" "run.cancelled")
       (unless (stringp (alist-get 'message event)) (error "Invalid terminal message"))
       (setf (wf--session-phase session) (if (equal type "run.failed") 'failed 'cancelled))))
    (cl-incf (wf--session-sequence session))
    (push envelope (wf--session-events session))))

(defun wf--same-attempt-p (left right)
  "Compare LEFT and RIGHT attempt identities independently of JSON key order."
  (if (and left right)
      (and (equal (alist-get 'occurrenceId left) (alist-get 'occurrenceId right))
           (equal (alist-get 'attemptNumber left) (alist-get 'attemptNumber right)))
    (eq left right)))

(defun wf--ack (session event)
  "Correlate SESSION's control previously sent with acknowledgement EVENT."
  (let* ((entry (assoc (alist-get 'controlId event) (wf--session-controls session)))
         (control (plist-get (cdr entry) :control))
         (old (plist-get (cdr entry) :state))
         (state (alist-get 'state event))
         (id (alist-get 'occurrenceId event)))
    (unless (and entry
                 (equal id (alist-get 'expectedOccurrenceId control))
                 (wf--same-attempt-p (alist-get 'attemptId event) (alist-get 'expectedAttemptId control))
                 (equal (alist-get 'command event) (alist-get 'type (alist-get 'command control)))
                 (stringp (alist-get 'message event))
                 (if old
                     (and (member old '("accepted" "queued"))
                          (member state '("delivered" "unsupported" "failed" "rejected-stale")))
                   (member state '("accepted" "queued" "unsupported" "failed" "rejected-stale"))))
      (error "Invalid control acknowledgement correlation or transition"))
    (when (and (equal (alist-get 'command event) "answerPerson")
               (equal state "queued"))
      (error "Person answers cannot be queued"))
    (setf (plist-get (cdr entry) :state) state)
    (when (and id (equal state "delivered"))
      (let ((occ (assoc id (wf--session-occurrences session))))
        (when (equal (alist-get 'command event) "answerPerson")
          (setf (plist-get (cdr occ) :answered) t))
        (when (member (alist-get 'command event)
                      '("answerPerson" "retryOccurrence" "failoverOccurrence" "abandonOccurrence"))
          (setf (wf--session-pending session) (delete id (wf--session-pending session))
                (plist-get (cdr occ) :pending) nil))))))

(defun wf--prepared-p (value)
  "Validate VALUE as a version-1 preparation, without inferring its facts."
  (and (eq (alist-get 'version value) 1)
       (equal (alist-get 'operation value) "prepared")
       (cl-every (lambda (key) (wf--bounded-text-p (alist-get key value) 128)) '(approvalId runId))
       (cl-every (lambda (key) (stringp (alist-get key value))) '(rootIdentity cwd targetKind))
       (let ((hash (alist-get 'programHash value)))
         (and (stringp hash) (string-match-p "\\`[0-9a-f]\\{64\\}\\'" hash)))
       (eq (alist-get 'descriptorVersion (alist-get 'descriptor value)) 3)
       (stringp (alist-get 'name (alist-get 'descriptor value)))
       (assq 'program (alist-get 'plan value))
       (listp (alist-get 'policy value)) (alist-get 'policy value)
       (vectorp (alist-get 'targetArguments value))
       (cl-every #'stringp (alist-get 'targetArguments value))
       (vectorp (alist-get 'inputs value))
       (cl-every (lambda (input)
                   (and (stringp (alist-get 'name input))
                        (wf--decimal-p (alist-get 'bytes input))
                        (let ((hash (alist-get 'sha256 input)))
                          (and (stringp hash) (string-match-p "\\`[0-9a-f]\\{64\\}\\'" hash)))))
                 (alist-get 'inputs value))
       (equal (alist-get 'personAnswering value) "local-control")))

(defun wf--filter (session chunk)
  "Advance SESSION's two-phase stream with CHUNK framed as raw UTF-8 lines."
  (unless (wf--session-error session)
    (condition-case err
        (progn
          (cl-incf (wf--session-bytes session) (string-bytes chunk))
          (when (> (wf--session-bytes session) wf--stream-limit)
            (error "Native stdout exceeds capture limit; output incomplete"))
          (setf (wf--session-wire session) (concat (wf--session-wire session) chunk))
          (let (end)
            (while (setq end (string-match "\n" (wf--session-wire session)))
              (when (and (not (eq (wf--session-phase session) 'preparing)) (> end (* 1024 1024)))
                (error "Runtime frame exceeds 1 MiB"))
              (setf (wf--session-rejected session) (substring (wf--session-wire session) 0 end))
              (let ((value (wf--json (wf--session-rejected session))))
                (setf (wf--session-wire session) (substring (wf--session-wire session) (1+ end)))
                (if (eq (wf--session-phase session) 'preparing)
                    (progn
                      (unless (wf--prepared-p value)
                        (error "Invalid prepared response"))
                      (setf (wf--session-prepared session) value
                            (wf--session-phase session) 'prepared))
                  (wf--event session value))
                (setf (wf--session-rejected session) nil)))
            (when (and (not (eq (wf--session-phase session) 'preparing))
                       (> (length (wf--session-wire session)) (* 1024 1024)))
              (error "Runtime frame exceeds 1 MiB")))
          (wf--render session))
      (error (wf--fail session (error-message-string err))))))

(defun wf--sentinel (session process)
  "Record SESSION exit from PROCESS truthfully, including incomplete framing."
  (when (memq (process-status process) '(exit signal failed closed))
    (unless (or (wf--session-error session) (eq (wf--session-phase session) 'discarded))
      (cond
       ((not (equal (wf--session-wire session) ""))
        (wf--fail session "Truncated native JSON frame"))
       ((not (memq (wf--session-phase session) '(completed failed cancelled)))
        (wf--fail session "Runner exited without terminal protocol event"))
       ((and (eq (wf--session-phase session) 'completed)
             (not (zerop (process-exit-status process))))
        (wf--fail session "Runner failed after completion event"))))
    (wf--render session)))

(defun wf--prepare (row inputs target directory)
  "Prepare ROW with INPUTS and opaque TARGET args in DIRECTORY.
Return the independent session after spawning; no run is started."
  (let ((default-directory directory))
    (wf--prepare-request
     `((version . 1) (operation . "prepare")
       (workflow . ,(alist-get 'name row))
       (stateDirectory . ,(wf--state-path))
       (personAnswering . "local-control")
       (targetArguments . ,(vconcat target)) (inputs . ,(vconcat inputs)))
     directory)))

(defun wf--make-process (&rest arguments)
  "Start a protocol process with ARGUMENTS, using call-local TRAMP pipes.
No connection profile or method configuration is changed persistently."
  (if (not (file-remote-p default-directory))
      (apply #'make-process arguments)
    (let* ((tramp-methods (copy-tree tramp-methods))
           (connection-local-default-application 'tramp)
           (connection-local-profile-alist (copy-tree connection-local-profile-alist))
           (connection-local-criteria-alist (copy-tree connection-local-criteria-alist))
           (remote (tramp-dissect-file-name default-directory))
           (method (assoc (tramp-file-name-method remote) tramp-methods))
           (direct (assq 'tramp-direct-async (cdr method))))
      (unless (cadr direct)
        (user-error "TRAMP method does not provide direct asynchronous processes"))
      (when (equal (cadr direct) '("-t" "-t"))
        (setcdr direct '(t)))
      (push '(wf-native-pipe (tramp-direct-async-process . t))
            connection-local-profile-alist)
      (push (list (connection-local-criteria-for-default-directory) 'wf-native-pipe)
            connection-local-criteria-alist)
      (unless (apply #'tramp-direct-async-process-p arguments)
        (user-error "TRAMP connection does not provide a direct protocol pipe"))
      (apply #'make-process arguments))))

(defvar-local wf--stderr-receiver nil
  "Receiver of bytes in a process-owned stderr buffer.")

(defun wf--stderr-buffer (name receiver)
  "Create hidden stderr buffer NAME for RECEIVER, activated after startup.
TRAMP may use the buffer during connection negotiation."
  (let ((buffer (generate-new-buffer (concat " " name))))
    (with-current-buffer buffer
      (set-buffer-multibyte nil)
      (setq wf--stderr-receiver receiver))
    buffer))

(defun wf--activate-stderr (buffer)
  "Forward captured and subsequent bytes from stderr BUFFER."
  (with-current-buffer buffer
    (unless (zerop (buffer-size))
      (funcall wf--stderr-receiver (get-buffer-process buffer) (buffer-string)))
    (add-hook
     'after-change-functions
     (lambda (start end _)
       (when (< start end)
         (funcall wf--stderr-receiver (get-buffer-process (current-buffer))
                  (buffer-substring-no-properties start end))))
     nil t)))

(defun wf--close-stderr (buffer)
  "Drain and close the process and hidden stderr BUFFER."
  (when (buffer-live-p buffer)
    (let ((process (get-buffer-process buffer)))
      (when (process-live-p process)
        (accept-process-output process 0.01)
        (when (process-live-p process) (delete-process process))))
    (kill-buffer buffer)))

(defun wf--prepare-request (request directory)
  "Prepare REQUEST on one worker in DIRECTORY without starting execution."
  (let* ((default-directory directory)
         (session (wf--session-create :directory directory :program wf-program
                                      :state-path (alist-get 'stateDirectory request)))
         (errors (wf--stderr-buffer
                  "wf diagnostics" (lambda (_ chunk)
                            (if (> (+ (string-bytes chunk)
                                      (string-bytes (or (wf--session-diagnostics session) "")))
                                   wf--stream-limit)
                                (wf--fail session "Native stderr exceeds capture limit; diagnostics incomplete")
                              (setf (wf--session-diagnostics session)
                                    (concat (wf--session-diagnostics session) chunk))
                              (wf--render session))))))
    (condition-case err
        (progn
          (wf--ensure-program directory)
          (setf (wf--session-process session)
                (wf--make-process :name "wf frontend" :buffer nil
                              :command (list wf-program "frontend")
                              :connection-type 'pipe :coding 'binary :noquery t
                              :file-handler t :stderr errors
                              :filter (lambda (_ chunk) (wf--filter session chunk))
                              :sentinel (lambda (process _)
                                          (when (memq (process-status process) '(exit signal failed closed))
                                            (unwind-protect (wf--sentinel session process)
                                              (wf--close-stderr errors))))))
          (unless (processp (wf--session-process session))
            (error "Connection does not support native pipe processes"))
          (push session wf--sessions)
          (wf--activate-stderr errors)
          (wf--send session request)
          session)
      ((error quit)
       (wf--close-stderr errors)
       (wf--fail session (error-message-string err))
       (signal (car err) (cdr err))))))

(defun wf--pretty (value)
  "Return indented JSON for VALUE without terminal control interpretation."
  (with-temp-buffer
    (insert (decode-coding-string
             (json-serialize value :null-object nil :false-object :false)
             'utf-8-unix))
    (json-pretty-print-buffer)
    (buffer-string)))

(defun wf--display-value (value)
  "Display textual VALUE directly and other JSON values structurally."
  (if (stringp value) value (wf--pretty value)))

(defun wf--snapshot-output (snapshot)
  "Render recorded output from SNAPSHOT without constructing runtime events."
  (if (null snapshot) "No runtime snapshot has been recorded.\n"
    (concat
     (format "%s — %s\nFresh/memo: %s/%s\n\n"
             (alist-get 'workflow snapshot) (alist-get 'status snapshot)
             (alist-get 'billFresh snapshot) (alist-get 'billMemo snapshot))
     (mapconcat
      (lambda (occurrence)
        (concat
         (format "Occurrence %s · %s · %s\n%s\n"
                 (alist-get 'id occurrence) (alist-get 'state occurrence)
                 (alist-get 'code occurrence) (alist-get 'addressee occurrence))
         (mapconcat (lambda (attempt)
                      (format "Attempt %s · %s · %s\n%s\n"
                              (alist-get 'id attempt) (alist-get 'target attempt)
                              (alist-get 'state attempt) (or (alist-get 'output attempt) "")))
                    (alist-get 'attempts occurrence) "\n")
         (when (stringp (alist-get 'answer occurrence))
           (concat "Recorded answer:\n" (alist-get 'answer occurrence) "\n"))
         (when (eq (alist-get 'personPending occurrence) t)
           "Human decision pending with the owning supervisor.\n")))
      (alist-get 'occurrences snapshot) "\n"))))

(defun wf--event-text (event)
  "Project validated EVENT as readable native text; diagnostics retain JSON."
  (let ((type (alist-get 'type event)))
    (concat
     (format "%s%s%s\n" type
             (if (alist-get 'occurrenceId event) (format " · occurrence %s" (alist-get 'occurrenceId event)) "")
             (if (alist-get 'attempt event) (format " · attempt %s" (alist-get 'attempt event)) ""))
     (pcase type
       ("occurrence.started"
        (format "%s · %s · %s\n%s\n" (alist-get 'intent event) (alist-get 'addressee event)
                (alist-get 'code event) (alist-get 'prompt event)))
       ("attempt.output" (concat (alist-get 'chunk event) "\n"))
       ("occurrence.completed" (format "%s\n%s\n" (alist-get 'source event) (alist-get 'answer event)))
       ("occurrence.person-answer-pending" "Human answer required.  Press a to verify full question and edit JSON.\n")
       ("run.completed" (format "Fresh: %s · memo: %s\nResult preview (not yet verified): %s\nPress r to verify full result.\n"
                                 (alist-get 'billFresh event) (alist-get 'billMemo event)
                                 (alist-get 'preview (alist-get 'result event))))
       ("control.ack" (format "%s · %s · %s\n%s\n" (alist-get 'controlId event)
                               (alist-get 'command event) (alist-get 'state event) (alist-get 'message event)))
       (_ (concat (wf--pretty event) "\n"))))))

(defun wf--render (session)
  "Refresh SESSION's view; follow only windows already at bottom."
  (let ((buffer (wf--session-view session)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (let ((inhibit-read-only t)
              (position (point))
              (bottom (= (point) (point-max)))
              (windows (mapcar (lambda (window)
                                 (list window (window-point window)
                                       (= (window-point window) (point-max))))
                               (get-buffer-window-list buffer nil t))))
          (erase-buffer)
          (insert (format "Run %s — %s\nRunner cwd: %s\nConnection directory: %s\n"
                          (alist-get 'runId (wf--session-prepared session))
                          (wf--session-phase session)
                          (alist-get 'cwd (wf--session-prepared session))
                          (wf--session-directory session))
                  "a answer · c control · C-c C-k cancel · r verified result\n"
                  "d diagnostics · g new root · R restart · S resume · F fork · = compare\n"
                  "H history · q bury (does not cancel)\n\n")
          (insert (format "Pending decisions (FIFO): %s\n\n"
                          (if (wf--session-pending session)
                              (string-join (wf--session-pending session) ", ") "none")))
          (when (wf--session-error session)
            (insert "FAILURE: " (wf--session-error session) "\n"))
          ;; ponytail: bounded full redraw; append-only projection if long runs need it.
          (dolist (frame (reverse (wf--session-events session)))
            (insert (wf--event-text (alist-get 'event frame)) "\n"))
          (goto-char (if bottom (point-max) (min position (point-max))))
          (dolist (item windows)
            (set-window-point (car item) (if (nth 2 item) (point-max)
                                           (min (nth 1 item) (point-max)))))
        (set-buffer-modified-p nil))))))

(defvar wf-run-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "C-c C-k") #'wf-kill)
    (define-key map (kbd "a") #'wf-answer)
    (define-key map (kbd "c") #'wf-control)
    (define-key map (kbd "r") #'wf-result)
    (define-key map (kbd "d") #'wf-diagnostics)
    (define-key map (kbd "g") #'wf-rerun)
    (define-key map (kbd "R") #'wf-restart)
    (define-key map (kbd "S") #'wf-resume)
    (define-key map (kbd "F") #'wf-fork)
    (define-key map (kbd "=") #'wf-lineage-compare)
    (define-key map (kbd "H") #'wf-history)
    map)
  "Local native run controls; views do not own processes.")

(define-derived-mode wf-run-mode special-mode "Workflow"
  "Display a native run without tying execution lifetime to this buffer.")

(defun wf--view (session)
  "Open or reopen SESSION's native view."
  (unless (buffer-live-p (wf--session-view session))
    (let ((buffer (generate-new-buffer
                   (format "*wf run %s*" (alist-get 'runId (wf--session-prepared session))))))
      (setf (wf--session-view session) buffer)
      (with-current-buffer buffer
        (wf-run-mode)
        (setq wf--session session default-directory (wf--session-directory session)))))
  (wf--render session)
  (pop-to-buffer (wf--session-view session)))

(defun wf-runs ()
  "Reopen an in-memory native session by its independent run identity."
  (interactive)
  (unless (wf--service 'wf-runs)
    (let ((choices (mapcar (lambda (session)
                             (cons (format "%s — %s" (alist-get 'runId (wf--session-prepared session))
                                           (wf--session-directory session)) session))
                           wf--sessions)))
      (wf--view (cdr (assoc (completing-read "Run: " choices nil t) choices))))))

(defun wf--current (&optional live)
  "Return the current session; require a live nonterminal run when LIVE."
  (unless (and wf--session (memq wf--session wf--sessions))
    (user-error "No native session in this view"))
  (when (and live (not (and (eq (wf--session-phase wf--session) 'running)
                           (process-live-p (wf--session-process wf--session)))))
    (user-error "Run is not live"))
  wf--session)

(defun wf--decision-inflight-p (session id)
  "Return non-nil when SESSION already sent an unresolved control for ID."
  (cl-some (lambda (entry)
             (and (equal id (alist-get 'expectedOccurrenceId (plist-get (cdr entry) :control)))
                  (not (member (plist-get (cdr entry) :state)
                               '("failed" "unsupported" "rejected-stale" "delivered")))))
           (wf--session-controls session)))

(defun wf--control-send (session command id)
  "Send on SESSION the COMMAND for live occurrence ID, retaining correlation."
  (unless (and (memq session wf--sessions) (eq (wf--session-phase session) 'running)
               (process-live-p (wf--session-process session)))
    (user-error "Run is not live"))
  (let* ((type (alist-get 'type command))
         (occ (cdr (assoc id (wf--session-occurrences session))))
         (attempt (plist-get occ :attempt))
         (cid (format "emacs-%d" (1+ (length (wf--session-controls session)))))
         (control `((controlId . ,cid) (expectedOccurrenceId . ,id)
                    (expectedAttemptId . ,(when attempt `((occurrenceId . ,id) (attemptNumber . ,attempt))))
                    (command . ,command))))
    (unless (or (and (equal type "cancelRun") (null id))
                (and occ (not (plist-get occ :terminal))))
      (user-error "Foreign, stale or terminal occurrence"))
    (unless (member type '("cancelRun" "answerPerson" "retryOccurrence" "failoverOccurrence"
                           "abandonOccurrence" "steerOccurrence" "redirectOccurrence"))
      (user-error "Unknown control command"))
    (when (equal type "steerOccurrence")
      (unless (or attempt (equal (alist-get 'timing command) "next-boundary"))
        (user-error "No live attempt to interrupt")))
    (when (equal type "redirectOccurrence")
      (unless (and (not attempt) (member (alist-get 'target command) (append (plist-get occ :targets) nil)))
        (user-error "Target is not an available dispatch choice")))
    (when (equal type "answerPerson")
      (unless (equal (alist-get 'type (plist-get occ :pending)) "occurrence.person-answer-pending")
        (user-error "Occurrence is not awaiting a human answer")))
    (when (member type '("retryOccurrence" "failoverOccurrence" "abandonOccurrence"))
      (let ((choice (cdr (assoc type '(("retryOccurrence" . "retry")
                                      ("failoverOccurrence" . "failover")
                                      ("abandonOccurrence" . "abandon"))))))
        (unless (cl-find choice (alist-get 'choices (plist-get occ :pending))
                         :key (lambda (option) (alist-get 'choice option)) :test #'equal)
          (user-error "Recovery choice is not available"))))
    (when (member type '("answerPerson" "retryOccurrence" "failoverOccurrence" "abandonOccurrence"))
      (unless (and (equal id (car (wf--session-pending session)))
                   (plist-get occ :pending))
        (user-error "Answer the oldest pending decision first"))
      (when (wf--decision-inflight-p session id)
        (user-error "A decision control is already in flight")))
    (let ((frame (wf--encode control (* 1024 1024)))
          (entry (cons cid (list :control control))))
      (push entry (wf--session-controls session))
      (condition-case failure
          (wf--send-frame session frame)
        ((error quit)
         (setf (plist-get (cdr entry) :state) "failed")
         (wf--fail session "Runtime control transport write failed")
         (signal (car failure) (cdr failure)))))))

(defun wf-kill ()
  "Request whole-run cancellation through the native control pipe."
  (interactive)
  (unless (wf--service 'wf-kill)
    (wf--control-send (wf--current t) '((type . "cancelRun")) nil)))

(defun wf-control ()
  "Send a native live control, with explicit occurrence context.
JSON objects use the runtime schema; the server is final authority."
  (interactive)
  (unless (wf--service 'wf-control)
    (let* ((session (wf--current t))
           (type (completing-read "Control: " '("steerOccurrence" "retryOccurrence"
                                                "failoverOccurrence" "abandonOccurrence"
                                                "redirectOccurrence") nil t))
           (ids (mapcar #'car (cl-remove-if (lambda (entry) (plist-get (cdr entry) :terminal))
                                            (wf--session-occurrences session))))
           (id (completing-read "Occurrence: " ids nil t nil nil (car (wf--session-pending session))))
           (context (copy-tree (cdr (assoc id (wf--session-occurrences session)))))
           (command (append `((type . ,type))
                            (pcase type
                              ("steerOccurrence" `((timing . ,(completing-read "Timing: " '("interrupt-now" "next-boundary") nil t))
                                                   (text . ,(read-string "Steering: "))))
                              ("redirectOccurrence"
                               `((target . ,(completing-read
                                             "Runtime target: "
                                             (append (plist-get (cdr (assoc id (wf--session-occurrences session))) :targets) nil)
                                             nil t))))))))
      (let ((current (cdr (assoc id (wf--session-occurrences session)))))
        (unless (cl-every (lambda (key) (equal (plist-get context key) (plist-get current key)))
                          '(:attempt :pending :targets :terminal))
          (user-error "Control context changed while editing; select it again")))
      (wf--control-send session command id))))

(defun wf--notice (name text directory)
  "Display native detail buffer NAME containing TEXT in DIRECTORY."
  (pop-to-buffer (wf--show name text directory)))

(defun wf--io (program directory request callback &optional refusal)
  "Use PROGRAM in DIRECTORY for read-only REQUEST, then call CALLBACK.
REFUSAL receives an error string; by default display a read-only notice."
  (let* ((default-directory directory)
         (operation (alist-get 'operation request))
         (output "") (errors "") failure stderr process started)
    (unwind-protect
        (progn
          (let ((inhibit-quit t))
            (setq stderr
                  (wf--stderr-buffer
                   "wf query errors" (lambda (pipe chunk)
                             (if (> (+ (length errors) (length chunk)) wf--stream-limit)
                                 (progn (setq failure "Query diagnostics exceed bound")
                                        (when (process-live-p pipe) (delete-process pipe)))
                               (setq errors (concat errors chunk))))))
            (setq process
                  (wf--make-process
                   :name "wf query" :buffer nil :noquery t :coding 'binary
                   :connection-type 'pipe :file-handler t :stderr stderr
                   :command (list program "frontend-io")
                   :filter (lambda (pipe chunk)
                             (if (> (+ (length output) (length chunk)) wf--stream-limit)
                                 (progn (setq failure "Query response exceeds bound")
                                        (delete-process pipe))
                               (setq output (concat output chunk))))
                   :sentinel
                   (lambda (pipe _)
                     (when (memq (process-status pipe) '(exit signal failed closed))
                       (unwind-protect
                           (condition-case err
                               (progn
                                 (when (buffer-live-p stderr)
                                   (accept-process-output (get-buffer-process stderr) 0.01))
                                 (when (or failure (not (zerop (process-exit-status pipe))))
                                   (error "Read-only verification refused: %s"
                                          (or failure (decode-coding-string errors 'utf-8))))
                                 (unless (and (string-suffix-p "\n" output)
                                              (= (cl-count ?\n output) 1))
                                   (error "Invalid query response framing"))
                                 (let ((value (wf--json output)))
                                   (unless (and (eq (alist-get 'version value) 1)
                                                (equal (alist-get 'operation value) operation))
                                     (error "Invalid query response identity"))
                                   (funcall callback value)))
                             (error
                              (if refusal (funcall refusal (error-message-string err))
                                (wf--notice (generate-new-buffer-name "*wf query refusal*")
                                            (error-message-string err) directory))))
                         (wf--close-stderr stderr)))))))
          (unless (processp process)
            (user-error "Connection does not support native query pipes"))
          (wf--activate-stderr stderr)
          (process-send-string process (wf--encode request))
          (process-send-eof process)
          (setq started t)
          process)
      (unless started
        (when (processp process)
          (set-process-sentinel process #'ignore)
          (when (process-live-p process) (delete-process process)))
        (wf--close-stderr stderr)))))

(defun wf--query (program directory request)
  "Use PROGRAM in DIRECTORY to return the read-only REQUEST response.
Failures are errors, never an empty catalogue.  Quitting stops only this query."
  (let (done value failure process)
    (unwind-protect
        (progn
          (setq process (wf--io program directory request
                               (lambda (reply) (setq value reply done t))
                               (lambda (message) (setq failure message done t))))
          (while (not done) (accept-process-output nil 0.05))
          (when failure (user-error "%s" failure))
          value)
      (when (process-live-p process) (delete-process process)))))

(defun wf--read-artifact (program directory root run operation reference callback &optional id code)
  "Verify artifact via PROGRAM in DIRECTORY under ROOT and RUN.
OPERATION and REFERENCE identify it; CALLBACK receives verified JSON.
Optional ID and CODE identify a question."
  (wf--io
   program directory
   (append `((version . 1) (operation . ,operation) (rootIdentity . ,root)
             (runId . ,run) (reference . ,reference))
           (when id `((occurrenceId . ,id) (codeName . ,code))))
   (lambda (value)
     (unless (and (equal (alist-get 'runId value) run)
                  (if id
                      (and (equal (alist-get 'occurrenceId value) id)
                           (stringp (alist-get 'intent value))
                           (listp (alist-get 'question value)))
                    (and (equal (alist-get 'code value) (alist-get 'code reference))
                         (assq 'value value))))
       (error "Invalid artifact response identity"))
     (funcall callback value))))

(defun wf--artifact (session operation reference callback &optional id code)
  "For SESSION use OPERATION to verify REFERENCE, then call CALLBACK.
ID and CODE identify a question.  Lisp never reads private store files."
  (wf--read-artifact
   (wf--session-program session) (wf--session-directory session)
   (alist-get 'rootIdentity (wf--session-prepared session))
   (alist-get 'runId (wf--session-prepared session))
   operation reference callback id code))

(defun wf-answer ()
  "Verify and display the oldest human question, then edit a JSON answer.
Boolean false is :false internally, never JSON null."
  (interactive)
  (unless (wf--service 'wf-answer)
    (let* ((session (wf--current t))
           (id (car (wf--session-pending session)))
           (occ (cdr (assoc id (wf--session-occurrences session))))
           (pending (plist-get occ :pending)))
      (unless (equal (alist-get 'type pending) "occurrence.person-answer-pending")
        (user-error "Oldest pending decision is not a human question"))
      (when (wf--decision-inflight-p session id)
        (user-error "Answer already sent; wait for acknowledgement"))
      (wf--artifact
       session "read-question" (alist-get 'question pending)
       (lambda (value)
         (unless (and (eq (wf--session-phase session) 'running)
                      (equal id (car (wf--session-pending session)))
                      (not (wf--decision-inflight-p session id))
                      (equal pending (plist-get (cdr (assoc id (wf--session-occurrences session))) :pending)))
           (user-error "Question context changed during verification; select it again"))
         (wf--notice (generate-new-buffer-name "*wf verified question*")
                     (concat (or (alist-get 'prompt (alist-get 'question value)) "")
                             "\n\nVerified question details:\n" (wf--pretty value))
                     (wf--session-directory session))
         (wf--answer-editor session id value))
       id (alist-get 'code (plist-get occ :event))))))

(defun wf--answer-editor (session id question)
  "Open a multiline JSON answer editor for SESSION, ID and verified QUESTION."
  (let ((buffer (generate-new-buffer "*wf answer JSON*")))
    (with-current-buffer buffer
      (text-mode)
      (use-local-map (make-sparse-keymap))
      (setq-local header-line-format "JSON answer — C-c C-c sends; C-c C-k abandons editor")
      (insert (if (equal (alist-get 'code (alist-get 'question question)) "flag") "true" "null"))
      (local-set-key
       (kbd "C-c C-c")
       (lambda ()
         (interactive)
         (let ((answer (wf--json (buffer-substring-no-properties (point-min) (point-max)))))
           (wf--control-send session `((type . "answerPerson") (answer . ,answer)) id)
           (kill-buffer buffer))))
      (local-set-key (kbd "C-c C-k") (lambda () (interactive) (kill-buffer buffer))))
    (pop-to-buffer buffer '(display-buffer-pop-up-window))))

(defun wf-result ()
  "Read the available result through the runner's read-only verifier."
  (interactive)
  (unless (wf--service 'wf-result)
    (let* ((session (wf--current)) (reference (wf--session-result session)))
      (unless reference (user-error "No result reference available"))
      (wf--artifact session "read-result" reference
                    (lambda (value)
                      (wf--notice (generate-new-buffer-name "*wf verified result*")
                                  (concat "Verified content only; not ownership or whole-store health.\n\n"
                                          (wf--display-value (alist-get 'value value)))
                                  (wf--session-directory session)))))))

(defun wf-diagnostics ()
  "Show all captured native stderr and validated protocol envelopes."
  (interactive)
  (unless (wf--service 'wf-diagnostics)
    (let ((session (wf--current)))
      (wf--notice (generate-new-buffer-name "*wf diagnostics*")
                  (concat (when (processp (wf--session-process session))
                            (format "Process: %s; exit status: %s\n"
                                    (process-status (wf--session-process session))
                                    (process-exit-status (wf--session-process session))))
                          "stderr (untrusted text):\n"
                          (decode-coding-string (or (wf--session-diagnostics session) "") 'utf-8)
                          "\nRejected/truncated protocol (untrusted text):\n"
                          (decode-coding-string (or (wf--session-rejected session) (wf--session-wire session)) 'utf-8)
                          "\nProtocol:\n"
                          (mapconcat #'wf--pretty (reverse (wf--session-events session)) "\n"))
                  (wf--session-directory session)))))

(defun wf--review (session)
  "Display SESSION's exact prepared plan and ask explicit start approval."
  (let* ((preview (wf--session-prepared session))
         (scripted (equal (alist-get 'targetKind preview) "scripted"))
         (buffer (generate-new-buffer "*wf prepared review*")))
    (unwind-protect
        (save-window-excursion
          (wf--show (buffer-name buffer)
                    (concat "Exact prepared run — no run has started.\n"
                            (if scripted "Scripted target: no provider billing.\n"
                              "WARNING: non-scripted target may incur provider charges.\n")
                            "Review actual plan bounds, effects, source hashes, target and routing policy below.\n"
                            "Approval starts THIS prepared process; edits require fresh preparation.\n\n"
                            (wf--pretty preview))
                    (wf--session-directory session))
          (display-buffer buffer)
          (funcall wf-confirm-function
                   (format "Start prepared run %s via %s%s? "
                           (alist-get 'runId preview) (alist-get 'targetKind preview)
                           (if scripted "" " (provider charges possible)"))))
      (kill-buffer buffer))))

;;; Persistent read-only records and semantic lineage

(cl-defstruct (wf--store (:constructor wf--store-create))
  "Runner connection and opaque store identity, not execution authority."
  program directory path root)

(defvar-local wf--store nil
  "Store queried by this history or observer buffer.")

(defvar-local wf--record nil
  "Authoritative observed record, never a prepared session or event stream.")

(defun wf--store-query (store operation &optional run)
  "Query STORE with OPERATION and optional RUN identity."
  (wf--query (wf--store-program store) (wf--store-directory store)
             (append `((version . 1) (operation . ,operation)
                       (rootIdentity . ,(wf--store-root store)))
                     (when run `((runId . ,run))))))

(defun wf--read-record (store run)
  "Read STORE record for RUN, refusing mismatched identities."
  (let ((record (alist-get 'run (wf--store-query store "read-run" run))))
    (unless (and (equal (alist-get 'runId record) run)
                 (equal (alist-get 'runId (alist-get 'manifest record)) run))
      (user-error "Invalid stored run identity"))
    record))

(defun wf-history-refresh ()
  "Refresh persistent history; query errors leave the previous table intact."
  (interactive)
  (unless (wf--service 'wf-history-refresh)
    (unless wf--store (user-error "No history store"))
    (let ((runs (alist-get 'runs (wf--store-query wf--store "list-runs"))))
      (unless (vectorp runs) (user-error "Invalid history catalogue"))
      (setq tabulated-list-entries
            (mapcar
             (lambda (row)
               (let ((snapshot (alist-get 'snapshot row)))
                 (list row
                       (if (equal (alist-get 'kind row) "corrupt")
                           (vector (format "%s" (alist-get 'directory row)) "CORRUPT"
                                   (format "%s" (alist-get 'error row)) "" "" "" "" "")
                         (vector (format "%s" (alist-get 'runId row))
                                 (or (alist-get 'status snapshot) "not-started")
                                 (format "%s / %s" (alist-get 'runnerId row) (alist-get 'workflow row))
                                 (format "%s/%s" (alist-get 'billFresh snapshot) (alist-get 'billMemo snapshot))
                                 (format "%s ← %s" (alist-get 'lineage row) (or (alist-get 'parentRunId row) "root"))
                                 (or (alist-get 'ownership row) "unknown")
                                 (format "%s / %s" (alist-get 'persona row) (alist-get 'targetKind row))
                                 (or (alist-get 'createdAt row) ""))))))
             runs))
      (tabulated-list-print t))))

(defvar wf-history-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "RET") #'wf-history-open)
    (define-key map (kbd "g") #'wf-history-refresh)
    map)
  "Persistent history keys.")

(define-derived-mode wf-history-mode tabulated-list-mode "wf-history"
  "Browse healthy and corrupt stored runs; RET opens an observer or local view."
  (setq tabulated-list-format [("Run / directory" 32 t) ("Status" 13 t)
                              ("Runner / workflow / error" 28 t) ("Fresh/memo" 12 t)
                              ("Lineage ← parent" 35 t) ("Ownership" 18 t)
                              ("Persona / target" 20 t) ("Created" 24 t)])
  (tabulated-list-init-header))

;;;###autoload
(defun wf-history ()
  "Open persistent history for this view's store, or the configured connection.
Store discovery never grants control and never creates a state directory."
  (interactive)
  (unless (wf--service 'wf-history)
    (let* ((store
            (or wf--store
                (when wf--session
                  (wf--store-create :program (wf--session-program wf--session)
                                    :directory (wf--session-directory wf--session)
                                    :path (wf--session-state-path wf--session)
                                    :root (alist-get 'rootIdentity (wf--session-prepared wf--session))))
                (let* ((path (wf--state-path))
                       (root (alist-get 'rootIdentity
                                        (wf--query wf-program default-directory
                                                   `((version . 1) (operation . "open-root") (path . ,path))))))
                  (wf--store-create :program wf-program :directory default-directory
                                    :path path :root root))))
           (buffer (generate-new-buffer "*wf history*")))
      (with-current-buffer buffer
        (wf-history-mode)
        (setq wf--store store default-directory (wf--store-directory store))
        (wf-history-refresh))
      (pop-to-buffer buffer))))

(defun wf--owned-session (store record)
  "Find a live local session matching STORE and RECORD, never infer ownership."
  (cl-find-if
   (lambda (session)
     (let ((prepared (wf--session-prepared session)))
       (and (eq (wf--session-phase session) 'running)
            (process-live-p (wf--session-process session))
            (equal (wf--store-program store) (wf--session-program session))
            (equal (file-remote-p (wf--store-directory store))
                   (file-remote-p (wf--session-directory session)))
            (equal (wf--store-root store) (alist-get 'rootIdentity prepared))
            (equal (alist-get 'runId record) (alist-get 'runId prepared)))))
   wf--sessions))

(defun wf-history-open ()
  "Open the selected healthy run; corrupt records remain visible with errors."
  (interactive)
  (unless (wf--service 'wf-history-open)
    (let ((row (tabulated-list-get-id)))
      (unless row (user-error "Select a history row"))
      (when (equal (alist-get 'kind row) "corrupt")
        (user-error "Corrupt run %s: %s" (alist-get 'directory row) (alist-get 'error row)))
      (wf--observe wf--store (wf--read-record wf--store (alist-get 'runId row))))))

(defvar wf-observer-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "g") #'wf-observer-refresh)
    (define-key map (kbd "r") #'wf-observer-result)
    (define-key map (kbd "R") #'wf-restart)
    (define-key map (kbd "S") #'wf-resume)
    (define-key map (kbd "F") #'wf-fork)
    (define-key map (kbd "=") #'wf-lineage-compare)
    map)
  "Observer keys deliberately exclude live controls.")

(define-derived-mode wf-observer-mode special-mode "wf-observer"
  "Read authoritative records without adopting another supervisor's run.")

(defun wf--observer-render ()
  "Render the current observed record without fabricating runtime events."
  (let ((inhibit-read-only t) (position (point)))
    (erase-buffer)
    (insert "OBSERVER ONLY — store data grants no control\n"
            "g refresh · r verified result · R restart · S resume · F fork · = compare\n"
            "q bury; closing this view cannot cancel any run\n\n"
            (wf--snapshot-output (alist-get 'snapshot wf--record))
            "\nFull record and snapshot details:\n"
            (wf--pretty wf--record))
    (goto-char (min position (point-max)))))

(defun wf--observe (store record)
  "From STORE open RECORD, reusing only a matching locally owned live session."
  (let ((session (wf--owned-session store record)))
    (if session (wf--view session)
      (let ((buffer (generate-new-buffer (format "*wf observer %s*" (alist-get 'runId record)))))
        (with-current-buffer buffer
          (wf-observer-mode)
          (setq wf--store store wf--record record default-directory (wf--store-directory store))
          (wf--observer-render))
        (pop-to-buffer buffer)))))

(defun wf-observer-refresh ()
  "Refresh this observer from the shared read-only query, retaining errors."
  (interactive)
  (unless (wf--service 'wf-observer-refresh)
    (unless (and wf--store wf--record) (user-error "No observed run"))
    (setq wf--record (wf--read-record wf--store (alist-get 'runId wf--record)))
    (wf--observer-render)))

(defun wf-observer-result ()
  "Verify the observed result reference before displaying content."
  (interactive)
  (unless (wf--service 'wf-observer-result)
    (unless (and wf--store wf--record) (user-error "No observed run"))
    (let* ((store wf--store)
           (run (alist-get 'runId wf--record))
           (reference (alist-get 'result (alist-get 'snapshot wf--record))))
      (unless reference (user-error "No recorded result reference"))
      (wf--read-artifact
       (wf--store-program store) (wf--store-directory store) (wf--store-root store)
       run "read-result" reference
       (lambda (value)
         (wf--notice (generate-new-buffer-name (format "*wf verified result %s*" run))
                     (wf--display-value (alist-get 'value value)) (wf--store-directory store)))))))

(defun wf--lineage-context ()
  "Return store and freshly queried record from this local or observed view."
  (let* ((session (and (not wf--record) (wf--current)))
         (prepared (and session (wf--session-prepared session)))
         (store (or wf--store
                    (wf--store-create :program (wf--session-program session)
                                      :directory (wf--session-directory session)
                                      :path (wf--session-state-path session)
                                      :root (alist-get 'rootIdentity prepared))))
         (run (if wf--record (alist-get 'runId wf--record) (alist-get 'runId prepared))))
    (list store (wf--read-record store run))))

(defun wf-lineage-compare ()
  "Display authoritative parent and child records, including full snapshots."
  (interactive)
  (unless (wf--service 'wf-lineage-compare)
    (pcase-let* ((`(,store ,child) (wf--lineage-context))
                 (parent (alist-get 'parentRunId (alist-get 'manifest child))))
      (unless parent (user-error "Root run has no parent"))
      (wf--notice (generate-new-buffer-name "*wf lineage comparison*")
                  (concat "PARENT (read-only record and snapshot)\n"
                          (wf--pretty (wf--read-record store parent))
                          "\nCHILD (read-only record and snapshot)\n" (wf--pretty child))
                  (wf--store-directory store)))))

(defun wf--fork-edits-p (edits)
  "Validate fork EDITS shape without interpreting workflow semantics or types."
  (and (vectorp edits)
       (cl-every
        (lambda (edit)
          (and (listp edit) (wf--decimal-p (alist-get 'occurrenceId edit))
               (pcase (alist-get 'operation edit)
                 ("drop" (and (= (length edit) 2) (assq 'operation edit)))
                 ("replace" (and (= (length edit) 3) (assq 'answer edit)))
                 (_ nil)))) edits)))

(defun wf--lineage (kind &optional edits)
  "Prepare semantic KIND with optional fork EDITS from the current record."
  (pcase-let* ((`(,store ,record) (wf--lineage-context))
               (wf-program (wf--store-program store))
               (session (wf--prepare-request
                         `((version . 1) (operation . "prepare-lineage")
                           (stateDirectory . ,(wf--store-path store))
                           (parentRunId . ,(alist-get 'runId record)) (lineage . ,kind)
                           (personAnswering . "local-control") (edits . ,(or edits [])))
                         (wf--store-directory store))))
    (wf--approve session)))

(defun wf-restart ()
  "Prepare semantic restart with parent source bytes; require same-worker approval."
  (interactive)
  (unless (wf--service 'wf-restart)
    (wf--lineage "restart")))

(defun wf-resume ()
  "Prepare semantic resume; backend validates checkpoint, effects and ownership."
  (interactive)
  (unless (wf--service 'wf-resume)
    (wf--lineage "resume")))

(defvar-local wf--fork-context nil
  "Store and parent record selected for this immutable fork editor.")

(defun wf-fork ()
  "Edit immutable fork drop/replacement JSON, with explicit confirmation.
Replacement answer is a JSON value, including false; backend checks its type."
  (interactive)
  (unless (wf--service 'wf-fork)
    (let ((context (wf--lineage-context)) (buffer (generate-new-buffer "*wf fork edits*")))
      (display-buffer
       (wf--show (generate-new-buffer-name "*wf fork parent*")
                 (concat "IMMUTABLE PARENT — occurrence IDs, codes and answers\n"
                         (wf--pretty (cadr context))) (wf--store-directory (car context))))
      (with-current-buffer buffer
        (fundamental-mode)
        (setq wf--fork-context context default-directory (wf--store-directory (car context)))
        (insert "[]\n")
        (setq header-line-format
              "JSON edits: drop {operation,occurrenceId}; replace adds answer. C-c C-c review; C-c C-k cancel")
        (use-local-map (make-sparse-keymap))
        (local-set-key (kbd "C-c C-c") #'wf-fork-submit)
        (local-set-key (kbd "C-c C-k") #'kill-current-buffer))
      (pop-to-buffer buffer))))

(defun wf-fork-submit ()
  "Validate fork JSON and explicitly confirm immutable child preparation."
  (interactive)
  (unless (wf--service 'wf-fork-submit)
    (unless wf--fork-context (user-error "Not a fork editor"))
    (let ((edits (condition-case err (wf--json (buffer-string))
                   (error (user-error "Invalid fork JSON: %s" (error-message-string err)))))
          (wf--store (car wf--fork-context)) (wf--record (cadr wf--fork-context)))
      (unless (wf--fork-edits-p edits) (user-error "Expected array of drop or typed replace edits"))
      (when (funcall wf-confirm-function
                     (format "Prepare immutable fork of %s with %d edits? "
                             (alist-get 'runId wf--record) (length edits)))
        (wf--lineage "fork" edits)))))

;;;###autoload
(defun wf-run (&optional refresh)
  "Set up all inputs, prepare and explicitly approve one native root run.
With REFRESH, refresh descriptor discovery.  Preparation and start share
one process and frozen program.  Closing a view never cancels execution."
  (interactive "P")
  (unless (wf--service 'wf-run refresh)
    (let* ((directory default-directory)
           (row (wf--read-row "Workflow: " refresh))
           (inputs (wf--setup-inputs row))
           (target (wf--read-transport row)))
      (wf--approve (wf--prepare row inputs target directory)))))

(defun wf--approve (session)
  "Review SESSION and start or discard on its original process."
  (let (approved)
    (unwind-protect
        (progn
          (while (and (eq (wf--session-phase session) 'preparing)
                      (process-live-p (wf--session-process session)))
            (accept-process-output (wf--session-process session) 0.1))
          (unless (eq (wf--session-phase session) 'prepared)
            (wf--view session)
            (user-error "Preparation failed; see run diagnostics"))
          (when (wf--review session)
            (unless (and (eq (wf--session-phase session) 'prepared)
                         (process-live-p (wf--session-process session)))
              (user-error "Prepared process no longer available; prepare again"))
            (setf (wf--session-phase session) 'running)
            (wf--send session `((version . 1) (operation . "start")
                                (approvalId . ,(alist-get 'approvalId (wf--session-prepared session)))))
            (setq approved t)
            (wf--view session)))
      (unless approved
        (if (and (eq (wf--session-phase session) 'prepared) (process-live-p (wf--session-process session)))
            (progn
              (setf (wf--session-phase session) 'discarded)
              (wf--send session `((version . 1) (operation . "discard")
                                  (approvalId . ,(alist-get 'approvalId (wf--session-prepared session)))))
              (process-send-eof (wf--session-process session)))
          (when (process-live-p (wf--session-process session))
            (delete-process (wf--session-process session))))))))

(defun wf-rerun ()
  "Open fresh root setup in this session's directory, not resume or fork."
  (interactive)
  (unless (wf--service 'wf-rerun)
    (let* ((session (wf--current))
           (default-directory (wf--session-directory session))
           (wf-program (wf--session-program session)))
      (wf-run))))

;;;###autoload
(defun wf-plan (&optional refresh)
  "Pick a workflow and read `wf plan' for it, without running anything.
A prefix argument, REFRESH, fetches the row listing again."
  (interactive "P")
  (unless (wf--service 'wf-plan refresh)
    (let ((row (wf--read-row "Plan workflow: " refresh)))
      (pop-to-buffer
       (wf--show (wf--buffer-name "wf plan" (alist-get 'name row))
                 (wf--call "plan" (alist-get 'name row))
                 default-directory)))))

;;;###autoload
(defun wf-cost (&optional refresh)
  "Pick a workflow and read `wf cost' for it, without running anything.
A prefix argument, REFRESH, fetches the row listing again."
  (interactive "P")
  (unless (wf--service 'wf-cost refresh)
    (let ((row (wf--read-row "Cost workflow: " refresh)))
      (pop-to-buffer
       (wf--show (wf--buffer-name "wf cost" (alist-get 'name row))
                 (wf--call "cost" (alist-get 'name row))
                 default-directory)))))

;;;###autoload
(defun wf-help (&optional refresh)
  "Pick a workflow and read its page, without running anything.
A prefix argument, REFRESH, fetches the row listing again.

The page is `wf help' \\='s stdout, shown as the binary printed it.  It is
prose and has no machine-readable spelling — there is no `help --json' —
so this displays the text and never parses it, which is the same
arrangement `wf-plan' and `wf-cost' have with theirs.

In service mode, the command reads the catalogue of the manager and
shows the help text that the catalogue states for the workflow."
  (interactive "P")
  (unless (wf--service 'wf-help refresh)
    (let ((row (wf--read-row "Help on workflow: " refresh)))
      (pop-to-buffer
       (wf--show (wf--buffer-name "wf help" (alist-get 'name row))
                 (wf--call "help" (alist-get 'name row))
                 default-directory)))))

(provide 'wf)

;;; wf.el ends here
