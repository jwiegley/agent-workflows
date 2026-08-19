#!/usr/bin/env bash
#
# The toolbox gate — every registered workflow, against a table pinned in this
# file.
#
#     ./ci/workflows.sh          # from the repository root, inside the devShell
#
# `Workflows.Registry.registry` is the owner's toolbox: his commands, agents and
# skills as agent-cat programs. It is held to a DIFFERENT discipline from
# agent-cat's `ci/examples.sh`, and the difference is the whole reason there are
# two registries.
#
#   ci/examples.sh pins level, size, askNodes, costSummary and both bills by
#   EQUALITY. Those seven programs are evidence about the language, and a moved
#   number is a fact worth stopping for.
#
#   This gate pins what a toolbox can honestly hold still. A lens added to a
#   roster moves askNodes, costMax and every path count in every program that
#   panels it — and that is a Tuesday, not a regression. A gate that went red
#   every Tuesday would be re-pinned by reflex, and the reflex would spread to
#   the gate next door.
#
# So, per row:
#
#   wf plan <name>              level    EQUALITY  — a rung is a design decision
#                               paths    EQUALITY  — a new branch is a design decision
#   wf cost <name>              costMax  CEILING   — a budget is a promise about
#                                                    the worst case; it may fall
#                                                    freely and rises only by
#                                                    editing one number here
#   wf run <name> --scripted    exit 0             — every branch a scripted
#                                                    default takes is reachable,
#                                                    and every text question has
#                                                    a canned reply
#
# `size`, `askNodes` and the bills are deliberately NOT pinned: they are exactly
# the fields a reworded rubric or an added lens moves, and pinning them here
# would buy nothing this gate does not already catch through `paths` and the
# ceiling.
#
# The registry is read from the binary rather than transcribed: a workflow
# registered and not pinned is a workflow whose price nobody is watching, and a
# row naming no workflow is a row about something that has gone.
#
# No Lean, no network, no agent: `--scripted` answers from each row's own table
# and runs no command. Exits 0 only if every check below passed.
set -uo pipefail
# `|| exit` and not `set -e`: this gate counts failures rather than stopping at
# the first one. Everything below is relative to the repository root, which is
# also the package root.
cd "$(dirname "$0")/.." || exit 1

work="$(mktemp -d "${TMPDIR:-/tmp}/agent-workflows.XXXXXX")"
trap 'rm -rf "$work"' EXIT

failures=0

note() { echo "ci/workflows: $*"; }
bad() {
  # workflow, field, expected, actual — a gate that says only "something moved"
  # costs an afternoon finding out what.
  echo "ci/workflows: FAIL $1: $2: expected '$3', actual '$4'" >&2
  failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# The inputs a row is priced and run with
# ---------------------------------------------------------------------------
#
# EVERY INPUT IS THE EMPTY STRING, deliberately. `plan` and `cost` bind `""` for
# an input nobody gave, and `run` refuses until every input is named — so the
# only way to run the very program that was priced is to name each one empty.
# That is also what makes house rule WR-1 a gate rather than a convention: a
# roster-shaping input must read `""` as THE DEFAULT ROSTER and never as NO
# MEMBERS, because `panel []` is an `error` on a CAF and would take the whole
# binary down here.
inputsFor() {
  case "$1" in
    review-*) ins=(--input-arg scope= --input-arg paths=) ;;
    green-*) ins=(--input-arg target=) ;;
    commit | commit-*) ins=(--input-arg scope= --input-arg tree=) ;;
    fess) ins=(--input-arg request= --input-arg base=) ;;
    stack | stack-*)
      ins=(--input-arg trunk= --input-arg tip= --input-arg agents= --input-arg pr=)
      ;;
    *) ins=() ;;
  esac
}

# ---------------------------------------------------------------------------
# The pinned table
# ---------------------------------------------------------------------------
#
#   pin <name> <level> <paths> <costCeiling>

names=()
declare -A pinLevel pinPaths pinCeiling

pin() {
  names+=("$1")
  pinLevel[$1]=$2
  pinPaths[$1]=$3
  pinCeiling[$1]=$4
}

#   name                level     paths  ceiling

