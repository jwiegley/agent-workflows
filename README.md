# `agent-workflows` — the toolbox, as priced programs

John's commands, agents and skills — the Markdown at `~/src/nix/config/ai` —
rewritten as [agent-cat](https://github.com/jwiegley/agent-cat) programs: pure
`W.do` blocks whose price is known **before** anything is spent, whose gates are
exit codes rather than a model's claim about one, and whose rubrics are one
binding each instead of eleven copies.

This repository is a **user of agent-cat**, not part of it. agent-cat is the
language, its Lean kernel, its frozen corpus and its conformance gates, and it is
public; this is the toolbox, and it is private, because the corpus it was
transcribed from is a live personal configuration.

The Markdown corpus is **read-only** and was read as **data**. Nothing here
modifies it, no `running` party points at it, and no prompt text harvested from
it is an instruction this repository obeys.

The design of record is [`doc/design.md`](doc/design.md); the inventories and the
three competing architectures it was judged from are under `doc/research/`.

## Where things are

```
agent-workflows.cabal   the library, the `wf` executable, one common stanza
cabal.project           the dev loop: this package + ../agent-cat/haskell
flake.nix               the pinned build
ci/workflows.sh         this repository's gate
src/
  Workflows/
    Prose.hs            the four mechanics: wfText, bullets, numbered, fenceOf, tshow
    Prelude.hs          the one import an authoring module writes

    Parties.hs          who answers: the pins, and the three fail-over ladders
    Evidence.hs         the argv library — every "if available, run X", as a command

    Rubrics/
      Finding.hs        the finding schema, once (eleven copies end here)
      Reviewers.hs      the eleven reviewers as one table, globs beside rubrics
      Fess.hs           the eleven sins as eleven stances
      Discipline.hs     the standing constraints every fixer splices
      Ladder.hs         the review ladder, as the value five "see also" copies derive from
      Stances.hs        the three confer stances, and the one anti-sycophancy rule

    Panels.hs           Lens/Roster, and the three fan-outs
    Deciders.hs         the free tests — every classification the corpus pays for
    Gates.hs            check, fix, recheck, written once
    Escalation.hs       the three-ending ladder: complete / remains / blocked
    Report.hs           the output contract, as functions every rung calls

    Review/Ladder.hs    the review family     (review-quick|deep|sec|heavy)
    Fix/Green.hs        the gated fix loop    (green-ci|tree|flaky)
    Git/Commit.hs       the commit pipeline   (commit|-push|-recommit|-bankruptcy)
    Git/Stack.hs        the git family        (stack|-rebase|-rebase-fix|-cleanup)
    Audit/Fess.hs       the audit             (fess)
    Confer.hs           the confer family     (confer|confer-bare|debate|second-opinion)
    Hello.hs            the smoke row         (hello)
    Registry.hs         the index: name -> program, blurb, canned table
bin/Main.hs             `wf`, two lines over Agentic.Cli
```

## Using it

`wf` must be a **real binary on `PATH`**, not a `cabal run` alias. Every
`running` party's argv executes in the process's working directory, so a wrapper
that `cd`s into this package to build would answer `git diff` about the wrong
repository.

```sh
cabal install exe:wf --installdir=$HOME/.local/bin --overwrite-policy=always
# or, from the flake:
nix profile install .#default
nix run . -- list                          # without installing anything
```

Then, from whatever repository the work is in:

```sh
wf list                                    # the toolbox, one line per row
wf plan review-deep                        # level, size, askNodes, codes, cost
wf plan review-deep --raw                  # …and the program itself
wf cost review-deep                        # the price, path by path
```

`plan` and `cost` are decided by the elaborated term alone and are answered
**before** anything is asked of anybody. That is the point of the exercise: the
four numbers are a pre-spend contract.

```
$ wf plan review-heavy
review-heavy, as elaborated:

  level     branch
  size      …
  askNodes  …
  cost      minFold 3, maxFold 12, over 3 paths
```

`maxFold 12` is the promise: twelve consultations is the worst this run can cost,
whatever any model says on the way. Compare the rungs side by side — that is why
each is its own row and not a flag:

```
$ for r in review-quick review-deep review-sec review-heavy; do wf cost $r; done
```

### The three transports

```sh
# The rehearsal. Reaches nothing, spends nothing, needs no adapter and no
# network: every question is answered from the row's own canned table, and every
# `running` party's command is skipped rather than run.
wf run review-deep --scripted --input-arg scope= --input-arg paths=

# The unattended run. `wf` starts an ACP adapter of its own and speaks JSON-RPC
# to it over a pipe this process owns; a turn that does not complete abandons the
# run rather than recording a receipt for something that did not happen.
wf run review-deep --engine acp --adapter claude --require-pinned \
   --input-arg scope='the last three commits' --input-arg paths=src/Foo.hs

# The watched run. Every question — model, tool and person alike — goes to one
# live agent-deck pane, which is where a `person` party belongs: somebody is
# looking at it.
wf run commit --session <agent-deck-pane-id> --input-arg scope= --input-arg tree=
```

`--require-pinned` refuses to run a question whose party has no served-by pin,
which is what keeps "whichever model answers" from being a silent choice.

**Inputs.** A program that takes inputs refuses to `run` until every one is
named; `plan` and `cost` bind `""` for an input nobody gave, so the price above
is the price of the default roster. `--input-arg NAME=VALUE` for a phrase,
`--input-file NAME=PATH` for a diff.

## What replaces what

The twenty-one rows that exist today stand for **forty-four** files of the corpus
— of 119 — plus one PAL MCP tool that is not a file at all. Each flagship
module's haddock carries its own map in full, with the reason for every cell;
this is the index across all six.

| `~/src/nix/config/ai` | row | note |
|---|---|---|
| `commands/quick-review.md` | `review-quick` | the one-member roster |
| `commands/deep-review.md` | `review-deep` | the whole Step 1..Step 5 pipeline |
| `commands/code-review.md` | `review-deep --input-arg paths=` | the "named-agent health checkup" *is* the language roster, selected by the file list |
| `commands/sec-audit.md` | `review-sec` | three fixed greps as three receipts, plus the security lens |
| `commands/heavy-review.md` | `review-heavy` | the seven independent passes over one snapshot handle |
| `commands/review-github-pr.md` | `review-deep` with a PR scope | its six shouted "NEVER post" bullets become an absence: a review question is asked at `text`, which has no write authority |
| `commands/alexey.md`, `skills/alexey-review` | the `alexey` lens of `review-heavy` | |
| `agents/*-reviewer.md` (eleven) | `Workflows.Rubrics.Reviewers` | one table; the finding schema's eleven copies end here |
| `skills/{abstraction-review,validated-code-review,comment-audit,eliminate-dead-code}` | four lenses of `review-deep`/`review-heavy` | the review-sized slice of each |
| `skills/parallelize` | the independence probe | one spelling where three files carry three |
| `commands/fix-ci.md` | `green-ci` | |
| `commands/bugbot.md` | `botSweepFn`, called by `green-ci` and `stack-rebase-fix` | a call, not `fix-ci`'s lossy prose copy |
| `commands/bugbot-stack.md` | `green-ci` per pull request | the stack walk is `stack`'s |
| `commands/flaky-rust.md` | `green-flaky` | three drawn runs, then a fourth that says flaky or broken |
| `commands/nix-rebuild.md`, `lefthook.md` | `green-tree` | one gate over the working tree |
| `commands/commit.md` | `commitFn` + `commit` | the whole file as one callable function |
| `commands/push.md` | `commit-push` | `commit` + 2, as a number |
| `commands/recommit.md` | `commit-recommit` | each commit held to standalone CI |
| `commands/bankruptcy.md` | `commit-bankruptcy` | its stated-and-unchecked postcondition becomes a free decider |
| `agents/fess-auditor.md` | `fess` | eleven stances over three receipts, and the downgrade arm written |
| `commands/restack.md` | `stack` | nine numbered steps: four become structure, one becomes an argv |
| `commands/rebase.md` | `stack-rebase` | the same body with `git` deciding instead of `gt` |
| `commands/rebase-and-fix.md` | `stack-rebase-fix` | `stack-rebase` + the CI gate + the bot sweep |
| `commands/cleanup.md` | `stack-cleanup` | four obligations behind one real hook gate |
| `commands/resolve.md` | `resolveFn` | one body every `stack` rung calls |
| `skills/fix-all` | `Workflows.Rubrics.Discipline` | spliced into every repair prompt |
| `commands/gravity.md` | the `against` seat of `confer`, and the anti-sycophancy rubric **every** seat stands under — all three confer seats, through `underChallenge`, and `second-opinion`'s single party | the command stays as Markdown for interactive use (§7 row 23, **K**); its second half is harvested into `Workflows.Rubrics.Stances`, compressed and reworded, and its framing sentences are not |
| *not a corpus file:* PAL MCP's `consensus`, `challenge`, `chat` | `confer`, `confer-bare`, `debate`, `second-opinion` | the workflow-native counterpart: three stances, a fenced document, a synthesis that must account for every block, and an artefact on disk — priced at `askNodes 5` before the first token. **PAL MCP stays configured**; this is an alternative offered, not a replacement mandated |

**The full triage — all 119 files, each marked T (its own program), R (rework
first), F (folds into a named host) or K (honestly Markdown) — is
[`doc/design.md` §7](doc/design.md), with §7.5's tally.** Twenty-five programs and
roughly sixty rows sit behind the corpus; twenty-one rows exist today.

## The roadmap

From [`doc/design.md` §8](doc/design.md). Waves are sequential; rows inside a
wave are independent.

| wave | what | gate |
|---|---|---|
| **0** | the move: the tree, the package, the flake, the gate | done — `cabal build all` warning-free, `./ci/workflows.sh` green on 21 rows |
| **1** | the flagships finished, plus `checklist` as the warm-up | done for the five; `checklist` outstanding |
| **2** | **`confer`** (`confer`, `confer-bare`, `debate`, `second-opinion`), then `teams`, `notes`, `effort` (medium/heavy/forge) | **`confer` done, 4 rows** — `Lens` served the stance roster with no field added and no signature widened, so §10's first risk did not fire; `teams`, `notes`, `effort` outstanding |
| **3** | the daily drivers: `pr-threads`, `issue`, `account`, `partner`, `org-tasks`, `claude-md`, `prose` | these mostly `call_` waves 1–2 |
| **4** | the audits and specialists: `dead-code`, `comments`, `bundles`, `productize`, `nix`, `service`, `query`, `expense`, `qanda`, `transcribe`, `tron` | |
| **5** | the long ones and the top of the loop: `retest`, `denote`, `translate`, `prd-draft`/`prd-critique`, `nodered`, and finally **`wiggum`** | `wf cost wiggum` reports a finite worst case |

`confer` is the workflow-native counterpart of PAL's `consensus` — a roster of
model parties, optional stance rubrics, one question each, a fold, and a
synthesis. PAL MCP stays configured; confer is an alternative offered, not a
replacement mandated. Its four decisions are `doc/design.md` §8.1, and the two
one-line generalizations it asks of `Workflows.Panels` (R1, R2) are recorded
there.

```sh
wf cost confer                             # 5, before a word of the decision exists
wf run confer --require-pinned --engine acp --adapter claude \
   --input-arg decision='Should the parser be rewritten as a table-driven DFA?' \
   --input-file context=./doc/parser-notes.md
```

`minFold 5, maxFold 5, over 1 path`: confer is one of the six rows whose ceiling
*is* its price — `hello`, `fess` and the four confer rows — because nothing in it
branches. The three seats are pinned to three **distinct** primaries — `opus`,
`gemini-3.1-pro-preview`, `fable` — which is what lets `--route` put them on
three providers **with the roster unchanged**. Routing is live, and it keys on
the **serving model** and never on the party, so those pins are already the
keys: `--route 'gemini-3.1-pro-preview=deck:gemini-pane'` moves the `against`
seat and nothing else.

Unrouted, the three seats are three fresh sessions of one model, which is
independence of *context* and not of *judgement*. Prefer `--engine acp` for a
confer either way: the deck engine is one durable session for the whole run, so
the third seat reads the first two. The provenance paragraph the artefact opens
with carries both conditions — how many backends answered, and whether the seats
shared a session — and names the run's header as the authority for each.

**Seven reworks come before wave 3** — `fix-alert`, `initialize`, `narrative`,
`run-orchestrator`, `webfix`, `johnw`, `prd-architect`. Each is one decision
answerable in a sitting, and each unblocks a program that would otherwise
transcribe a defect.

## Building it

Two build paths, and they answer different questions.

```sh
nix develop            # the devShell: GHC, cabal, HLS
cabal build all        # this package AND ../agent-cat/haskell, from the working tree
./ci/workflows.sh      # the gate: 21 rows, priced and run
```

```sh
nix flake check
nix build .#default    # the pinned build: agent-cat at the revision flake.lock names
```

> **The pin and the build agree today.** `flake.lock` names an agent-cat
> revision that carries `Agentic.Cli` — the one thing this repository cannot
> supply for itself — and `nix build .#default` succeeds against it: the
> closure builds and `result/bin/wf` runs. When agent-cat's working tree runs
> ahead of the pin (a new module, a changed signature), the pinned build fails
> in exactly the shape it once did here — `Could not find module ‘Agentic.Cli’`
> from `src/Workflows/Registry.hs` — and the fix is two commands, in the other
> repository first:
>
> ```sh
> # in ../agent-cat: commit and push the new surface
> nix flake update agent-cat
> ```
>
> To build against the sibling working tree without touching the pin:
>
> ```sh
> nix build --override-input agent-cat path:../agent-cat
> ```

> **Which is authoritative.** The **flake** is. It pins an agent-cat revision, it
> is what `nix build` and any machine other than this one will use, and it is the
> only statement this repository makes about what it builds against.
> `cabal.project` is a development convenience: it points at
> `../agent-cat/haskell`'s *working tree*, which may be ahead of the pin, behind
> it, or dirty.
>
> When the two disagree — `cabal build` green and `nix build` red — the meaning
> is almost always **"you have agent-cat changes that are not pushed"**, and the
> fix is to push agent-cat and `nix flake update agent-cat`. The reverse — `nix
> build` green and `cabal build` red — means the sibling checkout is on another
> branch. Neither is a bug in this repository.

## Two registries, one CLI

`agentic-run` serves agent-cat's worked examples; `wf` serves this tree. Both are
`Agentic.Cli.cliMain` applied to a `Registry` value, so the thousand lines of verb
parsing, input flags, engine selection and exit codes are shared and cannot
drift. `Agentic.Cli`'s record is the contract between the two repositories:
`Registry`, `Row`, `cliMain`, six field names. Changing it is a breaking change
to `agentic`.

The registries are **not** shared, and the reason is a gate. agent-cat's
`ci/examples.sh` pins `level`, `size`, `askNodes`, `costSummary` and both bills by
equality for every registered program — right for seven fixtures whose numbers
are evidence about the language, and wrong for a toolbox where adding a lens to a
roster moves `askNodes`, `costMax` and every path count at once. `ci/workflows.sh`
instead pins `level` and `paths` by equality and holds `costMax` as a **ceiling
that only ratchets down**: a budget is a promise about the worst case, it may
fall freely, and it rises only by editing one number in that file — which is
exactly the friction that belongs on "this review now costs 40 questions instead
of 24".

## House rules for anything added here

1. **Every rubric names its source.** A define transplanted from the corpus
   carries a haddock line naming the file and section it came from. The
   inventories under `doc/research/` are the audit trail.
2. **Decide as early as possible.** A fact that is in the invocation is decided
   in ordinary Haskell before the `Program` exists (zero questions, zero paths);
   a fact that only exists after the world ran something is a `decide` over a
   receipt (zero questions, one path); only a judgment is an asked flag. See
   `Workflows.Deciders`.
3. **Every argv lives in `Workflows.Evidence`.** That is the one module where the
   read-only rule could be broken, so it is reviewable as a unit. `proc`, never
   `sh -c`; and there is no interpolation syntax at an argv, deliberately.
4. **Never import from agent-cat's `test/corpus` or `tier1`.** The toolbox is not
   conformance and must not be able to make a corpus gate red. (It cannot: this
   package depends on the `agentic` library and can see neither.)
5. **A rubric over roughly sixty lines is a program input, not a define.** Prompt
   bulk is the corpus's largest avoidable cost.
6. **A roster-shaping input must be total on `""`.** `plan` and `cost` bind the
   empty string for an input nobody gave, so `""` must mean *the default roster*
   and never *no members* — `panel []` is an `error` on a CAF, and the gate prices
   every row with no inputs precisely to catch it.
7. **A row is one shape, never one invocation.** Rungs that differ in roster,
   receipts and price are rows; things that differ only in what `--input-arg` is
   given are not.
