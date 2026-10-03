class_name FormCast
extends Node
## The Form art on a SwayCaster (its child; SwayCaster.form): the stone-shapers' circle-work (docs/main_story.md section 11,
## the Sway's fifth art, 11.10; data/sway/moves.json, art "form"; user 2026-10-02: "if we equip full metal alchemist type
## spells and animations that would be great": our own, no one else's names or signs). A Form move locks only readied
## (SwayCaster.ready_spell: the hotbar's spell slot), with the hands the caster's mastery of it asks (SwayCaster.hands_rule).
##
##   the target  pick(): the earth under the crosshair for the ground moves (a fixed body facing up, not a built floor; a
##               person or a thing the crosshair is on stands for the ground under it); the pillar by its mode: "self" the
##               caster's own feet wherever the aim is (where they will land, in the air), "free" the aimed circle; a built
##               piece, a fire's ruin or a worn raised wall for mend (with a stage to mend and the wood for it in the pack).
##               (A stone to lift and hurl is Gust's now, not Form's: GustLift.) The ground moves lock on `mark` (a point that
##               stays where the circle is drawn; under the caster for the pillar's self mode, following them); mend on the
##               thing itself. Reach is flat from the feet (SwayCaster.reach_to). on_target(): the crosshair still in the
##               circle (always, for the pillar's self mode)
##   the cast    lock_started: the circle (FormCircle) comes up at the target and draws itself as the lock fills; the crackle
##               (FormCrackle) runs from the palms (SwayPose: the body's clip by mastery) to it from half. locked: the circle
##               flashes and pulses. cast: the circle swells out, a burst of crackle; the
##               effect is FormEffects' (SwayEffects.apply hands it on). A lock broken or fizzled: the circle dims out

const WALL_NORMAL_Y := 0.55
## The crosshair this much past the circle's radius still counts as in it.
const ON_SLACK := 1.35
## The earth: a surface facing up at least this much (its normal's y).
const GROUND_MIN_Y := 0.6
const HINTS := {"no earth": "No earth to raise there", "steep": "Too steep to raise earth there", "whole": "Nothing to mend there",
		"wood": "No wood in the pack to mend with"}

var caster: SwayCaster
var circle: FormCircle
var crackle: FormCrackle
## The ground moves' lock target: where the circle is (a point under the player, top_level).
var mark: Node3D
## The circle (world): its centre, its up, its radius; on an upright (the wall clip).
var at := Vector3.ZERO
var up := Vector3.UP
var radius := 1.0
var on_wall := false
var move := ""
## The last pick (what the next lock begins with) and the last hint.
var last_pick := {}
var hint := ""
## The lock is the pillar's self mode (the circle under the caster, following them).
var self_cast := false

var _hinted := ""


static func is_form(m: String) -> bool:
	return m != "" and String(SwayMoves.move(m).get("art", "")) == "form"


func _ready() -> void:
	if caster == null:
		caster = get_parent() as SwayCaster
	if caster == null:
		return
	caster.lock_started.connect(_on_started)
	caster.locked.connect(_on_locked)
	caster.cast.connect(_on_cast)
	caster.hold_started.connect(func(m: String, _t: Node3D) -> void: _swell(m))
	caster.lock_broken.connect(func(_m: String, _t: Node3D, _why: String) -> void: _on_end("break"))
	caster.fizzled.connect(func(_m: String, _t: Node3D) -> void: _on_end("fizzle"))
	mark = Node3D.new()
	mark.name = "FormMark"
	mark.top_level = true
	mark.set_meta(&"sway_tag", "ground")
	add_child.call_deferred(mark)


## The palms (SwayPose's, the clip's pose), else the casting hand.
func palms() -> Vector3:
	if caster.pose != null and caster.pose.palms != Vector3.INF and caster.pose.posing():
		return caster.pose.palms
	return caster.hand_point()


# ---------------------------------------------------------------- the target
## What a lock of `m` would take from the crosshair's query `q` (SwayCaster._query): {node, point, normal} (node null and a
## "hint" when nothing here takes it). Kept in last_pick for the lock's begin.
func pick(m: String, q: Dictionary) -> Dictionary:
	var out := _pick(m, q)
	last_pick = out
	hint = String(out.get("hint", ""))
	if hint != "" and hint != _hinted and caster.player.interactor != null and caster.player.is_local and HINTS.has(hint):
		caster.player.interactor.notice(String(HINTS[hint]), 1.5)
	_hinted = hint
	return out


var _land_at := Vector3.ZERO
var _land_frame := -1


