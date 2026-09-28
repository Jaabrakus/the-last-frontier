class_name HorseHaul
extends Node
## Log skidding behind a horse (user 2026-09-26: "we need a wagon or a AI where we can get the horse to pull a
## chopped tree"). The period's way first: where there is no road for a cart and no snow for a sled, a horse
## drags ("skids") the timber out of the woods on a chain. Every rideable horse has one (HorseMount.attach_to).
## Numbers: data/horse/haul.json (design values).
##
## E (PlayerInteractor's "any other interactable" contract; in the saddle through saddle_prompt(), a tap):
##   at a felled tree's butt, the horse's hitch within hitch_reach_m (lead it there, or ride up and stop
##   with its hindquarters by the butt: hitch_reach_saddle_m)
##       "Hitch the white pine to the horse": the tree is limbed and topped (its crown's firewood and branches
##       go into the pack) and what is left of its clear bole (after any logs bucked off it) is chained by
##       the butt: a SkidLoad
##   at either end of a bole lying loose            the same
##   at the horse's hitch, logs in the pack        "Hitch 6 logs from the pack": a bundle (up to bundle_max)
##   at a dead animal's neck (a deer, a buck, a wolf, a fox: WildAnimal), the hitch within reach
##       "Hitch the deer to the horse": a rope round its neck, dragged head first (CarcassLoad; user 2026-09-26:
##       "lets add the ability to haul animal carcasses as well"); let go, it lies there to be skinned
##   at the load, or in the saddle with the horse stopped
##       "Unhitch the white pine": the bole lies where it stopped (the axe bucks it into logs as before); a
##       bundle is laid down as a LogPile (E takes the logs back); a carcass lies where it stopped
## A load the horse cannot start (its weight x mu_axial over pull_max_frac x the horse's weight) is refused
## with the reason ("Too heavy for one horse (about 1,900 kg): buck logs off it").
##
## The pull (SkidLoad.pull_kgf: friction and slope) caps the horse (Horse.haul_speed_cap): up to
## pull_easy_frac of its weight it may trot, to pull_walk_frac it walks, then slows to a crawl at
## pull_max_frac; past stall_frac (a heavy log up a steep slope) it stops. A load caught on a tree (the chain
## drawn jam_stretch_m past its length) stops the horse; turning it frees the load, and after jam_free_after_s
## the load is worked free. It pulls the same ridden or led on foot (HorseLead).
##
## The harness, drawn while a load is on: a breast strap, two leather traces along the flanks to a singletree
## behind the hocks, and the chain from the singletree's hook to the choker round the load (for a carcass a rope
## to the collar round its neck). Project-made.

const DATA_PATH := "res://data/horse/haul.json"

static var _data := {}
static var _mats := {}

var horse: Horse
## A cart the horse is in the shafts of (HorseCart), or null: it sets the pace as a load does, and nothing is chained
## on while it is.
var cart: HorseCart = null
## The load on the chain, or null.
var load: SkidLoad = null
var interact_reach := 2.6
## The last pull cap given to the horse (m/s; tests).
var cap := INF
## Seconds the load has been caught.
var jam_t := 0.0

var _offer := {}
var _pack_offer := {}
var _saddle_offer := {}
var _pack_spot: PackSpot
var _mi: MeshInstance3D
var _mesh: ImmediateMesh
var _singletree: MeshInstance3D
var _label_text := ""
var _stalled := false


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = d if d is Dictionary else {}
	return _data


static func attach_to(h: Horse) -> HorseHaul:
	var hh := HorseHaul.new()
	hh.name = "Haul"
	hh.horse = h
	h.add_child(hh)
	return hh


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)
	process_physics_priority = 5            # after the horse has moved, before the load
	_pack_spot = PackSpot.new()
	_pack_spot.name = "PackSpot"
	_pack_spot.haul = self
	add_child(_pack_spot)
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.name = "Harness"
	_mi.mesh = _mesh
	_mi.top_level = true
	_mi.visible = false
	add_child(_mi)
	var bar := CylinderMesh.new()
	bar.top_radius = 0.032
	bar.bottom_radius = 0.036
	bar.height = 0.66
	bar.radial_segments = 8
	_singletree = MeshInstance3D.new()
	_singletree.name = "Singletree"
	_singletree.mesh = bar
	_singletree.material_override = _mat("wood", Color(0.42, 0.31, 0.2), 0.0, 0.75)
	_singletree.top_level = true
	_singletree.visible = false
	add_child(_singletree)


