extends SceneTree
## The Character look's before / after (SoftLook: Classic, the look as it was, and Soft) for the owner's eye, each pair from the
## SAME frozen frame: the frame is held (the tree paused, or the figures held still), drawn in Classic, the setting switched live
## (SoftLook.set_mode: the same switch the menus make), drawn again in Soft. Windowed (it draws); a normal window (CaptureKit's
## window policy: never pinned on top). The run's settings go to a file of its own (the player's are never touched).
##   Godot --path . --resolution 1600x900 -s tools/character/soft_look_shots.gd -- out=<dir> [what=ring|menu] [light=noon|night]
##         [element=earth] [foe=fire] [lineup=1] [palette=1] [face=1] [tag=<name part>]
## what=ring (the default): a ring match of `element` against `foe` at `light`, fought for a few seconds, then held mid-fight:
##   softlook_before|after_fight_<light><tag>.png   both fighters through the player's own camera (gameplay distance)
##   softlook_before|after_face_<light><tag>.png    the player's face up close (face=1)
##   softlook_before|after_mirror_<el>_<light>.png  lineup=1: each element's mirror, a home and an away fighter side by side at
##                                                  15 and 25 m from the player's camera; METRIC lines (the OKLab dE and value
##                                                  difference between the two sides' mean dress colour at 25 m) for both looks
##   softlook_before|after_palette_<light>.png      palette=1: everyday dress (the basic dress, open-world people) at 4 m,
##   softlook_before|after_face_people_<light>.png  and the middle one's face up close (both taken before the fight)
## what=menu: the main menu's lobby fighter, softlook_before|after_lobby.png.
## Every pair is also put side by side (Classic left, Soft right) as softlook_pair_<name>.png. Ends with SOFT LOOK SHOTS DONE.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OWN_CFG := "user://soft_look_shots.cfg"
const LOOK := "vietnamese_m_a"

var a := {}
var out := ""
var lvl: RingLevel
var p: FrontierPlayer
var mode: RingMode
var shots: Array = []


func _initialize() -> void:
	a = CaptureKit.args({"out": "", "what": "ring", "light": "noon", "element": "earth", "foe": "fire", "lineup": "0",
			"palette": "0", "face": "1", "tag": ""})
	out = String(a.out)
	if not CaptureKit.begin(self, "soft_look_shots", out, true):
		return
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SoftLook.override = SoftLook.CLASSIC
	FighterWorld.look_override = AppearanceStore.validate(CharacterPeoples.preset_look(LOOK))
	InputSetup.ensure()
	if String(a.what) == "menu":
		change_scene_to_file("res://scenes/main_menu.tscn")
		_menu.call_deferred()
		return
	KitWords.ensure_guard_action()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = String(a.element)
	MatchSetup.foes = [String(a.foe)]
	MatchSetup.difficulty = "easy"
	MatchSetup.light = String(a.light)
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	_ring.call_deferred()


func _frames(n: int) -> void:
	await CaptureKit.frames(self, n)


func _grab() -> Image:
	await _frames(3)
	await CaptureKit.drawn(self)
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## The held frame in Classic, then in Soft (switched live), saved as a pair. Returns [classic, soft].
func _pair(name: String) -> Array:
	SoftLook.override = ""
	SoftLook.set_mode(SoftLook.CLASSIC, self)
	await _frames(6)
	var before := await _grab()
	SoftLook.set_mode(SoftLook.SOFT, self)
	await _frames(10)                       # (the soft shaders' first draw)
	var after := await _grab()
	CaptureKit.save(before, out, "softlook_before_" + name)
	CaptureKit.save(after, out, "softlook_after_" + name)
	var w := before.get_width()
	var h := before.get_height()
	var sheet := Image.create(w * 2 + 8, h, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.05, 0.05, 0.06))
	sheet.blit_rect(before, Rect2i(0, 0, w, h), Vector2i.ZERO)
	sheet.blit_rect(after, Rect2i(0, 0, w, h), Vector2i(w + 8, 0))
	CaptureKit.save(sheet, out, "softlook_pair_" + name)
	shots.append(name)
	return [before, after]


