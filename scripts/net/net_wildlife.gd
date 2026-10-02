class_name NetWildlife
extends Node
## The animals in a session (docs/multiplayer_readiness.md, phase P5): the host's are the world's. The host's spawner
## runs them as ever, their senses and LOD over every player (WildlifeSpawner.nearest_player); SEND_HZ times a second
## the host sends the animals within NEAR_M of any other player (where, which way, its clip and speed, dead or not).
## A joiner's spawner has none of its own (WildlifeSpawner.mirror): it shows the host's (WildAnimal.mirrored: the
## species' own body and clips, drawn toward the sent place, its brain off). A shot or blow from the joiner that lands
## on one goes to the host (forward_hit), whose animal takes it from that player: it flees from them, dies by them.
##
## Not yet: a carcass dressed or dragged by a joiner is its own (the meat is not taken off the host's), wild horses caught.
## A child of NetSession ("/root/Net/Wild").

const SEND_HZ := 8.0
const NEAR_M := 260.0
const GONE_S := 4.0               ## a mirrored living animal not heard of this long is taken away
const PULL := 8.0

var net: NetSession
var _t := 0.0
var _serial := 0
var mirrors := {}                 ## the host's animal id -> WildAnimal (a joiner's)
var _want := {}                   ## id -> the last word: [pos, yaw, clip, speed, dead, at]


func _physics_process(delta: float) -> void:
	if net == null or not net.in_session() or net.level == null or not is_instance_valid(net.level):
		return
	if net.is_host():
		_t -= delta
		if _t <= 0.0 and not net.remotes.is_empty():
			_t = 1.0 / SEND_HZ
			_send()
	else:
		_follow(delta)


func _spawner() -> WildlifeSpawner:
	return get_tree().get_first_node_in_group(&"wildlife_spawner") as WildlifeSpawner


# --- The host ------------------------------------------------------------------------------------------------

func _send() -> void:
	var sp := _spawner()
	if sp == null:
		return
	var near: Array[Vector3] = []
	for id: int in net.remotes:
		var r: FrontierPlayer = net.remotes[id]
		if is_instance_valid(r):
			near.append(r.global_position)
	var out := []
	for n in get_tree().get_nodes_in_group(&"wildlife"):
		var a := n as WildAnimal
		if a == null or a.mirrored or not a.is_inside_tree():
			continue
		var close := false
		for q in near:
			if q.distance_squared_to(a.global_position) < NEAR_M * NEAR_M:
				close = true
				break
		if not close:
			continue
		if not a.has_meta(&"net_id"):
			_serial += 1
			a.set_meta(&"net_id", _serial)
		var sp_scale := a._ap.speed_scale if a._ap else 1.0
		out.append([int(a.get_meta(&"net_id")), a.species, a.global_position, a.rotation.y, a._anim, sp_scale, a.is_dead(), a.size])
	_animals.rpc(out)


## A joiner's hit on the host's animal `id`, from that joiner's player (its remote player here is the source).
@rpc("any_peer", "reliable")
func _hit(id: int, d: Dictionary) -> void:
	if not net.is_host():
		return
	var a := _by_id(id)
	if a == null:
		return
	var who: FrontierPlayer = net.remotes.get(multiplayer.get_remote_sender_id())
	var xf := a.global_transform
	a.apply_hit(float(d.get("dmg", 0.0)), xf * (d.get("lp", Vector3.ZERO) as Vector3), xf.basis * (d.get("ld", Vector3.ZERO) as Vector3),
			who if is_instance_valid(who) else null, String(d.get("part", "body")))


func _by_id(id: int) -> WildAnimal:
	for n in get_tree().get_nodes_in_group(&"wildlife"):
		if n.has_meta(&"net_id") and int(n.get_meta(&"net_id")) == id:
			return n as WildAnimal
	return null


# --- A joiner ------------------------------------------------------------------------------------------------

@rpc("authority", "unreliable_ordered")
func _animals(list: Array) -> void:
	var sp := _spawner()
	if sp == null or not sp.mirror:
		return
	var now := Time.get_ticks_msec()
	for e: Array in list:
		var id := int(e[0])
		_want[id] = [e[2], float(e[3]), String(e[4]), float(e[5]), bool(e[6]), now]
		if not mirrors.has(id) or not is_instance_valid(mirrors[id]):
			mirrors[id] = _make(sp, id, String(e[1]), float(e[7]), e[2], float(e[3]))


func _make(sp: WildlifeSpawner, id: int, species: String, size: float, at: Vector3, yaw: float) -> WildAnimal:
	var a := WildlifeSpecies.make(species)
	a.name = "Net_%s_%d" % [species.capitalize(), id]
	a.setup(species, sp, null, id)
	a.set_size(size)
	a.mirrored = true
	a.set_meta(&"net_id", id)
	sp.add_child(a)
	a.global_position = at
	a.rotation.y = yaw
	return a


func _follow(delta: float) -> void:
	var now := Time.get_ticks_msec()
	for id: int in mirrors.keys():
		var a: WildAnimal = mirrors[id]
		var w: Array = _want.get(id, [])
		if not is_instance_valid(a) or w.is_empty():
			mirrors.erase(id)
			continue
		var age := float(now - int(w[5])) / 1000.0
		if age > GONE_S and not a.is_dead():
			a.queue_free()
			mirrors.erase(id)
			_want.erase(id)
			continue
		if bool(w[4]):
			if not a.is_dead():
				a._die("", true)
			continue
		var to: Vector3 = w[0]
		var off := to - a.global_position
		a.global_position = to if off.length() > 6.0 else a.global_position + off * clampf(PULL * delta, 0.0, 1.0)
		a.rotation.y = lerp_angle(a.rotation.y, float(w[1]), clampf(PULL * delta, 0.0, 1.0))
		var clip := String(w[2])
		if clip != "" and a._ap and a._ap.has_animation(clip):
			a._play(clip, 0.3, float(w[3]))


## A hit here on a mirrored animal (WildAnimal.apply_hit): this machine's player's own shots and blows go to the host,
## in the animal's frame; anything else does nothing to it.
static func forward_hit(a: WildAnimal, damage: float, point: Vector3, direction: Vector3, source: Node, part: String) -> void:
	var n := NetSession.find(a.get_tree())
	if n == null or n.wild == null or not n.in_session() or not n._from_me(source) or damage <= 0.0:
		return
	var inv := a.global_transform.affine_inverse()
	n.wild._hit.rpc_id(1, int(a.get_meta(&"net_id", 0)), {"dmg": damage, "lp": inv * point, "ld": inv.basis * direction, "part": part})