## The chain's hook (global).
func hitch_point() -> Vector3:
	return horse.get_hitch_point()


## What pulls the load (SkidLoad: not ground under it) and how fast it goes (m/s).
func puller() -> CollisionObject3D:
	return horse


func puller_speed() -> float:
	return absf(horse.speed)


## Whether E at `n` (a dead animal or a felled tree) is the horse's now (FootDrag then leaves it to the horse).
func offers(n: Node) -> bool:
	return n != null and (_offer.get("animal") == n or _offer.get("ft") == n)


## Whether the horse offers anything on foot now (hitch, unhitch, the pack's logs): LogPull then does not push in.
func offering() -> bool:
	return not _offer.is_empty() or not _pack_offer.is_empty()


func _physics_process(delta: float) -> void:
	if horse == null:
		return
	if load != null and not is_instance_valid(load):
		load = null
	_update_cap(delta)
	_offer = _find_offer(false)
	_saddle_offer = _find_offer(true)
	_pack_offer = _find_pack_offer()
	_draw_harness()
	_refresh_label()


# --- The pull ------------------------------------------------------------------------------------------

## Speed cap (m/s) for a pull of `frac` x the horse's weight (haul.json).
static func cap_for_pull(frac: float) -> float:
	var d := data()
	var easy := float(d.get("pull_easy_frac", 0.2))
	var walk := float(d.get("pull_walk_frac", 0.5))
	var mx := float(d.get("pull_max_frac", 1.5))
	var trot := float(d.get("cap_trot_mps", 3.2))
	var walk_v := float(d.get("cap_walk_mps", 1.45))
	var crawl := float(d.get("cap_crawl_mps", 0.4))
	if frac <= easy:
		return trot
	if frac <= walk:
		return lerpf(trot, walk_v, (frac - easy) / (walk - easy))
	if frac <= mx:
		return lerpf(walk_v, crawl, (frac - walk) / (mx - walk))
	if frac <= float(d.get("stall_frac", 1.65)):
		return crawl
	return 0.0


## Can one horse start a load of `kg` on the level?
static func can_start(kg: float) -> bool:
	var d := data()
	return kg * float(d.get("mu_axial", 0.4)) <= float(d.get("pull_max_frac", 1.5)) * float(d.get("horse_kg", 430.0))


func _update_cap(delta: float) -> void:
	if cart != null and not is_instance_valid(cart):
		cart = null
	if load == null and cart != null:
		_cart_cap()
		return
	if load == null:
		cap = INF
		jam_t = 0.0
		horse.haul_speed_cap = INF
		horse.haul_accel_scale = 1.0
		return
	var d := data()
	var w := float(d.get("horse_kg", 430.0))
	var frac := load.pull_kgf / w
	cap = cap_for_pull(frac)
	if cap <= 0.0 and not _stalled:
		_notice("Too heavy to drag this way: buck logs off the %s or go round" % load.load_name())
	_stalled = cap <= 0.0
	var after := float(d.get("jam_free_after_s", 3.0))
	if load.stretch > float(d.get("jam_stretch_m", 0.2)):
		if jam_t <= 0.0:
			_notice("The %s is caught: turn the horse to free it" % load.load_name())
		# held a while: it is worked free, sideways off what holds it, for as long as it stays caught
		if jam_t + delta > after:
			load.work_free(float(d.get("jam_free_for_s", 1.2)), jam_t <= after)
		jam_t += delta
		cap = 0.0
	else:
		jam_t = maxf(jam_t - delta * 4.0, 0.0)
	horse.haul_speed_cap = cap
	horse.haul_accel_scale = lerpf(1.0, float(d.get("accel_scale_min", 0.35)), clampf(frac / float(d.get("pull_max_frac", 1.5)), 0.0, 1.0))


## In a cart's shafts: its weight rolled over the ground and up the grade (HorseCart.pull_kgf) caps the pace as a
## log's pull does; the cart held by a tree or a wall stops the horse.
func _cart_cap() -> void:
	var d := data()
	var w := float(d.get("horse_kg", 430.0))
	var frac := cart.pull_kgf / w
	cap = cap_for_pull(frac)
	if cart.stuck:
		if jam_t <= 0.0:
			_notice("The cart is caught: turn the horse to swing it clear")
		jam_t += get_physics_process_delta_time()
		cap = 0.0
	else:
		jam_t = 0.0
	horse.haul_speed_cap = cap
	horse.haul_accel_scale = lerpf(1.0, float(d.get("accel_scale_min", 0.35)), clampf(frac / float(d.get("pull_max_frac", 1.5)), 0.0, 1.0))


