extends Node


#const TIMESTAMP_FONT: Font = preload(Library.FONT_ROBOTO_MEDIUM)
#const TIMESTAMP_LINE_COLOR: Color = Color.DIM_GRAY
#
#const FADE_LINE_WIDTH: int = 3
#
#
## TODO: Move this to settings
#var color_wave: Color = Color(0.82, 0.82, 0.82, 0.8)
#var color_video_fade: Color = Color(0.76, 1, 0.18, 0.3)
#var color_audio_fade: Color = Color(0.80, 0.36, 0.36, 0.3)
#var color_video_fade_line: Color = Color(0.76, 1, 0.18, 0.5)
#var color_audio_fade_line: Color = Color(0.80, 0.36, 0.36, 0.5)
#
#
#
## Timestamp_box.gd
#func draw_timestamp_box(box: TimelineBox) -> void:
#	if !Project.is_loaded():
#		return
#
#	var framerate: float = Project.get_framerate()
#	var zoom: float = Project.get_zoom()
#	var size_x: float = box.size.x
#	var size_y: float = box.size.y
#
#	box.draw_line(
#			Vector2(0, size_y - 1),
#			Vector2(size_x, size_y - 1),
#			TIMESTAMP_LINE_COLOR,
#			2)
#
#	if box.frame_state != box.FRAME_STATE.HIDE:
#		var total: int = box.total_frames
#		var mod: int = 1
#
#		if box.frame_state == box.FRAME_STATE.SHOW_HALF:
#			mod = 2
#		elif box.frame_state == box.FRAME_STATE.SHOW_MINIMUM:
#			mod = 4
#
#		total /= mod
#
#		for i: int in total:
#			var x_pos: float = (i * zoom * mod) + 1
#
#			box.draw_line(
#					Vector2(x_pos, size_y / 1.3),
#					Vector2(x_pos, size_y - 1),
#					TIMESTAMP_LINE_COLOR)
#
#	for i: int in box.total_seconds:
#		var x_pos: float = i * framerate * zoom
#		var draw_time: bool = true
#
#		if box.time_state == box.TIME_STATE.FIVE_SECOND and i % 5:
#			draw_time = false
#		elif box.time_state == box.TIME_STATE.TEN_SECOND and i % 10:
#			draw_time = false
#		elif box.time_state == box.TIME_STATE.MINUTE and i % 60:
#			draw_time = false
#		elif box.time_state == box.TIME_STATE.HALF_MINUTE and i % 30:
#			draw_time = false
#
#		if box.frame_state == box.FRAME_STATE.HIDE:
#			if draw_time:
#				box.draw_line(
#						Vector2(x_pos, size_y / 1.5),
#						Vector2(x_pos, size_y - 1),
#						TIMESTAMP_LINE_COLOR,
#						2)
#			else:
#				box.draw_line(
#						Vector2(x_pos, size_y / 1.3),
#						Vector2(x_pos, size_y - 1),
#						TIMESTAMP_LINE_COLOR,
#						1)
#		else:
#			box.draw_line(
#					Vector2(x_pos, size_y / 2.3),
#					Vector2(x_pos, size_y - 1),
#					TIMESTAMP_LINE_COLOR,
#					2)
#
#		if draw_time:
#			box.draw_string(
#					TIMESTAMP_FONT,
#					Vector2(x_pos + 3, size_y / 2 + 2),
#					Utils.format_time_str(i, true),
#					HORIZONTAL_ALIGNMENT_LEFT,
#					-1, # Width.
#					12, # Font size.
#					TIMESTAMP_LINE_COLOR)
#
#	for i: int in box.total_minutes:
#		var x_pos: float = i * framerate * 60 * zoom
#		box.draw_line(
#				Vector2(x_pos, size_y),
#				Vector2(x_pos, size_y - 1),
#				TIMESTAMP_LINE_COLOR,
#				2)


#func draw_clip_wave(clip: ClipButton) -> void:
#	var file_data: FileData = FileManager.get_file_data(clip.clip_data.file_id)
#	var full_wave_data: PackedFloat32Array = file_data.audio_wave_data
#	var block_width: float = Timeline.get_zoom()
#	var display_begin_offset: int = 0
#	var display_duration: int = 0
#
#	var size_x: float = clip.size.x
#	var size_y: float = clip.size.y
#
#	if full_wave_data.is_empty() or size_x <= 0:
#		return # Should not happen, only during startup.
#
#	if clip.is_resizing_left or clip.is_resizing_right:
#		display_duration = clip._visual_duration
#		display_begin_offset = clip._original_begin + (clip._visual_start_frame - clip._original_start_frame)
#	else:
#		display_duration = clip.clip_data.duration
#		display_begin_offset = clip.clip_data.begin
#
#	if display_duration <= 0:
#		return
#
#	for i: int in display_duration:
#		var wave_data_index: int = display_begin_offset + i
#
#		if wave_data_index >= 0 and wave_data_index < full_wave_data.size():
#			var normalized_height: float = full_wave_data[wave_data_index]
#			var block_height: float = clampf(normalized_height * (size_y * 2), 0, size_y)
#			var block_pos_y: float = 0.0
#
#			match Settings.get_audio_waveform_style():
#				Settings.AUDIO_WAVEFORM_STYLE.CENTER:
#					block_pos_y = (size_y - block_height) / 2.0
#				Settings.AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP:
#					block_pos_y = size_y - block_height
#
#			var block_rect: Rect2 = Rect2(
#					i * block_width, block_pos_y,
#					block_width, block_height)
#
#			clip.draw_rect(block_rect, color_wave)


#func draw_video_fade_in(clip: ClipButton, fade: int) -> void:
#	var pos: PackedVector2Array = [
#			Vector2(0, 0), Vector2(0, clip.size.y),
#			Vector2(Timeline.get_frame_pos(fade), clip.size.y)]
#
#	clip.draw_colored_polygon(pos, color_video_fade)
#	clip.draw_polyline(pos, color_video_fade_line, FADE_LINE_WIDTH, true)
#
#
#func draw_audio_fade_in(clip: ClipButton, fade: int) -> void:
#	var pos: PackedVector2Array = [
#			Vector2(0, 0), Vector2(0, clip.size.y),
#			Vector2(Timeline.get_frame_pos(fade), 0)]
#
#	clip.draw_colored_polygon(pos, color_audio_fade)
#	clip.draw_polyline(pos, color_audio_fade_line, FADE_LINE_WIDTH, true)
#
#
#func draw_video_fade_out(clip: ClipButton, fade: int) -> void:
#	var pos: PackedVector2Array = [
#			Vector2(clip.size.x, 0), Vector2(clip.size.x, clip.size.y),
#			Vector2(clip.size.x - Timeline.get_frame_pos(fade), clip.size.y)]
#
#	clip.draw_colored_polygon(pos, color_video_fade)
#	clip.draw_polyline(pos, color_video_fade_line, FADE_LINE_WIDTH, true)
#
#
#func draw_audio_fade_out(clip: ClipButton, fade: int) -> void:
#	var pos: PackedVector2Array = [
#			Vector2(clip.size.x, 0), Vector2(clip.size.x, clip.size.y),
#			Vector2(clip.size.x - Timeline.get_frame_pos(fade), 0)]
#
#	clip.draw_colored_polygon(pos, color_audio_fade)
#	clip.draw_polyline(pos, color_audio_fade_line, FADE_LINE_WIDTH, true)
#
