-- |
-- Module      : Workflows.Deciders
-- Description : The free tests — every classification the corpus pays a model for.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/commands\/deep-review.md@ Step 2 (the
-- extension table); @skills\/parallelize\/SKILL.md@ (@PARENT_HISTORY_ABSENT@);
-- @skills\/wiggum\/SKILL.md@ (the done sentinel); @commands\/fix-ci.md@ (the
-- check status); @commands\/process-checklist.md@ (the unchecked box);
-- @agents\/elisp-reviewer.md@ (@lexical-binding@ on the first line);
-- @agents\/coq-reviewer.md@ (@Admitted@); @agents\/rust-reviewer.md@
-- (@// SAFETY:@).
--
-- Each of those is a __pure test on text already in hand__, and in the corpus
-- each costs a model call — or worse, is a thing a model is asked to report
-- about itself. @'Agentic.Workflow.decide'@ asks nothing and costs nothing in
-- any fold, so writing one where an asked flag stood is __one fewer question on
-- every path, the same number of paths, and the same rung__.
--
-- The needles are literal program text and never words: a needle a model could
-- author is a test a model chooses, which is not a decider.
--
-- == The house rule: decide as early as possible
--
-- Three tiers, and a workflow should reach for the lowest one that can answer.
--
-- +------+---------------------------------+---------------------+-------------------------------------------+
-- | tier | mechanism                       | costs               | when                                      |
-- +======+=================================+=====================+===========================================+
-- | 1    | ordinary Haskell, over a        | zero questions,     | the fact is in the invocation: which      |
-- |      | @'Agentic.Workflow.taking'@     | __zero paths__      | languages the diff touches, which rung,   |
-- |      | input, before the @Program@     |                     | which roster                              |
-- |      | exists                          |                     |                                           |
-- +------+---------------------------------+---------------------+-------------------------------------------+
-- | 2    | 'Agentic.Workflow.decide', over | zero questions,     | the fact exists only after the world ran  |
-- |      | a receipt                       | one path            | something: a sentinel, a head oid, a gate |
-- +------+---------------------------------+---------------------+-------------------------------------------+
-- | 3    | an asked flag                   | one question        | the fact is a judgment                    |
-- +------+---------------------------------+---------------------+-------------------------------------------+
--
-- Tier 1 is the one nothing in the corpus can reach: @supply@ builds the
-- 'Agentic.Builder.Program' /after/ the inputs are known, so
-- @plan --input-arg paths=…@ prints the exact roster that will run, and the
-- operator sees it before spending. 'touches' is that tier; everything else
-- here is tier 2.
{-# LANGUAGE OverloadedStrings #-}

module Workflows.Deciders
  ( -- * Tier 1 — decided in Haskell, before the program exists
    pathsOf,
    touches,

    -- * Tier 2 — decided over a receipt, for zero questions
    saysDone,
    saysComplete,
    historyAbsent,
    isGreen,
    isRed,
    noConflictMarkers,
    hasUnchecked,
    hasAdmitted,
    everyUnsafeHasSafety,
    lexicalBindingFirstLine,
    headMatches,
    incompleteFanOut,
  )
where

import Agentic.Workflow (Decider (..))
import Data.Text (Text)
import qualified Data.Text as T

-- ---------------------------------------------------------------------------
-- Tier 1
-- ---------------------------------------------------------------------------

-- | The paths in a @--input-arg paths=…@ value: one per line, blanks dropped.
--
-- Ordinary Haskell over ordinary 'Text'. What comes out of it selects a roster
-- (@'Workflows.Rubrics.Reviewers.languageRoster'@) __before__ the program is
-- built, which is why the dispatch adds no node, no question and no path.
pathsOf :: Text -> [Text]
pathsOf = filter (not . T.null) . map T.strip . T.lines

-- | Does any of these paths end in this suffix?
--
-- /Source:/ @commands\/deep-review.md@ Step 2's extension table, which in the
-- corpus is a thing a coordinator model is told to compute and here is a
-- three-line function. @'Workflows.Rubrics.Reviewers.languageRoster'@ is its
-- only caller and the glob column is its only argument.
touches :: [Text] -> Text -> Bool
touches ps suffix = any (suffix `T.isSuffixOf`) ps

-- ---------------------------------------------------------------------------
-- Tier 2
-- ---------------------------------------------------------------------------

-- $tier2
--
-- Each is a @(Decider, [needle])@ pair, spelled once. A workflow writes
--
-- > ok <- uncurry decide saysDone status
--
-- and nothing spells a needle twice. The pair is the unit because a decider
-- without its needles is half a test, and the corpus's own drift is exactly
-- there: three files carry the history sentinel and two of them spell it
-- differently.

-- | @DONE@ as the last non-empty line — the receipt shape every act in this
-- tree asks for.
saysDone :: (Decider, [Text])
saysDone = (LastNonEmptyLineIs, ["DONE"])

-- | @WORK COMPLETE@ against @WORK REMAINS@.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s continuation loop, and @incite@'s
-- @tripEnding@, which is the same sentinel one repository over. The @BLOCKED@
-- ending is not tested here: it is a __third__ answer and belongs to
-- 'Workflows.Escalation', not to a two-way flag.
saysComplete :: (Decider, [Text])
saysComplete = (LastNonEmptyLineIs, ["WORK COMPLETE"])

-- | @PARENT_HISTORY_ABSENT@, in the one spelling the corpus's three copies
-- should have had.
--
-- /Source:/ @skills\/parallelize\/SKILL.md@ step 2. In the corpus this is
-- checked by a Python script the runner is told to invoke; here it is a test on
-- the probe's own answer, and the script has nothing left to do.
historyAbsent :: (Decider, [Text])
historyAbsent = (LastNonEmptyLineIs, ["PARENT_HISTORY_ABSENT"])

-- | A check run that finished clean.
--
-- /Source:/ @commands\/fix-ci.md@, which watches @gh pr checks@ and reasons
-- about what it saw. Note that a real gate does not need this at all: an exit
-- code is a @flag@ or a @verdict@ directly (see 'Workflows.Gates'). It is here
-- for the case where the status arrived as /text/ inside something larger.
isGreen :: (Decider, [Text])
isGreen = (AnyLineStartsWith, ["All checks were successful", "✓ "])

-- | A check run with something red in it.
--
-- /Source:/ @incite@'s @isRed@, whose needle keeps its trailing space
-- deliberately: a needle is not trimmed, so @anyLineStartsWith [\"✗ \"]@ pins
-- @isRed \"✗\" == False@ exactly as the original does.
isRed :: (Decider, [Text])
isRed = (AnyLineStartsWith, ["✗ ", "fail", "FAIL"])

-- | No conflict marker survived a resolution.
--
-- /Source:/ @commands\/resolve.md@ and @commands\/rebase-and-fix.md@, whose
-- postcondition is exactly this and is checked by reading. Used __negated__:
-- the resolution is done when this is false.
noConflictMarkers :: (Decider, [Text])
noConflictMarkers = (AnyLineStartsWith, ["<<<<<<<", "=======", ">>>>>>>"])

-- | An unchecked Markdown box remains.
--
-- /Source:/ @commands\/process-checklist.md@, whose whole loop is \"until there
-- are none\". The loop's exit condition is free.
hasUnchecked :: (Decider, [Text])
hasUnchecked = (AnyLineStartsWith, ["- [ ]", "* [ ]"])

-- | An @Admitted@ survived.
--
-- /Source:/ @agents\/coq-reviewer.md@ priority 1: \"an @Admitted@ in non-draft
-- code is a critical finding.\" A critical finding that a grep decides is a
-- critical finding nobody has to be trusted about.
hasAdmitted :: (Decider, [Text])
hasAdmitted = (AnyLineStartsWith, ["Admitted."])

-- | Every @unsafe@ block carries its @// SAFETY:@ comment.
--
-- /Source:/ @agents\/rust-reviewer.md@ priority 1. This one is a __partial__
-- test and the haddock says so: it detects the presence of the comment
-- convention, not its correctness, and the file's own demand is that the
-- invariant actually holds — which is a judgment and therefore tier 3. The
-- decider is worth having anyway, because the cheap half of the question should
-- not cost a model call before the expensive half is asked.
everyUnsafeHasSafety :: (Decider, [Text])
everyUnsafeHasSafety = (AnyLineStartsWith, ["// SAFETY:"])

-- | The Emacs Lisp cookie.
--
-- /Source:/ @agents\/elisp-reviewer.md@ priority 1, which is stated as a test on
-- the __first line__ of the file. 'ContainsLine' is exact line equality, so a
-- file whose cookie is on line three fails it — which is the rule as written.
lexicalBindingFirstLine :: (Decider, [Text])
lexicalBindingFirstLine = (ContainsLine, [";;; -*- lexical-binding: t; -*-"])

-- | The head is still where the review started.
--
-- /Source:/ @commands\/bugbot.md@ and @commands\/review-github-pr.md@, both of
-- which pin @headRefOid@ and then hope. The needle is the oid the caller bound
-- earlier in the run, so this is the one decider whose needles are computed —
-- from a __receipt__, never from an answer.
headMatches :: Text -> (Decider, [Text])
headMatches oid = (LastNonEmptyLineIs, [oid])

-- | A synthesis that refused because a block was missing.
--
-- /Source:/ 'Workflows.Panels.refusingSynthesis', whose contract this is the
-- other half of: the brief tells the model to answer @INCOMPLETE: …@ and this
-- is what reads it, for free, so the refusal is a branch the program takes and
-- not a string a reader notices.
incompleteFanOut :: (Decider, [Text])
incompleteFanOut = (AnyLineStartsWith, ["INCOMPLETE:"])