# --- Hitching ---------------------------------------------------------------------------------------------

## Chains a felled tree (FelledTree, DOWN) by its butt, or a loose bole (SkidLoad) by end `end` (0 front, 1
## back). `p` (the player) gets the crown's firewood and branches. Returns the load, or null when it is too
## heavy or something is already on.
func hitch_tree(ft: FelledTree, end := 0, p: Node = null) -> SkidLoad:
	if load != null or ft == null or not is_instance_valid(ft) or ft.state != FelledTree.State.DOWN:
		return null
	if not can_start(mass_of(ft)):
		return null
	var s: SkidLoad
	if ft is SkidLoad:
		s = ft as SkidLoad
		if s.hitched or s.bundle > 0:
			return null
		if end == 1:
			s.swap_ends()
	else:
		var visuals := DisplayServer.get_name() != "headless"
		s = SkidLoad.from_felled(ft, data(), _log_len(), visuals)
		ft.get_parent().add_child(s)
		# limbed and topped where it lies: the crown's firewood and branches into the pack
		var cy := ft.crown_yield()
		var g: GatherTools = p.get("gather") if p != null else null
		for item: String in cy:
			if g:
				g.give(item, int(cy[item]))
		if visuals and is_inside_tree():
			GatherFx.wood_chips(get_tree().current_scene, ft.top(), Vector3.UP, 10)
		if g and g.target.get("felled") == ft:
			g.target = {}
		ft.queue_free()
	_attach(s)
	return s


## Takes up to bundle_max logs from `p`'s pack and chains them behind the horse; null without logs.
func hitch_pack(p: Node) -> SkidLoad:
	if load != null or p == null:
		return null
	var inv := InventoryState.from_player(p)
	var n := inv.take("log", int(data().get("bundle_max", 6)))
	if n <= 0:
		return null
	p.set("inventory_pack", inv.pack.duplicate(true))
	var back := horse.global_basis.z
	back.y = 0.0
	back = back.normalized()
	var at := hitch_point() + back * (float(data().get("chain_m", 2.4)) - 0.4)
	at.y -= Horse.HITCH_HEIGHT - 0.25          # about on the ground: the load settles itself
	var s := SkidLoad.make_bundle(n, at, back, data(), DisplayServer.get_name() != "headless")
	horse.get_parent().add_child(s)
	_attach(s)
	_notice("%d logs chained behind the horse" % n)
	return s


## Ropes dead animal `a` (CarcassLoad.haulable()) by the neck behind the horse; null when it cannot be taken.
func hitch_carcass(a: Node3D) -> CarcassLoad:
	if load != null or not CarcassLoad.haulable(a):
		return null
	var s := CarcassLoad.from_carcass(a, data(), DisplayServer.get_name() != "headless")
	if not can_start(s.mass_kg):
		s.free()
		return null
	horse.get_parent().add_child(s)
	_attach(s)
	return s


func _attach(s: SkidLoad) -> void:
	var d := data()
	var len_m := clampf(hitch_point().distance_to(s.front), float(d.get("chain_min_m", 1.8)), float(d.get("chain_max_m", 5.0)))
	s.hitch(self, len_m)
	load = s
	if s.body:
		horse.add_collision_exception_with(s.body)
	_notice("Hitched: the %s, about %s kg" % [s.load_name(), _thousands(roundi(s.mass_kg))])


## Lets the load go: a bole lies loose, a bundle is laid down as a LogPile, a carcass lies where it stopped.
## Returns what is left lying.
func unhitch() -> Node3D:
	var s := load
	load = null
	horse.haul_speed_cap = INF
	horse.haul_accel_scale = 1.0
	cap = INF
	jam_t = 0.0
	if s == null or not is_instance_valid(s):
		return null
	if s is CarcassLoad:
		var a := (s as CarcassLoad).release()
		s.queue_free()
		return a
	s.unhitch()
	if s.bundle > 0:
		var pile := LogPile.from_load(s)
		s.get_parent().add_child(pile)
		s.queue_free()
		return pile
	return s


