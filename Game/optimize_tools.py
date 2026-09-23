import bpy
from pathlib import Path
root=Path(__file__).resolve().parent/'assets'/'tools'
for name in ['hoe','seeds','water']:
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(root/(name+'_source.glb')))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 total=sum(len(o.data.polygons) for o in meshes)
 for obj in meshes:
  bpy.context.view_layer.objects.active=obj
  modifier=obj.modifiers.new('Tool detail','DECIMATE')
  modifier.ratio=min(1.0,18000.0/total)
  bpy.ops.object.modifier_apply(modifier=modifier.name)
 bpy.ops.export_scene.gltf(filepath=str(root/(name+'.glb')),export_format='GLB',export_animations=False)
 print('TOOL',name,total,'to',sum(len(o.data.polygons) for o in meshes),flush=True)
