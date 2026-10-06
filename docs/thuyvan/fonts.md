# Thủy Vân lettering: the one OFL family

The owner allowed one free OFL family with full Vietnamese (owner answers, item 2, 2026-10-05): Be Vietnam Pro or
Noto Serif, picked by eye on a strip, shipped with its OFL.txt and a SOURCE.md row.

## Status (2026-10-06)

- The tools are in: `tools/thuyvan_art/fonts/fetch_fonts.sh` (fetch from google/fonts, pinned commit, sha256 list)
  and `tools/thuyvan_art/fonts/font_compare.py` (the comparison strip, with the cmap check from
  `tools/fonts/font_cmap_check.py`).
- **The families are not fetched yet.** The agent that built this did not have the user's go-ahead for a download
  in its own session, so `assets/fonts/` is still empty. The strip now shows the system fonts with two empty
  candidate cards. Today's system fonts (Baskerville and Avenir Next) both pass the cmap check, with ink outside the
  line box at 0.111 em and 0.075 em.

## Rebuild

    zsh tools/thuyvan_art/fonts/fetch_fonts.sh                 # assets/fonts/bevietnampro, assets/fonts/notoserif
    python3 tools/thuyvan_art/fonts/font_compare.py --out <folder>
    python3 tools/fonts/font_cmap_check.py --strict --font assets/fonts/<folder>/<file>.ttf

`fetch_fonts.sh` takes the static Regular, Medium, SemiBold and Bold files, upright and italic, when the folder
has them. Otherwise it takes the variable `[wght]` files; Noto Serif's folder ships only variable files, and
`UiFonts.bundled()` already handles those. It writes `FETCHED.txt` in each folder with the commit, the date and the
hashes. After the pick, delete the losing folder: only one family ships.

## SOURCE.md row to add with the files (assets/fonts/SOURCE.md)

| Path | What | Source | Licence | Date |
|---|---|---|---|---|
| assets/fonts/<folder>/ | <Family> static TTFs (Regular/Medium/SemiBold/Bold + italics) | https://github.com/google/fonts/tree/<sha>/ofl/<folder> (sha in FETCHED.txt) | SIL OFL 1.1, OFL.txt beside the files | <fetch date> |

## The pick (provisional until the strip shows both)

Be Vietnam Pro for the sans role. Vietnamese type designers drew it for Vietnamese, so its stacked tone marks
(Ể Ỗ Ặ) are part of the design rather than a later add-on. The sans role covers the HUD, menus and body text,
which is most of what a player reads. The system serif (Baskerville, already complete) stays for titles, which
keeps us at the one family the owner allowed. Pick Noto Serif instead only if the strip shows Be Vietnam Pro
clashing with the painted world at title sizes. Confirm by eye once `font_compare.py` draws both cards.

## UiFonts (scripts/thuyvan/ui_fonts.gd) once the merge lands

`BUNDLED` already maps `"serif": "notoserif"` and `"sans": "bevietnampro"`, and it skips a folder that is not on
disk, so shipping either family needs no code change. Change only these:

1. In the header comment, replace `(none yet: free-licence fonts wait for the owner's go-ahead)` with
   `(Be Vietnam Pro for sans, OFL, the owner's yes of 2026-10-05; tools/thuyvan_art/fonts/fetch_fonts.sh)`.
2. In `LINE_GAP_EM`, set `"sans"` to the larger of 0.125 and the shipped family's overshoot from
   `font_compare.txt`, rounded up to 0.025 em.
3. If Noto Serif is chosen instead, the same edits apply to `"serif"`, with the header naming Noto Serif.
