-- |
-- Module      : Workflows.Partner
-- Description : The two-agent partnership — one reviewing half with two
--               settings, and the draining half that consumes what it writes.
--
-- == The map: old Markdown -> new program
--
-- +--------------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@            | here                                                      |
-- +======================================+===========================================================+
-- | @commands\/partner-reviewer.md@      | @partner-reviewer@ — the observation contract, over        |
-- |                                      | @heavy-review@'s seven passes, which is the review command |
-- |                                      | that file names                                            |
-- +--------------------------------------+-----------------------------------------------------------+
-- | @commands\/partner-collaborator.md@  | @partner-collaborator@ — the same contract over            |
-- |                                      | @deep-review@'s roster, which is the review command /that/ |
-- |                                      | file names, plus the ideation pass as @drawing 3@          |
-- +--------------------------------------+-----------------------------------------------------------+
-- | @commands\/partner-cleanup.md@       | @partner-cleanup@ — the drain, two rounds, each behind a   |
-- |                                      | free test over a @find@ receipt, then @call_ commitFn@     |
-- +--------------------------------------+-----------------------------------------------------------+
-- | @commands\/heavy-review.md@,         | @'Workflows.Review.Ladder.tierRoster'@ at @Heavy@ and at   |
-- | @commands\/deep-review.md@           | @Deep@ — the rosters, not a prose reference to a command   |
-- +--------------------------------------+-----------------------------------------------------------+
-- | @commands\/commit.md@                | @'Workflows.Git.Commit.commitFn'@, called                   |
-- +--------------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The duplication this ends, and the drift it had already caused
--
-- @doc\/design.md@ §7.2 row 39: @partner-reviewer.md@ and
-- @partner-collaborator.md@ are \"an ~85 % duplication that has __already
-- drifted__ — a differing Category enum, a typo on one side\". Both are true of
-- the files as they stand: the collaborator's contract carries @| Idea@ and the
-- reviewer's does not, which is correct, and the collaborator's setup section
-- also carries \"using etiher @obr@\", which is not.
--
-- Here there is one contract ('observationContract'), one category vocabulary
-- ('observationCategories'), and the @Idea@ row is __derived__ from the one
-- setting that distinguishes the two commands — so the enum cannot differ
-- between them, and a category added reaches both by being added.
--
-- __The two flags @doc\/design.md@ §8 names__ are 'ideasOn' and the role itself:
-- @ideas=off@ is @partner-reviewer@, @ideas=on@ is @partner-collaborator@, and
-- @Cleanup@ is the other half of the partnership. Three commands, one program,
-- two settings — and three rows, because the three differ in roster, in receipts
-- and in price, which is what @README@ house rule 7 says a row differs in.
--
-- == The leveling-up, item by item
--
--   1. __\"Use @heavy-review@ if available, else review manually\" becomes a
--      roster.__ Both files delegate to a review command by name and then supply
--      a fallback for its absence. The command is
--      "Workflows.Review.Ladder" and its rungs are values, so
--      'partnerRoster' /is/ @heavy-review@'s seven passes at @partner-reviewer@
--      and @deep-review@'s roster at @partner-collaborator@ — the difference
--      between the two files, which in the corpus is a word in a sentence, is
--      one argument here. The fallback disappears because the passes cannot be
--      unavailable.
--
--   2. __\"Three wild ideas\" is @drawing 3@.__ §7.2 row 38: the idea panel is
--      \"@drawing 3@ on one lateral party, which is what \'three wild ideas\'
--      /means/\". Three draws of one prompt are three questions, priced apart,
--      each answered without sight of the others — which is the whole of what
--      the corpus's numbered ideation list is asking for and cannot say.
--
--   3. __The observation count is a receipt.__ Both files end by asking the
--      reviewer to report \"the number of actionable observations written\" and
--      \"the observation filenames written\" — a report by the writer about its
--      own writing. Here the directory is read back with
--      @'Workflows.Evidence.mdFilesIn'@ and
--      'Workflows.Deciders.observationsPending' decides it for zero questions, so
--      the arm that wrote nothing says so and cannot say otherwise.
--
--   4. __The watch loop dissolves, and the unit is one commit.__ Both reviewing
--      files are a polling loop: read the last-reviewed SHA from
--      @.git\/partner-reviewer\/@, sleep fifteen seconds, compare against @HEAD@.
--      A program here is a /bounded, priced/ run — there is no sleep, no
--      persistent watcher state, and nothing to poll — and §7.2 row 38 says the
--      unit plainly: \"two panels over __one commit__\". So the commit is an
--      input, the run reviews it, and the cadence is the operator's @wf run@ or a
--      timer outside this repository. What the loop bought — never reviewing a
--      commit twice, never flooding on a rebase — is a fact about a file in
--      @.git@, and a program that priced it would be pricing somebody else's
--      bookkeeping.
--
--   5. __The rescan-before-committing is a decider, not a discipline.__
--      @partner-cleanup.md@ says to rescan for newly arrived observations before
--      committing, twice, in two sections. Here each round is entered behind
--      'Workflows.Deciders.observationsPending' over a fresh @find@ receipt —
--      zero questions per round — which is
--      "Workflows.Checklist"'s shape and, as there, the honest reading of a
--      design cell that sketched a @revisingOn@. See the note below.
--
-- == How to invoke it so the review is somebody else's
--
-- A partner review is worth having because it is /not/ the party that wrote the
-- code. Nothing in this module can secure that: the program says which questions
-- to put and to whom, and where they are put is the invocation's business. So it
-- is written here, where an operator reading the row will meet it.
--
-- Two spellings give a reviewing run a context the work does not share:
--
--   * @wf run partner-reviewer --session \<pane\>@ — a live @agent-deck@ pane
--     __other than the one doing the work__. Every question of the run shares
--     that one pane, which is fine and is the point: what matters is that the
--     pane is not the work's. Naming the working pane here is the failure mode,
--     and it is a quiet one, because the run succeeds and reads like a review.
--   * @wf run partner-reviewer --engine acp@ — an adapter this run starts, with
--     @acpFreshPerQuestion@ opening a session before every question. Each seat
--     then sees its own prompt and nothing else, which is the stronger of the
--     two.
--
-- The same holds of @partner-collaborator@, and of @partner-cleanup@ for a
-- different reason: the cleanup /edits/, so it wants the working tree, and it is
-- the one of the three that has no business being put somewhere else.
--
-- __Neither spelling is checked here, and the report says which was used.__
-- @run.engine@ ('Agentic.Workflow.runFacts') reaches this row's report, so a
-- reader can see whether the run shared one conversation; the row that turns that
-- fact into a refusal is @wiggum@, because there a separate evaluator is a clause
-- of a definition of done rather than a quality of a report.
--
-- == Two honest notes
--
-- __@partner-cleanup@ is not a @revisingOn@, and §7.2 row 37 sketches one.__ That
-- cell reads \"the drain loop is @revisingOn@ settled by an @ls@ receipt read by
-- a decider\". It is not writable, for the reason
-- "Workflows.Checklist"'s header sets out at length and
-- "Workflows.Gates"' haddock states as grammar: a bounded revision's review
-- clause is a __verdict__ question, so a @'Agentic.Workflow.decide'@ — which
-- yields a flag — cannot be one, and a revision's body is exactly one review and
-- one amendment, so a per-round pipeline (assign the batch, then review what came
-- back) cannot stand in one. The replacement is the one "Workflows.Gates" names:
-- K unrolled rounds, each a @call_@ behind a @decide@ on the previous round's
-- receipt. K is 2 here, which is @partner-cleanup.md@'s own two rescans, and the
-- design's \"zero questions per trip\" survives intact — it is the /decider/ that
-- is free, in either spelling.
--
-- __\"The sub-agent must not commit\" is half structural, and this says which
-- half.__ §7.2 row 37 reads: \"\'the sub-agent must not commit\' becomes
-- @CodeText@, which has no write authority\". The part that is exactly right is
-- the __review__: the main agent's inspection of what came back is an
-- @'Agentic.Workflow.ask'@ at @'Agentic.Raw.CodeText'@ over a @git diff@ receipt,
-- and @Agentic.Acp.permissionByCode@ grants it no write authority at all, so the
-- reviewing half of that loop /cannot/ commit whatever it is told.
--
-- The part that is not is the __worker__: addressing an observation means editing
-- files, so it is an @'Agentic.Workflow.act'@, and an act at
-- @'Agentic.Raw.CodeAck'@ has full write authority — including @git commit@. No
-- type keeps an editing party away from the index. What replaces the corpus's
-- hope is arrangement rather than authority: the program itself calls
-- @'Workflows.Git.Commit.commitFn'@, exactly once, after the drain has finished
-- and only on the arm where the directory came back empty — so a run that ends
-- committing has committed through the standing discipline, and the round's
-- instruction not to commit is a request whose /purpose/ the program no longer
-- depends on.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Partner
  ( -- * The roles
    PartnerRole (..),
    partnerRoleName,
    partnerDoc,
    ideasOn,

    -- * The program
    partnerProgram,
    partnerScript,

    -- * The contract, once, where the corpus has it twice
    observationCategories,
    observationContract,

    -- * The three defines a review that publishes observations elsewhere holes
    --
    -- $borrowed
    defectClosing,
    publishBrief,
    publishedBrief,

    -- * The roster each reviewing role fans out over
    partnerRoster,

    -- * The functions
    cleanupRoundFn,
    partnerReportFn,
    partnerTable,

    -- * The two places an absent input is given a meaning
    observationsDir,
    commitRev,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Git.Commit (commitFn)
import Workflows.Prelude
import Workflows.Review.Ladder (Tier (Deep, Heavy), tierRoster)
import Prelude

-- $borrowed
--
-- The observation-file contract is already this module's to state once
-- ('observationContract'); these three are the rest of the same contract — what
-- a defect pass is told to report, what the publishing act is told above the
-- contract, and how the directory is read back. "Workflows.Duet" runs a
-- four-seat review /inside/ a work loop and publishes through exactly this
-- protocol, so it holes these three rather than saying the same thing again in
-- its own words: two spellings of one contract is a contract that drifts, and
-- the drift would be invisible because each spelling would pass its own canned
-- table.

-- ---------------------------------------------------------------------------
-- The roles
-- ---------------------------------------------------------------------------

-- | The three commands of the partnership, as one program's three settings.
data PartnerRole
  = -- | @commands\/partner-reviewer.md@ — defects only, over
    -- @heavy-review@'s passes.
    Reviewer
  | -- | @commands\/partner-collaborator.md@ — defects over @deep-review@'s
    -- roster, and the ideation pass beside them.
    Collaborator
  | -- | @commands\/partner-cleanup.md@ — the other half: drain the directory
    -- the two above fill, then commit once.
    Cleanup
  deriving (Eq, Show)

-- | The name the operator types — the owner's own three, unchanged.
partnerRoleName :: PartnerRole -> Text
partnerRoleName Reviewer = "partner-reviewer"
partnerRoleName Collaborator = "partner-collaborator"
partnerRoleName Cleanup = "partner-cleanup"

-- | The one line @wf list@ prints beside a role.
partnerDoc :: PartnerRole -> Text
partnerDoc Reviewer =
  "partner-reviewer.md: heavy-review's passes over one commit, published as observation files"
partnerDoc Collaborator =
  "partner-collaborator.md: deep-review's roster plus three drawn ideas, as observation files"
partnerDoc Cleanup =
  "partner-cleanup.md: two drain rounds behind a free `find` test, then one `commitFn` call"

-- | @ideas=on@, the first of the two settings @doc\/design.md@ §8 names.
--
-- __Tier 1__, and it does two things: it adds the ideation panel, and it adds the
-- @Idea@ row to 'observationCategories' — so the enum the two corpus files have
-- already drifted on is derived from the one fact that distinguishes them.
ideasOn :: PartnerRole -> Bool
ideasOn Collaborator = True
ideasOn _ = False

-- ---------------------------------------------------------------------------
-- The two places an absent input is given a meaning
-- ---------------------------------------------------------------------------

-- | The observations directory.
--
-- __Tier 1__: the fact is in the invocation. @partner-cleanup.md@'s @## Scope@
-- says \"interpret @$ARGUMENTS@ as the observations directory; if empty, use
-- @obr@ if it is being used, otherwise use @doc\/observations\/@\" — so unlike
-- every other absent input in this tree, this one has a documented default, and
-- it is taken. @obr@ is not: it is a tool outside this repository with no argv
-- here, and a program that named it would be pointing at something the printed
-- plan cannot show.
observationsDir :: Text -> Text
observationsDir d
  | T.null (T.strip d) = "doc/observations"
  | otherwise = T.dropWhileEnd (== '/') (T.strip d)

-- | The commit under review.
--
-- __Tier 1__, and the default is @partner-reviewer.md@'s own: \"empty: start
-- from the current @HEAD@\". A run given no commit reviews @HEAD@, which is what
-- both files do when they start.
commitRev :: Text -> Text
commitRev c
  | T.null (T.strip c) = "HEAD"
  | otherwise = T.strip c

-- ---------------------------------------------------------------------------
-- The contract, once
-- ---------------------------------------------------------------------------

-- | The @**Category**@ vocabulary of the observation file, derived.
--
-- /Source:/ @commands\/partner-reviewer.md@'s @## Observation File Contract@
-- (six categories) and @commands\/partner-collaborator.md@'s (the same six plus
-- @Idea@). One list, and the seventh row appears exactly when the ideation pass
-- does.
--
-- __Deliberately not @'Workflows.Rubrics.Finding.categories'@__, and the reason
-- is worth one line: that vocabulary is the /review report's/ — ten rows
-- including @Simplification@ and @Dead Code@ — and this one is the /observation
-- file's/, six rows including @Maintainability@, which the review vocabulary
-- does not carry. They are two artefacts with two schemas. What this module ends
-- is the drift between the two partner commands; the drift between them and
-- @Rubrics.Finding@ is not drift, it is a difference, and
-- "Workflows.Rubrics.Finding"'s header is where the review one is argued.
observationCategories :: Bool -> [Text]
observationCategories ideas =
  [ "Bug",
    "Security",
    "Performance",
    "Test Coverage",
    "Documentation",
    "Maintainability"
  ]
    <> ["Idea" | ideas]

