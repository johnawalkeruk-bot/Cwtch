## Garden edge blending

The meadow continues live garden edge textures and blends into its surface brush over 1.5 metres. Colour, normal detail, roughness, parallax and watering share the same boundary, including corners. Tool changes appear immediately; tile types and land percentages are unchanged.

# Shovel, continuous tools and TARDIS shortcuts

Ctrl+T or clicking the right stick (R3) lands the TARDIS just north of the
garden, or makes it take off when landed. Repeated presses during an arrival
or departure do not restart the effect. Shortcuts are disabled in menus and
the console.

Hold left-click or the controller right trigger to repeat the equipped tool.
You can glide while working. Releasing finishes the current stroke without
starting another; opening a menu or the console cancels use and requires a
fresh press. Put away stows all models and disables tool actions.

Choose Shovel in the Tab / Y tool wheel, then choose one of its four modes.
Q/E or LB/RB cycles modes while equipped; a stroke already underway finishes
in its original mode. Keys 1–4 equip hoe, grass seeds, watering can and shovel.

- Dig: scoop a sloped hollow. Water fills the below-ground depression; repeated
  scoops deepen it to a safe floor above the diorama base.
- Pick: make a small, dry planting hole. Grass seeds planted there close the
  hole and grow the existing grass ground type.
- Pour: restore the local original ground height and fill the hollow with dirt.
- Thump: flatten the entire selected tile, including all edges and corners, to its original central elevation (zero at the garden boundary),
  with a smooth transition at its edge. Holding repeats the levelling action.

Each mode has a distinct procedural model animation and its matching sound.
Hoe, seeds and watering can also use their supplied Sounds folder recordings.
Original models and sounds remain in Tools/ and Sounds/.

Terrain edits change the height mesh, surface normals, raycast collision,
water depth, and grass roots. Only affected chunks and their shared edges are
rebuilt. Edits avoid people, crops and building footprints, preserve the outer
boundary, and are saved with the garden. Existing saves without deformation
continue to load normally.

# Compass, developer console and the TARDIS

The compass at the top of the garden and village shows the camera heading.
North is world -Z; east is +X. It follows mouse and controller camera aiming.

