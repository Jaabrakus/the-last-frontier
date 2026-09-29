class_name BabyLink
extends Node
## The node side of the baby (BabyCare: needs and holders; BabyHold: the hold poses; BabyModel: the bundle). A child of Household
## (Household.baby). It keeps the newest carried child of Household.family as a body in the world: in the arms of whoever holds it
## (the NPC parent, or the player), or in a cradle or bed; lets the needs run on the game clock; and plays the mother's care: she
## carries it home and following, sits to feed it (a modest clothed cradle hold under a shawl), kneels to change the wrappings,
## rocks it when it cries, burps it over the shoulder, and lays it in the cradle when she goes to work or sleeps (a cradle or, failing
## one, a bed), taking it up again when it wakes and wants her. The player can be handed the baby (Talk tab or E on the baby; both
## hands must be free: the weapon is put away through FrontierPlayer.toggle_hands_free() when there is one) and give it back.
##   Household.baby.ask_for_baby() / give_back() / lay_down() / feed_by_player() ...   (each returns a line, "" when nothing)
##   Household.baby.info() -> {id, name, age, state, holder, mood, ...} for the screen ({} without a baby)
## Only one child has a body (the newest of the newborn and infant stages); the other records keep their needs but nobody tends them.

const GROUP := &"baby_link"
## The baby's spot on a bed (the bed's frame): by its edge, within an arm's reach of someone standing beside it.
const BED_SPOT := Vector3(0.25, 0.62, 0.0)

var house: Household
var care := BabyCare.new()
var focus := ""
var baby: BabyModel
var touch: Node3D
var rigs := {}                ## "spouse" / "player" -> BabyHold
## The visual change of hands: {from, to, t, dur, swapped, snap, point}.
var tx := {}
## The mother's errand: {steps: [], i: 0, st: {}}. Empty when she has none.
var errand := {}
var last_line := ""
## Whether the last ask_for_baby / give_back / lay_down / take_up went ahead (false: it was refused and the line says why).
var last_ok := false
var _last_min := -1.0
var _tick := 0.0
var _look_t := 0.0
var _pose_for := {}           ## holder -> the pose it should hold in
var _player_act := {}         ## what the player is doing with the baby now: {kind, t, dur}
var _want_hands := {}         ## a pending pick-up waiting for the weapon to be put away: {kind, t}
var _toggled := false         ## we put the player's weapon away (draw it again on the give-back)


static func find(tree: SceneTree) -> BabyLink:
	return tree.get_first_node_in_group(GROUP) as BabyLink if tree else null


func _ready() -> void:
	add_to_group(GROUP)


func _cfg(key: String, dflt: float) -> float:
	return float((BabyCare.cfg().get("care", {}) as Dictionary).get(key, dflt))


# ---------------------------------------------------------------- who and where
func _now() -> float:
	return house.sc.core.state.minutes if house != null and house.sc != null else 0.0


func _child(id: String) -> Dictionary:
	for c: Dictionary in house.family:
		if String(c.get("id", "")) == id:
			return c
	return {}


func state() -> Dictionary:
	return care.state(focus)


func _pick_focus() -> void:
	var best := ""
	var born := -1e30
	for c: Dictionary in house.family:
		if BabyCare.carried(c, _now()) and float(c.get("born_at", 0.0)) >= born:
			born = float(c.get("born_at", 0.0))
			best = String(c.id)
	focus = best


func _body() -> Spouse:
	return house.body if house != null and is_instance_valid(house.body) else null


func _player() -> FrontierPlayer:
	return house.player if house != null and is_instance_valid(house.player) else null


func _skeleton(who: String) -> Skeleton3D:
	if who == "spouse":
		var b := _body()
		return b.sk if b != null else null
	var p := _player()
	return p.skeleton if p != null else null


func rig(who: String) -> BabyHold:
	var sk := _skeleton(who)
	if sk == null or not is_instance_valid(sk):
		return null
	var r: Variant = rigs.get(who)
	if r is BabyHold and is_instance_valid(r) and (r as BabyHold).get_parent() == sk:
		return r
	var h := BabyHold.attach(sk)
	if h != null:
		rigs[who] = h
	return h


func _speed(who: String) -> float:
	if who == "spouse":
		var b := _body()
		return Vector2(b.velocity.x, b.velocity.z).length() if b != null else 0.0
	var p := _player()
	if p == null:
		return 0.0
	return float(p.call("horizontal_speed")) if p.has_method("horizontal_speed") else Vector2(p.velocity.x, p.velocity.z).length()


