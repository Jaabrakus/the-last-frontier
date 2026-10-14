# Fonts (Thủy Vân)

Free fonts under the SIL Open Font License 1.1, each family in its own folder with its `OFL.txt` beside the files.
The owner allowed one free OFL family on 2026-10-05; the one shipped is Be Vietnam Pro (the reason, and how to
rebuild, in `docs/thuyvan/fonts.md`). Fetched with `tools/thuyvan_art/fonts/fetch_fonts.py`, which pins the
google/fonts commit and checks each file's blob hash; nothing here is modified. Under the OFL the fonts may be bundled
with the game; they may not be sold on their own, and a modified version may not use the reserved names.

| Folder | Family | Files | Source | Licence | Fetched |
| --- | --- | --- | --- | --- | --- |
| `bevietnampro/` | Be Vietnam Pro (Be Vietnam Pro Project Authors, github.com/bettergui/BeVietnamPro) | `BeVietnamPro-{Regular,Italic,Medium,MediumItalic,SemiBold,SemiBoldItalic,Bold,BoldItalic}.ttf` (static, 459 glyphs each), `OFL.txt` | https://github.com/google/fonts/tree/7085eb89a950e85db5b166b7a58d414544b4140c/ofl/bevietnampro | SIL OFL 1.1 (`bevietnampro/OFL.txt`) | 2026-10-05 |

All eight faces carry all 134 precomposed Vietnamese letters, the game's punctuation and every character in
`data/thuyvan/*.json` (`tools/thuyvan_art/fonts/font_compare.py`, using T2's `tools/fonts/font_cmap_check.py`).

Not shipped: Noto Serif (https://github.com/google/fonts/tree/7085eb89a950e85db5b166b7a58d414544b4140c/ofl/notoserif,
SIL OFL 1.1), the other candidate, fetched only outside the repo for the comparison strip.
