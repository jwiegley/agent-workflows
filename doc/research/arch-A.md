# `workflows/` — an architecture, designed from the shared foundation outward

**Bias, stated so it can be argued with: MAXIMAL REUSE.** Every workflow in this
proposal is thin because the library under it is thick. The corpus's 119 files
(67 commands, 25 skills, 25 agents, 2 prompts) are not 119 programs; they are
**≈30 programs behind the owner's own 67 names**, standing on **one** library of
rubrics, rosters, gates, receipts and deciders that is written once and called
everywhere. Where this bias costs something, the cost is named.

The corpus is read-only and was read as data. Nothing in `~/src/nix/config/ai`
is modified by anything proposed here, now or later.

---

## 0. The answer, in one page

**The registry question.** A new executable, `wf`, owns the workflows registry —
**and it shares one CLI with `agentic-run` rather than forking it.** `run/Main.hs`
moves into the library as `Agentic.Cli`, parameterized by a `Registry` value;
`agentic-run` becomes `main = Agentic.Cli.main examplesRegistry` and `wf` becomes
`main = Agentic.Cli.main workflowsRegistry`. Two registries, two gates, one CLI.
The reason is the one the brief already names and `ci/examples.sh` proves: that
gate reads the registry out of the binary and **fails on any field that moves**,
so the examples registry is a statement about *the language* and cannot hold a
toolbox that churns weekly. `ci/workflows.sh` is the second gate and pins
different things — that every row builds, plans, prices and runs `--scripted` to
exit 0, and that no row exceeds a per-row cost ceiling the owner sets — never
exact bills. §1 has the full argument and the cabal stanzas.

**The five flagships**, one line of design each:

| # | Name (registry keys it serves) | Design, in one line |
|---|---|---|
| 1 | **`review`** — `quick-review`, `code-review`, `sec-audit`, `deep-review`, `heavy-review`, `review-github-pr`, `alexey`, plus the six skill lenses | One `Roster`-driven ladder builder registered once per rung: a `running` scope snapshot bound once and spliced into every member, a linter dossier the world authored, `documentPanel` over the eleven-reviewer roster whose membership is chosen **in Haskell** from a `--input-arg paths=`, one `findingSchema` define holed into every brief, and one `reportFn` tail — so six commands, eleven agents and six skills become one program priced per rung. |
| 2 | **`green`** — `fix-ci`, `flaky-rust`, `webfix`, and every gate in the tree | `revising tree (atMost n)` whose **review clause is `ask (tool "green" \`running\` argv)` at verdict** — exit 0 approves, nonzero objects with the command's own first failing line, which the amendment splices into the repair prompt — with `Unsettled` naming the check still red, and `drawing n` as the flakiness rung. |
| 3 | **`commit`** — `commit`, `push`, `recommit`, `bankruptcy`, and callers `fix`/`halt`/`wiggum` | `commitFn :: Fn '[…] 'CodeAck` in one `defining` table, `call_`ed by four programs and three other workflows, with the per-commit "does it compile and pass tests" checklist item as a `Gates.gate` receipt and the "prefer a slightly larger commit" fallback as `Unsettled`'s yield. |
| 4 | **`fess`** — `fess` (= `agents/fess-auditor.md`), and a `call_` from every fixer | The independence attestation as a `running` sentinel receipt plus a zero-question `decide`, branching into two arms that call **one** `fessReportFn` with a different `{provenance}` argument — the md's "run the audit but report that its independence was not verified" made structural — over a `documentPanel` of the ten sin stances, each `servedBy` a different engine. |
| 5 | **`stack`** — `restack`, `rebase`, `rebase-and-fix`, `cleanup`, `resolve` | The step-1 baseline as a `running` receipt **bound once and live for the whole run**, `call_ resolveFn` per conflict, a `Gates.gate` per resolution, an outer `revising` for the `main`-moved fixpoint, and step 9's proof as a `git range-diff` receipt read by `decide containsLine` against that baseline handle. |

**The thesis, testable.** If the library is right, flagship 1 is under 60 lines of
program text, flagship 2 is under 25, and `teams` (twelve md bullets) and
`meeting-notes` (206 md lines) each fall out in a page during wave 2 without a
line of new library. If any flagship needs more than that, the library is in the
wrong place and §2 is what should move.

---

## 1. Integration

### 1.1 Where the tree lives

```
agent-cat/
  workflows/                     ← NEW. The owner's toolbox. Nothing else.
    Workflows/                   ← the library: rubrics, rosters, gates, receipts
      Prelude.hs
      Rubrics/…  Panels.hs  Gates.hs  Evidence.hs  Deciders.hs
      Parties.hs  Escalation.hs  Report.hs  Functions.hs  Registry.hs
      Review/…  Git/…  Fix/…  Audit/…  Doc/…  Nix/…  Positron/…
    bin/Main.hs                  ← `wf`, three lines
    corpus/                      ← the reference bulk that stays OUT of prompts
    README.md                    ← the owner's card: one line per registry key
  haskell/agentic.cabal          ← two new stanzas, one new library module
  haskell/ci/workflows.sh        ← NEW gate; ci/examples.sh untouched
```

`workflows/` sits at the repository root, as the brief asks. The cabal file stays
at `haskell/` (builds are `cabal` from `haskell/`, one builder at a time), and the
two new stanzas reach up with `hs-source-dirs: ../workflows`. That is legal and
builds; `cabal check` warns that the field points outside the package, and
`cabal sdist` would not carry it. Neither matters — this package is never
published — but the warning should be recorded in the stanza's comment rather
than discovered. *Fallback if that warning is unacceptable:* put the tree at
`haskell/workflows/` and leave a repo-root `workflows` symlink; the brief's
letter is then met by the symlink and the cabal file has no `..`. I recommend the
first and would not fight about it.

### 1.2 The registry question, decided

**`agentic-run` must not gain the workflows registry.** The evidence is in the
repository, not in taste:

* `ci/examples.sh` "reads the registry from the binary rather than transcribing
  it: an example name the table does not carry, or a table row naming no
  example, is a failure. **A new program cannot be registered without being
  priced.**" Every registered example has `level`, `size`, `askNodes`,
  `costSummary` and both bills pinned, and the gate "fails on any field that
  moves". That is exactly right for `harden`, `hello` and the five Isaac
  programs, whose numbers are evidence about the language.
* The owner's toolbox is the opposite object. A reviewer added to a roster, a
  rubric sharpened, a gate given one more repair trip — each moves `askNodes` and
  both bills, weekly. Under one registry, either every edit is a red CI run
  demanding a re-pin (and the gate stops meaning anything, because re-pinning
  becomes reflex), or the pins are loosened (and the language's own regression
  pin is loosened with them). Neither is acceptable.
* `Example.Harden.examples` already imports `Example.Isaac`; adding a third
  import would make the conformance registry depend on the toolbox's build.

**But two registries must not mean two CLIs.** `run/Main.hs` is 1047 lines of
argument parsing, input binding, engine selection, ACP/deck/shell wiring, pinning
checks and usage text, and none of it is about *which* programs are registered.
Forking it is precisely the drift the whole corpus survey indicts
(`partner-reviewer`/`partner-collaborator`, `rebase`/`rebase-and-fix`,
`retest`/`retest-categorical`). So:

**Move the CLI into the library and make the registry its argument.**

```haskell
-- Agentic/Cli.hs  (new library module; the present run/Main.hs, unchanged in
-- substance, with its two `Example.*` imports removed)

-- | What a CLI is a CLI *of*.
data Registry = Registry
  { regBinary :: !Text                 -- "agentic-run" | "wf", for the usage text
  , regRows   :: ![(Text, Row)]        -- ordered; the listing order
  }

-- | One registered program. The row is the unit, so a program cannot be
-- registered without the three things every verb needs from it.
data Row = Row
  { rowExample :: !Example             -- Fixed | Needs  (Agentic.Workflow)
  , rowDoc     :: !Text                -- one line, for `list` and for usage
  , rowScript  :: ![(Text, Text)]      -- the canned replies `--scripted` answers from
  , rowSample  :: ![(Text, Text)]      -- sample inputs, for `plan`/`cost`/CI
  }

main :: Registry -> IO ()
```

`run/Main.hs` becomes ~20 lines: build `examplesRegistry` from
`Example.Harden.exampleNames`/`lookupExample`/`scriptFor` and call
`Agentic.Cli.main`. `workflows/bin/Main.hs` is three lines over
`Workflows.Registry.registry`.

Four things fall out of `Row` that are worth having and that today are spread
across bash and two modules:

1. `rowScript` puts the canned table **beside the program**, which is
   `Example.Isaac`'s own argument for `isaacScript` ("the keys *are* the prompt
   defines those programs are written from") applied uniformly. `scriptFor`'s
   special-case dispatch in `run/Main.hs` disappears.
2. `rowSample` kills `ci/examples.sh`'s `inputsFor` bash function and its future
   equivalent: the gate asks the binary what input to price a row with.
3. `rowDoc` makes `wf list` generated rather than maintained, and makes the usage
   message name what each program is for.
4. A new verb, `list`, is one function over `regRows` and serves both binaries.

**Cabal:**

