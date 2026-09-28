extends Node3D
## Traversal test course and standalone preview, SOURCE CLIPS ONLY (user decision 2026-09-24;
## design 17 TW0 / TW8). Every obstacle sits at the height its Actor_B clip was made for
## (traversal_runtime.json authored_h) and every move has a clean, straight approach.
##
## Open scenes/traversal_course.tscn and press F6 to play it with the keyboard (WASD, Shift =
## free-run, Space = careful move, mouse = camera, wheel = distance, 1-9 = stations, F2 = debug
## draw), or run it from the tests and tools:
##   Godot --path . res://scenes/traversal_course.tscn -- [station=A_vaults]
##
## Stations (the runner starts at `start` and runs toward -Z):
##   A  sprint vaults 0.95 / 0.99 m walls and a split-rail fence (free-run)
##   B  standing vault 0.75 m, step-on 0.5 m, tall vault 1.58 m wall with the fall exit (careful)
##   C  jump-up lane: tops 0.79 / 1.34 / 2.0 / 3.0 m (knee, knee 1.5, chest, jump to hang +
##      hang climb-up), each dropped off at the back (drop + landing)
##   D  standing knee mantle 0.98 m (careful)
##   E  ladder to a 4.07 m platform (rungs where the ladder clips' hands and feet hold them)
##   F  beams: fallen log (step onto its end, balance walk) and a raised beam between 2 m platforms
##   G  big tree: a ladder up the trunk to a hunter's stand and a thick branch to walk out on
##   H  gaps between 1 m platforms: 1.2 m (one-foot jump) and 3.0 m (long jump)
##   J  crouch-under tunnel (clearance 1.2 m)
##   K  narrow ledge along a wall (wall shimmy), from a 1 m platform to another
##   L  squeeze-through gap between two rocks (the gap is sized from the clip's own path)
##   M  auto ledge generation from a convex rock hull and a triangle-mesh block (debug draw)
## Everything is built in code and tagged per the level-authoring conventions (design 14): plain
## static boxes are vaultable / climbable with no tags; ladders, narrow ledges, tunnels and the
## squeeze gap are markers; logs and branches are horizontal cylinders (auto beams).

const GROUND := 0.0

var registry := TravShapeRegistry.new()
var ledges: TravLedgeGraph
var baker: TravLedgeBaker
var runner: TravPreviewRunner
var controller: TraversalController
var actor: TravPreviewActor
var camera: Camera3D
var mode := "play"
var cam_distance := 4.2
var cam_pitch := -0.3
var cam_yaw := 0.0
var cam_target := Vector3.ZERO
var cam_vel := Vector3.ZERO
var cam_override := {}           ## {pos, look} fixed camera (screenshots)
var stations := {}               ## name -> {start: Vector3, yaw: float, note, obstacle: Vector3}
var ready_done := false
var _debug_mesh: MeshInstance3D
var _mats := {}
var _args := {}

signal course_ready


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	mode = str(_args.get("course", "play"))
	InputSetup.ensure()
	_environment()
	build_course()
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake()
	_spawn()
	ready_done = true
	course_ready.emit()


# --------------------------------------------------------------------------------------------------
# Environment and materials
# --------------------------------------------------------------------------------------------------

func _environment() -> void:
	var headless := DisplayServer.get_name() == "headless"
	if not headless and ClassDB.class_exists("EnvironmentRig") and not _args.has("plain_env"):
		var rig := EnvironmentRig.new()
		rig.name = "EnvironmentRig"
		add_child(rig)
		rig.build(WorldSettings.preset("medium"))
	else:
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		we.environment = env
		add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -35, 0)
		sun.shadow_enabled = true
		add_child(sun)


func _mat(name: String) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	var c: Color = {"ground": Color(0.36, 0.42, 0.26), "wood": Color(0.45, 0.31, 0.19), "stone": Color(0.52, 0.52, 0.5),
			"cliff": Color(0.48, 0.45, 0.42), "bark": Color(0.33, 0.24, 0.17), "crate": Color(0.58, 0.43, 0.25),
			"leaf": Color(0.22, 0.38, 0.16), "rail": Color(0.5, 0.36, 0.22), "rock": Color(0.47, 0.46, 0.43)}.get(name, Color(0.6, 0.6, 0.6))
	m.albedo_color = c
	m.roughness = 0.9
	_mats[name] = m
	return m


