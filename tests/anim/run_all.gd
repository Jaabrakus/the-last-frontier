extends SceneTree
## Runs the animation test suites (plan section 10, WPT):
##   tests/anim/engine/ec_*.gd   engine contracts (Godot behaviours the player tree relies on)
##   tests/anim/test_*.gd        work-package suites
##
##   Godot --headless --path . -s tests/anim/run_all.gd -- --no-capture [options]
##   (add --fixed-fps 120 before --path to run level suites faster than real time, with exactly
##    one process frame per physics tick)
##
## Options (after --):
##   --only=<glob>[,<glob>]   run suites whose name (e.g. ec_oneshot_loop, test_rig) or path matches
##   --list                   list the discovered suites with their describe() line and exit
##   --selftest               run the runner's own dummy suites (tests/anim/lib/selftest/st_*.gd)
##   --dir=<res://dir> --prefix=<p>   discover <dir>/<p>*.gd instead
##   --json=<path>            also write a machine-readable report
##   --timeout-scale=<k>      multiply every suite's timeout_s()
##   --quiet                  print only failures and the summary
##   Suites may read further `name=value` arguments through ctx.arg().
##
## Each suite extends AnimTestSuite (tests/anim/lib/anim_test_suite.gd) and implements
## run(ctx: AnimTestContext). A suite FAILs on a failed check, ERRORs when its script does not
## load or a GDScript / engine error is logged while it runs or while its fixtures are torn down
## (unless ctx.allow_error() matches; teardown errors are reported as "CLEANUP ..."), and
## TIMEOUTs after timeout_s() of real time. A timed-out suite is abandoned: its next wait through
## the context (ctx.frames / idle_frames / seconds, FootSlip with {"ctx": ctx}) never returns
## and the parked coroutine is dropped after its cleanup, so it cannot make checks, log errors
## or drive input during later suites. SKIP and PASS do not fail the run.
##
## Exit code: 0 when every suite passed or skipped, 1 otherwise, 2 when no suite matched.

const SETS := [["res://tests/anim/engine", "ec_"], ["res://tests/anim", "test_"]]
const SELFTEST := ["res://tests/anim/lib/selftest", "st_"]


## Collects errors logged while a suite runs (Godot 4.5+ Logger; called from any thread).
class ErrorLog extends Logger:
	var _mutex := Mutex.new()
	var _entries: Array = []
	var _on := false

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		if _on:
			var text := rationale if rationale != "" else code
			_entries.append({"type": ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)],
					"text": text, "where": "%s:%d %s()" % [file.get_file(), line, function]})
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func begin() -> void:
		_mutex.lock()
		_entries.clear()
		_on = true
		_mutex.unlock()

	func end() -> Array:
		_mutex.lock()
		_on = false
		var out := _entries.duplicate()
		_entries.clear()
		_mutex.unlock()
		return out


var _args := {}
var _log := ErrorLog.new()
## Contexts of timed-out suites; their parked coroutines are dropped again before quitting.
var _abandoned: Array[AnimTestContext] = []


func _initialize() -> void:
	_args = _parse_args()
	OS.add_logger(_log)
	var paths := _discover()
	if _args.has("list"):
		for p in paths:
			print("%-34s %s" % [_suite_name(p), _describe(p)])
		quit(0)
		return
	if paths.is_empty():
		printerr("run_all: no suite matched (only=%s)" % _args.get("only", "*"))
		print("ANIM TESTS: NO SUITES")
		quit(2)
		return
	# The root window enters the tree only after _initialize() starts; fixtures need it inside.
	await process_frame
	await process_frame
	var fast := await AnimTestContext.faster_than_realtime(self)
	print("run_all: %d suite(s), Godot %s, physics %d Hz, %s" % [paths.size(), Engine.get_version_info().string,
			Engine.physics_ticks_per_second, "fixed-step (faster than real time)" if fast else "real time"])
	var results := []
	for p in paths:
		results.append(await _run_suite(p))
	var code := _summary(results)
	if _args.has("json"):
		_write_json(String(_args.json), results)
	for ctx in _abandoned:
		ctx.release_parked()
	OS.remove_logger(_log)
	quit(code)


