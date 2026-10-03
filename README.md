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
X / Square opens the tool wheel, and B / Circle puts the tool away.
Choose Shovel in the wheel to select its mode. A / Cross guides a selected resident.
Keyboard and mouse continue to control player one. Extra controllers do not
control either spirit during play.

The garden, time, weather, wildlife, purse and save are shared. Either player can
open the shared pause menu with Start. Village streets also split; shops and story
conversations use one full-screen view. Disconnecting either active controller
pauses and returns to a single view; resume from the pause menu. Player two’s
garden position and equipment persist in the garden save, including older saves
that had no second player. Use Play Development.cmd to try unpublished changes.

## Valley presentation

The HUD shows status rather than control reminders; controls are documented above.
Menus use the same woodland-green panels and gold accents, and shop stock scrolls.
Natural weather has weighted transitions and variable durations, with its future
random sequence retained in the garden save. The village shares this weather.

Entering the garden from the main menu or returning from the village plays Arthur’s
Welcome.mp3 conversation, with timed subtitles and the existing portrait-camera
sequence. It repeats on each entry and is independent of the one-time hedgehog
introduction. Speech borders alternate the supplied Ui/Border-1.png and Border-2.png
at staggered angles. The menu and garden share the same mountain generator.

The launcher shows patch notes matched to the latest published release, using the
website changelog with GitHub release notes as a fallback. A cached copy remains
available offline. Manual publishing attaches these same changelog notes to each
GitHub release. Players with an older launcher need the updated launcher package
to see this panel; game updates do not replace the running launcher.

## Daffodil wheel, clock and garden experience

- Open the tool wheel with **Xbox X / PlayStation Square**, confirm with
  **A / Cross**; close with
  **B / Circle**. On keyboard use **Tab**, then mouse/click or Enter; Escape closes.
- Choose with the left stick or D-pad. Selecting Shovel opens Dig/Pick/Pour/Thump.
  Existing 1–4 and D-pad tool shortcuts, keyboard X mode cycling and held tool use
  remain available. B / Circle outside the wheel still puts the tool away.
- Each split-screen player owns a separate wheel; its blur stays inside their view.
- The analogue clock is on the left. Its 12 petals fill toward the next level;
  each level needs 100 XP. Level and XP are shared across the garden and saved.
- Successful hoeing earns 2 XP, grass seeding 3, watering dry ground 1, and changed
  shovel terrain 3. Each tile/action earns XP once per in-game day. Invalid uses
  and unchanged ground do not earn XP. Animal visits earn 25, residency 50 and
  births 30; existing discovery records are not retroactively converted to XP.
- Supplied button icons follow each controller’s reported identity: PlayStation
  names select PlayStation artwork; Xbox and generic mapped pads use Xbox artwork.
  Remapping software that presents a PlayStation pad as Xbox will show Xbox icons.
  Keyboard/mouse input shows compact key labels instead.

The in-game pause and shop menus use the clean woodland-green style, without
decorative petal frames. Button hints float over the scenery with outlined text.
The daffodil tool wheel, analogue clock and leather Field Guide keep their designs.


## Studio blog and manual releases

`Website/blog.html` is the studio blog. `DevTools/build_blog.py` renders it locally;
`Publish Next Version.cmd` automatically freezes a new post after promoting the
changelog and publishes it with the website. Retrying the same version keeps its
existing post. The author is always **Waldas Gamer Studios**. Nothing is published
by generating the local preview.

For each update, add `blog` to the unreleased changelog entry: `intro` (a lightly
humorous paragraph), `why` (paragraphs explaining decisions), `issues` (honest
recorded problems or limitations), and `screenshots` (optional objects with `path`
and `caption`). Store screenshots under `Website/assets/blog/` with unique names;
never overwrite images used by an older post. Only use actual development captures.
Run `Launcher/Python/python.exe DevTools/build_blog.py` to refresh the preview.

If editorial notes are omitted, publishing still creates a post from the release
notes with a light-hearted introduction and explicitly says detailed reasons or
additional issues were not recorded. It does not invent bugs, fixes or test results.
Published snapshots live in `Website/blog/posts.json`; older releases are not
backfilled automatically. Preview posts are explicitly marked as unreleased.


## Northern arrival

New Garden plays a roughly 40-second arrival before Arthur's welcome. A camera at
walking height follows the existing gravel-textured approach downhill, with a
small footstep bob and eased looks toward a crossing creature, a flying bird, a
birch and two distant animals. Escape, B / Circle or Start skips the walk. Both
players share the arrival and return to their own cameras afterwards. Existing
gardens receive the scenery but do not replay the walk when loaded.

The permanent path runs from the northern mountain scenery to the garden boundary.
Its height samples the actual meadow and ridge triangles. The walk uses the lower
34 metres; the upper stretch remains background scenery. Garden movement still
stays within the playable plot. Clock, weather and ambience continue during the
arrival. The arrival uses the supplied rabbit and bull models and the animated robin.
These are scenery, not visitor/resident animals, and do not change wildlife records or XP. The bird and crossing creature
animate during the arrival; this is not a new background wildlife AI system.

Tune timing, positions and scenery models in Game/northern_arrival.gd. No
save migration is needed. Player positions are saved at the northern garden entry.


### Arrival cast and corner rocks

The rabbit crosses with a simple whole-body hop; the robin uses its Blender Flying
clip; the two distant bulls breathe subtly. Rabbit and bull source rigs contain no
animation clips. Four textured rocks sit outside the plot corners with seeded yaw
and small tilt variations, stable across reloads. Arthur waits by the north entry
for the new-garden walk and welcome, then resumes normal wandering. Skipping the
walk still preserves his greeting. Source FBX and texture files remain untouched;
DevTools/import_arrival_models.py regenerates the game GLBs through Blender.

### Authored robin animation

Art/Robin/Robin_Animated.blend contains the editable 11-bone rig with a packed
texture. DevTools/animate_robin.py rebuilds Idle, Hopping and Flying from the
original FBX. Both REF_MOTION videos informed the poses; these are hand-authored
reference-inspired loops, not motion capture. The game switches clips with movement
and short low flights, preserving the 1% water entry rule and save data.

The high-density rock is reduced to approximately 12,000 faces for the game copy;
its full-detail FBX remains in Decor/Rock. The latest blog post was explicitly
revised on 2 October 2026, with unreleased changes labelled as a development follow-up.

## Purchases and resident destinations

Selecting shop stock returns to the garden with a translucent preview. Aim and move
to choose clear, dry ground; LB/RB (L1/R1), or Q/E, rotate it in 45-degree steps.
A / Cross or left click confirms; B / Circle or Escape cancels. Coins are charged
only when a valid placement is saved. In split-screen the spirit that entered the
shop receives the preview. Placement is cancelled if the game is paused.

Aim at a resident and press A / Cross, or R on keyboard. The animal waits under
a gold marker while a blue marker chooses its destination. Player two uses yellow
and red. Confirm to let it walk there; cancel to resume its wandering. Visitors
cannot be guided until resident. After reaching its destination the animal rests
briefly, then resumes wandering. Purchased animal positions and object rotations
are saved; old saves remain compatible.

The save emblem spins for at least four seconds on each save, and stays on during
longer cloud uploads. The toast reports whether saving or cloud syncing succeeded.

## Check before publishing

`Launcher/Python/python.exe DevTools/publish.py --check` validates release notes
and blog images without building, committing, uploading or publishing. The manual
publisher runs this same check first. If it reports missing notes, complete the
Next update entry in Website/changelog.json, then retry Publish Next Version.cmd.
An interrupted release keeps its pending version and can reuse promoted notes.
