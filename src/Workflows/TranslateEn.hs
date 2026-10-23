{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

-- | The translate-tool procedure: two complete specialist rounds per section.
-- Helpers handle documents and validation. Every model question, panel, revision,
-- publication effect and terminal result remains a native workflow operation.
module Workflows.TranslateEn
  ( translateEnProgram,
    translateEnDoc,
    translateEnHelp,
    translateEnScript,
    translateEnFunctions,
  ) where

import qualified Agentic.Workflow.Do as W
import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString.Lazy as BL
import Data.String (fromString)
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8)
import Workflows.Prelude
import Prelude

primaryPin, backPin, verifyPin :: Text
primaryPin = "translate-en"
backPin = "translate-en-back"
verifyPin = "translate-en-verify"

-- Each step retains its validated context outside the model's response. A model
-- can propose a candidate, not replace the source or the accumulated run state.
modelStep :: Text -> Text -> Fn '[ 'CodeText] 'CodeText
modelStep stage pin = function ("translate-en." <> stage)
  (takes @"context" Text noParams) \context -> W.do
    prompt <- ask (translationStage "prompt" [stage]) [wf|TRANSLATE_EN prompt {stage}
{context}|]
    proposed <- ask (model ("translate-en-" <> stage) `servedBy` pin) [wf|{prompt}|]
    accepted <- ask (translationStage "accept" [stage]) [wf|TRANSLATE_EN accept {stage}
{context}
{proposed}|]
    answer accepted

prepareFn, draftFn, firstSynthesisFn, finalSynthesisFn, verifyFn :: Fn '[ 'CodeText] 'CodeText
prepareFn = modelStep "brief" primaryPin
draftFn = modelStep "draft" primaryPin
firstSynthesisFn = modelStep "synthesis-one" primaryPin
finalSynthesisFn = modelStep "synthesis-two" primaryPin
verifyFn = modelStep "verify" verifyPin

backOneFn, backTwoFn :: Fn '[ 'CodeText] 'CodeText
backOneFn = modelStep "back-one" backPin
backTwoFn = modelStep "back-two" backPin

-- Native labelled text panels retain every review, unlike a verdict fold.
-- Round names distinguish otherwise identical candidates and prevent memo reuse
-- from turning the second independent round into a replay of the first.
reviewFn :: Text -> Fn '[ 'CodeText] 'CodeText -> Fn '[ 'CodeText] 'CodeText
reviewFn roundName backFn = function ("translate-en.review-" <> roundName)
  (takes @"context" Text noParams) \context -> W.do
    back <- call backFn (arg context :> noArgs)
    diction <- ask (translationStage "review-prompt" [roundName, "diction-grammar"]) [wf|TRANSLATE_EN review-prompt {roundName} diction-grammar
{back}|]
    beauty <- ask (translationStage "review-prompt" [roundName, "beauty-eloquence"]) [wf|TRANSLATE_EN review-prompt {roundName} beauty-eloquence
{back}|]
    clarity <- ask (translationStage "review-prompt" [roundName, "clarity-accessibility"]) [wf|TRANSLATE_EN review-prompt {roundName} clarity-accessibility
{back}|]
    conventions <- ask (translationStage "review-prompt" [roundName, "se-conventions"]) [wf|TRANSLATE_EN review-prompt {roundName} se-conventions
{back}|]
    fidelity <- ask (translationStage "review-prompt" [roundName, "back-translator"]) [wf|TRANSLATE_EN review-prompt {roundName} back-translator
{back}|]
    oral <- ask (translationStage "review-prompt" [roundName, "oral-spiritual"]) [wf|TRANSLATE_EN review-prompt {roundName} oral-spiritual
{back}|]
    reviews <- panelText
      [ ("diction-grammar", ask (reviewer "diction-grammar") [wf|{diction}|]),
        ("beauty-eloquence", ask (reviewer "beauty-eloquence") [wf|{beauty}|]),
        ("clarity-accessibility", ask (reviewer "clarity-accessibility") [wf|{clarity}|]),
        ("se-conventions", ask (reviewer "se-conventions") [wf|{conventions}|]),
        ("back-translator", ask (reviewer "back-translator") [wf|{fidelity}|]),
        ("oral-spiritual", ask (reviewer "oral-spiritual") [wf|{oral}|])
      ]
    accepted <- ask (translationStage "accept-reviews" [roundName]) [wf|TRANSLATE_EN accept-reviews {roundName}
{back}
{reviews}|]
    answer accepted
  where
    reviewer role = model ("translate-en-" <> roundName <> "-" <> role) `servedBy` primaryPin

firstReviewFn, secondReviewFn :: Fn '[ 'CodeText] 'CodeText
firstReviewFn = reviewFn "one" backOneFn
secondReviewFn = reviewFn "two" backTwoFn

