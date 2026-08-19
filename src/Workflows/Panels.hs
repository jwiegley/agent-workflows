-- |
-- Module      : Workflows.Panels
-- Description : The roster, and the one fan-out.
--
-- __Provenance.__ The corpus fans out constantly and never the same way twice:
-- eleven reviewers in @commands\/deep-review.md@, eleven sin stances in
-- @agents\/fess-auditor.md@, twelve roles in @commands\/teams.md@, ten sections
-- in @commands\/meeting-notes.md@, eight in @commands\/sitrep.md@, seven passes
-- in @commands\/heavy-review.md@, three advocates in
-- @skills\/eliminate-dead-code@. All of it is one type and three constructors.
--
-- == The derived roster, which is the point
--
-- @incite@'s @qaOfCommitOver@ splices a count and a sibling table computed from
-- the very list the panel is built from, so a lens added to the table arrives in
-- every other member's brief __by being added__. That is what 'memberNote' does
-- here, and it is why \"do not repeat the others' work\" is a sentence with a
-- referent rather than a hope. Fourteen files in the corpus tell a reviewer not
-- to duplicate a sibling and none of them can say which siblings there are.
--
-- == Where @skills\/parallelize@ dissolves
--
-- @skills\/parallelize\/SKILL.md@ has more inbound references than any other
-- skill in the corpus, and what every caller wants from it is \"run these N
-- things independently\". A 'Agentic.Workflow.panel' /is/ independent by
-- construction — each member is one question, no member sees another's answer,
-- and no @ask@ writes anything — so the skill's ten-bullet list of shared state
-- a subagent must not touch is a hand-written type system for an untyped
-- harness, with no referent here. What survives is its arity discipline, and
-- @'Agentic.Plan.costSummary'@ __computes__ that where the skill guesses at
-- three to five.
--
-- What does /not/ dissolve is its independence attestation, which is a claim
-- about the runner and not about the fan-out: see
-- 'Workflows.Rubrics.Discipline.independenceAttestation'.
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
-- @MonoLocalBinds@ for the reason "Agentic.WF" enables it: it is what keeps a
-- 'KnownIx' constraint out of @-Wsimplifiable-class-constraints@, which fires on
-- any signature mentioning a class that has exactly one instance standing on
-- another.
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Workflows.Panels
  ( -- * The roster
    Lens (..),
    Roster,
    lensNames,
    rosterTable,

    -- * The fan-outs
    asksOver,
    verdictPanel,
    documentPanel,
    withEvidence,

    -- * The derived brief
    memberNote,

    -- * The synthesis that refuses
    refusingSynthesis,
  )
where

import Agentic.Workflow
  ( Ask,
    Code (CodeText, CodeVerdict),
    KnownIx,
    Party,
    PartyK (IsModel),
    Rhs,
    V,
    ask,
    panel,
    panelText,
    wf,
  )
import Data.Text (Text)
import Workflows.Prose (bullets, tshow, wfText)
import Workflows.Rubrics.Finding (verdictSpec)

-- ---------------------------------------------------------------------------
-- The roster
-- ---------------------------------------------------------------------------

-- | One member of a fan-out: what it is called, what it owns, what it is told,
-- and who answers it.
--
-- __'lensName' is the author's and never the addressee's id.__ Two members of
-- one spread routinely share a serving model, and a document whose block names
-- change when an operator repoints a lens is naming the wrong thing.
--
-- __'lensOwns' exists so the /other/ members can be told about it.__ It is the
-- one column that would be pure decoration in a Markdown file and is load-
-- bearing here: 'memberNote' derives every member's sibling table from it.
data Lens = Lens
  { -- | the block label in a folded document, and the row name in a table
    lensName :: !Text,
    -- | the one question this member owns, in a clause
    lensOwns :: !Text,
    -- | its rubric — the first chunk of every question it is asked
    lensBrief :: !Text,
    -- | who answers, pin and alternates included ("Workflows.Parties")
    lensParty :: Party 'IsModel
  }

-- | A fan-out, in the order its members are asked and its blocks are folded.
type Roster = [Lens]

-- | The members' names, for a brief that has to name them or a report that has
-- to account for each.
lensNames :: Roster -> [Text]
lensNames = map lensName

-- | The whole roster as the bullet table a synthesis brief holes.
rosterTable :: Roster -> Text
rosterTable r = bullets [(lensName l, lensOwns l) | l <- r]

-- ---------------------------------------------------------------------------
-- The derived brief
-- ---------------------------------------------------------------------------

