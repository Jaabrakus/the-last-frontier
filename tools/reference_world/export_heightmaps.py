"""Export extracted terrain tiles as lossless 16-bit heightmap PNGs.

Raw .hght samples are little-endian uint16, 256 x 256. Sample values are
preserved; the source game's world scale and coordinate registration are
not established by this export. No normalization is applied to height data.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from unpack_resources import members


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_directory', type=Path)
    parser.add_argument('output_directory', type=Path)
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=False)
    rows = []
    for source in sorted(args.source_directory.rglob('*.hght.sstera')):
        raw = source.read_bytes()
        for name, data in members(raw):
            if not name.endswith('.hght'):
                continue
            if len(data) != 256 * 256 * 2:
                raise ValueError(f'Unexpected height tile size: {name}')
            # SARC member paths remain in metadata; only safe basenames go here.
            destination = args.output_directory / (Path(name).stem + '.png')
            if destination.exists():
                raise ValueError(f'Duplicate terrain tile: {name}')
            image = Image.frombytes('I;16', (256, 256), data)
            image.save(destination)
            # Readback compares samples, independent of PNG compression/byte order.
            with Image.open(destination) as check:
                if list(check.getdata()) != list(image.getdata()):
                    raise ValueError(f'PNG sample mismatch: {name}')
            rows.append({
                'file': destination.name, 'source': str(source.resolve()),
                'source_sha256': hashlib.sha256(raw).hexdigest(),
                'member': name, 'member_sha256': hashlib.sha256(data).hexdigest(),
                'png_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
                'size': [256, 256], 'bits': 16, 'sample_values_preserved': True,
            })
    (args.output_directory / 'heightmap_manifest.json').write_text(json.dumps({
        'source_game': 'The Legend of Zelda: Breath of the Wild (Wii U)',
        'purpose': 'Local source reference conversion',
        'world_scale_verified': False, 'world_registration_verified': False,
        'format_reference': 'https://github.com/AndrooU/BotWHeightMapConverter/blob/master/generate_map.py',
        'tiles': rows,
    }, indent=2))
    print(f'Exported and sample-verified {len(rows)} 16-bit heightmaps')


if __name__ == '__main__':
    main()
