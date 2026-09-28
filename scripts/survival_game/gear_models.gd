class_name GearModels
extends RefCounted
## Procedural models of the trapper's and the shot-maker's gear (user 2026-09-28: "making your gear", "trapping lines"),
## for the inventory icons (ItemIcons: the camera looks at a model's side from +X, up +Y): cordage, deadfall stakes, a
## steel trap, bar lead, the bullet mould, hooks and line; what the trap line takes: the small furs' pelts (marten, mink,
## fisher, raccoon: WildlifeModels' stretched hide in their colours) and a hare's meat, raw and roast. The project's own
## (no assets).

const KINDS := ["cordage", "stake_set", "steel_trap", "bar_lead", "bullet_mould", "hooks_line", "marten_pelt", "mink_pelt",
		"fisher_pelt", "raccoon_pelt", "small_game", "roast_small_game", "charred_small_game", "flint_knife", "bow_drill", "bone_awl", "charcoal", "bar_iron", "gun_barrel", "pistol_barrel", "gunlock", "gunstock"]
## The small furs' hides: back, belly, size (WildlifeModels._hide), a tail.
const PELT_LOOK := {
	"marten_pelt": [Color(0.43, 0.28, 0.15), Color(0.86, 0.62, 0.3), 0.42, true],
	"mink_pelt": [Color(0.2, 0.12, 0.07), Color(0.27, 0.17, 0.1), 0.34, true],
	"fisher_pelt": [Color(0.15, 0.11, 0.08), Color(0.36, 0.3, 0.24), 0.55, true],
	"raccoon_pelt": [Color(0.44, 0.41, 0.37), Color(0.62, 0.58, 0.52), 0.58, true],
}

static var _mats := {}