func _chest_world(who: String) -> Vector3:
	var sk := _skeleton(who)
	if sk == null:
		return Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spined")).origin


## The cradle or bed the baby would be laid in: {node (the piece), kind, mount (Node3D or null)}, nearest home.
func place() -> Dictionary:
	var best := {}
	var bd := float(BabyCare.cfg().get("care", {}).get("cradle_search_m", 40.0))
	for n in get_tree().get_nodes_in_group(Cradle.GROUP):
		var c := n as Cradle
		if c == null or not c.is_inside_tree():
			continue
		var d := c.global_position.distance_to(house.home)
		if d < bd:
			bd = d
			best = {"node": c, "kind": "cradle", "mount": c.mount()}
	if not best.is_empty():
		return best
	for n in get_tree().get_nodes_in_group(&"camp_stations"):
		var s := n as Node3D
		if s == null or String(s.get("kind")) not in CampStation.BEDS:
			continue
		var d := s.global_position.distance_to(house.home)
		if d < bd:
			bd = d
			best = {"node": s, "kind": "bed", "mount": null}
	return best


func _place_point(pl: Dictionary) -> Vector3:
	if pl.is_empty():
		return Vector3.ZERO
	if pl.kind == "cradle":
		return (pl.node as Cradle).baby_point()
	return (pl.node as Node3D).global_transform * BED_SPOT


## Where she stands to reach it: beside the cradle (the side toward `from`), or at a bed's edge by the baby's spot.
func _stand_point(pl: Dictionary, from: Vector3) -> Vector3:
	var n := pl.node as Node3D
	var x := n.global_transform.basis.x
	x.y = 0.0
	x = x.normalized()
	var stand := float((BabyCare.cfg().get("cradle", {}) as Dictionary).get("stand_m", 0.6))
	if pl.kind == "bed":
		return n.global_position + x * (BED_SPOT.x + stand)
	var side := 1.0 if (from - n.global_position).dot(x) >= 0.0 else -1.0
	return n.global_position + x * side * stand


func baby_world() -> Vector3:
	return baby.global_position if baby != null and baby.is_inside_tree() else Vector3.ZERO


# ---------------------------------------------------------------- the frame
func _process(dt: float) -> void:
	if house == null or house.sc == null or house.bridge == null or house.bridge.core == null:
		return
	care.sync(house.family)
	_pick_focus()
	if focus == "":
		_clear_body()
		return
	if care.holder_of(focus) == "":
		care.holders[focus] = "spouse"
	_ensure_body()
	var now := _now()
	var dm := 0.0
	if _last_min >= 0.0:
		dm = clampf(now - _last_min, 0.0, 240.0)
	_last_min = now
	if dm > 0.0:
		care.tick(dm, house.family, now)
		for c: Dictionary in house.family:
			if String(c.get("kind", "")) == "spouse" and BabyCare.nursing_now(c, now):
				BabyCare.nursing_burn(house.sc.core, dm)
			elif String(c.get("kind", "")) == "player" and BabyCare.nursing_now(c, now):
				BabyCare.nursing_burn(house.bridge.core, dm)
	_drain_events()
	_player_watch(dt)
	_place_baby(dt)
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = 0.2
		_look()
	_tick -= dt
	if _tick <= 0.0 and not get_tree().paused:
		_tick = _cfg("tick_s", 0.5)
		_plan()
	_rig_life(dt)


func _clear_body() -> void:
	if baby != null and is_instance_valid(baby):
		baby.queue_free()
		baby = null
	if touch != null and is_instance_valid(touch):
		touch.queue_free()
		touch = null
	_stop_errand()
	for r: Variant in rigs.values():
		if r is BabyHold and is_instance_valid(r):
			(r as BabyHold).release()


func _ensure_body() -> void:
	if baby != null and is_instance_valid(baby) and String(baby.child.get("id", "")) == focus:
		return
	if baby != null and is_instance_valid(baby):
		baby.queue_free()
	var c := _child(focus)
	var mels := [_melanin(house.sc.look), _melanin(_player_look())]
	baby = BabyModel.create(c, mels, float(BabyCare.stage_row(BabyCare.age_days(c, _now())).get("size", 1.0)))
	add_child(baby)
	if touch == null or not is_instance_valid(touch):
		touch = Touch.new()
		(touch as Touch).link = self
		touch.name = "BabyTouch"
		add_child(touch)


static func _melanin(look: Dictionary) -> float:
	return float(look.get("melanin", 0.3))


func _player_look() -> Dictionary:
	var p := _player()
	if p != null and p.appearance != null:
		return p.appearance.look
	return AppearanceStore.load_current()


