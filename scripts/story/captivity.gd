class_name Captivity
extends Node
## Taken captive (docs/research/codebase_story_audit.md item 6: the Prologue ends with the player taken after the 1757 raid,
## and later missions want the same): the captors take the gear into a held store, the player goes bound (walking only),
## follows a captor on a leash, perhaps on a forced march, and may break away. The store comes back at the end, all of it
## or part of it.
##
##   var c := Captivity.install(level)
##   c.begin(player, captor, {"route": [a, b, c], "march_hours": 10.0})
##   c.escaped.connect(_on_escape)        # the leash broken past escape_m (or by break_free())
##   c.end()                              # everything back; end(false) keeps it; end(true, ["pack", "coin"]) only those
##
## What is taken (opts "take", every part by default), each part held as it was so it comes back as it went:
##   weapons   every weapon carried (FrontierPlayer.carried false: is_usable() is false, so no key, H or the wheel
##             draws one), the loadout's weapon items, the quiver and the powder horn and shot pouch straps
##             (BareStart.KIT_GEAR) off the body, and the weapons' own entries in the pack (their state). Each weapon
##             keeps its charge and spare rounds while it is held.
##   tools     the tool loop's tool (the felling axe) off the body
##   pack      the things in the pack (inventory_pack), the tools in it too
##   torches   the torches in the pack and the one in the hand (put out first)
##   coin      the survival core's coin (SurvivalEconomy; none taken from a debt)
##   kit       the survival core's own kit (its stacks), less the clothes worn: the captive keeps what they wear (as many
##             of each as are worn; the spares go)
## While the pack or the tools are held, GatherTools.lost names every tool that is handed out again on its own, so none
## comes back from nowhere. A kind's mark comes off when that tool is back (on the loop or in the pack); one the captors
## keep (end(false), a part still held at the end, the pack left in a PackDrop) stays lost as a tool lost anywhere is,
## until it is found (or the next load, which hands every tool out again).
##
## Bound (until end(), or an escape with opts "unbind_on_escape", the default): no weapon drawn and no tool in the hands
## (one picked up and drawn is put away again); the hands hold nothing that carries the body or a load: off a horse (one
## mounted or caught wild, down again at once), out of a boat, a wheelbarrow set down, a carcass or a log let go (begin()
## also lets go of a grip and wakes a sleeper); no building (BuildMode does not run, so B does nothing) and no command
## mode (RtsMode takes no input, so F1 does nothing); and a walk: FrontierPlayer.drag_speed_cap at the walking pace (opts
## "speed", walk_speed by default), which also rules out the sprint. A lower cap stands (the river's wading pace is
## taken in here: RiverWater sets the cap only when no one else holds it). Captivity's physics runs after every other
## node's (PHYSICS_PRIORITY), so the cap is the frame's last word.
##
## The captor (any Node3D; opts or follow()): the player is to stay within leash_m of it. Further off, the captor waits
## and looks back ("waiting"); past turn_back_m it walks back toward the player at turn_back_speed until they are close
## again ("turning_back"): opts "turn_back_speed", by default TURN_BACK_SHARE of the walking cap, under it, so a captive
## who walks away on purpose gains on it, slowly; past escape_m the leash is broken: `escaped`. break_free() breaks it at
## once (a story's beat: the captors asleep, a rope cut). A captor that walks itself has captive_lead(to: Vector3,
## speed: float, delta: float) and captive_wait(face: Vector3) (asked to stand whenever it is not leading); any other node
## (a stand-in) is moved here, on the ground. A captor gone (freed) or none after a load: see below.
##
## The forced march (opts "route", or march()): the captor leads along the route's points at captor_speed while the
## player keeps up, and waits when they do not. Without a captor the player walks the route (each point reached within
## ARRIVE_M). Each metre of the route the lead covers moves the survival clock on by the route's share of march_hours
## (or march_min_per_m), so a day's march passes in a few minutes of walking; hunger comes with the hours (the core's own
## needs), and hunger_mult burns that much more of the food over them (short rations). `march_done` at the last point.
##
## Death (opts "on_death"): `captive_died`, never `escaped`. "end" (the default): the captive wakes free where the game
## brings them back and the captors keep what they hold (end(false)); "keep": they wake still captive and the captor is
## put beside them.
##
## A save keeps it (SaveParts "captivity", after "player"): the store, the bonds, the leash's numbers, the route and how
## far along it the march is, the captor's node path (and its place when it is a stand-in moved here). A captor made at
## run time by a story is not in a save, nor are the connections to these signals: after a load Captivity emits
## `restored` and calls captivity_restored(c: Captivity) on every node in the group WATCHERS (deferred: a story's own
## part has loaded by then), for the story to make the captor again, follow() it and connect again. Without a captor
## (none after a load, or the one there was freed) the march, when one is left, is the player's to walk; with none left
## and still no captor after NO_CAPTOR_GRACE_S, nobody holds them and the bonds come off (the store stays held; a
## follow() puts them on again).

