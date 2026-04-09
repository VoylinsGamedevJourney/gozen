extends Control

const STYLE_BOX_PREVIEW: StyleBox = preload("uid://dx2v44643hfvy")



func _draw() -> void:
	var zoom: float = Timeline.zoom
	if Timeline.state in [Timeline.STATE.MOVING, Timeline.STATE.DROPPING] and Timeline.draggable != null:
		if !Timeline.drop_valid:
			return
		if Timeline.draggable.is_file:
			var scroll_container: ScrollContainer = get_parent().get_parent()
			var current_offset_frames: int = 0
			for file_id: int in Timeline.draggable.ids:
				var file: FileData = FileLogic.files[file_id]
				var preview_position: Vector2 = Vector2(
						(Timeline.draggable.frame_offset + current_offset_frames) * zoom,
						Timeline.draggable.track_offset * Timeline.track_total_size)
				var preview_size: Vector2 = Vector2(file.duration * zoom, Timeline.track_height)
				var clip_rect: Rect2 = Rect2(preview_position, preview_size)
				draw_style_box(STYLE_BOX_PREVIEW, clip_rect)

				if file.type in EditorCore.AUDIO_TYPES:
					var wave_dict: Dictionary = FileLogic.audio_wave.get(file.id, {})
					if not wave_dict.is_empty():
						var lod: int = 1
						if zoom < 0.2:
							lod = 16
						elif zoom < 0.8:
							lod = 4
						var audio_wave: PackedFloat32Array = wave_dict[lod]
						_draw_wave(audio_wave, 0, int(file.duration / float(lod)), clip_rect, 1.0, lod, scroll_container)

				current_offset_frames += file.duration
		else:
			var scroll_container: ScrollContainer = get_parent().get_parent()
			for clip_id: int in Timeline.draggable.ids:
				var clip: ClipData = ClipLogic.clips[clip_id]
				var preview_position: Vector2 = Vector2(
						(clip.start + Timeline.draggable.frame_offset) * zoom,
						(clip.track + Timeline.draggable.track_offset) * Timeline.track_total_size)
				var preview_size: Vector2 = Vector2(clip.duration * zoom, Timeline.track_height)
				var clip_rect: Rect2 = Rect2(preview_position, preview_size)
				draw_style_box(STYLE_BOX_PREVIEW, clip_rect)

				var wave_file_id: int = clip.file
				var wave_offset_sec: float = 0.0

				if clip.effects.ato_active and clip.effects.ato_file != -1:
					wave_file_id = clip.effects.ato_file
					wave_offset_sec = clip.effects.ato_offset
				else:
					var target_file: FileData = FileLogic.files.get(clip.file)
					if target_file and target_file.ato_active and target_file.ato_file != -1:
						wave_file_id = target_file.ato_file
						wave_offset_sec = target_file.ato_offset

				var wave_dict: Dictionary = FileLogic.audio_wave.get(wave_file_id, {})
				if not wave_dict.is_empty():
					var lod: int = 1
					if zoom < 0.2:
						lod = 16
					elif zoom < 0.8:
						lod = 4

					var audio_wave: PackedFloat32Array = wave_dict[lod]
					var wave_begin: int = int((clip.begin + int(wave_offset_sec * Project.data.framerate)) / float(lod))
					_draw_wave(audio_wave, wave_begin, int(clip.duration / float(lod)), clip_rect, clip.speed, lod, scroll_container)
	elif Timeline.state in [Timeline.STATE.RESIZING, Timeline.STATE.SPEEDING]:
		var clip: ClipData = Timeline.resize_target.clip
		var draw_start: float = clip.start
		var draw_length: int = clip.duration
		var draw_begin: int = clip.begin
		var draw_speed: float = clip.speed

		if !Timeline.resize_target.is_end:
			draw_start += Timeline.resize_target.delta
			draw_length -= Timeline.resize_target.delta
			if Timeline.state == Timeline.STATE.RESIZING:
				draw_begin += int(Timeline.resize_target.delta * clip.speed)
		else:
			draw_length += Timeline.resize_target.delta

		if Timeline.state == Timeline.STATE.SPEEDING:
			draw_speed = (clip.duration * clip.speed) / float(maxi(draw_length, 1))

		var preview_position: Vector2 = Vector2(draw_start * zoom, clip.track * Timeline.track_total_size)
		var preview_size: Vector2 = Vector2(draw_length * zoom, Timeline.track_height)
		var box_pos: Vector2 = Vector2(clip.start * zoom, Timeline.track_total_size * clip.track)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip.duration * zoom, Timeline.track_height))
		var color: Color = Color(1.0, 1.0, 1.0, 0.3) # Resizing color.
		if Timeline.state == Timeline.STATE.SPEEDING:
			color = Color(1.0, 0.5, 0.0, 0.3) # Have different color on speeding.

		# Drawing the original clip box and actual resized box.
		draw_rect(clip_rect, color)
		var preview_rect: Rect2 = Rect2(preview_position, preview_size)
		draw_style_box(STYLE_BOX_PREVIEW, preview_rect)

		var scroll_container: ScrollContainer = get_parent().get_parent()
		var wave_file_id: int = clip.file
		var wave_offset_sec: float = 0.0

		if clip.effects.ato_active and clip.effects.ato_file != -1:
			wave_file_id = clip.effects.ato_file
			wave_offset_sec = clip.effects.ato_offset
		else:
			var target_file: FileData = FileLogic.files.get(clip.file)
			if target_file and target_file.ato_active and target_file.ato_file != -1:
				wave_file_id = target_file.ato_file
				wave_offset_sec = target_file.ato_offset

		var wave_dict: Dictionary = FileLogic.audio_wave.get(wave_file_id, {})
		if not wave_dict.is_empty():
			var lod: int = 1
			if zoom < 0.2:
				lod = 16
			elif zoom < 0.8:
				lod = 4

			var audio_wave: PackedFloat32Array = wave_dict[lod]
			var wave_begin: int = int((draw_begin + int(wave_offset_sec * Project.data.framerate)) / float(lod))
			_draw_wave(audio_wave, wave_begin, int(draw_length / float(lod)), preview_rect, draw_speed, lod, scroll_container)


