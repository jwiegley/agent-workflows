-- |
-- Module      : Workflows.Nix
-- Description : The NixOS host — three symptoms, one diagnosis-and-verify spine,
--               and a safety policy that is an absence rather than a paragraph.
--
-- == The map: old Markdown -> new program
--
-- +-------------------------------------+--------------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@           | here                                                               |
-- +=====================================+====================================================================+
-- | @commands\/nix-rebuild.md@          | @nix-rebuild@ — the host's own build driver as the receipt whose    |
-- |                                     | bytes are then the subject of the diagnosis                        |
-- +-------------------------------------+--------------------------------------------------------------------+
-- | @commands\/fix-alert.md@            | @nix-alert@ — __reworked__: @caveman@ is dropped from the           |
-- |                                     | diagnostic path, and the alert's own labels route the run in        |
-- |                                     | ordinary Haskell. See the rework note                              |
-- +-------------------------------------+--------------------------------------------------------------------+
-- | @commands\/fix-integration.md@      | @nix-integration@ — its hard-coded error string becomes an input    |
-- |                                     | whose /default/ carries today's text ('failureText')                |
-- +-------------------------------------+--------------------------------------------------------------------+
-- | @skills\/nixos\/SKILL.md@           | @'Workflows.Evidence.nixosBuild'@ and 'hostFlags' — and three       |
-- |                                     | prohibitions discharged as absences, not as prompt text            |
-- +-------------------------------------+--------------------------------------------------------------------+
-- | @agents\/nix-pro.md@ @## Search     | 'searchStrategy', and its closing rule as the gate                  |
-- | Strategy@                           | ('Workflows.Parties.nixPro' is the addressee)                       |
-- +-------------------------------------+--------------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __The failing build is a receipt, and that is the whole of the row.__
--      @nix-rebuild.md@ is one sentence — \"I cannot rebuild the current Nix
--      system using @.\/build system@. Use nix-pro to diagnose and resolve the
--      issue.\" — and @doc\/design.md@ §7.2 row 36 calls it the archetypal
--      receipt for a reason: the rework B named is that /the failure text is
--      missing/, and a program cannot diagnose a build it has not seen. Here the
--      driver is run and its own first failing line is what the diagnosis is
--      handed. Nobody has to paste anything and nobody has to remember what it
--      said.
--
--   2. __One build, three arms.__ The driver is run __once__ per run, and its
--      verdict's own three tags are what separate the endings:
--      @'Agentic.Workflow.caseVerdict'@'s approving arm is \"nothing to
--      diagnose\", its objecting arm carries the failing line into the diagnosis,
--      and its declining arm is 'driverSilentNote'. On the parked machine a second
--      build is hours, so a design that asked the same command once for its exit
--      code and once for its words would have cost the operator an afternoon to
--      buy a branch the language already gives away.
--
--   3. __A failing command is asked at @verdict@, deliberately.__ This is the
--      mechanical fact the row turns on. "Agentic.Shell" abandons a @text@ ask on
--      a nonzero exit — which is right, and which would make \"read the failing
--      build's output\" unwritable — but a @verdict@ question on the same party
--      __objects with the command's own first failing line__, and a verdict
--      interpolates into a prompt. So the receipt this program most needs is
--      exactly the one the transport was already shaped to give.
--
--   4. __The VPS flags are program-authored.__ @skills\/nixos\/SKILL.md@ says
--      \"on VPS, pass @--max-jobs 1 --cores 1@ to every @.\/build build@ and
--      @.\/build switch@\", which is a sentence one host out of several needs and
--      a model has to remember. 'hostFlags' decides it in ordinary Haskell from
--      the @host@ input — __tier 1__, zero questions and zero paths — and the
--      flags are in the printed argv, so @wf plan --raw@ shows which machine the
--      run is priced for.
--
--   5. __The three prohibitions are absences.__ Also from that skill: never
--      decrypt the SOPS secrets file; never create, remove or seize the
--      @.nixos-build@ lock; run builds through the host's own driver. There is no
--      @sops@ argv in "Workflows.Evidence", no @rm@ and no @touch@, and the only
--      build command in this module is the driver — so all three are not rules a
--      run is trusted with, they are commands that do not exist. @doc\/design.md@
--      §7.4 row 26 rules that this policy \"rides on the argv and on the
--      question's addressee, never in prompt text\", and __no prompt in this
--      module states any of the three__. That is the ruling honoured rather than
--      described.
--
--   6. __\"If the driver cannot acquire its lock, report its error and stop\" is
--      the transport's own behaviour.__ A missing or wedged command is a
--      @GapTransportRefusal@ — a /gap/, not an answer — and the run ends saying
--      the gate did not run rather than that it said no. The skill asks for
--      exactly that distinction and Markdown has no way to make it.
--
--   7. __\"Never assume an option exists without verification\" is the gate.__
--      @agents\/nix-pro.md@'s Search Strategy ends on that sentence and on \"test
--      all configurations thoroughly before deployment\". A NixOS option that does
--      not exist is a build error, so the verification is the host's own driver
--      run again after the repair — @'Workflows.Gates.gate'@, whose objection is
--      the driver's own failing line and whose exhaustion is an ending the run
--      reports rather than a loop that keeps going.
--
-- == The rework, discharged
--
-- @doc\/design.md@ §7.1 row 15 marks @fix-alert@ __R__ and names the defect:
-- \"naming @caveman@ beside a diagnostic skill compresses the very alert text
-- whose details decide the diagnosis. Drop it from the diagnostic path, or make
-- compression an earlier question with its own handle.\"
--
-- __It is dropped.__ @'Workflows.Prose.Polish.compressProgram'@ exists and this
-- module does not call it: an Alertmanager payload's value is in its label set,
-- its threshold and its timestamps, and those are precisely what a compressor
-- sheds. The alert arrives as a @{hole}@ — data, spliced whole, never fused with
-- the sentence beside it — and the /routing/ that the compression was presumably
-- meant to make cheap is free instead: 'severityOf' reads the payload's own
-- @severity=@ label in ordinary Haskell, before the program exists.
--
-- The second option §7.1 offers — compression as an earlier question with its own
-- handle — is not taken either, and the reason is a price: it is one more
-- question on every path to buy a shorter prompt, and a prompt's length is not
-- what this row is short of.
--
-- == Two honest notes
--
-- __The @cd@ is gone, because a @cd@ is shell.__ The skill's own example is
-- @cd \/etc\/nixos && .\/build switch@, and "Agentic.Shell" runs an argv with
-- @proc@ in the run's own working directory. So the requirement moves out of the
-- command and into where the run is started, and
-- @'Workflows.Evidence.nixosBuild'@'s haddock says so. A run started elsewhere
-- gets a @GapTransportRefusal@ on the first receipt — the driver is not there —
-- which is the loud failure and not a quiet one.
--
-- __@.\/build build@ and not @.\/build switch@, on every rung.__ @nix-rebuild.md@
-- names @.\/build system@ and the skill's example names @switch@. A @switch@
-- activates a configuration on the machine the run is on, and none of the three
-- rungs here has established that the configuration is right — that is what the
-- diagnosis and the gate are for. So the argv this module authors is @build@,
-- which is the same evidence at no risk, and the activation is left to the
-- operator with a working build in hand. The subcommand is one argument in a
-- printed program, and this paragraph is why it is that one.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Nix
  ( -- * The three rungs
    NixRung (..),
    nixName,
    nixDoc,

    -- * The programs
    nixProgram,
    nixScript,

    -- * The rubrics, transplanted
    searchStrategy,

    -- * The tier-1 readings of an invocation
    hostFlags,
    hostNote,
    severityOf,
    alertRouting,
    failureText,
    symptomOf,

    -- * The report both endings call
    nixReportFn,
    nixTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The three rungs
-- ---------------------------------------------------------------------------

-- | Three of the owner's commands over one diagnosis-and-verify spine.
--
-- What differs between them is __what the symptom is__: a receipt the program
-- ran, a payload somebody was paged by, or an error message an operator pasted.
-- What does not differ is everything after it, which is why this is one module
-- and three rows rather than three programs.
data NixRung
  = -- | @commands\/nix-rebuild.md@ — the system will not build.
    Rebuild
  | -- | @commands\/fix-alert.md@ — Alertmanager is paging.
    Alert
  | -- | @commands\/fix-integration.md@ — a Home Assistant integration will not
    -- load.
    Integration

-- | The name the operator types, and the name "Workflows.Registry" registers.
--
-- Family first, the owner's own word as the suffix. There is no bare @nix@ row:
-- this family has no default rung, because the three differ in /what went wrong/
-- and not in how much is spent finding out — and a bare name would have to pick
-- one symptom to be the ordinary case.
nixName :: NixRung -> Text
nixName Rebuild = "nix-rebuild"
nixName Alert = "nix-alert"
nixName Integration = "nix-integration"

-- | The one line @wf list@ prints beside each rung.
nixDoc :: NixRung -> Text
nixDoc Rebuild =
  "nix-rebuild.md: the host's own build driver as the receipt, then diagnose, repair and verify"
nixDoc Alert =
  "fix-alert.md: the alert routed by its own labels for free, and diagnosed whole rather than compressed"
nixDoc Integration =
  "fix-integration.md: the failing output as an input whose default carries the error the file hard-codes"

-- ---------------------------------------------------------------------------
-- The one party that is this program's own
-- ---------------------------------------------------------------------------

-- | The party that edits the configuration.
--
-- A @tool@ with __no__ argv, for 'Workflows.Checklist.worker'\''s reason: which
-- Nix files a repair touches is whatever the diagnosis says, and an
-- @'Agentic.Workflow.act'@ at @'Agentic.Raw.CodeAck'@ is the only kind of answer
-- the ACP transport grants write authority to. Everything this module /can/ name
-- as an argv is in "Workflows.Evidence", and the three things it deliberately
-- cannot are in the module header.
configurer :: Party 'IsTool
configurer = tool "nix-edit"

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | The flags every build on this host must carry.
--
-- /Source:/ @skills\/nixos\/SKILL.md@'s last bullet: \"VPS is parked and must be
-- selected explicitly for maintenance. On VPS, pass @--max-jobs 1 --cores 1@ to
-- every @.\/build build@ and @.\/build switch@ invocation.\"
--
-- __Tier 1__ ("Workflows.Deciders"): which host a run is against is in the
-- invocation, so this is ordinary Haskell over ordinary 'Data.Text.Text' and
-- costs zero questions and zero paths. The flags land in the argv, so
-- @wf plan nix-rebuild --input-arg host=vps --raw@ prints them and an operator can
-- see before spending that this run is priced for the parked machine.
--
-- The match is on the host /name/ and is deliberately loose: @vps@, @VPS@ and a
-- fully qualified name containing it all select the constrained build, because the
-- failure mode worth avoiding is an unconstrained build on the small machine and
-- not a constrained one on the large.
hostFlags :: Text -> [Text]
hostFlags h
  | "vps" `T.isInfixOf` T.toLower (T.strip h) = ["--max-jobs", "1", "--cores", "1"]
  | otherwise = []

-- | What the diagnosis is told about where it is working.
--
-- __Tier 1__, and the sentence differs because the constraint does: on the parked
-- machine a repair that needs a large build is a repair that will not finish, and
-- that is worth saying to whoever is proposing one.
hostNote :: Text -> Text
hostNote h
  | null (hostFlags h) =
      "Host: "
        <> shown
        <> ". Builds here are unconstrained."
  | otherwise =
      "Host: "
        <> shown
        <> ". This machine is parked and is built with `--max-jobs 1 --cores 1`, \
           \which is already in the command this run uses. A fix that requires a \
           \large rebuild will take hours here: say so if you propose one, and \
           \prefer a change that builds narrowly."
  where
    shown
      | T.null (T.strip h) = "not named, so the unconstrained default"
      | otherwise = T.strip h

-- | The alert's own severity, read off its label set.
--
-- /Source:/ @commands\/fix-alert.md@ — \"I'm receiving the following alert from
-- Alertmanager\" — read against Alertmanager's own payload shape, where the
-- labels are @name=value@ lines and @severity@ is the one that decides how a page
-- is handled.
--
-- __Tier 1, where @doc\/design.md@ §7.1 row 15 says tier 2__, and this is the one
-- deviation this module makes from the design. That row reads \"the labels route
-- by @anyLineStartsWith@ at zero cost\", which is a
-- @'Agentic.Workflow.decide'@ — zero questions and __one path__. But a decider
-- reads a /handle/, and the alert here is an /input/: a define, available to
-- ordinary Haskell before the @Program@ is built. So the same routing is free of
-- paths as well as of questions, and "Workflows.Deciders"' own house rule —
-- decide as early as possible, and tier 1 is the earliest — is what settles it.
-- The design's mechanism was right for an alert that arrived as a receipt; this
-- one arrives in the invocation.
severityOf :: Text -> Text
severityOf alert = case [v | l <- T.lines alert, Just v <- [labelled l]] of
  (v : _) -> v
  [] -> "unlabelled"
  where
    labelled l =
      let t = T.strip l
       in case T.stripPrefix "severity=" (T.toLower t) of
            Just v -> Just (clean v)
            Nothing -> case T.stripPrefix "severity:" (T.toLower t) of
              Just v -> Just (clean v)
              Nothing -> Nothing

    clean = T.takeWhile (\c -> c /= ',' && c /= ' ' && c /= '"') . T.dropWhile (== '"') . T.strip

-- | What the diagnosis is told about how urgently this alert is being handled.
--
-- __Tier 1__, derived from 'severityOf'. The routing is what the corpus's
-- compression step was presumably meant to make affordable, and here it is free —
-- so the alert itself is spliced whole. See the rework note in the module header.
alertRouting :: Text -> Text
alertRouting alert = case severityOf alert of
  "critical" ->
    "This alert is labelled severity=critical. Something is down or is about to \
    \be, so the first question is containment and not elegance: name the \
    \smallest change that stops the page, say what it costs, and only then the \
    \correct fix. If the two are different, say both and say which you \
    \recommend now."
  "warning" ->
    "This alert is labelled severity=warning. Nothing is down. Diagnose the \
    \cause properly rather than silencing the symptom, and if the honest answer \
    \is that the threshold is wrong, say that -- a warning that fires every day \
    \is a warning nobody reads, and moving it is a real fix."
  "info" ->
    "This alert is labelled severity=info. Treat it as a report and not as a \
    \page: say what it indicates, whether it needs any action at all, and what \
    \would have to change for it to become a warning."
  s ->
    "This alert carries no severity label this run could read (it read `"
      <> s
      <> "`). Do not assume it is urgent and do not assume it is not: say which \
         \it is from the payload's own contents, and say that the label was \
         \missing -- an unlabelled alert is itself a defect in whoever emits it."

-- | The failing output, with the corpus's own sample as the default.
--
-- /Source:/ @commands\/fix-integration.md@, which hard-codes exactly one error
-- inside an @\<output\>@ block:
--
-- > Config flow could not be loaded: {"message":"Invalid handler specified"}
--
-- __Tier 1__, and it is @doc\/design.md@ §7.1 row 18's ruling made literal: \"the
-- hardcoded error string becomes a second input whose sample carries today's
-- text, so it generalises without losing its default.\" An operator with a
-- different failure passes it; an operator with /this/ failure passes nothing and
-- gets the file's own behaviour.
failureText :: Text -> Text
failureText t
  | T.null (T.strip t) =
      "Config flow could not be loaded: {\"message\":\"Invalid handler specified\"}\n\
      \\n\
      \(No output was given to this run, so this is the error \
      \`fix-integration.md` carries as its own example. If the failure on the \
      \host is a different one, the diagnosis below is about the wrong thing: \
      \say so.)"
  | otherwise = T.strip t

-- | The symptom a non-@Rebuild@ rung diagnoses, assembled in Haskell.
--
-- __Tier 1__, and it is the whole of what separates two of the three rows: the
-- alert rung's symptom is a payload plus its routing, and the integration rung's
-- is a component name plus a failing output. Neither costs a question, and the two
-- rows therefore price identically — which is the correct outcome and is what
-- @stack@ against @stack-rebase@ already demonstrates in @ci\/workflows.sh@.
symptomOf :: NixRung -> Text -> Text -> Text
symptomOf Alert subject output =
  "An Alertmanager alert is firing on this host.\n\n"
    <> alertRouting subject
    <> "\n\nThe alert, exactly as it was received and NOT compressed:\n\n"
    <> spelled subject
    <> "\n\nAnything further the operator added:\n\n"
    <> spelled output
symptomOf Integration subject output =
  "A Home Assistant integration will not load on this host.\n\nThe integration: "
    <> spelled subject
    <> "\n\nWhat it is showing:\n\n"
    <> failureText output
symptomOf Rebuild subject output =
  -- Unreachable from `nixProgram`, which binds a receipt for this rung rather
  -- than assembling a define — but written, because a total function is one
  -- fewer thing for a later reader to check.
  "The system will not build on this host.\n\nWhat the operator was doing: "
    <> spelled subject
    <> "\n\nAnything further:\n\n"
    <> spelled output

-- | An input, or a sentence saying it was not given.
--
-- Every input in this module may be empty, and an empty splice reads as an
-- omission the answering party cannot tell from a blank. This is one line and it
-- is the difference.
spelled :: Text -> Text
spelled t
  | T.null (T.strip t) = "(not given)"
  | otherwise = T.strip t

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | @agents\/nix-pro.md@'s @## Search Strategy@, in order, with its closing two
-- sentences.
--
-- /Source:/ its five numbered steps verbatim, plus \"always validate option
-- existence before use. Never assume option exists without verification.\" and
-- \"test all configurations thoroughly before deployment.\"
--
-- The closing rules are carried as /rules about what to say/ and not as promises,
-- because what actually verifies them here is the gate: an option that does not
-- exist is a build error, and @'Workflows.Evidence.nixosBuild'@ is run again after
-- the repair. @doc\/design.md@ §7.3 calls this \"a @revisingOn@ over a
-- verification verdict — a small @Fn@ inside @nix@\"; it is a
-- @'Workflows.Gates.gate'@ rather than a @revisingOn@, for the reason
-- "Workflows.Escalation" states in its own header — with an exec review
-- @AbandonedOn@ is unreachable, so the two-way loop is the honest one and the
-- three-way loop would buy an arm nothing can take.
searchStrategy :: Text
searchStrategy =
  wfText
    [wf|
    Resolve this the way the operator's own NixOS practice does, in this order:

    1. First, `nix search nixpkgs` -- or search.nixos.org -- for an existing
       package or option.
    2. Second, the Home Manager manual's options, for anything user-scoped.
    3. Third, flakes, via search.nixos.org/flakes or FlakeHub.
    4. Fourth, community solutions and examples, by live search where you have
       one.
    5. Fifth, the nixpkgs repository itself, for a similar implementation.

    Validate that every option you name actually exists before you propose it,
    and say how you validated it. Never assume an option exists: a plausible
    option name is the most expensive mistake in this domain, because it looks
    exactly like a correct one until a build fails minutes later. Where you could
    not verify one, say so beside it rather than presenting the whole proposal at
    one confidence.

    Say which of the five steps produced each part of your answer. A step you
    could not take -- because this run has no live search, for instance -- is
    worth naming: it tells the reader what the diagnosis did not see.|]

-- ---------------------------------------------------------------------------
-- The prompts
-- ---------------------------------------------------------------------------

-- | What the one build every rung runs is asked.
--
-- /Source:/ @commands\/nix-rebuild.md@, whose whole content is that this command
-- fails, and @skills\/nixos\/SKILL.md@'s \"run builds and switches through the
-- host's build driver\". Asked at @verdict@, which is the module header's item 3:
-- exit @0@ approves and a nonzero exit objects with the driver's own first
-- failing line.
--
-- __One receipt, three rungs, two meanings.__ At @Rebuild@ a pass means there is
-- nothing to diagnose; at the other two a pass is the expected baseline and a
-- /failure/ means the configuration was already broken before this run touched
-- anything — which is the distinction @'Workflows.DeadCode.deadCodeProgram'@'s
-- red-baseline gate makes for the same reason, and which decides whether a later
-- failure is attributable to this run's own edit.
buildBrief :: Text
buildBrief =
  wfText
    [wf|
    The host's own build driver, run before anything is diagnosed or changed.
    This is the baseline: the same command is run again after the repair, so its
    verdict here is what makes the later one attributable.|]

-- | What the diagnosis is asked.
--
-- /Source:/ the three commands' shared instruction — @nix-rebuild.md@'s \"use
-- nix-pro to diagnose and resolve the issue\", @fix-alert.md@'s \"diagnose and
-- resolve it\", @fix-integration.md@'s \"help resolve this issue\" — and
-- @skills\/nixos\/SKILL.md@'s \"use sequential-thinking when appropriate to break
-- down tasks further\", which is a request for a structured answer and is asked
-- for as one.
diagnoseBrief :: Text
diagnoseBrief =
  wfText
    [wf|
    Diagnose this and propose the repair. Answer with the diagnosis and the
    repair plan, and nothing else: a later step applies it and a later step still
    verifies it, so what you write is read as instructions and not as a
    discussion.

    Work in this order, and break the problem down further wherever a step is
    doing more than one thing:

    1. What the evidence actually says. Quote the line that matters. Distinguish
       what the evidence shows from what you infer from it.
    2. The cause, named as a specific thing in a specific file, or named as
       unknown. "Probably a version mismatch" is not a cause; a module option
       that changed name between releases is.
    3. The repair, as an edit: which file, which attribute, what it becomes.
       Where a repair has a cheap containment and a correct fix, give both and
       say which is which.
    4. What would show the repair worked, beyond the build passing. The build is
       run again after the repair whatever you say here, so this is about
       behaviour: a service that answers, a unit that stays up, a metric that
       returns.
    5. What you did NOT establish. This is the part a report is written from and
       the part a tired diagnosis leaves out.|]

-- | What the repair act is told.
repairPlanBrief :: Text
repairPlanBrief =
  wfText
    [wf|
    Apply the repair the diagnosis below describes, and only that.

    Edit the configuration the plan names. Do not reformat the files you are in,
    do not fix an unrelated thing you notice, and do not widen the change to
    cover a case the diagnosis did not establish -- the build after this turn is
    the evidence that the change worked, and a change that did three things
    cannot be attributed by it.

    Where the plan gave both a containment and a correct fix, apply the correct
    fix unless the plan said the containment must come first.

    Do not activate anything. The next step builds; activation is the operator's,
    with a working build in hand.

    When you are done, reply DONE with one line per file changed.|]

-- ---------------------------------------------------------------------------
-- The three provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the build was green before anything was diagnosed.
--
-- Only the @Rebuild@ rung can reach it, and it is worth having: a run started
-- against a host that has since been fixed should cost one receipt and say so,
-- not diagnose a failure that is no longer there.
nothingWrongNote :: Text
nothingWrongNote =
  "Outcome: NOTHING TO DIAGNOSE. The host's own build driver was run first and it \
  \passed, so the system builds and nothing was diagnosed, repaired or verified -- \
  \the run cost one receipt. Report that, name the command that was run and the \
  \host it was run for, and say that if a failure was seen earlier then something \
  \changed in between: the tree, the channel, or the machine."

-- | The arm where the configuration was already broken before this run started.
--
-- Reachable at @Alert@ and @Integration@ only, and it is the arm that keeps the
-- verification honest: a repair applied on top of an already-failing
-- configuration cannot be verified by a build, because the build was going to fail
-- either way. @'Workflows.DeadCode.deadCodeProgram'@ refuses to start for the same
-- reason and in the same words.
redBaselineNote :: Text
redBaselineNote =
  "Outcome: NOT DIAGNOSED -- THE CONFIGURATION WAS ALREADY BROKEN. The host's own \
  \build driver was run before anything was changed and it failed, so this run \
  \diagnosed nothing and changed nothing. That is deliberate: a repair applied on \
  \top of a configuration that already does not build cannot be verified by a \
  \build, because the build fails either way, and a run that proceeded would end \
  \unable to say which failure was whose. Report the driver's own failing line, \
  \name it as pre-existing, and say that the build has to be green before the \
  \symptom below is worth diagnosing."

-- | The arm where the driver did not answer at all.
--
-- __Unreachable while the addressee is a @'Agentic.Workflow.running'@ party__, and
-- written because the compiler makes it be written and because that is not the
-- only thing the addressee can be. "Agentic.Shell" answers a verdict with approve
-- on exit @0@ and object on nonzero and never with a refusal — a missing or wedged
-- command is a @GapTransportRefusal@, which ends the run rather than taking an arm
-- — so the third arm of the @caseVerdict@ below is the one a @--route@ pointing
-- this addressee at a model would make reachable. It is also, as it happens, the
-- honest report for the case @skills\/nixos\/SKILL.md@ names: \"if the driver
-- cannot acquire its lock, report its error and stop.\"
driverSilentNote :: Text
driverSilentNote =
  "Outcome: THE DRIVER DID NOT ANSWER. The host's build driver was asked and gave \
  \back nothing at all -- neither a pass nor a failure -- so this run has no \
  \evidence about the machine and diagnosed nothing. Do not characterise the \
  \host's state. Report that the driver was reached and did not answer, and say \
  \what to check by hand: whether it holds its `.nixos-build` lock, and whether the \
  \run was started from the directory the driver lives in."

-- | The arm where the repair verified.
repairedNote :: NixRung -> Text
repairedNote t =
  "Outcome: REPAIRED AND VERIFIED. "
    <> what
    <> " The host's own build driver was run again after the edit and it passed, \
       \which is the verification `nix-pro`'s search strategy asks for and cannot \
       \perform: an option that does not exist is a build error, so a green build \
       \is evidence that every option the repair named is real. Nothing was \
       \activated. Report the diagnosis, the edit, and what the operator should \
       \watch after switching."
  where
    what = case t of
      Rebuild -> "The failing build was diagnosed from its own output and repaired."
      Alert -> "The alert was diagnosed from its own payload, uncompressed, and repaired."
      Integration -> "The integration failure was diagnosed and repaired."

-- | The arm where the build never came back.
stillBrokenNote :: NixRung -> Text
stillBrokenNote t =
  "Outcome: STILL FAILING. "
    <> what
    <> " and the host's own build driver still objects after every repair trip \
       \this run was given. Do not report this as resolved and do not suggest \
       \activating anything. Quote the driver's own failing line, say whether it \
       \is the same failure as the one this run started from or a new one -- those \
       \are very different facts -- and name what the next attempt should try. \
       \Every edit the repair trips made is still in the tree: nothing was \
       \reverted, because a named failure with the work in place is worth more \
       \than a clean tree with none of it."
  where
    what = case t of
      Rebuild -> "The failing build was diagnosed and a repair was applied"
      Alert -> "The alert was diagnosed and a repair was applied"
      Integration -> "The integration failure was diagnosed and a repair was applied"

-- ---------------------------------------------------------------------------
-- The report both endings call
-- ---------------------------------------------------------------------------

-- | The brief the report is written through.
--
-- /Source:/ none of the three commands has a report section — @nix-rebuild.md@
-- and @fix-alert.md@ are one sentence each — so the shape is
-- "Workflows.Report"'s: one act, a @{provenance}@ the arms differ in, and a
-- document that is the diagnosis and the driver's own words.
nixReportBrief :: Text
nixReportBrief =
  wfText
    [wf|
    Write the report for a NixOS repair run. It is read by the operator of the
    machine, who will decide from it whether to activate the configuration.

    Open with the provenance line you were given, verbatim, on its own line. It
    is the run's own account of how it ended and it is not yours to soften.

    Then, from the diagnosis and the build verdicts below and nothing else:

    - what the evidence said, quoting the line that mattered;
    - the cause, or that it was not established;
    - the edit that was applied, file by file;
    - what the build driver said afterwards, verbatim;
    - what the diagnosis explicitly did NOT establish;
    - what to watch after activating, and what would indicate the repair was
      wrong.

    Do not report an option as verified because the diagnosis named it
    confidently. A green build is what verifies an option exists; say which
    claims rest on the build and which rest on a reading.

    Nothing in this run activated a configuration. Do not write a sentence that
    reads as though the machine has been switched.|]

-- | One act, five provenance lines.
--
-- Three parameters: the provenance first, for "Workflows.Report"'s reason; then
-- the diagnosis, or — on an arm that never reached one — what the run knew about
-- the host; then the baseline __verdict__.
--
-- __The third parameter is a @verdict@ and not a @text@__, which is what lets
-- every arm splice the driver's own first failing line rather than a paraphrase
-- of it. A verdict interpolates into a prompt; that is the same property
-- @'Workflows.Notes.notesReportFn'@ turns on, and here it is the reason all five
-- endings can share one report function.
nixReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeVerdict] 'CodeAck
nixReportFn =
  function
    "nix.report"
    ( takes @"provenance" Text
        . takes @"diagnosis" Text
        . takes @"verdict" Verdict
        $ noParams
    )
    \provenance diagnosis verdict -> W.do
      act reporter [wf|
          {nixReportBrief}

          Provenance:

          {provenance}

          The diagnosis this run worked from:

          {diagnosis}

          What the host's build driver said when it was run before anything was
          changed:

          {verdict}

          Write the report, then reply DONE.|]
      done

