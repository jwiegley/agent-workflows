# Running the workflows

*Seventy-four rows, grouped by family: what each one is, what it costs, what its
inputs mean, one command line you can type, and the rehearsal that costs
nothing. `README.md` has the general grammar; this page is the per-row
specifics.*

**Every per-row section below is generated.** It is the price `wf list --json`
publishes, rendered in this page's own form, followed by `wf help <row>` — the
same page a terminal prints, from the same text, so the two cannot say different
things. `tools/cookbook-gen.sh` writes them and `ci/cookbook.sh` refuses any
difference; what is between a row's `wf:begin` and `wf:end` markers belongs to
the module that owns the program, and an edit made here is reverted by the next
regeneration. Everything else on this page — the grammar, the family prose, the
transport table, the build instructions — is authored, because no row owns it.

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
cannot exceed. Twenty-one of the seventy-four price *exactly*, min equal to max,
and those are written as a single number.

## The review ladder

Four rungs over one frozen snapshot, priced side by side — which is the whole
reason the ladder is four rows and not one flag with a weight adjective.

**Inputs, shared by all four.** `scope` is what to review: a git ref, a range,
or empty for the uncommitted changes. It becomes the *argv* of the snapshot
command rather than a string a model interprets. `paths` is the changed-file
list, one per line, and at two of the four rungs it selects the language roster
and the linters in ordinary Haskell before the program exists — so `plan` must
be given the same `paths=` the run will use or it prices a different program.
Each rung's section says what it selects there, because the answer differs.

`changed.txt` below is that file list, and `git diff --name-only > changed.txt`
is the usual way to make one. Every row on this page that takes a `paths=` reads
it the same way.

Rehearse any rung, and read the four bills against each other:

```sh
for r in review-quick review-deep review-sec review-heavy; do
  wf cost "$r"
  wf run "$r" --scripted --input-arg scope= --input-arg paths=
done
```

### `review-quick`

<!-- wf:begin review-quick -->

`branch · 3 to 6 over 3 paths`

`commands/quick-review.md` as a program: one lens over a frozen scope
snapshot, and the floor of a four-rung ladder that exists so the four
bills can be read against each other before one is chosen.

**Inputs.**

* `scope` — what to review: a git ref, a range, or empty for the uncommitted
  changes. It becomes the *argv* of the snapshot command and not a phrase a
  model interprets, so `HEAD~3..HEAD` means to `git diff` what it means to
  you. The snapshot is bound once and every reviewer below reads that one
  handle, so no two of them can be looking at different trees.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one.
  At this rung it selects **nothing**: the roster is one lens and the
  dossier is the diff-name receipt alone, so the file list is declared
  — the four rungs share one invocation — and read by neither. That is
  also why this rung's price does not move with it.

**Transport.** An adapter of the run's own, one fresh session per question.
This rung reports rather than refuses, and what it reports about itself is
read off `run.engine`: under one shared `--session` the provenance line says
in as many words that the passes were not reached independently, however
clean each block reads. It writes no file of yours, so `--scratch` changes
nothing about what it means.

```sh
wf run review-quick --engine acp --adapter claude --require-pinned \
   --input-arg scope= --input-file paths=changed.txt
```

**Rehearsal.** Both inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run review-quick --scripted --input-arg scope= --input-arg paths=
```

**Caveats.**

* One lens, and it is `quick-review.md`'s own: no language roster, no
  performance pass, none of the four required lenses, and no linter
  receipt. The floor of the ladder is a floor in coverage as well as
  in price.
* The cheapest ending reviews nothing, and it is the honest one. The
  parent-history sentinel probe is asked first and decided for free; if the
  line this run planted for itself comes back, no reviewer is asked, the
  report names the scope un-reviewed and it does not characterise the code.
* The other short ending is the fan-out's own: the consolidation must account
  for every block it was promised, and a document that came back short is
  reported as incomplete rather than ranked.
* An empty `paths=` is never an empty panel — it is the roster this rung has
  in the source. So the numbers above are a real program, and a file list
  that touches four languages is a wider fan-out and a different bill;
  `wf cost review-quick --input-file paths=changed.txt` is the verb that answers
  that before anything is spent.

<!-- wf:end review-quick -->

### `review-deep`

<!-- wf:begin review-deep -->

`branch · 3 to 10 over 3 paths`

`commands/deep-review.md` as a program: the language roster the file
list selects, the performance pass, and the four lenses that file calls
required — built from one list, so a run cannot quietly do three of
them.

**Inputs.**

* `scope` — what to review: a git ref, a range, or empty for the uncommitted
  changes. It becomes the *argv* of the snapshot command and not a phrase a
  model interprets, so `HEAD~3..HEAD` means to `git diff` what it means to
  you. The snapshot is bound once and every reviewer below reads that one
  handle, so no two of them can be looking at different trees.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one.
  At this rung it selects both the language reviewers and the
  `## Tool integration` receipt of each language it touches, in
  ordinary Haskell before the program exists — so `plan` must be given
  the same `paths=` the run will use or it prices a different
  program.

**Transport.** An adapter of the run's own, one fresh session per question.
This rung reports rather than refuses, and what it reports about itself is
read off `run.engine`: under one shared `--session` the provenance line says
in as many words that the passes were not reached independently, however
clean each block reads. It writes no file of yours, so `--scratch` changes
nothing about what it means.

```sh
wf run review-deep --engine acp --adapter claude --require-pinned \
   --input-arg scope=HEAD~3..HEAD --input-file paths=changed.txt
```

**Rehearsal.** Both inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run review-deep --scripted --input-arg scope= --input-arg paths=
```

**Caveats.**

* The security lens is deliberately absent. `deep-review.md` says not
  to run one by default and `sec-audit.md` says it is the whole of one,
  so the sentence became the difference between two rows: `review-sec`
  is that row, and running both is how you get both.
* The cheapest ending reviews nothing, and it is the honest one. The
  parent-history sentinel probe is asked first and decided for free; if the
  line this run planted for itself comes back, no reviewer is asked, the
  report names the scope un-reviewed and it does not characterise the code.
* The other short ending is the fan-out's own: the consolidation must account
  for every block it was promised, and a document that came back short is
  reported as incomplete rather than ranked.
* An empty `paths=` is never an empty panel — it is the roster this rung has
  in the source. So the numbers above are a real program, and a file list
  that touches four languages is a wider fan-out and a different bill;
  `wf cost review-deep --input-file paths=changed.txt` is the verb that answers
  that before anything is spent.

<!-- wf:end review-deep -->

### `review-sec`

<!-- wf:begin review-sec -->

`branch · 3 to 6 over 3 paths`

`commands/sec-audit.md` as a program: the language roster plus the one
cross-cutting lens that file says is the whole of a security review,
over the same frozen snapshot and the same command receipts
`review-deep` reads.

**Inputs.**

* `scope` — what to review: a git ref, a range, or empty for the uncommitted
  changes. It becomes the *argv* of the snapshot command and not a phrase a
  model interprets, so `HEAD~3..HEAD` means to `git diff` what it means to
  you. The snapshot is bound once and every reviewer below reads that one
  handle, so no two of them can be looking at different trees.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one.
  At this rung it selects both the language reviewers and the
  `## Tool integration` receipt of each language it touches, in
  ordinary Haskell before the program exists — so `plan` must be given
  the same `paths=` the run will use or it prices a different
  program.

**Transport.** An adapter of the run's own, one fresh session per question.
This rung reports rather than refuses, and what it reports about itself is
read off `run.engine`: under one shared `--session` the provenance line says
in as many words that the passes were not reached independently, however
clean each block reads. It writes no file of yours, so `--scratch` changes
nothing about what it means.

```sh
wf run review-sec --engine acp --adapter claude --require-pinned \
   --input-arg scope=origin/main..HEAD --input-file paths=changed.txt
```

**Rehearsal.** Both inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run review-sec --scripted --input-arg scope= --input-arg paths=
```

**Caveats.**

* This is not `review-deep` with security added. The performance pass
  and the four required lenses are not in it — it is the language
  roster plus one lens — so a change that wants both wants two runs.
* The cheapest ending reviews nothing, and it is the honest one. The
  parent-history sentinel probe is asked first and decided for free; if the
  line this run planted for itself comes back, no reviewer is asked, the
  report names the scope un-reviewed and it does not characterise the code.
* The other short ending is the fan-out's own: the consolidation must account
  for every block it was promised, and a document that came back short is
  reported as incomplete rather than ranked.
* An empty `paths=` is never an empty panel — it is the roster this rung has
  in the source. So the numbers above are a real program, and a file list
  that touches four languages is a wider fan-out and a different bill;
  `wf cost review-sec --input-file paths=changed.txt` is the verb that answers
  that before anything is spent.

<!-- wf:end review-sec -->

### `review-heavy`

<!-- wf:begin review-heavy -->

`branch · 3 to 12 over 3 paths`

`commands/heavy-review.md` as a program: seven independent passes over
one frozen snapshot — the deep pass, Alexey's discipline, abstraction
alignment, the validated multi-model pass, ponytail, dead code and the
comment audit — folded into a document whose synthesis must account
for every block it was promised before it may rank anything.

**Inputs.**

* `scope` — what to review: a git ref, a range, or empty for the uncommitted
  changes. It becomes the *argv* of the snapshot command and not a phrase a
  model interprets, so `HEAD~3..HEAD` means to `git diff` what it means to
  you. The snapshot is bound once and every reviewer below reads that one
  handle, so no two of them can be looking at different trees.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one.
  At this rung it selects the linter receipts and nothing else: the
  roster is `heavy-review.md`'s own fixed seven. `plan` still wants the
  same `paths=` the run will use, because a receipt is a question.

**Transport.** An adapter of the run's own, one fresh session per question.
This rung reports rather than refuses, and what it reports about itself is
read off `run.engine`: under one shared `--session` the provenance line says
in as many words that the passes were not reached independently, however
clean each block reads. It writes no file of yours, so `--scratch` changes
nothing about what it means.

```sh
wf run review-heavy --engine acp --adapter claude --require-pinned \
   --input-arg scope=origin/main..HEAD --input-file paths=changed.txt
```

**Rehearsal.** Both inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run review-heavy --scripted --input-arg scope= --input-arg paths=
```

**Caveats.**

* It does not consult the language reviewers at all: the seven passes
  are the whole roster, by `heavy-review.md`'s own count. A wider
  `paths=` therefore buys linter receipts and never a reviewer.
* The cheapest ending reviews nothing, and it is the honest one. The
  parent-history sentinel probe is asked first and decided for free; if the
  line this run planted for itself comes back, no reviewer is asked, the
  report names the scope un-reviewed and it does not characterise the code.
* The other short ending is the fan-out's own: the consolidation must account
  for every block it was promised, and a document that came back short is
  reported as incomplete rather than ranked.
* An empty `paths=` is never an empty panel — it is the roster this rung has
  in the source. So the numbers above are a real program, and a file list
  that touches four languages is a wider fan-out and a different bill;
  `wf cost review-heavy --input-file paths=changed.txt` is the verb that answers
  that before anything is spent.

<!-- wf:end review-heavy -->

## The green fix loops

Check, repair, recheck — where the review clause is a real exit code and the
number of repair trips is printed before the first one. All three edit, so give
them somewhere to edit.

**Input.** `target` is the thing green is about: the pull request *number* at
`green-ci` (it is the argv of both `gh` commands), a one-line description of
what green means at `green-tree`, and the failing-test report at `green-flaky`.

### `green-ci`

<!-- wf:begin green-ci -->

`branch · 4 to 10 over 8 paths`

`commands/fix-ci.md` and `commands/bugbot.md` as one program: build the
inventory of unresolved bot items from the pull request's own record,
run `bugbot`'s five phases as a called function rather than a copied
paragraph, then repair until the checks exit 0.

**Inputs.**

* `target` — the pull request. It is the *argv* of both `gh` commands
  — `gh pr view` for the inventory and `gh pr checks` for the gate — so
  it must be the number and nothing else. A phrase here reaches a
  command line, not a model, and `gh` will say so.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own, and `--scratch "$PWD"`, because every repair trip edits your tree and
the scratch directory is the only place an acting turn may write. Without it
the loop repairs a copy in a temporary directory and reports success about
it.

```sh
wf run green-ci --engine acp --adapter claude --require-pinned \
   --scratch "$PWD" \
   --input-arg target=1487
```

**Rehearsal.** The one input named empty, and the canned table approves on
the first trip so the run walks the settled arm end to end:

```sh
wf run green-ci --scripted --input-arg target=
```

**Caveats.**

* The inventory is bound once, before the first repair, so a bot
  comment that arrives mid-run has no way into it. That is `bugbot`'s
  scoping rule made structural rather than requested, and it is why a
  sweep can be said to be complete.
* Three repair trips, and the number is printed before the first one. When
  they run out the run reports the state it is holding and says
  still-red; it does not claim green and it does not throw the repairs
  away.
* The sweep is an act and not an ask: it pushes commits, posts replies
  and resolves threads. Under `--engine acp` nobody is between it and
  your pull request, so `--scratch "$PWD"` and a branch you are willing
  to have written to are both part of the invocation.

<!-- wf:end green-ci -->

### `green-tree`

<!-- wf:begin green-tree -->

`branch · 3 to 9 over 8 paths`

The four corpus files that all say "get the tree green", as one
program: take `git status` as a receipt, then repair until
`nix flake check` exits 0 — a review clause that is a real exit code
and a trip count printed before the first trip.

**Inputs.**

* `target` — one line saying what green means for this tree. It is
  *data* inside the prompt and not an argv: `nix flake check` is the
  whole of the objection, and this sentence only tells each repair what
  it was supposed to be aiming at. Empty is legal and reads as a tree
  with no stated goal.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own, and `--scratch "$PWD"`, because every repair trip edits your tree and
the scratch directory is the only place an acting turn may write. Without it
the loop repairs a copy in a temporary directory and reports success about
it.

```sh
wf run green-tree --engine acp --adapter claude --require-pinned \
   --scratch "$PWD" \
   --input-arg target='nix flake check is green on this tree'
```

**Rehearsal.** The one input named empty, and the canned table approves on
the first trip so the run walks the settled arm end to end:

```sh
wf run green-tree --scripted --input-arg target=
```

**Caveats.**

* `nix flake check` is the reviewer, and it is the only reviewer.
  Nothing here asks a model whether the tree is green, which is the
  whole difference between this row and the paragraph it replaces.
* Three repair trips, and the number is printed before the first one. When
  they run out the run reports the state it is holding and says
  still-red; it does not claim green and it does not throw the repairs
  away.
* `--input-arg target=` empty still runs: the gate is the command, so
  an unstated goal costs the repairs their aim and not the run its
  ending. Say what green means.

<!-- wf:end green-tree -->

### `green-flaky`

<!-- wf:begin green-flaky -->

`branch · 6 to 11 over 9 paths`

`commands/flaky-rust.md` as a program: three draws of the suite, a
triage report written from all three, a repair loop, and an
independent fourth draw that decides *flaky* from *broken*.

**Inputs.**

* `target` — the failing-test report: what was seen red, and how often.
  It is *data* inside the triage prompt and not an argv — `make test`
  is the command drawn four times, and this text is what the triage is
  written against.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own, and `--scratch "$PWD"`, because every repair trip edits your tree and
the scratch directory is the only place an acting turn may write. Without it
the loop repairs a copy in a temporary directory and reports success about
it.

```sh
wf run green-flaky --engine acp --adapter claude --require-pinned \
   --scratch "$PWD" \
   --input-arg target='tests::token_refresh::race is red about one run in five'
```

**Rehearsal.** The one input named empty, and the canned table approves on
the first trip so the run walks the settled arm end to end:

```sh
wf run green-flaky --scripted --input-arg target=
```

**Caveats.**

* Four draws of one suite, not one. Three before the loop — two draws
  of one prompt are two questions and are billed as two — and an
  independent fourth after it, so the *flaky* / *broken* call is an
  exit code and not a claim by the party that just did the fixing.
* Two repair trips, the smallest budget in the family, because a flake
  that needs a third is a bug with a stable cause. Exhausted, the run
  reports the state it is holding and calls the suite unfixed.
* A settled gate is not a green report. The fourth draw can disagree
  with the third, and that ending says GREEN ONCE, NOT STEADY and names
  what the two runs disagreed about — which is the finding, not a
  failure of the run.

<!-- wf:end green-flaky -->

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

<!-- wf:begin commit -->

`branch · 5 to 8 over 6 paths`

`commands/commit.md`, whole, as a program: the working tree decomposed
into an atomic, ordered series, staged and committed, then held to the
repository's own tests.

**Inputs.**

* `scope` — what is being committed: a branch name, a task description, a
  paste of `git status`. It is *data* in the decomposition's prompt, not an
  argv, and it is the only thing that tells the series what story it is
  telling.
* `tree` — the tree object this run must end at, tested by a free decider
  over `git rev-parse`. An empty one becomes the needle `<no tree given>`,
  which no receipt matches — so the run ends in the tree-moved report rather
  than skipping the check, and `wf plan commit --raw` prints
  that needle before you spend anything. Which object to pass is a fact
  about the rung:
  this rung commits new work, so it ends at the working tree, and
  `git add -A && git write-tree` prints the object to pass.

**Transport.** A watched pane. The decomposition is of *your* working tree
and the staging is an act, so `--session <pane>` is the shape this row is for:
the pane is where you can see what it is proposing to commit before it is
history.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.
Under `--engine acp` it works and nobody is looking, which for a row whose
whole job is rewriting your index is a choice and not a default.

```sh
wf run commit --session "$PANE" --require-pinned \
   --input-arg scope='the token-refresh work' \
   --input-arg tree="$(git add -A && git write-tree)"
```

**Rehearsal.** Both inputs named empty, and the canned table approves on the
first trip, so the run walks the gate's settled arm and then the tree-moved
ending — which is the correct ending for an unnamed tree. To rehearse the
*intact* arm instead, pass the object the row's own table answers the
postcondition receipt with:
`--input-arg tree=4b825dc642cb6eb9a060e54bf8d69288fbee4904`.

```sh
wf run commit --scripted --input-arg scope= --input-arg tree=
```

**Caveats.**

* One repair trip, printed before the first one. The comparison this
  family exists for is `wf cost commit` beside
  `wf cost commit-recommit`.
* The gate is `make test`, asked of the suite and not of the agent that just
  wrote the commits — `commit.md`'s own quality checklist item 4, and the
  objection each repair reads is the suite's first failing line.
* When the trips run out the tree keeps every edit the repairs made and the
  run reports the series it is holding. That is `commit.md`'s "prefer a
  slightly larger commit over a broken repository", as an ending rather than
  as advice.
* It commits and stops. Nothing is pushed and no pull request is opened
  — `commit-push` is the row that does that, and it is a different row
  because it is two more acts.

<!-- wf:end commit -->

### `commit-push`

<!-- wf:begin commit-push -->

`branch · 5 to 9 over 6 paths`

`commands/commit.md` and `push.md` as one program: the same series,
then `git push --force-with-lease` and `gh pr create` — so the last
commit's message is written knowing a reviewer reads it first.

**Inputs.**

* `scope` — what is being committed: a branch name, a task description, a
  paste of `git status`. It is *data* in the decomposition's prompt, not an
  argv, and it is the only thing that tells the series what story it is
  telling.
