extends SceneTree
## The Form spells' matter and the user's asks of 2026-10-03 on the level's player, free use (every spell an expert's), the
## hands free, survival on, saves in the test folder:
##   Godot --headless --fixed-fps 60 --path . -s tests/sway/test_wall_matter.gd -- survival=on save=on
##   ground  FormMatter.of_ground ("it should be earth wall where if the terrain is mud its a mud wall if its a tree i can make
##           a tree wall you know"): the range lane's packed dirt earth, the brook's bed mud (the splat), the outcrop west of
##           the fort stone (GroundStone's meta surface), a boulder stone (the vegetation's rocks), the lane under 0.3 m of
##           snow (SnowCover.force_depth_m) snow
##   walls   Earth Wall locked and cast on each: the circle drawn in the matter's colour, the lock's line ("Earth Wall: mud")
##           and the HUD's spell line naming it; the wall of that matter, its hits (earth 4, mud 2, stone 7, snow 3), hit_min
##           (stone 15: a 12 is not counted), its crumble, its surface; a fighter takes cover behind it (NpcCover finds its
##           box, whatever its matter; the stone wall's on the open lane: on the outcrop the query's 32 shapes are the
##           rocks', trunks' and saplings'); its last hit and it crumbles
##   tree    near the lane's nearest standing tree: the crosshair on the ground beside it locks the ground, not the tree;
##           on its trunk the tree (its circle round the trunk's foot, the lines say wood); cast: a palisade (wood, 5 hits)
##           just past its foot across the caster's line, the tree gone (felled, its trunk collider gone, the standing trees
##           one fewer), its stump at its foot; cover behind it
##   pillar  the cap ("for the pillar top dont make it see thru"): the cap's triangles face up (their normals up: drawn from
##           above); a mud pillar is mud (3 hits); a self cast high in the air ("the pillar should match the height so if im
##           jumping and cast a pillar underneath me it should quickly make a pillar just as big to catch me"): it rises in
##           0.2 s under them and catches them, their feet on its top, its height their feet's over the ground within 15 cm
##   throw   Stone Form throws itself ("Stone Form throws itself"): a spike at a militiaman 9 m off comes up near the caster,
##           flies at him and strikes him; a cannonball at a crate 9 m off flies and knocks it on; then each lies a stone
##   look    the stones raised from mud look so (FormStone.matter, stone_form.looks: the rock material of that ground)
##   save    the quick save (SaveGame.TEST_DIR, removed after) loaded: the tree still gone, its stump standing
## Writes none of the user's files (its saves in the test folder, deleted at the end).
## Ends with "WALL MATTER TEST PASSED (<n> checks)" or "WALL MATTER TEST FAILED (<f> of <n>)".

const FormMatter := preload("res://scripts/sway/form_matter.gd")
const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const LANE_X := -1.25
const BROOK := Vector2(161.0, -82.0)
const OUTCROP := Vector2(-190.0, -40.0)

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var c: SwayCaster
var ev := {"started": [], "cast": [], "broken": []}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	SwayCaster.free_override = null
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


func _place(p: Vector3, face: Vector3) -> void:
	player.global_position = p + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	var d := face - p
	player.yaw = atan2(-d.x, -d.z)
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


func _ready_spell(id: String) -> bool:
	var hb := player.hotbar
	if id != "" and hb != null and hb.slot_of(Hotbar.SPELL, id) < 0:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make(Hotbar.SPELL, id))
	return c.ready_spell(id)


func _notice() -> String:
	var lb: Variant = player.interactor.get(&"_notice") if player.interactor != null else null
	return (lb as Label).text if lb is Label else ""


func _hud_line(id: String) -> String:
	return String(player.hud.call(&"_spell_line", id)) if player.hud != null else ""


func _hands_free() -> void:
	for i in 16:
		if player.hands_free and not player.is_switching():
			break
		if not player.is_switching() and not player.hands_free:
			player.toggle_hands_free()
		await _secs(0.25)
	await _secs(0.3)


