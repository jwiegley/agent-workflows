-- |
-- Module      : Workflows.Rubrics.Discipline
-- Description : The standing constraints, spliced into every acting question.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/skills\/fix-all\/SKILL.md@ (the
-- no-deferral rule, the testing standards, the upstream rule and the definition
-- of done); @skills\/parallelize\/SKILL.md@ (the parent-history sentinel);
-- @skills\/wiggum\/SKILL.md@ and @skills\/toolkit\/SKILL.md@ (the environment
-- discipline).
--
-- These are the sentences the corpus repeats in every file that fixes anything.
-- Repeated prose is prose that drifts, and the corpus has the same rule in three
-- spellings in three files. Here each is one binding, and a program that fixes
-- something splices it.
--
-- Nothing in @~\/src\/nix\/config\/ai@ is modified by this module.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Workflows.Rubrics.Discipline
  ( -- * @skills\/fix-all@
    fixAllRule,
    testingStandard,
    upstreamRule,
    definitionOfDone,

    -- * @skills\/parallelize@
    independenceAttestation,
    independenceAttestationKey,
    unverifiedIndependence,

    -- * The standing artefact rule
    codeIsTheArtefact,
  )
where

import Agentic.Workflow (wf)
import Data.Text (Text)
import Workflows.Prose (wfText)

-- ---------------------------------------------------------------------------
-- fix-all
-- ---------------------------------------------------------------------------

-- | The no-deferral rule.
--
-- /Source:/ @skills\/fix-all\/SKILL.md@, @# Mission@ and @# When rules
-- conflict@, verbatim.
fixAllRule :: Text
fixAllRule =
  wfText
    [wf|
    Fix every issue uncovered during this work. No exceptions, no excuses, no
    deferrals. "Out of scope," "pre-existing," and "follow-up ticket" are not
    acceptable framings -- if it surfaced, it gets fixed here.

    When rules conflict, do the harder, more correct thing. If following these
    rules would require shipping something broken, surface the conflict
    explicitly. Do not silently lower the bar.|]

-- | The testing standard, including the four named reward hacks.
--
-- /Source:/ @skills\/fix-all\/SKILL.md@, @# Testing standards@, verbatim.
testingStandard :: Text
testingStandard =
  wfText
    [wf|
    Everything you change or add has tests. Period.

    Tests exist to catch bugs. That is their only purpose. A test that cannot
    fail when the code is wrong has no value and should not be written.

    No reward hacking. Specifically forbidden: weakening assertions to get
    green; deleting, skipping or xfail-ing tests to get green; mocking the
    system under test; tautological tests, blind snapshot tests, or tests that
    only verify the code matches itself.

    When a bug is found, the response is to fix the bug -- never relax the test,
    never adjust assertions to match buggy output. The standard does not move
    when it becomes inconvenient.

    For each bug fixed, add the test that would have caught it. If you genuinely
    cannot, say so explicitly and explain why.|]

-- | The upstream rule.
--
-- /Source:/ @skills\/fix-all\/SKILL.md@, @# Upstream fixes are non-negotiable@,
-- verbatim.
upstreamRule :: Text
upstreamRule =
  wfText
    [wf|
    If a problem is caused upstream, fix it upstream. Always. There is no
    version of this rule that ends with a workaround downstream. This applies to
    vendored and third-party dependencies, to tooling and build systems and
    frameworks, and to shared libraries owned by other teams.

    Forbidden downstream workarounds: shims that paper over upstream bugs;
    conditional branches that exist only because upstream is wrong; "temporary"
    patches in our tree; a comment saying "workaround for X" instead of a fix in
    X.

    If upstream is genuinely blocked -- frozen repo, dead project, hostile
    maintainer -- say so explicitly, fork it, treat the fork as the new
    upstream, and fix it there.|]

