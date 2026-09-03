#!/usr/bin/env bash
#
# The toolbox gate — every registered workflow, against a table pinned in this
# file.
#
#     ./ci/workflows.sh          # from the repository root, inside the devShell
#
# `Workflows.Registry.registry` is the owner's toolbox: his commands, agents and
# skills as agent-cat programs. It is held to a DIFFERENT discipline from
# agent-cat's `ci/examples.sh`, and the difference is the whole reason there are
# two registries.
#
#   ci/examples.sh pins level, size, askNodes, costSummary and both bills by
#   EQUALITY. Those seven programs are evidence about the language, and a moved
#   number is a fact worth stopping for.
#
#   This gate pins what a toolbox can honestly hold still. A lens added to a
#   roster moves askNodes, costMax and every path count in every program that
#   panels it — and that is a Tuesday, not a regression. A gate that went red
#   every Tuesday would be re-pinned by reflex, and the reflex would spread to
#   the gate next door.
#
# So, per row:
#
#   wf plan <name>              level    EQUALITY  — a rung is a design decision
#                               paths    EQUALITY  — a new branch is a design decision
#   wf cost <name>              costMax  CEILING   — a budget is a promise about
#                                                    the worst case; it may fall
#                                                    freely and rises only by
#                                                    editing one number here
#   wf run <name> --scripted    exit 0             — every branch a scripted
#                                                    default takes is reachable,
#                                                    and every text question has
#                                                    a canned reply
#
# `size`, `askNodes` and the bills are deliberately NOT pinned: they are exactly
# the fields a reworded rubric or an added lens moves, and pinning them here
# would buy nothing this gate does not already catch through `paths` and the
# ceiling.
#
# The registry is read from the binary rather than transcribed: a workflow
# registered and not pinned is a workflow whose price nobody is watching, and a
# row naming no workflow is a row about something that has gone.
#
# No Lean, no network, no agent: `--scripted` answers from each row's own table
# and runs no command. Exits 0 only if every check below passed.
set -uo pipefail
# `|| exit` and not `set -e`: this gate counts failures rather than stopping at
# the first one. Everything below is relative to the repository root, which is
# also the package root.
cd "$(dirname "$0")/.." || exit 1

work="$(mktemp -d "${TMPDIR:-/tmp}/agent-workflows.XXXXXX")"
trap 'rm -rf "$work"' EXIT

failures=0

note() { echo "ci/workflows: $*"; }
bad() {
  # workflow, field, expected, actual — a gate that says only "something moved"
  # costs an afternoon finding out what.
  echo "ci/workflows: FAIL $1: $2: expected '$3', actual '$4'" >&2
  failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# The inputs a row is priced and run with
# ---------------------------------------------------------------------------
#
# EVERY INPUT IS THE EMPTY STRING, deliberately. `plan` and `cost` bind `""` for
# an input nobody gave, and `run` refuses until every input is named — so the
# only way to run the very program that was priced is to name each one empty.
# That is also what makes house rule WR-1 a gate rather than a convention: a
# roster-shaping input must read `""` as THE DEFAULT ROSTER and never as NO
# MEMBERS, because `panel []` is an `error` on a CAF and would take the whole
# binary down here.
inputsFor() {
  case "$1" in
    hello-world) ins=(--input-arg language=) ;;
    review-*) ins=(--input-arg scope= --input-arg paths=) ;;
    green-*) ins=(--input-arg target=) ;;
    commit | commit-*) ins=(--input-arg scope= --input-arg tree=) ;;
    fess) ins=(--input-arg request= --input-arg base=) ;;
    # The confer family. Neither input shapes the roster — the roster is in the
    # source and the inputs are the subject — so WR-1 has nothing to say here
    # and `""` is simply an empty decision over an empty context. That is the
    # invocation priced above, and it is the one this gate runs.
    confer | confer-bare | debate | second-opinion)
      ins=(--input-arg decision= --input-arg context=)
      ;;
    stack | stack-*)
      ins=(--input-arg trunk= --input-arg tip= --input-arg agents= --input-arg pr=)
      ;;
    # Wave 2's residue. `checklist` and `notes` name a FILE, and `""` is given a
    # meaning in Haskell rather than left to `cat`: an absent path becomes a name
    # no file has, so `wf plan --raw` prints the omission and this gate's own
    # `--scripted` run never reaches a command at all.
    checklist) ins=(--input-arg checklist= --input-arg scope=) ;;
    teams) ins=(--input-arg problem= --input-arg context=) ;;
    notes) ins=(--input-arg notes=) ;;
    # The effort ladder. `worktree=` empty is NOT under a Positron directory, so
    # the numbers below are the non-Positron shape of `effort-heavy` — which is
    # tier 1 and therefore changes a define rather than a path, so the pinned
    # `paths` holds either way.
    effort-*) ins=(--input-arg task= --input-arg worktree=) ;;
    # Wave 3, the daily drivers. Five of the nineteen take a roster-shaping
    # `paths=`, and WR-1 is what those rows are priced with empty: at
    # `pr-threads-assess` the empty file list is ONE general seat, and at
    # `partner-collaborator` it is `deep-review`'s four required lenses plus the
    # performance pass — never zero members, because `panel []` is an `error` on
    # a CAF and would take this binary down here.
    pr-threads | pr-threads-assess) ins=(--input-arg pr= --input-arg paths=) ;;
    issue | issue-worktree) ins=(--input-arg issue= --input-arg paths=) ;;
    account-*) ins=(--input-arg scope= --input-arg journal=) ;;
    partner-*)
      ins=(--input-arg commit= --input-arg observations= --input-arg paths=)
      ;;
    # The two Org rows take DIFFERENT inputs, which is what a rung may do: one
    # decomposes a named task, the other extracts from unstructured text. A row's
    # inputs are its own, and `wf plan` prints them.
    org-tasks-breakdown) ins=(--input-arg task= --input-arg context=) ;;
    org-tasks-infer) ins=(--input-arg text=) ;;
    claude-md | claude-md-advise) ins=(--input-arg scope= --input-arg agents=) ;;
    # Same again across the prose dial: the scope of a project-wide proofread,
    # one passage, a file plus its reference tables, or one passage again.
    prose-proofread) ins=(--input-arg scope=) ;;
    prose-smooth | prose-compress) ins=(--input-arg text=) ;;
    prose-transcript) ins=(--input-arg transcript= --input-arg vocabulary=) ;;
    # Wave 4, the audits and the specialists. `dead-code` is one of six rows whose
    # PRICE depends on an input (the others: review-deep, review-sec and
    # partner-collaborator at `paths=`, translate and translate-en at `text=`):
    # `cap=` empty is `capBound ""`, which is two repair trips, and
    # `--input-arg cap=4` would price four. That is
    # `doc/design.md` §10's third risk showing on purpose, and it is why the
    # ceiling below is pinned at the shape this line runs.
    dead-code) ins=(--input-arg scope= --input-arg paths= --input-arg cap=) ;;
    # `extractor=` empty is a name no file has, so `wf plan --raw` prints
    # `python3 <no extractor given> inventory` and this gate's `--scripted` run
    # never reaches a command at all. Same rule as `checklist` and `notes`.
    comments) ins=(--input-arg extractor= --input-arg base=) ;;
    bundles) ins=(--input-arg focus= --input-arg candidates= --input-arg profile=) ;;
    # Both productize rows take a roster-shaping `paths=`, and WR-1 is what makes
    # the empty one safe: the twenty-one deliverables are a FIXED list, and the
    # per-language tool seats collapse to ONE general seat rather than to zero
    # members — `panel []` is an `error` on a CAF and would take this binary down
    # here.
    productize | productize-lefthook) ins=(--input-arg paths= --input-arg scope=) ;;
    # The three nix rows share one invocation shape, which is what makes them one
    # family. `host=` empty is the unconstrained default, so the numbers below are
    # the non-VPS shape — and that is tier 1, which changes an argv and a define
    # rather than a path, so the pinned `paths` holds either way.
    nix-*) ins=(--input-arg subject= --input-arg output= --input-arg host=) ;;
    # `service=` empty names the consent file `.consent/service-unnamed`, which is
    # exactly what a plan should print for an operator who forgot the flag.
    service-*) ins=(--input-arg service= --input-arg domain= --input-arg host=) ;;
    # Wave 4's second half. Three of the five name a FILE or a directory, and `""`
    # is given a meaning in Haskell rather than left to the command: an absent path
    # becomes a name nothing has, so `wf plan --raw` prints the omission and this
    # gate's own `--scripted` run never reaches a command at all. Same rule as
    # `checklist`, `notes` and `comments`.
    query) ins=(--input-arg question= --input-arg schema= --input-arg dialect=) ;;
    expense) ins=(--input-arg receipts= --input-arg trip= --input-arg script=) ;;
    # `decisions=` and `images=` are the two roster-shaping inputs in this half, and
    # WR-1 is what makes the empty ones safe: `decisionsOf ""` is ONE placeholder
    # decision and `imagePaths ""` is ONE placeholder path, never the empty list --
    # an empty agenda would ask the owner to walk through nothing, and an empty
    # image list would make the argv `ls -1` with no operand, which lists the
    # working directory and exits 0.
    qanda) ins=(--input-arg decisions= --input-arg context=) ;;
    transcribe) ins=(--input-arg images= --input-arg subject=) ;;
    # `model=` empty is the corpus's own `llama_3p1_8b_torch`, and the control's
    # name is COMPUTED from it, so one flag names both sides of the differential.
    # That is tier 1: it changes an argv, never a question and never a path.
    tron) ins=(--input-arg problem= --input-arg model= --input-arg trace=) ;;
    # Wave 5, the long ones. `retest`'s `models=` is the one roster-shaping input
    # in this wave, and WR-1 is what makes the empty one safe: `modelsOf ""` is
    # ONE model -- the spec's own `llama_3p1_8b` -- and never the empty list,
    # because `panel []` is an `error` on a CAF and a battery with no model in it
    # would take this binary down here. At `retest-categorical` the input is
    # IGNORED by that file's own ruling ("the ship gate is always all supported
    # models"), so the roster is the fixed eight whatever this line says -- which
    # is why the two ceilings below differ by twenty-one.
    retest | retest-categorical)
      ins=(--input-arg spec= --input-arg base= --input-arg models= --input-arg paths=)
      ;;
    # `denote`'s four inputs shape no roster: `prover=` empty is Lean 4 and
    # `realization=` empty is a design where phase 10 does not exist, both of
    # which are DEFINES rather than members, so WR-1 has nothing to say here.
    denote) ins=(--input-arg subject= --input-arg method= --input-arg prover= --input-arg realization=) ;;
    # The two directions that carry a review team take three inputs; the one that
    # does not takes one, because `prompts/spanish.md` names no glossary and no
    # reference corpus and the row does not pretend to. `text=` empty is the OTHER
    # roster-shaping input in this wave, and WR-1 again: `shortSource ""` is FALSE,
    # so the empty invocation is the full six-seat team and never one seat -- an
    # absent text is unknown, not short, and the price pinned below is the price of
    # the shape this line runs.
    translate | translate-en)
      ins=(--input-arg text= --input-arg glossary= --input-arg references=)
      ;;
    translate-es) ins=(--input-arg text=) ;;
    # The two PRD rows take different inputs, which is what the split bought: one
    # writes a document and needs the goals and the format authority, the other
    # reads one and needs only its path. `prd=` empty is §6's own default,
    # `.taskmaster/docs/prd.txt`, in the printed argv either way.
    prd-draft) ins=(--input-arg goals= --input-arg template= --input-arg prd=) ;;
    prd-critique) ins=(--input-arg prd=) ;;
    # `nodered` names TWO identifiers and a scripts directory, and all three are
    # validated or defaulted in Haskell: `flow=` and `node=` empty fail the skill's
    # own FLOW_ID regex, so `wf plan --raw` prints
    # `node-red-admin flow get <no valid flow id given>` and this gate's own
    # `--scripted` run never reaches a command at all. Same rule as `checklist`,
    # `notes` and `comments`, applied to an identifier rather than to a path.
    nodered)
      ins=(--input-arg request= --input-arg flow= --input-arg node= --input-arg scripts= --input-arg references=)
      ;;
    taskmaster) ins=(--input-arg evidence=) ;;
    # The top of the loop. NONE of its four inputs shapes a roster, so WR-1 has
    # nothing to say here and every empty one is given a meaning in Haskell
    # instead: `base=` empty is `main` (an argv), `observations=` empty is
    # `doc/observations` (an argv), `parity=` empty is the OTHER half of the
    # definition of done's last conjunct rather than a missing conjunct, and
    # `plan=` empty is the sentence a run with no frozen done-criteria earns --
    # which `wf plan wiggum --raw` prints, so an operator who forgot the flag
    # learns it from the plan and not from a report.
    wiggum)
      ins=(--input-arg plan= --input-arg base= --input-arg observations= --input-arg parity=)
      ;;
    # The same loop across two panes. Same four inputs and the same reading of
    # every empty one, with `plan=` renamed `goal=` — which is the word an owner
    # types beside two pane ids, and which reaches the same two places: the
    # audit's request fold and the judge's frozen criteria.
    #
    # NONE of the four is a run fact, and the two that decide this row's SHAPE
    # are: `run.routes` and `run.engine` are bound by `run` and by nothing else,
    # so the numbers pinned below are the numbers of the LOOP — the shape a run
    # with an unknown table takes. The refusal arm is a different and much
    # smaller program and is not reachable from here; the block at the end of
    # this file is where it is reached.
    wiggum-duet)
      ins=(--input-arg goal= --input-arg base= --input-arg observations= --input-arg parity=)
      ;;
    *) ins=() ;;
  esac
}

