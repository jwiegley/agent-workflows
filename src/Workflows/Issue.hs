-- |
-- Module      : Workflows.Issue
-- Description : A GitHub issue, fixed — with the three cheap gates that decide
--               whether anything expensive happens at all.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@           | here                                                      |
-- +=====================================+===========================================================+
-- | @commands\/fix.md@                  | @issue@ — the whole file: the gates, the work, the         |
-- |                                     | confirmation-test promotion, @call_ commitFn@, the push,   |
-- |                                     | the pull request, and @call_ botSweepFn@ over it           |
-- +-------------------------------------+-----------------------------------------------------------+
-- | @commands\/fix-github-issue.md@     | @issue-worktree@ — the same work in a worktree whose name  |
-- |                                     | is computed in Haskell, ending uncommitted /on purpose/,   |
-- |                                     | which a receipt now checks                                 |
-- +-------------------------------------+-----------------------------------------------------------+
-- | @commands\/commit.md@               | @'Workflows.Git.Commit.commitFn'@, called                   |
-- +-------------------------------------+-----------------------------------------------------------+
-- | @commands\/bugbot.md@               | @'Workflows.Fix.Green.botSweepFn'@, called                  |
-- +-------------------------------------+-----------------------------------------------------------+
-- | @prompts\/emacs.md@                 | 'Workflows.Rubrics.Personas.emacsPersona', spliced when    |
-- |                                     | the file list touches @.el@ — tier 1, zero questions       |
-- +-------------------------------------+-----------------------------------------------------------+
-- | @skills\/fix-all\/SKILL.md@         | "Workflows.Rubrics.Discipline", spliced into the work      |
-- +-------------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __Three cheap gates decide whether any expensive work happens.__
--      @doc\/design.md@ §7.2 row 20 is this sentence, and the three are: an open
--      pull request already addressing the issue
--      ('Workflows.Deciders.openPullRequest', a @'Agentic.Workflow.decide'@ over
--      a @gh@ receipt, zero questions); whether the issue is still live at all
--      (one flag, because that one /is/ a judgment); and whether a confirmation
--      test is waiting in @test\/todo@ (an exit code, decided by @test -f@ and
--      not by a model). @fix.md@ states all three and checks none of them: its
--      first is a @NOTE@ addressed to whoever read the file.
--
--   2. __\"Just give the PR number and stop immediately\" is a terminal.__ In
--      the corpus that instruction sits eleven paragraphs above the work it is
--      supposed to prevent. Here the false arm of the first decider ends the
--      run, and there is no reachable statement after it — which is a fact about
--      the printed program rather than about how carefully the file was read.
--
--   3. __The confirmation-test promotion is one flag and two call sites.__
--      @fix.md@'s @# If present, change confirmation tests into regression
--      tests@ section is conditional on a file existing. The condition is
--      @'Workflows.Evidence.filePresent'@ at the path
--      'todoTestPath' computes from the issue number, and the two arms call
--      __one__ 'issueFixFn' with a different guidance argument — so the two
--      cannot drift apart, and the promotion cannot happen for an issue whose
--      test is not there.
--
--   4. __The naming scheme is computed, not described.__ @fix-github-issue.md@
--      step 1 is \"if the issue number is 1024, then create a branch named
--      @fix-1024@ and a working tree in @work\/fix-1024@\", which is a
--      substitution it asks a model to perform. 'worktreePath' and
--      'worktreeBranch' perform it, in ordinary Haskell, and the same two
--      strings become the argv of @git worktree add@ /and/ of the
--      @git -C … status@ that checks the result.
--
--   5. __\"Leave your work uncommitted\" becomes a receipt read by a decider.__
--      §7.2 row 17's own words. Step 8 of that file is a postcondition, and a
--      postcondition addressed to the agent that just did the work is a hope:
--      here it is @git -C work\/fix-\<n\> status --porcelain@ and
--      'Workflows.Deciders.treeDirty', for zero questions, and the arm where the
--      tree came back clean reports that nothing was left to review rather than
--      claiming a review-ready worktree.
--
--   6. __The persona costs nothing.__ @prompts\/emacs.md@ is 169 lines that the
--      corpus stacks in front of a question by hand. Here it is selected by the
--      @paths@ input in ordinary Haskell — tier 1, zero questions, zero paths —
--      and a run whose diff touches no Elisp never carries it.
--
-- == Two honest limits, named rather than papered over
--
-- __The CI-monitoring half of @fix.md@ is a second run, and it has to be.__ That
-- file ends by monitoring the checks on the pull request it just created. The
-- workflow for that is @green-ci@, whose input is the pull request /number/ —
-- and this run cannot supply it: the number exists only in a receipt, and an
-- argv is part of the printed program. So @issue@ does not call @green-ci@; its
-- report names it as the next run, with the branch it is on. The bot sweep
-- /is/ reachable, and for exactly the complementary reason:
-- @'Workflows.Evidence.ghPrCurrent'@ names its subject by position rather than
-- by number, so a run that opened the pull request can still read it.
--
-- __@fix.md@'s @GH_TOKEN=\"$(gh auth token …)\"@ wrapper is not carried.__ It is
-- shell, and "Agentic.Shell" runs an argv with @proc@ and never @sh -c@ — which
-- is the rule that makes every placeholder in "Workflows.Evidence" safe. See
-- @'Workflows.Evidence.ghIssueView'@ for what replaces it and how it fails.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Issue
  ( -- * The rungs
    IssueRung (..),
    issueRungName,
    issueDoc,

    -- * The program
    issueProgram,
    issueScript,

    -- * The naming scheme, computed
    issueNumber,
    worktreePath,
    worktreeBranch,
    todoTestPath,

    -- * The functions
    issueWorkFn,
    issueFixFn,
    issueReportFn,
    issueTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Fix.Green (botSweepFn)
import Workflows.Git.Commit (commitFn)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The rungs
-- ---------------------------------------------------------------------------

-- | The two things the owner means by \"fix this issue\".
--
-- They differ in where the work happens and in how it ends: on the branch the
-- run is on, committed and published; or in a worktree of its own, left
-- deliberately uncommitted for a human to read.
data IssueRung
  = -- | @commands\/fix.md@
    Fix
  | -- | @commands\/fix-github-issue.md@
    Worktree
  deriving (Eq, Show)

-- | The name the operator types.
issueRungName :: IssueRung -> Text
issueRungName Fix = "issue"
issueRungName Worktree = "issue-worktree"

-- | The one line @wf list@ prints beside a rung.
issueDoc :: IssueRung -> Text
issueDoc Fix =
  "fix.md: three cheap gates, the fix, `commitFn`, a pull request, and the bot sweep over it"
issueDoc Worktree =
  "fix-github-issue.md: the fix in its own worktree, left uncommitted, and a receipt that says so"

-- ---------------------------------------------------------------------------
-- The naming scheme, computed
-- ---------------------------------------------------------------------------

-- | The issue number, and the one place an absent input is given a meaning.
--
-- __Tier 1__ ("Workflows.Deciders"): the fact is in the invocation.
-- 'Workflows.Git.Commit.treeNeedle' is the precedent and the rule is its —
-- an absent input becomes a name nothing answers to, so @wf plan issue --raw@
-- prints @gh issue view \<no issue given\>@ and an operator who forgot the flag
-- learns it from the plan rather than from a run that fixed something else.
issueNumber :: Text -> Text
issueNumber n
  | T.null (T.strip n) = "<no issue given>"
  | otherwise = T.strip n

-- | @work\/fix-\<n\>@ — @fix-github-issue.md@ step 1's directory, computed.
worktreePath :: Text -> Text
worktreePath n = "work/" <> worktreeBranch n

-- | @fix-\<n\>@ — the same step's branch, computed from the same input, so the
-- two cannot disagree.
worktreeBranch :: Text -> Text
worktreeBranch n = "fix-" <> issueNumber n

-- | @test\/todo\/\<n\>.test@ — the path @fix.md@'s confirmation-test section
-- names.
--
-- /Source:/ its own sentence: \"sometimes an issue will already have a
-- \'confirmation test\' in the directory @test\/todo@, with the name
-- @\<ISSUE-NUMBER\>.test@\".
todoTestPath :: Text -> Text
todoTestPath n = "test/todo/" <> issueNumber n <> ".test"

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the pull-request search receipt is introduced as.
--
-- /Source:/ @commands\/fix.md@'s @NOTE@. The prompt goes to the child's standard
-- input, which @gh@ does not read; it is here because @plan --raw@ prints it, so
-- a reader of the plan can see what the receipt is for.
prSearchBrief :: Text
prSearchBrief =
  [wft|
  The open pull requests whose text mentions this issue, one URL per line, as
  `gh pr list --search` reports them. Nothing at all means nobody is already
  working on it.|]

-- | What the issue receipt is introduced as.
issueBrief :: Text
issueBrief =
  [wft|
  The GitHub issue this run was given, as JSON: its title, its state, its
  labels, its body and its comments. This is the whole statement of the
  problem, and anything not in it is not part of this issue.|]

-- | What the branch-history receipt is introduced as.
--
-- /Source:/ @commands\/fix.md@'s \"if you find that the bug or feature you're
-- attempting to fix has already been addressed in an earlier commit\", which is
-- a question about history and is asked here with the history in hand.
historyBrief :: Text
historyBrief =
  [wft|
  The commits this branch carries over the trunk, oldest first. If the issue
  below has already been dealt with, it was dealt with here.|]

-- | @commands\/fix.md@'s second gate, as the one question in this program that
-- is genuinely a judgment.
--
-- __Tier 3__, and the haddock says why it is not lower: whether a commit already
-- addresses an issue is a reading of both, and no needle decides it. What the
-- program supplies is the /evidence/ — the issue and the branch's own log, both
-- receipts — so the judgment is made over bytes rather than over a memory.
triageBrief :: Text
triageBrief =
  [wft|
  Decide one thing: is the work this issue asks for still outstanding?

  Read the issue and the branch's commit log below. Answer no -- the issue is
  NOT outstanding -- if the log shows the behaviour it asks for has already
  been implemented or the bug it reports has already been fixed. Answer yes if
  the work still has to be done, or if the log does not settle it: a wrong
  "no" ends this run without fixing anything, and a wrong "yes" costs one
  superfluous investigation. Prefer yes when the evidence is thin, and say
  nothing but the answer.|]

-- | What the confirmation-test flag asks.
--
-- /Source:/ @commands\/fix.md@'s confirmation-test section, whose condition is
-- the existence of one file. The words go to @test@'s standard input, which it
-- does not read; @plan --raw@ prints them, and the /answer/ is the exit code.
confirmationBrief :: Text
confirmationBrief =
  [wft|
  Does this issue already have a confirmation test in test/todo? The answer is
  the exit code of `test -f`, and nothing here is being asked of a model.|]

-- | @commands\/fix.md@'s @# Think, Research, Plan, Act, Review@ opening, as the
-- planning question.
--
-- /Source:/ that heading and the two paragraphs under it, plus its @# Follow
-- these steps@ list, compressed to the part that is about /this/ plan. The
-- sentence about signing commits is dropped: it names a git identity, which is
-- the environment's and not a program's to assert.
planBrief :: Text
planBrief =
  [wft|
  Think deeply about the issue below, then produce the plan for fixing it and
  nothing else.

  The plan is a numbered list. Each entry names the file it touches, what
  changes there, and how that step will be verified -- the command to run, or
  the test that must go from failing to passing. Foundational steps come
  before the steps that depend on them.

  The plan must include the tests: every fix carries the test that would have
  caught the bug, and a step that says "add tests" without saying which
  behaviour they pin is not a step. It must also include the linting and
  type-checking the repository already runs, as its own last step.

  Do not begin the work and do not write code here. This job is long, and a
  plan that can be read in one page is what makes it resumable.|]

-- | What the working act is told, above the plan and the guidance.
--
-- /Source:/ @commands\/fix.md@'s steps 3 to 6 and its \"execute that plan step
-- by step\", with the standing no-deferral, upstream and testing rules spliced
-- from "Workflows.Rubrics.Discipline" — which is where those sentences live once.
workBrief :: Text
workBrief =
  [wft|
  Carry out the plan below, step by step, in the order it gives.

  After each step, run the verification that step names and do not proceed
  past a failing one: fix the cause, then continue. When the plan is done, run
  the repository's own linting and type checking and leave both clean.

  {noDeferral}

  {upstream}

  {testing}

  When you are done, reply DONE.|]
  where
    noDeferral = fixAllRule
    upstream = upstreamRule
    testing = testingStandard

-- | The guidance the two confirmation-test arms differ in.
--
-- /Source:/ @commands\/fix.md@'s @# If present, change confirmation tests into
-- regression tests@ section, whole, in the arm where the file is there; and its
-- absence in the arm where it is not.
--
-- The persona rides in the same argument, which is why there is one of these and
-- not two: the fixer is told who it is and what is waiting for it in one place,
-- and 'issueFixFn' has one parameter for both.
workGuidance :: Text -> Bool -> Text -> Text
workGuidance persona promoting n =
  T.intercalate "\n\n" (filter (not . T.null) [persona, promotion])
  where
    promotion
      | not promoting = ""
      | otherwise =
          [wft|
          This issue has a confirmation test waiting at {path}. That test
          "confirms" the bug by asserting the behaviour the issue reports, so
          it passes while the bug is present.

          Promote it as part of this work: move it to `test/regress`, then
          rewrite it to assert the CORRECT expected behaviour -- which will
          fail at first -- and fix the issue until it passes. Research what
          the correct behaviour actually is rather than inverting the
          assertion; an inverted confirmation test pins whatever the fix
          happened to do. Add whatever further tests show that no neighbouring
          behaviour moved.|]
    path = todoTestPath n

-- | The regression-test-only arm's act.
--
-- /Source:/ @commands\/fix.md@, verbatim in substance: \"if you find that the
-- bug or feature you're attempting to fix has already been addressed in an
-- earlier commit, just add a regression test to demonstrate the item has been
-- dealt with.\"
regressionOnlyBrief :: Text
regressionOnlyBrief =
  [wft|
  The issue below has already been addressed by a commit on this branch, so
  there is no fix to write. Add the regression test that demonstrates it has
  been dealt with, and nothing else.

  The test must fail if the fixing commit were reverted -- that is the whole
  of its value. Name, in one line above it, which commit it pins.

  Do not re-fix, do not refactor what the commit did, and do not add tests for
  behaviour the issue does not mention. When you are done, reply DONE.|]

-- | What the push act is told.
pushBrief :: Text
pushBrief =
  [wft|
  Push the branch. What is being published is the series the commit step just
  produced, and the lease is what keeps this push from overwriting somebody
  else's work on the ref.|]

-- | What the pull-request act is told.
--
-- /Source:/ @commands\/fix.md@'s \"create a PR using my jwiegley user on
-- GitHub\". The user is the environment's @gh@ credential and not a program's
-- assertion; what the program says is what the pull request is for.
prBrief :: Text
prBrief =
  [wft|
  Open the pull request for the branch that was just pushed, filled from the
  commit series. Its body must name the issue this run fixed, so that merging it
  closes the issue. Then reply DONE.|]

-- | What the current branch's pull-request record is introduced as.
--
-- /Source:/ @commands\/fix.md@'s closing section. The subject is named by
-- position rather than by number, which is the only way a run that just created
-- a pull request can read it — see @'Workflows.Evidence.ghPrCurrent'@.
sweepLedgerBrief :: Text
sweepLedgerBrief =
  [wft|
  This is the record of the pull request this run just opened, as JSON,
  straight from the GitHub API. Build the inventory of unresolved automated
  review items in it -- BugBot, Cursor, Devin and the rest -- as a numbered
  checklist: number, author, category, file and line where applicable, and one
  line on what each raises.

  Include only bot and automated authors: an author whose type is Bot, or
  failing that whose login contains "bot", "[bot]" or "app/". If there are
  none, reply with exactly

    No unresolved bot comments found

  and nothing else.|]

-- | What this caller asks of the commit decomposition, above the standing
-- discipline.
--
-- /Source:/ @commands\/fix.md@'s closing instruction — \"follow the @commit@
-- command's atomic decomposition, sequencing, message, staging, and per-commit
-- verification rules\" — plus its own demand that the regression test come
-- first. It is @'Workflows.Git.Commit.commitFn'@'s @style@ argument, which is
-- the whole of what separates that function's four registered callers.
commitStyle :: Text
commitStyle =
  [wft|
  This series fixes a GitHub issue and will be pushed and opened as a pull
  request as soon as it is written, so the last commit's message is the one a
  reviewer reads first: write it as the summary of the whole, and name the
  issue in it.

  The regression test and the fix it pins belong to two different commits,
  test first, so that the series shows the test failing before it shows it
  passing. A reviewer bisecting this branch should be able to stop at the test
  commit and watch it fail.|]

-- | The exclusion policy this caller hands @botSweepFn@.
--
-- /Source:/ @commands\/bugbot.md@ Phase 1 step 4's bold line, and
-- @commands\/fix.md@'s own \"BugBot, Cursor or Devin comments\". It is an
-- argument for @'Workflows.Fix.Green.botSweepFn'@'s stated reason — so that this
-- caller and @green-ci@'s cannot disagree about it without the difference being
-- visible at two call sites.
botExclusions :: Text
botExclusions =
  [wft|
  Exclude every human author, without exception. This sweep runs immediately
  after the pull request was opened, so a human comment on it is a colleague
  reading a fresh diff: replying to one on a bot's behalf is how an automated
  sweep starts answering a person.|]

-- | What the worktree-creating act is told.
--
-- /Source:/ @commands\/fix-github-issue.md@ step 1. The path and the branch are
-- the argv's, computed by 'worktreePath' and 'worktreeBranch', so the only thing
-- this text has to say is that they are not the answerer's to choose.
worktreeBrief :: Text
worktreeBrief =
  [wft|
  Create the worktree and branch for this issue. The path and the branch name
  are the argv of this command and were computed from the issue number; nothing
  here is for you to choose. The issue follows so that the command's own output
  can be read beside what it is for.|]

-- | What the closing worktree receipt is introduced as.
--
-- /Source:/ @commands\/fix-github-issue.md@ step 8, which is a postcondition;
-- these bytes are what tests it. See @'Workflows.Evidence.gitStatusIn'@ for why
-- the receipt is @-C@'d and not 'Workflows.Evidence.gitStatus'.
leftBrief :: Text
leftBrief =
  [wft|
  The worktree's own working tree, as `git -C <path> status --porcelain` reports
  it. This run was asked to leave its work uncommitted, so these bytes are the
  evidence that it did -- and their absence is evidence that it did not.|]

-- | The brief the report act is given.
issueWriteBrief :: Text
issueWriteBrief =
  [wft|
  Write the report for an issue run. It is read by somebody who was not
  watching and has to decide what happens next.

  Open with the provenance line you were given, verbatim, on its own line. It
  is the run's own account of how it ended and it is not yours to soften.

  Then, from the evidence below and nothing else: what the issue asked for,
  what this run did about it, and what the next run would have to do. Name
  every file, command and commit the evidence names, and nothing it does not.

  Do not describe work the evidence does not show, and do not report the issue
  as closed -- closing it is the pull request's business and merging is
  somebody else's.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where somebody was already on it.
--
-- /Source:/ @commands\/fix.md@'s @NOTE@, whose \"stop immediately\" this is.
alreadyOpenNote :: Text
alreadyOpenNote =
  [wft|
  Outcome: ALREADY IN HAND. A search of the open pull requests found at least
  one that mentions this issue, so no investigation was started and nothing was
  changed. Report the pull request URLs below and stop there: this run's whole
  job was to find out that somebody is already on it.|]

-- | The arm where the issue turned out to be fixed already.
alreadyFixedNote :: Text
alreadyFixedNote =
  [wft|
  Outcome: ALREADY ADDRESSED. The issue and the branch's own commit log were
  read together, and the work the issue asks for is already in the history -- so
  this run added the regression test that demonstrates it and did nothing else.
  Report which commit the test pins, and do not describe a fix that was not
  written here.|]

-- | The arm where the work was done and published.
fixedNote :: Bool -> Text
fixedNote promoting =
  [wft|
  Outcome: FIXED AND PUBLISHED. The issue was still outstanding, the plan was
  carried out, the series was committed through the standing commit discipline,
  the branch was pushed and a pull request was opened; the bot comments on that
  pull request were then swept. {promotedClause} Two things this run did NOT do,
  and the report must not claim: it did not watch CI -- that is the `green-ci`
  workflow, and it takes the pull request number this run cannot know -- and it
  did not merge anything.|]
  where
    promotedClause
      | promoting =
          [wft|
          The confirmation test in `test/todo` was promoted to `test/regress`
          and rewritten to assert the correct behaviour.|]
      | otherwise =
          [wft|
          No confirmation test was waiting in `test/todo` for this issue, so
          none was promoted.|]

-- | The arm where the worktree came back with something to review.
uncommittedNote :: Text -> Text
uncommittedNote n =
  "Outcome: READY TO REVIEW, UNCOMMITTED. The work was done in the worktree at "
    <> worktreePath n
    <> " on branch "
    <> worktreeBranch n
    <> [wft|
       , and `git -C` reports that tree as dirty -- which is what this run was
       asked for: the changes are there to be read and nothing has been
       committed. Report the file list below, and name the worktree path and
       branch so a reviewer can get to them.|]

-- | The arm where it came back clean.
--
-- /Source:/ the ending @fix-github-issue.md@ cannot have. Step 8 is a
-- postcondition and the file has no arm for its failing.
nothingChangedNote :: Text -> Text
nothingChangedNote n =
  [wft|
  Outcome: NOTHING TO REVIEW. The worktree at {path} was created and the work
  ran, and `git -C … status --porcelain` came back EMPTY -- so either nothing
  was changed or something committed it, and step 8 of this workflow says the
  work is to be left uncommitted. Do not report this as a completed fix. Say
  which of the two happened, from the evidence below, and what the next run
  would have to check first.|]
  where
    path = worktreePath n

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | Plan, then work. The two statements every rung shares.
--
-- Two parameters: the issue itself, and the guidance this call site adds — the
-- persona, and @fix.md@'s confirmation-test section where there is a test to
-- promote.
--
-- A function rather than four copies for "Workflows.Report"'s reason: a call is
-- priced at the callee's own body with the arguments ignored, so the second,
-- third and fourth call sites are free and the four cannot drift.
issueWorkFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
issueWorkFn =
  function
    "issue.work"
    ( takes @"issue" Text
        . takes @"guidance" Text
        $ noParams
    )
    \issue guidance -> W.do
      plan <- ask (reasoning (model "plan")) [wf|
          {planBrief}

          The issue:

          {issue}|]

      act (tool "issue-worker") [wf|
          {workBrief}

          What else this run is standing under:

          {guidance}

          The plan:

          {plan}|]
      done

-- | @fix.md@'s tail: the work, the series, the push, the pull request, and the
-- sweep over it.
--
-- Five statements and two calls, and every one of them is a thing that file
-- names. It is a function and not a block for the reason the two arms above it
-- exist: the confirmation-test flag chooses between two guidance texts and
-- nothing else, so the two arms differ in one argument and share this body.
--
-- __Its callees precede it in 'issueTable'__, which is what
-- @'Agentic.Workflow.defining'@ checks: a function may call a function the table
-- declared earlier, and 'issueWorkFn', @commitFn@ and @botSweepFn@ all do.
issueFixFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
issueFixFn =
  function
    "issue.fix"
    ( takes @"issue" Text
        . takes @"guidance" Text
        $ noParams
    )
    \issue guidance -> W.do
      call_ issueWorkFn (arg issue :> arg guidance :> noArgs)

      -- The commit discipline, called. `fix.md`'s own closing sentence is
      -- "follow the `commit` command's atomic decomposition, sequencing,
      -- message, staging, and per-commit verification rules", and this is where
      -- that sentence ends.
      call_ commitFn (arg issue :> arg commitStyle :> noArgs)

      act gitPushLease [wf|{pushBrief}|]
      act ghPrCreate [wf|{prBrief}|]

      -- The pull request now exists, so it can be read -- by position, which is
      -- the only handle a run that just created it has.
      inventory <- ask ghPrCurrent [wf|{sweepLedgerBrief}|]
      call_ botSweepFn (arg inventory :> arg botExclusions :> noArgs)
      done

-- | The report every ending calls.
--
-- Two parameters, provenance first, for 'Workflows.Report.reportFn''s reason: it
-- is the thing a report must not omit and the one argument the arms differ in.
issueReportFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
issueReportFn =
  function
    "issue.report"
    ( takes @"provenance" Text
        . takes @"evidence" Text
        $ noParams
    )
    \provenance evidence -> W.do
      act reporter [wf|
          {issueWriteBrief}

          Provenance:

          {provenance}

          The evidence:

          {evidence}

          Write the report, then reply DONE.|]
      done

-- | The table 'issueProgram' hands @'Agentic.Workflow.defining'@.
--
-- Declaration order is load-bearing: 'issueFixFn' calls the three above it, and
-- @defining@ refuses a call to a function the list declares later.
issueTable :: [SomeFn]
issueTable =
  [ SomeFn issueWorkFn,
    SomeFn commitFn,
    SomeFn botSweepFn,
    SomeFn issueFixFn,
    SomeFn issueReportFn
  ]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | Three gates, the work, and an ending that names what it did not do.
--
-- Two inputs. @issue@ is the number, and it is the argv of @gh issue view@, the
-- @--search@ term, the worktree's name and the confirmation test's path;
-- @paths@ is the file list, one per line, and it selects the persona in Haskell
-- before the program exists.
issueProgram :: IssueRung -> Parameterized
issueProgram rung =
  taking (input "issue" :> input "paths" :> noInputs) \issue paths ->
    let n = issueNumber issue
        persona = personaFor (pathsOf paths)
     in defining issueTable case rung of
          Fix -> W.do
            -- Gate 1, tier 2: is somebody already on it? Zero questions, and
            -- the needle is in the plan before the run.
            prs <- ask (ghPrSearch n) [wf|{prSearchBrief}|]
            taken <- tested openPullRequest prs

            if taken
              then W.do
                call_ issueReportFn (arg alreadyOpenNote :> arg prs :> noArgs)
                stop
              else W.do
                details <- ask (ghIssueView n) [wf|{issueBrief}|]
                history <- ask (gitLogSeries "main") [wf|{historyBrief}|]

                -- Gate 2, tier 3: the one judgment in this program, made over
                -- two receipts rather than over a memory.
                live <- confirm (reasoning (model "triage")) [wf|
                    {triageBrief}

                    The issue:

                    {details}

                    The branch's history:

                    {history}|]

                if live
                  then W.do
                    -- Gate 3, tier 2: an exit code, not a model's reading of a
                    -- directory listing.
                    promote <- passes (filePresent (todoTestPath n)) [wf|{confirmationBrief}|]

                    if promote
                      then W.do
                        call_ issueFixFn (arg details :> arg (workGuidance persona True n) :> noArgs)
                        call_ issueReportFn (arg (fixedNote True) :> arg details :> noArgs)
                        stop
                      else W.do
                        call_ issueFixFn (arg details :> arg (workGuidance persona False n) :> noArgs)
                        call_ issueReportFn (arg (fixedNote False) :> arg details :> noArgs)
                        stop
                  else W.do
                    act (tool "issue-worker") [wf|
                        {regressionOnlyBrief}

                        The issue:

                        {details}

                        The branch's history:

                        {history}|]
                    call_ issueReportFn (arg alreadyFixedNote :> arg history :> noArgs)
                    stop
          Worktree -> W.do
            details <- ask (ghIssueView n) [wf|{issueBrief}|]

            -- Step 1, with the substitution done in Haskell.
            act (gitWorktreeAdd (worktreePath n) (worktreeBranch n)) [wf|
                {worktreeBrief}

                {details}|]

            call_ issueWorkFn (arg details :> arg (workGuidance persona False n) :> noArgs)

            -- Step 8, as a receipt about the right tree.
            left <- ask (gitStatusIn (worktreePath n)) [wf|{leftBrief}|]
            dirty <- tested treeDirty left

            if dirty
              then W.do
                call_ issueReportFn (arg (uncommittedNote n) :> arg left :> noArgs)
                stop
              else W.do
                call_ issueReportFn (arg (nothingChangedNote n) :> arg left :> noArgs)
                stop

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every receipt's question opens with its own brief, the
-- plan's with 'planBrief', and the sweep's ledger with 'sweepLedgerBrief'.
--
-- __Three rows steer the run, and they steer it down the longest path.__
-- 'prSearchBrief' answers with nothing that begins @https:@, so gate 1 says
-- nobody is on it; @'Agentic.Exec.scriptedDefault'@ answers a flag @yes@, so
-- gate 2 says the issue is live and gate 3 says the confirmation test is there —
-- which is the arm where the promotion happens, and the one an operator most
-- wants rehearsed. Every other ending is one edit away: put a URL in the search
-- answer for the already-in-hand arm, add @(triageBrief, \"no\")@ for the
-- regression-only arm, add @(confirmationBrief, \"no\")@ for the unpromoted arm.
-- All of them exit 0.
--
-- At @issue-worktree@ the same defaults walk the dirty-tree arm, because
-- 'leftBrief''s row answers with two porcelain lines; empty it and the run
-- rehearses the ending that says nothing was left to review.
issueScript :: IssueRung -> [(Text, Text)]
issueScript rung =
  [ (prSearchBrief, ""),
    (issueBrief, issueAnswer),
    (historyBrief, historyAnswer),
    (planBrief, planAnswer),
    (sweepLedgerBrief, sweepAnswer),
    (leftBrief, leftAnswer)
  ]
  where
    _ = rung

    -- fixture bytes, not prose: fake `gh issue view --json` stdout.
    issueAnswer =
      "{\"number\":1024,\"title\":\"format --json drops the trailing newline\",\
      \\"state\":\"OPEN\",\"labels\":[{\"name\":\"bug\"}],\
      \\"body\":\"Running `fmt --json` on a file ending in a newline writes one \
      \that does not. The plain formatter is fine.\",\"comments\":[]}"

    -- fixture bytes, not prose: fake `git log --oneline` stdout.
    historyAnswer =
      "a1b2c3d Add the JSON writer\n\
      \e4f5a6b Reuse the plain formatter's buffer"

    planAnswer =
      [wft|
      1. test/todo/1024.test -> test/regress/1024.test -- promote, and rewrite
         the expectation to a trailing newline. Verify: the test fails before
         step 2 and passes after it.
      2. src/Json.hs -- the writer drops the final newline because it joins with
         `intercalate`; append it. Verify: `make test`.
      3. Run the repository's linting and type checking. Verify: both clean.|]

    sweepAnswer = "No unresolved bot comments found"

    -- fixture bytes, not prose: fake `git status --porcelain` stdout.
    leftAnswer =
      " M src/Json.hs\n\
      \?? test/regress/1024.test"
