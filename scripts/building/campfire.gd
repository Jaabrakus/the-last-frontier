class_name Campfire
extends Node3D
## A campfire (user 2026-09-27: "Fire, cold and shelter: the campfire model and light, placing it, and the lean-to as
## build pieces"): the fire of the build piece "campfire" (BuildGeometry: a ring of fieldstones round split wood laid
## in a cone; placed in build mode like any piece, for stone and firewood). It is built unlit, the wood laid.
##
## E (PlayerInteractor's interactable hook, like a door):
##   unlit       Light the fire: flint and steel (FIRE_STEEL, the player's from the start) or flint from the pack, or a bow
##               drill (twirled for a few seconds, it may not catch), or a
##               lit torch in the hand
##   burning     Add firewood from the pack (each stick burns FUEL_PER_WOOD s, at most MAX_WOOD laid), or, with none to
##               add, Smother the fire
##   burnt out   Lay firewood (then light it again); the coals glow for COALS_S after it burns down
## The fire is a TorchFire at campfire size (flames, tongues, embers, smoke, a warm flickering light reaching LIGHT_M,
## the crackle) on a TorchState that holds the fuel: it catches, burns, dies down and sputters as the wood runs out;
## heavy rain drowns it unless something overhead keeps the rain off (TorchState.sheltered: a roof, a lean-to's slope).
## Wolves keep off it (WildlifeSpawner counts every lit TorchFire). warmth_at() is the warmth a body feels from the lit
## fires near it (0..1).
## With the survival core in play (SurvivalBridge; user 2026-09-27: "they need to tell the bridge when you're near a lit
## fire"), CampLink keeps a record of the fire in the core (link, fire_id; SurvivalCamp): the fuel and the state are the
## record's, in game minutes (a stick FUEL_MIN_PER_WOOD), so the fire burns on the core's clock, a night's sleep too;
## the core warms, dries and wakes the player by it. Lighting, feeding, smothering and rain here go to the record, a
## burn-down there shows here. Lit, E's prompt also names F, cooking on it (CampCooking).

const GROUP := &"campfires"
const FIRE_STEEL := "fire_steel"
## The bow drill (the start with nothing: made at the knapping stone): a bow, spindle and hearth board, twirled for
## DRILL_S seconds; it may not catch (DRILL_BASE, better with practice at the Survival skill, worse on a wet fire).
const BOW_DRILL := "bow_drill"
const DRILL_S := 8.0
const DRILL_BASE := 0.5
const DRILL_PER_LEVEL := 0.006
const DRILL_WET := 0.4
const FUEL_PER_WOOD := 240.0      ## s of real time one stick of firewood burns
const MAX_WOOD := 6
const START_WOOD := 4             ## the build cost's firewood, laid in the ring
const LIGHT_M := 15.0
const SIZE := 2.8
const WARM_M := Vector2(2.0, 7.0)  ## full warmth within, none beyond
const COALS_S := 90.0
## Linked to the core: game minutes one stick of firewood burns (a pack firewood is an armload of split wood,
## item.fuel.split_wood), and the fuel below which the fire dies down (TorchState.GUTTER_FRAC of it).
const FUEL_MIN_PER_WOOD := 120.0
const LINK_GUTTER_MIN := 240.0
## In a hearth: its size and light, smaller than an open fire's.
const HEARTH_SIZE := 1.8
const HEARTH_LIGHT_M := 10.0

