-- |
-- Module      : Workflows.DeadCode
-- Description : The dead-code pass — four phases that cannot interleave, and a
--               debate that cannot be won on a majority.
--
-- == The map: old Markdown -> new program
--
-- +------------------------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                      | here                                                      |
-- +================================================+===========================================================+
-- | @skills\/eliminate-dead-code\/SKILL.md@        | @dead-code@ — the four-phase workflow as four segments of |
-- |                                                | one @W.do@ block, and the nine operating principles as    |
-- |                                                | 'operatingPrinciples'                                     |
-- +------------------------------------------------+-----------------------------------------------------------+
-- | its @references\/phases.md@ 1.0–1.7            | 'discoveryBrief', 'allowlistBrief', 'markBrief' — and its |
-- |                                                | two hard gates as a free decider and an exit code         |
-- +------------------------------------------------+-----------------------------------------------------------+
-- | its @references\/phases.md@ Phase 2            | 'debateRoster' — three advocates, folded to a __verdict__ |
-- +------------------------------------------------+-----------------------------------------------------------+
-- | its @references\/phases.md@ Phase 3–4          | 'actBrief', the repair gate, and                          |
-- |                                                | @'Workflows.Evidence.dceMarkers'@                         |
-- +------------------------------------------------+-----------------------------------------------------------+
-- | its @references\/gates-and-report.md@          | 'deadCodeReportBrief' (the template), 'approvalGates'     |
-- |                                                | (the ten pause conditions), 'neverDo' (the prohibitions)  |
-- +------------------------------------------------+-----------------------------------------------------------+
-- | @commands\/eliminate-dead-code.md@             | the row itself; the command is five lines and its own     |
-- |                                                | text says the machinery is the skill's                    |
-- +------------------------------------------------+-----------------------------------------------------------+
-- | @agents\/{haskell,python,rust,…}-reviewer.md@  | @'Workflows.Rubrics.Reviewers.langTools'@ — the static    |
-- | @## Tool integration@                          | analysis of phase 1.3, as receipts                        |
-- +------------------------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The two hard gates are the run's first two statements, and neither is a
--      plea.__ @phases.md@ 1.2 opens with \"working tree must be clean … if there
--      are uncommitted changes, __abort__\" and closes with \"if any of build \/
--      tests \/ lint fails __before any change is made__, __abort the run__\".
--      Here the first is @'Workflows.Deciders.treeDirty'@ over a
--      @git status --porcelain@ receipt — zero questions — and the second is
--      @'Workflows.Gates.passes'@ over the repository's own test command, which
--      is an exit code. Both have an arm, and the arm reports and stops. The
--      sentence the skill wrote in bold is now the only path the program has.
--
--   2. __\"Do not interleave the phases\" stops being an instruction.__ MARK's
--      act, DEBATE's panel, ACT's gate and VERIFY's sweep are binds in one
--      block, each reading the handle the last one bound. There is no order in
--      which they could run but this one, and no way to write a run that skips
--      one — which is @SKILL.md@'s \"run in four phases, do not interleave
--      them\" made unstatable-otherwise.
--
--   3. __The safety-biased rubric is the verdict monoid.__ @phases.md@ 2.C is
--      emphatic — \"decide __one__ verdict per region using a safety-biased
--      rubric __-- this is not a majority vote__\" — and then asks a model to
--      hold three arguments in mind and be conservative. Here the three
--      advocates are a @'Agentic.Workflow.panel'@, which folds right in the
--      noncommutative verdict monoid where __every member must approve__: the
--      keep advocate objecting is what makes the verdict @keep@, and no
--      arithmetic over three opinions can override it. \"Uncertainty resolves to
--      keep\" is not a rule the fold can break.
--
--   4. __The two-evidence rule binds because of the file list, not because
--      somebody remembered it.__ @SKILL.md@ principle 4 names seven dynamic
--      languages and demands two independent modalities in each. 'dynamicNote'
--      decides that in ordinary Haskell from @--input-arg paths=@ __before the
--      program exists__ — tier 1, zero questions and zero paths — so the rule
--      arrives in the debate's briefs when the diff touches Python and does not
--      when it touches Rust, and @wf plan --raw@ prints which.
--
--   5. __\"Never auto-install a static-analysis tool\" becomes an absence.__
--      Principle 5 and the @never do@ list both forbid it. Every analyzer this
--      program can run is an argv in "Workflows.Evidence", selected from
--      @'Workflows.Rubrics.Reviewers.languages'@ by the file list; there is no
--      @pip install@, no @cargo install@ and no @npm i@ anywhere in this tree,
--      so the prohibition is not enforced — it is unavailable. And a tool that
--      is missing is a __gap__ rather than a @no@, which is
--      @SKILL.md@ principle 6's yak-shaving trap answered by the transport.
--
--   6. __\"Markers never escape\" is checked, once, over the tree's own bytes.__
--      Principle 9 is the file's sharpest rule and its Phase 4 spells the check
--      as a @rg@ one-liner. Here it is
--      @'Workflows.Evidence.dceMarkers'@ asked as a flag, so a marker that
--      survived is an arm of the program and not a thing a report claims not to
--      have.
--
--   7. __\"Never claim no behaviour change\" has somewhere to go.__ The
--      prohibitions end with \"never claim 'no behavior change' -- instead report
--      __the evidence collected__ and let the user judge\", which in the corpus
--      is a rule about a sentence. Here the evidence /is/ the artefact: a
--      dossier of command receipts, a fold of three advocates' arguments, and a
--      gate's own failing line, each bound and each spliced into the report by a
--      hole.
--
-- == Three honest notes
--
-- __@cap=N@ is this program's repair bound, and that is not quite what the
-- corpus means by it.__ @SKILL.md@ principle 7 makes @cap@ a ceiling on
-- /removal commits per invocation/, which is a count inside one acting turn and
-- is nothing a plan can price. @doc\/design.md@ §7.4 row 13 asks for
-- \"@cap=N@ literally @atMost@\", and that is what 'capBound' does: the input is
-- read in Haskell — tier 1 — and becomes the bound of the ACT phase's gate, so
-- @wf cost dead-code --input-arg cap=4@ is a different number from
-- @wf cost dead-code@ and the operator sees it before spending. The same value
-- also rides into 'actBrief' as the commit ceiling, which is the corpus's own
-- meaning, so one number does both jobs and neither is invented. What is
-- deliberately __not__ carried is the default of 20: twenty rounds of a priced
-- loop is a plan nobody would read, and a bound whose default nobody would
-- accept is a bound that teaches an operator to ignore the price. The default
-- here is two, and @ci\/workflows.sh@ pins that shape.
--
-- __The sidecar manifest is the acting agent's, not this program's.__
-- @phases.md@ 1.7 specifies @.dce-pass-\<n\>\/candidates.json@ down to its
-- schema, and the schema is carried in 'markBrief' verbatim in shape. It is not
-- a receipt here, because the run never reads it back: what the debate is handed
-- is the MARK act's own answer, and what the ACT phase is handed is the debate's
-- verdict. The file exists for the /operator/ — it is what @git diff --stat@
-- shows him at the end of phase 1 — and this program's honesty about it is that
-- it asks for it and does not pretend to have parsed it.
--
-- __One phase of the corpus is missing, and it is the interactive one.__
-- @phases.md@ 1.7's end-of-phase review says \"__do not proceed to Phase 2 until
-- you have shown this__\", and @gates-and-report.md@'s ten approval gates all say
-- \"pause and ask the user\". A person's question is not a real gate when
-- unattended — @--scripted@ answers a flag @yes@ and an unwatched run reaches
-- nobody — so the ten gates ride into the debate's briefs as the
-- 'approvalGates' define, capping a gated region's verdict at @keep@ rather than
-- pausing for a human who may not be there. That is a weaker guarantee than the
-- corpus's and it is written here rather than glossed: the strong form is
-- @'Workflows.Evidence.consentFile'@, and it belongs to a run somebody is
-- watching.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.DeadCode
  ( -- * The program
    deadCodeProgram,
    deadCodeDoc,
    deadCodeScript,

    -- * The three advocates
    debateRoster,
    advocates,

    -- * The rubrics, transplanted
    operatingPrinciples,
    approvalGates,
    neverDo,

    -- * The report every ending calls
    deadCodeReportFn,
    deadCodeTable,

    -- * The two places an input is read in Haskell
    scopeNote,
    capBound,
    capCeiling,
    dynamicNote,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Read as TR
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The two parties that are this program's own
-- ---------------------------------------------------------------------------

-- | The party that inserts the markers and writes the sidecar.
--
-- A @tool@ with __no__ argv, for 'Workflows.Checklist.worker'\''s reason: what
-- MARK does is edit every file that carries a candidate, and the edit list is
-- not knowable to this program. An @'Agentic.Workflow.act'@ at
-- @'Agentic.Raw.CodeAck'@ is the only kind of answer the ACP transport grants
-- write authority to, so the one mutation phase 1 makes is the one statement in
-- this module that could make it.
marker :: Party 'IsTool
marker = tool "dce-mark"

-- | The party that applies the verdicts, commit by commit.
--
-- A second tool and not 'marker', deliberately: @wf plan --raw@ names the party
-- of every node, and a reader tracing a dead-code run should be able to tell the
-- turn that /annotated/ the tree from the turn that /deleted/ from it. The
-- corpus keeps them apart by phase number; here they are two addressees, and a
-- @--route@ table can send them to two different places.
remover :: Party 'IsTool
remover = tool "dce-act"

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | @skills\/eliminate-dead-code\/SKILL.md@'s @## Operating principles (read
-- first, every time)@ — all nine, in the file's own order.
--
-- /Source:/ verbatim in substance. Principle 4's language list and principle 7's
-- number are the two that move: the first is decided in Haskell (see
-- 'dynamicNote') and the second is this program's bound (see 'capBound'), so the
-- text below states the rule and the program states the number.
operatingPrinciples :: Text
operatingPrinciples =
  wfText
    [wf|
    Operating principles. Read these first, every time.

    1. Conservative by default. When uncertain, the verdict is keep, never
       remove. Uncertainty never resolves to removal -- not by majority vote,
       not by "the evidence mostly points that way."
    2. Pure deletions and surgical modifications only. Do not refactor, rename,
       reformat or "improve" adjacent code. A modify verdict applies only the
       concrete diff the debate produced -- nothing more. Do not fix unrelated
       bugs along the way; record them in the final report instead.
    3. Atomic commits. One logical region per commit, with a clear message. Each
       commit must leave the build and tests passing.
    4. Two-evidence rule for dynamic languages. Where a language supports
       reflection or string-based dispatch, a passing test suite is not
       sufficient evidence of safety. Require at least two independent forms of
       evidence before a region is marked a removal candidate, and again before
       a remove verdict is finalized. The two must be independent modalities --
       a static "no references" result AND an entry-point or registration check
       -- not two variants of the same grep.
    5. Native tooling first. Prefer the compiler flags and lints this repository
       already configures. Never install a static-analysis tool: if a
       recommended tool is not present, note it and move on.
    6. Avoid the yak-shaving trap. If the project's build or test commands fail
       for want of a toolchain, report that and stop. Do not spend the run
       trying to install things.
    7. Blast-radius cap. Stop at the cap this run was given. If more candidates
       carry a non-keep verdict, list them in the report and stop; the operator
       can re-invoke for another pass.
    8. Never bypass safety. No --no-verify, no --force, no skipping tests, no
       amending commits to hide failures.
    9. Markers never escape. DCE-BEGIN and DCE-END are working-tree-only
       scaffolding. They are never committed, never pushed, and must be gone
       before this run reports success.|]

