extends SceneTree
## Filmstrips of the hands' holds (push n01c: the torch in either hand, the axe and raised holds, the long gun gripped
## in the middle in the left hand, the crouch-walk one-hand hold, the quick throwables). Needs a window:
##   Godot --path . --resolution 1280x720 -s tests/torch/tools/hold_shots.gd -- out=<dir> [move=idle|walk|run|sprint|
##       crouch|crouch_walk|jump|turn] [weapon=musket|over_under|bow|pistol|tomahawk|spear|none] [torch=1] [relax=1]
##       [act=raise|aim|pickup|light|throw_tomahawk|throw_spear|back|switch_<weapon>] [hour=22.5] [shots=6] [gap=0.12] [settle=1.2]
##       [views=left,front,frontleft] [light=0.8] [tag=<name>] [focus=lhand] [gauge=1]
## grip=<name>: the left fist's grip on the gun (GunMiddleCarryIK.GRIPS).
## focus=lhand: close cameras round the LEFT hand (views hfront, hside, hbelow, htop, hback, hin: in front of, out to
## the left of, below, above, behind and inside of the hand, 0.45 m off); gauge=1 prints the left hand's grip on the
## long gun per shot (tests/torch/lib/grip_gauge.gd: palm gap, finger gaps, depth, wrap).
## relax=1: the relaxed one-hand carry comes on at once (PlayerAnim.relax_after_s 0.2): crouch-walking, the left hand
## holds the gun in the middle. act: raise holds T from the second shot; aim presses RMB (the torch is tossed);
## pickup: aim, then back to the torch and E; light taps T with the musket out (the handoff); throw_*: switches from
## the musket to the throwable (the gun stays in the left hand), throws, and switches back.
## Saves <out>/<tag>_<view>_<k>.png and one filmstrip per view (<tag>_<view>_strip.png).

var args := {}
const VIEWS := {
	"front": Vector3(0.4, 0.1, -2.4),
	"left": Vector3(-2.5, 0.1, -0.2),
	"right": Vector3(2.5, 0.1, -0.2),
	"back": Vector3(0.4, 0.5, 2.6),
	"frontleft": Vector3(-1.8, 0.3, -1.8),
	"frontright": Vector3(1.8, 0.3, -1.8),
	"top": Vector3(-0.3, 2.0, -1.0),
}
## Close cameras round the left hand (focus=lhand), in the player's facing (x right, y up, -z ahead), from the hand.
const HAND_VIEWS := {
	"hfront": Vector3(-0.08, 0.06, -0.45),
	"hside": Vector3(-0.45, 0.06, -0.04),
	"hbelow": Vector3(-0.2, -0.4, -0.12),
	"htop": Vector3(-0.1, 0.45, -0.1),
	"hback": Vector3(-0.1, 0.08, 0.45),
	"hin": Vector3(0.3, -0.05, -0.3),
}
const Gauge := preload("res://tests/torch/lib/grip_gauge.gd")
const PLACES := {"fort": [Vector2(0.0, 6.0), 0.0], "forest": [Vector2(-68.5, -53.7), 129.7], "range": [Vector2(0.0, -20.0), 0.0]}

