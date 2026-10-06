"""Crop details from the owner's concept sheets for the art-direction reference boards.

usage: python3 crop.py SPEC_FILE   (each line: name sheet x0 y0 x1 y1 scale)
"""
import os
import sys
from PIL import Image

S = "/Users/kiwimango/Downloads/New Folder With Items/"
O = os.path.join(os.path.dirname(os.path.abspath(__file__)), "crops")
os.makedirs(O, exist_ok=True)

for line in open(sys.argv[1]):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split("|")
    n, sh = parts[0].strip(), parts[1].strip()
    x0, y0, x1, y1, sc = [float(v) for v in parts[2].split()]
    im = Image.open(S + sh).convert("RGB").crop((int(x0), int(y0), int(x1), int(y1)))
    im = im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS)
    p = os.path.join(O, n + ".png")
    im.save(p)
    print(p, im.size)