-- | @references\/gates-and-report.md@'s @## Approval gates@ — the ten
-- conditions that stop a non-@keep@ verdict.
--
-- /Source:/ the ten bullets, verbatim in substance, with their closing
-- instruction rewritten. The corpus says \"stop and __ask the user__ … then wait
-- for the user's decision\"; this run may have nobody to ask, so the gate caps
-- the verdict at @keep@ and names itself in the report instead. The module header
-- says why, and says what the strong form would be.
approvalGates :: Text
approvalGates =
  wfText
    [wf|
    Approval gates. A region that hits any of these cannot be removed or
    modified by this run. Its verdict is keep, and the report says which gate it
    hit and what your recommendation would have been -- so that a human can
    decide it in one reading, with the evidence in front of him.

    - a public API surface: library exports, CLI commands, web routes, RPC
      handlers, GraphQL types, OpenAPI endpoints;
    - anything matching the exclusion allowlist you built in discovery;
    - any database migration;
    - anything inside a generated or vendored directory;
    - test fixtures, golden files, or i18n keys;
    - anything mentioned in a deploy, ops or runbook file;
    - anything touched inside the recency window this run was given;
    - conditional-compilation branches -- #ifdef, cfg!, feature gates -- whose
      inactive arm targets a platform this run cannot build;
    - a dead feature-flag definition whose default may still be read from a
      remote config service;
    - a deprecated API that may still have external consumers, even where every
      internal caller is gone.

    Do not present a gated region as removable-but-deferred. Present the
    evidence, the gate, and the recommendation.|]