## The look and the sound hook, from the needs.
func _look() -> void:
	if baby == null or not is_instance_valid(baby):
		return
	var s := state()
	var feeding := _pose_of(care.holder_of(focus)) == "feed"
	baby.set_state(BabyCare.mood(s), BabyCare.cry_level(s), bool(s.asleep), feeding)
	baby.visible = true


# ---------------------------------------------------------------- where the baby is
func _pose_of(who: String) -> String:
	return String(_pose_for.get(who, "cradle"))


func _place_baby(dt: float) -> void:
	if baby == null or not is_instance_valid(baby):
		return
	if not tx.is_empty():
		_tx_step(dt)
		return
	var who := care.holder_of(focus)
	var goal := Transform3D.IDENTITY
	var parent: Node = null
	if BabyCare.PEOPLE.has(who):
		var r := rig(who)
		if r == null:
			# no body to hold it (yet): parked with the link
			parent = self
		else:
			parent = r.hold
			if not r.engaged():
				r.engage(_pose_of(who), 1.0, true)
			elif r.pose_name != _pose_of(who):
				r.set_pose(_pose_of(who))
	else:
		var pl := place()
		if pl.is_empty():
			# the piece is gone: back in her arms
			care.holders[focus] = "spouse"
			return
		if pl.kind == "cradle":
			parent = (pl.node as Cradle).mount()
		else:
			var bnode := (pl.node as Node3D).get_node_or_null("BabyBed") as Node3D
			if bnode == null:
				bnode = Node3D.new()
				bnode.name = "BabyBed"
				bnode.position = BED_SPOT
				(pl.node as Node3D).add_child(bnode)
			parent = bnode
			goal = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
		for k: String in rigs:
			var rg: BabyHold = rigs[k]
			if is_instance_valid(rg) and rg.engaged() and not (errand.has("steps") or not tx.is_empty()):
				rg.release()
	if parent == null:
		return
	if baby.get_parent() != parent:
		if baby.get_parent() != null:
			baby.reparent(parent, false)
		else:
			parent.add_child(baby)
		baby.transform = goal
	else:
		baby.transform = baby.transform.interpolate_with(goal, clampf(dt * 10.0, 0.0, 1.0))


func _rig_life(_dt: float) -> void:
	for who: String in ["spouse", "player"]:
		var r: Variant = rigs.get(who)
		if not (r is BabyHold) or not is_instance_valid(r):
			continue
		var h := r as BabyHold
		h.speed = _speed(who)
		if who == "spouse":
			h.rocking = errand.has("steps") and String(errand.st.get("rock", "")) == "on"
		else:
			h.rocking = String(_player_act.get("kind", "")) == "rock"


## Drops the rigs of anyone not holding it now (after a change of hands the giver lets go).
func _release_others() -> void:
	var who := care.holder_of(focus)
	for k: String in rigs:
		var r: BabyHold = rigs[k]
		if is_instance_valid(r) and k != who and r.engaged():
			r.release()


# ---------------------------------------------------------------- changing hands (the visual)
func _drain_events() -> void:
	for e: Dictionary in care.pop_events():
		if String(e.id) != focus or baby == null or not is_instance_valid(baby):
			continue
		_begin_tx(String(e.from), String(e.to))


func _begin_tx(from: String, to: String) -> void:
	var dur := _cfg("hand_over_s", 1.1)
	if BabyCare.PLACES.has(from) or BabyCare.PLACES.has(to):
		dur = _cfg("lay_s", 1.0)
	var pl := place()
	var far := false
	if BabyCare.PEOPLE.has(from) and BabyCare.PEOPLE.has(to):
		far = _chest_world(from).distance_to(_chest_world(to)) > 3.0
	tx = {"from": from, "to": to, "t": 0.0, "dur": dur, "swapped": false, "snap": far, "pl": pl}
	for who: String in [from, to]:
		if BabyCare.PEOPLE.has(who):
			var r := rig(who)
			if r != null and not r.engaged():
				r.engage("reach" if not far else _pose_of(who), 1.0, far)
	if far:
		tx["dur"] = 0.05


func _tx_point() -> Vector3:
	var pl: Dictionary = tx.get("pl", {})
	if BabyCare.PLACES.has(String(tx.from)) or BabyCare.PLACES.has(String(tx.to)):
		return _place_point(pl)
	var a := _chest_world(String(tx.from))
	var b := _chest_world(String(tx.to))
	var m := (a + b) * 0.5
	m.y = minf(a.y, b.y) - 0.2
	return m


