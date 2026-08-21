-- |
-- Module      : Workflows.Wiggum
-- Description : The top of the loop — work, checkpoint, verify, with a price
--               printed before the first round.
--
-- == The map: old Markdown -> new program
--
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                  | here                                                         |
-- +============================================+==============================================================+
-- | @skills\/wiggum\/SKILL.md@                 | @wiggum@ — this program: the loop, the Definition of Done,   |
-- |                                            | the stop-and-escalate conditions, the cadence                |
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @skills\/wiggum\/references\/@             | 'wiggumCheckpointFn' — the final audit over the last work    |
-- | @fess-audit.md@                            | commit, which that file says to run \"before declaring the   |
-- |                                            | work done … even if the most recent commits were themselves  |
-- |                                            | fixes\"                                                      |
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @commands\/run-orchestrator.md@            | 'roundStages' and 'stageWaves' — its steps 1–8 as the        |
-- |                                            | round's obligation graph, sorted in Haskell                  |
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @commands\/commit.md@ (by prose reference)  | @call_ 'Workflows.Git.Commit.commitFn'@                       |
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @commands\/resolve.md@ (by prose reference) | @call 'Workflows.Git.Stack.resolveFn'@                        |
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @commands\/partner-cleanup.md@ (by prose    | @call_ 'Workflows.Partner.cleanupRoundFn'@                    |
-- | reference)                                 |                                                              |
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @agents\/fess-auditor.md@ (by prose         | 'Workflows.Rubrics.Fess.fessRoster' spread by                 |
-- | reference)                                 | 'Workflows.Panels.withEvidence', ending in                    |
-- |                                            | @call_ 'Workflows.Audit.Fess.fessReportFn'@                   |
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @skills\/parallelize\/SKILL.md@             | the sentinel probe, once, as this run's own precondition —    |
-- |                                            | under a free gate on @run.engine@ that is the /real/ test of  |
-- |                                            | a separate evaluator ('sharedSessionNote') — plus the fan-out |
-- |                                            | cap, /computed/ by 'stageWaves'                               |
-- +--------------------------------------------+--------------------------------------------------------------+
-- | @skills\/fix-all\/SKILL.md@                 | "Workflows.Rubrics.Discipline", spliced into the working act  |
-- +--------------------------------------------+--------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == Why this row is built last
--
-- @doc\/design.md@ §7.4 row 1 says it: \"@wiggum@, __built last__: it calls
-- almost everything.\" Five of its seven declared callees are other people's
-- functions — @commitFn@, @resolveFn@, @cleanupRoundFn@, @fessReportFn@ and,
-- inside @commitFn@, the whole commit discipline — and the two that are this
-- module's own are a round and a checkpoint. What is /new/ here is the shape:
-- a bound, a verdict set and three endings, which is the one thing an
-- autonomous loop must have before it starts and the corpus's version of it
-- does not.
--
-- == The leveling-up, item by item
--
--   1. __The loop has a price.__ This is wave 5's gate
--      (@doc\/design.md@ §8) and the whole reason the row exists:
--      @wf cost wiggum@ prints a finite @maxFold@ over finitely many paths
--      before the first token. @SKILL.md@'s loop is \"repeat until the
--      Definition of Done holds\", which is a budget nobody can read, and every
--      bound in it is a word: \"a bounded number of attempts (default 3)\",
--      \"roughly 3–5 at a time\", \"every four hours or so\". Here the bound is
--      @'Agentic.Workflow.atMost'@, the rounds are unrolled and counted, and the
--      fan-out cap is @'stageWaves'@'s widest wave rather than a guess.
--
--   2. __The durable-state section dissolves, exactly as the design predicted.__
--      Its three artefacts are the frozen plan, the handoff and the journal.
--      The frozen plan is a program __input__ — which is what makes \"read-only
--      for the purpose of lowering the bar\" true rather than requested, since
--      no question in this program can write to an input and the plan reaches
--      the verifier's brief in ordinary Haskell before the
--      'Agentic.Builder.Program' exists. The handoff is a __handle__
--      ('handoffBrief'), bound over receipts and read by the verifier. The
--      journal is @account-halt@'s @journalFn@, which is a different row.
--
--   3. __The three endings are a sum type, and the third one is written.__
--      @WORK COMPLETE@ \/ @WORK REMAINS@ \/ @WORK BLOCKED@ is
--      "Workflows.Escalation"'s own vocabulary, transplanted /from this skill/
--      in wave 1 and reaching its first caller here. The exhausted arm yields
--      its candidate, which is literally @SKILL.md@'s \"report where you are,
--      what you tried, and what you need\" — and the refusal arm is the
--      stop-and-escalate condition for requirements that turned out to be
--      ambiguous.
--
--   4. __\"Do NOT submit or push the stack\" becomes a command that does not
--      exist.__ @SKILL.md@ says it three times, in capitals twice, because it is
--      the one irreversible thing an unattended loop could do. There is no
--      @'Workflows.Evidence.gitPushLease'@ in this module, no @gh pr create@ and
--      no @gt submit@: the currency step is local, and the prohibition is an
--      __absence__ rather than a rule a tired runner is trusted with. Grep this
--      file for @push@ and the answer is this paragraph.
--
--   5. __The verifier is not the worker, and most of that is a type.__
--      \"Verification comes from a separate evaluator, not from grading your own
--      work\" is the skill's sharpest sentence and it has no mechanism. Here the
--      round's account is written over @git log@'s bytes, the suite's verdict is
--      the suite's own exit code, the audit is eleven independent stances on
--      three serving rungs, and the done-criteria judge is a party that answered
--      none of them.
--
--      __The part that is /not/ a type is the one the sentence is really
--      about__, and it is a fact rather than a shape: a party can be a different
--      /addressee/ and still be the same conversation. That is the engine's
--      doing, not the program's, and the program can only refuse to start — which
--      is 'sharedSessionNote', taken in Haskell over @run.engine@ before anything
--      is spent. Read that note for why the sentinel probe underneath it cannot
--      do this job.
--
--   6. __Steps 5 and 6 of @run-orchestrator.md@ stop being questions.__ \"Check
--      task dependencies\" and \"identify tasks that can run in parallel\" are,
--      in that file, work given to a coordinator /model/. Here the round's
--      obligations are 'roundStages' — a @[(Text, [Text])]@ — and 'stageWaves'
--      is a layered topological sort over it: __zero questions, zero paths__
--      (tier 1), and the answer is spliced into the round's own brief. That is
--      @doc\/design.md@ §7.2 row 59's rework, and it is the reason that command
--      is a fold into this row rather than a row of its own.
--
--   7. __The audit is called, not described.__ Four corpus files ask for a
--      @fess@ audit by name and none of them can make one happen.
--      'wiggumCheckpointFn' spreads 'Workflows.Rubrics.Fess.fessRoster' over the
--      diff and the receipts and ends in
--      @call_ 'Workflows.Audit.Fess.fessReportFn'@, with the original
--      request folded into all eleven briefs by
--      'Workflows.Audit.Fess.requesting' — where the request is the frozen plan,
--      which is what the reference file's context snapshot asks for first.
--
-- == Four honest notes
--
-- __The audit runs once per run, not once per commit.__ @SKILL.md@'s loop step 3
-- audits every commit; @references\/fess-audit.md@ then carves out the fix
-- commits and @partner-cleanup@'s own commit, and closes with the obligation
-- this program keeps: \"before declaring the work done, run one final audit over
-- the last work commit even if the most recent commits were themselves fixes.\"
-- One audit immediately before the verdict is that sentence; K audits would be K
-- eleven-stance fan-outs for a Definition-of-Done clause that is stated once.
-- The per-commit audit is a row that already exists — @wf run fess@ — and an
-- operator who wants it per commit has it.
--
-- __@fessAudit@ is a 'Agentic.Workflow.Parameterized' and not a
-- 'Agentic.Workflow.Fn', so it cannot be @call_@ed.__ What is callable is
-- @fessReportFn@; what is /shared/ is everything else the flagship exports —
-- the roster, the closing, the request fold and both provenance notes. So the
-- eleven briefs exist once, in "Workflows.Rubrics.Fess", and the fan-out here is
-- the same 'Workflows.Panels.withEvidence' call the flagship makes. No rubric
-- text is copied; the fan-out /statement/ is written twice, and turning it into a
-- function would mean rewriting a flagship whose numbers @ci\/workflows.sh@ pins.
--
-- __The restack's advancing command is an
-- @'Agentic.Workflow.act'@ with no argv.__ @SKILL.md@ says \"on a Graphite stack
-- follow the @restack@ procedure; off Graphite, @rebase@ and @resolve@\" — which
-- command that is, is a fact about the repository and not about this program, so
-- naming one would make the argv a lie half the time. What /is/ program-authored
-- is the doctrine (@call resolveFn@, the same body all four @stack@ rungs call)
-- and the postcondition (@git diff --check@, an exit code). The row that runs the
-- advancing command with a real argv is @wf run stack@, and it is a program
-- rather than a function, so it cannot be called from here.
--
-- __The bound is spent inside one run.__ @SKILL.md@ asks that the
-- stop-and-escalate attempt count be \"recorded in the handoff document so it
-- survives compaction\". A count that survives a fresh process is state outside
-- any program, and this one does not pretend to carry it: what it has instead is
-- @atMost 2@, printed by @wf cost@ before anything is spent, and an @UnsettledOn@
-- arm that hands back the candidate rather than thrashing.
--
-- == What stays with the skill, honestly
--
-- These are harness-level policies, not runs to price, and each is here because
-- pretending otherwise would be the manufacture @fess-auditor@ exists to catch.
--
--   * __The stop\/halt override.__ The Definition of Done opens: \"A user
--     request to stop or halt overrides everything below: acknowledge it,
--     record the current loop state, and stop immediately.\" A mid-run human
--     interrupt is a harness event — no question in this program can observe
--     one, so the override belongs to whoever is holding the run, exactly as
--     the skill states it.
--   * __Refresh after compaction.__ \"After every context compaction, before any
--     new work: re-read this skill, the frozen plan and the handoff in full.\" A
--     compaction is an event in the harness's context window and is invisible to
--     a program: there is nothing here to observe it, and a run that could not
--     see it cannot branch on it. What the section /demands/ does survive — the
--     baseline verification before touching anything new — and it is the flag at
--     the top of 'wiggumProgram'.
--   * __The durable files.__ @obr@ issues, @PLAN.org@, the handoff Markdown, the
--     journal. The plan and the handoff are an input and a handle here (see
--     item 2), which is the part that belongs in a program; the /files/ that
--     survive a machine death belong to the harness, and @account-halt@ is the
--     row that writes one.
--   * __The working policies.__ @CARGO_TARGET_DIR@, @~\/Products@ for build
--     products, @direnv exec .@, @git-surgeon@ over plain @git@. Every one of
--     them is an environment or tooling decision for whoever is holding the
--     hands, and none of them is expressible: "Agentic.Shell" runs an argv with
--     @proc@ and never a shell, so this tree cannot set an environment variable
--     at all. Recorded rather than reworded.
--   * __\"Do not enter this mode on your own — only when the user invokes it.\"__
--     A rule about who may /start/ a run, which is the invocation
--     (@wf run wiggum@) and not the program. The program has nothing to say
--     about it, and says nothing.
--   * __The clock.__ \"Restack every four hours or so.\" The skill already
--     replaces this with work-anchored cadence in its own next section, and here
--     the cadence /is/ the program's shape: one currency step, between the last
--     round and the checkpoint, so a restack and a commit never collide in one
--     step.
--   * __PAL MCP, and conferring for real decisions.__ Two rows exist for that
--     (@confer@, @effort-heavy@) and both are @Parameterized@, so neither can be
--     called from here. An operator who wants the consensus runs it.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Wiggum
  ( -- * The program
    wiggumProgram,
    wiggumDoc,
    wiggumScript,

    -- * @run-orchestrator.md@'s dependency graph, sorted in Haskell
    roundStages,
    stageGraph,
    stageWaves,
    roundWaves,
    roundFanOut,

    -- * The functions
    wiggumRoundFn,
    wiggumCheckpointFn,
    wiggumReportFn,
    wiggumTable,

    -- * The three bodies a second loop over the same shape borrows
    loopRoundFn,
    loopCheckpointFn,
    loopReportFn,

    -- * The defines a second loop's own term holes
    restacker,
    verdictTrips,
    orchestration,
    baselineBrief,
    currencyBrief,
    markersBrief,
    doneCriteriaBrief,
    continuationBrief,
    brokenBaseNote,
    conflictNote,
    notIndependentNote,
    doneNote,
    stillRemainsNote,
    cannotJudgeNote,

    -- * The two places an absent input is given a meaning
    trunkOf,
    parityClause,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Audit.Fess
  ( fessClosing,
    fessReportFn,
    fessScript,
    requesting,
    verifiedIndependence,
  )
import Workflows.Git.Commit
  ( CommitRung (Commit),
    commitFn,
    commitScript,
  )
import Workflows.Git.Stack
  ( StackRung (Restack),
    resolveFn,
    rungSpecialists,
    stackScript,
  )
import Workflows.Partner
  ( PartnerRole (Cleanup),
    cleanupRoundFn,
    observationsDir,
    partnerScript,
  )
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The two parties that are this program's own
-- ---------------------------------------------------------------------------

-- | The party a round's unit of work is done through.
--
-- A @tool@ with __no__ argv, for 'Workflows.Git.Commit''s reason: the argv of
-- \"advance one logical unit of work\" is whatever the plan says, and an
-- @'Agentic.Workflow.act'@ at @'Agentic.Raw.CodeAck'@ is the only kind of answer
-- the ACP transport grants write authority to. Everything this tree /can/ name
-- as an argv is in "Workflows.Evidence"; this is a case where it cannot, and the
-- act is where that shows.
worker :: Party 'IsTool
worker = tool "wiggum-work"

-- | The party the currency step is taken through.
--
-- A @tool@ with no argv, and the module header says why: whether the advancing
-- command is @gt restack@ or @git rebase@ is a fact about the repository. What
-- is program-authored either side of it is the doctrine (@resolveFn@) and the
-- postcondition (@'Workflows.Evidence.gitDiffCheck'@).
restacker :: Party 'IsTool
restacker = tool "wiggum-restack"

-- ---------------------------------------------------------------------------
-- Tier 1 — decided in Haskell, before the program exists
-- ---------------------------------------------------------------------------

-- | The base the branch is brought up to date with, and measured against.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s \"the branch is rebased or restacked
-- cleanly onto its base\", which names no default; @commands\/recommit.md@ and
-- @commands\/bankruptcy.md@ both say @main@ in so many words, and this program
-- means it too.
--
-- __Tier 1__ ("Workflows.Deciders"): zero questions and __zero paths__, because
-- it shapes an argv rather than adding a branch. Total on @\"\"@, which is house
-- rule 6.
trunkOf :: Text -> Text
trunkOf b
  | T.null (T.strip b) = "main"
  | otherwise = T.strip b

-- | The Definition of Done's last conjunct, which exists only when a target was
-- given.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@, two sentences of it: \"\\\"Parity\\\"
-- means the work matches a named reference target … If no target is given,
-- \\\"done\\\" means every objective of the current plan is complete and
-- independently verified\" and the Definition of Done's own \"if a parity target
-- was given, a parity check passes with evidence\".
--
-- __Tier 1, and the case the corpus states and cannot select between.__ Both
-- halves of that conditional are written here, one is chosen before the
-- 'Agentic.Builder.Program' exists, and @wf plan wiggum --raw@ prints the
-- conjunct the verifier will actually be held to.
parityClause :: Text -> Text
parityClause t
  | T.null (T.strip t) =
      [wft|
      No parity target was given. So "done" means every objective of the frozen
      plan below is complete AND independently verified -- and nothing more is
      required of the work than the plan asks for.|]
  | otherwise =
      [wft|
      A parity target WAS given, so the last clause of the definition of done is
      a parity check against it, passing with evidence rather than by assertion.
      The target: {target}|]
  where
    target = T.strip t

-- ---------------------------------------------------------------------------
-- run-orchestrator.md's dependency graph, sorted in Haskell
-- ---------------------------------------------------------------------------

-- | A round's obligations: the name, what it is, and what must be done first.
--
-- /Source:/ @commands\/run-orchestrator.md@'s numbered steps 1–8, folded onto
-- @skills\/wiggum\/SKILL.md@'s loop, which is where those steps happen.
--
-- __Two of that file's eight steps are deliberately not rows here__, and they
-- are the two @doc\/design.md@ §7.2 row 59 calls the rework: step 5 (\"check
-- task dependencies\") and step 6 (\"identify tasks that can run in parallel\").
-- They are not obligations, they are 'stageWaves' — a pure function of the third
-- column below. In the corpus they are work handed to a coordinator model, which
-- is a question asked about a table the program already holds.
roundStages :: [(Text, Text, [Text])]
roundStages =
  [ ( "decompose",
      "break the remaining work into concrete units and name the ONE this round advances",
      []
    ),
    ( "findings",
      "record what the investigation established, so the next round does not rediscover it",
      ["decompose"]
    ),
    ( "advance",
      "carry out that one unit -- a coherent change that builds and passes",
      ["decompose"]
    ),
    ( "commit",
      "commit it as an atomic, ordered series, through the standing commit discipline",
      ["advance"]
    ),
    ( "verify",
      "say what actually works against what should work, from the commands' own output",
      ["commit"]
    ),
    ( "account",
      "say where the round leaves the work, ending with the round's verdict word",
      ["findings", "verify"]
    )
  ]

-- | 'roundStages' with the descriptions dropped: the dependency graph itself.
stageGraph :: [(Text, [Text])]
stageGraph = [(n, ds) | (n, _, ds) <- roundStages]

-- | The layered topological sort: each wave is the set of stages whose
-- dependencies are all already done, so the stages within a wave are independent
-- of one another.
--
-- This is the whole of @run-orchestrator.md@ steps 5 and 6, and it costs
-- __zero questions and zero paths__: it is ordinary Haskell over an ordinary
-- list, applied before the 'Agentic.Builder.Program' exists.
--
-- __The cycle arm is written, and it is why this function is total.__ A table
-- with a dependency cycle has no next wave, and rather than loop forever this
-- emits what is left as one final wave. 'stageGraph' has no cycle; that is a
-- fact about the table, and the arm below is what makes it a fact this function
-- does not have to be trusted about.
stageWaves :: [(Text, [Text])] -> [[Text]]
stageWaves g = go (map fst g) []
  where
    go [] _ = []
    go pending settled =
      case [n | n <- pending, all (`elem` settled) (depsOf n)] of
        [] -> [pending]
        wave -> wave : go [n | n <- pending, n `notElem` wave] (settled <> wave)

    depsOf n = concat [ds | (m, ds) <- g, m == n]

-- | 'stageGraph', sorted.
roundWaves :: [[Text]]
roundWaves = stageWaves stageGraph

-- | The widest wave — this round's fan-out, __computed__.
--
-- /Source:/ @skills\/parallelize\/SKILL.md@'s \"bound fan-out to what you can
-- review (roughly 3–5 at a time)\", which is a guess about a number the graph
-- above determines. "Workflows.Panels"' header says the arity discipline is what
-- survives of that skill; this is the arity, and it is arithmetic rather than
-- advice.
roundFanOut :: Int
roundFanOut = maximum (1 : map length roundWaves)

-- | The waves, as the text a round's brief carries.
--
-- Derived from the same table the graph is built from, so a stage added to
-- 'roundStages' reaches the brief __by being added__ — which is
-- 'Workflows.Panels.memberNote''s rule at a different table.
orchestration :: Text
orchestration =
  [wft|
  The obligations of one round, in dependency order. This ordering is not
  advice and was not computed by anybody you can argue with: it is a
  topological sort of the round's own dependency table, done before this
  question existed.

  {waves}

  What each obligation is:

  {table}

  Stages listed together on one line are independent of each other and may be
  advanced together. The widest line has {width} stages in it, so that is this
  round's fan-out -- not a number somebody guessed, and not a licence to widen
  it. Do not reorder the lines, and do not start a stage whose line has not
  been reached.|]
  where
    waves =
      numbered
        [T.intercalate ", " w | w <- roundWaves]
    table = bullets [(n, what) | (n, what, _) <- roundStages]
    width = tshow roundFanOut

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the baseline flag's words say.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@ @## Refresh after compaction@ — \"run a
-- baseline verification … to confirm the current state before touching anything
-- new. Starting new work on an already-broken base only makes it worse.\"
--
-- The words go to the child's standard input, which @nix flake check@ does not
-- read; they are here because @wf plan --raw@ prints them, so a reader of the
-- plan can see what the exit code is being asked about. That is
-- "Workflows.Gates"' own reason for writing one.
baselineBrief :: Text
baselineBrief =
  [wft|
  The baseline verification, before any new work: does this tree already build
  and pass? A nonzero exit here ends the run, because starting new work on an
  already-broken base only makes it worse.|]

-- | What the round's working act is told.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@ @## The loop@ item 1 and its
-- @## Cadence@ section, verbatim on the part that is a judgment about size, plus
-- the standing no-deferral rule spliced from "Workflows.Rubrics.Discipline" and
-- the two sentences of @## Working policies@ that are about /this/ act rather
-- than about the environment: no scope creep, and no routing around an
-- abstraction to reach the goal.
workBrief :: Text
workBrief =
  [wft|
  Advance the work by ONE logical unit: a coherent change that builds and
  passes on its own. If that unit is very small, take a larger step instead --
  a commit cycle is slow, and committing too often slows the work down without
  making it safer. Do not batch many units into one giant change either, and do
  not stop mid-unit.

  Avoid scope creep and stay on the goal you were given. Do not circumvent an
  existing abstraction merely to reach the goal expediently: the goal is not
  only the outcome, it is also the principled manner of getting there. If the
  shared path cannot express what this unit needs, correct the shared path and
  say that you did.

  {discipline}

  When the unit is finished and the tree builds and passes, reply DONE. The
  round below says what this unit is.|]
  where
    discipline = fixAllRule

-- | What this caller asks of the commit decomposition.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@ @## The loop@ item 2 and @## Cadence --
-- by work, not by clock@. It is the @style@ argument of
-- @'Workflows.Git.Commit.commitFn'@, which is the only thing a caller of that
-- function gets to say — and the sentence the skill spends a paragraph on is
-- exactly a statement about /this/ round's series.
roundCommitStyle :: Text
roundCommitStyle =
  [wft|
  This is one round of an autonomous work loop, and what is being committed is
  ONE completed logical unit of work. Commit at the unit, not inside it: a
  series that splits this unit into commits that do not each build is two
  commits written as one, and a series that folds several units together is a
  commit nobody can revert.

  Nothing is being published. The branch is not pushed and no pull request is
  opened by this run, so no message here is a message a reviewer reads first --
  write each one for whoever bisects this history later.|]

-- | What the cleanup cycle asks of the commit decomposition.
--
-- /Source:/ @commands\/partner-cleanup.md@'s @## Commit Rules@ — one commit for
-- the whole batch — reached from @skills\/wiggum\/SKILL.md@'s loop item 4, which
-- is where that workflow is invoked and where its commit belongs.
drainCommitStyle :: Text
drainCommitStyle =
  [wft|
  This is the cleanup of a batch of partner review observations, and it is ONE
  commit for the whole batch -- not one per observation, and not folded into
  the work commits that came before it. Commit only the cleanup changes and the
  removal of any tracked observation files.

  The message is of this shape:

    Address partner review observations

    Resolve observations from <first timestamp> through <last timestamp>.|]

-- | What the round's series receipt is introduced as.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s \"with evidence rather than
-- self-assertion\". The round's account below is written over these bytes rather
-- than over what the working act remembers doing, which is the difference
-- between a report and a claim.
roundSeriesBrief :: Text
roundSeriesBrief =
  [wft|
  What this branch now carries, oldest first, as `git log` reports it against
  the base this run was given. These are bytes; whoever did the work did not
  write them.|]

-- | What the round's closing question asks for.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s loop (\"repeat until the Definition of
-- Done holds or a stop condition fires\") and its @## Durable state@ item 2,
-- which is a list of exactly four things a handoff must carry.
--
-- __The last line is the sentinel__, and it is
-- @'Workflows.Deciders.saysComplete'@'s needle spelled out where the answerer
-- can see it: the two words come from 'Workflows.Escalation.endings', which was
-- transplanted from this skill, so the free test between rounds reads a word this
-- brief demanded rather than a word a reader hoped for.
roundAccountBrief :: Text
roundAccountBrief =
  [wft|
  Account for the round that has just finished. This is the handoff: it is the
  only thing the next round is given about this one, so write it for somebody
  who was not watching.

  Four things, in this order:

  1. What is now done, and what in the receipts below shows it.
  2. What remains, as concretely as the plan allows.
  3. How a fresh run would resume -- the first command, the first file.
  4. Any gate or failing signature that has now objected more than once, and
     how many times. A count nobody wrote down is a count that resets itself.

  Then end your answer with exactly one of these two lines, on its own last
  line and with nothing after it:

    WORK COMPLETE -- the frozen plan's objectives are all advanced as far as
    this loop can take them, and there is no next unit to start.

    WORK REMAINS -- the work is sound so far and there is more of it; item 2
    above says what the next unit is.

  That line is read mechanically. It decides whether another round is spent, so
  do not write it as a hope.|]

-- | What the currency act is told.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@ @## Keep the branch current@ and loop
-- item 5, including both capitalised prohibitions — which are carried as words
-- here and as an /absence/ in the program; see the module header, item 4.
currencyBrief :: Text
currencyBrief =
  [wft|
  Bring the branch current, LOCALLY. On a Graphite stack, follow the restack
  procedure: rebase from the base of the stack up to this branch, and not above
  it. Off Graphite, rebase onto the base and resolve.

  This is a currency operation and nothing else. Do NOT submit the stack, do
  NOT push, and do NOT open or update a pull request: publishing rewritten or
  shared history is a terminal action that a person takes, and it is not part
  of this loop. Nothing in this run can do it for you.

  Leave every conflict you cannot resolve without guessing intent exactly as it
  is, marked and unresolved, and say so. A guess committed is worse than a
  conflict reported.

  When the branch is current, or when it is not and you have said why, reply
  DONE. What the last round left is below.|]

-- | What the conflict-marker flag's words say.
--
-- /Source:/ @commands\/resolve.md@ and @commands\/rebase-and-fix.md@, whose
-- postcondition is exactly this, together with @skills\/wiggum\/SKILL.md@'s
-- stop-and-escalate condition \"a rebase or restack conflict cannot be resolved
-- without guessing intent\".
--
-- __Asked as a flag, and that is the level-up.__ In the corpus the condition is
-- a judgment a tired runner makes about its own rebase. @git diff --check@
-- exits nonzero when a conflict marker or a whitespace error survives, so the
-- answer is an exit code that no model authored — and the arm it selects is a
-- terminal.
markersBrief :: Text
markersBrief =
  [wft|
  Did the currency step leave the tree clean? A nonzero exit means a conflict
  marker or a whitespace error survived, which is the stop-and-escalate
  condition for a conflict that cannot be resolved without guessing intent.|]

-- | What the observations receipt is introduced as.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@ loop item 4 — \"check
-- @doc\/observations\/@; if non-hidden Markdown is present, run
-- @partner-cleanup@\" — read through
-- @'Workflows.Evidence.mdFilesIn'@, whose four filters are
-- @partner-cleanup.md@'s own scope clause.
observationsBrief :: Text
observationsBrief =
  [wft|
  The partner review observations standing in the directory this run was given,
  one path per line, as `find` reports them -- regular, non-hidden Markdown
  directly inside it, and nothing else. Sorted lexicographically this is
  chronological, because every filename is an ISO timestamp.|]

-- | What the suite's verdict receipt is introduced as.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s Definition of Done, second conjunct:
-- \"the build and the full test suite pass, and you have shown the passing
-- output.\"
--
-- __Asked at @verdict@ rather than at @text@__, and that is what makes the
-- conjunct checkable: "Agentic.Shell" approves on exit @0@ and objects __with
-- the command's own first failing line__ on nonzero, so a red suite is an answer
-- the done-criteria judge reads rather than a run that ended. A @text@ ask would
-- have abandoned the run on the one tree this clause exists to describe.
suiteBrief :: Text
suiteBrief =
  [wft|
  The repository's own green gate, run over the tree as the rounds left it.
  Whatever it says is the passing output the definition of done asks for; if it
  failed, its own first failing line is the answer.|]

-- | What the checkpoint's diff receipt is introduced as.
--
-- /Source:/ @agents\/fess-auditor.md@ @## What To Inspect@, items 1 and 2,
-- reached from @skills\/wiggum\/references\/fess-audit.md@'s context snapshot.
checkpointChangesBrief :: Text
checkpointChangesBrief =
  [wft|
  The work this loop produced, as `git diff` reports it against the base the run
  was given. This is the change under audit -- the diff itself, not a
  description of one.|]

-- | What the checkpoint's worktree receipt is introduced as.
checkpointWorktreeBrief :: Text
checkpointWorktreeBrief =
  [wft|
  The working tree as `git status --porcelain` reports it after the rounds and
  the currency step: every path with an uncommitted change, staged or not, and
  every untracked file. Anything listed here is work the commits do not carry.|]

-- | What the checkpoint's history receipt is introduced as.
checkpointHistoryBrief :: Text
checkpointHistoryBrief =
  [wft|
  The commits this loop produced, oldest first, as `git log` reports them
  against the base. The last of them is the work commit the final audit is
  about.|]

-- | What the handoff question asks for.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@ @## Durable state@ item 2, which is the
-- section @doc\/design.md@ §7.4 row 1 says __dissolves__. This is where it
-- dissolves /to/: the handoff is a handle in a priced program rather than a file
-- somebody has to remember to append to, and it is assembled from the receipts
-- above rather than from anybody's memory of them.
--
-- It is the candidate the bounded verdict loop revises, which is why it is asked
-- at all: 'Workflows.Escalation.escalating' needs one artefact, and the artefact
-- an autonomous loop is judged on is its own account of where the work stands.
handoffBrief :: Text
handoffBrief =
  [wft|
  Assemble the handoff for this run. It is the artefact the definition of done
  is applied to, and it is read by somebody who was not watching -- including,
  possibly, a fresh process on another day.

  Write it from the receipts and the rounds below and from nothing else. Six
  parts, in this order:

  1. What was done, one line per unit, each naming the commit that carries it.
  2. What remains.
  3. How to resume: the first command a fresh run would type.
  4. What the green gate said, quoted, including its failing line if it has
     one.
  5. What the audit found, by category, with `none` kept as `none`.
  6. Every gate or failing signature that has objected more than once, with its
     count.

  Do not describe work the receipts do not show, and do not soften what the
  gate said. A handoff that reads better than the tree is the failure this
  whole loop exists to prevent.|]

-- | The Definition of Done, as the judge's brief.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@ @## Definition of Done@, its six
-- conjuncts verbatim but for the two that are structural here, plus its
-- never-lower-the-bar paragraph and its reward-hacking prohibition. The parity
-- conjunct is 'parityClause', chosen in Haskell.
--
-- __What is deliberately absent.__ The conjunct \"the last work commit has
-- passed a final @fess@ audit\" is not a question put to this judge: the audit
-- ran, its findings are in the handoff, and the judge is asked to read them. And
-- the frozen plan arrives here as an input, spliced before the
-- 'Agentic.Builder.Program' exists — so \"never edit the plan or the
-- done-criteria to lower the bar\" is not a rule the judge is trusted with,
-- because the plan it is judging against is not something any question in this
-- program can reach.
doneCriteriaBrief :: Text -> Text -> Text
doneCriteriaBrief plan parity =
  [wft|
  You are the separate evaluator. You did none of the work below and you are
  not being asked to improve it: you are being asked whether it is done,
  against a plan that was frozen before it started.

  Exit successfully ONLY when ALL of these hold, with evidence in the handoff
  rather than self-assertion:

  - every planned task or done-criterion is complete;
  - the build and the full test suite pass, and the passing output is shown;
  - the last work commit has passed a final audit -- the audit's findings are
    in the handoff, and `none` in a category means somebody checked it;
  - no actionable partner observation is outstanding as of the last cleanup
    cycle (partner review does not necessarily drain to empty; a note that
    further, non-blocking observations are deferred is an acceptable ending);
  - the branch is rebased or restacked cleanly onto its base, locally.

  {parityConjunct}

  Never lower the bar. Do not restate a criterion more weakly, do not treat a
  weakened assertion, a skipped test or a hardcoded output as a criterion met,
  and do not accept "out of scope", "pre-existing" or "follow-up ticket" as an
  account of an incomplete item. If following the plan would require shipping
  something broken, say so plainly instead of approving it.

  The frozen plan, verbatim. It is the whole of what "done" means here:

  {frozen}|]
  where
    parityConjunct = parity
    frozen = frozenOr plan

-- | The plan, or the sentence an absent one earns.
--
-- __Tier 1__, and it is the one place this module decides what an absent plan
-- means: a run given no done-criteria has none, and the judge is told exactly
-- that rather than being left to invent them. @wf plan wiggum --raw@ prints this
-- sentence, so an operator who forgot the flag learns it from the plan.
frozenOr :: Text -> Text
frozenOr p
  | T.null (T.strip p) =
      [wft|
      (No plan was given to this run. There are therefore no frozen
      done-criteria to check the work against. Say that, and treat the run as
      unfinished: an autonomous loop with no stated target cannot have reached
      one.)|]
  | otherwise = T.strip p

-- | What the continuation is told when the judge objects.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s loop, read at the granularity a
-- revision's amendment actually has. What the amendment produces is the next
-- /handoff/ and not the next commit — a revision's body is exactly one review
-- and one amendment ("Workflows.Gates"), and an
-- @'Agentic.Workflow.ask'@ has no write authority under
-- @Agentic.Acp.permissionByCode@ — and the module header says so rather than
-- implying that a trip here advances the tree.
continuationBrief :: Text
continuationBrief =
  [wft|
  The evaluator has objected to the handoff below: by its reading, the
  definition of done does not yet hold, and its one line says what is missing.

  Produce the next version of the handoff and nothing else. You may not do the
  work from here and you may not change the tree: what you can do is account
  for the objection honestly -- fold in what the receipts already show and the
  last version missed, and where the objection names work that genuinely has
  not been done, say so in part 2 rather than dressing it up. A handoff amended
  into an approval it has not earned is the one outcome worse than an
  unfinished run.|]

-- ---------------------------------------------------------------------------
-- The provenance lines the endings differ in
-- ---------------------------------------------------------------------------

-- | The arm the __engine fact__ closes, before a question is put.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s \"verification comes from a separate
-- evaluator, not from grading your own work\", which is the clause this gate
-- actually enforces — and which the sentinel probe below it never could.
--
-- __Why this gate exists at all, which is the whole of the finding it closes.__
-- The probe asks whether a line /this runner planted/ was already in the
-- answerer's context. An ordinary used @agent-deck@ pane — one that did the work
-- and is now being asked to judge it — has no such line in it, so it answers
-- @PARENT_HISTORY_ABSENT@ truthfully and the probe passes. The loop would then
-- have started, run its rounds, and had its Definition of Done judged by the
-- party that wrote the work, with a report saying independence was verified. The
-- probe was detecting only the contamination the toolbox itself could cause.
--
-- __The fact that settles it is the runner's, and it is free.__ @run.engine@
-- ('Agentic.Workflow.runFacts') says whether every question of the run lands in
-- one conversation, and 'Agentic.Workflow.sharesOneSession' reads it — in
-- ordinary Haskell, before the 'Agentic.Builder.Program' exists. That is
-- "Workflows.Deciders"' __tier 1__: zero questions and zero paths, because the
-- arm not taken is not in the term. A 'Agentic.Workflow.decide' could not have
-- done it — a decider reads a @V h 'CodeText'@, a name bound in scope, and an
-- input is a define — and it would have been the more expensive answer anyway.
--
-- __Where the probe still earns its question.__ On the residual this fact cannot
-- see: an adapter that resumes a conversation behind the client's back, or a
-- fan-out that leaks one prompt into another. So the order is the honest one —
-- the engine first, for nothing, and the probe only for the runs the engine
-- cleared.
--
-- __What the gate reads now, and why the words did not change.__ The @case@ at
-- the top of 'wiggumProgram' calls
-- @'Workflows.Deciders.judgeIsElsewhere'@ — the general form, over
-- @run.routes@ as well as @run.engine@ and over the whole of
-- @'Workflows.Parties.ladderPins'@, shared with "Workflows.Duet" so the two rows
-- cannot drift. For /this/ row it computes the same answer for every command line
-- there is, because @opus@ serves both the judge and the round account, so the
-- judge's pin is itself one of the work-side pins the predicate compares against
-- and the whole thing reduces to @'Agentic.Workflow.sharesOneSession'@ exactly.
-- __That is a stronger statement than it looks__: it is what makes
-- @--route opus=deck:\<elsewhere\>@ a refusal here too, rather than a way to
-- move this row's judge into a pane of its own while its round account follows it
-- there. The sentence below is therefore still true of every run that reaches it,
-- and rewording it to mention a table this row cannot act on would be a note
-- saying something new about the work. A row that /can/ separate judge from work
-- says so in its own words; that is @'Workflows.Duet.duetProgram'@.
sharedSessionNote :: Text
sharedSessionNote =
  [wft|
  Outcome: WORK BLOCKED, AND NOTHING WAS STARTED. This run's engine puts every
  question of the run into one shared conversation -- the fact is quoted below
  and it came from the runner, not from anybody asked -- so the party that would
  have judged the work is the party that would have done it. No question was
  put: no round ran, no commit was made, no gate was run and no audit was asked
  for. Every clause of this loop's definition of done is a claim checked by an
  evaluator that must not be the runner, and under one shared session there is
  no such evaluator to reach. Report that, quote the engine fact, and say what
  would fix it: run this loop under an engine that opens a new session per
  question (`--engine acp`), which is the one transport here that can put a
  question to a party that has not read the answer.|]

-- | The whole of a refused run's material, which is the fact that refused it.
--
-- 'wiggumReportFn' is handed a provenance line and a state, and asks the reporter
-- for what the run has to show. A run stopped by 'sharedSessionNote' has shown
-- nothing, and the honest state is a sentence saying so with the read fact
-- quoted under it — rather than the engine text alone, which a reporter would
-- have to guess the meaning of, or a handle, of which there is none: no question
-- was put, so there is no receipt to pass.
sharedSessionState :: Text -> Text
sharedSessionState engine =
  [wft|
  Nothing ran, so there is no receipt, no commit, no gate output and no audit
  to account for -- and any of those in a report would be invented. The whole
  of this run's material is the one fact the gate read, which is this run's
  engine and its session policy:

  {engine}|]

-- | The arm where the sentinel probe did not pass.
--
-- /Source:/ @skills\/parallelize\/SKILL.md@'s \"a separate context window alone
-- is not evidence of independence\" and
-- 'Workflows.Rubrics.Discipline.unverifiedIndependence'.
--
-- __Why this is a terminal here and a downgrade in @fess@.__ The audit can
-- honestly run without a passing probe and report that it did — that is
-- @agents\/fess-auditor.md@'s own sentence, and 'Workflows.Audit.Fess' keeps it.
-- An autonomous loop cannot: every clause of its Definition of Done is a claim
-- checked by somebody who must not be the runner, so a loop that cannot show its
-- evaluator is separate has no way to finish and should not start spending.
--
-- __What it claims is now what it tested.__ It used to say the runner \"could not
-- be shown to dispatch without inheriting the parent transcript\", which is more
-- than a failing probe establishes and, worse, implied that a /passing/ one
-- established the converse. Reaching this arm means a line this run planted came
-- back — planted context, found — and that is what the sentence says.
-- 'sharedSessionNote' is the gate for the other half.
notIndependentNote :: Text
notIndependentNote =
  [wft|
  Outcome: WORK BLOCKED, AND NOTHING WAS STARTED. The parent-history sentinel
  probe did not answer PARENT_HISTORY_ABSENT: a line this run generated for
  itself and put in no other place came back, so context this runner planted was
  already in front of the answerer. No round ran, no commit was made and no
  audit was asked for. Every clause of this loop's definition of done is a claim
  checked by an evaluator that must not be the runner, and an answerer that has
  read another of this run's prompts is not one. Report that, name the probe's
  answer below, and say that the loop needs an engine that puts each question to
  a party that has seen no other before it can be run unattended.|]

-- | The run's own transport, appended to whichever ending was reached.
--
-- __Seven endings, seven lines, one statement about the run.__ The endings differ
-- in /what happened/; they do not differ in /what this run was/, so the two facts
-- go on once, here, rather than seven times in seven notes that would then have
-- to be kept in step.
--
-- __Why an autonomous loop owes the reader this.__ Every clause of this loop's
-- definition of done is a claim checked by somebody who must not be the runner
-- ('notIndependentNote' says so, and makes it a terminal). The engine is what
-- decides whether \"somebody else\" is even possible: under a new session per
-- question the evaluator's context is its own, and under one session for the
-- whole run it has read the work it is judging. That was previously invisible —
-- the run's header is terminal output and no party receives it — and it is now
-- @run.engine@ ('Agentic.Workflow.runFacts'), bound by the runner from the very
-- field the header prints.
--
-- The sentence is added and the ending's own words are untouched, because a
-- report opens with this line verbatim ('wiggumReportBrief') and a note reworded
-- to accommodate a fact would be a note that says something new about the work.
runProvenance :: Text -> Text -> Text -> Text
runProvenance backends engine note =
  [wft|
  {note} This run's answerers: {backends}. Its engine: {engine}. Both facts came
  from the runner and from no party asked below, and the second one is what
  this loop gates on before it spends anything: an evaluator that shared one
  conversation with the work it was judging is not the separate evaluator the
  definition of done requires, so a run whose engine says it would have is
  refused rather than reported on. Quote both facts and let the reader check
  the ending above against them.|]

-- | The arm where the baseline was already red.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@ @## Refresh after compaction@, last
-- sentence, which states the consequence and gives it nowhere to go: \"starting
-- new work on an already-broken base only makes it worse.\"
brokenBaseNote :: Text
brokenBaseNote =
  [wft|
  Outcome: WORK BLOCKED, ON A BROKEN BASE. The baseline verification was run
  before anything was touched and the repository's own green gate did not exit
  0, so no round ran and nothing in the tree was changed by this loop. Report
  the gate that failed and what it said. Starting new work here would only make
  it worse, and the next run's first job is the failure that was already
  present.|]

-- | The arm where the currency step left the tree marked up.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s stop-and-escalate condition three, and
-- its \"resolving conflicts with the @resolve@ workflow\" — whose postcondition
-- @commands\/resolve.md@ states and never tests.
conflictNote :: Text
conflictNote =
  [wft|
  Outcome: WORK BLOCKED, ON A CONFLICT. The rounds' work is committed, the
  currency step ran, and `git diff --check` then exited nonzero -- a conflict
  marker or a whitespace error survived it. This is the stop-and-escalate
  condition for a conflict that cannot be resolved without guessing intent, and
  it is a human's to settle. NOTHING WAS PUBLISHED and nothing in this loop can
  publish. Report the doctrine below, name every path still marked, and say what
  the resolution turns on.|]

-- | The @SettledOn@ arm.
--
-- /Source:/ 'Workflows.Escalation.completeNote', which was transplanted from
-- this skill's Definition of Done in wave 1, plus the clause that makes it this
-- program's: the evidence is named.
doneNote :: Text
doneNote =
  [wft|
  {completeNote} This is `wiggum`'s WORK COMPLETE: the evaluator was a party
  that answered none of the work's own questions, the audit ran over the last
  work commit, and the green gate's own output is in the handoff below. Say
  which clause of the definition of done each item satisfies, and end with what
  was deliberately left for a person -- publishing, above all, which this loop
  cannot do.|]

-- | The @UnsettledOn@ arm.
--
-- /Source:/ 'Workflows.Escalation.remainsNote' — whose load-bearing sentence
-- about the un-answered last objection is kept — closed with
-- @skills\/wiggum\/SKILL.md@'s own escalation line, verbatim: \"report where you
-- are, what you tried, and what you need.\"
stillRemainsNote :: Text
stillRemainsNote =
  [wft|
  {remainsNote} This is the bounded-attempt condition firing: the same criteria
  have now objected as many times as this run was given, which the skill's own
  rule says to escalate rather than thrash. Do a root-cause pass on the
  outstanding objection, and then report where you are, what you tried, and what
  you need.|]

-- | The @AbandonedOn@ arm.
--
-- /Source:/ 'Workflows.Escalation.blockedNote', closed with the two
-- stop-and-escalate conditions an empty verdict actually means here.
cannotJudgeNote :: Text
cannotJudgeNote =
  [wft|
  {blockedNote} For this loop that reading is specific: the evaluator could not
  judge the work against the plan it was given, which is the skill's
  "requirements are ambiguous or appear to have changed" condition. The work in
  the tree is committed and is not lost. Report what the plan does not settle,
  and what a person would have to decide before another round could help.|]

-- | The brief the report act is given.
--
-- /Source:/ the skill has no report section: it ends at \"report where you are,
-- what you tried, and what you need\", which is one sentence in the escalation
-- paragraph. The shape is "Workflows.Report"'s — one act, a @{provenance}@
-- parameter the arms differ in, and the run's own artefact.
wiggumReportBrief :: Text
wiggumReportBrief =
  [wft|
  Write the report for an autonomous work loop. It is read by the person who
  started it and walked away, and it is the only account they get.

  Open with the provenance line you were given, verbatim, on its own line. It
  is the run's own statement of how it ended and it is not yours to soften, to
  restate or to reorder. In particular: if it says the run is blocked, do not
  describe the work as finished, and if it says nothing was started, do not
  describe any work at all.

  Then, from the material below and nothing else:

  - what is done, and which commit carries each item;
  - what remains, and what the next run starts with;
  - what every gate said, quoted, including its failing lines;
  - what the audit found, category by category, with `none` left as `none`;
  - what was deliberately not done because it is a person's to do.

  Do not add work the material does not show. Do not report a count you were
  not given. Then reply DONE.|]

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | One round: advance a unit, commit it, and account for it over receipts.
--
-- Two parameters. @plan@ is the frozen plan, which every round reads; @standing@
-- is what the round is starting from — the orchestration for the first round and
-- the previous round's own account for the second, so a round is told where the
-- work stands by the round that left it there.
--
-- Three statements and an answer, and it is called __twice__. A function rather
-- than two copies for "Workflows.Report"'s reason: @rhsAsks@ prices a call at
-- the callee's own @bodyAsks@ with the arguments ignored and @graft@ splices the
-- callee's node rather than adding one, so the second call site is free and the
-- two rounds cannot drift.
--
-- __The commit is a call and not a copy.__ @skills\/wiggum\/SKILL.md@ says
-- \"@commit@, @restack@ and @rebase@ are user-triggered commands, so follow their
-- procedure rather than invoking them as slash commands\" — which is a request to
-- reproduce another file's procedure faithfully, from memory, every round.
-- @call_ commitFn@ is where that sentence ends.
--
-- __Built from the trunk__ because @git log@'s range is an argv and an argv is
-- part of the printed program: it cannot arrive through a parameter handle. A
-- 'Agentic.Workflow.Fn' is an ordinary Haskell value, so the base is captured
-- here and 'wiggumTable' is a function of it too — which is
-- @'Workflows.Expense.expenseBuildFn'@'s arrangement.
wiggumRoundFn :: Text -> Fn '[ 'CodeText, 'CodeText] 'CodeText
wiggumRoundFn = loopRoundFn "wiggum.round" reasoning

-- | 'wiggumRoundFn''s body, with the function's name and the account's rung as
-- parameters.
--
-- __Why the body is a parameter of two things and not two bodies.__
-- "Workflows.Duet" is the same round put to a /routed/ pane: one pin changes and
-- nothing else does. Two copies of these four statements would be two copies of
-- four briefs' call sites, and the drift would be silent because each copy would
-- pass its own canned table. @'Workflows.Report.reportFn'@'s argument at a
-- different granularity: the second call site is free and the two rounds cannot
-- disagree.
--
-- __@wiggum@'s own elaboration is untouched by this__, which is the thing to
-- check rather than assume: 'wiggumRoundFn' passes the name it always had and
-- @'Workflows.Parties.reasoning'@, which is the party it always pinned, so the
-- printed program, its @askNodes@, its paths and its price are the same values
-- they were.
loopRoundFn ::
  -- | the name this loop's round is declared under
  Text ->
  -- | the rung the round's account is put on
  (Party 'IsModel -> Party 'IsModel) ->
  -- | the base @git log@'s range is taken against
  Text ->
  Fn '[ 'CodeText, 'CodeText] 'CodeText
loopRoundFn name rung trunk =
  function
    name
    ( takes @"plan" Text
        . takes @"standing" Text
        $ noParams
    )
    \plan standing -> W.do
      act worker [wf|
          {workBrief}

          The frozen plan this loop is working to. It is not yours to edit:

          {plan}

          Where the work stands, and what this round is to advance:

          {standing}|]

      -- The commit discipline, called. Three corpus files say "use the commit
      -- workflow" and this is one of the two places that sentence ends.
      call_ commitFn (arg standing :> arg roundCommitStyle :> noArgs)

      -- What the world now holds. The account below is written over these bytes.
      series <- ask (gitLogSeries trunk) [wf|{roundSeriesBrief}|]

      account <- ask (rung (model "round-account")) [wf|
          {roundAccountBrief}

          The frozen plan:

          {plan}

          Where the work stood when this round began:

          {standing}

          The commit series this branch now carries:

          {series}|]
      answer account

-- | The checkpoint: drain the observations, commit them, gate the tree, audit
-- the last work commit, and assemble the handoff.
--
-- One parameter, @standing@: the last round's account, which is the thing the
-- handoff is built around.
--
-- Five obligations, and every one of them is a Definition-of-Done conjunct:
--
--   1. the partner cycle — @call_ cleanupRoundFn@ and then @call_ commitFn@,
--      because @partner-cleanup.md@'s rule is one commit for a completed batch
--      and the cleanup is not part of the work commits;
--   2. the green gate, at __verdict__, so its failing line survives into the
--      handoff instead of ending the run;
--   3. the change and the receipts, as bytes;
--   4. the final audit — eleven independent stances over that dossier, the
--      frozen plan folded into every one of them by
--      'Workflows.Audit.Fess.requesting', ending in @call_ fessReportFn@;
--   5. the handoff itself, assembled from all of it.
--
-- __Built from the trunk, the directory and the roster__ for
-- 'wiggumRoundFn''s reason: two of the three are argv and the third is folded in
-- ordinary Haskell before the 'Agentic.Builder.Program' exists.
--
-- __The audit's provenance is the passing one and not a choice.__ It can be, and
-- this is the only place in the tree where that is true: both gates are this
-- program's preconditions rather than steps inside it, so by the time this
-- function is reachable the engine has been read and the sentinel probe has
-- passed. The arms where either did not are terminals that never get here.
--
-- @provenance@ is therefore a Haskell parameter and not a constant:
-- 'Workflows.Audit.Fess.verifiedIndependence' states the engine fact as well as
-- the probe's answer, and that fact belongs to the run rather than to this
-- function. Folded in before the 'Agentic.Builder.Program' exists, like the
-- trunk and the roster beside it, so it costs the same nothing they do.
wiggumCheckpointFn :: Text -> Text -> Roster -> Text -> Fn '[ 'CodeText] 'CodeText
wiggumCheckpointFn = loopCheckpointFn "wiggum.checkpoint" reasoning

-- | 'wiggumCheckpointFn''s body, with the function's name and the handoff's rung
-- as parameters. See 'loopRoundFn' for why the body is shared rather than
-- copied.
--
-- __The rung is the handoff's and not the audit's__, and that asymmetry is
-- deliberate where a routed loop takes it: the eleven @fess@ stances inside keep
-- their own three serving rungs and therefore land on the run's default, while
-- the handoff is a /judgment about/ the work. The audit is evidence-gathering
-- and reads the work in the pane that did it; the verdict the definition of done
-- turns on is the thing that must be elsewhere, and only that is pinned there.
loopCheckpointFn ::
  -- | the name this loop's checkpoint is declared under
  Text ->
  -- | the rung the handoff is assembled on
  (Party 'IsModel -> Party 'IsModel) ->
  Text ->
  Text ->
  Roster ->
  Text ->
  Fn '[ 'CodeText] 'CodeText
