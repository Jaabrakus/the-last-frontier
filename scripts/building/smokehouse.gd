class_name Smokehouse
extends StorageChest
## A smokehouse (the build piece "smokehouse"; user 2026-09-27: "a smokehouse for storing jerky"): a larder of food (its
## items: the pack's venison, jerky, cornmeal, johnnycake, berries, nuts...; ChestScreen, as the storage chest) and a
## smudge fire in its floor. While the smudge smoulders (firewood laid on it, SMUDGE_MIN_PER_WOOD game minutes a stick;
## a woodpile within PILE_M not feeding a fire tops it up by itself) each raw venison in the larder takes the smoke and
## after SMOKE_H game hours is jerky (JERKY_PER_VENISON pounds of it: the core's rcp.jerky, 10 lb raw to 4 dried). Game
## time is the survival core's (its clock runs through a night's sleep). E: a menu (StationMenu): open the larder, lay
## firewood on the smudge. The smudge glows through the doorway and its smoke rises from the ridge; the meat hangs
## inside, darker as it smokes. Kept in the save (SaveParts building "smokehouse").

const SMUDGE_MIN_PER_WOOD := 240.0
const SMUDGE_MAX_MIN := 1440.0
const SMOKE_H := 20.0
const JERKY_PER_VENISON := 2.8
const PILE_M := 3.5
const EVERY_S := 0.5

## Game minutes of smudge left, and of smoke each raw venison in the larder has had (most smoked first).
var smudge_min := 0.0
var smoke: Array = []
var _jerky_frac := 0.0
var _last_min := -1.0
var _t := 0.0
var _fire: TorchFire
var _fstate: TorchState
var _meat: Array[MeshInstance3D] = []
var _meat_mat: StandardMaterial3D
static var _food := {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"smokehouses")
	add_to_group(PlacedWeapon.GROUP)
	interact_reach = 2.6
	_fstate = TorchState.new(1.0e6)
	_fire = TorchFire.new()
	_fire.name = "Smudge"
	_fire.fire_size = 0.7
	_fire.amount_mult = 0.8
	_fire.light_range = 3.5
	_fire.light_up = 0.25
	_fire.energy = 0.9
	_fire.state = _fstate
	_fire.position = Vector3(0, 0.05, 0)
	_fire.smoke_offset = Vector3(0, BuildGeometry.SMOKE_RIDGE + 0.1, 0)
	add_child(_fire)
	_meat_mat = StandardMaterial3D.new()
	_meat_mat.roughness = 0.6


## Food only.
func accepts(kind: String) -> bool:
	if _food.is_empty():
		for k in SurvivalBridge.load_items():
			_food[String(k)] = true
	return _food.has(kind)


func put(inv: InventoryState, kind: String, n: int) -> int:
	if not accepts(kind):
		return 0
	var got := super.put(inv, kind, n)
	if kind == "venison":
		for i in got:
			smoke.append(0.0)
	_dress()
	return got


func take(inv: InventoryState, kind: String, n: int) -> int:
	var got := super.take(inv, kind, n)
	if kind == "venison":
		for i in got:
			if not smoke.is_empty():
				smoke.pop_back()                      # the least smoked come out first
	_dress()
	return got


func smudge_lit() -> bool:
	return smudge_min > 0.0


## Hours until the next venison is jerky (INF when none smokes).
func hours_to_next() -> float:
	if smoke.is_empty():
		return INF
	return maxf(SMOKE_H * 60.0 - float(smoke[0]), 0.0) / 60.0


# --- Time --------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = EVERY_S
	tick()


## The smudge burns, the meat smokes (on the core's minutes since the last tick), a woodpile beside it tops it up.
func tick() -> void:
	var b := SurvivalBridge.find(get_tree())
	if b == null or b.core == null:
		_show_fire()
		return
	var m := b.core.state.minutes + float(b.core.state.world.get("clock_acc", 0.0))
	var dm := m - _last_min if _last_min >= 0.0 else 0.0
	_last_min = m
	if dm < 0.0 or dm > 3.0 * SurvivalClock.MIN_PER_DAY:
		dm = 0.0
	var left := dm
	while left > 0.0:
		if smudge_min <= 0.0 and not _from_pile():
			break
		var burn := minf(left, smudge_min)
		smudge_min -= burn
		left -= burn
		for i in smoke.size():
			smoke[i] = float(smoke[i]) + burn
	if smudge_min < 60.0:
		_from_pile()
	_cure()
	_show_fire()
	_dress()


## A stick from a woodpile beside it (not one feeding a fire) onto the smudge. True when one came.
func _from_pile() -> bool:
	if smudge_min + SMUDGE_MIN_PER_WOOD > SMUDGE_MAX_MIN:
		return false
	for n in get_tree().get_nodes_in_group(Woodpile.GROUP):
		var p := n as Woodpile
		if p and p.global_position.distance_to(global_position) <= PILE_M and p.draw_one():
			smudge_min += SMUDGE_MIN_PER_WOOD
			return true
	return false


## Venison smoked long enough is jerky.
func _cure() -> void:
	var done := 0
	while not smoke.is_empty() and float(smoke[0]) >= SMOKE_H * 60.0:
		smoke.pop_front()
		done += 1
	if done <= 0:
		return
	_remove("venison", done)
	_jerky_frac += done * JERKY_PER_VENISON
	var units := floori(_jerky_frac + 0.0001)
	_jerky_frac -= units
	if units > 0:
		for e: Dictionary in items:
			if String(e.kind) == "jerky":
				e.count = int(e.count) + units
				return
		items.append({"kind": "jerky", "count": units})


