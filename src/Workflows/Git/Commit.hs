-- |
-- Module      : Workflows.Git.Commit
-- Description : Flagship 3 — the commit-discipline pipeline.
--
-- __What this replaces.__ Four Markdown files that are one shape, and three
-- more that reach it by prose reference:
--
-- +---------------------------------+----------------------------------------------+
-- | @~\/src\/nix\/config\/ai@        | here                                         |
-- +=================================+==============================================+
-- | @commands\/commit.md@ (84 lines) | 'commitFn' — the whole file, as __one__      |
-- |                                 | callable function, and rung 'Commit'         |
-- +---------------------------------+----------------------------------------------+
-- | @commands\/push.md@ (1 line)     | rung 'Push' — @call_ commitFn@ and two acts  |
-- +---------------------------------+----------------------------------------------+
-- | @commands\/recommit.md@          | rung 'Recommit' — its \"each commit passes   |
-- |                                 | CI on its own\" claim as a per-series gate   |
-- +---------------------------------+----------------------------------------------+
-- | @commands\/bankruptcy.md@        | rung 'Bankruptcy' — its unchecked            |
-- |                                 | postcondition as a zero-question decider     |
-- +---------------------------------+----------------------------------------------+
-- | @commands\/{fix,halt}.md@,       | @call_ commitFn@, when those land            |
-- | @skills\/wiggum@                 | (\"use the @commit@ skill or                 |
-- |                                 | @$command-commit@\" — the sentence ends)     |
-- +---------------------------------+----------------------------------------------+
--
-- == The leveling-up, item by item
--
--   1. __\"Use the @commit@ skill or @$command-commit@\" becomes a call.__
--      @commit.md@ is the most-referenced node in the A–L half of the corpus:
--      three files tell an agent to go and read it. A prose reference is a
--      promise no reader can check; @'Agentic.Workflow.call_' 'commitFn'@ is
--      one node the elaborated program carries, priced at the callee's own
--      questions, and a caller that drifts from it cannot exist.
--
--   2. __The quality checklist's fourth item stops being a question to
--      oneself.__ @commit.md@ asks \"does the code compile and pass tests at
--      this point?\" of the agent that just wrote the commits.
--      'Workflows.Gates.gate' asks it of @make test@: exit @0@ approves, and a
--      nonzero exit objects __with the command's own first failing line__,
--      which the repair prompt then splices. @recommit.md@'s entire content is
--      that gate with a bigger bound.
--
--   3. __@bankruptcy.md@'s postcondition is checked.__ The file states its own
--      contract — \"the end result should be an unchanged working tree, but a
--      new Git commit history\" — and then has no way to test it. Here the tree
--      the run must end at is a program __input__ (tier 1: the fact is in the
--      invocation), the tree it did end at is a __receipt__, and the comparison
--      is a 'Agentic.Workflow.decide' that costs zero questions and adds one
--      path. See 'treeNeedle' for why the baseline is an input and not a second
--      receipt.
--
--   4. __\"Prefer a slightly larger commit over a broken repository\" becomes
--      the language's exhaustion semantics.__ That is @commit.md@'s closing
--      sentence, and it is advice a tired agent skips. Here it is the
--      @'Agentic.Workflow.Unsettled'@ arm: the gate ran out, the tree keeps
--      every edit the repairs made, and the run reports the series it is
--      holding rather than throwing the work away.
--
--   5. __Four commands, four prices, before anything is spent.__ The rungs
--      differ only in a style define and a repair bound, both ordinary Haskell
--      over the rung — so @wf cost recommit@ and @wf cost commit@ are two
--      numbers an operator reads before the first token, where the Markdown
--      offers four files and no way to compare them.
--
-- __Provenance.__ Every define below names the file and section it came from.
-- @~\/src\/nix\/config\/ai@ is read-only and was read as data; nothing in this
-- module writes to it, and no party in it points at it.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Git.Commit
  ( -- * The rungs
    CommitRung (..),
    commitRungName,
    rungStyle,
    rungTrips,

    -- * The function four programs share
    commitFn,
    commitTable,

    -- * The programs
    commitProgram,
    commitDoc,
    commitScript,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The one party that is this program's own
-- ---------------------------------------------------------------------------

-- | The party a commit series is written through.
--
-- A @tool@ with __no__ argv, deliberately. @commit.md@'s staging strategy is
-- @git add -p@ hunk by hunk, which is an interactive program; under
-- @'Agentic.Workflow.running'@ the prompt is the child's standard input, so an
-- argv of @git add --patch@ would feed the briefing text to @git@ as its answers
-- to \"stage this hunk?\". Staging a series is exactly the work an agent with
-- write authority does, and an @'Agentic.Workflow.act'@ at
-- @'Agentic.Raw.CodeAck'@ is the only kind of answer the ACP transport grants
-- that authority to.
committer :: Party 'IsTool
committer = tool "commit-series"

-- ---------------------------------------------------------------------------
-- The rungs
-- ---------------------------------------------------------------------------

-- | Four of the owner's names for one shape.
--
-- Registered once per rung, so each is priced apart and an unknown rung is a
-- registry miss rather than an @error@ on a CAF.
data CommitRung
  = -- | @commands\/commit.md@
    Commit
  | -- | @commands\/push.md@
    Push
  | -- | @commands\/recommit.md@
    Recommit
  | -- | @commands\/bankruptcy.md@
    Bankruptcy

-- | What the rung asks of the decomposition, above the standing discipline.
--
-- __Tier 1__ ("Workflows.Deciders"): the rung is in the invocation, so this is
-- ordinary Haskell over an ordinary 'Text' and costs zero questions and zero
-- paths. It is the whole of what separates four commands.
rungStyle :: CommitRung -> Text
rungStyle Commit =
  [wft|
  This is the ordinary case: commit the work in the tree now. Nothing has been
  reset and no history is being rewritten.|]
rungStyle Push =
  [wft|
  The series will be pushed and a pull request opened from it as soon as it is
  green, so the last commit's message is the one a reviewer reads first. Write
  it as the summary of the whole.|]
rungStyle Recommit =
  [wft|
  Each commit in this series will be submitted as its own pull request in a
  stack of pull requests representing this feature. So each one must pass
  scrutiny and the full CI suite ON ITS OWN, not merely at the end of the
  series: a commit that only builds once its successor lands is not a commit
  in this series, it is two commits written as one.|]
rungStyle Bankruptcy =
  [wft|
  The entire branch has already been unwound: its work is sitting uncommitted
  in the working tree and its old history is gone. What you produce replaces
  that history entirely, so it should be much more compact than what it
  replaces and much quicker to rebase in future. Do not attempt to reproduce
  the old commit boundaries -- they are what was wrong.|]

-- | How many repair trips the rung's gate is given.
--
-- The number is the level-up @commands\/*.md@ cannot state: @recommit@'s claim
-- is the expensive one (every commit standalone-green), so it gets the budget,
-- and @'Agentic.Plan.costSummary'@ prices the difference before anything is
-- spent.
rungTrips :: CommitRung -> Integer
rungTrips Commit = 1
rungTrips Push = 1
rungTrips Recommit = 3
rungTrips Bankruptcy = 2

-- | The trunk each rung measures its series against.
--
-- @recommit.md@ and @bankruptcy.md@ both say @main@ in so many words; the other
-- two mean it.
rungTrunk :: CommitRung -> Text
rungTrunk _ = "main"

-- | The name the operator types, and the name "Workflows.Registry" registers.
--
-- Family first, the owner's own word as the suffix, and the bare family name for
-- the default rung — so @wf list@ sorts the four by the thing he is choosing
-- between and the price of each is beside it.
commitRungName :: CommitRung -> Text
commitRungName Commit = "commit"
commitRungName Push = "commit-push"
commitRungName Recommit = "commit-recommit"
commitRungName Bankruptcy = "commit-bankruptcy"

-- ---------------------------------------------------------------------------
-- The discipline, once
-- ---------------------------------------------------------------------------

-- | @commands\/commit.md@, whole: the three decomposition principles, the six
-- change categories with their dependency ordering, the message format, the
-- staging strategy and the five-item quality checklist.
--
-- Verbatim where the file is short and compressed where it is a page. The one
-- thing dropped is the worked example decomposition (its \"Example
-- Decomposition\" section), which is an illustration of the principles above it
-- and costs a sixth of the prompt to repeat.
commitDiscipline :: Text
commitDiscipline =
  [wft|
  Commit all work as a series of atomic, logically sequenced commits. Each
  commit should represent one coherent change that can be understood,
  reviewed, and reverted independently.

  Decomposition principles.

  - Scope each commit to a single logical change. A commit should do exactly
    one thing: add a function, fix a bug, refactor a module, update
    documentation. If you find yourself writing "and" in a commit message,
    consider splitting the commit.
  - Sequence commits to tell a story. Arrange commits so each builds naturally
    on the previous. A reviewer reading the series should understand why each
    change was made and how the code evolved. Foundational changes come before
    dependent ones.
  - Keep each commit in a working state. Every commit should compile, pass
    tests, and not introduce obvious regressions. This enables bisection for
    debugging and allows reviewers to check out any point in history.

  Categorize before committing. Group the working tree's changes into these
  six, and commit them in this order wherever a dependency exists between
  them -- refactoring that enables a new feature precedes the feature:

  1. Infrastructure and setup -- new dependencies, configuration, tooling.
  2. Refactoring -- restructuring existing code without changing behaviour.
  3. New functionality -- features, APIs, modules.
  4. Bug fixes -- corrections to existing behaviour.
  5. Tests -- new or modified test coverage.
  6. Documentation -- comments, READMEs, inline docs.

  Message format: a summary line, a blank line, a body, a blank line, a
  footer. The summary is imperative mood, no period, under 50 characters, and
  describes what applying the commit does rather than what you did. The body
  explains the motivation and contrasts with previous behaviour, wrapped at 72
  characters, and is about WHY -- the diff already shows what. The footer
  references issues, breaking changes or co-authors.

  Answer with the commit plan and nothing else: one numbered entry per commit,
  each naming its category, the files or hunks it takes, and its summary line.|]

-- | @commands\/commit.md@'s @# Staging Strategy@ and @# Handling Mixed Changes@,
-- and its @# Quality Checklist@ -- the part addressed to whoever is doing the
-- staging.
--
-- The checklist's fourth item is deliberately absent from this text: \"does the
-- code compile and pass tests at this point?\" is not asked of the agent doing
-- the staging, because that is the question this program answers with a receipt.
-- See 'commitProgram'.
stagingBrief :: Text
stagingBrief =
  [wft|
  Create the commits the plan below describes, in the order it gives them.

  Stage selectively: `git add -p` for hunks within a file, `git add <paths>` to
  group related files, and `git diff --staged` to review what is about to be
  committed. When a single file contains changes belonging to several logical
  commits, stage its hunks separately rather than committing the whole file.

  Where the tree's changes are entangled: identify the distinct changes,
  determine which require which, order the commits to satisfy those
  dependencies, stage incrementally to isolate each, and verify the repository
  still works after each one.

  Before finalizing each commit, check that it does exactly one thing; that
  someone could understand it without seeing the others; that its message is
  searchable -- somebody grepping history for this change will find it; and
  that reverting it would cleanly undo one logical change.

  When you are done, reply DONE.

  The plan:|]

-- | What the series receipt is introduced as.
--
-- The prompt goes to the child's standard input, which @git log@ does not read;
-- it is here because it is the scripted table's key and because
-- @plan --raw@ prints it, so a reader of the plan can see what each receipt is
-- for. That is the same reason "Workflows.Gates" writes one.
seriesBrief :: Text
seriesBrief =
  [wft|
  The commit series this branch now carries, oldest first, as `git log` reports
  it against the trunk.|]

-- | What the closing tree receipt is introduced as.
treeBrief :: Text
treeBrief =
  [wft|
  The tree object at HEAD, now that the series exists, as `git rev-parse`
  reports it.|]

-- | @commands\/commit.md@'s closing sentence, as the exhausted gate's report.
--
-- /Source:/ verbatim, and it is the file's best sentence: it names the trade
-- and picks a side.
largerCommitBrief :: Text
largerCommitBrief =
  [wft|
  The commit series below was produced, and the repository's own test gate
  still objects after every repair trip this run was given. Report it as
  unfinished, not as done.

  The standing instruction, which is the reason nothing was thrown away: when
  changes are too entangled to separate cleanly, prefer a slightly larger
  commit with a clear message over a commit that leaves the repository in a
  broken state. Say which commits in the series you would merge to get there,
  and what the gate was still objecting to.

  Every edit the repair trips made is still in the tree. The series:|]

-- | The report for the arm where the postcondition failed.
--
-- /Source:/ @commands\/bankruptcy.md@'s stated contract, negated. The Markdown
-- has no arm for this because it has no test; here the branch is total and the
-- compiler makes it be written.
treeMovedBrief :: Text
treeMovedBrief =
  [wft|
  The commit series below was produced and the test gate approved it, but the
  tree at HEAD is NOT the tree this run was told it must end at. Only the
  history was supposed to move.

  Do not report this run as finished. Say what is in HEAD's tree that should
  not be, or missing from it that should be, and name the commit that did it.
  `git diff` between the two tree objects is the first thing to look at.

  The series that was produced:|]

-- | The report the three non-publishing rungs end in.
committedBrief :: Text
committedBrief =
  [wft|
  The commit series below was produced, the repository's own test gate
  approved it, and the tree at HEAD is the tree this run was told it must end
  at -- so the work is committed and nothing but the history moved.

  Report the series: one line per commit, and one line saying which of the six
  change categories each belongs to. The series:|]

-- | /Source:/ @commands\/push.md@.
pushBrief :: Text
pushBrief =
  [wft|
  Push the branch. The series below is what is being published, and the lease is
  what keeps a push from overwriting somebody else's work on this ref.|]

-- | /Source:/ @commands\/push.md@.
prBrief :: Text
prBrief =
  [wft|
  Open the pull request for the branch that was just pushed, filled from the
  commit series below. Then reply DONE.|]

-- ---------------------------------------------------------------------------
-- The function four programs share
-- ---------------------------------------------------------------------------

-- | The discipline, as the one thing every caller calls.
--
-- Two parameters and two statements: decide the series, then create it. The
-- decomposition is a @model@ question because it is a judgment; the staging is
-- an @'Agentic.Workflow.act'@ because it writes.
--
-- __What registering it costs:__ nothing. @rhsAsks@ prices a call at the
-- callee's own @bodyAsks@ with the arguments ignored, and @graft@ splices the
-- callee's node rather than adding one — so the four programs below and every
-- later caller share this body at no charge, which is the whole argument for
-- making it a 'Agentic.Workflow.Fn' rather than a define.
commitFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
commitFn =
  function
    "commit.series"
    ( takes @"scope" Text
        . takes @"style" Text
        $ noParams
    )
    \scope style -> W.do
      series <- ask (reasoning (model "decompose")) [wf|
          {commitDiscipline}

          What this run is committing:

          {scope}

          What this run's caller asks of the series, above the standing
          discipline:

          {style}|]

      act committer [wf|
          {stagingBrief}

          {series}|]
      done

-- | The table 'commitProgram' hands @'Agentic.Workflow.defining'@.
--
-- One entry, because one function is called. @defining@ checks that every call
-- names a function the list declared, and declared earlier, so a table with a
-- callee nobody calls is noise in the printed program and a table missing one is
-- a type error.
commitTable :: [SomeFn]
commitTable = [SomeFn commitFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The needle the postcondition tests for, and the one place this module
-- decides what an absent input means.
--
-- __Why the baseline is an input and not a second receipt.__ The obvious
-- spelling of @bankruptcy.md@'s postcondition is two @git rev-parse@ receipts
-- and a comparison — and it is not writable, because no Haskell function may
-- look at an answer: a receipt is a handle, and
-- @'Agentic.Workflow.decide'@'s needles are literal program text by design (a
-- needle a model could author is a test a model chooses). The fact is in the
-- invocation, so it belongs in the invocation: tier 1, zero questions, and
-- @plan@ prints the needle it will test for.
--
-- Which tree to pass depends on what the rung is doing, and it is one line
-- either way:
--
--   * a history-only rewrite ('Bankruptcy', 'Recommit') ends at the tree it
--     started at — @--input-arg tree=\"$(git rev-parse HEAD^{tree})\"@ before
--     the unwind;
--   * a rung that commits new work ('Commit', 'Push') ends at the working
--     tree — @git add -A && git write-tree@.
--
-- An absent input becomes a needle no receipt can match, which is deliberate:
-- @wf plan commit@ with no inputs prints @\<no tree given\>@, so an operator who
-- forgot the flag learns it from the plan rather than from the report.
treeNeedle :: Text -> Text
treeNeedle t
  | T.null (T.strip t) = "<no tree given>"
  | otherwise = T.strip t

-- | The tail, chosen by the rung in ordinary Haskell.
--
-- Both arms are terminals, so the compiler supplies neither: a rung that
-- publishes says so in two acts, and a rung that does not says so in one. That
-- is @push.md@'s entire content, and it is two lines here because
-- @call_ commitFn@ is the rest of it.
commitTail ::
  (KnownIx h s) =>
  CommitRung ->
  V h 'CodeText ->
  W ('Open s) j Term
commitTail Push history = W.do
  act gitPushLease [wf|
      {pushBrief}

      {history}|]
  ask_ ghPrCreate [wf|
      {prBrief}

      {history}|]
commitTail _ history = ask_ (tool "write-report") [wf|
    {committedBrief}

    {history}|]

-- | The pipeline: decompose and commit, gate it on the repository's own tests,
-- check the postcondition, and end the way the rung ends.
--
-- Two inputs. @scope@ is what is being committed (a branch name, a task
-- description, a paste of @git status@); @tree@ is the tree object the run must
-- end at — see 'treeNeedle'.
--
-- The @case@ over the gate is total and both arms carry the series, so the
-- exhausted arm reports the work instead of discarding it. That is
-- @commit.md@'s own \"prefer a slightly larger commit over a broken
-- repository\", expressed as a constructor rather than as advice.
commitProgram :: CommitRung -> Parameterized
commitProgram rung =
  taking (input "scope" :> input "tree" :> noInputs) \scope tree ->
    defining commitTable W.do
      -- The discipline, called. Three corpus files say "use the commit skill"
      -- and this is where that sentence ends.
      call_ commitFn (arg scope :> arg (rungStyle rung) :> noArgs)

      -- What the world now holds, as bytes the answering model did not write.
      series <- ask (gitLogSeries (rungTrunk rung)) [wf|{seriesBrief}|]

      -- `commit.md`'s quality checklist, item 4 — "does the code compile and
      -- pass tests at this point?" — asked of `make test` rather than of the
      -- agent that just wrote the commits. The objection the repair reads is
      -- the suite's own first failing line.
      gated <- gate makeTest repairBrief (reasoning (model "repair")) series (atMost (rungTrips rung))

      case gated of
        Settled history -> W.do
          -- `bankruptcy.md`'s postcondition, actually tested: zero questions,
          -- one path, and the needle is visible in `plan` before the run.
          ended <- ask (gitRevParse "HEAD^{tree}") [wf|{treeBrief}|]
          intact <- decide LastNonEmptyLineIs ended [treeNeedle tree]
          if intact
            then commitTail rung history
            else ask_ (tool "write-report") [wf|
                {treeMovedBrief}

                {history}|]
        Unsettled history -> ask_ (tool "write-report") [wf|
            {largerCommitBrief}

            {history}|]

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside each rung.
commitDoc :: CommitRung -> Text
commitDoc Commit =
  "commit.md: the working tree as an atomic, ordered series, gated on `make test`"
commitDoc Push =
  "push.md: the commit series, then `git push --force-with-lease` and `gh pr create`"
commitDoc Recommit =
  "recommit.md: the same series, each commit held to standalone CI (three repair trips)"
commitDoc Bankruptcy =
  "bankruptcy.md: recommit an unwound branch, and check the tree really did not move"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: 'commitFn' opens its question with
-- 'commitDiscipline', and each receipt's prompt opens with its own brief.
--
-- Only the /text/ questions need entries — @'Agentic.Exec.scriptedDefault'@
-- answers a flag @yes@, a verdict @APPROVE@ and a receipt @DONE@ — and the tree
-- receipt's entry is the one that matters: it is what makes the scripted run
-- take the /settled, intact/ path rather than the postcondition-failed one, so
-- a green @wf run commit --scripted@ is evidence about the arm an operator
-- actually wants.
commitScript :: CommitRung -> [(Text, Text)]
commitScript rung =
  [ (commitDiscipline, plan),
    (seriesBrief, series),
    (treeBrief, scriptedTree),
    (repairBrief, "1. Extract token validation into a module\n2. Add its unit tests")
  ]
  where
    _ = rung
    plan =
      [wft|
      1. [Refactoring] src/token.rs -- Extract token validation into a module
      2. [Tests] tests/token.rs -- Add unit tests for token validation
      3. [New functionality] src/refresh.rs -- Implement refresh token rotation|]
    -- fixture bytes, not prose: fake `git log --oneline` stdout.
    series =
      "a1b2c3d Extract token validation into a module\n\
      \e4f5a6b Add unit tests for token validation\n\
      \c7d8e9f Implement refresh token rotation"

-- | The tree oid the scripted table answers the postcondition receipt with, and
-- the value a scripted run must pass as @--input-arg tree=@ for the intact arm
-- to be the one taken.
--
-- It is exported through 'commitScript' rather than by itself: the pair is the
-- unit, exactly as a decider and its needles are in "Workflows.Deciders", and a
-- table whose answer and whose input disagree is a scripted run that silently
-- exercises the wrong arm.
scriptedTree :: Text
scriptedTree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
