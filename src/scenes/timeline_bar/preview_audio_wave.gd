class_name PreviewAudioWave
extends Button



func _draw() -> void:
	pass
#	var full_wave_data: PackedFloat32Array = FileHandler.get_file_data(clip_data.file_id).audio_wave_data
#
#	if full_wave_data.is_empty():
#		return
#
#	var display_duration: int = clip_data.duration
#	var display_begin_offset: int = clip_data.begin
#
#	if display_duration <= 0 or size.x <= 0:
#		return
#
#	var block_width: float = Timeline.zoom
#	var panel_height: float = size.y
#
#	for i: int in display_duration:
#		var wave_data_index: int = display_begin_offset + i
#
#		if wave_data_index >= 0 and wave_data_index < full_wave_data.size():
#			var normalized_height: float = full_wave_data[wave_data_index]
#			var block_height: float = clampf(normalized_height * (panel_height * 2), 0, panel_height)
#			var block_pos_y: float = 0.0
#
#			match Settings.get_audio_waveform_style():
#				Settings.AUDIO_WAVEFORM_STYLE.CENTER:
#					block_pos_y = (panel_height - block_height) / 2.0
#				Settings.AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP:
#					block_pos_y = panel_height - block_height
#
#			var block_rect: Rect2 = Rect2(
#					i * block_width, block_pos_y,
#					block_width, block_height)
#
#			draw_rect(block_rect, Color.LIGHT_GRAY)

