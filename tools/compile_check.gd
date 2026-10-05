extends SceneTree
## THE COMPILE CHECK (the wave gates of the Tidebreak build; plan T6): every GDScript under scripts/ and tools/, and the
## bending, ring, sway, npc and ui tests, loaded and asked whether it can be made (Script.can_instantiate; an abstract base
## counts as whole), and the ring's scene too once it exists. `--import` compiles only what scenes/main.tscn reaches, not
## the scripts loaded by path, the tools or the tests, and a parse error in one file fails every level test after it (the
## plan's rule: fixing it comes first).
##
##   Godot --headless --path . -s tools/compile_check.gd [-- dirs=res://scripts/ring,res://tests/ring]
##
## Prints "BAD <path>" for each script that does not compile (the engine's own parse error above it) and ends with
## "COMPILE CHECK <n> ok <m> bad"; exits 1 when any is bad, 0 when none.
##   const CompileCheck := preload("res://tools/compile_check.gd")
##   CompileCheck.check("user://broken.gd", true)      # false: it does not compile (quiet: its parse error not printed)

const DIRS := ["res://scripts", "res://scenes", "res://tools", "res://tests/bending", "res://tests/ring", "res://tests/sway",
		"res://tests/npc", "res://tests/ui"]
## Scenes made from their scripts: each is checked when it exists (the ring's is being built in the same wave).
const SCENES := ["res://scenes/main.tscn", "res://scenes/main_menu.tscn", "res://scenes/ring.tscn"]


## Whether the script at `path` compiles: it loads, and it can be made (or is an abstract base). `quiet` keeps the engine's
## parse errors out of the log (a test's deliberate break) and the script out of the resource cache.
static func check(path: String, quiet := false) -> bool:
	var was := Engine.print_error_messages
	if quiet:
		Engine.print_error_messages = false
	var mode := ResourceLoader.CACHE_MODE_IGNORE if quiet else ResourceLoader.CACHE_MODE_REUSE
	var s := ResourceLoader.load(path, "", mode) as Script
	var ok := s != null and (s.can_instantiate() or (s.has_method(&"is_abstract") and bool(s.call(&"is_abstract"))))
	Engine.print_error_messages = was
	return ok


## Whether the scene at `path` loads and can be made.
static func check_scene(path: String) -> bool:
	var ps := ResourceLoader.load(path) as PackedScene
	return ps != null and ps.can_instantiate()


## Every .gd under `dir`, its sub-folders too (hidden folders skipped), sorted.
static func scripts_under(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(scripts_under(dir.path_join(sub)))
	out.sort()
	return out


func _initialize() -> void:
	var dirs: Array = DIRS
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("dirs="):
			dirs = Array(a.get_slice("=", 1).split(",", false))
	var ok := 0
	var bad := 0
	var t0 := Time.get_ticks_msec()
	for dir: String in dirs:
		for path: String in scripts_under(dir):
			if check(path):
				ok += 1
			else:
				bad += 1
				print("BAD ", path)
	for path: String in SCENES:
		if not ResourceLoader.exists(path):
			continue
		if check_scene(path):
			ok += 1
		else:
			bad += 1
			print("BAD ", path)
	print("COMPILE CHECK %d ok %d bad (%d ms)" % [ok, bad, Time.get_ticks_msec() - t0])
	quit(1 if bad > 0 else 0)
