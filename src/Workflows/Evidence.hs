-- |
-- Module      : Workflows.Evidence
-- Description : The receipts the world authors — every "if available, run X",
--               as a command.
--
-- __Provenance.__ The @## Tool integration@ block of
-- @~\/src\/nix\/config\/ai\/agents\/{bash,cpp,haskell,nix,python,rust,typescript}-reviewer.md@;
-- @commands\/sec-audit.md@'s three literal @grep -rn -E@ sweeps;
-- @commands\/restack.md@'s @git range-diff@; @commands\/cleanup.md@'s
-- obligations; @skills\/parallelize\/SKILL.md@'s history sentinel.
--
-- == Why this module is the largest honesty gain in the tree
--
-- \"If available, run @ruff check \<file\> --output-format=json@\" is a sentence
-- addressed to a model. The model may run it, may claim to have run it, or may
-- produce output that looks like it ran it — and the corpus's own
-- @agents\/fess-auditor.md@ names both failure modes it invites (/fallback
-- smuggling/ and the /verification gap/) without noticing that its own reviewer
-- family is where they live.
--
-- Under @'Agentic.Workflow.running'@ the argv is __program-authored__:
-- "Agentic.Shell" runs it with @proc@, never @sh -c@, so the unquoted
-- @\<file\>@ placeholders of the corpus stop being an injection surface; the
-- prompt goes to the child's __standard input__, where a splice is data; and
-- the receipt is bytes the answering model did not write. The argv is part of
-- the printed program, so a command that changed is a program that changed.
--
-- == The distinction the corpus has never had
--
-- "Agentic.Shell"'s answer table gives a gate three outcomes where prose had
-- one. At @verdict@: exit 0 __approves__, nonzero __objects with the command's
-- own first failing line__, and a command that is missing or outran its clock
-- is a __gap__ — a transport refusal, not an answer. In the owner's own terms:
-- the gate did not say no; it did not run. Nine commands in the corpus invoke
-- real argv and not one of them can tell those apart.
--
-- == The one rule this module exists to keep
--
-- __No party here points at @~\/src\/nix\/config\/ai@.__ The corpus is
-- read-only, absolutely, and the single place in this tree where that rule could
-- be broken is an argv — so every argv is here, and this module is reviewable as
-- a unit.
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Workflows.Evidence
  ( -- * Git
    gitStatus,
    gitStatusIn,
    gitDiff,
    gitDiffNames,
    gitDiffCheck,
    gitRangeDiff,
    gitRevParse,
    gitBranch,
    gitLogSeries,
    gitShowCommit,
    gitWorktreeAdd,
    gitPushLease,
    gitCommitYears,

    -- * GitHub
    ghPrChecks,
    ghPrDiff,
    ghPrView,
    ghPrCurrent,
    ghPrSearch,
    ghPrCreate,
    ghIssueView,

    -- * The linters the reviewer files ask for
    hlint,
    shellcheck,
    ruff,
    mypy,
    clippy,
    cargoAudit,
    clangTidy,
    cppcheck,
    statix,
    deadnix,
    tsc,
    eslint,

    -- * The security sweeps
    secretsGrep,
    dangerousPatternsGrep,
    hardcodedAddressGrep,

    -- * The scaffolding a dead-code pass must not leave behind
    dceMarkers,

    -- * The comment-audit extractor, subcommand by subcommand
    commentsInventory,
    commentsPending,
    commentsStats,

    -- * The NixOS host
    nixosBuild,
    systemctlStatus,
    httpHealth,

    -- * The file an operator names
    fileContents,
    lsPath,
    mdFilesIn,
    filePresent,

    -- * The gates
    nixFlakeCheck,
    makeTest,

    -- * The one probe that is about the run itself
    consentFile,
  )
where

import Agentic.Workflow (Party, PartyK (IsTool), running, tool)
import Data.Text (Text)
import qualified Data.Text as T

-- ---------------------------------------------------------------------------
-- Git
-- ---------------------------------------------------------------------------

-- | @git status --porcelain@ — the working tree, as bytes.
gitStatus :: Party 'IsTool
gitStatus = tool "git-status" `running` ("git", ["status", "--porcelain"])

-- | @git -C DIR status --porcelain@ — the working tree of __another__ checkout.
--
-- /Source:/ @commands\/fix-github-issue.md@ steps 1 and 8: the work is done in a
-- worktree under @work\/fix-\<n\>@, and step 8 is \"leave your work uncommitted
-- in the working tree, so it can be reviewed\".
--
-- __Why @-C@ and not @'gitStatus'@.__ Every argv in this module runs in the
-- /run's/ working directory, and a worktree is a sibling directory with its own
-- index: @git status --porcelain@ from the parent checkout reports the parent's
-- tree and says nothing at all about the worktree's. So a program that created a
-- worktree and then read 'gitStatus' would be reading the wrong tree and would
-- report a clean one. The directory is computed in Haskell from the issue number
-- — the same value that named the worktree — which is what makes the two argv
-- agree by construction.
gitStatusIn :: Text -> Party 'IsTool
gitStatusIn dir = tool "git-status-in" `running` ("git", ["-C", dir, "status", "--porcelain"])