func _remove(kind: String, n: int) -> void:
	for i in items.size():
		var e: Dictionary = items[i]
		if String(e.kind) == kind:
			e.count = int(e.count) - n
			if int(e.count) <= 0:
				items.remove_at(i)
			return


## Firewood from the pack onto the smudge (up to SMUDGE_MAX_MIN). How many sticks.
func lay_wood(player: Node) -> int:
	var room := floori((SMUDGE_MAX_MIN - smudge_min) / SMUDGE_MIN_PER_WOOD)
	var inv := InventoryState.from_player(player)
	var n := inv.take("firewood", room)
	if n <= 0:
		return 0
	player.set("inventory_pack", inv.pack.duplicate(true))
	smudge_min += n * SMUDGE_MIN_PER_WOOD
	_show_fire()
	return n


# --- Looks -------------------------------------------------------------------------------------------

func _show_fire() -> void:
	if smudge_lit() and not _fstate.lit:
		_fstate.burn_left = 1.0e6
		_fstate.light()
	elif not smudge_lit() and _fstate.lit:
		_fstate.snuff("burnt")


## Meat hung from the ridge pole inside: raw red, darker as it smokes, jerky near black.
func _dress() -> void:
	var raw := count_of("venison")
	var dry := count_of("jerky")
	var n := mini(raw * 3 + ceili(dry / 2.0), 30)
	while _meat.size() < n:
		var i := _meat.size()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.34 + 0.05 * float((i * 5) % 3), 0.015)
		mi.mesh = bm
		var row := i % 3
		var x := -BuildGeometry.SMOKE_W * 0.5 + 0.3 + 0.13 * float(i / 3)
		mi.position = Vector3(minf(x, BuildGeometry.SMOKE_W * 0.5 - 0.25), BuildGeometry.SMOKE_EAVE - 0.3, -0.35 + 0.35 * row)
		add_child(mi)
		_meat.append(mi)
	while _meat.size() > n:
		_meat.pop_back().queue_free()
	var smoked := 0.0
	if not smoke.is_empty():
		for s in smoke:
			smoked += float(s)
		smoked /= float(smoke.size()) * SMOKE_H * 60.0
	var col := Color(0.52, 0.14, 0.1).lerp(Color(0.2, 0.08, 0.06), clampf(smoked if raw > 0 else 1.0, 0.0, 1.0))
	_meat_mat.albedo_color = col
	for mi in _meat:
		mi.material_override = _meat_mat


# --- E -----------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_transform * Vector3(0, 1.0, BuildGeometry.SMOKE_D * 0.5 + 0.2)


func interact_prompt(_player: Node) -> String:
	if is_instance_valid(BuildMode.current) and BuildMode.current.active:
		return ""
	var raw := count_of("venison")
	var s := "The smokehouse"
	if raw > 0 and smudge_lit():
		s += " (%d venison smoking, the next jerky in %d hours)" % [raw, ceili(hours_to_next())]
	elif raw > 0:
		s += " (%d venison, the smudge out)" % raw
	elif total() > 0:
		s += " (%d things in the larder)" % total()
	return s


func interact(player: Node) -> void:
	if is_instance_valid(BuildMode.current) and BuildMode.current.active:
		return
	open_menu(player)


func menu_rows(player: Node) -> Array:
	var raw := count_of("venison")
	var wood := Campfire._pack_count(player, "firewood")
	var room := floori((SMUDGE_MAX_MIN - smudge_min) / SMUDGE_MIN_PER_WOOD)
	var smudge := "the smudge smoulders %d hours more" % ceili(smudge_min / 60.0) if smudge_lit() else "the smudge is out"
	return [
		{"id": "larder", "text": "Open the larder", "ok": true,
				"detail": "%d things in it%s: raw venison hung here smokes into jerky in %d game hours" % [total(),
						(" (%d venison, %d jerky)" % [raw, count_of("jerky")]) if total() > 0 else "", int(SMOKE_H)]},
		{"id": "smudge", "text": "Lay firewood on the smudge", "ok": wood > 0 and room > 0,
				"detail": ("%s; a stick smoulders 4 game hours (%d in the pack)" % [smudge, wood]) if wood > 0 and room > 0 else
						(("%s; no firewood in the pack" % smudge) if wood <= 0 else "%s; it has all it will take" % smudge)},
	]


func open_menu(player: Node) -> void:
	var rows := menu_rows(player)
	var m := StationMenu.open(get_tree(), "Smokehouse", rows)
	var i: int = await m.picked
	if i < 0:
		return
	match String(rows[i].id):
		"larder":
			ChestScreen.open_for(player, self)
		"smudge":
			lay_wood(player)


# --- The save ----------------------------------------------------------------------------------------

func to_save_all() -> Dictionary:
	return {"items": to_save(), "smoke": smoke.duplicate(), "smudge": smudge_min, "frac": _jerky_frac}


func from_save_all(d: Dictionary) -> void:
	from_save(d.get("items", []))
	smoke = []
	for s in d.get("smoke", []):
		smoke.append(float(s))
	smudge_min = float(d.get("smudge", 0.0))
	_jerky_frac = float(d.get("frac", 0.0))
	_last_min = -1.0
	_show_fire()
	_dress()
