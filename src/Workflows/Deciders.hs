-- |
-- Module      : Workflows.Deciders
-- Description : The free tests — every classification the corpus pays a model for.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/commands\/deep-review.md@ Step 2 (the
-- extension table); @skills\/parallelize\/SKILL.md@ (@PARENT_HISTORY_ABSENT@);
-- @skills\/wiggum\/SKILL.md@ (the done sentinel); @commands\/fix-ci.md@ (the
-- check status); @commands\/process-checklist.md@ (the unchecked box);
-- @agents\/elisp-reviewer.md@ (@lexical-binding@ on the first line);
-- @agents\/coq-reviewer.md@ (@Admitted@); @agents\/rust-reviewer.md@
-- (@// SAFETY:@).
--
-- Each of those is a __pure test on text already in hand__, and in the corpus
-- each costs a model call — or worse, is a thing a model is asked to report
-- about itself. @'Agentic.Workflow.decide'@ asks nothing and costs nothing in
-- any fold, so writing one where an asked flag stood is __one fewer question on
-- every path, the same number of paths, and the same rung__.
--
-- The needles are literal program text and never words: a needle a model could
-- author is a test a model chooses, which is not a decider.
--
-- == The house rule: decide as early as possible
--
-- Three tiers, and a workflow should reach for the lowest one that can answer.
--
-- +------+---------------------------------+---------------------+-------------------------------------------+
-- | tier | mechanism                       | costs               | when                                      |
-- +======+=================================+=====================+===========================================+
-- | 1    | ordinary Haskell, over a        | zero questions,     | the fact is in the invocation: which      |
-- |      | @'Agentic.Workflow.taking'@     | __zero paths__      | languages the diff touches, which rung,   |
-- |      | input, before the @Program@     |                     | which roster                              |
-- |      | exists                          |                     |                                           |
-- +------+---------------------------------+---------------------+-------------------------------------------+
-- | 2    | 'Agentic.Workflow.decide', over | zero questions,     | the fact exists only after the world ran  |
-- |      | a receipt                       | one path            | something: a sentinel, a head oid, a gate |
-- +------+---------------------------------+---------------------+-------------------------------------------+
-- | 3    | an asked flag                   | one question        | the fact is a judgment                    |
-- +------+---------------------------------+---------------------+-------------------------------------------+
--
-- Tier 1 is the one nothing in the corpus can reach: @supply@ builds the
-- 'Agentic.Builder.Program' /after/ the inputs are known, so
-- @plan --input-arg paths=…@ prints the exact roster that will run, and the
-- operator sees it before spending. 'touches' is that tier; everything else
-- here is tier 2.
{-# LANGUAGE OverloadedStrings #-}

module Workflows.Deciders
  ( -- * Tier 1 — decided in Haskell, before the program exists
    pathsOf,
    touches,

    -- * Tier 2 — decided over a receipt, for zero questions
    saysDone,
    saysComplete,
    historyAbsent,
    isGreen,
    isRed,
    noConflictMarkers,
    hasUnchecked,
    hasAdmitted,
    everyUnsafeHasSafety,
    lexicalBindingFirstLine,
    headMatches,
    incompleteFanOut,
    treeDirty,
    openPullRequest,
    observationsPending,
    claudeMdPresent,
    auditIncomplete,

    -- * Tier 2 — over a sentinel the asking brief spelled out
    noOpenComments,
    noTasksFound,
    nestedHeadline,
    notCompressible,
    atomicTask,
    ambiguousTask,
    noExpertise,
    unreconciled,
    bundleRejected,
    bundleRecommended,
    startOverRecommended,
    todosOutstanding,
    noRowsReturned,
    batteryRegressed,
    batteryIncomplete,
    noModelSet,
  )
where

import Agentic.Workflow (Decider (..))
import Data.Text (Text)
import qualified Data.Text as T

-- ---------------------------------------------------------------------------
-- Tier 1
-- ---------------------------------------------------------------------------

-- | The paths in a @--input-arg paths=…@ value: one per line, blanks dropped.
--
-- Ordinary Haskell over ordinary 'Text'. What comes out of it selects a roster
-- (@'Workflows.Rubrics.Reviewers.languageRoster'@) __before__ the program is
-- built, which is why the dispatch adds no node, no question and no path.
pathsOf :: Text -> [Text]
pathsOf = filter (not . T.null) . map T.strip . T.lines

-- | Does any of these paths end in this suffix?
--
-- /Source:/ @commands\/deep-review.md@ Step 2's extension table, which in the
-- corpus is a thing a coordinator model is told to compute and here is a
-- three-line function. @'Workflows.Rubrics.Reviewers.languageRoster'@ is its
-- only caller and the glob column is its only argument.
touches :: [Text] -> Text -> Bool
touches ps suffix = any (suffix `T.isSuffixOf`) ps

-- ---------------------------------------------------------------------------
-- Tier 2
-- ---------------------------------------------------------------------------

-- $tier2
--
-- Each is a @(Decider, [needle])@ pair, spelled once. A workflow writes
--
-- > ok <- uncurry decide saysDone status
--
-- and nothing spells a needle twice. The pair is the unit because a decider
-- without its needles is half a test, and the corpus's own drift is exactly
-- there: three files carry the history sentinel and two of them spell it
-- differently.

-- | @DONE@ as the last non-empty line — the receipt shape every act in this
-- tree asks for.
saysDone :: (Decider, [Text])
saysDone = (LastNonEmptyLineIs, ["DONE"])

-- | @WORK COMPLETE@ against @WORK REMAINS@.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s continuation loop, and @incite@'s
-- @tripEnding@, which is the same sentinel one repository over. The @BLOCKED@
-- ending is not tested here: it is a __third__ answer and belongs to
-- 'Workflows.Escalation', not to a two-way flag.
saysComplete :: (Decider, [Text])
saysComplete = (LastNonEmptyLineIs, ["WORK COMPLETE"])

-- | @PARENT_HISTORY_ABSENT@, in the one spelling the corpus's three copies
-- should have had.
--
-- /Source:/ @skills\/parallelize\/SKILL.md@ step 2. In the corpus this is
-- checked by a Python script the runner is told to invoke; here it is a test on
-- the probe's own answer, and the script has nothing left to do.
historyAbsent :: (Decider, [Text])
historyAbsent = (LastNonEmptyLineIs, ["PARENT_HISTORY_ABSENT"])

-- | A check run that finished clean.
--
-- /Source:/ @commands\/fix-ci.md@, which watches @gh pr checks@ and reasons
-- about what it saw. Note that a real gate does not need this at all: an exit
-- code is a @flag@ or a @verdict@ directly (see 'Workflows.Gates'). It is here
-- for the case where the status arrived as /text/ inside something larger.
isGreen :: (Decider, [Text])
isGreen = (AnyLineStartsWith, ["All checks were successful", "✓ "])

-- | A check run with something red in it.
--
-- /Source:/ @incite@'s @isRed@, whose needle keeps its trailing space
-- deliberately: a needle is not trimmed, so @anyLineStartsWith [\"✗ \"]@ pins
-- @isRed \"✗\" == False@ exactly as the original does.
isRed :: (Decider, [Text])
isRed = (AnyLineStartsWith, ["✗ ", "fail", "FAIL"])

-- | No conflict marker survived a resolution.
--
-- /Source:/ @commands\/resolve.md@ and @commands\/rebase-and-fix.md@, whose
-- postcondition is exactly this and is checked by reading. Used __negated__:
-- the resolution is done when this is false.
noConflictMarkers :: (Decider, [Text])
noConflictMarkers = (AnyLineStartsWith, ["<<<<<<<", "=======", ">>>>>>>"])

-- | An unchecked Markdown box remains.
--
-- /Source:/ @commands\/process-checklist.md@, whose whole loop is \"until there
-- are none\". The loop's exit condition is free.
hasUnchecked :: (Decider, [Text])
hasUnchecked = (AnyLineStartsWith, ["- [ ]", "* [ ]"])

-- | An @Admitted@ survived.
--
-- /Source:/ @agents\/coq-reviewer.md@ priority 1: \"an @Admitted@ in non-draft
-- code is a critical finding.\" A critical finding that a grep decides is a
-- critical finding nobody has to be trusted about.
hasAdmitted :: (Decider, [Text])
hasAdmitted = (AnyLineStartsWith, ["Admitted."])

-- | Every @unsafe@ block carries its @// SAFETY:@ comment.
--
-- /Source:/ @agents\/rust-reviewer.md@ priority 1. This one is a __partial__
-- test and the haddock says so: it detects the presence of the comment
-- convention, not its correctness, and the file's own demand is that the
-- invariant actually holds — which is a judgment and therefore tier 3. The
-- decider is worth having anyway, because the cheap half of the question should
-- not cost a model call before the expensive half is asked.
everyUnsafeHasSafety :: (Decider, [Text])
everyUnsafeHasSafety = (AnyLineStartsWith, ["// SAFETY:"])

-- | The Emacs Lisp cookie.
--
-- /Source:/ @agents\/elisp-reviewer.md@ priority 1, which is stated as a test on
-- the __first line__ of the file. 'ContainsLine' is exact line equality, so a
-- file whose cookie is on line three fails it — which is the rule as written.
lexicalBindingFirstLine :: (Decider, [Text])
lexicalBindingFirstLine = (ContainsLine, [";;; -*- lexical-binding: t; -*-"])

-- | The head is still where the review started.
--
-- /Source:/ @commands\/bugbot.md@ and @commands\/review-github-pr.md@, both of
-- which pin @headRefOid@ and then hope. The needle is the oid the caller bound
-- earlier in the run, so this is the one decider whose needles are computed —
-- from a __receipt__, never from an answer.
headMatches :: Text -> (Decider, [Text])
headMatches oid = (LastNonEmptyLineIs, [oid])

-- | A synthesis that refused because a block was missing.
--
-- /Source:/ 'Workflows.Panels.refusingSynthesis', whose contract this is the
-- other half of: the brief tells the model to answer @INCOMPLETE: …@ and this
-- is what reads it, for free, so the refusal is a branch the program takes and
-- not a string a reader notices.
incompleteFanOut :: (Decider, [Text])
incompleteFanOut = (AnyLineStartsWith, ["INCOMPLETE:"])

-- | Anything at all in @git status --porcelain@.
--
-- /Source:/ @commands\/halt.md@ step 2 — \"commit all outstanding work
-- following the @commit@ workflow … then push it\" — which is a postcondition
-- the file states and, like @bankruptcy.md@'s, never tests.
--
-- __The needle list is the porcelain format's own alphabet, and it is
-- exhaustive.__ @git status --porcelain@ prints nothing for a clean tree and
-- otherwise one @XY path@ line per entry, where @X@ is one of these nine
-- characters. A needle is not trimmed, so the single space matches an unstaged
-- modification (@\" M\"@) exactly as @\"?\"@ matches an untracked file: between
-- them the nine cover every line the command can write, which is what makes
-- \"any output at all\" decidable with a prefix test.
treeDirty :: (Decider, [Text])
treeDirty = (AnyLineStartsWith, [" ", "M", "A", "D", "R", "C", "U", "?", "!"])

-- | An open pull request already mentions the issue.
--
-- /Source:/ @commands\/fix.md@'s @NOTE@, and
-- @'Workflows.Evidence.ghPrSearch'@'s @--jq@, which is what gives the receipt a
-- shape this needle can test: one URL per hit, nothing at all for none.
openPullRequest :: (Decider, [Text])
openPullRequest = (AnyLineStartsWith, ["https:"])

-- | An observation file is still waiting in the directory the run was given.
--
-- /Source:/ @commands\/partner-cleanup.md@'s @## Cleanup Loop@ — \"repeat until
-- the observations directory has no regular, non-hidden @*.md@ files\".
--
-- The needle is the directory, which is a program /input/: this is
-- 'headMatches'\' company and 'Workflows.Git.Commit.treeNeedle'\'s rule — a
-- needle may be computed from the invocation, never from an answer. See
-- @'Workflows.Evidence.mdFilesIn'@ for why the receipt is a @find@ and not an
-- @ls@.
observationsPending :: Text -> (Decider, [Text])
observationsPending dir = (AnyLineStartsWith, [dir <> "/"])

-- | A @CLAUDE.md@ already stands in the directory the run was given.
--
-- /Source:/ @commands\/initialize.md@'s \"if there's already a @CLAUDE.md@,
-- suggest improvements to it\" — the clause @doc\/design.md@ §7.2 row 28 calls a
-- rework, because it silently changes the output /kind/. Here it is this test,
-- and the two kinds are two functions with two terminals.
--
-- 'ContainsLine' is exact line equality and @'Workflows.Evidence.lsPath'@ prints
-- one bare name per line, so the pair is exact: a @CLAUDE.md.bak@ is not a
-- @CLAUDE.md@, and a @doc\/CLAUDE.md@ is not one either.
claudeMdPresent :: (Decider, [Text])
claudeMdPresent = (ContainsLine, ["CLAUDE.md"])

-- | The comment-audit manifest still has entries nobody has judged.
--
-- /Source:/ @skills\/comment-audit\/SKILL.md@ step 6 — \"the audit is complete
-- only when the manifest reports zero pending __and__ the file\/comment
-- denominator reconciliation has no unclassified supplemental entry\" — read
-- against the extractor's own closing line, which is either
-- @AUDIT INCOMPLETE: \<n\> comment(s) still pending.@ or
-- @EXTRACTED INVENTORY COMPLETE: …@.
--
-- __The gate has two conjuncts and exactly one of them is decidable.__ This is
-- the first: a count the tool prints, tested for nothing. The second — whether
-- the extractor /missed/ anything — is a judgment about a heuristic tokenizer's
-- blind spots, and the script says so itself on its next line: \"file\/comment
-- denominator reconciliation is still required\". "Workflows.Comments" asks that
-- one, of somebody else, and 'unreconciled' reads the answer.
auditIncomplete :: (Decider, [Text])
auditIncomplete = (AnyLineStartsWith, ["AUDIT INCOMPLETE:"])

-- ---------------------------------------------------------------------------
-- Tier 2, over a sentinel the asking brief spelled out
-- ---------------------------------------------------------------------------

-- $sentinels
--
-- Each of these reads a word the /asking brief/ told the answerer to use, which
-- is 'Workflows.Panels.refusingSynthesis' and 'incompleteFanOut''s arrangement
-- generalised: the needle is still literal program text, and the program is
-- still the only party that could have chosen it. What distinguishes them from
-- the receipts above is worth stating plainly — the answer is a model's, so the
-- test proves the model said the word and not that the word is true. Every one
-- of them is used where the /cheap/ ending is the one being detected: a run
-- with nothing to do, a task that cannot be decomposed, a list with no tasks in
-- it. A sentinel that decided something expensive would be a model choosing its
-- own budget.

-- | The pull request has no open comment from a human author.
--
-- /Source:/ @commands\/respond.md@ opens \"in PR $ARGUMENTS there are several
-- open comments from my colleagues\", which is an assumption. Here it is a
-- branch, and the arm the corpus does not have is the one that costs nothing.
noOpenComments :: (Decider, [Text])
noOpenComments = (AnyLineStartsWith, ["NO OPEN COMMENTS"])

-- | The extraction found nothing to extract.
--
-- /Source:/ @commands\/infer-tasks.md@ @\<special_cases\>@, verbatim: \"if no
-- tasks are present: output exactly the sentence 'No actionable tasks
-- identified in this text.'\" The corpus wrote the sentinel and had nothing to
-- read it with.
noTasksFound :: (Decider, [Text])
noTasksFound = (AnyLineStartsWith, ["No actionable tasks identified in this text."])

-- | A second-level headline appeared in a list that must be flat.
--
-- /Source:/ @commands\/infer-tasks.md@'s @\<output_shape\>@ (\"all headlines at
-- the SAME star depth; no nested children\"), its @NO-OVERLAP RULE@, and the
-- last line of its @\<validation\>@ block (\"no headline describes HOW another
-- headline will be done\").
--
-- __This is the one mechanical item of that checklist the four deciders can
-- actually decide__, and it decides the load-bearing one: at the default depth
-- of one star, a line beginning @\"** \"@ /is/ a child, and a child is the
-- failure the whole prompt is written to prevent. See
-- "Workflows.OrgTasks" for the honest accounting of the other twelve.
nestedHeadline :: (Decider, [Text])
nestedHeadline = (AnyLineStartsWith, ["** "])

-- | The compression declined, because it could not shed anything without
-- shedding meaning.
--
-- /Source:/ @skills\/caveman\/SKILL.md@'s standing constraint — its @ALWAYS
-- KEEP@ list, and its whole premise that meaning survives — which the file
-- states as a rule and gives no way of refusing under. The sentinel is authored
-- by 'Workflows.Prose.Polish.compressBrief' for
-- 'Workflows.Prose.Polish.compressProgram' to read: text that is already at its
-- floor is a real case, and a compressor with no way to say so answers by
-- damaging it.
notCompressible :: (Decider, [Text])
notCompressible = (AnyLineStartsWith, ["NOT COMPRESSIBLE"])

-- | The task cannot be decomposed.
--
-- /Source:/ @commands\/breakdown.md@ @## Special Cases@: \"if the task is
-- already atomic … output only: @[ATOMIC]@\".
atomicTask :: (Decider, [Text])
atomicTask = (AnyLineStartsWith, ["[ATOMIC]"])

-- | The task cannot be decomposed without an answer from somebody.
--
-- /Source:/ @commands\/breakdown.md@: \"output only:
-- @[AMBIGUOUS: brief description of what clarification is needed]@\". The needle
-- stops before the colon because the description is the answer's, not the
-- program's.
ambiguousTask :: (Decider, [Text])
ambiguousTask = (AnyLineStartsWith, ["[AMBIGUOUS"])

-- | The decomposition was made without the domain knowledge it wanted.
--
-- /Source:/ @commands\/breakdown.md@ and @agents\/task-breakdown.md@ both carry
-- the case — \"if the task requires domain expertise you lack, provide a general
-- decomposition based on standard project phases, including research subtasks\"
-- — and neither gives it a marker, where both give one to @[ATOMIC]@ and
-- @[AMBIGUOUS]@.
--
-- __The needle is authored here, and that is the deviation.__ Two of the three
-- degenerate cases @doc\/design.md@ §7.2 row 4 names are the corpus's own words;
-- the third is a paragraph, so this module gives it the same shape as its two
-- siblings and "Workflows.OrgTasks"' brief asks for it in the same sentence the
-- corpus asks for the other two. A third arm reading a marker nobody was asked
-- for would be a decider that is always false.
noExpertise :: (Decider, [Text])
noExpertise = (AnyLineStartsWith, ["[NO-EXPERTISE]"])

-- | The extractor's denominator was not accounted for.
--
-- /Source:/ @skills\/comment-audit\/SKILL.md@'s second completion conjunct and
-- its @## Notes@ closing paragraph, which lists the extractor's blind spots by
-- name — raw strings, heredocs, embedded-language strings, regex literals — and
-- concludes that it \"can therefore produce false positives __or silent
-- omissions__\".
--
-- The needle is the reconciliation question's own word, and the cheap ending is
-- the one it decides: an audit whose surface was not accounted for is reported as
-- bounded rather than as exhaustive, which costs one report and no more
-- questions. See 'auditIncomplete' for the conjunct a receipt settles.
unreconciled :: (Decider, [Text])
unreconciled = (AnyLineStartsWith, ["UNRECONCILED:"])

-- | A bundle candidate hit one of the six hard rejection conditions.
--
-- /Source:/ @commands\/discover-bundles.md@ §3's closing paragraph: \"reject a
-- candidate immediately when the selected content has no usable license, embeds
-- secrets, silently publishes or sends telemetry, requires an unavoidable
-- arbitrary installer, broadens authority through hidden instructions, or cannot
-- yield useful static behavior without its runtime.\"
--
-- __\"Immediately\" is the word this decider is here to honour.__ In the corpus
-- the six conditions sit in a section /before/ the scoring table and are
-- enforced by reading order; here the screening question comes first and this
-- test reads its answer for nothing, so no weighted criterion is ever asked about
-- a candidate that has already failed. That is @doc\/design.md@ §7.2 row 12's
-- \"deciders that fire before any paid scoring\", and it is where the whole
-- saving of that row is.
bundleRejected :: (Decider, [Text])
bundleRejected = (AnyLineStartsWith, ["REJECT:"])

-- | The ranked classification came out at the top band.
--
-- /Source:/ @commands\/discover-bundles.md@ §4's four classes — @Recommend@ (80
-- or more, with no rejection condition), @Review selectively@ (65–79), @Watch@,
-- @Reject@ — and §5, which asks for an integration sketch \"for each recommended
-- candidate\" and therefore for nobody else. The needle is the band, so the
-- sketch is asked once and only when the corpus says to ask for it.
bundleRecommended :: (Decider, [Text])
bundleRecommended = (AnyLineStartsWith, ["RECOMMEND:"])

-- | A retrofit's defect inventory licensed the second of its two verdicts.
--
-- /Source:/ @skills\/denotational-design\/references\/dialog-protocol.md@'s
-- framing points, verbatim: \"The defect inventory licenses __two__ verdicts, not
-- one: fix these defects, or /start over/ — \'this is basically unfixable, thank
-- you very much for showing me so clearly the mistakes that were made in the
-- past.\' A retrofit that ends in a documented start-over recommendation
-- succeeded; say so rather than forcing a repair.\"
--
-- __The cheap ending is the one it decides__, which is the rule the sentinel
-- block above stands under: a start-over verdict ends the run at one phase and
-- asks nothing about representations, meaning functions, proofs or realizations.
-- The needle is 'Workflows.Denote.objectBrief''s own word, which that brief
-- demands on the first line and for exactly this reason.
startOverRecommended :: (Decider, [Text])
startOverRecommended = (AnyLineStartsWith, ["START OVER"])

-- | A drafted document still carries a question for the person who commissioned
-- it.
--
-- /Source:/ @agents\/prd-architect.md@ §3 step 1 (\"highlight areas that need
-- user input with @[TODO: User input needed]@\") and its self-verification
-- checklist's ninth item (\"no @[TODO]@ items remain without user
-- acknowledgment\") — which in the corpus is a box a model ticks about its own
-- document.
--
-- __The needle is a prefix, so the marker has to start a line__, and
-- @'Workflows.Prd.sectionClosing'@ is the other half of the contract: it tells
-- every section to put each open question on a line of its own beginning
-- @[TODO:@, and says why — the lines are read mechanically. That is
-- @'Workflows.Panels.refusingSynthesis'@'s arrangement at a marker the corpus
-- already writes.
--
-- __The cheap ending is the one it decides__, and unusually the cheap ending is
-- also the right one: a draft with open questions in it goes back to the person
-- who can answer them rather than to a reviewer, so the verification budget is
-- not spent on an opinion about a guess.
todosOutstanding :: (Decider, [Text])
todosOutstanding = (AnyLineStartsWith, ["[TODO"])

-- | The query matched nothing.
--
-- /Source:/ @skills\/node-red\/SKILL.md@'s @## Debugging workflow@, whose whole
-- method rests on this one test: query @msg_events@ for the trigger's @onSend@ in
-- the last twenty-four hours, and \"zero rows -> upstream issue. Rows present ->
-- drill in via msgid.\"
--
-- __The needle is @psql@'s own footer__, which is as literal as program text
-- gets: it is printed by the client and no model authored it. Two conclusions the
-- skill draws by reading are two arms here, at zero questions -- and the arm this
-- picks is the one that matters most, because a node that never fired is a node
-- whose configuration was never the problem.
noRowsReturned :: (Decider, [Text])
noRowsReturned = (AnyLineStartsWith, ["(0 rows)"])

-- | A retest sweep found something that blocks.
--
-- /Source:/ @skills\/retest\/SKILL.md@ and @commands\/retest-categorical.md@,
-- whose @REGRESSION@ verdicts are stated as a disjunction — \"any HF
-- @DIVERGE@, any \>5% slowdown, or any blocking review finding\", and
-- \"any byte @DIVERGE@, any in-scope @REACHABILITY-REGRESSION@, or any perf
-- regression above the 5% threshold\".
--
-- __The corpus's disjunction is the decider's disjunction.__
-- @Agentic.Text.runDecider@ takes its needle list with @any@, so a rule written
-- in English as \"any of these three\" is this pair exactly, with no reading
-- between the two. @'Workflows.Retest.gradingBrief'@ is the other half of the
-- contract: it demands one line per non-passing cell, beginning with the verdict
-- word, which is what makes a prefix test exact.
--
-- @REACHABILITY-REGRESSION@ is its own needle and not covered by @REGRESSION@:
-- a needle is a /prefix/, and that line begins with the longer word.
batteryRegressed :: (Decider, [Text])
batteryRegressed =
  ( AnyLineStartsWith,
    ["REGRESSION", "DIVERGE", "REACHABILITY-REGRESSION"]
  )

-- | A retest sweep did not finish.
--
-- /Source:/ the same two @Overall verdict@ sections: \"@INCOMPLETE@ — any
-- @NO-COVERAGE@\/@SKIPPED@\/@WEIGHTS-MISSING@\/@TIMEOUT@, or an
-- empty\/unrunnable derived set\", plus @retest-categorical.md@'s two additions
-- (unresolved @LOCK-CONTENTION@, and a selector @NO-MATCH@, which that file is
-- emphatic must be \"surfaced as NO-MATCH rather than silently counted as a
-- failure\").
--
-- This is the decider @skills\/retest\/SKILL.md@'s claim-discipline paragraph
-- asks for by name: \"report @PASS \/ SKIPPED \/ QUARANTINED \/ DIVERGE \/
-- NO-COVERAGE@ as distinct states — never collapse them into \'N\/N PASS\'\". A
-- grader that collapses them has to write one of these words to have reported
-- them at all, and if it writes one the success ending is unreachable.
batteryIncomplete :: (Decider, [Text])
batteryIncomplete =
  ( AnyLineStartsWith,
    [ "INCOMPLETE",
      "NO-COVERAGE",
      "SKIPPED",
      "WEIGHTS-MISSING",
      "TIMEOUT",
      "NO-MATCH",
      "LOCK-CONTENTION"
    ]
  )

-- | The branch diff implies no model at all.
--
-- /Source:/ @skills\/retest\/SKILL.md@'s @Arguments@ section, verbatim: \"empty
-- diff + no @--all@ — report \'no model-affecting changes detected\'\", read
-- against its own invariant that \"an empty or unrunnable derived set is
-- classified __INCOMPLETE__, never a success\".
--
-- __This one is read off the derivation's answer rather than off the grading__,
-- and that is the whole point of it. The corpus states the rule twice and both
-- times leaves it to whoever writes the summary; here the run's success ending
-- sits behind this test, so a grader that writes @HF-CORRECT@ over a sweep that
-- gated nothing cannot reach the arm that reports it.
noModelSet :: (Decider, [Text])
noModelSet = (AnyLineStartsWith, ["NO MODEL-AFFECTING CHANGES"])
