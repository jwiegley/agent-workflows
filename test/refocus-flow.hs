{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

-- Exercise the real interpreter with canned external answers. ExecTrace is in
-- plan order; concurrent human-readable log lines need not be.
import Agentic.Builder (progPlan)
import Agentic.DSL (Addressee (..))
import Agentic.Plan
import Agentic.Runtime
  ( ExecSettings (..),
    defaultExecSettings,
    runPlanIO,
    sayEl,
    scriptedWorldWith,
  )
import Agentic.Workflow (ParameterizedOf, supply)
import Control.Monad (unless)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Refocus
import Workflows.Wiggum
import Workflows.WiggumDuet

data Seen = Seen
  { target :: Addressee,
    prompt :: Text,
    reused :: Bool,
    response :: Text
  }

view :: ExecEvent -> Seen
view (ExecEvent code request source value) =
  Seen
    (qAddressee (reqQuestion request))
    (qPrompt (reqQuestion request))
    (case source of AnswerReused -> True; AnswerAsked _ -> False)
    (sayEl code value)

rehearse :: ParameterizedOf r -> [(Text, Text)] -> [Text] -> IO (El r, [Seen])
rehearse workflow replies inputs = do
  program <- either (fail . T.unpack) pure (supply workflow inputs)
  let settings = defaultExecSettings {esLog = const (pure ())}
  (result, trace) <- runPlanIO (scriptedWorldWith settings replies) (progPlan program)
  pure (result, map view trace)

check :: String -> Bool -> IO ()
check message condition = unless condition (fail message)

includes :: Text -> Text -> Bool
includes value context = T.unwords (T.words value) `T.isInfixOf` T.unwords (T.words context)

stage :: Seen -> Maybe Text
stage event = case target event of
  AddrToolExec "utc-now" _ _ -> Just "clock"
  AddrModel "refocus" -> Just "focus"
  AddrTool "wiggum-work" -> Just "work"
  AddrModel "round-account" -> Just "account"
  _ -> Nothing

checkLoop :: Text -> [Seen] -> IO ()
checkLoop assessment events = do
  let clocks = [event | event <- events, stage event == Just "clock"]
      focuses = [event | event <- events, stage event == Just "focus"]
      accounts = [event | event <- events, stage event == Just "account"]
      workers = [event | event <- events, stage event == Just "work"]
      cleanups = filter ((== AddrTool "observation-worker") . target) events
      handoffs = filter ((== AddrModel "handoff") . target) events
  check "each round must read the clock, refocus, work, then account" $
    mapMaybe stage events == concat (replicate 2 ["clock", "focus", "work", "account"])
  check "clock observations must dispatch separately" $ all (not . reused) clocks
  check "clock receipts must reach each assessment" $
    and (zipWith (\clock focus -> response clock `includes` prompt focus) clocks focuses)
  check "goal must reach focus, worker and partner cleanup" $
    all (includes "REFOCUS_GOAL" . prompt) (focuses ++ workers ++ cleanups)
  check "focus result must reach workers, accounts, cleanup and final handoff" $
    all (includes assessment . prompt) (workers ++ accounts ++ cleanups ++ handoffs)
  check "the final checkpoint must run" $ not (null cleanups) && not (null handoffs)
  case (accounts, focuses) of
    (first : _, [_initial, second]) ->
      check "second round lost the first account" $ response first `includes` prompt second
    _ -> fail "expected two round accounts and focus checks"

main :: IO ()
main = do
  (assessment, standalone) <- rehearse refocusProgram refocusScript
    ["REFOCUS_GOAL", "REFOCUS_STANDING"]
  case standalone of
    [clock, focus] -> do
      check "standalone row lost its inputs or clock receipt" $
        all (`includes` prompt focus) [response clock, "REFOCUS_GOAL", "REFOCUS_STANDING"]
      check "standalone result must be the assessment" $ assessment == response focus
    _ -> fail "standalone refocus must contain one clock read and one assessment"
  let inputs = "REFOCUS_GOAL" : replicate 7 ""
  (_, regular) <- rehearse wiggumProgram wiggumScript inputs
  (_, duet) <- rehearse duetProgram duetScript inputs
  mapM_ (checkLoop assessment) [regular, duet]
  putStrLn "refocus: fresh clock and goal/context flow verified in both Wiggum variants"
