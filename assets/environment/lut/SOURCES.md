# Colour-grade LUT (package A)

`frontier_grade_64_<hash>.png` is generated, not sourced: an 8x8 grid of 64x64 slices (slice =
blue, x = red, y = green) of the grade defined in `scripts/world/env/grade_lut.gd`
(`DEFAULT_PARAMS`), imported as a 64^3 `CompressedTexture3D` (lossless, no mipmaps). The hash in
the file name is `GradeLut.params_hash(DEFAULT_PARAMS)`; when the parameters change, re-bake:

    Godot --headless --path . -s tools/environment/lighting/bake_lut.gd
    Godot --headless --path . --import

Until re-baked, `GradeLut.texture()` builds a 32^3 LUT at runtime (about 80 ms) and warns.
Checks: `tools/environment/lighting/check_lut.gd` (identity within 1/255 as rendered, neutral
greys, baked LUT matches `grade()` within 2/255).
