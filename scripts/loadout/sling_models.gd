class_name SlingModels
extends RefCounted
## Visuals of the stowed items: one "unit" per carried object (a spear, a dart, a pistol...) so the body
## can show counts, plus the carrying gear the weapons do not bring (quiver with arrows, the reshaped
## powder horn, thong ties, belt hooks, sling holster loops).
##
## The weapons themselves are WeaponModels / ThrowableModels (the same meshes as in the hand). The gear
## pieces come from assets/loadout/ (tools/loadout/build_loadout_assets.py, MANIFEST.json) through
## LoadoutModels.build() when those GLBs are imported: quiver with 24 arrow ends, powder horn, spear-pair
## tie, dart bundle, musket sling ends, pistol belt hook, pistol-sling loops and buckle, tomahawk frog,
## bow cord. Weapon-frame gear is a child of the stowed weapon with an identity transform (MANIFEST
## integration hooks). Without them the procedural stand-ins below are used.
##
## Model frames (carry_gear.json conventions): firearms and spears -Z = muzzle / point, +Y top, +X lock;
## bow +Y upper limb, +Z string; tomahawk +Y haft to head, -Z edge; atlatl +Z to the hook; dart origin at
## the tip, +Z to the nock; quiver origin at the mouth, +Y out of the mouth. The horn is built in its own
## frame: origin at the base plug, +Z along the chord toward the spout, +Y the side the curve bows to.

const QUIVER_LEN := 0.674
const QUIVER_R_MOUTH := 0.047
const QUIVER_R_BOTTOM := 0.038
const ARROWS_SHOWN_MAX := 24
const SPEAR_GAP := 0.036
const DART_RING_R := 0.015

static var _mats := {}


# --- delivered gear (LoadoutModels) -------------------------------------------------------------

const LOADER := "res://scripts/loadout/loadout_models.gd"
static var _loader: Script
static var _loader_checked := false


static func _lm() -> Script:
	if not _loader_checked:
		_loader_checked = true
		if ResourceLoader.exists(LOADER):
			_loader = load(LOADER) as Script
	return _loader


## A delivered gear model of `kind` (LoadoutModels kinds), or null.
static func gear(kind: String) -> Node3D:
	var lm := _lm()
	if lm == null or not bool(lm.call("has_glb", kind)):
		return null
	var m: Variant = lm.call("build", kind)
	if m is Node3D:
		(m as Node3D).set_meta("sling_gear", kind)
		return m
	return null


static func has_gear(kind: String) -> bool:
	var lm := _lm()
	return lm != null and bool(lm.call("has_glb", kind))


static func gear_entry(kind: String) -> Dictionary:
	var lm := _lm()
	if lm == null:
		return {}
	var e: Variant = lm.call("manifest_entry", kind)
	return e if e is Dictionary else {}


## Slot transforms of a gear model ("Spear_", "Dart_" markers), name order.
static func slots(model: Node3D, prefix: String) -> Array:
	var lm := _lm()
	if lm:
		return lm.call("slot_transforms", model, prefix)
	return []


## Model-space position of a named node (marker) anywhere under `model`, or `fallback`.
static func marker(model: Node3D, names: Array, fallback: Vector3) -> Vector3:
	for n in names:
		var m := model.find_child(String(n), true, false) as Node3D
		if m:
			var xf := Transform3D.IDENTITY
			var cur: Node = m
			while cur != null and cur != model:
				if cur is Node3D:
					xf = (cur as Node3D).transform * xf
				cur = cur.get_parent()
			return xf.origin
	return fallback


# --- units ------------------------------------------------------------------------------------

