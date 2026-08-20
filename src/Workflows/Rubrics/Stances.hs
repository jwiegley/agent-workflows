-- |
-- Module      : Workflows.Rubrics.Stances
-- Description : The confer stances — three positions, one anti-sycophancy rule.
--
-- __Provenance.__ @agent-cat\/doc\/research\/pal-subsumption\/confer-design.md@
-- §1.1, §1.3, §1.4, §1.5 and §5, which is the specification of record for the
-- @confer@ family; @agent-cat\/doc\/research\/pal-vs-agent-cat.md@, whose
-- correspondence table is where \"PAL's @challenge@ tool is one rubric define\"
-- is argued; and @~\/src\/nix\/config\/ai\/commands\/gravity.md@, the owner's
-- own one-paragraph contrarian prompt, which @doc\/design.md@ §7 row 23 marks
-- __K__ (honestly Markdown) with its text harvested here — as the @against@
-- seat's stance and as the challenge rubric @second-opinion@ stands under.
--
-- Nothing in @~\/src\/nix\/config\/ai@ is modified by this module.
--
-- == Why these are rubrics and not a program
--
-- @doc\/design.md@ §8.1 rules where confer's pieces live: the program and the
-- roster are "Workflows.Confer", and the prose is here, because stances are
-- rubrics and rubrics live in @Rubrics\/@. The pattern is
-- "Workflows.Rubrics.Fess", which is ten stances in exactly this shape, and the
-- point of the split is that a stance can be reworded without the program being
-- reread.
--
-- == The ordering rule, which is load-bearing and looks cosmetic
--
-- Every seat stands under 'challengeRubric', and stands under it __second__.
-- A scripted table matches the first entry whose key is a prefix of the
-- rendered prompt, and this tree's rule is that a key is a prefix __by
-- construction__ because each member's prompt opens with its own
-- @'Workflows.Panels.lensBrief'@. Put the shared rubric first and all three
-- seats open with the same bytes: one canned answer would serve all three, and
-- @wf run confer --scripted@ would silently stop being a test of a fan-out. The
-- stance leads; the shared rule follows it. 'underChallenge' is that order, in
-- one place, so no seat can be assembled the other way round.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Workflows.Rubrics.Stances
  ( -- * The rule every party stands under
    challengeRubric,
    underChallenge,

    -- * The three positions
    forStance,
    skepticStance,
    neutralStance,

    -- * What a party is told about the shape of its answer
    stanceClosing,
    opinionClosing,

    -- * The subject the whole roster reads
    conferSubject,

    -- * The derived briefs
    conferSynthesis,
    conferProvenance,

    -- * The artefact
    conferWriteBrief,
    conferBareWriteBrief,
    secondOpinionWriteBrief,
  )
where

import Agentic.Workflow (wft)
import Data.Text (Text)
import Workflows.Panels (Roster, rosterTable)
import Workflows.Prose (tshow)

-- ---------------------------------------------------------------------------
-- The rule every party stands under
-- ---------------------------------------------------------------------------

-- | PAL's @challenge@ tool, which is a wrapper prompt and not a workflow, as
-- the one define every party in this family stands under.
--
-- /Source:/ @pal-vs-agent-cat.md@ — \"@challenge@ → one rubric define. A
-- @[wf|…|]@ constant of a dozen words. The transplant is so small it is barely
-- a line item.\" — composed with
-- @~\/src\/nix\/config\/ai\/commands\/gravity.md@, which is four sentences and
-- is carried here __compressed and not whole__. What the rubric below rewords
-- is the file's second half — \"Attack the weakest points in my reasoning,
-- challenge my assumptions, and expose what I might be missing. Be tough,
-- specific, and do not sugarcoat your feedback.\" — moved from the first person
-- to the second, with \"your feedback\" dropped from the end. The file's first
-- two sentences, \"Act like gravity for my idea. Your job is to pull it back to
-- reality.\", are its framing rather than its instruction: the persona is one
-- this family does not use, and \"pull it back to reality\" lands on
-- 'skepticStance' instead, quoted in that function's haddock as the owner's own
-- words for the trace-it-to-a-mechanism rule.
--
-- The corpus file stays as Markdown for interactive use (@doc\/design.md@ §7
-- row 23, __K__); what is transplanted is that half of it, once, where the
-- family's three programs read it — @conferOver@, @conferBareOver@ and
-- @secondOpinionOver@ in "Workflows.Confer", which is every row.
challengeRubric :: Text
challengeRubric =
  [wft|
  Evaluate what is put to you on its merits. Do not agree because the
  question was asked confidently, because agreeing is shorter, or because the
  person asking appears to want a particular answer. Attack the weakest point
  in the reasoning, challenge the assumptions, and name what is missing.

  Where you find the case sound, say which part carries the weight; where you
  do not, say where it fails and what the failure costs. Be tough, be
  specific, and do not sugarcoat. Deference is not analysis, and a reader who
  wanted agreement did not need to ask three parties.|]

