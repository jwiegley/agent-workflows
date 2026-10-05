#!/usr/bin/env python3
"""Exercise native Emacs widgets, windows, real scripted runs, and the service journey, lifecycle, controls, cross-client witness, its lifecycle and its lineage in private PTYs."""
from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time


def string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def terminal_attributes(attributes: list) -> list:
    result = list(attributes[:6]) + [[value[0] if isinstance(value, bytes) else value for value in attributes[6]]]
    result[3] &= ~getattr(termios, "PENDIN", 0)
    return result


def tty_host() -> None:
    child = subprocess.Popen(sys.argv[3:], close_fds=True)
    status = child.wait()
    Path(sys.argv[2]).write_text(json.dumps({"status": status, "attributes": terminal_attributes(termios.tcgetattr(0))}))
    raise SystemExit(status if status >= 0 else 128 - status)


class Emacs:
    """One isolated Emacs -Q -nw in a private PTY.

    SOURCE is the Lisp file to load, or a list of them, loaded in order.
    The state report also holds the value of `wf-ui-extra' under extra
    when BODY defines that function, and the last lines of *Messages*."""

    def __init__(self, executable: str, source: Path | list[Path], directory: Path, width: int, height: int, body: str):
        self.directory = directory
        directory.mkdir()
        (directory / "home").mkdir()
        self.state_path = directory / "state.json"
        state_path = string(str(self.state_path))
        initialization = f'''
(setq inhibit-startup-screen t ring-bell-function #'ignore)
(defvar wf-ui-result nil)
(defun wf-ui-report ()
  (condition-case nil
      (with-current-buffer (window-buffer (selected-window))
       (let* ((mini (active-minibuffer-window))
             (state `((mode . ,(symbol-name major-mode))
                      (buffer . ,(buffer-name))
                      (text . ,(buffer-substring-no-properties (point-min) (min (point-max) (+ (point-min) 24000))))
                      (minibuffer . ,(if mini (with-current-buffer (window-buffer mini) (buffer-string)) ""))
                      (width . ,(frame-width)) (height . ,(frame-total-lines))
                      (result . ,wf-ui-result)
                      (messages . ,(let ((log (get-buffer "*Messages*")))
                                     (if log
                                         (with-current-buffer log
                                           (buffer-substring-no-properties
                                            (max (point-min) (- (point-max) 6000)) (point-max)))
                                       "")))
                      (extra . ,(and (fboundp 'wf-ui-extra) (funcall 'wf-ui-extra)))
                      (sessions . ,(vconcat (mapcar (lambda (session)
                        `((id . ,(alist-get 'runId (wf--session-prepared session)))
                          (phase . ,(symbol-name (wf--session-phase session)))
                          (error . ,(wf--session-error session))
                          (targets . ,(vconcat (mapcan (lambda (entry)
                            (append (plist-get (cdr entry) :targets) nil))
                            (wf--session-occurrences session))))
                          (pending . ,(vconcat (wf--session-pending session))))) wf--sessions)))
                      (windows . ,(vconcat (mapcar (lambda (window)
                        (with-current-buffer (window-buffer window)
                          `((buffer . ,(buffer-name)) (point . ,(window-point window))
                            (start . ,(window-start window)) (end . ,(window-end window t))
                            (maximum . ,(point-max)) (width . ,(window-body-width window))
                            (height . ,(window-body-height window))))) (window-list nil 'no-minibuffer)))))))
        (let ((default-directory "/") (coding-system-for-write 'utf-8-unix))
          (with-temp-file {state_path}
            (insert (decode-coding-string (json-serialize state :null-object nil :false-object :false) 'utf-8-unix))))))
    (error nil)))
(run-at-time 0 0.05 #'wf-ui-report)
{body}
'''
        init = directory / "init.el"
        init.write_text(initialization)
        init.chmod(0o600)
        self.master, self.slave = pty.openpty()
        self.before = terminal_attributes(termios.tcgetattr(self.slave))
        self.exit_path = directory / "exit.json"
        self.ended: dict = {}
        sources = source if isinstance(source, list) else [source]
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))
        environment = {key: value for key, value in os.environ.items() if not key.startswith("AGENT_CAT_")}
        environment.update(HOME=str(directory / "home"), TERM="xterm-256color")

        def terminal() -> None:
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen(
            [sys.executable, str(Path(__file__).resolve()), "--tty-host", str(self.exit_path),
             executable, "-Q", "-nw", *[item for path in sources for item in ("-l", str(path))], "-l", str(init)],
            stdin=self.slave, stdout=self.slave, stderr=self.slave,
            env=environment, cwd=directory, preexec_fn=terminal, close_fds=True,
        )
        self.log = bytearray()
        self.state: dict = {}

    def drain(self, duration: float = 0.05) -> None:
        ready, _, _ = select.select([self.master], [], [], duration)
        if ready:
            try:
                block = os.read(self.master, 65536)
            except OSError:
                return
            self.log.extend(block)
            for query, response in [
                (b"\x1b[6n", b"\x1b[1;1R"),
                (b"\x1b]11;?\x07", b"\x1b]11;rgb:0000/0000/0000\x1b\\"),
                (b"\x1b]10;?\x07", b"\x1b]10;rgb:ffff/ffff/ffff\x1b\\"),
            ]:
                if query in block:
                    os.write(self.master, response)
        try:
            self.state = json.loads(self.state_path.read_bytes())
        except (FileNotFoundError, json.JSONDecodeError):
            pass

    def wait(self, predicate, label: str, timeout: float = 20) -> dict:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.drain()
            if predicate(self.state):
                (self.directory / (label + ".json")).write_text(json.dumps(self.state, ensure_ascii=False, indent=2))
                return self.state
            if self.process.poll() is not None:
                break
        raise AssertionError((label, self.process.poll(), self.state, bytes(self.log[-2000:])))

    def send(self, value: bytes | str) -> None:
        os.write(self.master, value.encode() if isinstance(value, str) else value)
        self.drain()

    def command(self, name: str) -> None:
        self.send(b"\x1bx" + name.encode() + b"\r")

    def resize(self, width: int, height: int) -> None:
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))
        os.killpg(self.process.pid, signal.SIGWINCH)
        self.wait(lambda state: state.get("width") == width and state.get("height") == height, f"resize-{width}x{height}")

    def close(self, normal: bool = True, send_quit: bool = True) -> None:
        if normal and send_quit and self.process.poll() is None:
            self.send(b"\x18\x03")
        deadline = time.monotonic() + 5
        while self.process.poll() is None and time.monotonic() < deadline:
            self.drain()
        if self.process.poll() is None:
            os.killpg(self.process.pid, signal.SIGKILL)
            deadline = time.monotonic() + 10
            while self.process.poll() is None and time.monotonic() < deadline:
                self.drain()
        (self.directory / "terminal.log").write_bytes(self.log)
        os.close(self.master)
        os.close(self.slave)
        self.process.wait(timeout=10)
        if normal:
            assert self.process.returncode == 0, self.process.returncode
            ended = json.loads(self.exit_path.read_bytes())
            self.ended = ended
            assert ended["status"] == 0, ended
            assert ended["attributes"] == self.before, (self.before, ended["attributes"])


def form_case(args, directory: Path, width: int, height: int) -> None:
    output = directory / "answer.json"
    body = f'''
(let ((result (wf--setup-inputs '((name . "four-inputs")
              (inputs . (((name . "first")) ((name . "second"))
                         ((name . "third")) ((name . "fourth"))))))))
  (let ((coding-system-for-write 'utf-8-unix))
    (with-temp-file {string(str(output))}
      (insert (decode-coding-string (json-serialize (vconcat result)) 'utf-8-unix))))
  (kill-emacs 0))
'''
    session = Emacs(args.emacs, args.source, directory, width, height, body)
    success = False
    try:
        session.wait(lambda state: state.get("mode") == "wf--setup-mode", "form-ready")
        session.send("α雪")
        if width == 40:
            session.resize(80, 24)
            session.resize(40, 12)
        session.send(b"\t\t\tbeta\t\t\tgamma\t\t\tdelta")
        session.send(b"\x03\x03")
        deadline = time.monotonic() + 10
        while not output.exists() and time.monotonic() < deadline:
            session.drain()
        values = json.loads(output.read_bytes())
        assert [item["value"] for item in values] == ["α雪", "beta", "gamma", "delta"], values
        assert all(item["source"] == "literal" for item in values)
        success = True
    finally:
        session.close(success, send_quit=False)


def human_case(args, directory: Path, configuration: str = "", work_directory: str | None = None, state_directory: Path | None = None) -> None:
    body = configuration + f'''
(setq wf-program {string(args.control_runner)}
      wf-state-directory {string(str(state_directory or directory / 'runs'))}
      default-directory {string(work_directory or str(directory) + '/')})
(wf-run)
'''
    session = Emacs(args.emacs, args.source, directory, 80, 24, body)
    success = False
    try:
        session.wait(lambda state: "Workflow:" in state.get("minibuffer", ""), "workflow-prompt")
        session.send("person-controlled\r")
        session.wait(lambda state: state.get("mode") == "wf--setup-mode", "human-input")
        session.send("native interactive question")
        session.send(b"\x03\x03")
        session.wait(lambda state: "Transport" in state.get("minibuffer", ""), "transport-prompt")
        session.send("scripted\r")
        session.wait(lambda state: "Start prepared" in state.get("minibuffer", ""), "review-prompt")
        session.resize(40, 12)
        session.send("yes\r")
        session.wait(lambda state: any(item.get("pending") for item in state.get("sessions", [])), "first-pending")
        session.resize(140, 36)
        for index, answer in enumerate(["false", "true"]):
            session.wait(lambda state: state.get("mode") == "wf-run-mode", f"run-view-{index}")
            session.send("a")
            session.wait(lambda state: state.get("buffer", "").startswith("*wf answer JSON"), f"answer-editor-{index}")
            session.send(b"\x18h\x17")
            session.send(answer)
            session.send(b"\x03\x03")
            if index == 0:
                session.wait(lambda state: any(item.get("pending") == ["1"] for item in state.get("sessions", [])), "second-pending")
                session.command("wf-runs")
                session.wait(lambda state: "Run:" in state.get("minibuffer", ""), "run-picker")
                session.send("\r")
        session.wait(lambda state: any(item.get("phase") == "completed" for item in state.get("sessions", [])), "human-completed")
        session.command("wf-runs")
        session.wait(lambda state: "Run:" in state.get("minibuffer", ""), "completed-picker")
        session.send("\r")
        session.wait(lambda state: state.get("mode") == "wf-run-mode", "completed-view")
        session.send("r")
        session.wait(lambda state: state.get("buffer", "").startswith("*wf verified result"), "verified-result")
        session.command("wf-history")
        session.wait(lambda state: state.get("mode") == "wf-history-mode", "human-history")
        session.send("\r")
        session.wait(lambda state: state.get("mode") == "wf-observer-mode", "human-observer")
        assert "OBSERVER ONLY" in session.state["text"]
        success = True
    finally:
        session.close(success)


