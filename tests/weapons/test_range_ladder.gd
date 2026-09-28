extends SceneTree
## Range ladder test: the balanced weapons flown through the game's own launch and flight code
## (Player_Animation_Project/graph_analysis/weapons/weapons_balance_design.md, sections 1.2,
## 1.4, 1.6, 1.7, 1.9 and 4.2-4.5). No level and no player rig: a flat physics world, a stub
## FrontierPlayer (its _ready / _physics_process do nothing; get_aim_point() returns a set
## point) holding a muzzle marker, and each weapon instance balanced with WeaponBalance.apply.
##
##   balance      ballistics.json applies in strict mode and round-trips, twice gives the same
##                state, aliases and the class check work, a missing file leaves the script
##                defaults, the realistic preset, upgrade blocks gated on their properties
##   cones        the settled standing and best-stance cones from Weapon.target_spread(); the
##                firearm snap and held cones through the real trigger path (Input + tick)
##   max carry    a fan of real Projectile / ThrownProjectile flights (0-70 deg in 0.25 deg
##                steps, from 1.4 m onto flat ground): strict ladder order, +-2 % of expect
##   hit rates    N real shots per distance through each weapon's own launch (the zeroed
##                Weapon.ballistic_dir, Weapon.apply_spread with seed 1750) at a 0.5 m disc:
##                expect.p_hit_disc within 3 sigma + 0.02, the snap cone at 20 and 50 m, the
##                measured D50s in strict ladder order (common random numbers across weapons),
##                and the tomahawk's blade-hit share (design 1.7)
##   zero         one spread-free full-power shot per weapon at 0.5 x and 1 x its effective
##                range and 0.9 x its flat reach lands on the aim point; its damage through
##                Hit.deliver brackets the one-shot distance
##   out of reach BallisticsUtil.zeroed_dir (hook H3) lands at >= 97 % of the max carry, and a
##                shot aimed steeply down (1.2-4 m out, 7.5-40 m below) lands on its point;
##                Weapon.ballistic_dir itself is "pending" until H3 is in weapon.gd
##   tomahawk     stick / haft sweep 2-16 m at wooden boards (the real spin_for and SPINNING
##                flight): default and realistic windows within +-0.35 m of expect, and the
##                pre-balance assist (2.5-15 m) sticking throughout for comparison
##
##   Godot --headless --fixed-fps 120 --path . -s tests/weapons/test_range_ladder.gd [-- --out=/abs/file.json]
## --fixed-fps 120 keeps the 1/120 s physics tick and runs faster than real time (20-45 s on a
## shared machine; about 80 s without it). -- --only=carry,zero,hits,windows runs those sections.
## Prints the measured table and RANGE LADDER PASSED / FAILED (exit code 1). "pending" lines are
## hooks not in yet (H3 in weapon.gd) and throws lost to the ThrownProjectile ray gap.

const DT := 1.0 / 120.0
const KEYS: Array[String] = ["tomahawk", "spear", "atlatl", "bow", "pistol", "over_under", "musket"]
const FIREARMS: Array[String] = ["pistol", "over_under", "musket"]
const HIT_DISTANCES: Array[float] = [5.0, 10.0, 20.0, 30.0, 50.0, 100.0, 200.0]
const TOMAHAWK_BLADE_DISTANCES: Array[float] = [3.0, 4.5, 6.5, 8.5, 9.5, 10.5, 12.0, 15.0]
const N := 300
const SEED := 1750
const LAUNCH_H := 1.4
const LANE := 45.0
const FAN_X := -500.0
const WINDOW_TOL := 0.35
const STUB_SRC := """extends FrontierPlayer
var aim_target := Vector3.ZERO
func _ready() -> void:
	pass
func _physics_process(_delta: float) -> void:
	pass
func _unhandled_input(_event: InputEvent) -> void:
	pass
func get_aim_point(_max_dist := 600.0) -> Vector3:
	return aim_target
"""
const BOARD_SRC := """extends StaticBody3D
var hit_log: Array = []
func apply_hit(damage, point, dir, source, part):
	hit_log.append({'damage': damage, 'point': point})
"""

var world: Node3D
var shooter: FrontierPlayer
var muzzle: Marker3D
var weapons := {}                   ## key -> balanced Weapon
var rows := {}                      ## key -> ballistics.json row
var stand_in := {}                  ## key -> true when the row's class does not exist yet
var measured := {}                  ## key -> {...} for the table and --out
var fails := PackedStringArray()
var pending := PackedStringArray()
var checks := 0
var _keep: Array[Node] = []
var _board_script: GDScript
var _lane_i := 0
## -- --only=carry,zero,hits,windows runs those sections (the balance data and cones always run).
var only := PackedStringArray()
## Thrown throws that fell through flat ground without an impact (ThrownProjectile POINT_FIRST:
## each tick's ray starts at COM + dir * reach with the new, lower dir, a few mm below where the
## last ray ended). Counted as misses and reported, not failed: the fix is the throwables owner's.
var lost_through_ground := {}


func _want(section: String) -> bool:
	return only.is_empty() or section in only


func _initialize() -> void:
	_run()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	await process_frame                  # the root enters the tree after _initialize
	InputSetup.ensure()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	await _build_world()
	print("balance data")
	_test_balance_data()
	print("helpers (BallisticsUtil, ArcCues)")
	_test_helpers()
	await _build_weapons()
	if weapons.size() != KEYS.size():
		_finish(t0)
		return
	print("cones")
	_test_cones()
	await _test_trigger_cones()
	if _want("carry"):
		print("max carry, out of reach")
		await _test_max_carry()
	if _want("zero"):
		print("zeroed shots and one-shot damage")
		await _test_zero()
	if _want("hits"):
		print("hit rates (N = %d per distance)" % N)
		await _test_hit_rates()
	if _want("windows"):
		print("tomahawk stick windows")
		await _test_tomahawk_windows()
	_print_table()
	_finish(t0)


# --- World ---------------------------------------------------------------------------------

func _build_world() -> void:
	world = Node3D.new()
	world.name = "RangeWorld"
	root.add_child(world)
	current_scene = world
	var ground := _box_body("Ground", Vector3(12000.0, 2.0, 4000.0), Vector3(5000.0, -1.0, -1500.0), "dirt")
	_keep.append(ground)
	_board_script = GDScript.new()
	_board_script.source_code = BOARD_SRC
	_board_script.reload()
	var s := GDScript.new()
	s.source_code = STUB_SRC
	if s.reload() != OK:
		_expect(false, "stub shooter script compiles")
		return
	shooter = s.new() as FrontierPlayer
	shooter.name = "Shooter"
	shooter.ignore_mouse_capture = true
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	shooter.add_child(cs)
	world.add_child(shooter)
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	world.add_child(muzzle)
	_keep.append_array([shooter, muzzle])
	_place(Vector3(0.0, LAUNCH_H, 0.0))
	await _frames(3)
	await _settle_shooter()


## Muzzle at `origin`, the shooter's feet under it, facing -Z.
func _place(origin: Vector3) -> void:
	muzzle.global_position = origin
	shooter.global_position = Vector3(origin.x, origin.y - LAUNCH_H, origin.z)
	shooter.global_basis = Basis.IDENTITY


func _aim_at(p: Vector3) -> void:
	shooter.set(&"aim_target", p)


## Puts the stub on the floor (is_on_floor() for Weapon.target_spread), standing still.
func _settle_shooter() -> void:
	for i in 3:
		await physics_frame
		shooter.velocity = Vector3(0.0, -1.0, 0.0)
		shooter.move_and_slide()
	shooter.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _box_body(label: String, size: Vector3, pos: Vector3, surface: String, logs := false) -> StaticBody3D:
	var b := StaticBody3D.new()
	if logs:
		b.set_script(_board_script)
	b.name = label
	b.set_meta(&"surface", surface)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	world.add_child(b)
	b.global_position = pos
	return b


