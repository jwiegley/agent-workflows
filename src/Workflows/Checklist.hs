-- |
-- Module      : Workflows.Checklist
-- Description : The warm-up — a Markdown checklist worked to empty, one free
--               test per round.
--
-- == The map: old Markdown -> new program
--
-- +----------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@        | here                                                      |
-- +==================================+===========================================================+
-- | @commands\/process-checklist.md@ | @checklist@ — the whole file, which is ten lines: a loop  |
-- |                                  | over unchecked boxes and a self-verify pass after it      |
-- +----------------------------------+-----------------------------------------------------------+
-- | @skills\/fix-all\/SKILL.md@      | "Workflows.Rubrics.Discipline", spliced into the working  |
-- |                                  | act — \"fully implement or resolve\" is that file's rule, |
-- |                                  | said once and checked nowhere in the corpus               |
-- +----------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == Why this row is the warm-up
--
-- @doc\/design.md@ §8 calls it that, and §7.2 row 41 says why: ten Markdown
-- lines with the highest structure-to-prose ratio in the corpus. Everything in
-- the file is a mechanism — a loop, its exit condition, and a second pass — and
-- none of it is judgment. So it is the smallest honest test of whether the
-- library is right: if a program this shape needs anything new, the library was
-- wrong.
--
-- It needed nothing new. 'Workflows.Deciders.hasUnchecked' was already in the
-- tree, transcribed from this very file, before this program existed.
--
-- == The leveling-up, item by item
--
--   1. __The loop's exit condition is free.__ \"Repeat for the next item until
--      all are complete\" and \"self-verify the list for missed or incomplete
--      tasks\" are, in the corpus, a model re-reading its own work and reporting
--      on it. Here each round is entered behind
--      @'Workflows.Gates.tested' 'Workflows.Deciders.hasUnchecked'@ over a
--      @cat@ receipt: __zero questions per round__, one path each, and the test
--      is a grep over bytes the answering model did not write.
--
--   2. __\"Verify the task is still incomplete\" stops being asked of the agent
--      that is about to do the task.__ The checklist a round is handed is a
--      receipt read fresh from disk after the previous round finished, so the
--      round's own first question is over the file as it now stands and not over
--      what it remembers writing.
--
--   3. __The unbounded loop becomes a number.__ \"Repeat as needed\" has no
--      budget an operator can read. Here it is two rounds — the pass and the
--      self-verify pass, which is exactly the file's two paragraphs — and
--      @wf cost checklist@ prints the worst case before the first token.
--
--   4. __A list with nothing left costs nothing.__ The first decider's false arm
--      reports and stops without asking anybody anything, so running this on an
--      already-finished checklist is two questions and no model consultation
--      about the work.
--
--   5. __The unfinished ending is written.__ The corpus's loop has no arm for
--      \"still not empty\", because prose loops do not have arms. Here the last
--      round's test has both, and the arm that did not finish reports what
--      remains under its own provenance line rather than describing the run as
--      complete.
--
-- == Two honest notes
--
-- __This is not a @revising@, and @doc\/design.md@ sketches one.__ §7.2 row 41
-- reads \"outer @revisingOn@ whose settle test is @decide containsLine@
-- inverted\" and §8 reads \"@revising@ plus a free settle test\". Neither is
-- writable, and the reason is the grammar rather than taste: a bounded
-- revision's review clause is a __verdict__ question
-- (@'Agentic.Workflow.revising'@'s @Clauses@), so a @'Agentic.Workflow.decide'@
-- — which yields a flag — cannot be one; and a revision's body is __exactly one
-- review and one amendment__, so the per-round work here (choose the next item,
-- then do it) cannot stand in one. "Workflows.Gates"' own haddock states the
-- consequence and names the shape to use instead: \"a loop whose per-trip work
-- is a pipeline … is K unrolled rounds, each round a @call_@ behind a
-- @'Agentic.Workflow.decide'@ on the previous round's receipt\". That is this
-- program, at @K = 2@, and the design's \"zero questions per trip\" survives
-- intact — it is the /decider/ that is free, and a decider is free in either
-- spelling.
--
-- __The work is an @'Agentic.Workflow.act'@ and could not have been anything
-- else.__ @Agentic.Acp.permissionByCode@ grants a tool call only during an act:
-- a question asked at @text@, @verdict@ or @flag@ is refused the workspace for
-- the duration of its turn. So \"fully implement or resolve the item\" is the
-- @act@ inside 'checklistRoundFn', and a gate whose repair was a @text@ ask
-- would have been a loop that could not change the file it was testing.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Checklist
  ( -- * The program
    checklistProgram,
    checklistDoc,
    checklistScript,

    -- * The round two call sites share
    checklistRoundFn,
    checklistReportFn,
    checklistTable,

    -- * The one place an absent input is given a meaning
    checklistFile,
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

-- | The party a round's work is done through.
--
-- A @tool@ with __no__ argv, for 'Workflows.Git.Commit''s reason: the argv of
-- \"fully implement or resolve the item\" is not knowable to this program — it
-- is whatever the item says — and an @'Agentic.Workflow.act'@ at
-- @'Agentic.Raw.CodeAck'@ is the only kind of answer the ACP transport grants
-- write authority to. Everything this tree /can/ name as an argv is in
-- "Workflows.Evidence"; this is the case where it cannot, and the act is where
-- that shows.
worker :: Party 'IsTool
worker = tool "checklist-worker"

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the opening receipt is introduced as.
--
-- /Source:/ @commands\/process-checklist.md@'s first line — \"you have been
-- given a Markdown checklist of tasks in: $ARGUMENTS\". In the corpus the file
-- is opened by whichever agent read the command; here it is @cat@ in the run's
-- own working directory, so the list the program branches on is bytes.
listBrief :: Text
listBrief =
  [wft|
  The Markdown checklist this run was given, as it stands on disk before any
  work has been done to it. Every task in it is either checked off already or
  is work this run is here to do.|]

-- | The same file, re-read after the first round.
afterBrief :: Text
afterBrief =
  [wft|
  The same checklist, re-read from disk now that the first round has finished
  with it. This is the file as it stands, not an account of what was done to
  it: anything still unchecked here is still undone.|]

-- | The same file, re-read after the self-verify round.
finalBrief :: Text
finalBrief =
  [wft|
  The same checklist, re-read from disk after the self-verification round.
  This is the last look this run takes at it.|]

-- | What the round's first question asks for.
--
-- /Source:/ @commands\/process-checklist.md@ items 1 and 4 — \"verify the task
-- is still incomplete\" and \"repeat for the next item until all are
-- complete\" — which together are a question about /order/ and about /whether
-- each item is really outstanding/, and are asked here before anything is done
-- rather than remembered while it is.
orderBrief :: Text
orderBrief =
  [wft|
  Below is a Markdown checklist. Decide what this round does, and answer with
  that and nothing else.

  Work only on tasks whose box is unchecked. For each one, in the order you
  give them:

  1. Say whether it is still genuinely incomplete. A box may be unchecked
     because the work was done and nobody ticked it; say so where the
     checklist or the surrounding tree shows it, and say what shows it.
  2. Say what completing it consists of, concretely enough that somebody
     could do it without asking you a question.
  3. Say what will show it is complete -- the command to run, the file to
     look at, the behaviour to observe.

  Order them so that a task whose result another task needs comes first. If
  two are independent, keep the checklist's own order: a reader of the file
  should recognise the sequence.

  Answer with one numbered entry per task and nothing else.|]

-- | What the round's act is told.
--
-- /Source:/ @commands\/process-checklist.md@ items 2 and 3 — \"fully implement
-- or resolve the item, and confirm it is complete\" and \"check off the item in
-- the checklist\" — with the standing no-deferral rule spliced from
-- "Workflows.Rubrics.Discipline", which is where that sentence lives once.
workBrief :: Text
workBrief =
  [wft|
  Carry out the round below, against the checklist file named in it.

  For each entry in the plan, in the order given: do the work, confirm it is
  actually complete by the check the entry names, and only then tick that
  item's box in the checklist file. A box ticked before its check has passed
  is worse than an unticked one, because the next round will not look at it
  again.

  Do not tick a box whose work you did not finish, do not delete or reword a
  task to make it finishable, and do not add tasks. If an entry turns out to
  be impossible or wrong, leave its box unchecked and append one line beneath
  it beginning `BLOCKED:` saying why -- the next round reads the file, and a
  line it can see is worth more than a paragraph in a reply nobody keeps.

  {discipline}

  When you are done, reply DONE.

  The plan for this round:|]
  where
    discipline = fixAllRule

-- ---------------------------------------------------------------------------
-- The three provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the checklist was already empty.
nothingLeftNote :: Text
nothingLeftNote =
  "Outcome: NOTHING TO DO. The checklist was read before any work was planned \
  \and no unchecked box was found in it, so no round ran and nothing was asked \
  \of anybody. Report that, and name the file that was read."

-- | The arm where the list came out empty.
clearedNote :: Text
clearedNote =
  "Outcome: CLEAR. The checklist was worked and then re-read from disk, and the \
  \re-read found no unchecked box. That test is a grep over the file's own \
  \bytes and not a claim by whoever did the work. Report the list as complete, \
  \and say which round each item was finished in if the file records it."

-- | The arm where items survived every round.
--
-- /Source:/ the sentence @commands\/process-checklist.md@ does not have. Its
-- loop says \"repeat as needed until the checklist is totally complete\", which
-- has no ending for the case where it is not — and a prose loop cannot be given
-- one.
unfinishedNote :: Text
unfinishedNote =
  "Outcome: ITEMS REMAIN. Every round this run was given has been spent and the \
  \checklist below, re-read from disk, still carries unchecked boxes. Do not \
  \report this run as complete. Name each box that is still open, quote any \
  \`BLOCKED:` line beneath it verbatim, and say what the next run would have to \
  \start with."

-- | The brief the report act is given.
--
-- /Source:/ the corpus command has no report section at all — it ends at
-- \"repeat as needed\". The shape is "Workflows.Report"'s: one act, a
-- @{provenance}@ parameter that the arms differ in, and a document that is the
-- file's own bytes.
checklistReportBrief :: Text
checklistReportBrief =
  [wft|
  Write the report for a checklist run. It is read by somebody who was not
  watching and who will decide from it whether the work is finished.

  Open with the provenance line you were given, verbatim, on its own line. It
  is the run's own account of how it ended and it is not yours to soften or
  to restate.

  Then, from the checklist below and nothing else:

  - one line per task, saying checked or unchecked, in the file's own order;
  - the count of each;
  - every line beginning `BLOCKED:` reproduced verbatim, under the task it
    sits beneath.

  Do not describe work that the checklist does not show. A ticked box is
  evidence that somebody ticked it; it is not evidence about the code, and
  this report does not pretend otherwise.|]

-- ---------------------------------------------------------------------------
-- The two functions
-- ---------------------------------------------------------------------------

-- | One round: decide what it does, then do it.
--
-- Two statements and two parameters, and it is called twice — once for the
-- pass and once for the self-verification pass, which is
-- @process-checklist.md@'s two paragraphs. A function rather than two copies for
-- "Workflows.Report"'s reason: a call is priced at the callee's own body with
-- the arguments ignored, so the second call site is free and the two rounds
-- cannot drift.
--
-- The @scope@ parameter is what the operator said the checklist is /for/, and it
-- rides into the ordering question because \"verify the task is still
-- incomplete\" is a judgment that needs to know what complete means here.
checklistRoundFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
checklistRoundFn =
  function
    "checklist.round"
    ( takes @"list" Text
        . takes @"scope" Text
        $ noParams
    )
    \list scope -> W.do
      plan <- ask (reasoning (model "sequence")) [wf|
          {orderBrief}

          What this checklist is for, in the operator's own words. It may be
          empty, and empty means the checklist stands on its own:

          {scope}

          The checklist:

          {list}|]

      act worker [wf|
          {workBrief}

          {plan}|]
      done

-- | The report the four endings share.
--
-- Two parameters, provenance first, for 'Workflows.Report.reportFn''s reason:
-- it is the thing a report must not omit, and it is the one argument the arms
-- differ in.
checklistReportFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
checklistReportFn =
  function
    "checklist.report"
    ( takes @"provenance" Text
        . takes @"list" Text
        $ noParams
    )
    \provenance list -> W.do
      act reporter [wf|
          {checklistReportBrief}

          Provenance:

          {provenance}

          The checklist, as last read from disk:

          {list}

          Write the report, then reply DONE.|]
      done

-- | The table 'checklistProgram' hands @'Agentic.Workflow.defining'@.
checklistTable :: [SomeFn]
checklistTable = [SomeFn checklistRoundFn, SomeFn checklistReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The file the run reads, and the one place an absent input is given a
-- meaning.
--
-- __Tier 1__ ("Workflows.Deciders"): the fact is in the invocation, so it is
-- ordinary Haskell over ordinary 'Data.Text.Text' and costs zero questions and
-- zero paths.
--
-- An absent input becomes a name no file has, deliberately, and
-- 'Workflows.Git.Commit.treeNeedle' is the precedent: @wf plan checklist --raw@
-- prints @cat \<no checklist file given\>@, so an operator who forgot the flag
-- learns it from the plan rather than from a run that analysed nothing.
checklistFile :: Text -> Text
checklistFile p
  | T.null (T.strip p) = "<no checklist file given>"
  | otherwise = T.strip p

-- | Two rounds over a checklist, each entered behind a free test.
--
-- Two inputs. @checklist@ is the path @process-checklist.md@ spells
-- @$ARGUMENTS@; @scope@ is what the list is for, and may be empty.
--
-- The shape, top to bottom: read the file; if nothing is unchecked, say so and
-- stop without spending anything; otherwise work a round, re-read the file, and
-- if anything survived, work the self-verification round and re-read once more.
-- Four endings, three provenance lines — the two that cleared share one, because
-- what they are reporting is the same fact reached in one round or in two — and
-- __one__ 'checklistReportFn', so no ending can quietly describe itself as
-- another.
--
-- Every test between rounds is a 'Agentic.Workflow.decide' over a @cat@ receipt:
-- zero questions, one path each, and nothing is trusted to report on its own
-- work.
checklistProgram :: Parameterized
checklistProgram =
  taking (input "checklist" :> input "scope" :> noInputs) \path scope ->
    let file = checklistFile path
     in defining checklistTable W.do
          -- The list, as bytes. This is the artefact every decision below reads.
          list <- ask (fileContents file) [wf|{listBrief}|]

          -- `process-checklist`'s loop condition, for zero questions.
          work <- tested hasUnchecked list

          if work
            then W.do
              -- The pass: the file's first paragraph.
              call_ checklistRoundFn (arg list :> arg scope :> noArgs)

              after <- ask (fileContents file) [wf|{afterBrief}|]
              again <- tested hasUnchecked after

              if again
                then W.do
                  -- The self-verification pass: the file's last line, which is
                  -- "repeat as needed" and is a number here.
                  call_ checklistRoundFn (arg after :> arg scope :> noArgs)

                  final <- ask (fileContents file) [wf|{finalBrief}|]
                  short <- tested hasUnchecked final

                  if short
                    then W.do
                      call_ checklistReportFn (arg unfinishedNote :> arg final :> noArgs)
                      stop
                    else W.do
                      call_ checklistReportFn (arg clearedNote :> arg final :> noArgs)
                      stop
                else W.do
                  call_ checklistReportFn (arg clearedNote :> arg after :> noArgs)
                  stop
            else W.do
              call_ checklistReportFn (arg nothingLeftNote :> arg list :> noArgs)
              stop

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
checklistDoc :: Text
checklistDoc =
  "process-checklist.md: two rounds over a Markdown checklist, each behind a free unchecked-box test"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every receipt's question opens with its own brief and
-- the round's opens with 'orderBrief'. Only the /text/ questions need entries —
-- @'Agentic.Exec.scriptedDefault'@ answers a receipt @DONE@, which is what both
-- acts want.
--
-- __The three file receipts are what steer the run, and they steer it down the
-- longest path.__ 'listBrief' answers with two unchecked boxes, so the first
-- decider says there is work; 'afterBrief' answers with one still open, so the
-- second says the self-verification round is needed; 'finalBrief' answers with
-- none, so the run ends in the /cleared/ arm. Change the last one to leave a box
-- open and the run ends in the /items remain/ arm instead — which is how the
-- ending nobody wants is exercised without a file, an agent or a network.
checklistScript :: [(Text, Text)]
checklistScript =
  [ (listBrief, before),
    (afterBrief, midway),
    (finalBrief, cleared),
    (orderBrief, plan)
  ]
  where
    before =
      "# Release checklist\n\
      \\n\
      \- [x] Cut the release branch\n\
      \- [ ] Regenerate the parser fixtures\n\
      \- [ ] Update CHANGELOG.md for 0.4.0"

    midway =
      "# Release checklist\n\
      \\n\
      \- [x] Cut the release branch\n\
      \- [x] Regenerate the parser fixtures\n\
      \- [ ] Update CHANGELOG.md for 0.4.0"

    cleared =
      "# Release checklist\n\
      \\n\
      \- [x] Cut the release branch\n\
      \- [x] Regenerate the parser fixtures\n\
      \- [x] Update CHANGELOG.md for 0.4.0"

    plan =
      "1. Regenerate the parser fixtures -- still incomplete: tests/fixtures/ \
      \is older than grammar.y. Run `make fixtures`; complete when \
      \`git diff --exit-code tests/fixtures` is clean.\n\
      \2. Update CHANGELOG.md for 0.4.0 -- still incomplete: the file's last \
      \entry is 0.3.2. Write the 0.4.0 section from `git log 0.3.2..HEAD`; \
      \complete when the top heading reads 0.4.0."
