# Emilia music workflow

Reviewed against the pinned Aurral 2.10.0 and Lidarr 3.1.6.5078 on 2026-10-15.

## Ownership and maintenance

slskd is the only downloader. Music requests come from its UI, Lidarr with
Tubifarry, or Aurral. The intended workflow is:

1. slskd completes the download.
2. Its owning application finishes any approval or review.
3. One shared beets importer matches, tags, indexes, and moves the approved music.
4. Aurral and Lidarr accept the resulting paths, where applicable.
5. Navidrome streams the final library.

Maintain beets settings in **`modules/homelab/services/beets/default.nix`** through
`homelab.services.beets.settings`. Client hooks should call its `importCommand`;
they must not define a second beets configuration or import policy.

**Status: the shared importer is configured. Automatic handoff for all three
routes is not implemented through native application settings.** The previous
custom Aurral worker and package patches have been removed. Emilia's raw slskd
completion mover is disabled because it can bypass Aurral approval or race
Lidarr's importer. This is a configuration refactor, not a completed replacement
for the missing application hooks. Review this limitation before deployment.

## Paths

| Path | Purpose |
| --- | --- |
| `/mnt/media/music/import.tmp` | slskd transfers still in progress |
| `/mnt/media/music/import` | Completed slskd downloads; application approval or consumption may still be pending |
| `/mnt/media/music/aurral` | Aurral-managed files after its consolidation/approval step; these are still tracked by Aurral |
| `/mnt/media/music/library` | Final shared library; Navidrome reads here |
| `/mnt/media/music/library/beets.db` | One beets database for all routes |
| `/mnt/media/music/library/.beets` | One beets state directory, import log, and import lock |

Beets uses `$albumartist/($year) $album/$track $title` for albums, singletons,
and compilations. This keeps all new imports under an artist and album directory.
Existing files are not renamed by changing this configuration. Navidrome's music
folder defaults to `homelab.services.beets.libraryDir` and scans every minute for
changes on the NFS share.

## Shared entry points

`homelab.services.beets.command` is the native `beet` CLI wrapped with the shared
YAML configuration, `BEETSDIR`, and `flock` lock. It runs as the media user.
`homelab.services.beets.importCommand` calls that command's `import` subcommand.
No Python or JavaScript importer is involved.

For an **unmanaged, completed directory**, an administrator can run:

```console
beet-wrapped import /path/to/completed/album
```

Add `-q` for automatic acceptance of strong matches. Weak recommendations and
unmatched files remain in their source directory (`quiet_fallback: skip`);
review the exact directory interactively with the same command. Use `-s` when
intentionally importing a standalone track.

Do not import the download root: other transfers or approvals may be pending.
Do not manually move an Aurral- or Lidarr-tracked file with this command: beets
cannot update those applications' database references through existing settings.
The shared command is ready for supported client hooks, not a path-repair tool.

The optional native beets lyrics plugin fetches and embeds lyrics when
`homelab.services.beets.lyrics.enable = true`. Navidrome can read embedded lyrics.
The previous custom Python sidecar exporter was removed. Existing sidecars are
not deleted or regenerated.

## Why one slskd completion hook does not cover all routes

| Route | Required readiness signal | Native integration status |
| --- | --- | --- |
| Direct slskd | Directory transfer complete | slskd's `DownloadDirectoryComplete` event can invoke the shared importer when no other application owns downloads |
| Lidarr → Tubifarry → slskd | Lidarr finishes download handling or delegates import | Lidarr currently owns its import/move and expects its chosen destination; its database must remain consistent with the final file path |
| Aurral → slskd | Aurral approves/consolidates a permanent download | Aurral 2.10 has no supported beets handoff that also accepts final paths |

slskd's directory-complete event exposes local/remote directory names and a peer
username. It does not expose the originating application or Aurral's approval
state. Importing every event moves files before approval and can remove a
Lidarr download before Lidarr sees it. Waiting a fixed number of seconds does
not establish approval.