# --------------------------------------------------------------------------------------------------
# Builders (one feature per shape, design 14.6)
# --------------------------------------------------------------------------------------------------

func _body(name: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	add_child(b)
	return b


func box(name: String, center: Vector3, size: Vector3, mat := "wood", meta := {}, yaw := 0.0) -> StaticBody3D:
	var b := _body(name)
	b.position = center
	b.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.name = "Shape"
	if not meta.is_empty():
		cs.set_meta("trav", meta)
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(mat)
	b.add_child(mi)
	b.set_meta("surface", {"wood": "wood", "crate": "wood", "rail": "wood", "stone": "stone", "cliff": "stone"}.get(mat, ""))
	return b


func cylinder(name: String, center: Vector3, radius: float, height: float, mat := "bark", axis := Vector3.UP, meta := {},
		capsule := false) -> StaticBody3D:
	var b := _body(name)
	b.position = center
	var up := axis.normalized()
	if absf(up.dot(Vector3.UP)) < 0.999:
		var x := up.cross(Vector3.UP).normalized()
		var z := x.cross(up).normalized()
		b.basis = Basis(x, up, z)
	var cs := CollisionShape3D.new()
	var sh: Shape3D
	var mesh: Mesh
	if capsule:
		var cap := CapsuleShape3D.new()
		cap.radius = radius
		cap.height = height
		sh = cap
		var cm := CapsuleMesh.new()
		cm.radius = radius
		cm.height = height
		mesh = cm
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		sh = cyl
		var cm2 := CylinderMesh.new()
		cm2.top_radius = radius
		cm2.bottom_radius = radius
		cm2.height = height
		mesh = cm2
	cs.shape = sh
	cs.name = "Shape"
	if not meta.is_empty():
		cs.set_meta("trav", meta)
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(mat)
	b.add_child(mi)
	return b


func label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.005
	l.modulate = Color(1, 1, 0.85)
	l.outline_size = 8
	add_child(l)


func _station(name: String, start: Vector3, note: String, obstacle := Vector3.ZERO, yaw := 0.0) -> void:
	stations[name] = {"start": start, "yaw": yaw, "note": note, "obstacle": obstacle}


## Height the course uses for a move: its authored height (traversal_runtime.json).
func authored(move_id: String, fallback: float) -> float:
	var m := TravMoveLibrary.shared().move(move_id)
	return float(m.get("authored_h", fallback))


# --------------------------------------------------------------------------------------------------
# The course
# --------------------------------------------------------------------------------------------------

func build_course() -> void:
	var g := box("Ground", Vector3(60, -0.5, -20), Vector3(220, 1.0, 120), "ground")
	registry.register(g.get_node("Shape"), {"kind": "terrain", "overlap": "never"})
	_vaults_sprint(Vector3(0, 0, 0))
	_vaults_standing(Vector3(10, 0, 0))
	_jump_ups(Vector3(20, 0, 0))
	_mantle_standing(Vector3(30, 0, 0))
	_ladder_platform(Vector3(40, 0, 0))
	_beams(Vector3(52, 0, 0))
	_tree(Vector3(66, 0, 0))
	_gaps(Vector3(80, 0, 0))
	_tunnel(Vector3(90, 0, 0))
	_sidle_ledge(Vector3(100, 0, 0))
	_squeeze(Vector3(112, 0, 0))
	_rock_and_mesh(Vector3(124, 0, 0))
	# Z: open flat ground (the strict test's locomotion baseline: the preview's own walk, run and
	# sprint, which have no foot IK).
	_station("Z_loco", Vector3(150, 0, 35), "plain locomotion (test baseline)")


## A: sprint vaults (p-sprint-vault-1..4, hands at 0.95 m) over thin walls and a split-rail fence.
## The second wall is 4 cm above the authored height, inside the move's band (which ends +5 cm
## above it: user decision 2026-09-24, a hand-planting move used higher pops its hand).
func _vaults_sprint(o: Vector3) -> void:
	var h := authored("vault_sprint", 0.95)
	_station("A_vaults", o + Vector3(0, 0, 14), "sprint vaults %.2f / %.2f m, fence" % [h, h + 0.04], o + Vector3(0, 0, 6))
	label("A  sprint vaults", o + Vector3(0, 2.4, 11))
	box("A_wall_1", o + Vector3(0, h * 0.5, 6.0), Vector3(2.4, h, 0.3), "stone")
	box("A_wall_2", o + Vector3(0, (h + 0.04) * 0.5, -4.0), Vector3(2.4, h + 0.04, 0.3), "stone")
	for px in [-1.6, 1.6]:
		box("A_fence_post_%d" % int(px * 10), o + Vector3(px, 0.55, -14.0), Vector3(0.12, 1.1, 0.12), "rail")
	for ry in [0.45, h - 0.045]:
		box("A_fence_rail_%d" % int(ry * 100), o + Vector3(0, ry, -14.0), Vector3(3.4, 0.09, 0.09), "rail")


## B: careful (walk + Space) standing vault 0.75 m, step-on 0.5 m, tall vault 1.58 m.
func _vaults_standing(o: Vector3) -> void:
	var hv := authored("vault_idle", 0.75)
	var hs := authored("step_on", 0.5)
	var ht := authored("vault_tall_fall", 1.58)
	_station("B_vault_idle", o + Vector3(0, 0, 11.5), "standing vault %.2f m" % hv, o + Vector3(0, 0, 8))
	_station("B_step_on", o + Vector3(0, 0, 3.4), "step-on %.2f m" % hs, o + Vector3(0, 0, 0))
	_station("B_tall", o + Vector3(0, 0, -6.4), "tall vault %.2f m (fall exit)" % ht, o + Vector3(0, 0, -10))
	label("B  standing vault / step-on / tall vault", o + Vector3(0, 2.8, 11))
	box("B_wall_vault", o + Vector3(0, hv * 0.5, 8.0), Vector3(2.4, hv, 0.3), "stone")
	box("B_step", o + Vector3(0, hs * 0.5, -0.6), Vector3(2.4, hs, 1.6), "crate")
	box("B_wall_tall", o + Vector3(0, ht * 0.5, -10.0), Vector3(3.0, ht, 0.35), "wood")


## C: free-run jump-up lane: deep tops at the knee (run), knee 1.5 m, chest 2 m and 3 m heights;
## the runner climbs each, crosses the top and drops off the back (drop_fall + landing).
func _jump_ups(o: Vector3) -> void:
	var hs := [authored("mantle_1m_run", 0.79), authored("mantle_1_5m", 1.34), authored("climb_chest", 2.0),
			authored("climb_hang_3m", 3.0)]
	var names := ["C_knee", "C_knee_1_5", "C_chest", "C_hang_3m"]
	label("C  jump-ups %.2f / %.2f / %.2f / %.2f m" % hs, o + Vector3(0, 3.6, 12))
	var z := 6.0
	for i in hs.size():
		var h: float = hs[i]
		box(names[i], o + Vector3(0, h * 0.5, z - 1.25), Vector3(3.0, h, 2.5), "stone")
		_station(str(names[i]), o + Vector3(0, 0, z + 8.0), "top %.2f m" % h, o + Vector3(0, 0, z))
		z -= 11.0


## D: careful standing knee mantle onto a 0.98 m top.
func _mantle_standing(o: Vector3) -> void:
	var h := authored("mantle_1m_idle", 0.98)
	_station("D_mantle_idle", o + Vector3(0, 0, 9.0), "standing knee mantle %.2f m" % h, o + Vector3(0, 0, 6))
	label("D  standing mantle %.2f m" % h, o + Vector3(0, 2.4, 10))
	box("D_block", o + Vector3(0, h * 0.5, 6.0 - 1.25), Vector3(3.0, h, 2.5), "stone")


## A ladder the source clips fit (contact pass 2026-09-25): rungs TravLaneClimb.PITCH (0.295 m)
## apart with a radius of 1.0 cm (the closed fists' holes are 1.1-1.7 cm; the old 2 cm radius put the fingers into them), the
## first under the feet at the end of the mount, the top `steps` hub positions (two rungs each)
## above the mount's hub, where the top dismount's hands reach it (TravLaneClimb.top_height). (The
## rungs used to be 0.2425 m apart from the survey's odometry of the fast cycles, which lets the held
## limbs slip 12 % per cycle, and their tops sat at the hub's palms: the fists hovered on the rungs.)
func _ladder(name: String, base: Vector3, steps: int, outward: Vector3) -> TravLadder:
	var height := TravLaneClimb.top_height(steps)
	var pitch := TravLaneClimb.PITCH
	var rr := TravLaneClimb.RUNG_R
	var offset := TravLaneClimb.first_rung_top()
	var side := Vector3.UP.cross(outward).normalized()
	var lad := Node3D.new()
	lad.name = name + "_visual"
	add_child(lad)
	for sx in [-0.25, 0.25]:
		var r := MeshInstance3D.new()
		var bm := BoxMesh.new()
		# Rails 0.3 m deep: they reach back to the wall the rungs stand 0.25 m off.
		bm.size = Vector3(0.06, height + 0.3, 0.3) if absf(outward.z) > 0.5 else Vector3(0.3, height + 0.3, 0.06)
		r.mesh = bm
		r.material_override = _mat("wood")
		r.position = base + side * sx + Vector3.UP * (height + 0.3) * 0.5 - outward.normalized() * 0.12
		lad.add_child(r)
	var k := 0
	while offset + k * pitch <= height + 0.01:
		var rung := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rr
		cm.bottom_radius = rr
		cm.height = 0.5
		rung.mesh = cm
		rung.material_override = _mat("rail")
		rung.position = base + Vector3.UP * (offset + k * pitch - rr)
		rung.basis = Basis(Vector3(0, 0, 1), PI * 0.5) if absf(side.x) > 0.5 else Basis(Vector3(1, 0, 0), PI * 0.5)
		lad.add_child(rung)
		k += 1
	var m := TravLadder.new()
	m.name = name + "_marker"
	m.position = base
	m.bottom = Vector3.ZERO
	m.top = Vector3(0, height, 0)
	m.outward = outward
	m.rung_pitch = pitch
	m.rung_offset = offset
	m.rung_radius = rr
	m.rail = false
	add_child(m)
	return m


## E: a 4.07 m platform with a ladder (TravLadder marker). The rungs stand 0.25 m off the platform's
## face: the climbing clips' toes reach ~0.22 m past the rung line (at 5 cm they went 5-17 cm into
## the platform; review 2026-09-24).
func _ladder_platform(o: Vector3) -> void:
	# (4.07 m: four hub positions above the mount's; TravLaneClimb.top_height.)
	var h := TravLaneClimb.top_height(4)
	_station("E_ladder", o + Vector3(0, 0, 3.5), "ladder %.2f m" % h, o + Vector3(0, 0, -7.75))
	label("E  ladder", o + Vector3(0, 5.2, -6))
	box("E_platform", o + Vector3(0, h * 0.5, -11.0), Vector3(6.0, h, 6.0), "wood")
	_ladder("E_ladder", o + Vector3(0, 0, -7.75), 4, Vector3(0, 0, 1))


## F: a fallen log on the ground (a horizontal cylinder: auto beam, width 0.4) and a raised beam
## (a 0.3 m box between two 2 m platforms: auto beam).
func _beams(o: Vector3) -> void:
	_station("F_log", o + Vector3(-2.5, 0, 4.0), "fallen log (step onto its end, balance walk)", o + Vector3(-2.5, 0.4, 2.5))
	_station("F_beam", o + Vector3(3.0, 2.0, -2.0), "raised beam 2 m between platforms", o + Vector3(3.0, 2.0, -5.0))
	label("F  log / raised beam", o + Vector3(0, 3.4, 6))
	var log := cylinder("F_log", o + Vector3(-2.5, 0.2, -1.0), 0.2, 7.0, "bark", Vector3(0, 0, 1))
	log.get_node("Shape").set_meta("trav", {"kind": "log", "surface": "bark"})
	box("F_platform_1", o + Vector3(3.0, 1.0, -2.0), Vector3(3.0, 2.0, 3.0), "wood")
	box("F_beam", o + Vector3(3.0, 1.85, -6.5), Vector3(0.3, 0.3, 6.0), "wood")
	box("F_platform_2", o + Vector3(3.0, 1.0, -11.0), Vector3(3.0, 2.0, 3.0), "wood")


## G: a big oak proxy: a ladder on the trunk to a hunter's stand at 2.89 m and a thick branch
## (capsule, r 0.2, auto beam) walked out from the stand.
func _tree(o: Vector3) -> void:
	var t := o + Vector3(0, 0, -6)
	# (The stand at 2.89 m: two hub positions above the mount's, where the ladder's top dismount
	# reaches it; TravLaneClimb.top_height.)
	var hs := TravLaneClimb.top_height(2)
	_station("G_tree", o + Vector3(0, 0, -1.5), "ladder up the trunk to the stand", t + Vector3(0, 0, 2.0))
	_station("G_branch", t + Vector3(-0.1, hs, 1.15), "thick branch from the stand", t + Vector3(-2.5, hs, 1.15), PI * 0.5)
	label("G  big tree: stand + thick branch", o + Vector3(0, 7.0, -4))
	var trunk := cylinder("G_trunk", t + Vector3(0, 6.0, 0), 0.55, 12.0, "bark")
	trunk.add_to_group("trees")
	registry.register(trunk.get_node("Shape"), {"kind": "tree_trunk", "surface": "bark"})
	var crown := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.6
	sm.height = 5.0
	crown.mesh = sm
	crown.material_override = _mat("leaf")
	crown.position = t + Vector3(0, 9.5, 0)
	add_child(crown)
	# The stand: a small plank platform around the trunk's front, its ladder on the trunk.
	box("G_stand", t + Vector3(0.0, hs - 0.05, 1.15), Vector3(1.6, 0.1, 1.2), "wood")
	_ladder("G_ladder", t + Vector3(0, 0, 2.0), 2, Vector3(0, 0, 1))
	cylinder("G_branch", t + Vector3(-2.75, hs - 0.2, 1.15), 0.2, 4.0, "bark", Vector3(1, 0, 0), {"kind": "branch", "surface": "bark"}, true)


## H: gaps between 1 m platforms: 1.2 m (one-foot gap jump) and 3.0 m (long jump).
func _gaps(o: Vector3) -> void:
	_station("H_gaps", o + Vector3(0, 1.0, 6.0), "gaps 1.2 / 3.0 m", o + Vector3(0, 1.0, -1.0))
	label("H  gaps 1.2 / 3.0 m", o + Vector3(0, 3.0, 5))
	box("H_platform_1", o + Vector3(0, 0.5, 3.0), Vector3(2.0, 1.0, 8.0), "wood")
	box("H_platform_2", o + Vector3(0, 0.5, -3.7), Vector3(2.0, 1.0, 3.0), "wood")
	box("H_platform_3", o + Vector3(0, 0.5, -11.2), Vector3(2.0, 1.0, 6.0), "wood")


## J: a low tunnel (clearance 1.2 m) with a crouch-under volume.
func _tunnel(o: Vector3) -> void:
	_station("J_tunnel", o + Vector3(0, 0, 8.0), "tunnel 1.2 m", o + Vector3(0, 0, 1.5))
	label("J  crouch-under 1.2 m", o + Vector3(0, 2.6, 4))
	box("J_wall_l", o + Vector3(-0.9, 0.6, 0), Vector3(0.3, 1.2, 3.0), "stone")
	box("J_wall_r", o + Vector3(0.9, 0.6, 0), Vector3(0.3, 1.2, 3.0), "stone")
	box("J_roof", o + Vector3(0, 1.3, 0), Vector3(2.1, 0.2, 3.0), "stone")
	var v := TravVolume.new()
	v.name = "J_crouch_volume"
	v.position = o + Vector3(0, 0.6, 0)
	v.size = Vector3(1.5, 1.2, 3.0)
	v.kind = "crouch_under"
	add_child(v)


## K: a narrow ledge (0.35 m) along a 3 m wall, 1 m up, between two 1 m platforms; walked
## sideways to the right with the wall-shimmy clips. The exit clip (p-ledge-idle-r-exit) turns
## right and walks 0.86 m forward past the wall's line, so the wall ends at the ledge's end and
## the far platform reaches behind the wall's line (review 2026-09-24: the exit used to walk
## into the wall, which ran on 0.8 m past the ledge).
func _sidle_ledge(o: Vector3) -> void:
	var hp := authored("mantle_1m_idle", 0.98)
	_station("K_sidle", o + Vector3(-2.2, hp, 1.2), "wall shimmy along a narrow ledge", o + Vector3(-2.2, hp, 0.2))
	label("K  wall shimmy", o + Vector3(0, 3.6, 2))
	box("K_wall", o + Vector3(-0.5, 1.5, -0.4), Vector3(5.0, 3.0, 0.5), "cliff")
	box("K_platform_1", o + Vector3(-2.9, hp * 0.5, 1.0), Vector3(1.4, hp, 2.2), "stone")
	box("K_shelf", o + Vector3(0.0, hp * 0.5, 0.0), Vector3(4.4, hp, 0.35), "stone")
	box("K_platform_2", o + Vector3(2.8, hp * 0.5, 0.25), Vector3(1.6, hp, 3.7), "stone")
	var m := TravLedge.new()
	m.name = "K_narrow_ledge"
	m.position = o + Vector3(0, hp, 0.0)
	# Along the shelf to the character's right while it faces the wall (-Z): +X.
	m.points = PackedVector3Array([Vector3(-2.2, 0, 0), Vector3(2.2, 0, 0)])
	m.outward = Vector3(0, 0, 1)
	m.kind = "narrow"
	m.lip_m = 0.35
	add_child(m)


## L: two rocks with a gap sized from the squeeze clip's own path (hands on the right wall, the
## body's widest point + 8 cm on the left).
func _squeeze(o: Vector3) -> void:
	var lib := TravMoveLibrary.shared()
	var m := lib.move("squeeze")
	var entry := o + Vector3(0, 0, 4.0)
	_station("L_squeeze", o + Vector3(0, 0, 7.5), "squeeze-through", entry)
	label("L  squeeze-through", o + Vector3(0, 3.0, 5))
	if m.is_empty():
		return
	# The clip's overall direction (start -> end) is the gap axis; lateral extents in that frame.
	var ea: Array = m.end_align
	var end := Vector3(float(ea[0]), 0, float(ea[2]))
	var yaw_off := atan2(end.x, end.z)       # clip frame -> axis
	var axis_yaw := PI                        # the gap runs toward -Z
	var clip_yaw := axis_yaw - yaw_off
	var bas := Basis(Vector3.UP, clip_yaw)
	var lat := Vector3.RIGHT                  # world +X = the gap's lateral axis (runner faces -Z)
	var tr: Dictionary = m.track
	var lo := INF
	var hi := -INF
	var zs := []
	for i in int(tr.n):
		var t := i / float(tr.hz)
		if t < 1.5 or t > 6.3:
			continue
		for nm in ["pelvis", "head_top", "l_elbow", "r_elbow", "l_hand", "r_hand"]:
			var arr: Array = tr[nm]
			var p := bas * Vector3(float(arr[3 * i]), float(arr[3 * i + 1]), float(arr[3 * i + 2]))
			lo = minf(lo, p.dot(lat))
			hi = maxf(hi, p.dot(lat))
			zs.append(p.z)
	var z0: float = zs.min()
	var z1: float = zs.max()
	var len := z1 - z0
	var cz := entry.z + 0.5 * (z0 + z1)
	var wl := 1.6
	box("L_rock_left", Vector3(entry.x + lo - 0.03 - wl * 0.5, 1.2, cz), Vector3(wl, 2.4, len), "rock")
	box("L_rock_right", Vector3(entry.x + hi + 0.03 + wl * 0.5, 1.2, cz), Vector3(wl, 2.4, len), "rock")
	var v := TravVolume.new()
	v.name = "L_squeeze_volume"
	v.position = Vector3(entry.x, 1.0, cz)
	v.size = Vector3(hi - lo, 2.0, len)
	v.kind = "squeeze"
	v.axis = Vector3(0, 0, -1)
	add_child(v)
	stations["L_squeeze"]["clip_yaw"] = clip_yaw
	stations["L_squeeze"]["gap"] = hi - lo + 0.06


## M: auto ledge generation from a convex rock hull and a triangle-mesh block.
func _rock_and_mesh(o: Vector3) -> void:
	_station("M_rock", o + Vector3(0, 0, 8), "convex rock + mesh block edges", o + Vector3(0, 0, -2))
	label("M  rock hull / mesh edges", o + Vector3(0, 4.0, 2))
	var pts := PackedVector3Array([
		Vector3(-1.4, 0, -1.2), Vector3(1.5, 0, -1.3), Vector3(1.6, 0, 1.2), Vector3(-1.5, 0, 1.3),
		Vector3(-1.2, 1.3, -1.0), Vector3(1.2, 1.35, -1.0), Vector3(1.25, 1.34, 0.95), Vector3(-1.25, 1.33, 1.0),
		Vector3(0.0, 1.4, 0.0)])
	var rb := _body("M_rock")
	rb.position = o + Vector3(0, 0, -2)
	var cs := CollisionShape3D.new()
	var cv := ConvexPolygonShape3D.new()
	cv.points = pts
	cs.shape = cv
	cs.name = "Shape"
	cs.set_meta("trav", {"ledges": true, "surface": "stone"})
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Dictionary in TravLedgeBaker.hull_faces(pts):
		var a: Vector3 = pts[f.i[0]]
		var b: Vector3 = pts[f.i[1]]
		var c: Vector3 = pts[f.i[2]]
		var n: Vector3 = f.n
		st.set_normal(n)
		if (b - a).cross(c - a).dot(n) > 0.0:
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
		else:
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
	mi.mesh = st.commit()
	mi.material_override = _mat("rock")
	rb.add_child(mi)
	var mb := _body("M_mesh_block")
	mb.position = o + Vector3(-6, 0, -2)
	var mesh := _stepped_mesh()
	var mmi := MeshInstance3D.new()
	mmi.mesh = mesh
	mmi.material_override = _mat("stone")
	mb.add_child(mmi)
	var cs2 := CollisionShape3D.new()
	cs2.shape = mesh.create_trimesh_shape()
	cs2.name = "Shape"
	cs2.set_meta("trav", {"ledges": true, "surface": "stone"})
	mb.add_child(cs2)


func _stepped_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var boxes := [[Vector3(-1.5, 0, -1.5), Vector3(1.5, 2.0, 0.0)], [Vector3(-1.5, 0, 0.0), Vector3(1.5, 1.34, 1.5)]]
	for bx: Array in boxes:
		var lo: Vector3 = bx[0]
		var hi: Vector3 = bx[1]
		var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
				Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
		var quads := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]
		for q: Array in quads:
			var a: Vector3 = c[q[0]]
			var b: Vector3 = c[q[1]]
			var cc: Vector3 = c[q[2]]
			var d: Vector3 = c[q[3]]
			var n := (b - a).cross(cc - a).normalized()
			st.set_normal(-n)
			for v in [a, cc, b, a, d, cc]:
				st.add_vertex(v)
	return st.commit()


