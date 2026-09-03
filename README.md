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
cabal.project           the dev loop: this package + ../agent-cat root workspace
flake.nix               the pinned build
ci/workflows.sh         this repository's gate: every row, priced and run
ci/emacs.sh             the Emacs gate: compile, checkdoc, smoke
ci/cookbook.sh          the cookbook gate: regeneration is a no-op
ci/taskmaster.sh        Taskmaster schemas, artifacts, repair, and exhaustion
tools/cookbook-gen.sh   …and the generator it holds doc/cookbook.md to
tools/wf-taskmaster-stage  packaged Taskmaster schema gate and report renderer
tools/taskmaster-framework.sh pinned-source Taskmaster production driver
src/
  Workflows/
    Prose.hs            the four mechanics — bullets, numbered, fenceOf, tshow
                        — and the one help-page fragment more than one page needs
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
      Voice.hs          the it-voice register, which three commands write in and none named
      Personas.hs       the corpus's one persona, compressed, and the table that selects it

    Panels.hs           Lens/Roster, and the three fan-outs
    Deciders.hs         the free tests — every classification the corpus pays for
    Gates.hs            check, fix, recheck, written once
    Escalation.hs       the three-ending ladder: complete / remains / blocked
    Report.hs           the output contract, as functions every rung calls

    Review/Ladder.hs    the review family     (review-quick|deep|sec|heavy)
    Fix/Green.hs        the gated fix loop    (green-ci|tree|flaky)
    Git/Commit.hs       the commit pipeline   (commit|-push|-recommit|-bankruptcy)
    Git/Stack.hs        the git family        (stack|-rebase|-rebase-fix|-cleanup)
    Fess.hs             the audit             (fess)
    Confer.hs           the confer family     (confer|confer-bare|debate|second-opinion)
    ProcessChecklist.hs the warm-up           (checklist)
    Teams.hs            the ten angles        (teams)
    MeetingNotes.hs     the meeting report    (notes)
    Effort.hs           the effort ladder     (effort-medium|-heavy|-forge)
    Threads.hs          the PR comments       (pr-threads|-assess)
    Issue.hs            the issue drivers     (issue|issue-worktree)
    Account.hs          the four accounts     (account-halt|-sitrep|-report|-narrative)
    Partner.hs          the partnership       (partner-reviewer|-collaborator|-cleanup)
    OrgTasks.hs         the Org-mode pair     (org-tasks-breakdown|-infer)
    ClaudeMd.hs         the briefing file     (claude-md|claude-md-advise)
    Prose/Polish.hs     the prose dial        (prose-proofread|-smooth|-transcript|-compress)
    EliminateDeadCode.hs the dead-code pass   (dead-code)
    CommentAudit.hs     the comment audit     (comments)
    DiscoverBundles.hs  external bundles      (bundles)
    Productize.hs       the deliverables      (productize|productize-lefthook)
    Nix.hs              the NixOS host        (nix-rebuild|-alert|-integration)
    Service.hs          services on the host  (service-install|-remove)
    QueryBuilder.hs     the SQL query builder (query)
    ExpenseReport.hs    receipts to a sheet   (expense)
    Qanda.hs            the decision walk     (qanda)
    TranscribeImage.hs  handwriting to Markdown (transcribe)
    TronDebug.hs        the Torch Fx pipeline (tron)
    Retest.hs           the model battery     (retest|retest-categorical)
    DenotationalDesign.hs denotational design (denote)
    Translate.hs        the translation team  (translate|translate-en|translate-es)
    PrdArchitect.hs     the requirements pair (prd-draft|prd-critique)
    NodeRed.hs          flows on vulcan       (nodered)
    Taskmaster.hs       pinned evidence to a framework design (taskmaster)
    Hello.hs            the smoke row         (hello)
    HelloWorld.hs       the beginner example  (hello-world)
    Registry.hs         the index: name -> program, blurb, canned table
bin/Main.hs             `wf`, two lines over Agentic.Cli
emacs/wf.el             the Emacs interface, over `--json` and nothing else
emacs/wf-smoke.el       …and its batch smoke, run by ci/emacs.sh
```

Workflow-definition modules with one canonical source follow that source's name
mechanically: `foo-bar-baz` becomes `FooBarBaz.hs` and
`Workflows.FooBarBaz`. A module that deliberately implements several commands
through one shared program keeps its aggregate family name (`Git.Commit`,
`Review.Ladder`, and their peers) rather than pretending one source owns it.

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

The Cabal command installs `wf` alone. Every existing row except `taskmaster` needs
nothing else; a source-tree Taskmaster run puts `tools/` on `PATH` itself. For an
installed Taskmaster row, use the Nix package, which installs
`wf-taskmaster-stage` beside `wf`.

Then, from whatever repository the work is in:

```sh
wf list                                    # the toolbox, one line per row
wf review-deep --help                      # the row's page; `wf help review-deep`
wf plan review-deep                        # level, size, askNodes, codes, cost
wf plan review-deep --raw                  # …and the program itself
wf cost review-deep                        # the price, path by path
```

`wf <row> --help` is the per-row page: what the row is for, what each of its
inputs means, which transport it wants, one worked command line and one
rehearsal, under a header computed from the same folds `wf list` publishes. It
spends nothing and asks nobody. `wf help <row>` prints the same bytes, and
`wf --help` lists the flags every row shares.

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

**[`doc/cookbook.md`](doc/cookbook.md) is the per-row guide**: all seventy-four,
by family, each with its price, what each of its inputs means, one worked command
line, and the `--scripted` rehearsal to try it dry. This section is the grammar;
that page is what to type for a given row.

### Start here: `hello-world`

`hello-world` is the small, public example to copy before reading the larger
workflows. It takes one `language` input, asks one model for `Hello, world!`,
splices that answer into a second model's prompt, and returns the translation as
the closed program's typed text result. It neither reads nor writes your tree.

For a reproducible first run from the repository root:

```sh
nix build
./result/bin/wf plan hello-world
./result/bin/wf run hello-world --scripted --input-arg language=Spanish
```

The scripted run reaches no model. Its fixed trace and final result include:

```text
    <- Hello, world!
    <- ¡Hola, mundo!

  the run is over.
    result      text
      ¡Hola, mundo!
```

To work on the example, enter the development shell and use the working-tree
binary rather than the pinned flake build:

```sh
nix develop
cabal build exe:wf
export WF="$(cabal list-bin exe:wf)"
"$WF" plan hello-world --raw
"$WF" run hello-world --scripted --input-arg language=Spanish
"$WF" run hello-world --engine acp --adapter claude --require-pinned \
  --input-arg language=Spanish
```

The canned replies are fixed, so the scripted command uses `Spanish` to keep
its fixture coherent; changing the language only changes a live prompt. The live
line also assumes an installed and authenticated `claude` adapter — substitute
another configured ACP adapter when appropriate.

The ACP command streams both questions and answers to this terminal. The second
`<-` line is the translator's consultation response; the `result text` block is
the program's actual returned value. `answer` is a pure terminal projection, so
it adds no consultation, path or cost. No file or agent-deck session is hidden
behind the example.

The pieces to follow are deliberately few:

* [`src/Workflows/HelloWorld.hs`](src/Workflows/HelloWorld.hs) owns the input,
  both prompts, their straight-line `W.do` program, the typed `answer` terminal,
  canned replies, and help.
* [`src/Workflows/Registry.hs`](src/Workflows/Registry.hs) gives that value the
  CLI name `hello-world`; [`agent-workflows.cabal`](agent-workflows.cabal) exposes
  its module.
* [`ci/workflows.sh`](ci/workflows.sh) pins the row's level, path count, and cost
  ceiling, and runs its canned table. [`emacs/wf-smoke.el`](emacs/wf-smoke.el)
  pins the registry count.
* [`doc/cookbook.md`](doc/cookbook.md) is generated from `helloWorldHelp`; do not
  edit its marked `hello-world` region by hand.

The data flow is two Haskell binds: `greeting` is holed into the translator's
prompt, and `translation` is passed to `answer`. The program therefore has type
`ParameterizedOf 'CodeText`, while legacy rows remain receipt-valued
`Parameterized`/`Program` aliases ending in `stop`. To experiment, change a
prompt or party, add a step, or add an input in `HelloWorld.hs`; then update the
canned table and registry/gate metadata that changed. `plan` and `cost` show any
structural or price change before a model is consulted.