func _tx_step(dt: float) -> void:
	tx["t"] = float(tx.t) + dt
	var from := String(tx.from)
	var to := String(tx.to)
	var dur := float(tx.dur)
	var frac := float(tx.t) / maxf(dur, 0.01)
	var pt := _tx_point()
	for who: String in [from, to]:
		if BabyCare.PEOPLE.has(who) and not bool(tx.snap):
			var r := rig(who)
			if r != null:
				r.reach_to(pt)
	if frac >= 0.45 and not bool(tx.swapped):
		tx["swapped"] = true
		var parent: Node = null
		if BabyCare.PEOPLE.has(to):
			var rt := rig(to)
			parent = rt.hold if rt != null else self
			_pose_for[to] = "cradle"
		else:
			var pl: Dictionary = tx.pl
			if not pl.is_empty():
				parent = (pl.node as Cradle).mount() if pl.kind == "cradle" else (pl.node as Node3D).get_node_or_null("BabyBed")
		if parent != null:
			baby.reparent(parent, true)
	if frac >= 1.0:
		var fin_to := to
		tx = {}
		if BabyCare.PEOPLE.has(fin_to):
			var r := rig(fin_to)
			if r != null:
				r.set_pose(_pose_of(fin_to))
		_release_others()


# ---------------------------------------------------------------- the player and the baby
func _hands_free() -> bool:
	var p := _player()
	return p != null and p.get("hands_free") == true


## Puts the weapon away if there is one in hand (FrontierPlayer.toggle_hands_free: the same as H). True when the hands are free now.
func _free_hands() -> bool:
	var p := _player()
	if p == null:
		return false
	if _hands_free():
		return true
	if p.has_method("toggle_hands_free"):
		p.call("toggle_hands_free")
		_toggled = true
	return _hands_free()


func _player_ctx(from_holder: String) -> Dictionary:
	var p := _player()
	var near := false
	if p != null:
		var who_pos := _chest_world(from_holder) if BabyCare.PEOPLE.has(from_holder) else _place_point(place())
		near = p.global_position.distance_to(who_pos) < 2.6
	return {"near": near, "hands": _hands_free(), "dead": p == null or p.is_dead}


func _player_watch(dt: float) -> void:
	var p := _player()
	if p == null:
		return
	# a pick-up waiting for the weapon to go away
	if not _want_hands.is_empty():
		_want_hands["t"] = float(_want_hands.t) + dt
		if _hands_free():
			var k := String(_want_hands.kind)
			_want_hands = {}
			_finish_take(k)
		elif float(_want_hands.t) > 2.0:
			_want_hands = {}
			_say(_refuse("hands"))
	if care.holder_of(focus) == "player":
		# both hands are needed: a weapon drawn, a fall, a horse or death and the baby goes to her
		var bad := p.is_dead or p.get("riding") != null or not _hands_free()
		if bad and tx.is_empty():
			_hand_back_now("hands")
		elif not _player_act.is_empty():
			_player_act["t"] = float(_player_act.t) + dt
			if float(_player_act.t) >= float(_player_act.dur):
				_finish_act()
	elif not _player_act.is_empty():
		_player_act = {}
		_pose_for.erase("player")


func _hand_back_now(_why: String) -> void:
	if care.holder_of(focus) != "player":
		return
	_player_act = {}
	_pose_for.erase("player")
	care.take(focus, "spouse", {"near": true})
	_after_return()


## The weapon comes back out if we put it away for the baby.
func _after_return() -> void:
	var p := _player()
	if _toggled and p != null and _hands_free() and p.has_method("toggle_hands_free") and care.holder_of(focus) != "player":
		p.call("toggle_hands_free")
	if care.holder_of(focus) != "player":
		_toggled = false


func _refuse(reason: String) -> String:
	return BabyCare.line(["refuse", reason])


func _say(text: String) -> void:
	if text == "":
		return
	last_line = text
	var p := _player()
	if p != null and p.hud != null:
		p.hud.toast(text)
	else:
		print(text)


func _spouse_says(path: Array) -> String:
	var c := _child(focus)
	var t := BabyCare.line(path).replace("{name}", String(c.get("name", "the baby")))
	if t != "":
		t = "%s: \"%s\"" % [house.sc.name, t]
	return t


