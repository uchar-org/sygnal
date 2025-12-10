{
  pkgs ? let
    lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
    nixpkgs = fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
      sha256 = lock.narHash;
    };
  in
    import nixpkgs {overlays = [];},
  ...
}: let
  # Library instance
  inherit (pkgs) poetry2nix lib;
in
  poetry2nix.mkPoetryApplication {
    projectDir = poetry2nix.cleanPythonSources {
      src = pkgs.fetchFromGitHub {
        owner = "element-hq";
        repo = "sygnal";
        rev = "v0.17.0";
        sha256 = "sha256-3edws4rGMBRy5fMbV1pjz3e7WaSvaTcn2RkJbGTz3P4=";
      };
    };

    overrides = poetry2nix.overrides.withDefaults (
      final: super:
        lib.mapAttrs
        (attr: systems:
          super.${attr}.overridePythonAttrs
          (old: {
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ map (a: final.${a}) systems;
          }))
        {
          package = ["setuptools"];
        }
    );
  }
