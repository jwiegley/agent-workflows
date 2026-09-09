-- |
-- Module      : Workflows.Refocus
-- Description : One clock-backed check of ongoing work against its frozen goal.
--
-- /Source:/ @skills\/refocus\/SKILL.md@, "When to check" and "The check".
-- A call is one checkpoint. Long-turn timing belongs to the acting agent;
-- this finite program starts no scheduler and interrupts no opaque tool call.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Refocus
  ( refocusFn,
    refocusProgram,
    refocusDoc,
    refocusHelp,
    refocusScript,
    refocusCadence,
    refocusExample,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import Workflows.Prelude
import Prelude

-- | /Source:/ @skills\/refocus\/SKILL.md@, "When to check" and step 5.
-- Shared with Wiggum's acting prompts; the caller owns the durable task state.
refocusCadence :: Text
refocusCadence =
  [wft|
  Keep refocusing throughout active work, including long turns. Read an actual
  clock at work-unit boundaries and before and after long tool calls or waits.
  Complete focus checks at most 60 minutes of wall-clock time apart; check
  sooner for unplanned investigations, repeated retries, or optional polish.
  Compare the full goal, latest user corrections and completion criteria with
  current work, drop detours, and choose the shortest sound required next step.
  Preserve required dependencies, fixes, tests, approval boundaries and stop
  requests. Do not lower the goal or discard work to finish sooner.

  Record the check time, goal, scope correction and next step in the existing
  task state or handoff, with the next deadline no later than 60 minutes from
  the clock reading. Give a brief progress update if the plan changes.
  Use bounded waits that allow checks before that deadline;
  do not cancel useful work merely to refocus. On resume or after compaction,
  re-read these instructions and recorded state and refocus before new work.
  If a timestamp is missing or no clock is available, refocus immediately and
  at every work-unit boundary until timing is available. Never infer elapsed
  time from turns or tokens, or claim an hourly deadline without clock evidence.
  Already authorized work requires no renewed permission.|]

-- | /Source:/ @skills\/refocus\/SKILL.md@, "When to check", clock clause.
clockBrief :: Text
clockBrief = "Read the current UTC time for this focus checkpoint."

-- | /Source:/ @skills\/refocus\/SKILL.md@, "The check", steps 1-5.
focusBrief :: Text
focusBrief =
  [wft|
  Refocus the current work against the full frozen goal and completion criteria.
  Re-read the supplied plan and standing account, including the user's latest
  corrections. Which unmet requirement does the current action satisfy or
  unblock? Identify unrelated cleanup, speculative features, widening inquiries,
  repeated checks without new evidence, and polish beyond the requested result.
  Stop pursuing detours that satisfy or unblock no requirement. Keep necessary
  dependencies, fixes and verification in scope; do not discard work or lower
  completion criteria. Useful unrelated findings may be noted briefly for the
  existing tracker, without turning that note into new work.

  Return only a few lines: check time from the clock receipt, the goal, any
  scope correction, the shortest sound next step toward an unmet requirement,
  and a next deadline no later than 60 minutes from that receipt. If every
  requirement has evidence, say finish; do not invent verification. If a user
  decision blocks progress, identify it under the active workflow's rules.
  Preserve approvals and stop requests; do not seek renewed permission for
  authorized work. This is an assessment: do not edit files, update trackers,
  commit, or ask the user questions. The caller carries this record forward.
  Missing timing evidence must be named, never replaced with an estimate.
  If no goal was supplied, report that omission rather than inventing one.|]

-- | A clock receipt followed by one judgment, returned for another workflow.
-- The request includes the checkpoint context: observations are memoized by
-- question, so the two Wiggum rounds must not ask one context-free clock question.
refocusFn :: Fn '[ 'CodeText, 'CodeText] 'CodeText
refocusFn =
  function
    "refocus.check"
    ( takes @"plan" Text
        . takes @"standing" Text
        $ noParams
    )
    \plan standing -> W.do
      checkedAt <- ask utcNow [wf|
          {clockBrief}

          Frozen plan for this checkpoint:
          {plan}

          Current standing and previous checkpoint:
          {standing}|]
      assessment <- ask (reasoning (model "refocus")) [wf|
          {focusBrief}

          Clock receipt:
          {checkedAt}

          Frozen plan:
          {plan}

          Current standing and latest user corrections:
          {standing}|]
      answer assessment

-- | The standalone row returns the same assessment Wiggum receives.
refocusProgram :: ParameterizedOf 'CodeText
refocusProgram =
  taking (input "plan" :> input "standing" :> noInputs) \plan standing ->
    defining [SomeFn refocusFn] W.do
      assessment <- call refocusFn (arg plan :> arg standing :> noArgs)
      answer assessment

refocusDoc :: Text
refocusDoc = "check goal alignment against a clock receipt and choose the next required step"

refocusScript :: [(Text, Text)]
refocusScript =
  [ (clockBrief, "2026-09-09T12:00:00Z"),
    (focusBrief, refocusExample)
  ]

-- | The same checkpoint carried by the standalone and Wiggum rehearsals.
refocusExample :: Text
refocusExample =
  [wft|
  Checked: 2026-09-09T12:00:00Z; next deadline: 2026-09-09T13:00:00Z.
  Goal: complete the frozen plan with its required verification.
  Scope correction: stop unrelated polish; preserve required fixes and tests.
  Next step: finish the next unmet requirement, respecting existing approvals.|]

refocusHelp :: Text
refocusHelp =
  [wft|
  One focus checkpoint from `skills/refocus/SKILL.md`: read a UTC clock receipt,
  assess current work against the full goal, and return a brief typed text record
  with the next required step and deadline. The caller preserves that record.

  **Inputs.** `plan` is the frozen goal, accepted plan and completion criteria.
  `standing` is current progress, recent work, latest user corrections, approvals
  and any previous focus timestamps. Supply their contents with input files.

  **Transport.** ACP with the existing reasoning ladder; this assessment reads
  the clock and supplied context and requires no write permission.

  ```sh
  wf run refocus --engine acp --adapter claude --require-pinned \
    --input-file plan=PLAN.org --input-file standing=HANDOFF.md
  ```

  **Rehearsal.** Fixed replies replace both the clock and model; this checks
  wiring, not current time, hourly compliance or the quality of an assessment.

  ```sh
  wf run refocus --scripted --input-arg plan= --input-arg standing=
  ```

  **Caveats.** Wiggum calls this function before each work round. Agents carrying
  out long turns remain responsible for the cadence below. A standalone invocation
  makes one checkpoint; it starts no background scheduler and cannot interrupt an
  opaque tool call. It makes no edits, commits or permission requests.

  Clock observations include the checkpoint context so Wiggum's two rounds
  read it separately. Identical context within one memo scope can reuse a
  receipt; this function is not a universally fresh clock primitive.

  {refocusCadence}|]
