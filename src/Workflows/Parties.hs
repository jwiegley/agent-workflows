-- |
-- Module      : Workflows.Parties
-- Description : Who answers — the pins, and the fail-over ladder.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/agents\/*.md@ (the nine @-pro@
-- specialists and the eleven reviewers), @skills\/forge\/SKILL.md@'s partner
-- table, and @commands\/heavy.md@'s confer clause, which are where the owner's
-- model names are written down.
--
-- The @-pro@ agents and the reviewers are __addressees__, not programs: a
-- Markdown file describing how a Haskell reviewer thinks is a /rubric/ plus a
-- /party/, and only the second belongs here. The rubric is
-- "Workflows.Rubrics.Reviewers".
--
-- == Three things this module makes structural
--
-- __A pin is on the question.__ @'Agentic.Workflow.servedBy'@ says which model
-- serves a named addressee, and @--require-pinned@ refuses a program that left
-- one out — before a plan is printed or an adapter started. The corpus has
-- three hand-rolled versions of that check (a Python model-dispatch verifier, a
-- @listmodels@ preflight, and an \"opus at max effort\" instruction); all three
-- are this module plus one flag.
--
-- __The deliberate /absence/ of a pin is the absence of the words.__ Isaac's I5,
-- and the corpus asks for it by name where several lenses must stay comparable:
-- an unpinned member inherits whatever the run is pointed at, and that is a
-- decision the source shows by saying nothing.
--
-- __A fail-over is not part of the question.__
-- @'Agentic.Workflow.fallingBackTo'@ appends alternates that the runner tries in
-- order; two asks differing only in their alternates elaborate to the same plan,
-- put the same question and bill the same, because the chain is a property of
-- the /model/ that @Agentic.Chains@ collects before the run. So the ladder below
-- costs nothing to write and nothing to price.
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Workflows.Parties
  ( -- * The serving models, by their names in the owner's config
    fable,
    opus,
    gpt5Pro,
    gemini,

    -- * The fail-over ladder
    reasoning,
    broad,
    lateral,

    -- * The specialists
    haskellPro,
    cppPro,
    rustPro,
    pythonPro,
    elispPro,
    nixPro,
    sqlPro,
    typescriptPro,
    rocqPro,

    -- * The standing parties
    owner,
    reporter,
  )
where

import Agentic.Workflow
  ( Party,
    PartyK (IsModel, IsPerson, IsTool),
    fallingBackTo,
    model,
    person,
    servedBy,
    tool,
  )
import Data.Text (Text)

-- ---------------------------------------------------------------------------
-- The serving models
-- ---------------------------------------------------------------------------

-- $models
--
-- These are 'Text', not parties: a serving model is what answers /for/ an
-- addressee, and the addressee is the role. Naming them once is what keeps a
-- model rename from being a sweep through every brief in the tree.

-- | /Source:/ @skills\/forge\/SKILL.md@'s executor row.
fable :: Text
fable = "fable"

-- | /Source:/ @skills\/forge\/SKILL.md@'s executor row.
opus :: Text
opus = "opus"

-- | /Source:/ @skills\/forge\/SKILL.md@'s Partner 1, and @commands\/heavy.md@.
gpt5Pro :: Text
gpt5Pro = "gpt-5.5-pro"

-- | /Source:/ @skills\/forge\/SKILL.md@'s Partner 2, and @commands\/heavy.md@.
gemini :: Text
gemini = "gemini-3.1-pro-preview"

-- ---------------------------------------------------------------------------
-- The fail-over ladder
-- ---------------------------------------------------------------------------

-- $ladder
--
-- Three rungs, each a pin plus the alternates the runner tries in order when
-- the pinned model will not answer. A workflow says which /kind/ of answering
-- it wants and does not repeat the ladder; when a model is retired, one rung
-- moves.
--
-- __The ladder is free.__ An alternate is not part of the question
-- (@Agentic.Chains@ collects it before the run), so @askNodes@, @costSummary@
-- and both bills are the same as they would be with a bare
-- @'Agentic.Workflow.servedBy'@. A run narrates a fail-over on stderr and the
-- trace records who actually answered.

-- | Deep, careful reasoning: the rung a synthesis, a plan or a verdict wants.
reasoning :: Party 'IsModel -> Party 'IsModel
reasoning p = p `servedBy` opus `fallingBackTo` gpt5Pro `fallingBackTo` fable

-- | Wide reading over a lot of context: the rung a survey or a language pass
-- wants.
broad :: Party 'IsModel -> Party 'IsModel
broad p = p `servedBy` fable `fallingBackTo` gemini `fallingBackTo` opus

-- | A second opinion from somewhere else: the rung a contrarian, a skeptic or a
-- confer member wants, and the reason its primary is not the house model.
lateral :: Party 'IsModel -> Party 'IsModel
lateral p = p `servedBy` gemini `fallingBackTo` gpt5Pro `fallingBackTo` opus

-- ---------------------------------------------------------------------------
-- The specialists
-- ---------------------------------------------------------------------------

-- $specialists
--
-- /Source:/ @agents\/haskell-pro.md@, @cpp-pro.md@, @rust-pro.md@,
-- @python-pro.md@, @emacs-lisp-pro.md@, @nix-pro.md@, @sql-pro.md@,
-- @typescript-pro.md@, @rocq-pro.md@ — nine files whose /identity/ is a name
-- and a serving model. What each of them /knows/ is reference material, and
-- reference material of that size is a program input and not a define; see
-- 'Workflows.Rubrics.Reviewers' for where the review-sized slice of it lives.

haskellPro, cppPro, rustPro, pythonPro, elispPro :: Party 'IsModel
nixPro, sqlPro, typescriptPro, rocqPro :: Party 'IsModel
haskellPro = broad (model "haskell-pro")
cppPro = broad (model "cpp-pro")
rustPro = broad (model "rust-pro")
pythonPro = broad (model "python-pro")
elispPro = broad (model "elisp-pro")
nixPro = broad (model "nix-pro")
sqlPro = broad (model "sql-pro")
typescriptPro = broad (model "typescript-pro")
rocqPro = broad (model "rocq-pro")

-- ---------------------------------------------------------------------------
-- The standing parties
-- ---------------------------------------------------------------------------

-- | The one person any workflow in this tree may ask.
--
-- A person's question is a real gate: under a live engine it reaches whoever is
-- watching, and @--scripted@ answers it @yes@ — which is exactly why a gate
-- that must not be auto-answered is a /file the run may not create/ and not a
-- person's question. See 'Workflows.Gates'.
owner :: Party 'IsPerson
owner = person "owner"

-- | The tool a program's closing act writes its report through.
--
-- A tool and not a model: the report is an artefact, and an act at
-- @'Agentic.Raw.CodeAck'@ is the only kind of answer the ACP transport grants
-- write authority to.
reporter :: Party 'IsTool
reporter = tool "write-report"
