-- |
-- Module      : Workflows.Duet
-- Description : The same loop, in two panes — work in one, judgment in the
--               other, driven by one invocation that owns neither.
--
-- == The ruling this row exists for
--
-- Two @agent-deck@ sessions, primed by the owner: one for the work, one for the
-- partner. __One__ @wf run@ that starts a work loop in the first and a review in
-- the second, and that keeps driving neither — the owner reads and types into
-- both while it runs, and when the run ends both panes are still attached, still
-- holding their history, still his. @wf@ is the driver and not the governor.
--
-- The transport already does that: @Agentic.AgentDeck@ holds no connection,
-- spawns no process and has no verb that could end a session. @--route@ already
-- dispatches on the question's model axis. What was missing was the /program's
-- ability to know/ — and that is now @run.routes@, the route table as a run
-- fact, read by @'Workflows.Deciders.judgeIsElsewhere'@ before anything is
-- spent.
--
-- == Why this is a row and not a flag on @wiggum@
--
-- A row is one __shape__ and never one invocation, which is the registry's
-- standing rule. The duet is a different shape: __the partner's observations
-- feed round two inside the term__, which is a bind @wiggum@ does not have, at a
-- price @wiggum@ does not pay. If it were only \"the same program under two
-- @--session@ flags\" the rule would forbid a row and this module would not
-- exist.
--
-- Two further reasons, and the second is decisive.
--
--   * __The churn is asymmetric.__ @wiggum@'s 34 paths and its ceiling of 44 are
--     pinned by equality and by ceiling in @ci\/workflows.sh@, its numbers are
--     quoted in three files, and its blanket refusal is documented in the README,
--     in @doc\/design.md@ and in the guide. A new row moves one number in each of
--     those places and leaves @wiggum@ as the single-pane loop the guide already
--     teaches.
--
--   * __This row cannot re-pin what it borrows.__ @commitFn@ carries
--     @model \"decompose\"@, @resolveFn@ carries @model \"resolve\"@,
--     @cleanupRoundFn@ carries @model \"cleanup-review\"@ and the eleven @fess@
--     stances carry a three-rung split — and every one of those pins is __shared
--     with the row that owns it__. Re-pinning @commitFn@ to @worker@ would
--     re-pin it for the whole commit family. So this row's reach is exactly its
--     own asks, and the rule that falls out is the one the invocation must
--     honour:
--
-- > The default backend is the worker's pane. Everything this row does not pin
-- > itself — every borrowed callee, every tool, every person, every unrouted
-- > receipt — is work, and work belongs in the work's pane. Only the judge and
-- > the partner's seats are routed away.
--
-- That is why @'Workflows.Deciders.judgeIsElsewhere'@ compares the judge's
-- backend against the default and against __every__ pin in 'duetWorkPins' — the
-- worker's and the four ladder rungs the borrowed callees arrive on — and not
-- merely against the work pin. Two invocations are refused by that, and an
-- operator can type either. The inverted split,
-- @--session \<partner\> --route worker=deck:\<work\>@, /looks/ like the split
-- and puts the worker somewhere of its own while quietly leaving the commit
-- decomposition, the conflict resolution and the cleanup review in the pane
-- about to judge them. And a rung routed alongside the judge,
-- @--route partner=deck:\<J\> --route opus=deck:\<J\>@, moves those same three
-- and the audit's @reasoning@ stances into the judge's pane by name, with the
-- judge on neither the default nor @worker@.
--
-- == What is this module's own, and what is borrowed
--
-- Almost everything here is borrowed, and that is the claim the row makes about
-- itself.
--
-- +---------------------------------+----------------------------------------------+
-- | this module's own               | borrowed, holed or called                    |
-- +=================================+==============================================+
-- | 'duetReviewFn' — the four-seat  | the round, the checkpoint and the report     |
-- | in-loop review and its publish  | bodies ("Workflows.Wiggum"'s 'loopRoundFn',  |
-- | act                             | 'loopCheckpointFn', 'loopReportFn' — one pin |
-- |                                 | apart)                                       |
-- +---------------------------------+----------------------------------------------+
-- | 'duetRoster' — the same four    | every rubric in it                           |
-- | lenses, re-pinned               | ("Workflows.Review.Ladder")                  |
-- +---------------------------------+----------------------------------------------+
-- | 'sameSessionNote' and           | the other six endings, and every brief the   |
-- | 'duetProvenance' — the two      | term holes ("Workflows.Wiggum")              |
-- | sentences that name /two/ panes |                                              |
-- +---------------------------------+----------------------------------------------+
-- | the term, which is the shape    | the observation contract, the defect closing |
-- | the row exists for              | and the publishing brief                     |
-- |                                 | ("Workflows.Partner")                        |
-- +---------------------------------+----------------------------------------------+
--
-- == The party pins, in full
--
-- Read against the owner's own invocation — @--session \<work\>@,
-- @--route partner=deck:\<partner\>@:
--
-- +--------------------------------------------+------------------+--------------+
-- | party                                      | pin              | pane         |
-- +============================================+==================+==============+
-- | @model \"round-account\"@ (in the round)   | 'onWorker'       | worker       |
-- +--------------------------------------------+------------------+--------------+
-- | @tool \"wiggum-work\"@,                    | /none — a tool/  | default =    |
-- | @tool \"wiggum-restack\"@                  |                  | worker       |
-- +--------------------------------------------+------------------+--------------+
-- | @model \"independence\"@ (the probe)       | @broad@          | default =    |
-- |                                            |                  | worker       |
-- +--------------------------------------------+------------------+--------------+
-- | the four 'duetRoster' seats                | 'onPartner'      | partner      |
-- +--------------------------------------------+------------------+--------------+
-- | @tool \"observations\"@                    | /none — a tool/  | default =    |
-- |                                            |                  | worker       |
-- +--------------------------------------------+------------------+--------------+
-- | @model \"handoff\"@ (in the checkpoint)    | 'onPartner'      | partner      |
-- +--------------------------------------------+------------------+--------------+
-- | @model \"done-criteria\"@ (the judge)      | 'onPartner'      | partner      |
-- +--------------------------------------------+------------------+--------------+
-- | @model \"continuation\"@ (the amender)     | 'onWorker'       | worker       |
-- +--------------------------------------------+------------------+--------------+
-- | the eleven @fess@ stances                  | their own rungs  | default =    |
-- |                                            |                  | worker       |
-- +--------------------------------------------+------------------+--------------+
-- | every borrowed callee's asks               | its own row's    | default =    |
-- |                                            | rung             | worker       |
-- +--------------------------------------------+------------------+--------------+
--
-- The asymmetry in the checkpoint is deliberate and is argued at
-- 'Workflows.Wiggum.loopCheckpointFn': the audit reads the work in the pane that
-- did it, because evidence-gathering is not judgment, and only the verdict the
-- definition of done turns on is pinned elsewhere.
--
-- == The human in the pane, honestly
--
-- One turn of the deck transport records the current reply's timestamp before
-- sending, sends, and then polls until the session is idle and the timestamp has
-- moved. Reading a pane is invisible to that loop, and a turn the owner takes
-- __between__ two of @wf@'s questions is absorbed exactly, because the stale
-- guard is re-armed before every question. What is /not/ safe is submitting a
-- message while @wf@ is waiting on that pane: the freshness test compares against
-- one stamp taken before the send, so it cannot tell two new replies apart, and
-- @wf@ would read the owner's answer as the answer to its own question — silently.
-- The window is one poll interval. @--poll 250@ shrinks it fourfold for the cost
-- of one subprocess a quarter second, and it is the only mitigation available
-- today that needs no code. @doc\/wiggum-two-sessions.md@ tells the operator this
-- in four sentences, which is the minimum a design that knows about a silent
-- failure owes whoever is holding the run.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Duet
  ( -- * The program
    duetProgram,
    duetDoc,
    duetScript,

    -- * The partner's seats, re-pinned rather than re-written
    duetRoster,

    -- * What the gate compares the judge against
    duetWorkPins,

    -- * The functions
    duetReviewFn,
    duetRoundFn,
    duetCheckpointFn,
    duetReportFn,
    duetTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Audit.Fess
  ( fessReportFn,
    requesting,
    verifiedIndependence,
  )
import Workflows.Git.Commit (commitFn)
import Workflows.Git.Stack
  ( StackRung (Restack),
    resolveFn,
    rungSpecialists,
  )
import Workflows.Partner
  ( cleanupRoundFn,
    defectClosing,
    observationContract,
    observationsDir,
    publishBrief,
    publishedBrief,
  )
import Workflows.Prelude
import Workflows.Review.Ladder
  ( abstractionLens,
    alexeyLens,
    ponytailLens,
    validatedLens,
  )
import Workflows.Wiggum
  ( baselineBrief,
    brokenBaseNote,
    cannotJudgeNote,
    conflictNote,
    continuationBrief,
    currencyBrief,
    doneCriteriaBrief,
    doneNote,
    loopCheckpointFn,
    loopReportFn,
    loopRoundFn,
    markersBrief,
    notIndependentNote,
    orchestration,
    parityClause,
    restacker,
    stillRemainsNote,
    trunkOf,
    verdictTrips,
    wiggumScript,
  )
import Prelude

-- ---------------------------------------------------------------------------
-- The partner's seats
-- ---------------------------------------------------------------------------

-- | The four seats the partner's pane answers, this row's own so that the pins
-- can be 'onPartner' without moving @review-*@'s.
--
-- __Re-pinned rather than re-written, and the mechanism is what makes that
-- safe.__ @'Agentic.Workflow.servedBy'@ replaces the whole served chain, spares
-- included, so @'onPartner' ('Workflows.Panels.lensParty' l)@ is @l@'s addressee
-- pinned to @partner@ with __no alternates__ — which is exactly what this row
-- requires. A ladder here would, on a dead partner pane, move the judgment to
-- whatever answers the next rung, and under the owner's own invocation the next
-- rung resolves through the default, which is the worker's pane. A dead pane must
-- be a dead question. See 'onWorker' for the doctrine.
--
-- So the rubric text is @review-heavy@'s, unchanged and uncopied; only the
-- parties are new. This resolves the design's first open question in the
-- affirmative: a re-pinning helper /is/ strictly better than four transcribed
-- lenses, because @servedBy@ drops the ladder for free.
--
-- __Four seats and not @review-heavy@'s seven__, which is a decision and not an
-- oversight. A review that runs /inside/ a bounded loop is a different economic
-- object from @partner-reviewer@, which runs once beside it: seven seats would
-- put this row's ceiling at 53 and buy three more opinions on a round that is
-- about to be revised anyway. Four is the recommendation the price was pinned
-- at; seven is a decision the owner may take with @wf cost@ in hand, which is
-- what pricing is for.
duetRoster :: Roster
duetRoster =
  [ l {lensParty = onPartner (lensParty l)}
    | l <- [alexeyLens, abstractionLens, validatedLens, ponytailLens]
  ]

-- ---------------------------------------------------------------------------
-- What the gate compares the judge against
-- ---------------------------------------------------------------------------

-- | __Every pin this row's work reaches__: the roster less the judge's own.
--
-- The fourth argument to @'Workflows.Deciders.judgeIsElsewhere'@, and the reason
-- that argument is a list. @'Workflows.Parties.routablePins'@ is every name a
-- @--route@ may claim here; @'partnerPin'@ is the only one of them this row puts
-- a /judgment/ on, and every other is work — @'workerPin'@ by the round's own
-- account, and the four @'Workflows.Parties.ladderPins'@ by the borrowed callees
-- the table above puts on the default. So the set difference is the honest list
-- for /this/ row, and it is a difference and not a hand-written five because a
-- rung added to the ladder must reach this gate without anybody remembering to
-- come here.
--
-- __The difference is right here and wrong in general__, which is why it is
-- stated per row rather than inside the gate: @wiggum@ pins its round account and
-- its judge to the /same/ name, so deleting the judge's pin from its list would
-- delete its work as well. That row passes 'Workflows.Parties.ladderPins' whole,
-- @opus@ included, and refuses accordingly.
--
-- Tier 1 and a CAF: no question, no path, and the same six names
-- @wf list --json@ reports under @pins@ for this row, which is what
-- @ci\/workflows.sh@ checks.
duetWorkPins :: [Text]
duetWorkPins = filter (/= partnerPin) routablePins

-- ---------------------------------------------------------------------------
-- The provenance the endings differ in
-- ---------------------------------------------------------------------------

-- | The arm the two run facts close, before a question is put.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s \"verification comes from a separate
-- evaluator, not from grading your own work\" — the same clause
-- @'Workflows.Wiggum.wiggumProgram'@'s gate enforces, read against a finer fact.
--
-- __What is refused here that @wiggum@ would have accepted, and vice versa.__
-- @wiggum@ refuses every @--session@ run flat, because its judge and its workers
-- are one serving model and no route table can separate them. This row can tell
-- them apart, so the refusal is narrower and sharper: it fires when the judge's
-- backend is the backend of __any__ pin in 'duetWorkPins' — the worker's, or one
-- of the four ladder rungs the borrowed callees arrive on — or when it is the
-- __default__. The second is the inverted split, which is the one an operator
-- will type by accident; the third is a rung routed alongside the judge, which is
-- the one an operator would type deliberately, believing it harmless.
--
-- __Which invocations actually reach these words, honestly.__ Only the /unrouted/
-- one: @--session \<pane\>@ with no @--route@ at all. A refusing invocation that
-- carries a @--route@ is stopped earlier, by @Agentic.Cli@'s check that a routed
-- name is a name the program pins — and the program the run facts built is
-- 'duetRefusalTable''s, whose only ask is a tool, so it pins nothing and every
-- @--route@ is refused by name. The operator is still refused before anything is
-- spent, which is the guarantee, but in the CLI's words and not these. Recorded
-- rather than papered over: the alternative would be to declare model asks in the
-- refusal table so that it pins something, which is a refusal made larger than a
-- refusal in order to improve an error message.
sameSessionNote :: Text
sameSessionNote =
  [wft|
  Outcome: WORK BLOCKED, AND NOTHING WAS STARTED.
  This run puts the judgment in a conversation the work also reaches -- the
  route table and the session policy are quoted below and both came from the
  runner, not from anybody asked -- so the party that would have judged the work
  is a party that will have read it. No question was put: no round ran, no
  review was asked for, no commit was made, no gate was run and no audit was
  requested. Every clause of this loop's definition of done is a claim checked
  by an evaluator that must not be the runner, and there is no such evaluator in
  this table to reach. Report that, quote both facts, and say what would fix it:
  give the WORK the default answerer and route only the judge away -- `--session
  <work-pane> --route partner=deck:<partner-pane>` -- because everything this
  row does not pin itself, every borrowed callee and every tool among them,
  lands on the default and is work. Written the other way round, the judge
  inherits the commit decomposition, the conflict resolution and the cleanup
  review, which is what was just refused.|]

-- | The whole of a refused run's material, which is the pair of facts that
-- refused it.
--
-- @wiggum@'s equivalent quotes one fact; this one quotes two, because either can
-- be the reason. A reporter handed the engine alone could not tell an unrouted
-- deck run from an inverted split, and those are two different mistakes with two
-- different fixes.
sameSessionState :: Text -> Text -> Text
sameSessionState engine routes =
  [wft|
  Nothing ran, so there is no receipt, no commit, no review, no gate output and
  no audit to account for -- and any of those in a report would be invented. The
  whole of this run's material is the two facts the gate read.

  This run's engine and its session policy:

  {engine}

  This run's route table, one line per answerer, as the runner resolved it and
  as the header printed it:

  {table}|]
  where
    table = orNoTable routes

-- | The run's own transport, appended to whichever of the seven endings was
-- reached.
--
-- __Seven endings, seven lines, one statement about the run__ —
-- 'Workflows.Wiggum.wiggumProgram''s arrangement, with the route table added,
-- because for this row the table /is/ the claim. @wiggum@ owes its reader the
-- engine; a duet owes its reader __both panes, named__, since \"the judge is
-- elsewhere\" is a sentence about a mapping and a reader who cannot see the
-- mapping has only the word.
--
-- Free in both folds: an input is a define, so the three facts add no question
-- and no path.
duetProvenance :: Text -> Text -> Text -> Text -> Text
duetProvenance backends engine routes note =
  [wft|
  {note} This run's answerers: {backends}. Its engine: {engine}. Its route
  table, one line per answerer, as the runner resolved it:

  {table}

  All three facts came from the runner and from no party asked below, and the
  last two are what this loop gates on before it spends anything: a judge that
  shares a conversation with the work it is judging is not the separate
  evaluator the definition of done requires. The judge's answerer is held
  against the answerer of EVERY other name in the table and against the
  DEFAULT, because a judge on the default is a judge that read every unpinned
  question, and a judge sharing an answerer with a borrowed callee's own pin has
  read that callee's questions by name. A run whose facts say any of those is
  refused rather than reported on. Name both panes -- the one the work was done
  in and the one the judgment came from -- and let the reader check the ending
  above against them.|]
  where
    table = orNoTable routes

-- | The route table, or the sentence an absent one earns.
--
-- __Tier 1__, and the one place this module decides what an unbound @run.routes@
-- means. The fact is empty exactly when there is /no table/ — @plan@, @cost@ and
-- @--scripted@, which make no run and therefore resolve no answerer — and never
-- because a live run happened not to be given a @--route@: an unrouted live run
-- still has a default, and its one @(default) = …@ line is what makes the gate
-- above decidable. So the empty value is a fact about the verb and this says
-- which, rather than leaving a reader of a rehearsed report to wonder where the
-- table went.
orNoTable :: Text -> Text
orNoTable t
  | T.null (T.strip t) =
      [wft|
      (No route table. This verb resolved no answerer at all -- it is a plan, a
      price or a rehearsal against a canned table -- so there is nothing here to
      read, and the gate above therefore took the shape a run with an unknown
      table would take. A real run always has at least the one `(default) =
      <backend>` line.)|]
  | otherwise = T.strip t

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | The partner's round: four seats over what the work round produced, published
-- as observation files, and the listing handed back.
--
-- __This function is the whole reason the row exists.__ The old guide taught this
-- by hand, across two invocations: run @wiggum@ in one pane, run
-- @partner-reviewer@ in another, and carry the report over as the next
-- invocation's @observations@ input. Here the coupling is a __bind__ — the
-- listing this answers with is round two's standing context — and it is priced.
--
-- Six consultations and __no branch__, deliberately. A
-- @'Agentic.Workflow.tested'@ over the listing would double this program's path
-- count for a fact round two's brief can carry as text (\"these observations, if
-- any\"), and a review inside a loop whose next round reads its output does not
-- need an arm for having found nothing.
--
-- __The contract is @partner-*@'s and is holed rather than restated__: the same
-- publishing brief, the same observation-file contract, the same closing every
-- defect pass in the tree is given. @ideas=off@, because a work loop's review is
-- for defects — the ideation pass is @partner-collaborator@'s and is a different
-- economic object.
duetReviewFn :: Text -> Fn '[ 'CodeText] 'CodeText
duetReviewFn dir =
  function
    "duet.review"
    (takes @"round" Text $ noParams)
    \made -> W.do
      findings <- panelText (zip (lensNames duetRoster) (asksOver duetRoster defectClosing made))

      act (tool "observations") [wf|
          {publishBrief}

          {contract}

          The observations directory:

          {dir}

          The round these findings are about:

          {made}

          The passes:

          {findings}|]

      listing <- ask (mdFilesIn dir) [wf|{publishedBrief}|]
      answer listing
  where
    contract = observationContract False