func _ring() -> void:
	await _frames(20)
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	p = lvl.player
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 2000:
		if mode != null and mode.phase == "FIGHT" and mode.foe != null and not LoadingScreen.covering():
			break
		await physics_frame
	var lt := String(a.light)
	var tag := String(a.tag)
	if String(a.palette) == "1":
		# (before the fight: no dust or smoke in the air yet; the foe held meanwhile)
		if mode.foe != null:
			mode.foe.held = true
		await _palette(lt)
		p.visible = true
		if mode.foe != null:
			mode.foe.held = false
			mode.foe.visible = true
			if mode.foe.body != null:
				mode.foe.body.visible = true
			mode.foe.process_mode = Node.PROCESS_MODE_INHERIT
	# a few seconds of the fight (the bot comes at the player), then held mid-fight at a moment both fighters stand on the deck in
	# the player's view, 3-14 m apart
	# (the player's % held at 0 meanwhile: a hit pushes, never launches him off the deck)
	var rules := RingRules.current()
	for i in 60 * 3:
		await physics_frame
		if rules != null:
			rules.reset_pct(p, 0.0)
	for i in 60 * 30:
		await physics_frame
		if rules != null:
			rules.reset_pct(p, 0.0)
		if i > 30 and _both_in_view() and p.velocity.length() < 4.0:
			break
	paused = true
	await _pair("fight_%s%s" % [lt, tag])
	if String(a.face) == "1":
		await _face("face_%s%s" % [lt, tag])
	paused = false
	if String(a.lineup) == "1":
		await _lineups(lt)
	_end()


func _both_in_view() -> bool:
	var f := mode.foe as Node3D
	if f == null or not is_instance_valid(f) or not p.is_on_floor() or p.camera == null:
		return false
	var d := p.global_position.distance_to(f.global_position)
	if d < 3.0 or d > 10.0 or absf(f.global_position.y - p.global_position.y) > 0.5:
		return false
	# (both standing: the head well above the feet, not knocked down)
	var body := p.appearance.body if p.appearance != null else null
	if body != null:
		var sk := body.skeleton
		var hy := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("headb"))).origin.y
		if hy - p.global_position.y < 1.3:
			return false
	var vp := root.get_visible_rect().size
	for b: Node3D in [p, f]:
		for h: float in [0.1, 1.7]:
			var at := b.global_position + Vector3.UP * h
			if p.camera.is_position_behind(at):
				return false
			var s2 := p.camera.unproject_position(at)
			if s2.x < 40.0 or s2.y < 40.0 or s2.x > vp.x - 40.0 or s2.y > vp.y - 40.0:
				return false
	return true


## The player's face up close: a camera of the tool's own in front of the head, looking back at it.
func _face(name: String) -> void:
	var body := p.appearance.body if p.appearance != null else null
	if body == null:
		return
	var sk := body.skeleton
	# (the head bone's origin sits at the crown here: the face is about 0.1 m under it)
	var head := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("headb"))).origin - Vector3.UP * 0.1
	var fwd := head - p.camera.global_position
	fwd.y = 0.0
	fwd = fwd.normalized()
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.near = 0.02
	current_scene.add_child(cam)
	cam.global_position = head + fwd * 1.05 + fwd.cross(Vector3.UP) * 0.22 + Vector3.UP * 0.03
	cam.look_at(head, Vector3.UP)
	cam.make_current()
	await _pair(name)
	p.camera.make_current()
	cam.queue_free()


## Each element's mirror: home and away side by side at 15 and 25 m from the player's camera, the 25 m frame measured.
func _lineups(lt: String) -> void:
	if mode.foe != null:
		mode.foe.process_mode = Node.PROCESS_MODE_DISABLED
		mode.foe.visible = false
		if mode.foe.body != null:
			mode.foe.body.visible = false
	for i in 60 * 3:                          # (the fight's dust and smoke settled)
		await physics_frame
	var sides: GDScript = load("res://scripts/ring/ring_sides.gd")
	var fwd := -p.camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var cam_at := p.camera.global_position
	var feet := Vector3(cam_at.x, p.global_position.y, cam_at.z)
	var right := fwd.cross(Vector3.UP).normalized()
	for el: String in Bending.ELEMENTS:
		sides.set(&"sides_override", [[el], [el]])
		var bots: Array = []
		for d: float in [15.0, 25.0]:
			var at := feet + fwd * d
			var gap := 1.1 + d * 0.02
			bots.append(_bot("ring_team_a", el, at - right * gap))
			bots.append(_bot("ring_team_b", el, at + right * gap))
		for i in 40:
			await physics_frame
		for b: Node in bots:
			b.process_mode = Node.PROCESS_MODE_DISABLED
		var pr := await _pair("mirror_%s_%s" % [el, lt])
		_measure(el, "classic", pr[0], bots[2], bots[3], lt)
		_measure(el, "soft", pr[1], bots[2], bots[3], lt)
		for b: Node in bots:
			b.get_parent().queue_free()
		await _frames(4)
	sides.set(&"sides_override", null)


func _bot(faction: String, el: String, at: Vector3) -> NpcFighter:
	var opts := {"face": p.global_position, "tag": "ring", "tactics": "bend", "element": el, "weapon": "", "sidearm": "",
			"skill": "easy", "seed": 1750, "y": at.y}
	var sq := NpcSquad.spawn(lvl, faction, 1, at, opts)
	var b := sq.members[0] as NpcFighter
	b.held = true
	b.no_death = true
	return b