def recovery_case(args, directory: Path, command: str) -> None:
    routed = command == "failoverOccurrence"
    arguments = ["--engine", "acp", "--adapter", sys.executable, "--adapter-arg",
                 str(args.control_adapters / "retry_adapter.py"), "--timeout", "10000"]
    if routed:
        arguments.extend(["--route", "spare=acp:" + str(args.control_adapters / "stub_adapter.py")])
    body = f'''
(setq wf-program {string(args.control_runner)}
      wf-state-directory {string(str(directory / 'runs'))}
      default-directory {string(str(directory) + '/')})
(cl-letf (((symbol-function 'wf--read-transport)
           (lambda (&optional _) '({' '.join(string(argument) for argument in arguments)}))))
  (wf-run))
'''
    session = Emacs(args.emacs, args.source, directory, 80, 24, body)
    success = False
    try:
        session.wait(lambda state: "Workflow:" in state.get("minibuffer", ""), "workflow-prompt")
        session.send(("controlled" if routed else "controlled-single") + "\r")
        session.wait(lambda state: state.get("mode") == "wf--setup-mode", "recovery-input")
        session.send("native keyboard recovery")
        session.send(b"\x03\x03")
        session.wait(lambda state: "Start prepared" in state.get("minibuffer", ""), "review-prompt")
        session.send("yes\r")
        session.wait(lambda state: state.get("mode") == "wf-run-mode", "recovery-view")

        def choose(control: str, target: str | None = None) -> None:
            session.send("c")
            session.wait(lambda state: "Control:" in state.get("minibuffer", ""), control + "-prompt")
            session.send(control)
            session.resize(40, 12)
            assert control in session.state["minibuffer"]
            session.resize(140, 36)
            assert control in session.state["minibuffer"]
            session.send("\r")
            session.wait(lambda state: "Occurrence:" in state.get("minibuffer", ""), control + "-occurrence")
            session.send("0\r")
            if target is not None:
                session.wait(lambda state: "Runtime target:" in state.get("minibuffer", ""), control + "-target")
                session.send(target + "\r")

        if routed:
            dispatch = session.wait(lambda state: any(item.get("targets") for item in state.get("sessions", [])), "dispatch-pending")
            choose("redirectOccurrence", dispatch["sessions"][0]["targets"][0])
        pending = session.wait(lambda state: any(item.get("pending") == ["0"] for item in state.get("sessions", [])), "recovery-pending")
        assert not pending["sessions"][0]["error"]
        choose(command)
        completed = session.wait(lambda state: any(item.get("phase") == "completed" for item in state.get("sessions", [])), "recovery-completed")
        assert not completed["sessions"][0]["error"]
        session.wait(lambda state: state.get("mode") == "wf-run-mode", "recovery-completed-view")
        session.send("r")
        session.wait(lambda state: state.get("buffer", "").startswith("*wf verified result"), "recovery-verified-result")
        success = True
    finally:
        session.close(success)


