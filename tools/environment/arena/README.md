# The arena in Blender (2026-10-16)

The owner: "we can build a new and better arena with a headless blender"; "we don't need the tree bark we can just build
our own"; then "the floor can be different it can be like earth not the wood ... closer to the water maybe a oval shape".

`arena_board.py` builds the Tidebreak ring in Blender 5.2 from `data/ring/ring.json`'s own numbers (the 14 x 34 m deck
and its zones, the tank 10 m round it, the walk, six tiers of stands, the end walls and gates, the grates, the water
curtain at the tank's edge) and renders it headless with Eevee, several ways, for the owner to pick from. Every material
is Blender's own procedural nodes (brick, noise, voronoi, wave); every prop is a primitive of the script; nothing is
loaded from disk, so nothing third party is in it.

    zsh tools/loop/blender_run.sh -b --factory-startup --python tools/environment/arena/arena_board.py -- \
        --out <dir> [--looks all|oval_ruin,rect_ruin,...] [--px 1600x900] [--samples 24] [--sheet]

Variants: `oval_<look>` (an ellipse of the deck's length and width, earth and stone floors, the water 2 m under the deck)
and `rect_ruin` (the rules' rectangle for comparison). Looks: ruin (a lake plateau, earth), harbour (water, evening),
crater (fire, dusk), cliff (air, sea haze). `--sheet` writes `board.png`, the renders side by side.

The owner picked **ruin and crater** (2026-10-16). `arena_build.py` builds those for the game: each look's procedural
materials baked to 1024 px tiles (Cycles; colour as jpg, normal as png, roughness; a glow tile where it glows), the meshes'
UVs box-projected at 4 m a tile, the vertex tints as COLOR_0, and the scene written as glTF for each deck size:

    zsh tools/loop/blender_run.sh -b --factory-startup --python tools/environment/arena/arena_build.py -- \
        --out assets/arena --looks ruin,crater --sizes 14x34:5,12x28:4 [--px 1024] [--samples 16]

→ `assets/arena/<look>/arena_14x34.gltf`, `arena_12x28.gltf` and `tex/` (shared by the look's sizes; about 12 MB a look).
The water, the curtain's sheet and the lanterns are left out: the game draws its own. After a build, re-import
(`zsh tools/play.sh` does, or `Godot --headless --import`).

In the game: `data/ring/ring.json` `arenas` (an overlay over the rule set's and the format's numbers: the water 2 m under the
deck, the shape oval, which parts of RingDressing stay, the water's colours); `RingArena.set_arena` from `MatchSetup.arena`
(the match setup's ARENA chips beside the light, the Esc menu's Arena row, the user arg `arena=`). An oval arena's lip is
the ellipse of the deck's length and width everywhere the rules read it (`inside_deck`, `clamp_inside`, `edge_x`,
`nearest_lip`, the colliders a convex slice a zone, the bots' clamps). `tests/ring/test_arena_shape.gd` plays a game on it.
Sizes not built yet (2v2 20x40, 4v4 28x52) fall back to the classic deck.
