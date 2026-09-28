extends SceneTree
## Cross-checks tools/weapons/range_sim.py (the Python range calculator) against the game:
##   1. the live property values of every weapon class (Musket.new(), Bow.new(), ...) equal the
##      values the calculator read from the scripts (data/weapons/range_research.json
##      "game_params"), and the quick-throw speed matches Throwable.throw_speed();
##   2. the calculator's port of Weapon.ballistic_dir gives the same elevation as the real
##      static function for every "crosscheck" case (to 0.5 mrad).
## A failure in (1) usually means a weapon script changed after the JSON was written: re-run
##   python3 tools/weapons/range_sim.py --write
##
##   Godot --headless --path . -s tests/weapons/range_crosscheck.gd
## Prints RANGE CROSSCHECK PASSED or FAILED (exit code 1). Needs no scene and no player.

const DATA := "res://data/weapons/range_research.json"
const CLASSES := {
	"tomahawk": "ThrowableTomahawk", "spear": "ThrowableSpear", "atlatl": "ThrowableAtlatl",
	"bow": "Bow", "pistol": "FlintlockPistol", "musket": "Musket",
}
## Properties compared between the script instance and the JSON.
const PROPS := [
	"muzzle_speed", "ball_gravity", "ball_drag", "damage", "spread_base", "spread_move", "spread_air",
	"crouch_mult", "aim_mult", "spread_unaimed", "min_arrow_speed", "max_arrow_speed", "arrow_gravity",
	"min_damage", "max_damage", "min_draw", "draw_time", "spread_undercharge", "min_speed", "max_speed",
	"flight_gravity", "flight_drag", "windup_time", "min_windup",
]

var fails := 0
var checks := 0


func _initialize() -> void:
	var text := FileAccess.get_file_as_string(DATA)
	var doc = JSON.parse_string(text) if text != "" else null
	if typeof(doc) != TYPE_DICTIONARY:
		_expect(false, "read %s (run tools/weapons/range_sim.py --write first)" % DATA)
		_finish()
		return
	_expect(int(doc.get("physics_ticks_per_second", 0)) == Engine.physics_ticks_per_second,
			"physics rate %d matches the JSON" % Engine.physics_ticks_per_second)
	_check_params(doc)
	_check_ballistic_dir(doc)
	_finish()


func _finish() -> void:
	print("RANGE CROSSCHECK %s (%d checks)" % ["PASSED" if fails == 0 else "FAILED (%d)" % fails, checks])
	quit(0 if fails == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL " + msg)


func _make(cls: String) -> Object:
	match cls:
		"ThrowableTomahawk": return ThrowableTomahawk.new()
		"ThrowableSpear": return ThrowableSpear.new()
		"ThrowableAtlatl": return ThrowableAtlatl.new()
		"Bow": return Bow.new()
		"FlintlockPistol": return FlintlockPistol.new()
		"Musket": return Musket.new()
	return null


func _check_params(doc: Dictionary) -> void:
	var params: Dictionary = doc.get("game_params", {})
	var current: Dictionary = doc.get("game_current", {})
	for key in CLASSES:
		if not params.has(key):
			_expect(false, "%s missing from game_params" % key)
			continue
		var w := _make(CLASSES[key])
		var vals: Dictionary = params[key].values
		var n := 0
		for p in PROPS:
			if not vals.has(p) or not (p in w):
				continue
			var live := float(w.get(p))
			n += 1
			_expect(absf(live - float(vals[p])) < 1e-4, "%s.%s: script %s, JSON %s" % [key, p, live, vals[p]])
		_expect(n >= 5, "%s: compared %d properties" % [key, n])
		if w is Throwable and current.has(key):
			var quick := (w as Throwable).throw_speed()
			var want := float(current[key].launch.quick_mps)
			_expect(absf(quick - want) < 0.01, "%s quick throw speed: game %.3f, JSON %.3f" % [key, quick, want])
		print("  ok   %s: %d properties%s" % [key, n, " + quick speed" if w is Throwable else ""])
		if w is Node:
			(w as Node).free()


func _check_ballistic_dir(doc: Dictionary) -> void:
	var cases: Array = doc.get("crosscheck", [])
	_expect(cases.size() > 0, "crosscheck cases present")
	# Hook H3 (weapons_balance_design.md 3.3) changes the out-of-reach answers: compare with the
	# port of whichever version weapon.gd has ("theta_h3_rad" once it calls fallback_elevation).
	var src := FileAccess.get_file_as_string("res://scripts/weapons/weapon.gd")
	var h3 := src.contains("BallisticsUtil.fallback_elevation")
	_expect(not src.contains("BallisticsUtil.max_carry_elevation"),
			"weapon.gd does not carry the first H3 draft (it lobbed shots aimed steeply down; use fallback_elevation)")
	var field := "theta_h3_rad" if h3 else "theta_rad"
	print("  ..   Weapon.ballistic_dir %s hook H3: comparing with %s" % ["has" if h3 else "does not have", field])
	var worst := 0.0
	for c in cases:
		if not c.has(field):
			_expect(false, "crosscheck case has %s (run python3 tools/weapons/range_sim.py --write)" % field)
			break
		var target := Vector3(float(c.dist), float(c.dy), 0.0)
		var dir := Weapon.ballistic_dir(Vector3.ZERO, target, float(c.speed), float(c.gravity), float(c.drag))
		var theta := atan2(dir.y, Vector2(dir.x, dir.z).length())
		var err := absf(theta - float(c[field]))
		worst = maxf(worst, err)
		_expect(err < 5e-4, "%s at %.0f m (dy %.1f): game %.6f rad, python %.6f rad" % [c.weapon, c.dist, c.dy, theta, c[field]])
	print("  ok   ballistic_dir: %d cases, worst difference %.7f rad" % [cases.size(), worst])
