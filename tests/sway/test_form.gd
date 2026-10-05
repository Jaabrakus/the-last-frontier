extends SceneTree
## The Sway v2's Form art (FormCast, FormEffects, FormCircle, FormRaised, FormSpikes, FormStone, FormHollow, SwayPose;
## scripts/sway, data/sway/moves.json art "form"; the clips in animations_extra/Frontier_Form.res; the owner's rules,
## docs/main_story.md 11.10) and Gust's stones (GustLift: the owner folded Levitate into Gust) on the level's player, the hands
## free, survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/sway/test_form.gd -- survival=on
##   api       give=form's grant (SwayCaster.give_arg): the four Form spells (earth wall, stone form, pillar, mend; no
##             levitate, no shape planks), the belt full, not on the hotbar (the Tab screen's Spells list: dragged on), none
##             readied; spells() lists them with gust (kind "spell", their SVG icons, their modes); ready_spell() readies only a
##             spell one has and only from the bar (the test drags each onto slot 9 first, as the player would); the five
##             clips are there (the floor cast's three and the two pushes, their moments)
##   no spell  nothing readied: the aim on the ground locks nothing
##   mastery   untrained the floor cast (own-form-clap-press) at x1.4, the caster held still while it plays (W held: no
##             step; rooted, free again after); the self pillar's cast in stride from practised; practised the two-handed
##             push (own-sway-push-two) at x1.0 and no lock with a pistol drawn ("weapon"); expert the one-handed push
##             (own-sway-push-one, "reach_l") at x0.8, the pistol kept in the right hand through the hotbar's key, its fire
##             still its own and its aim the spell's while the spell is readied
##   mode key  sway_mode on the middle mouse; the key flips Stone Form spike -> cannonball (and back), the HUD's line names
##             it and the hotbar slot carries its corner mark; Pillar self -> free; the modes saved
##   wall      Earth Wall untrained: the circle draws itself as the lock fills, the clap and press (the palms on the ground),
##             full, let go: the release, two motes, a wall past the circle that blocks a ray and gives cover; a hollow (the
##             circle and its crackle on a layer the hollows' decals do not darken); four
##             musket hits and it crumbles
##   pillar    self, standing: it rises under the player and lifts them about 3 m; self while running: launched up and
##             forward, a boost when let go on a foot plant (the step cycle) and none between; self in the air: it rises
##             where they come down; free: at the aimed circle, not under the player, and 8.5 m off (its 10 m reach)
##   stone     thrown (the user, 2026-10-03: "Stone Form throws itself"): spike: locked on the ground under a militiaman 7 m off,
##             a jagged spike bursts up a step in front of the caster (a hollow there), flies at him and strikes him
##             (Hit.deliver), staggering him; cannonball: a ball about 0.5 m across comes up in front of the caster, flies
##             along the aim and rests on the ground on, in the physics
##   gust      Gust's lock on a ball raised 3 m off (a stone: GustLift.is_stone; a crate is none): it tears free and rises while held,
##   stones    drawn like a bowstring (draw 0..1), the motes spent; let go along the aim at a militiaman: hurled, he is
##             struck, it lands and rolls. Held on a spike past its break: the power breaks, it drops, the caster staggers,
##             the motes lost (no cast). A boulder (group sway_boulders) too heavy for one: no lock, the hint "heavy"; a light
##             one is lifted
##   mend      a charred wall made whole, a burning one put out, a fire's ruin stood up again (charred), each taking wood from
##             the pack (the press on the wall's face for an upright)
## The gated rules: free use off here (SwayCaster.free_override false: a spell only once granted, the motes spent), as the
## story will want them back; free use itself (the user, 2026-10-03: "lets make the spells free use right now") is
## tests/sway/test_free_use.gd.
## Ends with "FORM TEST PASSED (<n> checks)" or "FORM TEST FAILED (<f> of <n>)".

const LANE_X := -1.25
var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var c: SwayCaster
var ev := {"started": [], "locked": [], "cast": [], "broken": [], "readied": [], "hold": [], "hurled": [], "over": []}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	SwayCaster.free_override = false          # (the gated rules: see the header)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _ground(x: float, z: float) -> Vector3:
	var h := FrontierTerrain.height_at(x, z)
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 3.0, z), Vector3(x, h - 3.0, z), 1, [player.get_rid()])
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3(x, h, z)


func _place_player(z := -24.0) -> void:
	player.global_position = _ground(LANE_X, z) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = 0.0


func _aim(p: Vector3) -> void:
	var d := p - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _hold_on(pt: Callable, limit: float, cond := Callable()) -> float:
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t < limit:
		await physics_frame
		if pt.is_valid():
			_aim(pt.call())
		if cond.is_valid() and cond.call():
			return t
		t += dt
	return INF if cond.is_valid() else t


func _release() -> void:
	Input.action_release("aim")
	await _ticks(3)


func _clear_ev() -> void:
	for k in ev:
		(ev[k] as Array).clear()


## Readies `id` as the player does (spells only from the bar): dragged onto slot 9 when it is not on the bar yet (what was
## there to the pack), then readied (as its key would: the bar follows the caster).
func _ready_spell(id: String) -> bool:
	var hb := player.hotbar
	if id != "" and hb != null and hb.slot_of(Hotbar.SPELL, id) < 0:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make(Hotbar.SPELL, id))
	return c.ready_spell(id)


## Readies `spell`, holds the aim on `pt` until the lock is full (or `limit`), lets go: whether it was cast.
func _cast(spell: String, pt: Callable, limit := 5.0) -> bool:
	_clear_ev()
	_ready_spell(spell)
	await _hold_on(pt, 0.15)
	Input.action_press("aim")
	var t := await _hold_on(pt, limit, func() -> bool: return c.state == SwayCaster.State.FULL)
	if t == INF:
		print("    (no full lock: state %s, move %s, hint '%s', form hint '%s', broken %s, blocked '%s')" % [SwayCaster.State.keys()[c.state], c.move,
				c.hint, c.form.hint, str(ev.broken), c.blocked()])
	await _release()
	return not ev.cast.is_empty() and String(ev.cast[0][0]) == spell


func _hollows() -> int:
	return get_nodes_in_group(FormHollow.GROUP).size()


func _stones(kind: String) -> Array:
	return get_nodes_in_group(FormStone.GROUP).filter(func(n: Node) -> bool: return (n as FormStone).kind == kind and not n.is_queued_for_deletion())


## The palms' height over the ground under the player (after the modifiers: skeleton_updated).
func _palm_height() -> float:
	var sk := player.skeleton
	var got := {}
	var grab := func() -> void:
		got["l"] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("l_palm")).origin
		got["r"] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_palm")).origin
	sk.skeleton_updated.connect(grab)
	await process_frame
	await process_frame
	sk.skeleton_updated.disconnect(grab)
	if got.size() < 2:
		return INF
	var g := _ground(player.global_position.x, player.global_position.z).y
	return maxf((got.l as Vector3).y, (got.r as Vector3).y) - g


