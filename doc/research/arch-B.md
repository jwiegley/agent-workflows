# `workflows/` — the architecture, operator-first

**Bias, deliberately assigned and honestly held: OPERATOR-FIRST.** Everything
below is designed from the owner's fingers backward. The three questions I asked
of every decision were: *what does he type?*, *what does he know before he
spends?*, and *how many new ideas does this workflow make him hold at once?*
Where a more elegant arrangement cost a flag, a `cd`, or a concept, I took the
uglier one. Where the language offered two constructs that do the same job, the
sketches below use the one already proven in `Example.Isaac`, so that the first
five programs teach five things and not fifteen.

Three consequences run through the whole document and are worth stating before
the detail:

1. **`plan` and `cost` are a contract, not a report.** A workflow whose price is
   a range over 43 paths is a workflow the owner cannot decide about. So the
   flagship programs are shaped to be *cheap to price*: rosters are selected in
   ordinary Haskell (before the `Program` exists), not by nine nested routers,
   so `wf cost review` answers with one number and not a spread.
2. **Zero-argument invocation from inside the repo is the target.** Facts about
   the world — the diff, the branch, the PR, the check status — arrive as
   `running` receipts the world authors, not as flags the owner types. `--input`
   is reserved for what the world cannot know: the task, the scope, the tier.
3. **The toolbox is not conformance.** It churns weekly. It gets its own
   executable, its own registry, and a gate whose remedy is one command.

---

## 1. Integration: how `workflows/` lives in the repo

### 1.1 The registry question, answered

**Neither. Split the registry; share the CLI.**

`agentic-run` keeps the `examples` registry. A new executable, **`wf`**, owns
the workflows registry. Both `main`s are two lines over one extracted
`Agentic.Cli`, parameterised by a `Registry` record. Five reasons, in the order
they weigh:

1. **The gate would invert.** `haskell/ci/examples.sh` is a hand-written table
   pinning `level`, `size`, `askNodes`, `costSummary` and both bills for
   *every registered program*, and its own header says why: "A new program
   cannot be registered without being priced." That is exactly right for seven
   fixtures whose numbers are evidence about the language. It is exactly wrong
   for a toolbox the owner edits on a Tuesday because a reviewer's rubric needs
   a sentence. Merging turns a green gate into a chore, and a gate that fails
   routinely stops being read — which costs the *examples* their gate, not just
   the workflows.
2. **The two products have different defaults, not different rows.**
   `agentic-run run … --engine acp` runs argv in a *fresh temporary directory*
   (`ShellConfig.shellCwd`, set from `--scratch`, defaulted to a new scratch)
   — correct for a self-contained example, and wrong for every one of the
   owner's workflows, which are about *this repository, right here*. `wf run`
   must default `--scratch` to `$PWD` and default `--require-pinned` **on**.
   Those are product decisions, and a shared registry would force one product
   to carry the other's defaults.
3. **The namespace belongs to the operator.** `wf ls` should print fifteen verbs
   the owner recognises. `agentic-run`'s usage line should print seven fixtures
   the conformance story names. One `<example>` slot cannot be both, and the
   moment it tries, the usage text stops being usable.
4. **Blast radius.** A half-written workflow must not break `tier1`, `ci/acp.sh`,
   `ci/deck.sh` or `ci/examples.sh`. Separate components mean
   `cabal build agentic:examples` is untouched by anything under `workflows/`.
5. **What actually wants sharing is the CLI, not the registry.** `run/Main.hs`
   is ~1,200 lines of verb parsing, input flags, engine selection, exit codes
   and printing. *That* is what would drift if duplicated. Extracting it is the
   move; sharing the registry is not.

**The extraction is safe by construction, and that is the argument for doing it
now.** `agentic-run`'s observable behaviour is already pinned end to end by
three gates that drive the binary itself — `ci/examples.sh` (plan/cost/run over
every example), `ci/acp.sh` and `ci/deck.sh` (the transports against the two
fixture doubles). An extraction that changed anything fails them.

```haskell
-- src/Agentic/Cli.hs  (new module in the main library)
data Registry = Registry
  { regBinary  :: Text                       -- "agentic-run" | "wf"; the usage banner
  , regNoun    :: Text                       -- "example" | "workflow"
  , regEntries :: [(Text, Example)]
  , regBlurb   :: Text -> Maybe Text         -- the one line `ls` prints
  , regScript  :: Text -> [(Text, Text)]     -- the canned table --scripted answers from
  , regDefaults :: RunDefaults               -- scratch, require-pinned, timeout
  }

cliMain :: Registry -> IO ()
```

```
run/Main.hs   =  main = cliMain Agentic.Cli.examplesRegistry   -- unchanged behaviour
wf/Main.hs    =  main = cliMain Workflows.Registry.registry
```

### 1.2 The components

```
haskell/agentic.cabal
  library                     src/            + Agentic.Cli          (new module)
  library examples            example/        unchanged
  library workflows           workflows/      NEW internal library
  executable agentic-run      run/            main = cliMain examplesRegistry
  executable wf               wf/             NEW; main = cliMain workflowsRegistry
```

An **internal library**, for the same reason `examples` is one: two components
must see the same `Workflows.Rubrics.findingSchema` and not two separately
compiled copies of it. `wf` runs it; a future `ci/workflows.sh` prices it; a
future test module may read a roster and assert its arity. Compiling it twice
would let those drift under a flag and read as agreement anyway.

`workflows/` is placed under `haskell/` and not at the repository root, because
cabal resolves a module name to a path and `Workflows.Review` must be
`haskell/workflows/Workflows/Review.hs`. (If the owner wants `/workflows` at the
top level for muscle memory, `hs-source-dirs: ../workflows` works and costs
nothing; I recommend against it only because every other component in this
repository lives under `haskell/`.)

### 1.3 Module layout and naming

```
haskell/workflows/Workflows/
  Prelude.hs        re-exports Agentic.Workflow + the six foundation modules;
                    one import per workflow module, and the one place
                    RebindableSyntax's needs are documented
  Parties.hs        WHO answers: model pins, -pro parties, argv parties, people
  Rubrics.hs        WHAT the prompts say: every define harvested from the corpus
  Panels.hs         the fan-outs: rosters -> [Ask s] / [(Text, Ask s)]
  Gates.hs          the loops and the free tests: check-fix-recheck, deciders
  Report.hs         the output: findingSchema, the document folds, report fns
  Registry.hs       the toolbox index: name -> Example, blurb, script table
  --- one module per workflow, named for the verb the operator types ---
  Review.hs  Green.hs  Commit.hs  Fess.hs  Forge.hs
  Fix.hs  Stack.hs  Tasks.hs  Sitrep.hs  Partner.hs  ...
```

**Naming rule, operator-first: the module is named for the verb, and the verb is
what the owner types.** `Workflows.Review` exports `reviewProgram` and registers
as `"review"`; `wf review` runs it. No workflow is named after the Markdown file
it replaces when that name is longer than the thing it does (`heavy-review`,
`quick-review`, `sec-audit`, `review-github-pr` and `code-review` are all
`wf review` at five tiers), and no two workflows differ only in a flag.

### 1.4 The pricing gate

`ci/workflows.sh`, modelled on **`lake exe corpus-gen`'s discipline rather than
`ci/examples.sh`'s**: regenerate and expect no diff, with a one-command remedy.

```sh
wf prices --write     # regenerates workflows/PRICES.md from the registry
wf prices --check     # exit 1 if the committed file differs   <- ci/workflows.sh
```

`workflows/PRICES.md` is a generated table — name, level, size, askNodes,
min/max/paths, scripted billFresh/billMemo, inputs — committed alongside the
code. A workflow edit that moves a price shows up as a **reviewable diff in one
file** with `wf prices --write` as the fix, instead of a red build with a
hand-edited table. The owner gets the pricing discipline (nothing is registered
without being priced; nothing changes price silently) without the editing tax
that would make him stop reading the gate.

---

## 2. The shared foundation

This is D1's payoff at scale, and the corpus's own numbers say how large it is:
one finding schema in **eleven** copies (nine byte-identical), one review-ladder
paragraph copy-pasted into **five** files, one `parallelize` sentinel gate in
**three** spellings, `resolve` cited by **three** callers as prose, `commit`
cited by **three**. Six modules, built once, called by everything.

### 2.1 `Workflows.Parties` — who answers

