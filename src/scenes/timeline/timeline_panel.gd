extends PanelContainer

enum POPUP_ACTION { 
	# Clip options
	CLIP_ONLY_VIDEO,
	CLIP_DELETE,
	CLIP_CUT,
	# Track options
	REMOVE_EMPTY_SPACE,
	TRACK_ADD,
	TRACK_REMOVE,
}
enum STATE {
	NORMAL,
	SCRUBBING,
	MOVING,
	DROPPING,
	RESIZING,
}


signal zoom_changed(new_zoom: float)


const TRACK_HEIGHT: int = 30
const TRACK_LINE_WIDTH: int = 1
const TRACK_LINE_COLOR: Color = Color.DIM_GRAY
const TRACK_TOTAL_SIZE: int = TRACK_HEIGHT + TRACK_LINE_WIDTH

const ZOOM_MIN: float = 0.1
const ZOOM_MAX: float = 20.0
const ZOOM_STEP: float = 1.1

const RESIZE_HANDLE_WIDTH: int = 5
const RESIZE_CLIP_MIN_WIDTH: float = 14

const PLAYHEAD_WIDTH: int = 2

const SNAPPING: int = 200

const STYLE_BOX_PREVIEW: StyleBox = preload("uid://dx2v44643hfvy")
const STYLE_BOXES: Dictionary[FileHandler.TYPE, Array] = {
    FileHandler.TYPE.IMAGE: [preload(Library.STYLE_BOX_CLIP_IMAGE_NORMAL), preload(Library.STYLE_BOX_CLIP_IMAGE_FOCUS)],
    FileHandler.TYPE.AUDIO: [preload(Library.STYLE_BOX_CLIP_AUDIO_NORMAL), preload(Library.STYLE_BOX_CLIP_AUDIO_FOCUS)],
    FileHandler.TYPE.VIDEO: [preload(Library.STYLE_BOX_CLIP_VIDEO_NORMAL), preload(Library.STYLE_BOX_CLIP_VIDEO_FOCUS)],
    FileHandler.TYPE.COLOR: [preload(Library.STYLE_BOX_CLIP_COLOR_NORMAL), preload(Library.STYLE_BOX_CLIP_COLOR_FOCUS)],
    FileHandler.TYPE.TEXT:  [preload(Library.STYLE_BOX_CLIP_TEXT_NORMAL), preload(Library.STYLE_BOX_CLIP_TEXT_FOCUS)],
}
const TEXT_OFFSET: Vector2 = Vector2(5, 20)


@onready var scroll: ScrollContainer = get_parent()


var zoom: float = 1.0
var selected_clip_ids: PackedInt64Array = []

var state: STATE = STATE.NORMAL

var draggable: Draggable = null

var right_click_pos: Vector2i = Vector2i.ZERO
var right_click_clip: ClipData = null

var resize_target: ResizeTarget = null
var pressed_clip: ClipData = null