signal began
## The leash's state changed: "close", "waiting", "turning_back", "escaped", "no_captor".
signal leash_changed(state: String)
## The leash broken past escape_m, or by break_free() (where the player was).
signal escaped(at: Vector3)
## The forced march came to its last point.
signal march_done
## The captive died (with opts "on_death" "end", before `ended`).
signal captive_died
## Back from a save (see the header): the captor to make again, the signals to connect again.
signal restored
## The captivity is over; what was still held and not given back (the store's parts).
signal ended(left: Dictionary)

const GROUP := &"captivity"
## Nodes told after a load: captivity_restored(c: Captivity).
const WATCHERS := &"captivity_watchers"
## The store's parts.
const PARTS := ["weapons", "tools", "pack", "torches", "coin", "kit"]
## The parts named in the notice ("Your ... are gone"); those that take "is".
const ONE_THING := ["pack", "coin", "kit"]
const LEASH_M := 6.0
const TURN_BACK_M := 14.0
const ESCAPE_M := 40.0
## The captor's pace on the march (m/s): under the player's walking pace, so a captive who walks keeps up.
const CAPTOR_MPS := 1.25
## The captor's pace walking back for a captive who fell behind: at most this (m/s), and TURN_BACK_SHARE of the captive's
## walking cap (1.2 m/s at the walk: a captive walking away gains 0.4 m/s, from turn_back_m to escape_m at the defaults
## in a little over a minute).
const TURN_BACK_MPS := 1.6
const TURN_BACK_SHARE := 0.75
## A turning-back captor walks back until the captive is this share of leash_m away.
const TURN_BACK_STOP := 0.6
## A route point counts as reached within this (m): by the player, by a captor that walks itself (one moved here
## reaches it exactly).
const ARRIVE_M := 2.5
const CAPTOR_ARRIVE_M := 0.8
## The march's game minutes are given to the core in pieces at least this long.
const MIN_STEP := 1.0
## After every other node's physics (lower runs first): the walking cap is the frame's last word, and the leash reads
## where the player went this frame.
const PHYSICS_PRIORITY := 1000
## No captor (none after a load, or the one there was freed) and no march left: this long (s) for a story to follow()
## one before the bonds come off.
const NO_CAPTOR_GRACE_S := 3.0

var player: FrontierPlayer
var captor: Node3D
## A captor was set by follow() (and may since have been freed).
var _has_captor := false
var active := false
var bound := false
var has_escaped := false
## What is held, by part (PARTS): weapons {keys, items, gear, pack}, tools {items}, pack [...], torches [...], coin int,
## kit [...].
var store := {}
## The tool kinds this captivity marked lost in GatherTools (each taken off again when that tool is back).
var lost_marks: Array = []
var leash := "no_captor"
var leash_m := LEASH_M
var turn_back_m := TURN_BACK_M
var escape_m := ESCAPE_M
var speed_cap := 1.6
var captor_speed := CAPTOR_MPS
var turn_back_speed := TURN_BACK_MPS * TURN_BACK_SHARE
var unbind_on_escape := true
## "end" or "keep" (see the header).
var on_death := "end"
## The forced march: its points (on the ground), the next one, metres done to it, metres of the whole route the lead has
## covered (never less), game minutes per metre, extra hunger, minutes not yet given to the core.
var route: Array = []
var route_i := 0
var marching := false
var march_m := 0.0
var min_per_m := 0.0
var hunger_mult := 1.0
var _done_m := 0.0
## The first leg's length: from where the lead stood when the march began to the first point.
var _first_leg := 0.0
var _min_acc := 0.0
var _build_mode := Node.PROCESS_MODE_INHERIT
var _rts_input := true
## The walking cap this captivity last set (INF: none): only its own is lifted again.
var _my_cap := INF
## Dead and not yet back (the leash rests: where they wake is no escape).
var _dying := false
## Seconds without a captor or a march to walk (-1: not counting; see NO_CAPTOR_GRACE_S).
var _orphan_t := -1.0
## The bonds came off for want of a captor (a follow() puts them on again).
var _loosed := false


static func find(tree: SceneTree) -> Captivity:
	return tree.get_first_node_in_group(GROUP) as Captivity if tree else null


## The level's Captivity, made under `level` when there is none.
static func install(level: Node) -> Captivity:
	var c := find(level.get_tree()) if level.is_inside_tree() else null
	if c != null:
		return c
	c = Captivity.new()
	c.name = "Captivity"
	level.add_child(c)
	return c


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = PHYSICS_PRIORITY


func is_active() -> bool:
	return active


## Whether `part` (PARTS) is held now.
func holding(part: String) -> bool:
	return store.has(part)


# --- Taken ------------------------------------------------------------------------------------------------------