```haskell
-- Models, with the corpus's pins made properties of questions.
fable, opus, gpt55, gemini3, opencode :: Text

-- A -pro agent is a party, not a program (agents.md §5 col. 2).
haskellPro, cppPro, rustPro, pythonPro, tsPro, nixPro, elispPro, sqlPro
  :: Text -> Party 'IsModel        -- the lens name it answers under
haskellPro n = model n `servedBy` fable `fallingBackTo` opus

-- Argv parties: the world authors the receipt.  Never `sh -c`.
gitDiff, gitStatus, gitTree, ghChecks, ghComments, gtList, nixCheck, makeTest
  :: Text -> Party 'IsTool
gitDiff n  = tool n `running` ("git", ["diff", "--unified=5", "HEAD"])
ghChecks n = tool n `running` ("gh",  ["pr", "checks"])

-- People, with the addressee in the program so a gate says who is asked (I6).
owner, operator :: Party 'IsPerson
```

This module absorbs **all nine `-pro` agents** and the `nixos` skill's three
hard prohibitions: permission belongs to the question, so "never seize the
`.nixos-build` lock" is an argv that does not take it, not a sentence hoping to
be obeyed.

### 2.2 `Workflows.Rubrics` — what the prompts say

Every `[wf|…|]` define harvested from the corpus, each one named for the file it
came from, each one holed rather than concatenated. The load-bearing entries:

```haskell
findingSchema  :: Text     -- ONE copy of the eleven (agents.md §3.1)
findingSchemaWithSound, findingSchemaConfident85, findingSchemaImpact :: Text
                           -- the three real variants, spliced where they belong

-- The eleven reviewer lenses, verbatim, one per agent file.
reviewerLens :: [(Text, Text, Text)]   -- (name, serving model, lens body)

-- Standing constraints, spliced into every fixer.
codeRule, fixAllRule, toolkitRule, ponytailSlot :: Text

-- Voices, mutually exclusive and selected by input.
itVoice, johnwVoice, johnwNeverList, docstringFormat :: Text

-- The ladder, ONE value from which every rung's "see also" text derives —
-- `qaFence`'s derived-roster trick applied to the corpus's own navigation.
ladder :: [(Text, Text)]
ladderText :: Text -> Text        -- "see also" for the rung named, minus itself

-- The corpus's first genuine prompt combinator (caveman, skills.md #8).
cavemanFn :: Fn '[ 'CodeText] 'CodeText
```

**Rule for this module: a rubric is text and holes, and it asks nobody.** If a
harvested thing wants to make a decision, it belongs in `Gates`; if it wants to
fan out, it belongs in `Panels`.

### 2.3 `Workflows.Panels` — the fan-outs

Rosters are ordinary Haskell tables and the briefs derive from them, so a lens
added to a table arrives in its own prompt *and* in the synthesis's refusal
roster by being added — `grindLensRoster` / `grindSynthesisBrief` exactly.

```haskell
-- The eleven reviewers, filtered by what the diff actually touches.
reviewRoster  :: KnownIx h s => Tier -> Text -> V h 'CodeText -> [(Text, Ask s)]
--                              ^tier   ^the changed-path list, matched in HASKELL

-- fess-auditor's ten sins, one stance each (agents.md §5 col. 1).
fessRoster    :: KnownIx h s => Text -> V h 'CodeText -> V h 'CodeText -> [(Text, Ask s)]
--                              ^the independence label the whole panel carries

-- teams.md's twelve bullets, minus the twelfth (which is a second tier).
teamRoster    :: KnownIx h s => V h 'CodeText -> [(Text, Ask s)]

-- forge / heavy's multi-model consensus.
consensusRoster :: KnownIx h s => Tier -> V h 'CodeText -> [(Text, Ask s)]

-- Every synthesis brief refuses on the roster it was built from.
synthesisOver :: [(Text, Text)] -> Text
```

**The tier/language filter runs in Haskell, before the `Program` exists.** This
is the single most operator-visible design decision in the proposal. Nine
language gates as nine `decide AnyPathMatches` routers would be nine nested
terminal `if`s and 2⁹ tails; as a Haskell filter over the roster it is one
`panelText` statement, level `pipeline`, **one path, one exact price**. The
detection is not lost — it moves to where `wf cost` can already see it.

### 2.4 `Workflows.Gates` — the loops and the free tests

```haskell
-- check-fix-recheck, in one shape, over a real exit code.
--   The review clause is a `running` party at `verdict`: exit 0 approves and
--   settles, nonzero objects with the command's own first failing line and
--   amends, and the case is total so the abandon arm is written.
gateOn :: (KnownIx h s, KnownCode c)
       => (Text, [Text])            -- the argv the world runs each trip
       -> Text                      -- the fixer's brief
       -> V h c -> Bound -> LoopOn c s

-- The comparisons the corpus writes as prose. NOTE: `decide`'s needles are
-- literal program text and never holes, so "is the tree the same as before"
-- is not a decider — it is an argv whose exit code is the answer.
sameTree, noConflictMarkers, worktreeClean, headIsPrOid :: Party 'IsTool
sameTree = tool "tree-same" `running` ("git", ["diff", "--quiet", "--cached", "HEAD"])

-- parallelize's sentinel, authored once, in three spellings no longer.
historyProbe :: Party 'IsTool
independent  :: KnownIx h s => V h 'CodeText -> Rhs s 'CodeFlag
independent p = decide LastNonEmptyLineIs p ["NO-HISTORY"]

-- The corpus's latent zero-question deciders, named (skills.md §5).
noOrphans, markersContained, hasPonytailDebt, checklistComplete, botsAllResolved
  :: KnownIx h s => V h 'CodeText -> Rhs s 'CodeFlag
```

### 2.5 `Workflows.Report` — the output

```haskell
-- The report shape every review rung shares, so the five rungs cannot drift.
reportFn        :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
suggestionsFn   :: Fn '[ 'CodeText] 'CodeAck      -- commands/markdown.md, promoted
observationFn   :: Fn '[ 'CodeText, 'CodeText] 'CodeAck   -- partner-* file contract
gradeMap        :: Text                            -- P0->critical, P1->high/medium, P2->low
fixOrderBrief   :: Text                            -- heavy-review's closing "smallest safe fix order"
```

### 2.6 `Workflows.Registry` — the toolbox index

```haskell
registry :: Registry
entries  :: [(Text, Example, Text)]   -- name, program, the one line `wf ls` prints
script   :: Text -> [(Text, Text)]    -- canned replies, keyed by the defines themselves
```

The script table keys are **the prompt defines themselves**, never a copy of
their first line — `Example.Isaac`'s rule, and the reason a `--scripted` rehearsal
of every workflow stays correct as rubrics are edited.

---

## 3. The triage, decisive

Classes: **TRANSFORM** (an agent-cat program) · **REWORK** (a program, but the md
needs rethinking first — the rethink is named) · **KEEP-AS-MD** (honestly not a
workflow) · **FOLD-IN** (a function or rubric inside another workflow; the host
is named).

### 3.1 Commands (67)