# ---------------------------------------------------------------------------
# The pinned table
# ---------------------------------------------------------------------------
#
#   pin <name> <level> <paths> <costCeiling>

names=()
declare -A pinLevel pinPaths pinCeiling

pin() {
  names+=("$1")
  pinLevel[$1]=$2
  pinPaths[$1]=$3
  pinCeiling[$1]=$4
}

#   name                level     paths  ceiling

# The smoke row (`Workflows.Hello`). One scrap, two cross-cutting lenses folded
# into a document, one report call: no branch and no loop, so its price is exact
# and the ceiling is the price.
#
# TWENTY-ONE of the seventy-four rows price exactly — minFold equals maxFold,
# `wf cost` answers with a number and not a range — and they are `hello`,
# `hello-world`, `fess`, `confer`, `confer-bare`, `debate`, `second-opinion`,
# `teams`, `notes`, `issue-worktree`, `account-halt`, `account-sitrep`,
# `account-report`, `account-narrative`, `partner-reviewer`,
# `partner-collaborator`, `claude-md-advise`, `prose-proofread`,
# `prose-transcript`, `prose-compress` and `translate-es`. The list is stated
# here, once, and the blocks below point back at it.
#
# It exists to prove the wiring — the registry,
# the shared CLI, the roster, the panel fold, `defining`'s table — rather than to
# do any of the owner's work, and it is the row this gate should be read against
# when a change to the foundation breaks something.
pin hello               pipeline      1       4

# The beginner row (`Workflows.HelloWorld`). One model answer is spliced into
# the next model's prompt; the second question is terminal, so the pipeline has
# one path and an exact price.
pin hello-world         pipeline      1       2

# The review ladder (`Workflows.Review.Ladder`). Four rungs, four prices, side by
# side — which is the entire reason the ladder became a program instead of a
# paragraph that orders five commands by a feeling about weight.
pin review-quick        branch        3       6
pin review-deep         branch        3      10
pin review-sec          branch        3       6
pin review-heavy        branch        3      12

# The gated fix loop (`Workflows.Fix.Green`). The path count is the loop's, and
# it is the number to watch: a rung that grew a branch grew a way to end.
pin green-ci            branch        8      10
pin green-tree          branch        8       9
pin green-flaky         branch        9      11

# The commit-discipline pipeline (`Workflows.Git.Commit`). One `commitFn` with
# four callers; the rungs differ in what they ask of the decomposition and in how
# many repair trips the gate is given, and the ceiling is where that shows.
pin commit              branch        6       8
pin commit-push         branch        6       9
pin commit-recommit     branch       12      12
pin commit-bankruptcy   branch        9      10

# The audit (`Workflows.Fess`). Eleven stances over three receipts, and one
# of the six rows whose minimum equals its maximum — the only one of the six that
# gets there with more than one path: nothing in it is a loop, and the one branch
# chooses which provenance the report carries rather than how much is asked.
#
# The ceiling was 15 until 2026-08-19, when the landing verification found that
# `Rubrics.Fess.sins` carried ten of `fess-auditor.md`'s ELEVEN bold sections —
# `**Loose ends**`, the file's last, was missing. Restoring it is one more lens,
# which is one more question and no more paths: 15 -> 16, `paths` still 2. This
# is the movement that gate comment above is about — a lens added to a roster is
# a Tuesday — and it is re-pinned here rather than absorbed, so the next reader
# can tell a repair from a drift.
pin fess                branch        2      16

# The git family (`Workflows.Git.Stack`). One body, four rungs, and the two
# numbers to watch are `stack` against `stack-rebase` — IDENTICAL, because they
# are the same program with a different argv deciding — and `stack-rebase-fix`
# against both, where the difference IS `rebase-and-fix.md`'s second half: a
# second gate and a bot sweep, priced at seven more consultations in the worst
# case and two and a half times the paths.
pin stack               branch       40      21
pin stack-rebase        branch       40      21
pin stack-rebase-fix    branch      100      28
pin stack-cleanup       branch       30      19

# The confer family (`Workflows.Confer`). Four rows, and four of the six in this
# table whose ceiling IS their price (`hello` and `fess` are the other two):
# nothing in them branches and nothing loops, so `minFold` equals `maxFold` and
# `paths` is 1 for every one. That is the shape a pre-spend contract is at its
# sharpest — `wf cost confer` answers "what will this spend" before a word of the
# decision has been written, and a run that bills anything other than 5 is a run
# of a different program.
#
# The arithmetic is the roster's and is legible at a glance: `askNodes` is
# |roster| + 2 for the synthesised rows and |roster| + 1 for the bare one. A
# fourth seat added to `conferRoster` moves `confer` to 6 and `confer-bare` to 5
# and leaves `debate` where it is, because `debate` filters rather than copies.
pin confer              pipeline      1       5
pin confer-bare         pipeline      1       4
pin debate              pipeline      1       4
pin second-opinion      pipeline      1       2

# The wave-1 warm-up (`Workflows.ProcessChecklist`), landed with wave 2's residue. Two
# rounds, each entered behind a `decide` over a `cat` receipt, and four endings:
# nothing to do (2), cleared after one round (5), and the two after the
# self-verification round (8 each). The number to watch is `paths`: a third
# round would be a design decision and would show here as 5.
pin checklist           branch        4       8

# The two most literal panels in the corpus (`Workflows.Teams`,
# `Workflows.MeetingNotes`). Both price EXACTLY, which is the point of writing them
# next to each other: nothing in either loops, and the one branch each carries
# chooses which provenance the artefact opens with rather than how much is
# asked.
#
# `teams` at 13 is `doc/design.md` §7.2 row 63's own number — ten angles, the
# devil's advocate as a second tier, the review of all the work, and the
# artefact — and it is the arithmetic that settled that cell's "eleven roster
# rows" against its price. An eleventh angle moves it to 14.
#
# `notes` at 17 is one `cat` receipt, ten sections, five checkpoints and the
# artefact. The five are on a serving model none of the ten used, which is what
# makes them an audit; they cost five and they are the five this row exists for.
pin teams               branch        2      13
pin notes               branch        3      17