## One carried object of `kind` in its model frame (what goes into the hand).
static func unit(kind: String) -> Node3D:
	match kind:
		"musket":
			return WeaponModels.build("musket")
		"over_under":
			return WeaponModels.build("over_under") if WeaponModels.has_glb("over_under") else WeaponModels.build("musket")
		"pistol", "bow":
			return WeaponModels.build(kind)
		"spear", "spear_pair":
			return ThrowableModels.build("spear")
		"dart", "dart_bundle":
			return ThrowableModels.build("atlatl_dart")
		"tomahawk", "tomahawk_pipe", "atlatl":
			return ThrowableModels.build(kind)
		"quiver":
			return quiver(24)
		"powder_horn":
			return powder_horn()
		"climbing_stakes_wood", "climbing_stakes_bone", "climbing_stakes_stone", "climbing_stakes_iron":
			return climbing_stakes(kind.trim_prefix("climbing_stakes_"))
	push_warning("SlingModels: no unit model for " + kind)
	return Node3D.new()


## The model shown on the body for an item: a root whose children "Unit0".."UnitN" are the units (count
## aware: SlingRig shows the first n) plus the gear that holds them (ties, hooks). `point` selects extras
## (a belt hook for hooked pistols).
static func stowed(kind: String, count: int, point: String, gear_ids: PackedStringArray = PackedStringArray()) -> Node3D:
	var root := Node3D.new()
	root.name = "Stowed_" + kind
	match kind:
		"spear_pair":
			var tie := gear("spear_pair_tie")
			var slot_xf: Array = slots(tie, "Spear_") if tie else []
			if tie:
				tie.name = "Tie"
				root.add_child(tie)
			for i in maxi(count, 2):
				var s := unit("spear")
				s.name = "Unit%d" % i
				s.transform = slot_xf[i] if i < slot_xf.size() else Transform3D(Basis(), Vector3(SPEAR_GAP * (i - 0.5), 0, 0))
				root.add_child(s)
			if tie == null:
				_ties(root, Vector3.ZERO, [-0.35, 0.55], 0.032, "")
		"dart_bundle":
			var bundle := gear("dart_bundle")
			var slot_xf: Array = slots(bundle, "Dart_") if bundle else []
			if bundle:
				bundle.name = "Tie"
				root.add_child(bundle)
			for i in maxi(count, 5):
				var d := unit("dart")
				d.name = "Unit%d" % i
				var a := TAU * i / 5.0
				d.transform = slot_xf[i] if i < slot_xf.size() else Transform3D(Basis(), Vector3(cos(a), sin(a), 0.0) * DART_RING_R)
				root.add_child(d)
			if bundle == null:
				var L := ThrowableModels.DART_LENGTH
				_ties(root, Vector3.ZERO, [L * 0.3, L * 0.7], 0.026, "")
		"pistol":
			var p := unit("pistol")
			p.name = "Unit0"
			root.add_child(p)
			if point in ["chest_R", "chest_L"] and gear_ids.has("pistol_sling"):
				p.add_child(sling_loop())
			elif point in ["R_hip", "chest_R", "chest_L"]:
				# hooked (lock out) at the right hip; on a shoulder belt at the chest; the left-hip and sash
				# pistols are tucked (MANIFEST: pistol_belt_hook carry points)
				p.add_child(belt_hook())
		"quiver":
			var q := quiver(count)
			q.name = "Unit0"
			root.add_child(q)
		_:
			var u := unit(kind)
			u.name = "Unit0"
			root.add_child(u)
			var extra := {"musket": "musket_sling", "over_under": "musket_sling", "tomahawk": "tomahawk_frog", "bow": "bow_cord"}
			if extra.has(kind):
				var gm := gear(String(extra[kind]))
				if gm:
					u.add_child(gm)
	return root


# --- materials --------------------------------------------------------------------------------

static func mat(key: String, color: Color, rough := 0.75, metal := 0.0, vcol := false, cull_off := false) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		m.vertex_color_use_as_albedo = vcol
		if cull_off:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func leather() -> StandardMaterial3D:
	return mat("leather", Color(0.36, 0.22, 0.12), 0.82)


