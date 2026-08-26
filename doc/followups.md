# Follow-ups from the landing verification (2026-08-19)

> **Tracking moved to obr (2026-08-20).** The live items below are now issues
> in this repository's tracker — `obr list` — under `awork-*`; this file stays
> as the narrative record of what each finding was and why it was deferred.

The landing verification (agent-cat session, workflow `ai-config-workflows`,
verify pass over both repos) confirmed all gates green and filed findings.
H1 (the fess sin catalog carried ten of the source's eleven sections), M2
(reviewer rubrics compressed past their own declared rule) and L4/L8 were
fixed before the initial commit. These remain, in the verifier's words,
lightly compressed — each is a decision, not just a chore:

## Medium

- **M1 — §5 step 8's cross-module call-site gate is unmet.** The design
  promised `resolveFn` three call sites and `commitFn` four; each has one.
  `resolveFn`'s single rung-parameterized caller is arguably the better
  outcome; `commitFn`'s is not — `Fix/Green.hs` ends its Settled arm with
  `reportFn` where the design's sketch said `call_ commitFn`. Either wire
  the calls the design promised or amend §5/§6 with the reason.
- **M3 — `Workflows.Rubrics.Ladder` is dead code carrying a false claim.**
  `seeAlso` has zero call sites; `Review/Ladder.hs` §2 argues (convincingly)
  that four priced rows supersede the paragraph. Decide: delete the module,
  or wire it and make the README's description true.
- **M4 — `Workflows.Evidence`'s "every argv is here" is stale.**
  `Git/Stack.hs:185–270` defines ten `running` parties locally and
  self-declares the debt. Move them into Evidence or amend Evidence's
  header; the unit-review property is the point of the module.
- **M5 — the independence probe asserts a premise nothing establishes.**
  `Rubrics/Discipline.hs:144` tells the answering model a
  `PARENT_HISTORY_SENTINEL` line stands in the parent conversation; `wf`
  plants none. `reviewLadder` stops the whole review on a negative and
  `fessAudit` downgrades provenance — both hanging off fiction. Either the
  runner plants the sentinel (an agent-cat `Registry` request, alongside
  the recorded `regDefaults` / `--at-most N` requests) or the probe must
  say what it can actually test.
  **Closed (2026-08-20), the first way.** agent-cat's runner generates one
  sentinel per run and binds it as the reserved input `run.sentinel`
  (`Agentic.Workflow.runFacts`); `independenceAttestation` takes it, quotes
  it last so a scripted table can still key on the constant prefix
  (`independenceAttestationKey`), and asks whether such a line was in the
  answerer's context *before* this request. `reviewLadder`, `fessAudit` and
  `wiggum` all declare the input.
- **F1-followup — runner-supplied backend count.**
  `Rubrics/Stances.hs`'s `conferProvenance` closes on a conditional —
  "unless the run's header names more than one backend" — whose authority
  is the run's header, terminal output the runner prints around the run
  and no prompt carries. Stage C verification caught a live one-backend
  run resolving it by guess (right, that time) and a two-backend run
  copying it unresolved; resolved the other way, an artefact would have
  claimed single-backend provenance for a two-provider confer. The write
  briefs now forbid resolving it, so the artefact carries the conditional
  as constant text — a repair, not a fix. The honest fix is for the runner
  to bind the backend count as a fact prompts can carry (an agent-cat
  `Registry` / CLI request, alongside the recorded `regDefaults` /
  `--at-most N` requests), at which point provenance can state what the
  run did. Until then: unresolved by design. **The same runner-supplied
  fact should carry the run's engine and session policy**, because the
  paragraph now turns on a second header-only condition: "a separate
  session per question" holds under `--engine acp` and is false of a run
  sent to a live agent-deck session, where one durable session serves the
  whole run and the third seat has read the first two.
  **Closed (2026-08-20), the honest way.** Both facts are now reserved
  inputs the runner binds — `run.backends` (the roster line the header
  prints) and `run.engine` (the engine and its session policy) — derived in
  `Agentic.Cli` from the very fields `sayBackends` prints, so header and
  paragraph cannot disagree. `conferProvenance` takes them and states them;
  the two write briefs' forbid now forbids *restating* them and forbids the
  "I cannot see the header" caveat, which is no longer true. `wiggum`'s seven
  endings carry the same two facts through one `runProvenance` (the seventh,
  `sharedSessionNote`, is the shared-conversation refusal itself).

## Low

- **L3 — built-ahead library, unnamed as such.** `Report.suggestionsFn`
  (declared in every `defining` table, called by none), all six exports of
  `Workflows.Escalation` (221 lines), `Rubrics.Ladder.rungNamed`. Roughly
  350 lines ahead of any consumer — fine for the roadmap's later waves, but
  the README should say "built ahead" rather than list them as live.
- **L10 — the confer gate is unbuilt, and is a design sketch only.**
  `confer-design.md` §5.4 sketches `conferGate` — three seats folded to a
  verdict — and nothing in this tree defines it. Three sites named it in
  identifier markup as though it existed (`Registry.hs`, `Confer.hs`,
  design §8.1) and now name it as the design's sketch. Build it as a gate
  in `Workflows.Gates`, or leave it in `confer-design.md`.
- **L6 — `green-web` is deferred and the deferral unrecorded.** Design §6.2
  names four green rows; `Fix/Green.hs` has three. §7.2 #66 triaged
  `webfix` as REWORK, so deferring is right — record it in §6.2.
- **L9 (agent-cat side) — `pal-note.md` remains in agent-cat's
  `doc/research/ai-config-workflows/`** naming the owner's skills; the same
  boundary case §4.4 resolved for `confer-design.md`, currently resolved by
  omission. Decide and record.
- **Systematic — 69 of 129 `[wf|…|]` blocks live in flagship modules**
  against §6's "rubric text lives in `Workflows.Rubrics.*`" convention
  (Stack 23, Commit 16, Review 16, Green 14). Only `Git/Stack.hs` declares
  it. The program bodies hold the design's under-60-line thesis; the
  modules read long because the rubrics moved in with them. Either move
  the text and leave the programs, or amend §6 to bless colocation.

## Roadmap head (from the verifier's ranking)

1. **confer** — wave 2's first build: roster/fan-out/fold machinery already
   exists; single-backend caveat becomes a sentence the program derives
   from its own roster; also lands `second-opinion`. Design:
   agent-cat `doc/research/pal-subsumption/confer-design.md`.
2. Engine `--route` (agent-cat side, `acat-engine-party-routing-hcx`) makes
   confer's roster span backends with the program text unchanged.

## From the waves 3–5 landing verification (2026-08-20)

- **`green-web` deferred, now recorded** (was the tranche's one Medium):
  design §8's amendment and `Fix/Green.hs`'s header carry the reason. Building
  it means a Playwright `running` party in `Workflows.Evidence` and one more
  green rung — do it when a web project actually wants the gate.
- **§7.4's `git-surgeon` cell is unaddressed as an argv promise.**
  `Wiggum.hs` records why the *policy* (git-surgeon over plain git) stays with
  the skill; the design cell also promised hunk-level staging argv as parties
  in `Workflows.Evidence`, and none exists. Either build the argv when a
  caller wants hunk-level staging, or amend §7.4's cell.
- **K=2 is wiggum's honest ceiling, and the mechanism gap is agent-cat's.**
  A bounded revision's body reviews and amends and holds no other statement
  (`Step (Calling s) ('Review c s)` refuses a call there), so the work
  cannot loop inside a `revisingOn`; `wiggum` therefore unrolls its rounds
  at the program level, and the count — two — is a recorded design decision
  ("a third round would be a design decision and would show here",
  ci/workflows.sh). A long session is several priced invocations. If
  continuation-with-a-price is ever wanted in one run, the request is an
  agent-cat surface feature (a bounded round-count former whose body admits
  statements — `revisingOn`'s sibling), not a toolbox workaround.
- **The verifier's usage ratio, kept where the roadmap can see it:** of the
  50 tranche rows, roughly 10 look weekly, 15 occasional, 25 priced-but-
  shelf-ware. §7.5's goal was to price the corpus, so a never-run priced row
  still answers "what would this cost" — but future waves should weight
  toward rows that get typed, and `translate-es` (a unit test wearing a row's
  clothes) is the marker for where to stop.

## From the wft sweep (2026-08-20)

- **The 500 string-gap literals, classified and left.** 457 are prose-runs
  (at least one gap join encodes a space, not a newline — `Wiggum.hs`'s
  `notIndependentNote` decodes to one 679-character line, and several run
  longer); 43 are fence-shaped but are canned stdout in scripted tables
  (fake `git`/`psql`/diff output), six of which end in a trailing newline no
  fence can produce. Converting any of them to `[wft|…|]` moves bytes.
  Bytes win over beauty: convert one only with its bytes compared, never
  assumed. The convertible idioms (412 `wfText [wf|…|]` compositions, two
  prefix-concatenations) are all gone.

  **The prose half is discharged (2026-08-21), by a ruling that let the bytes
  move.** The owner, on `Wiggum.hs`: *"why does src/Workflows/Wiggum.hs still
  use a mixture of Haskell-style multi-line strings, and the wft quasi-quoter?
  It should only use the latter for consistency."* That overrules
  bytes-win-over-beauty **for prose** and for prose only. Of the 511 gap
  literals this tree actually holds (the 500 above counted a slightly different
  grouping), 471 were prose and all 471 are now `[wft|…|]`, re-wrapped to the
  tree's ~80-col style. 429 stood alone and converted mechanically; the other
  42 were fragments of `<>` chains and were folded into 37 fences carrying
  define holes — among them `notIndependentNote`'s siblings `doneNote`,
  `stillRemainsNote` and `cannotJudgeNote`, `Wiggum.hs`'s `parityClause`, and
  the provenance builders `tierProvenance`, `wholeTeamNote` and `auditedNote`.
  Seven of those needed a `:: Text` signature on the newly held-out binding,
  because a hole goes through the class method `saysText` and an unannotated
  local binding is then ambiguous.

  **The fixture half fell to the total ruling (2026-08-21, same day).** The
  owner then ruled "any multi-line string uses the wft quasi-quoter", and all
  41 fixture gap literals became fences too — byte-exact, proved per literal
  against the text they replaced (83/83 across both repos), with the shapes a
  bare fence cannot carry held at the seam: trailing newlines spliced as
  `<> "\n"`, leading spaces as `" " <>`, indentation-significant scraps
  written at their own margin. Zero gap literals remain in this tree.
  agent-cat keeps nineteen, each naming a compiler-stated mechanism (Symbols
  in types; modules below the quoter in the import graph; the quoter's own
  module under the Template Haskell stage restriction). README house rule
  8 states the ruling; `Workflows.Prose`'s header carries the history.

  **Two prose blocks are fences that are deliberately not re-wrapped**, and
  say so: `EliminateDeadCode.hs`'s advocate `OBJECTION` and `Nix.hs`'s `baseline`, both
  answers to *verdict* questions, where `Agentic.Text.decodeVerdict` makes one
  objection **per line** — a wrap would have turned one objection into three.
  That is the one failure the word-preserving re-wrap could still cause, and
  it was caught by diffing every row's run output rather than by reading.

  **What the sweep is evidence about.** Every row's `wf plan`, `wf cost` and
  `wf run --scripted` output is byte-identical to `178cabb` — without
  `--raw`, which prints literal prompt bytes and correctly differs (the runner's
  per-run `PARENT_HISTORY_SENTINEL` normalised), which is stronger than the
  gate: it pins every arm, every bill and every rendered prompt, not just the
  level, the path count and the ceiling. The mechanism is
  `Agentic.Exec.oneLine`, which collapses whitespace runs when it prints a
  prompt — so a re-wrap that moves no *word* cannot move a printed byte.
  **No scripted key needed updating**, and that is a fact about the design
  rather than luck: every key in every table is the define itself (or a
  function of it), so a reworded prompt moves its key with it. A grep for a
  string-literal key across all `*Script*` tables finds zero.

## From the duet landing (2026-08-20)

The design of record is `doc/research/duet-design.md`. Everything in §1–§5 and
§6.2 landed; §6.1 is agent-cat's. Three items are recorded here rather than
absorbed, because each is somebody's decision and not a chore.

**One thing landed wider than the design wrote it, and the design is left as
written.** §2.2's `judgeIsElsewhere` takes a single work pin and compares three
backends; the code takes a *list* and compares the judge against every one of
them. The design's own §2.3 row 7 is what exposed the gap: if a judge on the
**default** must be refused because borrowed callees land there, then a judge
sharing a pane with a borrowed callee's *own pin* must be refused for the same
reason, and `--route opus=deck:<judge>` is that invocation — accepted by the
three-backend comparison, refused by the list. The ten-row table is unchanged
row for row (none of its rows routes a ladder rung), which is why the widening is
a strict tightening and not a re-decision. §2.2 is not edited: a design of record
rewritten to match the code stops being a record.

- **The tagged reply, deferred with the ledger the design wrote.** A message the
  owner submits into a pane while `wf` is waiting on that pane can be read as
  `wf`'s own answer: the freshness test compares against *one* timestamp taken
  before the send, so it cannot tell two new replies apart. The window is one
  poll interval and nothing in the transport reports it. The fix that would
  actually close it is a per-question nonce in the rendered answer-format line,
  and it was rejected for this piece of work for three reasons together —
  `renderQ` is cited *verbatim* against agent-cat's Lean source and `ci/citations.sh`
  gates that citation, so appending a nonce renegotiates it rather than editing
  it; it changes what is on the wire for every deck run and perturbs every
  `ci/deck.sh` scenario and the stub's `answer_for`; and a model that forgets the
  tag burns a re-ask. Two cheaper ideas were considered and rejected: reading
  `session output` on every poll catches a *second* new stamp but not the case
  that bites (where the owner's reply is the first), and a `DeckInterleaved`
  error on any ambiguity has the same blind spot. **The order that makes sense:**
  run the duet against two real panes, then decide whether the window was ever
  hit. `--poll 250` is the mitigation, and `doc/wiggum-two-sessions.md` states
  the hazard plainly, which is the minimum a design that knows about a silent
  failure owes its operator.
- **`--route` on a refusing row is refused in the CLI's words, not the gate's.**
  `Agentic.Cli`'s check that a routed name is a name the program pins runs against
  the program the *run facts built* — and on a refusing invocation those facts
  have already selected `duetRefusalTable`, whose only ask is a tool. So a routed
  refusal never reaches `judgeIsElsewhere`'s *words* — decision-table rows 5 and
  7, the judge on the work's pane and the inverted split, and now a third
  spelling: a ladder rung routed alongside the judge
  (`--route partner=deck:J --route opus=deck:J`), which is the invocation the
  two-name predicate used to accept. The operator is told "`--route` names the
  model 'partner', which this workflow never pins; it pins no model at all" —
  true of what was built, misleading about the row, which pins six. The gate is
  not bypassed: its verdict is what selected the program that pins nothing, so
  the parser's complaint is downstream of the refusal, and the predicate's own
  verdict on all three is `False`. Nothing is spent either way — measured, and no
  stub state directory is created — and the fix is the same one the guide's table
  gives. **The decision is agent-cat's**, because the two candidate fixes are
  both over there: compute `pinnedModels` from the row's *unrefused* elaboration,
  or say "the program this run's facts built" in the message. The toolbox-side
  alternative — declaring model asks in the refusal table so that it pins
  something — is a refusal made larger than a refusal in order to improve an
  error message, and is refused here. `ci/workflows.sh` pins the behaviour that
  actually happens, so a change to it is a change somebody notices.
- **`M-x wf-run` cannot drive a routed run.** `wf--read-transport` emits exactly
  one backend and contains no `--route`, so `wiggum-duet` is a shell invocation.
  The requirement is one sentence long and is recorded as a TODO above that
  function, including the trap: `list --json`'s `pins` array is *every* pinned
  serving model the program reaches, borrowed callees and ladder rungs included
  (six at `wiggum-duet`, of which two are the row's own), and a picker that
  offered a pane for each would invite a split **the gate refuses** — since
  `judgeIsElsewhere` compares the judge's backend against every one of the other
  five and against the default, a rung sent to the judge's pane is a refused run
  rather than a silently contaminated one. The picker's job is therefore to make
  the safe invocation easy and not to make the unsafe one unreachable: name which
  pins are the row's own and default every field to blank.