## Weight (kg) of what hitching `ft` would put on the chain.
func mass_of(ft: FelledTree) -> float:
	if ft is SkidLoad:
		return (ft as SkidLoad).mass_kg
	return SkidLoad.bole_mass(ft.info, float(maxi(ft.logs_left, 1)) * _log_len(), data())


static func _log_len() -> float:
	return float(GatherData.get_default().felling.get("log_length_m", 2.4))


# --- E ---------------------------------------------------------------------------------------------------

## What E offers now (on foot, or from the saddle): {kind, point, text, ft, end}, or {}.
func _find_offer(saddle: bool) -> Dictionary:
	var p := _player()
	if p == null or (p.get("is_dead") == true) or cart != null:
		return {}
	var rides: Variant = p.get("riding")
	if saddle != (rides == horse):
		return {}
	if not saddle and rides != null:
		return {}
	if not saddle and _ridden_by_other(p):
		return {}
	if load != null:
		if saddle and absf(horse.speed) > 0.3:
			return {}
		var cp := load.chain_point()
		if not saddle and _flat(p.global_position, cp) > interact_reach + 1.0:
			# along the load: the nearer of its chained end and the rest of it
			var bp := load.bole_point(p.global_position)
			if _flat(p.global_position, bp) > interact_reach:
				return {}
			cp = bp
		return {"kind": "unhitch", "point": cp, "text": "Unhitch the %s" % load.load_name()}
	var d := data()
	var hp := hitch_point()
	var reach := float(d.get("hitch_reach_saddle_m" if saddle else "hitch_reach_m", 5.0))
	var best := {}
	var best_s := INF
	for n in get_tree().get_nodes_in_group(FelledTree.GROUP):
		var ft := n as FelledTree
		if ft == null or ft.state != FelledTree.State.DOWN:
			continue
		var ends: Array = [ft.hinge]
		if ft is SkidLoad:
			var s := ft as SkidLoad
			if s.hitched or s.bundle > 0 or s.has_meta(&"in_barrow"):
				continue
			ends = [s.front, s.back]
		for e in ends.size():
			var pt: Vector3 = ends[e]
			var dh := hp.distance_to(pt)
			if dh > reach:
				continue
			var sc := dh
			if not saddle:
				sc = _flat(p.global_position, pt)
				if sc > interact_reach:
					continue
			if sc < best_s:
				best_s = sc
				best = {"kind": "hitch", "point": pt, "ft": ft, "end": e}
	# dead animals: the rope goes round the neck
	for n in get_tree().get_nodes_in_group(&"wildlife"):
		var a := n as Node3D
		if a == null or _flat(a.global_position, hp) > reach + 2.0 or not CarcassLoad.haulable(a):
			continue
		var pt := CarcassLoad.neck_point(a)
		var dh := hp.distance_to(pt)
		if dh > reach:
			continue
		var sc := dh
		if not saddle:
			sc = _flat(p.global_position, pt)
			if sc > interact_reach:
				continue
		if sc < best_s:
			best_s = sc
			best = {"kind": "carcass", "point": pt, "animal": a}
	if best.get("kind") == "carcass":
		var a: Node3D = best.animal
		var kg := CarcassLoad.mass_of_animal(a, d)
		var nm := CarcassLoad.name_of(a)
		if can_start(kg):
			best["text"] = ("Hitch the %s" if saddle else "Hitch the %s to the horse") % nm
		else:
			best["kind"] = "heavy"
			best["text"] = "Too heavy for one horse (about %s kg)" % _thousands(roundi(kg))
		return best
	if not best.is_empty():
		var ft: FelledTree = best.ft
		var kg := mass_of(ft)
		var nm := ft.species_name()
		if can_start(kg):
			best["text"] = ("Hitch the %s" if saddle else "Hitch the %s to the horse") % nm
		else:
			best["kind"] = "heavy"
			best["text"] = "Too heavy for one horse (about %s kg): buck logs off it" % _thousands(roundi(kg))
		return best
	return {}


