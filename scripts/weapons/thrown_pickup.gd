class_name ThrownPickup
extends Node3D
## A thrown spear, tomahawk or dart that has come to rest (stuck in something or
## lying on the ground). It goes back to the player's Throwable of the same `kind`,
## if that one has room (max_count), in either of two ways:
##
##   walk over it   the player's chest (0.9 m above the feet) comes within `radius` of
##                  the nearest point along the weapon (tip to butt)
##   press E        the "interact" action, within the longer `interact_radius`: a spear
##                  stuck high in a tree or a target. E is also the horse's mount key
##                  (HorseInput); the action is registered at runtime the same way when
##                  the project does not define it (ensure_input), input_setup.gd is not
##                  changed.
##
## With `require_interact` only the key works. Child of the ThrownProjectile it belongs
## to; picking it up frees that node. All pickups are in the "thrown_pickups" group;
## nearest_for(player) finds the one a HUD prompt would name (prompt()).

signal picked_up(by: Node)

const INTERACT := &"interact"
const INTERACT_KEY := KEY_E
const GROUP := &"thrown_pickups"

var kind := "spear"
## ThrowableModels kind of the item ("tomahawk_pipe" vs "tomahawk"): it goes back to the
## weapon that throws that model when there is one with room.
var model_kind := ""
var amount := 1
var item: Node3D
## Walk-over distance from the player's chest.
var radius := 1.5
## Distance from the chest within which the interact key picks it up.
var interact_radius := 2.5
var require_interact := false
## Seconds after coming to rest before it can be picked up (a point-blank throw is not
## returned the same instant).
var arm_delay := 0.5

var _poll := 0.0
var _key_latch := 0.0               ## A tap of the key is remembered until the next poll.
var _taken := false                 ## Given once; the node is freed at the end of the frame.


## Registers the "interact" action (E) unless the project or HorseInput already has it.
static func ensure_input() -> void:
	if InputMap.has_action(INTERACT):
		return
	InputMap.add_action(INTERACT)
	var e := InputEventKey.new()
	e.physical_keycode = INTERACT_KEY
	InputMap.action_add_event(INTERACT, e)


func _ready() -> void:
	ensure_input()
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	arm_delay -= delta
	_poll -= delta
	_key_latch -= delta
	if Input.is_action_just_pressed(INTERACT):
		_key_latch = 0.25
	if arm_delay > 0.0 or _poll > 0.0:
		return
	_poll = 0.1
	var key := _key_latch > 0.0 or Input.is_action_pressed(INTERACT)
	for n in get_tree().get_nodes_in_group(&"player"):
		var p := n as Node3D
		if p == null:
			continue
		# a player with the interaction (PlayerInteractor) picks up with E on the highlighted item only
		# (user 2026-09-25: no walk-over pickup; "we need a item to highlight and we press e")
		if p.get(&"interactor") != null:
			continue
		var d := distance_from(_chest(p))
		var walk := not require_interact and d <= radius
		var keyed := key and d <= interact_radius
		if (walk or keyed) and try_give(p):
			_key_latch = 0.0
			return


## True once the arm delay has passed.
func is_armed() -> bool:
	return arm_delay <= 0.0


## Distance from `point` to the item: to the nearest point along a thrown weapon
## (tip to butt), so a long spear stuck high in a target is still in reach.
func distance_from(point: Vector3) -> float:
	var proj := item as ThrownProjectile
	if proj == null:
		return point.distance_to(global_position)
	var a := proj.tip_position()
	var b := proj.tail_position()
	var ab := b - a
	var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return point.distance_to(a + ab * t)


## Hands the item to `p`'s Throwable of this kind. True when it was taken. Only once: a
## second call in the same frame (the pickup's own poll and, say, a HUD or player "E"
## handler) gives nothing.
func try_give(p: Node) -> bool:
	if _taken:
		return false
	var w := find_taker(p, kind, model_kind)
	if w == null:
		return false
	var took := w.add_items(amount)
	if took <= 0:
		return false
	_taken = true
	w.sfx.emit(&"pickup", global_position)
	picked_up.emit(p)
	var node := item if item else self
	if node is ThrownProjectile:
		(node as ThrownProjectile).collected = true
	remove_from_group(GROUP)
	node.queue_free()
	return true


## HUD prompt for this pickup, e.g. "E  pick up Throwing Spear" ("" when `p` cannot take it).
func prompt(p: Node) -> String:
	var w := find_taker(p, kind, model_kind)
	if w == null:
		return ""
	return "%s  pick up %s" % [OS.get_keycode_string(INTERACT_KEY), w.display_name]


## The armed pickup nearest to `p`'s chest within its `interact_radius` that `p` can
## take, or null. For a HUD prompt.
static func nearest_for(p: Node3D) -> ThrownPickup:
	if p == null or not p.is_inside_tree():
		return null
	var best: ThrownPickup = null
	var best_d := INF
	var chest := _chest(p)
	for n in p.get_tree().get_nodes_in_group(GROUP):
		var pk := n as ThrownPickup
		if pk == null or pk._taken or pk.is_queued_for_deletion() or not pk.is_armed():
			continue
		var d := pk.distance_from(chest)
		if d <= pk.interact_radius and d < best_d and find_taker(p, pk.kind) != null:
			best = pk
			best_d = d
	return best


static func _chest(p: Node3D) -> Vector3:
	return p.global_position + Vector3.UP * 0.9


## The Throwable of `p_kind` that belongs to `p` and has room: the player's weapons
## first, then any registered in the "throwables" group whose player is `p`. One that
## throws `p_model` is preferred (a pipe tomahawk goes back to the pipe tomahawk).
static func find_taker(p: Node, p_kind: String, p_model := "") -> Throwable:
	var candidates: Array = []
	if p is FrontierPlayer:
		candidates.append_array((p as FrontierPlayer).weapons.values())
	if p.is_inside_tree():
		candidates.append_array(p.get_tree().get_nodes_in_group(&"throwables"))
	var any: Throwable = null
	for c in candidates:
		var w := c as Throwable
		if w == null or w.player != p or not w.can_take(p_kind):
			continue
		if p_model == "" or w.projectile_kind == p_model:
			return w
		if any == null:
			any = w
	return any
