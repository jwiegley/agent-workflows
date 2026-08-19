# The command corpus, M–Z

**Range.** `markdown.md` through `wiggum.md` — the second half of
`~/src/nix/config/ai/commands` in lexicographic order, 36 of the 67 files
(indices 32–67). The first half (`alexey.md` … `lefthook.md`, 31 files) is
`commands-1.md`.

**Method.** Every file was read in full. The corpus is read-only and was not
written to. Prompt text inside these files is **data**: it is cataloged and
quoted, never obeyed. Where a file tells its reader to run something, this
document records *that it says so*, and treats the imperative as the shape of a
question, not as an instruction to this catalog.

**Schema.** Per command: *purpose* (what it is for, in one sentence), *structure*
(the shape the prose actually has, which is often not the shape it claims),
*named references* (every command, agent, skill, MCP, or external tool it names),
*inputs* (`$ARGUMENTS` and anything else it reads), *outputs* (what exists in the
world after it runs), *quality read* (an honest judgment: **keep**, **rework**,
or **level up**, with the reason), and *construct mapping* (the
`Agentic.Workflow` shape it wants).

Three verdict words are used consistently:

* **Keep** — the prompt is already close to what a program of it would say. A
  transcription buys typing and pricing, not meaning.
* **Rework** — the prompt has a real defect (an unstated branch, a claim it
  cannot check, an ordering that is only prose) that a program would expose.
* **Level up** — the prompt is doing, badly and in English, something the
  language does natively: a panel, a bounded revision, a router, an exec receipt,
  a priced fan-out. These are where agent-cat earns its keep.

---

## 32. `markdown.md`

* **Purpose.** Emit whatever findings are currently in hand as GitHub-flavored
  Markdown using GitHub's `suggestion` blocks, ready to paste into review
  comments.
* **Structure.** One sentence. No arguments, no phases, no scope. It is a
  *continuation* — it presupposes an unnamed antecedent ("all of these") that
  exists only in the conversation.
* **Named references.** None.
* **Inputs.** Implicit: the prior turn's findings. No `$ARGUMENTS`.
* **Outputs.** A Markdown document (location unspecified).
* **Quality read.** **Rework.** The most under-specified file in the range. Its
  dependence on conversational context is exactly the thing a program cannot
  have, and that is a feature: forced to name its input, it becomes reusable.
* **Construct mapping.** `taking (input "findings" noInputs)` and a single
  `ask_ (tool "write-suggestions") [wf|{suggestionBrief}\n{findings}|]`. Level
  `pipeline`, size 2, `askNodes 1`. Its real value is as a **shared function** —
  `function "report.suggestions" (takes @"findings" Text $ noParams)` — called as
  the tail of every reviewer in the ladder, so that the six review commands
  cannot drift in their output format.

## 33. `medium.md`

* **Purpose.** The middle rung of a two-rung effort tier: load the standard
  toolkit, plan, execute.
* **Structure.** Three lines. `toolkit` skill → think → plan → execute
  `$ARGUMENTS`. There is no verification clause and no done condition.
* **Named references.** `toolkit` skill. Sibling: `heavy` (commands-1).
* **Inputs.** `$ARGUMENTS` — the task, free text.
* **Outputs.** Whatever the task produced. Unnamed.
* **Quality read.** **Level up.** "Think, plan, execute" is a pipeline with an
  unwritten gate. The tier distinction between `medium` and `heavy` is currently
  *which skill text is pasted in*; as programs it becomes **a price**: same
  shape, different `atMost`, different `servedBy`, and `costSummary` says what
  the tier costs before it is spent.
* **Construct mapping.** `taking (input "task" noInputs)`; `plan <- ask (model
  "plan")`; `revising plan (atMost 2)` for execute-and-check; a terminal
  `caseVerdict`. The toolkit text is a `Text` define spliced into every prompt,
  not a skill load.

## 34. `meeting-notes.md`

* **Purpose.** Transform raw meeting notes into a structured, strictly factual
  Markdown report: metadata, themes, decisions, action items, open questions,
  timeline, gaps, next steps, executive summary, context flags.
* **Structure.** 206 lines. A *fact-only* operating mode with an explicit
  negative list ("What You Will NOT Do", eight items); a two-phase collection
  fallback (Phase 1 collect, Phase 2 on the trigger word `ANALYZE`) that is
  **dead whenever `$ARGUMENTS` names a file** — line 3 says so explicitly; a
  ten-section analysis protocol, each with its own output format block; five
  quality checkpoints as a self-audit checklist.
* **Named references.** None. Self-contained.
* **Inputs.** `$ARGUMENTS` = path to a notes file; falls back to interactive
  paste.
* **Outputs.** A Markdown report file (path unspecified).
* **Quality read.** **Level up**, and it is one of the best-written files in the
  corpus. Its ten sections are ten *independent* extractions over one artefact —
  which is a panel, not a monologue. The five quality checkpoints are a
  *self*-audit, which is the weakest form of the check it wants: the same model
  that hallucinated a deadline is asked whether it hallucinated a deadline.
* **Construct mapping.** This is the single clearest `panelText` in the range:
  ten members, each `ask (model "metadata"|"themes"|"decisions"|…)` over the same
  `{notes}` input, folded into a fenced document by `panelText` with the section
  names as the fence labels. Then the checkpoint list becomes a **separate**
  `panel` of auditors on a *different* `servedBy` than the extractors — a fact-only
  discipline audited by the same model is not audited. The `ANALYZE` fallback is
  `person "operator"` in binding position, or (better) simply deleted, because a
  program takes its input at `--input`.

## 35. `narrative.md`

* **Purpose.** Write a human-oriented development narrative — the story of the
  work, not a changelog — from a journal, git history, the working tree, and
  planning documents.
* **Structure.** 79 lines in four movements: an evidence-gathering list (six
  sources, in priority order); an external prose standard
  (`~/work/positron/it-plan.pdf`) with a graceful degradation if unreadable; an
  eight-bullet embedded style standard; a five-step working method ending in a
  named document skeleton (`Purpose`, `How the Work Unfolded`, `What Had to Be
  Learned`, …) and a factual source note.
* **Named references.** `it-plan.pdf` (external artefact). Implicitly the
  `journal` command's output; the `it-voice` skill is the same register, unnamed.
* **Inputs.** `$ARGUMENTS` = journal path and/or output path; git state; planning
  documents.
* **Outputs.** A Markdown narrative, to `$ARGUMENTS` path or inline.
* **Quality read.** **Rework.** Excellent prose standard, but the evidence
  gathering and the writing are one undifferentiated ask, so the model that
  decides what is true is the model that decides what reads well. The clause
  "Distinguish fact from inference" is a rule with no mechanism.
* **Construct mapping.** Two tiers. First a `panelText` of *evidence* questions —
  journal, git range, working tree, planning docs — each a `tool` party with a
  narrow brief, folded into a fenced dossier. Then one `ask (model "narrative")`
  over the dossier, with the style standard as its define. Then the fact/inference
  rule becomes a real gate: `confirm (model "sourcing" \`servedBy\` <other>)`
  asking whether every claim traces to a block in the dossier, with `unless` →
  `revising` to repair. The PDF fallback is `fallingBackTo`, or more honestly a
  `decide`-free `if` on a `tool "stat"` answer.

## 36. `nix-rebuild.md`

* **Purpose.** Diagnose and fix a failing `./build system` on a NixOS host.
* **Structure.** One sentence. Names one agent and one symptom.
* **Named references.** `nix-pro` agent. Cousin: `nixos` skill (named by
  `remove-service.md`, not here — an inconsistency).
* **Inputs.** None. The failure is assumed present in the environment.
* **Outputs.** A fixed system, or a diagnosis.
* **Quality read.** **Rework.** The most valuable thing in this command is
  missing: the *actual failure text*. It asks a model to rediscover an error the
  shell already printed.
* **Construct mapping.** The archetypal `running` party — `ask (tool "build"
  \`running\` ("./build", ["system"]))` produces a receipt the **world** authored,
  which is then the subject of the diagnosis. That is the difference between "an
  agent says it rebuilt" and "the rebuild's exit text is in the program". Then
  `revising receipt (atMost 3)` with a `decide ContainsLine` on success text as
  the settle condition — zero questions for the check.

## 37. `partner-cleanup.md`

* **Purpose.** The main-agent half of a two-agent loop: drain actionable
  observation files from `obr` or `doc/observations/`, have a sub-agent fix each,
  and make exactly one cleanup commit once the directory is empty.
