class_name NpcSenses
extends Node
## What the fighters share (NpcFighter, NpcBrain): who is about, what is heard, how dark it is, and the frame budget.
##   NpcSenses.noise(pos, radius, source)   a loud noise anyone may make (a gunshot, a door kicked in, a shout): every fighter
##                                          within `radius` hears it (NpcBrain.heard: suspicious, and looks that way)
##   NpcSenses.foes_of(fighter, max_m)      the foes it might see, nearest first: the player (when its faction is hostile to the
##                                          player's side) and the fighters of hostile factions, alive and not surrendered
##   NpcSenses.allies_of(fighter, r)        its side's fighters within r (alerts are shared with them)
##   NpcSenses.daylight(tree)               1 by day, down to NIGHT at night (sight is shortened by it)
## The node (one per level, NpcSenses.of(tree): made by the first fighter) hooks the player's weapons as the wildlife does
## (a musket heard SHOT_LOUD_M away, a bow or a throw SHOT_QUIET_M), keeps the one light every fighter's muzzle flash borrows
## (no light of its own per shot), and every BUDGET_S sorts the fighters by distance from the camera: the MAX_ANIMATED nearest
## are animated (their pose stepped at WildlifeSpawner.anim_step_at their distance), the rest frozen (their pose stepped only
## every FROZEN_STEP_S, so a man walking or crouching still shows it and his hit parts follow; his brain slower), and those
## past VISIBLE_M hidden and not stepped at all. A man falling dead plays his fall whatever the count (not counted).
## THE FIELD CLEARED (a long session, a raid's waves): the settled dead leave `fighters` for `corpses` (no one's foe, ally or
## listener; their bodies at rest: NpcBody.rest); a corpse's body is freed CORPSE_S after it fell once the camera does not see
## it (or it is past VISIBLE_M), its untouched packs LOOT_S after when no one is within VISIBLE_M; a man run off or let go,
## past VISIBLE_M from the camera for LEAVE_S, leaves the field (NpcFighter.leave_field). The nodes stay: the story counts them.
## A level's run-time changes (NpcFactions.set_hostile, NpcFighter.kills) go with it (_exit_tree).

const NODE_NAME := "NpcSenses"
## At most this many fighters are animated at once (the frame budget: docs/research/codebase_story_audit.md, 10-16 on screen).
const MAX_ANIMATED := 12
const BUDGET_S := 0.5
const VISIBLE_M := 260.0
## A frozen man's pose is stepped this often (s).
const FROZEN_STEP_S := 0.4
## The field cleared (s): a corpse's body, its untouched packs, a man run off.
const CORPSE_S := 180.0
const LOOT_S := 600.0
const LEAVE_S := 30.0
## A night's sight against a day's (moonlight); dusk between (the sun's elevation, deg).
const NIGHT := 0.35
const DAY_ELEV := 8.0
const NIGHT_ELEV := -6.0

## Every fighter in the world (they add themselves as they enter the tree), but the settled dead: those are in `corpses`.
static var fighters: Array[NpcFighter] = []
static var corpses: Array[NpcFighter] = []
## The player the fighters see (the level's; null when there is none).
static var player: FrontierPlayer = null
## Tests: the light set by hand (-1: from the sky).
static var daylight_override := -1.0

var animated := 0
var flash: OmniLight3D
var fx_root: Node3D
var _t := 0.0
var _hook_t := 0.0
var _flash_tw: Tween


static func of(tree: SceneTree) -> NpcSenses:
	var scene := tree.current_scene if tree else null
	if scene == null:
		return null
	var s := scene.get_node_or_null(NODE_NAME) as NpcSenses
	if s != null:
		return s
	s = NpcSenses.new()
	s.name = NODE_NAME
	scene.add_child(s)
	return s


func _ready() -> void:
	_find_player()
	fx_root = Node3D.new()
	fx_root.name = "MuzzleFx"
	add_child(fx_root)
	flash = OmniLight3D.new()
	flash.name = "MuzzleFlash"
	flash.light_color = Color(1.0, 0.72, 0.38)
	flash.omni_range = 4.0
	flash.omni_attenuation = 0.0
	flash.light_energy = 0.0
	flash.light_volumetric_fog_energy = 0.0
	flash.shadow_enabled = false
	flash.visible = false
	fx_root.add_child(flash)


func _find_player() -> void:
	var scene := get_tree().current_scene
	var p := scene.get_node_or_null("Player") as FrontierPlayer if scene else null
	if p != player:
		player = p


func _exit_tree() -> void:
	if player != null and is_instance_valid(player) and player.get_tree() == get_tree():
		player = null
	# (the level goes: its run-time hostility and the kills counted in it go too, not into the next game of the run)
	NpcFactions.clear_overrides()
	NpcFighter.kills.clear()


func _process(dt: float) -> void:
	_hook_t -= dt
	if _hook_t <= 0.0:
		_hook_t = 2.0
		_find_player()
		_hook_weapons()
	_t -= dt
	if _t <= 0.0:
		_t = BUDGET_S
		budget(BUDGET_S)


