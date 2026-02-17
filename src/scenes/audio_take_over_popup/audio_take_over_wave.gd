extends ColorRect

signal seek_requested(position: float)


const COLOR_WAVE: Color = Color(1.0, 1.0, 1.0, 0.5)
const COLOR_PLAYHEAD: Color = Color(1.0, 0.2, 0.2, 0.8)
const PREVIEW_DURATION: float = 30 ## Seconds of duration shown.


var file_id: int = -1: set = set_file_id
var wave_offset: float = 0.0: set = set_wave_offset
var playback_position: float = 0.0

var _seeking: bool = false



func set_file_id(new_file_id: int) -> void:
	file_id = new_file_id
	queue_redraw()


func set_wave_offset(new_wave_offset: float) -> void:
	wave_offset = new_wave_offset
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_seeking = mouse_event.pressed
		if _seeking:
			var seek_time: float = (mouse_event.position.x / size.x) * PREVIEW_DURATION
			seek_requested.emit(clampf(seek_time, 0.0, PREVIEW_DURATION))
	if event is InputEventMouseMotion:
		if _seeking:
			var seek_time: float = (get_local_mouse_position().x / size.x) * PREVIEW_DURATION
			seek_requested.emit(clampf(seek_time, 0.0, PREVIEW_DURATION))


func _draw() -> void:
	if file_id == -1:
		return
	var wave_data: PackedFloat32Array = Project.files.get_audio_wave(file_id)
	if wave_data.is_empty():
		return

	var area_width: float = size.x
	var area_height: float = size.y
	var center_y: float = area_height / 2.0

	# Calculating preview duration scale.
	var pixels_per_sec: float = area_width / PREVIEW_DURATION
	var pixel_offset: float = wave_offset * pixels_per_sec

	var framerate: float = Project.data.framerate
	var total_frames: int = wave_data.size()
	var max_visible_frames: int = floori(PREVIEW_DURATION * framerate)

	var step: float = maxi(1, int(max_visible_frames/ area_width))
	var start_index: int = 0
	if pixel_offset < 0:
		start_index = int(absf(pixel_offset) / (pixels_per_sec / framerate))
	var end_index: int = min(total_frames, start_index + max_visible_frames + 1)

	# - Draw wave.
	for i: int in range(start_index, end_index, step):
		var val: float = wave_data[i]
		var time: float = i / framerate
		var pos_x: float = (time * pixels_per_sec) + pixel_offset
		if pos_x > area_width:
			break
		var height: float = val * (area_height * 0.9)
		draw_line(
				Vector2(pos_x, center_y - height / 2.0),
				Vector2(pos_x, center_y + height / 2.0),
				COLOR_WAVE)

	# - Draw playhead.
	var playhead_x: float = (playback_position / PREVIEW_DURATION) * size.x
	if playhead_x >= 0 and playhead_x <= size.x:
		draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), COLOR_PLAYHEAD, 2.0)
