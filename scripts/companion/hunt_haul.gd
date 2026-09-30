class_name HuntHaul
extends Node
## How a household hunter brings her kill home (user 2026-09-29: "if they are smart they will use a household wheelbarrow or
## horse to drag the carcass or put the carcass in the wagon/wheelbarrow to save time"). data/companion/hunt.json "transport".
##
## The choice (choose(), logic only): a smart hunter (smart(): her Hunting and Woodcraft, the kills she has made, her traits)
## uses the household's transport, when it is free, in this order: the horse (led out from home and the carcass dragged behind
## it on its rope: HorseLead, HorseHaul.hitch_carcass), the horse with the cart (HorseCart: the horse put to it at home when it
## is not in the shafts already; the carcass in the bed), the wheelbarrow (Wheelbarrow.put_carcass: a deer whole; one she took
## out with her and left where she began her stalk, or fetched from home). A bison needs the horse or the cart. Otherwise she
## drags it by hand (HuntDrag, slow; not too heavy, not too far) or dresses it where it lies and carries the meat home, a
## quarter a trip (dress_trips()).
##
## The trip (this node, on her body; HuntRun's phase "transport" runs step()): to the horse (or the barrow), leading or pushing
## it to the carcass, the carcass on or in, home to the drop by the hearth, the carcass off, and the transport back to where it
## stood (the horse stands where it stood, the cart is parked in its place, the barrow set down in its place or back in the
## cart). Transport is free when nobody rides, leads, pushes or loads it and no other worker has it (meta hunt_by: her worker
## id while she has it); a horse that is being broken or ridden by the player (player_input) is not free.
## RIDING (user 2026-09-29: "if the horse is available they should ride the horse for the hunt", "saddle the carcass and head
## home", "park the horse ... in locations they remember where they put it, pick it up and go home"): a hunter who took the
## horse out as her stalk began (HuntRun._horse_first: ridden, or led by the young) left it standing out of the quarry's sight
## (horse_out; the horse keeps who left it, where, when and why: meta left_by). For the kill she goes back to it, rides it to
## the kill (HuntRide), lays a deer or a buck across the saddle (CarcassPack, up to ride.pack_max_kg) and leads it home, or
## ropes a heavier one behind it and rides home; the horse from home she rides out the same way. The horse she has out comes
## home with her in the end (begin_stow), ridden.
## The real hauling code does the work: HorseLead (the horse follows her as it follows the player), HorseHaul (the rope, the
## pull caps its pace), HorseCart (the shafts, the bed), Wheelbarrow (the bed, the pace by the load). She pushes the barrow as
## the player does (its pose in front of her, from Wheelbarrow's own grips and wheel).

const META := &"hunt_by"
## At a thing (m).
const AT := 1.7
## She stops for the horse when it is this far from her, and walks on when it has come up within HORSE_ON_M (HorseLead: a
## horse left far behind trots off round a wide turn to catch up; kept close, it follows at a walk and turns tight).
## (from its bit to her: HorseLead stops the head FOLLOW_M off her; the rope is ROPE_M)
const HORSE_WAIT_M := 3.0
const HORSE_ON_M := 2.1
## A walk given up when she has come no nearer for this long (s), any step after STEP_GIVE_UP_S: the trip ends where it is.
const NO_HEADWAY_S := 30.0
## A led horse that comes no nearer to her for this long (s) will not follow.
const HORSE_STUCK_S := 25.0
const STEP_GIVE_UP_S := 900.0

var run: HuntRun
var body: Spouse
var sc: SpouseCore
## The transport in use: "horse", "cart", "barrow" ("" none).
var kind := ""
var horse: Horse = null
var cart: HorseCart = null
var barrow: Wheelbarrow = null
var carcass: Node3D = null
## The barrow before her (she has the handles).
var pushing := false
## The trip's steps left, and the step in hand.
var steps: Array = []
var step_name := ""
var _t := 0.0
var _best := INF
var _best_t := 0.0
var _horse_best := INF
var _horse_t := 0.0
var _waiting_horse := false
## Where each thing stood when she took it: instance id -> Transform3D.
var _places := {}
var _cart_was_hitched := false
var _barrow_cart: HorseCart = null
## The barrow she took out with her and left where her stalk began (or null).
var barrow_out: Wheelbarrow = null
## The horse she took out as her stalk began (ridden or led) and left standing out of the quarry's sight (or null).
var horse_out: Horse = null
## The kill across its saddle (CarcassPack), or null.
var pack: CarcassPack = null
## This trip is ridden (HuntRide), not led.
var rides := false
## The kill goes behind the saddle (she rides home), not across it (she leads the horse).
var pack_behind := false
## Where she was as she set off for the saddle: the side she gets up on is chosen once from there (the nearer one), not
## again at every step (the goal flipping from side to side as she came round the horse).
var _saddle_from := Vector3.INF
var _exceptions: Array[PhysicsBody3D] = []
## What happened (tests, the look-check log).
var log: Array = []
## Why the trip in hand was given up ("" it was not).
var aborted := ""


func _ready() -> void:
	process_physics_priority = 5            # after her body has moved, before the barrow seats its load (6)


# ================================================================ the choice (logic)
static func tcfg() -> Dictionary:
	return HuntJob.cfg().get("transport", {})


