// Thủy Vân painted rock (style_guide.md 5.2 "Rock and karst"; the ROCK kit, tools/thuyvan_art/rock): karst towers,
// gorge walls, the Two Heights, the needle, boulders and the white stones. Moved here from the kit's own
// assets/thuyvan/rock/painted_rock.gdshader and extended; every rock material (assets/thuyvan/rock/materials, written by
// tools/thuyvan_art/rock/write_godot_materials.py) uses it.
//   paint     a triplanar of one painted tiling texture (`rock_tex`, `tile_m` m a tile: 16 m on karst, 6 m on boulders,
//             4 m on the white stones), its top (-V) up so strata run level on every face
//   vertex    multiplied by the kit's vertex colour RGB (baked occlusion x top light, 0.5-1.0, linear)
//   moss      `moss_tex` blended in by vertex colour A (the moss mask) on up-facing faces (smoothstep(0.55, 0.8, n.y)),
//             its edge breaking along the rock's darker strokes
//   normal    optional, soft: PAINT's stroke-height normal (OpenGL, same tile) at `normal_strength` (<= 0.3; 0 = off)
//   ranks     tv_rock_far.gdshader, the backdrop karst's fog steps (look_directions.json "karst_ranks": 15 / 35 / 60 /
//             80 % at 2-5 km): each instance's `rank_fog` replaces the scene fog on it with its rank's step toward
//             `rank_fog_color`, so the four ranks step paler and bluer whatever the exponential fog gives there
//   space     world (karst, cliffs, the needle: pieces side by side share one continuous paint) or object (ashlar, the
//             white stones, boulders: the pattern turns with the piece; its scale applied, so texel density holds)
// Lit, never unshaded: Lambert wrap, low specular, rough. No banded light.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/thuyvan/tv_rock.gdshaderinc"
