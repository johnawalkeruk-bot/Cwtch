# CWTCH — Development Home

This folder is the canonical development copy of CWTCH.

- **Game/**: complete Godot project, game assets and scripts.
- **NPCS/, Trees/, Tools/**: original supplied models and textures.
- **Launcher/**: custom Windows installer/updater.
- **DevTools/**: reproducible setup, build and publishing commands.
- **Dist/**: checked, versioned release builds (local only).
- **.local/**: local sign-in and build state (never committed).

Use **Open Editor.cmd** to edit, **Play Development.cmd** to test the current
source, and **Launch CWTCH.cmd** to install/play the latest published version.
The updater verifies the download checksum and installs each version separately.
It retains the previous installation if a download fails. Saves live separately
under `%LOCALAPPDATA%/CWTCH/UserData` for installed releases. Development saves
remain under `Game/runtime/data`.

## Publish each new version

Run **Publish Next Version.cmd** after finishing a change. It increments the
patch version, imports and checks Godot, builds a portable package, checks that
package, commits and pushes the development files, tags the version and uploads
the release and launcher. Players receive the latest release on launcher startup.
It does not publish unfinished edits on every file save.

For a specific version: `DevTools/Publish-Version.ps1 -Version 0.2.0`.
If upload fails after the tag was pushed, reuse the existing files in `Dist` with
GitHub CLI's `release create` or `release upload`; do not overwrite a released tag.

## Another development machine

Install Git with Git LFS, clone this repository, then run `git lfs pull` and
`python DevTools/setup.py`. The setup downloads pinned official Godot, Python
and GitHub CLI runtimes. Sign in using GitHub CLI's browser flow before publishing.
Use a public repository so players do not need GitHub credentials.

The launcher is a native Windows application with a bundled Python updater; it
does not require PowerShell scripts or change execution policies. Full game source is also in `Game/FULL_SOURCE.md`.

## Local split-screen

Connect two controllers before entering the garden, or connect a second during play.
The first connected controller owns the left view (gold/blue); the second owns
the right view (red/gold). Both use left stick to glide and right stick to aim.
D-pad Up/Right/Down/Left selects Hoe/Seeds/Watering Can/Shovel; hold RT to use,
X / Square changes shovel mode, and B / Circle puts the tool away.
Keyboard and mouse continue to control player one. Extra controllers do not
control either spirit during play.

The garden, time, weather, wildlife, purse and save are shared. Either player can
open the shared pause menu with Start. Village streets also split; shops and story
conversations use one full-screen view. Disconnecting either active controller
pauses and returns to a single view; resume from the pause menu. Player two’s
garden position and equipment persist in the garden save, including older saves
that had no second player. Use Play Development.cmd to try unpublished changes.
