#!/usr/bin/env python3
"""Convert UE Viewer PSA exports using recovered cooked skeletons, not PSA placeholder parents.
Outputs remain attributed third-party references. No Tidebreak rig retargeting is implied.
UE Viewer coordinate handling: undo ActorX Y/W reflection, then its glTF Y/Z conversion.
"""
import argparse,hashlib,json,struct,re
from pathlib import Path
import numpy as np

def chunks(path):
 d=path.read_bytes();out={};at=0
 while at<len(d):
  tag,_,size,count=struct.unpack_from('<20siii',d,at);at+=32;assert at+size*count<=len(d)
  out[tag.rstrip(b'\0').decode()]=(size,count,d[at:at+size*count]);at+=size*count
 assert at==len(d)
 return out

def rests(path):
 out={};name=None;bones=[]
 for line in path.read_text().splitlines():
  if line.startswith('REST_BEGIN|'):name=line.split('|',1)[1];bones=[]
  elif line.startswith('REST_BONE|'):
   _,n,p,t,q,s=line.split('|');bones.append(dict(name=n,parent=int(p),translation=list(map(float,t.split(','))),rotation=list(map(float,q.split(','))),scale=list(map(float,s.split(',')))))
  elif line=='REST_END':
   key=tuple(b['name'] for b in bones);out.setdefault(name,{})[key]=bones
 return out

