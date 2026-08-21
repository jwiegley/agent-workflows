-- |
-- Module      : Workflows.Fix.Green
-- Description : The gated fix loop — check, repair, recheck, with the exit code
--               as the review clause.
--
-- __The fourth row the design names is deferred.__ Design §6.2 lists
-- @green-web@ (@commands\/webfix.md@, §7.2 row 66's rework) beside the three
-- rows below; it is not built: a browser-driving gate needs a Playwright argv
-- in "Workflows.Evidence" that nothing else wants yet, and a deferred row
-- recorded here is honest where a silently missing one is not. The design §8
-- completion amendment carries the same note.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                 | here                                                          |
-- +===========================================+===============================================================+
-- | @commands\/fix-ci.md@                     | @green-ci@ — the whole file, which is two sentences and an     |
-- |                                           | unbounded \"monitor … until everything passes\"                |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/bugbot.md@                     | 'botSweepFn', called by @green-ci@ — @fix-ci@'s second         |
-- |                                           | sentence is a silent, lossy copy of that 89-line protocol, and |
-- |                                           | a call is not a copy                                           |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/bugbot-stack.md@               | @green-ci@ per pull request; the stack walk is @stack@'s and   |
-- |                                           | not this program's                                            |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/flaky-rust.md@                 | @green-flaky@ — three independent draws of the same check      |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/nix-rebuild.md@, @lefthook.md@,| @green-tree@ — one gate over the working tree                  |
-- | @cleanup.md@, @skills\/wiggum@'s loop     |                                                                |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @skills\/fix-all\/SKILL.md@               | "Workflows.Rubrics.Discipline", spliced into the repair prompt |
-- +-------------------------------------------+---------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The receipt-authored check: the review clause /is/ the exit code.__
--      @fix-ci.md@ says \"monitor with @gh@ … until everything passes\", which
--      asks a model to run a command, read it, and report faithfully on its own
--      work. Here the review of each trip is
--      @ask (ghPrChecks n) [wf|{candidate}|]@ at __verdict__: "Agentic.Shell"
--      approves on exit @0@ and objects with the command's own first failing
--      line on nonzero. The repair reads what CI actually said, not a model's
--      memory of it. See 'Workflows.Gates.gate', where this is written once.
--
--   2. __A missing command is a third outcome, and the corpus has no word for
--      it.__ A check that is absent or outran its clock raises a
--      @GapTransportRefusal@: the gate did not say no, it did not run. Nine
--      corpus commands invoke real argv and not one of them can tell those
--      apart.
--
--   3. __The priced fan-out — of /trips/, not of reviewers.__ \"Until everything
--      passes\" is an unbounded loop with no budget an operator can read.
--      @'Agentic.Workflow.atMost'@ makes it a number, and
--      @'Agentic.Plan.costSummary'@ answers \"between one and n+1 checks\" as two
--      numbers before the run. @wf cost green-ci@ is the pre-spend contract that
--      @fix-ci.md@'s two sentences cannot write.
--
--   4. __The yielded exhaustion.__ Every corpus loop ends at \"until it passes\"
--      and none of them says what happens when it does not.
--      @'Agentic.Workflow.Unsettled'@ carries the candidate, so the exhausted
--      arm hands back the artefact the last repair produced and the final check
--      objected to — the tree keeps every edit — and reports it as still red
--      instead of throwing the work away or claiming success.
--
--   5. __The decider-read gate.__ @green-flaky@ separates /flaky/ from /broken/
--      with a fourth draw asked as a @flag@ — an exit code, decided by
--      "Agentic.Shell" and not by a model — so the distinction that is the whole
--      of @flaky-rust.md@ costs one question and one path, and is made by the
--      test runner rather than by the agent being asked to fix it.
--
--   6. __The protocol is called, not copied.__ @bugbot.md@'s five phases exist
--      once, as 'botSweepFn', and @green-ci@ calls it. A call is priced at the
--      callee's own body with the arguments ignored, so sharing it moves
--      @size@, @askNodes@ and every path by nothing — which is why the corpus's
--      reason for copying (\"it is only two sentences\") was never a saving.
--
--   7. __The ledger is bound once.__ @bugbot.md@ Phase 5 closes with \"if new
--      bot comments appeared during processing, ignore them\" — a scoping
--      invariant maintained by asking the runner to remember. Here the inventory
--      is one handle bound before the loop; a comment that arrives mid-run has
--      no way in, structurally.
--
-- == Why 'Workflows.Gates.gate' and not @revisingOn@
--
-- With an exec review, @AbandonedOn@ is unreachable: "Agentic.Shell" answers a
-- verdict with approve or object and never with a refusal, and a verdict decodes
-- as declined only on an __empty__ answer, which is a thing a model does and a
-- process does not. The three-ending ladder ('Workflows.Escalation.escalating')
-- is the right loop when the reviewer is a model whose refusal must end the run.
-- Here the reviewer is @gh pr checks@.
--
-- == One known gap, named rather than papered over
--
-- @green-ci@'s ledger is @'Workflows.Evidence.ghPrView'@, which is
-- @gh pr view N --json number,title,headRefOid,files,reviews@. That carries the
-- pull request's /reviews/ and not its review __threads__: no thread id, no
-- @isResolved@, no @author.__typename@. @commands\/bugbot.md@ Phase 1 steps 2–4
-- fetch exactly those three through @gh api graphql@, and 'inventoryBrief' —
-- which is that phase, transcribed — asks for them. So a live @green-ci@ builds
-- a thinner inventory than the Markdown does, and 'botSweepFn' is handed thread
-- ids it was not given.
--
-- Closing it is __one argv__, and the design of record already names it
-- (@ghGraphqlThreads@, §6.2). It is not written here: every argv in this tree
-- lives in "Workflows.Evidence" so that the one module where the read-only rule
-- could be broken is reviewable as a unit, and a program that spelled its own
-- @running@ pair would be the first exception to that. Reported as a finding
-- against "Workflows.Evidence"; nothing in this module routes around it.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Fix.Green
  ( -- * The rungs
    Rung (..),
    rungName,
    greenDoc,

    -- * The program
    greenProgram,
    greenScript,

    -- * The protocol that is called rather than copied
    botSweepFn,
    botProtocol,
  )
where

import Data.String (fromString)
import Data.Text (Text)
-- `Rung` and `rungName` are hidden because "Workflows.Rubrics.Ladder" already
-- spells both, for a different thing: there, a rung is one of the /review
-- ladder's/ five weights, transcribed from the corpus's own paragraph; here it
-- is one of the three things the owner means by "make it green". The two are
-- unrelated and the rubric's is the older name, so this module hides it rather
-- than renaming the transcription.
import Workflows.Prelude hiding (Rung, rungName)
import qualified Agentic.Workflow.Do as W
import Prelude

-- ---------------------------------------------------------------------------
-- The rungs
-- ---------------------------------------------------------------------------

-- | The three things the owner means by \"make it green\".
--
-- They differ in exactly one thing that matters — __which command decides__ —
-- and in one thing that follows from it: whether there is a bot ledger to sweep
-- first, and whether the check is worth drawing more than once.
data Rung
  = -- | @commands\/fix-ci.md@ + @commands\/bugbot.md@: the pull request's own
    -- check runs decide, and the bot threads are swept before the first repair.
    Ci
  | -- | @commands\/nix-rebuild.md@, @commands\/lefthook.md@,
    -- @commands\/cleanup.md@, @skills\/wiggum@: the working tree, and
    -- @nix flake check@ decides.
    Tree
  | -- | @commands\/flaky-rust.md@: the same check, drawn three times, and a
    -- fourth draw that separates flaky from broken.
    Flaky
  deriving (Eq, Show)

-- | The name the operator types.
rungName :: Rung -> Text
rungName Ci = "green-ci"
rungName Tree = "green-tree"
rungName Flaky = "green-flaky"

-- | The one line @wf list@ prints beside a rung.
greenDoc :: Rung -> Text
greenDoc Ci = "sweep the bot threads, then repair until `gh pr checks` exits 0"
greenDoc Tree = "repair the working tree until `nix flake check` exits 0"
greenDoc Flaky = "three drawn runs, a repair loop, and a fourth draw that says flaky or broken"

-- | How many repair trips a rung is given.
--
-- /Source:/ 'Workflows.Rubrics.Ladder.rungBound' is the same idea one module
-- over: the Markdown ladder orders its rungs by a feeling about weight, and a
-- number an operator can read before spending is what the paragraph was reaching
-- for. These three are the owner's own patience, written down.
rungBudget :: Rung -> Bound
rungBudget Ci = atMost 3
rungBudget Tree = atMost 3
rungBudget Flaky = atMost 2

-- | Which command decides, for a rung, given the target.
--
-- This is the whole difference between the three rungs, and it is one function.
rungCheck :: Rung -> Text -> Party 'IsTool
rungCheck Ci target = ghPrChecks target
rungCheck Tree _ = nixFlakeCheck
rungCheck Flaky _ = makeTest

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the ledger question asks for.
--
-- /Source:/ @commands\/bugbot.md@ Phase 1, steps 1–7, compressed to the part
-- that is about /what the inventory is/. Its steps 1–3 are @gh@ invocations, and
-- they are the argv of this question rather than instructions inside it.
inventoryBrief :: Text
inventoryBrief =
  [wft|
  This is the pull request's own record, as JSON, straight from the GitHub
  API. Build the complete inventory of unresolved automated-review items in
  it, as a numbered checklist, before any code changes.

  For each item: number, author, category (an inline review thread with a
  resolvable thread id, or a top-level PR comment), file and line where
  applicable, and a one-line summary of the issue raised.

  Filter to unresolved items from bot or automated authors only. An author is
  a bot if its __typename is "Bot" -- which catches cursor, graphite-app,
  github-actions and the rest regardless of how the login is spelled. As a
  fallback for a response missing __typename, also match a login containing
  "bot", "[bot]" or "app/". Exclude every human author.

  If there are zero such items, reply with exactly

    No unresolved bot comments found

  and nothing else.|]

-- | The five-phase protocol, as one text.
--
-- /Source:/ @commands\/bugbot.md@, Phases 2 through 5, with its @gh api graphql@
-- mutations carried because they are the operative part of Phase 4 and a
-- paraphrase of a mutation is not a mutation.
--
-- Phase 1 is not here: it is the /caller's/ opening question, so that the
-- inventory is a handle bound before anything is fixed rather than a step this
-- text asks a model to remember doing.
botProtocol :: Text
botProtocol =
  [wft|
  Work the inventory below through the remaining phases, in order. Do not skip
  or reorder them.

  FIX. For each item: read the comment carefully and understand the exact
  issue it raises; read the relevant source; make the change that addresses
  it. If the comment is purely informational or a false positive requiring no
  code change, note that explicitly -- you still must reply to it and resolve
  it. Commit fixes with clear messages referencing what was addressed.

  PUSH. Push all commits to the remote branch. If the push fails due to remote
  changes, pull with rebase first, then push again.

  REPLY AND RESOLVE. After pushing, process every item from the inventory.
  For a review thread, reply explaining what you fixed -- one or two sentences
  -- or why no change was needed, then resolve the thread:

    gh api graphql -f query='
      mutation($threadId: ID!, $body: String!) {{
        addPullRequestReviewThreadReply(input: {{pullRequestReviewThreadId: $threadId, body: $body}) {{
          comment {{ id }
        }
      }' -f threadId='THREAD_NODE_ID' -f body='Fixed: <brief explanation>'

    gh api graphql -f query='
      mutation($threadId: ID!) {{
        resolveReviewThread(input: {{threadId: $threadId}) {{
          thread {{ isResolved }
        }
      }' -f threadId='THREAD_NODE_ID'

  Confirm the response shows isResolved true; if not, retry once. For a
  top-level comment, reply on the issue and then minimize the original with
  classifier RESOLVED.

  VERIFY. Re-fetch every review thread and confirm that each inventory item is
  now resolved or minimized. Retry the reply-and-resolve step for any that are
  not. Report completion only when every item from the original inventory has
  been verified, with the final tally in the form "N/N bot comments resolved."

  The verification checks only items from the original inventory. If new bot
  comments appeared while you were working, ignore them: they belong to the
  next run.|]

-- | The one line the corpus repeats and never enforces.
--
-- /Source:/ @commands\/bugbot.md@ Phase 1 step 4, whose last sentence is in bold
-- there. It is one argument here so that the two callers of 'botSweepFn' cannot
-- disagree about it.
humansExcluded :: Text
humansExcluded =
  [wft|
  Exclude every human author, without exception. A human's review comment is not
  this run's business: replying to one on a bot's behalf is how an automated
  sweep starts answering a colleague.|]

-- | What the tree question asks for, at the @green-tree@ rung.
--
-- /Source:/ @commands\/cleanup.md@'s obligations and @skills\/wiggum@'s
-- environment discipline: the loop's subject is the working tree as it stands,
-- which is a receipt and not a description of one.
treeBrief :: Text
treeBrief =
  [wft|
  This is the working tree, as `git status --porcelain` wrote it. It is the
  starting point of a repair loop whose gate is a real command: state what is
  here, and do not characterise anything you cannot see in these bytes.|]

-- | What each drawn run of the check is asked.
--
-- /Source:/ @commands\/flaky-rust.md@, whose whole content is \"there are still
-- more flaky tests, as shown at @$ARGUMENTS@\" and a request that the tests
-- become robust and true signals of correctness.
drawBrief :: Text
drawBrief =
  [wft|
  One independent run of the test suite. This is a draw: the same command, run
  again, with no memory of the previous run.|]

-- | The triage brief for the flaky rung.
--
-- /Source:/ @commands\/flaky-rust.md@'s one sentence, given the shape it was
-- asking for. The three draws' verdicts are spliced below it, so the triage
-- reads the runs' own failing lines rather than a summary of them.
flakyTriageBrief :: Text
flakyTriageBrief =
  [wft|
  Three independent runs of the same test suite were made. Their verdicts
  follow: an approval is an exit 0, and an objection carries that run's own
  first failing line.

  Diagnose these tests so that they become robust and true signals of
  correctness and project health. Separate, explicitly:

  - tests that failed in every run -- these are broken, and the code or the
    test is wrong;
  - tests that failed in some runs and not others -- these are flaky, and the
    defect is in the test's dependence on time, ordering, shared state, the
    filesystem, the network or an unseeded random source;
  - tests that never failed.

  Never make a test pass by weakening it. A flaky test made quiet is a signal
  deleted.|]

-- | What the fourth draw is asked, as a flag.
--
-- /Source:/ @commands\/flaky-rust.md@'s standard -- \"robust and true signals\"
-- -- which is a claim about /repeatability/ and therefore about a second run,
-- not about the run that went green.
steadyBrief :: Text
steadyBrief =
  [wft|
  One more independent run of the same test suite, after the repairs. This one
  is asked as a yes-or-no: did it exit clean?|]

-- | What a repairing model is told, beside the failing line.
--
-- /Source:/ 'Workflows.Gates.repairBrief' (the part that is about /this trip/)
-- with @skills\/fix-all\/SKILL.md@'s two standing rules spliced by the caller,
-- which is what that module's haddock asks a caller to do.
--
-- The testing standard is deliberately __not__ here: it is a page, it would be
-- paid for once per trip, and the rule this loop actually needs from it — do not
-- weaken the check — is already 'Workflows.Gates.repairBrief''s second
-- paragraph.
greenRepair :: Text
greenRepair =
  [wft|
  {trip}

  {noDeferral}

  {upstream}|]
  where
    trip = repairBrief
    noDeferral = fixAllRule
    upstream = upstreamRule

-- | The provenance line a settled gate reports under.
greenNote :: Rung -> Text
greenNote r =
  "Outcome: GREEN. The check for rung `"
    <> rungName r
    <> [wft|
       ` exited 0. Everything below is what the run produced; the check's own
       approval, and not a model's account of it, is why this says green.|]

-- | The provenance line an exhausted gate reports under.
--
-- /Source:/ 'Workflows.Escalation.remainsNote', specialised. The sentence about
-- what was /not/ asked for is the load-bearing one and is kept: the candidate an
-- exhausted loop yields is the one the last repair produced and the final check
-- objected to, not one produced in answer to that objection.
stillRedNote :: Rung -> Text
stillRedNote r =
  "Outcome: STILL RED. The repair budget for rung `"
    <> rungName r
    <> [wft|
       ` ran out with the check still failing. The artefact below is what the
       last repair produced and the final check objected to; no trip was spent
       answering that last objection, and every edit the repairs made is still
       in the tree. Name the check that is red and the line it failed on. Do not
       describe this as finished.|]

-- | The provenance line the flaky rung's steady arm reports under.
steadyNote :: Text
steadyNote =
  [wft|
  Outcome: GREEN AND STEADY. After the repairs, an independent fourth run of the
  same suite also exited 0. Two clean runs is not a proof of determinism; say
  so, and say what would be.|]

-- | The provenance line the flaky rung's unsteady arm reports under.
unsteadyNote :: Text
unsteadyNote =
  [wft|
  Outcome: GREEN ONCE, NOT STEADY. The gate settled, and an independent fourth
  run of the same suite did not exit 0. That is the flake, still there, and it
  is the finding: report the suite as unfixed and name what the fourth run
  disagreed with the third about.|]

-- ---------------------------------------------------------------------------
-- The protocol that is called rather than copied
-- ---------------------------------------------------------------------------

-- | @commands\/bugbot.md@'s Phases 2–5, as the function @fix-ci@ copies in one
-- sentence.
--
-- An @'Agentic.Workflow.act'@ and not an @ask@: the phases push commits, post
-- replies and resolve threads, and an act at @receipt@ is the only kind of
-- answer the ACP transport grants write authority to. The corpus's version of
-- that distinction is the hope that a reviewer will not edit.
botSweepFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
botSweepFn =
  function
    "green.bots"
    ( takes @"inventory" Text
        . takes @"exclusions" Text
        $ noParams
    )
    \inventory exclusions -> W.do
      act (tool "bot-sweep") [wf|
          {botProtocol}

          {exclusions}

          The inventory:

          {inventory}

          Reply DONE when every item in it has been verified resolved.|]
      done

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The gated fix loop, at a rung.
--
-- One input, @target@: the pull request number at @green-ci@ (where it is the
-- /argv/ of both @gh@ commands, not a string a model parses), a one-line
-- description of what green means at @green-tree@, and the report of failing
-- tests at @green-flaky@.
--
-- Every rung has the same three-part shape — a ledger bound once, the gate, and
-- a total case over its two endings — and the rungs differ in which command
-- decides ('rungCheck'), how many trips it is given ('rungBudget'), and what
-- happens either side of the loop.
greenProgram :: Rung -> Parameterized
greenProgram r =
  taking (input "target" :> noInputs) \target ->
    defining (SomeFn botSweepFn : reportTable) case r of
      Ci -> W.do
        -- The ledger, bound ONCE. A comment arriving mid-run has no way in,
        -- which is `bugbot` Phase 5's scoping invariant made structural.
        inventory <- ask (ghPrView target) [wf|{inventoryBrief}|]

        -- The protocol `fix-ci` copies in prose, called instead of copied.
        call_ botSweepFn (arg inventory :> arg humansExcluded :> noArgs)

        -- The gate. The objection each repair reads is CI's own failing line.
        gated <- gate (rungCheck r target) greenRepair (reasoning (model "repair")) inventory (rungBudget r)

        case gated of
          Settled state -> W.do
            call_ reportFn (arg (greenNote r) :> arg state :> noArgs)
            stop
          Unsettled state -> W.do
            call_ reportFn (arg (stillRedNote r) :> arg state :> noArgs)
            stop
      Tree -> W.do
        facts <- ask gitStatus [wf|
            {treeBrief}

            What green means for this tree:

            {target}|]

        gated <- gate (rungCheck r target) greenRepair (reasoning (model "repair")) facts (rungBudget r)

        case gated of
          Settled state -> W.do
            call_ reportFn (arg (greenNote r) :> arg state :> noArgs)
            stop
          Unsettled state -> W.do
            call_ reportFn (arg (stillRedNote r) :> arg state :> noArgs)
            stop
      Flaky -> W.do
        -- Three draws of one command. Two draws of one prompt are two
        -- questions, which is what the memo bill prices apart -- and it is the
        -- thing `flaky-rust.md` is asking for and has no way to say.
        draws <-
          panel
            [ ask (rungCheck r target `drawing` i) [wf|{drawBrief}|]
            | i <- [1, 2, 3]
            ]

        report <- ask rustPro [wf|
            {flakyTriageBrief}

            The runs:

            {draws}

            What was reported failing:

            {target}|]

        gated <- gate (rungCheck r target) greenRepair rustPro report (rungBudget r)

        case gated of
          Settled state -> W.do
            -- The decider-read gate: a fourth draw, asked as a flag, so the
            -- flaky/broken call is an exit code and not a claim.
            steady <- passes (rungCheck r target `drawing` 4) [wf|{steadyBrief}|]
            if steady
              then W.do
                call_ reportFn (arg steadyNote :> arg state :> noArgs)
                stop
              else W.do
                call_ reportFn (arg unsteadyNote :> arg state :> noArgs)
                stop
          Unsettled state -> W.do
            call_ reportFn (arg (stillRedNote r) :> arg state :> noArgs)
            stop

-- | The canned replies a @--scripted@ run of a rung answers from.
--
-- __Most questions need no entry.__ @'Agentic.Exec.scriptedDefault'@ answers a
-- flag @yes@, a verdict @APPROVE@ and a receipt @DONE@ — so the gate's check
-- approves on the first trip and the run walks the @Settled@ arm, the bot
-- sweep's act and both report calls answer @DONE@, and the flaky rung's fourth
-- draw says steady. The repair's row is written anyway: it is the prompt a
-- second trip would send, and a table that only covers the path taken is a table
-- that goes stale the first time the gate objects.
--
-- __The one row that is not a text question is 'drawBrief', and it is deliberate.__
-- A draw is folded by @'Agentic.Workflow.panel'@, so it is asked at __verdict__,
-- and @'Agentic.Text.decodeVerdict'@ reads any non-empty answer that is not an
-- approval as an objection carrying its own lines. A default @APPROVE@ would
-- rehearse three clean runs, which is the one situation @green-flaky@ is never
-- invoked in; the row below objects with a failing line instead, so the scripted
-- run exercises the objecting fold and the triage question is handed what a red
-- suite actually looks like.
--
-- __A scripted run cannot make the three draws differ__, and the table is honest
-- about it: three draws of one prompt share one key, so the flake itself — a run
-- that disagrees with its siblings — is not a thing @--scripted@ can stage. What
-- it does stage is the decider-read gate that follows: the fourth draw is a flag,
-- @yes@ by default, and the unsteady arm is reached by adding @(steadyBrief,
-- \"no\")@ to this table, exactly as the ladder's failing arm is reached by
-- deleting a row from its own.
--
-- The keys are the defines themselves, so each is a prefix of the rendered
-- prompt by construction.
greenScript :: Rung -> [(Text, Text)]
greenScript r =
  [ (greenRepair, repairedAnswer),
    (drawBrief, drawnAnswer),
    (flakyTriageBrief, triagedAnswer)
  ]
    <> ledgerRow
  where
    ledgerRow = case r of
      Ci -> [(inventoryBrief, inventoryAnswer)]
      Tree -> [(treeBrief, treeAnswer)]
      Flaky -> []

    inventoryAnswer =
      [wft|
      1. cursor[bot] — review thread — src/parse.rs:118 — unchecked slice index
         when the header is empty.
      2. graphite-app[bot] — top-level comment — the stack's base branch moved;
         rebase before merging.|]

    -- fixture bytes, not prose: fake `git status --porcelain` stdout. The fence
    -- carries the exact bytes: the porcelain column's leading space survives
    -- common-strip, because the `??` line sets the common prefix at the fence
    -- margin.
    treeAnswer =
      [wft|
       M flake.nix
       M src/Parse.hs
      ?? src/Parse.hs.orig|]

    -- An objection, and it says so in its own first line: a verdict answer that
    -- is not an approval is read as one, and a canned "ok" would have been a
    -- passing run reported as a failing one.
    -- fixture bytes, not prose: fake test-runner stdout. The fence carries the
    -- exact bytes: the failure line keeps its four-space indent, because the
    -- lines around it sit at the fence margin and set the common prefix there.
    drawnAnswer =
      [wft|
      test tests::race_on_tempdir ... FAILED
      failures:
          tests::race_on_tempdir: File exists (os error 17) at /tmp/fixture
      test result: FAILED. 40 passed; 1 failed|]

    -- What the triage says when all three draws objected with the same line,
    -- which is what a scripted run can produce: same failure every time is the
    -- BROKEN column, and the shared-state diagnosis is what makes it also the
    -- suspect one. The flaky column is empty and says why, because a scripted
    -- run has no way to make one draw disagree with another.
    triagedAnswer =
      [wft|
      Broken: tests::race_on_tempdir failed in all three runs with the same
      line. It writes to a fixed path under /tmp, so it is also the shared-state
      candidate: under concurrency the same defect would present as a flake.
      Flaky: none. Three draws objected identically, which distinguishes nothing
      -- flakiness is a disagreement between runs.
      Never failed: the remaining 40.|]

    repairedAnswer =
      [wft|
      tests::race_on_tempdir now allocates its directory with
      tempfile::tempdir()
      and drops it at the end of the test, so two concurrent runs cannot
      collide.|]
