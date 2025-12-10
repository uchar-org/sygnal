{pkgs, ...}: let
  # Library instance
  inherit (pkgs) poetry2nix lib;
in
  poetry2nix.mkPoetryApplication rec {
    pname = "sygnal";
    version = "v0.17.0";

    python3 = pkgs.python310;

    projectDir = pkgs.fetchFromGitHub {
      owner = "element-hq";
      repo = pname;
      rev = version;
      sha256 = "sha256-3edws4rGMBRy5fMbV1pjz3e7WaSvaTcn2RkJbGTz3P4=";
    };

    # Helpless, gotta fork the whole p2n and add value to getCargoHash.
    # https://github.com/nix-community/poetry2nix/blob/ce2369db77f45688172384bbeb962bc6c2ea6f94/overrides/default.nix#L3466
    overrides = poetry2nix.overrides.withDefaults (
      final: prev: {
        ruff = prev.ruff.overridePythonAttrs (
          old: {
            cargoLock.outputHashes."unicode_names2-0.6.0" = "hash";
          }
        );
      }
    );
  }
