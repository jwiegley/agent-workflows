-- |
-- Module      : Workflows.Hello
-- Description : The smoke row — the smallest program that touches the whole
--               foundation.
--
-- This is not one of the owner's commands and does not pretend to be. It exists
-- so that the wiring is __proved__ rather than argued: one registered row that
-- plans, prices and runs @--scripted@ to exit 0 through the new binary, using
-- one member of every foundation module.
--
-- What it touches, and therefore what a green @wf run hello --scripted@ is
-- evidence about:
--
--   * "Workflows.Parties" — a pinned party with a fail-over ladder behind it, so
--     @--require-pinned@ has something to accept;
--   * "Workflows.Rubrics.Ladder" — the derived \"see also\" paragraph;
--   * "Workflows.Rubrics.Reviewers" — the cross-cutting roster, which is a real
--     table transplanted from real files;
--   * "Workflows.Panels" — @documentPanel@, so the sibling table is derived and
--     the answers come back fenced;
--   * "Workflows.Rubrics.Discipline" — the standing read-only rule;
--   * "Workflows.Report" — @reportFn@, called, which means @defining@'s table is
--     exercised too.
--
-- __Level pipeline, one path, one price.__ No branch and no loop, deliberately:
-- a smoke row whose cost is a range is a smoke row whose gate output has to be
-- read carefully, and the first thing a foundation should prove is that the
-- numbers are exact.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}

module Workflows.Hello
  ( helloWorkflow,
    helloScript,
    helloDoc,
    helloHelp,
  )
where

import Data.String (fromString)
import Data.Text (Text)
import Workflows.Prelude
import qualified Agentic.Workflow.Do as W
import Prelude

-- | The one line @wf list@ prints beside this row.
helloDoc :: Text
helloDoc = "the smoke row: two cross-cutting lenses over one scrap, folded and reported"

-- | The page @wf help hello@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- __The one row in the table that declares no input__, and its @Inputs@ section
-- says @none.@ rather than being absent: an operator comparing pages should see
-- the same six headings everywhere, and \"this row takes nothing\" is a fact
-- worth reading, not a section worth omitting. It is also what the help gate
-- checks for.
--
-- __The advice this page carries is unlike every other row's__, because this
-- row's job is unlike every other row's: it is the one to run first against a
-- new transport, and what it tells you is whether the wiring works — not
-- anything about your repository.
--
-- __It states no price.__ The header above it carries the numbers off the same
-- 'Agentic.Plan.Facts' @wf list@ publishes.
helloHelp :: Text
helloHelp =
  [wft|
  The smoke row: one scrap of code asked for, two cross-cutting lenses over it,
  folded and reported. It exists to prove the *wiring* — the registry, the
  shared CLI, the roster, the panel fold, the report — rather than to do any of
  the owner's work, and it is the row to run first against a transport you have
  not used before.

  **Inputs.** none.

  **Transport.** Anywhere, and that is the point: this is the row whose only job
  is to answer the question "does this transport work at all". Run it against a
  fresh adapter, a new pane, or a stub before pointing anything expensive at
  them. It writes no file of yours, so `--scratch` changes nothing about what it
  means.

  ```sh
  wf run hello --engine acp --adapter claude
  ```

  **Rehearsal.** No input to name, every question answered from the row's own
  canned table, consulting nobody — and a complete test of the binary, the
  registry and the CLI in one line. Rows that price lower than this one exist;
  none of them is *for* this:

  ```sh
  wf run hello --scripted
  ```

  **Caveats.**

  * A green `hello` says the transport works. It says nothing about a row that
    edits, refuses on a run fact, or puts a question to a person — those are
    facts about the rows that do them.
  * It prices exactly and has no branch, so its number never moves for a reason
    that is about your repository. If it moves, the language did.
  * `--require-pinned` is deliberately absent from the line above: this row is
    what you reach for when the pinning story is what you are trying to
    establish.
  |]

-- | What the opening question asks for.
--
-- It is a @define@ and therefore the prompt's first chunk, which is what lets
-- 'helloScript' key on it by prefix rather than by proofreading.
scrapBrief :: Text
scrapBrief =
  [wft|
  Write out one short function -- at most eight lines, in any language -- that
  is worth reviewing: it should do something real and have exactly one thing
  wrong with it. Reply with the code and nothing else.|]

-- | The provenance line this row's report carries.
--
-- The smoke row runs no independence probe, so it says so. That is the whole
-- shape 'Workflows.Rubrics.Discipline.unverifiedIndependence' exists for, at
-- its smallest: a report that did not establish something does not get to imply
-- it.
-- The word \"Provenance\" is not repeated here: 'Workflows.Report.reportFn'
-- labels the slot, and a value that labels itself again prints the word twice.
helloProvenance :: Text
helloProvenance =
  [wft|
  the `hello` smoke row. Two cross-cutting lenses, one scrap, no independence
  probe and no receipts. Nothing here is evidence about a real tree.|]

-- | The program.
helloWorkflow :: Program
helloWorkflow = defining reportTable W.do
    scrap <- ask (broad (model "author")) [wf|{scrapBrief}|]

    findings <- documentPanel crossCuttingRoster scrap

    call_ reportFn (arg helloProvenance :> arg findings :> noArgs)
    stop

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves.__ The opening question's prompt is
-- @[wf|{scrapBrief}|]@ and each panel member's opens with its own
-- @'Workflows.Panels.lensBrief'@, so every key below is a prefix of the rendered
-- prompt __by construction__. The two lens rows are derived from the very roster
-- the panel is built from, so a lens added to
-- 'Workflows.Rubrics.Reviewers.crossCutting' arrives here by being added.
--
-- Only the /text/ questions need entries: @'Agentic.Exec.scriptedDefault'@
-- answers a flag @yes@, a verdict @APPROVE@ and a receipt @DONE@, and the
-- closing act is a receipt.
helloScript :: [(Text, Text)]
helloScript =
  (scrapBrief, scrapAnswer)
    : [(lensBrief l, answerOf (lensName l)) | l <- crossCuttingRoster]
  where
    -- fixture bytes, not prose: a code scrap whose indentation is the defect
    -- under review. The fence carries the exact bytes: its margin is set at the
    -- scrap's OUTDENTED line, so common-strip removes the margin and nothing
    -- else, and the body's four-space indent survives.
    scrapAnswer =
      [wft|
      def read_config(path):
          return eval(open(path).read())|]

    answerOf "security" =
      [wft|
      ### [CRITICAL] eval on file contents
      - **File**: config.py#L1-L2
      - **Category**: Security
      - **Confidence**: 95
      - **Fix**: parse with json.load or ast.literal_eval.|]
    answerOf "performance" =
      "No performance findings: the function reads one file once."
    answerOf n = "No findings from " <> n <> "."
