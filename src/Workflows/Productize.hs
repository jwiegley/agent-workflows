-- |
-- Module      : Workflows.Productize
-- Description : Twenty-one deliverables, priced at twenty-one before the first
--               one is written — and the pre-commit slice as a row of its own.
--
-- == The map: old Markdown -> new program
--
-- +-----------------------------------------+----------------------------------------------------------------+
-- | @~\/src\/nix\/config\/ai@               | here                                                           |
-- +=========================================+================================================================+
-- | @commands\/productize.md@'s 21 bullets  | 'deliverables' — twenty-one 'Workflows.Panels.Lens'es, folded  |
-- |                                         | to one specification document, and rung 'Full'                 |
-- +-----------------------------------------+----------------------------------------------------------------+
-- | its per-language preferences table      | 'preferenceTable' — tier 1 over @--input-arg paths=@           |
-- +-----------------------------------------+----------------------------------------------------------------+
-- | its five \"use available live web       | 'searchRoster' — __one seat per language present__, not one    |
-- | search\" cells                          | per deliverable                                                |
-- +-----------------------------------------+----------------------------------------------------------------+
-- | its deliverable 2's \"year range\"      | @'Workflows.Evidence.gitCommitYears'@ — a receipt, where the    |
-- |                                         | corpus leaves two numbers to whoever writes the file           |
-- +-----------------------------------------+----------------------------------------------------------------+
-- | @commands\/lefthook.md@                 | rung 'Lefthook' and 'lefthookFn' — the standalone pre-commit   |
-- |                                         | slice, which is what that file says it is                      |
-- +-----------------------------------------+----------------------------------------------------------------+
--
-- The Markdown was read as __data__. Nothing in @~\/src\/nix\/config\/ai@ is
-- modified by this module, and no party in it points at that tree.
--
-- == The leveling-up, item by item
--
--   1. __Twenty-one deliverables, priced at twenty-one.__ @doc\/design.md@ §7.2
--      row 42 asks for exactly this, and it is the whole argument for the row:
--      @productize.md@ is a bullet list an agent works down until it runs out of
--      patience, and there is no number anywhere in it. Here the list is a
--      'Workflows.Panels.Roster', the fan-out is one
--      @'Agentic.Workflow.panelText'@, and @wf cost productize@ is the price of
--      all twenty-one before the first one is written. A deliverable dropped is a
--      block missing from a fold whose labels are derived from the same list —
--      not an item somebody stopped reading at.
--
--   2. __The five \"use available live web search\" cells become one question per
--      language, not one per deliverable.__ The corpus writes that phrase five
--      times in its preferences table: Haskell lint, Bash lint, Emacs Lisp lint
--      /and/ format, Coq lint /and/ format. Read literally that is a search per
--      cell per deliverable that touches it. 'searchRoster' asks it once per
--      language whose tools the table does not name, in ordinary Haskell from the
--      file list — so a Rust-and-Python repository asks it zero times and a
--      Haskell one asks it once.
--
--   3. __The copyright year range is a receipt.__ Deliverable 2 wants
--      @Copyright (c) \<earliest\>-\<latest\>@ \"where the year range matches the
--      earliest to latest Git commit years\", which is a rule addressed to a
--      model that cannot count a repository. @'Workflows.Evidence.gitCommitYears'@
--      prints one year per commit, oldest first, so the two numbers are the first
--      and last line of a handle the writing question is holding.
--
--   4. __\"Ensure @nix flake check@ builds and runs all of the checks\" becomes
--      the gate.__ Deliverable 5 asks a run to ensure something about its own
--      output. Here @'Workflows.Evidence.nixFlakeCheck'@ is a
--      @'Workflows.Gates.gate'@ over the acted tree: exit @0@ settles, and a
--      nonzero exit objects __with the command's own first failing line__, which
--      the repair reads. The deliverable that asks for a working check is verified
--      by running it.
--
--   5. __@lefthook.md@ stops depending on prose reference.__ That file is three
--      lines and its second one says \"follow that workflow's lefthook \/
--      pre-commit section (including its per-language hook setup) for the
--      details, without performing the rest of productization\". A section
--      referenced across files is the coupling that rots — §7.1 row 31 says so —
--      and here it is @call_ 'lefthookFn'@ from two rungs, with the pre-commit
--      slice of the roster selected in Haskell. Two rows, two prices, one body.
--
--   6. __\"All of the above should happen in parallel\" is a deliverable and not a
--      hope.__ The corpus's last bullet asks for parallelism in the hook, which is
--      a property of the file being written and is therefore a thing to specify.
--      It is the twenty-first member, it is in the pre-commit slice, and it is
--      spelled out rather than left as an adverb on the other twenty.
--
-- == Three honest notes
--
-- __The twenty-one members specify; one act writes.__ A panel member is an
-- @'Agentic.Workflow.ask'@ and an ask has no write authority, so twenty-one
-- deliverables cannot be twenty-one acts. What the fan-out produces is a
-- specification document — one block per deliverable, each saying what file to
-- write, what target to add, and what command proves it — and 'productizeFn' and
-- 'lefthookFn' are the two acting turns that apply it. That is a real difference
-- from a reading of \"each a receipt\" in which each deliverable runs its own
-- command: the /verification/ is a receipt, once, and it is @nix flake check@,
-- which is deliverable 5's own answer to the question \"how would you know?\"
--
-- __The README's voice is named and not supplied.__ Deliverable 1 asks for a
-- README \"written in my voice (use the johnw skill)\", and
-- @'Workflows.Rubrics.Voice'@ carries @itVoice@ and not the owner's personal
-- register: @doc\/design.md@ §7.4 row 16 rules that @johnw@ splits into a
-- generator and a critic and that the split is __decided and deliberately
-- unwritten__ until a row calls it. This row does not call it either. The README
-- member therefore asks for the register the tree /has/ — measured,
-- institutionally grounded, no promotional adjectives — and says plainly that the
-- personal voice is not available to it, so a reader of the output can tell a
-- register that was chosen from one that was missed.
--
-- __Two deliverables are conditional in the corpus and are questions here.__
-- \"If this language supports a memory sanitizer\" and \"if there is
-- documentation that needs to be built\" are conditions a Markdown file states
-- and nobody resolves. They stay members of the roster, because a roster is what
-- makes a dropped item visible, and each is told that __\"this language has none\"
-- is a complete answer__ and an omission is not. That is one question spent to
-- make an absence explicit, and it is the cheaper mistake.
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE TypeApplications #-}

