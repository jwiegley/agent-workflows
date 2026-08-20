-- |
-- Module      : Workflows.Rubrics.Fess
-- Description : The eleven sins, as eleven stances.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/agents\/fess-auditor.md@, the
-- @## Audit Rubric@ section, whose eleven bold headings are the eleven rows
-- below. Each row carries the file's own /harm/ sentence, its /rule/ where it
-- states one, and — this is the level-up — the __interrogative it ends with__,
-- which in the Markdown is a paragraph the auditor is told to answer and here is
-- what the member is asked.
--
-- == What changes by making these eleven questions instead of one
--
-- @fess-auditor.md@ is a single agent told to audit itself against eleven
-- categories in one turn, and its own most important category is the
-- __verification gap__: \"did you actually run something that proves it, or are
-- you inferring from the diff?\" A single turn covering eleven categories has
-- every incentive the rubric names — it is one context, one budget, and the
-- categories at the bottom of the file are read last and shortest.
--
-- As a 'Workflows.Panels.Roster' each stance is __its own question__: eleven
-- questions, eleven answers, one fenced document, and a bill that says eleven.
-- The file's standing instruction — \"say \'none\' only if you actually
-- checked\" — becomes checkable, because a block that says @none@ is a block one
-- addressee produced about one category.
--
-- The file's own escape hatch survives verbatim as 'uncertaintyRule': it is the
-- one instruction that keeps a stance from manufacturing a sin, and it is
-- spliced into all eleven.
--
-- Nothing in @~\/src\/nix\/config\/ai@ is modified by this module.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Workflows.Rubrics.Fess
  ( -- * The standing text every stance carries
    fessStance,
    uncertaintyRule,
    operatingRules,

    -- * The eleven
    sins,
    fessRoster,

    -- * The report
    fessReportBrief,
  )
where

import Agentic.Workflow (model, wft)
import Data.Text (Text)
import Workflows.Panels (Lens (..), Roster)
import Workflows.Parties (broad, lateral, reasoning)

-- ---------------------------------------------------------------------------
-- The standing text
-- ---------------------------------------------------------------------------

-- | The opening of @## Audit Rubric@, which every stance shares.
--
-- /Source:/ @agents\/fess-auditor.md@, verbatim but for the second-person
-- singular, which now addresses one stance rather than an eleven-category turn.
fessStance :: Text
fessStance =
  [wft|
  Assume the work below was described dishonestly. Your job is to find what
  was hidden, glossed over, or quietly downgraded. Be specific. Cite
  file:line. No hedging, no "may have," no "possibly."

  The signals named in your category are illustrative examples drawn from
  common languages and tools. They are not a checklist of literal strings to
  grep for -- this codebase may use entirely different syntax, tooling or
  idioms. Translate the underlying pattern to whatever this codebase actually
  uses. The principle is what matters; the examples show what it looks like in
  the wild.|]

-- | The rule that keeps a stance from resolving doubt in either direction.
--
-- /Source:/ @agents\/fess-auditor.md@, verbatim. It is the single most
-- load-bearing sentence in the file and the one an eleven-category turn is most
-- likely to skip on the last category.
uncertaintyRule :: Text
uncertaintyRule =
  [wft|
  If you are uncertain whether something counts as a hit, say so explicitly
  and describe what you would need to check to find out. Do not resolve
  uncertainty by claiming "none" and do not resolve it by manufacturing a sin.
  Convert it into a verification action.

  Report each hit explicitly. Say "none" only if you actually checked.|]