* `tree` — the tree object this run must end at, tested by a free decider
  over `git rev-parse`. An empty one becomes the needle `<no tree given>`,
  which no receipt matches — so the run ends in the tree-moved report rather
  than skipping the check, and `wf plan commit-push --raw` prints
  that needle before you spend anything. Which object to pass is a fact
  about the rung:
  this rung commits new work, so it ends at the working tree, and
  `git add -A && git write-tree` prints the object to pass.

**Transport.** A watched pane. The decomposition is of *your* working tree
and the staging is an act, so `--session <pane>` is the shape this row is for:
the pane is where you can see what it is proposing to commit before it is
history.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.
Under `--engine acp` it works and nobody is looking, which for a row whose
whole job is rewriting your index is a choice and not a default.

```sh
wf run commit-push --session "$PANE" --require-pinned \
   --input-arg scope='the token-refresh work' \
   --input-arg tree="$(git add -A && git write-tree)"
```

**Rehearsal.** Both inputs named empty, and the canned table approves on the
first trip, so the run walks the gate's settled arm and then the tree-moved
ending — which is the correct ending for an unnamed tree. To rehearse the
*intact* arm instead, pass the object the row's own table answers the
postcondition receipt with:
`--input-arg tree=4b825dc642cb6eb9a060e54bf8d69288fbee4904`.

```sh
wf run commit-push --scripted --input-arg scope= --input-arg tree=
```

**Caveats.**

* One repair trip, printed before the first one. The comparison this
  family exists for is `wf cost commit-push` beside
  `wf cost commit-recommit`.
* The gate is `make test`, asked of the suite and not of the agent that just
  wrote the commits — `commit.md`'s own quality checklist item 4, and the
  objection each repair reads is the suite's first failing line.
* When the trips run out the tree keeps every edit the repairs made and the
  run reports the series it is holding. That is `commit.md`'s "prefer a
  slightly larger commit over a broken repository", as an ending rather than
  as advice.
* The tail is two acts: a lease push and `gh pr create`. Both are
  downstream of the tree check, so an empty `tree=` means neither
  happens — the run reports the tree moved and publishes nothing.

<!-- wf:end commit-push -->

### `commit-recommit`

<!-- wf:begin commit-recommit -->

`branch · 5 to 12 over 12 paths`

`commands/recommit.md` as a program: the same series again, with every
commit held to standalone CI rather than only the tip, which is the
expensive claim in this family and the reason it gets the largest
repair budget.

**Inputs.**

* `scope` — what is being committed: a branch name, a task description, a
  paste of `git status`. It is *data* in the decomposition's prompt, not an
  argv, and it is the only thing that tells the series what story it is
  telling.
* `tree` — the tree object this run must end at, tested by a free decider
  over `git rev-parse`. An empty one becomes the needle `<no tree given>`,
  which no receipt matches — so the run ends in the tree-moved report rather
  than skipping the check, and `wf plan commit-recommit --raw` prints
  that needle before you spend anything. Which object to pass is a fact
  about the rung:
  this rung is a history-only rewrite, so it ends where it began — run
  `git rev-parse 'HEAD^{tree}'` *before* the unwind and pass that.

**Transport.** A watched pane. The decomposition is of *your* working tree
and the staging is an act, so `--session <pane>` is the shape this row is for:
the pane is where you can see what it is proposing to commit before it is
history.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.
Under `--engine acp` it works and nobody is looking, which for a row whose
whole job is rewriting your index is a choice and not a default.

```sh
wf run commit-recommit --session "$PANE" --require-pinned \
   --input-arg scope='the token-refresh branch, re-cut' \
   --input-arg tree="$(git rev-parse 'HEAD^{tree}')"
```

**Rehearsal.** Both inputs named empty, and the canned table approves on the
first trip, so the run walks the gate's settled arm and then the tree-moved
ending — which is the correct ending for an unnamed tree. To rehearse the
*intact* arm instead, pass the object the row's own table answers the
postcondition receipt with:
`--input-arg tree=4b825dc642cb6eb9a060e54bf8d69288fbee4904`.

```sh
wf run commit-recommit --scripted --input-arg scope= --input-arg tree=
```

**Caveats.**

* Three repair trips, the largest in the family, and they are what this
  rung's claim costs: every commit standalone-green is a harder thing
  to reach than a green tip.
* The gate is `make test`, asked of the suite and not of the agent that just
  wrote the commits — `commit.md`'s own quality checklist item 4, and the
  objection each repair reads is the suite's first failing line.
* When the trips run out the tree keeps every edit the repairs made and the
  run reports the series it is holding. That is `commit.md`'s "prefer a
  slightly larger commit over a broken repository", as an ending rather than
  as advice.
* Each commit is written to be submitted as its own pull request in a
  stack, which is a constraint on the *decomposition* and not only on
  the gate: a commit that only builds once its successor lands is
  refused by the style this rung asks for.

<!-- wf:end commit-recommit -->

### `commit-bankruptcy`

<!-- wf:begin commit-bankruptcy -->

`branch · 5 to 10 over 9 paths`

`commands/bankruptcy.md` as a program: recommit a branch whose history
has already been unwound, and then check that the tree really did not
move. The postcondition that file asks for is tested here, not hoped
for.

**Inputs.**

* `scope` — what is being committed: a branch name, a task description, a
  paste of `git status`. It is *data* in the decomposition's prompt, not an
  argv, and it is the only thing that tells the series what story it is
  telling.
* `tree` — the tree object this run must end at, tested by a free decider
  over `git rev-parse`. An empty one becomes the needle `<no tree given>`,
  which no receipt matches — so the run ends in the tree-moved report rather
  than skipping the check, and `wf plan commit-bankruptcy --raw` prints
  that needle before you spend anything. Which object to pass is a fact
  about the rung:
  this rung is a history-only rewrite, so it ends where it began — run
  `git rev-parse 'HEAD^{tree}'` *before* the unwind and pass that.

**Transport.** A watched pane. The decomposition is of *your* working tree
and the staging is an act, so `--session <pane>` is the shape this row is for:
the pane is where you can see what it is proposing to commit before it is
history.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.
Under `--engine acp` it works and nobody is looking, which for a row whose
whole job is rewriting your index is a choice and not a default.

```sh
wf run commit-bankruptcy --session "$PANE" --require-pinned \
   --input-arg scope='forty-one commits down to nine' \
   --input-arg tree="$(git rev-parse 'HEAD^{tree}')"
```

**Rehearsal.** Both inputs named empty, and the canned table approves on the
first trip, so the run walks the gate's settled arm and then the tree-moved
ending — which is the correct ending for an unnamed tree. To rehearse the
*intact* arm instead, pass the object the row's own table answers the
postcondition receipt with:
`--input-arg tree=4b825dc642cb6eb9a060e54bf8d69288fbee4904`.

```sh
wf run commit-bankruptcy --scripted --input-arg scope= --input-arg tree=
```

**Caveats.**

* Two repair trips, printed before the first one. The comparison this
  family exists for is `wf cost commit-bankruptcy` beside
  `wf cost commit-recommit`.
* The gate is `make test`, asked of the suite and not of the agent that just
  wrote the commits — `commit.md`'s own quality checklist item 4, and the
  objection each repair reads is the suite's first failing line.
* When the trips run out the tree keeps every edit the repairs made and the
  run reports the series it is holding. That is `commit.md`'s "prefer a
  slightly larger commit over a broken repository", as an ending rather than
  as advice.
* It assumes the unwind already happened — the work sitting uncommitted
  and the old history gone — and it tells the decomposition not to
  reproduce the old commit boundaries, because those are what was
  wrong. Capture the tree object before you unwind, or the
  postcondition has nothing to be checked against.

<!-- wf:end commit-bankruptcy -->

## `fess`

<!-- wf:begin fess -->

`branch · 16 over 2 paths`

`agents/fess-auditor.md` as a program: eleven sin categories as eleven
independent stances over three receipts — the diff, the worktree and the
history — folded into one report that must account for every category it was
promised.

**Inputs.**

* `request` — the original request or plan the work is being audited against,
  folded verbatim into *every* stance's brief. That is what lets the spec-drift
  category walk it point by point instead of guessing what was asked; the
  natural spelling is `--input-file request=doc/REQUEST.md`. Empty is legal and
  costs nothing: the eleven stances get their bare rubrics and the audit is
  then about the change alone.
* `base` — the revision the diff and the log are measured against, as the
  *argv* of `git diff` and `git log`. Empty is `HEAD`, which is the
  uncommitted-work case this file was written for — so name a base explicitly
  when the work is already committed.

**Transport.** An adapter of the run's own, one fresh session per question.
The transport is part of the audit here: the report's provenance paragraph
quotes `run.engine`, so under one shared `--session` it says that a stance may
have read the work it is auditing, and under a session per question it says
the opposite. Either way it downgrades and never refuses, so the price does
not move.

```sh
wf run fess --engine acp --adapter claude --require-pinned \
   --input-file request=doc/REQUEST.md --input-arg base=origin/main
```

**Rehearsal.** Both inputs named empty, one canned reply answering the whole
eleven-stance panel because they share an opening:

```sh
wf run fess --scripted --input-arg request= --input-arg base=
```

**Caveats.**

* The branch is the parent-history sentinel probe's, and it is the probe's
  alone. It asks whether a line this run planted for itself was already in the
  answerer's context; that finds contamination *this* toolbox could cause and
  no other kind, which is why the passing arm states the engine fact beside
  the probe's answer and lets the reader draw the conclusion.
* Both endings write the same report through the same callee, one argument
  apart. There is no arm in which the audit is skipped — the file says
  downgrade, so it downgrades.
* Each stance reports only its own category and cites `file:line`, and says
  `none` only for what it actually checked. A category with nothing to say is
  an answer, and the report accounts for it.
* The eleventh category was missing until the landing verification found it.
  A category added to the rubric is one more question and no more paths, so
  what moves is the ceiling above and never the shape.

<!-- wf:end fess -->

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

<!-- wf:begin stack -->

`branch · 7 to 21 over 40 paths`

`commands/restack.md` as a program: `gt restack` to a fixpoint, every
conflict through one shared resolution step, then prove no commit was
lost with `git cherry` rather than with a reading, then submit.

**Inputs.**

* `trunk` — what the rewrite is brought up to date with. It is the *argv* of
  the advancing command, and empty is `main`.
* `tip` — this branch's tip *before* the run, and the input the proof is made
  of. It is resolved in step 1, before the first act, so a run that cannot
  name where it started never starts; it is then the argv of the `git cherry`
  the loss decider reads. An empty one is `<no tip given>`, which is a
  revision nothing resolves — so take it first:
  `--input-arg tip="$(git rev-parse HEAD)"`.
* `agents` — the routing table the shared `resolve` step is called with: which
  specialist resolves what. Empty is not an empty table, it is this rung's own
  default doctrine, and `wf plan stack --raw` prints it.
* `pr` — declared, because the four rungs share one invocation, and
  *ignored* by this rung: only `stack-rebase-fix` watches a pull
  request afterwards. Name it empty and nothing is lost.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own, and `--scratch "$PWD"`, because the sync and the publish are acts against
your history and the scratch directory is the only place an acting turn may
write. A watched pane also works and is the choice to make when you want to
see a rewrite as it happens.

```sh
wf run stack --engine acp --adapter claude --require-pinned \
   --scratch "$PWD" \
   --input-arg trunk=main --input-arg tip="$(git rev-parse HEAD)" \
   --input-arg agents= --input-arg pr=
```

**Rehearsal.** All four inputs named empty; the canned table settles both
loops on the first trip and reports no commit lost, so the run walks the
publishing arm end to end:

```sh
wf run stack --scripted --input-arg trunk= --input-arg tip= \
   --input-arg agents= --input-arg pr=
```

**Caveats.**

* It is the same program as `stack-rebase` — the header's numbers are
  identical — and the only difference is which command advances the
  stack. Choose by which tool owns your branches, not by price.
* The proof is read by a decider and not by a reader. `git cherry` is asked
  as a receipt and a free test over it decides whether a commit was lost; the
  losing arm reports the loss and publishes *nothing*, and it costs no
  question, which is why it adds a path and not a consultation.
* There are two bounded loops, not one: the advancing command to a fixpoint,
  and then `nix flake check` over the settled result. Either can run out, and
  each has its own ending that keeps the work and says which one it was.
* Conflict resolution is one called function shared with three other files.
  What `agents=` changes is the doctrine that function is called with — a
  define, decided before the program exists — and never the shape of the run.

<!-- wf:end stack -->

### `stack-rebase`

<!-- wf:begin stack-rebase -->

`branch · 7 to 21 over 40 paths`

`commands/rebase.md` as a program: the same shape with `git` deciding
instead of `gt` — rebase onto the trunk to a fixpoint, prove nothing was
lost, push with a lease.

**Inputs.**

* `trunk` — what the rewrite is brought up to date with. It is the *argv* of
  the advancing command, and empty is `main`.
* `tip` — this branch's tip *before* the run, and the input the proof is made
  of. It is resolved in step 1, before the first act, so a run that cannot
  name where it started never starts; it is then the argv of the `git cherry`
  the loss decider reads. An empty one is `<no tip given>`, which is a
  revision nothing resolves — so take it first:
  `--input-arg tip="$(git rev-parse HEAD)"`.
* `agents` — the routing table the shared `resolve` step is called with: which
  specialist resolves what. Empty is not an empty table, it is this rung's own
  default doctrine, and `wf plan stack-rebase --raw` prints it.
* `pr` — declared, because the four rungs share one invocation, and
  *ignored* by this rung: only `stack-rebase-fix` watches a pull
  request afterwards. Name it empty and nothing is lost.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own, and `--scratch "$PWD"`, because the sync and the publish are acts against
your history and the scratch directory is the only place an acting turn may
write. A watched pane also works and is the choice to make when you want to
see a rewrite as it happens.

```sh
wf run stack-rebase --engine acp --adapter claude --require-pinned \
   --scratch "$PWD" \
   --input-arg trunk=origin/main --input-arg tip="$(git rev-parse HEAD)" \
   --input-arg agents='haskell-pro for .hs, nix-pro for .nix' --input-arg pr=
```

**Rehearsal.** All four inputs named empty; the canned table settles both
loops on the first trip and reports no commit lost, so the run walks the
publishing arm end to end:

```sh
wf run stack-rebase --scripted --input-arg trunk= --input-arg tip= \
   --input-arg agents= --input-arg pr=
```

**Caveats.**

* It is the same program as `stack`, at a different advancing command,
  and the header's numbers say so. The publish is a lease push, which
  is an act against a remote branch somebody else may have moved.
* The proof is read by a decider and not by a reader. `git cherry` is asked
  as a receipt and a free test over it decides whether a commit was lost; the
  losing arm reports the loss and publishes *nothing*, and it costs no
  question, which is why it adds a path and not a consultation.
* There are two bounded loops, not one: the advancing command to a fixpoint,
  and then `nix flake check` over the settled result. Either can run out, and
  each has its own ending that keeps the work and says which one it was.
* Conflict resolution is one called function shared with three other files.
  What `agents=` changes is the doctrine that function is called with — a
  define, decided before the program exists — and never the shape of the run.

<!-- wf:end stack-rebase -->

### `stack-rebase-fix`

<!-- wf:begin stack-rebase-fix -->

`branch · 7 to 28 over 100 paths`

`commands/rebase-and-fix.md` as a program: `stack-rebase`, and then that
file's second half — push, watch the pull request's checks to green,
and sweep the bot threads the rewrite invalidated.

**Inputs.**

* `trunk` — what the rewrite is brought up to date with. It is the *argv* of
  the advancing command, and empty is `main`.
* `tip` — this branch's tip *before* the run, and the input the proof is made
  of. It is resolved in step 1, before the first act, so a run that cannot
  name where it started never starts; it is then the argv of the `git cherry`
  the loss decider reads. An empty one is `<no tip given>`, which is a
  revision nothing resolves — so take it first:
  `--input-arg tip="$(git rev-parse HEAD)"`.
* `agents` — the routing table the shared `resolve` step is called with: which
  specialist resolves what. Empty is not an empty table, it is this rung's own
  default doctrine, and `wf plan stack-rebase-fix --raw` prints it.
* `pr` — the pull request, and this is the one rung that reads it:
  after the push it is the argv of `gh pr checks` and of the
  `gh pr view` the bot sweep's inventory is built from, so it must be
  the number. Empty leaves both commands without an operand.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own, and `--scratch "$PWD"`, because the sync and the publish are acts against
your history and the scratch directory is the only place an acting turn may
write. A watched pane also works and is the choice to make when you want to
see a rewrite as it happens.

```sh
wf run stack-rebase-fix --engine acp --adapter claude --require-pinned \
   --scratch "$PWD" \
   --input-arg trunk=origin/main --input-arg tip="$(git rev-parse HEAD)" \
   --input-arg agents='haskell-pro for .hs' --input-arg pr=1487
```

**Rehearsal.** All four inputs named empty; the canned table settles both
loops on the first trip and reports no commit lost, so the run walks the
publishing arm end to end:

```sh
wf run stack-rebase-fix --scripted --input-arg trunk= --input-arg tip= \
   --input-arg agents= --input-arg pr=
```

**Caveats.**

* The most expensive rung in the family, and the difference is exactly
  `rebase-and-fix.md`'s second half: a second gate over the pull
  request's checks and a bot sweep after it. The sweep's inventory is
  bound once and after the push, so a comment arriving during it has no
  way in.
* The proof is read by a decider and not by a reader. `git cherry` is asked
  as a receipt and a free test over it decides whether a commit was lost; the
  losing arm reports the loss and publishes *nothing*, and it costs no
  question, which is why it adds a path and not a consultation.
* There are two bounded loops, not one: the advancing command to a fixpoint,
  and then `nix flake check` over the settled result. Either can run out, and
  each has its own ending that keeps the work and says which one it was.
* Conflict resolution is one called function shared with three other files.
  What `agents=` changes is the doctrine that function is called with — a
  define, decided before the program exists — and never the shape of the run.

<!-- wf:end stack-rebase-fix -->

### `stack-cleanup`

<!-- wf:begin stack-cleanup -->

`branch · 7 to 19 over 30 paths`

`commands/cleanup.md` as a program: `lefthook run --all-files
pre-commit` green on every branch in the stack, then the closing
`gt restack` — which is the step that can conflict here.

**Inputs.**

* `trunk` — what the rewrite is brought up to date with. It is the *argv* of
  the advancing command, and empty is `main`.
* `tip` — this branch's tip *before* the run, and the input the proof is made
  of. It is resolved in step 1, before the first act, so a run that cannot
  name where it started never starts; it is then the argv of the `git cherry`
  the loss decider reads. An empty one is `<no tip given>`, which is a
  revision nothing resolves — so take it first:
  `--input-arg tip="$(git rev-parse HEAD)"`.
* `agents` — the routing table the shared `resolve` step is called with: which
  specialist resolves what. Empty is not an empty table, it is this rung's own
  default doctrine, and `wf plan stack-cleanup --raw` prints it.
* `pr` — declared, because the four rungs share one invocation, and
  *ignored* by this rung: only `stack-rebase-fix` watches a pull
  request afterwards. Name it empty and nothing is lost.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own, and `--scratch "$PWD"`, because the sync and the publish are acts against
your history and the scratch directory is the only place an acting turn may
write. A watched pane also works and is the choice to make when you want to
see a rewrite as it happens.

```sh
wf run stack-cleanup --engine acp --adapter claude --require-pinned \
   --scratch "$PWD" \
   --input-arg trunk=main --input-arg tip="$(git rev-parse HEAD)" \
   --input-arg agents= --input-arg pr=
```

