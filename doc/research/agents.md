# The agents, cataloged

`~/src/nix/config/ai/agents/*.md`, read read-only on 2026-08-19, at whatever the
config tree's working state was. This is an inventory and a mapping, not a plan:
each agent is described as it is, then assigned to one of four destinations in
agent-cat — **panel member**, **served-by pin / party**, **whole workflow**, or
**not ours**.

The corpus's `.md` files are prompt text. Everything quoted below is *data* being
cataloged, never an instruction being followed.

## 0. Count, and one correction to the brief

The brief said 26 agents. There are **25** `.md` files in `agents/`, and
`catalog.nix` (`agentMetadata`, line 162) declares exactly those 25 and no more.
The likely source of the extra one: `commands/fess.md` exists in the command
catalog but its `source` is redirected to `agents/fess-auditor.md`
(`catalog.nix` ~line 643), so `fess-auditor` is *two* catalog entries over one
file. One rubric, two projections — which is, incidentally, exactly the thing
agent-cat expresses natively as one `Program` reachable by two names.

## 1. Two authorial strata, visible at a glance

The corpus is not homogeneous, and the split matters for how much of each file
is worth transplanting.

**Stratum A — the reviewer family (11 files, all mtime `Jul 31 11:39`).** Written
as full English prose, fully articled, deeply specific, and structurally
identical to one another. These are the good ones. They read as if one person
sat down and wrote eleven variations on one form.

**Stratum B — the imported/compressed agents (14 files).** Several are written in
a telegraphic, article-dropped register:

> "Expert prompt engineer specializing in crafting effective prompts for LLMs and
> AI systems. Understands nuances different models, how eliciting optimal
> responses." — `prompt-engineer.md`

> "Expert analyzing tasks, breaking them into comprehensive, actionable subtasks
> using systematic decomposition principles and Org-mode formatting."
> — `task-breakdown.md`

