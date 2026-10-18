# Expedition and home prototype

Owner direction, 2026-10-08: a small playable Godot area with a Durango-like
loop: travel from home to resource maps, gather, return home and build.
The Zelda image was supplied for world and visual extraction. The replacement
archive was successfully unpacked and its disc filesystem read on 2026-10-09.
The earlier failed attempts below are historical records. See
`artifacts/world_reference/extraction_status.json` for current conversion status.

## First playable slice

Proposed scope: one persistent home clearing and one small forest expedition.
A visible travel point offers Leave Home / Return Home. The first objective is
collect logs and stone, return, deposit them and construct a floor/wall section
and a storage chest. Start with existing supported item and building types.
Keep the current arena/menu untouched while testing a separate prototype scene.

The home retains buildings and storage between visits and restarts. The
expedition retains depleted nodes for its current visit; resetting or respawning
resources must be an explicit map/session rule. Repeated travel, reconnects or
loading must not duplicate carried inventory or return deposited items.

## Existing systems to inspect and reuse

- `scripts/world/frontier_level.gd`: assembles terrain, structures, vegetation,
  gathering, survival and player systems. Reuse its owners rather than making
  imported geometry responsible for movement or harvesting.
- `scripts/gathering/` and `data/gathering/gathering.json`: existing harvesting
  and resource definitions.
- `scripts/inventory/inventory_state.gd`: existing pack/loadout model with log,
  stone and tool item kinds.
- `scripts/building/build_world.gd` and `scripts/building/build_mode.gd`:
  persistent built-piece ownership and placement flow.
- `scripts/save/save_game.gd`: current level-part snapshot/load mechanism.
  Map transitions need explicit map identity and separation of home state,
  expedition state and carried player state; don't overwrite the home snapshot
  with expedition geometry/state.
- `scripts/net/net_session.gd`: existing host/session behavior and `own_world`
  storage for a joining player's homestead. Audit it before implementing travel;
  its presence does not establish working multi-map persistence. For multiplayer,
  the server must validate harvesting, inventory changes and building costs.

## Extraction and conversion sequence

1. Obtain locally supplied game/common key files or a decrypted `content`
   directory. Do not put key contents into logs, documentation or Git.
2. List the actual filesystem and choose one contiguous terrain region plus
   referenced object models/textures. Selective WUX extraction is supported by
   JWUDTool; do not expand the entire disc on this low-space machine.
3. Preserve input attribution and material/placement/terrain dependencies.
   Determine actual file formats after listing, rather than guessing filenames.
4. Convert geometry/textures for an isolated Godot scene. Reconstruct materials,
   terrain placement and collision; compare rendered output against a reference.
   Imported source art is reference art, not newly authored project content.
5. Add gatherable gameplay nodes through the existing gathering authority,
   home/expedition travel and separately scoped saves. Test a complete trip,
   construction, restart and a second trip before calling it playable.

Extraction of models does not itself implement this loop. The broader survival
mode and faithful reproduction of source-game lighting remain separate work.

## Extraction attempt result

The owner supplied both key values in chat. JWUDTool 0.4 was tested using
temporary key files, which were removed after the attempt. No key values were
written into project files or retained logs. No world assets were extracted.

The WUX header specifies 32,768-byte sectors, 763,712 logical sectors and a
3,080,192-byte physical data offset. Its largest referenced physical sector is
422,883, requiring 13,860,143,104 bytes, but the supplied file is only
8,860,532,736 bytes. 152,634 logical sector entries reference physical data
beyond EOF. This is consistent with an incomplete image or damaged sector
index; it is not evidence that either supplied key is incorrect. The Java
reader failed while parsing a partition volume header. A complete, intact
image or a decrypted content directory is needed before reliable extraction.

## Reliable retry path

The owner reports the archive was deleted and Trash emptied. The former WUX
path is also no longer present at the latest inspection. There is no readable
source at the supplied locations to extract or salvage. Obtain a complete
source copy before retrying. Use `tools/reference_world/prepare_wux.py` and its
README for controlled unpacking, space checks, read-back and atomic publication.
Its six miniature-fixture regressions pass; this does not validate a replacement
full-size image or resolve source key compatibility. The previous hash mismatch
and reader failure are separate observed problems. Zero padding alone does not
establish corruption.

## Successful replacement extraction, 2026-10-09

The replacement archive decoded successfully to a 13,860,143,104-byte WUX.
Stored bytes passed full readback hashing and sector-bound checks; SHA-256 is
`a507eade013f1886c9c2716587cb1c99d58d915d0f25060643e2195b83f40e49`.
JWUDTool parsed the filesystem using locally supplied keys and indexed 17,906
files across the disc's partitions. This establishes readable structure, not
publisher authenticity or a complete playable conversion.

The first selective export contains 19 files / 176,107,275 bytes: actor info,
F-7 clustering data, selected environment texture resources, three boot/title
packs and three height/material terrain packs. Every exported file's stored
size and SHA-256 were checked against its extraction manifest. These remain
local reference assets under ignored `artifacts/world_reference/world_sources`.
The source archive and verified WUX are retained. No key contents are recorded.

`tools/reference_world/unpack_resources.py` decodes bounded Yaz0 and SARC
resources with member-bound/path checks and parent/member source hashes.
`tools/reference_world/export_heightmaps.py` exported nine terrain tiles to
lossless 256x256 16-bit PNGs in `artifacts/world_reference/heightmaps` and checked
every sample by reopening each PNG. Raw height samples are preserved; source
world dimensions, height scale, orientation and registration are not yet
verified. The format reference is the original converter's raw uint16 path:
https://github.com/AndrooU/BotWHeightMapConverter/blob/master/generate_map.py

Tree and rock texture files have been extracted, but their matching geometry
and actor dependencies are still unresolved. Material reconstruction, reusable
prop scenes, terrain collision and a playable expedition/home loop remain
unfinished. None of these source assets have been added to the shipping game.