func _hands_free() -> void:
	for i in 16:
		if player.hands_free and not player.is_switching():
			break
		if not player.is_switching() and not player.hands_free:
			player.toggle_hands_free()
		await _secs(0.25)
	await _secs(0.3)


func _run() -> void:
	for i in 25:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(player != null, "the level has the player")
	if player == null:
		_end()
		return
	player.ignore_mouse_capture = true
	_strict_gust()
	for i in 60:
		await process_frame
	_place_player()
	await _hands_free()
	_expect(player.hands_free and not player.is_switching(), "the player's hands are free (H)")
	await _api()
	await _no_spell()
	await _mastery()
	await _mode_key()
	await _wall()
	await _pillar()
	await _stone()
	await _gust_stones()
	await _mend()
	_end()


# ---------------------------------------------------------------- the api, the clips
func _api() -> void:
	_expect(SwayCaster.give_arg(player, "form") and not SwayCaster.give_arg(player, "musket"),
			"give=form grants through the caster (an item is left to the pack)")
	c = SwayCaster.of(player)
	_expect(c != null and c.form != null and c.pose != null, "the caster installed, its Form side (FormCast) and its body's clips (SwayPose)")
	var ids := ["earth_wall", "stone_form", "pillar", "mend"]
	var all_have := true
	for id in ids:
		all_have = all_have and c.has(id)
	# (never onto the hotbar by themselves, the owner 2026-10-02: "pickups shouldnt auto fill": they wait in the Tab screen's
	# Spells list for the player to drag; none readied: spells only from the bar)
	var hb := player.get_node_or_null(^"Hotbar")
	var on_bar := 0
	if hb != null and hb.has_method(&"slot_of"):
		for id in ids:
			if int(hb.call(&"slot_of", "spell", id)) >= 0:
				on_bar += 1
	_expect(all_have and not c.has("gust") and c.motes == c.belt_max and on_bar == 0 and c.readied_spell == "",
			"the four Form spells granted, the belt full (%d), none on the hotbar (%d), none readied (%s)" % [c.motes, on_bar, c.readied_spell])
	_expect(SwayMoves.move("shape_planks").is_empty() and SwayMoves.move("stone_spikes").is_empty() and SwayMoves.move("levitate").is_empty()
			and not c.has("shape_planks") and not c.has("levitate") and SwayCaster.spell_icon("levitate") == null and not FormModels.has("form_levitate"),
			"Shape Planks dropped, Stone Spikes replaced by Stone Form, no Levitate (Gust lifts the stones): no entry, no icon")
	var sp := SwayCaster.spells()
	var sp_ids := sp.map(func(e: Dictionary) -> String: return String(e.id))
	var icons_ok := true
	for e: Dictionary in sp:
		icons_ok = icons_ok and String(e.icon) == "spell_" + String(e.id) and SwayCaster.spell_icon(String(e.id)) != null and String(e.kind) == "spell"
	icons_ok = true
	for e: Dictionary in sp.slice(0, 5):
		icons_ok = icons_ok and String(e.icon) == "spell_" + String(e.id) and SwayCaster.spell_icon(String(e.id)) != null and String(e.kind) == "spell"
	_expect(sp_ids.slice(0, 5) == ["gust", "earth_wall", "stone_form", "pillar", "mend"] and icons_ok and sp_ids.has("fire_blast"),
			"spells(): gust and the four first, each a {kind spell, id} with its icon, then the bending skills (%d in all)" % sp_ids.size())
	var modes := {}
	for e: Dictionary in sp:
		modes[String(e.id)] = e.modes
	_expect(str(modes.stone_form) == str(["spike", "cannonball", "disc"]) and str(modes.pillar) == str(["self", "free", "ramp"])
			and str(modes.gust) == str(["push", "pull", "lift"]),
			"their modes: stone form spike / cannonball / disc, pillar self / free / ramp, gust push / pull / lift")
	_expect(c.known_spells().size() == 4, "known_spells(): the four granted (%d)" % c.known_spells().size())
	c.spell_readied.connect(func(id: String) -> void: ev.readied.append(id))
	var off_bar := c.ready_spell("pillar")
	_expect(not c.ready_spell("gust") and not c.ready_spell("first_lock") and not off_bar and _ready_spell("pillar") and c.readied_spell == "pillar"
			and ev.readied == ["pillar"] and player.get_meta(SwayCaster.SPELL_META, "") == "pillar",
			"ready_spell(): only a spell one has, and only from the bar (off it refused; on slot 9 pillar readied, spell_readied, the player's meta)")
	c.set_uses("pillar", 0)
	var stride0 := c.sprint_ok("pillar")
	c.set_uses("pillar", 8)
	var stride1 := c.sprint_ok("pillar")
	c.set_uses("pillar", 0)
	_expect(not stride0 and stride1, "the self pillar's cast in stride (a sprint keeps its lock): practised and up, not untrained (rooted)")
	var icon := FormModels.build("form_stone_form")
	_expect(icon != null and icon.find_children("*", "MeshInstance3D", true, false).size() >= 3, "an icon's model (ItemIcons draws it)")
	icon.free()
	c.ready_spell("")
	_expect(not player.has_meta(SwayCaster.SPELL_META), "none readied: the meta gone")
	var crate := RigidBody3D.new()
	_expect(c.move_for(crate) == "", "unreadied, no move is picked for a target")
	crate.free()
	var lib := load(SwayPose.CLIPS) as AnimationLibrary
	var names := [SwayPose.CLAP_PRESS, SwayPose.RELEASE, SwayPose.PRESS_WALL, SwayPose.PUSH_TWO, SwayPose.PUSH_ONE]
	var ok := lib != null
	for n in names:
		ok = ok and lib.has_animation(n)
	_expect(ok, "the clips: the floor cast's three and own-sway-push-two, own-sway-push-one")
	if ok:
		var cp := lib.get_animation(SwayPose.CLAP_PRESS)
		var p2 := lib.get_animation(SwayPose.PUSH_TWO)
		var p1 := lib.get_animation(SwayPose.PUSH_ONE)
		_expect(float(cp.get_meta(&"clap_s")) < float(cp.get_meta(&"press_s")) and p2.has_meta(&"hold_s") and p2.has_meta(&"back_s")
				and float(p2.get_meta(&"hold_s")) < float(p2.get_meta(&"push_s")) and p1.has_meta(&"hold_s") and p2.get_track_count() > 40
				and String(p2.get_meta(&"authored", "")).contains("form_clips.py"),
				"their moments (the push's wind-up held at %.2f s, the push at %.2f s), the whole body keyed (%d tracks), authored by form_clips.py" % [
				float(p2.get_meta(&"hold_s")), float(p2.get_meta(&"push_s")), p2.get_track_count()])
	c.lock_started.connect(func(m: String, t: Node3D) -> void: ev.started.append([m, t]))
	c.locked.connect(func(m: String, t: Node3D) -> void: ev.locked.append([m, t]))
	c.cast.connect(func(m: String, t: Node3D) -> void: ev.cast.append([m, t]))
	c.lock_broken.connect(func(m: String, t: Node3D, why: String) -> void: ev.broken.append([m, t, why]))
	c.hold_started.connect(func(m: String, t: Node3D) -> void: ev.hold.append([m, t]))
	c.hurled.connect(func(m: String, t: Node3D) -> void: ev.hurled.append([m, t]))
	c.overstrained.connect(func(m: String, t: Node3D) -> void: ev.over.append([m, t]))