-- | Every party stands under 'challengeRubric', and stands under it
-- __second__.
--
-- The order is the module header's argument, and this is the only function that
-- states it: a seat built any other way is a seat whose scripted key collides
-- with its siblings'.
underChallenge :: Text -> Text
underChallenge stance =
  [wft|
  {stance}

  {challengeRubric}|]

-- ---------------------------------------------------------------------------
-- The three positions
-- ---------------------------------------------------------------------------

-- | The @for@ seat.
--
-- /Source:/ @confer-design.md@ §1.1, verbatim.
forStance :: Text
forStance =
  [wft|
  You are arguing FOR the decision below. Your job is the strongest honest
  case that it is right: what it buys, what it unblocks, and what not doing it
  costs. Two other parties argue the other side and the middle, so do not
  hedge and do not write their blocks for them.

  Argue from what the decision and its context actually say. An advantage you
  cannot point at is an advantage you are inventing, and a case built on one
  is worse than no case: it spends the reader's trust on the parts that were
  true.|]

-- | The @against@ seat.
--
-- /Source:/ @confer-design.md@ §1.1, which is deliberately
-- @agent-cat\/haskell\/example\/Example\/Isaac.hs:238@'s voice: \"a risk that
-- you did not trace to a concrete mechanism is not a risk -- it is anxiety\" is
-- the best sentence in that file, and a confer roster is where it belongs a
-- second time. @commands\/gravity.md@'s \"pull it back to reality\" is the same
-- instruction in the owner's own words, and reaches this seat through
-- 'challengeRubric'.
skepticStance :: Text
skepticStance =
  [wft|
  You are arguing AGAINST the decision below. Your job is what goes wrong:
  what it breaks, what it commits the tree to that a later change would have
  to undo, and what it costs that the proposal does not price.

  Trace every objection to a concrete mechanism -- the caller, the format, the
  file, the version. An objection you cannot trace is not an objection, it is
  unease, and the synthesis will rightly set it aside. Three real objections
  beat ten plausible ones.|]

