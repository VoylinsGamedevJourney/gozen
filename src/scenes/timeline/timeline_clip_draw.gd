extends Control
# TODO: Move preview to it's own script

const STYLE_BOX_PREVIEW: StyleBox = preload("uid://dx2v44643hfvy")
const STYLE_BOXES: Dictionary[FileHandler.TYPE, Array] = {
    FileHandler.TYPE.IMAGE: [preload(Library.STYLE_BOX_CLIP_IMAGE_NORMAL), preload(Library.STYLE_BOX_CLIP_IMAGE_FOCUS)],
    FileHandler.TYPE.AUDIO: [preload(Library.STYLE_BOX_CLIP_AUDIO_NORMAL), preload(Library.STYLE_BOX_CLIP_AUDIO_FOCUS)],
    FileHandler.TYPE.VIDEO: [preload(Library.STYLE_BOX_CLIP_VIDEO_NORMAL), preload(Library.STYLE_BOX_CLIP_VIDEO_FOCUS)],
    FileHandler.TYPE.VIDEO_ONLY: [preload(Library.STYLE_BOX_CLIP_VIDEO_NORMAL), preload(Library.STYLE_BOX_CLIP_VIDEO_FOCUS)],
    FileHandler.TYPE.COLOR: [preload(Library.STYLE_BOX_CLIP_COLOR_NORMAL), preload(Library.STYLE_BOX_CLIP_COLOR_FOCUS)],
    FileHandler.TYPE.TEXT:  [preload(Library.STYLE_BOX_CLIP_TEXT_NORMAL), preload(Library.STYLE_BOX_CLIP_TEXT_FOCUS)],
}
const TEXT_OFFSET: Vector2 = Vector2(5, 20)


@onready var timeline: PanelContainer = get_parent()


@onready var zoom: float = timeline.zoom
@onready var scroll: ScrollContainer = timeline.scroll
@onready var draggable: Draggable = timeline.draggable
@onready var track_height: float = timeline.TRACK_HEIGHT
@onready var track_total_size: float = timeline.TRACK_TOTAL_SIZE


func _ready() -> void:
	ClipHandler.clips_updated.connect(update_clips)
	ClipHandler.clip_selected.connect(update_clips.unbind(1))


