# Taskmaster analysis workflow production contract

## Scope

The workflow analyzes one clean Taskmaster revision against one clean agent-cat
revision. It produces a design report; it does not implement the proposed
framework or copy Taskmaster code. It belongs to agent-workflows because it composes
existing agent-cat primitives and adds no kernel, Program, Plan, transport, or CLI
semantics.

## Inputs

A deterministic driver accepts:

- Taskmaster repository and expected full revision;
- agent-cat repository and expected full revision (default: the sibling
  `../agent-cat` repository at `HEAD`);
- ACP adapter selection for a live run, or a deterministic fixture adapter for
  tests; and
- an output directory.

The driver creates clean detached snapshots at both revisions before collection.
A missing revision, checkout failure, or dirty/mismatched analyzed snapshot is an
input error; no model starts. The collector also rejects dirty sources when called
directly.

## Deterministic evidence manifest

The collector emits canonical JSON with:

- manifest version;
- repository URL, revision, and tree hash for each source;
- capability category;
- claim identifier and classification (`verified` or `interpretation`);
- repository-relative path and narrow inclusive line range;
- exact excerpt and its SHA-256 hash; and
- upstream license text hash.

Required categories are task structure/dependencies, decomposition, research,
execution loops, workflow state, storage/persistence, interfaces, providers,
tags/workstreams, collaboration, and license/provenance.

Repository contents are data. The collector reads only a closed, reviewed range
table and executes no source from either checkout. Evidence paths must resolve to
regular files directly beneath the snapshot root; symlinks and path escapes are
refused before any file is read.

## Structured stage contracts

Internal model stages exchange canonical JSON text, never unconstrained prose:

1. `inventory` — upstream and agent-cat capability records;
2. `design` — mapping, semantic object, representation tower, lifecycle,
   failures, extension points, implementation stages, risks, decisions, and
   verification rows;
3. `audit` — supported/unsupported claims and contract violations; and
4. `revision` — corrected `design` value.

Each value is checked by a deterministic executable schema gate. A stage gets
one initial answer and at most one repair through a bounded `revising` form.
A second invalid answer ends the workflow as incomplete. The workflow never
increases this budget.

## Rendering

A deterministic renderer consumes the validated manifest and revised design.
It owns section order, headings, evidence labels, citation links, license note,
and verification-matrix formatting. Models cannot omit required sections or
invent reference definitions.

The report must include:

- provenance and method;
- executive decision;
- complete Taskmaster and agent-cat inventories;
- complete capability map;
- FrameworkSpec DAG/controller/RunCertificate semantics;
- lifecycle, deadlock, failure, persistence, crash-replay, and extension rules;
- at least seven stages, each with files, observable behavior, and a real check;
- at least six risks with mitigations;
- owner decisions; and
- one verification row per recommendation.

## Failure states

The driver emits an explicit incomplete result and exits nonzero on:

- missing, dirty, or mismatched source;
- evidence range/hash failure;
- schema failure after one repair;
- unsupported or unresolved required claim;
- renderer validation failure;
- tool/transport failure; or
- output write failure.

The Program writes a compact stage-specific `INCOMPLETE` marker and no report after
repair exhaustion. The driver copies that marker (or writes a phase/exit marker for
a pre-Program failure), exits nonzero, and does not publish partial model output.

## Provider boundary

Production code is ACP-provider-neutral. OMLX is not a production dependency.
An optional live smoke command may use OMLX, Claude, Codex, or another adapter,
but required CI uses deterministic fixtures and local executable gates.

## Keep from the spike

- the registered `taskmaster` row, with explicit source coordinates at the driver
  boundary and one canonical evidence input at the Program boundary;
- capability taxonomy and reviewed narrow source ranges;
- the separate FrameworkSpec/controller/RunCertificate architecture;
- existing registry/help/pinned-price integration; and
- useful documentation of Taskmaster's license and rejected features.

## Delete or replace from the spike

