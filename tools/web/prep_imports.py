"""The web snapshot's import settings made lighter (run by tools/web/prep_snapshot.sh on the snapshot, never the project):
big textures capped at 1024 px (process/size_limit), the cloth fabric arrays' sources halved (a texture array import has no
size limit), and the menus' pictures (assets/ui: paintings, lobby plates, the skill tree's backdrops, loading screens) lossy
WebP instead of lossless (46 MB of the pack), and every sound QOA (Godot's own compressed audio, about 3 bits a sample;
the bending sounds were 16-bit PCM). The next `Godot --import` re-imports what changed.
    python3 -I tools/web/prep_imports.py <snapshot dir>
"""
import os
import re
import subprocess
import sys

SIZE_LIMIT = {
    'assets/environment/structures/textures/fieldstone_albedo_2k.png': 1024,
    'assets/environment/structures/textures/fieldstone_arm_2k.jpg': 1024,
    'assets/environment/structures/textures/fieldstone_nor_gl_2k.jpg': 1024,
    'assets/environment/structures/textures/boards_weathered_albedo_2k.png': 1024,
    'assets/environment/structures/textures/boards_weathered_arm_2k.png': 1024,
    'assets/environment/structures/textures/boards_weathered_nor_gl_2k.png': 1024,
    'assets/environment/sky/qwantani_late_afternoon_nosun_2k.exr': 1024,
    'assets/character/body/body_detail.png': 1024,
}
# Lossless pictures under these folders (2D, never in 3D: no VRAM compression) made lossy at this quality.
LOSSY_DIRS = ['assets/ui/']
LOSSY_QUALITY = 0.85
# Texture arrays (9 slices stacked): halved on disk.
HALVE = ['assets/character/fabrics/fabric_detail.jpg', 'assets/character/fabrics/fabric_normal.jpg']


def main(snap: str) -> int:
    if os.path.basename(os.path.normpath(snap)) == 'Frontier' or not os.path.exists(os.path.join(snap, 'project.godot')):
        print('not a snapshot:', snap)
        return 1
    for rel, px in SIZE_LIMIT.items():
        p = os.path.join(snap, rel + '.import')
        t = open(p).read()
        t2 = re.sub(r'^process/size_limit=\d+$', 'process/size_limit=%d' % px, t, flags=re.M)
        if t2 != t:
            open(p, 'w').write(t2)
            print('size_limit %d: %s' % (px, rel))
    for d in LOSSY_DIRS:
        for dirpath, _, files in os.walk(os.path.join(snap, d)):
            for fn in files:
                if not fn.endswith('.import'):
                    continue
                p = os.path.join(dirpath, fn)
                t = open(p).read()
                if 'importer="texture"' not in t or not re.search(r'^compress/mode=0$', t, flags=re.M):
                    continue
                t = re.sub(r'^compress/mode=0$', 'compress/mode=1', t, flags=re.M)
                t = re.sub(r'^compress/lossy_quality=[0-9.]+$', 'compress/lossy_quality=%s' % LOSSY_QUALITY, t, flags=re.M)
                open(p, 'w').write(t)
                print('lossy: %s' % os.path.relpath(p, snap)[:-7])
    for dirpath, _, files in os.walk(os.path.join(snap, 'audio')):
        for fn in files:
            if not fn.endswith('.wav.import'):
                continue
            p = os.path.join(dirpath, fn)
            t = open(p).read()
            t2 = re.sub(r'^compress/mode=[01]$', 'compress/mode=2', t, flags=re.M)
            if t2 != t:
                open(p, 'w').write(t2)
                print('qoa: %s' % os.path.relpath(p, snap)[:-7])
    for rel in HALVE:
        p = os.path.join(snap, rel)
        out = subprocess.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', p], capture_output=True, text=True).stdout
        w = int(re.search(r'pixelWidth: (\d+)', out).group(1))
        h = int(re.search(r'pixelHeight: (\d+)', out).group(1))
        if w <= 512:
            continue
        subprocess.run(['sips', '-z', str(h // 2), str(w // 2), p], check=True, capture_output=True)
        print('halved %dx%d: %s' % (w, h, rel))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
