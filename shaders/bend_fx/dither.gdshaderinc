// A screen-door: a 4x4 ordered dither (round 4 LOOKS). A pixel is kept while its threshold is under `a`, so a thing drawn
// at `a` keeps that share of its pixels in a fine even pattern: it fades without being sorted against anything (the
// near-camera fade of the effects, your own walls by the camera, the puffs before a struck body).

// The pixel's threshold (0..1, never 0 or 1).
float dither4(vec2 fc) {
	ivec2 p = ivec2(mod(floor(fc), 4.0));
	int i = p.x + p.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

// Whether a pixel of a thing drawn at `a` (0..1) is left out.
bool dither_cut(float a, vec2 fc) {
	return a < 0.999 && dither4(fc) >= a;
}