## The player taken: the gear into the store, bound, following `captor` (null: none yet). opts: take (parts), leash_m,
## turn_back_m, escape_m, speed (the walking cap), captor_speed, turn_back_speed, unbind_on_escape, on_death, route
## (points), march_hours, march_min_per_m, hunger_mult, notice (the line shown; "" none; by default it names the parts
## taken). False when already captive or there is no player (or a dead one).
func begin(p: FrontierPlayer, p_captor: Node3D = null, opts := {}) -> bool:
	if active or p == null or not is_instance_valid(p) or p.is_dead:
		return false
	player = p
	active = true
	has_escaped = false
	_dying = false
	_loosed = false
	_orphan_t = -1.0
	store = {}
	leash_m = float(opts.get("leash_m", LEASH_M))
	turn_back_m = maxf(float(opts.get("turn_back_m", TURN_BACK_M)), leash_m)
	escape_m = maxf(float(opts.get("escape_m", ESCAPE_M)), turn_back_m)
	speed_cap = float(opts.get("speed", p.walk_speed))
	captor_speed = float(opts.get("captor_speed", CAPTOR_MPS))
	turn_back_speed = float(opts.get("turn_back_speed", minf(TURN_BACK_MPS, speed_cap * TURN_BACK_SHARE)))
	unbind_on_escape = bool(opts.get("unbind_on_escape", true))
	on_death = String(opts.get("on_death", "end"))
	_let_go_holds(true)
	_empty_hands()
	var take: Array = opts.get("take", PARTS)
	var taken := []
	for part: String in PARTS:
		if part in take:
			_take(part)
			taken.append(part)
	_finish_body()
	_bind()
	_watch_player(true)
	follow(p_captor)
	var pts: Array = opts.get("route", [])
	if not pts.is_empty():
		march(pts, opts)
	var text := String(opts.get("notice", _notice_for(taken)))
	if text != "":
		_tell(text)
	began.emit()
	return true


## Sets the captor to follow (null: none; the bonds stay). A captor again after the bonds came off for want of one puts
## them back on.
func follow(p_captor: Node3D) -> void:
	captor = p_captor if p_captor != null and is_instance_valid(p_captor) else null
	_has_captor = captor != null
	if _has_captor:
		_orphan_t = -1.0
		if _loosed and active and not has_escaped:
			_loosed = false
			_bind()
	_set_leash("close" if _has_captor and not has_escaped else "no_captor")


## A forced march along `points` (Vector3s; put on the ground). opts: march_hours (the game hours the whole route stands
## for), march_min_per_m (instead), hunger_mult.
func march(points: Array, opts := {}) -> void:
	route = []
	for v in points:
		var q: Vector3 = v
		route.append(Vector3(q.x, FrontierTerrain.height_at(q.x, q.z), q.z))
	route_i = 0
	march_m = 0.0
	_done_m = 0.0
	_min_acc = 0.0
	hunger_mult = float(opts.get("hunger_mult", 1.0))
	var from := captor.global_position if _has_captor and is_instance_valid(captor) else (player.global_position if player else Vector3.ZERO)
	_first_leg = _flat(from, route[0]) if not route.is_empty() else 0.0
	var length := _first_leg
	for i in range(1, route.size()):
		length += _seg_length(i)
	min_per_m = float(opts.get("march_min_per_m", float(opts.get("march_hours", 0.0)) * 60.0 / length if length > 0.01 else 0.0))
	marching = not route.is_empty()


## The leash broken now, wherever the captor is (a story's beat: the captors asleep, the rope cut), as past escape_m.
## False when not captive or already away.
func break_free() -> bool:
	if not active or has_escaped or player == null or not is_instance_valid(player):
		return false
	_escape()
	return true


## "You are taken. Your weapons, your pack and your coin are gone." for the parts taken.
static func _notice_for(parts: Array) -> String:
	if parts.is_empty():
		return "You are taken."
	var names := PackedStringArray()
	for part: String in parts:
		names.append("your " + part)
	var list := names[0] if names.size() == 1 else ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]
	var verb := "is" if parts.size() == 1 and String(parts[0]) in ONE_THING else "are"
	return "You are taken. %s%s %s gone." % [list.substr(0, 1).to_upper(), list.substr(1), verb]


