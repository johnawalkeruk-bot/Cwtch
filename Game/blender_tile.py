import bpy
from pathlib import Path

# Save the .blend first to choose the export folder; otherwise use Blender's temp.
folder = Path(bpy.path.abspath("//")) if bpy.data.filepath else Path(bpy.app.tempdir)
target = folder / "ground_tile.glb"
name = "AberglenGroundTile"
old = bpy.data.objects.get(name)
if old:
    bpy.data.objects.remove(old, do_unlink=True)

bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1.0
# Blender XY ground becomes Godot XZ ground through glTF's Y-up conversion.
# Sixteen vertices, nine quads; origin at the center of the surface.
vertices = [(x * 2.0 / 3.0 - 1.0, y * 2.0 / 3.0 - 1.0, 0.0)
            for y in range(4) for x in range(4)]
faces = []
for y in range(3):
    for x in range(3):
        i = y * 4 + x
        faces.append((i, i + 1, i + 5, i + 4))
mesh = bpy.data.meshes.new(name + "Mesh")
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name="UVMap")
for polygon in mesh.polygons:
    polygon.use_smooth = False
    for loop_index in polygon.loop_indices:
        co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
        uv.data[loop_index].uv = ((co.x + 1.0) / 2.0, (co.y + 1.0) / 2.0)
tile = bpy.data.objects.new(name, mesh)
bpy.context.collection.objects.link(tile)
for obj in bpy.context.selected_objects:
    obj.select_set(False)
tile.select_set(True)
bpy.context.view_layer.objects.active = tile
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
                          use_selection=True, export_yup=True,
                          export_animations=False)
print(f"Exported 2m x 2m ground tile: {target}")