reviewedSectionFn :: Fn '[ 'CodeText, 'CodeText] 'CodeText
reviewedSectionFn = function "translate-en.reviewed-section"
  (takes @"document" Text . takes @"brief" Text $ noParams) \document brief -> W.do
  draft <- call draftFn (arg brief :> noArgs)
  firstReviews <- call firstReviewFn (arg draft :> noArgs)
  revised <- call firstSynthesisFn (arg firstReviews :> noArgs)
  secondReviews <- call secondReviewFn (arg revised :> noArgs)
  final <- call finalSynthesisFn (arg secondReviews :> noArgs)
  verified <- call verifyFn (arg final :> noArgs)
  assembled <- ask (translationStage "append" []) [wf|TRANSLATE_EN append
{document}
{verified}|]
  answer assembled

sectionFn :: Fn '[ 'CodeText] 'CodeText
sectionFn = function "translate-en.section" (takes @"document" Text noParams) \document -> W.do
  context <- ask (translationStage "section" []) [wf|TRANSLATE_EN section
{document}|]
  brief <- call prepareFn (arg context :> noArgs)
  assembled <- call reviewedSectionFn (arg document :> arg brief :> noArgs)
  answer assembled

translateEnFunctions :: [SomeFn]
translateEnFunctions =
  [ SomeFn prepareFn, SomeFn draftFn, SomeFn backOneFn, SomeFn backTwoFn,
    SomeFn firstReviewFn, SomeFn firstSynthesisFn, SomeFn secondReviewFn,
    SomeFn finalSynthesisFn, SomeFn verifyFn, SomeFn reviewedSectionFn, SomeFn sectionFn
  ]

translateEnProgram :: ParameterizedOf 'CodeText
translateEnProgram = taking
  (argsInputAs "file" :> stdinInputAs "text" :> input "run.engine" :> input "run.routes" :> noInputs)
  \file text engine routes ->
    let request = decodeUtf8 . BL.toStrict . encode $ object
          [ "file" .= file, "text" .= text,
            "independentBackTranslation" .= judgeIsElsewhere routes engine backPin [primaryPin, verifyPin]
          ]
    in defining translateEnFunctions W.do
      document <- ask (translationStage "prepare" []) [wf|TRANSLATE_EN prepare
{request}|]
      context <- ask (translationStage "section" []) [wf|TRANSLATE_EN section
{document}|]
      brief <- call prepareFn (arg context :> noArgs)
      short <- ask (translationStage "short" []) [wf|TRANSLATE_EN short
{brief}|] `annotated` Flag
      if short
        then W.do
          draft <- call draftFn (arg brief :> noArgs)
          verified <- call verifyFn (arg draft :> noArgs)
          assembled <- ask (translationStage "append" []) [wf|TRANSLATE_EN append
{document}
{verified}|]
          result <- ask (translationStage "result" []) [wf|TRANSLATE_EN result
{assembled}|]
          act (translationStage "publish" []) [wf|TRANSLATE_EN publish
{assembled}|]
          answer result
        else W.do
          act (translationStage "independent" []) [wf|TRANSLATE_EN independent
{document}|]
          firstSection <- call reviewedSectionFn (arg document :> arg brief :> noArgs)
          completed <- revising firstSection (atMost 63) \candidate -> W.do
            _progress <- ask (translationStage "progress" []) [wf|TRANSLATE_EN progress
{candidate}|]
            amendWith (call sectionFn (arg candidate :> noArgs))
          case completed of
            Settled assembled -> W.do
              result <- ask (translationStage "result" []) [wf|TRANSLATE_EN result
{assembled}|]
              act (translationStage "publish" []) [wf|TRANSLATE_EN publish
{assembled}|]
              answer result
            Unsettled incomplete -> W.do
              failure <- ask (translationStage "exhausted" []) [wf|TRANSLATE_EN exhausted
{incomplete}|]
              answer failure