func _take(part: String) -> void:
	var p := player
	match part:
		"weapons":
			var keys := []
			for key: String in p.weapons.keys():
				if p.is_carried(key):
					keys.append(key)
					p.carried[key] = false
			var items := []
			var gear := []
			if p.loadout:
				for it: Dictionary in p.loadout.items.duplicate():
					if not _is_tool(String(it.kind)):
						items.append(it.duplicate(true))
						p.loadout.remove_item(String(it.id))
				for g: String in BareStart.KIT_GEAR:
					if g in p.loadout.gear:
						gear.append(g)
				var left := PackedStringArray()
				for g: String in p.loadout.gear:
					if not g in gear:
						left.append(g)
				p.loadout.gear = left
			# the weapons' own entries in the pack (their state; InventoryState works them out from the weapons
			# carried) go with them: a dropped pack does not count weapons the player no longer has
			var own := []
			var rest := []
			for e: Dictionary in p.inventory_pack:
				if InventoryState._derived(String(e.get("kind", ""))):
					own.append(e.duplicate(true))
				else:
					rest.append(e)
			p.inventory_pack = rest
			store["weapons"] = {"keys": keys, "items": items, "gear": gear, "pack": own}
		"tools":
			var items := []
			if p.loadout:
				for it: Dictionary in p.loadout.items.duplicate():
					if _is_tool(String(it.kind)):
						items.append(it.duplicate(true))
						p.loadout.remove_item(String(it.id))
			store["tools"] = {"items": items}
			_mark_lost()
		"pack":
			# the things in it; the weapons' own entries stay when the weapons do (InventoryState works them out from
			# the weapons carried, keeping only their state), and the torches are their own part
			var held := []
			var keep := []
			for e: Dictionary in p.inventory_pack:
				var k := String(e.get("kind", ""))
				if InventoryState._derived(k):
					keep.append(e.duplicate(true))
				elif k != InventoryState.TORCH:
					held.append(e.duplicate(true))
			store["pack"] = held
			p.inventory_pack = keep
			_mark_lost()
		"torches":
			var held := []
			if p.torch:
				if p.torch.pending:
					p.torch._cancel_pending()          # (the torch asked for goes back into the pack first)
				if p.torch.holding() and not p.torch.tossing():
					p.torch.put_away()
				for bl in p.torch.pack:
					held.append(float(bl))
				var none: Array[float] = []
				p.torch.pack = none
				p.torch.changed.emit()
			store["torches"] = held
		"coin":
			var core := _core()
			if core:
				# (a debt is not coin: nothing is taken, nor given back)
				var d := maxi(SurvivalEconomy.money(core), 0)
				if d > 0:
					SurvivalEconomy._add_money(core, -float(d))
				store["coin"] = d
		"kit":
			var core := _core()
			if core:
				# as many of each garment as are worn stay with the captive; the spares go
				var worn_n := {}
				for id in core.state.worn:
					worn_n[String(id)] = float(worn_n.get(String(id), 0.0)) + 1.0
				var keep := []
				var held := []
				for st: Dictionary in core.state.inventory:
					var id := String(st.get("id", ""))
					var w := float(worn_n.get(id, 0.0))
					var q := float(st.get("qty", 0.0))
					if w <= 0.0:
						held.append(st.duplicate(true))
						continue
					keep.append(st)
					if q > w + SurvivalInventory.EPS:
						var spare := st.duplicate(true)
						spare["qty"] = q - w
						spare["uid"] = SurvivalInventory.new_uid(core)
						held.append(spare)
						st["qty"] = w
						worn_n[id] = 0.0
					else:
						worn_n[id] = w - q
				core.state.inventory = keep
				core._on_inventory_changed()
				store["kit"] = held


## Every tool GatherTools would hand out again (not made, not lost already) marked lost while the captive is without it.
func _mark_lost() -> void:
	var g := player.gather
	if g == null or g.data == null:
		return
	for kind: String in g.data.tools:
		if bool(g.data.tools[kind].get("crafted", false)) or g.lost.has(kind) or kind in lost_marks:
			continue
		g.lost[kind] = true
		lost_marks.append(kind)


## The marks off the kinds the player has back (on the tool loop or in the pack: GatherTools hands those out no more
## anyway). `forget` (the end): the others are no longer this captivity's; they stay lost in GatherTools, as any tool
## lost, until found.
func _unmark_lost(forget := false) -> void:
	var g := player.gather if player and is_instance_valid(player) else null
	var keep := []
	for kind: String in lost_marks:
		if g != null and (g.on_loop == kind or g._in_pack(kind)):
			g.lost.erase(kind)
		elif not forget:
			keep.append(kind)
	lost_marks = keep


func _is_tool(kind: String) -> bool:
	var g := player.gather if player else null
	return g != null and g.data != null and g.data.is_tool(kind)


## The body shows what is left on it (the sling rig, the tool loop).
func _finish_body() -> void:
	var p := player
	if p.loadout:
		p.apply_loadout(p.loadout, p.inventory_pack)
	if p.gather:
		p.gather._read_loop()             # (the tool on the loop, or none; nothing handed out anew)
		p.gather._refresh_models()


# --- Bound ------------------------------------------------------------------------------------------------------

func _bind() -> void:
	var p := player
	if not bound:
		if p.building:
			p.building.set_active(false)
			_build_mode = p.building.process_mode
			p.building.process_mode = Node.PROCESS_MODE_DISABLED
		if p.rts:
			if p.rts.active:
				p.rts.set_active(false)
			_rts_input = p.rts.is_processing_unhandled_input()
			p.rts.set_process_unhandled_input(false)     # (F1 is not taken: no overhead camera, even for a frame)
	bound = true
	_hold_pace()


func _unbind() -> void:
	if not bound:
		return
	bound = false
	var p := player
	if p == null or not is_instance_valid(p):
		return
	if p.building:
		p.building.process_mode = _build_mode
	if p.rts:
		p.rts.set_process_unhandled_input(_rts_input)
	if is_equal_approx(p.drag_speed_cap, _my_cap):
		p.drag_speed_cap = INF
	_my_cap = INF


## The walking pace, or the river's lower wading pace; a lower cap someone else set stands (and stays theirs).
func _hold_pace() -> void:
	var cap := minf(speed_cap, _wade_cap())
	if player.drag_speed_cap > cap + 0.001 or is_equal_approx(player.drag_speed_cap, _my_cap):
		player.drag_speed_cap = cap
		_my_cap = cap