## The pillar's self mode: its circle under the caster (where they will land, in the air: FormEffects.landing_point's march
## of rays, once a physics frame).
func self_point() -> Vector3:
	var p := caster.player
	if not p.is_on_floor():
		var f := Engine.get_physics_frames()
		if f != _land_frame:
			_land_frame = f
			_land_at = FormEffects.landing_point(caster)
		return _land_at
	var g := _down(p.global_position + Vector3.UP * 0.4)
	return g.position if not g.is_empty() else FormEffects.ground_at(caster, p.global_position)


func _pick(m: String, q: Dictionary) -> Dictionary:
	var d := SwayMoves.move(m)
	var targets: Array = d.get("targets", [])
	if m == "pillar" and caster.mode_of(m) == "self":
		var sp := self_point()
		mark.global_transform = Transform3D(Basis.IDENTITY, sp)
		return {"node": mark, "point": sp, "normal": Vector3.UP, "ground": true, "self": true}
	if not q.has("from"):
		return {}
	var h := _ray(q, caster.range_of(m) + caster.player.cam_distance_now() + 2.0)
	if h.is_empty():
		return {}
	var col := h.collider as Object
	var point: Vector3 = h.position
	var n: Vector3 = h.normal
	if "ground" in targets:
		if not _fixed(col):
			var g := _down(point + Vector3.UP * 0.3)
			if g.is_empty():
				return {"hint": "no earth"}
			col = g.collider
			point = g.position
			n = g.normal
		if not earth(col):
			return {"hint": "no earth"}
		if n.y < GROUND_MIN_Y:
			return {"hint": "steep"}
		# (the mark set where the circle will be now: the lock's point is taken in its frame as it begins)
		mark.global_transform = Transform3D(FormCircle.basis_on(n), point)
		return {"node": mark, "point": point, "normal": n, "ground": true}
	if "built" in targets:
		var t := _built(col, point)
		if t == null:
			return {"hint": "whole"}
		var stage := FormEffects.mend_stage(t)
		if stage == "":
			return {"hint": "whole"}
		var need := FormEffects.wood_need(stage, d)
		if need > 0 and FormEffects.wood_kind(caster.player, (d.get("wood", {}) as Dictionary).get("kinds", ["log"]), need) == "":
			return {"hint": "wood"}
		if t is FireRuin:
			var g3 := _down(point + Vector3.UP * 0.3)
			if not g3.is_empty():
				point = g3.position
			n = Vector3.UP
		return {"node": t, "point": point, "normal": n, "stage": stage}
	return {}


## The first thing the crosshair's ray meets (not the player): {position, normal, collider, rid} or {}.
func _ray(q: Dictionary, reach: float) -> Dictionary:
	var from: Vector3 = q.from
	var dir: Vector3 = q.dir
	var p := caster.player
	var r := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	r.exclude = [p.get_rid()]
	return p.get_world_3d().direct_space_state.intersect_ray(r)


## The ground straight under `p`: {position, normal, collider} or {} (through people, loose things and raised earth).
func _down(p: Vector3) -> Dictionary:
	var space := caster.player.get_world_3d().direct_space_state
	var ex: Array[RID] = [caster.player.get_rid()]
	for i in 6:
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 5.0, 1, ex))
		if h.is_empty():
			return {}
		if _fixed(h.collider):
			return h
		ex.append(h.rid)
	return {}


static func _fixed(c: Object) -> bool:
	return c is StaticBody3D and not (c is AnimatableBody3D) or c is CSGShape3D or c is GridMap


## Whether `c` is earth to raise (the terrain, a rock, the ground: a fixed body; not a built floor, not raised earth).
static func earth(c: Object) -> bool:
	if not _fixed(c):
		return false
	var n := c as Node
	if n != null and (n.is_in_group(BuiltPiece.BODY_GROUP) or n.get_parent() is BuiltPiece):
		return false
	return true


## The mend target behind `col` at `point`: a built piece (its body), a raised wall or pillar, or a fire's ruin where the
## crosshair meets the ground (ruins have no colliders).
func _built(col: Object, point: Vector3) -> Node3D:
	var n := col as Node
	if n is FormRaised:
		return n as Node3D
	while n != null:
		if n is BuiltPiece:
			return n as Node3D
		n = n.get_parent()
	var fs := FireSpread.find(get_tree())
	if fs == null:
		return null
	var best: FireRuin = null
	var bd := INF
	for r in fs.ruins:
		if not is_instance_valid(r) or r.in_place != null:
			continue
		var b: Array = r.data.get("box", [])
		if b.size() != 2:
			continue
		var box := AABB(SaveParts.to_v3(b[0]), SaveParts.to_v3(b[1])).grow(0.6)
		var c := box.get_center()
		if Rect2(box.position.x, box.position.z, box.size.x, box.size.z).has_point(Vector2(point.x, point.z)):
			var dd := Vector2(c.x - point.x, c.z - point.z).length()
			if dd < bd:
				bd = dd
				best = r
	return best


