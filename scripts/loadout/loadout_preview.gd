extends Node3D
## Loadout preview (scenes/loadout_preview.tscn): Actor_B with the skinned body (CharacterBodyMesh),
## posed straight from the AnimationPlayer's clips (LoadoutClipPoser: the clips as extracted, layered
## base + partial + additive twin like the graph composes them), a loadout preset stowed on the body
## by SlingRig, and a handoff mode that plays every draw set's grab / equip clips and their reverse,
## swapping the model between the body and the hand at the data's clip phases.
##
##   Godot --path <Frontier> res://scenes/loadout_preview.tscn [-- preset=<id> clip=<key> cycle=1]  (interactive)
##   Godot --path <Frontier> --resolution 1280x720 res://scenes/loadout_preview.tscn -- shots=/abs/dir [presets=a,b]
##         (renders one sheet per preset: front, back, left, right, 3/4, crouch, sprint, belt close-up,
##          back / chest close-up, weapon in hand; then quits. Windowed: the window shows for ~1 min.)
##   Godot --path <Frontier> --resolution 1280x720 res://scenes/loadout_preview.tscn -- review=/abs/dir [presets=a,b]
##         (review sheets per preset: all stowed from 6 sides + crouch + sprint; traversal (ledge climb,
##          ledge idle, vault) and close-ups of both hips, the back and the chest; every drawable item in
##          the hand in turn with the rest stowed, idle / crouch / sprint / aim. About 2 min windowed.)
##
## Keys: 1-8 / PgUp PgDn preset · C clip (Shift: back) · H handoff cycle on/off · X sling all / draw back
## · N next handoff now · F outfit bulk (legacy coat, fur coat, blanket wrap, shirt) · M state (stand,
## mounted, prone, traversal) · I reach IK · Space pause · arrows orbit · W/S zoom · Q/E height · P save a
## screenshot to user://.
##
## Provenance: the rig, clips and bind pose are Actor_B. Weapon models are the project's own
## (WeaponModels, ThrowableModels); the quiver, horn and straps are SlingModels / SlingStrap stand-ins
## until assets/loadout/ delivers them.

const CLIP_KEYS := ["idle", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "aim", "jump", "climb_ledge", "ledge_idle", "vault"]
## Relaxed carry arms per weapon kind and locomotion (the weapons' own `relaxed` tables:
## scripts/weapons/musket.gd, bow.gd, pistol.gd, throwable.gd).
const CARRY := {
	"musket": {"idle": "actor_b-p-rifle-run-arms", "run": "actor_b-p-rifle-run-arms", "crouch": "actor_b-p-rifle-crouch-idle-arms"},
	"bow": {"idle": "actor_b-p-bow-move--arms", "run": "actor_b-p-bow-move--arms", "sprint": "actor_b-p-bow-sprint--arms", "crouch": "actor_b-p-bow-crouch-idle--arms"},
	"pistol": {"idle": "actor_b-r-arm-gun-idle", "run": "actor_b-r-arm-gun", "crouch": "actor_b-r-arm-gun-crouch-idle"},
	"throw": {"idle": "actor_b-p-1h-arm--part", "run": "actor_b-p-1h-arm--part", "crouch": "actor_b-p-1h-arm-crouch--part"},
}
const AIM_KEY := {"musket": "aim_musket", "over_under": "aim_musket", "pistol": "aim_pistol", "bow": "aim_bow",
		"spear_pair": "aim_throw", "tomahawk": "aim_throw", "atlatl": "aim_throw"}
## The hand + prop-bone layer each weapon lays over its aim pose (the weapons' clips tables "hands":
## scripts/weapons/musket.gd, pistol.gd, bow.gd): it places the weapon in the hands.
const AIM_HANDS := {"musket": "actor_b-p-rifle-idle-aim--hands", "over_under": "actor_b-p-rifle-idle-aim--hands",
		"pistol": "actor_b-pistol-aim--hands", "bow": "actor_b-p-bow-aim-hands-idle"}