# The smoke row (`Workflows.Hello`). One scrap, two cross-cutting lenses folded
# into a document, one report call: no branch and no loop, so its price is exact
# and the ceiling is the price. It exists to prove the wiring — the registry,
# the shared CLI, the roster, the panel fold, `defining`'s table — rather than to
# do any of the owner's work, and it is the row this gate should be read against
# when a change to the foundation breaks something.
pin hello               pipeline      1       4

# The review ladder (`Workflows.Review.Ladder`). Four rungs, four prices, side by
# side — which is the entire reason the ladder became a program instead of a
# paragraph that orders five commands by a feeling about weight.
pin review-quick        branch        3       6
pin review-deep         branch        3      10
pin review-sec          branch        3       6
pin review-heavy        branch        3      12

# The gated fix loop (`Workflows.Fix.Green`). The path count is the loop's, and
# it is the number to watch: a rung that grew a branch grew a way to end.
pin green-ci            branch        8      10
pin green-tree          branch        8       9
pin green-flaky         branch        9      11

# The commit-discipline pipeline (`Workflows.Git.Commit`). One `commitFn` with
# four callers; the rungs differ in what they ask of the decomposition and in how
# many repair trips the gate is given, and the ceiling is where that shows.
pin commit              branch        6       8
pin commit-push         branch        6       9
pin commit-recommit     branch       12      12
pin commit-bankruptcy   branch        9      10

# The audit (`Workflows.Audit.Fess`). Eleven stances over three receipts, and the
# only row here whose minimum equals its maximum: nothing in it is a loop, and
# the one branch chooses which provenance the report carries rather than how much
# is asked.
#
# The ceiling was 15 until 2026-08-19, when the landing verification found that
# `Rubrics.Fess.sins` carried ten of `fess-auditor.md`'s ELEVEN bold sections —
# `**Loose ends**`, the file's last, was missing. Restoring it is one more lens,
# which is one more question and no more paths: 15 -> 16, `paths` still 2. This
# is the movement that gate comment above is about — a lens added to a roster is
# a Tuesday — and it is re-pinned here rather than absorbed, so the next reader
# can tell a repair from a drift.
pin fess                branch        2      16

# The git family (`Workflows.Git.Stack`). One body, four rungs, and the two
# numbers to watch are `stack` against `stack-rebase` — IDENTICAL, because they
# are the same program with a different argv deciding — and `stack-rebase-fix`
# against both, where the difference IS `rebase-and-fix.md`'s second half: a
# second gate and a bot sweep, priced at seven more consultations in the worst
# case and two and a half times the paths.
pin stack               branch       40      21
pin stack-rebase        branch       40      21
pin stack-rebase-fix    branch      100      28
pin stack-cleanup       branch       30      19

# ---------------------------------------------------------------------------
# The binary, resolved once
# ---------------------------------------------------------------------------
#
# `cabal list-bin` and not `cabal run`, for the reason `wf` must be a real binary
# on PATH: every `running` party's argv executes in the process's working
# directory, and `cabal run` may move it. A gate that ran the toolbox from
# somewhere else would be answering `git diff` about another repository.

cabal build all > "$work/build" 2>&1 \
  || { echo "ci/workflows: the build failed:" >&2; cat "$work/build" >&2; exit 1; }

# Zero warnings is part of the gate: a warning nobody can fix is a warning
# everybody learns to scroll past.
#
# The pattern is GHC's own — `FILE:LINE:COL: warning:` — and deliberately not a
# search for the word. cabal writes `Warning: The package list for
# 'hackage.haskell.org' is 30 days old` on a machine that has not run
# `cabal update` recently, which is a fact about the index and not about this
# code; a gate that went red for it would be turned off within the week.
if grep -qE "^[^[:space:]].*:[0-9]+:[0-9]+: warning:" "$work/build"; then
  echo "ci/workflows: the build warned:" >&2
  grep -nE "^[^[:space:]].*:[0-9]+:[0-9]+: warning:" -A6 "$work/build" >&2
  failures=$((failures + 1))
fi

wf=$(cabal list-bin exe:wf 2>/dev/null | tail -1)
[ -x "$wf" ] || { echo "ci/workflows: no wf binary: '$wf'" >&2; exit 1; }

# ---------------------------------------------------------------------------
# The registry, read from the binary
# ---------------------------------------------------------------------------

