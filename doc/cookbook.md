# Running the workflows

*Seventy-two rows, grouped by family: what each one is, what it costs, what its
inputs mean, one command line you can type, and the rehearsal that costs
nothing. `README.md` has the general grammar; this page is the per-row
specifics.*

## The grammar, in one paragraph

Price first, then run. `wf plan NAME` and `wf cost NAME` are answered by the
elaborated term alone, before anything is asked of anybody, so the ceiling on
this page is a promise and not an estimate. Then pick one of three transports:
`--scripted` rehearses from the row's own canned table and consults nobody;
`--engine acp --adapter claude` starts an adapter of its own, one fresh session
per question, which is the unattended shape; `--session <agent-deck-pane-id>`
sends every question — model, tool and person alike — into one live pane
somebody is watching. Inputs go in as `--input-arg NAME=VALUE` for a phrase or
`--input-file NAME=PATH` for a file's contents, and a program refuses to `run`
until every one it declares is named. **An empty string is legal**, and it is
what `plan` and `cost` bind for an input nobody gave — so every price quoted
below is the price of the empty invocation, and the row that says otherwise says
so. Four input names are never yours: `run.backends`, `run.engine`,
`run.routes` and `run.sentinel` are *run facts* the runner binds from the run it
is making, and a flag naming one is refused.

Two practical notes that save a first run:

* **`--scratch "$PWD"` under `--engine acp`, whenever the run should touch your
  tree.** Without it the adapter is started in a fresh temporary directory, and
  that directory is the only place an acting turn may write — so a repair loop
  repairs a copy and a report is written somewhere you will not look. That is
  deliberate: a run not given a directory of its own would be authorizing writes
  into whatever directory it was started from. Under `--session` the question
  goes to a pane already sitting in the work, and the flag does not apply.
* **`--require-pinned` before anything else.** It refuses a program whose model
  asks do not name the model that serves them, checked before a plan is printed
  or a token is spent. Recommended on every live line below, and left in them.

The prices below read `level · minFold to maxFold over N paths`. `minFold` is
the cheapest ending — often a refusal — and `maxFold` is the worst case the run
cannot exceed. Twenty of the seventy-two price *exactly*, min equal to max, and
those are written as a single number.

## The review ladder

Four rungs over one frozen snapshot, priced side by side — which is the whole
reason the ladder is four rows and not one flag with a weight adjective.

**Inputs, shared by all four.** `scope` is what to review: a git ref, a range,
or empty for the uncommitted changes. It becomes the *argv* of the snapshot
command rather than a string a model interprets. `paths` is the changed-file
list, one per line, and it selects the language roster and the linters in
ordinary Haskell before the program exists — so `plan` must be given the same
`paths=` the run will use or it prices a different program.

`changed.txt` below is that file list, and `git diff --name-only > changed.txt`
is the usual way to make one. Every row on this page that takes a `paths=` reads
it the same way.

### `review-quick`

One lens over the snapshot: the fastest rung. `branch · 3 to 6 over 3 paths`.

```sh
wf run review-quick --engine acp --adapter claude --require-pinned \
   --input-arg scope= --input-file paths=changed.txt
```

### `review-deep`

The language roster, the performance pass and the four required skill lenses,
over receipts. `branch · 3 to 10 over 3 paths`.

```sh
wf run review-deep --engine acp --adapter claude --require-pinned \
   --input-arg scope=HEAD~3..HEAD --input-file paths=changed.txt
```

### `review-sec`

The language roster plus the security lens, over the same receipts.
`branch · 3 to 6 over 3 paths`.

```sh
wf run review-sec --engine acp --adapter claude --require-pinned \
   --input-arg scope=origin/main..HEAD --input-file paths=changed.txt
```

### `review-heavy`

The seven independent passes of `heavy-review`, over one snapshot.
`branch · 3 to 12 over 3 paths`.

```sh
wf run review-heavy --engine acp --adapter claude --require-pinned \
   --input-arg scope=origin/main..HEAD --input-file paths=changed.txt
```

Rehearse any rung, and read the four bills against each other:

```sh
for r in review-quick review-deep review-sec review-heavy; do
  wf cost "$r"
  wf run "$r" --scripted --input-arg scope= --input-arg paths=
done
```

## The green fix loops

Check, repair, recheck — where the review clause is a real exit code and the
number of repair trips is printed before the first one. All three edit, so give
them somewhere to edit.

**Input.** `target` is the thing green is about: the pull request *number* at
`green-ci` (it is the argv of both `gh` commands), a one-line description of
what green means at `green-tree`, and the failing-test report at `green-flaky`.

### `green-ci`

Sweep the bot threads, then repair until `gh pr checks` exits 0.
`branch · 4 to 10 over 8 paths`.

```sh
wf run green-ci --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg target=1487
```

### `green-tree`

Repair the working tree until `nix flake check` exits 0.
`branch · 3 to 9 over 8 paths`.

```sh
wf run green-tree --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg target='nix flake check is green on this tree'
```

### `green-flaky`

Three drawn runs, a repair loop, and a fourth draw that says *flaky* or
*broken* — decided by the test runner's exit code and not by the agent that
just fixed it. `branch · 6 to 11 over 9 paths`.

```sh
wf run green-flaky --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg target='tests::token_refresh::race is red about one run in five'
```

```sh
for r in green-ci green-tree green-flaky; do
  wf run "$r" --scripted --input-arg target=
done
```

## The commit family

One `commitFn` with four callers. The rungs differ in what they ask of the
decomposition and in how many repair trips the gate is given. These are
watched-pane rows: the decomposition is of *your* working tree, and the pane is
where you can see what it is proposing.

**Inputs, shared by all four.** `scope` is what is being committed — a branch
name, a task description, a paste of `git status`. `tree` is the tree object the
run must end at, which `git write-tree` prints; it is what makes
`commit-bankruptcy`'s "the tree must not have moved" postcondition checkable
instead of hoped for. Empty is legal and reads as *no tree given*.