## How smart a hunter she is about getting the kill home (0..1): her Hunting and Woodcraft, the kills she has made (her
## experience), and her traits (a recruit's: transport.traits).
static func smart(w: SpouseCore) -> float:
	var c := tcfg()
	var k: Dictionary = c.get("weights", {})
	var s := float(k.get("hunting", 0.55)) * SurvivalSkills.level(w.core, "hunting") / 100.0 \
			+ float(k.get("woodcraft", 0.2)) * SurvivalSkills.level(w.core, "woodcraft") / 100.0 \
			+ float(k.get("kill", 0.02)) * mini(int(w.core.state.flags.get("hunt_kills", 0)), int(k.get("kills_max", 10)))
	var tr: Dictionary = c.get("traits", {})
	for t: Variant in w.recruit.get("traits", []):
		s += float(tr.get(String(t), 0.0))
	return clampf(s, 0.0, 1.0)


## The kill's weight (kg): transport.kg by species (the horse's haul.json has no bison), else the haul's carcass table.
static func kg_of(species: String, node: Object = null) -> float:
	var kg := float((tcfg().get("kg", {}) as Dictionary).get(species, 0.0))
	if node is Node:
		kg = maxf(kg, CarcassLoad.mass_of_animal(node as Node, HorseHaul.data()))
	elif kg <= 0.0:
		var t: Dictionary = (HorseHaul.data().get("carcass", {}) as Dictionary).get("kg", {})
		kg = float(t.get(species, t.get("default", 50.0)))
	return kg


## How the kill comes home: "horse", "cart", "barrow" (the transport free for her: `free` {horse, cart, barrow (at home),
## barrow_out (the one she took out)}), "drag" (by hand), "quarter" (dressed and carried in trips) or "dress" (one trip).
static func choose(smart_v: float, kg: float, dist_home: float, free: Dictionary) -> String:
	var c := tcfg()
	# (the horse she brought out is used whatever her smarts: that is what she brought it for)
	if bool(free.get("horse_out", false)) and (kg <= pack_max_kg() or HorseHaul.can_start(kg)):
		return "horse"
	if smart_v >= float(c.get("smart_min", 0.35)):
		var near := dist_home <= float(c.get("horse_fetch_m", 260.0))
		if bool(free.get("horse", false)) and near and HorseHaul.can_start(kg):
			return "horse"
		if bool(free.get("cart", false)) and near and kg <= HorseCart.CAPACITY_KG:
			return "cart"
		if kg <= float(c.get("barrow_max_kg", 120.0)) and (bool(free.get("barrow_out", false))
				or (bool(free.get("barrow", false)) and dist_home <= float(c.get("barrow_fetch_m", 200.0)))):
			return "barrow"
	var h: Dictionary = HuntJob.cfg().get("haul", {})
	if kg <= float(c.get("drag_max_kg", h.get("max_kg", 90.0))) and dist_home <= float(h.get("max_home_m", 220.0)):
		return "drag"
	return "quarter" if dress_trips(kg) > 1 else "dress"


## Trips to carry a dressed kill home: its meat (meat_share of the weight) a carry_kg load a trip, at most max_trips (the
## rest is left to the wolves).
static func dress_trips(kg: float) -> int:
	var c := tcfg()
	return clampi(ceili(kg * float(c.get("meat_share", 0.55)) / maxf(float(c.get("carry_kg", 30.0)), 1.0) - 0.001), 1,
			int(c.get("max_trips", 4)))


## The heaviest kill laid across the saddle (kg); a heavier one goes on the rope.
static func pack_max_kg() -> float:
	return float((tcfg().get("ride", {}) as Dictionary).get("pack_max_kg", 100.0))


## The heaviest kill behind the saddle with its rider up (kg): the horse carries both.
static func ride_pack_max_kg() -> float:
	return float((tcfg().get("ride", {}) as Dictionary).get("ride_pack_max_kg", 90.0))


## Whether she takes the wheelbarrow out with her when her stalk begins (smart enough, and it is free near her).
static func plans_barrow(smart_v: float) -> bool:
	return smart_v >= float(tcfg().get("plan_barrow", 0.5))


# ================================================================ what is free
func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _home() -> Vector3:
	return body.hearth


func _home_r() -> float:
	return float(tcfg().get("home_r", 45.0))


func _mine(n: Node) -> bool:
	return int(n.get_meta(META, -1)) == sc.worker_id


func _others(n: Node) -> bool:
	var by := int(n.get_meta(META, -1))
	return by >= 0 and by != sc.worker_id


## Why horse `h` is not free for her ("" free).
func why_not_horse(h: Horse) -> String:
	if h == null or not is_instance_valid(h) or h.is_queued_for_deletion() or h.has_meta(&"breaking"):
		return "no horse"
	if h.player_input:
		return "ridden"
	var m := h.get_node_or_null("Mount")
	if m == null or m.get("rider") != null:
		return "ridden"
	var l := h.get_node_or_null("Lead") as HorseLead
	if l == null or (l.leading and l.leader != body):
		return "led"
	var hh := h.get_node_or_null("Haul") as HorseHaul
	if hh == null or hh.load != null:
		return "hauling"
	if _others(h):
		return "another worker's"
	return ""


