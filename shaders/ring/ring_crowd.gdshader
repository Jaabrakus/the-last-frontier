// The Tidebreak crowd (RingCrowd; round 4 SHOW: fuller, lit, reacting fans instead of flat cut-outs). Built figures in a
// MultiMesh per pose (and a lighter mesh of each pose for the far view), one draw each. Per fan:
//   COLOR            rgb the clothes (the MultiMesh's instance colour; the mesh's own colour is white), a its side (0 the
//                    -X half's, 1 the +X half's: the flag's colour)
//   INSTANCE_CUSTOM  x the phase (0..1), y the skin (0 light .. 1 dark), z the fan's energy (0..1), w the hair (0..0.5)
//                    plus 0.5 for a hat (the parasol pose wears a straw hat instead of its parasol)
// Per pose (instance uniforms on each MultiMeshInstance3D): pose_id (0 idle, 1 lean, 2 arms up, 3 clap, 4 flag, 5 parasol).
// The mesh marks each vertex: UV.x the part (0 skin, 0.25 hair, 0.5 clothes, 0.62 the clothes' trim, 0.75 legs, 0.88
// straw, 0.95 a pole, 1.0 the flag's cloth, 1.12 a parasol's canopy); UV.y the arm (0 body, 0.5 the upper arm, 1 the
// forearm and hand, a flag's pole and cloth; 2 the head); UV2.x the occlusion (1 open .. 0 shut: the laps, under the arms,
// the seat, the feet under the tier); UV2.y the body's weight (1 the torso and up, 0 the shins and feet, the thighs
// between: what rises when a fan stands, what leans).
// The motion is all here (no per-fan work on the CPU): a slow sway and, with `cheer`, a bounce and waving arms; `ooh`
// (heads up, a lean forward); `ripple` (the stands rising from a fall's end outward and sitting back); `stand` (the
// chosen half up); `clap` on `beat` (hands meeting on each beat; knees slapped by those whose hands are on them).
// Lit like the world: lambert with wrap, a sky and deck ambient (by the mood), the occlusion, the engine's shadows and
// lamps. No outline, no cel bands.
shader_type spatial;
render_mode specular_disabled, cull_back;

uniform float cheer : hint_range(0.0, 1.0) = 0.25;
uniform float ooh : hint_range(0.0, 1.0) = 0.0;
uniform float ooh_lean = 0.32;
uniform float stand : hint_range(0.0, 1.0) = 0.0;
uniform float stand_share = 0.5;
uniform float clap : hint_range(0.0, 1.0) = 0.0;
uniform float beat = 0.0;
// the ripple: its origin (world), the axis it runs along (the ring's long axis, world), seconds since the fall, strength
uniform vec3 ripple_origin = vec3(0.0);
uniform vec3 ripple_axis = vec3(1.0, 0.0, 0.0);
uniform float ripple_t = -100.0;
uniform float ripple_k = 0.0;
uniform float ripple_mps = 16.0;
uniform float rise_s = 0.35;
uniform float hold_s = 0.9;
uniform float sit_s = 3.0;
uniform float reach_m = 60.0;

uniform vec3 side_a : source_color = vec3(0.12, 0.34, 0.72);
uniform vec3 side_b : source_color = vec3(0.78, 0.16, 0.06);
uniform vec3 skin_light : source_color = vec3(0.93, 0.76, 0.62);
uniform vec3 skin_dark : source_color = vec3(0.36, 0.23, 0.15);
uniform vec3 hair_a : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 hair_b : source_color = vec3(0.48, 0.32, 0.16);
uniform vec3 straw : source_color = vec3(0.86, 0.72, 0.42);
uniform vec3 wood : source_color = vec3(0.36, 0.24, 0.14);
uniform float wrap = 0.35;
uniform float ao_k = 0.75;
uniform vec3 sky_amb = vec3(0.2, 0.24, 0.3);
uniform vec3 deck_amb = vec3(0.16, 0.13, 0.09);

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
uniform float pose_id = 0.0;  // (the web build: a plain uniform, each object its own material; FxParams)
#else
instance uniform float pose_id = 0.0;
#endif

