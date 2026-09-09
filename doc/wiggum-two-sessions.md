# Two panes, one command

*You start two agent-deck sessions and prime them yourself. One `wf run` puts
the work loop in the first and a partner review in the second. `wf` drives both
and owns neither: you read and type into either pane while it runs, and when the
run ends both panes are still attached, still holding their history, still
yours.*

That is one row — `wiggum-duet` — and this page is how to use it. The
single-pane and no-pane spellings still work and are further down, under "When
you have no panes".

## The cast, in one paragraph each

**agent-deck** owns terminal sessions: tmux-backed panes you can watch, attach
to, and leave running. It doesn't know what a workflow is; it knows what a
session is. Nothing in this page can start, stop or kill one — `wf` implements
exactly three deck commands (`send`, `show`, `output`) and there is no fourth.

**agent-cat** is the language and the engines. A workflow here is a *priced
program*: before anything runs, `plan` and `cost` state its worst case as a
number. At run time an engine answers its questions — `--scripted` from a canned
table, `--engine acp` by starting a fresh adapter session *per question*, or
`--session <id>` by sending every question into one live agent-deck pane. A
`--route NAME=deck:<id>` sends the questions pinned to the serving model `NAME`
somewhere else.

**agent-workflows** (this repository) is the toolbox: 75 programs behind the `wf`
binary. Three of them matter here — `wiggum-duet`, the two-pane loop this page
teaches; `wiggum`, the same loop in one conversation; and `partner-reviewer`, the
seven-pass review that runs *beside* the work rather than inside it.

## Zeroth step: read the price

Nothing below spends a token you haven't seen first:

```sh
wf cost wiggum-duet
#   costSummary   minFold 2, maxFold 54, over 34 paths
#   no path through this program consults fewer than 2 addressees,
#   and none consults more than 54.
#
#   the fold, path by path (34 in all):
#     2, 3, 13, 26, 37 (×6), 39 (×6), 41 (×3), 50 (×6), 52 (×6), 54 (×3)
```

`maxFold 54` is a promise, not an estimate: whatever any model says along the
way, the run cannot cost more. The `minFold 2` is worth as much — that is the
run that refuses to start, having asked one probe and written one report.

Read it against the single-pane row:

```sh
wf cost wiggum
#   costSummary   minFold 2, maxFold 48, over 34 paths
#   the fold: 2, 3, 13, 20, 37 (×6), 39 (×6), 41 (×3), 44 (×6), 46 (×6), 48 (×3)
```

Same shape, same 34 paths, same floor. The six between them is exactly the
review the duet buys: four partner seats, one publishing act, one directory
listing, bought once and only on the arm where a second round runs — which is
the arm that can consume them.

## Standing up the two panes

```sh
# Pane W — the work.
agent-deck launch ~/src/my-project -c codex

# Pane R — the partner.
agent-deck launch ~/src/my-project -c claude

agent-deck list          # note the two session ids
```

Two panes, one repository. Which agent goes in which pane is yours to choose;
the pairing above is the ruling's own.

**Priming them is your business and `wf` will not do it.** Open each pane, let
the agent come up, give it whatever standing context you want it to have — and
then leave it at an idle prompt. `wf` sends its first question into whatever
state it finds.

## The one command

```sh
export PANE_W=0f3a91c2-codex     # the work
export PANE_R=7b2e40aa-claude    # the partner

wf run wiggum-duet \
   --session      "$PANE_W" \
   --route        "partner=deck:$PANE_R" \
   --poll         250 \
   --require-pinned \
   --input-arg    goal='Bring the token-refresh path under test and close the two known races.' \
   --input-arg    base=main \
   --input-arg    observations= \
   --input-arg    parity=
```

`--input-file goal=doc/GOAL.md` where the goal is longer than a shell line.

Read the two transport flags against each other, because between them they are
the whole configuration:

* **`--session "$PANE_W"` makes pane W the *default*.** Everything the row does
  not pin itself lands there: every borrowed callee (the commit decomposition,
  the conflict resolution, the cleanup review), every tool, every person, every
  unrouted receipt. All of that is *work*, and work belongs in the work's pane.
* **`--route "partner=deck:$PANE_R"` moves the judgment.** The four review
  seats, the handoff, and the done-criteria judge are pinned to the serving model
  `partner`, and that one flag is what sends them somewhere the work has not
  been.

`--require-pinned` is not required but is recommended: it refuses a model ask
that left out its `served by` *before* a plan is printed, which for this row
means it refuses any ask that would silently have taken the default when it
meant to name a pane.

Before the first question the run prints its table:

```
running wiggum-duet against 2 backends:
  (default)                                                 agent-deck session 0f3a91c2-codex
                                                            — every unpinned ask, every tool and every person
  partner                                                   agent-deck session 7b2e40aa-claude
                                                            — its working directory is its own; this run's tools run in .
  fable, gemini-3.1-pro-preview, gpt-5.5-pro, opus, worker  the default (no --route names them)
  polling every 250ms, 600000ms to a turn, one session for the run
  a `running` tool's command runs in .
  inputs    goal (text) = 70 B given with --input-arg
  inputs    base (text) = 4 B given with --input-arg
  inputs    observations (text) = 0 B given with --input-arg
  inputs    parity (text) = 0 B given with --input-arg
  inputs    run.backends (text) = 53 B supplied by the runner
  inputs    run.engine (text) = 29 B supplied by the runner
  inputs    run.routes (text) = 63 B supplied by the runner
  inputs    run.sentinel (text) = 39 B supplied by the runner
```

The byte counts are of *this* invocation, pane ids and all, so they move when
your ids do.

The third line is the honest one and is worth more than a moment, because it is
the line the gate is about. `worker` is a pin this row *does* declare, and it is
on the default because no `--route` names it — which is exactly right, since the
work belongs there anyway. The four model names beside it are the borrowed
callees' own pins: `opus` carries the commit decomposition, the conflict
resolution, the cleanup review and refocus, and the rest carry the audit's
stances. They are on the default for the same reason `worker` is, and **routing any one of them
is routing work.**

`run.routes` on the last line is that table as a program input: `(default) =
deck:0f3a91c2-codex`, then `partner = deck:7b2e40aa-claude`, one line each with
its newline, in the backend's own spelling — which is the 63 B above, and you can
count it off the two ids. Every ending's report quotes it, so a reader of the
report can name both panes without being told.

## Why the flags cannot be written the other way

Swap them and the run refuses:

```sh
wf run wiggum-duet --session "$PANE_R" --route "worker=deck:$PANE_W" …
```

It *looks* like the split. It puts the worker somewhere of its own. And it
quietly leaves the commit decomposition, the conflict resolution and the cleanup
review on the default — which is now the pane that is about to judge them. The
row will not run it.

| what you type | why |
|---|---|
| `--session W --route partner=deck:R` | **runs.** The judge's backend is neither the work's nor the default |
| `--session W --route worker=deck:W --route partner=deck:R` | **runs.** The same thing spelled out |
| `--engine acp --adapter claude --route worker=deck:W --route partner=deck:R` | **runs.** Three backends, all distinct |
| `--engine acp --adapter claude` | **runs.** Every question opens a session of its own, so the judge has read nothing whatever the routes say |
| `--engine acp --route partner=acp:codex` | **runs**, for the same reason |
| `--session W` (no route) | **refuses.** Judge, work and default are one pane |
| `--session W --route partner=deck:W` | **refuses.** The judge routed back onto the work's own pane |
| `--session R --route worker=deck:W` | **refuses.** The inversion: every borrowed callee would have landed in the judge's pane |
| `--session W --route partner=deck:R --route opus=deck:R` | **refuses.** A borrowed callee's own pin, routed into the judge's pane. Same for `fable`, `gemini-3.1-pro-preview` and `gpt-5.5-pro` |

The last row is the one worth reading twice, because it is the one that looks
harmless. The judge's backend is neither the work's nor the default, so it passes
the two comparisons an operator has in mind — and it still puts the commit
decomposition, the conflict resolution, the cleanup review and the audit's
stances in the judging pane, because those arrive on the *ladder's* names and not
on `worker`. The rule the gate actually applies is the wider one: **the judge's
pane may not be any other pin's pane, and may not be the default.** In practice
that means one `--route` for the judge and nothing else routed anywhere.

The refusal costs one question — the report every ending of this row owes you —
and says so in its own words:

```
Provenance: Outcome: WORK BLOCKED, AND NOTHING WAS STARTED. This run puts the
judgment in a conversation the work also reaches -- the route table and the
session policy are quoted below and both came from the runner, not from
anybody asked -- so the party that would have judged the work is a party that
will have read it. No question was put: no round ran, no review was asked
for, no commit was made, no gate was run and no audit was requested. …
say what would fix it: give the WORK the default answerer and route only the
judge away -- `--session <work-pane> --route partner=deck:<partner-pane>` --
because everything this row does not pin itself, every borrowed callee and
every tool among them, lands on the default and is work. …
```

**One wrinkle, so it does not surprise you.** Only the *unrouted* refusal — one
pane, no `--route` — gets those words. Every refusing row that carries a
`--route` is stopped *earlier*, by the command-line parser rather than by the
program, and its message is about the flag rather than about the split:

```
wf: --route names the model 'partner', which this workflow never pins;
    it pins no model at all
```