# --------------------------------------------------------------------------------------------------
# Bake, spawn, camera
# --------------------------------------------------------------------------------------------------

func bake() -> void:
	baker = TravLedgeBaker.new(registry, TravMoveLibrary.shared().settings)
	ledges = baker.bake(self, get_world_3d().direct_space_state)
	# The squeeze clip's facing (the gap runs along -Z; the clip travels at an angle).
	for id: int in ledges.volumes:
		var v: Dictionary = ledges.volumes[id]
		if str(v.kind) == "squeeze" and stations.has("L_squeeze"):
			v["clip_yaw"] = float(stations.L_squeeze.get("clip_yaw", PI))
			v["entry"] = stations.L_squeeze.obstacle
	_debug_draw(bool(_args.get("ledge_debug", mode == "play")))


func _spawn() -> void:
	runner = TravPreviewRunner.new()
	runner.name = "Runner"
	add_child(runner)
	controller = TraversalController.new()
	controller.name = "TraversalController"
	runner.add_child(controller)
	controller.setup(runner, {"registry": registry, "ledges": ledges})
	actor = TravPreviewActor.new()
	actor.name = "PreviewActor"
	add_child(actor)
	actor.build()
	runner.setup(controller, actor)
	runner.scripted = mode != "play"
	var st: Dictionary = stations.get(str(_args.get("station", "A_vaults")), stations["A_vaults"])
	place_runner(st.start, float(st.yaw))
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.fov = 60.0
	camera.far = 800.0
	add_child(camera)
	camera.current = true
	cam_target = runner.global_position + Vector3.UP * 1.1