static func leather_dark() -> StandardMaterial3D:
	return mat("leather_dark", Color(0.2, 0.12, 0.07), 0.8)


static func iron() -> StandardMaterial3D:
	return mat("iron", Color(0.22, 0.22, 0.23), 0.45, 0.8)


static func brass() -> StandardMaterial3D:
	return mat("brass", Color(0.74, 0.56, 0.28), 0.35, 0.9)


static func wood() -> StandardMaterial3D:
	return mat("wood", Color(0.42, 0.26, 0.13), 0.6)


# --- procedural pieces ------------------------------------------------------------------------

## Tapered tube along +Y from y0 (radius r0) to y1 (radius r1), `sides` facets.
static func tube_mesh(y0: float, y1: float, r0: float, r1: float, sides := 16, caps := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var p01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var p10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		var n0 := Vector3(cos(a0), (r0 - r1) / maxf(absf(y1 - y0), 1e-4), sin(a0)).normalized()
		var n1 := Vector3(cos(a1), (r0 - r1) / maxf(absf(y1 - y0), 1e-4), sin(a1)).normalized()
		st.set_normal(n0); st.add_vertex(p00)
		st.set_normal(n0); st.add_vertex(p10)
		st.set_normal(n1); st.add_vertex(p11)
		st.set_normal(n0); st.add_vertex(p00)
		st.set_normal(n1); st.add_vertex(p11)
		st.set_normal(n1); st.add_vertex(p01)
		if caps:
			st.set_normal(Vector3.DOWN); st.add_vertex(Vector3(0, y0, 0))
			st.set_normal(Vector3.DOWN); st.add_vertex(p00)
			st.set_normal(Vector3.DOWN); st.add_vertex(p01)
			st.set_normal(Vector3.UP); st.add_vertex(Vector3(0, y1, 0))
			st.set_normal(Vector3.UP); st.add_vertex(p11)
			st.set_normal(Vector3.UP); st.add_vertex(p10)
	return st.commit()


static func _mesh_node(parent: Node3D, mesh: Mesh, m: Material, xf := Transform3D.IDENTITY, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.transform = xf
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi


## Transform that maps +Y to the direction a -> b, origin at a.
static func along(a: Vector3, b: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(x, y, x.cross(y) * -1.0).orthonormalized(), a)


## Leather thong ties around a bundle whose axis is the model Z axis (through `center`), at z values.
static func _ties(root: Node3D, center: Vector3, zs: Array, r: float, _asset_name: String) -> void:
	for i in zs.size():
		var z: float = zs[i]
		var t := _mesh_node(root, tube_mesh(-0.009, 0.009, r, r, 12, false), mat("thong", Color(0.3, 0.19, 0.1), 0.85, 0.0, false, true),
				Transform3D(Basis(Vector3.RIGHT, PI / 2), center + Vector3(0, 0, z)), "Tie%d" % i)
		t.set_meta("sling_tie", true)


## A pair of climbing stakes (the four tiers of loadout_items.json: wood, bone, stone, iron), side by side along X,
## tied together at the grips. Each 0.20 m: a rawhide (iron: leather) grip from z +0.10 to +0.035, the working end
## to the point at z -0.10. Model frame: -Z = point, +Y out of the body (carry_gear.json back_left.climbing_stakes_*).
static func climbing_stakes(tier: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ClimbingStakes_" + tier
	for i in 2:
		var s := climbing_stake(tier)
		s.name = "Stake%d" % i
		s.position = Vector3(0.019 * (1 if i == 0 else -1), 0.0, 0.006 * i)
		root.add_child(s)
	_ties(root, Vector3.ZERO, [0.07], 0.034, "")
	return root


## One climbing stake of `tier` (see climbing_stakes), its grip centred at z +0.068, the point at z -0.10.
static func climbing_stake(tier: String) -> Node3D:
	var root := Node3D.new()
	var grip := mat("stake_rawhide", Color(0.72, 0.62, 0.45), 0.9) if tier != "iron" else leather()
	var up := Basis(Vector3.RIGHT, -PI / 2)      # tube_mesh runs along +Y; turned to run along -Z
	_mesh_node(root, tube_mesh(-0.10, -0.035, 0.0115, 0.0125, 10), grip, Transform3D(up, Vector3.ZERO), "Grip")
	_mesh_node(root, tube_mesh(-0.105, -0.10, 0.014, 0.014, 10), grip, Transform3D(up, Vector3.ZERO), "Butt")
	match tier:
		"wood":
			var w := mat("stake_wood", Color(0.42, 0.29, 0.17), 0.8)
			_mesh_node(root, tube_mesh(-0.035, 0.05, 0.011, 0.008, 10), w, Transform3D(up, Vector3.ZERO), "Shaft")
			_mesh_node(root, tube_mesh(0.05, 0.10, 0.008, 0.0, 8), mat("stake_charred", Color(0.09, 0.07, 0.06), 0.95),
					Transform3D(up, Vector3.ZERO), "Point")
		"bone":
			var b := mat("stake_bone", Color(0.86, 0.82, 0.7), 0.55)
			_mesh_node(root, tube_mesh(-0.035, 0.04, 0.012, 0.009, 9), b, Transform3D(up, Vector3.ZERO), "Shaft")
			_mesh_node(root, tube_mesh(0.04, 0.10, 0.009, 0.0, 7), b, Transform3D(up, Vector3.ZERO), "Point")
		"stone":
			_mesh_node(root, tube_mesh(-0.035, 0.035, 0.0105, 0.0095, 10), wood(), Transform3D(up, Vector3.ZERO), "Shaft")
			var f := mat("stake_flint", Color(0.36, 0.33, 0.3), 0.35)
			var flat := Basis.from_scale(Vector3(1.0, 1.0, 0.35))
			_mesh_node(root, tube_mesh(0.03, 0.05, 0.009, 0.016, 6), f, Transform3D(up * flat, Vector3.ZERO), "Belly")
			_mesh_node(root, tube_mesh(0.05, 0.10, 0.016, 0.0, 6), f, Transform3D(up * flat, Vector3.ZERO), "Point")
			var sinew := mat("stake_sinew", Color(0.82, 0.76, 0.62), 0.9)
			for k in 3:
				_mesh_node(root, tube_mesh(-0.003, 0.003, 0.0118, 0.0118, 10, false), sinew,
						Transform3D(up, Vector3(0, 0, -0.022 - 0.007 * k)), "Lash%d" % k)
		_:
			var m := iron()
			_mesh_node(root, tube_mesh(-0.037, -0.031, 0.016, 0.016, 4), m, Transform3D(up, Vector3.ZERO), "Guard")
			_mesh_node(root, tube_mesh(-0.031, 0.10, 0.0085, 0.0, 4), m, Transform3D(up, Vector3.ZERO), "Spike")
	return root


## A grip claw strapped under one foot, of `tier` (wood, bone, stone, iron: loadout_items.json climbing_claws_*; after
## the Japanese ashiko, user reference 2026-09-29): a plate under the forefoot a little wider than the foot, four teeth
## out of its toe edge pointing forward and down past the toes, a wide leather band over the forefoot and a buckled
## leather strap round the ankle. Origin at the sole under the middle of the plate, +Y up (the instep), -Z forward.
static func climbing_claw(tier := "iron") -> Node3D:
	var root := Node3D.new()
	root.name = "ClimbingClaw_" + tier
	var plate_m: Material
	var tooth_m: Material
	match tier:
		"wood":
			plate_m = mat("stake_wood", Color(0.42, 0.29, 0.17), 0.8)
			tooth_m = mat("stake_charred", Color(0.09, 0.07, 0.06), 0.95)
		"bone":
			plate_m = mat("stake_bone", Color(0.86, 0.82, 0.7), 0.55)
			tooth_m = plate_m
		"stone":
			plate_m = wood()
			tooth_m = mat("stake_flint", Color(0.36, 0.33, 0.3), 0.35)
		_:
			plate_m = iron()
			tooth_m = plate_m
	var thick := 0.005 if tier == "iron" else 0.011
	var plate := BoxMesh.new()
	plate.size = Vector3(0.092, thick, 0.11)
	_mesh_node(root, plate, plate_m, Transform3D(Basis(), Vector3(0, -thick * 0.5, 0.0)), "Plate")
	for i in 4:
		# teeth from the toe edge, forward and 25 deg down (stone: flat flint flakes)
		var t := _mesh_node(root, tube_mesh(0.0, 0.04, 0.0075 if tier != "iron" else 0.0065, 0.0, 4 if tier != "stone" else 6, false),
				tooth_m, Transform3D(Basis(Vector3.RIGHT, -PI / 2 - 0.44), Vector3(-0.033 + 0.022 * i, -thick * 0.6, -0.052)), "Tooth%d" % i)
		if tier == "stone":
			t.transform.basis = t.transform.basis * Basis.from_scale(Vector3(1.0, 1.0, 0.4))
	var band := leather()
	# the forefoot band (0.038 wide), round the foot's section, its lower run under the plate
	_mesh_node(root, tube_mesh(-0.019, 0.019, 0.057, 0.057, 22, false), band,
			Transform3D(Basis.from_scale(Vector3(1.0, 0.68, 1.0)) * Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.03, 0.012)), "Band")
	# the ankle strap (0.024 wide) with its iron buckle on the outside
	var ankle := Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 0.088, 0.09))
	_mesh_node(root, tube_mesh(-0.012, 0.012, 0.055, 0.055, 22, false), band, ankle, "AnkleStrap")
	var buckle := BoxMesh.new()
	buckle.size = Vector3(0.007, 0.028, 0.024)
	_mesh_node(root, buckle, iron(), ankle * Transform3D(Basis(), Vector3(0.057, 0.0, 0.0)), "Buckle")
	return root


