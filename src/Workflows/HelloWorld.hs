-- |
-- Module      : Workflows.HelloWorld
-- Description : A beginner example that passes one model answer to another.
--
-- This row is deliberately smaller than "Workflows.Hello", which is the
-- toolbox's foundation smoke test. It demonstrates one input, two sequential
-- questions, and the value flowing between them.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}

module Workflows.HelloWorld
  ( helloWorldProgram,
    helloWorldScript,
    helloWorldDoc,
    helloWorldHelp,
  )
where

import Data.String (fromString)
import Data.Text (Text)
import Workflows.Prelude
import qualified Agentic.Workflow.Do as W

-- | The one line @wf list@ prints beside this row.
helloWorldDoc :: Text
helloWorldDoc = "beginner example: ask for a greeting, then translate that answer into a requested language"

-- | The opening question, also used as the scripted-table key.
greetingBrief :: Text
greetingBrief =
  [wft|
  Reply with exactly this text and nothing else:

  Hello, world!|]

-- | The final question, also used as the scripted-table key.
translationBrief :: Text
translationBrief =
  [wft|
  Translate the greeting below into the requested target language. Return only
  the translated text: no label, quotation marks, or explanation.|]

-- | One input and two model questions on one path.
--
-- The translation is the program's typed text result. Returning it adds no
-- question, branch or cost; the CLI renders it after the trace.
helloWorldProgram :: ParameterizedOf 'CodeText
helloWorldProgram =
  taking (input "language" :> noInputs) \language ->
    workflow W.do
      greeting <- ask (broad (model "hello-world-greeter")) [wf|{greetingBrief}|]

      translation <- ask (broad (model "hello-world-translator")) [wf|
          {translationBrief}

          Target language:
          {language}

          Greeting:
          {greeting}|]
      answer translation

-- | The deterministic replies used by @--scripted@ rehearsals.
helloWorldScript :: [(Text, Text)]
helloWorldScript =
  [ (greetingBrief, "Hello, world!"),
    (translationBrief, "¡Hola, mundo!")
  ]

-- | The page @wf help hello-world@ prints below its computed header.
helloWorldHelp :: Text
helloWorldHelp =
  [wft|
  A small worked example for learning agent-cat's authoring surface. The first
  model returns `Hello, world!`; the second receives that answer through a
  prompt hole and translates it. `answer` makes that translation the program's
  typed text result, which `wf run` renders after the streamed trace.

  **Inputs.**

  * `language` — the target language named in the translation prompt, such as
    `Spanish`, `Persian`, or `Japanese`.

  **Transport.** Use ACP for an ordinary terminal run. Both questions use the
  toolbox's pinned broad-reading ladder, so `--require-pinned` can check that
  contract before anything is spent.

  ```sh
  wf run hello-world --engine acp --adapter claude --require-pinned --input-arg language=Spanish
  ```

  **Rehearsal.** The input is named empty to match the repository gate. The
  canned table still returns its Spanish fixture, consults nobody, and exercises
  the same two-step data flow.

  ```sh
  wf run hello-world --scripted --input-arg language=
  ```

  **Caveats.**

  * `--scripted` proves wiring, not translation quality; its answers are fixed.
  * This example has no glossary, review panel, retry, or file output. Use the
    `translate` family when those production concerns matter.
  * A live run writes no file. Its questions appear in the trace and its final
    translation appears in the result block; a deck session is optional.
  |]