const OUTFITS := ["", "fur_coat_tailored", "blanket_wrap_matchcoat", "shirt_only"]
const STATES := ["stand", "mounted", "prone", "traversal"]
const DRAWABLE := ["musket", "over_under", "bow", "pistol", "spear_pair", "tomahawk", "atlatl"]

var args := {}
var data: LoadoutData
var preset_ids: Array = []
var preset_i := 0
var loadout: Loadout
var sk: Skeleton3D
var ap: AnimationPlayer
var body: CharacterBodyMesh
var poser: LoadoutClipPoser
var rig: SlingRig
var cam: Camera3D
var cam_yaw := 210.0
var cam_pitch := -6.0
var cam_dist := 3.6
var cam_y := 1.15
var clip_i := 0
var t := 0.0
var paused := false
var hand_nodes := {}
var ho_mode := false
var ho := {}
var ho_queue: Array = []
var outfit_i := 0
var state_i := 0
var ui: Label
var caption: Label
var shot_mode := false
var _hold_kind := ""
var _events: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	data = LoadoutData.get_default()
	preset_ids = data.preset_ids()
	var want := String(args.get("preset", data.default_preset()))
	preset_i = maxi(preset_ids.find(want), 0)
	_build_world()
	_build_character()
	_build_ui()
	_set_preset(preset_i)
	if args.has("clip"):
		clip_i = maxi(CLIP_KEYS.find(String(args.clip)), 0)
	if String(args.get("cycle", "0")) == "1":
		ho_mode = true
		_queue_cycle()
	rig.handoff_event.connect(func(id: String, ev: StringName) -> void: _events.append("%s:%s" % [id, ev]))
	if args.has("quit_after"):
		get_tree().create_timer(float(args.quit_after)).timeout.connect(func() -> void:
			print("PREVIEW EVENTS %d: %s" % [_events.size(), ", ".join(_events)])
			get_tree().quit())
	if args.has("shots"):
		shot_mode = true
		_run_shots.call_deferred(String(args.shots))
	elif args.has("views"):
		shot_mode = true
		_run_views.call_deferred(String(args.views), String(args.get("out", OS.get_user_data_dir())))
	elif args.has("strips"):
		shot_mode = true
		_run_strips.call_deferred(String(args.strips), String(args.get("out", OS.get_user_data_dir())))
	elif args.has("review"):
		shot_mode = true
		_run_review.call_deferred(String(args.review))


# --- scene --------------------------------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.64, 0.7, 0.74)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.8, 0.84)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.45, -1.0, 0.55), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.6, -0.4, -0.8), Vector3.UP)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 14)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.43, 0.46, 0.37)
	ground.material_override = gm
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true


func _build_character() -> void:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	inst.name = "Actor_B"
	add_child(inst)
	sk = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	body = CharacterBodyMesh.attach(sk, ap)
	poser = LoadoutClipPoser.new(sk, ap)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Label.new()
	ui.position = Vector2(12, 10)
	ui.add_theme_font_size_override("font_size", 14)
	ui.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	layer.add_child(ui)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caption.position = Vector2(-300, 8)
	caption.size = Vector2(600, 30)
	caption.visible = false
	layer.add_child(caption)


func _set_preset(i: int) -> void:
	preset_i = wrapi(i, 0, preset_ids.size())
	loadout = Loadout.from_preset(String(preset_ids[preset_i]))
	loadout.outfit_bulk = OUTFITS[outfit_i]
	ho = {}
	ho_queue.clear()
	if rig == null:
		rig = SlingRig.new()
		rig.name = "SlingRig"
		add_child(rig)
		rig.setup(sk, body, loadout)
	else:
		rig.set_loadout(loadout)
	_build_hand_models()
	rig.set_state(STATES[state_i])
	_hold_kind = String(loadout.item(loadout.in_hand).get("kind", ""))


