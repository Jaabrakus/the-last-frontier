#!/usr/bin/env python3
"""Inventory retained Wii U BFRES textures and decode only selected first mips.

No network assets are fetched. Original container/texture names and hashes remain
in the manifest; role labels describe this lab's placement, not verified source
terrain material mapping. Requires the existing offline BfresMeshExport DLL.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess

from PIL import Image
from unpack_resources import decode

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / 'artifacts/world_reference/world_textures'
DEFAULT_EXPORTER = ROOT / 'artifacts/world_reference/character_preview/mesh_export/bin/Debug/net8.0/mesh_export.dll'
ARRAY_HELPER = r'''
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Text.Json;
using BfresLibrary;
class WorldArrayExport {
    static int Main(string[] args) {
        var res=new ResFile(args[0]);
        var inventory=new List<object>(); var layers=new List<object>();
        foreach(var texture in res.Textures.Values) {
            if(texture is not BfresLibrary.WiiU.Texture t) continue;
            inventory.Add(new {name=t.Name,width=t.Width,height=t.Height,format=t.Format.ToString(),depth=t.Depth,array_length=t.ArrayLength,dimension=t.Dim.ToString(),data_bytes=t.Data.Length});
            if(args.Length<5 || t.Name!=args[3]) continue;
            Directory.CreateDirectory(args[2]);
            foreach(var index in args[4].Split(',').Select(int.Parse)) {
                if(index<0 || index>=t.ArrayLength) throw new ArgumentOutOfRangeException("array index");
                var data=t.GetDeswizzledData(index,0);
                var file=$"{Path.GetFileName(t.Name)}__array_{index:D3}.raw";
                File.WriteAllBytes(Path.Combine(args[2],file),data);
                layers.Add(new {name=t.Name,width=t.Width,height=t.Height,format=t.Format.ToString(),array_index=index,array_length=t.ArrayLength,dimension=t.Dim.ToString(),file=file,bytes=data.Length,channels=new[]{t.CompSelR.ToString(),t.CompSelG.ToString(),t.CompSelB.ToString(),t.CompSelA.ToString()}});
            }
        }
        File.WriteAllText(args[1],JsonSerializer.Serialize(new {inventory=inventory,layers=layers},new JsonSerializerOptions {WriteIndented=true}));
        Console.WriteLine($"Inventoried {inventory.Count} textures; exported {layers.Count} selected array layers");return 0;
    }
}
'''


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_retained(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError('Existing retained extraction differs: ' + str(path))
    else:
        path.write_bytes(data)


def inventory(sources, output, exporter):
    rows, inputs = [], []
    for source in sources:
        source = source.resolve()
        raw = source.read_bytes()
        decoded = decode(raw)
        if not decoded.startswith(b'FRES'):
            raise ValueError('Not a Wii U BFRES: ' + str(source))
        decoded_path = output / 'decoded' / (source.stem + '.bfres')
        write_retained(decoded_path, decoded)
        dump_path = output / 'raw' / (source.stem + '.json')
        raw_directory = dump_path.parent / (dump_path.stem + '_raw')
        dump_path.parent.mkdir(parents=True, exist_ok=True)
        if not dump_path.exists():
            subprocess.run(['dotnet', str(exporter), str(decoded_path), str(dump_path), str(raw_directory)], check=True)
        dump = json.loads(dump_path.read_text())
        if dump['source_sha256'] != sha(decoded):
            raise ValueError('BFRES dump hash mismatch: ' + str(source))
        entry = {'source_bfres_path': str(source), 'source_bfres_sha256': sha(raw),
                 'decoded_bfres_path': str(decoded_path), 'decoded_bfres_sha256': sha(decoded),
                 'source_bytes': len(raw), 'decoded_bytes': len(decoded), 'texture_count': len(dump['textures'])}
        inputs.append(entry)
        for texture in dump['textures']:
            row = dict(texture, texture_name=texture['name'], **entry)
            row['raw_path'] = str(raw_directory / texture['file'])
            rows.append(row)
        print(f"{source.name}: {len(dump['textures'])} source textures", flush=True)
    result = {'attribution': 'Nintendo, The Legend of Zelda: Breath of the Wild; extracted local reference textures, no ownership transfer claimed',
              'source_files_modified': False, 'inputs': inputs, 'textures': rows}
    (output / 'inventory.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def image_of(row):
    data = Path(row['raw_path']).read_bytes()
    width, height = row['width'], row['height']
    codes = {'BC1': b'DXT1', 'BC2': b'DXT3', 'BC3': b'DXT5', 'BC4': b'ATI1', 'BC5': b'ATI2'}
    code = next((value for name, value in codes.items() if name in row['format']), None)
    if code:
        header = [124, 0x81007, height, width, len(data), 0, 1] + [0] * 11
        header += [32, 4, struct.unpack('<I', code)[0], 0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0]
        image = Image.open(io.BytesIO(b'DDS ' + struct.pack('<31I', *header) + data)).convert('RGBA')
    elif 'R8_G8_B8_A8' in row['format']:
        image = Image.frombytes('RGBA', (width, height), data[:width * height * 4])
    else:
        raise ValueError('Unsupported selected source format: ' + row['format'])
    original = image.split()
    channels = dict(zip(['ChannelR', 'ChannelG', 'ChannelB', 'ChannelA'], original))
    channels.update({'Always0': Image.new('L', image.size, 0), 'Always1': Image.new('L', image.size, 255),
                     'Zero': Image.new('L', image.size, 0), 'One': Image.new('L', image.size, 255)})
    return Image.merge('RGBA', tuple(channels.get(name, original[i]) for i, name in enumerate(row['channels'])))


def array_layers(source_inventory, source, name, indices, output, exporter):
    """Respect the source texture array dimension instead of assuming a 2D atlas."""
    source = source.resolve()
    entry = next(row for row in source_inventory['inputs'] if Path(row['source_bfres_path']) == source)
    helper = output / 'array_export'
    helper.mkdir(parents=True, exist_ok=True)
    (helper / 'WorldArrayExport.cs').write_text(ARRAY_HELPER)
    references = ''.join(f'<Reference Include="{p.stem}"><HintPath>{p.resolve()}</HintPath></Reference>'
                         for p in exporter.parent.glob('*.dll') if p.stem != exporter.stem)
    project = helper / 'array_export.csproj'
    project.write_text('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><NuGetAudit>false</NuGetAudit></PropertyGroup><ItemGroup>' + references + '</ItemGroup></Project>')
    config = helper / 'NuGet.Config'
    config.write_text('<configuration><packageSources><clear /></packageSources></configuration>')
    subprocess.run(['dotnet', 'restore', str(project), '--configfile', str(config), '--nologo', '-v', 'quiet'], check=True)
    subprocess.run(['dotnet', 'build', str(project), '-c', 'Release', '--no-restore', '--nologo', '-v', 'quiet'], check=True)
    dump = helper / 'array_dump.json'
    raws = output / 'raw' / 'array_layers'
    command = ['dotnet', str(helper / 'bin/Release/net8.0/array_export.dll'), entry['decoded_bfres_path'], str(dump), str(raws)]
    if indices:
        command += [name, ','.join(str(index) for index in indices)]
    subprocess.run(command, check=True)
    data = json.loads(dump.read_text())
    for row in source_inventory['textures']:
        if row['source_bfres_path'] == str(source):
            meta = next(t for t in data['inventory'] if t['name'] == row['texture_name'])
            row.update({key: meta[key] for key in ['array_length', 'depth', 'dimension']})
            row.setdefault('array_index', 0)
    for layer in data['layers']:
        row = dict(layer, texture_name=layer['name'], **entry)
        row['raw_path'] = str(raws / layer['file'])
        existing = [t for t in source_inventory['textures'] if t['texture_name'] == row['texture_name']
                    and t['source_bfres_path'] == row['source_bfres_path'] and int(t.get('array_index', 0)) == row['array_index']]
        if existing:
            existing[0].update(row)
        else:
            source_inventory['textures'].append(row)
    (output / 'inventory.json').write_text(json.dumps(source_inventory, indent=2) + '\n')
    return source_inventory


def select_images(source_inventory, selections, output):
    rows = []
    for role, name in selections:
        source_name, marker, array = name.partition('#')
        array_index = int(array) if marker else 0
        matches = [row for row in source_inventory['textures'] if row['texture_name'] == source_name and int(row.get('array_index', 0)) == array_index]
        if len(matches) != 1:
            raise ValueError(f'Expected exactly one source texture for {name}; found {len(matches)}')
        row = matches[0]
        image = image_of(row)
        suffix = f'__array_{array_index:03}' if marker else ''
        target = output / 'textures' / (Path(source_name).name + suffix + '.png')
        png = io.BytesIO()
        image.save(png, format='PNG')
        write_retained(target, png.getvalue())
        rows.append({'role': role, 'texture_name': source_name, 'array_index': array_index,
                     'array_length': row.get('array_length', 1), 'source_dimension': row.get('dimension', 'not inventoried'),
                     'output_png': str(target.resolve()),
                     'png_sha256': sha(png.getvalue()), 'source_bfres_path': row['source_bfres_path'],
                     'source_bfres_sha256': row['source_bfres_sha256'], 'decoded_bfres_path': row['decoded_bfres_path'],
                     'decoded_bfres_sha256': row['decoded_bfres_sha256'], 'width': image.width, 'height': image.height,
                     'source_format': row['format'], 'source_channels': row['channels'],
                     'source_raw_sha256': sha(Path(row['raw_path']).read_bytes()),
                     'alpha_extrema': list(image.getchannel('A').getextrema()),
                     'meaning': 'Source albedo selected for lab role ' + role + '; role placement/UV remapping is authored, not verified original map registration'})
        print(f"Decoded {role}: {name} ({image.width}x{image.height})", flush=True)
    manifest = {'attribution': source_inventory['attribution'], 'source_files_modified': False,
                'conversion': 'Lossless PNG of deswizzled, block-decoded first mip with source channel selectors; original source names retained',
                'original_world_material_placement_verified': False, 'inputs': source_inventory['inputs'], 'textures': rows}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sources', nargs='*', type=Path)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUT)
    parser.add_argument('--exporter', type=Path, default=DEFAULT_EXPORTER)
    parser.add_argument('--select', action='append', default=[], metavar='ROLE=SOURCE_TEXTURE_NAME')
    parser.add_argument('--array-source', type=Path)
    parser.add_argument('--array-texture', default='MaterialAlb')
    parser.add_argument('--array-indices', default='', help='Comma-separated layer indices; no value inventories array metadata only')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    data = inventory(args.sources, args.output, args.exporter) if args.sources else json.loads((args.output / 'inventory.json').read_text())
    if args.array_source:
        data = array_layers(data, args.array_source, args.array_texture,
                            [int(index) for index in args.array_indices.split(',') if index], args.output, args.exporter)
    if args.select:
        select_images(data, [value.split('=', 1) for value in args.select], args.output)


if __name__ == '__main__':
    main()
