// The flame's field (round 4 LOOKS; the moves' flames, ToonFx's toon_flame, and the ring's braziers, ring_flame, the same
// fire): two octaves of the tiling noise read through a domain warp (a slow low noise pushes where they are read), so the
// tongues lick, sway and split as they rise; the field is high in the middle and low at the edge and the tip. Its value
// `v` is cut at about 0.03 (the outline), and the bands (edge, mid, hot, core) are steps in it. Over the tip, ember_mask:
// small hot bits breaking off the tongues and rising faster than the flame.
//   `across` 0..1 over the width, `along` 0 at the base .. 1 at the tip, `t` the scrolled time, `sd` the tongue's own seed.

float flame_v(sampler2D tex, float across, float along, float t, float sd, vec2 nsc, float turb_k, float taper_k,
		float warp_k, out float n2_out) {
	vec2 base = vec2(across * nsc.x + sd * 0.37, along * nsc.y + sd * 1.31);
	vec2 w = vec2(texture(tex, base * 0.55 + vec2(0.0, -t * 0.55)).r,
			texture(tex, base * 0.55 + vec2(0.53, 0.29 - t * 0.7)).r) - 0.5;
	vec2 q = base + w * warp_k * (0.4 + along);
	float n1 = texture(tex, q + vec2(0.0, -t)).r;
	float n2 = texture(tex, q * vec2(2.1, 2.4) + vec2(0.41, -t * 1.7)).r;
	n2_out = n2;
	float n = n1 * 0.62 + n2 * 0.38;
	float x = across * 2.0 - 1.0;
	x += (w.x * 0.9 + (n2 - 0.5) * 0.4) * along;           // the tongue sways and splits toward its tip
	float width = mix(1.0, taper_k, pow(along, 0.8));
	float body = 1.0 - abs(x) / width;
	return body * (1.15 - along) + (n - 0.5) * turb_k * (0.35 + along * 0.9) - along * 0.12;
}

// The embers breaking off the tips: 0..1.
float ember_mask(sampler2D tex, float across, float along, float t, float sd, float v) {
	float e = texture(tex, vec2(across * 2.7 + sd * 0.91, along * 2.2 - t * 1.9 + sd)).r;
	float e2 = texture(tex, vec2(across * 6.3 - sd, along * 5.1 - t * 2.6)).r;
	float spot = smoothstep(0.69, 0.75, e * 0.7 + e2 * 0.45);
	return spot * smoothstep(0.42, 0.8, along) * smoothstep(-0.4, -0.08, v) * (1.0 - smoothstep(0.0, 0.03, v));
}

// The cel field (the cel look, 2026-10-16): a clean teardrop, fat low down and a point at the tip, bent by one slow low noise
// (more toward the tip), the tip split into `lobes_k` points by V notches `notch_k` deep (each tongue its own phase, `sd`).
// No fine grain and no second octave: a hand-drawn tongue, redrawn each step of `t`. Its value is high in the middle and 0
// at the edge: bands are steps in it (toon_flame).
float cel_v(sampler2D tex, float across, float along, float t, float sd, float lobes_k, float notch_k) {
	float x = across * 2.0 - 1.0;
	float n = texture(tex, vec2(sd * 0.37 + along * 0.35, t * 0.5)).r - 0.5;
	x += n * 1.1 * along * along;
	float w = pow(max(1.0 - along, 0.0), 1.15) * (1.0 + 0.3 * sin(along * 3.14159));   // (a belly low down, an S to the tip)
	float tips = 0.5 + 0.5 * cos(x * 3.14159 * lobes_k + sd * 3.1);
	w *= 1.0 - notch_k * (1.0 - tips) * smoothstep(0.25, 0.8, along);
	return (w - abs(x)) * 1.25;
}

// The cel slash (the High Kick's crescent: a flat arc of flame, its pointed ends from the mesh's own taper): high along the
// middle of the strip, 0 at both edges, the edge wavering a little; bands are steps in it.
float cel_slash(sampler2D tex, float across, float along, float t, float sd) {
	float x = abs(across * 2.0 - 1.0);
	float n = texture(tex, vec2(along * 1.5 + sd * 0.3, t * 0.6)).r - 0.5;
	return ((1.0 + n * 0.35) - x) * 1.45;
}
