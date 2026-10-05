// The Tidebreak crowd (RingCrowd): low-poly figures in a MultiMesh, one draw per pose. Per instance:
//   COLOR            the clothes (the MultiMesh's instance colour; the mesh's own colour is white)
//   INSTANCE_CUSTOM  x the phase (0..1), y the skin (0 light .. 1 dark), z the fan's energy (0..1), w the hair (0..1)
// The mesh marks its parts in UV.x: 0 skin, 0.25 hair, 0.5 clothes, 0.75 legs (the clothes darker); UV.y 1 on the arms
// (they wave more). `cheer` (0 idle .. 1 a roar) is the stands' mood (RingCrowd.set_cheer): idle fans sway a little,
// a roar bobs them up and down and shakes the raised arms. Flat, simple shading (cel friendly).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float cheer : hint_range(0.0, 1.0) = 0.25;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 skin_light : source_color = vec3(0.93, 0.76, 0.62);
uniform vec3 skin_dark : source_color = vec3(0.36, 0.23, 0.15);
uniform vec3 hair_a : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 hair_b : source_color = vec3(0.48, 0.32, 0.16);

varying vec3 v_cloth;
varying vec4 v_custom;
varying float v_part;

void vertex() {
	v_cloth = COLOR.rgb;
	v_custom = INSTANCE_CUSTOM;
	v_part = UV.x;
	float ph = INSTANCE_CUSTOM.x * 6.2831853;
	float e = mix(0.3, 1.0, INSTANCE_CUSTOM.z);
	float h = max(VERTEX.y, 0.0);
	float c = clamp(cheer, 0.0, 1.0);
	// a slow sway from the seat (the whole stand breathes), quicker and wider as they cheer
	float sway = sin(TIME * mix(0.9, 2.2, c) + ph) * mix(0.035, 0.09, c) * e;
	VERTEX.x += sway * h;
	// a bounce: up on the toes with the roar
	float hop = max(0.0, sin(TIME * mix(2.6, 5.2, INSTANCE_CUSTOM.z) + ph * 3.0));
	VERTEX.y += hop * hop * 0.12 * c * e;
	// the arms: shaken over the head
	float arm = UV.y;
	VERTEX.x += arm * sin(TIME * 6.0 + ph * 5.0) * 0.07 * (0.3 + c) * e * h;
	VERTEX.z += arm * cos(TIME * 5.0 + ph * 2.0) * 0.04 * (0.3 + c) * e;
}

void fragment() {
	vec3 skin = mix(skin_light, skin_dark, v_custom.y);
	vec3 hair = mix(hair_a, hair_b, step(0.6, v_custom.w)) * (0.8 + 0.4 * fract(v_custom.w * 7.0));
	vec3 col = v_cloth;
	if (v_part < 0.125) {
		col = skin;
	} else if (v_part < 0.375) {
		col = hair;
	} else if (v_part > 0.625) {
		col = v_cloth * 0.42 + vec3(0.03);
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
}

void light() {
	// two-tone: lit or shade, a narrow soft edge between (cel friendly)
	float nl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-0.05, 0.08, nl) * ATTENUATION;
	DIFFUSE_LIGHT += max(lit, shade_floor) * LIGHT_COLOR / PI;
}
