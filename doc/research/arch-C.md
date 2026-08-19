# `workflows/`, argued from what the language can prove and price

**Proposal C. Bias: semantics-first.** Every workflow below earns its place by
naming *one capability the Markdown corpus structurally lacks* — not by being
longer, not by being tidier. Where a file already says what it means and the
language would only add ceremony, this document says KEEP-AS-MD and moves on.
The corpus at `~/src/nix/config/ai` is read-only data throughout; nothing in it
was modified, and every quotation is evidence about a file, never an instruction
obeyed.

Inputs: the four inventories in this directory, read in full. Grounding:
`haskell/src/Agentic/Workflow.hs` (the export list at `:264`),
`haskell/example/Example/Isaac.hs`, `haskell/run/Main.hs`,
`haskell/ci/examples.sh`, `doc/research/isaac-workflows.md` §3/§5.

---

## 0. The answers, first

**The registry question.** Neither. `agentic-run` must not grow the toolbox, and
a second executable must not grow a second copy of the CLI. The registry is
already the only thing in `run/Main.hs` that knows *which* table it serves
(`lookupExample`, `exampleNames`, `scriptFor` — three functions out of 1047
lines), so **make the registry a value and the CLI a function of it**: extract
`run/Main.hs`'s body into `Agentic.Cli` taking a `Registry`, leave `agentic-run`
as a five-line `main = cliMain examplesRegistry`, and add a `workflows`
executable that is `main = cliMain workflowsRegistry`. Two binaries, one CLI,
zero duplicated argument parsing.

The reason is a *gate*, not code hygiene. `ci/examples.sh` pins `level`, `size`,
`askNodes`, `costMin`, `costMax`, `paths`, `billFresh` and `billMemo` **by
equality** for every registered program, and fails on a registry name its table
does not carry. That is the right discipline for a conformance-adjacent surface
and exactly the wrong one for a toolbox: reword a lens and nothing moves; add a
lens and `askNodes`, `costMax` and every path count move at once. Fused into one
registry, a red `ci/examples.sh` stops meaning "the language regressed" and
starts meaning "John edited a prompt" — and the moment that happens twice, the
gate is muted and the frozen corpus loses its alarm. So: **two registries, two
gates, two pin disciplines.** `ci/examples.sh` keeps equality. `ci/workflows.sh`
pins `level` and `paths` by equality (a new branch is a *design* change and
should be seen) and `costMax` as a **ceiling that only ratchets down**, plus
`--require-pinned` over every row. §2 spells both out.

**The five flagships**, one line each:

| # | Name | Design in one line | The capability the md lacks |
|---|---|---|---|
| 1 | `review` | The whole review ladder as one `Parameterized` program: `rung` and `langs` are **inputs**, so the panel roster is ordinary Haskell computed before the program exists; one frozen-scope receipt bound once and spliced into every member; `panelText` folds the report; the tail is one `Fn` every arm calls. | **Priced branching** — `cost review --input-arg rung=heavy --input-arg langs=hs,rs` is a number before the first token, where five Markdown rungs and a copy-pasted ladder paragraph can say nothing at all. |
| 2 | `green` | `fix-ci`/`fix`/`flaky` as one gated loop: `revisingOn` over a `gh pr checks` receipt, settled by `decide LastNonEmptyLineIs`, `amend` on an objection, **`abandon` naming the check still red**, and the exhausted arm yielding the partial state. | **Yielded exhaustion with a third fate** — the md's "monitor until everything passes" is unbounded and has no way to distinguish *still failing* from *cannot be fixed*. |
| 3 | `commit` | The atomic-commit discipline as the toolbox's most-called `Fn` (`commit`/`push`/`recommit`/`bankruptcy` are four **inputs**, not four files), with a per-commit `make test` receipt gating the next commit and a `git rev-parse HEAD^{tree}` before/after pair proving `bankruptcy`'s stated postcondition. | **One binding, four callers, priced at the callee's own body** — three commands re-enter `commit` today by quoting its name. |
| 4 | `audit` | `fess-auditor`'s ten sins as ten `panelText` members over one frozen change, behind an independence gate whose failure **downgrades rather than aborts** (a labelled-unverified arm of a total `case`), with every "quote the command" demand a receipt the world authored. | **World-authored receipts under a total case** — the auditor's own "verification gap" category, turned on the auditor. |
| 5 | `restack` | The Graphite stack pipeline: the step-1 baseline is a receipt **bound at depth 0 and live for the whole run**, steps 5 and 7 are nested `revisingOn` settled by pure deciders over real build receipts, step 9's `git range-diff` proof is compared against that first handle, and steps 4 and 8 are `call_ resolveFn` / `call_ commitFn`. | **A handle bound before the destruction that survives to prove it** — "record the starting state so the report can prove nothing was lost" is, in Markdown, a request to remember. |

---

## 1. The capability vocabulary

Twelve capabilities. Every triage row in §3 cites at least one; a row that can
cite none is KEEP-AS-MD by definition. This is the whole method of this
proposal: *if you cannot name the capability, you do not have a workflow, you
have a prompt that compiles.*

| Code | Capability | Mechanism | What it costs |
|---|---|---|---|
| **C1** | Priced before running | `level`, `size`, `askNodes`, `costSummary` min/max over N paths | nothing; it is a fold over the program text |
| **C2** | Zero-question deciders | `decide ContainsLine \| LastNonEmptyLineIs \| AnyLineStartsWith \| AnyPathMatches` | **zero** questions on every path, same paths, same rung |
| **C3** | World-authored receipts | `tool "x" \`running\` (cmd, args)` through `Agentic.Shell` (`proc`, never `sh -c`) | one question; the bytes are not the model's |
| **C4** | Yielded exhaustion, three fates | `revisingOn` → `SettledOn`/`UnsettledOn`/`AbandonedOn`, all three binding the candidate | `atMost n`; the block is replicated 2n+1 times |
| **C5** | Structural read-only | `permissionByCode`: only a `CodeAck` answer may write | nothing; it is the absence of an `act` |
| **C6** | Addressee on the question | `servedBy`, `fallingBackTo`, `--require-pinned` refusing before spending | nothing; an alternate is not part of the question |
| **C7** | One binding, many callers | `function`/`takes`/`call`/`call_`/`defining` | a call is priced at the callee's own `bodyAsks` |
| **C8** | Holes are data | `[wf\|…{hole}…\|]`; three meanings only; a splice never fuses with its neighbour | nothing; it is what a prompt *is* here |
| **C9** | Total arms | `case` on `Outcome`/`Ending` is total; `unless … stop` is a terminal | one arm the author cannot forget to write |
| **C10** | Independent draws | `drawing n` — two draws of one prompt are two questions | n questions, priced apart from a memo hit |
| **C11** | Falsifiable memo bill | `billFresh` vs `billMemo` as two objects | nothing; the saving is a number that can be wrong |
| **C12** | Program inputs | `taking`/`input`; `--input`, `--input-file`, `--input-arg` | nothing; a define never enters a scope |

### Three house rules that fall out of the semantics

These are load-bearing for every design below, and two of them are findings
rather than restatements.

**WR-1 — a roster-shaping input must be total on the empty text.** `plan` and
`cost` supply `""` for an input nobody gave (`run/Main.hs`, `bind`'s
`needsAll = False` arm), and `panel []` is an `error` on a CAF. So any Haskell
that computes a panel roster from an input must read `""` as *the default
roster*, never as *no members*. `workflows plan review` with no flags then
prices the default rung, which is what an operator expects, and `ci/workflows.sh`
can price every row with no fixtures at all.

**WR-2 — a two-settings-of-one-dial pair is an input, never a decider.** The
corpus has six near-duplicate pairs (`rebase`/`rebase-and-fix`,
`partner-reviewer`/`partner-collaborator`, `retest`/`retest-categorical`,
`report`/`sitrep`, `smooth`/`proofread`, `medium`/`heavy`). The reflex is a
router: bind a flag, branch. That is wrong here, and the reason is arithmetic.
A `Parameterized` is *an ordinary Haskell function to a `Program`*, so
`if kind == "halt" then … else …` on an **input** is Haskell's own `if`, chosen
before any plan exists: two different programs, **one path each**, each priced
exactly. The same distinction as a `confirm` + workflow `if` is one program,
**two paths**, a paid question, and a `costSummary` that reports the union of
two things the operator was never going to run together. *An input costs zero
paths and zero questions; a decider costs zero questions and one path; an asked
flag costs one of each.* Reach in that order.

**WR-2 has a corollary worth its own sentence: `D8` relaxes `G8`.**
`isaac-workflows` §4 records "a fan-out is a static list" as a gap, and it is —
for a list derived from an *answer*. It is not a gap for a list derived from an
*input*, because `supply` runs before the `Program` value exists. So
`panel (crossCuttingOver scope ++ concatMap (lensFor scope) (parseLangs langs))`
is a legal, dynamic, **priced** fan-out. This is the single most useful thing
the language can do for this corpus, because the corpus's most common shape —
`deep-review`'s extension→agent table, `teams`'s twelve roles, `prepare-with`'s
and `resolve`'s `$ARGUMENTS` rosters, `productize`'s 21 deliverables — is
exactly a roster the operator names.

**WR-3 — what a person chooses is an input; what the world knows is a receipt.**
Take the rung, the language set, the PR number, the scope path and the strength
dial as inputs. Never take the diff, the branch name, the check status or the
file list as an input if the program can run the argv itself: an input the
operator computed is an input the operator can get wrong, and a receipt is bytes
the program did not author. The one honest exception is a subject that lives
outside the repository the run is in — `review-lite`'s `--input ./commit.diff`
is that exception, and so is `notes`' meeting file.

---

## 2. Integration

### 2.1 The Stage-0 refactor: the registry becomes a value

`haskell/src/Agentic/Cli.hs`, new, holding everything `run/Main.hs` has today
except the three registry functions:

```haskell
module Agentic.Cli (Registry (..), Entry (..), cliMain) where

data Entry = Entry
  { entryExample :: !Example       -- Fixed prog | Needs parameterized
  , entryBlurb   :: !Text          -- one line, for `list` and for usage
  , entryScript  :: ![(Text, Text)]-- canned replies; [] is honest for a toolbox row
  }

data Registry = Registry
  { regBinary  :: !Text            -- "agentic-run" | "workflows"
  , regBlurb   :: !Text            -- the usage header
  , regEntries :: ![(Text, Entry)]
  }

cliMain :: Registry -> IO ()
```

