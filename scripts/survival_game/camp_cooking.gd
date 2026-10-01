class_name CampCooking
extends Node
## Cooking on a campfire (F; SurvivalBridge.cook; user 2026-09-27: "the same connection lets them cook cornmeal and
## venison"). At a lit campfire (the one E points at, or the nearest within REACH_M), F puts the pack's raw food on it:
## fresh fish first, then fresh venison and the trap line's small game (they will not keep), else cornmeal, as much as one roast takes (SurvivalJobs.COOK_MAX_GAME_KCAL:
## a game day's food, 3 venison or 7 cornmeal). The food goes into the core and its roast runs (the core's cook.roast
## job: 15-40 game minutes in 6-9 real seconds, a Provisions check, the fire must stay lit); the player kneels facing
## the fire (the bundled Actor_B low-search clips, as FieldDressing) while a bar fills. Moving, F again, a weapon or
## a hit stops it and the raw food comes back to the pack (the core keeps the roast's progress for a while).
## The roast's outcome sets what comes back, one pack unit for each put on (game_items.json maps each to the core):
##   cooked or a little underdone   roast venison / roast small game / johnnycake (cornmeal baked in the ashes)
##   burnt                          charred venison / charred small game / burnt johnnycake: half the food (the core's rule: burnt food keeps
##                                  half its energy)

const LIB := "actor_b"
const CLIP_IN := "actor_b-cap-ambi-search-low-in-place-entry"
const CLIP_LOOP := "actor_b-cap-ambi-search-low-in-place"
const CLIP_OUT := "actor_b-cap-ambi-search-low-in-place-exit"
const OUT_S := 1.5
const CANCEL_ACTIONS := ["jump", "crouch", "aim", "fire", "reload", "sprint", "cook"]
const ACTION := &"cook"
const JOB := "cook.roast"
## m from the fire (flat) to cook on it.
const REACH_M := 2.8
## The pack's raw food that cooks, in the order F takes it (fish first: it keeps least; each species its own kind,
## FishCatch, all roasting into roast fish).
const RAW := ["brook_trout", "salmon", "sucker", "perch", "pike", "eel", "bullhead", "sturgeon", "pickerel", "venison",
		"small_game", "cornmeal", "corn", "squash", "beans"]
## What each comes back as.
const COOKED := {
	"venison": {"cooked": "roast_venison", "burnt": "charred_venison", "verb": "Roast"},
	"small_game": {"cooked": "roast_small_game", "burnt": "charred_small_game", "verb": "Roast"},
	"brook_trout": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"salmon": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"sucker": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"perch": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"pike": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"eel": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"bullhead": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"sturgeon": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"pickerel": {"cooked": "roast_fish", "burnt": "charred_fish", "verb": "Roast"},
	"cornmeal": {"cooked": "johnnycake", "burnt": "burnt_johnnycake", "verb": "Bake"},
	# the farm's crops (FarmField)
	"corn": {"cooked": "roast_corn", "burnt": "charred_corn", "verb": "Roast"},
	"squash": {"cooked": "roast_squash", "burnt": "charred_squash", "verb": "Roast"},
	"beans": {"cooked": "bean_pot", "burnt": "scorched_beans", "verb": "Boil"},
}

var bridge: SurvivalBridge
var cooking := false
## The raw pack kind on the fire, how many units, and the fire.
var kind := ""
var units := 0
var fire: Campfire
## The last roast: {kind, units, state, got, text}.
var last := {}

var _item := ""
var _per := 1.0
var _base := 0.0
var _ap: AnimationPlayer
var _blender: HorsePhaseBlender
var _phase := 0            ## 0 kneeling down, 1 cooking, 2 getting up
var _t := 0.0
var _layer: CanvasLayer
var _label: Label
var _bar: ProgressBar


func _ready() -> void:
	_build_ui()
	hook(bridge.core)


## Listens to `core` (a new core after a load).
func hook(core: SurvivalCore) -> void:
	if core == null:
		return
	if not core.job_finished.is_connected(_on_finished):
		core.job_finished.connect(_on_finished)
	if not core.job_interrupted.is_connected(_on_interrupted):
		core.job_interrupted.connect(_on_interrupted)


## F's line in a lit fire's prompt: what F would put on it ("" when there is nothing to cook).
func hint(player: Node) -> String:
	if cooking or player == null:
		return ""
	var k := raw_kind(player)
	if k == "":
		return ""
	var n := units_for(k, Campfire._pack_count(player, k))
	var key := _key_name()
	if k == "cornmeal":
		return "%s  Bake johnnycake (%d cornmeal)" % [key, n]
	if k == "small_game":
		return "%s  Roast small game (%d)" % [key, n]
	return "%s  Roast venison (%d)" % [key, n]


## The raw food F would cook from the pack ("" when none).
func raw_kind(player: Node) -> String:
	for k: String in RAW:
		if bridge.items.has(k) and Campfire._pack_count(player, k) > 0:
			return k
	return ""


