"""Path shim for the vendored graph-analysis tools (see PROVENANCE.md).

The vendored modules originally hard-coded absolute paths. Each such line was
replaced by a lookup here, so the tools can run against any checkout of the
Player_Animation_Project (PAP) tree. Nothing else in the vendored files changed.

Environment:
  ANIM_GRAPH_PAP           root of Player_Animation_Project (default below)
  ANIM_GRAPH_SUBGRAPH_OUT  where build_subgraph.py writes state_subgraph.json
"""
import os
import tempfile

PAP = os.environ.get("ANIM_GRAPH_PAP", "/Users/kiwimango/Downloads/Player_Animation_Project")
GRAPH_JSON = os.path.join(PAP, "player_blending", "player_blending.json")
INDEX_CSV = os.path.join(PAP, "blender_animation_index.csv")
SUBGRAPH_OUT = os.environ.get("ANIM_GRAPH_SUBGRAPH_OUT",
                              os.path.join(tempfile.gettempdir(), "anim_graph_state_subgraph.json"))
