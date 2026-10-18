#!/usr/bin/env python3
"""Convert source-preserving BFRES dumps to a skinned GLB reference, offline.

The exporter preserves Nintendo source names and attribution. It does not port
the original shader or Actor draw/visibility rules. No input files are deleted.
"""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct

import numpy as np
from PIL import Image


def bone_local(bone):
    if bone['rotation_mode'] != 'EulerXYZ':
        raise ValueError('Only verified EulerXYZ source skeletons are supported')
    x, y, z = bone['rotation'][:3]
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])
    ry = np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]])
    rz = np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]])
    local = np.eye(4)
    local[:3,:3] = rz @ ry @ rx @ np.diag(bone['scale'])
    local[:3,3] = bone['position']
    return local


def skeleton_world(model):
    result = []
    for i,bone in enumerate(model['bones']):
        if bone['parent'] >= i:
            raise ValueError('Parent-after-child skeleton is unsupported')
        local = bone_local(bone)
        result.append(local if bone['parent'] < 0 else result[bone['parent']] @ local)
    return result


def decode_textures(manifest, directory):
    """Decode the deswizzled source BC1/2/3/4/5 or RGBA8 first mip losslessly."""
    result = {}
    directory.mkdir(parents=True, exist_ok=True)
    raw_dir = manifest.parent / (manifest.stem + '_raw')
    source = json.loads(manifest.read_text())
    for texture in source['textures']:
        width,height = texture['width'],texture['height']
        data = (raw_dir / texture['file']).read_bytes()
        fmt = texture['format']
        codes = {'BC1':b'DXT1','BC2':b'DXT3','BC3':b'DXT5','BC4':b'ATI1','BC5':b'ATI2'}
        code = next((v for k,v in codes.items() if k in fmt), None)
        if code:
            fourcc = struct.unpack('<I',code)[0]
            # Legacy DDS header, top-level mip only; dimensions preserve source.
            header = [124,0x81007,height,width,len(data),0,1]+[0]*11
            header += [32,4,fourcc,0,0,0,0,0,0x1000,0,0,0,0]
            image = Image.open(io.BytesIO(b'DDS '+struct.pack('<31I',*header)+data)).convert('RGBA')
        elif 'R8_G8_B8_A8' in fmt:
            image = Image.frombytes('RGBA',(width,height),data[:width*height*4])
        else:
            continue
        original = image.split()
        channels = {'ChannelR':original[0],'ChannelG':original[1],'ChannelB':original[2],'ChannelA':original[3],
                    'Always0':Image.new('L',image.size,0),'Always1':Image.new('L',image.size,255),
                    'Zero':Image.new('L',image.size,0),'One':Image.new('L',image.size,255)}
        image = Image.merge('RGBA',tuple(channels.get(c,original[i]) for i,c in enumerate(texture['channels'])))
        out = directory / (texture['name']+'.png')
        image.save(out)
        result[texture['name']] = out
    return result


class Gltf:
    def __init__(self):
        self.data = bytearray()
        self.document = {'asset':{'version':'2.0','generator':'Frontier offline BFRES reference converter',
            'copyright':'Source: local The Legend of Zelda: Breath of the Wild files (Nintendo); reference conversion, no ownership claim'},
            'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'skins':[],
            'materials':[],'accessors':[],'bufferViews':[],'buffers':[{'byteLength':0}],
            'images':[],'textures':[],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]}

    def view(self,data,target=None):
        self.data.extend(b'\0'*(-len(self.data)%4));offset=len(self.data);self.data.extend(data)
        view={'buffer':0,'byteOffset':offset,'byteLength':len(data)}
        if target: view['target']=target
        self.document['bufferViews'].append(view)
        return len(self.document['bufferViews'])-1

    def accessor(self,data,kind,component=5126,target=None,bounds=False):
        array=np.asarray(data,dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[component])
        acc={'bufferView':self.view(array.tobytes(),target),'componentType':component,'count':len(array),'type':kind}
        if bounds:
            acc['min']=array.min(axis=0).tolist();acc['max']=array.max(axis=0).tolist()
        self.document['accessors'].append(acc)
        return len(self.document['accessors'])-1

    def save(self,path):
        self.document['buffers'][0]['byteLength']=len(self.data)
        for key in ['images','textures']:
            if not self.document[key]:del self.document[key]
        raw=json.dumps(self.document,separators=(',',':')).encode();raw+=b' '*(-len(raw)%4)
        self.data.extend(b'\0'*(-len(self.data)%4))
        path.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(raw)+len(self.data))+struct.pack('<I4s',len(raw),b'JSON')+raw+struct.pack('<I4s',len(self.data),b'BIN\0')+self.data)


