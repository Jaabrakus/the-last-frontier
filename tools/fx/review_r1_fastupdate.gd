extends SceneTree
## Review round 1 probe (read-only), GENERATED from cascade_fx.gd's Emitter._update_one by a throwaway script: the same
## body with every all("X") / one("X") call replaced by a member read primed once (what a per-emitter module cache in init()
## would do), timed against the original on the same spec and particle.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r1_fastupdate.gd


class FastEmitter:
	extends CascadeFx.Emitter

	var _a_AccelerationConstant: Array = []
	var _a_AccelerationDrag: Array = []
	var _a_AccelerationDragScaleOverLife: Array = []
	var _a_AccelerationOverLifetime: Array = []
	var _a_AttractorPoint: Array = []
	var _a_AttractorPointGravity: Array = []
	var _a_ColorOverLife: Array = []
	var _a_ColorScaleOverLife: Array = []
	var _a_MeshRotationRateMultiplyLife: Array = []
	var _a_MeshRotationRateOverLife: Array = []
	var _a_ParameterDynamic: Array = []
	var _a_RotationOverLifetime: Array = []
	var _a_RotationRateMultiplyLife: Array = []
	var _a_SizeMultiplyLife: Array = []
	var _a_SizeScale: Array = []
	var _a_SizeScaleBySpeed: Array = []
	var _a_VelocityOverLifetime: Array = []
	var _o_Collision = null
	var _has_movie := false
	var _has_subuv := false

	func prime() -> void:
		_a_AccelerationConstant = all("AccelerationConstant")
		_a_AccelerationDrag = all("AccelerationDrag")
		_a_AccelerationDragScaleOverLife = all("AccelerationDragScaleOverLife")
		_a_AccelerationOverLifetime = all("AccelerationOverLifetime")
		_a_AttractorPoint = all("AttractorPoint")
		_a_AttractorPointGravity = all("AttractorPointGravity")
		_a_ColorOverLife = all("ColorOverLife")
		_a_ColorScaleOverLife = all("ColorScaleOverLife")
		_a_MeshRotationRateMultiplyLife = all("MeshRotationRateMultiplyLife")
		_a_MeshRotationRateOverLife = all("MeshRotationRateOverLife")
		_a_ParameterDynamic = all("ParameterDynamic")
		_a_RotationOverLifetime = all("RotationOverLifetime")
		_a_RotationRateMultiplyLife = all("RotationRateMultiplyLife")
		_a_SizeMultiplyLife = all("SizeMultiplyLife")
		_a_SizeScale = all("SizeScale")
		_a_SizeScaleBySpeed = all("SizeScaleBySpeed")
		_a_VelocityOverLifetime = all("VelocityOverLifetime")
		_o_Collision = one("Collision")
		_has_movie = mods.has("SubUVMovie")
		_has_subuv = mods.has("SubUV")

	func _update_one_fast(p: CascadeFx.Particle, dt: float, out_events: Dictionary) -> bool:
		p.age += dt
		p.rt = clampf(p.age / p.life, 0.0, 1.0) if p.life < INF else 0.0
		var rt := p.rt
		var et := time / maxf(duration, 1e-4)
		p.color = p.base_color
		for m in _a_ColorOverLife:
			var c := CascadeFx.sample(m.get("ColorOverLife"), rt, 0.0)
			p.color = Color(c[0], c[1] if c.size() > 1 else c[0], c[2] if c.size() > 2 else c[0], p.color.a)
			if m.has("AlphaOverLife"):
				p.color.a = CascadeFx.s1(m.AlphaOverLife, rt, 0.0)
			if m.get("bClampAlpha", true):
				p.color.a = clampf(p.color.a, 0.0, 1.0)
		for m in _a_ColorScaleOverLife:
			var tt := et if m.get("bEmitterTime", false) else rt
			var c := CascadeFx.sample(m.get("ColorScaleOverLife"), tt, 0.0)
			p.color.r *= c[0]
			p.color.g *= c[1] if c.size() > 1 else c[0]
			p.color.b *= c[2] if c.size() > 2 else c[0]
			if m.has("AlphaScaleOverLife"):
				p.color.a *= CascadeFx.s1(m.AlphaScaleOverLife, tt, 0.0)
		p.size = p.base_size
		for m in _a_SizeMultiplyLife:
			var k := CascadeFx.sample(m.LifeMultiplier, rt, 0.0)
			var kx := k[0]
			var ky: float = k[1] if k.size() > 1 else k[0]
			var kz: float = k[2] if k.size() > 2 else k[0]
			p.size = Vector3(p.size.x * (kx if m.get("MultiplyX", true) else 1.0), p.size.y * (ky if m.get("MultiplyY", true) else 1.0), p.size.z * (kz if m.get("MultiplyZ", true) else 1.0))
		for m in _a_SizeScale:
			var k := CascadeFx.sample(m.SizeScale, rt, 0.0)
			p.size = Vector3(p.base_size.x * k[0], p.base_size.y * (k[1] if k.size() > 1 else k[0]), p.base_size.z * (k[2] if k.size() > 2 else k[0]))
		for m in _a_SizeScaleBySpeed:
			var sp := world_vel(p).length() / CascadeFx.CM
			var sc: Array = m.get("SpeedScale", [1, 1])
			var mx: Array = m.get("MaxScale", [1, 1])
			p.size.x *= clampf(sp * float(sc[0]), 1.0, float(mx[0]))
			p.size.y *= clampf(sp * float(sc[1] if sc.size() > 1 else sc[0]), 1.0, float(mx[1] if mx.size() > 1 else mx[0]))
		for m in _a_VelocityOverLifetime:
			var k := CascadeFx.sample(m.VelOverLife, rt, 0.0)
			var f := CascadeFx.ue_axes(CascadeFx.v3(k))
			if m.get("Absolute", false):
				var av := CascadeFx.ue(CascadeFx.v3(k))
				p.vel = av if s.local_space or m.get("bInWorldSpace", false) else comp().basis * av
				p.base_vel = p.vel
			elif s.local_space:
				p.vel = p.base_vel * f
			else:
				var b := comp().basis.orthonormalized()
				p.vel = b * ((b.inverse() * p.base_vel) * f)
		for m in _a_AccelerationConstant:
			var a := CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(m.get("Acceleration"), rt, 0.5))) if m.get("Acceleration") is Dictionary else CascadeFx.ue(m.get("Acceleration", [0, 0, 0]))
			p.vel += a * dt
		p.vel += p.accel * dt
		for m in _a_AccelerationOverLifetime:
			var a := CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(m.AccelOverLife, rt, 0.0)))
			p.vel += (a if m.get("bAlwaysInWorldSpace", false) or s.local_space else comp().basis * a) * dt
		var drag := 0.0
		for m in _a_AccelerationDrag:
			drag += CascadeFx.s1(m.get("DragCoefficientRaw"), rt, 0.5)
		for m in _a_AccelerationDragScaleOverLife:
			drag *= CascadeFx.s1(m.get("DragScaleRaw"), rt, 0.0)
		if drag != 0.0:
			p.vel -= p.vel * minf(drag * dt, 1.0)
		for m in _a_AttractorPoint:
			var pt := comp() * CascadeFx.ue(CascadeFx.v3(CascadeFx.sample(m.get("Position"), rt, 0.5)))
			var rng := CascadeFx.s1(m.get("Range"), rt, 0.5) * CascadeFx.CM
			var str_ := CascadeFx.s1(m.get("Strength"), rt, 0.5) * CascadeFx.CM
			var d := pt - world_pos(p)
			var dist := d.length()
			if dist < rng and dist > 1e-4:
				var k := str_ * ((1.0 - dist / rng) if m.get("StrengthByDistance", true) else 1.0)
				var acc := d / dist * k
				if s.local_space:
					acc = comp().basis.inverse() * acc
				p.vel += acc * dt
		for m in _a_AttractorPointGravity:
			var pt := comp() * CascadeFx.ue(m.get("Position", [0, 0, 0]))
			var d := pt - world_pos(p)
			var dist := maxf(d.length(), float(m.get("Radius", 1.0)) * CascadeFx.CM)
			var g := CascadeFx.s1(m.get("Strength"), rt, 0.5) * CascadeFx.CM
			p.vel += d.normalized() * g / (dist * dist) * dt
		for m in _a_ParameterDynamic:
			var dp: Array = m.get("DynamicParams", [])
			for k in mini(dp.size(), 4):
				var d: Dictionary = dp[k]
				var tt := et if d.get("bUseEmitterTime", false) else rt
				var val := CascadeFx.s1(d.value, tt, p.rnd)
				match String(d.get("method", "EDPV_UserSet")):
					"EDPV_VelocityX": val *= world_vel(p).x / CascadeFx.CM
					"EDPV_VelocityY": val *= world_vel(p).z / CascadeFx.CM
					"EDPV_VelocityZ": val *= world_vel(p).y / CascadeFx.CM
					"EDPV_VelocityMag": val *= world_vel(p).length() / CascadeFx.CM
				p.dyn[k] = val
		var rr := 1.0
		for m in _a_RotationRateMultiplyLife:
			rr *= CascadeFx.s1(m.LifeMultiplier, rt, 0.0)
		p.rot_rate = p.base_rot_rate * rr
		for m in _a_RotationOverLifetime:
			var r := CascadeFx.s1(m.RotationOverLife, rt, 0.0)
			p.rot = p.rot * r if m.get("Scale", true) else p.rot + r * dt
		var mr := p.base_mesh_rot_rate
		for m in _a_MeshRotationRateMultiplyLife:
			var k := CascadeFx.sample(m.LifeMultiplier, rt, 0.0)
			mr *= Vector3(k[0], k[1] if k.size() > 1 else k[0], k[2] if k.size() > 2 else k[0])
		for m in _a_MeshRotationRateOverLife:
			var k := CascadeFx.sample(m.RotRate, rt, 0.0)
			var kv := Vector3(k[0], k[1] if k.size() > 1 else 0.0, k[2] if k.size() > 2 else 0.0)
			mr = mr * kv if m.get("bScaleRotRate", false) else mr + kv
		p.mesh_rot_rate = mr
		if _has_movie:
			var fr := CascadeFx.s1(mods.SubUVMovie.get("FrameRate"), rt, 0.0)
			var images: int = int(s.subuv[0]) * int(s.subuv[1])
			p.image = fposmod(p.image + fr * dt, float(maxi(images, 1)))
		elif _has_subuv and not String(s.subuv_method).begins_with("PSUVIM_Random"):
			p.image = CascadeFx.s1(mods.SubUV.get("SubImageIndex"), rt, p.rnd)
		p.pos += p.vel * dt
		p.rot += p.rot_rate * dt
		p.mesh_rot += p.mesh_rot_rate * dt
		p.orbit_rot += p.orbit_rate * dt
		var col = _o_Collision
		if col != null and not s.local_space:
			var r := maxf(p.size.x, 1.0) * CascadeFx.CM * 0.5 * float(col.get("DirScalar", 0.5) if col.get("DirScalar") is float else 0.5)
			if p.pos.y < sys.ground_y + r and p.vel.y < 0.0:
				p.pos.y = sys.ground_y + r
				var damp := CascadeFx.ue_axes(CascadeFx.v3(CascadeFx.sample(col.get("DampingFactor"), rt, dice.randf())))
				p.vel = Vector3(p.vel.x * damp.x, -p.vel.y * damp.y, p.vel.z * damp.z)
				p.base_vel = p.vel
				p.collisions += 1
				_emit_event(p, "EPET_Collision", out_events)
				var maxc := int(CascadeFx.s1(col.get("MaxCollisions"), 0.0, dice.randf())) if col.get("MaxCollisions") is Dictionary else int(col.get("MaxCollisions", 0))
				if maxc > 0 and p.collisions >= maxc:
					match String(col.get("CollisionCompletionOption", "EPCC_Kill")):
						"EPCC_Kill":
							return false
						"EPCC_Freeze", "EPCC_FreezeTranslation", "EPCC_FreezeMovement":
							p.vel = Vector3.ZERO
							p.base_vel = Vector3.ZERO
		return true