## Locks `spell` on `pt` and lets go once full: {cast, circle_color, lock_line, hud_line, matter, tree, circle_at} as it locked.
func _lock_cast(spell: String, pt: Callable, limit := 4.0) -> Dictionary:
	_clear_ev()
	_ready_spell(spell)
	player.interactor.notice("", 0.05)
	await _hold_on(pt, 0.12)
	Input.action_press("aim")
	var seen := {}
	var t := await _hold_on(pt, limit, func() -> bool:
		if c.state == SwayCaster.State.LOCKING and seen.is_empty() and c.form.circle != null and is_instance_valid(c.form.circle):
			seen["circle_color"] = c.form.circle.color
			seen["circle_at"] = c.form.circle.global_position
			seen["matter"] = c.form.lock_matter
			seen["tree"] = c.form.lock_tree
			seen["hud_line"] = _hud_line(spell)
		if c.state == SwayCaster.State.LOCKING and not seen.has("lock_line") and _notice() != "":
			seen["lock_line"] = _notice()
		return c.state == SwayCaster.State.FULL)
	if t == INF:
		print("    (no full lock: state %s, hint '%s', form hint '%s', blocked '%s')" % [SwayCaster.State.keys()[c.state], c.hint, c.form.hint, c.blocked()])
	await _release()
	seen["cast"] = not ev.cast.is_empty() and String(ev.cast[0][0]) == spell
	return seen


func _walls() -> Array:
	return get_nodes_in_group(FormRaised.GROUP).filter(func(n: Node) -> bool: return (n as FormRaised).kind == "wall" and not n.is_queued_for_deletion())


func _newest(group: StringName, before: Array) -> Node:
	var fresh := get_nodes_in_group(group).filter(func(n: Node) -> bool: return not before.has(n) and not n.is_queued_for_deletion())
	return fresh[fresh.size() - 1] if not fresh.is_empty() else null


func _run() -> void:
	for i in 25:
		await process_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	_expect(player != null, "the level has the player")
	if player == null:
		_end()
		return
	player.ignore_mouse_capture = true
	for i in 60:
		await process_frame
	c = SwayCaster.of(player)
	_expect(c != null and SwayCaster.free_use(), "free use: the level installed the caster")
	if c == null:
		_end()
		return
	c.lock_started.connect(func(m: String, t: Node3D) -> void: ev.started.append([m, t]))
	c.cast.connect(func(m: String, t: Node3D) -> void: ev.cast.append([m, t]))
	c.lock_broken.connect(func(m: String, t: Node3D, why: String) -> void: ev.broken.append([m, t, why]))
	_place(_ground(LANE_X, -24.0), _ground(LANE_X, -30.0))
	await _hands_free()
	_expect(player.hands_free, "the player's hands are free")
	await _ground_kinds()
	await _wall_on("earth", _ground(LANE_X, -24.0), _ground(LANE_X, -26.6))
	await _wall_on("mud", _ground(BROOK.x, BROOK.y + 2.4), _ground(BROOK.x, BROOK.y))
	await _wall_on("stone", _ground(OUTCROP.x + 2.4, OUTCROP.y), _ground(OUTCROP.x, OUTCROP.y))
	await _snow_wall()
	var tree_i := await _tree_wall()
	await _pillar_cap()
	await _pillar_catch()
	await _throws()
	await _save_load(tree_i)
	_end()


