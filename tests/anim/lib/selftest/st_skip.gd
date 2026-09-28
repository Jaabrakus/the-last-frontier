extends AnimTestSuite
## Runner self-test: must be reported SKIP (does not fail the run).


func describe() -> String:
	return "ctx.skip() -> SKIP (does not fail the run)"


func run(ctx: AnimTestContext) -> void:
	ctx.skip("dummy prerequisite missing")