def convert(path,skeleton_name,bones,out):
 c=chunks(path);size,count,data=c['BONENAMES'];names=[data[i*size:i*size+64].split(b'\0')[0].decode() for i in range(count)]
 # Actual hierarchy was recovered from the cooked Skeleton, never use the PSA parents.
 assert names==[b['name'] for b in bones],(path,'bone-name order differs')
 assert all(-1<=b['parent']<i for i,b in enumerate(bones))
 info=c['ANIMINFO'][2];assert c['ANIMINFO'][1]==1
 name=info[:64].split(b'\0')[0].decode();nb=struct.unpack_from('<i',info,128)[0];rate=struct.unpack_from('<f',info,152)[0];first,nf=struct.unpack_from('<ii',info,160);assert nb==len(bones)
 keys=np.frombuffer(c['ANIMKEYS'][2],dtype='<f4').reshape(-1,nb,8)[first:first+nf].copy();assert np.isfinite(keys).all()
 pos=keys[:,:,[0,2,1]];pos[:,:,2]*=-1;pos*=.01
 q=keys[:,:,[3,5,4,6]];q[:,:,2]*=-1;q[:,0,:3]*=-1;q[:,:,:3]*=-1
 norms=np.linalg.norm(q,axis=2);assert (norms>1e-6).all();q/=norms[:,:,None]
 # Quaternion sign continuity prevents a representation seam; motion remains unchanged.
 for f in range(1,nf):q[f,np.sum(q[f-1]*q[f],axis=1)<0]*=-1
 blob=bytearray();views=[];accessors=[]
 def acc(a,typ):
  a=np.asarray(a,dtype='<f4');blob.extend(b'\0'*((-len(blob))%4));start=len(blob);blob.extend(a.tobytes());views.append(dict(buffer=0,byteOffset=start,byteLength=a.nbytes));v=dict(bufferView=len(views)-1,componentType=5126,count=len(a),type=typ)
  if typ in ('SCALAR','VEC3'):v.update(min=np.min(a,axis=0).tolist(),max=np.max(a,axis=0).tolist());v['min']=v['min'] if isinstance(v['min'],list) else [v['min']];v['max']=v['max'] if isinstance(v['max'],list) else [v['max']]
  accessors.append(v);return len(accessors)-1
 # UE Viewer BAKE_BONE_SCALES already applies ancestral scale to rest/key translations.
 # Keep unit node scale to avoid applying the recorded scale twice.
 nodes=[]
 for i,b in enumerate(bones):
  x,y,z,w=b['rotation'];nodes.append(dict(name=b['name'],translation=[b['translation'][0]*.01,b['translation'][2]*.01,b['translation'][1]*.01],rotation=[-x,-z,-y,w],scale=[1,1,1]))
 for i,b in enumerate(bones):
  if b['parent']>=0:nodes[b['parent']].setdefault('children',[]).append(i)
 # UE Viewer writes zero/identity placeholders for missing tracks; honor its companion config.
 config=path.with_suffix('.config')
 section='';rotation_only=False;translation_bones=set();removed={}
 if config.exists():
  for line in config.read_text().splitlines():
   line=line.strip()
   if line.startswith('['):section=line
   elif line.startswith('bAnimRotationOnly='):rotation_only=line.endswith('1')
   elif section=='[UseTranslationBoneNames]' and line:translation_bones.add(line)
   elif section=='[RemoveTracks]' and '=' in line:
    k,v=line.split('=',1);removed[int(k.rsplit('.',1)[1])]=v
 for i,b in enumerate(bones):
  flag=removed.get(i,'')
  if flag in ('all','trans') or rotation_only and b['name'] not in translation_bones:pos[:,i]=nodes[i]['translation']
  if flag in ('all','rot'):q[:,i]=nodes[i]['rotation']

 # A small skinned marker makes glTF importers recognize Skeleton3D even without a character mesh.
 marker=acc(np.array([[0,0,0],[.002,0,0],[0,.002,0]]),'VEC3');weights=acc(np.array([[1,0,0,0]]*3),'VEC4')
 start=len(blob);blob.extend(np.zeros((3,4),dtype='<u2').tobytes());views.append(dict(buffer=0,byteOffset=start,byteLength=24));accessors.append(dict(bufferView=len(views)-1,componentType=5123,count=3,type='VEC4'));jointacc=len(accessors)-1
 nodes.append(dict(name='ReferenceMarker',mesh=0,skin=0));roots=[i for i,b in enumerate(bones) if b['parent']<0]+[len(nodes)-1]
 ti=acc(np.arange(nf,dtype=np.float32)/rate,'SCALAR');samplers=[];channels=[]
 for i in range(nb):
  for values,typ,target in [(pos[:,i],'VEC3','translation'),(q[:,i],'VEC4','rotation')]:
   ai=acc(values,typ);samplers.append(dict(input=ti,output=ai,interpolation='LINEAR'));channels.append(dict(sampler=len(samplers)-1,target=dict(node=i,path=target)))
 src=dict(asset=dict(version='2.0',generator='Tidebreak local reference converter',extras=dict(source='Spellbreak community Windows client; third-party reference',psa_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),skeleton=skeleton_name)),scenes=[dict(nodes=roots)],scene=0,nodes=nodes,skins=[dict(joints=list(range(nb)))],meshes=[dict(primitives=[dict(attributes=dict(POSITION=marker,WEIGHTS_0=weights,JOINTS_0=jointacc))])],animations=[dict(name=name,samplers=samplers,channels=channels)],buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
 j=json.dumps(src,separators=(',',':')).encode();j+=b' '*((-len(j))%4);blob+=b'\0'*((-len(blob))%4);out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(blob))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(blob),b'BIN\0')+blob)
 props=path.with_suffix('.props.txt')
 match=re.search(r'AdditiveAnimType = (\w+)',props.read_text()) if props.exists() else None
 additive=match.group(1) if match else 'unknown'
 return dict(source_additive_type=additive,clip=name,file=str(out),bones=nb,frames=nf,fps=rate,skeleton=skeleton_name,source=str(path),source_sha256=hashlib.sha256(path.read_bytes()).hexdigest())

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--reference',type=Path,required=True);ap.add_argument('--rests',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--limit',type=int,default=0);a=ap.parse_args();r=rests(a.rests);pk=json.loads((a.reference/'metadata/package_catalogue.json').read_text());byname={}
 for p in pk:
  if 'AnimSequence' not in p['classes']:continue
  for imp in p['imports']:
   if imp['class_name']=='Skeleton':byname[p['path'].lower()]=imp['name']
   if imp['class_name']=='Skeleton':
    for exp in p['exports']:
     if exp['class']=='AnimSequence':byname[(str(Path(p['path']).parent)+'/'+exp['name']+'.uasset').lower()]=imp['name']
 report=[];failures=[]
 for path in sorted((a.reference/'motion_psa').rglob('*.psa')):
  if a.limit and len(report)>=a.limit:break
  rel=path.relative_to(a.reference/'motion_psa');pkg='g3/Content/'+str(rel.with_suffix('.uasset'));sk=byname.get(pkg.lower())
  try:
   c=chunks(path);size,n,data=c['BONENAMES'];key=tuple(data[i*size:i*size+64].split(b'\0')[0].decode() for i in range(n));bones=r[sk][key];report.append(convert(path,sk,bones,a.out/'glb'/rel.with_suffix('.glb')))
  except Exception as e:failures.append(dict(path=str(path),error=repr(e)))
  if len(report)%100==0:print('Converted',len(report),'failed',len(failures),flush=True)
 a.out.mkdir(parents=True,exist_ok=True);(a.out/'conversion_report.json').write_text(json.dumps(dict(clips=report,failures=failures),indent=2));(a.out/'skeleton_rests.json').write_text(json.dumps({n:list(v.values()) for n,v in r.items()},indent=2));print('DONE',len(report),'failures',len(failures));assert not failures,failures[:3]
if __name__=='__main__':main()