## The player's weapons heard as the wildlife hears them (WildlifeSpawner._hook_weapons).
func _hook_weapons() -> void:
	if player == null or not is_instance_valid(player):
		return
	for key: String in player.weapons:
		var w: Weapon = player.weapons[key]
		if w != null and not w.fired.is_connected(_on_player_fired):
			w.fired.connect(_on_player_fired.bind(key))


func _on_player_fired(key: String) -> void:
	if player != null and is_instance_valid(player):
		noise(player.global_position, WildlifeSpawner.SHOT_LOUD_M if key in WildlifeSpawner.LOUD else WildlifeSpawner.SHOT_QUIET_M, player)


## The frame budget: the MAX_ANIMATED nearest fighters animated (their pose stepped for their distance), the rest frozen (a
## coarse step), the far ones hidden and still; a man falling dead animated whatever the count. `dt`: the time since the last
## (the field's clearing counts by it; 0 from a test: nothing cleared).
func budget(dt := 0.0) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else (player.global_position if player != null and is_instance_valid(player) else Vector3.ZERO)
	var live: Array = []
	for f in fighters.duplicate():
		if not is_instance_valid(f) or f.body == null:
			continue
		var d2 := eye.distance_squared_to(f.global_position)
		f.visible = d2 < VISIBLE_M * VISIBLE_M
		if f.is_dead():
			# (its fall played out whatever the count; settled, it is NpcFighter's to rest)
			f.body.animate = not f.settled()
			f.body.anim_step = WildlifeSpawner.anim_step_at(sqrt(d2))
			continue
		if f.brain != null and f.brain.routed() and not f.kneeling():
			# (run off, or let go: far from everyone a while, gone from the field)
			f.away_t = f.away_t + dt if d2 > VISIBLE_M * VISIBLE_M else 0.0
			if f.away_t > LEAVE_S:
				f.leave_field()
				continue
		live.append([d2, f])
	live.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	animated = 0
	for i in live.size():
		var f: NpcFighter = live[i][1]
		var d := sqrt(float(live[i][0]))
		var on := i < MAX_ANIMATED and d < VISIBLE_M
		f.body.animate = d < VISIBLE_M
		f.body.anim_step = WildlifeSpawner.anim_step_at(d) if on else maxf(WildlifeSpawner.anim_step_at(d), FROZEN_STEP_S)
		f.frozen = not on
		if on:
			animated += 1
	_clear_field(dt, cam, eye)


## The settled dead: the bodies freed long after when not seen, the untouched packs when no one is near (see the header).
func _clear_field(dt: float, cam: Camera3D, eye: Vector3) -> void:
	if dt <= 0.0:
		return
	var who := eye
	if player != null and is_instance_valid(player):
		who = player.global_position
	for f in corpses.duplicate():
		if not is_instance_valid(f):
			corpses.erase(f)
			continue
		f.away_t += dt
		var d2 := eye.distance_squared_to(f.global_position)
		f.visible = f.body != null and d2 < VISIBLE_M * VISIBLE_M
		if f.body != null and f.away_t > CORPSE_S and (d2 > VISIBLE_M * VISIBLE_M or cam == null
				or not cam.is_position_in_frustum(f.global_position + Vector3.UP * 0.4)):
			f.clear_away()
		for i in range(f.packs.size() - 1, -1, -1):
			var l: Variant = f.packs[i]               # (a pack taken is freed: read as it is, not as a pack)
			if not is_instance_valid(l):
				f.packs.remove_at(i)
				continue
			var at := (l as Node3D).global_position
			if f.away_t > LOOT_S and at.distance_to(who) > VISIBLE_M and at.distance_to(eye) > VISIBLE_M:
				(l as Node).queue_free()
				f.packs.remove_at(i)
		if f.body == null and f.packs.is_empty():
			corpses.erase(f)


## A fighter settled dead (NpcFighter._dead_step): out of `fighters`, into `corpses`.
static func settle(f: NpcFighter) -> void:
	fighters.erase(f)
	if f.is_inside_tree() and not corpses.has(f):
		f.away_t = 0.0
		corpses.append(f)


## `n` goes (freed, or out of the level): the player's interactor forgets it when it is his target, so that its next frame does
## not read it freed (PlayerInteractor keeps last frame's target and its list of what is in reach until it looks again).
static func forget(n: Node) -> void:
	if not is_instance_valid(player):
		return
	var it: Variant = player.get(&"interactor")
	if is_instance_valid(it) and (it as Object).get(&"target") == n:
		(it as Object).set(&"target", null)


