class_name BendBolt
extends Node3D
## A bent element in flight (BendEffects' "bolt"; docs/bending_design.md): stone, ice, water, fire or air, flying straight
## (gravity on it), struck as its front meets someone (BendStatus: the blow, the knockback, a root or a slow), spent on the
## world with a burst. Group GROUP. What it does against the others (docs: "How moves meet"):
##   bolt vs bolt (meet)   water + fire: both gone in steam; water + water: both gone; fire + ice: the ice melts, the fire
##                         goes on weaker; stone + anything else: the other is gone, the stone goes on; stone + stone: both
##                         break; air + fire: the air takes the flame (it burns); air + water: the water scatters
##   a raised wall         worn by its kind against the wall's matter (WEAR: water erodes earth, fire melts ice, stone
##                         breaks both, air does nothing); the bolt is spent
##   a zone                BendZone.on_bolt: a bubble, a water wall, an air shield, a fire wall decide (stop, send back,
##                         take the flame); an earth guard takes a stone (catch: held as a FormStone for Earth Shove to send
##                         back; deflect: knocked aside; cushion: dropped)
## Its caster is any Node3D (the player, a bot): its own bodies are left out of its flight (_exclude: ray_exclude).
## redirect(dir, by) turns it (a shield's, a parry's, a redirect's): it is then `by`'s, and can strike who first sent it.
## A thrown one (BendThrow, spec do "throw"): its flight "point_first" (a spear: its point -Z along its flight, as every bolt
## faces), "spinning" (a disc: its body turned about its own right axis at spin_rate rad/s, a wheel or a tomahawk end over
## end, tilted tilt_deg about its flight for a side-arm throw), "flick" (pebbles: each tumbling on its own axis). The
## water and fire that meet leave a short steam cloud (BendZone "steam": it hides whoever stands behind it from a bot).
## ROUND 2 (skills_r2 spec §2.4, §2.8-2.10, §8.2):
##   floor_wave   the Kick (spec do "floor_wave"): it runs along the deck under it (its origin on the ground), its width
##                growing from FLOOR_W0 at the foot to width_m at its range, height_m tall; a body is struck when it stands in
##                its width and its feet are no more than miss_above_m over the deck (a jump clears it); any wall stops it
##                (worn as fire: half a hit on earth); its look a row of low flame tongues (BendLooks.floor_wave_body)
##   weight       light < medium < heavy (spec weight; pebbles light, a boulder heavy, else medium): stone meets stone, the
##                heavier goes on and equal ones both break; a GustLift's flying stone too (its stone's weight: weight_of)
##   steer        a water bolt of a water fighter (Flowing: Bending.passive("water")) bends toward its caster's aim (no aim
##                help) at steer_dps for steer_s after it leaves, steer_max_deg in all
##   swing        a Turn on the beat (BendZone): it swings once round the guard's waist and leaves along his aim, his now
##                (x the Turn's perfect_mult): it glides from where it was caught onto the swing's circle (SWING_IN of the
##                swing), never a jump. The Air Lance turned (become "ice"): ice from the catch, its body drawn short on the
##                circle (WRAP_Z, it wraps round him) and grown back to its length as it leaves with a burst and a cast's voice
##   become       a kind made anew in flight (become: a Turn's catch of the Air Lance leaves as an ice lance): its body, trail
##                and voice of the new kind, a fire it carried put out; its numbers kept (a Turn sends back what it took)
##   under        a burrower (meta bend_under_until) is passed over by stone
##   near miss    a bolt passing within near_m of an air fighter in a Slip (meta bend_slip_until) charges his Carried wind
##   pull         a Pull wave: whom it strikes is knocked toward its caster
##   the cost     lock_s: its move's lock time (BendEffects), what a hit costs the struck one's lock (BendStatus.hurt)
##   guarded_by   the guards that halved it already (a late guard; a wind wall's push), never twice
## A caster freed in flight (a bot gone between rounds): its strikes are no one's (_by), never an error.
## ROUND 3 (smash_r3 spec §14.3; AIR): `info`, the hit info it carries (its spec's `_info`), its strike through
## BendR3.deliver; a guard sending it back makes it a return (BendZone.return_info). In the % ring the floor wave runs on
## floor_wave_lip_over_m past the deck's lip at the deck's height (a hanger's hands), and a caster's own held stone is not in
## his bolts' way.
## ROUND 4 (READ): in a ring or a duel it sounds in flight (BendSounds.flight from its launch, its kind's loop following it;
## the floor wave's floor_run), let go at its end (its hit, the world, its range, a guard's catch: BendSounds.flight_end).
## ONLINE (NetSpells, docs/tidebreak/ring_netcode.md "Ghost mode"): named by its cast's run (NetSpells.tag). On the host it
## does all of the above and tells the others: an end that is not its own (its range, the lip, the world) as an "end" word,
## any change a meeting made to it (a turn, a swing, a new kind, a fire it took, its numbers halved) as a "bolt" word with its
## state (_net_check, each frame). On any other machine it is a GHOST: it flies and steers as ever, ends on the world and on a
## raised wall as the host's will (seen at once), and passes bodies, stones, other bolts and zones untouched until the host's
## word turns it (net_state) or ends it where the host's did (net_end: its ending's look there).

signal struck(who: Node, dmg: float)
signal ended(why: String)

const GROUP := &"bend_bolts"
## How many hits a raised wall takes from a bolt of each kind ([earth-like, ice]): FormRaised.apply_hit per whole one, the
## rest kept (the wall's meta bend_wear).
const WEAR := {"water": [1.0, 0.5], "fire": [0.5, 3.0], "stone": [1.5, 2.0], "ice": [1.0, 1.0], "air": [0.0, 0.0]}

