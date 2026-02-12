extends Control
# TODO: Move preview to it's own script

const STYLE_BOX_PREVIEW: StyleBox = preload("uid://dx2v44643hfvy")
const STYLE_BOXES: Dictionary[FileLogic.TYPE, Array] = {
	FileLogic.TYPE.IMAGE: [preload(Library.STYLE_BOX_CLIP_IMAGE_NORMAL), preload(Library.STYLE_BOX_CLIP_IMAGE_FOCUS)],
	FileLogic.TYPE.AUDIO: [preload(Library.STYLE_BOX_CLIP_AUDIO_NORMAL), preload(Library.STYLE_BOX_CLIP_AUDIO_FOCUS)],
	FileLogic.TYPE.VIDEO: [preload(Library.STYLE_BOX_CLIP_VIDEO_NORMAL), preload(Library.STYLE_BOX_CLIP_VIDEO_FOCUS)],
	FileLogic.TYPE.VIDEO_ONLY: [preload(Library.STYLE_BOX_CLIP_VIDEO_NORMAL), preload(Library.STYLE_BOX_CLIP_VIDEO_FOCUS)],
	FileLogic.TYPE.COLOR: [preload(Library.STYLE_BOX_CLIP_COLOR_NORMAL), preload(Library.STYLE_BOX_CLIP_COLOR_FOCUS)],
	FileLogic.TYPE.TEXT:  [preload(Library.STYLE_BOX_CLIP_TEXT_NORMAL), preload(Library.STYLE_BOX_CLIP_TEXT_FOCUS)],
}
const TEXT_OFFSET: Vector2 = Vector2(5, 20)


@onready var timeline: PanelContainer = get_parent()

@onready var zoom: float = timeline.zoom
@onready var scroll: ScrollContainer = get_parent().get_parent()
@onready var draggable: Draggable = timeline.draggable
@onready var track_height: float = timeline.TRACK_HEIGHT
@onready var track_total_size: float = timeline.TRACK_TOTAL_SIZE


var waveform_style: int = Settings.get_audio_waveform_style()
var waveform_amp: float = Settings.get_audio_waveform_amp()


func _ready() -> void:
	Project.project_ready.connect(_on_project_ready)
	Settings.on_waveform_update.connect(update_waveform_data)


func _on_project_ready() -> void:
	Project.clips.updated.connect(update_clips)
	Project.clips.selected.connect(update_clips.unbind(1))


func _draw() -> void:
	zoom = timeline.zoom
	draggable = timeline.draggable

	var scroll_amount: float = scroll.scroll_horizontal
	var visible_start: int = floori(scroll_amount / zoom)
	var visible_end: int = ceili(visible_start + (size.x / zoom))

	var visible_clips: PackedInt64Array = _get_visible(visible_start, visible_end)
	var handled_clips: PackedInt64Array = []

	# - Previews
	if timeline.state in [timeline.STATE.MOVING, timeline.STATE.DROPPING] and draggable != null: # Moving + Dropping preview
		if draggable.files:
			var preview_position: Vector2 = Vector2(
					(draggable.frame_offset) * timeline.zoom,
					draggable.track_offset * track_total_size)
			var preview_size: Vector2 = Vector2(draggable.duration * timeline.zoom, track_height)

			draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
		else:
			for clip_id: int in draggable.ids:
				var index: int = Project.clips.get_index(clip_id)
				var duration: int = Project.clips.get_duration(index)
				var start: int = Project.clips.get_start(index) + draggable.frame_offset
				var track: int = Project.clips.get_track_id(index) + draggable.track_offset
				var preview_position: Vector2 = Vector2(start * zoom, track * track_total_size)
				var preview_size: Vector2 = Vector2(duration * zoom, track_height)

				draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
				if clip_id in timeline.visible_clips:
					handled_clips.append(clip_id)
	elif timeline.state == timeline.STATE.RESIZING: # Resizing preview
		var index: int = Project.clips.get_index(timeline.resize_target.clip_id)
		var track_id: int = Project.clips.get_track_id(index)
		var start: int = Project.clips.get_start(index)
		var duration: int = Project.clips.get_duration(index)
		var draw_start: float = start
		var draw_length: int = Project.clips.get_duration(index)

		if !timeline.resize_target.is_end:
			draw_start += timeline.resize_target.delta * zoom
			draw_length -= timeline.resize_target.delta
		else:
			draw_length += timeline.resize_target.delta

		var preview_position: Vector2 = Vector2(draw_start, track_id * track_total_size)
		var preview_size: Vector2 = Vector2(draw_length * zoom, track_height)
		var box_pos: Vector2 = Vector2(start * zoom, track_total_size * track_id)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(duration * zoom, track_height))

		# Drawing the original clip box and actual resized box.
		draw_rect(clip_rect, Color(1.0, 1.0, 1.0, 0.3))
		draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))

		if timeline.resize_target.clip_id in visible_clips:
			handled_clips.append(timeline.resize_target.clip_id)

	# - Clip blocks
	for id: int in visible_clips:
		if id in handled_clips:
			continue
		var index: int = Project.clips.get_index(id)
		var start: int = Project.clips.get_start(index)
		var begin: int = Project.clips.get_begin(index)
		var duration: int = Project.clips.get_duration(index)
		var track_id: int = Project.clips.get_track_id(index)
		var file_id: int = Project.clips.get_file_id(index)
		var box_type: int = 1 if id in timeline.selected_clip_ids else 0
		var box_pos: Vector2 = Vector2(start * zoom, track_total_size * track_id)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(duration * zoom, track_height))
		var text_pos_x: float = box_pos.x
		var clip_end_x: float = box_pos.x + (duration * zoom)

		if text_pos_x < scroll_amount  and text_pos_x + TEXT_OFFSET.x <= clip_end_x:
			text_pos_x = scroll_amount

		draw_style_box(STYLE_BOXES[Project.clips.get_type(id)][box_type], clip_rect)
		draw_string(
				get_theme_default_font(),
				Vector2(text_pos_x, box_pos.y) + TEXT_OFFSET,
				Project.files.get_nickname_by_id(file_id),
				HORIZONTAL_ALIGNMENT_LEFT, duration * zoom - TEXT_OFFSET.x,
				11, # Font size
				Color(0.9, 0.9, 0.9))

		# - Audio waves (Part of clip blocks)
		_draw_wave(Project.files.get_audio_wave(file_id), begin, duration, clip_rect)

		# - Fading handles + amount
		var show_handles: bool = (timeline.hovered_clip != null and timeline.hovered_clip.id == id) or \
				(timeline.state == timeline.STATE.FADING and timeline.fade_target.clip_id == id)
		if Project.clips.is_visual(index):
			_draw_fade_handles(index, box_pos, true, show_handles) # Bottom.
		if Project.clips.is_audio(index):
			_draw_fade_handles(index, box_pos, false, show_handles) # Top


