# Lachesis Tria

A tile library for pixel art, like an asset library. Slice tiles out of what is visible on the canvas, keep them in named groups, and reuse them in any project.

Requires Aseprite 1.3 or newer. Works on Windows, macOS and Linux.

> This first release covers capturing tiles and saving them to the library. Browsing the library and stamping tiles onto a layer come next.

## Capture tiles

**File > Scripts > Tile Library > Capture Tiles From Canvas...**

1. Set the grid:
   - **x** and **y**: where the first tile starts. Anything left of x or above y is ignored.
   - **Width** and **Height**: the size of each tile in pixels.

   The fields start with the grid you last used for this file, or the sprite's grid settings (View > Grid Settings) the first time.
2. Tria takes a snapshot of every **visible layer** in the **current frame**, exactly as the canvas shows it, and cuts it into tiles. It leaves out:
   - partial tiles at the right and bottom edges,
   - tiles that are fully transparent,
   - exact duplicates (only the first copy is kept).
3. All tiles start ticked. Click a tile to leave it out, or use **Tick All** / **Tick None**.
4. Pick a group (or type a new one), name the entry, and press **Save**. If the name is already taken in that group, you can replace it or keep both.

## Where the library lives

By default it lives in Aseprite's own config folder:

| OS | Folder |
| --- | --- |
| Windows | `%APPDATA%\Aseprite\lachesis-tria\library` |
| macOS | `~/Library/Application Support/Aseprite/lachesis-tria/library` |
| Linux | `~/.config/aseprite/lachesis-tria/library` |

You can pick a different folder in **Tile Library Settings...**, for example a synced folder to share the library between computers.

Each group is a folder. Each entry is an `.aseprite` file with one frame per tile, next to a `.preview.png` thumbnail sheet. You can open an entry file in Aseprite to edit or delete its tiles. The entry also remembers which file, frame and grid it was captured from.

## Shortcuts

The commands have no keyboard shortcut by default; you can bind one in **Edit > Keyboard Shortcuts**.

## Install

Build the package from the repository root with `./scripts/build.sh lachesis-tria` (or `powershell -File scripts\build.ps1 lachesis-tria` on Windows), then double-click the resulting `.aseprite-extension` file or add it in **Edit > Preferences > Extensions**.