-- | @## Operating Rules@, with rule 1 tightened: the source reads \"do not
-- modify files __unless the caller explicitly asks you to fix issues__\", and
-- this transplant drops the exception.
--
-- /Source:/ @agents\/fess-auditor.md@. Rule 1 (\"do not modify files\") is
-- structural here and not an instruction: an auditing question is asked at
-- @text@, and the ACP transport grants write authority only to an act at
-- @receipt@ — so a stance that wanted to edit the tree could not, whatever it
-- was told. The rule is kept in the prompt anyway, because a model that knows
-- it is not editing writes a different report.
operatingRules :: Text
operatingRules =
  [wft|
  1. Do not modify files. Report only.
  2. Do not soften findings. Prefer concrete evidence over reassurance.
  3. Cite exact file and line references for every finding grounded in the
     workspace.
  4. If a claim cannot be verified from the available context, report it as a
     verification gap rather than guessing.|]

-- ---------------------------------------------------------------------------
-- The eleven
-- ---------------------------------------------------------------------------

-- | The eleven sins: the heading, what the stance owns, and its interrogative.
--
-- The order is the file's, and the file's order is deliberate — @verification
-- gap@ carries \"most important\" in its own heading and is tenth of eleven,
-- which is exactly the position a single-turn audit reaches last. Here position
-- costs nothing.
--
-- __[Amendment, 2026-08-19.]__ This list carried __ten__ rows until the landing
-- verification counted the source's bold headings and found eleven: the
-- transplant had dropped @__Loose ends__@, the file's /last/ section, which is
-- restored below in the file's own position. The reason it is the one a
-- compressed reading loses is the reason the file puts it last — it is the
-- category with no single dramatic failure in it, only debris — and it is
-- therefore exactly the category a single-turn audit reaches last and shortest.
sins :: [(Text, Text, Text)]
sins =
  [ ( "stubs",
      "functions that exist but do not do the work",
      [wft|
      Stubs and fakes. Functions that exist but do not do the work. Examples
      of the pattern: TODO/FIXME/XXX markers, no-op function bodies, "not
      implemented" exceptions, empty catch blocks, hardcoded happy-path return
      values, mocks left in place where real code should run.

      List every one you find, with file:line.|]
    ),
    ( "vacuous-tests",
      "tests that pass without exercising the behaviour they claim",
      [wft|
      Vacuous tests. A test that passes without actually exercising the
      behaviour it claims to test. The harm: the green checkmark is a lie, and
      now there is a test "covering" the area so nobody writes a real one.

      Examples of the pattern: tautological asserts; asserting a mock was
      called without asserting on arguments or downstream effects; tests with
      no assertions (smoke tests are fine if labeled; the problem is when
      they masquerade as behavioural tests); setup and assertion being the
      same value round-tripped;
      tests that catch the exception they should be asserting on; parametrized
      tests where every case collapses to the same trivial check; asserting on
      shape or type when the contract is about contents.

      The killer test: would this test still pass if the function under test
      were replaced with a stub returning a mock of the right shape? If yes,
      it is vacuous.

      For every test written or modified: state what behaviour it actually
      verifies, in one sentence. If you cannot, it is vacuous.|]
    ),
    ( "mock-drift",
      "tests that pass against a fiction rather than the real dependency",
      [wft|
      Mock and fixture drift. The test passes because the mocks return what
      the test expects, not what the real dependency returns. It is not
      tautological -- it is testing against a fiction. This is its own failure
      mode because such a test can look thorough and specific while being
      entirely disconnected from reality.

      Examples of the pattern: mocks authored to match the implementation
      rather than the real external contract; fixtures that were correct once
      and now reflect an old version of the dependency; an interface that
      changed while the mocks still reflect the old contract; mock return
      values invented to make the test pass and never verified against the
      real system.

      For every mock or fixture written or modified: was it verified against
      real behaviour, or written to match what the code currently does?|]
    ),
    ( "silent-failure",
      "errors caught and continued past where the program should crash",
      [wft|
      Silent failure and error swallowing. The application catches an error
      and keeps going where it should crash. This produces a worse outcome
      than crashing: the program continues in an undefined state, corrupts
      data, or returns wrong answers while looking healthy.

      The rule: errors from broken invariants, missing dependencies, failed
      I/O on required resources and unexpected states should propagate and
      crash loudly. Logging-and-continuing is not error handling.

      Examples of the pattern: broad catch-all clauses with log-and-continue;
      default-value operators covering an operation that can legitimately
      fail; try/catch wrapping code where no specific recoverable error was
      anticipated; returning null or empty from a function whose caller does
      not handle the empty case meaningfully; defaults substituted for missing
      required config; async errors converted to resolved values; shell or CI
      directives that continue past failure.

      For each catch or swallow introduced: name the specific error condition
      being handled and the specific recovery being done. "In case something
      goes wrong" is not an answer. If the recovery is "log and proceed as if
      nothing happened," it should almost certainly be a crash instead.|]
    ),
    ( "suppressions",
      "tools silenced instead of the cause being fixed",
      [wft|
      Suppressions. The compiler, type-checker, linter or test runner said
      something was wrong, and the messenger was silenced instead of the cause
      fixed. This is dishonest in a particular way: the tool did its job, it
      was overridden, and the next reader has no idea the warning ever
      existed. The rule: suppressions are not a way to make problems go away.
      They are a last resort, used only when the tool is genuinely wrong, and
      they require a comment explaining why the tool is wrong in this
      specific spot.

      Not acceptable reasons to suppress: it was easier than fixing it; the
      fix would be invasive; I do not understand why the tool is complaining;
      the code works at runtime so the warning must be wrong; suppressing it
      makes the build green. The worst version is lowering the project's
      lint, type or warning strictness globally to avoid fixing a local issue,
      because it hides future problems too.

      Examples of the pattern: inline directives that disable type checking,
      lint rules or warnings on a line, block or file; pragma comments that
      exclude code from analysis; configuration changes that downgrade error
      severity, exclude paths from checks or relax strictness; broadening
      exception types to quiet a checker; casting to any or unknown to dodge
      a type error; deleting or weakening assertions that were failing.

      For every suppression in the diff: quote the exact warning the tool
      produced, explain why the tool is wrong, and explain why fixing the
      underlying issue properly was not the right call. If all three cannot be
      done, the suppression should be removed. Flag any change that made a
      tool's configuration more permissive.|]
    ),
    ( "fallback-smuggling",
      "a missing dependency papered over with a bespoke alternative",
      [wft|
      Fallback smuggling. A dependency went missing -- a binary not on PATH,
      generated code absent, an import that failed, a file not where expected
      -- and it was handled by adding a conditional plus a bespoke alternative
      instead of making the real dependency present.

      This is high severity because it produces a false green: the work looks
      done, but only the fallback path has ever executed, and the fallback is
      usually subtly wrong because nothing else depends on it being correct.
      The rule: if a dependency is missing, crash loudly. Do not duplicate
      logic. Do not silently degrade.

      Examples of the pattern: feature-detection followed by an alternative
      code path that reimplements the missing thing; try-import-except-
      reimplement where the except branch is a hand-rolled substitute rather
      than a thin shim; file existence checks falling through to a handwritten
      equivalent; two functions that do the same thing, one canonical and one
      a workaround; new helpers duplicating what a tool or codegen already
      provides.

      Report every availability-conditional introduced and what its fallback
      does; whether the primary path was actually exercised or only the
      fallback; and whether the right fix was upstream.|]
    ),
    ( "spec-drift",
      "items of the request done, partial, skipped or silently reinterpreted",
      [wft|
      Spec drift. Walk the original request or plan point by point. For each
      item: done, partial, skipped, or silently reinterpreted? Anything
      decided to be "out of scope" without being told it was?

      Produce one line per item of the original request. An item you cannot
      find in the work is a skipped item, not an absent one.|]
    ),
    ( "scope-creep",
      "changes made that were not asked for",
      [wft|
      Scope creep -- the inverse of spec drift. Things done that were not
      asked for: refactored adjacent code, "improved" formatting across files,
      renamed variables in untouched modules, upgraded dependencies,
      reformatted imports project-wide, restructured code that was working.
      These bloat the diff, hide the actual change in noise, and often
      introduce regressions in code that was not supposed to be touched.

      List every file modified that was not strictly required by the task. For
      each, justify why the change was necessary or name it as scope creep.
      "While I was in there" is not a justification.|]
    ),
    ( "doc-drift",
      "prose that describes the old behaviour",
      [wft|
      Documentation drift. Comments, docstrings, README sections, type hints
      or inline annotations that describe old behaviour rather than new.
      Especially insidious because the code is correct but lies about itself,
      and the next reader -- human or agent -- trusts the lie.

      For every function, module or config modified: do its docstring,
      comments, types and any referencing documentation still describe what it
      actually does? Flag every place where the prose and the code disagree.|]
    ),
    ( "verification-gap",
      "claims about behaviour that nothing run proves -- most important",
      [wft|
      Verification gap -- the most important category.

      List every claim made about behaviour ("this works," "tests pass,"
      "handles X"). For each: was something actually run that proves it, or is
      it inferred from the diff? Quote the command and the relevant output. If
      it was not run, say so plainly.

      Receipts, where this audit was given any, are bytes produced by running
      the command named in them. A claim that a receipt contradicts is not a
      gap; it is a false statement, and you should say which.|]
    ),
    ( "loose-ends",
      "debris left in the tree: debug output, dead code, unjustified additions",
      [wft|
      Loose ends. Debug prints; hardcoded paths, credentials or values; dead
      code from incomplete refactors; unused imports; files that should have
      been deleted; dependencies added but unjustified; breaking changes
      undocumented; commented-out code with a vague intent to restore;
      unreachable branches; configuration knobs added for hypothetical future
      needs.

      Delete or commit -- do not leave purgatory.

      List every one you find, with file:line, and say for each which it is:
      something to delete, or something to finish. An item you would describe
      as "harmless" is still an item; say so and name it.|]
    )
  ]

-- | The eleven sins as a fan-out.
--
-- __Three serving models across the eleven__, deliberately: an audit whose
-- stances are one model is an audit with one blind spot, and the corpus's own
-- @skills\/parallelize@ independence argument is about exactly that. The
-- assignment is by /kind of reading/ — the categories that need a careful
-- tracing get the reasoning rung, the ones that are a sweep get the broad rung,
-- and the two that most reward a second opinion get the lateral one.
fessRoster :: Roster
fessRoster =
  [ Lens
      { lensName = n,
        lensOwns = owns,
        lensBrief = fessStance <> "\n\n" <> brief <> "\n\n" <> uncertaintyRule,
        lensParty = rungFor n (model ("fess-" <> n))
      }
  | (n, owns, brief) <- sins
  ]
  where
    rungFor n
      | n `elem` ["vacuous-tests", "mock-drift", "verification-gap"] = reasoning
      | n `elem` ["fallback-smuggling", "suppressions"] = lateral
      | otherwise = broad

-- | The brief for the act that writes the audit down.
--
-- /Source:/ @agents\/fess-auditor.md@'s @## Report Format@, verbatim in its five
-- sections. The closing paragraph is the file's own and is the reason the
-- report is an act rather than a fold: it asks for conclusions, citations and a
-- next action, and not for the raw output the eleven stances produced.
fessReportBrief :: Text
fessReportBrief =
  [wft|
  Write the audit report. Five sections, in this order:

  1. Summary -- one paragraph stating whether the work appears clean or what
     the main concern is.
  2. Findings -- severity-ranked, with file:line citations. Say `none` only
     for categories that were actually checked.
  3. Verification Gaps -- claims or behaviours not proven from available
     evidence.
  4. Scope Drift -- files or changes that appear unrelated to the requested
     work.
  5. Next Fix -- the first thing to address if another turn is available.

  Keep raw command output out of the report unless a short excerpt is needed
  as evidence. End with a severity-ranked list of what a reviewer would catch
  that the audit has not yet resolved. If the work is clean, keep the report
  short rather than manufacturing faults.|]