varying vec3 v_cloth;
varying vec4 v_custom;
varying float v_part;
varying float v_ao;
varying float v_side;
varying vec3 v_nw;

// p turned by angle a (rad) about the X axis through `pivot` (a positive a tips +Y toward +Z: forward).
vec3 pitch(vec3 p, vec3 pivot, float a) {
	vec3 q = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec3(q.x, q.y * c - q.z * s, q.y * s + q.z * c);
}

// p turned by angle a about the Z axis through `pivot`.
vec3 roll(vec3 p, vec3 pivot, float a) {
	vec3 q = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec3(q.x * c - q.y * s, q.x * s + q.y * c, q.z);
}

void vertex() {
	v_cloth = COLOR.rgb;
	v_side = COLOR.a;
	v_custom = INSTANCE_CUSTOM;
	v_part = UV.x;
	v_ao = UV2.x;
	float arm = UV.y < 1.5 ? UV.y : 0.0;
	float head = step(1.5, UV.y);
	float w = UV2.y;
	float pose = floor(pose_id + 0.5);
	float ph = INSTANCE_CUSTOM.x * 6.2831853;
	float e = mix(0.3, 1.0, INSTANCE_CUSTOM.z);
	float c = clamp(cheer, 0.0, 1.0);
	bool hat = INSTANCE_CUSTOM.w >= 0.5;
	vec3 v = VERTEX;

	// the parasol pose: a straw hat or a parasol, the other folded away
	if (pose > 4.5) {
		bool is_hat = abs(UV.x - 0.88) < 0.03;
		bool is_parasol = UV.x > 0.92;
		if ((hat && is_parasol) || (!hat && is_hat)) {
			v = vec3(0.0, 0.3, 0.0);
		}
	}

	// how far up this fan is: the ripple from a fall's end, the chosen half standing
	vec3 seat = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = abs(dot(seat - ripple_origin, ripple_axis));
	float tr = ripple_t - d / max(ripple_mps, 0.1);
	float near = 1.0 - 0.65 * smoothstep(0.0, reach_m, d);
	float rise = ripple_k * near * smoothstep(0.0, rise_s, tr) * (1.0 - smoothstep(rise_s + hold_s, rise_s + hold_s + sit_s, tr));
	float pick = step(fract(INSTANCE_CUSTOM.x * 7.31 + INSTANCE_CUSTOM.y * 3.7), stand_share);
	float up = clamp(max(rise, stand * pick), 0.0, 1.0);
	float seated = 1.0 - step(3.5, pose) * step(pose, 4.5);

	// the clap on the beat: hands meet on it (the clapping pose, raised arms); hands on the knees lift and slap
	float b = fract(beat);
	float open = 1.0 - pow(abs(cos(3.14159265 * b)), 6.0);
	float clapping = clap * (0.4 + 0.6 * up);
	if (arm > 0.75) {
		if (pose > 2.5 && pose < 3.5) {
			// the clapping pose claps on its own (slower, its own phase) and on the beat in sudden death
			float own = 0.5 + 0.5 * sin(TIME * 7.0 + ph * 3.0);
			float o = mix(own * 0.6 * (0.3 + c), open, clap);
			v.x += sign(v.x) * o * 0.07;
		} else if (pose > 1.5 && pose < 2.5) {
			v.x += sign(v.x) * open * 0.09 * clapping;
		} else if (pose < 1.5) {
			v.y += open * 0.07 * clapping;
		}
	}

	// the ooh: heads up, a lean forward from the hips
	float lean = (pose > 0.5 && pose < 1.5) ? 0.0 : ooh * ooh_lean * e;
	if (head > 0.5) {
		v = pitch(v, vec3(0.0, 0.64, 0.02) + (1.0 - seated) * vec3(0.0, 0.43, 0.2), -ooh * 0.35);
	}
	v = mix(v, pitch(v, vec3(0.0, 0.08, 0.0), lean), w * seated);

	// standing up from the seat: the hips up and back over the feet (the thighs follow by their weight)
	v.y += up * 0.42 * w * seated;
	v.z -= up * 0.1 * w * seated;
	// and their hands thrown up as they rise
	v.y += up * 0.45 * arm * arm * seated * step(pose, 1.5);

	// the flag waved from the shoulder
	if (pose > 3.5 && pose < 4.5 && arm > 0.75 && v.x > 0.1) {
		float a = sin(TIME * mix(1.8, 3.2, c) + ph) * mix(0.25, 0.5, c);
		v = roll(v, vec3(0.2, 1.0, 0.2), a);
		if (UV.x > 0.97 && UV.x < 1.05) {
			float along = max(v.x - 0.3, 0.0);
			v.z += sin(TIME * 7.0 + ph + along * 9.0) * 0.06 * along * 3.0;
		}
	}

	// a slow sway from the seat (the whole stand breathes), quicker and wider as they cheer
	float h = max(v.y, 0.0);
	float sway = sin(TIME * mix(0.9, 2.2, c) + ph) * mix(0.035, 0.08, c) * e;
	v.x += sway * h;
	// a bounce with the roar
	float hop = max(0.0, sin(TIME * mix(2.6, 5.2, INSTANCE_CUSTOM.z) + ph * 3.0));
	v.y += hop * hop * 0.1 * c * e * (0.4 + 0.6 * w);
	// raised arms shaken over the head
	if (pose > 1.5 && pose < 2.5) {
		v.x += arm * sin(TIME * 6.0 + ph * 5.0) * 0.07 * (0.3 + c) * e;
		v.z += arm * cos(TIME * 5.0 + ph * 2.0) * 0.04 * (0.3 + c) * e;
	}
	VERTEX = v;
	v_nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 skin = mix(skin_light, skin_dark, v_custom.y);
	float hw = fract(v_custom.w * 2.0);
	vec3 hair = mix(hair_a, hair_b, step(0.6, hw)) * (0.8 + 0.4 * fract(hw * 7.0));
	vec3 col = v_cloth;
	float p = v_part;
	if (p < 0.125) {
		col = skin;
	} else if (p < 0.375) {
		col = hair;
	} else if (p < 0.56) {
		col = v_cloth;
	} else if (p < 0.68) {
		col = mix(v_cloth * 0.55, vec3(0.92, 0.86, 0.7), 0.35);
	} else if (p < 0.82) {
		col = v_cloth * 0.38 + vec3(0.035, 0.03, 0.03);
	} else if (p < 0.915) {
		col = straw;
	} else if (p < 0.97) {
		col = wood;
	} else if (p < 1.05) {
		col = mix(side_a, side_b, step(0.5, v_side));
	} else {
		// a parasol: a bright paper colour of its own
		float k = fract(v_custom.x * 13.7);
		col = k < 0.33 ? vec3(0.86, 0.26, 0.18) : (k < 0.66 ? vec3(0.95, 0.78, 0.32) : vec3(0.2, 0.52, 0.62));
	}
	float occ = mix(1.0, v_ao, ao_k);
	ALBEDO = col * mix(1.0, occ, 0.45);
	AO = occ;
	AO_LIGHT_AFFECT = 0.2;
	ROUGHNESS = 0.88;
	// the sky above and the sunlit deck below, by the mood (RingCrowd.set_light)
	float up = v_nw.y;
	EMISSION = col * (sky_amb * clamp(up * 0.5 + 0.5, 0.0, 1.0) + deck_amb * clamp(-up * 0.6 + 0.2, 0.0, 1.0)) * occ;
}

void light() {
	// lambert with wrap: the light reaches a little round the form (cloth, skin), the shadows the engine's own
	float nl = dot(NORMAL, LIGHT);
	float wr = max((nl + wrap) / (1.0 + wrap), 0.0);
	DIFFUSE_LIGHT += wr * ATTENUATION * LIGHT_COLOR / 3.14159265;
}
