"""The web build's pack with its binary resources compressed (after the export, before tools/web/split_pck.py).

Godot saves imported scenes compressed ("RSCC": FileAccessCompressed), but the export saves every resource a plugin
customizes (the release-metadata plugin customizes them all) uncompressed ("RSRC"): the body mesh's 37 shape keys, mostly
zeros, went from 35 MB to 74 MB. Here every RSRC file in the pack that deflate shrinks by at least MIN_GAIN is rewritten as
RSCC (mode 1, deflate; Godot's ResourceFormatLoaderBinary opens either), and every .json written without its indents
(parsed and dumped again: the same values; one that does not parse is kept as it is). The pack's directory written again.
    python3 -I tools/web/pack_compress.py <build dir>/index.pck
PCK format 3..4: magic, format, version x3, flags, file base (u64), directory offset (u64), reserved words up to the file
base (112 in 4.7), the files from the file base (32-byte aligned), then the directory: count, then per file the path's length (padded
to 4), the path, offset (from the file base), size, md5, flags.
"""
import hashlib
import json
import os
import struct
import sys
import zlib

ALIGN = 32
MIN_GAIN = 0.1
BLOCK = 65536
MODE_DEFLATE = 1


def _ustr(data: bytes, at: int):
    """A binary resource's string (u32 length with its NUL, the UTF-8 bytes): (the string, the position after it)."""
    n, = struct.unpack_from('<I', data, at)
    n &= 0x7fffffff
    return data[at + 4:at + 4 + n].rstrip(b'\0').decode('utf-8', 'replace'), at + 4 + n


def _shift_offsets(data: bytes) -> bytes:
    """An uncompressed RSRC file without its 4-byte magic, the offsets in it (the import metadata's, every internal
    resource's: positions in the file) made 4 less to match. ResourceLoaderBinary reads a compressed file's stream from the
    field after the magic. None when the header is not one this knows (big endian, a newer format)."""
    be, real64, vmaj, vmin, fmt = struct.unpack_from('<5I', data, 4)
    if be != 0 or vmaj != 4 or fmt < 5:
        return None
    out = bytearray(data[4:])
    at = 24
    _, at = _ustr(data, at)                          # the type
    imd_at = at
    imd, flags = struct.unpack_from('<QI', data, at)
    at += 12 + 8                                     # (import metadata offset, flags, uid)
    if flags & 8:                                    # FORMAT_FLAG_HAS_SCRIPT_CLASS
        _, at = _ustr(data, at)
    at += 11 * 4                                     # the reserved fields
    if imd:
        struct.pack_into('<Q', out, imd_at - 4, imd - 4)
    n, = struct.unpack_from('<I', data, at)
    at += 4
    for _ in range(n):                               # the string table
        _, at = _ustr(data, at)
    n, = struct.unpack_from('<I', data, at)
    at += 4
    for _ in range(n):                               # the external resources: type, path, uid
        _, at = _ustr(data, at)
        _, at = _ustr(data, at)
        if flags & 2:                                # FORMAT_FLAG_UIDS
            at += 8
    n, = struct.unpack_from('<I', data, at)
    at += 4
    for _ in range(n):                               # the internal resources: path, offset
        _, at = _ustr(data, at)
        off, = struct.unpack_from('<Q', data, at)
        # (each one starts with its class name: a check that this read the table right)
        cls, _ = _ustr(data, off)
        if not cls.isidentifier():
            return None
        struct.pack_into('<Q', out, at - 4, off - 4)
        at += 8
    return bytes(out)


def rscc(data: bytes) -> bytes:
    """`data` (a whole RSRC file) as ResourceSaver's FLAG_COMPRESS would have written it: magic RSCC, then the stream
    after the RSRC magic in FileAccessCompressed's blocks. None when its header is not one this knows."""
    data = _shift_offsets(data)
    if data is None:
        return None
    total = len(data)
    bs = BLOCK
    while total % bs == 0:             # (a last block of 0 bytes: avoided)
        bs -= 4096
    count = total // bs + 1
    blocks = []
    for i in range(count):
        chunk = data[i * bs:(i + 1) * bs] if i < count - 1 else data[i * bs:]
        blocks.append(zlib.compress(chunk, 9))
    out = [b'RSCC', struct.pack('<III', MODE_DEFLATE, bs, total)]
    out.append(b''.join(struct.pack('<I', len(b)) for b in blocks))
    out.extend(blocks)
    out.append(b'RSCC')
    return b''.join(out)


def main(path: str) -> int:
    with open(path, 'rb') as f:
        blob = f.read()
    if blob[:4] != b'GDPC':
        print('not a pck:', path)
        return 1
    fmt, = struct.unpack_from('<I', blob, 4)
    flags, base = struct.unpack_from('<IQ', blob, 20)
    if flags & 1:
        print('encrypted directory: not handled')
        return 1
    dir_at = struct.unpack_from('<Q', blob, 32)[0] if fmt >= 3 else None
    head_len = base                    # (the header, its reserved words and padding: copied as they are)
    if base < 40 + 64:
        print('unexpected file base %d' % base)
        return 1
    # the directory
    at = dir_at if dir_at is not None else head_len
    n, = struct.unpack_from('<I', blob, at)
    at += 4
    ents = []
    for _ in range(n):
        ln, = struct.unpack_from('<I', blob, at)
        at += 4
        p = blob[at:at + ln]
        at += ln
        off, size = struct.unpack_from('<QQ', blob, at)
        at += 16
        md5 = blob[at:at + 16]
        at += 16
        fl, = struct.unpack_from('<I', blob, at)
        at += 4
        ents.append([p, off, size, md5, fl])
    if dir_at is None:
        print('format %d (directory before the files): not handled' % fmt)
        return 1
    # the files again, compressed where it pays
    body = bytearray()
    before = after = 0
    changed = 0
    skipped = 0
    for e in sorted(ents, key=lambda e: e[1]):
        p, off, size, md5, fl = e
        data = blob[base + off: base + off + size]
        if fl == 0 and p.endswith(b'.json'):
            try:
                c = json.dumps(json.loads(data.decode('utf-8')), ensure_ascii=False, separators=(',', ':')).encode('utf-8')
            except (ValueError, UnicodeDecodeError):
                c = data
            if len(c) < size:
                before += size
                after += len(c)
                changed += 1
                data = c
        elif fl == 0 and data[:4] == b'RSRC':
            c = rscc(data)
            if c is None:
                skipped += 1
            elif len(c) <= size * (1.0 - MIN_GAIN):
                before += size
                after += len(c)
                changed += 1
                data = c
        pad = (-len(body)) % ALIGN
        body += b'\0' * pad
        e[1] = len(body)
        e[2] = len(data)
        e[3] = hashlib.md5(data).digest()
        body += data
    body += b'\0' * ((-(base + len(body))) % ALIGN)
    new_dir_at = base + len(body)
    d = bytearray(struct.pack('<I', len(ents)))
    for p, off, size, md5, fl in ents:
        d += struct.pack('<I', len(p)) + p + struct.pack('<QQ', off, size) + md5 + struct.pack('<I', fl)
    head = bytearray(blob[:head_len])
    struct.pack_into('<Q', head, 32, new_dir_at)
    tmp = path + '.tmp'
    with open(tmp, 'wb') as f:
        f.write(head)
        f.write(body)
        f.write(d)
    os.replace(tmp, path)
    print('%d resources compressed or minified: %.1f MB -> %.1f MB; pack %.1f MB -> %.1f MB (%d not read, kept)' % (
        changed, before / 1e6, after / 1e6, len(blob) / 1e6, os.path.getsize(path) / 1e6, skipped))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
