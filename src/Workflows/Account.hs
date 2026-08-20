-- |
-- Module      : Workflows.Account
-- Description : The four accounts of a run — halt, sitrep, report, narrative —
--               over receipts, and one artefact function.
--
-- == The map: old Markdown -> new program
--
-- +---------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@       | here                                                      |
-- +=================================+===========================================================+
-- | @commands\/halt.md@             | @account-halt@ — its four numbered steps, in order:        |
-- |                                 | @call_ journalFn@, @call_ commitFn@, the push, the report  |
-- |                                 | panel, and one act writing to @~\/dl@                     |
-- +---------------------------------+-----------------------------------------------------------+
-- | @commands\/sitrep.md@           | @account-sitrep@ — eight sections over a receipt-backed    |
-- |                                 | dossier, and the filename scheme computed here             |
-- +---------------------------------+-----------------------------------------------------------+
-- | @commands\/report.md@           | @account-report@ — seven categories as seven panel members, |
-- |                                 | and the estimate as a separate question on another engine   |
-- +---------------------------------+-----------------------------------------------------------+
-- | @commands\/narrative.md@        | @account-narrative@ — __reworked__: a receipt dossier, a    |
-- |                                 | chronology over it, a writer over that, and a sourcing gate |
-- +---------------------------------+-----------------------------------------------------------+
-- | @commands\/journal.md@          | 'journalFn', called by @account-halt@ and read as a receipt |
-- |                                 | by @account-narrative@                                     |
-- +---------------------------------+-----------------------------------------------------------+
-- | @skills\/it-voice\/SKILL.md@    | 'Workflows.Rubrics.Voice.itVoice', which is the register    |
-- |                                 | @narrative.md@'s own style standard asks for                |
-- +---------------------------------+-----------------------------------------------------------+
-- | @commands\/commit.md@           | @'Workflows.Git.Commit.commitFn'@, called                   |
-- +---------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The rework, discharged: @narrative.md@
--
-- @doc\/design.md@ §8 says to do the seven reworks before wave 3, and this is
-- one of them. §7.2 row 35 states the defect and the fix in one sentence:
-- \"evidence-gathering and writing are one undifferentiated ask, so the model
-- deciding what is true decides what reads well. Split into a receipt dossier
-- and a writer over it; \'distinguish fact from inference\' becomes a sourcing
-- gate on another engine.\"
--
-- Landed exactly so, and the three parts are three questions on three rungs:
--
--   1. the __dossier__ — the journal, the branch's log, the diff and the working
--      tree, four receipts, bound once and spliced into everything after;
--   2. the __chronology__ — a @'Workflows.Parties.broad'@ reading whose whole job
--      is to say what happened, in order, with every claim carrying the receipt
--      it came from;
--   3. the __narrative__ — a @'Workflows.Parties.reasoning'@ writer over the
--      chronology and nothing else, in
--      'Workflows.Rubrics.Voice.itVoice''s register;
--
-- and then the gate: a @'Workflows.Parties.lateral'@ party, pinned to a primary
-- neither of the two used, is given the draft __and__ the dossier and asked
-- whether every claim in the prose is carried by the evidence. Its answer is a
-- verdict, so @'Agentic.Workflow.caseVerdict'@ has three arms the compiler makes
-- the author write, and the artefact carries a different provenance line in each.
-- @narrative.md@'s \"distinguish fact from inference\" is that gate; in the
-- corpus it is a bullet in a style list, addressed to the writer.
--
-- == The leveling-up, item by item
--
--   1. __\"Write from the current state of the project, not from memory alone\"
--      is structural.__ That is @sitrep.md@'s own sentence, and it is an
--      instruction to a model about its own epistemics. Here every account is
--      built over a dossier of command receipts, bound before the first section
--      is asked and spliced into all of them by
--      'Workflows.Panels.withEvidence' — whose closing sentence is that a
--      receipt outranks a reading.
--
--   2. __@Measurements@ cannot invent a number.__ §7.2 row 61's own clause. The
--      section is one member of a panel handed the same receipts as its siblings,
--      and its rubric carries @sitrep.md@'s rule verbatim: a measurement that has
--      not been taken is /said/ to be untaken. The receipts are what make that
--      answerable rather than aspirational.
--
--   3. __Seven categories cannot be silently dropped.__ @report.md@ names them in
--      one sentence — \"open questions, design work, implementation work, testing
--      and verification work, documentation and commenting, cleanup, and review
--      tasks\" — and a sentence has no arity. 'reportRoster' is a list the fold is
--      built from and the fold's labels are its members' names, so a missing
--      category is a missing block.
--
--   4. __The estimate is somebody else's question.__ @report.md@ asks for a
--      time estimate \"based on how long things have taken up to this point\" in
--      the same breath as the roadmap, from the same writer. §7.2 row 52 splits
--      them: here the estimate is one question, on a
--      @'Workflows.Parties.lateral'@ party, over the /fold/ and over the
--      receipts — so the party that estimated the remaining work is not the party
--      that decided what it consists of.
--
--   5. __The filename scheme is computed here.__ @sitrep.md@'s
--      @YYYYMMDDTHHMM-SITREP-$PROJECT-$BRANCH.md@ is a scheme with two shell
--      variables nobody sets. 'sitrepDestination' is one Haskell-authored line,
--      and the two values it names are receipts in the document beside it —
--      @git rev-parse --show-toplevel@ and @git rev-parse --abbrev-ref HEAD@ —
--      so the artefact's name cannot drift from the run that wrote it.
--
--   6. __@halt.md@'s emitted @fess@ instruction is a hole, not a hope.__ §7.2
--      row 24: \"a define spliced by one hole — a program authoring a prompt,
--      where the boundary is a hole rather than a hope\". 'fessInstruction' is
--      that define, and it enters the artefact through
--      'accountWriteFn''s @addendum@ parameter: one hole, in one prompt, whose
--      surrounding text is this program's and whose content is this program's
--      too. What the corpus does instead is tell one agent to tell another agent
--      something, in prose, and hope the sentence survives.
--
--   7. __@halt.md@'s step 2 is checked.__ \"Commit all outstanding work … then
--      push it\" is a postcondition, and like @bankruptcy.md@'s it is stated and
--      never tested. Here the working tree is read again /after/ the commit and
--      the push, and 'Workflows.Deciders.treeDirty' decides it for zero
--      questions: the arm where something is still uncommitted says so, and does
--      not describe the session as cleanly stopped.
--
-- == One honest note
--
-- __@journal.md@ stays a function and not a row, and @doc\/design.md@ §7.1 row 30
-- is why__: \"its value is editorial taste, and its one mechanical rule
-- (append-only) is better enforced by the filesystem. Worth being @journalFn@,
-- called from @account@; not worth a program.\" It has one call site
-- (@account-halt@) and one reader (@account-narrative@, which takes the journal
-- as a @cat@ receipt), which is exactly the two things that row asks for.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Account
  ( -- * The kinds
    AccountKind (..),
    accountName,
    accountDoc,

    -- * The program
    accountProgram,
    accountScript,

    -- * The two rosters
    reportRoster,
    reportCategories,
    sitrepRoster,
    sitrepSections,

    -- * The dossier each kind reads
    accountDossier,

    -- * The functions
    journalFn,
    accountWriteFn,
    narrativeWriteFn,
    accountTable,

    -- * The one prompt this program authors for somebody else
    fessInstruction,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Git.Commit (commitFn)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The kinds
-- ---------------------------------------------------------------------------

-- | The four accounts the owner asks a run to give of itself.
--
-- They are four rows and not one with a flag because they differ in every
-- thing a row should differ in: which receipts are collected, which roster reads
-- them, whether anything is committed, and what it costs.
data AccountKind
  = -- | @commands\/halt.md@ — stop cleanly, and leave the next session
    -- everything it needs.
    Halt
  | -- | @commands\/sitrep.md@ — where the work stands, for a human reviewer
    -- deciding what to do with compute and attention.
    Sitrep
  | -- | @commands\/report.md@ — what remains, phase by phase, with an estimate.
    Report
  | -- | @commands\/narrative.md@ — the story of the work, for a reader.
    Narrative
  deriving (Eq, Show)

-- | The name the operator types.
--
-- Family first and the owner's own word as the suffix, which is
-- "Workflows.Git.Commit"'s rule: @wf list@ then sorts the four by the thing he
-- is choosing between, with the price of each beside it. There is no bare
-- @account@ row, because none of the four is the default — the effort ladder
-- made the same choice for the same reason.
accountName :: AccountKind -> Text
accountName Halt = "account-halt"
accountName Sitrep = "account-sitrep"
accountName Report = "account-report"
accountName Narrative = "account-narrative"

-- | The one line @wf list@ prints beside a kind.
accountDoc :: AccountKind -> Text
accountDoc Halt =
  "halt.md: journal, `commitFn`, push, the remaining-scope panel, and a handoff written to ~/dl"
accountDoc Sitrep =
  "sitrep.md: eight sections over four command receipts, and the filename scheme computed in Haskell"
accountDoc Report =
  "report.md: seven categories as seven panel members, and the estimate on a different engine"
accountDoc Narrative =
  "narrative.md: a receipt dossier, a chronology, a writer over it, and a sourcing gate elsewhere"

-- ---------------------------------------------------------------------------
-- The dossier each kind reads
-- ---------------------------------------------------------------------------

-- | The receipts a kind collects, as @(block label, argv)@.
--
-- __The whole of @sitrep.md@'s \"first gather evidence\" section, and
-- @narrative.md@'s.__ Both files list what to read — the working tree, the
-- recent history, the diffs, the journal — as instructions to a model that may
-- or may not run them and may or may not report faithfully on what came back.
-- Here each is an argv in "Workflows.Evidence", run by "Agentic.Shell" with
-- @proc@, and what the panel reads is bytes the answering model did not write.
--
-- The journal is the one row whose /path/ is an operator's: it is
-- @narrative.md@'s \"read the journal file named in the request\", and an absent
-- input becomes a name no file has (see 'journalFile'), so
-- @wf plan account-narrative --raw@ prints the omission.
accountDossier :: AccountKind -> Text -> [(Text, Party 'IsTool)]
accountDossier Halt _ = [("tree", gitStatus), ("series", gitLogSeries trunk)]
accountDossier Sitrep _ =
  [ ("tree", gitStatus),
    ("series", gitLogSeries trunk),
    ("branch", gitBranch),
    ("project", gitRevParse "--show-toplevel")
  ]
accountDossier Report _ = [("tree", gitStatus), ("series", gitLogSeries trunk)]
accountDossier Narrative journal =
  [ ("journal", fileContents (journalFile journal)),
    ("series", gitLogSeries trunk),
    ("diff", gitDiff []),
    ("tree", gitStatus)
  ]

-- | The trunk every account measures its history against.
--
-- @sitrep.md@ and @narrative.md@ both say \"recent commits\" and neither says
-- from where. This is 'Workflows.Git.Commit''s answer to the same silence.
trunk :: Text
trunk = "main"

-- | The journal file @account-narrative@ reads, and the one place an absent
-- input is given a meaning.
--
-- __Tier 1__: 'Workflows.Checklist.checklistFile''s rule, and
-- @narrative.md@'s own escalation is what makes it right here — that file says
-- \"if there is no clear candidate, ask for the journal path before writing the
-- narrative\", and a @cat@ of a name no file has abandons the run with exactly
-- that complaint rather than searching the tree for something plausible.
journalFile :: Text -> Text
journalFile p
  | T.null (T.strip p) = "<no journal file given>"
  | otherwise = T.strip p

-- ---------------------------------------------------------------------------
-- The seven categories of report.md
-- ---------------------------------------------------------------------------

-- | @commands\/report.md@'s one sentence, as seven rows.
--
-- /Source:/ \"call out the remaining open questions, design work,
-- implementation work, testing and verification work, documentation and
-- commenting, cleanup, and review tasks\" — seven categories, in the file's own
-- order, each given the paragraph the file implies and never writes.
reportCategories :: [(Text, Text, Text)]
reportCategories =
  [ ( "open-questions",
      "the decisions nobody has made yet, and what each one blocks",
      "List the questions that are still open -- design decisions not taken, \
      \unknowns not resolved, external answers not received. For each: what it \
      \blocks, what would settle it, and who or what has to settle it. A \
      \question with no blocked work is not open, it is idle; say so and move \
      \on."
    ),
    ( "design",
      "the design work still to be done, phase by phase",
      "List the design work that remains: what has to be decided or specified \
      \before implementation can proceed, in the order it has to happen. Name \
      \the artefact each piece produces -- a specification, a schema, an \
      \interface -- and what depends on it."
    ),
    ( "implementation",
      "the implementation work, ordered so each phase stands on the last",
      "List the implementation work that remains, as an ordered plan of phases. \
      \Each phase names the files or components it touches, what it makes \
      \possible, and what it needs to be in place first. A phase whose \
      \predecessor is not named is a phase in the wrong place."
    ),
    ( "testing",
      "the testing and verification work, and what each test would prove",
      "List the testing and verification work that remains. For each item: what \
      \it would prove, what it would run against, and what its passing would \
      \allow the project to stop worrying about. Distinguish tests that do not \
      \exist from tests that exist and do not yet pass."
    ),
    ( "documentation",
      "the documentation and commenting work, and its audience",
      "List the documentation and commenting work that remains, naming the \
      \reader of each piece: a future maintainer, an operator, a reviewer. \
      \Include the comments that are now wrong as well as the ones that are \
      \missing -- a stale comment is a documentation defect, not a cosmetic one."
    ),
    ( "cleanup",
      "the cleanup: dead code, scaffolding, temporary shapes",
      "List the cleanup that remains: scaffolding that was always temporary, \
      \code that is now dead, duplicated shapes that were tolerated to get \
      \moving, names that no longer describe what they name. Say for each what \
      \makes it safe to remove now, or what would have to be true first."
    ),
    ( "review",
      "the review tasks, and who has to do each",
      "List the review work that remains: what has to be read by whom before it \
      \can be relied on, and what each reviewer is being asked to judge. A \
      \review with no question is a formality; name the question."
    )
  ]

-- | The seven categories, as the roster the fold is built from.
--
-- Six read wide and go to 'Workflows.Parties.broad'; @implementation@ is the one
-- that has to hold an order in its head and goes to
-- 'Workflows.Parties.reasoning'. The category's own paragraph opens each brief,
-- so the seven do not share a leading chunk — which is
-- 'Workflows.Notes.sectionRoster''s rule and what lets a scripted table tell
-- them apart.
reportRoster :: Roster
reportRoster =
  [ Lens
      { lensName = n,
        lensOwns = owns,
        lensBrief = brief,
        lensParty = rungFor n (model ("report-" <> n))
      }
  | (n, owns, brief) <- reportCategories
  ]
  where
    rungFor n
      | n == "implementation" = reasoning
      | otherwise = broad

-- ---------------------------------------------------------------------------
-- The eight sections of sitrep.md
-- ---------------------------------------------------------------------------

-- | @commands\/sitrep.md@'s eight @##@ sections, in its own order.
--
-- /Source:/ the file, section by section, with each section's own paragraph
-- carried close to verbatim — it is the most concrete section specification in
-- the corpus after @restack.md@'s step 9, and the concreteness is the value.
sitrepSections :: [(Text, Text, Text)]
sitrepSections =
  [ ( "aim",
      "the full objective the run is presently trying to accomplish",
      "Restate the full objective, and name its source where the evidence shows \
      \one -- a user request, an issue, a pull request, a handoff, a plan. Do \
      \NOT shrink the aim to the work already completed: an aim narrowed to fit \
      \the progress is the one error this section exists to prevent."
    ),
    ( "accomplishments",
      "what has been accomplished, with the artefacts that prove it",
      "Give a full accounting of what has been accomplished so far, naming the \
      \concrete artefacts that prove the work moved: files, commits, tests, \
      \documents, runtime changes. Distinguish completed work from work that is \
      \merely started, and both from work you are inferring happened."
    ),
    ( "next-steps",
      "the next actions, in the order they should be taken",
      "List the next actions in the order they should be taken, specific enough \
      \that another agent could resume from this report without rediscovering \
      \anything. A step that assumes context this report does not carry is not \
      \a step."
    ),
    ( "blockers",
      "what is preventing, slowing or endangering progress",
      "Call out anything preventing progress, slowing it, or carrying material \
      \risk. Separate hard blockers from ordinary uncertainty, technical debt, \
      \flaky signals, missing context, environmental failures, reviewer \
      \decisions and unverified assumptions -- they are seven different things \
      \and collapsing them is how a report reads as calmer than the work is."
    ),
    ( "measurements",
      "the measurements that show progress, and the ones not taken",
      "Report the recent measurements that best show progress toward the goal, \
      \and name the command, artefact or observation that produced each. Take \
      \them from the receipts below and from nowhere else. If a measurement \
      \would be useful but has not been taken, say so plainly rather than \
      \inventing one, and say what would have to be run to take it. A number \
      \that no command in the evidence produced does not go in this section at \
      \all."
    ),
    ( "distance",
      "how far the goal is, in time and effort, with the assumptions named",
      "Estimate how far away the goal is in both time and effort, as a range \
      \wherever the uncertainty is material. State the assumptions the estimate \
      \rests on: remaining task count, known unknowns, expected verification \
      \cost, external dependencies, review time, computational cost."
    ),
    ( "parallel",
      "the work that could safely proceed alongside the current path",
      "Identify upcoming work that could be done in parallel without disrupting \
      \the current path. For each: why it is safe to parallelize, what inputs it \
      \needs, what output it should produce, and what conflicts or coordination \
      \risks to watch. If nothing should be parallelized yet, say that, and name \
      \the dependency that has to be resolved first."
    ),
    ( "recommendation",
      "the one thing the reviewer should do next",
      "End with a short recommendation for the reviewer: continue with the \
      \current agent, allocate another agent to a named parallel task, pause for \
      \a decision, run a specific verification step, or change course. Base it \
      \on the evidence above and on nothing else, and say which part of the \
      \evidence decides it."
    )
  ]

-- | The eight sections, as the roster the fold is built from.
--
-- @distance@ and @recommendation@ are judgments over everything else and go to
-- 'Workflows.Parties.reasoning'; the other six read wide and go to
-- 'Workflows.Parties.broad'.
sitrepRoster :: Roster
sitrepRoster =
  [ Lens
      { lensName = n,
        lensOwns = owns,
        lensBrief = brief,
        lensParty = rungFor n (model ("sitrep-" <> n))
      }
  | (n, owns, brief) <- sitrepSections
  ]
  where
    rungFor n
      | n `elem` ["distance", "recommendation"] = reasoning
      | otherwise = broad

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What each dossier row's question asks for.
--
-- /Source:/ @sitrep.md@'s \"inspect the working tree and recent history as
-- appropriate\" and @narrative.md@'s \"do not rely on commit messages alone\",
-- which are the same instruction addressed to a model. Here the commands are the
-- argv and this is only what the receipt is introduced as.
dossierBrief :: Text
dossierBrief =
  wfText
    [wf|
    Run and report. This is a receipt: whatever the command writes is the
    answer, and nothing is added to it.|]

-- | What every section is told about the shape of its block.
--
-- The operator's scope rides in here rather than in a hole, because it is a
-- program /input/ and an input is ordinary 'Data.Text.Text' at this layer: the
-- closing is computed once, in Haskell, and every member of the fan-out is
-- handed the same one. That is tier 1 and it costs nothing.
sectionClosing :: Text -> Text
sectionClosing scope =
  wfText
    [wf|
    Write your section and nothing else. Your answer is one block of a document
    whose other blocks are the other sections', each fenced under its own name:
    do not write theirs, do not summarise the document, and do not add a heading
    of your own above your content -- the fold supplies your name.

    Keep it direct and useful, and prefer concrete status to narrative colour.
    Do not hide weak evidence, a missing measurement or an optimistic estimate
    behind polished prose.

    What the operator said this account is about, which may be empty -- and
    empty means the evidence below is the whole of the scope:

    {scope}|]

-- | @commands\/report.md@'s estimate, as its own question on its own engine.
--
-- /Source:/ its second paragraph — \"a fairly decent idea of how much time it
-- may take us to complete it, based on how long things have taken up to this
-- point, and how many unknowns yet remained\" — which is a request for an
-- estimate /grounded in the history/, and is therefore a question about the
-- receipts as much as about the plan.
estimateBrief :: Text
estimateBrief =
  wfText
    [wf|
    You are estimating work you did not plan. Below is a remaining-scope
    document, one block per category, and the command receipts it was drawn
    from.

    Give the estimate: how long the remaining work is likely to take, as a range
    where the uncertainty is material, and how much of it is elapsed time rather
    than effort. Ground it in the receipts -- the commit series shows how long
    what has been done actually took -- and say which comparison you used.

    Then name what could move it: the count of open questions, the unknowns not
    yet thought through, the verification cost, and anything in the document
    whose size you cannot judge from the evidence. An estimate whose assumptions
    are not stated is a number somebody will quote without them.

    Do not re-plan the work, do not add a category, and do not correct the
    document. If a block is missing or empty, say so in one line first.|]

-- | @commands\/narrative.md@'s evidence half.
--
-- /Source:/ its \"recommended working method\" steps 1 and 2 — establish the
-- scope, then \"build a compact chronology from the journal, commits, diffs and
-- handoff material; identify the few moments that changed the agent's
-- understanding\". In the corpus that is the first half of one long ask whose
-- second half is the prose; here it is its own question, and its answer is what
-- the writer is given instead of the receipts.
chronologyBrief :: Text
chronologyBrief =
  wfText
    [wf|
    Build the chronology, and nothing else. You are not writing the narrative:
    you are establishing what happened, in order, so that somebody else can.

    From the receipts below -- the journal, the commit series, the diff and the
    working tree -- produce:

    - the sequence of events, oldest first, one line each, with the receipt each
      line comes from named in brackets at its end;
    - the few moments where the understanding changed: a constraint discovered,
      an assumption falsified, a design corrected. These are the ones worth
      finding, and there are usually three or four;
    - the durable themes: constraints found, principles clarified, mistakes
      corrected, verification lessons;
    - what the evidence does NOT show, listed plainly.

    Every line is either carried by a receipt or is in the last list. Do not
    smooth a gap, do not infer a motive, and do not promote a commit message
    into a decision: a message says what somebody wrote, not what they knew.|]

-- | @commands\/narrative.md@'s prose half.
--
-- /Source:/ its opening paragraph and its step 4 shape, with the register
-- supplied by 'Workflows.Rubrics.Voice.itVoice' — which is what that file's own
-- @Style standard@ block is, said once, in the place three commands share it.
--
-- __What is dropped, and why.__ The instruction to study
-- @~\/work\/positron\/it-plan.pdf@ \"if it is readable in the current
-- environment\" is not carried: it is a conditional read of a file outside the
-- repository, and the standard it teaches is the register above. The corpus's own
-- fallback sentence — \"if the PDF is unavailable, apply the embedded style
-- standard below\" — is the acknowledgement that the define was always the real
-- source.
narrativeBrief :: Text
narrativeBrief =
  wfText
    [wf|
    Write the development narrative. Below is a chronology of the work, built
    from command receipts by somebody else; it is your whole source.

    Tell the story of the work: what problem was being solved, what had to be
    discovered, where the path was harder than it first appeared, how those
    difficulties were overcome, which principles emerged, and what understanding
    the finished work now preserves. It must not read like a changelog, a commit
    summary or a postmortem, and it must not drown a thoughtful reader in
    implementation detail.

    A useful shape, adjusted to the material: Title; Purpose; How the Work
    Unfolded; What Had to Be Learned; How the Difficulties Were Resolved;
    Principles Preserved; Where the Work Now Stands. Begin with the purpose and
    the governing principles, and let the practical consequences follow from
    them. Use transitions that show how one discovery led to the next.

    End with a short source note naming the journal, the commit range, the
    working-tree state and any planning documents the chronology drew on. Keep
    it factual and compact.

    Every claim you make must be carried by a line of the chronology. Where the
    chronology says the evidence does not show something, either leave the claim
    out or phrase it as an interpretation and say what it rests on. Somebody who
    did not write this will check that, against the receipts, before it is
    filed.

    {register}|]
  where
    register = itVoice

-- | The sourcing gate — @narrative.md@'s \"distinguish fact from inference\",
-- asked of somebody who did not write the prose.
--
-- /Source:/ that bullet, plus @doc\/design.md@ §7.2 row 35's ruling that it
-- becomes \"a sourcing gate on another engine\". The register half of the same
-- check is 'Workflows.Rubrics.Voice.itVoiceSelfCheck', which is spliced here for
-- the reason that module's haddock gives: a draft's own author is the worst
-- reader of whether it opened with a forbidden opening.
sourcingBrief :: Text
sourcingBrief =
  wfText
    [wf|
    You are auditing a narrative you did not write, against the receipts it was
    supposed to be drawn from. You are not improving it and not rewriting it.

    Take its claims one at a time. For each, find the receipt that carries it.
    Object if a claim has no source in the evidence; object if a claim is
    presented as fact where the evidence supports only an interpretation; object
    if a difficulty, a decision or an outcome appears that the receipts do not
    show. Quote the sentence in every objection -- an objection without a
    quotation is not actionable by whoever has to fix it.

    Self-congratulation, marketing language, theatrical language and false drama
    are also objections: this register does not permit them, and a narrative that
    reaches for them is usually covering a claim it cannot source.

    {selfCheck}|]
  where
    selfCheck = itVoiceSelfCheck

-- | @commands\/journal.md@, whole.
--
-- /Source:/ the file, compressed to its preface contract, its append-only rule,
-- its tag vocabulary and its entry shape. What is dropped is its closing
-- paragraph about re-reading the command after a context compaction: that is
-- advice to a harness about its own session handling, and a program that is
-- itself the durable plan has no referent for it.
journalBrief :: Text
journalBrief =
  wfText
    [wf|
    Create or continue the learning journal for this work, as a Markdown file in
    the current project -- preferably beside the task's handoff or planning
    document where one exists. If you create it, say where.

    The journal is not a task list, a handoff, a scratchpad, a transcript or a
    command log. It exists to preserve the learning that happened while solving
    a real problem: discoveries, design shifts, constraints, failures that
    taught something durable, implementation principles, research findings, and
    the moments where the system proved too general, too specific, or shaped
    differently than expected.

    On a new journal, write a brief preface first, defining: the scope of the
    work being observed; what kinds of entries are valuable for it; the tag
    vocabulary to use; and the rule that entries are append-only and timestamped.

    APPEND ONLY. Add entries at the end of the file and never back-edit an
    existing one. Where earlier understanding turned out to be wrong, append a
    new entry stating the correction and what changed. Keep a blank line between
    entries.

    Begin every entry with an absolute timestamp, including the timezone where
    it is known, and tag it with one or more concise area tags in square
    brackets -- fitted to this project, such as [api], [cli], [data], [design],
    [docs], [runtime], [tests], [verification], or a local subsystem name.

    Each entry captures, compactly: what was discovered; what evidence or
    failure exposed it; what changed in the implementation, the plan or the
    mental model; and why it may matter for similar work later.

    Do not journal a routine step, a passing test, a command or a transient
    thought. Prefer the gems: the hard-won constraints, the surprising
    couplings, the principles, the war stories. When you are done, reply DONE.|]

-- | @commands\/halt.md@ step 2, as what this caller asks of the commit
-- decomposition.
haltCommitStyle :: Text
haltCommitStyle =
  wfText
    [wf|
    This series is being written so that a session can stop cleanly and be
    resumed in a fresh one, possibly on another machine. Nothing may be left
    uncommitted that the next session would need, and nothing half-finished may
    be committed in a state that does not build: where a change is genuinely
    unfinished, commit what stands on its own and say in the message what is
    missing.

    The last commit's message is the one the next session reads first. Write it
    as the summary of where the work stopped.|]

-- | What the push act is told.
pushBrief :: Text
pushBrief =
  "Push the branch. This is `halt`'s step 2 -- the work is being published so \
  \that a session on another machine can pick it up -- and the lease is what \
  \keeps the push from overwriting somebody else's work on the ref."

-- | The instruction @halt.md@ emits for the system that reads its handoff.
--
-- /Source:/ its step 3, verbatim in substance: \"instruct that the downstream
-- system run the @fess@ skill at the end of every subtask it performs\".
--
-- __This is the one place a program in this tree authors a prompt for somebody
-- else__, and @doc\/design.md@ §7.2 row 24 is why it is worth naming: in the
-- corpus the sentence is an instruction to an agent to include an instruction,
-- and whether it survives into the artefact is unknowable. Here it is a define,
-- it enters the artefact through 'accountWriteFn''s one @addendum@ hole, and the
-- text that lands in @~\/dl@ is text this module wrote.
--
-- The row it names is real: @fess@ is registered, and @wf cost fess@ prices it.
fessInstruction :: Text
fessInstruction =
  wfText
    [wf|
    Reproduce the following block verbatim in the document, under the heading
    `Standing instruction for the resuming system`. It is addressed to whatever
    system picks this work up, and it is not yours to reword, soften or
    summarise:

      At the end of EVERY subtask you perform against this plan, run the `fess`
      workflow over the work you have just done -- `wf run fess` with the
      request you were given and the base you started from -- and act on what it
      finds before starting the next subtask. Its job is to catch the things
      that are easy to report as done and hard to prove: a manufactured claim, a
      verification that did not happen, a fallback silently taken. A subtask
      whose audit you skipped is a subtask nobody has checked.|]

-- | @commands\/halt.md@ steps 3 and 4, as the artefact's own brief.
haltWriteBrief :: Text
haltWriteBrief =
  wfText
    [wf|
    Write the handoff and remaining-scope document to the `~/dl` directory --
    create it if it does not exist -- and NOT into the project or the current
    directory. Name it after the project and the date.

    Its job is stated in one line: a fresh session, on another machine, with
    none of this context, must be able to resume from this document alone.

    In this order: the provenance line you were given, verbatim; what is done;
    what remains, phase by phase, from the document below; how completion is to
    be verified for each phase; and exactly how to resume -- the branch, the
    commands, the first thing to read.

    Then reply DONE.|]

-- | @commands\/sitrep.md@'s destination and naming scheme.
--
-- /Source:/ the file's own paragraph, which is a scheme with two shell variables
-- and a substitution rule. The scheme is program text here; the two values it
-- names are receipts in the document beside it.
sitrepDestination :: Text
sitrepDestination =
  wfText
    [wf|
    Write the sitrep as a Markdown file in the `~/Documents/Obsidian` directory
    -- create it if it does not exist -- and NEVER into the project or the
    current directory.

    Its name follows this scheme exactly:

      YYYYMMDDTHHMM-SITREP-PROJECT-BRANCH.md

    where YYYYMMDDTHHMM is the local time now in that format; PROJECT is the
    basename of the repository path in the `project` receipt below; and BRANCH is
    the branch name in the `branch` receipt below, with every `/` replaced by
    `-`. Take both from the receipts and from nowhere else: a name assembled from
    memory is a name that does not match the run.|]

-- | Where @account-report@ writes.
--
-- /Source:/ @commands\/report.md@ asks for \"a Markdown report best suited for a
-- human reader who is familiar with the ideas and concepts in the project\" and
-- does not say where. It also asks for something this program can give it: \"I
-- may ask you to update this document in the future, so add any metadata tags
-- that might help you with such an update.\"
reportDestination :: Text
reportDestination =
  wfText
    [wf|
    Write the report as a Markdown file in the current directory, named
    `remaining-scope-<date>.md`.

    Open it with a metadata block -- the date, the branch, the commit at HEAD
    from the receipts, and the scope this account was given -- so that a later
    run asked to update this document can tell what it was written against.
    Write it for a reader who already knows the project's ideas and concepts: no
    introduction to the problem, no glossary, no recapitulation.|]

-- | Where @account-narrative@ writes.
narrativeDestination :: Text
narrativeDestination =
  "Write the narrative as a Markdown file in the current directory, named \
  \`narrative-<date>.md`."

-- | The brief every artefact is written through.
accountWriteBrief :: Text
accountWriteBrief =
  wfText
    [wf|
    You are writing an account of a run, and you are transcribing rather than
    composing: the blocks below were written by the parties that own them.

    Follow the destination instruction you were given exactly -- it names the
    directory, the naming scheme and where the name's parts come from.

    In this order: the provenance line, verbatim, first; then the document,
    block by block, under each block's own name as a heading; then the addendum,
    if one was given, at the end and under its own heading.

    Do not merge two blocks, do not reorder them, do not drop one because it is
    thin, and do not add a section of your own. Then reply DONE.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | @account-halt@, where the tree came back clean.
haltCleanNote :: Text
haltCleanNote =
  "Provenance: the journal was updated, the series was committed through the \
  \standing commit discipline and pushed, and the working tree was then re-read: \
  \`git status --porcelain` came back EMPTY, so nothing this session did is \
  \sitting uncommitted. The remaining-scope document below was written over \
  \command receipts. This session can be stopped."

-- | @account-halt@, where it did not.
--
-- /Source:/ the ending @halt.md@ cannot have. Its step 2 is a postcondition and
-- the file has no arm for its failing.
haltDirtyNote :: Text
haltDirtyNote =
  "Outcome: NOT CLEANLY STOPPED. The journal was updated and the commit and push \
  \steps ran, and the working tree was then re-read and is STILL DIRTY -- so \
  \something this session produced is not committed and will not be on the \
  \machine that resumes. Say that in the first line of the document, list what \
  \the tree still holds, and tell the resuming session to deal with it before \
  \anything else. Do not describe this session as cleanly stopped."

-- | @account-sitrep@'s one provenance line.
sitrepNote :: Text
sitrepNote =
  "Provenance: this sitrep was written over four command receipts -- the working \
  \tree, the commit series over the trunk, the branch name and the repository \
  \path -- each spliced into every section, so no section is describing a \
  \different state of the project. A measurement that no command here produced \
  \is not in this report; where one is missing, the Measurements section says so."

-- | @account-report@'s one provenance line.
reportNote :: Text
reportNote =
  "Provenance: the seven remaining-work categories were answered independently \
  \over the same two command receipts, and the estimate at the end was made by a \
  \different party over the fold -- so the party that estimated the remaining \
  \work is not the party that decided what it consists of. Neither read \
  \anything but the receipts."

-- | @account-narrative@, where the sourcing audit approved.
narrativeSourcedNote :: Text
narrativeSourcedNote =
  "Provenance: the chronology was built from four command receipts, the \
  \narrative was written from the chronology alone, and a third party -- pinned \
  \to a serving model neither of the other two used -- checked every claim in \
  \the prose against those receipts and approved. Fact and inference are \
  \separated because somebody who did not write the prose said so."

-- | @account-narrative@, where it objected.
narrativeObjectedNote :: Text
narrativeObjectedNote =
  "Provenance: the sourcing audit OBJECTED. Its objection lines are given below \
  \and they are about this narrative, not about the work. Open the document with \
  \them, verbatim, under the heading `Sourcing audit: objections`; leave the \
  \narrative as written -- an objection is not a licence to rewrite the prose it \
  \is about -- and do not describe this narrative as sourced."

-- | @account-narrative@, where it would not answer.
narrativeSilentNote :: Text
narrativeSilentNote =
  "Provenance: the sourcing audit was put to an independent party and it did not \
  \answer, so this narrative's claims are UNVERIFIED against the receipts. Say \
  \that in one sentence at the top, before anything else. Do not describe any \
  \claim below as sourced, and do not substitute your own reading of the \
  \evidence for the audit that did not happen."

-- | The addendum every kind but @halt@ passes.
noAddendum :: Text
noAddendum =
  "(No addendum: this kind of account carries no standing instruction for a \
  \downstream system. Write nothing under an addendum heading.)"

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | @commands\/journal.md@, as the function @doc\/design.md@ §7.1 row 30 says it
-- should be.
--
-- An @'Agentic.Workflow.act'@ and not an @ask@: it creates or appends to a file,
-- and an act at @'Agentic.Raw.CodeAck'@ is the only kind of answer the ACP
-- transport grants write authority to. The append-only rule is a sentence in the
-- brief and the filesystem is what enforces it — which is that row's own ruling.
journalFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
journalFn =
  function
    "account.journal"
    ( takes @"scope" Text
        . takes @"evidence" Text
        $ noParams
    )
    \scope evidence -> W.do
      act (tool "journal") [wf|
          {journalBrief}

          What this journal is observing, in the operator's own words. It may be
          empty, and empty means the evidence below is the scope:

          {scope}

          The evidence this session produced:

          {evidence}|]
      done

-- | One act, five provenance lines, four destinations, one hole for an addendum.
--
-- Four parameters, and the order is the one the body reads them in: where it
-- goes, how the run ended, what was written, and what this program is telling
-- somebody else.
--
-- __Why the destination is a parameter and not four functions.__ It is the only
-- thing that differs between @halt@, @sitrep@ and @report@'s artefacts, and
-- 'Workflows.Report.reportFn''s argument applies unchanged: two report functions
-- that differ in one string are two report functions that drift. The scheme
-- itself is program text — 'sitrepDestination' is the whole of @sitrep.md@'s
-- naming paragraph — so a run cannot invent a filename.
accountWriteFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText, 'CodeText] 'CodeAck
accountWriteFn =
  function
    "account.write"
    ( takes @"destination" Text
        . takes @"provenance" Text
        . takes @"document" Text
        . takes @"addendum" Text
        $ noParams
    )
    \destination provenance document addendum -> W.do
      act reporter [wf|
          {accountWriteBrief}

          Where it goes:

          {destination}

          Provenance:

          {provenance}

          The document:

          {document}

          The addendum:

          {addendum}|]
      done

-- | @account-narrative@'s artefact, which carries a __verdict__.
--
-- The middle parameter is a @'Agentic.Workflow.Verdict'@ and not a text for
-- 'Workflows.Notes.notesReportFn''s reason: a verdict interpolates into a
-- prompt, so the objecting arm splices the audit's own objection lines rather
-- than a paraphrase of them. That is why the sourcing gate is asked
-- @'Agentic.Workflow.answering' Verdict@ and not tested with a decider.
narrativeWriteFn :: Fn '[ 'CodeText, 'CodeVerdict, 'CodeText] 'CodeAck
narrativeWriteFn =
  function
    "account.narrative"
    ( takes @"provenance" Text
        . takes @"audit" Verdict
        . takes @"narrative" Text
        $ noParams
    )
    \provenance audit narrative -> W.do
      act reporter [wf|
          {accountWriteBrief}

          Where it goes:

          {destination}

          Provenance:

          {provenance}

          What the independent sourcing audit answered:

          {audit}

          The document:

          {narrative}

          The addendum:

          {addendum}|]
      done
  where
    destination = narrativeDestination
    addendum = noAddendum

-- | The table 'accountProgram' hands @'Agentic.Workflow.defining'@.
--
-- @commitFn@ is in it because @account-halt@ calls it, and a declared callee
-- nobody calls is noise in the printed program while a call to an undeclared one
-- is a type error — so the table is the same four entries for every kind, and the
-- kind decides which of them are reached.
accountTable :: [SomeFn]
accountTable =
  [ SomeFn journalFn,
    SomeFn commitFn,
    SomeFn accountWriteFn,
    SomeFn narrativeWriteFn
  ]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The four accounts, over receipts, ending in one artefact each.
--
-- Two inputs. @scope@ is what the operator says the account is about and may be
-- empty — it rides into every member's closing line, in Haskell, for zero
-- questions. @journal@ is the path @narrative.md@ names, and it is the argv of a
-- @cat@; the other three kinds do not read it, and @wf plan@ says so.
accountProgram :: AccountKind -> Parameterized
accountProgram kind =
  taking (input "scope" :> input "journal" :> noInputs) \scope journal ->
    let closing = sectionClosing scope
        dossier = accountDossier kind journal
     in defining accountTable case kind of
          Halt -> W.do
            -- The evidence, bound once: what the session is leaving behind.
            facts <- panelText [(label, ask p [wf|{dossierBrief}|]) | (label, p) <- dossier]

            -- Step 1. The journal, before anything is committed -- the learning
            -- is about the work, not about the commit.
            call_ journalFn (arg scope :> arg facts :> noArgs)

            -- Step 2, and the commit discipline is called rather than restated.
            call_ commitFn (arg scope :> arg haltCommitStyle :> noArgs)
            act gitPushLease [wf|{pushBrief}|]

            -- Step 3. The remaining-scope panel, over the same receipts.
            document <- panelText (zip (lensNames reportRoster) (asksOver reportRoster closing facts))

            -- Step 2's postcondition, tested: zero questions, one path.
            after <- ask gitStatus [wf|{afterBrief}|]
            dirty <- tested treeDirty after

            if dirty
              then W.do
                call_ accountWriteFn (arg haltWriteBrief :> arg haltDirtyNote :> arg document :> arg fessInstruction :> noArgs)
                stop
              else W.do
                call_ accountWriteFn (arg haltWriteBrief :> arg haltCleanNote :> arg document :> arg fessInstruction :> noArgs)
                stop
          Sitrep -> W.do
            facts <- panelText [(label, ask p [wf|{dossierBrief}|]) | (label, p) <- dossier]

            document <- panelText (zip (lensNames sitrepRoster) (asksOver sitrepRoster closing facts))

            call_ accountWriteFn (arg sitrepDestination :> arg sitrepNote :> arg document :> arg noAddendum :> noArgs)
            stop
          Report -> W.do
            facts <- panelText [(label, ask p [wf|{dossierBrief}|]) | (label, p) <- dossier]

            document <- panelText (zip (lensNames reportRoster) (asksOver reportRoster closing facts))

            -- The estimate: a different party, over the fold and the receipts.
            estimate <- ask (lateral (model "estimate")) [wf|
                {estimateBrief}

                The remaining-scope document:

                {document}

                The receipts it was drawn from:

                {facts}|]

            call_ accountWriteFn (arg reportDestination :> arg reportNote :> arg document :> arg estimate :> noArgs)
            stop
          Narrative -> W.do
            facts <- panelText [(label, ask p [wf|{dossierBrief}|]) | (label, p) <- dossier]

            -- The rework, part 1: what happened, with every line sourced.
            chronology <- ask (broad (model "chronology")) [wf|
                {chronologyBrief}

                The receipts:

                {facts}|]

            -- Part 2: the prose, over the chronology and nothing else.
            draft <- ask (reasoning (model "narrative")) [wf|
                {narrativeBrief}

                The chronology:

                {chronology}|]

            -- Part 3: the gate, on a party neither of the two used, over the
            -- draft AND the receipts.
            audit <-
              ask (lateral (model "sourcing")) [wf|
                  {sourcingBrief}

                  The narrative:

                  {draft}

                  The receipts it was supposed to be drawn from:

                  {facts}|]
                `answering` Verdict

            caseVerdict
              audit
              ( W.do
                  call_ narrativeWriteFn (arg narrativeSourcedNote :> arg audit :> arg draft :> noArgs)
                  stop
              )
              ( W.do
                  call_ narrativeWriteFn (arg narrativeObjectedNote :> arg audit :> arg draft :> noArgs)
                  stop
              )
              ( W.do
                  call_ narrativeWriteFn (arg narrativeSilentNote :> arg audit :> arg draft :> noArgs)
                  stop
              )

-- | What the closing tree receipt is introduced as, at @account-halt@.
afterBrief :: Text
afterBrief =
  "The working tree, re-read now that the journal, the commit series and the \
  \push have all run. This is what a fresh session on another machine would NOT \
  \see: anything still listed here is staying behind."

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a kind answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every receipt opens with 'dossierBrief', every section
-- with its own 'Workflows.Panels.lensBrief', and the four one-off questions with
-- their own briefs.
--
-- __One row per kind steers the run.__ At @account-halt@ the closing tree
-- receipt answers EMPTY, so 'Workflows.Deciders.treeDirty' says clean and the run
-- ends in the arm an operator wants — put a porcelain line in it and the run
-- rehearses the arm that says the session did not stop cleanly. At
-- @account-narrative@ @'Agentic.Exec.scriptedDefault'@ answers a verdict
-- @APPROVE@, so the sourcing audit approves and the run walks the sourced arm;
-- the objecting and declining arms are one row each, and all three exit 0.
--
-- __The dossier's rows share one key, and the table says so.__ All four receipts
-- open with 'dossierBrief', so one canned answer serves them all: a scripted run
-- cannot make the branch receipt differ from the diff receipt. What it does
-- exercise is every question, every fold and every branch, which is what the
-- gate is for.
accountScript :: AccountKind -> [(Text, Text)]
accountScript kind =
  [ (dossierBrief, dossierAnswer),
    (afterBrief, ""),
    (estimateBrief, estimateAnswer),
    (chronologyBrief, chronologyAnswer),
    (narrativeBrief, narrativeAnswer)
  ]
    <> [(lensBrief l, blockFrom l) | l <- roster]
  where
    roster = case kind of
      Sitrep -> sitrepRoster
      _ -> reportRoster

    dossierAnswer =
      " M src/Lex.hs\n\
      \?? doc/handoff.md\n\
      \a1b2c3d Add the boundary case to the lexer tests\n\
      \e4f5a6b Hoist the position reset out of the success arm"

    blockFrom l =
      "On "
        <> lensOwns l
        <> ": drawn from the receipts above and nothing else. Where the receipts \
           \are silent this section says so rather than filling the gap. (the "
        <> lensName l
        <> " section)"

    estimateAnswer =
      "All blocks accounted for.\n\
      \Estimate: two to four working days of effort, spread over a calendar week \
      \if review time is counted. Comparison used: the two commits in the series \
      \receipt cover roughly a third of the implementation blocks and were \
      \written over two days.\n\
      \What could move it: the two open questions are both design decisions the \
      \implementation blocks depend on; if either goes the other way, the \
      \implementation estimate doubles. Verification cost is not estimable from \
      \these receipts -- no test run appears in them."

    chronologyAnswer =
      "1. The lexer reported a wrong column on a boundary-split operator \
      \[journal].\n\
      \2. The position reset was found to be in the success arm only [diff].\n\
      \3. The boundary case was added as a test before the fix [series].\n\
      \\n\
      \Where the understanding changed: the defect was read as an off-by-one and \
      \turned out to be a control-flow placement [journal, diff].\n\
      \\n\
      \What the evidence does not show: whether the three-character operator \
      \case was ever considered; no receipt mentions it."

    narrativeAnswer =
      "# The Column That Was Off\n\
      \\n\
      \## Purpose\n\
      \\n\
      \The lexer reported the wrong column for an operator split across a buffer \
      \boundary. The purpose of the work was to make the reported position \
      \correct in every case, and to leave behind a test that would notice if it \
      \ceased to be.\n\
      \\n\
      \## How the Work Unfolded\n\
      \\n\
      \The defect presented as an off-by-one, and was read that way at first. \
      \The diff shows what it actually was: the position reset stood in the \
      \success arm of the scanner alone, so the miss path carried a stale \
      \position forward. The test was written before the correction, which is \
      \why the series shows it failing and then passing.\n\
      \\n\
      \## Where the Work Now Stands\n\
      \\n\
      \The two-character case is corrected and pinned. Whether the \
      \three-character case was ever considered cannot be established from the \
      \evidence to hand.\n\
      \\n\
      \Sources: the project journal, the commit series over the trunk, the \
      \working diff, and the working tree."
