#!/usr/bin/env python3
"""Exercise native Emacs widgets, windows and real scripted runs in private PTYs."""
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
    def __init__(self, executable: str, source: Path, directory: Path, width: int, height: int, body: str):
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
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))
        environment = {key: value for key, value in os.environ.items() if not key.startswith("AGENT_CAT_")}
        environment.update(HOME=str(directory / "home"), TERM="xterm-256color")

        def terminal() -> None:
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen(
            [sys.executable, str(Path(__file__).resolve()), "--tty-host", str(self.exit_path),
             executable, "-Q", "-nw", "-l", str(source), "-l", str(init)],
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emacs", default=os.environ.get("EMACS") or shutil.which("emacs"), required=False)
    parser.add_argument("--wf", default=os.environ.get("WF"))
    parser.add_argument("--control-runner", default=os.environ.get("WF_CONTROL_RUNNER"))
    parser.add_argument("--control-adapters", type=Path, default=os.environ.get("WF_CONTROL_ADAPTERS"))
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1] / "emacs/wf.el")
    parser.add_argument("--artifacts", type=Path)
    args = parser.parse_args()
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