translateEnDoc :: Text
translateEnDoc = "translate-tool: Arabic/Persian sacred text into English, with calibrated drafting, two six-specialist rounds, and verified artifacts"

translateEnHelp :: Text
translateEnHelp = [wft|
  The complete procedure developed in translate-tool, rather than the earlier
  reverse-direction sketch. Every normal section receives preparation, a draft,
  six specialist reviews, synthesis, six further reviews, final synthesis and
  targeted mechanical verification. Both fidelity rounds use a separate
  source-hidden back-translation. A genuine phrase may take the explicitly
  reported direct path, but a complete sentence does not bypass review.

  **Inputs.**

  * `file` — a local UTF-8 TXT/MD or DOCX path. Leave empty for pasted text.
    Pi binds this input from the unsplit command tail.
  * `text` — multiline Arabic/Persian source text. Leave empty for a file.
    Pi binds this input from the command body. Supply exactly one source.

  **Transport.** Use the existing Pi workflow launcher or ACP. The lead and
  reviewers use the dedicated `translate-en` profile, without an authored fallback
  chain. Map it to the calibrated Opus model without changing other workflows.
  `translate-en-back` must use fresh question sessions or a dedicated backend
  that never receives source text. `translate-en-verify` permits a separate
  deterministic sampling profile. Configure supported draft sampling at 0.3 and
  verification at 0.0. Unsupported adapter controls are not simulated by prompts.
  A shared conversation without an isolated back-translator refuses thorough work.

  ```sh
  wf run translate-en --engine acp --adapter claude --scratch "$PWD" --require-pinned --input-arg file= --input-arg text='يا أهل العالم اسلكوا سبيل العدل.'
  ```

  **Rehearsal.** Fixed responses exercise one complete section and both panels.
  They make no linguistic claim and write no file:

  ```sh
  wf run translate-en --scripted --input-arg file= --input-arg text=
  ```

  **Caveats.**

  * The Nix package supplies `wf-translate-stage` without relying on ambient PATH.
    A source-tree run adds `tools/` to PATH. File paths are relative to the run's
    working directory, so absolute paths are recommended in Pi. ACP runs should
    select a persistent scratch directory when artifacts must remain in the project.
  * Natural-boundary sections target about 2,000 words. The native bound is 64
    sections, checked before model work. Paragraph identities survive assembly.
  * Final translation, separate quality notes and a manifest are published as a
    new private bundle beneath `.translate-en/`. Its public directory link appears
    only after every file is complete. Keep its hidden `.data-*` backing directory,
    or copy the individual files when exporting. Existing files are never overwritten.
    Drafts and reviews remain in native run artifacts, not in default delivery.
  * Missing reviews, malformed replies, unresolved critical issues, failed
    verification and exhausted processing prevent verified final publication.
    Verification permits only enumerated local pronoun edits. An unresolved glossary
    or meaning defect requires renewed synthesis, not unreviewed paraphrase.
    Deterministic checks do not prove linguistic fidelity or devotional quality.
|]

-- Tool and model fixtures are deliberately wiring tokens, not pretend evidence.
translateEnScript :: [(Text, Text)]
translateEnScript =
  [ ("TRANSLATE_EN prepare", "SOURCE_STATE"),
    ("TRANSLATE_EN section", "SECTION_CONTEXT"),
    ("TRANSLATE_EN accept brief", "PREPARED_CONTEXT"),
    ("TRANSLATE_EN short", "no"),
    ("TRANSLATE_EN progress\nSOURCE_STATE", "OBJECTION: one section remains"),
    ("TRANSLATE_EN progress\nDONE_STATE", "APPROVE"),
    ("TRANSLATE_EN append", "DONE_STATE"),
    ("TRANSLATE_EN result", "SCRIPTED rehearsal complete. No translation artifact was written."),
    ("TRANSLATE_EN accept-reviews", "REVIEWED_CONTEXT"),
    ("TRANSLATE_EN review-prompt", "MODEL review"),
    ("TRANSLATE_EN prompt", "MODEL stage"),
    ("TRANSLATE_EN accept", "VALIDATED_CONTEXT"),
    ("MODEL", "{}")
  ]