After an edit, verify the example and the surfaces derived from it:

```sh
cabal build all
"$WF" run hello-world --scripted --input-arg language=Spanish
./tools/cookbook-gen.sh
./ci/cookbook.sh
./ci/workflows.sh
./ci/emacs.sh
```

### The Taskmaster analysis workflow

`taskmaster` is a production workflow built *with* agent-cat, not an agent-cat
language fixture. It collects reviewed excerpts from pinned Taskmaster and agent-cat
commits, carries four schema-validated JSON stages with one repair each, and lets a
deterministic renderer—not a model—own the report and citations. No `Agentic.*`
semantic or transport change is required, which is why the row lives in this second
registry.

From a source checkout, reproduce the retained fixture run with:

```sh
TASKMASTER_UPSTREAM=/absolute/path/to/claude-task-master \
TASKMASTER_AGENT_CAT=/absolute/path/to/agent-cat \
  tools/taskmaster-framework.sh
```

The ordinary registry gate prices its Program; `ci/taskmaster.sh` additionally runs
the executable schema gates, all four successful-repair paths, all four exhausted
paths, golden rendering, and retained-artifact checks. The exact trust, provenance,
output, and optional live-smoke contract is
[`doc/research/taskmaster-workflow-contract.md`](doc/research/taskmaster-workflow-contract.md).

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

**Four input names are the runner's.** `run.backends`, `run.engine`,
`run.routes` and `run.sentinel` are *run facts* — how many answerers this run
reached and which, whether each question got a session of its own or they all
shared one, which *pin* reaches which of those answerers, and a
line generated for this run and put nowhere else. `run` binds all four from the
run it is making and a flag naming one is refused, because a command line cannot
say what a run did: they are not part of the count when a row says how many
inputs it takes, and `--input FILE` still means the one input that is yours.
Thirteen rows declare one or more of them, and what each does with a fact is its
own business — `confer` and `partner-reviewer` quote the engine in their provenance
so a reader can see whether the answerers shared a conversation, while `wiggum`
*refuses to start* when they did. `plan` and `cost` make no run, so all four
come out empty there, which is why the numbers pinned in `ci/workflows.sh` are
the numbers of a run whose engine is not yet known.

`run.routes` is the newest of the four and the only one that is a *mapping*
rather than a count: one line per answerer, `LABEL = BACKEND`, the `(default)`
line first and then each `--route` in the order it was typed, in the backend's
own spelling — the same table the run's header prints. `run.backends` cannot
substitute for it, because that roster is deduplicated and carries no names, and
no arithmetic over it can answer *does the judge share a conversation with the
worker*. `wiggum-duet` is its first consumer: it reads the table and the engine
together and refuses, before spending anything, any invocation where the judge's
backend is the backend of **any** other pin the row reaches — or is the
**default**, which is where every borrowed callee lands when no `--route` names
it.

## The Emacs interface

`emacs/wf.el` is the same verbs with a minibuffer in front of them: pick a
row, give it its inputs, pick a transport, **read the price and say yes**, and
watch the run in a buffer of its own. No external packages — Emacs 29.1 and what
ships with it.

```elisp
(use-package wf
  :load-path "~/src/agent-workflows/emacs"
  :commands (wf-run wf-plan wf-cost wf-help wf-refresh))
```

Or, without `use-package`:

```elisp
(add-to-list 'load-path "~/src/agent-workflows/emacs")
(autoload 'wf-run "wf" nil t)
(autoload 'wf-plan "wf" nil t)
(autoload 'wf-cost "wf" nil t)
(autoload 'wf-help "wf" nil t)
```

Five commands to start from, none bound to a key (the run buffer binds two more
of its own, below):

| command | what it does |
| --- | --- |
| `M-x wf-run` | pick, price, confirm, run |
| `M-x wf-plan` | read `wf plan` for a row, run nothing |
| `M-x wf-cost` | read `wf cost` for a row, run nothing |
| `M-x wf-help` | read the row's page — inputs, transport, a worked line, a rehearsal |
| `M-x wf-refresh` | forget the cached listing (`C-u` on the other four does the same) |

Three options: `wf-program` (default `"wf"`), `wf-agent-deck-program` (default
`"agent-deck"`) and `wf-confirm-function` (default `yes-or-no-p`).

**Picking.** The candidates come from `wf list --json`, cached for the session,
and each is annotated with its price and its blurb:

```
wiggum                branch · at most 44 over 34 paths  —  wiggum/SKILL.md: two work rounds, …
wiggum-duet           branch · at most 50 over 34 paths  —  wiggum's loop across two panes: the work …
review-quick          branch · at most 6 over 3 paths    —  one lens over a frozen snapshot: …
```

That is `completing-read` with an `annotation-function`, so it reads the same
under vanilla completion, `icomplete`, or whatever else is installed.

**Inputs.** Every input the row *declares* is asked for, one at a time, in
order. Each keeps a minibuffer history of its own — `M-p` recalls what *this*
input was given before, and the last answer is offered as the default, so a
second run of `wiggum` in an afternoon is four `RET`s rather than four paths
retyped. Empty is allowed and passes an empty value, where there is no default
to take instead. An answer beginning with `@` is a file — with file-name
completion after the `@` — so `@notes.md` becomes `--input-file NAME=notes.md`
and anything else becomes `--input-arg NAME=VALUE`. The file is named *on the
machine `wf` will run on*: `@~/notes.md` from a hera buffer is hera's home, and
naming this machine's file there is refused rather than sent along to fail. The
four run facts are never asked for; the runner binds those.

**The price gate.** Asked last — after the inputs *and* after the transport,
never before — because a ceiling means one thing over `acp` and nothing at all
under `scripted`, and a question answered first would have priced a run nobody
had described yet. So the question names the transport it is the price of:

```
Run wiggum via acp:claude (branch, at most 44 consultations over 34 paths)? (yes or no)
Run wiggum via agent-deck session 9f3a2b-1747051200 (branch, at most 44 consultations over 34 paths)? (yes or no)
Run wiggum as a rehearsal (scripted): consults nobody (branch, 34 paths)? (yes or no)
```

The rehearsal quotes no ceiling, because it would be the one false number in the
sentence: a `--scripted` run answers from the row's own table and consults
nobody, whatever its paths could have cost. `g` in the run buffer asks the same
question again, naming the same transport, before repeating a run.

The word is typed out on purpose. The plan is on screen beside the question,
and `SPC` — the key you reach for to read on — is `act` in `query-replace-map`,
which `y-or-n-p` remaps to `y`; one thumb-twitch would start 44 consultations.
Set `wf-confirm-function` to `y-or-n-p` to trade that back for one key.

