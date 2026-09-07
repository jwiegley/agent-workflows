{
  description = "agent-workflows — John's commands, agents and skills as priced agent-cat programs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Read agent-cat source directly: root hosts its one Cabal package. Pinning
    # source makes `nix build` reproducible; `cabal.project` keeps local
    # iteration fast.
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

        # agent-cat exposes one public Cabal package from its repository root.
        hs = pkgs.haskell.packages.ghc910.extend (final: prev:
          # The existing pre-TUI pin has no dependency overrides.
          pkgs.lib.optionalAttrs (builtins.pathExists "${agent-cat}/nix/haskell-overrides.nix")
            ((import "${agent-cat}/nix/haskell-overrides.nix") pkgs final prev)
          // {
          agentic = final.callCabal2nix "agentic" agent-cat { };
          agent-workflows = final.callCabal2nix "agent-workflows" src {
            agentic = final.agentic;
          };
        });

        workflowExe = hs.agent-workflows;
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
        # `agentic` supplies agent-cat dependencies while Cabal resolves its
        # sibling working-tree copy from `cabal.project`.
        devShells.default = hs.shellFor {
          packages = p: [ p.agent-workflows p.agentic ];
          nativeBuildInputs = [ pkgs.cabal-install pkgs.haskell-language-server ];
        };
      });
}
