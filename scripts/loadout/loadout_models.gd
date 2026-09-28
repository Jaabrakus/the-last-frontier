class_name LoadoutModels
extends RefCounted
## Carry-gear meshes for the loadout: res://assets/loadout/<kind>.glb, built by
## tools/loadout/build_loadout_assets.py (Blender 5.2, procedural; MANIFEST.json next to the files
## lists every node, marker, frame and texture source).
##
## Kinds and frames (Godot axes, metres):
##   "quiver"              own frame: origin = centre of the mouth, +Y out of the mouth, +Z away from
##                         the wearer's back (carry_gear.json quiver.quiver). 24 arrow ends; the loader
##                         turns them into one MultiMeshInstance3D "Arrows" (set_arrow_count()).
##   "powder_horn"         own frame: origin = the horn mouth at the plug, +Z along the chord to the
##                         spout, +Y up. Hidden "StrapPreview" (display only).
##   "spear_pair_tie"      spear frame centred between two spears (Spear_1 / Spear_2 slot markers).
##   "dart_bundle"         dart frame (origin at the tips' ring centre, +Z to the nocks), Dart_1..5.
##   "musket_sling"        musket model frame  -> child of the musket model, identity transform.
##   "pistol_belt_hook"    pistol model frame  -> child of a hooked (R_hip) pistol.
##   "pistol_sling_loop"   pistol model frame  -> child of each chest pistol.
##   "pistol_sling_buckle" band frame (+Z along the band, +Y away from the body).
##   "tomahawk_frog"       tomahawk model frame -> child of the tomahawk.
##   "bow_cord"            bow model frame     -> child of the stowed bow.
##
## glTF empties import as plain Node3D; build() turns every childless plain Node3D into a Marker3D
## child of the model root at the same model-space transform (as WeaponModels does), so markers
## are read with get_node("StrapTop"). Display-only parts stay hidden unless set_display(model, true).

const GLB_DIR := "res://assets/loadout/"
const MANIFEST_PATH := "res://assets/loadout/MANIFEST.json"
const KINDS: Array[String] = ["quiver", "powder_horn", "spear_pair_tie", "dart_bundle", "musket_sling",
	"pistol_belt_hook", "pistol_sling_loop", "pistol_sling_buckle", "tomahawk_frog", "bow_cord"]
## Parts exported hidden (KHR_node_visibility) for pickups, racks and the camp chest.
const DISPLAY_NODES := {
	"powder_horn": ["StrapPreview"],
	"spear_pair_tie": ["ThongPreview"],
	"dart_bundle": ["ThongPreview"],
	"musket_sling": ["SlingTaut"],
}
## Items authored in a weapon's model frame: add them as a child of that weapon's model.
const HOST := {
	"musket_sling": "musket", "pistol_belt_hook": "pistol", "pistol_sling_loop": "pistol",
	"tomahawk_frog": "tomahawk", "bow_cord": "bow",
}
const ARROWS := "Arrows"

static var _scenes := {}
static var _manifest := {}


static func has_glb(kind: String) -> bool:
	return _scene(kind) != null


## Instances the carry gear of `kind`, or returns null when the GLB is missing or not imported.
## multimesh: the quiver's arrow ends become one MultiMeshInstance3D (false keeps 24 MeshInstance3D).
static func build(kind: String, multimesh := true) -> Node3D:
	var scene := _scene(kind)
	if scene == null:
		push_warning("LoadoutModels: %s.glb is missing or not imported" % kind)
		return null
	var inst := scene.instantiate()
	if not (inst is Node3D):
		if inst:
			inst.free()
		return null
	var model := inst as Node3D
	model.name = kind.to_pascal_case() + "Gear"
	_collect_markers(model, model)
	for n: String in DISPLAY_NODES.get(kind, []):
		var d := model.find_child(n, true, false) as Node3D
		if d:
			d.visible = false
	if kind == "quiver" and multimesh:
		_arrows_to_multimesh(model)
	return model


## Marker names of a built model (direct Marker3D children).
static func markers(model: Node3D) -> PackedStringArray:
	var out := PackedStringArray()
	for c in model.get_children():
		if c is Marker3D:
			out.append(c.name)
	return out


## Model-space transform of a marker (identity when missing).
static func marker_transform(model: Node3D, marker_name: String) -> Transform3D:
	var m := model.get_node_or_null(NodePath(marker_name)) as Marker3D
	return m.transform if m else Transform3D.IDENTITY


