#!/usr/bin/env bash
#
# The Emacs gate — every `emacs/*.el' file, in four passes.
#
#     ./ci/emacs.sh              # from the repository root
#
# `emacs/wf.el' uses the runner's descriptor, native frontend, and read-only
# frontend-io JSON contracts. It displays plan text without scraping it.
# This gate checks Lisp compilation, docstrings, and local runner behavior.
# Interactive terminal and SSH/TRAMP checks live in ci/emacs-ui.py and
# ci/emacs-tramp.py.
#
# Four passes, in the order that a failure is cheapest to read:
#
#   1. BYTE-COMPILE, with `byte-compile-error-on-warn'. Not a warning count —
#      a warning is the failure. A free variable or a wrong arity in a branch
#      nobody has taken yet is exactly the bug an interactive package hides
#      best, because the branch is a prompt somebody has to reach.
#
#   2. CHECKDOC, with the flags the defaults leave off (`arguments-in-order',
#      `package-keywords'). This file's docstrings carry the reasons for its
#      decisions, so they are load-bearing text and not decoration; checkdoc
#      exits 0 whatever it finds, so its output is what fails this pass.
#
#   3. RUNNER TESTS, `emacs/wf-smoke.el', against the real wf binary and
#      deterministic control fixture. These exercise native session behavior
#      and descriptor-driven discovery, completion, and input histories.
#
#   4. TRANSPORT TESTS, `emacs/wf-manager-tests.el', the ERT tests of the
#      service-mode transport `emacs/wf-manager.el'. They load client
#      profiles from temporary files, check the exact JSON codec, and run the
#      events vectors, the drafts, requests, preparations, receipts,
#      decisions, answers, controls and runs vectors, and the refresh
#      sequences, backoff, jitter and reconciliation vectors of agent-cat
#      test/manager_client_vectors.json, which WF_MANAGER_VECTORS names. The
#      HTTP transport tests start a plain HTTP listener on 127.0.0.1 inside
#      the test Emacs and check the exact request bytes, the typed refusals,
#      the response bound, cancellation, cleanup and the capability binding.
#      The session tests use the same listener for the overview page set, its
#      restart after 410 view-expired, the follow loop, the resnapshot after a
#      410 cursor refusal, the coalescing of invalidations during a read, the
#      endpoint switch and its failures, the close of a session with a
#      switch in flight, the uncertain send of an answer whose connection the
#      listener closes, with exactly one send and its reconciliation by one
#      read, the capture of exact bytes with its media type and receipt, and
#      the verified download of an artifact. The service-mode tests
#      check that wf-service-commands of emacs/wf-service.el states each
#      public command of emacs/wf.el once, that local mode is the default,
#      and that each pending and local-only command refuses in service mode
#      and starts no process and sends no request. They also check that a
#      refresh of the setup form keeps every draft, that the setup sources
#      give literal or capture specs, and that the review text states every
#      approval selector, the entity tag and the admission. The control tests
#      check that wf-control lists only the controls that the controls of a run
#      offer, that wf-kill sends one cancel only after a yes to its
#      confirmation, and that an uncertain steer is reconciled with one read and
#      not sent again. The tests of a server certificate that the CA file
#      of the profile does not verify start a TLS server on 127.0.0.1 with
#      the python3 of PATH. They contact no other host.
#
# Passes 1 and 2 also cover `emacs/wf-manager-live.el', the live check of
# the transport and of service mode against a running agent-cat workflow
# manager. This gate does
# not run it: the emacs-client mode of agent-cat
# `manager/test/service_http.py' runs it against a manager that the mode
# starts.
#
# No providers are contacted. The native tests use scripted runs and the
# deterministic human/control fixture named by WF_CONTROL_RUNNER. The
# agent-deck listing is supplied by a temporary deterministic shell fixture.
#
# Exits 0 only if all four passed.
set -uo pipefail
# `|| exit` and not `set -e`: this gate counts failures rather than stopping at
# the first one, so that one afternoon sees all four. Everything below is
# relative to the repository root, which is also the package root.
cd "$(dirname "$0")/.." || exit 1

work="$(mktemp -d "${TMPDIR:-/tmp}/agent-workflows-emacs.XXXXXX")"
trap 'rm -rf "$work"' EXIT

failures=0

