"""Create a lossless, hash-verified ZIP before deleting a source client folder."""
import argparse, hashlib, json, os, shutil, time, zipfile
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('source',type=Path)
p.add_argument('output',type=Path)
a=p.parse_args()
source=a.source.resolve(); output=a.output.resolve()
assert source.is_dir() and source not in output.parents
output.mkdir(parents=True,exist_ok=True)
final=output/'spellbreak-client-source.zip'
partial=output/'spellbreak-client-source.zip.partial'
assert not final.exists() and not partial.exists(), 'Refusing to overwrite an existing backup'
files=sorted(x for x in source.rglob('*') if x.is_file())
assert not any(x.is_symlink() for x in source.rglob('*')), 'Unexpected symlink requires explicit preservation'
total=sum(x.stat().st_size for x in files)
manifest=[]; done=0; last=time.monotonic()
try:
 with zipfile.ZipFile(partial,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=3,allowZip64=True) as archive:
  for path in files:
   before=path.stat(); digest=hashlib.sha256(); rel=str(path.relative_to(source))
   info=zipfile.ZipInfo.from_file(path,rel); info.compress_type=zipfile.ZIP_DEFLATED; info._compresslevel=3
   with path.open('rb') as src, archive.open(info,'w',force_zip64=True) as dst:
    while chunk:=src.read(8*1024*1024):
     if shutil.disk_usage(output).free < 3*1024**3: raise OSError('Stopped to preserve 3 GiB free space')
     digest.update(chunk); dst.write(chunk);done+=len(chunk)
     if time.monotonic()-last>15:
      print(json.dumps({'phase':'archive','percent':round(done/total*100,1),'archive_GiB':round(partial.stat().st_size/1024**3,2)}),flush=True);last=time.monotonic()
   after=path.stat()
   assert (before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns),f'Source changed: {rel}'
   manifest.append({'path':rel,'bytes':before.st_size,'mtime_ns':before.st_mtime_ns,'mode':before.st_mode,'sha256':digest.hexdigest()})
  archive.writestr('SOURCE_BACKUP_MANIFEST.json',json.dumps({'source':str(source),'files':manifest},indent=2))
 print('Archive written; verifying every decompressed byte against source SHA-256.',flush=True)
 done=0
 with zipfile.ZipFile(partial) as archive:
  assert len(archive.infolist())==len(manifest)+1
  for row in manifest:
   digest=hashlib.sha256(); count=0
   with archive.open(row['path']) as f:
    while chunk:=f.read(8*1024*1024):
     digest.update(chunk);count+=len(chunk);done+=len(chunk)
     if time.monotonic()-last>15:
      print(json.dumps({'phase':'verify','percent':round(done/total*100,1)}),flush=True);last=time.monotonic()
   assert count==row['bytes'] and digest.hexdigest()==row['sha256'],row['path']
 partial.rename(final)
 record={'source':str(source),'archive':str(final),'source_bytes':total,'archive_bytes':final.stat().st_size,'files':manifest,'verified':True,'verification':'Every ZIP member decompressed and checked against SHA-256 computed while reading the source; ZIP CRC also checked.'}
 (output/'manifest.json').write_text(json.dumps(record,indent=2))
 print(json.dumps({'status':'VERIFIED','files':len(manifest),'source_GiB':round(total/1024**3,2),'archive_GiB':round(final.stat().st_size/1024**3,2),'archive':str(final)}),flush=True)
except BaseException:
 if partial.exists(): partial.unlink()
 raise
