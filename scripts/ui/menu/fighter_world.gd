class_name FighterWorld
extends Node
## The menus' live fighters (the broadcast menus, 2026-10-10): the player's own look, in an element's ring dress, standing in
## that element's stance, in a small 3D world of their own (one SubViewport that owns the World3D, a noon sun and a clear
## sky). Nothing of the ring is loaded: the lobby's deck and gates are a picture (assets/ui/menu/lobby_<element>.jpg, made
## by tools/ui_audit/lobby_backdrops.gd from the ring's own scene), and the fighter is drawn over it through a viewport of
## the same camera. Several views share the one world: the lobby's (kind "lobby", the whole frame), a fighter card's ("card",
## the whole body) and a scoreboard's ("head", the bust). Built lazily and deferred: a figure is dressed the first time an
## element is asked for (about a second of the player's dress), and kept while the menu stands.
##   var fw := FighterWorld.make(self)          # a node of the menu; never in a headless run (FighterWorld.available())
##   var v := fw.view("fire", "lobby", Vector2i(1600, 900))     # a SubViewport; show v.get_texture() in a TextureRect
##   fw.ensure("fire")                          # dress the figure now (view() does it too)
##   fw.figure_ready("fire") / signal built(el)
## The look is AppearanceStore's saved one (the owner's own character; a tool's `look_override` first), its name the
## character's name (fighter_name()).

signal built(element: String)

const ACTOR := "res://characters/Actor_B.tscn"
const IDLE := &"actor_b/actor_b-p-relax-idle"
const GRADE_LUT := preload("res://scripts/world/env/grade_lut.gd")
const GarmentChest := preload("res://scripts/customizer/garment_chest.gd")
## The distance (m) between two elements' stations in the world.
const GAP := 14.0
## The bust's camera: how far (m) from the head.
const HEAD_DIST := 2.0
## A card's camera (the whole body in a card 214 x 452 wide): the field of view, and the height (m) it looks at, which puts the head
## about 45 px under the card's top and the feet under the name (the approved mock-up's framing).
const CARD_FOV := 19.0
const CARD_AT_Y := 0.80
## The lobby's camera, relative to the fighter's feet (the ring's own lobby shot, tools/ui_audit/lobby_backdrops.gd): where it
## stands, what it looks at, its field of view; the fighter turns toward it, a little toward the menu.
const LOBBY_CAM := Vector3(4.4, 1.0, 0.0)
const LOBBY_AT := Vector3(0.0, 1.0, 0.78)
const LOBBY_FOV := 30.0
const LOBBY_TURN_DEG := -24.0
## The ring's own noon sun in the lobby's axes (x toward the camera, z to its left): where its light travels, how strong.
const SUN_TRAVELS := Vector3(-0.326, -0.842, -0.429)
## Tools: each build step's cost as it ran ([element, stage, ms]; stage -1 the actor's instance, 10 to 12 the warm-up ahead of the
## dress): read by tools/ui_audit/lobby_perf.gd.
static var step_log: Array = []
## Tools: a look to show instead of the saved one (the shots never carry the owner's own character's name).
static var look_override := {}

var host: SubViewport
## The one world the host and every view share (a World3D of its own: not the menu's, which has no 3D).
var world := World3D.new()
var _figs := {}
## The figures being built in steps (element -> its state): ensure_slowly.
var _building := {}
var _order: Array = []
var _sun: DirectionalLight3D
## The light's strengths (the lobby's tuning; a tool may change them before the first figure).
var sun_energy := 2.6
var sky_ambient := 0.62
var fill_energy := 0.55
var exposure := 0.95
var _look := {}
## The look's materials made once ahead of the first dress (_warm): held so their textures stay loaded.
var _warm_mats: Array = []


## True where the fighters can be drawn (a window): not in a headless run.
static func available() -> bool:
	return DisplayServer.get_name() != "headless"


## The files the first figure's dress would otherwise load in one frame, cold (the actor about 0.45 s, the body and the garments
## about 0.6 s: the lobby froze for over a second just after it appeared): the actor, the body, the skin's textures, the look's
## hair and the garments of the four ring dresses on the saved look's body. Asked of the resource loader's threads as the menu
## opens (preload_assets), taken when the figure is first built (assets_ready), so the build finds them cached.
static var _asked := {}