note() { echo "ci/emacs: $*"; }
bad() {
  # pass, what was expected, what happened — a gate that says only "something
  # is wrong with wf.el" costs an afternoon finding out what.
  echo "ci/emacs: FAIL $1: expected $2, got $3" >&2
  failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# What this gate needs
# ---------------------------------------------------------------------------
#
# $EMACS, then whatever is on PATH. Named rather than searched for because the
# byte-compiler is the gate: a different Emacs is a different set of warnings,
# and a run under one that happens to be on PATH is not evidence about the one
# the package claims to support.
emacs="${EMACS:-}"
if [ -z "$emacs" ]; then
  emacs="$(command -v emacs 2>/dev/null)"
fi
if [ -z "$emacs" ] || ! [ -x "$emacs" ]; then
  echo "ci/emacs: no Emacs to run: set \$EMACS to one (29.1 or later), or put \`emacs' on PATH." >&2
  exit 1
fi
note "$("$emacs" --version | head -1) at $emacs"

# $WF, then the build tree. `wf-smoke.el' does this same search itself so that
# it can be run by hand, but the gate does it too, to fail with one sentence
# here rather than a backtrace out of a batch Emacs.
wf="${WF:-}"
if [ -z "$wf" ]; then
  # shellcheck disable=SC2012  # a glob, not a listing: the newest build wins.
  wf="$(ls -t dist-newstyle/build/*/*/*/x/wf/build/wf/wf 2>/dev/null | head -1)"
fi
if [ -z "$wf" ] || ! [ -x "$wf" ]; then
  echo "ci/emacs: no \`wf' binary: set \$WF to one, or \`cabal build exe:wf' to leave one under dist-newstyle." >&2
  exit 1
fi
wf="$(cd "$(dirname "$wf")" && pwd)/$(basename "$wf")"
note "wf at $wf"

control="${WF_CONTROL_RUNNER:-}"
if [ -z "$control" ]; then
  control="$(command -v routing-fixed-point-probe 2>/dev/null)"
fi
if [ -z "$control" ] || ! [ -x "$control" ]; then
  echo 'ci/emacs: set $WF_CONTROL_RUNNER to a compatible routing-fixed-point-probe for required human/control tests.' >&2
  exit 1
fi
control="$(cd "$(dirname "$control")" && pwd)/$(basename "$control")"
note "control fixture at $control"

adapters="${WF_CONTROL_ADAPTERS:-}"
if [ -z "$adapters" ] || ! [ -r "$adapters/retry_adapter.py" ] || ! [ -x "$adapters/stub_adapter.py" ]; then
  echo 'ci/emacs: use the Nix development shell or set $WF_CONTROL_ADAPTERS to agent-cat engine/acp/test.' >&2
  exit 1
fi
note "ACP fixtures at $adapters"

# The shared client vectors of agent-cat. The pinned agent-cat source of the
# development shell predates the file, so the gate names it explicitly and
# never skips the vector tests.
vectors="${WF_MANAGER_VECTORS:-}"
if [ -z "$vectors" ] || ! [ -r "$vectors" ]; then
  echo 'ci/emacs: set $WF_MANAGER_VECTORS to agent-cat test/manager_client_vectors.json for the transport vector tests.' >&2
  exit 1
fi
note "client vectors at $vectors"

# ---------------------------------------------------------------------------
# 1. Byte-compilation, where a warning is a failure
# ---------------------------------------------------------------------------
#
# Every file, the tests included: a test script that byte-compiles clean is a
# script whose every free variable is a real one. The `.elc' this leaves beside
# each source is deleted before and after, because a stale one is the single
# way this package can be loaded and not be the file somebody is reading.

lisp=(emacs/*.el)
rm -f emacs/*.elc
for f in "${lisp[@]}"; do
  if "$emacs" -Q --batch -L emacs \
       --eval '(setq byte-compile-error-on-warn t)' \
       -f batch-byte-compile "$f" > "$work/compile.out" 2>&1; then
    note "byte-compile $f: clean"
  else
    bad "byte-compile $f" "no warnings" "the following"
    cat "$work/compile.out" >&2
  fi
done
rm -f emacs/*.elc

# ---------------------------------------------------------------------------
# 2. Checkdoc, strictly
# ---------------------------------------------------------------------------
#
# `checkdoc-file' exits 0 whatever it finds, so the output is the verdict.
# `arguments-in-order' and `package-keywords' are off by default and both are
# wanted here: an argument named out of order is a docstring describing a
# signature the function does not have, and a keyword outside the standard set
# is a package that will not be found by the word it is about.

for f in "${lisp[@]}"; do
  "$emacs" -Q --batch --eval "(progn
      (require 'checkdoc)
      (setq checkdoc-arguments-in-order-flag t
            checkdoc-package-keywords-flag t
            checkdoc-permit-comma-termination-flag nil
            checkdoc-force-docstrings-flag t
            checkdoc-verb-check-experimental-flag t)
      (checkdoc-file \"$f\"))" > "$work/checkdoc.out" 2>&1
  if [ -s "$work/checkdoc.out" ]; then
    bad "checkdoc $f" "nothing to say" "the following"
    cat "$work/checkdoc.out" >&2
  else
    note "checkdoc $f: nothing to say"
  fi
done

# ---------------------------------------------------------------------------
# 3. The smoke, against the real binary
# ---------------------------------------------------------------------------
#
# stdin is /dev/null: every prompt in this package is a question to a person,
# and this pass reaches none of them — it calls the readers' insides and the
# price gate with `wf-confirm-function' bound to a function of its own. A hang
# here would mean one of them got through, which is worth failing over.

if WF="$wf" WF_CONTROL_RUNNER="$control" "$emacs" -Q --batch -l emacs/wf-smoke.el \
     < /dev/null > "$work/smoke.out" 2>&1; then
  cat "$work/smoke.out"
  note "smoke: green"
else
  bad smoke "every fact to hold" "exit $?"
  cat "$work/smoke.out" >&2
fi

# ---------------------------------------------------------------------------
# 4. The transport tests
# ---------------------------------------------------------------------------
#
# ERT over temporary files, the client vectors, a plain HTTP listener on
# 127.0.0.1 inside the test Emacs and a python3 TLS server on 127.0.0.1. No
# other host is contacted, and this pass
# needs neither the wf binary nor the control fixture. It needs the vector
# file.

if WF_MANAGER_VECTORS="$vectors" "$emacs" -Q --batch -L emacs -l emacs/wf-manager-tests.el \
     -f ert-run-tests-batch-and-exit < /dev/null > "$work/manager.out" 2>&1; then
  cat "$work/manager.out"
  note "transport tests: green"
else
  bad "transport tests" "every ERT test to pass" "exit $?"
  cat "$work/manager.out" >&2
fi

# ---------------------------------------------------------------------------

if [ "$failures" = 0 ]; then
  echo "ci/emacs: 4 pass(es) over ${#lisp[@]} file(s), 0 failed"
else
  echo "ci/emacs: $failures check(s) failed" >&2
fi
exit $((failures > 0))
