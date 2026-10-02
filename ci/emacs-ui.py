#!/usr/bin/env python3
"""Exercise native Emacs widgets, windows, real scripted runs, and the service journey and lifecycle in private PTYs."""
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


def service_body(profile: Path, directory: Path) -> str:
    """Return the Lisp body of a service case for the client profile PROFILE.

    It sets the profile and the coding systems and defines `wf-ui-extra',
    whose report states service mode, the runs that the session knows,
    the review buffers, the run views with their lines, head and control
    choices, and the service history buffer with its run identifiers."""
    return f"""
(set-keyboard-coding-system 'utf-8-unix)
(set-terminal-coding-system 'utf-8-unix)
(setq wf-manager-profiles (list {string(str(profile))})
      suggest-key-bindings nil
      extended-command-suggest-shorter nil
      default-directory {string(str(directory) + '/')})
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
      (histories . ,(vconcat histories)))))
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
        session.wait(lambda state: state.get("extra") is not None, "service-ready")
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
        prompt = session.wait(lambda state: "Approve preparation" in state.get("minibuffer", ""), "approve-prompt")["minibuffer"]
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
LIFECYCLE_REPORT_VERSION = 1
LIFECYCLE_FIRST = "Emacs lifecycle λ: first delayed run"
LIFECYCLE_SECOND = "Emacs lifecycle λ: second delayed run"
LIFECYCLE_CAPTURE = "Emacs capture λ ✓\nsecond line 雪\n"
LIFECYCLE_STEER = "Emacs lifecycle steer λ: focus on the patch."
LIFECYCLE_ANSWER = "false"


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
    # The review of the new request is the review buffer of a request that
    # no review buffer named before the submission.
    known = {item["request"] for item in service_extra(form).get("reviews", [])}
    session.send(b"\x03\x03")
    review = session.wait(lambda state: state.get("mode") == "wf-service-review-mode" and service_review(state) is not None
                          and service_review(state)["request"] not in known, label + "-review", 150)
    request = service_review(review)["request"]
    session.send("a")
    prompt = session.wait(lambda state: "Approve preparation" in state.get("minibuffer", ""), label + "-approve-prompt")["minibuffer"]
    session.send("yes\r")
    approved = session.wait(lambda state: any(item["request"] == request and item.get("run")
                                              for item in service_extra(state).get("reviews", [])), label + "-approved", 150)
    run = next(item["run"] for item in service_extra(approved)["reviews"] if item["request"] == request)
    return {"run": run, "request": request, "preparation": service_review(review)["preparation"],
            "approvePrompt": prompt, "formText": form["text"]}


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
    sent through its editor. At 40x12, M-x wf-history lists every page of
    the runs, the first run is opened from its row and r saves its
    verified result. The report records the facts of each step and is
    written again after each step."""
    profile, report_path = Path(args.service[0]).resolve(), Path(args.service[1]).resolve()
    emacs_directory = args.source.resolve().parent
    sources = [emacs_directory / name for name in ("wf.el", "wf-manager.el", "wf-service.el")]
    saved = directory / "saved-result.bin"
    report: dict = {"version": LIFECYCLE_REPORT_VERSION, "first": LIFECYCLE_FIRST, "second": LIFECYCLE_SECOND,
                    "capture": LIFECYCLE_CAPTURE, "steer": LIFECYCLE_STEER, "answer": LIFECYCLE_ANSWER,
                    "profile": str(profile), "steps": []}

    def record(step: str, line: str, **facts) -> None:
        report["steps"].append(step)
        report.update(facts)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print("PASS emacs-service-lifecycle keys " + step + ": " + line, flush=True)

    session = Emacs(args.emacs, sources, directory, 140, 36, service_body(profile, directory))
    success = False
    try:
        session.wait(lambda state: state.get("extra") is not None, "service-ready")
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
        session.wait(lambda state: "Control of run " + captured["run"] in state.get("minibuffer", ""), "control-prompt", 60)
        session.send(choice["label"] + "\r")
        session.wait(lambda state: state.get("buffer", "").startswith("*wf steer "), "steer-editor", 60)
        session.send(LIFECYCLE_STEER)
        session.wait(lambda state: state.get("text") == LIFECYCLE_STEER, "steer-typed")
        session.send(b"\x03\x03")
        session.wait(service_said("wf: steer interrupt-now reached occurrence", since), "steered", 90)
        steered = session.wait(lambda state: "Terminal: succeeded" in service_view(state, captured["run"])["lines"], "steered-succeeded", 120)
        record("9", "c and " + choice["label"] + " opened the steer editor of run " + captured["run"]
               + ", C-c C-c sent the typed text with the timing interrupt-now, and the run succeeded",
               steerChoice=choice, steeredLines=service_view(steered, captured["run"])["lines"])

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
        session.command("search-forward")
        session.wait(lambda state: "Search:" in state.get("minibuffer", ""), "search-prompt")
        session.send(first["run"] + "\r")
        session.send("\r")
        opened = session.wait(lambda state: state.get("mode") == "wf-service-run-mode" and service_view(state, first["run"]) is not None
                              and state.get("buffer") == service_view(state, first["run"])["buffer"], "history-opened", 60)
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
        session.command("wf-local")
        session.wait(lambda state: service_extra(state).get("service") is False, "local")
        success = True
    finally:
        session.close(success)
    record("13", "M-x wf-local closed the session, and C-x C-c ended Emacs with status 0 and the terminal attributes restored",
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
    parser.add_argument("--service-case", choices=["journey", "lifecycle"], default="journey",
                        help="the service case that --service runs")
    args = parser.parse_args()
    if args.service:
        if not args.emacs or not os.access(args.emacs, os.X_OK):
            parser.error("provide an executable emacs")
        artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix="wf-emacs-service-", dir="/tmp")).resolve()
        artifacts.mkdir(exist_ok=True)
        print(artifacts, flush=True)
        if args.service_case == "lifecycle":
            service_lifecycle_case(args, artifacts / "lifecycle")
            print("PASS service lifecycle by keys at 140x36, 80x24 and 40x12, and terminal restoration", flush=True)
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