func _ready() -> void:
	set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)

	Project.project_ready.connect(_project_ready)
	EditorCore.frame_changed.connect(queue_redraw)
	ClipHandler.clips_updated.connect(queue_redraw)

	MarkerHandler.marker_added.connect(queue_redraw.unbind(1))
	MarkerHandler.marker_updated.connect(queue_redraw.unbind(2))
	MarkerHandler.marker_removed.connect(queue_redraw.unbind(1))
	MarkerHandler.marker_moving.connect(queue_redraw)

	scroll.get_h_scroll_bar().value_changed.connect(queue_redraw.unbind(1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if state == STATE.MOVING or state == STATE.DROPPING:
			state = STATE.NORMAL
			draggable = null
			queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("delete_clips"):
		ClipHandler.delete_clips(selected_clip_ids)
	elif event.is_action_pressed("cut_clips_at_playhead", false, true):
		cut_clips_at(EditorCore.frame_nr)
	elif event.is_action_pressed("cut_clips_at_mouse", false, true):
		cut_clips_at(get_frame_from_mouse())
	elif event.is_action_pressed("remove_empty_space"):
		var track_id: int = get_track_from_mouse()
		var frame_nr: int = get_frame_from_mouse()

		if !TrackHandler.get_clip_at(track_id, frame_nr):
			remove_empty_space_at(track_id, frame_nr)
	elif event.is_action_pressed("ui_cancel"):
		_on_ui_cancel()


func _gui_input(event: InputEvent) -> void:
	if !Project.loaded:
		return

	if event is InputEventMouseButton:
		if event.is_action_pressed("timeline_zoom_in", false, true):
			zoom_at_mouse(ZOOM_STEP)
		elif event.is_action_pressed("timeline_zoom_out", false, true):
			zoom_at_mouse(1.0 / ZOOM_STEP)
		else:
			_on_gui_input_mouse_button(event)
			get_window().gui_release_focus()
		queue_redraw()
	elif event is InputEventMouseMotion:
		_on_gui_input_mouse_motion(event)


func _on_gui_input_mouse_button(event: InputEventMouseButton) -> void:
	if event.is_released():
		if state == STATE.RESIZING:
			_commit_current_resize()

		_on_ui_cancel()
	if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if clip is pressed or not.
		state = STATE.NORMAL
		pressed_clip = _get_clip_on_mouse()

		if pressed_clip == null:
			state = STATE.SCRUBBING
			move_playhead(get_frame_from_mouse())
			return

		resize_target = _get_resize_target()

		if resize_target:
			state = STATE.RESIZING
		else:
			if event.shift_pressed:
				selected_clip_ids.append(pressed_clip.id)
			else:
				selected_clip_ids = [pressed_clip.id]
	elif event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var popup: PopupMenu = PopupManager.create_popup_menu()
		right_click_clip = _get_clip_on_mouse()

		right_click_pos = Vector2i(get_track_from_mouse(), get_frame_from_mouse())

		if right_click_clip != null:
			if right_click_clip.id not in selected_clip_ids:
				selected_clip_ids = [right_click_clip.id]
				queue_redraw()

			# TODO: Set icons and shortcuts
			if ClipHandler.get_type(right_click_clip.id) in EditorCore.VISUAL_TYPES:
				popup.add_item("popup_item_clip_only_video", POPUP_ACTION.CLIP_ONLY_VIDEO)
			popup.add_item("popup_item_clip_delete", POPUP_ACTION.CLIP_DELETE)
			popup.add_item("popup_item_clip_cut", POPUP_ACTION.CLIP_CUT)
			popup.add_separator()
		else:
			popup.add_item("popup_item_track_remove_empty_space", POPUP_ACTION.REMOVE_EMPTY_SPACE)

		popup.add_item("popup_item_track_add", POPUP_ACTION.TRACK_ADD)
		popup.add_item("popup_item_track_remove", POPUP_ACTION.TRACK_REMOVE)

		popup.id_pressed.connect(_on_popup_menu_id_pressed)
		PopupManager.show_popup_menu(popup)


func _on_gui_input_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		scroll.scroll_horizontal = max(scroll.scroll_horizontal - event.relative.x, 0.0)
		queue_redraw()

	var clip_on_mouse: ClipData = _get_clip_on_mouse()

	if clip_on_mouse != null:
		var clip_name: String = FileHandler.get_file_name(clip_on_mouse.file_id)

		if tooltip_text != clip_name:
			tooltip_text = clip_name
	elif tooltip_text != "" or state != STATE.NORMAL:
		tooltip_text = ""

	if state == STATE.NORMAL and clip_on_mouse != null:
		if _get_resize_target() != null:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
		else:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif state == STATE.SCRUBBING and event.button_mask & MOUSE_BUTTON_LEFT:
		move_playhead(get_frame_from_mouse())
	elif state == STATE.RESIZING:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
		_handle_resize_motion()
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _on_ui_cancel() -> void:
	state = STATE.NORMAL
	draggable = null
	pressed_clip = null
	resize_target = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _draw() -> void:
	var visible_clip_ids: PackedInt64Array = []
	var visible_start: int = floori(scroll.scroll_horizontal / zoom)
	var visible_end: int = ceili(visible_start + (size.x / zoom))
	var visible_left: float = scroll.scroll_horizontal
	var visible_right: float = visible_left + scroll.size.x

	for track_id: int in TrackHandler.get_tracks_size():
		for clip: ClipData in TrackHandler.get_clips_in(track_id, visible_start, visible_end):
			visible_clip_ids.append(clip.id)

	# - Track lines
	for i: int in TrackHandler.tracks.size() - 1:
		var y: int  = TRACK_TOTAL_SIZE * (i + 1)

		draw_dashed_line(Vector2(visible_left, y), Vector2(visible_right, y), TRACK_LINE_COLOR, TRACK_LINE_WIDTH)

	# - Clip preview(s)
	if state in [STATE.MOVING, STATE.DROPPING] and draggable != null: # Moving + Dropping preview
		if draggable.files:
			var preview_position: Vector2 = Vector2(
					(draggable.frame_offset) * zoom,
					draggable.track_offset * TRACK_TOTAL_SIZE)
			var preview_size: Vector2 = Vector2(draggable.duration * zoom, TRACK_HEIGHT)

			draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
		else:
			for clip_id: int in draggable.ids:
				var clip_data: ClipData = ClipHandler.get_clip(clip_id)
				var new_start: int = clip_data.start_frame + draggable.frame_offset
				var new_track: int = clip_data.track_id + draggable.track_offset
				
				var preview_position: Vector2 = Vector2(
						new_start * zoom,
						new_track * TRACK_TOTAL_SIZE)
				var preview_size: Vector2 = Vector2(clip_data.duration * zoom, TRACK_HEIGHT)

				draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))

				if clip_id in visible_clip_ids:
					visible_clip_ids.remove_at(visible_clip_ids.find(clip_id))
	elif state == STATE.RESIZING: # Resizing preview
		var clip_data: ClipData = ClipHandler.get_clip(resize_target.clip_id)
		var draw_start: float = clip_data.start_frame
		var draw_length: int = clip_data.duration

		if resize_target.is_end:
			draw_length += resize_target.delta
		else:
			draw_start += resize_target.delta * zoom
			draw_length -= resize_target.delta

		var preview_position: Vector2 = Vector2(draw_start, clip_data.track_id * TRACK_TOTAL_SIZE)
		var preview_size: Vector2 = Vector2(draw_length * zoom, TRACK_HEIGHT)
		
		draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))

		if resize_target.clip_id in visible_clip_ids:
			visible_clip_ids.remove_at(visible_clip_ids.find(resize_target.clip_id))

	# - Clip blocks
	for clip_id: int in visible_clip_ids:
		var clip: ClipData = ClipHandler.get_clip(clip_id)
		var box_type: int = 1 if clip.id in selected_clip_ids else 0
		var box_pos: Vector2 = Vector2(clip.start_frame * zoom, TRACK_TOTAL_SIZE * clip.track_id)
		var new_clip: Rect2 = Rect2(box_pos, Vector2(clip.duration * zoom, TRACK_HEIGHT))
		var text_pos_x: float = box_pos.x
		var clip_end_x: float = box_pos.x + (clip.duration * zoom)

		if text_pos_x < scroll.scroll_horizontal and text_pos_x + TEXT_OFFSET.x <= clip_end_x:
			text_pos_x = scroll.scroll_horizontal

		draw_style_box(STYLE_BOXES[ClipHandler.get_type(clip.id)][box_type], new_clip)
		draw_string(
				get_theme_default_font(),
				Vector2(text_pos_x, box_pos.y) + TEXT_OFFSET,
				FileHandler.get_file_name(clip.file_id),
				HORIZONTAL_ALIGNMENT_LEFT, clip.duration * zoom - TEXT_OFFSET.x,
				11, # Font size
				Color(0.9, 0.9, 0.9))
		
	# TODO: - Audio waves

	# TODO: - Fading handles + amount

	# - Playhead
	var playhead_pos: float = EditorCore.frame_nr * zoom
	draw_line(
			Vector2(playhead_pos, 0),
			Vector2(playhead_pos, size.y),
			Color(0.4, 0.4, 0.4),
			PLAYHEAD_WIDTH)

	# - Marker lines
	for frame_nr: int in MarkerHandler.markers.keys():
		var marker_data: MarkerData = MarkerHandler.markers[frame_nr]
		var pos_x: float = frame_nr * zoom

		if frame_nr == MarkerHandler.dragged_marker:
			pos_x = MarkerHandler.dragged_marker_offset			

		draw_line(
				Vector2(pos_x, 0),
				Vector2(pos_x, size.y),
				Settings.get_marker_color(marker_data.type_id) * Color(1.0, 1.0, 1.0, 0.3),
				1.0)
		pos_x += 1
		draw_line(
				Vector2(pos_x, 0),
				Vector2(pos_x, size.y),
				Settings.get_marker_color(marker_data.type_id) * Color(1.0, 1.0, 1.0, 0.1),
				1.0)