var kind := "fire"
var caster: Node3D
var velocity := Vector3.ZERO
var gravity := 0.0
var damage := 10.0
var knock_mps := 3.0
var up_mps := 1.0
var radius := 0.2
var range_m := 30.0
var long := false
## Along the ground (spec.low: Fire Arc's kick, a wave along the ground): it keeps LOW_M over the ground under it (a slope, a
## deck), its blow felt by the legs; the ground itself does not stop it (its feel for the world a little narrower than it).
var low := false
const LOW_M := 0.45
## Extra wear on an earth wall (the water jet's erosion), a root or a slow on whom it strikes (s), fire it carries (air).
var erode := 1.0
var root_s := 0.0
var slow_s := 0.0
var burning := false
## A stone's shape (spec.shape: "ball", "disc", "shard"; a guard's catch holds a stone of it: BendZone.on_bolt).
var shape := "ball"
var travelled := 0.0
var spent := false
## How it flies (BendThrow): "" or "point_first" (its point along its flight), "spinning", "flick"; its turn (rad/s), the
## axis its body turns about (local), its tilt about its flight (rad). The body turns under `spin` (a child of the bolt,
## which keeps facing its flight); a bolt with no turn has none.
var flight := ""
var spin_rate := 0.0
var spin_axis := Vector3.RIGHT
var tilt := 0.0
var spin: Node3D
var spin_a := 0.0
## The steam left where water and fire meet (BendZone "steam"): its radius and how long it hangs (s).
const STEAM_R := 2.2
const STEAM_S := 1.5
## Round 2 (see the header). A floor wave's width at the foot (m).
const FLOOR_W0 := 1.2
const WEIGHTS := {"light": 0, "medium": 1, "heavy": 2}
var weight := "medium"
var lock_s := -1.0
var guarded_by: Array[int] = []
## A caught stone's own numbers (a returned stone carries them: BendZone.return_stone), its rally so far.
var stone_d := {}
var rally := 0.0
## The floor wave's: on, its width at range, its height, how high over the deck a body's feet may be and still be struck.
var floor_wave := false
var width_m := 2.2
var height_m := 0.9
var miss_above_m := 0.6
## A Turn's swing (begin_swing): the part of it (0..1) over which a caught bolt glides onto the circle, and the circle's height
## over the guard's feet (m).
const SWING_IN := 0.25
const SWING_WAIST_M := 1.0
## A bolt turned in a Turn's swing (become): its body drawn this long on the circle (of its length) while it wraps round the
## guard, coming in over WRAP_IN_S and grown back over WRAP_OUT_S as it leaves.
const WRAP_Z := 0.4
const WRAP_IN_S := 0.06
const WRAP_OUT_S := 0.12
var deck_y := 0.0
var _wave_look: Node3D
## The pull (a Pull wave): whom it strikes is knocked toward its caster.
var pull := false
## Round 3: the hit info it carries (BendR3.info_for: tag, from, air, a volley's id and size; slide_only once a late guard
## halved it; returned, ret_mult, origin_tag once a guard sent it back). Read only by the % rules.
var info := {}
## Flowing's steer: per second, in all (deg), for how long (s); how far it has turned, how long it has flown.
var steer_dps := 0.0
var steer_max_deg := 0.0
var steer_s := 0.0
var _steered := 0.0
var age := 0.0
## A Turn's swing: the guard it swings round, for how long, its radius, the factor it leaves with; 0..1 of it done.
var _swing_by: Node3D
var _swing_s := 0.0
var _swing_r := 1.0
var _swing_k := 1.0
var _swing_t := -1.0
var _swing_a0 := 0.0
## Where it was caught, from the guard: its flat distance and its height (the swing glides from there onto its circle).
var _swing_r0 := 1.0
var _swing_h0 := 1.0
## Its own look (BendLooks.bolt_body; not a floor wave's, not the Spellbreak effects'): the size it was drawn at and the parts
## it is drawn with, which become() makes again for a new kind (only those: nothing else hung on it is touched).
var look_r := 0.0
var _body_parts: Array[Node] = []
## A body made anew by become() (under this node, so it is drawn shorter as a whole on a Turn's circle).
var _look: Node3D
## The swing turned it (become): it is drawn wrapped round the guard and leaves with a burst and a cast's voice.
var _swing_became := false
## While valid, the swing goes on only as long as it says true (Eye of the Gale: the guarder's E held; AirTalents.eye_catch): let
## go, it leaves along his aim from where it is. Invalid (every Turn): the swing runs its time.
var swing_hold := Callable()
## Carrying Wind's Beat Gust (AirTalents.on_wind_wave): the loose stones it crosses are thrown on (AirTalents.carry_stones).
var carries := false

var _trail: GPUParticles3D
var _fire_trail: GPUParticles3D
var _q: PhysicsShapeQueryParameters3D


