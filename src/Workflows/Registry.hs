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
    accountHelp,
    accountName,
    accountProgram,
    accountScript,
  )
import Workflows.Fess (fessAudit, fessDoc, fessHelp, fessScript)
import Workflows.DiscoverBundles (bundlesDoc, bundlesHelp, bundlesProgram, bundlesScript)
import Workflows.ProcessChecklist (checklistDoc, checklistHelp, checklistProgram, checklistScript)
import Workflows.ClaudeMd
  ( ClaudeMdRung (Advise, Initialize),
    claudeMdDoc,
    claudeMdHelp,
    claudeMdName,
    claudeMdProgram,
    claudeMdScript,
  )
import Workflows.CommentAudit (commentsDoc, commentsHelp, commentsProgram, commentsScript)
import Workflows.Confer
  ( ConferRung (Bare, Confer, Debate, Second),
    conferDoc,
    conferHelp,
    conferProgram,
    conferRungName,
    conferScript,
  )
import Workflows.EliminateDeadCode (deadCodeDoc, deadCodeHelp, deadCodeProgram, deadCodeScript)
import Workflows.DenotationalDesign (denoteDoc, denoteHelp, denoteProgram, denoteScript)
import Workflows.WiggumDuet (duetDoc, duetHelp, duetProgram, duetScript)
-- Qualified, alone in this block, and for a reason worth one line: both
-- "Workflows.Effort" and "Workflows.Review.Ladder" call their rung type @Tier@
-- and both have a @Heavy@ rung, which is not a collision to rename away —
-- @review-heavy@ and @effort-heavy@ are two of the owner's own words and each is
-- right in its own module. The qualifier is where the two meet.
import qualified Workflows.Effort as Effort
import Workflows.ExpenseReport (expenseDoc, expenseHelp, expenseProgram, expenseScript)
import Workflows.Fix.Green
  ( Rung (Ci, Flaky, Tree),
    greenDoc,
    greenHelp,
    greenProgram,
    greenScript,
    rungName,
  )
import Workflows.Git.Commit
  ( CommitRung (Bankruptcy, Commit, Push, Recommit),
    commitDoc,
    commitHelp,
    commitProgram,
    commitRungName,
    commitScript,
  )
import Workflows.Git.Stack
  ( StackRung (Cleanup, Rebase, RebaseFix, Restack),
    stackDoc,
    stackHelp,
    stackProgram,
    stackRungName,
    stackScript,
  )
import Workflows.Hello (helloDoc, helloHelp, helloScript, helloWorkflow)
import Workflows.HelloWorld (helloWorldDoc, helloWorldHelp, helloWorldProgram, helloWorldScript)
import Workflows.Issue
  ( IssueRung (Fix, Worktree),
    issueDoc,
    issueHelp,
    issueProgram,
    issueRungName,
    issueScript,
  )
import Workflows.Nix
  ( NixRung (Alert, Integration, Rebuild),
    nixDoc,
    nixHelp,
    nixName,
    nixProgram,
    nixScript,
  )
import Workflows.NodeRed (noderedDoc, noderedHelp, noderedProgram, noderedScript)
import Workflows.MeetingNotes (notesDoc, notesHelp, notesProgram, notesScript)
import Workflows.OrgTasks
  ( OrgRung (Breakdown, Infer),
    orgDoc,
    orgHelp,
    orgProgram,
    orgRungName,
    orgScript,
  )
-- Qualified, and for the same reason "Workflows.Effort" is: both
-- "Workflows.Git.Stack" and "Workflows.Partner" have a @Cleanup@ rung, and
-- neither is the one to rename — @stack-cleanup@ and @partner-cleanup@ are two
-- of the owner's own words and each is right in its own module.
import qualified Workflows.Partner as Partner
import Workflows.PrdArchitect
  ( Mode (Critique, Draft),
    prdDoc,
    prdHelp,
    prdName,
    prdProgram,
    prdScript,
  )
import Workflows.Productize
  ( ProductizeRung (Full, Lefthook),
    productizeDoc,
    productizeHelp,
    productizeName,
    productizeProgram,
    productizeScript,
  )
import Workflows.Prose.Polish
  ( Strength (Compress, Proofread, Smooth, Transcript),
    proseDoc,
    proseHelp,
    proseName,
    proseProgram,
    proseScript,
  )
import Workflows.Qanda (qandaDoc, qandaHelp, qandaProgram, qandaScript)
import Workflows.QueryBuilder (queryDoc, queryHelp, queryProgram, queryScript)
-- Qualified, for the reason "Workflows.Effort" is: this module's rung type is
-- also called @Tier@, and neither name is the one to rename — @review-deep@ and
-- @retest@ are two of the owner's own words and each is right in its own module.
-- The qualifier is where the two meet.
import qualified Workflows.Retest as Retest
import Workflows.Review.Ladder
  ( Tier (Deep, Heavy, Quick, Sec),
    reviewDoc,
    reviewHelp,
    reviewLadder,
    reviewScript,
    tierName,
  )
