# Lachesis

An Aseprite extension that quietly snapshots your work as you draw, and turns
those snapshots into a timelapse. Requires **Aseprite 1.3 or newer**.

> Status: early. This version adds the menu, the on/off toggle and the settings
> dialog. Snapshot capture, rename following and export arrive in the next
> releases.

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

Next to your project file, in `snapshots/<project name>/`. If you rename the
project with Save As, the folder is renamed with it.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| Idle delay | 1.5 s | Pause after your last edit before a snapshot is taken |
| Max wait | 10 s | Longest continuous editing before a snapshot is forced |
| Max size | 1024 KB | Cap per snapshot; larger images are saved downscaled |

Nothing is saved while you are not editing.