# ---------------------------------------------------------------- no spell readied: nothing
func _no_spell() -> void:
	_place_player()
	await _secs(0.3)
	c.ready_spell("")
	var g := _ground(LANE_X, -26.6)
	var at := func() -> Vector3: return g
	_clear_ev()
	Input.action_press("aim")
	await _hold_on(at, 0.6)
	_expect(c.state == SwayCaster.State.IDLE and ev.started.is_empty() and not c.readied and float(player.get(&"_aim_cam_w")) < 0.05,
			"no spell readied: the aim on the ground locks nothing, no ring, the camera stays")
	await _release()


# ---------------------------------------------------------------- mastery: the hands, the clip, the time
func _lock_begin(spell: String, pt: Callable, secs := 0.4) -> void:
	_clear_ev()
	_ready_spell(spell)
	await _hold_on(pt, 0.12)
	Input.action_press("aim")
	await _hold_on(pt, secs)


func _mastery() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(c.belt_max)
	var g := _ground(LANE_X, -26.6)
	var at := func() -> Vector3: return g
	# untrained: the floor cast, x1.4
	c.set_uses("earth_wall", 0)
	await _lock_begin("earth_wall", at)
	_expect(c.tier("earth_wall") == 0 and c.state == SwayCaster.State.LOCKING and c.pose.anim_name == "own-form-clap-press"
			and is_equal_approx(c.lock_s, 1.6 * 1.4), "untrained: the floor cast (%s), the lock x1.4 (%.2f s)" % [c.pose.anim_name, c.lock_s])
	# (the owner's rule: kneel and press the palms to the floor while the ring fills: no walking off with the body bent)
	var p0 := player.global_position
	Input.action_press("move_forward")
	await _hold_on(at, 0.5)
	var spd := player.horizontal_speed()
	var moved := Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
	_expect(c.rooted and player.drag_speed_cap == SwayCaster.ROOT_CAP and spd < 0.3 and moved < 0.25 and c.state == SwayCaster.State.LOCKING,
			"untrained: held still while the floor cast plays (W held 0.5 s: %.2f m/s, %.2f m)" % [spd, moved])
	Input.action_release("move_forward")
	await _release()
	await _secs(0.8)
	_expect(not c.rooted and player.drag_speed_cap == INF, "the floor cast over: free to move again")
	# practised (by use: mastery_uses 8): the two-handed push, x1.0
	c.set_uses("earth_wall", 8)
	await _lock_begin("earth_wall", at)
	var pose := player.skeleton.get_node_or_null(^"SwayCastPose") as ToolPose
	var masks := (pose.layers as Array).map(func(l: Dictionary) -> String: return String(l.mask)) if pose != null else []
	_expect(c.tier("earth_wall") == 1 and c.state == SwayCaster.State.LOCKING and c.pose.anim_name == "own-sway-push-two"
			and is_equal_approx(c.lock_s, 1.6) and "upper" in masks, "practised: the two-handed push (%s, %s), the lock x1.0 (%.2f s)" % [c.pose.anim_name, str(masks), c.lock_s])
	await _release()
	_expect(c.pose.phase == "up" or c.pose.phase == "", "let go early: no cast, the push eased out (%s)" % c.pose.phase)
	await _secs(0.8)
	# a pistol drawn: practised (and untrained) want both hands empty
	player.switch_weapon("pistol")
	for i in 40:
		if player.weapon_key == "pistol" and not player.is_switching() and player.weapon.active:
			break
		await _secs(0.1)
	var pistol := player.weapon
	_expect(player.weapon_key == "pistol" and pistol.active, "the pistol drawn")
	_ready_spell("earth_wall")
	await _hold_on(at, 0.1)
	Input.action_press("aim")
	await _hold_on(at, 0.5)
	_expect(c.state == SwayCaster.State.IDLE and c.blocked() == "weapon" and not c.keeps_weapon("earth_wall"),
			"practised with a pistol in hand: no lock (%s)" % c.blocked())
	await _release()
	# expert: one palm; through the hotbar's key the pistol stays in the right hand, held (not fired) while readied
	c.set_uses("earth_wall", 30)
	c.ready_spell("")
	var hb := player.get_node_or_null(^"Hotbar") as Hotbar
	var slot := 8
	if hb != null:
		hb.assign(slot, Hotbar.make("spell", "earth_wall"))
		hb.select(slot)
		await _ticks(6)
	else:
		c.ready_spell("earth_wall")
	_expect(c.readied_spell == "earth_wall" and player.weapon_key == "pistol" and not player.hands_free and pistol.active and c.keeps_weapon("earth_wall"),
			"expert: readied from the hotbar with the pistol kept in the right hand (hands free %s)" % player.hands_free)
	_expect(pistol._fire_input_enabled() and not pistol._aim_input_enabled(),
			"the pistol still fires while the spell is readied, its aim (RMB) the spell's")
	await _hold_on(at, 0.1)
	Input.action_press("aim")
	await _hold_on(at, 0.4)
	pose = player.skeleton.get_node_or_null(^"SwayCastPose") as ToolPose
	masks = (pose.layers as Array).map(func(l: Dictionary) -> String: return String(l.mask)) if pose != null else []
	_expect(c.tier("earth_wall") == 2 and c.state == SwayCaster.State.LOCKING and c.pose.anim_name == "own-sway-push-one"
			and is_equal_approx(c.lock_s, 1.6 * 0.8) and masks == ["reach_l"],
			"expert: the one-handed push (%s, %s: the right arm left to the pistol), the lock x0.8 (%.2f s)" % [c.pose.anim_name, str(masks), c.lock_s])
	var t := await _hold_on(at, 2.0, func() -> bool: return c.state == SwayCaster.State.FULL)
	await _release()
	_expect(t < 2.0 and ev.cast.size() == 1 and c.uses_of("earth_wall") == 31 and c.pose.phase == "release",
			"expert: cast with the pistol in hand, the push plays, a use counted (%d)" % c.uses_of("earth_wall"))
	for w in get_nodes_in_group(FormRaised.GROUP):
		w.queue_free()
	if hb != null:
		hb.select(slot)                       # (the key again: the spell put down, the pistol kept; its other skill, Earth
		await _ticks(4)                       # Grip, is not had here: free use off, the four granted)
		_expect(c.readied_spell == "" and player.weapon_key == "pistol" and not player.hands_free and pistol._fire_input_enabled(),
				"its key again puts the spell down (its other skill not had); the pistol stays drawn, its own again")
		hb.clear(slot)
	c.ready_spell("")
	c.set_uses("earth_wall", 0)
	await _hands_free()
	_expect(player.hands_free, "hands free again")


