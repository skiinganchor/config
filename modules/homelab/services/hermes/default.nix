{ config, hermes-agent, lib, pkgs, ... }:
let
  service = "hermes";
  cfg = config.homelab.services.${service};
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
      type = lib.types.path;
      description = "Environment file containing Matrix and provider secrets";
      example = lib.literalExpression ''
        pkgs.writeText "hermes-env" '''
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
    ];

    services.hermes-agent = {
      enable = true;
      environmentFiles = [ cfg.environmentFile ];
    };
  };
}
