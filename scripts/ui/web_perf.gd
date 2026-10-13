class_name WebPerf
extends Node
## The web build's frame, measured (the owner, 2026-10-13: "how can we get it to run better?"): with ?perf=1 in the page's
## address, every PRINT_S the console gets the frame's numbers, where the time goes (the scripts' process and physics, the
## renderer's CPU) and what is drawn (draw calls, objects, primitives), and the slowest frame since the last line:
##   PERF fps=24 frame=41.7ms (worst 180) process=12.1 physics=6.3 render_cpu=14.0 | draws=812 objects=455 prims=1.9M nodes=6120
## Off elsewhere (attach returns null).
##   WebPerf.attach(level_node)

const PRINT_S := 2.0

var _t := 0.0
var _frames := 0
var _worst := 0.0
var _last := 0


static func attach(host: Node) -> WebPerf:
	if host == null or not OS.has_feature("web") or not bool(JavaScriptBridge.eval("/[?&]perf=1/.test(location.search)", true)):
		return null
	var p := WebPerf.new()
	p.name = "WebPerf"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(p)
	return p


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last = Time.get_ticks_usec()


func _process(dt: float) -> void:
	var now := Time.get_ticks_usec()
	_worst = maxf(_worst, (now - _last) / 1000.0)
	_last = now
	_t += dt
	_frames += 1
	if _t < PRINT_S:
		return
	var vp := get_viewport().get_viewport_rid()
	print("PERF fps=%d frame=%.1fms (worst %.0f) process=%.1f physics=%.1f render_cpu=%.1f | draws=%d objects=%d prims=%.2fM nodes=%d" % [
		roundi(_frames / _t), 1000.0 * _t / _frames, _worst,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(vp),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1e6,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	_t = 0.0
	_frames = 0
	_worst = 0.0
