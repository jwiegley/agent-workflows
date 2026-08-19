-- |
-- Module      : Workflows.Registry
-- Description : The toolbox's index — one row per name the owner types.
--
-- @wf@ is @'Agentic.Cli.cliMain' registry@ and nothing else.
--
-- == Why this is a second registry and not seven more rows in the first
--
-- agent-cat's @haskell\/ci\/examples.sh@ pins @level@, @size@, @askNodes@, @costSummary@ and
-- both bills __by equality__ for every registered program, and its own header
-- says why: \"A new program cannot be registered without being priced.\" That is
-- exactly right for seven fixtures whose numbers are evidence about the
-- language, and exactly wrong for a toolbox: a lens added to a roster moves
-- @askNodes@, @costMax@ and every path count in every program that panels it,
-- and that is a Tuesday, not a regression. Fused into one registry, a red
-- @ci\/examples.sh@ would stop meaning \"the language regressed\" and start
-- meaning \"a prompt was reworded\" — and the moment that happens twice the pins
-- are loosened, which costs the /examples/ their gate and not just the
-- workflows.
--
-- So: two registries, two gates, two pin disciplines, and __one CLI__
-- ("Agentic.Cli"), because what would actually drift if duplicated is the
-- thousand lines of verb parsing, input flags, engine selection and exit codes
-- that know nothing about which programs are registered.
--
-- == The naming rule
--
-- A row's name is __the owner's own word__ where one exists — @review@,
-- @green@, @commit@, @fess@ — and one name per /shape/, never one per
-- /invocation/: where a program absorbs several of his commands, the command's
-- name survives as an input value and not as a second row.
--
-- == What this tree must never do
--
--   * Never import from @test\/corpus@ or @tier1@. The toolbox is not
--     conformance and must not be able to make a corpus gate red.
--   * Never write outside the directory the run was given. Every argv in the
--     tree is in "Workflows.Evidence", which is one module and reviewable as a
--     unit, and none of them points at @~\/src\/nix\/config\/ai@ — the corpus is
--     read-only, absolutely.
{-# LANGUAGE OverloadedStrings #-}

module Workflows.Registry (registry) where

import Agentic.Cli (Registry (..), Row (..))
import Agentic.Workflow (Example (Fixed, Needs))
import Workflows.Audit.Fess (fessAudit, fessDoc, fessScript)
import Workflows.Fix.Green
  ( Rung (Ci, Flaky, Tree),
    greenDoc,
    greenProgram,
    greenScript,
    rungName,
  )
import Workflows.Git.Commit
  ( CommitRung (Bankruptcy, Commit, Push, Recommit),
    commitDoc,
    commitProgram,
    commitRungName,
    commitScript,
  )
import Workflows.Git.Stack
  ( StackRung (Cleanup, Rebase, RebaseFix, Restack),
    stackDoc,
    stackProgram,
    stackRungName,
    stackScript,
  )
import Workflows.Hello (helloDoc, helloScript, helloWorkflow)
import Workflows.Review.Ladder
  ( Tier (Deep, Heavy, Quick, Sec),
    reviewDoc,
    reviewLadder,
    reviewScript,
    tierName,
  )

-- | The toolbox, in the order @wf list@ prints it.
--
-- The smoke row first, which exists to prove the wiring rather than to do the
-- owner's work; then the flagships, each landing as a family of rows against
-- this table, one family at a time, each row with its own numbers.
--
-- __A row is one /shape/, and a rung is a shape.__ The naming rule above says
-- one name per shape and never one per invocation, and the review family is
-- where that has to be argued rather than asserted: @review-quick@,
-- @review-deep@, @review-sec@ and @review-heavy@ differ in their roster, in
-- which receipts they collect and in their price, which is precisely what a
-- registry row should differ in — while @code-review@ and @review-github-pr@,
-- which differ from @review-deep@ only in what @--input-arg paths=@ and
-- @--input-arg scope=@ are given, are __not__ rows. Same test for the fix loop:
-- three rungs, three deciding commands, three bills.
--
-- __The reason a rung is a row and not an input.__ These four numbers are the
-- owner's pre-spend contract, and @ci\/workflows.sh@ reads them out of this
-- binary: a rung behind a flag is a rung whose level and path count no gate
-- pins, and the price of the heaviest review is exactly the number that must not
-- move quietly.
registry :: Registry
registry =
  Registry
    { regBinary = "wf",
      regNoun = "workflow",
      regBanner = "list, plan, price and run the workflows",
      regRows =
        [ ("hello", Row (Fixed helloWorkflow) helloDoc helloScript),
          reviewRow Quick,
          reviewRow Deep,
          reviewRow Sec,
          reviewRow Heavy,
          greenRow Ci,
          greenRow Tree,
          greenRow Flaky,
          commitRow Commit,
          commitRow Push,
          commitRow Recommit,
          commitRow Bankruptcy,
          ("fess", Row (Needs fessAudit) fessDoc fessScript),
          stackRow Restack,
          stackRow Rebase,
          stackRow RebaseFix,
          stackRow Cleanup
        ]
    }
  where
    -- The row's name is the rung's own, from the module that defines the rung:
    -- a registry that spelled it a second time would be the corpus's five
    -- hand-maintained copies of one paragraph, in Haskell.
    reviewRow t =
      ( tierName t,
        Row (Needs (reviewLadder t)) (reviewDoc t) (reviewScript t)
      )
    greenRow r =
      ( rungName r,
        Row (Needs (greenProgram r)) (greenDoc r) (greenScript r)
      )
    commitRow r =
      ( commitRungName r,
        Row (Needs (commitProgram r)) (commitDoc r) (commitScript r)
      )
    stackRow r =
      ( stackRungName r,
        Row (Needs (stackProgram r)) (stackDoc r) (stackScript r)
      )