# ---------------------------------------------------------------- the ground's matter
func _ground_kinds() -> void:
	var lane := _ground(LANE_X, -26.6)
	var brook := _ground(BROOK.x, BROOK.y)
	var rock := _ground(OUTCROP.x, OUTCROP.y)
	_expect(FormMatter.of_ground(self, lane) == "earth", "ground: the range lane's packed dirt is earth (%s)" % FormMatter.of_ground(self, lane))
	_expect(FormMatter.of_ground(self, brook) == "mud", "ground: the brook's bed is mud (%s, the splat's mud %.2f)" % [FormMatter.of_ground(self, brook),
			FrontierTerrain.ground_layers(brook.x, brook.z)[FrontierTerrain.LAYER_MUD]])
	_expect(FormMatter.of_ground(self, rock) == "stone", "ground: the outcrop west of the fort is stone (%s)" % FormMatter.of_ground(self, rock))
	var h := VegHarvest.find(self)
	var bould := -1
	var bd := INF
	if h != null:
		for i in h.lay.prop_pos.size():
			var k: int = h.lay.prop_kind[i]
			if k >= Assets.ROCK_FIRST and k <= Assets.ROCK_LAST and h.rock_collider(i) != null:
				var dd := (h.lay.prop_pos[i] as Vector3).distance_to(Vector3(LANE_X, 0.0, -40.0))
				if dd < bd:
					bd = dd
					bould = i
	var on_rock := ""
	if bould >= 0:
		var rp: Vector3 = h.lay.prop_pos[bould]
		var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(rp + Vector3.UP * 4.0, rp + Vector3.DOWN * 1.0, 1, [player.get_rid()]))
		if not hit.is_empty():
			on_rock = FormMatter.of_ground(self, hit.position, hit.collider)
	_expect(on_rock == "stone", "ground: on a boulder (the vegetation's rocks) it is stone (%s)" % on_rock)


# ---------------------------------------------------------------- a wall on each ground
## Earth Wall cast from `stand` at `spot`: its matter `want`, its numbers (the table's), the circle, the lines, cover, its hits.
func _wall_on(want: String, stand: Vector3, spot: Vector3) -> void:
	_place(stand, spot)
	await _secs(0.5)
	var e: Dictionary = FormMatter.wall_materials().get(want, {})
	var w0: Dictionary = SwayMoves.move("earth_wall").get("wall", {})
	var before := _walls()
	var seen := await _lock_cast("earth_wall", func() -> Vector3: return spot)
	await _secs(0.9)
	var wall := _newest(FormRaised.GROUP, before) as FormRaised
	var hits_want := int(e.get("hits", w0.get("hits", 4)))
	var label := FormMatter.label(want)
	_expect(bool(seen.get("cast", false)) and wall != null and wall.matter == want and wall.is_up(),
			"%s: Earth Wall cast on it, a wall of %s (%s)" % [want, want, wall.matter if wall else "none"])
	if wall == null:
		return
	var col: Color = seen.get("circle_color", Color.BLACK)
	_expect(String(seen.get("matter", "")) == want and col.is_equal_approx(FormMatter.circle_color(want)),
			"%s: the lock's circle drawn in the matter's colour %s" % [want, str(col)])
	var hud := String(seen.get("hud_line", ""))
	var line := String(seen.get("lock_line", ""))
	_expect(hud.begins_with("Earth Wall: " + label) and (want == "earth" or line.begins_with("Earth Wall: " + label)),
			"%s: the HUD's spell line '%s', the lock's line '%s'" % [want, hud, line])
	_expect(wall.hits_max == hits_want and is_equal_approx(wall.hit_min, float(e.get("hit_min", w0.get("hit_min", 10.0))))
			and wall.crumble_style == String(e.get("crumble", "dust")) and String(wall.get_meta(&"surface", "")) == String(e.get("surface", "stone"))
			and absf(wall.size.y - float(e.get("height_m", w0.get("height_m", 2.0)))) < 0.01,
			"%s: %d hits of %.0f, crumbles '%s', sounds '%s', %.2f m high" % [want, wall.hits_max, wall.hit_min, wall.crumble_style,
			String(wall.get_meta(&"surface", "")), wall.size.y])
	if want == "stone":
		# (on the outcrop a fighter's cover query meets more shapes than it reads: NpcCover takes the first 32 within 12 m,
		# and the rocks, trunks and saplings there are more; the stone wall's box is checked on the open lane below)
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = NpcCover.RADIUS
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, wall.global_position + Vector3.UP)
		print("    (shapes within %.0f m of the outcrop's wall: %d)" % [NpcCover.RADIUS, (current_scene as Node3D).get_world_3d().direct_space_state.intersect_shape(q, 256).size()])
	else:
		await _cover_behind(wall, want)
	if want == "stone":
		Hit.deliver(wall, 12.0, wall.global_position + Vector3.UP, wall.global_basis.z, null)
		_expect(wall.hits == 0, "stone: a hit of 12 (under its hit_min %.0f) is not counted" % wall.hit_min)
	for i in wall.hits_max - 1:
		Hit.deliver(wall, 60.0, wall.global_position + Vector3.UP, wall.global_basis.z, null)
	var still := wall.state == FormRaised.State.UP
	Hit.deliver(wall, 60.0, wall.global_position + Vector3.UP, wall.global_basis.z, null)
	_expect(still and wall.state == FormRaised.State.CRUMBLING, "%s: it stands %d hits, the next crumbles it" % [want, wall.hits_max - 1])
	await _secs(wall.crumble_s + 0.3)
	if want == "stone":
		await _stone_cover()


