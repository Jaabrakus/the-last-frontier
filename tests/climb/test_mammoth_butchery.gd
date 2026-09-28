extends SceneTree
## Killing and butchering the woolly mammoth (StandInGiant.die, MammothButchery; user 2026-09-27: "for the mammoth we have
## to chop it in pieces when we skin it and butcher it so the user has to look at the location of what they want to chop
## off"), on the climbing yard, headless:
##
##   Godot --headless --path . -s tests/climb/test_mammoth_butchery.gd -- --no-capture [shots=<dir>]
##
##   killed    a hit in the hide does a quarter of its harm, one in the head twice; at no health it rolls onto a side
##             and lies there, its weak points gone
##   parts     the flank it lies with up can be skinned, the one under it not; its meat only once skinned
##   look      at the head, the crosshair on a tusk: the axe's target is that tusk; on the trunk, the trunk
##   tools     no felling axe, no chopping
##   cut       with the axe (user: "use the axe to butcher"; E draws it and swings, a stroke at a time): a tusk:
##             ivory, the tusk gone; with the knife the hide: the mammoth hide, the flank raw red; with the axe the
##             meat, cut by cut: meat, the flank bone at the last
##   limb      a leg chopped off drops, a carcass of its own (user: "chopped up limbs count as a carcass right like a
##             smaller animal carcass"): the leg gone from the mammoth, lying along the ground, its own mesh; a carcass
##             the rope, the barrow and the horse take (CarcassLoad.haulable; the rope offered at its foot); butchered
##             with the axe where it lies: meat and sinew, and it is gone
## With shots=<dir> (a window) stills: dead, and cut up.
## Ends with "MAMMOTH BUTCHERY TEST PASSED (<n> checks)" or "MAMMOTH BUTCHERY TEST FAILED (<f> of <n>)".

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var gi: StandInGiant
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
	gi = (current_scene.get("yard") as ClimbYard).giant
	gi.paces = false
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		root.content_scale_size = Vector2i(1280, 720)
		view = OffscreenView.new()
		root.add_child(view)
		view.setup(root, Vector2i(1280, 720))
		root.disable_3d = true
		var rig := current_scene.get_node("EnvironmentRig") as EnvironmentRig
		if rig and rig.clock_driver:
			rig.clock_driver.clock.running = false
			rig.clock_driver.clock.set_time(11.0)
	await _fr(60)
	await _killed()
	if gi.butchery:
		_parts()
		await _look()
		await _tools()
		await _cut()
	if fails.is_empty():
		print("MAMMOTH BUTCHERY TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("MAMMOTH BUTCHERY TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(nm: String, from: Vector3, at: Vector3) -> void:
	if shots == "":
		return
	view.source = null
	view.camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	view.camera.fov = 55.0
	for i in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	(view.get_texture().get_image() as Image).save_png(shots.path_join(nm + ".png"))


func _pack(kind: String) -> int:
	return InventoryState.from_player(p).pack_count(kind)


func _stand_at(pt: Vector3, off := 2.0) -> void:
	var from := pt - gi.where()
	from.y = 0.0
	from = from.normalized() if from.length() > 0.1 else Vector3.BACK
	var at := pt + from * off
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	p.global_position = at
	p.velocity = Vector3.ZERO
	var to := pt - at
	p.yaw = atan2(-to.x, -to.z)
	p.rotation.y = p.yaw
	await _fr(10)


func _killed() -> void:
	var h0 := gi.health
	Hit.deliver(gi.torso, 100.0, gi.torso.global_position, Vector3.FORWARD, p)
	_expect(is_equal_approx(h0 - gi.health, 100.0 * StandInGiant.HIDE_MULT), "killed: a hit in the hide does a quarter of its harm (%.0f)" % (h0 - gi.health))
	var died := []
	gi.died.connect(func() -> void: died.append(true), CONNECT_ONE_SHOT)
	var shots_n := 0
	while gi.dead_side == "" and shots_n < 20:
		Hit.deliver(gi.head, 110.0, gi.head.global_position, Vector3.FORWARD, p)
		shots_n += 1
		await _fr(2)
	_expect(died.size() == 1 and gi.dead_side in ["L", "R"] and shots_n == ceili((StandInGiant.MAX_HEALTH - 25.0) / (110.0 * StandInGiant.HEAD_MULT)),
			"killed: %d shots in the head, and it dies onto its %s side" % [shots_n, "left" if gi.dead_side == "L" else "right"])
	await _fr(int(3.0 * 120))
	var torso_up := gi.torso.global_position.y - gi.spawn.origin.y
	_expect(not gi.anim.active and torso_up < 2.2, "killed: it lies there (its middle %.1f m up; standing %.1f)" % [torso_up, StandInGiant.TORSO_Y])
	var weak_off := true
	for z in gi.weak:
		weak_off = weak_off and z.collision_layer == 0
	_expect(weak_off, "killed: its weak points gone")
	var c := gi.where()
	await _shot("1_dead", c + Vector3(-9.0, 3.5, 7.0), c + Vector3(0.0, 1.0, 0.0))


func _parts() -> void:
	var b := gi.butchery
	var up := "R" if gi.dead_side == "L" else "L"
	var down := gi.dead_side
	_expect(b.available("hide_" + up.to_lower()) and not b.available("hide_" + down.to_lower()),
			"parts: the %s flank (up) can be skinned, the one under it not" % ("left" if up == "L" else "right"))
	_expect(not b.available("meat_" + up.to_lower()), "parts: its meat only once skinned")
	var high: Vector3 = b.where("hide_" + up.to_lower())[0]
	_expect(high.y - gi.spawn.origin.y > 1.0, "parts: the up flank's middle is up (%.1f m)" % (high.y - gi.spawn.origin.y))


func _look() -> void:
	var b := gi.butchery
	# walked up to each and the crosshair on it (the other close by)
	for which: String in ["tusk_l", "tusk_r", "trunk"]:
		var w := b.where(which)
		var pt: Vector3 = ((w[0] as Vector3) + (w[1] as Vector3)) * 0.5
		await _aim_at(pt, 1.9)
		var key := String(p.gather.target.get("key", "")) if p.gather.target.get("type", "") == "carcass" else "(none)"
		_expect(key == which, "look: the crosshair on the %s: the axe's target is it (%s: %s)" % [which, key, p.gather.prompt()])


func _tools() -> void:
	var b := gi.butchery
	var had := p.gather.owns("felling_axe")
	# the axe away (out of the pack and off the loop)
	var inv := InventoryState.from_player(p)
	var n := inv.pack_count("felling_axe")
	inv.take("felling_axe", n)
	p.inventory_pack = inv.pack.duplicate(true)
	var on_loop := p.loadout.first_of_kind("felling_axe") if p.loadout else {}
	if not on_loop.is_empty():
		p.loadout.remove_item(String(on_loop.id))
	p.gather._read_loop()
	_expect(not b.has_tool("tusk_l") and not b.toggle("tusk_l"), "tools: no felling axe, no chopping")
	inv = InventoryState.from_player(p)
	inv.add("felling_axe", 1)
	p.inventory_pack = inv.pack.duplicate(true)
	_expect(had and b.has_tool("tusk_l"), "tools: the axe back")


## Standing `off` from `pt`, the camera turned so the crosshair is on it.
func _aim_at(pt: Vector3, off: float) -> void:
	await _stand_at(pt, off)
	for k in 4:
		var cam := p.get_viewport().get_camera_3d()
		var to := pt - cam.global_position
		p.yaw = atan2(-to.x, -to.z)
		p.rotation.y = p.yaw
		p.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		await _fr(6)
	await _fr(20)


## Chops part `id` with the axe as a player does: the crosshair on it, E (GatherTarget: draws the axe, one stroke) till
## it comes off. The strokes it took (-1: it never did).
func _chop(id: String) -> int:
	var b := gi.butchery
	var w := b.where(id)
	await _aim_at(((w[0] as Vector3) + (w[1] as Vector3)) * 0.5, 1.7)
	var strokes := 0
	var t := 0.0
	var last := -1
	var landed := [0]
	var cb := func(type: String, _c: Dictionary) -> void:
		if type == "carcass":
			landed[0] += 1
	p.gather.stroke_landed.connect(cb)
	var snapped := false
	while not bool(b.state[id].done) and t < 40.0:
		if p.gather.target.get("key", "") == id and p.gather._queued == 0 and p.gather.phase in [GatherTools.Phase.IDLE, GatherTools.Phase.READY]:
			p.gather.use_target()
		await physics_frame
		t += 1.0 / 120.0
		if shots != "" and not snapped and landed[0] >= 2 and p.gather.phase == GatherTools.Phase.SWING:
			snapped = true
			var side := p.global_basis.x * 3.2 + Vector3.UP * 1.4
			await _shot("chop_" + id, p.global_position + side - p.global_basis.z * 0.8, p.global_position + Vector3.UP * 1.0 - p.global_basis.z * 0.9)
	p.gather.stroke_landed.disconnect(cb)
	await _fr(30)
	return landed[0] if bool(b.state[id].done) else -1


## The dropped leg: lying along the ground, its own mesh; a carcass to haul (the rope at its foot); the axe butchers it.
func _limb(limb: LimbCarcass) -> void:
	await _fr(90)
	var lc := limb.global_transform * Vector3(0.0, limb.radius, 0.0)
	var out := lc - gi.torso.global_position
	out.y = 0.0
	out = out.normalized()
	await _shot("4_limb", lc + out * 3.2 + out.cross(Vector3.UP) * 1.2 + Vector3.UP * 1.6, lc)
	await _shot("5_limb_and_carcass", lc + out * 7.0 + out.cross(Vector3.UP) * 3.0 + Vector3.UP * 3.5, (lc + gi.torso.global_position) * 0.5)
	var g := FrontierTerrain.height_at(limb.global_position.x, limb.global_position.z)
	var tris := 0
	for si in limb.model.mesh.get_surface_count():
		tris += (limb.model.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	var flat := absf(limb.global_basis.z.normalized().y) < 0.2
	_expect(absf(limb.global_position.y - g) < 0.2 and flat and tris > 20,
			"limb: it lies along the ground (%.2f m off it), its own mesh (%d triangles)" % [limb.global_position.y - g, tris])
	_expect(CarcassLoad.is_carcass(limb) and CarcassLoad.haulable(limb) and CarcassLoad.mass_of_animal(limb, HorseHaul.data()) > 100.0,
			"limb: a carcass to haul (%.0f kg)" % CarcassLoad.mass_of_animal(limb, HorseHaul.data()))
	# the rope offered at its foot, standing there
	var foot := CarcassLoad.neck_point(limb)
	var at := foot + (foot - limb.global_position).normalized() * 0.8
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	p.global_position = at
	p.velocity = Vector3.ZERO
	await _fr(20)
	var offer: Dictionary = p.foot_drag._find_offer() if p.foot_drag else {}
	_expect(not offer.is_empty() and offer.get("animal") == limb, "limb: the rope offered at its foot (%s)" % String(offer.get("text", "none")))
	# butchered with the axe
	var vn := _pack("venison")
	var sn := _pack("sinew")
	var mid := limb.global_transform * Vector3(0.0, limb.radius, 0.0)
	await _aim_at(mid, 1.6)
	var landed := [0]
	var cb := func(type: String, _c: Dictionary) -> void:
		if type == "carcass":
			landed[0] += 1
	p.gather.stroke_landed.connect(cb)
	var t := 0.0
	while is_instance_valid(limb) and not limb.is_queued_for_deletion() and t < 30.0:
		if p.gather.target.get("work") == limb and p.gather._queued == 0 and p.gather.phase in [GatherTools.Phase.IDLE, GatherTools.Phase.READY]:
			p.gather.use_target()
		await physics_frame
		t += 1.0 / 120.0
	p.gather.stroke_landed.disconnect(cb)
	await _fr(10)
	_expect(not is_instance_valid(limb) and _pack("venison") == vn + 5 and _pack("sinew") == sn + 2,
			"limb: butchered with the axe (%d strokes): +%d meat, +%d sinew, and it is gone" % [landed[0], _pack("venison") - vn, _pack("sinew") - sn])


func _work(id: String) -> bool:
	var b := gi.butchery
	var w := b.where(id)
	await _stand_at(((w[0] as Vector3) + (w[1] as Vector3)) * 0.5, 1.8)
	b.speed = 20.0
	if not b.toggle(id):
		return false
	var t := 0.0
	while b.working != "" and t < 20.0:
		await physics_frame
		t += 1.0 / 120.0
	await _fr(30)
	return true


func _cut() -> void:
	var b := gi.butchery
	# (the knife: FieldDressing gives every player one at the start, with the wildlife, which a test run leaves out)
	if _pack(MammothButchery.KNIFE) <= 0:
		var inv := InventoryState.from_player(p)
		inv.add(MammothButchery.KNIFE, 1)
		p.inventory_pack = inv.pack.duplicate(true)
	var iv := _pack("ivory")
	var n := await _chop("tusk_l")
	var ok := n > 0
	_expect(n >= int(MammothButchery.PARTS.tusk_l.strokes) - 1, "cut: the axe chops at the left tusk, %d strokes" % n)
	var s := gi.surface("Tusk_L")
	var gone := not s.is_empty() and (s[0] as MeshInstance3D).get_surface_override_material(int(s[1])) == b._gone_mat
	_expect(ok and _pack("ivory") == iv + 1 and gone and not b.available("tusk_l") and b.axe_describe("tusk_l", p.global_position).is_empty(),
			"cut: the left tusk chopped off: ivory, the tusk gone, not offered again")
	# a leg lying up
	var leg := "foreleg_r" if gi.dead_side == "L" else "foreleg_l"
	var vn := _pack("venison")
	var sn := _pack("sinew")
	ok = await _chop(leg) > 0
	var li := int(MammothButchery.PARTS[leg].leg)
	var col_off := true
	for c in gi.legs[li].get_children():
		if c is CollisionShape3D:
			col_off = col_off and (c as CollisionShape3D).disabled
	var bi := gi.skeleton.find_bone(String(MammothButchery.PARTS[leg].cut))
	var limb: LimbCarcass = b.dropped.get(leg)
	_expect(ok and col_off and gi.skeleton.get_bone_pose_scale(bi).x < 0.05 and limb != null and is_instance_valid(limb)
			and _pack("venison") == vn, "limb: the %s chopped off: it drops, the leg gone from the mammoth" % MammothButchery.PARTS[leg].name)
	if limb:
		await _limb(limb)
	# the hide lying up, then its meat
	var up := ("R" if gi.dead_side == "L" else "L").to_lower()
	var hn := _pack("mammoth_hide")
	ok = await _work("hide_" + up)
	var hs := gi.surface("Hide_" + up.to_upper())
	_expect(ok and _pack("mammoth_hide") == hn + 1 and (hs[0] as MeshInstance3D).get_surface_override_material(int(hs[1])) == b._meat_mat
			and b.available("meat_" + up), "cut: skinned: the mammoth hide; the flank raw red; its meat can be cut now")
	vn = _pack("venison")
	# (the axe keeps at it cut after cut while the flank has meat: the cuts counted as they come)
	var cuts := [0]
	var on_cut := func(id: String) -> void:
		if id == "meat_" + up:
			cuts[0] += 1
	b.finished.connect(on_cut)
	var tries := 0
	while b.available("meat_" + up) and tries < 6:
		await _chop("meat_" + up)
		tries += 1
	b.finished.disconnect(on_cut)
	_expect(cuts[0] == MammothButchery.MEAT_CUTS and _pack("venison") == vn + 4 * MammothButchery.MEAT_CUTS
			and (hs[0] as MeshInstance3D).get_surface_override_material(int(hs[1])) == b._bone_mat,
			"cut: the flank's meat in %d cuts (+%d meat), the flank bone at the last" % [cuts[0], _pack("venison") - vn])
	var c := gi.where()
	await _shot("2_cut_up", c + Vector3(-9.0, 3.5, 7.0), c + Vector3(0.0, 1.0, 0.0))
	await _shot("3_cut_up_other_side", c + Vector3(9.0, 3.5, -7.0), c + Vector3(0.0, 1.0, 0.0))