loopCheckpointFn name rung trunk dir roster provenance =
  function
    name
    (takes @"standing" Text $ noParams)
    \standing -> W.do
      -- Loop item 4: the observations directory, as bytes, and the cycle the
      -- skill asks for by name.
      listing <- ask (mdFilesIn dir) [wf|{observationsBrief}|]
      drained <- call cleanupRoundFn (arg listing :> arg dir :> noArgs)
      call_ commitFn (arg drained :> arg drainCommitStyle :> noArgs)

      -- The second conjunct, as the gate's own verdict rather than as a claim.
      suite <- ask (nixFlakeCheck) [wf|{suiteBrief}|] `answering` Verdict

      -- The dossier the audit reads.
      changes <- ask (gitDiff [trunk]) [wf|{checkpointChangesBrief}|]
      evidence <-
        panelText
          [ ("worktree", ask gitStatus [wf|{checkpointWorktreeBrief}|]),
            ("history", ask (gitLogSeries trunk) [wf|{checkpointHistoryBrief}|])
          ]

      -- The final audit over the last work commit, which is
      -- `references/fess-audit.md`'s standing obligation. Eleven stances, three
      -- serving rungs, one fenced document.
      findings <- panelText (zip (lensNames roster) (withEvidence roster fessClosing changes evidence))
      call_ fessReportFn (arg findings :> arg evidence :> arg provenance :> noArgs)

      handoff <- ask (rung (model "handoff")) [wf|
          {handoffBrief}

          Where the last round left the work:

          {standing}

          What the cleanup cycle did with the partner observations it found:

          {drained}

          What the green gate said:

          {suite}

          The receipts:

          {evidence}

          What the audit found, category by category:

          {findings}|]
      answer handoff