## A bolt of `spec` (BendEffects' bolt fields) from `from` along `dir` by `by`, under the current scene.
static func launch(by: Node3D, from: Vector3, dir: Vector3, spec: Dictionary) -> BendBolt:
	var b := BendBolt.new()
	b.name = "BendBolt"
	b.kind = String(spec.get("kind", "fire"))
	b.caster = by
	b.velocity = dir.normalized() * float(spec.get("mps", 30.0))
	b.gravity = float(spec.get("gravity", 0.0))
	b.damage = float(spec.get("damage", 10.0))
	b.knock_mps = float(spec.get("knock_mps", 3.0))
	b.up_mps = float(spec.get("up_mps", 1.0))
	b.radius = float(spec.get("radius_m", 0.2))
	b.range_m = float(spec.get("range_m", 30.0))
	b.long = bool(spec.get("long", false))
	b.low = bool(spec.get("low", false))
	b.erode = float(spec.get("erode", 1.0))
	b.root_s = float(spec.get("root_s", 0.0))
	b.slow_s = float(spec.get("slow_s", 0.0))
	b.shape = String(spec.get("shape", "ball"))
	b.flight = String(spec.get("flight", ""))
	b.spin_rate = float(spec.get("spin_rate", 0.0))
	b.tilt = deg_to_rad(float(spec.get("tilt_deg", 0.0)))
	if spec.get("spin_axis") is Vector3:
		b.spin_axis = (spec.spin_axis as Vector3).normalized()
	b.weight = String(spec.get("weight", weight_by_size(b.kind, b.radius, String(spec.get("flight", "")))))
	b.lock_s = float(spec.get("_lock_s", -1.0))
	b.pull = bool(spec.get("pull", false))
	var inf: Variant = spec.get("_info", {})
	b.info = (inf as Dictionary).duplicate() if inf is Dictionary else {}
	b.floor_wave = String(spec.get("do", "")) == "floor_wave"
	if b.floor_wave:
		b.width_m = float(spec.get("width_m", 2.2))
		b.height_m = float(spec.get("height_m", 0.9))
		b.miss_above_m = float(spec.get("miss_above_m", 0.6))
		b.radius = minf(b.radius, 0.25)
	if spec.has("steer_dps"):
		b.steer_dps = float(spec.steer_dps)
		b.steer_max_deg = float(spec.get("steer_max_deg", 15.0))
		b.steer_s = float(spec.get("steer_s", 0.25))
	b.add_to_group(GROUP)
	NetSpells.tag(b)                             # (online: its name in its cast's run)
	by.get_tree().current_scene.add_child(b)
	b.global_position = from
	if b.floor_wave:
		b.deck_y = FormEffects.ground_at(b, from).y
		b.global_position.y = b.deck_y
	b._face()
	var holder: Node3D = b
	if b.flight in ["spinning", "flick"] or absf(b.tilt) > 1e-4:
		b.spin = Node3D.new()
		b.spin.name = "Spin"
		b.add_child(b.spin)
		b._turn(0.0)
		holder = b.spin
	# (the Spellbreak effects, SbFx: visual only; when the move's flight replaces today's body and trail they are not made)
	var sbk := SbFx.key_of(b.info)
	var sbo := {"node": b, "dir": b.velocity, "info": b.info, "width": b.width_m}
	var sb := SbFx.fire(by, sbk, "wave" if b.floor_wave or String(spec.get("do", "")) == "wind_wave" else "flight", sbo)
	SbFx.fire(by, sbk, "trail", sbo)
	if b.steer_dps > 0.0:
		SbFx.fire(by, "flowing", "curve", sbo.merged({"el": "water", "life": b.steer_s + 0.1}, true))
	if b.floor_wave:
		if not sb:
			# (earth's Fissure, a stone floor wave: spikes of stone, FissureFx; fire's Kick its flame tongues)
			if b.kind == "stone":
				b._wave_look = BendLooks.fissure_body(b, b.width_m, b.height_m)
			else:
				b._wave_look = BendLooks.floor_wave_body(b, FLOOR_W0, b.height_m)
	elif not sb:
		b.look_r = float(spec.get("look_r", b.radius))
		var before := holder.get_children()
		BendLooks.bolt_body(holder, b.kind, b.look_r, b.long, b.shape)
		for c in holder.get_children():
			if not c in before:
				b._body_parts.append(c)              # (its own look: what become() makes anew)
		# (a wind wave's trail the size of its look, not of the 2 m it hits: sized by its radius, its puffs swelled to 1.3 m and
		# its ribbons coiled 1.35 m round, a white cloud hiding the wave; the owner 2026-10-11: "i hate how that air blast has
		# such a big wave to it")
		var trail_r := b.look_r if String(spec.get("do", "")) == "wind_wave" else b.radius
		b._trail = BendLooks.trail(b, b.kind, trail_r)
	elif b.kind == "air":
		BendLooks._air_dust(holder)              # (the dust line under a low air bolt stays: today's look)
	# (round 4, READ: its voice in flight, an arena's only; let go at its end: BendSounds.flight)
	BendSounds.flight(BendSounds.flight_kind(b), b)
	return b


## A bolt's weight by what it is when its spec gives none: a stone flicked or small (a pebble) "light", a big one (0.35 m
## and more across its middle: a boulder) "heavy", else "medium"; anything not stone "light".
static func weight_by_size(k: String, r: float, flight := "") -> String:
	if k != "stone":
		return "light"
	if flight == "flick" or r < 0.15:
		return "light"
	return "heavy" if r >= 0.35 else "medium"


## The weight of a flying GustLift's stone (its meta bend_weight; a spike medium, a cannonball of 0.25 m or more heavy).
static func weight_of(l: GustLift) -> String:
	if l == null or l.stone == null or not is_instance_valid(l.stone):
		return "medium"
	if l.stone.has_meta(&"bend_weight"):
		return String(l.stone.get_meta(&"bend_weight"))
	if l.kind == "cannonball" and l.stone is FormStone and (l.stone as FormStone).radius >= 0.25:
		return "heavy"
	return "medium"


## Its caster, or null when that is gone (a bot freed between rounds): what its strikes are credited to.
func _by() -> Node3D:
	return caster if caster != null and is_instance_valid(caster) else null


## In a Turn's swing now (BendZone: no guard, no wall, no one meets it until it leaves).
func swinging() -> bool:
	return _swing_t >= 0.0


## A Turn on the beat (BendZone): once round `by`'s waist over `s` s at `r` m, then away along his aim at `k` times its
## speed, damage and knock, his; a water fighter's Flowing steers it as it leaves. `to_kind`: it turns into that kind as it
## is caught (become: the Air Lance turned to ice), drawn short on the circle (WRAP_Z) while it wraps round him.
func begin_swing(by: Node3D, s: float, r: float, k: float, to_kind := "") -> void:
	_swing_by = by
	_swing_s = maxf(s, 0.05)
	_swing_r = r
	_swing_k = k
	_swing_t = 0.0
	var off := global_position - by.global_position
	_swing_a0 = atan2(off.x, off.z)
	_swing_r0 = clampf(Vector2(off.x, off.z).length(), 0.2, 3.0)
	_swing_h0 = off.y
	info = BendZone.return_info(info, by, global_position, k)
	caster = by
	if to_kind != "" and to_kind != kind:
		become(to_kind)
		_swing_became = true
		if _look != null:
			create_tween().tween_property(_look, ^"scale", Vector3(1.0, 1.0, WRAP_Z), WRAP_IN_S)
		# (our own freeze: a big burst of the new kind where it was caught, ice's freezing voice)
		BendLooks.burst(global_position, to_kind, 24, Vector3.UP, 180.0, 4.0, 0.25, false)
		BendSounds.event("ice_rise" if to_kind == "ice" else "", global_position, -3.0)
	elif not SbFx.fire(by, "water_redirect/redirect", "swing", {"at": global_position, "dir": velocity, "el": "water"}):
		BendLooks.burst(global_position, kind, 10)


