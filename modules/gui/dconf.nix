{ lib, homelab, ... }:

let
  flameshotPath = "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot";
in
{
  home.packages = homelab.dconf.gnomeExtensions;
  dconf.settings = lib.mkMerge [
    {
      "org/gnome/shell" = lib.mkMerge [
        # Gnome extensions
        {
          disable-user-extensions = false;
          enabled-extensions = lib.lists.forEach homelab.dconf.gnomeExtensions (e: e.extensionUuid);
        }
        # Favorite apps for Dash
        (lib.mkIf (homelab.dconf.favoriteApps != [ ]) {
          favorite-apps = homelab.dconf.favoriteApps;
        })
      ];
    }
    {
      # Clean built-in screenshot keybindings
      "org/gnome/shell/keybindings" = {
        show-screenshot-ui = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
        screenshot = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
        screenshot-window = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      };
      # Register custom keybinding
      "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [ "/${flameshotPath}/" ];
      # Flameshot - declare custom keybinding
      ${flameshotPath} = {
        name = "Flameshot";
        binding = "Print";
        command = "sh -c 'flameshot gui'";
      };
    }
    # Hot corners
    {
      "org/gnome/desktop/interface".enable-hot-corners = homelab.dconf.hotCorners;
    }
    # Keyboard layout
    {
      "org/gnome/desktop/input-sources".sources =
        map
          (k:
            lib.hm.gvariant.mkTuple [
              "xkb"
              (k.layout + (if k.variant != null then "+" + k.variant else ""))
            ]
          )
          homelab.dconf.keyboardLayout;
    }
    # Show lock-screen notifications
    {
      "org/gnome/desktop/notifications".show-in-lock-screen = homelab.dconf.lockScreenNotifications;
    }
    # Night light
    (lib.mkIf homelab.dconf.nightLight {
      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-temperature = 2700;
        night-light-schedule-automatic = false;
        night-light-schedule-to = 6.0;
        night-light-schedule-from = 16.0;
        night-light-last-coordinates = "(91.0, 181.0)";
        active = true;
        priority = 0;
      };
    })
    # Suspend
    {
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = if homelab.dconf.suspend then "suspend" else "nothing";
        sleep-inactive-battery-type = if homelab.dconf.suspend then "suspend" else "nothing";
      } // lib.optionalAttrs (!homelab.dconf.suspend) {
        sleep-inactive-ac-timeout = lib.hm.gvariant.mkUint32 0;
        sleep-inactive-battery-timeout = lib.hm.gvariant.mkUint32 0;
      };
    }
  ];
}