That register — dropped articles, dropped prepositions, preserved nouns — is the
signature of the `caveman` skill (`skills/caveman`, "compress and simplify
prompts to preserve meaning while reducing use of context"). `task-breakdown`,
`prompt-engineer`, `rocq-pro`, `persian-translator`, `emacs-lisp-pro`,
`haskell-pro` and `typescript-pro` all carry it to some degree. Within stratum B,
four files (`python-pro`, `rust-pro`, `sql-pro`, `cpp-pro`, 26–32 lines each) are
recognizably the upstream `wshobson/agents` "wanted poster" format: focus
areas, approach, output, one closing aphorism. They carry no rubric.

The practical consequence: **stratum A has content worth moving into agent-cat
almost verbatim; stratum B mostly has *addressees* and *shapes*, not content.**

## 2. The families

| Family | Members | What binds them |
|---|---|---|
| **F1. Language reviewers** | `python-reviewer`, `typescript-reviewer`, `rust-reviewer`, `haskell-reviewer`, `cpp-reviewer`, `nix-reviewer`, `coq-reviewer`, `elisp-reviewer`, `bash-reviewer` | One rubric per language, severity-tiered sections, an optional tool-integration block, an identical finding schema. Selected by file extension. |
| **F2. Cross-cutting reviewers** | `security-reviewer`, `perf-reviewer` | Same form as F1, but language-agnostic and run over the *whole* changeset. Both raise the confidence floor on their own findings. |
| **F3. Language authors ("-pro")** | `haskell-pro`, `typescript-pro`, `emacs-lisp-pro`, `nix-pro`, `rocq-pro`, `cpp-pro`, `python-pro`, `rust-pro`, `sql-pro` | Not judges — *writers*. Reference material plus a house style. Two sub-strata: four encyclopedias (haskell 994 lines, emacs-lisp 258, typescript 249, nix 134, rocq 101) and four wanted posters (26–32 lines). |
| **F4. Producers of structured documents** | `task-breakdown`, `prd-architect`, `persian-translator`, `prompt-engineer` | Take an input artefact, emit a *specified* output artefact in a named format. Each has a real procedure and, in two cases, a real loop. |
| **F5. The auditor** | `fess-auditor` | Alone in its family. An adversarial self-audit rubric with ten named sin categories, an independence attestation protocol, and a fixed five-section report. |

F1 and F2 together are the **panel family**, and are 11 of the 25.

## 3. The reviewer family, read closely

This is the most valuable finding in the catalog, so it gets its own section.

### 3.1 The shared form

Every one of the eleven files has this skeleton:

```
# <Language> Code Reviewer
You are a senior <role> performing a focused <kind> review. You have deep
expertise in <three or four named areas>.

## Your review priorities (in order)
### 1. <Category> (CRITICAL)
- bullet … bullet
### 2. <Category> (CRITICAL|HIGH)
…
### N. <Category> (LOW)

## Tool integration          ← 7 of 11 have this
<fenced shell commands>
"Incorporate tool output but apply judgment."

## Output format
"If the invoking prompt specifies a findings format, use that. Otherwise …"
<the finding schema>
```

**The finding schema is duplicated eleven times, and I diffed it.** Taking
`bash-reviewer`'s `## Output format` section as the baseline:

- `coq`, `elisp`, `haskell`, `nix`, `python`, `rust` — **byte-identical**.
- `cpp`, `typescript` — identical **plus one line**: "If the code looks sound,
  say so."
- `security` — identical except the closing sentence, which raises the floor to
  confidence ≥ 85 and drops the "file path, line range" requirement.
- `perf` — identical except the closing sentence, which sets ≥ 80 and demands a
  concrete Impact line.

So the corpus already *is* one define spliced eleven times; it just has no way to
say so, and pays for that in eleven copies that can drift. **One has already
drifted, in the consumer rather than the agent:** `commands/deep-review.md`
Step 3 prints a finding format whose Category vocabulary is

> `Bug | Security | Performance | Simplification | Dead Code | Style | Convention | Edge Case | Documentation | Test Coverage`

with **`Simplification` and `Dead Code` added**, while every agent file's own
default omits both. The agents' escape hatch ("if the invoking prompt specifies
a findings format, use that") papers over it, but the two vocabularies are two
objects and only one of them is in the agents directory. In agent-cat this is a
single `findingSchema` define holed into eleven prompts; drift becomes
impossible rather than merely unlikely.

### 3.2 Severity is static, not judged

Each rubric section header carries its own severity in parentheses —
`### 1. Unsafe code audit (CRITICAL)`, `### 5. Performance (MEDIUM)`. Severity is
therefore a property of *which section a finding falls under*, decided by the
author when the file was written, not by the model at review time. That is a
fact about the text that no one has exploited: it means the rubric could be
sliced per severity tier and priced per tier, and it means a "CRITICAL" claim
that does not trace to a CRITICAL section is a category error the program can
name.

Section counts (the natural stance-granularity if one ever wants to split a
reviewer into sub-stances):

| Reviewer | Sections | Severity-1 category | Tool block |
|---|---:|---|---|
| `python-reviewer` | 6 | Security | `ruff`, `mypy`, `bandit` |
| `typescript-reviewer` | 7 | Type safety | `tsc`, `eslint`, `npx` fallbacks |
| `rust-reviewer` | 7 | Unsafe code audit | `cargo clippy`, `cargo audit` |
| `haskell-reviewer` | 6 | Partial functions | `hlint --json` |
| `cpp-reviewer` | 6 | Memory safety | `clang-tidy`, `cppcheck` |
| `nix-reviewer` | 7 | Reproducibility violations | `statix`, `deadnix`, `nix flake check` |
| `coq-reviewer` | 6 + anti-patterns | Proof soundness | — (but names `Print Assumptions`) |
| `elisp-reviewer` | 7 | Lexical binding | — |
| `bash-reviewer` | 6 | Quoting and word splitting | `shellcheck -f json` |
| `security-reviewer` | 7 + Methodology | Secrets and credentials | — |
| `perf-reviewer` | 5 | Algorithmic complexity | — |

≈ 71 rubric sections across the family. Every one is a paragraph of genuinely
domain-specific knowledge; none is filler.

### 3.3 Quality read

**These are good.** Not generically good — specifically good, in ways that show
the author checked the claims:

- `typescript-reviewer`'s prototype-pollution bullet volunteers the *exception*
  ("Object spread and `Object.assign` onto a fresh object only copy own
  properties and are safe"), which is the sentence a reviewer writes only after
  being wrong about it once.
- `haskell-reviewer` on `Writer`: "`Writer.Strict` still leaks — it is strict in
  the pair, not in the accumulated log." Correct, and the sort of thing generic
  rubrics get backwards.
- `bash-reviewer` on SC2181 explains *why* `$?` checking is wrong twice over
  (intervening commands reset it; `set -e` may exit first).
- `coq-reviewer` on universe constraints distinguishes parameters (left of colon,
  `≤`) from indices (right of colon, strict `<`). That is not lore, that is a
  mechanism.
- `nix-reviewer` leads with `/nix/store` being world-readable at 0444, which is
  the single most load-bearing Nix security fact.

Weaknesses, stated fairly:

1. **The tool blocks are wishes.** "If available, run: `ruff check <file>
   --output-format=json`" is a sentence addressed to a model that may run it, may
   claim to have run it, or may hallucinate its output. Nothing in the file makes
   the run observable, and nothing distinguishes "ruff was clean" from "ruff was
   absent". This is the largest single defect in the family and it is exactly
   `fess-auditor`'s own **fallback smuggling** and **verification gap** categories
   turned on the reviewers themselves.
2. **Four reviewers have no tool block at all** (`coq`, `elisp`, `security`,
   `perf`) even though `statix`-grade tools exist for two of them, and
   `reviewerCapabilities` in `catalog.nix` already grants all eleven
   `run-commands`. The capability is granted and unused.
3. **Confidence is self-reported.** Every finding carries a `Confidence: <0-100>`
   the *finding's own author* supplies, and `deep-review` Step 5 then filters on
   it. A reviewer that wants a finding kept simply writes 95. There is no
   independent hold on that number anywhere in the corpus.
4. **The dispatch decision is a paid model turn.** `deep-review` Step 2's
   extension→agent table is a pure function of the file list, and today a model
   reads the list and applies it.

### 3.4 What agent-cat does to each weakness

| Weakness | agent-cat mechanism |
|---|---|
| Tool blocks are wishes | `toolExec` — `tool "ruff" \`running\` ("ruff", ["check", "--output-format=json", …])`. The **world** authors the receipt by running the argv through `Agentic.Shell.proc`. A model cannot fabricate it and cannot silently skip it. `never sh -c` also removes the injection surface the un-quoted `<file>` placeholders currently invite. |
| Four reviewers have no tool block | Same mechanism, uniformly available; a missing tool is a receipt that says so rather than a silent absence. |
| Eleven copies of the finding schema | One `findingSchema :: Text` define, holed into eleven `[wf|{rubric}\n{findingSchema}\n{diff}|]` prompts. The two-line and one-sentence variants become two more defines, spliced where they belong. |
| Confidence filter | `panels` folding verdicts, and/or `containsLine` / `anyLineStartsWith` deciders over the reviewer's own output — **zero questions**, and the test cannot be chosen by the model being tested. |
| Dispatch is a paid turn | `anyPathMatches ["*.hs", "*.lhs"]` etc. — nine deciders, **zero questions**, and the routing is visible in `plan --raw` before anything runs. |
| Unknown cost until it runs | `cost` / `costSummary` gives min / max / path count *before* the first token is spent. `deep-review` today cannot say what a mixed-language review will cost. |
| Read-only is a promise | It is structural in agent-cat: a reviewer is read-only *because it does not `act`*. `reviewerCapabilities` grants `run-commands` to all eleven and relies on the prose "These are mandatory review lenses, not permission to mutate the changeset" to hold the line. |

Design arithmetic for the obvious first program (an estimate from the shape, not
a measurement — nothing has been built yet): nine gated language reviewers +
`security` + `perf` + one synthesis fold ⇒ `askNodes` ≈ 12, `costSummary`
somewhere near **1 .. 12** with the language gates contributing paths but no
questions. The point is not the numbers; it is that they exist before the run.

## 4. The other fourteen, per agent

### F3 — the "-pro" language authors

**These are parties, not programs.** A `-pro` agent answers the question "who
should write this?", and agent-cat already has a word for that: the addressee on
an `ask`, optionally pinned with `` `servedBy` `` and given alternates with
`` `fallingBackTo` ``. None of the nine contains control flow, a gate, a loop, or
an output contract worth expressing as a program.

| Agent | Lines | Role | Named references | Quality | Destination |
|---|---:|---|---|---|---|
| `haskell-pro` | 994 | Type-level programming, space-leak diagnosis, Cabal/Stack/Nix, concurrency, web/db/parsing/crypto ecosystems, DDD-in-Haskell, debugging methodology. 45 subsections. | named by `fix`, `assess`, `rebase-and-fix`, `review-github-pr`, `rebase`, `restack`, `skills/toolkit` | An encyclopedia, not an agent. Genuinely deep (the `Writer`/`Accum`, `Map.Lazy`, INLINE-vs-INLINABLE material is right) but 28 KB of it is loaded whether or not the task is about laziness. | **Party** + a *prompt library*: its section bodies are defines to splice on demand, not one blob to paste. |
| `typescript-pro` | 249 | Strict-mode type system, monorepo project references, Vitest coverage thresholds (90 %/99 %), JSDoc visibility tags. | `webfix` | Solid, opinionated, but half of it is `tsconfig.json` / `vitest.config.ts` samples that belong in the repo, not in a prompt. | **Party**; extract the two config samples as defines. |
| `emacs-lisp-pro` | 258 | Lexical binding, package.el conventions, buffer/text manipulation, macro authoring. | `fix`, `fix-github-issue`, `review-github-pr`, `skills/toolkit` | Good and non-obvious ("Lexical binding provides 10-15% performance improvement"). Overlaps `elisp-reviewer` §1–2 almost exactly. | **Party**; note the overlap — the shared facts should be one define both use. |
| `nix-pro` | 134 | Declarative-first, module system, flakes, Home Manager, agenix/sops-nix, nix-darwin. Has a five-step **Search Strategy** ending "Never assume option exists without verification." | `fix-integration`, `nix-rebuild`, `skills/nixos` | The best of the "-pro" files, because the search strategy is a *procedure* with a verification gate. Names `sequential-thinking` MCP and live web search. | **Party** — but its Search Strategy is a small **workflow** in its own right: five ordered lookups with an existence check, which is `revisingOn` over a verification verdict. |
| `rocq-pro` | 101 | Proof strategy, tactic vocabulary in three tiers, `Qed`-over-`Admitted`, output template. | *nothing in the corpus names it* | Competent; caveman-compressed. Overlaps `coq-reviewer` from the producing side. Orphaned. | **Party**, low priority. |
| `cpp-pro` | 32 | Modern C++ wanted poster. | `fix`, `assess`, `fix-github-issue`, `rebase-and-fix`, `review-github-pr`, `restack`, `skills/toolkit` | Upstream stub. Six of its bullets are a strict subset of `cpp-reviewer`'s rubric. | **Party only.** Nothing to transplant. |
| `python-pro` | 26 | Python wanted poster. | `fix`, `fix-github-issue`, `review-github-pr`, `webfix`, `skills/toolkit` | Upstream stub. | **Party only.** |
| `rust-pro` | 29 | Rust wanted poster. | `fix`, `assess`, `flaky-rust`, `fix-github-issue`, `review-github-pr`, `skills/toolkit` | Upstream stub. | **Party only.** |
| `sql-pro` | 29 | SQL wanted poster; CTEs, EXPLAIN ANALYZE, index strategy. | `query-builder` | Upstream stub, but its *consumer* is interesting: `commands/query-builder.md` builds queries "from schema alone, never revealing any table data". That constraint is the program, not the agent. | **Party only**; the data-secrecy constraint belongs to the query-builder workflow. |

**The `-pro`/`-reviewer` overlap is a real duplication.** Six languages have both
(`cpp`, `haskell`, `nix`, `python`, `rust`, `typescript`, plus `elisp`/`emacs-lisp`
and `coq`/`rocq` under different spellings). In every case the reviewer's rubric
is the sharper document and the pro's overlapping bullets are a weaker paraphrase.
Same fact, two files, no link between them. One define, two consumers.

### F4 — producers of structured documents

| Agent | Lines | Role | Named references | Quality | Destination |
|---|---:|---|---|---|---|
| `task-breakdown` | 320 | Decompose one Org-mode `TODO` into an ordered set of subtasks. Five-dimension analysis framework, seven decomposition principles, nine subtask categories, strict Org formatting rules (heading depth = parent + 1, `:CREATED:` timestamp, fresh UUID per subtask, explicitly *not* copying `:LAST_REVIEW:`/`:NEXT_REVIEW:`/`:REVIEWS:`), a two-section output, a worked example, three special cases. | `run-orchestrator`; sibling command `commands/breakdown.md` | **The best-shaped file in stratum B.** It has a real analysis→decompose→format pipeline, a real completeness gate ("If all subtasks completed, will parent task fully done?"), and three named degenerate cases (atomic / ambiguous / out-of-domain) that are three *branches*. | **Whole workflow.** |
| `prd-architect` | 243 | Create/refine a Task Master PRD. Discovery questions → eight mandatory sections → three-step process (draft with `[TODO: User input needed]` → iterative per-section refinement → validation) → a separate feedback/analysis mode → a nine-item self-verification checklist. | `.taskmaster/templates/example_prd.txt`, `.taskmaster/docs/prd.txt`; nothing in the corpus names the agent | Ambitious and coherent, but **it is two agents in one file**: a generator and a critic, selected by an unstated condition ("When asked to provide feedback on an existing PRD"). Also tightly coupled to a third-party tool. | **Whole workflow — two of them**, split at the mode boundary. |
| `persian-translator` | 114 | English → Persian for the Bahá'í World Centre, in the register of Shoghi Effendi and the Universal House of Justice. Carries a **50-term controlled glossary**. Its procedure: translate, **back-translate to English, compare against the source, and re-translate until the meaning is preserved**. | `skills/persian/SKILL.md` (which describes "a team of specialist reviewers") | The glossary is the asset — 50 hand-fixed renderings that no model should be free to re-invent. The back-translation loop is stated but **unbounded and ungated**: "translate again refine until preserving beauty and intent". | **Whole workflow**, and the *cleanest* `revising` in the corpus: candidate = translation, review = back-translation + comparison, `atMost n`, `settle`/`amend`. The glossary is one define. |
| `prompt-engineer` | 105 | Craft and optimize prompts. Technique catalog (few-shot, CoT, ToT, self-consistency, chaining), model-specific notes, six-step process, a **mandatory output contract** ("ALWAYS display complete prompt text… Never describe prompt without showing it"), a four-box pre-completion checklist. | *nothing in the corpus names it* | Weakest file in stratum A/B alike. Caveman-damaged to the point of ungrammaticality; its own "Example Output" is a generic code-review prompt strictly worse than any of the eleven real reviewers sitting beside it in the same directory. Its one strong idea is the output contract, which is a **decider**, not a plea. | **Not ours** as written. The output contract survives as `containsLine`/`anyLineStartsWith` over a fence. |

### F5 — the auditor

`fess-auditor` (253 lines) is the most sophisticated file in the corpus and the
one whose *structure* most rewards agent-cat.

- **Role.** "Assume you've been dishonest about the work. Your job now is to find
  what you hid, glossed over, or quietly downgraded." Ten named sin categories,
  each with a stated *harm*, a *rule*, illustrative signals, and a per-category
  interrogative the auditor must answer.
- **The ten categories** — stubs and fakes; vacuous tests; mock and fixture
  drift; silent failure / error swallowing; suppressions; fallback smuggling;
  spec drift; scope creep; documentation drift; verification gap ("most
  important"); loose ends. (Eleven if loose ends counts separately.)
- **Named references.** Declares itself the single source for four renderers'
  `/fess` (`Claude Code`, `Codex $command-fess`, `Factory Droid`, `Pi`,
  `Prime Agent`); `catalog.nix` implements that by aliasing `commands/fess` to
  this file. Consumed by `skills/fix-all/README.md` and `skills/wiggum/SKILL.md`.
- **The independence protocol.** "For a delegated independence claim, the parent
  must name the explicit no-history mode it used and provide a passing
  parent-history sentinel probe. If that attestation is absent, run the audit but
  report that its independence was not verified." This is the most agent-cat-shaped
  paragraph in the whole corpus: it is a **gate whose failure downgrades rather
  than aborts** — `revisingOn` with an `abandon` that still yields, or a `case`
  whose second arm produces a labelled-unverified report.
- **Quality read.** Excellent — the anti-manufacturing guards are the tell
  ("don't resolve uncertainty by claiming 'none' and don't resolve it by
  manufacturing a sin"; "If you genuinely did clean work, the honest answer is a
  short report"). Three things it cannot do on its own: (a) the independence
  attestation is prose the parent may simply not supply; (b) the ten categories
  are asked as one turn, so one weak category is invisible; (c) it ends by
  demanding evidence — "Quote the command and the relevant output" — from an
  agent with no structural guarantee it ran anything.
- **Destination.** **Whole workflow**, whose *interior* is a panel. Ten stances,
  one `ask` each, folded by `panels`; the report's five fixed sections are
  `panelText` over a fenced document; the independence attestation is a
  `confirm`/decider before the panel rather than a sentence hoping to be read;
  and every "quote the command" demand becomes a `toolExec` receipt the world
  authored. This is the single highest-value conversion in the directory.

## 5. The mapping, as four columns

### Column 1 — panel members (one stance each)

Eleven, verbatim, plus ten more if `fess-auditor` is split.

`security-reviewer`, `perf-reviewer`, `haskell-reviewer`, `rust-reviewer`,
`cpp-reviewer`, `python-reviewer`, `typescript-reviewer`, `nix-reviewer`,
`bash-reviewer`, `elisp-reviewer`, `coq-reviewer`
— and, from `fess-auditor`: stubs, vacuous-tests, mock-drift, silent-failure,
suppressions, fallback-smuggling, spec-drift, scope-creep, doc-drift,
verification-gap.

### Column 2 — served-by pins / parties on asks

All nine `-pro` agents. A `-pro` agent's whole content is "who should answer
this and in what house style", which is `ask (model "haskell-pro")`, a
`` `servedBy` `` naming the engine, and `` `fallingBackTo` `` naming the
alternate. Their *reference material* becomes defines, spliced per question
rather than pasted per session.

Also, honestly: `security-reviewer` and `perf-reviewer` are *both* — panel
members in a review program, and the natural pin for a one-off "just check the
security of this" ask.

### Column 3 — whole workflows

`fess-auditor` (panel-of-ten inside a gated report), `task-breakdown`
(analysis → decomposition → format, with three degenerate branches),
`prd-architect` (**split into two**: `prd-draft` and `prd-critique`),
`persian-translator` (bounded `revising` over back-translation, with a glossary
define), and — smaller, but real — `nix-pro`'s five-step Search Strategy as a
verification-gated lookup.

### Column 4 — not ours (harness agents, left alone)

- `prompt-engineer` — no rubric worth moving; superseded in its own directory by
  the eleven reviewers. Keep as a harness agent; take only its output contract,
  as a decider, if some program needs one.
- `cpp-pro`, `python-pro`, `rust-pro`, `sql-pro` — upstream wanted posters. They
  are pins (column 2) and nothing else; there is no file content to transplant.
- `rocq-pro` — orphaned (nothing in the corpus names it) and duplicative of
  `coq-reviewer`. Leave until someone actually calls it.

This is the honest not-ours column: **six of twenty-five**, and four of those six
still serve as party names.

## 6. Panel candidates, ranked

Ranked by *value of conversion* = (quality of the rubric) × (how much the
conversion fixes) ÷ (how much has to be invented). Rank 1 is where to start.

| # | Candidate | Why it ranks here |
|---:|---|---|
| **1** | `security-reviewer` | Language-agnostic, so it is in **every** panel regardless of the changeset — the one member no gate ever excludes. Its rubric is the strongest cross-cutting one, its confidence floor (≥ 85) is already stated and is a decider waiting to be written, and its "Methodology" section (scan for secrets → identify trust boundaries → trace data flow → check crossings → review error paths) is a **five-step pipeline**, not a bullet list, so it is the one reviewer that is a program by itself. Isaac's `reviewer-secure`, essentially unchanged. |
| **2** | `perf-reviewer` | Same shape, same universality, second-strongest cross-cutting rubric. Its "Impact must be concrete (e.g. 'O(n²) where n can be 10k+')" is a checkable output contract. Pairs with #1 to give a two-member panel that runs on *anything* — which is the smallest useful program in the whole exercise. |
| **3** | `haskell-reviewer` | The house language: it is what agent-cat itself is written in, so it can be dogfooded against this very repository on day one. Rubric is the most technically precise in the family (the `Writer.Strict` and `Map.Lazy` items are correct where generic rubrics are not), and `hlint --json` is a clean, single-argv `toolExec`. |
| **4** | `rust-reviewer` | Best gate story in the family: "Every `unsafe` block MUST have a `// SAFETY:` comment" is *literally* `anyLineStartsWith ["unsafe "]` gating a paid `ask`, and `cargo clippy … -D warnings` is a `toolExec` whose exit is meaningful. The highest ratio of rubric-that-becomes-free-deciders. |
| **5** | `nix-reviewer` | Reviews the corpus's own habitat, and its CRITICAL-1 (`<nixpkgs>` lookups, missing `flake.lock`, IFD) and CRITICAL-2 (`/nix/store` world-readable ⇒ no secrets) are exactly the checks the owner runs against `~/src/nix` constantly. Three tools (`statix`, `deadnix`, `nix flake check --no-build`) that are cheap and decisive. |
| **6** | `bash-reviewer` | Densest tool integration in the family — ShellCheck's ~200 rules with the file itself calling them "authoritative" — so it converts to *mostly* `toolExec` plus a thin judgment ask. Also the cheapest thing to demonstrate: one `proc`, one receipt, one fold. |
| **7** | `python-reviewer` | Three tools (`ruff`, `mypy`, `bandit`) and a rubric whose §2 (mutable defaults, late-binding closures, bare `except:`) is genuinely bug-finding rather than style. Ranks below #6 only because the tools overlap each other and the fold is fussier. |
| **8** | `typescript-reviewer` | Longest and most careful rubric (150 lines, 7 sections, the prototype-pollution nuance). Ranks here rather than higher because `tsc`/`eslint` invocation is project-shaped (`npx` fallbacks, monorepo project references) and the argv is not a constant — which is honest work, not a blocker. |
| **9** | `cpp-reviewer` | Strong rubric (memory safety, UB, concurrency). `clang-tidy` needs a compilation database to say anything true, so the `toolExec` has a real precondition the program must express — valuable as the case that *forces* a gate, less valuable as a first conversion. |
| **10** | `elisp-reviewer` | Sharp, specific, and its CRITICAL-1 (`;;; -*- lexical-binding: t; -*-` must be line 1) is the purest decider in the corpus — one `anyLineStartsWith` over the head of the file, zero questions, a whole CRITICAL category answered for free. Ranks tenth only because it has no tool block and a narrow blast radius. |
| **11** | `coq-reviewer` | Best *idea* of the eleven — "Run `Print Assumptions` on key definitions; the output must list only intended axioms" is a `toolExec` whose receipt is a soundness proof obligation, and `Admitted` is a `containsLine` gate. Ranks last of the eleven purely on frequency of use, not on quality; on quality it would be top three. |
| **12** | *(the ten `fess-auditor` stances)* | Ranked as one entry because they arrive together. Individually the top three would be **verification-gap** (the file itself calls it "most important", and it is precisely the thing `toolExec` receipts make honest), **fallback smuggling** (high-severity, and the only category with a stated primary-path-was-it-actually-exercised question), and **vacuous tests** (has the sharpest single test in the corpus: "would this test still pass if the function under test were replaced with a stub that returns a mock of the right shape?"). |

**Not panel candidates, and why:** the nine `-pro` agents (writers, not judges —
a panel of authors has no verdict to fold), `task-breakdown` and `prd-architect`
(producers with a single output artefact — one ask, not a stance), and
`prompt-engineer` (no rubric). `persian-translator` is not a panel *member* but
its consuming skill already claims "a team of specialist reviewers", so a panel
over the glossary, the register, and the back-translation is a defensible fourth
workflow — flagged, not asserted.

## 7. Three conversions that would not be visible without agent-cat

Stated as candidates, not as commitments.

1. **The extension→agent table becomes free.** `deep-review` Step 2 is nine rows
   of pure function from a file list to a set of reviewers, executed today by a
   model. Nine `anyPathMatches` deciders cost **zero questions**, appear in
   `plan --raw` before the run, and make the panel's membership a property of the
   diff rather than of a model's attention. It also fixes the table's silent
   hole: `.lean`, `.go`, `.java`, `.rb`, `.swift` and `.ml` fall through to
   "general-purpose", which today is invisible and would become a written arm.

2. **"If available, run X" becomes a receipt the world authored.** Every one of
   the seven tool blocks currently trusts the reviewer to run a command and
   report honestly on it. Under `toolExec` the argv is program-authored, `proc`
   runs it (never `sh -c`, so the `<file>` placeholders stop being an injection
   surface), and the receipt is not something the answering model can write. This
   turns `fess-auditor`'s own "verification gap" category from a question the
   auditor asks into a structural property of the program the auditor audits.

3. **The review gets a price before it runs.** No file in the corpus can say what
   a review costs. `cost` and `costSummary` give min / max / path count from the
   program text, so a mixed-language changeset can be priced, compared against a
   cheaper single-stance variant, and chosen between — before the first token.
   That is the improvement an operator feels first, and it is the same one
   `doc/research/isaac-workflows.md` §5 (I1) records against incite.

## 8. Loose ends worth someone's attention

- `rocq-pro` and `prompt-engineer` and `prd-architect` are named by **nothing**
  in `commands/`, `skills/`, `prompts/` or `agents/`. Three of twenty-five are
  orphans.
- `deep-review`'s finding-format Category vocabulary and the agents' own differ
  by two entries (§3.1). Which is authoritative is undecided.
- `elisp-reviewer` / `emacs-lisp-pro` and `coq-reviewer` / `rocq-pro` are the
  same language under two spellings, and the `deep-review` table maps `.el` and
  `.v` to the reviewer spelling only.
- `catalog.nix` grants `run-commands` to all eleven reviewers
  (`reviewerCapabilities`) and four of them never run one.
- The finding schema exists in eleven copies; nine are byte-identical.