func why_not_cart(c: HorseCart) -> String:
	if c == null or not is_instance_valid(c):
		return "no cart"
	if _others(c):
		return "another worker's"
	if c.is_hitched():
		var w := why_not_horse(c.horse)
		if w != "":
			return w
	return ""


func why_not_barrow(b: Wheelbarrow) -> String:
	if b == null or not is_instance_valid(b):
		return "no barrow"
	if b.is_pushed() and not (pushing and b == barrow):
		return "pushed"
	if b.load_node != null or b.total() > 0:
		return "loaded"
	if _others(b):
		return "another worker's"
	var ic: Variant = b.get_meta(&"in_cart") if b.has_meta(&"in_cart") else null
	if ic is HorseCart and why_not_cart(ic as HorseCart) != "":
		return "in a cart in use"
	return ""


func horses() -> Array:
	var sc_ := body.get_tree().current_scene if body.is_inside_tree() else null
	var out := []
	if sc_ == null:
		return out
	for n in sc_.find_children("*", "Horse", true, false):
		if n is Horse:
			out.append(n)
	return out


## The household's free transport at home: {horse, cart, barrow} (the nearest free one of each within transport.home_r of
## the hearth; a cart counts when a free horse is in its shafts or at home to be put to it; a horse in a cart's shafts is the
## cart's) and whether the barrow she took out is still hers (barrow_out).
func available() -> Dictionary:
	var out := {}
	var home := _home()
	var bd := INF
	for h: Horse in horses():
		var hh := HorseCart.haul_of(h)
		if why_not_horse(h) != "" or (hh != null and hh.cart != null and is_instance_valid(hh.cart)):
			continue
		var d := _flat(h.global_position, home)
		if d <= _home_r() and d < bd:
			bd = d
			out["horse"] = h
	var c := HorseCart.find(body.get_tree())
	if c != null and why_not_cart(c) == "" and _flat(c.global_position, home) <= _home_r() \
			and (c.is_hitched() or out.has("horse")) and c.loads.is_empty():
		out["cart"] = c
	bd = INF
	for n in body.get_tree().get_nodes_in_group(Wheelbarrow.GROUP):
		var b := n as Wheelbarrow
		if b == null or why_not_barrow(b) != "" or b == barrow_out:
			continue
		var d := _flat(b.global_position, home)
		if d <= _home_r() and d < bd:
			bd = d
			out["barrow"] = b
	if barrow_out != null and is_instance_valid(barrow_out) and _mine(barrow_out) and why_not_barrow(barrow_out) == "":
		out["barrow_out"] = barrow_out
	if horse_out != null and is_instance_valid(horse_out) and _mine(horse_out) and why_not_horse(horse_out) == "":
		out["horse_out"] = horse_out
	return out


## The flags choose() takes from available().
static func flags(av: Dictionary) -> Dictionary:
	return {"horse": av.has("horse"), "cart": av.has("cart"), "barrow": av.has("barrow"), "barrow_out": av.has("barrow_out"),
			"horse_out": av.has("horse_out")}


# ================================================================ taking it and putting it back
func _reserve(n: Node3D) -> void:
	n.set_meta(META, sc.worker_id)
	if not _places.has(n.get_instance_id()):
		_places[n.get_instance_id()] = n.global_transform


func _free(n: Node) -> void:
	if n != null and is_instance_valid(n) and _mine(n):
		n.remove_meta(META)


func place_of(n: Node3D) -> Transform3D:
	return _places.get(n.get_instance_id(), n.global_transform)


## The wheelbarrow out with her as her stalk begins (reserved; she takes the handles where it stands). False: not free.
func take_barrow_out(b: Wheelbarrow) -> bool:
	if b == null or why_not_barrow(b) != "":
		return false
	_reserve(b)
	var ic: Variant = b.get_meta(&"in_cart") if b.has_meta(&"in_cart") else null
	if ic is HorseCart:
		_barrow_cart = ic
		_reserve(ic as HorseCart)
		(ic as HorseCart).take_out()
	barrow_out = b
	barrow = b
	log.append("barrow_out")
	return true


## The horse out with her as her stalk begins (reserved; she mounts it, or takes its lead, where it stands). False: not free.
func take_horse_out(h: Horse) -> bool:
	if h == null or why_not_horse(h) != "":
		return false
	_reserve(h)
	horse_out = h
	horse = h
	log.append("horse_out")
	return true


## The horse she has out left standing where it is (she goes on on foot): off her lead, and the horse keeps who left it,
## where, when and why (meta left_by: {id, who, at, t, why}), for her to come back to.
func park_horse(why: String) -> void:
	if horse_out == null or not is_instance_valid(horse_out):
		return
	var l := horse_out.get_node_or_null("Lead") as HorseLead
	if l != null and l.leading and l.leader == body:
		l.stop()
	horse_out.drive(0.0, 0.0)
	horse_out.set_meta(&"left_by", {"id": sc.worker_id, "who": sc.name, "at": horse_out.global_position,
			"t": StoreLedger.now(body.get_tree()), "why": why})
	log.append("parked")