## A stone wall raised on the open lane (FormEffects.earth_wall of matter stone): a fighter takes cover behind it.
func _stone_cover() -> void:
	var spot := _ground(LANE_X, -26.6)
	_place(_ground(LANE_X, -24.0), spot)
	await _secs(0.4)
	var before := _walls()
	FormEffects.earth_wall(c, spot, SwayMoves.move("earth_wall"), "stone")
	await _secs(0.9)
	var wall := _newest(FormRaised.GROUP, before) as FormRaised
	_expect(wall != null and wall.matter == "stone", "stone: a stone wall raised on the lane")
	if wall == null:
		return
	await _cover_behind(wall, "stone")
	wall.crumble("test")
	await _secs(wall.crumble_s + 0.3)


## A fighter beyond `wall` from the caster takes cover behind it (NpcCover finds its box).
func _cover_behind(wall: FormRaised, what: String) -> void:
	var way := wall.global_basis.z
	way.y = 0.0
	way = way.normalized()
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(wall.global_position.x + way.x * 1.6, wall.global_position.z + way.z * 1.6),
			{"tag": "matter_cover", "seed": 11})
	var f: NpcFighter = sq.members[0] if not sq.members.is_empty() else null
	await _secs(0.4)
	var threat := wall.global_position - way * 9.0
	var spot := NpcCover.find(f, threat) if f != null else Vector3.INF
	var wp := wall.global_position
	var behind := spot != Vector3.INF and (spot - wp).dot(way) > 0.2 and Vector2(spot.x - wp.x, spot.z - wp.z).length() < 2.6
	_expect(behind, "%s: a fighter takes cover behind it (NpcCover: %s)" % [what, str(spot)])
	sq.queue_free()
	await _ticks(3)


func _snow_wall() -> void:
	var snow := SnowCover.find(self)
	_expect(snow != null, "snow: the level's snow cover")
	if snow == null:
		return
	var spot := _ground(LANE_X, -26.6)
	snow.force_depth_m = 0.3
	for i in 300:
		await physics_frame
		if snow.depth_at(spot) >= 0.2:
			break
	_expect(FormMatter.of_ground(self, spot) == "snow", "snow: the lane under %.2f m of snow is snow" % snow.depth_at(spot))
	await _wall_on("snow", _ground(LANE_X, -24.0), spot)
	snow.force_depth_m = 0.0
	for i in 300:
		await physics_frame
		if snow.depth_at(spot) < 0.005:
			break
	snow.force_depth_m = -1.0
	_expect(FormMatter.of_ground(self, spot) == "earth", "snow: thawed, the lane is earth again")


# ---------------------------------------------------------------- a tree
func _standing_trees(h: VegHarvest) -> int:
	var n := 0
	for i in h.lay.tree_pos.size():
		if int(h.lay.tree_kind[i]) < Assets.CANOPY_COUNT and not h.felled.has(i):
			n += 1
	return n


