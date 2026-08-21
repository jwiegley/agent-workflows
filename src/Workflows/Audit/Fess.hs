-- |
-- Module      : Workflows.Audit.Fess
-- Description : Flagship 4 — the fess-style audit.
--
-- __What this replaces.__ One file, which @catalog.nix@ projects under two
-- names:
--
-- +----------------------------------------+-------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                | here                                      |
-- +========================================+===========================================+
-- | @agents\/fess-auditor.md@ (253 lines)   | this program: eleven stances, one         |
-- |                                        | dossier, one branch, one report function  |
-- +----------------------------------------+-------------------------------------------+
-- | the @fess@ command (same file, aliased) | the same row; one shape, one name         |
-- +----------------------------------------+-------------------------------------------+
-- | @skills\/fix-all@, @skills\/wiggum@,     | @call_ fessReportFn@ / @wf run fess@,     |
-- | @commands\/{fix,bugbot}.md@              | which ask for this audit by name today    |
-- +----------------------------------------+-------------------------------------------+
--
-- == The leveling-up, item by item
--
--   1. __Eleven categories become eleven questions.__ @fess-auditor.md@ is one
--      agent told to audit itself against eleven rubric headings in a single
--      turn, and its own most important heading — /verification gap/ — is the
--      tenth of them. One turn covering eleven categories has every incentive
--      the rubric names: one context, one budget, and the last categories read
--      last and shortest. As a 'Workflows.Panels.Roster' each stance is its own
--      question, its own addressee and its own fenced block, and \"say 'none'
--      only if you actually checked\" becomes checkable, because a block saying
--      @none@ is one addressee's statement about one category. The bill says
--      eleven.
--
--   2. __\"Quote the command and the relevant output\" stops being a demand.__
--      The file's @## What To Inspect@ list asks an agent to look at the git
--      status and the diff, and then asks it to be honest about what it saw.
--      Here both are receipts the world authored — "Agentic.Shell" runs the argv
--      with @proc@ and the bytes are not written by the model that reads them —
--      and the roster is spread over them with
--      'Workflows.Panels.withEvidence', whose own sentence (\"if a receipt and
--      your reading disagree, the receipt is what happened\") is the missing
--      half of the file's rule.
--
--   3. __The independence clause becomes a branch, and it is a downgrade rather
--      than an abort.__ @fess-auditor.md@ says: \"For a delegated independence
--      claim, the parent must name the explicit no-history mode it used and
--      provide a passing parent-history sentinel probe. If that attestation is
--      absent, run the audit but report that its independence was not
--      verified.\" That is a two-armed conditional written in Markdown, which
--      means it is a hope. Here it is a probe, a zero-question
--      'Agentic.Workflow.decide' over the probe's own answer, and a total
--      @if@ whose two arms call __one__ 'fessReportFn' with a different
--      @{provenance}@ argument — so a report that did not establish
--      independence cannot come out claiming it, and the two arms cannot drift
--      because there is one report.
--
--      __And the passing arm reports two facts, not one.__ The file's \"explicit
--      no-history mode it used\" is the half a probe cannot supply: a session
--      already carrying the work answers @PARENT_HISTORY_ABSENT@ truthfully,
--      because there is no line this run planted in it to report. The mode
--      /is/ @run.engine@ ('Agentic.Workflow.runFacts'), which the runner binds
--      and 'verifiedIndependence' quotes beside the probe's answer — so the
--      clause is now satisfied in both its halves, and by the party that knows
--      each.
--
--   4. __The audit cannot edit the tree, and now that is a type.__ Operating
--      Rule 1 is \"do not modify files\". Every stance is asked at @text@, and
--      @Agentic.Acp.permissionByCode@ grants write authority only to an
--      @'Agentic.Workflow.act'@ at @receipt@ — so a stance that wanted to edit
--      could not, whatever it was told. The rule stays in the prompt anyway,
--      because a model that knows it is not editing writes a different report.
--
--   5. __The original request reaches every stance for free.__ /Spec drift/
--      asks the auditor to \"walk the original request point by point\", which
--      requires the request. It is a program __input__, folded into the roster's
--      briefs in ordinary Haskell before the 'Agentic.Builder.Program' exists —
--      tier 1: zero questions, zero paths — so @wf plan fess --raw@ prints the
--      eleven prompts that will be sent, request included, before anything is
--      spent.
--
-- __Provenance.__ The eleven rubrics, the standing stance, the uncertainty rule
-- and the report shape are "Workflows.Rubrics.Fess", transplanted there from
-- @agents\/fess-auditor.md@; the independence text is
-- 'Workflows.Rubrics.Discipline.independenceAttestation'. Nothing in
-- @~\/src\/nix\/config\/ai@ is modified by this module, and no party in it points
-- at that tree.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Audit.Fess
  ( -- * The report every arm calls
    fessReportFn,
    fessTable,

    -- * The program
    fessAudit,
    fessDoc,
    fessScript,

    -- * The pieces the header argues about
    requesting,
    verifiedIndependence,
    fessClosing,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The dossier
-- ---------------------------------------------------------------------------

-- | What the working-tree receipt is introduced as.
--
-- /Source:/ @agents\/fess-auditor.md@ @## What To Inspect@, item 1.
worktreeBrief :: Text
worktreeBrief =
  [wft|
  The working tree, as `git status --porcelain` reports it: every path with an
  uncommitted change, staged or not, and every untracked file.|]

-- | What the change receipt is introduced as.
--
-- /Source:/ @agents\/fess-auditor.md@ @## What To Inspect@, items 1 and 2.
changesBrief :: Text
changesBrief =
  [wft|
  The change under audit, as `git diff` reports it against the base this run was
  given. This is the diff, not a description of one.|]

-- | What the history receipt is introduced as.
historyBrief :: Text
historyBrief =
  [wft|
  The commits under audit, oldest first, as `git log` reports them against the
  base this run was given.|]

-- $dossier
--
-- __The three receipts, and why they are safe to ask at @text@.__ @git status@,
-- @git diff@ and @git log@ exit @0@ whether they have anything to say or not, so
-- each is a text question whose answer is bytes. They are asked inline in
-- 'fessAudit' rather than assembled into a table first, because the names the
-- report accounts for and the questions that produce them must not be two lists
-- that can disagree.
--
-- __What is deliberately not among them.__ The test suite. @fess-auditor.md@'s
-- @## What To Inspect@ names \"tests, lint, type checks, or other verification
-- commands the main agent claims to have run\", and the obvious move is to run
-- them. It is the wrong move for this program: "Agentic.Shell" abandons a
-- @text@ ask on a nonzero exit, so a red suite would end the audit — and an
-- audit that only runs on a green tree is an audit of the wrong trees. The
-- shape that /does/ fit is a verdict or a flag, which is exactly what
-- "Workflows.Gates" gives the fixers; here the suite's result arrives as part of
-- the caller's request (the claims the auditor is asked to check), and the
-- /verification gap/ stance's own brief already says what to do with a claim
-- nothing proves.

-- | The base the two ranged receipts measure against.
--
-- An absent input becomes @HEAD@, which makes @git diff HEAD@ and
-- @git log HEAD..HEAD@ the uncommitted-work audit — the case
-- @fess-auditor.md@ is written for, since it is invoked at the end of a turn.
auditBase :: Text -> Text
auditBase b
  | T.null (T.strip b) = "HEAD"
  | otherwise = T.strip b

-- ---------------------------------------------------------------------------
-- The roster, carrying the request
-- ---------------------------------------------------------------------------

-- | The closing line every stance is given.
--
-- 'Workflows.Panels.documentPanel' has one of these and this program cannot use
-- it: a fan-out over a dossier is 'Workflows.Panels.withEvidence', which takes
-- its closing as an argument precisely so a caller can say what its own document
-- is for.
fessClosing :: Text
fessClosing =
  [wft|
  Report the hits in your category and nothing else. Your answer is one block
  of a document whose other blocks are the other categories' -- do not
  summarise the whole audit, do not repeat another category's findings, and do
  not address the reader of any block but your own.

  Cite file:line for every finding grounded in the tree. Say `none` only for
  what you actually checked.|]

-- | The roster with the original request folded into every stance's brief.
--
-- __Tier 1__: the request is in the invocation, so this is ordinary Haskell over
-- ordinary 'Data.Text.Text', applied before the 'Agentic.Builder.Program'
-- exists. It costs zero questions and zero paths, and it is why
-- @wf plan fess --raw@ can print the eleven prompts that will be sent.
--
-- The request is given to __all eleven__ and not only to /spec drift/, because
-- every category in @fess-auditor.md@ is stated relative to what was asked for:
-- /scope creep/ is the same test read backwards, and /verification gap/ is about
-- the claims the request was answered with.
requesting :: Text -> Roster -> Roster
requesting request r
  | T.null (T.strip request) = r
  | otherwise = [l {lensBrief = lensBrief l <> "\n\n" <> header <> "\n\n" <> request} | l <- r]
  where
    header =
      [wft|
      The original request this work was done in answer to, verbatim. Every
      category below is stated relative to it.|]

-- ---------------------------------------------------------------------------
-- The report both arms call
-- ---------------------------------------------------------------------------

-- | The provenance line the attested arm passes: __two facts, and no word that
-- goes beyond them__.
--
-- The counterpart of 'Workflows.Rubrics.Discipline.unverifiedIndependence',
-- which the foundation carries because it is the arm the corpus asks for by
-- name. A pair of provenance notes is the unit — a report that may say either
-- and a program that can only say one is a report that says the wrong thing
-- half the time.
--
-- __Why it is a function of the engine now.__ It used to open \"this audit's
-- independence WAS verified\" and close \"they were not read out of the
-- conversation that produced the work\", and the second sentence was a claim the
-- probe cannot support: a session already carrying the work answers
-- @PARENT_HISTORY_ABSENT@ truthfully, because there is no planted sentinel in it
-- to report (see 'Workflows.Rubrics.Discipline.independenceAttestation'). The
-- probe establishes that no context /this runner/ planted was inherited; the
-- engine's session policy establishes whether the answerer shares a conversation
-- with anything else. Two facts, so two sentences, and the reader is given the
-- second rather than being left to assume it.
--
-- The engine fact is quoted rather than classified, because @fess@ __downgrades
-- and does not abort__: an audit that ran in one shared session is still an
-- audit and its findings are still findings, and what the reader needs is to
-- know which kind of confirmation they are holding. The row that turns the same
-- fact into a refusal is @wiggum@, where a separate evaluator is a clause of the
-- definition of done rather than a quality of the report.
verifiedIndependence :: Text -> Text
verifiedIndependence engine =
  [wft|
  Provenance, and it is two facts rather than one. First: a parent-history
  sentinel probe was put to the answering runner before any stance was asked,
  and it answered that no line this run planted was already in its context. So
  no context this runner itself introduced was inherited. Second, from the
  runner and not from any party asked below, this run's engine and its session
  policy: {engine}.

  Read them together and say so in the summary. The probe tests one line and
  cannot see any other prior context, so under an engine that puts every
  question of the run into one shared conversation a finding below may still
  have been reached by a party that had read the work -- and under an engine
  that opens a new session per question it cannot have been. Do not describe
  any finding as independently reached unless both facts support it.|]

-- | The five fixed report sections, and the provenance the arms differ in.
--
-- Three parameters in the order the body reads them. @provenance@ is last
-- because it is the argument the two arms of the @if@ differ in and the reader
-- of the call site should meet it last, where the difference is; it is
-- /first/ in the prompt, because it is the thing a report must not omit.
fessReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
fessReportFn =
  function
    "fess.report"
    ( takes @"findings" Text
        . takes @"evidence" Text
        . takes @"provenance" Text
        $ noParams
    )
    \findings evidence provenance -> W.do
      act reporter [wf|
          {fessReportBrief}

          {provenance}

          {operatingRules}

          The receipts this audit was given, which are bytes produced by running
          the commands named in them:

          {evidence}

          The eleven categories' findings, each fenced under its own name:

          {findings}

          Write the report, then reply DONE.|]
      done

-- | The table 'fessAudit' hands @'Agentic.Workflow.defining'@.
fessTable :: [SomeFn]
fessTable = [SomeFn fessReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The audit: three receipts, one sentinel probe, eleven stances, one
-- report, two provenances.
--
-- Two inputs the operator gives. @request@ is the original request or plan the
-- work answers — see 'requesting'; @base@ is the revision the diff and the log
-- are measured against, defaulting to @HEAD@ (the uncommitted-work case the file
-- is written for).
--
-- And two the __runner__ gives, which are the two halves of one claim.
-- @run.sentinel@ ('Agentic.Workflow.runFactSentinel') is the line this run
-- generated for itself, and it is what turns the probe below from a premise
-- nobody established into a question only an answerer that has seen the line can
-- answer — the whole of @doc\/followups.md@'s @M5@, which observed that this
-- audit downgraded its own provenance on the strength of a sentinel nothing
-- planted. @run.engine@ is the other half: the probe finds planted context and
-- cannot see any other, so what settles whether a stance had already read the
-- work is the engine's session policy, and 'verifiedIndependence' states it
-- beside the probe's answer instead of letting a passing probe stand for both.
--
-- Both are spliced and neither is branched on: this row __downgrades__ and does
-- not refuse, so the price is unchanged and every fold below is the fold it
-- always was.
--
-- __Where the price comes from.__ Three receipts, one probe, eleven stances, one
-- report — and the branch adds a path without adding a question, because
-- 'Agentic.Workflow.decide' asks nobody. That is the whole bill, and
-- @wf cost fess@ prints it before the first token, which is the thing no
-- Markdown file in the corpus can do for an audit that fans out eleven ways.
fessAudit :: Parameterized
fessAudit =
  taking
    ( input "request"
        :> input "base"
        :> input "run.engine"
        :> input "run.sentinel"
        :> noInputs
    )
    \request base engine sentinel ->
      let roster = requesting request fessRoster
          attestation = independenceAttestation sentinel
          -- Tier 1, and free in both folds: an input is a define, so the engine
          -- fact reaching a provenance line adds no question and no path. It is
          -- not branched on here -- this row downgrades and does not refuse --
          -- so the price is the price it always was.
          passingProvenance = verifiedIndependence engine
       in defining fessTable W.do
            -- The change under audit, as bytes. This is the artefact every
            -- stance reads; the file can only ask an agent to go and look at it.
            changes <- ask (gitDiff [auditBase base]) [wf|{changesBrief}|]

            -- The surrounding receipts, folded into one fenced document under
            -- the names the report will account for.
            evidence <-
              panelText
                [ ("worktree", ask gitStatus [wf|{worktreeBrief}|]),
                  ("history", ask (gitLogSeries (auditBase base)) [wf|{historyBrief}|])
                ]

            -- The sentinel protocol, put to the runner rather than assumed of
            -- it. One question, and then a decider that costs nothing.
            probe <- ask (broad (model "independence")) [wf|{attestation}|]
            attested <- tested historyAbsent probe

            -- Eleven stances, three serving rungs, one fenced document.
            findings <- panelText (zip (lensNames roster) (withEvidence roster fessClosing changes evidence))

            -- The downgrade, not the abort: two arms, one callee, one argument
            -- apart. This is `agents/fess-auditor.md`'s own sentence, made
            -- structural.
            if attested
              then W.do
                call_ fessReportFn (arg findings :> arg evidence :> arg passingProvenance :> noArgs)
                stop
              else W.do
                call_ fessReportFn (arg findings :> arg evidence :> arg unverifiedIndependence :> noArgs)
                stop

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
fessDoc :: Text
fessDoc =
  "fess-auditor.md: eleven sin categories as eleven independent stances over three receipts"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves.__ Each stance's prompt opens with its
-- own 'Workflows.Panels.lensBrief', which is
-- @'Workflows.Rubrics.Fess.fessStance' \<\> its rubric \<\> the uncertainty
-- rule@ — so the shared opening is a prefix of all eleven and __one entry
-- answers the whole panel__. There are no per-category replies below and none
-- are needed: a scripted run is evidence about the program's shape, not about
-- any rubric's judgement, and \"none -- checked\" is a well-formed answer to
-- every one of the eleven. The other four entries are the three receipts and
-- the probe.
--
-- The probe's entry is the load-bearing one: it is what makes the scripted run
-- take the __attested__ arm, so a green @wf run fess --scripted@ is evidence
-- about the arm that reports independence rather than the one that reports its
-- absence. Flip it to anything else and the other arm runs — which is how the
-- branch is exercised without an engine.
fessScript :: [(Text, Text)]
fessScript =
  [ (independenceAttestationKey, "PARENT_HISTORY_ABSENT"),
    (worktreeBrief, " M src/token.rs\n M tests/token.rs\n?? notes.txt"),
    (changesBrief, scriptedDiff),
    (historyBrief, "a1b2c3d Extract token validation into a module"),
    (fessStance, "none -- checked, and this category has no hits in the diff above.")
  ]
  where
    -- fixture bytes, not prose: a unified diff, trailing newline and all. The
    -- fence carries the exact bytes; the trailing newline is spliced, because a
    -- fence never ends in one.
    scriptedDiff =
      [wft|
      --- a/src/token.rs
      +++ b/src/token.rs
      @@
      -    validate(tok)?
      +    let _ = validate(tok); // TODO: handle|]
        <> "\n"
