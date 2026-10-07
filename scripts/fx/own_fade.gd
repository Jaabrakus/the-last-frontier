class_name OwnFade
extends Node
## Your own wall never fills your view (round 4 LOOKS; data/bending/fx_looks.json own_wall): a raised thing of yours (an
## earth or ice wall, a pillar: FormRaised; a fire, wind or water wall: BendZone's look) that stands between the camera
## and your head or your chest (it hides you), or within near_m of the camera, is drawn at `alpha` in a screen-door (its
## shaders' instance uniform `param`: form_matter's "fade", the effects' "own_fade"), easing there and back at `speed` a
## second. It is a look only:
## it still stops shots, bodies and the bots' sight. A piece in front of you (between you and the opponent) is cover and
## stays whole. Everyone else's walls, and yours seen by anyone else, are unchanged.
##   OwnFade.attach(frame, targets, box, param, owner)   frame: the thing's Node3D; box: its shape in frame's local space;
##                                                       owner: its owner, or null to read frame's meta bend_by
## blocks_view(cam, head, xf, box, near_m): the test it makes (static, for the tests).

var frame: Node3D
var owner_body: Node3D
var targets: Array[GeometryInstance3D] = []
var box := AABB()
var param := &"own_fade"
## The fade it is drawn at now (1 whole) and the one it eases to.
var fade := 1.0
var want := 1.0
var _alpha := 0.35
var _near_m := 2.5
var _speed := 5.0


static func attach(p_frame: Node3D, p_targets: Array, p_box: AABB, p_param: StringName, p_owner: Node3D = null) -> OwnFade:
	var f := OwnFade.new()
	f.name = "OwnFade"
	f.frame = p_frame
	f.owner_body = p_owner
	for t in p_targets:
		if t is GeometryInstance3D:
			f.targets.append(t)
	f.box = p_box
	f.param = p_param
	var d := ToonFx.looks("own_wall")
	f._alpha = float(d.get("alpha", 0.35))
	f._near_m = float(d.get("near_m", 2.5))
	f._speed = float(d.get("speed", 5.0))
	p_frame.add_child(f)
	return f


## Whether a thing whose shape is `bx` in the space of `xf` stands between the camera at `cam` and the head at `head`, or
## within `near_m` of the camera.
static func blocks_view(cam: Vector3, head: Vector3, xf: Transform3D, bx: AABB, near_m: float) -> bool:
	var inv := xf.affine_inverse()
	var a := inv * cam
	var b := inv * head
	if bx.intersects_segment(a, b) or bx.has_point(a):
		return true
	var c := Vector3(clampf(a.x, bx.position.x, bx.end.x), clampf(a.y, bx.position.y, bx.end.y), clampf(a.z, bx.position.z, bx.end.z))
	return (xf * c).distance_to(cam) < near_m


func _owner() -> Node3D:
	if owner_body != null and is_instance_valid(owner_body):
		return owner_body
	if frame != null and frame.has_meta(&"bend_by"):
		return instance_from_id(int(frame.get_meta(&"bend_by"))) as Node3D
	return null


func _process(dt: float) -> void:
	if frame == null or not is_instance_valid(frame) or not frame.is_inside_tree():
		return
	want = 1.0
	var body := _owner()
	if ToonFx.is_own(body):
		var cam := frame.get_viewport().get_camera_3d()
		if cam != null:
			var cp := cam.global_position
			var xf := frame.global_transform
			if blocks_view(cp, NpcSenses.head_of(body), xf, box, _near_m) \
					or blocks_view(cp, NpcSenses.chest_of(body), xf, box, _near_m):
				want = _alpha
	var was := fade
	fade = move_toward(fade, want, dt * _speed)
	if not is_equal_approx(was, fade):
		for t in targets:
			if is_instance_valid(t):
				t.set_instance_shader_parameter(param, fade)