func _get_visible(start: int, end: int) -> PackedInt64Array:
	var data: PackedInt64Array = []
	for track_id: int in Project.data.tracks_is_muted.size():
		data.append_array(Project.tracks.get_clip_ids_in(track_id, start, end))
	return data


func _draw_wave(wave_data: PackedFloat32Array, begin: int, duration: int, rect: Rect2) -> void:
	if wave_data.is_empty():
		return
	var display_duration: int = duration
	var display_begin_offset: int = begin
	var height: float = rect.size.y
	var base_x: float = rect.position.x
	var base_y: float = rect.position.y

	for i: int in display_duration:
		var wave_index: int = display_begin_offset + i
		if wave_index >= wave_data.size():
			break

		var normalized_height: float = wave_data[wave_index] * waveform_amp
		var block_height: float = clampf(normalized_height * (height * 0.9), 0, height)
		var block_pos_y: float = base_y # TOP_TO_BOTTOM style

		match waveform_style:
			SettingsData.AUDIO_WAVEFORM_STYLE.CENTER:
				block_pos_y = base_y + (height - block_height) / 2.0
			SettingsData.AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP:
				block_pos_y = base_y + height - block_height
		draw_rect(Rect2(base_x + (i * zoom), block_pos_y, zoom, block_height), timeline.COLOR_AUDIO_WAVE)


func _draw_fade_handles(index: int, box_pos: Vector2, is_visual: bool, show_handles: bool) -> void:
	var handle_radius: float = timeline.FADE_HANDLE_SIZE / 4.0
	var duration: int = Project.clips.get_duration(index)
	var effects: ClipEffects = Project.clips.get_effects(index)
	var fade: Vector2 = effects.fade_visual if is_visual else effects.fade_audio

	var real_duration: float = (duration * zoom)

	var clip_end_x: float = box_pos.x + real_duration
	var handle_y: float = box_pos.y
	if is_visual:
		handle_y += track_height - (handle_radius/2.0)
	else:
		handle_y += (handle_radius/2.0)

	fade.x = box_pos.x + (fade.x * zoom)
	fade.y = clip_end_x - (fade.y * zoom)

	if show_handles:
		handle_radius *= 2
		draw_circle(Vector2(fade.x, handle_y), handle_radius, timeline.FADE_HANDLE_COLOR) # Fade in handle
		draw_circle(Vector2(fade.y, handle_y), handle_radius, timeline.FADE_HANDLE_COLOR) # Fade out handle

	if fade.x > 0: # Draw line fade in (Top Left to Bottom Right/Handle)
		var start_y: float = box_pos.y if is_visual else (box_pos.y + track_height)
		draw_line(Vector2(box_pos.x, start_y), Vector2(fade.x, handle_y), timeline.FADE_LINE_COLOR, 1.0, true)
	if fade.y > 0: # Draw line fade out (Bottom Left/Handle to Top Right)
		var end_y: float = box_pos.y if is_visual else (box_pos.y + track_height)
		var from_pos: Vector2 = Vector2(fade.y, handle_y)
		var to_pos: Vector2 = Vector2(box_pos.x + real_duration, end_y)
		draw_line(from_pos, to_pos, timeline.FADE_LINE_COLOR, 1.0, true)


func update_clips() -> void: queue_redraw()


func update_waveform_data() -> void:
	waveform_style = Settings.get_audio_waveform_style()
	waveform_amp = Settings.get_audio_waveform_amp()
