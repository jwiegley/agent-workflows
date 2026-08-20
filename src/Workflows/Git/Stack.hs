-- |
-- Module      : Workflows.Git.Stack
-- Description : Flagship 5 — restack, rebase, and the rest of the git family.
--
-- __What this replaces.__ Five Markdown files that are one shape and one shared
-- step, plus the three-way prose reference that ties them together:
--
-- +---------------------------------------+-----------------------------------------------+
-- | @~\/src\/nix\/config\/ai@               | here                                          |
-- +=======================================+===============================================+
-- | @commands\/restack.md@ (38 lines)      | rung 'Restack' — nine numbered steps, of      |
-- |                                       | which four become structure and one becomes   |
-- |                                       | an argv                                       |
-- +---------------------------------------+-----------------------------------------------+
-- | @commands\/rebase.md@                  | rung 'Rebase' — the same shape with @git@     |
-- |                                       | deciding instead of @gt@                      |
-- +---------------------------------------+-----------------------------------------------+
-- | @commands\/rebase-and-fix.md@          | rung 'RebaseFix' — 'Rebase' plus the CI gate  |
-- |                                       | and @'Workflows.Fix.Green.botSweepFn'@        |
-- +---------------------------------------+-----------------------------------------------+
-- | @commands\/cleanup.md@                 | rung 'Cleanup' — its four obligations behind  |
-- |                                       | one real hook gate, and its @nix develop@     |
-- |                                       | hedge as part of the argv                     |
-- +---------------------------------------+-----------------------------------------------+
-- | @commands\/resolve.md@                 | 'resolveFn' — the one body every rung calls   |
-- |                                       | and three other files reference by prose      |
-- +---------------------------------------+-----------------------------------------------+
--
-- == The leveling-up, item by item
--
--   1. __\"See also: the resolve workflow is the canonical conflict-resolution
--      step\" becomes a call.__ That sentence is in @restack.md@,
--      @rebase.md@ /and/ @rebase-and-fix.md@, and each of the three then
--      paraphrases the step it just pointed at — so the canonical step exists in
--      four places and has already drifted (@rebase.md@ routes to @haskell-pro@,
--      @rebase-and-fix.md@ to @haskell-pro@ /and/ @cpp-pro@, @restack.md@ adds
--      the orthogonal-combination rule that neither of the others carries).
--      'resolveFn' is one body every rung calls; the routing table is its
--      __argument__, so a rung that wants a different specialist says so at the
--      call site and cannot restate the doctrine.
--
--   2. __\"Do not commit your work when you're done\" becomes a type.__
--      @resolve.md@'s postcondition is an instruction to an agent that has write
--      authority. Here 'resolveFn' answers @'Agentic.Raw.CodeText'@, and
--      @Agentic.Acp.permissionByCode@ grants write authority only to an
--      @'Agentic.Workflow.act'@ at @receipt@ — so the resolver /cannot/ commit,
--      whatever it is told. The same fact discharges @restack.md@ step 5's
--      \"never commit manually and never run @git rebase --continue@ directly\":
--      the only thing in this program that advances a rebase is the program's
--      own argv.
--
--   3. __Check-fix-recheck, where the check is @gt restack@ itself.__
--      @restack.md@ steps 3 through 7 are: run @gt restack@; if a conflict is
--      encountered, resolve it; @gt continue@; repeat for every further
--      conflict; then re-read @gt ls@ and, if anything still needs restacking,
--      go back to step 2. That is exactly 'Workflows.Gates.gate' — and it is
--      better than the prose in the one way that matters: "Agentic.Shell"
--      answers a __verdict__ question by running the argv, so a conflict is a
--      nonzero exit carrying @git@'s __own first failing line__, which the
--      resolver then reads. The fixpoint's bound is 'rungTrips', printed by
--      @wf cost@ before the run, where step 7 says \"return to step 2\" and
--      names no limit at all.
--
--   4. __@GIT_EDITOR=true@ stops being a sentence a model must remember.__
--      @restack.md@ opens with \"Run every @gt@ command with @GIT_EDITOR=true@
--      so nothing blocks waiting on an editor\". "Agentic.Shell" runs an argv
--      with @proc@ and never @sh -c@, so there is no shell to set a variable in
--      — and the fix is better than the wish: every @gt@ party below is
--      @env GIT_EDITOR=true gt …@, one argument list, printed in the plan. The
--      same move retires @cleanup.md@'s \"you may have to use
--      @nix develop --command $COMMAND@\": see 'lefthookPreCommit', where the
--      hedge is the first three arguments.
--
--   5. __The proof of no loss is a decider, not a reading.__ @restack.md@ step 9
--      asks for @git range-diff@ between each branch's recorded pre-restack tip
--      and its new tip, and then asks an agent to \"confirm only the expected
--      adjustments appear\". The range-diff is kept — it is what the report
--      quotes — but the /confirmation/ is 'commitLost': @git cherry HEAD \<tip\>@
--      prints @-@ for a pre-run commit with an equivalent patch in the new head
--      and @+@ for one with none, so \"a commit was lost\" is
--      @anyLineStartsWith [\"+\"]@ over a receipt, at zero questions and one
--      path. See 'commitLost' for why this is not the @containsLine@ the
--      skeleton sketched.
--
--   6. __The run refuses to begin a rewrite it could not later prove.__ The
--      pre-run tip is a program __input__ (tier 1: a decider's needles and a
--      party's argv are literal program text, and no Haskell function may look
--      at an answer — the same argument
--      @'Workflows.Git.Commit.commitProgram'@ makes for its tree). It is
--      resolved by @git rev-parse@ as part of the __baseline__, which is bound
--      before the first @act@ — so an absent or bogus tip abandons the run at
--      question three, with nothing rewritten, rather than at the proof, with
--      everything rewritten and no way to check it.
--
--   7. __Four commands, four prices.__ @restack@, @rebase@, @rebase-and-fix@ and
--      @cleanup@ differ in which command decides, how many trips the fixpoint
--      gets, who resolves, and what the run publishes — all of it ordinary
--      Haskell over the rung. @wf cost stack-rebase@ and
--      @wf cost stack-rebase-fix@ are two numbers side by side, where the
--      Markdown offers two files whose diff is one paragraph.
--
-- == What this module needed and could not have
--
-- __The @gt@ argv belongs in "Workflows.Evidence"__, whose own header states the
-- rule this module is a visible exception to: /every argv in the tree is in that
-- one module, and it is reviewable as a unit/. The builder of this flagship was
-- given a write set that excluded the foundation, so the ten parties under
-- \"The argv\" below are defined here instead. They should be moved, unchanged,
-- into "Workflows.Evidence" — and until they are, the sentence in that module's
-- header is not true of this tree.
--
-- __Likewise the prose.__ The house convention is that a rubric lives in
-- @Workflows.Rubrics.*@ named after its Markdown source. The text transplanted
-- below is @commands\/{restack,rebase,rebase-and-fix,cleanup,resolve}.md@ and
-- wants to be @Workflows.Rubrics.Stack@; it is here for the same reason, and
-- @'Workflows.Git.Commit.commitProgram'@ carries @commit.md@ inline for the
-- same one.
--
-- __Provenance.__ Every define below names the file and the step it came from.
-- @~\/src\/nix\/config\/ai@ is read-only and was read as data; nothing in this
-- module writes to it, and no party in it points at it.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Git.Stack
  ( -- * The rungs
    StackRung (..),
    stackRungName,
    rungTrips,
    rungSpecialists,
    rungFixer,
    rungStack,

    -- * The step every rung calls and three other files point at
    resolveFn,
    stackReportFn,
    stackTable,
    noProof,

    -- * The free proof
    commitLost,

    -- * The programs
    stackProgram,
    stackDoc,
    stackScript,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Fix.Green (botSweepFn)
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The argv
-- ---------------------------------------------------------------------------

-- $argv
--
-- These belong in "Workflows.Evidence" — see the module header. They are
-- grouped here so that the move is one cut and one paste, and so that the
-- exception is visible rather than scattered.
--
-- __Every @gt@ invocation is @env GIT_EDITOR=true gt …@.__ /Source:/
-- @commands\/restack.md@'s opening sentence, which asks for exactly this and can
-- only ask. There is no shell here — "Agentic.Shell" runs an argv with @proc@ —
-- so the variable is set by @env@, which is one more argument and not one more
-- hope.

-- | @gt ls@ — the stack, as Graphite sees it.
--
-- /Source:/ @commands\/restack.md@ step 1 and step 7.
gtLs :: Party 'IsTool
gtLs = tool "gt-ls" `running` ("env", ["GIT_EDITOR=true", "gt", "ls"])

-- | @gt ls -s@ — the same, in the short form @cleanup.md@ names.
--
-- /Source:/ @commands\/cleanup.md@, first clause.
gtLsShort :: Party 'IsTool
gtLsShort = tool "gt-ls-short" `running` ("env", ["GIT_EDITOR=true", "gt", "ls", "-s"])

-- | @gt get@ — sync trunk and the stack from the remote.
--
-- /Source:/ @commands\/restack.md@ step 2.
gtGet :: Party 'IsTool
gtGet = tool "gt-get" `running` ("env", ["GIT_EDITOR=true", "gt", "get"])

-- | @gt restack@ — and, because it is run as a __verdict__, the loop's review.
--
-- /Source:/ @commands\/restack.md@ step 3, with steps 6 and 7 folded in: it is
-- idempotent, so re-running it after a resolution is @gt continue@ followed by
-- the rest of the stack, and re-running it on a clean stack exits @0@ — which
-- is what makes it a fixpoint test as well as the action.
--
-- __A check that writes.__ That is unusual and deliberate, and it is what
-- @restack.md@ describes: the command that advances the restack is the command
-- whose exit code says whether the restack is finished. The alternative — a
-- separate read-only probe — would be a second question per trip that answers
-- the same fact later.
gtRestack :: Party 'IsTool
gtRestack = tool "gt-restack" `running` ("env", ["GIT_EDITOR=true", "gt", "restack"])

-- | @gt submit --stack@.
--
-- /Source:/ @commands\/restack.md@ step 8.
gtSubmitStack :: Party 'IsTool
gtSubmitStack =
  tool "gt-submit" `running` ("env", ["GIT_EDITOR=true", "gt", "submit", "--stack"])

-- | @git fetch --all --prune@ — the plain-git rungs' equivalent of @gt get@.
gitFetchAll :: Party 'IsTool
gitFetchAll = tool "git-fetch" `running` ("git", ["fetch", "--all", "--prune"])

-- | @git for-each-ref@ over the local heads: every branch, and its tip.
--
-- /Source:/ @commands\/restack.md@ step 1, which asks for \"each stack branch's
-- tip SHA (@git rev-parse \<branch\>@)\" — a loop over branches, which is one
-- argv here and therefore one receipt rather than a number of them nobody
-- counted.
gitBranchTips :: Party 'IsTool
gitBranchTips =
  tool "git-branch-tips"
    `running` ("git", ["for-each-ref", "--format=%(objectname) %(refname:short)", "refs/heads"])

-- | @git merge-base --is-ancestor TRUNK HEAD@ — \"is this branch fully rebased?\"
-- as an exit code.
--
-- /Source:/ @commands\/rebase.md@'s \"Continue until the branch is fully
-- rebased\", which is a __postcondition__ and is written here as one. It is the
-- rebase rungs' loop review, and it is a postcondition rather than the action
-- (@git rebase@) on purpose: a rebase interrupted by a conflict cannot be
-- restarted by re-running @git rebase@, so an action-as-check would object
-- forever on the second trip. The test below is idempotent and true exactly when
-- the work is done.
gitIsAncestor :: Text -> Party 'IsTool
gitIsAncestor trunk =
  tool "git-rebased" `running` ("git", ["merge-base", "--is-ancestor", trunk, "HEAD"])

-- | @git cherry HEAD TIP@ — the proof of no loss, as lines a decider can read.
--
-- /Source:/ @commands\/restack.md@ step 9's \"evidence that no meaningful
-- changes were lost\". For every commit reachable from @TIP@ (the pre-run tip),
-- @git cherry@ prints @-@ when an equivalent patch exists in @HEAD@ and @+@ when
-- none does. So a @+@ line /is/ a lost commit. See 'commitLost'.
gitCherry :: Text -> Party 'IsTool
gitCherry tip = tool "git-cherry" `running` ("git", ["cherry", "HEAD", tip])

-- | @nix develop --command lefthook run --all-files pre-commit@.
--
-- /Source:/ @commands\/cleanup.md@, whose two sentences are \"ensure that
-- @lefthook run --all-files pre-commit@ runs for each\" branch and \"you may
-- have to use @nix develop --command $COMMAND@ to run lefthook\". The hedge is
-- the first three arguments of the argv, so there is nothing left to may-have-to
-- about: this is the command, it is printed in the plan, and its exit code is
-- the gate.
lefthookPreCommit :: Party 'IsTool
lefthookPreCommit =
  tool "lefthook"
    `running` ( "nix",
                ["develop", "--command", "lefthook", "run", "--all-files", "pre-commit"]
              )

-- ---------------------------------------------------------------------------
-- The free proof
-- ---------------------------------------------------------------------------

-- | A commit that was in the pre-run tip and has no equivalent in the new head.
--
-- __Why this and not the @containsLine [\"=  \"]@ the design sketched.__
-- @'Agentic.Text.ContainsLine'@ is exact line equality over a trimmed, @bare@d,
-- lowercased line, so no needle of the form @\"=  \"@ can ever match a
-- @git range-diff@ row — and a test that is constantly false is a proof that
-- always passes, which is the one failure mode a proof-of-no-loss must not
-- have. @git cherry@'s output is one marker per line in the first column, which
-- is precisely the shape @'Agentic.Text.AnyLineStartsWith'@ reads; @+@ and @-@
-- are both in the set @'Agentic.Text.bare'@ is pinned never to drop.
--
-- Used __negated__: the rewrite is intact when this is false.
commitLost :: (Decider, [Text])
commitLost = (AnyLineStartsWith, ["+"])

-- ---------------------------------------------------------------------------
-- The rungs
-- ---------------------------------------------------------------------------

-- | Four of the owner's commands over one shape.
data StackRung
  = -- | @commands\/restack.md@
    Restack
  | -- | @commands\/rebase.md@
    Rebase
  | -- | @commands\/rebase-and-fix.md@
    RebaseFix
  | -- | @commands\/cleanup.md@
    Cleanup

-- | The name the operator types, and the name "Workflows.Registry" registers.
stackRungName :: StackRung -> Text
stackRungName Restack = "stack"
stackRungName Rebase = "stack-rebase"
stackRungName RebaseFix = "stack-rebase-fix"
stackRungName Cleanup = "stack-cleanup"

-- | How many trips the fixpoint is given.
--
-- __Tier 1__: the rung is in the invocation, so this is ordinary Haskell and
-- costs zero questions and zero paths. It is the number @restack.md@ step 7
-- declines to state — \"return to step 2\" — and the number @rebase.md@ hides
-- inside \"continue until the branch is fully rebased\".
rungTrips :: StackRung -> Bound
rungTrips Restack = atMost 3
rungTrips Rebase = atMost 3
rungTrips RebaseFix = atMost 3
rungTrips Cleanup = atMost 2

-- | Who resolves what, when the invocation did not say.
--
-- __House rule WR-1__: an input nobody gave is @\"\"@, and @\"\"@ means /the
-- rung's own default/ and never /nobody/. The defaults are the corpus's, file by
-- file, and they are the drift this function ends: @rebase.md@ names
-- @haskell-pro@ alone, @rebase-and-fix.md@ names @haskell-pro@ and @cpp-pro@,
-- and @restack.md@ names both plus the rule about trivial comment-only
-- conflicts.
rungSpecialists :: StackRung -> Text -> Text
rungSpecialists rung given
  | not (T.null (T.strip given)) = T.strip given
  | otherwise = defaultsFor rung
  where
    defaultsFor Rebase =
      "Route Haskell conflicts to haskell-pro. Anything else, resolve directly."
    defaultsFor Cleanup =
      "This run resolves no conflicts of its own: it runs the repository's \
      \pre-commit hooks over every branch in the stack and then restacks. It is \
      \that closing restack that can conflict. Route Haskell conflicts to \
      \haskell-pro and C++ conflicts to cpp-pro, and say so briefly rather than \
      \at length -- there may be nothing to resolve at all."
    defaultsFor _ =
      "Route Haskell conflicts to haskell-pro and C++ conflicts to cpp-pro. \
      \Trivial comment-only conflicts may be resolved directly, without routing."

-- | Who repairs, when the advancing command objects.
--
-- Every rung's fixer is on the reasoning rung of the fail-over ladder, and the
-- addressee's __name__ differs so that a trace says which job it was doing. That
-- is the whole of what @'Workflows.Parties.reasoning'@ costs to write here:
-- nothing, because an alternate is not part of the question.
rungFixer :: StackRung -> Party 'IsModel
rungFixer Cleanup = reasoning (model "cleanup")
rungFixer _ = reasoning (model "restack")

-- | The command whose exit code is the fixpoint's review.
--
-- This is the whole difference between the rungs' loops, and it is one function.
rungAdvance :: StackRung -> Text -> Party 'IsTool
rungAdvance Restack _ = gtRestack
rungAdvance Rebase trunk = gitIsAncestor trunk
rungAdvance RebaseFix trunk = gitIsAncestor trunk
rungAdvance Cleanup _ = lefthookPreCommit

-- | Which spelling of the stack listing the rung's baseline records.
--
-- @cleanup.md@ names @gt ls -s@ and the other three name @gt ls@. One receipt,
-- two argv, and the difference is the one the owner already wrote down.
rungStack :: StackRung -> Party 'IsTool
rungStack Cleanup = gtLsShort
rungStack _ = gtLs

-- | The command that syncs before anything is rewritten.
rungSync :: StackRung -> Party 'IsTool
rungSync Restack = gtGet
rungSync Cleanup = gtGet
rungSync Rebase = gitFetchAll
rungSync RebaseFix = gitFetchAll

-- | The command the run ends by publishing through.
rungPublish :: StackRung -> Party 'IsTool
rungPublish Restack = gtSubmitStack
rungPublish Rebase = gitPushLease
rungPublish RebaseFix = gitPushLease
rungPublish Cleanup = gtRestack

-- ---------------------------------------------------------------------------
-- The prose, transplanted
-- ---------------------------------------------------------------------------

-- | @commands\/resolve.md@, whole, plus @restack.md@ step 4's three-way reading
-- and its orthogonal-combination rule.
--
-- The one sentence deliberately dropped is @resolve.md@'s \"Do not commit your
-- work when you're done\": this function answers @text@ and has no write
-- authority, so saying it would be describing the type. What is kept is the part
-- that is a /judgment/ — what a good resolution preserves.
resolveRule :: Text
resolveRule =
  [wft|
  Resolve the merge conflicts described below in a way that preserves the
  semantics of the incoming changes, while maintaining the intent of the work
  they are being applied onto.

  For each conflict: identify which commit is being applied onto which branch,
  and read the three-way diff3 -- HEAD, the parent of the commit being applied,
  and the incoming commit -- rather than the two-way conflict block alone. The
  two-way block cannot distinguish "they changed it" from "we changed it back".

  When each side added something orthogonal -- a parameter, a field, a clause,
  an import, a case arm -- combine both sides rather than picking one. Picking
  one is the failure mode that survives every test and loses a feature.

  Answer with the resolution doctrine for this run and nothing else: for each
  conflict you are shown, the file, what each side was doing, and the resolved
  text. Where you are shown no conflict yet, answer with how you will resolve
  the ones this stack is likely to produce, given the branches and the work in
  them.|]

-- | The standing constraint on how the resolution reaches the tree.
--
-- /Source:/ @commands\/restack.md@ step 5 and @commands\/resolve.md@'s closing
-- clause. It is in the prompt even though it is also a type, for the reason
-- @'Workflows.Audit.Fess.fessAudit'@ keeps Operating Rule 1: a model that knows
-- it is not the thing advancing the rebase writes a different answer.
stagingRule :: Text
stagingRule =
  [wft|
  The resolved files are marked resolved with `git add` and nothing more. Do
  not commit. Do not run `git rebase --continue`, `gt continue` or any other
  command that advances the operation: something else in this run does that,
  and its exit code is what decides whether your resolution worked.|]

-- | What the fixpoint's fixer is told, beside the failing line.
--
-- /Source:/ @commands\/restack.md@ steps 4 through 7 for the two @gt@ rungs and
-- @commands\/rebase.md@ for the plain-git ones, reduced to the part that is
-- about /this trip/. 'Workflows.Gates.gate' splices the check's own objection
-- and the candidate below it.
rungRepair :: StackRung -> Text
rungRepair Cleanup =
  [wft|
  The repository's pre-commit hook suite was run over every file and objected.
  Its own first failing line is below.

  Fix the cause it names, for every branch in the stack. Where the fix is a
  formatting run, amend the result into that branch's own commit rather than
  adding a commit on top -- a stack whose formatting lives in a follow-up
  commit is a stack whose every commit fails the hook on its own. Remove any
  empty commit you find while you are there.

  Do not disable a hook, do not add a file to an ignore list, and do not pass
  a skip flag. Answer with the corrected state of the stack and nothing else.|]
rungRepair Restack =
  [wft|
  {advancing}

  {rerere}|]
  where
    advancing = advancingObjected
    rerere = rerereNote
rungRepair _ =
  [wft|
  {advancing}

  {descendants}

  {rerere}|]
  where
    advancing = advancingObjected
    descendants = descendantRule
    rerere = rerereNote

-- | The part of a repair brief every non-'Cleanup' rung shares.
--
-- /Source:/ @commands\/restack.md@ steps 4-6 and @commands\/rebase.md@'s
-- \"continue until the branch is fully rebased\", reduced to what is about
-- /this trip/. 'Workflows.Gates.gate' splices the check's own objection and the
-- candidate below it.
advancingObjected :: Text
advancingObjected =
  [wft|
  The command that advances this rewrite objected, and its own first failing
  line is below. Almost always that is a conflict.

  Resolve it the way the doctrine below directs, mark the resolved files with
  `git add`, and answer with the doctrine updated to record what you just did:
  the branch, the commit being applied, the files, how each conflict was
  resolved, and what you checked afterwards. That running record is what the
  final report is written from, so a conflict resolved and not written down is
  a conflict the report cannot account for.

  Do not weaken the change to make it apply. A conflict resolved by deleting
  the incoming side is the loss this run exists to prevent.|]

-- | /Source:/ @commands\/restack.md@ step 7's parenthesis.
rerereNote :: Text
rerereNote =
  "`git rerere` is enabled, so a resolution you make once is replayed \
  \automatically the next time the same conflict appears. Resolve it right the \
  \first time; you are not going to be asked again."

-- | /Source:/ @commands\/rebase.md@ and @commands\/rebase-and-fix.md@, their
-- three shared bullets.
descendantRule :: Text
descendantRule =
  [wft|
  If there are branches between this one and the trunk, rewrite all of them
  back to the trunk, and make the rewritten commits the new head of their
  respective branches, so that the branch-to-commit relationship survives the
  rewrite. A descendant left pointing at a pre-rewrite commit is a pull request
  that silently stops describing its branch.|]

-- | What the @gt ls@ receipt is introduced as.
--
-- /Source:/ @commands\/restack.md@ step 1, first half.
stackBrief :: Text
stackBrief =
  "The stack as Graphite reports it, before anything is touched: every branch, \
  \its parent, and whether it needs restacking."

-- | What the branch-tips receipt is introduced as.
--
-- /Source:/ @commands\/restack.md@ step 1, second half.
tipsBrief :: Text
tipsBrief =
  "Every local branch and the object id of its tip, before anything is touched. \
  \This is the record the closing proof is measured against."

-- | What the pre-run tip receipt is introduced as.
tipBrief :: Text
tipBrief =
  "The pre-run tip of this branch, resolved. If this question failed, the run \
  \stops here -- which is the point: a rewrite whose starting point cannot be \
  \named is a rewrite nothing can prove afterwards."

-- | What the sync act is told.
--
-- /Source:/ @commands\/restack.md@ step 2.
syncBrief :: Text
syncBrief =
  "Sync the trunk and the stack from the remote before anything is rewritten, \
  \then reply DONE."

-- | What the range-diff receipt is introduced as.
--
-- /Source:/ @commands\/restack.md@ step 9, which names this command.
proofBrief :: Text
proofBrief =
  [wft|
  `git range-diff` between this branch's recorded pre-run tip and its new tip:
  commit by commit, what the rewrite did. A row marked `=` is unchanged, `!` is
  changed, and a row with a `-:` on either side is a commit that exists on only
  one side.

  The baseline this is measured against, captured before anything was touched:|]

-- | What the @git cherry@ receipt is introduced as.
cherryBrief :: Text
cherryBrief =
  [wft|
  `git cherry` over the pre-run tip against the new head: one line per commit
  that was in this branch before the rewrite. A line beginning `-` is a commit
  whose patch survives in the new head; a line beginning `+` is a commit with
  no equivalent in the new head, which is a commit that was lost.|]

-- | What the closing publish act is told, by rung.
publishBrief :: StackRung -> Text
publishBrief Restack =
  "The stack is restacked, green, and proved intact. Submit the whole stack, \
  \then reply DONE. The proof:"
publishBrief Cleanup =
  "Every branch's hooks pass and nothing was lost. Restack the whole stack so \
  \the amended commits are the ones the pull requests describe, then reply DONE. \
  \The proof:"
publishBrief _ =
  "The branch is rebased, green, and proved intact. Push it and every descendant \
  \that was rewritten, with a lease so a push cannot overwrite somebody else's \
  \work on the ref, then reply DONE. The proof:"

-- | What the bot inventory question asks for.
--
-- /Source:/ @commands\/rebase-and-fix.md@'s closing paragraph, which is
-- @commands\/bugbot.md@'s protocol referenced in one sentence.
-- @'Workflows.Fix.Green.botSweepFn'@ is the protocol; this is only the ledger it
-- is handed, bound __once__, after the push, so a comment arriving during the
-- sweep has no way in.
inventoryBrief :: Text
inventoryBrief =
  [wft|
  This is the pull request's own record, as JSON, straight from the GitHub API,
  read after the rewritten branch was pushed. Build the complete inventory of
  unresolved automated-review items in it, as a numbered checklist: number,
  author, category, file and line where applicable, and a one-line summary.

  If there are zero such items, reply with exactly

    No unresolved bot comments found

  and nothing else.|]

-- | The exclusion policy, as an argument rather than a quoted paragraph.
--
-- /Source:/ @commands\/rebase-and-fix.md@ (\"BugBot, Cursor or Devin comments\")
-- and @commands\/bugbot.md@'s bold line. It is an argument so that this caller
-- and @green-ci@'s cannot disagree about it without the difference being visible
-- at two call sites.
botExclusions :: Text
botExclusions =
  "Exclude every human author, without exception. This sweep exists because a \
  \rewrite invalidated what the bots had said; a colleague's review comment is \
  \not this run's business, and replying to one on a bot's behalf is how an \
  \automated sweep starts answering a person."

-- | The report's own shape.
--
-- /Source:/ @commands\/restack.md@ step 9, which is the corpus's most concrete
-- report specification and is carried close to verbatim.
stackReportBrief :: Text
stackReportBrief =
  [wft|
  Write the complete summary of this run.

  1. Provenance -- the line you were given, verbatim, first and unedited.
  2. Every conflict encountered: branch, commit, files.
  3. How each was resolved, and how the resolution was verified.
  4. The evidence that no meaningful change was lost or broken: quote the rows
     of the range-diff that are not `=`, and say for each why the adjustment
     was expected. Do not summarise the range-diff as "as expected".
  5. What is left: anything a person still has to do.

  Keep raw command output out of the report except where a short excerpt is the
  evidence. If nothing went wrong, keep the report short rather than inflating
  it.|]

-- ---------------------------------------------------------------------------
-- The provenance lines the two arms differ in
-- ---------------------------------------------------------------------------

-- | The rewrite finished, was green, and lost nothing.
intactNote :: StackRung -> Text
intactNote rung =
  "Outcome: CLEAN. The rung `"
    <> stackRungName rung
    <> "` reached its fixpoint, the repository's own green gate approved the \
       \result, and `git cherry` found an equivalent of every pre-run commit in \
       \the new head. Nothing was lost, and that is a receipt rather than a \
       \reading."

-- | The rewrite finished and was green, and something is missing.
--
-- The arm @restack.md@ has no words for: its step 9 asks for evidence and
-- assumes the evidence will be good.
lossNote :: StackRung -> Text
lossNote rung =
  "Outcome: A COMMIT WAS LOST. The rung `"
    <> stackRungName rung
    <> "` reached its fixpoint and the green gate approved the result, but \
       \`git cherry` reports at least one commit from the pre-run tip with no \
       \equivalent patch in the new head. Nothing has been published. Name every \
       \`+` line, say what that commit did, and say where it went; the reflog and \
       \the recorded tip below are both still valid. Do not describe this run as \
       \finished."

-- | The fixpoint ran out.
--
-- /Source:/ @'Workflows.Escalation.remainsNote'@, specialised. The sentence
-- about what was /not/ asked for is kept: an exhausted revision yields the
-- candidate the last amendment produced and the final review objected to.
fixpointNote :: StackRung -> Text
fixpointNote rung =
  "Outcome: FIXPOINT NOT REACHED. The trip budget for rung `"
    <> stackRungName rung
    <> "` ran out with the advancing command still objecting. Every resolution \
       \made is still in the tree and the running record below is what the last \
       \trip produced; no trip was spent answering the final objection. Say which \
       \branch and which commit it stopped on, and what it was objecting to. The \
       \baseline is the record of where this started."

-- | The build gate ran out.
stillRedNote :: StackRung -> Text
stillRedNote rung =
  "Outcome: REWRITTEN, STILL RED. The rung `"
    <> stackRungName rung
    <> "` reached its fixpoint, and the repository's own green gate still \
       \objects after every repair trip this run was given. Nothing has been \
       \published. The rewrite is real and is in the tree; report it as \
       \unfinished, and name the check that is red and the line it failed on."

-- | The CI gate after the push ran out.
--
-- /Source:/ @commands\/rebase-and-fix.md@'s \"monitor until everything passes\",
-- which is a loop with no end. This is the end.
ciStillRedNote :: Text
ciStillRedNote =
  "Outcome: PUSHED, CI STILL RED. The rewritten branch was pushed and proved \
  \intact, and the pull request's checks still fail after every repair trip this \
  \run was given. The bot sweep was not run: a sweep that replies to review \
  \comments on a red branch is answering questions the next push will change. \
  \Name the failing check and the line it failed on."

-- ---------------------------------------------------------------------------
-- The step every rung calls, and the report every arm calls
-- ---------------------------------------------------------------------------

-- | @commands\/resolve.md@, as the one thing every rung calls.
--
-- One parameter, and it is the routing table: which specialist takes which
-- conflict. That is the only thing the three files referencing this step in
-- prose actually differ about, so it is the only thing a caller gets to say.
--
-- __Four callers, where the design predicted three.__ @cleanup.md@ was expected
-- not to need it, and it does: its closing @gt restack@ is exactly where a
-- cleanup conflicts, and 'rungSpecialists' says so at that call site rather than
-- leaving the fourth rung with no doctrine at the one moment it needs one.
--
-- __The result kind is the postcondition.__ @'Agentic.Raw.CodeText'@, so the
-- resolver reads and judges and cannot write; @resolve.md@'s \"do not commit\"
-- is the type of this function rather than a line in its prompt.
--
-- __What registering it costs:__ nothing. @rhsAsks@ prices a call at the
-- callee's own @bodyAsks@ and @graft@ splices the callee's node rather than
-- adding one, so all four rungs share this body at no charge.
resolveFn :: Fn '[ 'CodeText] 'CodeText
resolveFn =
  function
    "git.resolve"
    (takes @"agents" Text $ noParams)
    \agents -> W.do
      merged <- ask (reasoning (model "resolve")) [wf|
          {resolveRule}

          {stagingRule}

          Who takes which conflict:

          {agents}|]
      answer merged

-- | The report every ending calls, one argument apart.
--
-- Three parameters in the order the body reads them. @provenance@ is last
-- because it is what the arms differ in and the reader of a call site should
-- meet it where the difference is; it is __first__ in the prompt, because a
-- report that did not establish something does not get to imply it.
--
-- @baseline@ is the handle bound at depth zero, so every ending — clean, lossy,
-- unsettled, red — carries the record of where the run started. That is
-- @restack.md@ step 1's stated purpose (\"so the final report can prove nothing
-- was lost\"), and in Markdown it is a request to remember across a page of
-- steps.
stackReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText, 'CodeText] 'CodeAck
stackReportFn =
  function
    "stack.report"
    ( takes @"baseline" Text
        . takes @"state" Text
        . takes @"proof" Text
        . takes @"provenance" Text
        $ noParams
    )
    \baseline state proof provenance -> W.do
      act reporter [wf|
          {stackReportBrief}

          {provenance}

          The baseline, captured before anything was touched:

          {baseline}

          The record of what this run resolved and verified:

          {state}

          The proof of no loss:

          {proof}

          Write the report, then reply DONE.|]
      done

-- | What the two endings that never reached the proof pass in its place.
--
-- A 'Data.Text.Text' argument, which prints as a literal at the call site, so
-- the two arms are still one report one argument apart. This is
-- @'Workflows.Rubrics.Discipline.unverifiedIndependence'@'s shape borrowed from
-- flagship 4: __a report that did not establish something does not get to imply
-- it__, and an absent proof said out loud is what stops section 4 of
-- 'stackReportBrief' from being answered from the record instead of from the
-- receipt.
noProof :: Text
noProof =
  [wft|
  None. This run did not reach the point where the rewrite could be measured,
  so no `git range-diff` and no `git cherry` were produced. Section 4 of the
  report says exactly that. Do not infer from the record above that nothing was
  lost: nothing checked.|]

-- | The table 'stackProgram' hands @'Agentic.Workflow.defining'@.
--
-- Three entries. Every rung calls 'resolveFn' and 'stackReportFn'; only
-- 'RebaseFix' calls @'Workflows.Fix.Green.botSweepFn'@, and a declared callee a
-- given rung does not reach costs nothing — which is what
-- @'Workflows.Fix.Green.greenProgram'@ does with the report pair. One table for
-- the family, so a callee cannot be half-registered.
stackTable :: [SomeFn]
stackTable = [SomeFn resolveFn, SomeFn stackReportFn, SomeFn botSweepFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | The rev the proof is measured from, and the one place this module decides
-- what an absent input means.
--
-- __Why the pre-run tip is an input and not a receipt.__ It is argv, and argv is
-- literal program text: no Haskell function may look at an answer, so a receipt
-- cannot become the argument of a later command. The fact is in the invocation —
-- @--input-arg tip="$(git rev-parse HEAD)"@, run before the rewrite — so it
-- belongs in the invocation. This is the same argument
-- @'Workflows.Git.Commit.commitProgram'@ makes for its tree, and the two should
-- be read together.
--
-- An absent input becomes a rev no command can resolve, which is deliberate and
-- is why the resolution is part of the __baseline__: @git rev-parse@ exits
-- nonzero, "Agentic.Shell" abandons the @text@ ask, and the run stops before its
-- first @act@ — with nothing rewritten. @wf plan stack@ with no inputs prints the
-- rev it will try, so an operator who forgot the flag learns it from the plan.
tipRef :: Text -> Text
tipRef t
  | T.null (T.strip t) = "<no tip given>"
  | otherwise = T.strip t

-- | The trunk the rewrite is measured against; @main@ when nobody said.
trunkRef :: Text -> Text
trunkRef t
  | T.null (T.strip t) = "main"
  | otherwise = T.strip t

-- | How many trips the post-rewrite green gate is given.
--
-- /Source:/ @commands\/restack.md@ step 5, which asks that every resolution be
-- verified by a real build before moving on. The grammar's charge, stated rather
-- than hidden: a revision's body holds exactly one review and one amendment, so
-- \"verify, then proceed\" cannot live /inside/ each trip. It lives in the
-- amendment's prompt (see 'rungRepair') and the real build stands outside the
-- loop, once, over the settled result.
buildTrips :: Bound
buildTrips = atMost 2

-- | The whole family: baseline, sync, doctrine, fixpoint, build, proof, publish.
--
-- Four inputs. @trunk@ is what the rewrite is brought up to date with (@main@
-- when absent); @tip@ is this branch's tip __before__ the run — see 'tipRef';
-- @agents@ is the routing table 'resolveFn' is called with — see
-- 'rungSpecialists'; @pr@ is the pull request the @stack-rebase-fix@ rung
-- watches afterwards, and is ignored by the other three.
--
-- __One body, four rungs.__ Everything that separates @restack@, @rebase@,
-- @rebase-and-fix@ and @cleanup@ is a tier-1 Haskell function of the rung —
-- 'rungSync', 'rungSpecialists', 'rungAdvance', 'rungRepair', 'rungFixer',
-- 'rungTrips', 'rungPublish' — and the /only/ structural difference in the tree
-- is @stack-rebase-fix@'s tail, which is the last @case@ below. That is the
-- claim these four Markdown files make about themselves and cannot check: they
-- are one procedure with four settings.
--
-- __Why the shared tail is inline and not a Haskell helper.__ It was written as
-- one first, and it does not typecheck: @'Agentic.Builder.KnownIx' h s@ is
-- weakened one entry at a time by an instance GHC can only pick when the scope
-- is /concrete/, so a helper taking @V hb 'CodeText@ and binding four more names
-- before reading it cannot state its own constraint without spelling the exact
-- shape of the scope at every use — a signature that changes whenever a
-- statement is added. Inlining is what the language asks for here, and one body
-- for four rungs is what keeps it from being duplication.
--
-- __Where the price comes from.__ Three baseline receipts, one sync act, one
-- call, a bounded fixpoint, a bounded build gate, two proof receipts, a publish
-- act and a report — and the loss branch adds a path without adding a question,
-- because @'Agentic.Workflow.decide'@ asks nobody.
stackProgram :: StackRung -> Parameterized
stackProgram rung =
  taking (input "trunk" :> input "tip" :> input "agents" :> input "pr" :> noInputs)
    \trunk tip agents pr ->
      let trunkV = trunkRef trunk
          tipV = tipRef tip
       in defining stackTable W.do
            -- STEP 1. The baseline, bound at depth zero and live for the whole
            -- run: every ending below reads this handle, which is what
            -- `restack.md` step 1 asks for and what a page of Markdown steps can
            -- only request be remembered.
            baseline <- stackBaseline rung tipV

            -- STEP 2. Sync — and only now is anything allowed to move. The
            -- baseline above is what makes that ordering worth stating: the
            -- pre-run tip is resolved before the first act, so a run that cannot
            -- name where it started never starts.
            act (rungSync rung) [wf|{syncBrief}|]

            -- STEP 4, called and not copied. `resolve.md` is the canonical
            -- conflict-resolution step that three other files point at in prose;
            -- here it is one body, and the routing table is its argument.
            doctrine <- call resolveFn (arg (rungSpecialists rung agents) :> noArgs)

            -- STEPS 3, 6 and 7: run the advancing command and, while it objects,
            -- hand its own failing line to the resolver. The candidate is the
            -- doctrine, amended each trip into the running record of what was
            -- resolved -- which is what the report is written from, and which is
            -- what an exhausted revision yields rather than discards.
            settled <-
              gate
                (rungAdvance rung trunkV)
                (rungRepair rung)
                (rungFixer rung)
                doctrine
                (rungTrips rung)

            case settled of
              Settled state -> W.do
                -- STEP 5, properly: the resolutions verified by a real build,
                -- with the build's own failing line as the objection.
                built <- gate nixFlakeCheck repairBrief (reasoning (model "repair")) state buildTrips

                case built of
                  Settled tree -> W.do
                    -- STEP 9, first half: the receipt the report quotes.
                    proof <- ask (gitRangeDiff trunkV tipV "HEAD") [wf|
                        {proofBrief}

                        {baseline}|]

                    -- STEP 9, second half: the receipt a decider can read.
                    equiv <- ask (gitCherry tipV) [wf|{cherryBrief}|]
                    lost <- tested commitLost equiv

                    -- Both arms written, because a branch is terminal -- and the
                    -- arm `restack.md` has no words for is this one's true half,
                    -- where the evidence it asks for comes back bad.
                    if lost
                      then W.do
                        call_ stackReportFn (arg baseline :> arg tree :> arg proof :> arg (lossNote rung) :> noArgs)
                        stop
                      else case rung of
                        -- `rebase-and-fix.md`'s second half, which is the entire
                        -- difference between it and `rebase.md`: push, watch the
                        -- checks, then sweep the bots whose comments the rewrite
                        -- invalidated.
                        RebaseFix -> W.do
                          act (rungPublish rung) [wf|
                              {publishFix}

                              {proof}|]

                          ci <- gate (ghPrChecks pr) repairBrief (reasoning (model "repair")) proof buildTrips

                          case ci of
                            Settled after -> W.do
                              -- The ledger, bound once and after the push, so
                              -- the sweep is scoped to what the rewrite
                              -- invalidated and a comment arriving during it has
                              -- no way in.
                              inventory <- ask (ghPrView pr) [wf|{inventoryBrief}|]
                              call_ botSweepFn (arg inventory :> arg botExclusions :> noArgs)
                              call_ stackReportFn (arg baseline :> arg after :> arg proof :> arg (intactNote rung) :> noArgs)
                              stop
                            Unsettled after -> W.do
                              call_ stackReportFn (arg baseline :> arg after :> arg proof :> arg ciStillRedNote :> noArgs)
                              stop
                        _ -> W.do
                          act (rungPublish rung) [wf|
                              {publishPlain}

                              {proof}|]
                          call_ stackReportFn (arg baseline :> arg tree :> arg proof :> arg (intactNote rung) :> noArgs)
                          stop
                  Unsettled tree -> W.do
                    call_ stackReportFn (arg baseline :> arg tree :> arg noProof :> arg (stillRedNote rung) :> noArgs)
                    stop
              Unsettled state -> W.do
                call_ stackReportFn (arg baseline :> arg state :> arg noProof :> arg (fixpointNote rung) :> noArgs)
                stop
  where
    publishFix = publishBrief RebaseFix
    publishPlain = publishBrief rung

-- | STEP 1, as one handle folding the three receipts it takes.
--
-- @gt ls@, every branch's tip, and the pre-run tip resolved — the third of which
-- is the one that can fail, and it is asked here so that it fails __before__ the
-- sync act rather than after the rewrite. See 'tipRef'.
--
-- One handle and three questions, because @restack.md@ step 1 asks for two
-- things (\"capture @gt ls@ /and/ each stack branch's tip SHA\") and this
-- program needs a third that the file never thought to want.
stackBaseline :: StackRung -> Text -> Rhs s 'CodeText
stackBaseline rung tip =
  panelText
    [ ("stack", ask (rungStack rung) [wf|{stackBrief}|]),
      ("tips", ask gitBranchTips [wf|{tipsBrief}|]),
      ("tip", ask (gitRevParse tip) [wf|{tipBrief}|])
    ]

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside each rung.
stackDoc :: StackRung -> Text
stackDoc Restack =
  "restack.md: `gt restack` to a fixpoint, then prove no commit was lost, then submit"
stackDoc Rebase =
  "rebase.md: rebase onto the trunk to a fixpoint, prove nothing was lost, push with a lease"
stackDoc RebaseFix =
  "rebase-and-fix.md: stack-rebase, then the PR's checks green, then the bot sweep"
stackDoc Cleanup =
  "cleanup.md: `lefthook run --all-files pre-commit` green on every branch, then `gt restack`"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction.
--
-- Only the /text/ questions need entries — @'Agentic.Exec.scriptedDefault'@
-- answers a flag @yes@, a verdict @APPROVE@ and a receipt @DONE@, so both gates
-- approve on their first check and the run walks the settled arms. The repair
-- rows are written anyway: they are the prompts a second trip would send, and a
-- table that only covers the path taken goes stale the first time a gate
-- objects.
--
-- __'cherryBrief''s row is the load-bearing one.__ Its answer decides which arm
-- of the proof branch a scripted run takes: every line begins @-@, so
-- 'commitLost' is false and the run walks the /intact/ arm, which is the arm an
-- operator wants evidence about. Change one @-@ to a @+@ and the lossy arm runs
-- — which is how that branch is exercised without a repository.
stackScript :: StackRung -> [(Text, Text)]
stackScript rung =
  [ (stackBrief, scriptedStack),
    (tipsBrief, scriptedTips),
    (tipBrief, scriptedTip),
    (resolveRule, scriptedDoctrine),
    (rungRepair rung, scriptedRepair),
    (repairBrief, scriptedRepair),
    (proofBrief, scriptedProof),
    (cherryBrief, scriptedCherry),
    (inventoryBrief, scriptedInventory)
  ]
  where
    scriptedStack =
      "◉ feat/token-refresh (needs restack)\n\
      \◯ feat/token-validate\n\
      \◯ main"
    scriptedTips =
      "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678 feat/token-refresh\n\
      \b2c3d4e5f60718293a4b5c6d7e8f90123456789a feat/token-validate\n\
      \c3d4e5f60718293a4b5c6d7e8f90123456789ab2 main"
    scriptedTip = "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678"
    scriptedDoctrine =
      "Doctrine for this stack. src/token.rs is touched by both branches: \
      \feat/token-validate adds the validator, feat/token-refresh adds the \
      \rotation call. Both additions are orthogonal (a new function and a new \
      \call site), so a conflict there is combined, never chosen between. \
      \Haskell conflicts route to haskell-pro; there are none in this stack."
    scriptedRepair =
      "Resolved src/token.rs on feat/token-refresh: kept the incoming validator \
      \and the current rotation call, both. Marked resolved with `git add`. \
      \Nothing committed."
    scriptedProof =
      "1:  a1b2c3d =  1:  9f8e7d6 Extract token validation into a module\n\
      \2:  b2c3d4e !  2:  8e7d6c5 Implement refresh token rotation"
    -- Every line begins `-`: every pre-run commit has an equivalent in the new
    -- head, so nothing was lost and the intact arm is the one that runs.
    scriptedCherry =
      "- a1b2c3d4e5f60718293a4b5c6d7e8f9012345678\n\
      \- b2c3d4e5f60718293a4b5c6d7e8f90123456789a"
    scriptedInventory =
      "1. cursor[bot] — review thread — src/token.rs:44 — the rotation call \
      \ignores the validator's error.\n\
      \2. graphite-app[bot] — top-level comment — the stack was rewritten; \
      \re-request review."