static func asset_paths() -> Array:
	var out: Array = [ACTOR, BodyMaterials.BODY_GLB]
	var lk: Dictionary = look_override if not look_override.is_empty() else AppearanceStore.load_current()
	var sex := float(lk.get("sex", 0.0))
	# the skin's textures and the look's hair (the skin material made cold was about 0.09 s of a frame)
	for p: String in [BodyMaterials.HEAD_DETAIL, BodyMaterials.BODY_DETAIL, BodyMaterials.PAINT_HEAD, BodyMaterials.PAINT_LINES,
			BodyMaterials.BODY_HAIR_MASK, BodyMaterials.HAIR_ATLAS]:
		out.append(p)
	var hair: Variant = lk.get("hair")
	if hair is Dictionary and String((hair as Dictionary).get("style", "")) != "":
		out.append(BodyMaterials.HAIR_DIR + String((hair as Dictionary).style) + ".glb")
	for el: String in Bending.ELEMENTS:
		var outfit := PlayerAppearance.arena_outfit(el, sex)
		for slot: String in outfit:
			var id := String((outfit[slot] as Dictionary).get("id", "-"))
			if id != "-" and id != "":
				var glb := String(PlayerOutfit.entry(id).get("glb", ""))
				if glb != "" and not glb in out:
					out.append(glb)
	return out


## The actor's scene, kept for the run (a menu that comes after a match finds it loaded: 0.45 s the first time).
static var _actor_scene: PackedScene


static func _actor() -> PackedScene:
	if _actor_scene == null:
		var got: Variant = _asked.get(ACTOR)
		_actor_scene = got as PackedScene if got is PackedScene else load(ACTOR) as PackedScene
	return _actor_scene


## The loads asked of the resource loader's own threads (the main thread stays free); once.
static func preload_assets() -> void:
	if not available() or not _asked.is_empty():
		return
	for p: String in asset_paths():
		if ResourceLoader.exists(p):
			_asked[p] = null
			ResourceLoader.load_threaded_request(p, "", true)


## Whether every file asked for is there (or failed: then the build loads it itself); the loaded ones are kept in the cache here.
static func assets_ready() -> bool:
	var all := true
	for p: String in _asked:
		if _asked[p] != null:
			continue
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			all = false
		elif st == ResourceLoader.THREAD_LOAD_LOADED:
			_asked[p] = ResourceLoader.load_threaded_get(p)
		else:
			_asked[p] = false
	return all


static func make(parent: Node, tune := {}) -> FighterWorld:
	var fw := FighterWorld.new()
	fw.name = "FighterWorld"
	for k: String in tune:
		fw.set(k, tune[k])
	parent.add_child(fw)
	return fw


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host = SubViewport.new()
	host.name = "Host"
	host.size = Vector2i(2, 2)
	host.own_world_3d = false
	host.world_3d = world
	host.transparent_bg = true
	host.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(host)
	_build_light()


## The saved look (or a tool's), validated; the character's own.
func look() -> Dictionary:
	if _look.is_empty():
		_look = look_override.duplicate(true) if not look_override.is_empty() else AppearanceStore.load_current()
	return _look


## The look changed (the creator accepted a new one): every figure is dressed again as it is next asked for.
func refresh() -> void:
	_look = {}
	_warm_mats = []
	for el: String in _building.keys():
		var b: Dictionary = _building[el]
		b["dead"] = true
		(b.pivot as Node3D).queue_free()
	_building.clear()
	for el: String in _figs.keys():
		var f: Dictionary = _figs[el]
		(f.pivot as Node3D).queue_free()
		_figs.erase(el)
		_order.erase(el)


## The character's name for the screens: the look's own, else "You".
static func fighter_name(lk: Dictionary = {}) -> String:
	var l := lk if not lk.is_empty() else (look_override if not look_override.is_empty() else AppearanceStore.load_current())
	var n := String(l.get("name", "")).strip_edges()
	return n if n != "" else "You"


func figure_ready(el: String) -> bool:
	return _figs.has(el)


func station(el: String) -> Vector3:
	var i := Bending.ELEMENTS.find(el)
	return Vector3(float(maxi(i, 0)) * GAP, 0.0, 0.0)


# ------------------------------------------------------------------------------------------------ the world
func _build_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.52, 0.74)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.88)
	sky_mat.ground_horizon_color = Color(0.5, 0.5, 0.5)
	sky_mat.ground_bottom_color = Color(0.3, 0.3, 0.32)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = sky_ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = exposure
	env.tonemap_agx_contrast = 1.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.02
	env.adjustment_color_correction = GRADE_LUT.texture()
	world.environment = env
	# the noon sun: high, from the camera's left and a little behind it (the ring's own noon light at the lobby's camera)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color(1.0, 0.97, 0.9)
	_sun.light_energy = sun_energy
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.2
	_sun.directional_shadow_max_distance = 14.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	host.add_child(_sun)
	_sun.look_at_from_position(Vector3.ZERO, SUN_TRAVELS)
	# a cool fill from the right so the shadow side keeps its shape
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = fill_energy
	host.add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.3, -0.3, 0.9))