The prose in the plan buffer is for reading. The number in the question is read
from `wf plan NAME --json` under the inputs just given — this package parses the
JSON contract and nothing else, so no CLI wording is load-bearing here. A
program with no path through it has no ceiling, and the question says `—` there,
as the CLI does.

**Driving hera over TRAMP.** Every subprocess is started with `process-file` or
`start-file-process`, which honour the calling buffer's `default-directory`. So:

```
C-x C-f /ssh:hera:~/src/my-project/    RET
M-x wf-run                             RET
```

and `wf` runs *on hera*, in that repository, listing hera's rows, completing
hera's file names after an `@`, and offering the agent-deck sessions hera can
see. There is nothing else to configure — only that `wf` be found on the remote
PATH, which for TRAMP means `tramp-remote-path` reaching it (`(add-to-list
'tramp-remote-path 'tramp-own-remote-path)` is the usual answer) — and when it
is not there, the command says so and names both variables rather than raising
`file-missing`. This is the intended way to drive remote agent-deck sessions;
the local case is the same command from a local buffer.

**The run buffer.** `*wf: ROW*`, in `wf-run-mode` — read-only, colours applied
rather than shown, `C-c C-k` to interrupt, `g` to ask the price again and rerun,
`q` to bury. A run over TRAMP names its host, `*wf: hera:wiggum*`, so the same
row driven here and on hera gets a buffer each — the listing is cached per
connection and so are the buffers holding what came back. Scrolling back to
re-read a consultation holds: a window follows the output only while it is
already at the end.

**Deck sessions** come from `agent-deck list -json` when that answers, and from
a lenient parse of its plain table when it does not: the field that is a *whole*
session id is the id and the rest of the line is the title. Whole, because the
plain table ellipsizes that column and a truncated id selects nothing — a line
without one is skipped rather than guessed at. Both calls keep the two streams
apart, as every other call to a binary here does: with stderr merged into the
parsed output, one narrated line about a stale profile would make the JSON
unreadable and cost every session silently. If neither source works the prompt
degrades to reading an id as a string — and says why in the prompt, quoting
agent-deck's first line of stderr, or `agent-deck listed no sessions` when it
said nothing at all. It never raises.

**Why no transient.** The interaction is a straight line — row, inputs,
transport, price, go — with each step's choices decided by the last. A transient
prefix would be a menu over four questions that have to be asked in order
anyway, so it does not earn the dependency on a second UI model.

**The gate.** `./ci/emacs.sh`, from the repository root, is three passes over
`emacs/wf.el` and `emacs/wf-smoke.el`: byte-compilation with
`byte-compile-error-on-warn` so that a warning *is* the failure, `checkdoc` with
`arguments-in-order` and `package-keywords` — the two the defaults leave off —
and then the smoke, which loads the package and asks the real `wf` binary for
its listing. It finds Emacs at `$EMACS` or on `PATH` and the binary at `$WF` or
under `dist-newstyle`, and says which sentence to fix when it finds neither.

```sh
./ci/emacs.sh
EMACS=/path/to/emacs WF=$PWD/dist-newstyle/…/wf ./ci/emacs.sh
```

The smoke asserts what the JSON contract promises and the wording that spends
money: the row count and `wiggum`'s declared inputs, the per-connection cache,
that `@` hands off to file-name completion *after* the `@`, that the agent-deck
listing keeps its two streams apart so a line of stderr costs no session, that a
missing agent-deck degrades to nil *and* says why, and both shapes of the price
gate's question — including that a rehearsal says `consults nobody` instead of
quoting a ceiling it will not spend. One thing it does not cover: the per-input
`M-p` history and the last-answer default are verified structurally, since batch
Emacs records no minibuffer history — exercise those once interactively.

## What replaces what