### `commit`

`commit.md`: the working tree as an atomic, ordered series, gated on
`make test`. `branch · 5 to 8 over 6 paths`.

```sh
wf run commit --session "$PANE" \
   --input-arg scope='the token-refresh work' --input-arg tree=
```

### `commit-push`

The same series, then `git push --force-with-lease` and `gh pr create`.
`branch · 5 to 9 over 6 paths`.

```sh
wf run commit-push --session "$PANE" \
   --input-arg scope='the token-refresh work' --input-arg tree=
```

### `commit-recommit`

The same series again, each commit held to standalone CI, with three repair
trips. `branch · 5 to 12 over 12 paths`.

```sh
wf run commit-recommit --session "$PANE" \
   --input-arg scope='the token-refresh branch, re-cut' \
   --input-arg tree=8f2a1c9d4e7b05a3f16c2d8e9b0741a5c3e6d2f8
```

### `commit-bankruptcy`

Recommit an unwound branch, and check the tree really did not move.
`branch · 5 to 10 over 9 paths`.

```sh
wf run commit-bankruptcy --session "$PANE" \
   --input-arg scope='forty-one commits down to nine' \
   --input-arg tree=8f2a1c9d4e7b05a3f16c2d8e9b0741a5c3e6d2f8
```

```sh
for r in commit commit-push commit-recommit commit-bankruptcy; do
  wf run "$r" --scripted --input-arg scope= --input-arg tree=
done
```

## The stack family

One procedure at four settings: bring the stack up to date, resolve every
conflict through one shared `resolveFn`, prove no commit was lost with
`git cherry` rather than with a reading, and publish. The proof is why `tip` is
an input: the run refuses to begin a rewrite it could not later check.

**Inputs, shared by all four.** `trunk` is what the rewrite is brought up to
date with (`main` when empty). `tip` is this branch's tip *before* the run.
`agents` is the routing table `resolveFn` is called with — which specialist
resolves what. `pr` is the pull request the `stack-rebase-fix` rung watches
afterwards, and is ignored by the other three.

### `stack`

`gt restack` to a fixpoint, then prove no commit was lost, then submit.
`branch · 7 to 21 over 40 paths`.

```sh
wf run stack --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg trunk=main --input-arg tip=9c1f0ab \
   --input-arg agents= --input-arg pr=
```

### `stack-rebase`

The same shape with `git` deciding instead of `gt`: rebase onto the trunk to a
fixpoint, prove nothing was lost, push with a lease.
`branch · 7 to 21 over 40 paths`.

```sh
wf run stack-rebase --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg trunk=origin/main --input-arg tip=9c1f0ab \
   --input-arg agents='haskell-pro for .hs, nix-pro for .nix' --input-arg pr=
```

### `stack-rebase-fix`

`stack-rebase`, then the pull request's checks green, then the bot sweep. The
most expensive row in the family and the one that uses `pr`.
`branch · 7 to 28 over 100 paths`.

```sh
wf run stack-rebase-fix --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg trunk=origin/main --input-arg tip=9c1f0ab \
   --input-arg agents='haskell-pro for .hs' --input-arg pr=1487
```

### `stack-cleanup`

`lefthook run --all-files pre-commit` green on every branch, then `gt restack`.
`branch · 7 to 19 over 30 paths`.

```sh
wf run stack-cleanup --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg trunk=main --input-arg tip=9c1f0ab \
   --input-arg agents= --input-arg pr=
```

```sh
for r in stack stack-rebase stack-rebase-fix stack-cleanup; do
  wf run "$r" --scripted --input-arg trunk= --input-arg tip= \
     --input-arg agents= --input-arg pr=
done
```

## `fess`

Eleven sin categories as eleven independent stances over three receipts, folded
to one report. Priced exactly: `branch · 16 over 2 paths` — sixteen consultations
on either ending, because the two arms differ in a provenance line and not in a
question.

**Inputs.** `request` is the original request the work is being audited against,
which is what makes the *spec drift* stance able to walk it point by point;
`--input-file` is the natural spelling. `base` is the diff base, and empty is
the whole change.

The two paths are "independence verified" and "independence not verified", and
which one you get is decided by a probe plus `run.engine` — so the transport is
part of the audit. An adapter of the run's own, one session per question, is the
shape that earns the verified arm.

```sh
wf run fess --engine acp --adapter claude --require-pinned \
   --input-file request=doc/REQUEST.md --input-arg base=origin/main
```

```sh
wf run fess --scripted --input-arg request= --input-arg base=
```

## The confer family

Three stances over one decision, folded into a document. There is no Markdown
behind these rows: `confer` is the workflow-native counterpart of PAL's
`consensus`, with a price before the spend and a trace after it. All four price
exactly, over one path.

**Inputs, shared by all four.** `decision` is the question being conferred over.
`context` is the file context it is decided against — the operator's text reaches
the prompts as *data*, which is why the row does not open by asking a tool to go
and read it.

**Routing is what makes agreement mean something.** The three seats are pinned
to three distinct primaries so that a route table *can* put them on three
providers. Unrouted under `--engine acp` they are three fresh sessions of one
model, which is independence of context and not of judgment; the report says
which you got, derived from `run.backends` and `run.engine`.

### `confer`

Three stances, folded to a document, and synthesised. `pipeline · 5 over 1 path`.

```sh
wf run confer --engine acp --adapter claude --require-pinned \
   --route gemini-3.1-pro-preview=acp:codex \
   --input-arg decision='Should the registry be one table or two?' \
   --input-file context=doc/design.md
```

### `confer-bare`

The same three stances, written down and deliberately *not* reconciled — for
when the reconciliation is yours to do. `pipeline · 4 over 1 path`.

```sh
wf run confer-bare --engine acp --adapter claude --require-pinned \
   --input-arg decision='Should the registry be one table or two?' \
   --input-file context=doc/design.md
```

### `debate`

