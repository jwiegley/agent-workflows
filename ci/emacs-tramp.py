#!/usr/bin/env python3
"""Run real TRAMP pipe tests against an unprivileged loopback-only SSH fixture."""
from __future__ import annotations

import argparse
import getpass
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import socket
import subprocess
import tempfile
import time


def quoted(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


class SshFixture:
    def __init__(self, artifacts: Path):
        self.artifacts = artifacts
        self.temporary = tempfile.TemporaryDirectory(prefix=".wf-ssh-test-", dir=Path.home())
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        self.home.mkdir(mode=0o700)
        self.work = self.root / "work"
        self.work.mkdir(mode=0o700)
        self.server = None
        self.log = None

    def __enter__(self):
        try:
            for name in ["host", "client"]:
                subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(self.root / name)], check=True)
            authorized = self.root / "authorized_keys"
            authorized.write_bytes((self.root / "client.pub").read_bytes())
            authorized.chmod(0o600)
            with socket.socket() as probe:
                probe.bind(("127.0.0.1", 0))
                self.port = probe.getsockname()[1]
            shell = self.root / "session-shell"
            shell.write_text('#!/bin/sh\nif test -n "$SSH_ORIGINAL_COMMAND"; then\n  exec /bin/sh -c "$SSH_ORIGINAL_COMMAND"\nelse\n  exec /bin/sh -i\nfi\n')
            shell.chmod(0o700)
            config = self.root / "sshd_config"
            config.write_text("\n".join([
                f"Port {self.port}", "ListenAddress 127.0.0.1", f"HostKey {self.root}/host",
                f"PidFile {self.root}/pid", f"AuthorizedKeysFile {authorized}", "StrictModes yes",
                "PasswordAuthentication no", "KbdInteractiveAuthentication no", "AuthenticationMethods publickey",
                "PermitRootLogin no", "PermitUserRC no", "PermitUserEnvironment no", "X11Forwarding no",
                "AllowTcpForwarding no", "AllowAgentForwarding no", f"AllowUsers {getpass.getuser()}",
                f"SetEnv HOME={self.home} ZDOTDIR={self.home}", f"ForceCommand {shell}", "LogLevel VERBOSE", "",
            ]))
            sshd = shutil.which("sshd")
            subprocess.run([sshd, "-t", "-f", str(config)], check=True)
            self.log = (self.artifacts / "sshd.log").open("wb")
            self.server = subprocess.Popen(
                [sshd, "-D", "-e", "-f", str(config)], stdin=subprocess.DEVNULL, stdout=self.log, stderr=self.log,
                env={"PATH": os.environ["PATH"], "HOME": str(self.home), "ZDOTDIR": str(self.home)},
                start_new_session=True,
            )
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if self.server.poll() is not None:
                    raise AssertionError("loopback sshd exited; see sshd.log")
                try:
                    with socket.create_connection(("127.0.0.1", self.port), timeout=.1):
                        break
                except OSError:
                    time.sleep(.05)
            else:
                raise AssertionError("loopback sshd did not become ready")
            host_key = (self.root / "host.pub").read_text().split()
            known = self.root / "known_hosts"
            known.write_text(f"[127.0.0.1]:{self.port} {host_key[0]} {host_key[1]}\n")
            self.client_config = self.root / "ssh_config"
            self.client_config.write_text("\n".join([
                "Host *", f"  IdentityFile {self.root}/client", "  IdentitiesOnly yes",
                f"  UserKnownHostsFile {known}", "  GlobalKnownHostsFile /dev/null",
                "  StrictHostKeyChecking yes", "  BatchMode yes", "  PasswordAuthentication no", "  ControlMaster no", "",
            ]))
            self.wrapper = self.root / "ssh-wrapper"
            self.wrapper.write_text(f"#!/bin/sh\nexec {shlex.quote(shutil.which('ssh'))} -F {shlex.quote(str(self.client_config))} \"$@\"\n")
            self.wrapper.chmod(0o700)
            self.prefix = f"/ssh:{getpass.getuser()}@127.0.0.1#{self.port}:"
            self.remote = self.prefix + str(self.work) + "/"
            probe = subprocess.run(
                [str(self.wrapper), "-p", str(self.port), "-l", getpass.getuser(), "127.0.0.1",
                 'printf "fixture-ok\\n%s\\n%s\\n" "$HOME" "$ZDOTDIR"'],
                capture_output=True, text=True, timeout=15,
            )
            assert probe.returncode == 0, probe.stderr
            assert probe.stdout.splitlines() == ["fixture-ok", str(self.home), str(self.home)], probe.stdout
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *_):
        if self.server is not None and self.server.poll() is None:
            os.killpg(self.server.pid, signal.SIGTERM)
            try:
                self.server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(self.server.pid, signal.SIGKILL)
                self.server.wait()
        if self.log is not None:
            self.log.close()
        self.temporary.cleanup()

    def link(self, program: str) -> str:
        """Return a short fixture path that runs PROGRAM on the loopback host."""
        directory = self.root / "bin"
        directory.mkdir(mode=0o700, exist_ok=True)
        link = directory / "wf"
        link.symlink_to(Path(program).resolve())
        return str(link)

    def lisp_configuration(self) -> str:
        return f'''
(require 'tramp-sh)
(setq tramp-persistency-file-name {quoted(str(self.artifacts / 'tramp-cache.el'))}
      tramp-histfile-override t
      tramp-verbose 6)
(defun wf-tramp-debug ()
  (let ((contents (mapconcat (lambda (buffer)
                    (with-current-buffer buffer
                      (if (string-match-p "tramp" (buffer-name))
                          (concat "BUFFER " (buffer-name) "\\n" (buffer-string) "\\n") "")))
                  (buffer-list) ""))
        (default-directory "/") (coding-system-for-write 'no-conversion))
    (with-temp-file {quoted(str(self.artifacts / 'tramp-debug.txt'))}
      (set-buffer-multibyte nil) (insert (encode-coding-string contents 'utf-8-unix)))))
(defun wf-tramp-phase (text)
  (let ((default-directory "/") (coding-system-for-write 'utf-8-unix))
    (write-region (concat text "\\n") nil {quoted(str(self.artifacts / 'phases.log'))} t 'silent)))
(run-at-time 15 15 #'wf-tramp-debug)
(let ((method (copy-tree (assoc "ssh" tramp-methods))))
  (setcar (cdr (assq 'tramp-login-program (cdr method))) {quoted(str(self.wrapper))})
  (setf (alist-get "ssh" tramp-methods nil nil #'equal) (cdr method)))
'''


