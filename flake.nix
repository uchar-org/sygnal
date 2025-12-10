{
  description = "Sygnal nixi-flaked for Uchar.";

  inputs = {
    # Nixpkgs for vanilla way
    nixpkgs-v.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Nixpkgs for poetry version
    # https://github.com/nix-community/poetry2nix/blob/ce2369db77f45688172384bbeb962bc6c2ea6f94/templates/app/flake.nix#L6
    nixpkgs-p.url = "github:NixOS/nixpkgs?rev=75e28c029ef2605f9841e0baa335d70065fe7ae2";

    # Flake utils, generators
    flake-utils.url = "github:numtide/flake-utils";

    # Poetry to Nix
    poetry2nix.url = "github:nix-community/poetry2nix";

    # For vanilla specific deps hunting
    nixpkkgs-aioapns.url = "github:NixOS/nixpkgs?rev=ebe4301cbd8f81c4f8d3244b3632338bbeb6d49c";
    nixpkkgs-prometheus-client.url = "github:NixOS/nixpkgs?rev=ebe4301cbd8f81c4f8d3244b3632338bbeb6d49c"; # TODO: cp'ed from above, find it
  };

  outputs = {
    self,
    nixpkgs-v,
    nixpkgs-p,
    flake-utils,
    poetry2nix,
    ...
  }:
  # Per system
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs-v = import nixpkgs-v {
        inherit system;
        overlays = [
          # Required python deps
          (import ./overlay.nix)
        ];
      };

      pkgs-p = import nixpkgs-p {
        inherit system;
        overlays = [
          # Required python deps
          poetry2nix.overlays.default
        ];
      };
    in {
      # Formatter for your nix files, available through 'nix fmt'
      formatter = pkgs-v.alejandra;

      # Development shells
      devShells = {
        default = import ./shell.nix {
          pkgs = pkgs-v;
          inherit (self.checks.${system}) pre-commit-check;
        };
      };

      # Packages
      packages = rec {
        default = poetry;
        vanilla = pkgs-v.callPackage ./pkgs/vanilla.nix {pkgs = pkgs-v;};
        poetry = pkgs-p.callPackage ./pkgs/poetry.nix {
          inherit self;
          pkgs = pkgs-p;
        };
      };
    })
    //
    # Flake attributes
    {
      # Possible services for NixOS here
    };
}