For and against only: the pair, synthesised, with no middle seat.
`pipeline · 4 over 1 path`.

```sh
wf run debate --engine acp --adapter claude --require-pinned \
   --input-arg decision='Should ci/workflows.sh pin costMax by equality?' \
   --input-arg context=
```

### `second-opinion`

One contrary party under the anti-sycophancy rubric, and an artefact — the
cheapest way in the toolbox to have a decision argued with.
`pipeline · 2 over 1 path`.

```sh
wf run second-opinion --engine acp --adapter claude --require-pinned \
   --input-arg decision='I am about to fold the two registries into one.' \
   --input-file context=doc/design.md
```

```sh
for r in confer confer-bare debate second-opinion; do
  wf run "$r" --scripted --input-arg decision= --input-arg context=
done
```

## `wiggum` and `wiggum-duet`

The autonomous continuation loop: two work rounds, one checkpoint audit, and a
bounded verdict against frozen done-criteria. These are the two most expensive
rows in the toolbox, and the two whose *transport is a gate* rather than a
preference.

**Inputs, shared.** `plan` (at `wiggum`) or `goal` (at `wiggum-duet`) is the
frozen plan and its done-criteria — read-only by construction, because an input
is a define. `base` is what the branch is measured against and brought up to
date with (`main` when empty). `observations` is the partner directory
(`doc/observations` when empty). `parity` is the reference target, and an absent
one is a *different* last conjunct rather than a missing one.

### `wiggum`

The loop in one conversation. `branch · 2 to 44 over 34 paths` — and the
`minFold 2` is worth as much as the ceiling, because that is the run that
refuses to start.

**It refuses every `--session` run, flat.** Its judge and its workers are one
serving model and no route table can separate them, so a single shared pane
means the party that would have judged the work is the party that did it. The
refusal costs one probe and one report and starts nothing.

```sh
wf run wiggum --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file plan=doc/PLAN.md --input-arg base=main \
   --input-arg observations= --input-arg parity=
```

### `wiggum-duet`

The same loop across two panes: the work in one, a four-seat review and the
done-criteria judge in the other. `branch · 2 to 50 over 34 paths` — the six
over `wiggum` is exactly the review the duet buys.

`--session` names the *work* pane and becomes the default, so every borrowed
callee, tool and person lands there; `--route partner=deck:<pane>` moves the
judgment. Written the other way round the run refuses, before anything is spent.
**[doc/wiggum-two-sessions.md](wiggum-two-sessions.md) is the full walkthrough** —
standing the panes up, what flows between them, what happens when you have no
panes — and this is the one command out of it:

```sh
wf run wiggum-duet --session "$PANE_W" --route "partner=deck:$PANE_R" \
   --poll 250 --require-pinned \
   --input-arg goal='Bring the token-refresh path under test.' \
   --input-arg base=main --input-arg observations= --input-arg parity=
```

```sh
wf run wiggum --scripted --input-arg plan= --input-arg base= \
   --input-arg observations= --input-arg parity=
wf run wiggum-duet --scripted --input-arg goal= --input-arg base= \
   --input-arg observations= --input-arg parity=
```

A rehearsal takes the *loop*, not the refusal: `--scripted` reaches no session
and says so, and the gate is chosen from `run.engine` in Haskell. The refusing
arm is reachable from a command line and from nowhere else.

## The daily drivers

### `pr-threads`

`respond.md`: one answer per open colleague comment, as a report, with nothing
posted back — the reviewing questions are asked at `text`, and only an act at
`receipt` has write authority, so no member *can* post.
`branch · 3 to 5 over 3 paths`.

**Inputs.** `pr` is the pull request number. `paths` is the changed-file list,
one per line, which selects the specialist roster; empty is one general seat.

```sh
wf run pr-threads --engine acp --adapter claude --require-pinned \
   --input-arg pr=1487 --input-file paths=changed.txt
```

### `pr-threads-assess`

`assess.md`: the language specialists read the comments *first*, then an approach
to answering them. `branch · 3 to 6 over 3 paths`. Same two inputs.

```sh
wf run pr-threads-assess --engine acp --adapter claude --require-pinned \
   --input-arg pr=1487 --input-file paths=changed.txt
```

```sh
for r in pr-threads pr-threads-assess; do
  wf run "$r" --scripted --input-arg pr= --input-arg paths=
done
```

### `issue`

`fix.md`: three cheap gates, the fix, `commitFn`, a pull request, and the bot
sweep over it. `branch · 2 to 14 over 4 paths`.

**Inputs.** `issue` is the number, and it is the argv of `gh issue view`, the
`--search` term, the worktree's name and the confirmation test's path. `paths`
selects the persona in Haskell before the program exists.

```sh
wf run issue --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg issue=412 --input-file paths=changed.txt
```

### `issue-worktree`

`fix-github-issue.md`: the fix in its own worktree, left uncommitted, and a
receipt that says so. Priced exactly: `branch · 6 over 2 paths`.

```sh
wf run issue-worktree --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg issue=412 --input-file paths=changed.txt
```

```sh
for r in issue issue-worktree; do
  wf run "$r" --scripted --input-arg issue= --input-arg paths=
done
```

### The account family

Four ways of writing down where the work stands. All four take the same two
inputs and only one of them reads the second.

**Inputs.** `scope` is what the account is about, and may be empty — it rides
into every member's closing line for zero questions. `journal` is the path
`narrative.md` names, and it is the argv of a `cat`; the other three kinds do
not read it, and `wf plan` says so.

* **`account-halt`** — journal, `commitFn`, push, the remaining-scope panel, and
  a handoff written to `~/dl`. `branch · 15 over 2 paths`.
* **`account-sitrep`** — eight sections over four command receipts.
  `pipeline · 13 over 1 path`.
* **`account-report`** — seven categories as seven panel members, and the
  estimate on a different engine. `pipeline · 11 over 1 path`.
