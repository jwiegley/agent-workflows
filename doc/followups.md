# Follow-ups from the landing verification (2026-08-19)

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

## Low

- **L3 — built-ahead library, unnamed as such.** `Report.suggestionsFn`
  (declared in every `defining` table, called by none), all six exports of
  `Workflows.Escalation` (221 lines), `Rubrics.Ladder.rungNamed`. Roughly
  350 lines ahead of any consumer — fine for the roadmap's later waves, but
  the README should say "built ahead" rather than list them as live.
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
