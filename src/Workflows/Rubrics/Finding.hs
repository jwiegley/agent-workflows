-- |
-- Module      : Workflows.Rubrics.Finding
-- Description : The finding schema, once. Eleven copies end here.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/agents\/*-reviewer.md@, the
-- @## Output format@ section. Eleven agent files carry this block; nine are
-- byte-identical, and the differences in the rest are recorded below as
-- /variants of one value/ rather than as eleven independent texts.
--
-- The corpus has already drifted once here, and that is the whole argument for
-- this module: @commands\/deep-review.md@ consumes these findings and prints a
-- category vocabulary of its own with __two entries no agent file carries__ —
-- @Simplification@ and @Dead Code@ — so a reviewer emitting the agent
-- vocabulary and a coordinator collating the deep-review one disagree about
-- what a category /is/, and nothing in Markdown can notice. Here the vocabulary
-- is a Haskell list, the schema is derived from it, and adding a category
-- reaches every brief by being added.
--
-- The drift is __resolved in favour of the consumer__, and this is the one place
-- that decision is made: the two extra categories are real (a @ponytail@ pass
-- and an @eliminate-dead-code@ pass produce nothing else), and a producer that
-- cannot name what it found is a producer whose findings get filed under
-- @Style@.
--
-- Nothing in @~\/src\/nix\/config\/ai@ is modified by this module or by
-- anything in this tree. The corpus was read as data.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Workflows.Rubrics.Finding
  ( -- * The vocabulary
    severities,
    categories,

    -- * The schema
    findingSchema,
    findingSchemaWith,

    -- * The three documented variants
    soundnessLine,
    confidenceFloor,
    verdictSpec,
    flagSpec,
  )
where

import Agentic.Workflow (wft)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prose (tshow)

-- | @Severity levels: CRITICAL, HIGH, MEDIUM, LOW.@
--
-- /Source:/ every @agents\/*-reviewer.md@, the closing line of @## Output
-- format@. Ordered worst-first, which is the order a report is sorted in.
severities :: [Text]
severities = ["CRITICAL", "HIGH", "MEDIUM", "LOW"]

-- | The @**Category**@ vocabulary, reconciled.
--
-- /Source:/ the eight that the eleven @agents\/*-reviewer.md@ files agree on,
-- plus the two @commands\/deep-review.md@'s collator prints and no producer
-- emits. Ten rows, in one list, rather than eight in eleven briefs and ten in
-- one collator.
categories :: [Text]
categories =
  [ "Bug",
    "Security",
    "Performance",
    "Simplification",
    "Dead Code",
    "Style",
    "Convention",
    "Edge Case",
    "Documentation",
    "Test Coverage"
  ]

-- | The schema every reviewing question ends with.
--
-- /Source:/ @agents\/haskell-reviewer.md@ and ten siblings, verbatim but for
-- the category line, which is derived from 'categories' so that the eleven
-- cannot drift.
findingSchema :: Text
findingSchema = findingSchemaWith []

-- | 'findingSchema' with extra lines appended to the block — the three
-- variants the corpus actually carries, supplied by the caller rather than
-- forked into a second copy of the schema.
--
-- /Sources of the variants:/ @agents\/cpp-reviewer.md@ and
-- @agents\/typescript-reviewer.md@ add a soundness line;
-- @agents\/security-reviewer.md@ and @agents\/perf-reviewer.md@ are quoted in
-- the review commands with a confidence floor. Each is one argument here, not
-- one file there.
findingSchemaWith :: [Text] -> Text
findingSchemaWith extras =
  [wft|
  If the invoking prompt specifies a findings format, use that. Otherwise,
  produce each finding in this default structure:

  ### [SEVERITY] Short title
  - **File**: path/to/file.ext#L<start>-L<end>
  - **Category**: {categoryLine}
  - **Confidence**: <0-100>
  - **Problem**: <1-2 sentence description>
  - **Impact**: <why this matters>
  - **Fix**: <concrete suggestion, ideally with code>
  {extraLines}
  Severity levels: {severityLine}. Every finding must include a file path,
  line range, severity, confidence score, and a concrete fix suggestion.|]
  where
    categoryLine = T.intercalate " | " categories
    severityLine = T.intercalate ", " severities
    extraLines
      | null extras = ""
      | otherwise = T.intercalate "\n" extras <> "\n"

-- | The extra line @cpp-reviewer@ and @typescript-reviewer@ carry.
--
-- /Source:/ the two files' @## Output format@ sections, which are the eleven's
-- only textual divergence that says something.
soundnessLine :: Text
soundnessLine =
  "- **Soundness**: <what makes this certain, or what would settle it>"

-- | The confidence floor a cross-cutting pass is held to.
--
-- /Source:/ the review commands quote a floor for the security and performance
-- passes; the number is the caller's and the sentence is one.
confidenceFloor :: Int -> Text
confidenceFloor n =
  [wft|
  Report only findings whose Confidence is {floorText} or higher. A finding
  you cannot reach that number on is a verification action, not a finding:
  say what you would have to check.|]
  where
    floorText = tshow n :: Text

-- | The line a question whose answer is a __verdict__ ends with.
--
-- /Source:/ @example-000@'s own @verdictSpec@, which is the shape
-- 'Agentic.Workflow.panel' folds. It is here rather than beside a program
-- because every panel in this tree ends with it and a panel whose members
-- disagree about how to say no is a panel that settles by accident.
verdictSpec :: Text
verdictSpec =
  "Reply with exactly APPROVE if acceptable, or OBJECTION: <one line> if not."

-- | The line a question whose answer is a __flag__ ends with.
flagSpec :: Text
flagSpec = "Reply with exactly yes or no."