## A musket's blast at `xf` (its muzzle, -Z along the shot): the game's fire, sparks and smoke (Fx.muzzle_blast) with the one
## shared light flashed there instead of a light of its own.
func muzzle_blast(xf: Transform3D, scale := 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var n0 := fx_root.get_child_count()
	Fx.muzzle_blast(fx_root, xf, scale)
	for i in range(fx_root.get_child_count() - 1, n0 - 1, -1):
		var c := fx_root.get_child(i)
		if c is OmniLight3D and c != flash:
			c.queue_free()
	flash_at(xf.origin - xf.basis.z * 0.8, 0.7 * scale * Fx._fire_dim(fx_root))   # (as bright as Fx's own would be)


## The shared light flashed at `pos` (gone in a tenth of a second).
func flash_at(pos: Vector3, energy := 0.7) -> void:
	if flash == null:
		return
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	flash.global_position = pos
	flash.visible = true
	flash.light_energy = energy
	_flash_tw = flash.create_tween()
	_flash_tw.tween_property(flash, "light_energy", 0.0, 0.1)
	_flash_tw.tween_callback(func() -> void: flash.visible = false)


## How many fighters are animated now (the budget's last count).
func animated_count() -> int:
	return animated


# ---------------------------------------------------------------- the shared world

## A loud noise at `pos` heard `radius` m off (a gunshot: WildlifeSpawner.SHOT_LOUD_M) by every fighter in reach.
static func noise(pos: Vector3, radius: float, source: Node = null) -> void:
	for f in fighters.duplicate():
		if is_instance_valid(f) and not f.is_dead() and f.global_position.distance_to(pos) <= radius:
			f.hear(pos, radius, source)


## The foes `me` might see within `max_m`, nearest first, at most `most`: [[distance, node], ...].
static func foes_of(me: NpcFighter, max_m: float, most := 4) -> Array:
	var out: Array = []
	var at := me.global_position
	if player != null and is_instance_valid(player) and not player.is_dead and NpcFactions.hostile(me.faction, NpcFactions.PLAYER):
		var d := at.distance_to(player.global_position)
		if d < max_m:
			out.append([d, player])
	for f in fighters:
		if f == me or not is_instance_valid(f) or f.is_dead() or f.surrendered() or not NpcFactions.hostile(me.faction, f.faction):
			continue
		var d := at.distance_to(f.global_position)
		if d < max_m:
			out.append([d, f])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out.slice(0, most)


## Its side's fighters within `r` of it (alive, not itself).
static func allies_of(me: NpcFighter, r: float) -> Array[NpcFighter]:
	var out: Array[NpcFighter] = []
	var side := NpcFactions.side_of(me.faction)
	for f in fighters:
		if f != me and is_instance_valid(f) and not f.is_dead() and NpcFactions.side_of(f.faction) == side \
				and f.global_position.distance_to(me.global_position) <= r:
			out.append(f)
	return out


## Whether `n` is a foe that can still fight (alive, not surrendered).
static func can_fight(n: Variant) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n is FrontierPlayer:
		return not (n as FrontierPlayer).is_dead
	if n is NpcFighter:
		return not (n as NpcFighter).is_dead() and not (n as NpcFighter).surrendered()
	return false


## Where to aim at `n` (its chest), and its eyes' height for a look at it.
static func chest_of(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * (0.85 if crouched(n) else 1.3)


static func head_of(n: Node3D) -> Vector3:
	return n.global_position + Vector3.UP * (1.1 if crouched(n) else 1.62)


static func crouched(n: Node) -> bool:
	return n.get(&"is_crouching") == true


## How fast `n` goes over the ground (m/s).
static func speed_of(n: Node) -> float:
	var v: Variant = n.get(&"velocity")
	return Vector2((v as Vector3).x, (v as Vector3).z).length() if v is Vector3 else 0.0


## Its velocity (m/s; zero for what has none).
static func velocity_of(n: Node) -> Vector3:
	var v: Variant = n.get(&"velocity") if n != null else null
	return v as Vector3 if v is Vector3 else Vector3.ZERO


## A lit torch in its hand shows it in the dark.
static func torch_lit(n: Node) -> bool:
	var t: Variant = n.get(&"torch")
	if t is PlayerTorch:
		var held := (t as PlayerTorch).held
		return held != null and held.lit
	return false


## The light to see by: 1 by day, NIGHT at night, between at dusk and dawn (the sky's sun).
static func daylight(tree: SceneTree) -> float:
	if daylight_override >= 0.0:
		return daylight_override
	var scene := tree.current_scene if tree else null
	var rig := scene.get_node_or_null("EnvironmentRig") as EnvironmentRig if scene else null
	if rig == null or rig.clock_driver == null or rig.clock_driver.clock == null:
		return 1.0
	var e := rig.clock_driver.clock.sun_elevation_deg()
	return lerpf(NIGHT, 1.0, clampf((e - NIGHT_ELEV) / (DAY_ELEV - NIGHT_ELEV), 0.0, 1.0))


## Whether the line from `from` to `to` is clear up to `target` (nothing solid between; mask 1, the world's bodies).
static func clear_line(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, target: Node, exclude: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	var c := hit.collider as Node
	for i in 4:
		if c == null:
			break
		if c == target:
			return true
		c = c.get_parent()
	return false
