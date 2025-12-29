extends PanelContainer


signal zoom_changed(new_zoom: float)


const TRACK_HEIGHT: int = 30
const TRACK_LINE_WIDTH: int = 1
const TRACK_LINE_COLOR: Color = Color.DIM_GRAY
const TRACK_TOTAL_SIZE: int = TRACK_HEIGHT + TRACK_LINE_WIDTH

const ZOOM_MIN: float = 0.1
const ZOOM_MAX: float = 20.0
const ZOOM_STEP: float = 1.1

const PLAYHEAD_WIDTH: int = 2

const SNAPPING: int = 30

const STYLE_BOX_PREVIEW: StyleBox = preload("uid://dx2v44643hfvy")
const STYLE_BOXES: Dictionary[File.TYPE, Array] = {
    File.TYPE.IMAGE: [preload(Library.STYLE_BOX_CLIP_IMAGE_NORMAL), preload(Library.STYLE_BOX_CLIP_IMAGE_FOCUS)],
    File.TYPE.AUDIO: [preload(Library.STYLE_BOX_CLIP_AUDIO_NORMAL), preload(Library.STYLE_BOX_CLIP_AUDIO_FOCUS)],
    File.TYPE.VIDEO: [preload(Library.STYLE_BOX_CLIP_VIDEO_NORMAL), preload(Library.STYLE_BOX_CLIP_VIDEO_FOCUS)],
    File.TYPE.COLOR: [preload(Library.STYLE_BOX_CLIP_COLOR_NORMAL), preload(Library.STYLE_BOX_CLIP_COLOR_FOCUS)],
    File.TYPE.TEXT:  [preload(Library.STYLE_BOX_CLIP_TEXT_NORMAL), preload(Library.STYLE_BOX_CLIP_TEXT_FOCUS)],
}
const TEXT_OFFSET: Vector2 = Vector2(5, 20)


@onready var scroll: ScrollContainer = get_parent()


var zoom: float = 1.0
var selected_clip_ids: PackedInt64Array = []

var draggable: Draggable = null
var can_drop_data: bool = false



func _ready() -> void:
	Project.project_ready.connect(_project_ready)
	set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	Project.timeline_end_update.connect(func(_v :Variant) -> void: queue_redraw())
	ClipHandler.clip_added.connect(func(_v :Variant) -> void: queue_redraw())
	ClipHandler.clip_deleted.connect(func(_v :Variant) -> void: queue_redraw())
	EditorCore.frame_changed.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if !Project.loaded:
		return

	if event is InputEventMouseButton:
		if event.is_action_pressed("timeline_zoom_in", false, true):
			zoom_at_mouse(ZOOM_STEP)
		elif event.is_action_pressed("timeline_zoom_out", false, true):
			zoom_at_mouse(1.0 / ZOOM_STEP)
		else:
			_on_gui_input_mouse(event)
			get_window().gui_release_focus()
			queue_redraw()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			scroll.scroll_horizontal = max(scroll.scroll_horizontal - event.relative.x, 0.0)
			queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("delete_clips"):
		ClipHandler.delete_clips(selected_clip_ids)


func _on_gui_input_mouse(event: InputEventMouseButton) -> void:
	if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if clip is pressed or not.
		var clip: ClipData = _get_clip_on_mouse()

		if clip != null:
			if event.shift_pressed:
				selected_clip_ids.append(clip.id)
			else:
				selected_clip_ids = [clip.id]
		else:
			selected_clip_ids = []
	elif event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		# TODO: Right click menu
		pass


func _draw() -> void:
	var visible_clip_ids: PackedInt64Array = []
	var visible_start: int = floori(scroll.scroll_horizontal / zoom)
	var visible_end: int = ceili(visible_start + (size.x / zoom))

	for track_id: int in TrackHandler.get_tracks_size():
		for clip: ClipData in TrackHandler.get_clips_in(track_id, visible_start, visible_end):
			visible_clip_ids.append(clip.id)

	# - Track lines
	for i: int in TrackHandler.tracks.size() - 1:
		var y: int  = TRACK_TOTAL_SIZE * (i + 1)

		draw_dashed_line(Vector2(0, y), Vector2(size.x, y), TRACK_LINE_COLOR, TRACK_LINE_WIDTH)

	# - Playhead
	var playhead_pos: float = EditorCore.frame_nr * zoom
	draw_line(
			Vector2(playhead_pos, 0), Vector2(playhead_pos, size.y),
			Color(0.4, 0.4, 0.4), PLAYHEAD_WIDTH)

	# - Clip preview(s) - moving or dragging new clip
	if can_drop_data and draggable.files:
		var preview_position: Vector2 = Vector2(
				(draggable.frame_offset) * zoom,
				draggable.track_offset * TRACK_TOTAL_SIZE)
		var preview_size: Vector2 = Vector2(draggable.duration * zoom, TRACK_HEIGHT)

		draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
	elif can_drop_data:
		for clip_id: int in draggable.ids:
			var clip_data: ClipData = ClipHandler.get_clip(clip_id)
			var preview_position: Vector2 = Vector2(
					(clip_data.start_frame - draggable.offset.x) * zoom,
					(clip_data.track_id - draggable.offset.y) * TRACK_TOTAL_SIZE)
			var preview_size: Vector2 = Vector2(clip_data.duration * zoom, TRACK_HEIGHT)

			draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))

	# - Clip blocks
	for clip_id: int in visible_clip_ids:
		var clip: ClipData = ClipHandler.get_clip(clip_id)
		var box_type: int = 1 if clip.id in selected_clip_ids else 0
		var pos: Vector2 = Vector2(clip.start_frame * zoom, TRACK_TOTAL_SIZE * clip.track_id)
		var new_clip: Rect2 = Rect2(pos, Vector2(clip.duration * zoom, TRACK_HEIGHT))

		draw_style_box(STYLE_BOXES[ClipHandler.get_clip_type(clip)][box_type], new_clip)
		draw_string(
				get_theme_default_font(),
				pos + TEXT_OFFSET,
				FileHandler.get_file_name(clip.file_id),
				HORIZONTAL_ALIGNMENT_LEFT, 0,
				11, # Font size
				Color(0.9, 0.9, 0.9))
		
	# TODO: - Audio waves

	# TODO: - Fading handles + amount


