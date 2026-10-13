extends SceneTree
## The web build's animation libraries, compressed IN PLACE (Animation.compress: about a quarter of the size). Run only on
## the web snapshot (tools/web/prep_snapshot.sh), never the working project: it saves over the libraries, and compressed
## tracks can't be edited (TreeBuilder.close_seam leaves those loops as they are).
##   WEB_SNAPSHOT=1 Godot --headless --path <snapshot> -s res://tools/web/compress_anims.gd
## At most $BATCH clips (default 100) a run, then the library is saved and the run quits with 3 (more to do; 0: all done):
## Actor_B.res loaded takes most of the 2.6 GB a process gets here, and every compress() keeps a little more.
## Zero-length clips are left as they are, and so are the clips named in $SKIP_FILE (one per line). Not Actor_B_from_A.res
## (the horse, the melee, the downed: compress() runs away on clip after clip of it; tools/web/pack_compress.py deflates it).

const LIBS := [
	"res://animations/Actor_B.res", "res://animations_extra/Actor_B_from_C.res",
	"res://animations_extra/Frontier_Bend.res", "res://animations_extra/Frontier_Bend_Aim.res",
	"res://animations_extra/Frontier_Downgraded.res", "res://animations_extra/Frontier_Forage.res",
	"res://animations_extra/Frontier_Form.res", "res://animations_extra/Frontier_Locomotion.res",
	"res://animations_extra/Frontier_Motifect.res", "res://animations_extra/Frontier_Own.res",
	"res://animations_extra/Frontier_Style_Boxing.res", "res://animations_extra/Frontier_Style_Capoeira.res",
	"res://animations_extra/Frontier_Traversal.res",
]
const MIN_LENGTH_S := 0.05
const MORE := 3


func _initialize() -> void:
	if OS.get_environment("WEB_SNAPSHOT") != "1":
		push_error("compress_anims: run on the web snapshot only (WEB_SNAPSHOT=1)")
		quit(1)
		return
	var batch := int(OS.get_environment("BATCH")) if OS.get_environment("BATCH") != "" else 100
	var skip := {}
	var sf := OS.get_environment("SKIP_FILE")
	if sf != "" and FileAccess.file_exists(sf):
		for line in FileAccess.get_file_as_string(sf).split("\n", false):
			skip[line.strip_edges()] = true
	for p: String in LIBS:
		if not ResourceLoader.exists(p):
			continue
		var lib := load(p) as AnimationLibrary
		var todo: Array[StringName] = []
		var left := 0
		for n in lib.get_animation_list():
			var a := lib.get_animation(n)
			if _compressed(a):
				continue
			if a.length < MIN_LENGTH_S or skip.has(String(n)):
				left += 1
				continue
			todo.append(n)
		if todo.is_empty():
			continue
		var done := 0
		for n in todo.slice(0, batch):
			print("WEB ANIMS clip %s" % n)
			var a := lib.get_animation(n)
			a.compress()
			if not _compressed(a):
				a.compress(65536)             # (a clip too big for the default page)
			done += int(_compressed(a))
		var err := ResourceSaver.save(lib, p, ResourceSaver.FLAG_COMPRESS)
		print("WEB ANIMS %s: %d compressed, %d to go, %d left as they are, saved %s" % [p, done, todo.size() - mini(batch, todo.size()), left, error_string(err)])
		quit(1 if err != OK else MORE)
		return
	print("WEB ANIMS all done")
	quit(0)


static func _compressed(a: Animation) -> bool:
	for t in a.get_track_count():
		if a.track_is_compressed(t):
			return true
	return false
