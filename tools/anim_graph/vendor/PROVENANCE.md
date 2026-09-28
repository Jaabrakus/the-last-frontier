# Vendored graph-analysis tools: provenance

These files are copies of the Player_Animation_Project graph-analysis tools
(`Player_Animation_Project/graph_analysis/graph/`). They decode the extracted
player animation graph (`player_blending/player_blending.json`).

The resolution logic is **not edited**. The only change is a path shim: each
line that hard-coded an absolute path now reads it from `_vendor_paths.py`
(environment `ANIM_GRAPH_PAP`, `ANIM_GRAPH_SUBGRAPH_OUT`). `decode_lambda.py`,
`resolve.py` and `durations.py` are vendored as well because
`build_subgraph.py` imports them. `tests/test_vendor.py` checks that:

- every vendored file's sha256 equals `vendored_sha256` below;
- reversing the listed shim lines gives back a file whose sha256 equals
  `source_sha256`, and, when the source tree is present, the current source
  file still has that hash;
- the vendored `build_subgraph.py` regenerates `state_subgraph.json`
  JSON-equal to `graph_analysis/graph/state_subgraph.json`.

Machine-readable record (parsed by the tests):

```json
[
 {
  "file": "resolve_overlays.py",
  "shim": [
   {
    "line": 54,
    "original": "PROJECT = \"/Users/kiwimango/Downloads/Player_Animation_Project\"",
    "replacement": "PROJECT = __import__(\"_vendor_paths\").PAP  # vendored path shim"
   }
  ],
  "source": "Player_Animation_Project/graph_analysis/graph/resolve_overlays.py",
  "source_sha256": "3f0ee23ee346e95efeaa7ee448f79c5081947b32c33c79b3c7a24611f933e025",
  "vendored_sha256": "b0f73a8fe044092f5a260168433672789eeabe7b76d48061f0ff08663c4fd7e6"
 },
 {
  "file": "symvm.py",
  "shim": [],
  "source": "Player_Animation_Project/graph_analysis/graph/symvm.py",
  "source_sha256": "961a445000632d92af44a506906e437e687702a0baff56f8e3e095aa96cb4036",
  "vendored_sha256": "961a445000632d92af44a506906e437e687702a0baff56f8e3e095aa96cb4036"
 },
 {
  "file": "common.py",
  "shim": [
   {
    "line": 2,
    "original": "P='/Users/kiwimango/Downloads/Player_Animation_Project/player_blending/player_blending.json'",
    "replacement": "P=__import__('_vendor_paths').GRAPH_JSON  # vendored path shim"
   }
  ],
  "source": "Player_Animation_Project/graph_analysis/graph/common.py",
  "source_sha256": "7d4c7ccc15fafac5c763561fe3b3b7d1d81a269f6cea73cb4697114eb240784a",
  "vendored_sha256": "73a14c0b37b6053696c2e74c233586a6a70e19fa1a3b7af34d2a9686946c6ae8"
 },
 {
  "file": "build_subgraph.py",
  "shim": [
   {
    "line": 6,
    "original": "OUT='/private/tmp/claude-501/-Users-kiwimango-Downloads-Player-Animation-Project/fd1daa6d-49fa-4529-a009-51bc30ee3ee6/scratchpad/graph/state_subgraph.json'",
    "replacement": "OUT=__import__('_vendor_paths').SUBGRAPH_OUT  # vendored path shim"
   },
   {
    "line": 7,
    "original": "rows=list(csv.DictReader(open('/Users/kiwimango/Downloads/Player_Animation_Project/blender_animation_index.csv')))",
    "replacement": "rows=list(csv.DictReader(open(__import__('_vendor_paths').INDEX_CSV)))  # vendored path shim"
   }
  ],
  "source": "Player_Animation_Project/graph_analysis/graph/build_subgraph.py",
  "source_sha256": "d339adfb92e0b8feb5da05b4a4f899c751179e91b14aaf9b9286dc5a592c5b02",
  "vendored_sha256": "7857b4782a5d8c3244096c1232c5c28c549b674c78ad9ffe58c8a7037801568f"
 },
 {
  "file": "lib.py",
  "shim": [
   {
    "line": 2,
    "original": "P='/Users/kiwimango/Downloads/Player_Animation_Project/player_blending/player_blending.json'",
    "replacement": "P=__import__('_vendor_paths').GRAPH_JSON  # vendored path shim"
   }
  ],
  "source": "Player_Animation_Project/graph_analysis/graph/lib.py",
  "source_sha256": "c4cbe930996bf50c19670c8d5ca657524b3c2e39b132ad772ea826c9039585aa",
  "vendored_sha256": "8494740037e8d35d731340ad5cecf3b4ed7ebc629ff797dbb10139767a8abb58"
 },
 {
  "file": "decode_lambda.py",
  "shim": [],
  "source": "Player_Animation_Project/graph_analysis/graph/decode_lambda.py",
  "source_sha256": "e7eadd83c2b016bb901a2f56288023e21005a2d39f086260a77370d09cf8468b",
  "vendored_sha256": "e7eadd83c2b016bb901a2f56288023e21005a2d39f086260a77370d09cf8468b"
 },
 {
  "file": "resolve.py",
  "shim": [],
  "source": "Player_Animation_Project/graph_analysis/graph/resolve.py",
  "source_sha256": "e30fbdf82aa7d6258283c5314adcac703c2f6c2ea1cab311283384a32f89ce02",
  "vendored_sha256": "e30fbdf82aa7d6258283c5314adcac703c2f6c2ea1cab311283384a32f89ce02"
 },
 {
  "file": "durations.py",
  "shim": [
   {
    "line": 2,
    "original": "rows=list(csv.DictReader(open('/Users/kiwimango/Downloads/Player_Animation_Project/blender_animation_index.csv')))",
    "replacement": "rows=list(csv.DictReader(open(__import__('_vendor_paths').INDEX_CSV)))  # vendored path shim"
   }
  ],
  "source": "Player_Animation_Project/graph_analysis/graph/durations.py",
  "source_sha256": "97e90db814b055fe73d1f905d290efc1224ed6e29e742c68d22af2e970c6573f",
  "vendored_sha256": "75f89b668d93809e9038619a288dba2eda541af71a70dc4be8e10088e577943c"
 }
]
```
