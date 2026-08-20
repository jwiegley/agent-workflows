-- |
-- Module      : Workflows.Tron
-- Description : The Torch Fx ingest pipeline, debugged against runs that
--               actually happened.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------------------+--------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@               | here                                                         |
-- +=========================================+==============================================================+
-- | @commands\/tron-debug.md@'s first        | 'tronIngestTorch' and 'tronMake' — two argv, because the      |
-- | @\<command\>@ block                     | corpus's @&&@ is a shell and sequencing is the program's       |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its second @\<command\>@ block (the     | 'tronIngestBulk' — the __control__ of the differential, run   |
-- | sglang status quo)                      | first, because a differential with no control is a guess      |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its third @\<command\>@ block           | 'tronRun' — the symptom, asked at @verdict@, so \"it did not  |
-- |                                         | reproduce\" is an ending rather than a surprise               |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its @model.bulk@, @model.loopy@,        | 'irDossier' — three @cat@ receipts and the @Fx.hs@ Note,      |
-- | @model.tron@ and @src\/Fx.hs@           | folded into one document every lens reads                     |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its \"Bulk, Loopy, Tron, and CPP        | 'stageRoster' — four lenses, one per IR boundary, three on     |
-- | intermediate representations\"          | @'Workflows.Parties.haskellPro'@ and the last on              |
-- |                                         | @'Workflows.Parties.cppPro'@                                  |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its \"the problem I am currently facing | @'Agentic.Workflow.input' \"problem\"@, spliced into every     |
-- | is: @$ARGUMENTS@\"                      | lens through 'stageClosing'                                   |
-- +-----------------------------------------+--------------------------------------------------------------+
-- | its \"it would be good to figure out    | 'synthesisBrief' — the differential question, asked once, over |
-- | why this works\"                        | a document that must be accounted for first                    |
-- +-----------------------------------------+--------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __A run that did not happen cannot be reasoned from.__ @doc\/design.md@
--      §7.2 row 65: \"three @\<command\>@ blocks are argv waiting to be receipts,
--      so the differential's diagnosis cannot rest on a run that did not happen —
--      this command's most exposed failure mode.\" In the corpus the three
--      commands are text inside @\<command\>@ tags, addressed to a model, and
--      whether any of them ran is a thing the transcript may or may not record.
--      Here each is an argv "Agentic.Shell" runs with @proc@, and __the diagnosis
--      node is only reachable through the arms in which all four commands
--      succeeded__. That is not a rule; it is the shape of the printed program,
--      and @wf plan tron --raw@ shows it.
--
--   2. __The @&&@ becomes sequencing.__ The first command block is
--      @cabal run … ingest … && make -C ..@, which is two processes joined by a
--      shell operator. There is no shell here, so it is two receipts, and the
--      compile is only asked for when the ingest's verdict approved. The corpus's
--      form has one failure mode this does not: a @make@ that succeeds against
--      the plugin the /previous/ run left behind.
--
--   3. __The control runs first.__ The corpus mentions the sglang path in its
--      /twelfth/ line, as something \"it would be good to figure out\". A
--      differential diagnosis whose control was not run is a one-sided reading
--      dressed as a comparison, so here it is the first statement of the program
--      and its failure is an ending: if the status quo does not ingest, there is
--      nothing to compare against and the run says so instead of diagnosing.
--
--   4. __\"It did not reproduce\" is an ending.__ 'tronRun' is asked at
--      @'Agentic.Workflow.Verdict'@, and "Agentic.Shell" answers a verdict by
--      running the argv: exit @0@ __approves__, a nonzero exit __objects with the
--      command's own first failing line__, and a missing binary or a hung run is a
--      __gap__ — a transport refusal, not an answer. Those are exactly the three
--      states a debugging run needs to tell apart, the corpus can express none of
--      them, and the middle one is where the objection /is/ the diagnosis's first
--      piece of evidence.
--
--   5. __Four IR boundaries, four lenses, one dossier.__ The corpus names the
--      pipeline — Torch, Bulk, Loopy, Tron, CPP — and then asks one reader to hold
--      all of it. 'stageRoster' is four members over one
--      @'Workflows.Panels.asksOver'@ fold, each told what it owns and what its
--      siblings own ('Workflows.Panels.memberNote'), and the C++ boundary goes to
--      @'Workflows.Parties.cppPro'@ because it is the one that is not a Haskell
--      question. The synthesis is
--      @'Workflows.Panels.refusingSynthesis'@'s, so a fold missing a stage's block
--      says @INCOMPLETE:@ and @'Workflows.Deciders.incompleteFanOut'@ reads it for
--      nothing.
--
-- == Two things this module is deliberately specific about
--
-- __The paths are this project's, and that is correct for this row.__
-- @tron-debug.md@ is written against one working tree: @src\/Fx.hs@,
-- @model.bulk@, @..\/h\/tron\/plugins@, @..\/gen\/runtron@, @model-trace.json@.
-- They are program constants here rather than inputs, for the reason
-- @doc\/design.md@ §7.4 row 22 gives @nodered@ — a deeply host-specific row
-- should be honest about being host-specific, and an input whose only sensible
-- value is one string is a flag nobody will ever vary. What /is/ an input is the
-- pair the corpus itself varies: the model name, and the Torch trace directory.
--
-- __The corpus writes the plugin directory two ways and this writes it one.__ Its
-- first command says @..\/h\/tron\/plugins\/@ and its second says
-- @..\/h\/tron\/plugins@ — the same directory, one with a trailing slash. Two
-- spellings of one path is exactly the drift "Workflows.Evidence" exists to end,
-- so 'pluginDir' is written once and both argv use it. If the two were ever meant
-- to differ, this row is where that would now be visible.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Tron
  ( -- * The program
    tronProgram,
    tronDoc,
    tronScript,

    -- * The four IR boundaries
    stageRoster,
    stages,

    -- * The tier-1 readings of an invocation
    torchModel,
    bulkModel,
    torchTrace,
    pluginDir,

    -- * The rubrics, transplanted
    pipelineNote,
    synthesisBrief,

    -- * The function
    tronReportFn,
    tronTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The argv
-- ---------------------------------------------------------------------------

-- $argv
--
-- These belong in "Workflows.Evidence" — that module is where the read-only rule
-- could be broken, so it is reviewable as a unit. They are grouped here, in one
-- labelled block, for @'Workflows.Git.Stack'@'s reason: the move is one cut and
-- one paste, and the exception is visible rather than scattered.
--
-- None of them points at @~\/src\/nix\/config\/ai@ and none of them is composed
-- with a shell. Every one is a @\<command\>@ block of @commands\/tron-debug.md@,
-- flag for flag, with the shell operators removed because there is no shell.

-- | @cabal run --flag +no-werror ingest -- --model-name M --output-dir D
-- --torch-trace-directory T --dump-all@ — the pipeline under test.
--
-- /Source:/ @commands\/tron-debug.md@'s first @\<command\>@ block, up to its
-- @&&@. The @&&@ and everything after it is 'tronMake', because a shell operator
-- is not an argv and because the sequencing belongs to the program: see the
-- module header, item 2.
--
-- Asked at @'Agentic.Workflow.Verdict'@, which is the one kind of ask that
-- survives a nonzero exit — so a failing ingest yields the compiler's or the
-- pipeline's own first failing line, and that line is the subject of the
-- diagnosis rather than a paraphrase of it.
tronIngestTorch :: Text -> Text -> Party 'IsTool
tronIngestTorch modelName traceDir =
  tool "tron-ingest-torch"
    `running` ( "cabal",
                [ "run",
                  "--flag",
                  "+no-werror",
                  "ingest",
                  "--",
                  "--model-name",
                  modelName,
                  "--output-dir",
                  pluginDir,
                  "--torch-trace-directory",
                  traceDir,
                  "--dump-all"
                ]
              )

-- | @cabal run --flag +no-werror ingest -- --model-name M --output-dir D
-- --bulk-trace-file model-trace.json --dump-all@ — the status quo.
--
-- /Source:/ @commands\/tron-debug.md@'s second @\<command\>@ block, flag for
-- flag. This is the __control__ of the differential the file asks for: \"the
-- status quo reasons with the existing sglang frontend … it would be good to
-- figure out why this works to determine whether changes to the backend are
-- really needed\".
--
-- Asked as a __flag__ rather than a verdict, and the asymmetry is deliberate: what
-- matters about the control is /that/ it still works, because that is what makes
-- the comparison meaningful. Its failing line would be a different bug's evidence,
-- and a run that cannot build the status quo is not a run that should be
-- diagnosing the new path.
tronIngestBulk :: Text -> Party 'IsTool
tronIngestBulk modelName =
  tool "tron-ingest-bulk"
    `running` ( "cabal",
                [ "run",
                  "--flag",
                  "+no-werror",
                  "ingest",
                  "--",
                  "--model-name",
                  modelName,
                  "--output-dir",
                  pluginDir,
                  "--bulk-trace-file",
                  "model-trace.json",
                  "--dump-all"
                ]
              )

-- | @make -C ..@ — the second half of the corpus's first command block.
--
-- /Source:/ the same block, after the @&&@. It builds the C++ Tron plugin the
-- ingest just wrote into 'pluginDir', so it is the one receipt that says whether
-- the generated C++ compiles at all — which is a different question from whether
-- it is right, and is the cheaper one.
tronMake :: Party 'IsTool
tronMake = tool "tron-make" `running` ("make", ["-C", ".."])

-- | @..\/gen\/runtron --model M stream-generate-text hello world@ — the symptom.
--
-- /Source:/ @commands\/tron-debug.md@'s third @\<command\>@ block, verbatim
-- including its two-word prompt. Asked at @'Agentic.Workflow.Verdict'@ for the
-- reason the module header's item 4 gives: the three tags a verdict has are the
-- three states this run needs to distinguish, and the objecting one carries the
-- runtime's own first failing line.
tronRun :: Text -> Party 'IsTool
tronRun modelName =
  tool "tron-run"
    `running` ("../gen/runtron", ["--model", modelName, "stream-generate-text", "hello", "world"])

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The plugin output directory, written once.
--
-- /Source:/ @commands\/tron-debug.md@'s two command blocks, which spell it two
-- ways; see the module header's second note for why this is one binding.
pluginDir :: Text
pluginDir = "../h/tron/plugins"

-- | The model whose Torch Fx path is under test.
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and zero paths, and the default is the corpus's own
-- @llama_3p1_8b_torch@. That is @commands\/fix-integration.md@'s arrangement —
-- @doc\/design.md@ §7.2 row 18 — applied to a model name: the row generalises to
-- another model without losing the one the command was written for.
torchModel :: Text -> Text
torchModel m
  | T.null (T.strip m) = "llama_3p1_8b_torch"
  | otherwise = T.strip m

-- | The same model's sglang sibling, which is the control.
--
-- __Tier 1__, and it is computed rather than asked for: the corpus's two command
-- blocks name @llama_3p1_8b_torch@ and @llama_3p1_8b@, which is the same model
-- through two frontends, and the naming convention is the suffix. So one input
-- names both sides of the differential and they cannot be mismatched — which is
-- the failure that would make the whole comparison meaningless while looking
-- exactly like a real result.
--
-- A model name that does not end in @_torch@ is passed through unchanged, on the
-- assumption that an operator who named the sglang side directly meant it; the
-- report names both, so a mistake here is visible rather than silent.
bulkModel :: Text -> Text
bulkModel m = case T.stripSuffix "_torch" (torchModel m) of
  Just b -> b
  Nothing -> torchModel m

-- | The Torch trace directory the ingest reads.
--
-- __Tier 1__, and the default is the corpus's own
-- @exports\/meta-llama-Llama-3.1-8B-Instruct@ — the export that goes with the
-- default model. An operator who changes the model and not the trace gets a plan
-- that shows both, which is why they are two flags.
torchTrace :: Text -> Text
torchTrace t
  | T.null (T.strip t) = "exports/meta-llama-Llama-3.1-8B-Instruct"
  | otherwise = T.strip t

-- ---------------------------------------------------------------------------
-- The four IR boundaries
-- ---------------------------------------------------------------------------

-- | The pipeline, boundary by boundary.
--
-- /Source:/ @commands\/tron-debug.md@'s first paragraph — \"you can read the Note
-- in @src\/Fx.hs@ for details on the Torch -> Bulk pipeline. After that it passes
-- through Bulk, Loopy, Tron, and CPP intermediate representations\" — which names
-- five stages and therefore four boundaries. Each row is @(name, what it owns)@,
-- and 'stageRoster' turns it into the fan-out.
--
-- __The boundaries are what a lens can own, and the stages are not.__ A bug in a
-- compilation pipeline lives at a translation, not in a representation: the
-- question is always \"what did this pass do to that\", so each member below is
-- named for the pass and is given the input and the output it is responsible for.
stages :: [(Text, Text)]
stages =
  [ ( "bulk",
      "the Torch Fx -> Bulk translation: whether the Bulk dump is a faithful \
      \reading of the traced graph, and whether anything the trace expressed was \
      \dropped, defaulted or silently reshaped on the way in"
    ),
    ( "loopy",
      "the Bulk -> Loopy translation: whether the loop and iteration structure \
      \Loopy imposes matches what Bulk described, and whether any implicit \
      \broadcast, reduction or ordering assumption was introduced here"
    ),
    ( "tron",
      "the Loopy -> Tron translation: whether the Tron dump's operations, \
      \buffers and schedule are what Loopy asked for, and whether anything about \
      \layout, dtype or lifetime was decided here rather than carried"
    ),
    ( "cpp",
      "the Tron -> C++ plugin translation: whether the emitted code implements \
      \the Tron dump it was generated from, and whether the fault is in the \
      \emitter rather than in anything upstream of it"
    )
  ]

-- | The four boundaries as a roster.
--
-- Three members on @'Workflows.Parties.haskellPro'@, because three of the four
-- boundaries are passes in a Haskell compiler and the question at each is what
-- some Haskell did to a data structure; the fourth on
-- @'Workflows.Parties.cppPro'@, because the emitted plugin is C++ and reading
-- generated C++ against its own IR is a different skill. That is the corpus's
-- @agents\/*-pro.md@ family being /used/ rather than described.
--
-- __The roster is fixed at four, so house rule WR-1 has nothing to say here__: no
-- input shapes it, and @'Agentic.Workflow.panelText' []@ is unreachable.
stageRoster :: Roster
stageRoster =
  [ Lens
      { lensName = n,
        lensOwns = owns,
        lensBrief = stageBrief n owns,
        lensParty = partyFor n
      }
  | (n, owns) <- stages
  ]
  where
    -- A guard and not an `if`: under `RebindableSyntax` an `if` in this module
    -- means `Agentic.Workflow.ifThenElse`, which is a workflow branch over a
    -- flag handle. That is the extension doing exactly what it is for, and a
    -- guard is how ordinary Haskell is written beside it.
    partyFor n
      | n == "cpp" = cppPro
      | otherwise = haskellPro

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | @commands\/tron-debug.md@'s first paragraph, as the standing context every
-- question in this row carries.
--
-- /Source:/ verbatim in substance, with one thing made explicit that the corpus
-- leaves to the reader: which dump file corresponds to which stage, since the
-- three dumps are the evidence and a lens reading the wrong one is a lens
-- answering about somebody else's pass.
pipelineNote :: Text
pipelineNote =
  [wft|
  This is the ingest pipeline that turns a Torch Fx trace into a C++ Tron
  plugin. The stages, in order:

    Torch Fx  ->  Bulk  ->  Loopy  ->  Tron  ->  C++ plugin

  The Note in `src/Fx.hs` documents the Torch -> Bulk half and is included in
  the dossier below, because that half is where an assumption about the traced
  graph gets baked in.

  A run with `--dump-all` writes one file per intermediate representation --
  `model.bulk`, `model.loopy`, `model.tron` -- and the plugin itself into the
  plugin output directory. The three dumps are in the dossier below, fenced
  under those names, and they are the primary evidence: they are bytes the
  pipeline wrote, and where a dump and a reading of the source disagree, the
  dump is what happened.|]

-- | What each stage lens is told about its own boundary.
--
-- Derived from 'stages', so a boundary added to that table arrives in the
-- fan-out, in the sibling note and in the synthesis's accounting __by being
-- added__ — which is 'Workflows.Panels.memberNote''s and
-- 'Workflows.Panels.refusingSynthesis''s arrangement.
stageBrief :: Text -> Text -> Text
stageBrief n owns =
  [wft|
  You own one translation in a compiler pipeline: {owns}

  Your block is named `{n}`. Answer about your own boundary and nothing else.

  Work from the dumps, not from the source alone. For your boundary:

  1. State what your pass was given and what it produced, in the terms of the
     two dumps that bracket it. Where your input is the Torch trace or your
     output is the emitted plugin, say which of those you can and cannot see
     from the dossier.
  2. Find the specific place the symptom could originate at this boundary --
     an operation that changed meaning, a shape or dtype that was decided
     rather than carried, an ordering that was imposed, a case the pass does
     not handle and silently passes through.
  3. For each candidate, say what in the dossier would confirm or refute it,
     and say plainly whether the dossier contains that or not. "I would need
     the Loopy dump for the sglang path to be sure" is a complete and useful
     answer; a confident diagnosis that the dossier cannot support is not.
  4. If your boundary is clean -- your output is a faithful translation of your
     input and the symptom cannot originate here -- say so, and say what makes
     you sure. A clean boundary stated is how a pipeline bug gets localised;
     a boundary nobody spoke about is not.

  Do not propose a fix. Do not rewrite anything. This run reads.|]

-- | What the differential synthesis is told.
--
-- /Source:/ 'Workflows.Panels.refusingSynthesis' — the roster accounting — plus
-- @commands\/tron-debug.md@'s closing question, which is the whole reason the
-- control is run: \"it would be good to figure out why this works to determine
-- whether changes to the backend are really needed or whether something needs to
-- be changed in the frontend.\"
--
-- That sentence is a __differential__ and it names the two answers it can have.
-- Here it is asked once, of a party that reads four accounted-for blocks and three
-- command receipts, and it is asked to choose.
synthesisBrief :: Roster -> Text
synthesisBrief r =
  [wft|
  {refusing}

  Then, and this is what the run is for, answer the differential question. The
  same ingest binary produced a working plugin for the sglang frontend and the
  plugin under test for the Torch Fx frontend. So:

  - Is the fault in the BACKEND -- a pass that is wrong for both frontends and
    that the sglang path happens not to exercise? Then say which pass, and say
    what the sglang path does differently that avoids it.
  - Or is it in the FRONTEND -- the Torch -> Bulk translation producing a Bulk
    program that is legal but is not what the sglang path produces? Then say
    what differs, and say which of the two is the intended shape.

  Answer with one of those two, or with "not yet determined" and the single
  piece of evidence that would decide it. Those are the three honest answers.
  A diagnosis that names a pass without saying why the control path survives it
  has not used the control, and the control is the only thing in this run that
  separates a bug from a design decision.

  Close with the smallest experiment that would confirm the answer -- one
  command, one dump to look at, or one line to change and re-ingest.|]
  where
    refusing = refusingSynthesis r

-- | What each dump receipt is introduced as.
dumpBrief :: Text
dumpBrief =
  [wft|
  An intermediate representation dumped by the ingest run that just happened.
  This is a receipt: whatever the file holds is the answer, and nothing is
  added to it.|]

-- | What the @Fx.hs@ receipt is introduced as.
--
-- /Source:/ @commands\/tron-debug.md@'s \"you can read the Note in @src\/Fx.hs@
-- for details on the Torch -> Bulk pipeline\".
noteBrief :: Text
noteBrief =
  [wft|
  The source of the Torch -> Bulk half of the pipeline, whose Note documents
  the translation. A receipt: what the file says is the answer.|]

-- | What the control receipt is asked.
controlBrief :: Text
controlBrief =
  [wft|
  The status quo: the same ingest binary over the existing sglang frontend for
  the same model. A pass here means the control of this differential is intact
  and a comparison is available. A failure means it is not, and this run has
  nothing to compare the Torch Fx path against.|]

-- | What the ingest receipt is asked.
ingestBrief :: Text
ingestBrief =
  [wft|
  The Torch Fx ingest under test, with every intermediate representation
  dumped. A pass means the pipeline ran to completion and wrote the dumps and
  the plugin; a failure carries the pipeline's own first failing line, which is
  then the subject of the diagnosis rather than a paraphrase of it.|]

-- | What the compile receipt is asked.
makeBrief :: Text
makeBrief =
  [wft|
  The build of the C++ Tron plugin the ingest just emitted. This asks whether
  the generated code compiles, which is a different and cheaper question than
  whether it is correct -- and a failure here localises the fault to the
  emitter before anything else is asked.|]

-- | What the runtime receipt is asked.
runBrief :: Text
runBrief =
  [wft|
  The model, run through the plugin that was just built. A pass means it
  generated without failing; a failure carries the runtime's own first failing
  line; and a missing binary or a hung run is neither -- it is a gap, and this
  run says so rather than treating it as a failure of the model.|]

-- | What each lens is told about the fan-out it is one of, and what this run is
-- looking for.
--
-- The @problem@ input is spliced here rather than into 'stageBrief', for one
-- reason worth stating: the briefs are the scripted table's keys, and a key
-- computed from an input is a key that changes with the invocation. The closing
-- line is passed to @'Workflows.Panels.asksOver'@ and lands after the brief in
-- every member's prompt, so the problem reaches all four lenses and the four keys
-- stay fixed.
stageClosing :: Text -> Text
stageClosing problem =
  [wft|
  The problem this run is diagnosing:

  {problem}

  Report on your own boundary and nothing else. Your answer is one block of a
  document whose other blocks are the other boundaries', each fenced under its
  own name: do not diagnose theirs, and do not summarise the whole. The
  synthesis that reads this document is told to account for every block, so a
  block that says "clean, and here is why" is worth as much as one that names a
  fault.|]

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the control does not build.
controlBrokenNote :: Text
controlBrokenNote =
  "Outcome: NO CONTROL -- NOTHING WAS DIAGNOSED. The sglang ingest, which is the \
  \status quo this differential compares against, did not complete. So there is no \
  \working path to compare the Torch Fx path with, and this run refuses to \
  \diagnose: a one-sided reading presented as a differential is exactly the \
  \mistake this row exists to prevent. Report which command was run, and say that \
  \fixing or rebuilding the status quo is the prerequisite -- not a detail."

-- | The arm where the ingest under test fails.
ingestFailedNote :: Text
ingestFailedNote =
  "Outcome: THE INGEST DID NOT COMPLETE. The Torch Fx pipeline failed before it \
  \wrote its dumps, so there is no Bulk, Loopy or Tron dump from this run to read \
  \and no plugin to build. That is not a dead end -- it is a better-localised \
  \failure than the one the operator came in with. The pipeline's own first \
  \failing line is the closing evidence below: report it verbatim, say which stage \
  \of the pipeline it comes from, and say what to look at first. Do not diagnose \
  \any boundary downstream of the failure, because nothing downstream ran."

-- | The arm where the emitted plugin does not compile.
makeFailedNote :: Text
makeFailedNote =
  "Outcome: THE GENERATED C++ DOES NOT COMPILE. The ingest completed and wrote its \
  \dumps and its plugin, and the build of that plugin failed. This localises the \
  \fault to the Tron -> C++ emitter more sharply than any reading of the IRs \
  \could: the emitter produced code that is not valid C++, which is a bug in the \
  \emitter and not a question about semantics. Report the compiler's own first \
  \failing line verbatim, and name the emitted construct it is about. The three IR \
  \dumps exist and are worth reading next, but the first thing to look at is the \
  \emitter."

-- | The arm where a command is missing or hung.
--
-- /Source:/ no line of the corpus, because the corpus cannot express it.
-- "Agentic.Shell" raises a @GapTransportRefusal@ for a command that is missing or
-- outran its clock, which in the owner's own terms is: __the gate did not say no;
-- it did not run__.
toolMissingNote :: Text
toolMissingNote =
  "Outcome: A COMMAND DID NOT RUN. One of this run's commands was missing, or \
  \outran its clock -- it did not fail, it did not run. That is a fact about this \
  \working tree and not about the pipeline: the wrong directory, an unbuilt \
  \`runtron`, a `cabal` outside the project, a Nix shell that was not entered. \
  \Report which command it was and what its argv was, and say that no conclusion \
  \at all follows about the model or the pipeline. Nothing was diagnosed."

-- | The arm where the symptom did not reproduce.
--
-- The ending that matters most to an operator and that the corpus has no place to
-- put: it asserts the problem in its tenth line and never asks whether the problem
-- is still there.
noReproNote :: Text
noReproNote =
  "Outcome: DID NOT REPRODUCE. The ingest completed, the plugin built, and the \
  \model generated without failing -- so the symptom this run was given did not \
  \occur here. Do NOT diagnose anything. Report exactly what was run, in full argv, \
  \and then the two possibilities, because they need different next steps: either \
  \the symptom is conditional on something this invocation did not carry (a longer \
  \prompt, a different model, a different trace directory, a stale plugin from a \
  \previous build) or it is a WRONG-OUTPUT symptom rather than a failure, which an \
  \exit code cannot see. If it is the second, the next run needs the expected \
  \output beside the actual, and this row cannot supply that."

-- | The arm where the fan-out came up short.
shortFanOutNote :: Text
shortFanOutNote =
  "Outcome: INCOMPLETE DIAGNOSIS. The synthesis refused, because at least one of \
  \the four pipeline boundaries produced no block; its first line names which. \
  \Label this report incomplete and name the missing boundaries. A pipeline \
  \diagnosis that skipped a translation has not localised anything -- the fault is \
  \as likely to be at the boundary nobody spoke about as at any of the others."

-- | The arm where everything ran and the differential was answered.
diagnosedNote :: Text
diagnosedNote =
  "Outcome: DIAGNOSED, OVER RUNS THAT HAPPENED. The control ingest passed, the \
  \Torch Fx ingest completed, the emitted plugin compiled, and the model then \
  \failed at run time -- so every piece of evidence below comes from a command \
  \this run executed, and the runtime's own failing line is in it. Four pipeline \
  \boundaries were read independently over the same three IR dumps and the same \
  \`Fx.hs` Note, and the synthesis accounted for all four before answering the \
  \frontend-or-backend question. Report the answer, the boundary it localises to, \
  \the evidence for it, and the one experiment that would confirm it."

-- ---------------------------------------------------------------------------
-- The function
-- ---------------------------------------------------------------------------

-- | What the report is written through.
tronReportBrief :: Text
tronReportBrief =
  [wft|
  Write the report for a debugging run over the Torch Fx ingest pipeline. It is
  read by the person who will make the next change to that pipeline.

  Open with the provenance line you were given, verbatim, on its own line. It is
  the run's own account of what ran and what did not, and it is not yours to
  soften: in particular, if it says nothing was diagnosed, do not diagnose.

  Then, from the work below and nothing else:

  - what was run, as argv, and what each command answered -- pass, its own
    failing line, or did not run. Every claim further down rests on this list,
    so it goes first;
  - the diagnosis, if there is one: the boundary it localises to, whether the
    fault is in the frontend or the backend, and why the sglang control path
    survives it;
  - the evidence, by dump and by line, so a reader can check the diagnosis
    against the same bytes;
  - what is NOT established, and what would establish it;
  - the smallest next experiment.

  Two things you must not write. Do not describe a command's result that is not
  in the list above -- if it did not run, nothing follows from it. And do not
  turn "not yet determined" into a leaning: a differential that did not resolve
  is a real answer, and dressing it as a probable cause is how the next person
  spends a day in the wrong pass.|]

-- | One act, seven provenance lines.
--
-- Three parameters, in the order the body reads them: the provenance first, for
-- "Workflows.Report"'s reason; then the diagnosis or the dossier, whichever the
-- arm has; then the closing evidence, which on every arm is what the commands
-- said.
tronReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeVerdict] 'CodeAck
tronReportFn =
  function
    "tron.report"
    ( takes @"provenance" Text
        . takes @"findings" Text
        . takes @"evidence" Verdict
        $ noParams
    )
    \provenance findings evidence -> W.do
      act reporter [wf|
          {writing}

          Provenance:

          {provenance}

          What was found:

          {findings}

          What the commands said:

          {evidence}

          Write the report, then reply DONE.|]
      done
  where
    writing = tronReportBrief

-- | The table 'tronProgram' hands @'Agentic.Workflow.defining'@.
tronTable :: [SomeFn]
tronTable = [SomeFn tronReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The control, the pipeline, the compile, the run — and only then a diagnosis.
--
-- Three inputs. @problem@ is @$ARGUMENTS@ with a name — the symptom, spliced into
-- all four lenses through 'stageClosing'; @model@ names both sides of the
-- differential, through 'torchModel' and 'bulkModel'; @trace@ is the Torch export
-- directory, and 'torchTrace' carries the corpus's own default.
--
-- The shape, top to bottom: run the status quo, and stop if it does not build; run
-- the pipeline under test, and stop with its own failing line if it does not
-- complete; build the plugin it emitted, and stop with the compiler's line if it
-- does not compile; run the model, and stop if the symptom did not reproduce; only
-- then read the three dumps and the @Fx.hs@ Note, fan out over the four pipeline
-- boundaries, and answer the frontend-or-backend question over a document that had
-- to be accounted for first.
--
-- __Seven endings, seven provenance lines, one__ 'tronReportFn'. Three of the
-- seven are \"a command did not do what this run needed\", and each of those is
-- more useful than the diagnosis it replaces, because it is better localised. The
-- diagnosis node sits at the bottom of four nested successes, which is
-- @doc\/design.md@ §7.2 row 65's whole claim expressed as reachability.
tronProgram :: Parameterized
tronProgram =
  taking (input "problem" :> input "model" :> input "trace" :> noInputs) \problem modelArg traceArg ->
    -- Tier 1, four times: both model names, the trace directory and the closing
    -- line the problem rides on. All four are ordinary Haskell over the
    -- invocation and the first three are in the printed argv.
    let torch = torchModel modelArg
        control = bulkModel modelArg
        traceDir = torchTrace traceArg
        closing = stageClosing problem
        situation = situationOf problem
        synthesis = synthesisBrief stageRoster
     in defining tronTable W.do
          -- The control, first. A differential whose control did not run is a
          -- one-sided reading, and the corpus mentions this command twelve lines
          -- in as something it would be good to try.
          intact <- passes (tronIngestBulk control) [wf|{controlling}|]

          if intact
            then W.do
              -- The pipeline under test, at `verdict` -- the one kind of ask that
              -- survives a nonzero exit, so a failure yields the pipeline's own
              -- first failing line.
              ingested <- ask (tronIngestTorch torch traceDir) [wf|{ingesting}|] `answering` Verdict

              caseVerdict
                ingested
                ( W.do
                    compiled <- ask tronMake [wf|{compiling}|] `answering` Verdict

                    caseVerdict
                      compiled
                      ( W.do
                          ran <- ask (tronRun torch) [wf|{runningModel}|] `answering` Verdict

                          caseVerdict
                            ran
                            -- Approved: it generated. The symptom did not
                            -- reproduce, and that is an ending.
                            ( W.do
                                call_ tronReportFn (arg noReproNote :> arg situation :> arg ran :> noArgs)
                                stop
                            )
                            -- Objected: the symptom reproduced, and the runtime's
                            -- own failing line is in hand. Now, and only now, is
                            -- there anything to diagnose.
                            ( W.do
                                irs <- panelText irDossier

                                found <- panelText (zip (lensNames stageRoster) (asksOver stageRoster closing irs))

                                diagnosis <- ask (reasoning (model "tron-synthesis")) [wf|
                                    {synthesis}

                                    {pipeline}

                                    What the runtime said:

                                    {ran}

                                    The four boundary readings:

                                    {found}|]

                                short <- tested incompleteFanOut diagnosis

                                if short
                                  then W.do
                                    call_ tronReportFn (arg shortFanOutNote :> arg diagnosis :> arg ran :> noArgs)
                                    stop
                                  else W.do
                                    call_ tronReportFn (arg diagnosedNote :> arg diagnosis :> arg ran :> noArgs)
                                    stop
                            )
                            ( W.do
                                call_ tronReportFn (arg toolMissingNote :> arg situation :> arg ran :> noArgs)
                                stop
                            )
                      )
                      ( W.do
                          call_ tronReportFn (arg makeFailedNote :> arg situation :> arg compiled :> noArgs)
                          stop
                      )
                      ( W.do
                          call_ tronReportFn (arg toolMissingNote :> arg situation :> arg compiled :> noArgs)
                          stop
                      )
                )
                ( W.do
                    call_ tronReportFn (arg ingestFailedNote :> arg situation :> arg ingested :> noArgs)
                    stop
                )
                ( W.do
                    call_ tronReportFn (arg toolMissingNote :> arg situation :> arg ingested :> noArgs)
                    stop
                )
            else W.do
              ask_ reporter [wf|
                  {controlBroken}

                  The control that did not build: the sglang ingest for model
                  `{control}`.

                  The Torch Fx path this run would have diagnosed: model
                  `{torch}`, trace directory `{traceDir}`.|]
  where
    controlling = controlBrief
    ingesting = ingestBrief
    compiling = makeBrief
    runningModel = runBrief
    pipeline = pipelineNote
    controlBroken = controlBrokenNote

-- | The pipeline note with the symptom under it, for the arms that have no
-- diagnosis to report.
--
-- __Tier 1__: the four command-failure endings and the did-not-reproduce ending
-- have nothing a model produced to hand the report, and "nothing" is the wrong
-- thing to hand it — a reader of a report that says a command failed wants the
-- symptom that was being chased beside it. Both halves are in the invocation, so
-- this costs nothing.
situationOf :: Text -> Text
situationOf problem =
  pipelineNote
    <> "\n\nThe problem this run was given:\n\n"
    <> problem

-- | The three IR dumps and the @Fx.hs@ Note, as the dossier every lens reads.
--
-- /Source:/ @commands\/tron-debug.md@'s \"this will produce a number of IR dump
-- files named @model.*@ (e.g. @model.bulk@, @model.loopy@, @model.tron@)\" and its
-- \"read the Note in @src\/Fx.hs@\".
--
-- Bound __once__, spliced into all four members by
-- @'Workflows.Panels.asksOver'@ — so the four boundaries cannot be reading four
-- different dumps, which is @commands\/heavy-review.md@'s frozen-snapshot argument
-- arriving at a compiler pipeline.
--
-- The four paths are program constants for the reason the module header's second
-- note gives: they are this project's, the corpus writes them as literals, and an
-- input whose only sensible value is one string is a flag nobody will vary.
irDossier :: [(Text, Ask s)]
irDossier =
  [ ("fx-note", ask (fileContents "src/Fx.hs") [wf|{note}|]),
    ("bulk", ask (fileContents "model.bulk") [wf|{dump}|]),
    ("loopy", ask (fileContents "model.loopy") [wf|{dump}|]),
    ("tron", ask (fileContents "model.tron") [wf|{dump}|])
  ]
  where
    note = noteBrief
    dump = dumpBrief

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
tronDoc :: Text
tronDoc =
  "tron-debug.md: the control, the ingest, the compile and the run as four receipts, and a diagnosis only reachable through all four"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every receipt's question opens with its own brief, each
-- boundary's with its own 'Workflows.Panels.lensBrief' (derived from 'stages', so
-- a boundary added to that table arrives here by being added), and the synthesis's
-- with @'synthesisBrief' 'stageRoster'@.
--
-- __The flag and verdict defaults do the steering, and they steer it to the wrong
-- arm.__ @'Agentic.Exec.scriptedDefault'@ answers a flag @yes@ and a verdict
-- @APPROVE@, so with no rows for the four commands the control passes, the ingest
-- and the compile approve — and then the /run/ approves too, which is the
-- @noReproNote@ arm: the shortest walk through this program and the one that
-- diagnoses nothing. So 'runBrief' has a row here that __objects__, which is what
-- puts the scripted run down the four-nested-successes path and through the whole
-- fan-out. That single row is this table's load-bearing line, and deleting it
-- rehearses the did-not-reproduce ending instead. Both exit 0.
--
-- The other endings are each one line away: @(controlBrief, \"no\")@ reaches the
-- no-control terminal, an @OBJECTION:@ on 'ingestBrief' or 'makeBrief' reaches the
-- two failing-command arms, and an @INCOMPLETE:@ first line on the synthesis
-- reaches the short-fan-out report.
tronScript :: [(Text, Text)]
tronScript =
  [ (ingestBrief, "APPROVE"),
    (makeBrief, "APPROVE"),
    (runBrief, "OBJECTION: runtron: assertion failed: buffer 17 lifetime ends before its last use"),
    (noteBrief, note),
    (dumpBrief, dump),
    (synthesisBrief stageRoster, diagnosed)
  ]
    <> [(lensBrief l, boundaryAnswer l) | l <- stageRoster]
  where
    note =
      "-- Note [Torch Fx -> Bulk]\n\
      \-- The traced graph is walked once; every node becomes exactly one Bulk\n\
      \-- operation, and buffer lifetimes are computed from the walk order rather\n\
      \-- than from the graph's use-def edges."

    dump =
      "op 16: matmul  in=[b12,b13] out=[b17]\n\
      \op 17: add     in=[b17,b14] out=[b18]\n\
      \op 18: output  in=[b18]"

    diagnosed =
      "All four boundaries accounted for.\n\
      \\n\
      \FRONTEND. The Torch -> Bulk translation computes buffer lifetimes from walk \
      \order, and the Fx trace for this model reuses a buffer across a branch the \
      \sglang frontend never emits -- so the lifetime it assigns to b17 ends before \
      \op 17 reads it. Every pass downstream carries that lifetime faithfully, which \
      \is why the Loopy, Tron and C++ boundaries are all clean.\n\
      \\n\
      \Why the control survives it: the sglang frontend emits a linear graph, so walk \
      \order and use-def order coincide and the assumption in Note [Torch Fx -> Bulk] \
      \holds.\n\
      \\n\
      \Smallest experiment: re-ingest with the walk-order lifetime computation \
      \replaced by a use-def scan, and diff `model.bulk`. If b17's lifetime extends \
      \past op 17, that is the fault."

    boundaryAnswer l
      | lensName l == "bulk" =
          "The Bulk dump assigns b17 a lifetime ending at op 16, and op 17 reads \
          \b17. That is inconsistent, and it is decided here: the Note says \
          \lifetimes come from walk order. Confirmed by the dump; the Torch trace \
          \itself is not in this dossier, so I cannot say what the trace intended. \
          \(the bulk boundary)"
      | otherwise =
          "This boundary is clean: my output is a faithful translation of my input, \
          \including the lifetime it was given, which is the thing the symptom is \
          \about. I carry it, I do not decide it. (the "
            <> lensName l
            <> " boundary)"
