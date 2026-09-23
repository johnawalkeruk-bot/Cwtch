"""Combine the supplied NPC FBX clips and textures into portable Godot GLBs.
Run with Blender --background --python import_garden_npcs.py.
"""
import bpy
from pathlib import Path
SOURCE = Path(r'C:\Users\Shadow\OneDrive\Desktop\CWTCH\NPCS')
OUTPUT = Path(__file__).resolve().parent / 'assets' / 'npcs'
OUTPUT.mkdir(parents=True, exist_ok=True)
for name in ('Arthur', 'Meera'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    folder = SOURCE / name
    bpy.ops.import_scene.fbx(filepath=str(folder / (name + '_Walking.fbx')))
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    actions = [('Walking', rig.animation_data.action)]
    rig.animation_data.action = None
    for path in sorted(folder.glob(name + '_*.fbx')):
        if path.stem.endswith('_Walking'): continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(path))
        imported = set(bpy.data.objects) - before
        donor = next(o for o in imported if o.type == 'ARMATURE')
        assert set(rig.data.bones.keys()) == set(donor.data.bones.keys()), path
        action = donor.animation_data.action
        action.use_fake_user = True
        actions.append((path.stem[len(name)+1:], action))
        for obj in imported: bpy.data.objects.remove(obj, do_unlink=True)
    texture = bpy.data.images.load(str(next(folder.glob('*.jpg'))))
    texture.pack()
    material = bpy.data.materials.new(name + ' Clothing')
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .86
    image = material.node_tree.nodes.new('ShaderNodeTexImage')
    image.image = texture
    material.node_tree.links.new(image.outputs['Color'], bsdf.inputs['Base Color'])
    for mesh in meshes:
        mesh.data.materials.clear()
        mesh.data.materials.append(material)
    for label, action in actions:
        action.name = label
        track = rig.animation_data.nla_tracks.new()
        track.name = label
        strip = track.strips.new(label, 1, action)
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (name.lower() + '.glb')),
        export_format='GLB', export_animation_mode='NLA_TRACKS',
        export_anim_slide_to_zero=True, export_force_sampling=True)
    print('EXPORTED', name, [label for label, _ in actions])