## The river's wading pace where the player stands, as RiverWater works it out (WADE_SLOW of a run from WADE_DEPTH.x of
## water to .y, RAPID_SLOW of that in a rapid): RiverWater lowers drag_speed_cap only when no one else holds it, so the
## bonds take it in here. INF out of the water.
func _wade_cap() -> float:
	var pos := player.global_position
	var surf := WorldRiver.surface_at(pos.x, pos.z)
	if surf == WorldRiver.NO_WATER or surf - pos.y <= RiverWater.WADE_DEPTH.x:
		return INF
	var k := clampf((surf - pos.y - RiverWater.WADE_DEPTH.x) / (RiverWater.WADE_DEPTH.y - RiverWater.WADE_DEPTH.x), 0.0, 1.0)
	return player.run_speed * lerpf(RiverWater.WADE_SLOW.x, RiverWater.WADE_SLOW.y, k) \
			* lerpf(1.0, RiverWater.RAPID_SLOW, WorldRiver.rapid_at(pos.z))


## The hands let go of what carries the body or a load: off a horse (one being broken: HorseBreaking lets it go), out of
## a boat (on the bank), a wheelbarrow set down, a carcass and a log let go; at the start (`first`) a grip too, and a
## sleeper woken. True when something was let go.
func _let_go_holds(first := false) -> bool:
	var p := player
	var any := false
	if p.riding != null:
		p.dismount()
		any = true
	if p.aboard != null and is_instance_valid(p.aboard) and p.aboard.has_method(&"leave"):
		p.aboard.call(&"leave")
		any = true
	if p.pushing != null and is_instance_valid(p.pushing) and p.pushing.has_method(&"set_down"):
		p.pushing.call(&"set_down", "bound")
		any = true
	if p.foot_drag and p.foot_drag.load != null:
		p.foot_drag.let_go("bound")
		any = true
	if p.log_pull and p.log_pull.load != null:
		p.log_pull._drop("bound")
		any = true
	if first:
		if p.grip and p.climbing == p.grip:
			p.grip._let_go(0.0, "let_go")
		var b := SurvivalBridge.find(get_tree()) if is_inside_tree() else null
		if b and b.sleeper and b.sleeper.sleeping:
			b.sleeper.stop_now()
	return any


## Nothing in the hands: a tool dropped back to its place, the weapon in the hand put away (one carried with its
## holster; one not carried any more, or out with the hands marked free as a respawn draws it, at once).
func _empty_hands() -> void:
	var p := player
	var g := p.gather
	if g != null and g.in_hand() != "":
		g.drop_now()
		g._refresh_models()
	if p.is_switching() or p.weapon == null or not p.weapon.active:
		return
	if p.is_carried(p.weapon_key) and not p.hands_free:
		p.toggle_hands_free()           # (its holster; asked again next frame while the hands are busy, a torch in them)
		return
	if p.quick != null:
		p.quick.drop()
	p.weapon.unequip()
	p.hands_free = true
	if p.anim:
		p.anim.hands_free = true
	if p.gear:
		p.gear.sling_all()


func _physics_process(delta: float) -> void:
	if not active or player == null or not is_instance_valid(player) or player.is_dead or _dying:
		return
	if bound:
		if _let_go_holds():
			_tell("Your hands are bound.")
		_empty_hands()
		if player.rts and player.rts.active:
			player.rts.set_active(false)
		_hold_pace()
	if _has_captor and not is_instance_valid(captor):
		follow(null)                     # (freed: a freed node reads as null, so the flag says there was one)
		_orphan_t = 0.0
	if has_escaped:
		return
	if _has_captor:
		_leash(delta)
	elif marching:
		_player_march()
	elif _orphan_t >= 0.0:
		_orphan_t += delta
		if _orphan_t >= NO_CAPTOR_GRACE_S:
			_orphan_t = -1.0
			if bound:
				_unbind()
				_loosed = true
				_tell("Nobody holds you now: you work your hands free.")


## The leash: close (the march goes on), waiting, turning back, or broken.
func _leash(delta: float) -> void:
	var d := _flat(player.global_position, captor.global_position)
	if d > escape_m:
		_escape()
		return
	var state := "close"
	if d > turn_back_m or (leash == "turning_back" and d > leash_m * TURN_BACK_STOP):
		state = "turning_back"
	elif d > leash_m:
		state = "waiting"
	_set_leash(state)
	match state:
		"turning_back":
			_drive(player.global_position, turn_back_speed, delta)
		"waiting":
			_wait(player.global_position)
		"close":
			if marching:
				_captor_march(delta)
			else:
				_wait(player.global_position)    # (nowhere to lead: it stands by the captive)


func _captor_march(delta: float) -> void:
	if route_i >= route.size():
		_end_march()
		return
	var to: Vector3 = route[route_i]
	_drive(to, captor_speed, delta)
	var left := _flat(captor.global_position, to)
	var seg := _seg_length(route_i)
	if left <= (CAPTOR_ARRIVE_M if captor.has_method(&"captive_lead") else 0.05):
		_done_m += seg
		route_i += 1
		_progress(_done_m)
		if route_i >= route.size():
			_end_march()
	else:
		_progress(_done_m + maxf(seg - left, 0.0))