func _get_clip_on_mouse() -> ClipData:
	var track_id: int = get_track_from_mouse()

	if track_id < 0 or track_id >= TrackHandler.get_tracks_size():
		return null

	return TrackHandler.get_clip_at(track_id, get_frame_from_mouse())


func _get_resize_target() -> ResizeTarget:
	var track_id: int = get_track_from_mouse()
	var frame_pos: float = get_local_mouse_position().x

	if track_id < 0 or track_id >= TrackHandler.get_tracks_size():
		return null

	var clip_on_mouse: ClipData = _get_clip_on_mouse()

	if clip_on_mouse == null:
		return null
	elif clip_on_mouse.duration * zoom > RESIZE_CLIP_MIN_WIDTH:
		return null # Too small

	var visible_start: int = floori(scroll.scroll_horizontal / zoom)
	var visible_end: int = ceili((scroll.scroll_horizontal + size.x) / zoom)
	var clips: Array[ClipData] = TrackHandler.get_clips_in(track_id, visible_start, visible_end)
	
	for clip_data: ClipData in clips:
		var start: float = clip_data.start_frame * zoom
		var end: float = (clip_data.start_frame + clip_data.duration) * zoom
		
		if abs(frame_pos - start) <= RESIZE_HANDLE_WIDTH:
			return ResizeTarget.new(clip_data.id, false, clip_data.start_frame, clip_data.duration)
		elif abs(frame_pos - end) <= RESIZE_HANDLE_WIDTH:
			return ResizeTarget.new(clip_data.id, true, clip_data.start_frame, clip_data.duration)
	
	return null