func _draw_wave(wave_data: PackedFloat32Array, begin: int, duration: int, rect: Rect2, speed: float, lod: int, scroll_container: ScrollContainer) -> void:
	if wave_data.is_empty():
		return
	var zoom: float = Timeline.zoom * lod
	var height: float = rect.size.y
	var base_x: float = rect.position.x
	var base_y: float = rect.position.y
	var step: int = maxi(1, int(2.0 / zoom))

	var start_i: int = 0
	var end_i: int = duration

	var scroll_start: float = Timeline.scroll_x
	var scroll_end: float = scroll_start + scroll_container.size.x

	if base_x < scroll_start:
		start_i = floori((scroll_start - base_x) / zoom)
	if base_x + (duration * zoom) > scroll_end:
		end_i = ceili((scroll_end - base_x) / zoom)

	start_i -= start_i % step

	var waveform_style: int = Settings.get_audio_waveform_style()
	var waveform_amp: float = Settings.get_audio_waveform_amp()

	for i: int in range(start_i, end_i, step):
		var wave_index: int = begin + int(i * speed)
		if wave_index < 0 or wave_index >= wave_data.size():
			continue

		var max_value: float = 0.0
		var check_end: int = mini(wave_index + maxi(1, int(step * speed)), wave_data.size())
		for index: int in range(wave_index, check_end):
			if wave_data[index] > max_value:
				max_value = wave_data[index]

		var normalized_height: float = max_value * waveform_amp
		var block_height: float = clampf(normalized_height * (height * 0.9), 0, height)
		var block_pos_y: float = base_y

		match waveform_style:
			SettingsData.AUDIO_WAVEFORM_STYLE.CENTER:
				block_pos_y = base_y + (height - block_height) / 2.0
			SettingsData.AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP:
				block_pos_y = base_y + height - block_height

		var wave_color: Color = Color(0.82, 0.82, 0.82, 0.6)
		draw_rect(Rect2(base_x + (i * zoom), block_pos_y, zoom * step, block_height), wave_color)