**Rehearsal.** All four inputs named empty; the canned table settles both
loops on the first trip and reports no commit lost, so the run walks the
publishing arm end to end:

```sh
wf run stack-cleanup --scripted --input-arg trunk= --input-arg tip= \
   --input-arg agents= --input-arg pr=
```

**Caveats.**

* This rung resolves no conflicts of its own — it runs the hooks over
  every branch and then restacks — so its default doctrine says in as
  many words that there may be nothing to resolve at all. Its fixer is
  addressed by a different name, which is what makes a trace say which
  job it was doing.
* The proof is read by a decider and not by a reader. `git cherry` is asked
  as a receipt and a free test over it decides whether a commit was lost; the
  losing arm reports the loss and publishes *nothing*, and it costs no
  question, which is why it adds a path and not a consultation.
* There are two bounded loops, not one: the advancing command to a fixpoint,
  and then `nix flake check` over the settled result. Either can run out, and
  each has its own ending that keeps the work and says which one it was.
* Conflict resolution is one called function shared with three other files.
  What `agents=` changes is the doctrine that function is called with — a
  define, decided before the program exists — and never the shape of the run.

<!-- wf:end stack-cleanup -->

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

<!-- wf:begin confer -->

`pipeline · 5 over 1 path`

Three stances over one decision — the case for, what breaks and traced
to a mechanism, and which claims the context actually settles — folded
into a document and then synthesised.

**Inputs.**

* `decision` — the question being conferred over, stated as a decision and
  not as a topic. It reaches every seat as *data*, so no turn can rewrite it
  and all of them are answering the same question.
* `context` — the material it is decided against, and
  `--input-file context=doc/design.md` is the natural spelling: the operator's
  text arrives as data, which is why this row does not open by asking a tool
  to go and read a file. Empty is legal and the brief says so in as many
  words, so nobody has to invent a placeholder.

**Transport.** An adapter of the run's own, and a `--route` per pinned seat
whenever you want a seat served by somebody other than the house model.
Three seats, three pins, and the report's provenance paragraph is
derived from where they actually landed.

```sh
wf run confer --engine acp --adapter claude --require-pinned \
   --route gemini-3.1-pro-preview=acp:codex \
   --input-arg decision='Should the registry be one table or two?' \
   --input-file context=doc/design.md
```

**Rehearsal.** Both inputs named empty, every seat answered from the row's own
canned table:

```sh
wf run confer --scripted --input-arg decision= --input-arg context=
```

**Caveats.**

* The synthesis is a fourth question, and it is where this row's price
  differs from `confer-bare`'s. If you want the three stances and none
  of the reconciling, that row is a smaller bill and a different
  artefact.
* Unrouted under one adapter the three seats are three fresh sessions
  of one model. That is independence of context and not of judgment,
  and it is not what agreement across three providers would mean; the
  report says which you got rather than letting the reader assume.
* It writes a document and touches nothing else, so `--scratch` changes
  nothing about what it means.
* There is no Markdown behind these rows. They are the workflow-native
  counterpart of a consensus tool, and what they add is a price before the
  spend and a trace after it.

<!-- wf:end confer -->

### `confer-bare`

<!-- wf:begin confer-bare -->

`pipeline · 4 over 1 path`

The same three stances, written down and deliberately *not* reconciled.
This is the row for when the reconciliation is yours to do and a
synthesis would be a fourth opinion wearing the other three's clothes.

**Inputs.**

* `decision` — the question being conferred over, stated as a decision and
  not as a topic. It reaches every seat as *data*, so no turn can rewrite it
  and all of them are answering the same question.
* `context` — the material it is decided against, and
  `--input-file context=doc/design.md` is the natural spelling: the operator's
  text arrives as data, which is why this row does not open by asking a tool
  to go and read a file. Empty is legal and the brief says so in as many
  words, so nobody has to invent a placeholder.

**Transport.** An adapter of the run's own, and a `--route` per pinned seat
whenever you want a seat served by somebody other than the house model.
Three seats, three pins, and the report's provenance paragraph is
derived from where they actually landed.

```sh
wf run confer-bare --engine acp --adapter claude --require-pinned \
   --route gemini-3.1-pro-preview=acp:codex \
   --input-arg decision='Should the registry be one table or two?' \
   --input-file context=doc/design.md
```

**Rehearsal.** Both inputs named empty, every seat answered from the row's own
canned table:

```sh
wf run confer-bare --scripted --input-arg decision= --input-arg context=
```

**Caveats.**

* Nothing reconciles the three blocks, on purpose. The document is the
  deliverable and the disagreement in it is the finding — do not read
  the last block as a conclusion.
* Unrouted under one adapter the three seats are three fresh sessions
  of one model. That is independence of context and not of judgment,
  and it is not what agreement across three providers would mean; the
  report says which you got rather than letting the reader assume.
* It writes a document and touches nothing else, so `--scratch` changes
  nothing about what it means.
* There is no Markdown behind these rows. They are the workflow-native
  counterpart of a consensus tool, and what they add is a price before the
  spend and a trace after it.

<!-- wf:end confer-bare -->

### `debate`

<!-- wf:begin debate -->

`pipeline · 4 over 1 path`

For and against only: the standing roster with the middle seat filtered
out, synthesised. A debate is what it is by not having an assessor, and
the two seats' briefs are told so.

**Inputs.**

* `decision` — the question being conferred over, stated as a decision and
  not as a topic. It reaches every seat as *data*, so no turn can rewrite it
  and all of them are answering the same question.
* `context` — the material it is decided against, and
  `--input-file context=doc/design.md` is the natural spelling: the operator's
  text arrives as data, which is why this row does not open by asking a tool
  to go and read a file. Empty is legal and the brief says so in as many
  words, so nobody has to invent a placeholder.

**Transport.** An adapter of the run's own, and a `--route` per pinned seat
whenever you want a seat served by somebody other than the house model.
Two seats, two pins. Routing them apart is what turns "they agreed"
from a fact about one model's temperature into a fact about two.

```sh
wf run debate --engine acp --adapter claude --require-pinned \
   --route gemini-3.1-pro-preview=acp:codex \
   --input-arg decision='Should ci/workflows.sh pin costMax by equality?' \
   --input-file context=doc/design.md
```

**Rehearsal.** Both inputs named empty, every seat answered from the row's own
canned table:

```sh
wf run debate --scripted --input-arg decision= --input-arg context=
```

**Caveats.**

* It *filters* the standing roster rather than copying it, which is why
  a fourth seat added to `confer` moves `confer` and `confer-bare` and
  leaves this row exactly where it is.
* Unrouted under one adapter the two seats are two fresh sessions of
  one model. That is independence of context and not of judgment; the
  report says which you got rather than letting the reader assume.
* It writes a document and touches nothing else, so `--scratch` changes
  nothing about what it means.
* There is no Markdown behind these rows. They are the workflow-native
  counterpart of a consensus tool, and what they add is a price before the
  spend and a trace after it.

<!-- wf:end debate -->

### `second-opinion`

<!-- wf:begin second-opinion -->

`pipeline · 2 over 1 path`

One contrary party under the anti-sycophancy rubric, and an artefact.
It is the smallest shape in the confer family: one seat, told to argue
with the decision rather than agree with it, where `confer` seats a
panel and `debate` seats two sides.

**Inputs.**

* `decision` — the question being conferred over, stated as a decision and
  not as a topic. It reaches every seat as *data*, so no turn can rewrite it
  and all of them are answering the same question.
* `context` — the material it is decided against, and
  `--input-file context=doc/design.md` is the natural spelling: the operator's
  text arrives as data, which is why this row does not open by asking a tool
  to go and read a file. Empty is legal and the brief says so in as many
  words, so nobody has to invent a placeholder.

**Transport.** An adapter of the run's own, and a `--route` per pinned seat
whenever you want a seat served by somebody other than the house model.
This row asks one party, and it is deliberately not the house model:
the whole value of a second opinion is that it comes from somewhere
else, so a route that sends it back to the primary undoes the row.

```sh
wf run second-opinion --engine acp --adapter claude --require-pinned \
   --route gemini-3.1-pro-preview=acp:codex \
   --input-arg decision='I am about to fold the two registries into one.' \
   --input-file context=doc/design.md
```

**Rehearsal.** Both inputs named empty, every seat answered from the row's own
canned table:

```sh
wf run second-opinion --scripted --input-arg decision= --input-arg context=
```

**Caveats.**

* It carries no provenance paragraph and declares no run facts, because
  one block cannot be independently confirmed by anything. What it buys
  is an argument and not a consensus, and reading it as a consensus is
  the one way to misuse it.
* Unrouted under one adapter the contrary party is a fresh session of
  the house model. It will still argue — the rubric is what makes it
  argue — but an objection from the model that produced the thing being
  objected to is worth less than one from somewhere else, which is why
  this row's one seat is pinned away from the primary.
* It writes a document and touches nothing else, so `--scratch` changes
  nothing about what it means.
* There is no Markdown behind these rows. They are the workflow-native
  counterpart of a consensus tool, and what they add is a price before the
  spend and a trace after it.

<!-- wf:end second-opinion -->

## Wave 2's residue, and the smoke row

### `checklist`

<!-- wf:begin checklist -->

`branch · 2 to 8 over 4 paths`

`commands/process-checklist.md` as a program: two rounds over a Markdown
checklist, each behind a **free** unchecked-box test — a grep over bytes the
answering model did not write, so "there is still work" is a fact about the
file rather than a party's account of it.

**Inputs.**

* `checklist` — the *path* to the checklist file, passed as the argv of a
  `cat`, so `--input-arg` and **not** `--input-file`: the run wants the name,
  not the contents. An absent path becomes a name no file has, which
  `wf plan checklist --raw` prints and which is why a `--scripted` run never
  reaches a command at all.
* `scope` — what the round is about: the release blockers, one section, the
  whole list. It is an input and therefore a define, so it rides into both
  rounds as data.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because working through a checklist means editing
the tree it is about and the scratch directory is the only place an acting
turn may write.

```sh
wf run checklist --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg checklist=doc/TODO.md --input-arg scope='the release blockers'
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run checklist --scripted --input-arg checklist= --input-arg scope=
```

**Caveats.**

* **The cheapest ending is a list with nothing left on it**: two questions,
  no consultation about the work, and a run that says so. That is the free
  test doing its job, and it is why pointing this row at a finished list costs
  almost nothing.
* Two rounds is the shape and not a setting. A list that needs more is a list
  to run this row against again, and the second run's free test is what
  decides whether that is worth anything.
* It ticks boxes in the file it was given. Point it at a copy if you want the
  original untouched.

<!-- wf:end checklist -->

### `teams`

<!-- wf:begin teams -->

`branch · 13 over 2 paths`

`commands/teams.md` as a program: ten angles on one problem — research, prior
art, user experience, architecture, planning, testing and the rest — a devil's
advocate over the fold of them, and a review of all of it. It has no loop and
no branch, so what it costs is exactly the roster plus the three questions
that close it.

**Inputs.**

* `problem` — the thing being explored, in your own words
  (`how should the registry be split?`). Every angle reads this one sentence,
  so it is worth writing carefully: ten seats each answering a slightly
  different question is what a vague problem buys.
* `context` — the background it is explored against, and `--input-file
  context=doc/design.md` is the natural spelling. It reaches every member as
  data, which is why the row does not open by asking a tool to go and read
  your design.

**Transport.** Fine anywhere: ten readings, a fold, and one artefact. An
adapter of the run's own is the usual shape, and its fresh session per
question is worth something here — ten angles taken in one pane are ten turns
of one conversation, each having read the last.

```sh
wf run teams --engine acp --adapter claude --require-pinned \
   --input-arg problem='how should the registry be split?' \
   --input-file context=doc/design.md
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run teams --scripted --input-arg problem= --input-arg context=
```

**Caveats.**

* **It explores; it decides nothing.** The artefact is a document, and the
  devil's advocate is there to keep the fold from reading like agreement. If
  what you want is a decision argued to a verdict, the confer family is
  cheaper and shaped for it.
* Ten angles is the roster and not a setting. A problem that wants three
  opinions wants `confer`; this row is the one that is deliberately broad.
* It prices exactly, which means the number above is what it costs every time
  — there is no cheap ending to hope for.

<!-- wf:end teams -->

### `notes`

<!-- wf:begin notes -->

`branch · 17 over 3 paths`

`commands/meeting-notes.md` as a program: ten sections — metadata, themes,
decisions, action items, open questions, the timeline and the rest — over one
notes receipt, with five fact-only checkpoints put to **another engine**,
because a fact-only discipline audited by the model that wrote the prose is
not audited.

**Inputs.**

* `notes` — the *path* to the notes file, which becomes the argv of a `cat`.
  Use `--input-arg notes=PATH`. **`--input FILE` is the wrong flag here**: it
  would bind the file's contents where the row wants its name, and the run
  would read a filename that does not exist.

**Transport.** Fine anywhere: one receipt, ten sections, five checkpoints and
one report. An adapter of the run's own is the usual shape, and `--scratch` is
worth giving only if you mean to keep the file.

```sh
wf run notes --engine acp --adapter claude --require-pinned \
   --input-arg notes=doc/meeting-2026-08-12.md
```

**Rehearsal.** The one input named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run notes --scripted --input-arg notes=
```

**Caveats.**

* The five checkpoints are on a different engine by construction, and under
  one shared pane they are not. The report keeps its shape and reads the same;
  what it loses is the only thing that made "fact-only" more than a heading.
* **Fact-only means fact-only.** Nothing here infers what somebody meant, so
  a set of notes that recorded no decision produces a report with an empty
  decisions section rather than a plausible one.
* It prices exactly: ten sections and five checkpoints every time, with no
  cheap ending to hope for.

<!-- wf:end notes -->

## The effort ladder

Three tiers of the standard toolkit, sharing a shape and differing in exactly
what the skills say they differ in: `medium` inside `heavy` inside `forge`, with
the three prices finally beside the three names.

**Inputs, shared.** `task` is what all three entry points spell `$ARGUMENTS`.
`worktree` is the path read to decide whether this is one of the owner's
Positron directories — used by the `heavy` rung alone, which is what makes it
free at the other two.

### `effort-medium`

<!-- wf:begin effort-medium -->

`branch · 4 to 7 over 3 paths`

`commands/medium.md` as a program: the standard toolkit at its first
setting — plan, execute, and hold the tree to its own lint and
type-check gate. The floor of the ladder, and the rung to reach for when
the work is understood and the question is only whether it was done
properly.

**Inputs.**

* `task` — what all three entry points spell `$ARGUMENTS`: the thing to be
  planned and done, in your own words. It is the subject of every phase, and
  an empty one is a plan about nothing — which the plan prints.
* `worktree` — the path `effort-heavy` reads to decide whether it is
  under a Positron directory, and **this rung does not read it**. The
  three rows share one invocation, so it is declared here and consumed
  nowhere; that is also what makes it free at this rung.

**Transport.** Unattended, with somewhere to write: an adapter of the run's own and
`--scratch "$PWD"`, because this rung edits your tree and the scratch
directory is the only place an acting turn may write.

```sh
wf run effort-medium --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg task='add the missing --dry-run flag' --input-arg worktree=
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run effort-medium --scripted --input-arg task= --input-arg worktree=
```

**Caveats.**

* No partners, no multi-model consensus, no approval pause. If the work
  needs an argument before it is done, that is `effort-heavy` or
  `effort-forge`, and the difference in price is the difference in what
  is asked.
* The three rungs are a ladder the owner already had as an unpriced cost model
  — medium inside heavy inside forge — and the point of them being three rows
  is that the three bills sit side by side in `wf list` before one is chosen.
* Every rung ends by holding the tree to a gate that is a *command's exit
  code*, not a party's opinion. Which command differs between the rungs, and
  the skills state the difference.

<!-- wf:end effort-medium -->

### `effort-heavy`

<!-- wf:begin effort-heavy -->

`branch · 7 to 10 over 3 paths`

`commands/heavy.md` as a program: the same shape, plus the two pinned
partners and the Positron context — the latter decided for *free*, in
ordinary Haskell over the worktree path, before the program exists.

**Inputs.**

* `task` — what all three entry points spell `$ARGUMENTS`: the thing to be
  planned and done, in your own words. It is the subject of every phase, and
  an empty one is a plan about nothing — which the plan prints.
* `worktree` — the path read to decide whether this is one of the
  owner's Positron directories, which selects the extra context this
  rung carries. It is read in ordinary Haskell — tier 1, zero questions
  — so it changes a define rather than a path, and an empty one is
  simply the non-Positron shape.

**Transport.** Unattended, with somewhere to write: an adapter of the run's own and
`--scratch "$PWD"`, because this rung edits your tree and the scratch
directory is the only place an acting turn may write.

```sh
wf run effort-heavy --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg task='bring the token-refresh path under test' --input-arg worktree="$HOME/src/positron/my-project"
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run effort-heavy --scripted --input-arg task= --input-arg worktree=
```

**Caveats.**

* The Positron context is decided for nothing and is either there or
  not. An empty `worktree=` is the non-Positron shape, which is a
  smaller define and the same program — so this rung does not become
  `effort-medium` when the flag is missing.
* The three rungs are a ladder the owner already had as an unpriced cost model
  — medium inside heavy inside forge — and the point of them being three rows
  is that the three bills sit side by side in `wf list` before one is chosen.
* Every rung ends by holding the tree to a gate that is a *command's exit
  code*, not a party's opinion. Which command differs between the rungs, and
  the skills state the difference.

<!-- wf:end effort-heavy -->

### `effort-forge`

<!-- wf:begin effort-forge -->

`branch · 10 to 24 over 16 paths`

`skills/forge/SKILL.md` as a program: the six phases, the approval pause
in the middle, and a remediation loop with three endings. The top of the
ladder, and the only rung that stops and asks.

**Inputs.**

* `task` — what all three entry points spell `$ARGUMENTS`: the thing to be
  planned and done, in your own words. It is the subject of every phase, and
  an empty one is a plan about nothing — which the plan prints.
* `worktree` — the path `effort-heavy` reads to decide whether it is
  under a Positron directory, and **this rung does not read it**. The
  three rows share one invocation, so it is declared here and consumed
  nowhere; that is also what makes it free at this rung.

**Transport.** A watched pane. This rung puts an approval to the owner in binding
position — the phases after it are reached only through his answer — and
an unattended run reaches nobody: `--scripted` answers the confirmation
from a table and an adapter of the run's own has no one to ask.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run effort-forge --session "$PANE" --require-pinned \
   --input-arg task='design the retry policy' --input-arg worktree=
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run effort-forge --scripted --input-arg task= --input-arg worktree=
```

**Caveats.**

* The approval pause is a real gate only when somebody is watching. A
  rehearsal answers it from the row's own table, which exercises the
  loop and tells you nothing about what you would have said.
* The remediation loop has three endings and the third is the one to
  read hardest: it means the work could not be brought to the standard
  the plan set, which is a result and not a crash.
* The three rungs are a ladder the owner already had as an unpriced cost model
  — medium inside heavy inside forge — and the point of them being three rows
  is that the three bills sit side by side in `wf list` before one is chosen.
* Every rung ends by holding the tree to a gate that is a *command's exit
  code*, not a party's opinion. Which command differs between the rungs, and
  the skills state the difference.

<!-- wf:end effort-forge -->

## The daily drivers

### `pr-threads`

<!-- wf:begin pr-threads -->

`branch · 3 to 5 over 3 paths`

