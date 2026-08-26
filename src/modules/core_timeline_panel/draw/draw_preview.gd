extends Control

enum SPLIT_AUDIO { NONE, SHIFT, CTRL }


@onready var scroll_container: ScrollContainer = get_parent().get_parent()


var draggable: Draggable = null

var offset_frames: int = 0
var split_audio: SPLIT_AUDIO = SPLIT_AUDIO.NONE

var preview_size: Vector2 = Vector2.ZERO
var preview_pos: Vector2 = Vector2.ZERO

var box_pos: Vector2 = Vector2.ZERO
var clip_rect: Rect2 = Rect2()

var wave_file_id: int = 0
var wave_offset: float = 0.0 ## In seconds.
var wave_streams: Dictionary = {}
var wave_dict: Dictionary = {}
var is_muted: bool = false



func _draw() -> void:
	match Timeline.current_state:
		Timeline.State.RESIZING: _handle_clip(false)
		Timeline.State.SPEEDING: _handle_clip(true)
		Timeline.State.DROPPING: _handle_draggable()
		Timeline.State.MOVING:   _handle_draggable()


func _get_wave_dict(index: int) -> Dictionary:
	if wave_streams.is_empty(): return {}
	if wave_streams.has(index): return wave_streams[index]
	if wave_streams.has(-1):    return wave_streams[-1]
	return wave_streams.values()[0]


func _set_wave_source(clip: ClipData) -> void:
	wave_file_id = clip.file
	wave_offset = 0.0
	var effects: ClipEffects = clip.effects

	if clip.effects and effects.ato_active and effects.ato_file != -1:
		wave_file_id = effects.ato_file
		wave_offset = effects.ato_offset
		return

	var target_file: FileData = FileLogic.files.get(clip.file)
	if target_file and target_file.ato_active and target_file.ato_file != -1:
		wave_file_id = target_file.ato_file
		wave_offset = target_file.ato_offset


#--- HANDLERS ---

func _handle_draggable() -> void:
	if Timeline.draggable == null or !Timeline.drop_valid: return
	draggable = Timeline.draggable

	if draggable.is_file:
		if Input.is_key_pressed(KEY_SHIFT):  split_audio = SPLIT_AUDIO.SHIFT
		elif Input.is_key_pressed(KEY_CTRL): split_audio = SPLIT_AUDIO.CTRL
		else: split_audio = SPLIT_AUDIO.NONE

		offset_frames = 0
		for file_id: int in draggable.ids:
			offset_frames += _handle_draggable_file(FileLogic.files[file_id])
		return

	# For preview clips only.
	for clip_id: int in draggable.ids:
		var clip: ClipData = ClipLogic.clips[clip_id]
		var track: int = clip.track
		preview_pos.x = (clip.start + draggable.frame_offset) * Timeline.zoom
		preview_pos.y = (track + draggable.track_offset) * Timeline.track_total_size
		preview_size.x = clip.duration * Timeline.zoom
		preview_size.y = Timeline.track_height

		clip_rect = Rect2(preview_pos, preview_size)
		draw_style_box(get_theme_stylebox("ClipPreview", "Timeline"), clip_rect)

		_set_wave_source(clip)

		wave_streams = FileLogic.audio_wave.get(wave_file_id, {})
		wave_dict = _get_wave_dict(clip.effects.audio_stream_index)
		if not wave_dict.is_empty():
			var begin: int = (clip.begin - int(wave_offset * Project.data.framerate))
			is_muted = TrackLogic.tracks[track].is_muted or clip.effects.is_muted
			_draw_wave(begin, clip.duration, clip.speed)


func _handle_draggable_file(file: FileData) -> int: ## Returns file duration.
	var multi_audio_streams: bool = file.audio_streams.size() > 0
	var is_video: bool = file.type == EditorCore.Type.VIDEO
	var is_split_video: bool = multi_audio_streams and is_video and split_audio != 0
	preview_size = Vector2(file.duration * Timeline.zoom, Timeline.track_height)

	if is_split_video: _draw_split_video_preview(file)
	else: _draw_clip_preview(file)
	return file.duration