# The effort ladder (`Workflows.Effort`). These three numbers are the reason the
# row exists: `skills/toolkit/SKILL.md` declares `medium ⊂ heavy ⊂ forge` in
# three bullets and has no way to say what the containment costs. It costs
# 7 -> 10 -> 24, and an operator reads that before spending anything.
#
# `effort-forge`'s 16 paths are the approval branch times the remediation loop's
# three endings over its two rounds, and its 24 is `doc/design.md` §7.4 row 10's
# demo: six phases across four parties, priced before the first token. The
# remediation bound is `atMost 2`; raising it moves both numbers, which is a
# design decision, which is what this table is for.
pin effort-medium       branch        3       7
pin effort-heavy        branch        3      10
pin effort-forge        branch       16      24

# ---------------------------------------------------------------------------
# Wave 3 — the daily drivers (`doc/design.md` §8)
# ---------------------------------------------------------------------------
#
# Nineteen rows, seven programs, and §8's claim about them is testable from this
# table: "these mostly `call_` waves 1–2". Three of them do, and the numbers say
# where — `issue` at 14 is the largest of the nineteen precisely because it calls
# `commitFn` and `botSweepFn`; `account-halt` at 15 is the largest of all because
# it calls `journalFn` and `commitFn` and then panels seven categories.
# Everything else in the wave is thin, and four rows price at 5 or under.

# The pull request's open comments (`Workflows.Threads`). Two rungs over ONE
# ledger, and the free decider over the inventory is what makes the third path:
# a pull request with nothing open on it costs 3 and asks no specialist.
#
# The two ceilings differ by exactly one question, which is the whole of what
# `assess.md` adds to `respond.md` at the empty file list — one general seat.
# A real `--input-arg paths=` widens that seat into the language specialists,
# which moves the ceiling and NOT the path count, because the roster is tier 1.
pin pr-threads          branch        3       5
pin pr-threads-assess   branch        3       6

# The issue drivers (`Workflows.Issue`). `issue`'s 14 is the wave's second
# largest and every part of it is a call: `issueWorkFn`, then `commitFn`, then the
# push, the pull request and `botSweepFn` over the ledger that now exists. Its
# minFold of 2 is the gate that matters — an open pull request already mentioning
# the issue costs one receipt and one report, which is `fix.md`'s own NOTE with a
# price on it.
#
# The four paths are the three cheap gates: already-in-hand, already-addressed,
# and the confirmation-test flag's two arms. A fifth path would mean a fourth
# gate, which is a design decision.
pin issue               branch        4      14
pin issue-worktree      branch        2       6

# The four accounts (`Workflows.Account`). Two of them are `pipeline` and that is
# the point of the pair: nothing in a sitrep or a remaining-scope report branches,
# because there is no judgment about how to END one — so `wf cost` answers with a
# single number and the ceiling IS the price. The other two branch: `account-halt`
# on whether the tree really came back clean, `account-narrative` on the three
# arms of its sourcing verdict.
#
# `account-halt` at 15 is the wave's largest: two receipts, `journalFn`,
# `commitFn`, the push, seven report categories, the closing tree receipt and the
# artefact. `account-sitrep`'s 13 is four receipts, eight sections and the
# artefact; `account-report`'s 11 is two receipts, seven categories, the estimate
# on another engine, and the artefact. An eighth category moves the last two by
# one each, which is a Tuesday.
pin account-halt        branch        2      15
pin account-sitrep      pipeline      1      13
pin account-report      pipeline      1      11
pin account-narrative   branch        3       8

# The partnership (`Workflows.Partner`). The two reviewing rows differ by exactly
# one question, and it is the right one: `partner-reviewer` is `heavy-review`'s
# seven passes and NOTHING else, because `partner-reviewer.md` has no ideation
# section; `partner-collaborator` is `deep-review`'s five plus the three draws
# `doc/design.md` §7.2 row 38 asks for. 7+4 against 5+3+4 is 11 against 12, and
# `ideas=off` is visible in this table as one fewer consultation. A real
# `--input-arg paths=` widens the second and leaves the first alone.
#
# `partner-cleanup`'s four paths are `checklist`'s shape — nothing to do, drained
# after one round, drained after two, or still not drained — and its minFold of 2
# is the arm where the directory was already empty.
pin partner-reviewer    branch        2      11
pin partner-collaborator branch       2      12
pin partner-cleanup     branch        4      12

# The Org-mode rows (`Workflows.OrgTasks`). Five paths each and four questions
# each, which is the shape of a program whose value is mostly in its ENDINGS:
# three degenerate cases and a checked one at `breakdown`, two free deciders and
# a three-armed verdict at `infer`. Both minFold at 2, which is the cheap arm —
# an atomic task, or a text with no commitments in it — and neither pays for a
# judgment about nothing.
pin org-tasks-breakdown branch        5       4
pin org-tasks-infer     branch        5       4

# The briefing file (`Workflows.ClaudeMd`). `claude-md` is the smallest branching
# row in the table and is meant to be: one `ls` receipt, one free decider, and two
# outcomes that cannot be confused — which is the whole of the `initialize.md`
# rework. Its maxFold of 4 is the critique arm, where the decider has licensed a
# `cat`; the writing arm is 3.
pin claude-md           branch        2       4
pin claude-md-advise    branch        3       5

# The prose dial (`Workflows.Prose.Polish`). Four settings, and the number to look
# at is `prose-smooth`'s 15 paths: that is `Workflows.Escalation`'s own arithmetic
# — a three-way `revisingOn` replicates its tail 2n+1 times in the plan, and at
# `atMost 2` with three report arms that is fifteen. It is the price of an ending
# for "the reviewer would not judge it", and `smooth.md` has no such ending.
#
# `prose-compress` at 2 over 2 paths is the smallest row in the whole table, and
# it is `compressFn`'s one call site: one question inside the callee, one report,
# and a free decider between them for the refusal.
pin prose-proofread     branch        3       4
pin prose-smooth        branch       15       7
pin prose-transcript    branch        3       5
pin prose-compress      branch        2       2

# ---------------------------------------------------------------------------
# Wave 4, first half — the audits and the specialists (`doc/design.md` §8)
# ---------------------------------------------------------------------------
#
# Ten rows, six programs, and the wave's claim is legible from this table: these
# are the rows that TRANSPLANT A SUBSTANTIAL RUBRIC rather than compose waves 1-3.
# Only two of the ten call anything (`productize`'s two acting turns and
# `service-install`'s nine obligations are calls of this wave's own functions), and
# the ceilings are correspondingly the widest in the table — 31 and 23 — because
# what a specialist costs is the size of the thing it is specialising in.

# The dead-code pass (`Workflows.EliminateDeadCode`). Eleven paths, and every one of them is
# a place the corpus says "abort" or "stop": a dirty tree, a red baseline, a marker
# that escaped, a gate that never came back. Two of the eleven cost 2 and 3 -- the
# two refusals to start -- which is the whole argument for putting them first.
#
# The ceiling is the number to watch here for a reason no other row in this table
# has: `cap=N` is read in Haskell into the ACT gate's bound, so this row's price is
# a function of an input. 18 is the shape at `cap=` empty, which is two repair
# trips; `--input-arg cap=4` prices higher and `wf cost` says so before anything is
# spent. Raising the DEFAULT would be a design decision and would show here.
pin dead-code           branch       11      18

# The comment audit (`Workflows.CommentAudit`). Seventeen paths is the largest count in
# the whole table, and it is the false-positive guard's arithmetic:
# `Workflows.Escalation`'s three-way loop replicates its tail 2n+1 times in the
# plan, and at `atMost 2` with three endings under two completion gates that is
# seventeen. It is the price of an ending for "the guard would not judge these
# verdicts", and `comment-audit/SKILL.md` has no such ending -- its guardrails are
# a checklist, and a checklist has no outcome.
pin comments            branch       17      13

# External bundles (`Workflows.DiscoverBundles`). Three paths and a ceiling of 12, and the
# gap between minFold 3 and maxFold 12 is the row's entire point: the six hard
# rejection conditions are read by a free decider BEFORE the seven weighted seats,
# so a batch where nothing survives screening costs three questions instead of
# twelve. `doc/design.md` §7.2 row 12 asks for exactly that saving and this is it,
# as two numbers.
pin bundles             branch        3      12

# Productization (`Workflows.Productize`). 31 is the widest ceiling in the table and
# it is meant to be: twenty-one deliverables, one tool seat, two acting turns, a
# gate with two repair trips and a report. `productize.md` is a bullet list with no
# number anywhere in it, and this row is that list PRICED -- which is §7.2 row 42's
# whole claim.
#
# The pair is what makes `lefthook.md` a row rather than a prose reference: same
# body, same `lefthookFn`, seven of the twenty-one deliverables, and half the
# ceiling. A deliverable added to the pre-commit slice moves the second number and
# not the first, and that is visible here in one line.
pin productize          branch        6      31
pin productize-lefthook branch        6      15

# The NixOS host (`Workflows.Nix`). THREE IDENTICAL TRIPLES, and that is the row
# family's strongest evidence: `nix-rebuild`, `nix-alert` and `nix-integration`
# differ only in what their symptom IS -- a receipt, an alert payload plus its
# routing, or a pasted error with the corpus's own sample as its default -- and all
# three of those are tier 1. A difference decided in ordinary Haskell over an input
# changes a define and an argv, never a question and never a path, so three of the
# owner's commands price the same to the digit.
#
# Eight paths each: the first build's verdict has three arms, and one of those arms
# carries a two-trip gate with two endings. The `fix-alert` rework shows up here as
# an ABSENCE -- there is no compression question on any path, which is why the
# ceiling is 9 and not 10.
pin nix-rebuild         branch        8       9
pin nix-alert           branch        8       9
pin nix-integration     branch        8       9

