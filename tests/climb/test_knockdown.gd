extends SceneTree
## Knocked down (PlayerRagdoll, FrontierPlayer.knock_down; user 2026-09-27: "do we have ragdoll physics?", "when we get
## hit?"), on the climbing yard's flat ground, headless:
##
##   Godot --headless --path . -s tests/climb/test_knockdown.gd -- --no-capture [shots=<dir>]
##
##   thrown    knock_down(v): a ragdoll on the skeleton, thrown with v; the player's body goes with the hips; input and
##             the player's own animation suspended (kneeling), the weapon to the body
##   at rest   it comes to rest on the ground, a get-up clip is chosen by how the body lies, the ragdoll fades into it
##   up        the get-up plays out: the player on their feet where the body lay, their own animation and weapon back,
##             able to be knocked down again
##   refused   not while already down
##   disarmed  by the dice (drop_chance 1 here) a weapon in the hands is knocked out of them: it lands a few metres
##             off, lying on the ground, the player no longer carries it and gets up empty-handed; E takes it again.
##             By the dice kept (drop_chance 0): on the body through the fall and drawn again after
##   tool      the felling axe in the hands: knocked out of them, lying on the ground; the player has it no more (not
##             given back by GatherTools) till E picks it up
## With shots=<dir> (a window) stills: thrown, at rest, getting up, up.
## Ends with "KNOCKDOWN TEST PASSED (<n> checks)" or "KNOCKDOWN TEST FAILED (<f> of <n>)".

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var shots := ""
var view


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots = a.substr(6)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		root.content_scale_size = Vector2i(1280, 720)
		view = OffscreenView.new()
		root.add_child(view)
		view.setup(root, Vector2i(1280, 720))
		root.disable_3d = true
	# on open flat ground well away from the rocks and the mammoth
	var yard := current_scene.get("yard") as ClimbYard
	yard.giant.paces = false
	var at := Vector3(0.0, 0.0, -140.0)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	p.global_position = at
	p.velocity = Vector3.ZERO
	await _fr(120)
	PlayerRagdoll.of(p).drop_chance = 0.0
	await _knock(Vector3(6.0, 4.0, 1.0), "a")
	await _fr(120)
	await _knock(Vector3(-2.0, 3.5, -6.5), "b")
	await _fr(120)
	await _knock(Vector3(0.5, 5.0, 7.0), "c")
	await _fr(120)
	await _disarm()
	await _fr(120)
	await _lose_tool()
	if fails.is_empty():
		print("KNOCKDOWN TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("KNOCKDOWN TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _shot(nm: String) -> void:
	if shots == "":
		return
	var hips := p.skeleton.global_transform * p.skeleton.get_bone_global_pose(p.skeleton.find_bone("root")).origin
	var from := hips + Vector3(3.2, 1.6, 3.2)
	view.source = null
	view.camera.global_transform = Transform3D(Basis.looking_at(hips - from, Vector3.UP), from)
	view.camera.fov = 50.0
	for i in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	(view.get_texture().get_image() as Image).save_png(shots.path_join(nm + ".png"))


## With the musket in the hands: knocked out of them; slung: kept.
func _disarm() -> void:
	var r := PlayerRagdoll.of(p)
	if p.hands_free or p.weapon_key != "musket":
		p.set_carried("musket", true)
		p.switch_weapon("musket")
		await _fr(240)
	_expect(p.weapon_key == "musket" and not p.hands_free and p.weapon.active, "disarmed: the musket in the hands")
	r.drop_chance = 1.0
	var at := p.global_position
	p.knock_down(Vector3(4.0, 4.0, 0.0))
	await _fr(120)
	var pw := r.dropped
	_expect(pw != null and is_instance_valid(pw) and pw.key == "musket" and not p.is_carried("musket"),
			"disarmed: the blow knocks the musket out of the hands; it is no longer carried")
	var t := 0.0
	while r.phase != "" and t < 8.0:
		await physics_frame
		t += 1.0 / 120.0
	await _fr(60)
	if pw == null or not is_instance_valid(pw):
		return
	var g := FrontierTerrain.height_at(pw.global_position.x, pw.global_position.z)
	_expect(_flat(pw.global_position, at) > 1.0 and _flat(pw.global_position, at) < 8.0 and absf(pw.interact_point().y - g) < 0.3,
			"disarmed: it lies on the ground %.1f m off" % _flat(pw.global_position, at))
	_expect(p.hands_free, "disarmed: up empty-handed")
	pw.interact(p)
	await _fr(240)
	_expect(p.is_carried("musket") and p.weapon_key == "musket" and not is_instance_valid(pw) or pw.is_queued_for_deletion(),
			"disarmed: E takes it again")
	# the dice say it stays: on the body through the fall, drawn again after
	r.drop_chance = 0.0
	await _fr(60)
	p.knock_down(Vector3(-3.0, 4.0, 2.0))
	await _fr(60)
	_expect(r.dropped == null and p.is_carried("musket"), "kept: the musket stays with the player through the fall")
	t = 0.0
	while r.phase != "" and t < 8.0:
		await physics_frame
		t += 1.0 / 120.0
	await _fr(240)
	_expect(p.weapon_key == "musket" and not p.hands_free, "kept: drawn again once up")


func _lose_tool() -> void:
	var r := PlayerRagdoll.of(p)
	var g := p.gather
	if g == null:
		_expect(false, "tool: the player has GatherTools")
		return
	g.take_out("felling_axe")
	var t := 0.0
	while g.in_hand() != "felling_axe" and t < 8.0:
		await physics_frame
		t += 1.0 / 120.0
	await _fr(30)
	_expect(g.in_hand() == "felling_axe", "tool: the felling axe in the hands")
	r.drop_chance = 1.0
	var at := p.global_position
	p.knock_down(Vector3(3.0, 4.0, 3.0))
	await _fr(60)
	var d := r.dropped_tool
	_expect(d != null and is_instance_valid(d) and d.kind == "felling_axe" and not g.owns("felling_axe")
			and g.lost.has("felling_axe"), "tool: the blow knocks the felling axe out of the hands; the player has it no more")
	t = 0.0
	while r.phase != "" and t < 8.0:
		await physics_frame
		t += 1.0 / 120.0
	await _fr(60)
	if d == null or not is_instance_valid(d):
		return
	g._ensure_owned()
	_expect(not g.owns("felling_axe"), "tool: not given back while it lies there")
	var gy := FrontierTerrain.height_at(d.global_position.x, d.global_position.z)
	_expect(_flat(d.global_position, at) > 1.0 and absf(d.interact_point().y - gy) < 0.4 and g.in_hand() == "",
			"tool: it lies on the ground %.1f m off; the hands empty" % _flat(d.global_position, at))
	d.interact(p)
	await _fr(10)
	_expect(g.owns("felling_axe") and not g.lost.has("felling_axe"), "tool: E picks it up again")


func _knock(v: Vector3, tag: String) -> void:
	var r := PlayerRagdoll.of(p)
	var start := p.global_position
	var hp := p.health
	var ok := p.knock_down(v)
	_expect(ok and r.phase == "thrown" and p.kneeling == r, "%s thrown: knocked down with %s (%s)" % [tag, v, r.phase])
	_expect(not p.knock_down(v), "%s refused: not while already down" % tag)
	await _fr(30)
	await _shot(tag + "_1_thrown")
	var t := 0.0
	while r.phase == "thrown" and t < 6.0:
		await physics_frame
		t += 1.0 / 120.0
	_expect(r.phase == "blend" and r.clip != "", "%s at rest: after %.1f s the body lies still; get up with %s" % [tag, t, r.clip])
	var lay := p.global_position
	_expect(_flat(lay, start) > 1.5, "%s thrown %.1f m" % [tag, _flat(lay, start)])
	var hips := p.skeleton.global_transform * p.skeleton.get_bone_global_pose(p.skeleton.find_bone("root")).origin
	_expect(hips.y - FrontierTerrain.height_at(hips.x, hips.z) < 0.6, "%s lying on the ground (hips %.2f m up)" % [tag,
			hips.y - FrontierTerrain.height_at(hips.x, hips.z)])
	await _shot(tag + "_2_rest")
	await _fr(int(1.1 * 120))
	await _shot(tag + "_3_getting_up")
	t = 0.0
	while r.phase != "" and t < 5.0:
		await physics_frame
		t += 1.0 / 120.0
	await _fr(60)
	await _shot(tag + "_4_up")
	var hips2 := p.skeleton.global_transform * p.skeleton.get_bone_global_pose(p.skeleton.find_bone("root")).origin
	_expect(r.phase == "" and p.kneeling == null and p.is_on_floor() and hips2.y - p.global_position.y > 0.6,
			"%s up: on their feet, their own animation back (hips %.2f m up)" % [tag, hips2.y - p.global_position.y])
	_expect(_flat(p.global_position, lay) < 1.5, "%s up where the body lay (%.2f m off)" % [tag, _flat(p.global_position, lay)])
	_expect(p.health == hp, "%s the knock itself costs no health (the blow does)" % tag)