| # | Command | Class | Program / host | Construct design (two lines) |
|---|---|---|---|---|
| 1 | `alexey` | FOLD-IN | `wf review` | One panel member carrying `alexey-review`'s 12 moves; its two rubrics composed in the file's own stated precedence. Its four severity gates are the `revisingOn` tag set `wf fix` consumes. |
| 2 | `assess` | FOLD-IN | `wf respond` | Same body as `respond`, different terminal: analysis vs. drafted answers. The "and/or" over three `-pro` agents becomes roster selection over the diff, in Haskell. |
| 3 | `bankruptcy` | FOLD-IN | `wf commit` (`mode=bankruptcy`) | `call_ commitFn` between two `git rev-parse HEAD^{tree}` receipts; the unchecked postcondition becomes `confirm sameTree` with `unless … stop`. The conflict clause becomes `revisingOn (atMost 3)` with an abandon arm. |
| 4 | `breakdown` | TRANSFORM | `wf tasks` (`mode=breakdown`) | One generator ask; the five shape rules become `anyLineStartsWith` / `containsLine` / `lastNonEmptyLineIs` at zero questions. `revisingOn`: settle on shape, amend with the violated rule spliced, abandon; `[ATOMIC]`/`[AMBIGUOUS]` are arms. |
| 5 | `bugbot-stack` | FOLD-IN | `wf green` (`scope=stack`) | `gt ls -s` receipt is the ledger, bound once; the per-PR body is `call_ botSweep` with the exclusion policy as an argument. An exhausted revision **yields**, so a partial sweep still reports. |
| 6 | `bugbot` | FOLD-IN | `wf green` (`botSweep`) | The `gh api graphql` inventory is a receipt the program did not author; every later phase reads *that* handle, so a mid-run comment structurally cannot enter. Per item `revisingOn (atMost 2)` settling on an `isResolved: true` receipt. |
| 7 | `capture` | KEEP-AS-MD | — | A three-line adapter onto a wiki's own `CLAUDE.md`. The interesting logic is out of scope; a program adds ceremony and nothing else. |
| 8 | `cleanup` | FOLD-IN | `wf stack` (`mode=cleanup`) | Four obligations, four `running` receipts (lefthook, `make format`, `git diff --name-only`, `gt restack`). "Absorb the formatter output" is an `if` on a decider at zero cost; the `nix develop` hedge disappears because the argv is program-authored. |
| 9 | `code-review` | FOLD-IN | `wf review` (`tier=repo`) | The dozen concerns are twelve roster rows over one snapshot handle. The mutating half (new tests, doc edits) leaves the review entirely and becomes `wf fix` behind `confirm (person "owner")`. |
| 10 | `commit` | **TRANSFORM** | **`wf commit`** (flagship 3) | `commitFn` with `takes @"scope"`/`@"style"`, called by three other programs. The per-commit checklist becomes a build receipt gating the next commit. |
| 11 | `deep-review` | FOLD-IN | `wf review` (`tier=deep`) | The nine-row extension table becomes roster selection in Haskell; the conditional security pass becomes a roster row, not a branch. The completeness gate is a decider whose false arm writes no report. |
| 12 | `discover-bundles` | TRANSFORM | `wf bundles` | Six hard-reject conditions are deciders that fire *before* any paid scoring; seven weighted criteria are a panel over one candidate handle. Read-only is structural: a scorer that never `act`s cannot run an installer. |
| 13 | `eliminate-dead-code` | TRANSFORM | `wf dead` | Four non-interleavable phases are four `W.do` segments; the three-advocate debate is a `panel` of three folded to one verdict. `cap=N` *is* `atMost`; "markers never escape" is `containsLine "DCE-BEGIN"` at zero questions. |
| 14 | `expense-report` | TRANSFORM | `wf expense` | Receipts are `--input`; one extraction ask per receipt folded by `panelText` into the confirmation table. `person "owner"` in **binding position** drives `revisingOn`: accept→settle, edit→amend (correction spliced), abandon→stop. |
| 15 | `fix-alert` | REWORK | `wf nix` (`mode=alert`) | **Rework first:** naming `caveman` beside a diagnostic skill compresses the very evidence the diagnosis needs — drop it from the diagnostic path. Then: alert text is an input, its labels route via `anyLineStartsWith` at zero cost. |
| 16 | `fix-ci` | **TRANSFORM** | **`wf green`** (flagship 2) | The unbounded monitor becomes `revisingOn (atMost n)` over a `gh pr checks` receipt whose exit code is the review verdict; the silent copy of `bugbot` becomes `call_ botSweep`. |
| 17 | `fix-github-issue` | FOLD-IN | `wf fix` (`mode=worktree`) | Shares `fix`'s body; only the terminal differs. "Leave it uncommitted" stops being an instruction and becomes a postcondition: a `git status --porcelain` receipt read by a decider. |
| 18 | `fix-integration` | KEEP-AS-MD | — | A situational one-shot whose hardcoded error string is the point. If ever generalised, the error becomes a second input with today's string as its `Example`. |
| 19 | `fix-transcript` | FOLD-IN | `wf prose` (`mode=transcript`) | The numbered rule-priority list is one rubric define; the two reference corpora are inputs. The injection guard is structural — the transcript arrives as a `{hole}`, which is data with three meanings and no fusion. |
| 20 | `fix` | TRANSFORM | `wf fix` | Three cheap gates decide whether *any* expensive work happens: `containsLine` over a `gh pr list` receipt (PR open), `anyPathMatches` (confirmation-test migration), a status receipt (already fixed) — each feeding an `if` whose false arm is `stop`. `call_ commitFn`, `call_ botSweep`. |
| 21 | `flaky-rust` | FOLD-IN | `wf green` (`mode=flaky`) | `tool "test" \`running\` ("cargo",["test",…]) \`drawing\` n` — n independent draws are n questions, priced apart, which is the entire notion of flakiness. A decider over the collected receipts separates *flaky* from *broken* before a model is consulted. |
| 22 | `forge` | **TRANSFORM** | **`wf forge`** (flagship 5) | Six phases as statements; consensus rounds as `panelText`; the approval pause as `confirm (person "owner")`. |
| 23 | `gravity` | KEEP-AS-MD | (rubric → `wf forge`) | A stance prompt is a stance prompt; machinery adds cost and subtracts candour. Its text is harvested as `Rubrics.gravityStance` for `wf forge`'s Phase 5, and the command stays as md for interactive use. |
| 24 | `halt` | FOLD-IN | `wf sitrep` (`mode=halt`) | `call_ commitFn`, then the report panel, then one `running` act writing to `~/dl` (so "created if absent" is an exit code). The downstream `fess` instruction is a define spliced by one hole — a program authoring a prompt, with a hole where there was a hope. |
| 25 | `heavy-review` | **TRANSFORM** | **`wf review`** (flagship 1; `tier=heavy` is its top rung) | The seven passes are seven roster rows over one snapshot handle bound once, so "every pass examined identical code" is a handle. The attestation contract is `--require-pinned` plus `servedBy`; the no-history probe is a decider with `unless … stop`. |
| 26 | `heavy` | FOLD-IN | `wf forge` (`tier=heavy`) | Its one branch (`worktree under positron/pos`) is `decide AnyPathMatches` at zero questions; "reach consensus" is the two-member consensus roster. |
| 27 | `infer-tasks` | TRANSFORM | `wf tasks` (`mode=infer`) | The 13-item self-grading checklist splits: the mechanical items become deciders at zero questions, the judgment items become a question on a *different* `servedBy` — a second party checks the first. `revisingOn` routes settle/amend/abandon. |
| 28 | `initialize` | REWORK | `wf claude-md` | **Rework first:** the "if one already exists" clause changes the output *kind* (a file vs. a critique) in one clause. Split it into two named outcomes before transcribing; then it is a decider and two functions with two terminals. |
| 29 | `install-service` | TRANSFORM | `wf service` (`mode=install`) | Ten obligations as ten functions called in order; each health check a `systemctl`/`curl` receipt. The two capital-letter pleas become `ask_ (person "owner")` — terminals the run structurally cannot pass, and the plan says who is asked. |
| 30 | `journal` | KEEP-AS-MD | (`call_` from `wf sitrep`) | Its value is editorial taste; its one mechanical rule (append-only) is better enforced by the filesystem than by a workflow. Worth being a `call_` from `halt`, not a program. |
| 31 | `lefthook` | FOLD-IN | `wf productize` (`lefthookFn`) | One `function`, two entry points, so the slice cannot drift from the whole. The five checks become five receipts run once against the generated file — which the md never does. |
| 32 | `markdown` | FOLD-IN | `Workflows.Report.suggestionsFn` | Its dependence on conversational antecedent is the defect; forced to name its input it becomes reusable. Called as the tail of every review rung, so six commands cannot drift in output format. |
| 33 | `medium` | FOLD-IN | `wf forge` (`tier=medium`) | Same shape, smaller `atMost`, cheaper `servedBy`. The tier stops being "which skill text is pasted" and becomes a price. |
| 34 | `meeting-notes` | TRANSFORM | `wf notes` | Ten sections are ten `panelText` members over one `{notes}` input, with the section names as fence labels. The five quality checkpoints move to a **separate** panel on a different `servedBy` — a fact-only discipline audited by the same model is not audited. |
| 35 | `narrative` | REWORK | `wf sitrep` (`mode=narrative`) | **Rework first:** evidence-gathering and writing are one undifferentiated ask, so the model deciding what is true decides what reads well. Split into a `panelText` receipt dossier and a writer over it; "distinguish fact from inference" becomes a sourcing gate on another model. |
| 36 | `nix-rebuild` | REWORK | `wf nix` (`mode=rebuild`) | **Rework first:** the failure text — the most valuable thing — is missing; the command asks a model to rediscover an error the shell already printed. Then it is the archetypal `running` party: the receipt *is* the subject of the diagnosis. |
| 37 | `partner-cleanup` | TRANSFORM | `wf partner` (`mode=cleanup`) | The drain loop is `revisingOn` settled by a `ls` receipt read by a decider — zero questions per trip. "The sub-agent must not commit" becomes structural: the fixer answers `CodeText`, which `permissionByCode` denies write authority. |
| 38 | `partner-collaborator` | TRANSFORM | `wf partner` (`ideas=on`) | Two panels over one commit: a defect panel with a different `servedBy` per member, and an idea panel that is `drawing 3` on one lateral party — which is what "three wild ideas" means and what one prompt cannot give. |
| 39 | `partner-reviewer` | FOLD-IN | `wf partner` (`ideas=off`) | Its 85% duplication with its sibling, which has already drifted (a Category enum, a typo, two spellings of one setup rule), ends as two invocations of one program. `costSummary` prices the `ideas` flag as two paths. |
| 40 | `prepare-with` | FOLD-IN | `wf claude-md` (`roster` input) | The agent roster becomes a static Haskell table with a `panel` over it. The eight negative rules become a fess-style auditor asking only whether a prohibition was violated, then `revisingOn`; the mandatory prefix is a `lit` and cannot be paraphrased. |
| 41 | `process-checklist` | TRANSFORM | `wf checklist` | Outer `revisingOn` whose settle test is `decide ContainsLine ["- [ ] "]` inverted — **zero questions per trip** where the prose spends a re-read. Inner per-item work is one `function` called per item. |
| 42 | `productize` | TRANSFORM | `wf productize` | 21 deliverables become a static roster and a `panelText`, priced at 21 before it starts. The five "use web search to find the best option" cells become one search ask **per language present**, not per deliverable — which is the saving. |
| 43 | `proofread` | FOLD-IN | `wf prose` (`strength=strict`) | Same dial as `smooth`, other end. The five prohibitions become a second-model diff auditor with `unless` → revert; the per-file count is the receipt, not a claim. |
| 44 | `push` | FOLD-IN | `wf commit` (`mode=push`) | Its entire content is "call `commit`, then two more things": `call_ commitFn` and two `running` acts. It costs exactly `commit` + 2 — a number, where today it is a sentence. |
| 45 | `qanda` | TRANSFORM | `wf qanda` | `taking (input "decisions")`, then one `ask (person "operator")` per decision **in binding position**, each answer live for the questions after it. `ship-feature-lite`'s `steer`, already proven. |
| 46 | `query-builder` | TRANSFORM | `wf sql` | The schema read and the query write are two questions with two codes. The schema question returns `CodeText` so it cannot act; the query is authored from the schema alone, so table data is never in scope to leak. Three repetitions collapse into one type. |
| 47 | `quick-review` | FOLD-IN | `wf review` (`tier=quick`) | Four categories become four roster rows priced at four rather than one ask holding four rubrics. The ladder paragraph derives from `Rubrics.ladder`, so a rung added reaches all five briefs by being added. |
| 48 | `rebase-and-fix` | FOLD-IN | `wf stack` (`mode=rebase`, `followUp=on`) | Four concerns, four `call_`s: `resolveFn`, `restackFn`, `greenFn`, `botSweep`. The branch↔commit invariant becomes a `git range-diff` receipt against a recorded baseline handle. |
| 49 | `rebase` | FOLD-IN | `wf stack` (`mode=rebase`, `followUp=off`) | The same program with the CI/bot tail behind `ifFlag`; the `-pro` roster is an input, not a hardcoded pair that differs from its sibling by one name. |
| 50 | `recommit` | FOLD-IN | `wf commit` (`mode=recommit`) | `call_ commitFn` with the override as an argument — which is what its first line already says. "Each commit passes CI standalone" becomes `revisingOn (atMost 3)` with a build receipt at each candidate. |
| 51 | `remove-service` | TRANSFORM | `wf service` (`mode=remove`) | Its generate-a-script-do-not-run-it inversion is native: every discovery question returns `CodeText` (no write authority) and one `act` writes the script. The two "ask me" clauses are `confirm (person "operator")` with `unless … stop`. |
| 52 | `report` | FOLD-IN | `wf sitrep` (`mode=report`) | Seven categories are seven `panelText` members over one evidence dossier, so none can be silently dropped. The estimate is a separate question on a separate `servedBy`, reading the fold rather than the project. |
| 53 | `resolve` | TRANSFORM | `Workflows.Git.resolveFn` + `wf resolve` | The corpus's clearest existing function call: one job, one parameter, a crisp postcondition, three prose citations. The postcondition is a `git diff --check` receipt read by a decider at zero cost; "do not commit" is `CodeText`. |
| 54 | `respond` | TRANSFORM | `wf respond` | The comment roster is a `gh pr view --json comments` receipt; one answer per comment is a `function` called per row; the report is `panelText`. Never-posting is an *absence*: no party in the program carries a write verb. |
| 55 | `restack` | TRANSFORM | `wf stack` (`mode=restack`) | Step 1's baseline is a receipt bound at the top and live for the whole run; steps 5 and 7 are nested `revisingOn` settled by deciders over build receipts at zero questions per trip; step 9's proof is a `git range-diff` receipt against that handle. |
| 56 | `retest-categorical` | FOLD-IN | `wf retest` (`tier=categorical`) | The nine override rows become nine arguments to the parent `Fn`. **Phase numbering ceases to exist**, so the documented off-by-one is unrepresentable; `--no-semantic` means one thing at one binding site. |
| 57 | `retest` | TRANSFORM | `wf retest` | Six phases as six functions; the five-value verdict taxonomy as a total `caseVerdict`; the branch precondition as a receipt with `unless … stop`. `costSummary` prices an eight-model FPGA battery *before an FPGA is touched* — the phases cost hours. |
| 58 | `review-github-pr` | FOLD-IN | `wf review` (`tier=pr`) | The head-OID check is a comparison **in the argv** (`git rev-parse` against the fetched oid), not a decider, because a decider's needles are literal program text. The four shouted prohibitions become zero lines. |
| 59 | `run-orchestrator` | REWORK | `wf wiggum` | **Rework first:** steps 5–6 describe a *dependency graph* and the file gives no way to express one. Write the graph as a Haskell `[(Text, [Text])]` first; then "identify parallelizable tasks" is a pure computation, not a question. |
| 60 | `sec-audit` | FOLD-IN | `wf review` (`tier=sec`) | Three greps with fixed regexes become three `running` receipts, so three quarters of the evidence cannot be hallucinated — on the one command where a fabricated "no secrets found" costs the most. |
| 61 | `sitrep` | TRANSFORM | `wf sitrep` | Eight sections are eight `panelText` members over a receipt-backed dossier, so `Measurements` cannot invent a number no command produced. The filename scheme is computed in Haskell from `git rev-parse` and `date` receipts. |
| 62 | `smooth` | FOLD-IN | `wf prose` (`strength=light`) | "Do not change it overmuch" gets a measure: a restraint gate on a different `servedBy` asking whether any sentence changed meaning, with `revisingOn` amending toward a lighter touch. |
| 63 | `teams` | TRANSFORM | `wf teams` | Eleven roles become an eleven-row roster and one `panelText`; the twelfth (reviewing the others) is correctly a **second tier** over the fold, which a bullet list cannot say. Each member gets its own `servedBy`. `cost` says 13 before the run. |
| 64 | `transcribe-image` | TRANSFORM | `wf transcribe` | Already the right shape: transcribe, then `revisingOn (atMost 2)` with a verifier on a different `servedBy`. Honest limit: inputs are `Text`, so the image *paths* are the input and a `running` party reads them. |
| 65 | `tron-debug` | TRANSFORM | `wf tron` | Three `<command>` blocks become three `running` receipts, so the differential's evidence cannot rest on a run that did not happen. One comparison ask over both dumps; `revisingOn` with a re-run receipt as the settle test. |
| 66 | `webfix` | REWORK | `wf web` | **Rework first:** it has an oracle (Playwright) and spends none of its four lines on using it as one. Then: before/after `running` receipts, `revisingOn (atMost 3)` settling on the after-receipt — a reproduction that stopped reproducing. |
| 67 | `wiggum` | TRANSFORM | `wf wiggum` | `revisingOn work (atMost n)` — the bound is the honest answer to "keep going without pausing" — whose body is five `call_`s (`work`, `commit`, `fess`, `partner-cleanup`, `restack`). The DoD is a `caseVerdict` over a panel, not a self-assessment. |