`commands/respond.md` as a program: the pull request's own comment
ledger, one drafted answer per open colleague comment, and a Markdown
report carrying them — the whole file, which is one sentence, with the
finding of the comments done by a command instead of by whoever read
it.

**Inputs.**

* `pr` — the pull request number, and it is the *argv* of `gh pr view` rather
  than a phrase a model interprets. The comment inventory is built from that
  command's own JSON and bound once, so a comment that arrives mid-run belongs
  to the next run and a comment nobody left cannot be answered.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one. At
  this rung it selects **nothing**: the answers are drafted against the
  comments, so the file list is declared and read by neither the roster
  nor a receipt. That is also why this rung's price does not move with
  it.

**Transport.** Fine anywhere: it reads a ledger, fans out over it and writes
one report. An adapter of the run's own is the usual shape, and `--scratch` is
worth giving only if you mean to keep the report file.

**Nothing is posted back, and that is an absence rather than a rule.** Every
question here is asked at `text` or folded from `text` answers, and only an
act at `ack` carries write authority — of which this program has exactly one,
and it writes the report. There is no `gh pr comment` in the tree's evidence
module for a run to reach for, so no member *can* post.

```sh
wf run pr-threads --engine acp --adapter claude --require-pinned \
   --input-arg pr=1487 --input-file paths=changed.txt
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run pr-threads --scripted --input-arg pr= --input-arg paths=
```

**Caveats.**

* It drafts answers; it does not research them. A comment whose answer
  needs a specialist's reading is the reason `pr-threads-assess` exists,
  and running both is how you get both.
* The cheapest ending answers nobody. A pull request with no open human
  comment is one free test over the inventory, one arm, and the specialists
  are never asked — which is the correct bill for a page of answers to
  nothing.
* Bot comments are deliberately not in this ledger. The inventory excludes
  every bot author and names `green-ci` as where they are swept, because a
  third rung here would be `green-ci` with its gate removed.

<!-- wf:end pr-threads -->

### `pr-threads-assess`

<!-- wf:begin pr-threads-assess -->

`branch · 3 to 6 over 3 paths`

`commands/assess.md` as a program: the same ledger, read *first* by the
language specialists that file's "haskell-pro and/or cpp-pro and/or
rust-pro" names, and then folded into an approach for answering rather
than into the answers themselves.

**Inputs.**

* `pr` — the pull request number, and it is the *argv* of `gh pr view` rather
  than a phrase a model interprets. The comment inventory is built from that
  command's own JSON and bound once, so a comment that arrives mid-run belongs
  to the next run and a comment nobody left cannot be answered.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one. At
  this rung it selects the specialist roster in ordinary Haskell before
  the program exists, so `plan` must be given the same `paths=` the run
  will use or it prices a different panel. An empty list is *one general
  seat* and never an empty panel.

**Transport.** Fine anywhere: it reads a ledger, fans out over it and writes
one report. An adapter of the run's own is the usual shape, and `--scratch` is
worth giving only if you mean to keep the report file.

**Nothing is posted back, and that is an absence rather than a rule.** Every
question here is asked at `text` or folded from `text` answers, and only an
act at `ack` carries write authority — of which this program has exactly one,
and it writes the report. There is no `gh pr comment` in the tree's evidence
module for a run to reach for, so no member *can* post.

```sh
wf run pr-threads-assess --engine acp --adapter claude --require-pinned \
   --input-arg pr=1487 --input-file paths=changed.txt
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run pr-threads-assess --scripted --input-arg pr= --input-arg paths=
```

**Caveats.**

* It produces an *approach* and not the replies. That is the file's own
  shape — read the comments and their implications, then say how a
  response would be formulated — so a run that ends with nothing to
  paste has not failed.
* The cheapest ending answers nobody. A pull request with no open human
  comment is one free test over the inventory, one arm, and the specialists
  are never asked — which is the correct bill for a page of answers to
  nothing.
* Bot comments are deliberately not in this ledger. The inventory excludes
  every bot author and names `green-ci` as where they are swept, because a
  third rung here would be `green-ci` with its gate removed.

<!-- wf:end pr-threads-assess -->

### `issue`

<!-- wf:begin issue -->

`branch · 2 to 14 over 4 paths`

`commands/fix.md` as a program: three cheap gates, the fix under the
fix-all discipline, the confirmation-test promotion, the commit
discipline called as a function, the push, the pull request, and the bot
sweep over it. Three of its callees belong to other rows, so what it
costs is largely what the toolbox under it costs.

**Inputs.**

* `issue` — the issue number, and it is the *argv* of `gh issue view`, the
  `--search` term the open-pull-request gate uses, the worktree's computed
  name and the path of the confirmation test. One flag names all four, which
  is what makes the naming scheme checkable instead of described. An empty one
  becomes a name nothing answers to: `wf plan issue --raw` prints
  `gh issue view <no issue given>` and an operator who forgot the flag learns
  it from the plan rather than from a run that fixed something else.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one. It
  selects the persona spliced into the work — the Emacs persona when the list
  touches `.el`, for instance — in ordinary Haskell before the program exists,
  so `plan` must be given the same `paths=` the run will use or it prices a
  different program. An empty list is the general shape and never an empty
  roster.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because this row edits your tree and the scratch
directory is the only place an acting turn may write. Without the flag the
fix repairs a copy in a temporary directory.

```sh
wf run issue --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg issue=412 --input-file paths=changed.txt
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run issue --scripted --input-arg issue= --input-arg paths=
```

**Caveats.**

* It commits, pushes and opens a pull request. If what you want is the
  work left in a tree for you to read, that is `issue-worktree`, and it
  is a different row because it is a different ending.
* The three cheap gates are the reason the floor above is so far below the
  ceiling, and they decide before anything expensive is asked: an open pull
  request already addressing the issue is a `gh` receipt read by a decider for
  nothing; whether the issue is still live is one flag, because that one *is*
  a judgment; and whether a confirmation test is waiting is `test -f` and not
  a model's opinion. The first gate's other arm ends the run, and there is no
  reachable statement after it.
* The confirmation-test promotion happens only for an issue whose test is
  actually there. Both arms call one fixing function with a different guidance
  argument, so the two cannot drift apart.

<!-- wf:end issue -->

### `issue-worktree`

<!-- wf:begin issue-worktree -->

`branch · 6 over 2 paths`

`commands/fix-github-issue.md` as a program: the same fix in a worktree
whose branch name is *computed* from the issue number rather than
described, ending deliberately uncommitted — and a receipt that checks
it really did, because "leave the work for review" is a postcondition
and not a hope.

**Inputs.**

* `issue` — the issue number, and it is the *argv* of `gh issue view`, the
  `--search` term the open-pull-request gate uses, the worktree's computed
  name and the path of the confirmation test. One flag names all four, which
  is what makes the naming scheme checkable instead of described. An empty one
  becomes a name nothing answers to: `wf plan issue-worktree --raw` prints
  `gh issue view <no issue given>` and an operator who forgot the flag learns
  it from the plan rather than from a run that fixed something else.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one. It
  selects the persona spliced into the work — the Emacs persona when the list
  touches `.el`, for instance — in ordinary Haskell before the program exists,
  so `plan` must be given the same `paths=` the run will use or it prices a
  different program. An empty list is the general shape and never an empty
  roster.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because this row edits your tree and the scratch
directory is the only place an acting turn may write. Without the flag the
fix repairs a copy in a temporary directory.

```sh
wf run issue-worktree --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg issue=412 --input-file paths=changed.txt
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run issue-worktree --scripted --input-arg issue= --input-arg paths=
```

**Caveats.**

* It prices exactly, and the reason is that it *ends* rather than loops:
  no commit, no push, no pull request and therefore no bot sweep. The
  run stops with a worktree and a receipt saying the tree is dirty on
  purpose.
* The three cheap gates are the reason the floor above is so far below the
  ceiling, and they decide before anything expensive is asked: an open pull
  request already addressing the issue is a `gh` receipt read by a decider for
  nothing; whether the issue is still live is one flag, because that one *is*
  a judgment; and whether a confirmation test is waiting is `test -f` and not
  a model's opinion. The first gate's other arm ends the run, and there is no
  reachable statement after it.
* The confirmation-test promotion happens only for an issue whose test is
  actually there. Both arms call one fixing function with a different guidance
  argument, so the two cannot drift apart.

<!-- wf:end issue-worktree -->

## The account family

Four ways of writing down where the work stands. All four take the same two
inputs and only one of them reads the second: `scope` is what the account is
about, and `journal` is the path `narrative.md` names — the other three kinds do
not read it, and `wf plan` says so.

### `account-halt`

<!-- wf:begin account-halt -->

`branch · 15 over 2 paths`

`commands/halt.md` as a program: its four numbered steps in order — the
journal written as a function call, the commit discipline called as
another, the push, the remaining-scope panel, and one act that writes
the handoff where the next session will find it.

**Inputs.**

* `scope` — what the account is *about*: a branch, a milestone, a week. It is
  an input and therefore a define, so it rides into every member's closing
  line for zero extra questions. Empty is legal and costs nothing — the
  account is then about the work the receipts found.
* `journal` — the path `account-narrative` reads, and **this kind does
  not read it**. The four rows share one invocation, so the input is
  declared here and consumed nowhere; `wf plan account-halt` says as much. A
  value given here changes nothing about what is asked.

**Transport.** A watched pane, which is what the line below spells. This kind is the
one of the four that *acts on your repository*: it calls the commit
discipline, it pushes, and it writes a handoff outside the tree, and
in a pane all of that happens where you can watch it.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.
Under `--engine acp` instead, give it `--scratch "$PWD"` so the run
edits the tree you meant. The two are not interchangeable flags:
`--scratch` is `acp`'s, and a run that names it beside `--session` is
refused before anything starts.

```sh
wf run account-halt --session "$PANE" --require-pinned \
   --input-arg scope='stopping for the week' --input-arg journal=
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run account-halt --scripted --input-arg scope= --input-arg journal=
```

**Caveats.**

* It is the only one of the four that changes anything. The other three
  write a document; this one commits, pushes and leaves a handoff, so
  run it when you mean to stop rather than when you want to look.
* Every one of the four is built on *receipts* — the working tree, the
  branch's log, the diff — collected before anything is asked, so an account
  is about the repository rather than about what a model remembers of it. A
  run in the wrong directory writes a confident account of the wrong project,
  and no gate in the program can catch that.

<!-- wf:end account-halt -->

### `account-sitrep`

<!-- wf:begin account-sitrep -->

`pipeline · 13 over 1 path`

`commands/sitrep.md` as a program: eight sections over a dossier of four
command receipts, with the filename scheme computed in Haskell instead
of described in prose. It prices exactly, because it has no loop and no
branch — it reads, it folds, it writes.

**Inputs.**

* `scope` — what the account is *about*: a branch, a milestone, a week. It is
  an input and therefore a define, so it rides into every member's closing
  line for zero extra questions. Empty is legal and costs nothing — the
  account is then about the work the receipts found.
* `journal` — the path `account-narrative` reads, and **this kind does
  not read it**. The four rows share one invocation, so the input is
  declared here and consumed nowhere; `wf plan account-sitrep` says as much. A
  value given here changes nothing about what is asked.

**Transport.** Fine anywhere: it reads receipts, fans out over them and writes one
report. An adapter of the run's own is the usual shape, and `--scratch`
is worth giving only if you mean to keep the file.

```sh
wf run account-sitrep --engine acp --adapter claude --require-pinned \
   --input-arg scope='the token-refresh branch' --input-arg journal=
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run account-sitrep --scripted --input-arg scope= --input-arg journal=
```

**Caveats.**

* Eight sections, and the eighth is not an estimate. If what you want is
  "how much is left and how long", that is `account-report`, whose
  estimate is a separate question on a separate engine.
* Every one of the four is built on *receipts* — the working tree, the
  branch's log, the diff — collected before anything is asked, so an account
  is about the repository rather than about what a model remembers of it. A
  run in the wrong directory writes a confident account of the wrong project,
  and no gate in the program can catch that.

<!-- wf:end account-sitrep -->

### `account-report`

<!-- wf:begin account-report -->

`pipeline · 11 over 1 path`

`commands/report.md` as a program: seven categories as seven panel
members over one dossier, and the estimate asked as a *separate*
question on another engine — because the party that planned the work is
the last one to ask how long it will take.

**Inputs.**

* `scope` — what the account is *about*: a branch, a milestone, a week. It is
  an input and therefore a define, so it rides into every member's closing
  line for zero extra questions. Empty is legal and costs nothing — the
  account is then about the work the receipts found.
* `journal` — the path `account-narrative` reads, and **this kind does
  not read it**. The four rows share one invocation, so the input is
  declared here and consumed nowhere; `wf plan account-report` says as much. A
  value given here changes nothing about what is asked.

**Transport.** Fine anywhere: it reads receipts, fans out over them and writes one
report. An adapter of the run's own is the usual shape, and `--scratch`
is worth giving only if you mean to keep the file.

```sh
wf run account-report --engine acp --adapter claude --require-pinned \
   --input-arg scope='what remains before the release' --input-arg journal=
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run account-report --scripted --input-arg scope= --input-arg journal=
```

**Caveats.**

* The estimate is deliberately not the panel's. Seven category members
  write what remains; a different engine prices it, so the party that
  enumerated the work is not the party that says how long it takes.
* Every one of the four is built on *receipts* — the working tree, the
  branch's log, the diff — collected before anything is asked, so an account
  is about the repository rather than about what a model remembers of it. A
  run in the wrong directory writes a confident account of the wrong project,
  and no gate in the program can catch that.

<!-- wf:end account-report -->

### `account-narrative`

<!-- wf:begin account-narrative -->

`branch · 8 over 3 paths`

`commands/narrative.md` as a program, reworked: a receipt dossier, a
chronology over it whose every claim carries the receipt it came from, a
writer over the chronology and nothing else, and a sourcing gate
elsewhere. "Distinguish fact from inference" stops being an instruction
and becomes a party that did not write the prose it is checking.

**Inputs.**

* `scope` — what the account is *about*: a branch, a milestone, a week. It is
  an input and therefore a define, so it rides into every member's closing
  line for zero extra questions. Empty is legal and costs nothing — the
  account is then about the work the receipts found.
* `journal` — the path to the journal file, and it is the *argv* of a
  `cat` rather than the file's contents. This is the one kind of the
  four that reads it, and it is the earliest receipt in the dossier: the
  chronology is built over it. Empty is a narrative written from the
  repository's own history alone.

**Transport.** Fine anywhere: it reads receipts, fans out over them and writes one
report. An adapter of the run's own is the usual shape, and `--scratch`
is worth giving only if you mean to keep the file.

```sh
wf run account-narrative --engine acp --adapter claude --require-pinned \
   --input-arg scope='the last three weeks' --input-arg journal=doc/journal.md
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run account-narrative --scripted --input-arg scope= --input-arg journal=
```

**Caveats.**

* The sourcing gate is on another engine, and it is the point of the
  rework: the chronology's claims are checked by a party that did not
  write them. A run that puts writer and checker in one shared pane
  keeps the shape and loses the guarantee.
* Every one of the four is built on *receipts* — the working tree, the
  branch's log, the diff — collected before anything is asked, so an account
  is about the repository rather than about what a model remembers of it. A
  run in the wrong directory writes a confident account of the wrong project,
  and no gate in the program can catch that.

<!-- wf:end account-narrative -->

## The partner family

A review that runs *beside* the work rather than inside it, publishing one
observation file per finding.

**Where you put it is the whole point.** A partner review is worth having
because it is not the party that wrote the code, and nothing in the program can
secure that — so name a pane that is *not* the work's, or use `--engine acp`,
whose fresh session per question is the stronger of the two. Naming the working
pane is the quiet failure: the run succeeds and reads like a review. Every
ending quotes `run.engine`, so the report says which you did. `partner-cleanup`
is the exception in both directions: it *edits*, so it belongs in the work's own
tree.

### `partner-reviewer`

<!-- wf:begin partner-reviewer -->

`branch · 11 over 2 paths`

`commands/partner-reviewer.md` as a program: the observation contract
over `heavy-review`'s seven passes — which is the review command that
file names — publishing one file per actionable finding, and priced
exactly because it neither loops nor branches.

**Inputs.**

* `commit` — the revision under review, as the *argv* of the git commands and
  not a phrase a model interprets. Empty is `HEAD`.
* `observations` — the directory observation files are published into, or
  drained from. It is an argv too. Empty is `doc/observations`, which is where
  all three look by default, so the reviewing half and the draining half meet
  without either being told twice.
* `paths` — the changed-file list, one path per line. At this role the
  roster is `heavy-review`'s own fixed seven, so the file list selects
  **nothing** and this row's price does not move with it. It is declared
  because the three roles share one invocation.

**Transport.** Somewhere that is **not** the work. A partner review is worth having
because it is not the party that wrote the code, and nothing in the
program can secure that — so name a pane that is not the work's, or use
`--engine acp`, whose fresh session per question is the stronger of the
two. Naming the working pane is the quiet failure: the run succeeds and
reads like a review. Every ending quotes `run.engine`, so the report
says which you did.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run partner-reviewer --session "$PANE_R" --require-pinned \
   --input-arg commit=HEAD --input-arg observations=doc/observations \
   --input-file paths=changed.txt
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run partner-reviewer --scripted --input-arg commit= --input-arg observations= \
   --input-arg paths=
```

**Caveats.**

* It publishes; it does not fix. The files it writes are consumed by
  `partner-cleanup`, and running the reviewer without ever draining the
  directory is how an observations directory becomes an archive.
* One observation file per finding is the contract, and it is one contract for
  all three rows rather than one per command: the category vocabulary is
  derived from the single setting that distinguishes reviewer from
  collaborator, so a category added reaches both by being added.

<!-- wf:end partner-reviewer -->

### `partner-collaborator`

<!-- wf:begin partner-collaborator -->

`branch · 12 over 2 paths`

`commands/partner-collaborator.md` as a program: the same contract over
`deep-review`'s roster — which is the review command *that* file names —
with the ideation pass beside it as three drawn ideas. The one setting
that separates it from `partner-reviewer` also adds the `Idea` category,
so the two vocabularies cannot drift.

**Inputs.**

* `commit` — the revision under review, as the *argv* of the git commands and
  not a phrase a model interprets. Empty is `HEAD`.
* `observations` — the directory observation files are published into, or
  drained from. It is an argv too. Empty is `doc/observations`, which is where
  all three look by default, so the reviewing half and the draining half meet
  without either being told twice.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one. At
  this role it *widens the roster* with the language reviewers the
  commit touches, in ordinary Haskell before the program exists, so
  `plan` must be given the same `paths=` the run will use. An empty list
  is the required lenses and the performance pass — never an empty
  panel.

**Transport.** Somewhere that is **not** the work. A partner review is worth having
because it is not the party that wrote the code, and nothing in the
program can secure that — so name a pane that is not the work's, or use
`--engine acp`, whose fresh session per question is the stronger of the
two. Naming the working pane is the quiet failure: the run succeeds and
reads like a review. Every ending quotes `run.engine`, so the report
says which you did.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run partner-collaborator --engine acp --adapter claude --require-pinned \
   --input-arg commit=HEAD --input-arg observations=doc/observations \
   --input-file paths=changed.txt
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run partner-collaborator --scripted --input-arg commit= --input-arg observations= \
   --input-arg paths=
```

**Caveats.**

* The three drawn ideas are drawn rather than ranked, and they are the
  only difference in kind from `partner-reviewer`. If ideas are not
  wanted, the cheaper row is the other one.
