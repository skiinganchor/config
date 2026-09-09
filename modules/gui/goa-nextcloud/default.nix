{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkOption types;
  cfg = config.services.goa-nextcloud;
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  accountsManifest = pkgs.writeText "goa-nextcloud-accounts.json" (builtins.toJSON (
    map
      (account: {
        inherit (account) serverAddress username;
        secretPath = config.sops.secrets.${account.sopsSecretName}.path;
      })
      cfg.accounts
  ));
  provisioner = pkgs.writeShellScriptBin "goa-nextcloud-provision" ''
    exec ${python}/bin/python ${./provision.py}
  '';
in
{
  options.services.goa-nextcloud.accounts = mkOption {
    type = types.listOf (types.submodule {
      options = {
        serverAddress = mkOption { type = types.str; };
        username = mkOption { type = types.str; };
        sopsSecretName = mkOption { type = types.str; };
        sopsFile = mkOption {
          type = types.path;
        };
      };
    });
    default = [ ];
    description = "Nextcloud accounts to provision through GNOME Online Accounts.";
  };

  config = mkIf (cfg.accounts != [ ]) {
    assertions = [
      {
        assertion = lib.all (account: lib.hasPrefix "https://" account.serverAddress) cfg.accounts;
        message = "services.goa-nextcloud accounts must use an HTTPS serverAddress";
      }
      {
        assertion = lib.length (lib.unique (map (account: builtins.toJSON [ account.serverAddress account.username ]) cfg.accounts)) == lib.length cfg.accounts;
        message = "services.goa-nextcloud accounts must not repeat a serverAddress and username pair";
      }
      {
        assertion = lib.length (lib.unique (map (account: account.sopsSecretName) cfg.accounts)) == lib.length cfg.accounts;
        message = "services.goa-nextcloud accounts must not reuse a sopsSecretName";
      }
    ];

    sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    sops.secrets = lib.listToAttrs (map
      (account:
        lib.nameValuePair account.sopsSecretName
          {
            mode = "0400";
            inherit (account) sopsFile;
          }
      )
      cfg.accounts);

    systemd.user.services.goa-nextcloud-provision = {
      Unit = {
        Description = "Provision Nextcloud GNOME Online Accounts";
        Requires = [ "sops-nix.service" ];
        After = [
          "sops-nix.service"
          "graphical-session-pre.target"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        Environment = [ "GOA_ACCOUNTS_FILE=${accountsManifest}" ];
        ExecStart = "${provisioner}/bin/goa-nextcloud-provision";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
