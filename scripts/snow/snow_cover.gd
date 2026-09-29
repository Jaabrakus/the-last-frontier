class_name SnowCover
extends Node
## Snow on the land (user 2026-09-28: "we need to add snow and snow effects on our land and snow prints"; picked: real
## winter and a test key; falling snow, the ground, trees, rocks and roofs, footprints, gameplay; the prints pressed into
## a trail map). The survival core already has the snow: SurvivalWeather turns the sky's rain into snow below freezing
## (November to March) and keeps snow_depth_cm (building while it snows, melting in a thaw, deepest in January and
## February). This node shows it:
##   the shader globals (shaders/common/snow.gdshaderinc) every frame: snow_cover (the depth over FULL_M, eased), snow_fresh
##   (falling or new), snow_total (the snowfall so far: the prints fill in with it), the shelter map (where a roof or a
##   floor above keeps the snow off: built from the level's colliders, again when a building piece goes up or down);
##   the terrain, the grass (buried as it deepens), the trees, the fort and the built pieces read them;
##   the falling snow (SnowFall, round the camera) in place of the rain while the core says it snows (WeatherFx.snow_mix);
##   the prints (SnowPrints: the player, the spouse, the horse, the deer and the wolves press the snow down);
##   the footsteps (Footsteps asks snow_at(): a crunch in the snow);
##   the land (user 2026-09-28: "we need to make it procedure beacuse we have the great planes as well as the water";
##   SnowLand, data/snow/snow.json): the depth square by square and point by point (the open plains scoured on the
##   rises and the slopes facing the wind and drifted in their lee, the woods deep and even, the cliffs' faces bare),
##   the shaders' region map, and depth_at() the same on the CPU: the prints, the footsteps and the slowed walk follow
##   the snow where the player stands (the core's snow_here_cm context);
##   the water's ice (water_ice: the river's shelf ice from the banks as the cold deepens, frozen across in deep winter),
##   firm enough to walk on back from its thin edge (RiverIce: slabs at the water's surface round the player).
## Test key: Shift+F10 cycles a snowing January morning -> a clear winter day with the snow lying -> back to the date and
## the ground it was.
##
##   var snow := SnowCover.find(tree)
##   snow.depth_at(pos)     # m of snow at a point (0 under a roof)

const GROUP := &"snow_cover"
## Snow this deep (m) is snow_cover 1 (shaders: SNOW_FULL_M).
const FULL_M := 0.35
## How fast the shown depth follows the core's (m / s; the core's own change is a centimetre or two a game hour).
const EASE_M_PER_S := 0.12
const SHELTER_RES := 0.5
const SHELTER_HALF := 400.0
## A collider whose underside is this high over the ground (m) and at least this wide covers what is under it.
const COVER_MIN_H := 1.3
const COVER_MIN_W := 0.8
const SnowLand := preload("res://scripts/snow/snow_land.gd")
const RiverIce := preload("res://scripts/snow/river_ice.gd")

## The depth shown now (m), and the core's.
var depth_m := 0.0
var target_m := 0.0
## 0..1: the cover and the freshness sent to the shaders (snow_cover, snow_fresh).
var cover := 0.0
var fresh := 0.0
## m of water depth the ice covers now (water_ice), and the date's.
var ice_m := 0.0
var ice_target_m := 0.0
## Test and tool override of the ice (m of water depth; < 0: the date's).
var force_ice_m := -1.0
## 0..1: how hard it is snowing (the sky's rain rate while the core says snow).
var falling := 0.0
## Snowfall so far, tenths of a cm (snow_total).
var total_units := 0.0
## Test and tool override of the depth (m; < 0: the core's).
var force_depth_m := -1.0
var prints: SnowPrints
var fall: SnowFall
## The river's ice underfoot (river_ice.gd).
var river_ice: StaticBody3D
## The broadleaves' year (autumn colour, the fall, bare winter trees, spring's buds): SeasonLeaves.
var season: SeasonLeaves