* **`account-narrative`** — a receipt dossier, a chronology, a writer over it,
  and a sourcing gate elsewhere. `branch · 8 over 3 paths`. The one that reads
  `journal`.

```sh
wf run account-sitrep --engine acp --adapter claude --require-pinned \
   --input-arg scope='the token-refresh branch' --input-arg journal=

wf run account-report --engine acp --adapter claude --require-pinned \
   --input-arg scope='what remains before the release' --input-arg journal=

wf run account-halt --session "$PANE" \
   --input-arg scope='stopping for the week' --input-arg journal=

wf run account-narrative --engine acp --adapter claude --require-pinned \
   --input-arg scope='the last three weeks' --input-arg journal=doc/journal.md
```

```sh
for r in account-halt account-sitrep account-report account-narrative; do
  wf run "$r" --scripted --input-arg scope= --input-arg journal=
done
```

### The partner family

A review that runs *beside* the work rather than inside it, publishing one
observation file per finding.

**Inputs, shared by all three.** `commit` is the revision under review
(`HEAD` when empty). `observations` is the directory published into
(`doc/observations` when empty). `paths` is the changed-file list, which widens
`partner-collaborator`'s roster with the language reviewers the commit touches.

**Where you put it is the whole point.** A partner review is worth having
because it is not the party that wrote the code, and nothing in the program can
secure that — so name a pane that is *not* the work's, or use `--engine acp`,
whose fresh session per question is the stronger of the two. Naming the working
pane is the quiet failure: the run succeeds and reads like a review. Every
ending quotes `run.engine`, so the report says which you did.

* **`partner-reviewer`** — `heavy-review`'s passes over one commit.
  `branch · 11 over 2 paths`.
* **`partner-collaborator`** — `deep-review`'s roster plus three drawn ideas.
  `branch · 12 over 2 paths`.
* **`partner-cleanup`** — two drain rounds behind a free `find` test, then one
  `commitFn` call. `branch · 2 to 12 over 4 paths`. This one *edits*, so it is
  the one of the three that belongs in the work's own tree.

```sh
wf run partner-reviewer --session "$PANE_R" \
   --input-arg commit=HEAD --input-arg observations=doc/observations \
   --input-file paths=changed.txt

wf run partner-collaborator --engine acp --adapter claude --require-pinned \
   --input-arg commit=HEAD --input-arg observations=doc/observations \
   --input-file paths=changed.txt

wf run partner-cleanup --session "$PANE_W" \
   --input-arg commit=HEAD --input-arg observations=doc/observations \
   --input-arg paths=
```

```sh
for r in partner-reviewer partner-collaborator partner-cleanup; do
  wf run "$r" --scripted --input-arg commit= --input-arg observations= \
     --input-arg paths=
done
```

### The Org-mode pair

Two rungs that take *different* inputs, which is what a rung may do.

* **`org-tasks-breakdown`** — analyse, decompose, format, with `[ATOMIC]`,
  `[AMBIGUOUS]` and `[NO-EXPERTISE]` as arms. `branch · 2 to 4 over 5 paths`.
  Inputs: `task`, the one headline being decomposed; `context`, its background.
* **`org-tasks-infer`** — extract a flat list, decide the nesting rule for free,
  and have a second party judge it. `branch · 2 to 4 over 5 paths`. Input:
  `text`, the unstructured source.

```sh
wf run org-tasks-breakdown --engine acp --adapter claude --require-pinned \
   --input-arg task='* TODO Bring token refresh under test' \
   --input-file context=doc/design.md

wf run org-tasks-infer --engine acp --adapter claude --require-pinned \
   --input-file text=notes.md
```

```sh
wf run org-tasks-breakdown --scripted --input-arg task= --input-arg context=
wf run org-tasks-infer --scripted --input-arg text=
```

### The `CLAUDE.md` pair

Both take `scope` and `agents`, and each ignores one of them.

* **`claude-md`** — one `ls` receipt decides it: write the file, or critique the
  one already there. `branch · 3 to 4 over 2 paths`. `scope` is what to
  emphasise; `agents` is unused here, and `wf plan` says so.
* **`claude-md-advise`** — the named specialists advise, then a *different*
  engine audits the draft. `branch · 5 over 3 paths`. Here `agents` is
  `prepare-with.md`'s `$ARGUMENTS` and selects the roster in Haskell.

```sh
wf run claude-md --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg scope='the build and test commands' --input-arg agents=

wf run claude-md-advise --engine acp --adapter claude --require-pinned \
   --input-arg scope= --input-arg agents='haskell-pro nix-pro'
```

```sh
for r in claude-md claude-md-advise; do
  wf run "$r" --scripted --input-arg scope= --input-arg agents=
done
```

### The prose dial

Four settings of one dial, each with a check its own author does not make. The
rungs take different inputs.

* **`prose-proofread`** — clear errors only, then the five prohibitions checked
  against `git diff` elsewhere. `branch · 4 over 3 paths`. Input: `scope`.
* **`prose-smooth`** — a light rewrite, with "do not change it overmuch" as a
  bounded restraint gate. `branch · 3 to 7 over 15 paths`. Input: `text`.
* **`prose-transcript`** — the rule-priority order over a `cat` receipt.
  `branch · 5 over 3 paths`. Inputs: `transcript`, the file's *path*;
  `vocabulary`, the reference tables.
* **`prose-compress`** — `compressFn`, called: the family's reusable transform,
  priced at two questions. `branch · 2 over 2 paths`. Input: `text`.

```sh
wf run prose-proofread --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg scope='doc and README.md'

wf run prose-smooth --engine acp --adapter claude --require-pinned \
   --input-file text=doc/intro.md

wf run prose-transcript --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg transcript=talk.txt --input-file vocabulary=terms.md

wf run prose-compress --engine acp --adapter claude --require-pinned \
   --input-file text=prompt.md
```

