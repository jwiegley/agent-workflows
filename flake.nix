{
  description = "agent-workflows — John's commands, agents and skills as priced agent-cat programs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Not a flake: agent-cat's flake.nix exposes a Lean devShell and
    # agent-cat/haskell/flake.nix exposes a GHC devShell — there are no Haskell
    # package outputs anywhere in agent-cat. So what this repository needs from
    # it is the source tree, and cabal2nix. Pinning it here is what makes
    # `nix build` reproducible; `cabal.project` is what makes the inner loop
    # fast, and the README says which wins when they disagree.
    agent-cat = {
      url = "github:jwiegley/agent-cat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, agent-cat }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Everything `nix build` should not have to look at: build products, the
        # direnv cache, the `result` symlinks (which are DANGLING until
        # something has been built, and a dangling symlink in a source tree is
        # an evaluation error rather than a slow copy).
        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            let base = baseNameOf (toString path);
            in !(builtins.elem base [ "dist-newstyle" ".direnv" "result" ".git" ])
               && !(pkgs.lib.hasPrefix "result-" base);
        };

        # One overlay over the default package set, because `agentic` and this
        # package must see ONE GHC and one `text`. `agent-cat/haskell` is a
        # subdirectory of a source tree, which is exactly what callCabal2nix
        # takes.
        hs = pkgs.haskellPackages.extend (final: prev: {
          agentic = final.callCabal2nix "agentic" "${agent-cat}/haskell" { };
          agent-workflows = final.callCabal2nix "agent-workflows" src { };
        });

        workflowExe = pkgs.haskell.lib.justStaticExecutables hs.agent-workflows;
        taskmasterStage = pkgs.writeShellScriptBin "wf-taskmaster-stage" ''
          exec ${pkgs.python3}/bin/python3 ${src}/tools/wf-taskmaster-stage "$@"
        '';
      in {
        packages.default = pkgs.symlinkJoin {
          name = "agent-workflows";
          paths = [ workflowExe taskmasterStage ];
        };
        packages.agent-workflows = self.packages.${system}.default;

        # `cabal build`, `cabal run wf`, `./ci/workflows.sh`.
        #
        # BOTH packages are listed, to match `cabal.project`: the inner loop
        # builds `agentic` from the sibling working tree, so what the shell must
        # supply is `agentic`'s dependencies (aeson, QuickCheck, …) and not
        # `agentic` itself. Listing only this package would put a pinned
        # `agentic` in the package database that cabal would then shadow with a
        # local build whose own dependencies were never brought in.
        devShells.default = hs.shellFor {
          packages = p: [ p.agent-workflows p.agentic ];
          nativeBuildInputs = [ pkgs.cabal-install pkgs.haskell-language-server ];
        };
      });
}