module Workflows.Productize
  ( -- * The two rungs
    ProductizeRung (..),
    productizeName,
    productizeDoc,
    productizeHelp,

    -- * The programs
    productizeProgram,
    productizeScript,

    -- * The deliverables
    deliverables,
    deliverableRoster,
    preCommitSlice,

    -- * The per-language readings of the file list
    preferenceTable,
    searchRoster,

    -- * The functions
    lefthookFn,
    productizeFn,
    productizeReportFn,
    productizeTable,
  )
where

import qualified Agentic.Workflow.Do as W
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prelude
import Prelude

-- ---------------------------------------------------------------------------
-- The two rungs
-- ---------------------------------------------------------------------------

-- | Two of the owner's commands over one body.
data ProductizeRung
  = -- | @commands\/productize.md@ — all twenty-one deliverables.
    Full
  | -- | @commands\/lefthook.md@ — the pre-commit slice, and nothing else.
    Lefthook

-- | The name the operator types, and the name "Workflows.Registry" registers.
--
-- Family first, the owner's own word as the suffix, and the bare family name for
-- the default rung: @productize@ is the whole workflow and @productize-lefthook@
-- is the slice its own Markdown file says it is.
productizeName :: ProductizeRung -> Text
productizeName Full = "productize"
productizeName Lefthook = "productize-lefthook"

-- | The one line @wf list@ prints beside each rung.
productizeDoc :: ProductizeRung -> Text
productizeDoc Full =
  "productize.md: twenty-one deliverables as a roster priced at twenty-one, then `nix flake check` as the gate"
productizeDoc Lefthook =
  "lefthook.md: the pre-commit slice of `productize`, as a call rather than a prose reference"

-- | The page @wf help \<rung\>@ prints under the computed header
-- ('Agentic.Cli.rowHelp').
--
-- One text at two settings. The two rungs take the same two inputs and read
-- them the same way — a whole rung is a /slice/ of the other, called rather
-- than described — so the inputs and the transport are written once; what
-- differs is the opening, the worked example's scope, and the caveat that says
-- which of the two an operator wants.
--
-- __It states no price.__ The header above it carries the numbers off the same
-- 'Agentic.Plan.Facts' @wf list@ publishes. The one number worth an operator's
-- attention is this row's /floor/, which is unusually high — the deliverables
-- are a fixed roster, so even the cheapest run writes all of them — and the
-- caveat says so in words rather than repeating the header.
productizeHelp :: ProductizeRung -> Text
productizeHelp r =
  [wft|
  {opening}

  **Inputs.**

  * `paths` — the file list, one path per line, and
    `git diff --name-only > changed.txt` is the usual way to make one. It
    decides the preferences table and the per-language tool seats in ordinary
    Haskell before the program exists, so `plan` must be given the same `paths=`
    the run will use. An empty list collapses the per-language seats to *one
    general seat* rather than to none.
  * `scope` — what the operator says the repository is **for**, in his own
    words. It rides into the specification, because a README and a fuzz harness
    both need to know what the thing is. Empty is legal and is a
    productionisation of a repository described only by its files.

  **Transport.** Unattended, with somewhere to write: an adapter of the run's
  own and `--scratch "$PWD"`, because this row *writes files into your
  repository* — that is the whole of what it is for — and the scratch directory
  is the only place an acting turn may write.

  ```sh
  wf run {row} --engine acp --adapter claude --require-pinned --scratch "$PWD" \
     --input-file paths=changed.txt --input-arg scope='a Haskell library and its CLI'
  ```

  **Rehearsal.** Both inputs named empty, every question answered from the row's
  own canned table, consulting nobody:

  ```sh
  wf run {row} --scripted --input-arg paths= --input-arg scope=
  ```

  **Caveats.**

  {caveat}
  * **The floor above is high, and it is a floor rather than an estimate.** The
    deliverables are a *fixed roster*, so the cheapest run is one that wrote all
    of them and passed the gate first time; there is no arm in which fewer are
    written. Read the floor before starting, not the spread.
  * The gate at the end is `nix flake check`, which is an exit code and not an
    opinion. A repository that cannot be checked that way gets a run that
    reports it rather than one that claims success.
  |]
  where
    row = productizeName r

    opening = case r of
      Full ->
        [wft|
        `commands/productize.md` as a program: twenty-one deliverables — README,
        licence, dev shell, formatting, linting, coverage, CI, pre-commit hooks
        and the rest — as a roster priced at twenty-one, and then
        `nix flake check` as the gate the whole thing is held to.|]
      Lefthook ->
        [wft|
        `commands/lefthook.md` as a program: the pre-commit slice of
        `productize`, as a **call** rather than as a prose reference to another
        command. Formatting, a warning-free build, tests, linting and coverage,
        wired into `lefthook.yml` and held to the same gate.|]

    caveat = case r of
      Full ->
        [wft|
        * If what you want is only the pre-commit wiring, `productize-lefthook`
          is the cheaper row and it is the same code: the slice is a function
          call here, so the two cannot drift apart.|]
      Lefthook ->
        [wft|
        * It is a slice and says so. There is no README, no licence and no CI
          workflow in this rung — `productize` is the row that writes those, and
          this one is a call inside it.|]

