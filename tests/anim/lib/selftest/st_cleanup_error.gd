extends AnimTestSuite
## Runner self-test: an error logged while the suite's fixtures are torn down (after run()
## returned) must be charged to this suite and reported ERROR ("CLEANUP ERROR").


func describe() -> String:
	return "teardown error -> ERROR (CLEANUP)"


func run(ctx: AnimTestContext) -> void:
	var s := GDScript.new()
	s.source_code = "extends Node\n\nfunc _exit_tree() -> void:\n\tpush_error(\"st_cleanup_error: error while the fixture is freed\")\n"
	s.reload()
	var n := Node.new()
	n.set_script(s)
	ctx.add_node(n)
	await ctx.idle_frames(1)
	ctx.check(n.is_inside_tree(), "fixture node is in the tree; its _exit_tree() logs an error during cleanup")
