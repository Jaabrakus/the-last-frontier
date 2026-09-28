class_name LogPile
extends StaticBody3D
## A bundle of logs laid down where a horse dragged it (HorseHaul.unhitch): the logs lie as they were chained,
## and E takes them into the pack ("Take 6 logs"; PlayerInteractor's "any other interactable" contract). Low
## enough for a horse to step over (FrontierVegetation.LOW_GROUP). Not saved.

var count := 0
var log_length := 2.4
var log_radius := 0.15
var species := "white_pine"
var interact_reach := 2.6
var _model: Node3D


## The pile a bundle (`s`, a SkidLoad with bundle > 0) leaves where it lies.
static func from_load(s: SkidLoad) -> LogPile:
	var p := LogPile.new()
	p.name = "LogPile"
	p.count = s.bundle
	p.log_length = s.length
	p.log_radius = s.r_front
	p.species = String(s.info.get("species", "white_pine"))
	p.transform = Transform3D(SkidLoad._basis_for(s.axis()), s.front)
	p._build(DisplayServer.get_name() != "headless")
	return p


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)
	add_to_group(FrontierVegetation.LOW_GROUP)
	set_meta(&"surface", "wood")


func _build(visuals: bool) -> void:
	var offs := SkidLoad.pile_offsets(count, log_radius)
	var w := 0.0
	var h := 0.0
	for o in offs:
		w = maxf(w, absf(o.x))
		h = maxf(h, o.y)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0 * (w + log_radius), log_length, h + 2.0 * log_radius)
	cs.shape = box
	cs.position = Vector3(0.0, log_length * 0.5, h * 0.5)
	add_child(cs)
	if not visuals:
		return
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	for o in offs:
		SkidLoad.log_model(_model, log_radius, log_radius, log_length, species, Vector3(o.x, 0.0, o.y))


## The middle of the pile's top.
func interact_point() -> Vector3:
	return global_transform * Vector3(0.0, log_length * 0.5, log_radius)


func distance_from(p: Vector3) -> float:
	var a := global_position
	var b := global_transform * Vector3(0.0, log_length, 0.0)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	var q := a + ab * t
	return maxf(Vector2(q.x - p.x, q.z - p.z).length() - log_radius * 2.0, 0.0)


func interact_prompt(p: Node) -> String:
	if count <= 0 or p == null or p.get("riding") != null or (p.get("is_dead") == true):
		return ""
	return "Take %d log%s" % [count, "" if count == 1 else "s"]


func highlight_targets() -> Array:
	return _model.find_children("*", "GeometryInstance3D", true, false) if _model else []


## The logs go into the pack (GatherTools.give: the pack and the notice) and the pile goes.
func interact(p: Node) -> bool:
	if count <= 0 or p == null:
		return false
	var g: Variant = p.get("gather")
	if g is GatherTools:
		(g as GatherTools).give("log", count)
	else:
		var inv := InventoryState.from_player(p)
		inv.add("log", count)
		p.set("inventory_pack", inv.pack.duplicate(true))
	count = 0
	queue_free()
	return true
