{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.services.beets;
  inherit (config) homelab;
  settingsFormat = pkgs.formats.yaml { };
  command = pkgs.writeShellScriptBin "beet-homelab" ''
    set -euo pipefail
    export BEETSDIR=${lib.escapeShellArg cfg.stateDir}
    exec ${lib.getExe' pkgs.util-linux "flock"} ${lib.escapeShellArg "${cfg.stateDir}/import.lock"} \
      ${lib.getExe cfg.package} -c ${cfg.configFile} "$@"
  '';
  defaults = {
    directory = cfg.libraryDir;
    library = "${cfg.libraryDir}/beets.db";

    plugins = [
      "duplicates"
      "musicbrainz"
    ] ++ lib.optional cfg.lyrics.enable "lyrics";

    # This handles the cases where odd characters are replaced by '_'
    replace = {
      # 1. Directory Separators: Matches any forward slash (/) or backslash (\) such as AC/DC
      "[\\\\/]" = "_";
      # 2. Hidden Files: Matches a literal dot (.) if it appears at the very beginning of a name
      "^\\." = "_";
      # 3. Forbidden & Control Characters: Matches Windows-illegal characters and ASCII control codes
      "[\\x00-\\x1f\\\\?*:\"<>|]" = "_";
    };

    import = {
      autotag = true;
      copy = false;
      duplicate_action = "skip";
      log = "${cfg.stateDir}/import.log";
      move = true;
      # Automatic callers pass -q; manual imports remain interactive.
      # Weak matches are retained in staging.
      quiet = false;
      quiet_fallback = "skip";
      write = true;
    };

    original_date = true;
    per_disc_numbering = true;

    match = {
      ignore_data_tracks = false;
      ignore_video_tracks = false;
      # An incomplete album may still be a strong match. Extra files that the
      # candidate release cannot account for retain beets' safer default cap.
      max_rec = {
        missing_tracks = "strong";
      };
    };

    paths = lib.genAttrs [ "default" "singleton" "comp" ] (_: "$albumartist/($year) $album/$track $title");
  };
  lyricsSettings = lib.optionalAttrs cfg.lyrics.enable {
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
  imports = [
    (lib.mkRenamedOptionModule [ "homelab" "services" "slskd" "musicDir" ] [ "homelab" "services" "beets" "libraryDir" ])
    (lib.mkRenamedOptionModule [ "homelab" "services" "slskd" "beetsLyrics" "enable" ] [ "homelab" "services" "beets" "lyrics" "enable" ])
  ];

  options.homelab.services.beets = {
    enable = lib.mkEnableOption "the shared music importer";
    package = lib.mkPackageOption pkgs.pkgs-unstable "beets" { };
    libraryDir = lib.mkOption {
      type = lib.types.externalPath;
      default = "/mnt/media/music/library";
      description = "Final music library used by beets and music consumers.";
    };
    stateDir = lib.mkOption {
      type = lib.types.externalPath;
      default = "${cfg.libraryDir}/.beets";
      description = "Shared importer state, log, and lock directory.";
    };
    lyrics.enable = lib.mkEnableOption "fetching and embedding lyrics with the native beets plugin";
    settings = lib.mkOption {
      inherit (settingsFormat) type;
      default = { };
      description = "Shared beets settings for all acquisition routes.";
    };
    configFile = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Generated shared beets configuration.";
    };
    command = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Beets command with the shared configuration, state, and import lock; run as the media user.";
    };
    importCommand = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Shared import entry point; accepts the native beet import arguments.";
    };
  };

  config = lib.mkIf cfg.enable {
    homelab.services.beets = {
      settings = lib.mkMerge [
        (lib.mapAttrsRecursive (_: value: lib.mkDefault value) defaults)
        (lib.mapAttrsRecursive (_: value: lib.mkDefault value) lyricsSettings)
      ];
      configFile = settingsFormat.generate "music-library-beets.yaml" cfg.settings;
      inherit command;
      importCommand = toString (pkgs.writeShellScript "beets-import" ''
        exec ${lib.getExe cfg.command} import "$@"
      '');
    };
    systemd.tmpfiles.rules = map
      (directory:
        "d ${directory} 0775 ${homelab.mainUser.name} ${homelab.mainUser.group} - -"
      ) [ cfg.libraryDir cfg.stateDir ];
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "beet-wrapped" ''
        exec sudo -u ${lib.escapeShellArg homelab.mainUser.name} ${lib.getExe cfg.command} "$@"
      '')
    ];
  };
}
