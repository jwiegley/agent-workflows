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
import Workflows.Account
  ( AccountKind (Halt, Narrative, Report, Sitrep),
    accountDoc,
    accountName,
    accountProgram,
    accountScript,
  )
import Workflows.Audit.Fess (fessAudit, fessDoc, fessScript)
import Workflows.Bundles (bundlesDoc, bundlesProgram, bundlesScript)
import Workflows.Checklist (checklistDoc, checklistProgram, checklistScript)
import Workflows.ClaudeMd
  ( ClaudeMdRung (Advise, Initialize),
    claudeMdDoc,
    claudeMdName,
    claudeMdProgram,
    claudeMdScript,
  )
import Workflows.Comments (commentsDoc, commentsProgram, commentsScript)
import Workflows.Confer
  ( ConferRung (Bare, Confer, Debate, Second),
    conferDoc,
    conferProgram,
    conferRungName,
    conferScript,
  )
import Workflows.DeadCode (deadCodeDoc, deadCodeProgram, deadCodeScript)
import Workflows.Denote (denoteDoc, denoteProgram, denoteScript)
import Workflows.Duet (duetDoc, duetProgram, duetScript)
-- Qualified, alone in this block, and for a reason worth one line: both
-- "Workflows.Effort" and "Workflows.Review.Ladder" call their rung type @Tier@
-- and both have a @Heavy@ rung, which is not a collision to rename away —
-- @review-heavy@ and @effort-heavy@ are two of the owner's own words and each is
-- right in its own module. The qualifier is where the two meet.
import qualified Workflows.Effort as Effort
import Workflows.Expense (expenseDoc, expenseProgram, expenseScript)
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
import Workflows.Issue
  ( IssueRung (Fix, Worktree),
    issueDoc,
    issueProgram,
    issueRungName,
    issueScript,
  )
import Workflows.Nix
  ( NixRung (Alert, Integration, Rebuild),
    nixDoc,
    nixName,
    nixProgram,
    nixScript,
  )
import Workflows.NodeRed (noderedDoc, noderedProgram, noderedScript)
import Workflows.Notes (notesDoc, notesProgram, notesScript)
import Workflows.OrgTasks
  ( OrgRung (Breakdown, Infer),
    orgDoc,
    orgProgram,
    orgRungName,
    orgScript,
  )
-- Qualified, and for the same reason "Workflows.Effort" is: both
-- "Workflows.Git.Stack" and "Workflows.Partner" have a @Cleanup@ rung, and
-- neither is the one to rename — @stack-cleanup@ and @partner-cleanup@ are two
-- of the owner's own words and each is right in its own module.
import qualified Workflows.Partner as Partner
import Workflows.Prd
  ( Mode (Critique, Draft),
    prdDoc,
    prdName,
    prdProgram,
    prdScript,
  )
import Workflows.Productize
  ( ProductizeRung (Full, Lefthook),
    productizeDoc,
    productizeName,
    productizeProgram,
    productizeScript,
  )
import Workflows.Prose.Polish
  ( Strength (Compress, Proofread, Smooth, Transcript),
    proseDoc,
    proseName,
    proseProgram,
    proseScript,
  )
import Workflows.QandA (qandaDoc, qandaProgram, qandaScript)
import Workflows.Query (queryDoc, queryProgram, queryScript)
-- Qualified, for the reason "Workflows.Effort" is: this module's rung type is
-- also called @Tier@, and neither name is the one to rename — @review-deep@ and
-- @retest@ are two of the owner's own words and each is right in its own module.
-- The qualifier is where the two meet.
import qualified Workflows.Retest as Retest
import Workflows.Review.Ladder
  ( Tier (Deep, Heavy, Quick, Sec),
    reviewDoc,
    reviewLadder,
    reviewScript,
    tierName,
  )
import Workflows.Service
  ( ServiceOp (Install, Remove),
    serviceDoc,
    serviceName,
    serviceProgram,
    serviceScript,
  )
import Workflows.Teams (teamsDoc, teamsProgram, teamsScript)
import Workflows.Threads
  ( ThreadRung (Assess, Respond),
    threadRungName,
    threadsDoc,
    threadsProgram,
    threadsScript,
  )
import Workflows.Transcribe (transcribeDoc, transcribeProgram, transcribeScript)
import Workflows.Translate
  ( Direction (En, Es, Fa),
    translateDoc,
    translateName,
    translateProgram,
    translateScript,
  )
