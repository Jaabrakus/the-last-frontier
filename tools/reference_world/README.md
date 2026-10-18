# Verified WUX preparation

Run `prepare_wux.py` on a supplied source archive before attempting disc
asset extraction. It never deletes the archive, overwrites an existing output,
or treats a completed-looking file size as verification.

The tool reads the archive member's declared size before writing. It requires
that size plus 2 GiB of free space, writes to a unique `.partial` file, monitors
remaining space, checks the archive decoder's exit/errors and exact byte count,
flushes the output, hashes stored bytes again, optionally compares a trusted
SHA-256, and checks the WUX sector references. Only successful output is
published under the requested filename, with a `.verified.json` record.
Failures remove only the temporary output created by this run.

Dependencies on this Mac: Python 3.9+, system `bsdtar`, system libarchive.
No third-party Python package or console keys are needed for unpacking.
Decryption and key/image compatibility remain a separate subsequent check.

Example (use a new output filename and the actual local archive path):

```sh
python3 tools/reference_world/prepare_wux.py \
  '/path/to/source.7z' \
  '/path/with/space/verified-source.wux' \
  --expected-sha256 a507eade013f1886c9c2716587cb1c99d58d915d0f25060643e2195b83f40e49
```

That reference digest came from the complete WUX member read from the specific
user-supplied archive on 2026-10-08. It is not a publisher authenticity record
or a universal hash for every edition of the game. If using a different source
edition, establish its own integrity rather than reusing this digest.

For the earlier archive, retain room for both the approximately 13.90 GB
archive and 13.86 GB output, plus reserve. Roughly 30 GB free before downloading
both onto the same volume is a practical minimum. An external volume is also
supported. Do not expand WUX into a full WUD; select needed content directly
from the verified WUX using the extractor.

Meaningful failure and round-trip checks:

```sh
python3 -m unittest discover -s tools/reference_world -p 'test_*.py' -v
```

Six checks cover successful output/readback, refusing overwrite, wrong digest,
no free space, space loss midstream, missing sectors and a truncated index.
No Zelda assets were extracted by these tests; they use a miniature synthetic
WUX. A zero-filled tail alone is not proof of corruption. The actual previous
copy's failed digest comparison is the evidence that it differed from the
archive member, and the disc reader separately rejected its volume header.

## Selective extraction and terrain conversion

`index_wux.py` rechecks the verified WUX hash, indexes the disc filesystem, and
optionally exports paths matching `--select` (a Java regular expression).
Supply local key-file paths through `--disc-key-file` and `--common-key-file`;
key bytes travel to the Java bridge through stdin and are excluded from logs.
The local toolkit needs JWUDTool 0.4 and Java. Extracted files get size/hash
records and are never overwritten.

`unpack_resources.py source.pack` lists SARC members (including Yaz0-wrapped
resources). Add `--extract 'REGEX' --output new-directory` to export selected
members with source hashes. It also handles extracted `.sstera` terrain packs.

`export_heightmaps.py source-directory new-output-directory` decodes selected
height packs to lossless 16-bit PNGs and verifies every pixel on readback.
Requires Pillow. It preserves samples, without asserting source world scale
or registration. Metadata retains the source game and parent/member hashes.
The current nine PNGs are data conversions; they do not implement prop scenes,
terrain collision, procedural placement or a playable expedition loop.

## Character rig reference

`export_bfres_rig.py input.bfres new-output.json` runs the offline skeleton
inspector. Requires the built local BfresLibrary net8 toolkit and .NET 8 SDK;
accepts decoded `FRES` resources, not compressed `Yaz0` directly. The inspection
retains actual source names, hierarchy, transforms and input hashes.

`rebuild_reference_rig.gd` rebuilds that record as a standalone Godot Skeleton3D
scene and verifies saved-scene names, parents and rests on readback. Example:

```sh
Godot --headless --path . -s tools/reference_world/rebuild_reference_rig.gd -- \
  artifacts/world_reference/character_source/link_rig.json \
  artifacts/world_reference/character_source/new-reference-rig.tscn
```

`BfresMeshExport.cs` and `convert_character_mesh.py` convert decoded local source
meshes and textures to a separately attributed portable GLB. Original shaders
and actor part-visibility rules are not ported. `reference_character_preview.gd`
imports a local GLB through GLTFDocument and renders reference head views. Append
`check` after the model/output arguments for a headless import check. No tool in
this directory installs the source character as the playable character.
