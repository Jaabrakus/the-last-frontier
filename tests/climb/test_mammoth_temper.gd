extends SceneTree
## The woolly mammoth's temper (MammothTemper; user 2026-09-27: "if we are within distance they will attack us charge at
## us and swing there trunk to get us to back away, there goal is to survive and run away", "do a ground stomp"), on the
## climbing yard, headless:
##
##   Godot --headless --path . -s tests/climb/test_mammoth_temper.gd -- --no-capture
##
##   calm      a player far off: it paces, untroubled
##   threat    a player within ALERT_R: it stops and turns to face them, head up and shaking; past CHARGE_R it holds its
##             ground; backed off past CALM_R, it calms and paces again
##   charge    within CHARGE_R: it charges, rams a player standing before it (blunt, a heavy blow) and knocks them down
##             (a ragdoll, PlayerRagdoll), thrown back
##   swing     close before it on its left: the trunk swept to its left strikes them and throws them away
##   stomp     at its forefeet: it rears and slams them down: the ground shakes and they are thrown off
##   flee      up from a buckled leg: it walks off, away from the player; then home to where it stood, and paces
## Ends with "MAMMOTH TEMPER TEST PASSED (<n> checks)" or "MAMMOTH TEMPER TEST FAILED (<f> of <n>)".

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var gi: StandInGiant
var tp: MammothTemper


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	await _fr(30)
	p = current_scene.get_node("Player") as FrontierPlayer
	p.ignore_mouse_capture = true
	var yard := current_scene.get("yard") as ClimbYard
	gi = yard.giant
	tp = yard.temper
	_expect(tp != null and not tp.enabled, "off in a test run unless asked for")
	await _put(Vector3(0.0, 0.0, 70.0))
	tp.enabled = true
	await _calm()
	await _threat()
	await _charge()
	await _swing()
	await _stomp()
	await _flee()
	if fails.is_empty():
		print("MAMMOTH TEMPER TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			print("FAIL: ", f)
		print("MAMMOTH TEMPER TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _fr(n: int) -> void:
	for i in n:
		await physics_frame


## The player standing at `off` from where the mammoth stands, in its own frame (Body's: -Z ahead, its left -X).
func _put(off: Vector3) -> void:
	var at := gi.body.global_transform * off
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1
	p.global_position = at
	p.velocity = Vector3.ZERO
	await _fr(4)


## The mammoth back where it was built, calm; the player whole.
func _reset() -> void:
	tp.enabled = false
	# knocked down: up again first (the ragdoll carries the player's body)
	var t := 0.0
	while PlayerRagdoll.of(p).is_down() and t < 10.0:
		await physics_frame
		t += 1.0 / 120.0
	await _fr(2)
	gi.set_driven(false)
	gi._home = gi.spawn
	gi._pace_c = Vector3.INF
	tp.attacks = 0
	tp._go("calm")
	p.health = p.max_health
	if p.wounds:
		p.wounds.pool = 0.0
	await _put(Vector3(0.0, 0.0, 70.0))
	await _fr(30)
	tp.enabled = true
	await _fr(10)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _facing(to: Vector3) -> float:
	var d := to - gi.where()
	d.y = 0.0
	return rad_to_deg(gi.heading().angle_to(d.normalized()))


func _calm() -> void:
	await _fr(240)
	_expect(tp.mood == "calm" and not gi.driven, "calm: a player 70 m off, it paces untroubled (%s)" % tp.mood)


func _threat() -> void:
	var at := gi.body.global_transform * Vector3(-12.0, 0.0, -14.0)
	await _put(Vector3(-12.0, 0.0, -14.0))
	await _fr(60)
	_expect(tp.mood == "threat" and gi.driven, "threat: a player %.0f m off: it turns on them (%s)" % [_flat(at, gi.where()), tp.mood])
	await _fr(360)
	_expect(_facing(p.global_position) < 20.0 and gi.display, "threat: it faces them, the head up and shaking (%.0f deg off)" %
			_facing(p.global_position))
	var w := gi.where()
	await _fr(360)
	_expect(tp.mood == "threat" and _flat(gi.where(), w) < 0.5, "threat: past %.0f m it holds its ground" % MammothTemper.CHARGE_R)
	await _put(Vector3(-12.0, 0.0, -14.0).normalized() * 36.0)
	await _fr(240)
	_expect(tp.mood == "calm" and not gi.driven, "threat: backed off past %.0f m, it calms (%s)" % [MammothTemper.CALM_R, tp.mood])
	await _reset()


func _charge() -> void:
	await _put(Vector3(0.0, 0.0, -13.0))
	var hp := p.health
	var hit_at := Vector3.INF
	var charged := false
	var hurt := false
	for i in 120 * 8:
		await physics_frame
		charged = charged or tp.mood == "charge"
		if not hurt and p.health < hp:
			hurt = true
			hit_at = p.global_position
			break
	_expect(charged, "charge: a player 13 m before it: it charges")
	_expect(hurt and hp - p.health >= MammothTemper.RAM.damage * 0.9, "charge: it rams them (%.0f health lost)" % (hp - p.health))
	await _fr(120)
	_expect(hurt and _flat(p.global_position, hit_at) > 1.5, "charge: they are thrown back %.1f m" % _flat(p.global_position, hit_at))
	await _reset()


func _swing() -> void:
	await _put(Vector3(-3.2, 0.0, -4.2))
	var hp := p.health
	var played := ""
	var hit_at := Vector3.INF
	for i in 120 * 6:
		await physics_frame
		if gi.acting != "":
			played = gi.acting
		if p.health < hp:
			hit_at = p.global_position
			break
	_expect(played == "TrunkSwing_L", "swing: close before it on its left: the trunk swept to its left (%s)" % played)
	_expect(hp - p.health >= MammothTemper.SWING.damage * 0.9, "swing: the trunk strikes them (%.0f health lost)" % (hp - p.health))
	await _fr(120)
	var l := gi.body.global_transform.affine_inverse() * p.global_position
	_expect(hit_at != Vector3.INF and _flat(p.global_position, hit_at) > 1.5 and l.x < -3.0,
			"swing: they are thrown %.1f m, off its left side" % _flat(p.global_position, hit_at))
	await _reset()


func _stomp() -> void:
	await _put(MammothTemper.FOREFEET + Vector3(-2.2, 0.0, -0.8))
	var hp := p.health
	var played := ""
	var most := 0.0
	var hit_at := Vector3.INF
	for i in 120 * 6:
		await physics_frame
		if gi.acting != "":
			played = gi.acting
		most = maxf(most, CameraShake.of(p.camera).trauma)
		if p.health < hp and hit_at == Vector3.INF:
			hit_at = p.global_position
		if hit_at != Vector3.INF and gi.acting == "":
			break
	_expect(played == "Stomp", "stomp: at its forefeet: it rears and stomps (%s)" % played)
	_expect(most > 0.5, "stomp: the ground shakes (trauma %.2f)" % most)
	_expect(hp - p.health >= MammothTemper.STOMP.damage * 0.9 and _flat(p.global_position, hit_at) > 1.0,
			"stomp: they are struck (%.0f) and thrown off" % (hp - p.health))
	await _reset()


func _flee() -> void:
	await _put(Vector3(-6.0, 0.0, -12.0))
	tp.enabled = true
	await _fr(30)
	gi.knock_down("Front_R")
	await _fr(int((StandInGiant.DOWN_S + 3.5) * 120.0))
	var d0 := _flat(gi.where(), p.global_position)
	var fled := tp.mood == "flee"
	await _fr(120 * 4)
	var d1 := _flat(gi.where(), p.global_position)
	_expect(fled and d1 - d0 > 6.0, "flee: up from the buckled leg it walks off (%s; %.0f m to %.0f m from the player)" %
			["fleeing" if fled else tp.mood, d0, d1])
	# the player gone off: it comes home
	await _put(Vector3(0.0, 0.0, 200.0))
	var home := false
	for i in 120 * 60:
		await physics_frame
		if tp.mood == "calm" and not gi.driven:
			home = true
			break
	_expect(home and _flat(gi.where(), gi.spawn.origin) < 1.5, "home: it walks back to where it stood and paces (%.1f m off)" %
			_flat(gi.where(), gi.spawn.origin))