import Workflows.Tron (tronDoc, tronProgram, tronScript)
import Workflows.Wiggum (wiggumDoc, wiggumProgram, wiggumScript)

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
          stackRow Cleanup,
          conferRow Confer,
          conferRow Bare,
          conferRow Debate,
          conferRow Second,
          ("checklist", Row (Needs checklistProgram) checklistDoc checklistScript),
          ("teams", Row (Needs teamsProgram) teamsDoc teamsScript),
          ("notes", Row (Needs notesProgram) notesDoc notesScript),
          effortRow Effort.Medium,
          effortRow Effort.Heavy,
          effortRow Effort.Forge,
          threadsRow Respond,
          threadsRow Assess,
          issueRow Fix,
          issueRow Worktree,
          accountRow Halt,
          accountRow Sitrep,
          accountRow Report,
          accountRow Narrative,
          partnerRow Partner.Reviewer,
          partnerRow Partner.Collaborator,
          partnerRow Partner.Cleanup,
          orgRow Breakdown,
          orgRow Infer,
          claudeMdRow Initialize,
          claudeMdRow Advise,
          proseRow Proofread,
          proseRow Smooth,
          proseRow Transcript,
          proseRow Compress,
          ("dead-code", Row (Needs deadCodeProgram) deadCodeDoc deadCodeScript),
          ("comments", Row (Needs commentsProgram) commentsDoc commentsScript),
          ("bundles", Row (Needs bundlesProgram) bundlesDoc bundlesScript),
          productizeRow Full,
          productizeRow Lefthook,
          nixRow Rebuild,
          nixRow Alert,
          nixRow Integration,
          serviceRow Install,
          serviceRow Remove,
          -- Wave 4's second half (`doc/design.md` §8). Five rows, five programs,
          -- and no rungs: each of these is one shape and the owner has one name
          -- for it, so the naming rule above gives each the bare family name.
          --
          -- What they have in common is worth one line, because it is why they
          -- are the last of the specialists: each is a program whose read-only
          -- or human-gated character is a TYPE rather than an instruction.
          -- `query` contains no `act` at all; `transcribe` and `tron` contain
          -- exactly one, and it writes the artefact; `expense` and `qanda` put
          -- the owner in binding position, so their expensive arms are
          -- unreachable without his answer.
          ("query", Row (Needs queryProgram) queryDoc queryScript),
          ("expense", Row (Needs expenseProgram) expenseDoc expenseScript),
          ("qanda", Row (Needs qandaProgram) qandaDoc qandaScript),
          ("transcribe", Row (Needs transcribeProgram) transcribeDoc transcribeScript),
          ("tron", Row (Needs tronProgram) tronDoc tronScript),
          -- Wave 5, the long ones (`doc/design.md` §8). What these have in
          -- common is that each carries a whole *procedure* rather than a
          -- rubric: a phase battery, a ten-phase design method, a five-phase
          -- translation team, a two-mode requirements agent, and a
          -- host-specific automation surface. Every one of them is a file whose
          -- own text says "follow it exactly", and the level-up in all five is
          -- the same: a procedure that is a program can be priced, and its
          -- steps cannot be reordered by a tired reader.
          retestRow Retest.Hf,
          retestRow Retest.Categorical,
          ("denote", Row (Needs denoteProgram) denoteDoc denoteScript),
          translateRow Fa,
          translateRow En,
          translateRow Es,
          prdRow Draft,
          prdRow Critique,
          -- Last of the wave's specialists, and last on purpose: `doc/design.md`
          -- §7.4 row 22 says "deeply host-specific -- port last", and this is
          -- the one row in the table whose paths, database, config-node ids and
          -- entity families are one machine's.
          ("nodered", Row (Needs noderedProgram) noderedDoc noderedScript),
          -- The top of the loop, and the last row in the table (`doc/design.md`
          -- §7.4 row 1: "`wiggum`, BUILT LAST: it calls almost everything").
          -- Five of its seven declared callees belong to other rows -- `commitFn`
          -- from the commit family, `resolveFn` from the git family,
          -- `cleanupRoundFn` from the partnership, `fessReportFn` from the audit,
          -- and the eleven fess stances by way of `Rubrics.Fess` -- so this row
          -- is very largely a composition of the rows above it, which is the
          -- claim wave 5 makes about it.
          --
          -- It is also the row that carries the wave's gate: `wf cost wiggum`
          -- reports a finite worst case over finitely many paths, which is the
          -- one number an autonomous loop must have before it starts.
          ("wiggum", Row (Needs wiggumProgram) wiggumDoc wiggumScript),
          -- The same loop across two live panes ("Workflows.Duet"), and a row
          -- rather than a flag on the one above it for the naming rule's own
          -- reason: a row is one SHAPE, and this shape has a bind `wiggum` does
          -- not have — the partner's observations feed round two inside the
          -- term. It is priced accordingly, and the two prices side by side in
          -- `wf list` are what an operator reads before choosing.
          --
          -- Last in the table because it is last to land and because it sits on
          -- top of `wiggum`, which sits on top of everything else: five of its
          -- eight declared callees belong to other rows, and the three that are
          -- its own are `wiggum`'s three bodies with one pin moved plus the
          -- four-seat review between the rounds.
          ("wiggum-duet", Row (Needs duetProgram) duetDoc duetScript)
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
    -- The confer family. Four rows and not five: the confer-shaped gate
    -- @confer-design.md@ §5.4 sketches is unbuilt, and when it is built it
    -- wants a verdict rather than a document, so it belongs with the gates —
    -- @doc/design.md@ §8.1. The rows sit last because they are the newest wave
    -- and `wf list` is read top to bottom in landing order.
    conferRow r =
      ( conferRungName r,
        Row (Needs (conferProgram r)) (conferDoc r) (conferScript r)
      )
    -- The rest of wave 2, in the order `doc/design.md` §8 lists them:
    -- `checklist` (the wave-1 warm-up, which landed with this batch), then
    -- `teams` and `notes` — the corpus's two most literal panels — then the
    -- effort ladder, whose three rows are the owner's own unpriced cost model
    -- (`medium ⊂ heavy ⊂ forge`) with the three prices finally beside it.
    effortRow r =
      ( Effort.effortName r,
        Row (Needs (Effort.effortProgram r)) (Effort.effortDoc r) (Effort.effortScript r)
      )
    -- Wave 3, the daily drivers (`doc/design.md` §8). They are thin over the
    -- library and over waves 1-2's functions, which is what that wave says they
    -- should be: `issue` and `account-halt` call `commitFn`, `issue` calls
    -- `botSweepFn`, `partner-cleanup` calls `commitFn`, and every one of them
    -- ends in a report function of its own family.
    threadsRow r =
      ( threadRungName r,
        Row (Needs (threadsProgram r)) (threadsDoc r) (threadsScript r)
      )
    issueRow r =
      ( issueRungName r,
        Row (Needs (issueProgram r)) (issueDoc r) (issueScript r)
      )
    accountRow k =
      ( accountName k,
        Row (Needs (accountProgram k)) (accountDoc k) (accountScript k)
      )
    proseRow r =
      ( proseName r,
        Row (Needs (proseProgram r)) (proseDoc r) (proseScript r)
      )
    claudeMdRow r =
      ( claudeMdName r,
        Row (Needs (claudeMdProgram r)) (claudeMdDoc r) (claudeMdScript r)
      )
    orgRow r =
      ( orgRungName r,
        Row (Needs (orgProgram r)) (orgDoc r) (orgScript r)
      )
    serviceRow o =
      ( serviceName o,
        Row (Needs (serviceProgram o)) (serviceDoc o) (serviceScript o)
      )
    nixRow r =
      ( nixName r,
        Row (Needs (nixProgram r)) (nixDoc r) (nixScript r)
      )
    productizeRow r =
      ( productizeName r,
        Row (Needs (productizeProgram r)) (productizeDoc r) (productizeScript r)
      )
    partnerRow r =
      ( Partner.partnerRoleName r,
        Row (Needs (Partner.partnerProgram r)) (Partner.partnerDoc r) (Partner.partnerScript r)
      )
    -- Wave 5. The battery's two rungs are one body and one override table, which
    -- is why they are two rows rather than two programs: `retest` and
    -- `retest-categorical` differ in their oracle, their build target, their
    -- roster and their success word, and a reader compares the two prices in
    -- `wf list` without spending either.
    retestRow t =
      ( Retest.retestName t,
        Row (Needs (Retest.retestProgram t)) (Retest.retestDoc t) (Retest.retestScript t)
      )
    -- Three rows and two shapes, which is the naming rule doing its job: the two
    -- directions that carry a review team are one body with the languages
    -- swapped, and the one that does not is a single call of the same drafting
    -- function. The three prices say which is which without a word of prose.
    translateRow r =
      ( translateName r,
        Row (Needs (translateProgram r)) (translateDoc r) (translateScript r)
      )
    -- Two rows because one agent file was two agents. `doc/design.md` §7.3 marks
    -- `prd-architect` R -> 2xT and says to split at the mode boundary BEFORE
    -- writing either; these are the two, and their two prices are the first
    -- thing the split bought.
    prdRow m =
      ( prdName m,
        Row (Needs (prdProgram m)) (prdDoc m) (prdScript m)
      )
