-- |
-- Module      : Workflows.Escalation
-- Description : The three-ending ladder — complete, remains, blocked.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/skills\/wiggum\/SKILL.md@ (the
-- autonomous-continuation loop and its stop-and-escalate condition);
-- @skills\/retest\/SKILL.md@ (\"report PASS/SKIPPED/QUARANTINED/DIVERGE/
-- NO-COVERAGE as distinct states, never collapse them into 'N/N PASS'\");
-- @skills\/abstraction-review@, @skills\/comment-audit@,
-- @skills\/eliminate-dead-code@, @skills\/alexey-review@, @skills\/forge@ and
-- @skills\/fix-all@, each of which carries a finite verdict set written as
-- prose.
--
-- Nine skills in the corpus name a closed set of outcomes in English. @retest@'s
-- line is the clearest: it is a request for a sum type, and it is made to a
-- Markdown file that has no way to grant it. Here the set is
-- @'Agentic.Workflow.Ending'@ and the compiler makes every arm be written.
--
-- == What the third ending buys
--
-- @'Agentic.Workflow.revising'@ tests approval, so an objection and a refusal
-- are the same thing to it: a reviewer that would not answer buys a trip that
-- should have ended the run. @'Agentic.Workflow.revisingOn'@ reads the review's
-- __verdict tag__ three ways — approval settles, an objection amends (or, at the
-- last round, leaves the loop @UnsettledOn@), a refusal abandons — which is
-- @WORK COMPLETE@ \/ @WORK REMAINS@ \/ @WORK BLOCKED@, made structural.
--
-- == One honest note, and it decides which loop to use
--
-- __With an exec review, @AbandonedOn@ is unreachable.__ "Agentic.Shell" answers
-- a verdict question with approve on exit @0@ and object on nonzero, and never
-- with a refusal: a command that is missing or timed out raises a
-- @GapTransportRefusal@ — a /gap/, not an answer. A verdict is decoded as
-- @declined@ only when the answer is __empty__, which is a thing a model does
-- and a process does not.
--
-- So:
--
--   * @'Workflows.Gates.gate'@ (two-way) is the right loop when the review is a
--     __command__;
--   * 'escalating' (three-way) is the right loop when the review is a
--     __model whose refusal must end the run__.
--
-- Writing @revisingOn@ around an exec review is not wrong, but it costs a
-- replication of the tail — the block is built three times at the Haskell level
-- and @2n+1@ times in the plan — to buy an arm nothing can take.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}

module Workflows.Escalation
  ( -- * The three endings, as the words a reviewer answers with
    endings,
    endingSpec,

    -- * The loop
    escalating,

    -- * What each ending is reported as
    completeNote,
    remainsNote,
    blockedNote,
  )
where

import Agentic.Workflow
  ( Bound,
    Code (CodeText),
    KnownIx,
    LoopOn,
    Party,
    PartyK (IsModel),
    V,
    amend,
    ask,
    revisingOn,
    wf,
    wft,
  )
import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)

-- ---------------------------------------------------------------------------
-- The three endings
-- ---------------------------------------------------------------------------

-- | The three words, and what each means, in the owner's own vocabulary.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s Definition of Done and its
-- stop-and-escalate condition, which are the first two; the third is the one
-- the skill describes at length and has no word for.
endings :: [(Text, Text)]
endings =
  [ ("WORK COMPLETE", "the definition of done holds, in full, and you can say which clause each item satisfies"),
    ("WORK REMAINS", "the work is sound so far and there is more of it; say what the next unit is"),
    ("WORK BLOCKED", "something outside this run has to change before the work can continue")
  ]

-- | The closing line a three-way review is given.
--
-- The @WORK BLOCKED@ clause is the one that has to be spelled carefully:
-- @'Agentic.Workflow.revisingOn'@ abandons on a __declined__ verdict, and a
-- verdict decodes as declined when the answer is __empty__. So the instruction
-- asks for an empty answer, and says why — a reviewer that writes a paragraph
-- explaining why it is blocked has objected, which buys another trip.
endingSpec :: Text
endingSpec =
  [wft|
  End your answer with exactly one of these, on its own last line:

  - APPROVE -- the work is complete as it stands.
  - OBJECTION: <one line> -- the work is sound but not done; the line says
    what remains, and it is the only thing the next round is told.

  If, and only if, you cannot judge the work at all -- the artefact is not
  what you were told it is, or something outside this run has to change first
  -- reply with NOTHING AT ALL: an empty answer. An empty answer ends the loop
  as blocked. An explanation of why you are blocked is an objection, and buys
  another round that cannot help.|]

-- ---------------------------------------------------------------------------
-- The loop
-- ---------------------------------------------------------------------------

-- | A bounded revision whose review is a model, and whose three verdict tags
-- become three endings.
--
-- > result <- escalating reviewer reviewBrief worker draft (atMost 3)
-- > case result of
-- >   SettledOn   x -> …   -- WORK COMPLETE
-- >   UnsettledOn x -> …   -- WORK REMAINS: the bound ran out, holding x
-- >   AbandonedOn x -> …   -- WORK BLOCKED: the reviewer would not judge it
--
-- Each constructor carries the candidate in hand, so no arm has to throw the
-- work away to report its ending — which is the difference between an
-- escalation and an abort.
--
-- The @case@ is total, so the third arm is a thing the author writes. That is
-- the point: nine corpus skills name a third outcome and every one of them
-- reaches it through prose that a tired reader collapses into the second.
escalating ::
  (KnownIx h s) =>
  -- | who judges
  Party 'IsModel ->
  -- | what the judge is told, above 'endingSpec'
  Text ->
  -- | who works
  Party 'IsModel ->
  -- | what the work is done to
  Text ->
  V h 'CodeText ->
  Bound ->
  LoopOn 'CodeText s
escalating judge judgeBrief worker workerBrief subject bound =
  revisingOn subject bound \candidate -> W.do
    verdict <- ask judge [wf|
        {judgeBrief}

        {candidate}

        {endingSpec}|]
    amend
      ( ask worker [wf|
          {workerBrief}

          What stands now:

          {candidate}

          What the reviewer said remains:

          {verdict}

          Produce the next version of the artefact and nothing else.|]
      )

-- ---------------------------------------------------------------------------
-- What each ending is reported as
-- ---------------------------------------------------------------------------

-- $notes
--
-- Three provenance lines, one per arm, spliced into whatever the arm reports
-- through. They exist so that the three arms of a @case@ can call __one__
-- report function with a different note rather than growing three report
-- functions that drift — which is @agents\/fess-auditor.md@'s \"run the audit
-- but report that its independence was not verified\", generalised.

-- | The @SettledOn@ note.
completeNote :: Text
completeNote =
  "Outcome: WORK COMPLETE. A review approved this artefact within the run's \
  \bound. Report it as finished."

-- | The @UnsettledOn@ note.
--
-- The sentence about what was /not/ asked for is load-bearing: the candidate an
-- exhausted loop yields is the one the last amendment produced and the final
-- review objected to — not one produced in response to that objection, which
-- was never requested.
remainsNote :: Text
remainsNote =
  "Outcome: WORK REMAINS. The bound ran out with an objection outstanding. The \
  \artefact below is what the last round produced and the final review objected \
  \to; no round was spent answering that last objection. Report what remains, \
  \and do not describe this as finished."

-- | The @AbandonedOn@ note.
blockedNote :: Text
blockedNote =
  "Outcome: WORK BLOCKED. The reviewer declined to judge the artefact, so no \
  \further round could help. Report what is blocking and what would have to \
  \change outside this run; do not report findings as though a review had been \
  \completed."