# ---------------------------------------------------------------- the mode key
func _mode_key() -> void:
	var evs := InputMap.action_get_events(SwayCaster.MODE_ACTION) if InputMap.has_action(SwayCaster.MODE_ACTION) else []
	var mmb := evs.any(func(e: InputEvent) -> bool: return e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE)
	_expect(mmb, "the mode key: %s on the middle mouse button (rebindable)" % SwayCaster.MODE_ACTION)
	var hb := player.get_node_or_null(^"Hotbar") as Hotbar
	var hud: FrontierHUD = player.hud
	var slot := 8
	if hb != null:
		hb.assign(slot, Hotbar.make("spell", "stone_form"))
		hb.select(slot)
	else:
		c.ready_spell("stone_form")
	var changed: Array = []
	var cb := func(id: String, m: String) -> void: changed.append([id, m])
	c.mode_changed.connect(cb)
	await _ticks(4)
	await process_frame
	var line0 := hud._ammo.text if hud != null else ""
	_expect(c.readied_spell == "stone_form" and c.mode_of("stone_form") == "spike" and (hud == null or line0.begins_with("Stone Form (spike)")),
			"Stone Form readied in its first mode, spike; the HUD's line names it (%s)" % line0)
	var key := InputEventAction.new()
	key.action = SwayCaster.MODE_ACTION
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await _ticks(3)
	await process_frame
	var line1 := hud._ammo.text if hud != null else ""
	var mark := ""
	if hud != null:
		for box: Array in hud._slot_boxes:
			var tr := box[1] as TextureRect
			if String(tr.get_meta(&"kind", "")) == "spell:stone_form":
				mark = String((box[0] as Control).get_meta(&"mode", ""))
	_expect(c.mode_of("stone_form") == "cannonball" and str(changed) == str([["stone_form", "cannonball"]]) and (hud == null or line1.begins_with("Stone Form (boulder)"))
			and (hud == null or mark == "cannonball"), "the key flips it to cannonball (mode_changed), the HUD's line (%s) and the slot's corner mark (%s)" % [line1, mark])
	_expect(c.flip_mode() == "disc" and c.flip_mode() == "spike" and c.mode_of("stone_form") == "spike", "on to disc, and back to spike")
	c.mode_changed.disconnect(cb)
	_expect(c.mode_of("pillar") == "self" and c.flip_mode("pillar") == "free" and c.mode_of("pillar") == "free" and c.flip_mode("pillar") == "ramp" and c.flip_mode("pillar") == "self",
			"pillar: self by default, flips to free and back")
	c.set_mode("stone_form", "cannonball")
	var sv := c.save_data()
	c.modes.clear()
	c.load_data({"modes": sv.modes, "uses": sv.uses})
	_expect(c.mode_of("stone_form") == "cannonball", "the modes saved (%s)" % str(sv.modes))
	c.set_mode("stone_form", "spike")
	if hb != null:
		hb.select(slot)
		hb.clear(slot)
	c.ready_spell("")


# ---------------------------------------------------------------- the earth wall (untrained: the floor cast)
func _wall() -> void:
	_place_player()
	await _secs(0.4)
	c.set_motes(c.belt_max)
	var g := _ground(LANE_X, -26.6)
	var at := func() -> Vector3: return g
	var h0 := _hollows()
	_clear_ev()
	_ready_spell("earth_wall")
	await _hold_on(at, 0.15)
	Input.action_press("aim")
	await _hold_on(at, 0.4)
	var circ := c.form.circle
	_expect(c.state == SwayCaster.State.LOCKING and c.move == "earth_wall" and c.target == c.form.mark and ev.started.size() == 1,
			"wall: the aim on the ground locks Earth Wall on the place (%s, %s)" % [SwayCaster.State.keys()[c.state], c.move])
	_expect(circ != null and is_instance_valid(circ) and circ.global_position.distance_to(g) < 0.2 and circ.radius > 1.0,
			"wall: the circle comes up on the ground there (%.2f m off)" % (circ.global_position.distance_to(g) if circ else INF))
	var hol := get_nodes_in_group(FormHollow.GROUP)
	var crk := c.form.crackle
	_expect(circ != null and circ.layers == FormCircle.FX_LAYER and crk != null and crk.layers == FormCircle.FX_LAYER
			and (hol.is_empty() or ((hol[0] as FormHollow).cull_mask & FormCircle.FX_LAYER) == 0),
			"wall: the circle and its crackle on their own layer, outside the hollows' decal mask (no older hollow darkens them)")
	var f0 := circ.fill if circ else 0.0
	_expect(c.pose.phase == "press" and c.pose.anim_name == "own-form-clap-press" and c.pose.weight > 0.9,
			"wall: the hands clap and press (%s %s, weight %.2f)" % [c.pose.phase, c.pose.anim_name, c.pose.weight])
	_expect(c.arm.weight < 0.01 and not c.thread.visible, "wall: no pointing arm, no thread (the circle instead)")
	await _hold_on(at, 0.5)
	var ph := await _palm_height()
	_expect(ph < 0.25, "wall: past the press the palms are on the ground (%.2f m over it)" % ph)
	_expect(circ != null and is_instance_valid(circ) and circ.fill > f0 + 0.15 and circ.fill < 1.0,
			"wall: the circle draws itself as the lock fills (%.2f -> %.2f)" % [f0, circ.fill if circ else -1.0])
	var pose := player.skeleton.get_node_or_null(^"SwayCastPose") as ToolPose
	var still_w := float((pose.layers[1] as Dictionary).weight) if pose != null and pose.layers.size() == 2 else -1.0
	var at0 := player.global_position
	Input.action_press("move_left")
	await _hold_on(at, 0.35)
	var walk_w := float((pose.layers[1] as Dictionary).weight) if pose != null and pose.layers.size() == 2 else -1.0
	var up_w := float((pose.layers[0] as Dictionary).weight) if pose != null and pose.layers.size() == 2 else -1.0
	var stepped := Vector2(player.global_position.x - at0.x, player.global_position.z - at0.z).length()
	Input.action_release("move_left")
	_expect(still_w > 0.9 and walk_w > 0.9 and up_w > 0.9 and stepped < 0.2 and c.state != SwayCaster.State.IDLE,
			"wall: kneeling, the caster is held still (A held: %.2f m), the squat whole (%.2f -> %.2f, the upper body %.2f), the lock held" % [
			stepped, still_w, walk_w, up_w])
	await _hold_on(at, 0.3)
	var t := await _hold_on(at, 2.0, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(t < 2.0 and ev.locked.size() == 1 and circ.full, "wall: full (locked), the circle whole and pulsing")
	await _release()
	_expect(ev.cast.size() == 1 and ev.cast[0][0] == "earth_wall" and c.motes == c.belt_max - 2 and c.uses_of("earth_wall") == 1,
			"wall: let go, it is cast, two motes spent (%d left), a use counted" % c.motes)
	_expect(c.pose.phase == "release" and c.pose.anim_name == "own-form-release", "wall: the palms push down and the body stands (%s)" % c.pose.anim_name)
	var walls := get_nodes_in_group(FormRaised.GROUP)
	var wall: FormRaised = walls[walls.size() - 1] if not walls.is_empty() else null
	_expect(wall != null and wall.kind == "wall" and _hollows() == h0 + 1, "wall: a wall raised, a hollow where its earth came from (%d)" % (_hollows() - h0))
	await _secs(1.0)
	_expect(wall != null and wall.is_up() and wall.global_position.z < g.z - 0.3, "wall: it has risen, past the circle (%.2f m on)" % ((g.z - wall.global_position.z) if wall else 0.0))
	_expect(c.pose.phase == "", "wall: the release over, the body the game's again")
	_expect(get_nodes_in_group(FormCircle.GROUP).is_empty(), "wall: the circle has faded away (%d left)" % get_nodes_in_group(FormCircle.GROUP).size())
	var eye := player.global_position + Vector3.UP * 1.3
	var far := Vector3(LANE_X, eye.y - 0.3, -32.0)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, far, 0xFFFFFFFF, [player.get_rid()]))
	_expect(not hit.is_empty() and hit.collider == wall, "wall: it stands in the way (a ray down the lane meets it)")
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(LANE_X + 0.8, -29.6), {"tag": "form_cover", "seed": 11})
	var f: NpcFighter = sq.members[0]
	await _secs(0.5)
	var threat := _ground(LANE_X, -16.0)
	var spot := NpcCover.find(f, threat) if f != null else Vector3.INF
	var behind := spot != Vector3.INF and spot.z < wall.global_position.z - 0.2 and Vector2(spot.x - wall.global_position.x, spot.z - wall.global_position.z).length() < 2.6
	_expect(behind, "wall: a fighter takes cover behind it (NpcCover: %s)" % str(spot))
	sq.queue_free()
	await _ticks(3)
	var wid := wall.get_instance_id() if wall else 0
	for i in 4:
		Hit.deliver(wall, 60.0, wall.global_position + Vector3.UP, Vector3.FORWARD, null)
	_expect(wall.state == FormRaised.State.CRUMBLING, "wall: four musket hits and it crumbles")
	await _secs(wall.crumble_s + 0.3)
	_expect(not is_instance_valid(instance_from_id(wid)), "wall: gone back into the ground")