-- | The @neutral@ seat.
--
-- /Source:/ @confer-design.md@ §1.1, verbatim. It is the seat a two-sided
-- argument does not have, and @debate@ is the row that deliberately drops it.
neutralStance :: Text
neutralStance =
  [wft|
  You are the neutral party. The other two argue the sides; nobody has asked
  them what is actually true. Sort the claims: which are settled by the
  context below, which are judgement calls where reasonable people differ, and
  which are simply unknowable from what is here.

  Name the one fact that would decide this if somebody went and got it. If the
  decision is underspecified, say what it is missing rather than choosing on
  the asker's behalf.|]

-- ---------------------------------------------------------------------------
-- What a party is told about the shape of its answer
-- ---------------------------------------------------------------------------

-- | The closing line every seat of a confer is given.
--
-- /Source:/ @confer-design.md@ §1.1, verbatim.
--
-- Not a verdict spec: a stance is prose, and the runner already appends
-- @answerSpec CodeText@ — \"Reply with the text itself and nothing else\" — to
-- every text question. What this adds is the one thing the code cannot say:
-- your answer is __one block of a document__, so do not write the other blocks
-- and do not address the reader of any block but your own.
--
-- It is a parameter of the fan-out and not a constant of it, which is
-- @confer-design.md@ §1.7's R2: @'Workflows.Panels.documentPanel'@ hard-codes
-- \"Report your findings and nothing else\", which is right for a review roster
-- and wrong for a stance roster — a party arguing a case is not reporting
-- findings.
stanceClosing :: Text
stanceClosing =
  [wft|
  Write your case as prose, at most twelve lines, and do not summarise the
  decision back: the reader has it above your block. Your answer is one block
  of a document whose other blocks are the other parties'. Do not write
  theirs, do not address the reader of the whole, and do not pre-empt the
  synthesis -- it is a later question, put to somebody who has read all of
  you.|]

-- | The closing line the single party of a @second-opinion@ is given.
--
-- /Source:/ @confer-design.md@ §5.3, verbatim. There is no document here and no
-- sibling to stay out of the way of, so what the closing asks for is the shape
-- of an opinion rather than the shape of a block.
opinionClosing :: Text
opinionClosing =
  "Say whether the claim holds, where it is weakest, and what would change \
  \your answer. At most ten lines."

-- ---------------------------------------------------------------------------
-- The subject
-- ---------------------------------------------------------------------------

-- | The decision and its context, as one define the whole roster reads.
--
-- /Source:/ @confer-design.md@ §1.1, verbatim.
--
-- Two inputs and one subject, because a fan-out member takes one artefact. The
-- context may be empty and the words say what empty means, so that an operator
-- who has nothing to attach does not have to invent a placeholder and a party
-- that receives nothing does not have to guess whether something was lost.
conferSubject :: Text -> Text -> Text
conferSubject decision context =
  [wft|
  The decision:

  {decision}

  The context. This may be empty, and empty means the decision stands on its
  own words -- it does not mean a document failed to arrive:

  {context}|]

-- ---------------------------------------------------------------------------
-- The derived briefs
-- ---------------------------------------------------------------------------

-- | The brief for the question that reads every block, derived from the roster
-- it will refuse on.
--
-- /Source:/ @confer-design.md@ §1.3.
--
-- The first half is @'Workflows.Panels.refusingSynthesis'@' argument, unchanged
-- and unarguable: an unauthenticated backend returns nothing, and nothing
-- folded into a recommendation reads exactly like agreement. A confer is the
-- shape where that failure is most expensive, because the whole claim of the
-- artefact is that N parties were consulted.
--
-- The second half is confer's own, and is where it differs from a review
-- synthesis: a review deduplicates and ranks findings; a confer locates
-- __disagreement__ and says what turns on it. That is why this is its own
-- binding rather than a splice of @refusingSynthesis@ — the two halves are one
-- brief, and the shared paragraph is stated twice on purpose until somebody
-- wants @accountForBlocks@ (@confer-design.md@ §1.7's optional third
-- requirement, which is not taken here).
conferSynthesis :: Roster -> Text
conferSynthesis r =
  [wft|
  Below is the decision, its context, and a document of {count} blocks, one
  per party, each fenced under its own name. The parties and what each was
  asked to own:

  {table}

  First, account for the blocks. If any named party's block is missing or
  empty, reply with exactly

    INCOMPLETE: <the names of the missing blocks>

  and nothing else. Do not synthesise what did arrive: a partial roster folded
  into a recommendation is indistinguishable from a unanimous one, and that is
  the one mistake this step exists to prevent.

  Otherwise:

  - Say where the parties actually disagree -- not where they used different
    words for one thing. Quote the sentence from each block that carries the
    disagreement.
  - For each disagreement, say what turns on it: what would follow if each
    side were right.
  - Then the recommendation, in one paragraph, and the condition that would
    change it.

  Attribute every load-bearing claim to the block it came from. You are the
  only party that has read all of them, and a claim you cannot attribute is a
  claim you introduced.|]
  where
    count = tshow (length r)
    table = rosterTable r

-- | What the artefact says about how the confer was run.
--
-- /Source:/ @confer-design.md@ §1.4, and behind it
-- @'Workflows.Rubrics.Discipline.unverifiedIndependence'@, whose whole shape is:
-- a report that did not establish something does not get to imply it.
--
-- A confer's implied claim is that N parties were consulted. An unrouted run
-- binds every addressee to one backend, so a three-block document produced by
-- three sessions of one model is exactly as honest as it says it is and no
-- more; and under @--engine deck@ the three seats are not even three sessions.
-- What the __program__ asked for is the seats below; what the __run__ did is
-- the run's header, and the two are different statements. This says so.
--
-- __Derived from the roster and from the run's own two facts.__ The roster is
-- what makes it a function of the /program/: a routed run moves neither the
-- roster nor this paragraph, because a route names a serving __model__ and the
-- roster's pins are already those keys. What a run changes — how many backends
-- it reached, and which engine and session policy it ran under — used to live
-- only in the header, which is terminal output no prompt sees; the runner now
-- binds both as inputs, and they arrive here as the second and third arguments.
--
-- __One deviation from §1.4, and it is a repair.__ The design's table is
-- @bullets [(lensName l, lensOwns l) | l <- r]@ — the seats and what each owns
-- — and its next sentence reads \"Those are the models the program pins\", which
-- names something the table does not carry. It cannot carry it:
-- "Agentic.Workflow" exports no accessor for a party's pin, so a roster cannot
-- be printed as its serving models by any caller. The sentence is corrected to
-- name the seats, and the pins are described rather than listed.
--
-- __Two conditionals, and the runner now answers both.__ The paragraph turns
-- twice on how the run was made — on how many backends answered, and on whether
-- the seats shared a session — and until the runner supplied those two facts
-- there was nothing to hole in their place: the header is terminal output the
-- runner prints /around/ the run, no party receives it, and a reporter asked to
-- decide either @unless@ was being asked to guess about the run in the one
-- paragraph a reader trusts about the run. Verification caught it guessing both
-- ways, on a one-backend run (resolved, correctly, by luck) and on a
-- two-backend one (copied unresolved); guessed the other way round, an artefact
-- would have asserted single-backend provenance for a two-provider confer,
-- which is the exact over-trust this paragraph exists to prevent.
--
-- They are now @run.backends@ and @run.engine@
-- ('Agentic.Workflow.runFacts'), bound by the runner from the very fields the
-- header prints, and the two sentences state them:
--
--   * __Backends.__ The roster line, in the header's own words — and it counts
--     __transports__, which is not the same as counting answerers. The closing
--     rule used to read \"names more than one answerer\", and that was a
--     misreading of the fact it rests on: an @acp:@ backend is one adapter
--     process, and every seat of a confer goes down it to its /own/ pinned
--     serving model through its own fail-over ladder — so one backend routinely
--     serves several answerers. The converse fails too: several backends can end
--     up serving one, when a ladder spends its primaries and falls through to a
--     spare a second seat is also using. What names the intended answerers is
--     the header's @served by@ lines, and what records the answerer of a given
--     question is that question's scope in the trace, after the fact. Neither is
--     an input, so neither is in front of the reporter, and the paragraph says so
--     rather than letting a count of processes be read as a count of minds. The
--     one direction the fact does settle is the narrow one: a single transport
--     under a single session is one conversation, and agreement inside it is
--     agreement with itself.
--   * __Engine.__ The engine and its session policy. \"A new session per
--     question\" is @--engine acp@, whose @acpFreshPerQuestion@ opens a
--     @session\/new@ before every question; a run sent to a live agent-deck
--     session (@--session \<id\>@, which @--engine deck@ requires as well) is
--     one durable conversation in which the seats answer in program order and
--     the third has read the first two. Nothing forbids running a confer that
--     way — @README.md@ only advises against it — and now nothing has to guess
--     which was done.
--
-- What remains a rule rather than a statement is the closing paragraph, and
-- deliberately: it tells the reporter what to /do/ with two facts that are in
-- front of it, which is reading rather than guessing.
-- 'conferWriteBrief' and 'conferBareWriteBrief' say so.
--
-- This closes @doc\/followups.md@'s @F1-followup@, which asked for exactly these
-- two facts and named the runner as the only place they could come from.
conferProvenance :: Roster -> Text -> Text -> Text
conferProvenance r backends engine =
  [wft|
  Provenance: a confer of {count} parties.

  {table}

  Those are the seats the program asked, each pinned to its own serving model
  through a fail-over ladder. Two things about how they were answered are
  properties of the run and not of the program, and this run supplied both.

  Backends: {backends}. That line counts TRANSPORTS, not answerers, and it is
  the whole of what this run reached: no block below was produced by anything
  it does not name.

  Engine: {engine}. Read that line this way: a new session per question is
  independence of context and not independence of judgement; one session for
  the whole run is one conversation, in which the seats answer in program
  order and each has read the blocks above it.

  Do not describe agreement between two blocks as independent confirmation
  unless two different parties produced them -- and the Backends line above
  does not settle that on its own, in either direction. One backend can serve
  several answerers, because each seat is pinned to its own serving model and
  reaches it through a fail-over ladder down that one transport; several
  backends can end up serving one, because a ladder that spends its primaries
  falls through to a spare the next seat is also using. What names the intended
  answerers is the run header's `served by` lines, and what records the actual
  one for each question is that question's scope in the trace. Neither is in
  front of you here. So: if the Backends line names one transport and the
  Engine line says one session, say plainly that agreement below is one
  conversation agreeing with itself. Otherwise say which facts you have and
  stop there, rather than upgrading a count of transports into a count of
  minds.|]
  where
    count = tshow (length r)
    table = rosterTable r

-- ---------------------------------------------------------------------------
-- The artefact
-- ---------------------------------------------------------------------------

-- | What the closing act is told to write, when there is a synthesis.
--
-- /Source:/ @confer-design.md@ §1.5, verbatim.
--
-- The blocks go in __verbatim__ and the recommendation goes in beside them,
-- because the whole difference between a confer and an opinion is that the
-- reasoning is inspectable.
--
-- __The provenance paragraph is constant text and this brief says so.__ See
-- 'conferProvenance': its two statements about the run — how many backends
-- answered, and which engine and session policy they answered under — are
-- __resolved facts the runner supplied__, not conditions to be decided. The
-- forbid below names both by the word each begins with, so a reporter can check
-- it has carried both, and forbids the two things it might do to them instead of
-- reproducing them: restating them in its own words, and hedging them with the
-- old \"I cannot see the header\" caveat, which is now false.
conferWriteBrief :: Text
conferWriteBrief =
  [wft|
  Write the confer below to `confer-<date>.md` in the current directory: the
  provenance line first, then the decision this confer was about, then every
  party's block verbatim under its own name, then the recommendation, marked
  as one reading of the blocks and not as their sum.

  The provenance paragraph is constant text: reproduce it word for word,
  including both of its statements about the run -- the sentence beginning
  "Backends:", naming every answerer this run reached, and the sentence
  beginning "Engine:", naming the engine and its session policy. Both were
  supplied by the runner and are already resolved: do not restate them in your
  own words, do not soften them, and do not add a caveat about not being able
  to see the run's header. What the header would have told you is in the
  paragraph.

  Apply the paragraph's closing rule to those two lines rather than to a guess:
  two blocks are independent confirmation only if more than one answerer is
  named and the run was not one session.

  Change no party's words. The blocks are the evidence; the recommendation is
  an argument about them, and a reader who disagrees with the argument must be
  able to check it against what was actually said. Then reply DONE.|]

-- | What the closing act is told to write, when there is no synthesis.
--
-- /Source:/ @confer-design.md@ §5.1, whose one differing clause is
-- @Example.Isaac@'s @reviewReportBrief@ (@Isaac.hs:494@--@:499@): \"Reconcile
-- nothing and rank nothing: six independent opinions are the artefact.\" A
-- decision the owner intends to make personally wants the same thing — the
-- arguments, with no aggregator standing between them and the reader.
--
-- It carries 'conferProvenance' too, so it carries the same forbid: both
-- statements about the run are the runner's and neither is the reporter's to
-- restate, for 'conferWriteBrief'\'s reason.
conferBareWriteBrief :: Text
conferBareWriteBrief =
  [wft|
  Write the confer below to `confer-<date>.md` in the current directory: the
  provenance line first, then the decision this confer was about, then every
  party's block verbatim under its own name, in the order they arrive.

  The provenance paragraph is constant text: reproduce it word for word,
  including both of its statements about the run -- the sentence beginning
  "Backends:", naming every answerer this run reached, and the sentence
  beginning "Engine:", naming the engine and its session policy. Both were
  supplied by the runner and are already resolved: do not restate them in your
  own words, do not soften them, and do not add a caveat about not being able
  to see the run's header. What the header would have told you is in the
  paragraph.

  Apply the paragraph's closing rule to those two lines rather than to a guess:
  two blocks are independent confirmation only if more than one answerer is
  named and the run was not one session.

  Reconcile nothing, rank nothing, and add no summary: the independent
  arguments are the artefact, and a reader who wanted them averaged did not
  need to ask several parties. Change no party's words. Then reply DONE.|]

-- | What @second-opinion@'s closing act is told to write.
--
-- /Source:/ @confer-design.md@ §5.3, verbatim.
secondOpinionWriteBrief :: Text
secondOpinionWriteBrief =
  [wft|
  Write the opinion below to `second-opinion-<date>.md` in the current
  directory, verbatim, under a heading naming the question. Change no words of
  it. Then reply DONE.|]