func _build_hand_models() -> void:
	for k in hand_nodes:
		if is_instance_valid(hand_nodes[k]):
			(hand_nodes[k] as Node).get_parent().queue_free()
	hand_nodes.clear()
	for it: Dictionary in loadout.items:
		var k := String(it.kind)
		if not k in DRAWABLE:
			continue
		var es := rig.entries_of(String(it.id))
		if es.is_empty():
			continue
		var side: String = (es[0] as SlingRig.Entry).hold
		var att := BoneAttachment3D.new()
		att.name = "Hand_" + String(it.id)
		att.bone_name = SlingRig.PROPS[side]
		sk.add_child(att)
		var m := SlingModels.unit("spear" if k == "spear_pair" else k)
		m.transform = SlingRig.HAND_OFFSET
		att.add_child(m)
		hand_nodes[String(it.id)] = m
		rig.set_hand_model(String(it.id), m)


# --- frame ----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not paused:
		t += delta
	var layers := _base_layers()
	var held := rig.item_in_hand()
	if ho_mode or not ho.is_empty():
		_step_handoff(delta if not paused else 0.0, layers)
	elif held != "" and rig.mode_of(held) == SlingRig.Mode.HELD and _clip_key() != "aim":
		layers.append_array(_carry_layers(String(loadout.item(held).get("kind", ""))))
	elif held != "" and _clip_key() == "aim":
		var hc := String(AIM_HANDS.get(String(loadout.item(held).get("kind", "")), ""))
		if hc != "" and poser.has_clip(hc):
			layers.append([hc, fmod(t, maxf(poser.length(hc), 0.01)), "partial"])
	poser.pose(layers)
	_update_camera()
	if not shot_mode:
		_update_ui()


func _clip_key() -> String:
	return CLIP_KEYS[clip_i]


func _stance() -> String:
	return "crouch" if _clip_key().begins_with("crouch") else "stand"


func _clip_name(key: String) -> String:
	var clips: Dictionary = data.rt("preview", {}).get("clips", {})
	if key == "aim":
		var held := rig.item_in_hand()
		var k := String(loadout.item(held).get("kind", "")) if held != "" else _hold_kind
		key = String(AIM_KEY.get(k, "idle"))
	return String((clips.get(key, clips.get("idle", ["actor_b-p-stealth-idle"])) as Array)[0])


func _base_layers() -> Array:
	var c := _clip_name(_clip_key())
	if not ho.is_empty():
		c = "actor_b-p-crouch-idle" if _stance() == "crouch" else "actor_b-p-stealth-idle"
	var L := maxf(poser.length(c), 0.01)
	return [[c, fmod(t, L)]]


func _carry_layers(kind: String) -> Array:
	var fam := kind
	if kind in ["spear_pair", "tomahawk", "atlatl"]:
		fam = "throw"
	elif kind == "over_under":
		fam = "musket"
	var tab: Dictionary = CARRY.get(fam, {})
	var key := "crouch" if _stance() == "crouch" else ("sprint" if _clip_key() == "sprint" and tab.has("sprint") else ("run" if _clip_key() in ["run", "sprint", "walk"] else "idle"))
	var c := String(tab.get(key, tab.get("idle", "")))
	if c == "":
		return []
	return [[c, fmod(t, maxf(poser.length(c), 0.01)), "partial"]]


# --- handoff cycle ------------------------------------------------------------------------------

func _drawable_ids() -> Array:
	var out: Array = []
	for it: Dictionary in loadout.items:
		if String(it.kind) in DRAWABLE:
			var es := rig.entries_of(String(it.id))
			if es.is_empty():
				continue
			if LoadoutDrawClips.new((es[0] as SlingRig.Entry).ds, _stance(), poser).ok:
				out.append(String(it.id))
	return out


## Queues: put away what is in the hand, draw every drawable item in turn, then hands free.
func _queue_cycle() -> void:
	ho_queue.clear()
	var held := rig.item_in_hand()
	for id in _drawable_ids():
		if held != "":
			ho_queue.append({"op": "holster", "item": held})
		ho_queue.append({"op": "draw", "item": id})
		held = id
	if held != "":
		ho_queue.append({"op": "holster", "item": held, "sling": true})


