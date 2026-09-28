class_name HorseMount
extends Node
## Makes a Horse rideable by the player (user 2026-09-25: "add in the horse"): the horse joins the E
## interaction (PlayerInteractor: it glows and the prompt says "E  Mount horse"), E mounts it
## (FrontierPlayer.mount()) and E again, from the saddle, dismounts. While ridden the horse reads the riding
## input itself (Horse.player_input: W / S throttle and brake, A / D steer, Shift spurs, Alt walks, Space jumps)
## and HorseRiderLink seats the player's own rig on the saddle, playing the Actor_B riding clips at the horse's
## phase with the feet in the stirrups and the hands on the reins.
## The horse is the project's procedural model (tools/horse).
## attach_to() also gives the horse its lead (HorseLead: E at its head) and its hitch (HorseHaul: log skidding).

const GROUP := &"interactables"

var horse: Horse
var interact_reach := 2.6
var rider: Node = null


static func attach_to(h: Horse) -> HorseMount:
	var m := HorseMount.new()
	m.name = "Mount"
	m.horse = h
	h.add_child(m)
	# on foot: E at its head leads it (HorseLead); a load on a chain behind it (HorseHaul)
	HorseLead.attach_to(h)
	HorseHaul.attach_to(h)
	return m


func _ready() -> void:
	add_to_group(GROUP)


func interact_prompt(p: Node) -> String:
	if rider != null or p == null or p.get("riding") != null or bool(p.get("is_dead")):
		return ""
	return "Mount horse"


func interact_point() -> Vector3:
	return horse.get_saddle_transform().origin


func distance_from(point: Vector3) -> float:
	var a := horse.get_mount_point(Horse.LEFT).origin
	var b := horse.get_mount_point(Horse.RIGHT).origin
	var s := horse.get_saddle_transform().origin
	return minf(minf(point.distance_to(a + Vector3.UP), point.distance_to(b + Vector3.UP)), point.distance_to(s))


func highlight_targets() -> Array:
	return horse.visual.find_children("*", "GeometryInstance3D", true, false) if horse.visual else []


func interact(p: Node) -> bool:
	if p == null or not p.has_method("mount") or rider != null:
		return false
	return p.mount(horse)


## The demo's horse, saddled and standing near the player's spawn, unless the level has one.
static func ensure_demo_horse(p: Node3D) -> void:
	var scene := p.get_tree().current_scene
	if scene == null:
		return
	for n in scene.find_children("*", "Horse", true, false):
		return
	var h := Horse.new()
	h.name = "Horse"
	scene.add_child(h)
	var fwd := -p.global_transform.basis.z
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var at := p.global_position - right * 4.5 + fwd * 5.0
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at.y = (hit.position as Vector3).y
	h.global_position = at
	h.rotation.y = p.rotation.y + PI * 0.5
	attach_to(h)