## The figure for `el`, dressed (once): its station, the blob of shadow under it, the stance. All in this frame (a figure that is
## wanted now); ensure_slowly() builds the same one over a few frames.
func ensure(el: String) -> bool:
	if _figs.has(el):
		return true
	var s: Dictionary = _building.get(el, {})
	if s.is_empty():
		s = _stage_open(el)
		if s.is_empty():
			return false
		_building[el] = s
	while int(s.stage) < 3:
		_step(s)
	return _figs.has(el)


## The same figure built in steps, a frame apart (the actor, the body, the dress, the stance): a figure that is not wanted yet (the
## other three elements' behind the lobby) costs a frame about 15 ms, not 80. Called again or ensure()d meanwhile, it is the same build.
func ensure_slowly(el: String) -> void:
	if _figs.has(el) or _building.has(el):
		return
	var s := _stage_open(el)
	if s.is_empty():
		return
	_building[el] = s
	while int(s.stage) < 3:
		await get_tree().process_frame
		if not is_inside_tree() or s.get("dead", false) or _building.get(el) != s:
			return
		if int(s.stage) == 1 and not _warm(s):
			continue
		_step(s)


## Whether a figure is being built in steps now.
func building() -> bool:
	return not _building.is_empty()


## What the dress would do cold in its one frame, done ahead a piece a frame (the first figure's dress was about 0.55 s in one frame:
## the cloth's chest search over the body 0.35 s, the skin's textures 0.08 s, the chest garment's smoothing): the chest search a
## slice a frame (GarmentChest.warm_step), then this dress's chest garments smoothed, then the look's skin, eye and face-hair
## materials made once (their textures loaded and kept while the menu stands). true when the dress may run.
func _warm(s: Dictionary) -> bool:
	var w := int(s.get("warm", 0))
	var t0 := Time.get_ticks_usec()
	if w < 3:
		step_log.append([String(s.el), 10 + w, 0.0])
	match w:
		0:
			if not GarmentChest.warm_step():
				return false
		1:
			PlayerOutfit.warm_chest(PlayerAppearance.arena_outfit(String(s.el), float(look().get("sex", 0.0))), float(look().get("sex", 0.0)))
		2:
			if _warm_mats.is_empty():
				_warm_mats = [BodyMaterials.skin_material(look()), BodyMaterials.eye_material(look()), BodyMaterials.face_hair_material(look())]
		_:
			return true
	(step_log.back() as Array)[2] = (Time.get_ticks_usec() - t0) / 1000.0
	s["warm"] = w + 1
	return false


## The first step: the figure's pivot at its station and the actor under it. {} when it cannot be (no window, no actor).
func _stage_open(el: String) -> Dictionary:
	if not available() or not el in Bending.ELEMENTS or not ResourceLoader.exists(ACTOR):
		return {}
	var pivot := Node3D.new()
	pivot.name = "Fighter_" + el
	pivot.position = station(el)
	host.add_child(pivot)
	var t0 := Time.get_ticks_usec()
	var inst := _actor().instantiate() as Node3D
	pivot.add_child(inst)
	step_log.append([el, -1, (Time.get_ticks_usec() - t0) / 1000.0])
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		pivot.queue_free()
		return {}
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	return {"el": el, "pivot": pivot, "inst": inst, "skeleton": sks[0], "ap": aps[0] if not aps.is_empty() else null, "stage": 0}


func _step(s: Dictionary) -> void:
	var el := String(s.el)
	var t0 := Time.get_ticks_usec()
	match int(s.stage):
		0:
			s["body"] = CharacterBodyMesh.attach(s.skeleton as Skeleton3D, s.ap as AnimationPlayer)
			BindRest.ensure_character(s.inst as Node3D)
		1:
			var lk := look().duplicate(true)
			lk["outfit"] = PlayerAppearance.arena_outfit(el, float(lk.get("sex", 0.0)))
			if s.body != null:
				PlayerAppearance.dress(s.body as CharacterBodyMesh, lk)
		2:
			_finish(s)
	step_log.append([el, int(s.stage), (Time.get_ticks_usec() - t0) / 1000.0])
	s["stage"] = int(s.stage) + 1


