"""Shared code of the British and French regular uniforms (costume bible §5, Set D).

The garment generators are the flat modules tools/character/garments/military_<id>.py
(one SPEC + build(ctx) each; build_character.py runs them). This package only holds the
code they share, in modules whose names start with "_" so the driver's part glob
(tools/character/garments/**/*.py, "_" files skipped) never mistakes them for parts:

    _base     MilSpec (glb and catalog fragment under assets/character/garments/military/),
              pieces (cloth, lining, trims) -> one surface with zones, grain UVs in metres,
              edge distances, body / skirt / rigid / band weights, occupied regions
    _trims    buttons, lace loops, buckles and small fittings (Prims) laid on a surface
    _coat     regimental coats: British 1751 / cropped 1758, French justaucorps
    _vest     waistcoat (British) and sleeved veste (French)
    _legs     breeches, gaiters, stockings
    _hats     cocked hat / tricorne
    _neck     stock and cravat
    _belts    shoulder (cross) belts with cartridge pouch and bayonet, waist belt with
              gargoussier

Build (Blender, on a copy of the rig; see tools/character/README.md):

    tools/character/build_character.sh --garments $(cd tools/character/garments && \
        ls military_*.py | sed 's/\\.py$//' | paste -sd, -)

Every part is generated procedurally around the Actor_B bind pose (null-add); nothing is
downloaded. The lib (tools/character/lib) is imported, never edited.
"""
