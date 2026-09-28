"""Re-bakes the stylized face's painted maps (lib/paint.py) from the cached source that
body/body.py writes (tools/character/cache/paint_src_v1.npz), with plain python3 (numpy):

    python3 tools/character/paint_bake.py [--out DIR]

Writes assets/character/body/paint_head.png and paint_lines.png (or into DIR). The body build
(build_character.sh --body) bakes them too; this is for tuning the paint without a rebuild.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from lib import paint as PT  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "..", "..", "assets", "character", "body"))
    a = ap.parse_args()
    Vbase, Vsty, F, mucosa, head_tris, K = PT.load_source()
    head, lines = PT.bake_maps(Vbase, Vsty, F, K, mucosa, head_tris)
    os.makedirs(a.out, exist_ok=True)
    print(PT.write_png(os.path.join(a.out, "paint_head.png"), head))
    print(PT.write_png(os.path.join(a.out, "paint_lines.png"), lines))


if __name__ == "__main__":
    main()
