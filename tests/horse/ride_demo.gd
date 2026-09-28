extends Node3D
## Interactive horse prototype: Actor_B rides the procedural horse on a flat field.
##
##   Godot --path . tests/horse/ride_demo.tscn
##
## W / S       throttle / brake (W cruises at the current cruise gait)
## A / D       steer (at a stand: turn in place)
## Shift       tap: spur one gait up (walk > trot > canter > gallop); hold at gallop: sprint
## Alt         hold: walk
## Space       jump (canter or faster) / rear (standing)
## Mouse wheel camera distance, Esc quit
##
## The rider is a stopgap HorseRiderLink (no PlayerAnim ride mode yet): riding clips at
## the horse's phase, reins to the palms, stirrups following the feet.

const Rig := preload("res://tests/horse/horse_test_rig.gd")

var horse: Horse
var link: HorseRiderLink
var cam: Camera3D
var hud: Label
var dist := 4.6
var _cam_pos := Vector3.ZERO
var _pivot_y := 2.2


func _ready() -> void:
	HorseInput.ensure()
	_world()
	horse = Horse.new()
	horse.name = "Horse"
	horse.player_input = true
	add_child(horse)
	var rider := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	add_child(rider)
	var sk := rider.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := rider.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	CharacterBodyMesh.attach(sk, ap)
	link = HorseRiderLink.new()
	horse.add_child(link)
	link.attach(horse, rider, ap)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 800.0
	add_child(cam)
	cam.current = true
	_cam_pos = horse.global_position + Vector3(0, 3.0, 6.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(hud)


func _world() -> void:
	Rig.studio(self, 600.0, false)
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(600, 1, 600)
	gs.shape = gb
	gs.position = Vector3(0, -0.5, 0)
	ground.add_child(gs)
	add_child(ground)
	# posts every 10 m to read the speed
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 160:
		var p := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.08
		cm.height = rng.randf_range(0.8, 1.6)
		p.mesh = cm
		p.position = Vector3(rng.randf_range(-150, 150), cm.height * 0.5, rng.randf_range(-150, 150))
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.42, 0.33, 0.24)
		p.material_override = pmat
		add_child(p)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(3.0, dist - 0.4)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(14.0, dist + 0.4)
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		get_tree().quit()


func _process(delta: float) -> void:
	# centred chase camera behind the horse; the pivot follows the root, not the saddle,
	# so it does not bob with the gait (horse.md 3.5)
	var fwd := -horse.global_basis.z
	_pivot_y = lerpf(_pivot_y, horse.global_position.y + 2.2, 1.0 - exp(-delta / 0.15))
	var pivot := Vector3(horse.global_position.x, _pivot_y, horse.global_position.z)
	var want := pivot - fwd * dist + Vector3.UP * dist * 0.22
	_cam_pos += horse.velocity * delta          # keep pace, then ease towards the target
	_cam_pos = _cam_pos.lerp(want, 1.0 - exp(-delta * 6.0))
	cam.global_position = _cam_pos
	cam.look_at(pivot + fwd * 1.5)
	hud.text = "gait %s   speed %.1f m/s   cruise %s   clip %s  phase %.2f  rate %.2f\n" % [
		Horse.GAIT_CLIPS[horse.gait], horse.speed, Horse.GAIT_CLIPS[horse.cruise_gait], horse.clip, horse.phase,
		horse.rate] + "W/S throttle  A/D steer  Shift spur (hold: sprint)  Alt walk  Space jump / rear  wheel zoom  Esc quit"