# Services on the host (`Workflows.Service`). `service-install`'s minFold of 2 is
# the number worth reading first: the consent file is absent, so the run asks the
# owner for the certificate and the secrets and ends, having changed nothing. Its
# 23 is the other end of the same branch -- nine obligations at two questions each,
# the shape question, two health receipts and the report.
#
# `service-remove` is the tree's exemplar of structural read-only, and its numbers
# say so: twelve of its fifteen minimum consultations are questions asked at `text`,
# which have no write authority at all, and the single node in the program that can
# write anything writes a script it does not run.
pin service-install     branch        4      23
pin service-remove      branch        6      19

# ---------------------------------------------------------------------------
# Wave 4, second half — the specialists (`doc/design.md` §8)
# ---------------------------------------------------------------------------
#
# Five rows, five programs, no rungs, and what they have in common is the wave's
# closing claim: each one's READ-ONLY OR HUMAN-GATED CHARACTER IS A TYPE. `query`
# contains no `act` at all, so `wf plan query --raw` is the evidence that it
# cannot run the query it wrote; `transcribe` and `tron` contain exactly one, and
# it writes the artefact; `expense` and `qanda` put the owner in binding position,
# so their expensive arms are unreachable without his answer.
#
# Three of the five carry a three-way loop, and that is where their paths come
# from: `Workflows.Escalation`'s arithmetic replicates the tail 2n+1 times in the
# plan, so at `atMost 2` with three endings the counts are 15 and 16 rather than 3.
# The number to read is the CEILING, which is small on all three.

# The SQL query builder (`Workflows.QueryBuilder`). Sixteen paths and a ceiling of 8, and
# the one path worth naming is the minFold of 3: a draft whose first line begins
# with a write verb is refused by a free decider before the audit is asked
# anything. That is `mutatingStatement`, it costs zero questions, and it is the
# ending `query-builder.md` cannot have because nothing there reads the answer.
pin query               branch       16       8

# The expense report (`Workflows.ExpenseReport`). Seventeen paths, which is the
# `comments` count exactly and for the same reason -- a three-way loop under a
# branch -- and the branch is the level-up: the extraction's own `REVIEW` flag,
# read for nothing, chooses between a bounded revision with the owner in binding
# position and a single yes/no. Four of its six endings build NOTHING, and the two
# that build are both behind his answer.
pin expense             branch       17      10

# The decision walkthrough (`Workflows.Qanda`). Fifteen paths, a ceiling of 8, and
# a minFold of 4 -- the round where he approves the first walkthrough. `qanda.md`
# is three lines with no named input at all; this row is those three lines with an
# agenda, a bound, and an ending for a person who walks away.
pin qanda               branch       15       8

# Handwriting to Markdown (`Workflows.TranscribeImage`). The same triple as `qanda`, and
# that is not a coincidence: the two are the same shape -- one preparatory
# question, then a three-way bounded loop, then one artefact -- over two completely
# different subjects. A shared shape pricing identically is what the library is
# for.
pin transcribe          branch       15       8

# The Torch Fx pipeline (`Workflows.TronDebug`). The one row in this half whose price
# is a RANGE worth reading: 2 to 14 over 9 paths. The 2 is the control ingest
# failing, which refuses to diagnose at all; the 14 is the full differential --
# four command receipts, four IR dumps and the Fx note, four boundary readings and
# the synthesis. Seven of the nine paths are "a command did not do what this run
# needed", and each of those costs 5 or less. That gap IS `doc/design.md` §7.2
# row 65: a diagnosis is only reachable through the arms in which the commands ran.
pin tron                branch        9      14

# ---------------------------------------------------------------------------
# Wave 5 — the long ones (`doc/design.md` §8)
# ---------------------------------------------------------------------------
#
# Nine rows, five programs, and what they share is that each transplants a whole
# PROCEDURE rather than a rubric. Their paths are dominated by two things: the
# free deciders that give a procedure its endings, and `Workflows.Escalation`'s
# 2n+1 replication wherever a phase has a reviewer that may decline.

# The model-support battery (`Workflows.Retest`). ONE BODY, TWO ORACLES, and the
# gap between the two ceilings is the whole row: 16 against 37. Both have five
# paths and both have the same shape -- probe, sweep, grade, three free tests,
# five endings -- and the 21 extra consultations at `retest-categorical` are the
# fixed eight-model roster, which is eight gate processes and sixteen perf trials
# (a categorical slug and a legacy slug per model) instead of one and one.
#
# THAT NUMBER IS THE POINT OF THE ROW. `doc/design.md` §7.2 row 57 asks for
# "`costSummary` prices an eight-model FPGA run BEFORE an FPGA is touched", and
# `wf cost retest-categorical` answers 37 before a card is opened. 37 is now the
# widest ceiling in this table -- wider than `productize`'s 31 -- and it is
# honest: what an eight-model byte-identity sweep costs is eight models' worth of
# processes.
#
# The minFold of 2 on both rows is the refusal to start: `make -n <target>`
# exits nonzero, so the tree is the other rung's, and the run reports that
# without building, gating or characterising anything.
pin retest              branch        5      16
pin retest-categorical  branch        5      37

# Denotational design (`Workflows.DenotationalDesign`). Seventeen paths and a ceiling of 18,
# and the two numbers to read together are the minFold of 2 and the path count.
# The 2 is the admission test answering no -- one flag and one report, for a
# subject the method should not be applied to, which is the cheapest correct
# answer this program has and the one `## When to use, and when not` is written
# to produce. The 3 is a retrofit whose own defect inventory says to start over,
# which the skill calls a SUCCESSFUL retrofit and which costs one phase.
#
# The seventeen are `Workflows.Escalation`'s arithmetic over three report arms
# (5 x 3 = 15) plus those two early endings. The ceiling is small for a
# ten-phase design method because the phases are a CHAIN and not ten loops:
# `doc/design.md` §7.4 row 6 sketches ten `revisingOn` triples, which would be
# 5^10 paths, and the module header records the departure and what it costs.
pin denote              branch       17      18

# The translation family (`Workflows.Translate`). THREE ROWS, TWO SHAPES, and the
# table says which is which: `translate` and `translate-en` are IDENTICAL triples
# -- one body, the languages swapped, which is `nix`'s argument at another
# family -- and `translate-es` is `pipeline`, 1 path, 2 consultations, in a
# three-way tie for the smallest row in the whole table with `second-opinion`
# (its exact structural match: pipeline, 1 path, 2) and `prose-compress`
# (branch, 2 paths, 2).
#
# The 15 paths are `Workflows.Escalation`'s 2n+1 over three report arms again. The
# 23 is two rounds of a six-seat review plus the terminology brief, the draft and
# the delivery; the minFold of 9 is the same run settling on the first round, and
# the gap between those two numbers is the bound `persian/SKILL.md` states without
# one ("run Phase 3 again on the synthesis, and then come back here to phase 4").
#
# `translate-es` at 2 is the row that keeps the family honest: its source file is
# an instruction block and a task, it names no reviewer, and its price says so
# rather than borrowing its siblings' apparatus.
pin translate           branch       15      23
pin translate-en        branch       15      23
pin translate-es        pipeline      1       2

# The requirements pair (`Workflows.PrdArchitect`). TWO ROWS BECAUSE ONE FILE WAS TWO
# AGENTS, and this is the line of the table that shows what `doc/design.md` §7.3's
# R -> 2xT rework bought: 19 against 11, and 18 paths against 3. The fused file
# has one number for both, which is no number.
#
# `prd-draft`'s minFold of 2 is the refusal to overwrite: a `test -f` says a PRD
# already stands, and the run reports that and names `prd-critique`. Its 18 paths
# are three cheap endings -- already there, not confirmed, open questions -- plus
# `Workflows.Escalation`'s 5x3 over the verification loop's three arms.
#
# `prd-critique`'s minFold of 2 is the mirror: nothing at the path, so nothing was
# asked of anybody, and seven analysis axes over a document that does not exist
# were not run. Its 3 paths carry no loop at all, which is correct for a row whose
# whole job is to read: there is nothing to revise, because nothing in the row can
# write.
pin prd-draft           branch       18      19
pin prd-critique        branch        3      11

# Flows on the owner's own host (`Workflows.NodeRed`). Four paths, and the
# NARROWEST range in this half of the table: 15 to 17. That is what a program
# looks like when almost nothing in it is a judgment -- four receipts, six seats
# over one fetched tab, one edit, one staging act, one validator, one put and one
# refetch -- and the two consultations of spread are the put and the confirming
# refetch, which only the arm that validated reaches.
#
# The four endings are the validator's three tags plus the event log's row count:
# put with history, put where the node had NEVER fired in twenty-four hours (which
# this host's own debugging rule reads as an upstream problem, so the report says
# the change may not be the fix), not put because the envelope did not validate,
# and not put because the validator did not run. Two of the four write nothing.
pin nodered             branch        4      17

# Pinned evidence to a deterministic design report (`Workflows.Taskmaster`). Four
# nested one-repair revisions yield 46 complete/exhausted paths and a finite
# ceiling of 22. `--scripted` proves the Program shape but executes no command;
# `ci/taskmaster.sh` separately runs every schema gate, one repair and exhaustion.
pin taskmaster           branch       46      22

