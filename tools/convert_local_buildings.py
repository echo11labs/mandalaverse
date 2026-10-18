"""Blender CLI: selected Craftpix houses for local game use; outputs stay gitignored."""
import bpy
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "Resources/free-medieval-houses-3d-low-poly-pack.zip"
OUT = ROOT / "game/assets/models/local_buildings"
STAGE = ROOT / "reports/building-refresh/source-stage"
SELECTED = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
OUT.mkdir(parents=True, exist_ok=True)
STAGE.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(ARCHIVE) as archive:
    texture = archive.read("Texture/House_texture_atlas.png")
    (STAGE / "atlas.png").write_bytes(texture)
    license_text = archive.read("License.txt")
    sources = [n for n in archive.namelist() if n.startswith("fbx/House_Full_ordinar/") and n.lower().endswith(".fbx")]
    reports = []
    for number in SELECTED:
        source_name = next(n for n in sources if Path(n).name.lower() == "house_%02d_full.fbx" % number)
        raw = archive.read(source_name)
        source = STAGE / Path(source_name).name
        source.write_bytes(raw)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(source))
        for obj in list(bpy.data.objects):
            if obj.type != 'MESH' or obj.name.upper().startswith(('UCX_', 'UBX_')):
                bpy.data.objects.remove(obj, do_unlink=True)
        image = bpy.data.images.load(str(STAGE / "atlas.png"), check_existing=False)
        if max(image.size) > 1024: image.scale(1024, 1024)
        image.pack()
        mat = bpy.data.materials.new('HouseAtlas')
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Roughness'].default_value = 0.9
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = image
        mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        objects = list(bpy.data.objects)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.data.materials.clear(); obj.data.materials.append(mat); obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        mesh = bpy.context.object
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        target = OUT / ('house_%02d.glb' % number)
        bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', use_selection=True, export_animations=False)
        reports.append({'model':target.name,'source':source_name,'source_sha256':hashlib.sha256(raw).hexdigest(),'output_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'source_dimensions':list(mesh.dimensions)})
receipt = {'date':'2026-10-12','source_archive':str(ARCHIVE.relative_to(ROOT)),'archive_sha256':hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(),'texture_sha256':hashlib.sha256(texture).hexdigest(),'license_url':'https://craftpix.net/file-licenses/','license_checked':'2026-10-12','distribution':'Local game-use models; excluded from source distribution. Public runtime retains CC0 model fallback.','conversion':'Mesh child transforms baked, source UV retained, source atlas resized to 1024px and embedded, no collision geometry admitted.','models':reports}
(OUT/'RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
(OUT/'LICENSE.txt').write_bytes(license_text)
print('GOPALA_BUILDING_CONVERSION='+json.dumps(receipt))