## The lane's nearest sturdy standing tree, the player 2.3 m off its trunk on the lane's side: the ground beside it first,
## then its trunk. The tree's index (-1 none).
func _tree_wall() -> int:
	var h := VegHarvest.find(self)
	var best := -1
	var bd := INF
	for i in h.lay.tree_pos.size():
		var d := h.describe("tree", "tree", i)
		if d.is_empty() or float(d.radius) < 0.22 or not h.has_trunk_collider(i):
			continue
		var dist := Vector2((d.pos as Vector3).x - LANE_X, (d.pos as Vector3).z + 40.0).length()
		if dist < bd:
			bd = dist
			best = i
	_expect(best >= 0, "tree: the lane's nearest standing tree (%d)" % best)
	if best < 0:
		return -1
	var td := h.describe("tree", "tree", best)
	var tp: Vector3 = td.pos
	var out := Vector3(LANE_X - tp.x, 0.0, -40.0 - tp.z).normalized()
	var stand := _ground(tp.x + out.x * 2.3, tp.z + out.z * 2.3)
	_place(stand, tp)
	await _secs(0.6)
	var n0 := _standing_trees(h)
	# the ground beside it: the ground
	var beside := _ground(tp.x + out.x * 1.1 + out.z * 0.9, tp.z + out.z * 1.1 - out.x * 0.9)
	_ready_spell("earth_wall")
	await _hold_on(func() -> Vector3: return beside, 0.12)
	Input.action_press("aim")
	await _hold_on(func() -> Vector3: return beside, 0.3)
	_expect(c.state == SwayCaster.State.LOCKING and c.form.lock_tree == -1 and c.form.lock_matter == "earth",
			"tree: the crosshair on the ground beside it locks the ground (%s, tree %d)" % [c.form.lock_matter, c.form.lock_tree])
	await _release()
	await _secs(0.3)
	# its trunk: the tree
	var trunk := tp + Vector3.UP * 1.4 + out * float(td.radius) * 0.8
	var before := _walls()
	var seen := await _lock_cast("earth_wall", func() -> Vector3: return trunk)
	var ca: Vector3 = seen.get("circle_at", Vector3.INF)
	_expect(int(seen.get("tree", -1)) == best and String(seen.get("matter", "")) == "wood" and ca != Vector3.INF
			and Vector2(ca.x - tp.x, ca.z - tp.z).length() < 0.15,
			"tree: the crosshair on its trunk locks the tree (%d), its circle round the trunk's foot" % int(seen.get("tree", -1)))
	_expect(String(seen.get("hud_line", "")).begins_with("Earth Wall: wood") and String(seen.get("lock_line", "")).begins_with("Earth Wall: wood"),
			"tree: the lines say wood ('%s', '%s')" % [String(seen.get("hud_line", "")), String(seen.get("lock_line", ""))])
	await _secs(0.9)
	var wall := _newest(FormRaised.GROUP, before) as FormRaised
	_expect(bool(seen.get("cast", false)) and wall != null and wall.matter == "wood" and wall.hits_max == 5 and wall.crumble_style == "splinters"
			and String(wall.get_meta(&"surface", "")) == "wood" and int(wall.get_meta(&"tree_i", -1)) == best,
			"tree: cast, a palisade of its wood (5 hits, splinters)")
	if wall != null:
		var to_wall := Vector3(wall.global_position.x - tp.x, 0.0, wall.global_position.z - tp.z)
		var way := Vector3(tp.x - stand.x, 0.0, tp.z - stand.z).normalized()
		_expect(to_wall.dot(way) > float(td.radius) and to_wall.length() < float(td.radius) + 0.6 and absf(wall.global_basis.z.dot(way)) > 0.95,
				"tree: it stands just past the tree's foot (%.2f m on), across the caster's line" % to_wall.length())
	var stump := current_scene.get_node_or_null("Stump_%d" % best)
	_expect(h.felled.has(best) and not h.has_trunk_collider(best) and h.describe("tree", "tree", best).is_empty() and _standing_trees(h) == n0 - 1,
			"tree: the tree is gone into it (felled, no trunk collider, the standing trees %d -> %d)" % [n0, _standing_trees(h)])
	_expect(stump != null and stump.is_in_group(FelledTree.STUMP_GROUP) and Vector2(stump.global_position.x - tp.x, stump.global_position.z - tp.z).length() < 0.05
			and (SaveParts.save_vegetation(current_scene).felled as Array).has(best),
			"tree: its stump stands at its foot, and the save's vegetation part has it felled")
	if wall != null:
		await _cover_behind(wall, "wood")
	return best


