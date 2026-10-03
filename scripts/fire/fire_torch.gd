class_name FireTorch
extends Node
## Setting fire with the held torch, and beating a fire out, on purpose (scripts/fire; FireSpread makes one, its child,
## and polls it every FireSpread.TORCH_POLL s). Never by chance: a lit torch carried past a wall, held in a doorway or
## on the fort's firing step against the palisade sets nothing alight (the torch's flame rides 0.16 m from the body,
## so "the flame touches the wood" was any wall the player stood against).
##   set it alight   a lit torch in the hand and the crosshair on something that burns within REACH: the prompt says
##                   "E  Set the notched log wall alight"; a tap of E holds the torch to it, and kept there for
##                   FireSpread.TORCH_S (the player within JOB_REACH of the place, the torch lit and in the hand) it
##                   catches. Putting the torch away, letting it burn out or walking off stops it.
##   beat it out     a fire still catching (FireSpread.CATCH_S: its first seconds; a burnable all alight cannot be
##                   put out by hand): "E  Beat out the flames on the notched log wall", kept at for BEAT_S.
## A tap of E while either goes on stops it ("E  Stop ..."). Not in build mode (its E is its own), not riding, not dead.
## The offer is an Offer node (the PlayerInteractor's "any other interactable" contract: PlacedWeapon.GROUP,
## interact_point, interact_prompt, interact, highlight_targets, interact_reach, distance_from). There are two, made
## once and never freed (the interactor keeps last frame's candidates, and a freed one there is an error): when what is
## offered changes the other one goes up, so the interactor sees a new node and glows the new piece.
## Tests and films: `aim_at` (world, not INF) stands for where the crosshair lands.

const REACH := 2.4
const JOB_REACH := 2.8
const BEAT_S := 2.5
const RAY_LEN := 12.0
## The torch is lit enough to set fire with (TorchState.strength()).
const MIN_STRENGTH := 0.3

## The interactor's target: an offer of what E does here.
class Offer:
	extends Node3D
	var ctl: FireTorch
	var interact_reach := FireTorch.REACH

	func interact_point() -> Vector3:
		return ctl.point

	func distance_from(p: Vector3) -> float:
		return p.distance_to(ctl.point)

	## (the one put by says nothing: the interactor may still hold it for a frame)
	func interact_prompt(_player: Node) -> String:
		return ctl.prompt() if ctl.offer == self else ""

	func highlight_targets() -> Array:
		return ctl.glow_targets() if ctl.offer == self else []

	func interact(_player: Node) -> void:
		if ctl.offer == self:
			ctl.act()


var fire: FireSpread
## Not INF: where the crosshair lands (tests).
var aim_at := Vector3.INF
## What is offered: the burnable, the kind ("light" / "beat", "" none) and the point.
var target: Node3D
var kind := ""
var point := Vector3.ZERO
## The job going on ({} none): {"kind", "node", "at", "t"}.
var job := {}
## The offer up (null: none), and the two it is one of (the last up, `_last`).
var offer: Offer
var _offers: Array[Offer] = []
var _last: Offer


## Every TORCH_POLL s: the job goes on (or stops), and the offer follows the crosshair.
func poll(dt: float) -> void:
	var p := fire._player() if fire else null
	if not job.is_empty():
		_job_step(p, dt)
	if not job.is_empty():
		_offer(job.node, String(job.kind), job.at)
		return
	var n: Node3D = null
	var at := Vector3.INF
	var k := ""
	if _can_act(p) and (fire.burning_count() > 0 or _torch_lit(p)):
		var hit := _aim(p)
		n = hit.get("node") as Node3D
		at = hit.get("at", Vector3.INF)
		if n != null:
			var stage := fire.stage_of(n)
			if stage == "catching":
				k = "beat"
			elif stage == "" and _torch_lit(p):
				k = "light"
	_offer(n if k != "" else null, k, at)