## It is made a bolt of kind `k` now, in flight (a water Turn's catch of the Air Lance leaves as ice: begin_swing): its kind,
## and its own look and voice of that kind made anew (its body under a "Look" node, its trail, its flight's voice); a fire
## it carried (an air bolt through fire: burning) put out. Its numbers stay as they are: speed, damage, knock, up, size,
## gravity, range, weight and the lock a hit costs (a Turn sends back what it took, x its own mult). A look that is not its
## own (the Spellbreak effects' flight) is left as it is.
func become(k: String) -> void:
	if spent or k == "" or k == kind:
		return
	kind = k
	burning = false
	if _fire_trail != null:
		BendLooks.stop_trail(_fire_trail)
		_fire_trail = null
	if not _body_parts.is_empty():
		var holder: Node3D = spin if spin != null else self
		for c: Node in _body_parts:
			if is_instance_valid(c):
				if c.get_parent() != null:
					c.get_parent().remove_child(c)   # (out of the tree at once: a replay copying its look sees the new body only)
				c.queue_free()
		_body_parts.clear()
		_look = Node3D.new()
		_look.name = "Look"
		holder.add_child(_look)
		BendLooks.bolt_body(_look, kind, look_r, long, shape)
		_body_parts.append(_look)
		BendLooks.stop_trail(_trail)
		_trail = BendLooks.trail(self, kind, radius)
	BendSounds.flight_end(self)
	BendSounds.flight(BendSounds.flight_kind(self), self)


func _swing(dt: float) -> void:
	if _swing_by == null or not is_instance_valid(_swing_by):
		_swing_t = -1.0
		end("swing")
		return
	if not (swing_hold.is_valid() and not bool(swing_hold.call())):
		_swing_t += dt / _swing_s
		var u := minf(_swing_t, 1.0)
		var a := _swing_a0 - TAU * u
		# (from where it was caught onto the circle at the waist over the first SWING_IN of the swing: no jump onto it)
		var e := smoothstep(0.0, SWING_IN, u)
		var rr := lerpf(_swing_r0, _swing_r, e)
		var hh := lerpf(_swing_h0, SWING_WAIST_M, e)
		var at := _swing_by.global_position + Vector3.UP * hh + Vector3(sin(a), 0.0, cos(a)) * rr
		var was := global_position
		global_position = at
		if (at - was).length_squared() > 1e-6:
			velocity = (at - was).normalized() * velocity.length()
		_face()
		if _swing_t < 1.0:
			return
	_swing_t = -1.0
	swing_hold = Callable()
	var to := BendZone.guard_aim(_swing_by, global_position)
	var sp := velocity.length() * _swing_k
	velocity = (to - global_position).normalized() * sp
	damage *= _swing_k
	knock_mps *= _swing_k
	up_mps *= _swing_k
	travelled = 0.0
	if BendPoses.element_of(_swing_by) == "water":
		var pv := Bending.passive("water")
		steer_dps = BendLoadout.tune_f(_swing_by, "rules:passives.water.steer_dps", float(pv.get("steer_dps", 45.0)))
		steer_max_deg = BendLoadout.tune_f(_swing_by, "rules:passives.water.steer_max_deg", float(pv.get("steer_max_deg", 15.0)))
		steer_s = BendLoadout.tune_f(_swing_by, "rules:passives.water.steer_s", float(pv.get("steer_s", 0.25)))
		age = 0.0
		_steered = 0.0
	_face()
	if _swing_became:
		_swing_became = false
		if _look != null and is_instance_valid(_look):
			create_tween().tween_property(_look, ^"scale", Vector3.ONE, WRAP_OUT_S)
		# (it leaves as what it became: a burst along its way and the cast's voice of its kind)
		BendLooks.burst(global_position, kind, 16, velocity.normalized(), 50.0)
		if kind == "ice":
			BendSounds.play(&"ice_cast", global_position)


func _face() -> void:
	if velocity.length_squared() > 1e-6:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)


## Its body turned on by `dt` (spinning, flick: spin_rate about spin_axis; tilted about its flight by tilt).
func _turn(dt: float) -> void:
	if spin == null:
		return
	spin_a = fposmod(spin_a + spin_rate * dt, TAU)
	spin.basis = Basis(Vector3.BACK, tilt) * Basis(spin_axis, -spin_a)


func _physics_process(dt: float) -> void:
	if spent:
		return
	_net_check()
	if _swing_t >= 0.0:
		_swing(dt)
		return
	var ghost := not NetSpells.decides()
	age += dt
	_steer(dt)
	velocity.y -= gravity * dt
	var from := global_position
	var step := velocity * dt
	if low:
		var nxt := from + step
		step.y = FormEffects.ground_at(self, nxt).y + LOW_M - from.y
	var lip_end := false
	if floor_wave:
		var nxt2 := from + Vector3(step.x, 0.0, step.z)
		var over := BendR3.past_lip(get_tree(), nxt2) if BendR3.stock() else -INF
		if over > 0.0:
			# (round 3: past the lip it runs on at the deck's height for floor_wave_lip_over_m, over the hands of a man hanging
			# there, then it is spent)
			deck_y = from.y
			var lim := BendR3.num("floor_wave_lip_over_m", 0.3)
			if over > lim:
				var fl := Vector2(step.x, step.z).length()
				var keep := clampf(1.0 - (over - lim) / maxf(fl, 1e-4), 0.0, 1.0)
				step = Vector3(step.x * keep, 0.0, step.z * keep)
				lip_end = true
		else:
			deck_y = FormEffects.ground_at(self, nxt2).y
		step = Vector3(step.x, deck_y - from.y, step.z)
	if not ghost:
		# a teammate held in a bind or a float on its way is freed (BendStatus.rescue: it passes through him, as through allies)
		_rescue_on(from, from + step)
		# the others met on the way (bolts, zones)
		_meet_bolts()
		if spent:
			return
		for z in get_tree().get_nodes_in_group(BendZone.GROUP):
			if (z as BendZone).on_bolt(self) or spent:
				if spent:
					return
		if _swing_t >= 0.0:
			return                            # (a Turn took it: it swings from the next frame)
		_near_miss()
		if carries:
			AirTalents.carry_stones(self, from, step)
	if floor_wave:
		_wave_step(from, step)
		if lip_end and not spent:
			end("lip")
		return
	# the world and whom it meets
	if _q == null:
		_q = PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = minf(radius, LOW_M - 0.12) if low else radius
		_q.shape = sph
	_q.exclude = _exclude()
	_q.transform = Transform3D(Basis.IDENTITY, from)
	_q.motion = step
	var space := get_world_3d().direct_space_state
	var frac := space.cast_motion(_q)
	if frac.size() == 2 and frac[1] < 1.0:
		var at := from + step * frac[1]
		_q.transform = Transform3D(Basis.IDENTITY, at)
		_q.motion = Vector3.ZERO
		var info := space.get_rest_info(_q)
		var col := instance_from_id(int(info.get("collider_id", 0))) as Node if not info.is_empty() else null
		if not (ghost and _ghost_through(col, info)):
			global_position = from + step * frac[0]
			_hit(col, at, Vector3(info.get("normal", -velocity.normalized())))
			return
	global_position = from + step
	travelled += step.length()
	_face()
	_turn(dt)
	if travelled > range_m:
		end("range")


