-- |
-- Module      : Workflows.Threads
-- Description : The pull request's open comments — answered, or researched
--               first, and never posted back.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------+-----------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@     | here                                                      |
-- +===============================+===========================================================+
-- | @commands\/respond.md@        | @pr-threads@ — the whole file, which is one sentence: a    |
-- |                               | Markdown report carrying the answer each colleague would   |
-- |                               | be given, and nothing posted                               |
-- +-------------------------------+-----------------------------------------------------------+
-- | @commands\/assess.md@         | @pr-threads-assess@ — the same ledger, read first by the   |
-- |                               | language specialists its \"haskell-pro and\/or cpp-pro     |
-- |                               | and\/or rust-pro\" names, then folded into an approach     |
-- +-------------------------------+-----------------------------------------------------------+
-- | @commands\/bugbot.md@         | __not here__: @'Workflows.Fix.Green.botSweepFn'@, called   |
-- |                               | by @green-ci@. See \"The bot half\" below                  |
-- +-------------------------------+-----------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __Never posting is an absence, not a rule.__ @doc\/design.md@ §7.2 row 54
--      states it: \"never-posting is an __absence__, not a rule — no party in
--      the program carries a write verb\". Every question below is asked at
--      @text@ or folded from @text@ answers, and
--      @Agentic.Acp.permissionByCode@ grants write authority only to an
--      @'Agentic.Workflow.act'@ at @'Agentic.Raw.CodeAck'@ — of which this
--      program has exactly one, and it writes a report file. There is no
--      @gh pr comment@ in "Workflows.Evidence" for a run to reach for.
--
--   2. __The comment roster is a receipt.__ @respond.md@ opens \"in PR
--      $ARGUMENTS there are several open comments\" and leaves the finding of
--      them to whoever read the command. Here the pull request's own JSON is
--      @'Workflows.Evidence.ghPrView'@ and the inventory is built from those
--      bytes — so the run cannot answer a comment nobody left, and cannot miss
--      one because it stopped reading.
--
--   3. __The ledger is bound once.__ "Workflows.Fix.Green"'s item 7, for the
--      same reason: a comment that arrives while the specialists are reading
--      has no way into this run. It belongs to the next one.
--
--   4. __The empty pull request is an ending that costs nothing.__ \"There are
--      several open comments\" is an assumption, and a run against a pull
--      request with none of them spends a page answering nothing. Here it is
--      'Workflows.Deciders.noOpenComments' over the inventory: one free test,
--      one arm, and the specialists are never asked.
--
--   5. __The @and\/or@ becomes a table.__ @assess.md@ says \"use your
--      superpowers and haskell-pro and\/or cpp-pro and\/or rust-pro\", which is
--      a decision it hands to a model. 'assessRoster' is __tier 1__
--      ("Workflows.Deciders"): ordinary Haskell over the @paths@ input, before
--      the @'Agentic.Builder.Program'@ exists, so
--      @wf cost pr-threads-assess --input-arg paths=…@ prices this pull
--      request's roster before a token moves.
--
--   6. __\"Use the @opus@ model for running any sub-agents\" is a pin.__ That
--      sentence is @assess.md@'s last, and it is an instruction to a runner that
--      nothing checks. The specialists are "Workflows.Parties"' @-pro@ parties,
--      every one pinned with @'Agentic.Workflow.servedBy'@, and
--      @--require-pinned@ refuses the run before a plan is printed if one is
--      not.
--
-- == The bot half, and why it is not a third rung
--
-- @doc\/design.md@ §8 lists this row as \"@pr-threads@ (respond, assess,
-- bugbot)\". §7.1 row 6 — the triage cell for @bugbot.md@ itself, which is the
-- more specific statement — names its host as @green@ (@botSweepFn@), and that
-- is where it landed in wave 1: @green-ci@ binds the same @gh@ ledger, calls
-- @'Workflows.Fix.Green.botSweepFn'@, and then gates on the pull request's own
-- checks. A third rung here would be @green-ci@ with its gate removed: two
-- mechanisms for one job, which is the duplication this repository exists to
-- end.
--
-- So the division is structural rather than editorial, and both halves say so in
-- their prompts: 'inventoryBrief' excludes every bot author and names @green-ci@
-- as where they are handled, exactly as
-- @'Workflows.Fix.Green.botSweepFn'@'s own @exclusions@ argument excludes every
-- human. Between them the two rungs read one ledger and neither answers the
-- other's authors — where the corpus has two commands that each silently ignore
-- half of it.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Threads
  ( -- * The rungs
    ThreadRung (..),
    threadRungName,
    threadsDoc,

    -- * The program
    threadsProgram,
    threadsScript,

    -- * The roster @assess.md@'s and\/or becomes
    assessRoster,
    proFor,

    -- * The artefact every ending writes through
    threadsReportFn,
    threadsTable,
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

-- | The two things the owner does with a colleague's review comments.
--
-- They differ in what stands between the ledger and the answer: nothing, or the
-- language specialists. That is a roster and a price, which is what a registry
-- row should differ in.
data ThreadRung
  = -- | @commands\/respond.md@ — answer each comment, in a report.
    Respond
  | -- | @commands\/assess.md@ — research the comments and their implications
    -- first, then say how a response would be formulated.
    Assess
  deriving (Eq, Show)

-- | The name the operator types.
threadRungName :: ThreadRung -> Text
threadRungName Respond = "pr-threads"
threadRungName Assess = "pr-threads-assess"

-- | The one line @wf list@ prints beside a rung.
threadsDoc :: ThreadRung -> Text
threadsDoc Respond =
  "respond.md: one answer per open colleague comment, as a report, with nothing posted back"
threadsDoc Assess =
  "assess.md: the language specialists read the comments first, then an approach to answering them"

-- ---------------------------------------------------------------------------
-- The roster assess.md's and/or becomes
-- ---------------------------------------------------------------------------

-- | The @-pro@ specialist for a language reviewer's name, where there is one.
--
-- /Source:/ @agents\/*-pro.md@, the nine files "Workflows.Parties" calls
-- addressees. @bash@ has no @-pro@ agent in the corpus and therefore no row
-- here: a language with no specialist is a language this rung does not pretend
-- to have one for, and the absence is visible rather than filled in.
proFor :: Text -> Maybe (Party 'IsModel)
proFor "haskell" = Just haskellPro
proFor "cpp" = Just cppPro
proFor "rust" = Just rustPro
proFor "python" = Just pythonPro
proFor "nix" = Just nixPro
proFor "elisp" = Just elispPro
proFor "typescript" = Just typescriptPro
proFor "coq" = Just rocqPro
proFor _ = Nothing

-- | The specialists a file list selects, or the one general reader.
--
-- __Tier 1__, and the whole of @assess.md@'s \"haskell-pro and\/or cpp-pro
-- and\/or rust-pro\": the globs are
-- 'Workflows.Rubrics.Reviewers.languages'\''s, the parties are
-- "Workflows.Parties"', and the join happens in ordinary Haskell before the
-- program exists.
--
-- __House rule WR-1__ (@README@): an absent @paths@ must mean /the default
-- roster/ and never /no members/, because @'Agentic.Workflow.panel'@ at the
-- empty list is an @error@ on a CAF and @ci\/workflows.sh@ prices every row with
-- no inputs. The default is one seat and it says in its own brief that it is
-- reading without a language in hand.
assessRoster :: [Text] -> Roster
assessRoster files
  | null selected = [generalAssessor]
  | otherwise = selected
  where
    selected =
      [ Lens
          { lensName = langName l,
            lensOwns = langOwns l,
            lensBrief = assessBrief (langName l),
            lensParty = p
          }
      | l <- languages,
        any (touches files) (langGlobs l),
        Just p <- [proFor (langName l)]
      ]

-- | The seat a run with no file list is answered by.
generalAssessor :: Lens
generalAssessor =
  Lens
    { lensName = "general",
      lensOwns = "the comments, read without a language specialist in hand",
      lensBrief = assessBrief "general",
      lensParty = broad (model "assess-general")
    }

-- ---------------------------------------------------------------------------
-- The prompts, transplanted
-- ---------------------------------------------------------------------------

-- | What the pull request's own record is introduced as.
--
-- /Source:/ @commands\/respond.md@'s @PR $ARGUMENTS@ and @assess.md@'s \"the PR
-- for the current branch\". The number is the /argv/ of two @gh@ commands rather
-- than a string a model interprets.
ledgerBrief :: Text
ledgerBrief =
  [wft|
  This is the pull request's own record, as JSON, straight from the GitHub
  API. It is the whole universe of comments for this run: a comment that is
  not in these bytes is not this run's business, and one that arrives while
  the run is working belongs to the next run.|]

-- | What the inventory question asks for.
--
-- /Source:/ @commands\/respond.md@ (\"several open comments from my
-- colleagues\") and @commands\/bugbot.md@ Phase 1's own filter, inverted — which
-- is the whole of the division named in the module header.
--
-- The @NO OPEN COMMENTS@ sentinel is this program's, and
-- 'Workflows.Deciders.noOpenComments' is what reads it, for nothing.
inventoryBrief :: Text
inventoryBrief =
  [wft|
  Build the complete inventory of open review comments on this pull request,
  as a numbered checklist, from the record below and nothing else.

  For each item: number, author, the file and line where the comment applies,
  whether it is an inline review thread or a top-level comment, and a one-line
  statement of what it asks or claims.

  Include only comments from HUMAN authors, and exclude every bot or automated
  reviewer without exception -- an author whose type is Bot, or whose login
  contains "bot", "[bot]" or "app/". Those are handled by a different run, the
  `green-ci` workflow, which sweeps them and replies to them; answering one
  here would be this run posting on a bot's behalf.

  Include only comments that are still open: skip anything already resolved,
  and skip a thread whose last reply already answers it.

  If there are no such comments, reply with exactly

    NO OPEN COMMENTS

  and nothing else.|]

-- | What the diff receipt is introduced as.
--
-- /Source:/ @commands\/respond.md@'s \"explain your fix\", which is a claim
-- about code and therefore needs the code. The diff is a receipt, so an answer
-- describing a fix that is not in it is contradicted by bytes rather than by
-- opinion.
diffBrief :: Text
diffBrief =
  [wft|
  This is the pull request's diff, as `gh pr diff` wrote it. It is what the
  comments below are about, and it is the evidence for every claim an answer
  makes about what the code does or now does.|]

-- | @commands\/respond.md@, whole.
--
-- /Source:/ its one sentence, given the two things it asks for and cannot say:
-- an answer per comment rather than an answer to the set, and the accounting
-- that makes a missing answer visible. The @INCOMPLETE:@ line is
-- 'Workflows.Panels.refusingSynthesis'\''s contract, read here by
-- 'Workflows.Deciders.incompleteFanOut'.
respondBrief :: Text
respondBrief =
  [wft|
  For every item in the inventory below, write the answer you would give that
  comment's author -- explaining the fix, or the clarification, or the reason
  the comment does not apply. You are not posting anything: this is a report
  the author of the pull request reads before deciding what to say.

  One section per inventory item, in the inventory's own order and numbering.
  Each section:

  - names the author, the file and the line;
  - quotes the comment in one line;
  - gives the answer, in the second person, as it would be said to that
    person: what was changed and where, or what was already true and where to
    look, or what is not going to change and why;
  - names the evidence in the diff -- a file and a hunk -- for every claim
    about the code. An answer that cannot point at the diff says so in the
    same breath.

  Answer every item. If you cannot -- an item's thread is unreadable, or the
  diff does not carry what it is about -- reply with exactly

    INCOMPLETE: <the item numbers you could not answer>

  on its own line, followed by the sections you could write. Do not
  silently drop an item: a report that answers four of five comments and says
  so is useful, and one that answers four and does not is worse than none.

  Assume competence on both sides. A comment is a colleague's reading of the
  code, and where it is mistaken the answer says what the code does, not what
  the reader missed.|]

-- | What each specialist seat is asked, by language.
--
-- /Source:/ @commands\/assess.md@ — \"deeply research and analyze the comments
-- they've left (and their implications)\". The language name opens the brief so
-- that the seats do not share a leading chunk, which is
-- 'Workflows.Notes.sectionRoster'\''s rule and the reason a scripted table can
-- tell them apart.
assessBrief :: Text -> Text
assessBrief lang =
  [wft|
  You are the {lang} specialist on this pull request, and the comments below
  are your subject.

  For each comment that touches your language, research what it is really
  saying and what follows from it: whether the claim holds against this code,
  what it implies for the rest of the change, and what a correct response
  would have to do. Read the implications past the comment -- a reviewer who
  objects to one call site is often objecting to the invariant behind it, and
  that is the finding worth having.

  Say plainly which comments are outside your language and leave them to the
  seat that owns them.

  Report what you found and nothing else: no answer to the reviewer, no code,
  no plan. This block is one specialist's reading, and the approach is
  somebody else's job.|]

-- | The fold @assess.md@ asks for.
--
-- /Source:/ its \"present to me your findings and how we might begin to
-- formulate a response\", over 'Workflows.Panels.refusingSynthesis' — so the
-- fold accounts for every seat before it is allowed to recommend anything.
approachBrief :: Roster -> Text
approachBrief r =
  [wft|
  {refusing}

  Then, and only then, say how a response would be formulated: for each
  comment, what the answer would have to establish, what would have to be
  checked or changed first, and which comments can be answered together
  because they are one objection said twice.

  Separate what the specialists verified from what they inferred. End with the
  order in which the comments should be taken, cheapest decision first.|]
  where
    refusing = refusingSynthesis r

-- | What each specialist block is told about the shape of its answer.
assessClosing :: Text
assessClosing =
  [wft|
  Report your reading and nothing else. Your answer is one block of a document
  whose other blocks are the other specialists', each fenced under its own
  name: do not write theirs, and do not summarise the whole.|]

-- | The brief the report act is given.
--
-- /Source:/ @commands\/respond.md@'s \"create a Markdown report\", which is the
-- output half of that file, plus the naming this program adds so that two runs
-- against two pull requests do not overwrite one artefact.
threadsWriteBrief :: Text
threadsWriteBrief =
  [wft|
  Write the report to `pr-<number>-responses.md` in the current directory,
  with the pull request number you were given in place of <number>.

  In this order, and change nothing on the way: the provenance line you were
  given, verbatim, first; then the document below, block for block, under its
  own headings.

  You are transcribing, not editing. Do not answer a comment the document does
  not answer, do not soften an answer, and do not add a closing paragraph of
  your own. Then reply DONE.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the pull request had nothing open on it.
nothingOpenNote :: Text
nothingOpenNote =
  "Outcome: NOTHING OPEN. The pull request's own record was read and the \
  \inventory built from it found no open comment from a human author, so no \
  \specialist and no answering question was asked. Report that, name the pull \
  \request, and say plainly that bot comments -- if there are any -- are the \
  \`green-ci` workflow's and were not looked at here."

-- | The arm where every item was answered.
answeredNote :: ThreadRung -> Text
answeredNote Respond =
  "Provenance: every item in the inventory was answered from the pull request's \
  \own record and its diff, both of which are command receipts. Nothing was \
  \posted: no question in this run had write authority, and no bot author was \
  \answered. Report the answers as they stand."
answeredNote Assess =
  "Provenance: the language specialists read the inventory and the diff -- the \
  \same bytes, spliced into every seat -- and the fold accounted for every seat \
  \before recommending anything. Nothing was posted and no bot author was \
  \answered. Report the findings and the approach as they stand."

-- | The arm where the answering refused.
shortNote :: Text
shortNote =
  "Outcome: INCOMPLETE. The answering step declined to account for at least one \
  \inventory item; its first line names which. Label this report incomplete, \
  \name the unanswered items at the top, and do not present the rest as a full \
  \pass over the pull request's comments."

-- ---------------------------------------------------------------------------
-- The artefact every ending writes through
-- ---------------------------------------------------------------------------

-- | One act, three provenance lines.
--
-- Three parameters. The pull request number is one of them because the
-- artefact's name carries it: a report called @pr-responses.md@ is a report the
-- second run overwrites.
threadsReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
threadsReportFn =
  function
    "threads.write"
    ( takes @"pr" Text
        . takes @"provenance" Text
        . takes @"document" Text
        $ noParams
    )
    \pr provenance document -> W.do
      act reporter [wf|
          {threadsWriteBrief}

          The pull request number:

          {pr}

          Provenance:

          {provenance}

          The document:

          {document}|]
      done

-- | The table 'threadsProgram' hands @'Agentic.Workflow.defining'@.
threadsTable :: [SomeFn]
threadsTable = [SomeFn threadsReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One ledger, two rungs, three endings.
--
-- Two inputs. @pr@ is the pull request number, and it is the argv of both @gh@
-- commands; @paths@ is the file list, one per line, and at @pr-threads-assess@
-- it selects the specialists in Haskell before the program exists.
--
-- The shape, top to bottom and the same both times: bind the pull request's
-- record; build the inventory from it and decide the empty case for free;
-- otherwise take the diff, produce the document — one answering question, or the
-- specialist fan-out and a fold over it — decide the refusal for free, and end
-- in one report function whichever way the two decisions went.
--
-- __Why the two rungs are two blocks and not one with a @case@ in the middle.__
-- A bind's right-hand side is an @'Agentic.Workflow.Rhs'@ — one question, one
-- fold, one call — and @Assess@'s document is /two/ statements: the panel, then
-- the question that reads it. There is no @Rhs@ that is a block, deliberately
-- (that is what a @'Agentic.Workflow.Fn'@ is for, and a function body may not
-- branch), so the rung is chosen at the top exactly as
-- "Workflows.Fix.Green"'s is. Every brief, every decider and the report function
-- are shared; what is written twice is the four statements around them.
threadsProgram :: ThreadRung -> Parameterized
threadsProgram rung =
  taking (input "pr" :> input "paths" :> noInputs) \pr paths ->
    let roster = assessRoster (pathsOf paths)
        approach = approachBrief roster
     in defining threadsTable case rung of
          Respond -> W.do
            -- The ledger, bound once. A comment arriving mid-run has no way in.
            record <- ask (ghPrView pr) [wf|{ledgerBrief}|]

            -- The inventory, and the one filter that keeps this run off a bot's
            -- threads.
            inventory <- ask (broad (model "inventory")) [wf|
                {inventoryBrief}

                The record:

                {record}|]

            -- The ending `respond.md` assumes away, for zero questions.
            quiet <- tested noOpenComments inventory

            if quiet
              then W.do
                call_ threadsReportFn (arg pr :> arg nothingOpenNote :> arg inventory :> noArgs)
                stop
              else W.do
                diff <- ask (ghPrDiff pr) [wf|{diffBrief}|]

                answers <- ask (reasoning (model "answers")) [wf|
                    {respondBrief}

                    The inventory:

                    {inventory}

                    The diff:

                    {diff}|]

                short <- tested incompleteFanOut answers

                if short
                  then W.do
                    call_ threadsReportFn (arg pr :> arg shortNote :> arg answers :> noArgs)
                    stop
                  else W.do
                    call_ threadsReportFn (arg pr :> arg (answeredNote rung) :> arg answers :> noArgs)
                    stop
          Assess -> W.do
            record <- ask (ghPrView pr) [wf|{ledgerBrief}|]

            inventory <- ask (broad (model "inventory")) [wf|
                {inventoryBrief}

                The record:

                {record}|]

            quiet <- tested noOpenComments inventory

            if quiet
              then W.do
                call_ threadsReportFn (arg pr :> arg nothingOpenNote :> arg inventory :> noArgs)
                stop
              else W.do
                diff <- ask (ghPrDiff pr) [wf|{diffBrief}|]

                -- The and/or, as a priced fan-out over the same two receipts.
                found <- panelText (zip (lensNames roster) (withEvidence roster assessClosing inventory diff))

                document <- ask (reasoning (model "approach")) [wf|
                    {approach}

                    The inventory:

                    {inventory}

                    What the specialists found:

                    {found}|]

                short <- tested incompleteFanOut document

                if short
                  then W.do
                    call_ threadsReportFn (arg pr :> arg shortNote :> arg document :> noArgs)
                    stop
                  else W.do
                    call_ threadsReportFn (arg pr :> arg (answeredNote rung) :> arg document :> noArgs)
                    stop

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the two receipts open with their own briefs, the
-- inventory with 'inventoryBrief', each seat with its own
-- 'Workflows.Panels.lensBrief', and the fold with 'approachBrief' at the very
-- roster the panel was built from.
--
-- __The inventory's row is what steers the run.__ Its answer deliberately does
-- __not__ open a line with @NO OPEN COMMENTS@, so the free decider says there is
-- work and the run walks the long arm; delete that row and the run rehearses the
-- nothing-open ending instead. The answering row deliberately does not open a
-- line with @INCOMPLETE:@ either, so the run ends in the arm where every item
-- was answered. Both other endings are one edit away, and all three exit 0.
--
-- The table is built at the empty file list, which is the invocation
-- @ci\/workflows.sh@ prices and runs: at @pr-threads-assess@ that is the single
-- general seat, and a scripted run given a real @--input-arg paths=@ falls
-- through to @'Agentic.Exec.scriptedDefault'@ for the specialists __and for the
-- fold__, because 'approachBrief' is derived from the roster that will actually
-- run. Both fall-throughs echo the prompt, which is harmless, and the run still
-- exits 0.
threadsScript :: ThreadRung -> [(Text, Text)]
threadsScript rung =
  [ (ledgerBrief, recordAnswer),
    (inventoryBrief, inventoryAnswer),
    (diffBrief, diffAnswer),
    (respondBrief, answersAnswer),
    (approachBrief roster, approachAnswer)
  ]
    <> [(lensBrief l, seatAnswer l) | l <- roster]
  where
    roster = assessRoster []

    _ = rung

    recordAnswer =
      "{\"number\":412,\"title\":\"Cache the parsed header\",\
      \\"headRefOid\":\"9f1c2ab\",\"files\":[{\"path\":\"src/Header.hs\"}],\
      \\"reviews\":[{\"author\":{\"login\":\"rlepinski\"},\
      \\"body\":\"The cache is never invalidated when the header changes.\"}]}"

    inventoryAnswer =
      "1. rlepinski -- inline review thread -- src/Header.hs:88 -- the parsed \
      \header cache is never invalidated when the underlying header changes.\n\
      \2. rlepinski -- top-level comment -- asks whether the cache is shared \
      \between requests."

    diffAnswer =
      "--- a/src/Header.hs\n\
      \+++ b/src/Header.hs\n\
      \@@ -85,6 +85,9 @@\n\
      \+parsedCache :: IORef (Map ByteString Header)\n\
      \+parsedCache = unsafePerformIO (newIORef mempty)\n"

    answersAnswer =
      "## 1. rlepinski -- src/Header.hs:88\n\
      \\n\
      \> The cache is never invalidated when the header changes.\n\
      \\n\
      \You are right, and the diff shows why: `parsedCache` at \
      \src/Header.hs:88-90 is keyed on the raw bytes, so a changed header is a \
      \different key and the stale entry is never read again. It is a leak \
      \rather than a correctness bug, and the fix is a bounded map.\n\
      \\n\
      \## 2. rlepinski -- top-level\n\
      \\n\
      \> Is the cache shared between requests?\n\
      \\n\
      \Yes -- it is a top-level `IORef`, so it is process-wide. That is \
      \deliberate for the parse cost, and the boundedness above is what makes it \
      \safe."

    approachAnswer =
      "All blocks accounted for.\n\
      \\n\
      \Verified: the cache is keyed on raw bytes and is process-wide (both read \
      \off src/Header.hs:88-90).\n\
      \Inferred: that the entry count is unbounded in practice; nobody measured \
      \it.\n\
      \One objection said twice: items 1 and 2 are both about lifetime, and one \
      \answer serves them.\n\
      \Order: decide the bound first -- it settles both comments; the sharing \
      \question needs no change."

    seatAnswer l =
      "On "
        <> lensOwns l
        <> ": the objection holds against this code, and its implication is \
           \wider than the call site it names. Read by the "
        <> lensName l
        <> " seat."
