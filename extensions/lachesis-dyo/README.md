# Lachesis Dyo

Reopens the sprites you had open the last time you used Aseprite, like a browser restoring its last tabs.

Requires Aseprite 1.3 or newer. Works on Windows, macOS and Linux.

## What it does

- Every 2 minutes (configurable) it records which files are open, in tab order, and which tab had focus. Nothing is written when the list has not changed.
- When Aseprite starts, it reopens those files and puts focus back on the tab you were using.
- A file that is already open is never opened a second time, for example one you passed on the command line. Paths are compared case-insensitively on Windows and macOS.
- Files that were moved or deleted since are skipped.
- New sprites that were never saved to disk are not part of the session, because there is no file to reopen.
- When you quit, the full list is saved before Aseprite starts closing tabs. If you cancel the quit, background saving carries on.

## Menu

Everything is under **File > Scripts > Session Restore**:

- **Restore Last Session on Launch**: the on/off switch. It is on by default. When it is off, nothing is saved and nothing is reopened on launch.
- **Reopen Last Session Now**: reopens the saved files right away, skipping ones already open.
- **Session Restore Settings...**: the save interval, and the crash-safe session file option.

The commands have no keyboard shortcut by default; you can bind one in **Edit > Keyboard Shortcuts**.

## Crash safety

By default the session lives in the extension's preferences, which Aseprite writes to disk when it closes normally. If Aseprite crashes, the session from your previous normal exit is used instead.

Turn on **Also keep a crash-safe session file** in the settings to also write the list to `lachesis-dyo-session.txt` in Aseprite's user config folder at every save. Aseprite asks once for permission to write that file; choose "Give full trust" or tick "Don't show this again" to stop it asking. If you refuse, the option turns itself off.

## Install

Build the package from the repository root with `./scripts/build.sh lachesis-dyo` (or `powershell -File scripts\build.ps1 lachesis-dyo` on Windows), then double-click the resulting `.aseprite-extension` file or add it in **Edit > Preferences > Extensions**.
