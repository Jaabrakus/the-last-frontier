extends AnimTestSuite
## Runner self-test: a GDScript runtime error after an await must be reported ERROR.


func describe() -> String:
	return "script error after an await -> ERROR"


func run(ctx: AnimTestContext) -> void:
	ctx.check(true, "a passing check before the error")
	await ctx.idle_frames(1)
	var d := {}
	ctx.check(d["missing_key"] == 1, "unreachable: the line above raises a script error")
