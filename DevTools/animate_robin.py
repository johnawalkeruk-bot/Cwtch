"""Blender 5.1: rig the supplied robin and author reference-inspired actions.
Run: blender -b --python DevTools/animate_robin.py
Original FBX, texture and REF_MOTION videos are never modified.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Art/Robin'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.fbx(filepath=str(ROOT/'Animals/Robin/Robin.fbx'))
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
mesh.name='RobinMesh'
# Source is posed diagonally. Align the beak with Blender -Y / Godot +Z.
turn=Matrix.Rotation(math.radians(-45),4,'Z')
world=turn@mesh.matrix_world
for v in mesh.data.vertices:v.co=world@v.co
mesh.matrix_world=Matrix.Identity(4)
print('ALIGNED_BOUNDS',[(round(min(v.co[i] for v in mesh.data.vertices),3),round(max(v.co[i] for v in mesh.data.vertices),3)) for i in range(3)])
for mat in mesh.data.materials:
 if mat and mat.use_nodes:
  for node in mat.node_tree.nodes:
   if node.type=='TEX_IMAGE':node.image=bpy.data.images.load(str(ROOT/'Animals/Robin/Robin.fbm/Robin_basecolor.jpg'),check_existing=True)
   if node.type=='BSDF_PRINCIPLED':node.inputs['Roughness'].default_value=.88
arm=bpy.data.armatures.new('RobinSkeleton')
rig=bpy.data.objects.new('RobinRig',arm)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);mesh.select_set(False)
bpy.ops.object.mode_set(mode='EDIT')
specs=[('body',(0,0,.24),(0,0,.36),None),('head',(.035,-.23,.40),(.035,-.33,.52),'body'),('tail',(0,.13,.22),(0,.37,.13),'body')]
for sign,side in [(1,'L'),(-1,'R')]:
 specs.extend([(f'wing_{side}',(sign*.10,.005,.34),(sign*.31,.04,.51),'body'),(f'tip_{side}',(sign*.31,.04,.51),(sign*.63,.09,.76),f'wing_{side}'),(f'leg_{side}',(sign*.055,-.045,.19),(sign*.065,-.09,.055),'body'),(f'foot_{side}',(sign*.065,-.09,.055),(sign*.065,-.17,.02),f'leg_{side}')])
for name,head,tail,parent in specs:
 bone=arm.edit_bones.new(name);bone.head=head;bone.tail=tail
 if parent:bone.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
mesh.parent=rig
mod=mesh.modifiers.new('Robin deformation','ARMATURE');mod.object=rig
for bone in arm.bones:mesh.vertex_groups.new(name=bone.name)
def smooth(a,b,v):
 t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
counts={b.name:0 for b in arm.bones}
for vert in mesh.data.vertices:
 x,y,z=vert.co;side='L' if x>=0 else 'R';weights={'body':1.0}
 if z<.19 and y<.13:
  limb=1-smooth(.15,.205,z)
  foot=1-smooth(.045,.08,z)
  weights={'body':1-limb,f'leg_{side}':limb*(1-foot),f'foot_{side}':limb*foot}
 elif y<-.23 and z>.38 and abs(x)<.19:
  w=smooth(.34,.41,z);weights={'body':1-w,'head':w}
 elif abs(x)>.16 and z>.27:
  wing=smooth(.15,.24,abs(x))*smooth(.25,.34,z)
  tip=smooth(.27,.38,abs(x))
  weights={'body':1-wing,f'wing_{side}':wing*(1-tip),f'tip_{side}':wing*tip}
 elif y>.14:
  w=smooth(.12,.23,y);weights={'body':1-w,'tail':w}
 elif z>.35:
  w=smooth(.34,.41,z)*(1-smooth(.0,.10,y));weights={'body':1-w,'head':w}
 for name,w in weights.items():
  if w>.00001:mesh.vertex_groups[name].add([vert.index],w,'REPLACE');counts[name]+=1
assert all(counts.values()),counts
# Keep real-world bird size independent of the spread-wing bounding box.
rig.scale=(.43,)*3
scene=bpy.context.scene;scene.render.fps=24
rest={p.name:p.bone.matrix_local.to_quaternion() for p in rig.pose.bones}
for p in rig.pose.bones:p.rotation_mode='QUATERNION'
def rotate(name,axis,degrees):
 q=Quaternion(Vector(axis),math.radians(degrees));r=rest[name]
 rig.pose.bones[name].rotation_quaternion=r.inverted()@q@r

def pose(kind,t):
 for p in rig.pose.bones:p.location=(0,0,0);p.rotation_quaternion=(1,0,0,0);p.scale=(1,1,1)
 phase=math.tau*t
 flight=kind=='Flying'
 for sign,side in [(1,'L'),(-1,'R')]:
  if flight:
   # Sweep down strongly, with a softer recovery and delayed wrist feathers.
   rotate('wing_'+side,(0,1,0),sign*(25-48*math.cos(phase)))
   rotate('tip_'+side,(0,1,0),sign*14*math.sin(phase-.55))
   rotate('leg_'+side,(1,0,0),-38)
   rotate('foot_'+side,(1,0,0),25)
  else:
   # Fold the raised source wings back alongside the body, then close the wrist.
   q=Quaternion(Vector((0,0,1)),sign*math.radians(78))@Quaternion(Vector((0,1,0)),sign*math.radians(58))
   r=rest['wing_'+side];rig.pose.bones['wing_'+side].rotation_quaternion=r.inverted()@q@r
   rotate('tip_'+side,(0,1,0),sign*28)
 if kind=='Hopping':
  # Anticipation, both feet leaving the ground, then a short landing compression.
  lift=max(0,math.sin(math.pi*max(0,min(1,(t-.18)/.58))))*.115 if .18<t<.76 else 0
  crouch=-.018*math.sin(math.pi*t/.18) if t<.18 else (-.012*math.sin(math.pi*(t-.76)/.24) if t>.76 else 0)
  # Bone local Y is vertical for body.
  rig.pose.bones['body'].location.y=lift+crouch
  rotate('body',(1,0,0),3*math.sin(phase))
  rotate('head',(1,0,0),-3*math.sin(phase))
  rotate('tail',(1,0,0),8*math.sin(phase-.2))
  for side in ['L','R']:
   rotate('leg_'+side,(1,0,0),-22*lift/.115)
   rotate('foot_'+side,(1,0,0),18*lift/.115)
 elif flight:
  rig.pose.bones['body'].location.y=.012*math.sin(phase)
  rotate('body',(1,0,0),-5+2*math.sin(phase))
  rotate('head',(1,0,0),5-2*math.sin(phase))
  rotate('tail',(1,0,0),6*math.sin(phase-.5))
 else:
  rotate('head',(0,0,1),6*math.sin(phase))
  rotate('tail',(1,0,0),2*math.sin(phase))
  rig.pose.bones['body'].scale=(1+.006*math.sin(phase),1,1+.006*math.sin(phase))

actions={}
for name,frames in [('Idle',72),('Hopping',18),('Flying',12)]:
 rig.animation_data_clear()
 for f in range(frames+1):
  scene.frame_set(f+1);pose(name,f/frames)
  for p in rig.pose.bones:
   p.keyframe_insert('rotation_quaternion',frame=f+1,group=p.name)
   p.keyframe_insert('location',frame=f+1,group=p.name)
   p.keyframe_insert('scale',frame=f+1,group=p.name)
 action=rig.animation_data.action;action.name=name;action.use_fake_user=True
 action['reference']='REF_MOTION_'+('FLYING' if name=='Flying' else 'HOPPING')+'.mp4'
 action['description']='Hand-authored reference-inspired loop; not motion capture.'
 actions[name]=action
rig.animation_data.action=actions['Idle'];scene.frame_start=1;scene.frame_end=73;scene.frame_set(1)
# Remove source imports from the export selection; only the skinned robin travels.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Robin_Animated.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'Game/assets/animals/Robin/robin_animated.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_skins=True)
# Render actual deformation previews, with the final exported texture.
scene.world=bpy.data.worlds.new('PreviewWorld');scene.world.color=(.35,.35,.35)
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=800;scene.render.resolution_y=600;scene.render.resolution_percentage=100
bpy.ops.object.camera_add(location=(.7,-.7,.32));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.13))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=.62;scene.camera=cam
for pos,energy in [((1,-2,2),140),((-1,1,1),90)]:
 bpy.ops.object.light_add(type='AREA',location=pos);lamp=bpy.context.object;lamp.data.energy=energy;lamp.data.size=2;lamp.rotation_euler=(Vector((0,0,.1))-lamp.location).to_track_quat('-Z','Y').to_euler()
for name,frames in [('Idle',[1]),('Hopping',[4,10,17]),('Flying',[1,7])]:
 rig.animation_data.action=actions[name]
 for frame in frames:
  scene.frame_set(frame);scene.render.filepath=str(ROOT/'.local'/f'robin-{name}-{frame}.png');bpy.ops.render.render(write_still=True)
print('ROBIN_EXPORT_OK',counts)