# ---------------------------------------------------------------------------
# Wave 5's last row — the top of the loop (`doc/design.md` §8)
# ---------------------------------------------------------------------------
#
# The gate of the whole wave, and it is this line: `wf cost wiggum` reports
# `minFold 2, maxFold 44, over 34 paths`. A FINITE WORST CASE, printed before the
# first round — which is the one number an autonomous work loop must have and the
# one `skills/wiggum/SKILL.md` cannot state. Every bound in that file is a word
# ("a bounded number of attempts (default 3)", "roughly 3-5 at a time", "every
# four hours or so"); all three are numbers here, and 44 is what they add up to.
#
# 44 IS THE SECOND WIDEST CEILING IN THIS TABLE — wider than
# `retest-categorical`'s 37 and `productize`'s 31, and displaced only by
# `wiggum-duet`'s 50, which is this row's loop with a four-seat review between
# the rounds — and that is correct rather than alarming: five of the
# row's seven declared callees belong to other rows, so what it costs is what the
# toolbox it sits on top of costs. Read it against the minFold of 2, which is the
# refusal to start — the parent-history sentinel probe did not pass, so no round
# ran, nothing was committed and nothing was audited. The two cheapest paths in
# this row (2 and 3) both change the tree not at all.
#
# The 34 paths are six endings over the shape: two terminals before any work (an
# unproven runner, a red baseline), and then, per round-count arm, a conflict
# terminal plus `Workflows.Escalation`'s 2n+1 replication at `atMost 2` over
# three report arms — 1 + 15 twice, plus the two early refusals. A third round
# would be a design decision and would show here.
pin wiggum              branch       34      44

# The same loop across two live panes (`Workflows.WiggumDuet`). THREE OF THE FOUR
# NUMBERS ARE `wiggum`'s TO THE DIGIT — `branch`, 34 paths, and a minFold of 2 —
# and that is the whole claim the row makes about itself: it adds one `call` and
# NO branch, and a call is consultations rather than paths.
#
# The one number that moves is the ceiling, 44 -> 50, and it is exactly
# `duetReviewFn`: four partner seats, one publishing act, one directory receipt,
# bought ONCE and only on the two-round arm, which is the arm the maximum lives
# on. The one-round arm prices exactly as `wiggum`'s does, because a review whose
# findings nothing could consume is spend with no consumer — read the two fold
# lists side by side and the six shows up in four places and nowhere else:
#
#   wiggum       2, 3, 11, 16, 35 (x6), 37 (x6), 39 (x3), 40 (x6), 42 (x6), 44 (x3)
#   wiggum-duet  2, 3, 11, 22, 35 (x6), 37 (x6), 39 (x3), 46 (x6), 48 (x6), 50 (x3)
#
# 50 IS NOW THE WIDEST CEILING IN THIS TABLE, displacing `wiggum`'s 44, and for
# the same reason that one was honest: what a loop costs is what the toolbox it
# sits on top of costs, and this one sits on top of `wiggum`.
#
# The four partner seats are a DESIGN DECISION and this is where it is recorded:
# `review-heavy`'s roster has seven, which would price this row at 53. A review
# that runs inside a bounded loop is a different economic object from
# `partner-reviewer`, which runs once beside it, and three more opinions on a
# round that is about to be revised anyway are three consultations. Seven is a
# decision the owner may take with `wf cost` in hand; four is what is pinned.
pin wiggum-duet         branch       34      50

# ---------------------------------------------------------------------------
# The binary, resolved once
# ---------------------------------------------------------------------------
#
# `cabal list-bin` and not `cabal run`, for the reason `wf` must be a real binary
# on PATH: every `running` party's argv executes in the process's working
# directory, and `cabal run` may move it. A gate that ran the toolbox from
# somewhere else would be answering `git diff` about another repository.

cabal build all > "$work/build" 2>&1 \
  || { echo "ci/workflows: the build failed:" >&2; cat "$work/build" >&2; exit 1; }

# Zero warnings is part of the gate: a warning nobody can fix is a warning
# everybody learns to scroll past.
#
# The pattern is GHC's own — `FILE:LINE:COL: warning:` — and deliberately not a
# search for the word. cabal writes `Warning: The package list for
# 'hackage.haskell.org' is 30 days old` on a machine that has not run
# `cabal update` recently, which is a fact about the index and not about this
# code; a gate that went red for it would be turned off within the week.
if grep -qE "^[^[:space:]].*:[0-9]+:[0-9]+: warning:" "$work/build"; then
  echo "ci/workflows: the build warned:" >&2
  grep -nE "^[^[:space:]].*:[0-9]+:[0-9]+: warning:" -A6 "$work/build" >&2
  failures=$((failures + 1))
fi

wf=$(cabal list-bin exe:wf 2>/dev/null | tail -1)
[ -x "$wf" ] || { echo "ci/workflows: no wf binary: '$wf'" >&2; exit 1; }

# ---------------------------------------------------------------------------
# The registry, read from the binary
# ---------------------------------------------------------------------------

"$wf" list > "$work/list" 2>&1
registered=$(sed -n 's/^  \([^ ][^ ]*\)  .*/\1/p' "$work/list")
[ -n "$registered" ] || {
  echo "ci/workflows: could not read the registry: $(cat "$work/list")" >&2
  exit 1
}

for n in $registered; do
  [ -n "${pinLevel[$n]+set}" ] \
    || bad "$n" registry "a pinned row" "registered, and pinned nowhere in ci/workflows.sh"
done
for n in "${names[@]}"; do
  echo "$registered" | grep -qx "$n" \
    || bad "$n" registry "a registered workflow" "pinned here, and registered nowhere"
done

# ---------------------------------------------------------------------------
# The pin rosters `judgeIsElsewhere` is given, held to the program's own answer
# ---------------------------------------------------------------------------
#
# `Workflows.Deciders.judgeIsElsewhere` compares the judge's backend against the
# backend of every pin the WORK reaches, and the list of those pins is STATIC —
# `Workflows.Parties.ladderPins`, and `routablePins` less the judge's own at
# `Workflows.WiggumDuet.duetWorkPins`. It has to be static: the gate is tier 1 and runs
# before the `Program` exists, so it cannot ask the program. That makes the list
# the one part of the gate that could rot silently — a rung added to the ladder
# and not to the list would be a name the judge is never compared against, which
# is a hole shaped exactly like the one this check exists to keep shut.
#
# So it is checked from OUTSIDE the source, against `pinnedModels` — the primaries
# and their spares off the built program's own served chains, published by
# `list --json` under `pins`, which is also exactly the set `--route` will accept.
# A name in one and not the other fails here.
"$wf" list --json > "$work/list.json" 2>&1

# Bare `wf` is the usage on stderr under exit 1; `--help` is the same payload
# on stdout under exit 0. The human catalog is complete, ordered, and bounded;
# the machine catalog keeps the full prose.
"$wf" --help > "$work/usage.out" 2> "$work/usage.err"
code=$?
[ "$code" = 0 ] || bad "--help" "exit" 0 "$code"
[ -s "$work/usage.out" ] || bad "--help" "stdout" "the usage" "empty"
[ ! -s "$work/usage.err" ] \
  || bad "--help" "stderr" "empty" "$(head -1 "$work/usage.err")"

"$wf" > "$work/usage.bare.out" 2> "$work/usage.bare.err"
code=$?
[ "$code" = 1 ] || bad "bare wf" "exit" 1 "$code"
[ ! -s "$work/usage.bare.out" ] \
  || bad "bare wf" "stdout" "empty" "$(head -1 "$work/usage.bare.out")"
[ -s "$work/usage.bare.err" ] || bad "bare wf" "stderr" "the usage" "empty"
sed '1s/^wf: //' "$work/usage.bare.err" > "$work/usage.bare"
cmp -s "$work/usage.bare" "$work/usage.out" \
  || bad "bare wf" "usage payload" "the --help bytes" "different"

usage_registered=$(sed -n \
  '/^  <workflow> is one of:$/,/^$/s/^  \([^ ][^ ]*\)  .*/\1/p' \
  "$work/usage.out")
[ "$usage_registered" = "$registered" ] \
  || bad wf "usage catalog names" "$registered" "$usage_registered"
while read -r n; do
  [ -n "$n" ] || continue
  doc=$(sed -n "/^  <workflow> is one of:$/,/^$/s/^  $n  *//p" "$work/usage.out")
  [ -n "$doc" ] || bad "$n" "usage summary" "one line" "empty"
done <<< "$usage_registered"
too_wide=$(awk 'length($0) > 80 { print NR ":" length($0); exit }' "$work/usage.out")
[ -z "$too_wide" ] || bad wf "usage line width" "at most 80" "$too_wide"

full_blurb=$(sed -n 's/^  retest-categorical  *//p' "$work/list")
# Split only at top-level row boundaries. `capabilities` is now a nested object
# between `blurb` and `name`, so splitting at every `{` loses the blurb before
# the line on which the name appears.
json_blurb=$(
  sed 's/},{"askNodes"/\n{"askNodes"/g' < "$work/list.json" \
    | grep '"name":"retest-categorical"' \
    | sed -n 's/.*"blurb":"\([^"]*\)".*/\1/p'
)
[ "$json_blurb" = "$full_blurb" ] \
  || bad retest-categorical "JSON blurb" "$full_blurb" "$json_blurb"
[ "${#json_blurb}" -gt 80 ] \
  || bad retest-categorical "JSON blurb length" "more than 80" "${#json_blurb}"
usage_blurb=$(sed -n \
  '/^  <workflow> is one of:$/,/^$/s/^  retest-categorical  *//p' \
  "$work/usage.out")
case "$usage_blurb" in
  *…) ;;
  *) bad retest-categorical "usage summary" "a deterministic ellipsis" "$usage_blurb" ;;
esac

# The `pins` array of one row, comma-separated, in `pinnedModels`' own sorted
# order. Python's standard JSON parser survives nested descriptor-v2 input
# objects without adding a package dependency.
pinsOf() {
  python3 - "$work/list.json" "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    rows = json.load(stream)
row = next(row for row in rows if row["name"] == sys.argv[2])
print(",".join(row["pins"]))
PY
}