-- | The observation file contract, once, where the corpus has it twice.
--
-- /Source:/ both files' @## Observation File Contract@ and @## Atomic Write
-- Requirement@ sections, whose shape is carried exactly — the header block, the
-- five prose sections, the timestamp filename scheme, and the temp-then-rename
-- rule. The category line is derived from 'observationCategories'; the @Idea@
-- reading of the five sections appears only when the ideation pass does.
observationContract :: Bool -> Text
observationContract ideas =
  [wft|
  Publish each finding as its own observation entry: one file per finding, and
  a file must be COMPLETE before it appears in the observations directory.

  Use this shape exactly:

  # Observation: <short imperative title>

  - **Source commit**: `<full-sha>`
  - **Observed at**: `<ISO-8601 UTC timestamp with milliseconds>`
  - **Severity**: Critical | High | Medium | Low
  - **Category**: {categoryLine}
  - **File**: `path/to/file.ext:line`
  - **Confidence**: <0-100>

  ## Problem

  <Concrete description of what is wrong.>

  ## Impact

  <Why this matters.>

  ## Suggested Fix

  <Specific remediation. Include code when useful.>

  ## Verification

  <Tests, commands, or manual checks that should prove the fix.>

  The filename is the full ISO timestamp, in UTC, and nothing else:
  `<dir>/YYYY-MM-DDTHH:MM:SS.mmmZ.md`. No counters, no titles, no SHA
  fragments. If a name already exists for the current millisecond, wait for the
  next millisecond and generate a new one.

  ATOMIC WRITE. Never stream a partial observation into its final pathname.
  Build the whole content first; write it to a hidden temporary file in the same
  directory on the same filesystem, for example `.<stamp>.md.tmp.<pid>`; flush
  and close it; then rename it into place. If the final path already exists,
  discard the temp file and try again with a fresh timestamp. A half-written
  observation is worse than a missing one, because the draining half will read
  it.

  Do not stage and do not commit anything. This half of the partnership
  produces coordination files and nothing else.{ideaReading}|]
  where
    categoryLine = T.intercalate " | " (observationCategories ideas)
    ideaReading :: Text
    ideaReading
      | not ideas = ""
      | otherwise =
          "\n\nFor a `Category: Idea` file, keep the same headers and read them \
          \as: **Problem** = the idea and the gap it addresses, **Impact** = why \
          \it is worth doing, **Suggested Fix** = a concrete first step, \
          \**Verification** = how to validate that it pays off. Tie it to the \
          \commit that inspired it, and give it the severity its value deserves \
          \-- usually Low."