## Scripted routes (demo, tests, screenshots). Steps:
##   {station: name}                     place the runner at a station start
##   {at: Vector3, yaw: float}           place the runner
##   {input: {...}, for: seconds}        hold an input (move / sprint / walk / crouched)
##   {tap: "jump" | "crouch"}            one-tick press
##   {until: "OFF" | "CLIMB" | ..., timeout: s}   wait for a controller mode
##   {wait: seconds}
## `on_tick` (Callable(t)) is called every physics tick of the route.
func run_route(steps: Array, on_tick: Callable = Callable()) -> void:
	var t := 0.0
	runner.scripted = true
	for st: Dictionary in steps:
		if st.has("station"):
			var sd: Dictionary = stations[st.station]
			place_runner(sd.start, float(sd.yaw))
			runner.input = {}
			await get_tree().physics_frame
			continue
		if st.has("at"):
			place_runner(st.at, float(st.get("yaw", 0.0)))
			runner.input = {}
			await get_tree().physics_frame
			continue
		if st.has("tap"):
			runner.input[str(st.tap)] = true
			await get_tree().physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			if on_tick.is_valid():
				on_tick.call(t)
			continue
		var dur := float(st.get("for", st.get("wait", st.get("timeout", 0.0))))
		var tap_every := float(st.get("tap_every", 0.0))
		var tap_t := 0.0
		if st.has("input"):
			var inp: Dictionary = (st.input as Dictionary).duplicate()
			inp["yaw"] = runner.yaw
			runner.input = inp
		elif st.has("wait"):
			runner.input = {"yaw": runner.yaw}
		var el := 0.0
		while el < dur:
			if tap_every > 0.0:
				tap_t += 1.0 / Engine.physics_ticks_per_second
				if tap_t >= tap_every:
					tap_t = 0.0
					runner.input["jump"] = true
			await get_tree().physics_frame
			var dt := 1.0 / Engine.physics_ticks_per_second
			el += dt
			t += dt
			if on_tick.is_valid():
				on_tick.call(t)
			if st.has("until") and controller.mode_name() == str(st.until):
				break