var _shelter: Image
## The shelter texture the shaders sample: kept for the whole run (SnowPrints.texture).
static var _shelter_tex: ImageTexture
var _shelter_dirty_frame := 0
var _build_hooked := false
var _last_core_cm := -1.0
var _test_step := 0
var _test_saved := {}


static func find(tree: SceneTree) -> SnowCover:
	return tree.get_first_node_in_group(GROUP) as SnowCover if tree else null


func _ready() -> void:
	add_to_group(GROUP)
	process_priority = -5
	prints = SnowPrints.new()
	prints.name = "Prints"
	prints.cover = self
	add_child(prints)
	fall = SnowFall.new()
	fall.name = "Fall"
	fall.cover = self
	add_child(fall)
	season = SeasonLeaves.new()
	season.name = "Leaves"
	add_child(season)
	river_ice = RiverIce.new()
	river_ice.name = "RiverIce"
	river_ice.set("cover", self)
	add_child(river_ice)
	_global(&"snow_cover", 0.0)
	_global(&"snow_fresh", 0.0)
	_global(&"snow_total", 0.0)
	_global(&"water_ice", 0.0)
	SnowLand.bake()


func _core() -> SurvivalCore:
	var b := SurvivalBridge.find(get_tree()) if is_inside_tree() else null
	return b.core if b else null


func _process(delta: float) -> void:
	var core := _core()
	var core_cm := SurvivalWeather.snow_depth_cm(core) if core else 0.0
	target_m = force_depth_m if force_depth_m >= 0.0 else core_cm / 100.0
	var snowing := core != null and SurvivalWeather.precip(core) == "snow"
	var ws := _sky()
	falling = move_toward(falling, clampf((ws.rain if ws else 0.2) * 3.0, 0.25, 1.0) if snowing else 0.0, delta * 0.5)
	# the snowfall's running total (the prints fill in with it): what the core's depth gains while it snows
	if _last_core_cm >= 0.0 and core_cm > _last_core_cm and snowing:
		total_units = fmod(total_units + (core_cm - _last_core_cm) * 10.0, 65536.0)
	_last_core_cm = core_cm
	var step := EASE_M_PER_S * delta * (4.0 if absf(target_m - depth_m) > 0.1 else 1.0)
	depth_m = move_toward(depth_m, target_m, step)
	var c := clampf(depth_m / FULL_M, 0.0, 1.0)
	cover = c
	_global(&"snow_cover", c)
	fresh = falling
	if core and c > 0.0:
		var since_h := (float(core.state.minutes) - SurvivalUtil.num(core.state.weather.get("last_snow_min"), -1e9)) / 60.0
		fresh = maxf(fresh, 1.0 - clampf(since_h / 48.0, 0.0, 1.0))
	_global(&"snow_fresh", fresh)
	_global(&"snow_total", total_units)
	# the ice follows the month's cold (a jump of the date: at once)
	ice_target_m = force_ice_m if force_ice_m >= 0.0 else SnowLand.ice_target_m(core)
	var grow := float((SnowLand.data().get("ice", {}) as Dictionary).get("grow_per_s", 0.03))
	ice_m = move_toward(ice_m, ice_target_m, delta * grow * (20.0 if absf(ice_target_m - ice_m) > 0.5 else 1.0))
	_global(&"water_ice", ice_m)
	_tell_weather_fx(snowing)
	_tell_core_here(core)
	_keep_shelter()


## The snow where the player stands, for the core's slowed walk (survival_conditions: snow_here_cm), when it changes.
func _tell_core_here(core: SurvivalCore) -> void:
	if core == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var cm := roundf(depth_at(player.global_position) * 50.0) * 2.0
	if SurvivalUtil.num(core.state.context.get("snow_here_cm"), -1.0) != cm:
		core.set_context({"snow_here_cm": cm})