```sh
wf run prose-proofread --scripted --input-arg scope=
wf run prose-smooth --scripted --input-arg text=
wf run prose-transcript --scripted --input-arg transcript= --input-arg vocabulary=
wf run prose-compress --scripted --input-arg text=
```

## The specialists

### `dead-code`

Four phases that cannot interleave, two gates before anything is asked, and a
three-advocate debate no majority can win. `branch · 2 to 18 over 11 paths`.

The two gates come first and cost nothing: a dirty working tree is
`git status --porcelain` read by a decider, and a red test suite is the
repository's own gate read as an exit code. Both have an arm, and the arm
reports and stops — which is where `minFold 2` comes from. Then MARK, DEBATE,
ACT and VERIFY are binds in one block, each reading the handle the last one
bound, so there is no order in which they could run but this one.

**Its three inputs.**

* `scope` is `$ARGUMENTS`: a path, a kind, a language name, or empty for the
  whole repository.
* `paths` is the changed-file list, one per line. It selects which static
  analyzers run and decides whether the two-evidence rule binds — the rule
  arrives in the debate's briefs when the list touches Python and does not when
  it touches Rust, decided in Haskell before the program exists.
* `cap` is the blast-radius cap, and it is **the one input in the whole table
  that moves a price.** It is read in Haskell into the ACT gate's bound, so the
  operator sees the cost of his own cap before spending it:

```sh
$ wf cost dead-code
  costSummary   minFold 2, maxFold 18, over 11 paths

$ wf cost dead-code --input-arg cap=4
  costSummary   minFold 2, maxFold 22, over 17 paths
```

Empty `cap` is two repair trips — not the skill's default of twenty, because
twenty rounds of a priced loop is a plan nobody would read, and a bound whose
default nobody would accept teaches an operator to ignore the price. `cap=0` is
*not* unbounded here; an unbounded loop has no price. **`plan` and `cost` must be
given the same `cap=` the run will use**, or they price a different program.

The full worked run — unattended, with somewhere to write, and a cap chosen on
purpose:

```sh
wf run dead-code --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg scope=src/Workflows --input-file paths=changed.txt --input-arg cap=4
```

```sh
wf run dead-code --scripted --input-arg scope= --input-arg paths= --input-arg cap=
```

Note that the rehearsal is the `cap=` empty shape, which is the price
`ci/workflows.sh` pins. A rehearsal at `cap=4` is a different program with six
more paths, and rehearsing it is the cheapest way to see that.

### `comments`

The extractor as three receipts, the manifest read back off disk, and a
false-positive guard on another engine. `branch · 5 to 13 over 17 paths`.

**Inputs.** `extractor` is the installed *path* of the audit's
`inventory_comments.py` — a path passed as argv, so `--input-arg` and not
`--input-file`. An empty one becomes a name no file has, which is what
`wf plan --raw` prints and why a `--scripted` run never reaches a command at
all. `base` is the diff base, and empty means the whole project.

```sh
wf run comments --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg extractor="$HOME/.claude/skills/comment-audit/scripts/inventory_comments.py" \
   --input-arg base=origin/main
```

```sh
wf run comments --scripted --input-arg extractor= --input-arg base=
```

### `bundles`

Six hard rejections decided before any paid scoring, then seven weighted seats
over one dossier. `branch · 3 to 12 over 3 paths`.

**Inputs.** `focus` is what you are shopping for. `candidates` is the candidate
material, which is what `--input-file` is for. `profile` is the taste profile —
an input rather than a scan, deliberately.

```sh
wf run bundles --engine acp --adapter claude --require-pinned \
   --input-arg focus='review and audit bundles' \
   --input-file candidates=doc/candidates.md --input-file profile=doc/taste.md
```

```sh
wf run bundles --scripted --input-arg focus= --input-arg candidates= --input-arg profile=
```

### `productize` and `productize-lefthook`

Twenty-one deliverables as a roster priced at twenty-one, then `nix flake check`
as the gate — and the pre-commit slice of the same, as a call rather than a
prose reference.

* **`productize`** — `branch · 27 to 31 over 6 paths`. The most expensive
  floor in the toolbox: twenty-seven consultations on the cheapest path.
* **`productize-lefthook`** — `branch · 11 to 15 over 6 paths`.

**Inputs.** `paths` is the file list, one per line, and it decides the
preferences table and the search seats in Haskell; empty collapses the
per-language seats to one general seat rather than to none. `scope` is what the
operator says the repository is *for*, and it rides into the specification
because a README and a fuzz harness both need to know.

```sh
wf run productize --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file paths=changed.txt --input-arg scope='a Haskell library and its CLI'

wf run productize-lefthook --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file paths=changed.txt --input-arg scope='a Haskell library and its CLI'
```

```sh
for r in productize productize-lefthook; do
  wf run "$r" --scripted --input-arg paths= --input-arg scope=
done
```

### The nix family

Three rows, one invocation shape — which is what makes them one family. Each
runs the host's own build driver as the receipt, then diagnoses, repairs and
verifies. All three: `branch · 2 to 9 over 8 paths`.

**Inputs, shared.** `subject` is what is wrong. `output` is the failing output,
whose default carries the error the source file hard-codes. `host` is the
machine, and it decides the build flags; empty is the unconstrained default.

* **`nix-rebuild`** — the failure *is* the subject, so an approving baseline
  means there is nothing to diagnose.
* **`nix-alert`** — the alert routed by its own labels for free, and diagnosed
  whole rather than compressed.
* **`nix-integration`** — the failing integration output as the input.

```sh
wf run nix-rebuild --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg subject='vulcan will not switch after the Grafana bump' \
   --input-file output=build.log --input-arg host=vulcan

wf run nix-alert --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg subject='PostgresBackupStale has been firing since Tuesday' \
   --input-file output=build.log --input-arg host=vulcan

wf run nix-integration --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg subject='the Home Assistant bridge drops its websocket at start-up' \
   --input-file output=build.log --input-arg host=vulcan
```