-- | The table 'nixProgram' hands @'Agentic.Workflow.defining'@.
nixTable :: [SomeFn]
nixTable = [SomeFn nixReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One symptom, one diagnosis, one repair, one verification.
--
-- Three inputs, shared by all three rungs so that the family has one invocation
-- shape. @subject@ is what the run is about — the alert payload, the integration's
-- name, or what the operator was doing when the build failed; @output@ is the
-- failing text where the operator has it, and at the @Integration@ rung its
-- default is the error @fix-integration.md@ hard-codes; @host@ is the machine,
-- and it decides the build flags in Haskell.
--
-- The shape, top to bottom: run the host's own driver once and read its verdict
-- three ways; on the arm this rung diagnoses, put the symptom to @nix-pro@ under
-- its own search strategy, apply the repair, and run the driver again as the
-- verification. Five endings, five provenance lines, __one__ 'nixReportFn'.
--
-- __What differs between the rungs is which arm of the first verdict diagnoses.__
-- At @Rebuild@ the failure /is/ the subject, so the objecting arm is the working
-- one and an approving baseline means there is nothing to diagnose. At @Alert@ and
-- @Integration@ the failure is a runtime one, so an approving baseline is the
-- expected case and the working arm, and an /objecting/ baseline means the
-- configuration was already broken before this run touched it — which is a
-- different report and, more importantly, the fact that makes the verification at
-- the end attributable.
nixProgram :: NixRung -> Parameterized
nixProgram t =
  taking (input "subject" :> input "output" :> input "host" :> noInputs) \subject output host ->
    -- Tier 1, three times: the build flags this host needs, what the diagnosis is
    -- told about working on it, and — at two of the three rungs — the whole
    -- symptom. None of them costs a question or a path.
    let flags = hostFlags host
        sited = hostNote host
        symptom = symptomOf t subject output
        strategy = searchStrategy
     in defining nixTable case t of
          Rebuild -> W.do
            built <- ask (nixosBuild "build" flags) [wf|{buildBrief}|] `answering` Verdict

            -- One build, three arms. The driver is run ONCE before anything is
            -- changed -- on the parked machine a second run is hours -- and the
            -- verdict's own three tags are what separate "nothing to diagnose"
            -- from "here is the failing line" from "the driver said nothing".
            caseVerdict
              built
              ( W.do
                  call_ nixReportFn (arg nothingWrongNote :> arg sited :> arg built :> noArgs)
                  stop
              )
              ( W.do
                  diagnosis <- ask nixPro [wf|
                      {diagnoseBrief}

                      {sited}

                      {strategy}

                      The system will not build on this host. What the operator
                      was doing:

                      {subject}

                      What the build driver said:

                      {built}|]

                  act configurer [wf|
                      {repairPlanBrief}

                      {diagnosis}|]

                  gated <- gate (nixosBuild "build" flags) repairBrief nixPro diagnosis (atMost 2)

                  case gated of
                    Settled final -> W.do
                      call_ nixReportFn (arg (repairedNote t) :> arg final :> arg built :> noArgs)
                      stop
                    Unsettled final -> W.do
                      call_ nixReportFn (arg (stillBrokenNote t) :> arg final :> arg built :> noArgs)
                      stop
              )
              ( W.do
                  call_ nixReportFn (arg driverSilentNote :> arg sited :> arg built :> noArgs)
                  stop
              )
          _ -> W.do
            built <- ask (nixosBuild "build" flags) [wf|{buildBrief}|] `answering` Verdict

            caseVerdict
              built
              ( W.do
                  -- The symptom is a define here: assembled in Haskell from the
                  -- invocation, spliced whole, and never compressed. See the
                  -- rework note in the module header.
                  diagnosis <- ask nixPro [wf|
                      {diagnoseBrief}

                      {sited}

                      {strategy}

                      {symptom}|]

                  act configurer [wf|
                      {repairPlanBrief}

                      {diagnosis}|]

                  gated <- gate (nixosBuild "build" flags) repairBrief nixPro diagnosis (atMost 2)

                  case gated of
                    Settled final -> W.do
                      call_ nixReportFn (arg (repairedNote t) :> arg final :> arg built :> noArgs)
                      stop
                    Unsettled final -> W.do
                      call_ nixReportFn (arg (stillBrokenNote t) :> arg final :> arg built :> noArgs)
                      stop
              )
              ( W.do
                  call_ nixReportFn (arg redBaselineNote :> arg symptom :> arg built :> noArgs)
                  stop
              )
              ( W.do
                  call_ nixReportFn (arg driverSilentNote :> arg sited :> arg built :> noArgs)
                  stop
              )

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the build receipt's question opens with 'buildBrief'
-- and the diagnosis's with 'diagnoseBrief'.
--
-- __The baseline row is what steers the run, and it steers each rung down its own
-- working arm.__ The first build is a @verdict@, and the arm a rung diagnoses on
-- is not the same one:
--
--   * at @Rebuild@ the row answers with a real @nix@ error, which is not an
--     approving word, so the verdict objects and the run takes the /diagnosing/
--     arm — and the diagnosis's @{built}@ hole carries that line, which is the
--     whole point of the row;
--   * at @Alert@ and @Integration@ the row answers @APPROVE@, so the baseline is
--     green and those rungs take /their/ diagnosing arm. Change it to an error
--     line and the already-broken arm is what runs.
--
-- Delete the row entirely and @'Agentic.Exec.scriptedDefault'@ answers a verdict
-- @APPROVE@, which at @Rebuild@ rehearses the nothing-to-diagnose ending. All
-- five endings exit 0, which is the point of writing them.
--
-- __The gate's default ends the run green.__ The gate's check is the same driver
-- at @verdict@ and its prompt is the candidate rather than a brief, so it has no
-- key here and takes the @APPROVE@ default: the driver passes on the first check
-- after the repair and the run ends in @Settled@. The @repairBrief@ row is here so
-- that the repair turn's own question has an answer on the trip where it is
-- reached.
nixScript :: NixRung -> [(Text, Text)]
nixScript t =
  [ (buildBrief, baseline),
    (diagnoseBrief, diagnosed),
    (repairBrief, "Renamed the option to `services.grafana.settings.server.http_port`.")
  ]
  where
    baseline = case t of
      Rebuild ->
        "error: The option `services.grafana.protocol' does not exist. \
        \Definition values: [ \"http\" ]"
      _ -> "APPROVE"

    diagnosed = case t of
      Rebuild ->
        "1. Evidence: `error: The option `services.grafana.protocol' does not \
        \exist.` -- that is the driver's own line and it names the option.\n\
        \2. Cause: `hosts/vulcan/grafana.nix:14` sets \
        \`services.grafana.protocol`, which moved under \
        \`services.grafana.settings.server` in 23.05.\n\
        \3. Repair: in that file, replace the attribute with \
        \`services.grafana.settings.server.protocol`. Validated against the \
        \nixpkgs option list (step 1).\n\
        \4. Beyond the build: grafana answers on its port after activation.\n\
        \5. Not established: whether any other option in that file moved in the \
        \same release."
      Alert ->
        "1. Evidence: the payload's `alertname=NodeFilesystemAlmostOutOfSpace` \
        \and `mountpoint=/nix`.\n\
        \2. Cause: the Nix store has not been collected since the last channel \
        \bump; this is not a configuration defect.\n\
        \3. Repair: `nix.gc.automatic` is off in `hosts/vulcan/nix.nix`; turn it \
        \on with a weekly schedule. Validated against the nixpkgs option list \
        \(step 1).\n\
        \4. Beyond the build: the mountpoint's free space rises after the first \
        \collection.\n\
        \5. Not established: whether the growth rate makes weekly enough."
      Integration ->
        "1. Evidence: `Config flow could not be loaded: {\"message\":\"Invalid \
        \handler specified\"}`.\n\
        \2. Cause: the custom component's directory name does not match the \
        \`domain` in its `manifest.json`, so Home Assistant cannot find the \
        \handler the config flow names.\n\
        \3. Repair: rename the component directory to the manifest's domain in \
        \the package that installs it.\n\
        \4. Beyond the build: the integration appears in the add-integration \
        \dialog and its config flow opens.\n\
        \5. Not established: whether the component's own version constraint \
        \still matches the Home Assistant in this configuration."
