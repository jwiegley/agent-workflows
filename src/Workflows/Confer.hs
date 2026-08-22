-- |
-- Module      : Workflows.Confer
-- Description : The confer family — a roster of stances, a fold, a synthesis.
--
-- __What this replaces.__ Nothing in @~\/src\/nix\/config\/ai@, and that is the
-- point: @confer@ is the workflow-native counterpart of PAL MCP's @consensus@,
-- which is a tool the owner calls and not a file he wrote. Its specification of
-- record is
-- @agent-cat\/doc\/research\/pal-subsumption\/confer-design.md@; the four
-- decisions this module executes — where it lives, which rows it registers, what
-- it owes "Workflows.Panels", and how the write is spelled — are
-- @doc\/design.md@ §8.1. The one corpus file that lands here is
-- @commands\/gravity.md@, harvested into
-- "Workflows.Rubrics.Stances"' 'challengeRubric' and 'skepticStance' and left
-- in place as Markdown for interactive use.
--
-- __PAL MCP stays configured.__ This is an alternative offered, not a
-- replacement mandated. What it buys is the option: the same shape, plus a price
-- before the spend, a trace after it, and a fold that is a term rather than
-- caller-side bookkeeping.
--
-- == What confer is, in five questions
--
-- Three parties are asked one decision under three stances; a synthesis folds
-- their document into a recommendation; an act writes the artefact. The decision
-- and its file context are __inputs__, so the operator's text reaches the
-- prompts as /data/ and not as an /answer/ — the difference
-- @Example.Isaac@'s @readRequest@ names, and the reason @confer@ does not open
-- by asking a tool to go and read the decision.
--
-- The price, for the standing three-seat roster: @level pipeline@, @size 6@,
-- @askNodes 5@, @codes text, text, text, text, receipt@,
-- @cost minFold 5, maxFold 5, over 1 path@ — one path, one price, not a range.
-- And @plan@ and @cost@ do not need the inputs to say so, so a confer is priced
-- before the decision has been written down.
--
-- == The fold is 'Agentic.Workflow.panelText' and not
-- 'Agentic.Workflow.panel'
--
-- A consensus output is document-shaped: the point of consulting three parties
-- is that three readings survive, attributed, for the synthesis and for the
-- human. @panel@ folds prose into a verdict tag — three essays become
-- @APPROVE@, or an objection list — and one /declined/ member annihilates the
-- whole fold, which is the right semantics for a gate and the wrong one for a
-- survey. @panelText@ folds into @\<for\>…\</for\>\<against\>…\</against\>@…,
-- one block per member under a label the __author__ chose, with each member's
-- attempt to forge its own closing tag defanged. Three parties asked to argue
-- opposing sides is precisely the configuration where one of them has an
-- incentive to write another's block.
--
-- The gate that wants a verdict instead is not a confer and is not a row here:
-- @doc\/design.md@ §8.1 rules that it belongs with "Workflows.Gates".
--
-- == The roster is routable, and this is how
--
-- The requirement was that backend routing land __without changing a line of
-- this module__. It landed — @Agentic.Route@ and @--route@ are live — and not a
-- line here moved. It holds for four reasons, and the first is the one that
-- shapes the table below, and the one the requirement is most often misstated
-- against: what a route table splits is not the /parties/.
--
-- 1. __A route names a serving model, never a party.__ A run's route table is
--    keyed on the model a question is pinned to, so
--    @--route \'gemini-3.1-pro-preview=deck:gemini-pane\'@ moves every seat
--    served by that model and nothing else. The pins in 'conferRoster' /are/
--    those keys, already written down. @Agentic.Route@ names the alternative
--    and rejects it in as many words — a party name is per-program and
--    per-role, and routing one would put every rung of its fail-over ladder on
--    one backend — so \"the seats are the names a route table splits\" is the
--    wrong mechanism even where it happens to move the right seats.
-- 2. __The three panel seats are pinned to three distinct primaries__ —
--    @opus@ through 'reasoning', @gemini-3.1-pro-preview@ through 'lateral',
--    @fable@ through 'broad' — which is what makes a route table able to put
--    them on three providers. Two seats sharing a serving model are two seats on
--    one backend however the run is routed, so the distinctness is load-bearing
--    and not decoration.
--
--    __\"The three panel seats\", and deliberately not \"the roster\".__ The
--    synthesis is @'reasoning' ('model' \"synthesis\")@ and 'reasoning''s
--    primary is @opus@, which is also the @for@ seat's — so no route table can
--    separate the synthesis from the @for@ seat. That costs the artefact
--    nothing (the synthesis is not compared against the seats; it reads them),
--    and it is written here rather than left in a design document so that a
--    reader routing this program is not surprised. If the synthesis ever wants a
--    backend of its own, the fix is one line — give it its own primary — and it
--    is a fix to this table, not to the engine.
-- 3. __A pin is not part of the question.__ Two asks differing only in their
--    alternates elaborate to the same plan, put the same question and bill the
--    same, because the chain is a property of the /model/ that @Agentic.Chains@
--    collects before the run. So the ladders cost nothing to write and nothing
--    to price, today or after routing.
-- 4. __The artefact does not move either.__ The document's block names are
--    'Workflows.Panels.lensName's — @for@, @against@, @neutral@ — which are the
--    author's and never the addressee's id. Repoint a seat at another provider
--    and the report's section headings are byte-identical, so two confers a
--    month apart stay comparable across a fleet change.
--
-- A confer is __useful and honest routed or not__, and what differs is what its
-- three blocks are evidence of. Routed, the three panel seats reach three
-- backends and the run's header names them, which is the only thing that makes
-- agreement between two blocks independent confirmation. Unrouted under
-- @--engine acp@, every question opens its own session, so the three seats are
-- three fresh sessions of one model — independence of /context/, which is real,
-- and not independence of /judgement/, which it is not. Sent to a live
-- agent-deck session it is neither: one conversation serves the whole run and
-- the third seat has read the first two.
-- 'Workflows.Rubrics.Stances.conferProvenance' is derived from the roster and
-- from the run's own two facts — @run.backends@ and @run.engine@, bound by the
-- runner ('Agentic.Workflow.runFacts') — and says all three /resolved/, inside
-- the artefact where a reader will actually be.
--
-- == Four rows, one shape
--
-- @confer@, @confer-bare@, @debate@ and @second-opinion@ (@doc\/design.md@
-- §8.1). The first three are 'conferOver' or 'conferBareOver' at a different
-- roster, which is why each is one line of 'conferProgram' and why none of them
-- can drift from the others in anything but its table: @debate@ is
-- 'conferRoster' /filtered/, so a stance reworded once reaches both.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}

