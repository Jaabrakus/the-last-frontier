# Tattoo designs and body map (the creator's Tattoos row)

The tattoos of the character creator (`Tattoos`, `TattooPanel`, `skin.gdshader` through `tattoo.gdshaderinc`; the
owner, 2026-10-03: "also we need tattoos"). Everything here is the project's own work: no image, font, tracing,
flash sheet or photograph was downloaded, imported or copied. Every design is written as geometry in code and
rendered by our own build.

- `tools/character/tattoos/make_designs.py` draws each design as line art (circles, polygons and hand-placed Bézier
  curves computed in the script; the roses and spirals by trigonometry) into `tools/character/tattoos/designs/<id>.svg`
  (white ink on transparency in a 512 px box). Written 2026-10-03.
- `tools/character/tattoos/build_tattoos.gd` rasterizes the SVGs with Godot's own SVG loader into
  `tattoo_atlas.png` (a 4 x 4 grid of 256 px cells of ink coverage, L8). A figure that reaches into its box's margin
  (44 px of 512: the atlas's mip levels must not bleed into the next cell) is drawn smaller about the box's centre;
  the build prints the scale (2026-10-03: compass rose 0.86, ship 0.88, the Drift's waves 0.89, keelstone star 0.92,
  mermaid 0.93, anchor and wind spiral 0.96, heart 0.98). Only the offered designs (`designs`) are drawn: the held
  ones' cells stay empty.
- The same script measures `tattoo_map.json` on `assets/character/body/body.glb`: the torso's arc map and each
  place's centre and frame (see its header). Rebuild it whenever the body changes.

```
python3 tools/character/tattoos/make_designs.py
Godot --headless --path . -s tools/character/tattoos/build_tattoos.gd      # [-- atlas | map]
Godot --headless --path . --import                                       # the new atlas
```

Licence: the project's own, like the rest of its art.

## The designs

The ids, atlas cells and default places are `data/customizer/tattoos.json` "designs". Everyone may wear every
design from the start (the owner, 2026-10-03: "give everyone the ability to wear anything").

| Id | Cell | Label | What is drawn |
| --- | --- | --- | --- |
| `anchor` | 0 | Anchor | An anchor with ring, ball-ended stock, shank, curved arms and barbed flukes, fouled with a cable |
| `compass_rose` | 1 | Compass rose | Eight points, each half filled and half open, two rings with ticks, a lozenge over north |
| `heart` | 2 | Heart | A heart pierced by an arrow, shaded on one side |
| `ship` | 4 | Ship | A three-masted ship under square sail on the swell, side view |
| `initials_date` | 5 | Initials and year | "W·H" over "1757" in plain serifed capitals, a rule and a lozenge between |
| `mermaid` | 7 | Mermaid | A mermaid in profile on her curled, scaled tail, raising a looking-glass |
| `keelstone_star` | 8 | Keelstone star | The sky crews' mark: a cut keelstone in a four-pointed star, small stars, a keel line |
| `wind_spiral` | 9 | Wind spiral | The sky crews' mark: a spiral of wind with streaming lines |
| `drift_waves` | 10 | The Drift's waves | The sky crews' mark: two rows of curling crests under three stars |
| `band` | 11 | Plain band | A plain band (repeated round the limb) |
| `band_double` | 12 | Double band | Two narrow bands (repeated round the limb) |
| `dots` | 13 | Ring of dots | One dot (repeated round the limb: a ring) |

The sky crews' marks are our own fiction, from the Drift and its keelstone (`docs/main_story.md` §7). Cells 3 and 6
are empty (below).

### Held and dropped (2026-10-03 review)

| Id | Cell | Label | What is drawn | State |
| --- | --- | --- | --- | --- |
| `crucifix` | 6 | Crucifix | A Latin cross on three Calvary steps with its title board, rays behind | Held (`held_designs`): a sacred image. The owner decides whether it ships as a documented seaman's mark; if it does, the rule below is reworded to say so, the entry moves back to `designs` and the atlas is rebuilt. Its SVG is kept. |
| `crossed_keys` | 3 | Crossed keys | Two keys in saltire | Dropped: the keys of Saint Peter, the papal emblem, and not among the documented seamen's marks below. Its drawing and SVG are removed. |

The face is held too (`held_places`: cheek, brow). Face tattooing belongs to particular peoples (Māori tā moko,
Amazigh and Bedouin women's marks, Inuit, the Haudenosaunee and Lenape men of the period), and a cross on the brow is a
living practice of Ethiopian and Coptic Orthodox women (Ethiopian is a playable people), so no design goes on the face
until consultation. A saved tattoo at a held place moves to its design's own place; one of a held design is dropped.

## Period basis and certainty

The sailors' motifs are the common stock of European and colonial seamen's marks: anchors, hearts, crosses and
crucifixes, initials and dates, ships, mermaids (the crucifix is held, above). The best counts come from records made a
generation or more after 1757 (the United States' seamen's protection certificates from 1796, and later naval
description books), so for the 1750s the set is M to L in `docs/research/peoples_dress_1750s.md`'s terms. The design
notes in `tattoos.json` are the reporter's background knowledge (†), not re-checked against a source this session;
reword them if a check disagrees.
Inks: soot or gunpowder black, which heals blue-grey under the skin, and the rarer red (vermilion); an old mark spreads
and greys (the Fade setting).

## What is left out

No sacred or people-specific tradition is offered: no Polynesian or Māori designs (tatau, tā moko), no Indigenous North
American designs, no other living people's marks, no sacred images (the held crucifix) and nothing on the face. Those
are consultation matters (`docs/research/peoples_dress_1750s.md` §1.3, `docs/main_story.md` §10.8) and are not to be
added without it. The test (`tests/customizer/test_tattoos.gd`) checks the design list, labels and notes against a
deny-list of those words (tests/customizer/deny_words.gd), that nothing held is offered and that no place is on the face.
