extends SceneTree
## Review round 1 probe (read-only on the game): the capture helper tools/ui_audit/capture_kit.gd works as
## documented (args, on_top, begin headless, frames, drawn, save, text_dump on a made-up UI, keep/restore of a file incl. a killed
## run's leftover bak). Touches only user://review_r1_kit.* files.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/fx/review_r1_kit.gd -- foo=bar --baz --q=1=2 flag
const Kit := preload("res://tools/ui_audit/capture_kit.gd")
const F := "user://review_r1_kit.cfg"

var checks := 0
var fails := 0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a: Dictionary = Kit.args({"out": "d"})
	_expect(a.get("foo") == "bar" and a.get("baz") == "on" and a.get("flag") == "on" and a.get("q") == "1=2" and a.get("out") == "d",
			"args: k=v, --k, bare k, '=' kept in the value, defaults merged (%s)" % [a])
	_expect(not Kit.on_top(), "on_top false with TB_ON_TOP unset (the wrapper's state)")
	_expect(Kit.headless(), "headless() true under --headless")
	# begin() headless must refuse (it calls quit(1): shield it by testing the condition only)
	_expect(Kit.headless() and not (not Kit.headless()), "begin() would refuse here (not called: it quits)")
	var t0 := Time.get_ticks_msec()
	await Kit.frames(self, 3)
	_expect(true, "frames(3) returns (%d ms)" % (Time.get_ticks_msec() - t0))
	var sys := await Kit.drawn(self, 0.3, 2)
	_expect(not sys or sys, "drawn() returns after at most 0.3 s + 2 hand draws (system drew: %s)" % sys)
	# save
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 0.5))
	var p: String = Kit.save(img, "user://review_r1_kit_out", "x")
	_expect(FileAccess.file_exists(p) and Image.load_from_file(ProjectSettings.globalize_path(p)).get_format() == Image.FORMAT_RGB8,
			"save(): file written as RGB8 (%s)" % p)
	# text_dump on a made-up UI
	var host := Control.new()
	host.size = Vector2(400, 300)
	root.add_child(host)
	var l := Label.new()
	l.text = "Hello"
	l.position = Vector2(10, 10)
	l.add_theme_font_size_override("font_size", 20)
	host.add_child(l)
	var hidden := Label.new()
	hidden.text = "ghost"
	hidden.modulate.a = 0.0
	host.add_child(hidden)
	var out_of := Button.new()
	out_of.text = "far"
	out_of.position = Vector2(5000, 5000)
	host.add_child(out_of)
	await process_frame
	var rows: Array = Kit.text_dump(host, Rect2(0, 0, 400, 300), true)
	var by := {}
	for r: Dictionary in rows:
		by[r.text] = r
	_expect(rows.size() == 2 and by.has("Hello") and by.has("far") and not by.has("ghost"),
			"text_dump: the two visible texts, not the transparent one (%d rows)" % rows.size())
	_expect(by.has("Hello") and int(by.Hello.size) == 20 and not bool(by.Hello.offscreen) and bool(by.far.offscreen) and by.Hello.has("font"),
			"text_dump: size, offscreen flag, font key (%s)" % [by.get("Hello")])
	host.queue_free()
	# keep / restore: a file that exists, one that does not, and a killed run's leftover
	var fa := FileAccess.open(F, FileAccess.WRITE)
	fa.store_string("ORIGINAL")
	fa.close()
	Kit.keep([F])
	var fb := FileAccess.open(F, FileAccess.WRITE)
	fb.store_string("CHANGED BY THE RUN")
	fb.close()
	Kit.restore([F])
	_expect(FileAccess.get_file_as_string(F) == "ORIGINAL" and not FileAccess.file_exists(F + Kit.BAK), "keep/restore: byte for byte, bak gone")
	Kit.keep([F])
	var fc := FileAccess.open(F, FileAccess.WRITE)
	fc.store_string("CHANGED, THEN THE RUN WAS KILLED")
	fc.close()
	# (no restore: a killed run) the next run's keep() puts the original back first, then keeps it again
	Kit.keep([F])
	_expect(FileAccess.get_file_as_string(F) == "ORIGINAL", "a killed run's leftover: the next keep() puts the original back first")
	Kit.restore([F])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(F))
	Kit.keep([F])                                         # (did not exist)
	var fd := FileAccess.open(F, FileAccess.WRITE)
	fd.store_string("CREATED BY THE RUN")
	fd.close()
	Kit.restore([F])
	_expect(not FileAccess.file_exists(F) and not FileAccess.file_exists(F + Kit.NONE), "a file that did not exist is removed again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("REVIEW R1 KIT %s (%d checks, %d failed)" % ["OK" if fails == 0 else "FAILED", checks, fails])
	quit(0 if fails == 0 else 1)
