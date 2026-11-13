# Lachesis

An Aseprite extension that quietly snapshots your work as you draw, and turns
those snapshots into a timelapse. Requires **Aseprite 1.3 or newer**.

> Status: early. Toggle, settings and automatic snapshots work. Rename
> following and timelapse export arrive in the next releases.

## Install

1. Build the package (or download it from a release):
   - Windows: `powershell -File scripts\build.ps1`
   - macOS / Linux: `./scripts/build.sh`
2. Double-click `dist/lachesis.aseprite-extension`, or in Aseprite open
   **Edit > Preferences > Extensions > Add Extension** and pick the file.

## Use

Everything is under **File > Snapshots**:

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

## Releases

Releases are built by GitHub Actions and are only started by hand:
**Actions > Release > Run workflow** on `main`, then pick a bump.

| Bump | Example | Use for |
| --- | --- | --- |
| `minor` | v0.3.2 → v0.4.0 | New dev release with features |
| `patch` | v0.3.2 → v0.3.3 | Bug fixes and small updates |

The major number stays at 0 for now. The first release is v0.0.1 (patch) or
v0.1.0 (minor). Each release attaches `lachesis-vX.Y.Z.aseprite-extension`.
