class_name AutoCutWave
extends ColorRect

signal seek_requested(position: float)
signal zoom_requested(new_duration: float)


var file_id: int = -1: set = set_file_id
var audio_stream_index: int = -1
var playback_position: float = 0.0
var preview_duration: float = 30.0
var silences: Array[Vector2] = []
var clip_offset_sec: float = 0.0
var clip_duration_sec: float = 0.0

var wave_modifier: int = 10: set = set_wave_modifier

var _seeking: bool = false



func set_file_id(new_file_id: int) -> void:
	file_id = new_file_id
	queue_redraw()


func set_wave_modifier(new_modifier: int) -> void:
	wave_modifier = new_modifier
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT: _seeking = mouse_event.pressed
			MOUSE_BUTTON_WHEEL_UP: zoom_requested.emit(maxf(1.0, preview_duration / 1.2))
			MOUSE_BUTTON_WHEEL_DOWN: zoom_requested.emit(minf(300.0, preview_duration * 1.2))

		if _seeking:
			var seek_time: float = (mouse_event.position.x / size.x) * preview_duration + clip_offset_sec
			seek_requested.emit(maxf(0.0, seek_time))
	elif event is InputEventMouseMotion and _seeking:
		var seek_time: float = (get_local_mouse_position().x / size.x) * preview_duration + clip_offset_sec
		seek_requested.emit(maxf(0.0, seek_time))


func _draw() -> void:
	if file_id == -1 or !FileLogic.audio_wave.has(file_id): return

	var wave_streams: Dictionary = FileLogic.audio_wave[file_id]
	var wave_dict: Dictionary = wave_streams.get(audio_stream_index, wave_streams.get(-1, wave_streams.values()[0] if wave_streams.size() > 0 else {}))
	if wave_dict.is_empty(): return

	var wave_data: PackedFloat32Array = wave_dict.get(1, PackedFloat32Array())
	if wave_data.is_empty(): return

	var area_width: float = size.x
	var area_height: float = size.y
	var center_y: float = area_height / 2.0

	var pixels_per_sec: float = area_width / preview_duration
	var pixel_offset: float = -clip_offset_sec * pixels_per_sec

	var framerate: float = Project.data.framerate
	var total_frames: int = wave_data.size()
	var max_visible_frames: int = floori(preview_duration * framerate)

	var step: int = maxi(1, int(max_visible_frames / area_width))
	var start_index: int = floori(clip_offset_sec * framerate)
	if start_index < 0: start_index = 0

	var end_index: int = mini(total_frames, start_index + max_visible_frames + 1)

	for silence: Vector2 in silences:
		var silence_start_px: float = (silence.x * pixels_per_sec) + pixel_offset
		var silence_end_px: float = (silence.y * pixels_per_sec) + pixel_offset
		if silence_start_px < area_width and silence_end_px > 0:
			var s_start: float = clampf(silence_start_px, 0.0, area_width)
			var s_end: float = clampf(silence_end_px, 0.0, area_width)
			draw_rect(Rect2(s_start, 0, s_end - s_start, area_height), Color(1.0, 0.2, 0.2, 0.4))

	for i: int in range(start_index, end_index, step):
		var value: float = wave_data[i]
		var time: float = i / framerate
		var pos_x: float = (time * pixels_per_sec) + pixel_offset
		if pos_x > area_width: break

		var height: float = clampf(value * wave_modifier, 0.0, 1.0) * (area_height * 0.9)
		var from: Vector2 = Vector2(pos_x, center_y - height / 2.0)
		var to: Vector2 = Vector2(pos_x, center_y + height / 2.0)
		draw_line(from, to, Color(1, 1, 1, 0.5))

	var playhead_x: float = ((playback_position - clip_offset_sec) / preview_duration) * size.x
	if playhead_x >= 0 and playhead_x <= size.x:
		draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color(1.0, 0.2, 0.2, 0.8), 2.0)
