shader_type spatial;
// Tidebreak's own forked lightning bolt shaded the way Spellbreak's lightning materials are (BendLooks.lightning, SB_BOLT).
//
// GEOMETRY (ours, unchanged): the strips ToonFx.lightning_strips builds for every bolt (the jagged main stroke and its
// forks; UV.x along a fork 0..1, UV.y across 0..1, UV2.x the half width, UV2.y how thick a fork is: 1 main, 0.45 a
// branch, 0.2 a twig), turned to face the camera the same way shaders/bend_fx/toon_bolt.gdshader does. Its path, forks,
// flicker (rebuilt a few times over its life) and timing are the pool's; only the shading is new.
//
// SHADING (Spellbreak, Proletariat; materials m_f_lightingToonErosion / M_LightingBoltToon_Uncompressed, instances
// MI_f_lightningBranchingBolt, _Bolt3, _Bolt4 as used by GauntletLightningMuzzle_FX (146) and Shock2StrikeNew_FX (152),
// and m_f_lightingtest_horiz's MI_LBoltProjectile_Beam (148); see shaders/cascade/fam_toon_mesh_lightning.gdshader and
// data/fx/cascade_families/toon_mesh_lightning.json for the family's evidence):
//  * "Lightning Bolt" texture T_f_GenericLighting_F (a strip of flat toon plateaus) read along the bolt; its UV pushed by
//    two panned noises ("Noise 1"/"Noise 2", T_f_SmokeHeight_Greyscale_Uncompressed) times "noise strength", and panned
//    along ("Lightning Vertical Panner" 1 x "Lightning Pan Speed" (0, 1)); every pan stepped at the material's FPS (15):
//    the crackle.
//  * MF_TransluscentToonErosion: the plateaus are cut by (1 - opacity) with a hard edge ("Edge Softness" 0.1), so a dying
//    bolt erodes from its fringe into its core instead of fading. (Authored: the cut follows the fade on a curve from the
//    fade's first frame, and the core's and sheath's levels rise as it dies, so it dies the way our cel bolt does: the core
//    first, then the sheath, the fringe eaten meanwhile.)
//  * Emissive = particle colour (HDR blue-violet: the emitters' ColorOverLife (2.5, 0, 30) / (0.78, 0, 30) /
//    (6.25, 2.48, 150)) x "Emissive Strength" 2 x the plateau: UE's tonemapper burns the top plateau to white. Here the
//    burn is explicit (the ring's AgX would push a saturated blue to grey, not white): the plateaus are banded into a
//    white-hot core, a pale lavender sheath and a blue-violet fringe.
// AUTHORED for our strips (not Spellbreak's): the across mapping (the texture's strip, u 0.441-0.559, laid across ours),
// the metres per tile, the bands' levels and colours, the wander (a small sideways push of the noise, kept inside the
// strip so the bolt's shape stays ours). Opaque with a hard cut (no veil, no sorting), the same pass as toon_bolt.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://shaders/bend_fx/fx_common.gdshaderinc"

uniform sampler2D bolt_tex : repeat_enable, filter_linear_mipmap;    // "Lightning Bolt" T_f_GenericLighting_F (linear)
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;   // "Noise 1"/"Noise 2" T_f_SmokeHeight_Greyscale_Uncompressed
uniform float fps = 15.0;                    // FPS (MI_f_lightningBranchingBolt3/4)
uniform float noise_strength = 0.3;          // noise strength (along, in tiles: 0.30 / 0.33 in the instances)
uniform float noise_size = 0.77;             // Noise Size Multiplier
uniform vec2 noise1_pan = vec2(1.0, 1.0);    // NOISE1_Hor/Vert_Panner Speed
uniform vec2 noise2_pan = vec2(1.0, 1.0);    // NOISE2_Hor/Vert_Panner Speed
uniform float pan = 1.0;                     // Lightning Vertical Panner x Lightning Pan Speed.y (tiles/s along)
uniform float edge_softness = 0.1;           // Edge Softness
// (authored for our strips)
uniform float spread = 1.45;                 // the strip drawn this much wider than the pool's (room for the wander)
uniform float tex_u0 = 0.5;                  // the texture's strip middle in u
uniform float tex_hw = 0.064;                // u per strip half width (the texture's strip is u 0.441-0.559: a bit narrower)
uniform float tile_m = 1.9;                  // metres of bolt per texture tile (the main stroke)
uniform float noise_m = 3.0;                 // metres of bolt per noise tile
uniform float wander = 0.35;                 // the sideways push of the noise, in strip half widths (forks and twigs)
uniform float wander_main = 0.15;            // the same on the main stroke (calmer: its core stays one stroke)
uniform float tex_gain = 1.32;               // the texture's top plateau (~0.76) brought to ~1
uniform float floor_cut = 0.14;              // the faint outer ramp never drawn (a crisp edge)
uniform float clean = 0.5;                   // 0 the texture's own silhouette, 1 our strip's smooth one (bands stay the texture's)
uniform float clean_main = 0.65;             // the same on the main stroke
uniform float band_clean_main = 0.6;         // the main stroke's bands taken this far toward the smooth profile (no split core)
uniform float spine = 0.18;                  // a white-hot spine down the middle (in strip half widths; 0 none)
uniform float twig_k = 0.78;                 // a twig's plateaus x this (thin forks keep less white core)
uniform vec3 c_fringe : source_color = vec3(0.34, 0.1, 1.0);
uniform vec3 c_sheath : source_color = vec3(0.56, 0.45, 1.0);
uniform vec3 c_core : source_color = vec3(1.0, 1.0, 1.0);
uniform float fringe_gain = 1.3;
uniform float sheath_gain = 2.0;
uniform float core_gain = 4.0;
uniform float band_sheath = 0.5;             // level (from the eroded edge to the top plateau) where the sheath starts
uniform float band_core = 0.88;              // level where the white core starts
// (the death, authored to read like our cel bolt's: the core goes first, then the sheath, while the cut eats the fringe)
uniform float cut_curve = 0.6;               // the erosion's cut = (1 - fade) ^ this x cut_reach: it bites from the first frame
uniform float cut_reach = 0.95;
uniform float core_die = 0.3;                // band_core + (1 - fade) x this: the white core is gone by fade ~0.6
uniform float sheath_die = 0.5;              // band_sheath + (1 - fade) x this
uniform float dim_die = 0.25;                // the colours x (1 - (1 - fade) x this)
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float fade = 1.0;           // 1 -> 0 over the end of its life (the erosion)
#else
instance uniform float fade = 1.0;           // 1 -> 0 over the end of its life (the erosion)
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float len_m = 8.0;          // the main stroke's length (metres along a fork)
#else
instance uniform float len_m = 8.0;          // the main stroke's length (metres along a fork)
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float seed = 0.0;           // a new pattern each time the bolt is rebuilt
#else
instance uniform float seed = 0.0;           // a new pattern each time the bolt is rebuilt
#endif
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float width_k = 1.0;        // the strip's width x this (a short crackle's thin forks)
#else
instance uniform float width_k = 1.0;        // the strip's width x this (a short crackle's thin forks)
#endif

