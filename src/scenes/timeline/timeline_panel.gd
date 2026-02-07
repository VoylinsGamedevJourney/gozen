extends PanelContainer
# TODO: Look into caching the waveform data (not an issue right now, but might become one)

signal zoom_changed(new_zoom: float)
signal draw_track_lines
signal draw_clips
signal draw_mode
signal draw_playhead
signal draw_selection_box
signal draw_markers
signal draw_all


enum POPUP_ACTION {
	# Clip options
	CLIP_VIDEO_ONLY,
	CLIP_DELETE,
	CLIP_CUT,
	CLIP_AUDIO_TAKE_OVER,
	CLIP_AUDIO_TAKE_OVER_ENABLE,
	CLIP_AUDIO_TAKE_OVER_DISABLE,
	# Track options
	REMOVE_EMPTY_SPACE,
	TRACK_ADD,
	TRACK_REMOVE,
}
enum STATE {
	CURSOR_MODE_SELECT,
	CURSOR_MODE_CUT,
	SCRUBBING,
	MOVING,
	DROPPING,
	RESIZING,
	FADING,
	BOX_SELECTING,
}

const TRACK_HEIGHT: int = 30
const TRACK_LINE_WIDTH: int = 1
const TRACK_LINE_COLOR: Color = Color.DIM_GRAY
const TRACK_TOTAL_SIZE: int = TRACK_HEIGHT + TRACK_LINE_WIDTH # TODO: Make this adjustable

const RESIZE_HANDLE_WIDTH: int = 5
const RESIZE_CLIP_MIN_WIDTH: float = 14

const FADE_HANDLE_SIZE: int = 6
const FADE_HANDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.7)
const FADE_LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)

const PLAYHEAD_WIDTH: int = 2
const PLAYHEAD_COLOR: Color = Color(0.4, 0.4, 0.4)

const ZOOM_MIN: float = 0.1
const ZOOM_MAX: float = 20.0
const ZOOM_STEP: float = 1.1

const SNAPPING: int = 200

const COLOR_AUDIO_WAVE: Color = Color(0.82, 0.82, 0.82, 0.8)


@onready var scroll: ScrollContainer = get_parent()


var zoom: float = 1.0
var selected_clip_ids: PackedInt64Array = []

var state: STATE = STATE.CURSOR_MODE_SELECT: set = set_state

var draggable: Draggable = null

var right_click_pos: Vector2i = Vector2i.ZERO
var right_click_clip: ClipData = null

var box_select_start: Vector2
var box_select_end: Vector2

var resize_target: ResizeTarget = null
var fade_target: FadeTarget = null
var pressed_clip: ClipData = null
var hovered_clip: ClipData = null



