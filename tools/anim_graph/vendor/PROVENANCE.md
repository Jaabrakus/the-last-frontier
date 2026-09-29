# Vendored graph-analysis tools: provenance

These tools decode the extracted player animation graph. Source paths are configured through
`ANIMATION_SOURCE_ROOT`; `ANIM_GRAPH_SUBGRAPH_OUT` controls the optional subgraph output.
The game uses the bundled tables and does not load this external source.

The records retain historical upstream hashes and the current vendored hashes.
Machine-specific reverse-patch records were retired during source-path cleanup; the tests
verify current file integrity and, when configured, upstream file hashes and resolver behaviour.

```json
[
 {
  "file": "resolve_overlays.py",
  "source": "graph_analysis/graph/resolve_overlays.py",
  "source_sha256": "3f0ee23ee346e95efeaa7ee448f79c5081947b32c33c79b3c7a24611f933e025",
  "vendored_sha256": "1ee2dd18a34d5cae52a41ab24f42ac303f22e97a442b00f4f4a6b6645dedc69b"
 },
 {
  "file": "symvm.py",
  "source": "graph_analysis/graph/symvm.py",
  "source_sha256": "961a445000632d92af44a506906e437e687702a0baff56f8e3e095aa96cb4036",
  "vendored_sha256": "961a445000632d92af44a506906e437e687702a0baff56f8e3e095aa96cb4036"
 },
 {
  "file": "common.py",
  "source": "graph_analysis/graph/common.py",
  "source_sha256": "7d4c7ccc15fafac5c763561fe3b3b7d1d81a269f6cea73cb4697114eb240784a",
  "vendored_sha256": "73a14c0b37b6053696c2e74c233586a6a70e19fa1a3b7af34d2a9686946c6ae8"
 },
 {
  "file": "build_subgraph.py",
  "source": "graph_analysis/graph/build_subgraph.py",
  "source_sha256": "d339adfb92e0b8feb5da05b4a4f899c751179e91b14aaf9b9286dc5a592c5b02",
  "vendored_sha256": "92503065e1ece7f8f34e9a956c1d0ecada8da7f1916ab98e693ede9b3406d496"
 },
 {
  "file": "lib.py",
  "source": "graph_analysis/graph/lib.py",
  "source_sha256": "c4cbe930996bf50c19670c8d5ca657524b3c2e39b132ad772ea826c9039585aa",
  "vendored_sha256": "8494740037e8d35d731340ad5cecf3b4ed7ebc629ff797dbb10139767a8abb58"
 },
 {
  "file": "decode_lambda.py",
  "source": "graph_analysis/graph/decode_lambda.py",
  "source_sha256": "e7eadd83c2b016bb901a2f56288023e21005a2d39f086260a77370d09cf8468b",
  "vendored_sha256": "e7eadd83c2b016bb901a2f56288023e21005a2d39f086260a77370d09cf8468b"
 },
 {
  "file": "resolve.py",
  "source": "graph_analysis/graph/resolve.py",
  "source_sha256": "e30fbdf82aa7d6258283c5314adcac703c2f6c2ea1cab311283384a32f89ce02",
  "vendored_sha256": "e30fbdf82aa7d6258283c5314adcac703c2f6c2ea1cab311283384a32f89ce02"
 },
 {
  "file": "durations.py",
  "source": "graph_analysis/graph/durations.py",
  "source_sha256": "97e90db814b055fe73d1f905d290efc1224ed6e29e742c68d22af2e970c6573f",
  "vendored_sha256": "75f89b668d93809e9038619a288dba2eda541af71a70dc4be8e10088e577943c"
 }
]
```
