{
  pkgs ? let
    lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
    nixpkgs = fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
      sha256 = lock.narHash;
    };
  in
    import nixpkgs {
      overlays = [
        ./overlay.nix
      ];
    },
  ...
}:
pkgs.python3Packages.buildPythonApplication rec {
  pname = "sygnal";
  version = "v0.17.0";
  pyproject = true;

  doCheck = false;
  dontCheck = true;
  doInstallCheck = false;

  src = pkgs.fetchFromGitHub {
    owner = "element-hq";
    repo = pname;
    rev = version;
    sha256 = "sha256-3edws4rGMBRy5fMbV1pjz3e7WaSvaTcn2RkJbGTz3P4=";
  };

  build-system = with pkgs.python3Packages; [
    poetry-core
  ];

  propagatedBuildInputs = with pkgs.python3Packages; [
    aioapns
    aiohttp
    attrs
    cryptography
    idna
    google-auth
    matrix-common
    prometheus-client
    py-vapid
    pyopenssl
    pywebpush
    pyyaml
    sentry-sdk
    service-identity
    twisted
    zope-interface

    # Self service
    pkgs.jaeger-client
    pkgs.opentracing
  ];
}
