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
    gitDiff,
    gitDiffNames,
    gitDiffCheck,
    gitRangeDiff,
    gitRevParse,
    gitLogSeries,
    gitPushLease,

    -- * GitHub
    ghPrChecks,
    ghPrDiff,
    ghPrView,
    ghPrCreate,

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

    -- * The gates
    nixFlakeCheck,
    makeTest,

    -- * The one probe that is about the run itself
    consentFile,
  )
where

import Agentic.Workflow (Party, PartyK (IsTool), running, tool)
import Data.Text (Text)

-- ---------------------------------------------------------------------------
-- Git
-- ---------------------------------------------------------------------------

-- | @git status --porcelain@ — the working tree, as bytes.
gitStatus :: Party 'IsTool
gitStatus = tool "git-status" `running` ("git", ["status", "--porcelain"])

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

-- | @git push --force-with-lease@.
--
-- /Source:/ @commands\/push.md@, and @commands\/rebase-and-fix.md@'s \"force
-- push the rewritten branches\". @--force-with-lease@ rather than @--force@ is
-- this tree's addition and the reason it is worth having the argv in a printed
-- program: a flag nobody can forget is a flag a plan prints before it is spent.
gitPushLease :: Party 'IsTool
gitPushLease = tool "git-push" `running` ("git", ["push", "--force-with-lease"])

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

-- | @gh pr create --fill@.
--
-- /Source:/ @commands\/push.md@ (\"create a PR for this work and push it to
-- GitHub\").
ghPrCreate :: Party 'IsTool
ghPrCreate = tool "gh-pr-create" `running` ("gh", ["pr", "create", "--fill"])

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
