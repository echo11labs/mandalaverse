"""Blender CLI: local game-use conversion; output MUST remain gitignored."""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Quaternion
root=Path(__file__).resolve().parents[1]
stage=Path.home()/'Work/gopala-assets/characters/craftpix-medieval-people__LOCAL-ONLY'
out=root/'game/assets/models/local_villagers';out.mkdir(parents=True,exist_ok=True)
report=[]
for name in ['peasant_4','peasant_5','peasant_1','peasant_2','peasant_3','peasant_6']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 source=stage/'fbx/people_unity'/(name+'.fbx');bpy.ops.import_scene.fbx(filepath=str(source))
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 mesh=next(o for o in bpy.data.objects if o.type=='MESH')
 img=bpy.data.images.load(str(stage/'texture/people_texture_map.png'),check_existing=False)
 if max(img.size)>1024:img.scale(1024,1024)
 img.pack()
 mat=bpy.data.materials.new('VillagerAtlas');mat.use_nodes=True
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
 bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=0.9
 mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);mesh.data.materials.clear();mesh.data.materials.append(mat)
 bones=rig.pose.bones;up=(bones['Head'].head-bones['Pelvis'].head).normalized();right=(bones['Thigh_R'].head-bones['Thigh_L'].head).normalized()
 neutral={}
 for bone in bones:
  bone.rotation_mode='QUATERNION';neutral[bone.name]=Quaternion()
 for side in ['L','R']:
  bone=bones['Upperarm_'+side];direction=(bone.tail-bone.head).normalized();target=(-up+direction*0.12).normalized()
  q=direction.rotation_difference(target);basis=bone.bone.matrix_local.to_quaternion()
  neutral[bone.name]=basis.inverted()@q@basis
 def rotation(name,angle):
  basis=bones[name].bone.matrix_local.to_quaternion()
  return neutral[name]@(basis.inverted()@Quaternion(right,angle)@basis)
 for action_name in ['static','idle','walk','pick-up']:
  if rig.animation_data is None:rig.animation_data_create()
  rig.animation_data.action=bpy.data.actions.new(action_name)
  frames=[1,31] if action_name=='static' else list(range(1,32,5))+[31]
  for frame in frames:
   phase=(frame-1)/30*math.tau
   for bone in bones:bone.rotation_quaternion=neutral[bone.name]
   if action_name=='walk':
    for side,sign in [('L',1),('R',-1)]:
     bones['Thigh_'+side].rotation_quaternion=rotation('Thigh_'+side,sign*math.sin(phase)*0.38)
     bones['Calf_'+side].rotation_quaternion=rotation('Calf_'+side,max(0,-sign*math.sin(phase))*0.45)
     bones['Upperarm_'+side].rotation_quaternion=rotation('Upperarm_'+side,-sign*math.sin(phase)*0.22)
   elif action_name=='pick-up':
    bend=math.sin((frame-1)/30*math.pi)*0.5
    bones['Spine_01'].rotation_quaternion=rotation('Spine_01',bend)
    for side in ['L','R']:bones['Upperarm_'+side].rotation_quaternion=rotation('Upperarm_'+side,0.65*bend)
   elif action_name=='idle':bones['Spine_02'].rotation_quaternion=rotation('Spine_02',math.sin(phase)*0.008)
   for bone in bones:bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
  track=rig.animation_data.nla_tracks.new();track.name=action_name
  track.strips.new(action_name,1,rig.animation_data.action);rig.animation_data.action=None
 bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=31;bpy.context.scene.render.fps=30
 bpy.context.scene.frame_set(1)
 bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS')
 report.append({'model':name+'.glb','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256((out/(name+'.glb')).read_bytes()).hexdigest(),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'licence':'Craftpix freebie, local game use only; source redistribution excluded','animation':'Original project-authored idle, walk and pickup on downloaded rig; no root motion'})
(out/'RECEIPT.json').write_text(json.dumps(report,indent=2)+'\n')
(out/'RECEIPT.json.import').write_text('[remap]\nimporter="keep"\n')
print('LOCAL_VILLAGERS='+json.dumps(report))
