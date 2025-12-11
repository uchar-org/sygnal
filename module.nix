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

      serviceUnit = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = ''
          The systemd unit (a service or a target) for other services to depend on if they
          need to be started after matrix-synapse.

          This option is useful as the actual parent unit for all matrix-synapse processes
          changes when configuring workers.
        '';
      };

      configFile = mkOption {
        type = types.path;
        readOnly = true;
        description = ''
          Path to the configuration file on the target system. Useful to configure e.g. workers
          that also need this.
        '';
      };

      package = mkOption {
        type = types.package;
        readOnly = true;
        description = ''
          Reference to the `matrix-synapse` wrapper with all extras
          (e.g. for `oidc` or `saml2`) added to the `PYTHONPATH` of all executables.

          This option is useful to reference the "final" `matrix-synapse` package that's
          actually used by `matrix-synapse.service`. For instance, when using
          workers, it's possible to run
          `''${config.services.matrix-synapse.package}/bin/synapse_worker` and
          no additional PYTHONPATH needs to be specified for extras or plugins configured
          via `services.matrix-synapse`.

          However, this means that this option is supposed to be only declared
          by the `services.matrix-synapse` module itself and is thus read-only.
          In order to modify `matrix-synapse` itself, use an overlay to override
          `pkgs.matrix-synapse-unwrapped`.
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

      log = mkOption {
        type = types.attrsOf format.type;
        defaultText = literalExpression defaultCommonLogConfigText;
        description = ''
          Default configuration for the loggers used by `matrix-synapse` and its workers.
          The defaults are added with the default priority which means that
          these will be merged with additional declarations. These additional
          declarations also take precedence over the defaults when declared
          with at least normal priority. For instance
          the log-level for synapse and its workers can be changed like this:

          ```nix
          { lib, ... }: {
            services.matrix-synapse.log.root.level = "WARNING";
          }
          ```

          And another field can be added like this:

          ```nix
          {
            services.matrix-synapse.log = {
              loggers."synapse.http.matrixfederationclient".level = "DEBUG";
            };
          }
          ```

          Additionally, the field `handlers.journal.SYSLOG_IDENTIFIER` will be added to
          each log config, i.e.
          * `synapse` for `matrix-synapse.service`
          * `synapse-<worker name>` for `matrix-synapse-worker-<worker name>.service`

          This is only done if this option has a `handlers.journal` field declared.

          To discard all settings declared by this option for each worker and synapse,
          `lib.mkForce` can be used.

          To discard all settings declared by this option for a single worker or synapse only,
          [](#opt-services.matrix-synapse.workers._name_.worker_log_config) or
          [](#opt-services.matrix-synapse.settings.log_config) can be used.
        '';
      };

      settings = mkOption {
        default = {};
        description = ''
          The primary synapse configuration. See the
          [sample configuration](https://github.com/element-hq/synapse/blob/v${pkgs.matrix-synapse-unwrapped.version}/docs/sample_config.yaml)
          for possible values.

          Secrets should be passed in by using the `extraConfigFiles` option.
        '';
        type = with types;
          submodule {
            freeformType = format.type;
            options = {
              # This is a reduced set of popular options and defaults
              # Do not add every available option here, they can be specified
              # by the user at their own discretion. This is a freeform type!

              server_name = mkOption {
                type = types.str;
                example = "example.com";
                default = config.networking.hostName;
                defaultText = literalExpression "config.networking.hostName";
                description = ''
                  The domain name of the server, with optional explicit port.
                  This is used by remote servers to look up the server address.
                  This is also the last part of your UserID.

                  The server_name cannot be changed later so it is important to configure this correctly before you start Synapse.
                '';
              };

              enable_registration = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Enable registration for new users.
                '';
              };

              registration_shared_secret = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  If set, allows registration by anyone who also has the shared
                  secret, even if registration is otherwise disabled.

                  Secrets should be passed in via `extraConfigFiles`!
                '';
              };

              macaroon_secret_key = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  Secret key for authentication tokens. If none is specified,
                  the registration_shared_secret is used, if one is given; otherwise,
                  a secret key is derived from the signing key.

                  Secrets should be passed in via `extraConfigFiles`!
                '';
              };

              enable_metrics = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Enable collection and rendering of performance metrics
                '';
              };

              report_stats = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Whether or not to report anonymized homeserver usage statistics.
                '';
              };

              signing_key_path = mkOption {
                type = types.path;
                default = "${cfg.dataDir}/homeserver.signing.key";
                description = ''
                  Path to the signing key to sign messages with.
                '';
              };

              pid_file = mkOption {
                type = types.path;
                default = "/run/matrix-synapse.pid";
                readOnly = true;
                description = ''
                  The file to store the PID in.
                '';
              };

              log_config = mkOption {
                type = types.path;
                default = genLogConfigFile "synapse";
                defaultText = logConfigText "synapse";
                description = ''
                  The file that holds the logging configuration.
                '';
              };

              media_store_path = mkOption {
                type = types.path;
                default =
                  if lib.versionAtLeast config.system.stateVersion "22.05"
                  then "${cfg.dataDir}/media_store"
                  else "${cfg.dataDir}/media";
                defaultText = "${cfg.dataDir}/media_store for when system.stateVersion is at least 22.05, ${cfg.dataDir}/media when lower than 22.05";
                description = ''
                  Directory where uploaded images and attachments are stored.
                '';
              };

              public_baseurl = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "https://example.com:8448/";
                description = ''
                  The public-facing base URL for the client API (not including _matrix/...)
                '';
              };

              tls_certificate_path = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "/var/lib/acme/example.com/fullchain.pem";
                description = ''
                  PEM encoded X509 certificate for TLS.
                  You can replace the self-signed certificate that synapse
                  autogenerates on launch with your own SSL certificate + key pair
                  if you like.  Any required intermediary certificates can be
                  appended after the primary certificate in hierarchical order.
                '';
              };

              tls_private_key_path = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "/var/lib/acme/example.com/key.pem";
                description = ''
                  PEM encoded private key for TLS. Specify null if synapse is not
                  speaking TLS directly.
                '';
              };

              presence.enabled = mkOption {
                type = types.bool;
                default = true;
                example = false;
                description = ''
                  Whether to enable presence tracking.

                  Presence tracking allows users to see the state (e.g online/offline)
                  of other local and remote users.
                '';
              };

              listeners = mkOption {
                type = types.listOf (listenerType false);
                default =
                  [
                    {
                      port = 8008;
                      bind_addresses = ["127.0.0.1"];
                      type = "http";
                      tls = false;
                      x_forwarded = true;
                      resources = [
                        {
                          names = ["client"];
                          compress = true;
                        }
                        {
                          names = ["federation"];
                          compress = false;
                        }
                      ];
                    }
                  ]
                  ++ lib.optional hasWorkers {
                    path = "/run/matrix-synapse/main_replication.sock";
                    type = "http";
                    resources = [
                      {
                        names = ["replication"];
                        compress = false;
                      }
                    ];
                  };
                description = ''
                  List of ports that Synapse should listen on, their purpose and their configuration.

                  By default, synapse will be configured for client and federation traffic on port 8008, and
                  use a UNIX domain socket for worker replication. See [`services.matrix-synapse.workers`](#opt-services.matrix-synapse.workers)
                  for more details.
                '';
              };

              database.name = mkOption {
                type = types.enum [
                  "sqlite3"
                  "psycopg2"
                ];
                default =
                  if versionAtLeast config.system.stateVersion "18.03"
                  then "psycopg2"
                  else "sqlite3";
                defaultText = literalExpression ''
                  if versionAtLeast config.system.stateVersion "18.03"
                  then "psycopg2"
                  else "sqlite3"
                '';
                description = ''
                  The database engine name. Can be sqlite3 or psycopg2.
                '';
              };

              database.args.database = mkOption {
                type = types.str;
                default =
                  {
                    sqlite3 = "${cfg.dataDir}/homeserver.db";
                    psycopg2 = "matrix-synapse";
                  }
                  .${cfg.settings.database.name};
                defaultText = literalExpression ''
                  {
                    sqlite3 = "''${${options.services.matrix-synapse.dataDir}}/homeserver.db";
                    psycopg2 = "matrix-synapse";
                  }.''${${options.services.matrix-synapse.settings}.database.name};
                '';
                description = ''
                  Name of the database when using the psycopg2 backend,
                  path to the database location when using sqlite3.
                '';
              };

              database.args.user = mkOption {
                type = types.nullOr types.str;
                default =
                  {
                    sqlite3 = null;
                    psycopg2 = "matrix-synapse";
                  }
                  .${cfg.settings.database.name};
                defaultText = lib.literalExpression ''
                  {
                    sqlite3 = null;
                    psycopg2 = "matrix-synapse";
                  }.''${cfg.settings.database.name};
                '';
                description = ''
                  Username to connect with psycopg2, set to null
                  when using sqlite3.
                '';
              };

              url_preview_enabled = mkOption {
                type = types.bool;
                default = true;
                example = false;
                description = ''
                  Is the preview URL API enabled?  If enabled, you *must* specify an
                  explicit url_preview_ip_range_blacklist of IPs that the spider is
                  denied from accessing.
                '';
              };

              url_preview_ip_range_blacklist = mkOption {
                type = types.listOf types.str;
                default = [
                  "10.0.0.0/8"
                  "100.64.0.0/10"
                  "127.0.0.0/8"
                  "169.254.0.0/16"
                  "172.16.0.0/12"
                  "192.0.0.0/24"
                  "192.0.2.0/24"
                  "192.168.0.0/16"
                  "192.88.99.0/24"
                  "198.18.0.0/15"
                  "198.51.100.0/24"
                  "2001:db8::/32"
                  "203.0.113.0/24"
                  "224.0.0.0/4"
                  "::1/128"
                  "fc00::/7"
                  "fe80::/10"
                  "fec0::/10"
                  "ff00::/8"
                ];
                description = ''
                  List of IP address CIDR ranges that the URL preview spider is denied
                  from accessing.
                '';
              };

              url_preview_ip_range_whitelist = mkOption {
                type = types.listOf types.str;
                default = [];
                description = ''
                  List of IP address CIDR ranges that the URL preview spider is allowed
                  to access even if they are specified in url_preview_ip_range_blacklist.
                '';
              };

              url_preview_url_blacklist = mkOption {
                # FIXME revert to just `listOf (attrsOf str)` after some time(tm).
                type = types.listOf (
                  types.coercedTo types.str (const (throw ''
                    Setting `config.services.matrix-synapse.settings.url_preview_url_blacklist`
                    to a list of strings has never worked. Due to a bug, this was the type accepted
                    by the module, but in practice it broke on runtime and as a result, no URL
                    preview worked anywhere if this was set.

                    See https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html#url_preview_url_blacklist
                    on how to configure it properly.
                  '')) (types.attrsOf types.str)
                );
                default = [];
                example = literalExpression ''
                  [
                    { scheme = "http"; } # no http previews
                    { netloc = "www.acme.com"; path = "/foo"; } # block http(s)://www.acme.com/foo
                  ]
                '';
                description = ''
                  Optional list of URL matches that the URL preview spider is
                  denied from accessing.
                '';
              };

              max_upload_size = mkOption {
                type = types.str;
                default = "50M";
                example = "100M";
                description = ''
                  The largest allowed upload size in bytes
                '';
              };

              max_image_pixels = mkOption {
                type = types.str;
                default = "32M";
                example = "64M";
                description = ''
                  Maximum number of pixels that will be thumbnailed
                '';
              };

              dynamic_thumbnails = mkOption {
                type = types.bool;
                default = false;
                example = true;
                description = ''
                  Whether to generate new thumbnails on the fly to precisely match
                  the resolution requested by the client. If true then whenever
                  a new resolution is requested by the client the server will
                  generate a new thumbnail. If false the server will pick a thumbnail
                  from a precalculated list.
                '';
              };

              turn_uris = mkOption {
                type = types.listOf types.str;
                default = [];
                example = [
                  "turn:turn.example.com:3487?transport=udp"
                  "turn:turn.example.com:3487?transport=tcp"
                  "turns:turn.example.com:5349?transport=udp"
                  "turns:turn.example.com:5349?transport=tcp"
                ];
                description = ''
                  The public URIs of the TURN server to give to clients
                '';
              };
              turn_shared_secret = mkOption {
                type = types.str;
                default = "";
                example = literalExpression ''
                  config.services.coturn.static-auth-secret
                '';
                description = ''
                  The shared secret used to compute passwords for the TURN server.

                  Secrets should be passed in via `extraConfigFiles`!
                '';
              };

              trusted_key_servers = mkOption {
                type = types.listOf (
                  types.submodule {
                    freeformType = format.type;
                    options = {
                      server_name = mkOption {
                        type = types.str;
                        example = "matrix.org";
                        description = ''
                          Hostname of the trusted server.
                        '';
                      };
                    };
                  }
                );
                default = [
                  {
                    server_name = "matrix.org";
                    verify_keys = {
                      "ed25519:auto" = "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw";
                    };
                  }
                ];
                description = ''
                  The trusted servers to download signing keys from.
                '';
              };

              app_service_config_files = mkOption {
                type = types.listOf types.path;
                default = [];
                description = ''
                  A list of application service config file to use
                '';
              };

              redis = lib.mkOption {
                type = types.submodule {
                  freeformType = format.type;
                  options = {
                    enabled = lib.mkOption {
                      type = types.bool;
                      default = false;
                      description = ''
                        Whether to use redis support
                      '';
                    };
                  };
                };
                default = {};
                description = ''
                  Redis configuration for synapse.

                  See the
                  [upstream documentation](https://github.com/element-hq/synapse/blob/v${pkgs.matrix-synapse-unwrapped.version}/docs/usage/configuration/config_documentation.md#redis)
                  for available options.
                '';
              };
            };
          };
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["--no-secrets-in-config"];
        description = ''
          Extra command lines argument that are passed to synapse and workers.
        '';
      };

      extraConfigFiles = mkOption {
        type = types.listOf types.path;
        default = [];
        description = ''
          Extra config files to include.

          The configuration files will be included based on the command line
          argument --config-path. This allows to configure secrets without
          having to go through the Nix store, e.g. based on deployment keys if
          NixOps is in use.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.matrix-synapse.settings.redis = lib.mkIf cfg.configureRedisLocally {
      enabled = true;
      path = config.services.redis.servers.matrix-synapse.unixSocket;
    };
    services.matrix-synapse.settings.instance_map.main = lib.mkIf hasWorkers (
      lib.mkDefault {
        path = "/run/matrix-synapse/main_replication.sock";
      }
    );

    services.matrix-synapse.serviceUnit =
      if hasWorkers
      then "matrix-synapse.target"
      else "matrix-synapse.service";
    services.matrix-synapse.configFile = configFile;
    services.matrix-synapse.package = wrapped;

    # default them, so they are additive
    services.matrix-synapse.extras = defaultExtras;

    services.matrix-synapse.log = mapAttrsRecursive (const mkDefault) defaultCommonLogConfig;

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

    systemd.targets.matrix-synapse = lib.mkIf hasWorkers {
      description = "Synapse Matrix parent target";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];
    };

    systemd.services = let
      targetConfig =
        if hasWorkers
        then {
          partOf = ["matrix-synapse.target"];
          wantedBy = ["matrix-synapse.target"];
          unitConfig.ReloadPropagatedFrom = "matrix-synapse.target";
          requires = optional hasLocalPostgresDB "postgresql.target";
        }
        else {
          wants = ["network-online.target"];
          after = ["network-online.target"] ++ optional hasLocalPostgresDB "postgresql.target";
          requires = optional hasLocalPostgresDB "postgresql.target";
          wantedBy = ["multi-user.target"];
        };
      baseServiceConfig =
        {
          environment = optionalAttrs (cfg.withJemalloc) {
            LD_PRELOAD = "${pkgs.jemalloc}/lib/libjemalloc.so";
            PYTHONMALLOC = "malloc";
          };
          serviceConfig = {
            Type = "notify";
            User = "matrix-synapse";
            Group = "matrix-synapse";
            WorkingDirectory = cfg.dataDir;
            RuntimeDirectory = "matrix-synapse";
            RuntimeDirectoryPreserve = true;
            ExecReload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
            Restart = "on-failure";
            UMask = "0077";

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
            ReadWritePaths =
              [
                cfg.dataDir
                cfg.settings.media_store_path
              ]
              ++ (map (listener: dirOf listener.path) (
                filter (listener: listener.path != null) cfg.settings.listeners
              ));
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
        }
        // targetConfig;
      genWorkerService = name: workerCfg: let
        finalWorkerCfg =
          workerCfg
          // {
            worker_name = name;
          };
        workerConfigFile = format.generate "worker-${name}.yaml" finalWorkerCfg;
      in {
        name = "matrix-synapse-worker-${name}";
        value = lib.mkMerge [
          baseServiceConfig
          {
            description = "Synapse Matrix worker ${name}";
            # make sure the main process starts first for potential database migrations
            after = ["matrix-synapse.service"];
            requires = ["matrix-synapse.service"];
            serviceConfig = {
              ExecStart = ''
                ${cfg.package}/bin/synapse_worker \
                  ${concatMapStringsSep "\n  " (x: "--config-path ${x} \\") (
                  [
                    configFile
                    workerConfigFile
                  ]
                  ++ cfg.extraConfigFiles
                )}
                  --keys-directory ${cfg.dataDir} \
                  ${utils.escapeSystemdExecArgs cfg.extraArgs}
              '';
            };
          }
        ];
      };
    in
      {
        matrix-synapse = lib.mkMerge [
          baseServiceConfig
          {
            description = "Synapse Matrix homeserver";
            preStart = ''
              ${cfg.package}/bin/synapse_homeserver \
                --config-path ${configFile} \
                --keys-directory ${cfg.dataDir} \
                --generate-keys
            '';
            serviceConfig = {
              ExecStartPre = [
                (
                  "+"
                  + (pkgs.writeShellScript "matrix-synapse-fix-permissions" ''
                    chown matrix-synapse:matrix-synapse ${cfg.settings.signing_key_path}
                    chmod 0600 ${cfg.settings.signing_key_path}
                  '')
                )
              ];
              ExecStart = ''
                ${cfg.package}/bin/synapse_homeserver \
                  ${concatMapStringsSep "\n  " (x: "--config-path ${x} \\") (
                  [configFile] ++ cfg.extraConfigFiles
                )}
                  --keys-directory ${cfg.dataDir} \
                  ${utils.escapeSystemdExecArgs cfg.extraArgs}
              '';
            };
          }
        ];
      }
      // (lib.mapAttrs' genWorkerService cfg.workers);
  };

  meta = {
    # doc = ./synapse.md;
    buildDocsInSandbox = false;
    maintainers = with maintainers; [orzklv];
  };
}