## Units of `k` one roast takes out of `have`.
func units_for(k: String, have: int) -> int:
	var per := maxf(bridge.unit_kcal(k), 1.0)
	return clampi(floori(SurvivalJobs.COOK_MAX_GAME_KCAL / per + 0.0001), 1, maxi(have, 1)) if have > 0 else 0


func _physics_process(dt: float) -> void:
	if bridge == null or bridge.player == null or not is_instance_valid(bridge.player):
		return
	var p := bridge.player
	if not cooking:
		if InputMap.has_action(ACTION) and Input.is_action_just_pressed(ACTION) and not get_tree().paused and not p.is_dead:
			var f := target_fire()
			if f == null:
				if raw_kind(p) != "":
					bridge._notice("Cook at a lit campfire")
			else:
				start(f)
		return
	if p.is_dead or p.kneeling != self or not is_instance_valid(fire):
		_stop_now("")
		return
	if _phase < 2 and _cancel_pressed():
		_cancel("moved")
	_t += dt
	match _phase:
		0:
			_blender.show_clip(CLIP_IN, minf(_t, _len(CLIP_IN)), 0.15)
			if _t >= _len(CLIP_IN):
				_phase = 1
				_t = 0.0
		1:
			_blender.show_clip(CLIP_LOOP, fposmod(_t, _len(CLIP_LOOP)), 0.3)
			var j := SurvivalJobs.current(bridge.core)
			if String(j.get("action", "")) == JOB:
				_bar.value = clampf(float(j.get("elapsed_min", 0.0)) / maxf(float(j.get("duration_min", 1.0)), 0.01), 0.0, 1.0)
		2:
			_blender.show_clip(CLIP_OUT, minf(_t, _len(CLIP_OUT)), 0.2)
			if _t >= minf(OUT_S, _len(CLIP_OUT)):
				_end()
				return
	_blender.update(dt)


## The fire F cooks on: the one E points at when it burns, else the nearest lit one in reach.
func target_fire() -> Campfire:
	var p := bridge.player
	var it: Node = p.get("interactor")
	var t: Variant = it.get("target") if it else null
	if t is Campfire and (t as Campfire).is_lit():
		return t as Campfire
	return bridge.camp.lit_fire_near(p.global_position, REACH_M) if bridge.camp else null


## Puts the raw food on `f` and kneels to it. False when it cannot (a notice says why).
func start(f: Campfire) -> bool:
	var p := bridge.player
	if cooking or f == null or not f.is_lit() or (bridge.sleeper and bridge.sleeper.sleeping):
		return false
	var k := raw_kind(p)
	if k == "":
		bridge._notice("Nothing to cook: fresh fish, raw venison, cornmeal, corn, squash or beans")
		return false
	var core := bridge.core
	# the core's fire is this one
	if bridge.camp:
		bridge.camp.link_fire(f)
		bridge.camp.refresh()
		if str(core.state.context.get("fire_id", "")) != f.fire_id:
			var d := Vector2(f.global_position.x - p.global_position.x, f.global_position.z - p.global_position.z).length()
			bridge.set_context({"fire_id": f.fire_id, "fire_distance_m": d})
	var e: Dictionary = bridge.items[k]
	_item = String(e.item)
	_per = float(e.get("qty", 1.0))
	var n := units_for(k, Campfire._pack_count(p, k))
	# into the core: its roast works on its own inventory
	var inv := InventoryState.from_player(p)
	inv.take(k, n)
	p.inventory_pack = inv.pack.duplicate(true)
	_base = SurvivalInventory.count(core, _item)
	SurvivalInventory.add(core, _item, n * _per)
	kind = k
	units = n
	var r := core.start_job(JOB, {"item": _item, "qty": n * _per})
	if not bool(r.get("ok", false)):
		_give_back()
		var rs: Array = r.get("reasons", [])
		bridge._notice("You cannot cook now: %s" % (String(rs[0]) if not rs.is_empty() else String(r.get("reason", "not now"))))
		kind = ""
		return false
	_ap = p.begin_kneel(self, f.global_position)
	if _ap == null:
		core.cancel_job("moved")
		_give_back()
		kind = ""
		return false
	fire = f
	cooking = true
	_phase = 0
	_t = 0.0
	_blender = HorsePhaseBlender.new(_ap, p, LIB)
	_blender.show_clip(CLIP_IN, 0.0, 0.0)
	_blender.update(0.0)
	_label.text = "Roasting venison over the fire" if k == "venison" else "Roasting small game over the fire" if k == "small_game" else ("Roasting %s over the fire" % InventoryState.name_of(k).to_lower() if FishCatch.is_fish(k) else _crop_label(k))
	_bar.value = 0.0
	_layer.visible = true
	return true


## The roast is done: its food back into the pack, cooked (or burnt), one unit for each put on.
## The bar's line for the farm's crops (and the cornmeal's).
static func _crop_label(k: String) -> String:
	match k:
		"corn":
			return "Roasting ears of corn in their husks"
		"squash":
			return "Roasting squash in the ashes"
		"beans":
			return "Boiling beans over the fire"
	return "Baking johnnycake in the ashes"


