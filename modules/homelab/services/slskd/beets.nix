{ config
, pkgs
, lib
, ...
}:
let
  service = "slskd";
  inherit (config) homelab;
  cfg = homelab.services.${service};
  settingsFormat = pkgs.formats.yaml { };

  # The lyrics plugin stores fetched lyrics in the beets database. Export them
  # beside each audio file so media players can find them without reading beets.
  beets-export-lyrics-py = pkgs.writeText "beets-export-lyrics.py" ''
    import os
    import re
    import sqlite3
    import sys

    library = "${config.homelab.services.slskd.musicDir}/beets.db"
    # A timestamp at the start of a line means the lyrics use the LRC format.
    timestamp = re.compile(r"^\s*\[\d{1,2}:\d{2}(?:[.:]\d{1,3})\]", re.MULTILINE)

    def decode_path(path):
        # Older beets databases can contain paths as SQLite byte strings.
        if isinstance(path, bytes):
            return os.fsdecode(path)
        return path

    try:
        # Read only tracks for which the lyrics plugin stored non-empty text.
        conn = sqlite3.connect(library)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "select path, lyrics from items where lyrics is not null and length(trim(lyrics)) > 0"
        )
    except sqlite3.Error as error:
        print(f"Failed to read beets lyrics from {library}: {error}", file=sys.stderr)
        sys.exit(1)

    written = 0
    skipped = 0
    errors = 0
    for row in rows:
        track_path = decode_path(row["path"])
        if not os.path.isfile(track_path):
            skipped += 1
            continue

        try:
            # Normalize line endings and remove the source footer added by some
            # lyrics providers; the sidecar should contain lyrics only.
            lyrics = row["lyrics"].replace("\r\n", "\n").replace("\r", "\n").strip()
            lyrics = re.split(r"\n\nSource: ", lyrics, maxsplit=1)[0].strip()
            extension = ".lrc" if timestamp.search(lyrics) else ".txt"
            lyrics_path = os.path.splitext(track_path)[0] + extension
            lyrics = lyrics + "\n"

            try:
                with open(lyrics_path, "r", encoding="utf-8") as existing:
                    if existing.read() == lyrics:
                        continue
            except FileNotFoundError:
                pass

            # Replace the sidecar atomically so readers never observe a
            # partially written lyrics file.
            tmp_path = lyrics_path + ".tmp"
            with open(tmp_path, "w", encoding="utf-8") as output:
                output.write(lyrics)
            os.replace(tmp_path, lyrics_path)
            written += 1
        except OSError as error:
            errors += 1
            print(f"Failed to export lyrics for {track_path}: {error}", file=sys.stderr)

    print(f"Exported lyrics for {written} track(s), skipped {skipped}, errors {errors}")
    if errors:
        sys.exit(1)
  '';
  beets-export-lyrics = pkgs.writeShellScriptBin "beets-export-lyrics" ''
    ${lib.getExe pkgs.python3} ${beets-export-lyrics-py}
  '';
  beet-wrapped = pkgs.writeShellScriptBin "beet-wrapped" ''
    # Find the beets subcommand while ignoring global options. This lets the
    # wrapper decide whether the command can change tracks or their paths.
    find_beet_command() {
      local expect_value=0
      for arg in "$@"; do
        # Options such as --config consume the following argument; that value
        # must not be mistaken for the subcommand.
        if [ "$expect_value" -eq 1 ]; then
          expect_value=0
          continue
        fi

        case "$arg" in
          -c|-d|-l|--config|--directory|--library)
            expect_value=1
            ;;
          --|--config=*|--directory=*|--library=*|-v|--verbose|-h|--help|--version)
            ;;
          -*)
            ;;
          *)
            printf '%s\n' "$arg"
            return
            ;;
        esac
      done
    }

    beet_command="$(find_beet_command "$@")"
    # Always use the homelab user's ownership, the generated configuration,
    # and a stable directory for beets' state files.
    sudo -u ${homelab.mainUser.name} \
      BEETSDIR=/var/lib/slskd-import-files \
      ${lib.getExe pkgs.beets} \
      -c ${config.homelab.services.slskd.beetsConfigFile} \
      "$@"
    beet_status=$?

    # These commands may fetch lyrics or move tracks. Regenerate sidecars so
    # their contents and locations continue to match the beets database.
    case "$beet_command" in
      import|lyrics|modify|write|move)
        echo "Exporting beets lyrics sidecars after '$beet_command'..." >&2
        sudo -u ${homelab.mainUser.name} ${lib.getExe beets-export-lyrics}
        export_status=$?
        ;;
      *)
        export_status=0
        ;;
    esac

    # Report the beets failure first; only report an export failure when the
    # requested beets operation itself succeeded.
    if [ "$beet_status" -ne 0 ]; then
      exit "$beet_status"
    fi
    exit "$export_status"
  '';
  beetsConfig = {
    directory = "${config.homelab.services.slskd.musicDir}";
    library = "${config.homelab.services.slskd.musicDir}/beets.db";

    plugins = [
      "duplicates"
      "lyrics"
      "musicbrainz"
    ];

    # This handles the cases where odd characters are replaced by '_'
    replace = {
      # 1. Directory Separators: Matches any forward slash (/) or backslash (\) such as AC/DC
      "[\\\\/]" = "_";
      # 2. Hidden Files: Matches a literal dot (.) if it appears at the very beginning of a name
      "^\\." = "_";
      # 3. Forbidden & Control Characters: Matches Windows-illegal characters and ASCII control codes
      "[\\x00-\\x1f\\\\?*:\"<>|]" = "_";
    };

    terminal_encoding = "utf-8";

    threaded = true;

    ui = {
      color = true;
    };

    import = {
      autotag = true;
      bell = true;
      copy = false;
      duplicate_action = "skip";
      log = "${config.homelab.services.slskd.musicDir}/.beets/import.log";
      move = true;
      # Automated imports pass -q explicitly. Keep manual imports interactive so
      # ambiguous matches can be resolved instead of silently skipped.
      quiet = false;
      quiet_fallback = "skip";
      write = true;
    };

    original_date = true;
    per_disc_numbering = true;

    embedart = {
      auto = true;
    };

    paths = {
      default = "$albumartist/($year) $album/$track $title";
      singleton = "$albumartist/($year) $album/$track $title";
      comp = "Compilations/($year) $album/$track $title";
    };

    aunique = {
      keys = [
        "albumartist"
        "album"
      ];
      disambiguators = [
        "albumtype"
        "year"
        "label"
        "catalognum"
        "albumdisambig"
        "releasegroupdisambig"
      ];
      bracket = "[]";
    };

    fetchart = {
      auto = true;
      sources = [
        "filesystem"
        "coverart"
        "itunes"
        "amazon"
        "albumart"
        "fanarttv"
      ];
    };

    lastgenre = {
      auto = true;
      source = "album";
    };

    lyrics = {
      auto = true;
      sources = [
        "lrclib"
        "genius"
        "tekstowo"
      ];
      synced = true;
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    homelab.services.slskd.beetsConfigFile = settingsFormat.generate "beets.yaml" beetsConfig;
    homelab.services.slskd.beetsExportLyricsCommand = lib.getExe beets-export-lyrics;
    # this was added for manually being able to use beet-wrapped commands
    systemd.tmpfiles.rules = [
      "d /var/lib/slskd-import-files 0775 ${homelab.mainUser.name} ${homelab.mainUser.group} - -"
    ];

    environment.systemPackages = [
      beet-wrapped
      beets-export-lyrics
    ];
  };
}