func _next_op() -> void:
	ho = {}
	if ho_queue.is_empty():
		if ho_mode:
			_queue_cycle()
		if ho_queue.is_empty():
			return
	var op: Dictionary = ho_queue.pop_front()
	var es := rig.entries_of(String(op.item))
	if es.is_empty():
		return
	var e: SlingRig.Entry = es[0]
	for x: SlingRig.Entry in es:
		if x.mode != SlingRig.Mode.STOWED:
			e = x
	var dc := LoadoutDrawClips.new(e.ds, _stance(), poser)
	ho = op.duplicate()
	ho["dc"] = dc
	ho["t"] = 0.0
	var fin := dc.sling_finish if op.get("sling", false) and dc.sling_finish != "" else dc.finish
	if op.op == "holster" and not op.get("sling", false) and not ho_queue.is_empty():
		fin = ""   # the next draw starts at once (graph: holster_finish only when nothing follows)
	ho["finish"] = fin
	ho["finish_s"] = poser.length(fin) if fin != "" else 0.0
	if op.op == "draw":
		rig.begin_draw(String(op.item), {"driven": true, "stance": _stance()})
	else:
		rig.begin_holster(String(op.item), {"driven": true, "stance": _stance()})


func _step_handoff(delta: float, layers: Array) -> void:
	if ho.is_empty():
		_next_op()
		if ho.is_empty():
			return
	ho.t = float(ho.t) + delta
	var tn: float = float(ho.t) * rig.rate
	var dc: LoadoutDrawClips = ho.dc
	var id := String(ho.item)
	if ho.op == "draw":
		layers.append_array(dc.draw_layers(tn))
		rig.drive(id, dc.draw_role(tn), dc.draw_phase(tn))
		if tn > dc.draw_length() + 1.2 * rig.rate:
			_next_op()
	else:
		layers.append_array(dc.holster_layers(tn, String(ho.finish)))
		rig.drive(id, dc.holster_role(tn), dc.holster_phase(tn))
		if tn > dc.equip_s + float(ho.finish_s) + 0.3 * rig.rate:
			_next_op()


# --- input --------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	var shift := (event as InputEventKey).shift_pressed
	if k >= KEY_1 and k <= KEY_8:
		_set_preset(k - KEY_1)
	match k:
		KEY_PAGEUP:
			_set_preset(preset_i - 1)
		KEY_PAGEDOWN:
			_set_preset(preset_i + 1)
		KEY_C:
			clip_i = wrapi(clip_i + (-1 if shift else 1), 0, CLIP_KEYS.size())
		KEY_H:
			ho_mode = not ho_mode
			if ho_mode and ho.is_empty():
				_queue_cycle()
		KEY_N:
			_next_op()
		KEY_X:
			var held := rig.item_in_hand()
			if held != "":
				ho_queue = [{"op": "holster", "item": held, "sling": true}]
			elif rig.last_slung != "":
				ho_queue = [{"op": "draw", "item": rig.last_slung}]
			if ho.is_empty():
				_next_op()
		KEY_F:
			outfit_i = wrapi(outfit_i + 1, 0, OUTFITS.size())
			loadout.outfit_bulk = OUTFITS[outfit_i]
			rig.set_outfit_bulk(OUTFITS[outfit_i])
		KEY_M:
			state_i = wrapi(state_i + 1, 0, STATES.size())
			rig.set_state(STATES[state_i])
		KEY_I:
			rig.enable_reach_ik(rig.reach_ik == null)
		KEY_SPACE:
			paused = not paused
		KEY_LEFT:
			cam_yaw -= 15.0
		KEY_RIGHT:
			cam_yaw += 15.0
		KEY_UP:
			cam_pitch = clampf(cam_pitch - 5.0, -60.0, 40.0)
		KEY_DOWN:
			cam_pitch = clampf(cam_pitch + 5.0, -60.0, 40.0)
		KEY_W:
			cam_dist = maxf(cam_dist - 0.3, 0.6)
		KEY_S:
			cam_dist += 0.3
		KEY_Q:
			cam_y += 0.1
		KEY_E:
			cam_y -= 0.1
		KEY_P:
			var path := "user://loadout_preview_%d.png" % Time.get_ticks_msec()
			get_viewport().get_texture().get_image().save_png(path)
			print("saved ", ProjectSettings.globalize_path(path))