# ---------------------------------------------------------------- the pillar: self (standing, running, in the air) and free
func _pillars() -> Array:
	return get_nodes_in_group(FormRaised.GROUP).filter(func(n: Node) -> bool: return (n as FormRaised).kind == "pillar" and not n.is_queued_for_deletion())


func _clear_pillars() -> void:
	for p in _pillars():
		p.queue_free()
	await _ticks(3)


func _pillar() -> void:
	# self, standing: under the player wherever the aim is
	_place_player()
	await _secs(0.4)
	c.set_motes(c.belt_max)
	c.set_mode("pillar", "self")
	var y0 := player.global_position.y
	var ahead := func() -> Vector3: return _ground(LANE_X, -30.0)
	var ok := await _cast("pillar", ahead)
	_expect(ok and c.motes == c.belt_max - 1, "pillar self: cast (the aim down the lane: it does not matter), a mote spent (%d)" % c.motes)
	var ps := _pillars()
	var pil: FormRaised = ps[ps.size() - 1] if not ps.is_empty() else null
	_expect(pil != null and String(pil.get_meta(&"pillar_mode", "")) == "stand" and Vector2(pil.global_position.x - player.global_position.x,
			pil.global_position.z - player.global_position.z).length() < 0.5, "pillar self: it rises under the player")
	await _secs(1.8)
	var up := player.global_position.y - y0
	_expect(up > 2.5 and up < 3.4 and player.is_on_floor(), "pillar self: the player carried up on it (%.2f m)" % up)
	await _clear_pillars()
	await _secs(0.8)
	# self while running (practised, to keep the lane): launched up and forward; a boost on a foot plant
	var boosted := await _run_launch(true)
	await _clear_pillars()
	var plain := await _run_launch(false)
	await _clear_pillars()
	_expect(not boosted.is_empty() and not plain.is_empty() and bool(boosted.boost) and not bool(plain.boost)
			and (boosted.velocity as Vector3).y > (plain.velocity as Vector3).y + 1.0,
			"pillar self running: on the foot plant a boost (up %.1f m/s, gap %.3f s), between steps none (up %.1f m/s, gap %.3f s)" % [
			(boosted.get("velocity", Vector3.ZERO) as Vector3).y, float(boosted.get("gap", INF)), (plain.get("velocity", Vector3.ZERO) as Vector3).y,
			float(plain.get("gap", INF))])
	# (a timing, not a coin toss: the share of a stride a release at random gets the boost in)
	var ld: Dictionary = (SwayMoves.move("pillar").get("pillar", {}) as Dictionary).get("launch", {})
	var win := float(ld.get("plant_window_s", 0.0)) + float(ld.get("plant_after_s", 0.0))
	var share_run := win * 3.6 / float(Footsteps.STRIDE.run)
	var share_sprint := win * 5.6 / float(Footsteps.STRIDE.sprint)
	_expect(share_run < 0.3 and share_sprint < 0.3, "pillar self running: the boost's moment is a timing (%.0f%% of a run's stride, %.0f%% of a sprint's)"
			% [share_run * 100.0, share_sprint * 100.0])
	# self in the air: it rises where they come down
	_place_player()
	await _secs(0.5)
	c.set_motes(c.belt_max)
	c.set_uses("pillar", 8)
	_clear_ev()
	_ready_spell("pillar")
	Input.action_press("aim")
	var t := await _hold_on(Callable(), 2.5, func() -> bool: return c.state == SwayCaster.State.FULL)
	var gy := player.global_position.y
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	await _hold_on(Callable(), 0.8, func() -> bool: return not player.is_on_floor() and player.global_position.y > gy + 0.7)
	var in_air := not player.is_on_floor()
	var feet_y := player.global_position.y
	await _release()
	ps = _pillars()
	pil = ps[ps.size() - 1] if not ps.is_empty() else null
	_expect(t < 2.5 and in_air and pil != null and String(pil.get_meta(&"pillar_mode", "")) == "air",
			"pillar self in the air: cast mid-jump (%s)" % (String(pil.get_meta(&"pillar_mode", "")) if pil else "none"))
	var top := -INF
	for i in 100:
		await physics_frame
		top = maxf(top, player.global_position.y)
	_expect(pil != null and Vector2(pil.global_position.x - player.global_position.x, pil.global_position.z - player.global_position.z).length() < 0.6
			and player.is_on_floor() and player.global_position.y > gy + 0.35 and top < feet_y + 0.6 and not player.is_dead,
			"pillar self in the air: it rose where they came down, under their feet (%.2f m), they land on it (%.2f m up), not thrown (top %.2f m)" % [
			pil.size.y if pil else 0.0, player.global_position.y - gy, top - gy])
	await _clear_pillars()
	await _secs(0.6)
	# free: at the aimed circle
	_place_player()
	await _secs(0.5)
	c.set_motes(c.belt_max)
	c.set_mode("pillar", "free")
	var spot := _ground(LANE_X, -26.6)
	ok = await _cast("pillar", func() -> Vector3: return spot)
	ps = _pillars()
	pil = ps[ps.size() - 1] if not ps.is_empty() else null
	_expect(ok and pil != null and String(pil.get_meta(&"pillar_mode", "")) == "free" and Vector2(pil.global_position.x - spot.x, pil.global_position.z - spot.z).length() < 0.4
			and Vector2(pil.global_position.x - player.global_position.x, pil.global_position.z - player.global_position.z).length() > 2.0,
			"pillar free: at the aimed circle 2.6 m ahead, not under the player")
	await _secs(1.5)
	await _clear_pillars()
	# free reaches far (the owner's "move the pillar anywhere": mode_range_m.free), self stays under the caster
	_place_player()
	await _secs(0.5)
	c.set_motes(c.belt_max)
	var far := _ground(LANE_X, -32.5)
	ok = await _cast("pillar", func() -> Vector3: return far)
	ps = _pillars()
	pil = ps[ps.size() - 1] if not ps.is_empty() else null
	var reach := c.range_of("pillar")
	c.set_mode("pillar", "self")
	_expect(ok and pil != null and Vector2(pil.global_position.x - far.x, pil.global_position.z - far.z).length() < 0.6 and is_equal_approx(reach, 10.0)
			and is_equal_approx(c.range_of("pillar"), 3.2), "pillar free: 8.5 m off too (its reach %.0f m in free, 3.2 m in self)" % reach)
	c.set_mode("pillar", "free")
	await _secs(1.5)
	await _clear_pillars()
	c.set_mode("pillar", "self")
	c.set_uses("pillar", 0)
	await _secs(0.5)