## Flowing (see the header): for steer_s after it leaves it turns toward its caster's aim now (the crosshair's point, no aim
## help: a bot's its target), at most steer_dps a second and steer_max_deg in all.
func _steer(dt: float) -> void:
	if steer_dps <= 0.0 or age > steer_s or _steered >= steer_max_deg or _by() == null:
		return
	var bc := BendCaster.of(_by())
	if bc == null or not bc.valid():
		return
	var aim := bc.aim_point([], Vector3.INF)
	if not aim.is_finite():
		return
	var want := aim - global_position
	var v := velocity
	if want.length_squared() < 1.0 or v.length_squared() < 1e-4:
		return
	var ang := rad_to_deg(v.angle_to(want))
	var turn := minf(minf(steer_dps * dt, steer_max_deg - _steered), ang)
	if turn <= 1e-3:
		return
	var axis := v.cross(want)
	if axis.length_squared() < 1e-8:
		return
	velocity = v.rotated(axis.normalized(), deg_to_rad(turn))
	_steered += turn
	_face()


## How far (deg) it has turned on Flowing's steer so far (the tests).
func steered_deg() -> float:
	return _steered


## Earth's Fissure and the deck's loose stones (2026-10-10: the Shove took them; the Fissure's skill tree keeps them earth's
## ammo): a stone lying free in this step's width on this deck (a loose one, a kicked-up rock, a standing spike: whoever's,
## stones on the deck are fair for both sides; never one held or raised, in flight or sinking, as the Shove's pick) is
## heaved up where it lies and thrown on at the caster's aim (BendEffects.crack_heave: the Shove's throw of a loose stone,
## this wave's hit info). Once each: thrown, it is in flight.
func _heave_loose(from: Vector3, flat: Vector3, fwd: Vector3, across: Vector3, w: float) -> void:
	var by := _by()
	if by == null:
		return
	for s: Node in get_tree().get_nodes_in_group(FormStone.GROUP):
		var st := s as FormStone
		if st == null or st.state == FormStone.State.SINKING or GustLift.busy(st) or st.has_meta(&"bend_held_by") \
				or st.has_meta(&"bend_raised_by"):
			continue
		var l := st.global_position - from
		var along := l.dot(fwd)
		if along < -0.3 or along > flat.length() + 0.35 or absf(l.dot(across)) > w * 0.5 + st.radius:
			continue
		if absf(st.global_position.y - deck_y) > 1.2:
			continue                                  # (not lying on this deck: under the lip, up on a wall)
		BendEffects.crack_heave(by, st, info)
		NetSpells.word(["heave", by, st, info])     # (online: the host's; the others throw it too)


## The floor wave's step (see the header): any wall across its foot stops it (a box at its height swept along); a body in
## its width whose feet are within miss_above_m of the deck is struck; earth's Fissure heaves the loose stones in its width
## (_heave_loose); else on, its width growing.
func _wave_step(from: Vector3, step: Vector3) -> void:
	var flat := Vector3(step.x, 0.0, step.z)
	var w := lerpf(FLOOR_W0, width_m, clampf(travelled / maxf(range_m, 0.1), 0.0, 1.0))
	if flat.length_squared() > 1e-8:
		var fwd := flat.normalized()
		var across := Vector3.UP.cross(fwd).normalized()
		var space := get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		var low_h := maxf(height_m - 0.35, 0.25)
		box.size = Vector3(w, low_h, 0.3)
		q.shape = box
		q.transform = Transform3D(Basis(across, Vector3.UP, fwd), from + Vector3.UP * (0.3 + low_h * 0.5))
		q.motion = flat
		var ex := _exclude()
		for i in 6:
			q.exclude = ex
			var frac := space.cast_motion(q)
			if frac.size() != 2 or frac[1] >= 1.0:
				break
			var at := from + flat * frac[1] + Vector3.UP * 0.6
			q.transform = Transform3D(q.transform.basis, q.transform.origin + flat * frac[1])
			var mv := q.motion
			q.motion = Vector3.ZERO
			var info := space.get_rest_info(q)
			q.motion = mv
			q.transform = Transform3D(Basis(across, Vector3.UP, fwd), from + Vector3.UP * (0.3 + low_h * 0.5))
			var col := instance_from_id(int(info.get("collider_id", 0))) as Node if not info.is_empty() else null
			var who := _taker(col)
			if who is CharacterBody3D or who is NpcFighter or col is CharacterBody3D or (col != null and col.get_parent() is CharacterBody3D):
				if info.has("rid"):
					ex.append(info.rid)      # (a body is the width's own test below, by its feet)
				continue
			if col != null and (who is FormRaised or col is StaticBody3D or col is AnimatableBody3D or col is CSGShape3D):
				global_position = from + flat * frac[0]
				_hit(col, at, -fwd)
				return
			if info.has("rid"):
				ex.append(info.rid)
			else:
				break
		if kind == "stone" and NetSpells.decides():
			_heave_loose(from, flat, fwd, across, w)   # (earth's Fissure: the loose stones it runs under thrown on)
		# whom it runs into: in its width, the feet low enough (online the host's to decide)
		for e in (BendCaster.near(_by() if _by() != null else self, from, w * 0.5 + 1.5) if NetSpells.decides() else []):
			var n: Node3D = e[0]
			if n == _by() or not BendStatus.can_take(n, _by()):
				continue
			var l := n.global_position - from
			var along := l.dot(fwd)
			if along < -0.3 or along > flat.length() + 0.35:
				continue
			if absf(l.dot(across)) > w * 0.5 + 0.3:
				continue
			if n.global_position.y - deck_y > miss_above_m:
				continue                          # (jumped: its feet over the wave)
			global_position = from + fwd * maxf(along, 0.0)
			_hit(n, n.global_position + Vector3.UP * 0.4, -fwd)
			return
	global_position = from + step
	travelled += flat.length()
	_face()
	if _wave_look != null and is_instance_valid(_wave_look):
		if _wave_look.has_method(&"set_width"):
			_wave_look.call(&"set_width", w)        # (a look that lays itself out across the width: FissureFx)
		else:
			_wave_look.scale = Vector3(w / FLOOR_W0, 1.0, 1.0)
	if travelled > range_m:
		end("range")


