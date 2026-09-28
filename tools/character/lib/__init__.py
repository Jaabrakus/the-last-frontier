"""Shared Blender library of the Frontier character generators (tools/character/lib).

Owner: the body and library workstream. Garment, hair and fur generators import it
and never edit it; request changes instead (a change needs a rebuild of every catalog
glb and all character checks). See README.md in this folder for the API and the
conventions (spaces, glb contents, region codes, layers, catalog entries).

Modules (all Blender-side; import after `sys.path.insert(0, tools/character)`):
    sdf          SDF nodes, polygonize, vector helpers, log
    remesh       Blender mesh objects, decimate, isotropic remesh, Prims, materials
    rig          bind pose null-add, Skel (joints), export rig, glb export, paths
    body_shapes  BodyParams (female / male), FACE_FEATURES, body part SDFs, sizing
    regions      region ids and hair zones, border cuts, Region UV codes, hide masks
    layers       layer bands, envelopes (clearance above the skin), envelope checks
    weights      body weights, transfer, twist helpers, skirt / queue / band weights
    helpers      helper-bone table and constants (single source), driver twin
    shapes       shape keys: projection onto variant SDFs, writing keys
    wrap         nearest-point binding to the body, shape-key wrap transfer
    uv           grain-aligned UVs in metres
    bands        edge-distance attribute (CUSTOM0) for ribbons, lists, lace
    cards        card strips along curves (hair, fringe)
    fur          fur shells and guard-hair cards
    materials    fabric codes, palette tokens, zone roles, preview materials
    catalog      catalog entry (GarmentSpec), validation, respectful-terms lint, merge
    context      BuildContext, BodyData cache
    pipeline     finish_part(): UVs -> regions/zones -> bands -> weights -> sex shape ->
                 envelope check -> budget -> glb export -> catalog fragment
    preview      Workbench renders, contact sheets, posed previews
"""

LIB_VERSION = 1
