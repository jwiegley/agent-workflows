-- |
-- Module      : Workflows.Effort
-- Description : The escalation ladder — medium, heavy, forge, at three prices.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------+-----------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@   | here                                                            |
-- +=============================+=================================================================+
-- | @skills\/toolkit\/SKILL.md@ | 'toolkitStandard' — a define, spliced by the two rungs that     |
-- |                             | invoke it. Its @## Effort tiers@ table __dissolves__: it is     |
-- |                             | three registry rows and three prices                            |
-- +-----------------------------+-----------------------------------------------------------------+
-- | @commands\/medium.md@       | @effort-medium@ — the toolkit, a plan, the work, the gate       |
-- +-----------------------------+-----------------------------------------------------------------+
-- | @commands\/heavy.md@        | @effort-heavy@ — the same, plus the two named partners and the  |
-- |                             | Positron context, which is decided from the worktree path in    |
-- |                             | ordinary Haskell                                                |
-- +-----------------------------+-----------------------------------------------------------------+
-- | @skills\/forge\/SKILL.md@   | @effort-forge@ — the six phases, in order, with the approval    |
-- |                             | pause and the remediation loop                                  |
-- +-----------------------------+-----------------------------------------------------------------+
-- | @commands\/forge.md@        | nothing, and that is right: it is a pure entry point whose only |
-- |                             | content is \"the forge skill defines the entire workflow … do   |
-- |                             | not restate, abbreviate, or modify it here\". As a row over the |
-- |                             | skill's program there is nowhere to restate                     |
-- +-----------------------------+-----------------------------------------------------------------+
-- | @skills\/fix-all\/SKILL.md@ | "Workflows.Rubrics.Discipline", spliced into the acting         |
-- |                             | questions                                                       |
-- +-----------------------------+-----------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The owner's own cost model, finally priced.__ @toolkit@ declares
--      @medium ⊂ heavy ⊂ forge@ in three bullets and has no way to say what the
--      containment costs. Three rows, three bills, side by side in @wf list@:
--      the tier stops being which text was pasted and becomes a number an
--      operator reads before spending anything. @doc\/design.md@ §7.2 row 33
--      asks for exactly this sentence, and §7.4 row 10 calls pricing @forge@
--      before running it \"the demo\".
--
--   2. __\"If this worktree is anywhere under positron or pos\" costs nothing.__
--      @heavy.md@ spends a turn asking a model where it is. 'inPositron' is
--      ordinary Haskell over the @worktree@ input, applied __before__ the
--      'Agentic.Builder.Program' exists — tier 1: zero questions and __zero
--      paths__ — and @wf plan effort-heavy --raw --input-arg worktree=…@ prints
--      which of the two briefs will be sent.
--
--   3. __\"Do not fall back to single-model operation\" is the absence of a
--      ladder.__ @forge@'s prerequisites say it in as many words, and then the
--      skill has no mechanism for it. Here 'partnerOne' and 'partnerTwo' are
--      pinned with @'Agentic.Workflow.servedBy'@ and carry __no__
--      @'Agentic.Workflow.fallingBackTo'@ — alone in this tree — so a partner
--      that will not answer cannot be silently replaced by the house model, and
--      @--require-pinned@ refuses the run before a plan is printed if the pin is
--      missing. The @listmodels@ preflight has nothing left to check.
--
--   4. __\"Never skip phases\" becomes unstatable otherwise.__ @forge@'s
--      constraint is addressed to whoever is reading it. Here phases 1 to 6 are
--      binds in one @W.do@ block: phase 4 reads the handle phase 3 bound, so
--      there is no order in which they could run but this one, and no way to
--      write a run that omits one.
--
--   5. __\"Do NOT proceed to Phase 3 without approval\" has an arm.__ The
--      approval is @'Agentic.Workflow.confirm' 'Workflows.Parties.owner'@ and
--      the run branches on it. §7.4 row 10 sketches @ask_ (person "owner")@; a
--      flag is taken instead, and the reason is that forge's rule is not
--      /pause/ but /do not proceed/ — only a flag has an arm for \"no\", and an
--      @ask_@ would have made the refusal unrepresentable. The declining arm
--      reports the approved-but-unexecuted plan, which is the artefact that run
--      produced.
--
--   6. __The three overall assessments become a sum type.__ @forge@ step 6.1
--      item 6 asks for one of \"ready to merge, needs fixes, or needs rework\",
--      in prose, from a model. Those are
--      @'Agentic.Workflow.SettledOn'@ \/ @'Agentic.Workflow.UnsettledOn'@ \/
--      @'Agentic.Workflow.AbandonedOn'@, and
--      'Workflows.Escalation.escalating' is the loop that produces them: the
--      @case@ is total, so the third arm — the one a tired reader collapses into
--      the second — is a thing the compiler makes the author write. See __the
--      Escalation decision__ below.
--
--   7. __The test suite's verdict is the suite's.__ @forge@ step 4.1 says \"run
--      any tests specified in the plan to independently verify results\" and
--      then hands the results to a model as prose. Here it is
--      @'Workflows.Evidence.makeTest'@ asked at __verdict__: exit @0@ approves,
--      nonzero objects with the suite's own first failing line, and the review
--      question splices that verdict rather than a claim about it.
--
-- == The Escalation decision
--
-- @doc\/design.md@ built "Workflows.Escalation" in the foundation wave and
-- nothing had called it since. The question this row was asked to settle is
-- whether it earns its keep or is deleted. __It earns its keep, here, and the
-- argument is @forge@'s own text.__
--
-- @'Workflows.Gates.gate'@ is the two-way loop and is right when the review is a
-- __command__; @'Workflows.Escalation.escalating'@ is the three-way loop and is
-- right when the review is a __model whose refusal must end the run__.
-- @forge@'s Phase 5–6 remediation cycle is the second case exactly:
--
--   * the reviewer is the adversarial assessment, a model;
--   * approval settles — @forge@'s \"ready to merge\";
--   * an objection amends, and an exhausted bound leaves the loop holding the
--     candidate — @forge@'s \"needs fixes\", reported /with/ the critique rather
--     than instead of it, which is what @'Agentic.Workflow.UnsettledOn'@
--     carrying its candidate buys;
--   * a __refusal__ ends the run — @forge@'s \"if PAL MCP is unavailable or a
--     partner model is missing, inform the user and halt; do not fall back to
--     single-model operation\", and its \"if any phase encounters an
--     unrecoverable error, halt and report what succeeded and what failed\".
--     That is @'Agentic.Workflow.AbandonedOn'@, and no two-way loop can express
--     it: @'Agentic.Workflow.revising'@ tests approval, so a refusal buys a trip
--     that cannot help.
--
-- Nine skills in the corpus name a closed set of outcomes in English; this is
-- the first row that has one, and the three notes the module already carried —
-- 'Workflows.Escalation.completeNote', 'Workflows.Escalation.remainsNote',
-- 'Workflows.Escalation.blockedNote' — are the three provenance lines the arms
-- pass. Nothing in "Workflows.Escalation" had to change.
--
-- == Three honest notes
--
-- __The repair round is unrolled, and not a @'Workflows.Gates.gate'@.__
-- @Agentic.Acp.permissionByCode@ grants a tool call only during an
-- @'Agentic.Workflow.act'@: a question asked at @text@ is refused the workspace
-- for the duration of its turn. A gate's amendment is an @ask@ at @text@
-- (@'Agentic.Workflow.amend'@ takes an 'Agentic.Workflow.Ask'), so a gate whose
-- check is @nix flake check@ and whose repair must edit the tree is a loop that
-- cannot change what it is testing. So the check here is
-- @'Workflows.Gates.passes'@ — an exit code as a flag, which is the world's
-- answer and not a model's — and the repair is @call_ 'effortRepairFn'@, whose
-- body ends in an act. This is "Workflows.Gates"' own prescription for a
-- pipeline per trip, and 'Workflows.Checklist' reaches it from the other
-- direction. Reported as a finding against "Workflows.Gates", whose
-- @'Workflows.Gates.gate'@ has the same property and whose two callers
-- (@green-tree@, @commit@) inherit it; closing it means letting a revision's
-- amendment be a @call_@, which is a change to @Agentic.Workflow@'s block
-- grammar and is not this row's to make.
--
-- __@toolkit@'s @-pro@ roster is a sentence here and not a dispatch.__ Its
-- standard tooling names @cpp-pro@, @python-pro@, @emacs-lisp-pro@, @rust-pro@
-- and @haskell-pro@, which are "Workflows.Parties"' specialists. Selecting one
-- would need the file list, and @medium.md@ and @heavy.md@ take a task
-- description and not a diff. So the clause is transcribed as prose and the
-- dispatch is not invented: when @effort@ grows a @paths@ input it becomes
-- 'Workflows.Rubrics.Reviewers.languageRoster' at tier 1, exactly as
-- @review-deep@'s does, and until then this is honest about being a sentence.
--
-- __The remediation loop's candidate is the critique, and the diff is not
-- spliced beside it.__ @'Workflows.Escalation.escalating'@ splices one
-- candidate, so the remediation author reads the critique document and the
-- citations in it rather than the diff as well. Where that bites, the repair is
-- an evidence parameter on @escalating@ — the same shape
-- @'Workflows.Panels.withEvidence'@ has — and it is recorded here rather than
-- taken, because a signature change to a shared loop is not one row's to make
-- unilaterally.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Effort
  ( -- * The rungs
    Tier (..),
    effortName,
    effortDoc,
    effortHelp,
    effortGate,

    -- * The program
    effortProgram,
    effortScript,

    -- * The two partners forge names, and the two rosters
    partnerOne,
    partnerTwo,
    consensusRoster,
    critiqueRoster,

    -- * The rubrics
    toolkitStandard,

    -- * The tier-1 decision @heavy.md@ spends a turn on
    inPositron,

    -- * The functions the rungs share
    effortRepairFn,
    effortReportFn,
    effortTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The parties that are this program's own
-- ---------------------------------------------------------------------------

-- | The party a plan is carried out through.
--
-- A @tool@ with __no__ argv, for 'Workflows.Git.Commit''s reason: the argv of
-- \"execute each step in the specified order\" is whatever the plan says, and an
-- @'Agentic.Workflow.act'@ at @'Agentic.Raw.CodeAck'@ is the only kind of answer
-- the ACP transport grants write authority to.
--
-- __@forge@ pins its executor to Fable or Opus and that pin cannot be carried
-- here__: @'Agentic.Workflow.servedBy'@ on a tool party is a type error
-- (@Couldn't match type ‘IsTool’ with ‘IsModel’@), by design, because a tool is
-- the run's own hands. Which model holds them is chosen at the run —
-- @--engine acp --adapter claude@ — and not in the program. That is a real loss
-- against the skill's table and it is written down rather than papered over.
executor :: Party 'IsTool
executor = tool "execute"

-- | @forge@'s Partner 1.
--
-- /Source:/ @skills\/forge\/SKILL.md@'s @## PAL Model Reference@, and
-- @commands\/heavy.md@, which names the same two models.
--
-- __No fail-over, deliberately, and this is the only party in the tree without
-- one.__ @forge@'s prerequisites read \"if PAL MCP is unavailable or a partner
-- model is missing, inform the user and halt. Do not fall back to single-model
-- operation -- the value of Forge comes from multi-model collaboration.\" A
-- @'Agentic.Workflow.fallingBackTo'@ here would be precisely that fallback, so
-- the sentence is the __absence__ of the words. What happens instead is what the
-- skill asks for: the pinned model does not answer, the run has nowhere to go,
-- and it says so.
partnerOne :: Party 'IsModel
partnerOne = model "partner-1" `servedBy` gpt5Pro

-- | @forge@'s Partner 2. /Source:/ the same table; see 'partnerOne' for why it
-- carries no alternates.
partnerTwo :: Party 'IsModel
partnerTwo = model "partner-2" `servedBy` gemini

-- ---------------------------------------------------------------------------
-- The rungs
-- ---------------------------------------------------------------------------

-- | The owner's three effort tiers.
--
-- /Source:/ @skills\/toolkit\/SKILL.md@'s @## Effort tiers@, which is the
-- clearest statement of an unpriced cost model in the corpus: three bullets that
-- say one tier contains another and cannot say what the containment costs.
data Tier
  = -- | @commands\/medium.md@ — the standard toolkit and discipline.
    Medium
  | -- | @commands\/heavy.md@ — the toolkit plus the two named partners and
    -- Positron's Notion context.
    Heavy
  | -- | @skills\/forge\/SKILL.md@ — the full six-phase, multi-model workflow.
    Forge
  deriving (Eq, Show)

-- | The name the operator types, and the name "Workflows.Registry" registers.
--
-- Family first and the owner's own word as the suffix, which is
-- 'Workflows.Git.Commit.commitRungName''s rule: @wf list@ sorts the three by the
-- thing he is choosing between, and the price of each is beside it.
effortName :: Tier -> Text
effortName Medium = "effort-medium"
effortName Heavy = "effort-heavy"
effortName Forge = "effort-forge"

-- | The one line @wf list@ prints beside a rung.
effortDoc :: Tier -> Text
effortDoc Medium = "medium.md: the standard toolkit — plan, execute, and hold the tree to its own gate"
effortDoc Heavy = "heavy.md: the same, plus the two pinned partners and the Positron context, decided free"
effortDoc Forge = "forge/SKILL.md: the six phases, the approval pause, and a remediation loop with three endings"

-- | The page @wf help \<rung\>@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- One text at three settings. The three rungs share a shape and two inputs and
-- differ in exactly what the skills say they differ in, so the inputs are
-- written once — with one exception that has to be per-rung.
--
-- __@worktree@ is read by one rung of the three__, which is the fact this page
-- exists to carry: it decides whether the run is under one of the owner's
-- Positron directories, and only the @Heavy@ rung consults that. At the other
-- two the input is declared, because the three share one invocation, and read
-- by nobody — a shared bullet would be wrong twice out of three times.
--
-- __The transport is per-rung too__, because the heaviest one puts an approval
-- to a person and an unattended run reaches nobody.
--
-- __It states no price.__ The header above it carries the numbers off the same
-- 'Agentic.Plan.Facts' @wf list@ publishes.
effortHelp :: Tier -> Text
effortHelp t =
  [wft|
  {opening}

  **Inputs.**

  * `task` — what all three entry points spell `$ARGUMENTS`: the thing to be
    planned and done, in your own words. It is the subject of every phase, and
    an empty one is a plan about nothing — which the plan prints.
  {worktreeInput}

  **Transport.** {transport}

  ```sh
  wf run {row} {live} \
     --input-arg task={taskEg} --input-arg worktree={worktreeEg}
  ```

  **Rehearsal.** Both inputs named empty, every question answered from the row's
  own canned table, consulting nobody:

  ```sh
  wf run {row} --scripted --input-arg task= --input-arg worktree=
  ```

  **Caveats.**

  {caveat}
  * The three rungs are a ladder the owner already had as an unpriced cost model
    — medium inside heavy inside forge — and the point of them being three rows
    is that the three bills sit side by side in `wf list` before one is chosen.
  * Every rung ends by holding the tree to a gate that is a *command's exit
    code*, not a party's opinion. Which command differs between the rungs, and
    the skills state the difference.
  |]
  where
    row = effortName t

    opening = case t of
      Medium ->
        [wft|
        `commands/medium.md` as a program: the standard toolkit at its first
        setting — plan, execute, and hold the tree to its own lint and
        type-check gate. The floor of the ladder, and the rung to reach for when
        the work is understood and the question is only whether it was done
        properly.|]
      Heavy ->
        [wft|
        `commands/heavy.md` as a program: the same shape, plus the two pinned
        partners and the Positron context — the latter decided for *free*, in
        ordinary Haskell over the worktree path, before the program exists.|]
      Forge ->
        [wft|
        `skills/forge/SKILL.md` as a program: the six phases, the approval pause
        in the middle, and a remediation loop with three endings. The top of the
        ladder, and the only rung that stops and asks.|]

    worktreeInput = case t of
      Heavy ->
        [wft|
        * `worktree` — the path read to decide whether this is one of the
          owner's Positron directories, which selects the extra context this
          rung carries. It is read in ordinary Haskell — tier 1, zero questions
          — so it changes a define rather than a path, and an empty one is
          simply the non-Positron shape.|]
      _ ->
        [wft|
        * `worktree` — the path `effort-heavy` reads to decide whether it is
          under a Positron directory, and **this rung does not read it**. The
          three rows share one invocation, so it is declared here and consumed
          nowhere; that is also what makes it free at this rung.|]

    transport = case t of
      Forge ->
        [wft|
        A watched pane. This rung puts an approval to the owner in binding
        position — the phases after it are reached only through his answer — and
        an unattended run reaches nobody: `--scripted` answers the confirmation
        from a table and an adapter of the run's own has no one to ask.
        {paneNote}|]
      _ ->
        [wft|
        Unattended, with somewhere to write: an adapter of the run's own and
        `--scratch "$PWD"`, because this rung edits your tree and the scratch
        directory is the only place an acting turn may write.|]

    live = case t of
      Forge -> [wft|--session "$PANE" --require-pinned|]
      _ -> [wft|--engine acp --adapter claude --require-pinned --scratch "$PWD"|]

    taskEg :: Text
    taskEg = case t of
      Medium -> "'add the missing --dry-run flag'"
      Heavy -> "'bring the token-refresh path under test'"
      Forge -> "'design the retry policy'"

    worktreeEg :: Text
    worktreeEg = case t of
      Heavy -> "\"$HOME/src/positron/my-project\""
      _ -> ""

    caveat = case t of
      Medium ->
        [wft|
        * No partners, no multi-model consensus, no approval pause. If the work
          needs an argument before it is done, that is `effort-heavy` or
          `effort-forge`, and the difference in price is the difference in what
          is asked.|]
      Heavy ->
        [wft|
        * The Positron context is decided for nothing and is either there or
          not. An empty `worktree=` is the non-Positron shape, which is a
          smaller define and the same program — so this rung does not become
          `effort-medium` when the flag is missing.|]
      Forge ->
        [wft|
        * The approval pause is a real gate only when somebody is watching. A
          rehearsal answers it from the row's own table, which exercises the
          loop and tells you nothing about what you would have said.
        * The remediation loop has three endings and the third is the one to
          read hardest: it means the work could not be brought to the standard
          the plan set, which is a result and not a crash.|]

-- | Which command decides that a rung's work is green.
--
-- /Source:/ @skills\/toolkit\/SKILL.md@'s working discipline (\"ensure code
-- passes linting and type checking after any change\") for the two lighter
-- rungs, and @forge@ step 4.1 (\"run any tests specified in the plan to
-- independently verify results\") for the heaviest. Two commands, and the
-- difference between them is a difference the skills state.
effortGate :: Tier -> Party 'IsTool
effortGate Forge = makeTest
effortGate _ = nixFlakeCheck

-- ---------------------------------------------------------------------------
-- The tier-1 decision heavy.md spends a turn on
-- ---------------------------------------------------------------------------

-- | Is this worktree under one of the owner's Positron directories?
--
-- /Source:/ @commands\/heavy.md@'s one conditional — \"if this worktree is
-- anywhere under the \\\"positron\\\" or \\\"pos\\\" directories\" — which in the
-- corpus is a question a model answers about its own surroundings and here is
-- three lines of Haskell over an input.
--
-- __Tier 1__ ("Workflows.Deciders"): zero questions and __zero paths__, because
-- it is applied before the 'Agentic.Builder.Program' exists and so shapes a
-- define rather than adding a branch. It is total on @\"\"@ — an unnamed
-- worktree is not under a Positron directory — which is house rule 6.
--
-- The bracketing slashes are what make @pos@ a directory component and not a
-- substring: @\/home\/j\/possum\/x@ is not a Positron worktree, and a match on
-- the bare word would have said it was.
inPositron :: Text -> Bool
inPositron w = any (`T.isInfixOf` bracketed) ["/positron/", "/pos/"]
  where
    bracketed = "/" <> T.strip w <> "/"

-- | What the research question is told about where it is standing.
--
-- Both arms are written, and the false one is not an absence: a question that is
-- told nothing about Notion is a question that may go looking for it, which is
-- the turn @heavy.md@ spends and this rung does not.
positronNote :: Bool -> Text
positronNote True =
  [wft|
  This worktree is under one of the owner's Positron directories, which was
  decided from its path before this question was asked. So: query Positron's
  Notion repository for supporting documents and context on this task. Some of
  it may be out of date, and out-of-date context is still context -- say which
  of your conclusions rests on it and how old the source was.|]
positronNote False =
  [wft|
  This worktree is NOT under a Positron directory, which was decided from its
  path before this question was asked. There is no Notion repository to consult
  for it and you should not go looking for one. Work from the task, the
  codebase and public sources.|]

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | @skills\/toolkit\/SKILL.md@, whole: the standard tooling and the working
-- discipline.
--
-- /Source:/ its @## Standard tooling@ and @## Working discipline@ sections. The
-- @## Effort tiers@ section is deliberately absent: it is three registry rows,
-- and a define that told a model which tier it was would be the corpus's
-- \"which text was pasted\" restated inside the thing that replaced it.
--
-- The @GH_TOKEN@ invocation is carried because it is the owner's, and it is the
-- one line here that is a real command rather than a disposition — see the
-- module header on why it is prose and not an argv in
-- "Workflows.Evidence": nothing in this program runs it, the answering agent
-- does.
toolkitStandard :: Text
toolkitStandard =
  [wft|
  The standard tooling and working discipline for this task.

  - For anything touching GitHub, use
    `GH_TOKEN="$(gh auth token --hostname github.com --user jwiegley)" gh ...`.
  - Search the codebase for the relevant files before reasoning about them.
  - Reach for the language specialist where the task is in its language:
    `cpp-pro`, `python-pro`, `emacs-lisp-pro`, `rust-pro`, `haskell-pro`.
  - Use live web search for research and for discovering resources.
  - Break the task down further where it is not yet one step.

  The discipline: ensure the code passes linting and type checking after any
  change. Think deeply to analyse the task, construct a well-thought-out plan
  of action from the context and research at hand, and then carefully execute
  that plan step by step.|]

-- | What the planning question asks for.
--
-- /Source:/ @commands\/medium.md@, whose whole content is \"think deeply,
-- construct a well-thought-out plan for the task below, and carefully execute it
-- step by step\", made into a question with a stated output.
planBrief :: Text
planBrief =
  [wft|
  Construct the plan for the task below. Answer with the plan and nothing
  else: it is handed, verbatim, to whoever does the work.

  Cover, in this order:

  - what is being changed, file by file, and what each change is;
  - the order of operations, and which changes depend on which;
  - what will be run to check it, and what passing looks like;
  - what to do if a step fails: the thing to try, or the thing to report.

  Be concrete enough that somebody could execute it without asking you a
  question, and short enough that they will read all of it.|]

-- | What the executing act is told.
--
-- /Source:/ @commands\/medium.md@'s \"carefully execute it step by step\", with
-- the no-deferral rule and the testing standard spliced from
-- "Workflows.Rubrics.Discipline" — which is where those sentences live once.
executeBrief :: Text
executeBrief =
  [wft|
  Carry out the plan below, step by step and in its order.

  Where a step's check fails, fix the cause rather than the check. Where the
  plan turns out to be wrong, do the correct thing and say in your reply which
  step you departed from and why -- a deviation reported is a fact; a deviation
  absorbed is a defect nobody can find later.

  {discipline}

  {testing}

  When you are done, reply DONE.

  The plan:|]
  where
    discipline = fixAllRule
    testing = testingStandard

-- | What the gate question is introduced as.
--
-- The words go to the child's standard input, which @nix flake check@ does not
-- read; it is here because @plan --raw@ prints it, so a reader of the plan can
-- see what the exit code is being asked about. That is
-- "Workflows.Gates"' own reason for writing one.
gateBrief :: Text
gateBrief =
  [wft|
  The repository's own lint and type-check gate, run after the work. Its exit
  code is the answer: nothing here is a claim about whether the tree is green.|]

-- | The same gate, after a repair round.
regateBrief :: Text
regateBrief =
  [wft|
  The repository's own gate again, after the repair round. This is the second
  and last time this run asks it.|]

-- | What the repair round's first question asks for.
repairDiagnoseBrief :: Text
repairDiagnoseBrief =
  [wft|
  The repository's lint and type-check gate objected after the work below was
  done. Say what to change and nothing else.

  Name the cause, not the symptom, and name the file and the line. If the
  right fix is upstream of this tree, say so and say where. Do not propose
  silencing the check, weakening it, or annotating around it: a check quietly
  disabled is the failure this round exists to prevent.|]

-- | What the repair round's act is told.
repairWorkBrief :: Text
repairWorkBrief =
  [wft|
  Make the change below, and nothing beyond it. Then run the repository's own
  lint and type-check gate yourself and say what it said.

  {upstream}

  When you are done, reply DONE.

  The change:|]
  where
    upstream = upstreamRule

-- ---------------------------------------------------------------------------
-- The consensus roster
-- ---------------------------------------------------------------------------

-- | The line every partner seat stands under, second in its brief.
--
-- 'Workflows.Rubrics.Stances.challengeRubric' is
-- @commands\/gravity.md@'s harvested second half and is the anti-sycophancy rule
-- every contrary party in this tree carries. It is second rather than first for
-- @confer@'s reason: a roster whose seats share an opening chunk has one canned
-- answer serving all of them, and 'effortScript' is where that is checked.
consensusRoster :: Roster
consensusRoster =
  [ Lens
      { lensName = "partner-1",
        lensOwns = "gaps, missing steps and overlooked dependencies",
        lensBrief = underChallenge gapsStance,
        lensParty = partnerOne
      },
    Lens
      { lensName = "partner-2",
        lensOwns = "risks, edge cases and failure modes, and a confidence rating",
        lensBrief = underChallenge risksStance,
        lensParty = partnerTwo
      }
  ]

-- | /Source:/ @forge@ steps 1.3 and 2.2, first and third bullets.
gapsStance :: Text
gapsStance =
  [wft|
  Read what you are given as somebody who will have to live with it, and
  answer on gaps.

  Name what was missed: the aspect not examined, the step the plan does not
  have, the dependency between two steps that nobody stated. Name any
  alternative root cause or approach that has not been considered, and say
  what would distinguish it from the one on the table. Where you would do it
  differently, say what your version buys.

  You are one of two parties asked independently; the other owns risk and
  confidence. Do not write its answer.|]

-- | /Source:/ @forge@ steps 1.3 and 2.2, second and fourth bullets.
risksStance :: Text
risksStance =
  [wft|
  Read what you are given as somebody who will be paged when it breaks, and
  answer on risk.

  Name the failure modes, the edge cases, and the constraint that is being
  assumed rather than checked. For each, say how it would present and how
  expensive it would be to find later -- a silent failure is worth more of
  your attention than a loud one.

  Close with a confidence rating from 1 to 10 in the completeness of what you
  were given, on its own last line, and one sentence saying what would move
  it.

  You are one of two parties asked independently; the other owns gaps and
  alternatives. Do not write its answer.|]

-- | What each partner is told about the shape of its answer.
consensusClosing :: Text
consensusClosing =
  [wft|
  Answer your part and nothing else. Your answer is one block of a document
  whose other block is the other party's: do not write theirs, do not
  summarise the whole, and do not reconcile the two -- reconciling them is a
  later question, put to somebody who has read both.|]

-- ---------------------------------------------------------------------------
-- The critique roster
-- ---------------------------------------------------------------------------

-- | @forge@'s Phase 5, as two adversarial seats.
--
-- /Source:/ @skills\/forge\/SKILL.md@ step 5.2's two @stance_prompt@ values,
-- carried close to verbatim — they are the sharpest prose in the skill and the
-- part that must not be paraphrased — with step 5.1's own checklist folded into
-- the first, which is where that file addresses it.
critiqueRoster :: Roster
critiqueRoster =
  [ Lens
      { lensName = "hostile",
        lensOwns = "every flaw, edge case, race and design mistake, and what the review dismissed",
        lensBrief = underChallenge hostileStance,
        lensParty = partnerOne
      },
    Lens
      { lensName = "auditor",
        lensOwns = "what an adversary and extreme load would do, and the review's blind spots",
        lensBrief = underChallenge auditorStance,
        lensParty = partnerTwo
      }
  ]

-- | /Source:/ @forge@ step 5.2's first stance, plus step 5.1's checklist.
hostileStance :: Text
hostileStance =
  [wft|
  You are a hostile code reviewer. Find every possible flaw, vulnerability,
  edge case, race condition and design mistake in these changes. Be ruthlessly
  critical. If you cannot find real problems, identify theoretical risks and
  worst-case scenarios -- and say which of your findings are which.

  Walk it deliberately: every conditional branch, what if the other path is
  taken? Every external call, what if it fails, times out, or returns
  unexpected data? Every assumption, what if it is wrong? Concurrency: races,
  deadlocks. Error propagation: swallowed or mishandled.

  Then critique the review report itself. What did the reviewers miss, and
  what did they dismiss too easily? Assume the review was too lenient, because
  a review that agreed readily is the one worth reading twice.|]

-- | /Source:/ @forge@ step 5.2's second stance.
auditorStance :: Text
auditorStance =
  [wft|
  You are a security auditor and a reliability engineer. Assume this code will
  be attacked by adversaries and subjected to extreme load.

  Find every weakness, every assumption that could fail, every error path that
  is not handled. Question the architectural decisions. Challenge the test
  coverage: name a test that would pass whatever the code did.

  Then examine the review report for blind spots and groupthink -- two
  reviewers who reached the same conclusion from the same brief have not
  confirmed anything.|]

-- | What each critic is told about the shape of its answer.
--
-- /Source:/ @forge@ step 5.3's four severities, which is the closest thing in
-- the corpus to 'Workflows.Rubrics.Finding.severities' and is carried in the
-- skill's own words.
critiqueClosing :: Text
critiqueClosing =
  [wft|
  Grade every finding, and put the grade first on its line:

  - Critical -- must fix before merging: a functional bug, a security hole, a
    data-corruption risk.
  - High -- should fix soon: a significant quality or reliability concern.
  - Medium -- worth addressing: maintainability, robustness.
  - Low -- a nitpick or a theoretical concern, for awareness.

  Your answer is one block of a document whose other block is the other
  critic's. Do not write theirs and do not summarise the whole.|]

-- ---------------------------------------------------------------------------
-- The forge phase briefs
-- ---------------------------------------------------------------------------

-- | /Source:/ @forge@ Phase 1, steps 1.1 and 1.2.
forgeResearchBrief :: Text
forgeResearchBrief =
  [wft|
  Phase 1 of six: deep analysis and research. Investigate before anything is
  planned or written.

  Explore the problem space: read the relevant files, understand the current
  state, the architecture and the constraints, and identify the root cause if
  this is a debugging task or the core requirements if it is a building one.
  Collect the file paths and the code that a reader who has not looked would
  need.

  Then analyse systematically, step by step, and say which of your conclusions
  are read off the code and which are inferred. Answer with the investigation
  and nothing else; it is put to two independent partners next.|]

-- | /Source:/ @forge@ step 1.4, with 'Workflows.Panels.refusingSynthesis''s
-- accounting paragraph, whose contract
-- 'Workflows.Deciders.incompleteFanOut' is the other half of — and which is
-- deliberately __not__ read here: forge has no arm for a missing partner block
-- short of the halt its prerequisites already state, and the halt is the
-- remediation loop's third ending.
forgeBriefSynthesis :: Roster -> Text
forgeBriefSynthesis r =
  [wft|
  Synthesise the research brief. You are given the investigation and a document
  of {count} blocks, one per partner, each fenced under its own name. The
  partners and what each owns:

  {table}

  The brief, in this order: the problem statement and its context; the root
  cause or the requirements; the key constraints and risks; where the partners
  agree and where they do not, named as disagreements rather than averaged;
  and what the planning phase should therefore do.

  If a named partner's block is missing or empty, say so in the first line and
  do not present the brief as validated -- a plan built on one partner is the
  single-model operation this workflow exists to refuse.|]
  where
    count = tshow (length r)
    table = rosterTable r

-- | /Source:/ @forge@ step 2.1.
forgePlanBrief :: Text
forgePlanBrief =
  [wft|
  Phase 2 of six: the plan. From the research brief below, and answering with
  the plan and nothing else:

  - the specific files to create, modify or delete, with what each change is;
  - the order of operations, and the dependencies between changes;
  - the test strategy: which tests to run, what to verify, what the expected
    outcome of each is;
  - the rollback approach if the changes break existing functionality.

  It goes to two independent partners for validation, and then to the owner for
  approval, before a line of it is executed.|]

-- | /Source:/ @forge@ step 2.3.
forgeRefineBrief :: Text
forgeRefineBrief =
  [wft|
  Refine the plan below against what the partners said.

  Address every concern raised, or state explicitly why a suggestion was not
  incorporated -- those are the only two options, and \"noted\" is neither. A
  concern you accept changes the plan; a concern you reject gets one sentence
  saying what it would cost to accommodate and why that is the wrong trade.

  Answer with the refined plan, followed by a short section headed
  `Concerns addressed` listing each partner concern and its disposition.|]

-- | /Source:/ @forge@ step 2.4, whose \"do NOT proceed to Phase 3 without
-- approval\" is the arm this question's @no@ takes.
forgeApprovalBrief :: Text
forgeApprovalBrief =
  [wft|
  The plan below has been validated by both partners and refined against what
  they said. Nothing has been executed and nothing in the tree has changed.

  Approve it? Answering no ends the run here and writes the plan down as it
  stands -- no file is touched. Answering yes executes it, reviews the result,
  critiques the review, and gives you a remediation loop with a stated bound.

  Reply with exactly yes or no.|]

-- | /Source:/ @forge@ step 3.1.
baselineBrief :: Text
baselineBrief =
  [wft|
  The working tree as it stands before execution begins, as `git status
  --porcelain` reports it. This is the baseline the review measures against, and
  it is bytes rather than a recollection.|]

-- | /Source:/ @forge@ step 3.2's Task prompt, items 1 to 4.
forgeExecuteBrief :: Text
forgeExecuteBrief =
  [wft|
  Phase 3 of six: execution. Execute the approved plan below, each step in the
  order it specifies, and run the tests it specifies after making the changes.

  Report back with: every file changed and what was done to it; the full test
  output, pass or fail for each; any deviation from the plan and why it was
  necessary; and any issue, warning or concern you hit on the way. A deviation
  you do not report is the one the review will not know to look at.

  {discipline}

  {testing}

  When you are done, reply DONE.

  The approved plan:|]
  where
    discipline = fixAllRule
    testing = testingStandard

-- | /Source:/ @forge@ steps 3.3 and 4.1 — \"run @git diff@ to independently
-- verify what changed\".
changesBrief :: Text
changesBrief =
  [wft|
  Everything the execution phase changed, as `git diff` reports it. This is the
  diff, not an account of one: where it and the executor's report disagree, this
  is what happened.|]

-- | /Source:/ @forge@ step 4.1's second sentence.
testsBrief :: Text
testsBrief =
  [wft|
  The repository's own test suite, run independently of the executor. Its exit
  code is the answer and its own first failing line is the objection; nothing
  here is a claim about whether the tests passed.|]

-- | /Source:/ @forge@ steps 4.2 and 4.4.
forgeReviewBrief :: Text
forgeReviewBrief =
  [wft|
  Phase 4 of six: the review. You are given the diff, the suite's own verdict,
  and two partners' independent readings.

  Compile the review report organised by category -- correctness, security,
  performance, architecture, test coverage -- with a severity on every finding.
  Cover, within those: whether the implementation is correct; security
  vulnerabilities; performance implications; whether the changes match the
  plan and the original intent; regressions and unintended side effects; and
  whether the test coverage is adequate.

  Where the suite's verdict and a partner's reading disagree, the verdict is
  what happened. Answer with the report and nothing else; it is handed to two
  adversarial critics next.|]

-- | What the partners are told when they are reviewing rather than planning.
reviewClosing :: Text
reviewClosing =
  [wft|
  Evaluate the change on: correctness of the implementation; security
  vulnerabilities; performance implications; whether it matches the plan and
  the original intent; regressions and unintended side effects; and the
  adequacy of the test coverage. Say something about each, and say which of
  your claims you verified against the diff.

  Your answer is one block of a document whose other block is the other
  party's. Do not write theirs and do not summarise the whole.|]

-- | The assessment that judges the remediation loop.
--
-- /Source:/ @forge@ step 6.1 item 6 (\"ready to merge, needs fixes, or needs
-- rework\") and step 6.2's condition (\"if Phase 5 produced critical
-- findings\"). 'Workflows.Escalation.escalating' appends its own
-- 'Workflows.Escalation.endingSpec', which is what makes the three answers three
-- endings.
forgeAssessmentBrief :: Text
forgeAssessmentBrief =
  [wft|
  Phase 6 of six: the assessment. Below is the adversarial critique of a
  change that has already been executed and reviewed.

  Decide one thing: does any CRITICAL finding remain -- a functional bug, a
  security hole, a data-corruption risk? Critical is the only grade that
  blocks; High, Medium and Low are reported and do not.

  Approve if none remains. Object if one does, and let the objection line name
  the finding, not the category. Do not re-grade the critique to reach the
  answer you prefer, and do not approve because the remaining work looks
  small.|]

-- | What the remediation author is told each round.
--
-- /Source:/ @forge@ step 6.2 — \"create a targeted remediation plan, loop back
-- to Phase 3 with only the fixes, then repeat Phases 4-5 on the remediation
-- changes only\".
forgeRemediationBrief :: Text
forgeRemediationBrief =
  [wft|
  Remediate the critical finding the assessment named, and only it.

  Produce the targeted remediation: the specific change, file by file; the
  test that would have caught the finding; and the re-reading of the critique
  with that finding's entry replaced by what was done about it. Leave every
  other entry as it stands -- a remediation round that rewrites the critique
  it is answering has destroyed the evidence.

  {upstream}

  {testing}

  Answer with the amended critique document and nothing else.|]
  where
    upstream = upstreamRule
    testing = testingStandard

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the gate approved first time.
greenFirstNote :: Tier -> Text
greenFirstNote t =
  [wft|
  Outcome: DELIVERED. The plan was executed and the repository's own gate for
  rung `|]
    <> effortName t
    <> [wft|
       ` exited 0 on the first ask, so no repair round was spent. That the tree
       is green is the gate's own answer and not a model's account of it.|]

-- | The arm where one repair round settled it.
repairedNote :: Tier -> Text
repairedNote t =
  "Outcome: DELIVERED AFTER ONE REPAIR. The gate for rung `"
    <> effortName t
    <> [wft|
       ` objected after the work, one repair round was spent on the cause it
       named, and the second ask exited 0. Report both the work and the repair:
       a run that needed a repair round is a run whose plan was incomplete, and
       that is worth knowing.|]

-- | The arm where the gate was still red.
stillRedNote :: Tier -> Text
stillRedNote t =
  "Outcome: STILL RED. The gate for rung `"
    <> effortName t
    <> [wft|
       ` objected after the work and objected again after the one repair round
       this rung is given. Every edit both rounds made is still in the tree. Do
       not report this as delivered: say what the gate is objecting to and what
       the next run would have to start with.|]

-- | The arm where the owner declined the plan.
--
-- /Source:/ @forge@ step 2.4's \"do NOT proceed to Phase 3 without approval\",
-- which in the corpus is a capitalised instruction and here is the arm a @no@
-- takes.
declinedNote :: Text
declinedNote =
  [wft|
  Outcome: NOT APPROVED. The plan below was researched, validated by both pinned
  partners and refined against what they said, and the owner declined it.
  Nothing was executed and no file was touched. Write the plan down as it
  stands, with the partners' concerns and their dispositions: the next attempt
  starts from this document, and none of the four questions that produced it has
  to be paid for twice.|]

-- | The three endings of the remediation loop, as
-- 'Workflows.Escalation''s three notes with @forge@'s own words for each.
readyNote :: Text
readyNote =
  [wft|
  {completeNote}

  In this workflow's terms that is READY TO MERGE: the adversarial critique was
  assessed and no critical finding remained. Report the medium and low concerns
  for awareness; they are not blockers and must not be presented as any.|]

-- | /Source:/ 'Workflows.Escalation.remainsNote' and @forge@'s \"needs fixes\".
fixesNote :: Text
fixesNote =
  [wft|
  {remainsNote}

  In this workflow's terms that is NEEDS FIXES: a critical finding was
  outstanding when the remediation bound ran out. Name it, name what the last
  round did about it, and say plainly that this change is not ready to merge.|]

-- | /Source:/ 'Workflows.Escalation.blockedNote' and @forge@'s prerequisite
-- halt.
reworkNote :: Text
reworkNote =
  [wft|
  {blockedNote}

  In this workflow's terms that is NEEDS REWORK, and it is the ending `forge`'s
  prerequisites describe: the assessment declined to judge, so no further round
  could help and this run does not fall back to a single-model reading. Report
  what succeeded, what failed, and what would have to change outside this run.|]

-- | The brief the report is written through.
--
-- /Source:/ @forge@ step 6.1's six numbered parts for the heaviest rung, and
-- nothing at all for the two lighter ones — @medium.md@ and @heavy.md@ end at
-- \"execute it step by step\". One brief serves all three, which is
-- "Workflows.Report"'s argument: two report formats reached by prose reference
-- is how two rungs come to disagree about what a run said.
effortReportBrief :: Text
effortReportBrief =
  [wft|
  Write the report for an effort run, to `effort-<date>.md` in the current
  directory.

  Open with the provenance line you were given, verbatim, on its own line. It
  is the run's own account of how it ended and it is not yours to soften.

  Then, from the document below and nothing else:

  1. the problem, in one or two sentences;
  2. the approach, and the decisions it turned on;
  3. what changed -- the file list and what was done to each;
  4. what the review found, by category;
  5. what the critique found, by severity;
  6. the overall assessment, which is the provenance line's and not yours.

  Where the document does not carry one of these -- a lighter rung has no
  critique — write the heading and "not part of this rung" beneath it. Do not
  supply the missing section from your own reading of the change, and do not
  present a concern as resolved unless the document says it was. Then reply
  DONE.|]

-- ---------------------------------------------------------------------------
-- The two functions the rungs share
-- ---------------------------------------------------------------------------

-- | The repair round: diagnose the objection, then fix it.
--
-- Two statements, and its second is an @'Agentic.Workflow.act'@ — which is why
-- this is a function called from the block rather than the amendment of a
-- @'Workflows.Gates.gate'@. See the module header.
effortRepairFn :: Fn '[ 'CodeText] 'CodeAck
effortRepairFn =
  function
    "effort.repair"
    (takes @"work" Text $ noParams)
    \work -> W.do
      diagnosis <- ask (reasoning (model "repair")) [wf|
          {repairDiagnoseBrief}

          {work}|]

      act executor [wf|
          {repairWorkBrief}

          {diagnosis}|]
      done

-- | The report every ending calls.
--
-- Two parameters, provenance first, for 'Workflows.Report.reportFn''s reason: it
-- is the thing a report must not omit and the one argument the arms differ in.
effortReportFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
effortReportFn =
  function
    "effort.report"
    ( takes @"provenance" Text
        . takes @"document" Text
        $ noParams
    )
    \provenance document -> W.do
      act reporter [wf|
          {effortReportBrief}

          Provenance:

          {provenance}

          The document:

          {document}|]
      done

-- | The table 'effortProgram' hands @'Agentic.Workflow.defining'@.
--
-- One table for three rungs, because one lambda serves all three: @forge@ never
-- calls 'effortRepairFn' — its gate is the suite's verdict inside the review and
-- its repair is the remediation loop — and a declared callee nobody calls is
-- noise in a printed program rather than an error, which is the trade
-- 'Workflows.Review.Ladder' takes with
-- 'Workflows.Report.suggestionsFn'.
effortTable :: [SomeFn]
effortTable = [SomeFn effortRepairFn, SomeFn effortReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The ladder, at a rung.
--
-- Two inputs. @task@ is what all three corpus entry points spell @$ARGUMENTS@;
-- @worktree@ is the path 'inPositron' reads, and it is used by the @heavy@ rung
-- alone — which is what makes it free at the other two, since a define nobody
-- splices is a define that costs nothing.
--
-- The three rungs share a shape and differ in exactly what the skills say they
-- differ in: @medium@ plans and executes; @heavy@ puts the investigation to two
-- pinned partners first and knows where it is standing; @forge@ is six phases,
-- an approval the run cannot pass by itself, and a remediation loop with three
-- endings.
effortProgram :: Tier -> Parameterized
effortProgram t =
  taking (input "task" :> input "worktree" :> noInputs) \task worktree ->
    -- Tier 1, both of them: where this worktree stands, and the roster table the
    -- research synthesis accounts for. Ordinary Haskell, before the `Program`
    -- exists, so neither costs a question or a path.
    let sited = positronNote (inPositron worktree)
        briefSynthesis = forgeBriefSynthesis consensusRoster
     in defining effortTable case t of
      Medium -> W.do
        plan <- ask (reasoning (model "plan")) [wf|
            {toolkitStandard}

            {planBrief}

            The task:

            {task}|]

        act executor [wf|
            {executeBrief}

            {plan}|]

        -- The toolkit's working discipline, asked of the gate rather than of
        -- whoever just changed the tree: an exit code, decided by
        -- `Agentic.Shell` and not by a model.
        green <- passes (effortGate t) [wf|{gateBrief}|]

        if green
          then W.do
            call_ effortReportFn (arg (greenFirstNote t) :> arg plan :> noArgs)
            stop
          else W.do
            -- One repair round, unrolled: its work is an act, which a
            -- revision's amendment cannot be. See the module header.
            call_ effortRepairFn (arg plan :> noArgs)

            steady <- passes (effortGate t) [wf|{regateBrief}|]

            if steady
              then W.do
                call_ effortReportFn (arg (repairedNote t) :> arg plan :> noArgs)
                stop
              else W.do
                call_ effortReportFn (arg (stillRedNote t) :> arg plan :> noArgs)
                stop
      Heavy -> W.do
        -- Tier 1: where this worktree is was decided in Haskell, so the brief
        -- that arrives already knows, and no turn was spent asking.
        investigation <- ask (reasoning (model "research")) [wf|
            {toolkitStandard}

            {sited}

            {planBrief}

            The task:

            {task}|]

        -- The two pinned partners, neither of which can fail over to the house
        -- model. That is `heavy.md`'s confer clause and `forge`'s no-fallback
        -- rule, in one roster.
        partners <- panelText (zip (lensNames consensusRoster) (asksOver consensusRoster consensusClosing investigation))

        plan <- ask (reasoning (model "plan")) [wf|
            {planBrief}

            The investigation:

            {investigation}

            What the two partners said about it:

            {partners}|]

        act executor [wf|
            {executeBrief}

            {plan}|]

        green <- passes (effortGate t) [wf|{gateBrief}|]

        if green
          then W.do
            call_ effortReportFn (arg (greenFirstNote t) :> arg plan :> noArgs)
            stop
          else W.do
            call_ effortRepairFn (arg plan :> noArgs)

            steady <- passes (effortGate t) [wf|{regateBrief}|]

            if steady
              then W.do
                call_ effortReportFn (arg (repairedNote t) :> arg plan :> noArgs)
                stop
              else W.do
                call_ effortReportFn (arg (stillRedNote t) :> arg plan :> noArgs)
                stop
      Forge -> W.do
        -- Phase 1. The phases are binds and each reads the handle the last one
        -- bound, so "never skip phases" is not a rule here: there is no other
        -- order to write.
        investigation <- ask (reasoning (model "research")) [wf|
            {forgeResearchBrief}

            The problem:

            {task}|]

        found <- panelText (zip (lensNames consensusRoster) (asksOver consensusRoster consensusClosing investigation))

        brief <- ask (reasoning (model "research-brief")) [wf|
            {briefSynthesis}

            The investigation:

            {investigation}

            The partners:

            {found}|]

        -- Phase 2.
        draft <- ask (reasoning (model "plan")) [wf|
            {forgePlanBrief}

            The research brief:

            {brief}|]

        validated <- panelText (zip (lensNames consensusRoster) (asksOver consensusRoster consensusClosing draft))

        plan <- ask (reasoning (model "refine")) [wf|
            {forgeRefineBrief}

            The plan:

            {draft}

            What the partners said:

            {validated}|]

        -- Phase 2.4. `forge` says do NOT proceed without approval, and this is
        -- the arm that gives the sentence somewhere to go.
        approved <- confirm owner [wf|
            {forgeApprovalBrief}

            {plan}|]

        if approved
          then W.do
            -- Phase 3.
            baseline <- ask gitStatus [wf|{baselineBrief}|]

            act executor [wf|
                {forgeExecuteBrief}

                {plan}

                The tree as it stood before you started:

                {baseline}|]

            -- Phase 4: the diff and the suite's own verdict, neither of them
            -- authored by whoever did the work.
            changes <- ask (gitDiff []) [wf|{changesBrief}|]
            tests <- ask (effortGate t) [wf|{testsBrief}|] `answering` Verdict

            reviewed <- panelText (zip (lensNames consensusRoster) (asksOver consensusRoster reviewClosing changes))

            review <- ask (reasoning (model "review")) [wf|
                {forgeReviewBrief}

                The diff:

                {changes}

                What the test suite said:

                {tests}

                What the two partners said:

                {reviewed}|]

            -- Phase 5: the adversaries, over the review and the diff.
            critique <- panelText (zip (lensNames critiqueRoster) (withEvidence critiqueRoster critiqueClosing review changes))

            -- Phase 6: the remediation loop, and the three endings `forge`
            -- names in prose. This is where `Workflows.Escalation` earns its
            -- keep; see the module header.
            assessed <-
              escalating
                (reasoning (model "assessment"))
                forgeAssessmentBrief
                (reasoning (model "remediation"))
                forgeRemediationBrief
                critique
                (atMost 2)

            case assessed of
              SettledOn final -> W.do
                call_ effortReportFn (arg readyNote :> arg final :> noArgs)
                stop
              UnsettledOn final -> W.do
                call_ effortReportFn (arg fixesNote :> arg final :> noArgs)
                stop
              AbandonedOn final -> W.do
                call_ effortReportFn (arg reworkNote :> arg final :> noArgs)
                stop
          else W.do
            call_ effortReportFn (arg declinedNote :> arg plan :> noArgs)
            stop

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the planning question opens with 'toolkitStandard' at
-- the two lighter rungs and with its own phase brief at @forge@, each partner
-- seat opens with its own 'Workflows.Panels.lensBrief', and the receipts open
-- with theirs.
--
-- __The two gate rows are what steer the lighter rungs, and they steer them down
-- the longest path.__ @'Agentic.Exec.scriptedDefault'@ answers a flag @yes@,
-- which would take the first arm and leave 'effortRepairFn' unreached; the
-- @\"no\"@ below sends the run through the repair round, and the @\"yes\"@ after
-- it ends in the repaired arm. Delete the first row and the run rehearses the
-- clean path instead; change the second to @\"no\"@ and it rehearses the arm
-- that gives up. All three exit 0, which is the point of writing them.
--
-- __At @forge@ the defaults do the steering and they do it well.__ A flag is
-- @yes@, so the owner approves and the run enters phases 3 to 6; a verdict is
-- @APPROVE@, so the suite passes and the assessment settles on the first round
-- — which is the @SettledOn@ arm, @forge@'s \"ready to merge\". The remediation
-- author's row is written anyway, because a table that only covers the path
-- taken goes stale the first time the assessment objects.
effortScript :: Tier -> [(Text, Text)]
effortScript Forge =
  [ (forgeResearchBrief, investigated),
    (forgeBriefSynthesis consensusRoster, researchBriefAnswer),
    (forgePlanBrief, planned),
    (forgeRefineBrief, refined),
    (baselineBrief, " M src/Lex.hs\n?? src/Lex.hs.orig"),
    (changesBrief, diffed),
    (forgeReviewBrief, reviewed),
    (forgeAssessmentBrief, assessed),
    (forgeRemediationBrief, remediated)
  ]
    <> [(lensBrief l, seatAnswer l) | l <- consensusRoster]
    <> [(lensBrief l, criticAnswer l) | l <- critiqueRoster]
  where
    investigated =
      [wft|
      Root cause: `Lex.hs` re-enters `scanToken` after a partial match without
      resetting `pos`, so a two-character operator at a buffer boundary is
      reported at the wrong column. Read off the code: the reset is in the
      success arm only. Inferred: that the boundary is the only trigger.|]

    researchBriefAnswer =
      [wft|
      Problem: wrong column on a boundary-split operator. Root cause: `pos` is
      reset in the success arm of `scanToken` only. Constraints: the diagnostics
      format has downstream consumers. Agreement: both partners accept the root
      cause. Disagreement: partner-1 wants the reset hoisted, partner-2 wants
      the boundary case tested first. Planning should do both, test first.|]

    planned =
      [wft|
      1. tests/Lex.hs -- add the boundary case, expected column 7. 2. src/Lex.hs
         -- hoist the `pos` reset out of the success arm. 3. Run `make test`.
         Rollback: revert step 2; step 1 stands on its own.|]

    refined =
      [wft|
      1. tests/Lex.hs -- add the boundary case, expected column 7. 2. src/Lex.hs
         -- hoist the `pos` reset. 3. `make test`. 4. Check the two downstream
         consumers of the diagnostics format still parse it.
      Concerns addressed: partner-1's hoist -- accepted, step 2. partner-2's
      test-first -- accepted, step 1 precedes step 2. partner-2's format concern
      -- accepted as step 4.|]

    -- fixture bytes, not prose: a unified diff, trailing newline and all. The
    -- fence carries the exact bytes; the trailing newline is spliced, because a
    -- fence never ends in one.
    diffed =
      [wft|
      --- a/src/Lex.hs
      +++ b/src/Lex.hs
      @@
      -  scanToken s = case match s of Just t -> reset (advance t); Nothing -> s
      +  scanToken s = reset (case match s of Just t -> advance t; Nothing -> s)|]
        <> "\n"

    reviewed =
      [wft|
      Correctness: the hoist fixes the reported case and the added test pins it.
      Security: nothing in scope. Performance: one extra `reset` on the miss
      path, constant. Architecture: matches the plan. Test coverage: the
      boundary case is covered; the three-character operator is not.|]

    -- An approve word and nothing else, because that is what
    -- `Agentic.Text.approvesB` reads: a verdict answer carrying a sentence
    -- AND the word is an objection carrying both, and the run would end in
    -- `UnsettledOn` -- "needs fixes" -- with nothing having gone wrong.
    assessed = "APPROVE"

    remediated =
      [wft|
      Remediation: added the three-character boundary case to tests/Lex.hs. The
      critique's Medium entry now reads: covered by `tests/Lex.hs:boundary3`.
      Every other entry unchanged.|]

    seatAnswer l =
      "On " <> lensOwns l <> ": one point worth acting on, from the " <> lensName l <> " seat."

    criticAnswer l =
      "Medium -- " <> lensOwns l <> ": one finding, and no Critical from the " <> lensName l <> " seat."
effortScript t =
  [ (toolkitStandard, planned),
    (repairDiagnoseBrief, diagnosed),
    -- The gate objects the first time and approves the second, so the scripted
    -- run walks the repair round rather than stepping over it.
    (gateBrief, "no"),
    (regateBrief, "yes")
  ]
    <> partnerRows
  where
    partnerRows
      | t == Heavy = [(lensBrief l, seatAnswer l) | l <- consensusRoster]
      | otherwise = []

    planned =
      [wft|
      1. src/Lex.hs -- hoist the `pos` reset out of `scanToken`'s success arm.
         2. tests/Lex.hs -- add the boundary case, expected column 7. Order:
         test first. Check: `make test`. On failure: report the failing column
         rather than adjusting the expectation.|]

    diagnosed =
      [wft|
      Cause: `src/Lex.hs:41` shadows `pos` with the hoisted binding, so
      `-Wname-shadowing` fires. Rename the outer binding to `pos0`; do not add a
      pragma.|]

    seatAnswer l =
      "On " <> lensOwns l <> ": one point worth acting on, from the " <> lensName l <> " seat."