## A near miss (see the header): an air fighter in a Slip within near_m of it charges his Carried wind, once a bolt.
var _missed: Array[int] = []
func _near_miss() -> void:
	if _by() == null:
		return
	var base := float(Bending.passive("air").get("near_m", 1.2))
	for e in BendCaster.near(_by(), global_position, base * AirTalents.NEAR_QUERY_K):
		var n: Node3D = e[0]
		var near_m := AirTalents.near_m(n, base)        # (his own: Near Miss worn; Classic the passive's)
		if float(e[1]) > near_m or BendStatus.until(n, &"bend_slip_until") <= 0.0 or _missed.has(n.get_instance_id()):
			continue
		if (NpcSenses.chest_of(n) - global_position).length() > near_m + 0.6:
			continue
		_missed.append(n.get_instance_id())
		BendZone.carry_wind(n)

## Its caster's own bodies, left out of its flight: a fighter's hit parts too (NpcFighter.ray_exclude), so a bolt from a bot's
## chest does not strike the bot that sent it. Its caster's allies too (BendCaster.ally_rids: the ring's sides): it passes them.
func _exclude() -> Array[RID]:
	var ex: Array[RID] = _ghost_ex.duplicate()
	if caster == null or not is_instance_valid(caster):
		return ex
	if caster.has_method(&"ray_exclude"):
		ex.append_array(caster.call(&"ray_exclude"))
	elif caster is CollisionObject3D:
		ex.append((caster as CollisionObject3D).get_rid())
	ex.append_array(BendCaster.ally_rids(caster))
	if BendR3.stock():
		var held := BendZone.held_stone(caster)
		if held is CollisionObject3D:
			ex.append((held as CollisionObject3D).get_rid())      # (round 3: past the stone in its own hand)
	if kind == "stone" and is_inside_tree():
		# (a burrower under the deck: stone passes over him; round 2's Burrow, under_s)
		for n in BendCaster.near(caster, global_position, 6.0):
			var b: Node = n[0]
			if BendStatus.until(b, &"bend_under_until") > 0.0:
				if b.has_method(&"ray_exclude"):
					ex.append_array(b.call(&"ray_exclude"))
				elif b is CollisionObject3D:
					ex.append((b as CollisionObject3D).get_rid())
	return ex


func _hit(col: Node, at: Vector3, n: Vector3) -> void:
	var who := _taker(col)
	var by := _by()
	var sbk := SbFx.key_of(info)
	var sbo := {"at": at, "normal": n, "dir": velocity, "info": info, "node": self}
	if not NetSpells.decides():
		# (a ghost: the world or a raised wall ends it here as on the host, its look at once; the wall's wear is the host's word)
		_end_look("wall" if who is FormRaised else "world", at, n)
		_finish("wall" if who is FormRaised else "world")
		return
	if who is FormRaised:
		wear(who as FormRaised, at)
		if not SbFx.fire(by, sbk, "impact", sbo):
			BendLooks.burst(at, kind, 14, n, 70.0, 3.0)
		BendLooks.sound(kind, "hit", at, -4.0)
		if kind == "stone" and weight != "light" and not floor_wave and is_inside_tree():
			_drop_loose(at + n * (radius + 0.05))    # (a stone off a wall lies loose: earth's ammo)
		end("wall")
		return
	if who != null and BendStatus.can_take(who, by):
		var dir := velocity.normalized()
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		if pull and by != null:
			var to := by.global_position - (who as Node3D).global_position
			to.y = 0.0
			flat = to.normalized() if to.length_squared() > 1e-4 else -flat
		BendR3.deliver(who, damage + (6.0 if burning else 0.0), at, dir, by, lock_s, flat * knock_mps + Vector3.UP * up_mps, info)
		if root_s > 0.0:
			BendStatus.root(who, root_s)
		if slow_s > 0.0:
			BendStatus.slow(who, slow_s)
		struck.emit(who, damage)
		SbFx.fire(by, sbk, "body_extra", sbo)
	if not SbFx.fire(by, sbk, "impact", sbo):
		BendLooks.burst(at, kind, 16, n, 80.0, 3.5)
	BendLooks.sound(kind, "hit", at, -3.0)
	end("hit" if who != null else "world")


static func _taker(col: Node) -> Node:
	var n := col
	var depth := 0
	while n != null and depth < 6:
		if n is FormRaised or n is FrontierPlayer or n is NpcFighter or n is WildAnimal or (n is RigidBody3D and not (n is FormStone)):
			return n
		n = n.get_parent()
		depth += 1
	return null


## A stone bolt stopped by a wall: a stone of its size lies at `at`, its caster's loose one (FormStone.make_loose).
func _drop_loose(at: Vector3) -> void:
	var rad := clampf(radius, 0.12, 0.45)
	var s := FormStone.ball(get_tree().current_scene, FormEffects.ground_at(self, at), {"radius_m": rad, "mass_kg": 20.0,
			"rise_s": 0.01, "life_s": 30.0, "sink_s": 1.0}, absi(hash(Vector3i(at * 10.0))) % 97, "stone")
	s.state = FormStone.State.RESTING
	s.freeze = false
	s.set_meta(&"bend_weight", weight)
	FormStone.make_loose(s, _by())


## A raised wall worn by this bolt (WEAR by its kind and the wall's matter; the water jet's erode on an earth wall).
func wear(w: FormRaised, at: Vector3) -> void:
	if w.has_meta(&"bend_brace"):
		w.remove_meta(&"bend_brace")             # (braced: this one is taken free; Catch's brace)
		return
	var ice := w.has_meta(&"bend_ice") or w.matter == "snow"
	var k := float((WEAR.get(kind, [1.0, 1.0]) as Array)[1 if ice else 0])
	if kind == "water" and not ice:
		k *= erode
	var acc := float(w.get_meta(&"bend_wear", 0.0)) + k
	while acc >= 1.0 and is_instance_valid(w) and w.is_up():
		acc -= 1.0
		w.apply_hit(maxf(w.hit_min, damage), at, velocity.normalized())
	if is_instance_valid(w):
		w.set_meta(&"bend_wear", acc)


