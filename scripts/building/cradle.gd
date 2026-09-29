class_name Cradle
extends Node3D
## A cradle (the build piece "cradle", Furniture): a small wooden rocking cradle where the baby is laid to sleep (BabyLink). E with
## the baby in arms lays it in; E with the baby in the cradle takes it up. The baby rides `mount()`; the mount rocks a little while
## the baby cries (data/companion/baby.json "cradle": baby_pos, stand_m, rock_deg, rock_hz).

const GROUP := &"cradles"

var interact_reach := 2.4
var _mount: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	mount()


static func cfg() -> Dictionary:
	return BabyCare.cfg().get("cradle", {})


## Where the baby lies (a Node3D in the piece's frame).
func mount() -> Node3D:
	if _mount == null or not is_instance_valid(_mount):
		_mount = get_node_or_null("BabyMount") as Node3D
	if _mount == null:
		_mount = Node3D.new()
		_mount.name = "BabyMount"
		var a: Variant = cfg().get("baby_pos", [0.0, 0.3, 0.0])
		_mount.position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		add_child(_mount)
	return _mount


## The baby's place in the world.
func baby_point() -> Vector3:
	return mount().global_position


func _process(dt: float) -> void:
	_t += dt
	var m := mount()
	var rock := 0.0
	for c in m.get_children():
		if c is BabyModel and String((c as BabyModel).get("_mood")) in ["crying", "wailing", "fretful"]:
			rock = 1.0
	var deg := float(cfg().get("rock_deg", 6.0)) * rock
	m.rotation.z = lerpf(m.rotation.z, deg_to_rad(sin(_t * TAU * float(cfg().get("rock_hz", 0.6))) * deg), clampf(dt * 6.0, 0.0, 1.0))


func _link() -> BabyLink:
	return BabyLink.find(get_tree())


func interact_point() -> Vector3:
	return global_position + Vector3(0.0, 0.4, 0.0)


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func interact_prompt(_p: Node) -> String:
	var l := _link()
	return l.cradle_prompt(self) if l != null else ""


func interact(_p: Node) -> void:
	var l := _link()
	if l != null:
		var t := l.cradle_action(self)
		if t != "":
			l._say(t)