# ---------------------------------------------------------------- the pillar
func _pillar_cap() -> void:
	for m: String in ["earth", "stone"]:
		var mesh := FormModels.pillar_mesh(0.55, 3.0, 2, FormModels.BURY_M, m)
		var arr := mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tris := 0
		var up := 0
		var count := ids.size() if not ids.is_empty() else vs.size()
		for k in range(0, count, 3):
			var ia := ids[k] if not ids.is_empty() else k
			var ib := ids[k + 1] if not ids.is_empty() else k + 1
			var ic := ids[k + 2] if not ids.is_empty() else k + 2
			if vs[ia].y < 2.999 or vs[ib].y < 2.999 or vs[ic].y < 2.999:
				continue
			tris += 1
			var n := (ns[ia] + ns[ib] + ns[ic]).normalized()
			if n.y > 0.7:
				up += 1
		_expect(tris >= 20 and up == tris, "pillar (%s): the cap is drawn, %d triangles over its top, %d facing up (drawn from above)" % [m, tris, up])
	# a mud pillar is mud
	var mud_at := _ground(BROOK.x, BROOK.y)
	_place(_ground(BROOK.x, BROOK.y + 2.0), mud_at)
	await _secs(0.4)
	var before := get_nodes_in_group(FormRaised.GROUP)
	var p := FormEffects.pillar(c, mud_at, SwayMoves.move("pillar"), "free")
	_expect(p != null and p.matter == "mud" and p.hits_max == 3 and p.crumble_style == "slump",
			"pillar: raised from the brook's mud it is mud (%s, %d hits, %s)" % [p.matter if p else "", p.hits_max if p else 0, p.crumble_style if p else ""])
	await _secs(1.5)
	if p != null:
		p.queue_free()
	await _ticks(3)


## A self cast high in the air: it rises fast under where the player will be, just tall enough, and catches them.
func _pillar_catch() -> void:
	var at := _ground(LANE_X, -24.0)
	_place(at, _ground(LANE_X, -30.0))
	await _secs(0.6)
	c.set_mode("pillar", "self")
	_clear_ev()
	_ready_spell("pillar")
	Input.action_press("aim")
	var t := await _hold_on(Callable(), 3.0, func() -> bool: return c.state == SwayCaster.State.FULL)
	_expect(t < 3.0, "pillar catch: the self lock full on the ground (%.2f s)" % t)
	var before := get_nodes_in_group(FormRaised.GROUP)
	# up in the air as from a jump off something high, still rising a little and drifting forward
	player.global_position = at + Vector3.UP * 5.2
	player.velocity = Vector3(0.0, 1.5, -1.6)
	await _ticks(2)
	var air := not player.is_on_floor()
	var ad: Dictionary = (SwayMoves.move("pillar").get("pillar", {}) as Dictionary).get("air", {})
	var catch := FormEffects.air_catch(c, ad)
	Input.action_release("aim")
	await _ticks(1)
	var pil := _newest(FormRaised.GROUP, before) as FormRaised
	_expect(air and ev.cast.size() == 1 and pil != null and String(pil.get_meta(&"pillar_mode", "")) == "air" and is_equal_approx(pil.rise_s, float(ad.get("rise_s", 0.2))),
			"pillar catch: cast in the air, it rises in %.2f s" % (pil.rise_s if pil else -1.0))
	if pil == null:
		return
	var landed_y := INF
	var on_t := INF
	for i in 180:
		await physics_frame
		if player.is_on_floor() and pil.is_up():
			landed_y = player.global_position.y
			on_t = i / 60.0
			break
	await _secs(0.4)
	var top := pil.top()
	var g := FormEffects.ground_at(c, pil.global_position)
	var feet_over := landed_y - g.y
	_expect(player.is_on_floor() and absf(player.global_position.y - top.y) < 0.08 and Vector2(player.global_position.x - top.x, player.global_position.z - top.z).length() < pil.size.x * 0.5,
			"pillar catch: they land on its top (feet %.2f m over it, %.2f m off its middle)" % [player.global_position.y - top.y,
			Vector2(player.global_position.x - top.x, player.global_position.z - top.z).length()])
	_expect(landed_y != INF and absf(pil.size.y - feet_over) < 0.15 and pil.size.y > 3.5 and pil.size.y <= 8.0,
			"pillar catch: just as tall as their feet were high (%.2f m, their feet %.2f m over the ground; predicted %.2f m)" % [pil.size.y, feet_over, float(catch.height_m)])
	_expect(player.global_position.y > g.y + pil.size.y - 0.1, "pillar catch: their fall did not carry them through it")
	for n in get_nodes_in_group(FormRaised.GROUP):
		n.queue_free()
	player.global_position = at + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await _secs(0.6)


