-- |
-- Module      : Workflows.ClaudeMd
-- Description : The repository's own briefing file — written, or critiqued, and
--               never both by accident.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@     | here                                                      |
-- +===============================+===========================================================+
-- | @commands\/initialize.md@     | @claude-md@ — __reworked__: its \"if there's already a     |
-- |                               | @CLAUDE.md@\" clause split into two named outcomes, one    |
-- |                               | decider, two functions, two terminals                     |
-- +-------------------------------+-----------------------------------------------------------+
-- | @commands\/prepare-with.md@   | @claude-md-advise@ — the @$ARGUMENTS@ roster as a Haskell  |
-- |                               | table, and the eight usage notes as an auditor over the    |
-- |                               | draft rather than eight rules nothing checks               |
-- +-------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The rework, discharged: @initialize.md@
--
-- @doc\/design.md@ §8 says to do the seven reworks before wave 3, and this is one
-- of them. §7.2 row 28 states the defect exactly: the \"if one already exists\"
-- clause \"silently changes the output /kind/ (a file vs. a critique). Split it
-- into two named outcomes first; then it is one decider and two @Fn@s with two
-- terminals, and the mandatory prefix is a @lit@ that cannot be paraphrased.\"
--
-- Landed so, and the split is worth stating in the terms the corpus cannot: the
-- two outcomes have different __artefacts__ (a file the repository will carry,
-- against a document somebody reads once), different __authority__ (both write,
-- but one overwrites nothing and the other must not touch @CLAUDE.md@ at all),
-- and different __audiences__. In the corpus they are one command whose behaviour
-- turns on a condition mentioned in a bullet under @Usage notes@; here they are
-- 'claudeMdDraftFn' and 'claudeMdCritiqueFn', reached by
-- 'Workflows.Deciders.claudeMdPresent' over an @ls@ receipt, and neither can be
-- reached by accident.
--
-- == The leveling-up, item by item
--
--   1. __The decider makes the receipt after it safe.__ This is the one place in
--      the tree where a free test /licenses/ a command: @cat CLAUDE.md@ abandons
--      the run when the file is missing ("Workflows.Evidence" says so of
--      @'Workflows.Evidence.fileContents'@, and calls it the useful failure), so
--      it is asked only inside the arm a decider has already established the file
--      exists in. Zero questions decide it, and the arm that reads the file
--      cannot be entered when there is nothing to read.
--
--   2. __The mandatory prefix cannot be paraphrased.__ @initialize.md@ ends
--      \"be sure to prefix the file with the following text\" and then quotes
--      four lines. In the corpus those four lines are text inside a prompt that a
--      model reproduces from memory of having read them. 'mandatoryPrefix' is a
--      define spliced into the writing act, byte for byte, and the act is told to
--      copy it rather than to write something like it.
--
--   3. __The eight usage notes are checked by somebody.__ §7.2 row 40's own
--      clause: they \"become a @fess@-style auditor over the draft rather than
--      eight rules nothing checks\". 'claudeMdRules' is one list; the drafting
--      question is told them, and at @claude-md-advise@ a
--      @'Workflows.Parties.lateral'@ party — pinned to a primary the drafter did
--      not use — is handed the same list and the draft, and answers a verdict.
--      Four of the eight are prohibitions on /adding/ things (\"do not repeat
--      yourself\", \"do not include obvious instructions\", \"avoid listing every
--      component\", \"do not make up information\"), and a prohibition on adding
--      is exactly the kind of rule its own author is worst at checking.
--
--   4. __The @$ARGUMENTS@ roster is a table.__ @prepare-with.md@ opens \"treat
--      @$ARGUMENTS@ as the named agents to enlist\", which is a roster supplied
--      as a string and resolved by whoever reads it. 'adviserRoster' resolves it
--      in ordinary Haskell against "Workflows.Parties"' own specialists — tier 1,
--      zero questions, zero paths — so @wf plan claude-md-advise --raw@ prints
--      the panel that will actually run, and a name that resolves to nothing is
--      visibly absent from it rather than silently ignored.
--
-- == One honest note
--
-- __The survey is an act, and it has to be.__ Both files ask for an analysis of
-- the codebase, and an analysis means reading files. A question asked at
-- @'Agentic.Raw.CodeText'@ is refused the workspace for the duration of its turn
-- (@Agentic.Acp.permissionByCode@), so a \"survey the repository\" /ask/ would be
-- a question about a repository the answerer cannot open. What this program gives
-- a reading party is the @ls@ receipt; what it gives the /writing/ party is an
-- @'Agentic.Workflow.act'@, which has the authority to open what it needs. So
-- the shape is: one cheap receipt that the program branches on, and one act that
-- does the work — rather than a survey question whose answer would be a
-- plausible description of a tree nobody looked at.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.ClaudeMd
  ( -- * The rungs
    ClaudeMdRung (..),
    claudeMdName,
    claudeMdDoc,

    -- * The program
    claudeMdProgram,
    claudeMdScript,

    -- * The eight usage notes, once
    claudeMdRules,
    mandatoryPrefix,

    -- * The roster @prepare-with.md@'s @$ARGUMENTS@ becomes
    adviserRoster,

    -- * The two named outcomes
    claudeMdDraftFn,
    claudeMdCritiqueFn,
    claudeMdAdviseFn,
    claudeMdTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Workflows.Threads (proFor)
import Prelude

-- ---------------------------------------------------------------------------
-- The rungs
-- ---------------------------------------------------------------------------

-- | The two ways the owner asks for a @CLAUDE.md@.
data ClaudeMdRung
  = -- | @commands\/initialize.md@ — do it, from the repository as it stands.
    Initialize
  | -- | @commands\/prepare-with.md@ — enlist named specialists first, and have
    -- the draft audited.
    Advise
  deriving (Eq, Show)

-- | The name the operator types.
claudeMdName :: ClaudeMdRung -> Text
claudeMdName Initialize = "claude-md"
claudeMdName Advise = "claude-md-advise"

-- | The one line @wf list@ prints beside a rung.
claudeMdDoc :: ClaudeMdRung -> Text
claudeMdDoc Initialize =
  "initialize.md: one `ls` receipt decides it -- write the file, or critique the one already there"
claudeMdDoc Advise =
  "prepare-with.md: the named specialists advise, then a different engine audits the draft"

-- ---------------------------------------------------------------------------
-- The eight usage notes, once
-- ---------------------------------------------------------------------------

-- | @commands\/initialize.md@'s @Usage notes@, which @prepare-with.md@ carries
-- verbatim.
--
-- /Source:/ both files, whose usage-note blocks are byte-identical — the eight
-- rules below and the prefix. One list here, two consumers: the party that
-- drafts is told them, and at @claude-md-advise@ the party that audits is
-- handed the same list. A ninth rule reaches both by being added.
claudeMdRules :: [Text]
claudeMdRules =
  [ [wft|
    Do not repeat yourself. A thing said in two sections is a thing that will
    drift in one of them.|],
    [wft|
    Do not include obvious instructions -- "provide helpful error messages",
    "write unit tests for all new utilities", "never include secrets in code or
    commits". Every one of those is true of every repository, so none of them
    says anything about this one.|],
    [wft|
    Avoid listing every component or file structure that can be discovered by
    looking. A tree listing is not architecture.|],
    "Do not include generic development practices.",
    [wft|
    If there are Cursor rules -- in `.cursor/rules/` or `.cursorrules` -- or
    Copilot rules in `.github/copilot-instructions.md`, include the important
    parts of them.|],
    "If there is a `README.md`, include the important parts of it.",
    [wft|
    Do not make up information. Sections such as "Common Development Tasks",
    "Tips for Development" or "Support and Documentation" go in only when a file
    you actually read carries them.|],
    [wft|
    Prefix the file with the mandatory block, exactly as given, before anything
    else.|]
  ]

-- | The four lines @initialize.md@ says the file must begin with.
--
-- /Source:/ its last bullet, byte for byte. It is a define and it is spliced,
-- which is what §7.2 row 28 means by \"a @lit@ that cannot be paraphrased\": the
-- writing act is handed the text, not a description of it.
mandatoryPrefix :: Text
mandatoryPrefix =
  [wft|
  # CLAUDE.md

  This file provides guidance to Claude Code (claude.ai/code) when working
  with code in this repository.|]

-- | The two things both files ask a @CLAUDE.md@ to contain.
--
-- /Source:/ their identical @What to add@ sections.
claudeMdContent :: Text
claudeMdContent =
  [wft|
  Two things go in, and they are the two the repository cannot tell a reader
  for itself:

  1. The commands that are commonly used -- how to build, how to lint, how to
     run the tests, and how to run a SINGLE test. Whatever is needed to develop
     in this codebase, in the form somebody would actually type.
  2. The high-level architecture and structure: the big picture that takes
     reading several files to see, and that nobody can reconstruct from any
     one of them.|]

-- ---------------------------------------------------------------------------
-- The roster prepare-with.md's $ARGUMENTS becomes
-- ---------------------------------------------------------------------------

-- | The specialists an @agents@ input names, or the one general reader.
--
-- __Tier 1__: the fact is in the invocation. The names are resolved against
-- @'Workflows.Threads.proFor'@ — the same table @pr-threads-assess@ resolves
-- @assess.md@'s \"haskell-pro and\/or cpp-pro\" against, because two tables of
-- the owner's nine specialists is exactly the duplication this repository exists
-- to end.
--
-- A name that resolves to nothing is dropped, visibly: @wf plan@ prints the
-- roster that will run, so an operator who typed @rust-por@ sees a panel without
-- a Rust seat rather than a run that quietly had one fewer opinion.
--
-- __House rule WR-1__: the empty input is the default roster and never the empty
-- one.
adviserRoster :: Text -> Roster
adviserRoster names
  | null selected = [generalAdviser]
  | otherwise = selected
  where
    selected =
      [ Lens
          { lensName = n,
            lensOwns = "what a " <> n <> " reader needs to know about this repository",
            lensBrief = adviceBrief n,
            lensParty = p
          }
      | raw <- T.words (T.replace "," " " names),
        let n = T.strip raw,
        not (T.null n),
        Just p <- [proFor (T.replace "-pro" "" n)]
      ]

-- | The seat a run that named no agents is answered by.
generalAdviser :: Lens
generalAdviser =
  Lens
    { lensName = "general",
      lensOwns = "what any reader needs to know about this repository before touching it",
      lensBrief = adviceBrief "general",
      lensParty = broad (model "claude-md-general")
    }

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the directory receipt is introduced as.
--
-- /Source:/ both files' \"analyze this codebase\", which is where a run has to
-- start and which neither file gives a command for. This is the cheapest
-- possible one, and it is also what
-- 'Workflows.Deciders.claudeMdPresent' reads.
listingBrief :: Text
listingBrief =
  [wft|
  The top level of the repository this run is in, one name per line, as `ls`
  wrote it. It is the starting point and not the survey: what a briefing file
  has to say about this repository is inside these entries, not in their names.|]

-- | What the existing file is introduced as.
existingBrief :: Text
existingBrief =
  [wft|
  The `CLAUDE.md` this repository already carries, exactly as it stands on
  disk. It is the subject of what follows: it is not being replaced, and
  nothing below may overwrite it.|]

-- | What each adviser seat is asked.
--
-- /Source:/ @commands\/prepare-with.md@'s \"use those agents to deeply analyze
-- and understand the current project, so that you may provide expert guidance on
-- the construction of a @CLAUDE.md@\". The specialist's name opens the brief so
-- that the seats do not share a leading chunk.
adviceBrief :: Text -> Text
adviceBrief who =
  [wft|
  You are the {who} specialist advising on this repository's `CLAUDE.md`.

  You are not writing the file. Say what a briefing file would have to tell a
  capable newcomer about the parts of this repository you own, so that they
  could be productive without rediscovering it: the commands they would need,
  the architecture they could not infer from any single file, and the one or
  two conventions here that would surprise somebody who knows the language but
  not this codebase.

  Name the file you learned each thing from. Where you are inferring rather
  than reading, say so: guidance stated as fact and drawn from a guess is the
  failure mode of the document you are advising on.

  If this repository has nothing in your area, say exactly that in one line and
  stop. A specialist who invents a section is worse than a specialist who was
  not needed.|]

-- | What the adviser panel's blocks are told about their shape.
adviceClosing :: Text
adviceClosing =
  [wft|
  Report your advice and nothing else. Your answer is one block of a document
  whose other blocks are the other specialists', each fenced under its own name:
  do not write theirs, and do not draft the file.|]

-- | What the drafting act is told, at @claude-md@.
draftBrief :: Text
draftBrief =
  [wft|
  Analyse this codebase and write the `CLAUDE.md` it does not yet have. It
  will be given to future sessions working in this repository, and it is the
  only thing they will have read before they start.

  {content}

  The file MUST begin with exactly this block, copied character for character,
  before anything else:

  {prefix}

  The rules this document is held to:

  {rules}

  Read what you need to read -- the README, the build files, the test
  configuration, whatever rules files are present, and enough of the source to
  see the shape. Then write the file, and reply DONE.|]
  where
    content = claudeMdContent
    prefix = mandatoryPrefix
    rules = numbered claudeMdRules

-- | What the critiquing act is told, at @claude-md@.
--
-- /Source:/ @initialize.md@'s \"if there's already a @CLAUDE.md@, suggest
-- improvements to it\" — the clause that is the whole of the rework, given the
-- output kind it always implied and never named.
critiqueBrief :: Text
critiqueBrief =
  [wft|
  This repository already carries a `CLAUDE.md`. You are NOT rewriting it and
  you are NOT to modify it: write a critique of it, as its own document, and
  leave the file exactly as it stands.

  Write `CLAUDE-review-<date>.md` in the current directory. In it, three
  sections and nothing else:

  - What is missing. Each item names the command, the architectural fact or
    the convention that is absent, and the file you learned it from.
  - What is wrong. Each item quotes the line and says what the repository
    actually does now.
  - What should come out. Each item quotes the line and names which of the
    rules below it violates.

  {content}

  The rules the existing file is being judged against:

  {rules}

  Every item is a suggested edit somebody could apply without asking you a
  question: quote what stands, and give what should stand in its place. A
  critique that says a section "could be improved" has said nothing. Then reply
  DONE.|]
  where
    content = claudeMdContent
    rules = numbered claudeMdRules

-- | What the drafting question is asked at @claude-md-advise@.
--
-- Unlike 'draftBrief' this is an @ask@ and not an act: the specialists have
-- already read the repository, this question folds their advice into a draft, and
-- the draft is then audited before anything is written. That is the whole
-- difference between the two rungs — one writes and stops, the other drafts,
-- is checked, and then writes.
adviseDraftBrief :: Text
adviseDraftBrief =
  [wft|
  Draft the `CLAUDE.md` for this repository, from the specialists' advice
  below and the directory listing beside it. Answer with the file's contents
  and nothing else: no preamble, no commentary, no fences around it.

  {content}

  The file MUST begin with exactly this block, copied character for character,
  before anything else:

  {prefix}

  The rules this document is held to:

  {rules}

  Where two specialists disagree, say what each observed rather than choosing
  between them silently. Where an adviser said their area is not present here,
  write nothing about it.|]
  where
    content = claudeMdContent
    prefix = mandatoryPrefix
    rules = numbered claudeMdRules

-- | The auditor @doc\/design.md@ §7.2 row 40 asks for.
--
-- /Source:/ the eight usage notes, turned round: in the corpus they are
-- instructions to the writer, and here the same list is the checklist somebody
-- else holds the draft to. The shape is @agents\/fess-auditor.md@'s — a stance
-- over an artefact, answering a verdict, on a party that produced none of it.
auditBrief :: Text
auditBrief =
  [wft|
  You are auditing a `CLAUDE.md` draft you did not write, against the rules it
  was written under. You are not improving it: you are saying whether it holds.

  The rules:

  {rules}

  Four of those are prohibitions on ADDING, and they are the ones to be strict
  about, because a draft that breaks them looks thorough: a repeated
  instruction, an obvious instruction true of every repository, an exhaustive
  file listing where architecture was asked for, and an invented section that
  no file the drafter read carries. Quote the offending text in each objection.

  Check three more things and object with each failure:

  - the mandatory prefix block stands first, character for character;
  - every command it gives is one somebody could type, including the way to run
    a single test;
  - the architecture section says something that could not be read off any one
    file.

  {spec}|]
  where
    rules = numbered claudeMdRules
    spec = verdictSpec

-- | What the @claude-md-advise@ artefact act is told.
adviseWriteBrief :: Text
adviseWriteBrief =
  [wft|
  Write the audited draft to `CLAUDE.md` in the current directory.

  You are transcribing: write the draft below exactly as it stands, beginning
  with its mandatory prefix block. Do not edit it, do not reformat it, and do
  not act on the audit yourself.

  If the provenance line you were given says the audit objected or did not
  answer, do NOT write `CLAUDE.md` at all: write the draft to
  `CLAUDE-draft-<date>.md` instead, with the audit's own lines at the top under
  the heading `Audit`, so that a person decides whether it becomes the
  repository's briefing file. Then reply DONE.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where there was no file.
writtenNote :: Text
writtenNote =
  [wft|
  Provenance: the repository's top level was read with `ls`, no `CLAUDE.md`
  stood in it -- a test over the listing's own bytes -- and one was written,
  beginning with the mandatory prefix block as given. Nothing was overwritten,
  because there was nothing there to overwrite.|]

-- | The arm where there was one.
critiquedNote :: Text
critiquedNote =
  [wft|
  Provenance: the repository already carries a `CLAUDE.md`, so this run produced
  a CRITIQUE of it and did not touch it. The existing file is quoted in the
  critique and is otherwise exactly as it was. Do not report this run as having
  written or updated the repository's briefing file.|]

-- | @claude-md-advise@, where the audit approved.
auditedNote :: Roster -> Text
auditedNote r =
  [wft|
  Provenance: this draft was built from {readings} specialist reading(s) of the
  repository, folded once, and then audited against the eight standing rules by
  a party pinned to a serving model none of them used -- which approved. The
  audit is somebody else's, which is what makes it an audit.|]
  where
    readings = tshow (length r)

-- | Where it objected.
auditObjectedNote :: Text
auditObjectedNote =
  [wft|
  Outcome: THE AUDIT OBJECTED. The draft below did not hold against the standing
  rules; the objection lines are given with it and each quotes what it is about.
  Do NOT write this draft to `CLAUDE.md`: a briefing file every future session
  reads is exactly the wrong place for a rule violation to land unnoticed. Write
  it as a draft beside the audit and leave the decision to a person.|]

-- | Where it declined.
auditSilentNote :: Text
auditSilentNote =
  [wft|
  Outcome: UNAUDITED. The audit was put to an independent party and it did not
  answer, so this draft is unchecked against the standing rules. Do NOT write it
  to `CLAUDE.md`. Write it as a draft, say in one line at the top that no audit
  ran, and do not substitute your own reading of the rules for the one that did
  not happen.|]

-- ---------------------------------------------------------------------------
-- The two named outcomes
-- ---------------------------------------------------------------------------

-- | The file this repository does not yet have.
--
-- An @'Agentic.Workflow.act'@: it reads the tree and writes a file, and an act at
-- @'Agentic.Raw.CodeAck'@ is the only kind of answer the ACP transport grants
-- either authority to.
claudeMdDraftFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
claudeMdDraftFn =
  function
    "claudemd.draft"
    ( takes @"listing" Text
        . takes @"scope" Text
        $ noParams
    )
    \listing scope -> W.do
      act (tool "claude-md") [wf|
          {draftBrief}

          The repository's top level:

          {listing}

          What the operator said to emphasise, which may be empty -- and empty
          means the repository decides what goes in:

          {scope}|]
      done

-- | The critique of the file it already has.
--
-- The second named outcome, and it exists so that the first cannot happen by
-- accident: this act writes a review document, and the brief it carries says in
-- its first line that @CLAUDE.md@ is not to be modified.
claudeMdCritiqueFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
claudeMdCritiqueFn =
  function
    "claudemd.critique"
    ( takes @"existing" Text
        . takes @"listing" Text
        $ noParams
    )
    \existing listing -> W.do
      act (tool "claude-md-review") [wf|
          {critiqueBrief}

          The `CLAUDE.md` as it stands:

          {existing}

          The repository's top level:

          {listing}|]
      done

-- | @claude-md-advise@'s artefact, which carries the audit's verdict.
--
-- The middle parameter is a @'Agentic.Workflow.Verdict'@ for
-- 'Workflows.Notes.notesReportFn''s reason: the objecting arm splices the
-- audit's own lines rather than a paraphrase, and the writing act reads the
-- provenance to decide which file it is allowed to write.
claudeMdAdviseFn :: Fn '[ 'CodeText, 'CodeVerdict, 'CodeText] 'CodeAck
claudeMdAdviseFn =
  function
    "claudemd.advise"
    ( takes @"provenance" Text
        . takes @"audit" Verdict
        . takes @"draft" Text
        $ noParams
    )
    \provenance audit draft -> W.do
      act reporter [wf|
          {adviseWriteBrief}

          Provenance:

          {provenance}

          What the audit answered:

          {audit}

          The draft:

          {draft}|]
      done

-- | The table 'claudeMdProgram' hands @'Agentic.Workflow.defining'@.
claudeMdTable :: [SomeFn]
claudeMdTable =
  [ SomeFn claudeMdDraftFn,
    SomeFn claudeMdCritiqueFn,
    SomeFn claudeMdAdviseFn
  ]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One receipt, one decider, and two outcomes that cannot be confused.
--
-- Two inputs at both rungs. At @claude-md@ they are @scope@ (what to emphasise,
-- possibly empty) and @agents@ (unused, and @wf plan@ says so); at
-- @claude-md-advise@ @agents@ is @prepare-with.md@'s @$ARGUMENTS@ and selects the
-- roster in Haskell before the program exists.
claudeMdProgram :: ClaudeMdRung -> Parameterized
claudeMdProgram rung =
  taking (input "scope" :> input "agents" :> noInputs) \scope agents ->
    let roster = adviserRoster agents
     in defining claudeMdTable case rung of
          Initialize -> W.do
            listing <- ask (lsPath ".") [wf|{listingBrief}|]

            -- The rework, as one free test: which of the two outcomes this run
            -- has.
            present <- tested claudeMdPresent listing

            if present
              then W.do
                -- Safe here and nowhere else: `cat` abandons the run on a
                -- missing file, and the decider above is what establishes that
                -- this one is not missing.
                existing <- ask (fileContents "CLAUDE.md") [wf|{existingBrief}|]
                call_ claudeMdCritiqueFn (arg existing :> arg listing :> noArgs)
                ask_ reporter [wf|
                    {critiquedNote}

                    Report where the critique was written and how many items it
                    carries, then reply DONE.|]
              else W.do
                call_ claudeMdDraftFn (arg listing :> arg scope :> noArgs)
                ask_ reporter [wf|
                    {writtenNote}

                    Report that the file was written, and name the sections it
                    carries, then reply DONE.|]
          Advise -> W.do
            listing <- ask (lsPath ".") [wf|{listingBrief}|]

            -- The `$ARGUMENTS` roster, priced before it runs.
            advice <- panelText (zip (lensNames roster) (asksOver roster adviceClosing listing))

            draft <- ask (reasoning (model "claude-md-draft")) [wf|
                {adviseDraftBrief}

                What the specialists advised:

                {advice}

                The repository's top level:

                {listing}

                What the operator said to emphasise, which may be empty:

                {scope}|]

            -- The eight rules, checked by somebody who did not write the draft.
            audit <- ask (lateral (model "claude-md-audit")) [wf|
                {auditBrief}

                The draft:

                {draft}|]
              `answering` Verdict

            caseVerdict
              audit
              ( W.do
                  call_ claudeMdAdviseFn (arg (auditedNote roster) :> arg audit :> arg draft :> noArgs)
                  stop
              )
              ( W.do
                  call_ claudeMdAdviseFn (arg auditObjectedNote :> arg audit :> arg draft :> noArgs)
                  stop
              )
              ( W.do
                  call_ claudeMdAdviseFn (arg auditSilentNote :> arg audit :> arg draft :> noArgs)
                  stop
              )

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the listing opens with 'listingBrief', the existing
-- file with 'existingBrief', each adviser seat with its own
-- 'Workflows.Panels.lensBrief' and the draft with 'adviseDraftBrief'.
--
-- __The listing's row is the steering one__, and at @claude-md@ it decides
-- everything: it answers with a top level that does __not__ contain a
-- @CLAUDE.md@ line, so the free decider says there is none and the run walks the
-- writing arm. Add @CLAUDE.md@ to that listing and the run rehearses the
-- critique arm instead, including the @cat@ the decider licenses — one edit, and
-- both arms exit 0.
--
-- At @claude-md-advise@ @'Agentic.Exec.scriptedDefault'@ answers a verdict
-- @APPROVE@, so the audit approves and the run ends in the arm that writes
-- @CLAUDE.md@; the objecting and declining arms are one row each.
claudeMdScript :: ClaudeMdRung -> [(Text, Text)]
claudeMdScript rung =
  [ (listingBrief, listingAnswer),
    (existingBrief, existingAnswer),
    (adviseDraftBrief, draftAnswer)
  ]
    <> [(lensBrief l, adviceAnswer l) | l <- adviserRoster ""]
  where
    _ = rung

    -- Deliberately without a `CLAUDE.md` line: the scripted run takes the
    -- writing arm, and the other arm is reached by adding one.
    -- fixture bytes, not prose: fake `ls` stdout. The fence carries the exact
    -- bytes, one entry a line.
    listingAnswer =
      [wft|
      Makefile
      README.md
      flake.nix
      src
      test|]

    -- fixture bytes, not prose: the existing CLAUDE.md's own bytes, as read off
    -- disk. The fence carries the exact bytes; every blank line is interior, so
    -- each rides the fence as an empty line.
    existingAnswer =
      [wft|
      # CLAUDE.md

      This file provides guidance to Claude Code (claude.ai/code) when working
      with code in this repository.

      ## Commands

      Run `make` to build.

      ## Notes

      Always write unit tests for new utilities.|]

    adviceAnswer l =
      [wft|
      On {owns}: the build is `make`, and a single test runs as `make test
      TEST=<name>` (read off the Makefile). The architecture worth stating is
      that `src` is a library and `test` drives it through one entry point.
      Nothing else in my area. (the {name} seat)|]
      where
        owns = lensOwns l
        name = lensName l

    draftAnswer =
      [wft|
      # CLAUDE.md

      This file provides guidance to Claude Code (claude.ai/code) when working
      with code in this repository.

      ## Commands

      - Build: `make`
      - Test: `make test`
      - One test: `make test TEST=<name>`

      ## Architecture

      `src` is a library with a single public entry point; `test` drives it
      through that entry point only, which is why a change to an internal module
      rarely needs a test change.|]
