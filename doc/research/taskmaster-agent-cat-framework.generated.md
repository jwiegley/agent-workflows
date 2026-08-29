# Taskmaster concepts for an agent-cat workflow framework

## 1. Status and provenance

- **Verified:** Taskmaster `c0c98d367c55296bfe69e65680625b6db437af02` / tree `6c7447184c0a92476ed6021373a55bb06ac92ca1`.
- **Verified:** agent-cat `a88dc85935032fd760c2cd489e05b34c2d9736dd` / tree `c14caddcc9647d4cfacbb2f48840374b393240a9`.
- **Verified:** Sources were clean before collection; evidence excerpts and hashes are retained in the manifest.
- **Recommendation:** Re-derive concepts, retain provenance, and copy no implementation code.

## 2. Executive decision

- **Recommendation:** Build a finite FrameworkSpec DAG, separate Controller, RunCertificate, repository adapter, proposal workflows, and thin Registry/Cli integration without changing Plan.

## 3. Verified Taskmaster capability inventory

- **Verified — collaboration:** Authenticated team invitations carry email addresses and roles. — [tm-team](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/integration/services/export.service.ts#L1464-L1523)
- **Verified — decomposition:** Expansion builds task context and posts to the subtask-generation endpoint; PRD parsing builds prompts, processes generated tasks, and saves them. — [tm-expand](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/integration/services/task-expansion.service.ts#L119-L178), [tm-prd](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/scripts/modules/task-manager/parse-prd/parse-prd.js#L64-L100)
- **Verified — execution-loops:** Loop execution is bounded by configured iterations and explicit endings; Loop output recognizes complete and blocked markers. — [tm-loop](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/loop/services/loop.service.ts#L129-L175), [tm-loop-markers](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/loop/services/loop.service.ts#L289-L302)
- **Verified — interfaces:** The MCP registry exposes task, workflow, research, and tag tools. — [tm-mcp](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/mcp-server/src/tools/tool-registry.js#L59-L104)
- **Verified — providers:** The AI-provider interface owns generation, model selection, and availability; The AI-provider interface exposes capabilities, credentials, initialization, and cleanup. — [tm-provider-core](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/ai/interfaces/ai-provider.interface.ts#L115-L171), [tm-provider-lifecycle](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/ai/interfaces/ai-provider.interface.ts#L173-L207)
- **Verified — research:** Research passes task, file, and project context to the shared research function. — [tm-research](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/mcp-server/src/core/direct-functions/research.js#L108-L135)
- **Verified — storage-persistence:** File updates use atomic writes and cross-process locking. — [tm-file-store](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/storage/adapters/file-storage/file-operations.ts#L69-L105)
- **Verified — tags-workstreams:** TaskTag associates a name, task identifiers, and metadata. — [tm-tags](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/common/types/index.ts#L204-L208)
- **Verified — task-structure-dependencies:** Tasks carry dependencies and one level of subtasks; Ready tasks have actionable status and completed dependencies. — [tm-task](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/common/types/index.ts#L131-L176), [tm-ready](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/tasks/utils/task-filters.ts#L121-L143)
- **Verified — workflow-state:** Workflow and TDD phases are explicit state data with task context; Workflow state and transition events are explicit types; Workflow transitions can persist state automatically. — [tm-workflow-phases](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/types.ts#L4-L29), [tm-workflow-events](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/types.ts#L63-L96), [tm-workflow-persist](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/orchestrators/workflow-orchestrator.ts#L444-L470)

## 4. Existing agent-cat capability inventory

- **Interpretation — collaboration:** Panels provide authored fan-out, not multi-user collaboration. — `haskell/src/Agentic/Workflow.hs:L687-L718`
- **Verified — decomposition:** A function has a straight-line workflow body over typed parameters; Value and statement calls reuse function questions at the call site. — `haskell/src/Agentic/Workflow.hs:L1814-L1839`, `haskell/src/Agentic/Workflow.hs:L1943-L1957`
- **Verified — execution-loops:** A bounded revision has an explicit bound and settled or unsettled outcome; revising couples review, amendment, bound, and both terminal arms; The three-way bounded form adds an explicit abandoned outcome; revisingOn maps verdict tags to settle, amend, or abandon. — `haskell/src/Agentic/Workflow.hs:L1557-L1608`, `haskell/src/Agentic/Workflow.hs:L1610-L1662`, `haskell/src/Agentic/Workflow.hs:L1673-L1698`, `haskell/src/Agentic/Workflow.hs:L1700-L1745`
- **Verified — interfaces:** Registry rows couple programs with documentation and scripted fixtures. — `haskell/src/Agentic/Cli.hs:L441-L478`
- **Verified — providers:** Routes select a backend from the question's model axis or the default; Runtime routing substitutes a backend without changing Plan or trace structure. — `haskell/src/Agentic/Route.hs:L260-L293`, `haskell/src/Agentic/Route.hs:L319-L354`
- **Verified — research:** Request intent distinguishes consult, observe, and effect below meaning. — `haskell/src/Agentic/Plan.hs:L351-L394`
- **Verified — storage-persistence:** Exec returns annotated per-Plan-node trace evidence and derives bills from it. — `haskell/src/Agentic/Exec.hs:L32-L50`
- **Interpretation — tags-workstreams:** Scope is semantic binding policy, not Taskmaster-style workstream metadata. — `Agentic/Scope.lean:L3-L31`
- **Verified — task-structure-dependencies:** agent-cat gives workflows a denotational meaning and separates Lean from Haskell at RawProgram; Plan is a typed five-form representation. — `README.md:L1-L15`, `haskell/src/Agentic/Plan.hs:L675-L701`
- **Verified — workflow-state:** The authoring block is indexed by open/result, review, amending, and body stages. — `haskell/src/Agentic/Workflow.hs:L784-L823`

## 5. Capability map

| Capability | Decision | Owner | Rationale | Evidence |
|---|---|---|---|---|
| collaboration | DEFER | repository adapter metadata | **Interpretation:** Keep multi-user collaboration outside the minimum framework and preserve only optional ownership metadata. | [tm-team](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/integration/services/export.service.ts#L1464-L1523), `haskell/src/Agentic/Workflow.hs:L687-L718` |
| decomposition | ADAPT | proposal Registry programs | **Interpretation:** Let ordinary Registry programs propose validated graph patches; do not add decomposition primitives to Plan. | [tm-expand](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/integration/services/task-expansion.service.ts#L119-L178), [tm-prd](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/scripts/modules/task-manager/parse-prd/parse-prd.js#L64-L100), `haskell/src/Agentic/Workflow.hs:L1814-L1839`, `haskell/src/Agentic/Workflow.hs:L1943-L1957` |
| execution-loops | ADAPT | Agentic.Framework.Controller | **Interpretation:** Use Controller attempt bounds across runs and keep revising bounded within one run. | [tm-loop](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/loop/services/loop.service.ts#L129-L175), [tm-loop-markers](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/loop/services/loop.service.ts#L289-L302), `haskell/src/Agentic/Workflow.hs:L1557-L1608`, `haskell/src/Agentic/Workflow.hs:L1610-L1662`, `haskell/src/Agentic/Workflow.hs:L1673-L1698`, `haskell/src/Agentic/Workflow.hs:L1700-L1745` |
| interfaces | ADAPT | Registry and Agentic.Cli | **Interpretation:** Expose FrameworkSpec through thin Registry/Cli integration after semantic modules exist. | [tm-mcp](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/mcp-server/src/tools/tool-registry.js#L59-L104), `haskell/src/Agentic/Cli.hs:L441-L478` |
| providers | ADOPT | Agentic.Route and Agentic.Chains | **Interpretation:** Reuse existing model routing and fail-over without a framework-specific provider layer. | [tm-provider-core](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/ai/interfaces/ai-provider.interface.ts#L115-L171), [tm-provider-lifecycle](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/ai/interfaces/ai-provider.interface.ts#L173-L207), `haskell/src/Agentic/Route.hs:L260-L293`, `haskell/src/Agentic/Route.hs:L319-L354` |
| research | ADAPT | proposal Registry programs | **Interpretation:** Treat research as an evidence-producing program that may propose a graph patch behind a person gate. | [tm-research](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/mcp-server/src/core/direct-functions/research.js#L108-L135), `haskell/src/Agentic/Plan.hs:L351-L394` |
| storage-persistence | ADAPT | Agentic.Framework.Repository | **Interpretation:** Persist Controller state and certificate references atomically; keep ExecTrace as run evidence. | [tm-file-store](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/storage/adapters/file-storage/file-operations.ts#L69-L105), `haskell/src/Agentic/Exec.hs:L32-L50` |
| tags-workstreams | DEFER | repository adapter metadata | **Interpretation:** Defer workstream tags; reserve optional repository metadata without changing framework meaning. | [tm-tags](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/common/types/index.ts#L204-L208), `Agentic/Scope.lean:L3-L31` |
| task-structure-dependencies | ADAPT | Agentic.Framework.Spec | **Interpretation:** Represent cross-run dependencies in FrameworkSpec; leave single-run Plan sequencing unchanged. | [tm-task](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/common/types/index.ts#L131-L176), [tm-ready](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/tasks/utils/task-filters.ts#L121-L143), `README.md:L1-L15`, `haskell/src/Agentic/Plan.hs:L675-L701` |
| workflow-state | ADAPT | Agentic.Framework.Controller | **Interpretation:** Store node status in Controller state rather than adding operational status to Workflow stages. | [tm-workflow-phases](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/types.ts#L4-L29), [tm-workflow-events](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/types.ts#L63-L96), [tm-workflow-persist](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/orchestrators/workflow-orchestrator.ts#L444-L470), `haskell/src/Agentic/Workflow.hs:L784-L823` |

## 6. Minimum framework semantics and representation tower

- **Recommendation — principal object:** FrameworkSpec is a finite dependency DAG whose nodes name Registry rows, inputs, prerequisites, and completion contracts.
- **Recommendation — representation:** FrameworkSpec
- **Recommendation — representation:** Controller state
- **Recommendation — representation:** existing Plan and ExecTrace
- **Recommendation — representation:** RunCertificate
- **Recommendation — law:** the graph is finite and acyclic
- **Recommendation — law:** a node is ready exactly when every prerequisite has a completion certificate
- **Recommendation — law:** claiming one node does not change Plan meaning
- **Recommendation — law:** ExecTrace is immutable run evidence rather than controller state
- **Recommendation — law:** a node completes only after its completion contract yields a RunCertificate
- **Recommendation — boundary:** FrameworkSpec is a finite multi-run DAG outside Plan.
- **Recommendation — boundary:** Controller owns operational state and FrameworkSpec owns readiness.
- **Recommendation — boundary:** ExecTrace is run evidence; repository adapters own persistence.
- **Recommendation — boundary:** Plan, Workflow, Exec, Route, and Certify remain unchanged.
- **Recommendation — boundary:** Taskmaster JSON is not parsed into agent-cat Plan or RawProgram.

## 7. Lifecycle, failure, persistence, and extension boundaries

- **Recommendation — lifecycle:** validate every node reference and reject a cyclic graph before execution
- **Recommendation — lifecycle:** derive the ready set from prerequisite completion certificates
- **Recommendation — lifecycle:** atomically claim one ready node with a stable run identifier
- **Recommendation — lifecycle:** execute the node's Registry row through existing Route and Exec seams
- **Recommendation — lifecycle:** evaluate its completion contract against ExecTrace and Certify evidence
- **Recommendation — lifecycle:** record an immutable RunCertificate for an accepted result
- **Recommendation — lifecycle:** complete, retry, or block the node within its stored attempt bound
- **Recommendation — lifecycle:** persist Controller state and repeat, or report no-ready deadlock
- **Recommendation — failure:** invalid or dangling graph input refuses controller initialization
- **Recommendation — failure:** no ready node with unfinished work reports an explicit deadlock
- **Recommendation — failure:** transport failure records the attempt without completing the node
- **Recommendation — failure:** tool failure records the attempt without treating model prose as success
- **Recommendation — failure:** failed acceptance retains evidence but produces no completion certificate
- **Recommendation — failure:** retry exhaustion blocks the node and prevents further spending
- **Recommendation — failure:** persistence failure withholds acknowledgement of the state transition
- **Recommendation — failure:** crash replay uses the stable run identifier to avoid repeating accepted effects
- **Recommendation — extension:** Registry rows define executable node behavior without extending Plan
- **Recommendation — extension:** repository adapters add storage backends without changing graph meaning
- **Recommendation — extension:** completion contracts add acceptance policy without changing ExecTrace
- **Recommendation — extension:** proposal workflows may suggest patches but validation and person gates apply them

## 8. Ordered implementation plan with acceptance checks

### Stage 1: formal-spec
- **Files:** Agentic/Framework/Spec.lean
- **Behavior:** Reject cyclic and dangling graphs and derive readiness from completed prerequisites.
- **Check:** `lake build`

### Stage 2: haskell-spec
- **Files:** haskell/src/Agentic/Framework/Spec.hs
- **Behavior:** Decode the same graph shape and agree with checked Lean conformance vectors.
- **Check:** `nix develop path:./. -c cabal build all`

### Stage 3: controller
- **Files:** haskell/src/Agentic/Framework/Controller.hs
- **Behavior:** Atomically claim ready nodes, enforce attempt bounds, and report no-ready deadlock.
- **Check:** `./ci/tier0.sh`

### Stage 4: certificate
- **Files:** haskell/src/Agentic/Framework/Certificate.hs
- **Behavior:** Refuse completion unless accepted ExecTrace and Certify evidence produce a RunCertificate.
- **Check:** `./ci/policies.sh`

### Stage 5: repository
- **Files:** haskell/src/Agentic/Framework/Repository.hs
- **Behavior:** Persist Controller state atomically and replay a crashed run idempotently.
- **Check:** `./ci/acp.sh`

### Stage 6: proposal-workflow
- **Files:** haskell/example/Example/FrameworkProposal.hs
- **Behavior:** Emit a graph patch that schema validation and an explicit person gate can accept or reject.
- **Check:** `./ci/deck.sh`

### Stage 7: cli-integration
- **Files:** haskell/src/Agentic/Cli.hs, haskell/ci/framework.sh
- **Behavior:** Run one named FrameworkSpec node through Registry routing and print matching Plan facts.
- **Check:** `./ci/examples.sh`

## 9. Risks, license/provenance constraints, and rejected alternatives

- **Risk:** Mutable status leaks into Plan meaning. **Mitigation:** Keep Controller state in Agentic.Framework only.
- **Risk:** Agent prose falsely claims completion. **Mitigation:** Require RunCertificate evidence.
- **Risk:** Crash repeats an effect. **Mitigation:** Use run IDs and idempotent certificate replay.
- **Risk:** Concurrent claims lose updates. **Mitigation:** Make claim atomic in the repository adapter.
- **Risk:** Unbounded retries spend indefinitely. **Mitigation:** Store and enforce a finite attempt bound.
- **Risk:** License conclusions are overstated. **Mitigation:** Copy no implementation and retain exact license provenance.
- **Recommendation — rejected:** Do not parse Taskmaster JSON into RawProgram or Plan.
- **Recommendation — rejected:** Do not add dependency readiness as a new Plan level.
- **Recommendation — rejected:** Do not persist ExecTrace as mutable Controller state.
- **Recommendation — rejected:** Do not add framework-specific provider, MCP, editor, or cloud layers.
- **Recommendation — rejected:** Do not implement collaboration or workstream tags before a semantic requirement exists.
- **Verified — license:** Taskmaster is MIT plus Commons Clause; the license defines the restricted sale of the Software. — [tm-license](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/LICENSE#L1-L25)
- **Interpretation — license:** The restriction is specific to the Software as defined; this is not legal advice.

## 10. Open owner decisions

- **Recommendation:** First repository adapter? Default: Keep obr outside the semantic core.
- **Recommendation:** Certificate payload? Default: Store evidence digests plus an optional explicitly retained transcript reference.

## 11. Verification matrix

| ID | Recommendation | Evidence | Check |
|---|---|---|---|
| R1 | Defer multi-user collaboration and keep optional ownership fields in repository metadata. | [tm-team](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/integration/services/export.service.ts#L1464-L1523), `haskell/src/Agentic/Workflow.hs:L687-L718` | `nix develop path:./. -c cabal build all` |
| R2 | Implement decomposition and research as Registry programs that propose validated FrameworkSpec patches. | [tm-expand](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/integration/services/task-expansion.service.ts#L119-L178), [tm-prd](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/scripts/modules/task-manager/parse-prd/parse-prd.js#L64-L100), `haskell/src/Agentic/Workflow.hs:L1814-L1839`, `haskell/src/Agentic/Workflow.hs:L1943-L1957` | `./ci/deck.sh` |
| R3 | Put cross-run attempts and retry exhaustion in Controller while retaining bounded revising inside each run. | [tm-loop](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/loop/services/loop.service.ts#L129-L175), [tm-loop-markers](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/loop/services/loop.service.ts#L289-L302), `haskell/src/Agentic/Workflow.hs:L1557-L1608`, `haskell/src/Agentic/Workflow.hs:L1610-L1662`, `haskell/src/Agentic/Workflow.hs:L1673-L1698`, `haskell/src/Agentic/Workflow.hs:L1700-L1745` | `./ci/tier0.sh` |
| R4 | Add only thin Registry and Cli entry points after Spec, Controller, Certificate, and Repository exist. | [tm-mcp](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/mcp-server/src/tools/tool-registry.js#L59-L104), `haskell/src/Agentic/Cli.hs:L441-L478` | `./ci/examples.sh` |
| R5 | Reuse Route and Chains unchanged for framework nodes and add no framework-specific provider abstraction. | [tm-provider-core](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/ai/interfaces/ai-provider.interface.ts#L115-L171), [tm-provider-lifecycle](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/ai/interfaces/ai-provider.interface.ts#L173-L207), `haskell/src/Agentic/Route.hs:L260-L293`, `haskell/src/Agentic/Route.hs:L319-L354` | `./ci/acp.sh` |
| R6 | Require research-produced graph patches to pass schema validation and an explicit person gate. | [tm-research](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/mcp-server/src/core/direct-functions/research.js#L108-L135), `haskell/src/Agentic/Plan.hs:L351-L394` | `./ci/deck.sh` |
| R7 | Persist Controller state and RunCertificate references atomically, never ExecTrace as mutable state. | [tm-file-store](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/storage/adapters/file-storage/file-operations.ts#L69-L105), `haskell/src/Agentic/Exec.hs:L32-L50` | `./ci/policies.sh` |
| R8 | Defer workstream tags until a repository adapter demonstrates a semantic requirement for them. | [tm-tags](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/common/types/index.ts#L204-L208), `Agentic/Scope.lean:L3-L31` | `nix develop path:./. -c cabal build all` |
| R9 | Define FrameworkSpec as the separate finite dependency DAG and keep Plan unchanged. | [tm-task](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/common/types/index.ts#L131-L176), [tm-ready](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/tasks/utils/task-filters.ts#L121-L143), `README.md:L1-L15`, `haskell/src/Agentic/Plan.hs:L675-L701` | `lake build` |
| R10 | Define Controller node states and no-ready deadlock separately from Workflow authoring stages. | [tm-workflow-phases](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/types.ts#L4-L29), [tm-workflow-events](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/types.ts#L63-L96), [tm-workflow-persist](https://github.com/eyaltoledano/claude-task-master/blob/c0c98d367c55296bfe69e65680625b6db437af02/packages/tm-core/src/modules/workflow/orchestrators/workflow-orchestrator.ts#L444-L470), `haskell/src/Agentic/Workflow.hs:L784-L823` | `./ci/tier0.sh` |
