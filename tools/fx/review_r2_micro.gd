extends SceneTree
## Review round 2 probe (read-only): small per-particle costs in CascadeFx that a table or a constant would remove.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/fx/review_r2_micro.gd

const N := 300000
const AXES := {"X": [1, 0, 0], "Y": [0, 1, 0], "Z": [0, 0, 1]}


func _initialize() -> void:
	var flag := "EPAL_ROTATE_X"
	var sink := 0.0
	var t0 := Time.get_ticks_usec()
	for i in N:
		var axes := {"X": [1, 0, 0], "Y": [0, 1, 0], "Z": [0, 0, 1]}
		var key := flag.right(1)
		if axes.has(key):
			var ax := CascadeFx.ue_axes(axes[key])
			if flag.contains("NEGATIVE"):
				ax = -ax
			sink += ax.x
	var a := float(Time.get_ticks_usec() - t0) / float(N)
	t0 = Time.get_ticks_usec()
	for i in N:
		var key := flag.right(1)
		if AXES.has(key):
			var ax := CascadeFx.ue_axes(AXES[key])
			if flag.contains("NEGATIVE"):
				ax = -ax
			sink += ax.x
	var b := float(Time.get_ticks_usec() - t0) / float(N)
	print("REVIEW micro: _sprite_basis' axis-lock block per particle per frame: literal dictionary %.3f us, const dictionary %.3f us (%.0f)" % [a, b, sink])
	quit(0)
