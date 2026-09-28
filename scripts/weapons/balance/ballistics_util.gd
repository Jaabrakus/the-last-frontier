class_name BallisticsUtil
## Small ballistic helpers for the weapon balance (weapons_balance_design.md sections 1.1, 1.6,
## 1.9 and 3.3). Every flight here is stepped exactly like Projectile / ThrownProjectile and
## Weapon._height_at: per physics tick, gravity, then linear drag, then move.
##
##   max_carry_elevation(speed, g, drag)    elevation of the longest carry back to launch
##                                          height (cached): the out-of-reach fallback of H3
##   fallback_elevation(dist, dy, theta, speed, g, drag)
##                                          the elevation H3 uses when the Newton solve of
##                                          Weapon.ballistic_dir misses: a target it can still
##                                          reach lower down (steeper than the solver's -80 deg
##                                          clamp: straight down off a wall or a cliff) is solved
##                                          by bisection; a target out of reach is thrown at the
##                                          longest-carry elevation, never flatter than the aim line
##   zeroed_dir(origin, target, speed, g, drag)
##                                          Weapon.ballistic_dir with H3 applied: a target out
##                                          of reach is thrown as far as it goes, so a full-power
##                                          shot falls short past its reach instead of going
##                                          into the ground in front of the thrower
##   effective_range(cone_deg)              torso-disc D50 of a cone: 0.5 / tan(cone)
##   hit_chance(dist, cone_deg)             chance of hitting the 0.5 m torso disc at `dist`
##   falloff(speed, start_speed, exponent)  the impact damage multiplier of Projectile and
##                                          ThrownProjectile._on_impact (exponent 1: today's law;
##                                          set B's Projectile.falloff_exp 0 for arrows)
##
## Hook H3 in Weapon.ballistic_dir: three lines replacing the final straight-line fallback,
##     var h := _height_at(dist, theta, speed, gravity, drag, dt)
##     if is_nan(h) or absf(h - to.y) > 0.05:   # missed: out of reach, or steeper down than the clamp
##         theta = BallisticsUtil.fallback_elevation(dist, to.y, theta, speed, gravity, drag)
## and, in the Newton loop, the clamp widened so targets nearly overhead converge too:
##         theta = clampf(theta - miss / slope, -1.55, 1.55)
## (tools/weapons/range_sim.py game_ballistic_theta_h3 ports exactly this; with both, every
## reachable target of the review grid, 1.2 m to 2.5 x reach and 60 m below to 60 m above, lands
## within 5 cm.)
## (The first review's version, `theta = maxf(max_carry_elevation(...), atan2(to.y, dist))` for
## every miss, also lobbed shots aimed steeply DOWN: a target 1.2 m out and 7.5 m below, beyond
## the solver's -80.2 deg clamp, sent a musket ball up at 11.6 deg to land 726 m away, where the
## unfixed code misses by 0.5 m. fallback_elevation keeps the lob for targets out of reach only.)

const TORSO_RADIUS := 0.25          ## The 0.5 m torso disc of the effective-range definition.
const FALLOFF_FLOOR := 0.35         ## Projectile._on_impact: damage never drops below 35 %.
const REACH_TOLERANCE := 0.05       ## Metres of miss at the target that still count as "reached".
const STEEPEST := 1.5608            ## rad (89.43 deg): the steepest launch fallback_elevation tries.

static var _carry_cache := {}


## Elevation (rad) of the longest carry back to launch height, stepped like Projectile. Cached.
static func max_carry_elevation(speed: float, gravity: float, drag: float) -> float:
	var key := Vector3(speed, gravity, drag)
	if _carry_cache.has(key):
		return _carry_cache[key]
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var a := 0.0
	var b := 1.3
	for i in 28:   # golden-section search on the carry
		var c := b - 0.618034 * (b - a)
		var d := a + 0.618034 * (b - a)
		if _carry(c, speed, gravity, drag, dt) > _carry(d, speed, gravity, drag, dt):
			b = d
		else:
			a = c
	_carry_cache[key] = (a + b) * 0.5
	return _carry_cache[key]


## Longest carry (m) back to launch height at the best elevation.
static func max_carry(speed: float, gravity: float, drag: float) -> float:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	return _carry(max_carry_elevation(speed, gravity, drag), speed, gravity, drag, dt)


## Horizontal distance at which a shot at elevation `theta` comes back to launch height.
static func _carry(theta: float, speed: float, g: float, drag: float, dt: float) -> float:
	var vx := cos(theta) * speed
	var vy := sin(theta) * speed
	var x := 0.0
	var y := 0.0
	for step in 12000:
		vy -= g * dt
		var k := maxf(1.0 - drag * dt, 0.0)
		vx *= k
		vy *= k
		var ny := y + vy * dt
		if ny < 0.0 and vy < 0.0:
			return x + vx * dt * y / (y - ny)
		x += vx * dt
		y = ny
	return x


