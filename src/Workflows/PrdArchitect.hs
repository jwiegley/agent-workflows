-- |
-- Module      : Workflows.PrdArchitect
-- Description : The requirements agent, split at the mode boundary — one program
--               that drafts, one that critiques.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                 | here                                                          |
-- +===========================================+===============================================================+
-- | @agents\/prd-architect.md@ §§1–3, 5–6     | @prd-draft@ — discovery, the eight sections, the Task Master   |
-- |                                           | format, and the self-verification checklist                    |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @agents\/prd-architect.md@ §4             | @prd-critique@ — the seven analysis axes and the five-part     |
-- | (\"Feedback & Analysis Mode\")            | structured feedback                                            |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its §1 discovery questions                | 'discoveryBrief', asked of @'Workflows.Parties.owner'@ __in    |
-- |                                           | binding position__: every section below reads his answers       |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its \"__Validate assumptions__: repeat    | 'paraphraseBrief' then a @'Agentic.Workflow.confirm'@ — a       |
-- | back your understanding and confirm       | paraphrase somebody wrote and a yes\/no somebody answered,     |
-- | before proceeding\"                       | with an arm for the no                                         |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its §2 eight required sections            | 'sectionRoster' — eight lenses over one confirmed              |
-- |                                           | understanding, folded into one document                        |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its \"@[TODO: User input needed]@\"       | 'Workflows.Deciders.todosOutstanding' — zero questions, and    |
-- |                                           | an ending that goes back to the owner rather than to a         |
-- |                                           | reviewer                                                       |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its @## Self-Verification Checklist@      | 'checklistBrief', applied by                                   |
-- | (nine items)                              | @'Workflows.Escalation.escalating'@ on a different engine      |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its §6 (\"place the PRD at               | 'prdPath' plus a @test -f@ flag: the \"if one does not already |
-- | @.taskmaster\/docs\/prd.txt@ by default   | exist\" clause is the branch between the two rows              |
-- | if one doesn't already exist\")           |                                                                |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its §4 seven analysis dimensions          | 'critiqueRoster' — seven lenses over the document              |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its §4 \"Question Framework\"             | 'critiqueClosing' — the three templates, as the form every     |
-- |                                           | axis's findings take                                           |
-- +-------------------------------------------+---------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The rework is the split, and this is what it bought
--
-- @doc\/design.md@ §7.3 marks @prd-architect@ __R__→2×T: \"two agents in one file
-- — a generator and a critic — selected by an unstated condition. Split at the
-- mode boundary into @prd-draft@ and @prd-critique@ __before__ writing either.
-- Unanimous.\" The unstated condition is the file's own §4 opening: \"when asked
-- to provide feedback on an existing PRD\". Asked by whom, and recognised how, the
-- file does not say — so a single agent holds two output contracts and picks
-- between them by reading the room.
--
-- Split, four things become true that could not be:
--
--   1. __Two prices.__ @prd-draft@ costs eight sections plus a discovery turn
--      plus a bounded verification; @prd-critique@ costs seven axes and a fold.
--      An operator reads both before spending either, and the fused file has one
--      number for both, which is no number.
--
--   2. __Two output contracts, neither of which can be reached from the other's
--      arm.__ The draft ends in a Task Master document; the critique ends in the
--      five-part structured feedback. In the corpus a run that was asked for
--      feedback and produced a PRD is a mode error nobody can see.
--
--   3. __The mode condition becomes a receipt.__ \"Place the PRD at
--      @.taskmaster\/docs\/prd.txt@ by default __if one doesn't already exist__\"
--      is §6's own clause, and it is the discriminator the file needed and never
--      used: a @test -f@ is what decides, @prd-draft@ refuses to overwrite a PRD
--      that stands, and its refusal names @prd-critique@. The two rows are each
--      other's arms.
--
--   4. __The critique cannot edit.__ Every question in @prd-critique@ is asked at
--      @text@, and @Agentic.Acp.permissionByCode@ grants write authority only to
--      an act at @receipt@ — so the row that gives feedback on a document
--      structurally cannot改 it. The corpus's §4 has no such guarantee and its
--      §3 step 2 (\"incorporate user feedback immediately\") is in the same file.
--
-- == The leveling-up, item by item
--
--   1. __\"Ask before assuming\" is a person's question in binding position.__
--      The file's §1 is seven questions and its interaction guideline is \"ask
--      rather than guess\"; in the corpus both are addressed to an agent that
--      may or may not have a person to ask. Here 'discoveryBrief' is asked of
--      @'Workflows.Parties.owner'@ and every section below is bound after it, so
--      the eight section questions are unreachable without his answer.
--
--   2. __\"Validate assumptions … confirm before proceeding\" is a branch.__ It
--      needs two turns and the corpus gives it none: somebody has to write the
--      paraphrase, and somebody else has to accept it. Here a party writes it,
--      the owner confirms it, and the @no@ arm reports what was misunderstood
--      without drafting a line — which is the cheapest correct ending this row
--      has.
--
--   3. __@[TODO]@ becomes decidable, and it decides the right thing.__ Checklist
--      item 9 is \"no @[TODO]@ items remain without user acknowledgment\", which
--      in the corpus is a box a model ticks about its own document.
--      'Workflows.Deciders.todosOutstanding' reads it for nothing, and the arm it
--      chooses goes back to the __owner__ rather than to a reviewer: a draft with
--      open questions in it does not need a reviewer's opinion, it needs the
--      answers. That saves the verification budget for a draft that is complete.
--
--   4. __The checklist is applied by somebody who did not write the draft.__ Nine
--      items, self-applied in the corpus, and the ninth is about the document's
--      own honesty. The judge is @'Workflows.Parties.lateral'@ and the author is
--      @'Workflows.Parties.reasoning'@, which is
--      "Workflows.Rubrics.Voice"'s argument again.
--
--   5. __The eight sections cannot be silently dropped.__ They are a roster, so
--      the fold names every one of them and
--      @'Workflows.Panels.refusingSynthesis'@'s accounting is available to the
--      critique's fold as well. \"Your PRDs must include these comprehensive
--      sections\" is a sentence in the corpus and a list here.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.PrdArchitect
  ( -- * The two modes
    Mode (..),
    prdName,
    prdDoc,
    prdHelp,

    -- * The tier-1 readings of an invocation
    prdPath,

    -- * The rosters
    sectionRoster,
    critiqueRoster,

    -- * The rubrics, transplanted
    discoveryBrief,
    paraphraseBrief,
    validateBrief,
    assembleBrief,
    checklistBrief,
    reviseBrief,
    critiqueClosing,
    feedbackBrief,

    -- * The programs
    prdProgram,
    prdScript,

    -- * The function
    prdReportFn,
    prdTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The two modes
-- ---------------------------------------------------------------------------

-- | The two agents @agents\/prd-architect.md@ is.
data Mode
  = -- | §§1–3, 5–6 — the generator.
    Draft
  | -- | §4 — the critic.
    Critique
  deriving (Eq, Show)

-- | The name the operator types.
prdName :: Mode -> Text
prdName Draft = "prd-draft"
prdName Critique = "prd-critique"

-- | The one line @wf list@ prints beside a row.
prdDoc :: Mode -> Text
prdDoc Draft =
  "prd-architect.md (the generator): the owner's answers in binding position, eight sections as a roster, and the checklist applied elsewhere"
prdDoc Critique =
  "prd-architect.md §4 (the critic): seven analysis axes over a document nothing in the row can write to"

-- | The page @wf help \<mode\>@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- __Two bodies, because the split is what the rework bought.__ One file was two
-- agents; splitting it at the mode boundary gave them different inputs — the
-- generator needs the goals and the format authority, the critic needs a path —
-- and a shared inputs paragraph would be the fused file's one number for both
-- jobs, in prose.
--
-- __It states no price.__ The header above it carries the numbers off the same
-- 'Agentic.Plan.Facts' @wf list@ publishes.
prdHelp :: Mode -> Text
prdHelp Draft =
  [wft|
  `agents/prd-architect.md` as a program, the generator half: the owner's
  answers to seven discovery questions **in binding position**, eight sections
  written as a roster over them, and the format checklist applied by somebody
  who did not write the document.

  **Inputs.**

  * `goals` — the design goals the document is *for*, and `--input-file
    goals=doc/GOALS.md` is the natural spelling. They are data the discovery
    questions are asked against, so an empty one is a discovery from nothing.
  * `template` — the format authority, as a file **in your own project**. This
    is what makes "follow the house format" a table the run was given rather
    than a convention it half-remembers.
  * `prd` — where the document goes, as a path. Empty is the source file's own
    default, which the plan prints, so a run that would have written somewhere
    unexpected says so before it starts.

  **Transport.** A watched pane. It asks the owner seven discovery questions in
  binding position — the document is written *from* his answers — and an
  unattended run reaches nobody: `--scripted` answers them from a table and an
  adapter of the run's own has no one to ask.
  {paneNote}

  ```sh
  wf run prd-draft --session "$PANE" --require-pinned \
     --input-file goals=doc/GOALS.md \
     --input-file template=.taskmaster/templates/example_prd.txt \
     --input-arg prd=.taskmaster/docs/prd.txt
  ```

  **Rehearsal.** All three inputs named empty, every question answered from the
  row's own canned table, consulting nobody:

  ```sh
  wf run prd-draft --scripted --input-arg goals= --input-arg template= --input-arg prd=
  ```

  **Caveats.**

  * **The cheapest ending is a refusal to overwrite.** A `test -f` says a
    document already stands at that path, and the run reports it and names
    `prd-critique` instead of writing over work somebody did. Moving the old
    file is a deliberate act and is yours.
  * There are two other cheap endings — a discovery the owner did not confirm,
    and open questions he could not settle — and both are honest stopping points
    rather than failures.
  * A rehearsal exercises the loop and not the discovery. Canned answers are not
    the owner's, which is why the pane above is a requirement rather than
    advice.
  |]
prdHelp Critique =
  [wft|
  `agents/prd-architect.md` §4 as a program, the critic half: seven analysis
  axes over a requirements document that **nothing in this row can write to**.
  It reads, it judges, and the artefact is the critique.

  **Inputs.**

  * `prd` — the path to the document under critique. It is the *only* input this
    row declares, and it is argv rather than contents: the run probes for the
    file, so a path that names nothing is an ending rather than an empty
    reading. Empty is the source file's own default path, printed by the plan.

  **Transport.** Fine anywhere: it reads one document, runs seven axes over it
  and writes a critique. An adapter of the run's own is the usual shape.

  ```sh
  wf run prd-critique --engine acp --adapter claude --require-pinned \
     --input-arg prd=.taskmaster/docs/prd.txt
  ```

  **Rehearsal.** The one input named empty, every question answered from the
  row's own canned table, consulting nobody:

  ```sh
  wf run prd-critique --scripted --input-arg prd=
  ```

  **Caveats.**

  * **Nothing here can revise the document**, which is correct for a row whose
    whole job is to read: there is no revision loop, because there is nothing in
    the row that could write. Acting on the critique is `prd-draft`'s or yours.
  * The cheapest ending is the probe finding no document at the path — seven
    analysis axes over a file that does not exist were not run, and the run says
    which path it looked at.
  |]

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | Where the PRD lives.
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and zero paths, and it is in the printed argv.
--
-- /Source:/ @agents\/prd-architect.md@ §6, verbatim: \"place the PRD at
-- @.taskmaster\/docs\/prd.txt@ by default if one doesn't already exist.\" An
-- absent input is that default; a given one is taken as the whole path, because
-- an operator who names a file means that file.
prdPath :: Text -> Text
prdPath p
  | T.null (T.strip p) = ".taskmaster/docs/prd.txt"
  | otherwise = T.strip p

-- ---------------------------------------------------------------------------
-- The eight sections
-- ---------------------------------------------------------------------------

-- | The eight sections @agents\/prd-architect.md@ §2 says a PRD \"must include\".
--
-- /Source:/ its eight @####@ headings, each with its own bullet list, in its own
-- order. A roster rather than a section list, so that the fold names every one of
-- them and a PRD missing a section is visible rather than merely shorter.
--
-- __The roster is fixed at eight, so house rule WR-1 has nothing to say here__:
-- no input shapes it, and @'Agentic.Workflow.panelText' []@ is unreachable.
sectionRoster :: Roster
sectionRoster =
  [ Lens
      { lensName = "stack",
        lensOwns = "the languages, frameworks, databases, infrastructure and build tools, each with its justification",
        lensParty = reasoning (model "prd-stack"),
        lensBrief =
          [wft|
          Write the Technology Stack section.

          - the primary programming language or languages, WITH VERSIONS;
          - the frameworks -- web, mobile, backend -- with versions;
          - the database systems, SQL or NoSQL, with a justification for the
            choice;
          - the infrastructure and deployment platforms;
          - the development tools and build systems;
          - a justification for every major technology choice.

          A version constraint you were not told is a `[TODO:` line, not a
          guess: a version invented here becomes a dependency somebody
          installs.|]
      },
    Lens
      { lensName = "testing-strategy",
        lensOwns = "unit, integration and end-to-end testing, performance, security, CI and test data",
        lensParty = reasoning (model "prd-testing"),
        lensBrief =
          [wft|
          Write the Testing Strategy section.

          - the unit testing framework, and the coverage target;
          - the integration testing approach;
          - the end-to-end methodology;
          - performance and load testing requirements;
          - security testing considerations;
          - how testing integrates with the CI/CD pipeline;
          - the test data management strategy.

          Every item here must be something a person could later check was
          done. "Comprehensive testing" is not one.|]
      },
    Lens
      { lensName = "requirements",
        lensOwns = "the four requirement families, each item with an ID, acceptance criteria, a priority and its dependencies",
        lensParty = reasoning (model "prd-requirements"),
        lensBrief =
          [wft|
          Write the Requirements section, in the four families and in this
          order, using these ID prefixes exactly:

          - FUNCTIONAL REQUIREMENTS -- user-facing features and capabilities.
            `FR-001: <feature name>` and up.
          - NON-FUNCTIONAL REQUIREMENTS -- performance, security, scalability.
            `NFR-001: <requirement>` and up.
          - TECHNICAL REQUIREMENTS -- architecture, APIs, data models.
            `TR-001: <component>` and up.
          - INTEGRATION REQUIREMENTS -- external systems and APIs.
            `IR-001: <integration>` and up.

          Every requirement carries all five of: its unique identifier; a
          clear, TESTABLE description; its acceptance criteria; its priority
          (Critical, High, Medium or Low); and its dependencies on other
          requirements by ID.

          Be specific. "Fast" and "secure" are not requirements -- a measurable
          criterion is. A requirement nobody could write a test for is a
          paragraph in the wrong section.|]
      },
    Lens
      { lensName = "documentation",
        lensOwns = "API docs, code documentation standards, decision records, user guides, ops docs and versioning",
        lensParty = broad (model "prd-documentation"),
        lensBrief =
          [wft|
          Write the Documentation Strategy section.

          - the API documentation approach -- OpenAPI, or whatever this project
            uses;
          - the code documentation standard, by language;
          - architecture decision records: where they live and when one is
            required;
          - user documentation and guides;
          - deployment and operations documentation;
          - the changelog and versioning strategy.|]
      },
    Lens
      { lensName = "layout",
        lensOwns = "the directory structure, module organisation, configuration locations and asset management",
        lensParty = broad (model "prd-layout"),
        lensBrief =
          [wft|
          Write the File Organization section.

          Give the project structure as a tree, then state:

          - the directory structure and the naming conventions;
          - the module organisation principles -- what decides which directory
            a new file goes in;
          - where configuration files live;
          - how assets and resources are managed.

          The tree is the part people will actually follow, so make it the
          project's own rather than a generic one: it must reflect the stack
          and the requirements sections beside it.|]
      },
    Lens
      { lensName = "testing-guidelines",
        lensOwns = "coverage requirements, the testing pyramid, mocking policy, naming and benchmarking",
        lensParty = broad (model "prd-guidelines"),
        lensBrief =
          [wft|
          Write the Testing Guidelines section -- the standards, as distinct
          from the strategy above.

          - the code coverage requirement, as a number;
          - the testing pyramid ratios: unit to integration to end-to-end;
          - the mocking and stubbing policy, including what must never be
            mocked;
          - test naming conventions;
          - how tests run during development, not only in CI;
          - the performance benchmarking approach.|]
      },
    Lens
      { lensName = "flow",
        lensOwns = "branching, review, commits, pull requests, the definition of done, releases and hotfixes",
        lensParty = reasoning (model "prd-flow"),
        lensBrief =
          [wft|
          Write the Development Flow section.

          - the git branching strategy;
          - the code review process, and what a review must cover;
          - commit message conventions;
          - the pull request template and its checklist;
          - the DEFINITION OF DONE for a task -- state it as a conjunction of
            checkable clauses, because this is the one item in the whole
            document that decides when work stops;
          - the release and deployment process;
          - the hotfix procedure.|]
      },
    Lens
      { lensName = "dependencies",
        lensOwns = "every major dependency with its version, purpose, licence, security posture and alternatives",
        lensParty = broad (model "prd-dependencies"),
        lensBrief =
          [wft|
          Write the Dependencies section. For each major dependency:

          - the package name and its version constraint;
          - its purpose, and the justification for taking it;
          - licence compatibility, verified rather than assumed;
          - security considerations;
          - the update and maintenance strategy;
          - the alternatives that were considered, and why this one.

          A dependency whose licence you cannot verify from what you were given
          is a `[TODO:` line. A licence guessed here is a legal claim nobody
          made.|]
      }
  ]

-- ---------------------------------------------------------------------------
-- The seven analysis axes
-- ---------------------------------------------------------------------------

-- | The seven dimensions @agents\/prd-architect.md@ §4 analyses an existing PRD
-- against.
--
-- /Source:/ its @Analyze Against Best Practices@ list, one lens per bullet, in
-- its order. Each was a phrase there and is a question here, and the difference
-- shows in what a member can be held to: \"Completeness: are all essential
-- sections present and detailed?\" is a question about a specific list, and the
-- list is 'sectionRoster'.
critiqueRoster :: Roster
critiqueRoster =
  [ Lens
      { lensName = "completeness",
        lensOwns = "whether every required section is present and detailed enough to act on",
        lensParty = reasoning (model "prd-completeness"),
        lensBrief =
          [wft|
          Judge COMPLETENESS. The eight sections a PRD must carry are:

          {sections}

          For each one: present and detailed, present and thin, or absent. A
          section that exists as a heading with a sentence under it is thin,
          and thin is a finding.

          Then: which requirements have no acceptance criteria, which have no
          priority, which have no ID, and which reference a dependency by an ID
          that appears nowhere.|]
      },
    Lens
      { lensName = "clarity",
        lensOwns = "whether every requirement is unambiguous and testable",
        lensParty = reasoning (model "prd-clarity"),
        lensBrief =
          [wft|
          Judge CLARITY. A requirement is clear when two people who read it
          build the same thing, and testable when one of them could write the
          test before either builds anything.

          Find and quote every requirement that is neither. The usual failures:
          an unquantified adjective ("fast", "secure", "scalable"), a passive
          construction with no actor, a compound requirement that is really
          three, and an acceptance criterion that restates the description.

          For each one, propose the measurable version.|]
      },
    Lens
      { lensName = "consistency",
        lensOwns = "whether the technology choices, the requirements and the structure agree with each other",
        lensParty = reasoning (model "prd-consistency"),
        lensBrief =
          [wft|
          Judge CONSISTENCY. This is the axis nobody checks, because it needs
          two sections held open at once.

          - do the technology choices support every requirement, and is any
            choice unjustified by any requirement?
          - does the file organisation reflect the architecture the technical
            requirements describe?
          - do the testing strategy and the testing guidelines agree about
            coverage, framework and pyramid?
          - does any requirement contradict another? Name both IDs.
          - is the terminology the same throughout, or does one section's
            "service" mean another's "component"?|]
      },
    Lens
      { lensName = "feasibility",
        lensOwns = "whether the timelines, the complexity estimates and the team size can hold together",
        lensParty = lateral (model "prd-feasibility"),
        lensBrief =
          [wft|
          Judge FEASIBILITY. Are the timelines and complexity estimates
          realistic for the team and the stack described?

          Say what you are reasoning from, and say plainly where the document
          gives you nothing to reason from -- a PRD with no team size and no
          timeline is not infeasible, it is unestimated, and those are
          different findings.

          Name the two or three requirements that will take longest and say
          why. A feasibility review that names no specific requirement is an
          opinion about the whole document, which nobody can act on.|]
      },
    Lens
      { lensName = "maintainability",
        lensOwns = "whether the architecture as described stays workable after the first year",
        lensParty = reasoning (model "prd-maintainability"),
        lensBrief =
          [wft|
          Judge MAINTAINABILITY. Read the architecture, the file organisation
          and the dependencies as they will look after a year of change.

          - which boundary will be the first one somebody routes around?
          - which dependency is the one that will pin a language version?
          - what in the development flow will be skipped first when the
            schedule is tight, and does the definition of done prevent that?
          - what is described here that will need to be rewritten rather than
            extended when a stated non-functional requirement doubles?|]
      },
    Lens
      { lensName = "security",
        lensOwns = "whether security is addressed as requirements rather than as a heading",
        lensParty = reasoning (model "prd-security"),
        lensBrief =
          [wft|
          Judge SECURITY. Is it addressed adequately, and is it addressed as
          REQUIREMENTS with acceptance criteria rather than as a section
          heading?

          - authentication and authorisation: stated, with the model named?
          - secrets: where they live, and who can read them?
          - the data the system holds, and what its exposure would cost?
          - input handling at every boundary the integration requirements
            name?
          - the security testing in the strategy: does it test any of the
            above, or does it name a tool?

          A PRD that says "security is a priority" and carries no NFR about it
          has not addressed security. Say so in those terms.|]
      },
    Lens
      { lensName = "scalability",
        lensOwns = "whether the design supports the growth the document claims to plan for",
        lensParty = broad (model "prd-scalability"),
        lensBrief =
          [wft|
          Judge SCALABILITY. Does the design support the growth the document
          describes?

          Find the stated numbers -- users, requests, data volume, latency --
          and for each one say which part of the described architecture is the
          first to become the constraint. Where there are no numbers, that is
          the finding: a scalability requirement without a number is a wish,
          and the document should carry the number or say it does not know it
          yet.|]
      }
  ]
  where
    sections = rosterTable sectionRoster

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | The discovery questions, put to the owner.
--
-- /Source:/ @agents\/prd-architect.md@ §1 — its seven bullet questions verbatim,
-- its \"identify gaps proactively\" clause, and its interaction guideline \"ask
-- before assuming: when details are unclear, ask rather than guess\".
discoveryBrief :: Text
discoveryBrief =
  [wft|
  Before a line of this PRD is written, seven questions. Answer the ones you
  can and say "don't know" to the rest -- a "don't know" here becomes a marked
  open question in the document, which is the right place for it, and a guess
  here becomes a requirement somebody builds.

  1. What is the core problem this software solves?
  2. Who are the primary users, and what are their key workflows?
  3. What are the critical success metrics?
  4. Are there performance, scalability or security requirements, and what are
     the numbers?
  5. What is the deployment environment and the infrastructure?
  6. Are there existing systems to integrate with?
  7. What is the expected timeline and team size?

  And three gaps that are usually left unstated, so they are asked here rather
  than filled in later by whoever writes that section: the testing strategy,
  the documentation approach, and any technology choice that is already made
  and not up for discussion.

  Everything in the document that follows is built from this answer. Nothing
  else in this run will ask you anything.|]

-- | The paraphrase, written by a party and confirmed by the owner.
--
-- /Source:/ §1's third bullet: \"__Validate assumptions__: repeat back your
-- understanding and confirm before proceeding with PRD generation.\" Two turns,
-- because it is two acts — writing a paraphrase and accepting one — and the
-- corpus gives it one line.
paraphraseBrief :: Text
paraphraseBrief =
  [wft|
  Repeat back, in your own words, what you now understand this project to be.
  This is read by the person who answered the questions, and he will accept it
  or not; the whole document is built from whatever he accepts.

  Cover, in one short paragraph each:

  - the problem, and who has it;
  - the primary users and their main workflows;
  - what success is measured by;
  - the constraints that are already fixed -- environment, integrations,
    technology decisions already made;
  - the numbers you were given, quoted exactly as given.

  Then, separately, list what you are ASSUMING because you were not told. One
  line each, and be exhaustive about it: an assumption you do not list here
  becomes a requirement nobody agreed to. If you were told "don't know" about
  something, that is not an assumption, it is an open question -- list those
  separately again.

  Do not write any of the PRD here. Do not propose a technology. This turn is
  only for making sure the next eight are about the right project.|]

-- | What the owner is asked to confirm.
validateBrief :: Text
validateBrief =
  [wft|
  Is this understanding right? A yes starts the drafting; a no ends the run
  with what was misunderstood, and nothing is written.

  Read the assumptions list especially. An assumption you let through here is
  one you will find as a requirement later.|]

-- | The closing line every section lens is given.
--
-- /Source:/ §5's output format and §2's introduction. The Task Master template is
-- an @--input-file@ rather than transcribed prompt text, because \"the structure
-- in @.taskmaster\/templates\/example_prd.txt@\" is a file in the operator's
-- project and not a thing this module knows.
sectionClosing :: Text -> Text -> Text
sectionClosing template goals =
  [wft|
  The design goals this PRD is being written for:

  {goals}

  The Task Master template this document must fit, which is authoritative on
  format wherever it and this brief disagree:

  {template}

  Standing rules for your section, all four from the quality standards this
  document is held to:

  - BE SPECIFIC. Avoid "fast", "secure", "scalable" and every other
    unquantified adjective; use a measurable criterion.
  - BE PRACTICAL. Everything you specify must be implementable with the
    resources described.
  - BE CONSISTENT. Use the same terms the other sections use for the same
    things; the siblings above tell you what they own.
  - BE FORWARD-THINKING. Consider maintenance, scaling and evolution, not only
    the first release.

  And one rule about what you do not know, which is the one that matters most
  for what happens to this draft. Where the answers you were given do not
  settle something, DO NOT GUESS. Write a line of its own, beginning exactly

    [TODO: <the question, addressed to the owner>

  and carry on. Those lines are read mechanically by the program that consumes
  this document: a draft containing any of them goes back to the owner for
  answers instead of to a reviewer, which is what you want -- a reviewer's
  opinion about a section built on a guess is worth nothing.

  Report your section and nothing else. Your answer is one block of a document
  whose other blocks are your siblings', each fenced under its own name: do not
  write theirs, do not summarise the whole, and do not address any reader but
  your own section's.|]

-- | What the assembling turn is told.
--
-- /Source:/ §5's @## Output Format@ skeleton, which is the Task Master shape, and
-- §3 step 1 (\"generate a comprehensive first draft … highlight areas that need
-- user input\").
assembleBrief :: Text
assembleBrief =
  [wft|
  Assemble the PRD from the section blocks below, in the Task Master format.
  The blocks are the sections; your job is the document.

  The order:

    # <Project Name>

    ## Overview
    ## Technology Stack
    ## Requirements
    ### Functional Requirements
    ### Non-Functional Requirements
    ### Technical Requirements
    ### Integration Requirements
    ## Testing Strategy
    ## Documentation Strategy
    ## File Organization
    ## Testing Guidelines
    ## Development Flow
    ## Dependencies

  Three rules about the assembly, and they are all about not doing more than
  assembling.

  DO NOT REWRITE A SECTION. If a section is thin, it stays thin: it has been
  written by the party that owns it and a rewrite here has been reviewed by
  nobody. If two sections contradict each other, say so in the Overview under a
  line beginning "INCONSISTENT:" and leave both alone.

  CARRY EVERY `[TODO:` LINE THROUGH, unchanged and on its own line. They are
  read mechanically, and an answered-looking TODO is worse than an open one.

  WRITE THE OVERVIEW YOURSELF, from the sections -- it is the one part of this
  document that is yours. Two paragraphs: what this is, and what it is for.|]

-- | The self-verification checklist, applied by a party that did not write the
-- draft.
--
-- /Source:/ @agents\/prd-architect.md@'s @## Self-Verification Checklist@ — nine
-- items, verbatim — plus §3 step 3's four validation clauses, which are the same
-- exercise stated twice.
checklistBrief :: Text
checklistBrief =
  [wft|
  You are verifying a PRD you did not write, against the checklist its author
  is supposed to apply to itself. Apply it as a checklist: item by item, each
  with a verdict, and the verdict is about the document in front of you and not
  about how it reads.

  1. Are all required sections present and detailed? The required sections are
     Technology Stack, Testing Strategy, Requirements, Documentation Strategy,
     File Organization, Testing Guidelines, Development Flow and Dependencies.
  2. Does every requirement have a unique identifier, in the FR/NFR/TR/IR
     families?
  3. Are the technology choices justified, and are they compatible with each
     other?
  4. Does the testing strategy cover all four requirement types?
  5. Does the file organisation support the architecture the technical
     requirements describe?
  6. Are dependencies specified with versions?
  7. Is the development flow clearly defined, including the definition of done?
  8. Is the documentation strategy comprehensive?
  9. Do any `[TODO:` items remain? Say how many and which.

  Then the four validation checks:

  - internal consistency: does any section contradict another?
  - is every requirement testable and measurable?
  - do the technology choices align with the project goals?
  - are the dependencies compatible?

  An objection is one line naming the item number and the specific defect. Be
  concrete: "item 2: NFR-003 and NFR-004 both carry the id NFR-003" is
  actionable and "item 2: identifiers need work" is not.

  Approve only when every item passes. This document is going to be turned into
  tasks by a machine, and an ambiguous requirement becomes an ambiguous task.|]

-- | What the author is told on a repair trip.
reviseBrief :: Text
reviseBrief =
  [wft|
  A verifier applied the self-verification checklist to your PRD and objected.
  Produce the next version of the whole document and nothing else -- the same
  sections in the same order, no commentary about what you changed.

  Fix the item the objection names. Where fixing it needs a fact you were not
  given, do not invent the fact: write a line beginning `[TODO:` with the
  question on it and leave the requirement marked. A requirement invented to
  satisfy a checklist is worse than a marked gap, because it will be built.

  Do not delete a section to make an objection go away, and do not soften a
  requirement's acceptance criteria to make it look testable. Both are the
  failure this verification exists to catch.|]

-- | The closing line every critique lens is given.
--
-- /Source:/ §4's @Question Framework@ — its three question templates, verbatim —
-- and its five-part output structure, which the fold below produces.
critiqueClosing :: Text
critiqueClosing =
  [wft|
  You are reviewing an existing PRD on one axis. You are not editing it and you
  cannot: this question's answer is text, and nothing in this run has authority
  to write to that document. Report; do not revise.

  Put every finding in one of these three forms, which is the house form for
  this review:

  - "I notice <observation>. Have you considered <alternative or addition>?"
  - "The <section> could be strengthened by <specific suggestion>."
  - "This requirement <ID> might conflict with <other requirement ID>. Should
    we clarify the priority?"

  They are questions rather than verdicts on purpose: this document belongs to
  somebody who knows things about the project you do not, and a finding phrased
  as a question can be answered by that knowledge instead of argued with.

  Quote what you are talking about. A finding that names no section and no
  requirement ID cannot be acted on and should not be written.

  Report your axis and nothing else. Your answer is one block of a document
  whose other blocks are your siblings' -- do not judge their axes, and do not
  summarise the whole.|]

-- | The structured feedback the critique folds to.
--
-- /Source:/ §4's @Provide Structured Feedback@ — its five numbered parts,
-- verbatim — under 'Workflows.Panels.refusingSynthesis', so a fold that lost an
-- axis says so instead of ranking the axes it got.
feedbackBrief :: Roster -> Text
feedbackBrief r =
  [wft|
  {refusing}

  Then produce the structured feedback, in these five parts and this order:

  1. STRENGTHS -- what is well defined and comprehensive. Specifically, with
     section names. This part is not politeness: a reader who cannot tell which
     parts of the document are sound will re-litigate all of it.
  2. CRITICAL GAPS -- missing sections and underspecified requirements. Each
     one names the section or the requirement ID.
  3. IMPROVEMENT OPPORTUNITIES -- areas that could be stronger and are not
     gaps.
  4. RISK FACTORS -- what could go wrong if this document is built as written.
  5. SPECIFIC RECOMMENDATIONS -- actionable, with an example of the fixed form
     for each.

  Deduplicate across the axes: two reviewers reaching the same gap is one gap,
  and say that two reached it. Order parts 2 and 5 so that a reader who fixes
  them top to bottom never has to redo an earlier fix because of a later one.

  Do not rewrite the PRD, and do not attach a corrected version. That is a
  different job and it belongs to whoever owns the document.|]
  where
    refusing = refusingSynthesis r

-- | What the receipt over the existing document is introduced as.
readingBrief :: Text
readingBrief =
  [wft|
  The PRD under review, as bytes `cat` wrote. This is a receipt: whatever the
  file holds is the document, and nothing is added to it.|]

-- | What the presence probe is asked.
presenceBrief :: Text
presenceBrief =
  [wft|
  Does a PRD already stand at this path? The answer decides which of two jobs
  this run is: writing one, or reviewing one. It is asked as an exit code, so
  nothing is being judged here.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The @prd-draft@ arm where a PRD already stands.
standsNote :: Text
standsNote =
  [wft|
  Outcome: A PRD ALREADY STANDS, AND NOTHING WAS WRITTEN. `prd-architect.md` §6
  says to place the PRD at its default path "if one doesn't already exist", and
  one does. This row does not overwrite it and does not merge into it: a
  document with requirements somebody has already built against is not a draft.
  Report the path, and name `prd-critique` as the row for an existing PRD -- it
  reads the document, judges it on seven axes and cannot write to it. If the
  intent really is to start again, the existing file is moved by a person first,
  which is a deliberate act and not a side effect of a workflow.|]

-- | The @prd-draft@ arm where the understanding was not confirmed.
misunderstoodNote :: Text
misunderstoodNote =
  [wft|
  Outcome: NOT CONFIRMED -- NO PRD WAS DRAFTED. The paraphrase of the project
  was put to the owner and he did not accept it, so the eight section questions
  were never asked: every one of them is bound after his answer, which is what
  makes "validate assumptions before proceeding" a property of this program
  rather than an instruction in it. Report the understanding that was rejected,
  verbatim, with its assumptions list -- that list is the useful artefact of
  this run, because the assumption he objected to is the one that would have
  become a requirement. Then say what a second run would need to be told.|]

-- | The @prd-draft@ arm where the draft still has open questions.
openQuestionsNote :: Text
openQuestionsNote =
  [wft|
  Outcome: DRAFT WITH OPEN QUESTIONS -- NOT VERIFIED, AND DELIBERATELY NOT SENT
  TO A REVIEWER. The assembled document carries at least one `[TODO:` line,
  which means a section could not be settled from what the owner was able to
  say. A verifier's opinion about a section built on a guess is worth nothing,
  so the verification budget was not spent. Report the draft in full, then list
  EVERY open question as its own line, addressed to the owner -- that list is
  what this run is for. Do not present the document as a PRD, and do not answer
  any of the open questions in the report: the whole point of the marker is that
  nobody has.|]

-- | The @prd-draft@ arm where the checklist passed.
verifiedNote :: Text
verifiedNote =
  [wft|
  Outcome: DRAFTED AND VERIFIED. The owner's answers were paraphrased and
  confirmed before anything was written; eight sections were written by eight
  parties, each told what its siblings own; the assembly changed no section's
  text; the document carries no open question; and a party that wrote none of it
  applied the nine-item self-verification checklist and approved it. Report the
  document as the artefact. Say what this establishes and what it does not: a
  checklist that passed is a document that is internally consistent and
  specific, which is not the same as a document whose requirements are the right
  requirements -- only the owner can say that, and he has seen the paraphrase
  rather than the PRD.|]

-- | The @prd-draft@ arm where the checklist still objected.
unverifiedNote :: Text
unverifiedNote =
  [wft|
  Outcome: NOT VERIFIED. The verifier still objected after every repair trip
  this run was given, so the document below is the one the last trip produced
  and the final check objected to -- no trip was spent answering that last
  objection. Report the outstanding objection FIRST, verbatim, with the
  checklist item number it names, then the document beneath it. Do NOT describe
  this as a verified PRD. An item that survived two repairs is usually an item
  the document cannot satisfy from what the owner knew, and naming it is more
  useful than another round would have been.|]

-- | The @prd-draft@ arm where the verifier declined.
uncheckedNote :: Text
uncheckedNote =
  [wft|
  Outcome: UNCHECKED. The verifier declined to judge the document at all, so the
  nine-item checklist was applied by nobody -- and it certainly was not applied
  by its author, which is the arrangement this row exists to avoid. Report the
  document as UNCHECKED, name the eight sections and their parties, and do not
  report any checklist item as passed.|]

-- | The @prd-critique@ arm where there is nothing at the path.
absentNote :: Text
absentNote =
  [wft|
  Outcome: NOTHING TO CRITIQUE. No file stands at the path this run was given,
  so there is no PRD to analyse and nothing was asked of anybody. Report the
  path that was probed, and name `prd-draft` as the row that writes one. This
  costs two consultations and it is the correct answer: seven analysis axes over
  a document that does not exist would have produced seven readings of nothing.|]

-- | The @prd-critique@ arm where every axis reported.
critiquedNote :: Text
critiquedNote =
  [wft|
  Outcome: CRITIQUED, AND NOTHING WAS WRITTEN TO THE DOCUMENT. Seven axes --
  completeness, clarity, consistency, feasibility, maintainability, security and
  scalability -- read the same document independently, and the fold accounted
  for every one of them before ranking anything. Nothing in this run can modify
  the PRD: every question in it was asked at `text`, which has no write
  authority, so "provide feedback" and "do not edit" are one fact here rather
  than two instructions. Report the five parts as they came: strengths, critical
  gaps, improvement opportunities, risk factors, and specific recommendations.|]

-- | The @prd-critique@ arm where the fold came up short.
shortFanOutNote :: Text
shortFanOutNote =
  [wft|
  Outcome: INCOMPLETE CRITIQUE. The fold refused, because at least one axis
  produced no block; its first line names which. Label this feedback incomplete
  and name the missing axes. This matters more here than in most folds: the
  seven axes are chosen to be non-overlapping, so a missing axis is not a
  thinner review of the same thing, it is a dimension of the document nobody
  looked at.|]

-- ---------------------------------------------------------------------------
-- The function
-- ---------------------------------------------------------------------------

-- | What the report is written through.
prdReportBrief :: Text
prdReportBrief =
  [wft|
  Write the deliverable for a requirements run. What the deliverable IS depends
  on the provenance line you were given, and the provenance line is not yours
  to soften: a draft that was not verified is reported as a draft that was not
  verified, and a run that wrote nothing reports that it wrote nothing.

  Open with the provenance line, verbatim, on its own line.

  Then the work below, in full and unedited. Do not improve a requirement here,
  do not answer an open question here, and do not attach a corrected version of
  a document you were asked to critique. Everything below has been through
  whatever review it was going to get, and a change made at this point has been
  checked by nobody.

  Close with the open questions or the recommendations -- whichever the work
  below carries -- each on its own line, addressed to the person who has to act
  on it.

  Then reply DONE with the path you wrote.|]

-- | One act, eight provenance lines across the two rows.
--
-- Three parameters, in the order the body reads them: the provenance first, for
-- "Workflows.Report"'s reason; then the document or the feedback, whichever the
-- arm has; then the context — the confirmed understanding at @prd-draft@, the
-- reviewed document at @prd-critique@ — so the deliverable can say what it is
-- about without a question being spent on saying it.
prdReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
prdReportFn =
  function
    "prd.report"
    ( takes @"provenance" Text
        . takes @"document" Text
        . takes @"context" Text
        $ noParams
    )
    \provenance document context -> W.do
      act reporter [wf|
          {writing}

          Provenance:

          {provenance}

          What this run was about:

          {context}

          The work:

          {document}|]
      done
  where
    writing = prdReportBrief

-- | The table both rows hand @'Agentic.Workflow.defining'@.
prdTable :: [SomeFn]
prdTable = [SomeFn prdReportFn]

-- ---------------------------------------------------------------------------
-- The programs
-- ---------------------------------------------------------------------------

-- | The generator, and the critic — two shapes, split at the mode boundary.
--
-- @prd-draft@ takes three inputs: @goals@ is the design goals the PRD is for;
-- @template@ is @.taskmaster\/templates\/example_prd.txt@ as an @--input-file@,
-- because the format authority is a file in the operator's project; @prd@ is where
-- the document goes, and 'prdPath' carries §6's own default.
--
-- Its shape: probe the path and refuse to overwrite a PRD that stands; ask the
-- owner the seven discovery questions __in binding position__; have a party
-- paraphrase what it heard and have him confirm it, with an arm for the no; fan
-- out over the eight required sections; assemble without rewriting; read the
-- @[TODO:@ markers for nothing and go back to the owner if any stand; and only
-- then spend the verification budget, bounded, on a party that wrote none of it.
-- __Six endings, six provenance lines, one__ 'prdReportFn'.
--
-- @prd-critique@ takes one input, @prd@, and contains __no__
-- @'Agentic.Workflow.act'@ except the report: every question in it is asked at
-- @text@, and @Agentic.Acp.permissionByCode@ grants write authority only to an act
-- at @receipt@. Its shape: probe the path; read the document as a receipt; fan out
-- over the seven analysis axes; fold under a synthesis that must account for every
-- axis; read its refusal for nothing; and report. __Three endings, three
-- provenance lines, one__ 'prdReportFn'.
prdProgram :: Mode -> Parameterized
prdProgram Draft =
  taking (input "goals" :> input "template" :> input "prd" :> noInputs)
    \goals template prdArg ->
      -- Tier 1, twice: where the document goes, and what every section lens is
      -- told about the format and the goals. Both are ordinary Haskell over the
      -- invocation, and the first is in the printed argv.
      let path = prdPath prdArg
          closing = sectionClosing template goals
       in defining prdTable W.do
            -- `test -f` and not `ls`: in a project with no Task Master at all the
            -- whole directory is absent, and `ls` on a missing directory exits
            -- nonzero -- which abandons a `text` ask. An exit code asked as a
            -- flag answers "no" instead, which is the right answer.
            stands <- passes (filePresent path) [wf|{probing}|]

            if stands
              then W.do
                ask_ reporter [wf|
                    {alreadyThere}

                    The path that was probed: `{path}`.

                    The goals this run was given, which are not lost -- they are
                    what `prd-critique` should be pointed at this document with:

                    {goals}|]
              else W.do
                -- The owner, in binding position. Everything below is bound after
                -- this, so no section question is reachable without his answer.
                said <- ask owner [wf|
                    {asking}

                    The design goals this PRD is for:

                    {goals}|]

                understanding <- ask (reasoning (model "prd-understand")) [wf|
                    {paraphrasing}

                    The design goals:

                    {goals}

                    What the owner said:

                    {said}|]

                agreed <- confirm owner [wf|
                    {validating}

                    {understanding}|]

                if agreed
                  then W.do
                    sections <- panelText (zip (lensNames sectionRoster) (asksOver sectionRoster closing understanding))

                    draft <- ask (reasoning (model "prd-assemble")) [wf|
                        {assembling}

                        The sections:

                        {sections}|]

                    -- Checklist item 9, read for nothing, and it chooses the arm
                    -- that goes back to the owner rather than to a reviewer.
                    holes <- tested todosOutstanding draft

                    if holes
                      then W.do
                        call_ prdReportFn (arg openQuestionsNote :> arg draft :> arg understanding :> noArgs)
                        stop
                      else W.do
                        checked <-
                          escalating
                            (lateral (model "prd-verify"))
                            checklistBrief
                            (reasoning (model "prd-assemble"))
                            reviseBrief
                            draft
                            (atMost 2)

                        case checked of
                          SettledOn final -> W.do
                            call_ prdReportFn (arg verifiedNote :> arg final :> arg understanding :> noArgs)
                            stop
                          UnsettledOn final -> W.do
                            call_ prdReportFn (arg unverifiedNote :> arg final :> arg understanding :> noArgs)
                            stop
                          AbandonedOn final -> W.do
                            call_ prdReportFn (arg uncheckedNote :> arg final :> arg understanding :> noArgs)
                            stop
                  else W.do
                    call_ prdReportFn (arg misunderstoodNote :> arg understanding :> arg goals :> noArgs)
                    stop
  where
    probing = presenceBrief
    alreadyThere = standsNote
    asking = discoveryBrief
    paraphrasing = paraphraseBrief
    validating = validateBrief
    assembling = assembleBrief
prdProgram Critique =
  taking (input "prd" :> noInputs) \prdArg ->
    let path = prdPath prdArg
        folding = feedbackBrief critiqueRoster
     in defining prdTable W.do
          stands <- passes (filePresent path) [wf|{probing}|]

          if stands
            then W.do
              document <- ask (fileContents path) [wf|{reading}|]

              found <- panelText (zip (lensNames critiqueRoster) (asksOver critiqueRoster critiqueClosing document))

              feedback <- ask (reasoning (model "prd-feedback")) [wf|
                  {folding}

                  The axes' blocks:

                  {found}|]

              short <- tested incompleteFanOut feedback

              if short
                then W.do
                  call_ prdReportFn (arg shortFanOutNote :> arg feedback :> arg document :> noArgs)
                  stop
                else W.do
                  call_ prdReportFn (arg critiquedNote :> arg feedback :> arg document :> noArgs)
                  stop
            else W.do
              ask_ reporter [wf|
                  {nothingThere}

                  The path that was probed: `{path}`.|]
  where
    probing = presenceBrief
    reading = readingBrief
    nothingThere = absentNote

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a row answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the probe's question opens with 'presenceBrief', the
-- discovery's with 'discoveryBrief', the paraphrase's with 'paraphraseBrief', each
-- section's and each axis's with its own @'Workflows.Panels.lensBrief'@ (derived
-- from the very roster the panel is built from), the assembly's with
-- 'assembleBrief', the verification's with 'checklistBrief' and the fold's with
-- @'feedbackBrief' 'critiqueRoster'@.
--
-- __Two rows steer the whole rehearsal, and they steer it the counter-intuitive
-- way.__ @'Agentic.Exec.scriptedDefault'@ answers a flag @yes@, so with no row for
-- 'presenceBrief' a @prd-draft@ rehearsal would find a PRD already standing and
-- refuse in two consultations, while a @prd-critique@ rehearsal would find a file
-- and read it. So @prd-draft@'s table answers that probe __no__ and
-- @prd-critique@'s leaves it at the default __yes__ — and each row then walks its
-- own long path. Flipping either one rehearses the other arm, and both exit 0.
--
-- __The assembly's row is the second load-bearing one.__ It must not open a line
-- with @[TODO:@, or 'Workflows.Deciders.todosOutstanding' fires and the run takes
-- the open-questions ending having spent nothing on verification. It is written
-- without one; adding one is how that ending is rehearsed.
--
-- The two verdict rows are the bare word, for
-- @'Workflows.TranscribeImage.transcribeScript'@'s reason: @Agentic.Text.approvesB@
-- approves only a reply that /is/ an approve word and nothing else.
prdScript :: Mode -> [(Text, Text)]
prdScript Draft =
  [ -- Answered `no`, against the flag default, so the rehearsal drafts.
    (presenceBrief, "no"),
    (discoveryBrief, saidAnswer),
    (paraphraseBrief, understandingAnswer),
    (validateBrief, "yes"),
    (assembleBrief, draftAnswer),
    (checklistBrief, "APPROVE"),
    (reviseBrief, draftAnswer)
  ]
    <> [(lensBrief l, sectionAnswer (lensName l)) | l <- sectionRoster]
  where
    saidAnswer =
      [wft|
      The problem: our support team re-types the same answers into three
      systems. Primary users: eight support agents, and their key workflow is
      open ticket, find prior answer, paste, close. Success metric: median
      handle time under four minutes. Performance: 200 concurrent agents, p99
      under 300ms. Deployment: our own Kubernetes cluster. Integrations:
      Zendesk, and the internal wiki's search API. Timeline: one quarter, two
      engineers. Testing: don't know. Documentation: don't know. Already
      decided: it is TypeScript, because the team is.|]

    understandingAnswer =
      [wft|
      The project is an answer-reuse layer over an existing support stack. Users
      are eight agents whose workflow is ticket-to-paste-to-close, and success
      is measured in median handle time.

      Constraints already fixed: TypeScript, our own Kubernetes, Zendesk and the
      wiki search API as integrations, one quarter with two engineers.

      Numbers as given: 200 concurrent agents, p99 under 300ms, median handle
      time under four minutes.

      Assumptions I am making: that the wiki search API is read-only; that agent
      identity comes from the existing SSO; that there is no requirement to work
      offline.

      Open questions the owner said he does not know: the testing strategy, and
      the documentation approach.|]

    -- Deliberately does NOT open a line with `[TODO:`, so the rehearsal reaches
    -- the verification loop rather than the open-questions ending.
    draftAnswer =
      [wft|
      # Answer Reuse Layer

      ## Overview
      A service that surfaces prior support answers into the agent's ticket
      view.

      ## Technology Stack
      TypeScript 5.4, Node 22, PostgreSQL 16, deployed to the existing
      Kubernetes cluster.

      ## Requirements
      ### Functional Requirements
      FR-001: Suggest prior answers for an open ticket.
      - Acceptance: for a ticket with a known-duplicate history, the prior
        answer appears in the top three suggestions.
      - Priority: Critical. Dependencies: IR-001.
      ### Non-Functional Requirements
      NFR-001: p99 suggestion latency under 300ms at 200 concurrent agents.
      ### Technical Requirements
      TR-001: A read-only projection of the wiki index, refreshed every five
      minutes.
      ### Integration Requirements
      IR-001: Zendesk ticket events over its webhook.

      ## Testing Strategy
      Vitest for units at 80% line coverage; one integration suite against a
      containerised Postgres; a load test that asserts NFR-001.

      ## Documentation Strategy
      OpenAPI for the HTTP surface, TSDoc on exported symbols, one ADR per
      integration.

      ## File Organization
      src/api, src/ingest, src/rank, src/db; tests beside the code they cover.

      ## Testing Guidelines
      80% lines, 70:25:5 unit to integration to end-to-end, and the Zendesk
      client is the only mock permitted.

      ## Development Flow
      Trunk-based, one review per change, definition of done is: tests green,
      coverage not reduced, ADR written if an integration moved.

      ## Dependencies
      fastify 4.x (HTTP, MIT), pg 8.x (Postgres driver, MIT), zod 3.x
      (validation, MIT).|]

    sectionAnswer :: Text -> Text
    sectionAnswer n =
      [wft|
      This is the {n} section, written against the confirmed understanding and
      carrying no open question.|]
prdScript Critique =
  [ -- No row for the probe: the flag default is `yes`, which is the arm that
    -- reads the document. `(presenceBrief, "no")` reaches the other terminal.
    (readingBrief, documentAnswer),
    (feedbackBrief critiqueRoster, feedbackAnswer)
  ]
    <> [(lensBrief l, axisAnswer (lensName l)) | l <- critiqueRoster]
  where
    documentAnswer =
      [wft|
      # Answer Reuse Layer

      ## Overview
      A service that surfaces prior support answers into the agent's ticket
      view.

      ## Requirements
      FR-001: Suggest prior answers. Priority: Critical.
      NFR-001: The service should be fast.

      ## Dependencies
      fastify, pg, zod.|]

    axisAnswer :: Text -> Text
    axisAnswer n =
      [wft|
      I notice the {n} dimension is addressed in one line. Have you considered
      stating it as a requirement with an acceptance criterion? The Requirements
      section could be strengthened by giving NFR-001 a number: "should be fast"
      cannot be tested.|]

    -- Deliberately does NOT open a line with `INCOMPLETE:`: the scripted run
    -- takes the complete arm, and the other arm is reached by opening with one.
    feedbackAnswer =
      [wft|
      All seven axes accounted for.

      ## Strengths
      The Overview states the problem in one sentence, and FR-001 carries a
      priority.

      ## Critical Gaps
      NFR-001 has no number and therefore no test. Five of the eight required
      sections are absent: Technology Stack, Testing Strategy, Documentation
      Strategy, File Organization, Testing Guidelines and Development Flow.

      ## Improvement Opportunities
      FR-001 has no acceptance criterion; two reviewers reached this
      independently.

      ## Risk Factors
      Dependencies carry no versions and no licences, so the build is not
      reproducible and the licence position is unknown.

      ## Specific Recommendations
      1. Give NFR-001 a latency and a concurrency: "p99 under 300ms at 200
         concurrent agents".
      2. Add the six missing sections; the Requirements section depends on the
         stack being named first.|]