## Begins the trip with transport `k` for `a` (the carcass): reserves it and lays out the steps. False: not free now.
func begin(k: String, a: Node3D, av: Dictionary) -> bool:
	carcass = a
	steps = []
	match k:
		"horse":
			horse = av.get("horse_out", av.get("horse"))
			if horse == null:
				return false
			_reserve(horse)
			var kg := kg_of(String(sc.hunt.get("species", "")), a)
			var up := HuntRide.can_ride(sc)
			pack_behind = up and kg <= ride_pack_max_kg()
			steps = horse_steps(up, kg <= (ride_pack_max_kg() if up else pack_max_kg()),
					run.ride != null and run.ride.on and run.ride.horse == horse)
		"cart":
			cart = av.get("cart")
			if cart == null:
				return false
			_reserve(cart)
			_cart_was_hitched = cart.is_hitched()
			horse = cart.horse if _cart_was_hitched else av.get("horse")
			if horse == null:
				return false
			_reserve(horse)
			steps = ["to_horse", "lead"]
			if not _cart_was_hitched:
				steps += ["to_shafts", "hitch_cart"]
			steps += ["to_carcass", "cart_in", "to_drop", "cart_out"]
			if not _cart_was_hitched:
				steps += ["to_cart_place", "unhitch_cart"]
			steps += ["to_horse_place", "stay"]
		"barrow":
			var b: Wheelbarrow = av.get("barrow_out", av.get("barrow"))
			if b == null:
				return false
			if b != barrow_out:
				_reserve(b)
				var ic: Variant = b.get_meta(&"in_cart") if b.has_meta(&"in_cart") else null
				if ic is HorseCart:
					_barrow_cart = ic
					_reserve(ic as HorseCart)
			barrow = b
			steps = ["to_barrow"]
			if b.has_meta(&"in_cart"):
				steps += ["barrow_from_cart"]
			steps += ["handles", "to_carcass", "barrow_in", "to_drop", "barrow_out", "to_barrow_place", "set_down"]
			if _barrow_cart != null:
				steps += ["to_cart_tail", "barrow_to_cart"]
		_:
			return false
	kind = k
	_t = 0.0
	step_name = ""
	aborted = ""
	log.append("begin %s" % k)
	return true


## The horse's trip: `ride` (a grown worker: to it, up, and out to the kill in the saddle; else she leads it), `packed` (the
## kill on its back: behind the saddle and she rides home, or, led, across the saddle; else on the rope behind it, ridden
## home), `mounted` (she is up already).
static func horse_steps(ride: bool, packed: bool, mounted := false) -> Array:
	var out: Array = []
	if ride:
		out += ([] if mounted else ["to_saddle", "mount"]) + ["to_carcass", "dismount"]
		if packed:
			out += ["to_carcass", "pack_carcass", "to_saddle", "mount", "to_drop", "dismount", "unpack_carcass", "lead",
					"to_horse_place", "stay"]
		else:
			out += ["hitch_carcass", "to_saddle", "mount", "to_drop", "dismount", "unhitch_carcass", "lead", "to_horse_place", "stay"]
		return out
	out += ["to_horse", "lead", "to_carcass"]
	if packed:
		out += ["pack_carcass", "to_drop", "unpack_carcass"]
	else:
		out += ["hitch_carcass", "to_drop", "unhitch_carcass"]
	return out + ["to_horse_place", "stay"]


## Lets go of everything (the hunt ended, wolves, a step that cannot be done): the carcass off the horse or out of the barrow
## where it is, the lead dropped (the horse stands), the handles let go (the barrow set down), the reservations off. Returns
## the carcass (where it lies now) or null.
func abort(why := "", keep_horse := false) -> Node3D:
	var a := carcass
	if run != null and run.ride != null and run.ride.on:
		run.ride.dismount()
	if pack != null:
		var rp: Node3D = pack.release()
		pack = null
		a = rp if rp != null else a
	if horse != null and is_instance_valid(horse):
		var hh := HorseCart.haul_of(horse)
		if hh != null and hh.load != null and _mine(horse):
			var r := hh.unhitch()
			a = r if r != null else a
		var l := horse.get_node_or_null("Lead") as HorseLead
		if l != null and l.leading and l.leader == body:
			l.stop()
	if cart != null and is_instance_valid(cart) and _mine(cart):
		for ld: Dictionary in cart.loads.duplicate():
			if ld.get("node") == carcass:
				var r := cart.take_out()
				a = r if r != null else a
	_set_down()
	if barrow != null and is_instance_valid(barrow) and barrow.load_node == carcass and carcass != null:
		var r := barrow.tip_out()
		a = r if r != null else a
	# (the horse she brought out stays hers, standing where it is, to be taken home: begin_stow)
	var keep := horse_out if keep_horse and horse_out != null and is_instance_valid(horse_out) else null
	for n in [horse, cart, barrow, barrow_out, _barrow_cart, horse_out]:
		if n != keep:
			_free(n)
	if keep != null:
		keep.drive(0.0, 0.0)
		if not keep.has_meta(&"left_by"):
			park_horse(String(sc.hunt.get("species", "the hunt")))
	if why != "":
		log.append("abort %s" % why)
	aborted = why if why != "" else "given up"
	horse_out = keep
	horse = keep
	cart = null
	barrow = null
	barrow_out = null
	_barrow_cart = null
	kind = ""
	steps = []
	step_name = ""
	carcass = null
	return a if a != null and is_instance_valid(a) else null


