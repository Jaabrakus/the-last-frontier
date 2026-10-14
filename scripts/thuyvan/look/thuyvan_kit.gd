class_name ThuyVanKit
extends RefCounted
## The Thủy Vân look's kits as Godot loads them (tools/thuyvan_art/godot/write_godot_import.py; the kits' notes in
## docs/thuyvan/look_paint.md, rock_kit.md, village_kit.md):
##   rock        assets/thuyvan/rock/<piece>.glb and its hand-made <piece>_lod1.glb (karst towers, gorge walls,
##               boulders, the white stones, the Two Heights, the needle, cairns): the surfaces already carry the kit's
##               materials (rock/materials, shaders/thuyvan/tv_rock.gdshader), set at import
##   village     assets/thuyvan/village/<piece>.glb (houses, the rope bridge, waystone, banners, lanterns, clutter,
##               porters): materials tvv_<key> set at import; the rope bridge's "-colonly" decks import as static bodies
##   vegetation  assets/thuyvan/vegetation/<species>.glb: every variant and LOD in one file (<species>_v<k>_lod<n>),
##               with no material of its own: plant() gives one and sets the species' foliage material
## Pieces come out in the kits' frame: Godot +Y up, a piece's front toward +Z, its origin on the ground at its foot.

const ROOT := "res://assets/thuyvan/"
const ROCK_DIR := ROOT + "rock/"
const VILLAGE_DIR := ROOT + "village/"
const VEG_DIR := ROOT + "vegetation/"
const VEG_MATERIALS := VEG_DIR + "materials/"
## The rock kit's far model takes over at this distance (m) per piece height: LOD1 from 6x the piece's height.
const ROCK_LOD1_PER_H := 6.0

static var _scenes := {}


## A kit's PackedScene by path (cached), or null when the kit is not there.
static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if _scenes[path] == null:
			push_warning("ThuyVanKit: missing %s" % path)
	return _scenes[path]


## A rock kit piece ("karst_hero_c", "cliff_notch_75", "boulder_a", ...). With `lod`, its _lod1 model stands in from
## ROCK_LOD1_PER_H x its height on (a visibility-range hand-over), when the kit has one.
static func rock(piece: String, lod := true) -> Node3D:
	var ps := scene(ROCK_DIR + piece + ".glb")
	if ps == null:
		return null
	var root := Node3D.new()
	root.name = piece
	var near := ps.instantiate() as Node3D
	root.add_child(near)
	var far_path := ROCK_DIR + piece + "_lod1.glb"
	if lod and ResourceLoader.exists(far_path):
		var far := scene(far_path).instantiate() as Node3D
		root.add_child(far)
		var h := maxf(bounds(near).size.y, 1.0)
		_ranges(near, 0.0, h * ROCK_LOD1_PER_H)
		_ranges(far, h * ROCK_LOD1_PER_H, 0.0)
	return root


## A village kit piece ("stilt_house_large", "rope_bridge_r1", "lantern_round", ...).
static func village(piece: String) -> Node3D:
	var ps := scene(VILLAGE_DIR + piece + ".glb")
	return ps.instantiate() as Node3D if ps else null


## One plant: `species` ("tv_broadleaf", "tv_karst_pine", "tv_bamboo", "tv_banana", "tv_fern", "tv_shrub"), its variant
## and LOD (0 near, 1 far), with the species' foliage material (tv_foliage.gdshader).
static func plant(species: String, variant := 0, lod := 0) -> MeshInstance3D:
	var ps := scene(VEG_DIR + species + ".glb")
	if ps == null:
		return null
	var all := ps.instantiate()
	var want := "%s_v%d_lod%d" % [species, variant, lod]
	var src := all.find_child(want, true, false) as MeshInstance3D
	var out: MeshInstance3D = null
	if src:
		out = MeshInstance3D.new()
		out.name = want
		out.mesh = src.mesh
		out.material_override = foliage_material(species)
	else:
		push_warning("ThuyVanKit: no %s in %s" % [want, species])
	all.free()
	return out


## How many variants a species has (vegetation.json).
static func plant_variants(species: String) -> int:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(VEG_DIR + "vegetation.json"))
	if meta is Dictionary and meta.get("species", {}).has(species):
		return (meta["species"][species]["variants"] as Array).size()
	return 0


## A species' shared foliage material (assets/thuyvan/vegetation/materials/<species>.tres).
static func foliage_material(species: String) -> Material:
	var path := VEG_MATERIALS + species + ".tres"
	return load(path) as Material if ResourceLoader.exists(path) else null


## The merged AABB of every mesh under `n`, in `n`'s parent frame (its own transform applied).
static func bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in _meshes(n):
		var box: AABB = _to(n, mi) * mi.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return n.transform * out if not first else AABB(n.position, Vector3.ZERO)


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## `mi`'s transform relative to `top` (without the scene tree: the pieces may not be in it yet).
static func _to(top: Node3D, mi: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != top:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _ranges(n: Node, begin: float, end: float) -> void:
	for mi in _meshes(n):
		mi.visibility_range_begin = begin
		mi.visibility_range_end = end
