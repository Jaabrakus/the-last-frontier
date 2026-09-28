# Sky panorama (package A)

| File | Source | Processing |
|---|---|---|
| `qwantani_late_afternoon_nosun_2k.exr` | Poly Haven HDRI `qwantani_late_afternoon_puresky`, 2K `.hdr` (`assets/polyhaven/hdri/qwantani_late_afternoon_puresky_2k.hdr`, <https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/qwantani_late_afternoon_puresky_2k.hdr>), CC0 1.0 | `tools/environment/lighting/process_hdri.py`: sun disc (inside 1.2 deg) replaced by the fitted power-law aureole, 8 photographic diffraction spikes clamped to the ring median (out to 10 deg), mirrored lower hemisphere replaced by the lowest sky row. Written as uncompressed half-float OpenEXR, 2048x1024 |
| `sun.json` | measured from the same HDRI | sun direction (native azimuth 216.13 deg, elevation 19.08 deg), removed irradiance, colour, the matching DirectionalLight energy (2.93) and the sky irradiance |

Imported lossless, no mipmaps (`.import`). Used by `shaders/sky/frontier_sky.gdshader` through
`scripts/world/env/environment_rig.gd`, rotated +6.37 deg so the panorama's sun sits on the
DirectionalLight (azimuth 222.5 deg). Re-run:

    python3 tools/environment/lighting/process_hdri.py \
        assets/polyhaven/hdri/qwantani_late_afternoon_puresky_2k.hdr assets/environment/sky

# Cloud noise (cloud engine, 2026-09-26)

| File | Source | Processing |
|---|---|---|
| `cloud_noise_3d.png` | generated (original) by `tools/environment/sky/make_cloud_noise.py`, seed 1765 | 64 x 64 x 64 tileable RGBA8 volume as 8 x 8 slices: R Perlin-Worley base shape, G Worley detail, B Perlin, A large Worley cells. Imported as a Texture3D (lossless, mipmaps); sampled by `shaders/sky/cloud_engine.gdshaderinc` and mirrored on the CPU by `scripts/world/env/cloud_field.gd` |

The weather sounds in `audio/sfx/weather/` (thunder near / far, the rain loop) are synthesised (original) by
`tools/sfx/weather.py`.

# The Moon's near side (sun and moon push, 2026-09-26)

| File | Source | Processing |
|---|---|---|
| `moon_albedo.png` | generated (original) by `tools/environment/sky/make_moon_map.py`, seed 1765; nothing traced from a photograph, no downloads | 512 x 512 RGB8, linear albedo (not sRGB): the disc as seen from the Earth, north up, selenographic east (Mare Crisium) to the right. Maria as soft blobs at the IAU positions and sizes of the near side's seas, highland mottling, a crater population, the bright ray craters (Tycho, Copernicus, Kepler, Aristarchus ...) and the dark-floored ones (Plato, Grimaldi). Imported lossless with mipmaps; sampled by `moon_disc()` in `shaders/sky/frontier_sky_dynamic.gdshader` |
