{ lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
  userType = with types; submodule {
    options = {
      name = mkOption {
        type = str;
        description = "Username for the user.";
      };
      group = mkOption {
        type = str;
        description = "Primary group for the user.";
      };
      uid = mkOption {
        type = nullOr int;
        default = null;
        description = ''
          Optional stable numeric uid. Leave null to let NixOS allocate one;
          set it explicitly when the id must be aligned across hosts
          (e.g. NFS shares).
        '';
      };
      hasSudo = mkOption {
        type = bool;
        default = false;
        description = "Whether the user belongs to the wheel group (sudo access).";
      };
      gitUserName = mkOption {
        type = nullOr str;
        default = null;
        description = "Git user.name override. Falls back to homelab.git.userName when null.";
      };
      gitEmail = mkOption {
        type = nullOr str;
        default = null;
        description = "Git user.email override. Falls back to homelab.git.email when null.";
      };
      passwordSecretName = mkOption {
        type = nullOr str;
        default = null;
        example = "users/alice/password";
        description = ''
          sops secret key whose decrypted value is a hashed password
          (output of mkpasswd -m yescrypt). When set, the secret is declared
          with neededForUsers = true and linked to the user's hashedPasswordFile.
          Leave null to leave the account locked (e.g. SSH-key-only users).
        '';
      };
      pkgs = mkOption {
        type = listOf package;
        default = [ ];
        description = "Packages available to the user.";
      };
    };
  };
in
{
  options.homelab = {
    enable = lib.mkEnableOption "The homelab services and configuration variables";

    ambidextrousWeeklySwitch = mkOption {
      type = with types; submodule {
        options = {
          enable = mkOption {
            type = bool;
            default = false;
            description = ''
              Whether to enable weekly primary mouse button switching. Disabling
              stops future switches but leaves the current primary-button setting
              untouched; reset it manually with `gsettings set org.gnome.desktop.peripherals.mouse left-handed false`.
            '';
          };

          notify = mkOption {
            type = bool;
            default = true;
            description = "Whether to show a desktop notification when the primary mouse button actually changes.";
          };
        };
      };
      default = { };
      example = {
        enable = true;
        notify = true;
      };
      description = ''
        Opt-in weekly GNOME primary mouse button switching on a deterministic
        Monday boundary.
      '';
    };

    baseDomain = lib.mkOption {
      default = "";
      type = lib.types.str;
      description = ''
        Base domain name to be used to access the homelab services via reverse proxy
      '';
    };

    dconf = mkOption {
      type = with types; submodule {
        options = {
          favoriteApps = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = "List of favorite applications shown in GNOME Dash.";
            example = [ "brave-browser.desktop" "org.gnome.Nautilus.desktop" "org.gnome.Terminal.desktop" ];
          };
          gnomeExtensions = mkOption {
            type = listOf package;
            default = [ ];
            description = "List of Gnome extensions. Requires Gnome session restart to take effect!";
          };
          hotCorners = mkOption {
            type = bool;
            default = false;
            description = "Whether to enable hot corners on Gnome.";
          };
          keyboardLayout = mkOption {
            type = with types; listOf (submodule {
              options = {
                layout = mkOption {
                  type = str;
                  description = "Keyboard layout, e.g. 'us'";
                  example = "us";
                };

                variant = mkOption {
                  type = nullOr str;
                  default = null;
                  description = "Optional keyboard variant, e.g. 'intl'";
                  example = "intl";
                };
              };
            });
            default = [ ];
            description = "List of keyboard layout and optional variant tuples.";
            example = [
              { layout = "us"; variant = "intl"; }
              { layout = "de"; variant = null; }
            ];
          };
          lockScreenNotifications = mkOption {
            type = bool;
            default = false;
            description = "Whether to enable notifications in lock screen Gnome.";
          };
          nightLight = mkOption {
            type = bool;
            default = false;
            description = "Whether to enable night light on Gnome.";
          };
          suspend = mkOption {
            type = bool;
            default = true;
            description = "Whether to suspend is enabled on Gnome.";
          };
        };
      };
      default = { };
      example = {
        favoriteApps = [ "brave-browser.desktop" "org.gnome.Nautilus.desktop" "org.gnome.Terminal.desktop" ];
        gnomeExtensions = with pkgs.gnomeExtensions; [
          appindicator
        ];
        hotCorners = false;
        keyboardLayout = [
          { layout = "us"; variant = "intl"; }
          { layout = "de"; variant = null; }
        ];
        lockScreenNotifications = false;
        nightLight = true;
        suspend = true;
      };
      description = "DConf configuration for Gnome.";
    };

    git = mkOption {
      type = with types; submodule {
        options = {
          userName = mkOption {
            type = str;
            default = "Rick Sanchez";
            description = "Git global username.";
          };

          email = mkOption {
            type = str;
            default = "Rick.Sanchez@Wabalaba.dubdub";
            description = "Git global email.";
          };

          defaultBranch = mkOption {
            type = str;
            default = "main";
            description = "Default Git branch name (e.g. main or master).";
          };

          createWorkspaces = mkOption {
            type = bool;
            default = false;
            description = "Whether to enable per-workspace Git configs.";
          };

          workspaces = mkOption {
            type = listOf (submodule {
              options = {
                folderName = mkOption {
                  type = str;
                  description = "Relative folder path for the Git workspace.";
                };
                email = mkOption {
                  type = str;
                  description = "Git email to use in this workspace.";
                };
                userName = mkOption {
                  type = str;
                  description = "Git username to use in this workspace.";
                };
                sshKeyFile = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Absolute path to the SSH private key to use for this workspace.";
                };
              };
            });
            default = [ ];
            description = "List of Git workspace configurations.";
          };
        };
      };
      default = { };
      example = {
        userName = "Rick Sanchez";
        email = "Rick.Sanchez@Wabalaba.dubdub";
        defaultBranch = "main";
        createWorkspaces = true;
        workspaces = [
          {
            folderName = "workspace_personal";
            email = "personal@example.com";
            userName = "Rick Personal";
          }
          {
            folderName = "workspace_work";
            email = "rick@rick.com";
            userName = "Rick Professional";
          }
        ];
      };
      description = "Git configuration including user info and optional workspace-specific overrides.";
    };

    mainUser = mkOption {
      type = userType;
      default = {
        name = "rick";
        group = "rick";
        uid = 1001; # stable for NFS share alignment
        hasSudo = true;
        pkgs = with pkgs; [
          git
          pay-respects
          tmux
          vscodium
          wl-clipboard
        ];
      };
      description = "The main user of the system.";
    };

    extraUsers = mkOption {
      type = types.listOf userType;
      default = [ ];
      description = ''
        Additional users sharing the same shape as mainUser. Each gets a
        NixOS user account and a home-manager profile that inherits all
        home-manager.sharedModules.
      '';
      example = [
        {
          name = "alice";
          group = "alice";
          pkgs = [ ];
        }
      ];
    };

    opencode.useOpencodeGo = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use opencode-go models for oh-my-openagent.";
    };

    shell = mkOption {
      type = types.nullOr (types.either types.shellPackage (types.passwdEntry types.path));
      default = pkgs.shadow;
    };

    systemWidePkgs = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        openssl
      ];
      description = "The system packages";
    };

    timeZone = mkOption {
      type = types.str;
      default = "UTC";
      description = "The system time zone";
    };
  };

  config = { };

  imports = [
    ./git.nix
    ./homelab
    ./nfs_client
  ];
}