* One observation file per finding is the contract, and it is one contract for
  all three rows rather than one per command: the category vocabulary is
  derived from the single setting that distinguishes reviewer from
  collaborator, so a category added reaches both by being added.

<!-- wf:end partner-collaborator -->

### `partner-cleanup`

<!-- wf:begin partner-cleanup -->

`branch · 2 to 12 over 4 paths`

`commands/partner-cleanup.md` as a program: the other half of the
partnership. Two drain rounds, each behind a *free* test over a `find`
receipt — bytes the answering model did not write — and then one call of
the commit discipline.

**Inputs.**

* `commit` — the revision under review, as the *argv* of the git commands and
  not a phrase a model interprets. Empty is `HEAD`.
* `observations` — the directory observation files are published into, or
  drained from. It is an argv too. Empty is `doc/observations`, which is where
  all three look by default, so the reviewing half and the draining half meet
  without either being told twice.
* `paths` — the changed-file list, one path per line. This role reads no
  reviewer roster at all — it drains a directory and commits — so the
  file list selects **nothing** here. It is declared because the three
  roles share one invocation.

**Transport.** The work's own pane, or an adapter with `--scratch "$PWD"`. This is the
role of the three that *edits*: it drains the observation files into
changes and calls the commit discipline, so it belongs in the tree the
observations are about.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run partner-cleanup --session "$PANE_W" --require-pinned \
   --input-arg commit=HEAD --input-arg observations=doc/observations \
   --input-arg paths=
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run partner-cleanup --scripted --input-arg commit= --input-arg observations= \
   --input-arg paths=
```

**Caveats.**

* The cheapest ending is the honest one and it costs almost nothing: a
  `find` over the observations directory comes back empty, so there is
  nothing to drain, nobody is consulted about the work, and the run says
  so.
* It commits. The decomposition is the commit discipline's, called as a
  function, so what lands is what that row would have landed.
* One observation file per finding is the contract, and it is one contract for
  all three rows rather than one per command: the category vocabulary is
  derived from the single setting that distinguishes reviewer from
  collaborator, so a category added reaches both by being added.

<!-- wf:end partner-cleanup -->

## The Org-mode pair

Two rungs that take *different* inputs, which is what a rung may do: one
decomposes a named headline against its background, the other extracts a flat
list from unstructured text.

### `org-tasks-breakdown`

<!-- wf:begin org-tasks-breakdown -->

`branch · 2 to 4 over 5 paths`

`commands/breakdown.md` and `agents/task-breakdown.md` as one program: the
analysis framework as the first question, the decomposition, the formatting
rules, and that file's three special cases as three free deciders with three
terminals of their own.

**Inputs.**

* `task` — the one Org-mode headline being decomposed, as the operator would
  write it: `* TODO Bring token refresh under test`. It is the subject of
  every question in the run, so an empty one asks a panel to decompose
  nothing; the plan prints what it would have asked.
* `context` — the background the headline is decomposed *against*: the design
  document, the ticket, the surrounding plan. It is an input and therefore a
  define, so it reaches the analysis as data rather than as a file somebody is
  asked to go and read. Empty is legal and is a decomposition from the
  headline alone.

**Transport.** Fine anywhere: it reads two texts, asks a small chain and
writes one document. An adapter of the run's own is the usual shape.

```sh
wf run org-tasks-breakdown --engine acp --adapter claude --require-pinned \
   --input-arg task='* TODO Bring token refresh under test' \
   --input-file context=doc/design.md
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run org-tasks-breakdown --scripted --input-arg task= --input-arg context=
```

**Caveats.**

* `[ATOMIC]`, `[AMBIGUOUS]` and `[NO-EXPERTISE]` are three *endings* and not
  three shapes of one answer. Each is decided for free over the answer already
  given, each has its own terminal and its own provenance line, so a task that
  could not be decomposed is reported as such rather than as a short list.
* The completeness check is asked of somebody else. "If all subtasks are
  completed, will the parent be fully done?" is one confirmation on a party
  whose primary the decomposer did not use — which is only a real check if the
  transport keeps them apart.
* The artefact is Org-mode text in a report, and nothing here writes into your
  agenda files. What lands where is yours to decide, which is deliberate: a
  run that edited `~/org` would be a run whose blast radius is your whole
  task history.

<!-- wf:end org-tasks-breakdown -->

### `org-tasks-infer`

<!-- wf:begin org-tasks-infer -->

`branch · 2 to 4 over 5 paths`

`commands/infer-tasks.md` as a program: a flat list of independently
committable headlines extracted from unstructured text, that file's
`NO-OVERLAP RULE` decided for free over the extraction, and its two judgments
put to a second party rather than to the extractor.

**Inputs.**

* `text` — the unstructured source: meeting notes, a mail thread, a paste of
  somebody's plan. It is the *only* input this rung declares, and
  `--input-file text=notes.md` is the natural spelling, because the source is
  usually a file and its contents are what the extraction reads. Empty is
  legal and is the shape the price above is the price of.

**Transport.** Fine anywhere: it reads one text, extracts, judges and writes.
An adapter of the run's own is the usual shape.

```sh
wf run org-tasks-infer --engine acp --adapter claude --require-pinned \
   --input-file text=notes.md
```

**Rehearsal.** The one input named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run org-tasks-infer --scripted --input-arg text=
```

**Caveats.**

* It extracts and does **not** decompose. A headline that wants subtasks is
  `org-tasks-breakdown`'s job, and running one after the other is how you get
  both — which is also why these are two rows and not one flag.
* The no-overlap rule costs nothing and is checked rather than requested: it
  is decided over the list that came back, so a run cannot both violate it and
  claim to have followed it.
* The artefact is Org-mode text in a report, and nothing here writes into your
  agenda files. What lands where is yours to decide, which is deliberate: a
  run that edited `~/org` would be a run whose blast radius is your whole
  task history.

<!-- wf:end org-tasks-infer -->

## The `CLAUDE.md` pair

Both take `scope` and `agents`, and each ignores one of them. Which one is in
each row's section, because that is a fact about the row.

### `claude-md`

<!-- wf:begin claude-md -->

`branch · 3 to 4 over 2 paths`

`commands/initialize.md` as a program, reworked: one `ls` receipt
decides which of *two named outcomes* the run has — write the briefing
file, or critique the one already there. In the corpus that is a clause
under `Usage notes` that silently changes the output's kind; here they
are two functions with two terminals, and neither can be reached by
accident.

**Inputs.**

* `scope` — what the file should emphasise: the build and test commands,
  the architecture, the house rules. It is an input and therefore a
  define, so it reaches both outcomes as data. Empty is legal and is the
  general briefing.
* `agents` — the specialist roster `claude-md-advise` is given, and
  **this rung does not read it**. The two rows share one invocation, so
  the input is declared here and consumed nowhere; `wf plan claude-md`
  says as much.

**Transport.** Unattended, with somewhere to write: an adapter of the run's own and
`--scratch "$PWD"`, because the write outcome puts a file in your
repository and the scratch directory is the only place an acting turn
may write.

```sh
wf run claude-md --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg scope='the build and test commands' --input-arg agents=
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run claude-md --scripted --input-arg scope= --input-arg agents=
```

**Caveats.**

* Which of the two outcomes you get is not yours to choose from the
  command line: an `ls` receipt decides it. If a `CLAUDE.md` already
  stands, the run critiques it and overwrites nothing — so a rewrite
  means moving the old file yourself first, deliberately.
* The mandatory prefix of the written file is a literal and cannot be
  paraphrased by whoever writes the rest.
* The eight usage notes are one define in this module and not eight rules
  repeated in two prompts, so a note edited once is a note edited for both
  rungs.

<!-- wf:end claude-md -->

### `claude-md-advise`

<!-- wf:begin claude-md-advise -->

`branch · 5 over 3 paths`

`commands/prepare-with.md` as a program: the specialists the operator
names advise on what the briefing file should say, and then a
*different* engine audits the draft against the eight usage notes —
which in the corpus are eight rules nothing checks.

**Inputs.**

* `scope` — what the advice should emphasise, and **this rung reads it
  only as the subject of the advice**: the roster is `agents`' to
  select. Empty is legal, and the specialists then advise on the
  repository as they find it.
* `agents` — `prepare-with.md`'s own `$ARGUMENTS`: the specialists to
  consult, named as the operator would name them (`haskell-pro nix-pro`).
  It selects the roster in ordinary Haskell before the program exists,
  so `plan` must be given the same `agents=` the run will use or it
  prices a different panel. An empty list is one general seat and never
  an empty panel.

**Transport.** Fine anywhere: it consults, drafts and audits, and the artefact is a
document. `--scratch` is worth giving only if you mean to keep the file.
The audit is on a *different* engine by construction, which is worth
something only if the transport does not collapse the two into one pane.

```sh
wf run claude-md-advise --engine acp --adapter claude --require-pinned \
   --input-arg scope= --input-arg agents='haskell-pro nix-pro'
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run claude-md-advise --scripted --input-arg scope= --input-arg agents=
```

**Caveats.**

* It advises; it does not install. The artefact is a draft and a
  critique of it, and putting the result in `CLAUDE.md` is yours — which
  is why `claude-md` is the row that writes and this one is the row that
  consults.
* The audit's value is the second engine. Under one shared pane the
  party that drafted is the party that audited, and the run reads the
  same either way.
* The eight usage notes are one define in this module and not eight rules
  repeated in two prompts, so a note edited once is a note edited for both
  rungs.

<!-- wf:end claude-md-advise -->

## The prose dial

Four settings of one dial, each with a check its own author does not make. The
rungs take different inputs, which is why there is no shared inputs paragraph
here.

### `prose-proofread`

<!-- wf:begin prose-proofread -->

`branch · 4 over 3 paths`

`commands/proofread.md` as a program: clear spelling, grammar and punctuation
errors and nothing else, then that file's five prohibitions checked against
the run's own `git diff` by a party that did not make the corrections.

**Inputs.**

* `scope` — what to proofread: a directory, a file set, a description of the
  corpus (`doc and README.md`). It is the subject the corrections are made
  over, and empty is legal — the plan prints what it would have asked.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because this rung *edits your files* and the
scratch directory is the only place an acting turn may write.

```sh
wf run prose-proofread --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg scope='doc and README.md'
```

**Rehearsal.** The one input named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run prose-proofread --scripted --input-arg scope=
```

**Caveats.**

* The five prohibitions are audited against the *diff*, not against a promise.
  A rewrite that improved the prose is a violation here, and the auditor sees
  the bytes rather than the corrector's account of them.
* The per-file count is a receipt and not a claim: what changed is read off
  the repository afterwards.
* The check is made by somebody who did not write the prose, which is the
  whole of what this family adds to the corpus files it carries. Under one
  shared `--session` that party is the party that wrote it: the run keeps its
  shape, produces the same document, and loses the guarantee.

<!-- wf:end prose-proofread -->

### `prose-smooth`

<!-- wf:begin prose-smooth -->

`branch · 3 to 7 over 15 paths`

`commands/smooth.md` as a program: a light rewrite in an elevated register,
with "do not change it overmuch" turned from an instruction repeated three
times into a *bounded restraint gate* — a reviewer who did not write the draft
says whether any sentence changed more than it had to, and the run amends
toward a lighter touch under a bound.

**Inputs.**

* `text` — the passage itself, and `--input-file text=doc/intro.md` is the
  natural spelling: the rewrite reads the prose as data rather than opening
  by asking a tool to go and fetch it. Empty is legal and is the shape the
  numbers above are the numbers of.

**Transport.** Fine anywhere: it reads one passage, rewrites it, has the
restraint judged and reports. An adapter of the run's own is the usual shape,
and `--scratch` is worth giving only if you mean to keep the file.

```sh
wf run prose-smooth --engine acp --adapter claude --require-pinned \
   --input-file text=doc/intro.md
```

**Rehearsal.** The one input named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run prose-smooth --scripted --input-arg text=
```

**Caveats.**

* The restraint loop is where the spread between this row's floor and its
  ceiling comes from: an accepted first draft is the cheap ending, and each
  amendment toward a lighter touch is another trip. The bound is in the
  program, so the worst case is the number above and not a hope.
* It rewrites the passage you give it and writes no file of yours. What to do
  with the result is yours.
* The check is made by somebody who did not write the prose, which is the
  whole of what this family adds to the corpus files it carries. Under one
  shared `--session` that party is the party that wrote it: the run keeps its
  shape, produces the same document, and loses the guarantee.

<!-- wf:end prose-smooth -->

### `prose-transcript`

<!-- wf:begin prose-transcript -->

`branch · 5 over 3 paths`

`commands/fix-transcript.md` and `skills/fix-transcript/SKILL.md` as one
program: the rule-priority order applied to a speech-to-text transcript over a
`cat` receipt, restructured — paragraphs, punctuation, capitalisation —
without a word of the speaker's changing.

**Inputs.**

* `transcript` — the *path* to the transcript file, passed as the argv of a
  `cat`, so `--input-arg` and not `--input-file`. An absent one becomes a name
  no file has: `wf plan prose-transcript --raw` prints
  `cat <no transcript given>` and a `--scripted` run never reaches a command
  at all, which is how an operator who forgot the flag learns it from the plan
  rather than from a run that cleaned up nothing.
* `vocabulary` — the reference tables: the technical vocabulary and the
  spoken-punctuation conventions this speaker uses. It is an input and
  therefore data, which is what turns "correct the technical terms" from an
  instruction into a table the run was given. Empty is legal and is the
  general shape.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because the cleaned transcript is written where
you asked for it and the scratch directory is the only place an acting turn
may write.

```sh
wf run prose-transcript --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg transcript=talk.txt --input-file vocabulary=terms.md
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run prose-transcript --scripted --input-arg transcript= --input-arg vocabulary=
```

**Caveats.**

* Not a summary and not an edit: the speaker's words are preserved, and the
  only permitted changes are structural. A rung that rewrote would be
  `prose-smooth`, which is a different row for exactly that reason.
* The transcript reaches the prompt as its own chunk and never fuses with the
  literal beside it, so a transcript that happens to contain instructions is
  read as the material it is.
* The check is made by somebody who did not write the prose, which is the
  whole of what this family adds to the corpus files it carries. Under one
  shared `--session` that party is the party that wrote it: the run keeps its
  shape, produces the same document, and loses the guarantee.

<!-- wf:end prose-transcript -->

### `prose-compress`

<!-- wf:begin prose-compress -->

`branch · 2 over 2 paths`

`skills/caveman/SKILL.md` as a program: the family's one reusable transform,
called. Compress a prompt or a passage to fit a smaller budget while
preserving what it means, and have the result checked for what compression
usually loses.

**Inputs.**

* `text` — the passage to compress, and `--input-file text=prompt.md` is the
  natural spelling. Empty is legal and is the shape the numbers above are the
  numbers of.

**Transport.** Fine anywhere: two questions and a report, no file of yours
touched. It is the cheapest row in this family and among the cheapest in the
toolbox, so it is also a reasonable first row to point at a new transport
after `hello`.

```sh
wf run prose-compress --engine acp --adapter claude --require-pinned \
   --input-file text=prompt.md
```

**Rehearsal.** The one input named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run prose-compress --scripted --input-arg text=
```

**Caveats.**

* The transform is a *function* in this module and this row is one call of it.
  Other rows call the same function, so a compression improved here improves
  everywhere it is called, and this row is where its price is published.
* Compression loses nuance by construction. The check that follows it is what
  makes that a measured loss rather than an unnoticed one.
* The check is made by somebody who did not write the prose, which is the
  whole of what this family adds to the corpus files it carries. Under one
  shared `--session` that party is the party that wrote it: the run keeps its
  shape, produces the same document, and loses the guarantee.

<!-- wf:end prose-compress -->

## The specialists

### `dead-code`

<!-- wf:begin dead-code -->

`branch · 2 to 18 over 11 paths`

`skills/eliminate-dead-code/SKILL.md` as a program: four phases that cannot
interleave, two gates decided before anything is asked of anybody, and a
three-advocate debate whose verdict no majority can win — removal needs
independent evidence, not a vote.

**Inputs.**

* `scope` — the skill's own `$ARGUMENTS`: a path, a kind of dead thing, a
  language name, or empty for the whole repository. It is the subject of the
  marking phase and rides into every advocate's brief.
* `paths` — the changed-file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one. It
  selects which static analyzers are run *and* decides whether the
  two-evidence rule binds — the rule arrives in the debate's briefs when the
  list touches Python and does not when it touches Rust, decided in Haskell
  before the program exists. So `plan` must be given the same `paths=` the run
  will use.
* `cap` — the blast-radius cap, and **this row's price-moving input**: at
  `cap=` the row is 11 paths and a ceiling of 18, at `cap=4` it is 17 and 22,
  so price what you will run. (Five other rows have one too — `review-deep`,
  `review-sec` and `partner-collaborator` at `paths`, `translate` and
  `translate-en` at `text` — and each says so on its own page.) It is read
  in Haskell into the ACT gate's bound
  and rides into the acting brief as the commit ceiling, so one number does
  both jobs. Empty is *two* repair trips — deliberately not the skill's own
  default of twenty, because twenty rounds of a priced loop is a plan nobody
  would read. `cap=0` is not unbounded here; an unbounded loop has no price.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because the ACT phase removes code from your tree
and the scratch directory is the only place an acting turn may write. Without
the flag it deletes from a copy.

```sh
wf run dead-code --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg scope=src/Workflows --input-file paths=changed.txt --input-arg cap=4
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run dead-code --scripted --input-arg scope= --input-arg paths= --input-arg cap=
```

**Caveats.**

* **`plan` and `cost` must be given the same `cap=` the run will use**, or
  they price a different program. `wf cost dead-code --input-arg cap=4` is how
  to see the cost of your own cap before spending it, and the difference
  between that and `wf cost dead-code` is the whole argument for the input
  being read in Haskell rather than in a prompt. The rehearsal above is the
  empty-`cap` shape, which is also the shape the gate pins — rehearsing at
  `cap=4` is the cheapest way to watch the paths multiply.
* The two gates come first and cost nothing. A dirty working tree is
  `git status --porcelain` read by a decider; a red test suite is the
  repository's own gate read as an exit code. Both have an arm, and the arm
  reports and stops — which is where the cheapest ending comes from, and it
  changes your tree not at all.
* MARK, DEBATE, ACT and VERIFY are binds in one block, each reading the handle
  the last one bound. There is no order in which they could run but this one,
  which is what "four phases that cannot interleave" means when it is a type
  rather than a heading.
* The sidecar candidate manifest is asked for and never read back. It exists
  for you — it is what `git diff --stat` shows at the end of the marking phase
  — and this program's honesty about it is that it does not pretend to have
  parsed it.

<!-- wf:end dead-code -->

`dead-code` is the one row in the table whose **price depends on an input**, and
the two invocations side by side are the whole argument for reading `cap` in
Haskell rather than in a prompt:

```sh
$ wf cost dead-code
  costSummary   minFold 2, maxFold 18, over 11 paths

$ wf cost dead-code --input-arg cap=4
  costSummary   minFold 2, maxFold 22, over 17 paths
