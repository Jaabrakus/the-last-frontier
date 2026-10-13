# Mud meshes (`mud.glb`)

Our own meshes, made 2026-10-12 for the guards' mud (the owner: "the water parry earth needs new blender effects it needs to look
like mud"): `tools/fx/blender/mud_meshes.py` builds them in Blender from metaballs (balls and ellipsoids melted together), roughens
them with Blender's own noise, maps UVs round each one's middle and exports one glb. Nothing is imported, traced or taken from
another asset; run the script again to rebuild them (the same `--seed`, the same shapes).

| Mesh | What it is | Used by |
| --- | --- | --- |
| `mud_blob` | a ball of mud about 1 m across, lumps pressed into it and three drips hanging from its underside | `BendLooks._molten_body` (a mud or magma bolt), `FormStone.pack_look` (a held or thrown mud or magma stone) |
| `mud_spear` | a spear of mud about 1.2 m long, its point on -Z, lumps and two drips along it | `BendLooks._mud_spear_body` (a water Turn's mud spear), `FormStone.pack_look` (a Spike turned to mud) |
| `mud_clod_a`, `mud_clod_b`, `mud_clod_c` | clods of two or three balls run together | `FissureFx` (the mud wave's crest and rows) |
| `mud_lump` | a squat wide lump with gloops on its top | `FissureFx` (the mud wave's crest) |

Their look is the game's own shaders: ToonFx `mud` and `magma` (the cel liquid, `shaders/bend_fx/toon_water.gdshader`).
