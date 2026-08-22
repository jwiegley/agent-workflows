#!/usr/bin/env bash
#
# The cookbook gate — `doc/cookbook.md`'s per-row sections against the help
# texts they are generated from.
#
#     ./ci/cookbook.sh           # from the repository root, inside the devShell
#
# `doc/research/help-design.md` §4 makes the help texts the source and the
# cookbook's per-row sections their rendering. That is only true while somebody
# checks it: a generated region edited by hand reads exactly like an authored
# one, and the first time an edit here survives a release the arrangement is
# over. So this gate regenerates into a temporary copy and refuses any
# difference.
#
# THREE CHECKS, AND THE FIRST IS THE WHOLE POINT.
#
#   1. Regeneration is a NO-OP. `diff -u` against a fresh render, byte for byte,
#      which catches an edit made inside a marked region AND a help text edited
#      in a module without the page being regenerated. Both are the same defect
#      seen from two ends.
#   2. Every registered row has EXACTLY ONE marked region. A row registered and
#      not documented is a row an operator meets first in a refusal; two regions
#      for one row are two renderings that will differ the moment one is edited.
#   3. Every marked region names a REGISTERED row. A region about something that
#      has gone is the drift this arrangement exists to end, pointing the other
#      way.
#
# No Lean, no network, no agent: the generator runs `wf list`, `wf list --json`
# and `wf help`, all three of which are static verbs that ask nobody and spend
# nothing. Exits 0 only if every check below passed.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

work="$(mktemp -d "${TMPDIR:-/tmp}/ci-cookbook.XXXXXX")"
trap 'rm -rf "$work"' EXIT

failures=0
note() { echo "ci/cookbook: $*"; }
bad() {
  echo "ci/cookbook: FAIL $1: $2" >&2
  failures=$((failures + 1))
}

page="doc/cookbook.md"
[ -f "$page" ] || { echo "ci/cookbook: no $page" >&2; exit 1; }

# `cabal` directly and not `nix develop`, which is `ci/workflows.sh`'s own
# convention: both gates are run from inside the devShell, and a gate that
# re-entered it would build a second time for nothing.
cabal build exe:wf > "$work/build" 2>&1 \
  || { echo "ci/cookbook: the build failed:" >&2; cat "$work/build" >&2; exit 1; }

wf=$(cabal list-bin exe:wf 2>/dev/null | tail -1)
[ -x "$wf" ] || { echo "ci/cookbook: no wf binary: '$wf'" >&2; exit 1; }

# ---------------------------------------------------------------------------
# The registry, and the page's markers, read from where each of them lives
# ---------------------------------------------------------------------------

"$wf" list > "$work/list" 2>&1
registered=$(sed -n 's/^  \([^ ][^ ]*\)  .*/\1/p' "$work/list")
[ -n "$registered" ] \
  || { echo "ci/cookbook: could not read the registry: $(cat "$work/list")" >&2; exit 1; }

begins=$(sed -n 's/^<!-- wf:begin \([a-z0-9-]*\) -->$/\1/p' "$page")
ends=$(sed -n 's/^<!-- wf:end \([a-z0-9-]*\) -->$/\1/p' "$page")

# Every registered row: exactly one region, opened and closed.
while read -r n; do
  [ -n "$n" ] || continue
  b=$(echo "$begins" | grep -cx "$n")
  e=$(echo "$ends" | grep -cx "$n")
  [ "$b" = 1 ] || bad "$n" "expected exactly 1 <!-- wf:begin $n -->, found $b"
  [ "$e" = 1 ] || bad "$n" "expected exactly 1 <!-- wf:end $n -->, found $e"
done <<< "$registered"

# Every region: a registered row.
while read -r n; do
  [ -n "$n" ] || continue
  echo "$registered" | grep -qx "$n" \
    || bad "$n" "<!-- wf:begin $n --> names no registered workflow"
done <<< "$begins"

# The markers nest, in order, one pair at a time. An unclosed region would
# otherwise swallow the authored prose after it on the next regeneration, which
# is a data-loss bug and not a formatting one.
awk -v out="$work/nesting" '
  /^<!-- wf:begin [a-z0-9-]+ -->$/ {
    if (open != "") { print "begin " $3 " inside " open > out; bad = 1 }
    open = $3; next
  }
  /^<!-- wf:end [a-z0-9-]+ -->$/ {
    if (open != $3) { print "end " $3 " closes " (open == "" ? "nothing" : open) > out; bad = 1 }
    open = ""; next
  }
  END { if (open != "") print "begin " open " is never closed" > out }
' "$page"
if [ -s "$work/nesting" ]; then
  while read -r why; do bad "$page" "$why"; done < "$work/nesting"
fi

# ---------------------------------------------------------------------------
# Regeneration is a no-op
# ---------------------------------------------------------------------------

./tools/cookbook-gen.sh "$work/regenerated" > "$work/gen" 2>&1 \
  || { echo "ci/cookbook: the generator failed:" >&2; cat "$work/gen" >&2; exit 1; }

if diff -u "$page" "$work/regenerated" > "$work/diff" 2>&1; then
  note "regeneration is a no-op: $(echo "$begins" | grep -c .) region(s), byte-identical"
else
  bad "$page" "regeneration is not a no-op — run ./tools/cookbook-gen.sh"
  head -60 "$work/diff" >&2
fi

# ---------------------------------------------------------------------------

if [ "$failures" = 0 ]; then
  echo "ci/cookbook: $(echo "$registered" | grep -c .) row(s) documented, 0 failed"
else
  echo "ci/cookbook: $failures check(s) failed" >&2
fi
exit $((failures > 0))
