-- |
-- Module      : Workflows.Gates
-- Description : Check, fix, recheck — written once.
--
-- __Provenance.__ The single most repeated shape in
-- @~\/src\/nix\/config\/ai@: @commands\/fix-ci.md@'s monitor loop,
-- @commands\/restack.md@ step 5, @commands\/recommit.md@'s per-commit CI,
-- @commands\/process-checklist.md@'s fixpoint, @commands\/cleanup.md@'s four
-- obligations, @commands\/lefthook.md@'s pre-commit set,
-- @skills\/retest\/SKILL.md@'s phases, @commands\/productize.md@'s deliverables,
-- @skills\/wiggum\/SKILL.md@'s continuation loop. Nine spellings of one
-- function, called with a different command each time.
--
-- == The review clause is the exit code
--
-- That is the whole level-up, and it is one line of 'gate':
--
-- > verdict <- ask check [wf|{candidate}|]
--
-- where @check@ is a party under @'Agentic.Workflow.running'@. "Agentic.Shell"
-- answers a __verdict__ question by running the argv: exit @0@ approves, and a
-- nonzero exit objects __with the command's own first failing line__ — which
-- the amendment then splices into the repair prompt. The fixer reads what the
-- compiler actually said, not what a model remembered it saying.
--
-- A command that is missing or outran its clock is neither: it is a
-- @GapTransportRefusal@, and the run says so in the owner's own terms — the gate
-- did not say no, it did not run. No command in the corpus can make that
-- distinction, and every one of the nine wants it.
--
-- == Two grammar facts encoded here so no workflow rediscovers them
--
-- Both were checked against "Agentic.Workflow", not assumed.
--
--   1. __A revision's body is exactly one review and one amendment.__ No third
--      statement: @'Agentic.Workflow.act'@ and @'Agentic.Workflow.call_'@ have
--      @Step@ instances at @'Open s@ and @'Body r s@ only, and the instances at
--      @'Review@ and @'Amending@ are @TypeError@s. So per-trip work that is a
--      /pipeline/ must be unrolled outside the loop.
--   2. __@amend@ takes an 'Agentic.Workflow.Ask', not a call.__ A loop whose
--      per-trip work is five stages is __not__ a revision with five @call_@s in
--      its body. It is K unrolled rounds, each round a @call_@ behind a
--      'Agentic.Workflow.decide' on the previous round's receipt — with
--      @costSummary@ reporting min 1 round, max K, over K+1 paths. That is a
--      real charge, and it is the honest bound the corpus's prose declines to
--      state.
--
-- == There is no @mustPass@ combinator, and that is deliberate
--
-- The corpus's three sentinel gates want \"stop unless this passed\". That is
-- Haskell's own @when@:
--
-- > when ok $ W.do
-- >   … the rest of the run …
--
-- @'Agentic.Workflow.when'@ is terminal — it seals its body with the implicit
-- @stop@ an arm block ends in — so the failing arm is a @stop@ the compiler
-- supplies and the author cannot drop. A combinator taking \"the rest\" as an
-- argument would be that, spelled worse.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}

module Workflows.Gates
  ( -- * The free test, and the exit code
    tested,
    passes,

    -- * Check, fix, recheck
    gate,
    repairBrief,
  )
where

import Agentic.Workflow
  ( Bound,
    Code (CodeFlag, CodeText),
    Decider,
    KnownIx,
    Loop,
    Party,
    PartyK (IsModel, IsTool),
    Rhs,
    V,
    Words,
    amend,
    ask,
    confirm,
    decide,
    revising,
    wf,
    wft,
  )
import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)

-- ---------------------------------------------------------------------------
-- The free test, and the exit code
-- ---------------------------------------------------------------------------

-- | A "Workflows.Deciders" pair applied to a handle: a flag for zero questions.
--
-- > ok <- tested saysDone receipt
--
-- The pair travels together because a decider without its needles is half a
-- test, and this is the only place the two are ever separated.
tested :: (KnownIx h s) => (Decider, [Text]) -> V h 'CodeText -> Rhs s 'CodeFlag
tested (d, needles) v = decide d v needles

-- | A command's exit code, as a flag.
--
-- @'Agentic.Workflow.confirm'@ at a party under @'Agentic.Workflow.running'@:
-- "Agentic.Shell" answers a flag question with @code == ExitSuccess@, so a check
-- is a yes\/no that no model authored. Use this where the /answer/ is wanted and
-- 'gate' where the /objection/ is.
--
-- The words still go somewhere: they are written to the child's standard input,
-- so a check script can read what it is checking. A command that never reads
-- stdin does not wedge the run.
passes :: Party 'IsTool -> Words s -> Rhs s 'CodeFlag
passes = confirm

-- ---------------------------------------------------------------------------
-- Check, fix, recheck
-- ---------------------------------------------------------------------------

-- | The gate loop: run the check, and while it fails, hand the failure to a
-- fixer.
--
-- > gated <- gate nixFlakeCheck repairBrief (reasoning (model "repair")) tree (atMost 3)
-- > case gated of
-- >   Settled   t -> …   -- the check exited 0
-- >   Unsettled t -> …   -- still red after three repairs; the tree keeps the edits
--
-- __Both endings carry the candidate.__ @Unsettled@ hands back the artefact the
-- last amendment produced and the final check objected to — so an exhausted gate
-- can yield its work rather than throwing it away, which is what every one of
-- the nine corpus loops does by hand and none of them says.
--
-- __The bound is visible before the run.__ @'Agentic.Plan.costSummary'@ prices
-- the unrolled loop, so @cost@ answers \"between one and @n+1@ checks\" as two
-- numbers rather than as a paragraph about persistence.
gate ::
  (KnownIx h s) =>
  -- | the check, under @'Agentic.Workflow.running'@
  Party 'IsTool ->
  -- | what the fixer is told, beside the failing line
  Text ->
  -- | who repairs
  Party 'IsModel ->
  -- | the artefact under repair
  V h 'CodeText ->
  Bound ->
  Loop 'CodeText s
gate check repair fixer subject bound =
  revising subject bound \candidate -> W.do
    verdict <- ask check [wf|{candidate}|]
    amend
      ( ask fixer [wf|
          {repair}

          The check was run. Its verdict, and — where it failed — its own first
          failing line:

          {verdict}

          What it was run against:

          {candidate}|]
      )

-- | What a fixer is told, by default.
--
-- /Source:/ the shared instruction of @commands\/fix-ci.md@,
-- @commands\/cleanup.md@ and @skills\/fix-all\/SKILL.md@, reduced to the part
-- that is about /this trip/. The standing constraints — no deferrals, upstream
-- fixes, the testing standard — are 'Workflows.Rubrics.Discipline''s and are
-- spliced by the caller, because a repair prompt that carried all of them every
-- trip would be paying for them once per trip.
repairBrief :: Text
repairBrief =
  [wft|
  A check failed. Produce the corrected artefact and nothing else -- no
  commentary, no diff of your reasoning, no explanation above it. Your output
  is fed straight back to the same check.

  Fix the cause the failing line names. Do not silence the check, do not
  weaken it, and do not route around it: if the check is wrong, say so in one
  line at the top and leave the artefact unchanged, because a check quietly
  disabled is the failure this loop exists to prevent.|]
