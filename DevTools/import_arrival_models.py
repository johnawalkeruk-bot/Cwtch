"""Convert supplied arrival FBX models without modifying originals."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
for category,name in [('Animals','Rabbit'),('Animals','Bull'),('Decor','Rock')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 source=ROOT/category/name
 bpy.ops.import_scene.fbx(filepath=str(source/(name+'.fbx')))
 images=list(source.rglob('*.jpg'))
 if images:
  material=bpy.data.materials.new(name+'Surface')
  material.use_nodes=True
  shader=material.node_tree.nodes.get('Principled BSDF')
  shader.inputs['Roughness'].default_value=.92
  texture=material.node_tree.nodes.new('ShaderNodeTexImage')
  texture.image=bpy.data.images.load(str(images[0]),check_existing=True)
  material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
  for obj in bpy.context.scene.objects:
   if obj.type=='MESH':
    obj.data.materials.clear()
    obj.data.materials.append(material)
 if name=='Rock':
  for obj in bpy.context.scene.objects:
   if obj.type=='MESH' and len(obj.data.polygons)>20000:
    bpy.context.view_layer.objects.active=obj
    decimate=obj.modifiers.new('Game rock detail','DECIMATE')
    decimate.ratio=12000.0/len(obj.data.polygons)
    bpy.ops.object.modifier_apply(modifier=decimate.name)
 print('ASSET',name,[(o.name,o.type,tuple(o.dimensions)) for o in bpy.context.scene.objects], 'ACTIONS',[a.name for a in bpy.data.actions])
 target=ROOT/'Game/assets/arrival';target.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(target/(name.lower()+'.glb')),export_format='GLB',export_animations=True)