In the garden, press the backtick key (`) to open or close the developer console.
Escape closes it, Enter runs a command, and Up/Down recalls command history.
Movement and tool selection are disabled while typing. The simulation continues
unless the pause menu is open. Type `help` to see the commands:

- `time 18:30` sets the 24-hour clock within the current dawn-to-dawn cycle.
- `weather fair`, `weather cloudy`, `weather light rain`, `weather rain`,
  `weather heavy rain`, `weather thunderstorm`, or `weather clearing`.
- `tardis land` materialises just outside the north edge, with its door facing south.
- `tardis takeoff` dematerialises a landed TARDIS.
- `tardis visit` lands, waits 20 seconds, and automatically takes off.
- `tardis status` reports whether it is away, landing, landed or taking off.

Time and weather continue their normal cycles after a command. Existing saves
retain time/weather through the normal save flow. The TARDIS is a temporary
console event and does not persist across restarting the game.

The model stays in its rest pose throughout landing and takeoff; no spin clips
play. Its materialisation shader and lamp pulses follow Landing.mp3 and
Takeoff.mp3. It stands 2.4 m beyond the middle of the north boundary, grounded
on the surrounding meadow, without occupying garden tiles. Pause holds the
sound and visual effect together. Original source animations remain intact.

# Animal notices and the land survey

Animal visits and residency changes display a queued bottom-left notice with
the day. Each notice stays for six seconds; opening the pause menu or Field
Guide hides and holds the queue. Reloading a save does not replay old arrivals.
Purchasing another animal of an already discovered species still gives notices.

Birth and death notification handlers are available as
`garden.wildlife.record_birth(species, individual_id)` and
`garden.wildlife.record_death(species, individual_id)`. Pass a stable unique
animal ID. Their event records survive saves and suppress duplicate reports.
These handlers report events only; breeding and lifespan simulation are not
implemented, and no animals are randomly born or killed by this update.

The Field Guide's fourth tab, Land area, shows every micro-tile with north at
the top, eight terrain colours, tile counts and coverage percentages. Buildings
remain included in the underlying ground totals; scenery beyond the garden is
excluded. Hover a square or use arrows/D-pad to inspect its ground type and
coordinates. Previous/Next scans tiles; LB/RB changes categories. Counts refresh
from the current terrain when the page opens or a terrain change is reported.

# Village and shops

Choose Visit the village from the garden pause menu. WASD/left stick moves;
mouse/right stick aims. Aim at a cottage and click, press E or A/Cross to enter.
Esc/Menu opens the village travel menu, including Return to the garden.

A gravel-textured street links four cottage-front shops: animal keeper, nursery,
decorator and builder. Each opens a warm 3D interior with its own stock. Start
with 500 coins; purchases deliver to clear garden ground and save immediately.
Stock includes chicken, hedgehog, young birch/ash, flower planter, bench and cottage.
Coin earning and manual placement are not implemented in this first village version.
Balances, purchases and delivery locations survive save/reload. Purchases are
blocked when funds or space run out; no coins are spent if saving fails.

The Field Guide has left-edge category tabs. LB/RB switches categories;
D-pad or keyboard arrows browse entries. B/Esc closes the book.

Validation: all four interiors, all seven purchases, insufficient funds, delivery,
return travel, save/reload and category/entry controller navigation passed.

---

# Menu and handwritten guide update

Main-menu labels, options, weather text and new-garden confirmation are uppercase.
QUIT GAME closes the application. The pause menu keeps Save & return to main menu
and adds Save & Quit, which writes and flushes the current garden before exiting.
If saving fails, the application stays open and displays a message.

The Field Guide uses Segoe Print handwriting throughout, with Ink Free and Segoe
Script fallbacks. This uses installed Windows fonts rather than redistributing them.
Opening the guide shows the cover, then a hinged cover and two turning flyleaves
before revealing the entries. Escape/B can cancel back to pause during opening.

Validated 16:9 menu/pause layouts, handwritten pages and cover/page-turn renders.
Save & Quit was invoked in an isolated test profile; its latest saved state was
verified after the application exited. Player saves were not used for testing.

---

# Leather Field Guide

Open the pause menu (Esc / F / controller Menu), then choose Open the Field Guide.
The open leather book has stitched edges, aged parchment, a shaded spine and
serif lettering. People, Animals and Plants tabs contain ten illustrated entries:
Arthur, Meera, Angus, the visitor, chicken, hedgehog, badger, dragon, ash and birch.
Each has a description and a softly lit, slowly rotating 3D model. Animal previews
reuse repaired garden visuals rather than broken source rigs. Previews use their
own 3D world and never move the real NPCs or resume the garden.

Previous / Next browse entries. Controller A confirms, D-pad navigates buttons,
LB / RB turns pages, and B closes the book back to pause. Keyboard Esc / F also
closes the book. Closing releases its preview; rendering stops while hidden.
Validated all ten previews visually, pause preservation and controller navigation.

---

# Angus McDoogal

Added Angus from Desktop/CWTCH/NPCS/Angus-McDoogal/Angus.fbx, with his
embedded texture and 25.37-second supplied animation. He performs in place,
is selectable, and has a collision body and reserved garden tile. Opening the
Field Guide pauses playback. Arthur, Meera and the other visitors remain.
import_angus.py reproduces assets/npcs/angus.glb with Blender.

Validation: eight NPC collision bodies, 44 changing bones, looping playback,
guide pause and tile reservation. Rendered and inspected three animation poses.

---

# Controller support

Standard Godot-mapped Xbox/PlayStation-style controllers are supported alongside
keyboard and mouse. Prompts change with the last input device.

- Left stick: glide, with a 22% deadzone to prevent drift.
- Right stick: aim the camera; speed is independent of frame rate.
- Y / Triangle: open or close the tool wheel.
- Left stick or D-pad: choose a tool; A / Cross equips it.
- Right trigger: use the equipped tool once per press.
- Menu / Start: open or close the Field Guide.
- B / Circle: close the wheel or guide; return from Options.
- Menus: left stick or D-pad navigates, A / Cross confirms.

Disconnecting the active controller opens the Field Guide and cancels pending
use. Keyboard and mouse remain available. Validation uses simulated controller
events for menu focus/options/back, deadzones, movement, camera, wheel selection
without click-through, guide, trigger, held-trigger repeat prevention and
disconnection. Physical controller hardware has not been tested here.

---

# Updated Arthur and Meera

Arthur and Meera now use the textured, rigged models supplied in Desktop/CWTCH/NPCS.
Their separate FBX animations are combined into assets/npcs/arthur.glb and meera.glb.
Walking, start-walk and left/right turn clips follow their roaming motion, with
quarter-second blends. Arthur uses Happy_Idle when resting; Meera holds the
beginning of her start-walk pose because no idle clip was supplied for her.
Root travel and yaw are removed from playback so smooth steering and collision
bodies remain authoritative. Walking playback follows the source stride speed.
Both remain 1.5 m tall and respect the Field Guide pause.

import_garden_npcs.py reproduces the GLBs in Blender from the supplied folder.
Validated animated leg bones, in-place motion, all imported clips, pause and
32 seconds of roaming with bounded turns and no NPC overlap. Both models and
textures were rendered and inspected in the garden.

---

# CWTCH — tool wheel and widescreen garden

The game uses a 1280 x 720 (16:9) canvas and preserves that aspect ratio when
resized. The interface uses rounded forest-green panels, warm gold accents and
clearer type. The bottom toolbar is removed.

## Controls

- WASD: glide through the garden. Mouse: look around.
- Tab: open/close the radial tool wheel. Move the pointer over a tool and click
  to equip it. The selection click does not also use the tool.
- Left-click: use the hovering tool on the spirit's current ground tile.
- 1 / 2 / 3: quick-equip hoe / seed packet / watering can.
- F or Esc: Field Guide, including save and return to the main menu.
- M: toggle garden ambience.

The hoe bounces down to turn grass into dirt. The seed packet flips upside down,
bounces and releases green particles to turn dirt into grass. The watering can
tips its spout down and pours blue particles, darkening and wetting the tile.
Watered ground gradually dries over 70 seconds; its remaining wetness is saved.
Tool effects occur during the animation. Movement pauses during a tool action,
and the Field Guide and tool wheel pause the action.

All three tools use the supplied Desktop/CWTCH/Tools models. Original copies
are retained in assets/tools/*_source.glb. optimize_tools.py creates textured
18,000-triangle game copies; bake_tool_icons.gd renders their wheel thumbnails.

Validation: aspect settings, radial selection without click-through, delayed
hoe impact, seed inversion and grass conversion, spout tilt and blue particles,
local watering, pause, cottage protection, menu transitions and save/resume.
The HUD, wheel, tool actions, Field Guide and menu were rendered for inspection.
Full source is collected in FULL_SOURCE.md. The notes below are development
history; this section supersedes earlier toolbar and crop controls.

---

# Smooth visitors, imported woodland and new animals

All seven garden NPCs now use CharacterBody3D collision bodies. Their facing
turns smoothly at a maximum 1.8 radians/second, with eased steering and reduced
walking speed through sharp turns. The facing pivot is independent of imported
animation root tracks. Tile reservations avoid choosing occupied destinations;
physical swept collisions prevent actors passing through one another. Blocked
actors pause and back out before choosing another step. The cottage also blocks
them. The invisible player controller is unchanged.

Both menu and garden forests now use ash.glb and birch.glb from the supplied
Desktop/CWTCH/Trees folder. Optimized textured copies contain 10,000 triangles
per model, reduced from approximately 1.96 and 1.71 million. Small MultiMesh
batches reuse them throughout the scenery. The full source models are retained
in assets/trees; optimize_trees.py reproduces the game copies using Blender.
There are 362 imported trees around the garden, with a separate menu forest.

Badger and Dragon now roam the garden and can be selected by the spirit. Their
procedural movement includes breathing, pauses and leg motions; the dragon also
moves its wings, head and tail. The dragon's missing joint rest transforms are
recovered from its inverse bind matrices. The badger's bind matrices contain
invalid values, so a small quadruped rig and feathered leg weights are rebuilt
while keeping its original mesh shape and textures. The Field Guide pauses both.

Validation: seven collision bodies; direct swept body collision; destination
reservation; bounded turn rate; 32 simulated seconds with no NPC overlap; both
animal rigs and pause behaviour; all menu/save/resume/new-garden checks. Rendered
and inspected both forests and close views of the badger and dragon.

# Fully 3D menu environment

The menu now uses a perspective camera and a complete mountain mesh with a
snowy summit and ridges on every side (178 m wide, 76 m tall, 144 m deep).
The mountain stands in rolling terrain with a pine forest, bank rocks and a
flowing stream. Seven birds have mesh bodies and animated wings and circle
through 3D space. A slow camera drift makes the scene depth visible. Lighting,
fog, weather, ambience and the existing menu/save functions remain active.

`menu_valley_3d.gd` builds the environment. `assets/menu_mountain.res` is the
standalone generated mountain mesh. The former illustrated mountain is no
longer instantiated. Older sections below describe superseded versions.
Validated the mountain dimensions, rendered front and side views, and checked
menu transitions, saving, resuming and new-garden reset.

# Illustrated mountain menu

The opening menu now follows the supplied CWTCH reference: a pale background,
a layered teal mountain with an angular snowy summit, bold amber-gold lettering
across the mountain, and the uppercase two-line tagline beneath it. Seven dark
swallows circle and flap around the summit; three small glints twinkle in fair
weather. The artwork is built from native polygon meshes, so its palette shifts
with the live day/night and weather cycle. Rain and lightning remain animated.
The three menu buttons, options, ambience and saved-garden behaviour are retained.

The illustrated backdrop replaces the previous cone-tree landscape in the menu.
The playable garden and its surrounding scenery remain as before.

# CWTCH � animated main menu and living weather

The launcher now opens `main_menu.tscn`: a real 3D scene with one large faceted
mountain, woodland, an animated stream and eleven circling, flapping birds.
The gold CWTCH title has a dark drop shadow, with �your slice of the valley.�
beneath it. The menu has its own day/night and weather clock: 20-minute days,
20-minute nights. Wind, bird calls, insects, stream, rain and thunder are original
synthesized sound effects generated by `generate_ambience.py`; there is no music.

- **enter garden** resumes saved terrain, crops, harvest count, player tile and
  garden clock/weather, or creates a garden if no save exists.
- **new garden** creates a fresh garden; replacing progress asks for confirmation.
- **options** offers master sound volume, fullscreen and a menu weather preview.
- In the garden, F/Esc opens the Field Guide, which includes **Save and return
  to main menu**. Returning to the menu or closing the window saves the garden.
  NPC positions/animation phases are not saved across launches.

The old pond is replaced by level grass. Rain puddles remain. Weather progresses
through Fair (180s), Cloudy (90s), Light rain (150s), Rain (150s), Heavy rain (120s),
Thunderstorm (90s), and Clearing (120s). Rain density, sound and haze vary with
intensity; storms add brief lightning with a delayed thunder rumble. The garden
Field Guide pauses weather and ambient sounds. M toggles garden ambience.

Saves and options use Godot's user directory under the launcher's local
`runtime/data` directory. No music is loaded or played; older source notes below
are historical and may describe superseded behaviour.

Validation: garden flattening, all weather stages, wetness, lightning and delayed
thunder, sound pause/mute, menu transitions, saved crops/harvest, and fresh-game
reset passed. Menu daylight/night, options and the rainy garden were rendered
and visually inspected.

# Cottage and hedgehog

The desktop cottage is placed beside the central garden at a six-metre width.
Its footprint blocks spirit movement, NPC wandering and planting. Aim at it
with the mouse to select it. The building is exterior scenery with no interior.

The desktop hedgehog is 35 cm long and roams dry, unplanted ground. It has no
usable animation clips, so its motion is procedural: a whole-body waddle,
gentle breathing and occasional sniffing pauses. The Field Guide pauses it.
The existing chicken and human visitors remain in the garden.
# Layered Welsh valley

The background now uses real faceted terrain: rolling wooded ridges at
24–68 metres and a separate mountain range at 78–196 metres, inspired by the
provided low-poly mountain reference. These layers create camera parallax.
637 pines and 325 broadleaf trees form woodland clusters. 577 fern, heather
and gorse clumps sit outside the editable plot and thicken toward the woods.
The playable garden, pond bed, NPCs and free camera remain intact; no fence
or 3D lawn grass has been reintroduced.

Height-weighted distance haze and 18 drifting, soft mist planes suggest mist
along the valley floor. This is a Compatibility-renderer approximation, not
Forward+ volumetric fog. Rain increases haze density and reduces visibility.
14 cloud planes drift on the existing game clock, with a procedural cloud
layer above them. Dawn and dusk tint the sky amber, rose and lavender; night
shifts it to indigo. The Field Guide pauses their motion with the game clock.
The environment remains lit by the moving sun and moon. The scenery is visual
background outside the garden and has no movement or selection colliders.
# Expanded garden

The playable plot is now 24 x 24 metres: 12 x 12 two-metre chunks and
36 x 36 gardening microtiles (1296 total). The original pond, prepared soil,
path and spawn points are grouped near the centre. New playable space is grass.

Outside the editable grid, four level terrain surfaces extend into a 512-metre
background meadow. A painted weight map blends broad grass, damp grass, soil
and stone patches with soft brush falloff. The inner margin matches the garden
surface; the surrounding scenery has no gardening cells or movement collision.
The playable floor remains level. The camera's far range is now 250 metres.
# Current visitor

The visitor is now desktop test.glb, using its native skeleton and ten built-in
animations. Arthur is no longer instantiated. Nine normal animations play in
shuffled order without immediate repeats: walking, four non-speaking idles,
talking, greeting, rejecting and kneeling. Walking moves the visitor around
dry garden cells; other actions stop movement. Shivering overrides normal
actions while rain intensity exceeds 15%, then random behavior resumes.

Each Idle_Talking entry chooses one of the three MP3 files copied from the
desktop audio folder. It avoids repeating the previous voice clip. The talking
animation loops for at least the voice clip's duration, with one voice at a
time. Speech comes from the visitor's location. Rain interrupts speech.
The Field Guide pauses speech, animation and behavior timers. The chicken,
quieter background music, textured floor and absence of 3D grass are retained.
Older notes below describe previous versions.
# Latest update

3D grass has been removed from the active scene. Ground textures remain.
Arthur replaces the original visitor and is labelled Arthur when selected.
The desktop file named arthur (without an extension) was copied as arthur.glb.
Its export has no animation, missing joint transforms and invalid inverse-bind
data. The visitor controller rebuilds a compatible Mixamo rest rig and adapts
the existing walk animation while retaining Arthur's mesh and textures.
Finger weights use their parent hand; the adapted animation is approximate.
The chicken remains unchanged. The original walking asset is retained solely
as a skeleton/animation source. Historical feature notes follow below.

# Current controls and scene

The stone perimeter has been removed, including its collision bodies. The camera
follows behind the spirit and aims freely with the mouse, including upward
toward the sky. A small centre dot aims object selection. F / Escape opens
the guide, pauses play and releases the mouse. WASD still moves the spirit
within the playable terrain. Older feature notes below describe earlier versions.

# Aberglen — Spirit Cursor

Double-click **Play Aberglen.cmd**. Godot 4.6.2 is included.

The spirit is the only visible player: twelve chunky, inward-pointing arrowheads
with yellow tops and red sides, inspired by the supplied reference. The ring
hovers around 10 cm above the ground, rotates slowly, and gently bobs.
The player has no humanoid model. A separate visitor wanders around the garden.

The perspective camera follows at 1.5 metres above the ground, looking down at
45 degrees toward the spirit. Its 75-degree field of view frames nearby terrain.

## Controls

- **WASD:** glide between grid squares relative to the camera.
- **Move the mouse:** freely aim the camera; no mouse button needed. F / Escape opens the guide and releases the pointer.
- **Q / E:** also orbit the camera.
- **Aim the centre dot at NPCs or crops:** the spirit ring glides to their feet and fits their size. Left-click crops to use the selected tool.
- **1–4 / wheel:** Hoe, Seeds, Water, Harvest.
- **Left click:** tend the spirit's selected ground once settled.
- **Tab:** one tile or a surrounding 3 x 3 patch.
- **F / Escape:** Field Guide and pause.
- **M:** toggle the requested background music.

Prepare earth, sow, water once, and harvest after twelve seconds. Raise six
turnips. Nothing withers. Progress lasts for the current session.

The level floor, POM, overcast sky, ambient occlusion, and music remain enabled.
FULL_SOURCE.md contains all code. Open project.godot to edit.

## Wandering visitor

The supplied Meshy GLB is included in assets. Its Walking animation loops while
the 1.5-metre visitor strolls at 0.48 metres per second, turning smoothly toward
random neighbouring tiles. It avoids water and planted tiles and pauses with
the Field Guide. It is decorative and does not block the spirit or tend crops.
The controller is wandering_npc.gd.

## Chicken and selection

The desktop chicken_rig.glb is included. The chicken walks at 0.30 m/s,
avoids water and crops, and pauses with the guide. Its supplied Idle animation
is supplemented with procedural hip and knee motion because the asset has no
walk clip. Mouse camera pitch is limited to 25–70 degrees and begins at 45.
The camera stays 1.5 m above the ground. Music plays at -18 dB.

selection_target.gd adds ray-selectable bounds to both NPCs and growing turnips.
Attach it to additional object roots to make future objects selectable. The
ring returns to the player's square when the pointer leaves an object. NPCs
are decorative; selecting one does not apply gardening tools to its ground.

## Cosy valley and stone boundary

cosy_sky.gdshader draws a seamless cloudy sky and two hazy valley ridges.
Warm directional light, gentle fog, ambient occlusion and softer grass colours
keep the garden welcoming. Existing POM still gives flat ground surface detail.
stone_wall.gdshader adds varied stone tones, fine grain and moss to three
staggered courses of low-poly stones. garden_wall.gd builds the wall outside
the playable cells with four continuous StaticBody3D collision boxes. The
player and NPC grid movement also remains constrained to the enclosed plot.


## Desktop texture sets

The textures folder from the desktop is copied into assets/textures.
Ground106 covers dirt and tinted hard dirt; Grass002 covers grass; Grass003
covers long/wet grass; Gravel040 covers paths; Rock062 covers rocky terrain
and the stone wall. Color, OpenGL normal, displacement, roughness and ambient
occlusion maps are used. Terrain maps are baked into five-layer 512px arrays
with mipmaps; original JPG files remain available. Run bake_desktop_textures.gd
with the graphical Godot executable to regenerate the arrays. Terrain height
is parallax only: floor geometry and collision remain level.


## Day, night and weather

The game begins at 06:00. Daytime (06:00–18:00) lasts 20 real minutes;
nighttime (18:00–06:00) also lasts 20 minutes. The upper-right clock displays
the day, 24-hour time and weather. Sun direction, shadows, sky colour, moonlight
and stars follow the clock. The Field Guide pauses time, weather and rain.

Weather repeats: Fair for 3 minutes, Cloudy for 2, Rain for 3, Clearing for 2.
The first rain arrives after 5 minutes of unpaused play. Transitions fade
gradually. Puddles collect in fixed patches during rain, then evaporate over
roughly 3 dry minutes; the level floor and collision do not change. Rain adds
ripples and dampens the terrain. Crops retain their existing watering controls.

The new desktop M_Water textures provide animated colour, normal, opacity and
roughness detail. M_RiverBottom colour and AO provide the bed under the pond
and shallow puddles. Water-lily files are included as source assets but no
lilies have been placed. Cycle state resets with each new play session.


## 3D grass

LivingGrass places instanced, tapered mesh blades on grass terrain only.
Short grass is 8–16 cm tall; long grass is 26–46 cm tall. Wind sways the tips
while roots stay fixed. Blades bend near the spirit, visitor and chicken,
and become darker and sway more strongly in rain. The Field Guide pauses
wind. Hoeing clears the matching patch immediately. Grass has no collision
or selection body, so it does not interfere with gardening or object aiming.


## Additional visitors: Arthur and Meera

arthur_anim.glb and meera_anim.glb are added alongside the existing visitor
and chicken. Arthur cycles fold_arms and walk. Meera cycles agree, fold_arms,
idle, wait and walk. Each non-walking clip plays fully, and walking repeats
four strides while the grid controller moves the character. Horizontal walk
root drift is removed from private animation copies; vertical movement stays.
Both characters pause with the Field Guide and have selectable named bounds.
Neither asset contains a talking or shiver clip, so those behaviors remain
with the original test.glb visitor. The new models use their native rigs.


## Sloping pond bed

The pond now has real geometry and matching collision, sloping smoothly from
the shoreline to a maximum depth of 0.9 metres. Land remains level. Terrain
uses 12 subdivisions per 2-metre chunk for smooth banks; gardening cells stay
the same size. The water surface remains level and uses depth-dependent
transparency so the textured bed is visible. The spirit follows the actual
pond floor continuously while entering and leaving water. NPCs still avoid
water. Rain puddles remain shallow surface effects. The pond bed is generated
from the starting water layout; gardening tools cannot change water tiles.