func _draw() -> void:
	zoom = timeline.zoom
	scroll = timeline.scroll
	draggable = timeline.draggable
	track_height = timeline.TRACK_HEIGHT
	track_total_size = timeline.TRACK_TOTAL_SIZE

	var visible_start: int = floori(scroll.scroll_horizontal / zoom)
	var visible_end: int = ceili(visible_start + (size.x / zoom))

	var visible_clip_ids: PackedInt64Array = []
	var handled_clip_ids: PackedInt64Array = []
	var waveform_style: int = Settings.get_audio_waveform_style()
	var waveform_amp: float = Settings.get_audio_waveform_amp()

	# Get all visible clips.
	for track_id: int in TrackHandler.get_tracks_size():
		for clip: ClipData in TrackHandler.get_clips_in(track_id, visible_start, visible_end):
			visible_clip_ids.append(clip.id)

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
				var clip_data: ClipData = ClipHandler.get_clip(clip_id)
				var new_start: int = clip_data.start_frame + draggable.frame_offset
				var new_track: int = clip_data.track_id + draggable.track_offset

				var preview_position: Vector2 = Vector2(
						new_start * zoom,
						new_track * track_total_size)
				var preview_size: Vector2 = Vector2(clip_data.duration * zoom, track_height)

				draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))

				if clip_id in timeline.visible_clip_ids:
					handled_clip_ids.append(clip_id)
	elif timeline.state == timeline.STATE.RESIZING: # Resizing preview
		var clip_data: ClipData = ClipHandler.get_clip(timeline.resize_target.clip_id)
		var draw_start: float = clip_data.start_frame
		var draw_length: int = clip_data.duration

		if timeline.resize_target.is_end:
			draw_length += timeline.resize_target.delta
		else:
			draw_start += timeline.resize_target.delta * zoom
			draw_length -= timeline.resize_target.delta

		var preview_position: Vector2 = Vector2(draw_start, clip_data.track_id * track_total_size)
		var preview_size: Vector2 = Vector2(draw_length * zoom, track_height)

		var box_pos: Vector2 = Vector2(clip_data.start_frame * zoom, track_total_size * clip_data.track_id)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip_data.duration * zoom, track_height))

		# Drawing the original clip box
		draw_rect(clip_rect, Color(1.0, 1.0, 1.0, 0.3))

		# Drawing the actual resized box
		draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))

		if timeline.resize_target.clip_id in visible_clip_ids:
			handled_clip_ids.append(timeline.resize_target.clip_id)

	# - Clip blocks
	for clip_id: int in visible_clip_ids:
		if clip_id in handled_clip_ids:
			continue

		var clip_data: ClipData = ClipHandler.get_clip(clip_id)
		var box_type: int = 1 if clip_data.id in timeline.selected_clip_ids else 0
		var box_pos: Vector2 = Vector2(clip_data.start_frame * zoom, track_total_size * clip_data.track_id)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip_data.duration * zoom, track_height))
		var text_pos_x: float = box_pos.x
		var clip_end_x: float = box_pos.x + (clip_data.duration * zoom)

		if text_pos_x < scroll.scroll_horizontal and text_pos_x + TEXT_OFFSET.x <= clip_end_x:
			text_pos_x = scroll.scroll_horizontal

		draw_style_box(STYLE_BOXES[ClipHandler.get_type(clip_data.id)][box_type], clip_rect)
		draw_string(
				get_theme_default_font(),
				Vector2(text_pos_x, box_pos.y) + TEXT_OFFSET,
				FileHandler.get_file_name(clip_data.file_id),
				HORIZONTAL_ALIGNMENT_LEFT, clip_data.duration * zoom - TEXT_OFFSET.x,
				11, # Font size
				Color(0.9, 0.9, 0.9))

		# - Audio waves (Part of clip blocks)
		var wave_data: PackedFloat32Array = FileHandler.get_file_data(clip_data.file_id).audio_wave_data

		if !wave_data.is_empty():
			var display_duration: int = clip_data.duration
			var display_begin_offset: int = clip_data.begin
			var height: float = clip_rect.size.y
			var base_x: float = clip_rect.position.x
			var base_y: float = clip_rect.position.y

			for i: int in display_duration:
				var index: int = display_begin_offset + i

				if index >= wave_data.size():
					break

				var normalized_height: float = wave_data[index] * waveform_amp
				var block_height: float = clampf(normalized_height * (height * 0.9), 0, height)
				var block_pos_y: float = base_y # TOP_TO_BOTTOM style

				match waveform_style:
					SettingsData.AUDIO_WAVEFORM_STYLE.CENTER:
						block_pos_y = base_y + (height - block_height) / 2.0
					SettingsData.AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP:
						block_pos_y = base_y + height - block_height

				var sample_rect: Rect2 = Rect2(
					base_x + (i * zoom),
					block_pos_y,
					zoom,
					block_height)
				draw_rect(sample_rect, timeline.COLOR_AUDIO_WAVE)

		# - Fading handles + amount
		var show_handles: bool = (timeline.hovered_clip != null and timeline.hovered_clip.id == clip_id) or \
				(timeline.state == timeline.STATE.FADING and timeline.fade_target.clip_id == clip_id)
		if ClipHandler.get_type(clip_id) in EditorCore.VISUAL_TYPES: # Bottom handles
			_draw_fade_handles(clip_data, box_pos, true, show_handles)
		if ClipHandler.get_type(clip_id) in EditorCore.AUDIO_TYPES: # Top handles
			_draw_fade_handles(clip_data, box_pos, false, show_handles)


func _draw_fade_handles(clip_data: ClipData, box_pos: Vector2, is_visual: bool, show_handles: bool) -> void:
	var handle_radius: float = timeline.FADE_HANDLE_SIZE / 4.0
	var clip_end_x: float = box_pos.x + (clip_data.duration * zoom)
	var fade_in_length: int = clip_data.fade_in_visual if is_visual else clip_data.fade_in_audio
	var fade_out_length: int = clip_data.fade_out_visual if is_visual else clip_data.fade_out_audio

	var fade_in_x: float = box_pos.x + (fade_in_length * zoom)
	var fade_out_x: float = clip_end_x - (fade_out_length * zoom)
	var handle_y: float = box_pos.y
	if is_visual:
		handle_y += track_height - (handle_radius/2.0)
	else:
		handle_y += (handle_radius/2.0)

	if show_handles:
		handle_radius *= 2
		draw_circle(Vector2(fade_in_x, handle_y), handle_radius, timeline.FADE_HANDLE_COLOR) # Fade in handle
		draw_circle(Vector2(fade_out_x, handle_y), handle_radius, timeline.FADE_HANDLE_COLOR) # Fade out handle

	if fade_in_length > 0: # Draw line fade in (Top Left to Bottom Right/Handle)
		var start_y: float = box_pos.y if is_visual else (box_pos.y + track_height)
		draw_line(Vector2(box_pos.x, start_y), Vector2(fade_in_x, handle_y), timeline.FADE_LINE_COLOR, 1.0, true)
	if fade_out_length > 0: # Draw line fade out (Bottom Left/Handle to Top Right)
		var end_y: float = box_pos.y if is_visual else (box_pos.y + track_height)
		var from_pos: Vector2 = Vector2(fade_out_x, handle_y)
		var to_pos: Vector2 = Vector2(box_pos.x + (clip_data.duration * zoom), end_y)
		draw_line(from_pos, to_pos, timeline.FADE_LINE_COLOR, 1.0, true)


func update_clips() -> void:
	queue_redraw()