## 0.5 m disc facing +Z (the shooter), centre at `pos`, 5 cm thick.
func _disc(pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Disc"
	b.set_meta(&"surface", "wood")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.25
	cyl.height = 0.05
	cs.shape = cyl
	cs.rotation.x = PI * 0.5
	b.add_child(cs)
	world.add_child(b)
	b.global_position = pos
	return b


## The next free lane: its launch point (x, LAUNCH_H, 0).
func _lane() -> Vector3:
	_lane_i += 1
	return Vector3(_lane_i * LANE, LAUNCH_H, 0.0)


## Frees every projectile, effect and lane body of the last batch.
func _clear() -> void:
	for n in world.find_children("*", "ThrownProjectile", true, false):
		(n as ThrownProjectile).collected = true     # no lying copy when its target goes
	for n in world.find_children("*", "Projectile", true, false):
		n.queue_free()
	for n in world.find_children("*", "ThrownProjectile", true, false):
		n.queue_free()
	for c in world.get_children():
		if c in _keep or c is Weapon or String(c.name).begins_with("Sfx") or c.name == "Weapons":
			continue
		c.queue_free()
	_lane_i = 0
	await _frames(2)


# --- Balance data (design 4.2) ------------------------------------------------------------------

func _class_script(cls: String) -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c["class"]) == cls:
			return load(String(c["path"]))
	return null


func _make(key: String) -> Weapon:
	match key:
		"tomahawk", "spear", "atlatl", "tomahawk_pipe":
			return ThrowableKit.create(key)
		"bow":
			return Bow.new()
		"pistol":
			return FlintlockPistol.new()
		"musket":
			return Musket.new()
		"over_under":
			var s := _class_script("OverUnderMusket")
			return s.new() as Weapon if s else Musket.new()
	return null


func _values_match(w: Object, values: Dictionary) -> PackedStringArray:
	var bad := PackedStringArray()
	for k: String in values:
		if not WeaponBalance.has_property(w, k):
			continue
		var live: Variant = w.get(k)
		var want: Variant = values[k]
		var ok := false
		if live is Vector2:
			ok = want is Array and (live as Vector2).is_equal_approx(Vector2(want[0], want[1]))
		elif live is float or live is int:
			ok = absf(float(live) - float(want)) < 1e-6
		else:
			ok = live == want
		if not ok:
			bad.append("%s=%s (json %s)" % [k, live, want])
	return bad


func _snapshot(w: Object) -> Dictionary:
	var out := {}
	for p: Dictionary in w.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and typeof(w.get(p.name)) in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_VECTOR2]:
			out[p.name] = w.get(p.name)
	return out


func _test_balance_data() -> void:
	WeaponBalance.reset()
	WeaponBalance.strict = true
	_expect(WeaponBalance.load_file(), "ballistics.json loads with schema %s" % WeaponBalance.SCHEMA)
	var doc := WeaponBalance.data()
	_expect(int(doc.get("physics_ticks_per_second", 0)) == Engine.physics_ticks_per_second,
			"physics rate %d matches the file" % Engine.physics_ticks_per_second)
	for key in KEYS:
		rows[key] = WeaponBalance.row(key)
		_expect(not rows[key].is_empty(), "%s has a balance row" % key)
	for key in KEYS:
		var r: Dictionary = rows[key]
		var w := _make(key)
		if key == "over_under" and not WeaponBalance.script_is(w, "OverUnderMusket"):
			stand_in[key] = true
			pending.append("over_under: OverUnderMusket (scripts/weapons/over_under.gd) not built yet; its row is flown on a Musket stand-in")
			w.free()
			continue
		var res := WeaponBalance.apply(w, key)
		_expect(res.ok and res.skipped.is_empty(), "%s: strict apply, %d properties, nothing skipped %s"
				% [key, res.applied.size(), res.skipped])
		var bad := _values_match(w, r.set)
		if WeaponBalance.preset == "":
			_expect(bad.is_empty(), "%s: every property equals the JSON %s" % [key, bad])
		for up: Dictionary in r.get("upgrades", []):
			var can := true
			for n: String in up.get("requires", []):
				can = can and WeaponBalance.has_property(w, n)
			var id := String(up.get("id"))
			_expect(can == (id in res.upgrades) and (not can) == (id in res.skipped_upgrades),
					"%s: upgrade %s %s" % [key, id, "applied (its hooks exist)" if can else "skipped until its hooks land"])
		var before := _snapshot(w)
		WeaponBalance.apply(w, key)
		_expect(before == _snapshot(w), "%s: apply twice gives the same state" % key)
		_expect(WeaponBalance.expect(w).has("max_range_m") and w.get_meta(&"balance_key") == key,
				"%s: the row key and expect block are kept on the weapon" % key)
		w.free()
	# THROW2 (user playtest 2026-09-25): the atlatl dart out-damages the spear at both ends of the
	# wind-up (70 quick / 150 full vs 60 / 130), and the atlatl's script defaults equal its JSON row
	# (the harnesses that run the throwables at script defaults then see the same damage).
	var sp_set: Dictionary = rows["spear"].set
	var at_set: Dictionary = rows["atlatl"].set
	_expect(is_equal_approx(float(at_set.min_damage), 70.0) and is_equal_approx(float(at_set.max_damage), 150.0)
			and float(at_set.min_damage) > float(sp_set.min_damage) and float(at_set.max_damage) > float(sp_set.max_damage),
			"atlatl dart damage %.0f-%.0f, above the spear's %.0f-%.0f" % [at_set.min_damage, at_set.max_damage, sp_set.min_damage, sp_set.max_damage])
	var atl_default := ThrowableAtlatl.new()
	_expect(is_equal_approx(atl_default.min_damage, float(at_set.min_damage)) and is_equal_approx(atl_default.max_damage, float(at_set.max_damage)),
			"atlatl script defaults %.0f-%.0f equal ballistics.json" % [atl_default.min_damage, atl_default.max_damage])
	atl_default.free()
	# Alias, class lookup, mismatch, unknown key.
	var pipe := _make("tomahawk_pipe")
	var pr := WeaponBalance.apply(pipe, "tomahawk_pipe")
	_expect(pr.ok and pr.key == "tomahawk" and (pipe as ThrowableTomahawk).pipe and absf((pipe as Throwable).spread_base - 3.1) < 1e-6,
			"tomahawk_pipe resolves to the tomahawk row and stays a pipe tomahawk")
	pipe.free()
	var m := Musket.new()
	_expect(WeaponBalance.apply(m).key == "musket", "an empty key finds the row by class (Musket -> musket)")
	m.free()
	var ou_script := _class_script("OverUnderMusket")
	if ou_script:
		var ou := ou_script.new() as Weapon
		var bad := _values_match(ou, rows["over_under"].set)
		_expect(bad.is_empty(), "OverUnderMusket script defaults equal its JSON row %s" % bad)
		_expect(WeaponBalance.key_for(ou) == "over_under" and WeaponBalance.script_is(ou, "Musket"),
				"OverUnderMusket extends Musket, and the class lookup finds the over_under row, not the musket's")
		ou.free()
	WeaponBalance.strict = false
	var b := Bow.new()
	var keep_speed := b.max_arrow_speed
	var mr := WeaponBalance.apply(b, "musket")
	_expect(not mr.ok and b.max_arrow_speed == keep_speed, "a row for another class is refused (bow as musket: nothing applied)")
	_expect(not WeaponBalance.apply(b, "no_such_weapon").ok, "an unknown key is a warning, not a crash")
	b.free()
	# Defaults are untouched on weapons never applied; a missing file leaves defaults.
	var fresh_a := Musket.new()
	var fresh_b := Musket.new()
	WeaponBalance.apply(fresh_a, "musket")
	var fresh_c := Musket.new()
	_expect(_snapshot(fresh_b) == _snapshot(fresh_c) and fresh_c.muzzle_speed != fresh_a.muzzle_speed,
			"a weapon never passed to apply keeps its script defaults (musket %.0f m/s, balanced %.0f)" % [fresh_c.muzzle_speed, fresh_a.muzzle_speed])
	_expect(not WeaponBalance.load_file("res://data/weapons/__missing__.json"), "a missing file does not load")
	var mr2 := WeaponBalance.apply(fresh_b, "musket")
	_expect(not mr2.ok and _snapshot(fresh_b) == _snapshot(fresh_c), "with no file apply() changes nothing (script defaults)")
	for w: Object in [fresh_a, fresh_b, fresh_c]:
		w.free()
	WeaponBalance.reset()
	# Preset.
	WeaponBalance.preset = "realistic"
	var t := _make("tomahawk") as ThrowableTomahawk
	var s := _make("spear") as Throwable
	WeaponBalance.apply(t, "tomahawk")
	WeaponBalance.apply(s, "spear")
	_expect(absf(t.spin_assist - 0.5) < 1e-6 and t.assist_range.is_equal_approx(Vector2(2.5, 10.0)) and absf(s.spread_base - 2.9) < 1e-6,
			"preset realistic: tomahawk spin_assist 0.5, the rest of its row and the other rows unchanged")
	t.free()
	s.free()
	WeaponBalance.reset()