# `Workflows.Parties.routablePins` — the four ladder rungs and the two pins.
duetPins="fable,gemini-3.1-pro-preview,gpt-5.5-pro,opus,partner,worker"
# `Workflows.Parties.ladderPins` — this row pins no pane, so the rungs are all of
# it, and `opus` among them is BOTH its judge's pin and its round account's.
wiggumPins="fable,gemini-3.1-pro-preview,gpt-5.5-pro,opus"

got=$(pinsOf wiggum-duet)
[ "$got" = "$duetPins" ] \
  || bad wiggum-duet "routablePins against the program's pins" "$duetPins" "$got"
got=$(pinsOf wiggum)
if [ "$got" = "$wiggumPins" ]; then
  note "the gate's pin rosters match the programs': 6 at wiggum-duet, 4 at wiggum"
else
  bad wiggum "ladderPins against the program's pins" "$wiggumPins" "$got"
fi

# Every row's one line, because `wf list` is what an operator browses and a blank
# line is a row nobody can choose.
while read -r n; do
  [ -n "$n" ] || continue
  doc=$(sed -n "s/^  $n  *//p" "$work/list")
  [ -n "$doc" ] || bad "$n" blurb "one line" "empty"
done <<< "$registered"

# ---------------------------------------------------------------------------
# No row's name is a verb
# ---------------------------------------------------------------------------
#
# `Agentic.Cli`'s parse order decides a verb in head position BEFORE a row name
# is ever looked up, so a row named `plan` would not be ambiguous — it would be
# unreachable by name, which is exactly the kind of thing a gate should shout
# about rather than a thing to discover. Checked against the real registry, not
# against a literal transcribed from it.
while read -r n; do
  [ -n "$n" ] || continue
  case "$n" in
    list | plan | cost | run | help)
      bad "$n" "the reserved verbs" "a name that is not a verb" "$n"
      ;;
  esac
done <<< "$registered"

# ---------------------------------------------------------------------------
# Every row's page
# ---------------------------------------------------------------------------
#
# `wf help <row>` is HALF COMPUTED AND HALF AUTHORED, and this block holds the
# authored half to the shape `doc/research/help-design.md` §3 specifies while
# leaving the computed half to the pins above. Eight things, per row:
#
#   1. `help NAME` exits 0 and says something.
#   2. `NAME --help` — the owner's own spelling, and the ruling's — is BYTE
#      IDENTICAL to it. Two spellings, one renderer, one thing to keep true.
#   3. The body carries the four headings a page is made of. A page missing
#      `**Transport.**` is a page that does not answer the question the ruling
#      asked ("which arguments and patterns would be useful").
#   4. Every declared input is named in the body as `` `name` ``, and no
#      `--input-arg X=` or `--input-file X=` in the body names an X the row does
#      not declare. THAT is the check that catches a renamed input against a
#      stale page, in the direction that actually happens.
#   5. Two fenced blocks at least: the first is a live line and must NOT carry
#      `--scripted`, the last is the rehearsal and must begin exactly
#      `wf run NAME --scripted`. The guard is not decorative — a live line
#      pasted into a rehearsal block is what a reader would copy.
#   6. The body restates NO price. `minFold`, `maxFold` and `over N paths` are
#      the header's, computed from the same `Facts` the pins above read, and a
#      hand-copied number in the prose could only ever disagree with them; and
#      no page claims a place in the table's PRICE ORDER, which is the same
#      defect written in words instead of digits.
#   7. THE PRINTED LIVE LINE PARSES, AND NAMES ONE TRANSPORT. Run against a row
#      name no registry holds, so it stops at the registry lookup — see
#      `targetCheck`.
#   8. THE PRINTED REHEARSAL RUNS. Not `inputsFor`'s spelling of it: the printed
#      one, word for word, at exit 0 — and its input names are still compared
#      against `list --json`'s `inputs`, because a rehearsal can run green while
#      naming the wrong things.
#
# WHY 7 AND 8 ARE BOTH HERE. A page is a thing a reader PASTES, so the evidence
# that has to exist is that the bytes on it work — not that a command spelled
# elsewhere in this file works. Held to `inputsFor`, a page could print any
# transport at all and stay green: that is how `account-halt` came to print
# `--session "$PANE" --scratch "$PWD"`, which the CLI refuses, for as long as it
# did.

# Input names in declaration order. Descriptor v1 used strings; v2 records
# each name and source. Accept both while the runner catalogue is upgraded.
inputsOf() {
  python3 - "$work/list.json" "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    rows = json.load(stream)
row = next(row for row in rows if row["name"] == sys.argv[2])
print(",".join(value if isinstance(value, str) else value["name"] for value in row["inputs"]))
PY
}

# The authored half of a page: everything below the computed header and above
# the footer. Both ends are `Agentic.Cli`'s and neither is a row's, so neither
# may be held to a row's rules.
helpBody() { sed -e '1,/^  pins /d' -e '/^  wf --help lists the flags/,$d' "$1"; }

# The nth fenced `sh` block of a body, whole — continuation lines included,
# because a rehearsal that wraps is still one command line.
fenceAt() { tail -n +"$(($2 + 1))" "$1" | sed -n '1,/^```$/p' | sed '$d'; }

# A fenced block as ONE line: the trailing backslashes dropped and the newlines
# closed up, which is what the shell does with a continuation and therefore what
# a reader who pasted the block would get.
oneLine() { fenceAt "$1" "$2" | sed -e 's/[[:space:]]*\\$//' | tr '\n' ' '; }

# A row name no registry holds, and the three pane ids the pages spell.
#
# The panes are set because a page's live line is written for an operator who
# HAS two panes — `--route "partner=deck:$PANE_R"` against an unset variable is
# `deck:` and refuses for a reason that is about this gate's environment rather
# than about the page. Standing in as that operator is the point.
sentinel="ci-no-such-row-and-never-will-be"
export PANE=ci-pane PANE_R=ci-pane-reviewer PANE_W=ci-pane-work

if echo "$registered" | grep -qx "$sentinel"; then
  # Not a `bad`: if this name were ever registered the check below would RUN a
  # row live, which is the one thing no gate here may do by accident.
  echo "ci/workflows: '$sentinel' is a registered row; pick another sentinel" >&2
  exit 1
fi

# THE PRINTED LIVE LINE, RUN — against the sentinel name, so that it stops.
#
# `Agentic.Cli.parseCommand` chooses the run's TARGET while it is still parsing:
# `chooseTarget` decides which of the three transports a combination of flags
# names, and refuses every combination that names two — `--scratch` under
# `--session`, `--adapter` under a deck run, `--scripted` beside either. Only
# after that does the command look the row up. So a live line typed with a name
# no registry holds is driven through every one of those refusals and then stops
# at `no workflow named`, having started no adapter, opened no session and spent
# nothing.
#
# That is the whole check: a line that could not run refuses in the TRANSPORT's
# words, and a line that could refuses in the registry's. Appending `--json`
# instead was considered and does not work — `--json` is refused by the option
# loop, several arms before `chooseTarget` is reached, so it passes a line the
# CLI would refuse.
#
# `eval`, because the page is quoted the way a command line is (`--scratch
# "$PWD"`, `--input-arg trip='Boston, June 2026'`) and word-splitting would tear
# those apart. Two things are done to the line first, and both are the
# difference between reading a command line's SHAPE and obeying it.
#
#   * EVERY COMMAND SUBSTITUTION IS REPLACED BY A PLACEHOLDER. Eight pages spell
#     a value as one — `--input-arg tree="$(git add -A && git write-tree)"` is
#     the commit family's, and running it would stage this gate's own working
#     tree. A substitution is a hole the reader fills, not part of the line's
#     shape, and what is under test here is which transport the FLAGS name.
#   * WHAT IS LEFT MUST BE A PLAIN COMMAND LINE. After the holes are out, a
#     page carrying a `;`, a pipe, a redirect or a backtick is a page this gate
#     fails rather than executes.
targetCheck() {
  local n="$1" line="$2" rest out code

  line=$(printf '%s' "$line" | sed -e 's/\$([^)]*)/SUBSTITUTION/g' -e 's/`[^`]*`/SUBSTITUTION/g')

  case "$line" in
    *';'* | *'|'* | *'&'* | *'`'* | *'$('* | *'>'* | *'<'*)
      bad "$n" "the page's live line" "a plain command line" "it carries a shell metacharacter"
      return
      ;;
  esac

  rest=${line#wf run $n }
  out=$(eval "$(printf '%q' "$wf") run $(printf '%q' "$sentinel") $rest +RTS -N8 -RTS" < /dev/null 2>&1)
  code=$?

  if [ "$code" != 1 ]; then
    bad "$n" "the page's live line, parsed" "exit 1 at the registry" "$code"
    echo "  $line" >&2
    echo "  $out" | head -3 >&2
  elif ! echo "$out" | grep -q "no workflow named"; then
    # It got as far as a transport refusal, which means the flags on the page
    # do not name a transport this CLI will take. The refusal says which.
    bad "$n" "the page's live line" "a transport the CLI takes" "$(echo "$out" | head -1)"
    echo "  $line" >&2
  fi

  # THE ONE FLAG ON THE LINE THAT IS THE ROW'S AND NOT THE TRANSPORT'S.
  # `--require-pinned` refuses the program unless every model ask names the
  # model that serves it, and whether it does is a fact about THIS row — which
  # is exactly what the sentinel above cannot see, because it stops before the
  # row is looked up. `plan` is the verb that answers it: same check, before
  # anything is printed, started or spent. A page that prints the flag against a
  # row that cannot satisfy it prints a line that does not run, which is the
  # defect this whole block is about, wearing a different flag.
  case "$line" in
    *--require-pinned*)
      "$wf" plan "$n" --require-pinned > /dev/null 2>&1 \
        || bad "$n" "the page's live line" "--require-pinned, which this row satisfies" "the program is refused under it"
      ;;
  esac
}