func _on_finished(res: Dictionary) -> void:
	if not cooking or String(res.get("action", "")) != JOB:
		return
	var core := bridge.core
	var c: Dictionary = res.get("cooked", {})
	if not bool(c.get("ok", false)):
		_give_back()
		_done("The food would not cook", {})
		return
	SurvivalInventory.remove(core, String(c.item), float(c.qty_out))
	_give_back()                      # anything raw the roast left (none, normally)
	var st := String(c.get("state", "cooked"))
	var got := String(COOKED[kind].burnt if st == "burnt" else COOKED[kind].cooked)
	var inv := InventoryState.from_player(bridge.player)
	inv.add(got, units)
	bridge.player.inventory_pack = inv.pack.duplicate(true)
	var nm := InventoryState.name_of(got).to_lower()
	var text := ""
	if st == "burnt":
		text = "It burns: %d %s" % [units, nm]
	elif kind == "venison":
		text = "You roast the venison: %d %s%s" % [units, nm, ", a little underdone" if st == "undercooked" else ""]
	elif kind == "small_game":
		text = "You roast the small game: %d %s%s" % [units, nm, ", a little underdone" if st == "undercooked" else ""]
	elif FishCatch.is_fish(kind):
		text = "You roast the %s: %d lb of %s%s" % [InventoryState.name_of(kind).to_lower(), units, nm, ", a little underdone" if st == "undercooked" else ""]
	elif kind in ["corn", "squash", "beans"]:
		var what := "You boil the beans" if kind == "beans" else "You roast the %s" % InventoryState.name_of(kind).to_lower()
		text = "%s: %d %s%s" % [what, units, nm, ", a little underdone" if st == "undercooked" else ""]
	else:
		text = "You bake %d %s in the ashes%s" % [units, nm, ", a little doughy" if st == "undercooked" else ""]
	bridge.needs_changed.emit()
	_done(text, {"state": st, "got": got})


func _on_interrupted(job: Dictionary, reason: String) -> void:
	if not cooking or String(job.get("action", "")) != JOB:
		return
	# going from fed to peckish (the core's wake rule for any worse need): the roast goes on where it was
	if reason.contains("peckish") and bool(bridge.core.start_job(JOB, SurvivalUtil.dict(job.get("params"))).get("ok", false)):
		return
	_give_back()
	_done("The fire went out: the food is still raw" if reason.contains("fire") else "You stop cooking: %s" % reason, {})


## Stopped by the player: the core keeps the roast's progress, the food comes back raw.
func _cancel(reason: String) -> void:
	if SurvivalJobs.is_running(bridge.core) and String(SurvivalJobs.current(bridge.core).get("action", "")) == JOB:
		bridge.core.cancel_job(reason)
	_give_back()
	_done("", {})


func _done(text: String, extra: Dictionary) -> void:
	last = {"kind": kind, "units": units, "state": String(extra.get("state", "")), "got": String(extra.get("got", "")), "text": text}
	if text != "":
		bridge._notice(text)
	_layer.visible = false
	if _phase < 2:
		_phase = 2
		_t = 0.0


## What of the raw food is still in the core goes back to the pack (whole units).
func _give_back() -> void:
	if _item == "":
		return
	var core := bridge.core
	var left := SurvivalInventory.count(core, _item) - _base
	if left > 0.0001:
		SurvivalInventory.remove(core, _item, left)
		var n := floori(left / _per + 0.0001)
		if n > 0 and kind != "":
			var inv := InventoryState.from_player(bridge.player)
			inv.add(kind, n)
			bridge.player.inventory_pack = inv.pack.duplicate(true)
	_item = ""


func _cancel_pressed() -> bool:
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3:
		return true
	for a: String in CANCEL_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return not bridge.player.hands_free


func _stop_now(reason: String) -> void:
	if cooking and _phase < 2:
		_cancel(reason if reason != "" else "moved")
	_end()


func _end() -> void:
	cooking = false
	_layer.visible = false
	if _blender and is_instance_valid(_blender.tree):
		_blender.tree.active = false
		_blender.tree.queue_free()
	_blender = null
	var p := bridge.player
	if p and p.kneeling == self:
		p.end_kneel()
	fire = null
	kind = ""


func _len(clip: String) -> float:
	var full := "%s/%s" % [LIB, clip]
	return _ap.get_animation(full).length if _ap and _ap.has_animation(full) else 1.0


static func _key_name() -> String:
	if InputMap.has_action(ACTION):
		for ev in InputMap.action_get_events(ACTION):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	return "F"


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.78
	box.anchor_bottom = 0.78
	box.offset_left = -150.0
	box.offset_right = 150.0
	_layer.add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 5)
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(300, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.86, 0.52, 0.24)
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.07, 0.06, 0.7)
	back.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
