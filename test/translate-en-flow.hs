{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

-- Real interpreter and helpers, with a finite translation oracle replacing only
-- model answers. These fixtures test procedure and integrity, not prose quality.
import Agentic.Builder (progPlan)
import Agentic.DSL (Addressee (..))
import Agentic.Plan (ExecTrace, ExecEvent (..), AnswerSource (..), Q (..), Request (..))
import Agentic.Runtime
  ( ExecSettings (..), WorldIO (..), defaultExecSettings, runPlanIO,
    scriptedWorldWith, ShellConfig (..), defaultShellConfig, executingWorld
  )
import Agentic.Workflow (supply)
import Control.Concurrent (newEmptyMVar, putMVar, takeMVar)
import Control.Concurrent.Async (cancel, waitCatch, withAsync)
import Control.Exception (SomeException, bracket, bracket_, displayException, try)
import Control.Monad (forM_, unless)
import Data.Aeson (Result (..), Value (..), decodeStrict', encode, fromJSON, object, (.=))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Lazy as BL
import Data.Either (isLeft)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import qualified Data.Text.IO as TIO
import System.Directory (canonicalizePath, doesDirectoryExist, doesFileExist, getTemporaryDirectory, listDirectory, removeDirectoryRecursive)
import System.Environment (getEnv, setEnv)
import System.FilePath ((</>))
import System.Posix.Temp (mkdtemp)
import Workflows.TranslateEn

source, english, persian, persianEnglish, fragment :: Text
source = "يا أهل العالم اسلكوا سبيل العدل."
english = "O peoples of the world! Walk in the path of justice."
persian = "ای دوست، در راه عدل گام بردار."
persianEnglish = "O friend, walk thou in the path of justice."
fragment = "ای دوست"

renderFixture, reverseFixture :: Text -> Text
renderFixture = T.replace fragment "O friend" . T.replace persian persianEnglish . T.replace source english
reverseFixture = T.replace "O friend" fragment . T.replace persianEnglish persian . T.replace english source

json :: Value -> Text
json = decodeUtf8 . BL.toStrict . encode

field :: Key.Key -> Value -> Value
field key (Object fields) = maybe (error ("missing fixture field " ++ show key)) id (KM.lookup key fields)
field _ _ = error "fixture payload is not an object"

values :: Value -> [Value]
values value = case fromJSON value of
  Success result -> result
  Error why -> error why

textValue :: Value -> Text
textValue value = case fromJSON value of
  Success result -> result
  Error why -> error why

intValue :: Value -> Int
intValue value = case fromJSON value of
  Success result -> result
  Error why -> error why

roles :: [(Text, [Text])]
roles =
  [ ("diction-grammar", ["diction", "grammar"]),
    ("beauty-eloquence", ["beauty", "eloquence"]),
    ("clarity-accessibility", ["clarity", "concision"]),
    ("se-conventions", ["conventions", "terminology"]),
    ("back-translator", ["fidelity"]),
    ("oral-spiritual", ["oralFluidity", "spiritualPotency"])
  ]

payload :: Request c -> Value
payload request = case reverse (T.lines (qPrompt (reqQuestion request))) of
  lastLine : _ -> maybe (error "fixture expected a terminal JSON data line") id (decodeStrict' (encodeUtf8 lastLine))
  [] -> error "empty model request"

fixtureReply :: Request c -> Value
fixtureReply request =
  let value = payload request
      units = values (field "units" value)
      render unit = object ["id" .= field "id" unit, "text" .= renderFixture (textValue (field "source" unit))]
      back unit = object ["id" .= field "id" unit, "text" .= reverseFixture (textValue (field "text" unit))]
      language unit = object
        [ "id" .= field "id" unit,
          "language" .= (if fragment `T.isInfixOf` textValue (field "source" unit) then "Persian" else "Arabic" :: Text)
        ]
      term candidate = object
        [ "term" .= field "term" candidate,
          "applications" .= [object ["unitId" .= unitId, "applies" .= True, "reason" .= ("Applicable fixture term." :: Text)] | unitId <- values (field "unitIds" candidate)]
        ]
      review role = case lookup role roles of
        Nothing -> error ("unknown fixture reviewer " ++ T.unpack role)
        Just scores -> object
          [ "status" .= ("reviewed" :: Text), "issues" .= ([] :: [Value]),
            "scores" .= object [Key.fromText score .= (8 :: Int) | score <- scores],
            "strengths" .= ["Concise wording." :: Text], "summary" .= ("No issues." :: Text)
          ]
   in case qAddressee (reqQuestion request) of
        AddrModel "translate-en-brief" -> object
          [ "languages" .= map language units,
            "terminology" .= map term (values (field "termCandidates" value)),
            "sentenceFragment" .= (map (textValue . field "source") units == [fragment]),
            "fragmentReason" .= ("A vocative phrase." :: Text)
          ]
        AddrModel "translate-en-draft" -> object ["units" .= map render units]
        AddrModel "translate-en-verify" -> object ["edits" .= ([] :: [Value])]
        AddrModel name
          | "translate-en-back-" `T.isPrefixOf` name -> object ["units" .= map back (values (field "english" value))]
          | "translate-en-synthesis-" `T.isPrefixOf` name -> object
              ["units" .= field "candidate" value, "decisions" .= ([] :: [Value]), "notes" .= ([] :: [Text])]
          | Just role <- T.stripPrefix "translate-en-one-" name -> review role
          | Just role <- T.stripPrefix "translate-en-two-" name -> review role
        _ -> error "unexpected non-model fixture question"

settings :: ExecSettings
settings = defaultExecSettings {esLog = const (pure ())}

fixtureWorld :: [(Text, Text)] -> WorldIO
fixtureWorld overrides =
  let base = scriptedWorldWith settings []
      for :: Request c -> WorldIO
      for request = scriptedWorldWith settings (overrides ++ [("", json (fixtureReply request))])
   in base
        { worldAskIO = \code request -> worldAskIO (for request) code request,
          worldAskAttemptIO = \context code request -> worldAskAttemptIO (for request) context code request
        }

check :: String -> Bool -> IO ()
check message condition = unless condition (fail message)

run :: FilePath -> Text -> Text -> Text -> WorldIO -> IO (Text, ExecTrace)
run directory file text engine world = do
  program <- either (fail . T.unpack) pure $ supply translateEnProgram
    [file, text, engine, "(default) = acp:fixture"]
  runPlanIO (executingWorld defaultShellConfig {shellCwd = directory} world) (progPlan program)

freshEngine :: Text
freshEngine = "acp:fixture; a new session per question"

modelQuestions :: ExecTrace -> [(Text, Text)]
modelQuestions events =
  [ (name, qPrompt (reqQuestion request))
  | ExecEvent _ request answerSource _ <- events,
    AddrModel name <- [qAddressee (reqQuestion request)],
    AnswerAsked _ <- [answerSource]
  ]

scratch :: (FilePath -> IO a) -> IO a
scratch action = do
  base <- getTemporaryDirectory
  bracket (mkdtemp (base </> "translation-native.XXXXXX")) removeDirectoryRecursive action

checkSuccess :: Bool -> Text -> Bool -> IO ()
checkSuccess fromFile sourceText short = scratch $ \directory -> do
  let input = directory </> "source.txt"
  TIO.writeFile input sourceText
  (result, trace) <- run directory (if fromFile then T.pack input else "") (if fromFile then "" else sourceText) freshEngine (fixtureWorld [])
  children <- listDirectory (directory </> ".translate-en")
  child <- case filter (not . T.isPrefixOf "." . T.pack) children of
    [only] -> pure only
    _ -> fail "one complete private output bundle must be published"
  let output = directory </> ".translate-en" </> child
  manifestBytes <- TIO.readFile (output </> "manifest.json")
  manifest <- maybe (fail "invalid artifact manifest") pure (decodeStrict' (encodeUtf8 manifestBytes))
  let sections = intValue (field "sections" manifest)
      questions = modelQuestions trace
      names = map fst questions
      expectedCalls = if short then 3 else 19 * sections
  check ("wrong model request count: " ++ show names) (length questions == expectedCalls)
  check "short-input manifest disagrees with the actual path" (field "shortInputException" manifest == Bool short)
  if short
    then check "phrase exception was not disclosed" ("review was skipped" `T.isInfixOf` result)
    else forM_ ["one", "two"] $ \roundName -> do
      forM_ roles $ \(role, _) -> check "a required reviewer was skipped or reused" $
        length (filter (== "translate-en-" <> roundName <> "-" <> role) names) == sections
      let blind = [text | (name, text) <- questions, name == "translate-en-back-" <> roundName]
      check "back-translation received source text or skipped a section" $
        length blind == sections && all (\text -> not (T.any (\c -> c >= '\x0600' && c <= '\x06ff') text) && not ("fullGlossary" `T.isInfixOf` text)) blind
  check "long input did not take the iterative path" (length (T.words sourceText) <= 2000 || sections > 1)
  saved <- TIO.readFile (output </> "translation.txt")
  check "saved text does not cover the entire source in paragraph order" (saved == renderFixture (T.strip sourceText) <> "\n")
  check "Pi result omitted the translation or separate notes" $
    T.strip saved `T.isPrefixOf` result && "Quality notes" `T.isInfixOf` result
  mapM_ (\name -> doesFileExist (output </> name) >>= check "missing delivery artifact") ["quality-notes.txt", "manifest.json"]
  check "Pi result must identify the absolute artifact path" (T.pack output `T.isInfixOf` result)

checkFailure :: Text -> Text -> [(Text, Text)] -> String -> IO ()
checkFailure text engine overrides expected = scratch $ \directory -> do
  failure <- try (run directory "" text engine (fixtureWorld overrides)) :: IO (Either SomeException (Text, ExecTrace))
  case failure of
    Left why -> check ("wrong failure: " ++ displayException why) (T.pack expected `T.isInfixOf` T.pack (displayException why))
    Right _ -> fail "invalid run was reported as successful"
  exists <- doesDirectoryExist (directory </> ".translate-en")
  check "a failed run published an artifact" (not exists)

checkUnavailableModel :: IO ()
checkUnavailableModel = scratch $ \directory -> do
  let base = fixtureWorld []
      unavailable = base
        { worldAskIO = \_ _ -> fail "fixture model unavailable",
          worldAskAttemptIO = \_ _ _ -> fail "fixture model unavailable"
        }
  failure <- try (run directory "" source freshEngine unavailable) :: IO (Either SomeException (Text, ExecTrace))
  case failure of
    Left why -> check "model failure lost its cause" ("fixture model unavailable" `T.isInfixOf` T.pack (displayException why))
    Right _ -> fail "model failure was reported as success"
  exists <- doesDirectoryExist (directory </> ".translate-en")
  check "model failure published an artifact" (not exists)

checkCancellation :: IO ()
checkCancellation = scratch $ \directory -> do
  entered <- newEmptyMVar
  release <- newEmptyMVar
  let base = fixtureWorld []
      block = putMVar entered () >> takeMVar release
      world = base
        { worldAskIO = \code request -> block >> worldAskIO base code request,
          worldAskAttemptIO = \context code request -> block >> worldAskAttemptIO base context code request
        }
  withAsync (run directory "" source freshEngine world) $ \worker -> do
    takeMVar entered
    cancel worker
    result <- waitCatch worker
    check "cancelled work was reported as successful" (isLeft result)
  exists <- doesDirectoryExist (directory </> ".translate-en")
  check "cancelled work published an artifact" (not exists)

main :: IO ()
main = do
  tools <- canonicalizePath "tools"
  oldPath <- getEnv "PATH"
  bracket_ (setEnv "PATH" (tools ++ ":" ++ oldPath)) (setEnv "PATH" oldPath) $ do
    checkSuccess False source False
    checkSuccess True source False
    checkSuccess False (source <> "\n\n" <> persian) False
    checkSuccess False (T.intercalate " " (replicate 600 source)) False
    checkSuccess False fragment True
    checkFailure "" freshEngine [] "supply exactly one"
    checkFailure source freshEngine [("TRANSLATE_EN_MODEL draft", json (object ["units" .= [object ["id" .= ("p00001.s001" :: Text), "text" .= source]]]))] "English candidate retains"
    checkFailure source freshEngine [("TRANSLATE_EN_MODEL review-one-diction-grammar", "")] "Expecting value"
    checkFailure source freshEngine [("TRANSLATE_EN_MODEL verify", "{\"edits\":[{\"id\":\"invented\",\"replacement\":\"bogus\"}]}")] "unauthorized edit"
    checkFailure source "acp:fixture; one session for the run" [] "shares source context"
    checkUnavailableModel
    checkCancellation
  putStrLn "translate-en: native file, pasted, mixed, long and phrase flows; all reviews; artifacts; failures and cancellation verified"
