extends SceneTree
## Fire's bolt bodies from four sides, for the owner's eye (2026-10-16, the cel look): each body BendLooks.bolt_body makes for
## fire (the Fireball, the Punch's, Embers', the Kick disc's, the High Kick's crescent) set in the ring flying along +X, taken
## from the side, from ahead of it (where its target stands), from behind it (the caster's eye) and from above, the same four
## cameras every run, so a before and an after line up. A row a body, a column a view. Windowed (it draws):
##   zsh tools/loop/godot_run.sh --path . --resolution 1280x720 --fixed-fps 60 -s tools/bending/fire_bodies.gd -- out=<dir> tag=<name>
## Writes <dir>/fire_bodies_<tag>.png and each cell as <body>_<view>_<tag>.png. Our own effects only.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const W := 640
const H := 400
## [name, radius, long, shape]
const BODIES := [["fireball", 0.5, false, "ball"], ["punch", 0.2, false, "ball"], ["embers", 0.08, false, "ball"],
		["kick_disc", 0.45, false, "disc"], ["high_kick", 0.4, false, "crescent"]]
const VIEWS := ["side", "ahead", "behind", "above"]
## Where the body hangs: over the deck's middle, flying toward +X.
const AT := Vector3(12.5, 1.5, 0.0)
const DIST := 4.2

var out := "user://fire_bodies"
var tag := "now"


func _initialize() -> void:
	var a := CaptureKit.args({"out": out, "tag": tag})
	out = String(a.out)
	tag = String(a.tag)
	if not CaptureKit.begin(self, "FIRE BODIES", out, true):
		return
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("FIRE BODIES FAILED (watchdog)")
		quit(2))
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 120:
		await process_frame
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	view.camera.fov = 45.0
	view.camera.far = 1500.0
	var cells: Array = []
	var rows: Array = []
	for b: Array in BODIES:
		var holder := Node3D.new()
		current_scene.add_child(holder)
		holder.global_transform = Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), AT)
		BendLooks.bolt_body(holder, "fire", float(b[1]), bool(b[2]), String(b[3]))
		var row: Array = []
		for v: String in VIEWS:
			var eye := AT
			match v:
				"side":
					eye += Vector3(0.0, 0.2, DIST)
				"ahead":
					eye += Vector3(DIST, 0.5, 1.0)
				"behind":
					eye += Vector3(-DIST, 0.8, 1.0)
				"above":
					eye += Vector3(-0.3, DIST, 0.4)
			view.camera.global_transform = Transform3D(Basis.looking_at(AT - eye, Vector3.UP if v != "above" else Vector3.RIGHT), eye)
			for i in 40:
				await process_frame
			var img: Image = view.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(out.path_join("%s_%s_%s.png" % [b[0], v, tag]))
			var small := img.duplicate() as Image
			small.resize(W / 2, H / 2, Image.INTERPOLATE_LANCZOS)
			row.append(small)
		cells.append(row)
		rows.append(String(b[0]))
		holder.queue_free()
	var st := FxStage.new(self)
	await st.sheet(cells, rows, VIEWS, Vector2i(W / 2, H / 2), out.path_join("fire_bodies_%s.png" % tag), [], 110)
	print("FIRE BODIES DONE -> ", out)
	quit(0)
