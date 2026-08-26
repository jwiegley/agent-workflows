# `wf wiggum --help`: a help text per row

*A design for `rowHelp` — a mandatory field on `Agentic.Cli.Row`, a fifth verb
that spends nothing, a template derived from the verified cookbook, and the
generation rule that keeps the two from ever saying different things.*

---

## 0. The ruling

The owner's ruling, 2026-08-22, verbatim:

> For every workflow, I want you to allow to define a Haskell function that
> provides specific help on how to make use of that workflow, so that if I run
> `wf wiggum --help`, it will show me which arguments and patterns would be
> useful for actually using wiggum.

Four things follow. The field is **mandatory**, because "for every workflow".
The dispatch must accept the spelling he typed, which is not a verb. The
content is **already written and already verified** — it is `doc/cookbook.md`,
whose every rehearsal command was executed and every price read from
`list --json` — so this is very largely a question of *where the bytes live*,
not of what to say. And the moment they live in two places they will drift,
which is §4 and the only decision here worth arguing about.

Nothing below moves a pinned number. `ci/examples.sh` pins seven programs by
equality and `ci/workflows.sh` pins level, paths and a ceiling for seventy-two;
a help text is prose *about* a program, no fold reads it, and if any pin moves
the help text has become part of a program and the work stops.

---

## 1. The field

```haskell
data Row = Row
  { rowExample :: !Example,
    -- | one line, for @list@ and for the usage message
    rowDoc :: !Text,
    -- | the page @help@ prints: what this row is for, what its inputs mean,
    -- which transport it wants, one worked line, one rehearsal, its caveats
    rowHelp :: !Text,
    -- | the canned replies @--scripted@ answers from, keyed by prefix
    rowScript :: ![(Text, Text)]
  }
```

`Text` and not `Maybe Text`. A registered row without help is a row nobody can
use, and a `Maybe` would oblige the CLI to have an arm that prints *there is no
help for this row* — a sentence whose reader can do nothing about it, printed by
a binary that could have refused to build instead.

Third position, between the blurb and the script: the two prose fields sit
together, one line then the page, and the script — which is the row's answering
table and not its documentation — stays last where its haddock's argument for it
("the canned table travels beside the program") still reads.

**A registry literal that omits it fails to compile, and by arity rather than by
type.** Every construction site in both trees is positional (`Row ex doc
script`), inside a list of `(Text, Row)`; a three-argument application of a
four-field constructor is a `Text -> Row` where a `Row` is wanted, which is a
type error at every site, not a warning. There is no smart constructor and no
runtime validation: the registry is a *value* and the CLI a function of it, and
a `mkRegistry :: … -> Either Text Registry` would buy a binary that can fail to
start in exchange for a check two lines of `bash` make at CI time (§2, the
collision).

Rejected alternative: a `helpFor :: Text -> Text` dispatch inside each registry,
beside `blurbFor`. That is the `scriptFor` shape `Row`'s own haddock argues
against — "the row is the unit, so a program cannot be registered without them"
— and its failure mode is a pattern-match error at run time for a row somebody
added and did not document. The field makes that a build failure.

### The migration cost, both trees

**agent-cat** — one construction site.
`haskell/example/Example/Harden.hs:283` is a comprehension over `examples`, so
the edit is one token (`Row ex (blurbFor n) (helpFor n) (scriptFor n)`) plus a
`helpFor` beside `blurbFor` and an `isaacHelp` beside `isaacBlurb`
(`example/Example/Isaac.hs:1667`). Seven texts: `harden`, `hello`,
`plan-feature`, `review-lite`, `ship-feature-lite`, `grind-tests`, `stack-prs`.
Both dispatches are keyed by `Text` and therefore not exhaustiveness-checked, so
the gate runs `agentic-run help` for all seven — a missing case is a runtime
error and must be caught by something.

**agent-workflows** — thirty-seven construction sites and seventy-two texts.
`src/Workflows/Registry.hs` has seventeen direct literals and nineteen
per-family helpers (`reviewRow`, `greenRow`, …), each a one-token edit; the
texts live beside the programs in the ~36 `Workflows.*` modules that already
export a `…Doc`, as `…Help :: Text` or `…Help :: Rung -> Text` mirroring the
`…Doc` next to it, one more name per export list.