The reason is worth one sentence, because it explains a message that otherwise
looks like a bug: `--route` is checked against the models the program *actually
built* pins, and by then the run facts have already selected the refusal
program — one report act, no model asks, therefore no pins. So the sentence is
true of what was built and misleading about the row, which pins six. The gate is
not being bypassed: its verdict is what selected the program that pins nothing,
and the parser's complaint is downstream of the refusal rather than instead of
it. Nothing is spent either way and the fix is the one the table gives; the
wording is a known rough edge and is pinned in `ci/workflows.sh` as the behaviour
that happens.

**One thing the gate cannot check, so it is yours to hold.** It compares route
table *text* — `deck:` and whatever you typed — while `agent-deck` will take
either an id or a title for `session send`, `session show` and `session output`
alike. So `--route partner=deck:my-judge-pane` and `--route opus=deck:7b2e40aa`
are two spellings the gate reads as two panes even when they are one, and the
check is defeated without a word being said. **Give the gate one selector
vocabulary: ids everywhere, or titles everywhere.** Resolving them would mean the
gate calling `agent-deck`, which is exactly what it must not do to stay free.

### Why not `wf run wiggum --session <pane-W>`?

Still refused, and still for the right reason. `wiggum`'s judge and its round
account are the *same* serving model, `opus`, so no route table can separate
them: under one deck session the party that would judge the work is the party
that did it, and an autonomous loop whose judge has read the work it is judging
is the thing that program exists to refuse. It costs one question and changes
nothing. `--route opus=deck:<somewhere-else>` does not rescue it either — that
moves the judge and its round account together, which is why `opus` is in the
list the gate compares against for that row.

`wiggum-duet` is not an exception to that gate — it is the same gate reading a
finer fact. Both rows call one predicate over `run.routes` and `run.engine`, so
the two cannot drift apart.

## Reading and typing while it runs

One turn of the deck transport reads the pane's current reply timestamp *before*
sending, sends, then polls until the session is idle and the timestamp has moved.
Four sentences follow from that, and the third is the one that matters:

1. **Read either pane at any time.** Reading is invisible to the transport.
2. **Type into either pane freely *between* `wf`'s questions.** The staleness
   guard is re-armed before every question and absorbs your turn exactly.
3. **Do not submit a message while `wf` is waiting on that pane.** If your reply
   lands before `wf` reads its own, `wf` will read yours instead, and nothing
   will say so. Watch the run's narration: it prints one line per consultation,
   and the pane is `wf`'s between "put text to model X" and the answer.
4. **For a duet run, pass `--poll 250`.** It shrinks the misattribution window
   fourfold at the cost of one `agent-deck session show` subprocess every quarter
   second, and it is the only mitigation available today that requires no code.

Two further facts, so the picture is complete. A message already *queued* when
`wf` sends is safe: `agent-deck session send` waits for the agent to be ready
before it types, so your turn is answered first and `wf`'s question goes after
it. And a long human interleave will eventually spend `wf`'s turn budget
(600 000 ms by default) and produce a named timeout quoting the last status it
saw — loud, and therefore fine.

## What flows between the panes

Round one runs in pane W. Its account goes to the partner's four seats in pane R,
which publish one observation file per finding into the directory the run was
given (`observations=`, defaulting to `doc/observations`). The directory is then
read back with `find`, and *that listing* is what round two is started from:

```
pane W   round one  ──▶  its account
pane R                        │  four seats, one file per finding
                              ▼
                    doc/observations/2026-…Z.md
                              │  find
                              ▼
pane W   round two  ◀───  the listing
```

The old version of this page taught the same coupling as three commands and a
copy-paste between two invocations. **It is now a bind inside one term, and it is
priced** — those six consultations are the difference between `maxFold 48` and
`maxFold 54`, and `wf cost` shows them before you spend them.

The checkpoint later drains the same directory through the standing cleanup
discipline and commits it once, exactly as `wiggum` does.

## Refocus at each work round

Both Wiggum rows call `Workflows.Refocus.refocusFn` before each work round. A
clock receipt and a reasoning question compare the frozen goal and completion
criteria with the current work and select the next required step. The result
feeds the work brief and the round account carried into the handoff. In a duet,
refocus follows the existing reasoning ladder onto the work side; no new pin is
introduced. The standalone `wf refocus` row runs that same single checkpoint:

```sh
wf run refocus --scripted --input-arg plan= --input-arg standing=
```

The active agent retains the skill's hourly obligation during long turns and
across continuations: refocus immediately on resume or compaction, then at least
once every 60 minutes of wall-clock time during active work, recording clock
evidence and the next deadline in existing task state. Keep required work and verification in scope;
stop only detours that serve no remaining requirement. The runner has no
scheduler that interrupts an opaque model call, so the checkpoints at round
boundaries alone do not verify the hourly deadline.

## When you have no panes