-- | One round of work, in the worker's pane.
--
-- @'Workflows.Wiggum.wiggumRoundFn'@ with one pin changed: the round's account is
-- put 'onWorker'. Everything it /calls/ — the commit discipline above all — keeps
-- its own row's pin and therefore lands on the default, which this row requires
-- to be the same pane.
duetRoundFn :: Text -> Fn '[ 'CodeText, 'CodeText] 'CodeText
duetRoundFn = loopRoundFn "duet.round" onWorker

-- | The checkpoint, with the handoff in the judge's pane.
--
-- @'Workflows.Wiggum.wiggumCheckpointFn'@ with one pin changed: the handoff is a
-- /judgment about/ the work and belongs where the verdict is. The eleven @fess@
-- stances inside keep their own three rungs and go to the default — see
-- 'Workflows.Wiggum.loopCheckpointFn' for why that asymmetry is right.
duetCheckpointFn :: Text -> Text -> Roster -> Text -> Fn '[ 'CodeText] 'CodeText
duetCheckpointFn = loopCheckpointFn "duet.checkpoint" onPartner

-- | The report every one of the seven endings calls.
--
-- @'Workflows.Wiggum.wiggumReportFn'@'s body under this row's name. The reporter
-- is a tool, so the artefact is written in the pane the work was done in, which
-- is where an operator will look for it.
duetReportFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
duetReportFn = loopReportFn "duet.report"