module Workflows.Confer
  ( -- * The rows
    ConferRung (..),
    conferRungName,
    conferDoc,
    conferHelp,
    conferProgram,
    conferScript,

    -- * The rosters
    conferRoster,
    debateRoster,
    secondParty,

    -- * The two shapes the rows are built from
    conferOver,
    conferBareOver,
    secondOpinionOver,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The rosters
-- ---------------------------------------------------------------------------

-- | Three parties, three stances, three distinct serving models.
--
-- /Source:/ @confer-design.md@ §1.2.
--
-- __The three primaries are distinct on purpose__, for the reason the module
-- header gives at length: routing keys on the serving model and not on the
-- party, so two seats pinned to one model are two seats on one backend however
-- the run is routed. Three ladders, three primaries — @opus@,
-- @gemini-3.1-pro-preview@, @fable@ — is also what @Agentic.Chains@ wants: each
-- primary is pinned with one spelling, so the collected chains are well defined
-- and the run does not refuse to start.
--
-- __'Workflows.Panels.lensOwns' is load-bearing and not decoration.__
-- 'Workflows.Panels.memberNote' derives every party's sibling table from this
-- column, so \"do not write their blocks for them\" is a sentence with a
-- referent, and a fourth seat arrives in the other three's briefs __by being
-- added__.
conferRoster :: Roster
conferRoster =
  [ Lens
      { lensName = "for",
        lensOwns = "the strongest honest case that the decision is right",
        lensBrief = underChallenge forStance,
        lensParty = reasoning (model "advocate")
      },
    Lens
      { lensName = "against",
        lensOwns = "what breaks, traced to a mechanism",
        lensBrief = underChallenge skepticStance,
        lensParty = lateral (model "skeptic")
      },
    Lens
      { lensName = "neutral",
        lensOwns = "which claims the context settles, and which it cannot",
        lensBrief = underChallenge neutralStance,
        lensParty = broad (model "assessor")
      }
  ]

-- | For and against, with the synthesis. The middle seat is what a debate
-- deliberately does not have.
--
-- /Source:/ @confer-design.md@ §5.2.
--
-- __Filtering the standing roster rather than writing a second table is the
-- point.__ 'Workflows.Panels.memberNote' and
-- 'Workflows.Rubrics.Stances.conferSynthesis' both derive from whatever list
-- they are handed, so the two seats' briefs tell each of them that there is
-- exactly one other party and who it is, and the synthesis refuses on exactly
-- two blocks. Add a seat to 'conferRoster' and @debate@ is unaffected; reword a
-- stance and both programs get it.
debateRoster :: Roster
debateRoster = [seat | seat <- conferRoster, lensName seat /= "neutral"]

-- | The one party a @second-opinion@ asks.
--
-- /Source:/ @confer-design.md@ §5.3. 'lateral' and not 'reasoning': the whole
-- value of a second opinion is that it is not the party that produced the
-- first, and 'lateral''s own haddock says exactly that — \"a second opinion from
-- somewhere else… and the reason its primary is not the house model\". Under a
-- routed run it goes to another provider by the roster's own words.
secondParty :: Party 'IsModel
secondParty = lateral (model "second")

-- ---------------------------------------------------------------------------
-- The fan-out
-- ---------------------------------------------------------------------------

-- $fanout
--
-- __The debt this section held is paid.__ It carried @stanceAsks@ — the body of
-- 'Workflows.Panels.asksOver' copied at a subject the prompt splices as a
-- /define/ rather than as a live handle, because confer's subject is an input
-- and @asksOver@ was typed at @'Agentic.Workflow.KnownIx'@, which only a binding
-- satisfies. Its haddock said the function would be deleted the day
-- @confer-design.md@ §1.7's __R1__ landed. R1 landed in wave 2, when @teams@ and
-- @effort@ became the third and fourth callers wanting a define for a subject:
--
-- > asksOver :: (Says a s) => Roster -> Text -> a -> [Ask s]
--
-- so the two call sites below now read @asksOver roster stanceClosing subject@,
-- the copy is gone, and there is one fan-out in the tree again. Confer's four
-- rows price exactly as they did — the asks are the same four chunks in the same
-- order — which is what @ci\/workflows.sh@'s unmoved ceilings say.

-- ---------------------------------------------------------------------------
-- The programs
-- ---------------------------------------------------------------------------

-- | Confer over any roster: the fan-out, the synthesis, the artefact.
--
-- /Source:/ @confer-design.md@ §1.5. The shape is one; the roster is data,
-- which is why @debate@ is a row and not a second program.
--
-- __Why the run ends in an act.__ A run announces each answer through a
-- one-line rendering, so a multi-paragraph stance is collapsed to a single
-- console line; the trace holds the answers, but a trace is not a document a
-- person reads over coffee. So confer pays one leaf for its artefact, exactly as
-- @Example.Isaac@'s @review-lite@ does — and, as there, it is worth naming as a
-- cost rather than hiding: __confer is five questions where PAL's @consensus@ is
-- three model calls plus caller-side prose.__ What the two extra questions buy
-- is a synthesis that is a /question in the term/ — priced, traced,
-- attributable — and an artefact on disk that nobody had to copy out of a chat
-- window.
--
-- __The subject is spliced into the synthesis and into the artefact as well as
-- into the seats__, and that costs __nothing__ the price counts: a bill is a
-- question count and not a token count. The synthesis therefore reads the
-- decision itself rather than three summaries of it, and the artefact says what
-- it is a confer /about/.
--
-- __No @revising@, no @if@, no @case@.__ A confer collects and recommends; it
-- does not iterate to approval, and it does not branch. That is what keeps it
-- @level pipeline@ with one path and one price, and it is why this module needs
-- no decider and no gate.
conferOver :: Roster -> Text -> Text -> Text -> Text -> Program
conferOver roster decision context backends engine = workflow W.do
  stances <- panelText (zip (lensNames roster) (asksOver roster stanceClosing subject))

  recommendation <- ask (reasoning (model "synthesis")) [wf|
      {synthesis}

      {subject}

      {stances}|]

  ask_ reporter [wf|
      {writeBrief}

      {provenance}

      {subject}

      {stances}

      {recommendation}|]
  where
    subject = conferSubject decision context
    synthesis = conferSynthesis roster
    provenance = conferProvenance roster backends engine
    writeBrief = conferWriteBrief

-- | Confer with no synthesis: the parties' blocks, written down and not
-- reconciled.
--
-- /Source:/ @confer-design.md@ §5.1, whose argument is @review-lite@'s: its fold
-- is a pure reorder-then-union and it has no synthesis leaf __on purpose__,
-- \"because six independent opinions are worth more unreconciled than one
-- reconciled one\". A decision the owner intends to make personally wants the
-- same thing — three arguments and no aggregator standing between them and the
-- reader.
--
-- One statement shorter than 'conferOver', and one question cheaper.
conferBareOver :: Roster -> Text -> Text -> Text -> Text -> Program
conferBareOver roster decision context backends engine = workflow W.do
  stances <- panelText (zip (lensNames roster) (asksOver roster stanceClosing subject))

  ask_ reporter [wf|
      {writeBrief}

      {provenance}

      {subject}

      {stances}|]
  where
    subject = conferSubject decision context
    provenance = conferProvenance roster backends engine
    writeBrief = conferBareWriteBrief

-- | The quick second opinion: one party, no stance, no roster, no synthesis.
--
-- /Source:/ @confer-design.md@ §5.3. This is PAL's @challenge@ and PAL's @chat@
-- in one program, and it is the shape the owner reaches for most often — which
-- is why it is a row and not a flag on @confer@.
--
-- __The write is not optional here either.__ An @'ask_'@ at a /model/ would be
-- an ask at @receipt@, and the runner appends \"Do what was asked, then reply
-- with exactly DONE\" — so the opinion would be asked for and thrown away. Two
-- questions, and the second is the artefact.
--
-- There is no provenance line, and that is the point: a provenance that
-- disclaims independence between blocks has no referent when there is one block.
secondOpinionOver :: Text -> Text -> Program
secondOpinionOver decision context = workflow W.do
  opinion <- ask secondParty [wf|
      {challengeRubric}

      {subject}

      {closing}|]

  ask_ reporter [wf|
      {writeBrief}

      {subject}

      {opinion}|]
  where
    subject = conferSubject decision context
    closing = opinionClosing
    writeBrief = secondOpinionWriteBrief

-- ---------------------------------------------------------------------------
-- The rows
-- ---------------------------------------------------------------------------

-- | The four rows @doc\/design.md@ §8.1 rules on.
--
-- Four and not five. The fifth shape @confer-design.md@ §5.4 sketches — three
-- parties folded to a /verdict/, which is the one place
-- 'Agentic.Workflow.panel' is right — is unbuilt: nothing in this tree defines
-- it, and it is a sketch in that design and nowhere else. When it is built it
-- is a __gate__ and belongs with "Workflows.Gates", because calling it a confer
-- would be naming a gate after a survey.
data ConferRung
  = -- | three seats, synthesised — the counterpart of PAL's @consensus@
    Confer
  | -- | the same three blocks, unreconciled
    Bare
  | -- | for and against, and no middle seat
    Debate
  | -- | one lateral party under the challenge rubric
    Second
  deriving (Eq, Show)

-- | The name the operator types.
conferRungName :: ConferRung -> Text
conferRungName Confer = "confer"
conferRungName Bare = "confer-bare"
conferRungName Debate = "debate"
conferRungName Second = "second-opinion"

-- | The one line @wf list@ prints beside a row.
conferDoc :: ConferRung -> Text
conferDoc Confer = "three stances over one decision, folded to a document and synthesised"
conferDoc Bare = "the same three stances, written down and deliberately not reconciled"
conferDoc Debate = "for and against only: the pair, synthesised, with no middle seat"
conferDoc Second = "one contrary party under the anti-sycophancy rubric, and an artefact"

-- | The page @wf help \<row\>@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- One text at four settings, for 'conferProgram''s own reason: a variant is the
-- same program at a different roster, so a page per row would be four things to
-- keep true about one shape.
--
-- __The routing paragraph is the whole point of the family and is shared.__
-- The seats are pinned to distinct primaries so that a route table /can/ put
-- them on distinct providers; unrouted they are fresh sessions of one model,
-- which is independence of context and not of judgment. The three rows that
-- carry a provenance paragraph say which you got, from @run.backends@ and
-- @run.engine@ — and @second-opinion@ declares neither run fact, because one
-- block has nothing to be independently confirmed by. That is why its
-- @runFacts@ line in the header above is empty, and it is a fact worth seeing.
--
-- __It states no price.__ The header above carries the numbers, and for all
-- four rows the two bounds coincide: nothing branches and nothing loops, so
-- @wf cost@ answers before a word of the decision has been written.
conferHelp :: ConferRung -> Text
conferHelp r =
  [wft|
  {opening}

  **Inputs.**

  * `decision` — the question being conferred over, stated as a decision and
    not as a topic. It reaches every seat as *data*, so no turn can rewrite it
    and all of them are answering the same question.
  * `context` — the material it is decided against, and
    `--input-file context=doc/design.md` is the natural spelling: the operator's
    text arrives as data, which is why this row does not open by asking a tool
    to go and read a file. Empty is legal and the brief says so in as many
    words, so nobody has to invent a placeholder.

  **Transport.** An adapter of the run's own, and a `--route` per pinned seat
  whenever you want a seat served by somebody other than the house model.
  {routing}

  ```sh
  wf run {row} --engine acp --adapter claude --require-pinned \
     --route gemini-3.1-pro-preview=acp:codex \
     --input-arg decision={decisionEg} \
     --input-file context=doc/design.md
  ```

  **Rehearsal.** Both inputs named empty, every seat answered from the row's own
  canned table:

  ```sh
  wf run {row} --scripted --input-arg decision= --input-arg context=
  ```

  **Caveats.**

  {rowCaveat}
  {unrouted}
  * It writes a document and touches nothing else, so `--scratch` changes
    nothing about what it means.
  * There is no Markdown behind these rows. They are the workflow-native
    counterpart of a consensus tool, and what they add is a price before the
    spend and a trace after it.
  |]
  where
    row = conferRungName r

    opening = case r of
      Confer ->
        [wft|
        Three stances over one decision — the case for, what breaks and traced
        to a mechanism, and which claims the context actually settles — folded
        into a document and then synthesised.|]
      Bare ->
        [wft|
        The same three stances, written down and deliberately *not* reconciled.
        This is the row for when the reconciliation is yours to do and a
        synthesis would be a fourth opinion wearing the other three's clothes.|]
      Debate ->
        [wft|
        For and against only: the standing roster with the middle seat filtered
        out, synthesised. A debate is what it is by not having an assessor, and
        the two seats' briefs are told so.|]
      Second ->
        [wft|
        One contrary party under the anti-sycophancy rubric, and an artefact.
        It is the smallest shape in the confer family: one seat, told to argue
        with the decision rather than agree with it, where `confer` seats a
        panel and `debate` seats two sides.|]

    routing = case r of
      Second ->
        [wft|
        This row asks one party, and it is deliberately not the house model:
        the whole value of a second opinion is that it comes from somewhere
        else, so a route that sends it back to the primary undoes the row.|]
      Debate ->
        [wft|
        Two seats, two pins. Routing them apart is what turns "they agreed"
        from a fact about one model's temperature into a fact about two.|]
      _ ->
        [wft|
        Three seats, three pins, and the report's provenance paragraph is
        derived from where they actually landed.|]

    -- The seat count is the row's, so this cannot be one shared sentence:
    -- 'debateRoster' filters the middle seat out and @second-opinion@ asks one
    -- party, and a caveat that said "three" at all four would be false at two
    -- of them.
    unrouted = case r of
      Second ->
        [wft|
        * Unrouted under one adapter the contrary party is a fresh session of
          the house model. It will still argue — the rubric is what makes it
          argue — but an objection from the model that produced the thing being
          objected to is worth less than one from somewhere else, which is why
          this row's one seat is pinned away from the primary.|]
      Debate ->
        [wft|
        * Unrouted under one adapter the two seats are two fresh sessions of
          one model. That is independence of context and not of judgment; the
          report says which you got rather than letting the reader assume.|]
      _ ->
        [wft|
        * Unrouted under one adapter the three seats are three fresh sessions
          of one model. That is independence of context and not of judgment,
          and it is not what agreement across three providers would mean; the
          report says which you got rather than letting the reader assume.|]

    decisionEg :: Text
    decisionEg = case r of
      Debate -> "'Should ci/workflows.sh pin costMax by equality?'"
      Second -> "'I am about to fold the two registries into one.'"
      _ -> "'Should the registry be one table or two?'"

    rowCaveat = case r of
      Confer ->
        [wft|
        * The synthesis is a fourth question, and it is where this row's price
          differs from `confer-bare`'s. If you want the three stances and none
          of the reconciling, that row is a smaller bill and a different
          artefact.|]
      Bare ->
        [wft|
        * Nothing reconciles the three blocks, on purpose. The document is the
          deliverable and the disagreement in it is the finding — do not read
          the last block as a conclusion.|]
      Debate ->
        [wft|
        * It *filters* the standing roster rather than copying it, which is why
          a fourth seat added to `confer` moves `confer` and `confer-bare` and
          leaves this row exactly where it is.|]
      Second ->
        [wft|
        * It carries no provenance paragraph and declares no run facts, because
          one block cannot be independently confirmed by anything. What it buys
          is an argument and not a consensus, and reading it as a consensus is
          the one way to misuse it.|]

-- | The inputs the three rows with a provenance paragraph take.
--
-- Two the operator gives, and the second may be empty:
-- 'Workflows.Rubrics.Stances.conferSubject' says in as many words what an empty
-- context means, so an operator with nothing to attach does not have to invent a
-- placeholder.
--
-- Then two the __runner__ gives, and no command line may
-- ('Agentic.Workflow.runFacts'): @run.backends@ and @run.engine@ are the two
-- facts 'Workflows.Rubrics.Stances.conferProvenance' used to carry as
-- conditionals a reporter was forbidden to resolve. They are declared here
-- because a program declares its inputs; they are bound by @wf run@ and left
-- unbound by @wf plan@ and @wf cost@, where no run is being made — which costs
-- the price nothing, because no static fold reads a prompt.
conferInputs :: Ins (Text, (Text, (Text, (Text, ()))))
conferInputs =
  input "decision"
    :> input "context"
    :> input "run.backends"
    :> input "run.engine"
    :> noInputs

-- | The inputs @second-opinion@ takes.
--
-- The operator's two and neither run fact, because there is no provenance line
-- to carry them: one block cannot be independently confirmed by anything, so the
-- paragraph has no referent (see 'secondOpinionOver'). A row that declared a
-- fact nothing holes would be asking the runner for something it then threw
-- away.
secondOpinionInputs :: Ins (Text, (Text, ()))
secondOpinionInputs = input "decision" :> input "context" :> noInputs

-- | The program a row holds.
--
-- One line each, which is the whole claim of @confer-design.md@ §5: a variant is
-- the same program at a different roster, so none of them can drift from the
-- others in anything but its table.
conferProgram :: ConferRung -> Parameterized
conferProgram Confer = taking conferInputs (conferOver conferRoster)
conferProgram Bare = taking conferInputs (conferBareOver conferRoster)
conferProgram Debate = taking conferInputs (conferOver debateRoster)
conferProgram Second = taking secondOpinionInputs secondOpinionOver

-- | The canned replies a @--scripted@ run of a row answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves.__ Each seat's prompt opens with its own
-- 'Workflows.Panels.lensBrief', which is
-- @'Workflows.Rubrics.Stances.underChallenge' \<stance\>@, and the synthesis's
-- opens with 'Workflows.Rubrics.Stances.conferSynthesis' at the very roster the
-- panel was built from — so every key below is a prefix of the rendered prompt
-- __by construction__ rather than by proofreading, and a seat added to
-- 'conferRoster' arrives here by being added.
--
-- __The three seats must get three different answers, and they do only because
-- the shared rubric comes second.__ A scripted table matches the first entry
-- whose key is a prefix of the prompt; a roster whose seats shared an opening
-- chunk would have one canned answer serving all three, and the fan-out would be
-- untested by the gate that exists to test it. That is the whole reason
-- 'Workflows.Rubrics.Stances.underChallenge' puts the stance first, and this
-- table is where the rule is checked.
--
-- Only the /text/ questions need entries: a scripted run answers a receipt
-- @DONE@ by default, and the closing act is a receipt.
conferScript :: ConferRung -> [(Text, Text)]
conferScript Confer = seatRows conferRoster <> [(conferSynthesis conferRoster, recommended)]
conferScript Bare = seatRows conferRoster
conferScript Debate = seatRows debateRoster <> [(conferSynthesis debateRoster, recommended)]
conferScript Second = [(challengeRubric, opinionAnswer)]

-- | One canned block per seat, derived from the roster the panel is built from.
seatRows :: Roster -> [(Text, Text)]
seatRows r = [(lensBrief l, blockFrom (lensName l)) | l <- r]

-- | The canned block a seat returns, distinct per seat.
--
-- Distinctness is the assertion: three identical blocks would mean the scripted
-- run had matched one key three times, which is exactly the failure the
-- stance-before-rubric order exists to prevent.
blockFrom :: Text -> Text
blockFrom "for" =
  [wft|
  The rewrite pays for itself in the parser's two worst files: the hand-rolled
  state machine in `lex.c` is where every open bug lives, and a table-driven DFA
  deletes the class rather than the instances.|]
blockFrom "against" =
  [wft|
  The cost the proposal does not price is the error messages. `lex.c` reports a
  column and a suggestion; a generated DFA reports a state number, and every
  downstream consumer of the diagnostics format breaks on the same day.|]
blockFrom "neutral" =
  [wft|
  Settled by the context: the bug list, and that the grammar is regular. A
  judgement call: whether diagnostics quality is negotiable. Unknowable from
  what is here: how many callers parse the diagnostics.|]
blockFrom n = "No position from the " <> n <> " seat."

-- | The canned synthesis, which deliberately does __not__ open a line with
-- @INCOMPLETE:@ — the scripted run walks the arm where every block arrived.
recommended :: Text
recommended =
  [wft|
  The parties disagree on one thing: whether diagnostics quality is a constraint
  or a preference. `for` says the DFA deletes a bug class; `against` says it
  deletes the column numbers with it. What turns on it: if diagnostics are a
  constraint the rewrite needs a source-map, which is most of the work.
  Recommendation: rewrite, with the source-map in scope from the start. This
  changes if no caller parses the diagnostics.|]

-- | The canned second opinion.
opinionAnswer :: Text
opinionAnswer =
  [wft|
  The claim holds for the lexer and not for the parser. It is weakest where it
  assumes the grammar stays regular; one context-sensitive rule and the table is
  back to hand-written code beside it. What would change my answer: a single
  counterexample rule in the current grammar.|]