func _update_camera() -> void:
	if shot_mode:
		return
	var yaw := deg_to_rad(cam_yaw)
	var pitch := deg_to_rad(cam_pitch)
	var tgt := Vector3(0, cam_y, 0)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	cam.look_at_from_position(tgt + dir * cam_dist, tgt, Vector3.UP)


func _update_ui() -> void:
	var lines: Array[String] = []
	lines.append("%s  [%s]  grade %s" % [loadout.display_name, loadout.preset_id, String(data.preset(loadout.preset_id).get("grade", "-"))])
	lines.append("clip: %s (%s)   state: %s   outfit bulk: %s   reach IK: %s" % [_clip_key(), _clip_name(_clip_key()),
			STATES[state_i], OUTFITS[outfit_i] if OUTFITS[outfit_i] != "" else "legacy coat", "on" if rig.reach_ik else "off"])
	var cap := LoadoutRules.pistol_capacity(loadout.gear, loadout.shoulder_ew_sash)
	var eff := LoadoutRules.effective_pistol_capacity(loadout.gear, loadout.point_kinds(), loadout.shoulder_ew_sash)
	lines.append("gear: %s   pistols %d / max %d (effective %d)" % [", ".join(loadout.gear), loadout.pistols().size(), int(cap.max), int(eff.max)])
	for it: Dictionary in loadout.items:
		var m := rig.mode_of(String(it.id))
		var st := ""
		if String(it.kind) == "pistol":
			st = " loaded" if bool(it.state.get("loaded", true)) else " EMPTY"
		lines.append("  %-11s %-14s x%d  %s%s" % [it.id, ",".join(it.points), int(it.count), SlingRig.Mode.keys()[m], st])
	var errs := LoadoutRules.validate(loadout)
	if not errs.is_empty():
		lines.append("INVALID: " + "; ".join(errs))
	if not ho.is_empty():
		lines.append("handoff: %s %s  t=%.2f" % [ho.op, ho.item, float(ho.t)])
	lines.append("keys: 1-8 preset  C clip  H handoff cycle  X sling all/draw  F outfit  M state  I IK  arrows/W/S/Q/E camera  Space pause  P shot")
	ui.text = "\n".join(lines)


# --- screenshot sheets ----------------------------------------------------------------------------

## [name, clip key, camera eye (relative to the character, which faces +Z), target, hands free, t]
const VIEWS := [
	["front", "idle", Vector3(0.0, 1.2, 3.9), Vector3(0, 1.15, 0), true, 0.6],
	["back", "idle", Vector3(0.0, 1.25, -3.9), Vector3(0, 1.15, 0), true, 0.6],
	["left side", "idle", Vector3(3.9, 1.2, 0.0), Vector3(0, 1.15, 0), true, 0.6],
	["right side", "idle", Vector3(-3.9, 1.2, 0.0), Vector3(0, 1.15, 0), true, 0.6],
	["3/4 back right", "idle", Vector3(-2.8, 1.45, -2.8), Vector3(0, 1.15, 0), true, 0.6],
	["crouch", "crouch_idle", Vector3(2.4, 1.2, -2.9), Vector3(0, 0.8, 0), true, 0.6],
	["sprint", "sprint", Vector3(-3.4, 1.2, -1.2), Vector3(0, 1.1, 0), true, 0.35],
	["belt close-up (right hip)", "idle", Vector3(-1.05, 1.05, 0.45), Vector3(-0.12, 0.93, 0.0), true, 0.6],
	["close-up (back / chest)", "idle", Vector3(0.0, 1.2, -1.45), Vector3(0, 1.1, 0), true, 0.6],
	["in hand", "aim", Vector3(-1.6, 1.9, -3.0), Vector3(0, 1.25, 0.3), false, 0.5],
]