func _project_ready() -> void:
	custom_minimum_size.y = TRACK_TOTAL_SIZE * TrackHandler.tracks.size()
	queue_redraw()


func _get_drag_data(_p: Vector2) -> Variant:
	if state != STATE.NORMAL or pressed_clip == null:
		return null

	var clicked_clip: ClipData = pressed_clip
		
	if pressed_clip.id not in selected_clip_ids:
		selected_clip_ids = [pressed_clip.id]
		queue_redraw()

	var data: Draggable = Draggable.new()
	var clip_ids: PackedInt64Array = selected_clip_ids.duplicate()
	var anchor_index: int = clip_ids.find(clicked_clip.id)

	if anchor_index != -1:
		clip_ids.remove_at(anchor_index)
		clip_ids.insert(0, clicked_clip.id)

	data.ids = clip_ids
	data.mouse_offset = get_frame_from_mouse() - clicked_clip.start_frame
	
	state = STATE.MOVING

	return data


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is not Draggable:
		return false
	elif data.files:
		state = STATE.DROPPING

	draggable = data
	queue_redraw()

	return _can_drop_new_clips() if draggable.files else _can_move_clips()


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
	var anchor_clip: ClipData = ClipHandler.get_clip(draggable.ids[0])
	var mouse_track: int = get_track_from_mouse()
	var mouse_frame: int = get_frame_from_mouse()
	var target_start: int = mouse_frame - draggable.mouse_offset
	var track_difference: int = mouse_track - anchor_clip.track_id
	var frame_difference: int = target_start - anchor_clip.start_frame

	var min_allowed_diff: int = -1000000000 # Effectively -Infinity
	var max_allowed_diff: int = 1000000000  # Effectively +Infinity

	for id: int in draggable.ids:
		var clip: ClipData = ClipHandler.get_clip(id)
		var new_track: int = clip.track_id + track_difference
		var middle_frame: int = clip.start_frame + floori(clip.duration / 2.0)
		
		if new_track < 0 or new_track >= TrackHandler.get_tracks_size():
			return false # First boundary check

		var free_region: Vector2i = TrackHandler.get_free_region(new_track, middle_frame + frame_difference, draggable.ids)

		if free_region == Vector2i(-1, -1):
			return false

		# Calculating clip constrains
		min_allowed_diff = max(min_allowed_diff, free_region.x - clip.start_frame)
		max_allowed_diff = min(max_allowed_diff, free_region.y - clip.start_frame - clip.duration)

	if min_allowed_diff > max_allowed_diff:
		return false # No space for all clips

	if frame_difference < min_allowed_diff:
		# Overlapping to the left. Check if within snap distance.
		if min_allowed_diff - frame_difference <= SNAPPING:
			frame_difference = min_allowed_diff # Snap to valid start
		else:
			return false # Too far overlap
	elif frame_difference > max_allowed_diff:
		# Overlapping to the right. Check if within snap distance.
		if frame_difference - max_allowed_diff <= SNAPPING:
			frame_difference = max_allowed_diff # Snap to valid end
		else:
			return false # Too far overlap

	# If we got here, frame_difference is either originally valid or successfully snapped.
	draggable.track_offset = track_difference
	draggable.frame_offset = frame_difference
	return true