## The player's asking for the baby: the NPC parent comes and hands it over (both hands must be free). Returns the line.
func ask_for_baby() -> String:
	last_ok = false
	if focus == "":
		return ""
	var who := care.holder_of(focus)
	if who == "player":
		return _refuse("held")
	if BabyCare.PEOPLE.has(who) and (errand.has("steps") and _errand_busy()):
		return _refuse("busy")
	var r := care.can_take(focus, "player", {"near": true, "hands": true, "dead": _player() == null or _player().is_dead})
	if not bool(r.ok):
		return _refuse(String(r.reason))
	# the wife walks to the player, then the handover
	_start_errand([{"do": "walk", "to": "player"}, {"do": "give_player"}])
	last_ok = true
	return _spouse_says(["hand_over"])


## E on the baby in a cradle or bed: the player takes it up.
func take_up() -> String:
	last_ok = false
	if focus == "" or not BabyCare.PLACES.has(care.holder_of(focus)):
		return ""
	var r := care.can_take(focus, "player", _player_ctx(care.holder_of(focus)))
	if not bool(r.ok):
		if String(r.reason) == "hands":
			return _begin_hands("take_up")
		return _refuse(String(r.reason))
	_finish_take("take_up")
	last_ok = true
	return ""


func _begin_hands(kind: String) -> String:
	if _free_hands():
		_finish_take(kind)
		return ""
	_want_hands = {"kind": kind, "t": 0.0}
	last_ok = true
	return ""


func _finish_take(_kind: String) -> void:
	var r := care.take(focus, "player", {"near": true, "hands": true, "dead": false})
	if bool(r.ok):
		_pose_for["player"] = "cradle"


## The player gives the baby back: she comes and takes it.
func give_back() -> String:
	last_ok = false
	if focus == "" or care.holder_of(focus) != "player":
		return ""
	_player_act = {}
	_start_errand([{"do": "walk", "to": "player"}, {"do": "receive"}])
	last_ok = true
	return _spouse_says(["take_back"])


## The player lays the baby in the cradle or bed nearby.
func lay_down() -> String:
	last_ok = false
	if focus == "" or care.holder_of(focus) != "player":
		return ""
	var pl := place()
	if pl.is_empty():
		return "There is nowhere to lay the baby: a cradle, or a bed."
	var p := _player()
	if p.global_position.distance_to(_place_point(pl)) > 1.9:
		return "Come closer to the %s." % String(pl.kind)
	_player_act = {}
	var r := care.lay_down(focus, String(pl.kind), {"places": [pl.kind]})
	_after_return()
	last_ok = bool(r.ok)
	return _spouse_says(["lay"]) if bool(r.ok) else ""


## The player does a bit of care with the baby in arms: "rock", "feed" (the mother only), "change", "burp".
func player_care(kind: String) -> String:
	if focus == "" or care.holder_of(focus) != "player" or not _player_act.is_empty():
		return ""
	var d := {"rock": 5.0, "feed": 7.0, "change": 3.5, "burp": 4.0}
	if not d.has(kind):
		return ""
	if kind == "feed" and not player_is_mother():
		return ""
	_player_act = {"kind": kind, "t": 0.0, "dur": float(d[kind])}
	match kind:
		"feed":
			_pose_for["player"] = "feed"
		"burp":
			_pose_for["player"] = "shoulder"
		_:
			_pose_for["player"] = "cradle"
	return ""


func player_is_mother() -> bool:
	var c := _child(focus)
	return String(c.get("kind", "")) == "player"


func _finish_act() -> void:
	var s := state()
	match String(_player_act.kind):
		"rock":
			BabyCare.soothe(s, 0.8)
		"feed":
			BabyCare.feed(s)
			BabyCare.take_kcal(house.bridge.core, BabyCare.per_feed_kcal())
		"change":
			BabyCare.change(s)
		"burp":
			BabyCare.soothe(s, 0.3)
	_player_act = {}
	_pose_for["player"] = "cradle"


# ---------------------------------------------------------------- E on the baby, the cradle
func _name() -> String:
	return String(_child(focus).get("name", "the baby"))


func prompt() -> String:
	if focus == "":
		return ""
	var who := care.holder_of(focus)
	if who == "spouse":
		return "Ask %s for %s" % [house.sc.name, _name()]
	if who == "player":
		return "%s: give back" % _name()
	return "Pick up %s" % _name()


func actions() -> Array:
	var out := []
	if focus == "":
		return out
	var who := care.holder_of(focus)
	if who == "spouse":
		out.append({"id": "ask", "text": "Ask %s for %s" % [house.sc.name, _name()]})
	elif who == "player":
		out.append({"id": "give_back", "text": "Give %s back to %s" % [_name(), house.sc.name]})
		if not place().is_empty():
			out.append({"id": "lay", "text": "Lay %s down" % _name()})
		out.append({"id": "rock", "text": "Rock %s" % _name()})
		out.append({"id": "burp", "text": "Hold %s over your shoulder" % _name()})
		out.append({"id": "change", "text": "Change the wrappings"})
		if player_is_mother():
			out.append({"id": "feed", "text": "Feed %s" % _name()})
	else:
		out.append({"id": "take_up", "text": "Pick up %s" % _name()})
	return out


