# The living bison (a modified CC-BY 3.0 work, rigged and animated by this project)

`bison.glb` is the game's plains bison (WildlifeSpecies "bison"). It is made from two models by
`tools/wildlife/bison_rig.py` (Blender 5.2, run 2026-09-28), and it is a **modified version** of the first:

- **Mesh and texture:** "Bison" by **Poly by Google**, licensed **CC-BY 3.0**
  (https://creativecommons.org/licenses/by/3.0/). Attribution is required (see CREDITS.md). The source file is in
  `assets/wildlife/polypizza/bison.glb` (unmodified; page, URL, size and SHA-256 in `assets/wildlife/polypizza/SOURCE.md`).
- **Armature and clips:** the stag of **Quaternius**'s "Ultimate Animated Animal Pack", licensed **CC0 1.0**
  (`assets/wildlife/quaternius/stag.glb`, unmodified; `assets/wildlife/quaternius/SOURCE.md`).

**Changes made by this project** (the CC-BY notice of modification):
- The bison mesh was scaled to metres and stretched to a plains bull's build (about 1.97 m at the hump, 3.3 m long,
  1.05 m across: 1.22 across, 1.18 along and 1.03 up on its first scale; re-run 2026-09-28). The game makes the herd's
  cows smaller from it (WildlifeSpecies "sizes").
- The mesh was skinned to the stag's armature. The armature's joints were moved to the bison's anatomy (spine,
  shoulders, legs, neck and head, tail), measured off both meshes. The weights are this project's own, by distance
  to each bone.
- The stag's 13 clips were carried over by rotation. Their location keys (body bounce, shoulder shift) were scaled to
  the bison's size.

The rig was built by another of this project's sessions ("Systems showcase video") and taken into the game here. The
texture `bison_BisonPlains_BaseColor.png` is the Poly by Google model's own, as written out with the rigged glTF.

| File | Bytes | SHA-256 |
| --- | --- | --- |
| bison.glb | 2909232 | 9cf55485cb4d76dba918623ec0b15f8e70b87aeb41401500b9d94c020d2ccc83 |
| bison_BisonPlains_BaseColor.png | 1375873 | 5c3bb42bd691caf799105d5df78fb6be0bc42bc3cfb0a40465ab9bd9b3ce61aa |
