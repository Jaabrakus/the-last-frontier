extends SceneTree
## Stills of the bent elements' effects on the Tidebreak deck, for the look (BendLooks, BendZone._look; the owner judges by
## eye): per element, (a) a bolt in flight, (b) its hit on the deck, (c) its signature zone (fire wall, water wall and
## bubble, ice wall shatter, air shield and tornado, earth wall rise, lightning strike). The same camera for every run, so a
## before and an after line up. Windowed (it draws), at a fixed 60 fps so every shot is taken at the same moment:
##   Godot --path . --fixed-fps 60 -s tools/bending/vfx_lineup.gd -- out=<dir> [tag=<name>] [only=fire,water] [style=<s>]
## Writes <dir>/<element>_<bolt|hit|zone>_<tag>.png. style= is handed to the effects as Engine meta "bend_fx_style".

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const W := 1280
const H := 720
const ELEMENTS := ["fire", "water", "ice", "air", "stone", "lightning"]
## The camera: over the near deck looking at the dark far boards and the end wall.
const EYE := Vector3(7.2, 1.8, 3.8)
const C := Vector3(12.5, 0.0, 0.0)

## Bolts per element: [spec, offset back along the path (m), offset down (m)].
var BOLTS := {
	"fire": [[{"kind": "fire", "mps": 22.0, "radius_m": 0.5, "range_m": 35.0}, 0.0, 0.0],
			[{"kind": "fire", "mps": 22.0, "radius_m": 0.2, "range_m": 35.0}, 3.2, 0.9]],
	"water": [[{"kind": "water", "mps": 34.0, "gravity": 1.0, "radius_m": 0.22, "range_m": 30.0}, 0.0, 0.0],
			[{"kind": "water", "mps": 34.0, "gravity": 1.0, "radius_m": 0.18, "range_m": 30.0}, 3.0, 0.9]],
	"ice": [[{"kind": "ice", "mps": 42.0, "gravity": 0.0, "radius_m": 0.16, "range_m": 40.0, "long": true}, 0.0, 0.0],
			[{"kind": "ice", "mps": 42.0, "radius_m": 0.1, "range_m": 40.0}, 2.5, 0.8],
			[{"kind": "ice", "mps": 42.0, "radius_m": 0.1, "range_m": 40.0}, 3.4, 1.0]],
	"air": [[{"kind": "air", "mps": 28.0, "radius_m": 0.35, "range_m": 30.0}, 0.0, 0.0],
			[{"kind": "air", "mps": 28.0, "radius_m": 0.12, "range_m": 35.0, "long": true}, 3.0, 0.9]],
	"stone": [[{"kind": "stone", "mps": 30.0, "gravity": 0.0, "radius_m": 0.3, "range_m": 35.0}, 0.0, 0.0],
			[{"kind": "stone", "mps": 30.0, "radius_m": 0.09, "range_m": 30.0}, 2.6, 0.8],
			[{"kind": "stone", "mps": 30.0, "radius_m": 0.09, "range_m": 30.0}, 3.4, 0.6]],
}

var view
var out := "user://vfx_lineup"
var tag := "now"
var right := Vector3.ZERO
var flat := Vector3.ZERO
var made: Array[Node] = []


func _initialize() -> void:
	var only: Array = ELEMENTS.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
		elif a.begins_with("only="):
			only = Array(a.substr(5).split(","))
		elif a.begins_with("style="):
			Engine.set_meta(&"bend_fx_style", a.substr(6))
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	await process_frame
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	view.camera.fov = 50.0
	view.camera.far = 1500.0
	var look := C + Vector3.UP * 1.0
	view.camera.global_transform = Transform3D(Basis.looking_at(look - EYE, Vector3.UP), EYE)
	flat = Vector3(look.x - EYE.x, 0.0, look.z - EYE.z).normalized()
	right = flat.cross(Vector3.UP).normalized()
	await _frames(120)
	for el in only:
		if el != "lightning":
			await _bolt_shot(el)
			await _hit_shot(el)
		else:
			await _lightning_shots()
		await _zone_shot(el)
	print("VFX LINEUP DONE ", tag)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _snap(name: String) -> void:
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out.path_join("%s_%s.png" % [name, tag]))
	print("shot ", name)


func _dummy(at: Vector3) -> Node3D:
	var d := Node3D.new()
	d.name = "LineupDummy"
	current_scene.add_child(d)
	d.global_position = at
	made.append(d)
	return d


## Everything made for a shot gone, and time for its effects to fade.
func _clear(wait := 420) -> void:
	for b in get_nodes_in_group(BendBolt.GROUP):
		(b as BendBolt).end("lineup")
	for z in get_nodes_in_group(BendZone.GROUP):
		(z as BendZone).end()
	for w in get_nodes_in_group(FormRaised.GROUP):
		(w as Node).queue_free()
	for n in made:
		if is_instance_valid(n):
			n.queue_free()
	made.clear()
	await _frames(wait)


