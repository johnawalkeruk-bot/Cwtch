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