The seventy-four rows that exist today include three workflows that are not corpus
replacements: `hello`, the transport smoke test; `hello-world`, the public tutorial;
and `taskmaster`, a pinned external-source analysis. Collectively, the corpus-derived
toolbox covers **eleven more files** than the sixty-one-row stage did — ninety-one,
plus wave 5's nine, plus the two files the last two rows absorb
(`skills/wiggum` and `commands/run-orchestrator`) — plus one PAL MCP tool that is
not a file at all and one external skill (`translate-en`) whose edge is transplanted
and whose text is not. `wiggum-duet` stands for no new file either: it is the same
two files across two panes, which is the owner's own ruling and not a corpus
document. Each program module's haddock carries its own map in full, with the reason
for every cell; this is the index across all thirty-seven.

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
| `skills/parallelize` | the parent-history sentinel probe | one spelling where three files carry three — and it is reported for what it tests, which is that no line *this runner planted* was inherited. Whether an answerer had already read the work is `run.engine`'s to say, and the rows that care state it beside the probe or gate on it |
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
| `commands/process-checklist.md` | `checklist` | two rounds, each entered behind a `decide` over a `cat` receipt: the loop's exit condition costs zero questions where the file spends a re-read |
| `commands/teams.md` | `teams` | ten angles, the devil's advocate correctly a **second tier** over the fold, and a review of all the work that must account for every block first. `wf cost teams` says 13 |
| `commands/meeting-notes.md` | `notes` | ten sections over one `cat` receipt, and the file's five quality checkpoints as a **separate** panel on a serving model none of the sections used — a fact-only discipline audited by the same model is not audited |
| `commands/medium.md`, `skills/toolkit` | `effort-medium` | the toolkit as one define, and its working discipline as an exit code |
| `commands/heavy.md` | `effort-heavy` | its one conditional (`positron`/`pos`) decided in Haskell before the program exists: zero questions and zero paths |
| `skills/forge/SKILL.md`, `commands/forge.md` | `effort-forge` | six phases as six binds, the approval as a flag with an arm for "no", and the remediation loop's three endings as `SettledOn`/`UnsettledOn`/`AbandonedOn` — which is where `Workflows.Escalation` earns its keep |
| `commands/respond.md` | `pr-threads` | one answer per open colleague comment; never-posting is an **absence** — no party in the program carries a write verb, and the empty pull request is an ending that costs 3 |
| `commands/assess.md` | `pr-threads-assess` | its "haskell-pro and/or cpp-pro and/or rust-pro" is tier-1 roster selection over `--input-arg paths=`, and its "use the `opus` model" is a `servedBy` pin `--require-pinned` enforces |
| `commands/fix.md` | `issue` | three cheap gates decide whether anything expensive happens; then `commitFn`, the push, the pull request, and `botSweepFn` over the ledger that now exists |
| `commands/fix-github-issue.md` | `issue-worktree` | the `work/fix-<n>` naming scheme computed in Haskell, and "leave it uncommitted" as a `git -C … status --porcelain` receipt read by a decider |
| `commands/halt.md` | `account-halt` | `journalFn`, `commitFn`, the push, the remaining-scope panel, and its emitted `fess` instruction as a **hole** rather than a hope; its step-2 postcondition is finally tested |
| `commands/sitrep.md` | `account-sitrep` | eight sections over four command receipts, so `Measurements` cannot invent a number, and the `YYYYMMDDTHHMM-SITREP-$PROJECT-$BRANCH.md` scheme computed here from two of them |
| `commands/report.md` | `account-report` | seven categories as seven panel members, and the estimate as a separate question on a different engine over the fold |
| `commands/narrative.md` | `account-narrative` | **reworked**: a receipt dossier, a chronology over it, a writer over that, and "distinguish fact from inference" as a sourcing gate on a third engine |
| `commands/journal.md` | `journalFn` | called by `account-halt`, read as a `cat` receipt by `account-narrative` — a function, not a program (§7.1 row 30) |
| `commands/partner-reviewer.md` | `partner-reviewer` | `heavy-review`'s seven passes, which is the review command that file names, and the observation count as a `find` receipt. `ideas=off` is one fewer consultation in `ci/workflows.sh` — 11 against 12 — because that file has no ideation section and this row therefore asks no ideation question. **Run it somewhere else than the work**: `--session <pane>` in an `agent-deck` pane that is not the one doing the work, or an `--engine acp` invocation of its own, which opens a session per question. A partner review put down the same conversation as the work is the work reviewing itself, and `run.engine` in the report says which you did. That last sentence is advice this row cannot check; `wiggum-duet` is where it became a refusal a program computes |
| `commands/partner-collaborator.md` | `partner-collaborator` | `deep-review`'s roster plus "three wild ideas" as `drawing 3` on one lateral party; one contract with the `Idea` category **derived**, ending an enum that had already drifted |
| `commands/partner-cleanup.md` | `partner-cleanup` | two drain rounds, each behind a free test over a `find` receipt, then exactly one `commitFn` call — and the ending its prose loop cannot have |
| `commands/breakdown.md`, `agents/task-breakdown.md` | `org-tasks-breakdown` | `[ATOMIC]`, `[AMBIGUOUS]` and `[NO-EXPERTISE]` as three deciders and three arms, and the completeness check asked of somebody else |
| `commands/infer-tasks.md` | `org-tasks-infer` | its `NO-OVERLAP RULE` as a free decider over `** `, its own no-tasks sentence read for nothing, and its two judgments on a second party |
| `commands/initialize.md` | `claude-md` | **reworked**: the "if one already exists" clause split into two named outcomes — one decider, two `Fn`s, two terminals — and the mandatory prefix as a `lit` |
| `commands/prepare-with.md` | `claude-md-advise` | the `$ARGUMENTS` roster as a Haskell table, and the eight usage notes as an auditor over the draft on another engine |
| `commands/proofread.md` | `prose-proofread` | its five prohibitions as a diff auditor elsewhere, and the per-file count as a `git diff` receipt rather than a claim |
| `commands/smooth.md` | `prose-smooth` | "do not change it overmuch" gets a measure: a bounded restraint gate amending *toward a lighter touch*, with the ending for a reviewer that will not judge |
| `commands/fix-transcript.md`, `skills/fix-transcript` | `prose-transcript` | the rule-priority order over a `cat` receipt spliced as its own chunk, the two reference corpora as an `--input-file`, and a fidelity check on another engine |
| `skills/caveman/SKILL.md` | `compressFn` + `prose-compress` | the first genuinely reusable prompt combinator: its answer *is* the artefact, so "output ONLY the compressed text" is not a rule it can break |
| `skills/it-voice/SKILL.md` | `Workflows.Rubrics.Voice` | the register `narrative`, `smooth` and `proofread` all write in and none of them names; its self-check is a question put to somebody else |
| `prompts/emacs.md` | `Workflows.Rubrics.Personas` | compressed at authoring time for zero questions, and selected by `paths` in ordinary Haskell — the corpus stacks 169 lines by hand |
| `commands/eliminate-dead-code.md`, `skills/eliminate-dead-code` | `dead-code` | four phases as four segments of one block, two hard gates before a model is asked anything, and the three-advocate debate folded in the **verdict monoid** — so "this is not a majority vote" is a fold and not a rubric |
| `skills/comment-audit` | `comments` | the extractor as three receipts, the manifest read back off disk, and the false-positive guard on a serving model that did none of the auditing — **fixes are applied only in the arm where it approved** |
| `commands/discover-bundles.md` | `bundles` | the six hard rejections decided **before** any paid scoring, so a batch that all fails costs 3 questions instead of 12; the seven weighted criteria as seven seats each carrying its own weight; the candidate text a `{hole}` |
| `commands/productize.md` | `productize` | twenty-one deliverables as a roster **priced at twenty-one before the first one is written**, the copyright year range as a `git log` receipt, and `nix flake check` as the gate that verifies deliverable 5 by running it |
| `commands/lefthook.md` | `productize-lefthook` | `call_ lefthookFn` and seven of the twenty-one, where the corpus slices a section out of a sibling command by prose reference. Same body, half the ceiling |
| `commands/nix-rebuild.md` | `nix-rebuild` | the host's own build driver at **`verdict`** — the one kind of ask that survives a nonzero exit — so the failing line the diagnosis reads is the driver's own; one build, three arms |
| `commands/fix-alert.md` | `nix-alert` | **reworked**: `caveman` is dropped from the diagnostic path, because a compressor sheds exactly the labels and thresholds that decide the diagnosis. The routing it was meant to make cheap is free instead — tier 1 over the payload's own `severity=` |
| `commands/fix-integration.md` | `nix-integration` | its hard-coded `Invalid handler specified` becomes an input whose **default** carries that text, so it generalises without losing its default |
| `skills/nixos/SKILL.md` | `Workflows.Evidence.nixosBuild` + `hostFlags` | three prohibitions as **absences**: there is no `sops`, no `rm` and no build command but the driver anywhere in the tree, and no prompt in `Workflows.Nix` states any of the three. The VPS `--max-jobs 1 --cores 1` is tier 1 in the printed argv |
| `commands/install-service.md` | `service-install` | nine obligations as nine `call_`s of one body, in the file's own order; its two capital-letter pleas as a **consent file the program is forbidden to create**, with `ask_ owner` as the terminal; item 10 as `systemctl` and `curl`, read as three endings |
| `commands/remove-service.md` | `service-remove` | the tree's **exemplar of structural read-only**: twelve discovery questions at `text`, which cannot write whatever they are told, and one act that writes a script it does not run. The SOPS exception needs no rule — there is no `sops` argv |
| `commands/query-builder.md` | `query` | its three repetitions of "never reveal data" collapse into **no `act` at all**: the schema is a `cat` receipt, there is no database argv anywhere in the tree, and a draft opening a line with a write verb is refused by a free decider before the audit is asked anything. The mssql MCP is **narrowed** to an exported schema plus a dialect input whose default is that MCP's |
| `commands/expense-report.md` | `expense` | the owner in **binding position** driving `revisingOn` — accept settles, an edit amends with his one line spliced, an empty answer stops — and its decorative `REVIEW` flag as the free decider that chooses between that loop and a single yes/no. Four of six endings build nothing; the corpus's `nix-shell --run` shell string becomes `nix shell … --command`, four argv elements with no shell |
| `commands/qanda.md` | `qanda` | **the rework is the input**: "these decisions" becomes `--input-file decisions=`, read in Haskell before the program exists, and the agenda is spliced into every round. The owner is the loop's verdict, and an empty answer is an ending — a person who walks away from a decision review has not consented to its conclusions |
| `commands/transcribe-image.md` | `transcribe` | `revisingOn (atMost 2)` gives "re-review" the stopping rule the sentence has no way to state, and "use pal mcp" becomes a `servedBy` pin rather than a tool call. The honest limit is §7.2 row 64's own: an `ls` receipt over the image paths proves the files, and nothing in the run can see the handwriting |
| `commands/tron-debug.md` | `tron` | its three `<command>` blocks as four receipts — the `&&` is sequencing, not a shell — with the **sglang control run first**, so a differential whose control did not build refuses to diagnose. Four IR boundaries over one dossier, and the diagnosis node reachable only through the arms in which every command ran |
| `commands/retest.md`, `skills/retest` | `retest` | the phase battery as an exhaustive sweep: three `panel`s and four verdict binds, so "**do not stop at the first failure**" is a fold rather than a rule. The 674-line spec is an `--input-file`; the five-value taxonomy is read by two free deciders; and the empty derived set is INCOMPLETE **structurally**, from the model-set audit's own answer rather than from a grader's summary |
| `commands/retest-categorical.md` | `retest-categorical` | the same body, nine override rows as nine fields of one table — so **phase numbering ceases to exist** and the off-by-one that file spends a paragraph warning about is unrepresentable. Its fixed eight-model roster is argv, and `wf cost` says **37** before a single FPGA card is opened, which is §7.2 row 57's whole ask |
| `skills/denotational-design` | `denote` | the admission test as a `confirm` **before** the body; the four meaning phases as a chain; every phase's exit test applied by a party that wrote none of it, bounded; and phases 5–8 reachable **only** through the arm where the meaning settled — which is phase 7's own Gate expressed as reachability. A retrofit's "start over" verdict is a free decider and a **successful** ending |
| `skills/persian`, `agents/persian-translator.md` | `translate` | the six-seat review team as a panel folded in the **priority order phase 4 resolves conflicts by**, so the conflict list cannot drift from the fan-out; the unbounded "run Phase 3 again" as `revisingOn (atMost 2)`; the 52-term glossary as one define under `TERMS.csv`; and `TeamCreate`/`TeamDelete` dissolved, because a panel is a fan-out and not a resource |
| `translate-en` *(external)* | `translate-en` | one body, the directions swapped. The edge is transplanted and not the text: what the corpus itself says about this direction is `persian/SKILL.md`'s own last line, plus the one-line register the external skill names |
| `prompts/spanish.md` | `translate-es` | `call translateFn` and one delivery — `pipeline`, one path, **2**. The family's shared drafting function has three call sites, which is what makes the three rungs provably share a turn |
| `agents/prd-architect.md` | `prd-draft`, `prd-critique` | **the rework is the split.** One file was two agents selected by an unstated condition; §6's own "if one doesn't already exist" is the condition, and a `test -f` decides it — so the two rows are each other's arms. `prd-draft` puts the owner in binding position and reads `[TODO:` for nothing, sending an incomplete draft back to him rather than to a reviewer; `prd-critique` contains no `act` but the report |
| `skills/node-red` | `nodered` | the three-signature admin boundary **is** the argv — no `curl`, no HTTP client, no flow-file path, no credential read, so six prohibitions become commands that do not exist. The `FLOW_ID` regex is checked in Haskell before the program exists; "zero rows → upstream issue" is a free decider over `psql`'s own footer; "don't fabricate entity IDs" is a `jq` receipt; and the put is the single node with write authority |
| `skills/wiggum`, `commands/run-orchestrator.md` | `wiggum` | **the loop's inner step, priced** — two work rounds, one checkpoint audit and a bounded done-criteria verdict at `minFold 2, maxFold 44, over 34 paths`, which is wave 5's gate. It is *not* the skill's unbounded continuation: the rounds are unrolled at the program level (a bounded revision's body reviews and amends and holds no other statement, so the work cannot loop inside one), and the unroll count — two — is a design decision the gate records in its own words: "a third round would be a design decision and would show here." A long session is several `wf run wiggum` invocations, each re-priced — continuation, compaction refresh and the cross-session durable files stay with the skill. What the program wins: the frozen plan is an *input* ("read-only for the purpose of lowering the bar" becomes true rather than requested); the loop will not start at all under an engine whose questions share one conversation — that is `run.engine` read in Haskell, so it costs no question and no path, and it is the gate the sentinel probe could never be, since a session already carrying the work answers `PARENT_HISTORY_ABSENT` truthfully; the probe is then the *first* question and gates every path, over the residual the engine fact cannot see; the evaluator answered none of the work's questions by construction; "Do NOT submit or push" becomes an **absence** — there is no push argv reachable from the module, verified transitively. `run-orchestrator`'s steps 5–6 are a layered topological sort in Haskell, so the fan-out cap is computed where `parallelize` guesses 3–5 |
| the owner's ruling of 2026-08-20 (no corpus file) | `wiggum-duet` | **the same loop across two live panes**, and the row that made `run.routes` worth having. Its two pins are `worker` and `partner`, neither with a fall-back — a dead pane is a dead question, not a question that silently tries the pane about to judge it — and everything it does not pin itself stays on the default, which is the work's pane. The partner's four seats review round one *inside the term* and round two reads their observations, which is the bind `wiggum` does not have: the old guide's copy-paste between two invocations, priced at `minFold 2, maxFold 50, over 34 paths`. Its gate is `judgeIsElsewhere` over `run.routes`, `run.engine` and the row's own list of work-side pins, shared with `wiggum` so the two cannot drift; it refuses the *inverted* split as well as the shared one, and it refuses a borrowed callee's pin routed at the judge's pane, which is the same contamination spelled as an extra `--route` |

