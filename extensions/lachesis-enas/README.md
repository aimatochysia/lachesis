# Lachesis Enas

Part of the [Lachesis](../../README.md) suite. An Aseprite extension that
quietly snapshots your work as you draw, and turns those snapshots into a
timelapse. Requires **Aseprite 1.3 or newer**.

> Status: early. Toggle, settings and automatic snapshots work. Rename
> following and timelapse export arrive in the next releases.

## Install

1. Download `lachesis-enas-vX.Y.Z.aseprite-extension` from a release, or build it
   from the repository root:
   - Windows: `powershell -File scripts\build.ps1 lachesis-enas`
   - macOS / Linux: `./scripts/build.sh lachesis-enas`
2. Double-click `dist/lachesis-enas.aseprite-extension`, or in Aseprite open
   **Edit > Preferences > Extensions > Add Extension** and pick the file.

**Upgrading from "Lachesis" v0.1.x:** this extension used to be called
`lachesis`. Aseprite treats the renamed one as a new extension, so uninstall the
old "Lachesis" entry in **Edit > Preferences > Extensions** first. Your settings
and any keyboard shortcut you assigned need to be set again once. Snapshots
already on disk are untouched and keep being used.

## Use

Everything is under **File > Scripts > Snapshots**:

- **Snapshots Enabled**: turns snapshotting on or off (shows a checkmark when on).
- **Snapshot Settings...**: idle delay, max wait and the per-snapshot size cap.

There is no default keyboard shortcut. To add one, open
**Edit > Keyboard Shortcuts**, search for "Snapshots Enabled" and assign a key.

## Where snapshots go

Next to your project file, in `snapshots/<project name>/`, as PNG files named
`<number>_<date-time>_f<frame>.png` (an `_s2`, `_s3`... suffix means the image
was saved at 1/2, 1/3... size to stay under the size cap). The project must be
saved at least once before snapshots start. Following renames is coming next.

Each snapshot is the frame you are working on, with visible layers flattened.
A snapshot identical to the previous one is skipped.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| Idle delay | 1.5 s | Pause after your last edit before a snapshot is taken |
| Max wait | 10 s | Longest continuous editing before a snapshot is forced |
| Max size | 1024 KB | Cap per snapshot; larger images are saved downscaled |

Nothing is saved while you are not editing.

Releases are described in the [root README](../../README.md#releases).
