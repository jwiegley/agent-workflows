-- |
-- Module      : Workflows.OrgTasks
-- Description : Org-mode tasks — one decomposed, or many extracted, with the
--               degenerate cases as arms.
--
-- == The map: old Markdown -> new program
--
-- +---------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@       | here                                                      |
-- +=================================+===========================================================+
-- | @commands\/breakdown.md@        | @org-tasks-breakdown@ — the analysis framework, the        |
-- |                                 | decomposition, the formatting rules, and its three         |
-- |                                 | special cases as three deciders and three arms             |
-- +---------------------------------+-----------------------------------------------------------+
-- | @agents\/task-breakdown.md@     | the same program: its @## Analysis Framework@ is the first |
-- |                                 | question, and its completeness check is the gate           |
-- +---------------------------------+-----------------------------------------------------------+
-- | @commands\/infer-tasks.md@      | @org-tasks-infer@ — the extraction, its @NO-OVERLAP RULE@  |
-- |                                 | as a free decider, and its two judgments on another engine |
-- +---------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __Three special cases, three deciders, three arms.__ @doc\/design.md@
--      §7.2 row 4's own words. @breakdown.md@ ends with a @## Special Cases@
--      section naming three, and in the corpus all three are shapes of the same
--      answer — a reader has to notice @[ATOMIC]@ where a list of subtasks was
--      expected. Here each is a @'Agentic.Workflow.decide'@ over the answer, for
--      zero questions, and each has its own terminal and its own provenance line,
--      so an atomic task and a decomposed one cannot be reported the same way.
--
--   2. __The completeness check is asked of somebody else.__
--      @agents\/task-breakdown.md@'s @### 5. Completeness Check@ — \"if all
--      subtasks are completed, will the parent task be fully done?\" — is a
--      question the decomposer asks itself, in its own head, as part of the same
--      answer. Here it is one @'Agentic.Workflow.confirm'@ on a
--      @'Workflows.Parties.lateral'@ party whose primary the decomposer did not
--      use, and its two arms carry two provenance lines. §7.3's task-breakdown
--      row asks for exactly this: \"a real analysis-decompose-format pipeline
--      with a completeness gate\".
--
--   3. __\"No nested children\" is decidable, and it is the load-bearing rule.__
--      @infer-tasks.md@ spends four sections on one invariant — a flat list of
--      siblings, no headline a refinement of another — and checks it in a
--      thirteen-item checklist the extractor ticks about itself. At the default
--      depth of one star, a line beginning @\"** \"@ /is/ a child:
--      'Workflows.Deciders.nestedHeadline', zero questions, one path, and the
--      arm that fires reports the violation rather than filing the list.
--
--   4. __The sentinel the corpus writes and never reads.__ @infer-tasks.md@'s
--      @\<special_cases\>@ says \"if no tasks are present: output exactly the
--      sentence 'No actionable tasks identified in this text.'\" — and then has
--      nothing that could read it. 'Workflows.Deciders.noTasksFound' reads it,
--      for nothing, and the run ends without paying for two judgments about an
--      empty list.
--
--   5. __A second party checks the first.__ §7.2 row 27: \"the two judgments go
--      to a differently-@servedBy@ party — a second party checks the first\".
--      'judgmentRoster' is those two, folded to a verdict, on
--      @'Workflows.Parties.lateral'@ — whose primary is neither the extractor's
--      nor the decomposer's — and @'Agentic.Workflow.caseVerdict'@ gives the
--      three arms the compiler makes the author write.
--
-- == The honest accounting of \"the mechanical eleven\"
--
-- §7.2 row 27 reads: \"the thirteen-item self-grading checklist /splits/: the
-- mechanical eleven become deciders at zero questions, the two judgments go to a
-- differently-@servedBy@ party\". The split is right and the second half landed
-- exactly as written. The first half did not, and this is the deviation.
--
-- @'Agentic.Text.Decider'@ has four constructors and they test one thing each:
-- the last non-empty line, an exact line, a line's prefix, and a path in a diff
-- header. @infer-tasks.md@'s eleven per-item checks are, in its own words: a
-- title of at most 67 characters; no articles; no abbreviations; an opening
-- action verb; specificity; grounding in the source; valid Org syntax at a
-- consistent depth; preserved metadata; the assignee convention; a priority only
-- where the source signals one; and no headline a refinement of another. Of
-- those, exactly __one__ — the last — is a line-prefix test, and it is the one
-- that landed ('Workflows.Deciders.nestedHeadline'). A character count, a
-- word-class test and an \"is this specific\" test are not expressible by any of
-- the four, and a decider that approximated one would be a test that fails
-- silently on the cases it was written for.
--
-- So the other ten stay where the corpus has them — in the extractor's brief, as
-- rules it is held to — and the two judgments are asked of somebody else. The
-- honest count is __one decider, one sentinel, two judgment seats__, and it is
-- written here rather than left for a reader to discover from the code.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.OrgTasks
  ( -- * The rungs
    OrgRung (..),
    orgRungName,
    orgDoc,

    -- * The program
    orgProgram,
    orgScript,

    -- * The two judgments a second party makes
    judgmentRoster,

    -- * The artefact every ending writes through
    orgReportFn,
    orgTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The rungs
-- ---------------------------------------------------------------------------

-- | The two Org-mode transforms, which @breakdown.md@'s own second paragraph
-- distinguishes: one expands a single task into the steps it needs; the other
-- extracts a flat list of commitments from unstructured text.
data OrgRung
  = -- | @commands\/breakdown.md@ + @agents\/task-breakdown.md@
    Breakdown
  | -- | @commands\/infer-tasks.md@
    Infer
  deriving (Eq, Show)

-- | The name the operator types.
orgRungName :: OrgRung -> Text
orgRungName Breakdown = "org-tasks-breakdown"
orgRungName Infer = "org-tasks-infer"

-- | The one line @wf list@ prints beside a rung.
orgDoc :: OrgRung -> Text
orgDoc Breakdown =
  "breakdown.md: analyse, decompose, format -- with [ATOMIC], [AMBIGUOUS] and [NO-EXPERTISE] as arms"
orgDoc Infer =
  "infer-tasks.md: extract a flat list, decide the nesting rule for free, and have a second party judge it"

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | @commands\/breakdown.md@'s @## Internal Analysis Process@ and
-- @agents\/task-breakdown.md@'s @## Analysis Framework@, as the first question.
--
-- /Source:/ the five dimensions both files name — understanding, scope and
-- complexity, hidden requirements, temporal and logical ordering, completeness —
-- carried in their own order.
--
-- __In the corpus this is explicitly /not/ output__ (\"do NOT output this
-- analysis\"), which is a way of saying that a model should think and then
-- forget. Here it is a question whose answer is a handle the decomposition
-- reads: the analysis is visible in the trace, it is priced, and the
-- decomposition can be checked against it.
analysisBrief :: Text
analysisBrief =
  [wft|
  Analyse one Org-mode task before anybody decomposes it. Answer with the
  analysis and nothing else -- no subtasks, no Org-mode.

  Work through five dimensions, in this order:

  1. Understanding. What is the explicit goal? What is implicitly required and
     not stated? What does "done" look like? What domain knowledge does the
     title, the tags, the URL, the properties, the body or the context carry?
  2. Scope and complexity. Is this learning, setup, feature development,
     research or maintenance? What are its natural phases? What does it depend
     on -- technically, in knowledge, in resources? What are the common
     pitfalls in this domain?
  3. Hidden requirements. What prerequisite knowledge, infrastructure, tools or
     access are needed? What testing or validation? What documentation? What
     integration points? What has to be maintained afterwards?
  4. Ordering. What must happen sequentially and what can be parallel? What are
     the logical dependencies? Are there waiting periods or external blockers?
  5. Completeness. If every subtask you can foresee were done, would the parent
     be fully done? Are research, setup, implementation, testing,
     documentation and integration all covered? What edge cases are there?

  Then, on the LAST line, one of these and nothing after it:

  - `[ATOMIC]` -- the task cannot meaningfully be broken down.
  - `[AMBIGUOUS: <what clarification is needed>]` -- it cannot confidently be
    decomposed without an answer from somebody.
  - `[NO-EXPERTISE]` -- it needs domain expertise you do not have, so any
    decomposition would be the standard project phases plus research steps to
    fill the gap.
  - `[PROCEED]` -- none of the above.

  Choose exactly one. `[AMBIGUOUS]` and `[NO-EXPERTISE]` are not the same
  thing: the first needs an answer from a person, the second needs research
  that is itself work.|]

-- | @commands\/breakdown.md@'s decomposition principles, subtask categories,
-- output rules and Org-mode formatting rules.
--
-- /Source:/ its @## Decomposition Principles@ (eight), @## Subtask Categories to
-- Consider@ (nine), @## Output Rules@ (six) and @## Org-Mode Formatting Rules@
-- (five), carried close to verbatim — the file's whole value is in the
-- specificity of these, and the 67-character limit, the article rule and the
-- action-verb rule are the sort of thing that is silently lost in a paraphrase.
--
-- What is dropped is its worked example, which is a third of the file and is an
-- illustration of the rules above it.
decomposeBrief :: Text
decomposeBrief =
  [wft|
  Decompose the Org-mode task below into subtasks, using the analysis you are
  given. Output ONLY the subtasks in valid Org-mode: no analysis, no synopsis,
  no preamble, no closing text, no code fences. Start at the first subtask and
  end at the last.

  Each subtask is:

  1. Actionable -- a clear action verb and a specific outcome.
  2. Appropriately sized -- roughly one to four hours of focused work: not so
     broad as to be ambiguous, not so narrow as to be trivial.
  3. Specific -- concrete and unambiguous.
  4. Complete -- together they cover 100% of the parent task.
  5. Non-overlapping -- each owns a distinct slice of the work.
  6. Ordered -- arranged in logical execution sequence.
  7. Measurable -- with clear criteria for being done.
  8. Independent where possible -- no unnecessary sequential dependency.

  Aim for three to ten for a typical task; fewer if it is small, more if it
  spans distinct phases. Cover, where they are relevant: research and
  learning, prerequisites, core implementation, configuration, integration,
  testing and validation, documentation, optimisation, and maintenance
  planning.

  Formatting, and these are hard rules:

  - Heading depth is exactly one level deeper than the parent: a parent at
    `* TODO` gets subtasks at `** TODO`, a parent at `*** TODO` gets `**** TODO`.
  - Every subtask starts in the TODO state.
  - A title is at most 67 characters. Shorten by removing filler, never by
    truncating meaning.
  - Remove articles -- "the", "a", "an" -- and write words in full: "with" not
    "w/", "and" not "&".
  - Every title begins with a clear action verb: Set up, Configure, Research,
    Implement, Write, Review, Test, Deploy.
  - No blank lines between sibling subtasks.

  Do not copy or repeat the input task.|]

-- | The guidance the @[NO-EXPERTISE]@ arm adds.
--
-- /Source:/ @commands\/breakdown.md@'s third special case, verbatim in
-- substance: \"provide a general decomposition based on standard project phases,
-- including research subtasks to fill in domain-specific details\".
noExpertiseGuidance :: Text
noExpertiseGuidance =
  [wft|
  The analysis reported that this task needs domain expertise it does not
  have. So this decomposition is the standard project phases, and its FIRST
  subtasks are research: find out what the domain actually requires before the
  later steps assume it.

  Open your answer with the line

    [NO-EXPERTISE]

  and then give the subtasks. A decomposition made without the domain in hand
  is worth having and is not worth mistaking for one made with it.|]

-- | @agents\/task-breakdown.md@'s completeness check, asked of a second party.
--
-- /Source:/ its @### 5. Completeness Check@ and @## Decomposition Principles@
-- item 4, which are the same demand stated twice in one file.
completenessBrief :: Text
completenessBrief =
  [wft|
  You are checking a decomposition you did not write.

  One question: if every subtask below were completed, would the parent task be
  fully done? Answer no if anything the parent needs is missing -- a phase, a
  prerequisite, a verification, the documentation, an integration point, an
  edge case the parent's own wording implies. Answer no if two subtasks overlap
  so badly that one of them is not really a slice of the work. Answer yes only
  if the set is genuinely exhaustive.

  Do not judge the wording, the ordering or the Org-mode formatting: another
  rule owns each of those. Answer with nothing but yes or no.|]

-- | @commands\/infer-tasks.md@, whole.
--
-- /Source:/ its @\<core_directive\>@, @\<output_shape\>@,
-- @\<extraction_rules\>@, @\<one_task_vs_many\>@, @\<priority_definitions\>@,
-- @\<assignee_rules\>@, @\<title_rules\>@, @\<orgmode_format\>@ and
-- @\<special_cases\>@, compressed to the rules and keeping every literal the
-- file is specific about — the priority letters, the tag convention, the
-- 67-character limit and the two sentinels.
--
-- Its five worked examples are not carried: they are half the file, they are
-- illustrations of the rules above them, and house rule 5 calls a rubric that
-- size a program input.
inferBrief :: Text
inferBrief =
  [wft|
  You are a task extraction specialist for Org-mode. Read the unstructured
  text below and emit a flat list of Org-mode headlines for the actionable
  commitments stated in it. Be precise and conservative, and never invent a
  task the source does not carry.

  Do NOT decompose. Extract only INDEPENDENTLY COMMITTED OUTCOMES: if a
  commitment names several steps, methods or implementation details, emit only
  the highest-level parent goal and discard the sub-steps. The "how" belongs to
  a different workflow; you capture the "what". If you find yourself wanting to
  add a child headline, stop and emit only the parent.

  All headlines at the SAME star depth, and no nested children. If the input is
  itself an Org headline, match its depth; otherwise use a single star.

  Extract: explicit commitments ("I'll handle X", "Sarah will Y", "we need to
  Z"); assigned action items with a clear owner and outcome; deadlines or
  scheduled events that require action; distinct deliverables that stand alone;
  and questions that imply a needed follow-up.

  Do not extract: procedural sub-steps describing HOW one outcome is achieved;
  discussion, opinion or observation with no action; completed past actions;
  hypotheticals with no stated commitment; background or explanatory material.

  Emit multiple siblings only where the source presents multiple INDEPENDENT
  commitments -- different owners, different deadlines, different separable
  deliverables, different unrelated systems, or an explicit enumeration of
  self-contained items. Emit one and stop where the source uses procedural
  language for one outcome: "by doing X, Y, Z", "which involves", "including",
  "using", "first... then... finally".

  NO-OVERLAP RULE. Never emit both a parent outcome and its component steps. If
  the source assigns specific components to specific owners, emit only those
  components and drop the umbrella. If no component is individually committed,
  emit only the umbrella. No headline may be a refinement of another.

  Keywords: TODO by default, TASK when an assignee tag is present, WAITING when
  blocked on an external response. Priority only where the source signals it:
  [#A] for explicit urgency or a deadline within 48 hours, [#B] for a standard
  deadline or ordinary workflow item, [#C] for nice-to-have or vague language.
  Otherwise omit the bracket entirely; never default to one.

  Assignees: "I" or the operator's own name produces no tag, because he is the
  default owner. Any other named person becomes their first name as a tag, as
  in `:Ben:`.

  Titles: at most 67 characters, no articles, no informal abbreviations
  (standard technical acronyms and proper names are fine), beginning with a
  clear action verb, and concrete enough to be unambiguous.

  Dates: `SCHEDULED:` and `DEADLINE:` on their own lines immediately after the
  headline, with timestamps as `<YYYY-MM-DD Day>`. Use DEADLINE for a hard due
  date and SCHEDULED for a planned start. Preserve source metadata -- IDs,
  URLs, ticket numbers, existing properties -- in a `:PROPERTIES:` drawer, and
  never synthesise a cross-task property such as BLOCKED_BY: that is not
  extraction. No blank lines between siblings, and none between a headline and
  its own SCHEDULED, DEADLINE or PROPERTIES lines.

  Output ONLY the task entries: no analysis, no preamble, no explanation, no
  code fences.

  If there are no tasks, output exactly

    No actionable tasks identified in this text.

  and optionally one short line saying why a near-miss did not qualify.|]

-- | What each judgment seat is told about the shape of its answer, with the
-- source text carried in.
--
-- The source is a program /input/ and therefore ordinary
-- 'Data.Text.Text' at this layer, so it is spliced into the closing once, in
-- Haskell, and handed to both seats — tier 1, zero questions. The seats' own
-- briefs stay independent of it, which is what keeps
-- 'orgScript''s keys stable across invocations.
judgmentClosing :: Text -> Text
judgmentClosing source =
  [wft|
  {spec}

  The source text the list was extracted from, which is the only thing either
  of us may judge it against:

  {source}|]
  where
    spec = verdictSpec

-- | The two judgments @infer-tasks.md@'s validation block cannot decide.
--
-- /Source:/ its @\<validation\>@ items 1 and 2 — \"grounded in specific language
-- from the source text\" and \"an INDEPENDENTLY COMMITTED OUTCOME, not a
-- sub-step of another task in the same output\" — which are the two of the
-- thirteen that are readings rather than measurements.
--
-- Both seats are @'Workflows.Parties.lateral'@, whose primary is not the
-- extractor's: §7.2 row 27's \"a second party checks the first\", and the reason
-- it is a second /party/ and not a second paragraph.
judgmentRoster :: Roster
judgmentRoster =
  [ Lens
      { lensName = "grounded",
        lensOwns = "whether every task is carried by specific language in the source",
        lensParty = lateral (model "infer-grounded"),
        lensBrief =
          [wft|
          Check that every headline in the list below is grounded in specific
          language from the source text. Take them one at a time and find the
          sentence that commits to each.

          Object with any headline whose commitment you cannot find: an
          invented task is the most expensive error this extraction can make,
          because it is indistinguishable from a real one once it is filed.
          Object also with any headline that states a deadline, an owner or a
          priority the source does not carry.|]
      },
    Lens
      { lensName = "independent",
        lensOwns = "whether each task is a committed outcome rather than a step of another",
        lensParty = lateral (model "infer-independent"),
        lensBrief =
          [wft|
          Check that every headline in the list below is an INDEPENDENTLY
          COMMITTED OUTCOME and not a sub-step of another headline in the same
          list.

          Object with any pair where one describes HOW the other will be done.
          Object with an umbrella outcome standing beside its own components,
          and with a component standing alone where the source committed only
          to the umbrella. This is the source's NO-OVERLAP rule, and it is the
          one thing a flat list can get wrong while looking perfectly
          well-formed.|]
      }
  ]

-- | The brief the report act is given.
orgWriteBrief :: Text
orgWriteBrief =
  [wft|
  Write the Org-mode result. The reader pastes it into a file, so what you
  write is the artefact and not a description of one.

  The provenance line you were given comes FIRST, as an Org comment -- a line
  beginning `# ` -- and verbatim. Then the Org-mode below, exactly as it
  stands: do not reindent it, do not renumber it, do not change a star depth,
  do not reword a title, and do not add or remove an entry.

  You are transcribing. If the provenance line says the result is degenerate
  or unverified, the comment says so and the entries below it stay as they
  are. Then reply DONE.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | @breakdown.md@'s first special case.
atomicNote :: Text
atomicNote =
  [wft|
  Outcome: ATOMIC. The analysis found this task cannot meaningfully be broken
  down, so no decomposition was produced and none should be invented below.
  Write the comment, then the task as it was given, unchanged.|]

-- | Its second.
ambiguousNote :: Text
ambiguousNote =
  [wft|
  Outcome: AMBIGUOUS. The analysis could not confidently decompose this task
  without an answer from a person; its `[AMBIGUOUS: …]` line says what is
  needed. Reproduce that line verbatim in the comment. Do not decompose anyway,
  and do not guess the missing detail.|]

-- | Its third.
noExpertiseNote :: Text
noExpertiseNote =
  [wft|
  Outcome: DECOMPOSED WITHOUT THE DOMAIN. The analysis reported that this task
  needs expertise it does not have, so what follows is the standard project
  phases with research subtasks first, and it was NOT checked for completeness
  -- a set nobody could judge is not a set to certify. Say that in the comment,
  and say that the research subtasks come first because the rest depends on what
  they find.|]

-- | The arm where the completeness gate approved.
--
-- Named @exhaustiveNote@ and not @completeNote@ because
-- 'Workflows.Escalation.completeNote' already means something else in every
-- module that imports "Workflows.Prelude" -- there it is the @WORK COMPLETE@
-- ending of a three-way revision, which this is not.
exhaustiveNote :: Text
exhaustiveNote =
  [wft|
  Provenance: this decomposition was produced from a written analysis, and a
  second party -- pinned to a serving model the decomposer did not use -- was
  asked whether completing every subtask would fully complete the parent, and
  said yes. The check is somebody else's, which is what makes it a check.|]

-- | The arm where it objected.
--
-- /Source:/ the ending @agents\/task-breakdown.md@ cannot have. Its completeness
-- check is a bullet in the analysis the decomposer does in its own head.
incompleteNote :: Text
incompleteNote =
  [wft|
  Outcome: INCOMPLETE DECOMPOSITION. A second party was asked whether completing
  every subtask below would fully complete the parent task, and said NO. The
  subtasks are reproduced unchanged, because a set that is short is still the
  set that was produced -- but say in the comment that it is known to be short,
  so that whoever files it looks for what is missing before working from it.|]

-- | @infer-tasks.md@'s empty case.
nothingFoundNote :: Text
nothingFoundNote =
  [wft|
  Outcome: NO TASKS. The extraction reported that the source text carries no
  actionable commitment, and it was believed: that sentence is the one thing
  this workflow asks for by name when there is nothing to extract. No judgment
  seat was asked, because there is nothing to judge. Reproduce the extraction's
  own sentence and any note it gave, and add nothing.|]

-- | The arm where the flat list was not flat.
nestedNote :: Text
nestedNote =
  [wft|
  Outcome: NESTED HEADLINES. The extraction emitted a headline at a deeper star
  depth than its siblings, which this workflow forbids absolutely: the output is
  a flat list of independent commitments, and a child headline is a
  decomposition that a different workflow owns. Do NOT file this list. Say in
  the comment which lines are nested, reproduce the list unchanged beneath, and
  say that the extraction should be re-run or the nested entries lifted by hand.|]

-- | The arm where both judgments approved.
groundedNote :: Text
groundedNote =
  [wft|
  Provenance: the list was extracted from the source text, checked for nesting
  by a grep over its own bytes, and then put to two independent judgment seats
  -- pinned to a serving model the extractor did not use -- which asked whether
  every entry is carried by specific language in the source and whether any
  entry is a step of another. Both approved.|]

-- | The arm where at least one objected.
objectedNote :: Text
objectedNote =
  [wft|
  Outcome: JUDGMENT OBJECTED. At least one of the two independent seats objected
  to this list; their objection lines are given below and each names the
  headline it is about. Open the comment with them, verbatim, and reproduce the
  list unchanged. An objection is not a licence to edit the extraction: the
  entries named are the ones to look at before anything is filed.|]

-- | The arm where the judgment declined.
silentNote :: Text
silentNote =
  [wft|
  Outcome: UNJUDGED. The two independent seats were asked and did not answer, so
  this list is UNVERIFIED: nobody has checked that its entries are grounded in
  the source or that none is a step of another. Say so in the comment, before
  anything else, and do not substitute your own reading of the source for the
  judgment that did not happen.|]

-- ---------------------------------------------------------------------------
-- The artefact every ending writes through
-- ---------------------------------------------------------------------------

-- | One act, eight provenance lines, one artefact.
--
-- Two parameters, provenance first, for 'Workflows.Report.reportFn''s reason. It
-- is the only thing the eight endings of this module differ in, which is exactly
-- when a shared function is right.
orgReportFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
orgReportFn =
  function
    "org.write"
    ( takes @"provenance" Text
        . takes @"entries" Text
        $ noParams
    )
    \provenance entries -> W.do
      act reporter [wf|
          {orgWriteBrief}

          Provenance:

          {provenance}

          The Org-mode:

          {entries}|]
      done

-- | The table 'orgProgram' hands @'Agentic.Workflow.defining'@.
orgTable :: [SomeFn]
orgTable = [SomeFn orgReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | Two rungs, eight endings, one artefact function.
--
-- The rungs take different inputs, which is what a rung may do: @breakdown@ takes
-- the one task and its optional context, and @infer@ takes the unstructured text.
-- @ci\/workflows.sh@ names each row's own inputs, and @wf plan@ prints them.
orgProgram :: OrgRung -> Parameterized
orgProgram Breakdown =
  taking (input "task" :> input "context" :> noInputs) \task context ->
    defining orgTable W.do
      -- The analysis, which in the corpus is a thing a model is told to do and
      -- then not show. Here it is a handle, and the decomposition reads it.
      analysis <- ask (broad (model "task-analysis")) [wf|
          {analysisBrief}

          The task:

          {task}

          The context, which may be empty -- and empty means the task stands on
          its own. Use it to make the subtasks specific, and do not turn a
          context item into a subtask unless completing the parent requires it:

          {context}|]

      -- The three special cases, decided over the analysis for zero questions,
      -- before the decomposition is paid for.
      atomic <- tested atomicTask analysis

      if atomic
        then W.do
          call_ orgReportFn (arg atomicNote :> arg task :> noArgs)
          stop
        else W.do
          ambiguous <- tested ambiguousTask analysis

          if ambiguous
            then W.do
              call_ orgReportFn (arg ambiguousNote :> arg analysis :> noArgs)
              stop
            else W.do
              thin <- tested noExpertise analysis

              if thin
                then W.do
                  -- The decomposition still happens; what changes is what it is
                  -- told and what the report says about it.
                  subtasks <- ask (reasoning (model "decompose")) [wf|
                      {decomposeBrief}

                      {noExpertiseGuidance}

                      The analysis:

                      {analysis}

                      The task:

                      {task}|]
                  call_ orgReportFn (arg noExpertiseNote :> arg subtasks :> noArgs)
                  stop
                else W.do
                  subtasks <- ask (reasoning (model "decompose")) [wf|
                      {decomposeBrief}

                      The analysis:

                      {analysis}

                      The task:

                      {task}|]

                  -- The completeness gate, on a party the decomposer did not
                  -- use.
                  whole <- confirm (lateral (model "completeness")) [wf|
                      {completenessBrief}

                      The parent task:

                      {task}

                      The subtasks:

                      {subtasks}|]

                  if whole
                    then W.do
                      call_ orgReportFn (arg exhaustiveNote :> arg subtasks :> noArgs)
                      stop
                    else W.do
                      call_ orgReportFn (arg incompleteNote :> arg subtasks :> noArgs)
                      stop
orgProgram Infer =
  taking (input "text" :> noInputs) \source ->
    defining orgTable W.do
      tasks <- ask (broad (model "extract")) [wf|
          {inferBrief}

          The text:

          {source}|]

      -- The sentinel the corpus writes and never reads.
      nothing <- tested noTasksFound tasks

      if nothing
        then W.do
          call_ orgReportFn (arg nothingFoundNote :> arg tasks :> noArgs)
          stop
        else W.do
          -- The one mechanical rule of thirteen that a decider can decide, and
          -- the one that matters most.
          nested <- tested nestedHeadline tasks

          if nested
            then W.do
              call_ orgReportFn (arg nestedNote :> arg tasks :> noArgs)
              stop
            else W.do
              -- A second party checks the first: two judgments, one verdict.
              judged <- panel (asksOver judgmentRoster (judgmentClosing source) tasks)

              caseVerdict
                judged
                ( W.do
                    call_ orgReportFn (arg groundedNote :> arg tasks :> noArgs)
                    stop
                )
                ( W.do
                    call_ orgReportFn (arg objectedNote :> arg tasks :> noArgs)
                    stop
                )
                ( W.do
                    call_ orgReportFn (arg silentNote :> arg tasks :> noArgs)
                    stop
                )

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the analysis opens with 'analysisBrief', the
-- decomposition with 'decomposeBrief', the extraction with 'inferBrief', and
-- each judgment seat with its own 'Workflows.Panels.lensBrief'.
--
-- __The steering rows are the first two.__ At @org-tasks-breakdown@ the analysis
-- answers @[PROCEED]@ on its last line, so none of the three special-case
-- deciders fires and the run walks the arm that decomposes and is checked; change
-- that last line to @[ATOMIC]@, @[AMBIGUOUS: …]@ or @[NO-EXPERTISE]@ and the run
-- rehearses each of the other three, one edit apiece. At @org-tasks-infer@ the
-- extraction answers with four flat headlines at one star, so neither free
-- decider fires and the two judgment seats are reached.
--
-- __The judgment seats need no rows, and writing them would have been a bug.__
-- @'Agentic.Exec.scriptedDefault'@ answers a verdict @APPROVE@, so both seats
-- approve and the run ends in the grounded arm — which is the arm an operator
-- wants rehearsed, and is "Workflows.Notes"' arrangement for its checkpoint panel
-- exactly. A row answering @\"APPROVE -- checked …\"@ would /not/ have approved:
-- @Agentic.Text@ reads a verdict answer that carries the word AND a sentence as
-- an __objection carrying both__ ("Workflows.Effort" says so at its own
-- assessment row), so the table would have rehearsed the objecting arm while
-- claiming the grounded one. The objecting and declining arms are reached by
-- adding one row whose answer is @\"OBJECTION: …\"@ or empty.
--
-- __The decomposition's row serves both of its call sites__, which is deliberate:
-- the @[NO-EXPERTISE]@ arm's prompt opens with the same 'decomposeBrief' and
-- differs only after it, so one canned answer covers the two — and the /arm/ is
-- chosen by the analysis row above, which is where it should be chosen.
orgScript :: OrgRung -> [(Text, Text)]
orgScript Breakdown =
  [ (analysisBrief, analysed),
    (decomposeBrief, decomposed)
  ]
  where
    analysed =
      [wft|
      Understanding: the goal is a working Elsa static-analysis setup for this
      project's Emacs Lisp, integrated into the ordinary edit loop. "Done" is
      Elsa running over the whole codebase and its findings triaged.
      Scope: setup plus configuration; two natural phases, install and
      integrate. Depends on a working package manager.
      Hidden requirements: type annotations on the critical functions, and a
      configuration file the project does not have.
      Ordering: install before configure before integrate; the CI step depends
      on the configuration existing.
      Completeness: research, setup, configuration, integration, documentation
      are all needed; testing is the run over the codebase.
      [PROCEED]|]

    decomposed =
      [wft|
      **** TODO Research Elsa capabilities and architecture
      **** TODO Review Elsa type annotation syntax
      **** TODO Install Elsa via package manager
      **** TODO Configure Elsa rules for project conventions
      **** TODO Integrate Elsa with flycheck for real-time analysis
      **** TODO Run Elsa over entire codebase and triage findings
      **** TODO Document Elsa setup and configuration decisions|]
orgScript Infer = [(inferBrief, extracted)]
  where
    extracted =
      [wft|
      * TODO Set up Prometheus on new cluster
      * TASK Write Grafana dashboard configurations        :Ben:
      * TODO Review alerting rules with full team
      * TODO Update runbook with new endpoints|]
