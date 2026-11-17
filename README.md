# Lachesis

A small suite of Aseprite extensions. Each one lives in its own folder under
`extensions/` and is packaged and installed separately. All need
**Aseprite 1.3 or newer** and work on Windows, macOS and Linux.

| Extension | What it does |
| --- | --- |
| [lachesis-enas](extensions/lachesis-enas/README.md) | Toggleable automatic snapshots of your work, saved next to the project, for timelapses |

## Build

From the repository root:

- macOS / Linux: `./scripts/build.sh` builds every extension, or
  `./scripts/build.sh lachesis-enas` builds just one.
- Windows: `powershell -File scripts\build.ps1` (same optional name argument).

Each extension ends up as `dist/<name>.aseprite-extension`. Double-click it, or
in Aseprite open **Edit > Preferences > Extensions > Add Extension**.

## Adding an extension

Create `extensions/<name>/` with its own `package.json` (whose `name` is
`<name>`), `src/` and `README.md`, then add a row to the table above. The build
scripts and the release workflow pick it up automatically.

## Releases

Releases are built by GitHub Actions and are only started by hand:
**Actions > Release > Run workflow** on `main`, then pick a bump.

| Bump | Example | Use for |
| --- | --- | --- |
| `minor` | v0.3.2 → v0.4.0 | New dev release with features |
| `patch` | v0.3.2 → v0.3.3 | Bug fixes and small updates |

The major number stays at 0 for now. All extensions share one version number,
and each release attaches one `<name>-vX.Y.Z.aseprite-extension` per extension.