func _ready() -> void:
	set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)

	Project.project_ready.connect(_project_ready)

	InputManager.switch_timeline_mode_select.connect(set_state.bind(STATE.CURSOR_MODE_SELECT))
	InputManager.switch_timeline_mode_cut.connect(set_state.bind(STATE.CURSOR_MODE_CUT))

	scroll.get_h_scroll_bar().value_changed.connect(draw_all.emit.unbind(1))
	scroll.get_v_scroll_bar().value_changed.connect(draw_all.emit.unbind(1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if state == STATE.MOVING or state == STATE.DROPPING:
			state = STATE.CURSOR_MODE_SELECT
			draggable = null
			draw_clips.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("delete_clips"):
		ClipHandler.delete_clips(selected_clip_ids)
	elif event.is_action_pressed("ripple_delete_clips"):
		ClipHandler.ripple_delete_clips(selected_clip_ids)
	elif event.is_action_pressed("cut_clips_at_playhead", false, true):
		cut_clips_at(EditorCore.frame_nr)
	elif event.is_action_pressed("cut_clips_at_mouse", false, true):
		cut_clips_at(get_frame_from_mouse())
	elif event.is_action_pressed("remove_empty_space"):
		var track_id: int = get_track_from_mouse()
		var frame_nr: int = get_frame_from_mouse()

		if !TrackHandler.get_clip_at(track_id, frame_nr):
			remove_empty_space_at(track_id, frame_nr)
	elif event.is_action_pressed("duplicate_selected_clips"):
		duplicate_selected_clips()
	elif event.is_action_pressed("ui_cancel"):
		selected_clip_ids = []
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
	elif event is InputEventMouseMotion:
		_on_gui_input_mouse_motion(event)


func _on_gui_input_mouse_button(event: InputEventMouseButton) -> void:
	if state == STATE.CURSOR_MODE_CUT:
		var clip_data: ClipData = _get_clip_on_mouse()

		cut_clip_at(clip_data, get_frame_from_mouse())
		return
	elif event.is_released():
		match state:
			STATE.RESIZING: _commit_current_resize()
			STATE.BOX_SELECTING: _commit_box_selection(event.ctrl_pressed)

		_on_ui_cancel()

	if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if clip is pressed or not.
		state = STATE.CURSOR_MODE_SELECT
		pressed_clip = _get_clip_on_mouse()
		resize_target = _get_resize_target()
		fade_target = _get_fade_target()

		if fade_target:
			state = STATE.FADING
			draw_clips.emit()
		elif resize_target:
			state = STATE.RESIZING
			draw_clips.emit()
		elif pressed_clip == null:
			if event.shift_pressed:
				state = STATE.BOX_SELECTING
				box_select_start = get_local_mouse_position()
				box_select_end = box_select_start
				draw_selection_box.emit()
			else:
				state = STATE.SCRUBBING
				move_playhead(get_frame_from_mouse())
		else:
			var clip_id: int = pressed_clip.id

			if event.shift_pressed:
				selected_clip_ids.append(clip_id)
			else:
				selected_clip_ids = [clip_id]

			draw_clips.emit()
			ClipHandler.clip_selected.emit(clip_id)
	elif event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var popup: PopupMenu = PopupManager.create_popup_menu()
		right_click_clip = _get_clip_on_mouse()

		right_click_pos = Vector2i(get_track_from_mouse(), get_frame_from_mouse())

		if right_click_clip != null:
			_add_popup_menu_items_clip(popup)
		else:
			popup.add_item(tr("Remove empty space"), POPUP_ACTION.REMOVE_EMPTY_SPACE)

		popup.add_item(tr("Add track"), POPUP_ACTION.TRACK_ADD)
		popup.add_item(tr("Remove track"), POPUP_ACTION.TRACK_REMOVE)
		popup.id_pressed.connect(_on_popup_menu_id_pressed)
		PopupManager.show_popup_menu(popup)


func _on_gui_input_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		scroll.scroll_horizontal = max(scroll.scroll_horizontal - event.relative.x, 0.0)

	var clip_on_mouse: ClipData = _get_clip_on_mouse()

	if clip_on_mouse != null:
		var clip_name: String = FileHandler.get_file_name(clip_on_mouse.file_id)

		if tooltip_text != clip_name:
			tooltip_text = clip_name
		if hovered_clip != clip_on_mouse:
			hovered_clip = clip_on_mouse
	elif tooltip_text != "" or state != STATE.CURSOR_MODE_SELECT:
		tooltip_text = ""

	match state:
		STATE.CURSOR_MODE_SELECT:
			if _get_resize_target() != null:
				mouse_default_cursor_shape = Control. CURSOR_HSIZE
			elif _get_fade_target() != null:
				mouse_default_cursor_shape = Control.CURSOR_CROSS
			elif clip_on_mouse != null:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
		STATE.CURSOR_MODE_CUT:
			mouse_default_cursor_shape = Control.CURSOR_IBEAM # TODO: Create a better cursor shape
		STATE.SCRUBBING:
			if event.button_mask & MOUSE_BUTTON_LEFT:
				move_playhead(get_frame_from_mouse())
		STATE.BOX_SELECTING:
			box_select_end = get_local_mouse_position()
			mouse_default_cursor_shape = Control.CURSOR_CROSS
			draw_selection_box.emit()
		STATE.RESIZING:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
			_handle_resize_motion()
		STATE.FADING:
			_handle_fade_motion()


func _on_ui_cancel() -> void:
	state = STATE.CURSOR_MODE_SELECT
	draggable = null
	pressed_clip = null
	resize_target = null
	fade_target = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	draw_all.emit()


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
	elif clip_on_mouse.duration * zoom < RESIZE_CLIP_MIN_WIDTH:
		return null # Too small

	var visible_start: int = floori(scroll.scroll_horizontal / zoom)
	var visible_end: int = ceili((scroll.scroll_horizontal + size.x) / zoom)
	var clips: Array[ClipData] = TrackHandler.get_clips_in(track_id, visible_start, visible_end)

	for clip_data: ClipData in clips:
		var start: float = clip_data.start_frame * zoom
		var end: float = (clip_data.start_frame + clip_data.duration) * zoom

		if abs(frame_pos - start) <= RESIZE_HANDLE_WIDTH:
			return ResizeTarget.new(
					clip_data.id, false, clip_data.start_frame, clip_data.duration)
		elif abs(frame_pos - end) <= RESIZE_HANDLE_WIDTH:
			return ResizeTarget.new(
					clip_data.id, true, clip_data.start_frame, clip_data.duration)

	return null


func _get_fade_target() -> FadeTarget:
	var track_id: int = get_track_from_mouse()
	var mouse_pos: Vector2 = get_local_mouse_position()

	if track_id < 0 or track_id >= TrackHandler.get_tracks_size():
		return null

	# Check for clips in visible area
	var visible_start: int = floori(scroll.scroll_horizontal / zoom)
	var visible_end: int = ceili((scroll.scroll_horizontal + size.x) / zoom)

	for clip: ClipData in TrackHandler.get_clips_in(track_id, visible_start, visible_end):
		var is_video: bool = ClipHandler.get_type(clip.id) in EditorCore.VISUAL_TYPES
		var is_audio: bool = ClipHandler.get_type(clip.id) in EditorCore.AUDIO_TYPES

		var start_x: float = clip.start_frame * zoom
		var end_x: float = (clip.start_frame + clip.duration) * zoom
		var y_pos: float = clip.track_id * TRACK_TOTAL_SIZE

		# Hitbox tolerance
		var r: float = FADE_HANDLE_SIZE * 1.5

		# Check Video Handles (Bottom)
		if is_video:
			var video_y_pos: float = y_pos + TRACK_HEIGHT - FADE_HANDLE_SIZE
			var in_pos: Vector2 = Vector2(start_x + (clip.fade_in_visual * zoom), video_y_pos)
			var out_pos: Vector2 = Vector2(end_x - (clip.fade_out_visual * zoom), video_y_pos)

			if mouse_pos.distance_to(in_pos) < r: return FadeTarget.new(clip.id, false, true)
			if mouse_pos.distance_to(out_pos) < r: return FadeTarget.new(clip.id, true, true)

		# Check Audio Handles (Top)
		if is_audio:
			var audio_y_pos: float = y_pos + FADE_HANDLE_SIZE
			var in_pos: Vector2 = Vector2(start_x + (clip.fade_in_audio * zoom), audio_y_pos)
			var out_pos: Vector2 = Vector2(end_x - (clip.fade_out_audio * zoom), audio_y_pos)

			if mouse_pos.distance_to(in_pos) < r: return FadeTarget.new(clip.id, false, false)
			if mouse_pos.distance_to(out_pos) < r: return FadeTarget.new(clip.id, true, false)
	return null


func _project_ready() -> void:
	custom_minimum_size.y = TRACK_TOTAL_SIZE * TrackHandler.tracks.size()
	draw_all.emit()


func _get_drag_data(_p: Vector2) -> Variant:
	if state != STATE.CURSOR_MODE_SELECT or pressed_clip == null:
		return null

	var clicked_clip: ClipData = pressed_clip

	if pressed_clip.id not in selected_clip_ids:
		selected_clip_ids = [pressed_clip.id]
		draw_clips.emit()

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
	draw_clips.emit()

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

		if distance_necessary > SNAPPING or target_frame - free_region.x < distance_necessary:
			return false

		draggable.frame_offset = target_frame - distance_necessary

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
	draw_clips.emit()


func _on_mouse_entered() -> void:
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_ui_cancel()
	draw_all.emit()


func _on_mouse_exited() -> void:
	hovered_clip = null
	draw_all.emit()


func _commit_current_resize() -> void:
	if resize_target.delta != 0:
		var request: ResizeClipRequest = ResizeClipRequest.new(
			resize_target.clip_id,
			resize_target.delta if resize_target.is_end else -resize_target.delta,
			resize_target.is_end)

		ClipHandler.resize_clips([request])

	resize_target = null
	draw_clips.emit()


func _commit_box_selection(is_ctrl_pressed: bool) -> void:
	var track_start: int = clampi(floori(box_select_start.y / TRACK_TOTAL_SIZE), 0, TrackHandler.tracks.size())
	var track_end: int = clampi(floori(box_select_end.y / TRACK_TOTAL_SIZE), 0, TrackHandler.tracks.size())
	var frame_start: int = floori(box_select_start.x / zoom)
	var frame_end: int = floori(box_select_end.x / zoom)

	if not is_ctrl_pressed: selected_clip_ids.clear()

	if track_start > track_end:
		var temp: int = track_start
		track_start = track_end
		track_end = temp
	if frame_start > frame_end:
		var temp: int = frame_start
		frame_start = frame_end
		frame_end = temp

	for track_id: int in range(track_start, clamp(track_end + 1, 0, TrackHandler.tracks.size())):
		for frame_nr: int in TrackHandler.tracks[track_id].clips:
			if frame_nr > frame_end: break
			var clip_id: int = TrackHandler.tracks[track_id].clips[frame_nr]

			if frame_nr > frame_start and frame_nr < frame_end:
				if clip_id not in selected_clip_ids: selected_clip_ids.append(clip_id)
				continue

			# We should also check if a clip ends inside the selection box.
			if ClipHandler.get_end_frame(clip_id) > frame_start:
				if clip_id not in selected_clip_ids: selected_clip_ids.append(clip_id)

	if selected_clip_ids.size() > 0:
		ClipHandler.clip_selected.emit(selected_clip_ids[-1])
	else:
		ClipHandler.clip_selected.emit(-1)

	draw_selection_box.emit()
	draw_clips.emit()


func _handle_resize_motion() -> void:
	var clip_data: ClipData = ClipHandler.get_clip(resize_target.clip_id)
	var track_id: int = clip_data.track_id
	var file_duration: int = FileHandler.get_file(clip_data.file_id).duration
	var current_frame: int = get_frame_from_mouse()

	if resize_target.is_end: # Resizing end
		var new_duration: int = current_frame - resize_target.original_start
		var max_allowed_duration: int = file_duration - clip_data.begin

		if new_duration < 1:
			new_duration = 1
		if new_duration > max_allowed_duration:
			new_duration = max_allowed_duration

		# Collision detection
		var free_region: Vector2i = TrackHandler.get_free_region(
			track_id, resize_target.original_start + 1, [resize_target.clip_id])

		if (resize_target.original_start + new_duration) > free_region.y:
			new_duration = free_region.y - resize_target.original_start

		resize_target.delta = new_duration - resize_target.original_duration
	else: # Resizing beginning
		var new_start: int = current_frame
		var min_allowed_duration: int = resize_target.original_start - clip_data.begin

		if new_start > (resize_target.original_start + resize_target.original_duration - 1):
			new_start = (resize_target.original_start + resize_target.original_duration - 1)
		if new_start < min_allowed_duration:
			new_start = min_allowed_duration

		# Collision detection
		var free_region: Vector2i = TrackHandler.get_free_region(
				track_id,
				resize_target.original_start + resize_target.original_duration - 1,
				[resize_target.clip_id])

		if new_start < free_region.x:
			new_start = free_region.x
		resize_target.delta = new_start - resize_target.original_start
	draw_clips.emit()


func _handle_fade_motion() -> void:
	var clip: ClipData = ClipHandler.get_clip(fade_target.clip_id)
	var mouse_x: float = get_local_mouse_position().x
	var start_x: float = clip.start_frame * zoom
	var end_x: float = (clip.start_frame + clip.duration) * zoom

	# Convert pixel drag to frame amount
	var drag_frames: int = 0

	if not fade_target.is_end: # Fade In
		drag_frames = floori((mouse_x - start_x) / zoom)
		drag_frames = clamp(drag_frames, 0, clip.duration / 2.0)

		if fade_target.is_visual: clip.fade_in_visual = drag_frames
		else: clip.fade_in_audio = drag_frames
	else: # Fade Out
		drag_frames = floori((end_x - mouse_x) / zoom)
		drag_frames = clamp(drag_frames, 0, clip.duration / 2.0)

		if fade_target.is_visual: clip.fade_out_visual = drag_frames
		else: clip.fade_out_audio = drag_frames

	draw_clips.emit()
	EditorCore.update_frame()


func _add_popup_menu_items_clip(popup: PopupMenu) -> void:
	var clip_data: ClipData = ClipHandler.get_clip(right_click_clip.id)
	var clip_id: int = clip_data.id
	var clip_type: FileHandler.TYPE = ClipHandler.get_type(clip_id)

	if clip_id not in selected_clip_ids:
		selected_clip_ids = [clip_id]
		ClipHandler.clip_selected.emit(clip_id)

	# TODO: Set icons and shortcuts
	popup.add_item(tr("Delete clip"), POPUP_ACTION.CLIP_DELETE)
	popup.add_item(tr("Cut clip"), POPUP_ACTION.CLIP_CUT)

	if clip_type in FileHandler.TYPE_VIDEOS:
		popup.add_separator(tr("Video options"))
		popup.add_item(tr("Add clip only video isntance"), POPUP_ACTION.CLIP_VIDEO_ONLY)

	if clip_type == FileHandler.TYPE.VIDEO:
		popup.add_item(tr("Clip audio-take-over"), POPUP_ACTION.CLIP_AUDIO_TAKE_OVER)

	if clip_data.ato_file_id != -1: # Can only be not -1 if clip is video
		if clip_data.ato_active:
			popup.add_item(
					tr("Disable clip audio-take-over"),
					POPUP_ACTION.CLIP_AUDIO_TAKE_OVER_DISABLE)
		else:
			popup.add_item(
					tr("Enable clip audio-take-over"),
					POPUP_ACTION.CLIP_AUDIO_TAKE_OVER_ENABLE)

	popup.add_separator(tr("Track options")) # TODO:


func _on_popup_menu_id_pressed(id: POPUP_ACTION) -> void:
	match id:
		# Clip options
		POPUP_ACTION.CLIP_DELETE: _on_popup_action_clip_delete()
		POPUP_ACTION.CLIP_CUT: _on_popup_action_clip_cut()
		# Video options
		POPUP_ACTION.CLIP_VIDEO_ONLY: _on_popup_action_clip_only_video()
		POPUP_ACTION.CLIP_AUDIO_TAKE_OVER: _on_popup_action_clip_ato()
		POPUP_ACTION.CLIP_AUDIO_TAKE_OVER_ENABLE: _on_popup_action_clip_ato_enable()
		POPUP_ACTION.CLIP_AUDIO_TAKE_OVER_DISABLE: _on_popup_action_clip_ato_disable()
		# Track options
		POPUP_ACTION.REMOVE_EMPTY_SPACE: _on_popup_action_remove_empty_space()
		POPUP_ACTION.TRACK_ADD: _on_popup_action_track_add()
		POPUP_ACTION.TRACK_REMOVE: _on_popup_action_track_remove()
	draw_all.emit()


func _on_popup_action_clip_delete() -> void:
	ClipHandler.delete_clips(selected_clip_ids)


func _on_popup_action_clip_cut() -> void:
	cut_clips_at(right_click_pos.y)


func _on_popup_action_remove_empty_space() -> void:
	remove_empty_space_at(right_click_pos.x, right_click_pos.y)


func _on_popup_action_clip_ato() -> void:
	var popup: Control = PopupManager.get_popup(PopupManager.POPUP.AUDIO_TAKE_OVER)
	popup.load_data(right_click_clip.id, false)


func _on_popup_action_clip_ato_enable() -> void:
	InputManager.undo_redo.create_action("Enable clip audio take over")
	InputManager.undo_redo.add_do_method(
			ClipHandler.set_ato_active.bind(right_click_clip.id, true))
	InputManager.undo_redo.add_undo_method(
			ClipHandler.set_ato_active.bind(right_click_clip.id, false))
	InputManager.undo_redo.commit_action()


func _on_popup_action_clip_ato_disable() -> void:
	InputManager.undo_redo.create_action("Disable clip audio take over")
	InputManager.undo_redo.add_do_method(
			ClipHandler.set_ato_active.bind(right_click_clip.id, false))
	InputManager.undo_redo.add_undo_method(
			ClipHandler.set_ato_active.bind(right_click_clip.id, true))
	InputManager.undo_redo.commit_action()


func _on_popup_action_clip_only_video() -> void:
	FileHandler.enable_clip_only_video(right_click_clip.file_id, right_click_clip.id)


func _on_popup_action_track_add() -> void:
	TrackHandler.add_track(right_click_pos.x)


func _on_popup_action_track_remove() -> void:
	TrackHandler.remove_track(right_click_pos.x)


func zoom_at_mouse(factor: float) -> void:
	var old_zoom: float = zoom
	var old_mouse_pos_x: float = get_local_mouse_position().x
	var mouse_viewport_offset: float = old_mouse_pos_x - scroll.scroll_horizontal

	zoom = clamp(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if old_zoom == zoom: return

	var zoom_ratio: float = zoom / old_zoom
	var new_mouse_pos_x: float = old_mouse_pos_x * zoom_ratio

	scroll.scroll_horizontal = int(new_mouse_pos_x - mouse_viewport_offset)
	zoom_changed.emit(zoom)
	draw_all.emit()
	accept_event()


func get_frame_from_mouse() -> int:
	return floori(get_local_mouse_position().x / zoom)


func get_track_from_mouse() -> int:
	return clampi(floori(get_local_mouse_position().y / TRACK_TOTAL_SIZE), 0, TrackHandler.tracks.size())


func move_playhead(frame_nr: int) -> void:
	EditorCore.set_frame(max(0, frame_nr))
	draw_playhead.emit()


func remove_empty_space_at(track_id: int, frame_nr: int) -> void:
	var clips: PackedInt64Array = TrackHandler.get_clip_ids_after(track_id, frame_nr)
	var region: Vector2i = TrackHandler.get_free_region(track_id, frame_nr)
	var empty_size: int = region.y - region.x
	var move_requests: Array[MoveClipRequest] = []

	for clip_id: int in clips:
		move_requests.append(MoveClipRequest.new(clip_id, -empty_size, 0))
	ClipHandler.move_clips(move_requests)


func cut_clip_at(clip_data: ClipData, frame_pos: int) -> void:
	if clip_data.start_frame <= frame_pos and clip_data.end_frame >= frame_pos:
		ClipHandler.cut_clips([CutClipRequest.new(clip_data.id, frame_pos - clip_data.start_frame)])
	draw_clips.emit()


# WARN: Make certain that cutting is possible (space available)
func cut_clips_at(frame_pos: int) -> void:

	# Check if any of the clips in the tracks is in selected clips
	# if there are selected clips present, we only cut the selected ones
	var requests: Array[CutClipRequest] = []

	# Checking if we only want selected clips to be cut.
	for clip_id: int in selected_clip_ids:
		var clip_data: ClipData = ClipHandler.get_clip(clip_id)

		if clip_data.start_frame < frame_pos and clip_data.end_frame > frame_pos:
			requests.append(CutClipRequest.new(clip_data.id, frame_pos - clip_data.start_frame))

	if requests.size() != 0:
		ClipHandler.cut_clips(requests)
		draw_clips.emit()
		return

	# No selected clips present so cutting all possible clips
	for track_id: int in TrackHandler.get_tracks_size():
		var clip_data: ClipData = TrackHandler.get_clip_at(track_id, frame_pos)

		if clip_data != null and clip_data.start_frame < frame_pos and clip_data.end_frame > frame_pos:
			requests.append(CutClipRequest.new(clip_data.id, frame_pos - clip_data.start_frame))

	ClipHandler.cut_clips(requests)
	draw_clips.emit()


func duplicate_selected_clips() -> void:
	if selected_clip_ids.is_empty():
		return

	var requests: Array[CreateClipRequest] = []
	for clip_id: int in selected_clip_ids:
		var clip_data: ClipData = ClipHandler.get_clip(clip_id)

		if not clip_data:
			return # Invalid clip id

		var target_frame: int = clip_data.start_frame + clip_data.duration
		var free_region: Vector2i = TrackHandler.get_free_region(clip_data.track_id, target_frame)

		if free_region.y - target_frame >= clip_data.duration:
			requests.append(CreateClipRequest.new(clip_data.file_id, clip_data.track_id, target_frame))

	if not requests.is_empty():
		ClipHandler.add_clips(requests)


func set_state(new_state: STATE) -> void:
	state = new_state



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


class FadeTarget:
	var clip_id: int
	var is_end: bool
	var is_visual: bool


	func _init(_clip_id: int, _is_end: bool, _is_visual: bool) -> void:
		clip_id = _clip_id
		is_end = _is_end
		is_visual = _is_visual
