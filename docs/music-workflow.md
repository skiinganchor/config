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

There is no shared external importer. Each acquisition application owns its
downloads and final file paths. Navidrome reads the library without managing
imports or moving files.

## Paths

| Path | Purpose |
| --- | --- |
| `/mnt/media/music/import.tmp` | slskd transfers still in progress |
| `/mnt/media/music/import` | Completed slskd downloads; application approval or consumption may still be pending |
| `/mnt/media/music/aurral` | Aurral-managed files after its consolidation/approval step; these are still tracked by Aurral |
| `/mnt/media/music/library` | Finished library scanned by Navidrome and shared by slskd |

Navidrome's scanned folder is configured with
`homelab.services.navidrome.musicDir`. slskd shares that same folder.
Navidrome scans every minute because changes on the NFS share may bypass its
native filesystem watcher.

Download staging stays outside the scanned library. Aurral's managed folder is
currently separate from that library, so its direct acquisitions are **not
automatically visible in Navidrome**. Making approved, permanent Aurral music
available there remains a separate integration decision. Do not point Navidrome
at the entire music parent directory: it also contains incomplete downloads,
pending approvals, and potentially temporary playback files.

## Acquisition routes

### Lidarr → Tubifarry → slskd

Lidarr monitors the selected albums and uses Tubifarry to request downloads from
slskd. Let Lidarr handle completed downloads and import them into its configured
root folder. For those albums to appear in Navidrome, configure the Lidarr root
folder within Navidrome's scanned library using Lidarr's native settings.
Lidarr's saved application settings are not declared by this repository.

Do not move or rename Lidarr-managed files with a second tool: Lidarr expects the
paths recorded in its database to remain valid.

### Aurral → slskd

Aurral owns approval and consolidation of its direct downloads. Keep that
lifecycle intact. Aurral's `DOWNLOAD_FOLDER` controls its managed folder; it does
not implement a transfer of ownership to Lidarr or distinguish a finished
Navidrome collection from temporary playback content.

The wrapper uses the stock application package and the native NixOS service.
Its saved `downloadFolderPath` setting takes precedence over `DOWNLOAD_FOLDER`,
so a short sqlite3 startup command enforces the declared folder, backing up the
database only when that setting changes. It does not rewrite track paths or
import music. The existing NFS confinement workaround remains necessary.

### Direct slskd downloads

Direct downloads remain in the completed download folder. Review them and use
Lidarr's native manual import for albums it should manage. Unmanaged music can be
organized manually into the finished library only after confirming that neither
Aurral nor Lidarr owns the files.

There is no global completion mover. slskd's directory-complete event does not
identify the requesting application or establish Aurral approval. Acting on every
completion can bypass approval or remove files before Lidarr consumes them.

## Maintenance rules

- Use native application settings and NixOS modules. Do not add application source
  patches, database polling workers, receipt caches, or competing importers.
- Preserve one owner for each download and its final paths.
- Keep the existing library and application databases intact when changing service
  configuration. This configuration does not migrate or delete existing music or
  historical importer state.
- Keep lyrics in Navidrome's existing plugin configuration; no separate lyrics
  import stage is needed.

## References

- [slskd event and script configuration](https://github.com/slskd/slskd/blob/master/docs/config.md#integrations)
- [slskd event fields](https://github.com/slskd/slskd/blob/master/src/slskd/Events/Types/Events.cs)
- [Aurral 2.10 finalization](https://github.com/lklynet/aurral/blob/v2.10.0/backend/services/pipelineHelpers.js)
- [Lidarr documentation](https://wiki.servarr.com/lidarr)
