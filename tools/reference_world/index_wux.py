"""Index/selectively extract a verified WUX using the local JWUDTool bridge.
Both key files stay local; key bytes are passed through stdin, never argv.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def read_key(path):
    raw = Path(path).read_bytes()
    if len(raw) == 16:
        return raw
    try:
        text = raw.decode('ascii').strip()
        key = bytes.fromhex(text) if len(text) == 32 else b''
    except (UnicodeError, ValueError):
        key = b''
    if len(key) != 16:
        raise ValueError('Key file must contain 16 binary bytes or 32 hex characters')
    return key


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('image',type=Path)
    p.add_argument('output',type=Path)
    p.add_argument('--disc-key-file',type=Path,required=True)
    p.add_argument('--common-key-file',type=Path,required=True)
    p.add_argument('--toolkit',type=Path,default=Path('artifacts/world_reference/toolkit'))
    p.add_argument('--select',help='Java regex matched against full disc paths; absent means index only')
    a=p.parse_args()
    record=json.loads(a.image.with_suffix(a.image.suffix+'.verified.json').read_text())
    if not record.get('verified') or a.image.stat().st_size != record['bytes']:
        p.error('Image lacks a matching verification record; run prepare_wux.py first')
    h=hashlib.sha256()
    with a.image.open('rb') as f:
        while chunk:=f.read(8*1024*1024):h.update(chunk)
    if h.hexdigest()!=record['sha256']:
        p.error('Image changed after verification')
    disc,common=read_key(a.disc_key_file),read_key(a.common_key_file)
    jar=a.toolkit/'JWUDTool-0.4.jar'
    source=Path(__file__).with_name('DiscAssetIndex.java')
    subprocess.run(['javac','-cp',str(jar),'-d',str(a.toolkit),str(source)],check=True)
    cp=str(a.toolkit)+':'+str(jar)
    command=['java','-Xmx1024m','-cp',cp,'DiscAssetIndex',str(a.image.resolve()),str(a.output.resolve())]
    if a.select:command.append(a.select)
    result=subprocess.run(command,input=disc+common,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    log=result.stdout.decode(errors='replace')
    for key in (disc,common):
        for value in (key.hex(),key.hex().upper()):log=log.replace(value,'[redacted]')
    a.output.mkdir(parents=True,exist_ok=True)
    (a.output/'index_reader.log').write_text(log)
    print(log)
    if result.returncode:
        raise SystemExit(result.returncode)
    (a.output/'source.json').write_text(json.dumps({'image':str(a.image.resolve()),'sha256':h.hexdigest(),'selection':a.select,'key_contents_recorded':False},indent=2))

if __name__=='__main__':main()
