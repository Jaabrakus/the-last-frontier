class_name BuildMode
extends Node
## Building (user 2026-09-26: "so they can build windows logs forts and etc"): build mode puts what is in the
## hands away and shows the piece to build as a ghost at the crosshair (shaders/interact/ghost.gdshader: green
## where it can go, red where it cannot, with the reason under it). Pieces cost logs and stone from the pack
## (data/building/building.json) and snap to each other (BuildSnap); taking one down gives part of its cost
## back. Placing a piece gives Building experience (GatherSkills "building": data/gathering/gathering.json
## skills.building.xp); the skill raises what taking down gives back.
##
## Controls (build mode):
##   B            build mode on / off (a weapon key, H, 7 / 8 or mounting a horse also ends it)
##   mouse wheel  the piece to build; the last choice is Take down
##   R            turn the piece a quarter (on a socket: end for end)
##   hold Alt     (Option on a Mac) snap: onto the other pieces' sockets and the ground's grid (user 2026-10-02: "i dont like the snap
##                effect, we should allow them to put it freely"); without it the piece goes where the crosshair is,
##                turned with the camera, at any angle (a gable and a roof always snap: they rest on wall tops)
##   hold E       brighter ghost; letting go of E builds it there (the placement convention of PlayerInteractor)
##   tap E        as ever: open a door, take an item; with Take down chosen, takes the piece under the crosshair
##                down (its prompt says what comes back)
## The pieces themselves: BuiltPiece, BuildWorld (the "Building" node of the level), BuildGeometry, BuildDoor.

signal placed(piece: BuiltPiece)
signal taken_down(type: String, refund: Dictionary)

const ACTION := &"build_mode"
const KEY := KEY_B
## Held, the piece snaps (Alt: the horse's walking gait, nothing on foot; build mode ends on a horse).
const SNAP_ACTION := &"walk"
const AIM_RANGE := 24.0
const SOUND_PATH := "res://audio/sfx/gathering/%s_%02d.wav"
const GHOST_OK := Color(0.42, 1.0, 0.5, 0.42)
const GHOST_BAD := Color(1.0, 0.3, 0.24, 0.42)
const ARMED_ALPHA := 0.7
## Physics ticks between two placement updates (120 Hz physics: 60 a second).
const REFRESH_EVERY := 2

## The player's build mode while it is on (one player).
static var current: BuildMode

var player: FrontierPlayer
var data: BuildData
var active := false
## The chosen entry: data.order[index], or Take down at data.order.size().
var index := 0
## R presses (quarter turns on the ground, flips on a socket).
var steps := 0
## The camera ray's hit {position, normal, collider}, or {}.
var aim := {}
## The chosen placement {xf, kind, support, grounded, score} and its BuildSnap.check() verdict.
var cand := {}
var verdict := {}
## Take down: the piece under the crosshair.
var aimed_piece: BuiltPiece
## E held long enough: letting go builds.
var armed := false
## Tests and captures: the crosshair is taken to rest on this point (a ray straight down onto it from 1 m above)
## instead of the camera's (INF: the camera's).
var aim_at := Vector3.INF
## With aim_at: the ray comes from here through aim_at instead (a wall's face from the side).
var aim_from := Vector3.INF
## With aim_at the placement snaps as with Alt held (the tests and the films aim at sockets) unless this is set.
var scripted_free := false
var hud: BuildHud
var rng := RandomNumberGenerator.new()

var _ghost: Node3D
var _ghost_key := ""
var _ghost_mat: ShaderMaterial
var _press_t := -1.0
var _was_e := false
var _was_b := false
var _was_r := false
var _streams := {}
var _tick := 0
var _last_sel := Vector3i(-1, -1, -1)


static func install(p: FrontierPlayer) -> BuildMode:
	var m := BuildMode.new()
	m.name = "BuildMode"
	m.player = p
	p.add_child(m)
	return m


static func ensure_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var e := InputEventKey.new()
	e.physical_keycode = KEY
	InputMap.action_add_event(ACTION, e)


func _ready() -> void:
	ensure_input()
	rng.seed = 1754
	data = BuildData.get_default()
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = load("res://shaders/interact/ghost.gdshader")
	hud = BuildHud.new()
	hud.name = "BuildHud"
	add_child(hud)
	hud.visible = false
	Campfire.ensure_striker.call_deferred(player)    # flint and steel for the campfires


func _exit_tree() -> void:
	if current == self:
		current = null
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()


## The chosen piece type ("" for Take down).
func piece_type() -> String:
	return data.order[index] if index < data.order.size() else ""


