# Playable asset lab

Open `scenes/labs/extracted_assets_lab.tscn` in Godot 4.7.2 and press F6, or run
`tools/reference_world/play_asset_lab.command` on this Mac. This scene is separate
from the main menu and the main game. It uses the current `FrontierPlayer`, native
weapon sockets, `PlayerAnim`, `GatherTools`, and `SwayCaster`.

F1 opens/closes the lab controls; Esc releases the cursor. Click outside the panel
to resume camera control. WASD moves, Space jumps, Shift sprints. Keys 1–5 select
sword, spear, bow, tomahawk, and spells. The buttons teleport between the terrain
map and test arena. The control panel selects the body/hands comparison, three
project clothing fits, the element, and a spell from that element's current kit.
Hold and release LMB for the quick spell; hold and release RMB for the selected
spell. The normal lock ring shows casting progress. Two dressed sparring partners
test weapon contact; a stationary game player is a supported target for actual
spell damage and knockback. The hit counter includes both types of target.

## Actual assets and scope

| Lab component | Actual input |
| --- | --- |
| Terrain map | Extracted raw `5000000000.hght`, SHA-256 checked before loading; centered 65×65 crop with original 16-bit samples normalized to 0–6 m over 64 m. Source world scale and registration remain unverified. |
| Current body + fitted hands | Project body with the converted source hand geometry fitted to the project's canonical 291-bone bind. Native hand triangles are removed from an instance copy; original mesh resources remain unchanged. |
| Fitted reference body | Converted Link and Armor_Default geometry fitted to the current rig, including the available lower-body pieces, belts, pouches and hair. Face/hair helper animation and unsupported source joints have documented weight fallbacks. |
| Clothing reference stand | Actual NPC Gerudo Hero Low clothing surfaces with their decoded source textures, on their own source skeleton. These are display references; they are not fitted interchangeable Link tunics. |
| Arrow reference stand | Actual Arrow_001 geometry with its three decoded source textures. |
| Three interchangeable clothing fits | Existing project garments: a closed Earth tunic with fitted Fire trousers and Water boots for the blue fit, an Earth green traveler fit, and a sleeveless Fire training fit. They are worn by the current/hybrid or fitted reference body; they are not extracted source tunics. Available source starter pieces remain underneath the reference clothing fit. |
| Sword, spear, bow, tomahawk | Existing project weapons, with the project's native draw, grip, aim, attack/throw and stow logic. These are not extracted Zelda weapons. |
| World textures | Actual decoded source terrain grass (`MaterialAlb` array layer 0), dirt (layer 10), gray cliff, mossy bark, tree leaves and grass blades. Original paths, layer indices, dimensions and hashes are retained in `artifacts/world_reference/world_textures/manifest.json`. |
| Trees, rocks, grass, arena and placement | Project vegetation/rock geometry, authored meadow grass and a non-colliding backdrop, plus an independently arranged stone arena. The decoded world textures are applied through lab materials and authored UV/triplanar mapping. No source world-object placements or original material assignment are claimed. |

The inventory checked the disc catalogue, every top-level pack's model member
names, and three selected armor texture bundles. No tunic, sword or spear geometry
was located within that documented scope. The three armor bundles parsed contain
textures and zero models. See the retained
`artifacts/world_reference/character_outfits/outfit_inventory.json` for exact scope;
this does not establish that every possible resource in every texture bundle was
parsed.

All converted reference files retain their actual source attribution and hashes in
the adjacent manifests. This lab makes no animation ownership claim. The animation
records remain in `animations/SOURCE.md` and `docs/animation_provenance.md`.

## Runtime isolation and limitations

The lab builds a player without loading the saved appearance or creating the main
HUD/customizer, then enables its normal local input. Outfit changes stay on this
instance; the scene does not write appearance files or game saves. Current and
full-reference `CharacterBodyMesh` modifiers are mutually exclusive. Weapon
selection respects native stow/draw stages and cancels an obsolete pending choice.
Keyboard movement and casting input are gated while the cursor is released for
the controls panel; the resume click clears fire/aim so it does not also attack.
Teleporting clears the prior fall accumulator. Reset/recover uses the native
respawn and status reset paths to recover the player and spell target.

Reference GLBs, world PNG textures and the raw height file live in ignored
`artifacts/` and are loaded directly through `GLTFDocument`/`Image`/`FileAccess`.
They must be present locally for these
comparisons. Missing character references fall back to the current body; missing
or changed height data is reported as a flat fallback in the world report.

The lab starts with the project's character and the fitted-hand comparison. The
full reference body remains an optional fit comparison and uses an authored three-band
toon material on its original source surfaces. Source albedo textures, UVs and
alpha cutouts are retained; original material objects are retained by the
per-instance shader overrides. This is a new presentation shader, not the source
game's original renderer. The world uses the decoded Zelda grass, dirt, stone,
bark, leaf and blade textures. Their material placement and mapping are authored
for our geometry; the source leaf RGB uses the project's existing card mask.
Lighting, linear vertex-color handling and vegetation are adjusted only in this
lab. See `docs/asset_lab_world.md` for the exact source and material scope.

The fitted hands retain a small wrist seam/color difference. Existing garment
shoulder/elbow gaps are visible in both the baseline and hybrid comparison. The
full reference body is an experimental fit; its unsupported face/hair motion,
floor fit, and clothing intersections need further work. The lab tests the
existing combat pipeline; it does not supply new sword/spear combat clips.

The terrain collider follows Godot's centered one-metre
[HeightMapShape3D grid](https://docs.godotengine.org/en/latest/classes/class_heightmapshape3d.html)
and shares the rendered float heights. Reading raw 16-bit samples avoids the
8-bit PNG import loss documented there. Mesh construction follows
[ArrayMesh](https://docs.godotengine.org/en/latest/classes/class_arraymesh.html);
weapons retain the existing
[BoneAttachment3D](https://docs.godotengine.org/en/latest/classes/class_boneattachment3d.html)
hierarchy.

## Validation

Run the focused integration checks with:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . \
  -s tools/reference_world/test_assets_lab.gd -- check=1
```

Run that tool without `--headless`, with `render=1`, for offscreen rendered proof.
The generated test report and captures are in
`artifacts/world_reference/character_fit/lab_preview/`. Structural fitting reports and
casting/weapon close-ups are under `artifacts/world_reference/character_fit/`.