-- | The table 'duetProgram' hands @'Agentic.Workflow.defining'@.
--
-- Eight entries against @wiggum@'s seven, and the order is the one @defining@
-- checks: a function may call a function the table declared earlier. The four
-- borrowed callees come first because each is called from inside a body below;
-- then the review, the round and the checkpoint; then the report every arm ends
-- in.
duetTable :: Text -> Text -> Roster -> Text -> [SomeFn]
duetTable trunk dir roster provenance =
  [ SomeFn commitFn,
    SomeFn cleanupRoundFn,
    SomeFn fessReportFn,
    SomeFn resolveFn,
    SomeFn (duetReviewFn dir),
    SomeFn (duetRoundFn trunk),
    SomeFn (duetCheckpointFn trunk dir roster provenance),
    SomeFn duetReportFn
  ]

-- | The table the __refused program__ hands @'Agentic.Workflow.defining'@: one
-- entry.
--
-- 'sameSessionNote''s arm is a different program and not a different path, and
-- the only function it can reach is the report. Declaring the other seven would
-- print seven function bodies, and therefore seven prompts, into a program that
-- cannot call one of them — @wf plan@ would show them and @wf cost@ would price
-- a loop this program has already refused to start. A refusal should be the size
-- of a refusal.
duetRefusalTable :: [SomeFn]
duetRefusalTable = [SomeFn duetReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The duet: one free gate over two run facts, a probe, a baseline, two rounds
-- with a four-seat review between them, one currency step, one checkpoint, one
-- bounded verdict, seven endings.
--
-- Four inputs the operator gives, and four the runner gives (@run.backends@,
-- @run.engine@, @run.routes@, @run.sentinel@). @goal@ is the frozen plan and its
-- done-criteria — read-only by construction, since it is an input; @base@ is what
-- the branch is measured against and brought up to date with (@main@ when
-- absent); @observations@ is the directory the partner publishes into and the
-- checkpoint drains (@doc\/observations@ when absent); @parity@ is the reference
-- target, and an absent one is a different last conjunct rather than a missing
-- one.
--
-- __The input is @goal@ and not @plan@__, which is the one place this row's
-- vocabulary departs from @wiggum@'s on purpose: a duet is started from a
-- sentence about what to achieve, typed on the command line beside two pane ids,
-- and @--input-arg goal=…@ is what the owner will type. It reaches the same two
-- places @wiggum@'s @plan@ reaches — the audit's request fold and the judge's
-- frozen criteria — and the judge is still held to it verbatim.
--
-- __The first gate is not a step and costs nothing.__
-- @'Workflows.Deciders.judgeIsElsewhere'@ is taken in ordinary Haskell over
-- @run.engine@ and @run.routes@, before this function has built a
-- 'Agentic.Builder.Program' at all — so the refusing arm is not a path through
-- the loop, it is a different and much smaller program. With the facts unbound,
-- which is every @plan@, every @cost@ and every @--scripted@ run, the answer is
-- the loop: the shape a run with an unknown table takes, and the shape that keeps
-- every check.
--
-- __The refusal arm is therefore not reachable from a canned table__, and that is
-- the shape of the gate rather than a gap in the rehearsal. What reaches it is a
-- command line, and @ci\/workflows.sh@ proves it with one.
--
-- __Where the price comes from, top to bottom.__ One probe and one baseline flag;
-- then one or two rounds, each an act, a called commit discipline, a receipt and
-- an account; the four-seat review, its publish act and its listing, on the
-- two-round arm only; then a currency act, a called resolution doctrine and a
-- free exit code; then the checkpoint's drain, commit, gate, three receipts,
-- eleven stances and report; then a bounded three-way verdict over the handoff;
-- then one report. The one-round arm prices exactly as @wiggum@'s does, because
-- a review whose findings nothing could consume is spend with no consumer.
duetProgram :: Parameterized
duetProgram =
  taking
    ( input "goal"
        :> input "base"
        :> input "observations"
        :> input "parity"
        :> input "run.backends"
        :> input "run.engine"
        :> input "run.routes"
        :> input "run.sentinel"
        :> noInputs
    )
    \goal base obs parity backends engine routes sentinel ->
      -- Tier 1, all of it: the trunk, the directory, the audit roster with the
      -- goal folded in, the last conjunct of the definition of done, the
      -- resolution doctrine, the probe's prompt at this run's own sentinel, and
      -- the provenance every ending carries. Ordinary Haskell, before the
      -- `Program` exists, so none of it costs a question or a path.
      let trunk = trunkOf base
          dir = observationsDir obs
          roster = requesting goal fessRoster
          criteria = doneCriteriaBrief goal (parityClause parity)
          doctrine = rungSpecialists Restack ""
          attestation = independenceAttestation sentinel
          onThisRun = duetProvenance backends engine routes
          provenance = verifiedIndependence engine
       in -- THE FIRST GATE, AND IT ASKS NOBODY. Tier 1 over two run facts, so
          -- the refusing arm is a different *program* and not a path with a
          -- price. `Workflows.Deciders.judgeIsElsewhere` is the whole of its
          -- behaviour, and it is the SAME function `wiggum` gates on: two
          -- spellings of one policy is a policy that drifts, and the drift would
          -- be silent because both spellings would pass their own tests.
          --
          -- `duetWorkPins` and not `workerPin`, which is the difference between
          -- a gate and a gesture. This row's own account is on `worker`, but the
          -- callees it borrows arrive on the LADDER's names, so
          -- `--route opus=deck:<judge>` beside `--route partner=deck:<judge>`
          -- puts the commit decomposition, the conflict resolution, the cleanup
          -- review and the audit's `reasoning` stances in the judge's pane while
          -- the judge sits on neither the default nor `worker`. Compared against
          -- two names that invocation is accepted; compared against the whole
          -- list it is refused, which is what the row claims to do.
          --
          -- A `case` and not an `if`, for `Workflows.Wiggum`'s reason: under
          -- `RebindableSyntax` an `if` here is `Agentic.Workflow.ifThenElse` over
          -- a flag bound in a program, and there is no program yet.
          case judgeIsElsewhere routes engine partnerPin duetWorkPins of
            False -> defining duetRefusalTable W.do
              call_
                duetReportFn
                ( arg (onThisRun sameSessionNote)
                    :> arg (sameSessionState engine routes)
                    :> noArgs
                )
              stop
            True -> defining (duetTable trunk dir roster provenance) W.do
              -- The second precondition, over the residual the two facts cannot
              -- see: an adapter that resumed a conversation behind the client's
              -- back, or a fan-out that leaked one prompt into another.
              probe <- ask (broad (model "independence")) [wf|{attestation}|]
              attested <- tested historyAbsent probe

              if attested
                then W.do
                  ready <- passes nixFlakeCheck [wf|{baselineBrief}|]

                  if ready
                    then W.do
                      -- Round one, in the worker's pane: the round's account is
                      -- `onWorker`, and everything it calls is on the default,
                      -- which this row requires to be the same pane.
                      first <- call (duetRoundFn trunk) (arg goal :> arg orchestration :> noArgs)

                      complete <- tested saysComplete first

                      if complete
                        then W.do
                          -- One round was enough, so no review is bought: the
                          -- checkpoint's own audit is the judgment, and a review
                          -- whose findings nothing could consume is spend with no
                          -- consumer.
                          act restacker [wf|
                              {currencyBrief}

                              {first}|]

                          resolved <- call resolveFn (arg doctrine :> noArgs)
                          clean <- passes gitDiffCheck [wf|{markersBrief}|]

                          if clean
                            then W.do
                              handoff <- call (duetCheckpointFn trunk dir roster provenance) (arg first :> noArgs)

                              judged <-
                                escalating
                                  (onPartner (model "done-criteria"))
                                  criteria
                                  (onWorker (model "continuation"))
                                  continuationBrief
                                  handoff
                                  verdictTrips

                              case judged of
                                SettledOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun doneNote) :> arg final :> noArgs)
                                  stop
                                UnsettledOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun stillRemainsNote) :> arg final :> noArgs)
                                  stop
                                AbandonedOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun cannotJudgeNote) :> arg final :> noArgs)
                                  stop
                            else W.do
                              call_ duetReportFn (arg (onThisRun conflictNote) :> arg resolved :> noArgs)
                              stop
                        else W.do
                          -- THE DUET, IN ONE BIND. The partner reviews round one
                          -- in its own pane, publishes one file per finding, and
                          -- the listing it answers with is round two's standing
                          -- context. This is the interleaving the old guide did by
                          -- hand across two invocations, priced.
                          review <- call (duetReviewFn dir) (arg first :> noArgs)

                          second <- call (duetRoundFn trunk) (arg goal :> arg review :> noArgs)

                          act restacker [wf|
                              {currencyBrief}

                              {second}|]

                          resolved <- call resolveFn (arg doctrine :> noArgs)
                          clean <- passes gitDiffCheck [wf|{markersBrief}|]

                          if clean
                            then W.do
                              handoff <- call (duetCheckpointFn trunk dir roster provenance) (arg second :> noArgs)

                              judged <-
                                escalating
                                  (onPartner (model "done-criteria"))
                                  criteria
                                  (onWorker (model "continuation"))
                                  continuationBrief
                                  handoff
                                  verdictTrips

                              case judged of
                                SettledOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun doneNote) :> arg final :> noArgs)
                                  stop
                                UnsettledOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun stillRemainsNote) :> arg final :> noArgs)
                                  stop
                                AbandonedOn final -> W.do
                                  call_ duetReportFn (arg (onThisRun cannotJudgeNote) :> arg final :> noArgs)
                                  stop
                            else W.do
                              call_ duetReportFn (arg (onThisRun conflictNote) :> arg resolved :> noArgs)
                              stop
                    else W.do
                      call_ duetReportFn (arg (onThisRun brokenBaseNote) :> arg probe :> noArgs)
                      stop
                else W.do
                  call_ duetReportFn (arg (onThisRun notIndependentNote) :> arg probe :> noArgs)
                  stop

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
duetDoc :: Text
duetDoc =
  "wiggum's loop across two panes: the work in one, a four-seat review and the done-criteria judge in the other"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __Five rows of this row's own, and then @wiggum@'s whole table spliced.__ The
