class_name ClassicFrames
extends Control
## The classic HUD's frames (the owner, 2026-10-03: "can the hud be similar to world of warcraft vanilla?"; the approved
## mockup's layout, in the game's own art: ClassicSkin), over FrontierHUD when the HUD style is classic
## (ClassicSkin.style()):
##   top left      the player frame (ClassicPlayerFrame: the portrait, name, health, the Sway's motes, the status icons)
##   beside it     the target frame (ClassicTargetFrame), hidden when there is nothing: what the Sway's lock is on, else
##                 what the crosshair is on (a ray from the camera ten times a second, AIM_REACH m with a weapon raised or a
##                 spell readied, LOOK_REACH m else; held RAY_KEEP_S after the crosshair leaves it), else what E would use
##                 (PlayerInteractor.target), else what the player last hit (HIT_KEEP_S: a shot or a blow, group
##                 hit_listeners), never the horse he rides
##   bottom centre the action bar (ClassicActionBar: the hotbar's nine buttons, the ammo line under it), the renown bar
##                 over it (ClassicRenownBar)
##   bottom right  the micro menu (ClassicMicroMenu) over the bag bar (ClassicBagBar)
## The minimal HUD's vitals and slot strip are hidden while these show (FrontierHUD.classic). The rest of the classic
## layout (the minimap, the quest tracker, the chat log) is its own. The interactor's prompt goes up PROMPT_LIFT px over the
## bars while these are on; the command mode (RtsMode, its own screen) hides them, a talk (StoryDialogue, its box at the
## bottom middle) the action bar, the renown bar and the chat log (`talking`).
## Cheap: the bars and buttons are drawn, not built of nodes; they are looked at ten times a second (the status icons twice,
## the renown and the menus once), drawn again only when something they show changed (or while they animate: a bar easing,
## a spell's glow, the lock filling); the ray is one query a tick.
##   ClassicFrames.install(hud)    FrontierHUD._ready, when classic
##   open(screen)                  "gear", "skills", "settings", "group:<name>" (the micro menu's and the bags' clicks)

const TICK_S := 0.1
const STATUS_S := 0.5
const SLOW_S := 1.0
const AIM_REACH := 150.0
const LOOK_REACH := 40.0
const RAY_KEEP_S := 1.2
const HIT_KEEP_S := 10.0
const MARGIN := Vector2(14, 10)
## px the interactor's prompt, its "Hold E: more" line and the hold-E list go up (PlayerInteractor.prompt_lift): clear of
## the renown and action bars.
const PROMPT_LIFT := 32.0

var hud: FrontierHUD
var player: FrontierPlayer
var player_frame: ClassicPlayerFrame
var target_frame: ClassicTargetFrame
var action_bar: ClassicActionBar
var renown: ClassicRenownBar
var micro: ClassicMicroMenu
var bags: ClassicBagBar
## The target the frame shows (null none) and why ("lock", "aim", "use", "hit").
var target: Node = null
var target_why := ""
## A talk is open (StoryDialogue): the action bar, the renown bar and the chat log are hidden under it.
var talking := false
var _tick := 0.0
var _status_t := 0.0
var _slow_t := 0.0
var _ray_hit: Node = null
var _ray_keep := 0.0
var _hit: Node = null
var _hit_t := 0.0
var _caster: SwayCaster = null       ## the player's (looked up at the tick, read every frame while a lock is on)