var p: FrontierPlayer
var shots_by_view := {}
var tag := ""
var gauge = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var out: String = args.get("out", "user://hold_shots")
	DirAccess.make_dir_recursive_absolute(out)
	var move: String = args.get("move", "idle")
	var act: String = args.get("act", "")
	tag = String(args.get("tag", "%s_%s%s" % [args.get("weapon", "musket"), move, ("_" + act) if act != "" else ""]))
	var shots := int(args.get("shots", "6"))
	var gap := float(args.get("gap", "0.12"))
	var views: PackedStringArray = String(args.get("views", "left,front,frontleft")).split(",")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	p = current_scene.get_node("Player")
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in current_scene.find_children("*", "DayNight", true, false):
		(n as DayNight).clock.running = false
		(n as DayNight).clock.set_time(float(args.get("hour", "22.5")))
	if args.get("relax", "0") == "1":
		p.anim.relax_after_s = 0.2
	if args.has("grip"):
		p.anim.mid_ik.grip = String(args.grip)
	if args.has("roll"):
		p.anim.mid_ik.roll_max_deg = float(args.roll)
	gauge = Gauge.new()
	gauge.watch(p.skeleton)
	await _phys(60)
	var wk: String = args.get("weapon", "musket")
	if wk == "over_under":
		OverUnderKit.install(p)
	if wk == "none":
		p.toggle_hands_free()
	elif wk != p.weapon_key:
		p.switch_weapon(wk)
	await _settle_switch()
	var place: Array = PLACES.get(String(args.get("place", "fort")), PLACES.fort)
	var at: Vector2 = place[0]
	var hit := _ground(Vector3(at.x, 50, at.y))
	p.global_position = Vector3(at.x, hit + 0.05, at.y)
	p.velocity = Vector3.ZERO
	p.yaw = deg_to_rad(float(args.get("yaw", str(place[1]))))
	p.pitch = deg_to_rad(float(args.get("pitch", "-8")))
	await _phys(30)
	if args.get("torch", "0") == "1" and act != "light":
		await _tap("torch", 4)
		await _phys(90)
		for i in 200:
			if p.torch.holding() and not p.torch.pending:
				break
			await _phys(1)
		await _phys(40)
	var crouch := move.begins_with("crouch")
	if crouch != p.is_crouching:
		await _tap("crouch", 2)
		await _phys(40)
	var held: Array = {"walk": ["walk", "move_forward"], "run": ["move_forward"], "sprint": ["sprint", "move_forward"],
			"crouch_walk": ["move_forward"], "jump": ["move_forward"], "turn": ["move_left"]}.get(move, [])
	for a: String in held:
		Input.action_press(a)
	await _phys(int(float(args.get("settle", "1.2")) * Engine.physics_ticks_per_second))
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.far = 400.0
	current_scene.add_child(cam)
	var fill: OmniLight3D = null
	if float(args.get("light", "0.8")) > 0.0:
		fill = OmniLight3D.new()
		fill.omni_range = 7.0
		fill.light_energy = float(args.get("light", "0.8"))
		current_scene.add_child(fill)
	var acts := {}
	match act:
		"raise":
			acts[1] = func() -> void: Input.action_press("torch")
		"aim":
			acts[1] = func() -> void: Input.action_press("aim")
		"pickup":
			acts[1] = func() -> void: Input.action_press("aim")
		"light":
			acts[1] = func() -> void: await _tap("torch", 4)
		"throw_tomahawk", "throw_spear":
			var tk := "tomahawk" if act == "throw_tomahawk" else "spear"
			acts[1] = func() -> void: p.switch_weapon(tk)
			acts[int(shots * 0.45)] = func() -> void: Input.action_press("fire")
			acts[int(shots * 0.6)] = func() -> void: Input.action_release("fire")
			acts[int(shots * 0.8)] = func() -> void: p.switch_weapon("musket")
		"back":
			acts[1] = func() -> void: p.switch_weapon("tomahawk")
			acts[int(shots * 0.5)] = func() -> void: p.switch_weapon("musket")
		_:
			if act.begins_with("switch_"):
				var sk_key := act.substr(7)
				acts[1] = func() -> void: p.switch_weapon(sk_key)
	if move == "jump":
		acts[1] = func() -> void: await _tap("jump")
	for k in shots:
		if acts.has(k):
			await (acts[k] as Callable).call()
		if act == "pickup" and k == shots - 2:
			Input.action_release("aim")
			await _phys(40)
			await _walk_to_torch()
			await _tap("interact", 6)
			await _phys(60)
		await _phys(maxi(int(gap * Engine.physics_ticks_per_second), 1))
		await process_frame
		await process_frame
		paused = true
		await process_frame
		var h := p.anim.holds
		print("shot %d: loco %s crouch %s torch %s side %s pass %s raise %.2f mid %.2f (on %s) exch %s | weapon %s aim %.2f relaxed %s one_hand %s offhand %s" % [
				k, p.anim.loco.state, p.is_crouching, p.torch.holding(), p.anim.torch_ik.side, p.anim.torch_ik.passing(),
				h.raise, p.anim.mid_ik.progress, p.anim.mid_ik.on, h.exchange, p.weapon_key, p.weapon.aim if p.weapon else 0.0,
				p.anim.relaxed, p.anim.one_hand, str(h.offhand.name) if h.offhand else "-"])
		var sk := p.skeleton
		var chest := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("spined"))).origin
		var hand: Vector3 = (sk.global_transform * (gauge.final_pose("l_palm") as Transform3D)).origin
		var basis := Basis(Vector3.UP, p.yaw)
		if args.get("gauge", "0") == "1":
			_gauge()
		for v in views:
			if v == "game":
				p.camera.current = true
			elif HAND_VIEWS.has(v):
				cam.near = 0.02
				var hoff: Vector3 = HAND_VIEWS[v]
				cam.global_position = hand + basis * hoff
				cam.look_at(hand, Vector3.UP if absf(hoff.normalized().y) < 0.9 else basis * Vector3.FORWARD)
				cam.current = true
				if fill:
					fill.global_position = cam.global_position + basis * Vector3(0.1, 0.3, 0.0)
			else:
				var off: Vector3 = VIEWS.get(v, VIEWS.front)
				var target := chest - Vector3(0, 0.3, 0)
				cam.global_position = chest + basis * off
				cam.look_at(target, Vector3.UP)
				cam.current = true
				if fill:
					fill.global_position = cam.global_position + Vector3(0, 0.6, 0)
			await _shot(out, v, k)
		paused = false
	for a: String in held:
		Input.action_release(a)
	for a in ["aim", "fire", "torch"]:
		Input.action_release(a)
	_strips(out)
	quit()