`homelab.services.slskd.autoImport` is therefore off on Emilia. The option is
available for a deployment where slskd is the only owner; an assertion rejects
enabling it alongside Aurral or Lidarr. Its small shell hook validates the event's
path and calls the shared importer. It has no matching or move policy of its own.

Aurral's `DOWNLOAD_FOLDER` controls its managed folder, not an external beets
import destination. Aurral saves job/media paths there. Pointing it at the final
library or moving its files with a timer does not supply the missing handoff.

Lidarr's `UseScriptImport`/`ScriptImportPath` is a useful native extension point,
but the pinned version expects the script to create **Lidarr's** destination.
Its return codes do not provide an arbitrary final beets path. A post-import
script also cannot move files again without updating Lidarr. Do not add a second
mover based solely on the presence of that setting.

## Upstream changes needed

### Aurral application

Add a supported external-import callback **after approval**, restricted to
permanent acquisitions (not temporary flow/playback files). It should invoke the
shared importer and accept its final path/metadata, update Aurral's own job and
media references, and retain a reviewable file on an uncertain match or failure.
Use an application-owned lifecycle hook rather than polling its SQLite schema.

The current saved `downloadFolderPath` setting also takes precedence over
`DOWNLOAD_FOLDER`. A supported way to enforce declarative settings would remove
the remaining startup database adjustment.

### nixpkgs Aurral module

A first-class `downloadDir` should wire the environment, directory creation,
permissions, mount ordering, and confinement bindings. Document the saved UI
setting's precedence. Once the application supports the callback, expose its
command/path options and runtime dependencies in the module. A module option
alone cannot implement application behavior that does not exist.

The homelab wrapper continues to use upstream `services.aurral` with the stock
package. Its existing NFS confinement workaround is retained. A short sqlite3
startup command replaces the old Python folder-enforcement helper; it backs up
the database only when changing the saved folder. It does not rewrite track paths
or import music.

### Lidarr/Tubifarry and slskd

Provide a supported external-import mode that delegates the move to beets,
accepts the resulting path, and updates the managed library/download state.
Lidarr should then index the library without renaming or tagging it again.
Do not just disable completed download handling and claim that Lidarr's queue and
library will automatically stay synchronized.

A requester/category or external batch identifier on slskd completion events,
with matching support in its API clients, would allow declarative routing of
managed and direct downloads without inspecting application databases.

## Earlier fixes retained

- Lidarr's archive remains pinned to the immutable 3.1.6.5078 release URL. The
  earlier hash mismatch came from the mutable nightly download endpoint.
- Aurral's declared managed folder and NFS confinement workaround remain in place.
- Navidrome uses a native scan schedule; no custom watcher is needed for NFS.
- The earlier nginx network/DNS ordering fix is separate from music importing.
- Completed one-time music/path migrations are not repeated during startup.

## Removed approach

The previous proposal added an Aurral-specific JavaScript polling worker,
tracker source patch, Python import driver, receipt plugin, review command,
ownership checker, and receipt caches alongside the slskd importer. That made the
workflow depend on application internals and duplicated importer behavior.
Those files/options/commands have been removed. The old `aurral-beets-import`
manual mover is also retired because it invalidated Aurral's references.

No service switch, music migration, cleanup, or live database changes are part of
this refactor. Existing library files and old migration backups stay where they
are. Old receipts, if that proposal was deployed, are inert after switching back
to the stock Aurral package; review them before any separate cleanup.

## References

- [slskd event and script configuration](https://github.com/slskd/slskd/blob/master/docs/config.md#integrations)
- [slskd event fields](https://github.com/slskd/slskd/blob/master/src/slskd/Events/Types/Events.cs)
- [Aurral 2.10 finalization](https://github.com/lklynet/aurral/blob/v2.10.0/backend/services/pipelineHelpers.js)
- [Pinned Lidarr script import contract](https://github.com/Lidarr/Lidarr/blob/v3.1.6.5078/src/NzbDrone.Core/MediaFiles/ScriptImportDecider.cs)
- [Beets import options](https://docs.beets.io/en/stable/reference/cli.html#import)
- [Beets lyrics plugin](https://docs.beets.io/en/stable/plugins/lyrics.html)