* **Structure.** 121 lines, six sections. Scope (which files count: regular,
  non-hidden, `*.md`, top-level only); preconditions (repo root, batch capture by
  lexicographic sort, a three-way working-tree check); a **cleanup loop** with an
  explicit re-scan for observations that arrived mid-run; a verbatim sub-agent
  assignment in a fenced block (six numbered rules, including "Do not commit");
  main-agent review (five steps, including "Do not accept a superficial
  deletion"); commit rules; completion report.
* **Named references.** `obr` (external tool), `doc/observations/`,
  `partner-reviewer` / `partner-collaborator` (its producers, by role not by
  name), `wiggum` skill names this as a loop stage.
* **Inputs.** `$ARGUMENTS` = observations directory, default `obr` or
  `doc/observations/`.
* **Outputs.** Code/test edits, removed observation files, exactly one commit,
  a completion report.
* **Quality read.** **Level up.** This is a genuinely good design — the re-scan
  and the "one commit for the whole batch" rule both come from real experience —
  expressed in a language that cannot enforce either. Two claims it makes and
  cannot check: that the sub-agent did not commit, and that every observation was
  either fixed or justified.
* **Construct mapping.** The sub-agent assignment is a `function` with the batch
  as a `takes @"batch" Text` parameter — one text, one callee, no drift between
  the parallel and serial paths. The drain loop is `revisingOn dir (atMost n)`
  whose settle condition is a `tool "ls"` receipt read by `decide ContainsLine`
  against the empty marker — a **zero-question** loop test. The
  "did-not-commit" rule becomes structural: the fixer question returns `CodeText`
  and never `CodeAck`, so `permissionByCode` denies it write authority outright,
  which is `I3` in `isaac-workflows.md` applied to exactly the rule this prose
  states and cannot hold.

## 38. `partner-collaborator.md`

* **Purpose.** The reviewing half of the two-agent loop, in its richer form:
  watch for new commits, deep-review each, and publish every actionable finding —
  **and every genuinely good idea** — as its own atomic observation file.
* **Structure.** 195 lines. Argument grammar (five distinct forms: empty, a ref,
  a range `A..B`, an integer poll interval, a ref plus an integer); setup (state
  under `.git/partner-reviewer/`, never in the work tree); a watch loop with an
  explicit **rebase-detection** clause; a six-step review procedure; a nine-step
  **ideation pass** (identify hidden assumptions → invert one → three wild ideas →
  borrow from an unrelated discipline → explain the mechanism); an observation
  file contract (seven metadata fields, four body sections); an **atomic write
  requirement** (build, temp file, flush, rename, retry on collision); reporting.
* **Named references.** `deep-review` command/skill (its review engine), `obr`,
  `partner-cleanup` (its consumer, by role).
* **Inputs.** `$ARGUMENTS` in five shapes; git history; `.git/partner-reviewer/`
  state.
* **Outputs.** One observation file (or `obr` issue) per finding; a per-commit
  report; updated watcher state.
* **Quality read.** **Level up**, and it is the most *interesting* file in the
  range. The ideation pass is a second, orthogonal panel wearing the clothes of a
  numbered list, and its severity discipline ("silence is better than noise",
  "Prefer zero observations over noisy observations") is stated three times
  because prose has no other way to enforce it.
* **Construct mapping.** Two `panel`s over one commit: the **defect** panel
  (correctness, security, regression, test coverage, contracts, migrations,
  performance, docs), each member `servedBy` a different engine so the findings
  are genuinely independent; and the **idea** panel, which is `drawing` on a
  single lateral-thinking party — `ask (model "lateral") \`drawing\` 3` prices
  three independent draws as three questions, which is what "generate three wild
  ideas" actually means and what a single prompt asking for three cannot give.
  The five-shape argument grammar is `input`s with defaults, not parsing prose.
  The observation contract is a `function` both panels call, so a defect file and
  an idea file cannot drift in their headers. The atomic write is a `running`
  party over a real `mv`, not an instruction.

## 39. `partner-reviewer.md`

* **Purpose.** The same reviewing half, minus the ideation pass, routed through
  `heavy-review` instead of `deep-review`.
* **Structure.** 110 lines — `partner-collaborator.md` with the "Ideas and
  Suggestions" section removed, the `Idea` category dropped from the observation
  contract, and the engine swapped. Otherwise line-for-line the same design,
  reflowed to long lines.
* **Named references.** `heavy-review` command (**this is the only difference in
  the engine edge**), `obr`, `partner-cleanup`.
* **Inputs.** Identical five-shape `$ARGUMENTS`.
* **Outputs.** Observation files, defects only.
* **Quality read.** **Rework — this is the range's clearest duplication.** Two
  files, ~85% identical, differing in one named engine and one optional section.
  They have already drifted: `partner-collaborator` says "create
  `doc/observations/` if `obr` is not being used" at step 2 and carries a typo
  (`etiher`), `partner-reviewer` says the same thing in different words, and the
  Category enum differs by one member. This is exactly the drift `incite`'s
  single-binding discipline exists to prevent.
* **Construct mapping.** **One** program, `taking (input "engine" …
  (input "ideas" noInputs))`. The watch loop, the review procedure, the
  observation contract and the atomic write are one `function` table shared by
  both; the ideation panel stands behind `ifFlag ideas`. Two commands become one
  program and two invocations, and `costSummary` prices the ideas flag: the two
  arms are two paths with two bills, which is a thing the two Markdown files
  cannot say at all.

## 40. `prepare-with.md`

* **Purpose.** Use a set of named agents to analyze a project and produce
  expert guidance for constructing its `CLAUDE.md`.
* **Structure.** 24 lines. `$ARGUMENTS` is *the agent roster* — unusual and good.
  Two "what to add" items; eight "usage notes" that are almost entirely
  **negative** (do not repeat, do not include obvious instructions, do not list
  every component, do not invent sections); a mandatory verbatim file prefix.
* **Named references.** `$ARGUMENTS` names agents dynamically — so it can name any
  of the 26. Sibling: `initialize` (commands-1), which is this without the roster.
* **Inputs.** `$ARGUMENTS` = agent names; the project tree; an existing
  `CLAUDE.md`, `README.md`, `.cursor/rules/`, `.github/copilot-instructions.md`.
* **Outputs.** Guidance (not the file itself — it produces advice about the file).
* **Quality read.** **Level up.** A roster passed as an argument is a *dynamic
  fan-out*, which is `G8` in `isaac-workflows.md` — the one gap this corpus hits
  hardest and most often. The negative list is the interesting part: eight rules
  about what must not appear, none of which anything checks.
* **Construct mapping.** The roster is a static `[(Text, Text)]` table in Haskell
  with `panel (rosterOver table)` — a lens per agent, its brief derived from its
  row, exactly `grindLensRoster`. The eight negative rules become a real
  `fess`-style auditor: `ask (model "claude-md-audit" \`servedBy\` <other>)` over
  the draft, asking only whether any of the eight prohibitions was violated, then
  `revisingOn` on its verdict. The mandatory prefix is a `lit`, so it cannot be
  paraphrased.

## 41. `process-checklist.md`

* **Purpose.** Work through a Markdown checklist file, completing and ticking
  every unfinished item, then self-verify and repeat until complete.
* **Structure.** 10 lines. A four-step per-item loop (verify still incomplete →
  implement → confirm → tick), then an outer self-verification loop with no bound.
* **Named references.** None.
* **Inputs.** `$ARGUMENTS` = path to a checklist file.
* **Outputs.** A completed checklist, edited in place; the work itself.
* **Quality read.** **Level up.** Ten lines that describe a nested bounded
  revision, an idempotence check, and a fixpoint — the densest ratio of structure
  to prose in the range. It is also unbounded twice over, which is `G9`: the
  language's refusal to express "loop forever" is the feature here, not the
  limitation.
* **Construct mapping.** Outer `revisingOn checklist (atMost n)` whose settle test
  is a **pure decider** over the file's own text — `decide ContainsLine checklist
  ["- [ ] "]` inverted — costing zero questions per trip, where the prose spends
  a full re-read. Inner per-item work is a `function` called once per item.
  "Verify the task is still incomplete" is precisely the guard a re-entrant loop
  needs and is precisely what `decide` gives for free.

## 42. `productize.md`

* **Purpose.** Turn a repository into a product: README, LICENSE, `flake.nix` dev
  shell, formatters, linters, coverage, profiling, fuzzing, sanitizers, docs
  build, `lefthook.yml`, and GitHub Actions — all running in parallel on
  pre-commit.
* **Structure.** 92 lines. A flat 21-item bullet list of *independent* deliverables
  (each is a build target or a check), an inline `lefthook.yml` example, then a
  per-language tool table (Haskell, Rust, C++, Python, Bash, Emacs Lisp, Coq/Rocq)
  in which **five of the fourteen cells say "use available live web search to find
  the best option"** — the table is half-empty by construction.
* **Named references.** `johnw` skill (for the README voice); `lefthook` command
  (commands-1) which is item 21 of this list, standalone; tools `fourmolu`,
  `cargo clippy`, `cargo fmt`, `clang-tidy`, `cppcheck`, `clang-format`, `ruff`,
  `shfmt`.
* **Inputs.** None. The repository is the subject. Git commit years are read for
  the LICENSE range.
* **Outputs.** A large set of files: `README.md`, `LICENSE.md`, `flake.nix`,
  `lefthook.yml`, CI workflows, build targets.
* **Quality read.** **Level up**, and it is the largest *unpriced* command in the
  range. Twenty-one independent deliverables presented as a list is a fan-out
  presented as a sentence; nothing sequences them, nothing checks them, and the
  five empty table cells mean the shape of the work is not known until run time.
* **Construct mapping.** A static roster `[(Text, Text)]` of the 21 deliverables,
  `panelText` over it, so the run is priced at 21 before it starts. The language
  table is a Haskell `Map Text (Text, Text)` whose *empty* cells become a
  `tool "search"` question asked **once per language present**, not once per
  deliverable — which is the saving. Each deliverable then wants its own
  `running` receipt: `ask (tool "check" \`running\` ("nix", ["flake","check"]))`
  is the difference between "added a CI check" and a receipt the world authored.
  The README gets `servedBy` a model and the `johnw` voice as a define; every
  other item is a `tool`.

## 43. `proofread.md`

* **Purpose.** Fix spelling, grammar, and punctuation across every Markdown,
  Org-mode, and text file in a project, preserving voice.
* **Structure.** 27 lines, four blocks: corrections to make (2 categories, 5
  sub-rules); important guidelines (5); an explicit **do NOT change** list (5:
  stylistic choices, intentional informality, jargon, URLs/paths/code, British vs
  American spelling); output format (corrected file plus a count-and-type summary).
* **Named references.** None.
* **Inputs.** None (whole project). No `$ARGUMENTS`.
* **Outputs.** Edited files in place; a per-file summary of corrections.
* **Quality read.** **Keep**, with one structural upgrade. The negative list is
  well-drawn and the required per-file count ("Fixed 3 spelling errors, 2 comma
  splices") is an unusually good discipline — it makes over-editing visible.
* **Construct mapping.** The subject is a *file set*, which is `G8` again: the
  roster is dynamic. Two honest options — take the paths as `--input-arg`, or
  `ask (tool "find" \`running\` ("git", ["ls-files","*.md","*.org","*.txt"]))`
  and treat the receipt as the roster in a prompt. The five prohibitions then
  become a second-model diff auditor, `confirm (model "voice-check" \`servedBy\`
  <other>) [wf|{prohibitions}\n{diff}|]`, with `unless` → revert. The count
  summary is the receipt, not a claim.

## 44. `push.md`

* **Purpose.** Run `/commit`, then open a PR and push it.
* **Structure.** One sentence. It is a **composition of two commands**, one of
  which (`commit`) is a 100+ line procedure in commands-1.
* **Named references.** `/commit` (explicit, by slash name).
* **Inputs.** None.
* **Outputs.** A series of commits, a pushed branch, a PR.
* **Quality read.** **Level up.** This is the corpus's own admission that it wants
  function calls: the entire content of the file is "call `commit`, then do two
  more things". In Markdown that is a name and a hope; here it is a `Fn`.
* **Construct mapping.** `defining [SomeFn commitFn]` and then
  `call_ commitFn (arg scope :> noArgs)` followed by two `running` acts (`gh pr
  create`, `git push`). A call is priced at the callee's own `bodyAsks`, so
  `push` costs exactly `commit` plus two — which is a number, where today it is
  a sentence.

## 45. `qanda.md`

* **Purpose.** Walk the operator through a set of pending decisions one at a time,
  with background, implications, and trade-offs, using the client's Q&A interface.
* **Structure.** Three lines. No arguments. Depends entirely on conversational
  antecedent ("these decisions").
* **Named references.** "the Claude Code question/answer interface" — a client
  capability, not a named artefact.
* **Inputs.** Implicit: a decision list from the prior turn.
* **Outputs.** Answers, held in conversation.
* **Quality read.** **Rework.** Like `markdown.md`, it is a continuation with no
  named input. But its shape is the most *natively expressible* thing in the
  range: a sequence of `ask (person "operator")` in binding position, each answer
  live for the questions after it.
* **Construct mapping.** `taking (input "decisions" noInputs)`, then per decision
  a `person "operator"` question whose brief is derived from the decision's row
  and whose answer is spliced into the next — which is the whole of "step by
  step, with implications". `ship-feature-lite`'s `steer` is exactly this shape
  and is already proven in `Example.Isaac`.

## 46. `query-builder.md`

* **Purpose.** Build an SQL query from schema alone, answering a stated question,
  **without ever revealing table data**.
* **Structure.** Seven lines. One agent, one MCP, and a security constraint
  stated three times in four sentences ("Never reveal table data", "Treat all of
  the data as if it were highly secret", "never reveal any of it").
* **Named references.** `sql-pro` agent; `mssql` MCP.
* **Inputs.** The question, appended after the prompt.
* **Outputs.** An SQL query text. Explicitly *not* results.
* **Quality read.** **Level up**, and it is the range's best case for `I3`
  (structural read-only). The constraint is repeated three times because repetition
  is the only enforcement Markdown offers. A prompt that says "never reveal data"
  three times is a prompt that knows it cannot stop the model from revealing data.
* **Construct mapping.** The schema read and the query write are two questions
  with **two different codes**. The schema question is a `tool` party returning
  `CodeText`; because `permissionByCode` grants write authority only to `CodeAck`,
  a schema reader structurally cannot act. The query is authored from the schema
  answer alone, and the data is never in scope to leak because no question ever
  puts it there. The three repetitions collapse into one type.

## 47. `quick-review.md`

* **Purpose.** The fastest rung of the review ladder: a single-pass review with no
  sub-agents, for feedback during development.
* **Structure.** 36 lines. An explicit **"See also — review ladder"** paragraph
  naming all five rungs and telling the reader to "pick the lightest rung that
  fits"; a three-way scope resolution from `$ARGUMENTS` (git ref → file paths →
  empty means uncommitted-or-last-commit); four numbered check categories; a
  one-line output format with a severity token.
* **Named references.** `code-review`, `deep-review`, `sec-audit`,
  `review-github-pr` — **the ladder paragraph, which appears verbatim in three
  files in this range and more in commands-1.**
* **Inputs.** `$ARGUMENTS` = ref, range, paths, or empty.
* **Outputs.** Findings inline, `**[SEVERITY]** file:line — description`.
* **Quality read.** **Keep the ladder, rework the duplication.** The ladder
  paragraph is the corpus's only explicit statement of *how its commands relate*,
  and it is maintained by copy-paste in at least five files. That is a shared
  binding written five times.
* **Construct mapping.** The ladder becomes one Haskell value — a rung table —
  and every rung's brief derives its "see also" text from it, so a rung added or
  renamed reaches all five briefs by being added. That is `qaFence`'s derived
  roster applied to the corpus's own navigation. The scope resolution is `input`s
  with defaults; the four categories are four `panel` members priced at 4 rather
  than one ask asked to hold four rubrics.

## 48. `rebase-and-fix.md`

* **Purpose.** Rebase the working tree onto a branch, resolving conflicts with
  language agents, rewrite and force-push all descendant branches, then watch CI
  and address bot comments.
* **Structure.** 13 lines, four concerns fused: (1) rebase + conflict resolution;
  (2) descendant-branch rewrite and force-push, with a branch↔commit invariant
  stated in prose; (3) CI watch-and-fix with an inline `GH_TOKEN` incantation;
  (4) bot-comment triage, fix, reply, resolve.
* **Named references.** `haskell-pro`, `cpp-pro` agents; the `resolve` command
  (named as "the canonical conflict-resolution step this follows"); `gh`;
  BugBot / Cursor / Devin as comment sources. Overlaps `fix-ci` and `bugbot`
  (commands-1).
* **Inputs.** `$ARGUMENTS` = target branch.
* **Outputs.** A rebased branch, rewritten descendants, force pushes, green CI,
  resolved bot threads.
* **Quality read.** **Rework — it is four commands in one file.** Each of its four
  concerns exists as its own command elsewhere in the corpus (`resolve`, `restack`,
  `fix-ci`, `bugbot`). The invariant it states — "the branch↔commit relationship is
  preserved despite these rewrites" — is checkable and is not checked.
* **Construct mapping.** Four `call_`s to four functions, in order, in one program:
  `resolveFn`, `restackFn`, `fixCiFn`, `botFn`. The invariant becomes a `running`
  party over `git range-diff` between recorded pre- and post- tips — a receipt the
  world authored — read by `decide ContainsLine`, which is exactly what `restack.md`
  step 9 asks for in English and this file does not ask for at all.

## 49. `rebase.md`

* **Purpose.** `rebase-and-fix` minus the CI and bot phases: rebase, resolve with
  `haskell-pro`, rewrite descendants, force-push.
* **Structure.** 11 lines. Opens with the generic "think deeply, construct a
  plan, execute step by step" preamble that also opens `medium.md`; then the same
  `resolve` see-also paragraph; then the same descendant-rewrite bullets as
  `rebase-and-fix.md`, **verbatim**.
* **Named references.** `haskell-pro` (not `cpp-pro` — the one substantive
  difference from its sibling); `resolve` command.
* **Inputs.** `$ARGUMENTS` = target branch.
* **Outputs.** A rebased branch, rewritten descendants, force pushes.
* **Quality read.** **Rework — duplication with `rebase-and-fix.md`.** The three
  descendant-rewrite bullets are byte-identical across the two files, and the
  agent roster differs by one name. Second instance of the `partner-*` pattern.
* **Construct mapping.** One program with the CI/bot tail behind
  `ifFlag followUp`, and the language roster as an input rather than a hardcoded
  pair. Two commands, one program, two paths, two prices.

## 50. `recommit.md`

* **Purpose.** Rebuild the branch as a series of logical successive commits from
  `main`, each of which passes CI on its own, in preparation for a stacked-PR
  submission.
* **Structure.** Three lines. Line 1 is a *call with an override*: "`/commit` but
  ignore the current state of `$ARGUMENTS`". Line 3 states the hard constraint —
  **each commit must pass CI standalone** — and then delegates analysis to
  "your superpowers".
* **Named references.** `/commit` (explicit); "superpowers" (the skill bundle);
  `bankruptcy` and `commit` in commands-1 are the near neighbours.
* **Inputs.** `$ARGUMENTS` = state to ignore.
* **Outputs.** A rewritten commit series.
* **Quality read.** **Level up.** "Each commit should pass scrutiny and all CI
  tests on its own" is a per-element check over a produced list, asserted and
  never run. This is the range's cleanest example of a claim that a program can
  turn into a receipt.
* **Construct mapping.** `call_ commitFn` with an argument — the override is
  literally a parameter, which is what line 1 already says. Then the standalone-CI
  claim becomes a bounded revision per commit: `revisingOn series (atMost 3)` with
  a `running` build receipt at each candidate, settling on `decide
  LastNonEmptyLineIs receipt ["BUILD OK"]`. Cost is then `commit` + 3n in the worst
  case and `commit` + n in the best, over n paths — a fact the prose cannot state.

## 51. `remove-service.md`

* **Purpose.** Completely remove a named service from a NixOS host — nginx
  vhosts, monitoring, alerting, systemd units and timers, containers, Nagios,
  Alertmanager, exporters, config, users, directories, data.
* **Structure.** Nine lines, with an unusual and important **inversion**: it
  explicitly forbids performing the removal and requires *generating a script the
  operator will run later*. Nix declarations may be edited directly; SOPS secrets
  are the operator's. Two secrecy rules ("Do not reveal ANY secrets", "always ask
  me" for a new SOPS secret or SSL cert). A coherence requirement: the machine's
  other services must keep working.
* **Named references.** `nixos` skill; live web search. Cousin: `install-service`
  (commands-1) — the inverse operation; `nix-rebuild` (this range).
* **Inputs.** `$ARGUMENTS` = service name.
* **Outputs.** A removal script (not executed); edited Nix declarations.
* **Quality read.** **Keep the policy, level up the mechanism.** The "generate a
  script, do not run it" inversion is the single best safety idea in the range and
  is exactly `I3` avant la lettre — it separates authoring from acting. The two
  "ask me" clauses are human gates with no mechanism.
* **Construct mapping.** The inversion is native: every discovery question is a
  `tool` party returning `CodeText` (no write authority by construction), and the
  script is one `act` at the end. The two "ask me" clauses are `confirm (person
  "operator")` with `unless … stop` — a terminal arm the compiler will not let the
  author omit, which is `I4`. The coherence requirement is a `panel` of per-subsystem
  auditors (nginx, systemd, prometheus, nagios, users, data) over the generated
  script — six independent readers of one artefact, priced at six.

## 52. `report.md`

* **Purpose.** Pause and produce a comprehensive completion report: the remaining
  roadmap phase by phase, open questions, design, implementation, testing,
  documentation, cleanup, review — with a time estimate calibrated against how
  long the work has taken so far.
* **Structure.** Two paragraphs. Names seven work categories; requires a
  human-familiar-with-the-project register; asks for **metadata tags to support
  future updates of the same document** — an unusual and thoughtful requirement;
  requires a time estimate grounded in observed velocity and remaining unknowns.
* **Named references.** None explicitly. Near neighbours: `sitrep` (this range),
  `halt` and `narrative` (halt in commands-1).
* **Inputs.** None. Project state.
* **Outputs.** A Markdown report, path unspecified.
* **Quality read.** **Rework — it overlaps `sitrep.md` and `halt.md` substantially
  and states no boundary.** Three commands produce a status document; only
  `sitrep` says where it goes. The metadata-tags requirement is the seed of a
  real idea (a report that can be re-derived) that nothing else in the corpus
  picks up.
* **Construct mapping.** Seven categories → seven `panelText` members over one
  evidence dossier, so the categories are priced and none can be silently
  dropped. The estimate is a separate question on a separate `servedBy`, over the
  *fold* rather than the project, so the estimator reads what the panel said and
  not what it wishes. The metadata tags become an `--input` on re-run: the prior
  report is a program input, and the update is a `revisingOn` over it.

## 53. `resolve.md`

* **Purpose.** Resolve the working tree's merge conflicts, preserving the
  semantics of the incoming change and the intent of the current work; `git add`
  the results; **do not commit**.
* **Structure.** One sentence, and it is the corpus's most *reused* sentence:
  `rebase.md`, `rebase-and-fix.md`, and `restack.md` all cite it by name as their
  canonical conflict step.
* **Named references.** `$ARGUMENTS` names the agents to use (like
  `prepare-with.md`, a dynamic roster). Cited **by** `rebase`, `rebase-and-fix`,
  `restack`.
* **Inputs.** `$ARGUMENTS` = agent names; the conflicted working tree.
* **Outputs.** Resolved files, staged, uncommitted.
* **Quality read.** **Keep — and promote.** This is already a function in
  everything but name: three commands call it, it takes a parameter, it has one
  job and a crisp postcondition. It is the corpus's proof that it wants `Fn`.
* **Construct mapping.** `function "git.resolve" (takes @"agents" Text $
  noParams)`, in `defining` for all three callers. The postcondition — staged,
  zero conflict markers, not committed — is a `running` receipt over
  `git diff --check` read by a pure `decide`, costing zero questions, and the
  "do not commit" rule is structural: the resolver's answer is `CodeText`, so it
  has no authority to commit.

## 54. `respond.md`

* **Purpose.** Answer every open reviewer comment on a PR — but as a Markdown
  report, not as GitHub replies.
* **Structure.** Two sentences. The whole design is the *redirection*: the natural
  action (reply on GitHub) is explicitly replaced by an artefact the operator
  reviews first.
* **Named references.** None. Near neighbours: `assess`, `bugbot`,
  `review-github-pr` — the last shares the never-post discipline and states it in
  screaming capitals over ten lines.
* **Inputs.** `$ARGUMENTS` = PR number/URL.
* **Outputs.** A Markdown report, one answer per comment.
* **Quality read.** **Level up.** Same design as `review-github-pr.md`'s
  never-post rule, and the two files enforce it by wildly different amounts of
  shouting: two sentences here, a fenced all-caps section there. Neither can
  actually stop a `gh pr comment`.
* **Construct mapping.** The comment roster is an `ask (tool "gh" \`running\`
  ("gh", ["pr","view","--json","comments"]))` receipt; one answer per comment is
  a `function` called per row, and the report is `panelText` over the answers.
  Never-posting is not a rule but an absence: no question in the program is a
  `running` party with a write verb, so the program has no way to post, and the
  ten capitalized lines become zero lines.

## 55. `restack.md`

* **Purpose.** Bring an entire Graphite PR stack up to date with `main`, resolving
  every conflict, verifying each resolution, and submitting the result.
* **Structure.** 38 lines, nine numbered steps — the most rigorous procedure in
  the range. Step 1 **records the starting state** (`gt ls`, each branch tip SHA)
  *so the final report can prove nothing was lost*; step 4 delegates to `resolve`
  and adds a genuinely good rule ("when each side added something orthogonal,
  combine both sides rather than picking one"); step 5 requires per-resolution
  verification (zero markers, builds, unit tests) before proceeding; step 7 is a
  **fixpoint** (if `main` moved, go back to step 2 — with `git rerere` replaying);
  step 9 requires `git range-diff` between recorded and new tips as *evidence*.
* **Named references.** `resolve` command; `haskell-pro`, `cpp-pro` agents; `gt`
  (Graphite), `git rerere`, `git range-diff`; `bin/ingest-cabal` as the example
  verification. Named **by** `wiggum` as the last stage of its loop.
* **Inputs.** None (the current stack). `GIT_EDITOR=true` is mandated.
* **Outputs.** A restacked, submitted stack; a complete run summary with evidence.
* **Quality read.** **Keep — this is the best-engineered command in the range**,
  and the one whose discipline the rest of the corpus should inherit. Record the
  baseline, verify each step, prove nothing was lost with a mechanical diff. Its
  only defect is that all of that rigour is *asked for* rather than *held*.
* **Construct mapping.** Step 1's baseline is a `running` receipt bound at the
  top and live for the whole program — which is what makes step 9's proof
  possible without trusting memory. Step 4 is `call_ resolveFn`. Step 5 is
  `revisingOn resolution (atMost 3)` whose settle test is a `decide ContainsLine`
  over a real build receipt — zero questions. Step 7's fixpoint is the outer
  `revisingOn` over `gt ls`, again decided purely. Step 9 is a `running`
  `git range-diff` receipt compared against the step-1 handle: the evidence is in
  the program, not in the report's prose. This one command exercises `running`,
  `decide`, nested `revisingOn`, `call_`, and a live baseline handle — it is the
  best single demonstration target in the corpus.

## 56. `retest-categorical.md`

* **Purpose.** Confirm the categorical ingest pipeline is a byte-for-byte drop-in
  for the legacy path with no performance regression, across a fixed eight-model
  roster.
* **Structure.** 474 lines — the largest file in the range and possibly the
  corpus. A blockquoted **branch precondition** with an abort incantation; an
  explicit "this is the categorical specialization of `/retest`" section
  containing a **nine-row override table** against its parent; two paragraphs
  naming exactly where the two documents *conflict* (phase numbering off by one
  for perf; `--no-semantic` means structurally different things); an argument
  grammar; operating rules inherited "verbatim" from the parent plus two
  specializations; a known-traps table; six phases (0 provision, 1 rebuild, 2 unit
  tests, 3 the byte-exact headline gate, 4 semantic logit parity, 5 perf +
  decode-token parity); embedded bash for the roster and the sweep runner; a
  final-report section with a **five-value verdict taxonomy** (`BYTE-EXACT
  DROP-IN`, `INCOMPLETE`, `REGRESSION`, `OUT-OF-SCOPE`, and a triage rule for
  `FAIL(rc=…)`) in which *every status Phase 3 can emit maps to exactly one*.
* **Named references.** `/retest` command (**documentation-style delegation** —
  the file says so explicitly: "there is no machine handoff or argument
  forwarding; read both docs and apply the overrides by hand"); the `retest`
  skill by transitivity; `bin/ci/categorical_logit_matrix.sh`,
  `t/t_generate_categorical_fpga_real.cpp`, `bin/get_model`, `runtron`,
  `make build-categorical`; issue #2808.
* **Inputs.** `$ARGUMENTS` = bare model tags (subsetting Phases 3 & 5 but
  **not** Phase 4), `--no-perf`, `--no-semantic`.
* **Outputs.** One consolidated result table; per-phase per-model verdicts; an
  overall verdict from the taxonomy.
* **Quality read.** **Level up — this is the highest-value transform target in the
  range, by a wide margin.** It is a rigorously specified conformance battery, and
  the file itself documents the mechanism it is missing in one sentence:
  *"This is a documentation-style delegation — there is no machine handoff or
  argument forwarding; read both docs and apply the overrides by hand."* That is a
  function call written as a request that a human perform a function call. The
  two documented conflicts (phase numbering, `--no-semantic`) are the *predicted
  consequence* of that missing mechanism, and the file predicts them accurately.
* **Construct mapping.** `/retest` becomes `Fn` with parameters for every row of
  the override table — roster, comparison binary, build target, sweep filter,
  Phase-4 body, slug scheme, verdict label. `retest-categorical` is then
  `call retestFn (arg categoricalRoster :> arg byteExactOracle :> …)`, and the
  nine overrides are nine arguments. **Phase numbering ceases to exist as a
  concept**, because phases are statements in a body and not numbers in prose, so
  the off-by-one is unrepresentable. `--no-perf` and `--no-semantic` become
  `input`s consumed by `ifFlag`, so `--no-semantic` means one thing at one binding
  site. The branch precondition is a `running` receipt (`make -n
  build-categorical`) read by a pure `decide`, then `unless … stop` — a terminal
  arm nobody can forget. Each of the six phases is a `function`. The verdict
  taxonomy is `caseVerdict` over a fold, and its "every status maps to exactly
  one" property becomes total-case exhaustiveness that the compiler holds. And
  `costSummary` prices the battery — eight models × boundary sweep × two skip
  flags — **before** an FPGA is touched, which is the operational win: this
  command's phases cost hours.

## 57. `retest.md`

* **Purpose.** Run the full model-support retest battery for a named model set by
  following the `retest` skill exactly.
* **Structure.** Four lines. It is a *pure delegation stub*: derive the model set
  from the branch diff, work Phases 0–6, "follow it exactly". All content lives in
  the skill.
* **Named references.** `retest` skill (the entire body). Named **by**
  `retest-categorical.md` as its parent, and by name in five places there.
* **Inputs.** `$ARGUMENTS` = model set / branch scope.
* **Outputs.** The skill's phase reports.
* **Quality read.** **Rework — the delegation is real but unidirectional.** A
  four-line command whose 474-line child overrides nine of its rows and documents
  two conflicts with it is a parent that does not know it has been specialized.
* **Construct mapping.** The parent `Fn`, per §56. Its parameters are exactly the
  nine override rows; its default arguments are the general HF-oracle battery.
  `retest` and `retest-categorical` become two `Parameterized` programs over one
  function table, which is the whole of what "the categorical specialization of
  `/retest`" means and what neither Markdown file can hold.

## 58. `review-github-pr.md`

* **Purpose.** Review a GitHub PR in a detached worktree at its exact head commit,
  reporting locally and **never posting to GitHub**.
* **Structure.** 61 lines. The ladder paragraph; a fenced all-caps
  **"CRITICAL: DO NOT POST TO GITHUB"** section with four explicit prohibitions
  (`gh pr review`, `gh pr comment`, any writing CLI command, any form of
  submission); a ten-step review process whose step 2 is unusually careful —
  fetch the head, create a detached worktree under `work/pr-NUMBER`, and **verify
  `HEAD == headRefOid`, stopping rather than reviewing another revision**; an
  output format; a post-report clause allowing *suggestion* of posting only after
  explicit operator confirmation; a tools section.
* **Named references.** `quick-review`, `code-review`, `deep-review`, `sec-audit`
  (ladder); `cpp-pro`, `python-pro`, `emacs-lisp-pro`, `rust-pro`, `haskell-pro`
  agents; `pal` MCP with `gemini-3.1-pro-preview` and `gpt-5.5-pro`, conditional
  on the worktree path being under `positron`/`pos`; sequential-thinking; live
  web search; `gh` with a pinned token incantation.
* **Inputs.** `$ARGUMENTS` = PR reference.
* **Outputs.** A Markdown report in the response **and** saved to the worktree.
* **Quality read.** **Level up.** Two excellent ideas fighting their medium. The
  head-OID equality check is a real conformance gate stated in English. The
  never-post rule is shouted because shouting is the only enforcement available —
  and the file then *undermines itself* by naming the exact four commands it
  forbids, which is a prompt containing its own attack.
* **Construct mapping.** Never-posting is structural, not textual: no `running`
  party in the program carries a write verb, and every reviewer question returns
  `CodeText`, so `permissionByCode` denies write authority — the four
  prohibitions and the capitals both disappear. The head-OID check is a `running`
  `git rev-parse` receipt compared to a `gh pr view` receipt by `decide
  ContainsLine`, then `unless … stop`: an arm the compiler requires. The
  five language agents are a `panel` with `servedBy` per member, not a menu. The
  `positron`-conditional PAL consensus is `ifFlag` on a path decider — `decide
  AnyPathMatches worktree ["positron/","pos/"]`, which costs zero questions where
  today it costs a judgment call. The "suggest posting" clause is
  `confirm (person "operator")` with a terminal `unless`.

## 59. `run-orchestrator.md`

* **Purpose.** Act as project orchestrator: decompose the work, spawn sub-agents
  for available tasks, monitor, and continue autonomously to completion.
* **Structure.** 24 lines. Three preliminary rules; an eight-step orchestrator
  loop (break down → save findings → checkpoint commit → document works-vs-should
  → check dependencies → identify parallelizable tasks → spawn → monitor); a
  delegation clause; and a strong autonomy clause — "DO NOT pause… Work
  continuously… do not stop to ask for my review".
* **Named references.** `task-breakdown` agent; sequential-thinking; live web
  search; `@CLAUDE.md`. Overlaps `wiggum` (autonomy loop) and `teams` (fan-out).
* **Inputs.** None explicit; the project and its `CLAUDE.md`.
* **Outputs.** Completed work; checkpoint commits; saved findings and test results.
* **Quality read.** **Rework.** Steps 5 and 6 ("check task dependencies",
  "identify tasks that can run in parallel") describe a *graph* and the file
  provides no way to express one. The autonomy clause plus an unbounded loop is
  precisely `G9` — and here the language's refusal is a safety property, not a
  limitation.
* **Construct mapping.** `atMost n` gives the autonomy clause a bound the prose
  refuses to state. The dependency graph is a Haskell value — a topologically
  sorted `[(Text, [Text])]` — from which the fan-out roster is derived, so
  "identify parallelizable tasks" becomes a pure computation over the table and
  not a question. "Save test results before claiming completion" is a `running`
  receipt, and the claim it guards becomes a `decide` over that receipt.
  Overlaps `wiggum` enough that both should share a loop `Fn`.

## 60. `sec-audit.md`

* **Purpose.** A security-narrowed review: spawn `security-reviewer`, run three
  grep sweeps in parallel, and synthesize.
* **Structure.** 33 lines. The ladder paragraph; a three-way scope resolution
  identical in shape to `quick-review.md`'s; an execution section that spawns one
  agent **and** runs three named greps (secrets, dangerous patterns, hardcoded
  IPs) with their exact regexes; a report section requiring dedup, severity sort,
  confidence scores, and "the same structured format as `/deep-review`".
* **Named references.** `security-reviewer` agent; `quick-review`, `code-review`,
  `deep-review`, `review-github-pr` (ladder); `/deep-review` again for the output
  format.
* **Inputs.** `$ARGUMENTS` = ref, paths, or empty.
* **Outputs.** Deduplicated, severity-sorted findings with confidence.
* **Quality read.** **Level up**, and it is the best small example in the range of
  **the deterministic/probabilistic split**. Three of its four evidence sources
  are `grep` invocations with fixed regexes — facts, not opinions — and the file
  asks a model to run them and report what it saw.
* **Construct mapping.** The three greps are three `running` parties over real
  argv (`Agentic.Shell.proc`, never `sh -c`), producing receipts **the world
  authored**; the agent is one `ask (model "security" \`servedBy\` …)`. Then
  `panelText` folds the four blocks and one synthesis question dedups them. That
  is a program in which three quarters of the evidence cannot be hallucinated —
  which is the whole argument for `running` parties, on the one command where
  a fabricated "no secrets found" costs the most. The `/deep-review` output
  format becomes a shared `Fn`, ending the format drift across the five rungs.

## 61. `sitrep.md`

* **Purpose.** A situational report for a human reviewer: what the agent is
  trying to do, how far it has got, what blocks it, and how to spend the next
  unit of compute or attention.
* **Structure.** 89 lines. An evidence-gathering block (four bullets, including a
  long menu of possible measurements and an explicit "if a measurement would be
  useful but has not been taken, say so plainly rather than inventing one"); a
  **strict output path and naming scheme** —
  `~/Documents/Obsidian/YYYYMMDDTHHMM-SITREP-$PROJECT-$BRANCH.md`, with `/` in the
  branch replaced by `-`, and an explicit prohibition on writing into the project;
  eight named sections with a paragraph of guidance each (`Aim` — "do not shrink
  the aim to the work already completed"; `Accomplishments` — distinguish
  completed from started; `Next Steps`; `Blockers`; `Measurements`; `Distance To
  Completion` — a range, with stated assumptions; `Parallel Work`;
  `Recommendation`); a closing rule against hiding weak evidence behind polished
  prose.
* **Named references.** None. Near neighbours: `report` (this range), `halt`,
  `journal`, `narrative`.
* **Inputs.** `$ARGUMENTS` = scope; the working tree, git state, measurements.
* **Outputs.** One Markdown file at a strictly named path outside the project.
* **Quality read.** **Level up.** The eight sections are eight independent
  readings of one project state, and the two best rules in the file — "do not
  shrink the aim", "do not hide weak evidence behind polished prose" — are
  self-discipline asked of the writer, which is the weakest place to ask it.
* **Construct mapping.** Eight `panelText` members over one evidence dossier,
  priced at eight; the dossier itself is `running` receipts (`git status`, test
  output, benchmark output) so the `Measurements` section cannot invent a number
  that no command produced. The two self-discipline rules become an auditor on a
  different `servedBy` — read the `Aim` against the original request, read the
  report against the dossier — with `revisingOn` on the verdict. The filename
  scheme is computed in Haskell from `running` receipts (`git rev-parse
  --abbrev-ref HEAD`, `date`), which removes the one thing a model reliably gets
  wrong about this command.

## 62. `smooth.md`

* **Purpose.** Lightly polish given text — simplify, cut duplication and excess
  adjectives, fix grammar — while preserving voice, motion, emotion, power, and
  "exalted and high character".
* **Structure.** Three short paragraphs, then the text. The second paragraph is
  entirely a *restraint* clause ("should not change this text overmuch", "not
  apply a heavy hand", "only massage a little bit").
* **Named references.** None. Register neighbours: `proofread` (this range,
  stricter), `it-voice` and `johnw` skills, `translate-en`.
* **Inputs.** The text, appended.
* **Outputs.** The polished text.
* **Quality read.** **Rework.** "Do not change it overmuch" is the whole design
  and has no measure. Two models will disagree about "a little bit" by an order of
  magnitude, and nothing in the run notices.
* **Construct mapping.** `taking (input "text" noInputs)`; one `ask (model
  "smooth")`; then the restraint clause becomes a real gate — `confirm (model
  "restraint" \`servedBy\` <other>) [wf|{restraintRubric}\n{original}\n{polished}|]`
  asking whether any sentence changed meaning, with `revisingOn` amending toward
  a lighter touch. `smooth` and `proofread` are two settings of one dial and want
  one `Fn` with a strength parameter.

## 63. `teams.md`

* **Purpose.** Create a twelve-member agent team to explore a problem from twelve
  angles.
* **Structure.** 13 lines: one framing sentence and a twelve-item bullet list —
  three deep-research roles (domain, best practices, prior art), then UX,
  architecture, planning, testing/coverage, security, performance, documentation,
  devil's advocate, and **one reviewing all work performed by other teams**. No
  fold, no output format, no arguments.
* **Named references.** None — and that is notable: eleven of its twelve roles
  correspond to agents that exist by name in `agents/`
  (`security-reviewer`, `perf-reviewer`, the `*-pro` family, `prd-architect`,
  `task-breakdown`), and the file names none of them.
* **Inputs.** Implicit ("explore this").
* **Outputs.** Unspecified.
* **Quality read.** **Level up — this is the most literal `panel` in the entire
  corpus** and the cheapest high-value transform. A twelve-member fan-out with a
  synthesizing twelfth member, written as a bullet list with no fold and no price.
* **Construct mapping.** `[(Text, Text)]` roster of eleven lenses with the
  question each owns; `panelText (teamOver roster subject)`; one synthesis
  `ask` over the fold — which is the twelfth bullet, and the roster it refuses on
  is derived from the same table, exactly `grindSynthesisBrief`. Each member gets
  its own `servedBy`, so twelve angles are twelve genuinely different readers and
  not one model role-playing twelve times. `costSummary` says 13 before the run.
  The devil's advocate is the one member that must read the *others'* output, so
  it is a second tier, not a panel member — which the bullet list cannot say.

## 64. `transcribe-image.md`

* **Purpose.** Transcribe handwriting from images into paragraph-form Markdown,
  then re-review the transcription for correctness with a second model.
* **Structure.** Two sentences describing a **two-pass** shape: transcribe, then
  re-review via `pal` MCP with grammar and English usage as additional criteria.
* **Named references.** `pal` MCP.
* **Inputs.** `$ARGUMENTS` = image paths.
* **Outputs.** A Markdown file of paragraph-form text.
* **Quality read.** **Keep — it is already the right shape**, and it is the only
  command in the range that reaches for a *second* model as a check by default.
  It is under-specified only in that "re-review" has no stopping rule.
* **Construct mapping.** `ask (model "transcribe" \`servedBy\` "opus")` then
  `revisingOn draft (atMost 2)` with the review clause `ask (model "verify"
  \`servedBy\` <other>)`. The `pal` consensus is `servedBy` plus
  `fallingBackTo`; two independent readings of one image is `drawing 2`, which
  prices the second draw honestly. Multiple images are `--input-arg` per image
  and a panel over them.

## 65. `tron-debug.md`

* **Purpose.** Debug the C++ produced by the Torch Fx ingest pipeline, tracing
  through the Bulk, Loopy, Tron, and CPP intermediate representations.
* **Structure.** 22 lines. Context (`@src/Fx.hs`'s Note, and the IR chain); three
  fenced `<command>` blocks — the Torch-trace pipeline run, the *working* sglang
  frontend run for the same model, and the `runtron` test invocation; the problem
  statement (`$ARGUMENTS`); and a genuinely good investigative instruction: work
  out **why the working path works** to decide whether the fix belongs in the
  backend or the frontend.
* **Named references.** `@src/Fx.hs`, `@model.bulk`, `@model.loopy`, `@model.tron`,
  `@../h/tron/plugins`; `cabal run ingest`, `make`, `../gen/runtron`. Cousin:
  `retest-categorical` (same tree, same binaries).
* **Inputs.** `$ARGUMENTS` = the problem.
* **Outputs.** A diagnosis; possibly a fix.
* **Quality read.** **Level up.** The differential — run the broken path and the
  known-good path and compare — is a real methodology and the file leaves both
  runs to the model's discretion. The three `<command>` blocks are argv waiting
  to be receipts.
* **Construct mapping.** Three `running` parties over the three exact argv lines
  (via `Agentic.Shell.proc`, so no shell quoting is in play), yielding three
  receipts the world authored; then one comparison question over both dumps.
  Because the differential's *evidence* is receipts, the diagnosis cannot rest on
  a run that did not happen — which is the failure mode this command is most
  exposed to. `revisingOn` over the fix with a re-run receipt as the settle test.

## 66. `webfix.md`

* **Purpose.** Resolve issues in the current web application using Playwright and
  two language agents.
* **Structure.** Four lines: one tool/agent sentence and two generic bullets
  (live web search, sequential-thinking) that also appear verbatim in
  `run-orchestrator.md` and `review-github-pr.md`.
* **Named references.** Playwright; `typescript-pro`, `python-pro` agents.
* **Inputs.** The issues, appended.
* **Outputs.** Fixes.
* **Quality read.** **Rework.** The thinnest command with a real capability behind
  it. Playwright gives it an actual oracle — a browser that either shows the bug
  or does not — and the file spends none of its four lines on using it as one.
* **Construct mapping.** `running` over the Playwright runner, before and after,
  as two receipts; `revisingOn fix (atMost 3)` settling on `decide ContainsLine`
  over the after-receipt. That converts "resolve the issues" from a claim into a
  reproduction that stopped reproducing. The two generic bullets become a shared
  `Text` define, not copy-paste.

## 67. `wiggum.md`

* **Purpose.** Enter autonomous-continuation mode: keep going without pausing
  until the Definition of Done holds, or a stop-and-escalate condition fires.
* **Structure.** Seven lines, three paragraphs. The DoD and its alternative
  (parity with a named reference target); an **environment discipline** paragraph
  that is unusually specific and unusually good (read from the working tree's
  direnv; never `nix develop`; never install on the fly; if blocked on a
  dependency, **stop and ask**; if it can go in Nix, add it, regenerate with `de`,
  re-read, retry); and a delegation to the `wiggum` skill naming eight mechanisms
  it owns.
* **Named references.** `wiggum` skill (the body); `parallelize` skill (fan-out
  limits); `partner-cleanup` and `restack` **commands**, named inside the loop
  description (`work -> commit -> audit -> partner-cleanup -> restack`); PAL for
  consensus; `de`.
* **Inputs.** `$ARGUMENTS` = the work.
* **Outputs.** Completed work; commits; durable plan/handoff/journal state.
* **Quality read.** **Level up — and it is the corpus's own top-level loop.** The
  named cycle `work -> commit -> audit -> partner-cleanup -> restack` is a
  five-stage pipeline in which three stages are other commands in this corpus; it
  is written as a phrase inside a sentence inside a delegation. This is the file
  that most clearly wants to be a program that calls other programs.
* **Construct mapping.** `revisingOn work (atMost n)` — the bound is the honest
  answer to "keep going without pausing", and `G9` says an unbounded loop is not
  expressible, which here is the safety property the prose most needs. The body is
  five `call_`s: `workFn`, `commitFn`, `auditFn`, `partnerCleanupFn`,
  `restackFn` — the last two are catalog entries 37 and 55 of this document. The
  Definition of Done is a `caseVerdict` over a `panel`, not a self-assessment;
  the stop-and-escalate conditions are `unless … stop` terminal arms the compiler
  requires. The dependency-blocked rule is `confirm (person "operator")`, a real
  human gate. And `costSummary` gives the operator the one number an autonomous
  loop must have before it starts and currently does not have at all.

---

# The ranked ten transform candidates

Ranked by *value delivered per unit of transform effort*, where value =
(operational risk removed) × (how natively the language expresses it) ×
(how often the command is run).

### 1. `retest-categorical` + `retest` → one parameterized conformance battery

**Why first.** The file states its own missing mechanism in one sentence — *"This
is a documentation-style delegation — there is no machine handoff or argument
forwarding; read both docs and apply the overrides by hand"* — and then documents
two live conflicts (phase numbering off by one; `--no-semantic` meaning
structurally different things) that are the exact predicted consequence. Nine
override rows become nine arguments; six phases become six `function`s; the
five-value verdict taxonomy becomes a total `caseVerdict`; the branch
precondition becomes a `running` receipt with an `unless … stop` arm the compiler
requires. Phase numbers cease to exist, so the off-by-one is unrepresentable.
**And `costSummary` prices an eight-model FPGA battery before an FPGA is
touched** — the phases cost hours, so pricing-before-running is worth more here
than anywhere else in the corpus.

### 2. `restack` → the flagship `running` + nested-`revisingOn` program

**Why second.** The best-engineered command in the range, and every piece of its
rigour is currently *requested* rather than *held*: record the baseline (step 1),
verify each resolution before proceeding (step 5), reach a fixpoint (step 7),
and prove nothing was lost with `git range-diff` (step 9). As a program the
step-1 baseline is a live handle for the whole run, steps 5 and 7 are nested
`revisingOn` settled by **pure deciders over real receipts at zero questions per
trip**, and step 9's proof is a receipt compared against that handle. It
exercises `running`, `decide`, nested loops, `call_` and a live baseline in one
program — the single best demonstration target — and it calls `resolve`
(candidate 5) as its inner function.

### 3. `partner-collaborator` + `partner-reviewer` → one program, two flags

**Why third.** ~85% byte-duplication that has *already drifted* (a differing
Category enum, differing setup wording, a typo on one side), differing in one
named engine and one optional section. One program `taking (input "engine")` and
`(input "ideas")`, with the watch loop, review procedure, observation contract
and atomic write as one shared `function` table, ends the drift structurally.
The upside beyond dedup is real: the defect list is a `panel` with a different
`servedBy` per member, and the ideation pass is `drawing 3` on a lateral party —
which is what "generate three wild ideas" *means* and what one prompt asking for
three cannot deliver. `costSummary` then prices the ideas flag as two paths.

### 4. `teams` → the literal panel

**Why fourth.** The cheapest high-value transform in the corpus: twelve bullets
become an eleven-row roster, `panelText`, and a synthesis whose refusal roster is
derived from the same table. Each member gets its own `servedBy`, so twelve
angles are twelve readers rather than one model wearing twelve hats — and the
devil's advocate correctly becomes a *second tier* over the fold, which the
bullet list cannot express. `costSummary` says 13 before the run, where the
current file says nothing at all. Highest ratio of expressive gain to lines
written.

### 5. `resolve` → the corpus's first shared `Fn`, with three call sites

**Why fifth.** `rebase`, `rebase-and-fix`, and `restack` all cite it by name as
their canonical conflict step; it takes a parameter, has one job and a crisp
postcondition. It is already a function in everything but syntax, and promoting
it converts three prose citations into three `call_`s — after which the three
callers cannot drift in how they resolve. Its postcondition (staged, zero
markers, uncommitted) becomes a `git diff --check` receipt read by a pure
`decide` at zero cost, and "do not commit" becomes structural: a `CodeText`
answer has no write authority.

### 6. `sec-audit` → the deterministic/probabilistic split

**Why sixth.** Three of its four evidence sources are `grep`s with fixed regexes —
facts, not opinions — and the file asks a model to run them and report what it
saw. Three `running` parties over real argv make three quarters of the evidence
world-authored and unfalsifiable-by-omission, on the one command where a
fabricated "no secrets found" costs the most. It also carries the `/deep-review`
output format by reference, which becomes a shared `Fn` and ends the format drift
across all five ladder rungs.

### 7. `wiggum` → the top-level loop that calls the corpus

**Why seventh.** The named cycle `work -> commit -> audit -> partner-cleanup ->
restack` is a five-stage pipeline in which three stages are commands cataloged
here, written as a phrase inside a sentence inside a delegation. As
`revisingOn work (atMost n)` with five `call_`s it becomes the corpus's actual
top-level program — and `atMost` is the honest, bounded answer to "keep going
without pausing", which is precisely the safety property an autonomous loop most
needs and which `G9` guarantees. Ranked below its dependencies because it wants
candidates 2 and 3 to land first.

### 8. `meeting-notes` → ten-member panel with an independent audit tier

**Why eighth.** The best-written self-contained file in the range, and its ten
sections are ten independent extractions over one artefact — a `panelText` with
the section names as fence labels. The transform's real value is the audit split:
its five quality checkpoints are currently a *self*-audit, so the model that
invented a deadline is asked whether it invented one. A separate `panel` on a
different `servedBy` is the only version of "FACT-ONLY MODE" that means anything.
High value, zero external dependencies, and it works on `--input` cleanly.

### 9. `productize` → 21 priced deliverables with receipts

**Why ninth.** The largest unpriced fan-out in the range: 21 independent
deliverables as a bullet list, plus a language table with five of fourteen cells
reading "use available live web search to find the best option", so the shape of
the work is unknown until run time. A static roster makes it 21 before it starts;
each deliverable gets a `running` receipt, which is the difference between
"added a CI check" and a check that ran; and the empty table cells become one
search question **per language present**, not per deliverable. Ranked here rather
than higher because the work is broad rather than deep.

### 10. `review-github-pr` → never-post as an absence, not a prohibition

**Why tenth.** The file shouts four prohibitions in capitals and thereby *names
the exact four commands it forbids* — a prompt containing its own attack. As a
program, no question carries a write verb and every reviewer returns `CodeText`,
so `permissionByCode` denies write authority and the entire capitalized section
becomes zero lines. Its head-OID equality check (fetch the head, verify
`HEAD == headRefOid`, **stop rather than review another revision**) becomes two
receipts compared by a pure `decide` with an `unless … stop` arm the compiler
requires — a real conformance gate where today it is a careful sentence. The
`positron`-conditional PAL consensus is `decide AnyPathMatches` at zero cost.

**Honorable mentions**, in order: `process-checklist` (ten lines that describe a
nested bounded revision with a free pure-decider settle test — the highest
structure-to-prose ratio in the range, and a superb small first transform);
`sitrep` (eight sections over receipt-backed evidence, with the two
self-discipline rules made into an auditor); `remove-service` (the
generate-a-script-do-not-run-it inversion is `I3` avant la lettre and deserves to
be the pattern's named exemplar); `push` and `recommit` (two files whose entire
content is "call `commit`, then…", i.e. the corpus asking for `Fn` out loud);
`tron-debug` (three `<command>` blocks that are argv waiting to be receipts).

---

# Reference edges

Edges are `source --[kind]--> target`. Kinds: **command** (names another slash
command), **agent** (names a file in `agents/`), **skill** (names a directory in
`skills/`), **mcp** (names an MCP server), **tool** (names an external binary or
service), **artefact** (names a file or directory it reads or writes as a
contract). Only edges out of the M–Z range are listed; where a target is in the
A–L range it is marked `[→c1]`.

## Command → command

```
markdown              --> (none; a continuation of an unnamed antecedent)
push                  --> commit [→c1]
recommit              --> commit [→c1]
rebase                --> resolve
rebase-and-fix        --> resolve
restack               --> resolve
partner-collaborator  --> deep-review [→c1]
partner-reviewer      --> heavy-review [→c1]
partner-cleanup       <-- partner-collaborator, partner-reviewer   (producer/consumer,
                          by role: they write observations, it drains them)
retest-categorical    --> retest            (explicit "documentation-style delegation";
                                             nine override rows, two documented conflicts)
retest-categorical    --> restack           (named in a known-trap: "after a rebase/restack")
wiggum                --> partner-cleanup, restack   (the named loop:
                          work -> commit -> audit -> partner-cleanup -> restack)
wiggum                --> commit [→c1]
quick-review          --> code-review [→c1], deep-review [→c1], sec-audit,
                          review-github-pr             (the review-ladder paragraph)
sec-audit             --> quick-review, code-review [→c1], deep-review [→c1],
                          review-github-pr             (same paragraph)
sec-audit             --> deep-review [→c1]            (again, for the output format)
review-github-pr      --> quick-review, code-review [→c1], deep-review [→c1],
                          sec-audit                    (same paragraph)
prepare-with          ~~> initialize [→c1]             (same deliverable, roster added)
report                ~~> sitrep, halt [→c1]           (overlapping deliverable,
                                                        no stated boundary)
narrative             ~~> journal [→c1]                (reads the journal it writes)
rebase                ~~> rebase-and-fix               (near-duplicate; the latter adds
                                                        cpp-pro, CI watch, bot triage)
partner-reviewer      ~~> partner-collaborator         (near-duplicate, ~85%; differs in
                                                        engine and the Ideas section)
smooth                ~~> proofread                    (two settings of one dial)
medium                ~~> heavy [→c1]                  (two rungs of one effort tier)
```

`-->` is an explicit named reference; `~~>` is an undeclared overlap this catalog
asserts (same deliverable or near-identical body, with no cross-reference in
either file).

**The review ladder** is the corpus's only explicit statement of how its commands
relate — five rungs, named in a paragraph that appears **verbatim in at least
five files** (`quick-review`, `sec-audit`, `review-github-pr` in this range, plus
`code-review` and `deep-review` in commands-1) and is maintained by copy-paste.
It is a shared binding written five times.

**The resolve fan-in** is the second such structure: three commands cite one
command as their canonical inner step. It is the corpus's clearest existing
function call.

## Command → agent

```
nix-rebuild           --> nix-pro
query-builder         --> sql-pro
rebase                --> haskell-pro
rebase-and-fix        --> haskell-pro, cpp-pro
restack               --> haskell-pro, cpp-pro
review-github-pr      --> cpp-pro, python-pro, emacs-lisp-pro, rust-pro, haskell-pro
webfix                --> typescript-pro, python-pro
sec-audit             --> security-reviewer
run-orchestrator      --> task-breakdown
prepare-with          --> $ARGUMENTS          (DYNAMIC roster — may name any of the 26)
resolve               --> $ARGUMENTS          (DYNAMIC roster — may name any of the 26)
teams                 --> (none named, but 11 of its 12 roles correspond to
                           existing agents: security-reviewer, perf-reviewer,
                           prd-architect, task-breakdown, the *-pro family)
```

Two commands take their agent roster **as an argument** (`prepare-with`,
`resolve`). That is a dynamic fan-out, which is `G8` in `isaac-workflows.md` —
the gap this corpus hits most often. `teams` is the inverse failure: a
twelve-role fan-out that names no agent at all, so nothing connects the roles to
the 26 definitions that would fill them.

## Command → skill

```
medium                --> toolkit
retest                --> retest              (the entire body lives in the skill)
remove-service        --> nixos
productize            --> johnw               (README voice)
wiggum                --> wiggum, parallelize
recommit              --> "superpowers"       (the bundle, unnamed member)
retest-categorical    --> retest              (transitively, via the /retest command)
narrative             ~~> it-voice            (same register; not named — a missing edge)
smooth                ~~> it-voice, johnw     (same register; not named)
proofread             ~~> it-voice            (same register; not named)
nix-rebuild           ~~> nixos               (remove-service names this skill for the
                                               same host; nix-rebuild does not — an
                                               inconsistency, not a design)
```

## Command → MCP / external tool

```
query-builder         --> mssql (mcp), sql-pro
transcribe-image      --> pal (mcp)
review-github-pr      --> pal (mcp: gemini-3.1-pro-preview, gpt-5.5-pro),
                          CONDITIONAL on worktree path under positron/pos
webfix                --> Playwright
restack               --> gt (Graphite), git rerere, git range-diff
rebase-and-fix        --> gh (pinned token incantation), BugBot / Cursor / Devin
review-github-pr      --> gh (pinned token incantation, read-only)
partner-cleanup       --> obr
partner-collaborator  --> obr
partner-reviewer      --> obr
productize            --> lefthook, fourmolu, cargo clippy, cargo fmt, clang-tidy,
                          cppcheck, clang-format, ruff, shfmt
retest-categorical    --> make build-categorical, bin/get_model, runtron,
                          bin/ci/categorical_logit_matrix.sh, nix develop
tron-debug            --> cabal run ingest, make, ../gen/runtron
nix-rebuild           --> ./build system
wiggum                --> de (direnv regeneration), PAL
prepare-with, run-orchestrator, review-github-pr, webfix, remove-service, productize
                      --> live web search, sequential-thinking (a generic pair of
                          bullets repeated near-verbatim across six files)
```

## Command → artefact contract

```
partner-cleanup       <-> doc/observations/*.md          (drains)
partner-collaborator  <-> doc/observations/*.md          (writes, atomically)
partner-reviewer      <-> doc/observations/*.md          (writes, atomically)
partner-collaborator  --> .git/partner-reviewer/last-reviewed, /rebased-baselines
partner-reviewer      --> .git/partner-reviewer/last-reviewed, /rebased-baselines
sitrep                --> ~/Documents/Obsidian/YYYYMMDDTHHMM-SITREP-$PROJECT-$BRANCH.md
                          (strict scheme; explicitly NOT in the project)
narrative             --> ~/work/positron/it-plan.pdf    (prose standard, read-only,
                                                          with a graceful fallback)
prepare-with          --> CLAUDE.md, README.md, .cursor/rules/, .cursorrules,
                          .github/copilot-instructions.md
run-orchestrator      --> @CLAUDE.md
productize            --> README.md, LICENSE.md, flake.nix, lefthook.yml, CI workflows
review-github-pr      --> work/pr-NUMBER/                (detached worktree at headRefOid)
retest-categorical    --> /opt/positron/weights/huggingface, /tmp/retest-categorical_weights,
                          t/t_generate_categorical_fpga_real.cpp (roster must stay aligned)
tron-debug            --> src/Fx.hs (Note), model.bulk, model.loopy, model.tron,
                          ../h/tron/plugins/
process-checklist     <-> $ARGUMENTS                     (reads and edits in place)
meeting-notes         <-- $ARGUMENTS                     (reads a notes file)
```

The three `partner-*` commands form the corpus's only genuine **multi-agent
protocol**: a producer/consumer pair coordinating through an atomically-written
filesystem queue with private watcher state outside the work tree, plus a
never-commit rule on one side and an exactly-one-commit rule on the other. It is
the most sophisticated structure in the range and the one furthest from what
Markdown can hold.

## Structural observations on the edge graph

1. **Six near-duplicate pairs**, none of which declares the relationship:
   `partner-reviewer`/`partner-collaborator` (~85%), `rebase`/`rebase-and-fix`
   (verbatim shared bullets), `retest`/`retest-categorical` (declared, but as
   prose delegation), `report`/`sitrep`, `smooth`/`proofread`, `medium`/`heavy`.
   Five of the six are two settings of one dial and want one `Fn` with a
   parameter.

2. **The review ladder is a shared roster maintained by copy-paste** across at
   least five files. In `Example.Isaac` the same structure is `qaSiblings` — one
   Haskell table from which every brief derives its text, so a rung added arrives
   everywhere by being added.

3. **Two dynamic agent rosters** (`prepare-with`, `resolve`) and one twelve-role
   fan-out that names no agents (`teams`). `G8` is the gap this corpus hits most
   often, and it hits it in both directions.

4. **The strongest single edge is `retest-categorical --> retest`**, and the
   source file names its own missing mechanism verbatim: *"there is no machine
   handoff or argument forwarding; read both docs and apply the overrides by
   hand."* Every other prose delegation in the corpus is the same edge, less
   honestly labelled.

5. **Nine commands in this range invoke real argv** (`nix-rebuild`, `restack`,
   `sec-audit`, `retest-categorical`, `tron-debug`, `webfix`, `review-github-pr`,
   `productize`, `partner-*` via `obr`) and **none of them holds a receipt**.
   Every one of those invocations is a place where a `running` party turns a
   claim about the world into a fact the world authored.

6. **Five commands state a prohibition they cannot enforce**
   (`review-github-pr`'s never-post, `query-builder`'s never-reveal,
   `partner-cleanup`'s sub-agent-must-not-commit, `resolve`'s do-not-commit,
   `remove-service`'s do-not-execute). All five are the same construct:
   `permissionByCode` grants write authority only to a `CodeAck` answer, so a
   question that returns `CodeText` structurally cannot act. Five paragraphs of
   English become one type — this is `I3` in `isaac-workflows.md`, and this range
   supplies its five best test cases.