func taking_down() -> bool:
	return index >= data.order.size()


## Chooses entry `i` (wraps; data.order.size() is Take down).
func select(i: int) -> void:
	index = posmod(i, data.order.size() + 1)
	steps = 0


func select_type(type: String) -> void:
	var i := data.order.find(type)
	select(i if i >= 0 else data.order.size())


func toggle() -> void:
	set_active(not active)


func set_active(on: bool) -> void:
	if on == active:
		return
	if on:
		if player.is_dead or player.riding != null:
			return
		if player.gather and player.gather.tool != "":
			player.gather.put_away()
		if not player.hands_free and player.weapon and player.weapon.active:
			player.toggle_hands_free()
		current = self
	else:
		if current == self:
			current = null
		aimed_piece = null
		cand = {}
		verdict = {}
		armed = false
		_press_t = -1.0
	active = on
	_last_sel = Vector3i(-1, -1, -1)
	hud.visible = on
	if _ghost:
		_ghost.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed(&"weapon_next") or event.is_action_pressed(&"weapon_prev"):
		select(index + (1 if event.is_action_pressed(&"weapon_next") else -1))
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var b := InputMap.has_action(ACTION) and Input.is_action_pressed(ACTION)
	if b and not _was_b:
		toggle()
	_was_b = b
	if not active:
		return
	if _must_leave():
		set_active(false)
		return
	var r := InputMap.has_action(&"reload") and Input.is_action_pressed(&"reload")
	if r and not _was_r:
		steps += 1
	_was_r = r
	# the placement is worked out every REFRESH_EVERY ticks (the checks cast a few dozen rays and boxes), and at
	# once when the piece, its turn or the snap changes
	_tick += 1
	var sel := Vector3i(index, steps, int(snapping()))
	if _tick % REFRESH_EVERY == 0 or sel != _last_sel:
		_last_sel = sel
		aim = _cast()
		refresh_placement()
		_show_ghost()
		hud.refresh(self)
	_read_e(delta)


## A weapon or a tool came into the hands, the player got on a horse or died.
func _must_leave() -> bool:
	if player.is_dead or player.riding != null:
		return true
	if player.weapon and player.weapon.active and not player.hands_free:
		return true
	var g := player.gather
	return g != null and g.tool != "" and g.phase in [GatherTools.Phase.DRAW_GRAB, GatherTools.Phase.DRAW_OUT,
			GatherTools.Phase.READY, GatherTools.Phase.SWING]


func _read_e(delta: float) -> void:
	var down := Input.is_action_pressed(ThrownPickup.INTERACT)
	var pressed := down and not _was_e
	var released := _was_e and not down
	_was_e = down
	if released and _press_t >= 0.0:
		var held := _press_t >= PlayerInteractor.HOLD_S
		_press_t = -1.0
		armed = false
		if held and not taking_down():
			place()
		return
	if pressed:
		_press_t = 0.0
	elif down and _press_t >= 0.0:
		_press_t += delta
	elif not down:
		_press_t = -1.0
	var was_armed := armed
	armed = down and _press_t >= PlayerInteractor.HOLD_S and not taking_down()
	if armed != was_armed:
		_show_ghost()
		hud.refresh(self)


# --- Aim and placement --------------------------------------------------------------------------------------

func _cast() -> Dictionary:
	var cam := player.get_viewport().get_camera_3d()
	var from := cam.global_position if cam else Vector3.ZERO
	var to := from - cam.global_transform.basis.z * AIM_RANGE if cam else Vector3.ZERO
	if aim_at.is_finite():
		from = aim_from if aim_from.is_finite() else aim_at + Vector3.UP
		to = aim_at + (aim_at - from).normalized()
	elif cam == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var p: Vector3 = hit.position
	if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > data.reach:
		return {"far": true, "position": p}
	return hit


## Whether the piece snaps (Alt held; a scripted aim always, unless scripted_free).
func snapping() -> bool:
	if aim_at.is_finite():
		return not scripted_free
	return InputMap.has_action(SNAP_ACTION) and Input.is_action_pressed(SNAP_ACTION)


func aim_point() -> Vector3:
	return aim.get("position", player.global_position) as Vector3


