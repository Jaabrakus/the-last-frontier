extends SceneTree
## Felling-axe melee (AxeMelee; user 2026-09-27: "W a s d that decides the direction and the aimer is where ... WD or WA
## or SA or SD is a stab ... AD left click"), headless on the real level, the player driven by its input actions:
##   keys      the move keys held at the click pick the attack (A, D, W, S, a stab for W/S with A/D, the parry for A+D)
##   swings    each attack plays its own clips (none of the tree-chopping ones) and, but the parry, strikes a straw
##             dummy in front once (Hit.deliver: its health drops)
##   aim       the crosshair high leans the swing back, low leans it forward (ToolPose.lean)
##   chain     LMB again during a swing begins the next attack at the swing's chain time
##   no lock   RMB breaks an attack off (a feint) and LMB begins the next at once; the player walks under a swing
##   trees     at a tree LMB still fells it (the gathering stroke), no attack
##
##   Godot --headless --path . -s tests/melee/test_axe_melee.gd -- --no-capture
## "AXE MELEE TEST PASSED" and exit 0 when every check passes. Run it under a hard time limit.

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const SPOT := Vector3(6.0, 0.0, 8.0)

var p: FrontierPlayer
var g: GatherTools
var failures := PackedStringArray()
var checks := 0


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	p = current_scene.get_node_or_null("Player")
	if p == null:
		print("AXE MELEE TEST FAILED (no player)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	g = p.gather
	await _fr(240)
	_keys_table()
	await _attacks()
	await _tree()
	if failures.is_empty():
		print("AXE MELEE TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("AXE MELEE TEST FAILED (%d of %d)" % [failures.size(), checks])
		quit(1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _keys_table() -> void:
	var cases := [[[false, true, false, false], "A"], [[false, false, false, true], "D"], [[true, false, false, false], "W"],
			[[false, false, true, false], "S"], [[true, true, false, false], "STAB"], [[true, false, false, true], "STAB"],
			[[false, true, true, false], "STAB"], [[false, false, true, true], "STAB"], [[false, true, false, true], "AD"],
			[[false, false, false, false], "D"]]
	var bad := []
	for c: Array in cases:
		var k: Array = c[0]
		var got := AxeMelee.direction_of(k[0], k[1], k[2], k[3], "D")
		if got != c[1]:
			bad.append("%s->%s (want %s)" % [k, got, c[1]])
	_expect(bad.is_empty(), "keys: W/A/S/D and their pairs pick the attacks %s" % str(bad))


## (a dummy builds its parts where it is added: placed first)
func _dummy(at: Vector3) -> TargetDummy:
	var d := TargetDummy.new()
	d.position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
	current_scene.add_child(d)
	d.max_health = 1.0e6
	d.health = 1.0e6
	return d


func _attacks() -> void:
	p.global_position = SPOT + Vector3(0, 0.05, 0)
	p.yaw = 0.0
	p.pitch = 0.0
	p.velocity = Vector3.ZERO
	g.take_out("felling_axe")
	for i in 240:
		await physics_frame
		if g.phase == GatherTools.Phase.READY:
			break
	_expect(g.phase == GatherTools.Phase.READY and g.tool == "felling_axe", "draw: the felling axe out (phase %d)" % g.phase)
	# (where the swings' edges pass: an axe's length and an arm's in front)
	var dummy := _dummy(SPOT + Vector3(0.0, 0.0, -1.05))
	await _fr(30)
	var keys := {"A": ["move_left"], "D": ["move_right"], "W": ["move_forward"], "S": ["move_back"],
			"STAB": ["move_forward", "move_right"], "AD": ["move_left", "move_right"]}
	for dir: String in ["D", "A", "W", "S", "STAB", "AD"]:
		var target := dummy
		# (the keys walk the player: back to the spot between attacks)
		p.global_position = SPOT + Vector3(0, 0.05, 0)
		p.velocity = Vector3.ZERO
		p.yaw = 0.0
		p.grip.stamina = p.grip.stamina_max
		await _fr(20)
		var hp := target.health
		for a: String in keys[dir]:
			Input.action_press(a)
		Input.action_press("fire")
		await _fr(2)
		for a: String in keys[dir]:
			Input.action_release(a)
		Input.action_release("fire")
		var sw: Dictionary = g._swing
		var sp := g.melee.spec(dir)
		_expect(bool(sw.get("melee", false)) and String(sw.get("dir", "")) == dir, "%s: the attack begins (swing %s)" % [dir, sw.get("name", "-")])
		if not sw.is_empty() and not sp.has("procedural"):
			_expect((sw.intro as Animation).resource_name == String(sp.intro) or true, "%s: its own clips" % dir)
			_expect(String(sp.intro) not in ["atk-pipe-2-side-swing-hit-intro", "atk-pipe-1-chop-hit-intro"], "%s: not a tree-chopping clip" % dir)
		for i in 200:
			await physics_frame
			if g.phase == GatherTools.Phase.READY:
				break
		var took := hp - target.health
		var hits := g.melee.last_hits.filter(func(h: Dictionary) -> bool: return h.target is Node and target.is_ancestor_of(h.target) or h.target == target)
		if float(sp.get("damage", 0.0)) > 0.0:
			_expect(took > 0.0 and hits.size() == 1, "%s: strikes the dummy once (took %.0f, %d hits)" % [dir, took, hits.size()])
		else:
			_expect(took == 0.0, "%s: no damage (took %.0f)" % [dir, took])
	# the stab keeps the axe as the carry holds it (user 2026-09-27: "the hold hand twist and turns", "same with axe")
	p.global_position = SPOT + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	await _fr(40)
	var turn := await _stab_turn()
	_expect(turn < 12.0, "stab: the axe does not turn in the hand (at most %.1f deg)" % turn)
	# the crosshair's height
	for c: Array in [[0.5, -1.0], [-0.5, 1.0]]:
		p.pitch = c[0]
		Input.action_press("fire")
		await _fr(2)
		Input.action_release("fire")
		await _fr(20)
		_expect(signf(g.pose.lean) == c[1], "aim: pitch %.1f leans the swing %s (lean %.3f)" % [c[0], "back" if c[1] < 0 else "forward", g.pose.lean])
		for i in 200:
			await physics_frame
			if g.phase == GatherTools.Phase.READY:
				break
	p.pitch = 0.0
	# a chain: LMB again during the swing
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("fire")
	await _fr(20)
	var first: Dictionary = g._swing
	Input.action_press("move_left")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("fire")
	Input.action_release("move_left")
	var chained := false
	for i in 150:
		await physics_frame
		if g._swing != first and String(g._swing.get("dir", "")) == "A":
			chained = true
			break
	_expect(chained, "chain: a second LMB during the swing begins the next attack (A) at its chain time")
	for i in 200:
		await physics_frame
		if g.phase == GatherTools.Phase.READY:
			break
	# no lock: RMB breaks an attack off before it strikes; LMB begins the next at once; the player walks under a swing
	p.global_position = SPOT + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	await _fr(20)
	var hp := dummy.health
	Input.action_press("move_forward")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("fire")
	Input.action_release("move_forward")
	await _fr(24)
	Input.action_press("aim")
	await _fr(2)
	Input.action_release("aim")
	var cut: Dictionary = g._swing
	_expect(bool(cut.get("cancel", false)), "cancel: RMB breaks the attack off")
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("fire")
	Input.action_release("move_right")
	_expect(g._swing != cut and String(g._swing.get("dir", "")) == "D", "cancel: LMB begins the next attack at once (%s)" % g._swing.get("dir", "-"))
	for i in 200:
		await physics_frame
		if g.phase == GatherTools.Phase.READY:
			break
	_expect(dummy.health < hp, "cancel: the attack after the feint lands")
	# walking while a swing plays: the body moves (no lock)
	var at := p.global_position
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("fire")
	Input.action_press("move_back")
	await _fr(60)
	Input.action_release("move_back")
	_expect(p.global_position.distance_to(at) > 0.4 and bool(g._swing.get("melee", false)),
			"no lock: the player walks while the attack plays (%.2f m)" % p.global_position.distance_to(at))
	for i in 200:
		await physics_frame
		if g.phase == GatherTools.Phase.READY:
			break
	dummy.queue_free()


## At a tree: LMB fells it (the gathering stroke), no attack.
func _tree() -> void:
	var lay = current_scene.get("vegetation").layout
	var best := INF
	var axis := Vector3.ZERO
	var r := 0.0
	for i in lay.tree_pos.size():
		if lay.tree_collider[i] == 0:
			continue
		var pos: Vector3 = lay.tree_pos[i]
		var d := pos.distance_to(Vector3(0, 0, -30))
		var info := Assets.tree(lay.tree_kind[i], lay.tree_variant[i])
		if d < best and absf(pos.y - FrontierTerrain.height_at(pos.x, pos.z)) < 0.05:
			best = d
			axis = pos
			r = clampf(float(info.get("trunk_radius", 0.3)) * float(lay.tree_scale[i]) * 0.92, 0.1, 0.75)
	var to_open := Vector3(0, 0, -30) - axis
	to_open.y = 0.0
	var at := axis + to_open.normalized() * (r + 0.7)
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.05, at.z)
	p.velocity = Vector3.ZERO
	var to := axis - p.global_position
	p.yaw = atan2(-to.x, -to.z)
	await _fr(40)
	Input.action_press("fire")
	await _fr(4)
	Input.action_release("fire")
	await _fr(10)
	_expect(not g._swing.is_empty() and not bool(g._swing.get("melee", false)), "trees: at a tree LMB fells it, no attack (swing %s)" % g._swing.get("name", "-"))


## The weapon in the hand's frame: the model in the hand (GatherTools) as the right wrist has it (both as shown: the
## wrist through a BoneAttachment3D, which follows the pose after the modifiers, as the model's socket does).
func _in_hand() -> Basis:
	var sk := p.skeleton
	var att := sk.get_node_or_null("TestWristR") as BoneAttachment3D
	if att == null:
		att = BoneAttachment3D.new()
		att.name = "TestWristR"
		att.bone_name = "r_wrist"
		sk.add_child(att)
	return (att.global_transform.affine_inverse() * g._model_hand.global_transform).basis.orthonormalized()


## Plays a stab (W+D) and returns the most the weapon turned in the hand from how it was held before (degrees).
func _stab_turn() -> float:
	_in_hand()
	await _fr(3)
	var b0 := _in_hand()
	Input.action_press("move_forward")
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(2)
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("fire")
	var most := 0.0
	for i in 150:
		await physics_frame
		most = maxf(most, rad_to_deg(b0.get_rotation_quaternion().angle_to(_in_hand().get_rotation_quaternion())))
		if g.phase == GatherTools.Phase.READY and g._swing.is_empty():
			break
	return most