`run/Main.hs` becomes:

```haskell
main :: IO ()
main = cliMain examplesRegistry   -- Example.Harden
```

`Example.Harden.examples` gains an `entryBlurb` per row and absorbs
`run/Main.hs`'s `scriptFor` as `entryScript` (its `harden`/`hello` tables move
beside the programs they answer, which is where `isaacScript` already lives and
for the reason `Example.Isaac` gives: a key that *is* the prompt define is a
prefix by construction).

**The gate on the refactor itself.** `ci/examples.sh` must produce byte-identical
output before and after. That is the whole acceptance test for Stage 0: a
mechanical extraction that moved a number is not a mechanical extraction.

One new verb falls out and is worth having: **`list`**, which prints each row's
name, blurb, and `costSummary`. `agentic-run list` gets it for free; that is an
improvement to the examples CLI, not a cost.

### 2.2 The cabal components

```cabal
-- The owner's toolbox: his commands, agents and skills as priced programs.
--
-- An internal library and not a directory glued onto `agentic-run`, because the
-- two registries are held to two different gates. `ci/examples.sh` pins the
-- examples by EQUALITY — they are conformance-adjacent, and a moved number is a
-- fact about the language. These churn: a lens added to `Workflows.Rubrics`
-- moves askNodes, costMax and every path count in every program that panels it,
-- and that is a Tuesday, not a regression. `ci/workflows.sh` pins what a
-- toolbox can honestly hold still: level, paths, and a cost CEILING.
library workflows
  import:          settings
  hs-source-dirs:  workflows
  exposed-modules:
    -- the foundation, built once
    Workflows.Prose
    Workflows.Rubrics
    Workflows.Panels
    Workflows.Receipts
    Workflows.Gates
    Workflows.Commit
    Workflows.Tiers
    -- the programs, one module per family
    Workflows.Review
    Workflows.Green
    Workflows.Audit
    Workflows.Restack
    -- the catalog
    Workflows.Registry
  build-depends:   agentic

executable workflows
  import:          settings
  hs-source-dirs:  wf
  main-is:         Main.hs
  build-depends:   agentic, agentic:workflows
  -- the same departure agentic-run makes, for the same reason: an ACP turn's
  -- timeout is `System.Timeout.timeout` around a blocked pipe read.
  ghc-options:     -threaded
```

`wf/Main.hs` is five lines. `workflows/Workflows/Registry.hs` is the catalog and
the only module the executable imports.

**Naming.** Directory `workflows/` at `haskell/workflows/` (cabal resolves a
module name to a path, so `Workflows.Review` is
`haskell/workflows/Workflows/Review.hs` — the same lesson `example/Example/`
records). Program names in the registry are **lower-case, hyphenated, and the
owner's own word where one exists**: `review`, `green`, `commit`, `audit`,
`restack`. Where a program absorbs several commands, the *command's* name
survives as an input value, not as a registry row — `workflows run commit
--input-arg mode=recommit`, not a `recommit` row. One name per *shape*, not one
per *invocation*.

### 2.3 `ci/workflows.sh`

```
for each row in `workflows list`:
    workflows plan <row> --require-pinned            level, paths        EQUALITY
    workflows cost <row>                              costMax             CEILING (≤)
    every row in the table has a registry entry, and vice versa
one designated smoke row:
    workflows run <row> --engine acp --adapter stub   exit 0
```

Three properties, each argued:

* **`level` and `paths` by equality.** A program that gained a branch gained a
  design decision, and the owner should have to acknowledge it. These are the
  two folds that move only when the *shape* moves.
* **`costMax` as a ceiling that only ratchets down.** A budget is a promise
  about the worst case. Ratcheting down is a real improvement worth pinning;
  ratcheting up should require editing the ceiling, which is one line and a
  moment's thought — exactly the friction that belongs on "this review now costs
  40 questions instead of 24".
* **`--require-pinned` on every row.** The examples do not require it; the
  toolbox should. `run/Main.hs` checks it *before* a plan is printed or an
  adapter is started, so a workflow with an unpinned model ask is refused
  without spending anything. In a toolbox that will be pointed at codex and
  claude alternately, an unpinned reviewer is a reviewer whose identity is an
  accident of the command line.