## Works out the placement (or the piece to take down) for the current aim.
func refresh_placement() -> void:
	cand = {}
	verdict = {}
	aimed_piece = null
	if taking_down():
		if not aim.is_empty() and not aim.has("far"):
			aimed_piece = piece_of(aim.get("collider"))
		return
	if data.opening(piece_type()) != "":
		_opening_placement(data.opening(piece_type()))
		return
	if aim.is_empty():
		verdict = {"ok": false, "reason": "Look at the ground or at your building"}
		return
	if aim.has("far"):
		verdict = {"ok": false, "reason": "Too far away"}
		return
	var type := piece_type()
	var world := BuildWorld.of(get_tree(), false)
	# snapping (or a piece that only rests on others): the sockets near the crosshair, then the ground on the grid;
	# free: only where the crosshair is
	var snap := snapping() or not data.free_standing(type)
	var list: Array = BuildSnap.candidates(type, world, aim.position, data.snap_radius, steps % 2 == 1) if world and snap else []
	var free := _free_candidate(type, snap)
	if not free.is_empty():
		list.append(free)
	if list.is_empty():
		verdict = {"ok": false, "reason": "Needs a wall to sit on" if not data.free_standing(type) else "Look at the ground"}
		return
	# what the pack holds of everything the piece costs (logs and stone; firewood, poles, branches for camp pieces)
	var have := {"log": pack_count("log"), "stone": pack_count("stone")}
	for k: String in data.cost(type):
		have[k] = pack_count(k)
	var space := player.get_world_3d().direct_space_state
	for i in mini(list.size(), BuildSnap.MAX_CANDIDATES):
		var c: Dictionary = list[i]
		var v := BuildSnap.check(type, c, world, space, have, data)
		if v.ok or cand.is_empty():
			cand = c
			verdict = v
		if v.ok:
			break


## The piece standing on its own under the crosshair: on the ground (or, for a hearth or a post, on a floor; placed
## freely a wall too). `snap`: on the ground's grid and turned in its steps; else exactly there, at any angle.
func _free_candidate(type: String, snap := true) -> Dictionary:
	if not data.free_standing(type):
		return {}
	var col: Object = aim.get("collider")
	var n: Vector3 = aim.get("normal", Vector3.ZERO)
	if not (col is Node) or n.y < 0.6:
		return {}
	var node := col as Node
	var grounded := true
	if node.is_in_group(BuiltPiece.BODY_GROUP):
		var p := piece_of(node)
		if p != null and (BuildSnap.OVERLAP_OK.get(type, []) as Array).has(p.type):
			pass                                   # aimed at a piece it may stand over (a drying rack over a campfire)
		elif p == null or p.type != "floor" or not (type in ["hearth", "post"] or data.on_floor(type)
				or (not snap and type in ["wall", "wall_window", "wall_door"])):
			return {}
		else:
			grounded = false
	elif not (node.is_in_group(&"terrain") or node is StaticBody3D) or node.is_in_group(&"trees"):
		return {}
	var cam := player.get_viewport().get_camera_3d()
	var fwd := -cam.global_transform.basis.z if cam else -player.global_transform.basis.z
	var view_yaw := atan2(-fwd.x, -fwd.z)
	var xf := BuildSnap.free_xf(aim.position, view_yaw, steps, data.grid if snap else 0.0, data.yaw_step if snap else 0.0)
	return {"xf": xf, "kind": "", "support": -1,
			"grounded": grounded, "score": data.snap_radius}


## The BuiltPiece a collider belongs to (null for anything else).
static func piece_of(col: Variant) -> BuiltPiece:
	var n := col as Node if col is Node else null
	while n:
		if n is BuiltPiece:
			return n
		n = n.get_parent()
	return null


# --- Building and taking down -------------------------------------------------------------------------------

## Builds the chosen piece where the ghost shows it (when it can go there). Returns the piece or null.
func place() -> BuiltPiece:
	if taking_down() or not bool(verdict.get("ok", false)):
		if verdict.has("reason") and player.interactor:
			player.interactor.notice(String(verdict.reason))
		return null
	var type := piece_type()
	var c := data.cost(type)
	var inv := InventoryState.from_player(player)
	for k: String in c:
		inv.take(k, int(c[k]))
	player.inventory_pack = inv.pack.duplicate(true)
	if data.opening(type) != "":
		_close_opening(type, c)
		return null
	var world := BuildWorld.of(get_tree())
	var p := world.add_piece(type, verdict.xf, bool(verdict.grounded), int(cand.get("support", -1)), verdict.get("ground", PackedFloat32Array()))
	var sk := skills()
	if sk:
		sk.award("building", sk.xp("building", "piece") + sk.xp("building", "log") * int(c.get("log", 0))
				+ sk.xp("building", "stone") * int(c.get("stone", 0)))
	_sound("mattock_stone" if type in ["hearth", "floor", "campfire"] else "axe_buck", p.global_position + Vector3.UP, -4.0,
			&"ball_hit_stone" if type in ["hearth", "floor", "campfire"] else &"arrow_hit_wood")
	if player.interactor:
		player.interactor.notice("Built: %s  (-%s)" % [data.name_of(type), BuildData.cost_text(c)])
	placed.emit(p)
	return p