## No captor: the player walks the route; each point reached counts its leg.
func _player_march() -> void:
	if route_i >= route.size():
		_end_march()
		return
	if _flat(player.global_position, route[route_i]) <= ARRIVE_M:
		_done_m += _seg_length(route_i)
		route_i += 1
		_progress(_done_m)
		if route_i >= route.size():
			_end_march()


## The flat length of the route's leg into point `i` (the first: from where the lead stood when the march began).
func _seg_length(i: int) -> float:
	if i <= 0:
		return 0.0 if route.is_empty() else _first_leg
	return _flat(route[i - 1], route[i])


## The lead has covered `m` metres of the route: the clock (and hunger) moves on by the new metres' minutes.
func _progress(m: float) -> void:
	if m <= march_m:
		return
	_min_acc += (m - march_m) * min_per_m
	march_m = m
	if _min_acc >= MIN_STEP:
		_advance(_min_acc)
		_min_acc = 0.0


func _end_march() -> void:
	if not marching:
		return
	marching = false
	if _min_acc > 0.0:
		_advance(_min_acc)
		_min_acc = 0.0
	march_done.emit()


## The survival clock on by `minutes`; hunger_mult over 1 burns the more food over them (the stomach first, then the
## body's reserve, as the needs burn it).
func _advance(minutes: float) -> void:
	var core := _core()
	if core == null or minutes <= 0.0:
		return
	var n: Dictionary = core.state.needs
	var before := float(n.get("stomach", 0.0)) + float(n.get("reserve", 0.0))
	core.advance(minutes)
	var burnt := before - (float(n.get("stomach", 0.0)) + float(n.get("reserve", 0.0)))
	var extra := maxf(burnt, 0.0) * maxf(hunger_mult - 1.0, 0.0)
	if extra > 0.0:
		var s := float(n.get("stomach", 0.0))
		var from_s := minf(s, extra)
		n["stomach"] = s - from_s
		n["reserve"] = maxf(0.0, float(n.get("reserve", 0.0)) - (extra - from_s))


## The captor walks toward `to` at `pace` (its own legs when it has them).
func _drive(to: Vector3, pace: float, delta: float) -> void:
	if captor.has_method(&"captive_lead"):
		captor.call(&"captive_lead", to, pace, delta)
		return
	var at := captor.global_position
	var flat := Vector3(to.x - at.x, 0.0, to.z - at.z)
	var step := minf(flat.length(), pace * delta)
	if flat.length() < 0.001:
		return
	var dir := flat.normalized()
	var nx := at + dir * step
	nx.y = FrontierTerrain.height_at(nx.x, nx.z)
	captor.global_position = nx
	captor.rotation.y = atan2(-dir.x, -dir.z)


## The captor stands and looks at `face`.
func _wait(face: Vector3) -> void:
	if captor.has_method(&"captive_wait"):
		captor.call(&"captive_wait", face)
		return
	var at := captor.global_position
	var flat := Vector3(face.x - at.x, 0.0, face.z - at.z)
	if flat.length() > 0.001:
		captor.rotation.y = atan2(-flat.x, -flat.z)


func _escape() -> void:
	has_escaped = true
	marching = false
	_orphan_t = -1.0
	_set_leash("escaped")
	if captor != null and is_instance_valid(captor):
		_wait(player.global_position)
	if unbind_on_escape:
		_unbind()
	_tell("You have broken away.")
	escaped.emit(player.global_position)


func _set_leash(state: String) -> void:
	if state == leash:
		return
	leash = state
	leash_changed.emit(state)


# --- Death ------------------------------------------------------------------------------------------------------