```cabal
-- The owner's toolbox: rubric library, shared functions, and the workflows
-- written on them. An internal library rather than modules compiled into `wf`,
-- for `library examples`' own reason: `ci/workflows.sh` prices the registry
-- through the very binary that runs it, and two compiled copies could drift
-- under a flag and read as agreement.
--
-- `hs-source-dirs` reaches out of the package directory because the brief puts
-- this tree at the repository root, beside `haskell/` rather than under it.
-- `cabal build` is happy; `cabal check` warns; `cabal sdist` would not carry
-- it, and nothing here is ever published.
library workflows
  import:          settings
  hs-source-dirs:  ../workflows
  exposed-modules:
    Workflows.Prelude
    Workflows.Parties
    Workflows.Deciders
    Workflows.Evidence
    Workflows.Panels
    Workflows.Gates
    Workflows.Escalation
    Workflows.Report
    Workflows.Functions
    Workflows.Registry
    Workflows.Rubrics.Finding
    Workflows.Rubrics.Reviewers
    Workflows.Rubrics.Fess
    Workflows.Rubrics.Discipline
    Workflows.Rubrics.Voice
    Workflows.Rubrics.Ladder
    Workflows.Rubrics.Lang
    Workflows.Review.Ladder
    Workflows.Fix.Green
    Workflows.Fix.Bugbot
    Workflows.Git.Commit
    Workflows.Git.Stack
    Workflows.Audit.Fess
    -- … one module per program; see §6
  build-depends:   agentic

-- The owner's entry point. Three lines over `Agentic.Cli`, which `agentic-run`
-- is now also three lines over: one CLI, two registries.
executable wf
  import:          settings
  hs-source-dirs:  ../workflows/bin
  main-is:         Main.hs
  build-depends:
    , agentic
    , agentic:workflows
  ghc-options:     -threaded
```

**Gates.** `ci/examples.sh` is untouched and keeps pinning exact fields.
`ci/workflows.sh` is new and pins *invariants a churning toolbox can keep*:

* every row builds, and `wf plan NAME` and `wf cost NAME` succeed on `rowSample`;
* `wf run NAME --scripted` exits 0 (so every branch a scripted default takes is
  reachable and every text question has a canned reply);
* `askNodes` and `costSummary`'s max are **below a per-row ceiling** carried in
  `rowDoc`'s sibling field (`rowCeiling :: Int`), so a rubric edit is free and a
  panel that doubled is a red build;
* `wf list` is non-empty and every row's `rowDoc` is non-empty.

That is the whole difference between the two registries, said in one place: the
examples gate holds numbers still; the workflows gate holds a budget.

### 1.3 Naming

* **Module namespace `Workflows.`**, mirroring `Example.` — `workflows/Workflows/Panels.hs`.
* **Registry keys are the owner's own slash names.** `wf run fix-ci`,
  `wf run heavy-review`, `wf run restack`. He types what he types today; that
  several keys resolve to one Haskell builder is the library's business, not his.
* **Program-facing Haskell names read as the thing, not the command**:
  `reviewLadder`, `greenLoop`, `commitFn`, `fessAudit`, `stackProgram`.
* **A `Fn`'s printed name is dotted and namespaced** — `"review.report"`,
  `"git.resolve"`, `"commit.series"` — as `Example.Isaac`'s `"review-lite.report"`
  already is, so a printed program says which family a call came from.

---

## 2. The shared foundation

This is where the bias lives. Eleven modules, built once, called by everything.
Each names the corpus evidence that demanded it.

### 2.1 `Workflows.Prelude` — the one import

Re-exports `Agentic.Workflow`, `Agentic.Workflow.Do` (as the author's `W`), and
every module below, plus the three helpers `Example.Isaac` had to define
privately and every workflow module would otherwise redefine: `wfText :: Words '[] -> Text`
(the `[wf|…|]`-to-`Text` conversion, with Isaac's argument for why defines are
`Text` and not `Words`), `bullets :: [(Text,Text)] -> Text`, `tshow`. An authoring
module's header is then the LANGUAGE block and `import Workflows.Prelude`.

### 2.2 `Workflows.Rubrics.*` — the corpus's prose, as defines

**The rule for what becomes a define and what becomes an input.** A rubric of
roughly sixty lines or fewer is a `Text` define in Haskell, with a provenance
comment naming the md file and section it was transcribed from. Anything larger
is **program input** and lives in `workflows/corpus/` — `denotational-design`'s
1921 reference lines, `haskell-pro`'s 994, `retest`'s 674-line spec,
`johnw`'s 487, `alexey-review`'s two 290-line references, `swiftui`'s eleven
references, `persian`'s glossary files. Prompt bulk is the corpus's largest
avoidable cost and `caveman` exists because of it; the split is where the saving is.

* **`Rubrics.Finding`** — **the** finding schema, once. Eleven agent files carry
  it, nine byte-identical, two with one extra line, two with a different closing
  sentence; `deep-review` prints a *different* category vocabulary with two extra
  entries and nothing reconciles them. Here it is
  `findingSchema :: [Text] -> Text` over one `findingCategories :: [Text]` table,
  with `soundnessLine`, `securityFloor 85` and `perfImpactLine` as the three
  documented variants. Adding `Simplification` to the vocabulary reaches all
  eleven briefs by being added — and the corpus's one live drift becomes
  unrepresentable.
* **`Rubrics.Reviewers`** — the eleven reviewers as a `Roster` (§2.4), each row
  carrying its severity-tiered sections, **its file globs**, **its tool argv**,
  and its serving pin. The globs are what makes `deep-review`'s nine-row
  extension→agent table free; the argv is what turns seven "if available, run
  `ruff …`" wishes into receipts; the four reviewers with no tool block get one
  (`catalog.nix` already grants all eleven `run-commands` and four never use it).
* **`Rubrics.Fess`** — the ten sin categories, each with harm, rule, signals and
  its interrogative, as a `Roster`. Ten stances, ten asks, one panel.
* **`Rubrics.Discipline`** — the standing constraints spliced into every acting
  question: `fix-all`'s no-deferral rule (six conjuncts, two of which are pure
  deciders), `codeRule` (the code is the artefact, the review is the record),
  `toolkit`'s tier text, `wiggum`'s environment discipline (direnv, never
  `nix develop`, never install on the fly, stop and ask when blocked), `nixos`'s
  three prohibitions.
* **`Rubrics.Voice`** — `johnw` **split into two**, which the skills survey names
  as the level-up: `johnwGenerate` (patterns that work) and `johnwCritique` (the
  two NEVER lists and the self-review checklist, asked of a *different* model).
  Plus `itVoice`, `caveman`, `smoothRestraint`, `proofreadProhibitions`, and a
  `ponytail` **slot** the owner fills — the discipline is honored as an edge, the
  text is not owned here.
* **`Rubrics.Ladder`** — the review ladder as one value. The five-rung paragraph
  appears verbatim in at least five files and is maintained by copy-paste; here
  every rung's "see also" text derives from the same table, so a rung added
  arrives everywhere by being added. This is `qaFence`'s derived roster pointed at
  the corpus's own navigation.
* **`Rubrics.Lang`** — the `-pro` agents' reference material, sliced by section,
  so a question about laziness splices the `Writer`/`Accum` paragraph and not
  28 KB. The `-pro`/`-reviewer` overlap (six languages have both, the reviewer
  always sharper) becomes one define with two consumers.

### 2.3 `Workflows.Parties` — who answers

The nine `-pro` agents and the eleven reviewers are **addressees**, not programs.
One module of party constructors with the pin and the alternates said once:

```haskell
haskellPro, cppPro, rustPro, pythonPro, elispPro, nixPro, sqlPro, tsPro :: Party 'IsModel
haskellPro = model "haskell-pro" `servedBy` "fable" `fallingBackTo` "opus"
```

Isaac's I5 applies verbatim: the pin is on the question, and the *deliberate*
absence of one is the absence of the words — which is what `deep-review`'s
"the four mandatory lenses must stay comparable" asks for and cannot say.
`validated-code-review`'s `verify-model-dispatch.py`, `forge`'s `listmodels`
preflight and `persian`'s "opus at max effort" are three hand-rolled model
attestations; all three are this module plus `fallingBackTo`, and the Python
script and the twelve-row mistakes table go away.

### 2.4 `Workflows.Panels` — the roster, and the one fan-out

The corpus fans out constantly and never the same way twice: eleven reviewers,
ten fess stances, twelve `teams` roles, ten `meeting-notes` sections, eight
`sitrep` sections, seven `report` categories, six `remove-service` subsystem
auditors, twenty-one `productize` deliverables, three `eliminate-dead-code`
advocates, seven `heavy-review` passes. All of it is one type:

```haskell
data Lens = Lens
  { lensName  :: !Text          -- the fence label; the author's name, never the addressee's id
  , lensOwns  :: !Text          -- the one question it owns — for the derived sibling table
  , lensBrief :: !Text          -- its rubric
  , lensParty :: Party 'IsModel -- who answers, pin and alternates included
  }
type Roster = [Lens]

-- Every member's brief is spliced with the roster *derived from the same list*:
-- how many reviewers there are, and what each sibling owns, so anything it
-- repeats ships twice. This is `qaOfCommitOver` / `qaFence`, generalized.
asksOver        :: KnownIx h s => Roster -> V h 'CodeText -> [Ask s]
verdictPanel    :: KnownIx h s => Roster -> V h 'CodeText -> Rhs s 'CodeVerdict
documentPanel   :: KnownIx h s => Roster -> V h 'CodeText -> Rhs s 'CodeText
withEvidence    :: KnownIx h s => Roster -> V h 'CodeText -> V h 'CodeText -> [Ask s]

-- The synthesis that REFUSES on a short roster, with the roster it refuses on
-- derived from the same table (`grindSynthesisOver`). "An unauthenticated
-- backend returns nothing, and nothing folded into a ranked list reads exactly
-- like a clean tree."
refusingSynthesis :: Roster -> Text
```