## Closing an opening cut in the palisade (PalisadeCuts; user 2026-09-26: "each one hole we cut we need to either be able to
## build a doors there or cover it up with logs or repair it"; 2026-09-28: "a cut opening can be filled back in"): the opening
## the crosshair looks into, and whether `kind` (BuildData.opening: repair / cover) can be done there.
func _opening_placement(kind: String) -> void:
	var world := BuildWorld.of(get_tree(), false)
	if world == null:
		verdict = {"ok": false, "reason": "Look into an opening cut in the palisade"}
		return
	var ray := _aim_ray()
	if ray.is_empty():
		verdict = {"ok": false, "reason": "Look into an opening cut in the palisade"}
		return
	var op := PalisadeCuts.opening_at(world, ray[0], ray[1], player.global_position, kind, [player.get_rid()])
	if not bool(op.get("ok", false)):
		verdict = {"ok": false, "reason": String(op.get("reason", ""))}
		return
	cand = {"xf": op.xf, "opening": op}
	var c := data.cost(piece_type())
	for k: String in c:
		if pack_count(k) < int(c[k]):
			verdict = {"ok": false, "reason": "Needs %s" % BuildData.cost_text(c), "xf": op.xf, "opening": op}
			return
	verdict = {"ok": true, "xf": op.xf, "opening": op}


## The crosshair's ray [from, direction] (the camera's; aim_at / aim_from in tests), [] without a camera.
func _aim_ray() -> Array:
	if aim_at.is_finite():
		var from := aim_from if aim_from.is_finite() else aim_at + Vector3.UP
		return [from, (aim_at - from).normalized()]
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return []
	return [cam.global_position, -cam.global_transform.basis.z]


func _close_opening(type: String, c: Dictionary) -> void:
	var world := BuildWorld.of(get_tree(), false)
	var op: Dictionary = verdict.get("opening", {})
	if world == null or op.is_empty():
		return
	match data.opening(type):
		"repair":
			PalisadeCuts.repair(world, op)
		"cover":
			PalisadeCuts.cover(world, op)
	var sk := skills()
	if sk:
		sk.award("building", sk.xp("building", "piece") + sk.xp("building", "log") * int(c.get("log", 0)))
	var at: Vector3 = (op.xf as Transform3D).origin
	_sound("axe_buck", at, -4.0, &"arrow_hit_wood")
	if player.interactor:
		player.interactor.notice("Built: %s  (-%s)" % [data.name_of(type), BuildData.cost_text(c)])
	cand = {}
	verdict = {}


## The ghost of a closing: a panel the opening's size where it will go.
func _show_opening_ghost(type: String) -> void:
	var op: Dictionary = verdict.get("opening", cand.get("opening", {}))
	if op.is_empty():
		if _ghost:
			_ghost.visible = false
		return
	var sz: Vector3 = op.size
	var key := "%s|%.2f|%.2f" % [type, sz.x, sz.y]
	if _ghost == null or not is_instance_valid(_ghost):
		_ghost = Node3D.new()
		_ghost.name = "BuildGhost"
		get_tree().current_scene.add_child(_ghost)
		_ghost_key = ""
	if key != _ghost_key:
		for ch in _ghost.get_children():
			ch.queue_free()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sz.x, sz.y, sz.z + 0.04)
		mi.mesh = bm
		mi.material_override = _ghost_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost.add_child(mi)
		_ghost_key = key
	var col := GHOST_OK if bool(verdict.get("ok", false)) else GHOST_BAD
	if armed:
		col.a = ARMED_ALPHA
	_ghost_mat.set_shader_parameter(&"ghost_color", col)
	_ghost.global_transform = op.xf
	_ghost.visible = true


## Takes `p` down (when nothing rests on it): part of its cost back into the pack. True when done.
func take_down(p: BuiltPiece) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	var world := BuildWorld.of(get_tree(), false)
	if world == null:
		return false
	var deps := world.dependents(p)
	if not deps.is_empty():
		if player.interactor:
			player.interactor.notice("Take the %s off it first" % data.name_of(deps[0].type).to_lower())
		return false
	var back := refund_of(p.type)
	var inv := InventoryState.from_player(player)
	for k: String in back:
		inv.add(k, int(back[k]))
	player.inventory_pack = inv.pack.duplicate(true)
	var type := p.type
	_sound("axe_chop", p.global_position + Vector3.UP, -5.0, &"ball_hit_wood")
	if aimed_piece == p:
		aimed_piece = null
	world.remove_piece(p)
	if player.interactor:
		player.interactor.notice("Taken down: %s  (+%s)" % [data.name_of(type), BuildData.cost_text(back)])
	taken_down.emit(type, back)
	return true


