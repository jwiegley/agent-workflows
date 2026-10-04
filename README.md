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

## Using service mode

Service mode connects the Emacs client of this repository to an agent-cat
workflow manager. The
[agent-cat getting-started guide](https://github.com/jwiegley/agent-cat/blob/main/doc/getting-started.md),
`doc/getting-started.md` in an agent-cat checkout, creates the manager with
`agentic-run --manager init`, starts it and writes its client profile. These
lines then load the client and name that profile:

```elisp
(add-to-list 'load-path "~/src/agent-workflows/emacs")
(require 'wf-service)
(setq wf-manager-profiles '("/path/to/manager-root/client/profile.json"))
```

1. `M-x wf-service` selects the client profile and connects to the manager.
2. `M-x wf-run` asks for a profile and a workflow. It opens the setup form
   for the missing inputs and then shows the exact review of the manager.
3. In the review, `a` asks `Start WORKFLOW in PROFILE (TARGET)?`. A yes
   starts the run and shows its run view, which ends with the Terminal line,
   for example `Terminal: succeeded`. `d` declines the review and discards
   its preparation. `q` asks whether to discard the preparation, so that a
   declined review holds no execution reservation of the manager.
4. `M-x wf-requests` lists the requests of the manager in draft or review
   and opens the review of one. A request that `q` left in review stays
   reachable with this command.
5. `M-x wf-runs` opens the view of a run of the manager. It offers each run
   whose view this Emacs process opened, also after the run ends, and each
   run of the overview of the manager. `M-x wf-history` lists every run of
   the manager by workflow name, and `RET` opens the view of a row.
6. `M-x wf-local` returns to local mode. The runs and requests of the
   manager continue.

Local mode needs no manager. `wf-program` names the runner, `wf` by default.
It can also be `agentic-run` of agent-cat, whose catalogue holds the worked
examples of agent-cat, for example `hello`:

```elisp
(setq wf-program "agentic-run")
```

[Service mode](#service-mode) is the complete reference.

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
    Refocus.hs          scope against the frozen goal (refocus; called by each Wiggum round)
    Hello.hs            the smoke row         (hello)
    HelloWorld.hs       the beginner example  (hello-world)
    Registry.hs         the index: name -> program, blurb, canned table
bin/Main.hs             `wf`, two lines over Agentic.Cli
emacs/wf.el             native setup, prepared runs, controls, history and lineage
emacs/wf-smoke.el       batch contracts, run by ci/emacs.sh
emacs/wf-manager.el     service-mode transport: client profile, credential,
                        exact JSON codec, decoders, sessions, commands and
                        verified downloads
emacs/wf-service.el     service mode of wf.el: profile selection, catalogue,
                        setup, review, run views, answers, controls and the
                        dispatch table of the commands
emacs/wf-manager-tests.el  ERT tests of the transport and of the dispatch table,
                           run by ci/emacs.sh
emacs/wf-manager-live.el   live checks of the transport and of service mode, run
                           by the emacs-client and emacs-client-controls
                           modes of agent-cat
ci/emacs-ui.py          isolated Emacs PTY, resize and window acceptance, the
                        service journey of the emacs-service modes, the
                        service lifecycle of the emacs-service-lifecycle mode
                        and the Emacs client of the three cross-client modes
ci/emacs-tramp.py       loopback SSH/TRAMP, typed controls and lineage acceptance
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

**[`doc/cookbook.md`](doc/cookbook.md) is the per-row guide**: all seventy-five,
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

`emacs/wf.el` is a native workflow client using built-in Emacs buffers, widgets,
completion, keymaps, and process support. The `Package-Requires` header of
`wf.el`, `wf-manager.el` and `wf-service.el` keeps `((emacs "29.1"))` as the
declared minimum, and no check runs Emacs 29.1. Every check of this repository,
local mode, TRAMP and service mode alike, runs GNU Emacs 30.2 on macOS, the
Emacs of the development shell. No check runs another version. The configured
runner must provide the
shared `frontend` preparation service and read-only `frontend-io` queries.
An older runner is refused rather than falling back to an unreviewed launch.

```elisp
(use-package wf
  :load-path "~/src/agent-workflows/emacs"
  :commands (wf-run wf-runs wf-history wf-plan wf-cost wf-help wf-refresh))
```

Without `use-package`, add `emacs/` to `load-path` and autoload the commands:

```elisp
(add-to-list 'load-path "~/src/agent-workflows/emacs")
(autoload 'wf-run "wf" nil t)
(autoload 'wf-history "wf" nil t)
```

| Command | Behavior |
| --- | --- |
| `wf-run` | Discover a workflow, edit inputs, prepare, review, and explicitly start it. |
| `wf-runs` | Reopen a session retained by this Emacs process. |
| `wf-history` | Query persistent history, including corrupt entries and ownership. |
| `wf-plan`, `wf-cost`, `wf-help` | Display the runner's inspection output without executing a workflow. |
| `wf-refresh` | Clear descriptor discovery caches. A prefix argument also refreshes discovery for the inspection and run commands. |
| `wf-restart`, `wf-resume`, `wf-fork` | Prepare a separately owned lineage child and require fresh approval. |
| `wf-export` | Export the verified result of a manager run under a new name. Only service mode has this command. |
| `wf-requests` | List the requests of the manager in draft or review and open the review of one. Only service mode has this command. |
| `wf-lineage-compare` | Display authoritative parent and child records and snapshots. |
| `wf-diagnostics` | Display the diagnostics of the current run view. |
| `wf-service`, `wf-local` | Select service mode with a client profile, or return to local mode (see [Service mode](#service-mode)). |

Configuration uses `wf-program`, `wf-agent-deck-program`,
`wf-confirm-function`, `wf-state-directory`, and, for service mode,
`wf-manager-profiles`. Confirmation defaults to
`yes-or-no-p`. The state directory defaults to
`~/.local/state/agent-workflows` on the workflow's machine.

**Discovery and setup.** Descriptors supply workflow names, descriptions, input
declarations, and capabilities. Completion remains connection-aware, so local
and TRAMP catalogues are not mixed. The setup buffer displays all initial inputs
together, with per-input history and explicit Literal, Multiline, File, Buffer,
and Region sources. A literal beginning with `@` remains literal text.

Use `TAB` and backtab to navigate, `M-TAB` for file completion, and `C-c C-c` to
submit the sources. `C-c C-k` or `C-g` cancels without execution. Multiline fields
accept newlines, while `C-q TAB` and `C-q C-m` insert literal tabs and carriage
returns. Buffer capture reads the explicitly selected buffer's accessible text.
Region capture reads its point-to-mark range. These captures remain unchanged
until edited or explicitly recaptured, and each source retains its draft while
the form is open.

File sources remain paths for the runner to capture. Lisp does not write managed
input snapshots, manifests, or leases. Files from another machine are refused.
The runner captures transport bytes once, applies the declared input decoding,
and retains the prepared program in memory. Source changes after preparation
cannot change the approved execution. Literal values and human answers travel
through private pipes rather than process arguments.

**Target and approval.** Scripted, ACP, Deck, configured routing, and explicit
opaque target arguments remain available. Configured selection uses sanitized
offline routing inspection, including an inherited or explicit persona and
CLI-produced launch arguments. It does not read routing YAML or reconstruct a
routing fingerprint. Explicit target arguments support choices not represented
by configured engines, including declared model overrides.

The review displays the exact prepared plan, consultation bounds, effects,
input hashes, target arguments, and routing policy. Every non-scripted target
carries a provider-charge warning. Approval starts the same prepared process,
not another command assembled from displayed text. Declining discards it.
Changing the setup requires another preparation and review.

**Execution and decisions.** Each run has its own durable ID and independent
session state. Multiple runs of the same workflow can coexist. Killing or
burying a view does not cancel its process, and `wf-runs` can reopen the view.
Output following applies only to windows already at the end.

A live run buffer provides `a` for the oldest verified human question, `c` for
available runtime controls, `C-c C-k` for cancellation, `r` for verified result
content, and `d` for diagnostics. Human and fork answers use native JSON editors.
The verified question of `a` shows in another window. The answer editor opens
in a new window, below the run view when the frame has no room for a pop-up
window. Its close deletes that window and returns to the view.
`C-c C-c` submits an edited value, while `C-c C-k` abandons the editor. Boolean
false is preserved separately from JSON null. The runner remains the authority
for answer types and schemas.

Controls retain occurrence, attempt, and acknowledgement correlation. Human
and recovery decisions preserve FIFO order, and stale or unavailable actions
are refused. Runtime controls are bounded at 1 MiB before a control ID is
reserved. Framing, identity, sequence, trace, and stream failures are reported
rather than treated as successful completion.

**History and lineage.** Persistent history is a native table. `RET` opens the
selected record and `g` refreshes it. Corrupt records remain visible, and a failed
query does not become empty history. Only a matching live session already owned
by this Emacs process can reopen as a live view. Other records open explicitly
as observers, without control commands.

Observer views provide `g` to refresh, `r` for a verified result, `R` for restart,
`S` for resume, `F` for fork edits, and `=` for parent/child comparison. These
lineage operations create new runs. They do not adopt the parent's live control
channel. The backend authenticates and copies parent inputs, validates checkpoint
and effect restrictions, rechecks ownership and inherited answers across approval,
and preserves the parent store. Existing exact program and policy refusals remain
in force. `g` in a live run view still opens fresh root setup rather than claiming
semantic resume or fork.

Artifact content is displayed only after the shared verifier accepts its recorded
reference. A recorded result reference alone is not verified content, and artifact
verification alone proves neither whole-store health nor control ownership.

**Remote execution.** Subprocesses retain TRAMP connection identity and the
workflow's `default-directory`. Native protocol calls use TRAMP direct-async
pipes and separate stderr buffers. Settings are scoped to each call rather than
persistently changing connection profiles or methods. State and input paths are
checked against the selected connection, and unsupported direct-pipe connections
are refused rather than using a terminal for protocol data.

TRAMP refuses a direct-async command that is longer than the remote pipe
buffer, which is 512 bytes on macOS, and its environment prefix uses most of
that buffer. On a remote connection, `wf-program` must therefore name a short
path, such as an installed `~/.local/bin/wf`. The SSH gate runs its runner
through a short link inside its fixture for the same reason.

SSH behavior is verified with Emacs 30.2 against an isolated loopback server on
macOS. This exercises the real SSH/TRAMP path, including binary file capture,
typed human answers, verification, history, semantic resume, cancellation, and
interactive resize. It does not establish a different host OS or Linux acceptance.

**Verification.** The gate compiles every `emacs/*.el` file with warnings
treated as errors, runs strict `checkdoc` on each of them, and executes
descriptor, setup, native process, control, artifact, history, and lineage
regressions. A fourth pass runs the ERT tests of the service-mode transport in
`emacs/wf-manager-tests.el`, which include the events vectors, the drafts,
requests, preparations, receipts, decisions, answers, controls and runs vectors,
and the refresh sequences, backoff, jitter and reconciliation vectors of
`test/manager_client_vectors.json` in agent-cat. The HTTP transport tests and
the session tests run against a plain HTTP listener on 127.0.0.1 inside the
test Emacs and contact no other host. The command tests send an answer whose
connection the listener closes after the request, so that the send is
uncertain. They require exactly one send for each answer and a
reconciliation with one read that gives `effect-observed` or stays uncertain.
The download tests require the exact bytes for the stated size and digest and
a refusal for a wrong digest, a wrong size and an inline disposition. The
service-mode tests require that `wf-service-commands` states each public
command of `wf.el` once, that local mode is the default, and that each
local-only command refuses with its message in service mode and starts no
process and sends no request. The run view tests require the
separate lines of a run view and its Terminal and Result lines, the choices
of `wf-runs` for local and service runs, a view that follows a succeeded run
to the size and digest of its verified download, and a view kill and the
function of `kill-emacs-hook` that send nothing. The answer tests require
the answer `no` as JSON `false` with the entity tag of the decision, a 412
refusal that keeps and reports the draft and sends nothing again, and an
uncertain answer that one read of the run snapshot reconciles. The result
and history tests require the exact bytes of a saved result with mode 0600
and a refusal of a second save to the same file, a history of every page of
the run collection in its order, and a refusal of a history row of another
endpoint that sends nothing. The lineage and export tests require the
decoders of the lineage and export collections and of the export receipt,
the body of a fork with its edits in occurrence order, the fork edits of the
completed and reused occurrences of a snapshot with a refused replacement
read again, one lineage request with the entity tag of its collection
followed by the enqueue of the child, a refusal that sends nothing when the
operation is not eligible, and one export with the entity tag of its
collection, the verified download of the export and the export buffer, and
an uncertain export that one read of its collection reconciles and that is
not sent again. The
human/control fixture and
the vector file are explicit dependencies, not developer-specific paths or
skipped tests. The pinned agent-cat source of the development shell does not
have the vector file, so `WF_MANAGER_VECTORS` names it.

```sh
WF=/path/to/compatible/wf \
WF_CONTROL_RUNNER=/path/to/routing-fixed-point-probe \
WF_MANAGER_VECTORS=/path/to/agent-cat/test/manager_client_vectors.json \
  nix develop path:. -c bash ci/emacs.sh
```

The gate also compiles and checks `emacs/wf-manager-live.el`, and it does not
run it. That file is the live check of the transport against a running
agent-cat workflow manager. The `emacs-client` mode of
`manager/test/service_http.py` in agent-cat starts the manager with its mixed
fixture, issues two client credentials with the scopes `observe`, `submit`,
`control` and `export` and their client profiles, writes a third profile whose
endpoint has no listener, and runs the file in a batch
`Emacs -Q` with an isolated home directory. The mode needs `EMACS` and
`WF_EMACS_DIR`, the `emacs` directory of this repository. From the root of
agent-cat:

```sh
EMACS=/path/to/emacs WF_EMACS_DIR=/path/to/agent-workflows/emacs \
  python3 -B manager/test/service_http.py "$PWD" "$(mktemp -d)" \
  "$(bash test/cabal.sh list-bin -ftui-tests routing-fixed-point-probe)" 8 emacs-client
```

The live check binds a transport over TLS with the CA file of the profile,
creates a draft and repeats the creation with the same idempotency key, and
supplies a literal input with a set-input command and repeats the command with
the earlier entity tag. It then creates three more drafts, each with a literal
of 600000 characters, so that the overview does not fit on one page. It
starts a session, which assembles the overview over all its pages, and asks
the harness to create and approve a run with the credential of the harness.
The run must appear in the overview of the session through an event poll,
with no other read by the check, and the delivery state must be `poll`. The
check then switches the session to a profile whose endpoint has no listener,
which must fail and keep the binding and its follow loop. It then switches the
session to the profile of a second credential of the same manager while the
delivery of a read of the first binding is delayed. The switch must commit
with a new endpoint identity, every member reference of the new overview must
read 200, the delayed read must change nothing, and a reference of the first
binding must give `wf-manager-wrong-endpoint`. The check then reads after the
harness revokes the second credential, kills a buffer that holds a reference of
the session, and closes the session. It requires 201 and the same draft for
the repeated creation, the typed refusals 412 `stale-revision` and 401
`unauthenticated`, the end of the follow loop with `refused` after the
revocation, no prompt, and no process, url.el buffer, timer or transport
directory after the close. The harness then reads that the run has not ended
and that the check sent no command after the run handshake, and it drives the
run to its terminal success. A new session of the first credential then sends
the export command of the run with the entity tag of its export collection
and reads the receipt at the Location of the 202 reply until it reaches
`effect-observed`. The harness reads the same receipt. The session downloads
the artifact of the export with the verified download, and the harness
requires the same bytes as its own download. A download with a wrong digest
and a download with a wrong size must each give
`wf-manager-invalid-response`. The service step then drives service mode with
keyboard macros through `execute-kbd-macro`, with the first profile as the
one item of `wf-manager-profiles`. `M-x wf-service` connects, and `M-x wf-run`
lists the ready profiles and then the catalogue in `*Completions*`, which the
check keeps with a key of its own. The harness requires exactly the ready
profiles and the workflow names that it reads, and the refusal of `wf-run`
after the selection. `M-x wf-help` must show the help text of the catalogue.
Each local-only command must refuse with its message and start no process and
send no request. `M-x wf-diagnostics` must show the endpoint, the scopes and
the delivery state `poll`, and `M-x wf-local` must close the session. The
requests step creates, sets up, reviews and approves or declines three
requests with keys, and the harness reads that the programs of the two
approved runs received their literal and captured inputs. The manager admits
at most 30 ordinary mutations of one client in one minute, so the views step
starts one minute after the pages step. The views step
starts one `mixed-controls` run of each of the two profiles of the fixture
and opens the view of each run with `M-x wf-runs`. While the answer editor of
the second run is open, the harness answers its question first, so the
answer of the view must receive 412 `stale-revision`, send nothing again and
keep the draft. The answer `no` in the view of the first run must reach its
decision, and the harness reads JSON `false` in the run store. Each view must
show only its own run. The check then kills the view of the second run while
that run still waits at its recovery decision. The harness reads that the run
still runs, that no cancel command exists and that the check sent no command
after the kill, and it then drives both runs to their terminal success. The
view of the first run must end with the Terminal line and the Result lines of
the verified result that the harness downloads, and the function of
`kill-emacs-hook` must close the transport with no command. The
mode also fills a local retention root with 300 legacy entries, which the
manager serves through `--legacy-history`, and issues a third credential. The
history step lists every run with `M-x wf-history`, and the harness requires
the run identifiers of every page of `/v1/runs`, over at least two pages and
in the order of the collection. `RET` on the row of the answered run opens its
view, and `r` there saves the verified result to a new file. The harness
requires the bytes, the size and the SHA-256 digest of its own download and
the mode 0600, and a second save to the same file must refuse. After the
switch of the session to the profile of the third credential, `RET` on the
same row must refuse, and no read and no view of the run may follow on the
new binding. Before the history step, the lineage step creates lineage
children with keys: `M-x wf-restart` on the history row of the literal run, `S`
and `g` in the view of the captured run, and `F` in the view of the restart
child, which replaces the answer of its first completed text occurrence. Each
child opens its exact review, which shows its lineage, and its run starts only
after `a` and the answer `yes`. The harness reads the lineage collection of
each parent, the child request, its consumed preparation with the lineage of
its review and the succeeded child run, which names its parent and its
operation. The step then exports the verified result of the answered run with
`M-x wf-export`, and the harness requires the published export and the bytes
of its own download. The
check writes a report whose `harnessVersion` field is
`wf-manager-live-harness-version`. The mode refuses a report of another
version with one sentence, so a mismatched pair of the two repositories fails
at once. The mode then checks the report against the reads of the manager.

The `emacs-client-controls` mode runs the second test of the file,
`wf-manager-live-controls`, in the same way:

```sh
EMACS=/path/to/emacs WF_EMACS_DIR=/path/to/agent-workflows/emacs \
  python3 -B manager/test/service_http.py "$PWD" "$(mktemp -d)" \
  "$(bash test/cabal.sh list-bin -ftui-tests routing-fixed-point-probe)" 8 emacs-client-controls
```

The mode starts the manager with the deterministic ACP control fixtures and
issues one client credential with the scopes `observe`, `submit` and
`control`. The harness creates and approves a run whose attempt holds its turn
until a steer and a run whose first candidate holds its turn until a redirect.
The check opens the view of each run with `M-x wf-runs` and starts each control
with `c` in the view. The choices that `*Completions*` lists must equal the
labels of `wf-service-control-read`. The check sends the steer through the
steer editor with the timing `interrupt-now`, and then the live redirect to
the spare target. The harness confirms both from the command receipts, the
run log and the run store, and settles both runs. It then starts a run of the
retry fixture, which it answers to its recovery decision, and a second held
run. The check sends the offered retry, and that run must end with
`Terminal: succeeded` in its view. In the view of the held run, `C-c C-k` and
the answer `no` must send nothing. The check then chooses `cancel` and answers
`yes`, the runtime acknowledgement must accept the cancel, and the view must
show `Terminal: cancelled`. The harness requires that the steer, the redirect,
the retry and the cancel are the only commands of the controls of the four
runs, each sent once with the entity tag of the controls as `If-Match`.

`EMACS` can select another Emacs executable. Otherwise the gate uses the pinned
development shell, which also supplies `WF_CONTROL_ADAPTERS` from the pinned
agent-cat source. Scripted workflows and deterministic human and ACP fixtures
exercise the real runner without contacting providers, including retry,
abandonment, dispatch redirection, and failover through the native controls.

The reproducible local PTY gate is:

```sh
WF=/path/to/compatible/wf \
WF_CONTROL_RUNNER=/path/to/routing-fixed-point-probe \
  nix develop path:. -c python3 ci/emacs-ui.py --artifacts /path/to/new/artifacts
```

This gate runs isolated `Emacs -Q` sessions. It covers four-input navigation at
40×12, 80×24, and 140×36, resizing during setup and review, typed human answers,
verified results, persistent observer/fork navigation, independent multiwindow
following, and terminal restoration. Recovery cases use a preconfigured
deterministic ACP target and drive retry, dispatch selection, and failover
through the native control menu with real keystrokes. Typed control names
survive terminal resizing before submission. Captured native window states and
terminal logs remain with the artifacts. These local checks do not establish
remote or Linux acceptance.

With `--service PROFILE REPORT`, the script runs only the service journey of
`wf-service.el` against a running agent-cat workflow manager. PROFILE is a
client profile file, and REPORT is the file of the JSON report of the journey.
The `emacs-service` and `emacs-service-broken-answer` modes of
`manager/test/service_http.py` in agent-cat start the manager with the mixed
fixture, issue the client credential and its profile, and run this journey.
These modes need `EMACS`, `WF_EMACS_DIR` and `WF_EMACS_UI`, the path of this
script. From the root of agent-cat:

```sh
EMACS=/path/to/emacs WF_EMACS_DIR=/path/to/agent-workflows/emacs \
WF_EMACS_UI=/path/to/agent-workflows/ci/emacs-ui.py \
  python3 -B manager/test/service_http.py "$PWD" "$(mktemp -d)" \
  "$(bash test/cabal.sh list-bin -ftui-tests routing-fixed-point-probe)" 8 emacs-service
```

The journey starts `Emacs -Q -nw` at 80×24 in a private PTY with its own
home directory, loads `wf.el`, `wf-manager.el` and `wf-service.el`, and acts
only by keys. `M-x wf-service` selects the profile. `M-x wf-run` chooses
`mixed-controls`, the Unicode literal of the script is typed in the setup form,
and `C-c C-c` submits it. `a` and the answer `yes` approve the exact review,
and `M-x wf-runs` opens the run view. The journey acts on the decision heads in
the order that the manager presents them: `a` opens the answer editor of the
question, where the answer of `--service-answer` (`false` by default) is typed
and sent, and `c` sends the offered `retry` of the recovery decision. After the
view shows terminal success and the verified result, `r` saves the result to a
new file. `M-x wf-local` closes the session, and `C-x C-c` ends Emacs. The setup
form, the review and the answer editor each pass through 40×12, 140×36 and
80×24, and each keeps its text. The script prints one PASS line for each step
and writes the report again after each step. The report holds the literal, the
texts at each size, the review, the run, the handled heads, the last lines of
the view, the path of the saved file, and the terminal attributes before the
start of Emacs and after its exit. The modes check the report against the reads
of the manager. The `emacs-service-broken-answer` mode passes
`--service-answer true`, and it must fail with the literal message
"JOURNEY-ASSERT Emacs answer is JSON false".

With `--service-case lifecycle`, the script runs the service lifecycle
instead. The `emacs-service-lifecycle` mode of `manager/test/service_http.py`
runs it against a manager whose profiles `profile_1` and `profile_2` hold each
engine turn for some seconds and whose profile `profile_steer` offers a steer.
The lifecycle starts `Emacs -Q -nw` at 140×36 and acts only by keys:

1. At 140×36, `M-x wf-run` creates and approves a `delayed-person` request of
   `profile_1` and one of `profile_2`. The person question of this workflow
   follows the engine answer, so it arrives late. `M-x wf-runs`, `C-x 1` and
   `C-x 2` show the two run views in two windows. The window of the first run
   keeps its point at the start, and the window of the second run keeps its
   point at the end. When the question of the first run arrives, `a` in its
   window opens the answer editor below it, and `false` is typed and sent.
   The first run succeeds while the second run runs, and both windows keep
   their points.
2. At 80×24, text is typed in the editor buffer `wf-capture`, and `M-x wf-run`
   creates a `captured-input` request of `profile_steer`. In the setup form,
   backtab, `RET` and `3` select the Buffer source, which captures that
   buffer. `C-c C-k` and the confirmation `yes` then cancel the second run,
   and `c` in the view of the captured run sends the offered steer with the
   timing `interrupt-now` through the steer editor. The label of the steer
   choice is typed in the open control prompt, which passes through 40×12,
   140×36 and 80×24 with the label kept before `RET`. The steer text is typed
   in the steer editor, which passes through the same sizes with the text
   kept before `C-c C-c`.
3. At 40×12, `M-x wf-history` lists the runs over every page, `RET` on the row
   of the first run opens its view, and `r` saves its verified result to a new
   file.
4. At 80×24, `F` in the view of the first run makes a fork child. The edit
   prompt selects the occurrence of the person question and the action
   `replace`, `yes` replaces the published answer in the replacement
   minibuffer, and `send` sends the fork. `a` and `yes` approve the exact
   review of the child. `R` in the view of the second run makes a restart child
   in the same way. `M-x wf-history` and `RET` on the row of the fork child
   open its view, because the fork child can end before the overview names
   it. When the fork child has succeeded, `E` in its view exports its verified
   result under a typed name, and the export buffer shows the receipt, the
   verified download and the export collection.
5. The view of the restart child waits at its question. The script asks the
   harness to stop the manager and then to start it again, through files in
   the directory of `--service-handshake`. With no key, the view reports the
   delivery `unreachable`, and then it reconnects and shows the supervision
   `lost` of the restarted manager.
6. `M-x wf-run` creates and approves a third `delayed-person` run. When its
   view shows its question, `C-x C-c` quits Emacs. A new `Emacs -Q -nw` with a
   new home directory selects the same profile, and `M-x wf-runs` opens the
   view of the waiting run, which shows its question and the supervision
   `owned`. `C-x k` kills that view, `M-x wf-local` closes the session, and
   `C-x C-c` ends Emacs.

The report holds the runs, the window points and view lines of step 1, the
captured request, the cancel and steer facts, the texts of the control prompt
and the steer editor at each size, the history rows, the path of the
saved file, the lineage children, the export buffer, the view lines around the
restart, the waiting run and the terminal attributes of both Emacs processes.
At each handshake, the harness records the commands of the manager. The mode
checks each step against the reads of the manager, the command receipts, the
coordination database and the run logs. It requires that the reconnect sends
no command again and that the quit of Emacs and the kill of a view send no
command.

With `--service-case controls`, the script sends three run controls from the
view of a run instead. The `emacs-service-controls` mode of
`manager/test/service_http.py` runs it against a manager with three profiles:
`profile_1`, whose recovery decision offers a retry and an abandon,
`profile_route`, whose recovery decision also offers the fail-over to the
spare candidate, and `profile_live`, whose question has two model candidates.
The harness creates, approves and settles each run, and it names each run
through a file in the directory of `--service-handshake` when the run is
ready. The script starts `Emacs -Q -nw` at 80×24 and acts only by keys:

1. `M-x wf-service` selects the profile.
2. `M-x wf-runs` opens the view of the `profile_route` run at its recovery
   decision. `c` opens the control prompt, the label `failover:1` is typed,
   and `RET` sends the fail-over choice. The harness confirms the command and
   settles the run, and the view shows terminal success.
3. In the same way, `c`, the label `abandon` and `RET` send the abandon choice
   in the view of the `profile_1` run, and the view shows the terminal status
   `failed`.
4. The harness answers the person question of the `profile_live` run, so that
   the dispatch window of its model question has no question head before it.
   `c`, the `redirect:N` label of the second listed target and `RET` send the
   redirect to that target, and the view shows terminal success.
5. `M-x wf-local` closes the session, and `C-x C-c` ends Emacs.

The report holds, for each control, the choices of the control prompt, the
text of the minibuffer when the prompt opened and with the typed label, and
the last lines of the view. It also holds each command that the session sent,
with its resource, its body, its If-Match and the entity tag of the read of its
resource in the act of the control. The mode checks each control against the
command receipts, the coordination database, `events.ndjson` and the run log,
and it requires that the session sent only these three controls, each once.

Emacs takes part in the three modes of the cross-client witness of
`manager/test/service_http.py`: `cross-client`, with its control
`cross-client-broken-answer`, `cross-client-lifecycle` and
`cross-client-lineage`. In each mode the TUI, Pi and Emacs act on one
manager, each with its own credential and client identifier. The witness is
local single-machine evidence. The manager, the three clients and the harness
run on one machine, so the witness is not evidence of clients on other
machines.

With `--service-case witness`, the script is the Emacs client of the
cross-client witness. The `cross-client` mode of
`manager/test/service_http.py` runs it against one manager with three client
credentials, one for each of the TUI, Pi and Emacs. The TUI creates and
enqueues a `mixed-controls` request by keys, and Pi approves its exact
review. When the run waits at its person question, the harness names the run
and the question through a file in the directory of `--service-handshake`.
The script starts `Emacs -Q -nw` at 80×24 with the client profile of the
Emacs credential and acts only by keys:

1. `M-x wf-service` selects the profile.
2. `M-x wf-runs` opens the view of the run, and the view shows the pending
   question as its head.
3. `a` opens the answer editor of that head, and the script types `false`.
   The handshake `open-answer` gives the harness the view lines, the editor
   text and the commands of the session. The harness answers it after Pi
   has answered the same head and that answer has reached its effect.
4. `C-c C-c` sends the open editor once. The manager refuses the answer, and
   the session records the refusal as its problem and shows it in
   `*Messages*`. The editor keeps its text, and for three seconds the
   session sends nothing more.
5. The handshake `save-result` gives the harness the refusal and the
   commands of the session. The harness answers it with the path of a new
   file after the TUI has sent the offered retry and the run has succeeded.
   `M-x wf-runs` opens the view of the run again, which shows terminal
   success and the SHA-256 of the verified result, and `r` saves that
   result to the path.
6. `M-x wf-local` closes the session, and `C-x C-c` ends Emacs.

The report has version 3. It holds the process identifier of Emacs, the
lines of the view, the refusal, the commands of the session and the saved
path. The mode requires that the session sent only the one refused answer,
that the coordination database holds no command of the Emacs credential,
that the one answer of the head is the answer of Pi, and that the saved file
has mode 0600 and holds exactly the bytes of the verified download of the
harness.

With `--service-case witness-lifecycle`, the script is the Emacs client of
the `cross-client-lifecycle` mode of `manager/test/service_http.py`. Pi
creates, enqueues and approves a `mixed-controls` request, and the TUI
observes the run. The script starts two `Emacs -Q -nw` processes in turn, each
at 80×24, and acts only by keys:

1. In the first Emacs, `M-x wf-service` selects the client profile of
   `--service`. The handshake `observe-ready` names the run and its pending
   person question.
2. `M-x wf-runs` opens the view of the run, which shows the question as its
   head under the supervision `owned` with the `cancel` choice.
3. The handshake `quit` gives the harness the lines and the choices of the
   view and the commands of the session, and `C-x C-c` quits Emacs while the
   run waits.
4. The handshake `quitted` gives the harness the exit status and the
   terminal state of the first Emacs. The harness rotates the Emacs
   credential, restarts the manager with the termination signal, and
   answers with the client profile of the rotated credential. In the second
   Emacs, `M-x wf-service` selects that profile.
5. `M-x wf-runs` opens the view of the run again, which shows the supervision
   `lost`. The handshake `reconnected` gives the harness the lines and the
   choices of the view, and the harness answers it with a second run and
   its pending person question.
6. `M-x wf-runs` opens the view of the second run, which shows the question
   as its head under the supervision `owned`. The handshake `held` gives the
   harness the view, and the harness kills the manager with SIGKILL.
7. With no key, the view reports the delivery `unreachable`. The handshake
   `unreachable` gives the harness the view, and the harness starts the
   manager again.
8. With no key, the view reconnects and shows the supervision `lost` and
   `Offers: none`. The handshake `quarantined` gives the harness the lines
   and the choices of the view. The harness releases the quarantined
   reservation of the second run and answers with a third run and its
   pending person question.
9. `M-x wf-runs` opens the view of the third run, `a` opens the answer editor
   of the head, the script types `false`, and `C-c C-c` sends it once. The
   handshake `answered` gives the harness the commands of the session, and
   the harness answers it after the run has succeeded.
10. `M-x wf-local` closes the session, and `C-x C-c` ends the second Emacs.

The report has version 2. It holds the process identifiers of the two Emacs
processes, the lines and the choices of each view, the commands of each
session and the exit status and terminal attributes of each Emacs. The mode
requires that the first session sent no command, that the views after each
restart offer no cancel, that the view of the second run sent nothing
across the manager loss, and that the one answer of the second session is
from the rotated credential.

With `--service-case witness-lineage`, the script is the Emacs client of the
`cross-client-lineage` mode of `manager/test/service_http.py`. The harness
settles two parent runs, the TUI forks the first parent with one
replacement, and Pi approves the exact review of the fork child. The script
then starts `Emacs -Q -nw` at 80×24 with the client profile of the Emacs
credential and acts only by keys:

1. `M-x wf-service` selects the profile. The handshake `lineage-ready` names
   the parent run and the run of the fork child.
2. `M-x wf-history` lists every page of the runs.
3. `RET` on the row of the parent opens its view, which shows `Lineage:
   root` and terminal success.
4. `M-x wf-history` again and `RET` on the row of the child open its view,
   which shows `Lineage: fork of run PARENT`, terminal success and the
   SHA-256 of the verified result.
5. `M-x wf-local` closes the session, and `C-x C-c` ends Emacs.

The report has version 1. It holds the process identifier of Emacs, the runs
and the pages of the history, the lines of the two views, the commands of the
session and the exit status and terminal attributes of Emacs. The mode
requires that the history rows equal every page of `/v1/runs` in order, that
the session sent no command, and that the SHA-256 of the child view is the
SHA-256 of the verified download of the harness.

The SSH/TRAMP gate starts an unprivileged server bound only to `127.0.0.1`,
with temporary host and client keys, strict host-key checking, public-key-only
authentication, and a private shell environment. It changes no account or
system configuration and removes the server and temporary keys afterward.

```sh
WF_CONTROL_RUNNER=/path/to/routing-fixed-point-probe \
  nix develop path:. -c python3 ci/emacs-tramp.py --artifacts /path/to/new/artifacts
```

### Service mode

`emacs/wf-service.el` connects the commands of `wf.el` to an agent-cat
workflow manager. The mode is explicit, and local mode is the default.

```elisp
(require 'wf-service)
(setq wf-manager-profiles '("/Users/me/.config/agent-cat/client-profile.json"))
```

`wf-manager-profiles` is a list of client profile files of version 1 (see
[Service-mode transport](#service-mode-transport) for the format). The list alone does not
select service mode. `M-x wf-service` reads one profile of the list, binds a
connection to its manager by `GET /v1/capabilities`, and starts a session. The
session installs the complete overview and follows the events of the manager
in the `poll` delivery. A failure leaves local mode in place and names its
cause. When service mode already has a session, `wf-service` switches that
session to the endpoint of the selected profile, and a switch that fails keeps
the earlier binding. `M-x wf-local` closes the session and returns every
command to local mode. The close sends no command, so the runs and requests of
the manager continue.

The delivery of service mode is `poll`. url.el gives a response to its caller
only when the response is complete, so the client reads `/v1/events` in the
bounded polling mode and never as server-sent events (see
[HTTP transport](#http-transport)). `wf-diagnostics` and each service run view
show the delivery state, which is `poll` while the batches arrive and
`unreachable` while they fail.

In service mode, `wf.el` never starts the `wf` binary or a local frontend
worker and never reads a file system path of the manager. Each public command
of `wf.el` then runs the behavior that the table `wf-service-commands` states
for it:

| Command | Behavior in service mode |
| --- | --- |
| `wf-run` | Read the ready profiles of `/v1/profiles` and ask for one, with its workspace and target labels. Then read the catalogue of `/v1/workflows?profileId=` for that profile and ask for one workflow through the completion of `wf--read-row`, with its price and blurb. Each read is fresh, so the prefix argument changes nothing. The command then creates a request, opens its setup form, enqueues it and shows its exact review (see [Service setup and review](#service-setup-and-review)). |
| `wf-help` | Read a profile and a workflow as `wf-run` does, and show the help text of the catalogue item in the buffer `*wf help: PROFILE/WORKFLOW*`. |
| `wf-diagnostics` | Show the buffer `*wf service diagnostics*`: the profile file, the endpoint, the endpoint identity, the authority epoch, the scopes, the profiles of the credential, the delivery state, the generation, the number of polling batches, the state of the follow loop and the last problem. |
| `wf-runs` | Ask for one local session of this Emacs process, with the label `local:RUN — DIRECTORY`, or one run of the manager, with the label `service:RUN`, and open its view. The service runs are the runs whose view this Emacs process opened at the endpoint of the session, also after they leave the overview, the runs of the open service run views and the runs of the installed overview (see [Service run views and answers](#service-run-views-and-answers)). When no run is known, the message names `M-x wf-history`, which lists every run of the manager. |
| `wf-answer` | Answer the head decision of a run of the manager in the answer editor. In a service run view, the run is the run of the view. Elsewhere, the command asks for one run with a pending decision of the installed overview. |
| `wf-refresh` | In a setup form of service mode, read the request of the form again and draw the form again with every draft. Elsewhere, show a message and send nothing, because service mode keeps no row listing. |
| `wf-control` | Send one control of a run of the manager that the controls of the run offer (see [Service controls](#service-controls)). In a service run view, the run is the run of the view, and in a service history of the endpoint of the session, it is the run of the row at point. Elsewhere, the command asks for one run that the session knows. |
| `wf-kill` | Cancel a run of the manager after a confirmation, when its controls allow a cancel. The run is chosen as for `wf-control`. |
| `wf-result` | Save the verified result of a run of the manager to a new file (see [Service results and history](#service-results-and-history)). The run is chosen as for `wf-control`. |
| `wf-history` | List every run of `/v1/runs` over every page in a new buffer `*wf service history*` of `wf-service-history-mode` (see [Service results and history](#service-results-and-history)). |
| `wf-history-refresh`, `wf-history-open` | In a service history buffer, read the run collection again, or open the run view of the row at point. Elsewhere, refuse with a message. |
| `wf-restart`, `wf-resume`, `wf-fork` | Create a restart, resume or fork child request of a run of the manager and show its exact review (see [Service lineage and exports](#service-lineage-and-exports)). |
| `wf-rerun` | Create a restart child request of a run of the manager, as `wf-restart` does. |
| `wf-fork-submit` | Refuse with the message "wf-fork-submit works only in local mode.  In service mode, use `wf-fork` instead". |
| `wf-plan`, `wf-cost` | Refuse with the message "COMMAND works only in local mode.  In service mode, use the review of `wf-run` instead". |
| `wf-lineage-compare`, `wf-observer-result`, `wf-observer-refresh` | Refuse with the message "COMMAND works only in local mode.  Service mode has no equivalent". |

A command of service mode reads each resource that it needs when it runs. A
read that the manager refuses with 429 `storage-quota` or 503
`storage-unavailable` is read again after 0.2 seconds, for at most 50 reads in
all. The manager gives 429 `storage-quota` to a client that already holds
two active page sets. Such a refusal clears without a change of the
resource, when another page set of the client completes or expires. A read is never a command, so nothing is
sent again.

No refusal starts a process or sends a request. `wf-requests` of
`wf-service.el` lists the requests of the manager in draft or review and
opens the review of one (see [Service setup and review](#service-setup-and-review)).
Local mode has no requests, so `wf-requests` refuses there. `wf-export` of
`wf-service.el` exports the verified result of a run of the manager (see
[Service lineage and exports](#service-lineage-and-exports)). Local mode has no
export, so `wf-export` refuses there. The dispatch is global: in
service mode, a command acts on the manager also in the view of a local run.
`wf-local` gives such a view its local commands again.

#### Service setup and review

In service mode, `wf-run` follows these steps after the selection of a
workflow:

1. It creates a request of the workflow with `POST /v1/requests`.
2. It opens the setup form of local mode, `wf--setup-mode`, with the same
   widgets, keys, sources and histories, for the missing inputs of the
   request. The header of the form names the request and its admission, and
   it states that Submit sends each input to the manager. The
   Literal and Multiline sources send the exact text of the input with
   `set-input`. The File, Buffer and Region sources upload exact UTF-8 bytes
   with `POST /v1/captures?requestId=ID` as `application/octet-stream`, and
   `set-input` then binds the identifier of the capture. The File source
   reads the bytes of a file of `default-directory`. The manager receives the
   bytes and never a file name. Each `set-input` binds the entity tag of a
   read of the request. `M-x wf-refresh` in the open form reads the request
   again and draws the form again, and every draft of every source and the
   position of point stay. A cancel of the form leaves the request a draft of
   the manager.
3. It enqueues the request and reads it until its preparation exists. Each
   change of the admission shows as a message with the phase, the admission
   state, the queue position and the blocking reasons.
4. It reads the preparation with `GET /v1/preparations/{id}` and shows it in
   the buffer `*wf review: REQUEST*` of `wf-service-review-mode`.

The review buffer shows the review of the manager, not a plan of this
client. It shows the admission lines of the wait, the current queue position
and blocking reasons, every approval selector (`reviewDigest`,
`requestRevision`, `profileRevision`, `descriptorRevision` and
`processGeneration`), the entity tag that `approve` binds as `If-Match`, and
every consent fact of the review: the program digest, the person answering,
the workflow, the profile, the workspace, the target, the policy, the result
code, the size and SHA-256 digest of each input, the plan, the run facts, the
pins, the warnings and the lineage. Nothing is shortened. The workflow line
names the workflow by the name of its plan, with its identifier. When the
plan is a JSON object, a plan summary states its workflow, level, size,
question count, price and observation codes above the raw program, which
is the exact plan text of the manager. The keys are these:

| Key | Behavior |
| --- | --- |
| `a` | Ask `wf-confirm-function` with the prompt `Start WORKFLOW in PROFILE (TARGET)?`. The selectors and the entity tag stay in the buffer. Only a yes sends `approve` with the five selectors and the entity tag of the preparation as `If-Match`. The buffer then waits for the run of the request, names it and shows the service run view of the run in another window. A no sends nothing, and the request stays in review. |
| `d` | Decline the review: send `discard` to the preparation and wait for its effect. The request is a draft again, and the preparation holds no execution reservation. |
| `w` | Send `withdraw` to the request and wait for its effect. |
| `g` | Read the request and the preparation again and draw the review again. |
| `q` | Quit the window. When the review sent no `approve`, `discard` or `withdraw`, ask `wf-confirm-function` whether to discard the preparation first. A yes sends the `discard` of `d`. A no sends nothing, and the request stays in review, where `wf-requests` opens it again. |

`M-x wf-requests` reads every page of `/v1/requests` and asks for one
request in the phase `draft`, `queued`, `preparing` or `review`. The
requests in review come first, then the preparing and queued requests,
then the drafts. Each choice has the label `WORKFLOW/REQUEST`, with the
workflow name of the catalogue of the profile of the request, and an
annotation with the profile, the phase and the admission. A request in review opens its exact review at once, and a
queued or preparing request opens it when its preparation exists. A draft
first opens the setup form for its missing inputs, and the command then
enqueues it as `wf-run` does. A request in another phase is not listed.

Each command is sent one time. A command whose outcome is uncertain stops
with a message, and nothing is sent again.

#### Service run views and answers

A service run view is the buffer `*wf service run RUN*` of
`wf-service-run-mode`, a mode derived from `wf-run-mode` with the same keys
and `E` for `wf-export`.
`wf-runs` opens it, and so does the approval of a review. The view is keyed
by the endpoint identity of the session
and the run identifier, so each window follows its own run, and a second open
of the same run selects the same view. The session watches four resources of
the run: `/v1/runs/{id}`, `/v1/runs/{id}/snapshot`, `/v1/runs/{id}/control`
and the decision queue `/v1/decisions?runId={id}`. Each read that the session
installs draws the view again. A read that fails keeps the last complete
observation in view, and the observation line names the failure. Each draw
keeps the point of each window of the view: a window at the end follows the
new end, and every other window keeps its position. So two windows can follow
two runs, each with its own point. The answer editor and the steer editor
open in a new window, below the selected window when the frame has no room for
a pop-up window. The close of an editor deletes that window, so an editor
never takes the window of another view.

The view shows these lines in order:

1. The run and its workflow.
2. The lineage of the run. A lineage child shows `Lineage: OPERATION of run
   PARENT`, for example `Lineage: fork of run run_20`, and a root run shows
   `Lineage: root`.
3. The endpoint identity, the delivery state and the freshness of the
   observation.
4. The runtime status of the snapshot, the supervision and the verification
   of the run, each on its own line.
5. The pending decisions of the queue, with the head first. A question line
   names its code and its prompt, and a recovery line names its gap, its
   message and its choices.
6. The offered controls, with `cancel` when the controls allow a cancel.
7. The Terminal line and the Result lines. A run that has not ended shows
   `Terminal: not yet` and no result. A succeeded run whose snapshot names a
   referenced or verified result reads the outputs of the run, downloads the
   verified result once with the verified download of the session, and shows
   its size and SHA-256 digest. The view keeps only the size and the digest.

`a` in the view runs `wf-answer`. The command reads the decision queue of the
run, the head decision and the controls of the run. It refuses a recovery
head and a head for which the controls offer no answer, and it sends nothing
then. It then opens `wf--answer-editor`, the answer editor of local mode,
with the kept draft of the decision, or empty. The header line names the
decision, its code and its prompt. `C-c C-c` sends the typed text:

- `wf-manager-answer-value` gives the typed JSON value, so the answer `no` to
  a flag question is JSON `false`. Text that the code does not accept is
  refused before any send, and the editor keeps the text.
- The answer binds the entity tag of the decision read as `If-Match`. Before
  the send, the command reads the controls and, for an answer that the run
  snapshot stores, the snapshot, as `wf-manager-session-answer-reconciliation`
  states.
- A 412 `stale-revision` refusal keeps the draft and reports it with one
  read of the decision: the decision is still the pending head, and
  `wf-answer` opens the editor again with the draft, or it is no longer the
  head, and the draft is not sent. The editor stays with its text, and a
  second `C-c C-c` in it refuses and sends nothing.
- An uncertain send is reconciled one time with `wf-manager-session-reconcile`,
  and it is never sent again. Only an observed effect closes the editor and
  forgets the draft.

The kill of a run view stops the watches of its resources and sends no
command, so the run continues. The kill of any other buffer, the answer editor
included, sends no command. The function `wf-service--kill-emacs` of
`kill-emacs-hook` closes the session and its transport and sends no command.

#### Service results and history

`r` in a service run view runs `wf-result`. The command reads the outputs of
the run with `GET /v1/runs/{id}/outputs` and selects the result whose
verification is `verified` and names its artifact. It downloads that artifact
with the verified download of the session, which requires the stated size and
SHA-256 digest. It then asks for the name of a new file and saves the exact
bytes there, with no coding conversion and with mode 0600. The creation is
exclusive: when the file exists, a directory included, the save refuses and
the file stays as it is, so a second save to the same file refuses. A run
with no verified result refuses. The command sends no command to the
manager.

`M-x wf-history`, and `H` in a service run view, open a new buffer
`*wf service history*` of `wf-service-history-mode`. The buffer lists every
run of `/v1/runs` over every page of the collection, in the order of the
collection, managed runs and legacy entries alike. The columns are the run,
the workflow, the profile, the runtime status, the supervision, the lineage
and the verification of the result. The workflow column shows the name of
the workflow in the catalogue of the profile of the run. A workflow that the
catalogue does not list shows its identifier. A legacy entry has the supervision
`observer (legacy entry, read only)`. The keys are these:

| Key | Behavior |
| --- | --- |
| `RET` | Read the run of the row with the reference that the row keeps, and open the service run view of the run. |
| `g` | Read every page of `/v1/runs` again and draw the rows again. |

Each row keeps the reference of its run on the binding that listed it. After
a switch of service mode to another endpoint, `RET` on such a row refuses
with `wf-manager-wrong-endpoint` and sends nothing, and `g` refuses and reads
nothing. A row is never opened on another endpoint. In local mode,
`wf-history` and the observer read the local stores as before.

#### Service controls

`c` in a service run view runs `wf-control`, and `C-c C-k` runs `wf-kill`.
`wf-control` reads the controls of the run with `GET /v1/runs/{id}/control`,
the head decision that the controls name and, when the controls offer a
redirect, the run snapshot. It then lists only what the controls offer, as
`wf-service-control-choices` states. Each choice has a label without a space
and a description:

| Label | Offered when | Command |
| --- | --- | --- |
| `cancel` | The controls are owned and allow a cancel. | `cancel` after a yes to `wf-confirm-function`. A no sends nothing. |
| `steer:N` | A steer offer names an attempt. One choice exists for each timing of the offer. | `steer` with the occurrence, the attempt, the timing and the text of the steer editor. |
| `redirect:N` | A redirect offer names targets. One choice exists for each target. The description names the open dispatch window or the attempt in flight. | `redirect` with the occurrence and the target. |
| `retry` | The head is a recovery decision with the choice `retry`, and a `retry` offer addresses it. | `retry` with the occurrence and the generation of the decision. |
| `abandon`, `failover:N` | The head is a recovery decision with that choice, and a `choose-recovery` offer of the decision carries the same choice and target. | `choose-recovery` with the occurrence, the generation and the choice, sent to the decision. |

A control that the controls do not offer is not listed, and a run whose
controls offer nothing refuses with a message and sends nothing. `cancel`,
`steer`, `redirect` and `retry` go to the controls of the run and bind the
entity tag of the controls read as `If-Match`. `choose-recovery` goes to the
decision and binds the entity tag of a read of the decision. The steer editor
is the buffer `*wf steer RUN*`. `C-c C-c` sends its text one time, and empty
text sends nothing. After the send, a second `C-c C-c` refuses and sends
nothing. `C-c C-k` abandons the editor.

Each control is sent one time. A cancel completes on the runtime
acknowledgement that accepts it, and the message names that acknowledgement.
Every other control completes when its receipt reaches `effect-observed`. A
refused control, or one whose acknowledgement rejects it, shows its refusal.
An uncertain send is reconciled one time with `wf-manager-session-reconcile`,
and it is never sent again. A retry or a recovery choice shows its effect when
one read of the controls no longer names the decision as the head. A cancel,
a steer and a redirect show their effect only in their receipt, so their
reconciliation without a receipt stays uncertain and reports it.

#### Service lineage and exports

`wf-restart`, `wf-resume` and `wf-fork` create a child request of a run of the
manager with `POST /v1/runs/{id}/lineage-requests`, and `wf-rerun` creates a
restart child in the same way. In a service run view, `R`, `S`, `F` and `g`
run these four commands. The run is chosen as for `wf-control`: the run of the
view, the run of the history row at point, or a run that the session knows.
A history of another endpoint refuses and sends nothing. Each command follows
these steps:

1. It reads the first page of the lineage collection of the run. The page must
   name the run, and its entity tag must be the strong tag of its revision.
   When the page does not list the operation as eligible, the command refuses
   with the eligible operations or the refusal code of the page, and it sends
   nothing.
2. A fork reads the run snapshot and lists its fork targets, the occurrences
   that the runtime completed or reused, in occurrence order, as
   `wf-service-fork-targets` states. Each target has the label `occurrence:N`
   and a description with its code, its current edit and its intent. The
   choice `keep`, `drop` or `replace` edits the answer of the target. A
   replacement is read in the minibuffer, which starts with the published
   answer of the occurrence or the earlier replacement.
   `wf-manager-fork-replacement-value` types the text by the code of the
   occurrence: text as given, a flag from yes, no, true or false, an
   acknowledgement from empty text, and a verdict or a structured answer from
   JSON text. A refused text is read again with the text. The label `send`
   sends the fork with its edits, and `stop` ends the command with nothing
   sent.
3. It sends the lineage request one time, with the body of
   `wf-manager-lineage-body` and the entity tag of the page as `If-Match`. A
   restart and a resume name only the operation. A fork carries its edits in
   occurrence order.
4. After the effect `lineage-created`, the child request takes its inputs from
   the parent run. The command enqueues it without `set-input` and shows its
   exact review in the review buffer of `wf-run`. The lineage lines of the
   review name the parent run, the operation and each edit, and a replacement
   shows the SHA-256 digest of its answer, not the answer. Only `a` and a yes
   start the child run.

`E` in a service run view runs `wf-export`, which exports the verified result
of a run under a new name. The run is chosen as for `wf-control`. The name is
one ASCII component of 1 to 128 letters, digits, dots, underscores and
hyphens that starts with a letter or a digit. Another name refuses before any
read. The command reads the first page of the export collection of the run
and sends `POST /v1/runs/{id}/exports` one time, with the body `{"name":
NAME}` and the entity tag of the page as `If-Match`. After the effect
`exported`, it reads the export receipt `/v1/exports/export_{commandId}`,
which must be published with the name, the run and the command. It downloads
the exported bytes with the verified download of the session, which requires
the size and the SHA-256 digest of the receipt. The buffer
`*wf export RUN/NAME*` then shows the receipt, the verified size and digest
and each receipt of the export collection of the run.

A lineage request and an export are each sent one time. A refused command
shows its refusal, and nothing is sent again. The retrieval of the verified
result of a run changes the revision of the run, so a lineage request sent
while a run view retrieves that result can receive 412 `stale-revision`. A
second run of the command then reads the collection again. An uncertain send
is reconciled one time with one read of its collection: a lineage request
shows its effect when the collection lists a new child of the operation, and
an export when the collection lists a published export of the name. It is
never sent again.

#### Service-mode limits

These limits of service mode stay open:

- An uncertain send of `create`, `set-input`, a capture, `enqueue`,
  `approve`, `discard` or `withdraw` stops the command with a message that
  the outcome is uncertain and that nothing was sent again. The command reads
  nothing to reconcile it. The user reads the request or the
  review again with `g` in the review buffer or `M-x wf-refresh` in the setup
  form, and decides from that read. Only an answer, a run control, a lineage
  request and an export are reconciled with one read.
- A command of service mode waits in the foreground for a receipt, a
  review or a run, for at most 120 seconds (`wf-service--wait-seconds`).
  Emacs accepts no other command during that wait, and only `C-g` ends it.
  The end of the wait sends nothing, and the manager keeps the command.
- A service run view reads `/v1/runs/{id}/snapshot` as its first page
  only, and so does the Pi extension. A snapshot of more than one page
  leaves an incomplete page set, which holds one of the two page-set places
  of the client until the set expires. While both places are held, another
  page set of the client receives 429 `storage-quota`.
- `wf-lineage-compare` and the observer commands have no service-mode
  equivalent.

The manager limits each client to two subscriptions across its event and
route streams, and a third stream receives 429 `storage-quota`. A client
that connects a stream again at once after a dropped connection can
receive this refusal while the earlier subscription still counts. The
refusal is transient, and the rule of the agent-cat protocol document is to
keep the cursor, poll from it, and connect the stream again after the
backoff. Service mode always reads `/v1/events` with polling batches, so it
holds no subscription and never receives this refusal. A read refused with
429 `storage-quota`, for example by the page-set limit above, is read again
as [Service mode](#service-mode) and [Sessions](#sessions) state.

### Service-mode transport

`emacs/wf-manager.el` is the transport of the service mode, in which `wf.el`
is a client of an agent-cat workflow manager over HTTPS. The file has no user
interface and uses only libraries that are part of Emacs. It currently loads a
client profile, reads its credential, decodes and encodes exact JSON, decodes
the event records and the resources of the manager, builds the typed answer of
a decision, and coordinates refreshes and the reconciliation of an uncertain
command without I/O. Its asynchronous HTTP transport sends requests, binds a
connection to the capabilities of the manager and reads the event polling
mode. A session on a connection installs the complete overview and follows
the events of the manager with polling batches. A session also sends the
commands of its caller one time each, reads their receipts, reconciles an
uncertain command with one read, and gives the bytes of an artifact only
after their size and SHA-256 digest agree with the stated values.
`emacs/wf-service.el` connects the commands of `wf.el` to this transport (see
[Service mode](#service-mode)).

A client profile is a JSON file of version 1. It has exactly these four
fields:

```json
{
  "version": 1,
  "endpoint": "https://127.0.0.1:8443/v1",
  "credentialFile": "/Users/me/.config/agent-cat/client.credential",
  "caFile": "/Users/me/.config/agent-cat/manager-ca.pem"
}
```

`wf-manager-profile-load` applies the client profile rules of agent-cat
(`doc/api/README.md` and `ext-pi/src/manager/profile.ts`):

| Item | Rule |
| --- | --- |
| Profile file | An absolute path. A private file of at most 16384 bytes, in UTF-8, that holds one JSON object. |
| `version` | The integer 1. |
| `endpoint` | An `https` URL of at most 8192 characters whose path is `/v1` or `/v1/`. It has no user information, query or fragment, and no space or control character. The port, when present, is from 1 to 65535. |
| `credentialFile` | An absolute path of at most 4096 UTF-8 bytes, with no NUL, line feed or carriage return. The file is private and holds 32 to 512 visible ASCII bytes other than the comma, with no final newline. |
| `caFile` | An absolute path with the same limits. The file is a regular file of at most 1048576 bytes that no group or other user can write. It holds at least one PEM certificate. |

A private file is a regular file, not a symbolic link, that belongs to the user,
has no group or other permission bits (mode 0600 or 0400) and has one link.

The loader reads the credential file one time, when the profile loads. The
profile record keeps the bearer in its `credential` slot. Only
`wf-manager-authorization` reads that slot, to build the one `Authorization`
header of a request.

Each refusal signals a condition below `wf-manager-error`. The data of the
condition is `(FIELD REASON)`, where `FIELD` is the JSON name of the field, or
`"profile"` for the profile file itself.

| Condition | Cause |
| --- | --- |
| `wf-manager-invalid-profile` | The profile is not UTF-8 JSON, has a missing, extra or repeated field, has a field of the wrong type, has a relative path, or names a CA file without a certificate. |
| `wf-manager-invalid-endpoint` | The endpoint breaks one of its rules. |
| `wf-manager-file-unavailable` | A file is missing, too large, not a regular file, writable by a group or other user, or, for a private file, not private. |
| `wf-manager-credential-unavailable` | The credential bytes are outside the bounds. |

#### Exact JSON

`wf-manager-json-decode` parses JSON text with `json-parse-string` and keeps
every value exact. The text is a unibyte string of UTF-8 bytes or a multibyte
string. The decoder checks the byte bound before it parses: text of more than
1048576 bytes (`wf-manager-response-bytes`), or of more than the optional limit
argument, signals `wf-manager-response-too-large`. Text that is not UTF-8 or
not one JSON value signals `wf-manager-invalid-response`.

| JSON | Lisp |
| --- | --- |
| object | hash table with the test `equal` and string keys. When a name occurs more than one time, the last member counts. |
| array | vector |
| string | string |
| number | `wf-manager-json-number`, which holds the source text of the number |
| `true` | `t` |
| `false` | `:false` |
| `null` | `:null` |

No JSON value is `nil`, so `gethash` gives `nil` only for an absent member.
False, null and absent are three distinct things. Because each number keeps its
source text, `9007199254740993`, `123456789012345678901234567890` and `1e400`
keep their values.

`wf-manager-json-encode` writes compact JSON as UTF-8 bytes: no white space,
the members of each object in the order of the UTF-16 code units of their
names, and each number as its source text. `wf-manager-json-equal` compares
numbers by exact decimal value, so `1` equals `1.0` and `-0` equals `0`, and it
compares objects without regard to the order of their members. These rules are
the rules of `ext-pi/src/manager/json.ts` in agent-cat.

#### Event decoders

The decoders follow `ext-pi/src/manager/events.ts` in agent-cat and pass the
`invalidations`, `batches`, `routeRecords`, `cursors`, `etags` and `problems`
vectors of the events section of `test/manager_client_vectors.json`.

| Function | Value |
| --- | --- |
| `wf-manager-decode-invalidation` | A version 1 invalidation of exactly `version`, `resource` and `revision`. The resource is a path below `/v1/`, and the revision is a bounded identifier. |
| `wf-manager-decode-invalidation-event` | One event of exactly `id`, `event` and `data`. The `id` is a cursor, and the `event` is one of the seven event names of `/v1/events`. |
| `wf-manager-decode-event-batch` | A version 1 polling batch with a cursor, an oldest cursor, at most 256 events and a boolean `hasMore`. |
| `wf-manager-decode-route-record` | A route record with its header and exactly one of `body`, `claim` and `event`. The record at position P has the identifier of position P+1. An inline body stays an exact JSON value. |

Each decoder returns a record and has an encoder that gives the JSON value
back. A value that breaks a rule signals `wf-manager-invalid-response`.

A bounded identifier is 1 to 128 ASCII letters, digits, `_` and `-`.
`wf-manager-valid-cursor-p` accepts a bounded identifier, a dot and a canonical
unsigned 64-bit decimal. `wf-manager-valid-etag-p` accepts a quoted bounded
identifier. An entity tag is an opaque token: `wf-manager-etag-equal` compares
two tags as text only, and a tag has no order and no numeric value.

`wf-manager-problem-failure` maps a problem response to a failure. It returns
a list for `signal`. A body whose `status` member equals the HTTP status and
whose `code` member is a bounded identifier gives
`(wf-manager-refused STATUS CODE)`. Thus a 410 problem with the code
`view-expired` or `cursor-expired` gives a refusal 410 with that code. Every
other body gives a `wf-manager-invalid-response` failure.

| Condition | Cause |
| --- | --- |
| `wf-manager-invalid-response` | A response is not UTF-8 JSON, or a decoded value breaks a rule. The data is `(KIND REASON)`, where `KIND` names the kind of value, such as `"route record"`. |
| `wf-manager-response-too-large` | A response has more bytes than the bound. |
| `wf-manager-refused` | The manager refused with a problem response. The data is `(STATUS CODE)`. |
| `wf-manager-transport-unavailable` | The manager could not be reached. The data is `(KIND REASON)`. |

#### Resource decoders

The resource decoders follow the draft, preparation, receipt, decision, control
and run decoders of `ext-pi/src/manager/resources.ts` in agent-cat. They pass
the `drafts`, `requests`, `preparations`, `receipts`, `decisions`, `controls`
and `runs` vectors of the resources section of
`test/manager_client_vectors.json`. Each decoder returns a record. The encoder
of a record gives its canonical JSON value. `wf-manager-decision-projection`,
`wf-manager-control-projection` and `wf-manager-run-projection` give the
projection of the decoded fields of a decision, of the controls of a run and of
a run. A value that breaks a rule signals `wf-manager-invalid-response`, with
the kind of value as `KIND`.

| Function | Value |
| --- | --- |
| `wf-manager-decode-draft` | A version 1 request resource, or one item of the request collection. The self link names its own identifier. The record keeps the phase, the readiness, the admission state, the queue position from 1 to 100 or nil, at most eight unique blocking reasons, and the preparation, run, parent run and lineage, each one possibly nil. |
| `wf-manager-decode-readiness` | The declarations, the supplied inputs, the missing names and the input errors, each one at most 256 items. Each supplied input names one declaration one time, and the missing names are the declarations without a supplied input, in declaration order. |
| `wf-manager-decode-input-declaration` | A declared input with a name, a source of `prompt`, `command-tail` or `stdin`, a null description, a true `required` and the schema `{"type":"string"}`. |
| `wf-manager-decode-supplied-input` | Literal text of at most 2097152 characters, NUL and empty text included, or a capture with its opaque selector, a bounded identifier. |
| `wf-manager-decode-input-error` | An input name and one of the codes `unknown-input`, `invalid-input`, `capture-unavailable` and `size-limit`. |
| `wf-manager-decode-capture-receipt` | A version 1 capture receipt with exactly the members `version`, `id`, `requestId`, `profileId`, `bytes` and `sha256`. The byte count is canonical decimal text of at most 67108864, and the digest is a lowercase SHA-256 digest. The vectors file has no capture receipt, so the ERT tests check this decoder on their own values. |
| `wf-manager-decode-preparation` | A version 1 preparation with a valid RFC 3339 expiry time, a lowercase SHA-256 review digest, a review and a reason or nil. |
| `wf-manager-decode-review` | The consent facts of a preparation. The policy and the result code stay exact JSON values after their checks. A review without a lineage is a root review, and a null lineage refuses. |
| `wf-manager-decode-review-input` | An input name, a source of `literal` or `capture`, the byte count as canonical unsigned 64-bit decimal text and a SHA-256 digest. |
| `wf-manager-decode-review-lineage` | A parent run, an operation of `restart`, `resume` or `fork`, and at most 2048 edits. Only a fork has edits. |
| `wf-manager-decode-review-edit` | A drop, or a replacement with the SHA-256 digest of its answer, at an occurrence that is canonical unsigned 64-bit decimal text. |
| `wf-manager-decode-command-receipt` | A version 1 command receipt. The required scopes are the scopes of the operation (`wf-manager-required-scopes`), the self link names the receipt, and the resource link names its resource. The acknowledgement and the effect stay exact JSON values after their checks. |
| `wf-manager-decode-decision` | A version 1 question or recovery decision whose queue names the decisions of its run. The occurrence and the observed sequence are canonical unsigned 64-bit decimal text, and the position is from 0 to 2047. A question keeps its observation code, its editor schema or nil, and its prompt. A structured code states the semantic schema of the question. A recovery keeps its gap, its message and at most 16 choices, and only a failover choice names a target. The record keeps the exact JSON value that it decodes. |
| `wf-manager-decode-control` | The version 1 controls of a run: its supervision state, `cancelAllowed` as JSON true or false, the decision head as a bounded identifier or JSON null, and at most 512 offers. Cancellation is not an offer. An offer is `steer`, `retry`, `choose-recovery`, `redirect` or `answer`. The address of a steer offer is an occurrence and an attempt, and the address of every other offer is an occurrence alone. The occurrence is canonical unsigned 64-bit decimal text and the attempt is canonical unsigned 32-bit decimal text. An offer keeps its generation or nil, at most two distinct timings, at most 16 recovery choices and at most 256 targets. The record keeps the exact JSON value that it decodes. |
| `wf-manager-decode-run` | One version 1 item of the run collection, or a catalogue entry of the kind `unreadable-manifest` with only its public category. The links of a run name its own identifier. A known run keeps its workflow, its request, parent run and lineage, each one possibly nil, and its manifest version, 2 or 3, or nil for a legacy manifest. It keeps four separate dimensions: the runtime summary or nil (status, last sequence as canonical unsigned 64-bit decimal text, and protocol version 1, 2 or 3), the supervision state, the integrity of the journal and the verification of the result. Its limitations are distinct. A run is display data and grants no supervision, control or signalling authority. |
| `wf-manager-decode-overview-member` | `{"kind":K,K:MEMBER}`, where `K` is `request`, `preparation`, `run` or `decision`. The encoder gives the projection of a run member and of a decision member. |
| `wf-manager-decode-export-receipt` | A version 1 export receipt with exactly the members `version`, `id`, `runId`, `commandId`, `name`, `code`, `state`, `sha256`, `bytes` and `download`. The name satisfies `wf-manager-export-name-valid-p`, the code is an observation code, and the state is `published` or `unresolved`. The digest, the size of at most 67108864 bytes as canonical decimal text and the download resource are each JSON null or valid. |
| `wf-manager-decode-export-collection` | The first page of the export collection of a run: the run, the page with its revision, and at most 256 unique export receipts, each of that run. |
| `wf-manager-decode-lineage-collection` | The first page of the lineage collection of a parent run: the run, the page with its revision, the unique eligible operations, the refusal code (`incompatible-parent`, `ownership-unavailable`, `quarantined` or `unsupported-operation`) exactly when no operation is eligible, and at most 256 unique child requests, each of which names the run as its parent. The vectors file has no export or lineage collection, so the ERT tests check these decoders on their own values. |

The state of a command receipt must agree with its evidence:

| State | Dispatch attempt | Acknowledgement | Effect | Refusal |
| --- | --- | --- | --- | --- |
| `accepted` | none | none | none | none |
| `dispatch-attempted` | present | none | none | none |
| `acknowledged` | present | present | none | none |
| `effect-observed` | any | any | present | none |
| `refused` | any | any | none | present |
| `unresolved` | any | any | none | none |

An acknowledgement names an attempt only together with an occurrence, and the
acknowledgement of an answer names an occurrence and no attempt. Accepted
intent is not an attempted or acknowledged delivery.

A name, a label or a text bound counts characters, which are Unicode code
points. `wf-manager-valid-timestamp-p` accepts the times that the protocol
accepts: a valid Gregorian date with a year other than 0, a time below
24:00:00 with optional fraction digits, and `Z` or an offset below 24:00.

#### Typed answers

`wf-manager-answer-value` gives the typed JSON answer of the text of a person
for a decision. It follows `answerValue` of `ext-pi/src/manager/resources.ts`
in agent-cat and passes the `answers` vectors of the resources section.

| Code of the question | Answer |
| --- | --- |
| `flag` | `yes`, `y` or `true` gives `t`, and `no`, `n` or `false` gives `:false`, which is JSON false. Letter case and the white space at the two ends do not count. |
| `receipt` | Empty text, or white space only, gives `:null`. |
| `text` | The text itself, empty text included. |
| `verdict` | JSON text of at most 1048576 UTF-8 bytes, as an exact JSON value. |
| structured, `{"json":{"schema":S}}` | JSON text that agrees with the editor schema of the decision: the type of each value, the required fields of each object, and no unknown field. |

`wf-manager-answer-body` gives the answer body from that value: the operation
`answer`, the occurrence as canonical decimal text, the generation of the
decision and the value. An answer that does not agree with the code, a
structured question without an editor schema, and any answer to a recovery
decision signal `wf-manager-invalid-answer` before any body is built. The data
is `("answer" REASON)`, for example
`("answer" "answer field ok must be a boolean")`.

`wf-manager-fork-replacement-value` types the replacement answer of a fork
edit in the same way, by the code of the occurrence in the run snapshot, as
`forkReplacementValue` of `ext-pi/src/manager/resources.ts` does. The code
`ack` takes empty text and gives `:null`, the code `structured` takes JSON
text, and the codes of the table convert as the table states.
`wf-manager-lineage-body` gives the closed body of a lineage request:
`{"operation":OPERATION}` for a restart and a resume, and for a fork its
records of `wf-manager-fork-edit` as edits in occurrence order, each
occurrence as canonical decimal text. `wf-manager-export-name-valid-p` accepts
one ASCII component of 1 to 128 letters, digits, dots, underscores and hyphens
that starts with a letter or a digit.

#### Refresh coordination

The refresh coordinator follows `ext-pi/src/manager/refresh.ts` in agent-cat
and passes the `sequences`, `backoff`, `jitter` and `reconciliation` vectors of
the refresh section of `test/manager_client_vectors.json`. It performs no I/O.
Each function returns the next state and the actions that the caller performs.
No action and no report is a send.

| Function | Behavior |
| --- | --- |
| `wf-manager-refresh-new` | The state of generation zero with every resource idle. |
| `wf-manager-refresh-invalidate` | An invalidation of a resource. An idle resource gives the action `(fetch KEY GENERATION)` for the current generation. A resource with a fetch in flight only becomes dirty, so any number of invalidations during one fetch give one later fetch. |
| `wf-manager-refresh-complete` | The completion of a fetch. Only the fetch in flight of the current generation gives `(install KEY GENERATION)`, and a dirty resource then gives exactly one more fetch. Every other completion, in particular one of an earlier generation, gives `(discard KEY GENERATION)` and changes nothing. |
| `wf-manager-refresh-advance` | A resnapshot, after a 410 refusal or a new overview, or an endpoint switch. The generation advances and every resource becomes idle. |
| `wf-manager-reconnect-delay` | The delay of a reconnection and the next backoff, as `(DELAY . NEXT)`. The delay doubles from one second (`wf-manager-initial-backoff`) up to 30 seconds (`wf-manager-reconnect-backoff-max-seconds`). A connection that delivered an event resets the backoff to one second. |
| `wf-manager-jittered-microseconds` | The wait in microseconds for a delay and a fraction from zero to one: from half the delay to the whole delay. A fraction outside that range is clamped, and a value that is not a number counts as zero. |
| `wf-manager-reconcile-read` | The one read that reconciles a `wf-manager-uncertain` command: `(receipt LOCATION)` when a receipt location is known, and otherwise `(target LOCATION)`. |
| `wf-manager-reconcile` | The report of that read: `(effect-observed)`, `(refused)` or `(uncertain UNCERTAIN)`. |

A `wf-manager-uncertain` record keeps the exact pending command, with its
bytes, its idempotency key and its precondition, the target location, the
precondition entity tag and the receipt location, when one is known. With a
receipt location, only the receipt decides. The state `effect-observed`
observes the effect, the state `refused` reports the refusal, and every other
state stays uncertain. Without a receipt location, the target observes the
effect only when the caller sees the effect in it and its entity tag differs
from the precondition. A failed read stays uncertain. An uncertain report
holds the same record, so that the command stays available for an explicit
exact resend.

Some targets no longer serve the effect of a command, for example an answered
decision that reads as 404. For such a command, the caller gives a
`wf-manager-reconcile-target` with another location and the entity tag of that
resource from before the send. Without a receipt location, that resource
replaces the target and its entity tag replaces the precondition. With a
receipt location, the receipt still decides.

#### HTTP transport

The transport sends each request with `url-retrieve` over the GnuTLS of Emacs.
The wait for a response does not block editing: the response arrives through a
process filter and a callback, and timers run while the request waits. The
connection of a request and its TLS handshake open before `url-retrieve`
returns. A connection of Emacs 30 on macOS that opens without waiting starts
its TLS handshake at once, and when the peer refuses the connection at once,
that handshake writes to the refused socket and the signal SIGPIPE ends the
Emacs process. A connection that opens before the call returns gives such a
refusal as the failure `wf-manager-transport-unavailable` instead.

The TCP connect and the TLS handshake of each request therefore block Emacs
until they end. On 127.0.0.1 this takes milliseconds. A host that drops
packets without a reply blocks Emacs until the connect timeout of the
operating system, before the 15-second response timer starts. A refused
connection, a failed handshake and a server certificate that the CA file of
the profile does not verify each end the request with one callback after the
call returns, with the failure `wf-manager-transport-unavailable`.

| Function | Behavior |
| --- | --- |
| `wf-manager-transport-open` | The transport of a loaded profile. Its optional argument is an existing session directory. Without one, the transport makes a private temporary directory and removes it on close. A temporary directory that cannot be made gives `wf-manager-file-unavailable`. The directory holds the settings file of the network security manager and an empty url.el cache directory. |
| `wf-manager-get` | One GET of a resource below `/v1/` with the Accept value `application/json`. |
| `wf-manager-post` | One POST of a JSON command of at most 2097152 bytes with its idempotency key and an optional `If-Match` entity tag. The transport sends it one time and never sends it again. |
| `wf-manager-poll-events` | One polling batch of `/v1/events` after a cursor, with the Accept value `application/json` and the cursor in the query parameter `after`. The result is a `wf-manager-event-batch`. |
| `wf-manager-cancel` | The end of one pending request. |
| `wf-manager-transport-close` | The end of every pending request. Each url.el process and buffer of the transport is gone when the function returns. A later request signals `wf-manager-closed`. |
| `wf-manager-connect` | A new transport bound by one GET of `/v1/capabilities`. The result is a `wf-manager-connection` with a fresh random endpoint identity of 32 hexadecimal digits and the checked capabilities. After a failure, the transport is closed. |
| `wf-manager-check-capabilities` | The rules of `checkCapabilities` in `ext-pi/src/manager/session.ts`: exactly the eight fields, supported versions, the version 1, an authority epoch of at most 105 characters, at most four distinct scopes, at most 256 distinct profile identifiers, the two transports `sse` and `polling`, each fixed limit at its value and each configured limit above zero and at most its largest value. Unsupported versions signal `wf-manager-unsupported-version`, and every other break of a rule signals `wf-manager-invalid-response`. |
| `wf-manager-command-key` | A new idempotency key of a connection: the authority epoch, a dot and a nonce of 16 random bytes in unpadded base64url, 22 characters. No nonce occurs two times in one connection. |

`wf-manager-get`, `wf-manager-post`, `wf-manager-poll-events` and
`wf-manager-connect` return a `wf-manager-exchange`, which `wf-manager-cancel`
takes. Their callback runs exactly one time, after the function returns, with
the result or a failure `(CONDITION . DATA)`. `wf-manager-failure-p` tells the
two apart. A successful JSON response is a `wf-manager-reply` with its status,
its decoded JSON value, its entity tag, its location and its size. An invalid
argument signals before any send: `wf-manager-invalid-endpoint` for a resource
that is not a path below `/v1/`, and `wf-manager-invalid-request` for a command
above its bound, an invalid idempotency key, an invalid `If-Match` value or an
invalid cursor.

Each request has exactly the headers `Authorization`, built from the
credential of the profile, `Accept` and, for a command, `Content-Type`,
`Idempotency-Key` and `If-Match`. url-http adds only `Host`, `Connection:
close`, `MIME-Version` and, for a command, `Content-Length`. url-http sends the
Accept value of `url-mime-accept-string`, and the manager refuses a repeated
Accept header with 400 `malformed-request`. The transport therefore binds that
variable to the Accept value of the request and never puts Accept in the extra
headers. It also binds the charset, language and encoding strings, the user
agent and the extension header to nil, so url.el adds no other negotiation
header. url-http joins the extra headers and the body without an encoding, and
it refuses a request that is multibyte text. The transport therefore sends
each header name and value as unibyte text, so a command body with non-ASCII
text goes out as its exact UTF-8 bytes.

url-http parses the response in its own buffer after `url-retrieve` returns.
The transport therefore gives each url.el buffer the same settings as
buffer-local values. The settings are: no redirect (`url-max-redirections` 0), no keepalive,
no cache, no cookie, no history, no proxy and no connection of another caller.
`gnutls-trustfiles` holds only the CA file of the profile, and
`gnutls-verify-error` is t. `url-request-noninteractive` and
`nsm-noninteractive` are t, and `nsm-settings-file` is a file in the session
directory. Advice on `nsm-verify-connection` binds these two variables again
for each process of a transport, both for the security check of a connection
while it opens inside `url-retrieve` and for each later check of that process,
so no prompt occurs. The advice also binds `network-security-level` to `low`
for each process of a transport, so the network security manager adds no
check of its own. The GnuTLS verification of the handshake against the CA file of the
profile is the trust decision. The network security manager would refuse a
self-signed server certificate even when the CA file holds that certificate,
which is the certificate that a local manager generates.

A response passes these checks:

| Response | Result |
| --- | --- |
| More than 100 header lines or 16384 header bytes | `wf-manager-response-too-large`. |
| A body above 1048576 bytes, or a declared length above that bound | `wf-manager-response-too-large`. The transport ends the request as soon as the bound is passed. |
| A repeated framing header, `Transfer-Encoding` together with `Content-Length`, or a `Content-Encoding` | `wf-manager-invalid-response`. |
| A redirect status | `wf-manager-redirect-refused`. No second request is sent. |
| A status outside 200 to 299 | The failure of its problem response, as `wf-manager-problem-failure` gives it, when the response is `application/problem+json` with `Cache-Control: no-store`. A 401 gives `(wf-manager-refused 401 CODE)` and a 412 gives `(wf-manager-refused 412 CODE)`. Every other response is `wf-manager-invalid-response`. |
| A 2xx response | A `wf-manager-reply`, when the response is `application/json` with `Cache-Control: no-store`, the body is a JSON object whose `version` is 1, the entity tag is strong and the location is a resource below `/v1/`. A version other than 1 is `wf-manager-unsupported-version`. |
| No complete response, a connection failure, or no response within 15 seconds | `wf-manager-transport-unavailable`. |

On a 401, the Authorization header is already present, so
`url-http-handle-authentication` consults no authentication source and the
response comes back as a typed refusal with no prompt.

url.el calls its callback one time, after the complete response. It has no
supported facility that delivers the bytes of an open response to a caller as
they arrive. The client therefore reads `/v1/events` in the bounded polling
mode, which the client names `poll`, and not as server-sent events.

| Condition | Cause |
| --- | --- |
| `wf-manager-redirect-refused` | The manager answered with a redirect status. |
| `wf-manager-unsupported-version` | The capabilities name versions that the client does not support, or a response version is not 1. |
| `wf-manager-invalid-request` | An argument of a request breaks a rule. The request is not sent. |
| `wf-manager-closed` | The request was cancelled, or its transport or its session was closed. |
| `wf-manager-wrong-endpoint` | A reference names the endpoint identity of another binding. |

#### Sessions

A session follows `ManagerSession` of `ext-pi/src/manager/session.ts` in
agent-cat, with the `poll` delivery of this client. It is bound to one
`wf-manager-connection` at a time and to the endpoint identity of that
connection. A `wf-manager-reference` is a resource path below `/v1/` together
with that endpoint identity.

| Function | Behavior |
| --- | --- |
| `wf-manager-session-start` | A new session on a connection. The session assembles the overview, installs it and then follows `/v1/events` from its cursor. Its callback receives the first overview read. After a failure, the session does not follow. An optional function runs after each install, each change of the delivery state, the end of the follow loop and the close. |
| `wf-manager-session-page-set` | One complete page set from its first page, as `pageSet` of ext-pi assembles it: every page repeats the set identity, the revision, the expiry, the total and the other members of the first page, the indexes follow each other, each page has at most 256 items, the set holds at most 64 MiB, every page arrives before the expiry, and each `next` token keeps the path and the query of the first page. Any other page gives `wf-manager-invalid-response`, and no partial set is given. A page that the manager refuses with 410 `view-expired` restarts the assembly at the first page, at most three times (`wf-manager-page-set-restarts`). |
| `wf-manager-session-load-overview` | The overview page set of `/v1/snapshot` as a `wf-manager-overview`: its cursor, its oldest cursor, its number of pages and its members. The metadata has exactly `version` 1, `snapshotVersion` 1, `cursor` and `oldestCursor`. Each member has its decoded value, its revision and the reference of its detail resource, such as `/v1/requests/{id}`, with the endpoint identity of the session. This read installs nothing. |
| `wf-manager-session-watch` | Watch a resource of the session. The session reads it now and again after each invalidation that concerns it. A reference of another endpoint signals `wf-manager-wrong-endpoint`. |
| `wf-manager-session-current` | The last installed read of a watched resource: a `wf-manager-reply`, a failure, or nil before the first read. |
| `wf-manager-session-switch` | Bind the session to the endpoint of another loaded profile, as `switchEndpoint` of ext-pi does. The new binding reads its capabilities, receives a new endpoint identity and assembles its complete overview through its own transport, with every member reference bound to the new identity. Only then does the switch commit: the generation advances, the watched resources become the overview alone, the installed reads are cleared, the new overview is installed, the earlier transport is closed and the follow loop starts again from the cursor of the new overview. The callback then receives the new overview. A failed connection, a transport that cannot open, a failed overview read, a close and the commit of another switch before the commit each close the new transport and keep the earlier binding, its watched resources, its installed reads and its follow loop, and the callback receives the failure one time, after the call returns. |
| `wf-manager-session-close` | Cancel the timers of the session and close its transports, the transport of a switch in flight included. Each pending request ends, and no read installs after the close. The close sends no command. |

The follow loop sends one polling batch each second (`wf-manager-poll-seconds`)
on a timer, and the next batch at once while the manager has more events. A
delivered batch sets the delivery state to `poll` and resets the backoff. A
failed batch sets the delivery state to `unreachable` and waits for the
jittered reconnection backoff of `wf-manager-reconnect-delay` before the next
batch. An invalidation concerns each watched resource that it equals or that
lies above or below it. An invalidation of a request, preparation, run or
decision also concerns the overview. The refresh coordinator reads each
concerned resource, with at most one read in flight for each resource, so any
number of invalidations during one read give exactly one later read. A 410
refusal of a batch, `cursor-expired` or `view-expired`, advances the
generation, reads the overview again, reads every other watched resource
again and follows from the new cursor. A read that completes for an earlier
generation installs nothing. A 401 refusal ends the follow loop with
`refused`. An installed read that the manager refused with 429
`storage-quota` or 503 `storage-unavailable` is read again after 0.1 seconds.
No read and no polling batch is a command. A session sends a command only
when its caller calls `wf-manager-session-send`.

After a switch, a read or a polling batch of the earlier binding that is still
in flight installs nothing, because the generation has advanced and the earlier
transport is closed. A reference of the earlier binding gives
`wf-manager-wrong-endpoint`, both for a watch and for the current read, and it
is never sent to the new endpoint. A switch also restarts a follow loop that
ended before it, for example with `refused` after the revocation of the
earlier credential. A buffer that holds a session or a reference owns nothing,
and killing that buffer sends no request and no command.

##### Commands and downloads

These functions follow `prepare`, `send`, `reconcileCommand` and `download`
of `ManagerSession` and the answer and recovery reconciliations of
`ext-pi/src/manager-ui.ts` in agent-cat.

| Function | Behavior |
| --- | --- |
| `wf-manager-session-prepare` | A `wf-manager-pending` command for a reference of the current binding: the exact bytes of its JSON body, a new idempotency key and the entity tag of its precondition or nil. A reference of another binding signals `wf-manager-wrong-endpoint`. |
| `wf-manager-session-send` | One POST of the exact bytes, key and precondition of a command, with `wf-manager-post-bytes`. The callback receives a `wf-manager-sent` of the kind `delivered`, `refused` or `uncertain`. A 2xx reply with a Location is `delivered`, and a 202 reply carries its decoded receipt, whose identifier must name the Location. A 412 `stale-revision` refusal, a closed session, a command of another binding and a refusal before any request are `refused`. Every other failure and every reply that does not agree with the command are `uncertain`. The session never sends a command again by itself. |
| `wf-manager-session-prepare-capture` | A `wf-manager-pending` capture of exact unibyte UTF-8 bytes for a request: a POST of `/v1/captures?requestId=ID` with the media type `application/octet-stream`, a new idempotency key and no `If-Match`. Bytes above 67108864 (`wf-manager-capture-bytes`) signal `wf-manager-response-too-large`, and bytes that are not UTF-8 signal `wf-manager-invalid-response`, as `prepareCapture` of `ManagerSession` refuses them. A capture is `delivered` only as a 202 reply whose body decodes with `wf-manager-decode-capture-receipt` and whose Location names its capture command. The `wf-manager-sent` then carries the capture receipt. |
| `wf-manager-session-read` | One GET of a reference of the current binding. The callback receives the `wf-manager-reply` of status 200 or a failure. |
| `wf-manager-session-receipt` | One read of the receipt at the Location of a delivered command. |
| `wf-manager-session-reconcile` | One read that reconciles an uncertain command under the rules of `wf-manager-reconcile`: its receipt when the location is known, and otherwise the supplied target of the reconciliation or the target of the command. A read of a target observes the effect only when the function of the reconciliation sees it and the entity tag differs from the precondition. The report is `(effect-observed)`, `(refused)` or `(uncertain UNCERTAIN)` with the unchanged uncertain command. Nothing is sent. |
| `wf-manager-session-answer-reconciliation` | The reconciliation of an answer, made before the send. The manager serves only pending decisions, so an answered decision reads as 404. When `wf-manager-stored-answer-text` names the value, one read of the run snapshot gives the supplied target and its entity tag, and the occurrence must have completed, no longer wait on the decision and store that text. Otherwise, and when that read fails, the controls of the run reconcile the answer, and the run must still run with a head that names a later decision. |
| `wf-manager-recovery-reconciliation` | The reconciliation of a recovery choice from the controls of the run: the effect shows when the head no longer names the decision. |
| `wf-manager-session-download` | The verified download of an artifact of the current binding with `wf-manager-download`. |

`wf-manager-download` sends one GET with the Accept value
`application/octet-stream`. A 200 response must have that media type,
`Cache-Control: no-store`, `X-Content-Type-Options: nosniff` and an attachment
disposition, and its exact body must have the stated size and the stated
SHA-256 digest, which `secure-hash` computes over the unibyte bytes. Only then
does the callback receive the bytes. Every other 200 response gives
`wf-manager-invalid-response`. A size above 67108864 bytes
(`wf-manager-artifact-bytes`) or a digest that is not 64 lowercase
hexadecimal digits signals `wf-manager-invalid-request` before any request.

## What replaces what

The seventy-five rows that exist today include three workflows that are not corpus
replacements: `hello`, the transport smoke test; `hello-world`, the public tutorial;
and `taskmaster`, a pinned external-source analysis. Collectively, the corpus-derived
toolbox covers **twelve more files** than the sixty-one-row stage did — ninety-one,
plus wave 5's nine, plus the two files the last two rows absorb
(`skills/wiggum` and `commands/run-orchestrator`), plus `skills/refocus` — plus
one PAL MCP tool that is not a file at all and one external skill (`translate-en`) whose edge is transplanted
and whose text is not. `wiggum-duet` stands for no new file either: it is the same
two files across two panes, which is the owner's own ruling and not a corpus
document. Each program module's haddock carries its own map in full, with the reason
for every cell; this is the index across those modules.

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
| `skills/refocus/SKILL.md` | `refocus`; `Workflows.Refocus.refocusFn` in both Wiggum rows | one clock receipt and one scope assessment against the frozen plan and current standing; the result identifies the unmet requirement, scope correction and next step, and flows into the round's work and handoff. Hourly checks during long turns and after resume remain the active agent's responsibility |
| `skills/wiggum`, `commands/run-orchestrator.md` | `wiggum` | **the loop's inner step, priced** — two work rounds with a refocus check before each, one checkpoint audit and a bounded done-criteria verdict at `minFold 2, maxFold 48, over 34 paths`, which is wave 5's gate. It is *not* the skill's unbounded continuation: the rounds are unrolled at the program level (a bounded revision's body reviews and amends and holds no other statement, so the work cannot loop inside one), and the unroll count — two — is a design decision the gate records in its own words: "a third round would be a design decision and would show here." A long session is several `wf run wiggum` invocations, each re-priced — continuation, compaction refresh and the cross-session durable files stay with the skill. What the program wins: the frozen plan is an *input* ("read-only for the purpose of lowering the bar" becomes true rather than requested); the loop will not start at all under an engine whose questions share one conversation — that is `run.engine` read in Haskell, so it costs no question and no path, and it is the gate the sentinel probe could never be, since a session already carrying the work answers `PARENT_HISTORY_ABSENT` truthfully; the probe is then the *first* question and gates every path, over the residual the engine fact cannot see; the evaluator answered none of the work's questions by construction; "Do NOT submit or push" becomes an **absence** — there is no push argv reachable from the module, verified transitively. `run-orchestrator`'s steps 5–6 are a layered topological sort in Haskell, so the fan-out cap is computed where `parallelize` guesses 3–5 |
| the owner's ruling of 2026-08-20 (no corpus file) | `wiggum-duet` | **the same loop across two live panes**, and the row that made `run.routes` worth having. Its two pins are `worker` and `partner`, neither with a fall-back — a dead pane is a dead question, not a question that silently tries the pane about to judge it — and everything it does not pin itself stays on the default, which is the work's pane. The partner's four seats review round one *inside the term* and round two reads their observations, which is the bind `wiggum` does not have: the old guide's copy-paste between two invocations, priced at `minFold 2, maxFold 54, over 34 paths`. Its gate is `judgeIsElsewhere` over `run.routes`, `run.engine` and the row's own list of work-side pins, shared with `wiggum` so the two cannot drift; it refuses the *inverted* split as well as the shared one, and it refuses a borrowed callee's pin routed at the judge's pane, which is the same contamination spelled as an extra `--route` |

**The original triage — all 119 files, each marked T (its own program), R (rework
first), F (folds into a named host) or K (honestly Markdown) — is
[`doc/design.md` §7](doc/design.md), with §7.5's tally.** It projected twenty-five
programs and roughly sixty rows behind the corpus; **seventy-five** rows exist today, and
with `wiggum` landed the roadmap's five waves are complete. The newest row,
`refocus`, transcribes the scope check and supplies the same checkpoint to each
Wiggum work round. The external `taskmaster` analysis and `hello-world` tutorial
remain outside the corpus tally. §7.5's "roughly sixty"
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
| **5** | the long ones and the top of the loop: `retest`, `denote`, `translate`, `prd-draft`/`prd-critique`, `nodered`, and finally **`wiggum`** | **done, 10 rows.** The wave's claim was that these transplant whole *procedures* rather than rubrics, and the table shows it: `retest-categorical` at 37 was the widest ceiling in `ci/workflows.sh` until the last row landed, and it is an eight-model FPGA sweep priced before a card is opened; `denote` and `prd-draft` are the two rows whose expensive halves are *unreachable* until a gate said yes. §10's first risk never fired — `Lens` carried eight PRD sections, seven analysis axes, six translation reviewers and six Node-RED house-style seats with no field added. **The wave's gate is paid:** `wf cost wiggum` reports `minFold 2, maxFold 48, over 34 paths` — a finite worst case, printed before the first round |

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
#   minFold 2, maxFold 48, over 34 paths
```

That line is the roadmap's own gate for the whole wave (`doc/design.md` §8): **a
finite worst case, printed before the first round.** It is the one number an
autonomous work→checkpoint→verify loop must have and the one
`skills/wiggum/SKILL.md` cannot state — every bound in that file is a word ("a
bounded number of attempts (default 3)", "roughly 3–5 at a time", "every four
hours or so"), and all three are numbers here.

**48 is the second widest ceiling in `ci/workflows.sh`** — past
`retest-categorical`'s 37 and `productize`'s 31, and displaced only by
`wiggum-duet`'s 54, which is this same loop run across two panes — and that is
the right shape
rather than a worrying one: five of the row's eight declared callees belong to
other rows — `commitFn`, `resolveFn`, `cleanupRoundFn`, `fessReportFn`, and
`refocusFn` — so what the top of the loop costs
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

### `refocus` — scope checked before each work round

`wf refocus` supplies one checkpoint from `skills/refocus/SKILL.md`. The `plan`
input carries the goal and accepted completion criteria; `standing` carries the
current work, latest corrections and proposed next step. One clock receipt and
one reasoning question return a short assessment: what remains required, which
detours to stop, the next sound step, the check time and the next deadline.

```sh
wf cost refocus
#   minFold 2, maxFold 2, over 1 path
wf run refocus --scripted --input-arg plan= --input-arg standing=
```

Both Wiggum rows call the same `refocusFn` before each work round. The result
reaches the work brief and the round account carried into the handoff, so the
next action stays tied to the frozen criteria. Two rounds add four consultations
without changing the path count or either early refusal.

The active agent keeps refocus in force during long turns and across resume or
compaction: check immediately on resume, then at least every 60 minutes of
wall-clock time during active work, and record the clock evidence and next deadline in existing task state.
The runner cannot interrupt an opaque model call to enforce a timer, and no
scheduler is added. A boundary check alone does not verify the hourly deadline.

### The seventy-second row: `wiggum-duet`, two panes and one command

```sh
wf cost wiggum-duet
#   minFold 2, maxFold 54, over 34 paths
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
receipt, bought once and only on the two-round arm. `54` is now the widest in the
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
./ci/workflows.sh      # the gate: 75 rows, priced and run
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
>
> To build `wf` against another agent-cat working tree, such as a worktree,
> without editing `cabal.project`, give Cabal a project file of its own whose
> `packages` are this directory and that tree, and a separate build directory:
>
> ```sh
> cabal build exe:wf --project-file=/path/to/cabal.project \
>   --builddir=/path/to/dist
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