func _run_suite(path: String) -> Dictionary:
	var name := _suite_name(path)
	var res := {"name": name, "path": path, "status": "PASS", "checks": 0, "failed": 0, "failures": [],
			"errors": [], "warnings": [], "notes": [], "metrics": {}, "skip_reason": "", "ms": 0}
	print("\n== %s" % name)
	var t0 := Time.get_ticks_msec()
	_log.begin()
	var scr: Script = load(path) as Script
	var suite: Object = null
	if scr and scr.can_instantiate():
		suite = scr.new()
	if suite == null or not suite.has_method("run"):
		res.errors = _log.end()
		res.status = "ERROR"
		res.failures.append("suite script did not load or has no run(ctx)")
		print("  ERROR %s did not load or has no run(ctx)" % path)
		for e in res.errors:
			print("  ERROR [%s] %s  (%s)" % [e.type, e.text, e.where])
		res.ms = Time.get_ticks_msec() - t0
		return res
	var ctx := AnimTestContext.new(self, name, path, _args)
	var timeout := 120.0
	if suite.has_method("timeout_s"):
		timeout = float(suite.timeout_s())
	timeout *= float(_args.get("timeout-scale", 1.0))
	var state := {"done": false}
	_drive(suite, ctx, state)
	var timed_out := false
	while not state.done:
		if Time.get_ticks_msec() - t0 > timeout * 1000.0:
			timed_out = true
			break
		await process_frame
	if timed_out:
		# The suite's next wait through ctx parks its coroutine for good (see the header).
		ctx.abandon()
		_abandoned.append(ctx)
	var errors := _log.end()
	# Teardown (fixture frees, level unload, input release) gets its own window, so an error
	# logged while this suite's nodes go away is charged to this suite, marked "cleanup".
	_log.begin()
	await ctx.cleanup()
	for e in _log.end():
		e.type = "CLEANUP " + e.type
		errors.append(e)
	if timed_out:
		ctx.release_parked()
	var real_errors := []
	for e in errors:
		var allowed := false
		for s in ctx.allowed_errors:
			if s in e.text:
				allowed = true
		if not allowed:
			real_errors.append(e)
	res.checks = ctx.checks
	res.failures = Array(ctx.failures)
	res.failed = ctx.failures.size()
	res.errors = real_errors
	res.warnings = Array(ctx.warnings)
	res.notes = Array(ctx.notes)
	res.metrics = ctx.metrics
	res.skip_reason = ctx.skip_reason
	if timed_out:
		res.status = "TIMEOUT"
		print("  TIMEOUT after %.0f s (timeout_s %.0f)" % [(Time.get_ticks_msec() - t0) / 1000.0, timeout])
	elif not real_errors.is_empty():
		res.status = "ERROR"
	elif res.failed > 0:
		res.status = "FAIL"
	elif ctx.skipped:
		res.status = "SKIP"
	elif res.checks == 0:
		res.status = "FAIL"
		res.failures.append("suite made no checks")
		print("  FAIL suite made no checks")
	for e in real_errors:
		print("  ERROR [%s] %s  (%s)" % [e.type, e.text, e.where])
	res.ms = Time.get_ticks_msec() - t0
	return res


func _drive(suite: Object, ctx: AnimTestContext, state: Dictionary) -> void:
	await suite.run(ctx)
	state.done = true


func _summary(results: Array) -> int:
	var counts := {"PASS": 0, "FAIL": 0, "ERROR": 0, "TIMEOUT": 0, "SKIP": 0}
	print("\n== tests/anim summary")
	print("  %-34s %-8s %6s %6s %8s" % ["suite", "status", "checks", "failed", "ms"])
	for r in results:
		counts[r.status] += 1
		print("  %-34s %-8s %6d %6d %8d" % [r.name, r.status, r.checks, r.failed, r.ms])
	var bad: int = counts.FAIL + counts.ERROR + counts.TIMEOUT
	for r in results:
		if r.status in ["FAIL", "ERROR", "TIMEOUT"]:
			print("  -- %s %s" % [r.name, r.status])
			for f in r.failures:
				print("       fail: " + f)
			for e in r.errors:
				print("       %s: %s (%s)" % [e.type.to_lower(), e.text, e.where])
		elif r.status == "SKIP":
			print("  -- %s SKIP: %s" % [r.name, r.skip_reason])
	print("  %d suites: %d passed, %d failed, %d errors, %d timeouts, %d skipped" % [results.size(), counts.PASS,
			counts.FAIL, counts.ERROR, counts.TIMEOUT, counts.SKIP])
	print("ANIM TESTS PASSED" if bad == 0 else "ANIM TESTS FAILED")
	return 0 if bad == 0 else 1


func _discover() -> PackedStringArray:
	var sets: Array = SETS
	if _args.has("selftest"):
		sets = [SELFTEST]
	elif _args.has("dir"):
		sets = [[String(_args.dir).trim_suffix("/"), String(_args.get("prefix", "test_"))]]
	var out := PackedStringArray()
	for s: Array in sets:
		var files := Array(DirAccess.get_files_at(s[0]))
		files.sort()
		for f: String in files:
			if f.begins_with(s[1]) and f.ends_with(".gd"):
				var p: String = s[0] + "/" + f
				if _matches(p):
					out.append(p)
	return out


func _matches(path: String) -> bool:
	if not _args.has("only"):
		return true
	var name := _suite_name(path)
	for g in String(_args.only).split(",", false):
		if name.matchn(g) or path.matchn(g) or name.get_file().matchn(g) or path.matchn("*" + g + "*.gd"):
			return true
	return false


func _suite_name(path: String) -> String:
	return path.trim_prefix("res://tests/anim/").trim_suffix(".gd")


## The suite's describe() line for --list ("(does not load)" when the script fails to load).
func _describe(path: String) -> String:
	var scr: Script = load(path) as Script
	if scr == null or not scr.can_instantiate():
		return "(does not load)"
	var suite: Object = scr.new()
	return String(suite.describe()) if suite.has_method("describe") else ""


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if "=" in s:
			out[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
		else:
			out[s] = true
	return out


func _write_json(path: String, results: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("run_all: cannot write " + path)
		return
	f.store_string(JSON.stringify({"godot": Engine.get_version_info().string, "suites": results}, " ", false))
	f.close()
	print("run_all: wrote " + path)
