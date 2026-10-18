"""Bounded Yaz0/SARC decoding for locally extracted reference resources.

Lists members by default; --extract REGEX exports matching names and records
their parent hash. Does not delete inputs or overwrite outputs.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct

LIMIT = 256 * 1024 * 1024


def decode(data):
    if not data.startswith(b'Yaz0'):
        return data
    size = struct.unpack_from('>I', data, 4)[0]
    if size > LIMIT:
        raise ValueError('Decoded resource exceeds limit')
    out = bytearray()
    pos = 16
    while len(out) < size:
        code = data[pos]
        pos += 1
        for bit in range(7, -1, -1):
            if len(out) == size:
                break
            if code & (1 << bit):
                out.append(data[pos])
                pos += 1
            else:
                a, b = data[pos:pos + 2]
                pos += 2
                distance = ((a & 15) << 8 | b) + 1
                length = a >> 4
                if length == 0:
                    length = data[pos] + 18
                    pos += 1
                else:
                    length += 2
                if distance > len(out) or len(out) + length > size:
                    raise ValueError('Invalid Yaz0 back reference')
                for _ in range(length):
                    out.append(out[-distance])
    return bytes(out)


def members(data):
    data = decode(data)
    if data[:4] != b'SARC':
        raise ValueError('Not a SARC resource')
    if data[6:8] not in (b'\xfe\xff', b'\xff\xfe'):
        raise ValueError('Invalid SARC byte order')
    endian = '>' if data[6:8] == b'\xfe\xff' else '<'
    header = struct.unpack_from(endian + 'H', data, 4)[0]
    total, start = struct.unpack_from(endian + 'II', data, 8)
    if total != len(data) or data[header:header + 4] != b'SFAT':
        raise ValueError('Invalid SARC header')
    sfat_size, count = struct.unpack_from(endian + 'HH', data, header + 4)
    nodes = header + sfat_size
    sfnt = nodes + count * 16
    if data[sfnt:sfnt + 4] != b'SFNT':
        raise ValueError('Missing SFNT')
    names = sfnt + struct.unpack_from(endian + 'H', data, sfnt + 4)[0]
    for i in range(count):
        key, attr, first, last = struct.unpack_from(endian + '4I', data, nodes + i * 16)
        if attr >> 24:
            offset = names + (attr & 0xffffff) * 4
            if not names <= offset < start:
                raise ValueError('Invalid name offset')
            name = data[offset:data.index(0, offset, start)].decode('utf-8')
        else:
            name = f'unnamed_{key:08x}'
        if not 0 <= first <= last <= len(data) - start:
            raise ValueError('Invalid member bounds')
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or '\\' in name:
            raise ValueError('Unsafe member path')
        yield name, data[start + first:start + last]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--extract')
    args = parser.parse_args()
    raw = args.source.read_bytes()
    rows = []
    for name, data in members(raw):
        print(f'{name}\t{len(data)}')
        if args.extract is not None and re.fullmatch(args.extract, name):
            if args.output is None:
                parser.error('--extract requires --output')
            path = args.output / name
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('xb') as f:
                f.write(data)
            rows.append({'member': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    if args.output is not None:
        args.output.mkdir(parents=True, exist_ok=True)
        with (args.output / 'resource_manifest.json').open('x') as f:
            json.dump({'source': str(args.source.resolve()), 'source_sha256': hashlib.sha256(raw).hexdigest(), 'members': rows}, f, indent=2)


if __name__ == '__main__':
    main()
