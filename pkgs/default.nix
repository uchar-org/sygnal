{ lib, python3Packages, pkgs, ... }:
let
  # Library instance
  pypkgs-build-requirements = {
    types-opentracing = [ "setuptools" ];
    google-auth-stubs = [ "poetry-core" "setuptools" ];
    grpc-stubs = [ "setuptools" ];
  };
  packageOverrides = final: prev:
    (builtins.mapAttrs (package: build-requirements:
      (builtins.getAttr package prev).overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg:
          if builtins.isString pkg then builtins.getAttr pkg prev else pkg)
          build-requirements);
      })) pypkgs-build-requirements) // {
        ruff = prev.ruff.overridePythonAttrs (old: {
          postPatch = ''
            substituteInPlace crates/ruff_python_ast/src/nodes.rs \
              --replace-fail 'assert_eq_size!(Pattern, [u8; 96]);' '// removed'
          '';
          cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./Cargo.ruff.lock;
            outputHashes = {
              "unicode_names2-0.6.0" =
                "sha256-eWg9+ISm/vztB0KIdjhq5il2ZnwGJQCleCYfznCI3Wg=";
            };
          };
        });
      };

  python = pkgs.python3.override { inherit packageOverrides; };

in python3Packages.buildPythonPackage rec {
  pname = "sygnal";
  version = "v0.17.0";

  python3 = python;

    # No tests
  doCheck = false;


  src = pkgs.fetchFromGitHub {
    owner = "element-hq";
    repo = pname;
    rev = version;
    sha256 = "sha256-3edws4rGMBRy5fMbV1pjz3e7WaSvaTcn2RkJbGTz3P4=";
  };

  meta = {
    mainProgram = "sygnal";
    platforms = with pkgs.lib.platforms; linux ++ darwin;
  };
}