## On foot at the horse's hitch with logs in the pack, nothing on the chain: {kind "pack", point, text}, or {}
## (its own interactable, PackSpot, so the view picks between it and a log end by it).
func _find_pack_offer() -> Dictionary:
	var p := _player()
	if load != null or cart != null or p == null or p.get("is_dead") == true or p.get("riding") != null or _ridden_by_other(p):
		return {}
	var hp := hitch_point()
	if _flat(p.global_position, hp) > interact_reach:
		return {}
	var logs := InventoryState.from_player(p).pack_count("log")
	if logs <= 0:
		return {}
	var n := mini(logs, int(data().get("bundle_max", 6)))
	return {"kind": "pack", "point": hp, "text": "Hitch %d log%s from the pack" % [n, "" if n == 1 else "s"]}


func interact_point() -> Vector3:
	return _offer.get("point", Vector3.INF)


## Near the butt the hitch wins over the axe's "Buck" (GatherTarget) at the same log. At a carcass it does not:
## the view picks between its neck (Hitch) and its body (WildAnimal's "Skin").
func distance_from(pt: Vector3) -> float:
	if _offer.is_empty():
		return INF
	return maxf(_flat(pt, _offer.point) - (0.0 if _offer.get("kind") == "carcass" else 0.8), 0.0)


func interact_prompt(p: Node) -> String:
	if p != null and p.get("riding") == horse:
		return String(_saddle_offer.get("text", ""))
	return String(_offer.get("text", ""))


## From the saddle (PlayerInteractor: a tap of E while riding).
func saddle_prompt(p: Node) -> String:
	if p == null or p.get("riding") != horse:
		return ""
	return String(_saddle_offer.get("text", ""))


## Nothing glows: a log lit whole along its 10 m drowns the view (as GatherTarget found for a felled tree),
## and the prompt says what E does.
func highlight_targets() -> Array:
	return []


func interact(p: Node) -> bool:
	var saddle: bool = p != null and p.get("riding") == horse
	var o := _saddle_offer if saddle else _offer
	match String(o.get("kind", "")):
		"unhitch":
			var nm := load.load_name() if load != null else ""
			var left := unhitch()
			_notice("Unhitched" if left == null else ("The logs are laid down" if left is LogPile else "Unhitched the %s" % nm))
			return true
		"hitch":
			return hitch_tree(o.ft, int(o.end), p) != null
		"carcass":
			return hitch_carcass(o.animal) != null
		"heavy":
			_notice(String(o.text))
			return false
	return false


func _refresh_label() -> void:
	var p := _player()
	if p == null:
		return
	var it: Node = p.get("interactor")
	var t := interact_prompt(p)
	if t == _label_text:
		return
	_label_text = t
	# the interactor refreshes its prompt only when its target changes (GatherTools does the same)
	if it and it.get("target") == self and it.has_method(&"_update_label"):
		it.call(&"_update_label")


## The pack's logs at the horse's hitch, as its own E target (HorseHaul._find_pack_offer()).
class PackSpot:
	extends Node
	var haul: HorseHaul

	func _ready() -> void:
		add_to_group(PlacedWeapon.GROUP)

	func interact_point() -> Vector3:
		return haul._pack_offer.get("point", Vector3.INF)

	func distance_from(pt: Vector3) -> float:
		return INF if haul._pack_offer.is_empty() else HorseHaul._flat(pt, haul._pack_offer.point)

	func interact_prompt(_p: Node) -> String:
		return String(haul._pack_offer.get("text", ""))

	func highlight_targets() -> Array:
		return []

	func interact(p: Node) -> bool:
		return not haul._pack_offer.is_empty() and haul.hitch_pack(p) != null


func _player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _ridden_by_other(p: Node) -> bool:
	var m := horse.get_node_or_null("Mount")
	return m != null and m.get("rider") != null and m.get("rider") != p


func _notice(text: String) -> void:
	var p := _player()
	var it: Node = p.get("interactor") if p else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _thousands(n: int) -> String:
	var s := str(n)
	return s if n < 1000 else "%s,%s" % [s.substr(0, s.length() - 3), s.substr(s.length() - 3)]


# --- Harness ---------------------------------------------------------------------------------------------

