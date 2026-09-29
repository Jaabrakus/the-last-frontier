# Source checks

Tests of the generator scripts in `tools/anim_graph` and `tools/traversal` against the original
animation source project (`external animation source`). The game never needs them: it plays the
exported files already in `animations/` and `data/`.

Without that project every test here skips. To run them, point `ANIMATION_SOURCE_ROOT` at it:

    ANIMATION_SOURCE_ROOT=/path/to/external animation source python3 -m unittest discover tests/source_checks