# ---------------------------------------------------------------- Stone Form thrown
func _crate(at: Vector3) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = "MatterCrate"
	b.mass = 20.0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.7, 0.9, 0.7)
	cs.shape = bx
	b.add_child(cs)
	current_scene.add_child(b)
	b.global_position = at + Vector3.UP * 0.46
	return b


func _throws() -> void:
	# a spike at a militiaman 9 m off
	var stand := _ground(LANE_X, -24.0)
	_place(stand, _ground(LANE_X, -33.0))
	await _secs(0.5)
	c.set_mode("stone_form", "spike")
	var sq := NpcSquad.spawn(current_scene, "militia", 1, _ground(LANE_X, -33.0), {"face": stand, "tag": "matter_target", "seed": 5})
	var f: NpcFighter = sq.members[0]
	await _secs(0.8)
	var hp0 := f.health
	var before := get_nodes_in_group(FormStone.GROUP)
	var seen := await _lock_cast("stone_form", func() -> Vector3: return NpcSenses.chest_of(f))
	var spike := _newest(FormStone.GROUP, before) as FormStone
	var th: Node = get_nodes_in_group(FormEffects.Throw.GROUP).back() if not get_nodes_in_group(FormEffects.Throw.GROUP).is_empty() else null
	var near := spike != null and Vector2(spike.global_position.x - stand.x, spike.global_position.z - stand.z).length() < 2.3
	_expect(bool(seen.get("cast", false)) and spike != null and spike.kind == "spike" and th != null and near,
			"throw: the spike comes up near the caster (%.2f m off)" % (Vector2(spike.global_position.x - stand.x, spike.global_position.z - stand.z).length() if spike else -1.0))
	var far := 0.0
	for i in 120:
		await physics_frame
		if spike != null and is_instance_valid(spike):
			far = maxf(far, Vector2(spike.global_position.x - stand.x, spike.global_position.z - stand.z).length())
		if f.health < hp0:
			break
	var struck: Array = th.get("struck") if th != null and is_instance_valid(th) else []
	_expect(f.health < hp0 and far > 5.0, "throw: it flies at him (%.1f m out) and strikes him (%.0f -> %.0f)" % [far, hp0, f.health])
	await _secs(1.0)
	_expect(is_instance_valid(spike) and not GustLift.busy(spike) and spike.state == FormStone.State.RESTING,
			"throw: then the spike lies, a stone for Gust (%s)" % (FormStone.State.keys()[spike.state] if is_instance_valid(spike) else "gone"))
	sq.queue_free()
	if is_instance_valid(spike):
		spike.queue_free()
	await _secs(0.4)
	# a cannonball at a crate 9 m off
	c.set_mode("stone_form", "cannonball")
	var crate := _crate(_ground(LANE_X, -33.0))
	await _secs(0.5)
	var c0 := crate.global_position
	before = get_nodes_in_group(FormStone.GROUP)
	var ths0 := get_nodes_in_group(FormEffects.Throw.GROUP)
	seen = await _lock_cast("stone_form", func() -> Vector3: return crate.global_position)
	var ball := _newest(FormStone.GROUP, before) as FormStone
	th = _newest(FormEffects.Throw.GROUP, ths0)
	var knocked: Array = []
	if th != null:
		th.connect(&"tree_exiting", func() -> void: knocked.append_array(th.get("knocked")))
	_expect(bool(seen.get("cast", false)) and ball != null and ball.kind == "cannonball"
			and Vector2(ball.global_position.x - stand.x, ball.global_position.z - stand.z).length() < 2.3,
			"throw: the cannonball comes up near the caster")
	var moved := 0.0
	for i in 150:
		await physics_frame
		moved = maxf(moved, crate.global_position.distance_to(c0))
		if moved > 0.4 and not knocked.is_empty():
			break
	_expect(moved > 0.4 and knocked.has(crate), "throw: it flies at the crate and knocks it on (%.2f m)" % moved)
	await _secs(2.0)
	_expect(is_instance_valid(ball) and not ball.freeze and not GustLift.busy(ball) and ball.state == FormStone.State.RESTING,
			"throw: then the ball rolls and rests, in the physics")
	if is_instance_valid(ball):
		ball.queue_free()
	crate.queue_free()
	# a stone raised from mud looks of mud (its rock look)
	var mud_at := _ground(BROOK.x, BROOK.y)
	_place(_ground(BROOK.x, BROOK.y + 2.0), mud_at)
	await _secs(0.5)
	before = get_nodes_in_group(FormStone.GROUP)
	_aim(mud_at + Vector3(0.0, 0.5, -6.0))
	await _ticks(2)
	var s := FormEffects.stone_form(c, mud_at, SwayMoves.move("stone_form"), "spike")
	_expect(s != null and s.matter == "mud" and s.mesh_instance.mesh.surface_get_material(0) == FormMatter.rock_material("mud"),
			"look: a spike raised from the brook's mud is a stone of it (%s)" % (s.matter if s else ""))
	await _secs(1.5)
	if is_instance_valid(s):
		s.queue_free()
	c.set_mode("stone_form", "spike")
	c.ready_spell("")


