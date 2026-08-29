#!/usr/bin/env bash
#
# The cookbook's per-row sections, generated from the help texts.
#
#     ./tools/cookbook-gen.sh            # rewrite doc/cookbook.md in place
#     ./tools/cookbook-gen.sh OUT        # write the regenerated page to OUT
#
# `doc/research/help-design.md` §4 settles where the per-row prose lives: the
# help texts are the source, and the cookbook's per-row sections are generated
# from them. The alternative — two authored copies with a diff gate — converts
# drift into a red gate, which is better than nothing, and then converts every
# honest edit into two; a gate that goes red for an honest edit is a gate
# somebody turns off.
#
# So this page is AUTHORED PROSE WITH MARKED REGIONS. What no row owns stays
# written by hand: the grammar paragraph, the per-family prose, the transport
# table, and "Building and installing it". What one row owns is between its
# markers and belongs to `wf help <row>`:
#
#     <!-- wf:begin wiggum -->
#     …the price line, then wf help wiggum's authored half…
#     <!-- wf:end wiggum -->
#
# TWO RENDERINGS OF ONE NUMBER, BOTH COMPUTED. The price line is built from
# `wf list --json` in the cookbook's own `level · min to max over N paths` form,
# and the body is `wf help <row>`'s, whose header carries the same numbers off
# the same `Agentic.Plan.Facts`. Neither is authored, so the cookbook's price
# lines stop being seventy-four hand-copied numbers — a second class of drift
# that a re-pinned ceiling in `ci/workflows.sh` silently creates today.
#
# No `jq`: `ci/workflows.sh` reads `list --json` with `tr` and `sed` and this
# does the same, because `flake.nix` promises neither.
#
# `ci/cookbook.sh` is the gate: it regenerates into a temporary copy and
# refuses any difference.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

page="doc/cookbook.md"
out="${1:-$page}"

work="$(mktemp -d "${TMPDIR:-/tmp}/cookbook-gen.XXXXXX")"
trap 'rm -rf "$work"' EXIT

wf=$(cabal list-bin exe:wf 2>/dev/null | tail -1)
[ -x "$wf" ] || { echo "cookbook-gen: no wf binary: '$wf'" >&2; exit 1; }

[ -f "$page" ] || { echo "cookbook-gen: no $page" >&2; exit 1; }

"$wf" list > "$work/list" 2>&1 || { cat "$work/list" >&2; exit 1; }
"$wf" list --json > "$work/list.json" 2>&1 || { cat "$work/list.json" >&2; exit 1; }

# One scalar field of one row. `tr '{'` puts one row per line; every field read
# here has a value with no comma in it, which is what lets `[^,}]*` stand in for
# a parser.
rowField() {
  tr '{' '\n' < "$work/list.json" \
    | grep "\"name\":\"$1\"" \
    | sed -n "s/.*\"$2\":\([^,}]*\).*/\1/p" \
    | tr -d '"'
}

# `level · min to max over N paths`, the form the page already reads in — and a
# single number where the two bounds coincide, which is how the twenty rows that
# price exactly have always been written here.
priceLine() {
  local n="$1" level min max paths spread noun
  level=$(rowField "$n" level)
  min=$(rowField "$n" minFold)
  max=$(rowField "$n" maxFold)
  paths=$(rowField "$n" paths)
  if [ "$min" = "$max" ]; then spread="$min"; else spread="$min to $max"; fi
  if [ "$paths" = 1 ]; then noun="path"; else noun="paths"; fi
  printf '`%s · %s over %s %s`\n' "$level" "$spread" "$paths" "$noun"
}

# The authored half of a page: everything below the computed header and above
# the footer, with the blank edges trimmed. Both ends belong to `Agentic.Cli`
# and neither is a row's, so neither travels into a page about rows.
helpBody() {
  "$wf" help "$1" \
    | sed -e '1,/^  pins /d' -e '/^  wf --help lists the flags/,$d' \
    | sed -e '/./,$!d' \
    | awk 'BEGIN{blank=0} {if ($0 ~ /^[[:space:]]*$/) {blank++} else {while (blank-- > 0) print ""; blank=0; print}}'
}

# Every registered row, in listing order, into one file per row.
registered=$(sed -n 's/^  \([^ ][^ ]*\)  .*/\1/p' "$work/list")
[ -n "$registered" ] || { echo "cookbook-gen: could not read the registry" >&2; exit 1; }

for n in $registered; do
  # A blank line either side of the region's contents: an HTML comment ends the
  # block it opens, so Markdown would parse this either way — the blank lines
  # are for the reader of the source, who should be able to see where a
  # generated region starts without counting comment markers.
  {
    echo
    priceLine "$n"
    echo
    helpBody "$n"
    echo
  } > "$work/$n.section"
done

# The splice. Everything outside a marked region is copied byte for byte; a
# region's contents are dropped and its row's section written in their place.
# A marker naming a row that is not registered is an error rather than a
# passthrough: the page would otherwise keep a section about something that has
# gone, which is the drift this whole arrangement exists to end.
awk -v dir="$work" -v names=" $(echo "$registered" | tr '\n' ' ')" '
  /^<!-- wf:begin [a-z0-9-]+ -->$/ {
    name = $3
    if (index(names, " " name " ") == 0) {
      printf "cookbook-gen: <!-- wf:begin %s --> names no registered workflow\n", name > "/dev/stderr"
      exit 1
    }
    print
    while ((getline line < (dir "/" name ".section")) > 0) print line
    close(dir "/" name ".section")
    inside = 1
    next
  }
  /^<!-- wf:end [a-z0-9-]+ -->$/ { inside = 0; print; next }
  inside { next }
  { print }
' "$page" > "$work/page" || exit 1

cp "$work/page" "$out"