**The full triage — all 119 files, each marked T (its own program), R (rework
first), F (folds into a named host) or K (honestly Markdown) — is
[`doc/design.md` §7](doc/design.md), with §7.5's tally.** Twenty-five programs and
roughly sixty rows sit behind the corpus; **seventy-four** rows exist today, and
with `wiggum` landed the roadmap's five waves are complete. The newest row is the
external `taskmaster` analysis; like `hello-world`, it is not another corpus
transcription. §7.5's "roughly sixty"
was an underestimate rather than a target that has
been met, and the reason is the naming rule doing its job: a rung whose roster,
receipts and *price* differ is a row, and wave 5 alone found nine of them behind
five programs.

## The roadmap

From [`doc/design.md` §8](doc/design.md). Waves are sequential; rows inside a
wave are independent.

| wave | what | gate |
|---|---|---|
| **0** | the move: the tree, the package, the flake, the gate | done — `cabal build all` warning-free, `./ci/workflows.sh` green on every registered row |
| **1** | the flagships finished, plus `checklist` as the warm-up | **done** — the five, and `checklist` at `minFold 2, maxFold 8, over 4 paths` |
| **2** | **`confer`**, then `teams`, `notes`, `effort` (medium/heavy/forge) | **done, 10 rows** — `Lens` served the stance roster, the ten team angles, the ten notes sections and the five checkpoints with no field added, so §10's first risk did not fire. `asksOver` **was** widened, which is R1 and is a different thing: see below |
| **3** | the daily drivers: `pr-threads`, `issue`, `account`, `partner`, `org-tasks`, `claude-md`, `prose` | **done, 19 rows** — and §8's claim is testable from `ci/workflows.sh`: the two largest rows in the wave are the two that call waves 1–2 (`issue` at 14 calls `commitFn` and `botSweepFn`; `account-halt` at 15 calls `journalFn` and `commitFn`), and four rows price at 5 or under |
| **4** | the audits and specialists: `dead-code`, `comments`, `bundles`, `productize`, `nix`, `service`, `query`, `expense`, `qanda`, `transcribe`, `tron` | **done, 15 rows** — and §10's first risk still has not fired: `Lens` carried three advocates, seven weighted criteria, twenty-one build deliverables, twelve removal surfaces and four compiler-pipeline boundaries with no field added. The widest ceiling in the wave is `productize` at 31, which is what §7.2 row 42 asked for |
| **5** | the long ones and the top of the loop: `retest`, `denote`, `translate`, `prd-draft`/`prd-critique`, `nodered`, and finally **`wiggum`** | **done, 10 rows.** The wave's claim was that these transplant whole *procedures* rather than rubrics, and the table shows it: `retest-categorical` at 37 was the widest ceiling in `ci/workflows.sh` until the last row landed, and it is an eight-model FPGA sweep priced before a card is opened; `denote` and `prd-draft` are the two rows whose expensive halves are *unreachable* until a gate said yes. §10's first risk never fired — `Lens` carried eight PRD sections, seven analysis axes, six translation reviewers and six Node-RED house-style seats with no field added. **The wave's gate is paid:** `wf cost wiggum` reports `minFold 2, maxFold 44, over 34 paths` — a finite worst case, printed before the first round |