`parallelize`'s seven inbound edges — the most-depended-upon skill in the corpus —
resolve here and at §2.5. Its 10-bullet list of shared state a subagent must not
touch is a hand-written type system for an untyped harness; no `ask` writes
anything, and a fan-out is a `panel`. What survives is its arity discipline, and
`costSummary` computes that instead of guessing at 3–5.

### 2.5 `Workflows.Evidence` — the receipts the world authors

Nine M–Z commands invoke real argv and **none holds a receipt**; seven reviewer
tool blocks are wishes. One module of named `running` parties, so an argv is
written once in the tree:

```haskell
gitDiffNames, gitStatus, gitRangeDiff, gitDiffCheck, gitRevParseTree :: [Text] -> Party 'IsTool
ghPrChecks, ghPrView, ghGraphqlThreads                              :: Text -> Party 'IsTool
gtLs, nixFlakeCheck, makeTest, lefthookAll                          :: Party 'IsTool
hlintJson, cargoClippy, ruffJson, mypy, bandit, shellcheckJson,
  statix, deadnix, clangTidy, cppcheck, printAssumptions            :: [Text] -> Party 'IsTool
noHistoryProbe                                                      :: Party 'IsTool

-- A fenced dossier of receipts: the "frozen scope snapshot", the "evidence
-- gathering block", the "three grep sweeps", all one shape.
dossierOver :: [(Text, Party 'IsTool)] -> Words s -> Rhs s 'CodeText
```

Three consequences the corpus asks for by name and cannot get:

* `heavy-review`'s "every pass examines identical code" becomes a **handle**: one
  snapshot receipt, bound once, spliced into every member.
* `sec-audit`'s three fixed-regex greps stop being things a model reports on.
  Three quarters of that command's evidence becomes world-authored on the one
  command where a fabricated "no secrets found" costs the most.
* `fess-auditor`'s "quote the command and the relevant output" stops being a
  demand made of an agent with no structural guarantee it ran anything.

And `Agentic.Shell`'s failure table gives the corpus a distinction it has never
had: **a command that exits nonzero is an answer; a command that is missing or
times out is a gap.** `renderShellError` says it in the owner's own terms — "the
gate did not say no; it did not run."

### 2.6 `Workflows.Deciders` — the free tests

Zero-question deciders, named for what they mean, so no workflow spells a needle
twice. The corpus already contains all of these and pays a model call for each:

```haskell
touches            :: [Text] -> …   -- anyPathMatches; the extension→agent table, free
saysDone, isGreen, allChecksPassed, zeroPending, noConflictMarkers,
  hasUnchecked, threadResolved, lexicalBindingFirstLine,
  everyUnsafeHasSafety, hasAdmitted, markerEscaped, orphanedWorkDirs,
  ponytailDebt, noHistoryVerified, attestsModel, headMatches
```

and the derived one that matters most:

```haskell
-- The nine language gates, derived from Rubrics.Reviewers' OWN glob column, so
-- the dispatch table cannot drift from the roster it dispatches to — and the
-- silent hole (.lean/.go/.java/.rb/.swift/.ml falling through to
-- general-purpose) becomes a written arm.
languagesIn :: Text -> Roster
```

**The house rule this module exists to enforce — decide as early as possible:**

| tier | mechanism | costs | when |
|---|---|---|---|
| 1 | **Haskell**, at program-construction time, over a `taking`/`input` `Text` | zero questions, **zero paths** | the fact is in the invocation: which languages the diff touches, which rung, which roster |
| 2 | **`decide`**, over a receipt | zero questions, one path | the fact exists only after the world ran something: the sentinel probe, the head OID, the green gate, the tally |
| 3 | **an asked flag** | one question | the fact is a judgment: `haskellTriageBrief`-style routing, `factsGate`-style prose reading |

Tier 1 is the one nothing in the corpus can reach and nothing in `Example.Isaac`
uses, and it is available because **`taking`'s inputs are ordinary Haskell `Text`
at build time**: `supply` builds the `Program` after the inputs are known, so
`wf plan review-deep --input-arg paths="$(git diff --name-only main)"` prints the
exact panel that will run. `deep-review`'s Step 2 costs nothing *and adds no
path*, and the operator sees the roster before spending.

### 2.7 `Workflows.Gates` — check, fix, recheck, written once

The single most repeated shape in the corpus, and the one that pays best:

```haskell
-- One receipt, one free decider, one terminal arm the compiler requires.
probe :: Party 'IsTool -> Decider -> [Text] -> Words s -> Rhs s 'CodeFlag

-- The gate loop. The REVIEW CLAUSE IS THE EXIT CODE: `Agentic.Shell` answers a
-- verdict question `approve` on exit 0 and `object [first failing line]` on
-- nonzero, so the command's own error is what the repair prompt reads.
gate :: (KnownIx h s)
     => Party 'IsTool          -- the check, `running` its argv
     -> Text                   -- the repair brief
     -> Party 'IsModel         -- who repairs
     -> V h 'CodeText -> Bound -> Loop 'CodeText s
```

so a whole check-fix-recheck is:

```haskell
gated <- gate (nixFlakeCheck) repairBrief (model "repair" `servedBy` "opus") tree (atMost 3)
case gated of
  Settled   t -> …          -- exit 0
  Unsettled t -> …          -- still red after three repairs; the tree keeps the edits
```

This is `fix-ci`'s monitor, `restack`'s step 5, `recommit`'s per-commit CI,
`process-checklist`'s fixpoint, `webfix`'s reproduction, `cleanup`'s four
obligations, `nix-rebuild`, `retest`'s phases, `productize`'s twenty-one
deliverables, and Isaac's `greenGate` — one function, called with different argv.

**Two grammar facts this module encodes so no workflow rediscovers them.** They
were checked against `Agentic.Workflow`, not assumed:

1. **A revision's body is exactly one verdict question and one `amend`.** No
   third statement, no `decide`, no `call_` (`act`/`call_` have `Step` instances
   at `'Open s` and `'Body r s` only). So per-trip work that is a *pipeline* must
   be unrolled outside the loop. §4.5 and §6 say where that bites.
2. **`amend` takes an `Ask`, not a call.** A loop whose per-trip work is five
   stages — `wiggum`'s `work → commit → audit → partner-cleanup → restack` — is
   **not** `revisingOn` with five `call_`s in the body, as the M–Z survey's
   construct mapping suggests. It is K unrolled rounds, each round a `call_
   roundFn` behind a `decide` on the previous round's DoD receipt, with
   `costSummary` reporting min 1 round, max K, over K+1 paths. That is a real
   charge, and it is the honest bound the prose refuses to state.

Also here: `mustPass`, the `unless ok stop` terminal that the three sentinel
gates (`alexey`, `deep-review`, `heavy-review` — three slightly different
spellings of one gate) collapse into.

### 2.8 `Workflows.Escalation` — the three-ending ladder

`WORK COMPLETE` / `WORK REMAINS` / `WORK BLOCKED`, one brief and one wiring.
`revisingOn`'s three tags close the gap `Example.Isaac` records twice
(`shipFeatureLiteProgram`, `stackPRsProgram`): approval settles, an objection
amends, **a refusal abandons** — which is the ending `WORK BLOCKED` was invented
for. Nine skills carry an explicit finite verdict set written as prose
(abstraction-review's 5, comment-audit's 7, eliminate-dead-code's 3,
alexey-review's 4, retest's 3+5, forge's 4, fix-all's 2); each becomes a tag set
here, and `retest`'s literal prose demand — "report PASS/SKIPPED/QUARANTINED/
DIVERGE/NO-COVERAGE as distinct states, never collapse them into 'N/N PASS'" — is
a request for a sum type, granted.

One honest note the module's haddock must carry: **with an exec review,
`AbandonedOn` is unreachable**, because the shell table yields approve-or-object
and never refuse (a missing or timed-out command is a *gap*, not a refusal). So
`revising` (two-way) is the right loop for a gate and `revisingOn` (three-way)
is the right loop when the review is a model whose refusal must end the run.

### 2.9 `Workflows.Report` — the output contract

`markdown.md`'s real value: `suggestionsFn` (GitHub suggestion blocks) and
`reportFn` (the consolidated finding report, dedup / severity sort / per-pass
clean statements / smallest-safe-fix order) as `Fn`s called as the **tail of every
review rung**, so the six review commands and the five ladder rungs cannot drift
in their output format. `sec-audit` today carries `deep-review`'s format by prose
reference; here it carries it by calling it.

### 2.10 `Workflows.Functions` — the `defining` tables

The corpus's proven fan-in points, as one `[SomeFn]` table per family, so
`defining` is written once per program and a callee cannot be half-registered:
`commitFn`, `resolveFn`, `bugbotFn`, `reportFn`, `suggestionsFn`, `fessReportFn`,
`cavemanFn`, `journalFn`, `lefthookFn`, `atDispatchV2Fn`, `observationFn`,
`retestFn`. `resolve` is the corpus's clearest existing function (three callers
cite it by name, it takes a parameter, it has one job and a crisp postcondition);
`commit` is the most-referenced node in the A–L half with three in-edges and zero
out-edges; `wiggum`'s "follow their procedure rather than invoking them as slash
commands" is the owner distinguishing a call from an entry point in prose, which
is the strongest single piece of evidence in the corpus that he has been reaching
for `function`/`call` and had no way to say it.

### 2.11 `Workflows.Registry`