-- | @git diff REV...@ — the change under review.
gitDiff :: [Text] -> Party 'IsTool
gitDiff revs = tool "git-diff" `running` ("git", "diff" : revs)

-- | @git diff --name-only REV...@ — the file list every language dispatch is a
-- pure function of.
--
-- /Source:/ @commands\/deep-review.md@ Step 1, which asks for exactly this and
-- then asks a model to classify the result. Here the classification is
-- 'Workflows.Deciders.touches', which costs nothing.
gitDiffNames :: [Text] -> Party 'IsTool
gitDiffNames revs = tool "git-diff-names" `running` ("git", ["diff", "--name-only"] <> revs)

-- | @git diff --check@ — whitespace errors and conflict markers, as an exit
-- code.
--
-- /Source:/ @commands\/cleanup.md@'s obligations.
gitDiffCheck :: Party 'IsTool
gitDiffCheck = tool "git-diff-check" `running` ("git", ["diff", "--check"])

-- | @git range-diff BASE OLD NEW@ — what a restack actually did to each commit.
--
-- /Source:/ @commands\/restack.md@'s proof step, which asks for this command by
-- name and has nowhere to put its output.
gitRangeDiff :: Text -> Text -> Text -> Party 'IsTool
gitRangeDiff base old new =
  tool "git-range-diff" `running` ("git", ["range-diff", base, old, new])

-- | @git rev-parse REV@ — an object id, for a head pin that must not have
-- moved.
gitRevParse :: Text -> Party 'IsTool
gitRevParse rev = tool "git-rev-parse" `running` ("git", ["rev-parse", rev])

-- | @git rev-parse --abbrev-ref HEAD@ — the branch name, as bytes.
--
-- /Source:/ @commands\/sitrep.md@'s filename scheme,
-- @YYYYMMDDTHHMM-SITREP-$PROJECT-$BRANCH.md@, whose @$BRANCH@ is exactly this
-- command's answer and in the corpus is a shell variable somebody has to have
-- set. A second binding rather than @'gitRevParse' \"--abbrev-ref HEAD\"@
-- because that spelling is two arguments and 'gitRevParse' takes one — the
-- constraint is the argv's, and this is where argv constraints live.
gitBranch :: Party 'IsTool
gitBranch = tool "git-branch" `running` ("git", ["rev-parse", "--abbrev-ref", "HEAD"])