-- ---------------------------------------------------------------------------
-- The one party that is this program's own
-- ---------------------------------------------------------------------------

-- | The party that writes the files and the build targets.
--
-- A @tool@ with __no__ argv, for 'Workflows.ProcessChecklist.worker'\''s reason: the
-- work is \"write these files and add these targets\", and which files depends on
-- what the specification came out as. An @'Agentic.Workflow.act'@ at
-- @'Agentic.Raw.CodeAck'@ is the only kind of answer the ACP transport grants
-- write authority to.
builder :: Party 'IsTool
builder = tool "productize-write"

-- ---------------------------------------------------------------------------
-- The per-language readings of the file list
-- ---------------------------------------------------------------------------

-- | @commands\/productize.md@'s per-language preferences, as one table.
--
-- /Source:/ its seven @##@ sections — Haskell, Rust, C++, Python, Bash, Emacs
-- Lisp, Coq — with the tool the file names, and 'Nothing' where it says \"use
-- available live web search to find the best option\". The globs are
-- @'Workflows.Rubrics.Reviewers'@'s vocabulary, spelled again here because this
-- table is about /which tool formats a language/ and that one is about /who
-- reviews a file/: two tables, two questions, and neither is the other's
-- accident.
preferences :: [(Text, [Text], Maybe Text, Maybe Text)]
preferences =
  [ ("Haskell", [".hs", ".lhs", ".cabal"], Nothing, Just "fourmolu"),
    ("Rust", [".rs"], Just "cargo clippy", Just "cargo fmt"),
    ("C++", [".cpp", ".cc", ".cxx", ".c", ".h", ".hpp", ".hxx"], Just "clang-tidy and cppcheck", Just "clang-format"),
    ("Python", [".py", ".pyi"], Just "ruff", Just "ruff"),
    ("Bash", [".sh", ".bash", ".zsh"], Nothing, Just "shfmt"),
    ("Emacs Lisp", [".el"], Nothing, Nothing),
    ("Coq", [".v"], Nothing, Nothing)
  ]

-- | The preferences that apply to this file list, as the paragraph every
-- deliverable is told.
--
-- __Tier 1__ ("Workflows.Deciders"): which languages a repository is in is a fact
-- about the invocation, so this is ordinary Haskell over ordinary
-- 'Data.Text.Text' and costs zero questions and zero paths. With no @paths@ the
-- whole table is spliced and the deliverables are told the file list was not
-- given — WR-1's direction, because a specification written for every language the
-- owner uses is over-broad and a specification written for none is empty.
preferenceTable :: [Text] -> Text
preferenceTable files
  | null present =
      [wft|
      No file list was given to this run, so the languages present were not
      decided. The operator's standing tool preferences, in full, are below; use
      the ones that apply to what you find in the tree, and say in your block
      which language you assumed.

      {everyRow}|]
  | otherwise =
      [wft|
      The languages this repository is in, from the file list this run was
      given, and the operator's tool preference for each:

      {presentRows}|]
  where
    present = [row | row@(_, globs, _, _) <- preferences, any (touches files) globs]

    everyRow = bullets [(n, toolLine l f) | (n, _, l, f) <- preferences]
    presentRows = bullets [(n, toolLine l f) | (n, _, l, f) <- present]

    toolLine l f = "lint: " <> quoted l <> "; format: " <> quoted f
    quoted (Just x) = "`" <> x <> "`"
    quoted Nothing = "NOT NAMED by the preferences table"

-- | One seat per language present whose lint or format tool the table does not
-- name.
--
-- /Source:/ @productize.md@'s five \"use available live web search to find the
-- best option\" cells. @doc\/design.md@ §7.2 row 42 rules that these become
-- \"one search question __per language present__, not per deliverable\", and this
-- is that ruling: the roster is derived in Haskell from the file list, so a
-- repository whose languages all have named tools asks nothing here.
--
-- __WR-1 is why the list is never empty.__ @plan@ and @cost@ bind @\"\"@ for an
-- input nobody gave and @'Agentic.Workflow.panelText' []@ is an @error@ on a CAF,
-- so the empty file list yields __one__ seat: the general one, which asks what
-- the tree is actually written in and which of the unnamed tools that implies.
-- That is also the honest answer for a run given no paths.
searchRoster :: [Text] -> Roster
searchRoster files
  | null unnamed = [generalSeat]
  | otherwise = [seatFor n | n <- unnamed]
  where
    unnamed =
      [ n
      | (n, globs, l, f) <- preferences,
        not (null files),
        any (touches files) globs,
        l == Nothing || f == Nothing
      ]

    generalSeat =
      Lens
        { lensName = "toolchain",
          lensOwns = "which languages this tree is actually in, and which of their tools the preferences table leaves open",
          lensBrief = generalSearchBrief,
          lensParty = broad (model "productize-toolchain")
        }

    seatFor n =
      Lens
        { lensName = "tools-" <> slug n,
          lensOwns = "the linter and formatter for " <> n <> " that the preferences table does not name",
          lensBrief = searchBriefFor n,
          lensParty = broad (model ("productize-tools-" <> slug n))
        }

    slug = T.toLower . T.replace " " "-" . T.replace "+" "p"