## The belt hook of a hooked pistol: a flat steel bar on the left flat of the stock (-X), screwed on at
## the rear lock screw and running forward, standing off the wood so it hooks over a belt or strap.
static func belt_hook() -> Node3D:
	var a := gear("pistol_belt_hook")
	if a:
		a.name = "BeltHook"
		return a
	var root := Node3D.new()
	root.name = "BeltHook"
	var bar := BoxMesh.new()
	bar.size = Vector3(0.004, 0.009, 0.12)
	_mesh_node(root, bar, iron(), Transform3D(Basis(), Vector3(-0.027, 0.036, -0.045)))
	var foot := BoxMesh.new()
	foot.size = Vector3(0.01, 0.009, 0.006)
	_mesh_node(root, foot, iron(), Transform3D(Basis(), Vector3(-0.022, 0.036, 0.012)))
	var tipm := BoxMesh.new()
	tipm.size = Vector3(0.006, 0.009, 0.01)
	_mesh_node(root, tipm, iron(), Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.029, 0.036, -0.105)))
	return root


## Back quiver with `arrows` fletched arrow ends in its mouth (count-aware: set_quiver_arrows()).
## Origin at the mouth, +Y out of the mouth.
static func quiver(arrows: int) -> Node3D:
	var a := gear("quiver")
	if a:
		# delivered in the stow frame: origin at the mouth, +Y out of it, +Z away from the back
		a.name = "QuiverModel"
		set_quiver_arrows(a, arrows)
		return a
	var root := Node3D.new()
	root.name = "QuiverModel"
	var body := leather()
	_mesh_node(root, tube_mesh(-QUIVER_LEN, -0.02, QUIVER_R_BOTTOM, QUIVER_R_MOUTH, 18, false), mat("quiver_leather", Color(0.4, 0.25, 0.13), 0.8, 0.0, false, true), Transform3D.IDENTITY, "Tube")
	_mesh_node(root, tube_mesh(-0.035, 0.0, QUIVER_R_MOUTH + 0.004, QUIVER_R_MOUTH + 0.005, 18, false), mat("quiver_rim", Color(0.24, 0.14, 0.08), 0.75, 0.0, false, true), Transform3D.IDENTITY, "Rim")
	_mesh_node(root, tube_mesh(-QUIVER_LEN - 0.012, -QUIVER_LEN + 0.03, QUIVER_R_BOTTOM + 0.003, QUIVER_R_BOTTOM + 0.004, 18, true), leather_dark(), Transform3D.IDENTITY, "Bottom")
	# a floor just inside the mouth so the open tube does not show the background through it
	_mesh_node(root, tube_mesh(-0.07, -0.065, QUIVER_R_MOUTH - 0.002, QUIVER_R_MOUTH - 0.002, 18, true), mat("quiver_in", Color(0.1, 0.07, 0.05), 0.9), Transform3D.IDENTITY, "Inside")
	# seam and two strap loops on the back of the tube (the strap ribbon ends here)
	var seam := BoxMesh.new()
	seam.size = Vector3(0.006, QUIVER_LEN - 0.06, 0.004)
	_mesh_node(root, seam, leather_dark(), Transform3D(Basis(), Vector3(0, -QUIVER_LEN * 0.5, -(QUIVER_R_MOUTH + QUIVER_R_BOTTOM) * 0.5 - 0.001)))
	for y in [-0.12, -0.56]:
		var r: float = lerpf(QUIVER_R_MOUTH, QUIVER_R_BOTTOM, -y / QUIVER_LEN) + 0.006
		_mesh_node(root, tube_mesh(y - 0.012, y + 0.012, r, r, 18, false), leather_dark(), Transform3D.IDENTITY, "Band")
	var top := Marker3D.new()
	top.name = "StrapTop"
	top.position = Vector3(0, -0.12, 0)
	root.add_child(top)
	var bot := Marker3D.new()
	bot.name = "StrapBottom"
	bot.position = Vector3(0, -0.56, 0)
	root.add_child(bot)
	# arrows: one MultiMesh of fletched ends, count-aware
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _arrow_end_mesh()
	mm.instance_count = ARROWS_SHOWN_MAX
	var rng := RandomNumberGenerator.new()
	rng.seed = 1757
	for i in ARROWS_SHOWN_MAX:
		# sunflower packing in the mouth, splayed a little outward, heights staggered
		var r := 0.034 * sqrt((i + 0.5) / ARROWS_SHOWN_MAX)
		var ang := i * 2.39996
		var pos := Vector3(cos(ang) * r, rng.randf_range(-0.012, 0.01), sin(ang) * r)
		var tilt := Basis(Vector3(-sin(ang), 0, cos(ang)), -r / 0.034 * deg_to_rad(5.0)) * Basis(Vector3.UP, rng.randf() * TAU)
		mm.set_instance_transform(i, Transform3D(tilt, pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Arrows"
	mmi.multimesh = mm
	var am := mat("arrow_end", Color(1, 1, 1), 0.7, 0.0, true, true)
	mmi.material_override = am
	root.add_child(mmi)
	set_quiver_arrows(root, arrows)
	return root


## Shows `n` arrows in a quiver (procedural MultiMesh, or an asset's "Arrow*" nodes / MultiMesh).
static func set_quiver_arrows(q: Node3D, n: int) -> void:
	for mmi in q.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (mmi as MultiMeshInstance3D).multimesh
		if mm:
			mm.visible_instance_count = clampi(n, 0, mm.instance_count)
	var arrows: Array = []
	for c in q.find_children("Arrow*", "Node3D", true, false):
		if not (c is MultiMeshInstance3D):
			arrows.append(c)
	arrows.sort_custom(func(a, b) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	for i in arrows.size():
		(arrows[i] as Node3D).visible = i < n


## Shaft (from inside the quiver to the nock), three fletches (two grey goose feathers and a darker cock
## feather) and the nock, +Y up, coloured by vertex colour.
static func _arrow_end_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(st, -0.22, 0.115, 0.0042, 6, Color(0.66, 0.5, 0.32))
	_cyl(st, 0.115, 0.13, 0.005, 6, Color(0.15, 0.1, 0.07))
	var feather := [Color(0.86, 0.84, 0.78), Color(0.86, 0.84, 0.78), Color(0.42, 0.3, 0.2)]
	for k in 3:
		var a := TAU * k / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		var y0 := 0.02
		var y1 := 0.11
		var p0 := d * 0.004 + Vector3(0, y0, 0)
		var p1 := d * 0.004 + Vector3(0, y1, 0)
		var p2 := d * 0.016 + Vector3(0, y1 - 0.012, 0)
		var p3 := d * 0.012 + Vector3(0, y0 + 0.025, 0)
		var n := d.cross(Vector3.UP).normalized()
		for tri in [[p0, p1, p2], [p0, p2, p3]]:
			for v: Vector3 in tri:
				st.set_color(feather[k])
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


static func _cyl(st: SurfaceTool, y0: float, y1: float, r: float, sides: int, c: Color) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for v: Array in [[d0, y0], [d0, y1], [d1, y1], [d0, y0], [d1, y1], [d1, y0]]:
			st.set_color(c)
			st.set_normal(v[0])
			st.add_vertex((v[0] as Vector3) * r + Vector3(0, float(v[1]), 0))


## The reshaped powder horn (loadout_design.md 2.6): a 0.30 m curved cow horn, domed wooden plug with a
## knob and a brass staple at the base, turned spout ring and stopper. Built along a quadratic curve from
## the plug (origin) to the spout in the horn frame: +Z along the chord, bowing toward +Y.
## `chord` is the plug -> spout distance, `bow` the bulge of the curve at its middle (m).
static func powder_horn(chord := 0.19, bow := 0.018) -> Node3D:
	var a := gear("powder_horn")
	if a:
		# own frame: origin at the plug, +Z along the chord to the spout, +Y up (placed with the MANIFEST's
		# reference_bind_placement by SlingRig)
		a.name = "PowderHornModel"
		return a
	var root := Node3D.new()
	root.name = "PowderHornModel"
	var p0 := Vector3.ZERO
	var p2 := Vector3(0, 0, chord)
	var p1 := Vector3(0, bow * 2.0, chord * 0.5)
	var rings := 22
	var sides := 16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var tans: Array[Vector3] = []
	var rads: Array[float] = []
	for i in rings + 1:
		var t := float(i) / rings
		var p := p0 * (1 - t) * (1 - t) + p1 * 2.0 * (1 - t) * t + p2 * t * t
		var d := (p1 - p0) * 2.0 * (1 - t) + (p2 - p1) * 2.0 * t
		pts.append(p)
		tans.append(d.normalized())
		rads.append(lerpf(0.031, 0.0105, pow(t, 0.85)))
	var base_c := Color(0.9, 0.84, 0.68)
	var mid_c := Color(0.8, 0.65, 0.42)
	var tip_c := Color(0.3, 0.22, 0.15)
	for i in rings:
		for j in sides:
			var quad: Array = []
			for di in [0, 1]:
				for dj in [0, 1]:
					var ii: int = i + di
					var aa := TAU * float(j + dj) / sides
					var tz: Vector3 = tans[ii]
					var nx := Vector3.UP.cross(tz).normalized() if absf(tz.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
					var ny := tz.cross(nx).normalized()
					var nrm := (nx * cos(aa) + ny * sin(aa)).normalized()
					var t := float(ii) / rings
					var c := base_c.lerp(mid_c, clampf(t / 0.6, 0.0, 1.0)) if t < 0.6 else mid_c.lerp(tip_c, clampf((t - 0.6) / 0.4, 0.0, 1.0))
					# two scribed rings near the base and one at the waist
					if absf(t - 0.09) < 0.02 or absf(t - 0.14) < 0.012 or absf(t - 0.62) < 0.015:
						c = c.darkened(0.35)
					quad.append([pts[ii] + nrm * rads[ii], nrm, c])
			for idx in [0, 1, 3, 0, 3, 2]:
				var q: Array = quad[idx]
				st.set_color(q[2])
				st.set_normal(q[1])
				st.add_vertex(q[0])
	var horn := _mesh_node(root, st.commit(), mat("horn_body", Color(1, 1, 1), 0.32, 0.0, true), Transform3D.IDENTITY, "Horn")
	horn.set_meta("sling_part", "horn")
	# domed wooden base plug with a knob, and the brass staple the strap is tied to
	var bz := -tans[0]
	var plug := _mesh_node(root, tube_mesh(0.0, 0.012, 0.0325, 0.0315, 18, true), wood(), along(p0 + tans[0] * 0.004, p0 + bz), "Plug")
	plug.set_meta("sling_part", "plug")
	var dome := SphereMesh.new()
	dome.radius = 0.031
	dome.height = 0.024
	_mesh_node(root, dome, wood(), Transform3D(along(p0, p0 + bz).basis, p0 + bz * 0.012), "Dome")
	var knob := SphereMesh.new()
	knob.radius = 0.008
	knob.height = 0.016
	_mesh_node(root, knob, wood(), Transform3D(Basis(), p0 + bz * 0.026), "Knob")
	var staple := TorusMesh.new()
	staple.inner_radius = 0.004
	staple.outer_radius = 0.0065
	_mesh_node(root, staple, brass(), Transform3D(Basis(Vector3.RIGHT, PI / 2), p0 + Vector3(0, 0.03, 0.006)), "Staple")
	# spout: turned ring, tapering spout, wooden stopper
	var tip := pts[rings]
	var td := tans[rings]
	_mesh_node(root, tube_mesh(0.0, 0.009, 0.0125, 0.0125, 14, true), brass(), along(tip - td * 0.004, tip + td), "SpoutRing")
	_mesh_node(root, tube_mesh(0.0, 0.028, 0.0095, 0.006, 12, true), mat("horn_tip", Color(0.22, 0.16, 0.11), 0.35), along(tip + td * 0.005, tip + td), "Spout")
	_mesh_node(root, tube_mesh(0.0, 0.022, 0.0052, 0.0058, 10, true), wood(), along(tip + td * 0.031, tip + td), "Stopper")
	var sk := SphereMesh.new()
	sk.radius = 0.0065
	sk.height = 0.013
	_mesh_node(root, sk, wood(), Transform3D(Basis(), tip + td * 0.056), "StopperKnob")
	var m1 := Marker3D.new()
	m1.name = "StrapPlug"
	m1.position = p0 + Vector3(0, 0.032, 0.006)
	root.add_child(m1)
	var m2 := Marker3D.new()
	m2.name = "StrapSpout"
	m2.position = tip + Vector3(0, 0.012, 0)
	root.add_child(m2)
	return root


## Leather holster loop of the pistol sling around a hooked pistol's barrel (model frame of the pistol).
static func sling_loop() -> Node3D:
	var a := gear("pistol_sling_loop")
	if a:
		a.name = "SlingLoop"
		return a
	var root := Node3D.new()
	root.name = "SlingLoop"
	_mesh_node(root, tube_mesh(-0.018, 0.018, 0.02, 0.02, 14, false), mat("loop", Color(0.28, 0.17, 0.09), 0.8, 0.0, false, true),
			Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.035, -0.16)))
	return root
