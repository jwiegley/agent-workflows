# Running wiggum across two agent-deck sessions

*An introduction: one session does the work, one session reviews it as a
partner, and `wf` — agent-cat driving the rows in this repository — stands
both up and starts them running.*

## The cast, in one paragraph each

**agent-deck** owns terminal sessions: tmux-backed panes you can watch,
attach to, and leave running. It doesn't know what a workflow is; it knows
what a session is.

**agent-cat** is the language and the engines. A workflow here is a *priced
program*: before anything runs, `plan` and `cost` state its worst case as a
number. At run time an engine answers its questions — `--scripted` from a
canned table, `--engine acp` by starting a fresh adapter session *per
question*, or `--session <id>` by sending every question into one live
agent-deck pane.

**agent-workflows** (this repository) is the toolbox: 71 programs behind the
`wf` binary. Two of them matter here — `wiggum`, the autonomous
work→checkpoint→verify loop as a program, and `partner-reviewer`, the
seven-pass review that runs *beside* the work rather than inside it.

## Zeroth step: read the price

Nothing below spends a token you haven't seen first:

```sh
wf cost wiggum
#   costSummary   minFold 2, maxFold 44, over 34 paths
#   no path through this program consults fewer than 2 addressees,
#   and none consults more than 44.

wf cost partner-reviewer
#   11 consultations, one price — a fixed-shape review
```

`maxFold 44` is a promise, not an estimate: whatever any model says along
the way, the run cannot cost more.

## Standing up the two sessions

```sh
# Pane W — where the work loop will run:
agent-deck launch ~/src/my-project        # add + start in one step
# Pane R — the partner's own conversation, in the same repo:
agent-deck launch ~/src/my-project -c claude

agent-deck list                           # note the two session ids
```

Two panes, one repository, two *different jobs*: pane W is a terminal that
will host the `wf` process; pane R is a live agent session that will *answer
questions* — the reviewer's conversation, watchable as it thinks.

## Session one: the work

From pane W (attach with agent-deck's TUI, or send the command with
`agent-deck session`):

```sh
wf run wiggum --engine acp --adapter claude --require-pinned \
   --input-file plan=doc/PLAN-frozen.md \
   --input-arg  base=main \
   --input-arg  observations= \
   --input-arg  parity=
```

What this does, in order: prints the price again; binds your four inputs
*plus three the runner supplies itself* (`run.backends`, `run.engine`,
`run.sentinel` — facts about the run, refused if you try to pass them);
checks independence — under `--engine acp` every question opens a fresh
adapter session, so the evaluator that judges the work at the end has
answered none of the work's own questions — then runs two work rounds, a
checkpoint fess audit, and a bounded done-criteria verdict, ending in one of
its endings: complete, remains, or blocked. The report states its own
provenance: which backends answered, under what session policy, with the
facts attributed to the runner rather than to anyone who was asked.

**Why not `wf run wiggum --session <pane-W>`?** Try it:

```
Provenance: Outcome: WORK BLOCKED, AND NOTHING WAS STARTED. This run's
engine puts every question of the run into one shared conversation ... so
the party that would have judged the work is the party that would have
done it. No question was put: no round ran, no commit was made ...
```

That refusal costs one question and is the gate doing its job: a deck pane
is *one conversation*, and an autonomous loop whose judge has read the work
it is judging is the thing this program exists to refuse. The pane hosts
the driver; the answering fans out to fresh sessions.

**Pane W does not have to be a pane.** Pane W is only a terminal hosting the
`wf` process — nothing about it answers a question. So `M-x wf-run` from an
Emacs buffer is the same job: pick `wiggum`, answer its four inputs (`@` for
the plan file), choose the `acp` transport with the `claude` adapter, read
the price the command puts in front of you — *run wiggum (branch, at most 44
consultations over 34 paths)?* — and the run lands in `*wf: wiggum*` instead
of a tmux pane. From a TRAMP buffer on the host (`/ssh:hera:~/src/my-project/`)
it runs on the host, beside pane R and the sessions it can see, with nothing
configured. See "The Emacs interface" in the README. Pane R is unaffected:
it is an answerer, not a driver, and `--session <pane-R-id>` still names it.

**A long session is several invocations.** One `wf run wiggum` is two work
rounds and a verdict — K = 2 by design, so the price stays finite. When the
verdict says WORK REMAINS, you (or your loop) invoke it again, re-priced
from scratch, feeding forward what changed.

## Session two: the partner

The partner review is the opposite shape: it *should* be one coherent
conversation — a reviewer building up a view across seven passes — and it
should be somewhere you can watch. That is what pane R is for:

```sh
wf run partner-reviewer --session <pane-R-id> \
   --input-arg scope='the branch against main'
```

Every question of the review lands in pane R's live session, in order, and
you can attach and watch it think. The one rule, stated in the row's own
documentation: **run it somewhere other than the work** — a pane that is
not doing the work, or an `--engine acp` invocation of its own. A partner
review put down the same conversation as the work is the work reviewing
itself, and the report's `run.engine` line says plainly which you did.

## The loop between them

The two sessions couple through *inputs*, not through shared context:

```
pane W:  wf run wiggum ... observations=            → WORK REMAINS + a handoff
pane R:  wf run partner-reviewer --session <pane-R> → a report with observations
pane W:  wf run wiggum ... --input-file observations=partner-report.md
                                                    → the next two rounds fold them
```

The partner's report becomes the next invocation's `observations` input —
data the program splices into its round briefs, priced like everything
else. Nothing flows between the sessions except what you hand across, which
is the point: the review's independence is not a convention, it is the
absence of a channel.

## What the program guarantees, and what stays with you

Guaranteed by construction: the price ceiling; the evaluator answered none
of the work's questions (`--engine acp`); a shared-conversation run refuses
before it starts; pushing does not exist — no publish command is reachable
from `wiggum`, verified transitively; the frozen plan is an *input*, so
nothing in the run can edit its own bar; the report's provenance is
runner-bound fact.

Staying with you (the harness, the skill): continuation across invocations,
compaction refresh, the durable files (`obr`, the journal), and the
stop-everything override — a human interrupt is a harness event no program
can observe.

## The same pattern, other rows

`review-heavy` runs exactly like `wiggum`'s work side (`--engine acp`,
independence checked the same way). `confer` — the decision panel — runs
either way and *says which*: its artefact states backends and session
policy as facts. Every row in `wf list` follows the same grammar: price it,
choose the transport honestly, run it.