## The trip home for the barrow she took out and did not use for the kill: to where she left it, and pushed back to its place.
func begin_return() -> bool:
	if barrow_out == null or not is_instance_valid(barrow_out) or not _mine(barrow_out) or kind != "":
		return false
	barrow = barrow_out
	carcass = null
	steps = [] if pushing else ["to_barrow", "handles"]
	steps += ["to_barrow_place", "set_down"]
	if _barrow_cart != null:
		steps += ["to_cart_tail", "barrow_to_cart"]
	kind = "barrow"
	step_name = ""
	_t = 0.0
	aborted = ""
	log.append("return barrow")
	return true


## Lets go of the carcass only (wolves: it is left where it is), keeping the horse on its lead, the cart, the barrow before
## her: she takes them home with her (stow_steps then puts them back). Returns the carcass where it lies, or null.
func let_go_load(why: String) -> Node3D:
	var a := carcass
	if pack != null:
		var rp: Node3D = pack.release()
		pack = null
		a = rp if rp != null else a
	if horse != null and is_instance_valid(horse):
		var hh := HorseCart.haul_of(horse)
		if hh != null and hh.load != null:
			var r := hh.unhitch()
			a = r if r != null else a
	if cart != null and is_instance_valid(cart):
		for ld: Dictionary in cart.loads.duplicate():
			if ld.get("node") == carcass:
				var r2 := cart.take_out()
				a = r2 if r2 != null else a
	if barrow != null and is_instance_valid(barrow) and barrow.load_node == carcass and carcass != null:
		var was := pushing
		_set_down()
		var r3 := barrow.tip_out()
		a = r3 if r3 != null else a
		if was:
			_take_handles()
	steps = []
	step_name = ""
	carcass = null
	kind = ""                                   # (the trip is over; what she has out comes home with her: has_out)
	log.append("let go %s" % why)
	return a if a != null and is_instance_valid(a) else null


## Whether she has the household's transport out with her (a horse on her lead, the cart, the barrow).
func has_out() -> bool:
	return (horse != null and is_instance_valid(horse) and _mine(horse)) or (horse_out != null and is_instance_valid(horse_out) and _mine(horse_out)) \
			or (cart != null and is_instance_valid(cart) and _mine(cart)) \
			or (barrow != null and is_instance_valid(barrow) and _mine(barrow))


## The trip that puts back what she has out (home early: the wolves, the dusk): the horse to where it stood (the cart
## parked in its place first), the barrow to its place (or back in the cart). False: nothing out.
func begin_stow() -> bool:
	if not has_out():
		return false
	steps = []
	if horse == null and horse_out != null and is_instance_valid(horse_out):
		horse = horse_out
	if horse != null and is_instance_valid(horse):
		var l := horse.get_node_or_null("Lead") as HorseLead
		var up := run != null and run.ride != null and run.ride.on and run.ride.horse == horse
		var in_cart := cart != null and is_instance_valid(cart) and not _cart_was_hitched and cart.is_hitched()
		if (up or HuntRide.can_ride(sc)) and not in_cart:
			# (ridden home, off at its place)
			steps += ([] if up else ["to_saddle", "mount"]) + ["to_horse_place", "dismount", "stay"]
		else:
			if l == null or not l.leading or l.leader != body:
				steps += ["to_horse", "lead"]
			if in_cart:
				steps += ["to_cart_place", "unhitch_cart"]
			steps += ["to_horse_place", "stay"]
	elif barrow != null and is_instance_valid(barrow):
		if not pushing:
			steps += ["to_barrow", "handles"]
		steps += ["to_barrow_place", "set_down"]
		if _barrow_cart != null:
			steps += ["to_cart_tail", "barrow_to_cart"]
	kind = "horse" if horse != null else ("cart" if cart != null else "barrow")
	carcass = null
	step_name = ""
	_t = 0.0
	aborted = ""
	log.append("stow %s" % kind)
	return true


# ================================================================ pushing the barrow
func take_handles() -> bool:
	return pushing or _take_handles()


func _take_handles() -> bool:
	if barrow == null or not is_instance_valid(barrow) or barrow.is_pushed() or barrow.has_meta(&"in_cart"):
		return false
	var f := barrow.global_basis.z
	if Vector2(f.x, f.z).length() > 0.1:
		body.set("_face", atan2(-f.x, -f.z))    # (she faces the way it points as she takes the handles)
		body.rotation.y = atan2(-f.x, -f.z)
	pushing = true
	_except(true)
	return true


func _set_down() -> void:
	if not pushing:
		return
	pushing = false
	if barrow != null and is_instance_valid(barrow):
		var f := barrow.global_basis.z
		barrow.park_at(barrow.global_position, Vector3(f.x, 0.0, f.z))
	_except(false)


## Her body and the barrow (its bed and what is in it) do not bump while she pushes it.
func _except(on: bool) -> void:
	for b in _exceptions:
		if is_instance_valid(b) and is_instance_valid(body):
			body.remove_collision_exception_with(b)
	_exceptions.clear()
	if not on or barrow == null:
		return
	var list: Array = barrow.find_children("*", "PhysicsBody3D", true, false)
	if barrow.load_node != null and is_instance_valid(barrow.load_node):
		list += barrow.load_node.find_children("*", "PhysicsBody3D", true, false)
		if barrow.load_node is PhysicsBody3D:
			list.append(barrow.load_node)
	for b in list:
		if b is PhysicsBody3D and b != body:
			body.add_collision_exception_with(b)
			_exceptions.append(b)