var state: TorchState
var fire: TorchFire
var interact_reach := 2.8
var _coals := 0.0
var _coal: MeshInstance3D
var _coal_mat: StandardMaterial3D
var _rain_t := 0.0
var _rain := 0.0
var _covered := false
## The survival core's camp (CampLink) and this fire's record there, while it keeps the fire.
var link: CampLink
var fire_id := ""
## The fire in a stone hearth (BuiltPiece "hearth"; user 2026-09-27: "making the stone hearth burn as a real fire
## indoors"): built with no wood laid, smaller, its smoke up the chimney (smoke_at, over the fire), its own stack keeping
## the rain off it. Everything else is a campfire's: E lays and lights it, F cooks on it, the core warms by it, and in a
## cabin under a roof a lit hearth makes it indoors (CampLink).
var hearth := false
var smoke_at := Vector3.ZERO
## The record's fuel as last seen (game minutes; -1 before a link): what a new record starts with when the old one is
## gone (a new or loaded core).
var _linked_fuel := -1.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(PlacedWeapon.GROUP)
	state = TorchState.new(FUEL_PER_WOOD * START_WOOD)
	if hearth:
		state.burn_left = 0.0                  # a hearth is built without wood
	fire = TorchFire.new()
	fire.name = "Fire"
	fire.fire_size = HEARTH_SIZE if hearth else SIZE
	fire.amount_mult = 1.6 if hearth else 2.0
	fire.light_range = HEARTH_LIGHT_M if hearth else LIGHT_M
	fire.light_up = 0.4 if hearth else 0.5
	fire.energy = 2.2 if hearth else 2.6
	fire.smoke_offset = smoke_at
	fire.state = state
	fire.position = Vector3(0, 0.06, 0)
	add_child(fire)
	_coal_mat = StandardMaterial3D.new()
	_coal_mat.albedo_color = Color(0.12, 0.05, 0.03)
	_coal_mat.emission_enabled = true
	_coal_mat.emission = Color(1.0, 0.35, 0.08)
	_coal_mat.emission_energy_multiplier = 0.0
	_coal = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.13 if hearth else 0.3
	disc.bottom_radius = 0.15 if hearth else 0.34
	disc.height = 0.05
	disc.radial_segments = 16
	_coal.mesh = disc
	_coal.material_override = _coal_mat
	_coal.position = Vector3(0, 0.03, 0)
	_coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coal)
	if hearth:
		_hearth_logs()


## Three split logs laid across the hearth's fire (a campfire's wood is its build piece's mesh).
func _hearth_logs() -> void:
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.2, 0.14, 0.1)
	bark.roughness = 0.9
	for i in 3:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.045
		c.bottom_radius = 0.05
		c.height = 0.5
		c.radial_segments = 7
		mi.mesh = c
		mi.material_override = bark
		mi.rotation = Vector3(0.0, [-0.5, 0.45, 0.0][i], PI * 0.5)
		mi.position = Vector3(0.0, 0.05 + 0.06 * float(i == 2), [-0.03, 0.03, -0.06][i])
		add_child(mi)


func is_lit() -> bool:
	return state != null and state.lit


## Sticks of wood laid now (whole sticks, rounded up).
func wood_left() -> int:
	return int(ceil(fuel_min() / FUEL_MIN_PER_WOOD - 0.001))


## The fuel laid now in game minutes (a new record starts with it).
func fuel_min() -> float:
	var r := record()
	if not r.is_empty():
		return float(r.get("fuel_min", 0.0))
	if _linked_fuel >= 0.0:
		return _linked_fuel
	return state.burn_left / FUEL_PER_WOOD * FUEL_MIN_PER_WOOD if state else 0.0


## The core's record of this fire while CampLink keeps it ({} when none).
func record() -> Dictionary:
	if link == null or not is_instance_valid(link) or fire_id == "":
		return {}
	return link.fire_record(fire_id)


## Kept by the survival core from now (CampLink): its record `id` holds the fuel and the state.
func attach(p_link: CampLink, id: String) -> void:
	link = p_link
	fire_id = id
	var r := record()
	if not r.is_empty():
		_linked_fuel = float(r.get("fuel_min", 0.0))
		state.burn_left = _linked_fuel
		state.burn_total = LINK_GUTTER_MIN


func _process(dt: float) -> void:
	if state == null:
		return
	# the weather twice a second (the rain on it, a roof or a lean-to's slope overhead)
	_rain_t -= dt
	if _rain_t <= 0.0:
		_rain_t = 0.5
		_rain = TorchState.rain_at(get_tree(), global_position)
		# a hearth's fire burns in its firebox's mouth, under the mantel: the rain does not reach it
		_covered = hearth or TorchState.sheltered(get_world_3d(), global_position + Vector3.UP * 0.6, _own_rids())
	var was := state.lit
	state.tick(dt, _rain, _covered, false)
	var r := record()
	if not r.is_empty():
		_follow(r, was)
	if was and not state.lit:
		_coals = COALS_S if state.out_reason == "burnt" else COALS_S * 0.3
		_sound(&"torch_snuff", -6.0)
	_coals = maxf(_coals - dt, 0.0)
	var glow := (state.strength() * 1.6 + (_coals / COALS_S) * 1.2) * (0.45 if hearth else 1.0)
	_coal_mat.emission_energy_multiplier = lerpf(_coal_mat.emission_energy_multiplier, glow, clampf(dt * 3.0, 0.0, 1.0))


