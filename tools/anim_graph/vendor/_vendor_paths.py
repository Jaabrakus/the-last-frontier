"""Path shim for the vendored graph-analysis tools (see PROVENANCE.md).

The vendored modules originally hard-coded absolute paths. Each such line was
replaced by a lookup here, so the tools can run against any checkout of the
external animation source (SOURCE_ROOT) tree. The resolution logic is retained.

Environment:
  ANIMATION_SOURCE_ROOT           root of external animation source (explicitly configured)
  ANIM_GRAPH_SUBGRAPH_OUT  where build_subgraph.py writes state_subgraph.json
"""
import os
import tempfile

SOURCE_ROOT = os.environ.get("ANIMATION_SOURCE_ROOT", "")
GRAPH_JSON = os.path.join(SOURCE_ROOT, "player_blending", "player_blending.json")
INDEX_CSV = os.path.join(SOURCE_ROOT, "blender_animation_index.csv")
SUBGRAPH_OUT = os.environ.get("ANIM_GRAPH_SUBGRAPH_OUT",
                              os.path.join(tempfile.gettempdir(), "anim_graph_state_subgraph.json"))
