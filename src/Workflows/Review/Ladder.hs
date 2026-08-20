-- |
-- Module      : Workflows.Review.Ladder
-- Description : The paneled reviewer family — one ladder builder, four priced rungs.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                 | here                                                          |
-- +===========================================+===============================================================+
-- | @commands\/quick-review.md@               | @review-quick@ — the one-member roster                        |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/deep-review.md@                | @review-deep@ — the whole Step 1..Step 5 pipeline             |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/code-review.md@                | @review-deep@ with @--input-arg paths=@ — the \"named-agent   |
-- |                                           | health checkup\" /is/ the language roster, and it is selected  |
-- |                                           | by the file list rather than by a sentence                     |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/sec-audit.md@                  | @review-sec@                                                  |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/heavy-review.md@               | @review-heavy@ — the seven passes                             |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/review-github-pr.md@           | @review-deep@ with a PR scope. Its \"NEVER post to GitHub\" —  |
-- |                                           | six capitalised bullets there — is not a rule here: a          |
-- |                                           | reviewing question is asked at @text@, and                     |
-- |                                           | @Agentic.Acp.permissionByCode@ grants write authority only to   |
-- |                                           | an act at @receipt@, so no member of any roster below /can/    |
-- |                                           | post                                                          |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/alexey.md@                     | 'alexeyLens', a member of the @review-heavy@ roster            |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @agents\/*-reviewer.md@ (eleven)          | "Workflows.Rubrics.Reviewers", selected by 'tierRoster'        |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @skills\/{alexey-review,comment-audit,@   | 'alexeyLens', 'commentAuditLens', 'deadCodeLens',              |
-- | @eliminate-dead-code,abstraction-review,@ | 'abstractionLens', 'validatedLens' — the review-sized slice of |
-- | @validated-code-review}\/SKILL.md@        | each, beside the roster that selects it                        |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @skills\/parallelize\/SKILL.md@           | the sentinel probe, once, over                                 |
-- |                                           | 'Workflows.Rubrics.Discipline.independenceAttestation' —       |
-- |                                           | reported beside @run.engine@, which is what actually settles   |
-- |                                           | whether the passes were independent ('tierProvenance')         |
-- +-------------------------------------------+---------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
-- Each item is a thing the Markdown could not express and this program does.
--
--   1. __The priced fan-out.__ @deep-review.md@ Step 2 is a nine-row extension
--      table a coordinator /model/ is told to compute, and Step 3 spawns \"the
--      corresponding agent\" for each hit. Here the table is
--      'Workflows.Deciders.touches' over the @paths@ input, the roster is
--      selected in ordinary Haskell __before the 'Agentic.Builder.Program'
--      exists__, and @wf cost review-deep --input-arg paths=…@ prints a min, a
--      max and a path count for /this/ diff before a token moves. The dispatch
--      costs zero questions and adds zero paths.
--
--   2. __The rung is priced apart from its siblings.__ The corpus's five
--      commands carry a hand-maintained \"See also — review ladder\" paragraph
--      that orders them by a feeling about weight. Four registry rows order them
--      by a number: @quick@, @sec@, @deep@, @heavy@ have four different bills and
--      an operator reads them without spending anything.
--
--   3. __The frozen snapshot is a handle, not a sentence.__ @heavy-review.md@
--      asks the runner to \"freeze one scope snapshot before reviewing so every
--      pass examines the same code\". Here the snapshot is one receipt the world
--      authored, bound once, and spliced into every member by
--      'Workflows.Panels.withEvidence' — so the members /cannot/ be reading
--      different trees, and no member has to be trusted to have run anything.
--
--   4. __The receipt-authored check.__ The @## Tool integration@ block of seven
--      reviewer files says \"if available, run @hlint \<file\> --json@\" to a
--      model. Here every one of those is an argv in "Workflows.Evidence", run by
--      "Agentic.Shell" with @proc@, and the dossier the panel reads is bytes the
--      answering model did not write — under a sentence
--      ('Workflows.Panels.withEvidence') that says a receipt outranks a reading.
--
--   5. __The decider-read gate.__ @deep-review.md@ and @heavy-review.md@ both
--      demand a no-history attestation and both leave the check to prose. Here
--      it is one probe and one 'Workflows.Deciders.historyAbsent' — zero
--      questions, one path — and the failing arm still /reports/, because
--      @deep-review@'s own rule is \"stop and report the review incomplete\",
--      which is a branch and not an abort.
--
--      __What the probe establishes is narrower than either file assumes__, and
--      'tierProvenance' now says so rather than printing \"the no-history
--      attestation verified\" over it: the probe can only find context /this
--      runner/ planted, so a session already carrying the work passes it
--      truthfully. The fact that settles independence is @run.engine@, which the
--      runner binds and this row reports beside the probe's answer. It is
--      reported and not gated on, because a rung here writes a review and a
--      reader can weigh it; the row that refuses to start on the same fact is
--      @wiggum@, where the separation is a clause of a definition of done.
--
--   6. __The refusal is a branch the program takes.__ @deep-review.md@ Step 5
--      says \"confirm that all four required skill-perspective passes completed
--      … else label the report incomplete\". That is read by
--      'Workflows.Panels.refusingSynthesis' (whose roster table is derived from
--      the very list the panel was built from) plus
--      'Workflows.Deciders.incompleteFanOut', for free — and the two arms call
--      __one__ 'Workflows.Report.reportFn' with a different @{provenance}@, so a
--      partial fan-out cannot come out looking like a clean tree.
--
--   7. __One finding schema, one report tail.__ Eleven agent files carry the
--      output block and @sec-audit.md@ carries @deep-review@'s report format by
--      prose reference (\"use the same structured format\"). Here it is
--      'Workflows.Rubrics.Finding.findingSchema' holed into every brief and
--      @call_ reportFn@ at every ending, and the four rungs cannot drift.
--
-- == Two honest notes
--
-- __The rung is chosen in Haskell, so @plan@ must be given the same
-- @--input-arg paths=@ the run will use__ or it prices a different program. With
-- no @paths@ the language roster is empty and only the fixed members run; that
-- is the number @ci\/workflows.sh@ pins.
--
-- __\"Every named block arrived\" is not decidable by the four pure deciders.__
-- @'Agentic.Workflow.ContainsLine'@ takes its needle list __disjunctively__
-- (@Agentic.Text.runDecider@: @any … ws@), so @decide ContainsLine found (map
-- fenceOpen roster)@ would say \"at least one block\" where the design's sketch
-- reads \"all of them\". The construction used instead is the foundation's own
-- and is exact: the synthesis is /asked/ to account for the blocks and to answer
-- @INCOMPLETE: …@, and 'Workflows.Deciders.incompleteFanOut' reads that answer
-- for nothing.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}

module Workflows.Review.Ladder
  ( -- * The rungs
    Tier (..),
    tierName,
    tierRoster,
    tierDossier,

    -- * The program
    reviewLadder,
    reviewDoc,
    reviewScript,

    -- * The lenses the corpus keeps in skill files
    quickLens,
    alexeyLens,
    ponytailLens,
    deadCodeLens,
    commentAuditLens,
    abstractionLens,
    validatedLens,
    heavyDeepLens,
  )
where

import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import qualified Agentic.Workflow.Do as W
import Prelude

-- ---------------------------------------------------------------------------
-- The rungs
-- ---------------------------------------------------------------------------

-- | The four shapes the corpus's seven review commands come in.
--
-- Four rows and not seven, because a row is one /shape/: @code-review@ is
-- @review-deep@ over a file list, and @review-github-pr@ is @review-deep@ over a
-- PR's diff. What differs between the four below is the roster, the dossier and
-- the price — which is exactly what a registry row should differ in.
data Tier
  = -- | @commands\/quick-review.md@ — \"a fast, single-pass code review without
    -- spawning sub-agents\".
    Quick
  | -- | @commands\/deep-review.md@ — the language roster, the performance pass
    -- and the four required skill perspectives.
    Deep
  | -- | @commands\/sec-audit.md@ — the language roster plus the security pass.
    Sec
  | -- | @commands\/heavy-review.md@ — the seven independent passes.
    Heavy
  deriving (Eq, Show)

-- | The name the operator types, and the name that goes in the provenance line.
tierName :: Tier -> Text
tierName Quick = "review-quick"
tierName Deep = "review-deep"
tierName Sec = "review-sec"
tierName Heavy = "review-heavy"

-- | The one line @wf list@ prints beside a rung.
reviewDoc :: Tier -> Text
reviewDoc Quick = "one lens over a frozen snapshot: the fastest rung, priced exactly"
reviewDoc Deep = "the language roster, perf and the four required skill lenses, over receipts"
reviewDoc Sec = "the language roster plus the security lens, over the same receipts"
reviewDoc Heavy = "the seven independent passes of `heavy-review`, over one snapshot"

-- ---------------------------------------------------------------------------
-- The roster a rung selects
-- ---------------------------------------------------------------------------

-- | The fan-out a rung runs, given the file list.
--
-- Ordinary Haskell over ordinary 'Data.Text.Text'. This is the tier-1 decision
-- of "Workflows.Deciders": it happens before the program is built, so @plan@
-- prints the exact roster that will run and the dispatch costs nothing.
tierRoster :: Tier -> [Text] -> Roster
tierRoster Quick _ = [quickLens]
tierRoster Deep files =
  languageRoster (touches files)
    <> fallThrough files
    <> crossCuttingNamed "performance"
    <> requiredLenses
tierRoster Sec files =
  languageRoster (touches files)
    <> fallThrough files
    <> crossCuttingNamed "security"
tierRoster Heavy _ =
  [ heavyDeepLens,
    alexeyLens,
    abstractionLens,
    validatedLens,
    ponytailLens,
    deadCodeLens,
    commentAuditLens
  ]

-- | The four @deep-review.md@ calls \"required cross-cutting skill
-- perspectives\", in its own order.
--
-- /Source:/ @commands\/deep-review.md@ @## Required cross-cutting skill
-- perspectives@ and Step 4 items 1–4. \"Required\" there is a word; here it is
-- a list every @Deep@ roster is built from, so a rung cannot quietly run three
-- of them.
requiredLenses :: Roster
requiredLenses = [alexeyLens, ponytailLens, deadCodeLens, commentAuditLens]

-- | One of the two cross-cutting reviewers, by name.
--
-- @deep-review.md@ is emphatic that the security pass is __not__ part of a deep
-- review (\"Do NOT run a security pass by default … leave security to the
-- standalone @sec-audit@ command\"), and @sec-audit.md@ is equally emphatic that
-- it is the whole of one. Two rungs, one table, and the sentence becomes the
-- difference between two rows.
crossCuttingNamed :: Text -> Roster
crossCuttingNamed n = [l | l <- crossCuttingRoster, lensName l == n]

-- | 'Workflows.Rubrics.Reviewers.generalPurpose', when the file list holds a
-- path no language reviewer claims.
--
-- /Source:/ @commands\/deep-review.md@ Step 2's closing sentence — \"if a
-- language has no specialist agent defined, use the @general-purpose@ built-in
-- agent\" — which in the corpus is a fall-through nobody can see and here is a
-- member with a name, a party and a price.
fallThrough :: [Text] -> Roster
fallThrough files
  | any unclaimed files = [generalPurpose]
  | otherwise = []
  where
    unclaimed f = not (any (`T.isSuffixOf` f) allGlobs)
    allGlobs = concatMap langGlobs languages

-- ---------------------------------------------------------------------------
-- The dossier a rung reads
-- ---------------------------------------------------------------------------

-- | The receipts the world authors for a rung, as @(block label, argv)@.
--
-- The first row is always @git diff --name-only@ — @deep-review.md@ Step 1's own
-- second command — so that the file list a run actually saw is in the document
-- beside the file list the operator asserted, and a mismatch is visible rather
-- than assumed. The remaining rows are the @## Tool integration@ blocks of the
-- language reviewers the file list selected.
--
-- __Why the labels are indexed rather than named after the command.__
-- 'Workflows.Rubrics.Reviewers.langTools' returns bare
-- @'Agentic.Workflow.Party' \''Agentic.Workflow.IsTool'@ values and
-- "Agentic.Workflow" exports no accessor for a party's name, so a caller cannot
-- label a receipt with the command that produced it. Reported as a finding
-- against "Workflows.Rubrics.Reviewers"; the argv is in the printed program
-- either way, so the receipt is attributable — just not from the label alone.
tierDossier :: Tier -> [Text] -> [Text] -> [(Text, Party 'IsTool)]
tierDossier t revs files = ("files", gitDiffNames revs) : linters
  where
    linters
      | t == Quick = []
      | otherwise =
          [ (langName l <> "-tool-" <> tshow i, p)
          | l <- languages,
            any (touches files) (langGlobs l),
            (i, p) <- zip [1 :: Int ..] (langTools l files)
          ]

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the snapshot question asks the diff command for.
--
-- /Source:/ @commands\/deep-review.md@ Step 1 and @commands\/heavy-review.md@'s
-- \"freeze one scope snapshot before reviewing so every pass examines the same
-- code\". The words go to the child's standard input, where they are data; the
-- scope itself is the argv, which is why an empty scope is @git diff@ (the
-- uncommitted changes) exactly as Step 1 says and not a string a model parsed.
snapshotBrief :: Text
snapshotBrief =
  [wft|
  This is the frozen scope snapshot for a code review. Every reviewer below
  reads this and only this, so that no two of them are looking at different
  trees.|]

-- | What each dossier row's question asks for.
--
-- /Source:/ the @## Tool integration@ block of
-- @agents\/{bash,cpp,haskell,nix,python,rust,typescript}-reviewer.md@, which in
-- the corpus reads \"if available, run …\" and is addressed to a model.
dossierBrief :: Text
dossierBrief =
  [wft|
  Run and report. This is a receipt: whatever the command writes is the
  answer, and nothing is added to it.|]

-- | The closing line every member of a document fold is given.
--
-- /Source:/ @commands\/deep-review.md@ Step 3 (\"instructions to produce
-- findings in the structured format\") and @heavy-review.md@'s \"each pass
-- subagent … returns findings as structured data\".
blockClosing :: Text
blockClosing =
  [wft|
  Report your findings and nothing else. Your answer is one block of a
  document whose other blocks are your siblings', each fenced under its own
  name: do not summarise the whole, and do not address the reader of any block
  but your own.|]

-- | The synthesis brief for a rung: the foundation's refusing synthesis, over
-- @deep-review@'s own four operations.
--
-- /Source:/ 'Workflows.Panels.refusingSynthesis' (the roster accounting) and
-- @commands\/deep-review.md@ Step 5 items 1–4 plus @heavy-review.md@'s
-- consolidation list, which are the same four operations written twice.
synthesisBrief :: Roster -> Text
synthesisBrief r =
  [wft|
  {refusing}

  Two more rules, which come from the commands this fold replaces:

  - Separate verified defects from questions and non-actionable observations,
    and include a clean-pass statement for every reviewer that found nothing.
  - End with the smallest safe fix order, and the verification command for
    each fix.

  Do not report a style preference that has no concrete maintenance,
  correctness, performance or security consequence.|]
  where
    refusing = refusingSynthesis r

-- | The provenance line a rung's report carries when everything held.
--
-- /Source:/ @commands\/deep-review.md@'s @**Required perspectives**@ line and
-- @heavy-review.md@'s \"include a clean-pass statement for each pass\". The
-- roster is derived from the very list the panel was built from, so this line
-- cannot name a reviewer that did not run.
--
-- __It used to close \"with the no-history attestation verified\", and that was
-- more than the probe establishes.__ The probe asks whether a line /this runner/
-- planted was already in the answerer's context, so it finds the contamination
-- this toolbox could cause and no other: a session already carrying the work
-- answers @PARENT_HISTORY_ABSENT@ truthfully, because there is no planted line in
-- it to report (see
-- 'Workflows.Rubrics.Discipline.independenceAttestation'). Under a runner that
-- shares one conversation, \"seven independent passes\" would then have been
-- printed over seven turns of one transcript.
--
-- So the line states __both__ facts and lets the reader draw the conclusion: the
-- probe's answer, and @run.engine@ — the engine and its session policy, from the
-- runner and from nobody asked. It is quoted rather than judged, because a rung
-- here reports and does not refuse; the row that turns the same fact into a
-- refusal is @wiggum@, where a separate evaluator is a clause of a definition of
-- done rather than a quality of a report.
tierProvenance :: Tier -> Roster -> Text -> Text
tierProvenance t r engine =
  "rung `"
    <> tierName t
    <> "`, over a frozen scope snapshot. This run's engine and its session \
       \policy, from the runner: "
    <> engine
    <> ". The reviewers, and what each owns:\n"
    <> rosterTable r
    <> "\nEvery reviewer read the same snapshot and the same command receipts. \
       \The parent-history sentinel probe passed, which establishes that no line \
       \this run planted was already in an answerer's context -- it cannot see \
       \any other prior context, so whether these passes were reached \
       \independently of each other and of the work is settled by the engine \
       \fact above and not by the probe. Under a new session per question they \
       \were; under one shared session they were not, however clean each block \
       \reads."

-- | The provenance line the failed-attestation arm carries.
--
-- /Source:/ @commands\/deep-review.md@ (\"if it is unavailable or fails, stop
-- and report the review incomplete instead of dispatching or claiming
-- independent passes\") and @heavy-review.md@ (\"if the runner cannot prove
-- no-history dispatch, stop rather than label the passes independent\").
--
-- Both files say /stop/ and both then say /report/, which is a branch. Here it
-- is one, and the arm that did not review still writes a report — because a run
-- that ends silently is a run whose operator learns nothing.
notIndependentNote :: Text
notIndependentNote =
  "Outcome: NO REVIEW WAS RUN. The parent-history sentinel probe did not answer \
  \PARENT_HISTORY_ABSENT: a line this run generated for itself and put in no \
  \other place came back, so context this runner planted was already in front of \
  \the answerer. No reviewer was asked. Report exactly that, name the scope below \
  \as un-reviewed, and do not characterise the code."

-- | The provenance line the short-fan-out arm carries.
--
-- /Source:/ @commands\/deep-review.md@ Step 5 (\"name it explicitly and label
-- the report incomplete rather than silently presenting it as a full deep
-- review\").
shortFanOutNote :: Text
shortFanOutNote =
  "Outcome: INCOMPLETE FAN-OUT. The consolidation refused, because at least \
  \one reviewer's block was missing or empty; its first line names which. \
  \Label this report incomplete, name the missing reviewers in the Reviewers \
  \line, and do not present it as a full pass."

-- ---------------------------------------------------------------------------
-- The lenses the corpus keeps in skill files
-- ---------------------------------------------------------------------------

-- | @commands\/quick-review.md@, whole.
--
-- /Source:/ its @## Review@ four-item checklist and its @## Output@ block,
-- verbatim but for the finding format, which is
-- 'Workflows.Rubrics.Finding.findingSchema' — so the fastest rung and the
-- heaviest one produce findings a single report function can fold.
quickLens :: Lens
quickLens =
  Lens
    { lensName = "quick",
      lensOwns = "the fast single pass: obvious bugs, security red flags, error handling, style",
      lensParty = broad (model "quick-review"),
      lensBrief =
        [wft|
        Perform a fast, single-pass code review. This is for rapid feedback
        during development, not for pre-merge thoroughness.

        Read each changed file and its diff. For each file, check for:

        1. Obvious bugs: null/nil dereference, off-by-one, logic inversions,
           typos.
        2. Security red flags: hardcoded secrets, unsanitized input,
           eval/exec.
        3. Error handling gaps: unchecked returns, swallowed exceptions,
           missing cleanup.
        4. Clear style violations: inconsistent naming, dead code,
           TODO/FIXME/HACK markers.

        Keep it concise. If the code looks fine, say "No issues found" with a
        brief summary of what you reviewed.

        {schema}

        {reading}|]
    }
  where
    schema = findingSchema
    reading = codeIsTheArtefact

-- | The Alexey-discipline pass.
--
-- /Source:/ @skills\/alexey-review\/SKILL.md@ — the identity guardrails
-- (verbatim, because they are the part that must not be paraphrased), the
-- twelve-step review procedure compressed to its named steps, and the severity
-- gates — together with @commands\/alexey.md@'s stance blockquote, which is the
-- same discipline said once more in one paragraph.
--
-- The two files are one value here. In the corpus the command quotes the skill
-- and the skill points at two reference files, and the reader has to hold all
-- three open.
alexeyLens :: Lens
alexeyLens =
  Lens
    { lensName = "alexey",
      lensOwns = "evidence-first maintainer judgment: benchmarks, counterexamples, prose truth, test meaning, scope",
      lensParty = reasoning (model "alexey"),
      lensBrief =
        [wft|
        Review this as a seasoned, high-bar maintainer applying Alexey's
        review discipline. You apply the discipline; you are NOT him.
        Findings are your own. Never sign as him, never write "Alexey would
        say", never attribute an opinion to him. Never simulate frustration,
        impatience or scorn: treat the code aggressively, remain a
        dispassionate agent. Do not invent benchmark numbers, repository
        history, or expertise you have not verified here. Own every judgment:
        never grade by proxy -- the severity call is yours and is stated as
        yours.

        The procedure, in order:

        1. Benchmarks first -- read the performance numbers before the diff.
           An unexplained delta in either direction costs the change
           unconditional approval.
        2. Simulate the code -- construct the counterexample, the thread
           interleaving, the unit arithmetic. Never argue "unlikely" about a
           race.
        3. Audit prose truth -- check every comment, note and doc claim
           against the code. False or overclaiming prose is a defect as severe
           as false code. Sweep every added comment for change-narration and
           AI planning residue.
        4. Perf from first principles -- allocation counts, critical path,
           worker stalls, missed streaming, read off the code.
        5. Hunt debris -- dead code, fields derivable from ground truth, two
           ways to do one thing, fossils of abandoned designs.
        6. Interrogate tests -- they must assert something meaningful and
           never lose coverage silently.
        7. Push types -- newtypes for indices, optional over sentinel, invalid
           states unrepresentable; a cast is a smell, fix the declaration.
        8. Police scope -- one stated objective, no unrelated changes.
        9. Prefer loud failure -- a defensive fallback that converts a bug into
           silence is guilty until explained.
        10. Generalize the hack -- propose the representation that would make
            the special case unnecessary.
        11. Micro-probe sweep -- walk every changed hunk and emit the one-line
            probes: "Still needed?", "Dead code?", "Is this comment still
            true?". The long tail is the review.
        12. Scope your verdict honestly -- say exactly what you reviewed at
            what depth and name who should cover the rest.

        Block only on: demonstrable correctness bugs; races without a
        synchronization story; unexplained material perf changes; false or
        overclaiming prose; tests that assert nothing or lose coverage
        silently; entangled scope; ignored prior feedback. Question rather
        than block a design alternative or a missing rationale. Every block
        carries a path forward.

        Criticism arrives as a genuine question with your candidate answer
        embedded. Under forty words for everything routine. Praise is loud,
        short, specific and earned.

        {schema}

        {reading}|]
    }
  where
    schema = findingSchemaWith [soundnessLine]
    reading = codeIsTheArtefact

-- | The over-engineering pass.
--
-- /Source:/ @commands\/deep-review.md@'s own two descriptions of it — the
-- @## Required cross-cutting skill perspectives@ bullet and Step 4 item 2 — and
-- @heavy-review.md@ pass 5. The @ponytail@ skill itself is __not in this
-- corpus__ (it is a plugin skill the owner has installed elsewhere), so the
-- rubric is what his own files say it should look for, and nothing is invented
-- on top of that.
ponytailLens :: Lens
ponytailLens =
  Lens
    { lensName = "ponytail",
      lensOwns = "work that need not exist, duplicate machinery, avoidable dependencies, code to delete",
      lensParty = lateral (model "ponytail"),
      lensBrief =
        [wft|
        Challenge unnecessary code and abstractions. Prefer deletion, reuse,
        standard-library or native facilities, and the smallest solution that
        actually satisfies the requirement.

        Look specifically for:

        - work that need not exist at all -- a requirement nobody stated;
        - an existing facility in this codebase that should have been reused;
        - a dependency or an abstraction that could be avoided;
        - duplicate machinery: two mechanisms doing one job;
        - a simpler correct design for what is here.

        Report what to delete and what replaces it. A finding that names no
        replacement is a preference, not a finding.

        {schema}

        {reading}|]
    }
  where
    schema = findingSchema
    reading = codeIsTheArtefact

-- | The dead-code pass, as a __lens__ and never as its four-phase workflow.
--
-- /Source:/ @skills\/eliminate-dead-code\/SKILL.md@ operating principles 1, 4
-- and 5, plus @commands\/deep-review.md@ Step 4 item 3, whose \"do not run its
-- MARK, ACT, or commit phases\" is the reason this is a rubric and not a
-- program. The skill's own MARK/DEBATE/ACT/VERIFY is a different object and
-- belongs to a different row.
deadCodeLens :: Lens
deadCodeLens =
  Lens
    { lensName = "dead-code",
      lensOwns = "unreachable, unreferenced, redundant or stale code and documentation, with evidence",
      lensParty = broad (model "dead-code"),
      lensBrief =
        [wft|
        Find code and documentation that are no longer reachable, referenced,
        or relevant. Report candidates only: do not mark, do not remove, do
        not commit, and do not create a manifest.

        You cannot guarantee zero behaviour change from static analysis alone
        -- reflection, dynamic dispatch, framework conventions and runtime
        wiring make that impossible. So gather evidence, and say what evidence
        you have.

        Operating principles:

        1. Conservative by default. When uncertain the verdict is keep, never
           remove. Uncertainty never resolves to removal -- not by majority
           vote, not by "the evidence mostly points that way."
        2. Two-evidence rule for dynamic languages. In Python, Ruby,
           JavaScript, TypeScript and any language supporting reflection or
           string-based dispatch, a passing test suite is not sufficient
           evidence. Require two independent modalities -- a static
           "no references" result AND an entry-point or registration check --
           not two variants of one grep.
        3. Native tooling first. Prefer the compiler flags and lints this repo
           already configures. Never propose installing a static-analysis
           tool.

        When in doubt, leave it: flagging a candidate for human review is
        always better than a silently broken deploy. Say so in the finding.

        {schema}

        {reading}|]
    }
  where
    schema = findingSchemaWith [soundnessLine]
    reading = codeIsTheArtefact

-- | The comment audit, as a lens.
--
-- /Source:/ @skills\/comment-audit\/SKILL.md@ @## Core principles@ and
-- @commands\/deep-review.md@ Step 4 item 4, whose \"do not create
-- @.comment-audit@ artifacts or apply fixes\" is again what makes this a rubric.
-- The skill's manifest, its extractor script and its resumability are about a
-- long-running audit and have no referent in one panel member's question.
commentAuditLens :: Lens
commentAuditLens =
  Lens
    { lensName = "comment-audit",
      lensOwns = "every comment and docstring claim, checked against the live code",
      lensParty = broad (model "comment-audit"),
      lensBrief =
        [wft|
        Audit the comments and docstrings in this change with a fine-toothed
        comb: confirm that every claim a comment makes is true, that any code
        shown in a comment actually works, and that everything a comment
        references still exists -- including references outside the diff that
        may have become stale.

        Evidence before verdict. Never call a comment wrong without concrete
        proof from the current code. When proof is missing, or the judgment
        depends on domain knowledge not present in the repository, the verdict
        is NEEDS_REVIEW and not INCORRECT. A confident-but-wrong verdict that
        triggers a "fix" to a correct comment is the worst possible outcome:
        bias toward caution.

        Exhaustive means accounted-for. Say which comment surfaces you did not
        reach, and why. A silent omission is indistinguishable from a clean
        audit.

        Do not create audit artifacts and do not apply fixes.

        {schema}

        {reading}|]
    }
  where
    schema = findingSchemaWith [soundnessLine]
    reading = codeIsTheArtefact

-- | The architecture-alignment pass.
--
-- /Source:/ @skills\/abstraction-review\/SKILL.md@ — its one question, its
-- failure mode, and its extension/evasion discriminator, which are the first
-- sixty lines of that file and the part a reviewer acts on.
abstractionLens :: Lens
abstractionLens =
  Lens
    { lensName = "abstraction",
      lensOwns = "whether the change extended the shared abstraction or routed around it",
      lensParty = reasoning (model "abstraction"),
      lensBrief =
        [wft|
        A change can work perfectly and still be wrong. Answer one question:
        when the task did not fit the existing abstractions, did the change
        correct the abstraction, or evade it? Correctness, performance, style
        and general over-engineering belong to other reviewers here -- report
        findings only about architectural fit.

        The failure mode: a requirement arrives that the shared path cannot
        express, the abstraction says no, and the implementer takes that "no"
        as a law of physics and routes around it -- a private mechanism, a
        special case, a name-sniffing hack. The code works, and working is the
        trap. Working code proves an implementation chain exists; it says
        nothing about whether it is a good path.

        Every route-around embodies a premise -- "the keys may not match, so
        search at runtime". Volume, polish and green tests measure that
        premise's blast radius, not its truth. So for every divergence from
        the shared path ask: real invariant, or accidental limitation? Most
        guards encode nothing deeper than "no input has needed this yet."

        The discriminator is not whether the change adds a mechanism but where
        the mechanism lands. Extension teaches the shared path a new word: it
        enters through the sanctioned extension point, is expressed as data,
        types or parameters flowing through the existing pipeline, is
        available to every consumer, and replaces the need for a special case.
        Evasion adds a private dialect: reachable only from the new case, with
        the shared path left ignorant of it.

        Name each finding as extension or evasion, and for an evasion sketch
        the representation that would have made it unnecessary.

        {schema}

        {reading}|]
    }
  where
    schema = findingSchemaWith [soundnessLine]
    reading = codeIsTheArtefact

-- | The validated multi-model pass.
--
-- /Source:/ @skills\/validated-code-review\/SKILL.md@ — its overview, its
-- P0–P2 grading and its different-model verification rule.
--
-- __What does not survive, and why that is the point.__ Two thirds of that file
-- is model dispatch: a @MODELS:@ line, a @mcp__pal__chat@ call per reviewer, a
-- @verify-model-dispatch.py@ that reads @metadata.model_used@, and an abort if
-- the identity attestation fails. All of it is
-- @'Agentic.Workflow.servedBy'@ plus @--require-pinned@, which refuses a program
-- with an unpinned addressee __before a plan is printed__ — so the skill's
-- hand-rolled attestation has nothing left to check. What remains is the review
-- rubric, which is this.
validatedLens :: Lens
validatedLens =
  Lens
    { lensName = "validated",
      lensOwns = "merge blockers, graded P0-P2, each claim stated so a different model could verify it",
      lensParty = lateral (model "validated"),
      lensBrief =
        [wft|
        This is strictly a code review: never build, never run tests. Work
        read-only against the diff you were given.

        Produce merge-blocker-focused findings. Grade each surviving claim:

        - P0 -- a merge blocker: it will break correctness, security or data
          integrity.
        - P1 -- should be fixed before merge, but does not block on its own.
        - P2 -- worth doing, and can follow.

        Write every claim so that a reviewer who is not you, reading only your
        sentence and the code, could confirm or refute it without asking you
        anything. A claim that needs your reasoning to be checkable has not
        been stated yet: rewrite it until it names the file, the line, the
        input and the observable consequence.

        State your own confidence, and separate what you verified from what
        you inferred.

        {schema}

        {reading}|]
    }
  where
    schema = findingSchemaWith [soundnessLine]
    reading = codeIsTheArtefact

-- | @heavy-review.md@'s first pass.
--
-- /Source:/ @commands\/heavy-review.md@ pass 1, which is one sentence naming six
-- concerns, given the six as an ordered walk. It is a distinct member from the
-- language reviewers because at the @heavy@ rung the language passes are not
-- run: the seven passes there are the whole roster, by that file's own count.
heavyDeepLens :: Lens
heavyDeepLens =
  Lens
    { lensName = "deep",
      lensOwns = "correctness, security, performance, structure, tests and documentation, together",
      lensParty = broad (model "deep"),
      lensBrief =
        [wft|
        Perform the deep pass: correctness, security, performance, structure,
        tests, and documentation. Walk them in that order and say something
        about each -- a heading with "nothing found" is an answer, and a
        heading you skipped is not.

        {schema}

        {reading}|]
    }
  where
    schema = findingSchema
    reading = codeIsTheArtefact

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One ladder builder, four rungs.
--
-- Two inputs the operator gives. @scope@ is @deep-review.md@ Step 1's
-- @$ARGUMENTS@ — a git ref, a range, or empty for the uncommitted changes — and
-- it becomes the /argv/ of the snapshot command rather than a string a model
-- interprets; @paths@ is the file list, one per line, and it selects the roster
-- and the linters in Haskell.
--
-- And two the __runner__ gives: @run.engine@ and @run.sentinel@
-- ('Agentic.Workflow.runFactSentinel'), which is what the probe below now rests
-- on. It stops a whole review when it fails, so the premise it tests had better
-- be one somebody established: before the runner generated a line per run,
-- nothing did, and the probe answered the same on an inheriting runner as on a
-- clean one.
--
-- The shape, top to bottom: freeze one snapshot; probe for parent history and
-- decide it for free; on a verified probe, collect the receipts, fan out over
-- the rung's roster with the snapshot and the receipts spliced into every
-- member, fold to a document, consolidate under a synthesis that must account
-- for the blocks, decide its refusal for free, and end in one report function
-- whichever way the two decisions went.
--
-- Three endings, three provenance lines, __one__
-- 'Workflows.Report.reportFn' — so no ending can quietly describe itself as
-- another.
reviewLadder :: Tier -> Parameterized
reviewLadder t =
  taking
    ( input "scope"
        :> input "paths"
        :> input "run.engine"
        :> input "run.sentinel"
        :> noInputs
    )
    \scopeArg pathsArg engine sentinel ->
      let files = pathsOf pathsArg
          attestation = independenceAttestation sentinel
          revs = T.words scopeArg
          roster = tierRoster t files
          dossier = tierDossier t revs files
          -- Derived from the roster the panel is ACTUALLY built from, and not
          -- from the default one: `refusingSynthesis` splices both the block
          -- count and the reviewer table, so a synthesis given the default
          -- roster would be accounting for blocks a run with
          -- `--input-arg paths=` never produced — and the free completeness
          -- decider below would be reading an answer to the wrong question.
          synthesis = synthesisBrief roster
       in defining reportTable W.do
            -- The frozen snapshot: one receipt the world authored, bound once,
            -- spliced into every member below.
            snapshot <- ask (gitDiff revs) [wf|{snapshotBrief}|]

            -- Independence, once, where three corpus files spell it three ways.
            -- A receipt, then a free decider, then a total branch.
            attested <- ask (broad (model "independence")) [wf|{attestation}|]
            independent <- tested historyAbsent attested

            if independent
              then W.do
                -- The deterministic evidence. Receipts, not claims.
                facts <- panelText [(label, ask p [wf|{dossierBrief}|]) | (label, p) <- dossier]

                -- The panel. One question per roster row; every brief carries the
                -- derived sibling table, the receipts and the one finding schema.
                found <- panelText (zip (lensNames roster) (withEvidence roster blockClosing snapshot facts))

                -- The consolidation, which must account for every block it was
                -- promised before it is allowed to rank anything.
                consolidated <- ask (reasoning (model "synthesis")) [wf|
                    {synthesis}

                    {found}|]

                -- `deep-review` Step 5's completeness check, for zero questions.
                short <- tested incompleteFanOut consolidated

                if short
                  then W.do
                    call_ reportFn (arg shortFanOutNote :> arg consolidated :> noArgs)
                    stop
                  else W.do
                    call_ reportFn (arg (tierProvenance t roster engine) :> arg consolidated :> noArgs)
                    stop
              else W.do
                -- Stop and report the review incomplete, rather than dispatch or
                -- claim independent passes.
                call_ reportFn (arg notIndependentNote :> arg snapshot :> noArgs)
                stop

-- | The canned replies a @--scripted@ run of a rung answers from.
--
-- __The keys are the defines themselves.__ Every member's question opens with
-- its own 'Workflows.Panels.lensBrief', the snapshot's with 'snapshotBrief', the
-- probe's with 'Workflows.Rubrics.Discipline.independenceAttestationKey' and the
-- consolidation's with 'synthesisBrief' — so each key below is a prefix of the
-- rendered prompt __by construction__ rather than by proofreading. The roster
-- rows are derived from the very table 'tierRoster' builds the panel from.
--
-- The probe's key is the __attestation up to this run's own sentinel line__,
-- which is the same rule and not an exception to it: the prompt's every byte
-- before the run fact is constant, the run fact is last, and a scripted table
-- matches by prefix. A key that included a run-unique value could never match
-- twice.
--
-- The table is built at the empty file list, which is the invocation
-- @ci\/workflows.sh@ prices and runs. A scripted run given a real
-- @--input-arg paths=@ falls through to
-- @'Agentic.Exec.scriptedDefault'@ for the language members __and for the
-- consolidation__ — the latter because 'synthesisBrief' is derived from the
-- roster that will actually run, so a fan-out the file list widened changes the
-- key here by changing the block count and the reviewer table. Both fall-throughs
-- echo the prompt, which is harmless, and the run still exits 0.
--
-- __The probe's row is the load-bearing one.__ Without it the echoed prompt's
-- last non-empty line is this run's sentinel rather than @PARENT_HISTORY_ABSENT@
-- — which is the honest answer to an echo, and the reason the answer matters at
-- all — so the free decider says \"not independent\", and
-- the scripted run exercises the arm that reviews nothing. With it the run walks
-- the whole pipeline. Both arms exit 0, and that is the point of writing the
-- failing one.
reviewScript :: Tier -> [(Text, Text)]
reviewScript t =
  [ (snapshotBrief, snapshotAnswer),
    (independenceAttestationKey, "PARENT_HISTORY_ABSENT"),
    (dossierBrief, dossierAnswer),
    (synthesisBrief roster, consolidatedAnswer)
  ]
    <> [(lensBrief l, findingFrom (lensName l)) | l <- roster]
  where
    roster = tierRoster t []

    snapshotAnswer =
      "diff --git a/config.py b/config.py\n\
      \@@ -1,2 +1,2 @@\n\
      \-def read_config(path):\n\
      \-    return json.load(open(path))\n\
      \+def read_config(path):\n\
      \+    return eval(open(path).read())"

    dossierAnswer = "config.py"

    findingFrom n =
      "### [HIGH] eval on file contents\n\
      \- **File**: config.py#L1-L2\n\
      \- **Category**: Security\n\
      \- **Confidence**: 90\n\
      \- **Problem**: the configuration loader evaluates the file it reads.\n\
      \- **Impact**: any writer of that file executes code in this process.\n\
      \- **Fix**: parse with json.load or ast.literal_eval.\n\
      \(reported by the "
        <> n
        <> " pass)"

    -- Deliberately does NOT open a line with `INCOMPLETE:`: the scripted run
    -- takes the complete arm, and the other arm is reached by deleting this row.
    consolidatedAnswer =
      "# Code Review Report\n\
      \\n\
      \All blocks accounted for.\n\
      \\n\
      \## CRITICAL\n\
      \(none)\n\
      \\n\
      \## HIGH\n\
      \- config.py#L1-L2 — eval on file contents; parse instead. Two reviewers \
      \reached this independently.\n\
      \\n\
      \## Fix order\n\
      \1. config.py#L1-L2 — replace eval with json.load; verify with `pytest \
      \tests/test_config.py`."
