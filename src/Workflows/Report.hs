-- |
-- Module      : Workflows.Report
-- Description : The output contract, as functions every rung calls.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/commands\/deep-review.md@ Step 5
-- (deduplicate, filter, sort, group, and the report skeleton);
-- @commands\/markdown.md@ (the GitHub suggestion form, which is the whole of
-- that file); @commands\/quick-review.md@'s @## Output@ block.
--
-- == Why these are 'Agentic.Workflow.Fn's and not defines
--
-- A define is spliced; a function is __called__, and a call is what makes two
-- programs provably share a tail. @commands\/sec-audit.md@ carries
-- @deep-review@'s report format today __by prose reference__ — \"use the same
-- format\" — which is a promise no reader can check and no gate can hold. Here
-- it is @call_ reportFn@, and the two rungs cannot drift in their output format
-- because there is one.
--
-- __A call costs what writing the callee's statements at the call site costs.__
-- @rhsAsks@ prices it at the callee's own @bodyAsks@ with the arguments ignored
-- and @graft@ splices the callee's node rather than adding one, so registering
-- a shared tail moves @size@, @askNodes@ and every path by nothing.
--
-- == The @{provenance}@ parameter, which is the level-up
--
-- Every report function here takes a provenance text as its first argument. It
-- is how @agents\/fess-auditor.md@'s \"run the audit but report that its
-- independence was not verified\" stops being a hope: two arms of a @case@ call
-- __one__ report function with two different notes, so a report that ran without
-- an independence attestation cannot come out claiming one. The same slot
-- carries 'Workflows.Escalation''s three ending notes.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Report
  ( -- * The briefs
    reportBrief,
    suggestionsBrief,

    -- * The functions
    reportFn,
    suggestionsFn,
    reportTable,
  )
where

import Agentic.Workflow
  ( Answer (Text),
    Code (CodeAck, CodeText),
    Fn,
    SomeFn (SomeFn),
    act,
    done,
    function,
    noParams,
    takes,
    wf,
    wft,
  )
import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import qualified Data.Text as DT
import Workflows.Parties (reporter)
import Workflows.Rubrics.Finding (categories, severities)
import Prelude

-- ---------------------------------------------------------------------------
-- The briefs
-- ---------------------------------------------------------------------------

-- | The consolidated finding report.
--
-- /Source:/ @commands\/deep-review.md@ Step 5, whose four operations and whose
-- report skeleton are carried verbatim. Two things are derived rather than
-- transcribed — the severity headings and the category vocabulary — so that
-- adding a severity or a category reaches this brief by being added
-- ("Workflows.Rubrics.Finding").
--
-- The closing guidelines are @deep-review@'s @## Important guidelines@, which
-- are the part of that file that is about /judgment/ rather than about
-- orchestration, and are the part worth keeping.
reportBrief :: DT.Text
reportBrief =
  [wft|
  Write the consolidated review report. You are given one document whose
  blocks are the reviewers' answers, each fenced under its own name, and a
  provenance line that says how the review was run.

  Fold it in this order, and do not reorder these:

  1. Deduplicate -- remove findings that several reviewers flagged
     identically. A finding two reviewers reached independently is one
     finding; say that two reached it.
  2. Filter -- drop findings below the confidence floor you were given, and
     say at the end how many were dropped and what the closest one was.
  3. Sort -- by severity ({severityLine}), then by file path.
  4. Group -- present the findings under one heading per severity.

  The report:

  # Code Review Report

  **Scope**: <what was reviewed>
  **Provenance**: <the provenance line you were given, verbatim>
  **Reviewers**: <every block name in the document, and for each, findings or "clean">

  ## Summary
  <one line per severity, with a count>

  <one section per severity, in order, with the findings>

  ## Review Notes
  <meta-observations about quality, architecture or patterns>

  Categories are exactly: {categoryLine}.

  Guidelines, which are about judgment and not about format:

  - Never invent findings. If the code looks correct, say so. False positives
    erode trust faster than missed bugs.
  - Be specific. Every finding references a concrete file and line range.
  - Provide fixes. A finding without a suggested fix is only half useful.
  - Frame findings as observations, not accusations. Assume competence.
  - Note uncertainty explicitly, and say what would settle it.

  A reviewer whose block is missing or empty is named in the Reviewers line as
  missing. Do not silently produce a report from a partial fan-out.|]
  where
    severityLine = DT.intercalate " -> " severities
    categoryLine = DT.intercalate " | " categories

-- | The same findings, as GitHub suggestion blocks.
--
-- /Source:/ @commands\/markdown.md@, which is one sentence long and is the
-- entire specification. It asks for something concrete and mechanical, so it
-- becomes a function rather than a command: any rung can end in it.
suggestionsBrief :: DT.Text
suggestionsBrief =
  [wft|
  Write the findings below to a GitHub-flavored Markdown document, using
  GitHub's suggestion blocks, so that each one can be pasted directly into a
  review comment.

  One section per finding, in the order given. Each section is:

  - a heading line naming the file and the line range;
  - one sentence of what is wrong;
  - a fenced block opened with ```suggestion containing the replacement lines
    and nothing else.

  A finding whose fix is not a literal replacement of specific lines gets no
  suggestion block: write the sentence and say plainly that the fix is not
  mechanical. A suggestion block that does not apply cleanly is worse than no
  block, because it is pasted before it is read.|]

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | The report, as the tail every review rung calls.
--
-- Two parameters, and the order is the one the body reads them in: the
-- provenance first, because it is the thing a report must not omit, and the
-- document second.
reportFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
reportFn =
  function
    "report.write"
    ( takes @"provenance" Text
        . takes @"findings" Text
        $ noParams
    )
    \provenance findings -> W.do
      act reporter [wf|
          {reportBrief}

          Provenance:

          {provenance}

          The document:

          {findings}

          Write the report, then reply DONE.|]
      done

-- | The suggestion document, as a tail a rung may call instead of or after
-- 'reportFn'.
suggestionsFn :: Fn '[ 'CodeText] 'CodeAck
suggestionsFn =
  function
    "report.suggestions"
    (takes @"findings" Text $ noParams)
    \findings -> W.do
      act reporter [wf|
          {suggestionsBrief}

          {findings}

          Write the document, then reply DONE.|]
      done

-- | The table a program passes to @'Agentic.Workflow.defining'@ when it calls
-- either of the above.
--
-- One table per family, so @defining@ is written once and a callee cannot be
-- half-registered: @defining@ checks that every @call@ names a function the list
-- declared, and declared it earlier.
reportTable :: [SomeFn]
reportTable = [SomeFn reportFn, SomeFn suggestionsFn]
