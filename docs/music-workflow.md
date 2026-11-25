# Emilia music workflow

## Responsibilities

- **Aurral** provides discovery, requests, approval, and management of its direct
  acquisitions.
- **Lidarr with Tubifarry** monitors selected wanted albums and handles its own
  imports, tagging, and library organization.
- **slskd** is the only music downloader, shared by Aurral, Lidarr/Tubifarry, and
  direct requests from its UI.
- **Navidrome** indexes the finished library, provides karaoke lyrics through its
  lyrics plugin, and serves music through the OpenSubsonic API.
- **Music Assistant** consumes Navidrome through that API for playback.

Lidarr imports into the curated library and applies the configured album-year
and track-number formats. Aurral reads that library and stores direct downloads
in its own writable folder. Navidrome serves the curated library.

## Paths

| Path | Purpose |
| --- | --- |
| `/mnt/media/music/import.tmp` | slskd transfers still in progress |
| `/mnt/media/music/import` | Completed slskd downloads; application approval or consumption may still be pending |
| `/mnt/media/music/aurral` | Aurral's writable Library folder for direct downloads and flow files |
| `/mnt/media/music/library` | Lidarr's curated library, read by Aurral, scanned by Navidrome, and shared by slskd |

Navidrome's scanned folder is configured with
`homelab.services.navidrome.musicDir`. slskd shares that same folder.
Navidrome scans every minute because changes on the NFS share may bypass its
native filesystem watcher.

In Aurral, add `/mnt/media/music/library` under **Settings → Library → Read-only
folders** and keep its writable Library folder at `/mnt/media/music/aurral`.
Aurral honors that setting when managing files. This is an application setting.
The service account still has the share's filesystem permissions. Keep systemd
path restrictions off the NFS library because systemd cannot traverse it as root.

Download staging stays outside the scanned library. The Navidrome module keeps
`.ndignore` in the curated library to exclude any temporary Aurral files left
from the previous layout. The slskd share filters exclude the same content.

## Acquisition routes

### Full albums through Lidarr

Lidarr handles both its own monitored albums and full-album requests delegated by
Aurral's Lidarr plugin. Tubifarry sends the downloads to slskd and Lidarr imports
them into `/mnt/media/music/library`. Use Lidarr's Media Management settings to
enable renaming and set the album and track formats. Enable MusicBrainz tag
writing for new imports if Aurral has trouble matching the finished albums.

Use version 0.3.0 or later of the Aurral Lidarr plugin, give it the curated root
for new artists, and place Lidarr first in Aurral's download source list. If an
album falls back to another source, it goes to Aurral's own folder. To guarantee
an album uses Lidarr's naming, request it in Lidarr directly or verify the Aurral
request reaches Lidarr's queue.

### Single tracks, playlists, and flows through Aurral

The Lidarr plugin handles full albums. Singles, playlist downloads, and flows use
Aurral's own download sources and its fixed naming layout. Aurral owns approval
and consolidation. Navidrome does not scan Aurral's writable folder.

To promote a track, copy the approved file into a staging folder outside both
libraries. Use Lidarr's Interactive Import on that copy and confirm the exact
album edition and track. Review any replacement separately. Verify the imported
path and playback before retiring a source copy, and keep the Aurral original
while the application still relies on it. An import from inside the artist's
Lidarr directory can be treated as an existing file and skip the import move.

### Direct slskd downloads

Direct downloads remain in the completed download folder. Review them and use
Lidarr's native manual import for the tracks or albums it should manage.

There is no global completion mover. slskd's directory-complete event does not
identify the requesting application or establish Aurral approval. Acting on every
completion can bypass approval or remove files before Lidarr consumes them.

## Maintenance rules

Uptime Kuma on Alertson monitors slskd through the exact `/health` route on
`https://slskd.tapirus.cc`, bypassing SSO only for the source IP in Emilia's
`alertson-ip` secret. Private DNS must resolve that name directly to Emilia;
the monitor accepts only HTTP 200 with redirects disabled to avoid OAuth2/Keycloak
login-page false positives. The unauthenticated backend port stays on loopback.

- Use native application settings and NixOS modules. Do not add application source
  patches, database polling workers, receipt caches, or competing importers.
- Preserve one owner for each download and its final paths. Review any legacy
  Aurral files still in Lidarr's tree before bulk renames or upgrades.
- Keep the existing library and application databases intact when changing service
  configuration. This configuration does not migrate or delete existing music or
  historical importer state.
- Keep lyrics in Navidrome's existing plugin configuration; no separate lyrics
  import stage is needed.
- Keep download staging outside Navidrome's scanned library. Preserve the
  module-managed `.ndignore` and slskd filters for Aurral temporary content.

## References

- [slskd event and script configuration](https://github.com/slskd/slskd/blob/master/docs/config.md#integrations)
- [slskd event fields](https://github.com/slskd/slskd/blob/master/src/slskd/Events/Types/Events.cs)
- [Aurral 3.0.1 release notes](https://github.com/lklynet/aurral/releases/tag/v3.0.1)
- [Aurral Lidarr plugin and read-only folders](https://docs.aurral.org/integrations/lidarr/)
- [NixOS Aurral 3.0.1 module update](https://github.com/NixOS/nixpkgs/pull/590890)
- [Lidarr documentation](https://wiki.servarr.com/lidarr)
