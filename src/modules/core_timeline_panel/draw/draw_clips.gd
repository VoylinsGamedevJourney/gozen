extends Control


const FADE_HANDLE_SIZE: float = 3.5
const CLIP_TEXT_OFFSET: Vector2 = Vector2(5, 12)



func _ready() -> void:
	@warning_ignore("return_value_discarded")
	Settings.on_waveform_update.connect(queue_redraw)


func _draw() -> void:
	var scroll_container: ScrollContainer = get_parent().get_parent()
	var zoom: float = Timeline.zoom
	var scroll_amount: float = Timeline.scroll_x
	var visible_start: int = floori(scroll_amount / zoom)
	var visible_end: int = ceili(visible_start + (scroll_container.size.x / zoom))

	var visible_clips: Array[ClipData] = _get_visible(visible_start, visible_end)
	var handled_clips: Array[ClipData] = []

	# Remove preview from visible clips.
	if Timeline.draggable != null and !Timeline.draggable.is_file:
		if Timeline.current_state in [Timeline.State.MOVING, Timeline.State.DROPPING, Timeline.State.RESIZING]:
			for clip_id: int in Timeline.draggable.ids:
				var clip: ClipData = ClipLogic.clips.get(clip_id)
				if clip: visible_clips.erase(clip)

	# - Clip blocks
	for clip: ClipData in visible_clips:
		if clip in handled_clips:
			continue
		var box_type: int = 1 if clip in ClipLogic.selected_clips else 0
		var box_pos: Vector2 = Vector2(clip.start * zoom, Timeline.track_total_size * clip.track)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip.duration * zoom, Timeline.track_height))
		var text_pos_x: float = box_pos.x
		var clip_end_x: float = box_pos.x + (clip.duration * zoom)

		if text_pos_x < scroll_amount and text_pos_x + CLIP_TEXT_OFFSET.x <= clip_end_x:
			text_pos_x = scroll_amount

		var visible_rect: Rect2 = Rect2(scroll_amount - 100, box_pos.y, scroll_container.size.x + 200, Timeline.track_height)
		var final_rect: Rect2 = clip_rect.intersection(visible_rect)
		if final_rect.size.x > 0:
			var type_str: String = "Unknown"
			match clip.type:
				EditorCore.Type.IMAGE: type_str = "Image"
				EditorCore.Type.AUDIO: type_str = "Audio"
				EditorCore.Type.VIDEO: type_str = "Video"
				EditorCore.Type.COLOR: type_str = "Color"
				EditorCore.Type.TEXT:  type_str = "Text"
				EditorCore.Type.PCK:   type_str = "Pck"
			var style_name: String = "Clip" + type_str + ("Focus" if box_type == 1 else "Normal")
			var style: StyleBox = get_theme_stylebox(style_name, "Timeline")
			if style:
				draw_style_box(style, final_rect)

		# - Audio waves (Part of clip blocks)
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

		var wave_streams: Dictionary = FileLogic.audio_wave.get(wave_file_id, {})
		var wave_dict: Dictionary = wave_streams.get(clip.effects.audio_stream_index, wave_streams.get(-1, wave_streams.values()[0] if wave_streams.size() > 0 else {}))
		if not wave_dict.is_empty():
			var lod: int = 1
			if zoom < 0.2:
				lod = 16
			elif zoom < 0.8:
				lod = 4

			var audio_wave: PackedFloat32Array = wave_dict[lod]
			var wave_begin: int = int((clip.begin - int(wave_offset_sec * Project.data.framerate)) / float(lod))
			var is_muted: bool = TrackLogic.tracks[clip.track].is_muted or clip.effects.is_muted
			_draw_wave(audio_wave, wave_begin, int(clip.duration / float(lod)), clip_rect, clip.speed, lod, scroll_container, is_muted)

		# - Fading handles + amount
		var show_handles: bool = false
		if (clip.duration * zoom) >= 20.0:
			show_handles = Timeline.hovered_clip == clip or (Timeline.current_state == Timeline.State.FADING and Timeline.fade_target != null and Timeline.fade_target.clip == clip)

		if clip.type in EditorCore.VISUAL_TYPES:
			_draw_fade_handles(clip, box_pos, true, show_handles) # Bottom.
		if clip.type in EditorCore.AUDIO_TYPES:
			_draw_fade_handles(clip, box_pos, false, show_handles) # Top.

		# - Clip speed tint
		if not is_equal_approx(clip.speed, 1.0):
			draw_rect(final_rect, get_theme_color("speed_tint", "Timeline"))

		# - Clip nickname
		if clip_rect.size.x > 20:
			var speed: float = clip.speed
			var text: String = FileLogic.files[clip.file].nickname

			if not is_equal_approx(speed, 1.0):
				var speed_text: String = "speed: %d%%" % int(speed * 100)
				draw_string(
						get_theme_default_font(),
						Vector2(text_pos_x, box_pos.y + Timeline.track_height - 4),
						speed_text,
						HORIZONTAL_ALIGNMENT_LEFT,
						clip_end_x - text_pos_x - CLIP_TEXT_OFFSET.x,
						10,
						Color(1.0, 1.0, 1.0, 0.5))
			draw_string(
					get_theme_default_font(),
					Vector2(text_pos_x, box_pos.y) + CLIP_TEXT_OFFSET,
					text,
					HORIZONTAL_ALIGNMENT_LEFT,
					clip_end_x - text_pos_x - CLIP_TEXT_OFFSET.x,
					11, # Font size.
					get_theme_color("clip_text", "Timeline"))

	# - Draw track state overlays (locked, muted, invisible)
	for i: int in TrackLogic.tracks.size():
		var track: TrackData = TrackLogic.tracks[i]
		var y_pos: float = Timeline.track_total_size * i
		var track_rect: Rect2 = Rect2(scroll_amount, y_pos, scroll_container.size.x, Timeline.track_total_size)

		if track.is_muted or not track.is_visible:
			draw_rect(track_rect, get_theme_color("track_muted", "Timeline"))

		if track.is_locked:
			draw_rect(track_rect, get_theme_color("track_locked", "Timeline"))