`--scripted` is deliberately **not** run over the toolbox. A canned table proves
nothing about a program whose gates are `running` parties, and `run/Main.hs`
already says so out loud ("no command was run; every gate in this program was
answered from the table"). One stub-adapter smoke row is enough to prove the
transport still works.

### 2.4 What `workflows/` must never do

* Never import from `test/corpus` or `tier1`. The toolbox is not conformance and
  must not be able to make a corpus gate red.
* Never write outside the working directory the run was given (`--scratch`, or
  the fresh temporary directory `--engine acp` makes). Acts that touch
  `~/src/nix/config/ai` are forbidden by construction — no program in the
  toolbox has a `running` party pointed at that tree, and the one place that
  rule could be broken is `Workflows.Receipts`, which is one module and reviewable
  as a unit.
* Never carry corpus text the owner has not agreed to move. Every define in
  `Workflows.Rubrics` names its source file in a haddock line, and the
  inventories in this directory are the audit trail.

---

## 3. The shared foundation

Seven modules, built once, called by every workflow. This is D1's payoff at
scale: the corpus has the finding schema in **eleven byte-similar copies**, the
review-ladder paragraph in **at least five**, the no-history sentinel in
**three spellings**, and the generic "live web search / sequential thinking"
bullet pair in **six files**. Each of those becomes one binding.

### `Workflows.Prose`

The mechanics `Example.Isaac` keeps private, promoted so every module shares
them, plus the voice rubrics and the two prompt *combinators*.

```haskell
wfText   :: Words '[] -> Text          -- a define's text (Builder.wordsClosed)
bullets  :: [(Text, Text)] -> Text     -- a roster as the bullet table a brief holes
tshow    :: Int -> Text                -- a derived count, as prompt text
fenceOf  :: Text -> Text -> Text       -- one named block of a folded document

johnwVoice, itVoice, smoothRestraint, proofreadProhibitions :: Text
compress :: Fn '[ 'CodeText] 'CodeText     -- skills/caveman, as a callable
translate :: Fn '[ 'CodeText, 'CodeText] 'CodeText  -- prompts/spanish.md's one hole
critique :: Fn '[ 'CodeText, 'CodeText] 'CodeText   -- johnw's NEVER-lists, split off
```

*Sources:* `skills/caveman`, `skills/it-voice`, `skills/johnw`,
`prompts/spanish.md`, `commands/smooth.md`, `commands/proofread.md`.
*Capability:* **C7** — `caveman` is a transform *on other prompts*, which is the
corpus's first genuinely reusable prompt combinator and which no Markdown skill
can be. **C2** — its "Output ONLY the compressed text" is
`LastNonEmptyLineIs`-adjacent and costs nothing to check.
*Note:* `johnw` is **two things fused** — a generation rubric and a critique
checklist. Splitting them here is the "level up": the same model that wrote the
draft is a bad judge of whether it opened with a forbidden opening.

### `Workflows.Rubrics`

Every rubric define, every roster table, and the finding schema — the module
that ends eleven copies.

```haskell
findingSchema          :: Text   -- the ONE copy; nine agents are byte-identical today
findingSchemaSoundLine :: Text   -- cpp/typescript's extra line
findingSchemaConfident :: Int -> Text  -- security ≥85, perf ≥80, derived not spelled
severityVocabulary     :: [Text] -- and deep-review's two extra Categories, reconciled once

languageLenses :: [(Text, Text, [Text])]   -- (name, rubric, path globs)
crossCutting   :: [(Text, Text)]           -- security, perf
fessSins       :: [(Text, Text, Text)]     -- (name, harm, the interrogative)
evasionPatterns:: [(Text, Text)]           -- abstraction-review's seven
alexeyGears    :: (Text, Text)             -- principles WHAT, stance HOW, in that order
fixAllRule     :: Text                     -- the standing constraint every fixer splices
ponytailSlot   :: Text                     -- EXTERNAL: an owner-filled define, never our text
rungs          :: [(Text, Text, Int)]      -- the review ladder: name, blurb, atMost
```

*Sources:* the eleven `agents/*-reviewer.md`, `agents/fess-auditor.md`,
`skills/abstraction-review`, `skills/alexey-review`, `skills/fix-all`,
`commands/quick-review.md`'s ladder paragraph.
*Capability:* **C8** — one `findingSchema` holed into eleven prompts makes drift
*impossible* rather than merely unlikely, and the corpus has already drifted
once (in `deep-review`'s consumer, which adds `Simplification` and `Dead Code`
to a vocabulary no agent file carries). **C6** — `rungs` is the ladder as a
Haskell value from which every brief derives its "see also" text, so a rung
added arrives in all five briefs by being added.
*Design note:* `languageLenses` carries its **path globs beside its rubric**,
because the `deep-review` extension→agent table is a pure function of the file
list and belongs next to the thing it selects. Its silent hole — `.lean`, `.go`,
`.java`, `.rb`, `.swift`, `.ml` falling through to `general-purpose` — becomes a
row, which is the point.

### `Workflows.Panels`

Roster → fan-out constructors. The one module that turns a table into questions.

```haskell
crossCuttingOver :: KnownIx h s => V h 'CodeText -> [Ask s]
lensesOver       :: KnownIx h s => [Text] -> V h 'CodeText -> [Ask s]      -- from an INPUT
fessPanelOver    :: KnownIx h s => V h 'CodeText -> [(Text, Ask s)]        -- ten sins, fenced
teamOver         :: KnownIx h s => [(Text,Text)] -> V h 'CodeText -> [(Text, Ask s)]
sectionsOver     :: KnownIx h s => [(Text,Text)] -> V h 'CodeText -> [(Text, Ask s)]
```

*Capability:* **C1 + WR-2's corollary** — `lensesOver` takes the language list as
ordinary `[Text]` parsed from an input, so the fan-out is dynamic *and* priced.
**C10** — the ideation roster (`partner-collaborator`'s "three wild ideas") is
`drawing 3` on one lateral party, which is what "three wild ideas" *means* and
what one prompt asking for three cannot give.
*This is where `skills/parallelize` dissolves.* Seven inbound edges, more than
any other skill in the corpus, and every one of them wants "run these N things
independently and prove the children did not inherit my context." A `panel` is
independent by construction, the fan-out arity is priced by `costSummary`
instead of capped at a guessed 3–5, and the ten-bullet list of shared state a
subagent must not touch is a hand-written type system for an untyped harness
that has no referent here: no `ask` writes anything.

### `Workflows.Receipts`

The argv library. Every "if available, run X" in the corpus, as a command the
world runs.

```haskell
gitStatus, gitDiffNameOnly, gitTreeHash, gitDiffCheck, gitRangeDiff :: (Text, [Text])
ghPrChecks, ghPrList, ghPrViewJson, ghApiGraphql                    :: ...
gtLs, gtRestack, gtSubmit                                           :: ...
hlintJson, shellcheckJson, ruffJson, mypy, bandit, clippy, cargoAudit,
  clangTidy, cppcheck, statix, deadnix, nixFlakeCheck, tsc, eslint,
  printAssumptions                                                  :: ...
historyProbe                                                        :: ...
secretsGrep, dangerousPatternsGrep, hardcodedIpGrep                 :: ...
```

*Sources:* the seven agent tool blocks; `commands/sec-audit.md`'s three exact
regexes; `commands/restack.md`'s `git range-diff`; `commands/cleanup.md`'s four
obligations; `skills/parallelize`'s `verify-history-isolation.py`;
`skills/comment-audit`'s `inventory_comments.py`; `skills/nixos`'s three hard
prohibitions, which ride on the argv rather than in prompt text.
*Capability:* **C3**, and this module is the single largest honesty gain in the
whole exercise. The agent inventory names it precisely: "If available, run
`ruff check <file> --output-format=json`" is a sentence addressed to a model
that may run it, may claim to have run it, or may hallucinate its output —
"the largest single defect in the family, and it is exactly `fess-auditor`'s own
*fallback smuggling* and *verification gap* categories turned on the reviewers
themselves." Under `running`, the argv is program-authored, `proc` runs it
(never `sh -c`, so the unquoted `<file>` placeholders stop being an injection
surface), and the receipt is bytes the answering model did not write.
*Also:* `catalog.nix` grants `run-commands` to all eleven reviewers and four of
them never run one. Here a missing tool is a receipt saying so, not a silence.

### `Workflows.Gates`

Check-fix-recheck, as callable functions rather than as a paragraph repeated in
every command that wants it.

```haskell
-- a receipt + a decider + the needles, as one callable
greenGate   :: Fn '[ 'CodeText] 'CodeFlag     -- nix flake check / make test
ciGate      :: Fn '[ 'CodeText] 'CodeFlag     -- gh pr checks, LastNonEmptyLineIs
cleanTree   :: Fn '[]           'CodeFlag     -- git diff --check, zero markers
headPin     :: Fn '[ 'CodeText] 'CodeFlag     -- HEAD == headRefOid, else stop
independence:: Fn '[ 'CodeText] 'CodeFlag     -- parallelize's sentinel, ONE spelling
consent     :: Fn '[ 'CodeText] 'CodeFlag     -- test -f <file>; the run may not create it
outputShape :: Decider -> [Text] -> ...       -- prompt-engineer's contract, as a decider
```

*Capability:* **C2 + C9**. Three files (`alexey`, `deep-review`, `heavy-review`)
carry the no-history sentinel in three slightly different spellings of one gate;
`independence` is one. And every gate's failure arm is `unless ok stop` — a
terminal the compiler will not let the author drop, which is `I4` on a real
workflow rather than on an example.
*The sharp one:* `consent`, from `stack-prs`, generalised. A human gate is not
real when unattended, because an unattended run auto-answers its gates; the last
thing between a draft and a public artefact is a file the agent is forbidden to
create. `commands/install-service.md`'s two capital-letter pleas ("DO NOT
generate the certificate yourself, ask me") are this gate, twice.

### `Workflows.Commit`

The git discipline as a function table, because `commit` and `resolve` are the
corpus's two clearest existing function calls and neither can say so.

```haskell
commitFn  :: Fn '[ 'CodeText, 'CodeText] 'CodeAck  -- scope, style
resolveFn :: Fn '[ 'CodeText] 'CodeAck             -- agents; postcondition: staged, uncommitted
pushFn    :: Fn '[ 'CodeText] 'CodeAck
restackFn :: Fn '[ 'CodeText] 'CodeAck
```

*Callers today, by name in prose:* `commit` ← `bankruptcy`, `fix`, `halt`,
`push`, `recommit`, `wiggum`; `resolve` ← `rebase`, `rebase-and-fix`, `restack`.
*Capability:* **C7 + C5**. `resolve`'s "do not commit" and
`partner-cleanup`'s "the sub-agent must not commit" are the same construct:
`permissionByCode` grants write authority only to a `CodeAck` answer, so a
question returning `CodeText` structurally cannot commit. Five paragraphs of
English across five files become one type.

### `Workflows.Tiers`

The effort ladder — `medium ⊂ heavy ⊂ forge` — as the owner's own cost model,
finally priced.

```haskell
data Tier = Tier { tierName :: Text, tierRoster :: [Text], tierFuel :: Int, tierPin :: Text }
tiers :: [(Text, Tier)]      -- medium, heavy, forge; retest's four skip flags; cap=N
```

*Capability:* **C1**. Four skills hand-roll a context budget by guessing a number
(comment-audit's 10–15-per-batch, wiggum's post-compaction re-read, forge's
"do not write temp files unless context size demands it", parallelize's cap of
3–5). All four are guessing at what `costSummary` *computes*. `toolkit` declares
the ladder and prices none of it; three programs sharing one `Tier` table and
reporting three `costSummary`s is the whole of what that declaration wanted to
say.

---

## 4. The triage, decisive

Verdicts: **TRANSFORM** (an agent-cat program) · **REWORK** (a program, but the
md needs rethinking first — what, stated) · **KEEP-AS-MD** (honestly not a
workflow) · **FOLD-IN** (a function/rubric inside a named host). Every FOLD-IN
names its host. Every TRANSFORM and FOLD-IN cites a capability code from §1.

### 4.1 Commands, A–L (31)

| # | Command | Verdict | Design / host | Cap |
|---|---|---|---|---|
| 1 | `alexey` | FOLD-IN → `review` | rung `alexey`: one panel member from `alexeyGears` (principles composed before stance, which is the file's own Conflict rule as composition order), behind `Gates.independence` | C2 C5 C7 |
| 2 | `assess` | FOLD-IN → `pr-threads` | mode `assess`: the read-only arm. The "and/or" across three language pros becomes `lensesOver` from an input; the `opus` pin moves onto the question | C6 C12 |
| 3 | `bankruptcy` | FOLD-IN → `commit` | mode `rebuild`. Its stated postcondition ("unchanged working tree") becomes a `gitTreeHash` receipt before and after with `decide ContainsLine`, and `unless same stop` | C3 C2 C9 |
| 4 | `breakdown` | TRANSFORM → `org-tasks` | one `Fn` per direction; four shape deciders (`AnyLineStartsWith ["** TODO"]`, `ContainsLine` for `[ATOMIC]`/`[AMBIGUOUS:`, `LastNonEmptyLineIs`) wrapped in `revisingOn` that amends with the violated rule spliced in | C2 C4 C8 |
| 5 | `bugbot-stack` | TRANSFORM → `pr-stack` | `gtLs` receipt for the roster; `call pr-threads`'s Fn per branch with the exclusion policy as an **argument**; exhausted sweep yields the partial tally | C3 C4 C7 |
| 6 | `bugbot` | TRANSFORM → `pr-threads` | mode `resolve`. The ledger is bound **once** from a `ghApiGraphql` receipt, so a comment arriving mid-run has no way in; `settle` is a receipt showing `isResolved: true`; "retry once" is `atMost 2` with a real `abandon` naming the thread | C3 C4 C9 |
| 7 | `capture` | **KEEP-AS-MD** | three lines onto a large instruction file that lives elsewhere; a program adds ceremony and no capability | — |
| 8 | `cleanup` | FOLD-IN → `restack` | the per-branch hygiene `Fn`. Three of its four obligations are exit codes and diffs — facts the file asks a model to assert; the `nix develop --command` hedge disappears because the argv is program-authored | C3 |
| 9 | `code-review` | FOLD-IN → `review` | rung `repo`. Its dozen concerns are twelve panel members; its mutating half (new tests and docs) is **not** a review and moves to `productize` | C1 C5 |
| 10 | `commit` | **TRANSFORM → `commit`** | **FLAGSHIP 3** | C7 C3 |
| 11 | `deep-review` | **TRANSFORM → `review`** | **FLAGSHIP 1** | C1 C2 |
| 12 | `discover-bundles` | TRANSFORM → `bundles` | seven weighted criteria as panel members; six reject conditions as deciders firing **before** any paid scoring; read-only structural, which matters more here than anywhere — the scorer is reading adversarial text | C5 C2 C1 |
| 13 | `eliminate-dead-code` | FOLD-IN → `dead-code` | the command is an honest thin adapter; the machinery is the skill's (row 13 of §4.3) | — |
| 14 | `expense-report` | TRANSFORM → `expenses` | person in **binding** position driving `revisingOn`: accept→settle, edit→amend with the correction spliced into a re-rendered table, abandon→stop; the decorative `REVIEW` flag becomes `ContainsLine` gating that loop at zero cost | C4 C2 C3 |
| 15 | `fix-alert` | FOLD-IN → `nixfix` | kind `alert`, **after REWORK**: naming `caveman` beside a diagnostic skill is a category error at the point of use — it compresses the very alert text whose details decide the diagnosis. If compression is wanted it is an earlier question with its own handle, so the program shows which text the diagnosis read | C8 C12 |
| 16 | `fix-ci` | **TRANSFORM → `green`** | **FLAGSHIP 2** | C4 C3 |
| 17 | `fix-github-issue` | FOLD-IN → `issue` | mode `worktree`. It is `fix` minus the PR tail with a divergent agent roster (no `haskell-pro`); one body, two terminals. "Leave it uncommitted" becomes a postcondition receipt, not an instruction | C7 C3 |
| 18 | `fix-integration` | FOLD-IN → `nixfix` | kind `integration`; the hardcoded error string becomes a second input whose `Example` carries today's text, so it generalises without losing its default | C12 |
| 19 | `fix-transcript` | TRANSFORM → `transcript` | the rule-priority list is a define, the two reference corpora are inputs, and the injection guard is **structural**: the transcript arrives as a `{hole}` — data, three meanings, never fusing with the literal beside it | C8 C3 |
| 20 | `fix` | TRANSFORM → `issue` | three cheap gates decide whether any expensive work happens (`ghPrList` + `ContainsLine` for the open-PR early exit; `AnyPathMatches ["test/todo/<N>.test"]` for the migration branch), each feeding an `if` whose false arm is `stop`; then `call_ commitFn`, `call_ greenFn`, `call_ prThreadsFn` | C2 C7 C1 |
| 21 | `flaky-rust` | TRANSFORM → `flaky` | `drawing n` over a `running` test party — *two draws of one prompt are two questions* — and a decider over the collected receipts deciding **flaky vs broken** before any model is consulted. That distinction is the whole task and the md cannot make it. Generalised past Rust: the argv is an input | C10 C3 C2 |
| 22 | `forge` | FOLD-IN → `forge` | the command is the corpus's cleanest pure entry point and its no-drift clause is exactly right; as a `call` there is nowhere to restate | C7 |
| 23 | `gravity` | **KEEP-AS-MD** | a stance prompt is a stance prompt; machinery adds cost and subtracts candour. (If the owner ever wants *disagreement between critics* rather than one critic's confidence, it is `panel` with three `servedBy`s — flagged, not asserted) | — |
| 24 | `halt` | FOLD-IN → `account` | kind `halt`, which additionally `call_ commitFn`. Its most interesting feature — emitting a document that instructs a later run — is a define spliced by one hole into the emitted document: a program authoring a prompt, where the boundary is a hole rather than a hope | C7 C8 |
| 25 | `heavy-review` | FOLD-IN → `review` | rung `heavy`, seven passes. Every one of its four load-bearing guarantees is currently a sentence; §5.1 shows all four as mechanisms | C3 C2 C6 C9 |
| 26 | `heavy` | FOLD-IN → `task` | rung `heavy` in `Workflows.Tiers`. Its one branch is `AnyPathMatches ["*/positron/*","*/pos/*"]` over the cwd — zero questions where the md spends a turn asking where it is | C2 C1 |
| 27 | `infer-tasks` | TRANSFORM → `org-tasks` | its thirteen-item self-validation checklist **splits**: the mechanical eleven become deciders at zero questions; the two judgment items go to a question `servedBy` a *different* model, which is the point — a second party checks the first | C2 C6 C4 |
| 28 | `initialize` | FOLD-IN → `claude-md` | `AnyPathMatches ["CLAUDE.md"]` decides file-vs-critique for free; the two arms are two `Fn`s with different terminals; the mandatory prefix is a define that cannot drift | C2 C8 |
| 29 | `install-service` | FOLD-IN → `service` | op `install`. Both handoffs become `ask_ (person "owner")`, so the run *structurally* cannot proceed past them and the plan says **who** is asked; item 10's "test to ensure it is working" is a `systemctl`/`curl` exit code | C9 C3 C6 |
| 30 | `journal` | **KEEP-AS-MD** | its value is editorial taste, which no construct improves, and its one mechanical rule (append-only) is better enforced by the filesystem. Worth being a `call_` from `halt`, and nothing more | — |
| 31 | `lefthook` | FOLD-IN → `productize` | the shared `lefthook` `Fn` with two entry points; slicing a section out of a sibling command by prose reference is exactly the coupling that rots | C7 C3 |

### 4.2 Commands, M–Z (36)

| # | Command | Verdict | Design / host | Cap |
|---|---|---|---|---|
| 32 | `markdown` | FOLD-IN → `Workflows.Rubrics` | `suggestionFormat` + a `report.suggestions` `Fn` called as the tail of every review rung, so six review commands cannot drift in their output format | C7 |
| 33 | `medium` | FOLD-IN → `task` | rung `medium`; same shape as `heavy`, different `atMost` and `servedBy`, and `costSummary` says what the tier costs before it is spent | C1 |
| 34 | `meeting-notes` | TRANSFORM → `notes` | ten `panelText` members over one `{notes}` input, section names as fence labels; then the five quality checkpoints as a **separate** panel on a different `servedBy` — a fact-only discipline audited by the same model is not audited | C6 C1 C12 |
| 35 | `narrative` | FOLD-IN → `account` | kind `narrative`; the evidence dossier is receipts, and "distinguish fact from inference" becomes a `confirm` on another `servedBy` over the dossier, with `revisingOn` to repair | C3 C6 |
| 36 | `nix-rebuild` | TRANSFORM → `nixfix` | the archetypal `running` party: `("./build",["system"])` produces a receipt the world authored, which is then the *subject* of the diagnosis — the difference between "an agent says it rebuilt" and the rebuild's exit text being in the program | C3 C4 |
| 37 | `partner-cleanup` | TRANSFORM → `partner` | role `cleanup`. The drain loop is `revisingOn` settled by an `ls` receipt read by a decider — a **zero-question** loop test; the sub-agent's "do not commit" is `CodeText`, so it has no write authority | C2 C5 C4 |
| 38 | `partner-collaborator` | FOLD-IN → `partner` | role `watch`, `ideas=yes`. The ideation pass is `drawing 3` on one lateral party | C10 C12 |
| 39 | `partner-reviewer` | FOLD-IN → `partner` | role `watch`, `ideas=no`, engine `heavy`. ~85% duplication that has **already drifted** (a differing Category enum, a typo on one side); WR-2 makes it one program and two invocations | C12 C7 |
| 40 | `prepare-with` | FOLD-IN → `claude-md` | the `$ARGUMENTS` agent roster is an **input**, so the fan-out is dynamic and priced; the eight negative rules become a `fess`-style auditor over the draft rather than eight rules nothing checks | C12 C6 |
| 41 | `process-checklist` | TRANSFORM → `checklist` | outer `revisingOn` whose settle test is `decide ContainsLine checklist ["- [ ] "]`, inverted — **zero questions per trip** where the prose spends a full re-read; ten lines with the highest structure-to-prose ratio in the corpus | C2 C4 |
| 42 | `productize` | TRANSFORM → `productize` | a 21-row roster priced at 21 before it starts; each deliverable a `running` receipt; the language table's five "use web search to find the best option" cells become one search question **per language present**, not per deliverable | C1 C3 |
| 43 | `proofread` | FOLD-IN → `polish` | strength `strict`. Its five prohibitions become a second-model diff auditor with `unless → revert` | C6 C12 |
| 44 | `push` | FOLD-IN → `commit` | mode `push`. The file's entire content is "call `commit`, then two more things" — priced at `commit` + 2, which is a number where today it is a sentence | C7 C1 |
| 45 | `qanda` | TRANSFORM → `qanda` | the purest **person in binding position** in the corpus: one `ask (person "operator")` per decision, each answer live for the questions after it, the roster from an input. The shape `ship-feature-lite`'s `steer` already proves | C12 C1 |
| 46 | `query-builder` | TRANSFORM → `query` | the schema read and the query write are two questions with two **codes**; a `CodeText` schema reader structurally cannot act, and the data is never in scope to leak because no question puts it there. Three repetitions of "never reveal data" collapse into one type | C5 |
| 47 | `quick-review` | FOLD-IN → `review` | rung `quick`. The ladder paragraph — the corpus's only statement of how its commands relate, maintained by copy-paste in five files — becomes `Rubrics.rungs`, from which every brief derives its "see also" | C7 C1 |
| 48 | `rebase-and-fix` | FOLD-IN → `restack` | `followUp=yes`. It is four commands in one file; as four `call_`s (`resolveFn`, `restackFn`, `greenFn`, `prThreadsFn`) the fusion dissolves, and its stated branch↔commit invariant becomes a `gitRangeDiff` receipt | C7 C3 |
| 49 | `rebase` | FOLD-IN → `restack` | `followUp=no`; three descendant-rewrite bullets are byte-identical with its sibling today | C12 |
| 50 | `recommit` | FOLD-IN → `commit` | mode `recommit`. "Each commit must pass CI on its own" is a per-element check over a produced list, asserted and never run — here `revisingOn` per commit with a build receipt at each candidate; worst case `commit + 3n`, best `commit + n`, over n paths | C4 C3 C1 |
| 51 | `remove-service` | FOLD-IN → `service` | op `remove`. Its generate-a-script-do-not-run-it inversion is `I3` avant la lettre and becomes the pattern's named exemplar: every discovery question returns `CodeText`, and the script is one `act` at the end | C5 C9 |
| 52 | `report` | FOLD-IN → `account` | kind `report`; seven categories as `panelText` members so none can be silently dropped; the estimate is a separate question on a separate `servedBy` over the **fold**, so the estimator reads what the panel said and not what it wishes; the metadata-tags idea becomes `--input` on re-run | C6 C12 |
| 53 | `resolve` | FOLD-IN → `Workflows.Commit` | `resolveFn`, plus a thin registry row. Already a function in everything but syntax: three callers, a parameter, one job, a crisp postcondition (`gitDiffCheck` read by a pure decider) | C7 C2 C5 |
| 54 | `respond` | FOLD-IN → `pr-threads` | mode `respond`. Never-posting is not a rule but an **absence**: no question in the program is a `running` party with a write verb | C5 |
| 55 | `restack` | **TRANSFORM → `restack`** | **FLAGSHIP 5** | C3 C2 C4 C7 |
| 56 | `retest-categorical` | FOLD-IN → `retest` | nine override rows become nine **inputs**. Phase numbering ceases to exist as a concept — phases are statements in a body, not numbers in prose — so the documented off-by-one is unrepresentable, and `--no-semantic` means one thing at one binding site | C12 C9 C1 |
| 57 | `retest` | TRANSFORM → `retest` | its five-value verdict taxonomy is a total `case`; its `MODELS` set is derived from the branch diff by a receipt feeding downstream phases; and `costSummary` prices an eight-model FPGA battery **before an FPGA is touched**, where the phases cost hours | C9 C3 C1 |
| 58 | `review-github-pr` | FOLD-IN → `review` | rung `pr`. The head-OID check is two receipts compared by a decider with `unless … stop`; the four shouted prohibitions become zero lines, which also removes a prompt that names its own attack | C2 C5 C9 |
| 59 | `run-orchestrator` | **REWORK** → FOLD-IN → `wiggum` | the rework: steps 5–6 describe a **dependency graph** and the file provides no way to express one. It has to become a topologically sorted `[(Text,[Text])]` in Haskell before it is a program at all; then "identify parallelizable tasks" is a pure computation over the table, not a question. Its autonomy clause plus an unbounded loop is `G9`, and the refusal is the safety property | C12 C1 |
| 60 | `sec-audit` | FOLD-IN → `review` | rung `sec`. Three of its four evidence sources are `grep`s with fixed regexes — facts, not opinions — and the file asks a model to run them and report what it saw. Three `running` parties make three quarters of the evidence unfalsifiable-by-omission, on the one command where a fabricated "no secrets found" costs the most | C3 |
| 61 | `sitrep` | FOLD-IN → `account` | kind `sitrep`; eight sections over a receipt-backed dossier, so `Measurements` cannot invent a number no command produced; the filename scheme is computed in Haskell from receipts, which removes the one thing a model reliably gets wrong here | C3 C6 |
| 62 | `smooth` | FOLD-IN → `polish` | strength `light`; the restraint clause becomes a `confirm` on another `servedBy` asking whether any sentence changed meaning, with `revisingOn` amending toward a lighter touch | C6 C4 |
| 63 | `teams` | TRANSFORM → `teams` | the most literal `panel` in the corpus and the cheapest high-value transform: eleven roster rows, `panelText`, and a synthesis whose refusal roster derives from the same table. The devil's advocate must read the *others'* output, so it is a second tier, not a member — which the bullet list cannot say. `costSummary` says 13 before the run | C1 C6 |
| 64 | `transcribe-image` | TRANSFORM → `transcribe` | already the right shape and the only command reaching for a second model by default; `revisingOn draft (atMost 2)` gives "re-review" the stopping rule it lacks, and two independent readings of one image are `drawing 2` | C4 C10 |
| 65 | `tron-debug` | TRANSFORM → `tron` | three `<command>` blocks that are argv waiting to be receipts; the differential's evidence is receipts, so the diagnosis cannot rest on a run that did not happen — which is this command's most exposed failure mode | C3 C4 |
| 66 | `webfix` | **REWORK** → TRANSFORM → `webfix` | the rework: Playwright is an actual **oracle** — a browser that either shows the bug or does not — and the file spends none of its four lines on using it as one. Then: `running` before and after, `revisingOn fix (atMost 3)` settling on a decider over the after-receipt, which converts "resolve the issues" into a reproduction that stopped reproducing | C3 C4 |
| 67 | `wiggum` | TRANSFORM → `wiggum` | the corpus's own top-level loop: `revisingOn work (atMost n)` with five `call_`s (`workFn`, `commitFn`, `auditFn`, `partnerFn`, `restackFn`). `atMost` is the honest, bounded answer to "keep going without pausing" — the safety property an autonomous loop most needs. **Build last**: it calls almost everything | C7 C4 C1 |

### 4.3 Agents (25)

| Agent | Verdict | Host / design | Cap |
|---|---|---|---|
| `security-reviewer` | FOLD-IN → `review` | a `crossCutting` member, in **every** panel regardless of the changeset; its ≥85 confidence floor is a decider, and its five-step Methodology is the one reviewer that is a pipeline by itself | C2 C1 |
| `perf-reviewer` | FOLD-IN → `review` | the second `crossCutting` member; "Impact must be concrete" is a checkable output contract | C2 |
| `haskell-reviewer` | FOLD-IN → `review` | `languageLenses` row + `hlintJson` receipt. The house language, so it dogfoods against this repository on day one | C3 |
| `rust-reviewer` | FOLD-IN → `review` | "every `unsafe` block MUST have a `// SAFETY:` comment" is *literally* `AnyLineStartsWith ["unsafe "]` gating a paid ask; `clippy -D warnings` is a receipt whose exit is meaningful | C2 C3 |
| `nix-reviewer` | FOLD-IN → `review` | three cheap decisive tools (`statix`, `deadnix`, `nix flake check --no-build`); reviews the corpus's own habitat | C3 |
| `bash-reviewer` | FOLD-IN → `review` | densest tool integration in the family — ShellCheck's ~200 rules, which the file itself calls authoritative — so it converts to *mostly* receipt plus a thin judgment ask | C3 |
| `python-reviewer` | FOLD-IN → `review` | `ruff`/`mypy`/`bandit` receipts | C3 |
| `typescript-reviewer` | FOLD-IN → `review` | the argv is project-shaped (`npx` fallbacks, monorepo project references), so its receipt takes the invocation as an input — honest work, not a blocker | C3 C12 |
| `cpp-reviewer` | FOLD-IN → `review` | `clang-tidy` needs a compilation database to say anything true, so its receipt has a real precondition the program expresses as a gate — the case that *forces* a gate | C3 C9 |
| `elisp-reviewer` | FOLD-IN → `review` | its CRITICAL-1 (`;;; -*- lexical-binding: t; -*-` must be line 1) is the purest decider in the corpus: one `AnyLineStartsWith` over the head of the file, zero questions, a whole CRITICAL category answered for free | C2 |
| `coq-reviewer` | FOLD-IN → `review` | best *idea* of the eleven: `Print Assumptions` is a receipt that is a soundness proof obligation, and `Admitted` is a `ContainsLine` gate | C3 C2 |
| `haskell-pro` | FOLD-IN → `Workflows.Parties` + `Rubrics` | a **party** (`servedBy` pin) plus a prompt *library*: its 45 subsections are defines spliced on demand, not 28 KB loaded whether or not the task is about laziness. The overlapping bullets it shares with `haskell-reviewer` become one define with two consumers | C6 C8 |
| `nix-pro` | FOLD-IN → `Workflows.Gates` | a party, **and** its five-step Search Strategy is a small workflow in its own right — five ordered lookups with an existence check, i.e. `revisingOn` over a verification verdict. `nix.search`, used by `nixfix` and `service` | C6 C4 |
| `emacs-lisp-pro` | FOLD-IN → `Workflows.Parties` | a party; its §1–2 overlap with `elisp-reviewer` is one define both use | C6 |
| `typescript-pro` | FOLD-IN → `Workflows.Parties` | a party; its two config samples belong in a repository, not in a prompt | C6 |
| `rocq-pro` | FOLD-IN → `Workflows.Parties` | a party, low priority — orphaned (nothing in the corpus names it) and duplicative of `coq-reviewer` | C6 |
| `cpp-pro`, `python-pro`, `rust-pro`, `sql-pro` | FOLD-IN → `Workflows.Parties` | pins and nothing else; upstream "wanted posters" with no file content to transplant. `sql-pro`'s *consumer* is the interesting one, and its data-secrecy constraint belongs to `query` | C6 |
| `task-breakdown` | FOLD-IN → `org-tasks` | a real analysis→decompose→format pipeline with a completeness gate and three named degenerate cases that are three **arms** | C9 C2 |
| `prd-architect` | **REWORK** → two programs | the rework: it is **two agents in one file** — a generator and a critic — selected by an unstated condition ("When asked to provide feedback on an existing PRD"). Split at the mode boundary into `prd-draft` and `prd-critique` *before* writing either | C12 |
| `persian-translator` | FOLD-IN → `persian` | the cleanest `revising` in the corpus: candidate = translation, review = back-translation + comparison, `atMost n`, settle/amend. Its 50-term glossary is a define; its loop is stated but unbounded today | C4 C8 |
| `prompt-engineer` | **KEEP-AS-MD** | no rubric worth moving, superseded in its own directory by the eleven reviewers, and caveman-damaged to ungrammaticality. Its one strong idea — the mandatory output contract — survives as `Gates.outputShape`, a decider rather than a plea | — |
| `fess-auditor` | **TRANSFORM → `audit`** | **FLAGSHIP 4**. Also: `catalog.nix` aliases the `fess` *command* to this agent's source — two catalog entries over one file, which is a manual sharing hack for exactly what `defining [SomeFn …]` does | C3 C9 C1 |

### 4.4 Skills (26 rows, incl. one external) and `prompts/` (2)

| # | Skill | Verdict | Host / design | Cap |
|---|---|---|---|---|
| 1 | `wiggum` | TRANSFORM → `wiggum` | its DoD is a `revisingOn` verdict set, its bounded-attempt escalation is the fuel bound, and "an exhausted revising **yields** its candidate" is exactly its "report where you are, what you tried, what you need". Its durable-state section (three artifacts, re-read everything after compaction) **dissolves**: a program *is* the durable plan, priced before it runs | C4 C1 |
| 2 | `parallelize` | FOLD-IN → `Panels` + `Gates` | ~90% dissolves — it is a hand-written type system for an untyped harness, and no `ask` writes anything here. What survives: the fan-out cap becomes panel arity **priced** by `costSummary`; the four-part brief becomes a `[wf\|…\|]` with four holes; the sentinel probe becomes `Gates.independence`, **one** spelling of a gate that appears in three today | C2 C3 C1 |
| 3 | `fix-all` | FOLD-IN → `Rubrics.fixAllRule` | the archetypal standing-constraint define, spliced into every fixer ask. Two of its six DoD conjuncts are pure deciders: `wg-*` orphans (`AnyPathMatches`) and a green suite (`LastNonEmptyLineIs`) | C2 C8 |
| 4 | `validated-code-review` | FOLD-IN → `review` | rung `validated`. Its **entire** attestation apparatus — `listmodels` preflight, `metadata.model_used` verification, the abort-on-substitution constraint, the 12-row mistakes table, and `verify-model-dispatch.py` — exists because the harness cannot promise which model answered. `servedBy` with `fallingBackTo` makes that a type and deletes the script | C6 C1 |
| 5 | `abstraction-review` | FOLD-IN → `review` | rung `abstraction`. Its per-divergence verdict set (`EXTENSION`/`EVASION`/`SHOEHORN`/`JUSTIFIED-LOCAL`/`PREMISE-UNVERIFIED`) is a `revisingOn` tag set; Step 1's "write the null diff **before reading the diff**" is a sequenced bind, enforced by construction rather than by self-discipline | C4 C9 |
| 6 | `denotational-design` | TRANSFORM → `denote` | ten phases each with questions, an artifact and an **exit test** — `ask`/`panelText`/`confirm` + `revisingOn`, ten times, with `ask_` at the human gates. Its 1921 lines of references are **program inputs**, not prompt bulk; its "when NOT to use" admission test is a `confirm` before the body | C4 C12 C9 |
| 7 | `alexey-review` | FOLD-IN → `Rubrics.alexeyGears` | four severity gates → `revisingOn` tags; the explicit Conflict rule ("engineering-principles dictates WHAT, stance dictates HOW") is a **precedence between two rubrics**, which is two defines composed in a fixed order | C4 C8 |
| 8 | `caveman` | FOLD-IN → `Prose.compress` | the purest define in the corpus, and a transform *on other prompts* — so it becomes the first genuinely reusable prompt combinator | C7 C2 |
| 9 | `ponytail` *(external)* | FOLD-IN → `Rubrics.ponytailSlot` | transplant the **edge**, not the text: a define the owner fills, or a `servedBy` pin to a model given the external skill. `ponytail-debt` is a pure decider job (`AnyLineStartsWith ["ponytail:"]`) costing zero questions | C6 C2 |
| 10 | `forge` | TRANSFORM → `forge` | already a workflow written as prose with an explicit phase/model table: consensus rounds are `panel`s, the roster is `servedBy` with alternates, Phase 2's "wait for explicit user approval" is `ask_`, Phase 6's remediation is `revisingOn` back to Phase 3. **Pricing forge is the demo** — six phases × three models is exactly the cost the owner cannot see until the bill arrives | C1 C6 C4 |
| 11 | `anvil` | **KEEP-AS-MD** | an empty `references/` directory: no `SKILL.md`, no registry entry, no inbound reference. Nothing to port. A greenfield slot that has to be *elicited*, and it would be dishonest to invent one | — |
| 12 | `comment-audit` | TRANSFORM → `comments` | the extractor is a textbook receipt party (`inventory`, `pending --limit 15`, `show <id>`, `update --id …`); seven verdicts → `revisingOn`; and its 10–15-per-batch loop is a **context-budget workaround that a priced program replaces with a cost bound** | C3 C4 C1 |
| 13 | `eliminate-dead-code` | TRANSFORM → `dead-code` | four non-interleavable phases = four `W.do` segments; the three-advocate debate is a `panel` of 3 folded to one verdict; `cap=N`/`recent=Nd` are inputs, and `cap` is literally the `atMost` bound; "markers never escape" is `ContainsLine "DCE-BEGIN"` at zero cost | C4 C2 C12 |
| 14 | `toolkit` | FOLD-IN → `Workflows.Tiers` | the corpus's smallest real skill and its clearest rubric; its declared ladder `medium ⊂ heavy ⊂ forge` is the owner's own cost model, currently unpriced | C1 |
| 15 | `it-voice` | FOLD-IN → `Prose.itVoice` | a voice rubric plus a self-check before finishing, which is a `confirm` gate over the draft | C8 C6 |
| 16 | `johnw` | **REWORK** → FOLD-IN → `Prose` | the rework: the largest rubric in the corpus is **two things fused** — a generation rubric and a critique function (the NEVER lists plus the self-review checklist). Splitting them is the level-up; then `johnwVoice` is a define and `Prose.critique` is an `Fn` on a *different* `servedBy` | C6 C7 |
| 17 | `persian` | TRANSFORM → `persian` | five phases, Phase 3 an explicit review **team** = `panel`; `TERMS.csv` authoritative and `PersianTerms.txt` a warned-about lossy extraction — a real input with a real precedence ordering; the `opus`-at-max pin is `servedBy` | C4 C6 C12 |
| 18 | `fix-transcript` | FOLD-IN → `transcript` | its substance is a numbered **rule-priority list**; the two references are lookup corpora → inputs | C8 C12 |
| 19 | `retest` | TRANSFORM → `retest` | seven ordered phases with per-phase skip flags = `if`/`unless` over inputs; its "Claim discipline" rule (report `PASS`/`SKIPPED`/`QUARANTINED`/`DIVERGE`/`NO-COVERAGE` as **distinct states**, never collapsed) is a demand for a sum type, hand-written in prose | C9 C12 C1 |
| 20 | `skill-creator` | **KEEP-AS-MD** | shadowed and dead — `catalog.nix` sources it from the resources flake, and the local copy's `__pycache__` is stale. Do not port. Its successor is `workflows/` itself | — |
| 21 | `swiftui` | **KEEP-AS-MD** | third-party, lightly owned, 11 references that are a domain corpus. Its three-branch Workflow Decision Tree FOLDS IN to `review` as rung `swift` if the owner ever wants it; the rest stays where it is | C12 |
| 22 | `node-red` | TRANSFORM → `nodered` | the most script-heavy skill: four `.py` scripts are four `proc` parties. Its "Supported admin boundary" and "Things to avoid offering" become permission on the **question**. Deeply host-specific — **port last** | C3 C5 |
| 23 | `docstring` | FOLD-IN → `Rubrics.docstringTemplate` | a pure format rubric with a `confirm` tail; used by `review` and `productize` | C8 |
| 24 | `add-uint-support` | **KEEP-AS-MD** | a mechanical seven-step transformation the harness loads *while editing*; pricing it buys little. Note for the record: its Step 1 is a decider and its hand-off to `at-dispatch-v2` is the corpus's **only true skill-calls-skill pair** — the cleanest existing `call_`, available whenever the owner wants it priced | — |
| 25 | `at-dispatch-v2` | **KEEP-AS-MD** | same, as the callee | — |
| 26 | `nixos` | FOLD-IN → `Receipts` | five bullets, three of them hard prohibitions (never decrypt SOPS, never seize the `.nixos-build` lock, `--max-jobs 1 --cores 1` on the VPS). This is permission and safety policy, not a procedure: it rides on the **argv** and on the question's addressee, not in prompt text | C3 C5 |
| — | `prompts/emacs.md` | FOLD-IN → `Rubrics.emacsPersona` | a persona rubric with no control flow. Its persona-stacking is precisely the bulk `caveman` exists to compress — a latent `call_` the corpus never makes and this one can | C8 C7 |
| — | `prompts/spanish.md` | FOLD-IN → `Prose.translate` | `<instructions>`/`<task>` with a literal `$ARGUMENTS` hole: the corpus's clearest existing `{name}` hole, and a one-argument `Fn` | C7 C8 |

### 4.5 Tally

| Verdict | Commands | Agents | Skills+prompts | Total |
|---|---:|---:|---:|---:|
| TRANSFORM | 24 | 1 | 9 | **34** |
| FOLD-IN | 36 | 21 | 15 | **72** |
| REWORK-then-program | 3 | 1 | 1 | **5** |
| KEEP-AS-MD | 4 | 1 | 5 | **10** |

Ten honest KEEP-AS-MD out of 121. That number is the point of the semantics-first
bias: it is small because the corpus is genuinely full of latent structure, and
it is *not zero* because four of the five commands and five of the skills that
stay have no capability to name.

---

## 5. The five flagships

Each sketch is the actual `W.do` skeleton, with the constraints the language
imposes honored rather than wished away. Three constraints recur, and they shape
every design below:

* **A branch is terminal** (`G1`). A conditional stage cannot rejoin, so *n*
  independent routers cost 2ⁿ arms. Deciders are cheap only in small numbers.
  This is why every panel roster below comes from an **input** (WR-2's corollary)
  and only the tier/mode selection is a branch.
* **A `revisingOn` body is exactly one review and one `amend`.** No third
  statement, and the grammar says so. A per-trip gate has nowhere to stand.
* **The tail after a `revisingOn` is replicated 2n+1 times in the plan.** So a
  long tail goes in a `function` and is called once per arm — which costs
  nothing, since a call is priced at the callee's own `bodyAsks`.

### 5.1 `review` — the paneled multi-reviewer

*Absorbs:* `deep-review`, `heavy-review`, `code-review`, `quick-review`,
`sec-audit`, `review-github-pr`, `alexey`, plus the skills
`validated-code-review`, `abstraction-review`, `alexey-review`, `comment-audit`
and `eliminate-dead-code` **as read-only lenses**, plus all eleven reviewer
agents.

*Prompts from:* `agents/*-reviewer.md` (rubric bodies, verbatim where they are
good), the **one** `findingSchema`, `commands/quick-review.md`'s ladder
paragraph (as `Rubrics.rungs`), `commands/markdown.md` (the suggestion format
tail).

```haskell
review :: Parameterized
review = taking (input "rung" (input "langs" (input "scope" noInputs)))
  \rung langs scope ->
    defining [SomeFn reviewReport, SomeFn independence] $ workflow W.do

      -- The no-history sentinel, ONE spelling of a gate that has three today.
      probe <- ask (tool "history-probe" `running` Receipts.historyProbe) [wf|{probeBrief}|]
      clean <- decide LastNonEmptyLineIs probe ["NO-HISTORY"]
      unless clean stop                      -- the terminal the author cannot drop

      -- The frozen snapshot. ONE receipt, bound once, spliced into every member
      -- as the same hole: "every pass examined identical code" becomes a handle.
      frozen <- ask (tool "scope" `running` Receipts.gitDiffFor scope) [wf|{scopeBrief}|]

      -- The tool receipts the rubrics currently only WISH for. One per lens the
      -- roster names; a missing tool is a receipt that says so.
      lint   <- ask (tool "lint" `running` Receipts.lintersFor (parseLangs langs)) [wf|{lintBrief}|]

      -- THE FAN-OUT. The roster is ordinary Haskell over an INPUT, so it is
      -- dynamic and priced: `cost review --input-arg langs=hs,rs` is a number.
      findings <- panelText
        ( Panels.crossCuttingNamed frozen                    -- security, perf: always
       ++ Panels.lensesNamed (parseLangs langs) frozen lint  -- 0..n language lenses
       ++ Panels.rungLensesNamed (Tiers.lookup rung) frozen  -- alexey / abstraction / ponytail / dead-code / comments
        )

      -- The attestation contract, at zero questions. `servedBy` already made the
      -- identity a type; this checks the ONE thing a type cannot: that the
      -- alternate did not answer silently.
      attested <- decide ContainsLine findings ["MODEL: "]
      if attested
        then W.do
          call_ reviewReport (arg findings :> arg frozen :> noArgs)
          stop
        else W.do
          -- The md labels the report incomplete; here that is an ARM.
          call_ reviewReport (arg findings :> arg unattestedNotice :> noArgs)
          stop
```

**What this buys, item by item.** The seven-pass frozen scope becomes a handle
rather than a promise (C3). The nine-row extension→agent table stops being a
paid model turn and becomes a roster the operator names, visible in `plan --raw`
before anything runs (C12, C1). The finding schema is one define holed eleven
times, so the drift that has already happened cannot happen again (C8). The
confidence filter is a decider over the reviewers' own output — **a test the
model being tested cannot choose** (C2). The completeness gate ("confirm all
four required skill passes completed") is a total `case`, an arm nobody can
forget (C9). And the ladder — five rungs maintained by copy-paste in five files
— becomes five `costSummary` numbers the owner compares before picking a rung
(C1).

**What it honestly loses.** `deep-review` runs *one reviewer per detected
language* on a mixed changeset; here the language set is an input, so a
changeset the operator under-declares is under-reviewed. The mitigation is that
the operator can see it: `plan --raw` prints the roster, and `Receipts` can
supply the honest default (`git diff --name-only` piped into the brief) so the
declared set and the actual set are both visible.

### 5.2 `green` — the gated fix loop

*Absorbs:* `fix-ci`, the CI tail of `fix`, `flaky-rust`, `webfix`'s oracle.

*Prompts from:* `commands/fix-ci.md`, `skills/fix-all` (`fixAllRule`, the
standing constraint every fixer ask splices), `agents/*-pro` as the fixer's pin.

```haskell
green :: Parameterized
green = taking (input "pr" (input "checkCmd" noInputs)) \pr checkCmd ->
  defining [SomeFn fixerFn] $ workflow W.do

    outcome <- revisingOn pr (atMost 5) \state -> W.do
      -- The review clause: ONE statement, and it is a RECEIPT, not a claim.
      checks <- ask (tool "checks" `running` Receipts.ghPrChecks pr) [wf|{checksBrief}|]
      amend (ask (model "fixer" `servedBy` "opus" `fallingBackTo` "gpt-5.5-pro") [wf|
          {fixAllRule}
          {codeRule}
          {state}
          {checks}|])

    case outcome of
      -- Green.
      SettledOn state -> W.do
        call_ fixerFn (arg state :> noArgs)     -- the shared tail: report + resolve threads
        stop
      -- Five trips and still red. The md loops forever; this YIELDS the state,
      -- so the operator gets the partial work and the name of the red check.
      UnsettledOn state -> W.do
        ask_ (tool "report" `running` Receipts.writeReport) [wf|
            {stillRedBrief}
            {state}|]
      -- The fixer REFUSED. Not the same as "still failing", and the md has no
      -- word for it: an infra failure, a permission wall, a check nobody owns.
      AbandonedOn state -> W.do
        ask_ (person "owner") [wf|
            {escalateBrief}
            {state}|]
```

**The argument.** `fix-ci`'s "monitor … until everything passes" is unbounded
with no abandon condition, and its second paragraph silently restates the whole
of `bugbot`'s five-phase protocol — which is where drift will happen first. Here
the bound is `atMost 5`, the settle test is a `gh pr checks` receipt read by
`LastNonEmptyLineIs`, and there are **three** endings where the md has one
(C4, C9). The duplicated bot protocol is deleted by `call_ prThreadsFn` (C7).
And the whole thing is priced: a 40-comment PR is a number the operator sees
rather than a surprise (C1).

**`flaky` is the same skeleton with one change**, and it is the change that
matters: the check party is `drawing n`, because *flakiness is by definition not
settled by one run* and the md has no notion of repetition. A decider over the
collected receipts separates *flaky* from *broken* **before any model is
consulted** (C10, C2). That distinction is the entire task.

### 5.3 `commit` — the commit-discipline pipeline

*Absorbs:* `commit`, `push`, `recommit`, `bankruptcy`; called by `fix`, `halt`,
`restack`, `wiggum`.

*Prompts from:* `commands/commit.md` (three decomposition principles, six change
categories with a dependency ordering, the message format, the hunk-granularity
staging strategy, the five-item per-commit checklist, the five-step
disentangling procedure with its "prefer a slightly larger commit over a broken
repository" fallback).

```haskell
commitFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
commitFn = function "git.commit"
  (takes @"scope" Text . takes @"style" Text $ noParams) \scope style -> W.do
    plan <- ask (model "decompose" `servedBy` "opus") [wf|
        {commitPrinciples}
        {categoryOrdering}
        {messageFormat}
        {scope}
        {style}|]
    act (tool "stage" `running` Receipts.gitAddPatch) [wf|{stagingStrategy}\n{plan}|]
    done

commit :: Parameterized
commit = taking (input "mode" (input "scope" noInputs)) \mode scope ->
  defining [SomeFn commitFn] $ workflow W.do

    -- bankruptcy's stated-and-never-checked postcondition, as a handle bound
    -- BEFORE the destructive middle.
    before <- ask (tool "tree" `running` Receipts.gitTreeHash) [wf|{treeBrief}|]

    -- Haskell's own `if`, on an INPUT: four commands, four PROGRAMS, one path
    -- each, each priced exactly. Not a router; not a paid question; no paths.
    if mode == "rebuild" then ... else pure ()          -- (elaborated in the module)

    series <- revisingOn before (atMost 3) \state -> W.do
      -- The five-item checklist's "does the code compile and pass tests at this
      -- point?" — a build receipt, not a question to oneself.
      built <- ask (tool "green" `running` Receipts.makeTest) [wf|{greenBrief}|]
      amend (ask (model "recommit" `servedBy` "opus") [wf|
          {perCommitChecklist}
          {state}
          {built}|])

    case series of
      SettledOn state -> W.do
        after <- ask (tool "tree" `running` Receipts.gitTreeHash) [wf|{treeBrief}|]
        same  <- decide ContainsLine after [/* the recorded hash, spliced */]
        unless same stop                        -- "unchanged working tree", checked
        call_ commitFn (arg state :> arg style :> noArgs)
        stop
      -- The file's OWN fallback — "prefer a slightly larger commit over a broken
      -- repository" — expressed as the language's exhaustion semantics rather
      -- than as advice.
      UnsettledOn state -> W.do
        call_ commitFn (arg state :> arg coarserStyle :> noArgs)
        stop
      AbandonedOn state -> W.do
        ask_ (person "owner") [wf|{cannotDecomposeBrief}\n{state}|]
```

**The argument.** `commit` is the most-referenced node in the A–L half (three
in-edges, zero out-edges) and the corpus's clearest candidate for a shared
function; today `bankruptcy` hedges over whether it is "the `commit` skill or
`$command-commit`", which the type settles (C7). Its per-commit checklist is a
build receipt written as a question to oneself (C3). Its "prefer a slightly
larger commit" fallback is *exactly* `UnsettledOn` — an exhausted revision that
yields its candidate — which is the most satisfying single correspondence in the
whole corpus (C4). And `push` costs `commit` + 2, which is a number where today
it is a sentence (C1).

### 5.4 `audit` — the fess-style audit

*Absorbs:* `agents/fess-auditor.md` (and therefore `commands/fess.md`, which
`catalog.nix` aliases to the same file — one rubric, two projections, which is
one `Program` reachable by two names here). Consumed by `wiggum`, `fix-all`.

*Prompts from:* the ten sin categories with their stated harm, rule, signals and
per-category interrogative; the independence attestation protocol; the fixed
five-section report; and the anti-manufacturing guards, which are the tell that
this file was written by someone who had been burned ("don't resolve uncertainty
by claiming 'none' and don't resolve it by manufacturing a sin").

```haskell
audit :: Parameterized
audit = taking (input "change" (input "attestation" noInputs)) \change attest ->
  defining [SomeFn auditReport] $ workflow W.do

    -- Evidence FIRST, because the file ends by demanding "quote the command and
    -- the relevant output" from an agent with no structural guarantee it ran
    -- anything. Here the world runs the argv and the receipt is not the
    -- answering model's to write.
    tests  <- ask (tool "suite"  `running` Receipts.makeTest)       [wf|{suiteBrief}|]
    diff   <- ask (tool "diff"   `running` Receipts.gitDiffFor change) [wf|{diffBrief}|]
    marks  <- ask (tool "marks"  `running` Receipts.suppressionGrep)[wf|{marksBrief}|]

    -- The ten sins as ten members of ONE document, each fenced under its own
    -- name — so a weak category is VISIBLE, where the md asks all ten in one
    -- turn and one weak answer disappears into the paragraph.
    sins <- panelText (Panels.fessPanelNamed diff tests marks)

    -- The independence protocol. The md's own words: "If that attestation is
    -- absent, run the audit but report that its independence was not verified."
    -- That is a gate whose failure DOWNGRADES rather than aborts — which is a
    -- two-armed case where BOTH arms produce a report, and the compiler makes
    -- the author write the second one.
    verified <- decide LastNonEmptyLineIs attest ["NO-HISTORY"]
    if verified
      then W.do
        call_ auditReport (arg sins :> arg verifiedNotice :> noArgs)
        stop
      else W.do
        call_ auditReport (arg sins :> arg unverifiedNotice :> noArgs)
        stop
```

**The argument.** Three things the auditor cannot do on its own, all three
closed: (a) the independence attestation is prose the parent may simply not
supply — now it is an input read by a decider with two written arms (C2, C9);
(b) the ten categories are asked as one turn, so one weak category is invisible
— now ten fenced blocks, priced at ten (C1); (c) it demands evidence from an
agent with no structural guarantee it ran anything — now three receipts the
world authored (C3). This is the single highest-value conversion in
`agents/`, and it is the one whose *structure* most rewards the language.

### 5.5 `restack` — the evidence pipeline

*Absorbs:* `restack`, `rebase`, `rebase-and-fix`, `cleanup`; calls `resolveFn`,
`commitFn`, `greenFn`, `prThreadsFn`. Named by `wiggum` as the last stage of its
loop.

*Prompts from:* `commands/restack.md`'s nine steps, especially step 4's genuinely
good rule ("when each side added something orthogonal, combine both sides rather
than picking one") and step 9's `git range-diff` evidence requirement.

```haskell
restack :: Parameterized
restack = taking (input "trunk" (input "followUp" noInputs)) \trunk followUp ->
  defining [SomeFn resolveFn, SomeFn commitFn, SomeFn branchFn] $ workflow W.do

    -- STEP 1. The baseline: a receipt bound at depth 0 and LIVE FOR THE WHOLE
    -- RUN. This is the capability the md structurally lacks — "record the
    -- starting state so the report can prove nothing was lost" is, in Markdown,
    -- a request to remember.
    baseline <- ask (tool "tips" `running` Receipts.gtLs) [wf|{baselineBrief}|]

    -- STEP 7 is a FIXPOINT: if main moved, go back to step 2. The outer loop,
    -- decided purely over a receipt.
    settled <- revisingOn baseline (atMost 3) \state -> W.do
      moved <- ask (tool "trunk" `running` Receipts.gitFetch trunk) [wf|{trunkBrief}|]
      -- STEPS 2-6 are the amendment: resolve, verify, restack, per branch.
      amend (ask (model "restack" `servedBy` "opus") [wf|
          {orthogonalCombineRule}
          {state}
          {moved}|])

    case settled of
      SettledOn state -> W.do
        -- STEP 9. The proof, against the handle bound before anything moved.
        proof <- ask (tool "range" `running` Receipts.gitRangeDiff) [wf|
            {rangeDiffBrief}
            {baseline}
            {state}|]
        intact <- decide ContainsLine proof ["="]     -- every pair matched
        unless intact stop                             -- nothing was lost, or we stop
        call_ commitFn (arg state :> arg atomicStyle :> noArgs)
        stop
      UnsettledOn state -> W.do
        ask_ (tool "report" `running` Receipts.writeReport) [wf|{partialBrief}\n{state}|]
      AbandonedOn state -> W.do
        ask_ (person "owner") [wf|{approvedHistoryBrief}\n{state}|]
```

**The argument.** This is the best-engineered command in the corpus and every
piece of its rigour is currently *requested* rather than *held*: record the
baseline (step 1), verify each resolution before proceeding (step 5), reach a
fixpoint (step 7), prove nothing was lost with a mechanical diff (step 9). Here
step 1 is a handle that outlives the destruction, steps 5 and 7 are `revisingOn`
settled by pure deciders over real build receipts at **zero questions per trip**,
and step 9's proof is a receipt compared against that first handle (C3, C2, C4).
It exercises `running`, `decide`, nested loops, `call_` and a live baseline in
one program, which makes it the best demonstration target in the corpus — and it
is the inner engine of `wiggum`, so building it early pays twice.

---

## 6. The invocation story

### 6.1 The verbs

```
workflows list                                  every row: name, blurb, cost min..max over N paths
workflows plan <name> [--raw] [--require-pinned] [<input>...]
workflows cost <name> [<input>...]
workflows run  <name> --engine acp --adapter claude|codex [--scratch DIR] [<input>...]
workflows run  <name> --session <deck-pane-id>
workflows run  <name> --engine acp --adapter stub          the dry run
```

Identical to `agentic-run`'s, because it *is* `agentic-run`'s — `cliMain` is one
function and the registry is its argument. Nothing new to learn, and the one new
verb (`list`) is the catalog the owner will actually live in.

### 6.2 The day, concretely

**Before spending anything.** `workflows cost review --input-arg rung=heavy
--input-arg langs=hs,rs` prints min, max and the number of paths. That is the
number no file in the corpus can produce: `deep-review` today cannot say what a
mixed-language review will cost, and `heavy-review` cannot say what seven passes
over a nine-language repository will cost. `workflows list` prints all of them
at once, which turns the five-rung review ladder — currently a paragraph
copy-pasted into five files — into five numbers side by side. That is the moment
the ladder stops being advice and starts being a decision.

**Reading the plan.** `workflows plan review --raw` prints the whole program:
every rendered prompt, every roster, every `servedBy`, every argv. Two things
the owner will use it for immediately: seeing *which* reviewers a language set
selects before paying for them, and seeing the exact command line a `running`
party will hand to `proc` — which is where a bad glob or a wrong flag is cheap
to find.

**Running.** `--engine acp --adapter claude` (or `codex`) is the daily driver: a
fresh scratch directory per run, one adapter this process owns, permission
decided by the answer code so a reviewer that never `act`s cannot write.
`--session <pane>` puts every question to a live agent-deck pane, which is the
right transport when the owner wants to watch and interject. `--adapter stub` is
the dry run that proves the shape without spending a token.

**Inputs, per WR-3.** What the owner chooses is a flag; what the world knows is
a receipt. In practice that means the flags are small and few — a rung, a
language list, a PR number, a mode, a scope path — and the diff, the branch, the
check status and the file list come from `Receipts`. Two ergonomic
consequences worth stating: `--input-arg` is almost always enough (no shell
plumbing), and a program that takes a document takes it as `--input FILE`
(`notes`, `transcript`, `persian`, `denote`'s reference corpora).

**The guard the owner should always pass.** `--require-pinned` is checked before
a plan is printed, an adapter is started, or anything is spent. `ci/workflows.sh`
enforces it on every row, so it should never fire in practice — which is exactly
what makes it worth having on the command line too, for the day the owner is
editing a program and forgets a pin.

### 6.3 What the owner stops doing

Three things, and each is a real recovered hour:

* **Guessing at a context budget.** Four skills hand-roll one — a
  10–15-per-batch loop, a post-compaction re-read, "do not write temp files
  unless context demands it", a fan-out cap of 3–5. All four are guessing at a
  number `costSummary` computes.
* **Hand-rolling model identity.** Three skills do it — one Python script, one
  `listmodels` preflight, one pin buried in prose. `servedBy` with
  `fallingBackTo` is a property of the question, checked before the run.
* **Maintaining copies.** The finding schema (eleven), the ladder paragraph
  (five), the sentinel probe (three spellings), the generic web-search/
  sequential-thinking bullet pair (six files), `bugbot`'s protocol (restated in
  two commands that do not name it). Each becomes one binding, and the two
  places drift has *already* happened — `deep-review`'s Category vocabulary and
  `partner-reviewer`'s Category enum — become unrepresentable.

---

## 7. The roadmap, in build order

Batches are sequential; within a batch, rows are independent.

**Batch 0 — the foundation and the gate.** `Agentic.Cli` extraction with the
byte-identical-`ci/examples.sh` acceptance test; `Registry`/`Entry`; the
`workflows` library and executable; `ci/workflows.sh`; the seven foundation
modules with the rubrics transplanted and their sources cited in haddock.
*Done when:* `workflows list` prints an empty catalog, `ci/examples.sh` output
is byte-identical to before, and `ci/workflows.sh` passes vacuously.
*Risk:* the extraction is ~900 lines moved. It is mechanical, and the gate is
the test.

**Batch 1 — the five flagships.** `review`, `green`, `commit`, `audit`,
`restack`, plus `Workflows.Commit`'s `resolveFn` (which `restack` needs and
which is the corpus's clearest existing function). *Done when:* each has a
`ci/workflows.sh` row with a level, a path count and a ceiling, and
`workflows list` prices the review ladder in one screen.

**Batch 2 — the daily drivers.** `pr-threads` (bugbot/assess/respond),
`pr-stack`, `issue` (fix/fix-github-issue), `checklist`, `qanda`, `account`
(report/sitrep/narrative/halt). These are the highest-frequency rows and they
mostly `call_` batch 1.

**Batch 3 — the audits and the panels.** `dead-code`, `comments`, `teams`,
`partner`, `bundles`, `forge`. `teams` first — it is the cheapest high-value
transform in the corpus and the most literal `panel` in it.

**Batch 4 — the producers.** `org-tasks` (infer-tasks + breakdown),
`notes`, `claude-md` (initialize + prepare-with), `polish` (smooth + proofread),
`transcript`, `transcribe`, `persian`, `denote`. All document-shaped, all
isolated, all easy to test against real inputs.

**Batch 5 — the hosts and the heavy.** `nixfix` (nix-rebuild + fix-alert +
fix-integration), `service` (install + remove), `productize`, `flaky`, `query`,
`expenses`, `webfix`, `prd-draft`, `prd-critique`, `retest`, `tron`, `nodered`.
`retest` is high-value (its phases cost hours, so pricing before running is
worth more here than anywhere) and high-effort; `nodered` is last within the
batch because it is the most host-specific thing in the corpus.

**Batch 6 — `wiggum`.** The corpus's own top-level loop, calling five programs
from earlier batches. It goes last because it wants everything else to exist,
and because `atMost` on an autonomous loop is a decision the owner should make
with the prices of its five stages already in front of him.

### Three things to decide before batch 1, not during it

1. **The Category vocabulary.** `deep-review`'s consumer adds `Simplification`
   and `Dead Code`; no agent file carries them. Two objects, one of them in
   `agents/`. `Workflows.Rubrics` must pick one, and the pick should be the
   owner's.
2. **The confidence floor.** Every finding carries a self-reported
   `Confidence: 0-100` and `deep-review` filters on it; a reviewer that wants a
   finding kept writes 95. Either the floor becomes a decider over a *different*
   party's judgment, or it should be dropped as theatre. This proposal assumes
   the first; it is a design decision, not a transcription.
3. **What `anvil` means.** It is an empty directory with no `SKILL.md`, no
   registry entry and no inbound reference. Nothing can be transplanted; it has
   to be elicited. Until then the slot stays empty, and inventing one would be
   the exact species of manufacture `fess-auditor` exists to catch.
