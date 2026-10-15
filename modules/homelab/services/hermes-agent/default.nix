{ config, hermes-agent, lib, pkgs, ... }:
let
  service = "hermes-agent";
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption service;

    addToSystemPackages = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Add the hermes CLI to environment.systemPackages and export
        HERMES_HOME system-wide (via environment.variables) so interactive
        shells share state with the gateway service.
      '';
    };

    # none is recommended to keep only configuration as code
    backend = lib.mkOption {
      type = lib.types.submodule {
        options = {
          mode = lib.mkOption {
            type = lib.types.enum [ "none" "serve" "dashboard" ];
            default = "none";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 9119;
          };
        };
      };
      default = { };
      description = "Hermes API and dashboard backend configuration";
    };

    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "hermes-agent" ] ++ lib.optionals (cfg.backend.mode != "none") [ "hermes-backend" ];
      description = "Systemd services to show in the MOTD status list";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Hermes Agent package to run";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes";
      description = "Persistent state directory for Hermes Agent";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file containing Matrix and provider secrets";
      example = lib.literalExpression ''
        pkgs.writeText "hermes-env" '''
          # Model provider configs, eg. OpenAI or OpenCode Go
          OPENCODE_GO_API_KEY=secret-api-key
          # Matrix configs
          MATRIX_E2EE_MODE=required|optional|off
          MATRIX_HOMESERVER=https://matrix.some.domain
          MATRIX_ACCESS_TOKEN=sometoken
          MATRIX_DEVICE_ID=someid
          MATRIX_USER_ID=@hermes:your-server.org
          # Security: restrict who can interact with the bot
          MATRIX_ALLOWED_USERS=@alice:matrix.example.org
          # Optional: restrict which rooms can trigger the bot
          MATRIX_ALLOWED_ROOMS=!abc123:matrix.example.org
          # Optional: by default, Hermes requires an @mention to respond
          MATRIX_REQUIRE_MENTION=false
        '''
      '';
    };

    cronJobsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = lib.literalExpression ''config.sops.secrets."hermes/cron-jobs".path'';
      description = ''
        Absolute runtime path to a JSON list of recurring jobs. Each entry has
        a stable id, name, schedule, deliver (matrix:ROOM_ID), and prompt.
        Use a sops-nix secret to keep all fields out of the Nix store.
        Jobs are reconciled before gateway startup; an empty list removes
        managed jobs while leaving jobs created interactively untouched.
        See docs/hermes-cron-jobs.md for the schema and SOPS configuration.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Generic Hermes Agent settings passed to the upstream module";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.environmentFile != null;
        message = "homelab.services.hermes.environmentFile must be set when Hermes is enabled";
      }
      {
        assertion = cfg.cronJobsFile == null || lib.hasPrefix "/" cfg.cronJobsFile;
        message = "homelab.services.hermes-agent.cronJobsFile must be an absolute runtime path";
      }
      {
        assertion = cfg.cronJobsFile == null || !config.services.hermes-agent.container.enable;
        message = "homelab.services.hermes-agent.cronJobsFile requires native service mode";
      }
    ];

    # See options in: https://github.com/NousResearch/hermes-agent/blob/main/nix/nixosModules.nix
    services.hermes-agent = {
      enable = true;
      inherit (cfg) addToSystemPackages backend package stateDir settings;
      environmentFiles = [ cfg.environmentFile ];
    };

    systemd.services.hermes-agent = lib.mkIf (cfg.cronJobsFile != null) {
      after = [ "sops-install-secrets.service" ];
      serviceConfig.UMask = lib.mkForce "0077";
      preStart = lib.mkAfter ''
        ${config.services.hermes-agent.package.hermesVenv}/bin/python3 \
          ${./reconcile-cron-jobs.py} ${lib.escapeShellArg cfg.cronJobsFile}
      '';
    };
  };
}
