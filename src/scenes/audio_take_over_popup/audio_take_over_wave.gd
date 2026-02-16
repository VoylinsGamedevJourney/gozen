extends ColorRect

const WAVE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)


var file_id: int = -1: set = set_file_id
var wave_offset: float = 0.0: set = set_wave_offset



func set_file_id(new_file_id: int) -> void:
	file_id = new_file_id
	queue_redraw()


func set_wave_offset(new_wave_offset: float) -> void:
	wave_offset = new_wave_offset
	queue_redraw()


func _draw() -> void:
	if file_id == -1:
		return
	var wave_data: PackedFloat32Array = Project.files.get_audio_wave(file_id)
	if wave_data.is_empty():
		return

	var area_width: float = size.x
	var area_height: float = size.y
	var center_y: float = area_height / 2.0
	var data_size: int = wave_data.size()
	if data_size == 0:
		return

	var step: float = area_width / float(data_size)
	var file_idx: int = Project.files.index_map[file_id]
	var duration_frames: int = Project.data.files_duration[file_idx]
	var duration_sec: float = float(duration_frames) / Project.data.framerate
	if duration_sec <= 0:
		return

	var pixel_offset: float = (wave_offset / duration_sec) * area_width
	for i: int in data_size:
		var val: float = wave_data[i]
		var x: float = (i * step) + pixel_offset
		if x < 0 or x > area_width:
			continue
		var height: float = val * (area_height * 0.9)
		draw_line(Vector2(x, center_y - height / 2.0), Vector2(x, center_y + height / 2.0), WAVE_COLOR)