## The pure helpers the integration hooks call (H3, H12, H15, set B falloff).
func _test_helpers() -> void:
	var near := func(a: float, b: float, eps := 1e-3) -> bool: return absf(a - b) <= eps
	_expect(near.call(BallisticsUtil.effective_range(3.1), 0.5 / tan(deg_to_rad(3.1))) and near.call(BallisticsUtil.hit_chance(20.0, 1.43), 0.25 / (20.0 * tan(deg_to_rad(1.43))))
			and BallisticsUtil.hit_chance(5.0, 1.0) == 1.0, "BallisticsUtil: cone D50 and torso-hit chance (design 1.1)")
	_expect(near.call(BallisticsUtil.falloff(300.0, 300.0), 1.0) and near.call(BallisticsUtil.falloff(60.0, 300.0), 0.35)
			and near.call(BallisticsUtil.falloff(150.0, 300.0), 0.5) and near.call(BallisticsUtil.falloff(150.0, 300.0, 0.0), 1.0),
			"BallisticsUtil.falloff: the Projectile law (clamp 0.35..1), exponent 0 = no falloff (set B arrows)")
	var el := rad_to_deg(BallisticsUtil.max_carry_elevation(14.0, 9.8, 0.03))
	var carry := BallisticsUtil.max_carry(14.0, 9.8, 0.03)
	_expect(el > 43.0 and el < 45.5 and near.call(carry, 19.2, 0.15), "BallisticsUtil: tomahawk longest carry to launch height %.2f m at %.2f deg (flat reach 19.2)" % [carry, el])
	var o := Vector3(3.0, 1.4, 2.0)
	var t := o + Vector3(4.0, 0.3, -30.0)
	_expect(BallisticsUtil.zeroed_dir(o, t, 42.0, 9.8, 0.0).is_equal_approx(Weapon.ballistic_dir(o, t, 42.0, 9.8, 0.0))
			and BallisticsUtil.in_reach(o, t, 42.0, 9.8, 0.0) and not BallisticsUtil.in_reach(o, o + Vector3(0, 0, -250), 42.0, 9.8, 0.0),
			"BallisticsUtil.zeroed_dir equals Weapon.ballistic_dir inside reach; in_reach knows the bow's 180 m")
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var bad := PackedStringArray()
	for sp: Array in [[14.0, 0.03], [20.0, 0.012], [42.0, 0.0], [200.0, 0.326], [360.0, 0.479]]:
		for c: Array in [[1.2, -7.5], [2.05, -30.0], [2.05, -60.0], [4.0, -40.0]]:
			var nd := Weapon.ballistic_dir(Vector3.ZERO, Vector3(0.0, c[1], -c[0]), sp[0], 9.8, sp[1])
			var th := BallisticsUtil.fallback_elevation(c[0], c[1], asin(clampf(nd.y, -1.0, 1.0)), sp[0], 9.8, sp[1])
			var h := Weapon._height_at(c[0], th, sp[0], 9.8, sp[1], dt)
			if is_nan(h) or absf(h - float(c[1])) > 0.05 or th > 0.0:
				bad.append("%s m/s at (%.2f, %.1f): %.1f deg, h %.2f" % [sp[0], c[0], c[1], rad_to_deg(th), h])
	var lob := rad_to_deg(BallisticsUtil.fallback_elevation(250.0, 0.0, 0.3, 42.0, 9.8, 0.0))
	_expect(bad.is_empty() and absf(lob - rad_to_deg(BallisticsUtil.max_carry_elevation(42.0, 9.8, 0.0))) < 0.01,
			"BallisticsUtil.fallback_elevation: steeply-down targets met by bisection (never lobbed), out of reach -> longest carry %.1f deg %s" % [lob, bad])
	var d_eff := ArcCues.effective_range(1.1)
	_expect(near.call(ArcCues.dot_alpha(0.5 * d_eff, 1.1), 1.0) and near.call(ArcCues.dot_alpha(d_eff, 1.1), 1.0)
			and near.call(ArcCues.dot_alpha(1.5 * d_eff, 1.1), 0.625) and near.call(ArcCues.dot_alpha(3.0 * d_eff, 1.1), 0.25),
			"ArcCues.dot_alpha: full to d_eff (%.1f m for the bow), 25 %% from 2 x d_eff" % d_eff)
	_expect(near.call(ArcCues.ring_radius(10.0, 3.1), 10.0 * tan(deg_to_rad(3.1))) and near.call(ArcCues.ring_radius(2.0, 0.38), 0.18)
			and near.call(ArcCues.ring_radius(200.0, 1.43), 1.5) and ArcCues.ring_basis(Basis.IDENTITY, 10.0, 3.1).y.is_equal_approx(Vector3.UP),
			"ArcCues.ring_radius clamp(d tan(spread), 0.18, 1.5) m; ring_basis keeps the normal")
	_expect(near.call(ArcCues.hit_tint(Color(1, 0.35, 0.25, 0.9), 30.0, 2.9).a, 0.9 * BallisticsUtil.hit_chance(30.0, 2.9))
			and ArcCues.blade_first(TAU * 2.0, 1.0) and not ArcCues.blade_first(TAU * 2.5, 1.0) and ArcCues.blade_first(TAU * 2.1, 1.0),
			"ArcCues: the P(hit) ring tint and the tomahawk blade/haft cue (H15)")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.material = StandardMaterial3D.new()
	mm.mesh = sphere
	mm.instance_count = 160
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	ArcCues.enable_colors(mmi)
	var col := ArcCues.dot_color(Vector3.ZERO, Vector3(0, 0, -40), 1.1)
	mm.set_instance_color(3, col)
	# The headless dummy renderer stores no instance colours: read one back only with a real one.
	var stored := DisplayServer.get_name() == "headless" or is_equal_approx(mm.get_instance_color(3).a, col.a)
	_expect(mm.use_colors and mm.instance_count == 160 and (sphere.material as StandardMaterial3D).vertex_color_use_as_albedo
			and col.a < 0.9 and stored, "ArcCues.enable_colors: per-dot colours on the arc's MultiMesh (H12), dot at 40 m alpha %.2f" % col.a)
	mmi.free()


