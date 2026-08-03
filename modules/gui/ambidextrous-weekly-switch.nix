{ lib, pkgs, homelab, ... }:

let
  script = pkgs.writeShellScriptBin "ambidextrous-weekly-switch" ''
        set -euo pipefail

        export PATH="${pkgs.glib}/bin:${pkgs.dconf}/bin:${pkgs.libnotify}/bin:${pkgs.coreutils}/bin:$PATH"

        if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
          echo "ambidextrous-weekly-switch: no DBUS_SESSION_BUS_ADDRESS; skipping" >&2
          exit 0
        fi

        # Do not use `date +%V`: ISO weeks run 01-53, and a 53-week year produces week 53 followed by week 01,
        # which are both odd and would repeat the handedness for an extra week every ~5-6 years. Epoch-week
        # arithmetic has no such discontinuity; the cycle is exactly 14 days forever.
        # `+ 3` is required because epoch day 0 (1970-01-01) was a Thursday, so raw `days / 7` would flip on
        # Thursdays. Adding 3 shifts the boundary to Monday: the first Monday is day 4 and `(4 + 3) / 7 = 1`.
        # The epoch's leading Thu-Sun forms a partial "week 0"; that is expected, not a bug.
        # Use UTC, not local time: `date +%s` is timezone-independent, so the boundary lands at Monday 00:00 UTC
        # (01:00 or 02:00 local in Europe/Amsterdam depending on DST). Computing a true local-midnight boundary
        # instead would require explicit timezone-aware date arithmetic (re-deriving the epoch second for the
        # local calendar date interpreted in the LOCAL zone, not UTC), which is materially harder to read and
        # easier to get wrong for a benefit that does not matter here (see below).
        # The UTC offset is harmless because this service also runs at every graphical login and the timer is
        # `Persistent = true`: even though the timer itself fires at Monday 00:00 UTC (not local midnight), any
        # missed or off-hours firing is caught up at the next session start regardless, so the user always
        # observes the change within the login that follows the boundary, not at some arbitrary later time.
        days=$(( $(date +%s) / 86400 ))
        parity=$(( ( days + 3 ) / 7 % 2 ))

        # To invert the logic just change the 1 to 0
        if [ "$parity" = "1" ]; then
          desired=true
          primaryButton="left"
        else
          desired=false
          primaryButton="right"
        fi

        current=$(gsettings get org.gnome.desktop.peripherals.mouse left-handed)

        if [ "$current" = "$desired" ]; then
          exit 0
        fi

        gsettings set org.gnome.desktop.peripherals.mouse left-handed "$desired"

    ${lib.optionalString homelab.ambidextrousWeeklySwitch.notify ''
        notify-send "Primary mouse button: ''${primaryButton}"
    ''}
  '';
in
{
  config = lib.mkIf homelab.ambidextrousWeeklySwitch.enable {
    home.packages = [ script ];

    systemd.user.services.ambidextrous-weekly-switch = {
      Unit = {
        Description = "Synchronize GNOME primary mouse handedness weekly and at login";
        After = [ "graphical-session.target" ];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${script}/bin/ambidextrous-weekly-switch";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.timers.ambidextrous-weekly-switch = {
      Unit = {
        Description = "Run GNOME primary mouse handedness sync every Monday at 00:00 UTC";
      };

      Timer = {
        OnCalendar = "Mon *-*-* 00:00:00 UTC";
        Persistent = true;
      };

      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
