import bpy,json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
stage=Path('/Users/devendrashahithakuri/Work/gopala-assets/buildings/highlands-fantasy__CC0')
out=root/'game/assets/models/buildings/highlands';out.mkdir(parents=True,exist_ok=True)
report=[]
for folder,name,prefix in [('Hut','SM_Hut','T_Hut'),('MiscProps','SM_WoodCrate','T_Props'),('MiscProps','SM_Barrel','T_Props'),('MiscProps','SM_WoodFence','T_Props'),('MiscProps','SM_Axe','T_Props')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 source=stage/folder/(name+'.fbx');bpy.ops.import_scene.fbx(filepath=str(source))
 removed=[]
 for obj in list(bpy.data.objects):
  if obj.name.upper().startswith('UCX_'):
   removed.append(obj.name);bpy.data.objects.remove(obj,do_unlink=True)
 mat=bpy.data.materials.new(name+'Material');mat.use_nodes=True
 bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Metallic'].default_value=0;bsdf.inputs['Roughness'].default_value=0.85
 hashes={}
 for suffix,input_name in [('diffuse','Base Color'),('roughness','Roughness'),('normal','Normal')]:
  path=stage/folder/'TextureMaps'/(prefix+'_'+suffix+'.png')
  if not path.exists():continue
  hashes[str(path.relative_to(stage))]=hashlib.sha256(path.read_bytes()).hexdigest()
  img=bpy.data.images.load(str(out/path.name),check_existing=False)
  if suffix!='diffuse':img.colorspace_settings.name='Non-Color'
  img.pack()
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
  if suffix=='normal':
   normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs[input_name])
  else:mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs[input_name])
 objects=[o for o in bpy.data.objects if o.type=='MESH']
 for obj in objects:obj.data.materials.clear();obj.data.materials.append(mat)
 # Bake the FBX child transforms and combine meshes for predictable Godot bounds.
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.object.join();mesh=bpy.context.object
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
 tri=sum(len(p.vertices)-2 for p in mesh.data.polygons)
 report.append({'file':name+'.glb','triangles':tri,'source':str(source.relative_to(stage)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'removed_collision_objects':removed,'texture_source_sha256':hashes,'output_sha256':hashlib.sha256((out/(name+'.glb')).read_bytes()).hexdigest()})
(out/'conversion.json').write_text(json.dumps(report,indent=2)+'\n')
print('GOPALA_CONVERTED='+json.dumps(report))