## The barrow before her as she walks (Wheelbarrow's own pushed pose, from her body: the grips at her hands, the wheel on the
## ground ahead).
func _physics_process(_dt: float) -> void:
	if not pushing:
		return
	if barrow == null or not is_instance_valid(barrow) or body == null or not is_instance_valid(body):
		pushing = false
		return
	var fwd := -body.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var grips := body.global_position + fwd * Wheelbarrow.GRIP_FWD + Vector3.UP * Wheelbarrow.GRIP_H
	var a := 0.0
	var axle := grips
	for i in 2:
		axle = grips + fwd * (Wheelbarrow.GRIP_BACK * cos(a) - Wheelbarrow.GRIP_UP * sin(a))
		axle.y = FrontierTerrain.height_at(axle.x, axle.z) + Wheelbarrow.WHEEL_R
		a = _pitch_for(Wheelbarrow.GRIP_UP, -Wheelbarrow.GRIP_BACK, grips.y - axle.y)
	barrow.global_transform = Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)) * Basis(Vector3.RIGHT, a), axle)


## The pitch (about the barrow's +X) that puts its local point (y, z) `dy` over the axle (as Wheelbarrow's own).
static func _pitch_for(y: float, z: float, dy: float) -> float:
	var r := sqrt(y * y + z * z)
	return asin(clampf(dy / r, -1.0, 1.0)) - atan2(y, -z)


# ================================================================ the trip
func _text() -> String:
	var sp := String(sc.hunt.get("species", "carcass"))
	match step_name:
		"to_horse", "lead", "to_saddle", "mount":
			return "Fetching the horse" if horse_out == null else "Going back to the horse"
		"pack_carcass":
			return "Laying the %s across the saddle" % sp
		"dismount":
			return "Getting down"
		"to_shafts", "hitch_cart":
			return "Putting the horse to the cart"
		"to_barrow", "barrow_from_cart", "handles":
			return "Fetching the wheelbarrow"
		"to_carcass", "hitch_carcass", "cart_in", "barrow_in":
			return "Bringing the %s to the %s" % [_noun(), sp]
		"to_drop", "unhitch_carcass", "cart_out", "barrow_out", "unpack_carcass":
			if kind == "horse" and pack != null:
				if pack.behind:
					return "Riding home with the %s behind the saddle" % sp
				return "Leading the horse home with the %s across the saddle" % sp
			return "Bringing the %s home %s" % [sp, "behind the horse" if kind == "horse" else "in the " + _noun()]
	return "Putting the %s back" % _noun()


func _noun() -> String:
	return String({"horse": "horse", "cart": "cart", "barrow": "wheelbarrow"}.get(kind, "load"))


## Where she walks for the step (Vector3.INF: the step is not a walk).
func _goal(s: String) -> Vector3:
	match s:
		"to_horse":
			# (to its head, as the player takes a horse by the bit: led from behind it trots off round a wide turn)
			if horse == null:
				return Vector3.INF
			var hf := -horse.global_basis.z
			hf.y = 0.0
			return horse.global_position + hf.normalized() * 1.7
		"to_saddle":
			if _saddle_from == Vector3.INF:
				_saddle_from = body.global_position
			return HuntRide.mount_point(horse, _saddle_from) if horse else Vector3.INF
		"to_barrow":
			return barrow.grips_point() if barrow else Vector3.INF
		"to_carcass":
			if carcass == null or not is_instance_valid(carcass):
				return Vector3.INF
			if kind == "horse" and ("pack_carcass" in steps or _riding()):
				return carcass.global_position   # (up to it: the horse stands by it for the lift; ridden, beside it)
			if kind in ["horse", "cart"]:
				# (past it, away from home: the horse's hitch, or the cart's tail, comes up by it)
				var away := carcass.global_position - _home()
				away.y = 0.0
				away = away.normalized() if away.length() > 0.5 else Vector3.FORWARD
				return carcass.global_position + away * (2.5 if kind == "horse" else 4.5)
			return carcass.global_position
		"to_drop":
			return run.drop_point()
		"to_horse_place":
			return place_of(horse).origin if horse else Vector3.INF
		"to_shafts":
			# (ahead of the shafts' tips on the cart's line: the horse comes up beside her, its shoulders by them)
			return cart.tips_point() + cart.forward() * 1.6 - cart.forward().cross(Vector3.UP).normalized() * 1.2 if cart else Vector3.INF
		"to_cart_place":
			var xf := place_of(cart)
			var f := xf.basis.z
			f.y = 0.0
			return xf.origin + f.normalized() * (HorseCart.SHAFT_LEN + 1.8) if cart else Vector3.INF
		"to_barrow_place":
			var xb := place_of(barrow)
			var fb := xb.basis.z
			fb.y = 0.0
			return xb.origin - fb.normalized() * (Wheelbarrow.GRIP_BACK + Wheelbarrow.GRIP_FWD) if barrow else Vector3.INF
		"to_cart_tail":
			return _barrow_cart.tail_point() if _barrow_cart and is_instance_valid(_barrow_cart) else Vector3.INF
	return Vector3.INF


