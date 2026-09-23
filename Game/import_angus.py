"""Run with Blender --background --python import_angus.py."""
import bpy
from pathlib import Path
source=Path(r'C:\Users\Shadow\OneDrive\Desktop\CWTCH\NPCS\Angus-McDoogal')
out=Path(__file__).resolve().parent/'assets'/'npcs'/'angus.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source/'Angus.fbx'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
rig.animation_data.action.name='Angus_Performance'
for image in bpy.data.images:
 if image.source=='FILE': image.pack()
for material in bpy.data.materials:
 if material.use_nodes:
  shader=material.node_tree.nodes.get('Principled BSDF')
  if shader: shader.inputs['Roughness'].default_value=.85
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
print('EXPORTED',out)
