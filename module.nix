flake: {
  config,
  lib,
  options,
  pkgs,
  utils,
  ...
}:
with lib; let
  cfg = config.services.matrix-sygnal;
  format = pkgs.formats.yaml {};
in {
  options = {
    services.matrix-sygnal = {
      enable = mkEnableOption "matrix.org sygnal, the reference push notifier";

      configFile = mkOption {
        type = types.path;
        description = ''
          Path to the configuration file on the target system.
        '';
      };

      package = mkOption {
        type = types.package;
        readOnly = true;
        description = ''
          Reference to the `matrix-sygnal`.
        '';
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/matrix-sygnal";
        description = ''
          The directory where matrix-sygnal stores its stateful data or such
          as configurations .
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.matrix-sygnal.package = flake.packages.${pkgs.stdenv.hostPlatform.system}.default;

    users.users.matrix-sygnal = {
      group = "matrix-sygnal";
      home = cfg.dataDir;
      createHome = true;
      shell = "${pkgs.bash}/bin/bash";
      uid = config.ids.uids.matrix-sygnal;
    };

    users.groups.matrix-sygnal = {
      gid = config.ids.gids.matrix-sygnal;
    };

    systemd.services.matrix-sygnal = {
      description = "Matrix Sygnal for push notifications";
      documentation = [
        "https://github.com/efael/sygnal"
        "https://github.com/element-hq/sygnal"
      ];

      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "notify";
        User = "matrix-sygnal";
        Group = "matrix-sygnal";
        WorkingDirectory = cfg.dataDir;
        RuntimeDirectory = "matrix-sygnal";
        RuntimeDirectoryPreserve = true;
        ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
        Restart = "on-failure";
        UMask = "0077";

        ExecStart = ''
          ${cfg.package}/bin/sygnal ${configFile}
        '';

        # Security Hardening
        # Refer to systemd.exec(5) for option descriptions.
        CapabilityBoundingSet = [""];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        ReadWritePaths = [cfg.dataDir];
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@resources"
          "~@privileged"
        ];
      };
    };
  };

  meta = {
    doc = ./readme.md;
    buildDocsInSandbox = false;
    maintainers = with maintainers; [orzklv];
  };
}