func _arrive(s: String) -> float:
	match s:
		"to_horse":
			return 0.9
		"to_saddle":
			return HuntRide.MOUNT_AT_M
		"to_carcass":
			if _riding():
				return 3.0
			return 2.4 if kind == "barrow" else AT
		"to_drop":
			return 1.4
		"to_barrow", "to_cart_tail", "to_barrow_place":
			return 1.2
	return AT


func _riding() -> bool:
	return run != null and run.ride != null and run.ride.on


## One frame of the trip: [dir, speed] for her body; ["done"] when it is over (the carcass home and the transport back),
## ["failed", why] when it cannot go on (abort() has let go).
func step(dt: float) -> Array:
	if steps.is_empty() and step_name == "":
		kind = ""
		if aborted != "":
			return ["failed", aborted]
		return ["done"]
	if step_name == "":
		step_name = String(steps.pop_front())
		_saddle_from = Vector3.INF
		_t = 0.0
		_best = INF
		_best_t = 0.0
		sc.task_text = _text()
	_t += dt
	if _t > STEP_GIVE_UP_S:
		var why := "stuck at %s" % step_name
		abort(why, true)
		return ["failed", why]
	var g := _goal(step_name)
	if step_name.begins_with("to_"):
		if g == Vector3.INF:
			return _next()
		var d := _flat(body.global_position, g)
		if d <= _arrive(step_name) or (step_name == "to_saddle" and HuntRide.at_saddle(horse, body.global_position)):
			return _next()
		var lag := _horse_lag()
		if lag > HORSE_WAIT_M or (_waiting_horse and lag > HORSE_ON_M):
			# (the horse has fallen behind: she stands for it to come up; one that makes no headway to her for
			# HORSE_STUCK_S will not come: the trip is given up for the next way home)
			_waiting_horse = true
			if lag < _horse_best - 0.3:
				_horse_best = lag
				_horse_t = 0.0
			else:
				_horse_t += dt
			if _horse_t > HORSE_STUCK_S:
				abort("the horse would not follow", true)
				return ["failed", "the horse would not follow"]
			return [Vector3.ZERO, 0.0]
		_waiting_horse = false
		_horse_best = INF
		_horse_t = 0.0
		if d < _best - 0.5:
			_best = d
			_best_t = 0.0
		else:
			_best_t += dt
		if _best_t > NO_HEADWAY_S:
			var why2 := "no way through to %s" % step_name.trim_prefix("to_")
			abort(why2, true)
			return ["failed", why2]
		return _go(g, _arrive(step_name))
	var r := _act(step_name)
	if r == "wait":
		return [Vector3.ZERO, 0.0]
	if r != "":
		abort(r, true)
		return ["failed", r]
	return _next()


func _next() -> Array:
	log.append(step_name)
	step_name = ""
	return [Vector3.ZERO, 0.0]


## Walking to `g` with what she has: the pace of the barrow's load, and a wait for the horse (and the cart) when it lags.
func _go(g: Vector3, arrive: float) -> Array:
	var speed := Spouse.WALK_SPEED
	if pushing and barrow:
		speed = minf(speed, Wheelbarrow.pace_for(barrow.load_kg()))
	if _horse_lag() > HORSE_ON_M:
		speed *= 0.75                           # (a slower step while the horse comes up)
	return run.walk(g, speed, arrive)


## How far the head of the horse she leads is from her (its bit; 0 when she leads none).
func _horse_lag() -> float:
	if horse == null or not is_instance_valid(horse):
		return 0.0
	var l := horse.get_node_or_null("Lead") as HorseLead
	if l == null or not l.leading or l.leader != body:
		return 0.0
	return _flat(l.bit_point(), body.global_position)


