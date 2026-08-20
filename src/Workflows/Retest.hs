-- |
-- Module      : Workflows.Retest
-- Description : The model-support battery — one body, two oracles, priced before
--               an FPGA is touched.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                 | here                                                          |
-- +===========================================+===============================================================+
-- | @commands\/retest.md@                     | @retest@ — the command is four lines that say \"follow the     |
-- |                                           | skill\"; the skill is the row                                  |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @skills\/retest\/SKILL.md@                | @retest@, tier 'Hf': the HuggingFace @transformers@ forward    |
-- |                                           | pass as the oracle                                             |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @skills\/retest\/references\/spec.md@     | @'Agentic.Workflow.input' \"spec\"@ — 674 lines are an          |
-- | (674 lines)                               | @--input-file@, not prompt bulk                                |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @commands\/retest-categorical.md@         | @retest-categorical@, tier 'Categorical': the same body, the   |
-- |                                           | legacy ingest path as the oracle, and the nine override rows   |
-- |                                           | as nine fields of 'Battery'                                    |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its \"Phase 0\" eight-model table         | 'categoricalRoster' — eight @(repo, slug, tag)@ rows, so the   |
-- |                                           | sweep is __argv__ and @wf cost@ prices it                      |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its \"isolated sweep runner — one         | @'Agentic.Workflow.panel'@ over the roster: one process per     |
-- | TEST_CASE per process\" (85 lines of      | model by construction, and no @set -f@ noglob hazard because   |
-- | bash)                                     | a tag is an argv element and never a shell word                |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | @/retest@ Phase 4 (\"invoke              | 'auditRoster' — the __same__                                   |
-- | @\/deep-review@\") and Phase 5            | "Workflows.Rubrics.Reviewers" rows and the __same__            |
-- | (\"invoke @comment-audit@\")              | @'Workflows.Review.Ladder.commentAuditLens'@ that              |
-- |                                           | @review-deep@ and @comments@ panel, in one fold                |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | its \"claim discipline\" paragraph        | 'gradingBrief' plus 'Workflows.Deciders.batteryIncomplete' —   |
-- | (@PASS \/ SKIPPED \/ QUARANTINED \/       | the five states are read for __zero questions__, and the       |
-- | DIVERGE \/ NO-COVERAGE@, never collapsed) | success ending is unreachable while any of them stands         |
-- +-------------------------------------------+---------------------------------------------------------------+
-- | both files' \"Overall verdict\" sections  | three free deciders and five endings, one 'retestReportFn'     |
-- +-------------------------------------------+---------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __\"Do not stop at the first failure — finish the sweep\" is what a panel
--      /is/.__ Both files open with that sentence and neither can enforce it: a
--      reader who hits a red build stops. A
--      @'Agentic.Workflow.panel'@ asks __every__ member and folds the answers in
--      the noncommutative verdict monoid, so the sweep is exhaustive by
--      construction and the objection a run reports is the first failing model in
--      roster order. It is the one place in this tree where the corpus's loudest
--      instruction becomes a fold rather than a rule.
--
--   2. __An eight-model FPGA run is priced before an FPGA is touched.__
--      @doc\/design.md@ §7.2 row 57 asks for exactly this. 'categoricalRoster' is
--      the @retest-categorical.md@ Phase-0 table written down, the gate is one
--      process per row, and @wf cost retest-categorical@ answers with a number
--      before a card is opened. The corpus's own runner computes the same set in
--      bash, at which point the machine is already busy.
--
--   3. __Phase numbering ceases to exist, so the off-by-one is
--      unrepresentable.__ @retest-categorical.md@ spends a numbered paragraph on
--      its own hazard: \"Phase numbering is off by one for perf … when this doc
--      says use the @\/retest@ Phase-6 perf methodology, that maps onto this
--      doc's Phase 5\", and a second on @--no-semantic@ meaning two different
--      things. Here there are no phase numbers. There is a build, a unit sweep, a
--      headline gate, a semantic check, an audit and a perf sweep — the same six
--      in the same order for both rungs — and the two rungs differ only in the
--      'Battery' fields. A number that does not exist cannot be off by one.
--
--   4. __\"No machine handoff or argument forwarding\" was the md's own
--      complaint.__ @retest-categorical.md@ says its delegation to @\/retest@ is
--      \"a __documentation-style delegation__ — there is no machine handoff or
--      argument forwarding; read both docs and apply the overrides by hand\". The
--      program __is__ the handoff: 'battery' is one table, 'retestProgram' is one
--      body, and the overrides are applied by the compiler rather than by hand.
--
--   5. __The empty derived set cannot be a success, and not because a grader said
--      so.__ Both files insist that an empty or unrunnable model set is
--      @INCOMPLETE@, \"never a success\". Here
--      @'Workflows.Deciders.noModelSet'@ reads the derivation's own answer for
--      nothing and the success ending sits behind it, so a grader that writes
--      @HF-CORRECT@ over a run that gated no model cannot reach the arm that
--      reports it.
--
--   6. __Every command is argv, and there is no shell.__ The corpus wraps all
--      thirty-odd of its commands as @nix develop --command bash -c '\<CMD\>'@;
--      here each is @nix develop --command@ plus an argv, run by "Agentic.Shell"
--      with @proc@. The one environment variable the perf methodology fixes
--      (@SYSTEM_CONFIG=\"--instance 0,1\"@, whose absence \"starves GPT-OSS-120B's
--      decode KV cache\") rides on @env@, which is a process and not a shell.
--
-- == Four things this module is deliberately specific about
--
-- __The build flavour table collapses to its own documented superset.__
-- @spec.md@ Phase 1 is a five-row table keyed on @CHANGED@, which is a receipt —
-- so a flavour chosen from it would be a model choosing the build. Its own last
-- row says what to do when the key is ambiguous: @make build-ingest -j 4@,
-- \"superset: sets @BUILD_TEST_MODELS=ON@ and @BUILD_INGEST_MODELS=ON@\". That is
-- 'batTarget' at tier 'Hf', and it is the spec's answer rather than this module's.
--
-- __The roster is the operator's or the table's, never the diff's.__ @spec.md@
-- derives the model set from @git diff --name-only@ by four signals and then hopes
-- the tags the operator passed agree with it. Here the argv is authored from the
-- @models@ input (tier 'Hf') or from the fixed eight (tier 'Categorical'), and the
-- derivation is still asked — as an __audit of the invocation__, not as its
-- source. That is the only arrangement available to a program whose commands are
-- written before the run, and it is the better one: the operator sees the models
-- the sweep will open in @wf plan --raw@ before it opens them.
--
-- __A tag filter does not narrow the categorical ship gate, by that file's own
-- ruling.__ \"A tag filter only /subsets/ that roster for a quick local run; the
-- ship gate is always all supported models.\" So 'batRoster' at 'Categorical'
-- ignores the @models@ input and returns the eight. An operator who wants one
-- model runs the binary himself; a row named @retest-categorical@ that could
-- silently gate one model would be the failure that file is written to prevent.
--
-- __Both rungs run the audit, which resolves a contradiction in the corpus.__
-- @retest-categorical.md@'s override table replaces \"Phase 4 = code review\"
-- with the semantic logit matrix, and its own second paragraph lists \"the
-- review\/comment phases\" among the shared grunt work it delegates. Both cannot
-- be true. @doc\/design.md@ §7.2 row 56's ruling — phase numbering ceases to exist
-- — decides it: the audit is a check both rungs run, the semantic check is a
-- check both rungs run, and what differs is which command answers the second one.
-- Nothing is dropped, and no reader has to hold two numbering schemes.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Retest
  ( -- * The two rungs
    Tier (..),
    retestName,
    retestDoc,

    -- * The override table
    Battery (..),
    battery,
    Model (..),
    modelsOf,
    categoricalRoster,

    -- * The tier-1 readings of an invocation
    diffRange,
    promptFile,
    auditRoster,

    -- * The program
    retestProgram,
    retestScript,

    -- * The function
    retestReportFn,
    retestTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Workflows.Review.Ladder (commentAuditLens)
import Prelude

-- ---------------------------------------------------------------------------
-- The two rungs
-- ---------------------------------------------------------------------------

-- | The two oracles the owner's two commands gate against.
--
-- Two rungs and not two programs: what differs between them is 'Battery', which
-- is data, and @doc\/design.md@ §7.2 row 56 is explicit that
-- @retest-categorical@ is @retest@ with nine overrides applied.
data Tier
  = -- | @skills\/retest\/SKILL.md@ — the HuggingFace @transformers@ reference
    -- forward pass is the source of truth.
    Hf
  | -- | @commands\/retest-categorical.md@ — the legacy ingest path is the source
    -- of truth, and the claim is bit-exact last-prompt-token logits.
    Categorical
  deriving (Eq, Show)

-- | The name the operator types, and the name the provenance line carries.
retestName :: Tier -> Text
retestName Hf = "retest"
retestName Categorical = "retest-categorical"

-- | The sibling rung, which the wrong-tree ending names.
--
-- /Source:/ both files' branch preconditions, which each end by naming the other
-- — @\"on main, use \/retest\"@ and @\"for the categorical pipeline's all-model
-- byte-identity sweep, use \/retest-categorical\"@. In the corpus that is a
-- sentence a reader may be in the wrong document to have read; here it is the
-- text of the one ending a wrong tree can reach.
retestSibling :: Tier -> Text
retestSibling Hf = "retest-categorical"
retestSibling Categorical = "retest"

-- | The one line @wf list@ prints beside a rung.
retestDoc :: Tier -> Text
retestDoc Hf =
  "retest/SKILL.md: the model-support battery against the HuggingFace forward pass — one exhaustive sweep, five endings, priced first"
retestDoc Categorical =
  "retest-categorical.md: the same battery against the legacy ingest path, over the fixed eight-model roster — an FPGA sweep priced before a card is opened"

-- ---------------------------------------------------------------------------
-- The models a rung sweeps
-- ---------------------------------------------------------------------------

-- | One row of a sweep: the HuggingFace repository the weights come from, the
-- runtime slug the executor is addressed by, and the Catch2 tag the gate case is
-- selected by.
--
-- /Source:/ @commands\/retest-categorical.md@'s Phase-0 table, which is exactly
-- @(huggingface-repo, default-tp-slug)@ pairs, plus its Phase-3
-- model-to-executor list, which is where the tags are written.
--
-- __Three fields and not one__, because the corpus needs all three and derives
-- none of them: the repo is what @bin\/get_model@ provisions, the slug is what
-- @runtron@ is pointed at, and the tag is what the gate binary filters on. A
-- program that carried only the slug would have to guess the other two, and
-- guessing the tag is the documented bug the file spends a paragraph on
-- (\"a name extracted from it silently fails to match and the case never
-- runs — a real bug observed in practice\").
data Model = Model
  { -- | the HuggingFace repository, for the semantic check's @--model@
    modelRepo :: !Text,
    -- | the runtime slug, for the executor
    modelSlug :: !Text,
    -- | the Catch2 tag, for the gate's per-process selector
    modelTag :: !Text
  }
  deriving (Eq, Show)

-- | The @models@ input, read as a roster.
--
-- __Tier 1__ ("Workflows.Deciders"): ordinary Haskell over the invocation, zero
-- questions and zero paths, and every field lands in the printed argv.
--
-- One model per line, spelled @repo=slug@ — the same shape
-- @retest-categorical.md@'s own Phase-0 table is written in. A line with no @=@
-- is a bare slug, and its repo becomes a name no repository has, so
-- @wf plan --raw@ prints @--model \<no huggingface repo given\>@ rather than
-- gating the semantic check against something plausible. The tag is derived from
-- the slug, which is the convention the project's own tags follow.
--
-- __An empty input is the spec's own example and never the empty list__ (house
-- rule WR-1): @'Agentic.Workflow.panel' []@ is an @error@ on a CAF, and a battery
-- with no model in it would take the binary down inside @ci\/workflows.sh@. The
-- default is @llama_3p1_8b@, which is the slug @spec.md@'s @Arguments@ section
-- uses as its example.
modelsOf :: Text -> [Model]
modelsOf raw = case [row l | l <- pathsOf raw] of
  [] -> [row "llama_3p1_8b"]
  ms -> ms
  where
    row l = case T.breakOn "=" l of
      (repo, rest)
        | not (T.null rest) ->
            let slug = T.strip (T.drop 1 rest)
             in Model (T.strip repo) slug (tagOf slug)
      _ -> Model "<no huggingface repo given>" l (tagOf l)

    tagOf s = "[" <> s <> "]"

-- | The eight models @commands\/retest-categorical.md@ gates on, written down.
--
-- /Source:/ its Phase-0 @MODELS@ array (repo and slug, verbatim) and its Phase-3
-- \"Model -> executor\" list (the tags, verbatim). The file's own instruction —
-- \"keep the roster aligned with the @ModelDef@ table in
-- @t\/t_generate_categorical_fpga_real.cpp@\" — is the reason this is one binding:
-- a roster spelled twice is a roster that drifts, and the file spells it twice
-- already.
categoricalRoster :: [Model]
categoricalRoster =
  [ Model "shuyuej/Llama-3.2-1B-Instruct-GPTQ" "ingested-llama-3.2-1b" "[llama-3.2-1b]",
    Model "thesven/Meta-Llama-3.1-8B-Instruct-GPTQ" "ingested-llama-3.1-8b" "[llama-3.1-8b]",
    Model "microsoft/phi-4" "ingested-phi-4" "[phi-4]",
    Model "hfl/chinese-alpaca-2-7b" "ingested-chinese-alpaca-2-7b" "[chinese-alpaca-2-7b]",
    Model "mistralai/Mixtral-8x7B-Instruct-v0.1" "ingested-mixtral-8x7b-instruct-v0.1-tp4" "[mixtral-8x7b]",
    Model "positron-ai/openai--gpt-oss-20b-ingest-best-gptq" "ingested-gpt-oss-20b-tp4" "[gpt-oss-20b]",
    Model "positron-ai/openai--gpt-oss-120b-ingest-best-gptq" "ingested-gpt-oss-120b-tp4" "[gpt-oss-120b]",
    Model "Qwen/Qwen2.5-32B-Instruct-GPTQ-Int4" "ingested-qwen-2.5-32b-tp4" "[qwen-2.5-32b]"
  ]

-- | The roster, as the table the derivation question audits the invocation
-- against.
--
-- __Tier 1__: three columns of text computed from the invocation, spliced into one
-- question. It costs nothing and it is the thing an operator most wants to see
-- before an eight-model FPGA sweep starts.
fleetTable :: [Model] -> Text
fleetTable ms =
  bullets
    [ (modelSlug m, "weights " <> modelRepo m <> ", gate case " <> modelTag m)
    | m <- ms
    ]

-- ---------------------------------------------------------------------------
-- The override table
-- ---------------------------------------------------------------------------

-- | @commands\/retest-categorical.md@'s nine-row override table, as nine fields.
--
-- @doc\/design.md@ §7.2 row 56: \"nine override rows as nine arguments\". The
-- fields below are in the table's own order, one per row, and the tenth field is
-- the override that file states in prose and forgot to table — which is itself
-- the argument for the table being code.
data Battery = Battery
  { -- | row 1 — the source of truth, in one sentence
    batOracle :: !Text,
    -- | row 2 — how the boundary sweep is gated
    batBoundary :: !Text,
    -- | row 3 — the comparison binary
    batGateBinary :: !Text,
    -- | row 4 — the @make@ target
    batTarget :: !Text,
    -- | row 5 — the model set
    batRoster :: Text -> [Model],
    -- | row 6 — the per-process gate selector
    batSelector :: Model -> Text,
    -- | row 7 — the semantic check
    batSemantic :: [Model] -> [Party 'IsTool],
    -- | row 8 — the slugs a perf comparison is run over
    batSlugs :: Model -> [Text],
    -- | row 9 — the overall success word
    batVerdict :: !Text,
    -- | the tenth override, stated in @Phase 2@'s parenthesis and in no table
    -- row: @\"the categorical run does not need the FPGA @make test-ingest@
    -- layer\"@
    batUnits :: [Party 'IsTool]
  }

-- | The two rungs' override rows, side by side.
battery :: Tier -> Battery
battery Hf =
  Battery
    { batOracle =
        "the HuggingFace `transformers` reference forward pass: logit \
        \allclose/TVD, top-1 and top-K overlap, and decoded-token parity",
      batBoundary =
        "the boundary set {8, 64, 256, 4096, 16384} is gated against \
        \HuggingFace top-K inclusion, and the spec records that only some \
        \binaries register the boundary cells -- an acknowledged coverage gap on \
        \this path, and a NO-COVERAGE rather than a pass wherever a cell is \
        \unregistered",
      batGateBinary = "gen/t_generate_ingest_1",
      batTarget = "build-ingest",
      batRoster = modelsOf,
      batSelector = modelTag,
      batSemantic = map (logitEquivalence . modelRepo),
      batSlugs = \m -> [modelSlug m],
      batVerdict = "HF-CORRECT",
      batUnits = [ingestCabalTest, makeUnit "retest-unit-host" "test-host", makeUnit "retest-unit-ingest" "test-ingest"]
    }
battery Categorical =
  Battery
    { batOracle =
        "the legacy ingest pipeline: bit-exact last-prompt-token logits, \
        \`require_byte_identical`, 100% -- not HuggingFace",
      batBoundary =
        "the same boundary set {8, 64, 256, 4096, 16384} and the same base \
        \methodology, gated against legacy byte-identity: no top-K slack, every \
        \in-scope (model, length) cell bit-exact through the page boundaries, \
        \out-of-scope lengths reported N/A-MAX-POSITION and never as a pass",
      batGateBinary = "gen/t_generate_categorical_fpga_real",
      batTarget = "build-categorical",
      -- The input is ignored, by that file's own ruling: "a tag filter only
      -- subsets that roster for a quick local run; the ship gate is always all
      -- supported models."
      batRoster = const categoricalRoster,
      -- "The oracle case is selected by TAG EXCLUSION `[model]~[long]`, NOT by a
      -- name pulled from `--list-tests`" — the file's own paragraph about a real
      -- bug it observed, as one function.
      batSelector = \m -> modelTag m <> "~[long]",
      -- One command for the whole matrix, and it "runs the full non-MoE matrix
      -- regardless of any tag filter passed in $ARGUMENTS" — so it takes the
      -- roster and ignores it, which is what the sentence says.
      batSemantic = const [categoricalMatrix],
      -- "Slugs: categorical = `categorical-$MODEL[-tpN]`, legacy =
      -- `ingested-$MODEL[-tpN]`" — a PAIR per model, because the perf comparison
      -- is between two pipelines and a single slug would compare a run with
      -- itself.
      batSlugs = \m -> [categoricalSlug (modelSlug m), modelSlug m],
      batVerdict = "BYTE-EXACT DROP-IN",
      batUnits = [ingestCabalTest, makeUnit "retest-unit-host" "test-host"]
    }

-- | @ingested-\<m\>@ -> @categorical-\<m\>@, which is the pairing
-- @retest-categorical.md@ spells twice.
--
-- __Tier 1__, and computed rather than named: the two slugs are the same model
-- through two pipelines, and a mismatched pair would compare two different models
-- while looking exactly like a real result. That is @'Workflows.Tron.bulkModel'@'s
-- argument at another project's naming convention.
--
-- A slug that does not begin @ingested-@ is passed through with the prefix
-- prepended, and the report names both sides, so a surprise here is visible
-- rather than silent.
categoricalSlug :: Text -> Text
categoricalSlug s = case T.stripPrefix "ingested-" s of
  Just rest -> "categorical-" <> rest
  Nothing -> "categorical-" <> s

-- ---------------------------------------------------------------------------
-- The argv
-- ---------------------------------------------------------------------------

-- $argv
--
-- These belong in "Workflows.Evidence" — that module is where the read-only rule
-- could be broken, so it is reviewable as a unit. They are grouped here, in one
-- labelled block, for @'Workflows.Tron'@'s and @'Workflows.Git.Stack'@'s reason:
-- they are one project's build system, the move is one cut and one paste, and the
-- exception is visible rather than scattered.
--
-- None of them points at @~\/src\/nix\/config\/ai@ and __none of them is composed
-- with a shell__. The corpus wraps every one of its commands as
-- @nix develop --command bash -c '\<CMD\>'@; here the wrapper survives and the
-- @bash -c@ does not, because there is nothing for a shell to do once the
-- sequencing belongs to the program.

-- | @nix develop --command make -n TARGET@ — does this tree have the target?
--
-- /Source:/ @commands\/retest-categorical.md@'s branch precondition, which asks
-- for exactly this and then says \"abort with this message otherwise\". Asked as a
-- __flag__, because that is what an exit code is: @make -n@ exits nonzero when
-- the target does not exist, and the run's one refusal-to-start hangs off it.
--
-- Generalised to both rungs, and that is the level-up: @retest.md@ carries the
-- same fact from the other side (\"@make build-categorical@ is not a target in
-- main — never use it\") and has no way to check it either. One probe, two rungs,
-- and each names the other in its failing arm.
makeTargetProbe :: Text -> Party 'IsTool
makeTargetProbe target =
  tool "retest-target-probe"
    `running` ("nix", ["develop", "--command", "make", "-n", target])

-- | @nix develop --command make TARGET -j 4@ — the rebuild.
--
-- /Source:/ @spec.md@ Phase 1's flavour table (tier 'Hf', its own ambiguous-key
-- superset row) and @retest-categorical.md@ Phase 1 (tier 'Categorical'). The
-- @-j 4@ is the corpus's own standing operating rule — \"@-j 4@ max build jobs\"
-- — and it is in the printed argv rather than in a paragraph a model must
-- remember.
makeBuild :: Text -> Party 'IsTool
makeBuild target =
  tool "retest-build"
    `running` ("nix", ["develop", "--command", "make", target, "-j", "4"])

-- | @nix develop --command bin\/ingest-cabal test@ — the Haskell ingest IR layer.
--
-- /Source:/ @spec.md@ Phase 2 layer 1, whose @bin\/ingest-cabal build &&
-- bin\/ingest-cabal test@ is two processes joined by a shell operator. The build
-- half is 'makeBuild''s job and already ran, so what is left is the test.
ingestCabalTest :: Party 'IsTool
ingestCabalTest =
  tool "retest-unit-haskell"
    `running` ("nix", ["develop", "--command", "bin/ingest-cabal", "test"])

-- | @nix develop --command make TARGET@ — one of the unit-test layers.
--
-- /Source:/ @spec.md@ Phase 2 layers 2 and 3, with the same @&&@-removal: the
-- corpus's @make build-test -j 4 && make test-host@ builds and then tests, and
-- the build already happened.
--
-- The party name is a parameter because "Agentic.Workflow" exports no accessor
-- for a party's name, so a caller cannot label a receipt with the command that
-- produced it — the finding @'Workflows.Review.Ladder.tierDossier'@ records
-- against "Workflows.Rubrics.Reviewers". Naming the layers here is what makes
-- @wf plan --raw@ say which of them objected.
makeUnit :: Text -> Text -> Party 'IsTool
makeUnit name target =
  tool name `running` ("nix", ["develop", "--command", "make", target])

-- | @nix develop --command BINARY SELECTOR@ — one gate case, in its own process.
--
-- /Source:/ @retest-categorical.md@'s isolated sweep runner and @spec.md@ Phase
-- 3's standing rule: \"__One TEST_CASE per process__ for all FPGA tests — Catch2
-- single-process mode shares FPGA state across cases. Never run the binary
-- unfiltered or with a multi-match filter as the gate.\"
--
-- One party per roster row, so \"one process per case\" is the shape of the
-- printed program rather than a discipline the runner is trusted with. And the
-- runner's own @set -f@ hazard — \"noglob: Catch2 tags are bracket-globs
-- (@[phi-4]@); unquoted they expand against cwd dirs and mangle
-- @phi-4\/chinese-alpaca\/mixtral@ into single-char tags\" — has no referent
-- here, because a tag is an argv element and argv elements are not globbed.
--
-- Asked at @'Agentic.Workflow.Verdict'@: exit @0@ approves, a nonzero exit
-- objects with the binary's own first failing line (which for this binary is
-- @first divergence at position …@), and a missing binary or a hung case is a
-- __gap__ rather than a failure of the model.
fpgaCase :: Text -> Text -> Party 'IsTool
fpgaCase binary selector =
  tool "retest-fpga"
    `running` ("nix", ["develop", "--command", binary, selector])

-- | @nix develop --command python …\/logit_equivalence_test.py --model REPO
-- --output-dir \/tmp\/logit_test@ — the HuggingFace semantic check.
--
-- /Source:/ @spec.md@ Phase 3 check 1, flag for flag, including the output
-- directory. Its tolerance defaults (@--atol 0.1@, @--rtol 0.01@,
-- @--tvd-threshold 0.01@) are deliberately __not__ passed: the spec says they are
-- the committed defaults, and a battery that restated them on the command line
-- would be a battery whose thresholds drift from the ones the project pinned.
logitEquivalence :: Text -> Party 'IsTool
logitEquivalence repo =
  tool "retest-semantic"
    `running` ( "nix",
                [ "develop",
                  "--command",
                  "python",
                  "ingest/runtime/scripts/logit_equivalence_test.py",
                  "--model",
                  repo,
                  "--output-dir",
                  "/tmp/logit_test"
                ]
              )

-- | @nix develop --command bin\/ci\/categorical_logit_matrix.sh@ — the categorical
-- semantic gate.
--
-- /Source:/ @retest-categorical.md@ Phase 4, verbatim. No flag is passed, and
-- @--strict-top1@ in particular is not: that file says the flag belongs to
-- @categorical_logit_test.py@ /inside/ the script and that @\/retest@ \"forbids
-- inventing it\" on the outer command. A flag this module does not write is a
-- flag it cannot invent.
categoricalMatrix :: Party 'IsTool
categoricalMatrix =
  tool "retest-semantic"
    `running` ("nix", ["develop", "--command", "bin/ci/categorical_logit_matrix.sh"])

-- | @env SYSTEM_CONFIG=--instance 0,1 nix develop --command gen\/runtron
-- stream-generate-text --model SLUG …@ — one perf trial.
--
-- /Source:/ both files' fixed perf methodology, which says not to vary any of it:
-- 64-token prompt, 32-token greedy decode, @--temperature 0
-- --pay-for-determinism --seed 42@, and @SYSTEM_CONFIG=\"--instance 0,1\"@ for
-- every launch because @--instance 0,4@ \"starves GPT-OSS-120B's decode KV cache
-- -> DEBUG EXIT\".
--
-- __The environment variable rides on @env@, which is a process.__ An
-- assignment prefix is shell syntax and there is no shell here, so the argv names
-- @env@ — a real binary — and the variable is its first operand. That is the
-- house's @proc@-never-@sh -c@ rule honoured rather than worked around, and the
-- variable is in the printed argv where a reader can see it.
--
-- The prompt file is 'promptFile', which is the corpus's own @\/tmp@ convention
-- with the rung's name in it. Three trials per side and the median are the
-- methodology's, and they are a property of the /report/ rather than of the argv:
-- see 'perfBrief'.
perfRun :: Text -> Text -> Party 'IsTool
perfRun prompt slug =
  tool "retest-perf"
    `running` ( "env",
                [ "SYSTEM_CONFIG=--instance 0,1",
                  "nix",
                  "develop",
                  "--command",
                  "gen/runtron",
                  "stream-generate-text",
                  "--model",
                  slug,
                  "-f",
                  prompt,
                  "--prompt-length",
                  "64",
                  "--length",
                  "32",
                  "--temperature",
                  "0",
                  "--pay-for-determinism",
                  "--seed",
                  "42"
                ]
              )

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The diff range the whole battery is scoped to.
--
-- __Tier 1__: @spec.md@'s own @git diff --name-only \<BASE\>...HEAD@, with the
-- three dots kept because they are the difference between \"what this branch
-- changed\" and \"what differs from that ref right now\". An absent base is
-- @main@, which is the branch both files are written against.
diffRange :: Text -> [Text]
diffRange base
  | T.null (T.strip base) = ["main...HEAD"]
  | otherwise = [T.strip base <> "...HEAD"]

-- | The prompt file the perf trials read.
--
-- __Tier 1__, and named after the rung for the reason the corpus names its own
-- two scratch roots differently (@\/tmp\/retest_weights@ against
-- @\/tmp\/retest-categorical_weights@): two batteries sharing one scratch path is
-- how a warm artefact from one run becomes a fake result in the other.
promptFile :: Tier -> Text
promptFile t = "/tmp/" <> retestName t <> "_prompt.txt"

-- | The audit fan-out: the language reviewers the file list selects, both
-- cross-cutting passes, and the comment audit.
--
-- __Tier 1__, and __the same bindings @review-deep@ and @comments@ use__. That is
-- what replaces @spec.md@ Phase 4's \"invoke @\/deep-review@ scoped to the branch
-- diff\" and Phase 5's \"invoke @comment-audit@ scoped to the diff\": in the
-- corpus those are two commands calling two other commands by name, and a
-- rubric edited in one place may or may not reach the caller. Here the roster
-- rows are @'Workflows.Rubrics.Reviewers.languageRoster'@'s and
-- @'Workflows.Review.Ladder.commentAuditLens'@, so what @retest@ audits with and
-- what @review-deep@ audits with cannot differ.
--
-- __The two cross-cutting passes never filter out__, which is
-- "Workflows.Rubrics.Reviewers"' own rule and is why the empty file list is three
-- members rather than none (house rule WR-1): a roster-shaping input must read
-- @\"\"@ as the default roster, and @'Agentic.Workflow.panelText' []@ is an
-- @error@ on a CAF.
--
-- @review-deep@'s general-purpose fall-through is deliberately not repeated here.
-- A battery is scoped to one branch whose languages the operator names in
-- @paths=@; a fall-through seat would be a second general reader over a diff that
-- already has one in @performance@.
auditRoster :: [Text] -> Roster
auditRoster files =
  languageRoster (touches files) <> crossCuttingRoster <> [commentAuditLens]

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | What the target probe is asked.
probeBrief :: Text
probeBrief =
  wfText
    [wf|
    Does this working tree have the make target this battery builds? A yes means
    the tree is the one this rung is written for. A no means it is the other
    rung's tree, and the run stops rather than building something that is not
    there.|]

-- | What the file-list receipt is introduced as.
changedBrief :: Text
changedBrief =
  wfText
    [wf|
    The files this branch changed, as bytes `git diff --name-only` wrote. This is
    a receipt: it is the evidence the derived model set is audited against, and
    nothing is added to it.|]

-- | What the diff receipt is introduced as.
--
-- /Source:/ @commands\/heavy-review.md@'s frozen-snapshot argument, which arrives
-- here for the same reason it arrives in @review-deep@: every member of the audit
-- fan-out reads this handle and only this handle, so no two of them are reading
-- different trees.
snapshotBrief :: Text
snapshotBrief =
  wfText
    [wf|
    The frozen scope snapshot for this battery's audit. Every reviewer below
    reads this and only this, so that no two of them are looking at different
    trees.|]

-- | What the derivation question is asked — the audit of the invocation.
--
-- /Source:/ @spec.md@'s \"Derive the target model set from the branch (the core
-- generality step)\" and its four signals, verbatim in substance. What changes is
-- the /direction/: in the corpus the derivation produces the set the run then
-- gates, and here the set is already argv, so the derivation is asked whether the
-- argv is the right set. See the module header's second note.
derivationBrief :: Text
derivationBrief =
  wfText
    [wf|
    Audit this run's model set against what the branch diff implies. The set is
    already fixed -- it is in the argv of the commands this run will execute, and
    it is listed below -- so your job is to say whether it is the right set, not
    to choose it.

    Map the changed paths back to models by the four signals, in order of
    specificity:

    A. `config/models.yaml` edits -- a new or changed variant names its model
       directly.
    B. `ingest/export/*_export.py` -- an arch-specific export module names its
       arch family.
    C. `h/tron/plugins/*.hpp` -- a hand-authored plugin names its model.
    D. `gen/src/tron/h/tron/plugins/*` -- build artifacts, which confirm rather
       than establish.

    Shared-infrastructure edits are SUPPORTING. They do not widen the gate to
    sibling models, and they never auto-escalate to the family or to the full
    matrix. Advancing one model always means touching shared files; that is not
    evidence about the siblings.

    Answer with:

    - the set the four signals imply, as runtime slugs;
    - for each model in the run's argv, whether the signals support it,
      contradict it, or say nothing about it;
    - for each model the signals imply and the argv omits, say so plainly -- a
      gate that skips a model the diff advances is the failure this step exists
      to catch.

    If the diff implies NO model at all -- no model-affecting change -- then make
    the first line of your answer exactly

      NO MODEL-AFFECTING CHANGES

    and say underneath which files changed and why none of them maps to a model.
    An empty or unrunnable derived set is INCOMPLETE and never a success, and
    that line is what this run reads to enforce it.|]

-- | What the build receipt is asked.
buildBrief :: Text
buildBrief =
  wfText
    [wf|
    The rebuild. A pass means exit 0 with no `error:` line; a failure carries the
    build's own first failing line, which is then the subject of the report rather
    than a paraphrase of it. If `gen/` is corrupt from a prior non-Nix `make`, that
    is what the failing line will say, and the fix is to remove it and build
    again.|]

-- | What each unit-test layer is asked.
unitBrief :: Text
unitBrief =
  wfText
    [wf|
    One layer of the unit-test sweep. All layers must pass, including the
    byte-identity MD5 baselines. Never weaken or skip a failing test: if a
    baseline legitimately changed because emitter output changed, that is a
    deliberate update with a reason, and it is not something this run may do.

    Every layer is asked, whatever the earlier ones answered. This sweep does not
    stop at the first failure.|]

-- | What each gate case is asked.
--
-- /Source:/ @spec.md@ Phase 3 and @retest-categorical.md@ Phase 3, reduced to
-- what a single process's exit code means — because that is all a verdict
-- question can carry, and the taxonomy is read from it by 'gradingBrief'.
gateBrief :: Text
gateBrief =
  wfText
    [wf|
    One case of the headline correctness gate, in its own process. A pass is a
    pass for that one (model, prompt-length) cell and for nothing else.

    What the exit code means, and the distinctions matter more here than anywhere
    else in this run:

    - exit 0 with no SKIPPED line -- PASS for this cell.
    - exit 0 with a SKIPPED line -- SKIPPED, which is INCOMPLETE and not a pass.
    - a divergence line -- DIVERGE: a real correctness regression, reported with
      the position and the match count.
    - "No tests ran" or "No test cases matched" -- NO-MATCH: a selector or runner
      fault. Report it. It is never a pass, and it is never counted as a failure
      of the model.
    - a missing weights file -- WEIGHTS-MISSING, which is INCOMPLETE.
    - a lock, a busy device, an environment-setup failure or HBM exhaustion --
      LOCK-CONTENTION: re-run this case alone before concluding anything.
    - a timeout -- TIMEOUT, which is INCOMPLETE. A cold weight cache makes a
      first run slow; that is a provisioning fact, not a correctness one.|]

-- | What the semantic check is asked.
semanticBrief :: Text
semanticBrief =
  wfText
    [wf|
    The semantic check, which complements the byte-level or logit-level gate
    above rather than replacing it. A pass here and a failure there, or the
    reverse, are different findings about different codepaths, and the report says
    which.|]

-- | What each perf trial is asked.
--
-- /Source:/ both files' fixed methodology. The three trials and the median are
-- asked for /here/ rather than encoded in the argv, and the reason is worth one
-- line: a trial is one process, and three of them is a loop over a fixed count,
-- which the operator's own runner does. What this row guarantees is that every
-- trial ran with the same flags.
perfBrief :: Text
perfBrief =
  wfText
    [wf|
    One perf and decode-token trial, on the fixed methodology: 64-token prompt,
    32-token greedy decode, temperature 0, determinism paid for, seed 42, and the
    whole machine. Do not vary any of it, or the numbers are not comparable with
    the committed baseline.

    Report gen-time in ms/tok, tok/s, wall, and the decoded token IDs. A median
    over three trials is what the gate reads; a single trial is a sample. If the
    page cache could not be dropped, say so and label wall NON-COMPARABLE -- a
    warm cache has produced a fake 18% wall "win" on this pipeline before.

    Flag any median gen-time/tok regression above 5%.

    Phase separation, because it decides who owns a bug: this is the external
    decode loop with KV cache and sampling. The gate above is the in-process
    prompt path. A divergence here with a clean gate is in the decode loop or the
    host, and not in the emitter.|]

-- | The closing line every audit member is given.
--
-- /Source:/ @spec.md@ Phase 4 (\"@\/deep-review@ scoped to the branch diff; it
-- routes reviewers by touched language and adds security + perf reviewers\") and
-- Phase 5 (\"@comment-audit@ scoped to the diff\"), which are two invocations of
-- two other commands and are one fold here.
auditClosing :: Tier -> Text
auditClosing t =
  wfText
    [wf|
    This is the review arm of the `{name}` battery. The branch under review is a
    model-support branch: it adds or fixes support for one model or one
    architecture family on an FPGA inference pipeline.

    Two things follow from that, and they are the difference between a useful
    finding here and a generic one:

    - A claim about numerical behaviour belongs to the correctness gate, which
      has already run in this same program. Do not speculate about logits. Do
      report code that could make a tolerance, a golden or a baseline mean
      something other than what it says.
    - A test weakened, skipped, quarantined without a removal condition, or
      whose baseline was updated without a stated reason is a BLOCKING finding in
      this battery, whatever it would be elsewhere. The whole run is a claim
      about correctness, and a claim resting on a test that no longer asserts
      anything is the failure mode this rung exists to prevent.

    Report your findings and nothing else. Your answer is one block of a document
    whose other blocks are your siblings', each fenced under its own name: do not
    summarise the whole, and do not address the reader of any block but your own.|]
  where
    name = retestName t

-- | What the grading question is asked, over everything the sweep produced.
--
-- /Source:/ both files' @Final report@ and @Overall verdict@ sections, and
-- @spec.md@'s claim-discipline paragraph: \"Report @PASS \/ SKIPPED \/
-- QUARANTINED \/ DIVERGE \/ NO-COVERAGE@ as distinct states — never collapse them
-- into \'N\/N PASS\'.\"
--
-- __The taxonomy is a sum type in prose, and this brief is one half of a
-- contract.__ "Workflows.Escalation"'s header says so already: nine skills in the
-- corpus name a closed set of outcomes in English and this is the clearest of
-- them. The other half is 'Workflows.Deciders.batteryRegressed' and
-- 'Workflows.Deciders.batteryIncomplete', which read the words this brief demands
-- for zero questions — the arrangement
-- @'Workflows.Panels.refusingSynthesis'@ and
-- @'Workflows.Deciders.incompleteFanOut'@ are the original of.
--
-- __The grader is not one of the sweep's engines.__ It is asked of a laterally
-- served party, because a battery graded by the model that read its own phases is
-- a battery whose claim discipline nobody applied.
gradingBrief :: Battery -> [Model] -> Text
gradingBrief b ms =
  wfText
    [wf|
    Grade this battery. You did not run any of it: below are the commands' own
    answers and the reviewers' own blocks, and your job is to classify them
    without softening anything.

    The oracle this run gated against: {oracle}

    The boundary discipline this run is held to: {boundary}

    The models in the run's argv:

    {fleet}

    Produce, in this order:

    1. One row per (model, cell) the gate reported, with its verdict word from
       this closed set and no other:

         PASS  QUARANTINED-PASS  SKIPPED  QUARANTINED-FAIL  DIVERGE
         REACHABILITY-REGRESSION  OUT-OF-SCOPE  NO-COVERAGE  NO-MATCH
         WEIGHTS-MISSING  TIMEOUT  LOCK-CONTENTION  FAIL

       Never collapse them. "N/N PASS" over a set containing a SKIPPED is a false
       statement about correctness, and it is the specific false statement this
       battery exists to make impossible.

    2. The build, the unit layers, the semantic check and the perf trials, each
       with what its command actually answered.

    3. The review findings, by severity, from the blocks below.

    4. Then the classification lines. THIS IS THE PART THAT IS READ MECHANICALLY,
       so the shape is not negotiable. For every non-passing thing, write ONE
       LINE that BEGINS with its verdict word, a colon, and what it was about:

         DIVERGE: ingested-phi-4, 64-token cell, first divergence at position 12
         NO-COVERAGE: ingested-qwen-2.5-32b, len-16384 cell is not registered
         REGRESSION: ingested-llama-3.1-8b, median gen-time/tok up 7.4%

       An OUT-OF-SCOPE cell is reported with its limit and is NOT one of these
       lines: it is neither a pass nor an incompleteness nor a regression, and a
       line beginning with a verdict word is read as one of the latter two.

    5. Last, the overall verdict, on its own final line, as one of:

         {verdict}
         INCOMPLETE
         REGRESSION

       {verdict} requires: every in-scope measured row PASS or QUARANTINED-PASS,
       no DIVERGE, no REACHABILITY-REGRESSION, no missing required coverage, no
       setup failure, no perf regression above 5%, and a clean review. Quote the
       oracle, the codepath and the prompt-set bound beside it.

       INCOMPLETE for any NO-COVERAGE, SKIPPED, WEIGHTS-MISSING, TIMEOUT,
       unresolved LOCK-CONTENTION or NO-MATCH on an in-scope cell, or an empty or
       unrunnable model set.

       REGRESSION for any DIVERGE, any in-scope REACHABILITY-REGRESSION, any perf
       regression above 5%, or any blocking review finding.

    A FAIL with a signal is triaged before it is classified: an environment or
    harness cause folds into INCOMPLETE, a confirmed fault in the pipeline folds
    into REGRESSION. Say which and why.|]
  where
    oracle = batOracle b
    boundary = batBoundary b
    verdict = batVerdict b
    fleet = fleetTable ms

-- ---------------------------------------------------------------------------
-- The provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the tree is the other rung's.
--
-- /Source:/ @commands\/retest-categorical.md@'s branch precondition, which is a
-- blockquote at the top of that file and is enforced by a reader noticing it.
wrongTreeNote :: Tier -> Text
wrongTreeNote t =
  "Outcome: WRONG TREE -- NOTHING WAS BUILT, RUN OR GATED. The make target this \
  \battery builds does not exist here, so this working tree is not the one the \
  \`"
    <> retestName t
    <> "` rung is written for. Report exactly that, name the target that was \
       \probed, and name `"
    <> retestSibling t
    <> "` as the rung for this tree. Do not characterise the branch, the models \
       \or the pipeline: nothing was measured."

-- | The arm where the sweep found a regression.
regressionNote :: Tier -> Text
regressionNote t =
  "Outcome: REGRESSION. The sweep completed and the grading found at least one \
  \divergence, reachability regression, perf regression above the 5% threshold, \
  \or blocking review finding -- the lines beginning with a verdict word name \
  \which. This is the `"
    <> retestName t
    <> "` verdict that blocks: report the failing cells first, bind every \
       \correctness claim to its oracle and its codepath, and root-cause what \
       \diverged at file:line. Do not describe a real divergence as flaky. A \
       \quarantine needs an issue link and a removal condition, and this run has \
       \neither."

-- | The arm where the run gated no model at all.
--
-- The ending both files demand and neither can have: \"an empty or unrunnable
-- derived set is classified INCOMPLETE, never a success.\" Reached from the
-- derivation's __own answer__ rather than from the grader's opinion, which is what
-- makes it structural.
noModelsNote :: Tier -> Text
noModelsNote t =
  "Outcome: INCOMPLETE -- NO MODEL-AFFECTING CHANGES. The audit of this run's \
  \model set answered that the branch diff implies no model at all, so whatever \
  \the sweep's commands returned, this run gated nothing. That is INCOMPLETE and \
  \never a success, and it is decided here from the audit's own first line rather \
  \than from any grader's summary. Report the build and the unit layers, which are \
  \real results; report the gate, the semantic check and the perf trials as having \
  \run against a set the diff does not support; and say plainly that `"
    <> retestName t
    <> "` establishes nothing about correctness on this branch. If the branch \
       \really does advance a model, the model set in the argv is wrong and the \
       \report should say which files led the audit to that conclusion."

-- | The arm where the grading came back incomplete.
incompleteNote :: Tier -> Text
incompleteNote t =
  "Outcome: INCOMPLETE. The sweep completed and at least one in-scope cell came \
  \back NO-COVERAGE, SKIPPED, WEIGHTS-MISSING, TIMEOUT, NO-MATCH or unresolved \
  \LOCK-CONTENTION -- the lines beginning with those words name which. `"
    <> retestName t
    <> "` does not pass on this branch, and it did not fail either: it did not \
       \finish. Report every incomplete cell with the reason, say what would make \
       \it runnable -- a registered test case and a golden, provisioned weights, a \
       \free card, a pre-warmed cache -- and do NOT present the cells that did \
       \pass as a result. A partial matrix folded into a pass rate is exactly the \
       \collapse the claim discipline forbids."

-- | The arm where everything ran and everything held.
correctNote :: Tier -> Text
correctNote t =
  "Outcome: "
    <> batVerdict (battery t)
    <> ". Every command in this battery ran, the sweep was exhaustive -- no phase \
       \stopped at the first failure, because none of them can -- and the grading \
       \found no divergence, no incompleteness and no regression above threshold. \
       \Report the verdict WITH ITS BOUND: name the oracle, the codepath the gate \
       \exercised, the prompt set, and the tolerance or identity criterion. A \
       \verdict quoted without those four is a stronger claim than this run \
       \supports. Then name what was NOT measured -- out-of-scope lengths with \
       \their limits, and anything the audit blocks say it could not reach."

-- ---------------------------------------------------------------------------
-- The function
-- ---------------------------------------------------------------------------

-- | What the report is written through.
retestReportBrief :: Text
retestReportBrief =
  wfText
    [wf|
    Write the consolidated report for a model-support retest. One report, whatever
    the run found: it is read by the person deciding whether this branch ships.

    Open with the provenance line you were given, verbatim, on its own line. It is
    the run's own account of what ran and what did not, and it is not yours to
    soften -- in particular, if it says nothing was gated, do not report a
    correctness result.

    Then, from the work below and nothing else:

    - the model set the run gated, as runtime slugs, and what the audit of that
      set said about it;
    - one row per (model, cell), with its verdict word from the closed set,
      never collapsed and never rounded into a pass rate;
    - the build, the unit layers, the semantic check and the perf numbers;
    - the review findings by severity;
    - the overall verdict, with the oracle, the codepath, the prompt set and the
      tolerance or identity criterion quoted beside it;
    - what was NOT measured, and what would measure it.

    Two things you must not write. Do not report a command's result that is not in
    the work below -- if it did not run, nothing follows from it. And do not
    collapse SKIPPED, QUARANTINED, NO-COVERAGE, OUT-OF-SCOPE or TIMEOUT into PASS,
    or into a fraction that hides them: they are distinct states about distinct
    kinds of ignorance, and the whole value of this battery is that it can tell
    them apart.|]

-- | One act, five provenance lines.
--
-- Three parameters, in the order the body reads them: the provenance first, for
-- "Workflows.Report"'s reason; then the grading, which is the run's own account of
-- every cell; then the audit document, so the review findings arrive as blocks
-- rather than as a summary of blocks.
retestReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
retestReportFn =
  function
    "retest.report"
    ( takes @"provenance" Text
        . takes @"grading" Text
        . takes @"audit" Text
        $ noParams
    )
    \provenance grading audit -> W.do
      act reporter [wf|
          {writing}

          Provenance:

          {provenance}

          The graded sweep:

          {grading}

          The audit blocks:

          {audit}

          Write the report, then reply DONE.|]
      done
  where
    writing = retestReportBrief

-- | The table 'retestProgram' hands @'Agentic.Workflow.defining'@.
retestTable :: [SomeFn]
retestTable = [SomeFn retestReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One probe, one exhaustive sweep, three free tests, five endings.
--
-- Four inputs. @spec@ is @skills\/retest\/references\/spec.md@ as an
-- @--input-file@ — 674 lines that are the authoritative procedure and are
-- therefore data, not prompt bulk; @base@ is the diff base ('diffRange');
-- @models@ is the model set at tier 'Hf' and is ignored at tier 'Categorical', by
-- that file's own ruling; @paths@ selects the audit's language roster in ordinary
-- Haskell.
--
-- The shape, top to bottom: probe for the rung's own build target and refuse a
-- tree that is not this rung's; then sweep — the branch's file list, the frozen
-- diff, the audit of the model set, the build, every unit layer, one gate process
-- per model, the semantic check, one perf trial per slug, and the review fan-out
-- — with __no early exit anywhere in it__; then grade the whole thing on a party
-- that ran none of it; then three free deciders and one report.
--
-- __The sweep cannot stop at the first failure, and that is not a rule.__ Each of
-- the three fan-outs is a @'Agentic.Workflow.panel'@, which asks every member and
-- folds the answers; each single command is asked at
-- @'Agentic.Workflow.Verdict'@, which survives a nonzero exit. So the only way out
-- of the body is through the bottom, and both source files' opening instruction is
-- the shape of the printed program.
--
-- __Five endings, five provenance lines, one__ 'retestReportFn' — except the
-- wrong-tree arm, which reports through @'Agentic.Workflow.ask_'@ because there is
-- no grading and no audit to hand a report function, and a call with two empty
-- arguments would be a report about nothing dressed as a report about something.
retestProgram :: Tier -> Parameterized
retestProgram t =
  taking (input "spec" :> input "base" :> input "models" :> input "paths" :> noInputs)
    \spec baseArg modelsArg pathsArg ->
      -- Tier 1, five times: the diff range, the audit roster, the model roster,
      -- the prompt file and every argv the sweep will run. All of them are
      -- ordinary Haskell over the invocation, and `wf plan --raw` prints the
      -- commands before one of them opens a card.
      let b = battery t
          files = pathsOf pathsArg
          revs = diffRange baseArg
          roster = auditRoster files
          fleet = batRoster b modelsArg
          prompt = promptFile t
          grading = gradingBrief b fleet
          -- Bound HERE and not in the `where` below, and the difference is a
          -- correctness one: the table the audit is shown must be the roster this
          -- run will actually open, which is a function of the `models` input. A
          -- `where` binding cannot see an input, so one written there would have
          -- shown the default roster to an audit of a different one.
          fleetOf = fleetTable fleet
          closing = auditClosing t
       in defining retestTable W.do
            -- The one refusal to start. `make -n` exits nonzero when the target
            -- is absent, which is what makes the branch precondition a flag
            -- rather than a paragraph.
            mine <- passes (makeTargetProbe (batTarget b)) [wf|{probing}|]

            if mine
              then W.do
                changed <- ask (gitDiffNames revs) [wf|{changing}|]

                snapshot <- ask (gitDiff revs) [wf|{snapping}|]

                -- The audit of the invocation, not the source of it.
                derived <- ask (broad (model "retest-models")) [wf|
                    {deriving_}

                    The authoritative spec for this battery:

                    {spec}

                    The models in this run's argv:

                    {fleetOf}

                    The files this branch changed:

                    {changed}|]

                built <- ask (makeBuild (batTarget b)) [wf|{building}|] `answering` Verdict

                -- Three panels, and each one is the corpus's "do not stop at the
                -- first failure" as a fold rather than as a sentence.
                units <- panel [ask p [wf|{unitting}|] | p <- batUnits b]

                gated <- panel [ask (fpgaCase (batGateBinary b) (batSelector b m)) [wf|{gating}|] | m <- fleet]

                semantic <- panel [ask p [wf|{semanticing}|] | p <- batSemantic b fleet]

                measured <- panel [ask (perfRun prompt s) [wf|{perfing}|] | m <- fleet, s <- batSlugs b m]

                audited <- panelText (zip (lensNames roster) (withEvidence roster closing snapshot changed))

                graded <- ask (lateral (model "retest-grade")) [wf|
                    {grading}

                    What the model-set audit said:

                    {derived}

                    What the build said:

                    {built}

                    What the unit layers said:

                    {units}

                    What the correctness gate said, one process per case:

                    {gated}

                    What the semantic check said:

                    {semantic}

                    What the perf trials said:

                    {measured}

                    The audit blocks:

                    {audited}|]

                -- Three free tests, in the order they dominate: a regression is
                -- the most serious thing a battery can find; a run that gated no
                -- model cannot be a success whatever the grading said; and the
                -- grading's own incompleteness is last because it is the one a
                -- grader could have got wrong in either direction.
                regressed <- tested batteryRegressed graded

                if regressed
                  then W.do
                    call_ retestReportFn (arg (regressionNote t) :> arg graded :> arg audited :> noArgs)
                    stop
                  else W.do
                    nothingGated <- tested noModelSet derived

                    if nothingGated
                      then W.do
                        call_ retestReportFn (arg (noModelsNote t) :> arg graded :> arg audited :> noArgs)
                        stop
                      else W.do
                        short <- tested batteryIncomplete graded

                        if short
                          then W.do
                            call_ retestReportFn (arg (incompleteNote t) :> arg graded :> arg audited :> noArgs)
                            stop
                          else W.do
                            call_ retestReportFn (arg (correctNote t) :> arg graded :> arg audited :> noArgs)
                            stop
              else W.do
                ask_ reporter [wf|
                    {wrongTree}

                    The target that was probed: `{target}`, in this working tree.

                    The rung that was asked for: `{name}`. The rung for this tree:
                    `{sibling}`.|]
  where
    b0 = battery t
    probing = probeBrief
    changing = changedBrief
    snapping = snapshotBrief
    deriving_ = derivationBrief
    building = buildBrief
    unitting = unitBrief
    gating = gateBrief
    semanticing = semanticBrief
    perfing = perfBrief
    wrongTree = wrongTreeNote t
    target = batTarget b0
    name = retestName t
    sibling = retestSibling t

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every command's question opens with its own brief, each
-- audit member's with its own @'Workflows.Panels.lensBrief'@ (derived from the
-- very roster the panel is built from), and the grading's with
-- @'gradingBrief'@ at this rung's battery and this rung's roster.
--
-- The table is built at the empty file list and the empty model set, which is the
-- invocation @ci\/workflows.sh@ prices and runs. At tier 'Categorical' the roster
-- is the fixed eight either way, so the grading key is exact; at tier 'Hf' a real
-- @--input-arg models=@ changes the key by changing the table spliced into it, and
-- the grading falls through to @'Agentic.Exec.scriptedDefault'@, which echoes the
-- prompt. The run still exits 0 — and it takes the incomplete arm, because an
-- echoed prompt contains this brief's own @NO-COVERAGE@ line. That is the honest
-- behaviour to have: a rehearsal whose key drifted lands on the ending that says
-- \"this did not establish anything\".
--
-- __The grading's row is the load-bearing line.__ It is written so that no line
-- begins with a verdict word and no line begins @NO MODEL-AFFECTING CHANGES@, so
-- all three free deciders say no and the scripted run walks to the success
-- terminal. The other four endings are each one line away: @(probeBrief, \"no\")@
-- reaches the wrong-tree arm, a @DIVERGE:@ line here reaches the regression arm,
-- an @INCOMPLETE@ or @NO-COVERAGE:@ line reaches the incomplete arm, and a
-- derivation row opening with @NO MODEL-AFFECTING CHANGES@ reaches the
-- nothing-gated arm. All five exit 0.
--
-- __The four command rows are @APPROVE@ and are written rather than defaulted.__
-- @'Agentic.Exec.scriptedDefault'@ answers a verdict @APPROVE@ already, but a
-- table that relies on a default cannot be edited into the failing arm in one
-- line — @'Workflows.Comments.commentsScript'@'s reason, and the same one here.
retestScript :: Tier -> [(Text, Text)]
retestScript t =
  [ (probeBrief, "yes"),
    (changedBrief, changedAnswer),
    (snapshotBrief, snapshotAnswer),
    (derivationBrief, derivedAnswer),
    (buildBrief, "APPROVE"),
    (unitBrief, "APPROVE"),
    (gateBrief, "APPROVE"),
    (semanticBrief, "APPROVE"),
    (perfBrief, "APPROVE"),
    (gradingBrief b (batRoster b ""), gradedAnswer)
  ]
    <> [(lensBrief l, findingFrom (lensName l)) | l <- auditRoster []]
  where
    b = battery t

    changedAnswer =
      "config/models.yaml\n\
      \ingest/export/llama_export.py\n\
      \h/tron/plugins/llama.hpp"

    snapshotAnswer =
      "diff --git a/ingest/export/llama_export.py b/ingest/export/llama_export.py\n\
      \@@ -41,7 +41,7 @@\n\
      \-    rope_theta = cfg.rope_theta\n\
      \+    rope_theta = cfg.rope_theta or 10000.0"

    -- Deliberately does NOT open a line with `NO MODEL-AFFECTING CHANGES`: the
    -- scripted run gates a real set, and the nothing-gated arm is reached by
    -- changing this row's first line.
    derivedAnswer =
      "Signals A, B and C all name one model, and the run's argv is that model.\n\
      \\n\
      \- signal A: config/models.yaml changed -- names the variant directly.\n\
      \- signal B: ingest/export/llama_export.py -- the llama arch export.\n\
      \- signal C: h/tron/plugins/llama.hpp -- the hand-authored plugin.\n\
      \\n\
      \Nothing in the diff implies a sibling model, and no model the signals imply \
      \is missing from the argv."

    -- No line begins with a verdict word, so all three deciders say no.
    gradedAnswer =
      "Per (model, cell): every cell reported PASS.\n\
      \\n\
      \Build: exit 0, no `error:` line. Unit layers: all layers passed, including \
      \the byte-identity MD5 baselines. Semantic check: passed. Perf: median \
      \gen-time/tok within 1.1% of the committed baseline, decoded token IDs \
      \stable.\n\
      \\n\
      \Review: no blocking finding; one MEDIUM about a comment that outlived its \
      \code.\n\
      \\n\
      \Nothing to classify: no cell reported an incompleteness, a divergence or a \
      \regression, and no cell was out of scope.\n\
      \\n\
      \"
        <> batVerdict b

    findingFrom n =
      "### [MEDIUM] a comment that outlived its code\n\
      \- **File**: ingest/export/llama_export.py#L41\n\
      \- **Category**: Documentation\n\
      \- **Confidence**: 85\n\
      \- **Problem**: the comment above the rope_theta default still describes the \
      \unconditional read.\n\
      \- **Impact**: a reader takes the default as absent.\n\
      \- **Fix**: say that the config value may be absent and that 10000.0 is the \
      \fallback.\n\
      \(reported by the "
        <> n
        <> " pass)"