## Linked: the record's fuel is the fire's. Drowned here (or burnt down a frame before the core's step): the record
## follows; burnt down there (its fuel ran out, a night's sleep): it goes out here.
func _follow(r: Dictionary, was: bool) -> void:
	var fs := str(r.get("state", "out"))
	if was and not state.lit:
		link.set_fire_state(fire_id, "smouldering" if state.out_reason == "burnt" else "out")
	elif state.lit and fs != "lit" and fs != "banked":
		state.snuff("burnt")
	elif not state.lit and fs == "lit" and float(r.get("fuel_min", 0.0)) > 0.0:
		state.burn_left = float(r.fuel_min)
		state.light()                                  # lit in the core (a loaded game)
	_linked_fuel = float(r.get("fuel_min", 0.0))
	state.burn_left = _linked_fuel
	state.burn_total = LINK_GUTTER_MIN


func _own_rids() -> Array:
	if hearth:
		return []                              # its own chimney keeps the rain off
	var p := get_parent() as BuiltPiece
	return p.body_rids() if p else []


# --- E ---------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position + Vector3.UP * 0.35


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func highlight_targets() -> Array:
	var p := get_parent() as BuiltPiece
	return p.highlight_targets() if p else []


func interact_prompt(player: Node) -> String:
	var bm := _build_mode(player)
	if bm and bm.active:
		return ""                       # build mode's E is the piece's (take down)
	var wood := _pack_count(player, "firewood")
	if state.lit:
		var cook := link.cook_hint(player) if link and is_instance_valid(link) else ""
		var gap := "      " if cook != "" else ""
		if wood > 0 and wood_left() < MAX_WOOD:
			return "Add firewood (%d laid, %d in the pack)%s%s" % [wood_left(), wood, gap, cook]
		return "Smother the fire%s%s" % [gap, cook]
	if fuel_min() <= 0.0:
		return "Lay firewood" if wood > 0 else "Lay firewood (none in the pack)"
	if _torch_lit(player):
		return "Light the fire from the torch"
	if _has_striker(player):
		return "Light the fire"
	if _has_drill(player):
		return "Light the fire with the bow drill"
	return "Light the fire (needs flint and steel, a bow drill or a torch)"


## Hold E's list (PlayerInteractor): the tap's action, and the other one when both can be done (a lit fire with
## room and wood in the pack: add firewood / smother it; a cold one laid ready: light it / lay on more).
func interact_actions(player: Node) -> Array:
	var first := interact_prompt(player)
	if first == "":
		return []
	var out: Array = [{"id": "", "text": first}]
	var more := _pack_count(player, "firewood") > 0 and wood_left() < MAX_WOOD
	if state.lit and more:
		out.append({"id": "smother", "text": "Smother the fire"})
	elif not state.lit and fuel_min() > 0.0 and more and (_torch_lit(player) or _has_striker(player) or _has_drill(player)):
		out.append({"id": "wood", "text": "Lay on more firewood (%d laid)" % wood_left()})
	# casting balls at the lit fire (ShotMaking: the mould and bar lead in the pack)
	if state.lit:
		var cast := ShotMaking.row(self, player)
		if not cast.is_empty():
			out.append(cast)
	return out


func interact_action(player: Node, id: String) -> void:
	var bm := _build_mode(player)
	if bm and bm.active:
		return
	match id:
		"smother":
			smother()
		"wood":
			add_wood(player)
		"cast":
			ShotMaking.cast(self, player)
		_:
			interact(player)


func interact(player: Node) -> void:
	var bm := _build_mode(player)
	if bm and bm.active:
		return
	if state.lit:
		if _pack_count(player, "firewood") > 0 and wood_left() < MAX_WOOD:
			add_wood(player)
		else:
			smother()
		return
	if fuel_min() <= 0.0:
		add_wood(player)
		return
	if _torch_lit(player) or _has_striker(player):
		light()
	elif _has_drill(player):
		drill()


## Twirls the bow drill over the laid fire (StationWork: kneeling, DRILL_S s): the coal may catch and the fire light, or
## not (try again). Each try is practice at the Survival skill. False when it cannot start.
func drill() -> bool:
	var b := SurvivalBridge.find(get_tree())
	if b == null or b.core == null or b.work.working or state.lit or fuel_min() <= 0.0:
		return false
	return b.work.begin(global_position, "low", "Twirling the bow drill in the notch", DRILL_S, "", func(done: bool) -> void:
		if done:
			_drill_done(b))


## The drill's chance now: the base, the Survival skill's level, less on a wet fire.
func drill_chance(b: SurvivalBridge) -> float:
	var lvl := SurvivalSkills.level(b.core, "survival")
	return clampf(DRILL_BASE + lvl * DRILL_PER_LEVEL - DRILL_WET * clampf(float(state.wet), 0.0, 1.0), 0.1, 0.95)