-- | The definition of done.
--
-- /Source:/ @skills\/fix-all\/SKILL.md@, @# Definition of done@, verbatim but
-- for the worktree clause, which names a mechanism this toolbox does not use:
-- a fan-out here is a 'Agentic.Workflow.panel' and no @ask@ writes anything, so
-- there are no orphaned worktrees to leave lying around. The clause is dropped
-- rather than reworded, and this sentence is why.
definitionOfDone :: Text
definitionOfDone =
  wfText
    [wf|
    The task is done only when all of the following hold:

    - Every issue uncovered has been fixed -- not deferred, not ticketed.
    - Every upstream-caused problem has been fixed upstream, with our tree
      consuming the upstream fix. No local workarounds remain.
    - All new and modified code has high-value tests of the kind that catch the
      relevant bug class.
    - The full test suite passes locally.
    - All commits are atomically scoped.|]

-- ---------------------------------------------------------------------------
-- parallelize
-- ---------------------------------------------------------------------------

-- | The parent-history sentinel, in __one__ spelling.
--
-- /Source:/ @skills\/parallelize\/SKILL.md@, @## Context inheritance is
-- runner-dependent@. Three files in the corpus carry this gate in three
-- slightly different wordings — @commands\/deep-review.md@, @commands\/alexey.md@
-- and @commands\/heavy-review.md@ — which is three chances for one of them to be
-- the weak one.
--
-- __What this is a claim about, and what it is not.__ It is a claim about the
-- /runner/, not about the fan-out: a 'Agentic.Workflow.panel' member is an
-- independent question by construction here, but a live engine may still be a
-- session that inherited a transcript. The claim is worth stating because the
-- corpus's own reviewers make it constantly and nothing checks it.
--
-- __It detects planted context and nothing else, and the prompt now says so.__
-- The only thing an answerer can be asked about is the line the runner planted,
-- so the only contamination this probe can find is contamination the runner
-- itself would have caused: a second turn in a session it opened, or a fan-out
-- that leaked one prompt into another. A session that was already carrying an
-- unrelated transcript — an @agent-deck@ pane that did the work and is now being
-- asked to judge it — has no @PARENT_HISTORY_SENTINEL@ line in it, so it answers
-- @PARENT_HISTORY_ABSENT@ __truthfully__ and the probe passes. That is not a bug
-- in the answerer and cannot be fixed by rewording the question: the fact that
-- settles it is the engine's session policy, which the /runner/ knows and states
-- as @run.engine@ ('Agentic.Workflow.runFacts'), and which
-- 'Agentic.Workflow.sharesOneSession' reads for free. So a caller that needs a
-- separate evaluator gates on the engine fact and uses this probe for the
-- residual; the prompt below names its own limit rather than letting a reader
-- take a passing probe for independence.
--
-- __The premise is now established rather than asserted, and that is the whole
-- of this change.__ The old text said a sentinel line \"stands in the parent
-- conversation\" and that \"its value has not been copied into this request\".
-- Nothing planted one. Both halves were therefore false: a probe whose sentinel
-- does not exist is answered @PARENT_HISTORY_ABSENT@ by an inheriting runner and
-- by a clean one alike, which made every downstream gate rest on a reply that
-- could not distinguish them — @reviewLadder@ stopping a whole review, @fess@
-- downgrading its provenance, and @wiggum@ refusing to start. The runner now
-- generates one line per run (@run.sentinel@,
-- 'Agentic.Workflow.runFactSentinel'), so the argument the probe rests on is one
-- an answerer can only satisfy by having seen it.
--
-- __The value is in the request, and the question is where /else/ it is.__ There
-- is no way to ask about a line without naming it, and pretending otherwise is
-- what the old wording did. So the line is quoted, and what is asked is whether
-- a @PARENT_HISTORY_SENTINEL@ line was in the answerer's context /before/ this
-- request — a different value, or this one from an earlier turn. Under a runner
-- that opens a session per question there is nothing earlier to have seen;
-- under one that shares a conversation there is, and the answerer is the only
-- party that can say so.
--
-- __The sentinel is last on purpose.__ A scripted table matches by prefix
-- (@Agentic.Exec.scriptedReply@), so a run-unique value anywhere but the end
-- would make the key unwritable — every run would have a different prompt from
-- the first differing byte. At the end, everything before it is constant, and
-- 'independenceAttestationKey' is that constant, derived from this very function
-- so the two cannot drift.
independenceAttestation :: Text -> Text
independenceAttestation sentinel =
  wfText
    [wf|
    Sentinel check. This asks about one line and nothing else, and the answer is
    not a judgement about whether your context is otherwise clean.

    The runner generated one PARENT_HISTORY_SENTINEL line for this run and put it
    in no place other than this request. If such a line was already in your
    context before this request -- a different value, or this same one from an
    earlier turn -- reply with that inherited line and nothing else. If this
    request is the only place you have seen one, reply with exactly

      PARENT_HISTORY_ABSENT

    and nothing else.

    Answer literally. A session carrying other prior context but no
    PARENT_HISTORY_SENTINEL line answers PARENT_HISTORY_ABSENT, and that is the
    correct answer: whether this run's questions share a conversation is a fact
    the runner already holds and does not need you to guess at. Do not qualify,
    explain or hedge the reply.

    This run's line is:

    {sentinel}|]

