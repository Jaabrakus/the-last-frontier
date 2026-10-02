# The animals smoothed, with hair (modified copies of their sources)

User 2026-10-02: the low-poly animals "smooth out the poly to make it less angle", then "do that with all the animals",
"lets add hairs likes our hair for the humans" and "for the mammoth we need eyes" (like the horse's). Each file here is a
**modified copy** of a source model that stays unmodified in its own folder:

| Copy | Source (unmodified) | Author, licence |
| --- | --- | --- |
| deer.glb, stag.glb, wolf.glb, fox.glb | `assets/wildlife/quaternius/` | Quaternius, CC0 1.0 (quaternius/SOURCE.md) |
| great_horned_owl.glb | `assets/wildlife/polypizza/` | Poly by Google, see polypizza/SOURCE.md |
| mammoth.glb | `assets/wildlife/ice_age/` | Riley Kuhlman, CC0 1.0 (ice_age/SOURCE.md) |
| bison.glb | `assets/wildlife/bison/bison.glb` | Poly by Google's bison, **CC-BY 3.0** (attribution required: bison/SOURCE.md), on Quaternius's CC0 stag rig (bison/SOURCE.md) |

**Changes made by this project:**
- `tools/wildlife/smooth_models.py`: each mesh welded where its faces' corners meet, one Catmull-Clark subdivision step
  in Blender (UVs linear, colours per corner kept, skin weights carried), smooth shading; written over the source's mesh
  data only (the nodes, skin, bones and clips are the source's own, byte for byte). The bison is smoothed by
  `tools/wildlife/bison_rig.py`.
- `tools/wildlife/animal_hair.py`: a "Hair" mesh of strand cards grown on the skin (the project's own strand atlas,
  `assets/character/hair/tex/hair_atlas.png`; each card coloured by the skin at its root and weighted as the skin
  there) on the bison, mammoth, wolf and fox; the mammoth's eyes ("Eyes", "Eyelids": generated eyeballs and almond
  lids, the horse's eye look in `assets/wildlife/materials/animal_eye.gdshader`). No third-party data is added.

Rebuild: `Blender -b --factory-startup --python tools/wildlife/smooth_models.py -- .` then
`python3 tools/wildlife/animal_hair.py`.

| File | Bytes | SHA-256 |
| --- | --- | --- |
| bison.glb | 4754364 | aca34c958c7b1341eaf588297bfb1ee9a01d311384e4cbeaa24790aa014e0dd6 |
| deer.glb | 1529876 | 8401c04be1de08bbd636d7a935579859c1d62a2f344e29692b97dde55097916d |
| fox.glb | 2749820 | bf5e73ad0d0b20d93899679ed8b73a7e06e220ae1da22c1267ceeb884c63c475 |
| great_horned_owl.glb | 1630484 | 73fb0cc5bcc706d4a770520cda73e407306d500bbd11288a8080a5bc1a4825ef |
| mammoth.glb | 3303232 | 1d7f049f53066a2edfda7649443ee8c7f1b8f358fb0aa7d51cc0f86441e9cf6c |
| stag.glb | 1692168 | 3f690b7c82ad9af816608568847c3dd2b9bacc08475ed2df5e449e7a2a36a72c |
| wolf.glb | 3227548 | 93333aa3cd35eee7f77bca4412304deb34bbdfefd5735e9cdb4010c5795f8318 |