## A self pillar cast while running down the lane (practised), let go with the step cycle on a foot plant (`on_plant`) or
## between two: c.last_launch, and the player carried up and forward ({} when it did not cast).
func _run_launch(on_plant: bool) -> Dictionary:
	_place_player(-21.5)
	await _secs(0.5)
	c.set_motes(c.belt_max)
	c.set_uses("pillar", 8)
	c.set_mode("pillar", "self")
	_clear_ev()
	_ready_spell("pillar")
	Input.action_press("move_forward")
	await _secs(0.6)
	Input.action_press("aim")
	var t := await _hold_on(Callable(), 2.5, func() -> bool: return c.state == SwayCaster.State.FULL)
	var speed := player.horizontal_speed()
	var z0 := player.global_position.z
	var y0 := player.global_position.y
	var fs := player.get_node_or_null(^"Footsteps") as Footsteps
	if fs != null:
		var stride := float(Footsteps.STRIDE.get(fs._gait(speed), 1.15))
		fs.set(&"_moving", true)
		fs.set(&"_acc", stride - speed * 0.02 if on_plant else stride * 0.5 - speed / Engine.physics_ticks_per_second)    # (on: 20 ms before it)
	Input.action_release("aim")
	await _ticks(2)
	Input.action_release("move_forward")
	var out := c.last_launch.duplicate()
	var top := y0
	for i in 40:
		await physics_frame
		top = maxf(top, player.global_position.y)
	var fwd := z0 - player.global_position.z
	_expect(t < 2.5 and speed > 2.6 and ev.cast.size() == 1 and not out.is_empty() and top > y0 + 1.0 and fwd > 1.5,
			"pillar self running (%.1f m/s, %s): launched up %.2f m and %.2f m on" % [speed, "on a plant" if on_plant else "between plants", top - y0, fwd])
	for i in 90:
		if player.is_on_floor():
			break
		await physics_frame
	await _secs(0.3)
	return out


# ---------------------------------------------------------------- stone form: spike and cannonball
func _stone() -> void:
	# spike, thrown (the user, 2026-10-03: "Stone Form throws itself"): at a militiaman 7 m off
	_place_player()
	await _secs(0.4)
	c.set_motes(c.belt_max)
	c.set_mode("stone_form", "spike")
	var pp := player.global_position
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(LANE_X, -31.0), {"face": pp, "tag": "form_dummy", "seed": 7})
	var f: NpcFighter = sq.members[0]
	await _secs(0.8)
	_expect(f != null and not f.is_dead(), "spike: a militiaman stands 7 m down the lane")
	var h0 := _hollows()
	var hp0 := f.health
	var d0 := Vector2(f.global_position.x - pp.x, f.global_position.z - pp.z)
	var at := func() -> Vector3: return NpcSenses.chest_of(f)
	player.health = player.max_health
	var before := get_nodes_in_group(FormStone.GROUP)
	var ok := await _cast("stone_form", at)
	_expect(ok and c.motes == c.belt_max - 2, "spike: locked on the ground under him, cast, two motes (%d left)" % c.motes)
	var fresh := get_nodes_in_group(FormStone.GROUP).filter(func(n: Node) -> bool: return not before.has(n))
	var spike: FormStone = fresh[0] if not fresh.is_empty() else null
	var off := Vector2(spike.global_position.x - pp.x, spike.global_position.z - pp.z).length() if spike else INF
	_expect(spike != null and spike.kind == "spike" and spike.height > 1.5 and off < 2.3 and _hollows() == h0 + 1,
			"spike: a jagged spike (%.2f m) bursts up a step in front of the caster (%.2f m), a hollow there" % [spike.height if spike else 0.0, off])
	var flinched := false
	var most := 0.0
	for i in 60:
		await physics_frame
		flinched = flinched or f.action == "flinch"
		most = maxf(most, Vector2(f.global_position.x - pp.x, f.global_position.z - pp.z).distance_to(d0))
	_expect(f.health < hp0, "spike: it flies at him and strikes him (%.0f -> %.0f)" % [hp0, f.health])
	_expect(flinched or most > 0.2, "spike: and staggers him (%.1f m, staggered %s)" % [most, flinched])
	_expect(player.health >= player.max_health - 0.01, "spike: the caster untouched")
	sq.queue_free()
	if is_instance_valid(spike):
		spike.queue_free()
	await _secs(0.5)
	# cannonball: a stone ball rises in front of the caster, flies along the aim and rolls to rest
	c.set_motes(c.belt_max)
	c.set_mode("stone_form", "cannonball")
	var g := _ground(LANE_X + 1.2, -29.0)
	before = get_nodes_in_group(FormStone.GROUP)
	ok = await _cast("stone_form", func() -> Vector3: return g)
	fresh = get_nodes_in_group(FormStone.GROUP).filter(func(n: Node) -> bool: return not before.has(n))
	var ball: FormStone = fresh[0] if not fresh.is_empty() else null
	off = Vector2(ball.global_position.x - pp.x, ball.global_position.z - pp.z).length() if ball else INF
	_expect(ok and ball != null and absf(ball.radius * 2.0 - 0.5) < 0.1 and off < 2.3,
			"cannonball: cast, a stone ball %.2f m across comes up in front of the caster" % ((ball.radius * 2.0) if ball else 0.0))
	var y_mid := ball.global_position.y if ball else 0.0
	await _secs(0.2)
	var rising := ball != null and ball.global_position.y > y_mid + 0.3
	await _secs(2.5)
	var gy := FormEffects.ground_at(ball, ball.global_position).y if ball else 0.0      # (the ground under it, not the ball)
	_expect(ball != null and rising and ball.is_risen() and not ball.freeze and absf(ball.global_position.y - gy - ball.radius) < 0.12
			and Vector2(ball.global_position.x - pp.x, ball.global_position.z - pp.z).length() > 3.0,
			"cannonball: it rose, flew along the aim and rests on the ground on, in the physics (%.2f m over the ground)" % ((ball.global_position.y - gy) if ball else -1.0))
	if is_instance_valid(ball):
		ball.queue_free()
	c.set_mode("stone_form", "spike")


