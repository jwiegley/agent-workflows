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
  "the `hello` smoke row. Two cross-cutting lenses, one scrap, no independence \
  \probe and no receipts. Nothing here is evidence about a real tree."

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
    scrapAnswer =
      "def read_config(path):\n\
      \    return eval(open(path).read())"

    answerOf "security" =
      "### [CRITICAL] eval on file contents\n\
      \- **File**: config.py#L1-L2\n\
      \- **Category**: Security\n\
      \- **Confidence**: 95\n\
      \- **Fix**: parse with json.load or ast.literal_eval."
    answerOf "performance" =
      "No performance findings: the function reads one file once."
    answerOf n = "No findings from " <> n <> "."
