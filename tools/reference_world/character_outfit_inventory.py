#!/usr/bin/env python3
"""Inventory actual source wardrobe resources and preserve extraction evidence.

This tool only reads an already generated disc catalogue and already exported
packs. Missing geometry means absent from that scope, not absent from every
possible source/update. Inputs are never deleted or altered.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET

from unpack_resources import members, decode


def digest(data):
    return hashlib.sha256(data).hexdigest()


def byml_string_tables(raw):
    data=decode(raw)
    if data[:2] not in (b'BY',b'YB') or len(data)<16:
        raise ValueError('Not a supported BYML header')
    endian='>' if data[:2]==b'BY' else '<'
    order='big' if endian=='>' else 'little'
    keys,strings,root=struct.unpack_from(endian+'III',data,4)
    def table(offset):
        if offset==0:return []
        if offset+4>len(data) or data[offset]!=0xc2:
            raise ValueError('Invalid BYML string table')
        count=int.from_bytes(data[offset+1:offset+4],order)
        if offset+4+4*(count+1)>len(data):raise ValueError('BYML table exceeds bounds')
        offsets=struct.unpack_from(endian+'I'*(count+1),data,offset+4)
        if any(offset+x>len(data) for x in offsets):raise ValueError('BYML string exceeds bounds')
        result=[]
        for a,b in zip(offsets,offsets[1:]):
            if b<a:raise ValueError('BYML string offsets out of order')
            item=data[offset+a:offset+b]
            if b'\0' not in item:raise ValueError('Unterminated BYML string')
            result.append(item.split(b'\0',1)[0].decode('utf-8'))
        return result
    return {'keys':table(keys),'strings':table(strings),'root_offset':root,'decoded_bytes':len(data)}


def pack_names_from_prefix(manifest):
    scan=json.loads(manifest.read_text());result=[]
    for row in scan['packs']:
        if not row['is_sarc']:continue
        data=(manifest.parent/row['header_file']).read_bytes()
        if len(data)!=row['header_bytes'] or digest(data)!=row['header_sha256']:
            raise ValueError('Pack prefix hash mismatch')
        endian='>' if data[6:8]==b'\xfe\xff' else '<'
        header=struct.unpack_from(endian+'H',data,4)[0]
        total,start=struct.unpack_from(endian+'II',data,8)
        if total!=row['source_bytes'] or start!=len(data) or data[header:header+4]!=b'SFAT':
            raise ValueError('Invalid SARC prefix')
        size,count=struct.unpack_from(endian+'HH',data,header+4)
        nodes=header+size;sfnt=nodes+count*16
        if data[sfnt:sfnt+4]!=b'SFNT':raise ValueError('Missing SARC string table')
        names=sfnt+struct.unpack_from(endian+'H',data,sfnt+4)[0]
        entries=[]
        for i in range(count):
            key,attr,first,last=struct.unpack_from(endian+'4I',data,nodes+i*16)
            if not 0<=first<=last<=total-start:raise ValueError('Invalid member extent')
            if attr>>24:
                offset=names+(attr&0xffffff)*4
                if not names<=offset<start:raise ValueError('Invalid member string offset')
                name=data[offset:data.index(0,offset,start)].decode('utf-8')
            else:name=f'unnamed_{key:08x}'
            entries.append({'member':name,'source_offset':start+first,'bytes':last-first})
        result.append(dict(row,members=entries))
    return scan,result


def inventory(catalogue,packs,output,extract_geometry,header_manifest=None,app_xml=None):
    output.mkdir(parents=True,exist_ok=True)
    catalogue_rows=json.loads(catalogue.read_text())
    disc_outfits=[r for r in catalogue_rows if re.search(r'/Model/Armor_[^/]+\.(?:Tex[12]\.)?sbfres$',r['path'])]
    packed=[];extracted=[];metadata=[];pack_inputs=[]
    for pack in packs:
        raw=pack.read_bytes();pack_hash=digest(raw)
        pack_inputs.append({'file':str(pack.resolve()),'sha256':pack_hash,'bytes':len(raw)})
        outer_entries=list(members(raw))
        for name,data in outer_entries:
            if 'ModelDivideTable' in name:
                tables=byml_string_tables(data)
                metadata.append({'source':str(pack.resolve()),'member':name,'sha256':digest(data),
                    'decoded_bytes':tables['decoded_bytes'],'key_count':len(tables['keys']),'string_count':len(tables['strings']),
                    'armor_keys':[s for s in tables['keys'] if 'Armor' in s],
                    'armor_strings':[s for s in tables['strings'] if 'Armor' in s],
                    'observed_purpose':'World-object model and animation chunk map; wardrobe lookup not established.'})
                table_path=output/(pack.stem+'_ModelDivideTable_strings.json')
                table_path.write_text(json.dumps(tables,indent=2)+'\n')
            if re.search(r'(?:^|/)Model/Armor_[^/]+\.(?:Tex[12]\.)?sbfres$',name):
                is_geometry='.Tex1.' not in name and '.Tex2.' not in name
                row={'pack':str(pack.resolve()),'pack_sha256':pack_hash,'member':name,'bytes':len(data),
                     'sha256':digest(data),'kind':'geometry' if is_geometry else 'texture'}
                packed.append(row)
                if extract_geometry and is_geometry:
                    compressed=output/'files'/pack.name/name
                    compressed.parent.mkdir(parents=True,exist_ok=True)
                    if compressed.exists():
                        if digest(compressed.read_bytes())!=row['sha256']:raise ValueError('Existing extraction differs: '+str(compressed))
                    else:compressed.write_bytes(data)
                    decoded=decode(data)
                    if not decoded.startswith(b'FRES'):raise ValueError('Outfit geometry is not a BFRES')
                    portable_input=compressed.with_suffix('.bfres')
                    if portable_input.exists():
                        if portable_input.read_bytes()!=decoded:raise ValueError('Existing decoded extraction differs')
                    else:portable_input.write_bytes(decoded)
                    extracted.append(dict(row,compressed_file=str(compressed.resolve()),decoded_file=str(portable_input.resolve()),
                        decoded_bytes=len(decoded),decoded_sha256=digest(decoded)))
    header_scan=None;header_packs=[]
    if header_manifest:
        header_scan,header_packs=pack_names_from_prefix(header_manifest)
    header_models=[dict(r,pack=p['source_path'],partition=p['partition'],header_sha256=p['header_sha256'])
                   for p in header_packs for r in p['members'] if r['member'].startswith('Model/')]
    header_outfits=[r for r in header_models if re.search(r'/Armor_[^/]+\.sbfres$',r['member']) and '.Tex' not in r['member']]
    header_weapons=[r for r in header_models if re.search(r'/Weapon_[^/]+\.sbfres$',r['member']) and '.Tex' not in r['member'] and '_Animation.' not in r['member']]
    header_items=[r for r in header_models if re.search(r'/Item_[^/]+\.sbfres$',r['member']) and '.Tex' not in r['member'] and '_Animation.' not in r['member']]
    disc_weapons=[r for r in catalogue_rows if re.search(r'/Model/Weapon_[^/]+\.sbfres$',r['path']) and '.Tex' not in r['path'] and '_Animation.' not in r['path']]
    sword_and_spear_members=[r for r in header_weapons if re.search(r'/Weapon_(?:Sword|Lsword|Spear)_',r['member'])]
    app_metadata=None
    if app_xml:
        root=ET.parse(app_xml).getroot()
        app_metadata={'file':str(app_xml.resolve()),'sha256':digest(app_xml.read_bytes()),
                      'title_id':root.findtext('title_id'),'title_version':root.findtext('title_version')}
    texture_names={Path(r['path']).name.split('.Tex')[0] for r in disc_outfits if '.Tex' in r['path']}
    geometry_names={Path(r['path']).name.split('.')[0] for r in disc_outfits if '.Tex' not in r['path']}
    geometry_names|={Path(r['member']).name.split('.')[0] for r in packed if r['kind']=='geometry'}
    geometry_names|={Path(r['member']).name.split('.')[0] for r in header_outfits}
    report={'source_game':'The Legend of Zelda: Breath of the Wild (local Wii U source)',
            'attribution':'Nintendo source names retained; inventory/extraction does not change source ownership.',
            'catalogue':{'file':str(catalogue.resolve()),'sha256':digest(catalogue.read_bytes()),'rows':len(catalogue_rows)},
            'app_metadata':app_metadata,
            'pack_inputs':pack_inputs,'disc_outfit_resources':disc_outfits,'packed_outfit_resources':packed,
            'extracted_outfit_geometry':extracted,'model_divide_observations':metadata,
            'header_scan':{'source_image':header_scan['source_image'],'source_manifest':str(header_manifest.resolve()),
                'scope':header_scan['scope'],'pack_count':len(header_scan['packs']),
                'parsed_sarc_count':len(header_packs),'unparsed_packs':[r for r in header_scan['packs'] if not r['is_sarc']],
                'outfit_geometry_members':header_outfits,'weapon_geometry_members':header_weapons,
                'item_geometry_members':header_items,'sword_and_spear_geometry_members':sword_and_spear_members} if header_scan else None,
            'disc_weapon_geometry':disc_weapons,
            'geometry_not_located_in_inspected_scope':sorted(texture_names-geometry_names),
            'scope_limit':'Disc catalogue, explicitly extracted packs, and top-level Model members in scanned SARC name tables. Updates and arbitrary nested subarchives are not declared missing.',
            'reader_investigation':'JWUDTool NodeEntry.isFile includes linked File entries; DirectoryEntry.stream recursively visits all children. No simple file/link filter omission found.'}
    (output/'outfit_inventory.json').write_text(json.dumps(report,indent=2)+'\n')
    if header_scan:(output/'all_pack_members.json').write_text(json.dumps(header_packs,indent=2)+'\n')
    print(json.dumps({'packs_inspected':len(packs),'disc_outfit_resources':len(disc_outfits),
        'disc_outfit_geometry':sum('.Tex' not in r['path'] for r in disc_outfits),
        'packed_outfit_geometry':sum(r['kind']=='geometry' for r in packed),
        'all_pack_name_tables_scanned':len(header_packs),
        'weapon_geometry_member_names':[r['member'] for r in header_weapons],
        'sword_and_spear_geometry_member_names':[r['member'] for r in sword_and_spear_members],
        'extracted_outfit_geometry':len(extracted),
        'geometry_not_located_in_inspected_scope':report['geometry_not_located_in_inspected_scope']},indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalogue',required=True,type=Path);parser.add_argument('--pack',action='append',default=[],type=Path)
    parser.add_argument('--header-manifest',type=Path)
    parser.add_argument('--app-xml',type=Path)
    parser.add_argument('--output',required=True,type=Path);parser.add_argument('--extract-geometry',action='store_true')
    args=parser.parse_args()
    if not args.pack and not args.header_manifest:parser.error('At least one --pack or --header-manifest is required')
    inventory(args.catalogue,args.pack,args.output,args.extract_geometry,args.header_manifest,args.app_xml)