import Workflows.Service
  ( ServiceOp (Install, Remove),
    serviceDoc,
    serviceHelp,
    serviceName,
    serviceProgram,
    serviceScript,
  )
import Workflows.Taskmaster
  ( taskmasterDoc,
    taskmasterHelp,
    taskmasterProgram,
    taskmasterScript,
  )
import Workflows.Teams (teamsDoc, teamsHelp, teamsProgram, teamsScript)
import Workflows.Threads
  ( ThreadRung (Assess, Respond),
    threadRungName,
    threadsDoc,
    threadsHelp,
    threadsProgram,
    threadsScript,
  )
import Workflows.TranscribeImage (transcribeDoc, transcribeHelp, transcribeProgram, transcribeScript)
import Workflows.Translate
  ( Direction (En, Es, Fa),
    translateDoc,
    translateHelp,
    translateName,
    translateProgram,
    translateScript,
  )
import Workflows.TronDebug (tronDoc, tronHelp, tronProgram, tronScript)
import Workflows.Wiggum (wiggumDoc, wiggumHelp, wiggumProgram, wiggumScript)

-- | The toolbox, in the order @wf list@ prints it.
--
-- The smoke row first, then the beginner's two-question tutorial; after those
-- come the flagships, each landing as a family of rows against this table, one
-- family at a time, each row with its own numbers.
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
        [ ("hello", Row (Fixed helloWorkflow) helloDoc helloHelp helloScript),
          ("hello-world", Row (Needs helloWorldProgram) helloWorldDoc helloWorldHelp helloWorldScript),
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
          ("fess", Row (Needs fessAudit) fessDoc fessHelp fessScript),
          stackRow Restack,
          stackRow Rebase,
          stackRow RebaseFix,
          stackRow Cleanup,
          conferRow Confer,
          conferRow Bare,
          conferRow Debate,
          conferRow Second,
          ("checklist", Row (Needs checklistProgram) checklistDoc checklistHelp checklistScript),
          ("teams", Row (Needs teamsProgram) teamsDoc teamsHelp teamsScript),
          ("notes", Row (Needs notesProgram) notesDoc notesHelp notesScript),
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
          ("dead-code", Row (Needs deadCodeProgram) deadCodeDoc deadCodeHelp deadCodeScript),
          ("comments", Row (Needs commentsProgram) commentsDoc commentsHelp commentsScript),
          ("bundles", Row (Needs bundlesProgram) bundlesDoc bundlesHelp bundlesScript),
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
          ("query", Row (Needs queryProgram) queryDoc queryHelp queryScript),
          ("expense", Row (Needs expenseProgram) expenseDoc expenseHelp expenseScript),
          ("qanda", Row (Needs qandaProgram) qandaDoc qandaHelp qandaScript),
          ("transcribe", Row (Needs transcribeProgram) transcribeDoc transcribeHelp transcribeScript),
          ("tron", Row (Needs tronProgram) tronDoc tronHelp tronScript),
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
          ("denote", Row (Needs denoteProgram) denoteDoc denoteHelp denoteScript),
          translateRow Fa,
          translateRow En,
          translateRow Es,
          prdRow Draft,
          prdRow Critique,
          -- Last of the wave's specialists, and last on purpose: `doc/design.md`
          -- §7.4 row 22 says "deeply host-specific -- port last", and this is
          -- the one row in the table whose paths, database, config-node ids and
          -- entity families are one machine's.
          ("nodered", Row (Needs noderedProgram) noderedDoc noderedHelp noderedScript),
          -- A production evidence workflow rather than a language fixture. It sits
          -- in this second registry because it composes existing agent-cat seams
          -- without adding a semantic or transport primitive to agent-cat itself.
          ("taskmaster", Row (Needs taskmasterProgram) taskmasterDoc taskmasterHelp taskmasterScript),
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
          ("wiggum", Row (Needs wiggumProgram) wiggumDoc wiggumHelp wiggumScript),
          -- The same loop across two live panes ("Workflows.WiggumDuet"), and a row
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
          ("wiggum-duet", Row (Needs duetProgram) duetDoc duetHelp duetScript)
        ]
    }
  where
    -- The row's name is the rung's own, from the module that defines the rung:
    -- a registry that spelled it a second time would be the corpus's five
    -- hand-maintained copies of one paragraph, in Haskell.
    reviewRow t =
      ( tierName t,
        Row (Needs (reviewLadder t)) (reviewDoc t) (reviewHelp t) (reviewScript t)
      )
    greenRow r =
      ( rungName r,
        Row (Needs (greenProgram r)) (greenDoc r) (greenHelp r) (greenScript r)
      )
    commitRow r =
      ( commitRungName r,
        Row (Needs (commitProgram r)) (commitDoc r) (commitHelp r) (commitScript r)
      )
    stackRow r =
      ( stackRungName r,
        Row (Needs (stackProgram r)) (stackDoc r) (stackHelp r) (stackScript r)
      )
    -- The confer family. Four rows and not five: the confer-shaped gate
    -- @confer-design.md@ §5.4 sketches is unbuilt, and when it is built it
    -- wants a verdict rather than a document, so it belongs with the gates —
    -- @doc/design.md@ §8.1. The rows sit last because they are the newest wave
    -- and `wf list` is read top to bottom in landing order.
    conferRow r =
      ( conferRungName r,
        Row (Needs (conferProgram r)) (conferDoc r) (conferHelp r) (conferScript r)
      )
    -- The rest of wave 2, in the order `doc/design.md` §8 lists them:
    -- `checklist` (the wave-1 warm-up, which landed with this batch), then
    -- `teams` and `notes` — the corpus's two most literal panels — then the
    -- effort ladder, whose three rows are the owner's own unpriced cost model
    -- (`medium ⊂ heavy ⊂ forge`) with the three prices finally beside it.
    effortRow r =
      ( Effort.effortName r,
        Row (Needs (Effort.effortProgram r)) (Effort.effortDoc r) (Effort.effortHelp r) (Effort.effortScript r)
      )
    -- Wave 3, the daily drivers (`doc/design.md` §8). They are thin over the
    -- library and over waves 1-2's functions, which is what that wave says they
    -- should be: `issue` and `account-halt` call `commitFn`, `issue` calls
    -- `botSweepFn`, `partner-cleanup` calls `commitFn`, and every one of them
    -- ends in a report function of its own family.
    threadsRow r =
      ( threadRungName r,
        Row (Needs (threadsProgram r)) (threadsDoc r) (threadsHelp r) (threadsScript r)
      )
    issueRow r =
      ( issueRungName r,
        Row (Needs (issueProgram r)) (issueDoc r) (issueHelp r) (issueScript r)
      )
    accountRow k =
      ( accountName k,
        Row (Needs (accountProgram k)) (accountDoc k) (accountHelp k) (accountScript k)
      )
    proseRow r =
      ( proseName r,
        Row (Needs (proseProgram r)) (proseDoc r) (proseHelp r) (proseScript r)
      )
    claudeMdRow r =
      ( claudeMdName r,
        Row (Needs (claudeMdProgram r)) (claudeMdDoc r) (claudeMdHelp r) (claudeMdScript r)
      )
    orgRow r =
      ( orgRungName r,
        Row (Needs (orgProgram r)) (orgDoc r) (orgHelp r) (orgScript r)
      )
    serviceRow o =
      ( serviceName o,
        Row (Needs (serviceProgram o)) (serviceDoc o) (serviceHelp o) (serviceScript o)
      )
    nixRow r =
      ( nixName r,
        Row (Needs (nixProgram r)) (nixDoc r) (nixHelp r) (nixScript r)
      )
    productizeRow r =
      ( productizeName r,
        Row (Needs (productizeProgram r)) (productizeDoc r) (productizeHelp r) (productizeScript r)
      )
    partnerRow r =
      ( Partner.partnerRoleName r,
        Row (Needs (Partner.partnerProgram r)) (Partner.partnerDoc r) (Partner.partnerHelp r) (Partner.partnerScript r)
      )
    -- Wave 5. The battery's two rungs are one body and one override table, which
    -- is why they are two rows rather than two programs: `retest` and
    -- `retest-categorical` differ in their oracle, their build target, their
    -- roster and their success word, and a reader compares the two prices in
    -- `wf list` without spending either.
    retestRow t =
      ( Retest.retestName t,
        Row (Needs (Retest.retestProgram t)) (Retest.retestDoc t) (Retest.retestHelp t) (Retest.retestScript t)
      )
    -- Three rows and two shapes, which is the naming rule doing its job: the two
    -- directions that carry a review team are one body with the languages
    -- swapped, and the one that does not is a single call of the same drafting
    -- function. The three prices say which is which without a word of prose.
    translateRow r =
      ( translateName r,
        Row (Needs (translateProgram r)) (translateDoc r) (translateHelp r) (translateScript r)
      )
    -- Two rows because one agent file was two agents. `doc/design.md` §7.3 marks
    -- `prd-architect` R -> 2xT and says to split at the mode boundary BEFORE
    -- writing either; these are the two, and their two prices are the first
    -- thing the split bought.
    prdRow m =
      ( prdName m,
        Row (Needs (prdProgram m)) (prdDoc m) (prdHelp m) (prdScript m)
      )