def seed_history(runner: str, directory: Path) -> Path:
    directory.mkdir()
    state = directory / "state"
    process = subprocess.Popen([runner, "frontend"], cwd=directory, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        request = {"version": 1, "operation": "prepare", "workflow": "hello-world", "stateDirectory": str(state),
                   "targetArguments": ["--scripted"], "inputs": [{"name": "language", "source": "literal", "value": "Spanish"}]}
        process.stdin.write(json.dumps(request).encode() + b"\n")
        process.stdin.flush()
        prepared = json.loads(process.stdout.readline())
        process.stdin.write(json.dumps({"version": 1, "operation": "start", "approvalId": prepared["approvalId"]}).encode() + b"\n")
        process.stdin.flush()
        frames = [json.loads(line) for line in process.stdout]
        assert process.wait(timeout=20) == 0, process.stderr.read()
        assert frames[-1]["event"]["type"] == "run.completed"
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        process.stdin.close()
        process.stdout.close()
        process.stderr.close()
    return state


def history_case(args, directory: Path) -> None:
    store = seed_history(args.wf, directory.parent / "history-seed")
    body = f'''
(setq wf-program {string(args.wf)} wf-state-directory {string(str(store))}
      default-directory {string(str(directory) + '/')})
(wf-history)
'''
    session = Emacs(args.emacs, args.source, directory, 80, 24, body)
    success = False
    try:
        session.wait(lambda state: state.get("mode") == "wf-history-mode", "history-ready")
        session.resize(40, 12)
        session.send("g\r")
        session.wait(lambda state: state.get("mode") == "wf-observer-mode", "observer-ready")
        assert "OBSERVER ONLY" in session.state["text"]
        assert "Recorded answer:" in session.state["text"]
        session.resize(140, 36)
        session.send("r")
        session.wait(lambda state: state.get("buffer", "").startswith("*wf verified result"), "observed-result")
        assert session.state["text"] == "¡Hola, mundo!"
        session.command("wf-history")
        session.wait(lambda state: state.get("mode") == "wf-history-mode", "history-reopened")
        session.send("\r")
        session.wait(lambda state: state.get("mode") == "wf-observer-mode", "observer-reopened")
        session.send("F")
        session.wait(lambda state: state.get("buffer", "").startswith("*wf fork edits"), "fork-editor")
        session.send(b"\x03\x03")
        session.wait(lambda state: "Prepare immutable fork" in state.get("minibuffer", ""), "fork-confirmation")
        session.send("no\r")
        session.send(b"\x03\x0b")
        assert len(list((store / "runs").iterdir())) == 1
        success = True
    finally:
        session.close(success)


def multiwindow_case(args, directory: Path) -> None:
    body = f'''
(setq wf-program {string(args.control_runner)} wf-state-directory {string(str(directory / 'runs'))}
      default-directory {string(str(directory) + '/')})
(defvar wf-ui-session (wf--prepare '((name . "person-controlled"))
                        '(((name . "input") (source . "literal") (value . "window fixture")))
                        '("--scripted") default-directory))
(while (eq (wf--session-phase wf-ui-session) 'preparing)
  (accept-process-output (wf--session-process wf-ui-session) 0.05))
(unless (eq (wf--session-phase wf-ui-session) 'prepared) (error "Window fixture preparation failed"))
(setf (wf--session-phase wf-ui-session) 'running)
(wf--send wf-ui-session `((version . 1) (operation . "start")
                         (approvalId . ,(alist-get 'approvalId (wf--session-prepared wf-ui-session)))))
(wf--view wf-ui-session)
(defun wf-ui-answer ()
  (interactive)
  (let ((id (car (wf--session-pending wf-ui-session))))
    (wf--control-send wf-ui-session `((type . "answerPerson") (answer . ,(if (equal id "0") :false t))) id)))
(global-set-key (kbd "C-c a") #'wf-ui-answer)
'''
    session = Emacs(args.emacs, args.source, directory, 140, 36, body)
    success = False
    try:
        session.wait(lambda state: any(item.get("pending") == ["0"] for item in state.get("sessions", [])), "window-first-pending")
        session.send(b"\x18\x31\x18\x32\x1b<\x18o\x1b>\x18o")
        def positions(state):
            windows = [window for window in state.get("windows", []) if window["buffer"].startswith("*wf run ")]
            return len(windows) == 2 and any(window["point"] == 1 for window in windows) and any(window["point"] == window["maximum"] for window in windows)
        session.wait(positions, "two-window-positions")
        session.send(b"\x03a")
        session.wait(lambda state: any(item.get("pending") == ["1"] for item in state.get("sessions", [])), "window-second-pending")
        assert positions(session.state), session.state["windows"]
        session.send(b"\x03a")
        session.wait(lambda state: any(item.get("phase") == "completed" for item in state.get("sessions", [])), "window-completed")
        assert positions(session.state), session.state["windows"]
        success = True
    finally:
        session.close(success)


# The literal of the service journey. The service modes of agent-cat
# manager/test/service_http.py state the same literal.
SERVICE_LITERAL = "Emacs service λ: Café ✓ 雪 exact literal"
# The version of the report of the service journey. The service modes of
# agent-cat require the same version.
SERVICE_REPORT_VERSION = 1
SERVICE_SIZES = [(40, 12), (140, 36), (80, 24)]
# The seconds that a service case waits for Emacs -Q to load the service
# sources and write its first state. A busy host can take more than the 20
# seconds of an ordinary wait.
SERVICE_READY_SECONDS = 60


def service_body(profile: Path, directory: Path) -> str:
    """Return the Lisp body of a service case for the client profile PROFILE.

    It sets the profile and the coding systems and defines `wf-ui-extra',
    whose report states service mode, the runs that the session knows,
    the review buffers, the run views with their lines, head and control
    choices, and the service history buffer with its run identifiers. The
    report also states each listing of the control prompt, with the label
    and the description of each choice in the order of the prompt, and
    each command that the session sent, with its resource, its If-Match
    and its JSON body. A command that `wf-service--control-act' sends
    also states the entity tag of the latest read of its resource in that
    act: the read of the controls that the act received, or a later read
    of the act. Another command states false there, and a capture body is
    stated as false."""
    return f"""
(set-keyboard-coding-system 'utf-8-unix)
(set-terminal-coding-system 'utf-8-unix)
(setq wf-manager-profiles (list {string(str(profile))})
      suggest-key-bindings nil
      extended-command-suggest-shorter nil
      default-directory {string(str(directory) + '/')})
(defvar wf-ui-listed nil)
(defvar wf-ui-sent nil)
(defvar wf-ui-act-tags nil)
(advice-add 'completing-read :before
            (lambda (prompt collection &rest _)
              (when (and (string-prefix-p "Control of run " prompt) (consp collection))
                (push `((prompt . ,prompt)
                        (choices . ,(vconcat (mapcar (lambda (choice)
                                                       `((label . ,(car choice)) (description . ,(cadr choice))))
                                                     collection))))
                      wf-ui-listed))))
(advice-add 'wf-service--control-act :around
            (lambda (act session run action reply)
              (let ((wf-ui-act-tags (list (cons (concat "/v1/runs/" run "/control")
                                                (wf-manager-reply-etag reply)))))
                (funcall act session run action reply))))
(advice-add 'wf-service--read :around
            (lambda (read session uri)
              (let ((reply (funcall read session uri)))
                (when wf-ui-act-tags
                  (push (cons uri (wf-manager-reply-etag reply)) wf-ui-act-tags))
                reply)))
(advice-add 'wf-manager-session-send :before
            (lambda (_session command _callback)
              (let ((uri (wf-manager-reference-uri (wf-manager-pending-reference command))))
                (push `((resource . ,uri)
                        (ifMatch . ,(or (wf-manager-pending-if-match command) :false))
                        (readEtag . ,(or (cdr (assoc uri wf-ui-act-tags)) :false))
                        (body . ,(if (wf-manager-pending-media command)
                                     :false
                                   (decode-coding-string (wf-manager-pending-bytes command) 'utf-8))))
                      wf-ui-sent))))
(defun wf-ui-extra ()
  (let ((reviews nil) (views nil) (histories nil))
    (dolist (buffer (buffer-list))
      (let ((review (buffer-local-value 'wf-service--review-state buffer)))
        (when review
          (push `((buffer . ,(buffer-name buffer))
                  (run . ,(wf-service--review-run review))
                  (preparation . ,(wf-manager-preparation-id (wf-service--review-preparation review)))
                  (request . ,(wf-manager-preparation-request-id (wf-service--review-preparation review))))
                reviews))))
    (maphash
     (lambda (_key buffer)
       (when (buffer-live-p buffer)
         (let ((view (buffer-local-value 'wf-service--view-state buffer)))
           (when view
             (let ((head (cl-find-if
                          (lambda (decision)
                            (and (= (wf-manager-decision-position decision) 0)
                                 (equal (wf-manager-decision-state decision) "pending")))
                          (append (alist-get 'queue (wf-service--view-kept view)) nil))))
               (push `((buffer . ,(buffer-name buffer))
                       (run . ,(wf-service--view-run view))
                       (lines . ,(vconcat (wf-service-view-lines view)))
                       (head . ,(and head (wf-manager-decision-id head)))
                       (kind . ,(and head (if (wf-manager-question-p (wf-manager-decision-content head))
                                              "question" "recovery")))
                       (choices . ,(let ((control (alist-get 'control (wf-service--view-kept view))))
                                     (vconcat
                                      (and control
                                           (mapcar (lambda (choice)
                                                     `((label . ,(car choice)) (description . ,(cadr choice))))
                                                   (wf-service-control-choices
                                                    (wf-service--view-run view) control nil nil)))))))
                     views))))))
     wf-service--views)
    (dolist (buffer (buffer-list))
      (let ((history (buffer-local-value 'wf-service--history-state buffer)))
        (when history
          (setq histories
                (cons `((buffer . ,(buffer-name buffer))
                        (pages . ,(wf-service--history-pages history))
                        (runs . ,(vconcat (mapcar #'wf-manager-run-id (wf-service--history-runs history)))))
                      histories)))))
    `((service . ,(if wf-service--current t :false))
      (problem . ,(and wf-service--current (wf-service--state-problem wf-service--current)))
      (runs . ,(vconcat (and wf-service--current
                             (wf-service--service-runs (wf-service--state-session wf-service--current)))))
      (reviews . ,(vconcat reviews))
      (views . ,(vconcat views))
      (histories . ,(vconcat histories))
      (listed . ,(vconcat (reverse wf-ui-listed)))
      (sent . ,(vconcat (reverse wf-ui-sent))))))
"""


def service_extra(state: dict) -> dict:
    """The value of `wf-ui-extra' in the state report, or an empty one."""
    return state.get("extra") or {}


def service_said(text: str, since: int):
    """A predicate: the messages after the offset since hold text."""
    return lambda state: text in state.get("messages", "")[max(0, since - 300):]


def service_view(state: dict, run: str) -> dict | None:
    """The report of the run view of run, or None."""
    return next((view for view in service_extra(state).get("views", []) if view["run"] == run), None)


def service_terminal(view: dict) -> bool:
    """True when the lines of the view name a terminal status."""
    return any(line.startswith("Terminal: ") and not line.startswith("Terminal: not yet") for line in view["lines"])


def service_resized(session: Emacs, label: str, kept) -> list:
    """Resize through SERVICE_SIZES and give the text that each size kept."""
    texts = []
    for width, height in SERVICE_SIZES:
        session.resize(width, height)
        texts.append({"size": f"{width}x{height}",
                      "text": session.wait(kept, f"{label}-{width}x{height}")["text"]})
    return texts


def service_open_view(session: Emacs, run: str, label: str) -> dict:
    """Open the view of run with M-x wf-runs and wait until it is selected.

    The choices of wf-runs are the open views and the runs of the
    installed overview, which the session follows by polling."""
    session.wait(lambda state: run in service_extra(state).get("runs", []), label + "-run-known", 60)
    session.command("wf-runs")
    session.wait(lambda state: "Run:" in state.get("minibuffer", ""), label + "-run-prompt")
    session.send("service:" + run + "\r")
    return session.wait(lambda state: state.get("mode") == "wf-service-run-mode" and service_view(state, run) is not None
                        and state.get("buffer") == service_view(state, run)["buffer"], label + "-view")


def service_case(args, directory: Path) -> None:
    """Drive the service journey of wf-service.el by keys at 80x24.

    The keys select the client profile with wf-service, create a
    mixed-controls request with wf-run, type SERVICE_LITERAL in the setup
    form, submit it, approve the exact review, open the run view with
    wf-runs, answer the question with the typed answer, send the offered
    retry, wait for terminal success and save the verified result. The
    setup form, the review and the answer editor each pass through
    40x12, 140x36 and 80x24 with their text kept. The report records the
    facts of each step and is written again after each step."""
    profile, report_path = Path(args.service[0]).resolve(), Path(args.service[1]).resolve()
    answer = args.service_answer
    emacs_directory = args.source.resolve().parent
    sources = [emacs_directory / name for name in ("wf.el", "wf-manager.el", "wf-service.el")]
    saved = directory / "saved-result.bin"
    report: dict = {"version": SERVICE_REPORT_VERSION, "literal": SERVICE_LITERAL, "answer": answer,
                    "profile": str(profile), "steps": []}

    def record(step: str, line: str, **facts) -> None:
        report["steps"].append(step)
        report.update(facts)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print("PASS emacs-service keys " + step + ": " + line, flush=True)

    body = service_body(profile, directory)
    session = Emacs(args.emacs, sources, directory, 80, 24, body)
    success = False

    try:
        session.wait(lambda state: state.get("extra") is not None, "service-ready", SERVICE_READY_SECONDS)
        # The profile.
        session.command("wf-service")
        session.wait(lambda state: "Client profile" in state.get("minibuffer", ""), "profile-file-prompt")
        session.send("\r")
        session.wait(lambda state: service_extra(state).get("service") is True
                     and "wf: service mode, endpoint" in state.get("messages", ""), "service-bound", 60)
        record("1", "M-x wf-service selected the client profile " + str(profile))
        # The catalogue and the setup form.
        session.command("wf-run")
        session.wait(lambda state: "Profile" in state.get("minibuffer", ""), "manager-profile-prompt", 60)
        session.send("\r")
        session.wait(lambda state: "Workflow:" in state.get("minibuffer", ""), "workflow-prompt", 60)
        session.send("mixed-controls\r")
        session.wait(lambda state: state.get("mode") == "wf--setup-mode", "setup-form", 60)
        first, second = SERVICE_LITERAL[:17], SERVICE_LITERAL[17:]
        session.send(first)
        session.wait(lambda state: first in state.get("text", ""), "setup-first-half")
        session.resize(*SERVICE_SIZES[0])
        session.wait(lambda state: first in state.get("text", ""), "setup-first-half-40x12")
        session.send(second)
        setup = service_resized(session, "setup", lambda state: state.get("mode") == "wf--setup-mode" and SERVICE_LITERAL in state.get("text", ""))
        record("2", "wf-run chose mixed-controls, and the setup form kept the typed literal at 40x12, 140x36 and 80x24",
               setupTexts=setup)
        # The exact review.
        session.send(b"\x03\x03")
        review = session.wait(lambda state: state.get("mode") == "wf-service-review-mode" and service_extra(state).get("reviews"),
                              "review", 150)
        text = review["text"]
        reviewed = service_resized(session, "review", lambda state: state.get("mode") == "wf-service-review-mode" and state.get("text") == text)
        record("3", "C-c C-c submitted the form, and the exact review stayed the same at 40x12, 140x36 and 80x24",
               reviewText=text, reviewTexts=reviewed, reviewPreparation=service_extra(review)["reviews"][0]["preparation"],
               reviewRequest=service_extra(review)["reviews"][0]["request"])
        session.send("a")
        prompt = session.wait(lambda state: state.get("minibuffer", "").startswith("Start "), "approve-prompt")["minibuffer"]
        session.send("yes\r")
        approved = session.wait(lambda state: any(item.get("run") for item in service_extra(state).get("reviews", [])), "approved", 150)
        run = next(item["run"] for item in service_extra(approved)["reviews"] if item.get("run"))
        record("4", "a and yes approved the review, and the manager started run " + run, approvePrompt=prompt, run=run)
        # The run view and its heads, in the order that the manager presents them.
        service_open_view(session, run, "first")
        record("5", "M-x wf-runs opened the view of run " + run)
        handled: list = []
        heads: list = []
        while len(handled) < 2:
            state = session.wait(lambda state: service_view(state, run) is not None and (
                service_view(state, run)["kind"] not in (None, *handled) or service_terminal(service_view(state, run))), f"head-{len(handled)}", 180)
            view = service_view(state, run)
            assert view["kind"] not in (None, *handled), ("the run ended before its heads", handled, view["lines"])
            head, kind = view["head"], view["kind"]
            if state.get("buffer") != view["buffer"] or state.get("mode") != "wf-service-run-mode":
                service_open_view(session, run, "head-" + head)
            since = len(session.state.get("messages", ""))
            if kind == "question":
                session.send("a")
                session.wait(lambda state: state.get("buffer", "").startswith("*wf answer JSON"), "answer-editor", 60)
                session.send(answer[:2])
                session.wait(lambda state: state.get("text") == answer[:2], "answer-first")
                session.resize(*SERVICE_SIZES[0])
                session.wait(lambda state: state.get("text") == answer[:2], "answer-first-40x12")
                session.send(answer[2:])
                answered = service_resized(session, "answer", lambda state: state.get("buffer", "").startswith("*wf answer JSON")
                                   and state.get("text") == answer)
                session.send(b"\x03\x03")
                session.wait(service_said("reached decision " + head, since), "answered", 90)
                report.update(answerTexts=answered, question=head)
                line = "the typed answer " + answer + " reached question " + head
            else:
                session.send("c")
                session.wait(lambda state: "Control of run " + run in state.get("minibuffer", ""), "control-prompt", 60)
                session.send("retry\r")
                session.wait(service_said("retry reached decision " + head, since), "retried", 90)
                report.update(recovery=head)
                line = "the offered retry reached recovery decision " + head
            handled.append(kind)
            heads.append(head)
            record("6" + "ab"[len(handled) - 1], line, heads=heads, kinds=handled)
        # Terminal success and the verified result.
        final = session.wait(lambda state: service_view(state, run) is not None
                             and "Terminal: succeeded" in service_view(state, run)["lines"]
                             and any(line.startswith("Result SHA-256: ") for line in service_view(state, run)["lines"]),
                             "succeeded", 180)
        record("7", "the view of run " + run + " showed terminal success and the verified result",
               finalLines=service_view(final, run)["lines"])
        state = service_open_view(session, run, "result")
        since = len(state.get("messages", ""))
        session.send("r")
        session.wait(lambda state: "Save the verified result of run " + run in state.get("minibuffer", ""), "result-prompt", 60)
        session.send(b"\x01\x0b" + str(saved).encode())
        session.wait(lambda state: state.get("minibuffer", "").endswith(str(saved)), "result-path")
        session.send("\r")
        session.wait(lambda state: saved.exists() and service_said("saved the verified", since)(state), "saved", 60)
        record("8", "r saved the verified result of run " + run + " to " + str(saved), savedPath=str(saved))
        # Local mode, then the exit of Emacs.
        session.command("wf-local")
        session.wait(lambda state: service_extra(state).get("service") is False, "local")
        success = True
    finally:
        session.close(success)
    record("9", "M-x wf-local closed the session, and C-x C-c ended Emacs with status 0 and the terminal attributes restored",
           terminalBefore=session.before, terminalAfter=session.ended["attributes"], exitStatus=session.ended["status"])


# The facts of the service lifecycle. The emacs-service-lifecycle mode of
# agent-cat manager/test/service_http.py states the same values.
LIFECYCLE_REPORT_VERSION = 3
LIFECYCLE_FIRST = "Emacs lifecycle λ: first delayed run"
LIFECYCLE_SECOND = "Emacs lifecycle λ: second delayed run"
LIFECYCLE_CAPTURE = "Emacs capture λ ✓\nsecond line 雪\n"
LIFECYCLE_STEER = "Emacs lifecycle steer λ: focus on the patch."
LIFECYCLE_ANSWER = "false"
# The fork child of the first run replaces the answer of its person
# question, occurrence LIFECYCLE_FORK_OCCURRENCE, with the typed text
# LIFECYCLE_FORKED. The export of the fork child has the name
# LIFECYCLE_EXPORT. LIFECYCLE_PENDING is the literal of the run that waits
# at its question when Emacs quits.
LIFECYCLE_FORK_OCCURRENCE = "1"
LIFECYCLE_FORKED = "yes"
LIFECYCLE_EXPORT = "emacs-lifecycle-export.json"
LIFECYCLE_PENDING = "Emacs lifecycle λ: pending at the quit"


def service_review(state: dict) -> dict | None:
    """The report of the review buffer that the selected window shows, or None."""
    return next((review for review in service_extra(state).get("reviews", [])
                 if review["buffer"] == state.get("buffer")), None)


def service_create(session: Emacs, profile: str, workflow: str, label: str, typed: str | None = None,
                   capture: str | None = None) -> dict:
    """Create, review and approve one request by keys and return its facts.

    M-x wf-run chooses profile and workflow. The setup form types the
    literal typed, or it selects the Buffer source with the keys of its
    menu and captures the buffer named capture. The typed literal replaces
    the default of the field, the latest value of its input history.
    C-c C-c submits the form,
    and a and yes approve the exact review."""
    session.command("wf-run")
    session.wait(lambda state: "Profile" in state.get("minibuffer", ""), label + "-profile-prompt", 60)
    session.send(profile + "\r")
    session.wait(lambda state: "Workflow:" in state.get("minibuffer", ""), label + "-workflow-prompt", 60)
    session.send(workflow + "\r")
    session.wait(lambda state: state.get("mode") == "wf--setup-mode", label + "-setup", 60)
    if capture is None:
        # The latest value of the input history is the default of the
        # field, so C-k first clears the field from its start.
        session.send(b"\x0b" + typed.encode())
        form = session.wait(lambda state: typed in state.get("text", ""), label + "-typed")
    else:
        # Backtab twice reaches the Source menu from the value field, RET
        # opens its choices, and 3 is the Buffer choice.
        session.send(b"\x1b[Z\x1b[Z\r")
        session.wait(lambda state: any(window["buffer"] == " widget-choose" for window in state.get("windows", [])),
                     label + "-source-choices")
        session.send("3")
        session.wait(lambda state: "Capture text from buffer" in state.get("minibuffer", ""), label + "-capture-prompt")
        session.send(capture + "\r")
        form = session.wait(lambda state: state.get("mode") == "wf--setup-mode"
                            and LIFECYCLE_CAPTURE in state.get("text", ""), label + "-captured")
    known = {item["request"] for item in service_extra(form).get("reviews", [])}
    session.send(b"\x03\x03")
    return {**service_approve(session, label, known), "formText": form["text"]}


def service_approve(session: Emacs, label: str, known: set) -> dict:
    """Approve the exact review of a new request by keys and return its facts.

    The review of the new request is the review buffer of a request that
    no review buffer in known named. a and yes approve it. The facts are
    the run, the request, the preparation, the approval prompt and the
    text of the review."""
    review = session.wait(lambda state: state.get("mode") == "wf-service-review-mode" and service_review(state) is not None
                          and service_review(state)["request"] not in known, label + "-review", 150)
    request = service_review(review)["request"]
    session.send("a")
    prompt = session.wait(lambda state: state.get("minibuffer", "").startswith("Start "), label + "-approve-prompt")["minibuffer"]
    session.send("yes\r")
    approved = session.wait(lambda state: any(item["request"] == request and item.get("run")
                                              for item in service_extra(state).get("reviews", [])), label + "-approved", 150)
    run = next(item["run"] for item in service_extra(approved)["reviews"] if item["request"] == request)
    return {"run": run, "request": request, "preparation": service_review(review)["preparation"],
            "approvePrompt": prompt, "reviewText": review["text"]}


def service_lineage(session: Emacs, parent: str, operation: str, label: str) -> dict:
    """Create one lineage child of run parent by keys and approve its review.

    The keys act in the view of parent. R makes a restart child. F makes a
    fork child: the edits prompt selects occurrence
    LIFECYCLE_FORK_OCCURRENCE and the action replace, the typed
    LIFECYCLE_FORKED replaces the published answer that the replacement
    minibuffer starts with, and send sends the fork. The facts are those of
    service_approve, and a fork adds the text that the replacement
    minibuffer started with."""
    state = service_open_view(session, parent, label + "-parent")
    known = {item["request"] for item in service_extra(state).get("reviews", [])}
    if operation == "restart":
        session.send("R")
        return service_approve(session, label, known)
    edits = "Fork edits of run " + parent + ": "
    session.send("F")
    session.wait(lambda state: state.get("minibuffer", "").startswith(edits), label + "-edits", 60)
    session.send("occurrence:" + LIFECYCLE_FORK_OCCURRENCE + "\r")
    session.wait(lambda state: state.get("minibuffer", "").startswith(
        "Answer of occurrence " + LIFECYCLE_FORK_OCCURRENCE + " of run " + parent + ": "), label + "-action")
    session.send("replace\r")
    replacement = "Replacement answer of occurrence " + LIFECYCLE_FORK_OCCURRENCE + " (flag) of run " + parent + ": "
    prefill = session.wait(lambda state: state.get("minibuffer", "").startswith(replacement), label + "-replacement")["minibuffer"]
    # C-a and C-k clear the published answer from the start of the input.
    session.send(b"\x01\x0b" + LIFECYCLE_FORKED.encode())
    session.wait(lambda state: state.get("minibuffer", "") == replacement + LIFECYCLE_FORKED, label + "-replaced")
    session.send("\r")
    session.wait(lambda state: state.get("minibuffer", "").startswith(edits), label + "-edited")
    session.send("send\r")
    return {**service_approve(session, label, known), "forkPrefill": prefill[len(replacement):]}


def service_handshake(session: Emacs, directory: Path, name: str, facts: dict, timeout: float = 120) -> dict:
    """Ask the harness for the action name and wait until the harness did it.

    The request is the file name.json in directory, with facts, and the
    harness answers with the JSON file name.done after the action. Each
    file appears complete, by a rename. The output of Emacs is drained
    meanwhile, and no key is sent. Return the answer of the harness."""
    staged = directory / (name + ".json.new")
    staged.write_text(json.dumps(facts, ensure_ascii=False))
    staged.rename(directory / (name + ".json"))
    done = directory / (name + ".done")
    deadline = time.monotonic() + timeout
    while not done.exists():
        if time.monotonic() >= deadline or session.process.poll() is not None:
            raise AssertionError(("the harness did not answer the handshake", name, session.process.poll()))
        session.drain()
    return json.loads(done.read_text())


def service_history_open(session: Emacs, run: str, label: str) -> dict:
    """Open the view of run from its row of the selected service history.

    M-x re-search-forward with the anchor ^ moves the point to the row
    that starts with run, and RET opens its view. The row of a fork names
    its parent in its lineage column, and the order of the history rows
    is the order of /v1/runs, so a plain search can stop on the row of a
    fork of run. Return the state once the view is selected."""
    session.command("re-search-forward")
    session.wait(lambda state: "RE search:" in state.get("minibuffer", ""), label + "-search-prompt")
    session.send("^" + run + "\r")
    session.send("\r")
    return session.wait(lambda state: state.get("mode") == "wf-service-run-mode" and service_view(state, run) is not None
                        and state.get("buffer") == service_view(state, run)["buffer"], label + "-opened", 60)


def service_windows(state: dict, runs: list) -> list:
    """The window of each view of runs in the state, in the order of runs.

    Each item holds the buffer, the point and the maximum of the window,
    or None when no window shows the view."""
    views = [service_view(state, run) for run in runs]
    return [next(({"buffer": window["buffer"], "point": window["point"], "maximum": window["maximum"]}
                  for window in state.get("windows", []) if view and window["buffer"] == view["buffer"]), None)
            for view in views]


def service_lifecycle_case(args, directory: Path) -> None:
    """Drive the service lifecycle of wf-service.el by keys at three sizes.

    At 140x36, delayed-person runs of profile_1 and profile_2 are created
    and approved, and each is followed in its own window: the window of the
    first run keeps its point at the start, and the window of the second
    run keeps its point at the end. The delayed question of the first run
    is answered in its window while the second run runs. At 80x24, a
    captured-input request of profile_steer captures the text of an editor
    buffer through the Buffer source, the second run is cancelled after
    the confirmation yes, and the offered steer of the captured run is
    sent through its editor. The open control prompt with the typed label
    of the steer choice and the steer editor with the typed text each pass
    through 40x12, 140x36 and 80x24 with their text kept. At 40x12, M-x
    wf-history lists every page of the runs, the first run is opened from
    its row and r saves its verified result. At 80x24, F makes a fork child of the first run and R
    a restart child of the second run, each approved after its exact
    review, and E exports the verified result of the fork child. The
    manager then stops and starts again while the view of the restart
    child is open at its question, and the view reports the lost delivery
    and reconnects with no key. A third run is created and approved, and
    C-x C-c quits Emacs while that run waits at its question. A new Emacs
    with the same profile opens the view of that run, C-x k kills the view,
    M-x wf-local closes the session and C-x C-c ends Emacs. The harness
    stops and starts the manager, and it records the commands of the
    manager before the quit and before the kill, through the handshakes
    of service_handshake in the directory of --service-handshake. The
    report records the facts of each step and is written again after each
    step."""
    profile, report_path = Path(args.service[0]).resolve(), Path(args.service[1]).resolve()
    handshake = args.service_handshake.resolve()
    emacs_directory = args.source.resolve().parent
    sources = [emacs_directory / name for name in ("wf.el", "wf-manager.el", "wf-service.el")]
    saved = directory / "saved-result.bin"
    report: dict = {"version": LIFECYCLE_REPORT_VERSION, "first": LIFECYCLE_FIRST, "second": LIFECYCLE_SECOND,
                    "capture": LIFECYCLE_CAPTURE, "steer": LIFECYCLE_STEER, "answer": LIFECYCLE_ANSWER,
                    "forked": LIFECYCLE_FORKED, "forkOccurrence": LIFECYCLE_FORK_OCCURRENCE, "export": LIFECYCLE_EXPORT,
                    "pending": LIFECYCLE_PENDING, "profile": str(profile), "steps": []}

    def record(step: str, line: str, **facts) -> None:
        report["steps"].append(step)
        report.update(facts)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print("PASS emacs-service-lifecycle keys " + step + ": " + line, flush=True)

    session = Emacs(args.emacs, sources, directory, 140, 36, service_body(profile, directory))
    success = False
    try:
        session.wait(lambda state: state.get("extra") is not None, "service-ready", SERVICE_READY_SECONDS)
        session.command("wf-service")
        session.wait(lambda state: "Client profile" in state.get("minibuffer", ""), "profile-file-prompt")
        session.send("\r")
        session.wait(lambda state: service_extra(state).get("service") is True
                     and "wf: service mode, endpoint" in state.get("messages", ""), "service-bound", 60)
        record("1", "M-x wf-service selected the client profile " + str(profile) + " at 140x36")

        # 140x36: two runs, each in its own window.
        first = service_create(session, "profile_1", "delayed-person", "first", typed=LIFECYCLE_FIRST)
        record("2", "wf-run created, reviewed and approved request " + first["request"] + ", and the manager started run "
               + first["run"], firstRun=first)
        second = service_create(session, "profile_2", "delayed-person", "second", typed=LIFECYCLE_SECOND)
        record("3", "wf-run created, reviewed and approved request " + second["request"] + ", and the manager started run "
               + second["run"], secondRun=second)
        runs = [first["run"], second["run"]]
        # The view of the second run fills the frame and C-x 2 shows it in
        # two windows. M-x wf-runs in the upper window then shows the view of
        # the first run in the other window, which it selects.
        service_open_view(session, second["run"], "second")
        session.send(b"\x181\x182")
        session.wait(lambda state: [window["buffer"] for window in state.get("windows", [])]
                     == [service_view(state, second["run"])["buffer"]] * 2, "second-twice")
        service_open_view(session, first["run"], "first")
        session.send(b"\x1b<\x18o\x1b>\x18o")

        def independent(state: dict) -> bool:
            windows = service_windows(state, runs)
            return (len(state.get("windows", [])) == 2 and None not in windows
                    and windows[0]["point"] == 1 and windows[1]["point"] == windows[1]["maximum"] > 1
                    and state.get("buffer") == windows[0]["buffer"])

        split = session.wait(independent, "windows-split")
        record("4", "the views of runs " + " and ".join(runs) + " each fill their own window at 140x36, with the point of the "
               "first at its start and the point of the second at its end", splitWindows=service_windows(split, runs),
               splitHeads=[service_view(split, run)["head"] for run in runs],
               splitLines=[service_view(split, run)["lines"] for run in runs])
        asked = session.wait(lambda state: independent(state) and service_view(state, first["run"])["kind"] == "question",
                             "first-question", 180)
        question = service_view(asked, first["run"])["head"]
        record("5", "the delayed question " + question + " of run " + first["run"] + " arrived, and both windows kept their points",
               question=question, askedWindows=service_windows(asked, runs),
               askedLines=[service_view(asked, run)["lines"] for run in runs])
        # The answer editor opens below the window of the first run, so the
        # window of the second run keeps its view.
        since = len(asked.get("messages", ""))
        session.send("a")
        editor = session.wait(lambda state: state.get("buffer", "").startswith("*wf answer JSON"), "answer-editor", 60)
        assert len(editor["windows"]) == 3 and service_windows(editor, runs)[1] is not None, editor["windows"]
        session.send(LIFECYCLE_ANSWER)
        session.wait(lambda state: state.get("text") == LIFECYCLE_ANSWER, "answer-typed")
        session.send(b"\x03\x03")
        session.wait(service_said("reached decision " + question, since), "answered", 90)
        both = session.wait(lambda state: independent(state)
                            and "Terminal: succeeded" in service_view(state, first["run"])["lines"]
                            and any(line.startswith("Result SHA-256: ") for line in service_view(state, first["run"])["lines"])
                            and service_view(state, second["run"])["kind"] == "question"
                            and not service_terminal(service_view(state, second["run"])), "first-succeeded", 180)
        record("6", "a and " + LIFECYCLE_ANSWER + " answered question " + question + " in the window of run " + first["run"]
               + ", which succeeded while run " + second["run"] + " ran on to its own delayed question, and both windows kept their points",
               answeredWindows=service_windows(both, runs), answeredLines=[service_view(both, run)["lines"] for run in runs],
               editorWindows=len(editor["windows"]))

        # 80x24: a captured input, a cancel and a steer.
        session.resize(80, 24)
        session.send(b"\x181\x18bwf-capture\r")
        session.wait(lambda state: state.get("buffer") == "wf-capture", "capture-buffer")
        session.send(LIFECYCLE_CAPTURE.replace("\n", "\r"))
        session.wait(lambda state: state.get("buffer") == "wf-capture" and state.get("text") == LIFECYCLE_CAPTURE, "capture-typed")
        captured = service_create(session, "profile_steer", "captured-input", "captured", capture="wf-capture")
        record("7", "the Buffer source of the setup form captured the editor buffer wf-capture for request " + captured["request"]
               + ", and the manager started run " + captured["run"] + " at 80x24", capturedRun=captured)
        state = service_open_view(session, second["run"], "cancel")
        since = len(state.get("messages", ""))
        session.send(b"\x03\x0b")
        prompt = session.wait(lambda state: "Cancel run " + second["run"] in state.get("minibuffer", ""), "cancel-prompt", 60)["minibuffer"]
        session.send("yes\r")
        session.wait(service_said("the runtime accepted the cancel of run " + second["run"], since), "cancel-accepted", 90)
        cancelled = session.wait(lambda state: "Terminal: cancelled" in service_view(state, second["run"])["lines"], "cancelled", 120)
        record("8", "C-c C-k and the confirmation yes cancelled run " + second["run"], cancelPrompt=prompt,
               cancelledLines=service_view(cancelled, second["run"])["lines"])
        offered = service_open_view(session, captured["run"], "steer")
        offered = session.wait(lambda state: any(choice["description"].endswith(", interrupt-now")
                                                 for choice in service_view(state, captured["run"])["choices"]), "steer-offered", 120)
        choice = next(choice for choice in service_view(offered, captured["run"])["choices"]
                      if choice["description"].startswith("steer ") and choice["description"].endswith(", interrupt-now"))
        since = len(offered.get("messages", ""))
        session.send("c")
        control = "Control of run " + captured["run"] + ": "
        session.wait(lambda state: control in state.get("minibuffer", ""), "control-prompt", 60)
        # The open control prompt and the steer editor each pass through
        # SERVICE_SIZES with their typed text kept. The steer editor is
        # resized back to 80x24 before C-c C-c.
        session.send(choice["label"])
        prompted = []
        for width, height in SERVICE_SIZES:
            session.resize(width, height)
            prompted.append({"size": f"{width}x{height}",
                             "text": session.wait(lambda state: state.get("minibuffer") == control + choice["label"],
                                                  f"control-prompt-{width}x{height}")["minibuffer"]})
        session.send("\r")
        session.wait(lambda state: state.get("buffer", "").startswith("*wf steer "), "steer-editor", 60)
        session.send(LIFECYCLE_STEER)
        session.wait(lambda state: state.get("text") == LIFECYCLE_STEER, "steer-typed")
        steering = service_resized(session, "steer", lambda state: state.get("buffer", "").startswith("*wf steer ")
                                   and state.get("text") == LIFECYCLE_STEER)
        session.send(b"\x03\x03")
        session.wait(service_said("wf: steer interrupt-now reached occurrence", since), "steered", 90)
        steered = session.wait(lambda state: "Terminal: succeeded" in service_view(state, captured["run"])["lines"], "steered-succeeded", 120)
        record("9", "c and " + choice["label"] + " opened the steer editor of run " + captured["run"]
               + ", the control prompt and the steer editor kept their typed text at 40x12, 140x36 and 80x24, C-c C-c"
               " sent the typed text with the timing interrupt-now, and the run succeeded",
               steerChoice=choice, controlPromptTexts=prompted, steerTexts=steering,
               steeredLines=service_view(steered, captured["run"])["lines"])

        # 40x12: the history over every page, an earlier run and its result.
        session.resize(40, 12)
        state = session.wait(lambda state: True, "small")
        since = len(state.get("messages", ""))
        session.send(b"\x181")
        session.command("wf-history")
        listed = session.wait(lambda state: state.get("mode") == "wf-service-history-mode"
                              and service_said("wf: history of ", since)(state), "history", 120)
        history = next(item for item in service_extra(listed)["histories"] if item["buffer"] == listed["buffer"])
        record("10", "M-x wf-history listed " + str(len(history["runs"])) + " runs over " + str(history["pages"]) + " pages at 40x12",
               historyRuns=history["runs"], historyPages=history["pages"])
        opened = service_history_open(session, first["run"], "history")
        record("11", "RET on the history row of run " + first["run"] + " opened its view",
               openedLines=service_view(opened, first["run"])["lines"])
        since = len(opened.get("messages", ""))
        session.send("r")
        session.wait(lambda state: "Save the verified result of run " + first["run"] in state.get("minibuffer", ""), "result-prompt", 60)
        session.send(b"\x01\x0b" + str(saved).encode())
        session.wait(lambda state: state.get("minibuffer", "").endswith(str(saved)), "result-path")
        session.send("\r")
        session.wait(lambda state: saved.exists() and service_said("saved the verified", since)(state), "saved", 60)
        record("12", "r saved the verified result of run " + first["run"] + " to " + str(saved), savedPath=str(saved))

        # 80x24: a fork child and a restart child, each approved after its
        # exact review, and the export of the result of the fork child.
        session.resize(80, 24)
        session.send(b"\x181")
        fork = service_lineage(session, first["run"], "fork", "fork")
        record("13", "F, the replacement " + LIFECYCLE_FORKED + " of occurrence " + LIFECYCLE_FORK_OCCURRENCE + " and send created "
               "the fork child request " + fork["request"] + " of run " + first["run"] + ", and a and yes approved its exact review, "
               "which started run " + fork["run"] + " at 80x24", forkRun=fork)
        restart = service_lineage(session, second["run"], "restart", "restart")
        record("14", "R created the restart child request " + restart["request"] + " of run " + second["run"] + ", and a and yes "
               "approved its exact review, which started run " + restart["run"], restartRun=restart)
        # The fork child can end before the overview names it, so its view
        # opens from its row of the history.
        since = len(session.state.get("messages", ""))
        session.command("wf-history")
        session.wait(lambda state: state.get("mode") == "wf-service-history-mode"
                     and service_said("wf: history of ", since)(state), "fork-history", 120)
        service_history_open(session, fork["run"], "fork-history")
        forked = session.wait(lambda state: "Terminal: succeeded" in service_view(state, fork["run"])["lines"]
                              and any(line.startswith("Result SHA-256: ") for line in service_view(state, fork["run"])["lines"]),
                              "fork-succeeded", 180)
        since = len(forked.get("messages", ""))
        session.send("E")
        session.wait(lambda state: "Export name for the verified result of run " + fork["run"] in state.get("minibuffer", ""),
                     "export-prompt", 60)
        session.send(LIFECYCLE_EXPORT + "\r")
        exported = session.wait(lambda state: state.get("buffer") == "*wf export " + fork["run"] + "/" + LIFECYCLE_EXPORT + "*"
                                and service_said("wf: Export " + LIFECYCLE_EXPORT + ": ", since)(state), "exported", 90)
        record("15", "E and the name " + LIFECYCLE_EXPORT + " exported the verified result of run " + fork["run"] + ", and the "
               "export buffer states the receipt, the verified download and the export collection",
               forkLines=service_view(forked, fork["run"])["lines"], exportText=exported["text"])

        # 80x24: the manager stops and starts again while the view of the
        # restart child is open at its question. No key is sent until the
        # view has reconnected.
        service_open_view(session, restart["run"], "held")
        held = session.wait(lambda state: service_view(state, restart["run"])["kind"] == "question"
                            and "Delivery: poll" in service_view(state, restart["run"])["lines"], "held-question", 180)
        held_question = service_view(held, restart["run"])["head"]
        stopped = service_handshake(session, handshake, "stop-manager", {"run": restart["run"], "question": held_question})
        lost = session.wait(lambda state: state.get("buffer") == service_view(state, restart["run"])["buffer"]
                            and "Delivery: unreachable" in service_view(state, restart["run"])["lines"], "delivery-lost", 60)
        record("16", "the manager stopped while the view of run " + restart["run"] + " waited at its question " + held_question
               + ", and the view reported the delivery unreachable with no key", heldQuestion=held_question,
               heldLines=service_view(held, restart["run"])["lines"], lostLines=service_view(lost, restart["run"])["lines"],
               stopped=stopped)
        started = service_handshake(session, handshake, "start-manager", {"run": restart["run"]})
        reconnected = session.wait(lambda state: state.get("buffer") == service_view(state, restart["run"])["buffer"]
                                   and "Delivery: poll" in service_view(state, restart["run"])["lines"]
                                   and "Supervision: lost" in service_view(state, restart["run"])["lines"], "reconnected", 120)
        record("17", "the manager started again, and with no key the view of run " + restart["run"] + " reconnected and showed "
               "the supervision lost of the restarted manager", reconnectedLines=service_view(reconnected, restart["run"])["lines"],
               started=started)

        # 80x24: Emacs quits while a new run waits at its question.
        pending = service_create(session, "profile_1", "delayed-person", "pending", typed=LIFECYCLE_PENDING)
        service_open_view(session, pending["run"], "pending")
        waiting = session.wait(lambda state: service_view(state, pending["run"])["kind"] == "question", "pending-question", 180)
        pending_question = service_view(waiting, pending["run"])["head"]
        record("18", "wf-run created, reviewed and approved request " + pending["request"] + ", and the view of run "
               + pending["run"] + " showed its question " + pending_question, pendingRun=pending,
               pendingQuestion=pending_question, pendingLines=service_view(waiting, pending["run"])["lines"])
        service_handshake(session, handshake, "quit", {"run": pending["run"], "question": pending_question})
        success = True
    finally:
        session.close(success)
    record("19", "C-x C-c quit Emacs while run " + pending["run"] + " waited at its question, with status 0 and the terminal "
           "attributes restored", terminalBefore=session.before, terminalAfter=session.ended["attributes"],
           exitStatus=session.ended["status"])

    # A new Emacs with the same profile finds the run at its question, and
    # the kill of its view sends nothing.
    later_directory = directory.parent / (directory.name + "-second")
    later = Emacs(args.emacs, sources, later_directory, 80, 24, service_body(profile, later_directory))
    success = False
    try:
        later.wait(lambda state: state.get("extra") is not None, "service-ready", SERVICE_READY_SECONDS)
        later.command("wf-service")
        later.wait(lambda state: "Client profile" in state.get("minibuffer", ""), "profile-file-prompt")
        later.send("\r")
        later.wait(lambda state: service_extra(state).get("service") is True
                   and "wf: service mode, endpoint" in state.get("messages", ""), "service-bound", 60)
        service_open_view(later, pending["run"], "found")
        found = later.wait(lambda state: service_view(state, pending["run"])["head"] == pending_question
                           and "Supervision: owned" in service_view(state, pending["run"])["lines"], "found-pending", 60)
        found_buffer = service_view(found, pending["run"])["buffer"]
        record("20", "in a new Emacs, M-x wf-service with the same profile and M-x wf-runs found run " + pending["run"]
               + " still at its question " + pending_question + " under the supervision owned",
               foundLines=service_view(found, pending["run"])["lines"])
        service_handshake(later, handshake, "kill-view", {"run": pending["run"]})
        later.send(b"\x18k")
        later.wait(lambda state: "Kill buffer" in state.get("minibuffer", "") and found_buffer in state.get("minibuffer", ""),
                   "kill-prompt")
        later.send("\r")
        later.wait(lambda state: service_view(state, pending["run"]) is None
                   and found_buffer not in [window["buffer"] for window in state.get("windows", [])], "view-killed")
        record("21", "C-x k and RET killed the view " + found_buffer + " of run " + pending["run"], killedBuffer=found_buffer)
        later.command("wf-local")
        later.wait(lambda state: service_extra(state).get("service") is False, "local")
        success = True
    finally:
        later.close(success)
    record("22", "M-x wf-local closed the session of the new Emacs, and C-x C-c ended it with status 0 and the terminal "
           "attributes restored", laterTerminalBefore=later.before, laterTerminalAfter=later.ended["attributes"],
           laterExitStatus=later.ended["status"])


# The version of the report of the service controls. The
# emacs-service-controls mode of agent-cat manager/test/service_http.py
# requires the same version.
CONTROLS_REPORT_VERSION = 1


def service_control_choose(session: Emacs, run: str, label: str, choose) -> dict:
    """Press c in the selected view of run, type a label and confirm it with RET.

    The control prompt lists the choices of `wf-control'. choose takes the
    choices of that listing, each with its label and description, and
    returns the label to type. The facts are the listed choices, the
    minibuffer text of the open prompt, the minibuffer text with the typed
    label and the typed label."""
    known = len(service_extra(session.state).get("listed", []))
    session.send("c")
    prompt = "Control of run " + run + ": "
    opened = session.wait(lambda state: state.get("minibuffer", "") == prompt
                          and len(service_extra(state).get("listed", [])) > known, label + "-control-prompt", 60)
    listing = service_extra(opened)["listed"][-1]
    assert listing["prompt"] == prompt, listing
    choice = choose(listing["choices"])
    session.send(choice)
    typed = session.wait(lambda state: state.get("minibuffer", "") == prompt + choice, label + "-control-typed")
    session.send("\r")
    return {"choices": listing["choices"], "promptText": opened["minibuffer"], "typedText": typed["minibuffer"], "label": choice}


def service_controls_case(args, directory: Path) -> None:
    """Drive three controls of wf-service.el by keys at 80x24.

    The harness that runs the manager starts each run and names it through
    the handshakes of service_handshake in the directory of
    --service-handshake. M-x wf-runs opens the view of each run. In the
    view of a profile_route run at its recovery decision, c, the label
    failover:1 and RET send the fail-over choice. In the view of a
    profile_1 run at its recovery decision, c, the label abandon and RET
    send the abandon choice. In the view of a profile_live run whose
    dispatch window offers two targets, c, the redirect label of the
    second listed target and RET send the redirect. After each send the
    harness confirms the effect and settles the run, and the view shows
    the terminal status. M-x wf-local then closes the session, and C-x
    C-c ends Emacs. The report records the listed choices, the minibuffer
    texts, the last lines of each view and the commands of the session,
    and it is written again after each step."""
    profile, report_path = Path(args.service[0]).resolve(), Path(args.service[1]).resolve()
    handshake = args.service_handshake.resolve()
    emacs_directory = args.source.resolve().parent
    sources = [emacs_directory / name for name in ("wf.el", "wf-manager.el", "wf-service.el")]
    report: dict = {"version": CONTROLS_REPORT_VERSION, "profile": str(profile), "steps": []}

    def record(step: str, line: str, **facts) -> None:
        report["steps"].append(step)
        report.update(facts)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print("PASS emacs-service-controls keys " + step + ": " + line, flush=True)

    def ended(run: str, label: str, status: str) -> list:
        """The last lines of the view of run once they show the terminal status."""
        final = session.wait(lambda state: service_view(state, run) is not None
                             and "Terminal: " + status in service_view(state, run)["lines"], label + "-terminal", 180)
        return service_view(final, run)["lines"]

    def recovery(name: str, step: str, choice: str, status: str) -> None:
        """One recovery choice at the recovery decision of the run that the
        handshake name-ready names."""
        ready = service_handshake(session, handshake, name + "-ready", {}, 180)
        run, decision = ready["run"], ready["decision"]
        service_open_view(session, run, name)
        session.wait(lambda state: service_view(state, run) is not None and service_view(state, run)["head"] == decision
                     and service_view(state, run)["kind"] == "recovery", name + "-recovery", 120)
        since = len(session.state.get("messages", ""))
        chosen = service_control_choose(session, run, name, lambda choices: choice)
        session.wait(service_said("wf: " + choice.split(":")[0] + " reached decision " + decision + " of run " + run, since),
                     name + "-sent", 90)
        service_handshake(session, handshake, name + "-sent", {"run": run, "decision": decision}, 240)
        record(step, "c, " + choice + " and RET sent the " + choice.split(":")[0] + " choice of decision " + decision
               + " of run " + run + ", and the view showed Terminal: " + status,
               **{name: {"run": run, "decision": decision, **chosen, "finalLines": ended(run, name, status)}})

    session = Emacs(args.emacs, sources, directory, 80, 24, service_body(profile, directory))
    success = False
    try:
        session.wait(lambda state: state.get("extra") is not None, "service-ready", SERVICE_READY_SECONDS)
        session.command("wf-service")
        session.wait(lambda state: "Client profile" in state.get("minibuffer", ""), "profile-file-prompt")
        session.send("\r")
        session.wait(lambda state: service_extra(state).get("service") is True
                     and "wf: service mode, endpoint" in state.get("messages", ""), "service-bound", 60)
        record("1", "M-x wf-service selected the client profile " + str(profile) + " at 80x24")
        recovery("failover", "2", "failover:1", "succeeded")
        recovery("abandon", "3", "abandon", "failed")

        # The redirect to the second listed target of the dispatch window.
        ready = service_handshake(session, handshake, "redirect-ready", {}, 180)
        run, targets = ready["run"], ready["targets"]
        service_open_view(session, run, "redirect")
        session.wait(lambda state: service_view(state, run) is not None and service_view(state, run)["head"] is None
                     and len([choice for choice in service_view(state, run)["choices"]
                              if choice["label"].startswith("redirect:")]) >= 2, "redirect-offered", 120)
        since = len(session.state.get("messages", ""))

        def second_target(choices: list) -> str:
            redirects = [choice for choice in choices if choice["label"].startswith("redirect:")]
            assert len(redirects) >= 2 and " to " + targets[1] + ", " in redirects[1]["description"], (redirects, targets)
            return redirects[1]["label"]

        chosen = service_control_choose(session, run, "redirect", second_target)
        session.wait(service_said(" of run " + run + " to " + targets[1], since), "redirect-sent", 90)
        service_handshake(session, handshake, "redirect-sent", {"run": run, "target": targets[1]}, 240)
        record("4", "c, " + chosen["label"] + " and RET sent the redirect of run " + run + " to the second listed target "
               + targets[1] + ", and the view showed Terminal: succeeded",
               redirect={"run": run, "targets": targets, "target": targets[1], **chosen,
                         "finalLines": ended(run, "redirect", "succeeded")})
        report["sent"] = service_extra(session.state).get("sent", [])
        session.command("wf-local")
        session.wait(lambda state: service_extra(state).get("service") is False, "local")
        success = True
    finally:
        session.close(success)
    record("5", "M-x wf-local closed the session, and C-x C-c ended Emacs with status 0 and the terminal attributes restored",
           terminalBefore=session.before, terminalAfter=session.ended["attributes"], exitStatus=session.ended["status"])


# The version of the report of the cross-client witness. The cross-client
# mode of agent-cat manager/test/service_http.py requires the same version.
WITNESS_REPORT_VERSION = 3
# The answer that the witness types in the answer editor of the question.
WITNESS_ANSWER = "false"
# The seconds for which the witness watches the session after the refusal
# of its answer, to show that the session sends nothing more.
WITNESS_QUIET = 3.0


def service_witness_case(args, directory: Path) -> None:
    """Observe a run that other clients created and approved, and lose an
    answer race, by keys at 80x24.

    M-x wf-service selects the client profile. The harness that runs the
    manager names the run and its pending person question in its answer
    to the handshake witness-ready of service_handshake in the directory
    of --service-handshake. M-x wf-runs opens the view of the run, which
    must show the pending question as its head. a opens the answer editor
    of that head, and the witness types WITNESS_ANSWER. The handshake
    open-answer then gives the harness the lines of the view, the text of
    the editor and the commands of the session, and the harness answers it
    after another client has answered the same head. C-c C-c then sends
    the open editor once. The manager refuses that answer, and the session
    must record the refusal as its problem, show it in *Messages*, keep the
    editor with its text and send nothing more for WITNESS_QUIET seconds.
    The handshake save-result then gives the harness the refusal and the
    commands of the session, and the harness answers it with the path of a
    new file after the run has succeeded. M-x wf-runs opens the view of the
    run again, which must show terminal success and the SHA-256 of the
    verified result, and r saves that result to the path. M-x wf-local then
    closes the session, and C-x C-c ends Emacs. The report records the
    process identifier of Emacs, the lines of the view, the refusal, the
    commands of the session and the saved path, and it is written again
    after each step."""
    profile, report_path = Path(args.service[0]).resolve(), Path(args.service[1]).resolve()
    handshake = args.service_handshake.resolve()
    emacs_directory = args.source.resolve().parent
    sources = [emacs_directory / name for name in ("wf.el", "wf-manager.el", "wf-service.el")]
    report: dict = {"version": WITNESS_REPORT_VERSION, "profile": str(profile), "answer": WITNESS_ANSWER, "steps": []}

    def record(step: str, line: str, **facts) -> None:
        report["steps"].append(step)
        report.update(facts)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print("PASS cross-client witness keys " + step + ": " + line, flush=True)

    def editing(state: dict) -> bool:
        return state.get("buffer", "").startswith("*wf answer JSON")

    session = Emacs(args.emacs, sources, directory, 80, 24, service_body(profile, directory))
    success = False
    try:
        session.wait(lambda state: state.get("extra") is not None, "service-ready", SERVICE_READY_SECONDS)
        session.command("wf-service")
        session.wait(lambda state: "Client profile" in state.get("minibuffer", ""), "profile-file-prompt")
        session.send("\r")
        session.wait(lambda state: service_extra(state).get("service") is True
                     and "wf: service mode, endpoint" in state.get("messages", ""), "service-bound", 60)
        record("1", "M-x wf-service selected the client profile " + str(profile) + " at 80x24", emacsPid=session.process.pid)
        ready = service_handshake(session, handshake, "witness-ready", {}, 180)
        run, question = ready["run"], ready["question"]
        service_open_view(session, run, "witness")
        viewed = session.wait(lambda state: service_view(state, run) is not None
                              and service_view(state, run)["head"] == question
                              and any(question + ": pending question" in line for line in service_view(state, run)["lines"]),
                              "witness-question", 120)
        view = service_view(viewed, run)
        record("2", "M-x wf-runs opened the view of run " + run + ", which showed the pending question " + question + " as its head",
               run=run, question=question, viewLines=view["lines"], head=view["head"], kind=view["kind"])

        # The answer editor of the head, with the typed answer.
        session.send("a")
        session.wait(editing, "witness-answer-editor", 60)
        session.send(WITNESS_ANSWER)
        typed = session.wait(lambda state: editing(state) and state.get("text") == WITNESS_ANSWER, "witness-answer-typed")
        sent = service_extra(typed).get("sent", [])
        record("3", "a opened the answer editor " + typed["buffer"] + " of question " + question + ", and the editor holds "
               + WITNESS_ANSWER, editorBuffer=typed["buffer"], editorText=typed["text"], sentBefore=sent)
        service_handshake(session, handshake, "open-answer",
                          {"run": run, "question": question, "viewLines": view["lines"], "head": view["head"], "kind": view["kind"],
                           "editorBuffer": typed["buffer"], "editorText": typed["text"], "sent": sent}, 300)

        # The send of the open editor after the other answer took effect.
        since = len(session.state.get("messages", ""))
        session.send(b"\x03\x03")
        refused = session.wait(lambda state: bool(service_extra(state).get("problem"))
                               and len(service_extra(state).get("sent", [])) == len(sent) + 1
                               and service_said(service_extra(state)["problem"][:60], since)(state), "witness-refused", 90)
        problem = service_extra(refused)["problem"]
        quiet = time.monotonic() + WITNESS_QUIET
        while time.monotonic() < quiet:
            session.drain()
        after = session.state
        record("4", "C-c C-c sent the open editor once, and the session showed the refusal: " + problem,
               refusal=problem, sentAfterRefusal=service_extra(refused).get("sent", []), sentQuiet=service_extra(after).get("sent", []),
               editorKept=editing(after) and after.get("text") == WITNESS_ANSWER,
               messagesAfter=after.get("messages", "")[max(0, since - 300):])
        report["sent"] = service_extra(session.state).get("sent", [])
        saving = service_handshake(session, handshake, "save-result",
                                   {"run": run, "refusal": problem, "sent": report["sent"], "sentAfterRefusal": report["sentAfterRefusal"],
                                    "sentQuiet": report["sentQuiet"], "editorKept": report["editorKept"],
                                    "messagesAfter": report["messagesAfter"]}, 480)
        saved = Path(saving["path"])

        # The verified result of the succeeded run, saved with r in its view.
        service_open_view(session, run, "witness-result")
        final = session.wait(lambda state: service_view(state, run) is not None
                             and "Terminal: succeeded" in service_view(state, run)["lines"]
                             and any(line.startswith("Result SHA-256: ") for line in service_view(state, run)["lines"]),
                             "witness-succeeded", 120)
        since = len(final.get("messages", ""))
        session.send("r")
        session.wait(lambda state: "Save the verified result of run " + run in state.get("minibuffer", ""), "witness-result-prompt", 60)
        session.send(b"\x01\x0b" + str(saved).encode())
        session.wait(lambda state: state.get("minibuffer", "").endswith(str(saved)), "witness-result-path")
        session.send("\r")
        stored = session.wait(lambda state: saved.exists() and service_said("saved the verified", since)(state), "witness-saved", 60)
        record("5", "r in the view of run " + run + " saved its verified result to " + str(saved), savedPath=str(saved),
               resultLines=[line for line in service_view(final, run)["lines"] if line.startswith(("Terminal: ", "Result"))],
               savedMessage=next(line for line in reversed(stored.get("messages", "").splitlines())
                                 if "saved the verified" in line and run in line))
        session.command("wf-local")
        session.wait(lambda state: service_extra(state).get("service") is False, "local")
        success = True
    finally:
        session.close(success)
    record("6", "M-x wf-local closed the session, and C-x C-c ended Emacs with status 0 and the terminal attributes restored",
           terminalBefore=session.before, terminalAfter=session.ended["attributes"], exitStatus=session.ended["status"])


# The version of the report of the lifecycle of the cross-client witness. The
# cross-client-lifecycle mode of agent-cat manager/test/service_http.py
# requires the same version.
WITNESS_LIFECYCLE_REPORT_VERSION = 2


def service_witness_lifecycle_case(args, directory: Path) -> None:
    """Observe a run of other clients across a quit, a credential rotation and
    a manager restart, follow a second run across a manager loss, and answer
    a later question with the rotated credential, by keys at 80x24.

    The first Emacs selects the client profile of --service with M-x
    wf-service. The harness names the run and its pending person question
    in its answer to the handshake observe-ready. M-x wf-runs opens the view
    of the run, which must show the question as its head under the
    supervision owned. The handshake quit gives the harness the lines and
    the choices of the view and the commands of the session, and C-x C-c
    then quits Emacs. The handshake quitted, which no Emacs drains, gives
    the harness the exit status and the terminal attributes, and the
    harness answers it with the path of the client profile of the rotated
    credential after the rotation and the restart of the manager. A second
    Emacs selects that profile, and M-x wf-runs opens the view of the run
    again, which must show the supervision lost. The handshake reconnected
    gives the harness the lines and the choices of that view, and the
    harness answers it with a second run and its pending person question.
    M-x wf-runs opens the view of the second run, which must show the
    question as its head under the supervision owned. The handshake held
    gives the harness that view, and the harness kills the manager. With
    no key, the view must report the delivery unreachable, and the
    handshake unreachable gives the harness that view. The harness starts
    the manager again, and with no key the view must show the supervision
    lost. The handshake quarantined gives the harness that view, and the
    harness answers it with a third run and its pending person question.
    M-x wf-runs opens the view of the third run, a opens the answer editor
    of the head, Emacs types WITNESS_ANSWER, and C-c C-c sends it once. The
    handshake answered gives the harness the commands of the session, and
    the harness answers it after the run has succeeded. M-x wf-local then
    closes the session, and C-x C-c ends the second Emacs. The report
    records the process identifiers, the lines and the choices of each
    view, the commands of each session and the exit of each Emacs, and it
    is written again after each step."""
    profile, report_path = Path(args.service[0]).resolve(), Path(args.service[1]).resolve()
    handshake = args.service_handshake.resolve()
    emacs_directory = args.source.resolve().parent
    sources = [emacs_directory / name for name in ("wf.el", "wf-manager.el", "wf-service.el")]
    report: dict = {"version": WITNESS_LIFECYCLE_REPORT_VERSION, "profile": str(profile), "answer": WITNESS_ANSWER, "steps": []}

    def record(step: str, line: str, **facts) -> None:
        report["steps"].append(step)
        report.update(facts)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print("PASS cross-client lifecycle keys " + step + ": " + line, flush=True)

    def bind(session: Emacs) -> None:
        session.wait(lambda state: state.get("extra") is not None, "service-ready", SERVICE_READY_SECONDS)
        session.command("wf-service")
        session.wait(lambda state: "Client profile" in state.get("minibuffer", ""), "profile-file-prompt")
        session.send("\r")
        session.wait(lambda state: service_extra(state).get("service") is True
                     and "wf: service mode, endpoint" in state.get("messages", ""), "service-bound", 60)

    def choices(view: dict) -> list:
        return [choice["label"] for choice in view["choices"]]

    first_directory = directory / "first"
    directory.mkdir()
    session = Emacs(args.emacs, sources, first_directory, 80, 24, service_body(profile, first_directory))
    success = False
    try:
        bind(session)
        record("1", "M-x wf-service selected the client profile " + str(profile) + " at 80x24", emacsPid=session.process.pid)
        ready = service_handshake(session, handshake, "observe-ready", {}, 300)
        run, question = ready["run"], ready["question"]
        service_open_view(session, run, "observe")
        viewed = session.wait(lambda state: service_view(state, run) is not None
                              and service_view(state, run)["head"] == question
                              and "Supervision: owned" in service_view(state, run)["lines"]
                              and "cancel" in choices(service_view(state, run)), "observe-question", 120)
        view = service_view(viewed, run)
        record("2", "M-x wf-runs opened the view of run " + run + ", which showed the pending question " + question
               + " under the supervision owned", run=run, question=question, observedLines=view["lines"],
               observedChoices=choices(view), observedHead=view["head"], observedKind=view["kind"])
        service_handshake(session, handshake, "quit", {"run": run, "question": question, "viewLines": view["lines"],
                                                       "choices": choices(view), "head": view["head"], "kind": view["kind"],
                                                       "sent": service_extra(session.state).get("sent", [])}, 300)
        report["firstSent"] = service_extra(session.state).get("sent", [])
        success = True
    finally:
        session.close(success)
    record("3", "C-x C-c quit the first Emacs while run " + run + " waited at its question, with status 0 and the terminal "
           "attributes restored", firstTerminalBefore=session.before, firstTerminalAfter=session.ended["attributes"],
           firstExitStatus=session.ended["status"])
    staged = handshake / "quitted.json.new"
    staged.write_text(json.dumps({"run": run, "exitStatus": session.ended["status"], "emacsPid": report["emacsPid"],
                                  "terminalRestored": session.ended["attributes"] == session.before}))
    staged.rename(handshake / "quitted.json")
    done = handshake / "quitted.done"
    deadline = time.monotonic() + 600
    while not done.exists():
        if time.monotonic() >= deadline:
            raise AssertionError(("the harness did not answer the handshake", "quitted"))
        time.sleep(0.05)
    rotated = Path(json.loads(done.read_text())["profile"]).resolve()

    # The second Emacs, with the client profile of the rotated credential.
    second_directory = directory / "second"
    later = Emacs(args.emacs, sources, second_directory, 80, 24, service_body(rotated, second_directory))
    success = False
    try:
        bind(later)
        record("4", "M-x wf-service in a second Emacs selected the client profile " + str(rotated) + " of the rotated credential",
               rotatedProfile=str(rotated), laterPid=later.process.pid)
        service_open_view(later, run, "reconnect")
        lost = later.wait(lambda state: service_view(state, run) is not None
                          and "Supervision: lost" in service_view(state, run)["lines"]
                          and "Offers: not yet observed" not in service_view(state, run)["lines"], "reconnect-lost", 120)
        view = service_view(lost, run)
        record("5", "M-x wf-runs opened the view of run " + run + ", which showed the supervision lost of the restarted manager",
               lostLines=view["lines"], lostChoices=choices(view))
        held = service_handshake(later, handshake, "reconnected", {"run": run, "viewLines": view["lines"], "choices": choices(view),
                                                                   "sent": service_extra(later.state).get("sent", [])}, 600)
        second, second_head = held["run"], held["question"]
        service_open_view(later, second, "held")
        owned = later.wait(lambda state: service_view(state, second) is not None and service_view(state, second)["head"] == second_head
                           and service_view(state, second)["kind"] == "question"
                           and "Supervision: owned" in service_view(state, second)["lines"], "held-question", 120)
        view = service_view(owned, second)
        record("6", "M-x wf-runs opened the view of run " + second + ", which showed the pending question " + second_head
               + " under the supervision owned", secondRun=second, secondQuestion=second_head, heldLines=view["lines"],
               heldChoices=choices(view))
        service_handshake(later, handshake, "held", {"run": second, "head": view["head"], "kind": view["kind"], "viewLines": view["lines"],
                                                     "choices": choices(view), "sent": service_extra(later.state).get("sent", [])}, 600)
        unreachable = later.wait(lambda state: service_view(state, second) is not None
                                 and "Delivery: unreachable" in service_view(state, second)["lines"], "held-unreachable", 60)
        view = service_view(unreachable, second)
        record("7", "the manager was killed while the view of run " + second + " waited at its question, and the view reported "
               "the delivery unreachable with no key", unreachableLines=view["lines"])
        service_handshake(later, handshake, "unreachable", {"run": second, "viewLines": view["lines"],
                                                            "sent": service_extra(later.state).get("sent", [])}, 600)
        relost = later.wait(lambda state: service_view(state, second) is not None
                            and "Delivery: unreachable" not in service_view(state, second)["lines"]
                            and "Supervision: lost" in service_view(state, second)["lines"]
                            and "Offers: none" in service_view(state, second)["lines"], "held-lost", 120)
        view = service_view(relost, second)
        record("8", "the manager started again, and with no key the view of run " + second + " reconnected and showed the "
               "supervision lost of the restarted manager", quarantinedLines=view["lines"], quarantinedChoices=choices(view))
        queued = service_handshake(later, handshake, "quarantined", {"run": second, "viewLines": view["lines"], "choices": choices(view),
                                                                     "sent": service_extra(later.state).get("sent", [])}, 600)
        third, head = queued["run"], queued["question"]
        service_open_view(later, third, "third")
        asked = later.wait(lambda state: service_view(state, third) is not None and service_view(state, third)["head"] == head
                           and service_view(state, third)["kind"] == "question", "third-question", 120)
        since = len(asked.get("messages", ""))
        later.send("a")
        later.wait(lambda state: state.get("buffer", "").startswith("*wf answer JSON"), "third-answer-editor", 60)
        later.send(WITNESS_ANSWER)
        later.wait(lambda state: state.get("text") == WITNESS_ANSWER, "third-answer-typed")
        later.send(b"\x03\x03")
        later.wait(service_said("reached decision " + head, since), "third-answered", 90)
        sent = service_extra(later.state).get("sent", [])
        record("9", "a, " + WITNESS_ANSWER + " and C-c C-c answered question " + head + " of run " + third,
               thirdRun=third, thirdQuestion=head, thirdLines=service_view(asked, third)["lines"], laterSent=sent)
        service_handshake(later, handshake, "answered", {"run": third, "question": head, "sent": sent}, 600)
        later.command("wf-local")
        later.wait(lambda state: service_extra(state).get("service") is False, "local")
        success = True
    finally:
        later.close(success)
    record("10", "M-x wf-local closed the session of the second Emacs, and C-x C-c ended it with status 0 and the terminal "
           "attributes restored", laterTerminalBefore=later.before, laterTerminalAfter=later.ended["attributes"],
           laterExitStatus=later.ended["status"])


# The version of the report of the lineage of the cross-client witness. The
# cross-client-lineage mode of agent-cat manager/test/service_http.py
# requires the same version.
WITNESS_LINEAGE_REPORT_VERSION = 1


def service_witness_lineage_case(args, directory: Path) -> None:
    """List the history of runs of other clients and show a lineage child and
    its parent, by keys at 80x24.

    M-x wf-service selects the client profile. The harness that runs the
    manager names a parent run and the run of its fork child in its answer
    to the handshake lineage-ready. M-x wf-history lists every page of the
    runs. RET on the row of the parent opens its view, which must show the
    lineage line of a root run and terminal success. M-x wf-history again
    and RET on the row of the child open its view, which must show the
    lineage line of the fork of the parent, terminal success and the
    SHA-256 of the verified result. M-x wf-local then closes the session,
    and C-x C-c ends Emacs. The report records the process identifier of
    Emacs, the runs and pages of the history, the lines of each view and
    the commands of the session, and it is written again after each step."""
    profile, report_path = Path(args.service[0]).resolve(), Path(args.service[1]).resolve()
    handshake = args.service_handshake.resolve()
    emacs_directory = args.source.resolve().parent
    sources = [emacs_directory / name for name in ("wf.el", "wf-manager.el", "wf-service.el")]
    report: dict = {"version": WITNESS_LINEAGE_REPORT_VERSION, "profile": str(profile), "steps": []}

    def record(step: str, line: str, **facts) -> None:
        report["steps"].append(step)
        report.update(facts)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print("PASS cross-client lineage keys " + step + ": " + line, flush=True)

    def lines(state: dict, run: str) -> list:
        view = service_view(state, run)
        return view["lines"] if view else []

    def history(label: str) -> dict:
        since = len(session.state.get("messages", ""))
        session.command("wf-history")
        listed = session.wait(lambda state: state.get("mode") == "wf-service-history-mode"
                              and service_said("wf: history of ", since)(state), label, 120)
        return next(item for item in service_extra(listed)["histories"] if item["buffer"] == listed["buffer"])

    session = Emacs(args.emacs, sources, directory, 80, 24, service_body(profile, directory))
    success = False
    try:
        session.wait(lambda state: state.get("extra") is not None, "service-ready", SERVICE_READY_SECONDS)
        session.command("wf-service")
        session.wait(lambda state: "Client profile" in state.get("minibuffer", ""), "profile-file-prompt")
        session.send("\r")
        session.wait(lambda state: service_extra(state).get("service") is True
                     and "wf: service mode, endpoint" in state.get("messages", ""), "service-bound", 60)
        record("1", "M-x wf-service selected the client profile " + str(profile) + " at 80x24", emacsPid=session.process.pid)
        ready = service_handshake(session, handshake, "lineage-ready", {}, 300)
        parent, child = ready["parent"], ready["child"]
        listed = history("lineage-history")
        record("2", "M-x wf-history listed " + str(len(listed["runs"])) + " runs over " + str(listed["pages"]) + " pages",
               historyRuns=listed["runs"], historyPages=listed["pages"])
        service_history_open(session, parent, "lineage-parent")
        shown = session.wait(lambda state: "Lineage: root" in lines(state, parent)
                             and "Terminal: succeeded" in lines(state, parent), "lineage-parent-root", 120)
        record("3", "RET on the history row of run " + parent + " opened its view with the lineage line of a root run",
               parentLines=lines(shown, parent))
        history("lineage-history-again")
        service_history_open(session, child, "lineage-child")
        lineage = "Lineage: fork of run " + parent
        shown = session.wait(lambda state: lineage in lines(state, child)
                             and "Terminal: succeeded" in lines(state, child)
                             and any(line.startswith("Result SHA-256: ") for line in lines(state, child)),
                             "lineage-child-succeeded", 180)
        record("4", "RET on the history row of run " + child + " opened its view, which showed " + lineage + " and terminal success",
               childLines=lines(shown, child), sent=service_extra(shown).get("sent", []))
        session.command("wf-local")
        session.wait(lambda state: service_extra(state).get("service") is False, "local")
        success = True
    finally:
        session.close(success)
    record("5", "M-x wf-local closed the session, and C-x C-c ended Emacs with status 0 and the terminal attributes restored",
           terminalBefore=session.before, terminalAfter=session.ended["attributes"], exitStatus=session.ended["status"])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emacs", default=os.environ.get("EMACS") or shutil.which("emacs"), required=False)
    parser.add_argument("--wf", default=os.environ.get("WF"))
    parser.add_argument("--control-runner", default=os.environ.get("WF_CONTROL_RUNNER"))
    parser.add_argument("--control-adapters", type=Path, default=os.environ.get("WF_CONTROL_ADAPTERS"))
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1] / "emacs/wf.el")
    parser.add_argument("--artifacts", type=Path)
    parser.add_argument("--service", nargs=2, metavar=("PROFILE", "REPORT"),
                        help="run only the service journey with the client profile PROFILE and write its report to REPORT")
    parser.add_argument("--service-answer", default="false", help="the answer that the service journey types")
    parser.add_argument("--service-case", choices=["journey", "lifecycle", "controls", "witness", "witness-lifecycle", "witness-lineage"],
                        default="journey",
                        help="the service case that --service runs")
    parser.add_argument("--service-handshake", type=Path,
                        help="the directory of the handshakes of the lifecycle, the controls or a witness case with the harness that runs the manager")
    args = parser.parse_args()
    if args.service:
        if not args.emacs or not os.access(args.emacs, os.X_OK):
            parser.error("provide an executable emacs")
        if args.service_case in ("lifecycle", "controls", "witness", "witness-lifecycle", "witness-lineage") \
                and (not args.service_handshake or not args.service_handshake.is_dir()):
            parser.error(f"the {args.service_case} case needs --service-handshake, the directory of its handshakes with the harness")
        artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix="wf-emacs-service-", dir="/tmp")).resolve()
        artifacts.mkdir(exist_ok=True)
        print(artifacts, flush=True)
        if args.service_case == "lifecycle":
            service_lifecycle_case(args, artifacts / "lifecycle")
            print("PASS service lifecycle by keys at 140x36, 80x24 and 40x12, lineage, export, a manager restart, a quit "
                  "while a run waits and a second Emacs, and terminal restoration", flush=True)
            return
        if args.service_case == "controls":
            service_controls_case(args, artifacts / "controls")
            print("PASS service controls by keys at 80x24: a fail-over, an abandon and a redirect to the second listed target, "
                  "and terminal restoration", flush=True)
            return
        if args.service_case == "witness-lifecycle":
            service_witness_lifecycle_case(args, artifacts / "witness-lifecycle")
            print("PASS cross-client lifecycle by keys at 80x24: the view of a run of other clients showed it owned, the quit "
                  "sent nothing, a second Emacs with the rotated credential showed it lost after the manager restart, "
                  "followed a second run across a manager loss to its lost supervision, answered a later question, and "
                  "terminal restoration", flush=True)
            return
        if args.service_case == "witness-lineage":
            service_witness_lineage_case(args, artifacts / "witness-lineage")
            print("PASS cross-client lineage by keys at 80x24: the history listed the runs of other clients, the view of a "
                  "parent showed a root run, the view of its fork child showed its lineage and terminal success, and terminal "
                  "restoration", flush=True)
            return
        if args.service_case == "witness":
            service_witness_case(args, artifacts / "witness")
            print("PASS cross-client witness by keys at 80x24: the view of a run of other clients showed its pending question, "
                  "the answer editor of that head sent once after another client answered it, the session showed the refusal "
                  "and sent nothing more, r saved the verified result of the run, and terminal restoration", flush=True)
            return
        service_case(args, artifacts / "service")
        print("PASS service journey by keys at 80x24 with resizes to 40x12 and 140x36, and terminal restoration", flush=True)
        return
    for name in ["emacs", "wf", "control_runner"]:
        if not getattr(args, name) or not os.access(getattr(args, name), os.X_OK):
            parser.error(f"provide an executable {name}")
    if (not args.control_adapters
            or not (args.control_adapters / "retry_adapter.py").is_file()
            or not os.access(args.control_adapters / "stub_adapter.py", os.X_OK)):
        parser.error("provide --control-adapters or WF_CONTROL_ADAPTERS naming agent-cat engine/acp/test")
    args.control_adapters = args.control_adapters.resolve()
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix="wf-emacs-ui-", dir="/tmp")).resolve()
    artifacts.mkdir(exist_ok=True)
    print(artifacts, flush=True)
    for width, height in [(40, 12), (80, 24), (140, 36)]:
        form_case(args, artifacts / f"form-{width}x{height}", width, height)
        print(f"PASS form navigation and terminal restoration at {width}x{height}", flush=True)
    human_case(args, artifacts / "human")
    print("PASS native human review, resize, typed answers and verified result", flush=True)
    for command in ["retryOccurrence", "failoverOccurrence"]:
        recovery_case(args, artifacts / command, command)
        print(f"PASS keyboard {command}, control-prompt resize and verified result", flush=True)
    history_case(args, artifacts / "history")
    print("PASS persistent observer, verified result and fork refusal across sizes", flush=True)
    multiwindow_case(args, artifacts / "multiwindow")
    print("PASS independent window following during real runtime updates", flush=True)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--tty-host":
        tty_host()
    else:
        main()
