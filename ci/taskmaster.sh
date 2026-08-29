#!/usr/bin/env bash
# Offline production gate for the Taskmaster evidence-to-design workflow.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
root=$(git rev-parse --show-toplevel)
manifest="$root/doc/research/taskmaster-evidence-manifest.json"
golden="$root/doc/research/taskmaster-agent-cat-framework.generated.md"
certificate="$root/doc/research/taskmaster-framework-run.md"
adapter="$root/tools/taskmaster-fixture.py"
work=$(mktemp -d "${TMPDIR:-/tmp}/workflow-taskmaster.XXXXXX")
export PYTHONPYCACHEPREFIX="$work/pycache"
trap 'rm -rf "$work"' EXIT

python3 test/taskmaster_evidence_test.py
python3 test/taskmaster_stage_test.py
python3 -m py_compile \
  tools/taskmaster-evidence.py \
  tools/taskmaster-fixture.py \
  tools/wf-taskmaster-stage

nix develop path:./. -c cabal build all >/dev/null
bin=$(nix develop path:./. -c cabal list-bin exe:wf 2>/dev/null | tail -1)

run_mode() {
  mode=$1
  expected_bill=$2
  mkdir "$work/$mode"
  PATH="$root/tools:$PATH" TASKMASTER_FIXTURE_MODE="$mode" \
    "$bin" run taskmaster --engine acp --adapter "$adapter" \
    --scratch "$work/$mode" --input-file "evidence=$manifest" \
    >"$work/$mode.txt" 2>&1
  test -s "$work/$mode/taskmaster-agent-cat-framework.md"
  grep -Fq "    billFresh   $expected_bill" "$work/$mode.txt"
  grep -Fq "    billMemo    $expected_bill" "$work/$mode.txt"
}

run_mode valid 14
for stage in inventory design audit revision; do
  run_mode "repair-$stage" 16
  cmp "$work/valid/taskmaster-agent-cat-framework.md" \
    "$work/repair-$stage/taskmaster-agent-cat-framework.md"
done
cmp "$work/valid/taskmaster-agent-cat-framework.md" "$golden"

python3 - "$manifest" "$golden" "$certificate" "$root" <<'PY'
from pathlib import Path
import hashlib, json, re, sys
manifest_path, report_path, certificate_path, root = map(Path, sys.argv[1:])
manifest = json.loads(manifest_path.read_text())
report = report_path.read_text()
certificate = certificate_path.read_text()
categories = set(manifest["requiredCategories"]) - {"license-provenance"}
assert manifest["repositories"]["taskmaster"]["revision"] == "c0c98d367c55296bfe69e65680625b6db437af02"
agent_revision = manifest["repositories"]["agent-cat"]["revision"]
assert f"Analyzed agent-cat revision: `{agent_revision}`" in certificate
assert re.search(r"(?m)^- Runtime agent-cat revision: `[0-9a-f]{40}`$", certificate)
assert len(manifest["evidence"]) == 34
assert max(record["end"] - record["start"] + 1 for record in manifest["evidence"]) <= 60
assert len(re.findall(r"(?m)^## ", report)) == 11
assert len(re.findall(r"(?m)^### Stage ", report)) == 7
assert len(re.findall(r"(?m)^- \*\*Risk:\*\*", report)) == 6
assert len(re.findall(r"(?m)^- \*\*Recommendation — rejected:\*\*", report)) == 5
assert len(re.findall(r"(?m)^\| R\d+ \|", report)) == 10
mapping_rows = {
    category
    for category in categories
    if any(line.startswith(f"| {category} |") for line in report.splitlines())
}
assert mapping_rows == categories
assert "- **Interpretation — collaboration:**" in report
assert "- **Interpretation — tags-workstreams:**" in report
assert set(re.findall(r"/blob/([0-9a-f]{40})/", report)) == {
    manifest["repositories"]["taskmaster"]["revision"]
}
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(manifest_path) in certificate
assert sha(report_path) in certificate
helper_paths = {
    "Workflow source": root / "src/Workflows/Taskmaster.hs",
    "Evidence argv module": root / "src/Workflows/Evidence.hs",
    "Evidence collector": root / "tools/taskmaster-evidence.py",
    "Stage validator/renderer": root / "tools/wf-taskmaster-stage",
    "Fixture adapter": root / "tools/taskmaster-fixture.py",
    "Source driver": root / "tools/taskmaster-framework.sh",
}
for label, path in helper_paths.items():
    assert f"- {label} SHA-256: `{sha(path)}`" in certificate
