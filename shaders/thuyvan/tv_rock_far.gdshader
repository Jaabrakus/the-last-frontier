// Thủy Vân painted rock for the backdrop karst ranks (vista_spec.md D14-D15; style_guide.md 5.4 "Fog": the far karst
// layers fade in steps, 15 / 35 / 60 / 80 % fog at the four depth layers). The same paint as tv_rock.gdshader, but the
// scene's exponential fog is replaced on it by the instance's `rank_fog` (set per tower from look_directions.json
// "karst_ranks") toward `rank_fog_color` (the direction's fog colour, set by ThuyVanLook), so each rank steps paler and
// bluer at a fixed amount instead of by its exact distance.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

#define TV_RANK_FOG
#include "res://shaders/thuyvan/tv_rock.gdshaderinc"