## A teammate of its caster held in a bind or a float within its reach of its path this step (`a` to `b`) is freed (the owner
## 2026-10-11: allies "break binds to protect them"; BendStatus.rescue). Only a held one is looked at.
func _rescue_on(a: Vector3, b: Vector3) -> void:
	var by := _by()
	if by == null or not is_inside_tree():
		return
	var tree := get_tree()
	for n in tree.get_nodes_in_group(NpcFighter.GROUP) + tree.get_nodes_in_group(&"player"):
		if n == by or not (n is Node3D) or not (BendStatus.bound(n) or BendStatus.floating(n)):
			continue
		var c := (n as Node3D).global_position + Vector3.UP * 0.9
		var ab := b - a
		var u := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if c.distance_to(a + ab * u) <= radius + 0.7:
			BendStatus.rescue(n, by)


func _meet_bolts() -> void:
	for o in get_tree().get_nodes_in_group(GROUP):
		var b := o as BendBolt
		if b == null or b == self or b.spent or b.get_instance_id() < get_instance_id() or b.swinging():
			continue
		if b.global_position.distance_to(global_position) > radius + b.radius + 0.25:
			continue
		meet(self, b)
		if spent:
			return
	# (a flying stone of a GustLift: stone meets stone by weight; anything else is gone, the stone goes on)
	for o in get_tree().get_nodes_in_group(GustLift.GROUP):
		var l := o as GustLift
		if l == null or l.phase != GustLift.Phase.FLIGHT or l.stone == null or not is_instance_valid(l.stone):
			continue
		if l.by() == _by() or l.stone.global_position.distance_to(global_position) > radius + l.radius + 0.3:
			continue
		meet_lift(self, l)
		if spent:
			return


## A bolt meets a flying stone (GustLift): not stone, the bolt is gone; stone, the heavier goes on (the lighter breaks: a
## bolt ends, a lift's stone drops), equal ones both break.
static func meet_lift(a: BendBolt, l: GustLift) -> void:
	var at := (a.global_position + l.stone.global_position) * 0.5
	if a.kind != "stone":
		BendLooks.burst(at, a.kind, 14)
		a.end("stone")
		return
	var wa := int(WEIGHTS.get(a.weight, 1))
	var wb := int(WEIGHTS.get(weight_of(l), 1))
	if not SbFx.fire(a._by(), "clash/stone", "clash", {"at": at, "el": "earth", "node": a}):
		BendLooks.burst(at, "stone", 20)
	if wa <= wb:
		a.end("broken")
	if wb <= wa:
		l.drop()


## Two bolts meet (see the header).
static func meet(a: BendBolt, b: BendBolt) -> void:
	var at := (a.global_position + b.global_position) * 0.5
	var ks := [a.kind, b.kind]
	if a.kind == b.kind and a.kind != "stone":
		if a.kind in ["water", "fire", "ice", "air"] and a.caster != b.caster and not BendCaster.same_team(a.caster, b.caster):
			BendLooks.burst(at, a.kind, 20)
			a.end("cancel")
			b.end("cancel")
		return
	if "water" in ks and "fire" in ks:
		BendLooks.burst(at, "steam", 34, Vector3.UP, 120.0, 3.0, 0.9)
		BendLooks.sound("steam", "hit", at)
		steam(a._by() if a._by() != null else (b._by() if b._by() != null else a), at)
		a.end("steam")
		b.end("steam")
		return
	if "stone" in ks:
		if a.kind == "stone" and b.kind == "stone":
			# (the bigger stone wins: light < medium < heavy; equal ones both break)
			if not SbFx.fire(a._by(), "clash/stone", "clash", {"at": at, "el": "earth", "node": a}):
				BendLooks.burst(at, "stone", 24)
			var wa := int(WEIGHTS.get(a.weight, 1))
			var wb := int(WEIGHTS.get(b.weight, 1))
			if wa <= wb:
				a.end("broken")
			if wb <= wa:
				b.end("broken")
		else:
			var other := b if a.kind == "stone" else a
			BendLooks.burst(at, other.kind, 14)
			other.end("stone")
		return
	if "fire" in ks and "ice" in ks:
		var ice := a if a.kind == "ice" else b
		var fire := b if ice == a else a
		BendLooks.burst(at, "water", 14)
		ice.end("melted")
		fire.damage *= 0.5
		return
	if "air" in ks and "fire" in ks:
		var air := a if a.kind == "air" else b
		var fire := b if air == a else a
		air.burning = true
		if air._fire_trail == null:
			air._fire_trail = BendLooks.trail(air, "fire", air.radius)
		fire.end("carried")
		return
	if "air" in ks and "water" in ks:
		var water := a if a.kind == "water" else b
		BendLooks.burst(at, "water", 18, Vector3.UP, 180.0, 2.5)
		water.end("scattered")


## A short steam cloud where water met fire at `at` (BendZone "steam", STEAM_R round, STEAM_S long; on the ground under it
## when that is near, so it stands between whoever is about): it hides a man behind it from a bot (NpcBendCaster.hidden).
## `by` any node in the scene (whose fire or water it was).
static func steam(by: Node3D, at: Vector3) -> BendZone:
	if by == null or not is_instance_valid(by) or not by.is_inside_tree():
		return null
	var g := FormEffects.ground_at(by, at)
	var foot := g if at.y - g.y < 2.5 and at.y >= g.y - 0.5 else at - Vector3.UP * 1.0
	return BendZone.make(by, "steam", foot, {"radius_m": STEAM_R, "life_s": STEAM_S})


## Turned along `dir` (its speed kept), now `by`'s. A floor wave keeps to the floor (the line's yaw only).
func redirect(dir: Vector3, by: Node3D) -> void:
	if floor_wave:
		dir = Vector3(dir.x, 0.0, dir.z)
		if dir.length_squared() < 1e-6:
			dir = -velocity
	velocity = dir.normalized() * velocity.length()
	if by != caster:
		info = BendZone.return_info(info, by, global_position, 1.0)      # (round 3: sent back, the sender's now: a return)
	caster = by
	travelled = 0.0
	_face()