func _run_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var want: Array = String(args.get("presets", ",".join(preset_ids))).split(",", false)
	paused = true
	for pid: String in want:
		var i := preset_ids.find(pid)
		if i < 0:
			continue
		_set_preset(i)
		var cells: Array[Image] = []
		for v: Array in VIEWS:
			var view_name: String = v[0]
			var ckey: String = v[1]
			var hands_free: bool = v[4]
			clip_i = CLIP_KEYS.find(ckey)
			t = float(v[5])
			ho = {}
			if hands_free:
				for it: Dictionary in loadout.items:
					rig.snap_stowed(String(it.id))
			elif loadout.in_hand != "":
				rig.snap_held(loadout.in_hand)
			var eye: Vector3 = v[2]
			var tgt: Vector3 = v[3]
			if view_name.begins_with("close-up") and (loadout.gear.has("pistol_sling") or loadout.gear.has("br_belts_cartridge")):
				view_name = "close-up (chest)"
				eye = Vector3(0.25, 1.25, 1.35)
				tgt = Vector3(0, 1.12, 0)
			cam.fov = 38.0 if not view_name.contains("close") else 34.0
			cam.look_at_from_position(eye, tgt, Vector3.UP)
			caption.text = "%s  -  %s" % [loadout.display_name, view_name]
			caption.visible = true
			ui.visible = false
			for f in 4:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			cells.append(_crop_cell(img))
		var sheet := _compose(cells, 5)
		var path := "%s/%s_sheet.png" % [dir, pid]
		sheet.save_png(path)
		print("saved ", path)
	print("LOADOUT SHOTS DONE -> ", dir)
	get_tree().quit()