func _sky() -> WeatherSystem:
	var dn := get_tree().get_first_node_in_group(&"weather") if is_inside_tree() else null
	var w: Variant = dn.get("weather") if dn else null
	return w as WeatherSystem


## The rain streaks give way to the snow while it snows (WeatherFx.snow_mix).
func _tell_weather_fx(snowing: bool) -> void:
	var dn := get_tree().get_first_node_in_group(&"weather")
	if dn == null:
		return
	for c in dn.get_children():
		if c is WeatherFx:
			(c as WeatherFx).snow_mix = 1.0 if snowing else 0.0


static func _global(uniform: StringName, value: Variant) -> void:
	if ProjectSettings.has_setting("shader_globals/" + String(uniform)):
		RenderingServer.global_shader_parameter_set(uniform, value)


# --- Where the snow lies -----------------------------------------------------------------------------------------

## m of snow at `pos`: the shown depth x the land's there (SnowLand.depth_k: the region, the wind, the trees); 0 under a
## roof or a floor above (less under the trees is the shaders' look, not counted here).
func depth_at(pos: Vector3) -> float:
	if depth_m <= 0.0 or sheltered(pos):
		return 0.0
	return depth_m * SnowLand.depth_k_at(pos)


## Whether a roof or a floor above keeps the snow off `pos` (the shelter map).
func sheltered(pos: Vector3) -> bool:
	if _shelter == null:
		return false
	var n := _shelter.get_width()
	var i := int(floor((pos.x + SHELTER_HALF) / SHELTER_RES))
	var j := int(floor((pos.z + SHELTER_HALF) / SHELTER_RES))
	if i < 0 or j < 0 or i >= n or j >= n:
		return false
	var c := _shelter.get_pixel(i, j)
	var cm := roundf(c.r * 255.0) * 256.0 + roundf(c.g * 255.0)
	return cm > 0.5 and pos.y < (cm - 10000.0) * 0.01 - 0.05


func _keep_shelter() -> void:
	if not _build_hooked:
		var bw := BuildWorld.of(get_tree(), false)
		if bw:
			bw.changed.connect(func() -> void: _shelter_dirty_frame = Engine.get_process_frames() + 3)
			_build_hooked = true
	if _shelter == null and Engine.get_process_frames() > 30:
		_shelter_dirty_frame = Engine.get_process_frames()
	if _shelter_dirty_frame > 0 and Engine.get_process_frames() >= _shelter_dirty_frame:
		_shelter_dirty_frame = 0
		build_shelter()


