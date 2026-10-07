# UI icons

Drawn for this project (hand-written SVG, 2026-09-26): white line and fill art on transparency, tinted by the UI
(`modulate`). Skills (the three field skills of `data/gathering/gathering.json` and the ten frontier skills of
`data/survival/skills.json`), the four survival needs (`data/survival/needs.json`) and HUD glyphs (health, torch,
sun, moon). No third-party art.

Added 2026-09-27: `vice_cup` (a tankard: shown on the HUD only while merry) and `vice_pipe` (a clay pipe with its
smoke: while a pipe steadies the hands), for drink and tobacco (scripts/survival_game/vices.gd). Hand-written SVG, no
third-party art.

Added 2026-09-27: the lasting conditions (scripts/survival_game/lasting_conditions.gd), shown on the HUD only while one
holds: `need_wasted` (a gaunt rib cage: wasted by hunger), `need_ague` (a thermometer and shivers: the ague),
`need_festering` (a bandage and a drop: a festering wound), `need_flux` (a gut with a swirl: the flux) and
`need_sore_feet` (a footprint and its ache: sore feet). Hand-written SVG, no third-party art.

Added 2026-10-02: the spells' hotbar icons (the Sway, scripts/sway; the HUD's `spell_<id>`): `spell_earth_wall`,
`spell_stone_form`, `spell_pillar`, `spell_mend`, each the effect (a wall, a spike and a stone ball, a column, a post
and rails) over our own circle laid on the ground (a double ring, an inner ring, a square on its points), and `spell_gust`
(three strokes of wind with a curl). Hand-written SVG, no third-party art. (The Sway v2 dropped `spell_stone_spikes` and
`spell_shape_planks` with their spells, and `spell_levitate` when Gust took over lifting and hurling stones.)

Added 2026-10-06 (Tidebreak round 4, HUD): the ring's move icons, one per chip the key strip can show
(`spell_<id>__<mode>.svg`: every element's jab, guard, each key's two moves, the caught stone's return
`spell_stone_catch__return`, fire's grown `spell_fire_blast__fireball`, the Slams `spell_slam__<element>`, the air
dodge `spell_dodge__<element>`, the heals `spell_patch__patch` and `spell_mend__mend`) and the plates' element marks
(`spell_mark__<element>`). Drawn by hand as path data in `tools/ui/move_icons.py` (it writes them all), in the Form
spells' family: white round-capped strokes of 3.4, 2.8 and 1.6 on a 64 grid, tinted at draw time. One motif per
element: earth angular slabs and shards, water curls and crests, fire tongues, air spirals and arcs. No symbol of any
show or game, no nation marks, nothing traced; no third-party art. The five open-world spell icons above are untouched.