-- duet's term holes @wiggum@'s briefs and calls bodies @wiggum@ declares, so
-- @wiggum@'s canned answers are the ones that key them: the round's series and
-- account, the checkpoint's three receipts and its handoff, the amended handoff,
-- and — already spliced inside 'Workflows.Wiggum.wiggumScript' — the commit
-- discipline's, the resolution doctrine's, the cleanup round's and the audit's.
-- Transcribing any of them here would go stale the first time one of those files
-- was reworded, and this module's own rows come first, so an overlap resolves
-- here.
--
-- __What is this row's own is the review__: one reply per partner seat, keyed on
-- its rubric, and the directory read back afterwards. Those five keys are what
-- make the scripted run evidence about 'duetReviewFn' rather than about the loop
-- around it.
--
-- __The scripted run walks the TWO-ROUND arm__, which is the arm the review is
-- on, because @wiggum@'s canned round account ends @WORK REMAINS@ on its own last
-- line and @'Workflows.Deciders.saysComplete'@ reads it. Everything after that
-- rides on the scripted defaults: a flag is @yes@, so the baseline is green and
-- @git diff --check@ is clean; a verdict is @APPROVE@, so the green gate passes
-- and the done-criteria judge settles on its first reading, which is the
-- @SettledOn@ arm — this program's WORK COMPLETE.
--
-- __The refusal arm is not reachable from this table at all__, and that is the
-- gate's shape rather than a gap: it is chosen in Haskell from two run facts, and
-- @--scripted@ binds @run.routes@ to the empty text and @run.engine@ to a value
-- with no session policy in it, so a scripted run always takes the loop. What
-- reaches the refusal is a command line, and @ci\/workflows.sh@ runs one against
-- the deck stub.
duetScript :: [(Text, Text)]
duetScript =
  [(lensBrief l, blockFrom l) | l <- duetRoster]
    <> [(publishedBrief, published)]
    <> wiggumScript
  where
    published =
      observationsDir ""
        <> "/2026-08-20T11:02:41.318Z.md\n"
        <> observationsDir ""
        <> "/2026-08-20T11:02:41.902Z.md"

    blockFrom l =
      [wft|
      ### [MEDIUM] {owns}
      - **File**: src/token.rs#L120-L134
      - **Category**: Test Coverage
      - **Confidence**: 75
      - **Problem**: the rotation path's expired-refresh case is untested.
      - **Impact**: a regression there fails open, and nothing in the suite
        would say so.
      - **Fix**: add a case that presents an expired refresh token and asserts
        the rotation is refused.
      (reported by the {name} pass)|]
      where
        owns = lensOwns l
        name = lensName l