```

### `comments`

<!-- wf:begin comments -->

`branch · 5 to 13 over 17 paths`

`skills/comment-audit/SKILL.md` as a program: the audit's own extractor run as
three command receipts, the manifest it writes read back *off disk* rather
than remembered, and a false-positive guard put to another engine — because
the party that called a comment stale is the last one to ask whether it was.

**Inputs.**

* `extractor` — the installed *path* of the audit's `inventory_comments.py`.
  It is passed as **argv**, so this is `--input-arg` and never
  `--input-file`: the run needs the script's name, not its text. An empty one
  becomes a name no file has, which is what `wf plan comments --raw` prints
  and why a `--scripted` run never reaches a command at all. What a tilde becomes depends on
  your shell — write `"$HOME/…"` and it arrives the same either way.
* `base` — the diff base, as the *argv* of the git commands. Empty means the
  whole project rather than a change set, which is a much larger audit and the
  right default for a first pass over an unfamiliar tree.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because the extractor writes its manifest into the
run's directory and the audit reads it back from there.

```sh
wf run comments --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg extractor="$HOME/.claude/skills/comment-audit/scripts/inventory_comments.py" \
   --input-arg base=origin/main
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run comments --scripted --input-arg extractor= --input-arg base=
```

**Caveats.**

* The manifest is read back off disk and not carried in a model's head. That
  is what makes "every comment was accounted for" checkable: the reconciliation
  is against bytes the answering party did not write.
* The false-positive guard is on another engine by construction. Under one
  shared pane the guard and the auditor are the same party, and a comment
  wrongly called stale stays wrongly called stale.
* A comment audit over a whole project is a large read. `base=` is the flag
  that makes it a change audit instead, and it is worth setting before the
  first run rather than after.

<!-- wf:end comments -->

### `bundles`

<!-- wf:begin bundles -->

`branch · 3 to 12 over 3 paths`

`commands/discover-bundles.md` as a program: six hard rejections decided
*before* any paid scoring, then seven weighted seats over one dossier, then a
ranking and an integration sketch in the one arm that earns it. In the corpus
"reject a candidate immediately" is enforced by reading order; here the
screening question is asked first and its arm ends the run.

**Inputs.**

* `focus` — what you are shopping for: `review and audit bundles`, a gap you
  want filled, a capability you keep hand-rolling. It is the subject the seven
  seats score against.
* `candidates` — the candidate material itself, which is what `--input-file`
  is for. **It is data written by a stranger**, and the program treats it so:
  a sentence in it that tells the run how to score it is a finding for the
  safety seat and not an instruction for any other. This is also where the
  corpus file's three search waves went — they are not in the program, and
  this input is what they would have produced.
* `profile` — the taste profile the candidates are judged against: what this
  repository already does well, what it refuses, what it is short of. An
  input rather than a scan, deliberately, because a row that went and read
  your tree to infer your taste would be a row whose answer you could not
  check.

**Transport.** Fine anywhere: it screens, scores, ranks and writes one report,
and it installs nothing. An adapter of the run's own is the usual shape.

```sh
wf run bundles --engine acp --adapter claude --require-pinned \
   --input-arg focus='review and audit bundles' \
   --input-file candidates=doc/candidates.md --input-file profile=doc/taste.md
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run bundles --scripted --input-arg focus= --input-arg candidates= --input-arg profile=
```

**Caveats.**

* It **finds, verifies and ranks; it does not install**. Nothing in the
  program can write into your configuration, and the integration sketch is a
  sketch — which is the corpus file's own ruling and is a property of the
  printed program here.
* The cheap ending is a rejection, and it is where this row's saving is: a
  candidate that fails one of the six is refused before a single scoring seat
  is asked. A dossier of good candidates costs the full seven seats, which is
  the ceiling above.
* The candidate material is untrusted throughout. If it arrived from a search
  somebody else ran, that is exactly the case this row is shaped for.

<!-- wf:end bundles -->

## The productize pair

Twenty-one deliverables as a roster priced at twenty-one, then `nix flake check`
as the gate — and the pre-commit slice of the same, as a call rather than a
prose reference. Both take `paths` and `scope`, and the slice is a function call
inside the whole, so the two cannot drift apart.

### `productize`

<!-- wf:begin productize -->

`branch · 27 to 31 over 6 paths`

`commands/productize.md` as a program: twenty-one deliverables — README,
licence, dev shell, formatting, linting, coverage, CI, pre-commit hooks
and the rest — as a roster priced at twenty-one, and then
`nix flake check` as the gate the whole thing is held to.

**Inputs.**

* `paths` — the file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one. It
  decides the preferences table and the per-language tool seats in ordinary
  Haskell before the program exists, so `plan` must be given the same `paths=`
  the run will use. An empty list collapses the per-language seats to *one
  general seat* rather than to none.
* `scope` — what the operator says the repository is **for**, in his own
  words. It rides into the specification, because a README and a fuzz harness
  both need to know what the thing is. Empty is legal and is a
  productionisation of a repository described only by its files.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because this row *writes files into your
repository* — that is the whole of what it is for — and the scratch directory
is the only place an acting turn may write.

```sh
wf run productize --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file paths=changed.txt --input-arg scope='a Haskell library and its CLI'
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run productize --scripted --input-arg paths= --input-arg scope=
```

**Caveats.**

* If what you want is only the pre-commit wiring, `productize-lefthook`
  is the cheaper row and it is the same code: the slice is a function
  call here, so the two cannot drift apart.
* **The floor above is high, and it is a floor rather than an estimate.** The
  deliverables are a *fixed roster*, so the cheapest run is one that wrote all
  of them and passed the gate first time; there is no arm in which fewer are
  written. Read the floor before starting, not the spread.
* The gate at the end is `nix flake check`, which is an exit code and not an
  opinion. A repository that cannot be checked that way gets a run that
  reports it rather than one that claims success.

<!-- wf:end productize -->

### `productize-lefthook`

<!-- wf:begin productize-lefthook -->

`branch · 11 to 15 over 6 paths`

`commands/lefthook.md` as a program: the pre-commit slice of
`productize`, as a **call** rather than as a prose reference to another
command. Formatting, a warning-free build, tests, linting and coverage,
wired into `lefthook.yml` and held to the same gate.

**Inputs.**

* `paths` — the file list, one path per line, and
  `git diff --name-only > changed.txt` is the usual way to make one. It
  decides the preferences table and the per-language tool seats in ordinary
  Haskell before the program exists, so `plan` must be given the same `paths=`
  the run will use. An empty list collapses the per-language seats to *one
  general seat* rather than to none.
* `scope` — what the operator says the repository is **for**, in his own
  words. It rides into the specification, because a README and a fuzz harness
  both need to know what the thing is. Empty is legal and is a
  productionisation of a repository described only by its files.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because this row *writes files into your
repository* — that is the whole of what it is for — and the scratch directory
is the only place an acting turn may write.

```sh
wf run productize-lefthook --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file paths=changed.txt --input-arg scope='a Haskell library and its CLI'
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run productize-lefthook --scripted --input-arg paths= --input-arg scope=
```

**Caveats.**

* It is a slice and says so. There is no README, no licence and no CI
  workflow in this rung — `productize` is the row that writes those, and
  this one is a call inside it.
* **The floor above is high, and it is a floor rather than an estimate.** The
  deliverables are a *fixed roster*, so the cheapest run is one that wrote all
  of them and passed the gate first time; there is no arm in which fewer are
  written. Read the floor before starting, not the spread.
* The gate at the end is `nix flake check`, which is an exit code and not an
  opinion. A repository that cannot be checked that way gets a run that
  reports it rather than one that claims success.

<!-- wf:end productize-lefthook -->

## The nix family

Three rows, one invocation shape — which is what makes them one family. Each
runs the host's own build driver as the receipt, then diagnoses, repairs and
verifies, and all three price identically: choosing between them is choosing
which failure you are describing, and the price is not part of that choice.

**Inputs, shared.** `subject` is what is wrong. `output` is the failing output,
whose default carries the error the source file hard-codes. `host` is the
machine, and it decides the build flags; empty is the unconstrained default.

### `nix-rebuild`

<!-- wf:begin nix-rebuild -->

`branch · 2 to 9 over 8 paths`

`skills/nixos/SKILL.md` and `commands/nix-rebuild.md` as a program: the
host's own build driver run as the receipt, then diagnose, repair and
verify with the same command. Here **the failure is the subject**, so an
approving baseline means there is nothing to diagnose and the run says
so.

**Inputs.**

* `subject` — what is wrong, in your own words. It is the subject of the
  diagnosis and rides into every question, and empty is legal — the run is
  then about whatever the build driver's own output says.
* `output` — the failing output. `--input-file output=build.log` is the
  natural spelling, because a build log is a file and its contents are what
  the diagnosis reads. An empty one falls back to the error the source file
  hard-codes, which is a default worth knowing about: it means a run given no
  log is still diagnosing *something*.
* `host` — the machine, which decides the build flags. Empty is the
  unconstrained default. This is tier-1 — it changes an argv and a define,
  never a question — so the numbers above hold either way.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because the repair edits the host's declarations
in your configuration tree and the scratch directory is the only place an
acting turn may write.

```sh
wf run nix-rebuild --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg subject='vulcan will not switch after the Grafana bump' \
   --input-file output=build.log --input-arg host=vulcan
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run nix-rebuild --scripted --input-arg subject= --input-arg output= --input-arg host=
```

**Caveats.**

* The cheapest ending diagnoses nothing, and it is the correct one: the
  build driver approves, so the failure this run was about is not
  reproducible from here, and the report says that instead of
  manufacturing a cause.
* The receipt is the host's own build driver, run as a command, and the
  verification at the end is that same command again. So "it is fixed" is an
  exit code rather than a claim, and a repair that did not take is reported as
  not having taken.
* All three rungs price the same. Choosing between them is choosing which
  failure you are describing, and the price is not part of that choice — which
  is also why there is no bare `nix` row: a family with no cheap rung has no
  default.

<!-- wf:end nix-rebuild -->

### `nix-alert`

<!-- wf:begin nix-alert -->

`branch · 2 to 9 over 8 paths`

`commands/fix-alert.md` as a program: the alert routed by its own labels
for *free* — the routing is ordinary Haskell over the label set, before
the program exists — and then diagnosed whole rather than compressed
into a summary somebody else has to expand again.

**Inputs.**

* `subject` — what is wrong, in your own words. It is the subject of the
  diagnosis and rides into every question, and empty is legal — the run is
  then about whatever the build driver's own output says.
* `output` — the failing output. `--input-file output=build.log` is the
  natural spelling, because a build log is a file and its contents are what
  the diagnosis reads. An empty one falls back to the error the source file
  hard-codes, which is a default worth knowing about: it means a run given no
  log is still diagnosing *something*.
* `host` — the machine, which decides the build flags. Empty is the
  unconstrained default. This is tier-1 — it changes an argv and a define,
  never a question — so the numbers above hold either way.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because the repair edits the host's declarations
in your configuration tree and the scratch directory is the only place an
acting turn may write.

```sh
wf run nix-alert --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg subject='PostgresBackupStale has been firing since Tuesday' \
   --input-file output=build.log --input-arg host=vulcan
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run nix-alert --scripted --input-arg subject= --input-arg output= --input-arg host=
```

**Caveats.**

* The routing costs nothing and happens before anything is asked, so an
  alert whose labels name the wrong subsystem is routed wrongly for
  free — which is cheaper to notice than to argue with, and
  `wf plan nix-alert` prints where it went.
* The receipt is the host's own build driver, run as a command, and the
  verification at the end is that same command again. So "it is fixed" is an
  exit code rather than a claim, and a repair that did not take is reported as
  not having taken.
* All three rungs price the same. Choosing between them is choosing which
  failure you are describing, and the price is not part of that choice — which
  is also why there is no bare `nix` row: a family with no cheap rung has no
  default.

<!-- wf:end nix-alert -->

### `nix-integration`

<!-- wf:begin nix-integration -->

`branch · 2 to 9 over 8 paths`

`commands/fix-integration.md` as a program: the failing integration
output as the input, diagnosed against the host's declarations, repaired
and re-verified. The one of the three whose subject arrives as *bytes*
rather than as a symptom described in a sentence.

**Inputs.**

* `subject` — what is wrong, in your own words. It is the subject of the
  diagnosis and rides into every question, and empty is legal — the run is
  then about whatever the build driver's own output says.
* `output` — the failing output. `--input-file output=build.log` is the
  natural spelling, because a build log is a file and its contents are what
  the diagnosis reads. An empty one falls back to the error the source file
  hard-codes, which is a default worth knowing about: it means a run given no
  log is still diagnosing *something*.
* `host` — the machine, which decides the build flags. Empty is the
  unconstrained default. This is tier-1 — it changes an argv and a define,
  never a question — so the numbers above hold either way.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because the repair edits the host's declarations
in your configuration tree and the scratch directory is the only place an
acting turn may write.

```sh
wf run nix-integration --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg subject='the Home Assistant bridge drops its websocket at start-up' \
   --input-file output=build.log --input-arg host=vulcan
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run nix-integration --scripted --input-arg subject= --input-arg output= --input-arg host=
```

**Caveats.**

* An empty `output=` is not an empty diagnosis: the source file's
  hard-coded error stands in, and the run diagnoses *that*. Give the
  flag, or read the plan to see what you would otherwise be asking
  about.
* The receipt is the host's own build driver, run as a command, and the
  verification at the end is that same command again. So "it is fixed" is an
  exit code rather than a claim, and a repair that did not take is reported as
  not having taken.
* All three rungs price the same. Choosing between them is choosing which
  failure you are describing, and the price is not part of that choice — which
  is also why there is no bare `nix` row: a family with no cheap rung has no
  default.

<!-- wf:end nix-integration -->

## The service pair

**Inputs, shared.** `service` is the service's name, and it names both the
consent file and the unit — an empty one names `.consent/service-unnamed`, which
is exactly what a plan should print for an operator who forgot the flag.
`domain` is the virtual host and names the health URL. `host` is the machine.

Both want a watched pane, for two different reasons, and each section says which.

### `service-install`

<!-- wf:begin service-install -->

`branch · 2 to 23 over 4 paths`

`commands/install-service.md` as a program: nine obligations as nine
calls behind a consent file **the run cannot create**, and then two
health receipts. The consent gate is a person's decision expressed as a
file on disk, so a run that reaches it without one ends at your desk.

**Inputs.**

* `service` — the service's name, and it names **both** the consent file and
  the systemd unit, so one flag is two arguments. An empty one names
  `.consent/service-unnamed`, which is exactly what a plan should print for an
  operator who forgot the flag — and what a run against it will fail to find.
* `domain` — the virtual host, which names the health URL the run checks
  afterwards. Empty is legal and leaves the health check pointed at nothing
  useful, which the plan prints.
* `host` — the machine the declarations belong to.

**Transport.** A watched pane. Its consent gate is a *person's*, and an unwatched run
reaches nobody: `--scripted` answers a flag and an adapter of the run's
own has no one to ask. Give it the pane you are sitting in front of.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run service-install --session "$PANE" --require-pinned \
   --input-arg service=grafana --input-arg domain=grafana.example.com \
   --input-arg host=vulcan
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run service-install --scripted --input-arg service= --input-arg domain= --input-arg host=
```

**Caveats.**

* The cheapest ending finds no consent file, changes nothing on the
  machine, and stops. That is not a failure — it is the gate working,
  and the fix is to put the file there deliberately rather than to
  re-run with a flag.
* The two health receipts are commands, so "it came up" is an exit code.
  A unit that installed and did not start is reported as such.
* Both rows edit a host's declarations, which is to say they edit *your
  configuration repository* and not the running machine directly. What
  switches the machine is still yours to run, which is the boundary this pair
  keeps on purpose.

<!-- wf:end service-install -->

### `service-remove`

<!-- wf:begin service-remove -->

`branch · 15 to 19 over 6 paths`

`commands/remove-service.md` as a program: twelve read-only discovery
questions — what the unit is, what it owns, what points at it — and then
exactly one act, which **writes a removal script rather than running
one**. The asymmetry with installing is deliberate: taking a service
away is where a wrong answer costs the most.

**Inputs.**

* `service` — the service's name, and it names **both** the consent file and
  the systemd unit, so one flag is two arguments. An empty one names
  `.consent/service-unnamed`, which is exactly what a plan should print for an
  operator who forgot the flag — and what a run against it will fail to find.
* `domain` — the virtual host, which names the health URL the run checks
  afterwards. Empty is legal and leaves the health check pointed at nothing
  useful, which the plan prints.
* `host` — the machine the declarations belong to.

**Transport.** A watched pane, for a different reason: there is no person gate here.
It edits the host's declarations and writes a script you will want to
read before running it, so the pane is where you can see both as they
happen.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run service-remove --session "$PANE" --require-pinned \
   --input-arg service=grafana --input-arg domain=grafana.example.com \
   --input-arg host=vulcan
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run service-remove --scripted --input-arg service= --input-arg domain= --input-arg host=
```

**Caveats.**

* **It writes a removal script; it does not remove.** The one act in the
  program produces a file for you to read and run, which is why the
  twelve discovery questions are worth paying for: their whole output is
  a script whose every line you can check against what they found.
* Twelve read-only questions are its floor, and there is no arm in which
  fewer are asked. Discovery is not conditional here, because a removal
  script built from partial discovery is the failure this row exists to
  avoid.
* Both rows edit a host's declarations, which is to say they edit *your
  configuration repository* and not the running machine directly. What
  switches the machine is still yours to run, which is the boundary this pair
  keeps on purpose.

<!-- wf:end service-remove -->

## The read-only and human-gated five

What these have in common is that the property is a **type** rather than an
instruction: `query` contains no `act` at all, `transcribe` and `tron` contain
exactly one and it writes the artefact, and `expense` and `qanda` put the owner
in binding position — so their expensive arms are unreachable without his
answer. `wf plan <row> --raw` is where each of those can be checked.

### `query`

<!-- wf:begin query -->

`branch · 3 to 8 over 16 paths`

`commands/query-builder.md` as a program: a SQL query written against a schema
receipt by parties that **cannot reach the data**, and audited on another
engine before it is handed back. A draft whose first statement is a write verb
is refused by a free decider before the audit is asked anything at all.

**Inputs.**

* `question` — what the query must answer, in your own words
  (`which accounts had no activity last quarter`). It is the subject of the
  drafting and of the audit.
* `schema` — the *path* to the exported schema, as the argv of the command
  that reads it. The schema is the only thing the drafting parties see of your
  database, which is the point: they write against structure and never against
  rows.
* `dialect` — which SQL. Empty is the corpus's own default, which the plan
  prints, so a run that meant T-SQL and did not say so is visible before it
  starts.

**Transport.** Fine anywhere: it reads a schema, drafts, audits and reports,
and it runs nothing. An adapter of the run's own is the usual shape.

```sh
wf run query --engine acp --adapter claude --require-pinned \
   --input-arg question='which accounts had no activity last quarter' \
   --input-arg schema=schema.sql --input-arg dialect=tsql
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run query --scripted --input-arg question= --input-arg schema= --input-arg dialect=
```

**Caveats.**

* **Nothing here can run the query it wrote, and that is a type rather than a
  promise.** The program contains no acting turn except the one that writes
  the report; `wf plan query --raw` is where an operator can see that for
  himself, and it is a better guarantee than any sentence in a prompt.
* The cheapest ending is a refusal: a draft beginning with a write verb is
  caught by a decider for zero questions, and the audit is never asked. That
  is the ending the corpus file cannot have, because nothing there reads the
  answer.
* No data is ever read, so a query that is *valid* and *wrong for your rows*
  is a possible outcome. The audit checks the query against the schema and the
  question; it cannot check it against facts it is forbidden to see.

<!-- wf:end query -->

### `expense`

<!-- wf:begin expense -->

`branch · 4 to 10 over 17 paths`

`commands/expense-report.md` as a program: the receipt directory as a `find`
receipt, one extracted table over it, and **the owner's answer as the loop's
verdict**. Of its endings, exactly two build anything, and neither is
reachable without an approval or a yes — which is a property of the printed
program rather than a rule in a prompt.

**Inputs.**

* `receipts` — the directory the receipt files are in, as the argv of the
  `find`. What a tilde becomes depends on your shell: write `"$HOME/Documents/receipts/…"`.
* `trip` — the trip's name. In the corpus this is a quoted string a model has
  to spot inside `$ARGUMENTS`; here it is its own flag, so a trip whose name
  contains a comma is not a parsing problem.
* `script` — the filler's absolute path: the program that actually fills the
  expense form. It is argv, and it is the one input whose value decides what
  the building arms can do.

**Transport.** A watched pane. The verdict here is a person's, and an
unattended run reaches nobody: `--scripted` answers a flag *yes* and an
adapter of the run's own has no one to put the question to. Give it the pane
you are sitting in front of.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run expense --session "$PANE" --require-pinned \
   --input-arg receipts="$HOME/Documents/receipts/2026-06-boston" \
   --input-arg trip='Boston, June 2026' \
   --input-arg script="$HOME/bin/fill-expense-report"
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run expense --scripted --input-arg receipts= --input-arg trip= --input-arg script=
```

