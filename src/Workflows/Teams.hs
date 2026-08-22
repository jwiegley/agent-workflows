-- |
-- Module      : Workflows.Teams
-- Description : Ten angles on one problem, a devil's advocate over the fold,
--               and a review of all the work.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------+----------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@           | here                                                           |
-- +=====================================+================================================================+
-- | @commands\/teams.md@, bullets 1–10  | 'teamsRoster' — ten 'Workflows.Panels.Lens'es, one             |
-- |                                     | 'Agentic.Workflow.panelText' fold                              |
-- +-------------------------------------+----------------------------------------------------------------+
-- | @commands\/teams.md@, bullet 11     | 'advocateBrief' — a __second tier__ over the fold, and not an  |
-- | (\"one playing devil's advocate\")  | eleventh peer: it argues with what the others said, which is   |
-- |                                     | a thing a bullet list cannot say                               |
-- +-------------------------------------+----------------------------------------------------------------+
-- | @commands\/teams.md@, bullet 12     | 'teamsSynthesis' — the synthesis, whose roster table and whose |
-- | (\"one reviewing all work performed | refusal are derived from the very list the panel was built     |
-- | by other teams\")                   | from                                                           |
-- +-------------------------------------+----------------------------------------------------------------+
-- | @commands\/gravity.md@              | 'Workflows.Rubrics.Stances.challengeRubric', which the         |
-- |                                     | advocate stands under. @doc\/design.md@ §7.2 row 23 says this  |
-- |                                     | is the home that fold was looking for; the command itself      |
-- |                                     | stays Markdown (row 23 is a __K__)                             |
-- +-------------------------------------+----------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The fan-out is priced.__ @teams.md@ is twelve bullets and a verb
--      (\"create an agent team\"); how many agents that is, what each costs, and
--      whether they run at all is whatever the reading agent decides.
--      @wf cost teams@ answers 13 before a word of the problem has been written,
--      and the number is the roster's: ten members, the advocate, the synthesis,
--      the artefact.
--
--   2. __\"Different angles\" becomes a table each angle can see.__ Ten bullets
--      cannot tell teammate six what teammate two owns.
--      'Workflows.Panels.memberNote' derives every member's sibling table from
--      'Workflows.Panels.lensOwns', so \"do not repeat their work\" has a
--      referent, and an eleventh angle arrives in the other ten's briefs
--      __by being added__.
--
--   3. __The devil's advocate is a tier and not a peer.__ In the list it is one
--      bullet among twelve, which puts it in parallel with the work it exists to
--      attack — so in the corpus it argues with the problem rather than with the
--      team, or it argues with nine blocks it never saw. Here it is one question
--      after the fold, holding the whole document, and it stands under the
--      anti-sycophancy rubric every contrary party in this tree stands under.
--
--   4. __A missing block is an ending.__ \"One reviewing all work performed by
--      other teams\" is a review that cannot tell whether all the work arrived.
--      'Workflows.Panels.refusingSynthesis''s construction is used instead: the
--      synthesis is /asked/ to account for the blocks and to answer
--      @INCOMPLETE: …@, and 'Workflows.Deciders.incompleteFanOut' reads that
--      answer __for nothing__ — so a nine-block exploration cannot come out
--      looking like a ten-block one.
--
--   5. __The artefact survives the run.__ A run announces each answer as one
--      console line, so ten essays would arrive collapsed. One act writes the
--      whole thing down, and it is the same act on both endings with a different
--      provenance line — which is "Workflows.Report"'s contract.
--
-- == Two honest notes
--
-- __The count in @doc\/design.md@ §7.2 row 23 and its price disagree, and the
-- price wins.__ That cell says \"eleven roster rows … @cost@ says 13 before the
-- run\". @teams.md@ has __twelve__ bullets, and 13 is reachable only one way:
-- ten members, the advocate as a second tier, the synthesis, and the artefact.
-- Eleven members plus those three would be 14. The number is what the gate pins
-- and what an operator reads, so the number is what was built, and the
-- discrepancy is written here rather than left for a reader to rediscover.
--
-- __Each member's rubric is its bullet, made into a question.__ @teams.md@ gives
-- one clause per teammate and nothing else, so there is no rubric to transplant
-- — only a role. Every 'Workflows.Panels.lensOwns' below is that clause; every
-- 'Workflows.Panels.lensBrief' says what answering it consists of and refuses to
-- range past what the clause names. Nothing here is a rubric the corpus has and
-- this module paraphrased: where the corpus is silent, this module is short.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Teams
  ( -- * The program
    teamsProgram,
    teamsDoc,
    teamsHelp,
    teamsScript,

    -- * The roster, and the two questions above it
    teamsRoster,
    teammates,
    advocateBrief,
    teamsSynthesis,

    -- * The artefact both endings write through
    teamsReportFn,
    teamsTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The roster
-- ---------------------------------------------------------------------------

-- | @commands\/teams.md@'s first ten bullets: the name this program calls each
-- angle, the bullet itself, and what answering it consists of.
--
-- /Source:/ the file, in its own order. The middle column is the corpus's words;
-- the third is this module's, and it says only what the bullet names.
teammates :: [(Text, Text, Text)]
teammates =
  [ ( "domain",
      "deep research on the problem domain",
      [wft|
      Establish what the problem actually is, in the terms of the field it
      belongs to. Name the entities, the invariants, the vocabulary and the
      constraints that come from the domain itself rather than from any proposed
      solution. Say which parts of the stated problem are the real difficulty
      and which are incidental.|]
    ),
    ( "practice",
      "deep research on community best practices",
      [wft|
      Report what practitioners in this area have settled on, and how settled it
      is. Separate a convention that exists for a reason from one that exists
      because a popular tool chose it. Where a practice is contested, name both
      camps and what the disagreement turns on.|]
    ),
    ( "prior-art",
      "deep research on prior art and existing solutions",
      [wft|
      Find what already solves this or nearly solves it -- libraries, systems,
      papers, previous attempts inside this codebase. For each, say what it
      does, where it stops, and what adopting it would cost. A candidate you
      reject is worth naming with its reason: the next reader will think of it
      too.|]
    ),
    ( "ux",
      "UX",
      [wft|
      Answer for whoever has to use the result. Walk the path they take, name
      the point at which they must understand something to proceed, and say what
      they will get wrong. Where the problem statement assumes a user who
      already knows something, say so.|]
    ),
    ( "architecture",
      "technical architecture",
      [wft|
      Propose the shape: the components, what each owns, and where the seams
      are. Say which decisions are load-bearing and hard to reverse, and which
      can be deferred. Name the alternative you rejected and the property that
      decided it.|]
    ),
    ( "planning",
      "planning and strategy",
      [wft|
      Turn this into an order of work. Say what must come first because
      something else needs it, what can proceed in parallel, and what the first
      slice is that is worth having on its own. Name the decision that has to be
      made before the work can start.|]
    ),
    ( "testing",
      "testing and code coverage",
      [wft|
      Say how this would be known to work. Name the properties worth asserting,
      the cases that are easy to get wrong, and the kind of test that would
      catch each. Say where coverage would be misleading -- a path exercised by
      a test that would pass whatever the code did.|]
    ),
    ( "security",
      "security and code safety",
      [wft|
      Answer for what an adversary or an accident could do. Name the trust
      boundaries, the inputs that cross them, and what happens when each is
      hostile or malformed. Say which failure modes are silent, because those
      are the expensive ones.|]
    ),
    ( "performance",
      "performance and efficiency",
      [wft|
      Say what this costs when it runs: the critical path, the allocations, the
      work that scales with input and the work that scales with the collection.
      Name the measurement that would settle each claim, and separate what you
      computed from what you expect.|]
    ),
    ( "documentation",
      "documentation and good code comments",
      [wft|
      Say what a reader would need written down, and where. Name the decisions
      whose reasons will be invisible in the result, the invariants a comment
      has to carry because the types cannot, and the places where a comment
      would only narrate the code.|]
    )
  ]

-- | The line every teammate's brief closes with, above its own clause.
--
-- It is second rather than first, deliberately: a scripted table matches the
-- first entry whose key is a prefix of the prompt, so a roster whose members
-- shared an opening chunk would have one canned answer serving all ten and the
-- fan-out would be untested by the gate that exists to test it. This is
-- @confer@'s rule, and 'teamsScript' is where it is checked.
teamStance :: Text
teamStance =
  [wft|
  You are exploring, not deciding. Report what you found and what you judge,
  keep the two apart, and say which of your claims you verified and which you
  are asserting from experience. Where the problem as stated does not give you
  enough to answer, say what is missing rather than assuming it.|]

-- | Ten angles, three serving rungs.
--
-- The rung is chosen by what the angle is: the two that /design/ something and
-- the one that reasons about an adversary go to 'reasoning'; the two whose value
-- is in not thinking like the others go to 'lateral'; the rest, which are wide
-- reading, go to 'broad'. Three distinct primaries, which is what makes a
-- @--route@ able to put the panel on three backends.
teamsRoster :: Roster
teamsRoster =
  [ Lens
      { lensName = n,
        lensOwns = owns,
        lensBrief = brief <> "\n\n" <> teamStance,
        lensParty = rungFor n (model ("team-" <> n))
      }
  | (n, owns, brief) <- teammates
  ]
  where
    rungFor n
      | n `elem` ["architecture", "planning", "security"] = reasoning
      | n `elem` ["ux", "prior-art"] = lateral
      | otherwise = broad

-- ---------------------------------------------------------------------------
-- The prompts
-- ---------------------------------------------------------------------------

-- | The problem and its context, as one define the whole roster reads.
--
-- Two inputs and one subject, for @confer@'s reason: a fan-out member takes one
-- artefact, and the context may be empty without that meaning a document failed
-- to arrive.
teamsSubject :: Text -> Text -> Text
teamsSubject problem context =
  [wft|
  The problem this team is exploring:

  {problem}

  The context. This may be empty, and empty means the problem stands on its
  own words -- it does not mean a document failed to arrive:

  {context}|]

-- | What each member is told about the shape of its answer.
teamClosing :: Text
teamClosing =
  [wft|
  Report your angle and nothing else. Your answer is one block of a document
  whose other blocks are your teammates', each fenced under its own name: do
  not summarise the whole, do not write theirs, and do not recommend a course
  of action for the team -- that is a later question, put to somebody who has
  read all of you.|]

-- | The devil's advocate, over the fold.
--
-- /Source:/ @commands\/teams.md@ bullet 11, and
-- 'Workflows.Rubrics.Stances.challengeRubric', which is
-- @commands\/gravity.md@'s harvested second half and is what every contrary
-- party in this tree stands under.
advocateBrief :: Text
advocateBrief = underChallenge devilStance

-- | The stance the advocate composes with the challenge rubric.
--
-- The stance comes first and the shared rubric second, for 'teamStance''s
-- reason: it is what keeps this question's canned reply distinct from the ten
-- above it.
devilStance :: Text
devilStance =
  [wft|
  You are the devil's advocate, and you are reading a document the team has
  already written. Argue against it -- not against the problem.

  Take the strongest position each block reached and say why it might be
  wrong: the assumption it rests on that nobody stated, the case it does not
  cover, the two blocks that have quietly agreed on something neither
  checked. Where the whole team converged, that is where to look hardest;
  agreement between parties who read the same brief is not evidence.

  Name what the team did not consider at all. If the strongest objection you
  can find is weak, say that plainly and say why -- an advocate who
  manufactures an objection has cost the reader more than one who reports the
  case is sound.|]

-- | The synthesis brief, with the roster it accounts for derived from the same
-- table.
--
-- /Source:/ @commands\/teams.md@ bullet 12 (\"one reviewing all work performed
-- by other teams\") and 'Workflows.Panels.refusingSynthesis''s construction —
-- the accounting paragraph and the @INCOMPLETE:@ contract, which
-- 'Workflows.Deciders.incompleteFanOut' reads for nothing. The consolidation
-- instructions are this program's own: 'Workflows.Panels.refusingSynthesis''s
-- are a code review's (deduplicate by file and line, sort by severity), and an
-- exploration has neither.
teamsSynthesis :: Roster -> Text
teamsSynthesis r =
  [wft|
  Below is the problem, a document of {count} blocks -- one per teammate, each
  fenced under its own name -- and a devil's advocate's reading of that
  document. The teammates and what each owns:

  {table}

  First, account for the blocks. If any named teammate's block is missing or
  empty, reply with exactly

    INCOMPLETE: <the names of the missing blocks>

  and nothing else. Do not review what did arrive: a partial team folded into
  a recommendation is indistinguishable from a whole one, and that is the one
  mistake this step exists to prevent.

  Otherwise, review all the work. In this order:

  1. Where the blocks agree, say so once and say whether the agreement is
     independent or is two teammates reading the same source.
  2. Where they conflict, name the conflict, say what turns on it, and say
     what would settle it. Do not average them.
  3. Say which of the advocate's objections survives -- naming, for each, the
     block it lands on -- and which the document already answers.
  4. Close with what the team is recommending, what it is not yet in a
     position to recommend, and the one decision that has to be made next.

  Judge the work, do not redo it. A teammate's finding you disagree with is
  reported with your disagreement beside it, not replaced.|]
  where
    count = tshow (length r)
    table = rosterTable r

-- ---------------------------------------------------------------------------
-- The two provenance lines
-- ---------------------------------------------------------------------------

-- | What the artefact says when every block arrived.
wholeTeamNote :: Roster -> Text
wholeTeamNote r =
  [wft|
  Provenance: a team of {angles} angles over one problem, a devil's advocate
  over their folded document, and a review of all the work. Every angle
  answered, and the review accounted for every block before it judged anything.
  The team, and what each angle owned:
  {table}
  Each angle was a separate question and no angle saw another's answer; the
  advocate and the review saw all of them.|]
  where
    angles = tshow (length r)
    table = rosterTable r

-- | What the artefact says when the review refused.
--
-- /Source:/ the ending @teams.md@ has no way to have. Its bullet 12 reviews
-- \"all work performed by other teams\" and has no means of noticing that some
-- of it never arrived.
shortTeamNote :: Text
shortTeamNote =
  [wft|
  Provenance: INCOMPLETE TEAM. The review refused, because at least one angle's
  block was missing or empty; its first line names which. Do not present this as
  a whole-team exploration: name the missing angles at the top of the document,
  and say that the recommendation below, if there is one, was reached without
  them.|]

-- | The brief the artefact is written through.
--
-- /Source:/ @commands\/teams.md@ has no output section — it ends at the twelfth
-- bullet. The shape is @confer@'s: the provenance first, then the subject, then
-- every block verbatim under its own name, then the two questions that stand
-- above them.
teamsWriteBrief :: Text
teamsWriteBrief =
  [wft|
  Write the team's exploration to `teams-<date>.md` in the current directory.

  In this order, and change nothing on the way: the provenance line you were
  given, verbatim, first; then the problem this team was exploring; then every
  angle's block, verbatim, under its own name as a heading; then the devil's
  advocate's reading under its own heading; then the review of all the work.

  You are transcribing, not editing. Do not summarise a block, do not merge
  two, do not reorder them, and do not resolve a disagreement the review left
  open -- a reader who wanted one voice would not have asked for a team. Then
  reply DONE.|]

-- ---------------------------------------------------------------------------
-- The artefact both endings write through
-- ---------------------------------------------------------------------------

-- | One act, two provenance lines.
--
-- Three parameters, provenance last for 'Workflows.Audit.Fess.fessReportFn''s
-- reason — it is the argument the two arms differ in and the reader of the call
-- site should meet it where the difference is — and first in the prompt, because
-- it is the thing an artefact must not omit.
teamsReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
teamsReportFn =
  function
    "teams.write"
    ( takes @"document" Text
        . takes @"review" Text
        . takes @"provenance" Text
        $ noParams
    )
    \document review provenance -> W.do
      act reporter [wf|
          {teamsWriteBrief}

          {provenance}

          {document}

          The review of all the work:

          {review}|]
      done

-- | The table 'teamsProgram' hands @'Agentic.Workflow.defining'@.
teamsTable :: [SomeFn]
teamsTable = [SomeFn teamsReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | Ten angles, an advocate, a review, an artefact.
--
-- Two inputs, both defines the whole roster reads: @problem@ is what
-- @teams.md@ calls \"this\", and @context@ may be empty.
--
-- __Where the price comes from.__ Ten members, one advocate, one review, one
-- act — thirteen questions, and the branch adds a path without adding a question
-- because 'Agentic.Workflow.decide' asks nobody. @wf cost teams@ prints that
-- before the first token, which is the thing twelve bullets cannot do.
teamsOver :: Text -> Text -> Program
teamsOver problem context = defining teamsTable W.do
  -- Ten questions, one per angle, each carrying the sibling table derived from
  -- the very list this fan-out is built from.
  angles <- panelText (zip (lensNames teamsRoster) (asksOver teamsRoster teamClosing subject))

  -- The second tier. It reads the whole document, which is what makes it an
  -- advocate against the team rather than an eleventh member of it.
  contrary <- ask (lateral (model "devils-advocate")) [wf|
      {advocateBrief}

      {subject}

      What the team wrote:

      {angles}|]

  -- Bullet 12, which must account for the blocks before it is allowed to judge
  -- them.
  review <- ask (reasoning (model "review-of-work")) [wf|
      {synthesis}

      {subject}

      {angles}

      The devil's advocate's reading:

      {contrary}|]

  -- The refusal, decided for zero questions.
  short <- tested incompleteFanOut review

  if short
    then W.do
      call_ teamsReportFn (arg angles :> arg review :> arg shortTeamNote :> noArgs)
      stop
    else W.do
      call_ teamsReportFn (arg angles :> arg review :> arg (wholeTeamNote teamsRoster) :> noArgs)
      stop
  where
    subject = teamsSubject problem context
    synthesis = teamsSynthesis teamsRoster

-- | The row.
teamsProgram :: Parameterized
teamsProgram = taking (input "problem" :> input "context" :> noInputs) teamsOver

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
teamsDoc :: Text
teamsDoc =
  "teams.md: ten angles on one problem, a devil's advocate over the fold, and a review of all of it"

-- | The page @wf help teams@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- __A row that prices exactly is a row whose page can say what the money buys__,
-- member by member, and that is what this one does: ten angles, the advocate,
-- the synthesis and the artefact. There is no loop and no branch to hedge
-- about, so the caveats are about what the row /will not/ do rather than about
-- how much it might cost.
--
-- __It states no price.__ The header above it carries the numbers off the same
-- 'Agentic.Plan.Facts' @wf list@ publishes.
teamsHelp :: Text
teamsHelp =
  [wft|
  `commands/teams.md` as a program: ten angles on one problem — research, prior
  art, user experience, architecture, planning, testing and the rest — a devil's
  advocate over the fold of them, and a review of all of it. It has no loop and
  no branch, so what it costs is exactly the roster plus the three questions
  that close it.

  **Inputs.**

  * `problem` — the thing being explored, in your own words
    (`how should the registry be split?`). Every angle reads this one sentence,
    so it is worth writing carefully: ten seats each answering a slightly
    different question is what a vague problem buys.
  * `context` — the background it is explored against, and `--input-file
    context=doc/design.md` is the natural spelling. It reaches every member as
    data, which is why the row does not open by asking a tool to go and read
    your design.

  **Transport.** Fine anywhere: ten readings, a fold, and one artefact. An
  adapter of the run's own is the usual shape, and its fresh session per
  question is worth something here — ten angles taken in one pane are ten turns
  of one conversation, each having read the last.

  ```sh
  wf run teams --engine acp --adapter claude --require-pinned \
     --input-arg problem='how should the registry be split?' \
     --input-file context=doc/design.md
  ```

  **Rehearsal.** Both inputs named empty, every question answered from the row's
  own canned table, consulting nobody:

  ```sh
  wf run teams --scripted --input-arg problem= --input-arg context=
  ```

  **Caveats.**

  * **It explores; it decides nothing.** The artefact is a document, and the
    devil's advocate is there to keep the fold from reading like agreement. If
    what you want is a decision argued to a verdict, the confer family is
    cheaper and shaped for it.
  * Ten angles is the roster and not a setting. A problem that wants three
    opinions wants `confer`; this row is the one that is deliberately broad.
  * It prices exactly, which means the number above is what it costs every time
    — there is no cheap ending to hope for.
  |]

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves.__ Each angle's prompt opens with its
-- own 'Workflows.Panels.lensBrief', the advocate's with 'advocateBrief' and the
-- review's with 'teamsSynthesis' at the very roster the panel was built from —
-- so every key is a prefix of the rendered prompt __by construction__ rather
-- than by proofreading, and an eleventh angle arrives here by being added.
--
-- __The ten answers are derived from the same table__, so they are distinct
-- without ten hand-written paragraphs, and distinctness is the assertion: ten
-- identical blocks would mean the scripted run had matched one key ten times,
-- which is exactly the failure the clause-before-stance order exists to prevent.
--
-- The review's answer deliberately does __not__ open a line with @INCOMPLETE:@,
-- so the scripted run walks the arm where every block arrived. The other arm is
-- reached by making it do so.
teamsScript :: [(Text, Text)]
teamsScript =
  [(lensBrief l, blockFrom l) | l <- teamsRoster]
    <> [ (advocateBrief, contraryAnswer),
         (teamsSynthesis teamsRoster, reviewAnswer)
       ]
  where
    blockFrom l =
      [wft|
      On {owns}: one finding worth acting on, and one thing this angle could not
      settle from what it was given. Reported by the {name} angle.|]
      where
        owns = lensOwns l
        name = lensName l

    contraryAnswer =
      [wft|
      The team has converged on treating the input format as fixed, and no block
      says why it is fixed -- prior-art and architecture both assume it and
      neither checked. That agreement is the weakest load-bearing point here.
      Everything else survives: the objections I can raise against the testing
      and performance blocks are smaller than the cost of raising them.|]

    reviewAnswer =
      [wft|
      All ten blocks accounted for.

      Agreed, independently: the first slice is worth having on its own
      (planning, architecture).
      Conflict: ux wants the format negotiable, prior-art assumes it fixed. What
      turns on it: whether the first slice ships behind a flag. What would
      settle it: one question to whoever owns the format.
      Advocate: the fixed-format objection survives and lands on prior-art. The
      rest the document already answers.
      Recommending: the first slice, format left negotiable. Not yet in a
      position to recommend: the migration. Next decision: who owns the format.|]
