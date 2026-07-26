{ config, hermes-agent, lib, pkgs, ... }:
let
  service = "hermes";
  cfg = config.homelab.services.${service};
  inherit (config) homelab;
  matrixUserId = "@${cfg.matrix.botLocalpart}:${cfg.matrix.serverName}";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
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
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Environment file containing Matrix and provider secrets";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Generic Hermes Agent settings passed to the upstream module";
    };

    matrix = {
      homeserver = lib.mkOption {
        type = lib.types.str;
        default = "https://chat.tapirus.cc";
        description = "Matrix homeserver URL";
      };

      serverName = lib.mkOption {
        type = lib.types.str;
        default = "chat.tapirus.cc";
        description = "Matrix server name used to derive user IDs";
      };

      botLocalpart = lib.mkOption {
        type = lib.types.str;
        default = "hermes";
        description = "Matrix localpart for the Hermes bot account";
      };

      allowedUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "@${homelab.mainUser.name}:${cfg.matrix.serverName}" ];
        description = "Matrix user IDs allowed to interact with Hermes";
      };

      deviceId = lib.mkOption {
        type = lib.types.str;
        default = "hermes-${config.networking.hostName}";
        description = "Stable host-specific Matrix device ID";
      };

      requireMention = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Require a Matrix mention before Hermes responds in rooms";
      };

      e2eeMode = lib.mkOption {
        type = lib.types.enum [ "off" "optional" "required" ];
        default = "required";
        description = "Matrix end-to-end encryption policy";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "https://" cfg.matrix.homeserver;
        message = "homelab.services.hermes.matrix.homeserver must use HTTPS";
      }
      {
        assertion = cfg.matrix.botLocalpart != "";
        message = "homelab.services.hermes.matrix.botLocalpart must not be empty";
      }
      {
        assertion = cfg.matrix.serverName != "";
        message = "homelab.services.hermes.matrix.serverName must not be empty";
      }
      {
        assertion = cfg.matrix.allowedUsers != [ ] && lib.all (user: user != "") cfg.matrix.allowedUsers;
        message = "homelab.services.hermes.matrix.allowedUsers must contain at least one non-empty Matrix user ID";
      }
      {
        assertion = cfg.environmentFile != null;
        message = "homelab.services.hermes.environmentFile must be set when Hermes is enabled";
      }
      {
        assertion = cfg.matrix.e2eeMode != "required" || cfg.matrix.deviceId != "";
        message = "homelab.services.hermes.matrix.deviceId must be a stable non-empty value when E2EE is required";
      }
    ];

    services.hermes-agent = {
      enable = true;
      inherit (cfg) package settings stateDir;
      environmentFiles = lib.optionals (cfg.environmentFile != null) [ cfg.environmentFile ];
      environment = {
        MATRIX_ENCRYPTION = "true";
        MATRIX_E2EE_MODE = cfg.matrix.e2eeMode;
        MATRIX_HOMESERVER = cfg.matrix.homeserver;
        MATRIX_USER_ID = matrixUserId;
        MATRIX_DEVICE_ID = cfg.matrix.deviceId;
        MATRIX_ALLOWED_USERS = lib.concatStringsSep "," cfg.matrix.allowedUsers;
        MATRIX_REQUIRE_MENTION = lib.boolToString cfg.matrix.requireMention;
      };
    };
  };
}