func _watch_player(on: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	if on:
		if not player.died.is_connected(_on_died):
			player.died.connect(_on_died)
		if not player.respawned.is_connected(_on_respawned):
			# (deferred: DeathRule has put them at home by then, and respawn() has drawn the weapon in the hand)
			player.respawned.connect(_on_respawned, CONNECT_DEFERRED)
	else:
		if player.died.is_connected(_on_died):
			player.died.disconnect(_on_died)
		if player.respawned.is_connected(_on_respawned):
			player.respawned.disconnect(_on_respawned)


func _on_died(_dir: Vector2) -> void:
	_dying = true


## Back from the dead (see on_death): never an escape, however far from the captor they wake.
func _on_respawned() -> void:
	_dying = false
	if not active or player == null or not is_instance_valid(player):
		return
	_empty_hands()                       # (respawn() draws the weapon in the hand again, held by the captors or not)
	captive_died.emit()
	if on_death == "keep":
		if captor != null and is_instance_valid(captor) and not has_escaped:
			var at := player.global_position + player.global_basis.x * 2.0
			captor.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
			_wait(player.global_position)
		return
	_tell("You wake alone: the captors are gone, and all they took with them.")
	end(false)


# --- Given back -------------------------------------------------------------------------------------------------

## Gives back `parts` of the store (all of it when empty) while the captivity goes on; the parts given back.
func give_back(parts: Array = []) -> Array:
	var done := []
	if player == null or not is_instance_valid(player):
		return done
	var want: Array = parts if not parts.is_empty() else PARTS
	for part: String in PARTS:
		if part in want and store.has(part):
			_give(part, store[part])
			store.erase(part)
			done.append(part)
	if not done.is_empty():
		_finish_body()
		_unmark_lost()
	return done


## The captivity over: the store given back (`return_gear`; only `parts` when given), the bonds off, no captor. Returns
## what was still held (a story may leave it in a chest, or drop_store() it first). The tools not given back stay lost.
func end(return_gear := true, parts: Array = []) -> Dictionary:
	if not active:
		return {}
	if return_gear:
		give_back(parts)
	var left := store.duplicate(true)
	store = {}
	_unbind()
	_unmark_lost(true)
	_watch_player(false)
	captor = null
	_has_captor = false
	marching = false
	route = []
	_orphan_t = -1.0
	_loosed = false
	_dying = false
	active = false
	_set_leash("no_captor")
	ended.emit(left)
	return left


## Leaves the held pack and torches lying at `at` in a PackDrop (the captors' camp: E takes it back), out of the
## store. Null when neither is held. The tools in it stay lost until it is taken (none handed out meanwhile).
func drop_store(at: Vector3) -> PackDrop:
	var items: Array = store.get("pack", [])
	var torches: Array = store.get("torches", [])
	if items.is_empty() and torches.is_empty():
		return null
	var pd := PackDrop.new()
	pd.name = "PackDrop"
	pd.items = items.duplicate(true)
	pd.torches = torches.duplicate()
	var core := _core()
	pd.dropped_min = core.state.minutes if core else 0.0
	pd.scavenged_to = pd.dropped_min
	get_tree().current_scene.add_child(pd)
	pd.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
	var kinds := []
	for e: Dictionary in pd.items:
		if _is_tool(String(e.get("kind", ""))):
			kinds.append(String(e.kind))
	if not kinds.is_empty():
		pd.tree_exiting.connect(_on_drop_gone.bind(pd, kinds))
	store.erase("pack")
	store.erase("torches")
	return pd


## A PackDrop of drop_store() going: taken (E empties it and frees it; not the level going), its tools are found again.
func _on_drop_gone(pd: PackDrop, kinds: Array) -> void:
	if not is_instance_valid(pd) or not pd.is_queued_for_deletion() or pd.count() > 0:
		return
	var g := player.gather if player and is_instance_valid(player) else null
	if g == null:
		return
	for kind: String in kinds:
		if g._in_pack(kind):
			g.found(kind)
			lost_marks.erase(kind)


func _give(part: String, v: Variant) -> void:
	var p := player
	match part:
		"weapons":
			var w: Dictionary = v
			for key in w.get("keys", []):
				if p.weapons.has(String(key)):
					p.carried[String(key)] = true
			if p.loadout:
				var gear := PackedStringArray(p.loadout.gear)
				for g in w.get("gear", []):
					if not String(g) in gear:
						gear.append(String(g))
				p.loadout.gear = gear
			_wear_back(w.get("items", []))
			var own: Array = w.get("pack", [])
			if not own.is_empty():
				p.inventory_pack = _merged(p.inventory_pack, own)
		"tools":
			_wear_back((v as Dictionary).get("items", []))
		"pack":
			p.inventory_pack = _merged(p.inventory_pack, v)
		"torches":
			if p.torch:
				for bl in v:
					p.torch.pack.append(float(bl))
				p.torch.changed.emit()
		"coin":
			var core := _core()
			if core and int(v) > 0:
				SurvivalEconomy._add_money(core, float(v))
		"kit":
			var core := _core()
			if core:
				for st: Dictionary in v:
					SurvivalInventory.add_to(core, core.state.inventory, String(st.get("id", "")), float(st.get("qty", 0.0)),
							st.get("meta", {}) as Dictionary, String(st.get("uid", "")), false)
				core._on_inventory_changed()


## Loadout items back at their points; one whose point is taken meanwhile goes into the pack instead (a weapon is
## carried all the same: its kind comes from the weapon).
func _wear_back(items: Array) -> void:
	var p := player
	if p.loadout == null:
		return
	var occ := p.loadout.occupancy()
	var spill := []
	for it: Dictionary in items:
		var free := true
		for pt in it.get("points", []):
			if occ.has(String(pt)):
				free = false
		if free:
			p.loadout.add_item(String(it.kind), it.get("points", []), int(it.get("count", 1)), it.get("state", {}) as Dictionary)
			for pt in it.get("points", []):
				occ[String(pt)] = String(it.kind)
		elif not InventoryState._derived(String(it.kind)):
			spill.append({"kind": String(it.kind), "count": int(it.get("count", 1)), "state": it.get("state", {})})
	if not spill.is_empty():
		p.inventory_pack = _merged(p.inventory_pack, spill)


## `into` with `more` added: a stack of the same kind and state takes the count, any other is added as it was.
static func _merged(into: Array, more: Array) -> Array:
	var out := into.duplicate(true)
	for e: Dictionary in more:
		var hit := false
		for o: Dictionary in out:
			if String(o.get("kind", "")) == String(e.get("kind", "")) and str(o.get("state", {})) == str(e.get("state", {})):
				o["count"] = int(o.get("count", 1)) + int(e.get("count", 1))
				hit = true
				break
		if not hit:
			out.append(e.duplicate(true))
	return out


# --- Its part of a save -----------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	if not active:
		return {}
	var d := {"active": true, "bound": bound, "escaped": has_escaped, "store": SaveParts.plain(store), "lost": lost_marks.duplicate(),
			"leash_m": leash_m, "turn_back_m": turn_back_m, "escape_m": escape_m, "speed": speed_cap, "captor_speed": captor_speed,
			"turn_back_speed": turn_back_speed, "unbind_on_escape": unbind_on_escape, "on_death": on_death, "loosed": _loosed,
			"marching": marching, "route_i": route_i, "march_m": march_m, "done_m": _done_m, "first_leg": _first_leg,
			"min_per_m": min_per_m, "hunger_mult": hunger_mult, "min_acc": _min_acc}
	var pts := []
	for v in route:
		pts.append(SaveParts.v3(v))
	d["route"] = pts
	if captor != null and is_instance_valid(captor) and captor.is_inside_tree():
		var level := get_tree().current_scene
		if level and level.is_ancestor_of(captor):
			d["captor_path"] = String(level.get_path_to(captor))
			d["captor_xf"] = SaveParts.xf(captor.global_transform)
	return d


## Back from a save (after the player's part: the pack, the loadout and the carried weapons are as they were saved, the
## held store out of them): the store and the leash again, the tools' marks and the bonds put back on; then the story
## is told (`restored`, WATCHERS) to make the captor again.
func load_data(d: Dictionary) -> void:
	if not bool(d.get("active", false)):
		return
	player = get_tree().current_scene.get_node_or_null("Player") as FrontierPlayer if get_tree().current_scene else null
	if player == null:
		return
	active = true
	store = (d.get("store", {}) as Dictionary).duplicate(true)
	if store.has("coin"):
		store["coin"] = int(store.coin)
	leash_m = float(d.get("leash_m", LEASH_M))
	turn_back_m = float(d.get("turn_back_m", TURN_BACK_M))
	escape_m = float(d.get("escape_m", ESCAPE_M))
	speed_cap = float(d.get("speed", player.walk_speed))
	captor_speed = float(d.get("captor_speed", CAPTOR_MPS))
	turn_back_speed = float(d.get("turn_back_speed", minf(TURN_BACK_MPS, speed_cap * TURN_BACK_SHARE)))
	unbind_on_escape = bool(d.get("unbind_on_escape", true))
	on_death = String(d.get("on_death", "end"))
	has_escaped = bool(d.get("escaped", false))
	_loosed = bool(d.get("loosed", false))
	_dying = false
	route = []
	for a in d.get("route", []):
		route.append(SaveParts.to_v3(a))
	route_i = int(d.get("route_i", 0))
	marching = bool(d.get("marching", false)) and route_i < route.size()
	march_m = float(d.get("march_m", 0.0))
	_done_m = float(d.get("done_m", 0.0))
	_first_leg = float(d.get("first_leg", 0.0))
	min_per_m = float(d.get("min_per_m", 0.0))
	hunger_mult = float(d.get("hunger_mult", 1.0))
	_min_acc = float(d.get("min_acc", 0.0))
	# the held weapons stay off the body (the player's part has their carried flags already; a fresh level's hand-outs
	# of the tools are kept off by the marks)
	for key in (store.get("weapons", {}) as Dictionary).get("keys", []):
		if player.weapons.has(String(key)):
			player.carried[String(key)] = false
	lost_marks = []
	var g := player.gather
	for kind in d.get("lost", []):
		if g != null and not g.lost.has(String(kind)):
			g.lost[String(kind)] = true
			lost_marks.append(String(kind))
	if bool(d.get("bound", true)):
		_bind()
	var c: Node3D = null
	if d.has("captor_path"):
		c = get_tree().current_scene.get_node_or_null(NodePath(String(d.captor_path))) as Node3D
		if c != null and d.has("captor_xf") and not c.has_method(&"captive_lead"):
			c.global_transform = SaveParts.to_xf(d.captor_xf)
	leash = ""
	follow(c)
	if has_escaped:
		_set_leash("escaped")
	elif c == null:
		_orphan_t = 0.0                  # (the story may make it again: NO_CAPTOR_GRACE_S once the march is walked)
	_empty_hands()
	_watch_player(true)
	_tell_restored.call_deferred()


## After a load: the story told, to make the captor again and connect to the signals again.
func _tell_restored() -> void:
	if not active or not is_inside_tree():
		return
	restored.emit()
	for n in get_tree().get_nodes_in_group(WATCHERS):
		if n.has_method(&"captivity_restored"):
			n.call(&"captivity_restored", self)


# --- Helpers ----------------------------------------------------------------------------------------------------

func _core() -> SurvivalCore:
	var b := SurvivalBridge.find(get_tree()) if is_inside_tree() else null
	return b.core if b else null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _tell(text: String) -> void:
	var it: Node = player.get("interactor") if player else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text, 3.5)
