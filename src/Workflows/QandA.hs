-- |
-- Module      : Workflows.QandA
-- Description : A decision walkthrough whose questions are the owner's binds.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@               | here                                                         |
-- +=========================================+==============================================================+
-- | @commands\/qanda.md@, all three lines   | 'qandaProgram' — the whole row                                |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | \"these decisions\"                     | @'Agentic.Workflow.taking' ('Agentic.Workflow.input'          |
-- |                                         | \"decisions\")@ — 'decisionsOf', tier 1, one decision per     |
-- |                                         | line, given with @--input-file decisions=…@                    |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | \"use the Claude Code question\/answer  | @'Agentic.Workflow.ask' 'Workflows.Parties.owner'@ in         |
-- | interface to walk me through\"          | __binding position__, once per round, inside                  |
-- |                                         | @'Agentic.Workflow.revisingOn'@                               |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | \"presenting the full background and    | 'briefingBrief' before the first question, and 'foldBrief'    |
-- | clarifying each, along with             | after every answer — so the background for decision /n+1/ is   |
-- | implications and trade-offs\"           | produced by the round that settled decision /n/                |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | \"step by step\"                        | the loop's own shape: the running walkthrough is the           |
-- |                                         | candidate, and it is spliced into the next question             |
-- +-----------------------------------------+--------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The rework, which is the input
--
-- @doc\/design.md@ §7.2 row 45 records a disagreement and its ruling: one
-- proposal called this command a rework for having no named input, and the
-- ruling is that \"@taking (input \"decisions\")@ /is/ the rework\". That is this
-- module's first three lines. The corpus's @qanda.md@ is a paragraph whose
-- subject — \"these decisions\" — has no referent except whatever was said in the
-- conversation before it, so the command cannot be planned, cannot be priced, and
-- cannot be run twice over the same agenda. Here the agenda is a program input,
-- @wf plan qanda --input-file decisions=./agenda.txt@ prints it, and
-- 'decisionsOf' reads it in ordinary Haskell before the
-- 'Agentic.Builder.Program' exists — __tier 1__, zero questions and zero paths.
--
-- == The leveling-up, item by item
--
--   1. __The human is a binder.__ \"Walk me through these decisions\" is, in the
--      corpus, an instruction to use an interface. Here the owner's answer is the
--      loop's __verdict__ and the language reads its three tags three ways:
--      approval settles the walkthrough, an objection is his answers and is the
--      only thing the next round is told, and an empty answer abandons the loop.
--      That third tag is the one a Markdown command cannot have: a person who
--      walks away from a decision review has not consented to its conclusions,
--      and an unattended run must be able to say so.
--
--   2. __\"Each answer live for the questions after it\" is the candidate.__ The
--      loop's carrier is the running walkthrough document, and it is spliced into
--      the next question — so a later decision is presented in the light of the
--      earlier ones by construction rather than by a model remembering to. See
--      \"One narrowing\" below for what this is instead of.
--
--   3. __The agenda is derived and appears in every round.__ 'agendaOf' is built
--      from the very list 'decisionsOf' produced, and it is spliced into the
--      briefing, into every question the owner is asked, and into the fold — so a
--      decision that is on the agenda cannot quietly drop out of the walkthrough,
--      and the owner can see at every round what is left. Fourteen files in the
--      corpus ask a model not to lose an item and none of them can name the items.
--
--   4. __The record is audited by somebody who was not in the room.__ A
--      walkthrough written by the party that conducted it is a party grading its
--      own transcript. 'supportBrief' is one question on a different serving model
--      whose whole job is to find a line of the record that attributes a decision
--      to the owner which his own words do not support, and to mark it
--      @UNSUPPORTED:@. Its answer goes into the report beside the record, and the
--      report is told that an unsupported line is not a decision.
--
-- == One narrowing, recorded rather than absorbed
--
-- __\"One @ask@ per decision\" is not writable, and rounds are what is.__ §7.2 row
-- 45 asks for \"one @ask (person \"operator\")@ per decision, in binding
-- position\". The decision count is a /run-time/ value — it comes off an input —
-- and every bind in a @W.do@ block extends the block's scope index, so a
-- variable-length chain of binds is not a Haskell program: the type of the block
-- would depend on the length of a list nobody has yet. (A fan-out over the list
-- /is/ writable — @'Agentic.Workflow.panelText'@ takes one — and it is the wrong
-- shape here, because a panel's members are independent by construction and this
-- row's whole content is that answer /n/ is live for question /n+1/.)
--
-- So what is built is @skills\/wiggum@'s shape, which @doc\/design.md@ §7.4 row 1
-- rules for exactly this reason: __K rounds__, each carrying the whole agenda and
-- the whole walkthrough so far. The owner is in binding position once per round
-- rather than once per decision, the agenda he is looking at names every decision,
-- and he settles the loop when they are all made. What is lost is the guarantee
-- that each decision got its own turn; what is gained is a bound — @wf cost
-- qanda@ is a finite number over any agenda, where one-ask-per-decision would
-- price differently for every file.
--
-- __And the person is 'Workflows.Parties.owner', not @person \"operator\"@.__ The
-- design cell writes the latter; "Workflows.Parties" rules that there is exactly
-- one person any workflow in this tree may ask, and a second person addressee
-- would be a second pin nobody sets and a second thing @--scripted@ answers
-- @yes@. One person, one name.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.QandA
  ( -- * The program
    qandaProgram,
    qandaDoc,
    qandaScript,

    -- * The tier-1 readings of an invocation
    decisionsOf,
    agendaOf,

    -- * The rubrics, transplanted
    briefingBrief,
    walkBrief,
    foldBrief,
    supportBrief,

    -- * The function
    qandaRecordFn,
    qandaTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The agenda, one decision per line.
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and zero paths, and it is what @doc\/design.md@ §7.2 row 45 calls the
-- rework. @'Workflows.Deciders.pathsOf'@ does the reading — lines, stripped,
-- blanks dropped — because that is the same shape @--input-file@ hands every
-- list-valued input in this tree.
--
-- __Total on the empty string, and that is house rule WR-1.__ @wf plan@ and
-- @wf cost@ bind @\"\"@ for an input nobody gave, so an empty agenda must mean
-- /the default agenda/ and never /no decisions/: this row's derived briefs would
-- otherwise ask the owner to walk through nothing, and the one-line default below
-- says exactly what a run with no agenda is for.
decisionsOf :: Text -> [Text]
decisionsOf t = case pathsOf t of
  [] -> ["(no decisions were named for this run -- the first thing to settle is what has to be decided)"]
  ds -> ds

-- | The agenda as the numbered list every prompt in this row holes.
--
-- Derived from the same list the walkthrough is built from, so a decision on the
-- agenda arrives in the briefing, in the owner's question and in the fold __by
-- being on the agenda__. That is 'Workflows.Panels.memberNote''s argument applied
-- to a sequence instead of a fan-out.
agendaOf :: [Text] -> Text
agendaOf = numbered

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | What the opening briefing asks for.
--
-- /Source:/ @commands\/qanda.md@'s \"presenting the full background and
-- clarifying each, along with implications and trade-offs\", which in the corpus
-- is a clause and here is the first turn's whole contract. It runs __before__ the
-- owner is asked anything, so the first question he sees already has the material
-- he needs to answer it.
briefingBrief :: Text
briefingBrief =
  wfText
    [wf|
    Prepare a decision walkthrough. You are not deciding anything and you are not
    recommending a decision as though it were made: you are laying out what
    somebody needs in order to decide.

    Write it as a document, in the agenda's own order, one section per decision:

    - the decision, restated in one sentence as a choice between named options;
    - the background: what in this project makes this a question at all, and what
      is already true that constrains it;
    - the options, and for each one what it buys and what it costs -- concretely,
      in terms of this project, not in general;
    - the implications that outlive the decision: what becomes hard to change
      afterwards, and what stays cheap;
    - what would have to be true for each option to be the right one. This is the
      part that makes a walkthrough useful, because it turns a preference into a
      question of fact;
    - what you do not know, and what would settle it.

    Then, at the end, one line naming which decision should be settled FIRST and
    why -- usually the one the others depend on.

    Two things you must not do. Do not collapse a real choice into a
    recommendation and present the rest as detail: if one option is obviously
    right, say so in one line and still write the others down. And do not invent
    constraints -- a background claim you cannot support from the context you were
    given is a question, and it belongs in what you do not know.|]

-- | What the owner is asked, once per round, in binding position.
--
-- /Source:/ @commands\/qanda.md@'s \"walk me through these decisions, step by
-- step\", read as the contract it implies: the owner reads the walkthrough as it
-- stands, decides what he can, and says so.
--
-- __The three tags are spelled out to him__, because a human answering a machine
-- should be told what each of his answers does — and because a verdict decodes as
-- declined only when the answer is __empty__
-- ('Workflows.Escalation.endingSpec'), so an explanation of why he cannot decide
-- is an objection and buys a round that cannot help.
walkBrief :: Text
walkBrief =
  wfText
    [wf|
    Here is the walkthrough as it stands. Decisions you have already made are
    recorded in it, in your own words; the next open decision is presented with
    its background, its options and its trade-offs.

    Read it and answer with exactly one of these, on its own last line:

    - APPROVE -- every decision on the agenda is settled and the walkthrough
      records them correctly. Nothing further is asked and the record is written.
      Write that word alone: anything else on the line is read as a correction.
    - OBJECTION: <one line> -- your decisions, and your questions. Put everything
      in that one line: which option you are taking and why, what you want
      reconsidered, what you need clarified before you can decide the rest. That
      line is the ONLY thing the next round is told, so a decision left out of it
      is a decision the next round does not know you made.

    If, and only if, you do not want to continue this walkthrough at all -- these
    are not your decisions to make, the framing is wrong, something outside this
    run has to change first -- reply with NOTHING AT ALL: an empty answer. An
    empty answer ends the walkthrough with the decisions recorded as UNSETTLED and
    nothing presented as agreed. An explanation of why you are stopping is an
    objection, and buys a round that cannot help.|]

-- | What the folding turn is told after each of the owner's answers.
--
-- This is where \"step by step\" lives. The fold produces the next version of the
-- walkthrough: the decisions the owner has now made, in his words, plus the next
-- open one presented in full — so the background for decision /n+1/ is written by
-- the round that settled decision /n/, and is therefore written in the light of it.
foldBrief :: Text
foldBrief =
  wfText
    [wf|
    The owner read the walkthrough and answered. Produce the next version of the
    walkthrough document and nothing else -- no commentary about what changed.

    Three parts, in this order:

    1. DECIDED. One entry per decision he has now settled, each recording: the
       decision, the option he took, and his own reason in his own words. Do not
       improve his reasoning and do not add a justification he did not give. If he
       decided something you think is wrong, record it as decided and put your
       concern in part 3.

    2. NEXT. The next open decision from the agenda, presented in full: the choice
       as a choice between named options, the options with what each buys and
       costs, and the implications -- rewritten in the light of what he has now
       decided, because an earlier decision usually removes options from a later
       one. If his answer changed what a later decision even is, say so here.

    3. STILL OPEN, AND WHAT I OWE YOU. The remaining agenda items by name; any
       question of his you could not answer, and what would answer it; and any
       consequence of a decision he has taken that he may not have intended --
       stated once, plainly, without relitigating it.

    Two rules. Every agenda item appears somewhere in parts 1, 2 or 3: an item in
    none of them has been lost. And nothing is recorded as DECIDED that he did not
    say -- an inference from what he said is not a decision, it is part 3.|]

-- | What the support audit asks, on a serving model that was not in the room.
--
-- The one question in this row that exists because of a failure mode the corpus
-- cannot see: the walkthrough is written by the party that conducted it, so the
-- record of what the owner decided and the reasoning about what he should decide
-- come from the same place. This asks somebody else.
supportBrief :: Text
supportBrief =
  wfText
    [wf|
    You are auditing a decision record, not the decisions. You were not in this
    conversation and you have no view on what the right choices are.

    One question: does every line the record presents as DECIDED correspond to
    something the owner actually said?

    Go line by line through the DECIDED section. For each entry, find the owner's
    own words in the walkthrough that settle it. Then:

    - for each entry you cannot support, write a line beginning exactly

        UNSUPPORTED: <the entry, and what is missing>

      -- an option recorded as chosen where he only asked a question about it, a
      reason attributed to him that reads like the author's, a decision that
      appears in DECIDED without ever having been presented to him;
    - for each entry that is his, say nothing. Silence is the pass.

    Then one closing line: how many DECIDED entries there are, and how many you
    could support. If all of them, say so plainly.

    Do not audit the reasoning, the options, or whether a decision is wise. A
    decision you think is a mistake but which he clearly made is supported.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the owner approved the walkthrough.
decidedNote :: Text
decidedNote =
  "Outcome: DECIDED. The owner approved the walkthrough, which means every \
  \decision on the agenda is settled and the record of it is his. Report the \
  \record as the decision log for this agenda: one entry per decision, the option \
  \taken, and his own reason. Then the consequences the walkthrough named that \
  \nobody has acted on yet, which are the next run's work and not this one's."

-- | The arm where the rounds ran out.
openNote :: Text
openNote =
  "Outcome: NOT SETTLED. The walkthrough's rounds ran out with the owner still \
  \answering, so the document below is the one the last round produced and his \
  \final answer objected to -- no round was spent folding in that last answer. Do \
  \NOT present the agenda as decided. Report, in this order: the decisions the \
  \record does support, his outstanding answer verbatim, and the agenda items \
  \still open. The next run is given this record and the same agenda."

-- | The arm where the owner walked away.
withdrawnNote :: Text
withdrawnNote =
  "Outcome: WITHDRAWN -- NOTHING IS AGREED. The owner answered the walkthrough \
  \with nothing, which in this run means: do not treat any of this as decided. \
  \Every agenda item is UNSETTLED, including ones an earlier round recorded as \
  \decided, because the run that would have confirmed them is the run he stopped. \
  \Report the agenda, the background that was prepared for it, and nothing as \
  \agreed. This arm exists so that an unattended run cannot read silence as \
  \consent."

-- ---------------------------------------------------------------------------
-- The function
-- ---------------------------------------------------------------------------

-- | What the record is written through.
qandaReportBrief :: Text
qandaReportBrief =
  wfText
    [wf|
    Write the decision record for a walkthrough run. It is read by the owner
    later, and by whoever implements what was decided.

    Open with the provenance line you were given, verbatim, on its own line. It is
    the run's own account of how the walkthrough ended and it is not yours to
    soften: if it says nothing is agreed, do not write a decision log.

    Then, from the walkthrough and the audit below and nothing else:

    - the decisions, one entry each: the decision, the option taken, and the
      owner's own reason in his own words;
    - every agenda item that is still open, by name, and what it is waiting on;
    - the consequences the walkthrough named that nobody has acted on -- these are
      work, and they are the reason a decision record is worth writing down;
    - the audit's findings, verbatim. Any line the audit marked UNSUPPORTED names
      an entry that is NOT a decision: move it out of the decisions and into a
      section headed "presented as decided, and not supported by anything the
      owner said". Do not quietly drop it and do not quietly keep it.

    One thing you must not write. Do not add a decision, a reason or a
    qualification of your own. This document's whole value is that a reader can
    trust that every line in it came from the owner; one improved sentence costs
    that for the whole file.|]

-- | One audit, one act, three provenance lines.
--
-- Two parameters and two statements: the audit reads the walkthrough, and the
-- report is written over both. It is a 'Agentic.Workflow.Fn' rather than three
-- copies for "Workflows.Report"'s reason — a call is priced at the callee's own
-- body with the arguments ignored, so the three arms share this body at no charge
-- and cannot drift in what they claim was decided.
--
-- __The audit is inside the function and not before the loop__, deliberately:
-- there is nothing to audit until the walkthrough has stopped moving, and the
-- three arms stop it for three different reasons. Putting it here means all three
-- are audited, including the two that agreed nothing — where the interesting
-- question is precisely whether the record claims otherwise.
qandaRecordFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
qandaRecordFn =
  function
    "qanda.record"
    ( takes @"provenance" Text
        . takes @"walkthrough" Text
        $ noParams
    )
    \provenance walkthrough -> W.do
      support <- ask (lateral (model "qanda-support")) [wf|
          {auditing}

          The walkthrough:

          {walkthrough}|]

      act reporter [wf|
          {recording}

          Provenance:

          {provenance}

          The walkthrough:

          {walkthrough}

          The support audit:

          {support}

          Write the record, then reply DONE.|]
      done
  where
    auditing = supportBrief
    recording = qandaReportBrief

-- | The table 'qandaProgram' hands @'Agentic.Workflow.defining'@.
qandaTable :: [SomeFn]
qandaTable = [SomeFn qandaRecordFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One briefing, then the owner in binding position once per round.
--
-- Two inputs. @decisions@ is the agenda, one decision per line — the rework §7.2
-- row 45 asks for, and the reason to reach for @--input-file decisions=…@;
-- @context@ is whatever the decisions are about: a design document, a paste of
-- the situation, a directory description.
--
-- The shape, top to bottom: prepare the full background for every decision on the
-- agenda; then walk it, one round at a time, with the running walkthrough as the
-- loop's carrier and the owner's answer as its verdict. Three endings, three
-- provenance lines, __one__ 'qandaRecordFn'.
--
-- __The loop is written out rather than through
-- 'Workflows.Escalation.escalating'__, and for one reason: that function's judge
-- is typed @'Agentic.Workflow.Party' \''Agentic.Workflow.IsModel'@, and the judge
-- here is a person. The three arms are the same three, and the generalisation is
-- one word in "Workflows.Escalation"'s signature — reported rather than made,
-- because that module is the foundation's and this is the second row to want it
-- ("Workflows.Expense" is the first).
qandaProgram :: Parameterized
qandaProgram =
  taking (input "decisions" :> input "context" :> noInputs) \decisionsArg context ->
    -- Tier 1: the agenda, read before the program exists, so `wf plan` prints the
    -- exact list every round will carry.
    let roster = decisionsOf decisionsArg
        agenda = agendaOf roster
     in defining qandaTable W.do
          background <- ask (reasoning (model "qanda-background")) [wf|
              {briefing}

              The decisions to walk through, in this order:

              {agenda}

              What they are about:

              {context}|]

          walked <- revisingOn background (atMost 2) \candidate -> W.do
            -- The owner, in binding position. His answer IS the verdict, and the
            -- language reads its three tags three ways.
            said <- ask owner [wf|
                {walk}

                The agenda, in full:

                {agenda}

                {candidate}|]

            amend
              ( ask (reasoning (model "qanda-fold")) [wf|
                  {folding}

                  The agenda, in full:

                  {agenda}

                  The walkthrough as it stands:

                  {candidate}

                  What the owner said:

                  {said}|]
              )

          case walked of
            SettledOn record -> W.do
              call_ qandaRecordFn (arg decidedNote :> arg record :> noArgs)
              stop
            UnsettledOn record -> W.do
              call_ qandaRecordFn (arg openNote :> arg record :> noArgs)
              stop
            AbandonedOn record -> W.do
              call_ qandaRecordFn (arg withdrawnNote :> arg record :> noArgs)
              stop
  where
    briefing = briefingBrief
    walk = walkBrief
    folding = foldBrief

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
qandaDoc :: Text
qandaDoc =
  "qanda.md: an agenda from --input-file, the full background before the first question, and the owner's answer as the loop's verdict"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the briefing's question opens with 'briefingBrief', the
-- owner's with 'walkBrief', the fold's with 'foldBrief' and the audit's with
-- 'supportBrief'.
--
-- __The owner's row is the load-bearing one.__ A verdict question's scripted
-- default is @APPROVE@, so the run would settle on the first round with or without
-- this table; the row is written with the approving answer anyway, for
-- @'Workflows.Comments.commentsScript'@'s reason — a table that relies on a default
-- cannot be edited into the other two arms in one line. An @OBJECTION:@ here
-- reaches @UnsettledOn@ after the rounds run out and an empty answer reaches
-- @AbandonedOn@, and all three exit 0.
--
-- __It is the bare word, and that is load-bearing.__ @Agentic.Text.approvesB@
-- approves only a reply that /is/ an approve word and nothing else, so a row
-- answering @\"take the second option. APPROVE\"@ would be read as an objection
-- carrying that sentence — which is exactly the shape a real owner's answer takes
-- and is why 'walkBrief' tells him the word stands alone.
--
-- The fold's row is answered with a walkthrough rather than with a sentence,
-- because on the objecting edit above it is what the owner's next question carries
-- — a scripted run that reads a stub there is rehearsing a shape it will never see.
qandaScript :: [(Text, Text)]
qandaScript =
  [ (briefingBrief, briefed),
    (walkBrief, "APPROVE"),
    (foldBrief, folded),
    (supportBrief, "3 DECIDED entries, 3 supported.")
  ]
  where
    briefed =
      "## 1. Whether the ingest queue is shared or per-tenant\n\
      \Background: today one queue serves everybody, and one slow tenant delays \
      \the rest.\n\
      \Options: (a) a queue per tenant -- isolation, and N times the connection \
      \and monitoring surface; (b) one queue with per-tenant rate limits -- one \
      \thing to operate, and a slow tenant still adds latency.\n\
      \Implications: (a) is hard to undo once tenants depend on their own \
      \retention; (b) stays cheap to change.\n\
      \For (a) to be right, tenant isolation has to be a contractual commitment \
      \rather than a preference.\n\
      \Not known: whether any tenant contract mentions isolation.\n\
      \\n\
      \Settle this one first: the retention and the alerting decisions both \
      \depend on it."

    folded =
      "## DECIDED\n\
      \- Ingest queue: one queue with per-tenant rate limits. \"Take the second \
      \option -- one queue, and accept the latency.\"\n\
      \\n\
      \## NEXT\n\
      \Retention. With one shared queue the per-tenant retention window is a \
      \property of the consumer rather than of the queue, which removes the \
      \\"different retention per tenant\" option entirely.\n\
      \\n\
      \## STILL OPEN, AND WHAT I OWE YOU\n\
      \- Alerting thresholds.\n\
      \- I could not establish whether a tenant contract commits to isolation; the \
      \signed agreements would settle it.\n\
      \- Consequence you may not have intended: with one queue, a per-tenant \
      \backlog alert has to be derived from consumer lag rather than queue depth."
