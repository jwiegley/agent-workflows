-- |
-- Module      : Workflows.Comments
-- Description : The comment audit — a manifest read back off disk, and a
--               false-positive guard that is not the auditor.
--
-- == The map: old Markdown -> new program
--
-- +--------------------------------------------------+---------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@                        | here                                                    |
-- +==================================================+=========================================================+
-- | @skills\/comment-audit\/SKILL.md@ step 1          | 'modeNote' and 'diffFlags' — tier 1 over the @base@      |
-- |                                                  | input, where the corpus asks or infers                   |
-- +--------------------------------------------------+---------------------------------------------------------+
-- | its step 2, @scripts\/inventory_comments.py@      | @'Workflows.Evidence.commentsInventory'@,                |
-- |                                                  | @'Workflows.Evidence.commentsPending'@,                  |
-- |                                                  | @'Workflows.Evidence.commentsStats'@ — three receipts    |
-- +--------------------------------------------------+---------------------------------------------------------+
-- | its step 3 and @references\/claim-taxonomy.md@    | 'claimTaxonomy', 'verdictVocabulary', 'confidenceRule'   |
-- +--------------------------------------------------+---------------------------------------------------------+
-- | its step 4                                       | 'remoteSweep', spliced only in pull-request mode         |
-- +--------------------------------------------------+---------------------------------------------------------+
-- | its step 5 and @references\/verification-guide.md@| 'guardBrief' on one engine and 'fixBrief' on another,    |
-- | @## False-positive guardrails@                    | through 'Workflows.Escalation.escalating'                |
-- +--------------------------------------------------+---------------------------------------------------------+
-- | its step 6                                       | @'Workflows.Deciders.auditIncomplete'@ over the tool's    |
-- |                                                  | own last line, and 'Workflows.Deciders.unreconciled'      |
-- |                                                  | over a question the tool cannot answer                   |
-- +--------------------------------------------------+---------------------------------------------------------+
-- | @references\/verification-guide.md@ @## Report@    | 'commentsReportBrief'                                    |
-- +--------------------------------------------------+---------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree — see
-- 'extractorPath' for the one place that rule shaped the design.
--
-- == The leveling-up, item by item
--
--   1. __The completion gate is the tool's own sentence, read for nothing.__
--      Step 6 says the audit is complete \"only when the manifest reports zero
--      pending __and__ the file\/comment denominator reconciliation has no
--      unclassified supplemental entry\", and then asks a reader to check both.
--      The extractor prints the first itself — @AUDIT INCOMPLETE: \<n\>
--      comment(s) still pending.@ — so
--      @'Workflows.Deciders.auditIncomplete'@ decides it at zero questions over
--      bytes the auditing turn did not write. The second conjunct is a judgment
--      about a heuristic tokenizer's blind spots and is asked as one question of
--      somebody who did no auditing. __Two conjuncts, two mechanisms, and the
--      corpus's own \"do not treat zero pending as proof that extraction itself
--      was complete\" is now the shape of the program.__
--
--   2. __The manifest is read back off disk, which is what the corpus says it is
--      for.__ \"The manifest is the working ledger … track candidates on disk,
--      not in working memory. This makes the audit resumable.\" In the corpus the
--      agent that wrote the verdicts is also the agent that reports them, so the
--      ledger's whole point — that it survives the context that made it — is
--      never exercised. Here the audit is an
--      @'Agentic.Workflow.act'@ and the report is written from a @cat@ of
--      @.comment-audit\/manifest.json@: the reporting question holds the file,
--      not a recollection of it.
--
--   3. __The false-positive guard is not the auditor.__ The verification guide is
--      unambiguous about the stakes — \"the most damaging failure is declaring a
--      correct comment wrong and then 'fixing' it\" — and then asks the
--      classifier to guard against itself. Here the guard is
--      'Workflows.Escalation.escalating' with the reviewer on
--      @'Workflows.Parties.lateral'@ and the corrector on
--      @'Workflows.Parties.broad'@: a different primary reads every @INCORRECT@
--      for its counter-evidence, and __the fixes are applied only in the arm
--      where it approved__. An objection is not a licence to edit, and a guard
--      that declined to judge is not an approval — which is the corpus's \"never
--      auto-edit a @NEEDS_REVIEW@ or @UNVERIFIABLE@ comment, or any
--      medium\/low-confidence finding\", turned from a rule into an arm.
--
--   4. __The batch loop dissolves into a bound.__ @doc\/design.md@ §7.4 row 12
--      names it: \"the 10–15-per-batch loop is a context-budget workaround an
--      actual cost bound replaces\". The corpus loops @pending --limit 15@ until
--      the manifest drains, because its budget is a context window nobody can
--      see. Here the limit is an argument in a printed argv, the acting turn gets
--      the batch it can hold, and whether the manifest actually drained is the
--      completion decider's business rather than the loop's. @wf cost comments@
--      is the budget, in advance.
--
--   5. __\"Ask which scope applies\" becomes tier 1.__ Step 1 offers whole-project
--      and pull-request mode and tells the reader to \"ask (or infer from the
--      request)\". The @base@ input decides it in ordinary Haskell before the
--      program exists: 'diffFlags' shapes the argv and 'modeNote' shapes the
--      brief, so the mode is in @wf plan --raw@ and costs neither a question nor
--      a path.
--
--   6. __The remote-stale sweep arrives only where it means something.__ Step 4
--      is titled \"PR\/stack: catch remote stale comments\" and is one of the
--      corpus's rare conditional sections. 'remoteSweep' is spliced by 'modeNote'
--      in pull-request mode and is absent in whole-project mode, where every
--      comment is in scope anyway and the instruction would be noise.
--
-- == Three honest notes
--
-- __The @show \<id\>@ subcommand is not a party here, and it cannot be.__ The
-- corpus's loop is @pending --limit 15@, then @show \<id\>@ per entry, then a
-- @Read@ of the surrounding code. An id exists only inside the @pending@ receipt,
-- and a receipt can never become an argv: the argv is part of the printed
-- program, which is what makes it program-authored. So the batch's /locations/
-- arrive as a receipt and the batch's /text and context/ are read by the acting
-- turn, which has the workspace for exactly as long as its act lasts. The
-- @update --id@ writes are the same turn's, and they are why the audit is an act
-- and not a question.
--
-- __The extractor is somebody else's program, and this row is honest about
-- depending on it.__ If the path is wrong the @inventory@ receipt fails, and a
-- @text@ ask on a nonzero exit abandons the run rather than analysing an empty
-- string — which is the loud failure. What this row cannot do is check that the
-- script at that path is the script the rubrics were written against; a
-- @manifest_version@ the program tested for would be a decider over a receipt,
-- and it is not written because the version this corpus carries is not something
-- this repository should pin on the owner's behalf.
--
-- __\"Apply fixes for each finding the user asked to fix\" has no user here.__
-- Step 5 opens on that clause, and an unattended run has nobody to have asked.
-- 'fixBrief' therefore applies exactly the rule the corpus states for the
-- unsupervised case — high confidence and unambiguous content only — and the
-- guard decides whether even that happens. The stronger form, where a human names
-- the findings first, is @'Workflows.Evidence.consentFile'@, and it belongs to a
-- run somebody is watching.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Comments
  ( -- * The program
    commentsProgram,
    commentsDoc,
    commentsScript,

    -- * The rubrics, transplanted
    claimTaxonomy,
    verdictVocabulary,
    confidenceRule,
    verificationTiers,
    falsePositiveGuardrails,

    -- * The two functions
    commentsFixFn,
    commentsReportFn,
    commentsTable,

    -- * The tier-1 readings of an invocation
    extractorPath,
    diffFlags,
    modeNote,
    batchLimit,
    manifestPath,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The two parties that are this program's own
-- ---------------------------------------------------------------------------

-- | The party that reads the code, judges the batch and records the verdicts.
--
-- A @tool@ with __no__ argv, and this is the module's one unavoidable one: the
-- work is @show \<id\>@ per entry, a @Read@ of the surrounding code, and
-- @update --id@ per verdict, where the ids come out of a receipt and cannot be
-- argv. An @'Agentic.Workflow.act'@ at @'Agentic.Raw.CodeAck'@ is the only kind
-- of answer the ACP transport grants that authority to, so the audit is an act
-- and the manifest it writes is read back by 'manifestPath'.
auditor :: Party 'IsTool
auditor = tool "comment-audit"

-- | The party that edits the comments the guard approved.
--
-- A second tool and not 'auditor', deliberately: @wf plan --raw@ names the party
-- of every node, and the turn that /judged/ a comment should be visibly separate
-- from the turn that /rewrote/ it. It is also the only party in this module that
-- touches a source file, so a reader looking for where this row can change code
-- has one place to look.
editor :: Party 'IsTool
editor = tool "comment-fix"

-- ---------------------------------------------------------------------------
-- The tier-1 readings of an invocation
-- ---------------------------------------------------------------------------

-- | Where the extractor lives, and the one place the read-only rule shaped this
-- program.
--
-- @SKILL.md@ step 2 says the script \"lives next to this file at
-- @scripts\/inventory_comments.py@\" and must be run \"by its __installed
-- absolute path__ (this skill's own directory — the same directory this SKILL.md
-- was loaded from)\". The authoritative copy of that directory is under
-- @~\/src\/nix\/config\/ai@, which __no party in this tree may point at__, so the
-- path is a program input naming wherever the harness installed it.
--
-- __Tier 1__, and an absent input becomes a name no file has — 'notesFile'\''s
-- rule and 'Workflows.Git.Commit.treeNeedle'\''s before it: @wf plan comments
-- --raw@ prints @python3 \<no extractor given\> inventory@, so an operator who
-- forgot the flag learns it from the plan rather than from a run that audited
-- nothing.
extractorPath :: Text -> Text
extractorPath p
  | T.null (T.strip p) = "<no extractor given>"
  | otherwise = T.strip p

-- | The flags the @inventory@ argv carries, decided from the @base@ input.
--
-- __Tier 1__: whole-project mode is the empty list and pull-request mode is
-- @--diff-base BASE@, which is the whole of @SKILL.md@ step 1 as far as the
-- command line is concerned. The corpus resolves the base by asking @gh pr view
-- --json baseRefName@ or @git merge-base@; both are receipts, and a receipt can
-- never become an argv, so the base is where the operator puts it.
diffFlags :: Text -> [Text]
diffFlags base
  | T.null (T.strip base) = []
  | otherwise = ["--diff-base", T.strip base]

-- | What the audit is told about its own scope, and whether step 4 applies.
--
-- __Tier 1__. In whole-project mode every comment is in scope and the
-- remote-stale sweep would be telling the auditor to look outside a scope that
-- has no outside; in pull-request mode the sweep is the difference between an
-- audit of a diff and an audit of what the diff /invalidated/, and it is spliced.
modeNote :: Text -> Text
modeNote base
  | T.null (T.strip base) =
      [wft|
      Scope: the whole project. Every comment the extractor found is in scope,
      and there is no diff to prioritise by.|]
  | otherwise =
      [wft|
      Scope: the changes against {scope}. The manifest records which comments
      fall inside the diff, and those come first.

      {remoteSweep}|]
  where
    scope = T.strip base

-- | @SKILL.md@ step 4, verbatim in substance.
--
-- /Source:/ its @### 4. PR\/stack: catch remote stale comments@ — the section
-- whose first sentence is the one worth carrying: \"diff-adjacency is not
-- enough.\"
remoteSweep :: Text
remoteSweep =
  [wft|
  Diff-adjacency is not enough. When the diff changes a function, a type, a
  constant or a config key, comments ELSEWHERE in the repository that describe
  it may now be stale. For each symbol whose signature or behaviour changed in
  the diff, search the whole project for its name and audit any comment that
  references it, even where that comment is nowhere near the diff. A comment
  made false by this change is this change's defect wherever it lives.|]

-- | The batch the @pending@ receipt is bounded to.
--
-- /Source:/ @SKILL.md@ step 3's \"batches of ~10-15 comments per file so context
-- stays small\", at its upper bound. In the corpus the number is a
-- context-budget guess repeated until the manifest drains; here it is one
-- argument in a printed argv, and how much the run can afford is
-- @'Agentic.Plan.costSummary'@'s answer rather than this constant's.
batchLimit :: Int
batchLimit = 15

-- | @.comment-audit\/manifest.json@ — the ledger, at the extractor's own
-- default.
--
-- /Source:/ @scripts\/inventory_comments.py@'s @DEFAULT_MANIFEST@ and
-- @SKILL.md@'s \"track extracted candidates on disk in
-- @.comment-audit\/manifest.json@, not in working memory\". A literal and not an
-- input, because the same default is what the three argv above will use when
-- nobody passes @--manifest@: two spellings of one path is exactly the drift
-- @'Workflows.Evidence'@ exists to prevent.
manifestPath :: Text
manifestPath = ".comment-audit/manifest.json"

-- ---------------------------------------------------------------------------
-- The rubrics, transplanted
-- ---------------------------------------------------------------------------

-- | @references\/claim-taxonomy.md@'s two axes: the four comment forms and the
-- eleven claim types, each with what verifying it consists of.
--
-- /Source:/ that file's @## Axis 1@ and @## Axis 2@, compressed to the
-- verification recipe of each type — which is the part an auditor acts on — and
-- keeping every one of the eleven, including the three the file itself marks as
-- high-stakes.
claimTaxonomy :: Text
claimTaxonomy =
  [wft|
  Classify every comment along two axes, then verify each claim it carries. A
  comment may carry several claim types: label all that apply.

  Form: a line comment (often about the line or block below it); a delimited
  block (often a file or section header, or a longer rationale); a docstring
  (frequently carrying examples and signature claims); or a trailing comment,
  which annotates the statement it follows and nothing more.

  Claim type, and how each is verified:

  1. Behavioural -- "returns the count", "handles the empty list", "retries 3
     times", "is idempotent". Read the implementation it describes and trace
     the relevant branch. Confirm the asserted behaviour is what the CURRENT
     code produces.
  2. Signature or type -- argument names, types, shapes, return type,
     nullability. Compare against the actual signature. A renamed or removed
     parameter makes the claim stale or incorrect.
  3. Code in a comment -- an example, a usage snippet, a doctest meant to
     work. Verify it by the tiers below. "Not runnable as-is" is NOT
     automatically incorrect: many examples are deliberately schematic.
  4. Cross-reference -- another file, function, class, module, symbol, @see or
     @link. Confirm the target exists now. Missing target is ORPHANED;
     existing but renamed is STALE.
  5. External reference -- a URL, an RFC, a spec section, a ticket. Confirm it
     is well-formed and, where a tool is available, that it resolves. Do not
     fetch anything that looks unsafe.
  6. Rationale or constraint -- "because the API requires X", "must stay
     sorted for the binary search below", "workaround for bug Y". Check
     whether the stated constraint still holds. If the binary search became a
     hash lookup, "must stay sorted" is stale. If the rationale rests on
     context outside the repository, it is UNVERIFIABLE or NEEDS_REVIEW --
     never incorrect on a guess.
  7. Temporal or version -- "as of v2.3", "deprecated in 3.8", "remove after
     Q3". Check the version actually in use, from lockfiles and manifests. A
     deprecation that already happened, or a date that has passed, is stale.
  8. Environment or compatibility -- "Linux-only", "requires env var X",
     "needs GPU". Check config, CI matrices and code paths. Often
     NEEDS_REVIEW, because the environment cannot be inspected from here.
  9. Machine-meaningful -- suppressions and directives: type: ignore, noqa,
     eslint-disable, pragma, nolint. Is the suppression still needed? A
     suppression for a warning that no longer fires is a dead suppression and
     is stale. Removing one changes behaviour: report it, and be careful.
  10. Security, performance or concurrency -- "constant-time compare",
      "O(n log n)", "thread-safe", "input is already sanitized". High-stakes
      and usually only partly provable from code. Require strong evidence and
      default to NEEDS_REVIEW. Never mark a security-relevant claim VALID
      without solid proof.
  11. TODO, FIXME or HACK -- a marker pointing at deferred work. Has the work
      been done? Is the problem still there? A TODO whose task is complete is
      stale.|]

-- | @references\/claim-taxonomy.md@'s @## Verdict vocabulary@ — the seven, with
-- the file's own deliberately conservative definitions.
--
-- /Source:/ verbatim in substance. This is the set @doc\/design.md@ §7.4 row 12
-- calls \"seven verdicts as a @revisingOn@ set\", and the shape it takes here is
-- the guard loop of 'commentsProgram': the verdicts are the classifier's
-- vocabulary, and what @revisingOn@ contributes is the three endings a /guard/
-- over them can have.
verdictVocabulary :: Text
verdictVocabulary =
  [wft|
  Assign exactly one verdict per comment, from exactly these seven:

  - VALID -- every claim checked is true against the current code, with
    concrete supporting evidence.
  - STALE -- was accurate once; the code, version or reference has moved, and
    the comment now describes a past state.
  - INCORRECT -- contradicted by the current code, with explicit
    counter-evidence. Requires proof, not the absence of confirmation.
  - MISLEADING -- technically true but likely to deceive: omits a critical
    caveat, describes only the happy path, or is ambiguously worded.
  - ORPHANED -- references a file, symbol, ticket or URL that no longer exists
    or resolves.
  - UNVERIFIABLE -- pure intent, opinion, or context that cannot be checked
    from this repository.
  - NEEDS_REVIEW -- the comment could be wrong, but proving it needs domain
    knowledge, external context or judgment not available here. This is the
    safe default whenever counter-evidence is incomplete, and it is always
    preferred to a speculative INCORRECT.|]

-- | @references\/claim-taxonomy.md@'s @## Confidence@ block.
--
-- /Source:/ verbatim. It is three sentences and it is what gates every automatic
-- edit this program can make, so it is a define of its own rather than a clause
-- inside one.
confidenceRule :: Text
confidenceRule =
  [wft|
  Record confidence as high only where the verdict rests on direct,
  unambiguous evidence read from the current code. Use medium where the
  evidence is indirect and low where it is inferred. Only a high-confidence
  finding is eligible for an automatic fix.|]

-- | @references\/verification-guide.md@'s @## Verifying code found in comments
-- (tiered)@, including the two sandbox rules.
--
-- /Source:/ its four tiers, its \"prefer native doc-test harnesses\" section and
-- its \"when running ad hoc, sandbox it\" bullets. The tier reached is recorded
-- as evidence, and the file's own concession is carried because it is the one
-- that prevents a false positive: \"reaching a lower level than executed is
-- normal and fine; it does not by itself make a comment incorrect.\"
verificationTiers :: Text
verificationTiers =
  [wft|
  For code found in a comment, run the cheapest sufficient level and record
  which level you reached as part of the evidence:

  1. PARSED -- the snippet is syntactically valid for its language.
  2. TYPECHECKED -- it passes the type checker against this project's symbols.
  3. COMPILED -- it compiles in the project context.
  4. EXECUTED -- it runs and produces the stated result.

  Reaching a lower level than EXECUTED is normal and fine, and does not by
  itself make a comment incorrect.

  Prefer the project's own doctest harness where it has one -- `python -m
  doctest`, `cargo test --doc`, whatever the ecosystem documents -- because it
  handles imports and setup the way the authors intended.

  Only run a snippet directly where no harness applies and execution is what
  settles the verdict. Then: copy it into a throwaway file under a temporary
  directory and never run it inside the project tree; do not run code that
  makes network calls, uses credentials, or deletes anything -- mark it
  NEEDS_REVIEW instead; keep it short and abandon anything that hangs. A
  snippet missing imports, fixtures or setup is a schematic example, not
  broken code: supply the obvious import where that is clearly the author's
  intent, and otherwise lower the verification level rather than failing the
  comment.|]

-- | @references\/verification-guide.md@'s @## False-positive guardrails@.
--
-- /Source:/ verbatim in substance, opening on the sentence that is the reason
-- this program has a separate guard at all: \"the most damaging failure is
-- declaring a correct comment wrong and then 'fixing' it.\"
falsePositiveGuardrails :: Text
falsePositiveGuardrails =
  [wft|
  The most damaging failure of this audit is declaring a correct comment wrong
  and then "fixing" it. Guard against it:

  - INCORRECT requires explicit counter-evidence. If you cannot quote the code
    that contradicts the comment, the verdict is not INCORRECT.
  - Where a claim depends on business logic, intent or context outside this
    repository, the verdict is NEEDS_REVIEW. Do not guess.
  - Be especially conservative with rationale, security, performance,
    concurrency and environment claims: they are usually only partly provable.
  - Quote the exact claim and the exact evidence, so a human can audit the
    verdict without redoing it.
  - Distinguish "could not verify" from "proven false". The first is
    NEEDS_REVIEW or UNVERIFIABLE; only the second is INCORRECT.|]

-- ---------------------------------------------------------------------------
-- The prompts
-- ---------------------------------------------------------------------------

-- | What the inventory receipt is introduced as.
--
-- /Source:/ @SKILL.md@ step 2 and its closing @## Notes@ paragraph, which is
-- where the extractor's own limits are stated: the generic tokenizer \"does not
-- model every raw string, heredoc, embedded-language string, or regex literal\"
-- and \"can therefore produce false positives __or silent omissions__\".
inventoryBrief :: Text
inventoryBrief =
  [wft|
  The extractor's inventory pass, as it reported it. These lines are the
  audit's denominator: how many files were scanned, how many were skipped, how
  many comments were found, and how many are pending a verdict.

  The skipped count is the one that matters most. An unrecognised extension is
  a surface this audit did not reach, and a surface it did not reach is not a
  surface it found clean.|]

-- | What the pending receipt is introduced as.
pendingBrief :: Text
pendingBrief =
  [wft|
  The batch: one line per comment still awaiting a verdict, giving its id, its
  path and line range, and its form. This is the extractor's own list, bounded
  by the limit in the command above.|]

-- | What the audit act is told.
--
-- /Source:/ @SKILL.md@ step 3's four numbered steps, with the taxonomy, the
-- verdicts, the confidence rule, the verification tiers and the guardrails
-- spliced from their own defines.
auditBrief :: Text
auditBrief =
  [wft|
  Audit the batch of comments below, one at a time, and record a verdict for
  every one of them.

  For each id: read its text with the extractor's `show` subcommand, then open
  the surrounding code and read enough of it to understand the claim -- not
  just the commented line. Prefer this project's own tools as ground truth:
  a type checker, a linter, a compiler or an existing test is stronger
  evidence than a reading of the source.

  Then record the verdict with the extractor's `update` subcommand, giving the
  id, the verdict, the confidence, the claim types, the evidence -- what you
  checked and what you found -- and a recommendation where you have one.

  Evidence before verdict, always. Never call a comment wrong without concrete
  proof from the current code.

  Change no comment and no line of code in this turn. This turn judges; a
  later one, and only if a separate reviewer approves it, edits.

  When the batch is done, reply DONE.|]

-- | What the stats receipt is introduced as.
--
-- /Source:/ @SKILL.md@ step 6's completion gate. The receipt's last line is the
-- tool's own verdict on the first of the gate's two conjuncts, which is what
-- @'Workflows.Deciders.auditIncomplete'@ reads.
statsBrief :: Text
statsBrief =
  [wft|
  The manifest's counts, as the extractor reports them: the total, how many
  are still pending, how many are audited, and the tally by verdict. The last
  line is the tool's own statement of whether every extracted entry now has a
  verdict.|]

-- | What the ledger receipt is introduced as.
--
-- /Source:/ @SKILL.md@'s @## Core principles@ — \"the manifest is the working
-- ledger … on disk, not in working memory. This makes the audit resumable.\"
ledgerBrief :: Text
ledgerBrief =
  [wft|
  The audit manifest, read back from disk exactly as it now stands. Every
  verdict, confidence, claim-type list, evidence string and recommendation in
  it was written by the auditing turn and is now bytes: what follows is read
  from the file, not recalled.|]

-- | What the reconciliation question asks.
--
-- /Source:/ @SKILL.md@ step 6's second conjunct and its @## Notes@ paragraph on
-- extractor limitations. This is the half of the completion gate no receipt can
-- settle, and the whole reason it is a question is in the tool's own output: the
-- line after @EXTRACTED INVENTORY COMPLETE@ reads \"file\/comment denominator
-- reconciliation is still required\".
reconcileBrief :: Text
reconcileBrief =
  [wft|
  Reconcile the audit's denominator. You did no auditing: your one job is to
  say whether the surface the extractor covered is the surface that was
  declared in scope.

  Compare the inventory's files-scanned and files-skipped counts against the
  scope this run was given. Then look for the shapes this extractor is known
  to miss -- Python uses its real tokenizer, everything else is a heuristic
  state machine, and it does not model every raw string, heredoc,
  embedded-language string or regex literal. An unrecognised extension appears
  only in the skipped count and must be audited directly if it was in scope.

  Answer in one of exactly two forms:

  - RECONCILED -- followed by the file count you accounted for and the skipped
    surfaces you are satisfied were out of scope.
  - UNRECONCILED: <one line per gap> -- a skipped surface that was in scope, a
    language whose comment forms this extractor cannot see, or a count that
    does not add up. Name the surface and why it matters.

  Zero pending entries is not proof that extraction itself was complete. That
  sentence is the reason this question exists, and answering RECONCILED because
  the counts look tidy is the failure it is here to prevent.|]

-- | What the guard is told, above 'Workflows.Escalation.endingSpec'.
--
-- /Source:/ @references\/verification-guide.md@'s guardrails and @SKILL.md@
-- step 5's two rules about what may and may not be auto-fixed. The guard is on a
-- serving model that answered none of the audit, which is the whole point of
-- putting it here rather than in the auditor's own checklist.
guardBrief :: Text
guardBrief =
  [wft|
  You are the false-positive guard. You did not audit these comments and you
  are not being asked to re-audit them: you are asked whether the findings
  below are safe to act on.

  Approve only if all of these hold:

  - every INCORRECT finding quotes the code that contradicts the comment --
    not an absence of confirmation, an actual contradiction;
  - no finding that depends on business logic, intent or context outside this
    repository is anything other than NEEDS_REVIEW or UNVERIFIABLE;
  - no security, performance, concurrency, rationale or environment claim was
    graded VALID or INCORRECT on partial evidence;
  - every finding marked high confidence names evidence that could be checked
    by somebody who is not its author;
  - no finding proposes changing code to match a comment.

  Object with one line per finding that fails, naming the id and which
  condition it failed. Your objection is what stops an edit, so be exact: a
  finding you object to without a reason stops a correct fix, and a finding
  you pass without evidence licenses a wrong one.|]

-- | What the corrector is told between guard rounds.
--
-- /Source:/ @SKILL.md@ step 5. The corrector does not edit the tree — it is
-- @'Workflows.Escalation.escalating'@'s amendment, which is an
-- @'Agentic.Workflow.ask'@ and therefore has no write authority. What it produces
-- is the corrected /finding set/, and 'commentsFixFn' is what applies one.
fixDraftBrief :: Text
fixDraftBrief =
  [wft|
  Produce the corrected finding set and nothing else. Your output goes
  straight back to the guard.

  For each finding the guard objected to: downgrade the verdict to the
  conservative one the evidence actually supports -- NEEDS_REVIEW where
  counter-evidence is incomplete, UNVERIFIABLE where the claim cannot be
  checked from this repository at all -- or supply the missing evidence
  verbatim from the code if it exists. Never argue a verdict up. Leave every
  finding the guard did not object to exactly as it stands, including its
  evidence string.|]

-- | What the fix act is told.
--
-- /Source:/ @SKILL.md@ step 5's three bullets, verbatim in substance. Its first
-- clause — \"for each non-VALID finding the user asked to fix\" — has no referent
-- in an unattended run, so the standing rule below is the one the corpus states
-- for what may be fixed /without/ being asked, and the guard's approval is what
-- makes this turn happen at all.
fixBrief :: Text
fixBrief =
  [wft|
  Apply the approved fixes to the comments themselves.

  Edit a comment's text in place only where its verdict is STALE, INCORRECT,
  MISLEADING or ORPHANED and its confidence is high and the correct content is
  unambiguous from the recorded evidence. Never edit a NEEDS_REVIEW or
  UNVERIFIABLE finding, and never edit a medium- or low-confidence one: leave
  those for a human and say so.

  Never change the surrounding code to make a comment true. If a comment is
  right and the code is wrong, that is a separate finding, and it is reported
  rather than acted on.

  Deleting a comment is a valid fix for an orphaned reference or a resolved
  TODO, but prefer correcting to deleting unless the comment is purely
  obsolete.

  When you are done, reply DONE with a one-line list of the ids you edited.|]

-- ---------------------------------------------------------------------------
-- The five provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the manifest still had pending entries.
notDrainedNote :: Text
notDrainedNote =
  [wft|
  Outcome: THE AUDIT DID NOT FINISH. The extractor's own `stats` line says
  entries are still pending after this run's audit turn, so the manifest is
  partial and nothing has been fixed. That is a count printed by the tool and
  not a claim by whoever did the auditing. Report the counts, say which surfaces
  were reached, and say that the audit is resumable: the manifest on disk holds
  every verdict already recorded, and another run continues from it.|]

-- | The arm where the denominator did not reconcile.
--
-- /Source:/ @SKILL.md@ step 6's own warning: \"do not treat zero pending as
-- proof that extraction itself was complete.\"
notReconciledNote :: Text
notReconciledNote =
  [wft|
  Outcome: EXHAUSTIVE ONLY WITHIN THE EXTRACTOR. Every extracted entry has a
  verdict, and an independent reconciliation found that the extracted set is NOT
  the declared scope: the gaps it names are below, verbatim. Do not describe
  this audit as exhaustive. Open the report with the boundary -- which surfaces
  were covered and which were not -- and only then the findings, because a
  reader who takes a bounded audit for a complete one has been told something
  false by omission.|]

-- | The arm where the guard approved and the fixes were applied.
appliedNote :: Text
appliedNote =
  [wft|
  Outcome: AUDITED, GUARDED AND FIXED. Every extracted entry has a verdict, an
  independent reconciliation accounted for the scope, and a false-positive guard
  on a serving model that did none of the auditing approved the finding set
  before any comment was edited. Report which fixes were applied and which
  findings were deliberately left for a human, and keep those two lists apart.|]

-- | The arm where the guard was still objecting when the bound ran out.
--
-- /Source:/ 'Workflows.Escalation.remainsNote', specialised — and it is the arm
-- the corpus cannot have, because its guardrails are a checklist and a checklist
-- has no outcome.
notGuardedNote :: Text
notGuardedNote =
  [wft|
  Outcome: AUDITED, NOT FIXED. The false-positive guard was still objecting when
  this run's rounds ran out, so NO comment was edited -- which is the correct
  outcome and not a failure: an unguarded fix to a correct comment is the most
  damaging thing this workflow can do. Report the findings as proposals, quote
  the guard's outstanding objections verbatim under their own heading, and say
  that every edit is waiting on a human.|]

-- | The arm where the guard would not judge at all.
guardSilentNote :: Text
guardSilentNote =
  [wft|
  Outcome: AUDITED, UNGUARDED. The false-positive guard declined to judge the
  finding set, so this audit has no independent check on its verdicts and no
  comment was edited. Say that in one sentence at the top of the report, before
  anything else. Report every finding as a proposal, do not describe any verdict
  as confirmed, and do not substitute your own reading of the guardrails for the
  guard that did not answer.|]

-- ---------------------------------------------------------------------------
-- The two functions
-- ---------------------------------------------------------------------------

-- | The fixes, as the one thing only the approving arm calls.
--
-- One parameter and one statement. It is a 'Agentic.Workflow.Fn' rather than an
-- inline act for the reason "Workflows.Report" gives: a call is priced at the
-- callee's own body, and making the /application of edits/ a named callee is what
-- lets a reader of @wf plan --raw@ see that exactly one arm of this program
-- reaches it.
commentsFixFn :: Fn '[ 'CodeText] 'CodeAck
commentsFixFn =
  function
    "comments.fix"
    (takes @"findings" Text $ noParams)
    \findings -> W.do
      act editor [wf|
          {fixBrief}

          The approved finding set:

          {findings}|]
      done

-- | @references\/verification-guide.md@'s @## Report format@.
--
-- /Source:/ its severity mapping, its per-finding block and its three closing
-- items, carried in the file's own order.
commentsReportBrief :: Text
commentsReportBrief =
  [wft|
  Write the comment-audit report.

  Open with the provenance line you were given, verbatim, on its own line. It
  is this run's own account of how it ended, and it is not yours to soften or
  to restate.

  Group the findings by severity, mapping them this way:

  - Critical: INCORRECT or MISLEADING on a behavioural, security, performance,
    concurrency, or signature claim -- a reader acting on the comment would be
    actively misled.
  - High: STALE or ORPHANED on a behavioural, reference or code-in-comment
    claim; a broken doctest.
  - Medium: a stale temporal or version claim, a dead suppression, a resolved
    TODO.
  - Low: UNVERIFIABLE and NEEDS_REVIEW items needing a human, and wording
    nits.

  Each finding is one block:

    <severity>  <path>:<line>  [<verdict>, confidence=<level>]
      claim:    "<the quoted comment text>"
      evidence: <what was checked and what was found>
      fix:      <applied | proposed | recommendation | none>

  End with three things: the counts by verdict; the fixes applied
  automatically, kept apart from those left for human review; and every
  language or file whose surface was NOT covered, so a reader knows this
  audit's true boundary.

  Quote claims and evidence from the manifest. Do not restate a verdict in
  stronger terms than the manifest records, and do not promote a NEEDS_REVIEW
  to a defect because the finding reads convincingly.|]

-- | The report every ending calls.
--
-- Three parameters: the provenance first, because it is the thing a report must
-- not omit; then the manifest, which is bytes; then whatever the ending has to
-- add — the counts, the reconciliation's gaps, or the guard's outstanding
-- objections.
commentsReportFn :: Fn '[ 'CodeText, 'CodeText, 'CodeText] 'CodeAck
commentsReportFn =
  function
    "comments.report"
    ( takes @"provenance" Text
        . takes @"ledger" Text
        . takes @"note" Text
        $ noParams
    )
    \provenance ledger note -> W.do
      act reporter [wf|
          {commentsReportBrief}

          Provenance:

          {provenance}

          The manifest, as it stands on disk:

          {ledger}

          What this ending has to add:

          {note}

          Write the report, then reply DONE.|]
      done

-- | The table 'commentsProgram' hands @'Agentic.Workflow.defining'@.
commentsTable :: [SomeFn]
commentsTable = [SomeFn commentsFixFn, SomeFn commentsReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | Three receipts, one audit, two completion tests, and a guard that is not the
-- auditor.
--
-- Two inputs. @extractor@ is the installed path of
-- @scripts\/inventory_comments.py@ — see 'extractorPath'; @base@ is the diff
-- base, and empty means the whole project.
--
-- The shape, top to bottom: inventory the comments; take a bounded batch; audit
-- it; ask the tool whether the manifest drained, for nothing; ask somebody else
-- whether the extracted set /was/ the scope, for one question; then guard the
-- findings on a third engine and edit only in the arm where the guard approved.
-- Five endings, five provenance lines, __one__ 'commentsReportFn'.
commentsProgram :: Parameterized
commentsProgram =
  taking (input "extractor" :> input "base" :> noInputs) \script base ->
    -- Tier 1, three times: which script, which mode, and what the audit is told
    -- about its own scope. All three are ordinary Haskell over the invocation.
    let path = extractorPath script
        flags = diffFlags base
        scoping = modeNote base
     in defining commentsTable W.do
          -- The denominator, and the skipped-surface count the reconciliation
          -- question will be held to.
          inventory <- ask (commentsInventory path flags) [wf|{inventoryBrief}|]

          -- The batch, bounded in the argv rather than by a context window.
          batch <- ask (commentsPending path batchLimit) [wf|{pendingBrief}|]

          -- The audit. An act, because judging a comment means reading the code
          -- around it and writing a verdict back to the manifest.
          act auditor [wf|
              {auditBrief}

              {scoping}

              {taxonomy}

              {verdicts}

              {confidence}

              {tiers}

              {guardrails}

              What the inventory pass reported:

              {inventory}

              The batch:

              {batch}|]

          -- Conjunct one of the completion gate: the tool's own last line, read
          -- for nothing.
          counts <- ask (commentsStats path) [wf|{statsBrief}|]
          pendingLeft <- tested auditIncomplete counts

          if pendingLeft
            then W.do
              call_ commentsReportFn (arg notDrainedNote :> arg counts :> arg batch :> noArgs)
              stop
            else W.do
              -- The ledger, off disk. Everything below reads the file rather
              -- than the auditing turn's recollection of it.
              ledger <- ask (fileContents manifestPath) [wf|{ledgerBrief}|]

              -- Conjunct two, which no receipt can settle: was the extracted set
              -- the declared scope? Asked of a party that audited nothing.
              reconciled <- ask (lateral (model "reconcile")) [wf|
                  {reconcileBrief}

                  What the inventory pass reported:

                  {inventory}

                  What the manifest now holds:

                  {counts}|]

              gap <- tested unreconciled reconciled

              if gap
                then W.do
                  call_ commentsReportFn (arg notReconciledNote :> arg ledger :> arg reconciled :> noArgs)
                  stop
                else W.do
                  -- The false-positive guard: a different primary reads every
                  -- verdict for its counter-evidence, and its three endings are
                  -- the three ways this run can end.
                  guarded <-
                    escalating
                      (lateral (model "comments-guard"))
                      guardBrief
                      (broad (model "comments-correct"))
                      fixDraftBrief
                      ledger
                      (atMost 2)

                  case guarded of
                    SettledOn findings -> W.do
                      -- The only arm that edits anything.
                      call_ commentsFixFn (arg findings :> noArgs)
                      call_ commentsReportFn (arg appliedNote :> arg findings :> arg reconciled :> noArgs)
                      stop
                    UnsettledOn findings -> W.do
                      call_ commentsReportFn (arg notGuardedNote :> arg findings :> arg reconciled :> noArgs)
                      stop
                    AbandonedOn findings -> W.do
                      call_ commentsReportFn (arg guardSilentNote :> arg findings :> arg reconciled :> noArgs)
                      stop
  where
    taxonomy = claimTaxonomy
    verdicts = verdictVocabulary
    confidence = confidenceRule
    tiers = verificationTiers
    guardrails = falsePositiveGuardrails

-- ---------------------------------------------------------------------------
-- The registry's two other columns
-- ---------------------------------------------------------------------------

-- | The one line @wf list@ prints beside this row.
commentsDoc :: Text
commentsDoc =
  "comment-audit: the extractor as three receipts, the manifest read back off disk, and a false-positive guard on another engine"

-- | The canned replies a @--scripted@ run answers from, keyed by prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: every receipt's question opens with its own brief, the
-- reconciliation's with 'reconcileBrief', and the guard's with 'guardBrief'.
--
-- __The two receipts in the middle are what steer the run.__ 'statsBrief' answers
-- with the extractor's @EXTRACTED INVENTORY COMPLETE@ shape, so
-- @'Workflows.Deciders.auditIncomplete'@ says the manifest drained; change it to
-- the @AUDIT INCOMPLETE:@ line and the run takes the arm where the audit did not
-- finish. 'reconcileBrief' answers @RECONCILED@, so the second conjunct holds;
-- prefix it with @UNRECONCILED:@ and the bounded-audit arm is the one that runs.
--
-- __The guard's row is the load-bearing one.__ A verdict question's scripted
-- default is @APPROVE@, so without a row here the guard would approve and the
-- @SettledOn@ arm would run — which is the arm an operator wants rehearsed, and
-- it is the one this table takes. The row is written anyway, with the approving
-- answer, because a table that relies on a default cannot be edited into the other
-- two arms in one line: an @OBJECTION:@ here reaches @UnsettledOn@ and an empty
-- answer reaches @AbandonedOn@, and all three exit 0.
commentsScript :: [(Text, Text)]
commentsScript =
  [ (inventoryBrief, inventoried),
    (pendingBrief, pendingList),
    (statsBrief, stats),
    (ledgerBrief, ledger),
    (reconcileBrief, reconciled),
    (guardBrief, "APPROVE"),
    (fixDraftBrief, corrected)
  ]
  where
    inventoried =
      [wft|
      Manifest written: .comment-audit/manifest.json
        scope:          whole project
        files scanned:  18
        files skipped:  2
        comments found: 41
        preserved:      0 (verdicts carried over)
        pending:        41|]

    pendingList =
      [wft|
      c0a1  src/cache.py:12-14  [line]
      c0a2  src/cache.py:57-57  [trailing]
      c0b7  src/http.py:88-96  [docstring]|]

    stats =
      [wft|
      total:   41
      pending: 0
      audited: 41
        NEEDS_REVIEW: 3
        STALE: 2
        VALID: 36

      EXTRACTED INVENTORY COMPLETE: every extracted entry has a verdict.
      File/comment denominator reconciliation is still required.|]

    -- fixture bytes, not prose: fake manifest JSON. The manifest is ONE line,
    -- so the fences are one line each and `<>` joins them where the old gaps
    -- broke; `{{` is the fence's literal open brace, and `}` needs no escape.
    ledger =
      [wft|{{"manifest_version": 3, "files_scanned": 18, "files_skipped": |]
        <> [wft|[{{"path": "assets/app.min.js", "reason": "unrecognised |]
        <> [wft|extension"}], "comments": [{{"id": "c0a1", "path": |]
        <> [wft|"src/cache.py", "verdict": "STALE", "confidence": "high", |]
        <> [wft|"evidence": "comment says 'retries 3 times'; retry_count is 5 at |]
        <> [wft|src/cache.py:31"}, {{"id": "c0b7", "path": "src/http.py", |]
        <> [wft|"verdict": "NEEDS_REVIEW", "confidence": "low", "evidence": |]
        <> [wft|"claims the response is already sanitized; sanitiser is upstream and |]
        <> [wft|not in this repository"}]}|]

    reconciled =
      [wft|
      RECONCILED -- 18 of 20 files accounted for. The 2 skipped are
      assets/app.min.js and assets/vendor.min.css, both generated bundles and
      both out of the declared scope. Python files used the real tokenizer; no
      heredoc or embedded-language surface remains unexamined.|]

    corrected =
      [wft|
      c0b7 downgraded from NEEDS_REVIEW confidence low to NEEDS_REVIEW with the
      evidence string naming the upstream sanitiser explicitly. Every other
      finding unchanged.|]
