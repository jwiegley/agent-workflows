#!/usr/bin/env python3
"""Collect canonical, pinned evidence for the Taskmaster analysis workflow."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

MANIFEST_VERSION = 1
MAX_EXCERPT_LINES = 60
REQUIRED_CATEGORIES = {
    "task-structure-dependencies",
    "decomposition",
    "research",
    "execution-loops",
    "workflow-state",
    "storage-persistence",
    "interfaces",
    "providers",
    "tags-workstreams",
    "collaboration",
    "license-provenance",
}


@dataclass(frozen=True)
class EvidenceSpec:
    claim_id: str
    category: str
    repository: str
    path: str
    start: int
    end: int
    claim: str
    classification: str = "verified"


SPECS = (
    EvidenceSpec("tm-task", "task-structure-dependencies", "taskmaster", "packages/tm-core/src/common/types/index.ts", 131, 176, "Tasks carry dependencies and one level of subtasks."),
    EvidenceSpec("tm-ready", "task-structure-dependencies", "taskmaster", "packages/tm-core/src/modules/tasks/utils/task-filters.ts", 121, 143, "Ready tasks have actionable status and completed dependencies."),
    EvidenceSpec("tm-expand", "decomposition", "taskmaster", "packages/tm-core/src/modules/integration/services/task-expansion.service.ts", 119, 178, "Expansion builds task context and posts to the subtask-generation endpoint."),
    EvidenceSpec("tm-prd", "decomposition", "taskmaster", "scripts/modules/task-manager/parse-prd/parse-prd.js", 64, 100, "PRD parsing builds prompts, processes generated tasks, and saves them."),
    EvidenceSpec("tm-research", "research", "taskmaster", "mcp-server/src/core/direct-functions/research.js", 108, 135, "Research passes task, file, and project context to the shared research function."),
    EvidenceSpec("tm-loop", "execution-loops", "taskmaster", "packages/tm-core/src/modules/loop/services/loop.service.ts", 129, 175, "Loop execution is bounded by configured iterations and explicit endings."),
    EvidenceSpec("tm-loop-markers", "execution-loops", "taskmaster", "packages/tm-core/src/modules/loop/services/loop.service.ts", 289, 302, "Loop output recognizes complete and blocked markers."),
    EvidenceSpec("tm-workflow-phases", "workflow-state", "taskmaster", "packages/tm-core/src/modules/workflow/types.ts", 4, 29, "Workflow and TDD phases are explicit state data with task context."),
    EvidenceSpec("tm-workflow-events", "workflow-state", "taskmaster", "packages/tm-core/src/modules/workflow/types.ts", 63, 96, "Workflow state and transition events are explicit types."),
    EvidenceSpec("tm-workflow-persist", "workflow-state", "taskmaster", "packages/tm-core/src/modules/workflow/orchestrators/workflow-orchestrator.ts", 444, 470, "Workflow transitions can persist state automatically."),
    EvidenceSpec("tm-file-store", "storage-persistence", "taskmaster", "packages/tm-core/src/modules/storage/adapters/file-storage/file-operations.ts", 69, 105, "File updates use atomic writes and cross-process locking."),
    EvidenceSpec("tm-mcp", "interfaces", "taskmaster", "mcp-server/src/tools/tool-registry.js", 59, 104, "The MCP registry exposes task, workflow, research, and tag tools."),
    EvidenceSpec("tm-provider-core", "providers", "taskmaster", "packages/tm-core/src/modules/ai/interfaces/ai-provider.interface.ts", 115, 171, "The AI-provider interface owns generation, model selection, and availability."),
    EvidenceSpec("tm-provider-lifecycle", "providers", "taskmaster", "packages/tm-core/src/modules/ai/interfaces/ai-provider.interface.ts", 173, 207, "The AI-provider interface exposes capabilities, credentials, initialization, and cleanup."),
    EvidenceSpec("tm-tags", "tags-workstreams", "taskmaster", "packages/tm-core/src/common/types/index.ts", 204, 208, "TaskTag associates a name, task identifiers, and metadata."),
    EvidenceSpec("tm-team", "collaboration", "taskmaster", "packages/tm-core/src/modules/integration/services/export.service.ts", 1464, 1523, "Authenticated team invitations carry email addresses and roles."),
    EvidenceSpec("tm-license", "license-provenance", "taskmaster", "LICENSE", 1, 25, "Taskmaster is MIT plus Commons Clause; Sell is defined by that file."),
    EvidenceSpec("ac-dialogue", "task-structure-dependencies", "agent-cat", "README.md", 1, 15, "agent-cat gives workflows a denotational meaning and separates Lean from Haskell at RawProgram."),
    EvidenceSpec("ac-plan", "task-structure-dependencies", "agent-cat", "haskell/src/Agentic/Plan.hs", 675, 701, "Plan is a typed five-form representation."),
    EvidenceSpec("ac-function", "decomposition", "agent-cat", "haskell/src/Agentic/Workflow.hs", 1814, 1839, "A function has a straight-line workflow body over typed parameters."),
    EvidenceSpec("ac-call", "decomposition", "agent-cat", "haskell/src/Agentic/Workflow.hs", 1943, 1957, "Value and statement calls reuse function questions at the call site."),
    EvidenceSpec("ac-intent", "research", "agent-cat", "haskell/src/Agentic/Plan.hs", 351, 394, "Request intent distinguishes consult, observe, and effect below meaning."),
    EvidenceSpec("ac-revision-outcome", "execution-loops", "agent-cat", "haskell/src/Agentic/Workflow.hs", 1557, 1608, "A bounded revision has an explicit bound and settled or unsettled outcome."),
    EvidenceSpec("ac-revision-loop", "execution-loops", "agent-cat", "haskell/src/Agentic/Workflow.hs", 1610, 1662, "revising couples review, amendment, bound, and both terminal arms."),
    EvidenceSpec("ac-revision-ending", "execution-loops", "agent-cat", "haskell/src/Agentic/Workflow.hs", 1673, 1698, "The three-way bounded form adds an explicit abandoned outcome."),
    EvidenceSpec("ac-revision-on", "execution-loops", "agent-cat", "haskell/src/Agentic/Workflow.hs", 1700, 1745, "revisingOn maps verdict tags to settle, amend, or abandon."),
    EvidenceSpec("ac-stages", "workflow-state", "agent-cat", "haskell/src/Agentic/Workflow.hs", 784, 823, "The authoring block is indexed by open/result, review, amending, and body stages."),
    EvidenceSpec("ac-exec", "storage-persistence", "agent-cat", "haskell/src/Agentic/Exec.hs", 32, 50, "Exec returns annotated per-Plan-node trace evidence and derives bills from it."),
    EvidenceSpec("ac-cli", "interfaces", "agent-cat", "haskell/src/Agentic/Cli.hs", 441, 478, "Registry rows couple programs with documentation and scripted fixtures."),
    EvidenceSpec("ac-route-table", "providers", "agent-cat", "haskell/src/Agentic/Route.hs", 260, 293, "Routes select a backend from the question's model axis or the default."),
    EvidenceSpec("ac-route-world", "providers", "agent-cat", "haskell/src/Agentic/Route.hs", 319, 354, "Runtime routing substitutes a backend without changing Plan or trace structure."),
    EvidenceSpec("ac-scope", "tags-workstreams", "agent-cat", "Agentic/Scope.lean", 3, 31, "Scope is semantic binding policy, not Taskmaster-style workstream metadata.", "interpretation"),
    EvidenceSpec("ac-panel", "collaboration", "agent-cat", "haskell/src/Agentic/Workflow.hs", 687, 718, "Panels provide authored fan-out, not multi-user collaboration.", "interpretation"),
    EvidenceSpec("ac-certify", "license-provenance", "agent-cat", "Agentic/Core/Certify.lean", 154, 182, "Certification is a decidable per-run warrant over Plan, table, and value."),
)


class EvidenceError(RuntimeError):
    pass


def run_git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()


def repository_identity(repo: Path, expected_revision: str) -> dict[str, str]:
    if not (repo / ".git").exists():
        raise EvidenceError(f"not a Git checkout: {repo}")
    actual = run_git(repo, "rev-parse", "HEAD^{commit}")
    if actual != expected_revision:
        raise EvidenceError(f"revision mismatch for {repo}: expected {expected_revision}, found {actual}")
    dirty = run_git(repo, "status", "--porcelain")
    if dirty:
        raise EvidenceError(f"checkout is dirty: {repo}")
    return {
        "revision": actual,
        "tree": run_git(repo, "rev-parse", "HEAD^{tree}"),
    }


def collect_excerpt(repo: Path, spec: EvidenceSpec) -> dict[str, object]:
    root = repo.resolve()
    path = root / spec.path
    try:
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise EvidenceError(f"missing evidence path: {spec.repository}:{spec.path}") from error
    try:
        resolved.relative_to(root)
    except ValueError as error:
        raise EvidenceError(f"evidence path escapes checkout: {spec.repository}:{spec.path}") from error
    if resolved != path:
        raise EvidenceError(f"symlinked evidence path: {spec.repository}:{spec.path}")
    if not resolved.is_file():
        raise EvidenceError(f"missing evidence path: {spec.repository}:{spec.path}")
    width = spec.end - spec.start + 1
    if width > MAX_EXCERPT_LINES:
        raise EvidenceError(
            f"broad evidence range {spec.repository}:{spec.path}:L{spec.start}-L{spec.end}; "
            f"maximum is {MAX_EXCERPT_LINES} lines"
        )
    lines = resolved.read_text(errors="strict").splitlines()
    if not (1 <= spec.start <= spec.end <= len(lines)):
        raise EvidenceError(
            f"invalid range {spec.repository}:{spec.path}:L{spec.start}-L{spec.end}; file has {len(lines)} lines"
        )
    excerpt = "\n".join(lines[spec.start - 1 : spec.end]) + "\n"
    return {
        "id": spec.claim_id,
        "category": spec.category,
        "classification": spec.classification,
        "claim": spec.claim,
        "repository": spec.repository,
        "path": spec.path,
        "start": spec.start,
        "end": spec.end,
        "excerpt": excerpt,
        "excerptSha256": hashlib.sha256(excerpt.encode()).hexdigest(),
    }


def validate_categories(records: Iterable[dict[str, object]]) -> None:
    present = {str(record["category"]) for record in records}
    missing = sorted(REQUIRED_CATEGORIES - present)
    if missing:
        raise EvidenceError(f"missing evidence categories: {', '.join(missing)}")


def canonical_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"


def collect_manifest(
    upstream: Path,
    upstream_revision: str,
    local: Path,
    local_revision: str,
    specs: Iterable[EvidenceSpec] = SPECS,
) -> dict[str, object]:
    identities = {
        "taskmaster": {
            "url": "https://github.com/eyaltoledano/claude-task-master",
            **repository_identity(upstream, upstream_revision),
        },
        "agent-cat": {
            "url": "https://github.com/jwiegley/agent-cat",
            **repository_identity(local, local_revision),
        },
    }
    roots = {"taskmaster": upstream, "agent-cat": local}
    records = [collect_excerpt(roots[spec.repository], spec) for spec in specs]
    validate_categories(records)
    return {
        "version": MANIFEST_VERSION,
        "repositories": identities,
        "requiredCategories": sorted(REQUIRED_CATEGORIES),
        "evidence": records,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--upstream-revision", required=True)
    parser.add_argument("--local", type=Path, required=True)
    parser.add_argument("--local-revision", required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest = collect_manifest(
            args.upstream,
            args.upstream_revision,
            args.local,
            args.local_revision,
        )
    except (EvidenceError, OSError, subprocess.CalledProcessError, UnicodeError) as error:
        raise SystemExit(f"taskmaster-evidence: {error}") from error
    content = canonical_json(manifest)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_name(args.output.name + ".tmp")
    temporary.write_text(content)
    temporary.replace(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