```sh
for r in nix-rebuild nix-alert nix-integration; do
  wf run "$r" --scripted --input-arg subject= --input-arg output= --input-arg host=
done
```

### The service pair

* **`service-install`** — nine obligations as nine calls behind a consent file
  the run cannot create, then two health receipts. `branch · 2 to 23 over 4
  paths`. The `minFold 2` is the run that finds no consent file and ends at your
  desk with nothing on the machine changed.
* **`service-remove`** — twelve read-only discovery questions, then one act that
  *writes* a script rather than running one. `branch · 15 to 19 over 6 paths`.

**Inputs, shared.** `service` is the service's name, and it names both the
consent file and the unit — an empty one names `.consent/service-unnamed`, which
is exactly what a plan should print for an operator who forgot the flag.
`domain` is the virtual host and names the health URL. `host` is the machine.

`service-install` wants a watched pane because its consent gate is a person's
and an unwatched run reaches nobody. `service-remove` has no person gate; it is
shown on the same pane because it edits the host's declarations and writes a
script you will want to read before running it.

```sh
wf run service-install --session "$PANE" \
   --input-arg service=grafana --input-arg domain=grafana.example.com \
   --input-arg host=vulcan

wf run service-remove --session "$PANE" \
   --input-arg service=grafana --input-arg domain=grafana.example.com \
   --input-arg host=vulcan
```

```sh
for r in service-install service-remove; do
  wf run "$r" --scripted --input-arg service= --input-arg domain= --input-arg host=
done
```

### `query`

A query written against a schema receipt by parties that cannot reach the data,
audited on another engine. `branch · 3 to 8 over 16 paths`. There is no `act` in
this program except the report, so "a query I can run myself" is a property of
the printed program and not a sentence in a prompt.

**Inputs.** `question` is what the query must answer. `schema` is the path to the
exported schema. `dialect` is which SQL, with the corpus's own default when
empty.

```sh
wf run query --engine acp --adapter claude --require-pinned \
   --input-arg question='which accounts had no activity last quarter' \
   --input-arg schema=schema.sql --input-arg dialect=tsql
```

```sh
wf run query --scripted --input-arg question= --input-arg schema= --input-arg dialect=
```

### `expense`

Receipts as a `find` receipt, one extracted table, and **the owner's answer as
the loop's verdict**. `branch · 4 to 10 over 17 paths`. Six endings, of which
exactly two build anything — and neither is reachable without an approval or a
yes, which is a property of the printed program.

**Inputs.** `receipts` is the directory the receipt files are in. `trip` is the
trip name — in the corpus a quoted string a model has to spot in `$ARGUMENTS`,
here its own flag. `script` is the filler's absolute path.

A person's question is not a real gate when unattended, so this one belongs in a
pane you are looking at:

```sh
wf run expense --session "$PANE" \
   --input-arg receipts="$HOME/Documents/receipts/2026-06-boston" \
   --input-arg trip='Boston, June 2026' \
   --input-arg script="$HOME/bin/fill-expense-report"
```

```sh
wf run expense --scripted --input-arg receipts= --input-arg trip= --input-arg script=
```

### `qanda`

An agenda from `--input-file`, the full background produced before the first
question, and the owner's answer as the loop's verdict.
`branch · 4 to 8 over 15 paths`. Same reasoning as `expense`: the judge is a
person, so give it a pane.

**Inputs.** `decisions` is the agenda, one decision per line — an empty one is
*one* placeholder decision and never the empty list, because an empty agenda
would ask the owner to walk through nothing. `context` is the background.

```sh
wf run qanda --session "$PANE" \
   --input-file decisions=doc/agenda.md --input-file context=doc/design.md
```

```sh
wf run qanda --scripted --input-arg decisions= --input-arg context=
```

### `transcribe`

An `ls` receipt over the pages, one transcription, and a second engine re-reading
them under a bound. `branch · 4 to 8 over 15 paths`.

**Inputs.** `images` is the image paths, one per line; an empty one is one
placeholder path rather than the empty list, so the argv never degenerates into
a bare `ls`. `subject` is what the notes are about, which is the one thing that
turns an unreadable word into a readable one.

```sh
wf run transcribe --engine acp --adapter claude --require-pinned \
   --input-file images=pages.txt \
   --input-arg subject='the denotational design notebook'
```

```sh
wf run transcribe --scripted --input-arg images= --input-arg subject=
```

### `tron`

The control, the ingest, the compile and the run as four receipts, and a
diagnosis reachable only through all four. `branch · 2 to 14 over 9 paths`.
Three of its seven endings are "a command did not do what this run needed", and
each is better localised than the diagnosis it replaces.

**Inputs.** `problem` is the symptom, spliced into all four lenses. `model` names
*both* sides of the differential — the control's name is computed from it, so one
flag names both. `trace` is the Torch export directory, with the corpus's own
default when empty.

```sh
wf run tron --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg problem='the plugin emits zeros for the attention block' \
   --input-arg model=llama_3p1_8b_torch --input-arg trace="$HOME/exports/llama-3p1-8b"
```

```sh
wf run tron --scripted --input-arg problem= --input-arg model= --input-arg trace=
```

## The long ones

### `retest` and `retest-categorical`

The model-support battery: one exhaustive sweep with no early exit anywhere in
it, five endings, priced first.

* **`retest`** — against the HuggingFace forward pass.
  `branch · 2 to 16 over 5 paths`.
* **`retest-categorical`** — the same battery against the legacy ingest path,
  over the fixed eight-model roster. `branch · 2 to 37 over 5 paths` — the
  twenty-one between them is the fixed roster, and it is why `models=` is
  *ignored* at this rung by that file's own ruling.

**Inputs, shared.** `spec` is the skill's own 674-line procedure as an
`--input-file` — authoritative data, not prompt bulk. `base` is the diff base.
`models` is the model set, one per line, and an empty one is *one* model rather
than none. `paths` selects the audit's language roster.