func _draw_harness() -> void:
	var on := load != null and horse.visual != null and DisplayServer.get_name() != "headless"
	_mi.visible = on
	_singletree.visible = on
	if not on:
		return
	_mesh.clear_surfaces()
	var sad := horse.get_saddle_transform()          # model axes: +x the horse's left, +z forward
	var hp := hitch_point()
	var right := horse.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var ends := [hp - right * 0.31, hp + right * 0.31]   # the singletree's left and right end
	var leather := _mat("leather", Color(0.2, 0.13, 0.08), 0.0, 0.6)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, leather)
	# the breast strap round the front of the chest, and a trace from each end of it back to the singletree
	var strap := PackedVector3Array()
	for k in 7:
		var a := lerpf(-1.0, 1.0, float(k) / 6.0)
		strap.append(sad * Vector3(0.27 * a, -0.34 - 0.03 * (1.0 - a * a), 0.72 + 0.2 * (1.0 - a * a)))
	ribbon(_mesh, strap, 0.035)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0            # model +x is the horse's left: ends[0]
		var pts := PackedVector3Array([sad * Vector3(0.27 * s, -0.34, 0.72), sad * Vector3(0.33 * s, -0.4, 0.3),
				sad * Vector3(0.37 * s, -0.44, -0.2), ends[i]])
		ribbon(_mesh, _smooth(pts, 3), 0.03)
	_mesh.surface_end()
	# the chain from the singletree's hook to the choker (a carcass: a rope to the collar round its neck)
	var cp := load.chain_point()
	if load is CarcassLoad:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, CarcassLoad.rope_material())
		ribbon(_mesh, sag(hp, cp, load.chain_len + 0.01, 18), 0.02, 0.01)
	else:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, iron_material())
		chain(_mesh, sag(hp, cp, load.chain_len + SkidLoad.CHOKER_M, 18))
	_mesh.surface_end()
	# the singletree across the horse's line of pull (a CylinderMesh along its +Y)
	_singletree.global_transform = Transform3D(Basis(right.cross(Vector3.UP).normalized(), right, Vector3.UP).orthonormalized(), hp)


## Points along a rope or chain of `rope_len` hung from a to b (a parabola sagging by its slack), n segments.
static func sag(a: Vector3, b: Vector3, rope_len: float, n: int) -> PackedVector3Array:
	var d := a.distance_to(b)
	var s := 0.0
	if rope_len > d:
		s = minf(sqrt(3.0 * d * (rope_len - d) / 8.0), 1.2)
	var out := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		out.append(a.lerp(b, t) + Vector3.DOWN * s * 4.0 * t * (1.0 - t))
	return out


## Catmull-Rom through `pts`, `sub` points per span.
static func _smooth(pts: PackedVector3Array, sub: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in sub:
			var t := float(k) / sub
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[pts.size() - 1])
	return out


## A flat strap (a cross of two quads, so it reads from any side) of width w along `pts`.
static func ribbon(m: ImmediateMesh, pts: PackedVector3Array, w: float, thick := 0.006) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := b - a
		if dir.length() < 1e-5:
			continue
		dir = dir.normalized()
		var side := dir.cross(Vector3.UP)
		side = (side.normalized() if side.length() > 1e-3 else Vector3.RIGHT) * w * 0.5
		var up := side.cross(dir).normalized() * thick
		for q in [side, up]:
			var s: Vector3 = q
			m.surface_set_normal(s.cross(dir).normalized())      # lit as a strap, not left dark
			for v in [a - s, a + s, b + s, a - s, b + s, b - s]:
				m.surface_add_vertex(v)


## A chain along `pts`: links of LINK_M, every other one turned a quarter round the line.
static func chain(m: ImmediateMesh, pts: PackedVector3Array) -> void:
	const LINK := 0.075
	const W := 0.03
	var k := 0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 1e-5:
			continue
		var dir := (b - a) / seg
		var side := dir.cross(Vector3.UP)
		side = side.normalized() if side.length() > 1e-3 else Vector3.RIGHT
		var up := side.cross(dir).normalized()
		var t := 0.0
		while t < seg:
			var p0 := a + dir * t
			var p1 := a + dir * minf(t + LINK * 0.9, seg)
			var s := (side if k % 2 == 0 else up) * W * 0.5
			var o := (up if k % 2 == 0 else side) * 0.004
			for v in [p0 - s + o, p0 + s + o, p1 + s + o, p0 - s + o, p1 + s + o, p1 - s + o]:
				m.surface_add_vertex(v)
			t += LINK
			k += 1


static func iron_material() -> StandardMaterial3D:
	return _mat("iron", Color(0.22, 0.21, 0.2), 0.7, 0.5)


static func _mat(key: String, c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metallic
		m.roughness = rough
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]