static func has(kind: String) -> bool:
	return kind in KINDS


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind
	if PELT_LOOK.has(kind):
		var lk: Array = PELT_LOOK[kind]
		WildlifeModels._hide(root, lk[0], lk[1], float(lk[2]), bool(lk[3]))
		if kind == "raccoon_pelt":
			# the ringed tail
			var ring := _mat("coon_ring", Color(0.12, 0.1, 0.09), 0.95, 0.0)
			for i in 3:
				_box(root, Vector3(0.014, 0.05 * 0.58, 0.012), Vector3(0, 0, (0.15 + i * 0.03) * 0.58), ring)
		return root
	match kind:
		"small_game", "roast_small_game", "charred_small_game":
			# a dressed hare's saddle and two hind legs (raw red, roast brown, burnt black)
			var c: Color = {"small_game": Color(0.62, 0.2, 0.17), "roast_small_game": Color(0.5, 0.3, 0.14),
					"charred_small_game": Color(0.12, 0.09, 0.07)}[kind]
			var meat := _mat("hare_" + kind, c, 0.6 if kind == "small_game" else 0.75, 0.0)
			_sphere(root, Vector3(0.035, 0.03, 0.08), Vector3.ZERO, meat)
			for sd: float in [-1.0, 1.0]:
				_limb(root, Vector3(0.02 * sd, -0.005, 0.06), Vector3(0.035 * sd, -0.01, 0.15), 0.014, meat)
			_limb(root, Vector3(0.0, 0.0, -0.07), Vector3(0.0, 0.01, -0.11), 0.012, meat)
		"flint_knife":
			# a knapped chert blade, leaf-shaped, set in a split wooden handle and bound with sinew
			var chert := _mat("chert", Color(0.26, 0.26, 0.28), 0.5, 0.0)
			# (a flat leaf: an ellipsoid thin across, the point at +Z; the knapping scars as a few flatter facets)
			_sphere(root, Vector3(0.0045, 0.017, 0.065), Vector3(0, 0, 0.05), chert)
			for k in 4:
				var f := _sphere(root, Vector3(0.0048, 0.008, 0.014), Vector3(0, 0.006 * (1 - 2 * (k % 2)), 0.02 + 0.022 * k), _mat("chert_scar", Color(0.33, 0.33, 0.35), 0.4, 0.0))
				f.rotation.x = 0.3 * (1 - 2 * (k % 2))
			_limb(root, Vector3(0, 0, -0.1), Vector3(0, 0, 0.005), 0.011, _mat("knife_handle", Color(0.45, 0.33, 0.2), 0.8, 0.0))
			for i in 3:
				root.add_child(_cyl(0.0125, 0.0125, 0.005, Vector3(0, 0, -0.012 - i * 0.007), _mat("sinew_wrap", Color(0.78, 0.7, 0.52), 0.9, 0.0)))
				(root.get_child(root.get_child_count() - 1) as Node3D).rotation.x = PI * 0.5
		"charcoal":
			# a handful of charcoal: black, glossy at the cracks, the grain of the wood still in it
			var coal := _mat("charcoal", Color(0.07, 0.07, 0.075), 0.55, 0.0)
			for i in 5:
				var p := Vector3((i % 3 - 1) * 0.03, 0.012 + 0.01 * (i / 3), (i / 3) * 0.025 - 0.01)
				var bx := _box(root, Vector3(0.028 + 0.006 * (i % 2), 0.02, 0.05 - 0.006 * i), p, coal)
				bx.rotation = Vector3(0.2 * i, 0.9 * i, 0.1 * i)
		"bar_iron":
			# a bar of wrought iron, dark, hammer-flattened, its ends rough
			var iron2 := _mat("wrought", Color(0.2, 0.19, 0.18), 0.6, 0.7)
			_box(root, Vector3(0.03, 0.015, 0.2), Vector3.ZERO, iron2)
			_box(root, Vector3(0.032, 0.017, 0.02), Vector3(0, 0, 0.09), _mat("scale", Color(0.28, 0.2, 0.15), 0.8, 0.3))
		"gun_barrel", "pistol_barrel":
			# a barrel: octagonal at the breech, round forward, the breech plug and its tang
			var iron3 := _mat("barrel_iron", Color(0.22, 0.21, 0.2), 0.45, 0.8)
			var l := 0.34 if kind == "gun_barrel" else 0.16
			_limb(root, Vector3(0, 0, -l * 0.5), Vector3(0, 0, -l * 0.5 + 0.06), 0.013, iron3)
			_limb(root, Vector3(0, 0, -l * 0.5 + 0.06), Vector3(0, 0, l * 0.5), 0.010, iron3)
			_box(root, Vector3(0.008, 0.004, 0.03), Vector3(0, 0.004, -l * 0.5 - 0.015), iron3)
		"gunlock":
			# the lockplate, the cock with its flint, the frizzen and the mainspring under
			var iron4 := _mat("lock_iron", Color(0.24, 0.23, 0.22), 0.45, 0.75)
			_box(root, Vector3(0.006, 0.03, 0.13), Vector3.ZERO, iron4)
			var cock := _box(root, Vector3(0.008, 0.04, 0.012), Vector3(0.006, 0.025, -0.02), iron4)
			cock.rotation.x = -0.5
			_box(root, Vector3(0.009, 0.008, 0.014), Vector3(0.006, 0.045, -0.005), _mat("flint_chip", Color(0.3, 0.3, 0.32), 0.4, 0.0))
			_box(root, Vector3(0.008, 0.035, 0.01), Vector3(0.006, 0.03, 0.03), iron4)
			_box(root, Vector3(0.004, 0.006, 0.07), Vector3(0.006, -0.01, 0.02), iron4)
		"gunstock":
			# a carved stock: the butt, the wrist, the fore-end with its barrel channel
			var wood2 := _mat("stock_wood", Color(0.42, 0.26, 0.14), 0.6, 0.0)
			var butt := _box(root, Vector3(0.035, 0.1, 0.14), Vector3(0, -0.02, 0.11), wood2)
			butt.rotation.x = 0.12
			_box(root, Vector3(0.028, 0.035, 0.08), Vector3(0, 0.01, 0.0), wood2)
			_box(root, Vector3(0.026, 0.024, 0.22), Vector3(0, 0.016, -0.14), wood2)
			_box(root, Vector3(0.012, 0.006, 0.22), Vector3(0, 0.03, -0.14), _mat("channel", Color(0.3, 0.18, 0.1), 0.7, 0.0))
		"bone_awl":
			# an antler tine ground to a point, a strip of hide wound round its butt for the grip
			var bone := _mat("antler_bone", Color(0.8, 0.74, 0.6), 0.75, 0.0)
			_limb(root, Vector3(0, 0.004, -0.07), Vector3(0, 0.0, 0.035), 0.009, bone)
			_limb(root, Vector3(0, 0.0, 0.035), Vector3(0, -0.002, 0.085), 0.0045, bone)
			_limb(root, Vector3(0, -0.002, 0.085), Vector3(0, -0.003, 0.1), 0.0012, bone)
			for i in 4:
				root.add_child(_cyl(0.0105, 0.0105, 0.006, Vector3(0, 0.004, -0.06 + i * 0.008), _mat("hide_wrap", Color(0.5, 0.36, 0.22), 0.9, 0.0)))
				(root.get_child(root.get_child_count() - 1) as Node3D).rotation.x = PI * 0.5
		"bow_drill":
			# the fire kit: a bow with its cord, the spindle, the hearth board with its notched sockets, the bearing block
			var wood := _mat("drill_wood", Color(0.52, 0.4, 0.26), 0.85, 0.0)
			var cord2 := _mat("cord", Color(0.72, 0.62, 0.45), 0.85, 0.0)
			var pts := []
			for i in 7:
				var t := i / 6.0
				pts.append(Vector3(0.0, 0.035 * sin(t * PI), -0.2 + 0.4 * t))
			for i in 6:
				_limb(root, pts[i] + Vector3(0.04, 0, 0), pts[i + 1] + Vector3(0.04, 0, 0), 0.006, wood)
			_limb(root, pts[0] + Vector3(0.04, 0, 0), pts[6] + Vector3(0.04, 0, 0), 0.0015, cord2)
			_limb(root, Vector3(-0.02, 0.0, -0.12), Vector3(-0.02, 0.0, 0.12), 0.009, wood)
			_box(root, Vector3(0.03, 0.012, 0.26), Vector3(-0.065, -0.012, 0.0), wood)
			for i in 3:
				_box(root, Vector3(0.012, 0.004, 0.012), Vector3(-0.065, -0.004, -0.07 + i * 0.07), _mat("char", Color(0.1, 0.08, 0.06), 0.9, 0.0))
			_box(root, Vector3(0.04, 0.02, 0.04), Vector3(-0.02, 0.0, 0.16), _mat("block", Color(0.46, 0.44, 0.4), 0.7, 0.0))
		"cordage":
			# a hank of twisted sinew cord, wound in loops, a tail hanging
			var cord := _mat("cord", Color(0.72, 0.62, 0.45), 0.85, 0.0)
			for i in 5:
				var t := TorusMesh.new()
				t.inner_radius = 0.052 - i * 0.002
				t.outer_radius = 0.06 - i * 0.002
				t.rings = 24
				t.ring_segments = 6
				var mi := MeshInstance3D.new()
				mi.mesh = t
				mi.material_override = cord
				# (laid flat, loop on loop, each a little askew)
				mi.rotation = Vector3(deg_to_rad(6.0 * sin(i * 1.7)), deg_to_rad(i * 23.0), deg_to_rad(5.0 * cos(i * 1.3)))
				mi.position = Vector3(i * 0.002, i * 0.006, 0.0)
				root.add_child(mi)
			_limb(root, Vector3(0.0, 0.02, 0.055), Vector3(0.03, 0.02, 0.11), 0.004, cord)
		"stake_set":
			# a bundle: two forked stakes, the fall's trigger and bait stick, bound with bark
			var wood := _mat("stake", Color(0.62, 0.5, 0.34), 0.8, 0.0)
			var bark := _mat("stake_bark", Color(0.33, 0.24, 0.16), 0.95, 0.0)
			for i in 4:
				var off := Vector3((i % 2) * 0.018 - 0.009, (i / 2) * 0.018 - 0.009, 0.0)
				var len := 0.2 - i * 0.025
				_limb(root, off + Vector3(0, 0, -len * 0.5), off + Vector3(0, 0, len * 0.5), 0.008 - i * 0.001, wood)
			_limb(root, Vector3(0.0, 0.0, 0.03), Vector3(0.0, 0.035, 0.07), 0.005, wood)
			var band := _cyl(0.027, 0.027, 0.018, Vector3.ZERO, bark)
			band.rotation.x = PI * 0.5
			root.add_child(band)
		"steel_trap":
			# a long-spring steel trap, set: the jaws open flat, the pan between them, the spring along, the chain
			var iron := _mat("iron", Color(0.24, 0.23, 0.22), 0.55, 0.8)
			# (the jaws open flat: one ring, a little oval)
			var jaw := TorusMesh.new()
			jaw.inner_radius = 0.085
			jaw.outer_radius = 0.097
			jaw.rings = 28
			jaw.ring_segments = 6
			var j := MeshInstance3D.new()
			j.mesh = jaw
			j.material_override = iron
			j.scale = Vector3(1.0, 1.0, 0.8)
			root.add_child(j)
			# the base plate across, the pan in the middle, the dog over it
			_box(root, Vector3(0.2, 0.008, 0.022), Vector3(0.0, -0.004, 0.0), iron)
			root.add_child(_cyl(0.035, 0.035, 0.006, Vector3(0, 0.004, 0), iron))
			_box(root, Vector3(0.008, 0.006, 0.06), Vector3(0.0, 0.009, -0.03), iron)
			# the long spring out to one side, its eye round the jaws' end
			_box(root, Vector3(0.014, 0.012, 0.15), Vector3(0.0, 0.0, 0.16), iron)
			_box(root, Vector3(0.034, 0.02, 0.022), Vector3(0.0, 0.006, 0.235), iron)
			for i in 4:
				var link := TorusMesh.new()
				link.inner_radius = 0.008
				link.outer_radius = 0.012
				link.rings = 10
				link.ring_segments = 4
				var l := MeshInstance3D.new()
				l.mesh = link
				l.material_override = iron
				l.position = Vector3(0.0, 0.0, -0.08 - i * 0.02)
				l.rotation = Vector3(PI * 0.5 * (i % 2), 0.0, PI * 0.5)
				root.add_child(l)
		"bar_lead":
			# a pound of bar lead, dull blue-grey, the maker's stamp
			var lead := _mat("lead", Color(0.44, 0.46, 0.5), 0.45, 0.6)
			_box(root, Vector3(0.035, 0.022, 0.16), Vector3.ZERO, lead)
			_box(root, Vector3(0.02, 0.002, 0.03), Vector3(0.0, 0.012, 0.0), _mat("lead_stamp", Color(0.34, 0.35, 0.38), 0.6, 0.5))
		"bullet_mould":
			# the scissor mould: two long handles, the round-ball head, and the ladle beside it
			var iron := _mat("iron", Color(0.24, 0.23, 0.22), 0.55, 0.8)
			var wood := _mat("mould_wood", Color(0.4, 0.27, 0.15), 0.7, 0.0)
			_limb(root, Vector3(0.012, 0.0, 0.08), Vector3(0.004, 0.0, -0.1), 0.006, wood)
			_limb(root, Vector3(-0.012, 0.0, 0.08), Vector3(-0.004, 0.0, -0.1), 0.006, wood)
			_box(root, Vector3(0.04, 0.03, 0.035), Vector3(0.0, 0.0, 0.1), iron)
			_limb(root, Vector3(0.05, -0.01, 0.06), Vector3(0.05, -0.01, -0.09), 0.004, iron)
			var bowl := _sphere(root, Vector3(0.022, 0.012, 0.022), Vector3(0.05, -0.008, 0.08), iron)
			bowl.name = "Ladle"
		"hooks_line":
			# a winding stick of linen line, a hook and a lead shot
			var wood := _mat("winder", Color(0.58, 0.46, 0.3), 0.8, 0.0)
			var line := _mat("line", Color(0.85, 0.82, 0.72), 0.9, 0.0)
			var iron := _mat("iron", Color(0.24, 0.23, 0.22), 0.55, 0.8)
			_box(root, Vector3(0.012, 0.03, 0.12), Vector3.ZERO, wood)
			_box(root, Vector3(0.016, 0.022, 0.08), Vector3.ZERO, line)
			_limb(root, Vector3(0.0, 0.01, 0.06), Vector3(0.0, -0.03, 0.1), 0.0012, line)
			var hook := TorusMesh.new()
			hook.inner_radius = 0.009
			hook.outer_radius = 0.0115
			hook.rings = 12
			hook.ring_segments = 4
			var h := MeshInstance3D.new()
			h.mesh = hook
			h.material_override = iron
			h.position = Vector3(0.0, -0.042, 0.1)
			h.rotation.z = PI * 0.5
			root.add_child(h)
			_sphere(root, Vector3(0.006, 0.006, 0.006), Vector3(0.0, -0.022, 0.092), _mat("lead", Color(0.44, 0.46, 0.5), 0.45, 0.6))
	return root


static func _mat(key: String, c: Color, rough: float, metal: float) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, radii: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 12
	s.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.scale = radii
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	return mi


## A round rod from a to b.
static func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var len := a.distance_to(b)
	var mi := _cyl(r, r, len, (a + b) * 0.5, mat)
	var d := (b - a).normalized()
	if absf(d.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, d))
	parent.add_child(mi)
	return mi
