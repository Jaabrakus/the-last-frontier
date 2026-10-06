import os
from PIL import Image, ImageDraw
src = "/Users/kiwimango/Downloads/New Folder With Items/"
files = sorted(f for f in os.listdir(src) if f.endswith('.png'))
W = 640
thumbs = []
for f in files:
    im = Image.open(os.path.join(src, f)).convert('RGB')
    h = int(im.height * W / im.width)
    thumbs.append((f, im.resize((W, h))))
cols = 4
rows = (len(thumbs) + cols - 1) // cols
H = max(t.height for _, t in thumbs) + 24
sheet = Image.new('RGB', (cols * W, rows * H), 'white')
d = ImageDraw.Draw(sheet)
for i, (f, t) in enumerate(thumbs):
    x, y = (i % cols) * W, (i // cols) * H
    sheet.paste(t, (x, y + 24))
    d.text((x + 4, y + 4), f, fill='black')
out = "/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/d8726f05-a14a-44ac-97c9-351a2e11c5c5/scratchpad/thuyvan_plan/sheets_contact.jpg"
sheet.save(out, quality=80)
print(out, sheet.size)