## The crosshair still in the circle (its ray meets something within the circle's radius, ON_SLACK over), or on the thing
## locked; always for the pillar's self mode (the circle is under the caster).
func on_target(q: Dictionary) -> bool:
	if self_cast:
		return true
	if not q.has("from"):
		return false
	var h := _ray(q, 30.0)
	if h.is_empty():
		return false
	# (in the circle's plane: the crosshair on someone standing in it, or on the stone it is drawn round, still counts)
	var v: Vector3 = (h.position as Vector3) - at
	var off_plane := v.dot(up)
	if (v - up * off_plane).length() <= radius * ON_SLACK and off_plane > -0.5 and off_plane < 2.4:
		return true
	var t := caster.target
	if t != null and t != mark and is_instance_valid(t):
		var n := h.collider as Node
		while n != null:
			if n == t:
				return true
			n = n.get_parent()
	return false


# ---------------------------------------------------------------- the lock
func _on_started(m: String, t: Node3D) -> void:
	if not is_form(m):
		on_wall = false
		return
	move = m
	var d := SwayMoves.move(m)
	radius = float(d.get("circle_m", 1.0))
	var pk := last_pick
	self_cast = bool(pk.get("self", false))
	var point: Vector3 = pk.get("point", t.global_position)
	up = pk.get("normal", Vector3.UP)
	at = pk.get("circle_at", point)
	if pk.has("circle_at"):
		up = Vector3.UP
	on_wall = up.y < WALL_NORMAL_Y
	_clear_fx()
	var scn := get_tree().current_scene
	circle = FormCircle.make(scn, at, up, radius, SwayMoves.art_color("form"))
	crackle = FormCrackle.new()
	crackle.name = "FormCrackle"
	crackle.color = SwayMoves.art_color("form").lerp(Color.WHITE, 0.2)
	crackle.center = circle.global_position
	crackle.up = up
	crackle.radius = radius
	scn.add_child(crackle)


func _on_locked(m: String, _t: Node3D) -> void:
	if not is_form(m) or circle == null or not is_instance_valid(circle):
		return
	circle.full = true
	circle.fill = 1.0
	circle.flash()


func _on_cast(m: String, _t: Node3D) -> void:
	if is_form(m):
		_swell(m)
	self_cast = false


## The cast (or a hold begun): the circle swells out, a burst of crackle.
func _swell(m: String) -> void:
	if not is_form(m):
		return
	if circle != null and is_instance_valid(circle):
		circle.fill = 1.0
		circle.end("cast")
	if crackle != null and is_instance_valid(crackle):
		crackle.level = 0.0
		crackle.from = palms()
		crackle.burst()
		_free_later(crackle, FormCrackle.BURST_S + 0.4)
	FormEffects.sfx("crackle", at, -6.0, 1.6)
	circle = null
	crackle = null


func _on_end(kind: String) -> void:
	self_cast = false
	if circle != null and is_instance_valid(circle):
		circle.end(kind)
	if crackle != null and is_instance_valid(crackle):
		crackle.queue_free()
	circle = null
	crackle = null


func _clear_fx() -> void:
	if circle != null and is_instance_valid(circle):
		circle.end("break")
	if crackle != null and is_instance_valid(crackle):
		crackle.queue_free()
	circle = null
	crackle = null


func _free_later(n: Node, secs: float) -> void:
	await get_tree().create_timer(secs).timeout
	if is_instance_valid(n):
		n.queue_free()


func _process(_dt: float) -> void:
	if caster == null or caster.player == null or not is_instance_valid(caster.player):
		return
	var locking := caster.state in [SwayCaster.State.LOCKING, SwayCaster.State.FULL] and is_form(caster.move)
	if locking and self_cast:
		# (the self pillar's circle under the caster as they move: where they will land, in the air)
		var sp := self_point()
		mark.global_position = sp
		at = sp
		if circle != null and is_instance_valid(circle):
			circle.global_position = sp + Vector3.UP * 0.025
		if crackle != null and is_instance_valid(crackle):
			crackle.center = sp
	if circle != null and is_instance_valid(circle) and locking:
		circle.fill = caster.fill
		circle.full = caster.state == SwayCaster.State.FULL
	if crackle != null and is_instance_valid(crackle) and locking:
		var pressed := caster.pose != null and caster.pose.pressed
		crackle.from = palms()
		crackle.level = smoothstep(0.3, 1.0, caster.fill) * (1.0 if pressed else 0.25) * (0.35 if caster.off_t > 0.0 else 1.0)


func _exit_tree() -> void:
	_clear_fx()
