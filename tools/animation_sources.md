# Optional animation source inputs

The game runs with its bundled animation libraries and generated tables. Offline rebuilds
need an external source tree configured explicitly:

```sh
export ANIMATION_SOURCE_ROOT=/absolute/path/to/source
python3 tools/anim_graph/export_actor_b_graph.py --check
```

Graph, traversal and loadout exporters also accept `--source-root`. The tree must supply
`player_blending/player_blending.json`, `blender_animation_index.csv` and the
`graph_analysis/graph` inputs required by the exporter. Rig sync and retargeting additionally
need `godot_export`; character rebuilding needs `blender_libraries` and `ACTOR_B_BLEND`.
Run source-independent checks with `python3 -B -m unittest discover tests/source_checks`.
Source-dependent checks skip when the required inputs are unavailable.

`source/` in generated metadata is a portable input label, not a runtime filesystem path.
No animation tracks, native asset IDs, clip names, rig geometry or gameplay values were
changed by the source-path cleanup.