-- | The report every ending calls.
--
-- Two parameters, provenance first, for 'Workflows.Report.reportFn''s reason: it
-- is the thing a report must not omit, and it is the one argument the seven arms
-- differ in. Seven endings, seven provenance lines, __one__ report — so no ending
-- can quietly describe itself as another, and in particular a blocked run cannot
-- come out reading like a finished one.
--
-- It is the only entry in 'wiggumRefusalTable' as well as the last in
-- 'wiggumTable', because the ending the engine fact closes is a program of its
-- own and still owes its operator an account.
wiggumReportFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
wiggumReportFn = loopReportFn "wiggum.report"

-- | 'wiggumReportFn''s body, with the function's name as its one parameter. See
-- 'loopRoundFn' for why the body is shared rather than copied.
--
-- No rung here: the report is an @'Agentic.Workflow.act'@ through
-- @'Workflows.Parties.reporter'@, which is a /tool/, and a tool is not served by
-- a model — so a routed loop's report lands on the default, with the work, which
-- is where the artefact belongs.
loopReportFn :: Text -> Fn '[ 'CodeText, 'CodeText] 'CodeAck
loopReportFn name =
  function
    name
    ( takes @"provenance" Text
        . takes @"state" Text
        $ noParams
    )
    \provenance state -> W.do
      act reporter [wf|
          {wiggumReportBrief}

          Provenance:

          {provenance}

          What this run has to show:

          {state}|]
      done

