extends AnimTestSuite
## Runner self-test: must be reported PASS (run_all.gd -- --selftest --only=st_pass exits 0).


func describe() -> String:
	return "dummy passing suite"


func run(ctx: AnimTestContext) -> void:
	ctx.check(true, "a true check passes")
	ctx.near(1.0, 1.0 + 1e-7, 1e-6, "floats within tolerance")
	ctx.near(Quaternion(Vector3.UP, 0.5), Quaternion(Vector3.UP, 0.5 + 1e-6), 1e-5, "quaternion angle within tolerance")
	ctx.near([Vector3.ONE, Vector3.ZERO], [Vector3.ONE, Vector3(0, 0, 1e-7)], 1e-6, "arrays compared element-wise")
	await ctx.idle_frames(2)
	await ctx.frames(2)
	ctx.metric("answer", 42)