**The cross-tree window is real and is the reason phases 1 and 2 are one work
unit.** `cabal.project` builds `../agent-cat/haskell` from the sibling *working
tree*, so the instant `Row` gains a field, `cabal build` in agent-workflows —
and therefore `ci/workflows.sh` — is red until all seventy-two texts exist. The
flake pins a *revision*, so `nix build` (the authoritative one) stays green
throughout, provided the flake input is not bumped until both trees are green.
That is the ordering constraint, not a preference.

---

## 2. The dispatch

Two new constructors, `Usage` and `Help !Text`, and five new arms. **The four
existing verbs are untouched**: every new arm is placed so that a verb in head
position is decided before a row name is ever looked up.

```haskell
parseCommand reg = \case
  [] -> Left (usage reg)                         -- unchanged: exit 1, stderr
  ["--help"] -> Right Usage                      -- new: exit 0, stdout
  ["help"] -> Right Usage                        -- new
  ["help", name] -> Right (Help name)            -- new
  ("help" : _) -> Left ("help takes one " <> noun <> …)   -- new
  ["list"] -> Right (List Human)                 -- unchanged
  ["list", "--json"] -> Right (List Json)        -- unchanged
  ("list" : _) -> Left …                         -- unchanged
  [verb] | verb `elem` verbs -> Left …           -- unchanged (verbs stays 3)
  ("plan" : name : rest) -> planOpts …           -- unchanged
  ("cost" : name : rest) -> costOpts …           -- unchanged
  ("run"  : name : rest) -> …                    -- unchanged
  [name, "--help"] -> Right (Help name)          -- new: the owner's spelling
  [name] | isJust (regLookup reg name) -> Left (bareRow reg name)   -- new
  (verb : _) -> Left ("no verb '" <> verb <> "'" …)      -- unchanged
```

**`wf NAME --help`** — the ruling's own spelling, and unconditional in `name`:
`wf wigum --help` reaches `Help "wigum"` and gets the row list, which is more
use than *no verb 'wigum'*.

**`wf help NAME` — supported too.** Verb-first is the spelling every other verb
in this CLI uses, and `NAME --help` is the spelling a hand types out of habit.
Both build the same `Help name`, so there is one renderer and one thing to keep
true; refusing either would make the binary's answer depend on which habit the
operator has. The gate asserts the two outputs are byte-identical.

**`wf NAME` with no flag — refused, exit 1.** Not "print the help", and not
"run it":

```
wf: 'wiggum' is a workflow and not a verb; try wf help wiggum, wf plan wiggum,
    wf cost wiggum, or wf run wiggum --scripted
```

A bare name is ambiguous between *tell me about it* and *do it*, and guessing is
the one thing this CLI must not do with a line that could start spending. It
costs the operator one command line and teaches the verbs. Exit 1 is the usage
code: nothing ran.

**A NAME that collides with a verb — forbidden by gate, unreachable by
construction.** Two layers, neither of them a type. (i) The parse order above
makes a verb win, always: a row named `plan` is simply unreachable by name
rather than ambiguous, and unreachable-but-registered is exactly what a gate
should shout about. (ii) Both gates check `wf list`'s names against the reserved
set `{list, plan, cost, run, help}` — six lines of `bash`, run against the real
registry rather than against a literal transcribed from it. Nothing collides
today in either tree. A third layer is available and recommended once
`parseCommand` is exported for it: one `test/PolicyProbe.hs` case over a
*synthetic* registry containing rows named `plan` and `help`, asserting the verb
still wins — the policy, as against the fact about today's two tables.

**An unknown NAME — the existing refusal, verbatim.** `no workflow named 'x';
there is A and B and …`. It is built inside `withExample` today, which also
resolves inputs and builds a program; `help` does neither, so the sentence is
factored into `noSuchRow :: Registry -> Text -> Text` and both call it. The
bytes do not move — `ci/workflows.sh` greps `no workflow named` and stays green
— only the place they are assembled.

**`wf --help` bare — the usage text, on stdout, exit 0.** Today it is
`no verb '--help'` on stderr with the usage appended, exit 1. Bare `wf` stays
exactly as it is (stderr, exit 1), and the asymmetry is the point: `wf` alone is
a command line that asked for nothing, `wf --help` is a request that was
answered. The usage text grows two lines, in agent-cat, where both binaries read
them:

```
  wf help <workflow>
  wf <workflow> --help
```

**Deliberately unchanged.** `wf list --help` still says *list takes nothing but
--json*; `wf plan --help` still says *no workflow named '--help'* and lists the
rows. Both are verb arms, both already answer usefully, and touching either
touches a verb.

