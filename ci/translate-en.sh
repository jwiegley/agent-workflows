#!/usr/bin/env bash
# Native translation procedure and package gate. No provider or network calls.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
: "${TRANSLATE_TOOL_SOURCE:?Set TRANSLATE_TOOL_SOURCE to the authoritative translate-tool checkout}"
work=$(mktemp -d "${TMPDIR:-/tmp}/workflow-translate-en.XXXXXX")
trap 'rm -rf "$work"' EXIT
export PYTHONDONTWRITEBYTECODE=1
export XDG_CONFIG_HOME="$work/config"
mkdir -p "$XDG_CONFIG_HOME"

python3 tools/sync-translate-en.py "$TRANSLATE_TOOL_SOURCE" --check
python3 test/translate_en_stage_test.py
cabal build exe:wf
cabal test translate-en-flow --test-show-details=direct

if [[ $# -eq 0 ]]; then
  wf=$(cabal list-bin exe:wf)
  helper_path="$root/tools:$(dirname "$(command -v python3)")"
  export agentic_datadir="$root/../agent-cat"
elif [[ $# -eq 1 ]]; then
  wf=$1
  helper_path=$(dirname "$(command -v python3)")
  unset agentic_datadir
else
  echo 'usage: ci/translate-en.sh [INSTALLED_WF_BINARY]' >&2
  exit 2
fi

"$wf" plan translate-en --json --input-arg file= --input-arg text= > "$work/plan.json"
python3 - "$work/plan.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    plan = json.load(stream)
assert plan["result"] == "text"
assert plan["inputs"] == [{"name": "file", "source": "command-tail"}, {"name": "text", "source": "stdin"}]
assert plan["pins"] == ["translate-en", "translate-en-back", "translate-en-verify"]
assert plan["runFacts"] == ["run.engine", "run.routes"]
assert plan["paths"] == 129 and plan["maxFold"] == 3205
PY

"$wf" run translate-en --scripted --input-arg file= --input-arg text= > "$work/scripted.log" 2>&1
grep -Fq 'SCRIPTED rehearsal complete. No translation artifact was written.' "$work/scripted.log"

# The installed wrapper must find its helper even without the caller's PATH.
# ACP's built-in stub is local; the empty source fails before any model question.
if PATH="$helper_path" "$wf" run translate-en --engine acp --adapter stub \
    --scratch "$work/runtime" --input-arg file= --input-arg text= > "$work/preflight.log" 2>&1; then
  echo 'empty translation input unexpectedly succeeded' >&2
  exit 1
fi
if ! grep -Fq 'supply exactly one nonempty file path or pasted text' "$work/preflight.log"; then
  cat "$work/preflight.log" >&2
  exit 1
fi
if grep -q 'TRANSLATE_EN_MODEL' "$work/preflight.log"; then
  echo 'empty input reached a model' >&2
  exit 1
fi
if [[ $# -eq 0 ]]; then
  helper="$root/tools/wf-translate-stage"
else
  helper="$(dirname "$wf")/wf-translate-stage"
fi
python3 - "$helper" <<'PY'
import json
import subprocess
import sys
context = {"phase": "brief", "units": [{"id": "u1", "source": "ای دوست"}]}
for candidate, expected in [("O friend", 0), ("ای دوست", 1)]:
    payload = "TRANSLATE_EN accept draft\n" + json.dumps(context) + "\n" + json.dumps({"units": [{"id": "u1", "text": candidate}]})
    result = subprocess.run([sys.argv[1], "accept", "draft"], input=payload, text=True, capture_output=True, check=False)
    assert result.returncode == expected, result.stdout + result.stderr
    if expected:
        assert "English candidate retains" in result.stderr, result.stderr
PY
printf '%s\n' 'translate-en: source assets, native flows, catalogue, rehearsal and packaged-helper preflight passed'