func _drill_done(b: SurvivalBridge) -> void:
	if state.lit or fuel_min() <= 0.0:
		return
	if b.core.rng.randf() < drill_chance(b):
		SurvivalSkills.practice(b.core, "survival", 1.5)
		light()
		b._notice("The coal catches in the tinder: a flame")
	else:
		SurvivalSkills.practice(b.core, "survival", 0.6)
		b._notice("Smoke, but no coal yet: twirl it again")


## Lights it (the wood laid). True when it burns.
func light() -> bool:
	if fuel_min() <= 0.0:
		return false
	var r := record()
	if not r.is_empty():
		state.burn_left = float(r.get("fuel_min", 0.0))
		state.burn_total = LINK_GUTTER_MIN
	if not state.light():
		return false
	if not r.is_empty():
		link.set_fire_state(fire_id, "lit")
	_sound(&"torch_ignite", -2.0)
	return true


## One stick of firewood from the pack onto the fire (or into the cold ring).
func add_wood(player: Node) -> bool:
	if _pack_count(player, "firewood") <= 0 or wood_left() >= MAX_WOOD:
		return false
	var inv := InventoryState.from_player(player)
	inv.take("firewood", 1)
	player.set("inventory_pack", inv.pack.duplicate(true))
	if not record().is_empty():
		link.add_fuel(fire_id, FUEL_MIN_PER_WOOD)
		_linked_fuel = fuel_min()
		state.burn_left = _linked_fuel
		return true
	state.burn_left += FUEL_PER_WOOD
	state.burn_total = maxf(state.burn_total, state.burn_left)
	return true


func smother() -> void:
	if state.lit:
		state.snuff("snuffed")
		if not record().is_empty():
			link.set_fire_state(fire_id, "out")
		_coals = COALS_S * 0.2
		_sound(&"torch_snuff", -3.0)


# --- Warmth ----------------------------------------------------------------------------------------

## The warmth a body at `pos` feels from the lit campfires near it: 1 close in (WARM_M.x), nothing beyond WARM_M.y;
## the strongest fire counts, as big as it burns.
static func warmth_at(tree: SceneTree, pos: Vector3) -> float:
	var best := 0.0
	for n in tree.get_nodes_in_group(GROUP):
		var c := n as Campfire
		if c == null or not c.is_lit():
			continue
		var d := c.global_position.distance_to(pos)
		var w := (1.0 - smoothstep(WARM_M.x, WARM_M.y, d)) * c.state.strength()
		best = maxf(best, w)
	return best


# --- Helpers ---------------------------------------------------------------------------------------

static func _pack_count(player: Node, kind: String) -> int:
	var n := 0
	var pack: Variant = player.get("inventory_pack")
	if pack is Array:
		for e: Dictionary in pack:
			if String(e.get("kind", "")) == kind:
				n += int(e.get("count", 0))
	return n


static func _has_striker(player: Node) -> bool:
	if _pack_count(player, FIRE_STEEL) > 0:
		return true
	# a flint alone strikes fire on steel (a gunflint on the lock's frizzen): a start with nothing has no steel
	return _pack_count(player, "flint") > 0 and not (player != null and player.is_inside_tree() and SurvivalBridge.bare_of(player.get_tree()))


static func _has_drill(player: Node) -> bool:
	return _pack_count(player, BOW_DRILL) > 0


static func _torch_lit(player: Node) -> bool:
	var t: Variant = player.get("torch")
	if t == null or not t.has_method("holding") or not t.holding():
		return false
	var held: Variant = t.get("held")
	return held != null and held.lit


static func _build_mode(_player: Node) -> BuildMode:
	return BuildMode.current if is_instance_valid(BuildMode.current) else null


## Every frontiersman carries flint and steel: the player has it from the start (as the knife, FieldDressing).
static func ensure_striker(player: Node) -> void:
	if player == null or _pack_count(player, FIRE_STEEL) > 0:
		return
	if player.is_inside_tree() and SurvivalBridge.bare_of(player.get_tree()):
		return                     # (a start with nothing has neither flint nor steel)
	var inv := InventoryState.from_player(player)
	inv.add(FIRE_STEEL, 1)
	player.set("inventory_pack", inv.pack.duplicate(true))


func _sound(id: StringName, db: float) -> void:
	if Sfx.has(id):
		Sfx.play_3d(id, global_position + Vector3.UP * 0.3, db)
