# Taskmaster concepts for an agent-cat workflow framework

## 1. Status and provenance

- **Verified:** Taskmaster `1111111111111111111111111111111111111111` / tree `2222222222222222222222222222222222222222`.
- **Verified:** agent-cat `3333333333333333333333333333333333333333` / tree `4444444444444444444444444444444444444444`.
- **Verified:** Sources were clean before collection; evidence excerpts and hashes are retained in the manifest.
- **Recommendation:** Re-derive concepts, retain provenance, and copy no implementation code.

## 2. Executive decision

- **Recommendation:** Build a separate FrameworkSpec DAG and controller.

## 3. Verified Taskmaster capability inventory

- **Verified — task-structure-dependencies:** Taskmaster task-structure-dependencies — [tm-0](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L1-L1)
- **Verified — decomposition:** Taskmaster decomposition — [tm-1](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L2-L2)
- **Verified — research:** Taskmaster research — [tm-2](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L3-L3)
- **Verified — execution-loops:** Taskmaster execution-loops — [tm-3](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L4-L4)
- **Verified — workflow-state:** Taskmaster workflow-state — [tm-4](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L5-L5)
- **Verified — storage-persistence:** Taskmaster storage-persistence — [tm-5](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L6-L6)
- **Verified — interfaces:** Taskmaster interfaces — [tm-6](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L7-L7)
- **Verified — providers:** Taskmaster providers — [tm-7](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L8-L8)
- **Verified — tags-workstreams:** Taskmaster tags-workstreams — [tm-8](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L9-L9)
- **Verified — collaboration:** Taskmaster collaboration — [tm-9](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L10-L10)

## 4. Existing agent-cat capability inventory

- **Verified — task-structure-dependencies:** agent-cat task-structure-dependencies — `Agent.hs:L1-L1`
- **Verified — decomposition:** agent-cat decomposition — `Agent.hs:L2-L2`
- **Verified — research:** agent-cat research — `Agent.hs:L3-L3`
- **Verified — execution-loops:** agent-cat execution-loops — `Agent.hs:L4-L4`
- **Verified — workflow-state:** agent-cat workflow-state — `Agent.hs:L5-L5`
- **Verified — storage-persistence:** agent-cat storage-persistence — `Agent.hs:L6-L6`
- **Verified — interfaces:** agent-cat interfaces — `Agent.hs:L7-L7`
- **Verified — providers:** agent-cat providers — `Agent.hs:L8-L8`
- **Verified — tags-workstreams:** agent-cat tags-workstreams — `Agent.hs:L9-L9`
- **Verified — collaboration:** agent-cat collaboration — `Agent.hs:L10-L10`

## 5. Capability map

| Capability | Decision | Owner | Rationale | Evidence |
|---|---|---|---|---|
| task-structure-dependencies | ADAPT | FrameworkSpec | **Interpretation:** Map task-structure-dependencies without changing Plan. | [tm-0](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L1-L1), `Agent.hs:L1-L1` |
| decomposition | ADAPT | FrameworkSpec | **Interpretation:** Map decomposition without changing Plan. | [tm-1](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L2-L2), `Agent.hs:L2-L2` |
| research | ADAPT | FrameworkSpec | **Interpretation:** Map research without changing Plan. | [tm-2](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L3-L3), `Agent.hs:L3-L3` |
| execution-loops | ADAPT | FrameworkSpec | **Interpretation:** Map execution-loops without changing Plan. | [tm-3](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L4-L4), `Agent.hs:L4-L4` |
| workflow-state | ADAPT | FrameworkSpec | **Interpretation:** Map workflow-state without changing Plan. | [tm-4](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L5-L5), `Agent.hs:L5-L5` |
| storage-persistence | ADAPT | FrameworkSpec | **Interpretation:** Map storage-persistence without changing Plan. | [tm-5](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L6-L6), `Agent.hs:L6-L6` |
| interfaces | ADAPT | FrameworkSpec | **Interpretation:** Map interfaces without changing Plan. | [tm-6](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L7-L7), `Agent.hs:L7-L7` |
| providers | ADAPT | FrameworkSpec | **Interpretation:** Map providers without changing Plan. | [tm-7](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L8-L8), `Agent.hs:L8-L8` |
| tags-workstreams | ADAPT | FrameworkSpec | **Interpretation:** Map tags-workstreams without changing Plan. | [tm-8](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L9-L9), `Agent.hs:L9-L9` |
| collaboration | ADAPT | FrameworkSpec | **Interpretation:** Map collaboration without changing Plan. | [tm-9](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L10-L10), `Agent.hs:L10-L10` |

## 6. Minimum framework semantics and representation tower

- **Recommendation — principal object:** FrameworkSpec is a finite DAG outside Plan.
- **Recommendation — representation:** Spec
- **Recommendation — representation:** Controller
- **Recommendation — representation:** ExecTrace evidence
- **Recommendation — representation:** RunCertificate
- **Recommendation — law:** Acyclic
- **Recommendation — law:** Ready iff prerequisites complete
- **Recommendation — law:** Plan unchanged
- **Recommendation — law:** Trace is evidence
- **Recommendation — law:** Completion needs certificate
- **Recommendation — boundary:** FrameworkSpec is a finite multi-run DAG outside Plan.
- **Recommendation — boundary:** Controller owns operational state and FrameworkSpec owns readiness.
- **Recommendation — boundary:** ExecTrace is run evidence; repository adapters own persistence.
- **Recommendation — boundary:** Plan, Workflow, Exec, Route, and Certify remain unchanged.
- **Recommendation — boundary:** Taskmaster JSON is not parsed into agent-cat Plan or RawProgram.

