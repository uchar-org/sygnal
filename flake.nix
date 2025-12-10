{
  description = "Sygnal nixi-flaked for Uchar.";

  inputs = {
    # Nixpkgs latest
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Flake utils, generators
    flake-utils.url = "github:numtide/flake-utils";

    # Poetry to Nix
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # Pre commit hooks for git
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
    pre-commit-hooks,
    ...
  }:
  # Per system
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [poetry2nix.overlays.default];
      };
    in {
      # Formatter for your nix files, available through 'nix fmt'
      formatter = pkgs.alejandra;

      # Development shells
      devShells = {
        default = import ./shell.nix {
          inherit pkgs;
          inherit (self.checks.${system}) pre-commit-check;
        };
      };

      # Packages
      packages = rec {
        default = server;
        server = pkgs.callPackage ./. {inherit pkgs;};
      };

      # Checks for hooks
      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            statix = let
              pkgs = inputs.nixpkgs.legacyPackages.${system};
            in {
              enable = true;
              package =
                pkgs.statix.overrideAttrs
                (_o: rec {
                  src = pkgs.fetchFromGitHub {
                    owner = "oppiliappan";
                    repo = "statix";
                    rev = "e9df54ce918457f151d2e71993edeca1a7af0132";
                    hash = "sha256-duH6Il124g+CdYX+HCqOGnpJxyxOCgWYcrcK0CBnA2M=";
                  };

                  cargoDeps = pkgs.rustPlatform.importCargoLock {
                    lockFile = src + "/Cargo.lock";
                    allowBuiltinFetchGit = true;
                  };
                });
            };
            alejandra.enable = true;
            # flake-checker.enable = true;
          };
        };
      };
    })
    //
    # Flake attributes
    {
      # Possible services for NixOS here
    };
}
