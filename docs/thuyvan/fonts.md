# Thủy Vân's shipped font

## The pick: Be Vietnam Pro, for the sans role (HUD, menus, body text)

The owner allowed one free OFL family (2026-10-05). Be Vietnam Pro and Noto Serif were fetched from google/fonts and
set on T2's strip lines beside the system Baskerville and Avenir Next (`font_compare_strip.png`), and as a zone title
over the Trường Sơn sheet with a HUD line under it (`font_compare_context.png`, pairings D, A, B, C). Be Vietnam Pro
ships. It was drawn in Vietnam for Vietnamese: its tone marks are full-size and sit clear of the stacked circumflex
and breve (Ể Ỗ Ặ), and ơ and ư keep open horns at 14 px, where Avenir Next's marks turn small and crowd the letter. It is also the role
with the most at stake: the sans carries nearly all the game's text, and the system sans list is macOS-only at its head
(Avenir Next); on other platforms its tail is unverified. The serif role is for titles and names, which the sheets set
in a classical book serif. The system Baskerville already writes every Vietnamese letter there, and Georgia and Times
New Roman behind it do too. Noto Serif read sturdier than Baskerville at 14 px, but titles are set at 28 px and up,
where Baskerville is closer to the sheets' lettering (pairing D against A). Noto Serif would also add 4.3 MB of
variable font for a role that is already covered, so it does not justify a second family. If the owner later allows
two families, Noto Serif is ready to add. It passes the cmap check, keeps all ink inside its line box (0.000 em), and
`UiFonts.BUNDLED` already names its folder.

One cost: Be Vietnam Pro's line box is 1.0 em above the baseline, and its stacked capitals reach 0.29 em above that (at
14 to 40 px). The sans line gap must rise from 0.125 to 0.3 em, or stacked marks touch the line above. The current
system fonts need at most 0.14 em.

## Rebuild

    python3 tools/thuyvan_art/fonts/fetch_fonts.py                       # assets/fonts/bevietnampro, hash-checked
    python3 tools/thuyvan_art/fonts/fetch_fonts.py --check --candidates <tmp>/fontcands   # + Noto Serif outside the repo
    python3 tools/thuyvan_art/fonts/font_compare.py --out <look>/LOOK-FONT --candidate-dir <tmp>/fontcands \
        --backdrop "<concept sheets>/image-gen-4(1).png"

`fetch_fonts.py` pins google/fonts at `7085eb89a9` (2026-10-05) and fails if any file's blob hash differs.
`font_compare.py` imports T2's `tools/fonts/font_cmap_check.py` and `font_proof.py` (the same 134 letters, punctuation,
data characters and strip lines). It writes `font_compare.txt`/`.json` (the cmap and ink-outside-the-line-box results
per face) and the two images. It is deterministic.

## Wiring it in, once the Phase 1 merge lands (UiFonts is not edited here)

`scripts/thuyvan/ui_fonts.gd`:

- Line 7. Replace `## shipped under assets/fonts/<folder>/ (none yet: free-licence fonts wait for the owner's go-ahead) goes first, with`
  with `## shipped under assets/fonts/<folder>/ (Be Vietnam Pro for sans, the owner's one OFL family, 2026-10-05) goes first, with`.
- Line 19: `const BUNDLED := {"serif": "notoserif", "sans": "bevietnampro", "mono": ""}` becomes
  `const BUNDLED := {"serif": "", "sans": "bevietnampro", "mono": ""}`. No Noto Serif ships, so say so. The folder check
  already skips it.
- Line 26: `const LINE_GAP_EM := {"serif": 0.15, "sans": 0.125, "mono": 0.225}` becomes
  `const LINE_GAP_EM := {"serif": 0.15, "sans": 0.3, "mono": 0.225}`. Add a comment that Be Vietnam Pro's stacked
  capitals reach 0.29 em above its 1.0 em ascent (`tools/thuyvan_art/fonts/font_compare.py`).
- Line 72, in `bundled()`: `var want := String(STYLES.get(snappedi(clampi(weight, 100, 900), 100), "Regular"))` becomes
  `var want := String(STYLES.get(snappedi(clampi(weight, 400, 700), 100), "Regular"))`. Only 400 to 700 ship, so a
  300 or 800 request takes the nearest shipped face instead of falling through to Avenir Next mid-screen.

`assets/ui/thuyvan_theme.tres`. The sans becomes the shipped face, with the system list as its fallback:

    [gd_resource type="Theme" load_steps=6 format=3]

    [ext_resource type="FontFile" path="res://assets/fonts/bevietnampro/BeVietnamPro-Medium.ttf" id="1_bvp"]

    (SystemFont_sans, SystemFont_serif and SystemFont_mono unchanged)

    [sub_resource type="FontVariation" id="FontVariation_sans"]
    base_font = ExtResource("1_bvp")
    fallbacks = Array[Font]([SubResource("SystemFont_sans")])

    [resource]
    default_font = SubResource("FontVariation_sans")
    Label/constants/line_spacing = 6
    RichTextLabel/constants/line_separation = 6

Here 6 is `ceil(0.3 × 18)`. Title and Mono stay as they are.

The tests that read the theme expect a SystemFont for sans, so they follow:

- `tools/fonts/test_font_tools.py` `theme_values()`: for `default_font`, resolve the FontVariation's
  `fallbacks` SubResource to the SystemFont's names.
- `tests/thuyvan/test_vietnamese_glyphs.gd`, near line 145: when the role's font is a FontVariation, check its
  `base_font` for the letters, and check `fallbacks[0] as SystemFont` against `UiFonts.names(role)`.

Godot imports the `.ttf` files with the defaults: Antialiasing Grayscale, Hinting Light, Subpixel Positioning Auto,
Multichannel SDF off, Allow System Fallback on. Commit the `.import` files Godot writes next to them.