**`help` takes the name and nothing else** — no input flags. The numbers in its
header are the row at every input empty, which is the price `wf list --json`
publishes; a header that moved with a flag would be teaching by a number the
reader did not ask for. `dead-code`'s `cap` is named in its own caveats and
points at `wf cost`, the verb whose whole job is that question.

`help` is a **static verb**: it builds the program at empty inputs
(`listFacts`), asks nobody, starts no adapter, spends nothing. Exit 0, output on
stdout.

---

## 3. The shape of a help text

### What the CLI computes, and what the author writes

The single most important rule here: **a help text contains no price.**
Seventy-two hand-copied numbers is drift with a schedule. The CLI prints a
computed header from the same `Facts` `plan`, `cost` and `list --json` read, so
the number in `wf help wiggum` and the number in `ci/workflows.sh`'s pin cannot
disagree; the author writes only what cannot be computed.

`wf help wiggum` prints, in order:

1. `name — blurb` (`rowDoc`).
2. The computed block, in `plan`'s own labels and `renderSummary`'s own words:
   `level`, `cost`, `inputs`, `runFacts`, `pins`. Every label always printed,
   an empty list as `—`: that this row pins no model is a fact worth seeing,
   because it tells you `--route` will refuse everything.
3. `rowHelp`, **verbatim**.
4. A fixed footer, one string in the CLI and never seventy-two copies.

### The template

Authored flat (the fence strips the common margin anyway) and in CommonMark,
because one of its two consumers is a Markdown page and the other is a terminal
that will not mind. That is also what makes §4's generation a splice rather than
a translation — and it is what lets the verified cookbook bytes *move* instead of
being rewritten.

````haskell
-- | What @wf help <name>@ prints below the computed header.
nameHelp :: Text
nameHelp =
  [wft|
    <One or two sentences: which corpus file this row carries, and the shape it
    became. No price, no path count — the header above has them.>

    **Inputs.**

    * `first` — what the value MEANS, whether it reaches the program as argv or
      as data, and what an empty one means in Haskell.
    * `second` — …

    **Transport.** <This row's own advice: a watched pane, or an adapter of the
    run's own, or "fine anywhere" — and any way the transport changes what the
    answer MEANS rather than only where it goes.>

    ```sh
    wf run <name> --engine acp --adapter claude --require-pinned --scratch "$PWD" \
       --input-arg first=… --input-file second=…
    ```

    **Rehearsal.** <one line>

    ```sh
    wf run <name> --scripted --input-arg first= --input-arg second=
    ```

    **Caveats.**

    * <a price-moving input, a gate that refuses, an ending worth knowing>
  |]
````

Three authoring traps, all the fence's: a literal `{` is `{{` (so `${PWD}` is
`${{PWD}}` — write `"$PWD"` and the question does not arise); a text containing
`|]` cannot ride the fence; and whitespace at the very edge is stripped, so a
help text neither begins nor ends with a blank line.

Six sections, each of which the cookbook proved earns its place, and each of
which a gate can check for (§6): the opening sentences, `**Inputs.**` (with the
literal `none.` for a row that takes none), `**Transport.**`, the live block,
`**Rehearsal.**` with its block, and `**Caveats.**`.

### Where the cross-cutting facts live — once each

| fact | where | why |
| --- | --- | --- |
| the four run facts are not yours to give | bare usage — **already there, verbatim** | a fact about the flags |
| `--scratch` is where the adapter starts and the only place an act may write | bare usage's `--scratch` entry — **already there**, plus one added sentence of advice (`--scratch "$PWD"` whenever the run should touch your tree) | a fact about the flag |
| a tilde after `NAME=` is not expanded by the shell — write `"$HOME/…"` | bare usage's `--input-arg` entry, one added line | a fact about the flag; it is why the cookbook's `comments` line spells `$HOME` |
| what the three transports are | bare usage — **already there** — and the cookbook's grammar paragraph | |
| *which rows* want a watched pane, or `--scratch`, or refuse a shared session | each row's `**Transport.**` section, and the cookbook's transport table | a fact about the row |
| the numbers above are the empty invocation's | the CLI footer, one string | true of all seventy-two |
| every price | computed, never authored | |

Two usage-text edits in agent-cat, affecting both binaries, moving no pin: the
`help` lines, the `--scratch` sentence, the tilde line.