## What taking a `type` down gives back at the player's Building skill.
func refund_of(type: String) -> Dictionary:
	var sk := skills()
	return data.refund(type, sk.yield_bonus("building") if sk else 0.0)


func take_down_prompt() -> String:
	if aimed_piece == null or not is_instance_valid(aimed_piece):
		return ""
	var world := BuildWorld.of(get_tree(), false)
	var deps := world.dependents(aimed_piece) if world else []
	var nm := data.name_of(aimed_piece.type).to_lower()
	if not deps.is_empty():
		return "The %s rests on the %s" % [data.name_of(deps[0].type).to_lower(), nm]
	return "Take down the %s  (+%s)" % [nm, BuildData.cost_text(refund_of(aimed_piece.type))]


func skills() -> GatherSkills:
	return player.gather.skills if player.gather else null


## Logs or stone in the pack.
func pack_count(kind: String) -> int:
	var n := 0
	for e: Dictionary in player.inventory_pack:
		if String(e.get("kind", "")) == kind:
			n += int(e.get("count", 0))
	return n


# --- Ghost ---------------------------------------------------------------------------------------------------

func _show_ghost() -> void:
	if taking_down() or cand.is_empty():
		if _ghost:
			_ghost.visible = false
		return
	var type := piece_type()
	if data.opening(type) != "":
		_show_opening_ghost(type)
		return
	var xf: Transform3D = verdict.get("xf", cand.xf)
	var ground: PackedFloat32Array = verdict.get("ground", PackedFloat32Array())
	var world := BuildWorld.of(get_tree(), false)
	var grounded := bool(verdict.get("grounded", cand.get("grounded", true)))
	var ctx: Dictionary = world.ctx_for(type, xf, grounded, -1, ground) if world else _lone_ctx(type, xf, grounded, ground)
	var key := "%s|%s" % [type, JSON.stringify(ctx)]
	if _ghost == null or not is_instance_valid(_ghost):
		_ghost = Node3D.new()
		_ghost.name = "BuildGhost"
		get_tree().current_scene.add_child(_ghost)
		_ghost_key = ""
	if key != _ghost_key:
		for ch in _ghost.get_children():
			ch.queue_free()
		for g: GeometryInstance3D in BuiltPiece.build_visuals(_ghost, type, 0, ctx, ground, true, false):
			g.material_override = _ghost_mat
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ghost_key = key
	var col := GHOST_OK if bool(verdict.get("ok", false)) else GHOST_BAD
	if armed:
		col.a = ARMED_ALPHA
	_ghost_mat.set_shader_parameter(&"ghost_color", col)
	_ghost.global_transform = xf
	_ghost.visible = true


## The context of a piece with nothing built yet round it.
static func _lone_ctx(type: String, xf: Transform3D, grounded: bool, ground: PackedFloat32Array) -> Dictionary:
	var w := BuildWorld.new()
	var c := w.ctx_for(type, xf, grounded, -1, ground)
	w.free()
	return c


func ghost_node() -> Node3D:
	return _ghost


# --- Sound ---------------------------------------------------------------------------------------------------

## A gathering sound (audio/sfx/gathering/<id>_NN.wav: a random variant, a little pitch spread) at `pos`, the
## Sfx manifest's `fallback` when the files are missing (like GatherTools).
func _sound(id: String, pos: Vector3, gain_db: float, fallback: StringName) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if not _streams.has(id):
		var list: Array = []
		for v in range(1, 9):
			var path := SOUND_PATH % [id, v]
			if not ResourceLoader.exists(path):
				break
			list.append(load(path))
		_streams[id] = list
	var list: Array = _streams[id]
	if list.is_empty():
		if Sfx.has(fallback):
			Sfx.play_3d(fallback, pos, gain_db, rng.randf_range(0.7, 0.85))
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = list[rng.randi() % list.size()]
	p.volume_db = gain_db + rng.randf_range(-1.0, 1.0)
	p.pitch_scale = rng.randf_range(0.8, 0.95)
	p.unit_size = 8.0
	p.max_distance = 120.0
	if AudioServer.get_bus_index(&"World") >= 0:
		p.bus = &"World"
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
