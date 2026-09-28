extends AnimTestSuite
## Runner self-test: a suite that never finishes must be reported TIMEOUT after timeout_s(), and
## then be abandoned: its coroutine must never run again. Every time the coroutine resumes it
## bumps the SceneTree meta "st_timeout_resumes"; st_timeout_parked (the next suite) checks that
## the counter stays still while it runs.


func timeout_s() -> float:
	return 1.0


func describe() -> String:
	return "never finishes -> TIMEOUT; abandoned afterwards (see st_timeout_parked)"


func run(ctx: AnimTestContext) -> void:
	ctx.check(true, "a passing check before hanging")
	ctx.tree.set_meta("st_timeout_resumes", 0)
	var k := 0
	while true:
		if k % 2 == 0:
			await ctx.idle_frames(1)
		else:
			await ctx.frames(1)
		k += 1
		ctx.tree.set_meta("st_timeout_resumes", k)