-- | @git log --oneline --reverse BASE..HEAD@ — the series of commits that
-- exists between a base and here, oldest first.
--
-- /Source:/ @commands\/recommit.md@ (\"a series of logical, successive commits
-- from main in this branch\") and @agents\/fess-auditor.md@'s @## What To
-- Inspect@, which wants the same range for a different reason — one argv, one
-- binding, because two spellings of one command is exactly the duplication this
-- module exists to prevent. The command exits @0@ whether the range is empty or
-- not, so it is safe to ask at @text@, which is the distinction this module
-- spells out for @grep@ below.
gitLogSeries :: Text -> Party 'IsTool
gitLogSeries base =
  tool "git-log-series" `running` ("git", ["log", "--oneline", "--reverse", base <> "..HEAD"])

-- | @git show --find-renames --find-copies --stat --patch REV@ — one commit,
-- with its stat and its patch, as bytes.
--
-- /Source:/ @commands\/partner-reviewer.md@ and
-- @commands\/partner-collaborator.md@, which name this exact command — flag for
-- flag — as what to review when the local @deep-review@ tool will not take a
-- @\<sha\>^!@ argument. Here it is the /only/ way the commit is read, which is
-- the point: the fallback in those files is the reliable half, and the branch
-- that decides between them is a fact about somebody else's tooling.
gitShowCommit :: Text -> Party 'IsTool
gitShowCommit rev =
  tool "git-show"
    `running` ("git", ["show", "--find-renames", "--find-copies", "--stat", "--patch", rev])

-- | @git worktree add PATH -b BRANCH@ — a second checkout, on a new branch.
--
-- /Source:/ @commands\/fix-github-issue.md@ step 1, whose whole content is a
-- naming scheme: \"if the issue number is 1024, then create a branch named
-- @fix-1024@ and a working tree that has checked out that branch in
-- @work\/fix-1024@\".
--
-- __The scheme is computed in Haskell__ (see @'Workflows.Issue.worktreePath'@),
-- so both arguments are program-authored from the one input, and the same two
-- strings are reused by @'gitStatusIn'@ at the end of the run. In the corpus the
-- scheme is a sentence and the substitution is a model's.
gitWorktreeAdd :: Text -> Text -> Party 'IsTool
gitWorktreeAdd path branch =
  tool "git-worktree-add" `running` ("git", ["worktree", "add", path, "-b", branch])

-- | @git push --force-with-lease@.
--
-- /Source:/ @commands\/push.md@, and @commands\/rebase-and-fix.md@'s \"force
-- push the rewritten branches\". @--force-with-lease@ rather than @--force@ is
-- this tree's addition and the reason it is worth having the argv in a printed
-- program: a flag nobody can forget is a flag a plan prints before it is spent.
gitPushLease :: Party 'IsTool
gitPushLease = tool "git-push" `running` ("git", ["push", "--force-with-lease"])

-- | @git log --reverse --date=format:%Y --format=%ad@ — one four-digit year per
-- commit, oldest first.
--
-- /Source:/ @commands\/productize.md@ deliverable 2, which asks for a
-- @LICENSE.md@ whose copyright line reads
-- @Copyright (c) \<earliest\>-\<latest\>, John Wiegley@ where \"the year range
-- matches the earliest to latest Git commit years\".
--
-- __Why this is a receipt and not a sentence.__ The corpus states the rule and
-- leaves both numbers to whoever is writing the file, which is a model reading a
-- repository it cannot count. Here the first and the last line of this receipt
-- /are/ the range, and the model writing the header is holding the years rather
-- than recalling them.
--
-- __Why no shell pipeline.__ The obvious spelling is
-- @git log --format=%ad | sort -u | sed -n '1p;$p'@ — three processes and two
-- pipes, which is a shell, and "Agentic.Shell" runs an argv with @proc@. One
-- year per commit in commit order is the same information at the cost of a
-- longer receipt, and @--reverse@ is what puts the earliest on line one.
gitCommitYears :: Party 'IsTool
gitCommitYears =
  tool "git-years"
    `running` ("git", ["log", "--reverse", "--date=format:%Y", "--format=%ad"])

-- ---------------------------------------------------------------------------
-- GitHub
-- ---------------------------------------------------------------------------

-- $gh
--
-- /Source:/ @commands\/fix-ci.md@, @commands\/bugbot.md@ and
-- @commands\/review-github-pr.md@, which shell out to @gh@ and then reason about
-- what a model said it saw.

-- | @gh pr checks N@ — the check run status. Nonzero while anything is red,
-- which is what makes it a gate rather than a report.
ghPrChecks :: Text -> Party 'IsTool
ghPrChecks n = tool "gh-pr-checks" `running` ("gh", ["pr", "checks", n])

-- | @gh pr diff N@.
ghPrDiff :: Text -> Party 'IsTool
ghPrDiff n = tool "gh-pr-diff" `running` ("gh", ["pr", "diff", n])

-- | @gh pr view N --json …@ — the fields a review needs, as JSON.
ghPrView :: Text -> Party 'IsTool
ghPrView n =
  tool "gh-pr-view"
    `running` ("gh", ["pr", "view", n, "--json", "number,title,headRefOid,files,reviews"])

-- | @gh pr view --json …@ with __no number__ — the pull request of the branch
-- the run is on.
--
-- /Source:/ @commands\/assess.md@ (\"the PR for the current branch\") and
-- @commands\/fix.md@'s closing section, which sweeps the bot comments on a pull
-- request the same run has just created.
--
-- __This is the one @gh@ receipt whose subject is not in the invocation, and
-- that is why it exists.__ A run that opens a pull request cannot know its
-- number: the number arrives in a receipt, and a receipt can never become an
-- argv — the argv is part of the printed program, which is what makes it
-- program-authored. What such a run /does/ know is the branch it is on, so the
-- subject is named by position rather than by number, and the acting half of
-- @fix.md@ becomes reachable where @green-ci@'s numbered gate is not. The limit
-- is named in "Workflows.Issue"'s header rather than papered over.
ghPrCurrent :: Party 'IsTool
ghPrCurrent =
  tool "gh-pr-current"
    `running` ("gh", ["pr", "view", "--json", "number,title,headRefOid,files,reviews"])

-- | @gh pr list --state open --search N --json url --jq '.[].url'@ — one URL per
-- open pull request whose text mentions @N@, and __nothing at all__ when there
-- are none.
--
-- /Source:/ @commands\/fix.md@'s @NOTE@ — \"do not work on a bug that already
-- has a PR open that addresses it; in that case, just give the PR number and
-- stop immediately\" — which is the cheapest gate in the corpus and is checked
-- by nothing.
--
-- __Why @--jq@ and not the default table.__ A decider's needles are literal
-- program text, so the receipt has to have a shape this module chose: one line
-- per hit, each beginning @https:@, and no header row. @gh@'s human table would
-- make the test depend on @gh@'s formatting, and its \"no pull requests match
-- your search\" sentence would make it depend on @gh@'s prose. Both exit @0@, so
-- neither is a failure — which is why the distinction has to be in the argv.
-- See 'Workflows.Deciders.openPullRequest'.
ghPrSearch :: Text -> Party 'IsTool
ghPrSearch n =
  tool "gh-pr-search"
    `running` ("gh", ["pr", "list", "--state", "open", "--search", n, "--json", "url", "--jq", ".[].url"])

-- | @gh pr create --fill@.
--
-- /Source:/ @commands\/push.md@ (\"create a PR for this work and push it to
-- GitHub\").
ghPrCreate :: Party 'IsTool
ghPrCreate = tool "gh-pr-create" `running` ("gh", ["pr", "create", "--fill"])

-- | @gh issue view N --json number,title,state,labels,body,comments@ — the
-- issue, as JSON.
--
-- /Source:/ @commands\/fix.md@ step 1 and @commands\/fix-github-issue.md@ step
-- 2, both of which spell it
--
-- > GH_TOKEN="$(gh auth token --hostname github.com --user jwiegley)" gh issue view
--
-- __The token wrapper is not carried, and cannot be.__ It is shell — a command
-- substitution assigning an environment variable — and "Agentic.Shell" runs an
-- argv with @proc@ and never @sh -c@, which is the rule that makes every
-- placeholder in this module safe. A @gh@ invoked without it reads the same
-- credential from the host's own keychain; a @gh@ that cannot authenticate exits
-- nonzero, and a @text@ ask on a nonzero exit abandons the run — so the failure
-- is loud and names itself, where in the corpus a missing token yields a
-- plausible-looking empty issue.
ghIssueView :: Text -> Party 'IsTool
ghIssueView n =
  tool "gh-issue-view"
    `running` ("gh", ["issue", "view", n, "--json", "number,title,state,labels,body,comments"])

-- ---------------------------------------------------------------------------
-- The linters
-- ---------------------------------------------------------------------------

-- $linters
--
-- One per @## Tool integration@ block in the reviewer family, argv for argv.
-- The @\<file\>@ of the corpus becomes a real argument list, which is the
-- difference between a wish and a receipt.
--
-- @catalog.nix@ grants @run-commands@ to all eleven reviewers and four of them
-- never run one. Here a reviewer with no tool is a reviewer with no entry in
-- this list, which is a visible absence rather than an unused grant.

-- | /Source:/ @agents\/haskell-reviewer.md@ — @hlint \<file\> --json@.
hlint :: [Text] -> Party 'IsTool
hlint fs = tool "hlint" `running` ("hlint", fs <> ["--json"])

-- | /Source:/ @agents\/bash-reviewer.md@ — @shellcheck -f json \<file\>@.
shellcheck :: [Text] -> Party 'IsTool
shellcheck fs = tool "shellcheck" `running` ("shellcheck", ["-f", "json"] <> fs)

-- | /Source:/ @agents\/python-reviewer.md@ —
-- @ruff check \<file\> --output-format=json@.
ruff :: [Text] -> Party 'IsTool
ruff fs = tool "ruff" `running` ("ruff", ["check"] <> fs <> ["--output-format=json"])

-- | /Source:/ @agents\/python-reviewer.md@ —
-- @mypy \<file\> --no-error-summary@.
mypy :: [Text] -> Party 'IsTool
mypy fs = tool "mypy" `running` ("mypy", fs <> ["--no-error-summary"])

-- | /Source:/ @agents\/rust-reviewer.md@, whose flags are carried verbatim.
clippy :: Party 'IsTool
clippy =
  tool "clippy"
    `running` ( "cargo",
                [ "clippy",
                  "--all-targets",
                  "--all-features",
                  "--",
                  "-D",
                  "warnings",
                  "-W",
                  "clippy::pedantic",
                  "-W",
                  "clippy::unwrap_used"
                ]
              )

-- | /Source:/ @agents\/rust-reviewer.md@ — @cargo audit@.
cargoAudit :: Party 'IsTool
cargoAudit = tool "cargo-audit" `running` ("cargo", ["audit"])

-- | /Source:/ @agents\/cpp-reviewer.md@, whose check list is carried verbatim.
--
-- The corpus writes the check list inside single quotes because it is written
-- for a shell. There is no shell here, so the quotes are gone and the value is
-- one argument — which is what the quotes were for.
clangTidy :: [Text] -> Party 'IsTool
clangTidy fs =
  tool "clang-tidy"
    `running` ( "clang-tidy",
                "--checks=bugprone-*,cppcoreguidelines-*,modernize-*,cert-*,performance-*" : fs
              )

-- | /Source:/ @agents\/cpp-reviewer.md@ —
-- @cppcheck --enable=all --inconclusive \<file\>@.
cppcheck :: [Text] -> Party 'IsTool
cppcheck fs = tool "cppcheck" `running` ("cppcheck", ["--enable=all", "--inconclusive"] <> fs)

-- | /Source:/ @agents\/nix-reviewer.md@ — @statix check \<file\>@.
statix :: [Text] -> Party 'IsTool
statix fs = tool "statix" `running` ("statix", "check" : fs)

-- | /Source:/ @agents\/nix-reviewer.md@ — @deadnix \<file\>@.
deadnix :: [Text] -> Party 'IsTool
deadnix fs = tool "deadnix" `running` ("deadnix", fs)

-- | /Source:/ @agents\/typescript-reviewer.md@ —
-- @tsc --noEmit --pretty \<file-or-project\>@.
tsc :: [Text] -> Party 'IsTool
tsc fs = tool "tsc" `running` ("tsc", ["--noEmit", "--pretty"] <> fs)

-- | /Source:/ @agents\/typescript-reviewer.md@ —
-- @eslint \<file\> --format json@.
eslint :: [Text] -> Party 'IsTool
eslint fs = tool "eslint" `running` ("eslint", fs <> ["--format", "json"])

-- ---------------------------------------------------------------------------
-- The security sweeps
-- ---------------------------------------------------------------------------

-- $sweeps
--
-- /Source:/ @commands\/sec-audit.md@ steps 1–3, whose three regexes are carried
-- byte for byte. Three quarters of that command's evidence becomes
-- world-authored on the one command where a fabricated \"no secrets found\"
-- costs the most.
--
-- __A note the author of a program using these owes the reader.__ @grep@ exits
-- @1@ for \"no match\", which is an answer and not a failure, and
-- "Agentic.Shell" abandons a @text@ ask on a nonzero exit. So a sweep is asked
-- as a __flag__ (\"did anything match?\") or as a __verdict__ (no match
-- approves), never as text.

-- | @grep -rn -E '(password|secret|token|api_key|private_key|BEGIN (RSA|OPENSSH|PGP))'@
secretsGrep :: [Text] -> Party 'IsTool
secretsGrep fs =
  tool "secrets-grep"
    `running` ( "grep",
                ["-rn", "-E", "(password|secret|token|api_key|private_key|BEGIN (RSA|OPENSSH|PGP))"] <> fs
              )

-- | @grep -rn -E '(eval\\(|exec\\(|system\\(|popen\\(|pickle\\.load|yaml\\.load[^_])'@
dangerousPatternsGrep :: [Text] -> Party 'IsTool
dangerousPatternsGrep fs =
  tool "dangerous-grep"
    `running` ( "grep",
                ["-rn", "-E", "(eval\\(|exec\\(|system\\(|popen\\(|pickle\\.load|yaml\\.load[^_])"] <> fs
              )

-- | @grep -rn -E 'https?:\/\/[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+'@
hardcodedAddressGrep :: [Text] -> Party 'IsTool
hardcodedAddressGrep fs =
  tool "hardcoded-address-grep"
    `running` ("grep", ["-rn", "-E", "https?://[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+"] <> fs)

-- ---------------------------------------------------------------------------
-- The scaffolding a dead-code pass must not leave behind
-- ---------------------------------------------------------------------------

-- | @grep -rn -E 'DCE-BEGIN|DCE-END' .@ — did any marker survive the run?
--
-- /Source:/ @skills\/eliminate-dead-code\/SKILL.md@ operating principle 9
-- (\"markers never escape … must be fully gone before VERIFY reports success\")
-- and @references\/phases.md@ Phase 4 step 1, which spells the same check as
-- @rg --hidden -n 'DCE-BEGIN|DCE-END' && echo \"FAIL: markers remain\"@.
--
-- __Asked as a flag, and that is a deviation worth naming.__ @doc\/design.md@
-- §7.4 row 13 writes this as @containsLine \"DCE-BEGIN\"@, and a
-- @'Agentic.Workflow.decide'@ needs a receipt to read — but @grep@ exits @1@ for
-- \"no match\", which is the /good/ outcome here, and a @text@ ask on a nonzero
-- exit abandons the run. So the sweep is a flag over an exit code, exactly as
-- the @$sweeps@ note above requires: the answer is @yes@ when a marker is still
-- there. Same test, one fewer question, and no arm that fires because a clean
-- tree looked like a failure.
--
-- @-r@ walks the tree the run was given; the corpus's @--hidden@ has no @grep@
-- spelling and the markers it looks for are in source files, not dotfiles.
dceMarkers :: Party 'IsTool
dceMarkers =
  tool "dce-markers" `running` ("grep", ["-rn", "-E", "DCE-BEGIN|DCE-END", "."])

-- ---------------------------------------------------------------------------
-- The comment-audit extractor
-- ---------------------------------------------------------------------------

-- $extractor
--
-- /Source:/ @skills\/comment-audit\/SKILL.md@ steps 2, 3 and 6, whose four
-- invocations of @scripts\/inventory_comments.py@ — @inventory@,
-- @pending --limit@, @show \<id\>@ and @update --id@ — are the corpus's most
-- textbook receipt party: a program that already exists, already prints a fixed
-- shape, and is already told to a model as a command to remember.
--
-- __The script's path is an input, and it has to be.__ The corpus resolves it as
-- @$SKILL/scripts/inventory_comments.py@, where @$SKILL@ is \"this skill's own
-- directory -- the same directory this SKILL.md was loaded from\" — a fact the
-- reading agent is asked to remember. The authoritative copy of that file lives
-- under @~\/src\/nix\/config\/ai@, which __no party in this tree may point at__,
-- so the path arrives as a program input naming wherever the harness installed
-- it. An operator's path is not a party this module aims (see @$files@), and
-- @wf plan --raw@ prints the argv, so which script a run used is visible before
-- it runs.
--
-- @show \<id\>@ is deliberately __absent__: its argument is an id that exists
-- only inside the @pending@ receipt, and a receipt can never become an argv —
-- the argv is part of the printed program, which is what makes it
-- program-authored. "Workflows.CommentAudit" reads the batch through the acting
-- agent instead, and its header says so.

-- | @python3 SCRIPT inventory [--diff-base BASE]@ — build or refresh the
-- manifest, and print the denominator.
--
-- The flag list is the caller's, computed in Haskell from the run's inputs:
-- whole-project mode is the empty list and pull-request mode is
-- @[\"--diff-base\", base]@. The receipt's own lines carry @files scanned@,
-- @files skipped@, @comments found@ and @pending@, which is the reconciliation
-- denominator the skill's step 6 demands and the corpus asks a reader to compare
-- by eye.
commentsInventory :: Text -> [Text] -> Party 'IsTool
commentsInventory script flags =
  tool "comments-inventory" `running` ("python3", [script, "inventory"] <> flags)

-- | @python3 SCRIPT pending --limit N@ — the next batch, one @id path:lines
-- [form]@ line each.
--
-- /Source:/ step 3's loop. The @10-15 comments per file@ batch size is the
-- corpus's context-budget workaround; here it is this argument, and the number of
-- batches is the number of rounds the program is written with, which
-- @'Agentic.Plan.costSummary'@ prices.
commentsPending :: Text -> Int -> Party 'IsTool
commentsPending script limit =
  tool "comments-pending"
    `running` ("python3", [script, "pending", "--limit", T.pack (show limit)])

-- | @python3 SCRIPT stats@ — the counts, and the completion sentence.
--
-- /Source:/ step 6's completion gate. The script's last line is either
-- @AUDIT INCOMPLETE: \<n\> comment(s) still pending.@ or
-- @EXTRACTED INVENTORY COMPLETE: every extracted entry has a verdict.@ followed
-- by @File\/comment denominator reconciliation is still required.@ — which is
-- the gate's two conjuncts, printed by the tool itself, one decidable for
-- nothing and one that is not. See 'Workflows.Deciders.auditIncomplete'.
commentsStats :: Text -> Party 'IsTool
commentsStats script =
  tool "comments-stats" `running` ("python3", [script, "stats"])

-- ---------------------------------------------------------------------------
-- The NixOS host
-- ---------------------------------------------------------------------------

-- | @.\/build SUBCOMMAND [FLAGS]@ — the managed host's own build driver.
--
-- /Source:/ @skills\/nixos\/SKILL.md@: \"on a managed NixOS host, run builds and
-- switches through the host's build driver from @\/etc\/nixos@, for example
-- @cd \/etc\/nixos && .\/build switch@ … the driver owns the @.nixos-build@
-- lock; never create, remove, or seize that path manually. If the driver cannot
-- acquire its lock, report its error and stop.\"
--
-- __Three things this argv makes structural.__
--
--   * __The @cd@ is gone, because a @cd@ is shell.__ "Agentic.Shell" runs an
--     argv with @proc@ in the run's own working directory, so the corpus's
--     @cd \/etc\/nixos &&@ becomes a requirement on where the run is started —
--     and @wf plan --raw@ prints @.\/build build@, so a reader can see which
--     directory the receipt is about. A relative @.\/build@ rather than an
--     absolute path is deliberate: the driver is the /host's/, and hard-coding
--     one machine's layout into this repository would make the argv a lie on the
--     next one.
--   * __The lock cannot be seized, because nothing here can seize it.__ There is
--     no @rm@ and no @touch@ in this module, so \"never create, remove, or seize
--     that path\" is not a rule a run is trusted with; it is a command that does
--     not exist. And \"report its error and stop\" is what a @text@ ask on a
--     nonzero exit already does.
--   * __The VPS flags are program-authored.__ @--max-jobs 1 --cores 1@ is,
--     in the corpus, a sentence a model must remember on one host out of
--     several. Here it is this parameter, computed in Haskell from the run's
--     @host@ input before the program exists — tier 1, zero questions, zero
--     paths — and it is in the printed argv either way.
nixosBuild :: Text -> [Text] -> Party 'IsTool
nixosBuild subcommand flags =
  tool "nixos-build" `running` ("./build", subcommand : flags)

-- | @systemctl status UNIT@ — is the unit up? Nonzero when it is not.
--
-- /Source:/ @commands\/install-service.md@ item 10 (\"test to ensure the newly
-- installed service is working before you finish your work\") and
-- @commands\/remove-service.md@'s systemd clause. In both files that test is a
-- thing an agent is told to do at the end; here it is an exit code, so it is
-- asked as a flag or a verdict and never as text.
systemctlStatus :: Text -> Party 'IsTool
systemctlStatus unit = tool "systemctl" `running` ("systemctl", ["status", unit])

-- | @curl -fsS -m 10 URL@ — does the service answer over HTTPS? Nonzero when it
-- does not.
--
-- /Source:/ @commands\/install-service.md@ items 2 and 10: an nginx virtual host
-- with a TLS certificate, and a test that the service works. @-f@ makes an HTTP
-- error status a nonzero exit, which is what turns \"test it works\" into a
-- flag; @-m 10@ is what keeps a hung host from becoming a hung run, and a
-- timeout is a __gap__ rather than a @no@ — the distinction "Agentic.Shell"'s
-- answer table makes and the corpus cannot.
httpHealth :: Text -> Party 'IsTool
httpHealth url = tool "http-health" `running` ("curl", ["-fsS", "-m", "10", url])

-- ---------------------------------------------------------------------------
-- The file an operator names
-- ---------------------------------------------------------------------------

-- $files
--
-- One argv whose /argument/ is a program input rather than a literal, which is
-- the one shape in this module that deserves a sentence of its own.
--
-- @commands\/process-checklist.md@ and @commands\/meeting-notes.md@ both open
-- with @$ARGUMENTS@ naming a __file__, and in the corpus that file is opened by
-- whatever agent read the command. Here it is opened by @proc@, in the run's own
-- working directory, and what comes back is bytes. The path is an input and
-- therefore the operator's; the /command/ is the program's, and neither of these
-- writes anything.
--
-- The read-only rule is unaffected. It says no party in this tree __points at__
-- @~\/src\/nix\/config\/ai@, and none does: a path an operator types is not a
-- party this module aims, exactly as @'gitDiff'@'s revisions are not.

-- | @cat PATH@ — a file the operator named, as bytes.
--
-- /Source:/ @commands\/process-checklist.md@ (\"a Markdown checklist of tasks
-- in: $ARGUMENTS\") and @commands\/meeting-notes.md@ (\"the notes can be found
-- in the file $ARGUMENTS\").
--
-- Safe to ask at @text@, and the failure is the useful one: @cat@ exits @0@ with
-- the contents and nonzero only when the file is missing or unreadable, and
-- "Agentic.Shell" abandons a @text@ ask on a nonzero exit — so a run pointed at
-- a file that is not there ends saying so, rather than analysing the empty
-- string.
fileContents :: Text -> Party 'IsTool
fileContents path = tool "file" `running` ("cat", [path])

-- | @ls -1 PATH@ — one name per line, which is the shape a decider can test.
--
-- /Source:/ @commands\/initialize.md@'s \"if there's already a @CLAUDE.md@,
-- suggest improvements to it\" and @commands\/partner-cleanup.md@'s \"repeat
-- until the observations directory has no regular, non-hidden @*.md@ files\".
-- Both are questions about a directory, and in the corpus both are answered by
-- whichever agent read the command.
--
-- @-1@ is load-bearing: @ls@ columnates when its output is a terminal and this
-- receipt is read by @'Agentic.Workflow.decide'@ at
-- @'Agentic.Workflow.ContainsLine'@, which is exact line equality. One name per
-- line is what makes the test a test.
--
-- Safe to ask at @text@ for @'fileContents'@'s reason and with the same useful
-- failure: @ls@ exits @0@ on a directory that is there, including an empty one,
-- and nonzero on one that is not — so a run pointed at a directory that does not
-- exist ends saying so rather than draining nothing and reporting success.
lsPath :: Text -> Party 'IsTool
lsPath path = tool "ls" `running` ("ls", ["-1", path])

-- | @find DIR -maxdepth 1 -type f -name '*.md' -not -name '.*'@ — one path per
-- line, and no line at all when the directory is drained.
--
-- /Source:/ @commands\/partner-cleanup.md@ @## Scope@: \"only process regular,
-- non-hidden @*.md@ files directly inside the observations directory; ignore
-- temp files, dotfiles, and nested directories\". Four clauses, four flags:
-- @-type f@, @-name '*.md'@, @-not -name '.*'@, @-maxdepth 1@.
--
-- __@find@ where @doc\/design.md@ §7.2 row 37 says @ls@__, and the reason is the
-- decider. That row reads \"settled by an @ls@ receipt read by a decider\", and
-- @'Agentic.Workflow.AnyLineStartsWith'@ tests a line's /prefix/: @ls -1@ yields
-- bare names whose prefix is an ISO timestamp, so the needle would have to be a
-- date. @find@ prints each hit under the directory it was given, so the needle
-- is the directory — which is a program input, exactly as
-- @'Workflows.Git.Commit.treeNeedle'@'s is. See
-- 'Workflows.Deciders.observationsPending'.
--
-- The four filters are also what makes the receipt honest about the corpus's own
-- @## Atomic Write Requirement@: a half-written observation lives at
-- @.\<stamp\>.md.tmp.\<pid\>@, which @-not -name '.*'@ excludes, so a drain loop
-- cannot pick up a file the reviewing half is still writing.
mdFilesIn :: Text -> Party 'IsTool
mdFilesIn dir =
  tool "observations"
    `running` ("find", [dir, "-maxdepth", "1", "-type", "f", "-name", "*.md", "-not", "-name", ".*"])

-- | @test -f PATH@ — asked as a __flag__, because that is what an exit code is.
--
-- /Source:/ @commands\/fix.md@'s @# If present, change confirmation tests into
-- regression tests@ section, whose whole condition is whether
-- @test\/todo\/\<ISSUE-NUMBER\>.test@ exists.
--
-- __The same argv as 'consentFile', and deliberately a second binding.__ A
-- consent gate is a file the program is /forbidden/ to create and whose only way
-- through is a human; this is an ordinary question about the tree. The two party
-- names differ in the printed program — @consent@ against @file-present@ — and
-- that is the point: a reader of @wf plan --raw@ can tell which of the two a
-- @test -f@ is, and one binding serving both meanings would make that
-- undecidable.
filePresent :: Text -> Party 'IsTool
filePresent path = tool "file-present" `running` ("test", ["-f", path])

-- ---------------------------------------------------------------------------
-- The gates
-- ---------------------------------------------------------------------------

-- | @nix flake check@ — the owner's own green gate.
--
-- /Source:/ @skills\/wiggum\/SKILL.md@'s environment discipline and
-- @commands\/lefthook.md@'s pre-commit set, both of which name it as the thing
-- that decides.
nixFlakeCheck :: Party 'IsTool
nixFlakeCheck = tool "green" `running` ("nix", ["flake", "check"])

-- | @make test@ — the gate for a tree that has one.
makeTest :: Party 'IsTool
makeTest = tool "green" `running` ("make", ["test"])

-- ---------------------------------------------------------------------------
-- The consent file
-- ---------------------------------------------------------------------------

-- | @test -f PATH@ — a gate the run itself cannot pass.
--
-- /Source:/ @commands\/install-service.md@'s two capital-letter pleas (\"DO NOT
-- generate the certificate yourself, ask me\"), and Isaac's @stack-prs@ consent
-- file, which are the same construct twice.
--
-- __A person's question is not a real gate when unattended__: a scripted run
-- answers a flag @yes@, and a live run reaches whoever is watching — or nobody.
-- A file the program is forbidden to create is a gate whose only way through is
-- a human, and the workflow can be run unattended without that fact being
-- silently lost. Nothing in this tree writes it.
consentFile :: Text -> Party 'IsTool
consentFile path = tool "consent" `running` ("test", ["-f", path])