`registry :: Registry`, one row per owner-facing name, ordered by family. Rows
are grouped and commented by family so the file reads as the toolbox's index.

---

## 3. The triage, decisive

Classes: **T** = its own agent-cat program · **R** = a program, but the md needs
rethinking first (what, stated) · **K** = keep as md · **F** = folds into another
workflow (host named). Under the maximal-reuse bias **F** is heavy on purpose: a
fold that lands in a shared roster or `Fn` is the payoff, not a demotion.

### 3.1 Commands, A–L (31)

| # | Command | Class | Design, or host |
|---|---|---|---|
| 1 | `alexey` | **F** → `review` | Rung `alexey`: a one-lens roster over `Rubrics.Alexey`, its two 290-line references as `--input-file`. Sentinel gate is `Gates.mustPass`; read-only is structural. |
| 2 | `assess` | **F** → `pr-comments` | Mode `assess` of the comment program (§3.2 #54). Its "and/or across three pros" becomes tier-1 `languagesIn` over the diff. |
| 3 | `bankruptcy` | **F** → `commit` | Rung `bankruptcy`: `gitRevParseTree` receipt before and after, `decide containsLine`, then `call_ commitFn`; the postcondition it never checks becomes the gate. |
| 4 | `breakdown` | **F** → `org-tasks` | Rung `breakdown` over `task-breakdown`'s pipeline. The three escape hatches (`[ATOMIC]`, `[AMBIGUOUS]`, no-expertise) are three `containsLine` deciders and three arms. |
| 5 | `bugbot-stack` | **F** → `bugbot` | Rung `stack`: `gtLs` receipt for the enumeration, then `call_ bugbotFn` per PR with the exclusion policy as an argument rather than a quoted paragraph. |
| 6 | `bugbot` | **T** | The five-phase ledger program, and `bugbotFn` for its three callers. Inventory is a `ghGraphqlThreads` receipt bound once, so mid-run comments structurally cannot enter; phase 4 is `revisingOn` per item at `atMost 2`. |
| 7 | `capture` | **K** | A three-line adapter onto `~/org/wiki/CLAUDE.md`. The interesting logic is outside the corpus. |
| 8 | `cleanup` | **F** → `stack` | Four obligations that are four `Gates.gate`s per branch; the `nix develop --command` hedge disappears because the argv is program-authored. |
| 9 | `code-review` | **F** → `review` + `green` | Read-only half is rung `repo` (a dozen concerns = a twelve-row roster). Its mutating half (writes tests and docs) is authority confusion and belongs behind `green`'s `confirm (person "owner")`. |
| 10 | `commit` | **T** | **Flagship 3.** `commitFn` + four rungs. |
| 11 | `deep-review` | **F** → `review` | Rung `deep`. **This is flagship 1's shape**; the ladder builder is written from this file. |
| 12 | `discover-bundles` | **T** | Reject conditions as deciders that fire before any paid scoring; seven weighted criteria as a `verdictPanel`; candidates as `--input-file`; read-only structural, which is the point on a program reading adversarial text. |
| 13 | `eliminate-dead-code` | **F** → `dead-code` | The command is a thin adapter; the machinery is the skill (§3.3 #13). `cap=N` is literally `atMost`. |
| 14 | `expense-report` | **T** | Person in binding position + `revisingOn` accept/edit/abandon; `REVIEW` flag becomes a decider that gates the build; the spreadsheet is `ask_ (tool "fill" \`running\` …)`. |
| 15 | `fix-alert` | **R** → `nix-host` | *Rework:* naming `caveman` beside a diagnostic skill compresses the very text that decides the diagnosis. Drop it, or make compression an explicit earlier question with its own handle. Then a rung, routed by `anyLineStartsWith` on the alert labels. |
| 16 | `fix-ci` | **F** → `green` | Rung `ci`. **Flagship 2's shape.** Its silent copy of `bugbot`'s protocol becomes `call_ bugbotFn`. |
| 17 | `fix-github-issue` | **F** → `issue` | Rung `worktree` (terminal: leave uncommitted, checked by `decide containsLine status ["Changes not staged"]`). Shares its body with `fix`, which ends the divergent agent roster. |
| 18 | `fix-integration` | **F** → `nix-host` | Rung; today's hardcoded error string becomes a second input with that string as its sample. |
| 19 | `fix-transcript` | **F** → `prose` | Rung. The injection guard is structural: the transcript is a `{hole}`, and at the tool leg the words go to the child's stdin where a splice is data. |
| 20 | `fix` | **T** | The `issue` program (wave 2). Three gates that decide whether any expensive work happens are three deciders; `call_ commitFn` and `call_ bugbotFn` delete two prose copies. |
| 21 | `flaky-rust` | **F** → `green` | Rung `flaky`, whose distinguishing construct is `drawing n` on a `cargo test` party — repeated independent draws priced apart, then a decider over the receipts separating *flaky* from *broken* before any model is consulted. That distinction is the whole task. |
| 22 | `forge` | **F** → `forge` (skill) | The command is a pure entry point and its no-drift clause is exactly right; it becomes one registry row over the skill's program. |
| 23 | `gravity` | **F** → `teams` | Rung `gravity`: three adversarial members on three engines, `documentPanel`. Real only if the owner wants disagreement between critics. |
| 24 | `halt` | **F** → `session` | Rung `halt`: `call_ commitFn`, `call_ reportFn`, one `act` writing to `~/dl` with a receipt. Its emitted `fess` instruction is a define spliced by one hole — a program authoring a prompt, where the boundary is a hole rather than a hope. |
| 25 | `heavy-review` | **F** → `review` | Rung `heavy`. Its four load-bearing guarantees become: one snapshot handle, `Gates.mustPass` on the sentinel, `attestsModel` on the attestation, a total `case` for completeness. |
| 26 | `heavy` | **F** → `effort` | Rung `heavy`. Its one branch is `touches ["*/positron/*","*/pos/*"]` at **tier 1** (free, and no extra path); consensus is a two-member panel. |
| 27 | `infer-tasks` | **F** → `org-tasks` | Rung `infer`. Its thirteen-item self-grading checklist splits: the mechanical half to deciders at zero questions, the judgment half to a differently-`servedBy` second party. |
| 28 | `initialize` | **F** → `claude-md` | Rung `init`. The exists/not-exists branch is `touches ["CLAUDE.md"]` at tier 1; the mandatory prefix is a `lit` that cannot be paraphrased. |
| 29 | `install-service` | **F** → `nix-host` | Rung `install`, with its own ten-`Fn` table. Both capital-letter pleas become `ask_ (person "owner")` terminals the run cannot pass; item 10's "test it works" becomes `systemctl`/`curl` receipts. |
| 30 | `journal` | **F** → `session` | Rung `journal` and `journalFn`. Append-only becomes an argv property. Not worth a program alone; worth being a call from `halt` and `wiggum`. |
| 31 | `lefthook` | **F** → `productize` | `lefthookFn`, which `productize` also calls — one definition, two entry points, and the prose slice cannot drift from the whole. |

### 3.2 Commands, M–Z (36)

| # | Command | Class | Design, or host |
|---|---|---|---|
| 32 | `markdown` | **F** → `Report` | `suggestionsFn`, the tail of every review rung. Being forced to name its input is the fix. |
| 33 | `medium` | **F** → `effort` | Rung `medium`. Same shape as `heavy`, different `atMost` and different `servedBy` — and `costSummary` finally prices the owner's own tier ladder. |
| 34 | `meeting-notes` | **T** | Ten sections = `documentPanel` with the section names as fence labels; the five quality checkpoints become a **separate** panel on a different `servedBy`, because a fact-only discipline audited by the same model is not audited. Wave 2, cheap, high value. |
| 35 | `narrative` | **F** → `session` | Rung `narrative`. Two tiers: a receipt dossier, then one narrative ask over it; "distinguish fact from inference" becomes a `confirm` on another engine over the dossier. |
| 36 | `nix-rebuild` | **F** → `nix-host` | Rung `rebuild`: `ask (tool "build" \`running\` ("./build",["system"]))` is the archetypal receipt, then `Gates.gate`. The failure text stops being something a model rediscovers. |
| 37 | `partner-cleanup` | **F** → `partner` | The drain loop; the sub-agent's "do not commit" becomes structural (`CodeText` has no write authority). |
| 38 | `partner-collaborator` | **T** | The `partner` program. Two panels over one commit: the defect panel with a different engine per member, and the idea panel as `drawing 3` on one lateral party — which is what "three wild ideas" *means*. |
| 39 | `partner-reviewer` | **F** → `partner` | The same program with `ideas` off and `engine` set. Ends an ~85 % duplication that has already drifted (a differing Category enum, a typo on one side). |
| 40 | `prepare-with` | **F** → `claude-md` | Rung `advise`. Its roster argument is G8; here it is a static Haskell table, and its eight negative rules become a real `fess`-style auditor rather than eight unchecked prohibitions. |
| 41 | `process-checklist` | **T** | Ten md lines describing a nested bounded revision with a **free** settle test: `decide containsLine checklist ["- [ ] "]` inverted, zero questions per trip. The best small first transform in the corpus; wave 1 warm-up. |
| 42 | `productize` | **T** | Twenty-one deliverables as a roster priced at 21 before it starts; the five empty table cells become one search question **per language present**, not per deliverable; each deliverable gets a receipt. |
| 43 | `proofread` | **F** → `prose` | Rung `proofread`. The five prohibitions become a second-model diff auditor; the count summary is the receipt. |
| 44 | `push` | **F** → `commit` | Rung `push`: `call_ commitFn` then two `running` acts. Cost is `commit` plus two — a number, where today it is a sentence. |
| 45 | `qanda` | **R** → small **T** | *Rework:* it is a continuation with no named input. Given a decision list as `--input-file`, it is a sequence of `person "operator"` binds each live for the ones after it — `steer`'s proven shape. |
| 46 | `query-builder` | **T** (small) | The corpus's best I3 case: the schema reader is a `tool` party at `CodeText` and therefore cannot act; the data is never in scope to leak; the constraint stated three times collapses into one type. |
| 47 | `quick-review` | **F** → `review` | Rung `quick`. Its ladder paragraph comes from `Rubrics.Ladder`, ending the five-file copy-paste. |
| 48 | `rebase-and-fix` | **F** → `stack` | Rung `rebase-fix`: four `call_`s (`resolveFn`, restack body, `green`, `bugbotFn`). Its unchecked branch↔commit invariant becomes a `gitRangeDiff` receipt. |
| 49 | `rebase` | **F** → `stack` | Rung `rebase`, i.e. `rebase-fix` with the CI/bot tail off. Two commands, one program, two paths, two prices. |
| 50 | `recommit` | **F** → `commit` | Rung `recommit`: the "each commit passes CI standalone" claim becomes a per-commit `Gates.gate`. Cost is `commit` + n .. `commit` + 3n over n paths. |
| 51 | `remove-service` | **F** → `nix-host` | Rung `remove`. Its generate-a-script-do-not-run-it inversion is I3 avant la lettre and becomes the pattern's named exemplar: every discovery question is `CodeText`, the script is one `act`. |
| 52 | `report` | **F** → `session` | Rung `report`. Seven categories as `documentPanel` members; the estimate is a separate question on a separate engine over the *fold*; the metadata-tags idea becomes a prior-report `--input` and a `revisingOn` over it. |
| 53 | `resolve` | **T** (as `Fn`) | `resolveFn`, plus a one-row entry point. Three callers cite it by name today. Postcondition = `gitDiffCheck` receipt read by a pure decider; "do not commit" is structural. |
| 54 | `respond` | **T** | The `pr-comments` program (hosts `assess`). Comment roster is a `ghPrView` receipt; never-posting is an **absence**, not a rule — no party in the program carries a write verb. |
| 55 | `restack` | **T** | **Flagship 5.** |
| 56 | `retest-categorical` | **F** → `retest` | `call retestFn` with the nine override rows as nine arguments. Phase numbers cease to exist, so the documented off-by-one is unrepresentable. |
| 57 | `retest` | **T** | The parameterized battery. Its 674-line spec is `--input-file`, its verdict taxonomy is a total `caseVerdict`, and `costSummary` prices an eight-model FPGA run **before an FPGA is touched**. |
| 58 | `review-github-pr` | **F** → `review` | Rung `pr`: adds the head-OID gate (two receipts compared by a decider, `unless … stop`). Its four shouted prohibitions become zero lines — a prompt that names the four commands it forbids is a prompt containing its own attack. |
| 59 | `run-orchestrator` | **R** → **F** → `wiggum` | *Rework:* steps 5–6 describe a dependency graph the md cannot express. As a Haskell `[(Text,[Text])]` topologically sorted at build time, "identify parallelizable tasks" is a pure computation, not a question. Then it is `wiggum` without the durable state. |
| 60 | `sec-audit` | **F** → `review` | Rung `sec`: three fixed-regex greps as three `running` parties in the dossier, plus one `security-reviewer` ask. The deterministic/probabilistic split, on the command where fabrication costs most. |
| 61 | `sitrep` | **F** → `session` | Rung `sitrep`. Eight sections over a receipt-backed dossier, so `Measurements` cannot invent a number no command produced; the filename scheme is computed in Haskell from receipts, which removes the one thing a model reliably gets wrong here. |
| 62 | `smooth` | **F** → `prose` | Rung `smooth`. "Do not change it overmuch" gets a measure: a restraint gate on another engine asking whether any sentence changed meaning, with `revisingOn` amending toward a lighter touch. `smooth` and `proofread` are two settings of one dial. |
| 63 | `teams` | **T** (small) | The most literal panel in the corpus: eleven-row roster, `documentPanel`, and a synthesis whose refusal roster derives from the same table — with the devil's advocate correctly a **second tier** over the fold, which the bullet list cannot say. `costSummary` says 13 before the run. |
| 64 | `transcribe-image` | **K** | Already the right shape and the only command that reaches for a second model as a check by default. If it grows a stopping rule, it becomes a `prose` rung with `revisingOn (atMost 2)`. |
| 65 | `tron-debug` | **T** (small) | Three `<command>` blocks that are argv waiting to be receipts; the differential's evidence becomes world-authored, so the diagnosis cannot rest on a run that did not happen. |
| 66 | `webfix` | **R** → **F** → `green` | *Rework:* it has a real oracle (Playwright) and spends none of its four lines using it as one. Then rung `webfix`: before/after receipts, settling on the reproduction that stopped reproducing. |
| 67 | `wiggum` | **T** | The top-level program, **last**. See §2.7's second grammar fact: it is K unrolled rounds, not a five-call loop body. |

### 3.3 Skills (25 directories + the external edge)

| # | Skill | Class | Design, or host |
|---|---|---|---|
| 1 | `wiggum` | **T** | The loop, last, wanting its callees. Its durable-state section (three artefacts, re-read-everything-after-compaction) **dissolves**: an agent-cat program *is* the durable plan, priced before it runs. |
| 2 | `parallelize` | **F** → the library | Dissolved. The 10-bullet shared-state list is a hand-written type system for an untyped harness; what survives is `Gates.mustPass` over one sentinel receipt and `Panels` arity priced by `costSummary`. Seven inbound edges, one implementation. |
| 3 | `fix-all` | **F** → `Rubrics.Discipline` | The archetypal standing constraint, spliced into every fixer. Two of its six DoD conjuncts are pure deciders (`anyPathMatches "wg-*"`, `lastNonEmptyLineIs`). |
| 4 | `validated-code-review` | **F** → `review` | Rung `validated`. Its entire attestation apparatus — preflight, `metadata.model_used` verification, the abort-on-substitution rule, the Common-Mistakes table, one Python script — is replaced by `servedBy` + `fallingBackTo` and one decider. |
| 5 | `abstraction-review` | **F** → `review` | Rung `abstraction` + `Rubrics.Evasion` (the seven patterns) + a five-tag `revisingOn`. Its "write the null diff before reading the diff" is a sequenced bind, enforced by `W.do` rather than by self-discipline. Self-check mode = the same roster over your own diff. |
| 6 | `denotational-design` | **T** | Ten phases, each with questions, an artifact and an exit test = ten `documentPanel`/`confirm`/`revisingOn` triples; its "when NOT to use" admission test is a `confirm` gate before the body; 1921 reference lines are `--input-file`, not prompt bulk. Wave 4. |
| 7 | `alexey-review` | **F** → `review` | Rung `alexey`. Twelve review moves = the rubric; four severity gates = four tags; the explicit "engineering-principles dictates WHAT, stance dictates HOW" precedence is two defines composed in a fixed order. |
| 8 | `caveman` | **F** → `prose` + `cavemanFn` | The purest define in the corpus, and the right shape is a **callable** `Fn` — agent-cat's first genuinely reusable prompt combinator. `prompts/emacs.md`'s persona-stacking is a latent call the corpus never makes. |
| 9 | `ponytail` *(external)* | **F** → `Rubrics.Voice` slot | Honor the edge, do not own the text: a rubric slot the owner fills, plus `review` rung `ponytail` and `ponytail-debt` as `anyLineStartsWith ["ponytail:"]` at zero questions. |
| 10 | `forge` | **T** | Near-literal transplant: six phases, an explicit phase/model table, consensus rounds as panels, the approval pause as `ask_`, remediation as `revisingOn` back to phase 3. "Never skip phases" becomes unstatable-otherwise. **Pricing forge before running it is the demo.** Wave 3. |
| 11 | `anvil` | **K** | Empty directory, no `SKILL.md`, no inbound edge. Nothing to port; a greenfield slot to be elicited, not transplanted. |
| 12 | `comment-audit` | **F** → `review` | Rung `comments` + `Evidence.commentInventory` (the extractor's four argv forms). Its 10–15-per-batch context workaround is replaced by an actual cost bound. |
| 13 | `eliminate-dead-code` | **T** | The `dead-code` program: four non-interleavable phases as four `W.do` segments, the three-advocate debate as a three-member `verdictPanel`, `cap=N`/`recent=Nd` as inputs, and "markers never escape" as `containsLine "DCE-BEGIN"` at zero questions. |
| 14 | `toolkit` | **F** → `Rubrics.Discipline` + `effort` | A define and nothing more — but it declares the owner's own unpriced cost model (`medium ⊂ heavy ⊂ forge`), which becomes three programs sharing one rubric at three `costSummary` levels. |
| 15 | `it-voice` | **F** → `Rubrics.Voice` | Voice rubric; its self-check-before-finishing is a `confirm` gate over the draft. `narrative`, `smooth` and `proofread` all use this register and none names it — an edge the library supplies. |
| 16 | `johnw` | **F** → `Rubrics.Voice`, **split** | Two things fused: a generation rubric and a critique function. Splitting them is the level-up; the 487 lines and two references are inputs. |
| 17 | `persian` | **T** | The `translate` program. Five phases, phase 3 an explicit review team = a panel; `TERMS.csv` authoritative over the lossy `PersianTerms.txt` is a real input ordering. |
| 18 | `fix-transcript` | **F** → `prose` | Its substance is a numbered rule-priority list; the two references are lookup corpora → inputs. |
| 19 | `retest` | **T** | See §3.2 #57. Its `MODELS` set derived from the branch diff via four signals is a receipt feeding downstream phases. |
| 20 | `skill-creator` | **K** | Shadowed and dead (`catalog.nix` sources it from the resources flake). Its meta-role is interesting and its successor is this directory. Do not port. |
| 21 | `swiftui` | **F** → `review` + `Parties` | A roster row and a party; its three-branch decision tree is tier-1 Haskell; eleven references are inputs. |
| 22 | `node-red` | **T** | Four Python scripts are four `running` parties. Deeply host-specific; wave 5. Its "supported admin boundary" rides on the question. |
| 23 | `docstring` | **F** → `prose` / `review` | Pure format rubric with a `confirm` tail. Positron audience. |
| 24 | `add-uint-support` | **T** (small) | `pytorch-uint`: a seven-step transformation with a literal decision tree, whose step 1 `confirm` dispatches to `call_ atDispatchV2Fn`. |
| 25 | `at-dispatch-v2` | **F** → `pytorch-uint` | `atDispatchV2Fn`, plus its own entry point. **The corpus's only true skill-calls-skill pair** and therefore its cleanest existing `call_`. |
| 26 | `nixos` | **F** → `Rubrics.Discipline` + `nix-host` | Permission and safety policy, not procedure. In agent-cat it rides on the question and on the `toolExec` argv allowlist, not in prompt text. |

### 3.4 Prompts (2)

| File | Class | Design, or host |
|---|---|---|
| `prompts/emacs.md` | **F** → `Rubrics.Personas` + `effort` | A persona/system rubric; the corpus's only pure "you are an expert who…". Its persona-stacking is the exact bulk `cavemanFn` exists to compress. |
| `prompts/spanish.md` | **F** → `translate` | A one-hole define; becomes `function "translate.spanish" (takes @"text" Text)`. The corpus's clearest existing `{name}` hole. |

### 3.5 Agents (25)

| Group | Members | Class | Design, or host |
|---|---|---|---|
| **F1+F2 reviewers (11)** | `security`, `perf`, `haskell`, `rust`, `cpp`, `python`, `typescript`, `nix`, `bash`, `elisp`, `coq` | **F** → `Rubrics.Reviewers` rows, host `review` | Each row carries rubric sections, globs, tool argv and pin. The eleven copies of the finding schema become one define; the four reviewers with no tool block get one; severity, being a property of *which section a finding falls under*, is static and can be sliced and priced per tier. |
| **F3 `-pro` (9)** | `haskell`, `typescript`, `emacs-lisp`, `nix`, `rocq`, `cpp`, `python`, `rust`, `sql` | **F** → `Workflows.Parties` (+ `Rubrics.Lang` for the four encyclopedias) | Parties, not programs: none contains control flow, a gate, a loop or an output contract. `nix-pro`'s five-step Search Strategy is the one exception and becomes a small verification-gated `Fn` inside `nix-host`. |
| `fess-auditor` | — | **T** | **Flagship 4.** |
| `task-breakdown` | — | **F** → `org-tasks` | The best-shaped file in stratum B: a real analysis→decompose→format pipeline with a completeness gate and three named degenerate cases that are three branches. |
| `prd-architect` | — | **R** → two **T** | *Rework:* it is two agents in one file (generator and critic) selected by an unstated condition, and coupled to a third-party tool. Split at the mode boundary into `prd-draft` and `prd-critique`. Wave 5. |
| `persian-translator` | — | **F** → `translate` | The cleanest `revising` in the corpus: candidate = translation, review = back-translation compared against the source, `atMost n`. Its 50-term glossary is one define; the loop's present unboundedness gets a bound. |
| `prompt-engineer` | — | **K** | No rubric worth moving; superseded in its own directory by the eleven reviewers, and orphaned. Take only its output contract, as a decider, if some program needs one. |

**Tally.** 119 files → **T** 24 (own programs) · **R** 6 (rework named, then folded
or transformed) · **K** 6 · **F** 83. Behind the owner's 67 names sit **≈30
programs**; behind the 30 sits **one** library. That ratio is the proposal.

---

## 4. The five flagships

House conventions used in every sketch: `import Workflows.Prelude`; rubric text
is a define from `Workflows.Rubrics.*` named after its md source; a decision's
tier (§2.6) is named in a comment where it is not obvious.

### 4.1 `review` — the ladder (flagship 1)

**Serves:** `quick-review`, `code-review`, `sec-audit`, `deep-review`,
`heavy-review`, `review-github-pr`, `alexey`, and the six skill lenses
(`abstraction-review`, `validated-code-review`, `ponytail`, `comment-audit`,
`eliminate-dead-code`-as-lens, `alexey-review`). Registered once per rung, so
each rung is priced apart and an unknown rung is a registry miss rather than an
`error` on a CAF.

```haskell
-- workflows/Workflows/Review/Ladder.hs

data Rung = Quick | Repo | Sec | Deep | Heavy | Pr | Alexey

reviewLadder :: Rung -> Parameterized
reviewLadder rung =
  taking (input "scope" (input "paths" noInputs)) \scope paths ->
    -- TIER 1: the whole roster and the whole linter set are decided in Haskell,
    -- before a question exists. `deep-review` Step 2's nine-row table costs zero
    -- questions AND adds no path, and `wf plan` prints the panel that will run.
    let langs  = languagesIn paths                       -- Deciders
        roster = rungRoster rung langs                   -- Rubrics.Reviewers + Rubrics.Ladder
        probes = rungProbes rung langs                   -- Evidence: the seven tool blocks, plus four
     in defining [SomeFn reportFn, SomeFn suggestionsFn] W.do

      -- The frozen snapshot: ONE receipt the world authored, bound once, and
      -- spliced into every member below. `heavy-review`'s "every pass examines
      -- identical code" is this handle, not a sentence.
      snapshot <- ask (tool "scope" `running` scopeArgv scope) [wf|{snapshotBrief}|]

      -- Independence, once, where three md files spell it three ways.
      -- TIER 2: a receipt, then a free decider, then a terminal the compiler requires.
      independent <- probe noHistoryProbe lastNonEmptyLineIs ["NO-HISTORY"] [wf|{sentinelBrief}|]
      when independent $ W.do

        -- The deterministic evidence: hlint, clippy, ruff, mypy, bandit,
        -- shellcheck, statix, deadnix, clang-tidy, cppcheck, Print Assumptions,
        -- and sec-audit's three fixed-regex greps. Receipts, not claims.
        facts <- dossierOver probes [wf|{factsBrief}|]

        -- The panel. One `Ask` per roster row; every brief carries the derived
        -- sibling table (how many reviewers, and what each of the others owns)
        -- and the ONE `findingSchema` define. Each member `servedBy` its own
        -- engine, and the four members that must stay comparable carry no pin.
        found <- documentPanel (withEvidence roster snapshot facts) snapshot

        -- Completeness: `deep-review`'s "confirm all four required passes
        -- completed, else label the report incomplete" as a free decider over
        -- the fenced document's own labels, and a total two-armed branch whose
        -- shared tail is one function both arms call.
        whole <- decide containsLine found (map fenceOpen roster)
        if whole
          then W.do
            call_ reportFn (arg found :> arg facts :> arg (rungLabel rung) :> noArgs)
            stop
          else W.do
            call_ reportFn (arg found :> arg facts :> arg incompleteLabel :> noArgs)
            stop
```

**Where the prompts come from.** `snapshotBrief`, `sentinelBrief`, `factsBrief`
from `Rubrics.Ladder`; every `lensBrief` from `Rubrics.Reviewers` (the eleven
agent files) and `Rubrics.Evasion` / `Rubrics.Alexey` / `Rubrics.Ponytail` (the
six skill lenses); `findingSchema` from `Rubrics.Finding`, holed into all of them;
`reportFn`'s body from `deep-review`'s report template and `heavy-review`'s
consolidation spec, which are today two objects.

**What the operator gets that no md can give:** `wf cost deep-review --input-arg
paths="$(git diff --name-only main)"` — a min, a max and a path count for *this*
diff, before the first token; and `wf plan heavy-review --raw`, which prints the
eleven prompts that will be sent, with the snapshot hole in each.

**Honest cost of the fold.** The rung is chosen in Haskell, so `wf plan` must be
given the same `--input-arg paths=` the run will use or it prices a different
program. `ci/workflows.sh` pins each rung against `rowSample`, which is what makes
that a checked fact rather than a caveat.

### 4.2 `green` — the gated fix loop (flagship 2)

**Serves:** `fix-ci`, `flaky-rust`, `webfix`, `nix-rebuild`'s gate, and the gate
inside every other program.

The load-bearing discovery, verified in `Agentic/Shell.hs`'s answer table: **a
`verdict` question put to a `running` tool approves on exit 0 and objects with
the command's own first failing line on nonzero** — and a command that is missing
or times out is a *gap*, not an answer ("the gate did not say no; it did not
run"). So the whole of check-fix-recheck is a revision whose review clause is the
exit code.

```haskell
-- workflows/Workflows/Fix/Green.hs

greenProgram :: Rung -> Parameterized
greenProgram rung = taking (input "pr" (input "check" noInputs)) \pr checkName ->
  defining [SomeFn bugbotFn, SomeFn commitFn] W.do

    -- The ledger, bound ONCE. Comments arriving mid-run have no way in, which
    -- is `bugbot` phase 5's scoping invariant made structural.
    inventory <- ask (tool "threads" `running` ghGraphqlThreads pr) [wf|{inventoryBrief}|]

    -- The bot protocol `fix-ci` copies in prose, called instead of copied.
    call_ bugbotFn (arg inventory :> arg humansExcluded :> noArgs)

    -- The gate. Three lines, and the objection the repair reads is the CI's own
    -- failing line — not a model's paraphrase of one.
    gated <- revising inventory (atMost repairBudget) \state -> W.do
        checks <- ask (tool "checks" `running` ghPrChecks pr) [wf|{checksBrief}|]
        amend (ask (model "repair" `servedBy` "opus") [wf|
            {repairBrief}
            {codeRule}          -- Rubrics.Discipline
            {noDeferral}        -- fix-all
            {state}
            {checks}|])

    case gated of
      Settled state -> W.do
        call_ commitFn (arg state :> arg ciScope :> noArgs)
        stop
      -- The abandon arm `fix-ci` does not have: the run ends naming the check
      -- still red, and the tree keeps every edit the repairs made.
      Unsettled state -> W.do
        ask_ (tool "report") [wf|{stillRedBrief}{state}|]
        stop
```

* **Rung `flaky`** replaces the check party with `cargo test` under
  `drawing n` — repeated independent draws, priced apart by the memo bill — and
  inserts a tier-2 decider over the collected receipts that separates *flaky*
  from *broken* **before any model is consulted**. That distinction is the whole
  task, and `flaky-rust.md` cannot make it.
* **Rung `webfix`** replaces it with the Playwright runner, so "resolve the
  issues" becomes a reproduction that stopped reproducing.
* **Why `revising` and not `revisingOn`:** with an exec review, `AbandonedOn` is
  unreachable (§2.8). `revisingOn` is the right loop when the review is a model
  whose refusal must end the run — which is `bugbotFn`'s per-item shape.

### 4.3 `commit` — the commit-discipline pipeline (flagship 3)

**Serves:** `commit`, `push`, `recommit`, `bankruptcy`; called by `fix`, `halt`,
`wiggum`, `green`, `stack`. The most-referenced node in the A–L half, with three
in-edges and zero out-edges, and the end of "the `commit` skill or
`$command-commit`".

```haskell
-- workflows/Workflows/Git/Commit.hs

-- The discipline, once: three decomposition principles, six change categories
-- with their dependency ordering, the message format, hunk-granularity staging,
-- and the five-item per-commit checklist — from `commands/commit.md`, verbatim
-- where it is short and summarised where it is a page.
commitFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
commitFn =
  function "commit.series"
    (takes @"scope" Text . takes @"style" Text $ noParams)
    \scope style -> W.do
      series <- ask (model "decompose" `servedBy` "fable") [wf|
          {commitDiscipline}
          {style}
          {scope}|]
      act (tool "stage" `running` ("git", ["add", "--patch"])) [wf|{stagingBrief}{series}|]
      done

commitProgram :: Rung -> Parameterized
commitProgram rung = taking (input "scope" noInputs) \scope ->
  defining [SomeFn commitFn, SomeFn resolveFn] W.do

    -- `bankruptcy`'s postcondition, which it states and never checks.
    before <- ask (tool "tree" `running` gitRevParseTree) [wf|{treeBrief}|]

    call_ commitFn (arg scope :> arg (rungStyle rung) :> noArgs)

    -- `commit.md`'s own per-commit checklist item — "does the code compile and
    -- pass tests at this point?" — as a receipt rather than a question to
    -- oneself. This is `recommit`'s entire content, and its cost is
    -- commit + n .. commit + 3n over n paths.
    gated <- gate makeTest repairBrief (model "repair") before (atMost 3)

    case gated of
      Settled tree -> W.do
        -- The postcondition: the tree is what it was; only the history moved.
        same <- decide containsLine tree [beforeMarker]
        when same $ W.do
          when (rungPushes rung) $ W.do
            act (tool "push" `running` ("git", ["push", "--force-with-lease"])) [wf|{pushBrief}|]
            act (tool "pr"   `running` ("gh",  ["pr", "create", "--fill"]))     [wf|{prBrief}|]
      -- `commit.md`'s own "prefer a slightly larger commit over a broken
      -- repository", expressed as the language's exhaustion semantics rather
      -- than as advice.
      Unsettled tree -> W.do
        ask_ (tool "report") [wf|{largerCommitBrief}{tree}|]
```

### 4.4 `fess` — the audit (flagship 4)

**Serves:** `fess` (which `catalog.nix` aliases to `agents/fess-auditor.md` — one
rubric, two catalog entries over one file, which agent-cat expresses as one
program reachable by two names); called as `fessAuditFn` by `wiggum`, `green`,
`issue` and `dead-code`, which is what `fix-all` and `wiggum` ask for by name.

The file's most agent-cat-shaped paragraph is its independence protocol, and it
is **a gate whose failure downgrades rather than aborts**: "If that attestation
is absent, run the audit but report that its independence was not verified."
Because a branch is terminal, both arms must be written — and under maximal reuse
the shared tail is one function both arms call, exactly `review-lite.report`.

```haskell
-- workflows/Workflows/Audit/Fess.hs

-- The ten sin categories, each with its harm, its rule, its signals and its
-- interrogative, from `agents/fess-auditor.md`. Ten stances, ten engines: one
-- weak category is now visible, where the md asks all ten in one turn.
fessRoster :: Roster
fessRoster = [ stubsAndFakes, vacuousTests, mockDrift, silentFailure, suppressions
             , fallbackSmuggling, specDrift, scopeCreep, docDrift, verificationGap
             , looseEnds ]

-- The five fixed report sections, and the provenance label the two arms differ in.
fessReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
fessReportFn =
  function "fess.report"
    (takes @"findings" Text . takes @"evidence" Text . takes @"provenance" Text $ noParams)
    \findings evidence provenance -> W.do
      act (tool "write-audit") [wf|
          {fessReportShape}
          {provenance}
          {findings}
          {evidence}|]
      done

fessAudit :: Parameterized
fessAudit = taking (input "subject" noInputs) \subject ->
  defining [SomeFn fessReportFn] W.do

    -- Every "quote the command and the relevant output" demand, answered by the
    -- world: the test run, the coverage run, the grep for suppressions, the
    -- grep for skips and xfails. The md can only ask for these.
    evidence <- dossierOver fessProbes [wf|{evidenceBrief}|]

    -- The independence attestation: a receipt plus a zero-question decider,
    -- where the md has a paragraph the parent may simply not supply.
    attested <- probe noHistoryProbe lastNonEmptyLineIs ["NO-HISTORY"] [wf|{sentinelBrief}|]

    -- Ten stances, ten engines, one fenced document — with the anti-manufacturing
    -- guards ("don't resolve uncertainty by claiming none, and don't resolve it
    -- by manufacturing a sin") in the roster's shared preamble.
    findings <- documentPanel (withEvidence fessRoster subjectV evidence) subjectV

    -- The downgrade, not the abort. Two arms, one callee, one argument apart.
    if attested
      then W.do
        call_ fessReportFn (arg findings :> arg evidence :> arg independenceVerified :> noArgs)
        stop
      else W.do
        call_ fessReportFn (arg findings :> arg evidence :> arg independenceUnverified :> noArgs)
        stop
  where subjectV = subject   -- the audited change, supplied at --input
```

### 4.5 `stack` — restack and the git family (flagship 5)

**Serves:** `restack`, `rebase`, `rebase-and-fix`, `cleanup`, and `resolve` as a
`Fn`. The best-engineered command in the M–Z range, and every piece of its rigour
is currently requested rather than held.

```haskell
-- workflows/Workflows/Git/Stack.hs

resolveFn :: Fn '[ 'CodeText] 'CodeText
resolveFn =
  function "git.resolve" (takes @"agents" Text $ noParams) \agents -> W.do
    merged <- ask (model "resolve" `servedBy` "fable" `fallingBackTo` "opus") [wf|
        {resolveBrief}      -- preserve the incoming semantics AND the current intent
        {orthogonalRule}    -- restack step 4: combine both sides, do not pick one
        {agents}|]
    answer merged

stackProgram :: Rung -> Parameterized
stackProgram rung = taking (input "target" (input "agents" noInputs)) \target agents ->
  defining [SomeFn resolveFn, SomeFn commitFn] W.do

    -- Step 1: the baseline. A receipt bound at the top and LIVE FOR THE WHOLE
    -- RUN, which is what makes step 9's proof possible without trusting memory.
    baseline <- ask (tool "baseline" `running` gtLsWithTips) [wf|{baselineBrief}|]

    -- Step 7's fixpoint: `main` moved, so go back to step 2. The outer loop's
    -- review is `gt ls` at verdict — exit 0 when the stack is current.
    settled <- revising baseline (atMost 3) \state -> W.do
        current <- ask (tool "current" `running` ("gt", ["ls", "--stack"])) [wf|{currentBrief}|]
        -- Step 4 + step 5: resolve, then verify BEFORE proceeding. Both live in
        -- the amendment's single question, because a revision body holds exactly
        -- one review and one amend (§2.7).
        amend (ask (model "restack" `servedBy` "fable") [wf|
            {restackBrief}
            {rerereNote}
            {state}
            {current}
            {agents}|])

    case settled of
      Settled state -> W.do
        -- Step 5, properly: each resolution verified by a real build, with the
        -- build's own failing line as the objection.
        built <- gate (nixFlakeCheck) repairBrief (model "repair") state (atMost 3)
        case built of
          Settled tree -> W.do
            -- Step 9: the proof. A `git range-diff` receipt compared against the
            -- step-1 handle, by a decider that costs nothing. This is the
            -- evidence in the program rather than in the report's prose.
            proof <- ask (tool "proof" `running` gitRangeDiff) [wf|{proofBrief}{baseline}{tree}|]
            intact <- decide containsLine proof ["=  "]
            when intact $ W.do
              when (rungSubmits rung) $
                act (tool "submit" `running` ("gt", ["submit", "--stack"])) [wf|{submitBrief}{proof}|]
          Unsettled tree -> W.do
            ask_ (tool "report") [wf|{stillRedBrief}{tree}|]
      Unsettled state -> W.do
        ask_ (tool "report") [wf|{fixpointNotReachedBrief}{state}{baseline}|]
```

**What this flagship proves that the other four do not:** a live baseline handle
across an entire branching program, a nested gate inside a fixpoint loop, a `Fn`
with three callers, and step 9's mechanical proof-of-no-loss. It is also the one
that most clearly shows the grammar's charge: `restack`'s step 5 wants a
*verify-then-proceed* inside each trip, and a revision body holds one review and
one amendment, so the verification lives in the amendment's prompt and the real
build gate stands outside the loop. That is written above, not hidden.

---

## 5. The invocation story

### 5.1 The verbs

Identical to `agentic-run`'s, because it *is* `agentic-run`'s (§1.2), plus `list`:

```
wf list                                     # every key, its one-line doc, its price ceiling
wf plan  <name> [inputs] [--raw]            # level, size, askNodes, cost — and with --raw,
                                            #   every prompt that will be sent, holes filled
wf cost  <name> [inputs]                    # costSummary: cheapest bill, dearest bill, paths
wf run   <name> [inputs] --scripted         # answer from the row's canned table; ask nobody
wf run   <name> [inputs] --engine acp --adapter claude|codex [--adapter-arg …]
wf run   <name> [inputs] --session <pane>   # every question to one agent-deck pane
```

Inputs use the three flags already built: `--input FILE` when the program takes
exactly one, `--input-file NAME=FILE`, `--input-arg NAME=VALUE`.

### 5.2 A day

```bash
# Before spending anything: what does this review cost on THIS diff?
wf cost deep-review --input-arg scope=main \
                    --input-arg paths="$(git diff --name-only main)"
#   level branch · size 61 · askNodes 14 · cost 6..14 over 4 paths

# Cheaper rung, same library, same output format:
wf cost quick-review --input-arg scope=main --input-arg paths="$(…)"
#   level pipeline · size 9 · askNodes 5 · cost 5..5 over 1 path

# See the actual prompts before sending them:
wf plan deep-review --raw --input-arg … | less

# Run it against Claude:
wf run deep-review --engine acp --adapter claude \
       --input-arg scope=main --input-arg paths="$(git diff --name-only main)"

# The gate loop, against codex, with the CI's own failing line driving repair:
wf run fix-ci --engine acp --adapter codex --input-arg pr=1284

# The commit series, in the deck pane I am already watching:
wf run commit --session 7 --input-arg scope=working-tree

# A dry run of anything, for free, to see its shape and both bills:
wf run heavy-review --scripted --input-arg …
```

### 5.3 What `plan` and `cost` give him that nothing does today

Four things the survey found the corpus guessing at, and one it found it cannot
say at all:

* **`comment-audit`'s 10–15-per-batch loop, `wiggum`'s post-compaction re-read,
  `forge`'s "keep artifacts in context", `parallelize`'s cap of 3–5** are four
  hand-rolled context budgets, all guessing at a number `costSummary` computes.
* **The effort ladder** (`toolkit`'s `medium ⊂ heavy ⊂ forge`, `retest`'s four
  skip flags, `eliminate-dead-code`'s `cap=N`) is the owner's own cost model,
  unpriced. `wf cost medium` and `wf cost heavy` are two numbers.
* **`retest-categorical`** costs hours of FPGA time and is priced by nothing.
  `wf cost retest-categorical` is the operational win.
* **No file in the corpus can say what a review costs.** `wf cost` says min, max
  and path count from the program text.

### 5.4 Reaching it from the slash commands

Out of scope for this repository and stated so it is not forgotten: the corpus is
the owner's live config and is not touched here. When he wants the bridge, each
md becomes a two-line stub naming the `wf` invocation, and `workflows/README.md`
carries the exact line for every registry key so the stub is a copy-paste. Until
then, `wf` is a second front door and the md files keep working unchanged — which
is also the safest migration: a rung can be trusted against the md it replaces
before the md is retired.

---

## 6. The roadmap, in build order

Batched so that each wave lands a gate and so that no wave depends on a later
one. Waves are sequential; items inside a wave are independent.

**Wave 0 — the seam (no workflows).**
`Agentic.Cli` extracted from `run/Main.hs` and parameterized by `Registry`;
`run/Main.hs` reduced to its registry; `scriptFor` moved beside the programs;
`ci/examples.sh` re-run to prove not one field moved. Then the `workflows`
library and `wf` stanzas, an empty registry, and `ci/workflows.sh`. **Gate:** both
binaries build, `agentic-run` is byte-identical in behaviour, `wf list` is empty
and says so.

**Wave 1 — the library, and the two flagships that exercise it most.**
`Prelude`, `Parties`, `Deciders`, `Evidence`, `Panels`, `Gates`, `Report`,
`Functions`, `Rubrics.{Finding,Reviewers,Ladder,Discipline}`. Then **flagship 1
(`review`, all seven rungs)** and **flagship 2 (`green`, three rungs)**. Warm-up
first: `process-checklist`, which is ten md lines and exercises `revising` plus a
free decider end to end. **Gate:** `ci/workflows.sh` green on ten rows; the
eleven-reviewer finding schema exists once.

**Wave 2 — the git family and the audit.**
`Rubrics.Fess`; **flagship 3 (`commit`, four rungs)**, **flagship 5 (`stack`,
four rungs + `resolveFn`)**, **flagship 4 (`fess`)**, and `bugbot` (+ `stack`
rung). Then the two that fall out for a page each and test the maximal-reuse
claim: `teams` and `meeting-notes`. **Gate:** `resolveFn` has three call sites and
`commitFn` has four; if either needed a variant, the library is wrong.

**Wave 3 — the document and prose families.**
`Rubrics.Voice` (with `johnw` split); `session` (halt, sitrep, report, journal,
narrative — five rungs over one evidence dossier), `prose` (proofread, smooth,
fix-transcript, caveman, + `cavemanFn`), `pr-comments` (respond, assess),
`org-tasks` (infer-tasks, breakdown, task-breakdown), `claude-md` (initialize,
prepare-with), `effort` (medium, heavy). **Gate:** one dossier builder serves five
`session` rungs; `Rubrics.Ladder` is the only place the five-rung paragraph exists.

**Wave 4 — the long ones and the host family.**
`issue` (fix, fix-github-issue), `partner` (three commands, one program),
`dead-code`, `discover-bundles`, `nix-host` (install-service, remove-service,
nix-rebuild, fix-alert, fix-integration), `forge`, `productize` (+ `lefthookFn`),
`expense-report`, `qanda`, `query-builder`. **Gate:** the `partner` pair's
duplication is gone and its Category enum exists once.

**Wave 5 — Positron, and the top of the loop.**
`retest` + `retest-categorical` (the nine-argument call), `tron-debug`,
`pytorch-uint` + `atDispatchV2Fn`, `denotational`, `translate` (persian +
spanish + persian-translator's glossary), `prd-draft` / `prd-critique`,
`node-red`, and finally **`wiggum`** (+ `run-orchestrator`), which wants every
callee above and which is K unrolled rounds rather than a five-call loop body
(§2.7). **Gate:** `wf cost wiggum` reports a finite worst case — the one number an
autonomous loop must have before it starts and does not have today.

**Deliberately never built:** `capture`, `transcribe-image`, `prompt-engineer`,
`skill-creator`, `anvil`, and the nine `-pro` agents as programs. Six keeps and
nine parties; each is a line in §3 saying why.

---

## 7. Three things this proposal would be wrong about, and how you would know

Stated so the bake-off can settle them rather than argue them.

1. **The roster type may be too general.** `Lens` is asked to serve eleven
   reviewers, ten sins, twelve team roles and twenty-one build deliverables. If
   `productize`'s rows need a fourth and fifth field that no reviewer wants, the
   right answer is two types, not one with `Maybe`s. **You would know at wave 3**,
   when `session` and `productize` land: if either needs `Lens` widened, split it.
2. **Rungs may hide differences that matter.** Folding six review commands into
   one builder is the proposal's boldest claim. If `heavy-review`'s attestation
   contract or `review-github-pr`'s head-OID gate cannot be a rung's extra
   statement without contorting the others, they should be separate programs
   sharing the roster and the `Fn`s — which costs nothing, because the library
   is where the reuse lives. **You would know at wave 1.**
3. **Tier-1 deciding may be too clever.** Choosing the roster in Haskell from
   `--input-arg paths=` is free and visible in `plan`, but it means the program
   text differs per invocation and the owner must supply the paths. If he will
   not, the honest fallback is tier 2 — `anyPathMatches` deciders that cost zero
   questions and multiply paths — and `costSummary` will say exactly what that
   costs. **You would know the first week he uses it.**