func do_action(id: String) -> void:
	var line := ""
	match id:
		"ask":
			line = ask_for_baby()
		"take_up":
			line = take_up()
		"give_back":
			line = give_back()
		"lay":
			line = lay_down()
		"rock", "burp", "change", "feed":
			line = player_care(id)
	_say(line)


func interact_default() -> void:
	var a := actions()
	if not a.is_empty():
		do_action(String(a[0].id))


## The cradle's E: the player with the baby lays it in; otherwise the baby in this cradle is taken up.
func cradle_action(cradle: Cradle) -> String:
	if focus == "":
		return ""
	var who := care.holder_of(focus)
	if who == "player":
		return lay_down()
	if who == "cradle" and place().get("node") == cradle:
		return take_up()
	return ""


func cradle_prompt(cradle: Cradle) -> String:
	if focus == "":
		return ""
	var who := care.holder_of(focus)
	if who == "player":
		return "Lay %s in the cradle" % _name()
	if who == "cradle" and place().get("node") == cradle:
		return "Pick up %s" % _name()
	return ""


# ---------------------------------------------------------------- what the screen shows
func info() -> Dictionary:
	if focus == "":
		return {}
	var c := _child(focus)
	var s := state()
	var who := care.holder_of(focus)
	var holder_name := house.sc.name if who == "spouse" else "you" if who == "player" else "the %s" % who
	return {"id": focus, "name": String(c.get("name", "")), "age": Pregnancy.age_text(c, _now()),
			"girl": float(c.get("sex", 0.0)) < 0.5, "state": s, "holder": who, "holder_name": holder_name,
			"mood": BabyCare.mood(s), "status": BabyCare.status_text(s), "content": 1.0 - BabyCare.distress(s),
			"hunger": float(s.hunger), "has_place": not place().is_empty(), "player_mother": player_is_mother()}


func save_data() -> Dictionary:
	return care.to_dict()


func load_data(d: Variant) -> void:
	tx = {}
	errand = {}
	_player_act = {}
	care.load_dict(d, house.family if house != null else [])
	for r: Variant in rigs.values():
		if r is BabyHold and is_instance_valid(r):
			(r as BabyHold).release()


# ---------------------------------------------------------------- the mother's errands
func _plan() -> void:
	var b := _body()
	if b == null or focus == "" or errand.has("steps") or not tx.is_empty() or house.screen != null:
		return
	if house.link != null and house.link.following():
		return   # a yoga session has her
	var who := care.holder_of(focus)
	var sc := house.sc
	var busy := sc.busy() or not b._plan.is_empty() or not sc.awake() or sc.role == "outside" or sc.core.is_dead()
	var s := state()
	var ctx := {"holder": who, "can_feed": String(_child(focus).get("kind", "")) == "spouse",
			"free": not busy, "busy": busy, "has_place": not place().is_empty()}
	var steps := BabyCare.plan(s, ctx)
	if steps.is_empty():
		return
	_start_errand(steps)


func _start_errand(steps: Array) -> void:
	var b := _body()
	if b == null:
		return
	errand = {"steps": steps, "i": 0, "st": {}}
	b.errand = Callable(self, "_errand_move")


func _stop_errand() -> void:
	if errand.has("steps") and bool(errand.get("task", false)):
		house.sc.cancel("care done")
	errand = {}
	_pose_for.erase("spouse")
	var b := _body()
	if b != null:
		b.idle_clip = ""
		b.errand = Callable()


func _errand_busy() -> bool:
	# mid-feed / mid-change: she cannot hand it over now
	if not errand.has("steps"):
		return false
	var i := int(errand.i)
	var st: Array = errand.steps
	return i < st.size() and String((st[i] as Dictionary).do) in ["care", "sit"]


func _next_step() -> void:
	errand["i"] = int(errand.i) + 1
	errand["st"] = {}
	if int(errand.i) >= (errand.steps as Array).size():
		_stop_errand()


func _cur() -> Dictionary:
	var i := int(errand.i)
	var st: Array = errand.steps
	return st[i] if i < st.size() else {}


