# Level terrain, parallax relief, and an overcast Welsh sky

The running scene uses a flat Y=0 floor, including the ground under water.
All floor vertices, collision surfaces, and crop positions are level. The camera
now follows the player at 1.5 metres above the floor, angled downward at 45 degrees.
The spirit selection ring is the only visible player and hovers 10 cm above the floor. Water remains
a surface treatment 1.2 cm above the floor; deep/shallow water describes appearance.

## POM on the shared terrain

terrain.gdshader ray-marches a height texture with 12–48 steps, then interpolates
the intersection. Albedo and normal detail use the same shifted coordinates.
The four channels in the generated texture are R=dirt, G=grass, B=stone, A=path.
Terrain IDs select and blend these channels. Sampling uses diorama coordinates,
so chunks connect without UV seams. Explicit texture gradients keep mipmapping
stable inside the ray-march loop. Near-horizontal views fade the parallax offset.

- relief_metres: 0.008 means 8 mm of apparent relief.
- repeats_per_metre: 4 gives a 25 cm texture repeat.
- pom_enabled: turn this off for a before/after comparison.

POM changes apparent surface depth, not geometry, silhouettes, or collisions.
It does not supply self-shadowing. The shared shader currently targets flat
horizontal ground in this scene's local coordinates.

## StandardMaterial3D setup for separately textured objects

Use pom_material.gd's create_standard() with aligned albedo, OpenGL normal,
height, and optionally roughness textures. Assign its returned material to
MeshInstance3D.material_override. In the Inspector the equivalent settings are:

1. Albedo / Texture: the color map.
2. Normal Map / Enabled: on; assign the normal map.
3. Height / Enabled: on; assign a grayscale height map.
4. Height / Deep Parallax: on.
5. Height / Scale: start at 0.8 (approximately 8 mm with the default mapping).
6. Height / Min Layers: 12; Max Layers: 48.
7. UV1 / Triplanar: off. Use valid mesh UVs and tangents.
8. Enable mipmapped anisotropic filtering and repeat for tileable maps.

White is high, black is low. Treat height, normal, and roughness maps as linear
data, not sRGB color. The packed RGBA terrain texture is for the custom shader;
use the appropriate single grayscale channel for a StandardMaterial3D texture.

## Procedural sky

welsh_sky.gd's apply(world, sun) assigns a new Environment to the passed
WorldEnvironment. It creates a ProceduralSkyMaterial and generates its
equirectangular cloud cover by sampling 3D noise on a sphere. This gives a
continuous longitude seam and consistent poles. The colors are slate grey above
and pale, misty grey at the horizon. Sky lighting, a muted directional light,
and non-volumetric fog create the overcast atmosphere. Screen-space ambient
occlusion adds soft contact shading; this uses Godot 4.6's Compatibility support.
The sky uses its own 70-degree field of view to avoid orthographic sky distortion.

The garden calls it using the WorldEnvironment and DirectionalLight3D created
by the base scene. Avoid adding a second WorldEnvironment to the same scene.
The cloud cover is static and stylistic, not a weather simulation.

## Complete source

FULL_SOURCE.md includes all project scripts, shaders, scene settings, and the
launcher without omissions. The two reusable components are pom_material.gd and
welsh_sky.gd. The current scene uses the shared terrain shader to retain blending;
the StandardMaterial3D factory is provided for independent material assignments.

Verified in Godot 4.6.2 Compatibility: rendering changes when POM is toggled,
all ground mesh vertices are at Y=0, all 81 downward collision rays hit Y=0,
all four height channels contain relief, cloud panorama edges match, the sky and
fog are assigned, water traversal works, and the harvest loop and music work.

References:
- https://docs.godotengine.org/en/4.6/classes/class_basematerial3d.html
- https://docs.godotengine.org/en/4.6/classes/class_proceduralskymaterial.html
- https://docs.godotengine.org/en/4.6/classes/class_environment.html
