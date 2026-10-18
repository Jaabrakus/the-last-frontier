"""Unpack a WUX safely: space gate, temporary output, CRC/hash and structure checks.
Existing output files are never replaced. The source archive is never deleted.
"""
import argparse
import ctypes
import ctypes.util
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time

GIB = 1024 ** 3


def archive_members(path):
    """Read member sizes without writing/decompressing the large disc to disk."""
    lib = ctypes.CDLL(ctypes.util.find_library('archive'))
    ptr = ctypes.c_void_p
    for name, restype, args in [
        ('archive_read_new', ptr, []),
        ('archive_read_support_filter_all', ctypes.c_int, [ptr]),
        ('archive_read_support_format_all', ctypes.c_int, [ptr]),
        ('archive_read_open_filename', ctypes.c_int, [ptr, ctypes.c_char_p, ctypes.c_size_t]),
        ('archive_read_next_header', ctypes.c_int, [ptr, ctypes.POINTER(ptr)]),
        ('archive_entry_pathname', ctypes.c_char_p, [ptr]),
        ('archive_entry_size', ctypes.c_longlong, [ptr]),
        ('archive_entry_filetype', ctypes.c_uint, [ptr]),
        ('archive_read_data_skip', ctypes.c_int, [ptr]),
        ('archive_error_string', ctypes.c_char_p, [ptr]),
        ('archive_read_free', ctypes.c_int, [ptr]),
    ]:
        fn = getattr(lib, name); fn.restype = restype; fn.argtypes = args
    reader = lib.archive_read_new()
    rows = []
    try:
        lib.archive_read_support_filter_all(reader)
        lib.archive_read_support_format_all(reader)
        rc = lib.archive_read_open_filename(reader, os.fsencode(path), 65536)
        if rc != 0:
            raise ValueError((lib.archive_error_string(reader) or b'Cannot read archive').decode())
        entry = ptr()
        while True:
            rc = lib.archive_read_next_header(reader, ctypes.byref(entry))
            if rc == 1: break
            if rc != 0:
                raise ValueError((lib.archive_error_string(reader) or b'Invalid archive header').decode())
            rows.append({'name':os.fsdecode(lib.archive_entry_pathname(entry)),
                         'bytes':lib.archive_entry_size(entry),
                         'regular':lib.archive_entry_filetype(entry) == 0o100000})
            if lib.archive_read_data_skip(reader) < 0:
                raise ValueError('Cannot skip archive member')
    finally:
        lib.archive_read_free(reader)
    return rows


