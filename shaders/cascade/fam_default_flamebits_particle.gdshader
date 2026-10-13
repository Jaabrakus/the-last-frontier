// Family: /Engine/EngineMaterials/DefaultParticle -- Unreal Engine's own default particle
// material, as cooked into Spellbreak (Proletariat; UE4.22 Cascade; the owner reports a
// Proletariat licence, see animations/SOURCE.md). Spellbreak's artists left it on helper
// emitters: "Light" emitters (light module only) and "RibbonSource" / "SmokeSource" /
// "BoltTrailSource" emitters that only feed ribbons. In the cooked emitters 82 of the 84
// enabled users are EmitterRenderMode ERM_None or ERM_LightsOnly, so cascade.gd never draws
// their sprites (as in the game). The only drawn user is TinkerersDisassembly_CB_FxP / Light
// (ERM_Normal, StartSize 0.1 cm -- effectively invisible in the game too).
//
// SURVIVING SOURCE EVIDENCE: BLEND_Masked, MSM_Unlit, one-sided, no OpacityMaskClipValue
// override (UE default 0.3333). The Expressions array has exactly ONE entry: a TextureSample of
// /Engine/EngineMaterials/OrientParticle (the engine's orientation icon: red/green arms with blue
// arcs on a transparent background; sRGB). No ParticleColor / DynamicParameter node exists.
//
// AUTHORED (only the output wiring): Emissive = OrientParticle RGB, OpacityMask = its alpha,
// clipped at 0.3333. Particle colour/alpha cannot reach the output (no node reads them).
// cull_disabled although the source is one-sided (sprites face the camera in UE).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, fog_disabled;
#include "res://shaders/cascade/common.gdshaderinc"
#include "res://shaders/cascade/particle.gdshaderinc"

uniform sampler2D orient_tex : source_color, filter_linear_mipmap, repeat_enable; // OrientParticle
uniform float alpha_clip = 0.3333;   // UE default OpacityMaskClipValue

void vertex() {
	vec4 _e; vec4 _d;
	particle_vertex(VERTEX, UV, INSTANCE_CUSTOM, INSTANCE_ID, UV2, _e, _d);
	v_extra = _e; v_dyn = _d; v_color = COLOR; v_quv = UV;
}

void fragment() {
	vec4 t = texture(orient_tex, particle_atlas(v_quv));
	ALBEDO = t.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_clip;
}
