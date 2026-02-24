{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    eog
    nautilus
    onlyoffice-desktopeditors
    papers
    vlc
    vscodium
  ];

  # enable screen sharing
  xdg = {
    mime =
      let
        image = "org.gnome.eog.desktop";
        inode = "org.gnome.Nautilus.desktop";
        office = "onlyoffice-desktopeditors.desktop";
        pdf = "org.gnome.Papers.desktop";
        text = "codium.desktop";
        video = "vlc.desktop";
        web = "brave-browser.desktop";
      in
      {
        enable = true;
        addedAssociations = {
          "inode/directory" = [ inode ];
          "x-scheme-handler/http" = [ web ];
          "x-scheme-handler/https" = [ web ];
          "application/pdf" = [ pdf ];
          "image/bmp" = [ image ];
          "image/gif" = [ image ];
          "image/jpg" = [ image ];
          "image/pjpeg" = [ image ];
          "image/png" = [ image ];
          "image/tiff" = [ image ];
          "image/webp" = [ image ];
          "image/x-bmp" = [ image ];
          "image/x-gray" = [ image ];
          "image/x-icb" = [ image ];
          "image/x-ico" = [ image ];
          "image/x-png" = [ image ];
          "image/x-portable-anymap" = [ image ];
          "image/x-portable-bitmap" = [ image ];
          "image/x-portable-graymap" = [ image ];
          "image/x-portable-pixmap" = [ image ];
          "image/x-xbitmap" = [ image ];
          "image/x-xpixmap" = [ image ];
          "image/x-pcx" = [ image ];
          "image/svg+xml" = [ image ];
          "image/svg+xml-compressed" = [ image ];
          "image/vnd.wap.wbmp" = [ image ];
          "image/x-icns" = [ image ];
          "video/x-ogm+ogg" = [ video ];
          "video/3gp" = [ video ];
          "video/3gpp" = [ video ];
          "video/3gpp2" = [ video ];
          "video/dv" = [ video ];
          "video/divx" = [ video ];
          "video/fli" = [ video ];
          "video/flv" = [ video ];
          "video/mp2t" = [ video ];
          "video/mp4" = [ video ];
          "video/mp4v-es" = [ video ];
          "video/mpeg" = [ video ];
          "video/mpeg-system" = [ video ];
          "video/msvideo" = [ video ];
          "video/ogg" = [ video ];
          "video/quicktime" = [ video ];
          "video/vivo" = [ video ];
          "video/vnd.divx" = [ video ];
          "video/vnd.mpegurl" = [ video ];
          "video/vnd.rn-realvideo" = [ video ];
          "video/vnd.vivo" = [ video ];
          "video/webm" = [ video ];
          "video/x-anim" = [ video ];
          "video/x-avi" = [ video ];
          "video/x-flc" = [ video ];
          "video/x-fli" = [ video ];
          "video/x-flic" = [ video ];
          "video/x-flv" = [ video ];
          "video/x-m4v" = [ video ];
          "video/x-matroska" = [ video ];
          "video/x-mjpeg" = [ video ];
          "video/x-mpeg" = [ video ];
          "video/x-mpeg2" = [ video ];
          "video/x-ms-asf" = [ video ];
          "video/x-ms-asf-plugin" = [ video ];
          "video/x-ms-asx" = [ video ];
          "video/x-msvideo" = [ video ];
          "video/x-ms-wm" = [ video ];
          "video/x-ms-wmv" = [ video ];
          "video/x-ms-wmx" = [ video ];
          "video/x-ms-wvx" = [ video ];
          "video/x-nsv" = [ video ];
          "video/x-theora" = [ video ];
          "video/x-theora+ogg" = [ video ];
          "video/x-ogm" = [ video ];
          "video/avi" = [ video ];
          "video/x-mpeg-system" = [ video ];
        };
        defaultApplications = {
          # Word processing
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = office; # .docx
          "application/msword" = office; # .doc
          "application/vnd.oasis.opendocument.text" = office; # .odt
          "application/rtf" = office; # .rtf

          # Spreadsheets
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = office; # .xlsx
          "application/vnd.ms-excel" = office; # .xls
          "application/vnd.oasis.opendocument.spreadsheet" = office; # .ods
          "text/csv" = text; # .csv

          # Presentations
          "application/vnd.openxmlformats-officedocument.presentationml.presentation" = office; # .pptx
          "application/vnd.ms-powerpoint" = office; # .ppt
          "application/vnd.oasis.opendocument.presentation" = office; # .odp

          # Templates & misc
          "application/vnd.ms-word.document.macroEnabled.12" = office; # .docm
          "application/vnd.ms-excel.sheet.macroEnabled.12" = office; # .xlsm
          "application/vnd.ms-powerpoint.presentation.macroEnabled.12" = office; # .pptm

          # Generic text
          "text/plain" = text;

          # YAML, JSON, TOML, INI
          "text/yaml" = text;
          "application/x-yaml" = text;
          "application/json" = text;
          "application/toml" = text;
          "text/x-ini" = text;

          # Shell & scripting
          "text/x-shellscript" = text; # .sh, .bash
          "application/x-shellscript" = text;
          "application/x-sh" = text;
          "text/x-python" = text;
          "text/x-perl" = text;
          "text/x-ruby" = text;
          "text/x-php" = text;

          # Markup & config
          "text/html" = text;
          "application/xml" = text;
          "text/xml" = text;
          "text/markdown" = text; # .md
          "text/x-readme" = text;

          # Programming source files
          "text/x-c" = text;
          "text/x-c++src" = text;
          "text/x-java" = text;
          "text/x-go" = text;
          "text/x-rustsrc" = text;
          "text/x-haskell" = text;
          "text/x-scala" = text;
          "text/x-ocaml" = text;

          # Web development
          "text/css" = text;
          "application/javascript" = text;
          "application/x-javascript" = text;
          "text/javascript" = text;
          "text/x-typescript" = text;

          # SQL
          "application/sql" = text;

          # LaTeX
          "application/x-tex" = text;
          "text/x-tex" = text;

          # Docker and DevOps
          "text/x-dockerfile-config" = text; # some systems
          "text/x-makefile" = text;

          # Misc dev
          "application/x-nix" = text; # .nix files
          "application/x-patch" = text; # .diff, .patch

          "inode/directory" = [ inode ];
          "x-scheme-handler/http" = [ web ];
          "x-scheme-handler/https" = [ web ];
          "application/pdf" = [ pdf ];
          "image/bmp" = [ image ];
          "image/gif" = [ image ];
          "image/jpg" = [ image ];
          "image/pjpeg" = [ image ];
          "image/png" = [ image ];
          "image/tiff" = [ image ];
          "image/webp" = [ image ];
          "image/x-bmp" = [ image ];
          "image/x-gray" = [ image ];
          "image/x-icb" = [ image ];
          "image/x-ico" = [ image ];
          "image/x-png" = [ image ];
          "image/x-portable-anymap" = [ image ];
          "image/x-portable-bitmap" = [ image ];
          "image/x-portable-graymap" = [ image ];
          "image/x-portable-pixmap" = [ image ];
          "image/x-xbitmap" = [ image ];
          "image/x-xpixmap" = [ image ];
          "image/x-pcx" = [ image ];
          "image/svg+xml" = [ image ];
          "image/svg+xml-compressed" = [ image ];
          "image/vnd.wap.wbmp" = [ image ];
          "image/x-icns" = [ image ];
          "video/x-ogm+ogg" = [ video ];
          "video/3gp" = [ video ];
          "video/3gpp" = [ video ];
          "video/3gpp2" = [ video ];
          "video/dv" = [ video ];
          "video/divx" = [ video ];
          "video/fli" = [ video ];
          "video/flv" = [ video ];
          "video/mp2t" = [ video ];
          "video/mp4" = [ video ];
          "video/mp4v-es" = [ video ];
          "video/mpeg" = [ video ];
          "video/mpeg-system" = [ video ];
          "video/msvideo" = [ video ];
          "video/ogg" = [ video ];
          "video/quicktime" = [ video ];
          "video/vivo" = [ video ];
          "video/vnd.divx" = [ video ];
          "video/vnd.mpegurl" = [ video ];
          "video/vnd.rn-realvideo" = [ video ];
          "video/vnd.vivo" = [ video ];
          "video/webm" = [ video ];
          "video/x-anim" = [ video ];
          "video/x-avi" = [ video ];
          "video/x-flc" = [ video ];
          "video/x-fli" = [ video ];
          "video/x-flic" = [ video ];
          "video/x-flv" = [ video ];
          "video/x-m4v" = [ video ];
          "video/x-matroska" = [ video ];
          "video/x-mjpeg" = [ video ];
          "video/x-mpeg" = [ video ];
          "video/x-mpeg2" = [ video ];
          "video/x-ms-asf" = [ video ];
          "video/x-ms-asf-plugin" = [ video ];
          "video/x-ms-asx" = [ video ];
          "video/x-msvideo" = [ video ];
          "video/x-ms-wm" = [ video ];
          "video/x-ms-wmv" = [ video ];
          "video/x-ms-wmx" = [ video ];
          "video/x-ms-wvx" = [ video ];
          "video/x-nsv" = [ video ];
          "video/x-theora" = [ video ];
          "video/x-theora+ogg" = [ video ];
          "video/x-ogm" = [ video ];
          "video/avi" = [ video ];
          "video/x-mpeg-system" = [ video ];
        };
      };
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
      ];
    };
  };
}