**Caveats.**

* A rehearsal is not a check of the gate. `--scripted` answers the owner's
  question from the row's own table, so it exercises the *loop* and tells you
  nothing about what a person would have said. That is correct — a canned yes
  is not consent — and it is why the transport paragraph above is a
  requirement and not advice.
* The receipt directory is read by a command, so an empty or wrong directory
  is visible in the run rather than inferred from a thin table.
* It fills a form; it does not submit anything on your behalf beyond running
  the filler you named. The path in `script=` is the whole of what it can
  reach.

<!-- wf:end expense -->

### `qanda`

<!-- wf:begin qanda -->

`branch · 4 to 8 over 15 paths`

`commands/qanda.md` as a program: an agenda of decisions, the *full*
background produced before the first question is put, and then the owner's
answer as the loop's verdict. The corpus file is three lines with no named
input; this row is those three lines with an agenda, a bound, and an ending
for a person who walks away.

**Inputs.**

* `decisions` — the agenda, one decision per line, and `--input-file
  decisions=doc/agenda.md` is the natural spelling. An empty one is **one
  placeholder decision** and never the empty list, because an empty agenda
  would ask the owner to walk through nothing.
* `context` — the background the decisions are made against: the design, the
  constraints, what has already been settled. It is an input and therefore
  data, so the run does not open by asking a tool to go and read it.

**Transport.** A watched pane. The judge here is a person, and an unattended
run reaches nobody: `--scripted` answers a flag and an adapter of the run's
own has no one to ask. Give it the pane you are sitting in front of.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run qanda --session "$PANE" --require-pinned \
   --input-file decisions=doc/agenda.md --input-file context=doc/design.md
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run qanda --scripted --input-arg decisions= --input-arg context=
```

**Caveats.**

* The background is produced **before** the first question, which is the whole
  of what this row adds: a walkthrough that researches as it goes asks the
  owner to wait, and asks the third question with more context than the first.
* There is an ending for a person who walks away, and it is not a failure. The
  loop is bounded, so an unanswered agenda ends with what was settled and what
  was not.
* A rehearsal exercises the loop and not the judgment. A canned yes is not a
  decision, which is why the pane is a requirement here rather than advice.

<!-- wf:end qanda -->

### `transcribe`

<!-- wf:begin transcribe -->

`branch · 4 to 8 over 15 paths`

`commands/transcribe-image.md` as a program: an `ls` receipt over the pages,
one transcription into paragraph-form Markdown, and a **second engine**
re-reading the same images against that transcription under a bound — because
the party that read a word one way is the last one to ask whether it read it
right.

**Inputs.**

* `images` — the image paths, one per line, and `--input-file images=pages.txt`
  is the natural spelling. An empty one is **one placeholder path** rather
  than the empty list, so the argv never degenerates into a bare `ls` that
  lists the working directory and exits happily.
* `subject` — what the notes are about. It is the one input that turns an
  unreadable word into a readable one: a page of a denotational-design
  notebook and a page of a shopping list are read differently by anybody, and
  this is where the run is told which it has.

**Transport.** Fine anywhere: it reads images, transcribes, re-reads and
writes one artefact. An adapter of the run's own is the usual shape, and
`--scratch "$PWD"` is worth giving if you mean to keep the Markdown.

```sh
wf run transcribe --engine acp --adapter claude --require-pinned \
   --input-file images=pages.txt \
   --input-arg subject='the denotational design notebook'
```

**Rehearsal.** Both inputs named empty, every question answered from the row's
own canned table, consulting nobody:

```sh
wf run transcribe --scripted --input-arg images= --input-arg subject=
```

**Caveats.**

* The re-reading is on a second engine by construction, and under one shared
  pane it is not. The run keeps its shape and produces the same document; what
  it loses is the only reason to pay for the second pass.
* It is bounded. A page that two readings cannot agree on ends as a page two
  readings could not agree on, marked, rather than as an argument that runs
  until the budget does.
* The transcription is of what is *written*, and `subject=` is the whole of
  what the run knows about why. A wrong subject produces confident and wrong
  expansions of the same handwriting.

<!-- wf:end transcribe -->

### `tron`

<!-- wf:begin tron -->

`branch · 2 to 14 over 9 paths`

`commands/tron-debug.md` as a program: the control, the ingest, the compile
and the run as four command receipts, and a diagnosis reachable **only**
through all four. Several of its endings are "a command did not do what this
run needed", and each of those is better localised than the diagnosis it
replaces.

**Inputs.**

* `problem` — the symptom, in your own words, spliced into all four lenses.
  One description, four readings of it.
* `model` — the model under test, and it names **both** sides of the
  differential: the control's name is *computed* from this value, so one flag
  is two arguments and there is deliberately no second flag for the control.
  Empty is the corpus's own default, which the plan prints.
* `trace` — the Torch export directory. Empty is the corpus's own default,
  again printed by the plan. What a tilde becomes depends on your shell: write `"$HOME/…"`.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`, because the run compiles and executes in a
directory and the scratch directory is the only place an acting turn may
write.

```sh
wf run tron --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-arg problem='the plugin emits zeros for the attention block' \
   --input-arg model=llama_3p1_8b_torch --input-arg trace="$HOME/exports/llama-3p1-8b"
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run tron --scripted --input-arg problem= --input-arg model= --input-arg trace=
```

**Caveats.**

* A diagnosis is only reachable through the arms in which the commands
  actually ran, and that is the shape of this row rather than a caution about
  it. The cheap endings are the control's ingest failing — the run refuses to
  diagnose at all — and each of them names *which* command did not do what was
  needed.
* It is one machine's pipeline. The IR stages, the build targets and the
  export layout are the Torch Fx ingest path's, and a run pointed at anything
  else will report four failing receipts, correctly.
* A wrong `model=` is a wrong *control*, silently: the differential is then
  between two things you did not mean to compare. `wf plan tron --raw` prints
  both names, which is the cheapest way to check before spending.

<!-- wf:end tron -->

## The long ones

Each of these carries a whole *procedure* rather than a rubric: a phase battery,
a ten-phase design method, a five-phase translation team, a two-mode
requirements agent, and a host-specific automation surface. Every one of them is
a file whose own text says "follow it exactly", and the level-up in all five is
the same: a procedure that is a program can be priced, and its steps cannot be
reordered by a tired reader.

### `retest`

<!-- wf:begin retest -->

`branch · 2 to 16 over 5 paths`

`skills/retest/SKILL.md` as a program: the full model-support battery —
rebuild, unit tests, correctness against the HuggingFace forward pass as
the source of truth, code review, comment audit and a performance pass —
as one exhaustive sweep with five endings, priced before it starts.

**Inputs.**

* `spec` — the skill's own procedure, as an `--input-file`. It is
  *authoritative data* and not prompt bulk: the battery's steps, its ordering
  and its success words come from those bytes, so a procedure edited in the
  skill reaches this row by being passed to it.
* `base` — the diff base, as the argv of the git commands. It is what the
  branch's model set is derived from and what the audit reads.
* `models` — the model set, one per line. An empty one is **one model**
  — the spec's own — and never the empty list, so the numbers above are
  a real sweep. A wider set is a wider bill, and
  `wf cost retest --input-arg models=…` answers that before anything is
  built.
* `paths` — the changed-file list, one path per line. It selects the audit's
  language roster in ordinary Haskell before the program exists, so `plan`
  must be given the same `paths=` the run will use. An empty list is one
  general seat and never an empty panel.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`. It builds, runs a gate and writes reports, and the
scratch directory is the only place an acting turn may write.

```sh
wf run retest --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file spec="$HOME/.claude/skills/retest/references/spec.md" \
   --input-arg base=origin/main --input-arg models=llama_3p1_8b \
   --input-file paths=changed.txt
```

**Rehearsal.** All four inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run retest --scripted --input-arg spec= --input-arg base= \
   --input-arg models= --input-arg paths=
```

**Caveats.**

* The oracle is the HuggingFace forward pass, and correctness means
  agreement with it. A model whose reference implementation this tree
  cannot run is a model this rung cannot grade, and it says so rather
  than grading it anyway.
* **There is no early exit anywhere in the sweep.** That is the battery's
  defining property and the reason its ceiling is what it is: a red case does
  not stop the run, because a battery that stopped at the first failure would
  report one defect where there were four.
* The cheapest ending is a refusal to start — the tree is the *other* rung's,
  decided by a build target that does not exist here — and the report names
  the sibling rung rather than making you go and find it.

<!-- wf:end retest -->

### `retest-categorical`

<!-- wf:begin retest-categorical -->

`branch · 2 to 37 over 5 paths`

`commands/retest-categorical.md` as a program: the *same* battery
against the legacy ingest path, over the **fixed eight-model roster**
that file's ship gate insists on. One body, one override table, and a
different oracle — which is why the two are two rows whose prices can be
read against each other.

**Inputs.**

* `spec` — the skill's own procedure, as an `--input-file`. It is
  *authoritative data* and not prompt bulk: the battery's steps, its ordering
  and its success words come from those bytes, so a procedure edited in the
  skill reaches this row by being passed to it.
* `base` — the diff base, as the argv of the git commands. It is what the
  branch's model set is derived from and what the audit reads.
* `models` — **ignored at this rung, by that file's own ruling.** The
  ship gate is always all supported models, so the roster is the fixed
  eight whatever this flag says; a value here would be a claim the run
  does not honour. Name it empty. It is declared because the two rungs
  share one invocation, and `wf plan retest-categorical` prints the
  roster it will actually sweep.
* `paths` — the changed-file list, one path per line. It selects the audit's
  language roster in ordinary Haskell before the program exists, so `plan`
  must be given the same `paths=` the run will use. An empty list is one
  general seat and never an empty panel.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own and `--scratch "$PWD"`. It builds, runs a gate and writes reports, and the
scratch directory is the only place an acting turn may write.

```sh
wf run retest-categorical --engine acp --adapter claude --require-pinned --scratch "$PWD" \
   --input-file spec="$HOME/.claude/skills/retest/references/spec.md" \
   --input-arg base=origin/main --input-arg models= \
   --input-file paths=changed.txt
```

**Rehearsal.** All four inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run retest-categorical --scripted --input-arg spec= --input-arg base= \
   --input-arg models= --input-arg paths=
```

**Caveats.**

* **This is the row that prices an eight-model FPGA sweep before a card
  is opened**, and the whole gap between it and `retest` is that fixed
  roster: eight gate processes and two performance trials per model
  instead of one and one. What such a sweep costs is eight models' worth
  of processes, and the header says so honestly.
* **There is no early exit anywhere in the sweep.** That is the battery's
  defining property and the reason its ceiling is what it is: a red case does
  not stop the run, because a battery that stopped at the first failure would
  report one defect where there were four.
* The cheapest ending is a refusal to start — the tree is the *other* rung's,
  decided by a build target that does not exist here — and the report names
  the sibling rung rather than making you go and find it.

<!-- wf:end retest-categorical -->

### `denote`

<!-- wf:begin denote -->

`branch · 2 to 18 over 17 paths`

`skills/denotational-design/SKILL.md` as a program: the meaning first, its
exit tests judged by somebody who did not propose it, and the representation
tower reachable **only** through those tests. The phases are a chain and not
ten independent loops, which is what keeps a ten-phase design method finite.

**Inputs.**

* `subject` — the API sketch, the library, or the codebase being retrofitted:
  what is to be given a meaning. It is the subject of every phase.
* `method` — the skill's reference files and worksheet skeleton as an
  `--input-file`: *data* the phases are held to, not bulk prepended to a
  prompt. This is what makes "follow the method exactly" checkable.
* `prover` — Lean 4, Rocq or Agda. It is read **once**, in ordinary Haskell,
  so the choice cannot be re-litigated mid-dialog by a party that would rather
  use something else. Empty is the corpus's own default, printed by the plan.
* `realization` — the foreign language the last phase would bisimulate the
  design against. An empty one is a design in which **that phase does not
  exist** — a different program, not a skipped step.

**Transport.** Fine anywhere: it is a long dialog that produces documents and
proof obligations, and it writes no file of yours unless you give it
`--scratch "$PWD"` and mean to keep the worksheet. An adapter of the run's own
is the usual shape.

```sh
wf run denote --engine acp --adapter claude --require-pinned \
   --input-arg subject='the workflow cost algebra' \
   --input-file method="$HOME/.claude/skills/denotational-design/SKILL.md" \
   --input-arg prover=lean --input-arg realization=rust
```

**Rehearsal.** All four inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run denote --scripted --input-arg subject= --input-arg method= \
   --input-arg prover= --input-arg realization=
```

**Caveats.**

* **The cheapest ending is the admission test answering *no*.** A subject this
  method should not be applied to costs two questions and stops there, which
  is the correct answer and the one the skill's own "when not to use it"
  section is written to produce. Read it as the method working.
* A retrofit whose own defect inventory says to start over is a **successful**
  retrofit here, and it is nearly as cheap. Neither of those endings is a
  failed run.
* The phases are a chain: each reads the handle the last one bound, so there
  is no order in which they could run but this one, and a representation
  cannot be reached without the exit tests that admit it.

<!-- wf:end denote -->

## The translate family

Three rows and two shapes: `translate` and `translate-en` are one body with the
languages swapped and take three inputs; `translate-es` takes `text` alone,
because `prompts/spanish.md` names no glossary and no reference corpus and the
row does not pretend to. The three prices say which is which without a word of
prose.

### `translate`

<!-- wf:begin translate -->

`branch · 9 to 23 over 15 paths`

`skills/persian/SKILL.md` as a program: English into Persian, with six
reviewers folded in the priority order that file resolves conflicts by,
under a bound the file itself states only in words.

**Inputs.**

* `text` — the source passage, and `--input-file text=source.txt` is the
  natural spelling. An empty `text` is **not a short source** — it is an
  unknown one — so the empty invocation is the full six-seat team rather than
  one seat, which is what makes the numbers above the numbers of a real
  program.
* `glossary` — the terminology table, and it is **authoritative**: where the
  reviewers disagree with it, it wins. `TERMS.csv` is the usual file, and
  `--input-file glossary=TERMS.csv` the usual spelling.
* `references` — the reference letters and translations. This is what "the
  target style and standards" means concretely: a register is learned from a
  corpus, so the corpus is an input rather than an adjective.

**Transport.** Fine anywhere: it reads three texts, runs a review team over a
draft and delivers. An adapter of the run's own is the usual shape, and the
six seats are worth more when they are six sessions rather than one pane's six
turns.

```sh
wf run translate --engine acp --adapter claude --require-pinned \
   --input-file text=essay.md --input-file glossary=TERMS.csv \
   --input-file references=refs.md
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run translate --scripted --input-arg text= --input-arg glossary= --input-arg references=
```

**Caveats.**

* The six reviewers are folded **in the priority order the source file
  resolves conflicts by**, so a disagreement between two seats has a settled
  answer rather than a majority. That order is in the program, not in a
  reader's memory of the file.
* The revision loop is bounded, and the bound is where the spread above comes
  from: a draft the team settles on at the first round is the floor, and a
  second full round is most of the rest. The source file states that bound
  without a number ("run that phase again, then come back"); here it is one.
* `glossary` beats the reviewers, so a wrong entry in it is a wrong term
  everywhere, confidently. It is the input worth checking before the run
  rather than after.

<!-- wf:end translate -->

### `translate-en`

<!-- wf:begin translate-en -->

`branch · 9 to 23 over 15 paths`

`translate-en` as a program: Persian or Arabic into English in Shoghi
Effendi's register — the same six seats as `translate`, with the
directions swapped. One body, two rows, and the two prices are
identical, which is the claim the pair makes about itself.

**Inputs.**

* `text` — the source passage, and `--input-file text=source.txt` is the
  natural spelling. An empty `text` is **not a short source** — it is an
  unknown one — so the empty invocation is the full six-seat team rather than
  one seat, which is what makes the numbers above the numbers of a real
  program.
* `glossary` — the terminology table, and it is **authoritative**: where the
  reviewers disagree with it, it wins. `TERMS.csv` is the usual file, and
  `--input-file glossary=TERMS.csv` the usual spelling.
* `references` — the reference letters and translations. This is what "the
  target style and standards" means concretely: a register is learned from a
  corpus, so the corpus is an input rather than an adjective.

**Transport.** Fine anywhere: it reads three texts, runs a review team over a
draft and delivers. An adapter of the run's own is the usual shape, and the
six seats are worth more when they are six sessions rather than one pane's six
turns.

```sh
wf run translate-en --engine acp --adapter claude --require-pinned \
   --input-file text=source.txt --input-file glossary=TERMS.csv \
   --input-file references=refs.md
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run translate-en --scripted --input-arg text= --input-arg glossary= --input-arg references=
```

**Caveats.**

* The six reviewers are folded **in the priority order the source file
  resolves conflicts by**, so a disagreement between two seats has a settled
  answer rather than a majority. That order is in the program, not in a
  reader's memory of the file.
* The revision loop is bounded, and the bound is where the spread above comes
  from: a draft the team settles on at the first round is the floor, and a
  second full round is most of the rest. The source file states that bound
  without a number ("run that phase again, then come back"); here it is one.
* `glossary` beats the reviewers, so a wrong entry in it is a wrong term
  everywhere, confidently. It is the input worth checking before the run
  rather than after.

<!-- wf:end translate-en -->

### `translate-es`

<!-- wf:begin translate-es -->

`pipeline · 2 over 1 path`

`prompts/spanish.md` as a program: English into elevated Latin-American
Spanish, as **one call** of the same translating function its siblings use,
whose answer is the artefact. There is no review team here because that file
names none, and the row's price says so rather than borrowing an apparatus it
was not given.

**Inputs.**

* `text` — the source passage. It is the **only** input this row declares, so
  `--input essay.md` names it without a `NAME=` — which is also why a path
  containing `=` is never misread here.

**Transport.** Fine anywhere: one question and a delivery. It is among the
smallest rows in the toolbox, which makes it a reasonable second row to point
at a new transport after `hello`.

```sh
wf run translate-es --engine acp --adapter claude --require-pinned --input essay.md
```

**Rehearsal.** The one input named empty, answered from the row's own canned
table, consulting nobody:

```sh
wf run translate-es --scripted --input-arg text=
```

**Caveats.**