## The shelter map from the level's static colliders: every box or convex shape whose underside is COVER_MIN_H over
## the ground under it and COVER_MIN_W wide (a roof, a floor above, the firing step) marks the ground under its
## footprint with its underside's height (the lowest wins).
func build_shelter() -> void:
	var n := int(round(2.0 * SHELTER_HALF / SHELTER_RES))
	var data := PackedByteArray()
	data.resize(n * n * 2)
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return
	for c in scene.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		if cs.shape == null or cs.disabled or not (cs.get_parent() is StaticBody3D or cs.get_parent() is AnimatableBody3D):
			continue
		if (cs.get_parent() as Node).is_in_group(&"terrain") or (cs.get_parent() as Node).is_in_group(RiverIce.GROUP):
			continue
		var ab := _shape_aabb(cs)
		if ab.size.x < COVER_MIN_W or ab.size.z < COVER_MIN_W:
			continue
		var mid := ab.get_center()
		var ground := FrontierTerrain.height_at(mid.x, mid.z)
		if ab.position.y - ground < COVER_MIN_H:
			continue
		var cm := clampi(int(round(ab.position.y * 100.0)) + 10000, 1, 65535)
		var i0 := clampi(int(floor((ab.position.x + SHELTER_HALF) / SHELTER_RES)), 0, n - 1)
		var i1 := clampi(int(floor((ab.end.x + SHELTER_HALF) / SHELTER_RES)), 0, n - 1)
		var j0 := clampi(int(floor((ab.position.z + SHELTER_HALF) / SHELTER_RES)), 0, n - 1)
		var j1 := clampi(int(floor((ab.end.z + SHELTER_HALF) / SHELTER_RES)), 0, n - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var k := (j * n + i) * 2
				var cur := int(data[k]) * 256 + int(data[k + 1])
				if cur == 0 or cm < cur:
					data[k] = cm >> 8
					data[k + 1] = cm & 255
	_shelter = Image.create_from_data(n, n, false, Image.FORMAT_RG8, data)
	if _shelter_tex == null:
		_shelter_tex = ImageTexture.create_from_image(_shelter)
	else:
		_shelter_tex.update(_shelter)
	_global(&"snow_shelter", _shelter_tex)
	_global(&"snow_shelter_rect", Vector4(-SHELTER_HALF, -SHELTER_HALF, 2.0 * SHELTER_HALF, 2.0 * SHELTER_HALF))


## A collision shape's world AABB (boxes and convex hulls; others by their debug mesh's bounds).
static func _shape_aabb(cs: CollisionShape3D) -> AABB:
	var xf := cs.global_transform
	var local := AABB()
	if cs.shape is BoxShape3D:
		var e := (cs.shape as BoxShape3D).size
		local = AABB(-e * 0.5, e)
	elif cs.shape is ConvexPolygonShape3D:
		var pts := (cs.shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			return AABB()
		local = AABB(pts[0], Vector3.ZERO)
		for p in pts:
			local = local.expand(p)
	else:
		return AABB()     # (capsules, cylinders, spheres: trunks, posts, props: no cover)
	return xf * local


# --- The test key --------------------------------------------------------------------------------------------------

## Shift+F10 (the sky's dev keys are Shift+F6-F8): claimed in _input before the animation overlay's F-keys.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.shift_pressed and event.physical_keycode == KEY_F10:
		print(test_cycle())
		get_viewport().set_input_as_handled()


## The test cycle: a snowing January morning -> a clear winter day, the snow lying -> back as it was. Returns what it did.
func test_cycle() -> String:
	var core := _core()
	var dn := get_tree().get_first_node_in_group(&"weather")
	if core == null:
		force_depth_m = 0.3 if force_depth_m < 0.0 else -1.0
		return "snow test (no core): depth %.2f m" % maxf(force_depth_m, 0.0)
	_test_step = (_test_step + 1) % 3
	match _test_step:
		1:
			_test_saved = {"minutes": core.state.minutes, "depth": SurvivalWeather.snow_depth_cm(core)}
			var y := SurvivalClock.year(core)
			var jan := SurvivalClock.minutes_at(core, "jan_mid", y, 10.0)
			if jan < float(core.state.minutes):
				jan = SurvivalClock.minutes_at(core, "jan_mid", y + 1, 10.0)
			core.state.minutes = jan
			core.state.weather["snow_depth_cm"] = SurvivalWeather.normal_snow_depth(core)
			_last_core_cm = -1.0
			if dn and dn.has_method(&"force_weather"):
				dn.call(&"force_weather", "overcast")
				var w: Variant = dn.get("weather")
				if w:
					w.set("drizzle", true)
			return "snow test: a snowing January morning (%.0f cm on the ground)" % SurvivalWeather.snow_depth_cm(core)
		2:
			if dn and dn.has_method(&"force_weather"):
				dn.call(&"force_weather", "clear")
			return "snow test: a clear winter day, the snow lying"
		_:
			if not _test_saved.is_empty():
				core.state.minutes = float(_test_saved.minutes)
				core.state.weather["snow_depth_cm"] = float(_test_saved.depth)
			_test_saved = {}
			_last_core_cm = -1.0
			if dn and dn.has_method(&"force_weather"):
				dn.call(&"force_weather", "fair")
			return "snow test: back to %s" % SurvivalClock.date_string(core)