## Called by Spouse each physics frame while she has an errand: [direction, speed], or null to let her do as she does.
func _errand_move(dt: float) -> Variant:
	var b := _body()
	if b == null or not errand.has("steps"):
		return null
	var step := _cur()
	if step.is_empty():
		return null
	var st: Dictionary = errand.st
	st["t"] = float(st.get("t", 0.0)) + dt
	match String(step.do):
		"walk":
			var target := Vector3.ZERO
			if String(step.to) == "player":
				var p := _player()
				if p == null:
					_next_step()
					return [Vector3.ZERO, 0.0]
				var away := b.global_position - p.global_position
				away.y = 0.0
				target = p.global_position + (away.normalized() if away.length() > 0.1 else Vector3.BACK) * 1.05
			else:
				var pl := place()
				if pl.is_empty():
					_next_step()
					return [Vector3.ZERO, 0.0]
				target = _stand_point(pl, b.global_position)
			var to := target - b.global_position
			to.y = 0.0
			if to.length() < 0.55 or b._stuck_t > 3.0 or float(st.t) > 25.0:
				b._stuck_t = 0.0
				_next_step()
				return [Vector3.ZERO, 0.0]
			return [to.normalized(), Spouse.WALK_SPEED * (1.6 if to.length() > 8.0 else 1.0)]
		"take":
			if not st.has("started"):
				st["started"] = true
				var pl := place()
				if not BabyCare.PLACES.has(care.holder_of(focus)) or pl.is_empty():
					_next_step()
					return [Vector3.ZERO, 0.0]
				_face_point(b, _place_point(pl))
				care.take(focus, "spouse", {"near": true})
				_say(_spouse_says(["take_up"]))
			elif tx.is_empty():
				_next_step()
			return [Vector3.ZERO, 0.0]
		"lay":
			if not st.has("started"):
				st["started"] = true
				var pl := place()
				if care.holder_of(focus) != "spouse" or pl.is_empty():
					_next_step()
					return [Vector3.ZERO, 0.0]
				_face_point(b, _place_point(pl))
				care.lay_down(focus, String(pl.kind), {"places": [pl.kind]})
			elif tx.is_empty():
				_next_step()
			return [Vector3.ZERO, 0.0]
		"give_player":
			if not st.has("started"):
				st["started"] = true
				_face_point(b, _player().global_position)
				# both hands free first (the weapon away), then across
				if not _free_hands():
					st["wait"] = 0.0
				else:
					care.take(focus, "player", {"near": true, "hands": true})
					_pose_for["player"] = "cradle"
			elif st.has("wait"):
				st["wait"] = float(st.wait) + dt
				if _hands_free():
					st.erase("wait")
					care.take(focus, "player", {"near": true, "hands": true})
					_pose_for["player"] = "cradle"
				elif float(st.wait) > 2.0:
					_say(_refuse("hands"))
					_stop_errand()
			elif tx.is_empty():
				_next_step()
			return [Vector3.ZERO, 0.0]
		"receive":
			if not st.has("started"):
				st["started"] = true
				_face_point(b, _player().global_position)
				_player_act = {}
				care.take(focus, "spouse", {"near": true})
			elif tx.is_empty():
				_after_return()
				_next_step()
			return [Vector3.ZERO, 0.0]
		"sit":
			return _step_sit(b, step, st, dt)
		"care":
			return _step_care(b, step, st)
		"stand":
			return _step_stand(b, st)
		"rock":
			return _step_timed(b, step, st, "rock")
		"burp":
			return _step_timed(b, step, st, "burp")
	_next_step()
	return [Vector3.ZERO, 0.0]


func _face_point(b: Spouse, p: Vector3) -> void:
	var to := p - b.global_position
	if Vector2(to.x, to.z).length() > 0.05:
		b._face = atan2(-to.x, -to.z)


func _clips(kind: String) -> Dictionary:
	return (BabyCare.cfg().get("care", {}) as Dictionary).get("sit_clips" if kind == "sit" else "kneel_clips", {})


func _loop_mode(b: Spouse, clip: String) -> void:
	var full := "%s/%s" % [Spouse.LIB, clip]
	if b.ap != null and b.ap.has_animation(full):
		b.ap.get_animation(full).loop_mode = Animation.LOOP_LINEAR


