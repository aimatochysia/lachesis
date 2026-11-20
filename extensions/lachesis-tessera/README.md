# Lachesis Tessera

See whether your pixel art tiles seamlessly. Select an area and Tessera shows it repeated side by side, live, while you keep drawing on the normal canvas.

Requires Aseprite 1.3 or newer. Works on Windows, macOS and Linux.

## Use it

1. Bind a key to **Tiled Preview** in **Edit > Keyboard Shortcuts** (search for "Tiled Preview"). There is no default shortcut.
2. Select the area you want to check, for example one 16x16 tile. With nothing selected, Tessera uses the last area you selected in that sprite, or the whole canvas if you never selected anything.
3. Use the shortcut (or **File > Scripts > Tiled Preview > Tiled Preview**).

What you see is every **visible layer** of the **current frame**, flattened, exactly as the canvas shows it. The preview follows the selection as you change it, the frame you are on and the sprite tab you have open.

## Two ways to show it

Pick one in **Tiled Preview Settings... > Show as**.

| Show as | How it works |
| --- | --- |
| **Hold to peek** (default) | Hold the shortcut and the tiles appear over the canvas. Let go and they disappear. Clicking the preview or pressing Esc also closes it. |
| **Preview window** | The shortcut opens a small floating window, and pressing it again closes it. The window stays open while you draw and updates within a moment of every change. Park it beside the canvas or on a second screen; its size and position are remembered. |

Aseprite scripts cannot draw on the canvas itself, so the peek is a window laid over the work area.

## Settings

**File > Scripts > Tiled Preview > Tiled Preview Settings...**

| Setting | Choices | Default |
| --- | --- | --- |
| Show as | Hold to peek, Preview window | Hold to peek |
| Repeat | Both, Horizontal, Vertical (same as Aseprite's own tiled mode) | Both |
| Tiles | 2x2 to 7x7 | 3x3 |
| Zoom | Fit, 1x, 2x, 3x, 4x, 6x, 8x | Fit |

Fit uses the largest whole-number zoom that fits, and scales down only when the area is too big to fit at 1x. Pixels are never blurred. The preview window also has Repeat, Tiles and Zoom dropdowns under the tiles.

## Nothing is left in your sprite

Tessera only reads the sprite. It never adds layers, cels or frames, never writes properties, and adds nothing to the undo history, so a saved file stays saved. Closing the preview, closing the sprite or quitting Aseprite leaves nothing behind.

## Install

Build the package from the repository root with `./scripts/build.sh lachesis-tessera` (or `powershell -File scripts\build.ps1 lachesis-tessera` on Windows), then double-click the resulting `.aseprite-extension` file or add it in **Edit > Preferences > Extensions**.