func _drop_data(_p: Vector2, data: Variant) -> void:
	if data is not Draggable: return

	if state not in [STATE.DROPPING, STATE.MOVING]:
		return

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
		var move_requests: Array[MoveClipRequest] = []
		
		for id: int in draggable.ids:
			var request: MoveClipRequest = MoveClipRequest.new(
					id, draggable.frame_offset, draggable.track_offset)
			move_requests.append(request)
			
		if not move_requests.is_empty():
			ClipHandler.move_clips(move_requests)

	draggable = null
	queue_redraw()


func _on_mouse_entered() -> void:
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_ui_cancel()
	queue_redraw()


func _on_mouse_exited() -> void:
	queue_redraw()


func _commit_current_resize() -> void:
	if resize_target.delta != 0:
		var request: ResizeClipRequest = ResizeClipRequest.new(
			resize_target.clip_id,
			resize_target.delta if resize_target.is_end else -resize_target.delta,
			resize_target.is_end)

		ClipHandler.resize_clips([request])

	resize_target = null
	queue_redraw()


func _handle_resize_motion() -> void:
	var track_id: int = ClipHandler.get_clip(resize_target.clip_id).track_id
	var current_frame: int = get_frame_from_mouse()
	
	if resize_target.is_end: # Resizing end
		var new_duration: int = current_frame - resize_target.original_start
		
		if new_duration < 1:
			new_duration = 1
		
		# Collision detection
		var free_region: Vector2i = TrackHandler.get_free_region(
			track_id, resize_target.original_start + 1, [resize_target.clip_id])

		if (resize_target.original_start + new_duration) > free_region.y:
			new_duration = free_region.y - resize_target.original_start
			
		resize_target.delta = new_duration - resize_target.original_duration
	else: # Resizing beginning
		var new_start: int = current_frame
		
		if new_start > (resize_target.original_start + resize_target.original_duration - 1):
			new_start = (resize_target.original_start + resize_target.original_duration - 1)
			
		# Collision detection
		var free_region: Vector2i = TrackHandler.get_free_region(
				track_id,
				resize_target.original_start + resize_target.original_duration - 1,
				[resize_target.clip_id])

		if new_start < free_region.x:
			new_start = free_region.x
			
		resize_target.delta = new_start - resize_target.original_start
	
	queue_redraw()