static func install(h: FrontierHUD) -> ClassicFrames:
	var f := ClassicFrames.new()
	f.name = "ClassicFrames"
	f.hud = h
	f.player = h.player
	h._root.add_child(f)
	return f


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)     # (in the tree now: the offsets too, or it keeps no size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = ClassicSkin.theme()
	add_to_group("hit_listeners")
	player_frame = ClassicPlayerFrame.new()
	player_frame.hud = hud
	add_child(player_frame)
	hud._place(player_frame, Vector2(0, 0), MARGIN, Vector2(0, 0))
	target_frame = ClassicTargetFrame.new()
	add_child(target_frame)
	hud._place(target_frame, Vector2(0, 0), MARGIN + Vector2(ClassicPlayerFrame.W + 22.0, 0), Vector2(0, 0))
	action_bar = ClassicActionBar.new()
	add_child(action_bar)
	hud._place(action_bar, Vector2(0.5, 1), Vector2(0, -2), Vector2(0.5, 1))
	renown = ClassicRenownBar.new()
	renown.custom_minimum_size = Vector2(action_bar.plate.size.x - 16.0, ClassicRenownBar.H)
	add_child(renown)
	hud._place(renown, Vector2(0.5, 1), Vector2(0, -2.0 - action_bar.custom_minimum_size.y + action_bar.plate.position.y - 3.0),
			Vector2(0.5, 1))
	micro = ClassicMicroMenu.new()
	micro.frames = self
	add_child(micro)
	bags = ClassicBagBar.new()
	bags.frames = self
	add_child(bags)
	hud._place(bags, Vector2(1, 1), Vector2(-MARGIN.x, -6), Vector2(1, 1))
	hud._place(micro, Vector2(1, 1), Vector2(-MARGIN.x, -6.0 - ClassicBagBar.PACK.y - 6.0), Vector2(1, 1))
	if player != null:
		player_frame.portrait.follow(player)
	# a talk (StoryDialogue: its box at the bottom middle, the game paused under it) has the bottom of the screen: the
	# action bar, the renown bar and the chat log step aside while it is open (looked at ten times a second, paused too)
	var talk_t := Timer.new()
	talk_t.name = "TalkWatch"
	talk_t.wait_time = 0.1
	talk_t.autostart = true
	talk_t.process_mode = Node.PROCESS_MODE_ALWAYS
	talk_t.timeout.connect(_watch_talk)
	add_child(talk_t)
	_tick = TICK_S                   # (the first look at once)
	_status_t = STATUS_S
	_slow_t = SLOW_S


## A talk open (StoryDialogue): the bottom's parts away; gone: back.
func _watch_talk() -> void:
	var on := StoryDialogue.find(get_tree()) != null if is_inside_tree() else false
	if on == talking:
		return
	talking = on
	action_bar.visible = not on
	renown.visible = not on
	var mp := HudClassicMap.find(hud)
	if mp != null and mp.chat != null:
		mp.chat.visible = not on


## Taken off (the HUD style minimal: FrontierHUD.apply_style): the interactor's prompt back at its own place.
func _exit_tree() -> void:
	if player != null and is_instance_valid(player) and player.interactor != null and is_instance_valid(player.interactor):
		player.interactor.prompt_lift = 0.0


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_ray_keep = maxf(0.0, _ray_keep - delta)
	_hit_t = maxf(0.0, _hit_t - delta)
	_tick += delta
	_status_t += delta
	_slow_t += delta
	var b: SurvivalBridge = null
	if _tick >= TICK_S or _status_t >= STATUS_S or _slow_t >= SLOW_S:
		b = SurvivalBridge.find(get_tree())
	if _tick >= TICK_S:
		_tick = 0.0
		_caster = SwayCaster.of(player)
		player_frame.refresh(player, b)
		action_bar.refresh(player, hud)
		_pick_target()
	if _status_t >= STATUS_S:
		_status_t = 0.0
		player_frame.refresh_status(player, b)
	if _slow_t >= SLOW_S:
		_slow_t = 0.0
		renown.refresh(b)
		micro.refresh()
		bags.refresh(player)
		var it := player.interactor
		if it != null and is_instance_valid(it) and it.prompt_lift != PROMPT_LIFT:
			it.prompt_lift = PROMPT_LIFT
	# the command mode (F1, RtsMode) has its own screen over the land: the frames step aside (and take no clicks)
	var rts_on := player.rts != null and is_instance_valid(player.rts) and player.rts.active
	if visible == rts_on:
		visible = not rts_on
	# the lock fills smoothly (read every frame while one is on: no allocation)
	var c := _caster
	if c != null and is_instance_valid(c) and c.state != SwayCaster.State.IDLE:
		for btn: ClassicActionBar.ActionButton in action_bar.buttons:
			if btn.lock >= 0.0 and absf(btn.lock - c.fill) > 0.001:
				btn.lock = c.fill
				btn.queue_redraw()