func _step_sit(b: Spouse, step: Dictionary, st: Dictionary, _dt: float) -> Array:
	var clips := _clips(String(step.kind))
	if not st.has("started"):
		st["started"] = true
		_loop_mode(b, String(clips.get("loop", "")))
		b.idle_clip = String(clips.get("in", ""))
		b._play_work(String(clips.get("in", "")))
		_pose_for["spouse"] = "feed" if String(step.kind) == "sit" else "cradle"
		house.sc.task = "feed_baby" if String(step.kind) == "sit" else "change_baby"
		house.sc.task_text = ("Feeding %s" if String(step.kind) == "sit" else "Changing %s") % _name()
		errand["task"] = true
		if String(step.kind) == "sit":
			_say(_spouse_says(["feed"]))
		else:
			_say(_spouse_says(["change"]))
	elif float(st.t) >= minf(b._len(String(clips.get("in", ""))), 2.5):
		b.idle_clip = String(clips.get("loop", ""))
		_next_step()
	return [Vector3.ZERO, 0.0]


func _step_care(b: Spouse, step: Dictionary, st: Dictionary) -> Array:
	var s := state()
	if not st.has("elapsed"):
		st["elapsed"] = 0.0
		st["last"] = _now()
	var dm := maxf(_now() - float(st.get("last", _now())), 0.0)
	st["last"] = _now()
	st["elapsed"] = float(st.elapsed) + dm
	var total := maxf(float(step.minutes), 0.1)
	if String(step.what) == "feed":
		s["hunger"] = maxf(float(s.hunger) - dm / total * maxf(float(BabyCare.needs_cfg().get("feed_fill", 1.0)), 0.1) * 1.05, 0.0)
	if float(st.elapsed) >= total:
		if String(step.what) == "feed":
			BabyCare.feed(s, 0.0)   # the count and the settling (the hunger has gone down as she fed)
			BabyCare.take_kcal(house.sc.core, BabyCare.per_feed_kcal())
			_say(_spouse_says(["feed_done"]))
			s["tired"] = minf(float(s.tired) + 0.1, 1.0)
		else:
			BabyCare.change(s)
		_next_step()
	return [Vector3.ZERO, 0.0]


func _step_stand(b: Spouse, st: Dictionary) -> Array:
	var kneel := b.idle_clip.contains("search-low")   # (the data now sits her for both: the kneeling clip folds the torso flat)
	var clips := _clips("kneel" if kneel else "sit")
	if not st.has("started"):
		st["started"] = true
		if b.idle_clip != "":
			b._play_work(String(clips.get("out", "")))
			b.idle_clip = String(clips.get("out", ""))
		_pose_for["spouse"] = "cradle"
	elif float(st.t) >= minf(b._len(String(clips.get("out", ""))), 1.6) or b.idle_clip == "":
		b.idle_clip = ""
		if bool(errand.get("task", false)):
			house.sc.cancel("care done")
			errand["task"] = false
		_next_step()
	return [Vector3.ZERO, 0.0]


func _step_timed(b: Spouse, step: Dictionary, st: Dictionary, what: String) -> Array:
	if not st.has("started"):
		st["started"] = true
		st["last"] = _now()
		st["elapsed"] = 0.0
		if what == "rock":
			st["rock"] = "on"
			_pose_for["spouse"] = "cradle"
			_say(_spouse_says(["soothe"]))
		else:
			_pose_for["spouse"] = "shoulder"
		if _player() != null and what == "rock":
			_face_point(b, _player().global_position)
	var s := state()
	var dm := maxf(_now() - float(st.last), 0.0)
	st["last"] = _now()
	st["elapsed"] = float(st.elapsed) + dm
	var total := maxf(float(step.minutes), 0.1)
	if what == "rock":
		s["upset"] = maxf(float(s.upset) - dm / total * float(BabyCare.needs_cfg().get("soothe_relief", 0.7)) * 1.1, 0.0)
	if float(st.elapsed) >= total:
		if what == "rock":
			BabyCare.soothe(s, 0.3)
		else:
			BabyCare.soothe(s, 0.2)
		_pose_for["spouse"] = "cradle"
		_next_step()
	return [Vector3.ZERO, 0.0]


## The inner E target that follows the baby.
class Touch extends Node3D:
	var link: BabyLink
	var interact_reach := 2.6

	func _ready() -> void:
		add_to_group(PlacedWeapon.GROUP)

	func _process(_dt: float) -> void:
		if link != null and link.baby != null and is_instance_valid(link.baby) and link.baby.is_inside_tree():
			global_position = link.baby.global_position

	func interact_point() -> Vector3:
		return global_position

	func distance_from(p: Vector3) -> float:
		return p.distance_to(global_position)

	func interact_prompt(_p: Node) -> String:
		return link.prompt() if link != null else ""

	func interact(_p: Node) -> void:
		if link != null:
			link.interact_default()

	func interact_actions(_p: Node) -> Array:
		return link.actions() if link != null else []

	func interact_action(_p: Node, id: String) -> void:
		if link != null:
			link.do_action(id)
