{
  description = "agent-workflows — John's commands, agents and skills as priced agent-cat programs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Read agent-cat source directly: root hosts its one Cabal package. Pinning
    # source makes `nix build` reproducible; `cabal.project` keeps local
    # iteration fast.
    agent-cat = {
      url = "github:jwiegley/agent-cat/8cf54e9808dd8dfc1c28175cddb8d9cdf0dee427";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      agent-cat,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Everything `nix build` should not have to look at: build products, the
        # direnv cache, the `result` symlinks (which are DANGLING until
        # something has been built, and a dangling symlink in a source tree is
        # an evaluation error rather than a slow copy).
        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter =
            path: type:
            let
              base = baseNameOf (toString path);
            in
            !(builtins.elem base [
              "dist-newstyle"
              ".direnv"
              "result"
              ".git"
            ])
            && !(pkgs.lib.hasPrefix "result-" base);
        };

        # agent-cat exposes one public Cabal package from its repository root.
        hs = pkgs.haskell.packages.ghc910.extend (
          final: prev:
          (import "${agent-cat}/nix/haskell-overrides.nix") pkgs final prev
          // {
            agentic = final.callCabal2nix "agentic" agent-cat { };
            agent-workflows = pkgs.haskell.lib.overrideCabal (final.callCabal2nix "agent-workflows" src {
              agentic = final.agentic;
            }) (old: {
              testToolDepends = (old.testToolDepends or [ ]) ++ [ pkgs.python3 ];
            });
          }
        );

        workflowExe = hs.agent-workflows;
        taskmasterStage = pkgs.writeShellScriptBin "wf-taskmaster-stage" ''
          exec ${pkgs.python3}/bin/python3 ${src}/tools/wf-taskmaster-stage "$@"
        '';
        translationStage = pkgs.writeShellScriptBin "wf-translate-stage" ''
          exec ${pkgs.python3}/bin/python3 ${src}/tools/wf-translate-stage "$@"
        '';
      in
      {
        packages.default = pkgs.symlinkJoin {
          name = "agent-workflows";
          paths = [
            workflowExe
            taskmasterStage
            translationStage
          ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/wf" --prefix PATH : "${taskmasterStage}/bin:${translationStage}/bin"
          '';
        };
        packages.agent-workflows = self.packages.${system}.default;

        # `cabal build`, `cabal run wf`, `./ci/workflows.sh`.
        #
        # `agentic` supplies agent-cat dependencies while Cabal resolves its
        # sibling working-tree copy from `cabal.project`.
        devShells.default = hs.shellFor {
          packages = p: [
            p.agent-workflows
            p.agentic
          ];
          nativeBuildInputs = [
            pkgs.cabal-install
            pkgs.emacs
            pkgs.python3
            pkgs.openssh
            pkgs.haskell-language-server
            pkgs.pkg-config
          ];
          WF_CONTROL_ADAPTERS = "${agent-cat}/engine/acp/test";
          buildInputs = [ pkgs.zlib ];
        };
      }
    );
}
