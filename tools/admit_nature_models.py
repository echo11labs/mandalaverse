import json,struct,hashlib,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
stage=Path('/Users/devendrashahithakuri/Work/gopala-assets')
source=stage/'nature/kaykit-forest-nature__CC0/KayKit_Forest_Nature_Pack_1.0_FREE'
out=root/'game/assets/models/nature/kaykit';out.mkdir(parents=True,exist_ok=True)
selected=['Tree_1_A','Tree_1_B','Tree_2_A','Tree_2_B','Tree_3_A','Tree_3_B','Tree_4_A','Tree_4_B','Bush_1_A','Bush_2_A','Grass_1_A','Rock_1_A','Rock_3_A']
source_hash={}
for name in selected:
 p=source/'Assets/gltf'/(name+'_Color1.gltf');r=json.loads(p.read_text());blob=bytearray()
 assert len(r['buffers'])==1
 b=p.parent/r['buffers'][0].pop('uri');blob.extend(b.read_bytes());source_hash[str(p.relative_to(source))]=hashlib.sha256(p.read_bytes()).hexdigest();source_hash[str(b.relative_to(source))]=hashlib.sha256(b.read_bytes()).hexdigest()
 for image in r.get('images',[]):
  f=p.parent/image.pop('uri');source_hash[str(f.relative_to(source))]=hashlib.sha256(f.read_bytes()).hexdigest()
  while len(blob)%4:blob.append(0)
  image['bufferView']=len(r.setdefault('bufferViews',[]));r['bufferViews'].append({'buffer':0,'byteOffset':len(blob),'byteLength':f.stat().st_size});blob.extend(f.read_bytes())
 r['buffers'][0]['byteLength']=len(blob)
 while len(blob)%4:blob.append(0)
 js=json.dumps(r,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
 data=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(blob))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(blob),0x004e4942)+blob
 (out/(name+'.glb')).write_bytes(data)
shutil.copy2(source/'License.txt',out/'LICENSE.txt')
config=json.loads((root/'game/data/forest/models.json').read_text());mapping=['Tree_2_A','Tree_2_B','Tree_2_B','Tree_2_A','Tree_2_B','Tree_2_A','Tree_1_A','Tree_1_B','Tree_3_A','Tree_3_B','Tree_4_A','Tree_4_B','Tree_3_B','Tree_4_A','Tree_4_B','Tree_1_B']
models={}
for v,name in zip(config['variants'],mapping):
 v['path']='res://assets/models/nature/kaykit/'+name+'.glb';models[v['id']]={'surfaces':1,'model':name+'.glb'}
config['source_pack']='KayKit Forest Nature 1.0 (CC0, Kay Lousberg)'
(root/'game/data/forest/models.json').write_text(json.dumps(config,indent=2)+'\n')
receipt={'license':'CC0-1.0','license_file':'LICENSE.txt','source_url':'https://kaylousberg.itch.io/kaykit-forest','date':'2026-10-08','changes':'Repacked original glTF, buffers and 1024px palette image into GLB without geometry or material changes. Runtime normalizes transformed bounds to existing metre profiles.','models':models,'source_sha256':source_hash,'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.iterdir()) if p.suffix in ['.glb','.txt']}}
(out/'source-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');(out/'source-receipt.json.import').write_text('[remap]\nimporter="keep"\n')
(out/'RECEIPT.md').write_text('# KayKit Forest Nature\n\nSource: https://kaylousberg.itch.io/kaykit-forest. Kay Lousberg, CC0-1.0; downloaded staging pack, admitted 2026-10-08. Selected models only, original geometry and shared 1024px atlas. Original glTF/bin/PNG repacked losslessly into self-contained GLB. No density, seed, spacing or gameplay changes. Source and output hashes plus the sixteen-variant map are in source-receipt.json. Sizes and bottom-centre anchors are normalized at runtime through the world-scale standard.\n')
cowout=root/'game/assets/models/animals/styloo';cowout.mkdir(parents=True,exist_ok=True)
cow=stage/'animals/styloo-animals__CC0/stylooanimalassetpack/glb/Cow.glb';shutil.copy2(cow,cowout/'Cow.glb')
(cowout/'LICENSE.txt').write_text('Styloo Animals — Creative Commons Zero (CC0-1.0)\nPublisher declares CC0 at https://styloo.itch.io/animals\nCreative Commons legal code: https://creativecommons.org/publicdomain/zero/1.0/legalcode\nVerified in the coordinator ASSET_CATALOG and approved G1-11 map.\n')
(cowout/'RECEIPT.md').write_text('# Styloo Cow\n\nSource: https://styloo.itch.io/animals; author Styloo; CC0-1.0 per publisher. Admitted 2026-10-08 from the downloaded staging library. Only Cow.glb copied, unchanged; three embedded 1024px maps. Original iddle/walk animations retained. Runtime fits child-transformed bounds to the cattle metre profile and observes herd movement/paused state without simulation changes.\n\nSHA-256: '+hashlib.sha256(cow.read_bytes()).hexdigest()+'\n')
print('Admitted',len(selected),'nature models and unchanged cow')