## The mean colour of each side's dress (a column from the knees to the chest) in `img`: the METRIC line.
func _measure(el: String, look: String, img: Image, home: Node3D, away: Node3D, lt: String) -> void:
	var sums := [Vector3.ZERO, Vector3.ZERO]
	var ns := [0, 0]
	var bots := [home, away]
	var right := p.camera.global_basis.x
	for side in 2:
		var b := bots[side] as Node3D
		var lo := p.camera.unproject_position(b.global_position + Vector3.UP * 0.45 - right * 0.1)
		var hi := p.camera.unproject_position(b.global_position + Vector3.UP * 1.45 + right * 0.1)
		var r := Rect2i(Vector2i(mini(int(lo.x), int(hi.x)), mini(int(lo.y), int(hi.y))),
				Vector2i(absi(int(hi.x) - int(lo.x)) + 1, absi(int(hi.y) - int(lo.y)) + 1))
		for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
				var c := img.get_pixel(x, y)
				sums[side] += Vector3(c.r, c.g, c.b)
				ns[side] += 1
	if ns[0] == 0 or ns[1] == 0:
		print("METRIC softlook_sides %s %s %s n/a" % [el, look, lt])
		return
	var ca: Vector3 = sums[0] / float(ns[0])
	var cb: Vector3 = sums[1] / float(ns[1])
	var la := _oklab(Color(ca.x, ca.y, ca.z))
	var lb := _oklab(Color(cb.x, cb.y, cb.z))
	print("METRIC softlook_sides %s %s %s deltaE %.1f value_diff %.3f (home %s, away %s, 25 m)" % [el, look, lt,
			la.distance_to(lb) * 100.0, absf(la.x - lb.x), Color(ca.x, ca.y, ca.z).to_html(false), Color(cb.x, cb.y, cb.z).to_html(false)])


static func _oklab(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return SoftLook.lin_to_oklab(Vector3(l.r, l.g, l.b))


## Everyday dress (not a side's colours): the basic dress on two of the presets, and an open-world look, 4 m in front of a camera
## of the tool's own, the ring's light on them.
func _palette(lt: String) -> void:
	p.visible = false
	if mode.foe != null:
		mode.foe.process_mode = Node.PROCESS_MODE_DISABLED
		mode.foe.visible = false
		if mode.foe.body != null:
			mode.foe.body.visible = false
	var fwd := -p.camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var base := Vector3(p.global_position.x, p.global_position.y, p.global_position.z) + fwd * 3.0
	var looks: Array = []
	for preset: String in ["vietnamese_m_a", "vietnamese_f_a", "japanese_m_a"]:
		var lk := CharacterPeoples.preset_look(preset)
		if lk.is_empty():
			continue
		lk = AppearanceStore.validate(lk)
		looks.append(lk)
	var actors: Array = []
	for i in looks.size():
		var lk: Dictionary = looks[i]
		var actor := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
		current_scene.add_child(actor)
		actor.global_position = base + right * (float(i) - (looks.size() - 1) * 0.5) * 0.95
		actor.look_at(actor.global_position - fwd, Vector3.UP)
		actor.rotate_y(PI)
		var sk := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var ap := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := CharacterBodyMesh.attach(sk, ap)
		BindRest.ensure_character(actor)
		if i == looks.size() - 1:
			var fac := NpcFactions.look_for("toughs", RandomNumberGenerator.new())
			if fac.get("outfit") is Dictionary:
				lk["outfit"] = fac.outfit
		PlayerAppearance.dress(body, lk)
		if ap.has_animation(&"actor_b/actor_b-p-relax-idle"):
			ap.play(&"actor_b/actor_b-p-relax-idle")
		actors.append(actor)
	var cam := Camera3D.new()
	cam.fov = 34.0
	current_scene.add_child(cam)
	cam.global_position = base - fwd * 4.2 + Vector3.UP * 1.25
	cam.look_at(base + Vector3.UP * 0.95, Vector3.UP)
	cam.make_current()
	await _frames(30)
	paused = true
	await _pair("palette_%s" % lt)
	# the middle figure's face up close
	var mid := actors[actors.size() / 2] as Node3D
	var msk := mid.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var head := (msk.global_transform * msk.get_bone_global_pose(msk.find_bone("headb"))).origin + Vector3.UP * 0.05
	cam.fov = 24.0
	cam.global_position = head - fwd * 1.05 + right * 0.25 + Vector3.UP * 0.02
	cam.look_at(head, Vector3.UP)
	await _pair("face_people_%s" % lt)
	paused = false
	for ac: Node in actors:
		ac.queue_free()
	p.camera.make_current()
	cam.queue_free()


func _menu() -> void:
	await CaptureKit.secs(self, 7.0)
	await _pair("lobby")
	_end()


func _end() -> void:
	SoftLook.override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	print("SOFT LOOK SHOTS DONE %s %s" % [out, ", ".join(shots)])
	quit(0)
