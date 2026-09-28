class_name AnimTestSuite
extends RefCounted
## Base class of the animation test suites (plan section 10, WPT).
##
## A suite lives in tests/anim/engine/ec_*.gd (engine contracts) or tests/anim/test_*.gd,
## is discovered by tests/anim/run_all.gd, and overrides run():
##
##   extends AnimTestSuite
##
##   func run(ctx: AnimTestContext) -> void:
##       var rig := ctx.rig()                      # Actor_B rig + scratch AnimationTree (MANUAL)
##       rig.play(tree_root)
##       ctx.near(rig.bone_rot("spined"), expected, 1e-4, "what is checked")
##       var player = await ctx.level()            # real level (scenes/main.tscn)
##       await ctx.frames(60)                      # physics frames
##
## run() may await. The runner abandons a suite that runs longer than timeout_s() of real time
## (TIMEOUT; its next wait through ctx never returns, so await ctx.frames() / idle_frames() /
## seconds() rather than the SceneTree), and a GDScript error or engine error logged while the
## suite runs fails it (ERROR) unless the suite allowed it with ctx.allow_error(substring).
## Nodes created through the context (rig(), level(), add_node()) are freed and held input
## actions released afterwards.
##
## The runner also accepts any object with run(ctx) (duck typing), so a suite written before
## this class existed keeps working.


## Real-time seconds before the runner abandons run() and reports TIMEOUT.
func timeout_s() -> float:
	return 120.0


## One line for `run_all.gd -- --list`.
func describe() -> String:
	return ""


func run(ctx: AnimTestContext) -> void:
	ctx.fail("%s does not override run(ctx)" % ctx.suite_name)