-- ---------------------------------------------------------------------------
-- The roster each reviewing role fans out over
-- ---------------------------------------------------------------------------

-- | The review each reviewing role runs, as the roster of the command that role
-- names.
--
-- /Source:/ @partner-reviewer.md@ — \"use the local @heavy-review@ command\" —
-- and @partner-collaborator.md@ — \"use the local @deep-review@ command or skill
-- if available\". One word apart in the corpus, one argument apart here.
--
-- __House rule WR-1__: the @paths@ input shapes only the @Deep@ roster's
-- language members, and @'Workflows.Review.Ladder.tierRoster'@ at the empty file
-- list is already the four required lenses plus the performance pass — never
-- empty — so @''@ means the default roster and @'Agentic.Workflow.panel'@ is
-- never handed @[]@.
partnerRoster :: PartnerRole -> [Text] -> Roster
partnerRoster Reviewer _ = tierRoster Heavy []
partnerRoster Collaborator files = tierRoster Deep files
partnerRoster Cleanup _ = []

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the commit receipt is introduced as.
--
-- /Source:/ both files' @## Review Procedure@ step 3, which names this exact
-- command as what to read when the review tool will not take a @\<sha\>^!@
-- argument. Here it is the only reading, which is the point — see
-- @'Workflows.Evidence.gitShowCommit'@.
commitBrief :: Text
commitBrief =
  [wft|
  One commit, with its stat and its patch, as `git show` wrote it. This is the
  whole subject of this review: the commit before it is context you do not
  have, and the commit after it does not exist yet.|]

