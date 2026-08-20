-- |
-- Module      : Workflows.Rubrics.Personas
-- Description : The one persona in the corpus, compressed, and the table that
--               selects it for nothing.
--
-- __Provenance.__ @~\/src\/nix\/config\/ai\/prompts\/emacs.md@ — 169 lines, and
-- @doc\/design.md@ §7.4's last-but-one row is its whole triage: it is \"the
-- corpus's only pure \'you are an expert who…\'\", its host is @issue@, and
-- \"its persona-stacking is precisely the bulk @compressFn@ exists to
-- compress — a latent @call_@ the corpus never makes\".
--
-- == Where the compression happened, and why it is not a @call_@
--
-- The design calls the persona's bulk a latent @call_ compressFn@. It is
-- written here as a define that is /already/ compressed, and the reason is
-- arithmetic: a run-time compression is a question, and a question costs. The
-- corpus pays that cost every time it stacks the persona because it has no
-- authoring step; this tree has one, so the compression happens once, at
-- authoring time, for zero questions — and 'Workflows.Prose.Polish.compressFn'
-- is the same transform available to a /run/ that must compress text it did not
-- author, which is a different job.
--
-- What the compression dropped: the @## Response Structure@ template (a
-- half-page of skeleton Elisp with docstring headings), and the @\<examples\>@
-- block (two worked exchanges). Both are illustrations of the rules above them,
-- both are a third of the file, and both are exactly what house rule 5 calls a
-- program input rather than a define.
--
-- == The table has one row, and that is the honest count
--
-- 'personaFor' is a table because a table is what a second persona would join,
-- and there is no second persona: the triage found one. It is __tier 1__
-- ("Workflows.Deciders") — ordinary Haskell over the @paths@ input, before the
-- @'Agentic.Builder.Program'@ exists — so selecting it costs zero questions and
-- zero paths, and @wf plan issue --raw@ prints the prompt the run will actually
-- send.
--
-- Nothing in @~\/src\/nix\/config\/ai@ is modified by this module.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Workflows.Rubrics.Personas
  ( -- * The persona
    emacsPersona,

    -- * The table that selects one, in Haskell, before the program exists
    personas,
    personaFor,
  )
where

import Agentic.Workflow (wf)
import Data.Text (Text)
import qualified Data.Text as T
import Workflows.Prose (wfText)

-- | @prompts\/emacs.md@'s @\<instructions\>@ block, compressed to the part a
-- fixer can be held to.
--
-- /Source:/ its @## Core Competencies@ (six bullets), @## Development
-- Guidelines@ (code standards, performance targets, error handling, security),
-- @## Specialized Handling Protocols@ and @## Output Requirements@. The
-- numbers are the file's own — \"\<300ms load time\", \"Emacs 29+\" — because a
-- target with the number filed off is not a target.
emacsPersona :: Text
emacsPersona =
  wfText
    [wf|
    You are a seasoned Emacs Lisp programmer with deep experience in
    high-performance, maintainable, extensible Emacs configurations: buffer and
    window management (display-buffer-alist, window parameters, indirect
    buffers), performance engineering (benchmark-run, memory-usage, profiler.el,
    native compilation, lazy loading), security patterns (lexical-binding,
    sandboxing untrusted code, safe evaluation, auth-source), the Emacs 29+
    feature set (tree-sitter, eglot, project.el, tab-bar, seq.el), package
    management internals (package.el, use-package, straight.el, Elpaca), and
    system integration (process management, D-Bus, plists, external tools).

    Code standards. Follow Emacs Lisp convention: double semicolons for inline
    comments, triple for section headers; package-name-function naming, with a
    double-dash prefix for private functions; built-ins before dependencies --
    cl-lib, seq, map and subr-x before anything external; and a docstring on
    every function that describes its arguments and gives an example.

    Performance. Target under 300ms of startup impact through autoloads,
    deferred loading and lazy evaluation. Watch memory with memory-report, avoid
    circular references, defer non-critical work to idle timers, and use async
    processes for anything blocking.

    Robustness. Use condition-case-unless-debug for error boundaries; degrade
    gracefully when a package or feature is absent; validate input types with
    cl-check-type; and signal user-error for a user-facing problem and error for
    a programming one.

    Security. Flag and mitigate the risks in eval-after-load, advice-add,
    file-local-variables and evaluation of untrusted Elisp. Prefer make-process
    over shell-command, verify permissions and handle symlinks with care, and
    never hardcode a credential where auth-source will serve.

    Output. Give working code that can be evaluated as it stands, with brief
    inline comments for the non-obvious choices only. Cite an authoritative
    source -- a manual node, package documentation -- for an advanced technique.
    Name the platform-specific behaviour and the gotchas, and suggest the
    profiling command for anything on a hot path. Target Emacs 29 or later by
    default and say so when reaching past it.|]

-- | The personas, and the file suffixes that select each.
--
-- One row, because the corpus has one persona. The shape is
-- 'Workflows.Rubrics.Reviewers.languages'\' — a glob column beside a rubric —
-- so a second persona arrives by being added to this list and reaches every
-- caller of 'personaFor' by arriving.
personas :: [([Text], Text)]
personas = [([".el"], emacsPersona)]

-- | The persona a file list selects, or the empty text.
--
-- __Tier 1__: the fact is in the invocation. The empty result is the common
-- case and it is deliberately empty rather than a general-purpose paragraph: a
-- fixer told nothing about who it is answers as itself, which is what every
-- other program in this tree asks of it.
personaFor :: [Text] -> Text
personaFor files =
  case [p | (globs, p) <- personas, any touching globs] of
    (p : _) -> p
    [] -> ""
  where
    touching g = any (g `T.isSuffixOf`) files
