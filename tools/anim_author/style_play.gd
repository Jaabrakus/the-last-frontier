extends SceneTree
## A fighting style in the real game, for the owner to play (a dev launcher; the game itself never sets these): the style's
## clips (animations_extra/Frontier_Style_<Style>.res, tools/anim_author/install_style.gd) and its poses
## (data/bending/style_poses.json) put over the element's own (data/bending/poses.json) through BendPoses' test hooks
## (extra_library, override: the file's own entry of each move kept, only the modes the style re-poses replaced), then a
## practice in the ring (scenes/ring.tscn) as the style's element against a dummy of the same element that throws its
## strike every few seconds (so the guard can be tried, and the dummy shows the style too: the poses are the element's).
## The user args still apply over it (MatchSetup.parse: practice=stand, foe=water, mode=ring, ...). A line of keys stays
## in the corner. A script run: nothing is saved.
##   zsh tools/loop/godot_run.sh --path . -s tools/anim_author/style_play.gd -- style=boxing [practice=stand] [foe=water]
##   check=1 (headless): instead of playing, prints what each re-posed mode picks and what the idle player's stance plays,
##   then quits (STYLE CHECK lines; exit 1 when a pick is not the style's clip)

const POSES := "res://data/bending/style_poses.json"
## The corner's line of keys, per style.
const KEYS := {
	"boxing": "BOXING (fire, test)   Left click: jab, cross (the 3rd of a string: the hook)   1: Punch   1 twice: Lightning   2: Ground punch   2 twice: Uppercut   3: Step   E: Slip (on the beat)",
	"taekwondo": "TAEKWONDO (air, test)   Left click: snap kick (the 3rd of a string: a jumping kick)   1: Side kick (the Slice)   2: Spinning heel kick (the Gust)   2 in the air: Axe kick (the Slam)   Space twice, click: jumping spin kick (the Leap)   E: Knee guard (held: kept up)",
	"muay_thai": "MUAY THAI (fire, test)   Left click: elbows (the 3rd of a string: the clinch knee)   1: Cross   1 held: Fireball off the cross   2: Body kick   2 held: Teep   2 twice: High roundhouse   Shift + a direction: step and slide   E: Shin check (on the beat)",
	"wrestling": "WRESTLING (earth, test)   Left click: single-leg shot (the 3rd of a string: the lift)   2: Double-leg shot (the Push)   Shift + a direction: the low shuffle   E: Sprawl (on the beat)",
	"judo": "JUDO (water, test)   Left click: grip and pull (the 3rd of a string: the hip throw)   1: Ankle sweep (the Whip)   Shift + a direction: tsugi-ashi   E: Grip and turn (held: the grip kept)",
	"karate": "KARATE (earth, test)   Left click: lead punch (the 3rd of a string: the reverse punch)   1: Lunge punch (the Spike)   2: Double palm thrust (the Push)   Shift + a direction: sliding step   E: Low block (on the beat)",
	"wing_chun": "WING CHUN (water, test)   Left click: chain punches (the 3rd of a string: the palm)   1: Trap and punch (the Whip)   2: Double palm (the Wave)   Shift + a direction: arrow step   E: Bong sau (held: the hands on the line)",
}


func _initialize() -> void:
	var style := "boxing"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("style="):
			style = a.trim_prefix("style=")
	var all: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	if not (all is Dictionary and (all.get("styles", {}) as Dictionary).has(style)):
		push_error("style_play: no style %s in %s" % [style, POSES])
		quit(1)
		return
	var s: Dictionary = all.styles[style]
	var el := String(s.element)
	var lib := load(String(s.library)) as AnimationLibrary
	if lib == null:
		push_error("style_play: no library %s (install_style.gd)" % s.library)
		quit(1)
		return
	BendPoses.extra_library = lib
	BendPoses.override = {}
	var own := BendPoses.data()
	var moves := {}
	for m: String in (s.get("modes", {}) as Dictionary):
		var entry: Dictionary = ((own.get("moves", {}) as Dictionary).get(m, {}) as Dictionary).duplicate(true)
		var modes: Dictionary = (entry.get("modes", {}) as Dictionary).duplicate(true)
		for md: String in (s.modes[m] as Dictionary):
			modes[md] = s.modes[m][md]
		entry["modes"] = modes
		moves[m] = entry
	BendPoses.override = {"moves": moves, "stance": {el: s.get("stance", "")}, "guard_hold": {el: s.get("guard_hold", "")},
			"clips": s.get("clips", {})}
	print("STYLE PLAY %s (%s): %d clips, re-posed moves %s" % [style, el, lib.get_animation_list().size(), moves.keys()])
	MatchSetup.incoming = true
	MatchSetup.element = el
	MatchSetup.set_practice(el, "throw")
	change_scene_to_file.call_deferred("res://scenes/ring.tscn")
	if "check=1" in OS.get_cmdline_user_args():
		_check.call_deferred(s, el)
		return
	_corner.call_deferred(String(KEYS.get(style, style)))


## check=1: each re-posed mode's pick and the idle player's stance, then quit.
func _check(s: Dictionary, el: String) -> void:
	var bad := 0
	for m: String in (s.get("modes", {}) as Dictionary):
		for md: String in (s.modes[m] as Dictionary):
			var want := String(BendPoses._as_pose(s.modes[m][md]).get("clip", ""))
			var got := String(BendPoses.pick(m, md, el).get("clip", ""))
			print("STYLE CHECK pick %s/%s -> %s%s" % [m, md, got, "" if got == want else "   (want %s)" % want])
			bad += 0 if got == want else 1
	for i in 300:
		await process_frame
	var lvl := current_scene as RingLevel
	var c := SwayCaster.of(lvl.player) if lvl != null and lvl.player != null else null
	if c == null or c.pose == null:
		print("STYLE CHECK no player caster in the ring")
		quit(1)
		return
	print("STYLE CHECK the player's element %s, stance %s (weight %.2f), guard hold %s" % [BendPoses.element_of(lvl.player),
			c.pose.stance_clip(), c.pose.stance_weight(), c.guard_hold_clip()])
	bad += 0 if String(c.pose.stance_clip()) == String(s.get("stance", "")) else 1
	print("STYLE CHECK %s" % ("ok" if bad == 0 else "%d wrong" % bad))
	quit(0 if bad == 0 else 1)


## The line of keys in the corner, over the game's HUD.
func _corner(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var l := Label.new()
	l.text = text
	l.position = Vector2(14, 10)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	l.add_theme_constant_override("outline_size", 5)
	layer.add_child(l)
	root.add_child(layer)
