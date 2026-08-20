-- |
-- Module      : Workflows.Prelude
-- Description : The one import a workflow module writes.
--
-- A program in this tree opens with a LANGUAGE block and two imports:
--
-- > {-# LANGUAGE BlockArguments, DataKinds, OverloadedStrings #-}
-- > {-# LANGUAGE QualifiedDo, QuasiQuotes, RebindableSyntax #-}
-- >
-- > import Workflows.Prelude
-- > import qualified Agentic.Workflow.Do as W
-- > import Prelude
--
-- and then writes ordinary Haskell.
--
-- __Three things the header cannot avoid, and why.__
--
--   * @'Agentic.Workflow.Do'@ stays a separate qualified import: @W.do@ is
--     @QualifiedDo@, which names a /module/, and a re-export cannot supply the
--     qualifier.
--   * @Prelude@ is imported explicitly because @RebindableSyntax@ is what an
--     authoring module /is/ — it is how @if@ reaches
--     @'Agentic.Workflow.ifThenElse'@ rather than @Bool@ — and it turns off the
--     implicit @Prelude@ import along the way.
--   * @Data.String (fromString)@ comes with it when the module uses string
--     literals at 'Data.Text.Text', because @OverloadedStrings@ under
--     @RebindableSyntax@ resolves @fromString@ by name.
--
-- __This module re-exports; it defines nothing.__ Everything in it is somewhere
-- else, and the haddock that says where a rubric came from is on the binding and
-- not here. The mechanics — @wfText@, @bullets@, @tshow@ — are
-- "Workflows.Prose", which the foundation modules import directly, because a
-- module this one re-exports cannot import it.
module Workflows.Prelude
  ( -- * The language
    module Agentic.Workflow,

    -- * The mechanics
    module Workflows.Prose,

    -- * Who answers, and with what
    module Workflows.Parties,
    module Workflows.Evidence,

    -- * What the prompts say
    module Workflows.Rubrics.Discipline,
    module Workflows.Rubrics.Fess,
    module Workflows.Rubrics.Finding,
    module Workflows.Rubrics.Ladder,
    module Workflows.Rubrics.Reviewers,
    module Workflows.Rubrics.Stances,

    -- * The shapes
    module Workflows.Deciders,
    module Workflows.Escalation,
    module Workflows.Gates,
    module Workflows.Panels,
    module Workflows.Report,
  )
where

import Agentic.Workflow
import Workflows.Deciders
import Workflows.Escalation
import Workflows.Evidence
import Workflows.Gates
import Workflows.Panels
import Workflows.Parties
import Workflows.Prose
import Workflows.Report
import Workflows.Rubrics.Discipline
import Workflows.Rubrics.Fess
import Workflows.Rubrics.Finding
import Workflows.Rubrics.Ladder
import Workflows.Rubrics.Reviewers
import Workflows.Rubrics.Stances
