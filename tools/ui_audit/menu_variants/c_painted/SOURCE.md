## SUPERSEDED 2026-10-10: the owner chose style B (scripts/ui/menu/broadcast_ui.gd); kept as a reference mock-up, not wired into the game.

# Menu style mock C, "Painted river": where its pictures come from

Everything in the mock screens (`artifacts/ui_audit/menu_variants/c_painted/*.png`) is made by
`tools/ui_audit/menu_variants/c_painted.gd` from this project's own scene, shaders and drawing code. Nothing was downloaded
and no third-party art is used. This folder has a `.gdignore`; the script reads these files with `Image.load_from_file`.

| File | What it is | Source |
|---|---|---|
| `make_ink.py` | Draws every piece below from code (numpy and Pillow, fixed seeds: a rebuild gives the same files) | Written for this mock |
| `ink_*.png` | Brush art as white ink with alpha, tinted by the mock: the four element glyphs, the ensō ring, the row swash, brush rules, chevrons, the life stamps | Painted by `make_ink.py` |
| `wash_karst.png` | An ink-wash river landscape (karst towers in mist, a sampan, reeds) for a scroll's foot | Painted by `make_ink.py` |
| `seal_tidebreak.png`, `chop_square.png` | The vermilion chop with a breaking wave cut out of it, and a bare square stamp | Painted by `make_ink.py` |
| `paper_tile.png`, `lacquer_tile.png` | Rice paper and black-red lacquer with gold dust, 512 px, tiling | Painted by `make_ink.py` |
| `rod_top.png`, `rod_foot.png` | The scroll's head stick and foot roller (dark wood, gold knobs; nine-patches) | Painted by `make_ink.py` |
| `edge_noise.png`, `noise_a/b/c.png`, `flake_noise.png` | Tileable noises for the paper's torn edge and the oil-paint shader | Painted by `make_ink.py` |
| `*.gdshader` | The paper, lacquer, gold-text and grade shaders | Written for this mock |
| `raw_*.png` | Renders of `scenes/ring.tscn` (our scene, our fighters, our light) through `tools/environment/offscreen_view.gd`, one per view and light: the mock's backdrops (about 63 MB; regenerable with `part=render`, git-ignored) | Our scene |

Fonts are the Mac's own (`SystemFont`), each checked at the start of a run for all 134 Vietnamese letters (the script prints
the missing ones); no font file is shipped.
