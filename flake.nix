{
  # credit: https://docs.haskellstack.org/en/stable/nix_integration/#using-a-custom-shellnix-file
  description = ''
    A haskell-flavored flake
  '';

  inputs = {
    # stackage LTS 22.22 / ghc965 (May 19 2024) / hls 2.8.0.0
    nixpkgs.url = "github:NixOS/nixpkgs/1faadcf5147b9789aa05bdb85b35061b642500a4";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Need to match Stackage LTS version from stack.yaml resolver,
        # we do this by pinning the specific version of nixpkgs so that
        #     a) haskellPackages is the default one, its more tested
        #     b) haskellPackages is cached by cache.nixos.org
        #     c) the pin ensures that it matches the version stack wants to use
        hPkgs = pkgs.haskellPackages;

        devTools = [
          stack-wrapped
          hPkgs.haskell-language-server
          hPkgs.ghc
        ];

        # Wrap Stack to work with our Nix integration. We don't want to modify
        # stack.yaml so non-Nix users don't notice anything.
        # --no-nix: We don't want Stack's way of integrating Nix.
        # --system-ghc    # Use the existing GHC on PATH (will come from this Nix file)
        # --no-install-ghc  # Don't try to install GHC if no matching GHC found on PATH
        stack-wrapped = pkgs.symlinkJoin {
          name = "stack"; # will be available as the usual `stack` in terminal
          paths = [ pkgs.stack ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/stack \
              --add-flags "--no-nix --system-ghc --no-install-ghc"
          '';
        };
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        packages = {
          default = pkgs.haskellPackages.callCabal2nix "simple" ./. { };
          justStaticExecutables = pkgs.haskell.lib.justStaticExecutables self.packages.${system}.default;
        };

        devShells.default = pkgs.mkShell {
          packages = devTools;

          # Make external Nix c libraries like zlib known to GHC, like pkgs.haskell.lib.buildStackProject does
          # https://github.com/NixOS/nixpkgs/blob/d64780ea0e22b5f61cd6012a456869c702a72f20/pkgs/development/haskell-modules/generic-stack-builder.nix#L38
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath devTools;
        };
      }
    );
}
