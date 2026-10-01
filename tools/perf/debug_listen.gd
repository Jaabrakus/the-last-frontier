extends SceneTree
## Stands in for the editor's debugger to read the game's profilers headless (user 2026-10-01: "do it for me"): listens on
## 127.0.0.1:6007, turns the scripts and servers profilers on, and after `secs` s of frames prints the functions by their total
## self time (what the editor's Profiler tab shows). Start this first, then the game with
##   Godot --path . --remote-debug tcp://127.0.0.1:6007 --profiling -- survival=on wildlife=on
##   Godot --headless --path . -s tools/perf/debug_listen.gd -- warm=35 secs=15

var warm := 35.0
var secs := 15.0
var _srv := TCPServer.new()
var _peer: StreamPeerTCP
var _buf := PackedByteArray()
var _names := {}          ## message name -> count
var _sigs := {}           ## function id -> signature
var _self := {}           ## signature -> total self s
var _total := {}          ## signature -> total s
var _calls := {}
var _frames := 0
var _sample_shown := 0
var _profiling := false
var _thread: Variant = 0
var _last_draw := 0
var _hdr := [0.0, 0.0, 0.0, 0.0, 0.0]
var _hdr_n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("warm="):
			warm = float(s.get_slice("=", 1))
		elif s.begins_with("secs="):
			secs = float(s.get_slice("=", 1))
	_srv.listen(6007, "127.0.0.1")
	print("LISTEN waiting")
	while not _srv.is_connection_available():
		await process_frame
	_peer = _srv.take_connection()
	print("LISTEN connected")
	var t0 := Time.get_ticks_msec()
	var on := false
	while true:
		await process_frame
		_peer.poll()
		_read()
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if not on and t > warm:
			on = true
			_send("profiler:servers", [true, []])
			print("LISTEN thread ", _thread)
			print("LISTEN profilers on")
			_profiling = true
		if on and Time.get_ticks_msec() - _last_draw > 1000:
			_last_draw = Time.get_ticks_msec()
			_send("servers:draw", [])
		if on and t > warm + secs:
			break
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			print("LISTEN game gone")
			break
	_report()
	quit()


func _send(msg: String, data: Array) -> void:
	var b := var_to_bytes([msg, _thread, data])
	var head := PackedByteArray()
	head.resize(4)
	head.encode_u32(0, b.size())
	_peer.put_data(head + b)


func _read() -> void:
	var n := _peer.get_available_bytes()
	if n > 0:
		var r := _peer.get_data(n)
		if r[0] == OK:
			_buf.append_array(r[1])
	while _buf.size() >= 4:
		var len := _buf.decode_u32(0)
		if _buf.size() < 4 + len:
			return
		var v: Variant = bytes_to_var(_buf.slice(4, 4 + len))
		_buf = _buf.slice(4 + len)
		if v is Array and (v as Array).size() >= 3:
			if typeof(_thread) == TYPE_INT and int(_thread) == 0:
				_thread = v[1]
			_handle(String(v[0]), v[2] as Array)


func _handle(msg: String, data: Array) -> void:
	_names[msg] = int(_names.get(msg, 0)) + 1
	if msg.begins_with("servers:") and msg != "servers:drawn" and int(_names[msg]) <= 2:
		print("LISTEN raw ", msg, " ", str(data).left(1500))
	if msg.ends_with("function_signature"):
		# [sig, id, sig, id ...] or a dictionary
		var arr: Array = data[0] if not data.is_empty() and data[0] is Array else data
		for i in range(0, arr.size() - 1, 2):
			_sigs[arr[i + 1]] = String(arr[i])
		return
	if msg == "error" and int(_names[msg]) > 0 and _profiling:
		print("LISTEN error ", str(data).left(300))
	if msg.ends_with("profile_frame"):
		_frames += 1
		if msg == "servers:profile_frame" and data.size() > 5:
			_hdr_n += 1
			for j in 5:
				_hdr[j] += float(data[j + 1])
		if _sample_shown < 2:
			_sample_shown += 1
			print("LISTEN sample ", msg, " ", str(data).left(600))
		_take(data)


## A frame's script functions: Godot sends [..., count, then per function id, sig?, calls, total, self] in a flat array; read the
## known layouts and fall back to scanning for runs of (id, calls, total, self).
func _take(data: Array) -> void:
	# ServersDebugger profile_frame: [frame_number, frame_time, process_time, physics_time, physics_frame_time, script_time,
	#  servers count, servers..., functions count, then per function: sig_id, call_count, total_time, self_time]
	var i := 0
	if data.size() < 8:
		return
	i = 6
	var ns := int(data[i])
	i += 1
	for k in ns:
		# name, item count, then name/time pairs
		i += 1
		var items := int(data[i])
		i += 1 + items
	if i >= data.size():
		return
	var nvals := int(data[i])
	i += 1
	for k in nvals / 5:
		if i + 3 >= data.size():
			break
		var id: Variant = data[i]
		var calls := int(data[i + 1])
		var tot := float(data[i + 2])
		var slf := float(data[i + 3])
		i += 5
		var sig := String(_sigs.get(id, str(id)))
		_self[sig] = float(_self.get(sig, 0.0)) + slf
		_total[sig] = float(_total.get(sig, 0.0)) + tot
		_calls[sig] = int(_calls.get(sig, 0)) + calls


func _report() -> void:
	if _hdr_n > 0:
		print("LISTEN header avg over %d frames: frame %.2f ms  process %.2f ms  physics %.2f ms  physics-frame %.2f ms  SCRIPTS %.2f ms" % [_hdr_n, _hdr[0] * 1000.0 / _hdr_n, _hdr[1] * 1000.0 / _hdr_n, _hdr[2] * 1000.0 / _hdr_n, _hdr[3] * 1000.0 / _hdr_n, _hdr[4] * 1000.0 / _hdr_n])
	print("LISTEN messages ", _names)
	print("LISTEN frames %d  functions %d  signatures %d" % [_frames, _self.size(), _sigs.size()])
	var keys := _self.keys()
	keys.sort_custom(func(a, b) -> bool: return float(_self[a]) > float(_self[b]))
	var f := maxf(_frames, 1)
	for k in keys.slice(0, 40):
		print("LISTEN self %7.3f ms/frame  total %7.3f ms/frame  calls %6.1f/frame  %s" % [float(_self[k]) * 1000.0 / f,
				float(_total[k]) * 1000.0 / f, float(_calls[k]) / f, k])