func _get_clip_on_mouse() -> ClipData:
	return TrackHandler.get_clip_at(get_track_from_mouse(), get_frame_from_mouse())


func _project_ready() -> void:
	custom_minimum_size.y = TRACK_TOTAL_SIZE * TrackHandler.tracks.size()
	queue_redraw()


func _get_drag_data(_p: Vector2) -> Variant:
	# TODO:
	# Moving clip logic
	# Decide if I'm in an empty space on the timeline to create a selection box.
	# Also check if I'm not dragging a fade handle.
	# If not, check if selected clip is part of selected group and move the selected clip(s)
	return Draggable.new()


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is not Draggable: return false

	can_drop_data = false
	draggable = data
	can_drop_data = _can_drop_new_clips() if draggable.files else _can_move_clips()
	
	queue_redraw()
	return can_drop_data


func _can_drop_new_clips() -> bool:
	draggable.track_offset = get_track_from_mouse()
	var mouse_frame: int = get_frame_from_mouse()
	var target_frame: int = mouse_frame - draggable.mouse_offset
	var target_end: int = target_frame + draggable.duration
	var clip_at_pos: ClipData = TrackHandler.get_clip_at(draggable.track_offset, target_frame)
	var clip_at_end: ClipData = TrackHandler.get_clip_at(draggable.track_offset, target_end)
	var free_region: Vector2i

	if target_frame < 0:
		target_end += abs(target_frame)
		target_frame = 0

	if clip_at_pos == null:
		free_region = TrackHandler.get_free_region(draggable.track_offset, target_frame)

		if free_region.y > target_end:
			draggable.frame_offset = target_frame
			return true # Space fully available from target_frame to target_end
		elif free_region.y - free_region.x < draggable.duration:
			return false # No space

		# Check what space is needed on right side and if within snapping
		# Possible with snapping so checking if enough space on left side
		var distance_necessary: int = target_end - free_region.y
		if distance_necessary > SNAPPING or target_frame - free_region.x > distance_necessary:
			return false

		draggable.frame_offset = target_frame + distance_necessary
		return true
	elif clip_at_end != null:
		return false # Not possible to find space
	else:
		free_region = TrackHandler.get_free_region(draggable.track_offset, target_end)

		if free_region.y - free_region.x < draggable.duration:
			return false # No space

		# Check what space is needed on left side and if within snapping
		# Possible with snapping so checking if enough space on left side
		var distance_necessary: int = target_frame - free_region.x
		if distance_necessary > SNAPPING or target_end - free_region.y > distance_necessary:
			return false

		draggable.frame_offset = target_frame - distance_necessary
		return true


func _can_move_clips() -> bool:
	return false


func _drop_data(_p: Vector2, data: Variant) -> void:
	if data is not Draggable: return

	if draggable.files: # Creating new clips (ids are file ids!)
		var clips: Array[CreateClipRequest] = []
		var total_duration: int = 0

		for id: int in draggable.ids:
			var request: CreateClipRequest = CreateClipRequest.new(
					id, draggable.track_offset, draggable.frame_offset + total_duration)

			total_duration += FileHandler.get_file_duration(id)
			clips.append(request)

		ClipHandler.add_clips(clips)
	else: # Moving clips
		pass

	can_drop_data = false
	draggable = null

	queue_redraw()


func _on_mouse_exited() -> void:
	can_drop_data = false
	queue_redraw()


func zoom_at_mouse(factor: float) -> void:
	var old_zoom: float = zoom
	var old_mouse_pos_x: float = get_local_mouse_position().x
	var mouse_viewport_offset: float = old_mouse_pos_x - scroll.scroll_horizontal

	zoom = clamp(zoom * factor, ZOOM_MIN, ZOOM_MAX)

	if old_zoom == zoom:
		return

	var zoom_ratio: float = zoom / old_zoom
	var new_mouse_pos_x: float = old_mouse_pos_x * zoom_ratio
	
	scroll.scroll_horizontal = int(new_mouse_pos_x - mouse_viewport_offset)

	zoom_changed.emit(zoom)
	accept_event()
	queue_redraw()


func get_frame_from_mouse() -> int:
	return floori(get_local_mouse_position().x / zoom)


func get_track_from_mouse() -> int:
	return floori(get_local_mouse_position().y / TRACK_TOTAL_SIZE)


func move_playhead(frame_nr: int) -> void:
	EditorCore.set_frame_nr(frame_nr)
	queue_redraw()