# ---------------------------------------------------------------- the save
func _save_load(tree_i: int) -> void:
	var sg := SaveGame.find(self)
	_expect(sg != null and SaveGame.dir() == SaveGame.TEST_DIR, "save: the level saves, in the test folder")
	if sg == null or tree_i < 0:
		return
	_place(_ground(LANE_X, -24.0), _ground(LANE_X, -30.0))
	await _secs(0.5)
	_expect(sg.save_game("quick") == OK, "save: the quick save written")
	_expect(sg.load_slot("quick"), "save: and loaded (the level rebuilt)")
	for i in 60 * 30:
		await process_frame
		var s2 := SaveGame.find(self)
		if s2 != null and s2 != sg and not s2.loading and s2.level != null and s2.level.is_inside_tree():
			for k in 20:
				await process_frame
			break
	var h := VegHarvest.find(self)
	var stump := current_scene.get_node_or_null("Stump_%d" % tree_i)
	_expect(h != null and h.felled.has(tree_i) and not h.has_trunk_collider(tree_i) and stump != null,
			"save: loaded, the tree that went into the wall is still gone, its stump standing")


func _end() -> void:
	Input.action_release("aim")
	for s in SaveGame.SLOTS:
		var p := SaveGame.TEST_DIR + String(s) + ".json"
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if fails.is_empty():
		print("WALL MATTER TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("WALL MATTER TEST FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