-- | What a member is told about the fan-out it is one of.
--
-- Derived from the same list the fan-out is built from, so it cannot go stale.
-- Empty for a roster of one, because a lone reviewer told not to duplicate its
-- siblings has been told something false.
memberNote :: Roster -> Lens -> Text
memberNote r l
  | null others = ""
  | otherwise =
      "You are one of "
        <> tshow (length r)
        <> " independent reviewers reading the same artefact. The others own:\n"
        <> bullets [(lensName o, lensOwns o) | o <- others]
        <> "\nDo not repeat their work. Report only what you own; anything you\n"
        <> "duplicate ships twice and is read once.\n\n"
  where
    others = [o | o <- r, lensName o /= lensName l]

-- ---------------------------------------------------------------------------
-- The fan-outs
-- ---------------------------------------------------------------------------

-- | One question per member over one artefact, with the closing line the
-- caller's fold needs.
--
-- An ordinary Haskell function from a live handle to a list of
-- 'Agentic.Workflow.Ask's, usable at __any__ scope where the handle is live —
-- which is what @KnownIx h s@ says, and which is Isaac's \"a question shares\".
asksOver :: (KnownIx h s) => Roster -> Text -> V h 'CodeText -> [Ask s]
asksOver r closing subject =
  [ ask (lensParty l) [wf|
      {brief}

      {note}{subject}

      {closing}|]
  | l <- r,
    let brief = lensBrief l,
    let note = memberNote r l
  ]

-- | The roster folded to a __verdict__: every member must approve.
--
-- Folded right in the noncommutative verdict monoid, so the objections a run
-- collects are in member order and the first one is the first member that said
-- no.
verdictPanel :: (KnownIx h s) => Roster -> V h 'CodeText -> Rhs s 'CodeVerdict
verdictPanel r subject = panel (asksOver r verdictSpec subject)

-- | The roster folded to a __document__: each member's answer fenced under its
-- own 'lensName', concatenated in member order.
--
-- The same fan-out, the same one question per member, the same trace, and a
-- different fold — which is what the corpus's collating commands want and what
-- a verdict cannot give them: the reader of the document can tell which member
-- said what.
documentPanel :: (KnownIx h s) => Roster -> V h 'CodeText -> Rhs s 'CodeText
documentPanel r subject =
  panelText (zip (lensNames r) (asksOver r reportClosing subject))
  where
    reportClosing =
      "Report your findings and nothing else. Your answer is one block of a \
      \document whose other blocks are your siblings' — do not summarise the \
      \whole, and do not address the reader of any block but your own."

-- | The roster over an artefact __and__ a dossier of receipts the world
-- authored.
--
-- This is @commands\/heavy-review.md@'s \"every pass examines identical code\"
-- made structural: the snapshot is a handle, bound once, spliced into every
-- member — so the members cannot be looking at different trees, and no member
-- has to be trusted to have run anything.
withEvidence ::
  (KnownIx h s, KnownIx h' s) =>
  Roster ->
  Text ->
  V h 'CodeText ->
  V h' 'CodeText ->
  [Ask s]
withEvidence r closing subject dossier =
  [ ask (lensParty l) [wf|
      {brief}

      {note}The following receipts were produced by running the commands
      named in them. They are bytes, not claims: if a receipt and your reading
      of the artefact disagree, the receipt is what happened.

      {dossier}

      {subject}

      {closing}|]
  | l <- r,
    let brief = lensBrief l,
    let note = memberNote r l
  ]

-- ---------------------------------------------------------------------------
-- The synthesis
-- ---------------------------------------------------------------------------

-- | The brief for the question that folds a roster's document, __with the
-- roster it refuses on derived from the same table__.
--
-- /Source:/ @incite@'s @grindSynthesisOver@, whose argument is the one the
-- corpus needs and cannot state: an unauthenticated backend returns nothing,
-- and nothing folded into a ranked list reads exactly like a clean tree. A
-- synthesis that cannot see every block it was promised must say so instead of
-- summarising the blocks it got.
refusingSynthesis :: Roster -> Text
refusingSynthesis r =
  wfText
    [wf|
    Below is a document of {count} blocks, one per reviewer, each fenced under
    its own name. The reviewers and what each owns:

    {table}

    First, account for the blocks. If any named reviewer's block is missing or
    empty, reply with exactly

      INCOMPLETE: <the names of the missing blocks>

    and nothing else. Do not summarise what did arrive: a partial fan-out folded
    into a ranked list is indistinguishable from a clean tree, and that is the
    one mistake this step exists to prevent.

    Otherwise, produce the consolidated report: deduplicate findings that name
    the same file and line, sort by severity, keep every reviewer's clean
    statement as its own line, and order the fixes smallest-safe-first.|]
  where
    count = tshow (length r)
    table = rosterTable r