varying float v_along;
varying float v_thick;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 w = strip_point(c, (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz, UV2.x * spread * width_k, UV.y, CAMERA_POSITION_WORLD);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	// a fork's length from its thickness (ToonFx.lightning_strips: a branch 0.1-0.28 of the stroke, a twig 0.06-0.14)
	float frac = UV2.y > 0.7 ? 1.0 : (UV2.y > 0.3 ? 0.19 : 0.1);
	v_along = UV.x * len_m * frac;
	v_thick = UV2.y;
}

void fragment() {
	if (near_cut(VERTEX, FRAGCOORD.xy)) {
		discard;
	}
	float t = floor(TIME * fps) / fps;
	float tile = tile_m * mix(0.45, 1.0, v_thick);
	float x = (UV.y * 2.0 - 1.0) * spread;               // +-1 at the pool's strip edge
	float n1 = texture(noise_tex, vec2(v_along / noise_m, 0.37 + seed) + noise1_pan * t * 0.25).r;
	float n2 = texture(noise_tex, vec2(v_along / noise_m, 0.71 - seed) * noise_size + noise2_pan * t * 0.25).r;
	float main_k = smoothstep(0.7, 0.95, v_thick);       // 1 on the main stroke, 0 on branches and twigs
	float xu = x + (n1 - 0.5) * mix(wander, wander_main, main_k) * 2.0;
	vec2 buv = vec2(tex_u0 + xu * tex_hw, v_along / tile + seed * 7.0 - pan * t + (n2 - 0.5) * noise_strength);
	float m = texture(bolt_tex, buv).r * tex_gain;
	m *= mix(twig_k, 1.0, clamp((v_thick - 0.2) / 0.8, 0.0, 1.0));
	// (clean: the outline taken toward a smooth profile across the strip, centred on the wander, so the silhouette is ours;
	// the bands inside stay the texture's)
	float prof = clamp(1.0 - abs(xu) * tex_hw / 0.059, 0.0, 1.0);
	float sil = mix(m, prof, mix(clean, clean_main, main_k));
	// MF_TransluscentToonErosion: the plateaus cut by (1 - opacity), a hard edge; the cut follows the fade from its first
	// frame on a curve (it thins as soon as it starts to die, not only at its very end)
	float die = 1.0 - clamp(fade, 0.0, 1.0);
	float cut = max(pow(die, cut_curve) * cut_reach, floor_cut);
	float op = clamp((sil - cut) / max(edge_softness, 0.002), 0.0, 1.0);
	if (op < 0.5) {
		discard;
	}
	// the bands measured from the eroded edge, so a dying bolt keeps its fringe round what is left; the spine (thinner on a
	// twig) keeps the core whole where the silhouette stands; on the main stroke the bands lean to the smooth profile (one
	// core, not parallel streaks); as it dies the core's and sheath's levels rise, so the core goes first, then the sheath
	float sp = spine * mix(0.6, 1.0, v_thick);
	float mb = mix(m, max(m, prof), band_clean_main * main_k);
	float band = max(mb, 1.0 - smoothstep(sp * 0.6, sp, abs(xu)));
	float rel = clamp((band - cut) / max(1.0 - cut, 0.05), 0.0, 1.0);
	vec3 col = c_fringe * fringe_gain;
	col = mix(col, c_sheath * sheath_gain, aastep(band_sheath + die * sheath_die, rel));
	col = mix(col, c_core * core_gain, aastep(band_core + die * core_die, rel));
	ALBEDO = col * (1.0 - die * dim_die) * fx_gain;
}
