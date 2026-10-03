class_name StoryBark
extends Label3D
## A line said aloud in the world (StoryDialogue.bark; docs/research/codebase_story_audit.md item 3): the words float
## over the speaker's head for a few seconds, in the HUD's serif with a dark outline so they read against sky and snow,
## and fade. No box and no pause: the game goes on, and the player hears it in passing ("Halloo the house!", "Mind the
## river ice"). A speaker has one line at a time (a new one takes the old one's place). Far off the line fades out
## (FAR_M), so a shout across the valley does not fill the screen.
## The height over the speaker is its "bark_height" meta if it has one (a contact's post stands taller than a person:
## StoryContact sets it), else HEIGHT. Its node is "StoryBark": NpcFighter's own bark label, "Bark", is left alone.

const NODE_NAME := "StoryBark"
const HEIGHT := 2.4            ## m over the speaker's origin (over a person's head, above a name tag)
const FADE_IN_S := 0.2
const FADE_OUT_S := 0.45
const NEAR_M := 22.0           ## full strength nearer than this to the camera
const FAR_M := 34.0            ## gone beyond this
const WRAP_PX := 560.0         ## the line wraps at this width (in the font's pixels)

var life := 3.0                ## seconds it shows in all
var age := 0.0


## Puts `text` over `speaker` for `seconds` (a line already there goes). Null when there is no speaker or no text.
static func say(speaker: Node3D, text: String, seconds := 3.0) -> StoryBark:
	if speaker == null or not is_instance_valid(speaker) or not speaker.is_inside_tree() or text.strip_edges() == "":
		return null
	var old := speaker.get_node_or_null(NODE_NAME) as StoryBark
	if old != null:
		speaker.remove_child(old)
		old.queue_free()
	var b := StoryBark.new()
	b.name = NODE_NAME
	b.life = maxf(seconds, FADE_IN_S + FADE_OUT_S)
	b.text = text.strip_edges()
	b.position = Vector3(0.0, float(speaker.get_meta(&"bark_height", HEIGHT)), 0.0)
	speaker.add_child(b)
	return b


## The line over `speaker` now ("" none): tests, and whoever wants to know if someone is talking.
static func line_over(speaker: Node3D) -> String:
	if speaker == null or not is_instance_valid(speaker):
		return ""
	var b := speaker.get_node_or_null(NODE_NAME) as StoryBark
	return b.text if b != null and not b.is_queued_for_deletion() else ""


func _ready() -> void:
	font = FrontierHUD.serif()
	font_size = 30
	outline_size = 10
	outline_modulate = Color(0.02, 0.015, 0.01, 0.85)
	modulate = Color(FrontierHUD.INK, 0.0)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0008
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	width = WRAP_PX
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM      # (a long line grows upward, off the head)
	render_priority = 2


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	var a := clampf(minf(age / FADE_IN_S, (life - age) / FADE_OUT_S), 0.0, 1.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var d := cam.global_position.distance_to(global_position)
		a *= clampf(1.0 - (d - NEAR_M) / (FAR_M - NEAR_M), 0.0, 1.0)
	modulate.a = a