`confer` is the workflow-native counterpart of PAL's `consensus` — a roster of
model parties, optional stance rubrics, one question each, a fold, and a
synthesis. PAL MCP stays configured; confer is an alternative offered, not a
replacement mandated. Its four decisions are `doc/design.md` §8.1, and the two
one-line generalizations it asks of `Workflows.Panels` (R1, R2) are recorded
there. **R1 landed with the rest of wave 2**: `Workflows.Panels.asksOver` is now
typed `(Says a s) => Roster -> Text -> a -> [Ask s]`, which is exactly the three
things a `{hole}` may resolve to and not one value further, so a fan-out whose
subject is a program *input* no longer has to copy the body. `Confer`'s written-
down copy of it is deleted, `teams` and `effort` never wrote one, and the four
confer rows price as they did.

### Wave 2's residue: `checklist`, `teams`, `notes`, and the effort ladder

```sh
wf cost effort-medium ; wf cost effort-heavy ; wf cost effort-forge
#   minFold 4, maxFold  7, over  3 paths
#   minFold 7, maxFold 10, over  3 paths
#   minFold 10, maxFold 24, over 16 paths
```

`skills/toolkit/SKILL.md` declares the owner's own cost model — `medium ⊂ heavy ⊂
forge` — in three bullets, and has no way to say what the containment costs. It
costs **7 → 10 → 24**, and pricing `forge` before running it is what
`doc/design.md` §7.4 row 10 calls the demo.

Three things in these four rows are worth naming, because each is a place a
Markdown file said something it had no mechanism for:

* **`forge`'s "do not fall back to single-model operation" is the absence of a
  ladder.** `Workflows.Effort.partnerOne` and `partnerTwo` are pinned with
  `servedBy` and carry **no** `fallingBackTo` — alone in this tree — so a partner
  that will not answer cannot be silently replaced by the house model, and
  `--require-pinned` refuses the run before a plan is printed if a pin is
  missing.
* **`forge`'s three overall assessments become a sum type**, and that is where
  `Workflows.Escalation` earns its keep. It was built in the foundation wave and
  had no caller; `escalating` is the right loop exactly when the review is a model
  *whose refusal must end the run*, which is forge's prerequisite halt, and its
  `SettledOn` / `UnsettledOn` / `AbandonedOn` are forge's own "ready to merge,
  needs fixes, or needs rework". The module is **kept, and called**; nothing in it
  had to change.
* **`checklist` is not a `revising`, and the design sketched one.** A bounded
  revision's review clause is a *verdict* question, so a `decide` cannot be one,
  and a revision's body is exactly one review and one amendment, so a per-round
  pipeline cannot stand in one. `Workflows.Gates`' own haddock names the shape to
  use instead — K unrolled rounds, each a `call_` behind a `decide` on the
  previous round's receipt — and that is what landed, with the deviation recorded
  in the module header. The design's "zero questions per trip" survives intact: it
  is the *decider* that is free, in either spelling.


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

### Wave 3: the daily drivers

```sh
wf cost prose-compress ; wf cost claude-md ; wf cost issue ; wf cost account-halt
#   minFold 2,  maxFold  2, over  2 paths
#   minFold 3,  maxFold  4, over  2 paths
#   minFold 2,  maxFold 14, over  4 paths
#   minFold 15, maxFold 15, over  2 paths
```

Nineteen rows over seven programs, and the four numbers above are the wave read
end to end: the smallest is one call to a shared transform, and the largest is a
program whose whole body is calls to waves 1–2. `issue`'s `minFold 2` is the one
worth pausing on — `fix.md`'s own `NOTE` says "do not work on a bug that already
has a PR open; just give the PR number and stop immediately", and that sentence
now costs one receipt and one report instead of sitting eleven paragraphs above
the work it is meant to prevent.

Four things in this wave are worth naming, because each is a place a Markdown
file said something it had no mechanism for:

* **Never posting is an absence.** `respond.md` wants a report and no comments;
  `pr-threads` has exactly one `act` in it and that act writes a file. There is
  no `gh pr comment` in `Workflows.Evidence` for a run to reach for, so the rule
  is not enforced, it is *unavailable*.
* **Two reworks are discharged.** `initialize`'s "if one already exists" clause
  silently changed the output *kind*; it is now one decider over an `ls` receipt
  and two functions with two terminals — and the decider is what makes the `cat`
  after it safe, which is the one place in the tree where a free test licenses a
  command. `narrative`'s evidence-gathering and prose were one ask; they are now
  a dossier, a chronology, a writer, and a sourcing gate on a third engine.
* **A drift that had already happened is closed.** `partner-reviewer.md` and
  `partner-collaborator.md` are an ~85 % duplication whose `Category` enums had
  diverged. There is now one contract, one vocabulary, and the `Idea` row is
  *derived* from the one setting that distinguishes the two commands.
* **The honest count of "the mechanical eleven".** §7.2 row 27 asks for eleven of
  `infer-tasks.md`'s thirteen validation items to become deciders. Exactly one of
  them is expressible by `Agentic.Text.Decider`'s four constructors — the nesting
  rule, which is the load-bearing one — and a character count is not a line
  prefix. The other ten stay in the brief, the two judgments went to a second
  party, and `Workflows.OrgTasks`' header states the deviation rather than
  leaving it to be discovered.

**One rework remains** — `webfix` (`green-web`), deferred with its reason
recorded in `doc/design.md` §8's completion amendment. Of the original seven,
`initialize` and `narrative` landed with wave 3 (above), `fix-alert` with
wave 4 (below), and `run-orchestrator` and `prd-architect` with wave 5;
`johnw`'s split is **decided and deliberately unwritten**:
`Workflows.Rubrics.Voice`'s header records the ruling and the reason there is no
code for it yet, which is that no row in waves 1–5 writes in the owner's personal
voice and a 487-line define with no call site would be the largest unpaid prompt
in the tree.

### Wave 4, first half: the audits and the specialists

```sh
wf cost bundles ; wf cost service-install ; wf cost productize
#   minFold  3, maxFold 12, over  3 paths
#   minFold  2, maxFold 23, over  4 paths
#   minFold 27, maxFold 31, over  6 paths
```

Ten rows over six programs, and the three numbers above are the wave read end to
end. Two of them are the same shape as each other and neither is anything waves
1–3 produced: **a cheap refusal in front of an expensive body.** `bundles` spends
three questions when nothing survives its six hard rejection conditions and
twelve when something does; `service-install` spends two when the operator has not
issued the certificate and twenty-three when he has. In both cases the corpus has
the refusal — in a paragraph before the scoring table, and in capital letters
twice — and no mechanism that makes it come first.

`productize`'s 27-to-31 is the opposite shape and is the wave's other point: a
program with almost no branch and a large fixed body. `productize.md` is
twenty-one bullets and contains no number at all; this row is those bullets
priced, which is the whole of what §7.2 row 42 asked for.

Five things in this half are worth naming, because each is a place a Markdown file
stated a discipline it had no mechanism for:

* **A debate no majority can win.** `eliminate-dead-code`'s phase 2 says, in bold,
  "this is not a majority vote", and then asks one reader to hold three
  advocates' arguments and be conservative. Here the three are a `panel`, which
  folds right in the noncommutative verdict monoid where **every member must
  approve** — so the keep advocate objecting *is* the verdict, and "uncertainty
  resolves to keep" is not a rule the fold can break.
* **Two gates before anything is asked.** The same skill's phase 1.2 says abort on
  a dirty tree and abort on a red baseline. Those are now the run's first two
  statements — a free decider over `git status --porcelain`, then an exit code —
  and each has an arm that reports and stops. The eleven paths of `dead-code` are
  almost all places the corpus says "stop".
* **A guard that is not the author.** `comment-audit`'s verification guide names
  the stakes exactly — "the most damaging failure is declaring a correct comment
  wrong and then 'fixing' it" — and then asks the classifier to guard itself. The
  guard is now `revisingOn` on a different primary, and **the fixes are applied in
  one arm only**: an objection is not a licence to edit, and a guard that declined
  to judge is not an approval.
* **A completion gate with one decidable conjunct.** That skill's step 6 wants zero
  pending *and* a reconciled denominator, and warns against treating the first as
  proof of the second. The extractor prints the first itself, so a decider reads it
  for nothing; the second is a judgment about a heuristic tokenizer's blind spots
  and is one question put to somebody who did no auditing. Two conjuncts, two
  mechanisms, and the file's own warning is now the shape of the program.
* **Three prohibitions that are absences.** `skills/nixos` forbids decrypting the
  SOPS secrets, forbids seizing the `.nixos-build` lock, and requires the host's
  own driver. There is no `sops`, no `rm` and no other build command anywhere in
  `Workflows.Evidence` — and **no prompt in `Workflows.Nix` states any of the
  three**, which is `doc/design.md` §7.4 row 26's ruling honoured rather than
  described.

And one deviation, recorded rather than absorbed: §7.2 row 12 asks for the six
bundle rejections as **six** deciders. They are one, because each of the six is a
judgment about a repository's contents rather than a test on text a command
produced — so the six are the screening question's rubric and one free decider
reads its answer. What the design was actually buying is intact: the test is free
and it fires before any scoring.

### Wave 4, second half: the specialists

```sh
wf cost query ; wf cost expense ; wf cost tron
#   minFold  3, maxFold  8, over 16 paths
#   minFold  4, maxFold 10, over 17 paths
#   minFold  2, maxFold 14, over  9 paths
```

Five rows over five programs, no rungs, and the wave's closing claim is what they
have in common: **each one's read-only or human-gated character is a type rather
than an instruction.**

* `query` contains **no `act` at all**. `query-builder.md` says "never reveal any
  of it" three times in five lines; here there is no database argv anywhere in the
  tree, the schema is a `cat` receipt, and `Agentic.Acp.permissionByCode` grants
  write authority only to an act at `receipt` — so "an SQL query that I can run
  myself" is a property of `wf plan query --raw` and not a sentence in a prompt.
  What it adds on top is the ending the corpus cannot have: a draft opening a line
  with `DELETE `, `DROP ` or `TRUNCATE ` is refused by a free decider for zero
  questions, which is the row's `minFold 3`.
* `expense` and `qanda` put **the owner in binding position**, which is
  `doc/design.md` §7.2 row 14's phrase and is the thing three waves of programs
  had not yet needed. His answer is the loop's *verdict*, so the language reads it
  three ways: an approval settles, an objection is spliced into the correcting or
  folding turn as the only thing it is told, and an **empty answer abandons the
  loop**. That third tag is the one that matters and neither Markdown file has it:
  an unattended run must not be able to read silence as consent, and four of
  `expense`'s six endings build nothing at all.
* `transcribe` and `qanda` price **identically** — `branch, 15 paths, ceiling 8` —
  and that is worth one line, because they are two completely different subjects
  over one shape: a preparatory question, a three-way bounded loop, one artefact.
  A shared shape pricing to the digit is what the library is for.
* `tron` is the row whose *range* is the point: **2 to 14 over 9 paths.** Seven of
  the nine are "a command did not do what this run needed" and each costs 5 or
  less; the 14 is the full differential. `tron-debug.md`'s three `<command>` blocks
  are text addressed to a model, and whether any of them ran is a thing a
  transcript may or may not record — so here the diagnosis node sits at the bottom
  of four nested successes and the sglang control runs *first*. That is §7.2 row
  65's "the differential's diagnosis cannot rest on a run that did not happen",
  expressed as reachability.

Three narrowings in this half are recorded in the module headers rather than
absorbed, and each is a real limit:

* **"One `ask` per decision" is not writable** (§7.2 row 45), because the decision
  count is a run-time value and every bind extends a `W.do` block's scope index —
  so a variable-length chain of binds is not a Haskell program. What is writable is
  `skills/wiggum`'s shape: K rounds, each carrying the whole agenda and the whole
  walkthrough so far. The owner is in binding position once per *round*; what is
  bought is a finite `wf cost qanda` over any agenda.
* **Nothing in `transcribe` or `expense` can see an image**, which is §7.2 row 64's
  own honest limit. An agent-cat question carries text. So the receipt proves and
  names the *files* — `ls` exits nonzero on a missing path and a `text` ask
  abandons on a nonzero exit — and the answering party is an agent with its own
  file-reading tools. An extraction that *invented* a receipt file is caught; one
  that misread a real one is not, and both reports are told which.
* **The mssql MCP is not carried**, and the reason is the row's own claim: a
  program that can reach the data is a program whose read-only character is a
  promise rather than a type. The dialect input's default carries that MCP's
  dialect, which is `fix-integration`'s arrangement (§7.2 row 18) applied to a
  dialect instead of an error string.

One thing this half wanted from the foundation and did not take: **the judge of
`Workflows.Escalation.escalating` is typed `Party 'IsModel`**, so the two loops in
the tree whose judge is a *person* — `expense` and `qanda` — write their
`revisingOn` out by hand instead. The three arms are the same three and the
generalisation is one word in that signature; it is recorded here and in both
module headers rather than made, because the foundation is not this wave's to
widen.

