class_name SkyTear
extends Node
## The sky tears (the story's reveal, mission 11 "Two Fires"; the owner 2026-10-02: "the scene should be two air ships
## fighting, they break the sky and one crashes down"): the fight high over the valley cracks the night sky open from
## one point; the fractures spread and widen with the etherium showing through them, the shards between them fall away,
## and the whole wonder sky is open (EnvironmentRig.reveal_wonder, WonderLook) as the cracks fade.
## The look is the dynamic sky's (shaders/sky/wonder_sky.gdshaderinc: sky_tear; uniforms tear_amount, tear_dir,
## tear_seed, impact_flash, impact_flash_dir); this drives them on the rig's sky.
##   SkyTear.begin(rig, dir, seconds)  the tear from `dir` (world, toward its centre) over `seconds`: tear_amount 0 -> 1;
##                                     at REVEAL_AT of the way the rig's wonder starts to fade in, reaching 1 as the tear
##                                     ends; then the tear is put away (tear_amount 0: the wonder holds the sky) and
##                                     `opened` is emitted. A sky already open (rig.wonder 1) is left alone.
##   SkyTear.begin(rig, dir, seconds, -1, true)  held: the crack only creeps out from the point (toward HOLD_TO: small and
##                                     local, while the story has something else to watch: the cutter falling) until
##                                     release(); from there it runs on at its pace (the rest of `seconds` x what is left).
##                                     A hold is let go by itself after HOLD_MAX_S.
##   SkyTear.flash(rig, strength, dir) a hit's flash over the sky (impact_flash: the sky, the clouds, a little on the land
##                                     through the radiance map), gone in a fraction of a second; the cracks flare with it.
##   SkyTear.pose(rig, dir, amount)    the tear held at `amount` with the wonder where the tear would have it (look-dev,
##                                     tools/environment/tear_shots.gd).
## One SkyTear node lives under the rig (SkyTear.of(rig)). Headless (no sky material) it still runs its clock and the
## rig's wonder (tests/env/test_sky_tear.gd); `material` may be given one to watch.

signal opened

const NODE_NAME := "SkyTear"
## Of the tear's time: the wonder starts to fade in here (rig.reveal_wonder over the rest), so it is full as the tear ends.
const REVEAL_AT := 0.7
## The flash's half-life (s): a hit, not a glow.
const FLASH_HALF_LIFE := 0.11
const DEFAULT_SECONDS := 32.0
## Held: the tear creeps toward HOLD_TO (its time constant HOLD_TAU_S) and is let go after HOLD_MAX_S whatever happens.
const HOLD_TO := 0.1
const HOLD_TAU_S := 3.0
const HOLD_MAX_S := 30.0

var rig: EnvironmentRig
## The sky's material (the rig's dynamic sky); null headless unless a test gives one.
var material: ShaderMaterial
## Toward the tear's centre (world, unit).
var dir := Vector3(0.6, 0.62, -0.5).normalized()
var seconds := DEFAULT_SECONDS
## The tear now (0 .. 1: the shader's tear_amount) and the flash.
var amount := 0.0
var flash_amount := 0.0
var flash_dir := Vector3.ZERO
var running := false
var revealed := false
## Held (begin's `held`): creeping, until release().
var held := false
var _t := 0.0


## The rig's SkyTear (made on first use).
static func of(r: EnvironmentRig) -> SkyTear:
	var n := r.get_node_or_null(NODE_NAME) as SkyTear
	if n == null:
		n = SkyTear.new()
		n.name = NODE_NAME
		n.rig = r
		n.material = r._sky_material
		r.add_child(n)
	return n


## The tear opens from `toward` (world direction from the valley up into the sky) over `secs`. `pattern` picks the
## network (< 0: from the direction); `hold`: it only creeps until release().
static func begin(r: EnvironmentRig, toward: Vector3, secs := DEFAULT_SECONDS, pattern := -1.0, hold := false) -> SkyTear:
	var n := of(r)
	n.start(toward, secs, pattern, hold)
	return n


