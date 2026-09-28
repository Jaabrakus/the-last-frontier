extends SceneTree
## The musket as a club (user 2026-09-27: "make it where we can turn muskets into clubs"; picked: a key flips it,
## held by the barrel), headless on the real level, the player driven by its input actions:
##   flip      middle mouse with the musket out turns it into a club (GatherTools.CLUB): the gun's own model hidden,
##             the club (a copy end for end) shown, Weapon.clubbed set
##   no shot   LMB clubbed does not shoot (still loaded, never aiming): it attacks (D) and strikes a straw dummy where
##             the butt passes, blunt (nothing cut in to)
##   back      middle mouse again turns it back: the gun itself in the hand, LMB aims it again
##   refused   not while aiming
##   ends      switching to another weapon ends the club at once
##   knocked   knocked down clubbed (PlayerRagdoll, every die thrown): the club ends, the gun is itself again and it is
##             the gun that flies (a PlacedWeapon), never a "musket_club" item
##   Godot --headless --path . -s tests/melee/test_musket_club.gd
## "MUSKET CLUB TEST PASSED" and exit 0 when every check passes. Run it under a hard time limit.

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
		print("MUSKET CLUB TEST FAILED (no player)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	g = p.gather
	await _fr(240)
	await _run()
	if failures.is_empty():
		print("MUSKET CLUB TEST PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("MUSKET CLUB TEST FAILED (%d of %d)" % [failures.size(), checks])
		quit(1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String, frames := 2) -> void:
	Input.action_press(action)
	await _fr(frames)
	Input.action_release(action)


func _home() -> void:
	p.global_position = SPOT + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	p.grip.stamina = p.grip.stamina_max
	await _fr(20)


## Visible copies of a long gun in the hands other than the club (the sling rig's stand-ins, the gun's own model).
func _other_guns() -> Array:
	var out := []
	for n in p.find_children("*", "Node3D", true, false):
		var nd := n as Node3D
		var nm := String(nd.name)
		if (nm.begins_with("Flyer_") or nm == "MusketModel") and nd.is_visible_in_tree():
			out.append(nm)
	return out


func _run() -> void:
	await _home()
	var w := p.weapon as Firearm
	_expect(p.weapon_key == "musket" and w != null and w.active and not p.hands_free, "the musket is out (%s)" % p.weapon_key)
	if w == null:
		return
	var loaded := w.loaded
	# flip
	await _tap("club_grip")
	for i in 90:
		await physics_frame
		if g._club_flip >= 1.0:
			break
	_expect(g.tool == GatherTools.CLUB and w.clubbed, "middle mouse: the musket is a club (tool %s)" % g.tool)
	_expect(not w.model.visible and g._model_hand != null and g._model_hand.visible, "the gun's own model hidden, the club shown")
	_expect(_other_guns() == [], "no other copy of the gun in the hands (%s)" % str(_other_guns()))
	_expect(is_equal_approx(g._club_flip, 1.0), "turned round (flip %.2f)" % g._club_flip)
	# no shot: an attack
	var dummy := TargetDummy.new()
	var at := SPOT + Vector3(0.0, 0.0, -1.6)
	dummy.position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
	current_scene.add_child(dummy)
	dummy.max_health = 1.0e6
	dummy.health = 1.0e6
	await _fr(10)
	var hp := dummy.health
	Input.action_press("move_right")
	Input.action_press("fire")
	await _fr(3)
	Input.action_release("move_right")
	Input.action_release("fire")
	_expect(bool(g._swing.get("melee", false)) and String(g._swing.get("dir", "")) == "D", "LMB clubbed attacks (D)")
	var aimed := false
	for i in 200:
		await physics_frame
		aimed = aimed or w.state == Firearm.State.AIMING
		if g.phase == GatherTools.Phase.READY and g._swing.is_empty():
			break
	_expect(not aimed and w.loaded == loaded, "no shot: never aimed, still %s" % ("loaded" if loaded else "empty"))
	_expect(dummy.health < hp, "the butt strikes the dummy (took %.0f)" % (hp - dummy.health))
	var lc: Dictionary = g.melee.last_contact
	_expect(not lc.is_empty() and not bool(lc.get("core", false)), "blunt: nothing cut in to, on through it (%s)" % str(lc.get("surface", "-")))
	dummy.queue_free()
	await _home()
	# the stab keeps the gun as the guard's right hand holds it (user: "the hold hand twist and turns")
	var turn := await _stab_turn()
	_expect(turn < 12.0, "stab: the gun does not turn in the hand (at most %.1f deg)" % turn)
	await _home()
	# back
	await _tap("club_grip")
	await _fr(40)
	_expect(g.tool == "" and not w.clubbed and w.model.visible, "middle mouse again: the gun itself again (tool '%s')" % g.tool)
	Input.action_press("fire")
	await _fr(8)
	_expect(w.state == Firearm.State.AIMING, "LMB aims it again (state %d)" % w.state)
	# refused while aiming
	await _tap("club_grip")
	await _fr(10)
	_expect(g.tool == "" and not w.clubbed, "no club while aiming")
	Input.action_press("aim")
	await _fr(4)
	Input.action_release("aim")
	Input.action_release("fire")
	for i in 240:
		await physics_frame
		if w.state in [Firearm.State.READY, Firearm.State.EMPTY]:
			break
	# a weapon switch ends it
	await _fr(20)
	await _tap("club_grip")
	await _fr(30)
	_expect(g.tool == GatherTools.CLUB, "clubbed again (state %d)" % w.state)
	var other := ""
	for k: String in p.weapon_order:
		if k != "musket" and p.is_usable(k):
			other = k
			break
	if other != "":
		p.switch_weapon(other)
		await _fr(60)
		_expect(g.tool == "" and not w.clubbed, "switching to the %s ends the club (tool '%s')" % [other, g.tool])
	# pulled out and flipped at once (user 2026-09-27: "when we pull out the musket and then flip it to club mode we
	# have two butts"): clubbed the first moment it can be after the draw, and no other copy of the gun in a hand on
	# any frame while the draw's hand-off finishes
	p.switch_weapon("musket")
	for i in 240:
		await physics_frame
		if g.can_club():
			break
	g.club_toggle()
	var seen := []
	for i in 90:
		await physics_frame
		for nm: String in _other_guns():
			if not seen.has(nm):
				seen.append(nm)
	_expect(g.tool == GatherTools.CLUB, "clubbed straight after the draw")
	_expect(seen == [], "pulled out and flipped: never a second gun in the hands (%s)" % str(seen))
	var r := PlayerRagdoll.of(p)
	r.drop_chance = 1.0
	p.knock_down(Vector3(4.0, 4.0, 0.0))
	await _fr(90)
	_expect(g.tool == "" and not w.clubbed, "knocked: the club ends")
	_expect(r.dropped_tool == null, "knocked: no club item on the ground (%s)" % str(r.dropped_tool))
	_expect(r.dropped != null and is_instance_valid(r.dropped) and r.dropped.key == "musket", "knocked: the gun itself flies")
	r.drop_chance = 0.0


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
