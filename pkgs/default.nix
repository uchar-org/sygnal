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

  python = pkgs.python3.override {
    self = python;
    inherit packageOverrides;
  };

in pkgs.python3Packages.buildPythonPackage rec {
  pname = "sygnal";
  version = "v0.17.0";

  # No tests
  doCheck = false;

  src = pkgs.fetchFromGitHub {
    owner = "element-hq";
    repo = pname;
    rev = version;
    sha256 = "sha256-3edws4rGMBRy5fMbV1pjz3e7WaSvaTcn2RkJbGTz3P4=";
  };

  # build-system = python.withPackages
  #   (python-pkgs: with python-pkgs; [ setuptools setuptools-scm ]);

  propagatedBuildInputs = [
    (python.withPackages (python-pkgs:
      with python-pkgs; [
        twisted
        aioapns
        aiohttp
        attrs
        google-auth
        # jaeger-client
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

  # nativeBuildInputs = python.withPackages
  #   (python-pkgs: with python-pkgs; [ poetry-core flit-core ]);

  pyproject = true;

  meta = {
    mainProgram = "sygnal";
    platforms = with lib.platforms; linux ++ darwin;
  };
}