## (a) the bolts crossing the view left to right, the first at the middle when taken.
func _bolt_shot(el: String) -> void:
	var d := 7.0
	var mid := C + Vector3.UP * 1.4 + right * 0.6
	var by := _dummy(mid - right * 12.0)
	var lead: Dictionary = BOLTS[el][0][0]
	var frames := int(round(d / float(lead.mps) * 60.0))
	for e: Array in BOLTS[el]:
		var spec: Dictionary = e[0]
		var back := float(e[1])
		var from := mid - right * (d + back) - Vector3.UP * float(e[2])
		BendBolt.launch(by, from, right, spec)
	await _frames(frames)
	await _snap("%s_bolt" % el)
	await _clear()


## (b) the lead bolt down onto the deck at C, taken 7 frames (0.12 s) after it lands.
func _hit_shot(el: String) -> void:
	var at := C + Vector3.UP * 0.05
	var from := at - right * 4.0 + Vector3.UP * 2.6 - flat * 1.0
	var by := _dummy(from - right)
	var spec: Dictionary = (BOLTS[el][0][0] as Dictionary).duplicate()
	spec["range_m"] = 30.0
	var b := BendBolt.launch(by, from, at - from, spec)
	var st := {"done": false}
	b.ended.connect(func(_w: String) -> void: st.done = true)
	for i in 120:
		await process_frame
		if st.done:
			break
	await _frames(7)
	await _snap("%s_hit" % el)
	await _clear()


func _lightning_shots() -> void:
	var a := C + Vector3.UP * 1.5 - right * 6.0
	var b := C + Vector3.UP * 1.1 + right * 4.5
	BendLooks.lightning(a, b)
	await _frames(2)
	await _snap("lightning_bolt")
	await _clear(120)
	BendLooks.lightning(C + Vector3.UP * 1.6 - right * 6.0 - flat * 1.0, C + Vector3.UP * 0.05)
	await _frames(4)
	await _snap("lightning_hit")
	await _clear(120)


## (c) the element's signature zone at C.
func _zone_shot(el: String) -> void:
	var facing := -flat
	match el:
		"fire":
			var by := _dummy(C - flat * 3.0)
			BendZone.make(by, "fire_wall", C, {"width_m": 4.0, "height_m": 2.0, "thick_m": 0.6, "life_s": 30.0}, facing)
			BendZone.make(by, "burn", C + right * 3.6 - flat * 1.5, {"width_m": 1.4, "height_m": 0.4, "thick_m": 4.0, "life_s": 30.0}, right)
			await _frames(45)
		"water":
			var by := _dummy(C - flat * 3.0)
			BendZone.make(by, "water_wall", C - right * 1.9, {"width_m": 3.6, "height_m": 2.4, "thick_m": 0.8, "life_s": 30.0}, facing)
			var o := _dummy(C + right * 2.6)
			BendZone.make(o, "bubble", o.global_position, {"radius_m": 1.6, "life_s": 30.0}, facing)
			await _frames(40)
		"ice":
			var by := _dummy(C - flat * 3.0)
			var x := Vector3.UP.cross(facing).normalized()
			var xf := Transform3D(Basis(x, Vector3.UP, facing), C)
			var w := BendEffects._wall(by, xf, "snow")
			w.set_meta(&"bend_ice", true)
			BendLooks.burst(C + Vector3.UP, "ice", 24)
			_rise(C, w.size, facing, "ice")
			await _frames(80)
			w.crumble("shattered")
			BendLooks.burst(C + Vector3.UP, "ice", 30)
			var bl = BendLooks.new()
			if bl.has_method(&"shatter"):
				bl.call(&"shatter", C, w.size, facing, "ice")
			await _frames(10)
		"air":
			var o := _dummy(C - right * 2.2)
			BendZone.make(o, "air_shield", o.global_position, {"radius_m": 1.8, "life_s": 30.0}, facing)
			var by := _dummy(C - flat * 3.0)
			BendZone.make(by, "tornado", C + right * 2.4, {"radius_m": 1.6, "life_s": 30.0, "mps": 0.0}, facing)
			await _frames(60)
		"stone":
			var by := _dummy(C - flat * 3.0)
			var x := Vector3.UP.cross(facing).normalized()
			var w := BendEffects._wall(by, Transform3D(Basis(x, Vector3.UP, facing), C), "earth")
			BendLooks.burst(C, "stone", 30, Vector3.UP, 80.0, 3.0)
			_rise(C, w.size, facing, "earth")
			await _frames(20)
		"lightning":
			BendLooks.lightning(C + Vector3.UP * 14.0 + right * 0.5, C + Vector3.UP * 0.05)
			await _frames(2)
	await _snap("%s_zone" % el)
	await _clear()


## The wall-rise dust and cracks (BendLooks.rise) where this build has them (the old looks had none).
func _rise(at: Vector3, size: Vector3, way: Vector3, matter: String) -> void:
	var bl = BendLooks.new()
	if bl.has_method(&"rise"):
		bl.call(&"rise", at, size, way, matter)