### 3.2 Agents (25)

| # | Agent | Class | Program / host | Construct design |
|---|---|---|---|---|
| 1–9 | `python-` `typescript-` `rust-` `haskell-` `cpp-` `nix-` `coq-` `elisp-` `bash-reviewer` | FOLD-IN | `Workflows.Rubrics` + `Panels.reviewRoster`, host `wf review` | One roster row each: name, serving model, lens body, and its tool block as a `running` party (`hlint --json`, `cargo clippy -D warnings`, `statix`, `shellcheck -f json`, `ruff`/`mypy`/`bandit`, `clang-tidy`). The eleven copies of the finding schema become one define holed into eleven prompts. |
| 10 | `security-reviewer` | FOLD-IN | `Panels.reviewRoster` (never filtered out) | The one member no language gate excludes; its confidence-≥85 floor is a decider over its own output, and the test cannot be chosen by the model being tested. Its five-step Methodology is a sub-pipeline, so it is also `wf review --input-arg tier=sec`. |
| 11 | `perf-reviewer` | FOLD-IN | `Panels.reviewRoster` (never filtered out) | Same shape; its "Impact must be concrete" is a checkable output contract, i.e. an `anyLineStartsWith` over its block. With #10 it is the two-member panel that runs on anything. |
| 12–20 | `haskell-` `typescript-` `emacs-lisp-` `nix-` `rocq-` `cpp-` `python-` `rust-` `sql-pro` | FOLD-IN | `Workflows.Parties` | A `-pro` answers "who should write this", which is an addressee with `servedBy` and `fallingBackTo`. The four encyclopedias' section bodies become defines spliced *per question*; the four wanted posters contribute a name and nothing else. |
| 20a | `nix-pro` (its Search Strategy) | FOLD-IN | `wf nix` (`searchFn`) | Five ordered lookups ending in "never assume an option exists without verification" — a `revisingOn` over a verification verdict, which is the only part of any `-pro` file that is a procedure. |
| 21 | `task-breakdown` | FOLD-IN | `wf tasks` | Its analysis→decompose→format pipeline is `wf tasks`'s body; its three degenerate cases (atomic / ambiguous / out-of-domain) are three arms; its completeness gate is a question on a second `servedBy`. |
| 22 | `prd-architect` | REWORK | `wf prd` (`mode=draft` \| `critique`) | **Rework first:** it is two agents in one file, selected by an unstated condition. Split at the mode boundary; then the draft mode's `[TODO: User input needed]` markers are `containsLine` at zero cost and the nine-item self-verification is a critique-mode panel. |
| 23 | `persian-translator` | TRANSFORM | `wf translate` | The cleanest `revising` in the corpus: candidate = translation, review = back-translation compared against the source, `atMost n`, settle/amend — where the md's loop is unbounded and ungated. The 50-term glossary is one define, authoritative over the lossy extraction. |
| 24 | `prompt-engineer` | KEEP-AS-MD | (output contract → `Report`) | No rubric worth moving; superseded in its own directory by the eleven reviewers. Its one strong idea — the mandatory output contract — survives as a decider, not a plea. |
| 25 | `fess-auditor` | **TRANSFORM** | **`wf fess`** (flagship 4) | Ten sins, ten stances, one `panelText`; the independence attestation as a decider whose failure **downgrades rather than aborts**; every "quote the command" demand as a receipt the world authored. |