### The footer, in full

```
  wf --help lists the flags every row shares. The numbers above are this row at
  every input empty — the price wf list publishes; an input that shapes a roster
  or bounds a loop prices differently, and wf cost <name> [<input>...] is the
  verb that answers that. wf plan <name> --raw prints the program these numbers
  are the numbers of.
```

---

## 4. The cookbook relationship

**Recommendation: (a), with the carve-out that makes it honest.** The help texts
are the source; the cookbook's *per-row* sections are generated from them; a
gate asserts regeneration is a no-op. The cookbook keeps, as authored prose,
exactly what no row owns.

**Why not (b), two authored copies with a diff gate.** A gate that diffs two
proses can only be satisfied by making them identical, which is (a) performed by
hand, forever, by whoever is least interested in doing it. It converts drift
into a red gate, which is better than nothing, and then converts every honest
edit into two — and a gate that goes red for an honest edit is a gate somebody
turns off.

**Why not (c), the cookbook keeps the per-row material and points at `--help`.**
It leaves the verified content where the terminal cannot reach it, which is the
one thing the ruling forbids: `wf wiggum --help` must *show* which arguments and
patterns are useful.

**What generation cannot cover, and what therefore stays authored.** The
cookbook holds four kinds of material no row owns, and they are among its best
paragraphs: the grammar-in-one-paragraph opener; the per-family prose ("the
rungs differ in what they ask of the decomposition", the shared-inputs
paragraphs); the transport table, which is a statement about the whole table;
and "Building and installing it". So the page becomes: authored prose, with
marked regions the generator owns.

```markdown
### `wiggum`
<!-- wf:begin wiggum -->
…generated: the price line, then wf help wiggum's body…
<!-- wf:end wiggum -->
```

**The generator** (`tools/cookbook-gen.sh`, ~70 lines): read the names from
`wf list` in listing order; for each, replace the region between its markers
with a price line rendered from `wf list --json` in the cookbook's existing
`level · min to max over N paths` form, then `wf help NAME`'s body. Two
renderings of one number, both computed, neither authored — the `Facts` pattern
this CLI already rests on.

**The gate** (`ci/cookbook.sh`): regenerate into a temp copy and `diff -u`; red
on any difference. Plus the registered-versus-present check `ci/workflows.sh`
already models — every registered row has exactly one marked region, every
marked region names a registered row.

**What it costs.**

* One generator and one gate, and a `nix develop` that already has everything
  they need (no `jq`: `ci/workflows.sh` reads `pins` out of `list --json` with
  `tr`/`sed` today).
* A one-time move of ~1,000 lines of *verified* prose into thirty-six modules.
  The risk is losing a byte of a command line that was actually executed, and
  the mitigation is the acceptance test: **the first regeneration must diff
  clean against today's cookbook**, modulo the heading and price lines. That
  makes phase 3 the proof that phase 2 was a move and not a rewrite.
* One habit: a rubric edited in `Workflows.EliminateDeadCode` is documented in
  `Workflows.EliminateDeadCode`, and the cookbook follows by regeneration. An author who
  edits the generated region directly is caught by the gate on the next run.

**What it buys beyond one source.** The cookbook's seventy-two hand-copied price
lines stop being hand-copied. That is a second class of drift — one that a
re-pinned ceiling in `ci/workflows.sh` silently creates today — eliminated by
the same move.

---

## 5. The JSON contract

**No.** `help` joins neither `list --json` nor `plan --json`, and there is no
`help --json`.

`list --json` is a *chooser's* table: `emacs/wf.el` reads it on every completion
refresh and shows one line per row. Adding seventy-two multi-paragraph texts to
it makes every reader parse the whole toolbox's prose to choose one row, in
exchange for nothing the annotation can display.