### Wave 5's last row: `wiggum`, and the gate it pays

```sh
wf cost wiggum
#   minFold 2, maxFold 44, over 34 paths
```

That line is the roadmap's own gate for the whole wave (`doc/design.md` §8): **a
finite worst case, printed before the first round.** It is the one number an
autonomous work→checkpoint→verify loop must have and the one
`skills/wiggum/SKILL.md` cannot state — every bound in that file is a word ("a
bounded number of attempts (default 3)", "roughly 3–5 at a time", "every four
hours or so"), and all three are numbers here.

**44 is the second widest ceiling in `ci/workflows.sh`** — past
`retest-categorical`'s 37 and `productize`'s 31, and displaced only by
`wiggum-duet`'s 50, which is this same loop run across two panes — and that is
the right shape
rather than a worrying one: five of the row's seven declared callees belong to
other rows — `commitFn`, `resolveFn`, `cleanupRoundFn`, `fessReportFn`, and the
eleven `fess` stances by way of `Rubrics.Fess` — so what the top of the loop costs
is what the toolbox under it costs. Read it against the **minFold of 2**, which is
the refusal to start: the parent-history sentinel probe did not pass, so no round
ran, nothing was committed and nothing was audited. The two cheapest paths in the
row change the tree not at all.

Four things in it are worth naming, because each is a sentence in the skill that
had nowhere to go:

* **The durable-state section dissolves, exactly as §7.4 row 1 predicted.** The
  frozen plan is a program *input* — which is what makes "never edit the plan or
  the done-criteria to lower the bar" true rather than requested, since no
  question in the program can reach an input — and the handoff is a *handle*,
  assembled from receipts and revised by the bounded verdict loop. The journal is
  `account-halt`'s `journalFn`, which is a different row.
* **"Do NOT submit or push the stack" is an absence.** The skill says it three
  times because it is the one irreversible thing an unattended loop could do.
  There is no `gitPushLease`, no `gh pr create` and no `gt submit` anywhere in
  `Workflows.Wiggum`: the currency step is local, and the prohibition is a command
  that does not exist rather than a rule a tired runner is trusted with.
* **The three endings finally have a caller.** `WORK COMPLETE` / `WORK REMAINS` /
  `WORK BLOCKED` is `Workflows.Escalation`'s vocabulary, transplanted *from this
  skill* in wave 1 and used here for the first time. The exhausted arm yields its
  candidate, which is literally the skill's "report where you are, what you tried,
  and what you need".
* **`run-orchestrator`'s steps 5–6 stop being questions.** "Check task
  dependencies" and "identify tasks that can run in parallel" are, in that file,
  work given to a coordinator model. Here the round's obligations are a
  `[(Text, [Text])]` and `stageWaves` is a layered topological sort over it: zero
  questions, zero paths, and the fan-out cap is *computed* where `parallelize`
  guesses three to five.

Six things stay with the skill and the module header says so in full, because
pretending otherwise would be the manufacture `fess-auditor` exists to catch: the
refresh-after-compaction re-read (a compaction is an event in the harness's
context window and is invisible to a program — what it *demands*, the baseline
verification, is the flag at the top of the run), the durable files themselves,
the working policies (`CARGO_TARGET_DIR`, `~/Products`, `direnv exec .`,
`git-surgeon` — none of them expressible, since `Agentic.Shell` runs an argv with
`proc` and never a shell), "do not enter this mode on your own", the four-hour
clock, and conferring through PAL.

### The seventy-second row: `wiggum-duet`, two panes and one command

```sh
wf cost wiggum-duet
#   minFold 2, maxFold 50, over 34 paths
```

The owner's own ruling, and the shape it asks for: **two `agent-deck` sessions he
primes himself, one `wf run` that starts a work loop in the first and a review in
the second, and no ownership of either.** `wf` is the driver and not the
governor — nothing in the deck transport can start, stop or kill a session, so a
run that finishes leaves both panes attached and his, and the next run picks them
up where they are.

```sh
wf run wiggum-duet --session "$PANE_W" --route "partner=deck:$PANE_R" --poll 250 \
   --input-arg goal='…' --input-arg base=main \
   --input-arg observations= --input-arg parity=
```

**Three of the four numbers are `wiggum`'s to the digit** — `branch`, 34 paths, a
minimum of 2 — because the duet adds one `call` and no branch, and a call is
consultations rather than paths. The one that moves is the ceiling, and it is
exactly the review: four partner seats, one publishing act, one directory
receipt, bought once and only on the two-round arm. `50` is now the widest in the
table.

**What it buys is a judge that provably is not the worker under a transport that
shares one conversation** — which is the combination the old gate had to refuse
outright, and the only combination a two-pane workflow can be. The mechanism is
the fourth run fact: `run.routes` and `run.engine` read together, in ordinary
Haskell, before the program exists. So the refusal is finer than `wiggum`'s and
sharper: it fires when the judge's backend is the backend of **any** of the five
other pins this row reaches, and it fires when the judge's backend is the
**default**, because everything this row does not pin itself — every borrowed
callee, every tool, every person — lands on the default and is work. Writing the
split the other way round is therefore refused rather than accepted, which is the
mistake worth catching: it *looks* like the split. So is routing a borrowed
callee's own pin at the judge's pane (`--route opus=deck:<judge>` beside the
judge's own route), which looks harmless and is the same contamination by another
route.

**What it deletes** is the hand-carried loop the guide used to teach: three
commands and a copy-paste between two invocations become one command and a bind,
and the coupling is priced. **What it does not close** is a one-poll-interval
window in which a message the owner submits while `wf` is waiting on that pane
can be read as `wf`'s own answer. `--poll 250` shrinks it fourfold, the guide
states it plainly, and [`doc/wiggum-two-sessions.md`](doc/wiggum-two-sessions.md)
is where an operator should start.

## Building it

```sh
nix build              # -> ./result/bin/{wf,wf-taskmaster-stage}
./result/bin/wf list
```

That is the whole of a first build: no devShell, nothing installed. The `wf` binary
is the one every command on this page and in
[`doc/cookbook.md`](doc/cookbook.md) is written against; its packaged
`wf-taskmaster-stage` companion is the deterministic gate used only by the
Taskmaster row.

Beyond that there are two build paths, and they answer different questions.

```sh
nix develop            # the devShell: GHC, cabal, HLS
cabal build all        # this package and ../agent-cat root workspace
./ci/workflows.sh      # the gate: 74 rows, priced and run
./ci/taskmaster.sh     # Taskmaster unit, artifact, repair and exhaustion gate
./ci/emacs.sh          # the Emacs gate: compile, checkdoc, smoke over the binary
./ci/cookbook.sh       # the cookbook gate: regenerating doc/cookbook.md is a no-op
```

`doc/cookbook.md`'s per-row sections are **generated** from the help texts by
`./tools/cookbook-gen.sh`; edit the text in the module that owns the row and
regenerate. `ci/cookbook.sh` refuses any difference, which is what keeps the
page and `wf help` from ever saying different things.

```sh
nix flake check
nix build .#default    # the same pinned build, named: agent-cat at the revision
                       # flake.lock names. `nix build` above is this by default
```

> **The pin and the build agree whenever the lock is current.** When
> `flake.lock` names an agent-cat revision carrying everything this tree
> consumes — the one thing this repository cannot supply for itself —
> `nix build .#default` succeeds against it: the
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
> `cabal.project` is a development convenience: it points at `../agent-cat`'s
> *working tree*, which may be ahead of the pin, behind it, or dirty.
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
   package depends on `agentic` and can see neither.)
5. **A rubric over roughly sixty lines is a program input, not a define.** Prompt
   bulk is the corpus's largest avoidable cost.
6. **A roster-shaping input must be total on `""`.** `plan` and `cost` bind the
   empty string for an input nobody gave, so `""` must mean *the default roster*
   and never *no members* — `panel []` is an `error` on a CAF, and the gate prices
   every row with no inputs precisely to catch it.
7. **A row is one shape, never one invocation.** Rungs that differ in roster,
   receipts and price are rows; things that differ only in what `--input-arg` is
   given are not.
8. **Every multi-line string is a fence.** The owner's total ruling of
   2026-08-21: "any multi-line string uses the wft quasi-quoter." Prose is
   written at the fence at reading width; fixtures — bytes some tool or file
   would have produced, standing in for a receipt inside a scripted table —
   are fences too, byte-exact, with the shapes a bare fence cannot carry held
   at the seam: a trailing newline is `[wft|…|] <> "\n"`, a leading space is
   `" " <> [wft|…|]`, and indentation-significant content sets its own margin
   so the common-indent strip removes only the fence's. Zero string-gap
   literals remain in this tree; every conversion was proved byte-equal
   against the literal it replaced. (agent-cat keeps nineteen, each naming a
   mechanism the compiler itself states — a Symbol in a type, a module the
   quoter cannot reach without an import cycle, or the quoter's own module
   under the Template Haskell stage restriction.)