func _build_weapons() -> void:
	var holder := Node.new()
	holder.name = "Weapons"
	world.add_child(holder)
	_keep.append(holder)
	for key in KEYS:
		var w := _make(key)
		w.name = key.to_pascal_case()
		w.player = shooter
		w.muzzle = muzzle
		holder.add_child(w)
		if stand_in.get(key, false):
			var res := WeaponBalance.apply_set(w, rows[key].set)
			w.set_meta(&"balance_key", key)
			w.set_meta(&"balance_expect", rows[key].get("expect", {}))
			print("  note over_under: stand-in Musket, %d of its properties applied, not on a Musket: %s" % [res.applied.size(), res.skipped])
		else:
			var r := WeaponBalance.apply(w, key)
			if not r.ok:
				_expect(false, "%s balanced for the flight tests" % key)
				continue
		weapons[key] = w
		measured[key] = {"p": {}, "p_snap": {}}
	await _frames(2)


func _exp(key: String) -> Dictionary:
	return rows[key].get("expect", {})


# --- Cones ----------------------------------------------------------------------------------------

## Settled standing cone and best-stance cone from the weapon's own target_spread().
func _test_cones() -> void:
	for key in KEYS:
		var w: Weapon = weapons[key]
		var e := _exp(key)
		w.active = true
		w._bloom = 0.0
		_hold_settled(w)
		if key == KEYS[0]:
			_expect(shooter.is_on_floor() and shooter.horizontal_speed() < 1e-3, "the shooter stands still on the floor")
		var stand := w.target_spread()
		shooter.is_crouching = true
		if w is Firearm:
			(w as Firearm).state = Firearm.State.READY
			Input.action_press("aim")
		var best := w.target_spread()
		if w is Firearm:
			Input.action_release("aim")
		shooter.is_crouching = false
		_hold_settled(w)
		measured[key]["cone"] = stand
		measured[key]["cone_best"] = best
		measured[key]["d50_best_cone"] = BallisticsUtil.effective_range(best)
		_expect(absf(stand - float(e.cone_deg.stand)) < 1e-4, "%s: settled standing cone %.4f deg = expect %.4f" % [key, stand, e.cone_deg.stand])
		_expect(absf(best - float(e.cone_deg.best)) < 1e-3, "%s: best-stance cone %.4f deg = expect %.4f (%s)" % [key, best, e.cone_deg.best, e.best_stance])
		w.active = false
	# The best-stance ladder (cone model D50 = 0.5 / tan(cone)).
	var order: Array = WeaponBalance.ladder("best")
	var vals: Array = order.map(func(k: String) -> float: return measured[k]["d50_best_cone"])
	_expect_strict(order, vals, "best-stance D50 (0.5 / tan(best cone))")
	var brace := true
	for key in ["over_under", "musket"]:
		brace = brace and measured[key]["cone_best"] >= 0.32 - 1e-6
	_expect(brace, "long guns never brace below the 0.32 deg Graz machine-rest floor (over-under %.3f, musket %.3f)"
			% [measured["over_under"]["cone_best"], measured["musket"]["cone_best"]])


## Full power, held but not yet trembling (throwables, bow) / shouldered, not steadied (firearms).
func _hold_settled(w: Weapon) -> void:
	if w is Throwable:
		var t := w as Throwable
		t.state = Throwable.State.HOLDING
		t.charge = 1.0
		t.hold_time = 0.0
	elif w is Bow:
		var b := w as Bow
		b.state = Bow.State.HOLDING
		b.charge = 1.0
		b.hold_time = 0.0
	elif w is Firearm:
		(w as Firearm).state = Firearm.State.AIMING
		w.aim = 1.0


## Snap (LMB tapped from the lowered carry) and held (released 0.4 s after full aim) through
## Weapon.tick / Firearm._tick with Input, as the player drives it.
func _test_trigger_cones() -> void:
	for key in FIREARMS:
		var f: Firearm = weapons[key]
		var e := _exp(key)
		var lane := _lane()
		_place(lane)
		_aim_at(lane + Vector3(0.0, 0.0, -40.0))
		var snap := await _trigger_shot(f, -1.0)
		var held := await _trigger_shot(f, 0.4)
		measured[key]["snap_cone"] = snap[0]
		measured[key]["snap_time"] = snap[1]
		measured[key]["held_cone"] = held[0]
		_expect(absf(snap[0] - float(e.cone_deg.snap)) < 0.01 and absf(snap[1] - float(e.snap_time_s)) <= 2.5 * DT,
				"%s: snap shot through the trigger at %.3f deg after %.3f s (expect %.3f deg, %.3f s)" % [key, snap[0], snap[1], e.cone_deg.snap, e.snap_time_s])
		_expect(absf(held[0] - float(e.cone_deg.settled)) < 0.005,
				"%s: held 0.4 s past full aim: %.4f deg (expect %.4f)" % [key, held[0], e.cone_deg.settled])
	_place(Vector3(0.0, LAUNCH_H, 0.0))
	await _clear()


## Returns [cone at the discharge, seconds from the LMB press]. hold < 0: released the next tick.
func _trigger_shot(f: Firearm, hold: float) -> Array:
	f.active = true
	f.state = Firearm.State.READY
	f.loaded = true
	_rearm_barrels(f)
	f.aim = 0.0
	f._bloom = 0.0
	f.reserve = 99
	for i in 150:                        # settle at the carry
		await physics_frame
		shooter.move_and_slide()
		f.tick(DT)
	var got := [-1.0, -1.0]
	var tick_n := [0]
	var on_fired := func() -> void:
		if got[0] < 0.0:
			got[0] = f.spread
			got[1] = (tick_n[0] - 1) * DT
	f.fired.connect(on_fired)
	var full_at := -1
	for i in 600:
		await physics_frame
		tick_n[0] = i + 1
		shooter.move_and_slide()
		if i == 0:
			Input.action_press("fire")
		elif hold < 0.0 and i == 1:
			Input.action_release("fire")
		elif hold >= 0.0 and full_at >= 0 and (i - full_at) * DT >= hold - 1e-6 and Input.is_action_pressed("fire"):
			Input.action_release("fire")
		f.tick(DT)
		if full_at < 0 and f.aim >= 1.0:
			full_at = i
		if got[0] >= 0.0:
			break
	Input.action_release("fire")
	f.fired.disconnect(on_fired)
	for i in 50:                         # let the recoil run out
		await physics_frame
		f.tick(DT)
	f.active = false
	return got


## The over-under keeps its barrels in OverUnderBarrels and mirrors `loaded` from them: make
## both barrels charged and primed, the first on top (duck-typed, so this test still parses
## without the class).
func _rearm_barrels(f: Firearm) -> void:
	var b: Variant = f.get("barrels")
	if not (b is Object and (b as Object).has_method("restore")):
		return
	var ready_stage: int = (b as Object).get_script().get_script_constant_map().get("READY", 5)
	(b as Object).call("restore", {"top": 0, "stage": [ready_stage, ready_stage], "load_in": [true, true]})
	if "turning" in f:
		f.set("turning", false)
	if f.has_method("_mirror"):
		f.call("_mirror")


# --- Max carry and out of reach (design 4.3) ----------------------------------------------------------

