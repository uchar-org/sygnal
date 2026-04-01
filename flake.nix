{
  description = "Sygnal nixi-flaked for Uchar.";

  inputs = {
    # https://github.com/nix-community/poetry2nix/blob/ce2369db77f45688172384bbeb962bc6c2ea6f94/templates/app/flake.nix#L6
    nixpkgs.url =
      "github:NixOS/nixpkgs?rev=75e28c029ef2605f9841e0baa335d70065fe7ae2";

    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Flake utils, generators
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, pyproject-nix, ... }:
    # Per system
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (nixpkgs) lib;
        pkgs = import nixpkgs {
          inherit system;
          # overlays = [ ];
        };

        pname = "sygnal";
        version = "v0.17.0";

        python = pkgs.python310;

        project = pyproject-nix.lib.project.loadPyproject {
          # Read & unmarshal pyproject.toml relative to this project root.
          # projectRoot is also used to set `src` for renderers such as buildPythonPackage.
          projectRoot = pkgs.fetchFromGitHub {
            owner = "element-hq";
            repo = pname;
            rev = version;
            sha256 = "sha256-3edws4rGMBRy5fMbV1pjz3e7WaSvaTcn2RkJbGTz3P4=";
          };
        };

      in {
        # Formatter for your nix files, available through 'nix fmt'
        formatter = pkgs.alejandra;

        # Packages
        packages = {
          # default = pkgs.callPackage ./pkgs { inherit pkgs; }; 
          default = let
            # Returns an attribute set that can be passed to `buildPythonPackage`.
            attrs = project.renderers.buildPythonPackage {
              inherit python;

            };
            # Pass attributes to buildPythonPackage.
            # Here is a good spot to add on any missing or custom attributes.
          in python.pkgs.buildPythonPackage (attrs // {

            pname = "sygnal";
            version = "v0.17.0";

            propagatedBuildInputs = [
              (python.withPackages (python-pkgs:
                with python-pkgs; [
                  twisted
                  aioapns
                  aiohttp
                  attrs
                  google-auth
                  jaeger-client
                  matrix-common
                  opentracing
                  prometheus-client
                  py-vapid
                  pywebpush
                  pyyaml
                  sentry-sdk
                  service-identity
                ]))
            ];
          });
        };
      }) //
    # Flake attributes
    {
      # Possible services for NixOS here
      nixosModules.server = import ./module.nix self;
    };
}