helpCheck() {
  local n="$1" page="$work/$1.help" alt="$work/$1.help.alt" body="$work/$1.helpbody"
  local code declared given fences first last firstLine lastLine want got
  local -a rehearsal

  "$wf" help "$n" > "$page" 2>&1
  code=$?
  [ "$code" = 0 ] || { bad "$n" "help exit" 0 "$code"; return; }
  [ -s "$page" ] || { bad "$n" "help" "a page" "empty"; return; }

  # The ruling's own spelling, and the verb-first one, are one renderer.
  "$wf" "$n" --help > "$alt" 2>&1
  cmp -s "$page" "$alt" \
    || bad "$n" "help NAME against NAME --help" "byte-identical" "they differ"

  helpBody "$page" > "$body"
  for want in '\*\*Inputs\.\*\*' '\*\*Transport\.\*\*' '\*\*Rehearsal\.\*\*' '\*\*Caveats\.\*\*'; do
    grep -q "$want" "$body" \
      || bad "$n" "the page's sections" "$(echo "$want" | tr -d '\\')" "absent"
  done

  # A price is the header's to state. `over N path` is spelled as the summary
  # spells it, so a body that quoted the line would be caught by any of three.
  for want in minFold maxFold; do
    grep -q "$want" "$body" \
      && bad "$n" "the page's prose" "no price restated" "it names $want"
  done
  grep -qE ' over [0-9]+ path' "$body" \
    && bad "$n" "the page's prose" "no price restated" "it names a path count"

  # And no page claims a rank in the table's price order. "the cheapest ending"
  # is a claim about THIS row's own paths and is fine — the header's two bounds
  # are exactly that claim's evidence. "the cheapest command in the toolbox" is
  # a claim about seventy-three other rows, nothing in the header can check it,
  # and re-pricing any one of them falsifies it silently. That is a hand-copied
  # price with the digits left out, so it is banned where the digits are.
  grep -qiE '(cheapest|costliest|priciest|dearest|most expensive)[^.]*(in the (toolbox|table)|of the (seventy-two|seventy-three|seventy-four|rows)|of any (row|workflow)|registered row)' "$body" \
    && bad "$n" "the page's prose" "no rank in the price order" "a superlative across the table"
  grep -qiE "(toolbox|table)'s [a-z]* ?(cheapest|costliest|priciest|dearest|most expensive)" "$body" \
    && bad "$n" "the page's prose" "no rank in the price order" "a superlative across the table"

  # Every declared input named, and no flag naming an input that is not one.
  declared=$(inputsOf "$n" | tr ',' ' ')
  for want in $declared; do
    grep -q '`'"$want"'`' "$body" \
      || bad "$n" "the page's inputs" "\`$want\` named in the prose" "absent"
  done
  given=$(grep -oE -- '--input-(arg|file) [A-Za-z0-9_]+=' "$body" \
            | sed -e 's/^--input-[a-z]* //' -e 's/=$//' | sort -u)
  for got in $given; do
    echo " $declared " | grep -q " $got " \
      || bad "$n" "the page's flags" "only declared inputs" "--input-… $got="
  done

  # Two blocks: a live line, then the rehearsal. The order is the page's, and
  # the guard on the last one is what keeps a live command out of a block a
  # reader is invited to paste.
  fences=$(grep -c '^```sh$' "$body")
  if [ "$fences" -lt 2 ]; then
    bad "$n" "the page's blocks" "at least 2" "$fences"
    return
  fi
  first=$(grep -n '^```sh$' "$body" | head -1 | cut -d: -f1)
  last=$(grep -n '^```sh$' "$body" | tail -1 | cut -d: -f1)
  firstLine=$(fenceAt "$body" "$first" | head -1)
  lastLine=$(fenceAt "$body" "$last" | head -1)

  case "$firstLine" in
    "wf run $n "*) ;;
    *) bad "$n" "the page's live line" "wf run $n …" "$firstLine" ;;
  esac
  case "$firstLine" in
    *--scripted*) bad "$n" "the page's live line" "a live transport" "--scripted" ;;
  esac
  case "$lastLine" in
    "wf run $n --scripted"*) ;;
    *) bad "$n" "the page's rehearsal" "wf run $n --scripted …" "$lastLine" ;;
  esac

  # The live line, driven through `chooseTarget` and stopped at the registry.
  targetCheck "$n" "$(oneLine "$body" "$first")"

  # The rehearsal names exactly the row's inputs, each `--input-arg NAME=` and
  # empty — and then it is RUN, as printed. `inputsFor` above spells the same
  # command for the same row, and for a while that was taken as reason enough
  # not to run this one; but `inputsFor` is a table in this file and the
  # rehearsal is bytes on a page, and the whole claim a page makes is that its
  # bytes work. The naming check stays beside the run, because a rehearsal can
  # be green and still name the wrong inputs.
  fenceAt "$body" "$last" | grep -q -- '--input-file' \
    && bad "$n" "the page's rehearsal" "--input-arg NAME= for every input" "--input-file"
  fenceAt "$body" "$last" | grep -qE -- '--input-arg [A-Za-z0-9_]+=[^ \\]' \
    && bad "$n" "the page's rehearsal" "every input empty" "a value"
  want=$(echo "$declared" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')
  got=$(fenceAt "$body" "$last" \
          | grep -oE -- '--input-(arg|file) [A-Za-z0-9_]+=' \
          | sed -e 's/^--input-[a-z]* //' -e 's/=$//' | sort -u | tr '\n' ' ')
  [ "$want" = "$got" ] \
    || bad "$n" "the page's rehearsal inputs" "$want" "$got"

  # Run it. Every value is empty and there is no `--input-file` — both asserted
  # just above — so the printed block splits into words on whitespace and no
  # `eval` is wanted here: unlike the live line, this one carries no quoting to
  # preserve. stdin is /dev/null, for the reason the priced run has it: a
  # scripted run asks nobody, and this is what makes that a fact.
  read -r -a rehearsal <<< "$(oneLine "$body" "$last")"
  "$wf" "${rehearsal[@]:1}" < /dev/null > "$work/$n.rehearsal" 2>&1
  code=$?
  [ "$code" = 0 ] || {
    bad "$n" "the page's rehearsal, run as printed" "exit 0" "$code"
    tail -5 "$work/$n.rehearsal" >&2
  }
}

# ---------------------------------------------------------------------------
# Every row, field by field
# ---------------------------------------------------------------------------

# The value on a `  <label>   <value>` line, or the empty string.
field() { sed -n "s/^  *$2  *//p" "$1" | head -1; }

for n in "${names[@]}"; do
  inputsFor "$n"

  "$wf" plan "$n" > "$work/$n.plan" 2>&1
  code=$?
  [ "$code" = 0 ] || bad "$n" "plan exit" 0 "$code"

  got_level=$(field "$work/$n.plan" level)
  [ "$got_level" = "${pinLevel[$n]}" ] || bad "$n" level "${pinLevel[$n]}" "$got_level"

  # `paths` and `maxFold` both come off the one cost summary line, which `plan`
  # and `cost` share so the two verbs cannot disagree about them.
  summary=$(field "$work/$n.plan" cost)
  got_paths=$(echo "$summary" | sed -n 's/.*over \([0-9][0-9]*\) path.*/\1/p')
  [ "$got_paths" = "${pinPaths[$n]}" ] || bad "$n" paths "${pinPaths[$n]}" "$got_paths"

  "$wf" cost "$n" > "$work/$n.cost" 2>&1
  code=$?
  [ "$code" = 0 ] || bad "$n" "cost exit" 0 "$code"

  got_max=$(field "$work/$n.cost" costSummary | sed -n 's/.*maxFold \([0-9][0-9]*\).*/\1/p')
  if [ -z "$got_max" ]; then
    bad "$n" costMax "a number" "no maxFold on the costSummary line"
  elif [ "$got_max" -gt "${pinCeiling[$n]}" ]; then
    bad "$n" costMax "at most ${pinCeiling[$n]}" "$got_max"
  fi

  # stdin is /dev/null: a scripted run asks nobody, and this is what makes that a
  # fact rather than a hope.
  "$wf" run "$n" --scripted "${ins[@]}" +RTS -N8 -RTS < /dev/null > "$work/$n.run" 2>&1
  code=$?
  [ "$code" = 0 ] || {
    bad "$n" "run --scripted exit" 0 "$code"
    tail -20 "$work/$n.run" >&2
  }

  helpCheck "$n"

  note "$n: ${pinLevel[$n]}, ${got_paths} path(s), costMax $got_max of ${pinCeiling[$n]}; scripted exit $code"
done

# `hello-world` is the result-channel regression: the translation must be the
# final text result, not merely the last trace event followed by unit.
grep -q '^    result  *text$' "$work/hello-world.run" \
  || bad hello-world "final result" "a text result block" "absent"
grep -q '¡Hola, mundo!' "$work/hello-world.run" \
  || bad hello-world "final result value" "the canned Spanish translation" "absent"
grep -q '^    answer  *()' "$work/hello-world.run" \
  && bad hello-world "final result" "not unit" "answer ()"

note "help: ${#names[@]} page(s) checked — sections, both spellings, no price restated, and both printed command lines run"

# ---------------------------------------------------------------------------
# The `Agentic.Cli` contract
# ---------------------------------------------------------------------------
#
# This binary serves ITS OWN table under ITS OWN noun. `Agentic.Cli` is one
# function in agent-cat and both registries call it, so the outside evidence that
# `regNoun` and `regBinary` are still doing their job is that a refusal here is
# spelled in this registry's words and not in the examples'.

"$wf" plan --no-such-workflow > "$work/refusal" 2>&1
if grep -q "no workflow named" "$work/refusal"; then
  note "wf refuses in its own noun: two registries, one CLI"
