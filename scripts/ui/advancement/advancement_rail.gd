class_name AdvancementRail
extends Control
## The class rail at the window's right edge: the style's traits (its stance, jab string, signature and guard) in a chain,
## in the tall gold frame with diamond caps, as the reference's spec rail sits. The traits come with the class and cost
## nothing, so they are drawn gold; they change when the class does. Hover or focus a trait for its words.

signal tip_wanted(node: AdvancementNode, trait_info: Dictionary, on: bool)

var element := ""
var style_id := ""
var traits: Array = []
var nodes: Array = []
var _frame: Texture2D
var _head: Label


func setup(el: String, st: String) -> void:
	element = el
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = AdvancementTheme.frame_tex("rail_frame")
	_head = AdvancementTheme.label(AdvancementData.word("class.rail_head"), AdvancementTheme.S_SMALL, AdvancementData.color("frame_trim"), "body2", true)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.size = Vector2(size.x, 22)
	_head.position = Vector2(0, -26)
	add_child(_head)
	set_style(st)


func set_style(st: String) -> void:
	style_id = st
	for n: Node in nodes:
		n.queue_free()
	nodes.clear()
	traits = AdvancementData.rail(st, element)
	var px := AdvancementData.layout_num("icon", 46.0)
	var cnt := traits.size()
	var top := 96.0
	var step := (size.y - top * 2.0) / maxf(float(cnt - 1), 1.0)
	for i in cnt:
		var tr: Dictionary = traits[i]
		var n := AdvancementNode.new()
		n.setup({"type": "root", "ids": [], "key": "rail." + String(tr.id), "chip": String(tr.get("chip", ""))}, element, px, "circle")
		n.position = Vector2((size.x - px) * 0.5, top + step * float(i) - px * 0.5)
		n.home = n.position
		var pic: Texture2D = AdvancementTheme.style_glyph(st) if String(tr.id) == "stance" else BendStrip.icon_texture(String(tr.get("move", "")), String(tr.get("mode", "")))
		if pic == null:
			pic = AdvancementTheme.style_glyph(st)
		n.show_as("root", pic)
		n.badge = ""
		n.tip.connect(func(nn: AdvancementNode, on: bool) -> void: tip_wanted.emit(nn, tr, on))
		n.wear.connect(func(_nn: AdvancementNode) -> void: pass)
		add_child(n)
		nodes.append(n)
	queue_redraw()


func _draw() -> void:
	if _frame != null:
		draw_texture_rect(_frame, Rect2(Vector2.ZERO, size), false)
	var px := AdvancementData.layout_num("icon", 46.0)
	var gold := AdvancementData.color("link_worn")
	for i in range(nodes.size() - 1):
		var a: AdvancementNode = nodes[i]
		var b: AdvancementNode = nodes[i + 1]
		var p0 := a.position + a.size * 0.5 + Vector2(0, px * 0.5 + 3.0)
		var p1 := b.position + b.size * 0.5 - Vector2(0, px * 0.5 + 3.0)
		draw_line(p0, p1 - Vector2(0, 4), Color(0, 0, 0, 0.55), 5.0, true)
		draw_line(p0, p1 - Vector2(0, 4), gold, 2.4, true)
		draw_colored_polygon(PackedVector2Array([p1, p1 + Vector2(-5, -10), p1 + Vector2(5, -10)]), gold)
