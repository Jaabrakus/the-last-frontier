class_name ClassicPortrait
extends Control
## The round portrait in a brass ring (the player frame's; the target frame draws its own glyph in one).
## The player's face is a picture taken ONCE of a stand-in of him: his look (PlayerAppearance) on a copy of the body in a
## little studio of its own (own world, a warm key light, a cool fill, a rim), one frame rendered, read back into a small
## ImageTexture and the studio freed, so it costs nothing after. Taken again only when the look changes (look_changed, a
## moment after: a garment put on, the creator's accept). Headless, or before the picture comes, a stand-in is drawn: a
## head and shoulders in the leather's dark over a lit ground.
##   bake(player)     takes the picture (async; safe to call again: the last call wins)
##   texture          the picture (null: the stand-in)
##   hurt             0..1: the ring glows red (a blow just taken), set by the player frame

const SIZE := 160
const IDLE_CLIP := "actor_b-p-stealth-idle"
const HEAD_BONES := ["headb", "heada", "head"]
const REBAKE_S := 0.8

var texture: Texture2D
var hurt := 0.0
## The look last pictured (its string), so the same look is not pictured twice.
var baked_look := ""
var _serial := 0
var _disc: Array = []
var _disc_size := Vector2.ZERO
var _rebake_t := -1.0
var _player: Node


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Follows the player's look: pictured a little after the level starts, again when it changes.
func follow(p: Node) -> void:
	_player = p
	var app: Variant = p.get("appearance") if p != null else null
	if app is PlayerAppearance and not (app as PlayerAppearance).look_changed.is_connected(_on_look):
		(app as PlayerAppearance).look_changed.connect(_on_look)
	_rebake_t = 1.2           # (after the level's first frames: its loading, the character creator's offer)


func _on_look(_lk: Dictionary) -> void:
	_rebake_t = REBAKE_S


func _process(delta: float) -> void:
	if _rebake_t >= 0.0:
		_rebake_t -= delta
		if _rebake_t < 0.0 and _player != null and is_instance_valid(_player):
			bake(_player)


func bake(p: Node) -> void:
	var app: Variant = p.get("appearance") if p != null else null
	if not (app is PlayerAppearance) or DisplayServer.get_name() == "headless":
		return
	var lk: Dictionary = (app as PlayerAppearance).look
	var key := str(lk).md5_text()
	if key == baked_look and texture != null:
		return
	_serial += 1
	var serial := _serial
	var vp := SubViewport.new()
	vp.name = "PortraitStudio"
	vp.own_world_3d = true
	vp.size = Vector2i(SIZE, SIZE)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var studio := Node3D.new()
	vp.add_child(studio)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.15, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.54, 0.48)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	studio.add_child(env)
	for l: Array in [[Vector3(-0.6, -0.5, -1.0), Color(1.0, 0.9, 0.76), 1.5], [Vector3(0.9, -0.15, -0.6), Color(0.7, 0.8, 1.0), 0.45],
			[Vector3(0.2, -0.4, 1.0), Color(1.0, 0.92, 0.8), 1.2]]:
		var dl := DirectionalLight3D.new()
		dl.basis = Basis.looking_at((l[0] as Vector3).normalized(), Vector3.UP)
		dl.light_color = l[1]
		dl.light_energy = l[2]
		studio.add_child(dl)
	var scene := load(FrontierPlayer.CHARACTER_SCENE) as PackedScene
	if scene == null:
		vp.queue_free()
		return
	var inst := scene.instantiate() as Node3D
	studio.add_child(inst)
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty():
		vp.queue_free()
		return
	var sk := sks[0] as Skeleton3D
	var ap := aps[0] as AnimationPlayer if not aps.is_empty() else null
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach(sk, ap)
	if body != null:
		PlayerAppearance.dress(body, lk)
	var poser := LoadoutClipPoser.new(sk, ap) if ap != null else null
	if poser != null and poser.has_clip(IDLE_CLIP):
		poser.pose([[IDLE_CLIP, 0.4]])
	# (the dress and the pose settle over a frame or two)
	for i in 3:
		await get_tree().process_frame
	if serial != _serial or not is_instance_valid(vp):
		if is_instance_valid(vp):
			vp.queue_free()
		return
	var head := Vector3(0, 1.62, 0)
	for b: String in HEAD_BONES:
		var bi := sk.find_bone(b)
		if bi >= 0:
			head = sk.global_transform * sk.get_bone_global_pose(bi).origin
			break
	var cam := Camera3D.new()
	cam.fov = 24.0
	studio.add_child(cam)
	# (the rig faces +Z: the camera before the face, a little to its left and above, looking at the face)
	var aim := head + Vector3(0.0, 0.035, 0.03)
	cam.global_position = aim + Vector3(0.15, 0.04, 0.95)
	cam.look_at(aim, Vector3.UP)
	cam.current = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if serial != _serial or not is_instance_valid(vp):
		if is_instance_valid(vp):
			vp.queue_free()
		return
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return
	img.generate_mipmaps()
	texture = ImageTexture.create_from_image(img)
	baked_look = key
	queue_redraw()


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var rad := minf(s.x, s.y) * 0.5 - 4.0
	if _disc.is_empty() or _disc_size != s:
		_disc = ClassicSkin.disc(c, rad - 1.0, 48)
		_disc_size = s
	draw_circle(c + Vector2(1, 2), rad + 3.0, Color(0, 0, 0, 0.4))
	if texture != null:
		draw_colored_polygon(_disc[0], Color.WHITE, _disc[1], texture)
	else:
		stand_in(self, c, rad - 1.0)
	# the inner shadow round the picture's edge
	draw_arc(c, rad - 2.5, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 4.0, true)
	ClassicSkin.ring(self, c, rad, 5.0)
	if hurt > 0.01:
		draw_arc(c, rad + 1.0, 0.0, TAU, 64, Color(1.0, 0.18, 0.1, 0.75 * hurt), 3.0, true)
		draw_arc(c, rad + 3.5, 0.0, TAU, 64, Color(1.0, 0.18, 0.1, 0.3 * hurt), 3.0, true)


## The stand-in: a lit ground and a head and shoulders in the leather's dark.
static func stand_in(ci: CanvasItem, c: Vector2, rad: float) -> void:
	ci.draw_circle(c, rad, Color(0.32, 0.24, 0.16))
	ci.draw_circle(c + Vector2(-rad * 0.2, -rad * 0.25), rad * 0.7, Color(0.42, 0.32, 0.21, 0.6))
	var ink := Color(0.08, 0.055, 0.035, 0.92)
	ci.draw_circle(c + Vector2(0, -rad * 0.2), rad * 0.34, ink)
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		pts.append(c + Vector2(cos(a) * rad * 0.6, rad * 0.78 + sin(a) * rad * 0.52))
	ci.draw_colored_polygon(pts, ink)
