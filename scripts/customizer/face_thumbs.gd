extends SubViewport
## Portraits of the Face row's faces for the character creator's Face picker (CharacterCreator._open_picker; the picker
## showed only the words "Face 1 .. Face 10"): a second CreatorStage in this small viewport of its own, dressed with the
## look (its skin, hair, brows, jewellery and clothes) and each face in turn on its "portrait" framing, the figure
## centred and not blinking. Each face is drawn once and kept as an ImageTexture (by the look without its face, and the
## face: the picker opened again on the same look shows them at once); the viewport draws only while it makes them.
## Without a renderer (a headless run) there are no portraits: the picker keeps its words. (No class_name: a new global
## class waits for the editor's class cache, which script runs do not refresh; preload it.)
##
##   const FaceThumbs := preload("res://scripts/customizer/face_thumbs.gd")
##   var thumbs := FaceThumbs.new()
##   parent.add_child(thumbs)
##   thumbs.render(look, opts, func(i: int, tex: Texture2D) -> void: ...)   # async; a later render() stops it

const SIZE := Vector2i(96, 116)
## The look keys that are the face (the rest is the same for every portrait of one picker).
const FACE_KEYS := ["face", "face_variant", "preset", CreatorOptions.OWN_FACE]

var stage: CreatorStage
var _cache := {}
## The render() in progress (a newer one stops an older one between faces).
var _run := 0


static func available() -> bool:
	return DisplayServer.get_name() != "headless"


func _init() -> void:
	name = "FaceThumbs"
	size = SIZE
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	stage = CreatorStage.new()
	stage.side_shift = 0.0
	add_child(stage)
	stage.frame("portrait")
	stage._snap_camera()
	var blink := stage.find_child("FaceBlink", true, false) as FaceBlink
	if blink:
		blink.process_mode = Node.PROCESS_MODE_DISABLED
	# (idle between renders: the figure's idle and the camera wait too)
	stage.process_mode = Node.PROCESS_MODE_DISABLED


## The portrait of each of `opts` (the Face row's choices) on `look`: `done` is called with (index, texture) as each is
## ready (at once for those made before). Stops when render() is called again or the viewport leaves the tree.
func render(look: Dictionary, opts: Array, done: Callable) -> void:
	_run += 1
	var run := _run
	if not available():
		return
	var base := look.duplicate(true)
	for k: String in FACE_KEYS:
		base.erase(k)
	var key0 := JSON.stringify(base)
	stage.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in opts.size():
		var key := key0 + JSON.stringify((opts[i] as Dictionary).get("face", {}))
		if not _cache.has(key):
			var lk := base.duplicate(true)
			lk["face"] = ((opts[i] as Dictionary).get("face", {}) as Dictionary).duplicate()
			stage.show_look(lk)
			var blink := stage.find_child("FaceBlink", true, false) as FaceBlink
			if blink and blink.body:
				blink.set_blink(0.0)
			render_target_update_mode = SubViewport.UPDATE_ALWAYS
			# (the frame that draws the new face; a second one for the camera on the head after the first dress)
			for f in (3 if _cache.is_empty() else 1):
				await RenderingServer.frame_post_draw
			if run != _run or not is_inside_tree():
				return
			var img := get_texture().get_image()
			if img == null or img.is_empty():
				break
			_cache[key] = ImageTexture.create_from_image(img)
		if not done.is_valid():
			break
		done.call(i, _cache[key])
	if run == _run:
		render_target_update_mode = SubViewport.UPDATE_DISABLED
		stage.process_mode = Node.PROCESS_MODE_DISABLED
