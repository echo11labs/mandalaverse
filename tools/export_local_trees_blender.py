"""Run with Blender --background --factory-startup --python this_file."""
import bpy, json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[1]/'game/assets/models/local_nature'
SOURCE=OUT/'source'
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, image, leaves=False):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=0.9
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(SOURCE/image),check_existing=True)
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    if leaves:m.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha']);m.surface_render_method='DITHERED';m.use_backface_culling=False
    return m

def export(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    # Bake child/object transforms, anchor at bottom-centre, export Y-up glTF.
    coords=[o.matrix_world@v.co for v in o.data.vertices]
    bottom=Vector(((min(v.x for v in coords)+max(v.x for v in coords))/2,(min(v.y for v in coords)+max(v.y for v in coords))/2,min(v.z for v in coords)))
    for v,co in zip(o.data.vertices,coords):v.co=co-bottom
    o.matrix_world.identity()
    bpy.ops.export_scene.gltf(filepath=str(OUT/(o.name+'.glb')),export_format='GLB',use_selection=True,export_materials='EXPORT',export_animations=False)

bpy.ops.import_scene.fbx(filepath=str(SOURCE/'Vegetation.fbx'))
selected=['Tree_03','Tree_04','Tree_05']
for name in selected:
    o=bpy.data.objects[name+'_V']
    bpy.data.objects[name].name=name+'_Unused'
    o.name=name
    for i,m in enumerate(o.data.materials):
        leaves=m.name.startswith('Branch')
        o.data.materials[i]=material(m.name+'_Local',m.name+'.png',leaves)
    export(o)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bark=material('Forest bark','forest-bark.png')
leaves=material('Forest needles','forest-leaves.png',True)
for r in json.loads((SOURCE/'unity-meshes.json').read_text()):
    mesh=bpy.data.meshes.new(r['name']);mesh.from_pydata(r['vertices'],[],r['faces']);mesh.update()
    mesh.materials.append(bark);mesh.materials.append(leaves)
    uv=mesh.uv_layers.new(name='UVMap')
    for p,mat in zip(mesh.polygons,r['materials']):
        p.material_index=mat;p.use_smooth=True
        for li in p.loop_indices:uv.data[li].uv=r['uv'][mesh.loops[li].vertex_index]
    o=bpy.data.objects.new(r['name'],mesh);bpy.context.collection.objects.link(o);export(o)
# glTF's alpha MASK gives foliage depth and cutout shadows; no translucent sorting.
import struct,hashlib
for p in OUT.glob('*.glb'):
    data=p.read_bytes();n=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+n]);blob=data[28+n:]
    for m in doc.get('materials',[]):
        if 'Branch' in m.get('name','') or 'needles' in m.get('name',''):
            m['alphaMode']='MASK';m['alphaCutoff']=0.4;m['doubleSided']=True
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
    p.write_bytes(struct.pack('<III',0x46546c67,2,28+len(js)+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob)
r=json.loads((OUT/'source-receipt.json').read_text());r['files']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.glb')};(OUT/'source-receipt.json').write_text(json.dumps(r,indent=2)+'\n')
variants={
 'Fir_Tall_A':'Forest_Tall','Fir_Tall_B':'Forest_Medium','Fir_Young_C':'Forest_Small',
 'Pine_Open_A':'Forest_Tall','Pine_Open_B':'Forest_Small','Pine_Dense_C':'Forest_Medium',
 'Broad_Oak_A':'Tree_04','Broad_Oak_B':'Tree_05','Broad_Oak_C':'Tree_03','Broad_Oak_D':'Tree_04',
 'Broad_Round_A':'Tree_05','Broad_Round_B':'Tree_03','Broad_Round_C':'Tree_04'}
(OUT/'variants.json').write_text(json.dumps({k:'res://assets/models/local_nature/'+v+'.glb' for k,v in variants.items()},indent=2)+'\n')

for name in ['variants.json','source-receipt.json']:
    (OUT/(name+'.import')).write_text('[remap]\nimporter="keep"\n')

# Keep textures inside each imported scene: no generated external PNG/UID dependency.
for model in OUT.glob('*.glb'):
    settings=OUT/(model.name+'.import')
    if settings.exists():
        text=settings.read_text()
        import re
        text=re.sub(r'gltf/embedded_image_handling=\d+', 'gltf/embedded_image_handling=3', text)
    else:
        text='[remap]\nimporter="scene"\n\n[params]\ngltf/embedded_image_handling=3\n'
    settings.write_text(text)