## Ad-hoc views for close inspection: views="name:ex,ey,ez,tx,ty,tz,fov,clip,hands(0/1),t;..." with the
## eye / target in the character's frame (it faces +Z). One PNG per view in `out`.
func _run_views(spec: String, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	paused = true
	for v: String in spec.split(";", false):
		var nm := v.get_slice(":", 0)
		var f := v.get_slice(":", 1).split(",")
		clip_i = maxi(CLIP_KEYS.find(f[7] if f.size() > 7 else "idle"), 0)
		t = float(f[9]) if f.size() > 9 else 0.6
		if f.size() > 8 and f[8] == "0" and loadout.in_hand != "":
			rig.snap_held(loadout.in_hand)
		else:
			for it: Dictionary in loadout.items:
				rig.snap_stowed(String(it.id))
		cam.fov = float(f[6]) if f.size() > 6 else 38.0
		cam.look_at_from_position(Vector3(float(f[0]), float(f[1]), float(f[2])), Vector3(float(f[3]), float(f[4]), float(f[5])), Vector3.UP)
		ui.visible = false
		for k in 4:
			await get_tree().process_frame
		var path := "%s/%s_%s.png" % [out, loadout.preset_id, nm]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()


## Handoff frame strips: strips="preset:item;preset:item" -> <out>/<preset>_<item>_handoff.png, 8 frames of
## the draw (grab start .. settle end .. carry) over 4 frames of the holster, the moving copy in view.
const STRIP_CAMS := {
	"pistol": [Vector3(-1.2, 1.25, 0.9), Vector3(-0.1, 1.0, 0.1)],
	"musket": [Vector3(1.5, 1.6, -1.6), Vector3(0.05, 1.3, -0.05)],
	"bow": [Vector3(-1.2, 1.55, -1.8), Vector3(0.0, 1.25, 0.0)],
	"tomahawk": [Vector3(-1.5, 1.3, -1.3), Vector3(0.0, 1.05, -0.05)],
	"atlatl": [Vector3(-1.5, 1.3, -1.3), Vector3(0.0, 1.05, -0.05)],
	"spear_pair": [Vector3(1.6, 1.7, -1.8), Vector3(0.05, 1.35, -0.05)],
}


func _run_strips(spec: String, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	paused = true
	for pair: String in spec.split(";", false):
		var pid := pair.get_slice(":", 0)
		var id := pair.get_slice(":", 1)
		_set_preset(maxi(preset_ids.find(pid), 0))
		clip_i = 0
		for it: Dictionary in loadout.items:
			rig.snap_stowed(String(it.id))
		var kind := String(loadout.item(id).get("kind", ""))
		var camd: Array = STRIP_CAMS.get(kind, STRIP_CAMS.pistol)
		cam.fov = 40.0
		cam.look_at_from_position(camd[0], camd[1], Vector3.UP)
		ui.visible = false
		var cells: Array[Image] = []
		ho_queue = [{"op": "draw", "item": id}]
		_next_op()
		if ho.is_empty():
			continue
		var dc: LoadoutDrawClips = ho.dc
		var total := dc.draw_length()
		for k in 8:
			ho.t = total * k / 7.0 / rig.rate
			caption.text = "%s  draw %s  %.2f s (x%d)" % [id, dc.draw_role(float(ho.t) * rig.rate), float(ho.t), int(rig.rate)]
			caption.visible = true
			for f in 3:
				await get_tree().process_frame
			cells.append(_crop_cell(get_viewport().get_texture().get_image()))
		ho_queue = [{"op": "holster", "item": id, "sling": true}]
		_next_op()
		var hs := dc.equip_s
		for k in 4:
			ho.t = hs * (k + 1) / 4.0 / rig.rate
			caption.text = "%s  put away  %.2f s" % [id, float(ho.t)]
			for f in 3:
				await get_tree().process_frame
			cells.append(_crop_cell(get_viewport().get_texture().get_image()))
		var sheet := _compose(cells, 6)
		var path := "%s/%s_%s_handoff.png" % [out, pid, id]
		sheet.save_png(path)
		print("saved ", path)
		ho = {}
	get_tree().quit()


## Review sheets (review=<dir> [presets=a,b] [settle=frames]): per preset, 4x2 sheets of
##   <pid>_1_stowed.png   all stowed: front, back, right, left, 3/4 back right, 3/4 front left, crouch, sprint
##   <pid>_2_trav.png     traversal state, hands free: ledge climb x2, ledge idle, vault; close-ups of the
##                        right hip, left hip, back and chest
##   <pid>_3_<n>.png      each drawable item in the hand in turn (the rest stowed), 4 cells per item:
##                        3/4 back left idle, crouch, sprint, aim
## The camera follows the pelvis. Each cell waits `settle` frames so the yield smoothing converges.
const REVIEW_STOWED := [
	["front", "idle", Vector3(0.0, 0.05, 3.9)], ["back", "idle", Vector3(0.0, 0.1, -3.9)],
	["right side", "idle", Vector3(-3.9, 0.05, 0.0)], ["left side", "idle", Vector3(3.9, 0.05, 0.0)],
	["3/4 back right", "idle", Vector3(-2.8, 0.3, -2.8)], ["3/4 front left", "idle", Vector3(2.6, 0.2, 2.8)],
	["crouch 3/4 back", "crouch_idle", Vector3(2.4, 0.5, -2.9)], ["sprint side", "sprint", Vector3(-3.4, 0.1, -1.2)],
]
const REVIEW_TRAV := [
	["ledge climb 30%", "climb_ledge", 0.3, Vector3(-2.2, 0.5, -2.4)], ["ledge climb 65%", "climb_ledge", 0.65, Vector3(2.2, 0.5, -2.4)],
	["ledge idle", "ledge_idle", 0.5, Vector3(-1.8, 0.2, -2.6)], ["vault 45%", "vault", 0.45, Vector3(-3.0, 0.4, -1.6)],
]
const REVIEW_CLOSE := [
	["close right hip", Vector3(-1.05, 1.05, 0.45), Vector3(-0.12, 0.93, 0.0)],
	["close left hip", Vector3(1.05, 1.05, 0.45), Vector3(0.12, 0.93, 0.0)],
	["close back", Vector3(0.0, 1.2, -1.45), Vector3(0, 1.1, 0)],
	["close chest", Vector3(0.25, 1.25, 1.35), Vector3(0, 1.12, 0)],
]
const REVIEW_HELD := [
	["3/4 back left", "idle", Vector3(2.4, 0.45, -2.6)], ["crouch", "crouch_idle", Vector3(-2.4, 0.5, -2.9)],
	["sprint", "sprint", Vector3(-3.4, 0.1, -1.2)], ["aim", "aim", Vector3(-1.6, 0.8, -3.0)],
]


func _pelvis_world() -> Vector3:
	var b := sk.find_bone("pelvis")
	return sk.global_transform * sk.get_bone_global_pose(b).origin if b >= 0 else Vector3(0, 1.0, 0)


func _review_cell(label: String, ckey: String, tfrac: float, eye_off: Vector3, fixed_tgt: Variant, settle: int) -> Image:
	clip_i = maxi(CLIP_KEYS.find(ckey), 0)
	var c := _clip_name(ckey)
	t = tfrac * maxf(poser.length(c), 0.01) if tfrac >= 0.0 else 0.6
	# pose once so the pelvis is where this clip puts it, then aim the camera at it
	poser.pose(_base_layers())
	var tgt: Vector3 = fixed_tgt if fixed_tgt is Vector3 else _pelvis_world() + Vector3(0, 0.12, 0)
	var eye: Vector3 = eye_off if fixed_tgt is Vector3 else tgt + eye_off
	cam.fov = 34.0 if label.begins_with("close") else 38.0
	cam.look_at_from_position(eye, tgt, Vector3.UP)
	caption.text = "%s  -  %s" % [loadout.preset_id, label]
	caption.visible = true
	ui.visible = false
	for f in settle:
		await get_tree().process_frame
	return _crop_cell(get_viewport().get_texture().get_image())


func _review_save(cells: Array[Image], path: String) -> void:
	if cells.is_empty():
		return
	_compose(cells, 4).save_png(path)
	print("saved ", path)


func _run_review(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var want: Array = String(args.get("presets", ",".join(preset_ids))).split(",", false)
	var settle := int(args.get("settle", "14"))
	paused = true
	for pid: String in want:
		var i := preset_ids.find(pid)
		if i < 0:
			continue
		state_i = 0
		_set_preset(i)
		for it: Dictionary in loadout.items:
			rig.snap_stowed(String(it.id))
		var cells: Array[Image] = []
		for v: Array in REVIEW_STOWED:
			cells.append(await _review_cell(v[0], v[1], -1.0, v[2], null, settle))
		_review_save(cells, "%s/%s_1_stowed.png" % [dir, pid])
		cells = []
		rig.set_state("traversal")
		for v: Array in REVIEW_TRAV:
			cells.append(await _review_cell(v[0], v[1], v[2], v[3], null, settle))
		rig.set_state("stand")
		for v: Array in REVIEW_CLOSE:
			cells.append(await _review_cell(v[0], "idle", -1.0, v[1], v[2], settle))
		_review_save(cells, "%s/%s_2_trav.png" % [dir, pid])
		var n := 0
		cells = []
		for id: String in _drawable_ids_all():
			for it: Dictionary in loadout.items:
				rig.snap_stowed(String(it.id))
			rig.snap_held(id)
			_hold_kind = String(loadout.item(id).get("kind", ""))
			for v: Array in REVIEW_HELD:
				cells.append(await _review_cell("%s in hand: %s" % [id, v[0]], v[1], -1.0, v[2], null, settle))
			if cells.size() >= 8:
				n += 1
				_review_save(cells, "%s/%s_3_%d.png" % [dir, pid, n])
				cells = []
		if not cells.is_empty():
			n += 1
			_review_save(cells, "%s/%s_3_%d.png" % [dir, pid, n])
		for it: Dictionary in loadout.items:
			rig.snap_stowed(String(it.id))
	print("LOADOUT REVIEW DONE -> ", dir)
	get_tree().quit()


## Every drawable item of the loadout (also those whose draw clips are not built yet).
func _drawable_ids_all() -> Array:
	var out: Array = []
	for it: Dictionary in loadout.items:
		if String(it.kind) in DRAWABLE and not rig.entries_of(String(it.id)).is_empty():
			out.append(String(it.id))
	return out


func _crop_cell(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var cw := int(h * 0.8)
	var cell := img.get_region(Rect2i((w - cw) / 2, 0, cw, h))
	cell.resize(384, 480, Image.INTERPOLATE_LANCZOS)
	return cell


func _compose(cells: Array[Image], cols: int) -> Image:
	var cw := cells[0].get_width()
	var ch := cells[0].get_height()
	var rows := int(ceil(cells.size() / float(cols)))
	var sheet := Image.create(cw * cols, ch * rows, false, cells[0].get_format())
	sheet.fill(Color(0.2, 0.2, 0.2))
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	return sheet