```sh
wf run retest --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file spec="$HOME/.claude/skills/retest/references/spec.md" \
   --input-arg base=origin/main --input-arg models=llama_3p1_8b \
   --input-file paths=changed.txt

wf run retest-categorical --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file spec="$HOME/.claude/skills/retest/references/spec.md" \
   --input-arg base=origin/main --input-arg models= \
   --input-file paths=changed.txt
```

`models=` is left empty at `retest-categorical` on purpose: the ship gate is
always all supported models, so that rung ignores the input by its own ruling
and a value there would be a claim the run does not honour.

```sh
for r in retest retest-categorical; do
  wf run "$r" --scripted --input-arg spec= --input-arg base= \
     --input-arg models= --input-arg paths=
done
```

### `denote`

The meaning first, its exit tests judged elsewhere, and representations
reachable only through them. `branch · 2 to 18 over 17 paths`. The `minFold 2`
is the admission test answering *no* — a subject this method does not suit costs
two questions and stops there.

**Inputs.** `subject` is the API sketch or the codebase under retrofit. `method`
is the seven reference files and the worksheet skeleton as an `--input-file` —
again data, not bulk. `prover` is Lean 4, Rocq or Agda, read once in Haskell so
it cannot be re-litigated mid-dialog. `realization` names the foreign language
phase 10 would bisimulate against, and an empty one is a design where phase 10
does not exist.

```sh
wf run denote --engine acp --adapter claude --require-pinned \
   --input-arg subject='the workflow cost algebra' \
   --input-file method="$HOME/.claude/skills/denotational-design/SKILL.md" \
   --input-arg prover=lean --input-arg realization=rust
```

```sh
wf run denote --scripted --input-arg subject= --input-arg method= \
   --input-arg prover= --input-arg realization=
```

### The translate family

Six reviewers folded in the priority order the source file resolves conflicts
by, under a bound.

* **`translate`** — English into Persian. `branch · 9 to 23 over 15 paths`.
* **`translate-en`** — Persian or Arabic into English in Shoghi Effendi's
  register: the same six seats, the directions swapped.
  `branch · 9 to 23 over 15 paths`.
* **`translate-es`** — English into elevated Latin-American Spanish: one call,
  one delivery. `pipeline · 2 over 1 path`.

**Inputs.** At `translate` and `translate-en`: `text` is the source; `glossary`
is `TERMS.csv` and is authoritative; `references` is the reference letters, which
is what "the target style and standards" means concretely. An empty `text` is not
a *short* source — it is an unknown one, so the empty invocation is the full
six-seat team. `translate-es` takes `text` alone, because `prompts/spanish.md`
names no glossary and no reference corpus and the row does not pretend to.

```sh
wf run translate --engine acp --adapter claude --require-pinned \
   --input-file text=essay.md --input-file glossary=TERMS.csv \
   --input-file references=refs.md

wf run translate-en --engine acp --adapter claude --require-pinned \
   --input-file text=source.txt --input-file glossary=TERMS.csv \
   --input-file references=refs.md

wf run translate-es --engine acp --adapter claude --require-pinned --input essay.md
```

`translate-es` takes exactly one input, so `--input FILE` names it without a
`NAME=` — which is also why a path containing `=` is never misread there.

```sh
for r in translate translate-en; do
  wf run "$r" --scripted --input-arg text= --input-arg glossary= --input-arg references=
done
wf run translate-es --scripted --input-arg text=
```

### The PRD pair

Two shapes split at the mode boundary, and they take different inputs.

* **`prd-draft`** — the owner's answers in binding position, eight sections as a
  roster, and the checklist applied elsewhere. `branch · 2 to 19 over 18 paths`.
  Inputs: `goals`, the design goals the document is for; `template`, the format
  authority as a file in your own project; `prd`, where the document goes, with
  §6's default when empty. It asks the owner seven discovery questions *in
  binding position*, so give it a pane.
* **`prd-critique`** — seven analysis axes over a document nothing in the row can
  write to. `branch · 2 to 11 over 3 paths`. Input: `prd`, the path. The `minFold
  2` is the probe finding no document.

```sh
wf run prd-draft --session "$PANE" \
   --input-file goals=doc/GOALS.md \
   --input-file template=.taskmaster/templates/example_prd.txt \
   --input-arg prd=.taskmaster/docs/prd.txt

wf run prd-critique --engine acp --adapter claude --require-pinned \
   --input-arg prd=.taskmaster/docs/prd.txt
```

```sh
wf run prd-draft --scripted --input-arg goals= --input-arg template= --input-arg prd=
wf run prd-critique --scripted --input-arg prd=
```

### `nodered`

The three-signature admin boundary as argv, six house-style seats over one
fetched tab, and a put only through a validator. `branch · 15 to 17 over 4
paths`. Two of its four endings put nothing, and each is more useful than a
failed put: an envelope that does not validate names its own defect.

**Inputs.** `request` is what the session is for. `flow` is the tab's `FLOW_ID`
and `node` is the node whose history is being explained — both validated in
Haskell against the skill's own `[0-9a-f]{1,32}(\.[0-9a-f]{1,32})?` before the
program exists, so a malformed id is replaced by a name nothing has and a
`--scripted` run never reaches a command. `scripts` is where the skill's Python
lives; `references` is its six reference files as an `--input-file`.

```sh
wf run nodered --engine acp --adapter claude --require-pinned \
   --input-arg request='the Office lights fire twice at dusk' \
   --input-arg flow=a1b2c3d4e5f60789 --input-arg node=4f8a1c2d.9be03a \
   --input-arg scripts="$HOME/.claude/skills/node-red/scripts" \
   --input-file references=doc/nodered-references.md
```

```sh
wf run nodered --scripted --input-arg request= --input-arg flow= --input-arg node= \
   --input-arg scripts= --input-arg references=
```

## Wave 2's residue, and the smoke row

### `checklist`