-- | @references\/gates-and-report.md@'s @## What to never do@.
--
-- /Source:/ the eleven bullets. Three of them describe things this program
-- cannot do — there is no @git push --force@, no @git reset --hard@ and no
-- package installer in "Workflows.Evidence" — and they are carried anyway,
-- because the acting turn has the workspace and the sentence is addressed to
-- whoever is holding it.
neverDo :: Text
neverDo =
  wfText
    [wf|
    Never, in any phase:

    - commit or push a DCE marker or the sidecar directory. They are
      working-tree-only scaffolding;
    - insert a marker where a comment is not syntactically legal -- record it in
      the sidecar instead;
    - modify .git/, CI workflows or hooks unless this run's scope named them;
    - delete a file from a directory containing "Code generated", "@generated",
      or listed in .gitattributes as linguist-generated;
    - use git push --force, git reset --hard, or a rebase that hides commits;
    - bypass pre-commit or lefthook with --no-verify;
    - install a static-analysis tool. If it is absent, skip it and say so;
    - remove old-looking code on the strength of its age. Many projects have
      stable, rarely-touched, still-load-bearing modules;
    - trust a single evidence source in a dynamic language;
    - let a balanced-looking debate justify removal. Uncertainty resolves to
      keep;
    - claim "no behaviour change". Report the evidence collected and let the
      reader judge.|]

-- ---------------------------------------------------------------------------
-- The three tier-1 readings of an input
-- ---------------------------------------------------------------------------

-- | What @$ARGUMENTS@ narrows the pass to.
--
-- /Source:/ @SKILL.md@'s @## Scope@ block, whose eight cases are read here in
-- ordinary Haskell — __tier 1__, so the scope sentence a run carries is decided
-- before the program exists and costs neither a question nor a path.
--
-- The empty case is the file's own: \"empty or @.@ -- full repository\". Its
-- \"if the argument is ambiguous, ask the user before proceeding\" is not
-- carried, and the reason is worth one line: an unrecognised scope here is
-- passed through as a scope, so a run given @src\/foo cap=50@ narrows to that
-- subtree and prices its own cap, and a run given a word nobody recognises
-- narrows to a word the discovery question is told to interpret. A question
-- about the invocation is a question the invocation could have answered.
scopeNote :: Text -> Text
scopeNote s
  | T.null (T.strip s) =
      "Scope: the whole repository. Discovery, analysis, marking and removal all \
      \range over every tracked file."
  | otherwise =
      "Scope: " <> T.strip s <> ". Restrict discovery, analysis, marking and \
      \removal to it -- but run every cross-reference check over the WHOLE \
      \repository, because a symbol's callers are not obliged to live in its \
      \subtree. Where the scope names a kind of thing rather than a path -- \
      \docs, imports, feature-flags, comments, or a language name -- take only \
      \candidates of that kind and leave the rest unmarked."

-- | Whether the two-evidence rule binds, decided from the file list.
--
-- __Tier 1__ ("Workflows.Deciders"): @SKILL.md@ principle 4 names its languages
-- — Python, Ruby, JavaScript, TypeScript, Elixir, PHP, Lua — and the fact of
-- which of them a change touches is in the invocation. So this is ordinary
-- Haskell over ordinary 'Data.Text.Text', it costs nothing, and
-- @wf plan --raw@ prints the sentence that will be spliced.
--
-- With no @paths@ the rule binds anyway, and that is the safe direction: an
-- unknown file list is not a file list known to be static, and a two-evidence
-- rule applied where it was not needed costs an extra grep.
dynamicNote :: [Text] -> Text
dynamicNote files
  | null files || any (touches files) dynamicGlobs =
      "The two-evidence rule BINDS on this pass. The file list reaches a \
      \language with reflection or string-based dispatch (or was not given, \
      \which is not the same as being static), so no region is a removal \
      \candidate on one modality alone: a static no-references result AND an \
      \entry-point or registration check, and never two variants of one grep. A \
      \passing test suite is not one of the two."
  | otherwise =
      "The two-evidence rule does not bind on this pass: the file list reaches \
      \no language with reflection or string-based dispatch. One sound modality \
      \is enough to mark a candidate -- and the allowlist, the recency window \
      \and the approval gates are unaffected, because none of them is about \
      \dynamism."
  where
    -- The seven languages principle 4 names, by the extensions they are written
    -- in. Not `Rubrics.Reviewers.languages`, deliberately: that table is about
    -- who reviews a file, and this list is about whether a grep can be trusted.
    dynamicGlobs =
      [ ".py",
        ".pyi",
        ".rb",
        ".js",
        ".jsx",
        ".mjs",
        ".cjs",
        ".ts",
        ".tsx",
        ".mts",
        ".cts",
        ".ex",
        ".exs",
        ".php",
        ".lua"
      ]

-- | The number of act-and-verify trips @cap=N@ buys, and the ceiling the acting
-- turn is told about.
--
-- __Tier 1__, and the one place this module reads a number out of an
-- invocation. An unparseable or absent @cap@ is two; @cap=0@ — the corpus's \"no
-- cap\" — is /not/ unbounded here, because an unbounded loop has no price, and it
-- is read as the largest bound this row will price. Every other value is taken as
-- written and clamped only from below, so a run given @cap=1@ gets one trip and
-- not zero.
--
-- __Why a number and not a flag.__ @'Agentic.Workflow.atMost'@ takes an
-- 'Integer' at build time, and @'Agentic.Workflow.taking'@ hands its inputs to
-- ordinary Haskell before the @Program@ is built — which is exactly what makes a
-- priced bound possible. The consequence is the one @doc\/design.md@ §10 names as
-- its third risk: @plan@ must be given the same @--input-arg cap=@ the run will
-- use, or it prices a different program.
capBound :: Text -> Integer
capBound t = case TR.decimal (T.strip t) of
  Right (n, rest) | T.null rest, n == 0 -> 4
  Right (n, rest) | T.null rest, n >= 1 -> min n 4
  _ -> 2