def convert(inputs,output,texture_manifests=(),exclude_shapes=(),include_models=(),flip_v=False):
    sources=[json.loads(p.read_text()) for p in inputs]
    models=[m for s in sources for m in s['models'] if not include_models or m['name'] in include_models]
    gltf=Gltf();doc=gltf.document
    textures={}
    texture_sources=[]
    for p in texture_manifests:
        texture_sources.append(json.loads(p.read_text()))
        textures.update(decode_textures(p,output.parent/'textures'))
    texture_index={}
    for name,path in textures.items():
        image_idx=len(doc['images']);doc['images'].append({'name':name,'bufferView':gltf.view(path.read_bytes()),'mimeType':'image/png'})
        texture_index[name]=len(doc['textures']);doc['textures'].append({'sampler':0,'source':image_idx})

    # Merge only identical source bone names/rest transforms; armor adds its hair bones.
    bones=[];world=[];bone_by_name={};remaps=[];inverse_error=0.0
    for model in models:
        mw=skeleton_world(model);remap=[]
        for i,bone in enumerate(model['bones']):
            name=bone['name']
            if name in bone_by_name:
                target=bone_by_name[name]
                if np.max(np.abs(world[target]-mw[i]))>1e-5:
                    raise ValueError('Conflicting bind transform for source bone '+name)
            else:
                target=len(bones);bone_by_name[name]=target
                bones.append({'name':name,'local':bone_local(bone),'parent':-1 if bone['parent']<0 else remap[bone['parent']]})
                world.append(mw[i])
            remap.append(target)
            idx=bone['smooth_matrix']
            if idx>=0 and idx<len(model['inverse_model_matrices']):
                stored=np.eye(4);stored[:3]=np.array(model['inverse_model_matrices'][idx]).reshape(3,4)
                inverse_error=max(inverse_error,float(np.max(np.abs(stored@mw[i]-np.eye(4)))))
        remaps.append(remap)
    if inverse_error>1e-5:raise ValueError(f'Source inverse-bind validation failed: {inverse_error}')
    for i,bone in enumerate(bones):
        doc['nodes'].append({'name':bone['name'],'matrix':bone['local'].T.reshape(-1).tolist()})
        parent=bone['parent']
        if parent>=0:doc['nodes'][parent].setdefault('children',[]).append(i)
        else:doc['scenes'][0]['nodes'].append(i)
    inverse=np.array([np.linalg.inv(w).T.reshape(-1) for w in world])
    doc['skins'].append({'name':'Source_Link_and_armor_rig','inverseBindMatrices':gltf.accessor(inverse,'MAT4'),
                        'joints':list(range(len(bones))),'skeleton':0})
    shape_reports=[]
    for model,remap in zip(models,remaps):
        mat_offset=len(doc['materials'])
        for material in model['materials']:
            pbr={'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':0.8}
            sampler=material['samplers'].index('_a0') if '_a0' in material['samplers'] else -1
            texname=material['textures'][sampler] if sampler>=0 else None
            if texname in texture_index:pbr['baseColorTexture']={'index':texture_index[texname]}
            entry={'name':model['name']+'/'+material['name'],'pbrMetallicRoughness':pbr,'doubleSided':True,
                   'extras':{'source_shader':material['shader_archive'],'source_textures':material['textures'],
                             'limitation':'Original shader is not ported; portable PBR preview uses source albedo.'}}
            if any(word in material['name'].lower() for word in ['hair','eyelashes']):
                entry.update(alphaMode='MASK',alphaCutoff=0.5)
            doc['materials'].append(entry)
        source_world=skeleton_world(model);matrix_to_bone=model['matrix_to_bone']
        for shape in model['shapes']:
            if shape['name'] in exclude_shapes:continue
            if shape['primitive']!='Triangles':raise ValueError('Unsupported topology: '+shape['primitive'])
            a=shape['attributes'];positions=np.array(a['_p0'],dtype=float)[:,:3];normals=np.array(a['_n0'],dtype=float)[:,:3]
            count=len(positions);joints=np.zeros((count,4),dtype=np.uint16);weights=np.zeros((count,4))
            if shape['skin_count'] == 0:
                source_bones=np.full(count,shape['bone']);joints[:,0]=remap[shape['bone']];weights[:,0]=1
            elif shape['skin_count'] == 1:
                indices=np.array(a['_i0'])[:,0].astype(int)
                source_bones=np.array([matrix_to_bone[x] for x in indices]);joints[:,0]=[remap[x] for x in source_bones];weights[:,0]=1
            else:
                n=min(shape['skin_count'],4);indices=np.array(a['_i0'])[:,:n].astype(int)
                for col in range(n):joints[:,col]=[remap[matrix_to_bone[x]] for x in indices[:,col]]
                weights[:,:n]=np.array(a['_w0'])[:,:n]
                if np.any(weights.sum(axis=1)<=0):raise ValueError('Zero skin weight')
                weights/=weights.sum(axis=1,keepdims=True)
            if shape['skin_count']<=1:
                # Rigid source vertices are bone-local; portable glTF bind vertices are model-local.
                for i,b in enumerate(source_bones):
                    positions[i]=(source_world[b]@np.r_[positions[i],1])[:3]
                    normals[i]=np.linalg.inv(source_world[b][:3,:3]).T@normals[i]
            normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-12)
            indices=np.array(shape['indices'],dtype=np.uint32)+shape['first_vertex']
            if indices.max()>=count or len(indices)%3:raise ValueError('Invalid source triangle indices')
            attrs={'POSITION':gltf.accessor(positions,'VEC3',target=34962,bounds=True),
                   'NORMAL':gltf.accessor(normals,'VEC3',target=34962),
                   'JOINTS_0':gltf.accessor(joints,'VEC4',5123,34962),
                   'WEIGHTS_0':gltf.accessor(weights,'VEC4',target=34962)}
            if '_u0' in a:
                uv=np.array(a['_u0'])[:,:2]
                if flip_v:uv[:,1]=1-uv[:,1]
                attrs['TEXCOORD_0']=gltf.accessor(uv,'VEC2',target=34962)
            mesh_index=len(doc['meshes']);doc['meshes'].append({'name':model['name']+'/'+shape['name'],
                'primitives':[{'attributes':attrs,'indices':gltf.accessor(indices,'SCALAR',5125,34963),
                               'material':mat_offset+shape['material'],'mode':4}]})
            node_index=len(doc['nodes']);doc['nodes'].append({'name':model['name']+'/'+shape['name'],'mesh':mesh_index,'skin':0})
            doc['scenes'][0]['nodes'].append(node_index)
            shape_reports.append({'model':model['name'],'shape':shape['name'],'vertices':count,'triangles':len(indices)//3,
                                  'aabb_min':positions.min(axis=0).tolist(),'aabb_max':positions.max(axis=0).tolist()})
    doc['extras']={'source_attribution':[{'file':s['source'],'sha256':s['source_sha256'],'attribution':s['attribution']} for s in sources+texture_sources],
                   'source_actor_visibility_rules':'Not yet reconstructed; explicit exclusions only.',
                   'source_uv_v_flipped':flip_v,
                   'maximum_inverse_bind_identity_error':inverse_error}
    output.parent.mkdir(parents=True,exist_ok=True);gltf.save(output)
    report={'output':str(output.resolve()),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
            'source_files':[s['source'] for s in sources+texture_sources],
            'source_attribution':doc['extras']['source_attribution'],
            'source_uv_v_flipped':flip_v,'bones':len(bones),'meshes':len(shape_reports),
            'vertices':sum(s['vertices'] for s in shape_reports),'triangles':sum(s['triangles'] for s in shape_reports),
            'textures':len(textures),'maximum_inverse_bind_identity_error':inverse_error,'shapes':shape_reports,
            'limitations':['Source shaders not ported; portable preview uses albedo and PBR.',
                           'Actor material parameter and visibility rules not yet ported.',
                           'No source animations are included.']}
    output.with_suffix('.manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='shapes'},indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',nargs='+',type=Path);p.add_argument('--output',required=True,type=Path)
    p.add_argument('--texture-manifest',action='append',default=[],type=Path)
    p.add_argument('--exclude-shape',action='append',default=[]);p.add_argument('--include-model',action='append',default=[])
    p.add_argument('--flip-v',action='store_true',help='Create an explicit alternate UV convention for render comparison')
    a=p.parse_args();convert(a.input,a.output,a.texture_manifest,a.exclude_shape,a.include_model,a.flip_v)