Two rounds over a Markdown checklist, each behind a *free* unchecked-box test —
a grep over bytes the answering model did not write.
`branch · 2 to 8 over 4 paths`. A list with nothing left costs two questions and
no consultation about the work, which is the `minFold 2`.

**Inputs.** `checklist` names a *file*, passed as the argv of a `cat`, so
`--input-arg` and not `--input-file`; an absent path becomes a name no file has.
`scope` is what the round is about.

```sh
wf run checklist --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg checklist=doc/TODO.md --input-arg scope='the release blockers'
```

```sh
wf run checklist --scripted --input-arg checklist= --input-arg scope=
```

### `teams`

Ten angles on one problem, a devil's advocate over the fold, and a review of all
of it. Priced exactly: `branch · 13 over 2 paths` — ten members, the advocate,
the synthesis, the artefact.

**Inputs.** `problem` is the thing being explored; `context` is its background.

```sh
wf run teams --engine acp --adapter claude --require-pinned \
   --input-arg problem='how should the registry be split?' \
   --input-file context=doc/design.md
```

```sh
wf run teams --scripted --input-arg problem= --input-arg context=
```

### `notes`

Ten sections over one notes receipt, and five fact-only checkpoints on another
engine — because a fact-only discipline audited by the same model is not
audited. Priced exactly: `branch · 17 over 3 paths`.

**Input.** `notes` alone: the *path* to the notes file, which becomes the argv of
a `cat`. Use `--input-arg notes=PATH`; `--input FILE` would bind the file's
contents where the row wants its name.

```sh
wf run notes --engine acp --adapter claude --require-pinned \
   --input-arg notes=doc/meeting-2026-08-12.md
```

```sh
wf run notes --scripted --input-arg notes=
```

### The effort ladder

Three tiers of the standard toolkit, sharing a shape and differing in exactly
what the skills say they differ in.

* **`effort-medium`** — plan, execute, hold the tree to its own gate.
  `branch · 4 to 7 over 3 paths`.
* **`effort-heavy`** — the same, plus the two pinned partners and the Positron
  context, decided free. `branch · 7 to 10 over 3 paths`.
* **`effort-forge`** — the six phases, the approval pause, and a remediation
  loop with three endings. `branch · 10 to 24 over 16 paths`. The approval is a
  `confirm` put to the owner, so this rung wants a pane.

**Inputs.** `task` is what all three entry points spell `$ARGUMENTS`. `worktree`
is the path read to decide whether this is one of the owner's Positron
directories — used by the `heavy` rung alone, which is what makes it free at the
other two. An empty `worktree` is the non-Positron shape.

```sh
wf run effort-medium --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg task='add the missing --dry-run flag' --input-arg worktree=

wf run effort-heavy --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg task='bring the token-refresh path under test' \
   --input-arg worktree="$HOME/src/positron/my-project"

wf run effort-forge --session "$PANE" \
   --input-arg task='design the retry policy' --input-arg worktree=
```

```sh
for r in effort-medium effort-heavy effort-forge; do
  wf run "$r" --scripted --input-arg task= --input-arg worktree=
done
```

### `hello`

The smoke row: two cross-cutting lenses over one scrap, folded and reported.
`pipeline · 4 over 1 path`, no inputs. It exists to prove the wiring — the
registry, the shared CLI, the roster, the panel fold — rather than to do any
work, and it is the row to run first against a new transport.

```sh
wf run hello --engine acp --adapter claude
wf run hello --scripted
```

## Which transport for which row

| kind | rows | why |
| --- | --- | --- |
| **Refuses a one-session engine** | `wiggum`; `wiggum-duet` when the judge shares a backend with any work pin, or takes the default | verification comes from a separate evaluator, and one shared pane means the judge has read the work. Both refuse before spending anything |
| **Wants a watched pane** | `commit`, `commit-push`, `commit-recommit`, `commit-bankruptcy`; `partner-reviewer`, `partner-collaborator` (a pane that is *not* the work's); `partner-cleanup` (the work's own, because it edits); `expense`, `qanda`, `prd-draft`, `service-install`, `effort-forge` | a person's question is not a real gate when unattended — `--scripted` answers a flag *yes* and an unwatched run reaches nobody. The commit family is watched for a different reason: it is decomposing your tree |
| **Wants `--scratch "$PWD"` under acp** | every row that edits: `green-*`, `stack-*`, `issue`, `issue-worktree`, `dead-code`, `comments`, `productize*`, `nix-*`, `checklist`, `claude-md`, `prose-proofread`, `prose-transcript`, `tron`, `retest*`, `effort-*`, `partner-cleanup`, `wiggum` — and any other row whose written report you mean to keep | the scratch directory is the only place an act may write, and without the flag it is a fresh temporary one |
| **Fine anywhere** | the review ladder, `fess`, the confer family, `pr-threads*`, the account family, the Org pair, `claude-md-advise`, `prose-smooth`, `prose-compress`, `bundles`, `query`, `transcribe`, `denote`, the translate family, `prd-critique`, `nodered`, `teams`, `notes`, `hello` | they read, fan out and write one report. The transport still changes what the report *means* — see `fess` and `confer` — but no ending is unreachable |

## Building and installing it

```sh
nix build              # -> ./result/bin/wf, the pinned build
./result/bin/wf list
```

That is the whole of it for a first run: `nix build` produces `result/bin/wf`
against the agent-cat revision `flake.lock` names, and needs nothing installed.
To put `wf` on `PATH` — which is what the rows actually want, since every
`running` party's argv executes in the process's working directory and a
`cabal run` wrapper would answer `git diff` about the wrong repository — either
`nix profile install .#default`, or, in the dev loop,
`cabal install exe:wf --installdir=$HOME/.local/bin --overwrite-policy=always`
from inside `nix develop`. `nix run . -- list` reads the toolbox without
installing anything at all. `README.md`'s "Building it" section has the rest:
which of the flake and `cabal.project` is authoritative, and what a `cabal build`
green against a `nix build` red is telling you.