## 7. Lifecycle, failure, persistence, and extension boundaries

- **Recommendation — lifecycle:** validate
- **Recommendation — lifecycle:** select ready
- **Recommendation — lifecycle:** claim
- **Recommendation — lifecycle:** execute
- **Recommendation — lifecycle:** accept
- **Recommendation — lifecycle:** complete
- **Recommendation — lifecycle:** persist
- **Recommendation — lifecycle:** repeat
- **Recommendation — failure:** invalid graph
- **Recommendation — failure:** no-ready deadlock
- **Recommendation — failure:** transport failure
- **Recommendation — failure:** tool failure
- **Recommendation — failure:** failed acceptance
- **Recommendation — failure:** retry exhaustion
- **Recommendation — failure:** persistence failure
- **Recommendation — failure:** crash replay
- **Recommendation — extension:** Registry rows
- **Recommendation — extension:** repository adapter
- **Recommendation — extension:** completion contract
- **Recommendation — extension:** proposal workflow

## 8. Ordered implementation plan with acceptance checks

### Stage 1: stage-1
- **Files:** File1.hs
- **Behavior:** Observable behavior 1
- **Check:** `lake build`

### Stage 2: stage-2
- **Files:** File2.hs
- **Behavior:** Observable behavior 2
- **Check:** `nix develop path:./. -c cabal build all`

### Stage 3: stage-3
- **Files:** File3.hs
- **Behavior:** Observable behavior 3
- **Check:** `./ci/tier0.sh`

### Stage 4: stage-4
- **Files:** File4.hs
- **Behavior:** Observable behavior 4
- **Check:** `./ci/examples.sh`

### Stage 5: stage-5
- **Files:** File5.hs
- **Behavior:** Observable behavior 5
- **Check:** `./ci/acp.sh`

### Stage 6: stage-6
- **Files:** File6.hs
- **Behavior:** Observable behavior 6
- **Check:** `./ci/deck.sh`

### Stage 7: stage-7
- **Files:** File7.hs
- **Behavior:** Observable behavior 7
- **Check:** `./ci/citations.sh`

## 9. Risks, license/provenance constraints, and rejected alternatives

- **Risk:** Risk 1 **Mitigation:** Mitigation 1
- **Risk:** Risk 2 **Mitigation:** Mitigation 2
- **Risk:** Risk 3 **Mitigation:** Mitigation 3
- **Risk:** Risk 4 **Mitigation:** Mitigation 4
- **Risk:** Risk 5 **Mitigation:** Mitigation 5
- **Risk:** Risk 6 **Mitigation:** Mitigation 6
- **Recommendation — rejected:** Reject alternative one
- **Recommendation — rejected:** Reject alternative two
- **Recommendation — rejected:** Reject alternative three
- **Recommendation — rejected:** Reject alternative four
- **Verified — license:** Taskmaster is MIT plus Commons Clause; the license defines the restricted sale of the Software. — [tm-license](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/LICENSE#L1-L2)
- **Interpretation — license:** The restriction is specific to the Software as defined; this is not legal advice.

## 10. Open owner decisions

- **Recommendation:** Which adapter? Default: obr outside core

## 11. Verification matrix

| ID | Recommendation | Evidence | Check |
|---|---|---|---|
| R1 | Recommendation 1 | [tm-0](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L1-L1), `Agent.hs:L1-L1` | `lake build` |
| R2 | Recommendation 2 | [tm-1](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L2-L2), `Agent.hs:L2-L2` | `nix develop path:./. -c cabal build all` |
| R3 | Recommendation 3 | [tm-2](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L3-L3), `Agent.hs:L3-L3` | `./ci/tier0.sh` |
| R4 | Recommendation 4 | [tm-3](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L4-L4), `Agent.hs:L4-L4` | `./ci/examples.sh` |
| R5 | Recommendation 5 | [tm-4](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L5-L5), `Agent.hs:L5-L5` | `./ci/acp.sh` |
| R6 | Recommendation 6 | [tm-5](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L6-L6), `Agent.hs:L6-L6` | `./ci/deck.sh` |
| R7 | Recommendation 7 | [tm-6](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L7-L7), `Agent.hs:L7-L7` | `./ci/citations.sh` |
| R8 | Recommendation 8 | [tm-7](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L8-L8), `Agent.hs:L8-L8` | `lake build` |
| R9 | Recommendation 9 | [tm-8](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L9-L9), `Agent.hs:L9-L9` | `nix develop path:./. -c cabal build all` |
| R10 | Recommendation 10 | [tm-9](https://github.com/eyaltoledano/claude-task-master/blob/1111111111111111111111111111111111111111/src.ts#L10-L10), `Agent.hs:L10-L10` | `./ci/tier0.sh` |
