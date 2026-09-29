class_name Household
extends Node
## The player's household (user 2026-09-28: "a wife NPC for my char ... talk to the npc and delegate tasks either through
## talking or an npc management tab"): the spouse (SpouseCore: her own survival core and her work; Spouse: her body) and
## what she works from, the storage chests (ChestStock). The level installs it once the survival bridge exists; every
## frame it keeps her core on the player's clock. E on her, or J anywhere, opens the household screen (HouseholdScreen:
## Talk, Tasks, Stats). Saved as the "household" part.
##   Household.install(level, player) -> the household (null without survival: no clock to keep)

const GROUP := &"household"
const LINES_PATH := "res://data/companion/lines.json"
const ACTION := &"household"

var player: FrontierPlayer
var bridge: SurvivalBridge
var sc: SpouseCore
var body: Spouse
var stock: ChestStock
var home := Vector3.ZERO
var screen: HouseholdScreen
var lines := {}
var _rng := RandomNumberGenerator.new()


static func find(tree: SceneTree) -> Household:
	return tree.get_first_node_in_group(GROUP) as Household if tree else null


static func install(level: Node, p: FrontierPlayer) -> Household:
	var b := SurvivalBridge.find(level.get_tree())
	if b == null or b.core == null:
		return null
	var h := Household.new()
	h.name = "Household"
	h.player = p
	h.bridge = b
	level.add_child(h)
	return h


func _ready() -> void:
	add_to_group(GROUP)
	InputSetup.ensure()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	lines = d if d is Dictionary else {}
	_rng.randomize()
	stock = ChestStock.new()
	stock.tree = get_tree()
	_new_spouse.call_deferred()


## A spouse of the opposite sex to the player's character, standing near them.
func _new_spouse() -> void:
	if sc != null or not is_instance_valid(player):
		return
	var look: Dictionary = player.appearance.look if player.appearance != null else AppearanceStore.load_current()
	var seed_v := int(bridge.core.state.rng_seed) ^ 0xA11CE
	sc = SpouseCore.create(bridge.core, look, seed_v)
	sc.role = "home"
	_spawn(_start_point())


func _start_point() -> Vector3:
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	var p := player.global_position + fwd.normalized() * 2.2 + player.global_basis.x * -1.2
	p.y = maxf(FrontierTerrain.height_at(p.x, p.z), player.global_position.y - 0.5)
	return p


func _spawn(at: Vector3) -> void:
	if body != null and is_instance_valid(body):
		body.queue_free()
	sc.stock = stock
	home = at
	stock.home = home
	body = Spouse.spawn(get_parent(), sc, player, at)
	body.talk_requested.connect(open)
	_set_hearth()


## The hearth is the campfire nearest home (home itself when there is none).
func _set_hearth() -> void:
	var best := home
	var bd := 40.0
	for n in get_tree().get_nodes_in_group(Campfire.GROUP):
		var c := n as Node3D
		if c == null:
			continue
		var d := c.global_position.distance_to(home)
		if d < bd:
			bd = d
			best = c.global_position
	if body:
		body.home = home
		body.hearth = best


func _process(_dt: float) -> void:
	if sc == null or bridge == null or bridge.core == null:
		return
	sc.sync(bridge.core)
	if Input.is_action_just_pressed(ACTION) and screen == null and not get_tree().paused and is_instance_valid(player) \
			and not player.is_dead:
		open(body, "tasks")


func open(_who: Spouse = null, tab := "talk") -> void:
	if screen != null or sc == null:
		return
	screen = HouseholdScreen.open_for(self, tab)
	screen.tree_exited.connect(func() -> void: screen = null)


# ---------------------------------------------------------------- what the player can ask
func set_role(role: String) -> String:
	if not SpouseCore.ROLES.has(role):
		return ""
	sc.cancel("new orders")
	sc.role = role
	sc.focus = ""
	if body:
		body._plan = {}
	return pick(["role", role])


## Asks for a task by name: she takes it on its role's ground (cooking and butchering at home, forage and firewood out).
func order(task: String) -> String:
	if not SpouseCore.TASKS.has(task):
		return ""
	sc.cancel("new orders")
	sc.enabled[task] = true
	sc.role = String(SpouseCore.TASK_ROLE[task])
	sc.focus = task
	sc._cool = 0.0
	if body:
		body._plan = {}
	return pick(["task", task])


func set_home_here() -> String:
	var at := player.global_position
	home = at
	stock.home = home
	_set_hearth()
	return pick(["home_set"])


func pick(path: Array) -> String:
	var v: Variant = lines
	for k in path:
		v = (v as Dictionary).get(k, {}) if v is Dictionary else {}
	if v is Array and not (v as Array).is_empty():
		return String((v as Array)[_rng.randi() % (v as Array).size()])
	return ""


## What she says on meeting the player: by the hour and how she is.
func greeting() -> String:
	var stage := SurvivalNeeds.food_stage(sc.core)
	if sc.core.health() < 60.0:
		return pick(["greet", "hurt"])
	if stage in ["hungry", "very_hungry", "starving", "wasting"]:
		return pick(["greet", "hungry"])
	var h := sc.hour()
	var part := "night" if h < 5.0 or h >= 21.5 else "morning" if h < 10.0 else "day" if h < 18.0 else "evening"
	return pick(["greet", part])


# ---------------------------------------------------------------- saving
func save_data() -> Dictionary:
	if sc == null:
		return {}
	var d := {"spouse": sc.to_dict(), "home": [home.x, home.y, home.z]}
	if body and is_instance_valid(body):
		var p := body.global_position
		d["at"] = [p.x, p.y, p.z]
	return d


func load_data(d: Dictionary) -> void:
	if not d.has("spouse") or bridge == null or bridge.core == null:
		return
	sc = SpouseCore.from_dict(d.spouse, bridge.core)
	var a: Array = d.get("at", d.get("home", [0, 0, 0]))
	var at := Vector3(float(a[0]), float(a[1]), float(a[2]))
	var hm: Array = d.get("home", a)
	_spawn(at)
	home = Vector3(float(hm[0]), float(hm[1]), float(hm[2]))
	stock.home = home
	_set_hearth()