-- | What every defect member is told about the shape of its block, and what it
-- must leave alone.
--
-- /Source:/ both files' @## Review Procedure@ items 4 to 6 — the actionable-
-- defect list, the exclusion of coordination-only changes, and the
-- prefer-silence rule, which is the best sentence in either file.
defectClosing :: Text
defectClosing =
  [wft|
  Report your findings and nothing else. Your answer is one block of a document
  whose other blocks are your siblings', each fenced under its own name.

  Report only ACTIONABLE DEFECTS: correctness bugs, security problems,
  regressions, missing required tests, broken public contracts, unsafe
  migrations, serious performance issues, and documentation errors that could
  mislead a future change.

  Exclude coordination-only changes -- anything under the observations
  directory itself -- unless they affect executable behaviour or this workflow.

  Drop vague preferences, style nits, low-confidence concerns and duplicates.
  Prefer ZERO observations over noisy observations: this review's output
  becomes files somebody else has to read and drain, so a finding that is not
  worth acting on is worse here than elsewhere.|]

-- | @commands\/partner-collaborator.md@'s @## Ideas and Suggestions@ section,
-- as the brief of one drawn question.
--
-- /Source:/ that section, whole: the opt-in-on-quality rule, the five-step
-- lateral procedure, and its closing constraint. The section's own numbered list
-- asks for \"three wild ideas\" from one reading; here the /question/ is drawn
-- three times, so the three are three independent answers rather than three
-- items one answer was asked to produce.
ideationBrief :: Text
ideationBrief =
  [wft|
  Beyond defects, surface one genuinely useful new idea sparked by the commit
  below: a better design, a missing capability, a follow-on optimisation, a
  simpler formulation, or where this work could go next.

  Be playful and think laterally. Instead of refining the obvious solution
  head-on, move sideways: reframe the problem, attack it from an oblique angle,
  and let an unexpected association suggest an approach a straight-line
  analysis would never reach. Work this way:

  1. Identify a hidden assumption the commit takes for granted -- about the
     data, the hardware, the workflow, the order of operations, what "must" be
     true.
  2. Invert that assumption and follow where it leads.
  3. Reach for a technique from an unrelated discipline -- biology, logistics,
     music, finance, game design -- and apply it here.
  4. Explain why the seemingly crazy result might actually work: the concrete
     mechanism that makes it plausible, not the vibe.

  This is strictly opt-in on quality. Give the idea ONLY if it is concrete,
  grounded in the code you just read, and clearly valuable. If you have
  nothing, or what you have is weak, reply with exactly

    NO IDEA WORTH KEEPING

  and nothing else. Silence is better than noise, and padding a review with a
  speculative direction to look thorough is the failure this instruction
  exists to prevent.

  An idea never displaces or dilutes an actionable defect: they are different
  things and they are collected separately.|]

-- | What the publishing act is told, above the contract.
publishBrief :: Text
publishBrief =
  [wft|
  Publish the findings below as observation entries, in the observations
  directory named for you, one file per finding.

  Judge each finding against the contract before writing it: a block that
  reported nothing produces no file, and a finding that does not name a file
  and a line produces no file either. Do not merge two findings into one
  observation and do not split one into two.

  When you are done, reply DONE.|]

-- | What the closing directory receipt is introduced as.
--
-- /Source:/ both files' @## Reporting@ section, which asks the writer how many
-- files it wrote. These bytes are the answer, and they are not the writer's.
publishedBrief :: Text
publishedBrief =
  "The observation files that now stand in the directory, one path per line, as \
  \`find` reports them. This is the count and the filenames both reporting \
  \sections ask for, and it is a receipt rather than a claim."

