import os, subprocess
src = "/Users/kiwimango/Downloads/New Folder With Items/"
dst = "/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/d8726f05-a14a-44ac-97c9-351a2e11c5c5/scratchpad/thuyvan_plan/view/"
os.makedirs(dst, exist_ok=True)
for f in sorted(os.listdir(src)):
    if f.endswith(".png"):
        out = dst + f.replace(".png", ".jpg").replace("(", "_").replace(")", "")
        subprocess.run(["sips", "-Z", "1400", "-s", "format", "jpeg", src + f, "--out", out], capture_output=True)
        print(out)
