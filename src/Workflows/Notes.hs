-- |
-- Module      : Workflows.Notes
-- Description : Meeting notes to a structured report — ten sections, and five
--               checkpoints audited by somebody else.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                     | here                                                      |
-- +===============================================+===========================================================+
-- | @commands\/meeting-notes.md@ @**ANALYSIS      | 'sectionRoster' — ten 'Workflows.Panels.Lens'es, one      |
-- | PROTOCOL**@ sections 1–10                     | 'Agentic.Workflow.panelText' fold, the section names as   |
-- |                                               | the fence labels                                          |
-- +-----------------------------------------------+-----------------------------------------------------------+
-- | its @**Quality Checkpoints**@ (five)          | 'checkpointRoster' — a __second__ panel, folded to a      |
-- |                                               | verdict, on a serving model none of the ten sections used |
-- +-----------------------------------------------+-----------------------------------------------------------+
-- | its @**Core Operating Principles**@,          | 'factOnly' — the standing rule every section stands under |
-- | @**Handling Ambiguity**@ and @**What You Will |                                                           |
-- | NOT Do**@                                     |                                                           |
-- +-----------------------------------------------+-----------------------------------------------------------+
-- | its @$ARGUMENTS@ file                         | @'Workflows.Evidence.fileContents'@ — a @cat@ receipt, so |
-- |                                               | the notes every section reads are bytes and are the same  |
-- |                                               | bytes                                                     |
-- +-----------------------------------------------+-----------------------------------------------------------+
-- | its two-phase collection workflow             | __dissolves__; see the honest notes below                 |
-- +-----------------------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The audit is on another engine, and that is the whole point.__
--      @doc\/design.md@ §7.2 row 34 states it in one clause: \"a fact-only
--      discipline audited by the same model is not audited\". In the corpus the
--      five checkpoints are a checklist the analyst ticks about its own output.
--      Here they are five questions put to a party pinned to a different
--      primary, over the draft __and__ over the notes receipt, folded to a
--      verdict — so the thing being checked is not the thing doing the checking.
--
--   2. __The verdict is an ending, not a note.__ @'Agentic.Workflow.panel'@
--      folds the five to @APPROVE@ or to an objection list, and
--      @'Agentic.Workflow.caseVerdict'@ has three arms the compiler makes the
--      author write. A report that failed its own fact-only audit cannot come
--      out looking like one that passed it, because the two call one function
--      with different provenance — which is "Workflows.Report"'s contract.
--
--   3. __Ten sections cannot be silently dropped.__ The corpus numbers them and
--      hopes. Here they are a list the fold is built from and the fold's labels
--      are 'Workflows.Panels.lensName's, so a missing section is a missing
--      block, and the roster table every section is told about is derived from
--      the same list.
--
--   4. __\"Only what is explicitly present in the notes\" gets a witness.__ The
--      notes are one @cat@ receipt bound once and spliced into all fifteen
--      questions, so no section is reading a different transcript, and the
--      checkpoint panel is handed the same bytes the sections were — which is
--      what makes \"every statement can be traced to specific note content\"
--      answerable rather than aspirational.
--
--   5. __The report is one act.__ The corpus says \"your output and resulting
--      report should be written to a Markdown file\" to an agent that has
--      already printed it. Here the write is an
--      @'Agentic.Workflow.act'@ — the only kind of answer the ACP transport
--      grants write authority to — and it is the same act on all three endings.
--
-- == Two honest notes
--
-- __The two-phase collection workflow dissolves, and it is not a loss.__
-- @meeting-notes.md@ has a Phase 1 in which notes are pasted in incrementally
-- and acknowledged without analysis, and a Phase 2 triggered by the word
-- @ANALYZE@. That machinery exists because a command is read by an agent in the
-- middle of a conversation, and it has no referent here: a program's inputs are
-- supplied before it starts, so there is no state in which notes are
-- accumulating and nothing to wait for. The file's own first paragraph says as
-- much — \"when $ARGUMENTS names a file, read it and execute the analysis
-- protocol immediately\" — and this program is that sentence with the fallback
-- removed rather than transcribed.
--
-- __The sections are not audited section by section.__ The five checkpoints are
-- put to the folded document, not to each block, so an objection names a
-- checkpoint and not a section. Five questions over one document is what the
-- corpus asks for; fifty questions over ten would be a different program and a
-- different price, and it is worth saying which one this is.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Notes
  ( -- * The program
    notesProgram,
    notesDoc,
    notesHelp,
    notesScript,

    -- * The two rosters
    sectionRoster,
    sections,
    checkpointRoster,
    checkpoints,

    -- * The standing rule
    factOnly,

    -- * The artefact every ending writes through
    notesReportFn,
    notesTable,

    -- * The one place an absent input is given a meaning
    notesFile,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The standing rule
-- ---------------------------------------------------------------------------

-- | @meeting-notes.md@'s @**Core Operating Principles**@, its @**Handling
-- Ambiguity**@ block and its @**What You Will NOT Do**@ list, as the one rule
-- every section stands under.
--
-- /Source:/ those three blocks, compressed to the part that is a constraint on
-- an answer. The @**SESSION ISOLATION**@ sentence is dropped and this is why: it
-- tells an agent to treat its context window as the universe, and here each
-- section is its own question over one receipt, so the isolation is a property
-- of the fan-out rather than an instruction. The paragraph about Claude's
-- general knowledge is dropped for the same reason — it names an addressee, and
-- the addressee is 'Workflows.Panels.lensParty'.
factOnly :: Text
factOnly =
  [wft|
  FACT-ONLY. Base every statement on explicit content from the notes you were
  given. Do not infer, assume or extrapolate what is missing; do not fill a
  gap with a reasonable guess or with what the field usually does; do not
  reach for context outside the notes. If something is not stated in the
  notes, it does not exist for this analysis.

  Where the notes are unclear, say so in the form "the notes indicate X, but
  details about Y were not recorded". You may offer a reading -- "in context
  this likely refers to X, confirmation needed" -- but never present it as a
  fact.

  Specifically do not: infer a participant's expertise, seniority or
  relationships; assume project background, industry context or
  organisational structure; create a deadline or a priority that was not
  stated; expand an abbreviation the notes do not define; add a best-practice
  recommendation nobody asked for; or treat a brainstormed idea as a committed
  plan.

  If a field or a section has nothing in the notes, write "Not specified." and
  move on. An empty section is an answer; an invented one is a defect.|]

-- ---------------------------------------------------------------------------
-- The ten sections
-- ---------------------------------------------------------------------------

-- | @meeting-notes.md@'s @**ANALYSIS PROTOCOL**@, section by section: the fence
-- label, the clause that says what the section is for, and what answering it
-- consists of.
--
-- /Source:/ the file, in its own order and with its own formats. Where it gives
-- a literal output shape, the shape is carried; where it gives a guard rail, the
-- guard rail is carried in the file's own words.
sections :: [(Text, Text, Text)]
sections =
  [ ( "metadata",
      "the meeting's stated date, participants, purpose, duration and format",
      [wft|
      Extract only explicitly stated information, one field per line: Date/Time,
      Participants, Purpose, Duration, Location/Format. If a field is absent,
      write "Not specified." -- do not omit the line, because an omitted line
      and an unstated fact look the same to the reader.|]
    ),
    ( "themes",
      "the notes restructured into the topics they actually cover",
      [wft|
      Restructure the notes into logical categories following the discussion
      flow. Use descriptive headers that reflect the topics actually covered,
      and under each, the points from the notes as bullets. Maintain the
      original meaning without embellishment: a bullet is a note's content
      reorganised, never rewritten into something stronger.|]
    ),
    ( "decisions",
      "what was clearly stated as decided, and what only looked like it",
      [wft|
      List only decisions clearly stated as made, agreed or finalised. For each:
      the decision in its own terms, its rationale if one was given, and the
      affected parties if they were mentioned. If you are uncertain whether
      something was decided or merely discussed, put it under "Discussed but not
      decided" -- that is the guard rail, and it is not optional.|]
    ),
    ( "actions",
      "the concrete assigned tasks, with owner, deadline and dependencies",
      [wft|
      Extract concrete, assigned tasks. For each: the task, its owner (or
      "Unassigned"), its deadline (or "No deadline specified"), its dependencies
      if mentioned, and its priority if stated. Include only items explicitly
      framed as action items or to-dos. A casual mention of future work is not
      an action item, and promoting one is the most expensive error in this
      section.|]
    ),
    ( "questions",
      "what was tabled, left unresolved, or asked and not answered",
      [wft|
      Identify what was explicitly tabled for later, discussed without reaching
      consensus, marked as needing more information, or asked and not answered
      in the meeting. Do not include questions you think should have been asked,
      or topics you believe need clarification: this section is about the
      meeting, not about the notes' quality.|]
    ),
    ( "timeline",
      "every date-bound item, in chronological order",
      [wft|
      Create a chronological view of all date-bound items, one per line, as
      "[date] - [event, deadline or milestone]". Include past dates the notes
      mention where they give the reader context. Every line here must
      correspond to a date that appears in the notes.|]
    ),
    ( "gaps",
      "the gaps the participants themselves named",
      [wft|
      List only gaps the meeting participants identified -- "we need to find
      out", "TBD pending", "waiting on confirmation of". Label the section "Gaps
      identified BY participants during meeting". Never include a gap you
      noticed from the outside: that is a different kind of claim and it does
      not belong in this report.|]
    ),
    ( "next-steps",
      "the immediate follow-ups, kept separate from what was assigned",
      [wft|
      Suggest immediate follow-up actions based strictly on the discussion
      content, under the heading "DERIVED FROM DISCUSSION". Then, under
      "EXPLICITLY ASSIGNED", the action items as the notes assigned them. The
      distinction between the two headings is the content of this section: a
      suggestion presented as an assignment is a fabricated commitment.|]
    ),
    ( "summary",
      "a four-to-six sentence synthesis of objective, outcomes and next steps",
      [wft|
      Write four to six sentences: the meeting's objective in one, the key
      outcomes and decisions in two or three, the critical next steps in one or
      two. Use concrete language. Do not write "various topics" or "productive
      discussion" -- if the notes do not support a concrete sentence, say what
      they do support instead.|]
    ),
    ( "flags",
      "conflicting information, unclear ownership, ambiguous deadlines",
      [wft|
      Flag any of these if the notes contain them: conflicting information;
      unclear ownership of a task; an ambiguous deadline; a decision that
      appears to contradict an earlier note. Quote the conflicting parts. If
      there are none, say so -- this section being empty is informative.|]
    )
  ]

-- | Ten sections, and the rung each is answered at.
--
-- Nine are wide reading over one document and go to 'broad'; @summary@ is the
-- one that synthesises and goes to 'reasoning'. Neither primary is the
-- checkpoint panel's, which is the property the whole design of this row rests
-- on: see 'checkpointRoster'.
--
-- The section's own clause comes __first__ in the brief and 'factOnly' second,
-- so that ten members do not share an opening chunk — a scripted table matches
-- the first key that is a prefix of the prompt, and a shared opening would have
-- one canned answer serving all ten. 'notesScript' is where that is checked.
sectionRoster :: Roster
sectionRoster =
  [ Lens
      { lensName = n,
        lensOwns = owns,
        lensBrief = brief <> "\n\n" <> factOnly,
        lensParty = rungFor n (model ("notes-" <> n))
      }
  | (n, owns, brief) <- sections
  ]
  where
    rungFor n
      | n == "summary" = reasoning
      | otherwise = broad

-- ---------------------------------------------------------------------------
-- The five checkpoints
-- ---------------------------------------------------------------------------

-- | @meeting-notes.md@'s @**Quality Checkpoints**@, one per row.
--
-- /Source:/ the file's five numbered checkboxes, verbatim in the middle column
-- and expanded into a question in the third. In the corpus they are ticked by
-- the analyst; here each is a question, and none of them is put to a party that
-- wrote any of the answer.
checkpoints :: [(Text, Text)]
checkpoints =
  [ ( "traceable",
      [wft|
      Check that every statement in the report can be traced to specific note
      content. Take the report's claims one at a time and look for the note that
      carries each. Object if any statement has no source in the notes, and name
      it.|]
    ),
    ( "unassuming",
      [wft|
      Check that the report makes no assumption about missing context. Look for
      a sentence that only makes sense if something absent from the notes were
      true -- a role, a prior decision, an organisational fact, an expanded
      acronym. Object with the sentence and the assumption it rests on.|]
    ),
    ( "decided",
      [wft|
      Check that decisions and discussions are clearly distinguished. Every item
      under decisions must have been stated as made, agreed or finalised in the
      notes; anything softer belongs under discussed-but-not-decided. Object
      with any item that crossed that line, in either direction.|]
    ),
    ( "assigned",
      [wft|
      Check that every action item has an explicit basis in the notes -- framed
      there as a task or a to-do, not merely mentioned as future work. Check the
      same for every owner, deadline and priority the report states. Object with
      any item, owner or date the notes do not carry.|]
    ),
    ( "faithful",
      [wft|
      Check that the executive summary reflects the meeting the notes describe.
      It must not introduce an outcome, a decision or an emphasis that the rest
      of the report does not carry, and it must not describe the meeting in
      vague terms where the notes are concrete. Object with the sentence and
      what is wrong with it.|]
    )
  ]

-- | The five checkpoints, all on __one__ rung, and deliberately not the
-- sections'.
--
-- /Source:/ @doc\/design.md@ §7.2 row 34. 'lateral''s primary is
-- @gemini-3.1-pro-preview@ and no member of 'sectionRoster' is served by it, so
-- the audit is answered by a model that did not write a word of what it is
-- auditing — which is the difference between an audit and a self-assessment, and
-- is the reason this is a second panel rather than five more sections.
--
-- Under an unrouted @--engine acp@ run the seats are fresh sessions of one
-- model, which is independence of /context/ and not of /judgement/; the pins are
-- the keys a @--route@ splits on, so the separation is available and the
-- artefact does not claim it was used.
checkpointRoster :: Roster
checkpointRoster =
  [ Lens
      { lensName = n,
        lensOwns = "whether the report holds up on: " <> n,
        lensBrief = brief,
        lensParty = lateral (model ("notes-check-" <> n))
      }
  | (n, brief) <- checkpoints
  ]

-- ---------------------------------------------------------------------------
-- The prompts
-- ---------------------------------------------------------------------------

-- | What the notes receipt is introduced as.
--
-- /Source:/ @meeting-notes.md@'s \"the notes can be found in the file
-- $ARGUMENTS\". The file is read by @cat@ in the run's own working directory, so
-- what every question below reads is bytes and is the same bytes.
rawBrief :: Text
rawBrief =
  [wft|
  The raw meeting notes this run was given, exactly as they stand in the file
  the operator named. They are the whole universe of information for this
  analysis: nothing that is not here is a fact about this meeting.|]

-- | What each section is told about the shape of its answer.
sectionClosing :: Text
sectionClosing =
  [wft|
  Write your section and nothing else. Your answer is one block of a report
  whose other blocks are the other sections', each fenced under its own name:
  do not write theirs, do not summarise the report, and do not add a heading
  of your own above your content -- the fold supplies your name.

  Use `##` for any sub-heading you need, bullets or `[ ]` checkboxes for
  lists, bold for names, dates and decisions, and keep paragraphs to four
  sentences. Dense with information, light on filler.|]

-- ---------------------------------------------------------------------------
-- The three provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the audit approved.
auditPassedNote :: Text
auditPassedNote =
  [wft|
  Provenance: the five quality checkpoints of `meeting-notes.md` were put to a
  party pinned to a serving model that answered none of the ten sections, over
  this report and over the notes receipt itself, and all five approved. The
  fact-only discipline was audited by somebody other than its author. Report the
  sections as they stand.|]

-- | The arm where the audit objected.
--
-- /Source:/ the ending @meeting-notes.md@ cannot have. Its checkpoints are a
-- list to \"verify\" before delivering, with no statement of what a failed
-- verification changes.
auditObjectedNote :: Text
auditObjectedNote =
  [wft|
  Provenance: the five quality checkpoints were put to an independent party and
  at least one OBJECTED. Its objection lines are given below and they are about
  this report, not about the meeting. Open the document with them, verbatim,
  under the heading `Fact-only audit: objections`; leave every section as
  written -- an objection is not a licence to rewrite the analysis it is about
  -- and do not describe this report as having passed its audit.|]

-- | The arm where the audit declined.
--
-- /Source:/ 'Workflows.Escalation.blockedNote', specialised. A verdict decodes
-- as declined on an __empty__ answer, which is a thing a model does; so this arm
-- is reachable and the compiler makes it be written.
auditSilentNote :: Text
auditSilentNote =
  [wft|
  Provenance: the five quality checkpoints were put to an independent party and
  it did not answer, so this report's fact-only discipline is UNVERIFIED. Say
  that in one sentence at the top of the document, before anything else. Do not
  describe any section below as checked, and do not substitute your own reading
  of the checkpoints for the audit that did not happen.|]

-- | The brief the artefact is written through.
--
-- /Source:/ @meeting-notes.md@'s \"your output and resulting report should be
-- written to a Markdown file\" plus its @**Response Formatting Standards**@.
notesWriteBrief :: Text
notesWriteBrief =
  [wft|
  Write the meeting report to `meeting-notes-<date>.md` in the current
  directory.

  In this order: the provenance line you were given, verbatim, first; then
  each section's block, verbatim, under its own name as a `##` heading, in the
  order they are given to you.

  You are transcribing, not analysing. Do not merge two sections, do not
  reorder them, do not drop one because it says "Not specified.", and do not
  add a section of your own. If the provenance line tells you to open with
  something, that is the one thing you add. Then reply DONE.|]

-- ---------------------------------------------------------------------------
-- The artefact every ending writes through
-- ---------------------------------------------------------------------------

-- | One act, three provenance lines, and the audit's own words carried into all
-- three.
--
-- __The middle parameter is a @verdict@ and not a @text@__, which is what lets
-- the objecting arm splice the objections the fold collected rather than a
-- paraphrase of them. A verdict interpolates into a prompt; a flag does not, and
-- that is why the checkpoint panel is folded with
-- @'Agentic.Workflow.panel'@ rather than tested with a decider.
notesReportFn :: Fn '[ 'CodeText, 'CodeVerdict, 'CodeText] 'CodeAck
notesReportFn =
  function
    "notes.write"
    ( takes @"sections" Text
        . takes @"audit" Verdict
        . takes @"provenance" Text
        $ noParams
    )
    \document audit provenance -> W.do
      act reporter [wf|
          {notesWriteBrief}

          {provenance}

          What the independent checkpoint panel answered:

          {audit}

          The report, section by section:

          {document}|]
      done

-- | The table 'notesProgram' hands @'Agentic.Workflow.defining'@.
notesTable :: [SomeFn]
notesTable = [SomeFn notesReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The file the run reads, and the one place an absent input is given a
-- meaning.
--
-- __Tier 1__: the fact is in the invocation. An absent input becomes a name no
-- file has, which is 'Workflows.Checklist.checklistFile''s rule and
-- 'Workflows.Git.Commit.treeNeedle''s before it: @wf plan notes --raw@ prints
-- @cat \<no notes file given\>@, so an operator who forgot the flag learns it
-- from the plan.
notesFile :: Text -> Text
notesFile p
  | T.null (T.strip p) = "<no notes file given>"
  | otherwise = T.strip p

-- | One receipt, ten sections, five checkpoints, one artefact.
--
-- One input: @notes@, the path @meeting-notes.md@ spells @$ARGUMENTS@. There is
-- no second input, because there is nothing else the corpus command takes — its
-- collection phase is a conversation and not a parameter.
--
-- __Where the price comes from.__ One @cat@ receipt, ten sections, five
-- checkpoints, one act — seventeen questions on every path, and the three-armed
-- @'Agentic.Workflow.caseVerdict'@ adds paths without adding a question, because
-- a fold is not an ask.
notesProgram :: Parameterized
notesProgram =
  taking (input "notes" :> noInputs) \path ->
    defining notesTable W.do
      -- The notes, as bytes, bound once and read by all fifteen questions
      -- below: no section is looking at a different transcript.
      raw <- ask (fileContents (notesFile path)) [wf|{rawBrief}|]

      -- The protocol, ten sections at once, each fenced under its own name.
      report <- panelText (zip (lensNames sectionRoster) (asksOver sectionRoster sectionClosing raw))

      -- The quality checkpoints, on a rung no section used, over the report AND
      -- over the notes it was drawn from. `withEvidence`'s own sentence -- a
      -- receipt outranks a reading -- is exactly the rule a fact-only audit
      -- needs, and the receipt here is the notes themselves.
      audit <- panel (withEvidence checkpointRoster verdictSpec report raw)

      -- Three endings, three provenance lines, one artefact.
      caseVerdict
        audit
        ( W.do
            call_ notesReportFn (arg report :> arg audit :> arg auditPassedNote :> noArgs)
            stop
        )
        ( W.do
            call_ notesReportFn (arg report :> arg audit :> arg auditObjectedNote :> noArgs)
            stop
        )
        ( W.do
            call_ notesReportFn (arg report :> arg audit :> arg auditSilentNote :> noArgs)
            stop
        )

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
notesDoc :: Text
notesDoc =
  "meeting-notes.md: ten sections over one notes receipt, and five fact-only checkpoints on another engine"

-- | The page @wf help notes@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- __One input, and the flag for it is the one worth spelling out__: @notes@ is
-- a /path/ read as the argv of a @cat@, so @--input FILE@ — which is the
-- natural thing to reach for on a one-input row — binds the file's contents
-- where this row wants its name. The bullet says so in as many words, because
-- the mistake produces a run that succeeds against a filename nothing has.
--
-- __It states no price.__ The header above it carries the numbers off the same
-- 'Agentic.Plan.Facts' @wf list@ publishes.
notesHelp :: Text
notesHelp =
  [wft|
  `commands/meeting-notes.md` as a program: ten sections — metadata, themes,
  decisions, action items, open questions, the timeline and the rest — over one
  notes receipt, with five fact-only checkpoints put to **another engine**,
  because a fact-only discipline audited by the model that wrote the prose is
  not audited.

  **Inputs.**

  * `notes` — the *path* to the notes file, which becomes the argv of a `cat`.
    Use `--input-arg notes=PATH`. **`--input FILE` is the wrong flag here**: it
    would bind the file's contents where the row wants its name, and the run
    would read a filename that does not exist.

  **Transport.** Fine anywhere: one receipt, ten sections, five checkpoints and
  one report. An adapter of the run's own is the usual shape, and `--scratch` is
  worth giving only if you mean to keep the file.

  ```sh
  wf run notes --engine acp --adapter claude --require-pinned \
     --input-arg notes=doc/meeting-2026-08-12.md
  ```

  **Rehearsal.** The one input named empty, every question answered from the
  row's own canned table, consulting nobody:

  ```sh
  wf run notes --scripted --input-arg notes=
  ```

  **Caveats.**

  * The five checkpoints are on a different engine by construction, and under
    one shared pane they are not. The report keeps its shape and reads the same;
    what it loses is the only thing that made "fact-only" more than a heading.
  * **Fact-only means fact-only.** Nothing here infers what somebody meant, so
    a set of notes that recorded no decision produces a report with an empty
    decisions section rather than a plausible one.
  * It prices exactly: ten sections and five checkpoints every time, with no
    cheap ending to hope for.
  |]

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves.__ The receipt's question opens with
-- 'rawBrief' and each section's with its own
-- 'Workflows.Panels.lensBrief', so every key is a prefix of the rendered prompt
-- by construction and an eleventh section arrives here by being added.
--
-- __The checkpoint panel needs no entries, and that is a choice worth naming.__
-- @'Agentic.Exec.scriptedDefault'@ answers a verdict @APPROVE@, so all five
-- approve and the run walks the arm where the audit passed — which is the arm an
-- operator wants rehearsed. The objecting arm is reached by adding one
-- @(brief, \"OBJECTION: …\")@ row for any checkpoint, and the declining arm by
-- adding one whose answer is empty; both are one line, and writing them here by
-- default would rehearse a failure on every gate run instead.
notesScript :: [(Text, Text)]
notesScript =
  (rawBrief, rawAnswer)
    : [(lensBrief l, blockFrom l) | l <- sectionRoster]
  where
    rawAnswer =
      [wft|
      Tue 12 Aug, 30 min, video. Present: RL, JS, MK.
      - Purpose: settle the 0.4.0 cut date.
      - RL: parser fixtures are stale, needs a day.
      - Agreed: cut on 19 Aug.
      - JS to update CHANGELOG by 18 Aug.
      - MK asked whether the format freeze applies to 0.4.0; not answered.
      - TBD pending legal on the licence header.|]

    blockFrom l =
      [wft|
      On {owns}: drawn from the notes above and nothing else. Not specified
      where the notes are silent. (the {name} section)|]
      where
        owns = lensOwns l
        name = lensName l
