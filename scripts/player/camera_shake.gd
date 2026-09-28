class_name CameraShake
extends Node
## A shake of the view (user 2026-09-27: "if the mammoth kneels i want the screen to shake for the players within the
## area"). quake() shakes the view of every player within `radius` of a place: in full within a third of it, fading to
## nothing at its edge. The shake is the camera's own screen offsets (h_offset, v_offset): the view jolts, the camera
## does not turn and the aim does not move. A trauma (0..1) that runs down over the shake's seconds, the jolt its square
## (hard at the start, settling), from smooth noise. One CameraShake under a player's camera, made when first needed.

const MAX_OFFSET := 0.22         ## m of screen offset at full trauma
const FREQ := 14.0               ## how fast it jolts (noise per second)

var camera: Camera3D
var trauma := 0.0
var _fall := 1.0
var _t := 0.0
var _noise := FastNoiseLite.new()


## Shakes the view of each player within `radius` m of `at`, `strength` (0..1) close by, over `secs` seconds.
static func quake(tree: SceneTree, at: Vector3, strength: float, radius: float, secs := 1.0) -> void:
	for n in tree.get_nodes_in_group(&"player"):
		var p := n as Node3D
		if p == null:
			continue
		var cam := p.get("camera") as Camera3D
		var d := p.global_position.distance_to(at)
		if cam == null or d >= radius:
			continue
		of(cam).add(strength * (1.0 - smoothstep(radius / 3.0, radius, d)), secs)


## The shake of `cam` (made on first use).
static func of(cam: Camera3D) -> CameraShake:
	var s := cam.get_node_or_null(^"CameraShake") as CameraShake
	if s == null:
		s = CameraShake.new()
		s.name = "CameraShake"
		s.camera = cam
		cam.add_child(s)
	return s


## A jolt of `amount` (0..1; the stronger of it and what is left of the last), running down over `secs`.
func add(amount: float, secs: float) -> void:
	if amount <= trauma:
		return
	trauma = clampf(amount, 0.0, 1.0)
	_fall = trauma / maxf(secs, 0.05)


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()


func _process(dt: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if trauma <= 0.0:
		if camera.h_offset != 0.0 or camera.v_offset != 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
		return
	_t += dt
	trauma = maxf(trauma - _fall * dt, 0.0)
	var a := trauma * trauma * MAX_OFFSET
	camera.h_offset = a * _noise.get_noise_2d(_t * FREQ, 0.0) * 1.4
	camera.v_offset = a * _noise.get_noise_2d(0.0, 50.0 + _t * FREQ) * 1.4
