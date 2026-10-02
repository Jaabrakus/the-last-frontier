class_name Owl
extends Node3D
## A great horned owl at night (user 2026-09-26: "add in fireflys and Owls"; "as long as it has yellow eyes and then
## disappear to spook the char"). The model: "Great horned owl" by Poly by Google, CC-BY 3.0
## (assets/wildlife/polypizza/SOURCE.md, CREDITS.md), split at load into the bird and its branch. The branch sticks out
## from a real trunk of the level (BirdLife picks the perch); the owl sits on it, turns to watch the player, and its
## yellow eyes catch the light in the dark (eyeshine: small emissive eyes, brighter the darker it is). It hoots now and
## then (the recorded great horned owl, BirdLife.call_from). When the player comes close, fires near by, or stares at it
## too long, it is suddenly gone: no flight, no sound, only the bare branch left. It turns up again later on another
## tree (BirdLife), and sometimes hoots from somewhere behind the player first.

enum Mode { PERCH, GONE }

const MODEL := "res://assets/wildlife/smooth/great_horned_owl.glb"
const SCALE := 0.06                    ## model units to metres: the owl ~0.43 m tall on a 0.6 m branch
const BRANCH_Y := 2.3                  ## model units: the branch below, the bird above
const EYES := [Vector3(-0.44, 7.9, 2.62), Vector3(0.44, 7.9, 2.62)]    ## model units (the texture's yellow eyes)
const SHY_M := 12.0
const STARE_DEG := 5.0
const STARE_S := 1.4
const GONE_S := Vector2(25.0, 70.0)
const CALLS := {"horned": &"bird_rec_great_horned_owl", "barred": &"bird_rec_barred_owl"}

static var _parts := {}                ## {bird: ArrayMesh, branch: ArrayMesh, mat: Material}

var kind := "horned"
var life: BirdLife
var mode := Mode.PERCH
var rng := RandomNumberGenerator.new()
var perch := Vector3.ZERO
var trunk := Vector3.ZERO
var call_in := 20.0
var gone_until := 0.0

var _bird: Node3D
var _branch: MeshInstance3D
var _eye_mat: StandardMaterial3D
var _stare := 0.0
var _t := 0.0


func setup(p_life: BirdLife, _kind: String, at: Vector3, seed_: int, p_trunk := Vector3.INF) -> void:
	life = p_life
	perch = at
	trunk = p_trunk if p_trunk != Vector3.INF else at + Vector3(0.5, 0.0, 0.0)
	rng.seed = seed_
	call_in = rng.randf_range(6.0, 40.0)


func _ready() -> void:
	add_to_group(&"owls")
	_build()
	_place(perch, trunk)


static func _split() -> Dictionary:
	if not _parts.is_empty():
		return _parts
	var root := (load(MODEL) as PackedScene).instantiate()
	var mi := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
	var bird := PackedInt32Array()
	var branch := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var cy := (v[idx[t]].y + v[idx[t + 1]].y + v[idx[t + 2]].y) / 3.0
		var tgt := branch if cy < BRANCH_Y else bird
		tgt.append_array([idx[t], idx[t + 1], idx[t + 2]])
	var mat := mi.get_active_material(0)
	for part: Array in [["bird", bird], ["branch", branch]]:
		var a := arr.duplicate()
		a[Mesh.ARRAY_INDEX] = part[1]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(0, mat)
		_parts[part[0]] = m
	root.free()
	return _parts


func _build() -> void:
	var parts := _split()
	_branch = MeshInstance3D.new()
	_branch.name = "Branch"
	_branch.mesh = parts.branch
	_branch.scale = Vector3.ONE * SCALE
	add_child(_branch)
	_bird = Node3D.new()
	_bird.name = "Bird"
	add_child(_bird)
	var body := MeshInstance3D.new()
	body.mesh = parts.bird
	body.scale = Vector3.ONE * SCALE
	_bird.add_child(body)
	# eyeshine: two small yellow eyes over the texture's, lit from within as it gets dark
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(1.0, 0.82, 0.18)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(1.0, 0.78, 0.15)
	_eye_mat.emission_energy_multiplier = 0.0
	_eye_mat.roughness = 0.2
	for e: Vector3 in EYES:
		var eye := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.016
		s.height = 0.032
		s.radial_segments = 10
		s.rings = 5
		eye.mesh = s
		eye.material_override = _eye_mat
		eye.position = e * SCALE
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bird.add_child(eye)


## On a new perch: the branch points out from the trunk, the owl sits on it.
func _place(at: Vector3, from_trunk: Vector3) -> void:
	perch = at
	trunk = from_trunk
	global_position = at - Vector3.UP * (BRANCH_Y * SCALE * 0.95)
	var out := Vector3(at.x - from_trunk.x, 0.0, at.z - from_trunk.z)
	if out.length_squared() > 1e-4:
		# the model's branch runs along its x axis
		_branch.rotation.y = atan2(-out.z, out.x)
		_branch.position = Vector3.ZERO


func _process(dt: float) -> void:
	_t += dt
	match mode:
		Mode.PERCH:
			_perched(dt)
		Mode.GONE:
			pass


func _perched(dt: float) -> void:
	# eyeshine: brighter the darker it is
	var el := life.sun_elevation() if life else -12.0
	_eye_mat.emission_energy_multiplier = lerpf(0.0, 3.2, clampf((2.0 - el) / 12.0, 0.0, 1.0))
	var p := life.player if life else null
	if p == null or not is_instance_valid(p):
		return
	var to := p.global_position - global_position
	var d := to.length()
	# the owl turns (the model faces +Z) to watch the player
	if d < 40.0:
		var want := atan2(to.x, to.z)
		_bird.rotation.y = lerp_angle(_bird.rotation.y, want, clampf(dt * 1.2, 0.0, 1.0))
	# stared at: the camera's aim on it for a while
	var cam := p.get_viewport().get_camera_3d() if p.get_viewport() else null
	if cam and d < 60.0:
		var look := -cam.global_basis.z
		var at := (global_position + Vector3.UP * 0.3 - cam.global_position).normalized()
		_stare = _stare + dt if rad_to_deg(look.angle_to(at)) < STARE_DEG else maxf(_stare - dt * 2.0, 0.0)
	if d < SHY_M or _stare > STARE_S or (life and life.shot_near(global_position, 45.0)):
		vanish()
		return
	call_in -= dt
	if call_in <= 0.0:
		call_in = rng.randf_range(25.0, 70.0)
		if life:
			life.call_from(self)


## Gone: no flight, no sound; the bare branch stays. BirdLife brings it back elsewhere after GONE_S.
func vanish() -> void:
	if mode == Mode.GONE:
		return
	mode = Mode.GONE
	_stare = 0.0
	_bird.visible = false
	gone_until = (life.now if life else 0.0) + rng.randf_range(GONE_S.x, GONE_S.y)
	if life:
		life.owl_vanished(self)


## Back on another tree.
func reappear(at: Vector3, from_trunk: Vector3) -> void:
	_place(at, from_trunk)
	mode = Mode.PERCH
	_bird.visible = true
	call_in = rng.randf_range(8.0, 30.0)


## A call: the owl leans into it (BirdLife plays the recording).
func hoot() -> void:
	var tw := create_tween()
	tw.tween_property(_bird, "rotation:x", 0.18, 0.3)
	tw.tween_property(_bird, "rotation:x", 0.0, 0.5)