# --- the target ---------------------------------------------------------------------------------------------------

func _pick_target() -> void:
	var p := player
	var t: Node = null
	var why := ""
	var c := SwayCaster.of(p)
	if c != null and c.state != SwayCaster.State.IDLE and c.target != null and is_instance_valid(c.target):
		t = ClassicTargetFrame.subject_of(c.target)
		why = "lock"
	var seen := _ray()
	if seen != null:
		_ray_hit = seen
		_ray_keep = RAY_KEEP_S
	elif _ray_hit != null and (not is_instance_valid(_ray_hit) or _ray_keep <= 0.0):
		_ray_hit = null
	if t == null and _ray_hit != null:
		t = _ray_hit
		why = "aim"
	if t == null and p.interactor != null and is_instance_valid(p.interactor) and p.interactor.target != null \
			and is_instance_valid(p.interactor.target):
		t = ClassicTargetFrame.subject_of(p.interactor.target)
		why = "use" if t != null else ""
	if t == null and _hit != null and is_instance_valid(_hit) and _hit_t > 0.0:
		t = _hit
		why = "hit"
	if t != null and t == p.riding:
		t = null
	target = t
	target_why = why if t != null else ""
	var dist := -1.0
	if t is Node3D:
		var tp := (t as Node3D).global_position
		dist = Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(tp.x, tp.z))
	target_frame.show_target(t, dist)


## What the crosshair is on: the camera's ray (AIM_REACH with a weapon raised or a spell readied, else LOOK_REACH),
## its first hit taken back to one of the target frame's kinds (null none).
func _ray() -> Node:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not player.is_inside_tree():
		return null
	var aiming := (player.weapon != null and player.weapon.aim > 0.5 and not player.hands_free) \
			or (player.hotbar != null and player.hotbar.spell != "")
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var ex: Array[RID] = [player.get_rid()]
	if player.riding != null and is_instance_valid(player.riding):
		ex.append(player.riding.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (AIM_REACH if aiming else LOOK_REACH), 0xFFFFFFFF, ex)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return ClassicTargetFrame.subject_of(hit.get("collider") as Node)


## A shot or a blow landed (Projectile, ThrownProjectile, AxeMelee: group hit_listeners): its target is the last hit.
func on_projectile_hit(collider: Object, _pos: Vector3) -> void:
	var s := ClassicTargetFrame.subject_of(collider as Node) if collider is Node else null
	if s != null:
		_hit = s
		_hit_t = HIT_KEEP_S
		_tick = TICK_S                 # (shown at once)


func on_target_killed(_t: Node) -> void:
	pass


# --- the screens ----------------------------------------------------------------------------------------------------

## Opens a screen from a button: "gear" or "skills" (the character screen, InventoryScreen: as Tab and K, one at a time,
## not dead or riding), "settings" (the pause menu's Settings), "group:<name>" (a node in that group with toggle()).
func open(screen: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	if screen.begins_with("group:"):
		var n := get_tree().get_first_node_in_group(StringName(screen.substr(6)))
		if n != null and n.has_method(&"toggle"):
			n.call(&"toggle")
		return
	if screen == "settings":
		var pm := get_tree().current_scene.find_child("PauseMenu", false, false) as PauseMenu if get_tree().current_scene else null
		if pm != null and not pm.is_open() and pm._can_open():
			pm.open()
			pm._settings()
		return
	if player.is_dead or player.riding != null:
		return
	var cur: Variant = player.get("_inv_screen")
	if is_instance_valid(cur) and cur is InventoryScreen:
		(cur as InventoryScreen).show_tab(screen)
		return
	player.set("_inv_screen", InventoryScreen.open_for(player, screen))