func _on_popup_menu_id_pressed(id: POPUP_ACTION) -> void:
	match id:
		# Clip options
		POPUP_ACTION.CLIP_ONLY_VIDEO: _on_popup_action_clip_only_video()
		POPUP_ACTION.CLIP_DELETE: _on_popup_action_clip_delete()
		POPUP_ACTION.CLIP_CUT: _on_popup_action_clip_cut()
		# Track options
		POPUP_ACTION.REMOVE_EMPTY_SPACE: _on_popup_action_remove_empty_space()
		POPUP_ACTION.TRACK_ADD: _on_popup_action_track_add()
		POPUP_ACTION.TRACK_REMOVE: _on_popup_action_track_remove()

	queue_redraw()


func _on_popup_action_clip_only_video() -> void:
	FileHandler.enable_clip_only_video(right_click_clip.file_id, right_click_clip.id)


func _on_popup_action_clip_delete() -> void:
	ClipHandler.delete_clips(selected_clip_ids)


func _on_popup_action_clip_cut() -> void:
	cut_clips_at(right_click_pos.y)


func _on_popup_action_remove_empty_space() -> void:
	remove_empty_space_at(right_click_pos.x, right_click_pos.y)


func _on_popup_action_track_add() -> void:
	TrackHandler.add_track(right_click_pos.x)


func _on_popup_action_track_remove() -> void:
	TrackHandler.remove_track(right_click_pos.x)


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


func get_frame_from_mouse() -> int:
	return floori(get_local_mouse_position().x / zoom)


func get_track_from_mouse() -> int:
	return floori(get_local_mouse_position().y / TRACK_TOTAL_SIZE)


func move_playhead(frame_nr: int) -> void:
	EditorCore.set_frame(max(0, frame_nr))
	queue_redraw()


func remove_empty_space_at(track_id: int, frame_nr: int) -> void:
	var clips: PackedInt64Array = TrackHandler.get_clip_ids_after(track_id, frame_nr)
	var region: Vector2i = TrackHandler.get_free_region(track_id, frame_nr)
	var empty_size: int = region.y - region.x
	var move_requests: Array[MoveClipRequest] = []

	for clip_id: int in clips:
		move_requests.append(MoveClipRequest.new(clip_id, -empty_size, 0))

	ClipHandler.move_clips(move_requests)


func cut_clips_at(frame_pos: int) -> void:
	# WARN: Make certain that cutting is possible (space available)

	# Check if any of the clips in the tracks is in selected clips
	# if there are selected clips present, we only cut the selected ones
	var requests: Array[CutClipRequest] = []

	# Checking if we only want selected clips to be cut.
	for clip_id: int in selected_clip_ids:
		var clip: ClipData = ClipHandler.get_clip(clip_id)

		if clip.start_frame < frame_pos and clip.end_frame > frame_pos:
			requests.append(CutClipRequest.new(clip.id, frame_pos - clip.start_frame))

	if requests.size() != 0:
		ClipHandler.cut_clips(requests)
		queue_redraw()
		return

	# No selected clips present so cutting all possible clips
	for track_id: int in TrackHandler.get_tracks_size():
		var clip: ClipData = TrackHandler.get_clip_at(track_id, frame_pos)

		if clip != null and clip.start_frame < frame_pos and clip.end_frame > frame_pos:
			requests.append(CutClipRequest.new(clip.id, frame_pos - clip.start_frame))

	ClipHandler.cut_clips(requests)
	queue_redraw()



class ResizeTarget:
	var clip_id: int
	var is_end: bool
	var original_start: int = 0
	var original_duration: int = 0
	var delta: int = 0


	func _init(_clip_id: int, _is_end: bool, start: int, duration: int) -> void:
		clip_id = _clip_id
		is_end = _is_end
		original_start = start
		original_duration = duration