## True when the zeroed shot from `origin` can land on `target` (within REACH_TOLERANCE).
static func in_reach(origin: Vector3, target: Vector3, speed: float, gravity: float, drag: float) -> bool:
	var to := target - origin
	var dist := Vector2(to.x, to.z).length()
	if dist < 1.0 or (gravity <= 0.0 and drag <= 0.0):
		return true
	var dir := Weapon.ballistic_dir(origin, target, speed, gravity, drag)
	var theta := atan2(dir.y, Vector2(dir.x, dir.z).length())
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var h := Weapon._height_at(dist, theta, speed, gravity, drag, dt)
	return not is_nan(h) and absf(h - to.y) <= REACH_TOLERANCE


## Weapon.ballistic_dir with hook H3: whenever its solve misses, fallback_elevation. Where the
## solve lands on the target it returns exactly Weapon.ballistic_dir.
static func zeroed_dir(origin: Vector3, target: Vector3, speed: float, gravity: float, drag: float) -> Vector3:
	var dir := Weapon.ballistic_dir(origin, target, speed, gravity, drag)
	var to := target - origin
	var flat := Vector3(to.x, 0.0, to.z)
	var dist := flat.length()
	if dist < 1.0 or (gravity <= 0.0 and drag <= 0.0):
		return dir
	var theta := atan2(dir.y, Vector2(dir.x, dir.z).length())
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var h := Weapon._height_at(dist, theta, speed, gravity, drag, dt)
	if not is_nan(h) and absf(h - to.y) <= REACH_TOLERANCE:
		return dir
	theta = fallback_elevation(dist, to.y, theta, speed, gravity, drag)
	return (flat / dist * cos(theta) + Vector3.UP * sin(theta)).normalized()


## The elevation (rad) for a target `dist` m away and `dy` m above the launch point when the Newton
## solve of Weapon.ballistic_dir ended at `theta` without landing on it (hook H3):
##   * a shot passes ABOVE the target (at `theta`, or, for a target below, launched level or at
##     the solver's -1.4 rad clamp): the target is reachable lower down, beyond that clamp (aimed
##     steeply down off a wall, a ledge or a cliff), so bisect between the steepest launch and
##     that elevation for the one that meets it;
##   * otherwise it is out of reach: the longest-carry elevation, never flatter than the aim
##     line (a full-power shot falls short past its reach; aimed nearly overhead, the aim line).
## A shot that never gets `dist` out counts as passing below. The out-of-reach case costs one
## cached lookup and at most three flights that stop once they drop below the target (cheap
## enough for the arcs, which solve every physics tick); the steep-down case about 30 short ones.
static func fallback_elevation(dist: float, dy: float, theta: float, speed: float, gravity: float, drag: float) -> float:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var hi := theta
	var above := _h_or_low(dist, dy, theta, speed, gravity, drag, dt) > dy
	if not above and dy < 0.0:
		# Aimed so steeply down that the solve went NaN (Weapon._height_at gives up once the
		# horizontal speed is under 0.5 m/s): a level or clamped launch may still pass above.
		for probe: float in [0.0, -1.4]:
			if _h_or_low(dist, dy, probe, speed, gravity, drag, dt) > dy:
				above = true
				hi = probe
				break
	if above:
		var lo := -STEEPEST
		for i in 30:
			var mid := (lo + hi) * 0.5
			if _h_or_low(dist, dy, mid, speed, gravity, drag, dt) < dy:
				lo = mid
			else:
				hi = mid
		return (lo + hi) * 0.5
	return maxf(max_carry_elevation(speed, gravity, drag), atan2(dy, dist))


## Weapon._height_at (the same steps), except that a flight already coming down below `dy`
## stops there, and one that never gets `dist` out gives -INF: "passes below" either way.
static func _h_or_low(dist: float, dy: float, theta: float, speed: float, g: float, drag: float, dt: float) -> float:
	var vx := cos(theta) * speed
	var vy := sin(theta) * speed
	var x := 0.0
	var y := 0.0
	for step in 6000:
		vy -= g * dt
		var k := maxf(1.0 - drag * dt, 0.0)
		vx *= k
		vy *= k
		var nx := x + vx * dt
		var ny := y + vy * dt
		if nx >= dist:
			return y + (ny - y) * (dist - x) / (nx - x)
		x = nx
		y = ny
		if vx < 0.5 or (vy <= 0.0 and y < dy):
			break
	return -INF


## Torso-disc D50 (m) of a cone: half the shots land inside the 0.5 m disc up to here.
static func effective_range(cone_deg: float) -> float:
	var t := tan(deg_to_rad(maxf(cone_deg, 1e-4)))
	return 2.0 * TORSO_RADIUS / t


## Chance that a shot with this cone lands inside the 0.5 m torso disc at `dist` metres
## (Weapon.apply_spread draws the miss radius uniformly in [0, d tan(cone)]).
static func hit_chance(dist: float, cone_deg: float) -> float:
	var r := dist * tan(deg_to_rad(maxf(cone_deg, 0.0)))
	return 1.0 if r <= TORSO_RADIUS else TORSO_RADIUS / r


## Impact damage multiplier: clamp((v / v0) ^ exponent, 0.35, 1). Exponent 1 is today's law in
## Projectile and ThrownProjectile._on_impact; set B gives arrows 0 (a broadhead cuts).
static func falloff(speed: float, start_speed: float, exponent := 1.0) -> float:
	var ratio := speed / maxf(start_speed, 0.01)
	return clampf(pow(maxf(ratio, 0.0), exponent), FALLOFF_FLOOR, 1.0)
