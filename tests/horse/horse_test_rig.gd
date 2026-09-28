extends RefCounted
## Shared set-up for the horse tests: a ground, the Horse and an Actor_B rider (with the
## player's body mesh) on it through HorseRiderLink, plus CPU skinning helpers.
##
##   const Rig := preload("res://tests/horse/horse_test_rig.gd")
##   var r := Rig.new()
##   await r.build(scene_tree)            # r.horse, r.rider, r.link, r.body ...
##   r.pose("trot", 0.25)                 # horse and rider at that phase

var world: Node3D
var horse: Horse
var rider: Node3D
var rider_sk: Skeleton3D
var rider_ap: AnimationPlayer
var body: CharacterBodyMesh
var link: HorseRiderLink
var tree: SceneTree


func build(t: SceneTree, with_body := true, lights := false) -> void:
	tree = t
	world = Node3D.new()
	world.name = "HorseTestWorld"
	t.root.add_child(world)
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(4000, 1, 4000)
	gs.shape = gb
	gs.position = Vector3(0, -0.5, 0)
	ground.add_child(gs)
	world.add_child(ground)
	if lights:
		studio(world)
	horse = Horse.new()
	horse.name = "Horse"
	world.add_child(horse)
	rider = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	rider.name = "Rider"
	world.add_child(rider)
	rider_sk = rider.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	rider_ap = rider.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(rider_sk, rider_ap)
	if with_body:
		body = CharacterBodyMesh.attach(rider_sk, rider_ap)
	link = HorseRiderLink.new()
	link.name = "RiderLink"
	horse.add_child(link)
	await t.process_frame
	link.attach(horse, rider, rider_ap)


## Horse clip `clip` and the rider's clip at `phase` (0..1), no blending.
func pose(clip: String, phase: float) -> void:
	horse.force_clip(clip, phase)
	link.instant = true
	link.sync(0.0)


## Sky, sun, fill light and a ground plane (plus 1 m stakes along the path) under `world`.
static func studio(world: Node3D, plane_size := 40.0, stakes := true) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.42, 0.55, 0.72)
	sm.sky_horizon_color = Color(0.75, 0.78, 0.8)
	sm.ground_bottom_color = Color(0.3, 0.28, 0.24)
	sm.ground_horizon_color = Color(0.6, 0.6, 0.58)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 40, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.25
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 220, 0)
	fill.light_energy = 0.35
	world.add_child(fill)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(plane_size, plane_size)
	plane.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.40, 0.42, 0.36)
	plane.material_override = gm
	world.add_child(plane)
	# a line of stakes every metre along the horse's path, for scale
	for i in (range(-6, 7) if stakes else []):
		var st := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.02
		cm.height = 0.5 if i % 5 == 0 else 0.25
		st.mesh = cm
		st.position = Vector3(1.2, cm.height * 0.5, float(i))
		var sm2 := StandardMaterial3D.new()
		sm2.albedo_color = Color(0.85, 0.82, 0.7)
		st.material_override = sm2
		world.add_child(st)


# ---------------------------------------------------------------------------
# CPU skinning
# ---------------------------------------------------------------------------
## Surfaces of the horse's meshes as dictionaries {name, v, n, bo, w, nb, bind}.
static func horse_surfaces(h: Horse, names: Array) -> Array:
	var out := []
	for mi: MeshInstance3D in h.visual.find_children("*", "MeshInstance3D", true, false):
		if not names.is_empty() and not (String(mi.name) in names):
			continue
		var arr := mi.mesh.surface_get_arrays(0)
		var skin := mi.skin
		var bind := []
		for b in skin.get_bind_count():
			var bi := skin.get_bind_bone(b)
			if bi < 0:
				bi = h.skeleton.find_bone(skin.get_bind_name(b))
			bind.append([bi, skin.get_bind_pose(b)])
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		out.append({"name": String(mi.name), "v": v, "n": arr[Mesh.ARRAY_NORMAL], "bo": arr[Mesh.ARRAY_BONES],
				"w": arr[Mesh.ARRAY_WEIGHTS], "nb": (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / maxi(v.size(), 1),
				"bind": bind})
	return out


## World positions and normals of a horse surface in the current pose.
static func skin_horse(h: Horse, sf: Dictionary) -> Array:
	var sk := h.skeleton
	var g := sk.global_transform
	var m: Array[Transform3D] = []
	for b: Array in sf.bind:
		m.append(g * sk.get_bone_global_pose(b[0]) * (b[1] as Transform3D))
	return _skin(sf, m)


## Rider surfaces {mesh name, surface index, material} -> dictionaries like above.
static func rider_surfaces(body: CharacterBodyMesh, want: Array) -> Array:
	var out := []
	for mi in body.meshes:
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var label := "%s/%s" % [mi.name, mat.resource_name if mat else str(s)]
			if not want.is_empty() and not (label in want):
				continue
			var arr := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			out.append({"name": label, "v": v, "n": arr[Mesh.ARRAY_NORMAL], "bo": arr[Mesh.ARRAY_BONES],
					"w": arr[Mesh.ARRAY_WEIGHTS], "nb": (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() / maxi(v.size(), 1),
					"skin": mi.skin})
	return out


static func skin_rider(body: CharacterBodyMesh, sk: Skeleton3D, sf: Dictionary) -> Array:
	var g := body.skinning_globals()
	var gt := sk.global_transform
	var skin: Skin = sf.skin
	var m: Array[Transform3D] = []
	for b in skin.get_bind_count():
		m.append(gt * g[skin.get_bind_bone(b)] * skin.get_bind_pose(b))
	return _skin(sf, m)


static func _skin(sf: Dictionary, m: Array[Transform3D]) -> Array:
	var v: PackedVector3Array = sf.v
	var nn: PackedVector3Array = sf.n
	var bo: PackedInt32Array = sf.bo
	var w: PackedFloat32Array = sf.w
	var nb: int = sf.nb
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	P.resize(v.size())
	N.resize(v.size())
	for i in v.size():
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		for k in nb:
			var ww := w[i * nb + k]
			if ww <= 0.0:
				continue
			var t: Transform3D = m[bo[i * nb + k]]
			p += (t * v[i]) * ww
			n += (t.basis * nn[i]) * ww
		P[i] = p
		N[i] = n.normalized()
	return [P, N]
