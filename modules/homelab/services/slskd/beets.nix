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
  beet-wrapped = pkgs.writeScriptBin "beet-wrapped" ''
    sudo -u ${homelab.mainUser.name} BEETSDIR=/var/lib/slskd-import-files ${lib.getExe pkgs.beets} -c ${config.homelab.services.slskd.beetsConfigFile} "$@"
  '';
  beets-export-lyrics-py = pkgs.writeText "beets-export-lyrics.py" ''
    import os
    import re
    import sqlite3
    import sys

    library = "${config.homelab.services.slskd.musicDir}/beets.db"
    timestamp = re.compile(r"^\s*\[\d{1,2}:\d{2}(?:[.:]\d{1,3})\]", re.MULTILINE)

    def decode_path(path):
        if isinstance(path, bytes):
            return os.fsdecode(path)
        return path

    try:
        conn = sqlite3.connect(library)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "select path, lyrics from items where lyrics is not null and length(trim(lyrics)) > 0"
        )
    except sqlite3.Error as error:
        print(f"Failed to read beets lyrics from {library}: {error}", file=sys.stderr)
        sys.exit(1)

    written = 0
    for row in rows:
        track_path = decode_path(row["path"])
        lyrics = row["lyrics"].replace("\r\n", "\n").replace("\r", "\n").strip()
        extension = ".lrc" if timestamp.search(lyrics) else ".txt"
        lyrics_path = os.path.splitext(track_path)[0] + extension
        lyrics = lyrics + "\n"

        try:
            with open(lyrics_path, "r", encoding="utf-8") as existing:
                if existing.read() == lyrics:
                    continue
        except FileNotFoundError:
            pass

        tmp_path = lyrics_path + ".tmp"
        with open(tmp_path, "w", encoding="utf-8") as output:
            output.write(lyrics)
        os.replace(tmp_path, lyrics_path)
        written += 1

    print(f"Exported lyrics for {written} track(s)")
  '';
  beets-export-lyrics = pkgs.writeShellScriptBin "beets-export-lyrics" ''
    ${lib.getExe pkgs.python3} ${beets-export-lyrics-py}
  '';
  beetsConfig = {
    directory = "${config.homelab.services.slskd.musicDir}";
    library = "${config.homelab.services.slskd.musicDir}/beets.db";

    plugins = [
      "duplicates"
      "lyrics"
    ];

    terminal_encoding = "utf-8";

    threaded = true;

    ui = {
      color = true;
    };

    import = {
      write = true;
      copy = true;
      move = false;
      autotag = true;
      bell = true;
      log = "/dev/null";
      quiet = true;
      quiet_fallback = "asis";
    };

    original_date = true;
    per_disc_numbering = true;

    embedart = {
      auto = true;
    };

    paths = {
      default = "$albumartist/($year) $album/$track $title";
      singleton = "$albumartist/($year) $album/$track $title";
      comp = "Compilations/$album/$track $title";
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