-- ---------------------------------------------------------------------------
-- The twenty-one deliverables
-- ---------------------------------------------------------------------------

-- | @commands\/productize.md@'s bullet list, in the file's own order.
--
-- /Source:/ the twenty-one bullets, each carried as @(fence label, what it owns,
-- what answering it consists of)@. Nothing is merged and nothing is dropped: the
-- count is the point of the row, and a roster is what makes a missing item
-- visible.
deliverables :: [(Text, Text, Text)]
deliverables =
  [ ( "readme",
      "a full, clear, concise README.md, if the repository has none",
      [wft|
      Specify the README.md this repository should have, if it does not already
      have one: what it must say, section by section, and in what order. Full,
      clear and concise, in that order of priority. Write in a measured,
      institutionally grounded register -- no promotional adjectives, no
      exclamation, no second-person marketing. The owner's own personal writing
      voice is NOT available to this run: say so in one line at the end of your
      block rather than approximating it, so that a reader can tell a register
      that was chosen from one that was missed. If a README already exists, say
      what is missing from it instead of specifying a replacement.|]
    ),
    ( "license",
      "LICENSE.md, BSD-3-Clause, with the copyright years taken from the receipt",
      [wft|
      Specify LICENSE.md containing the standard BSD-3-Clause license text, with
      the copyright line reading exactly `Copyright (c) <earliest>-<latest>,
      John Wiegley.  All rights reserved.` -- two spaces after the period, as
      written. Take <earliest> and <latest> from the commit-years receipt you
      were given: the first line is the earliest year and the last line is the
      latest. Quote both, and say which line of the receipt each came from. Do
      not compute a range from anything else, and do not write a single year
      where the receipt shows two.|]
    ),
    ( "devshell",
      "flake.nix, so `nix develop` enters a shell that can build every target",
      [wft|
      Specify the flake.nix this repository needs so that `nix develop` enters a
      development shell carrying every dependency required to build every
      target. Name the inputs, the devShell's packages, and which target each
      package is there for -- a shell with an unexplained dependency is a shell
      nobody can prune later.|]
    ),
    ( "build-check",
      "a pre-commit check and a CI check that `nix build` completes",
      [wft|
      Specify the pre-commit check and the CI check that `nix build` completes
      correctly. Both, and the same command in both: a pre-commit check that CI
      does not mirror is a check that stops applying the moment somebody commits
      from another machine.|]
    ),
    ( "flake-check",
      "`nix flake check` running every check in this list",
      [wft|
      Specify how `nix flake check` comes to build and run all of the checks in
      this specification -- not a subset, and not a separate script that happens
      to run them. Name each check as a flake check output. This is the
      deliverable that makes every other one verifiable by one command, so say
      which of the others it does NOT cover and why.|]
    ),
    ( "format-target",
      "a build target that formats every language present",
      [wft|
      Specify a build target that formats all the code to one standard, using
      the formatter the preferences table names for each language present. One
      target that covers every language, and name the tool per language.|]
    ),
    ( "format-hook",
      "a pre-commit check that formatting is correct in every file",
      [wft|
      Specify the pre-commit check that verifies formatting is correct in every
      file -- a check, not a reformat: a hook that rewrites the tree under
      somebody's commit is a hook that loses work. Name the flag that makes each
      formatter check rather than write.|]
    ),
    ( "coverage-target",
      "a build target that generates a code-coverage report",
      [wft|
      Specify a build target that generates a code-coverage report, naming the
      tool for each language present and where the report lands.|]
    ),
    ( "coverage-hook",
      "a pre-commit check that coverage does not drop",
      [wft|
      Specify the pre-commit check that coverage does not drop. Say against what
      it compares -- a committed baseline number, or the merge base -- and what
      happens on the first run, when there is nothing to compare against. A
      ratchet with no stored baseline is a check that always passes.|]
    ),
    ( "profile-target",
      "a build target that generates a performance profiling report",
      [wft|
      Specify a build target that generates a performance profiling report: the
      tool, the workload it profiles, and where the report lands. Name the
      workload explicitly -- a profile of an unspecified workload is a number
      nobody can reproduce.|]
    ),
    ( "profile-hook",
      "a pre-commit check that performance has not dropped by more than 5%",
      [wft|
      Specify the pre-commit check that performance numbers do not drop by more
      than 5%. Say which numbers, against what baseline, and how the noise floor
      is handled -- a 5% threshold on a benchmark whose run-to-run variance is
      10% is a check that fails at random, which is worse than no check.|]
    ),
    ( "lint-target",
      "a build target that performs full linting",
      [wft|
      Specify a build target that performs full linting, using the linter the
      preferences table names for each language present -- or the one the
      toolchain block below recommends, where the table does not name it.|]
    ),
    ( "warnings-as-errors",
      "warnings enabled and treated as errors, where the language allows it",
      [wft|
      Specify how the build comes to have all warnings enabled and warnings
      treated as errors, per language, where that is applicable. Name the flag
      for each. Where a language cannot do it, say so rather than omitting the
      language.|]
    ),
    ( "clean-build",
      "a build target proving the full build is warning-free and passes cleanly",
      [wft|
      Specify a build target that ensures the full build contains no warnings
      and passes cleanly. Say how it distinguishes a warning from the build
      tool's own noise -- a grep for the word `warning` catches a package index
      being out of date, and a gate that goes red for that is a gate everybody
      learns to skip.|]
    ),
    ( "fuzz",
      "a fuzz-testing target, where the language supports one",
      [wft|
      Specify a fuzz-testing target, if this is possible in the languages
      present: the harness, the corpus, and where a crash lands. If none of the
      languages present supports fuzzing, say that in one line -- "this language
      has none" is a complete answer to this deliverable and an omission is not.|]
    ),
    ( "tests",
      "a build target that builds and runs unit and integration tests",
      [wft|
      Specify the build target that builds and runs all unit tests and all
      integration tests. If the two are run differently, say so and name both.|]
    ),
    ( "sanitizer",
      "a memory-sanitizer build, where the language supports one",
      [wft|
      Specify a memory-sanitizer build, or the nearest equivalent, if the
      languages present support one: the flags, and which target it applies to.
      If none does, say that in one line -- an absence stated is a deliverable
      met, and an absence omitted is a deliverable nobody can tell was
      considered.|]
    ),
    ( "lefthook",
      "the lefthook.yml that runs every check on pre-commit",
      [wft|
      Specify the lefthook.yml that performs all of the builds and checks in
      this specification on pre-commit, adapted to the languages and tools
      present. One command entry per check, each with the glob it applies to and
      the command it runs against the staged files. Follow the shape of this
      example rather than its contents:

        pre-commit:
          parallel: true
          commands:
            ruff-format:
              glob: "*.py"
              run: ruff format --check {{staged_files}
            ruff-lint:
              glob: "*.py"
              run: ruff check {{staged_files}
            tests:
              run: pytest tests/ -x -q

      Every hook that can take the staged file list should take it: a hook that
      lints the whole tree on every commit is a hook somebody disables.|]
    ),
    ( "docs",
      "a documentation build, and its output as a CI artifact",
      [wft|
      If this repository has documentation that needs building, specify the
      build target that checks the docs do build, and how that build's output
      becomes a CI artifact. If it has none, say so in one line.|]
    ),
    ( "actions",
      "GitHub Actions running the same checks the pre-commit hook runs",
      [wft|
      Specify the GitHub Actions workflow that runs the same checks the
      pre-commit hook runs. The same checks, named the same way: two lists that
      drift are two lists, and the whole value of this deliverable is that a
      contributor without the hook installed is held to the same bar. Say how
      the two stay in step.|]
    ),
    ( "parallel",
      "the pre-commit checks running in parallel, as far as they can",
      [wft|
      Specify how the pre-commit checks run in parallel, as much as is possible.
      Say which checks cannot -- because one produces what another reads, or
      because two contend for the same lock or build directory -- and what the
      ordering between those is. Parallelism stated without its exceptions is a
      hook that fails intermittently.|]
    )
  ]

-- | @commands\/lefthook.md@'s slice, by name.
--
-- /Source:/ that file's own scope — \"pre-commit checks for code formatting,
-- building with no warnings, running tests, linting, and code-coverage
-- checking\" — plus its \"including its per-language hook setup\", read against
-- 'deliverables'. Seven of the twenty-one, chosen in Haskell, so the slice is a
-- list and not a paragraph a second file quotes.
preCommitSlice :: [Text]
preCommitSlice =
  [ "build-check",
    "format-hook",
    "coverage-hook",
    "profile-hook",
    "lefthook",
    "actions",
    "parallel"
  ]

-- | The deliverables a rung specifies, with the preferences table spliced into
-- each brief.
--
-- The splice is __tier 1__: which languages are present is decided before the
-- program exists, so every one of the twenty-one members already knows what tools
-- it may name, and nothing was spent finding out.
--
-- Three rungs of party, and the split is by what the deliverable /is/: the two
-- that are prose about this repository go to @'Workflows.Parties.broad'@, the
-- three that are judgments about how a check could be wrong go to
-- @'Workflows.Parties.reasoning'@, and the rest go to @broad@ as well — with the
-- hook file itself on @reasoning@, because a hook that fails intermittently is the
-- expensive mistake in this list.
deliverableRoster :: ProductizeRung -> [Text] -> Roster
deliverableRoster t files =
  [ Lens
      { lensName = n,
        lensOwns = owns,
        lensBrief = brief <> "\n\n" <> prefs,
        lensParty = rungFor n (model ("productize-" <> n))
      }
  | (n, owns, brief) <- chosen
  ]
  where
    chosen = case t of
      Full -> deliverables
      Lefthook -> [row | row@(n, _, _) <- deliverables, n `elem` preCommitSlice]

    prefs = preferenceTable files

    rungFor n
      | n `elem` ["coverage-hook", "profile-hook", "clean-build", "lefthook", "parallel"] = reasoning
      | otherwise = broad

-- ---------------------------------------------------------------------------
-- The prompts
-- ---------------------------------------------------------------------------

-- | What the commit-years receipt is introduced as.
yearsBrief :: Text
yearsBrief =
  [wft|
  One four-digit year per commit in this repository, oldest first. The first
  line is the earliest year anything was committed here and the last line is
  the most recent: those two numbers are the copyright range, and they are
  counted rather than recalled.|]

-- | What a per-language search seat is asked.
searchBriefFor :: Text -> Text
searchBriefFor lang =
  [wft|
  The operator's tool preferences do not name a linter or a formatter for
  {lang}, and say to find the best option by live search. Answer that question
  and nothing else.

  Name the tool you would use, what it is packaged as, and how it is invoked to
  CHECK rather than to rewrite -- a pre-commit hook needs the checking form.
  Then cite where the recommendation comes from: the tool's own documentation,
  its repository, or a comparison you can name. A recommendation with no source
  is an inference, and it is labelled one.

  If the honest answer is that the ecosystem has no established option, say
  that. An absent tool named as absent is worth more here than a plausible one
  named without evidence, because the second becomes a build target that fails
  on somebody else's machine.|]

-- | What the general toolchain seat is asked, when the file list was not given.
generalSearchBrief :: Text
generalSearchBrief =
  [wft|
  No file list was given to this run, so the languages this repository is in
  were not decided in advance. Answer two things and nothing else.

  First: which languages this tree is actually written in, and what shows it --
  a manifest, a build file, an extension count.

  Second: for each of those languages that the operator's preference table does
  not name a linter or a formatter for, name the tool you would use, how it is
  invoked to CHECK rather than to rewrite, and where the recommendation comes
  from. A recommendation with no source is an inference and is labelled one.|]

-- | What each deliverable member is told about the shape of its answer.
deliverableClosing :: Text
deliverableClosing =
  [wft|
  Specify your own deliverable and nothing else. Your answer is one block of a
  specification whose other blocks are the other deliverables', each fenced
  under its own name: do not specify theirs, do not summarise the document, and
  do not add a heading of your own -- the fold supplies your name.

  Your block is written for the turn that will apply it, so it must be
  concrete: the file to write or the target to add, its contents or its
  definition, and the one command that would prove it works. A deliverable
  whose block names no verification is a deliverable nobody can tell was
  delivered.

  Where this repository already satisfies your deliverable, say so and say what
  shows it. That is a complete answer, and it costs the applying turn nothing.|]

-- | What the applying act is told, for the whole workflow.
--
-- /Source:/ @productize.md@ read as one instruction to one acting turn, plus its
-- standing shape: every deliverable is a file or a build target, and every one of
-- them has to exist before @nix flake check@ can run them.
applyBrief :: Text
applyBrief =
  [wft|
  Apply the specification below. Write each file it names and add each build
  target it defines, in the order the blocks are given, so that a deliverable
  another one depends on exists first.

  Apply what the blocks say and nothing more. Do not add a target nobody
  specified, do not reformat the tree while you are in it, and do not
  "improve" an existing file beyond what its block asks for -- this turn is
  the specification's, and anything else it does is a change nobody reviewed.

  Where a block says this repository already satisfies its deliverable, leave
  that alone.

  Do not run the checks you are adding. The next step runs `nix flake check`,
  which is deliverable 5's own answer to how any of this is verified, and its
  verdict is the one that counts.

  When you are done, reply DONE with one line per file written or target added.|]

-- | What the hook act is told.
--
-- /Source:/ @productize.md@ deliverable 18 and its parallelism bullet, and
-- @commands\/lefthook.md@, which is the same instruction addressed at one file.
hookBrief :: Text
hookBrief =
  [wft|
  Write the lefthook.yml this specification describes, and the GitHub Actions
  workflow that mirrors it.

  One command entry per check, each with the glob it applies to and the command
  it runs against the staged files. `parallel: true` where the checks are
  independent, and an explicit ordering where they are not -- a hook whose
  parallelism is wrong fails intermittently, which teaches somebody to pass
  --no-verify, which is worse than having no hook.

  The Actions workflow runs the same checks under the same names. Two lists
  that drift are two lists, and the point of this pair is that a contributor
  without the hook installed is held to the same bar.

  Write nothing else: this turn owns the hook file and the workflow file, and
  the other deliverables are somebody else's.

  When you are done, reply DONE.|]

-- ---------------------------------------------------------------------------
-- The two provenance lines
-- ---------------------------------------------------------------------------

-- | The arm where the gate came back green.
greenNote :: ProductizeRung -> Text
greenNote t =
  [wft|
  Outcome: GREEN. {what} and `nix flake check` passed on the tree that resulted
  -- which is deliverable 5's own answer to how any of this is verified, run
  rather than promised. Report each deliverable and what proves it, and name
  every one whose block said this repository already satisfied it: those are the
  ones a reader will want to check for himself.|]
  where
    what = case t of
      Full ->
        [wft|
        All twenty-one deliverables were specified block by block, applied in
        one turn|]
      Lefthook ->
        [wft|
        The pre-commit slice was specified block by block and the hook file and
        its Actions mirror were written|]

-- | The arm where the gate never came back green.
redNote :: ProductizeRung -> Text
redNote t =
  "Outcome: STILL RED. "
    <> what
    <> [wft|
       , and `nix flake check` still objects after every repair trip this run
       was given. Do not report the work as done. Quote the check's own failing
       line, name the deliverable it belongs to, and say what the next run would
       have to start with. Everything the repair trips wrote is still in the
       tree: nothing was reverted, because a half-productized repository with a
       named failure is worth more than a clean one with none of the work in it.|]
  where
    what = case t of
      Full -> "All twenty-one deliverables were specified and applied"
      Lefthook -> "The pre-commit slice was specified and its files written"

-- ---------------------------------------------------------------------------
-- The functions
-- ---------------------------------------------------------------------------

-- | The hook file, as the one thing both rungs call.
--
-- /Source:/ @commands\/lefthook.md@, whose whole content is a pointer at
-- @productize.md@'s pre-commit section. @doc\/design.md@ §7.1 row 31 says why this
-- is a function: \"slicing a section out of a sibling command by prose reference
-- is exactly the coupling that rots.\" Two call sites, one body, and the price of
-- the second is the price of the first.
lefthookFn :: Fn '[ 'CodeText] 'CodeAck
lefthookFn =
  function
    "productize.lefthook"
    (takes @"spec" Text $ noParams)
    \spec -> W.do
      act builder [wf|
          {hookBrief}

          The specification:

          {spec}|]
      done

-- | Everything the hook file is not.
--
-- A second acting turn and not one, deliberately: the hook file is written by
-- 'lefthookFn' from both rungs, and this one exists only at 'Full'. @wf plan
-- --raw@ therefore shows @productize-lefthook@ reaching exactly one of the two,
-- which is what \"without performing the rest of productization\" means.
productizeFn :: Fn '[ 'CodeText] 'CodeAck
productizeFn =
  function
    "productize.apply"
    (takes @"spec" Text $ noParams)
    \spec -> W.do
      act builder [wf|
          {applyBrief}

          The specification:

          {spec}|]
      done

-- | The brief the report is written through.
productizeReportBrief :: Text
productizeReportBrief =
  [wft|
  Write the productization report.

  Open with the provenance line you were given, verbatim, on its own line. It
  is this run's own account of how it ended, and it is not yours to soften or
  to restate.

  Then, from the specification and the gate's verdict and nothing else:

  - one line per deliverable, saying delivered, already present, or not
    applicable -- and for "not applicable", the reason its own block gave;
  - the command that verifies each delivered item;
  - what `nix flake check` said, verbatim where it objected;
  - every recommendation that was labelled an inference rather than sourced,
    because those are the build targets most likely to fail on another
    machine.

  Do not report a deliverable as delivered because its block was written. A
  block is a specification; the gate is the evidence.|]

-- | The report both endings call.
productizeReportFn :: Fn '[ 'CodeText, 'CodeText] 'CodeAck
productizeReportFn =
  function
    "productize.report"
    ( takes @"provenance" Text
        . takes @"spec" Text
        $ noParams
    )
    \provenance spec -> W.do
      act reporter [wf|
          {productizeReportBrief}

          Provenance:

          {provenance}

          The specification, and what the gate said about the tree it produced:

          {spec}

          Write the report, then reply DONE.|]
      done

-- | The table 'productizeProgram' hands @'Agentic.Workflow.defining'@.
--
-- Three entries, and @'Agentic.Workflow.defining'@ checks that every call names
-- one the list declared — so the @Lefthook@ rung, which never calls
-- 'productizeFn', still declares it. That is the table being the /family's/ and
-- not the rung's, which is "Workflows.Report"'s arrangement.
productizeTable :: [SomeFn]
productizeTable = [SomeFn lefthookFn, SomeFn productizeFn, SomeFn productizeReportFn]

-- ---------------------------------------------------------------------------
-- The program
-- ---------------------------------------------------------------------------

-- | One question per deliverable, one acting turn per file family, one gate.
--
-- Two inputs. @paths@ is the file list, one per line, and it decides the
-- preferences table and the search seats in Haskell; @scope@ is what the operator
-- says the repository is for, and it rides into the specification because a README
-- and a fuzz harness both need to know.
--
-- The shape, top to bottom: count the commit years; ask the open tool questions,
-- one per language rather than one per cell; specify every deliverable in
-- parallel; apply the specification; gate the tree on @nix flake check@; report.
-- Two endings, two provenance lines, __one__ 'productizeReportFn'.
productizeProgram :: ProductizeRung -> Parameterized
productizeProgram t =
  taking (input "paths" :> input "scope" :> noInputs) \paths scope ->
    -- Tier 1, three times: which languages are present, which of their tools are
    -- unnamed, and which deliverables this rung owns. All three are ordinary
    -- Haskell over the invocation, so `wf plan` prints the exact roster that will
    -- run and the dispatch costs nothing.
    let files = pathsOf paths
        roster = deliverableRoster t files
        searching = searchRoster files
     in defining productizeTable case t of
          Full -> W.do
            -- Deliverable 2's two numbers, counted.
            years <- ask gitCommitYears [wf|{yearsBrief}|]

            -- The five "use live web search" cells, once per language.
            tools <- panelText (zip (lensNames searching) (asksOver searching searchClosing scope))

            -- Twenty-one deliverables, one question each, folded to one
            -- specification.
            spec <- panelText (zip (lensNames roster) (deliverableAsks roster years tools scope))

            -- Two acting turns, because the hook file is the one thing the other
            -- rung also writes.
            call_ lefthookFn (arg spec :> noArgs)
            call_ productizeFn (arg spec :> noArgs)

            -- Deliverable 5, run rather than promised.
            gated <- gate nixFlakeCheck repairBrief (reasoning (model "productize-repair")) spec (atMost 2)

            case gated of
              Settled done' -> W.do
                call_ productizeReportFn (arg (greenNote t) :> arg done' :> noArgs)
                stop
              Unsettled done' -> W.do
                call_ productizeReportFn (arg (redNote t) :> arg done' :> noArgs)
                stop
          Lefthook -> W.do
            tools <- panelText (zip (lensNames searching) (asksOver searching searchClosing scope))

            -- The same seven asks the full rung would put, with the years
            -- receipt named as out of scope rather than taken: no deliverable in
            -- this slice writes a licence, so the two numbers are not counted and
            -- the run does not pay a receipt to say so.
            spec <- panelText (zip (lensNames roster) (deliverableAsks roster noYears tools scope))

            call_ lefthookFn (arg spec :> noArgs)

            gated <- gate nixFlakeCheck repairBrief (reasoning (model "productize-repair")) spec (atMost 2)

            case gated of
              Settled done' -> W.do
                call_ productizeReportFn (arg (greenNote t) :> arg done' :> noArgs)
                stop
              Unsettled done' -> W.do
                call_ productizeReportFn (arg (redNote t) :> arg done' :> noArgs)
                stop

-- | The twenty-one asks, with the years receipt, the tool answers and the scope
-- spliced into every one.
--
-- __Why this is written out rather than @'Workflows.Panels.asksOver'@.__ That
-- function splices __one__ subject, and every deliverable here needs three: a
-- receipt (the commit years), another fold (the tool recommendations), and an
-- input (the scope). @'Workflows.Panels.withEvidence'@ splices two but says of
-- the second that it is \"produced by running the commands named in
-- them\" — which is true of the years and false of the tool answers, and a
-- sentence that mislabels a model's answer as a receipt is the one thing this
-- tree's evidence discipline must not do. So the chunks are written here, in the
-- same order and importing 'Workflows.Panels.memberNote' rather than re-deriving
-- it.
deliverableAsks :: (Says a s, Says b s) => Roster -> a -> b -> Text -> [Ask s]
deliverableAsks r years tools scope =
  [ ask (lensParty l) [wf|
      {brief}

      {note}What this repository is for, in the operator's own words. It may be
      empty, and empty means the tree speaks for itself:

      {scope}

      One year per commit in this repository, oldest first:

      {years}

      What was found for the tools the preferences table does not name:

      {tools}

      {closing}|]
  | l <- r,
    let brief = lensBrief l,
    let note = memberNote r l,
    let closing = deliverableClosing
  ]

-- | What the years slot says at the @Lefthook@ rung.
--
-- The pre-commit slice carries no @license@ deliverable, so there is nothing for
-- @'Workflows.Evidence.gitCommitYears'@ to be counted for. It is a define rather
-- than an unasked receipt, which is the difference between a rung that did not
-- need a fact and a rung that has a fact it did not check.
noYears :: Text
noYears =
  [wft|
  Not counted on this rung. The pre-commit slice specifies no LICENSE.md, so the
  repository's commit years were not read: no block below may state a copyright
  range, and none of them needs one.|]

-- | What each tool seat is told about the shape of its answer.
searchClosing :: Text
searchClosing =
  [wft|
  Answer only your own question. Your answer is one block of a document whose
  other blocks are the other languages', each fenced under its own name: do not
  answer theirs, and do not summarise. The blocks are read by the turn that
  specifies the lint and format targets, so a tool named without its checking
  invocation is a tool that target cannot use.|]

-- ---------------------------------------------------------------------------
-- The registry's other column
-- ---------------------------------------------------------------------------

-- | The canned replies a @--scripted@ run of a rung answers from, keyed by
-- prefix.
--
-- __The keys are the defines themselves__, so each is a prefix of the rendered
-- prompt by construction: the years receipt opens with 'yearsBrief', each tool
-- seat with its own 'Workflows.Panels.lensBrief', and each deliverable with its
-- own.
--
-- The table is built at the __empty__ file list, which is the invocation
-- @ci\/workflows.sh@ prices and runs: 'searchRoster' is therefore the one general
-- seat, and 'preferenceTable' splices the whole preferences table into every
-- deliverable's brief. A scripted run given a real @--input-arg paths=@ falls
-- through to @'Agentic.Exec.scriptedDefault'@ for the per-language seats __and for
-- every deliverable__ — the latter because the preferences paragraph is part of
-- each brief and therefore part of each key. Both fall-throughs echo the prompt,
-- which is harmless, and the run still exits 0.
--
-- __The gate's default is what steers the ending.__ A verdict question's scripted
-- default is @APPROVE@, so @nix flake check@ passes on the first check and the run
-- ends green. To rehearse the red arm, add one @(repairBrief, …)@ row — it is
-- already here — and give the gate an objection by naming the check's own key,
-- which is the candidate rather than a brief; the simpler way to see that arm is
-- to raise the bound and watch the trip count in @wf plan --raw@.
productizeScript :: ProductizeRung -> [(Text, Text)]
productizeScript t =
  [ (yearsBrief, "2019\n2019\n2021\n2024\n2026"),
    (repairBrief, "Added the missing `checks.coverage` output to flake.nix.")
  ]
    <> [(lensBrief l, toolAnswer l) | l <- searchRoster []]
    <> [(lensBrief l, blockFor l) | l <- deliverableRoster t []]
  where
    toolAnswer l =
      [wft|
      The tree is Haskell and Nix, by `agent-workflows.cabal` and `flake.nix`.
      For Haskell the preferences table names no linter: use `hlint`, invoked as
      `hlint --no-exit-code=false` for checking, per its own README. Source: the
      hlint repository. (the {name} seat)|]
      where
        name = lensName l

    blockFor l =
      [wft|
      On {owns}: specified concretely, with the file or target named and the one
      command that proves it. Verified by `nix flake check`. (the {name} block)|]
      where
        owns = lensOwns l
        name = lensName l
