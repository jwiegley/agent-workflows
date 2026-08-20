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