## Slot transforms in name order: "Spear_" (spear_pair_tie: the two spears' model transforms) or
## "Dart_" (dart_bundle: five darts). Instance ThrowableModels there for the ones still carried.
static func slot_transforms(model: Node3D, prefix: String) -> Array[Transform3D]:
	var names: Array[String] = []
	for c in model.get_children():
		if c is Marker3D and String(c.name).begins_with(prefix):
			names.append(String(c.name))
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var out: Array[Transform3D] = []
	for n in names:
		out.append((model.get_node(NodePath(n)) as Marker3D).transform)
	return out


## Number of arrow ends the quiver can show (24).
static func arrow_capacity(model: Node3D) -> int:
	var a := model.get_node_or_null(ARROWS)
	if a is MultiMeshInstance3D:
		return (a as MultiMeshInstance3D).multimesh.instance_count
	return a.get_child_count() if a else 0


## Shows the first n arrow ends (fill order: centre first, so the rim empties first).
static func set_arrow_count(model: Node3D, n: int) -> void:
	var a := model.get_node_or_null(ARROWS)
	if a == null:
		return
	var cap := arrow_capacity(model)
	n = clampi(n, 0, cap)
	if a is MultiMeshInstance3D:
		(a as MultiMeshInstance3D).multimesh.visible_instance_count = n
		return
	var kids := a.get_children()
	for i in kids.size():
		(kids[i] as Node3D).visible = i < n


static func arrow_count(model: Node3D) -> int:
	var a := model.get_node_or_null(ARROWS)
	if a is MultiMeshInstance3D:
		var mm := (a as MultiMeshInstance3D).multimesh
		return mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
	var n := 0
	if a:
		for c in a.get_children():
			n += 1 if (c as Node3D).visible else 0
	return n


## Shows or hides the display-only parts (StrapPreview, ThongPreview, SlingTaut).
static func set_display(model: Node3D, on: bool) -> void:
	for kind: String in DISPLAY_NODES:
		for n: String in DISPLAY_NODES[kind]:
			var d := model.find_child(n, true, false) as Node3D
			if d:
				d.visible = on


## The quiver placed with its nocks, not its mouth, at the stow origin: stow * this. See the
## MANIFEST integration hooks (the source arrow reach passes the fletching only in this placement).
static func quiver_nocks_offset(model: Node3D) -> Transform3D:
	return Transform3D(Basis.IDENTITY, -marker_transform(model, "Nocks").origin)


## MANIFEST.json as a Dictionary (cached); {} when missing.
static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if d is Dictionary:
			_manifest = d
	return _manifest


## The MANIFEST entry of one kind ({} when missing).
static func manifest_entry(kind: String) -> Dictionary:
	for a: Dictionary in manifest().get("assets", []):
		if a.get("kind", "") == kind:
			return a
	return {}


static func _scene(kind: String) -> PackedScene:
	if not _scenes.has(kind):
		var path := GLB_DIR + kind + ".glb"
		var scene: PackedScene = null
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
		_scenes[kind] = scene
	return _scenes[kind]


## Every childless plain Node3D (a glTF empty) becomes a Marker3D child of the root.
static func _collect_markers(model: Node3D, node: Node) -> void:
	for c in node.get_children():
		_collect_markers(model, c)
	if node == model or node.get_class() != "Node3D" or node.get_child_count() > 0:
		return
	var src := node as Node3D
	var xf := Transform3D.IDENTITY
	var n: Node = src
	while n != model:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var mk := Marker3D.new()
	mk.transform = xf
	var nm := src.name
	src.get_parent().remove_child(src)
	src.free()
	mk.name = nm
	model.add_child(mk)
	mk.owner = model


static func _arrows_to_multimesh(model: Node3D) -> void:
	var holder := model.get_node_or_null(ARROWS) as Node3D
	if holder == null or holder is MultiMeshInstance3D:
		return
	var kids: Array[MeshInstance3D] = []
	for c in holder.get_children():
		if c is MeshInstance3D:
			kids.append(c)
	if kids.is_empty():
		return
	kids.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = kids[0].mesh
	mm.instance_count = kids.size()
	for i in kids.size():
		mm.set_instance_transform(i, holder.transform * kids[i].transform)
	mm.visible_instance_count = kids.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = ARROWS
	model.remove_child(holder)
	holder.free()
	model.add_child(mmi)
	mmi.owner = model