else
  bad wf "the registry's noun" "no workflow named …" "$(cat "$work/refusal")"
fi

# ---------------------------------------------------------------------------
# The one thing a scripted run cannot prove: `wiggum-duet`'s refusal arm
# ---------------------------------------------------------------------------
#
# The loop above pins the SHAPE and the PRICE of every row and nothing else, and
# for `wiggum-duet` that is deliberately not enough. Its first gate is
# `Workflows.Deciders.judgeIsElsewhere` over `run.routes` and `run.engine`, and
# ONLY `run` binds a run fact — so `plan`, `cost` and `--scripted` all take the
# loop, which is right (an unknown table must price as the shape that keeps every
# check) and means the refusal is reachable from a command line and from nowhere
# else. So two command lines are run here, and between them they cover both
# refusing rows of the design's decision table.
#
# THREE DEPARTURES FROM THE DESIGN'S §6.2, RECORDED RATHER THAN GLOSSED.
#
#   1. It said "no adapter and no session needed, because the gate fires before
#      the first question". The gate does fire first, but the refusing program is
#      not empty: it calls `duetReportFn`, which is an `act`, which is a
#      question — so a live-shaped transport IS needed for the one turn the
#      refusal spends. That is agent-cat's deck STUB, pointed at by `--binary`,
#      same fixture `agent-cat/engine/agent-deck/ci/deck.sh` runs; it answers an `ack`
#      question with `DONE` and reaches no network and no agent.
#
#   2. It said row 7 — the inverted split — was "the one worth pinning, since it
#      is the one an operator will type". It is pinned, but NOT as the program's
#      own refusal, because it cannot be: `Agentic.Cli`'s `--route` check runs
#      against the program the run facts BUILT, and on a refusing row those facts
#      have already selected the refusal program, whose only ask is a tool. A
#      program that pins no model refuses every `--route` by name, so NO routed
#      refusal — row 5, row 7, or the ladder-rung attack below — ever reaches
#      `judgeIsElsewhere`'s WORDS. It reaches the predicate: the gate is what
#      selected the refusal program, and the CLI's complaint is downstream of
#      that verdict rather than instead of it. The operator is still refused
#      before anything is spent, which is the guarantee that matters, but in the
#      CLI's words and not the gate's, and the CLI's words ("it pins no model at
#      all") are true of the refusal program and misleading about the row, which
#      pins six. That is agent-cat's to settle if it is worth settling; here it is
#      pinned as the behaviour that actually happens, so a change to it is a
#      change somebody notices.
#
#   3. Row 4 — an unrouted `--session` run, where judge and work both fall to the
#      default — is therefore the ONLY reachable spelling of the program's own
#      refusal, and it is where the gate's own words are checked.
#
# `cabal.project` already requires the sibling tree, so the fixture is present
# whenever this gate can build at all; it is guarded anyway, because a gate that
# dies on a missing fixture teaches nothing.

stub="../agent-cat/engine/agent-deck/test/stub-deck.sh"

# The row's inputs from the one place that spells them, so a fifth input reaches
# these two command lines by being added there and nowhere else.
inputsFor wiggum-duet

if [ ! -x "$stub" ]; then
  bad wiggum-duet "the deck stub" "an executable at $stub" "missing or not executable"
else
  # DECISION-TABLE ROW 4. One pane, no route: J == W == D, and the run refuses in
  # the program's own words, having put exactly one question — the report every
  # ending owes its operator.
  DECK_STUB_STATE="$work/one-pane" \
    "$wf" run wiggum-duet \
      --session one-pane \
      --binary "$stub" --poll 20 --timeout 30000 \
      "${ins[@]}" \
      +RTS -N8 -RTS \
      < /dev/null > "$work/row4.run" 2>&1
  code=$?
  [ "$code" = 0 ] || {
    bad wiggum-duet "row 4's exit" 0 "$code"
    tail -20 "$work/row4.run" >&2
  }

  # The gate-unique sentence, not the shared banner: the probe-failure ending
  # also prints WORK BLOCKED, so matching that alone cannot tell the two apart.
  grep -q "This run puts the judgment in a conversation the work also reaches" \
    "$work/row4.run" \
    || bad wiggum-duet "row 4: the refusal's wording" \
         "the gate's own sentence" "not in the run's output"

  # The fact the refusal is made of, quoted into the report by the run rather
  # than described: `run.routes`, in the header's own spelling.
  grep -q "(default) = deck:one-pane" "$work/row4.run" \
    || bad wiggum-duet "row 4: run.routes in the report" \
         "(default) = deck:one-pane" "not in the run's output"

  # A refusal the size of a refusal: ONE question put, and it is the report. Its
  # `effect` intent is the write authority; a run that had started the loop would
  # have put the sentinel probe first.
  put=$(grep -c '^  effect ack -> tool write-report' "$work/row4.run")
  [ "$put" = 1 ] \
    || bad wiggum-duet "row 4: questions put" 1 "$put report act(s)"
  if grep -q "model independence" "$work/row4.run"; then
    bad wiggum-duet "row 4: the refused run" "no probe" "the sentinel probe was put"
  fi

  # DECISION-TABLE ROW 7. The inversion, refused earlier and by somebody else —
  # see departure 2 above. Nonzero, and no question at all.
  DECK_STUB_STATE="$work/inverted" \
    "$wf" run wiggum-duet \
      --session judge-pane \
      --route worker=deck:work-pane \
      --binary "$stub" --poll 20 --timeout 30000 \
      "${ins[@]}" \
      +RTS -N8 -RTS \
      < /dev/null > "$work/row7.run" 2>&1
  code=$?
  [ "$code" = 0 ] && bad wiggum-duet "row 7's exit" "nonzero" 0
  grep -q "never pins" "$work/row7.run" \
    || bad wiggum-duet "row 7: the refusal" \
         "--route names the model 'worker', which this workflow never pins" \
         "$(head -1 "$work/row7.run")"
  [ -d "$work/inverted" ] \
    && bad wiggum-duet "row 7: what was spent" "nothing" "the stub was reached"

  # A LADDER RUNG ROUTED ALONGSIDE THE JUDGE, which is the invocation a
  # two-name gate accepted. `partner` and `opus` on one pane leaves the judge
  # off the default and off `worker`, so the old predicate said "elsewhere" and
  # the loop STARTED — with `model "decompose"`, `model "resolve"`,
  # `model "cleanup-review"` and the audit's `reasoning` stances answering in the
  # pane about to judge them. Every one of the four rungs is a spelling of it,
  # and every one of the four is run here: the roster check above compares a
  # pinned literal against the program, so it structurally cannot see a rung
  # dropped from the SOURCE list — a perturbation trial proved a binary built
  # without gemini in ladderPins sailed through everything but this loop. Two
  # extra stub runs buy the only coverage that direction has.
  #
  # Refused now, and refused by the CLI for departure 2's reason — the gate's
  # verdict is what selected the program that pins nothing, and the message is
  # about the flag. What is checked is therefore what is guaranteed: NONZERO, and
  # nothing reached. A stub that was never run leaves no state directory, which is
  # the strongest statement this gate can make about spend.
  for rung in opus fable gpt-5.5-pro gemini-3.1-pro-preview; do
    DECK_STUB_STATE="$work/rung-$rung" \
      "$wf" run wiggum-duet \
        --session work-pane \
        --route partner=deck:judge-pane \
        --route "$rung=deck:judge-pane" \
        --binary "$stub" --poll 20 --timeout 30000 \
        "${ins[@]}" \
        +RTS -N8 -RTS \
        < /dev/null > "$work/rung-$rung.run" 2>&1
    code=$?
    [ "$code" = 0 ] \
      && bad wiggum-duet "the $rung rung on the judge's pane: exit" "nonzero" 0
    grep -q "never pins" "$work/rung-$rung.run" \
      || bad wiggum-duet "the $rung rung on the judge's pane: the refusal" \
           "a --route refused by name" "$(head -1 "$work/rung-$rung.run")"
    [ -d "$work/rung-$rung" ] \
      && bad wiggum-duet "the $rung rung on the judge's pane: what was spent" \
           "nothing" "the stub was reached"
    if grep -q "model independence" "$work/rung-$rung.run"; then
      bad wiggum-duet "the $rung rung on the judge's pane" "no probe" "the loop started"
    fi
  done

  # AND THE SPLIT ITSELF STILL RUNS, which is the other half of the claim: the
  # list the judge is compared against must refuse a rung routed onto the judge's
  # pane WITHOUT refusing the two-pane invocation the row exists for. Decision
  # table row 6, the owner's own command line, reaching the probe.
  DECK_STUB_STATE="$work/split" \
    "$wf" run wiggum-duet \
      --session work-pane \
      --route partner=deck:judge-pane \
      --binary "$stub" --poll 20 --timeout 30000 \
      "${ins[@]}" \
      +RTS -N8 -RTS \
      < /dev/null > "$work/row6.run" 2>&1
  code=$?
  [ "$code" = 0 ] || {
    bad wiggum-duet "row 6's exit" 0 "$code"
    tail -20 "$work/row6.run" >&2
  }
  grep -q "text -> model independence" "$work/row6.run" \
    || bad wiggum-duet "row 6: the gate accepted" \
         "the sentinel probe put" "no probe in the run's output"
  grep -q "This run puts the judgment in a conversation the work also reaches" \
    "$work/row6.run" \
    && bad wiggum-duet "row 6: the gate accepted" "no refusal" "the gate refused the split"

  note "wiggum-duet: row 4 refuses in the gate's own words; row 7, and a rung on the judge's pane, never start; row 6 runs"
fi

# ---------------------------------------------------------------------------

if [ "$failures" = 0 ]; then
  echo "ci/workflows: ${#names[@]} workflow(s) pinned, 0 failed"
else
  echo "ci/workflows: $failures check(s) failed" >&2
fi
exit $((failures > 0))
