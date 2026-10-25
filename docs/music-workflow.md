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

There is no shared external importer. Aurral and Lidarr each own their imports
and tracked files, but their permanent files share the same flat library tree.
Navidrome is the single scanner for that finished library; it does not import or
move files.

## Paths

| Path | Purpose |
| --- | --- |
| `/mnt/media/music/import.tmp` | slskd transfers still in progress |
| `/mnt/media/music/import` | Completed slskd downloads; application approval or consumption may still be pending |
| `/mnt/media/music/library` | The single finished library: Aurral permanent tracks and Lidarr-managed albums in the flat `Artist/Album` layout; scanned by Navidrome and shared by slskd |

Navidrome's scanned folder is configured with
`homelab.services.navidrome.musicDir`. slskd shares that same folder.
Navidrome scans every minute because changes on the NFS share may bypass its
native filesystem watcher.

Download staging stays outside the scanned library. slskd transfers remain in
`import.tmp` and `import`; Aurral's managed download folder is the library itself.
The Aurral module writes a `.ndignore` there so Navidrome ignores Aurral's
temporary flow, staging, and playlist directories while scanning permanent
`Artist/Album` music. slskd share filters exclude the same temporary content.
Do not point Navidrome at the music parent directory: it contains incomplete
downloads and pending approvals.

## Acquisition routes

### Lidarr → Tubifarry → slskd

Lidarr monitors the selected albums and uses Tubifarry to request downloads from
slskd. Let Lidarr handle completed downloads and import them into its configured
root folder. For those albums to appear in Navidrome, configure the Lidarr root
folder within Navidrome's scanned library using Lidarr's native settings.
Lidarr's saved application settings are not declared by this repository.

Do not move or rename Lidarr-managed files with a second tool: Lidarr expects the
paths recorded in its database to remain valid. Aurral and Lidarr can have files
in the same album directory; avoid Lidarr upgrades, renames, or deletions that
could affect Aurral-tracked singles in that directory.

### Aurral → slskd

Aurral owns approval and consolidation of its direct downloads. Keep that
lifecycle intact. Aurral's `DOWNLOAD_FOLDER` is `/mnt/media/music/library`,
and permanent tracks use the same flat `Artist/Album` tree as Lidarr. Aurral
tracks remain Aurral-owned even when they are physically in a Lidarr-managed
album directory; do not use Lidarr to rename, upgrade, or delete those files.
The module-managed `.ndignore` excludes Aurral temporary content from Navidrome.

The wrapper uses the stock application package and the native NixOS service.
Its saved `downloadFolderPath` setting takes precedence over `DOWNLOAD_FOLDER`,
so a short sqlite3 startup command enforces the declared folder, backing up the
database only when that setting changes. It does not migrate existing music or
rewrite track paths. The existing NFS confinement workaround remains necessary.
Keep Aurral's separate Navidrome playback integration disabled: its automatic
library setup can rename the Navidrome library at the same filesystem path,
conflicting with this repository's single Navidrome library configuration.
Changing `downloadDir` does not move the existing `/mnt/media/music/aurral`
tree. Do not activate this path change until those files have been reconciled
into the library and Aurral's tracked paths verified: the startup setting update
does not move files, and missing tracked paths can be requeued for download.
Treat same-name files as conflicts to review rather than overwriting either
application's copy. Keep the old tree until every tracked file is confirmed at
its final path. This configuration intentionally does not run a second mover or
perform a live migration.

The download folder and Lidarr root now overlap. Aurral's legacy download-folder
migration detects that overlap and refuses its migration pass; do not bypass that
guard or run the legacy migration over the shared library. Keep Aurral and Lidarr
as the owners of their respective files, and avoid Lidarr operations that could
alter Aurral-owned tracks in a shared album directory.

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
- Preserve one owner for each download and its final paths. Aurral and Lidarr
  share the flat folder structure, so avoid Lidarr operations that can alter
  Aurral-owned files in a shared album directory.
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
- [Aurral 2.10 finalization](https://github.com/lklynet/aurral/blob/v2.10.0/backend/services/pipelineHelpers.js)
- [Lidarr documentation](https://wiki.servarr.com/lidarr)