"$wf" list > "$work/list" 2>&1
registered=$(sed -n 's/^  \([^ ][^ ]*\)  .*/\1/p' "$work/list")
[ -n "$registered" ] || {
  echo "ci/workflows: could not read the registry: $(cat "$work/list")" >&2
  exit 1
}

for n in $registered; do
  [ -n "${pinLevel[$n]+set}" ] \
    || bad "$n" registry "a pinned row" "registered, and pinned nowhere in ci/workflows.sh"
done
for n in "${names[@]}"; do
  echo "$registered" | grep -qx "$n" \
    || bad "$n" registry "a registered workflow" "pinned here, and registered nowhere"
done

# Every row's one line, because `wf list` is what an operator browses and a blank
# line is a row nobody can choose.
while read -r n; do
  [ -n "$n" ] || continue
  doc=$(sed -n "s/^  $n  *//p" "$work/list")
  [ -n "$doc" ] || bad "$n" blurb "one line" "empty"
done <<< "$registered"

# ---------------------------------------------------------------------------
# Every row, field by field
# ---------------------------------------------------------------------------

# The value on a `  <label>   <value>` line, or the empty string.
field() { sed -n "s/^  *$2  *//p" "$1" | head -1; }

for n in "${names[@]}"; do
  inputsFor "$n"

  "$wf" plan "$n" > "$work/$n.plan" 2>&1
  code=$?
  [ "$code" = 0 ] || bad "$n" "plan exit" 0 "$code"

  got_level=$(field "$work/$n.plan" level)
  [ "$got_level" = "${pinLevel[$n]}" ] || bad "$n" level "${pinLevel[$n]}" "$got_level"

  # `paths` and `maxFold` both come off the one cost summary line, which `plan`
  # and `cost` share so the two verbs cannot disagree about them.
  summary=$(field "$work/$n.plan" cost)
  got_paths=$(echo "$summary" | sed -n 's/.*over \([0-9][0-9]*\) path.*/\1/p')
  [ "$got_paths" = "${pinPaths[$n]}" ] || bad "$n" paths "${pinPaths[$n]}" "$got_paths"

  "$wf" cost "$n" > "$work/$n.cost" 2>&1
  code=$?
  [ "$code" = 0 ] || bad "$n" "cost exit" 0 "$code"

  got_max=$(field "$work/$n.cost" costSummary | sed -n 's/.*maxFold \([0-9][0-9]*\).*/\1/p')
  if [ -z "$got_max" ]; then
    bad "$n" costMax "a number" "no maxFold on the costSummary line"
  elif [ "$got_max" -gt "${pinCeiling[$n]}" ]; then
    bad "$n" costMax "at most ${pinCeiling[$n]}" "$got_max"
  fi

  # stdin is /dev/null: a scripted run asks nobody, and this is what makes that a
  # fact rather than a hope.
  "$wf" run "$n" --scripted "${ins[@]}" < /dev/null > "$work/$n.run" 2>&1
  code=$?
  [ "$code" = 0 ] || {
    bad "$n" "run --scripted exit" 0 "$code"
    tail -20 "$work/$n.run" >&2
  }

  note "$n: ${pinLevel[$n]}, ${got_paths} path(s), costMax $got_max of ${pinCeiling[$n]}; scripted exit $code"
done

# ---------------------------------------------------------------------------
# The `Agentic.Cli` contract
# ---------------------------------------------------------------------------
#
# This binary serves ITS OWN table under ITS OWN noun. `Agentic.Cli` is one
# function in agent-cat and both registries call it, so the outside evidence that
# `regNoun` and `regBinary` are still doing their job is that a refusal here is
# spelled in this registry's words and not in the examples'.

"$wf" plan --no-such-workflow > "$work/refusal" 2>&1
if grep -q "no workflow named" "$work/refusal"; then
  note "wf refuses in its own noun: two registries, one CLI"
else
  bad wf "the registry's noun" "no workflow named …" "$(cat "$work/refusal")"
fi

# ---------------------------------------------------------------------------

if [ "$failures" = 0 ]; then
  echo "ci/workflows: ${#names[@]} workflow(s) pinned, 0 failed"
else
  echo "ci/workflows: $failures check(s) failed" >&2
fi
exit $((failures > 0))