* **No glossary, no reference corpus, no reviewer.** That is the source file's
  shape and this row's honesty about it. A translation that must be held to a
  terminology table wants `translate` or `translate-en`, whose prices say what
  that costs.
* The register is elevated by instruction rather than by a reviewer checking
  it, so what comes back is one party's reading of "elevated".

<!-- wf:end translate-es -->

## The PRD pair

Two shapes split at the mode boundary, and they take different inputs. The fused
file had one number for both, which is no number.

### `prd-draft`

<!-- wf:begin prd-draft -->

`branch · 2 to 19 over 18 paths`

`agents/prd-architect.md` as a program, the generator half: the owner's
answers to seven discovery questions **in binding position**, eight sections
written as a roster over them, and the format checklist applied by somebody
who did not write the document.

**Inputs.**

* `goals` — the design goals the document is *for*, and `--input-file
  goals=doc/GOALS.md` is the natural spelling. They are data the discovery
  questions are asked against, so an empty one is a discovery from nothing.
* `template` — the format authority, as a file **in your own project**. This
  is what makes "follow the house format" a table the run was given rather
  than a convention it half-remembers.
* `prd` — where the document goes, as a path. Empty is the source file's own
  default, which the plan prints, so a run that would have written somewhere
  unexpected says so before it starts.

**Transport.** A watched pane. It asks the owner seven discovery questions in
binding position — the document is written *from* his answers — and an
unattended run reaches nobody: `--scripted` answers them from a table and an
adapter of the run's own has no one to ask.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.

```sh
wf run prd-draft --session "$PANE" --require-pinned \
   --input-file goals=doc/GOALS.md \
   --input-file template=.taskmaster/templates/example_prd.txt \
   --input-arg prd=.taskmaster/docs/prd.txt
```

**Rehearsal.** All three inputs named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run prd-draft --scripted --input-arg goals= --input-arg template= --input-arg prd=
```

**Caveats.**

* **The cheapest ending is a refusal to overwrite.** A `test -f` says a
  document already stands at that path, and the run reports it and names
  `prd-critique` instead of writing over work somebody did. Moving the old
  file is a deliberate act and is yours.
* There are two other cheap endings — a discovery the owner did not confirm,
  and open questions he could not settle — and both are honest stopping points
  rather than failures.
* A rehearsal exercises the loop and not the discovery. Canned answers are not
  the owner's, which is why the pane above is a requirement rather than
  advice.

<!-- wf:end prd-draft -->

### `prd-critique`

<!-- wf:begin prd-critique -->

`branch · 2 to 11 over 3 paths`

`agents/prd-architect.md` §4 as a program, the critic half: seven analysis
axes over a requirements document that **nothing in this row can write to**.
It reads, it judges, and the artefact is the critique.

**Inputs.**

* `prd` — the path to the document under critique. It is the *only* input this
  row declares, and it is argv rather than contents: the run probes for the
  file, so a path that names nothing is an ending rather than an empty
  reading. Empty is the source file's own default path, printed by the plan.

**Transport.** Fine anywhere: it reads one document, runs seven axes over it
and writes a critique. An adapter of the run's own is the usual shape.

```sh
wf run prd-critique --engine acp --adapter claude --require-pinned \
   --input-arg prd=.taskmaster/docs/prd.txt
```

**Rehearsal.** The one input named empty, every question answered from the
row's own canned table, consulting nobody:

```sh
wf run prd-critique --scripted --input-arg prd=
```

**Caveats.**

* **Nothing here can revise the document**, which is correct for a row whose
  whole job is to read: there is no revision loop, because there is nothing in
  the row that could write. Acting on the critique is `prd-draft`'s or yours.
* The cheapest ending is the probe finding no document at the path — seven
  analysis axes over a file that does not exist were not run, and the run says
  which path it looked at.

<!-- wf:end prd-critique -->

## `nodered`

<!-- wf:begin nodered -->

`branch · 15 to 17 over 4 paths`

`skills/node-red/SKILL.md` as a program, and **the one row in the table whose
world is one machine's**: the three-signature admin boundary as argv, six
house-style seats over one fetched tab, one staged edit, and a put that
happens only through a validator. Two of its endings put nothing, and each is
more useful than a failed put — an envelope that does not validate names its
own defect.

**Inputs.**

* `request` — what the session is for: `the Office lights fire twice at dusk`.
  It is the subject every seat reads.
* `flow` — the tab's flow id. It is **validated in Haskell** against the
  skill's own identifier shape before the program exists, so a malformed one
  becomes a name nothing has: the plan prints
  `node-red-admin flow get <no valid flow id given>` and a rehearsal never
  reaches a command.
* `node` — the node whose history is being explained, validated the same way
  and with the same consequence.
* `scripts` — where the skill's Python lives, as argv. What a tilde becomes depends on your shell:
  write `"$HOME/…"` and it arrives the same either way.
* `references` — the skill's reference files as an `--input-file`: the house
  conventions, the plugin set, the naming style, as data the six seats are
  held to.

**Transport.** Fine anywhere in the sense that matters — it fetches, reads,
stages, validates and puts through the admin API rather than by editing files
of yours. An adapter of the run's own is the usual shape. What it does reach
is a **live automation host**, so read the caveats before pointing it at one.

```sh
wf run nodered --engine acp --adapter claude --require-pinned \
   --input-arg request='the Office lights fire twice at dusk' \
   --input-arg flow=a1b2c3d4e5f60789 --input-arg node=4f8a1c2d.9be03a \
   --input-arg scripts="$HOME/.claude/skills/node-red/scripts" \
   --input-file references=doc/nodered-references.md
```

**Rehearsal.** All five inputs named empty, every question answered from the
row's own canned table, consulting nobody — and, because two of them are
validated, reaching no command at all:

```sh
wf run nodered --scripted --input-arg request= --input-arg flow= --input-arg node= \
   --input-arg scripts= --input-arg references=
```

**Caveats.**

* **It changes a running automation host.** The put is guarded by a validator
  and by a refetch that confirms what landed, but what lands is live: a flow
  that fires the lights fires them.
* One of the four endings is "the node had never fired in the last day", and
  this host's own debugging rule reads that as an upstream problem — so the
  report says the change may not be the fix rather than claiming a repair.
* The narrow spread above is what a program looks like when almost nothing in
  it is a judgment: four receipts, six seats, one edit, one validator, one put
  and one refetch. The only spread is the put and its confirming refetch,
  which only the arm that validated ever reaches.
* The ids, the paths and the entity families are one machine's. This row is
  not portable and does not pretend to be.

<!-- wf:end nodered -->

## `taskmaster`

<!-- wf:begin taskmaster -->

`branch · 3 to 22 over 46 paths`

A production evidence-to-design workflow. The source driver creates clean pinned
Taskmaster and agent-cat snapshots and supplies a canonical evidence manifest.
Inventory, design, audit, and revision exchange JSON text checked by
`wf-taskmaster-stage`, installed by the Nix package and put on `PATH` by the
source driver. Each stage has one repair at most.
A deterministic renderer owns the Markdown report structure and citations.

**Inputs.**

* `evidence` — the canonical manifest produced by
  `tools/taskmaster-evidence.py`. Use the source driver for ordinary runs.

**Transport.** Use ACP with `--require-pinned`; the model roles use the toolbox's
broad, lateral, and reasoning ladders. A source-tree run should use the driver.
For a direct run, put `tools/` on `PATH`, supply its canonical manifest, and
choose a configured ACP adapter:

```sh
wf run taskmaster --engine acp --adapter claude --require-pinned \
  --scratch "$PWD/taskmaster-run" \
  --input-file evidence=/absolute/path/to/taskmaster-evidence-manifest.json
```

**Rehearsal.** The no-network shape rehearsal names the evidence input empty;
the row's small scripted table settles each revision without executing tools:

```sh
wf run taskmaster --scripted --input-arg evidence=
```

**Caveats.**

* A missing or mismatched source revision fails in the driver before an agent
  starts. A stage receives one repair; a second invalid answer writes a
  stage-specific `INCOMPLETE` marker and no complete report.
* Transport, validator, renderer, and output failures are fatal. `--scripted`
  proves the Program's wiring but does not execute those external gates.

* This row analyzes and recommends; it does not implement FrameworkSpec, copy
  Taskmaster code, add providers or MCP, or change agent-cat semantics.
* `tools/taskmaster-framework.sh` owns source pinning and retained artifacts;
  set its adapter variable for an optional live smoke.

<!-- wf:end taskmaster -->

## `wiggum` and `wiggum-duet`

The autonomous continuation loop: two work rounds, one checkpoint audit, and a
bounded verdict against frozen done-criteria. These are the two most expensive
rows in the toolbox, and the two whose *transport is a gate* rather than a
preference. The inputs are the same four either side, with `plan` renamed `goal`
at the duet — the word an owner types beside two pane ids.

**[doc/wiggum-two-sessions.md](wiggum-two-sessions.md) is the full walkthrough**
for the duet: standing the panes up, what flows between them, and what happens
when you have no panes.

A rehearsal of either takes the *loop*, not the refusal: `--scripted` reaches no
session and says so, and the gate is chosen from `run.engine` in Haskell. The
refusing arm is reachable from a command line and from nowhere else.

### `wiggum`

<!-- wf:begin wiggum -->

`branch · 2 to 44 over 34 paths`

`skills/wiggum/SKILL.md` as a program: two work rounds with a checkpoint audit
between them, and a bounded verdict against done-criteria the run froze before
it started. Four of its seven callees are other rows' own — the commit
discipline, the partner cleanup round, the audit's report and the shared
conflict resolution — so what it costs is largely what the toolbox under it
costs.

**Inputs.**

* `plan` — the frozen plan and its done-criteria. It is an input and therefore
  a define, so it reaches every prompt as data and no turn can rewrite it;
  `--input-file plan=doc/PLAN.md` is the natural spelling. An empty one is the
  sentence a run with no frozen criteria earns, and `wf plan wiggum --raw`
  prints it, so an operator who forgot the flag learns it from the plan rather
  than from the report.
* `base` — what the branch is measured against and brought up to date with. It
  is the argv of the git commands and not a phrase a model interprets. Empty
  is `main`.
* `observations` — the partner directory the cleanup round drains. Empty is
  `doc/observations`.
* `parity` — the reference target the last done-criterion is about. An absent
  one is a *different* last conjunct rather than a missing one.

**Transport.** Unattended, with somewhere to write: an adapter of the run's
own, and `--scratch "$PWD"`, because every round edits your tree and the
scratch directory is the only place an acting turn may write.

**It refuses every `--session` run, flat.** Its judge and its workers are one
serving model and no route table can separate them, so one shared pane means
the party that would have judged the work is the party that did it. Two panes
is `wiggum-duet`, which is a different row because it is a different shape.

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

* The floor above is worth as much as the ceiling. The two cheapest endings in
  that range change your tree not at all: a sentinel probe that says this
  runner cannot be held to a parent history, and a baseline that was already
  red. Both report and stop.
* The `--session` refusal is not in that range at all. It is taken in ordinary
  Haskell over `run.engine` before the program exists, and only `run` binds a
  run fact — so `plan`, `cost` and `--scripted` all price the **loop**, which
  is the shape a run with an unknown table keeps every check for. The refusing
  arm is a different and much smaller program, reachable from a command line
  and from nowhere else.
* Two rounds is a design decision and not a setting: a third would move the
  path count above, and the gate pins it.
* The verdict is bounded and three-way. *Done*, *still remains*, and *cannot
  judge* are three endings and not two, and the third is the one an operator
  should read hardest — it means the criteria as frozen could not be decided.

<!-- wf:end wiggum -->

### `wiggum-duet`

<!-- wf:begin wiggum-duet -->

`branch · 2 to 50 over 34 paths`

`wiggum`'s loop across two panes: the work in one, and in the other a
four-seat review and the judge that holds the run to its frozen done-criteria.
The one-round arm prices exactly as `wiggum`'s does — a review whose findings
nothing could consume is spend with no consumer — so what the duet buys shows
up only on the arm that has a second round to spend it on.

**Inputs.**

* `goal` — the frozen plan and its done-criteria, and the one place this row's
  vocabulary departs from `wiggum`'s on purpose: a duet is started from a
  sentence about what to achieve, typed beside two pane ids. It reaches the
  same two places `plan` reaches — the audit's request fold and the judge's
  frozen criteria — and the judge is held to it verbatim.
* `base` — what the branch is measured against and brought up to date with,
  as an argv. Empty is `main`.
* `observations` — the directory the partner publishes into and the checkpoint
  drains. Empty is `doc/observations`.
* `parity` — the reference target the last done-criterion is about. An absent
  one is a *different* last conjunct rather than a missing one.

**Transport.** Two live panes, and the flags are not interchangeable.
`--session` names the **work** pane and becomes the default, so everything
this row does not pin itself — every borrowed callee and every tool among them
— lands there; `--route partner=deck:<pane>` moves the judgment and only the
judgment. Written the other way round the run refuses before anything is
spent.
The pane id is an `agent-deck` session id; `agent-deck list` prints them.
`doc/wiggum-two-sessions.md` is the full walkthrough: standing the panes up,
what flows between them, and what to do when you have none.

```sh
wf run wiggum-duet --session "$PANE_W" --route "partner=deck:$PANE_R" \
   --poll 250 --require-pinned \
   --input-arg goal='Bring the token-refresh path under test.' \
   --input-arg base=main --input-arg observations= --input-arg parity=
```

**Rehearsal.** Every input named empty. A rehearsal takes the *loop* and never
the refusal: `--scripted` reaches no session, and the gate is chosen from the
run facts in Haskell before the program exists.

```sh
wf run wiggum-duet --scripted --input-arg goal= --input-arg base= \
   --input-arg observations= --input-arg parity=
```

**Caveats.**

* The refusal is sharper than `wiggum`'s and narrower. It fires when the
  judge's backend is the backend of *any* work-side pin — the worker's, or one
  of the four rungs the borrowed callees arrive on — or when it is the
  default. The second is the inverted split an operator types by accident; the
  third is a rung routed alongside the judge, which is the one an operator
  types deliberately, believing it harmless.
* Only the *unrouted* `--session <pane>` reaches this row's own refusal
  wording. A refusing invocation that carries a `--route` is stopped one step
  earlier by the CLI, because the program the run facts selected pins nothing
  and so refuses every routed name. Refused either way, before anything is
  spent; the words differ.
* `--poll` is worth setting on a live pane. The run is long and every question
  is a round trip through somebody's terminal.
* Two rounds is a design decision and not a setting, exactly as in `wiggum`,
  and the gate pins the path count that says so.

<!-- wf:end wiggum-duet -->

## `hello`

<!-- wf:begin hello -->

`pipeline · 4 over 1 path`

The smoke row: one scrap of code asked for, two cross-cutting lenses over it,
folded and reported. It exists to prove the *wiring* — the registry, the
shared CLI, the roster, the panel fold, the report — rather than to do any of
the owner's work, and it is the row to run first against a transport you have
not used before.

**Inputs.** none.

**Transport.** Anywhere, and that is the point: this is the row whose only job
is to answer the question "does this transport work at all". Run it against a
fresh adapter, a new pane, or a stub before pointing anything expensive at
them. It writes no file of yours, so `--scratch` changes nothing about what it
means.

```sh
wf run hello --engine acp --adapter claude
```

**Rehearsal.** No input to name, every question answered from the row's own
canned table, consulting nobody — and a complete test of the binary, the
registry and the CLI in one line. Rows that price lower than this one exist;
none of them is *for* this:

```sh
wf run hello --scripted
```

**Caveats.**

* A green `hello` says the transport works. It says nothing about a row that
  edits, refuses on a run fact, or puts a question to a person — those are
  facts about the rows that do them.
* It prices exactly and has no branch, so its number never moves for a reason
  that is about your repository. If it moves, the language did.
* `--require-pinned` is deliberately absent from the line above: this row is
  what you reach for when the pinning story is what you are trying to
  establish.

<!-- wf:end hello -->

## `hello-world`

<!-- wf:begin hello-world -->

`pipeline · 2 over 1 path`

A small worked example for learning agent-cat's authoring surface. The first
model returns `Hello, world!`; the second receives that answer through a
prompt hole and translates it. `answer` makes that translation the program's
typed text result, which `wf run` renders after the streamed trace.

**Inputs.**

* `language` — the target language named in the translation prompt, such as
  `Spanish`, `Persian`, or `Japanese`.

**Transport.** Use ACP for an ordinary terminal run. Both questions name the
symbolic `deep-thinker` profile, so `--require-pinned` can check the workflow
before anything is spent while routing.yaml chooses its concrete router,
provider, model, effort, output bound, and fallback chain. With no matching
profile, backward compatibility sends the pin to the command's default backend.

```sh
wf run hello-world --engine acp --adapter claude --require-pinned --input-arg language=Spanish
```

**Rehearsal.** The input is named empty to match the repository gate. The
canned table still returns its Spanish fixture, consults nobody, and exercises
the same two-step data flow.

```sh
wf run hello-world --scripted --input-arg language=
```

**Caveats.**

* `--scripted` proves wiring, not translation quality; its answers are fixed.
* This example has no glossary, review panel, retry, or file output. Use the
  `translate` family when those production concerns matter.
* A live run writes no file. Its questions appear in the trace and its final
  translation appears in the result block; a deck session is optional.

<!-- wf:end hello-world -->

## Which transport for which row

| kind | rows | why |
| --- | --- | --- |
| **Refuses a one-session engine** | `wiggum`; `wiggum-duet` when the judge shares a backend with any work pin, or takes the default | verification comes from a separate evaluator, and one shared pane means the judge has read the work. Both refuse before spending anything |
| **Wants a watched pane** | `commit`, `commit-push`, `commit-recommit`, `commit-bankruptcy`; `partner-reviewer`, `partner-collaborator` (a pane that is *not* the work's); `partner-cleanup` (the work's own, because it edits); `account-halt`, `expense`, `qanda`, `prd-draft`, `service-install`, `service-remove`, `effort-forge` | a person's question is not a real gate when unattended — `--scripted` answers a flag *yes* and an unwatched run reaches nobody. The commit family is watched for a different reason: it is decomposing your tree |
| **Wants `--scratch "$PWD"` under acp** | every row that edits: `green-*`, `stack-*`, `issue`, `issue-worktree`, `dead-code`, `comments`, `productize*`, `nix-*`, `checklist`, `claude-md`, `prose-proofread`, `prose-transcript`, `tron`, `retest*`, `effort-medium`, `effort-heavy`, `partner-cleanup`, `wiggum` — and any other row whose written report you mean to keep | the scratch directory is the only place an act may write, and without the flag it is a fresh temporary one |
| **Fine anywhere** | the review ladder, `fess`, the confer family, `pr-threads*`, the other three account rows, the Org pair, `claude-md-advise`, `prose-smooth`, `prose-compress`, `bundles`, `query`, `transcribe`, `denote`, the translate family, `prd-critique`, `nodered`, `teams`, `notes`, `hello`, `hello-world` | they consult without editing your tree, and some write one report. The transport still changes what a report *means* — see `fess` and `confer` — but no ending is unreachable |

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

## Regenerating this page

```sh
./tools/cookbook-gen.sh    # rewrite the marked regions from wf help
./ci/cookbook.sh           # refuse any difference
```

Edit a row's prose in the module that owns its program — `wiggum`'s is
`Workflows.Wiggum.wiggumHelp` — and this page follows by regeneration. An edit
made inside a marked region is caught by the gate on the next run.