def batch_test(args, fixture: SshFixture, artifacts: Path) -> None:
    source = fixture.work / "input.txt"
    source.write_bytes("α雪\r\nsecond\n\n".encode())
    source.chmod(0o600)
    output = artifacts / "batch-result.json"
    script = artifacts / "batch.el"
    script.write_text(fixture.lisp_configuration() + f'''
(setq wf-program {quoted(args.control_runner)}
      wf-state-directory {quoted(str(fixture.root / 'state'))}
      default-directory {quoted(fixture.remote)})
(defun wf-tramp-wait (predicate)
  (let ((deadline (+ (float-time) 30)))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (unless (funcall predicate) (error "TRAMP fixture timed out"))))
(wf-tramp-phase "source-check")
(unless (condition-case failure
            (progn (wf--setup-file {quoted(f'/ssh:{getpass.getuser()}@127.0.0.1#{fixture.port + 1}:/unused')}) nil)
          (user-error (string-match-p "machine" (error-message-string failure))))
  (error "A file from another SSH endpoint was accepted"))
(let* ((directory default-directory)
       (file (wf--setup-file {quoted(fixture.prefix + str(source))}))
       (_ (wf-tramp-phase "prepare-process"))
       (session (wf--prepare '((name . "person-controlled"))
                 `(((name . "input") (source . "file") (path . ,file)))
                 '("--scripted") directory)))
  (unless (equal file {quoted(str(source))}) (error "Wrong remote source path"))
  (wf-tramp-wait (lambda () (not (eq (wf--session-phase session) 'preparing))))
  (unless (eq (wf--session-phase session) 'prepared)
    (error "Remote preparation failed: %s; stderr: %s" (wf--session-error session)
           (decode-coding-string (or (wf--session-diagnostics session) "") 'utf-8-unix)))
  (write-region "changed after capture" nil {quoted(fixture.prefix + str(source))} nil 'silent)
  (setf (wf--session-phase session) 'running)
  (wf--send session `((version . 1) (operation . "start")
                     (approvalId . ,(alist-get 'approvalId (wf--session-prepared session)))))
  (dotimes (index 2)
    (wf-tramp-wait (lambda () (or (wf--session-pending session) (wf--session-error session))))
    (when (wf--session-error session) (error "%s" (wf--session-error session)))
    (let* ((id (car (wf--session-pending session)))
           (occ (cdr (assoc id (wf--session-occurrences session))))
           (reference (alist-get 'question (plist-get occ :pending))) question)
      (wf--artifact session "read-question" reference (lambda (reply) (setq question reply)) id "flag")
      (wf-tramp-wait (lambda () question))
      (unless (string-suffix-p "α雪\\r\\nsecond\\n\\n" (alist-get 'prompt (alist-get 'question question)))
        (error "Remote source bytes changed"))
      (wf--control-send session `((type . "answerPerson") (answer . ,(if (zerop index) :false t))) id)
      (wf-tramp-wait (lambda () (not (member id (wf--session-pending session)))))))
  (wf-tramp-wait (lambda () (memq (wf--session-phase session) '(completed failed cancelled))))
  (unless (eq (wf--session-phase session) 'completed) (error "Remote run did not complete"))
  (let* ((prepared (wf--session-prepared session))
         (record (wf--query wf-program directory
                   `((version . 1) (operation . "read-run")
                     (rootIdentity . ,(alist-get 'rootIdentity prepared))
                     (runId . ,(alist-get 'runId prepared))))))
    (unless (equal (alist-get 'status (alist-get 'snapshot (alist-get 'run record))) "succeeded")
      (error "Remote record did not replay"))
    (let ((child (wf--prepare-request
                   `((version . 1) (operation . "prepare-lineage")
                     (stateDirectory . {quoted(str(fixture.root / 'state'))})
                     (parentRunId . ,(alist-get 'runId prepared)) (lineage . "resume")
                     (personAnswering . "local-control") (edits . [])) directory)))
      (wf-tramp-wait (lambda () (not (eq (wf--session-phase child) 'preparing))))
      (unless (eq (wf--session-phase child) 'prepared) (error "Remote lineage preparation failed"))
      (setf (wf--session-phase child) 'running)
      (wf--send child `((version . 1) (operation . "start")
                       (approvalId . ,(alist-get 'approvalId (wf--session-prepared child)))))
      (wf-tramp-wait (lambda () (memq (wf--session-phase child) '(completed failed cancelled))))
      (unless (and (eq (wf--session-phase child) 'completed) (null (wf--session-pending child)))
        (error "Remote semantic resume did not reuse captured person answers")))
    (let ((cancelled (wf--prepare '((name . "person-controlled"))
                      '(((name . "input") (source . "literal") (value . "remote cancellation")))
                      '("--scripted") directory)))
      (wf-tramp-wait (lambda () (not (eq (wf--session-phase cancelled) 'preparing))))
      (unless (eq (wf--session-phase cancelled) 'prepared) (error "Remote cancel fixture failed"))
      (setf (wf--session-phase cancelled) 'running)
      (wf--send cancelled `((version . 1) (operation . "start")
                           (approvalId . ,(alist-get 'approvalId (wf--session-prepared cancelled)))))
      (wf-tramp-wait (lambda () (wf--session-pending cancelled)))
      (wf--control-send cancelled '((type . "cancelRun")) nil)
      (wf-tramp-wait (lambda () (eq (wf--session-phase cancelled) 'cancelled))))
    (let ((catalogue (wf--query wf-program directory
                       `((version . 1) (operation . "list-runs")
                         (rootIdentity . ,(alist-get 'rootIdentity prepared))))))
      (unless (= (length (alist-get 'runs catalogue)) 3) (error "Remote history lost runs")))
    (let ((default-directory "/") (coding-system-for-write 'utf-8-unix))
      (with-temp-file {quoted(str(output))}
        (insert (decode-coding-string
                 (json-serialize `((status . "passed") (remote . ,directory)
                                   (runId . ,(alist-get 'runId prepared)))) 'utf-8-unix))))))
(tramp-cleanup-all-connections)
''')
    environment = {key: value for key, value in os.environ.items() if not key.startswith("AGENT_CAT_")}
    environment.update(HOME=str(fixture.home), ZDOTDIR=str(fixture.home))
    with (artifacts / "emacs.log").open("wb") as log:
        result = subprocess.Popen([args.emacs, "-Q", "--batch", "-l", str(args.source), "-l", str(script)],
                                  cwd=fixture.work, env=environment, stdout=log, stderr=log, start_new_session=True)
        try:
            result.wait(timeout=60)
        except subprocess.TimeoutExpired:
            os.kill(result.pid, signal.SIGUSR2)
            try:
                result.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(result.pid, signal.SIGKILL)
                result.wait()
            raise
    assert result.returncode == 0, f"TRAMP batch failed ({result.returncode}); see {artifacts}/emacs.log"
    assert json.loads(output.read_bytes())["status"] == "passed"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emacs", default=os.environ.get("EMACS") or shutil.which("emacs"))
    parser.add_argument("--control-runner", default=os.environ.get("WF_CONTROL_RUNNER"))
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1] / "emacs/wf.el")
    parser.add_argument("--artifacts", type=Path)
    args = parser.parse_args()
    for name in ["emacs", "control_runner"]:
        if not getattr(args, name) or not os.access(getattr(args, name), os.X_OK):
            parser.error(f"provide executable {name}")
    for tool in ["sshd", "ssh", "ssh-keygen"]:
        if not shutil.which(tool):
            parser.error(f"{tool} is required")
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix="wf-tramp-", dir="/tmp")).resolve()
    artifacts.mkdir(exist_ok=True)
    print(artifacts, flush=True)
    with SshFixture(artifacts) as fixture:
        # TRAMP refuses a direct asynchronous command longer than the remote
        # PIPE_BUF, which is 512 bytes on macOS, and its own environment prefix
        # uses most of that. The remote runner therefore has a short path.
        args.control_runner = fixture.link(args.control_runner)
        batch_test(args, fixture, artifacts)
        import importlib.util
        spec = importlib.util.spec_from_file_location("wf_emacs_ui", Path(__file__).with_name("emacs-ui.py"))
        ui = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ui)
        ui.human_case(args, artifacts / "interactive", fixture.lisp_configuration(), fixture.remote, fixture.root / "interactive-state")
    print("PASS loopback TRAMP batch and interactive native runs, resize, typed controls and verified artifacts; fixture removed", flush=True)


if __name__ == "__main__":
    main()