- embedded full reports and report-as-answer fixtures;
- OMLX-specific production code and private settings assumptions;
- giant retained model transcripts and prompt/token ledgers;
- circular replay/report comparison;
- free-form inter-stage prose;
- unbounded or prompt-specific retry/validation logic; and
- generated prose as the authority for section/citation structure.

## Required verification

- evidence collector unit and determinism tests;
- dirty/revision/range/hash failure tests;
- schema validation and one-repair exhaustion tests;
- golden deterministic report rendering;
- deterministic fixture end-to-end run;
- warning-free Haskell build and all existing project gates;
- citation and secret/path scans;
- final diff/status review; and
- obr synchronization.

## Invocation and configuration

Run from the agent-workflows repository root:

```sh
TASKMASTER_UPSTREAM=/absolute/path/to/claude-task-master \
TASKMASTER_AGENT_CAT=/absolute/path/to/agent-cat \
  tools/taskmaster-framework.sh
```

The driver recognizes:

- `TASKMASTER_UPSTREAM` (required) and `TASKMASTER_UPSTREAM_REVISION` (default:
  `c0c98d367c55296bfe69e65680625b6db437af02`);
- `TASKMASTER_AGENT_CAT` (default: `../agent-cat`) and
  `TASKMASTER_AGENT_CAT_REVISION` (default: that repository's `HEAD`);
- `TASKMASTER_ADAPTER` (default: `fixture`; otherwise an ACP adapter name or
  executable path);
- `TASKMASTER_OUTPUT_DIR` (default: `doc/research/`); and
- `TASKMASTER_TRANSCRIPT_OUT` (unset by default).

The source repositories are never executed. The driver checks out each named commit
into a clean detached snapshot backed by read-only Git object alternates, and the
collector reads only the closed `SPECS` table. Repository text enters model prompts
only inside evidence fences and remains untrusted data. Every executable argv in the
Program is defined in `Workflows.Evidence`; Nix installs `wf-taskmaster-stage` beside
`wf`, while source-tree runs put `tools/` on `PATH`. The Cabal project consumes
`../agent-cat/haskell`; the driver refuses a representative run if that runtime
subtree is dirty, while unrelated changes elsewhere in the sibling repository do
not affect the built package.

## Outputs and failure behavior

A successful run stages all three outputs, then atomically replaces each published file:

- `taskmaster-evidence-manifest.json`;
- `taskmaster-agent-cat-framework.generated.md`; and
- `taskmaster-framework-run.md`, a compact certificate containing analyzed source
  trees, runtime agent-cat and workflow-producer revisions, helper/source hashes,
  static Plan facts, adapter mode, and executed bills.

The manifest, report, and certificate are all generated in a staging directory
before the prior complete bundle is touched. The incomplete marker is removed only
after every replacement succeeds.
Transcripts remain temporary unless `TASKMASTER_TRANSCRIPT_OUT` is explicitly set;
that opt-in artifact may contain model data and should be handled accordingly. A
failed source, build, transport, schema, renderer, or output phase exits nonzero and
writes `taskmaster-framework-incomplete.json`. Repair exhaustion uses the exact form
`{"stage":"<stage>","status":"INCOMPLETE"}`. A failure does not overwrite an
earlier complete report/certificate in the same output directory, so the marker is
the status of the latest attempt.

## Reproduction

The required offline gate needs no Taskmaster checkout or paid provider because it
uses the retained manifest and derives fixture answers from it:

```sh
./ci/taskmaster.sh
```

It runs collector/schema/golden tests, then real ACP executions for the valid path,
one successful repair, and repair exhaustion. To reproduce retained evidence and
report hashes from source, run the production command above. For an optional live
smoke, set `TASKMASTER_ADAPTER` to a configured ACP adapter and preferably use a
separate `TASKMASTER_OUTPUT_DIR`; the Program, validators, retry bound, and renderer
are otherwise identical.