# ---------------------------------------------------------------- Gust's stones (GustLift)
## A boulder (group sway_boulders) of `kg` at `at`: a fixed body with a rock's mesh, its weight in meta sway_mass_kg.
func _boulder(at: Vector3, kg: float, r := 0.4) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "TestBoulder"
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = r
	cs.shape = sp
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = FormModels.ball_mesh(r, 17)
	b.add_child(mi)
	b.add_to_group(GustLift.BOULDERS)
	b.set_meta(&"sway_mass_kg", kg)
	current_scene.add_child(b)
	b.global_position = at + Vector3.UP * r
	return b


func _gust_stones() -> void:
	_place_player()
	await _secs(0.3)
	c.set_motes(c.belt_max)
	c.grant("gust", false)
	c.set_uses("gust", 0)
	# (a ball raised 3 m off where it rests: Stone Form throws its own now, FormEffects.stone_form)
	var ball := FormStone.ball(current_scene, _ground(LANE_X + 1.2, -27.0), SwayMoves.move("stone_form").get("cannonball", {}), 3)
	await _secs(1.0)
	_expect(ball != null and ball.is_risen(), "gust stones: the cannonball lies 3 m off")
	if ball == null:
		return
	var crate := RigidBody3D.new()
	_expect(SwayCaster.kind_of(ball) == "stone" and GustLift.is_stone(ball) and not GustLift.is_stone(crate) and SwayCaster.kind_of(crate) == "prop"
			and SwayCaster.holds("gust", ball) and not SwayCaster.holds("gust", crate),
			"a raised cannonball is a stone Gust holds; a crate is a prop it pushes")
	crate.free()
	var pp := player.global_position
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(LANE_X, -32.5), {"face": pp, "tag": "form_target", "seed": 9})
	var f: NpcFighter = sq.members[0]
	await _secs(0.8)
	var hp0 := f.health
	var rest_y := ball.global_position.y
	var on_ball := func() -> Vector3: return ball.global_position
	_clear_ev()
	_ready_spell("gust")
	await _hold_on(on_ball, 0.12)
	Input.action_press("aim")
	var t := await _hold_on(on_ball, 2.5, func() -> bool: return c.state == SwayCaster.State.HOLDING)
	var lock0 := float((SwayMoves.move("gust").get("stone", {}) as Dictionary).get("lock_s", 0.8)) * c.tier_mult("gust")
	_expect(t < 2.5 and ev.hold.size() == 1 and ev.hold[0][0] == "gust" and ev.hold[0][1] == ball and c.hold is GustLift and c.motes == c.belt_max - 1
			and is_equal_approx(c.lock_s, lock0) and c.pose.anim_name == "own-form-clap-press",
			"gust on the ball: the lock (%.2f s, the stone's x1.4 untrained, the floor cast) full at %.2f s: the hold begins, a mote spent (%d)" % [c.lock_s, t, c.motes])
	await _hold_on(on_ball, 0.5)
	var draw_mid := c.hold.draw if c.hold != null else -1.0
	var risen := ball.global_position.y - rest_y
	_expect(risen > 0.3 and ball.freeze and GustLift.busy(ball) and c.move_for(ball) == "", "gust on the ball: it tears free and rises while held (%.2f m up), no second lock on it" % risen)
	var aim_f := func() -> Vector3: return NpcSenses.chest_of(f)
	await _hold_on(aim_f, 0.9)
	var draw_full := c.hold.draw if c.hold != null else -1.0
	_expect(draw_mid > 0.0 and draw_mid < 1.0 and draw_full >= 0.999 and c.hold.strain == 0.0 and c.state == SwayCaster.State.HOLDING,
			"gust on the ball: drawn like a bowstring (%.2f -> %.2f), no strain yet" % [draw_mid, draw_full])
	var struck: Array = []
	var lift := c.hold
	lift.struck.connect(func(who: Node, dmg: float) -> void: struck.append([who, dmg]))
	var landed: Array = []
	lift.landed.connect(func(p: Vector3) -> void: landed.append(p))
	var u0 := c.uses_of("gust")
	await _release()
	_expect(ev.hurled.size() == 1 and ev.cast.size() == 1 and ev.cast[0][0] == "gust" and c.state == SwayCaster.State.IDLE and c.uses_of("gust") == u0 + 1,
			"gust on the ball: let go, it is hurled along the aim (cast, a use of Gust counted)")
	for i in 120:
		await physics_frame
		if not landed.is_empty():
			break
	_expect(not struck.is_empty() and struck[0][0] == f and f.health < hp0, "gust on the ball: the militiaman is struck (%.0f -> %.0f, %s)" % [hp0, f.health, str(struck)])
	await _ticks(2)
	var v := ball.linear_velocity.length() if is_instance_valid(ball) else 0.0
	_expect(not landed.is_empty() and is_instance_valid(ball) and not ball.freeze and v > 0.5 and not GustLift.busy(ball),
			"gust on the ball: it lands and rolls on (%.1f m/s), a stone again" % v)
	sq.queue_free()
	await _secs(1.0)
	if is_instance_valid(ball):
		ball.queue_free()
	# held too long on a spike: the power breaks
	_place_player()
	await _secs(0.3)
	c.set_motes(c.belt_max)
	c.set_mode("stone_form", "spike")
	var sg := _ground(LANE_X + 1.0, -27.5)
	var spike := FormStone.spike(current_scene, sg, Vector3.FORWARD, SwayMoves.move("stone_form").get("spike", {}), 5)
	var ok := spike != null
	await _secs(0.4)
	c.set_motes(c.belt_max)
	_expect(ok and spike != null, "gust stones: a spike raised 3.5 m off")
	if spike == null:
		return
	var m0 := c.motes
	var on_spike := func() -> Vector3: return spike.global_transform * Vector3(0.0, spike.height * 0.5, 0.0)
	_clear_ev()
	_ready_spell("gust")
	await _hold_on(on_spike, 0.12)
	Input.action_press("aim")
	t = await _hold_on(on_spike, 2.5, func() -> bool: return c.state == SwayCaster.State.HOLDING)
	var ahead := func() -> Vector3: return _ground(LANE_X, -40.0) + Vector3.UP * 1.5
	var strained := [0.0]
	var t2 := await _hold_on(ahead, 7.0, func() -> bool:
		if c.hold != null and is_instance_valid(c.hold):
			strained[0] = maxf(float(strained[0]), c.hold.strain)
		return not ev.over.is_empty())
	await _ticks(2)
	_expect(t < 2.5 and t2 < 7.0 and float(strained[0]) > 0.5 and ev.over.size() == 1 and ev.over[0][0] == "gust" and ev.cast.is_empty() and c.last_break == "strain",
			"gust on the spike: held past its break (%.1f s, strain %.2f) the power breaks (overstrained, no cast)" % [t2, float(strained[0])])
	_expect(c.motes == m0 - 1, "gust on the spike: the motes lost (%d -> %d)" % [m0, c.motes])
	await _secs(0.4)
	_expect(is_instance_valid(spike) and not spike.freeze and not GustLift.busy(spike), "gust on the spike: it dropped where it hung")
	_expect(c.state == SwayCaster.State.IDLE and not c.readied, "gust on the spike: the caster staggered, the lock gone (no new one until the aim is let go)")
	await _release()
	if is_instance_valid(spike):
		spike.queue_free()
	# a ship's boulder: too heavy for one (two casters: the hook), a light one lifted
	_place_player()
	await _secs(0.3)
	c.set_motes(c.belt_max)
	var heavy := _boulder(_ground(LANE_X + 0.8, -30.0), 300.0, 0.55)
	await _ticks(3)
	var on_heavy := func() -> Vector3: return heavy.global_position
	_clear_ev()
	await _hold_on(on_heavy, 0.12)
	Input.action_press("aim")
	await _hold_on(on_heavy, 1.4)
	_expect(GustLift.casters_needed(heavy) == 4 and c.state == SwayCaster.State.IDLE and ev.started.is_empty() and c.hint == "heavy",
			"gust on a 300 kg boulder: too heavy for one (%d casters), no lock, the hint '%s'" % [GustLift.casters_needed(heavy), c.hint])
	await _release()
	heavy.queue_free()
	var light := _boulder(_ground(LANE_X + 0.8, -30.0), 60.0, 0.35)
	await _ticks(3)
	var at_light := light.global_position
	var on_light := func() -> Vector3: return light.global_position
	_clear_ev()
	await _hold_on(on_light, 0.12)
	Input.action_press("aim")
	t = await _hold_on(on_light, 2.5, func() -> bool: return c.state == SwayCaster.State.HOLDING)
	await _hold_on(on_light, 0.6)
	var up := light.global_position.y - at_light.y if is_instance_valid(light) else 0.0
	_expect(t < 2.5 and ev.hold.size() == 1 and ev.hold[0][1] == light and up > 0.3 and c.hold.kind == "stone",
			"gust on a 60 kg boulder (group sway_boulders): held up (%.2f m)" % up)
	await _release()
	await _secs(1.5)
	_expect(ev.hurled.size() == 1 and is_instance_valid(light) and Vector2(light.global_position.x - at_light.x, light.global_position.z - at_light.z).length() > 1.0
			and not GustLift.busy(light), "and hurled, it lands away down the lane")
	if is_instance_valid(light):
		light.queue_free()
	c.ready_spell("")