func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	var player := SpellFx.of(root)
	player.set_process(false)
	var N := 200000
	var tot_b := 0.0
	var tot_f := 0.0
	var cnt := 0
	for id: String in ["g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP", "g3/Content/VFX/Character/Wind/TornadoNewSimple",
			"g3/Content/VFX/Character/Fire/FireWall_FX_TranslucentSmoke", "g3/Content/VFX/Character/Earth/EarthImpactAOE_FX_Meteor"]:
		var h := SpellFx.spawn(id, Vector3(0, 1, -3))
		for f in 40:
			await process_frame
			h.fx.step(1.0 / 60.0)
		var sb := 0.0
		var sf := 0.0
		var k := 0
		for e in h.fx.emitters:
			if e.particles.is_empty() or e.s.type == "ribbon" or e.s.type == "beam" or e.s.type == "anim_trail":
				continue
			var p = e.particles[0]
			var q = e.particles[0]
			var t0 := Time.get_ticks_usec()
			for i in N:
				e._update_one(p, 0.0, {})
			var base := float(Time.get_ticks_usec() - t0) / N
			var fe := FastEmitter.new()
			fe.sys = h.fx
			fe.index = e.index
			fe.init(e.s)
			fe.prime()
			t0 = Time.get_ticks_usec()
			for i in N:
				fe._update_one_fast(q, 0.0, {})
			var fast := float(Time.get_ticks_usec() - t0) / N
			sb += base
			sf += fast
			k += 1
			fe.free_render()
		print("%-34s %d emitters: _update_one avg %.2f us -> %.2f us with module lookups primed once (%.0f %% saved)" % [id.get_file(), k, sb / maxf(k, 1), sf / maxf(k, 1), 100.0 * (1.0 - sf / maxf(sb, 1e-6))])
		tot_b += sb
		tot_f += sf
		cnt += k
		h.kill()
	print("ALL: %.2f us -> %.2f us (%.0f %% saved)" % [tot_b / cnt, tot_f / cnt, 100.0 * (1.0 - tot_f / tot_b)])
	quit(0)