## What a tap of E does now ("" nothing).
func prompt() -> String:
	if target == null or not is_instance_valid(target):
		return ""
	var nm := fire.name_of(target)
	if not job.is_empty():
		return "Stop holding the torch to the %s" % nm if job.kind == "light" else "Stop beating at the flames"
	if kind == "light":
		return "Set the %s alight" % nm
	if kind == "beat":
		return "Beat out the flames on the %s" % nm
	return ""


func glow_targets() -> Array:
	if target == null or not is_instance_valid(target):
		return []
	if target is BuiltPiece:
		return (target as BuiltPiece).highlight_targets()
	return target.find_children("*", "GeometryInstance3D", true, false).filter(
			func(g: Node) -> bool: return not (g is GPUParticles3D or g is CPUParticles3D))


## A tap of E: starts what is offered, or stops what goes on.
func act() -> void:
	if not job.is_empty():
		stop()
		return
	if target == null or not is_instance_valid(target) or kind == "":
		return
	job = {"kind": kind, "node": target, "at": point, "t": 0.0}
	fire.tell("You hold the torch to the %s" % fire.name_of(target) if kind == "light" else "You beat at the flames")


## Stops the job (and takes the offer down: it is made again on the next poll).
func stop() -> void:
	job = {}
	_offer(null, "", Vector3.ZERO)


func _job_step(p: FrontierPlayer, dt: float) -> void:
	var n: Variant = job.get("node")
	var ok := is_instance_valid(n) and fire.burnable(n as Node3D) and _can_act(p) \
			and p.global_position.distance_to(job.at) <= JOB_REACH
	if ok and job.kind == "light":
		ok = fire.stage_of(n) == "" and _torch_lit(p)
	elif ok:
		ok = fire.stage_of(n) == "catching"
	if not ok:
		stop()
		return
	job.t = float(job.t) + dt
	if job.kind == "light" and float(job.t) >= FireSpread.TORCH_S - 0.001:
		var nm := fire.name_of(n)
		var at: Vector3 = job.at
		job = {}
		if fire.ignite(n, at):
			fire.tell("The %s catches fire" % nm)
	elif job.kind == "beat" and float(job.t) >= BEAT_S - 0.001:
		job = {}
		if fire.put_out(n):
			fire.tell("You beat out the flames")


## The player can set fire or beat it out now: there, alive, on foot, not building.
func _can_act(p: FrontierPlayer) -> bool:
	if p == null or not is_instance_valid(p) or p.is_dead or p.riding != null:
		return false
	var bm := BuildMode.current
	return not (bm and is_instance_valid(bm) and bm.active)


func _torch_lit(p: FrontierPlayer) -> bool:
	var t := p.torch
	return t != null and t.holding() and not t.tossing() and t.held.lit and t.held.strength() > MIN_STRENGTH


## The burnable the crosshair lands on within REACH of the chest: {node, at} ({} none).
func _aim(p: FrontierPlayer) -> Dictionary:
	var chest := p.global_position + Vector3.UP
	if aim_at != Vector3.INF:
		var an := fire.burnable_at(aim_at)
		return {"node": an, "at": aim_at} if an and chest.distance_to(aim_at) <= REACH else {}
	var cam := p.get_viewport().get_camera_3d() if p.is_inside_tree() else null
	if cam == null:
		return {}
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * RAY_LEN)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or chest.distance_to(hit.position) > REACH:
		return {}
	var n := fire._resolve(hit.collider)
	return {"node": n, "at": hit.position} if n and fire.burnable(n) else {}


## The offer up for `n` (`k` what E does, `at` where), made again when either changes; none for null.
func _offer(n: Node3D, k: String, at: Vector3) -> void:
	point = at if at != Vector3.INF else point
	if n == target and k == kind and (offer != null) == (n != null):
		return
	target = n
	kind = k
	if offer:
		offer.remove_from_group(PlacedWeapon.GROUP)
	offer = null
	if n == null:
		return
	if _offers.is_empty():
		for i in 2:
			var o := Offer.new()
			o.name = "FireOffer%d" % i
			o.ctl = self
			add_child(o)
			_offers.append(o)
	offer = _offers[1] if _last == _offers[0] else _offers[0]
	_last = offer
	offer.add_to_group(PlacedWeapon.GROUP)
