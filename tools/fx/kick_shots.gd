extends SceneTree
## The Motifect moves in the game, filmed for review (the owner, 2026-10-12: "do and add what u can so we can see what it looks
## like"): a Practice stage of `el`, the player's real casts as the game plays them (the key readied, the aim held on the dummy,
## let go at full, or held on past it to grow), each cast twice: first on the old clip (the move's own, BendPoses.override
## putting the old pose back for the take), then on the new (data/bending/poses.json's motifect- clip). Fire: the Kick, the Kick
## held long (the teep), the High Kick; air: the Leap. A side camera close on the player. Each take's first frame and label in
## <dir>/shots.json. Windowed (a normal window, never on top):
##   zsh tools/loop/godot_run.sh --path . --resolution 1280x720 --fixed-fps 60 -s tools/fx/kick_shots.gd -- el=fire out=<dir>
## Writes <dir>/frames/f00000.jpg ... and prints KICK SHOTS DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
## Per element: [label, move, mode, held past full (s; 0: let go at full), the old pose of the mode].
const CASTS := {
	"fire": [["FIRE KICK  ·  Muay Thai roundhouse, low", "fire_kick", "kick", 0.0,
				{"clip": "own-bend-fire-kick-low", "alt": "own-bend-fire-kick-low-l"}],
			["FIRE KICK HELD  ·  the teep (push kick)", "fire_kick", "kick", 1.3,
				{"clip": "own-bend-fire-kick-low", "alt": "own-bend-fire-kick-low-l"}],
			["HIGH KICK  ·  Taekwondo high roundhouse", "fire_kick", "high_kick", 0.0,
				{"clip": "own-bend-fire-kick", "alt": "own-bend-fire-kick-l"}]],
	"air": [["AIR LEAP  ·  Taekwondo jumping spinning kick", "air_jump", "leap", 0.0, "own-bend-air-leap"]],
}

var out := "user://kick_shots"
var el := "fire"
var st: FxStage
var cam: Camera3D
var frame_n := 0
var recording := false
var marks: Array = []
## The clips the player's pose played through the take (printed with it: which clip each take really showed).
var seen: Array[String] = []
## The take's BendPoses.override (the old pose put back, or {}), set again after the stage's reset and kept every frame of
## the take: the stage's reset left it empty (2026-10-12: a first film's BEFORE takes played the new clips), and `lost`
## counts the frames it was found changed.
var want_ov := {}
var lost := 0


func _initialize() -> void:
	var a := CaptureKit.args({"out": out, "el": el})
	out = String(a["out"])
	el = String(a["el"])
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	st = FxStage.new(self)
	st.start(el)
	_run.call_deferred()


func _run() -> void:
	if not await st.wait_fight():
		print("KICK SHOTS FAILED (no fight)")
		quit(1)
		return
	await st.calibrate_pitch()
	await st.reset()
	st.hide_ui()
	st.aiming = true
	st.keeper = _keep
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.far = 1500.0
	current_scene.add_child(cam)
	st.cam = cam
	(st.mode.foe as NpcFighter).held = true
	await st.frames(20)
	for c: Array in CASTS[el]:
		for old in [true, false]:
			want_ov = {"moves": {String(c[1]): {"modes": {String(c[2]): c[4]}}}} if old else {}
			await _cast(String(c[0]) + ("  ·  BEFORE (our old clip)" if old else "  ·  NEW"), String(c[1]), String(c[2]), float(c[3]))
	want_ov = {}
	BendPoses.override = {}
	BendPoses.reload()
	recording = false
	var f := FileAccess.open(out.path_join("shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"el": el, "frames": frame_n, "shots": marks}))
	f.close()
	print("KICK SHOTS DONE frames=%d shots=%d" % [frame_n, marks.size()])
	quit(0)


## The camera beside the player, a little before him, low enough to see the legs, on his middle.
func _place_cam() -> void:
	var p := st.p
	var f := -p.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var side := f.cross(Vector3.UP).normalized()
	var eye := p.global_position + side * 5.2 + f * 1.6 + Vector3.UP * 1.5
	cam.global_transform = Transform3D(Basis.looking_at(p.global_position + Vector3.UP * 1.0 + f * 0.7 - eye, Vector3.UP), eye)


func _keep() -> void:
	if cam != null and (not recording or el == "air"):
		_place_cam()                              # (the leap's take follows him up)
	if recording:
		if BendPoses.override != want_ov:
			BendPoses.override = want_ov.duplicate(true)
			lost += 1
		var pz := st.sway.pose if st.sway != null else null
		if pz != null and pz.anim_name != "" and not pz.anim_name in seen:
			seen.append(pz.anim_name)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(out.path_join("frames/f%05d.jpg" % frame_n), 0.9)
		frame_n += 1


## One take: the stage reset, move `m` readied at mode `md`, the aim held till full and `past` s more, let go, its aftermath.
func _cast(label: String, m: String, md: String, past: float) -> void:
	await st.reset()
	BendPoses.override = want_ov.duplicate(true)
	lost = 0
	_place_cam()
	var sway := st.sway
	if m != "air_jump":
		sway.ready_spell(m)
		sway.set_mode(m, md)
	await st.frames(8)
	marks.append({"frame": frame_n, "label": label})
	seen.clear()
	var pk := BendPoses.pick(m, md, el, st.p)
	print("KICK SHOTS %s pick=%s from=%s override=%s" % [label, pk.get("clip", "-"), pk.get("from", "-"), BendPoses.override])
	recording = true
	await st.frames(10)
	if m == "air_jump":
		# (the Leap since the movement spells went to key 3 (2026-10-11): 3 tapped, then again within key3_min_s, the key's
		# other move; its lock goes as soon as it fills, no button held)
		var tapped := sway.key3_press()
		await st.frames(4)
		tapped = sway.key3_press() and tapped
		print("KICK SHOTS %s key 3 twice: %s" % [label, tapped])
		await st.frames(150)
		recording = false
		print("KICK SHOTS %s %s/%s played=%s (override put back %d times)" % [label, m, md, seen, lost])
		return
	sway.held_override = true
	var full_t := -1.0
	var started := false
	for i in 600:
		await st.frames(1)
		if sway.state != SwayCaster.State.IDLE:
			started = true
		elif started:
			break                                  # (it went off by itself)
		if sway.state == SwayCaster.State.FULL:
			full_t = maxf(full_t, 0.0) + 1.0 / 60.0
			if full_t >= past:
				break
	sway.held_override = false
	await st.frames(80 if m != "air_jump" else 110)
	sway.held_override = null
	recording = false
	print("KICK SHOTS %s %s/%s played=%s (override put back %d times)" % [label, m, md, seen, lost])
