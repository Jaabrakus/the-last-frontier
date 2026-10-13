"""Restore selected source-client files from the verified backup.
Use --pak-only to recover only the asset archive for further extraction.
Destination must be a new directory; existing files are never overwritten.
"""
import argparse, hashlib, json, zipfile
from pathlib import Path, PurePosixPath

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('backup',type=Path)
p.add_argument('destination',type=Path)
p.add_argument('--pak-only',action='store_true')
a=p.parse_args()
assert not a.destination.exists(), 'Choose a new destination directory'
with zipfile.ZipFile(a.backup) as archive:
 manifest=json.loads(archive.read('SOURCE_BACKUP_MANIFEST.json'))
 rows=[r for r in manifest['files'] if not a.pak_only or r['path']=='g3/Content/Paks/g3-WindowsNoEditor.pak']
 assert rows, 'No requested members in manifest'
 for row in rows:
  rel=PurePosixPath(row['path']);assert not rel.is_absolute() and '..' not in rel.parts
  target=a.destination/rel;target.parent.mkdir(parents=True,exist_ok=True)
  digest=hashlib.sha256();size=0
  with archive.open(row['path']) as src,target.open('xb') as dst:
   while chunk:=src.read(8*1024*1024):
    dst.write(chunk);digest.update(chunk);size+=len(chunk)
  assert size==row['bytes'] and digest.hexdigest()==row['sha256'],str(target)
  print('Verified',target,flush=True)
