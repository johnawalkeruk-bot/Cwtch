"""Run with Blender --background --python Game/import_robin.py to rebuild the supplied robin asset."""
import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root/'Animals/Robin/Robin.fbx'))
print('OBJECTS',[(o.name,o.type) for o in bpy.context.scene.objects])
print('ANIMATIONS',[(a.name,list(a.frame_range)) for a in bpy.data.actions])
for o in bpy.context.scene.objects:
 if o.type=='ARMATURE':print('BONES',list(o.data.bones.keys()))
texture=bpy.data.images.load(str(root/'Animals/Robin/Robin.fbm/Robin_basecolor.jpg'))
texture.pack()
material=bpy.data.materials.new('Robin Plumage');material.use_nodes=True
bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=0.9
node=material.node_tree.nodes.new('ShaderNodeTexImage');node.image=texture
material.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
for o in bpy.context.scene.objects:
 if o.type=='MESH':o.data.materials.clear();o.data.materials.append(material)
out=root/'Game/assets/animals/Robin';out.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out/'robin.glb'),export_format='GLB',export_animations=True)