func _handle_clip(is_speeding: bool) -> void:
	var clip: ClipData = Timeline.resize_target.clip
	var draw_start: float = clip.start
	var draw_length: int = clip.duration
	var draw_begin: int = clip.begin
	var draw_speed: float = clip.speed

	if !Timeline.resize_target.is_end:
		draw_start += Timeline.resize_target.delta
		draw_length -= Timeline.resize_target.delta
		if Timeline.current_state == Timeline.State.RESIZING:
			draw_begin += int(Timeline.resize_target.delta * clip.speed)
	else: draw_length += Timeline.resize_target.delta

	if is_speeding: draw_speed = (clip.duration * clip.speed) / float(maxi(draw_length, 1))

	preview_pos = Vector2(draw_start * Timeline.zoom, clip.track * Timeline.track_total_size)
	preview_size = Vector2(draw_length * Timeline.zoom, Timeline.track_height)
	box_pos = Vector2(clip.start * Timeline.zoom, Timeline.track_total_size * clip.track)

	var clip_size: Vector2 = Vector2(clip.duration * Timeline.zoom, Timeline.track_height)
	clip_rect = Rect2(box_pos, clip_size)

	# Drawing the original clip box and actual resized box.
	draw_rect(clip_rect, get_theme_color("speeding", "Timeline") if is_speeding else get_theme_color("resizing", "Timeline"))

	# Clip rect is re-used for the preview.
	clip_rect = Rect2(preview_pos, preview_size)
	draw_style_box(get_theme_stylebox("ClipPreview", "Timeline"), clip_rect)

	_set_wave_source(clip)
	wave_streams = FileLogic.audio_wave.get(wave_file_id, {})
	wave_dict = _get_wave_dict(clip.effects.audio_stream_index)
	if not wave_dict.is_empty():
		var begin: int = (draw_begin - int(wave_offset * Project.data.framerate))
		is_muted = TrackLogic.tracks[clip.track].is_muted or clip.effects.is_muted
		_draw_wave(begin, draw_length, draw_speed)


#--- DRAW LOGIC ---

func _draw_split_video_preview(file: FileData) -> void:
	var video_preview_position: Vector2 = Vector2(
			(draggable.frame_offset + offset_frames) * Timeline.zoom,
			draggable.track_offset * Timeline.track_total_size)
	draw_style_box(get_theme_stylebox("ClipPreview", "Timeline"), Rect2(video_preview_position, preview_size))

	wave_streams = FileLogic.audio_wave.get(file.id, {})
	if split_audio == SPLIT_AUDIO.CTRL:
		var stream_index: int = file.audio_streams[0]
		wave_dict = _get_wave_dict(stream_index)

		if not wave_dict.is_empty():
			clip_rect = Rect2(video_preview_position, preview_size)
			is_muted = false
			_draw_wave(0, file.duration, 1.0)

	# Draw audio previews.
	var start_i: int = 0 if split_audio == SPLIT_AUDIO.SHIFT else 1
	for i: int in range(start_i, file.audio_streams.size()):
		var audio_track_idx: int = draggable.track_offset + 1 + (i - start_i)
		var audio_preview_position: Vector2 = Vector2(
				(draggable.frame_offset + offset_frames) * Timeline.zoom,
				audio_track_idx * Timeline.track_total_size)
		clip_rect = Rect2(audio_preview_position, preview_size)
		draw_style_box(get_theme_stylebox("ClipPreview", "Timeline"), clip_rect)

		var stream_index: int = file.audio_streams[i]
		wave_dict = _get_wave_dict(stream_index)
		if not wave_dict.is_empty():
			is_muted = false
			_draw_wave(0, file.duration, 1.0)


func _draw_clip_preview(file: FileData) -> void:
	preview_pos.x = (draggable.frame_offset + offset_frames) * Timeline.zoom
	preview_pos.y = draggable.track_offset * Timeline.track_total_size

	clip_rect = Rect2(preview_pos, preview_size)
	draw_style_box(get_theme_stylebox("ClipPreview", "Timeline"), clip_rect)

	if file.type in EditorCore.AUDIO_TYPES:
		wave_streams = FileLogic.audio_wave.get(file.id, {})
		wave_dict = _get_wave_dict(-1)
		if not wave_dict.is_empty():
			is_muted = false
			_draw_wave(0, file.duration, 1.0)


func _draw_wave(begin: int, total_duration: int, speed: float) -> void:
	var lod: int = 1
	if Timeline.zoom < 0.2: lod = 16
	elif Timeline.zoom < 0.8: lod = 4

	begin /= lod

	var duration: int = int(total_duration / float(lod))
	var wave_data: PackedFloat32Array = wave_dict.get(lod, [])
	if wave_data.is_empty(): return

	var zoom: float = Timeline.zoom * lod
	var height: float = clip_rect.size.y
	var base_x: float = clip_rect.position.x
	var base_y: float = clip_rect.position.y
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
		if wave_index < 0 or wave_index >= wave_data.size(): continue

		var max_value: float = 0.0
		var end: int = mini(wave_index + maxi(1, int(step * speed)), wave_data.size())
		for index: int in range(wave_index, end):
			if wave_data[index] > max_value:
				max_value = wave_data[index]

		var normalized_height: float = max_value * waveform_amp
		var block_height: float = clampf(normalized_height * (height * 0.9), 0, height)
		var block_pos_y: float = base_y

		if waveform_style == SettingsData.AudioWaveformStyle.CENTER:
			block_pos_y = base_y + (height - block_height) / 2.0
		elif waveform_style == SettingsData.AudioWaveformStyle.BOTTOM_TO_TOP:
				block_pos_y = base_y + height - block_height

		draw_rect(
				Rect2(base_x + (i * zoom), block_pos_y, zoom * step, block_height),
				get_theme_color("audio_wave_muted", "Timeline") if is_muted else get_theme_color("audio_wave", "Timeline"))