-- | @commands\/partner-cleanup.md@'s @## Sub-Agent Assignment@ block, whole.
--
-- /Source:/ that fenced @text@ block, verbatim in substance, with its six
-- numbered steps and its handoff demand. The two clauses about /spawning/ a
-- sub-agent and about parallelising independent batches are not carried, and the
-- reason is narrower than \"independent by construction\" — which is what this
-- said before, and which is false under @--session@.
--
-- What holds by construction is that a question here is a __separate question__:
-- 'Agentic.Workflow.panel' puts each member once, in its own right, and no
-- member is told what another said. Whether it is put in a separate /context/ is
-- the engine's business and not the program's. Under @--engine acp@ it is —
-- @acpFreshPerQuestion@ opens a @session\/new@ before every question — and under
-- @--session \<pane\>@ it is not: every question of the run lands in one live
-- @agent-deck@ conversation, in program order, each seat having read the ones
-- above it. @run.engine@ ('Agentic.Workflow.runFacts') is the authority on which,
-- and 'Agentic.Workflow.sharesOneSession' is how a program that must not run
-- that way finds out (@wiggum@ does; this row reports rather than refuses).
--
-- So the clauses are dropped because the /mechanism/ they ask for exists here and
-- is priced ("Workflows.Panels" says where @skills\/parallelize@ dissolves), not
-- because the context separation they wanted comes free.
assignmentBrief :: Text
assignmentBrief =
  [wft|
  You are addressing partner review observations in this repository. Process
  the observation files listed below, in the order they are given.

  For each observation:

  1. Read it completely.
  2. Verify that the finding is still applicable to the code as it now stands.
  3. If it is valid, implement the smallest correct fix, and add or update a
     focused test where the risk warrants one.
  4. If it is obsolete or a false positive, record the evidence for that
     instead of changing code.
  5. Remove the observation file only after the item has been addressed or
     proven inapplicable.
  6. Do not commit. Leave every change in the working tree for review.

  Then write a concise handoff: each observation file, its resolution, the
  files you changed, and the verification you performed.

  {discipline}

  When you are done, reply DONE.|]
  where
    discipline = fixAllRule

-- | What the round's own review receipt is introduced as.
reviewEvidenceBrief :: Text
reviewEvidenceBrief =
  "The working tree's diff, as `git diff` wrote it, now that the round has \
  \finished. This is what the round actually changed, as against what it said it \
  \changed."

-- | @commands\/partner-cleanup.md@'s @## Main-Agent Review@ section, as the one
-- question in this program that reads without any authority to write.
--
-- /Source:/ that section's five items, compressed to the three that are about
-- /judgment/. Its items 4 and 5 — \"ensure no captured observation files remain\"
-- and \"rescan for newly arrived observation files\" — are deliberately absent:
-- they are the program's, they are @find@ receipts read by a decider, and asking
-- a model to confirm them is what the corpus does instead of testing them.
mainReviewBrief :: Text
mainReviewBrief =
  [wft|
  Review what the round just did. You are reading, not writing: report only,
  and do not edit, stage or commit anything.

  Against the diff and the round's own handoff:

  - Confirm that every observation file in the batch was either removed or
    explicitly justified as inapplicable, and name any that were neither.
  - Re-read any fix that looks uncertain and say what makes it uncertain. Do
    not accept a superficial deletion: an observation file removed without a
    corresponding change in the diff is the failure this review exists to
    catch.
  - Say which verification commands the handoff names, which of them the diff
    makes plausible, and which further check the risk warrants.

  Answer with those three findings and nothing else.|]