Everything below is the older pattern, unchanged and still supported. Use it when
you have one pane, or none.

**The work, with no pane at all.** `--engine acp` opens a fresh adapter session
per question, so the evaluator that judges the work at the end has answered none
of the work's own questions:

```sh
wf run wiggum --engine acp --adapter claude --require-pinned \
   --input-file plan=doc/PLAN-frozen.md \
   --input-arg  base=main \
   --input-arg  observations= \
   --input-arg  parity=
```

**The partner, separately.** The partner review is the opposite shape from the
work: it *should* be one coherent conversation — a reviewer building a view
across seven passes — and it should be somewhere you can watch. So a pane suits
it, provided the pane is not the one doing the work:

```sh
wf run partner-reviewer --session "$PANE_R" \
   --input-arg commit=HEAD \
   --input-arg observations= \
   --input-arg paths=
```

Its three inputs are `commit` (the revision under review, `HEAD` when empty),
`observations` (the directory it publishes into) and `paths` (one file per line,
which widens `partner-collaborator`'s roster and leaves this row's alone). It
prices at `minFold 11, maxFold 11, over 2 paths` — a fixed-shape review.

**The hand-carried loop.** The two invocations couple through *inputs*, not
through shared context:

```
pane W:  wf run wiggum ... observations=            → WORK REMAINS + a handoff
pane R:  wf run partner-reviewer --session $PANE_R  → observation files
pane W:  wf run wiggum ... --input-arg observations=doc/observations
                                                    → the next rounds fold them
```

Nothing flows between the sessions except what you hand across. That is the
version `wiggum-duet` replaces, and the difference is worth naming: there, the
review's independence is the absence of a channel *and* your discipline about
which pane you typed in; here it is a refusal the program computes from the route
table before anything is spent.

**Pane W does not have to be a pane.** For the single-pane spellings, pane W is
only a terminal hosting the `wf` process — nothing about it answers a question.
So `M-x wf-run` from an Emacs buffer is the same job: pick the row, answer its
inputs (`@` for a file), choose the transport, read the price the command puts in
front of you, and the run lands in `*wf: wiggum*` instead of a tmux pane. From a
TRAMP buffer on the host (`/ssh:hera:~/src/my-project/`) it runs on the host,
beside the sessions it can see, with nothing configured. See "The Emacs
interface" in the README.

**`M-x wf-run` cannot yet drive the duet.** Its transport picker emits exactly
one backend and has no `--route` in it, so `wiggum-duet` is a shell invocation
for now; the requirement — one pane picker per declared pin — is recorded as a
TODO above `wf--read-transport` in `emacs/wf.el`.

**A long session is several invocations.** One `wf run` of either row is at most
two work rounds and a verdict — K = 2 by design, so the price stays finite. When
the verdict says WORK REMAINS, you (or your loop) invoke it again, re-priced from
scratch, feeding forward what changed. Both panes are still there.

## What is guaranteed, and what stays with you

Guaranteed by construction:

* the price ceiling — 54 consultations, over 34 paths, printed before the first
  question;
* **the judge's pane is not the work's pane**, checked before anything is spent,
  and checked against *every* other pin this row reaches — the worker's and the
  four the borrowed callees arrive on — as well as against the default, so no
  callee can be routed into the judge's conversation and none can inherit it by
  default. The comparison is over the pane selectors you typed, so one pane named
  two ways is two panes to it: use ids everywhere or titles everywhere;
* the four review seats and the done-criteria judge have **no fall-back** — a
  dead partner pane is a dead question and the run fails, rather than quietly
  re-routing the judgment to whoever answers next;
* pushing does not exist: no publish command is reachable from either row,
  verified transitively;
* the goal is an *input*, so nothing in the run can edit its own bar;
* every work round receives a fresh refocus checkpoint, and its result flows
  into the work brief and the handoff;
* every report's provenance is runner-bound fact — both panes named, from the
  route table, not from anybody who was asked;
* your sessions are yours: `wf` issues no `session start`, `session stop` or
  `session kill`, and there is no verb in the transport that could.

Staying with you (the harness, the skill): continuation across invocations,
compaction refresh, hourly refocus during long turns, the durable files (`obr`,
the journal), the stop-everything override — a human interrupt is a harness event no program can observe — and
**the interleaving window**, which this design names, mitigates with `--poll 250`,
and does not close.

## The same pattern, other rows

`review-heavy` runs exactly like the work side (`--engine acp`, independence
checked the same way). `confer` — the decision panel — runs either way and *says
which*: its artefact states backends and session policy as facts. Any row that
declares more than one pinned model can be split across panes the same way
`wiggum-duet` is, with the same rule: **give the work the default and route the
judgment away.** Every row in `wf list` follows the same grammar — price it,
choose the transport honestly, run it.