`plan --json` is per-program detail, and a `help` key there would be a second
spelling of bytes that already have a door — the same argument this module makes
about refusals ("a second, machine-readable spelling of every refusal is a second
thing to keep true"). Prose is explicitly not a contract in this CLI; a text has
no structure to lose, so **the machine-readable form of the help text is the
help text**. The contract `help` offers a program is the one it already has to
honour: exit 0, the whole text on stdout, nothing else on stdout, and the
refusal on stderr under exit 1 like every other refusal.

The one condition under which to reopen this: a consumer that must render all
seventy-two without seventy-two processes. Today there is exactly one such
consumer, it is the cookbook generator, and a `bash` loop over `wf list` is what
it wants anyway.

**The requirement on `wf.el`** (one sentence, not an implementation): keep
`blurb` in the completion annotation, and add a `wf-help` command that shows
`wf help NAME`'s stdout in a buffer the way `wf-plan` and `wf-cost` already show
theirs (`wf--show` over `wf--call`, `emacs/wf.el:862-874`) — displaying the text,
never parsing it.

---

## 6. Build order, and the gate each phase owes

**Phase 1 — agent-cat: the field, the dispatch, the renderer, the usage, seven
texts.** `Row` gains `rowHelp`; `Command` gains `Usage` and `Help`;
`parseCommand` gains five arms; `noSuchRow` is factored; `helpCmd` renders
header + text + footer off `listFacts`; the usage text gains the `help` lines,
the `--scratch` sentence and the tilde line; `Example.Harden` and
`Example.Isaac` gain `helpFor`/`isaacHelp`.

Gates owed:
* `cabal build` warning-free (one build at a time per tree).
* `ci/examples.sh` green with **every equality pin unmoved** — the evidence that
  help is prose about a program and not part of one.
* `ci/acp.sh`, `ci/deck.sh`, `ci/policies.sh`, `tier0`, `tier1` green: the three
  live verbs byte-unchanged. No Lean, no `lake`, no corpus.
* New block in `ci/examples.sh`: all seven rows `help` exit 0 and non-empty;
  `help NAME` and `NAME --help` byte-identical; an unknown name exits 1 with the
  existing wording; `--help` exits 0 **on stdout**; a bare registered name exits
  1 naming the verbs; no registered name is in `{list, plan, cost, run, help}`.
* Optional, recommended: the `PolicyProbe` verb-precedence case over a synthetic
  colliding registry (needs `parseCommand` exported).

**Phase 2 — agent-workflows: seventy-two texts, thirty-seven sites.** Same work
unit as phase 1 (§1: `ci/workflows.sh` cannot run between them), authored family
by family in `wf list` order, with the cookbook as the source of the bytes. Do
not bump the flake input until this is green.

Gates owed:
* `ci/workflows.sh` green with **all seventy-two × three pins unmoved**. If any
  pin wants to move: stop.
* New per-row block, for each of the seventy-two: `help` exits 0; non-empty;
  contains `**Inputs.**`, `**Transport.**`, `**Rehearsal.**`, `**Caveats.**`;
  names every declared operator input as `` `name` `` and names no
  `--input-arg X=` / `--input-file X=` whose `X` is not declared (this is the
  check that catches a renamed input against a stale help); contains at least
  two fenced blocks, the first beginning `wf run NAME ` and not containing
  `--scripted`, the last beginning `wf run NAME --scripted`; and contains no
  `minFold`, no `maxFold` and no ` over N path` — the help must not restate a
  price.
* The reserved-name check.
* **The rehearsal in the help is the rehearsal the gate runs** — extract the
  last fenced block, refuse it unless it begins exactly `wf run NAME
  --scripted` (this guard is not optional: a live line pasted into a rehearsal
  block would otherwise spawn a real adapter, which the house rules forbid), then
  run it and require exit 0 and that its input names equal `list --json`'s
  `inputs`. `inputsFor` stays the authority for the *priced* runs. May be
  deferred to phase 4 if it doubles the gate's wall time, and nothing else may.

**Phase 3 — the cookbook becomes generated.** Markers, `tools/cookbook-gen.sh`,
`ci/cookbook.sh`.

Gates owed:
* The first regeneration diffs clean against today's cookbook modulo headings
  and price lines — the acceptance test that phase 2 moved bytes rather than
  rewriting them.
* Thereafter: regeneration is a no-op (`diff` empty); every registered row has
  exactly one region; every region names a registered row.
* `ci/workflows.sh` unchanged and green.

**Phase 4 — `wf.el` and the surrounding prose.** `wf-help` bound and shown;
`README.md` and `AGENTS.md` gain the verb; `doc/cookbook.md`'s opener points at
`wf help NAME` for the per-row detail it now generates.

Gates owed: `emacs/wf-smoke.el` gains a case; `ci/workflows.sh`'s closing note
mentions help; the deferred rehearsal-execution check lands here if it was
deferred.

---

## 7. The exemplar: `wiggum`

What `wf help wiggum` prints. Everything above the first blank line after `pins`
is computed by the CLI from `Facts`; everything from *`wiggum/SKILL.md` as a
program* to the last caveat is `wiggumHelp` verbatim; the last paragraph is the
CLI's footer.

````
wiggum — wiggum/SKILL.md: two work rounds, one checkpoint audit, and a bounded done-criteria verdict

  level     branch
  cost      minFold 2, maxFold 44, over 34 paths
  inputs    plan, base, observations, parity
  runFacts  run.backends, run.engine, run.routes, run.sentinel
  pins      fable, gemini-3.1-pro-preview, gpt-5.5-pro, opus

`wiggum/SKILL.md` as a program: two work rounds with a checkpoint audit between
them, and a bounded verdict against done-criteria the run froze before it
started. Five of its seven callees belong to other rows, so what it costs is
largely what the toolbox under it costs.

**Inputs.**

* `plan` — the frozen plan and its done-criteria. It is a define, so it reaches
  every prompt as data and no turn can rewrite it; `--input-file
  plan=doc/PLAN.md` is the natural spelling. An empty one is the sentence a run
  with no frozen criteria earns, and `wf plan wiggum --raw` prints it.
* `base` — what the branch is measured against and brought up to date with. It
  is the argv of the git commands, not a phrase a model interprets. Empty is
  `main`.
* `observations` — the partner directory the cleanup round drains. Empty is
  `doc/observations`.
* `parity` — the reference target the last done-criterion is about. An absent
  one is a *different* last conjunct rather than a missing one.

**Transport.** Unattended, with somewhere to write: an adapter of the run's own,
and `--scratch "$PWD"`, because every round edits your tree and the scratch
directory is the only place an acting turn may write.

**It refuses every `--session` run, flat.** Its judge and its workers are one
serving model and no route table can separate them, so one shared pane means the
party that would have judged the work is the party that did it. Two panes is
`wiggum-duet`, which is a different row because it is a different shape.

```sh
wf run wiggum --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file plan=doc/PLAN.md --input-arg base=main \
   --input-arg observations= --input-arg parity=
```

**Rehearsal.** Every input named empty, answered from the row's own table,
consulting nobody:

```sh
wf run wiggum --scripted --input-arg plan= --input-arg base= \
   --input-arg observations= --input-arg parity=
```

**Caveats.**

* The `minFold` above is worth as much as the ceiling. The two cheapest endings
  in that range change your tree not at all: a sentinel probe that says this
  runner cannot be held to a parent history, and a baseline that was already
  red. Both report and stop.
* The `--session` refusal is not in that range at all. It is taken in ordinary
  Haskell over `run.engine` before the program exists, and only `run` binds a
  run fact — so `plan`, `cost` and `--scripted` all price the **loop**, which is
  the shape a run with an unknown table keeps every check for. The refusing arm
  is a different and much smaller program, reachable from a command line and
  from nowhere else.
* Two rounds is a design decision and not a setting: a third would move the path
  count, and `ci/workflows.sh` pins it.

  wf --help lists the flags every row shares. The numbers above are this row at
  every input empty — the price wf list publishes; an input that shapes a roster
  or bounds a loop prices differently, and wf cost <name> [<input>...] is the
  verb that answers that. wf plan <name> --raw prints the program these numbers
  are the numbers of.
````

Every fact in it is checkable against something that already exists: the blurb
is `Workflows.Wiggum.wiggumDoc:1629`; the level, ceiling and path count are
`ci/workflows.sh`'s pin for `wiggum`; the four inputs are its `inputsFor` entry;
the four run facts are `Workflows/Wiggum.hs:1448-1451`; the four pins are the
gate's `wiggumPins`, which it already holds against the program's own
`pinnedModels`; and both command lines are `doc/cookbook.md:402-406` and
`428-430`, which were executed.

---

## 8. The stop conditions

* Any pinned number moves in `ci/examples.sh` or `ci/workflows.sh`. Help is
  prose about a program; if a pin moves, it has become part of one.
* Any of the four verbs changes a byte of output. `list`, `plan`, `cost` and
  `run` are what three shell gates and `wf.el` read.
* `no workflow named` stops being the wording. `ci/workflows.sh:925` greps it as
  the evidence that two registries share one CLI.
* A help text that cannot be authored without a price in it. That is a row whose
  price is a fact about its use, and the right answer is a caveat pointing at
  `wf cost`, not a number nobody regenerates.