## The held tear let go (the story's beat: the cutter down): it runs on from where it crept to.
static func let_go(r: EnvironmentRig) -> void:
	var n := r.get_node_or_null(NODE_NAME) as SkyTear if r != null else null
	if n != null:
		n.release()


## A hit's flash over the sky: `strength` 0..1 (stacks to the stronger), toward `toward` when given (zero: even).
static func flash(r: EnvironmentRig, strength := 1.0, toward := Vector3.ZERO) -> void:
	var n := of(r)
	n.flash_amount = maxf(n.flash_amount, clampf(strength, 0.0, 1.0))
	n.flash_dir = toward.normalized() if toward.length_squared() > 1e-6 else Vector3.ZERO
	n._push_flash()


## The tear held at `at` (0..1), the wonder where the tear's clock would have it.
static func pose(r: EnvironmentRig, toward: Vector3, at: float, pattern := 0.0) -> SkyTear:
	var n := of(r)
	n.dir = toward.normalized()
	n.running = false
	n.amount = clampf(at, 0.0, 1.0)
	n._push_tear(pattern)
	r.set_wonder(ease_wonder(wonder_at(n.amount)))
	return n


## The rig's wonder (linear, before the rig's easing) at tear `a`.
static func wonder_at(a: float) -> float:
	return clampf((a - REVEAL_AT) / (1.0 - REVEAL_AT), 0.0, 1.0)


## The rig's easing of its wonder (EnvironmentRig._process: smoothstep).
static func ease_wonder(w: float) -> float:
	return w * w * (3.0 - 2.0 * w)


func start(toward: Vector3, secs := DEFAULT_SECONDS, pattern := -1.0, hold := false) -> void:
	if rig and rig.wonder >= 1.0:
		return   # the sky is open already (a save after the reveal)
	dir = toward.normalized() if toward.length_squared() > 1e-6 else dir
	seconds = maxf(secs, 0.5)
	amount = 0.0
	_t = 0.0
	running = true
	revealed = false
	held = hold
	var s := pattern if pattern >= 0.0 else fposmod(dir.x * 13.7 + dir.y * 7.1 + dir.z * 3.3, 7.0)
	_push_tear(s)


func _process(delta: float) -> void:
	if flash_amount > 0.0:
		flash_amount *= pow(0.5, delta / FLASH_HALF_LIFE)
		if flash_amount < 0.004:
			flash_amount = 0.0
		_push_flash()
	if not running:
		return
	_t += delta
	if held:
		# creeping: small and local, slowing as it nears HOLD_TO
		amount = maxf(amount, HOLD_TO * (1.0 - exp(-_t / HOLD_TAU_S)))
		if _t >= HOLD_MAX_S:
			release()
	else:
		amount = clampf(amount + delta / seconds, 0.0, 1.0)
	if not revealed and amount >= REVEAL_AT and rig:
		revealed = true
		rig.reveal_wonder(seconds * (1.0 - REVEAL_AT))
	if material:
		material.set_shader_parameter(&"tear_amount", amount)
	if amount >= 1.0 and (rig == null or rig.wonder >= 1.0):
		# the wonder holds the whole sky now: the tear put away (its cost with it)
		running = false
		amount = 0.0
		if material:
			material.set_shader_parameter(&"tear_amount", 0.0)
		if rig:
			rig.set_wonder(1.0)                           # (settled: its fade done)
		opened.emit()


## Let go of the hold: from here the tear runs on at 1 / seconds a second.
func release() -> void:
	held = false


func _push_tear(pattern: float) -> void:
	if material == null:
		return
	material.set_shader_parameter(&"tear_amount", amount)
	material.set_shader_parameter(&"tear_dir", dir)
	material.set_shader_parameter(&"tear_seed", pattern)


func _push_flash() -> void:
	if material == null:
		return
	material.set_shader_parameter(&"impact_flash", flash_amount)
	material.set_shader_parameter(&"impact_flash_dir", flash_dir)
