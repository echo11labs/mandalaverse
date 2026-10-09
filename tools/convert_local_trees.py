"""Prepare the three user-supplied archives for local tree use; no redistribution grant."""
from pathlib import Path
import hashlib, io, json, re, struct, zipfile
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/models/local_nature'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE=OUT/'source'
SOURCE.mkdir(exist_ok=True)
(SOURCE/'.gdignore').touch()

def png(data, name, alpha=False):
    # Photoshop TIFF's fourth channel is tagged unspecified. Preserve it as alpha.
    b = bytearray(data)
    if alpha:
        endian = '<' if b[:2] == b'II' else '>'
        pos = struct.unpack_from(endian+'I', b, 4)[0]
        for i in range(struct.unpack_from(endian+'H', b, pos)[0]):
            entry = pos + 2 + i*12
            if struct.unpack_from(endian+'H', b, entry)[0] == 338:
                struct.pack_into(endian+'H', b, entry+8, 2)
    im = Image.open(io.BytesIO(b)).convert('RGBA' if alpha else 'RGB')
    im.thumbnail((1024,1024), Image.Resampling.LANCZOS)
    im.save(SOURCE/name)

z = zipfile.ZipFile(ROOT/'Resources/Forest Scene.zip')
textures = {'forest-bark.png':'Conifer Trunk [Albedo] [Smoothness].tif',
            'forest-leaves.png':'Conifer  Branches [Albedo] [Smoothness].tif'}
for out, suffix in textures.items():
    source = next(n for n in z.namelist() if n.endswith(suffix))
    png(z.read(source),out,out=='forest-leaves.png')
meshes = []
for name in ['Small','Medium','Tall']:
    source = next(n for n in z.namelist() if n.endswith(f'Conifer {name} LOD1.asset'))
    s = z.read(source).decode()
    channels = re.findall(r'- stream: (\d+)\s+offset: (\d+)\s+format: (\d+)\s+dimension: (\d+)',s)
    assert all(int(c[0])==0 and int(c[2])==0 for c in channels if int(c[3]))
    stride = max(int(c[1])+4*int(c[3]) for c in channels)
    vcount = int(re.search(r'm_VertexCount: (\d+)',s)[1])
    data = bytes.fromhex(re.search(r'_typelessdata: ([0-9a-fA-F]+)',s)[1])
    indices = bytes.fromhex(re.search(r'm_IndexBuffer: ([0-9a-fA-F]+)',s)[1])
    assert len(data)==vcount*stride
    def attr(channel):
        _,offset,_,dim=map(int,channels[channel]);return [list(struct.unpack_from('<'+'f'*dim,data,i*stride+offset)) for i in range(vcount)]
    sub = re.findall(r'firstByte: (\d+)\s+indexCount: (\d+).*?baseVertex: (\d+)',s,re.S)
    faces=[]; materials=[]
    for mat,(first,count,base) in enumerate(sub):
        ids=struct.unpack_from('<'+'H'*int(count),indices,int(first))
        for i in range(0,len(ids),3):faces.append([int(base)+ids[i],int(base)+ids[i+2],int(base)+ids[i+1]]);materials.append(mat)
    meshes.append({'name':'Forest_'+name,'vertices':[[x,z,y] for x,y,z in attr(0)],'uv':attr(4),'faces':faces,'materials':materials,'source':source})
(SOURCE/'unity-meshes.json').write_text(json.dumps(meshes))
vz=zipfile.ZipFile(ROOT/'Resources/Vegetation.zip')
for n in vz.namelist():
    if n.endswith('Vegetation.fbx'):(SOURCE/'Vegetation.fbx').write_bytes(vz.read(n))
    elif '/Textures/' in n and n.endswith('.png') and Path(n).stem in ['BarkDecidious','Branch_T','Branch_T2','Branch','Branch_T_01','Branch_T2_01']:
        im=Image.open(io.BytesIO(vz.read(n))).convert('RGBA');im.thumbnail((1024,1024));im.save(SOURCE/Path(n).name)
receipt={'scope':'Local-only user-requested trees. Vegetation licence unknown; Forest Scene redistribution unverified. KayKit CC0 is tracked fallback.', 'archives':{name:hashlib.sha256((ROOT/'Resources'/name).read_bytes()).hexdigest() for name in ['Vegetation.zip','KayKit_Forest_Nature_Pack_1.0_FREE.zip','Forest Scene.zip']},'forest_lod':'LOD1','textures_max_px':1024}
(OUT/'source-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('Prepared',len(meshes),'Unity meshes and selected Vegetation textures')