for retained in [manifest_path.read_text(), report, certificate]:
    assert "/Users/" not in retained and "/var/folders/" not in retained
    assert "BEGIN PRIVATE KEY" not in retained
PY

check_exhaustion() {
  stage=$1
  fresh=$2
  memo=$3
  mode="fail-$stage"
  mkdir "$work/$mode"
  PATH="$root/tools:$PATH" TASKMASTER_FIXTURE_MODE="$mode" \
    "$bin" run taskmaster --engine acp --adapter "$adapter" \
    --scratch "$work/$mode" --input-file "evidence=$manifest" \
    >"$work/$mode.txt" 2>&1
  test ! -e "$work/$mode/taskmaster-agent-cat-framework.md"
  test "$(cat "$work/$mode/taskmaster-framework-incomplete.json")" = \
    "{\"stage\":\"$stage\",\"status\":\"INCOMPLETE\"}"
  grep -Fq "    billFresh   $fresh" "$work/$mode.txt"
  grep -Fq "    billMemo    $memo" "$work/$mode.txt"
}

check_exhaustion inventory 5 4
check_exhaustion design 8 7
check_exhaustion audit 11 10
check_exhaustion revision 14 13

# Certificate generation happens after every expensive stage. A late failure must
# leave the previous complete bundle intact and publish only an incomplete marker.
source_repo="$work/taskmaster-source"
mkdir "$source_repo"
git -C "$source_repo" init --quiet
python3 - "$source_repo" <<'PY'
from pathlib import Path
import importlib.util, sys

root = Path(sys.argv[1])
module_path = Path.cwd() / "tools" / "taskmaster-evidence.py"
spec = importlib.util.spec_from_file_location("taskmaster_evidence", module_path)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)

widths = {}
for evidence in module.SPECS:
    if evidence.repository == "taskmaster":
        widths[evidence.path] = max(widths.get(evidence.path, 0), evidence.end)
for relative, width in widths.items():
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(f"{relative} fixture line {line}\n" for line in range(1, width + 1)))
PY
git -C "$source_repo" add .
git -C "$source_repo" -c user.name=Fixture -c user.email=fixture@example.invalid \
  -c commit.gpgsign=false commit --quiet -m fixture
source_revision=$(git -C "$source_repo" rev-parse HEAD)
agent_revision=$(git -C "$root/../agent-cat" rev-parse HEAD)

preserved="$work/preserved"
mkdir "$preserved"
for artifact in taskmaster-evidence-manifest.json \
  taskmaster-agent-cat-framework.generated.md taskmaster-framework-run.md; do
  printf 'previous %s\n' "$artifact" >"$preserved/$artifact"
done

fail_bin="$work/fail-bin"
mkdir "$fail_bin"
real_python=$(command -v python3)
cat >"$fail_bin/python3" <<EOF
#!/bin/sh
case "\${2-}" in
  */taskmaster-framework-run.md) exit 86 ;;
esac
exec "$real_python" "\$@"
EOF
chmod +x "$fail_bin/python3"

set +e
PATH="$fail_bin:$PATH" \
  TASKMASTER_UPSTREAM="$source_repo" \
  TASKMASTER_UPSTREAM_REVISION="$source_revision" \
  TASKMASTER_AGENT_CAT="$root/../agent-cat" \
  TASKMASTER_AGENT_CAT_REVISION="$agent_revision" \
  TASKMASTER_ADAPTER=fixture \
  TASKMASTER_OUTPUT_DIR="$preserved" \
  tools/taskmaster-framework.sh >"$work/publication.txt" 2>&1
publication_status=$?
set -e
[ "$publication_status" -ne 0 ]
for artifact in taskmaster-evidence-manifest.json \
  taskmaster-agent-cat-framework.generated.md taskmaster-framework-run.md; do
  test "$(cat "$preserved/$artifact")" = "previous $artifact"
done
grep -Fq '"phase": "publish"' "$preserved/taskmaster-framework-incomplete.json"
test -z "$(find "$preserved" -maxdepth 1 -name '.taskmaster-publish.*' -print -quit)"

printf '%s\n' \
  'ci/taskmaster: 25 unit checks, retained artifacts, all repair/exhaustion paths, publication rollback passed'