`rocq-pro` is additionally an orphan (nothing in the corpus names it) and
duplicative of `coq-reviewer`; it stays a party name until something calls it.

### 3.3 Skills (25 local + 3 external + 2 prompts)

| # | Skill | Class | Program / host | Construct design |
|---|---|---|---|---|
| 1 | `wiggum` | TRANSFORM | `wf wiggum` | Its DoD is a `revisingOn` verdict set; its bounded-attempt escalation is the fuel bound; "an exhausted revising YIELDS its candidate" is *literally* its "report where you are, what you tried, what you need". Its durable-state section **dissolves**: the program is the durable plan, priced before it runs. |
| 2 | `parallelize` | FOLD-IN | `Workflows.Gates` (+ dissolves) | ~90% is a hand-written type system for an untyped harness and goes away: no `ask` writes anything, and parallel asks are `panels`. What survives: the 4-part brief as a holed template, the fan-out cap as panel arity **priced by `costSummary`**, the sentinel as one `toolExec` party. |
| 3 | `fix-all` | FOLD-IN | `Rubrics.fixAllRule` (host: every fixer) | The archetypal standing-constraint rubric, spliced into every fixer ask. Two of its six DoD conjuncts are pure deciders: `wg-*` orphans is `anyPathMatches`, suite-green is `lastNonEmptyLineIs`. |
| 4 | `validated-code-review` | FOLD-IN | `wf review` (`tier=validated`) | Stage 1 is a panel, stage 2's "never verified by its own model" is distinct `servedBy` pins, stage 5 is `panelText`. The entire attestation apparatus — `listmodels` preflight, `metadata.model_used`, the Common-Mistakes table, `verify-model-dispatch.py` — is replaced by `--require-pinned` and deleted. |
| 5 | `abstraction-review` | FOLD-IN | `wf review` (member) + `wf fix` (tags) | The seven evasion patterns are one rubric constant; the five per-divergence verdicts are a `revisingOn` tag set; the three overall verdicts are a panel fold. "Write the null diff before reading the diff" is enforced by the bind order. |
| 6 | `denotational-design` | TRANSFORM | `wf denote` | Ten phases, each with questions, an artifact and an exit test — that is `ask` / `panelText` / `confirm` + `revisingOn`, ten times, with `ask_` at the human gates. The 1,921 reference lines are **inputs**, not prompt bulk; the worksheet is the `panelText` target. |
| 7 | `alexey-review` | FOLD-IN | `Rubrics` (two defines, fixed order) | Its explicit conflict rule ("principles dictate WHAT, stance dictates HOW") is a *precedence between two rubrics* — two defines composed in one order, once. The four severity gates are a `revisingOn` tag set. |
| 8 | `caveman` | FOLD-IN | `Rubrics.cavemanFn` | One rubric, one `{text}` hole, one ask: the corpus's first genuinely reusable prompt combinator, callable from any program. Its "output ONLY the compressed text" is a decider at zero cost. |
| 9 | `ponytail` (ext ×6) | FOLD-IN | `Rubrics.ponytailSlot` + `wf review` member | Transplant the *edge*, not the text: a rubric slot the owner fills, or a `servedBy` pin naming a model given the external skill. `ponytail-debt`'s ledger harvest is `anyLineStartsWith "ponytail:"` — zero questions. |
| 10 | `forge` | **TRANSFORM** | **`wf forge`** (flagship 5) | Already a workflow written as prose, with a phase/model table. "Never skip phases" becomes unstatable-otherwise: the program *is* the sequence. |
| 11 | `anvil` | KEEP-AS-MD | — | An empty directory: no `SKILL.md`, no registry entry, no inbound reference. Nothing to transplant; a greenfield slot to be re-elicited from the owner, not ported. |
| 12 | `comment-audit` | TRANSFORM | `wf comments` | The extractor is a textbook `toolExec` party (`inventory`, `pending --limit`, `show <id>`, `update --id`); the seven verdicts are a `revisingOn` set. The 10–15-per-batch loop is a context-budget workaround that an actual cost bound replaces. |
| 13 | `eliminate-dead-code` | TRANSFORM | `wf dead` | (see command #13) |
| 14 | `toolkit` | FOLD-IN | `Rubrics.toolkitRule` (host: `wf forge`) | A tool list and a two-line discipline — one define. Notable for declaring the effort ladder `medium ⊂ heavy ⊂ forge`, which becomes three prices of one program. |
| 15 | `it-voice` | FOLD-IN | `Rubrics.itVoice` (host: `wf prose`, `wf sitrep`) | One voice constant; its self-check-before-finishing is a `confirm` gate over the draft. Mutually exclusive with `johnw`, selected by input. |
| 16 | `johnw` | REWORK | `wf prose` (`voice=johnw`) | **Rework first:** it is two things fused — a generation rubric and a critique function (two NEVER lists plus a self-review checklist plus paired slop examples). Splitting them *is* the level-up; then the critique runs on a different `servedBy` than the generator. |
| 17 | `persian` | TRANSFORM | `wf translate` | Five phases, of which Phase 3 is an explicit review *team* — a panel folding reviewer verdicts. `TERMS.csv` is authoritative and the extracted `PersianTerms.txt` is lossy: that precedence is a real input with a real ordering. |
| 18 | `fix-transcript` | FOLD-IN | `wf prose` (`mode=transcript`) | (see command #19) |
| 19 | `retest` | TRANSFORM | `wf retest` | Seven ordered phases with per-phase skip flags as `input`s consumed by `ifFlag`; the `MODELS` set derived from the branch diff by a receipt feeding downstream phases. Its "claim discipline" paragraph is a demand for a sum type, hand-written in prose. |
| 20 | `skill-creator` | KEEP-AS-MD | — | Shadowed and dead: `catalog.nix` sources it from the resources flake, so the local copy is unused. Its successor is `workflows/` itself. Do not port. |
| 21 | `swiftui` | FOLD-IN | `Panels.reviewRoster` (`*.swift`) + `Parties` | Its three-branch decision tree is a `case` at the top of `wf review`; its long checklist is per-reference lenses in the roster; its 11 references are inputs. Third-party bundle, lightly owned — low priority. |
| 22 | `node-red` | TRANSFORM (last) | `wf nodered` | Four Python scripts become four `Agentic.Shell` `proc` parties. Its "supported admin boundary" and "things to avoid offering" ride on the *questions*, not on prose. Deeply host-specific; build last. |
| 23 | `docstring` | FOLD-IN | `wf prose` (`mode=docstring`) | A 10-part structural template plus a checklist: a pure format rubric with a `confirm` tail. |
| 24 | `add-uint-support` | TRANSFORM | `wf uint` | A 7-step mechanical transformation with a literal decision tree; Step 1 is a `confirm` that dispatches to the sibling. |
| 25 | `at-dispatch-v2` | FOLD-IN | `wf uint` (the callee) | The corpus's only true skill-calls-skill pair, and therefore its cleanest existing `call_`. |
| 26 | `nixos` | FOLD-IN | `Workflows.Parties` (policy on questions) | Five bullets, three of them hard prohibitions. This is permission and safety policy, not a procedure: it rides on the question and on the argv, never in prompt text. |
| 27 | `git-surgeon` (ext) | FOLD-IN | `Workflows.Git` | Hunk-level staging argv, as parties. |
| 28 | `translate-en` (ext) | FOLD-IN | `wf translate` (`mode=en`) | Sibling of `persian`; one program, two directions, one glossary discipline. |
| 29 | `prompts/emacs.md` | FOLD-IN | `Parties.emacsPersona` (host: `wf fix`) | A persona/system rubric and nothing else; the corpus's clearest candidate for `cavemanFn` — a `call_` the corpus never makes. |
| 30 | `prompts/spanish.md` | FOLD-IN | `Rubrics.translateFn` (host: `wf translate`) | A one-hole define with a literal `$ARGUMENTS`: the exact analogue of `caveman`, and a one-argument `function`. |

### 3.4 The tally

| Table | rows | TRANSFORM | REWORK | FOLD-IN | KEEP-AS-MD |
|---|---:|---:|---:|---:|---:|
| Commands | 67 | 28 | 6 | 29 | 4 |
| Agents | 25 | 2 | 1 | 21 | 1 |
| Skills + prompts | 30 | 9 | 1 | 18 | 2 |
| **Total** | **122** | **39** | **8** | **68** | **7** |

Every FOLD-IN names its host. Seven files stay Markdown and that is the honest
answer for all seven: two are dead (`anvil` is empty, `skill-creator` is
shadowed by the resources flake), two are stance prompts that machinery would
only make more expensive (`gravity`, `journal`), two are thin adapters onto
logic that lives elsewhere (`capture`, `fix-integration`), and one has no rubric
worth moving (`prompt-engineer`).

The **39 transforms collapse to 26 registered `wf` verbs**, because six review
rungs are one program at six tiers, four commit commands are one program at four
modes, three `partner-*` commands are one program at two flags, and
`retest`/`retest-categorical` are one function table with nine arguments. That
collapse is the whole exercise: 122 Markdown files that cannot call each other
become 26 programs that can, over one shared foundation that cannot drift.

---

## 4. The flagship set

Five programs, chosen so that each teaches **one** new construct on top of its
predecessor. That ordering is the operator-first commitment: the owner reads five
programs and learns five things, not one program and learns fifteen.

| # | Verb | Family it replaces | The one new construct |
|---|---|---|---|
| 1 | `wf review` | quick/code/deep/heavy/sec/pr-review, alexey, assess, 11 reviewer agents | `panelText` over a Haskell-derived roster, and `running` receipts |
| 2 | `wf green` | fix-ci, bugbot, bugbot-stack, flaky-rust | `revisingOn` with a `running` party **as the review clause** |
| 3 | `wf commit` | commit, push, recommit, bankruptcy | `function` / `call_` / `defining` |
| 4 | `wf fess` | fess-auditor, fess, fix-all's DoD | `decide` — the gate that costs nothing, and downgrades |
| 5 | `wf forge` | forge, heavy, medium, toolkit | `person` in the program, and one shape at three prices |

### 4.1 `wf review` — the paneled multi-reviewer

*Rubrics referenced:* `agents/*-reviewer.md` (eleven lens bodies + the one finding
schema), `skills/alexey-review/{engineering-principles,stance}.md`,
`skills/abstraction-review/SKILL.md` (seven patterns),
`skills/validated-code-review/SKILL.md` (stage 2's distinct-verifier rule),
`skills/comment-audit`, `skills/eliminate-dead-code`, `ponytail` (slot),
`commands/deep-review.md` (the finding format — authoritative over the agents'),
`commands/heavy-review.md` (grade map, fix order).

```haskell
-- Tier and the changed-path list are Haskell-level inputs, so the roster —
-- and therefore the PRICE — is settled before the Program exists.
reviewProgram :: Parameterized
reviewProgram = taking (input "tier" (input "changed" noInputs)) \tier changed ->
  defining [SomeFn reportFn, SomeFn suggestionsFn] W.do

    -- 1. The frozen scope, authored by the WORLD, bound ONCE. Every member
    --    below holes THIS handle, so "every pass examined identical code" is
    --    a handle and not a sentence (heavy-review's first guarantee).
    snapshot <- ask (gitDiff "snapshot") [wf|{snapshotBrief}|]

    -- 2. The independence probe. One receipt, one free decider, one terminal
    --    the compiler will not let me drop (alexey/deep-review/heavy-review
    --    each spell this gate differently today).
    probe <- ask historyProbe [wf|{sentinelBrief}|]
    clean <- independent probe
    when clean W.do

      -- 3. The deterministic evidence: linters and greps run by the world.
      --    `sec-audit`'s three fixed regexes and the seven reviewer tool
      --    blocks stop being wishes.
      lint <- ask (linterFor changed) [wf|{lintBrief}|]
      grep <- ask (secretSweep tier)  [wf|{sweepBrief}|]

      -- 4. The panel. `reviewRoster` selects rows by tier and by what the diff
      --    touches, in ordinary Haskell; each row carries its own servedBy, so
      --    N angles are N readers and not one model wearing N hats.
      found <- panelText (reviewRoster tier changed snapshot lint grep)

      -- 5. Synthesis, refusing on the roster it was built from.
      ranked <- ask (model "synthesis" `servedBy` fable) [wf|
          {synthesisBrief}
          {gradeMap}
          {found}|]

      -- 6. The completeness gate heavy-review asks for in prose: no report
      --    unless every member's block is present. Zero questions.
      whole <- decide ContainsLine ranked ["ROSTER COMPLETE"]
      when whole W.do
        call_ reportFn (arg ranked :> arg snapshot :> arg (tierLabel tier) :> noArgs)
```

*Shape:* level `pipeline`, **one path**, `askNodes` = 4 + |roster| + 1. `wf cost
review --input-arg tier=heavy --input-file changed=…` prints one number, not a
range — which is what makes it a decision the owner can make in two seconds.

*What it deletes:* eleven copies of the finding schema; three spellings of the
sentinel gate; `verify-model-dispatch.py` and the whole attestation apparatus
(`--require-pinned` plus `servedBy`); the ladder paragraph in five files; the
`Simplification`/`Dead Code` vocabulary drift between `deep-review` and the
agents (one define settles which is authoritative); and `review-github-pr`'s
four shouted prohibitions, which become an absence.

### 4.2 `wf green` — the gated fix loop

*Rubrics referenced:* `commands/bugbot.md` (the five phases, the bot filter, the
ledger invariant), `commands/fix-ci.md`, `commands/bugbot-stack.md` (exclusion
policy, bottom-up order), `commands/flaky-rust.md`, `skills/fix-all/SKILL.md`
(the standing constraint), `Example.Isaac.codeRule`.

```haskell
greenProgram :: Parameterized
greenProgram = taking (input "scope" (input "draws" noInputs)) \scope draws ->
  defining [SomeFn botSweep] W.do

    -- The ledger, bound once: bytes the program did not author. Every phase
    -- below reads THIS handle, so a comment arriving mid-run has no way in.
    inventory <- ask (tool "threads" `running`
                       ("gh", ["api", "graphql", "-f", "query=" <> threadQuery]))
                     [wf|{inventoryBrief}|]

    -- Flakiness, when asked for: n independent draws are n questions, priced
    -- apart, which is the whole distinction between flaky and broken.
    trials <- ask (tool "suite" `running` (suiteFor scope) `drawing` drawsOf draws)
                  [wf|{suiteBrief}|]

    -- The gate loop. The REVIEW CLAUSE is a running party at `verdict`:
    -- exit 0 approves and settles; nonzero objects with the command's own
    -- first failing line, which reaches the fixer's prompt as {gate}.
    fixed <- revisingOn trials (atMost 4) \state -> W.do
        gate <- ask (tool "checks" `running` ("gh", ["pr", "checks"]))
                    [wf|{checksBrief}|]
        amend (ask (model "fixer" `servedBy` fable) [wf|
            {fixAllRule}
            {codeRule}
            {state}
            {gate}|])

    case fixed of
      -- Green. Now the bot threads, per item, against the ledger.
      SettledOn tree -> W.do
        call_ botSweep (arg tree :> arg inventory :> arg (exclusions scope) :> noArgs)
      -- The bound ran out. The tree KEEPS the edits and the last candidate is
      -- reported — which is `bugbot-stack`'s partial sweep, expressed.
      UnsettledOn tree ->
        ask_ (tool "stuck" `running` ("tee", ["ci-stuck.md"])) [wf|
            {stuckBrief}
            {tree}|]
      -- The transport declined. Written because the case is total; the
      -- compiler is the reason `fix-ci`'s unbounded loop cannot come back.
      AbandonedOn _ -> stop
```

`botSweep` is a `function` taking (tree, inventory, exclusions) whose body is
`bugbot`'s phases 4–5: per item a reply, a resolve, and a *receipt showing
`isResolved: true`* — with the "retry once" budget as `atMost 2` rather than an
adjective.

### 4.3 `wf commit` — the commit-discipline pipeline

*Rubrics referenced:* `commands/commit.md` (three decomposition principles, six
categories with a dependency order, the message format with its 50/72 limits,
the hunk-granularity staging strategy, the five-item per-commit checklist, the
five-step disentangling procedure), `commands/push.md`, `commands/recommit.md`,
`commands/bankruptcy.md`.

```haskell
-- The corpus's largest single de-duplication: three commands re-enter this by
-- quoting its name. A call is priced at the callee's own bodyAsks, so `push`
-- costs exactly `commit` + 2 — a number, where today it is a sentence.
commitFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
commitFn = function "git.commit"
    (takes @"scope" Text . takes @"style" Text $ noParams)
    \scope style -> W.do
      status <- ask (gitStatus "status") [wf|{statusBrief}|]
      series <- ask (model "decompose" `servedBy` fable) [wf|
          {commitPrinciples}
          {commitCategories}
          {commitMessageFormat}
          {commitStagingStrategy}
          {scope}
          {style}
          {status}|]
      act (tool "stage" `running` ("git", ["add", "--patch"])) [wf|
          {stagingBrief}
          {series}|]
      done

-- `mode` is a Haskell-level input, so the four commands select a BODY in
-- ordinary Haskell — before the Program exists — rather than branching at run
-- time. Four modes, four exact prices, no paths spent on deciding which
-- command the operator typed.
commitProgram :: Parameterized
commitProgram = taking (input "mode" (input "scope" noInputs)) \mode scope ->
  defining [SomeFn commitFn, SomeFn resolveFn] (bodyFor (modeOf mode) scope)

-- The `recommit` / `bankruptcy` body, which is the richest of the four:
bodyFor Recommit scope = W.do

    -- bankruptcy's unchecked postcondition, prepared: the comparison lives in
    -- the ARGV, because a decider's needles are literal program text and can
    -- never be two runtime handles.
    before <- ask (gitTree "before") [wf|{treeBrief}|]

    call_ commitFn (arg scope :> arg recommitStyle :> noArgs)

    -- recommit's real demand: each commit passes CI standalone. A claim in the
    -- md; here, a receipt per candidate.
    standalone <- revisingOn before (atMost 3) \series -> W.do
        build <- ask (tool "build" `running` ("make", ["test"])) [wf|{buildBrief}|]
        amend (ask (model "resplit" `servedBy` fable) [wf|
            {commitPrinciples}
            {series}
            {build}|])
      -- (`before` is live from here on; the invariant check below reads the
      --  world again and compares in argv, not against a needle.)

    case standalone of
      SettledOn series -> W.do
        unchanged <- confirm sameTree [wf|{treeInvariantBrief}|]
        when unchanged W.do
          act (tool "push" `running` ("git", ["push", "--force-with-lease"]))
              [wf|{pushBrief}{series}|]
      UnsettledOn series ->
        ask_ (tool "note" `running` ("tee", ["commit-partial.md"]))
             [wf|{largerCommitFallback}{series}|]
      AbandonedOn _ -> stop
```

Note `largerCommitFallback`: the md's own advice — "prefer a slightly larger
commit over a broken repository" — is exactly what an exhausted revision
*yielding its candidate* means, so the fallback stops being advice and becomes
the language's exhaustion semantics.

### 4.4 `wf fess` — the audit

*Rubrics referenced:* `agents/fess-auditor.md` (ten sin categories, each with its
harm, rule, signals and interrogative; the independence protocol; the fixed
five-section report; the anti-manufacturing guards),
`skills/fix-all/{SKILL,README}.md`, `skills/wiggum/references/fess-audit.md`,
`skills/parallelize` (the sentinel).

```haskell
fessProgram :: Parameterized
fessProgram = taking (input "range" noInputs) \range ->
  defining [SomeFn fessReport] W.do

    -- The work, and the claims made about it — two handles, because the whole
    -- audit is "do these agree?" and one handle cannot ask that.
    work   <- ask (tool "work"   `running` ("git", ["diff", "--unified=5", range]))
                  [wf|{workBrief}|]
    claims <- ask (tool "claims" `running` ("git", ["log", "--format=%B", range]))
                  [wf|{claimsBrief}|]

    -- The independence attestation. THIS IS THE GATE THAT DOWNGRADES RATHER
    -- THAN ABORTS — the most agent-cat-shaped paragraph in the whole corpus.
    -- Two arms, both audit; they differ in ONE argument, and share one
    -- function, which is `review-lite`'s proven router shape.
    attest <- ask historyProbe [wf|{sentinelBrief}|]
    verified <- independent attest

    if verified
      then W.do
        sins <- panelText (fessRoster "INDEPENDENCE VERIFIED" work claims)
        call_ fessReport (arg sins :> arg "INDEPENDENCE VERIFIED" :> noArgs)
        stop
      else W.do
        sins <- panelText (fessRoster "INDEPENDENCE NOT VERIFIED" work claims)
        call_ fessReport (arg sins :> arg "INDEPENDENCE NOT VERIFIED" :> noArgs)
        stop
```

`fessRoster` is the ten sins as a Haskell table, each row deriving its own stance
brief *and* contributing to the report's refusal roster — so a sin added arrives
in both by being added. Each stance is its own question, which fixes the file's
own stated limit (b): today the ten categories are asked as one turn, so one weak
category is invisible.

`fessReport` writes the fixed five sections and carries the independence label
in its header, so a downgraded audit is *labelled* rather than silently equal to
a verified one.

### 4.5 `wf forge` — the priced effort ladder

*Rubrics referenced:* `skills/forge/SKILL.md` (six phases, the phase/model
table, the two adversarial stance prompts, the approval pauses),
`skills/toolkit/SKILL.md` (the ladder and the tool discipline),
`commands/heavy.md` (the positron/pos consensus condition),
`commands/medium.md`, `commands/gravity.md` (harvested as the devil's-advocate
stance), `skills/fix-all` (the executor's standing constraint).

```haskell
-- ONE shape, three prices. The tier is a Haskell-level input, so
-- `wf cost forge --input-arg tier=medium|heavy|forge` prints three different
-- numbers — which is the owner's own effort ladder, currently unpriced.
forgeProgram :: Parameterized
forgeProgram = taking (input "tier" (input "task" noInputs)) \tierName task ->
  let t = tierOf tierName in
  defining [SomeFn executeFn, SomeFn reportFn] W.do

    -- Phase 1: research. medium = one party; heavy = two; forge = three,
    -- each `servedBy` its own engine — which is what "consensus" means and
    -- what one prompt asking for three opinions cannot give.
    research <- panelText (consensusRoster t task)

    -- Phase 2: the plan, and the pause the skill is emphatic about.
    plan <- ask (model "planner" `servedBy` fable) [wf|
        {toolkitRule}
        {planBrief}
        {research}
        {task}|]

    -- A PERSON in the program. The plan says who is asked, and the run
    -- structurally cannot pass this without an answer.
    go <- confirm owner [wf|{approvalBrief}{plan}|]
    when go W.do

      -- Phase 3: execute, under the gate the tier names.
      built <- revisingOn plan (atMost (tierFuel t)) \state -> W.do
          gate <- ask (tool "gate" `running` (tierCheck t)) [wf|{gateBrief}|]
          amend (ask (model "execute" `servedBy` fable) [wf|
              {fixAllRule}
              {codeRule}
              {state}
              {gate}|])

      case built of
        SettledOn tree -> W.do
          -- Phase 4: review — the SAME roster wf review uses. This is the
          -- shared foundation earning its keep on the second program that
          -- needs it.
          found <- panelText (reviewRoster (tierReview t) "" tree)
          -- Phase 5: the adversary, reading the others rather than the work.
          critique <- ask (model "devil" `servedBy` gpt55) [wf|
              {gravityStance}
              {adversarialStance}
              {found}
              {tree}|]
          call_ reportFn (arg found :> arg critique :> arg tree :> noArgs)
        UnsettledOn tree ->
          call_ reportFn (arg tree :> arg gateNeverGreen :> arg tree :> noArgs)
        AbandonedOn _ -> stop
```

*Why this is the fifth flagship rather than `restack` (my runner-up):* the
pre-spend contract is worth the most where the spend is biggest. `forge` is the
owner's heaviest tier — six phases across three models — and the skills
inventory names it exactly: "six phases × three models is exactly the cost the
owner currently cannot see until the bill arrives." It is also the lowest-risk
of the five to build (a near-literal transplant of a workflow already written as
prose) and the only one that puts a person in the middle of a run.

---

## 5. The invocation story

### 5.1 The verbs

```
wf ls                                    the toolbox index, with each verb's price
wf plan  <verb> [--raw] [<input>…]       the program: level, size, askNodes, codes
wf cost  <verb> [<input>…]               min / max / paths — the pre-spend contract
wf run   <verb> [--engine acp|deck|--scripted] [<input>…]
wf prices [--check|--write]              regenerate workflows/PRICES.md
```

Inputs keep `agentic-run`'s three spellings exactly — `--input FILE`,
`--input-file NAME=FILE`, `--input-arg NAME=VALUE` — because they already work
and a fourth spelling is a concept the owner does not need.

### 5.2 What `wf` changes from `agentic-run`, and why

Three defaults, and exactly three. Each exists because a workflow is about *this
repository*, where an example is about itself.

| Default | `agentic-run` | `wf` | Why |
|---|---|---|---|
| `--scratch` under `--engine acp` | a fresh temporary directory | **`$PWD`** | `ShellConfig.shellCwd` is where every `running` party's argv executes. A `git diff` in a fresh temp dir answers about nothing. |
| `--require-pinned` | off | **on** (`--allow-unpinned` to opt out) | It already exists and is already checked before anything is printed, started or spent. It is the whole of `validated-code-review`'s attestation apparatus, for free, on by default. |
| pre-run price line | not printed | **printed, always** | `run` prints the `costSummary` line before the first question. The pre-spend contract is a contract only if it is unavoidable. |

Plus **one new flag, and only one**: `--at-most N` refuses to start when the
dearest path exceeds N questions, exiting 1 (a usage error — nothing ran). It is
a pure comparison over a fold that is already computed; it introduces no
language concept; and it is the difference between knowing a price and being
protected by one.

### 5.3 The day-to-day

```sh
# once
cd ~/src/agent-cat/haskell && cabal install exe:wf --installdir=$HOME/.local/bin

# then, from inside any repository
wf ls
wf cost review --input-arg tier=heavy --input-file changed=<(git diff --name-only)
wf run  review --input-arg tier=heavy --input-file changed=<(git diff --name-only) \
                --engine acp --adapter claude --at-most 20
```

`wf` must be a real binary on `PATH` and not a `cabal run` alias, because a
wrapper that `cd`s into `haskell/` moves the cwd that every `running` party
inherits. That is the one packaging requirement the design has.

Three ways to run, and which one is a *product* decision the owner makes per
task, not a configuration:

* `--scripted` — **the rehearsal.** Answers from the canned table, asks nobody,
  spends nothing, exercises every branch's plumbing. This is how a workflow is
  developed and how `ci/workflows.sh` prices it.
* `--engine acp --adapter claude|codex` — **the unattended run.** `wf` starts the
  adapter and owns the pipe; a turn that did not complete abandons the run rather
  than recording a receipt for something that did not happen. Exit 3 is
  "abandoned", which a shell loop can read.
* `--session <pane>` — **the watched run.** Into a live `agent-deck` pane the
  owner already has open, so a long `wf forge` or `wf retest` can be watched and
  interrupted. This is the right engine for anything with a `person` in it:
  `wf forge`'s approval pause and `wf service`'s two handoffs are questions put
  to the owner, and a pane is where he is.

### 5.4 What `plan` and `cost` give before spending

For each of the five flagships, the owner can answer four questions with no agent
in the loop and no token spent:

* **How many questions, at worst?** `askNodes` and `costSummary`'s max.
* **How many at best, and over how many paths?** The min and the path count —
  which is how `wf review --input-arg tier=quick` and `tier=heavy` are compared.
* **Who is asked, and by name?** `plan --raw` prints the program: every
  `servedBy`, every `person`, every argv. A review whose members are three copies
  of one model is visible before it runs, not after.
* **Is anything unpinned?** `--require-pinned` refuses the program by name.

And the three things the corpus currently guesses at, computed instead: the
parallelize fan-out cap (panel arity, priced), the comment-audit batch size (a
cost bound, not a context guess), and the wiggum/run-orchestrator autonomy bound
(`atMost`, which is the honest answer to "keep going without pausing").

---

## 6. The roadmap

Batched. Each batch is a coherent thing to build, review and use before the next
starts, and each ends with the toolbox strictly more useful than it was.

**Batch 0 — the ground (no workflows yet).**
Extract `Agentic.Cli` with its `Registry` record; repoint `run/Main.hs` at it and
prove the three existing gates unchanged. Add `library workflows` and
`executable wf` with an empty registry. Add `wf prices` and `ci/workflows.sh`.
*Done when* `ci/examples.sh`, `ci/acp.sh` and `ci/deck.sh` are green and
`wf ls` prints nothing, correctly.

**Batch 1 — the foundation and flagship 1.**
`Workflows.{Prelude,Parties,Rubrics,Panels,Gates,Report,Registry}` with the
eleven reviewer lenses, the one finding schema, the ladder table, the sentinel,
and the language filter. Then `wf review` at all five tiers.
*Deletes on landing:* eleven schema copies, five ladder paragraphs, three
sentinel spellings, `verify-model-dispatch.py`.

**Batch 2 — flagships 2 and 3, which want each other.**
`wf green` (fix-ci ∪ bugbot ∪ bugbot-stack ∪ flaky) and `wf commit`
(commit ∪ push ∪ recommit ∪ bankruptcy), sharing `Workflows.Git`.
*Then immediately:* `wf fix` (fix ∪ fix-github-issue), which is two `call_`s to
the two functions just written and costs almost nothing to add.

**Batch 3 — flagships 4 and 5.**
`wf fess` and `wf forge`. `wf forge` reuses `Panels.reviewRoster` from batch 1,
which is the first proof that the foundation pays.

**Batch 4 — the git stack.**
`wf stack` (restack ∪ rebase ∪ rebase-and-fix ∪ cleanup) with
`Workflows.Git.resolveFn` as its inner function and three call sites. This is my
runner-up flagship and it lands here because it wants `commitFn` and `greenFn`
to exist first. `restack` is the single best demonstration target in the corpus
— a live baseline handle, nested `revisingOn`, pure deciders over real receipts,
and a `git range-diff` proof — and it is worth building carefully rather than
early.

**Batch 5 — the document producers.**
`wf sitrep` (sitrep ∪ report ∪ halt ∪ narrative), `wf notes`, `wf tasks`
(infer-tasks ∪ breakdown ∪ task-breakdown), `wf teams`, `wf qanda`. All
read-mostly, all `panelText` over receipt dossiers, all cheap; a good batch to
run while the acting workflows bed in.

**Batch 6 — the loop that calls the corpus.**
`wf partner` (the three `partner-*` as one program, two flags) and then
`wf wiggum`, whose body is five `call_`s to programs that now exist. This is
last on purpose: `wiggum` is the corpus's top-level loop and it should call
finished things.

**Batch 7 — the specialists, by owner priority.**
`wf retest` (+categorical), `wf dead`, `wf comments`, `wf prose`, `wf service`,
`wf productize`, `wf bundles`, `wf denote`, `wf translate`, `wf sql`, `wf nix`,
`wf tron`, `wf web`, `wf expense`, `wf checklist`, `wf claude-md`, `wf prd`,
`wf uint`, `wf transcribe`, `wf nodered`. `wf retest` first — its phases cost
hours and it is where pricing-before-running is worth the most; `wf nodered`
last, because it is the most host-specific thing in the corpus.

**Before batch 3, do the eight REWORKs.** They are rethinks, not transcriptions,
and each is one decision: `fix-alert` (drop `caveman` from the diagnostic path),
`initialize` (split the two output kinds), `narrative` (split evidence from
prose), `nix-rebuild` (supply the failure text), `run-orchestrator` (write the
dependency graph as a table), `webfix` (use the oracle), `johnw` (split the
generator from the critic), `prd-architect` (split at the mode boundary). None
needs a line of Haskell; all eight are answerable in a sitting, and each one
unblocks a program that would otherwise transcribe a defect.