def validate_wux(path):
    physical = path.stat().st_size
    with path.open('rb') as f:
        header = f.read(32)
        if len(header) != 32: raise ValueError('Short WUX header')
        a, b, sector, flags, logical = struct.unpack_from('<IIIIQ', header)
        if (a,b) != (0x30585557,0x1099d02e): raise ValueError('WUX signature mismatch')
        if not 512 <= sector <= 1048576 or sector & (sector-1):
            raise ValueError('Invalid WUX sector size')
        count = (logical+sector-1)//sector
        if not 0 < count <= 8_000_000: raise ValueError('Invalid WUX sector count')
        table_size = count*4
        table = f.read(table_size)
        if len(table) != table_size: raise ValueError('Short WUX index')
        data_offset = ((32+table_size+sector-1)//sector)*sector
        indexes = struct.iter_unpack('<I',table)
        required = data_offset
        for (index,) in indexes:
            required = max(required,data_offset+(index+1)*sector)
        if required > physical:
            raise ValueError('WUX sector index references missing data beyond EOF')
    return {'sector_bytes':sector,'logical_bytes':logical,'required_physical_bytes':required,
            'actual_bytes':physical,'flags':flags}


def prepare(archive, output, member=None, expected_sha256=None, reserve=2*GIB):
    archive, output = Path(archive).resolve(), Path(output).absolute()
    if not archive.is_file(): raise ValueError('Source archive does not exist')
    if os.path.lexists(output): raise ValueError('Output already exists; choose a new filename')
    output.parent.mkdir(parents=True,exist_ok=True)
    marker = output.with_suffix(output.suffix+'.verified.json')
    if os.path.lexists(marker): raise ValueError('Verification record already exists')
    source_stat = archive.stat()
    choices = [r for r in archive_members(archive) if r['regular'] and r['name'].lower().endswith('.wux')]
    if member is not None: choices = [r for r in choices if r['name']==member]
    if len(choices) != 1: raise ValueError('Choose exactly one WUX member with --member')
    row = choices[0]
    if row['bytes'] <= 0: raise ValueError('Archive reports an invalid WUX size')
    needed = row['bytes']+reserve
    free = shutil.disk_usage(output.parent).free
    if free < needed:
        raise ValueError('Need %.2f GiB free (including reserve); have %.2f GiB' % (needed/GIB,free/GIB))
    partial = None; published = False; process = None
    digest = hashlib.sha256(); count = 0; last = time.monotonic()
    try:
        fd,name = tempfile.mkstemp(prefix=output.name+'.',suffix='.partial',dir=output.parent)
        partial = Path(name)
        with os.fdopen(fd,'wb') as dst, tempfile.TemporaryFile() as errors:
            process = subprocess.Popen(['bsdtar','-xOf',str(archive),'--',row['name']],stdout=subprocess.PIPE,stderr=errors)
            while chunk := process.stdout.read(8*1024*1024):
                if shutil.disk_usage(output.parent).free < len(chunk)+reserve:
                    raise OSError('Disk space fell below reserve; temporary output will be removed')
                if count+len(chunk) > row['bytes']: raise ValueError('Member exceeds its declared size')
                dst.write(chunk); digest.update(chunk); count += len(chunk)
                if time.monotonic()-last >= 15:
                    print('Unpacking %.1f%%' % (count/row['bytes']*100),flush=True); last=time.monotonic()
            process.stdout.close()
            rc = process.wait()
            errors.seek(0); message = errors.read().decode(errors='replace').strip()
            if rc or message: raise ValueError('Archive read/CRC check failed: '+message)
            if count != row['bytes']: raise ValueError('Short archive member')
            dst.flush(); os.fsync(dst.fileno())
        current = archive.stat()
        if (current.st_size,current.st_mtime_ns)!=(source_stat.st_size,source_stat.st_mtime_ns):
            raise ValueError('Source archive changed during extraction')
        # Hash the stored bytes too: successful streaming is not a read-back check.
        stored = hashlib.sha256()
        with partial.open('rb') as f:
            while chunk := f.read(8*1024*1024): stored.update(chunk)
        actual = stored.hexdigest()
        if actual != digest.hexdigest(): raise ValueError('Stored output does not match extracted stream')
        if expected_sha256 and actual.lower()!=expected_sha256.lower():
            raise ValueError('SHA-256 does not match the supplied reference digest')
        structure = validate_wux(partial)
        record = {'archive':str(archive),'member':row['name'],'output':str(output),
                  'bytes':count,'sha256':actual,'expected_sha256':expected_sha256,
                  'archive_read_crc_passed':True,'stored_readback_passed':True,
                  'structure':structure,'verified':True,
                  'scope':'Archive integrity and stored bytes only; decryption/key compatibility is a separate check.'}
        # Atomic publication without overwriting an existing file, even after a race.
        os.link(partial,output); published=True
        try:
            with marker.open('x') as f: json.dump(record,f,indent=2)
        except BaseException:
            output.unlink(); published=False; raise
        print('VERIFIED: '+str(output),flush=True)
        return record
    finally:
        if process and process.poll() is None:
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
        if process and process.stdout: process.stdout.close()
        if partial: partial.unlink(missing_ok=True)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('archive',type=Path)
    p.add_argument('output',type=Path)
    p.add_argument('--member')
    p.add_argument('--expected-sha256')
    a=p.parse_args()
    if a.expected_sha256 and (len(a.expected_sha256)!=64 or any(c not in '0123456789abcdefABCDEF' for c in a.expected_sha256)):
        p.error('Expected SHA-256 must be 64 hexadecimal characters')
    try: prepare(a.archive,a.output,a.member,a.expected_sha256)
    except (OSError,ValueError) as e: p.exit(1,'FAILED: '+str(e)+'\n')

if __name__=='__main__':main()
