-- |
-- Module      : Workflows.Rubrics.Ladder
-- Description : The review ladder, as one value the "see also" text derives from.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/commands\/quick-review.md@,
-- @code-review.md@, @deep-review.md@, @sec-audit.md@ and
-- @review-github-pr.md@ each open with a \"See also -- review ladder:\"
-- paragraph naming all five rungs. Five copies, maintained by hand.
--
-- The paragraph is a table read aloud. Here it is the table, and every rung's
-- \"see also\" text is 'seeAlso' applied to it — so a rung added arrives in all
-- five briefs __by being added__, and a rung renamed cannot be renamed in four
-- places out of five.
--
-- This is @incite@'s derived-roster discipline pointed at the corpus's own
-- navigation.
--
-- Nothing in @~\/src\/nix\/config\/ai@ is modified by this module.
{-# LANGUAGE OverloadedStrings #-}

module Workflows.Rubrics.Ladder
  ( -- * The ladder
    Rung (..),
    rungs,
    rungNamed,

    -- * What every rung's brief opens with
    seeAlso,
  )
where

import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T

-- | One rung: the owner's own name for it, what it is, and the bound a bounded
-- revision at that rung gets.
--
-- __The bound is the level-up.__ The Markdown ladder orders five commands by a
-- feeling about weight. Ordering them by a number an operator can read before
-- spending — and that @'Agentic.Plan.costSummary'@ prices — is what the
-- paragraph was reaching for and could not say.
data Rung = Rung
  { rungName :: !Text,
    rungBlurb :: !Text,
    -- | the amendment bound a gate at this rung is given
    rungBound :: !Integer
  }

-- | The five rungs, lightest first, in the order the corpus's own paragraph
-- names them.
--
-- /Source:/ the \"See also -- review ladder\" paragraph, whose five clauses are
-- the five 'rungBlurb's below, verbatim.
rungs :: [Rung]
rungs =
  [ Rung
      { rungName = "quick-review",
        rungBlurb = "the fastest single-pass rung",
        rungBound = 0
      },
    Rung
      { rungName = "code-review",
        rungBlurb = "a comprehensive named-agent health checkup",
        rungBound = 1
      },
    Rung
      { rungName = "deep-review",
        rungBlurb = "the heavy multi-agent, multi-language pass",
        rungBound = 2
      },
    Rung
      { rungName = "sec-audit",
        rungBlurb = "narrows the focus to security",
        rungBound = 1
      },
    Rung
      { rungName = "review-github-pr",
        rungBlurb = "reviews a GitHub PR in a worktree and never posts back",
        rungBound = 1
      }
  ]

-- | A rung by the name the owner types.
rungNamed :: Text -> Maybe Rung
rungNamed n = find ((== n) . rungName) rungs

-- | The paragraph a rung's brief opens with, derived from 'rungs'.
--
-- /Source:/ the five copies named above, whose shape this reproduces exactly —
-- including the closing sentence, which is the only advice in the whole
-- paragraph and the reason it is worth carrying at all.
seeAlso :: Rung -> Text
seeAlso this =
  "Review ladder: "
    <> T.intercalate "; " [phrase r | r <- rungs]
    <> ". Pick the lightest rung that fits."
  where
    phrase r
      | rungName r == rungName this = "`" <> rungName r <> "` (this one) is " <> rungBlurb r
      | otherwise = "`" <> rungName r <> "` is " <> rungBlurb r
