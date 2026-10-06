#!/usr/bin/env python3
"""Fetch Thủy Vân's free font (SIL Open Font License 1.1) from its official source, pinned and verified:

    python3 tools/thuyvan_art/fonts/fetch_fonts.py [--check] [--candidates <folder outside the repo>]

The owner said yes to one free OFL family (2026-10-05). The one shipped is Be Vietnam Pro (a sans drawn in Vietnam
for Vietnamese), into assets/fonts/bevietnampro/ with its OFL.txt; the reason is in docs/thuyvan/fonts.md. Noto Serif,
the other candidate, is fetched only with --candidates, into a folder outside the repo, for the comparison strip
(font_compare.py --candidate-dir); it is not shipped.

Source: the google/fonts repository, folders ofl/bevietnampro and ofl/notoserif, at the commit pinned below. Each file
is checked against the blob hash GitHub lists for it at that commit (sha1 of "blob <size>\\0" + bytes), so a re-run
either gives the same bytes or fails. Be Vietnam Pro ships static faces there (Regular, Medium, SemiBold, Bold and
their italics are taken; Thin to Light and ExtraBold to Black are left out); Noto Serif ships only variable files.

--check verifies the files already on disk and downloads nothing.
"""

import argparse
import hashlib
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
DEST = os.path.join(REPO, "assets", "fonts")
## google/fonts main at 2026-10-05T18:00:35Z.
COMMIT = "7085eb89a950e85db5b166b7a58d414544b4140c"
RAW = "https://raw.githubusercontent.com/google/fonts/%s/ofl/%s/%s"
## folder -> {file: blob sha1 prefix at COMMIT}. SHIPPED goes to assets/fonts; CANDIDATES only with --candidates.
SHIPPED = {
    "bevietnampro": {
        "BeVietnamPro-Regular.ttf": "dfa34c09fe",
        "BeVietnamPro-Italic.ttf": "d9d0134f41",
        "BeVietnamPro-Medium.ttf": "d6deb87afd",
        "BeVietnamPro-MediumItalic.ttf": "dea22c6ac0",
        "BeVietnamPro-SemiBold.ttf": "b25bad31fe",
        "BeVietnamPro-SemiBoldItalic.ttf": "7f55bb760f",
        "BeVietnamPro-Bold.ttf": "52aadc6da0",
        "BeVietnamPro-BoldItalic.ttf": "7e22a2d7e1",
        "OFL.txt": "9e2c1177b1",
    },
}
CANDIDATES = {
    "notoserif": {
        "NotoSerif[wdth,wght].ttf": "7664d59c95",
        "NotoSerif-Italic[wdth,wght].ttf": "0e60f3e924",
        "OFL.txt": "6843f31878",
    },
}


def blob_sha(data):
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="verify the files on disk only")
    ap.add_argument("--candidates", help="also fetch the unshipped candidates into this folder (outside the repo)")
    args = ap.parse_args(argv)
    jobs = [(DEST, SHIPPED)]
    if args.candidates:
        jobs.append((os.path.abspath(args.candidates), CANDIDATES))
    bad = []
    for dest, group in jobs:
        for folder, files in group.items():
            os.makedirs(os.path.join(dest, folder), exist_ok=True)
            for name, want in files.items():
                path = os.path.join(dest, folder, name)
                if not args.check and not os.path.exists(path):
                    url = RAW % (COMMIT, folder, name.replace("[", "%5B").replace("]", "%5D").replace(",", "%2C"))
                    subprocess.run(["curl", "-sSfL", "-o", path, url], check=True)
                if not os.path.exists(path):
                    bad.append(name + " (missing)")
                    continue
                with open(path, "rb") as f:
                    got = blob_sha(f.read())
                ok = got.startswith(want)
                print("%-4s %s/%s  %s" % ("OK" if ok else "BAD", folder, name, got[:10]))
                if not ok:
                    bad.append(name)
    if bad:
        print("FETCH FAILED: " + ", ".join(bad))
        return 1
    print("fonts verified at google/fonts@%s" % COMMIT[:10])
    return 0


if __name__ == "__main__":
    sys.exit(main())