## A step that is not a walk: "" done, "wait" not yet, else why it cannot be done.
func _act(s: String) -> String:
	match s:
		"mount":
			if horse == null or not is_instance_valid(horse):
				return "the horse is gone"
			if absf(horse.speed) > 0.4:
				return "wait" if _t < 10.0 else "the horse would not stand"
			return "" if run.ride.mount(horse) else ("wait" if _t < 5.0 else "the horse cannot be mounted")
		"dismount":
			if _riding() and absf(run.ride.horse.speed) > 0.35 and _t < 6.0:
				return "wait"                   # (reined in: HuntRide)
			if _riding():
				# (on the side toward what she does next: the carcass, or home)
				var nxt: Vector3 = carcass.global_position if carcass != null and is_instance_valid(carcass) and pack == null else _home()
				run.ride.dismount(nxt)
			return ""
		"pack_carcass":
			if carcass == null or not is_instance_valid(carcass):
				return "the carcass is gone"
			if _flat(horse.global_position, carcass.global_position) > 4.5 or absf(horse.speed) > 0.4:
				return "wait" if _t < 30.0 else "the horse would not stand by the carcass"
			if not CarcassLoad.haulable(carcass):
				return "wait" if _t < 5.0 else "the carcass cannot be taken"
			if _t < 2.0:
				return "wait"                   # (the lift)
			pack = CarcassPack.pack(carcass, horse, pack_behind)
			return "" if pack != null else "the %s does not go on the horse" % String(sc.hunt.get("species", "carcass"))
		"unpack_carcass":
			if absf(horse.speed) > 0.4 and _t < 6.0:
				return "wait"
			if _t < 1.5:
				return "wait"
			if pack != null:
				var a: Node3D = pack.release()
				pack = null
				if a != null:
					carcass = a
			return ""
		"lead":
			var l := horse.get_node_or_null("Lead") as HorseLead if horse else null
			if l == null or why_not_horse(horse) != "":
				return "the horse is not free"
			l.start(body)
			return ""
		"hitch_cart":
			if cart.is_hitched():
				return ""
			if absf(horse.speed) > 0.4 or HorseCart.harness_point(horse).distance_to(cart.tips_point()) > HorseCart.HITCH_REACH:
				return "wait" if _t < 25.0 else "the horse would not stand to the shafts"
			if not cart.hitch(horse):
				return "wait" if _t < 25.0 else cart.why_not_hitch(horse)
			return ""
		"hitch_carcass":
			if carcass == null or not is_instance_valid(carcass):
				return "the carcass is gone"
			if _flat(HorseCart.haul_of(horse).hitch_point(), carcass.global_position) > 5.0 or absf(horse.speed) > 0.5:
				return "wait" if _t < 30.0 else "the horse would not come to the carcass"
			if not CarcassLoad.haulable(carcass):
				return "wait" if _t < 5.0 else "the carcass cannot be taken"
			return "" if HorseCart.haul_of(horse).hitch_carcass(carcass) != null else "too heavy for the horse"
		"unhitch_carcass":
			var hh := HorseCart.haul_of(horse)
			if absf(horse.speed) > 0.4 and _t < 6.0:
				return "wait"
			var a := hh.unhitch()
			if a != null:
				carcass = a
			return ""
		"cart_in":
			if carcass == null or not is_instance_valid(carcass):
				return "the carcass is gone"
			if cart.tail_point().distance_to(carcass.global_position) > 6.0 or absf(horse.speed) > 0.4:
				return "wait" if _t < 30.0 else "the cart would not come to the carcass"
			if not CarcassLoad.haulable(carcass):
				return "wait" if _t < 5.0 else "the carcass cannot be taken"
			return "" if cart.put_carcass(carcass) else cart.why_not_put("carcass", kg_of(String(sc.hunt.get("species", "")), carcass))
		"cart_out":
			if absf(horse.speed) > 0.4 and _t < 6.0:
				return "wait"
			var a := cart.take_out()
			if a != null:
				carcass = a
			return ""
		"unhitch_cart":
			if absf(horse.speed) > 0.4 and _t < 6.0:
				return "wait"
			if not _cart_was_hitched:
				cart.unhitch()
				var xf := place_of(cart)
				if cart.global_position.distance_to(xf.origin) < 6.0:
					cart.park_at(xf.origin, xf.basis.z)     # (a shove into its old place)
			return ""
		"stay":
			var l := horse.get_node_or_null("Lead") as HorseLead
			if l != null and l.leader == body:
				l.stop()
			if horse.has_meta(&"left_by"):
				horse.remove_meta(&"left_by")   # (home: nobody need remember where it was left)
			_free(horse)
			_free(cart)
			if horse == horse_out:
				horse_out = null
			horse = null
			cart = null
			return ""
		"barrow_from_cart":
			var c: Variant = barrow.get_meta(&"in_cart") if barrow.has_meta(&"in_cart") else null
			if c is HorseCart:
				(c as HorseCart).take_out()
			return ""
		"handles":
			return "" if pushing or _take_handles() else "the barrow cannot be pushed"
		"barrow_in":
			_set_down()
			if carcass == null or not is_instance_valid(carcass):
				return "the carcass is gone"
			if not CarcassLoad.haulable(carcass):
				if _t < 5.0:
					return "wait"
				return "the carcass cannot be taken"
			if not barrow.put_carcass(carcass):
				return "the %s does not go in the barrow" % String(sc.hunt.get("species", "carcass"))
			_take_handles()
			return ""
		"barrow_out":
			_set_down()
			var a := barrow.tip_out()
			if a != null:
				carcass = a
			_take_handles()
			return ""
		"set_down":
			_set_down()
			var xb := place_of(barrow)
			if barrow.global_position.distance_to(xb.origin) < 4.0:
				barrow.park_at(xb.origin, xb.basis.z)
			if _barrow_cart == null:
				_free(barrow)
				barrow = null
				barrow_out = null
			return ""
		"barrow_to_cart":
			if _barrow_cart != null and is_instance_valid(_barrow_cart) and barrow != null:
				_barrow_cart.put_barrow(barrow)
			_free(barrow)
			_free(_barrow_cart)
			barrow = null
			barrow_out = null
			_barrow_cart = null
			return ""
	return ""


## The barrow she took out, set down where her crouched stalk begins (she comes back for it after the kill).
func leave_barrow() -> void:
	if pushing:
		_set_down()
		log.append("left the barrow")


## Whether she has the handles of the barrow she took out (it goes before her as she walks to her stalk).
func pushing_out() -> bool:
	return pushing and barrow_out != null and barrow == barrow_out and kind == ""