-- | The table 'wiggumProgram' hands @'Agentic.Workflow.defining'@.
--
-- Seven entries, and the order is the one @defining@ checks: a function may call
-- a function the table declared __earlier__. So the four callees this row does
-- not own come first — @commitFn@ and @cleanupRoundFn@ and @fessReportFn@ are
-- all called from inside a body below, which is why they cannot be listed after
-- it — then this module's round and checkpoint, then the report every arm ends
-- in.
--
-- @resolveFn@ is called from the program rather than from a body, so its
-- position is free; it sits with the other borrowed callees because that is
-- where a reader looks for them.
wiggumTable :: Text -> Text -> Roster -> Text -> [SomeFn]
wiggumTable trunk dir roster provenance =
  [ SomeFn commitFn,
    SomeFn cleanupRoundFn,
    SomeFn fessReportFn,
    SomeFn resolveFn,
    SomeFn (wiggumRoundFn trunk),
    SomeFn (wiggumCheckpointFn trunk dir roster provenance),
    SomeFn wiggumReportFn
  ]

-- | The table the __refused program__ hands @'Agentic.Workflow.defining'@: one
-- entry.
--
-- 'sharedSessionNote''s arm is a different program and not a different path — it
-- is chosen in Haskell, before there is anything to fold — and the only function
-- it can reach is the report. Declaring the other six would print six function
-- bodies, and therefore six prompts, into a program that cannot call one of
-- them: @wf plan@ would show them, Lean would check them, and @wf cost@ would
-- price a loop this program has already refused to start. A refusal should be
-- the size of a refusal.
--
-- The three terminals /inside/ the loop keep 'wiggumTable', because they are
-- arms of that program and reached over the very functions it declares.
wiggumRefusalTable :: [SomeFn]
wiggumRefusalTable = [SomeFn wiggumReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | How many rounds of judgment the verdict loop is given.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s first stop-and-escalate condition —
-- \"the same failing signature or gate persists after a bounded number of
-- attempts (default 3) without intervening progress\" — at the granularity this
-- loop actually has. Two amendments of the handoff plus the first judgment is
-- three readings of the criteria, which is that default; and
-- @'Agentic.Plan.costSummary'@ prices it before the run, where the Markdown
-- states it and has no way to hold to it.
verdictTrips :: Bound
verdictTrips = atMost 2

-- | The loop: one free gate, a probe, a baseline, two rounds, one currency step,
-- one checkpoint, one bounded verdict, seven endings.
--
-- Four inputs the operator gives, and four the runner gives
-- (@run.backends@, @run.engine@, @run.routes@, @run.sentinel@).
-- @plan@ is the frozen plan and its done-criteria — read-only by
-- construction, since it is an input; @base@ is what the branch is measured
-- against and brought up to date with (@main@ when absent); @observations@ is
-- the partner directory (@doc\/observations@ when absent); @parity@ is the
-- reference target, and an absent one is a different last conjunct rather than a
-- missing one ('parityClause').
--
-- __The first gate is not a step and costs nothing.__ 'sharedSessionNote' is
-- taken in ordinary Haskell, over the @run.engine@ and @run.routes@ inputs,
-- before this function has built a 'Agentic.Builder.Program' at all — so it is
-- not a path through the
-- loop, it is a different and much smaller program. Read that note for why the
-- loop needs it and why the probe underneath cannot do its job. The consequence
-- for the numbers is that there are two programs here and @wf plan@ prints
-- whichever the given engine selects; with the fact unbound, which is every
-- @plan@ and every @cost@, the answer is the loop — the shape a run with an
-- unknown engine takes, and the shape that keeps every check.
--
-- __Where the price comes from, top to bottom.__ One probe and one baseline
-- flag; then one or two rounds, each an act, a called commit discipline, a
-- receipt and an account; then a currency act, a called resolution doctrine and
-- a free exit code; then the checkpoint's drain, commit, gate, three receipts,
-- eleven stances and report; then a bounded three-way verdict over the handoff;
-- then one report. Four of the seven endings ask for nothing beyond the point
-- they are reached at, the shared-session one asks for nothing at all, and the
-- two cheapest of the rest — an inherited sentinel and a red baseline — spend two
-- consultations between them and change nothing.
--
-- __Why the tail is written twice.__ The second round is entered behind a free
-- test over the first round's own last line, and a bind is a statement rather
-- than a value, so the two arms cannot rejoin. 'Workflows.Git.Stack' states the
-- other half of the reason: a Haskell helper for the shared tail does not
-- typecheck, because @'Agentic.Builder.KnownIx' h s@ is weakened one entry at a
-- time and a helper binding four more names cannot state its own constraint
-- without spelling the exact shape of the scope at every use. Inlining is what
-- the language asks for; the /work/ in both tails is two calls and a loop, so
-- what is duplicated is six lines and no prompt.
wiggumProgram :: Parameterized
wiggumProgram =
  taking
    ( input "plan"
        :> input "base"
        :> input "observations"
        :> input "parity"
        :> input "run.backends"
        :> input "run.engine"
        :> input "run.routes"
        :> input "run.sentinel"
        :> noInputs
    )
    \plan base obs parity backends engine routes sentinel ->
      -- Tier 1, all of them: the argv, the directory, the roster the audit
      -- fans out over with the frozen plan folded in, the last conjunct of
      -- the definition of done, the probe's prompt at this run's own sentinel,
      -- and the provenance every ending is stated on. Ordinary Haskell, before
      -- the `Program` exists, so none of them costs a question or a path.
      let trunk = trunkOf base
          dir = observationsDir obs
          roster = requesting plan fessRoster
          criteria = doneCriteriaBrief plan (parityClause parity)
          doctrine = rungSpecialists Restack ""
          attestation = independenceAttestation sentinel
          onThisRun = runProvenance backends engine
          -- Tier 1 as well, and the one that decides which program this is: the
          -- two facts the checkpoint's audit states about itself.
          provenance = verifiedIndependence engine
       in -- The first gate, and it asks nobody. `run.engine` says whether every
          -- question of this run lands in one conversation and `run.routes` says
          -- which pin reaches which backend; between them they decide whether a
          -- separate evaluator is reachable at all -- and they are read here, in
          -- Haskell, so the refusing arm is a program with one function in it
          -- rather than a path with a cost. `sharedSessionNote` is why the probe
          -- below cannot answer this.
          --
          -- `Workflows.Deciders.judgeIsElsewhere` is the general form, shared
          -- with `Workflows.Duet` for `sharesOneSession`'s own reason: two gates
          -- spelled twice are two gates that stop agreeing, and the drift would
          -- be silent because each spelling would pass its own tests. HERE IT
          -- COMPUTES EXACTLY WHAT THE BLANKET REFUSAL DID, and that is checkable
          -- rather than hopeful: this row's judge is `model "done-criteria"` and
          -- its round account is `model "round-account"`, both on `reasoning`,
          -- both therefore served by `opus` -- so the judge's pin is ALSO a
          -- work-side pin, it is in the list below, `judge` is one of `works`
          -- under every route table there is, and the predicate reduces to
          -- `not (sharesOneSession engine)`. `ci/workflows.sh` pins the
          -- consequence: 34 paths and a ceiling of 44, unmoved.
          --
          -- `ladderPins` and not `[opus]`, though the two compute the same answer
          -- here: it is the four names `wf list --json` reports under `pins` for
          -- this row, so the list says what it means -- every pin this row's work
          -- reaches -- rather than the one name that happens to be sufficient
          -- while the round account sits on `reasoning`. `ci/workflows.sh` checks
          -- the list against that array, which the shorter one would fail.
          --
          -- A `case` and not an `if`, because under `RebindableSyntax` an `if`
          -- in this module is `Agentic.Workflow.ifThenElse` and takes a flag
          -- bound in a program. This choice is between two *programs*, and
          -- there is no program yet for a flag to live in.
          case judgeIsElsewhere routes engine opus ladderPins of
            False -> defining wiggumRefusalTable W.do
              call_
                wiggumReportFn
                ( arg (onThisRun sharedSessionNote)
                    :> arg (sharedSessionState engine)
                    :> noArgs
                )
              stop
            True -> defining (wiggumTable trunk dir roster provenance) W.do
              -- The second precondition, over the residual the engine fact
              -- cannot see: an adapter that resumed a conversation behind the
              -- client's back, or a fan-out that leaked one prompt into
              -- another. See `notIndependentNote` for why this is a terminal
              -- here and a downgrade in `fess`.
              probe <- ask (broad (model "independence")) [wf|{attestation}|]
              attested <- tested historyAbsent probe

              if attested
                then W.do
                  -- `Refresh after compaction`'s baseline, asked of the gate
                  -- rather than of whoever is about to start work.
                  ready <- passes nixFlakeCheck [wf|{baselineBrief}|]

                  if ready
                    then W.do
                      -- Round one. The orchestration it is handed is the sorted
                      -- obligation graph -- tier 1, and `run-orchestrator`'s
                      -- steps 5 and 6 already answered.
                      first <- call (wiggumRoundFn trunk) (arg plan :> arg orchestration :> noArgs)

                      -- The loop's own condition, for zero questions: the round's
                      -- last line, which `roundAccountBrief` demanded.
                      complete <- tested saysComplete first

                      if complete
                        then W.do
                          -- One round was enough. The cadence step still runs:
                          -- "the branch is rebased or restacked cleanly onto its
                          -- base" is a conjunct, not an optimisation.
                          act restacker [wf|
                              {currencyBrief}

                              {first}|]

                          resolved <- call resolveFn (arg doctrine :> noArgs)
                          clean <- passes gitDiffCheck [wf|{markersBrief}|]

                          if clean
                            then W.do
                              handoff <- call (wiggumCheckpointFn trunk dir roster provenance) (arg first :> noArgs)

                              judged <-
                                escalating
                                  (reasoning (model "done-criteria"))
                                  criteria
                                  (reasoning (model "continuation"))
                                  continuationBrief
                                  handoff
                                  verdictTrips

                              case judged of
                                SettledOn final -> W.do
                                  call_ wiggumReportFn (arg (onThisRun doneNote) :> arg final :> noArgs)
                                  stop
                                UnsettledOn final -> W.do
                                  call_ wiggumReportFn (arg (onThisRun stillRemainsNote) :> arg final :> noArgs)
                                  stop
                                AbandonedOn final -> W.do
                                  call_ wiggumReportFn (arg (onThisRun cannotJudgeNote) :> arg final :> noArgs)
                                  stop
                            else W.do
                              call_ wiggumReportFn (arg (onThisRun conflictNote) :> arg resolved :> noArgs)
                              stop
                        else W.do
                          -- Round two, entered because the first round's own last
                          -- line said the work remains.
                          second <- call (wiggumRoundFn trunk) (arg plan :> arg first :> noArgs)

                          act restacker [wf|
                              {currencyBrief}

                              {second}|]

                          resolved <- call resolveFn (arg doctrine :> noArgs)
                          clean <- passes gitDiffCheck [wf|{markersBrief}|]

                          if clean
                            then W.do
                              handoff <- call (wiggumCheckpointFn trunk dir roster provenance) (arg second :> noArgs)

                              judged <-
                                escalating
                                  (reasoning (model "done-criteria"))
                                  criteria
                                  (reasoning (model "continuation"))
                                  continuationBrief
                                  handoff
                                  verdictTrips

                              case judged of
                                SettledOn final -> W.do
                                  call_ wiggumReportFn (arg (onThisRun doneNote) :> arg final :> noArgs)
                                  stop
                                UnsettledOn final -> W.do
                                  call_ wiggumReportFn (arg (onThisRun stillRemainsNote) :> arg final :> noArgs)
                                  stop
                                AbandonedOn final -> W.do
                                  call_ wiggumReportFn (arg (onThisRun cannotJudgeNote) :> arg final :> noArgs)
                                  stop
                            else W.do
                              call_ wiggumReportFn (arg (onThisRun conflictNote) :> arg resolved :> noArgs)
                              stop
                    else W.do
                      call_ wiggumReportFn (arg (onThisRun brokenBaseNote) :> arg probe :> noArgs)
                      stop
                else W.do
                  call_ wiggumReportFn (arg (onThisRun notIndependentNote) :> arg probe :> noArgs)
                  stop

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
wiggumDoc :: Text
wiggumDoc =
  "wiggum/SKILL.md: two work rounds, one checkpoint audit, and a bounded done-criteria verdict"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every receipt's question opens with its own brief, the
-- round's account with 'roundAccountBrief', the handoff with 'handoffBrief'.
--
-- __Four of the five tables below are other rows' own__, spliced rather than
-- transcribed: 'Workflows.Git.Commit.commitScript' answers the commit
-- discipline, 'Workflows.Git.Stack.stackScript' answers the resolution doctrine,
-- 'Workflows.Partner.partnerScript' answers the cleanup round's two questions,
-- and 'Workflows.Audit.Fess.fessScript' answers the sentinel probe and, with one
-- entry, all eleven audit stances. A callee's canned answers belong to the
-- module that owns the callee's defines; keyed any other way they would go stale
-- the first time one of those files was reworded. Rows in those tables that this
-- program never asks are harmless — @'Agentic.Exec.scriptedReply'@ takes the
-- first key that is a prefix of the prompt — and this module's own rows come
-- first, so an overlap resolves here.
--
-- __The two rows that steer the run steer it down the two-round arm__ —
-- @billFresh 40@ against the ceiling of 44; the 44-fold paths need a
-- reviewer objection this table deliberately does not can.
-- 'roundAccountBrief' answers with @WORK REMAINS@ on its last line, so
-- 'Workflows.Deciders.saysComplete' says the work is not done and the __second__
-- round runs; change that last line to @WORK COMPLETE@ and the run rehearses the
-- one-round arm instead. Everything after it rides on the scripted defaults,
-- which is reachability evidence — exactly what this gate claims, and no
-- more: a flag is @yes@, so the baseline is green and
-- @git diff --check@ is clean; a verdict is @APPROVE@, so the green gate passes
-- and the done-criteria judge settles on its first reading — which is the
-- @SettledOn@ arm, this program's WORK COMPLETE.
--
-- The three arms nobody reaches by default are reached by one edit each, and
-- that is the point of writing them: delete @fessScript@'s probe row and the run
-- takes the inherited-sentinel terminal; add @(baselineBrief, \"no\")@ and it
-- takes the broken-base terminal; add @(markersBrief, \"no\")@ and it takes the
-- conflict terminal. All of them exit 0.
--
-- __The fourth arm is not reachable from this table at all__, and that is the
-- shape of the gate rather than a gap in the rehearsal. 'sharedSessionNote' is
-- chosen from @run.engine@ in Haskell, so a @--scripted@ run cannot be steered
-- into it by canning an answer: the scripted engine reaches no session, states
-- exactly that, and takes the loop. What reaches it is a command line —
-- @wf run wiggum --session \<pane\>@, whose engine says every question shares one
-- @agent-deck@ conversation — and the run then puts no question at all, which is
-- the one outcome no canned table can rehearse because there is nothing to can.
wiggumScript :: [(Text, Text)]
wiggumScript =
  [ (roundSeriesBrief, series),
    (roundAccountBrief, account),
    (observationsBrief, listing),
    (checkpointChangesBrief, changed),
    (checkpointWorktreeBrief, worktree),
    (checkpointHistoryBrief, series),
    (handoffBrief, handoff),
    (continuationBrief, amended)
  ]
    <> commitScript Commit
    <> stackScript Restack
    <> partnerScript Cleanup
    <> fessScript
  where
    -- fixture bytes, not prose: fake `git log --oneline` stdout. The fence
    -- carries the exact bytes, one commit a line.
    series =
      [wft|
      a1b2c3d Extract token validation into a module
      e4f5a6b Add unit tests for token validation
      c7d8e9f Implement refresh token rotation|]

    worktree = ""

    -- fixture bytes, not prose: a unified diff, trailing newline and all. The
    -- fence carries the exact bytes; the trailing newline is spliced, because a
    -- fence never ends in one.
    changed =
      [wft|
      --- a/src/token.rs
      +++ b/src/token.rs
      @@
      -    let _ = validate(tok);
      +    validate(tok)?;|]
        <> "\n"

    listing = observationsDir "" <> "/2026-08-19T09:14:02.117Z.md"

    -- Ends WORK REMAINS, so the free test between rounds says there is a second
    -- round to run. That one line is what makes the scripted run evidence about
    -- the long path.
    account =
      [wft|
      Done: token validation is extracted and tested (a1b2c3d, e4f5a6b), and
      refresh rotation now calls it (c7d8e9f).
      Remains: the rotation path has no test for an expired refresh token.
      Resume with: `cargo test refresh::` in the repository root.
      Repeated objections: none. No gate has objected twice.
      WORK REMAINS|]

    handoff =
      [wft|
      1. Extracted token validation into a module -- a1b2c3d.
      2. Added its unit tests -- e4f5a6b.
      3. Implemented refresh token rotation over the validator -- c7d8e9f.
      Remains: nothing the frozen plan names.
      Resume with: nothing; the plan's objectives are advanced.
      Green gate: exited 0 over the tree as the rounds left it.
      Audit: none in every category, each checked against the diff.
      Repeated objections: none.|]

    amended =
      [wft|
      The objection is that the rotation path's expired-token case is untested.
      That work has not been done, so it stays in `Remains` rather than being
      written up as done: the test is `cargo test refresh::expired`, and it does
      not exist yet.|]