-- | The probe's prompt up to the run's own line: the prefix a scripted table
-- keys the probe on.
--
-- It is 'independenceAttestation' at the empty sentinel rather than a second
-- copy of the words, which is the same rule every canned table in this toolbox
-- follows — the keys /are/ the defines — extended to a define one input long.
-- A reworded probe moves this key with it, by construction.
independenceAttestationKey :: Text
independenceAttestationKey = independenceAttestation ""

-- | What a run says when the sentinel probe is absent or failed.
--
-- /Source:/ @agents\/fess-auditor.md@'s own clause: \"If that attestation is
-- absent, run the audit but report that its independence was not verified.\"
--
-- That sentence is a __branch__, and in Markdown it is a hope. Here it is two
-- arms of one @case@ calling one report function with a different
-- @{provenance}@ argument, so the report cannot come out claiming an
-- independence nothing established.
--
-- __The engine fact is not in this arm's wording, and does not need to be.__
-- This is the arm where the probe /failed/, which is already the stronger
-- statement: planted context was found, so no session policy can make the
-- answers separate. The arm that has to name the engine is the passing one,
-- because that is the one a reader would otherwise over-read — see
-- 'Workflows.Audit.Fess.verifiedIndependence'.
unverifiedIndependence :: Text
unverifiedIndependence =
  wfText
    [wf|
    Provenance: this audit ran, and its independence was NOT verified. This
    run's own parent-history sentinel was put to the answering runner and the
    reply was not PARENT_HISTORY_ABSENT, so a transcript this audit did not
    choose was in front of it. Do not describe any finding below as an
    independent confirmation. State this in the summary, in one sentence, before
    anything else.|]

-- ---------------------------------------------------------------------------
-- The standing artefact rule
-- ---------------------------------------------------------------------------

-- | The rule that separates a review from an edit.
--
-- /Source:/ @commands\/deep-review.md@ (\"These are mandatory review lenses, not
-- permission to mutate the changeset\") and @agents\/fess-auditor.md@'s
-- Operating Rule 1.
--
-- __It is already structural.__ A reviewing question is asked at @text@, and
-- @Agentic.Acp.permissionByCode@ grants write authority only to an act at
-- @receipt@ — so a reviewer that wanted to edit the tree could not, whatever it
-- was told. The sentence is spliced anyway, because a model that knows it is
-- not editing writes a different review: it reports rather than proposes to
-- apply.
codeIsTheArtefact :: Text
codeIsTheArtefact =
  wfText
    [wf|
    You are reading, not writing. Identify and report findings only: do not edit
    files, add markers, create manifests, remove code, or apply fixes. If a fix
    is obvious, describe it; the describing is your whole output.|]
