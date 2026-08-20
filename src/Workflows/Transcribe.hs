-- |
-- Module      : Workflows.Transcribe
-- Description : Handwriting to Markdown, re-reviewed on another engine, with a
--               stopping rule.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@               | here                                                         |
-- +=========================================+==============================================================+
-- | @commands\/transcribe-image.md@ line 1  | 'transcribeBrief' — and @$ARGUMENTS@ becomes                   |
-- | (\"transcribe the handwriting in the    | @'Agentic.Workflow.input' \"images\"@, read by 'imagePaths' in |
-- | images @$ARGUMENTS@\")                  | ordinary Haskell and proved by an @ls@ receipt                |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its \"compile the text into paragraph   | 'transcribeReportFn' — one act, which is the only node in     |
-- | form as a Markdown file\"               | this program with write authority                             |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its line 3 (\"use pal mcp to            | @'Workflows.Parties.lateral'@ — a different serving model,     |
-- | re-review\")                            | pinned, which is what \"another model\" means when it is a     |
-- |                                         | type rather than a tool call                                   |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its \"based on the results of your      | @'Workflows.Escalation.escalating' … ('Agentic.Workflow.atMost'|
-- | first attempt … re-review\"             | 2)@ — the stopping rule the sentence does not have, and its    |
-- |                                         | three endings                                                  |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its \"grammar and proper English        | 'reviewBrief' — read as the check it is, and split from        |
-- | language … correctness and accuracy\"   | fidelity, which is the one thing grammar must not be allowed   |
-- |                                         | to improve                                                     |
-- +-----------------------------------------+--------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __\"Re-review\" gets a stopping rule.__ @doc\/design.md@ §7.2 row 64:
--      \"already the right shape and the only command reaching for a second model
--      by default; @revisingOn (atMost 2)@ gives \'re-review\' the stopping rule it
--      lacks.\" The corpus's second sentence describes a loop with no bound and no
--      exit: transcribe, re-review, and then whatever the reader feels like. Here
--      it is 'Workflows.Escalation.escalating' at
--      @'Agentic.Workflow.atMost' 2@, and the three ways it can end are three arms
--      the compiler makes be written — approved, out of trips with an objection
--      outstanding, or a reviewer that would not judge. @wf cost transcribe@
--      prices all three before an image is opened.
--
--   2. __\"Use pal mcp\" becomes a pin.__ The corpus names an MCP server to get a
--      second opinion. @'Workflows.Parties.lateral'@ is the same intent as a
--      /type/: the reviewer's primary serving model is deliberately not the
--      transcriber's, @--require-pinned@ refuses a run that left the pin out, and
--      @Agentic.Chains@ collects the fail-over before the run so the ladder costs
--      nothing. There is no MCP client in this tree and none is needed for this.
--
--   3. __Grammar is separated from fidelity, which the corpus fuses.__ Line 3 asks
--      for \"grammar and proper English language\" /and/ \"correctness and
--      accuracy\" in one breath, and those pull in opposite directions on
--      handwriting: a transcription made grammatical is a transcription changed.
--      'reviewBrief' names the distinction and gives the reviewer the harder half
--      — a suspected misreading is an objection, an ungrammatical sentence the
--      writer actually wrote is not.
--
--   4. __An uncertain word has a spelling.__ The corpus has no way for a
--      transcription to say \"I could not read this\", so an unreadable word
--      becomes a plausible one. 'transcribeBrief' asks for @[?word]@ and
--      @[illegible]@ inline and a trailer line per gap, and
--      'transcribeReportFn' carries them into the artefact — so the file the
--      operator gets distinguishes what was read from what was guessed.
--
-- == One narrowing, and it is the honest limit §7.2 row 64 names
--
-- __This program cannot see an image, and says so everywhere it matters.__ An
-- agent-cat question carries @'Agentic.Workflow.Words'@ — text — so a photograph
-- cannot be handed to a party by this language. The design cell rules the
-- consequence: \"inputs are @Text@, so the image /paths/ are the input and a
-- receipt reads them.\"
--
-- So the row is built at that boundary and puts something real on it:
--
--   * the paths are an input, read by 'imagePaths' in ordinary Haskell — __tier
--     1__, zero questions and zero paths;
--   * 'imagesListed' is @ls -1@ over exactly those paths, so the receipt is bytes
--     the answering model did not write and __a transcription of a file that is
--     not there cannot pass unnoticed__: @ls@ exits nonzero on a missing path, and
--     a @text@ ask on a nonzero exit abandons the run;
--   * the transcribing party is an agent with its own file-reading tools, and what
--     this program hands it is the manifest.
--
-- __What is lost, stated plainly:__ nothing in this run has looked at the
-- handwriting, so the row cannot tell a faithful transcription from a fluent
-- invention of the same length. The receipt establishes that the files exist and
-- which they are; the reviewer re-reads them independently, which is the only
-- check available and is the reason the second engine is worth its question. The
-- report is told to say which of the two guarantees it has.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Transcribe
  ( -- * The program
    transcribeProgram,
    transcribeDoc,
    transcribeScript,

    -- * The tier-1 readings of an invocation
    imagePaths,
    pathManifest,

    -- * The rubrics, transplanted
    transcribeBrief,
    reviewBrief,
    reviseBrief,

    -- * The function
    transcribeReportFn,
    transcribeTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The argv
-- ---------------------------------------------------------------------------

-- $argv
--
-- This belongs beside @'Workflows.Evidence.lsPath'@ — that module is where the
-- read-only rule could be broken, so it is reviewable as a unit. It is here, in
-- one labelled block, for @'Workflows.Git.Stack'@'s reason: the move is one cut
-- and one paste, and the exception is visible rather than scattered.

-- | @ls -1 PATH…@ — the images this run was given, one name per line, and a
-- nonzero exit if any of them is not there.
--
-- /Source:/ @commands\/transcribe-image.md@'s @$ARGUMENTS@, which in the corpus
-- is a list of paths a reading agent expands and opens. Here the list is a program
-- input, the argv is built from it in ordinary Haskell, and the receipt is what
-- makes the file list a fact rather than an assumption.
--
-- __Why @'Workflows.Evidence.lsPath'@ does not serve.__ That binding takes one
-- path; this takes the whole list in one argv, which matters for the reason the
-- receipt exists: @ls@ given five paths and missing one prints the four and exits
-- nonzero, so the run abandons instead of transcribing four images and reporting
-- five. Five separate receipts would each have to be branched on.
--
-- @-1@ is load-bearing for @'Workflows.Evidence.lsPath'@'s reason: @ls@
-- columnates when its output is a terminal, and one name per line is the shape a
-- reader — and a decider — can use.
imagesListed :: [Text] -> Party 'IsTool
imagesListed paths = tool "images" `running` ("ls", "-1" : paths)

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The image paths, one per line.
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and zero paths, and @'Workflows.Deciders.pathsOf'@ does the reading
-- because that is the shape @--input-arg@ and @--input-file@ hand every
-- list-valued input in this tree.
--
-- __Total on the empty string__, which is house rule WR-1: @wf plan@ and
-- @wf cost@ bind @\"\"@ for an input nobody gave, and an empty list would make the
-- argv @ls -1@ with no operand — which lists the working directory and exits @0@,
-- so a run pointed at nothing would report a clean transcription of whatever
-- happened to be in the current directory. The single placeholder below is a name
-- no file has, so @wf plan --raw@ prints the omission and a real run abandons at
-- the receipt.
imagePaths :: Text -> [Text]
imagePaths t = case pathsOf t of
  [] -> ["<no images given>"]
  ps -> ps

-- | The same list as the numbered manifest every prompt in this row holes.
--
-- Derived from the very list the argv was built from, so the transcriber and the
-- reviewer are told about exactly the files the receipt is about. The number is
-- what makes a per-image gap trailer readable: \"image 3\" is unambiguous where a
-- path repeated in prose is not.
pathManifest :: [Text] -> Text
pathManifest = numbered

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | What the inventory receipt is introduced as.
--
-- The words go to @ls@'s standard input, which @ls@ does not read; they are here
-- because they are the scripted table's key and because @wf plan --raw@ prints
-- them, so a reader of the plan can see what the receipt is for. That is
-- "Workflows.Gates"' reason.
inventoryBrief :: Text
inventoryBrief =
  wfText
    [wf|
    The image files this run was given. This receipt is what establishes that
    they exist and which they are: nothing else in this run can see them, and a
    path that is not here is a path nothing was transcribed from.|]

-- | @commands\/transcribe-image.md@ line 1, whole.
--
-- /Source:/ \"transcribe the handwriting in the images @$ARGUMENTS@ and compile
-- the text into paragraph form as a Markdown file\", carried in substance. What is
-- added is the vocabulary for uncertainty — see the module header, item 4 — and
-- the standing rule that the transcription is not an edit.
transcribeBrief :: Text
transcribeBrief =
  wfText
    [wf|
    Transcribe the handwriting in the image files listed below, and compile the
    text into paragraph form.

    Open every file in the list. Read them in the order given; that is the order
    the pages were in.

    You are transcribing, not editing. Write what is on the page:

    - keep the writer's words, his word order and his terminology, including
      terminology you think is wrong;
    - keep his emphasis where the page shows it -- underlining becomes italics,
      a boxed or double-underlined phrase becomes bold;
    - join the lines of a paragraph into a paragraph. Handwriting breaks lines
      where the page ends, and those breaks carry no meaning; a blank line, an
      indent, or a new thought is a paragraph break and does carry meaning;
    - keep his lists as lists and his headings as headings;
    - where a marginal note or an arrow attaches to a passage, put it where it
      attaches and say in square brackets that it was a margin note.

    Where you cannot read something, say so rather than choosing:

    - a word you are fairly sure of but not certain: write it as [?word];
    - a word or phrase you cannot read at all: write [illegible];
    - a passage that is crossed out: leave it out, unless it is legible and
      replaced by something, in which case write [struck: …] before the
      replacement.

    Then, after the transcription, one trailer line per gap:

      UNREADABLE: image <n> -- <what you could not read, and what surrounds it>

    and if there are none, exactly one line reading

      NOTHING UNREADABLE

    A plausible word invented to fill a gap is the one failure here that a reader
    cannot detect, because it reads better than the truth. The trailer is what
    makes it detectable.|]

-- | What the reviewer is told, above 'Workflows.Escalation.endingSpec'.
--
-- /Source:/ @commands\/transcribe-image.md@ line 3 — \"use pal mcp to re-review,
-- and also take grammar and proper English language into consideration, to better
-- analyze these notes for their correctness and accuracy\" — read as the check it
-- implies and split into its two halves, because they pull in opposite directions.
reviewBrief :: Text
reviewBrief =
  wfText
    [wf|
    Re-review a transcription of handwritten notes. You did not produce it. Open
    the same image files and read them yourself: this is a second reading, not a
    proofread of somebody's output.

    Two questions, and the first outranks the second whenever they conflict.

    1. Fidelity. Does the transcription say what the page says? Look hardest at
       the places a misreading is invisible in the result: a number (7 against 1,
       3 against 8, a decimal point), a proper noun, a negation, a technical term
       that has a near neighbour, a line that was continued in the margin, an
       ordering that the page shows and prose does not. Every one of these is an
       objection when it is wrong, and the objection names the image and the
       passage.

    2. English. Is the compiled text readable as English -- punctuation, sentence
       boundaries, paragraph breaks, the spelling of words the writer clearly
       intended?

    The two conflict constantly and the rule is this: an ungrammatical sentence
    the writer actually wrote stays ungrammatical. Do not object to his grammar,
    his register, his abbreviations or his terminology. Object to the
    transcriber's -- a sentence boundary put in the wrong place, a comma that
    changes the meaning, a word spelled as a different word.

    Two more checks, and both are cheap:

    - every image in the manifest must be accounted for in the transcription. An
      image nothing came from is either blank -- and the transcription should say
      so -- or was not read.
    - the gap trailers must be honest. A passage transcribed with confident,
      fluent text where the page is genuinely hard to read is worse than an
      [illegible], and it is the specific failure a second reader exists to
      catch. If you find one, that is an objection.

    A transcription that is faithful, accounts for every image and marks its gaps
    honestly is an approval, and an approval is the single word APPROVE and
    nothing else -- anything you add beside it is read as an objection by the
    program that consumes your verdict. What you re-read and what you checked
    hardest belongs in an objection line or nowhere.|]

-- | What the transcriber is told on a repair trip.
reviseBrief :: Text
reviseBrief =
  wfText
    [wf|
    A second reader re-read the images and objected. Produce the next version of
    the transcription and nothing else -- the same shape as before, including the
    gap trailers, and no commentary about what you changed.

    Go back to the image the objection names and look again. Where the reader is
    right, take his reading. Where you still cannot tell, that is what [?word]
    and [illegible] are for: an honest gap is a better answer than either of two
    guesses, and the trailer line says which.

    Where the objection is about English rather than about the page, remember
    which way the rule runs: the writer's own words stay, and only the
    transcriber's punctuation and sentence boundaries are yours to fix.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the second reader approved.
approvedNote :: Text
approvedNote =
  "Outcome: TRANSCRIBED AND RE-READ. The image files were proved to exist by an \
  \`ls` receipt, transcribed, and then re-read independently by a second engine \
  \which approved the result for fidelity, for coverage of every image, and for \
  \honest gap marking. Report the transcription as the artefact and the gaps as \
  \gaps. Say what this establishes and what it does not: two readings of the same \
  \pages agreed, which is the strongest thing available here, and it is not the \
  \same as somebody who was there checking the transcript against the notebook."

-- | The arm where the trips ran out.
unresolvedNote :: Text
unresolvedNote =
  "Outcome: NOT AGREED. The second reader still objected after every re-reading \
  \trip this run was given, so the transcription below is the one the last trip \
  \produced and the final review objected to -- no trip was spent answering that \
  \last objection. Do NOT present it as a checked transcription. Report the \
  \outstanding objection first, verbatim, then the transcription beneath it, and \
  \name the specific passage the two readings disagree about: a passage two \
  \careful readers read differently is a passage a human should look at, and that \
  \is a useful result rather than a failure."

-- | The arm where the second reader declined.
declinedNote :: Text
declinedNote =
  "Outcome: NOT RE-READ. The second reader declined to judge the transcription at \
  \all, which means it could not do the job asked -- most often because it cannot \
  \open the image files, which is a fact about the run's tooling and not about the \
  \notes. Report the transcription as UNCHECKED, name the image files by path, and \
  \say plainly that only one reading of these pages exists."

-- ---------------------------------------------------------------------------
-- The function
-- ---------------------------------------------------------------------------

-- | What the artefact is written through.
--
-- /Source:/ @commands\/transcribe-image.md@ line 1's \"compile the text into
-- paragraph form as a __Markdown file__\" — the file is the deliverable, so the
-- closing turn writes one rather than reporting about one.
transcribeReportBrief :: Text
transcribeReportBrief =
  wfText
    [wf|
    Write the transcription to a Markdown file. The file is the point of this run:
    somebody will read it instead of the notebook.

    The file, in this order:

    - a title naming what these notes are, and a line naming the image files it
      came from, in order;
    - the provenance line you were given, verbatim, as a blockquote. It is the
      run's own account of how the transcription was checked and it is not yours
      to soften;
    - the transcription itself, in paragraph form, exactly as it stands. Do not
      re-edit it here: it has been through the reviews it is going to get, and a
      change made at this point has been checked by nobody;
    - a closing section headed "Gaps and uncertainties", listing every [?word],
      every [illegible] and every trailer line -- or the sentence "Nothing in
      these pages was unreadable" if there were none.

    Then reply DONE with the path you wrote.

    One thing you must not do: do not remove the square-bracket markers from the
    body. They are what tells a reader which words are the writer's and which are
    a best guess, and a file without them reads as though every word were certain.|]

-- | One act, three provenance lines.
--
-- Three parameters, in the order the body reads them: the provenance first, for
-- "Workflows.Report"'s reason; then the transcription; then the file manifest, so
-- the artefact can name its own sources without a question being spent on saying
-- what they were.
--
-- __This is the only node in the program with write authority.__
-- @Agentic.Acp.permissionByCode@ grants it to an @'Agentic.Workflow.act'@ at
-- @'Agentic.Raw.CodeAck'@ and to nothing else, and the transcription and both
-- readings are asked at @text@ — so the pages cannot be modified by anything in
-- this run, whatever it is told.
transcribeReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
transcribeReportFn =
  function
    "transcribe.write"
    ( takes @"provenance" Text
        . takes @"transcription" Text
        . takes @"images" Text
        $ noParams
    )
    \provenance transcription images -> W.do
      act reporter [wf|
          {writing}

          Provenance:

          {provenance}

          The image files:

          {images}

          The transcription:

          {transcription}|]
      done
  where
    writing = transcribeReportBrief

-- | The table 'transcribeProgram' hands @'Agentic.Workflow.defining'@.
transcribeTable :: [SomeFn]
transcribeTable = [SomeFn transcribeReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One receipt, one transcription, and a bounded second reading on another
-- engine.
--
-- Two inputs. @images@ is the image paths, one per line — @$ARGUMENTS@ with a
-- name, and 'imagePaths' says what an absent one means; @subject@ is what the
-- notes are about, which is the one thing that turns an unreadable word into a
-- readable one and is worth a flag of its own.
--
-- The shape, top to bottom: prove the files exist and name them; transcribe them;
-- have a differently-served engine re-read the same pages with a bound; and write
-- the Markdown file whichever way the loop ended. Three endings, three provenance
-- lines, __one__ 'transcribeReportFn'.
transcribeProgram :: Parameterized
transcribeProgram =
  taking (input "images" :> input "subject" :> noInputs) \imagesArg subject ->
    -- Tier 1, twice: which files, and how they are named to the two readers.
    -- Both are ordinary Haskell over the invocation, and the first is in the
    -- printed argv.
    let paths = imagePaths imagesArg
        manifest = pathManifest paths
     in defining transcribeTable W.do
          -- The receipt. `ls` exits nonzero on a missing path and a `text` ask
          -- abandons on a nonzero exit, so a run pointed at a file that is not
          -- there ends saying so rather than transcribing the ones that are.
          present <- ask (imagesListed paths) [wf|{inventory}|]

          first <- ask (broad (model "transcribe")) [wf|
              {transcribing}

              What these notes are about, so far as this run knows: {subject}

              The image files, in page order:

              {manifest}

              What the run found on disk:

              {present}|]

          -- `pal mcp to re-review`, as a pin: the reviewer's primary serving
          -- model is deliberately not the transcriber's.
          reread <-
            escalating
              (lateral (model "transcribe-review"))
              (reviewOver manifest)
              (broad (model "transcribe"))
              reviseBrief
              first
              (atMost 2)

          case reread of
            SettledOn final -> W.do
              call_ transcribeReportFn (arg approvedNote :> arg final :> arg present :> noArgs)
              stop
            UnsettledOn final -> W.do
              call_ transcribeReportFn (arg unresolvedNote :> arg final :> arg present :> noArgs)
              stop
            AbandonedOn final -> W.do
              call_ transcribeReportFn (arg declinedNote :> arg final :> arg present :> noArgs)
              stop
  where
    inventory = inventoryBrief
    transcribing = transcribeBrief

-- | The reviewer's brief with the manifest named in it.
--
-- __Tier 1__, and the reason it is a function rather than a second define: the
-- reviewer's second cheap check — every image accounted for — needs the list of
-- images, and a reviewer told to check coverage against a list it was not given
-- has been told to check nothing. 'reviewBrief' stays first in the text, so the
-- scripted table's key is a prefix of the rendered prompt by construction.
reviewOver :: Text -> Text
reviewOver manifest =
  reviewBrief
    <> "\n\nThe image files, in page order -- every one of these must be accounted \
       \for in the transcription:\n\n"
    <> manifest

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
transcribeDoc :: Text
transcribeDoc =
  "transcribe-image.md: an `ls` receipt over the pages, one transcription, and a second engine re-reading them under a bound"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the receipt's question opens with 'inventoryBrief', the
-- transcription's with 'transcribeBrief', the second reading's with 'reviewBrief'
-- — through @'reviewOver'@, which appends the manifest after it — and the repair's
-- with 'reviseBrief'.
--
-- __The receipt's row is what keeps the scripted run off the disk.__ With it, the
-- @ls@ is answered from this table and no command runs; without it,
-- @'Agentic.Exec.scriptedDefault'@ would echo the prompt, which is harmless but
-- says nothing about the shape a real run sees.
--
-- The review's row is written with the approving answer even though a verdict
-- question's scripted default is @APPROVE@, for
-- @'Workflows.Comments.commentsScript'@'s reason: a table that relies on a default
-- cannot be edited into the other two arms in one line. An @OBJECTION:@ here
-- reaches @UnsettledOn@ and an empty answer reaches @AbandonedOn@, and all three
-- exit 0.
--
-- __It is the bare word.__ @Agentic.Text.approvesB@ approves only a reply that
-- /is/ an approve word and nothing else, so a row carrying the word and a sentence
-- would be read as an objection carrying that sentence — and this table would
-- rehearse the unsettled arm while claiming the approved one.
-- "Workflows.OrgTasks" records the same fact at its own verdict rows.
transcribeScript :: [(Text, Text)]
transcribeScript =
  [ (inventoryBrief, listed),
    (transcribeBrief, transcribed),
    (reviewBrief, "APPROVE"),
    (reviseBrief, transcribed)
  ]
  where
    listed =
      "/home/johnw/scans/notebook-p1.jpg\n\
      \/home/johnw/scans/notebook-p2.jpg"

    transcribed =
      "# Notebook, pages 1-2\n\
      \\n\
      \The queue design has to answer one question before anything else: whether \
      \a tenant gets its own queue. Everything downstream follows from that, and \
      \it is the decision that is hardest to reverse.\n\
      \\n\
      \With one shared queue the retention window belongs to the consumer, not to \
      \the queue, so per-tenant retention stops being available at all. That may \
      \be fine. [margin note: check the [?Kowalski] contract]\n\
      \\n\
      \Numbers from last month: 41k messages a day at peak, 3.2s p99 end to end. \
      \The p99 is dominated by one tenant's batch job, which is the whole reason \
      \this came up.\n\
      \\n\
      \[illegible] -- something about the alerting thresholds, three or four words.\n\
      \\n\
      \UNREADABLE: image 2 -- a short line at the foot of the page, immediately \
      \after the paragraph about alerting thresholds; three or four words, heavily \
      \crossed through and rewritten over.\n\
      \UNREADABLE: image 1 -- the surname in the margin note reads as Kowalski but \
      \could be Kowalsky or Kowalksi."