func _flight(w: Weapon) -> Dictionary:
	if w is Throwable:
		var t := w as Throwable
		return {"speed": t.max_speed, "g": t.flight_gravity, "drag": t.flight_drag, "damage": t.max_damage}
	if w is Bow:
		var b := w as Bow
		return {"speed": b.max_arrow_speed, "g": b.arrow_gravity, "drag": 0.0, "damage": b.max_damage}
	var f := w as Firearm
	return {"speed": f.muzzle_speed, "g": f.ball_gravity, "drag": f.ball_drag, "damage": f.damage}


## A projectile of `w`'s kind leaving `origin` along `dir` at full power, spawned the way the
## weapon's launch spawns it (Throwable._launch_thrown / Weapon._launch), without spread.
func _spawn(w: Weapon, origin: Vector3, dir: Vector3) -> Node3D:
	var fl := _flight(w)
	var speed: float = fl.speed
	if w is Throwable:
		var t := w as Throwable
		var p := ThrownProjectile.new()
		p.kind = t.ammo_kind
		p.model_kind = t.projectile_kind
		p.velocity = dir * speed
		p.gravity = fl.g
		p.drag = fl.drag
		p.damage = fl.damage
		p.exclude = [shooter.get_rid()]
		p.shooter = shooter
		p.whoosh = false
		t._configure_projectile(p, origin, dir, speed)
		world.add_child(p)
		p.launch(origin, dir, t._launch_basis(dir))
		return p
	var q := Projectile.new()
	q.kind = Projectile.Kind.ARROW if w is Bow else Projectile.Kind.BALL
	q.velocity = dir * speed
	q.gravity = fl.g
	q.drag = fl.drag
	q.damage = fl.damage
	q.exclude = [shooter.get_rid()]
	q.shooter = shooter
	world.add_child(q)
	q.global_position = origin
	q.look_at(origin + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	return q


## First impact of each projectile: rec[id] = [collider, point, stuck].
func _track(p: Node3D, rec: Dictionary, tag: Variant) -> void:
	var id := p.get_instance_id()
	if p is ThrownProjectile:
		var on_thrown := func(c: Object, at: Vector3, stuck: bool) -> void:
			if not rec.has(id):
				rec[id] = [c, at, stuck, tag]
		(p as ThrownProjectile).hit.connect(on_thrown)
	else:
		var on_ball := func(c: Object, at: Vector3) -> void:
			if not rec.has(id):
				rec[id] = [c, at, false, tag]
		(p as Projectile).hit.connect(on_ball)


func _wait_for(rec: Dictionary, n: int, max_s: float) -> void:
	var t := 0.0
	while rec.size() < n and t < max_s:
		await physics_frame
		t += DT


func _test_max_carry() -> void:
	var rec := {}
	var fan := []
	var origin := Vector3(FAN_X, LAUNCH_H, 0.0)
	_place(origin)
	var shots := 0
	for key in KEYS:
		var w: Weapon = weapons[key]
		# Firearms: 0-25 deg (their longest carry is at 11-19 deg). Steeper balls stay up longer
		# than Projectile.max_life (20 s) and are freed in the air, as in the game.
		var steps := 101 if w is Firearm else 281
		for i in steps:
			var th := deg_to_rad(i * 0.25)
			var p := _spawn(w, origin, Vector3(0.0, sin(th), -cos(th)))
			_track(p, rec, [key, i * 0.25])
			fan.append([p, p.get_instance_id(), key])
			shots += 1
	# Out of reach (H3): aimed past the reach, along BallisticsUtil.zeroed_dir and along today's
	# Weapon.ballistic_dir, in their own lanes.
	var h3_cases := [["tomahawk", 40.0], ["spear", 50.0], ["atlatl", 100.0], ["bow", 250.0], ["pistol", 650.0]]
	var h3 := {}
	for c: Array in h3_cases:
		var key: String = c[0]
		var w: Weapon = weapons[key]
		var fl := _flight(w)
		for mode: String in ["h3", "now"]:
			var o := _lane()
			var target := o + Vector3(0.0, 0.0, -float(c[1]))
			var dir := BallisticsUtil.zeroed_dir(o, target, fl.speed, fl.g, fl.drag) if mode == "h3" \
					else Weapon.ballistic_dir(o, target, fl.speed, fl.g, fl.drag)
			var p := _spawn(w, o, dir)
			_track(p, rec, ["h3", key, mode, o, dir])
			shots += 1
	# Aimed steeply DOWN (off a wall or a cliff) at a ground point 1.2-4 m out and 7.5-40 m below:
	# steeper than the Newton clamp (-80.2 deg), so the solve misses. H3 must still put the shot
	# on the point, not lob it (the first H3 draft sent a musket ball 726 m out from here).
	var steep := {}
	var steep_cases := [[1.2, 7.5], [2.0, 12.0], [4.0, 40.0]]
	var src := FileAccess.get_file_as_string("res://scripts/weapons/weapon.gd")
	var has_h3 := src.contains("BallisticsUtil.fallback_elevation")
	_expect(not src.contains("BallisticsUtil.max_carry_elevation"),
			"weapon.gd does not carry the first H3 draft (it lobbed shots aimed steeply down)")
	for key in KEYS:
		var w: Weapon = weapons[key]
		var fl := _flight(w)
		for c: Array in steep_cases:
			for mode: String in ["h3", "now"]:
				var o := _lane() + Vector3(0.0, float(c[1]), 0.0)
				var target := Vector3(o.x, 0.0, o.z - float(c[0]))
				var dir := BallisticsUtil.zeroed_dir(o, target, fl.speed, fl.g, fl.drag) if mode == "h3" \
						else Weapon.ballistic_dir(o, target, fl.speed, fl.g, fl.drag)
				var p := _spawn(w, o, dir)
				_track(p, rec, ["steep", key, mode, o, dir, c])
				steep[[key, mode, c[0]]] = {"p": p, "id": p.get_instance_id()}
				shots += 1
	await _wait_for(rec, shots, 19.0)
	for id: int in rec:
		var tag: Array = rec[id][3]
		if tag[0] != "steep":
			continue
		var o: Vector3 = tag[3]
		var c: Array = tag[5]
		var at: Vector3 = rec[id][1]
		steep[[tag[1], tag[2], c[0]]]["miss"] = Vector2(at.x - o.x, at.z - (o.z - float(c[0]))).length()
		steep[[tag[1], tag[2], c[0]]]["elev"] = rad_to_deg(asin(clampf((tag[4] as Vector3).y, -1.0, 1.0)))
	for key in KEYS:
		for c: Array in steep_cases:
			for mode: String in ["h3", "now"]:
				var s: Dictionary = steep[[key, mode, c[0]]]
				if not s.has("miss"):
					if weapons[key] is Throwable:
						lost_through_ground[key] = lost_through_ground.get(key, 0) + 1
						continue
					_expect(false, "%s aimed %.1f m out, %.1f m down (%s): the shot came down" % [key, c[0], c[1], mode])
					continue
				var line := "%s aimed %.1f m out and %.1f m down: %s leaves at %.1f deg and lands %.2f m from the point" \
						% [key, c[0], c[1], "zeroed_dir" if mode == "h3" else "Weapon.ballistic_dir", s.elev, s.miss]
				if mode == "h3" or has_h3:
					_expect(s.miss <= 0.1 and s.elev < 0.0, line)
				elif s.miss > 0.1:
					pending.append("H3 not in weapon.gd yet: " + line)
	var best := {}
	for id: int in rec:
		var r: Array = rec[id]
		var tag: Array = r[3]
		if tag[0] == "h3":
			var o: Vector3 = tag[3]
			var land := Vector2(r[1].x - o.x, r[1].z - o.z).length()
			h3[[tag[1], tag[2]]] = {"land": land, "elev": rad_to_deg(atan2(tag[4].y, Vector2(tag[4].x, tag[4].z).length()))}
			continue
		var key: String = tag[0]
		var land := Vector2(r[1].x - origin.x, r[1].z - origin.z).length()
		if not best.has(key) or land > best[key][0]:
			best[key] = [land, tag[1]]
	var lost := 0
	for f: Array in fan:
		if not rec.has(f[1]) and not is_instance_valid(f[0]) and weapons[f[2]] is Throwable:
			lost += 1
			lost_through_ground[f[2]] = lost_through_ground.get(f[2], 0) + 1
	_expect(rec.size() + lost == shots, "every fan and out-of-reach shot came down (%d of %d, %d thrown lost through the ground; firearms 0-25 deg, the rest 0-70 deg)"
			% [rec.size(), shots, lost])
	for key in KEYS:
		var e := _exp(key)
		var got: Array = best.get(key, [0.0, 0.0])
		measured[key]["max_carry"] = got[0]
		measured[key]["best_elev"] = got[1]
		_expect(absf(got[0] - float(e.max_range_m)) <= 0.02 * float(e.max_range_m),
				"%s: max carry %.1f m at %.2f deg (expect %.1f m at %.1f deg, +-2 %%)" % [key, got[0], got[1], e.max_range_m, e.best_elevation_deg])
	var order: Array = WeaponBalance.ladder("max_range")
	_expect_strict(order, order.map(func(k: String) -> float: return measured[k]["max_carry"]), "max carry")
	for c: Array in h3_cases:
		var key: String = c[0]
		var e := _exp(key)
		var fl := _flight(weapons[key])
		var mc := rad_to_deg(BallisticsUtil.max_carry_elevation(fl.speed, fl.g, fl.drag))
		var a: Dictionary = h3.get([key, "h3"], {"land": 0.0, "elev": -99.0})
		var n: Dictionary = h3.get([key, "now"], {"land": 0.0, "elev": -99.0})
		_expect(absf(a.elev - mc) <= 1.0 and a.elev >= 0.0 and a.land >= 0.97 * float(e.max_range_m),
				"%s aimed at %.0f m (out of reach): zeroed_dir leaves at %.1f deg (longest carry %.1f), lands %.1f m (>= 97 %% of %.1f)"
				% [key, c[1], a.elev, mc, a.land, e.max_range_m])
		measured[key]["h3"] = {"aim_m": c[1], "h3_land": a.land, "now_land": n.land, "now_elev": n.elev}
		if absf(n.elev - mc) <= 1.0:
			_expect(n.land >= 0.97 * float(e.max_range_m) and n.elev >= 0.0,
					"%s: Weapon.ballistic_dir has H3: lands %.1f m" % [key, n.land])
		else:
			pending.append("H3 not in weapon.gd yet: %s aimed at %.0f m leaves at %.1f deg and lands at %.1f m (with H3: %.1f m)"
					% [key, c[1], n.elev, n.land, a.land])
	await _clear()


# --- Zeroed shots and damage ----------------------------------------------------------------------------

## One spread-free full-power shot through the weapon's own launch. Returns the projectile.
func _shoot(w: Weapon) -> Node3D:
	if w is Throwable:
		var t := w as Throwable
		t.state = Throwable.State.HOLDING
		t.charge = 1.0
		t.hold_time = 0.0
		return t._launch_thrown()
	if w is Bow:
		var b := w as Bow
		b.state = Bow.State.HOLDING
		b.charge = 1.0
		b.hold_time = 0.0
		b.quiver = 100000
		var before := world.get_child_count()
		b._fire()
		return world.get_child(world.get_child_count() - 1) as Node3D if world.get_child_count() > before else null
	var f := w as Firearm
	return f._launch(Projectile.Kind.BALL, f.muzzle_speed, f.ball_gravity, f.ball_drag, f.damage, f.muzzle_speed)


func _test_zero() -> void:
	var rec := {}
	var cases := []
	for key in KEYS:
		var e := _exp(key)
		var d50 := float(e.d50_m)
		var dists := [0.5 * d50, d50, 0.9 * float(e.flat_reach_m)]
		if e.get("one_shot_limit") == "falloff":
			dists.append_array([0.9 * float(e.one_shot_torso_m), 1.1 * float(e.one_shot_torso_m)])
		for d: float in dists:
			var o := _lane()
			var board := _box_body("Board", Vector3(8.0, 8.0, 0.3), o + Vector3(0.0, 0.0, -d - 0.15), "straw", true)
			cases.append({"key": key, "d": d, "o": o, "board": board})
	await _frames(2)
	for c: Dictionary in cases:
		var w: Weapon = weapons[c.key]
		_place(c.o)
		var aim: Vector3 = c.o + Vector3(0.0, 0.0, -c.d)
		_aim_at(aim)
		w.spread = 0.0
		var p := _shoot(w)
		c["aim"] = aim
		if p:
			_track(p, rec, c)
	await _wait_for(rec, cases.size(), 12.0)
	for id: int in rec:
		var tagged: Dictionary = rec[id][3]
		tagged["r"] = rec[id]
	for c: Dictionary in cases:
		var r: Array = c.get("r", [])
		var key: String = c.key
		var e := _exp(key)
		if r.is_empty() or r[0] != c.board:
			_expect(false, "%s zeroed at %.1f m hits the board" % [key, c.d])
			continue
		var miss: float = (r[1] - c.aim).length()
		var hl: Array = c.board.get("hit_log")
		var dmg: float = hl[0].damage if not hl.is_empty() else 0.0
		var reach_note := " (beyond effective range, inside the %.0f m flat reach)" % e.flat_reach_m if c.d > float(e.d50_m) + 0.01 else ""
		_expect(miss <= 0.06, "%s zeroed at %.1f m%s lands %.3f m from the aim point" % [key, c.d, reach_note, miss])
		var os_lim: String = e.get("one_shot_limit", "")
		var os_d: float = float(e.get("one_shot_torso_m", 0.0))
		if os_lim == "never":
			_expect(dmg < 100.0, "%s at %.1f m: %.1f damage, never a one-shot torso kill" % [key, c.d, dmg])
		elif os_lim == "reach":
			_expect(dmg >= 100.0, "%s at %.1f m: %.1f damage, a one-shot torso kill to its reach" % [key, c.d, dmg])
		elif os_lim == "falloff":
			var inside: bool = c.d <= os_d
			_expect((dmg >= 100.0) == inside, "%s at %.1f m: %.1f damage (one-shot torso to %.1f m)" % [key, c.d, dmg, os_d])
		measured[key].get_or_add("zero", []).append([snappedf(c.d, 0.1), snappedf(miss, 0.001), snappedf(dmg, 0.1)])
	await _clear()


# --- Hit rates (design 4.4) -----------------------------------------------------------------------------

func _test_hit_rates() -> void:
	# Distances: the table's, plus a D50 grid shared by neighbours on the ladder (common random
	# numbers make the measured D50 order robust where two weapons are close).
	var grid: Array[float] = []
	for key in KEYS:
		for k: float in [0.85, 1.0, 1.15]:
			grid.append(snappedf(float(_exp(key).d50_m) * k, 0.1))
	for key in KEYS:
		var e := _exp(key)
		var reach := float(e.flat_reach_m)
		var d50 := float(e.d50_m)
		var cells := []
		var ds: Array[float] = []
		for d in HIT_DISTANCES:
			if d <= reach:
				ds.append(d)
		for g in grid:
			if g >= 0.7 * d50 and g <= 1.4 * d50 and not g in ds:
				ds.append(g)
		if key == "tomahawk":
			for d in TOMAHAWK_BLADE_DISTANCES:
				if not d in ds:
					ds.append(d)
		ds.sort()
		for d in ds:
			cells.append({"key": key, "d": d, "cone": measured[key]["cone"], "snap": false})
		if key in FIREARMS:
			for d: float in [20.0, 50.0]:
				cells.append({"key": key, "d": d, "cone": measured[key]["snap_cone"], "snap": true})
		await _run_cells(cells)
		for c: Dictionary in cells:
			var p := float(c.hits) / N
			if c.snap:
				measured[key]["p_snap"][c.d] = p
			else:
				measured[key]["p"][c.d] = p
				if key == "tomahawk":
					measured[key].get_or_add("blade", {})[c.d] = float(c.blade) / N
		_check_rates(key)
	var order: Array = WeaponBalance.ladder("effective")
	_expect_strict(order, order.map(func(k: String) -> float: return measured[k]["d50"]), "measured standing D50")


func _run_cells(cells: Array) -> void:
	var rec := {}
	for c: Dictionary in cells:
		var o := _lane()
		c["o"] = o
		c["disc"] = _disc(o + Vector3(0.0, 0.0, -c.d))
		_box_body("Backstop", Vector3(30.0, 40.0, 1.0), o + Vector3(0.0, 20.0 - LAUNCH_H, -c.d - 2.5), "dirt")
	await _frames(2)
	var shots := 0
	var spawned := []
	for c: Dictionary in cells:
		var w: Weapon = weapons[c.key]
		_place(c.o)
		_aim_at(c.o + Vector3(0.0, 0.0, -c.d))
		seed(SEED)
		for i in N:
			w.spread = c.cone
			var p := _shoot(w)
			if p:
				_track(p, rec, c)
				spawned.append([p, p.get_instance_id(), c, i])
				shots += 1
	await _wait_for(rec, shots, 8.0)
	for c: Dictionary in cells:
		c["lost"] = 0
	for sp: Array in spawned:
		if rec.has(sp[1]):
			continue
		var c: Dictionary = sp[2]
		if not is_instance_valid(sp[0]):
			if weapons[c.key] is Throwable:
				c.lost += 1
				lost_through_ground[c.key] = lost_through_ground.get(c.key, 0) + 1
			else:
				print("    unresolved %s at %.1f m shot %d: freed without an impact" % [c.key, c.d, sp[3]])
			continue
		var n := sp[0] as Node3D
		var rel: Vector3 = n.global_position - (c.o as Vector3)
		print("    unresolved %s at %.1f m shot %d: at %s (from the muzzle) v %s phase %s impacts %s parent %s"
				% [c.key, c.d, sp[3], rel, n.get("velocity"), n.get("phase"), n.get("impacts"), n.get_parent().name])
	for c: Dictionary in cells:
		c["hits"] = 0
		c["blade"] = 0
		c["resolved"] = 0
	for id: int in rec:
		var r: Array = rec[id]
		var c: Dictionary = r[3]
		c.resolved += 1
		if r[0] == c.disc:
			c.hits += 1
			if r[2]:
				c.blade += 1
	for c: Dictionary in cells:
		if c.resolved + c.lost < N:
			_expect(false, "%s at %.1f m: %d of %d shots resolved" % [c.key, c.d, c.resolved, N])
	await _clear()


func _check_rates(key: String) -> void:
	var e := _exp(key)
	var p: Dictionary = measured[key]["p"]
	var parts := PackedStringArray()
	var worst := 0.0
	var all_ok := true
	for ds: String in e.p_hit_disc:
		var d := float(ds)
		if not p.has(d):
			continue
		var want := float(e.p_hit_disc[ds])
		var tol := 3.0 * sqrt(maxf(want * (1.0 - want), 0.0) / N) + 0.02
		var ok := absf(p[d] - want) <= tol
		all_ok = all_ok and ok
		worst = maxf(worst, absf(p[d] - want) / tol)
		parts.append("%sm %.2f/%.2f%s" % [ds, p[d], want, "" if ok else " X"])
	_expect(all_ok, "%s hit rates (measured/expect): %s" % [key, "  ".join(parts)])
	if key in FIREARMS:
		var ps: Dictionary = measured[key]["p_snap"]
		var sparts := PackedStringArray()
		var sok := true
		for d: float in [20.0, 50.0]:
			var want := float(e.p_hit_disc_snap.get(str(int(d)), -1.0))
			if want < 0.0 or not ps.has(d):
				continue
			var tol := 3.0 * sqrt(maxf(want * (1.0 - want), 0.0) / N) + 0.02
			sok = sok and absf(ps[d] - want) <= tol
			sparts.append("%dm %.2f/%.2f" % [d, ps[d], want])
		_expect(sok, "%s snap-cone hit rates (%.3f deg): %s" % [key, measured[key]["snap_cone"], "  ".join(sparts)])
	# Measured D50: the first fall below 0.5, linearly interpolated.
	var ds_sorted := p.keys()
	ds_sorted.sort()
	var d50 := INF
	var prev := []
	for d: float in ds_sorted:
		if p[d] < 0.5:
			d50 = d if prev.is_empty() else lerpf(prev[0], d, (prev[1] - 0.5) / maxf(prev[1] - p[d], 1e-6))
			break
		prev = [d, p[d]]
	measured[key]["d50"] = d50
	_expect(absf(d50 - float(e.d50_m)) <= 0.1 * float(e.d50_m),
			"%s measured D50 %.1f m (expect %.1f, +-10 %%)" % [key, d50, e.d50_m])
	if key == "tomahawk":
		var bl: Dictionary = measured[key]["blade"]
		var bparts := PackedStringArray()
		var b_ok := true
		for d in TOMAHAWK_BLADE_DISTANCES:
			var want_stick := _in_windows(d, e.stick_windows_m)
			var blade: float = bl.get(d, 0.0)
			var hit: float = p.get(d, 0.0)
			# Blade hits = torso hits where the windows say "stick", none where they say "haft"
			# (a few throws near a window edge may flip: 5 % slack).
			var ok := absf(blade - hit) <= 0.05 if want_stick else blade <= 0.05
			if _near_edge(d, e.stick_windows_m, e.haft_windows_m, 0.3):
				ok = true
			b_ok = b_ok and ok
			bparts.append("%.1fm %.2f/%.2f" % [d, hit, blade])
		_expect(b_ok, "tomahawk torso/blade hit share: %s" % "  ".join(bparts))


# --- Tomahawk stick windows (design 4.5) ---------------------------------------------------------------

func _test_tomahawk_windows() -> void:
	var holder: Node = world.get_node("Weapons")
	var variants := {}
	variants["default"] = weapons["tomahawk"]
	WeaponBalance.preset = "realistic"
	var real := _make("tomahawk") as ThrowableTomahawk
	real.player = shooter
	real.muzzle = muzzle
	holder.add_child(real)
	WeaponBalance.apply(real, "tomahawk")
	WeaponBalance.preset = ""
	variants["realistic"] = real
	var old := _make("tomahawk") as ThrowableTomahawk     # script defaults: assist 2.5-15 m
	old.player = shooter
	old.muzzle = muzzle
	holder.add_child(old)
	variants["pre-balance"] = old
	var sweep: Array[float] = []
	for i in 57:
		sweep.append(2.0 + 0.25 * i)          # 2.0 .. 16.0, exact in binary
	for extra: float in [10.7, 13.5]:
		sweep.append(extra)
	sweep.sort()
	var cases := []
	for v: String in variants:
		for dist in sweep:
			var o := _lane()
			var board := _box_body("Board", Vector3(1.6, 3.2, 0.3), o + Vector3(0.0, 0.0, -dist - 0.15), "wood", true)
			cases.append({"v": v, "d": dist, "o": o, "board": board})
	await _frames(2)
	var rec := {}
	for c: Dictionary in cases:
		var t: ThrowableTomahawk = variants[c.v]
		_place(c.o)
		_aim_at(c.o + Vector3(0.0, 0.0, -c.d))
		t.spread = 0.0
		var p := _shoot(t)
		if p:
			_track(p, rec, c)
	await _wait_for(rec, cases.size(), 4.0)
	var res := {}
	for id: int in rec:
		var r: Array = rec[id]
		var c: Dictionary = r[3]
		var what := "miss"
		if r[0] == c.board:
			what = "stick" if r[2] else "haft"
		res[[c.v, c.d]] = what
		if what != "miss":
			var hl: Array = c.board.get("hit_log")
			c["damage"] = hl[0].damage if not hl.is_empty() else 0.0
	var e := _exp("tomahawk")
	for v: String in variants:
		var sticks: Array = e.stick_windows_m if v != "realistic" else e.presets.realistic.stick_windows_m
		var hafts: Array = e.haft_windows_m if v != "realistic" else e.presets.realistic.haft_windows_m
		var line := ""
		var bad := PackedStringArray()
		var runs := []
		for dist in sweep:
			var got: String = res.get([v, dist], "none")
			line += "S" if got == "stick" else ("h" if got == "haft" else "?")
			if runs.is_empty() or runs[-1][0] != got:
				runs.append([got, dist, dist])
			else:
				runs[-1][2] = dist
			if v == "pre-balance":
				continue
			if _near_edge(dist, sticks, hafts, WINDOW_TOL):
				continue
			var want := "stick" if _in_windows(dist, sticks) else ("haft" if _in_windows(dist, hafts) else "?")
			if want != "?" and got != want:
				bad.append("%.2f m %s (expect %s)" % [dist, got, want])
		measured["tomahawk"]["windows_" + v] = runs.filter(func(r: Array) -> bool: return r[0] == "stick").map(
				func(r: Array) -> Array: return [r[1], r[2]])
		print("    %-11s 2 m %s 16 m   (S stick, h haft)" % [v, line])
		if v == "pre-balance":
			var all_stick := true
			for dist in sweep:
				if dist >= 3.0 and dist <= 15.0 and res.get([v, dist], "") != "stick":
					all_stick = false
			_expect(all_stick, "pre-balance assist (2.5-15 m) sticks everywhere 3-15 m: the windows beyond 10 m come from the balance")
			continue
		_expect(bad.is_empty(), "tomahawk %s: stick/haft agree with expect windows away from their edges (+-%.2f m) %s" % [v, WINDOW_TOL, bad])
		var spots := {"default": {"stick": [3.0, 4.5, 6.5, 8.5, 9.5, 12.0], "haft": [10.7, 13.5]},
				"realistic": {"stick": [4.5, 8.5], "haft": [6.5, 10.7]}}
		var spot: Dictionary = spots[v]
		var sbad := PackedStringArray()
		for kind: String in spot:
			for dist: float in spot[kind]:
				if res.get([v, dist], "none") != kind:
					sbad.append("%.1f m %s" % [dist, res.get([v, dist], "none")])
		_expect(sbad.is_empty(), "tomahawk %s: sticks at %s, bounces off the haft at %s %s" % [v, spot.stick, spot.haft, sbad])
	# Damage: a blade hit is 85 x falloff (< 100: a finisher), a haft hit the 12 blunt.
	var dmg_ok := true
	var blade_dmg := []
	for c: Dictionary in cases:
		if c.v != "default" or not c.has("damage"):
			continue
		var what: String = res.get([c.v, c.d], "")
		if what == "stick":
			dmg_ok = dmg_ok and c.damage > 75.0 and c.damage < 100.0
			blade_dmg.append(c.damage)
		elif what == "haft":
			dmg_ok = dmg_ok and c.damage <= 12.0 + 1e-3
	_expect(dmg_ok and not blade_dmg.is_empty(), "tomahawk damage: blade %.1f-%.1f (under 100 HP), haft <= 12"
			% [blade_dmg.min() if blade_dmg else 0.0, blade_dmg.max() if blade_dmg else 0.0])
	await _clear()


func _in_windows(d: float, windows: Array) -> bool:
	for w: Array in windows:
		if d >= float(w[0]) - 1e-6 and d <= float(w[1]) + 1e-6:
			return true
	return false


func _near_edge(d: float, a: Array, b: Array, tol: float) -> bool:
	for w: Array in a + b:
		# A window edge lies half a sweep step outside the last point of the run.
		if absf(d - float(w[0])) <= tol or absf(d - float(w[1])) <= tol:
			return true
	return false


# --- Output ---------------------------------------------------------------------------------------------

func _expect(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)
	print(("  ok   " if cond else "  FAIL ") + msg)


func _expect_strict(order: Array, vals: Array, what: String) -> void:
	var ok := true
	var parts := PackedStringArray()
	for i in order.size():
		parts.append("%s %.1f" % [order[i], vals[i]])
		if i > 0 and not (float(vals[i - 1]) < float(vals[i])):
			ok = false
	_expect(ok, "ladder by %s strict: %s" % [what, "  <  ".join(parts)])


func _print_table() -> void:
	print("")
	print("RANGE LADDER, measured in Godot (expect from data/weapons/ballistics.json in brackets)")
	print("%-11s %8s %16s %7s %14s %16s %9s  %s" % ["weapon", "speed", "max carry", "elev", "D50 stand", "best cone/D50", "snap", "torso hit share at 5/10/20/30/50/100/200 m"])
	for key in KEYS:
		var m: Dictionary = measured[key]
		var e := _exp(key)
		var fl := _flight(weapons[key])
		var ps := PackedStringArray()
		for d in HIT_DISTANCES:
			ps.append("%.2f" % m.p[d] if m.p.has(d) else "  - ")
		print("%-11s %6.0f/s %7.1f (%6.1f) %6.2f° %5.1f (%5.1f) %6.3f°/%5.1f %s  %s" % [
				key + ("*" if stand_in.get(key, false) else ""), fl.speed, m.get("max_carry", 0.0), e.max_range_m,
				m.get("best_elev", 0.0), m.get("d50", 0.0), e.d50_m, m.get("cone_best", 0.0), m.get("d50_best_cone", 0.0),
				("%7.3f°" % m.snap_cone) if m.has("snap_cone") else "     -  ", " ".join(ps)])
	if stand_in.get("over_under", false):
		print("  * over_under flown on a Musket stand-in with its row's ballistics (OverUnderMusket not built yet)")
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--out="):
			var out := {}
			for key in measured:
				out[key] = measured[key]
			var f := FileAccess.open(a.substr(6), FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(out, "  ", false))
				print("wrote " + a.substr(6))


func _finish(t0: int) -> void:
	if not lost_through_ground.is_empty():
		pending.append("ThrownProjectile POINT_FIRST ray gap: throws fell through flat ground without an impact %s (counted as misses; see the ray-continuity fix for thrown_projectile.gd)"
				% lost_through_ground)
	for p in pending:
		print("  pending " + p)
	print("RANGE LADDER %s (%d checks, %d pending, %.0f s)" % [
			"PASSED" if fails.is_empty() else "FAILED (%d)" % fails.size(), checks, pending.size(),
			(Time.get_ticks_msec() - t0) / 1000.0])
	for f in fails:
		printerr("FAIL: " + f)
	quit(0 if fails.is_empty() else 1)
