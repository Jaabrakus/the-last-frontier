extends SceneTree
## The web build's animation libraries, compressed IN PLACE (Animation.compress: about a third of the size). Run only on
## the web snapshot (tools/web/prep_snapshot.sh), never the working project: it saves over the libraries.
##   WEB_SNAPSHOT=1 Godot --headless --path <snapshot> -s res://tools/web/compress_anims.gd
## Each clip is CHECKED right after it is compressed (tools/web/anim_error.gd: the compressed copy sampled against the original
## every 1/120 s and at its end) and replaces the original in its library only when no rotation is more than 2 degrees off, no
## position more than 10 mm and no scale more than 0.01; otherwise the original stays (marked with the metadata KEPT, so the next
## batch leaves it alone) and the log says "WEB ANIMS clip X kept uncompressed (err ...)".
## Why: compress() at its default page size (8192 bytes) left 122 of the 1,607 clips of these libraries beyond those limits (sampled
## every 1/120 s: actor_b-p-sprint-fw a knee 122 degrees off, own-bend-air-slip a wrist 170, the fire Kick 78, motifect-air-jump-spin-kick
## the root 179 for half a second, actor_b-climb-on-3m-down^run-enter-left the root 781 mm away). It happens where a clip's data runs
## over a page boundary: of 1,389 clips measured the 797 that fit one page were all right, 115 of the 592 that took several were not.
## PAGE_SIZE puts every clip of these libraries in ONE page: none of the 1,607 is off by more than 0.4 degrees or 0.1 mm, and the
## libraries come out smaller (Actor_B.res 15.9 -> 11.3 MB).
## Left as they are besides (counted in "left as they are"): clips shorter than MIN_LENGTH_S, the clips named in $SKIP_FILE (one per
## line; compress() runs away on them) and the loops in tools/web/seam_clips.txt: the player tree closes their seams at load
## (TreeBuilder.close_seam edits the clip's keys, which a compressed track can't take), so they stay as the desktop game has them.
## At most $BATCH clips (default 100) a run, then the library is saved and the run quits with 3 (more to do; 0: all done):
## Actor_B.res loaded takes most of the 2.6 GB a process gets here, and every compress() keeps a little more.
## Not Actor_B_from_A.res (the horse, the melee, the downed: compress() runs away on clip after clip of it; tools/web/pack_compress.py
## deflates it).

const AnimError := preload("anim_error.gd")

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
## compress()'s page_size (bytes): the largest compressed clip of these libraries is 410 KB, so 1 MiB holds any of them in one page (all
## 1,269 compress() calls of a build came out in one page).
## (A size in between does not do for a clip with hundreds of tracks: actor_b-death-standing-generic, 533 tracks, is refused at 8192
## ("Cannot compress with the given page size"), wrong by 13 degrees at 65536 and runs away at 16384, killed by the system as the
## clips of tools/web/anim_skip.txt are.)
const PAGE_SIZE := 1048576
## Metadata on a clip the check kept uncompressed.
const KEPT := AnimError.KEPT
## The loops the player tree closes at load, by the AnimationPlayer's library ("<library>/<clip>", as TreeIndex.loop_seams names
## them), and the file each library is.
const SEAM_CLIPS := "res://tools/web/seam_clips.txt"
const SEAM_LIBS := {
	"actor_b": "res://animations/Actor_B.res",
	"frontier_locomotion": "res://animations_extra/Frontier_Locomotion.res",
	"frontier_downgraded": "res://animations_extra/Frontier_Downgraded.res",
}


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
	var seams := _seam_clips()
	if seams.is_empty():
		push_error("compress_anims: no loop-seam clips listed in %s" % SEAM_CLIPS)
		quit(1)
		return
	for p: String in LIBS:
		if not ResourceLoader.exists(p):
			continue
		var lib := load(p) as AnimationLibrary
		var todo: Array[StringName] = []
		var left := 0
		var kept_before := 0
		for n in lib.get_animation_list():
			var a := lib.get_animation(n)
			if _compressed(a):
				continue
			if a.has_meta(KEPT):
				kept_before += 1
				continue
			if a.length < MIN_LENGTH_S or skip.has(String(n)) or (seams.get(p, {}) as Dictionary).has(String(n)):
				left += 1
				continue
			todo.append(n)
		for n: String in seams.get(p, {}):
			if not lib.has_animation(StringName(n)):
				push_warning("compress_anims: %s lists %s, not a clip of %s" % [SEAM_CLIPS, n, p])
		if todo.is_empty():
			continue
		var done := 0
		var kept := 0
		var worst_rot := 0.0
		var worst_pos := 0.0
		for n in todo.slice(0, batch):
			print("WEB ANIMS clip %s" % n)
			var a := lib.get_animation(n)
			var res := _compress_checked(a)
			if res.anim != null:
				lib.remove_animation(n)
				lib.add_animation(n, res.anim)
				done += 1
				worst_rot = maxf(worst_rot, float(res.err.rot))
				worst_pos = maxf(worst_pos, float(res.err.pos_mm))
			else:
				a.set_meta(KEPT, true)
				kept += 1
				print("WEB ANIMS clip %s kept uncompressed (err %s)" % [n, res.text])
		var err := ResourceSaver.save(lib, p, ResourceSaver.FLAG_COMPRESS)
		print("WEB ANIMS %s: %d compressed (worst %.2f deg, %.2f mm), %d kept uncompressed (%d earlier), %d to go, %d left as they are, saved %s" % [
				p, done, worst_rot, worst_pos, kept, kept_before, todo.size() - mini(batch, todo.size()), left, error_string(err)])
		quit(1 if err != OK else MORE)
		return
	print("WEB ANIMS all done")
	quit(0)


## `a` compressed as a copy and checked against `a`: {anim (the copy when it passes the check, else null), err (its
## AnimError.measure), text (what is wrong with it, for the log)}.
static func _compress_checked(a: Animation) -> Dictionary:
	var c := a.duplicate(true) as Animation
	c.compress(PAGE_SIZE)
	if not _compressed(c):
		return {"anim": null, "err": {}, "text": "compress() refused it"}
	var err := AnimError.measure(a, c)
	if AnimError.beyond(err):
		return {"anim": null, "err": err, "text": AnimError.describe(err)}
	return {"anim": c, "err": err, "text": ""}


## The loops the player tree closes at load: {library path: {clip: true}} from tools/web/seam_clips.txt.
static func _seam_clips() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(SEAM_CLIPS):
		return out
	for line in FileAccess.get_file_as_string(SEAM_CLIPS).split("\n", false):
		var s := line.strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		var lib_name := s.get_slice("/", 0)
		if not SEAM_LIBS.has(lib_name):
			push_error("compress_anims: %s: no library file known for '%s' (SEAM_LIBS)" % [SEAM_CLIPS, s])
			return {}
		var path: String = SEAM_LIBS[lib_name]
		if not out.has(path):
			out[path] = {}
		out[path][s.trim_prefix(lib_name + "/")] = true
	return out


static func _compressed(a: Animation) -> bool:
	for t in a.get_track_count():
		if a.track_is_compressed(t):
			return true
	return false
