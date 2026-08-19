-- | @wf@ — list, plan, price and run the owner's workflows.
--
-- The CLI is "Agentic.Cli", parameterized by the registry it serves; this
-- executable is that function applied to "Workflows.Registry"'s table, and
-- @agentic-run@ is the same function applied to the examples'. Two binaries, two
-- registries, two gates, one argument parser. The argument for the split is in
-- "Workflows.Registry"'s haddock.
--
-- > wf list
-- > wf plan  <workflow> [--raw] [--require-pinned] [<input>...]
-- > wf cost  <workflow> [<input>...]
-- > wf run   <workflow> --scripted [<input>...]
-- > wf run   <workflow> --engine acp [--adapter claude|codex|stub|PATH] …
-- > wf run   <workflow> --session <id> …
module Main (main) where

import Agentic.Cli (cliMain)
import Workflows.Registry (registry)

main :: IO ()
main = cliMain registry
