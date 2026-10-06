#!/bin/zsh
# Fetch the two OFL candidate families for Thủy Vân's lettering from their official source, google/fonts on GitHub,
# into assets/fonts/<folder>/ with each family's OFL.txt beside its files:
#
#     zsh tools/thuyvan_art/fonts/fetch_fonts.sh            # both families
#     zsh tools/thuyvan_art/fonts/fetch_fonts.sh notoserif  # one
#
# The owner allowed ONE shipped family (owner_answers item 2, 2026-10-05). Fetch both to compare on the strip
# (tools/thuyvan_art/fonts/font_compare.py), then delete the folder that loses before committing.
#
# Pinned: the google/fonts commit is resolved once, written to assets/fonts/<folder>/FETCHED.txt with each file's
# sha256, so a rebuild can check it got the same bytes (FONTS_REF=<sha> pins a run to an earlier commit).
# Only static TTFs at weights 400/500/600/700 (upright and italic) are taken when the folder has them; a folder that
# ships only variable files ("[wght]" in the name) gets those (UiFonts.bundled() drives the wght axis).
set -euo pipefail

REPO=${0:A:h:h:h:h}
API=https://api.github.com/repos/google/fonts
REF=${FONTS_REF:-$(curl -fsSL "$API/commits/main" | python3 -c 'import json,sys; print(json.load(sys.stdin)["sha"])')}
FAMILIES=(${@:-bevietnampro notoserif})
DATE=$(date -u +%Y-%m-%d)

for fam in $FAMILIES; do
  dest="$REPO/assets/fonts/$fam"
  mkdir -p "$dest"
  listing=$(curl -fsSL "$API/contents/ofl/$fam?ref=$REF")
  files=("${(@f)$(print -r -- "$listing" | python3 -c '
import json, re, sys
items = [i["name"] for i in json.load(sys.stdin) if i["type"] == "file"]
want = r"-(Regular|Italic|Medium|MediumItalic|SemiBold|SemiBoldItalic|Bold|BoldItalic)\.ttf$"
static = [n for n in items if re.search(want, n)]
variable = [n for n in items if n.endswith(".ttf") and "[" in n]
keep = static or variable
if "OFL.txt" not in items or not keep:
    sys.exit("no OFL.txt or no TTFs in the folder")
print("\n".join(["OFL.txt"] + keep))
')}")
  : > "$dest/FETCHED.txt"
  print "source: https://github.com/google/fonts/tree/$REF/ofl/$fam" >> "$dest/FETCHED.txt"
  print "licence: SIL Open Font License 1.1 (OFL.txt in this folder)" >> "$dest/FETCHED.txt"
  print "fetched: $DATE" >> "$dest/FETCHED.txt"
  for f in $files; do
    url="https://raw.githubusercontent.com/google/fonts/$REF/ofl/$fam/${f//\[/%5B}"
    url=${url//\]/%5D}
    curl -fsSL "$url" -o "$dest/$f"
    print "$(shasum -a 256 "$dest/$f" | cut -d' ' -f1)  $f" >> "$dest/FETCHED.txt"
  done
  grep -q "SIL OPEN FONT LICENSE" "$dest/OFL.txt" || { print -u2 "$fam: OFL.txt is not the OFL"; exit 1; }
  print "$fam: ${#files} files at google/fonts@${REF[1,10]}"
done