func _get_visible(start: int, end: int) -> Array[ClipData]:
	var data: Array[ClipData] = []
	for track: int in TrackLogic.tracks.size():
		data.append_array(TrackLogic.get_clips_in_range(track, start, end))
	return data


func _draw_wave(wave_data: PackedFloat32Array, begin: int, duration: int, rect: Rect2, speed: float, lod: int, scroll_container: ScrollContainer, is_muted: bool) -> void:
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
		var block_pos_y: float = base_y # TOP_TO_BOTTOM style.

		match waveform_style:
			SettingsData.AudioWaveformStyle.CENTER:
				block_pos_y = base_y + (height - block_height) / 2.0
			SettingsData.AudioWaveformStyle.BOTTOM_TO_TOP:
				block_pos_y = base_y + height - block_height

		var wave_color: Color = get_theme_color("audio_wave", "Timeline")
		if is_muted:
			wave_color = get_theme_color("audio_wave_muted", "Timeline")
		draw_rect(Rect2(base_x + (i * zoom), block_pos_y, zoom * step, block_height), wave_color)


func _draw_fade_handles(clip: ClipData, box_pos: Vector2, is_visual: bool, show_handles: bool) -> void:
	var zoom: float = Timeline.zoom
	var duration: float = (clip.duration * zoom)
	var fade: Vector2 = clip.effects.fade_visual if is_visual else clip.effects.fade_audio
	var corner_y: float = box_pos.y + (Timeline.track_height if is_visual else 0.0)
	var opposite_y: float = box_pos.y + (0.0 if is_visual else Timeline.track_height)

	# Draw background and lines. (if fade present)
	if fade.x > 0: # Draw line fade in.
		var fade_in_pts: PackedVector2Array = [
			Vector2(box_pos.x, opposite_y),
			Vector2(box_pos.x, corner_y),
			Vector2(box_pos.x + fade.x * zoom, corner_y)
		]
		draw_colored_polygon(fade_in_pts, get_theme_color("fade_area", "Timeline"))
		draw_line(fade_in_pts[2], fade_in_pts[0], get_theme_color("fade_line", "Timeline"), 1.0, true)

	if fade.y > 0: # Draw line fade out.
		var fade_out_pts: PackedVector2Array = [
			Vector2(box_pos.x + duration, opposite_y),
			Vector2(box_pos.x + duration, corner_y),
			Vector2(box_pos.x + duration - fade.y * zoom, corner_y)
		]
		draw_colored_polygon(fade_out_pts, get_theme_color("fade_area", "Timeline"))
		draw_line(fade_out_pts[2], fade_out_pts[0], get_theme_color("fade_line", "Timeline"), 1.0, true)

	# Draw handles.
	if show_handles:
		var current_handle_size: float = FADE_HANDLE_SIZE
		var in_x: float = box_pos.x + fade.x * zoom
		var out_x: float = box_pos.x + duration - fade.y * zoom - current_handle_size * 2
		current_handle_size *= 2

		var in_rect: Rect2
		var out_rect: Rect2
		if is_visual:
			in_rect = Rect2(in_x, corner_y - current_handle_size, current_handle_size, current_handle_size)
			out_rect = Rect2(out_x, corner_y - current_handle_size, current_handle_size, current_handle_size)
		else:
			in_rect = Rect2(in_x, corner_y, current_handle_size, current_handle_size)
			out_rect = Rect2(out_x, corner_y, current_handle_size, current_handle_size)

		draw_rect(in_rect, get_theme_color("fade_handle", "Timeline"))
		draw_rect(out_rect, get_theme_color("fade_handle", "Timeline"))