# ---------------------------------------------------------------- mend
func _mend() -> void:
	_place_player()
	await _secs(0.4)
	c.set_motes(c.belt_max)
	var world := BuildWorld.of(self)
	var fire := FireSpread.of(self)
	var x := LANE_X
	var z := -26.4
	var xf := Transform3D(Basis(), Vector3(x, FrontierTerrain.height_at(x, z), z))
	var piece := world.add_piece("wall", xf, true, -1)
	await _ticks(3)
	var inv := InventoryState.from_player(player)
	inv.add("log", 4)
	player.inventory_pack = inv.pack.duplicate(true)
	var logs := func() -> int: return InventoryState.from_player(player).pack_count("log")
	var l0: int = logs.call()
	# charred: made whole
	FireRuin.char_geometry(piece.highlight_targets(), INF, 0.0)
	_expect(FormEffects.mend_stage(piece) == "charred", "mend: a wall standing charred (%s)" % FormEffects.mend_stage(piece))
	var face := func() -> Vector3:
		return Vector3(x, piece.global_position.y + 1.2, z) + (player.global_position - piece.global_position).slide(Vector3.UP).normalized() * 0.05
	var ok := await _cast("mend", face)
	_expect(ok and not FormEffects.charred(piece) and logs.call() == l0 - 1,
			"mend: cast on its face, it is made whole, a log from the pack (%d -> %d)" % [l0, logs.call()])
	_expect(c.pose.anim_name == "own-form-press-wall", "mend: the palms pressed onto the upright (%s)" % c.pose.anim_name)
	await _secs(1.0)
	# alight: put out
	c.set_motes(c.belt_max)
	fire.ignite(piece)
	await _ticks(2)
	_expect(FormEffects.mend_stage(piece) == "alight", "mend: the wall set alight (%s)" % fire.stage_of(piece))
	ok = await _cast("mend", face)
	_expect(ok and not fire.is_burning(piece) and logs.call() == l0 - 2, "mend: the fire drawn out of it (%d logs)" % logs.call())
	await _secs(1.0)
	# a ruin: stood up again, charred
	c.set_motes(c.belt_max)
	var box: AABB = fire._box_of(piece)
	var ruin := FireRuin.of_piece(fire._ruins_root, piece, box)
	fire.ruins.append(ruin)
	world.remove_piece(piece)
	await _ticks(3)
	_expect(FormEffects.mend_stage(ruin) == "ruin" and world.near(xf.origin, 1.0).is_empty(), "mend: then only its ruin left")
	var ground := func() -> Vector3: return _ground(x + 0.6, z + 0.35)
	ok = await _cast("mend", ground)
	await _ticks(3)
	var again := world.near(xf.origin, 1.0)
	_expect(ok and not is_instance_valid(ruin) and again.size() == 1 and (again[0] as BuiltPiece).type == "wall" and FormEffects.charred(again[0])
			and logs.call() == l0 - 4, "mend: the ruin stands again as the wall, charred, two logs (%d left)" % logs.call())
	await _secs(1.0)
	for p in again:
		world.remove_piece(p)
	c.set_motes(c.belt_max)
	await _ticks(3)


func _end() -> void:
	Input.action_release("aim")
	if fails.is_empty():
		print("FORM TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("FORM TEST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)

## Gust under the strict rules these checks were written for: the art's cone, grace and release window, the 0.6 s and 0.8 s
## locks, the stone's strain and break. Its own easier rules (lock_rules, the stone's no_break, the quicker locks: the
## user's 2026-10-03 choice "easier Gust everywhere") are checked in tests/sway/test_free_use.gd. Set in memory only.
func _strict_gust() -> void:
	var g := SwayMoves.move("gust")
	g.erase("lock_rules")
	g["lock_s"] = 0.6
	var st: Dictionary = g.get("stone", {})
	st["lock_s"] = 0.8
	(st.get("hold", {}) as Dictionary)["no_break"] = false
