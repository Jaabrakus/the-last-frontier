extends SceneTree
## Review round 2 probe (read-only): what CascadeFx.sample() (a PackedFloat32Array per call, read for [0], [1], [2] right after) costs
## against a table read that returns a Vector3 with no array, on the real tables of the imported effects (ColorOverLife,
## SizeMultiplyLife, SizeScale, VelocityOverLifetime ...), and how many of those calls one particle update makes.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/fx/review_r2_sample.gd

const N := 200000


## The same arithmetic as CascadeFx.sample for the first three components, no array.
static func sample3(t, time: float, rnd: float) -> Vector3:
	if t == null or not (t is Dictionary) or not t.has("v"):
		return Vector3.ZERO
	var v: Array = t.v
	var n: int = int(t.n)
	var stride: int = int(t.stride)
	var sub: int = int(t.sub)
	var op: int = int(t.op)
	var i0 := 0
	var i1 := 0
	var f := 0.0
	if n > 1:
		var x := clampf((time - float(t.tb)) * float(t.ts), 0.0, float(n - 1))
		i0 = int(floor(x))
		i1 = mini(i0 + 1, n - 1)
		f = x - float(i0)
	var out := Vector3.ZERO
	for k in mini(maxi(sub, 1), 3):
		if i1 * stride + k >= v.size():
			break
		var a0: float = lerpf(float(v[i0 * stride + k]), float(v[i1 * stride + k]), f)
		if (op == 2 or op == 3) and i1 * stride + sub + k < v.size():
			var b0: float = lerpf(float(v[i0 * stride + sub + k]), float(v[i1 * stride + sub + k]), f)
			a0 = lerpf(a0, b0, rnd) if op == 2 else (b0 if rnd > 0.5 else a0)
		out[k] = a0
	return out


## The same table read from typed members (what an Emitter.init() could build once per module table).
class Tab:
	var v := PackedFloat32Array()
	var n := 1
	var stride := 1
	var sub := 1
	var op := 1
	var tb := 0.0
	var ts := 1.0

	static func of(t: Dictionary) -> Tab:
		var o := Tab.new()
		o.v = PackedFloat32Array(t.v)
		o.n = int(t.n)
		o.stride = int(t.stride)
		o.sub = int(t.sub)
		o.op = int(t.op)
		o.tb = float(t.tb)
		o.ts = float(t.ts)
		return o

	func s1(time: float, rnd: float) -> float:
		if sub < 1:
			return 0.0
		var i0 := 0
		var i1 := 0
		var f := 0.0
		if n > 1:
			var x := clampf((time - tb) * ts, 0.0, float(n - 1))
			i0 = int(x)
			i1 = mini(i0 + 1, n - 1)
			f = x - float(i0)
		if i1 * stride >= v.size():
			return 0.0
		var a0: float = lerpf(v[i0 * stride], v[i1 * stride], f)
		if (op == 2 or op == 3) and i1 * stride + sub < v.size():
			var b0: float = lerpf(v[i0 * stride + sub], v[i1 * stride + sub], f)
			a0 = lerpf(a0, b0, rnd) if op == 2 else (b0 if rnd > 0.5 else a0)
		return a0


func _initialize() -> void:
	var tabs: Array = []
	var calls := {}
	var emitters := 0
	for id in SpellFx.effect_ids():
		for es: Dictionary in SpellFx.spec(id).emitters:
			if not es.enabled:
				continue
			emitters += 1
			for m: Dictionary in es.modules:
				if not m.enabled:
					continue
				var cls := String(m["class"]).trim_suffix("_Seeded")
				if cls in ["ColorOverLife", "SizeMultiplyLife", "SizeScale", "VelocityOverLifetime"]:
					var key := "ColorOverLife" if cls == "ColorOverLife" else ("SizeMultiplyLife" if cls == "SizeMultiplyLife" else
							("SizeScale" if cls == "SizeScale" else "VelOverLife"))
					var t = m.get(key)
					if t is Dictionary and t.has("v"):
						tabs.append(t)
						calls[cls] = int(calls.get(cls, 0)) + 1
	print("REVIEW sample: %d tables from %d emitters, by class %s" % [tabs.size(), emitters, calls])
	var consts := 0
	for t: Dictionary in tabs:
		if int(t.n) <= 1:
			consts += 1
	print("  tables with n <= 1 (a constant: read again every frame per particle): %d of %d" % [consts, tabs.size()])
	var sink := 0.0
	var t0 := Time.get_ticks_usec()
	for i in N:
		var a := CascadeFx.sample(tabs[i % tabs.size()], float(i % 100) / 100.0, 0.0)
		sink += a[0] + (a[1] if a.size() > 1 else a[0]) + (a[2] if a.size() > 2 else a[0])
	var us_sample := float(Time.get_ticks_usec() - t0) / float(N)
	t0 = Time.get_ticks_usec()
	for i in N:
		var b := sample3(tabs[i % tabs.size()], float(i % 100) / 100.0, 0.0)
		sink += b.x + b.y + b.z
	var us_s3 := float(Time.get_ticks_usec() - t0) / float(N)
	t0 = Time.get_ticks_usec()
	for i in N:
		sink += CascadeFx.s1(tabs[i % tabs.size()], float(i % 100) / 100.0, 0.0)
	var us_s1 := float(Time.get_ticks_usec() - t0) / float(N)
	print("  per call: sample() + three reads %.3f us, array-free sample3 %.3f us, s1 %.3f us  (%.0f)" % [us_sample, us_s3, us_s1, sink])
	var typed: Array = []
	for t: Dictionary in tabs:
		typed.append(Tab.of(t))
	t0 = Time.get_ticks_usec()
	for i in N:
		sink += (typed[i % typed.size()] as Tab).s1(float(i % 100) / 100.0, 0.0)
	var us_typed := float(Time.get_ticks_usec() - t0) / float(N)
	var diff := 0
	for i in tabs.size():
		for time in [0.0, 0.3, 0.77, 1.0]:
			if not is_equal_approx(CascadeFx.s1(tabs[i], time, 0.5), (typed[i] as Tab).s1(time, 0.5)):
				diff += 1
	print("  typed-member table read (s1 equivalent) %.3f us per call (vs s1 %.3f); %d value differences" % [us_typed, us_s1, diff])
	# a value check: sample3 == sample on every table at a few times
	var bad := 0
	for t: Dictionary in tabs:
		for time in [0.0, 0.3, 0.77, 1.0]:
			for rnd in [0.0, 0.5, 1.0]:
				var a := CascadeFx.sample(t, time, rnd)
				var b := sample3(t, time, rnd)
				for k in 3:
					var av: float = a[k] if k < a.size() else 0.0
					if not is_equal_approx(av, b[k]) and k < a.size():
						bad += 1
	print("  sample3 differs from sample on %d component reads" % bad)
	quit(0)