func place_runner(p: Vector3, yaw: float) -> void:
	if controller:
		controller.teleported()
	runner.global_position = p + Vector3.UP * 0.05
	runner.velocity = Vector3.ZERO
	runner.yaw = yaw
	if actor:
		# A teleport: the rendered root and pose must not inertialize from the old place.
		actor.teleport(yaw + PI)
	cam_yaw = yaw
	cam_target = p + Vector3.UP * 1.1
	cam_vel = Vector3.ZERO


## Camera: a critically damped spring on the body (capsule) position, so a move's root changes
## never jerk the view; `cam_override` fixes it for screenshots.
func _physics_process(delta: float) -> void:
	if not ready_done or camera == null:
		return
	if not cam_override.is_empty():
		camera.global_position = cam_override.pos
		camera.look_at(cam_override.look, Vector3.UP)
		return
	var focus := runner.global_position + Vector3.UP * 1.1
	var w := 7.0
	var acc := (focus - cam_target) * w * w - cam_vel * 2.0 * w
	cam_vel += acc * delta
	cam_target += cam_vel * delta
	if mode == "play":
		cam_yaw = runner.yaw
	var off := Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch) * Vector3(0, 0, cam_distance)
	camera.global_position = cam_target + off
	camera.look_at(cam_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if mode != "play":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		runner.yaw -= event.relative.x * 0.004
		cam_pitch = clampf(cam_pitch - event.relative.y * 0.003, -1.2, 0.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = maxf(1.5, cam_distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = minf(12.0, cam_distance + 0.3)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_debug_draw(_debug_mesh == null or not _debug_mesh.visible)
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var names := stations.keys()
			var k: int = event.keycode - KEY_1
			if k < names.size():
				var st: Dictionary = stations[names[k]]
				place_runner(st.start, float(st.yaw))


## Debug draw (design 14.5): baked ledges orange (narrow sidle ledges yellow), ladders green,
## beams blue, volumes white.
func _debug_draw(on: bool) -> void:
	if _debug_mesh == null:
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.name = "LedgeDebug"
		_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_debug_mesh)
	_debug_mesh.visible = on
	if not on or ledges == null:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var line := func(a: Vector3, b: Vector3, c: Color) -> void:
		im.surface_set_color(c)
		im.surface_add_vertex(a)
		im.surface_set_color(c)
		im.surface_add_vertex(b)
	for id: int in ledges.ledges:
		var lg: Dictionary = ledges.ledges[id]
		var pts: PackedVector3Array = lg.points
		var col := Color(1.0, 0.9, 0.1) if str(lg.kind) == "narrow" else Color(1.0, 0.55, 0.1)
		for i in range(1, pts.size()):
			line.call(pts[i - 1] + Vector3.UP * 0.02, pts[i] + Vector3.UP * 0.02, col)
			var m := (pts[i - 1] + pts[i]) * 0.5
			line.call(m, m + (lg.normal as Vector3) * 0.2, col)
	for id: int in ledges.lanes:
		var ln: Dictionary = ledges.lanes[id]
		line.call(ln.bottom, ln.top, Color(0.3, 1.0, 0.3))
	for id: int in ledges.beams:
		var bm: Dictionary = ledges.beams[id]
		line.call((bm.a as Vector3) + Vector3.UP * 0.03, (bm.b as Vector3) + Vector3.UP * 0.03, Color(0.3, 0.4, 1.0))
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	_debug_mesh.mesh = im
	_debug_mesh.material_override = mat