func end(why: String) -> void:
	if spent:
		return
	if not why in NetSpells.OWN_ENDS and not NetSpells.decide(self, "end", [why, global_position]):
		return                                    # (a ghost's: the host's word ends it, net_end)
	_finish(why)


func _finish(why: String) -> void:
	if spent:
		return
	spent = true
	remove_from_group(GROUP)
	BendSounds.flight_end(self)
	BendLooks.stop_trail(_trail)
	BendLooks.stop_trail(_fire_trail)
	ended.emit(why)
	queue_free()


# ---------------------------------------------------------------- online (see the header's ONLINE)
## The bodies, stones and props a ghost has passed (its flight's exclusions): the host's word decides what they did to it.
var _ghost_ex: Array[RID] = []
## Its state as last told (the host's): what a meeting changes, compared each frame.
var _net_sig: Array = []


## A ghost's flight meeting `col` (`info` the shape's rest info): true when it passes (a body, a stone, a prop: the host's
## to decide), the thing's RID kept out of its flight from now; false: the world or a raised wall, it ends there.
func _ghost_through(col: Node, info: Dictionary) -> bool:
	var who := _taker(col)
	if who is FormRaised:
		return false
	if who == null and not (col is RigidBody3D) and not (col is CharacterBody3D):
		return false
	if info.has("rid"):
		_ghost_ex.append(info.rid)
	return true


## The host's: its state told when a meeting has changed it since it was last told (its caster, kind, fire, numbers, the
## guards it met, a swing begun or over); its first frame only remembered (its cast told the others how it began).
func _net_check() -> void:
	if not NetSpells.online() or not NetSpells.decides() or NetSpells.id_of(self) == "":
		return
	var sig := [_by().get_instance_id() if _by() != null else 0, kind, burning, snappedf(damage, 0.01), snappedf(knock_mps, 0.01),
			snappedf(up_mps, 0.01), guarded_by.size(), _swing_t >= 0.0, bool(info.get("returned", false))]
	if _net_sig.is_empty():
		_net_sig = sig
		return
	if sig == _net_sig:
		return
	_net_sig = sig
	var sw: Array = []
	if _swing_t >= 0.0:
		sw = [_swing_by, _swing_s, _swing_r, _swing_k, kind]
	NetSpells.word(["bolt", NetSpells.id_of(self), {"p": global_position, "v": velocity, "by": _by(), "kind": kind,
			"burning": burning, "dmg": damage, "kn": knock_mps, "up": up_mps, "tr": travelled, "info": info, "sw": sw}])


## The host's word on it (a ghost's): its state as the host's bolt has it now (_net_check's): a swing begun round its guard
## (its look and its turn there, begin_swing), a swing over, a new kind, a fire taken, its place, way, numbers and caster.
func net_state(d: Dictionary) -> void:
	var sw: Array = d.get("sw", [])
	if not sw.is_empty() and _swing_t < 0.0 and sw[0] is Node3D:
		global_position = d.get("p", global_position)
		begin_swing(sw[0] as Node3D, float(sw[1]), float(sw[2]), float(sw[3]), String(sw[4]))
		return
	if sw.is_empty() and _swing_t >= 0.0:
		_swing_t = -1.0                           # (the host's swing is over: it leaves as his did)
		_leave_look()
	if String(d.get("kind", kind)) != kind:
		become(String(d.kind))
	if bool(d.get("burning", false)) and not burning:
		burning = true
		if _fire_trail == null:
			_fire_trail = BendLooks.trail(self, "fire", radius)
	var by: Variant = d.get("by")
	if by is Node3D:
		caster = by as Node3D
	global_position = d.get("p", global_position)
	velocity = d.get("v", velocity)
	damage = float(d.get("dmg", damage))
	knock_mps = float(d.get("kn", knock_mps))
	up_mps = float(d.get("up", up_mps))
	travelled = float(d.get("tr", travelled))
	if d.get("info") is Dictionary:
		info = d.info
	_ghost_ex.clear()                             # (turned: whatever it passed it may meet again on its new way)
	_face()


## The host's word that it ended (a ghost's): put where the host's ended, its ending's look there, gone.
func net_end(why: String, at: Vector3) -> void:
	if spent:
		return
	global_position = at
	_end_look(why, at, -velocity.normalized() if velocity.length_squared() > 1e-6 else Vector3.UP)
	_finish(why)


## The look of its ending `why` at `at` (`n` the face it met): a ghost's own ends and the host's words (the host played the
## same where it decided).
func _end_look(why: String, at: Vector3, n: Vector3) -> void:
	match why:
		"hit", "wall", "world":
			if not SbFx.fire(_by(), SbFx.key_of(info), "impact", {"at": at, "normal": n, "dir": velocity, "info": info, "node": self}):
				BendLooks.burst(at, kind, 16 if why != "wall" else 14, n, 80.0, 3.5)
			BendLooks.sound(kind, "hit", at, -3.0)
		"steam":
			BendLooks.burst(at, "steam", 34, Vector3.UP, 120.0, 3.0, 0.9)
			BendLooks.sound("steam", "hit", at)
		"broken":
			if not SbFx.fire(_by(), "clash/stone", "clash", {"at": at, "el": "earth", "node": self}):
				BendLooks.burst(at, "stone", 24)
		"melted", "bubble":
			BendLooks.burst(at, "water", 14)
		"scattered":
			BendLooks.burst(at, "water", 18, Vector3.UP, 180.0, 2.5)
		"cancel", "stone", "blocked", "dropped":
			BendLooks.burst(at, kind, 14)


## Flown on `s` seconds at once, a physics tick at a time (NetCasts.catch_up: a cast run here as old as the wire made it), its
## meetings as they go (the host's: decided; a ghost's: passed).
func catch_up(s: float) -> void:
	var step := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	while s > 1e-4 and not spent and is_inside_tree():
		var d := minf(step, s)
		_physics_process(d)
		s -= d


## A turned bolt's look as it leaves a swing (drawn back to its length: become's wrap).
func _leave_look() -> void:
	if _swing_became:
		_swing_became = false
		if _look != null and is_instance_valid(_look):
			create_tween().tween_property(_look, ^"scale", Vector3.ONE, WRAP_OUT_S)