## The last step: the blink, the element's own stance (looped; poses.json "stance"; the plain idle when a clip is not there), the soft
## blob of shadow under the feet (the ring's own: a dark ellipse, no hard edge); the figure is then there.
func _finish(s: Dictionary) -> void:
	var el := String(s.el)
	var pivot := s.pivot as Node3D
	var ap := s.ap as AnimationPlayer
	var blink := FaceBlink.new()
	blink.name = "FaceBlink"
	blink.body = s.body
	pivot.add_child(blink)
	var clip := IDLE
	if ap != null:
		var nm := SwayPose.stance_name(el)
		var a := BendPoses.animation(nm) if nm != "" else null
		if a != null:
			a = a.duplicate() as Animation
			a.loop_mode = Animation.LOOP_LINEAR
			var lib := AnimationLibrary.new()
			lib.add_animation(&"stance", a)
			ap.add_animation_library(&"lobby", lib)
			clip = &"lobby/stance"
		if ap.has_animation(clip):
			ap.play(clip)
			ap.advance(0.01)
		elif ap.has_animation(IDLE):
			ap.play(IDLE)
	pivot.add_child(_blob())
	_turn(pivot, LOBBY_TURN_DEG)
	_figs[el] = {"pivot": pivot, "skeleton": s.skeleton, "body": s.body, "ap": ap}
	_order.append(el)
	_building.erase(el)
	built.emit(el)


## The figure turned for a kind of view (the lobby's: toward its camera, a little toward the menu; a card's: three quarters).
func face(el: String, kind: String) -> void:
	if not _figs.has(el):
		return
	var pivot := _figs[el].pivot as Node3D
	if kind == "lobby":
		_turn(pivot, LOBBY_TURN_DEG)
	else:
		var cam := _view_pos(kind)
		pivot.rotation.y = atan2(cam.x, cam.z) + deg_to_rad(-12.0)


func _turn(pivot: Node3D, deg: float) -> void:
	var to_cam := LOBBY_CAM.normalized().rotated(Vector3.UP, deg_to_rad(deg))
	pivot.rotation.y = atan2(to_cam.x, to_cam.z)


func _blob() -> MeshInstance3D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = t
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := PlaneMesh.new()
	q.size = Vector2(1.7, 1.2)
	var mi := MeshInstance3D.new()
	mi.name = "Blob"
	mi.mesh = q
	mi.material_override = m
	mi.position = Vector3(0.0, 0.01, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------------------------------------ the views
## A SubViewport of `px` over the shared world with its own camera on `el`'s station: "lobby" the ring's lobby shot (the whole
## frame, `px` 16:9), "card" the whole body, "head" the bust. Transparent behind the fighter. The figure is dressed first.
func view(el: String, kind: String, px: Vector2i) -> SubViewport:
	ensure(el)
	if kind != "lobby":
		face(el, kind)                       # (turned first: the bust's camera is aimed at where the head is then)
	var v := SubViewport.new()
	v.name = "View_%s_%s" % [el, kind]
	v.size = px
	v.own_world_3d = false
	v.world_3d = world
	v.transparent_bg = true
	# (video memory: the lobby's view is drawn at its own size, so 2X with FXAA over it (4X took about 100 MB more); a card's and a
	# bust's is drawn twice as big as it is shown, so no AA at all)
	if kind == "lobby":
		v.msaa_3d = Viewport.MSAA_2X
		v.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	v.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	v.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var cam := Camera3D.new()
	cam.name = "Camera"
	v.add_child(cam)
	_aim(cam, el, kind)
	cam.current = true
	return v


## Where a kind's camera stands, relative to the figure's feet.
func _view_pos(kind: String) -> Vector3:
	match kind:
		"card":
			return Vector3(0.9, 1.1, 5.6)
		"head":
			return Vector3(0.7, 1.62, 3.0)
	return LOBBY_CAM


## The head's place in the world for `el`'s figure (its "heada" bone, a little above it), else a standing man's.
func _head_at(el: String) -> Vector3:
	var f: Dictionary = _figs.get(el, {})
	var sk := f.get("skeleton") as Skeleton3D
	if sk != null and sk.is_inside_tree():
		var i := sk.find_bone("heada")
		if i >= 0:
			return (sk.global_transform * sk.get_bone_global_pose(i)).origin + Vector3(0.0, 0.07, 0.0)
	return station(el) + Vector3(0.0, 1.6, 0.0)


func _aim(cam: Camera3D, el: String, kind: String) -> void:
	var p := station(el)
	match kind:
		"card":
			cam.fov = CARD_FOV
			cam.look_at_from_position(p + _view_pos(kind), p + Vector3(0.0, CARD_AT_Y, 0.0))
		"head":
			# the bust: the camera looks at where the head is in this element's stance (an earth stance sits lower than an air one)
			cam.fov = 18.0
			var at := _head_at(el)
			var dir := Vector3(_view_pos(kind).x, 0.0, _view_pos(kind).z).normalized()
			cam.look_at_from_position(at + dir * HEAD_DIST + Vector3(0.0, 0.04, 0.0), at)
		_:
			cam.fov = LOBBY_FOV
			cam.look_at_from_position(p + LOBBY_CAM, p + LOBBY_AT)
