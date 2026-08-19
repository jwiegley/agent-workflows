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
-- __What this is a claim about.__ It is a claim about the /runner/, not about
-- the fan-out: a 'Agentic.Workflow.panel' member is an independent question by
-- construction here, but a live engine may still be a session that inherited a
-- transcript, and that is what the probe tests. The claim is worth stating
-- because the corpus's own reviewers make it constantly and nothing checks it.
independenceAttestation :: Text
independenceAttestation =
  wfText
    [wf|
    Independence check. A new context window is not necessarily a blank context:
    some runners inherit the parent transcript by default.

    A random line of the form PARENT_HISTORY_SENTINEL=<at least 16 random
    characters> stands in the parent conversation, and its value has not been
    copied into this request. Reply with the inherited sentinel line if you can
    see one, or with exactly

      PARENT_HISTORY_ABSENT

    if you cannot. Reply with that and nothing else.|]

-- | What a run says when the attestation is absent or failed.
--
-- /Source:/ @agents\/fess-auditor.md@'s own clause: \"If that attestation is
-- absent, run the audit but report that its independence was not verified.\"
--
-- That sentence is a __branch__, and in Markdown it is a hope. Here it is two
-- arms of one @case@ calling one report function with a different
-- @{provenance}@ argument, so the report cannot come out claiming an
-- independence nothing established.
unverifiedIndependence :: Text
unverifiedIndependence =
  wfText
    [wf|
    Provenance: this audit ran, and its independence was NOT verified. The
    runner offered no explicit no-history mode, or the parent-history sentinel
    probe did not pass. Do not describe any finding below as an independent
    confirmation. State this in the summary, in one sentence, before anything
    else.|]

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