-- | The brief the report act is given.
partnerWriteBrief :: Text
partnerWriteBrief =
  [wft|
  Write the report for a partner run. It is read by whoever is running the
  other half of the partnership.

  Open with the provenance line you were given, verbatim, on its own line.
  Then, from the evidence below and nothing else: what was reviewed or
  drained, what now stands in the observations directory -- by filename, from
  the receipt -- and what the other half should do next.

  Do not describe an observation the evidence does not carry, and do not count
  files the receipt does not list. Then reply DONE.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The reviewing arm where files were written.
--
-- __\"Each pass answering independently\" is now what the program can promise,
-- and no more.__ It used to say the passes answered \"independently over the same
-- bytes\", which reads as a claim about their /contexts/ and is one this module
-- cannot make: a 'Agentic.Workflow.panel' puts each member once and tells no
-- member what another said, and that is separateness of /question/. Whether it is
-- separateness of context is the engine's business — see this module's header for
-- the two invocations that get it — and 'onThisRun' appends the fact rather than
-- letting the word carry it.
publishedNote :: PartnerRole -> Text
publishedNote role =
  "Provenance: one commit was read as a `git show` receipt and reviewed by "
    <> rosterWord
    <> ", each pass put as a separate question over the same bytes and told \
       \nothing of what the others said"
    <> ideaWord
    <> ". The observation files were then published under the standing contract, \
       \and the directory was read back with `find`: the receipt below is the \
       \count and the filenames, and it is not the writer's account of its own \
       \work. Nothing was staged and nothing was committed."
  where
    rosterWord
      | role == Reviewer = "`heavy-review`'s seven passes"
      | otherwise = "`deep-review`'s roster"
    ideaWord
      | ideasOn role = ", beside three separately drawn ideation passes"
      | otherwise = ""

-- | The run's own engine, appended to whichever ending was reached.
--
-- __Three roles, five endings, one statement about the run.__ Same shape and
-- same reason as @wiggum@'s: the endings differ in what happened and not in what
-- this run /was/, so the fact goes on once here instead of five times in five
-- notes that would then have to be kept in step.
--
-- __Why this row owes the reader it.__ A partner review is worth having because
-- it is not the party that wrote the code, and nothing in this module can secure
-- that — the invocation decides it (see the module header). @run.engine@
-- ('Agentic.Workflow.runFacts') is the runner's own statement of which invocation
-- was made, and without it the report's word \"separate\" would be the only thing
-- a reader had, which is a word and not a fact.
--
-- Free in both folds: an input is a define, so this adds no question and no path.
onThisRun :: Text -> Text -> Text
onThisRun engine note =
  [wft|
  {note} This run's engine, from the runner and from no party asked above: {engine}.
  A new session per question means every question above was put to a party
  that had seen no other; one session for the run means they all landed in
  one conversation, in program order, each having read what came before --
  and if that conversation is also where the reviewed work was done, a review
  in it is the work reviewing itself. Say which of the two this was, in one
  sentence, before anything else.|]

-- | The reviewing arm where nothing was written.
--
-- /Source:/ both files' \"prefer zero observations over noisy observations\",
-- which is an instruction with no ending. This is the ending.
nothingPublishedNote :: Text
nothingPublishedNote =
  "Outcome: NOTHING PUBLISHED. The commit was reviewed and the observations \
  \directory was read back with `find`, which listed no file -- so either every \
  \pass came back clean or every finding was judged not worth an observation. \
  \That is a legitimate result and this workflow's own rule prefers it to a \
  \noisy one: report the commit as reviewed and clean, and do not describe a \
  \finding that produced no file."

-- | The draining arm where the directory was already empty.
nothingToDrainNote :: Text
nothingToDrainNote =
  "Outcome: NOTHING TO DO. The observations directory was read before any work \
  \was planned and `find` listed no regular, non-hidden Markdown file in it, so \
  \no round ran, nothing was asked of anybody and nothing was committed. Report \
  \that, and name the directory that was read."

-- | The draining arm where the directory came back empty.
drainedNote :: Text
drainedNote =
  "Outcome: DRAINED. Every observation the directory held was addressed or \
  \proven inapplicable, the directory was re-read from disk and `find` listed \
  \nothing -- a test over the filesystem's own bytes and not a claim by whoever \
  \did the work -- and the cleanup was then committed as ONE commit through the \
  \standing commit discipline. If the reviewing half has since reacted to that \
  \commit, another cleanup cycle is available; say so, and do not start it."

-- | The draining arm where observations survived both rounds.
--
-- /Source:/ the ending @partner-cleanup.md@ cannot have: its loop says \"repeat
-- until the observations directory has no regular, non-hidden @*.md@ files\", and
-- a prose loop has no arm for not getting there.
notDrainedNote :: Text
notDrainedNote =
  "Outcome: OBSERVATIONS REMAIN. Both rounds this run was given have been spent \
  \and `find` still lists observation files in the directory. NOTHING WAS \
  \COMMITTED: this workflow's rule is exactly one commit for a completed batch, \
  \and the batch is not complete. Name every file still standing, say what the \
  \last round said about each, and say what the next run would have to start \
  \with."

-- | What this caller asks of the commit decomposition.
--
-- /Source:/ @commands\/partner-cleanup.md@'s @## Commit Rules@, including its
-- message shape, which is carried because it is the one thing that section is
-- specific about.
cleanupCommitStyle :: Text
cleanupCommitStyle =
  [wft|
  This is a cleanup of partner review observations, and it is ONE commit for
  the whole batch -- not one per observation. Commit only the cleanup changes
  and the removal of any tracked observation files; do not add untracked
  observation files to the repository.

  The message is of this shape:

    Address partner review observations

    Resolve observations from <first timestamp> through <last timestamp>.

  with the timestamps taken from the filenames the batch actually held.|]

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | One drain round: assign the batch, then review what came back.
--
-- Three statements, and it is called twice — @partner-cleanup.md@'s loop and its
-- rescan. A function rather than two copies for "Workflows.Report"'s reason: the
-- second call site is free and the two rounds cannot drift.
--
-- __The round answers @'Agentic.Raw.CodeText'@__, and that is the half of §7.2
-- row 37 that /is/ structural: what it answers with is the main agent's review,
-- and a question at @text@ has no write authority under
-- @Agentic.Acp.permissionByCode@ — so the reviewing half of this loop cannot
-- commit what the working half produced, whatever either is told. See the module
-- header for the half that is arrangement rather than authority.
cleanupRoundFn :: Fn '[ 'CodeText, 'CodeText] 'CodeText
cleanupRoundFn =
  function
    "partner.round"
    ( takes @"batch" Text
        . takes @"directory" Text
        $ noParams
    )
    \batch directory -> W.do
      act (tool "observation-worker") [wf|
          {assignmentBrief}

          The observations directory:

          {directory}

          The batch, in the order it is to be processed -- which is
          lexicographic, and therefore chronological, because the filenames are
          timestamps:

          {batch}|]

      changed <- ask (gitDiff []) [wf|{reviewEvidenceBrief}|]

      review <- ask (reasoning (model "cleanup-review")) [wf|
          {mainReviewBrief}

          The batch that was assigned:

          {batch}

          What the round changed:

          {changed}|]
      answer review

-- | The report every ending calls.
--
-- Three parameters, and the middle one is the load-bearing one: the /listing/ is
-- always the @find@ receipt, so every one of the six endings reports the
-- directory's own bytes rather than somebody's count of them. The third is
-- whatever that ending has to show — the defect document at the reviewing roles,
-- the round's review at the draining one — and the arms differ in the first.
partnerReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
partnerReportFn =
  function
    "partner.report"
    ( takes @"provenance" Text
        . takes @"listing" Text
        . takes @"notes" Text
        $ noParams
    )
    \provenance listing notes -> W.do
      act reporter [wf|
          {partnerWriteBrief}

          Provenance:

          {provenance}

          What the observations directory now holds:

          {listing}

          What this run has to show:

          {notes}|]
      done

-- | The table 'partnerProgram' hands @'Agentic.Workflow.defining'@.
--
-- @commitFn@ precedes nothing that calls it from a body — @partner-cleanup@
-- calls it from the program — and the order is otherwise the order of the
-- definitions above.
partnerTable :: [SomeFn]
partnerTable =
  [ SomeFn cleanupRoundFn,
    SomeFn commitFn,
    SomeFn partnerReportFn
  ]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | Three roles, one contract, and a receipt at every ending.
--
-- Three inputs. @commit@ is the revision under review and defaults to @HEAD@;
-- @observations@ is the directory and defaults to @doc\/observations@;
-- @paths@ is the file list, one per line, and it widens
-- @partner-collaborator@'s roster with the language reviewers the commit
-- touches — tier 1, before the program exists.
--
-- And one the __runner__ gives: @run.engine@, which every ending carries through
-- 'onThisRun'. It is spliced and never branched on, so it moves no fold: this row
-- reports how the run was made and leaves what to do about it to the operator who
-- made it.
partnerProgram :: PartnerRole -> Parameterized
partnerProgram role =
  taking
    ( input "commit"
        :> input "observations"
        :> input "paths"
        :> input "run.engine"
        :> noInputs
    )
    \sha obs paths engine ->
      let rev = commitRev sha
          dir = observationsDir obs
          roster = partnerRoster role (pathsOf paths)
          contract = observationContract (ideasOn role)
          stated = onThisRun engine
       in defining partnerTable case role of
            Cleanup -> W.do
              -- The batch, as bytes. Every decision below reads a receipt like
              -- this one, taken fresh.
              batch <- ask (mdFilesIn dir) [wf|{batchBrief}|]
              work <- tested (observationsPending dir) batch

              if work
                then W.do
                  -- Round one: the cleanup loop's first trip.
                  first <- call cleanupRoundFn (arg batch :> arg dir :> noArgs)

                  after <- ask (mdFilesIn dir) [wf|{afterBrief}|]
                  again <- tested (observationsPending dir) after

                  if again
                    then W.do
                      -- Round two: the rescan `partner-cleanup.md` asks for twice.
                      second <- call cleanupRoundFn (arg after :> arg dir :> noArgs)

                      final <- ask (mdFilesIn dir) [wf|{finalBrief}|]
                      left <- tested (observationsPending dir) final

                      if left
                        then W.do
                          call_ partnerReportFn (arg (stated notDrainedNote) :> arg final :> arg second :> noArgs)
                          stop
                        else W.do
                          call_ commitFn (arg final :> arg cleanupCommitStyle :> noArgs)
                          call_ partnerReportFn (arg (stated drainedNote) :> arg final :> arg second :> noArgs)
                          stop
                    else W.do
                      call_ commitFn (arg after :> arg cleanupCommitStyle :> noArgs)
                      call_ partnerReportFn (arg (stated drainedNote) :> arg after :> arg first :> noArgs)
                      stop
                else W.do
                  call_ partnerReportFn (arg (stated nothingToDrainNote) :> arg batch :> arg noRoundRan :> noArgs)
                  stop
            Reviewer -> W.do
              -- One commit, bound once, and every pass below reads these bytes.
              commit <- ask (gitShowCommit rev) [wf|{commitBrief}|]

              defects <- panelText (zip (lensNames roster) (asksOver roster defectClosing commit))

              -- No ideation pass, and that is the whole of `ideas=off`:
              -- `partner-reviewer.md` has no ideation section, so this role does
              -- not ask for one. The two reviewing arms are two blocks for the
              -- reason "Workflows.Threads"' two rungs are: a bind is a statement,
              -- not a value, so a statement one role does not have cannot be a
              -- conditional argument. Every brief, the contract, the receipt, the
              -- decider and the report function are shared.
              act (tool "observations") [wf|
                  {publishBrief}

                  {contract}

                  The observations directory:

                  {dir}

                  The commit these findings are about:

                  {commit}

                  The defect passes:

                  {defects}|]

              written <- ask (mdFilesIn dir) [wf|{publishedBrief}|]
              wrote <- tested (observationsPending dir) written

              if wrote
                then W.do
                  call_ partnerReportFn (arg (stated (publishedNote role)) :> arg written :> arg defects :> noArgs)
                  stop
                else W.do
                  call_ partnerReportFn (arg (stated nothingPublishedNote) :> arg written :> arg defects :> noArgs)
                  stop
            Collaborator -> W.do
              commit <- ask (gitShowCommit rev) [wf|{commitBrief}|]

              defects <- panelText (zip (lensNames roster) (asksOver roster defectClosing commit))

              -- `drawing 3` on one lateral party: three independent answers, not
              -- three items in one. This is the whole of `ideas=on`.
              ideas <-
                panelText
                  [ ("idea-" <> tshow i, ask (lateral (model "ideation") `drawing` toInteger i) [wf|
                        {ideationBrief}

                        The commit:

                        {commit}|])
                  | i <- [1 :: Int, 2, 3]
                  ]

              act (tool "observations") [wf|
                  {publishBrief}

                  {contract}

                  The observations directory:

                  {dir}

                  The commit these findings are about:

                  {commit}

                  The defect passes:

                  {defects}

                  The ideation passes:

                  {ideas}|]

              written <- ask (mdFilesIn dir) [wf|{publishedBrief}|]
              wrote <- tested (observationsPending dir) written

              if wrote
                then W.do
                  call_ partnerReportFn (arg (stated (publishedNote role)) :> arg written :> arg defects :> noArgs)
                  stop
                else W.do
                  call_ partnerReportFn (arg (stated nothingPublishedNote) :> arg written :> arg defects :> noArgs)
                  stop

-- | What the report is told when no round ran.
--
-- A 'Data.Text.Text' argument where the other endings pass a handle, which is
-- what @'Agentic.Workflow.arg'@ accepts either of: the arm that did no work has
-- no review to show, and saying so is better than passing the batch twice.
noRoundRan :: Text
noRoundRan =
  "(No round ran, so there is no review of one. The listing above was the first \
  \and only thing this run read.)"

-- | What the opening batch receipt is introduced as.
batchBrief :: Text
batchBrief =
  "The observation files standing in the directory before any work has been done \
  \to them, one path per line, as `find` reports them. Sorted lexicographically \
  \this is chronological, because every filename is an ISO timestamp."

-- | The same directory, re-read after the first round.
afterBrief :: Text
afterBrief =
  "The same directory, re-read from disk now that the first round has finished. \
  \This is what stands there, not an account of what was done: anything still \
  \listed is still to be addressed, including a file the reviewing half added \
  \while the round was running."

-- | The same directory, re-read after the second round.
finalBrief :: Text
finalBrief =
  "The same directory, re-read from disk after the second round. This is the \
  \last look this run takes at it, and it is what decides whether the batch is \
  \complete."

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a role answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: each pass opens with its own
-- 'Workflows.Panels.lensBrief', the ideation draws with 'ideationBrief', and
-- every receipt with its own brief.
--
-- __The receipts steer both halves, and they steer them down the long arms.__ At
-- the reviewing roles 'publishedBrief' answers with two paths under the default
-- directory, so 'Workflows.Deciders.observationsPending' says files were written;
-- empty that row and the run rehearses the arm that published nothing. At
-- @partner-cleanup@ the three directory receipts answer with two files, then one,
-- then none — so the run works both rounds and ends in the /drained/ arm, which
-- is the one that reaches @commitFn@. Leave a file in the last one and the run
-- ends in the arm that commits nothing.
--
-- __The three ideation draws share one key__, so a scripted run cannot make them
-- differ — which is the same honest limit @green-flaky@'s three draws have, and
-- for the same reason: three draws of one prompt are one key. The row is present
-- only at @partner-collaborator@, because only that role asks the question.
partnerScript :: PartnerRole -> [(Text, Text)]
partnerScript role =
  case role of
    Cleanup ->
      [ (batchBrief, twoFiles),
        (afterBrief, oneFile),
        (finalBrief, ""),
        (reviewEvidenceBrief, diffAnswer),
        (mainReviewBrief, reviewAnswer)
      ]
    _ ->
      [ (commitBrief, commitAnswer),
        (publishedBrief, twoFiles)
      ]
        <> [(ideationBrief, ideaAnswer) | ideasOn role]
        <> [(lensBrief l, blockFrom l) | l <- partnerRoster role []]
  where
    dir = observationsDir ""

    twoFiles =
      dir <> "/2026-08-19T09:14:02.117Z.md\n" <> dir <> "/2026-08-19T09:14:02.884Z.md"

    oneFile = dir <> "/2026-08-19T09:14:02.884Z.md"

    commitAnswer =
      "commit 9f1c2ab Cache the parsed header\n\
      \ src/Header.hs | 12 ++++++++++--\n\
      \\n\
      \--- a/src/Header.hs\n\
      \+++ b/src/Header.hs\n\
      \@@ -85,6 +85,9 @@\n\
      \+parsedCache :: IORef (Map ByteString Header)\n\
      \+parsedCache = unsafePerformIO (newIORef mempty)\n"

    blockFrom l =
      "### [MEDIUM] "
        <> lensOwns l
        <> "\n- **File**: src/Header.hs#L85-L90\n- **Category**: Maintainability\n\
           \- **Confidence**: 80\n- **Problem**: the cache is unbounded.\n\
           \- **Impact**: a long-lived process retains every header it has ever \
           \parsed.\n- **Fix**: bound the map, or key it on a digest with an \
           \eviction policy.\n(reported by the "
        <> lensName l
        <> " pass)"

    ideaAnswer =
      "Hidden assumption: that the cache has to live for the process. Inverted: \
      \let it live for the request. Borrowed from logistics -- a cross-docking \
      \model, where nothing is warehoused and everything is sorted in transit: a \
      \per-request arena freed at the end of the request needs no eviction policy \
      \at all, because the lifetime IS the policy. Mechanism: the parse cost is \
      \paid once per distinct header per request, which is where the repetition \
      \actually is."

    diffAnswer =
      "--- a/src/Header.hs\n\
      \+++ b/src/Header.hs\n\
      \@@\n\
      \-parsedCache = unsafePerformIO (newIORef mempty)\n\
      \+parsedCache = unsafePerformIO (newIORef (bounded 4096))\n"

    reviewAnswer =
      "Both observation files in the batch were removed, and the diff carries a \
      \change for each: the unbounded map is now bounded, and the second \
      \observation's missing test is present.\n\
      \Uncertain: the bound of 4096 is not justified anywhere in the diff or the \
      \handoff -- it is a number somebody chose.\n\
      \Verification: the handoff names `make test`; the diff makes that \
      \plausible. A test that the eviction actually evicts is the further check \
      \the risk warrants, and it is not there."