-- | The ceiling the ACT phase's own prompt carries, in the corpus's units.
--
-- Principle 7's cap is a count of /commits/, and 'capBound' is a count of
-- /trips/. They are the same input read twice, which is deliberate: one number
-- the operator supplies, one meaning for the price and one for the prompt, and
-- neither invented.
capCeiling :: Text -> Text
capCeiling t
  | T.null (T.strip t) = "20"
  | otherwise = T.strip t

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the baseline tree receipt is introduced as.
--
-- /Source:/ @phases.md@ 1.2 step 1: \"working tree must be clean. Run
-- @git status@. If there are uncommitted changes, __abort__ and ask the user to
-- commit\/stash first. A clean starting tree is what lets you discard markers
-- safely later.\"
baselineTreeBrief :: Text
baselineTreeBrief =
  wfText
    [wf|
    The working tree as it stands before anything is marked, analysed or
    removed. A dead-code pass inserts markers into the tree and discards them
    with `git restore`, so a tree that was already dirty is a tree whose markers
    cannot be told from somebody's work in progress.|]

-- | What the baseline gate is asked.
--
-- /Source:/ @phases.md@ 1.2 steps 4–6, whose hard gate is the sharpest sentence
-- in that file: \"dead-code elimination on a broken baseline silently corrupts
-- state. Do not try to fix the failure as part of this run.\"
baselineGateBrief :: Text
baselineGateBrief =
  wfText
    [wf|
    The repository's own build-and-test gate, run before anything has changed.
    This is the baseline: the same command will be run again after each removal,
    and a removal is only judged safe by comparison with this run.|]

-- | What each analyzer receipt is introduced as.
--
-- /Source:/ @phases.md@ 1.3, whose two tables list the native and third-party
-- detectors per language and whose standing rule is \"run only the analyzers
-- that are __already available__ … do not install new tools\".
analyzerBrief :: Text
analyzerBrief =
  wfText
    [wf|
    Run and report. This is a receipt: whatever the command writes is the
    answer, and nothing is added to it. A command that is not installed on this
    machine did not run, which is a different fact from finding nothing.|]

-- | What the discovery question asks for.
--
-- /Source:/ @phases.md@ 1.0 (the seven things to learn about the project) and
-- 1.1 (the exclusion allowlist), which is the file's own most important step:
-- \"this step is the most important defense against breaking the project.\"
discoveryBrief :: Text
discoveryBrief =
  wfText
    [wf|
    Phase 1, discovery. Produce two things and nothing else: a Discovery Report
    and an Exclusion Allowlist.

    The Discovery Report, from the receipts you were given and from the
    repository they describe: whether this is a monorepo and which packages
    consume which; the languages and build system; exactly how tests and lints
    are run; the entry points -- library exports, binary targets, CLI commands,
    web routes, scheduled jobs, queue consumers, plugin registrations; the CI
    configuration, which is what reveals the load-bearing scripts and symbols;
    where the documentation lives; and any CLAUDE.md or AGENTS.md convention
    file, whose rules this run obeys.

    The Exclusion Allowlist: every place code is wired up at runtime by
    convention, reflection or string lookup. Dependency injection and service
    registration; file-system routing and autoloading; ORM, serializer, admin
    and middleware registrations; decorators and macros that register handlers;
    reflection and dynamic dispatch; native and FFI surface; manifests and
    infrastructure -- Helm, Terraform, Kubernetes, CI YAML, systemd units,
    Dockerfiles, package scripts, Makefile targets, entry points, cron entries;
    schemas, whose dead-looking message types may be required by external
    consumers or by stored data; i18n keys; telemetry, metric and feature-flag
    names, which are referenced from dashboards and remote config and will never
    appear in a code search; permission and policy names; database migrations,
    every one of which is load-bearing while any environment references it;
    generated and vendored directories; and test fixtures named from CI by
    filename.

    Everything in that allowlist is must-not-remove without a human. Write it as
    a structured list of paths, directories, symbols and string patterns, and
    write it before you have looked at a single candidate: an allowlist compiled
    after the candidates is an allowlist shaped by what you hoped to remove.|]

-- | What the MARK act is told.
--
-- /Source:/ @phases.md@ 1.4 (cross-reference verification), 1.5 (the three
-- provisional classes), 1.6 (the stale-documentation sweep) and 1.7 (the marker
-- format and the sidecar schema), which are one instruction to one acting turn:
-- annotate, and change nothing else.
markBrief :: Text
markBrief =
  wfText
    [wf|
    Phase 1, marking. This phase inserts comments and writes one new file. It
    removes nothing, edits no line of code, and commits nothing.

    For every candidate, collect the evidence before you mark it: a repo-wide
    grep including hidden files, over the symbol and its plausible case
    variants; a string-literal search, because a symbol referenced from a
    decorator, a plugin registry or a dynamic import is referenced as text; a
    filename search; a manifest scan across package scripts, Makefile targets,
    entry points, every CI file, and any Helm, Terraform, Kubernetes, Docker or
    systemd file; the framework's own route or handler listing where it has one;
    the public-API surface, before and after; `git log --follow` on the file and
    `git log -S` on the symbol, because recency is a signal and code touched
    inside the recency window defaults to needing approval; whether any test,
    fixture or snapshot references it; and whether its name matches anything in
    your allowlist.

    Then classify it provisionally -- safe, needs-approval, or ambiguous. An
    allowlist hit caps the class at needs-approval and can never be safe.
    Anything uncertain is ambiguous or needs-approval. Nothing defaults to safe.

    Sweep the documentation the same way, and be more careful there because
    nothing compiles it: docs anchored to a candidate symbol, examples that
    reference a removed API, migration guides whose target version is older than
    this codebase, TODOs whose issue is closed, README sections for a dependency
    that has gone, stale ADRs and runbooks -- which are historical record and
    default to needing approval -- and commented-out blocks older than about six
    months.

    Now bracket every bracketable region with a matched pair, using the file's
    own comment syntax:

      <comment> DCE-BEGIN id=<NNN> kind=<symbol|block|comment-block|doc>
                class=<safe|needs-approval|ambiguous> name=<symbol-or-desc>
                evidence="<one line>"
      ...the candidate region, unchanged...
      <comment> DCE-END id=<NNN>

    Never insert a marker where a comment is not syntactically legal -- inside a
    string literal, inside a JSON file, mid-expression, between a decorator and
    its function, inside a multi-line literal. If a region cannot be bracketed
    without risking a parse error, do not bracket it. Insert markers only; do not
    touch the bracketed lines.

    Write the sidecar manifest at `.dce-pass-1/candidates.json`, which is the
    authoritative record and includes every candidate that could not be
    bracketed: the pass, the branch, the baseline commands, the starting commit,
    and per candidate an id, kind, location, name, class, whether it was marked
    in source, its evidence as a list, its anchored docs, whether it hit the
    allowlist, and a null verdict. Whole-file deletions, unused imports, unused
    dependencies and standalone doc files are sidecar-only: they have no
    bracketable region.

    Then answer, and this answer is what the debate reads: the Mark Report --
    candidates by kind and by class, the sidecar path, and one line per
    candidate giving its id, location, name, class and evidence. Do not
    summarise the evidence away; the next phase argues from it.|]

-- | What the marker diff is introduced as.
--
-- /Source:/ @phases.md@ 1.7's end-of-phase review — \"then run
-- @git diff --stat@ so the user can see exactly what was annotated\" — which is
-- the corpus asking for this receipt and then handing the /agent's own account/
-- to the next phase anyway.
--
-- __This is the load-bearing bind of the module.__ MARK is an
-- @'Agentic.Workflow.act'@, because it writes, and an act's answer is a receipt
-- rather than a document. So what the three advocates argue over is not the
-- marking turn's summary of itself: it is the diff the marking turn left in the
-- tree, read back by @git@. A region the marking turn described and did not
-- bracket is not in this handle, and a region it bracketed and did not mention
-- is.
markedBrief :: Text
markedBrief =
  wfText
    [wf|
    The marker diff: every line phase 1 added to the working tree, as `git diff`
    reports it. Nothing has been removed or edited -- these are comment markers
    and one new sidecar file, and they are the whole of what phase 1 did.

    This is the artefact under debate. Each DCE-BEGIN line carries the region's
    id, kind, provisional class, name and one-line evidence; each DCE-END closes
    one. A region that is not bracketed here was not bracketed, whatever any
    report says about it.|]

-- | What each advocate is told about the shape of its answer.
--
-- The fold is a @'Agentic.Workflow.panel'@, so each member's answer is read as a
-- verdict — and 'Workflows.Rubrics.Finding.verdictSpec' is where the two words a
-- verdict is decoded from are spelled. This closing line is what makes the
-- direction of the vote unambiguous: an advocate approves when it cannot show a
-- region must stay.
debateClosing :: Text
debateClosing =
  wfText
    [wf|
    You are one of three advocates, and the fold that reads you requires ALL
    THREE to approve before a region may be removed or modified. So the
    direction of your answer matters more than its length:

    - APPROVE means: on the question I own, nothing here forbids acting on this
      pass.
    - OBJECTION: <one line per region> means: these regions must not be acted on
      this pass, and here is the concrete artefact -- file and line, config key,
      route table entry, git range -- that says so.

    Cite artefacts, never possibilities. "It might be used somewhere" is not
    admissible; `src/app.py:41` is. An objection you cannot point at is an
    objection that stops a safe removal, and a removal that should have been
    stopped and was not is worse. Say which regions you object to and be exact
    about the rest.|]

-- | What the ACT act is told, above the cap and the verdict.
--
-- /Source:/ @phases.md@ Phase 3, whose six numbered steps are one acting turn's
-- instructions: dependency order, exactly the verdict, a targeted check, a
-- clean recovery, an atomic commit, and the cap.
actBrief :: Text
actBrief =
  wfText
    [wf|
    Phase 3, acting. Walk the regions in dependency order, leaves first, so that
    removing a callee never orphans a caller that is still there.

    Apply exactly the verdict and nothing more. A kept region loses its markers
    and is not committed. A modified region gets the concrete diff the debate
    produced, its markers stripped, and its anchored doc updates in the same
    commit -- no incidental edits. A removed region goes, markers and all,
    together with the artefacts the sidecar attached to it: anchored docs, and
    the imports the removal has just made unused. No refactors, no renames, no
    reformatting.

    After each region: run the smallest-scope build the project supports and the
    tests that cover the affected module. If anything fails, restore only the
    files that verdict touched -- a repo-wide restore would wipe every other
    pending region's markers -- never `git clean` the sidecar away, never
    `git reset --hard`, downgrade that region's verdict to keep, record the
    failure mode for the report, and move on. If it passes, stage and commit
    only those files, with a message that names the symbol and summarises the
    deciding evidence.

    Every ~5 commits and again at the end of this phase, run the full baseline
    command set and confirm it is green.

    Before you finish: strip the markers of every region you did not act on.
    Acted regions lost theirs in their commit; kept and skipped regions did not,
    and a marker that survives this turn is the one failure this workflow
    guarantees against.

    When you are done, reply DONE.|]

-- | What the marker sweep is asked.
--
-- /Source:/ @phases.md@ Phase 4 step 1. Asked as a flag, because @grep@ exits
-- @1@ for no match and no-match is the good answer here — see
-- @'Workflows.Evidence.dceMarkers'@.
sweepBrief :: Text
sweepBrief =
  wfText
    [wf|
    The marker sweep. Every DCE-BEGIN or DCE-END still in the tree is
    scaffolding this run failed to remove.|]

-- | What the closing delta receipt is introduced as.
--
-- /Source:/ @phases.md@ Phase 4 steps 3 and 4 — the commit history and the
-- line-count delta — which the corpus asks for as two commands and reports as
-- two numbers a model recalls.
deltaBrief :: Text
deltaBrief =
  wfText
    [wf|
    The commits this pass produced, oldest first. This is the removal history,
    as git reports it: one line per commit, and nothing else in it.|]

-- ---------------------------------------------------------------------------
-- The five provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the tree was dirty before anything started.
dirtyTreeNote :: Text
dirtyTreeNote =
  "Outcome: NOT STARTED -- THE TREE WAS DIRTY. `git status --porcelain` \
  \answered with at least one line before this run marked, analysed or removed \
  \anything, so no phase ran and nothing was asked of anybody. A dead-code pass \
  \discards its markers with `git restore --worktree`, which is only safe from a \
  \clean start: on a dirty tree that restore would take somebody's work with it. \
  \Report the porcelain lines below verbatim and say that the pass needs the \
  \tree committed or stashed first."

-- | The arm where the baseline itself was red.
--
-- /Source:/ @phases.md@ 1.2 step 5, whose own sentence is the reason this arm
-- exists and does not try to help: \"do not try to fix the failure as part of
-- this run.\"
redBaselineNote :: Text
redBaselineNote =
  "Outcome: NOT STARTED -- THE BASELINE WAS RED. The repository's own gate was \
  \run before any change was made and it did not pass, so no candidate was \
  \marked and no model was asked to judge one. Dead-code elimination on a broken \
  \baseline silently corrupts state: every later comparison would be against a \
  \failure. Report the gate's own failing line, and say plainly that fixing it \
  \is not this run's job."

-- | The arm where a marker survived.
--
-- /Source:/ @SKILL.md@ principle 9 and @gates-and-report.md@'s first
-- prohibition, negated. This is the arm the corpus's Phase 4 describes as
-- \"strip it before doing anything else\" and has no way to reach.
markersLeakedNote :: Text
markersLeakedNote =
  "Outcome: MARKERS REMAIN. The final sweep found DCE-BEGIN or DCE-END still in \
  \the tree, which means this run's own scaffolding survived the phase that was \
  \supposed to remove it. Do not report the pass as complete and do not \
  \recommend opening a pull request. Say that the markers must be stripped \
  \before anything else happens, name the sweep as the evidence, and list every \
  \commit this pass made so that a reader can tell a leak from an unfinished \
  \phase."

-- | The arm where the gate never came back green.
gateRedNote :: Text
gateRedNote =
  "Outcome: RED AT THE END. Every repair trip this run was given has been spent \
  \and the repository's own gate still objects. Do not push the branch and do \
  \not report the pass as complete. Name the commit that most likely introduced \
  \the failure and the diagnostic step -- a bisect, or a commit-by-commit \
  \revert -- and say that the offending commit should be reverted and the gate \
  \re-run before anything else. Every commit this pass made is still in the \
  \branch."

-- | The arm where everything held.
cleanPassNote :: Text
cleanPassNote =
  "Outcome: GREEN. The baseline passed before anything changed, the debate \
  \settled every region, the gate passed again on the final tree, and the marker \
  \sweep found nothing. Report the pass as ready for review, and say that the \
  \diff should be read before a pull request is opened -- this run reports the \
  \evidence it collected and does not claim there was no behaviour change."

-- ---------------------------------------------------------------------------
-- The three advocates
-- ---------------------------------------------------------------------------

-- | @phases.md@ 2.B's three stances: what each argues, and what makes it lose.
--
-- /Source:/ the three bulleted advocates, verbatim in substance, including the
-- two sentences that decide each one's failure mode — the modify advocate \"must
-- produce a concrete diff, not a theory … 'modify' is not a place to park
-- risk\", and the remove advocate's \"speculative or hypothetical justifications
-- are inadmissible\".
advocates :: [(Text, Text, Text)]
advocates =
  [ ( "keep",
      "whether anything here is or might be live, on concrete evidence",
      "You argue that the marked regions must be retained unchanged. Your job \
      \is to find any reason a region is or might be live: a hidden caller, \
      \dynamic dispatch, a framework convention, membership of a public \
      \surface, recency, an allowlist hit, an external consumer. You may win on \
      \genuine uncertainty or on a protected pattern -- that is the one stance \
      \that may -- but you must cite a concrete artefact: a file and line, a \
      \config key, a route table entry, a git range. A bare \"it might be used \
      \somewhere\" is not admissible and costs you the region."
    ),
    ( "modify",
      "whether a concrete, behaviour-preserving diff is better than either extreme",
      "You argue that a region should be transformed rather than kept or \
      \deleted: slimmed, inlined, stubbed, deprecated, narrowed in visibility, \
      \or moved. You must produce the concrete diff, not the theory of one. If \
      \you cannot produce a specific diff that is clearly behaviour-preserving \
      \-- or an explicitly approved behaviour change -- this stance loses by \
      \default, because modify is not a place to park risk. Object where a \
      \region should be modified and your diff says how; approve where you have \
      \no diff to offer."
    ),
    ( "remove",
      "whether the recorded evidence, re-verified, actually supports deletion",
      "You argue for full deletion. You must enumerate the independent evidence \
      \for each region -- and where the two-evidence rule binds on this pass, \
      \two independent modalities per region, not two variants of one grep -- \
      \and explicitly confirm there is no allowlist hit. Only recorded and \
      \re-verified evidence counts: a speculative or hypothetical justification \
      \is inadmissible. Object to any region whose evidence you cannot now \
      \re-establish, even where you would have removed it; approve only the \
      \regions whose case you can state in full."
    )
  ]

-- | The three advocates, on three rungs, and the fold is a __verdict__.
--
-- /Source:/ @phases.md@ 2.B and 2.C. Three seats and three rungs, so the
-- stances are not three questions to one temperament:
-- @'Workflows.Parties.reasoning'@ holds the keep case (the one that may win on
-- uncertainty), @'Workflows.Parties.broad'@ reads the tree for the modify diff,
-- and @'Workflows.Parties.lateral'@ argues removal from somewhere else — which
-- is the seat whose agreement is worth the most and whose independence therefore
-- matters most.
--
-- __The roster is fixed at three, so WR-1 has nothing to say here__: no input
-- shapes it, @'Agentic.Workflow.panel' []@ is unreachable, and the price of the
-- debate is three questions on every path.
debateRoster :: Roster
debateRoster =
  [ Lens
      { lensName = n,
        lensOwns = owns,
        lensBrief = brief,
        lensParty = rungFor n (model ("dce-" <> n))
      }
  | (n, owns, brief) <- advocates
  ]
  where
    rungFor n
      | n == "keep" = reasoning
      | n == "remove" = lateral
      | otherwise = broad

-- ---------------------------------------------------------------------------
-- The report every ending calls
-- ---------------------------------------------------------------------------

-- | @references\/gates-and-report.md@'s report template.
--
-- /Source:/ its @## Report structure@ fenced block, section for section, plus
-- the three \"proposed next step\" sentences that follow it — which are three
-- different endings in the corpus and are the @{provenance}@ argument here.
deadCodeReportBrief :: Text
deadCodeReportBrief =
  wfText
    [wf|
    Write the dead-code elimination report. Print it; do not write it to disk
    unless you were asked to.

    Open with the provenance line you were given, verbatim, on its own line. It
    is this run's own account of how it ended, and it is not yours to soften, to
    restate, or to reconcile with what you think happened.

    Then:

    # Dead-Code Elimination Report

    **Scope**: <the scope sentence this run carried>
    **Baseline**: <the command, and whether it passed before anything changed>
    **Result**: green / red
    **Markers remaining**: <from the sweep receipt, which is bytes>

    ## Verdicts
    Removed / Modified / Kept / Gated, with counts.

    ## Removed and modified
    One line per commit: the sha, the verdict, the symbol, the files and line
    delta, and the deciding evidence.

    ## Kept, and why
    Location, symbol, and the concrete reference or the uncertainty that won the
    debate.

    ## Gated
    Location, symbol, the evidence found, what was missing, and which approval
    gate it hit.

    ## Stale-doc changes
    ## Toolchain notes
    Tools attempted, tools missing, tools that produced output. A tool that is
    not installed is not a clean result.

    ## Cap status
    Whether the cap was reached, and how many non-keep verdicts remain.

    ## Risks and uncertainties
    ## Unrelated issues observed
    Noticed and deliberately not fixed, per the operating principles.

    Never claim there was no behaviour change. Report the evidence collected and
    let the reader judge -- that is the whole difference between this report and
    a reassurance.|]

-- | One act, five provenance lines.
--
-- Three parameters, and the order is the one the body reads them in: the
-- provenance first, because it is the thing a report must not omit; then the
-- evidence dossier, which is bytes; then whatever the run has to show —
-- the porcelain lines, the mark report, the debate, or the commit series.
deadCodeReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
deadCodeReportFn =
  function
    "deadcode.report"
    ( takes @"provenance" Text
        . takes @"evidence" Text
        . takes @"work" Text
        $ noParams
    )
    \provenance evidence work -> W.do
      act reporter [wf|
          {deadCodeReportBrief}

          Provenance:

          {provenance}

          The command receipts this run collected:

          {evidence}

          What the run has to show:

          {work}

          Write the report, then reply DONE.|]
      done

-- | The table 'deadCodeProgram' hands @'Agentic.Workflow.defining'@.
deadCodeTable :: [SomeFn]
deadCodeTable = [SomeFn deadCodeReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The receipts the world authors for a pass, as @(block label, argv)@.
--
-- The first row is always the repository's own top level, so the dossier is
-- never empty — @'Agentic.Workflow.panelText' []@ is an @error@ on a CAF, and
-- WR-1 says a run priced with no inputs must still be a run. The remaining rows
-- are the @## Tool integration@ blocks of the language reviewers the file list
-- selected, which is @phases.md@ 1.3's \"native compiler and built-in analyzers,
-- always prefer these first\" — as argv rather than as a table somebody consults.
analyzers :: [Text] -> [(Text, Party 'IsTool)]
analyzers files = ("tree", lsPath ".") : detectors
  where
    detectors =
      [ (langName l <> "-analyzer-" <> tshow i, p)
      | l <- languages,
        any (touches files) (langGlobs l),
        (i, p) <- zip [1 :: Int ..] (langTools l files)
      ]

-- | Four phases, five endings, and two gates before a model is asked anything.
--
-- Three inputs. @scope@ is @$ARGUMENTS@ — a path, a kind, a language name, or
-- empty for the whole repository; @paths@ is the file list, one per line, and it
-- selects the analyzers and decides whether the two-evidence rule binds; @cap@ is
-- the blast-radius cap, read in Haskell into the ACT gate's bound.
--
-- The shape, top to bottom: read the tree and refuse to start on a dirty one;
-- run the repository's own gate and refuse to start on a red one; collect the
-- analyzers' receipts; discover the project and build the allowlist; mark;
-- debate to a verdict; act; gate; sweep for markers; report. Five endings, five
-- provenance lines, __one__ 'deadCodeReportFn'.
deadCodeProgram :: Parameterized
deadCodeProgram =
  taking (input "scope" :> input "paths" :> input "cap" :> noInputs) \scope paths cap ->
    -- Tier 1, four times: what the pass ranges over, whether the two-evidence
    -- rule binds, the cap the acting turn is told, and the bound its gate gets.
    -- All four are ordinary Haskell over the invocation, so none of them costs a
    -- question or a path, and `wf plan --raw` prints every one of them.
    let files = pathsOf paths
        ranging = scopeNote scope
        evidenceRule = dynamicNote files
        capNote = capCeiling cap
        principles = operatingPrinciples
        gates = approvalGates
        prohibitions = neverDo
     in defining deadCodeTable W.do
          -- Gate 1. `phases.md` 1.2 step 1, as a receipt and a free decider.
          tree <- ask gitStatus [wf|{baselineTreeBrief}|]
          dirty <- tested treeDirty tree

          if dirty
            then W.do
              call_ deadCodeReportFn (arg dirtyTreeNote :> arg tree :> arg tree :> noArgs)
              stop
            else W.do
              -- Gate 2. `phases.md` 1.2 step 5, as an exit code. One question,
              -- and the arm that refuses to start is that step's own bold
              -- sentence.
              baseline <- passes makeTest [wf|{baselineGateBrief}|]

              if baseline
                then W.do
                  -- Phase 1.3. Receipts, not "if available, run X".
                  facts <- panelText [(label, ask p [wf|{analyzerBrief}|]) | (label, p) <- analyzers files]

                  -- Phase 1.0 and 1.1. The allowlist is authored before a
                  -- single candidate is looked at, which is that file's own
                  -- ordering and here is a bind.
                  discovered <- ask (broad (model "discovery")) [wf|
                      {discoveryBrief}

                      {ranging}

                      What the commands found:

                      {facts}|]

                  -- Phase 1.7. The only mutation phase 1 makes, and an act
                  -- because it writes.
                  act marker [wf|
                      {markBrief}

                      {ranging}

                      {evidenceRule}

                      {principles}

                      {prohibitions}

                      What discovery found, including the allowlist this phase
                      is bound by:

                      {discovered}|]

                  -- The marker diff, read back out of the tree: the debate
                  -- argues over what phase 1 left behind and not over what it
                  -- said it did.
                  marked <- ask (gitDiff []) [wf|{markedBrief}|]

                  -- Phase 2. Three advocates, folded so that ALL THREE must
                  -- approve: `phases.md` 2.C's "this is not a majority vote",
                  -- as the verdict monoid rather than as a rubric.
                  debated <- panel (withEvidence debateRoster debateClosing marked facts)

                  -- Phase 3.
                  act remover [wf|
                      {actBrief}

                      The blast-radius cap for this pass is {capNote} commits.
                      When you reach it, strip the markers of every region you
                      have not acted on, list the remaining verdicts, and stop.

                      {principles}

                      {gates}

                      {prohibitions}

                      What the three advocates answered. A region any one of
                      them objected to is a KEEP, whatever the other two said:

                      {debated}

                      The regions, as they were marked:

                      {marked}|]

                  -- What the world now holds, as bytes the acting turn did not
                  -- write.
                  series <- ask (gitLogSeries "main") [wf|{deltaBrief}|]

                  -- Phase 3's milestone check and Phase 4 step 2, as one gate.
                  -- `cap=N` is its bound, so the price of this loop is the
                  -- number the operator supplied.
                  gated <- gate makeTest repairBrief (reasoning (model "dce-repair")) series (atMost (capBound cap))

                  case gated of
                    Settled work -> W.do
                      -- Phase 4 step 1. The sweep is what this whole workflow
                      -- guarantees, so it is tested before anything is called
                      -- clean.
                      leaked <- passes dceMarkers [wf|{sweepBrief}|]

                      if leaked
                        then W.do
                          call_ deadCodeReportFn (arg markersLeakedNote :> arg facts :> arg work :> noArgs)
                          stop
                        else W.do
                          call_ deadCodeReportFn (arg cleanPassNote :> arg facts :> arg work :> noArgs)
                          stop
                    Unsettled work -> W.do
                      call_ deadCodeReportFn (arg gateRedNote :> arg facts :> arg work :> noArgs)
                      stop
                else W.do
                  call_ deadCodeReportFn (arg redBaselineNote :> arg tree :> arg tree :> noArgs)
                  stop

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
deadCodeDoc :: Text
deadCodeDoc =
  "eliminate-dead-code: four phases, two gates before anything is asked, and a three-advocate debate no majority can win"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every receipt's question opens with its own brief,
-- each advocate's with its 'Workflows.Panels.lensBrief', and the marking turn's
-- with 'markBrief'.
--
-- __The first receipt is what steers the run, and it steers it down the working
-- path.__ 'baselineTreeBrief' answers with a line no porcelain prefix matches, so
-- @'Workflows.Deciders.treeDirty'@ reads the tree as clean and the run proceeds.
-- A real clean tree prints nothing at all, and an /empty/ canned answer is not
-- the way to say that here — an empty answer is how a party declines. Delete the
-- row and the echoed prompt's own lines are read as porcelain, so the run takes
-- the dirty-tree arm instead. Both arms exit 0, which is the point of writing
-- them.
--
-- __And the sentence had to be chosen with care, which is worth recording.__
-- @Agentic.Text.dlines@ ASCII-lowercases the /line/ and @Agentic.Text.dneedle@
-- ASCII-lowercases the /needle/, so @'Workflows.Deciders.treeDirty'@'s porcelain
-- alphabet — @M A D R C U ? !@ — matches those initials in __either__ case. A
-- rehearsal answer beginning \"clean\" is therefore read as a porcelain @C@, and
-- the row that was meant to prove the working path proved the dirty one instead.
-- The answer below opens with a word no porcelain status letter begins.
--
-- __The flags do the rest of the steering, and one default is wrong.__
-- @'Agentic.Exec.scriptedDefault'@ answers a flag @yes@, a verdict @APPROVE@ and
-- a receipt @DONE@: the baseline gate passes, the three advocates approve, the
-- gate settles on its first check, and both acts acknowledge. But the marker
-- sweep is also a flag, and @yes@ there means /markers remain/ — so 'sweepBrief'
-- carries the one explicit @\"no\"@ in this table. That single row is the
-- difference between rehearsing a clean pass and rehearsing the failure this
-- workflow exists to prevent; change it to @\"yes\"@ and the other arm is the one
-- that runs.
deadCodeScript :: [(Text, Text)]
deadCodeScript =
  [ (baselineTreeBrief, "the tree is clean: git status --porcelain printed nothing"),
    (analyzerBrief, analyzed),
    (discoveryBrief, discovered),
    (markedBrief, markerDiff),
    (sweepBrief, "no"),
    (deltaBrief, series),
    (repairBrief, "Restored src/legacy.py and downgraded region 002 to keep.")
  ]
    <> [(lensBrief l, advocateAnswer l) | l <- debateRoster]
  where
    analyzed =
      "src/legacy.py:12:1: F401 'os' imported but unused\n\
      \src/legacy.py:44:1: unused function `render_v1`"

    discovered =
      "Discovery: single package, Python 3.12, pytest, ruff configured. Entry \
      \points: `cli:main` in pyproject.toml [project.scripts]. CI: \
      \.github/workflows/test.yml runs `pytest -q` and `ruff check`.\n\
      \Exclusion allowlist: src/routes/ (FastAPI decorator registration), \
      \migrations/ (every file load-bearing), src/models.py (SQLAlchemy \
      \declarative base), tests/fixtures/ (named from CI by filename)."

    markerDiff =
      "--- a/src/legacy.py\n\
      \+++ b/src/legacy.py\n\
      \@@ -10,6 +10,8 @@\n\
      \+# DCE-BEGIN id=001 kind=import class=safe name=os evidence=\"no refs \
      \(rg, all variants); zero refs (pyright)\"\n\
      \ import os\n\
      \+# DCE-END id=001\n\
      \@@ -38,6 +40,8 @@\n\
      \+# DCE-BEGIN id=002 kind=symbol class=ambiguous name=render_v1 \
      \evidence=\"no static refs; named in a template string\"\n\
      \ def render_v1(ctx):\n\
      \+# DCE-END id=002\n\
      \--- /dev/null\n\
      \+++ b/.dce-pass-1/candidates.json"

    series =
      "a1b2c3d chore: remove unused import os (no refs per ruff + rg, debate: remove)"

    advocateAnswer l
      | lensName l == "keep" =
          "OBJECTION: src/legacy.py:40-58 render_v1 -- templates/old.html:17 \
          \names it in a string literal, which is the string-based dispatch the \
          \two-evidence rule is about. 001 is clear."
      | otherwise =
          "APPROVE -- on " <> lensOwns l <> ", nothing forbids acting on 001 this pass."
