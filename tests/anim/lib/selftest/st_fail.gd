extends AnimTestSuite
## Runner self-test: must be reported FAIL (run_all.gd -- --selftest --only=st_fail exits 1).


func describe() -> String:
	return "dummy failing suite"


func run(ctx: AnimTestContext) -> void:
	ctx.check(true, "a passing check")
	await ctx.idle_frames(1)
	ctx.near(1.0, 1.1, 1e-3, "deliberately failing near() check")
