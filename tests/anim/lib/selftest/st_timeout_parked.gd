extends AnimTestSuite
## Runner self-test, runs right after st_timeout: the timed-out suite's coroutine must stay
## parked (its resume counter, SceneTree meta "st_timeout_resumes", does not move while this
## suite waits 60 frames), so it cannot check, log errors or drive input during later suites.
## Must be reported PASS (SKIP when st_timeout did not run first). Without the runner's
## ctx.abandon() the counter moves on every frame and this suite fails.


func describe() -> String:
	return "the timed-out st_timeout never resumes while later suites run"


func run(ctx: AnimTestContext) -> void:
	if not ctx.tree.has_meta("st_timeout_resumes"):
		ctx.skip("st_timeout did not run before this suite (run the whole --selftest)")
		return
	var before := int(ctx.tree.get_meta("st_timeout_resumes"))
	await ctx.idle_frames(30)
	await ctx.frames(30)
	var after := int(ctx.tree.get_meta("st_timeout_resumes"))
	ctx.check(before > 0, "st_timeout ran and resumed %d times before its timeout" % before)
	ctx.check(after == before, "st_timeout's coroutine stayed parked after the runner abandoned it (resumes %d -> %d over 60 frames)" % [before, after])