## The left hand's grip on the long gun it holds in the middle (printed; set up on first use).
func _gauge() -> void:
	var mid := p.anim.mid_ik
	if mid == null or mid.gun == null or mid.progress <= 0.0:
		print("  grip: the gun is not in the left hand (progress %.2f)" % (mid.progress if mid else 0.0))
		return
	if gauge.model != mid.gun:
		if not gauge.setup(p, mid.gun, -mid.balance_m):
			print("  grip: gauge set-up failed: ", gauge.info)
			return
		print("  ", gauge.info)
	print("  ", Gauge.line(gauge.measure()), " (hand weight %.2f, roll %.0f deg, wrist %.0f deg)" % [mid.last_w_left,
			rad_to_deg(mid._roll), float(mid.last_wrist_bend.l)])


func _settle_switch() -> void:
	await _phys(30)
	for i in 600:
		if not p.is_switching() and not (p.weapon and p.weapon.is_equipping()) and p._held_switch == "":
			break
		await _phys(1)
	await _phys(20)


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String, frames := 4) -> void:
	Input.action_press(action)
	await _phys(frames)
	Input.action_release(action)


func _ground(from: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 100.0)
	q.exclude = [p.get_rid()]
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3).y if not h.is_empty() else 0.0


func _walk_to_torch() -> void:
	var d := p.torch.last_dropped
	if d == null or not is_instance_valid(d):
		return
	p.camera.current = true
	var to := d.global_position - p.global_position
	to.y = 0.0
	var at := d.global_position - to.normalized() * 1.2
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.velocity = Vector3.ZERO
	p.yaw = atan2(-to.x, -to.z)
	p.pitch = deg_to_rad(-20.0)
	await _phys(50)
	print("pickup: target is the torch: ", p.interactor.target == d)


func _shot(out: String, v: String, k: int) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s_%s_%d.png" % [out, tag, v, k]
	img.save_png(path)
	if not shots_by_view.has(v):
		shots_by_view[v] = []
	shots_by_view[v].append(path)


## One filmstrip per view: the shots side by side, each cropped to the middle and scaled down.
func _strips(out: String) -> void:
	var cw := 360
	var ch := 400
	for v: String in shots_by_view:
		var paths: Array = shots_by_view[v]
		var strip := Image.create(cw * paths.size(), ch, false, Image.FORMAT_RGB8)
		for i in paths.size():
			var img := Image.load_from_file(String(paths[i]))
			if img == null:
				continue
			var w := img.get_width()
			var h := img.get_height()
			var crop_w := int(h * float(cw) / ch)
			var sub := img.get_region(Rect2i((w - crop_w) / 2, 0, crop_w, h))
			sub.resize(cw, ch)
			strip.blit_rect(sub, Rect2i(0, 0, cw, ch), Vector2i(i * cw, 0))
		var sp := "%s/%s_%s_strip.png" % [out, tag, v]
		strip.save_png(sp)
		print("strip ", sp)
