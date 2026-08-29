#!/usr/bin/env bash
# Production source driver for the Taskmaster evidence-to-design workflow.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
root=$(git rev-parse --show-toplevel)
upstream_input=${TASKMASTER_UPSTREAM:-${1:-}}
upstream_revision=${TASKMASTER_UPSTREAM_REVISION:-c0c98d367c55296bfe69e65680625b6db437af02}
agent_cat_input=${TASKMASTER_AGENT_CAT:-$root/../agent-cat}
agent_cat_revision=${TASKMASTER_AGENT_CAT_REVISION:-}
runtime_agent_cat="$root/../agent-cat"
adapter_choice=${TASKMASTER_ADAPTER:-fixture}
output_dir=${TASKMASTER_OUTPUT_DIR:-$root/doc/research}
transcript_out=${TASKMASTER_TRANSCRIPT_OUT:-}

if [ -z "$upstream_input" ]; then
  echo "usage: TASKMASTER_UPSTREAM=/absolute/repository [TASKMASTER_AGENT_CAT=/absolute/repository] [TASKMASTER_ADAPTER=fixture|NAME|PATH] tools/taskmaster-framework.sh" >&2
  exit 2
fi
case "$output_dir" in
  /*) ;;
  *) output_dir="$root/$output_dir" ;;
esac
if [ -n "$transcript_out" ]; then
  case "$transcript_out" in
    /*) ;;
    *) transcript_out="$root/$transcript_out" ;;
  esac
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/workflow-taskmaster.XXXXXX")
phase=initialization
cleanup() {
  code=$?
  if [ "$code" -ne 0 ]; then
    mkdir -p "$output_dir"
    workflow_marker=
    [ -n "${scratch:-}" ] && workflow_marker="$scratch/taskmaster-framework-incomplete.json"
    if [ -n "$workflow_marker" ] && [ -f "$workflow_marker" ]; then
      cp "$workflow_marker" "$output_dir/taskmaster-framework-incomplete.json.tmp"
      mv "$output_dir/taskmaster-framework-incomplete.json.tmp" \
        "$output_dir/taskmaster-framework-incomplete.json"
    else
      python3 - "$output_dir/taskmaster-framework-incomplete.json" "$code" "$phase" <<'PY'
import json, os, sys
path, code, phase = sys.argv[1:]
with open(path + ".tmp", "w") as stream:
    json.dump({"status": "INCOMPLETE", "exit": int(code), "phase": phase}, stream, sort_keys=True)
    stream.write("\n")
os.replace(path + ".tmp", path)
PY
    fi
    echo "taskmaster: incomplete (exit $code)" >&2
    [ -f "${transcript:-}" ] && tail -30 "$transcript" | cut -c1-500 >&2
  fi
  [ -z "${publish_dir:-}" ] || rm -rf "$publish_dir"
  [ -z "${transcript_tmp:-}" ] || rm -f "$transcript_tmp"
  rm -rf "$work"
  trap - EXIT
  exit "$code"
}
trap cleanup EXIT

if [ -z "$agent_cat_revision" ]; then
  agent_cat_revision=$(git -C "$agent_cat_input" rev-parse HEAD)
fi
phase=runtime-source
runtime_haskell_status=$(git -C "$runtime_agent_cat" status --porcelain -- haskell)
if [ -n "$runtime_haskell_status" ]; then
  echo "taskmaster: runtime agent-cat Haskell subtree is dirty" >&2
  exit 2
fi
producer_revision=$(git rev-parse HEAD)
producer_tree=$(git rev-parse 'HEAD^{tree}')
runtime_revision=$(git -C "$runtime_agent_cat" rev-parse HEAD)
runtime_tree=$(git -C "$runtime_agent_cat" rev-parse 'HEAD^{tree}')

phase=source-snapshot
upstream_source="$work/taskmaster-source"
agent_cat_source="$work/agent-cat-source"
snapshot() {
  source_repository=$1
  revision=$2
  destination=$3
  mkdir "$destination"
  git -C "$destination" init --quiet
  mkdir -p "$destination/.git/objects/info"
  git -C "$source_repository" rev-parse --path-format=absolute --git-path objects \
    >"$destination/.git/objects/info/alternates"
  git -C "$destination" cat-file -e "$revision^{commit}"
  git -C "$destination" checkout --quiet --detach "$revision"
}
snapshot "$upstream_input" "$upstream_revision" "$upstream_source"
snapshot "$agent_cat_input" "$agent_cat_revision" "$agent_cat_source"

phase=evidence
manifest="$work/evidence.json"
python3 tools/taskmaster-evidence.py \
  --upstream "$upstream_source" --upstream-revision "$upstream_revision" \
  --local "$agent_cat_source" --local-revision "$agent_cat_revision" \
  --output "$manifest"

adapter="$adapter_choice"
if [ "$adapter_choice" = fixture ]; then
  adapter="$root/tools/taskmaster-fixture.py"
fi

phase=build
nix develop path:./. -c cabal build all >"$work/build.txt" 2>&1 || {
  cat "$work/build.txt" >&2
  exit 1
}
bin=$(nix develop path:./. -c cabal list-bin exe:wf 2>/dev/null | tail -1)
plan="$work/plan.json"
"$bin" plan taskmaster --json --input-file "evidence=$manifest" >"$plan"

phase=run
scratch="$work/scratch"
transcript="$work/transcript.txt"
PATH="$root/tools:$PATH" "$bin" run taskmaster \
  --engine acp --adapter "$adapter" --require-pinned --scratch "$scratch" \
  --input-file "evidence=$manifest" >"$transcript" 2>&1

report="$scratch/taskmaster-agent-cat-framework.md"
test -s "$report"
bill_fresh=$(awk '$1 == "billFresh" { print $2; exit }' "$transcript")
bill_memo=$(awk '$1 == "billMemo" { print $2; exit }' "$transcript")
case "$bill_fresh:$bill_memo" in
  *[!0-9:]*) exit 1 ;;
esac
((bill_fresh >= 14 && bill_fresh <= 22))
((bill_memo >= 14 && bill_memo <= 22))
grep -Fq '  run tee taskmaster-agent-cat-framework.md' "$transcript"

phase=publish
mkdir -p "$output_dir"
publish_dir=$(mktemp -d "$output_dir/.taskmaster-publish.XXXXXX")
staged_manifest="$publish_dir/taskmaster-evidence-manifest.json"
staged_report="$publish_dir/taskmaster-agent-cat-framework.generated.md"
staged_certificate="$publish_dir/taskmaster-framework-run.md"
cp "$manifest" "$staged_manifest"
cp "$report" "$staged_report"

if [ -n "$transcript_out" ]; then
  transcript_tmp="$transcript_out.tmp.$$"
  python3 - "$transcript" "$transcript_tmp" "$work" "$upstream_input" \
    "$upstream_source" "$agent_cat_input" "$agent_cat_source" "$root" \
    "$runtime_agent_cat" <<'PY'
from pathlib import Path
import sys
source, output, work, upstream_input, upstream, agent_input, agent, root, runtime = map(Path, sys.argv[1:])
text = source.read_text()
for path, label in [
    (work, "<WORK>"),
    (upstream_input, "<TASKMASTER_INPUT>"),
    (upstream, "<TASKMASTER_SOURCE>"),
    (agent_input, "<AGENT_CAT_INPUT>"),
    (agent, "<AGENT_CAT_SOURCE>"),
    (runtime, "<AGENT_CAT_RUNTIME>"),
    (root, "<WORKFLOW_SOURCE>"),
]:
    for spelling in sorted({str(path), str(path.resolve())}, key=len, reverse=True):
        text = text.replace(spelling, label)
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(text)
PY
fi

python3 - \
  "$staged_certificate" "$staged_manifest" "$staged_report" "$plan" \
  "$adapter_choice" "$bill_fresh" "$bill_memo" "$producer_revision" \
  "$producer_tree" "$runtime_revision" "$runtime_tree" "$root" <<'PY'
from pathlib import Path
import hashlib, json, sys
(
    output,
    manifest,
    report,
    plan,
    adapter,
    bill_fresh,
    bill_memo,
    producer_revision,
    producer_tree,
    runtime_revision,
    runtime_tree,
    root,
) = sys.argv[1:]
output, manifest, report, plan, root = map(Path, [output, manifest, report, plan, root])
data = json.loads(manifest.read_text())
plan_data = json.loads(plan.read_text())
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
helpers = [
    ("Workflow source", root / "src/Workflows/Taskmaster.hs"),
    ("Evidence argv module", root / "src/Workflows/Evidence.hs"),
    ("Evidence collector", root / "tools/taskmaster-evidence.py"),
    ("Stage validator/renderer", root / "tools/wf-taskmaster-stage"),
    ("Fixture adapter", root / "tools/taskmaster-fixture.py"),
    ("Source driver", root / "tools/taskmaster-framework.sh"),
]
helper_lines = "\n".join(f"- {name} SHA-256: `{sha(path)}`" for name, path in helpers)
text = f"""# Taskmaster framework representative run

- Status: complete
- Adapter mode: `{adapter}`
- Taskmaster revision: `{data['repositories']['taskmaster']['revision']}`
- Taskmaster tree: `{data['repositories']['taskmaster']['tree']}`
- Analyzed agent-cat revision: `{data['repositories']['agent-cat']['revision']}`
- Analyzed agent-cat tree: `{data['repositories']['agent-cat']['tree']}`
- Runtime agent-cat revision: `{runtime_revision}`
- Runtime agent-cat tree: `{runtime_tree}`
- Workflow producer revision: `{producer_revision}`
- Workflow producer tree: `{producer_tree}`
- Evidence manifest SHA-256: `{sha(manifest)}`
- Generated report SHA-256: `{sha(report)}`
{helper_lines}
- Static level/size/asks: `{plan_data['level']}` / `{plan_data['size']}` / `{plan_data['askNodes']}`
- Static cost: min `{plan_data['minFold']}`, max `{plan_data['maxFold']}`, paths `{plan_data['paths']}`
- Executed bill: fresh `{bill_fresh}`, memo `{bill_memo}`

The source revisions identify what was analyzed and which agent-cat implementation
executed the workflow. The content hashes identify the uncommitted workflow bundle
that produced this representative artifact. Fixture mode stores no model transcript
and uses no paid service; a live ACP smoke is optional and separate.
"""
output.write_text(text)
PY

if [ -n "$transcript_out" ]; then
  mv "$transcript_tmp" "$transcript_out"
  transcript_tmp=
fi
mv "$staged_manifest" "$output_dir/taskmaster-evidence-manifest.json"
mv "$staged_report" "$output_dir/taskmaster-agent-cat-framework.generated.md"
mv "$staged_certificate" "$output_dir/taskmaster-framework-run.md"
rm -rf "$publish_dir"
publish_dir=
rm -f "$output_dir/taskmaster-framework-incomplete.json"

echo "taskmaster: report: $output_dir/taskmaster-agent-cat-framework.generated.md"
echo "taskmaster: evidence: $output_dir/taskmaster-evidence-manifest.json"
echo "taskmaster: certificate: $output_dir/taskmaster-framework-run.md"
