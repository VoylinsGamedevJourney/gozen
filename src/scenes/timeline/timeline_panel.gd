extends PanelContainer


enum POPUP_ACTION {
	CLIP_DELETE, CLIP_SPLIT, CLIP_AUDIO_TAKE_OVER, # Clip options
	# Track options
	REMOVE_EMPTY_SPACE, TRACK_ADD, TRACK_REMOVE, TRACK_TOGGLE_VISIBLE,
	TRACK_TOGGLE_MUTE, TRACK_TOGGLE_LOCK }


const TRACK_HEIGHT_LIMIT: Vector2i = Vector2i(34, 100)

const RESIZE_HANDLE_WIDTH: int = 5
const RESIZE_CLIP_MIN_WIDTH: float = 14

const ZOOM_MIN: float = 0.01
const ZOOM_MAX: float = 200.0
const ZOOM_STEP: float = 1.1

const SAFE_ZONE: int = 200


@export var mode_panel: PanelContainer
@export var button_select: TextureButton
@export var button_split: TextureButton
@export var button_snap: TextureButton


@onready var scroll: ScrollContainer = get_parent()

@onready var draw_track_lines: Control = $TrackLinesDraw
@onready var draw_clips: Control = $ClipsDraw
@onready var draw_preview: Control = $PreviewDraw
@onready var draw_mode: Control = $ModeDraw
@onready var draw_playhead: Control = $PlayheadDraw
@onready var draw_box_selection: Control = $BoxSelectionDraw
@onready var draw_markers: Control = $MarkersDrawn


var right_click_track: int
var right_click_frame: int
var right_click_clip: ClipData = null

var pressed_clip: ClipData = null

var _update_clips: bool = true



func _ready() -> void:
	Project.project_ready.connect(_project_ready)
	Timeline.state_changed.connect(_on_state_changed)
	Timeline.scroll_changed.connect(draw_all.unbind(1))
	Settings.on_show_time_mode_bar_changed.connect(_show_hide_mode_bar)
	Settings.on_track_height_changed.connect(_update_track_height)
	EditorCore.visual_frame_changed.connect(draw_playhead.queue_redraw)

	var markers_redraw: Callable = draw_markers.queue_redraw
	MarkerLogic.added.connect(markers_redraw.unbind(1))
	MarkerLogic.removed.connect(markers_redraw.unbind(1))
	MarkerLogic.updated.connect(markers_redraw.unbind(1))
	MarkerLogic.moving.connect(markers_redraw)

	button_snap.toggled.connect(func(toggled: bool) -> void:
			Timeline.snap_enabled = toggled)

	visibility_changed.connect(func() -> void: if is_visible_in_tree():
			await get_tree().process_frame
			draw_all())

	set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	_show_hide_mode_bar()


# --- Notification handling ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and Timeline.state in [Timeline.STATE.MOVING, Timeline.STATE.DROPPING]:
		Timeline.state = Timeline.STATE.SELECT
		Timeline.draggable = null
		draw_clips.queue_redraw()
		draw_preview.queue_redraw()


# --- Input handling ---

func _unhandled_input(event: InputEvent) -> void:
	var focus_owner: Control = get_window().gui_get_focus_owner()
	if !is_visible_in_tree() and !Project.is_loaded or focus_owner is LineEdit or focus_owner is TextEdit:
		return

	if event.is_action_pressed("split_clips_at_playhead", false, true):
		split_clips_at(EditorCore.frame_nr)
	elif event.is_action_pressed("ui_cancel"):
		if !PopupManager._open_popups.is_empty() or Timeline.state in [Timeline.STATE.MOVING, Timeline.STATE.DROPPING]:
			return
		ClipLogic.selected_clips.clear()
		_on_ui_cancel()

	if scroll.get_global_rect().has_point(get_global_mouse_position()):
		if event.is_action_pressed("ui_copy"):
			ClipLogic.copy_selected_clips()
			accept_event()
		elif event.is_action_pressed("ui_cut"):
			ClipLogic.cut_selected_clips()
			accept_event()
		elif event.is_action_pressed("ripple_delete_clips"):
			ClipLogic.ripple_delete(ClipLogic.selected_clips)
		elif event.is_action_pressed("delete_clips"):
			ClipLogic.delete(ClipLogic.selected_clips)
		elif event.is_action_pressed("duplicate_selected_clips"):
			var failed_dupes: int = ClipLogic.duplicate_clips(ClipLogic.selected_clips)
			if failed_dupes > 0:
				var dialog: AcceptDialog = PopupManager.create_accept_dialog(tr("Duplication failed"))
				dialog.dialog_text = tr("Could not duplicate %d clip(s) because there was not enough empty space.") % failed_dupes
				add_child(dialog)
				dialog.popup_centered()
			draw_clips.queue_redraw()
		elif event.is_action_pressed("split_clips_at_mouse", false, true):
			split_clips_at(get_frame_from_mouse())
		elif event.is_action_pressed("trim_to_clip_start", false, true):
			trim_clips_at(EditorCore.frame_nr, false)
		elif event.is_action_pressed("trim_to_clip_end", false, true):
			trim_clips_at(EditorCore.frame_nr, true)
		elif event.is_action_pressed("remove_empty_space"):
			var track: int = get_track_from_mouse()
			var frame_nr: int = get_frame_from_mouse()
			if !TrackLogic.get_clip_at_overlap(track, frame_nr):
				remove_empty_space_at(track, frame_nr)


func _gui_input(event: InputEvent) -> void:
	if !Project.is_loaded:
		return
	elif event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event
		if mouse_button_event.ctrl_pressed and mouse_button_event.shift_pressed and mouse_button_event.pressed:
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				Settings.set_track_height(clampf(
						Settings.get_track_height() + 2.0, TRACK_HEIGHT_LIMIT.x, TRACK_HEIGHT_LIMIT.y))
				accept_event()
				return
			elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				Settings.set_track_height(clampf(
						Settings.get_track_height() - 2.0, TRACK_HEIGHT_LIMIT.x, TRACK_HEIGHT_LIMIT.y))
				accept_event()
				return

		if event.is_action_pressed("timeline_zoom_in", false, true):
			zoom_at_mouse(ZOOM_STEP)
		elif event.is_action_pressed("timeline_zoom_out", false, true):
			zoom_at_mouse(1.0 / ZOOM_STEP)
		else:
			_on_gui_input_mouse_button(event as InputEventMouseButton)
			get_window().gui_release_focus()
	elif event is InputEventMouseMotion:
		_on_gui_input_mouse_motion(event as InputEventMouseMotion)
	_unhandled_input(event)


func _on_gui_input_mouse_button(event: InputEventMouseButton) -> void:
	if Timeline.state == Timeline.STATE.SPLIT:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			var target: ClipData = _get_clip_on_mouse()
			if target:
				split_clip_at(target, get_frame_from_mouse())
		return
	elif event.is_released():
		match Timeline.state:
			Timeline.STATE.RESIZING: _commit_current_resize()
			Timeline.STATE.SPEEDING: _commit_current_resize()
			Timeline.STATE.BOX_SELECTING: _commit_box_selection(event.ctrl_pressed)
			Timeline.STATE.SCRUBBING: EditorCore.finish_scrub()
		_on_ui_cancel()

	if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		Timeline.state = Timeline.STATE.SELECT
		pressed_clip = _get_clip_on_mouse()
		Timeline.resize_target = _get_resize_target()
		Timeline.fade_target = _get_fade_target()

		if event.double_click and !pressed_clip:
			var mod: int = Settings.get_delete_empty_modifier()
			if mod == KEY_NONE or (mod == KEY_CTRL and event.ctrl_pressed) or (mod == KEY_SHIFT and event.shift_pressed):
				remove_empty_space_at(get_track_from_mouse(), get_frame_from_mouse())
				return

		if Timeline.fade_target:
			Timeline.state = Timeline.STATE.FADING
			draw_clips.queue_redraw()
		elif Timeline.resize_target:
			Timeline.state = Timeline.STATE.SPEEDING if event.ctrl_pressed else Timeline.STATE.RESIZING
			draw_clips.queue_redraw()
		elif !pressed_clip:
			if event.shift_pressed:
				Timeline.state = Timeline.STATE.BOX_SELECTING
				Timeline.box_select_start = get_local_mouse_position()
				Timeline.box_select_end = Timeline.box_select_start
				draw_box_selection.queue_redraw()
			else:
				Timeline.state = Timeline.STATE.SCRUBBING
				if EditorCore.is_playing:
					EditorCore.is_playing = false
				EditorCore.scrub_to_frame(get_frame_from_mouse())
		else:
			if !event.shift_pressed:
				ClipLogic.selected_clips = [pressed_clip]
			elif !ClipLogic.selected_clips.has(pressed_clip):
				ClipLogic.selected_clips.append(pressed_clip)
			draw_clips.queue_redraw()
			ClipLogic.selected.emit(pressed_clip)
	elif event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var popup: PopupMenu = PopupManager.create_menu()
		right_click_clip = _get_clip_on_mouse()
		right_click_track = get_track_from_mouse()
		right_click_frame = get_frame_from_mouse()

		if right_click_clip:
			_add_popup_menu_items_clip(popup)
		else:
			popup.add_item(tr("Remove empty space"), POPUP_ACTION.REMOVE_EMPTY_SPACE)

		popup.add_separator(tr("Track options"))
		var track_data: TrackData = TrackLogic.tracks[right_click_track]

		popup.add_icon_item(preload(Library.ICON_ADD), tr("Add track"), POPUP_ACTION.TRACK_ADD)
		if TrackLogic.tracks.size() != 1:
			popup.add_icon_item(preload(Library.ICON_DELETE), tr("Remove track"), POPUP_ACTION.TRACK_REMOVE)

		popup.add_separator()

		popup.add_check_item(tr("Visible"), POPUP_ACTION.TRACK_TOGGLE_VISIBLE)
		popup.set_item_checked(popup.get_item_index(POPUP_ACTION.TRACK_TOGGLE_VISIBLE), track_data.is_visible)

		popup.add_check_item(tr("Muted"), POPUP_ACTION.TRACK_TOGGLE_MUTE)
		popup.set_item_checked(popup.get_item_index(POPUP_ACTION.TRACK_TOGGLE_MUTE), track_data.is_muted)

		popup.add_check_item(tr("Locked"), POPUP_ACTION.TRACK_TOGGLE_LOCK)
		popup.set_item_checked(popup.get_item_index(POPUP_ACTION.TRACK_TOGGLE_LOCK), track_data.is_locked)

		popup.id_pressed.connect(_on_popup_menu_id_pressed)
		PopupManager.show_menu(popup)



func _on_gui_input_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		scroll.scroll_horizontal = max(scroll.scroll_horizontal - event.relative.x, 0.0)

	var clip_on_mouse: ClipData = _get_clip_on_mouse()
	if clip_on_mouse:
		var nickname: String = FileLogic.files[clip_on_mouse.file].nickname
		if tooltip_text != nickname:
			tooltip_text = nickname
		if Timeline.hovered_clip != clip_on_mouse:
			Timeline.hovered_clip = clip_on_mouse
			draw_clips.queue_redraw()
	elif tooltip_text != "" or Timeline.state != Timeline.STATE.SELECT:
		tooltip_text = ""

	match Timeline.state:
		Timeline.STATE.SELECT:
			if _get_fade_target() != null:
				mouse_default_cursor_shape = Control.CURSOR_CROSS
			elif _get_resize_target() != null:
				mouse_default_cursor_shape = Control. CURSOR_HSIZE
			elif clip_on_mouse:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
		Timeline.STATE.SPLIT:
			mouse_default_cursor_shape = Control.CURSOR_IBEAM
			draw_mode.queue_redraw()
		Timeline.STATE.FADING:
			_handle_fade_motion()
		Timeline.STATE.SCRUBBING:
			if event.button_mask & MOUSE_BUTTON_LEFT:
				EditorCore.scrub_to_frame(get_frame_from_mouse())
		Timeline.STATE.BOX_SELECTING:
			Timeline.box_select_end = get_local_mouse_position()
			mouse_default_cursor_shape = Control.CURSOR_CROSS
			draw_box_selection.queue_redraw()
		Timeline.STATE.RESIZING, Timeline.STATE.SPEEDING:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
			_handle_resize_motion()
			draw_preview.queue_redraw()


func _on_ui_cancel() -> void:
	pressed_clip = null
	Timeline.hovered_clip = null
	Timeline.state = Timeline.STATE.SELECT
	Timeline.draggable = null
	Timeline.fade_target = null
	Timeline.resize_target = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	draw_all()


## Returns the clip.
func _get_clip_on_mouse() -> ClipData:
	return TrackLogic.get_clip_at_overlap(get_track_from_mouse(), get_frame_from_mouse())


func _get_resize_target() -> Timeline.ResizeTarget:
	var track: int = get_track_from_mouse()
	if TrackLogic.tracks[track].is_locked or not Timeline.hovered_clip:
		return null

	var zoom: float = Timeline.zoom
	var mouse_pos: float = get_local_mouse_position().x

	var handle_width: float = RESIZE_HANDLE_WIDTH
	if Input.is_key_pressed(KEY_SHIFT):
		handle_width *= 2.0

	var clip: ClipData = Timeline.hovered_clip
	if (clip.duration * zoom) < 20.0:
		return null

	var start_x: float = clip.start * zoom
	var end_x: float = clip.end * zoom
	var start_distance: float = abs(mouse_pos - start_x)
	var end_distance: float = abs(mouse_pos - end_x)

	if start_distance <= handle_width and (start_distance < end_distance or mouse_pos >= start_x):
		return Timeline.ResizeTarget.new(clip, false, clip.start, clip.duration)
	if end_distance <= handle_width and (end_distance <= start_distance or mouse_pos <= end_x):
		return Timeline.ResizeTarget.new(clip, true, clip.start, clip.duration)

	return null


func _get_fade_target() -> Timeline.FadeTarget:
	var track: int = get_track_from_mouse()
	if TrackLogic.tracks[track].is_locked or not Timeline.hovered_clip:
		return null

	var zoom: float = Timeline.zoom
	var mouse_pos: Vector2 = get_local_mouse_position()

	var current_handle_size: float = 3.5 # FADE_HANDLE_SIZE
	if Input.is_key_pressed(KEY_SHIFT):
		current_handle_size *= 2.0

	var clip: ClipData = Timeline.hovered_clip
	if (clip.duration * zoom) < 20.0:
		return null

	var start_x: float = clip.start * zoom
	var end_x: float = clip.end * zoom
	var y_pos: float = clip.track * Timeline.track_total_size

	if clip.type in EditorCore.VISUAL_TYPES:
		var corner_y: float = y_pos + Timeline.track_height
		var in_x: float = start_x + clip.effects.fade_visual.x * zoom
		var out_x: float = end_x - clip.effects.fade_visual.y * zoom - current_handle_size * 2

		var in_rect: Rect2 = Rect2(in_x, corner_y - current_handle_size * 2, current_handle_size * 2, current_handle_size * 2)
		var out_rect: Rect2 = Rect2(out_x, corner_y - current_handle_size * 2, current_handle_size * 2, current_handle_size * 2)

		if in_rect.grow(current_handle_size).has_point(mouse_pos):
			return Timeline.FadeTarget.new(clip, false, true)
		if out_rect.grow(current_handle_size).has_point(mouse_pos):
			return Timeline.FadeTarget.new(clip, true, true)

	if clip.type in EditorCore.AUDIO_TYPES:
		var corner_y: float = y_pos
		var in_x: float = start_x + clip.effects.fade_audio.x * zoom
		var out_x: float = end_x - clip.effects.fade_audio.y * zoom - current_handle_size * 2

		var in_rect: Rect2 = Rect2(in_x, corner_y, current_handle_size * 2, current_handle_size * 2)
		var out_rect: Rect2 = Rect2(out_x, corner_y, current_handle_size * 2, current_handle_size * 2)

		if in_rect.grow(current_handle_size).has_point(mouse_pos):
			return Timeline.FadeTarget.new(clip, false, false)
		if out_rect.grow(current_handle_size).has_point(mouse_pos):
			return Timeline.FadeTarget.new(clip, true, false)
	return null


func _project_ready() -> void:
	ClipLogic.added.connect(draw_clips.queue_redraw.unbind(1))
	ClipLogic.deleted.connect(_on_clip_deleted)
	ClipLogic.updated.connect(draw_clips.queue_redraw)
	TrackLogic.updated.connect(_on_tracks_updated)
	_update_track_height(Settings.get_track_height())
	draw_all()


func _get_drag_data(_p: Vector2) -> Variant:
	if Timeline.state != Timeline.STATE.SELECT or !pressed_clip or TrackLogic.tracks[pressed_clip.track].is_locked:
		return null
	if pressed_clip not in ClipLogic.selected_clips:
		ClipLogic.selected_clips = [pressed_clip]
		draw_clips.queue_redraw()

	var data: Draggable = Draggable.new()
	var clips: Array[ClipData] = ClipLogic.selected_clips.duplicate()
	var anchor_index: int = clips.find(pressed_clip)
	if anchor_index != -1:
		clips.remove_at(anchor_index)
		clips.insert(0, pressed_clip)
	for clip: ClipData in clips:
		data.ids.append(clip.id)
	data.mouse_offset = get_frame_from_mouse() - pressed_clip.start
	Timeline.state = Timeline.STATE.MOVING
	return data


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is EffectsPanel.DragData:
		var drag_data: EffectsPanel.DragData = data
		var clip_on_mouse: ClipData = _get_clip_on_mouse()
		if not clip_on_mouse:
			return false
		if drag_data.is_visual and clip_on_mouse.type not in EditorCore.VISUAL_TYPES:
			return false
		if not drag_data.is_visual and clip_on_mouse.type not in EditorCore.AUDIO_TYPES:
			return false
		return true

	if data is not Draggable:
		draw_preview.queue_redraw()
		return false

	var result: bool
	Timeline.draggable = data
	if Timeline.draggable.is_file:
		Timeline.state = Timeline.STATE.DROPPING
		result = Timeline.can_drop_new_clips(get_track_from_mouse(), get_frame_from_mouse(), SAFE_ZONE)
	else:
		Timeline.state = Timeline.STATE.MOVING
		result = Timeline.can_move_clips(get_track_from_mouse(), get_frame_from_mouse(), SAFE_ZONE)
		draw_clips.queue_redraw()

	if _update_clips:
		draw_clips.queue_redraw()
		_update_clips = false
	elif !result:
		draw_clips.queue_redraw()
		_update_clips = true
	Timeline.drop_valid = result
	draw_preview.queue_redraw()
	return result


func _drop_data(_p: Vector2, data: Variant) -> void:
	if data is EffectsPanel.DragData:
		var drag_data: EffectsPanel.DragData = data
		var clip: ClipData = _get_clip_on_mouse()
		if clip:
			var new_effect: Effect = drag_data.effect.deep_copy()
			new_effect.keyframes = drag_data.effect.keyframes.duplicate(true)
			EffectsHandler.add_effect([clip], new_effect, drag_data.is_visual)
		return
	elif data is not Draggable or Timeline.state not in [Timeline.STATE.DROPPING, Timeline.STATE.MOVING]:
		return
	elif Timeline.draggable.is_file: # Creating new clips (ids are file ids!)
		var requests: Array[ClipRequest] = []
		var total_duration: int = 0
		for file_id: int in Timeline.draggable.ids:
			var file: FileData = FileLogic.files[file_id]
			var target_frame: int = Timeline.draggable.frame_offset + total_duration
			requests.append(ClipRequest.add_request(file, Timeline.draggable.track_offset, target_frame))
			total_duration += file.duration
		ClipLogic.add(requests)
	else: # Moving clips
		var move_requests: Array[ClipRequest] = []
		for clip_id: int in Timeline.draggable.ids:
			var clip: ClipData = ClipLogic.clips[clip_id]
			move_requests.append(ClipRequest.move_request(clip, Timeline.draggable.track_offset, Timeline.draggable.frame_offset))
		if not move_requests.is_empty():
			ClipLogic.move(move_requests)
	Timeline.draggable = null
	_update_clips = true
	draw_clips.queue_redraw()
	draw_preview.queue_redraw()


func _on_mouse_entered() -> void:
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_ui_cancel()
	draw_all()


func _on_mouse_exited() -> void:
	Timeline.hovered_clip = null
	await RenderingServer.frame_pre_draw
	draw_all()


## This function is also used to handle speeding.
func _commit_current_resize() -> void:
	if Timeline.resize_target.delta != 0:
		if Timeline.state == Timeline.STATE.SPEEDING:
			ClipLogic.change_speed([ClipRequest.resize_request(
				Timeline.resize_target.clip, Timeline.resize_target.delta, Timeline.resize_target.is_end)])
		else:
			ClipLogic.resize([ClipRequest.resize_request(
					Timeline.resize_target.clip, Timeline.resize_target.delta, Timeline.resize_target.is_end)])
	Timeline.resize_target = null
	draw_clips.queue_redraw()


func _commit_box_selection(is_ctrl_pressed: bool) -> void:
	var zoom: float = Timeline.zoom
	var max_track: int = TrackLogic.tracks.size()
	var track_start: int = clampi(floori(Timeline.box_select_start.y / Timeline.track_total_size), 0, max_track)
	var track_end: int = clampi(floori(Timeline.box_select_end.y / Timeline.track_total_size), 0, max_track)
	var frame_start: int = floori(Timeline.box_select_start.x / zoom)
	var frame_end: int = floori(Timeline.box_select_end.x / zoom)
	var temp: int
	if not is_ctrl_pressed:
		ClipLogic.selected_clips.clear()

	if track_start > track_end:
		temp = track_start
		track_start = track_end
		track_end = temp
	if frame_start > frame_end:
		temp = frame_start
		frame_start = frame_end
		frame_end = temp

	for track: int in range(track_start, clamp(track_end + 1, 0, max_track)):
		for clip: ClipData in TrackLogic.track_clips[track].clips:
			if clip.start > frame_end:
				break

			if clip.start > frame_start and clip.start < frame_end:
				if clip not in ClipLogic.selected_clips:
					ClipLogic.selected_clips.append(clip)
				continue

			# We should also check if a clip ends inside the selection box.
			if clip.end > frame_start:
				if clip not in ClipLogic.selected_clips:
					ClipLogic.selected_clips.append(clip)
	if ClipLogic.selected_clips.is_empty():
		ClipLogic.selected.emit(null)
	else:
		ClipLogic.selected.emit(ClipLogic.selected_clips[-1])

	draw_box_selection.queue_redraw()
	draw_clips.queue_redraw()


## This function is also used to handle speeding.
func _handle_resize_motion() -> void:
	var clip: ClipData = Timeline.resize_target.clip
	var file: FileData = FileLogic.files[clip.file]
	var current_frame: int = get_frame_from_mouse()
	var is_fixed_duration: bool = file.type in [EditorCore.TYPE.AUDIO, EditorCore.TYPE.VIDEO]

	var snap_delta: int = Timeline.find_snap_offset([current_frame], maxi(1, int(10.0 / Timeline.zoom)), [clip.id])
	current_frame += snap_delta

	if Timeline.resize_target.is_end: # Resizing end.
		var new_duration: int = current_frame - Timeline.resize_target.original_start
		var max_allowed_duration: int = file.duration - clip.begin

		if new_duration < 1:
			new_duration = 1
		if Timeline.state != Timeline.STATE.SPEEDING and is_fixed_duration and new_duration > max_allowed_duration:
			new_duration = max_allowed_duration

		# Collision detection.
		var free_region: Vector2i = TrackLogic.get_free_region(
				clip.track, Timeline.resize_target.original_start + 1, [clip.id])

		if (Timeline.resize_target.original_start + new_duration) > free_region.y:
			new_duration = free_region.y - Timeline.resize_target.original_start
		Timeline.resize_target.delta = new_duration - Timeline.resize_target.original_duration
	else: # Resizing beginning.
		var new_start: int = current_frame

		if new_start > (Timeline.resize_target.original_start + Timeline.resize_target.original_duration - 1):
			new_start = (Timeline.resize_target.original_start + Timeline.resize_target.original_duration - 1)
		if Timeline.state != Timeline.STATE.SPEEDING and is_fixed_duration:
			var min_allowed_duration: int = Timeline.resize_target.original_start - clip.begin
			if new_start < min_allowed_duration:
				new_start = min_allowed_duration

		# Collision detection.
		var free_region: Vector2i = TrackLogic.get_free_region(
				clip.track,
				Timeline.resize_target.original_start + Timeline.resize_target.original_duration - 1,
				[clip.id])

		if new_start < free_region.x:
			new_start = free_region.x
		Timeline.resize_target.delta = new_start - Timeline.resize_target.original_start
	draw_clips.queue_redraw()


func _handle_fade_motion() -> void:
	var zoom: float = Timeline.zoom
	var clip: ClipData = Timeline.fade_target.clip
	var mouse_x: float = get_local_mouse_position().x
	var start_x: float = clip.start * zoom
	var end_x: float = clip.end * zoom
	var drag_frames: int = 0 ## Convert pixel drag to frame amount

	if not Timeline.fade_target.is_end: # Fade In
		var max_frames: int = clip.duration - (clip.effects.fade_visual.y if Timeline.fade_target.is_visual else clip.effects.fade_audio.y)
		drag_frames = clamp(floori((mouse_x - start_x) / zoom), 0, max_frames)
		if Timeline.fade_target.is_visual:
			clip.effects.fade_visual.x = drag_frames
		else:
			clip.effects.fade_audio.x = drag_frames
	else: # Fade Out
		var max_frames: int = clip.duration - (clip.effects.fade_visual.x if Timeline.fade_target.is_visual else clip.effects.fade_audio.x)
		drag_frames = clamp(floori((end_x - mouse_x) / zoom), 0, max_frames)
		if Timeline.fade_target.is_visual:
			clip.effects.fade_visual.y = drag_frames
		else:
			clip.effects.fade_audio.y = drag_frames
	draw_clips.queue_redraw()
	EditorCore.update_frame()


func _add_popup_menu_items_clip(popup: PopupMenu) -> void:
	if !right_click_clip:
		return
	if right_click_clip not in ClipLogic.selected_clips:
		ClipLogic.selected_clips = [right_click_clip]
		ClipLogic.selected.emit(right_click_clip)

	# TODO: Set shortcuts.
	popup.add_theme_constant_override("icon_max_width", 20)
	popup.add_icon_item(preload(Library.ICON_DELETE), tr("Delete clip"), POPUP_ACTION.CLIP_DELETE)
	popup.add_icon_item(preload(Library.ICON_TIMELINE_MODE_SPLIT), tr("Split clip"), POPUP_ACTION.CLIP_SPLIT)

	if right_click_clip.type == EditorCore.TYPE.VIDEO:
		popup.add_separator(tr("Video options"))
		popup.add_item(tr("Clip audio-take-over"), POPUP_ACTION.CLIP_AUDIO_TAKE_OVER)


func _on_popup_menu_id_pressed(id: POPUP_ACTION) -> void:
	match id:
		POPUP_ACTION.CLIP_DELETE: _on_popup_action_clip_delete()
		POPUP_ACTION.CLIP_SPLIT: _on_popup_action_clip_split()
		POPUP_ACTION.CLIP_AUDIO_TAKE_OVER: _on_popup_action_clip_ato()
		POPUP_ACTION.REMOVE_EMPTY_SPACE: _on_popup_action_remove_empty_space()
		POPUP_ACTION.TRACK_ADD: _on_popup_action_track_add()
		POPUP_ACTION.TRACK_REMOVE: _on_popup_action_track_remove()
		POPUP_ACTION.TRACK_TOGGLE_VISIBLE: _on_popup_action_track_toggle("is_visible")
		POPUP_ACTION.TRACK_TOGGLE_MUTE: _on_popup_action_track_toggle("is_muted")
		POPUP_ACTION.TRACK_TOGGLE_LOCK: _on_popup_action_track_toggle("is_locked")
	draw_all()


func _on_popup_action_clip_delete() -> void:
	ClipLogic.delete(ClipLogic.selected_clips)


func _on_popup_action_clip_split() -> void:
	split_clips_at(right_click_frame)


func _on_popup_action_remove_empty_space() -> void:
	remove_empty_space_at(right_click_track, right_click_frame)


func _on_popup_action_clip_ato() -> void:
	var popup: Control = PopupManager.get_popup(PopupManager.AUDIO_TAKE_OVER)
	@warning_ignore("unsafe_method_access") # NOTE: Audio take over doesn't have a class.
	popup.load_data(right_click_clip.id, false)


func _on_popup_action_track_add() -> void:
	TrackLogic.add_track(right_click_track)


func _on_popup_action_track_remove() -> void:
	TrackLogic.remove_track(right_click_track)


func _on_popup_action_track_toggle(property: String) -> void:
	var track_data: TrackData = TrackLogic.tracks[right_click_track]
	track_data.set(property, !track_data.get(property))
	if property in ["is_visible", "is_muted"]:
		EditorCore.set_frame_nr(EditorCore.frame_nr)
	Project.unsaved_changes = true
	TrackLogic.updated.emit()


func _show_hide_mode_bar(value: bool = Settings.get_show_time_mode_bar()) -> void:
	mode_panel.visible = value


func _on_select_mode_button_pressed() -> void:
	button_select.set_pressed_no_signal(true)


func _on_split_mode_button_pressed() -> void:
	button_split.set_pressed_no_signal(true)


func _on_state_changed(new_state: Timeline.STATE) -> void:
	if new_state == Timeline.STATE.SELECT:
		_on_select_mode_button_pressed()
	elif new_state == Timeline.STATE.SPLIT:
		_on_split_mode_button_pressed()

	draw_mode.queue_redraw()
	draw_playhead.queue_redraw()


func _update_track_height(new_height: float) -> void:
	Timeline.track_height = new_height
	Timeline.track_total_size = Timeline.track_height + Timeline.TRACK_LINE_WIDTH
	_on_tracks_updated()


func _on_clip_deleted(clip_id: int) -> void:
	if Timeline.hovered_clip and Timeline.hovered_clip.id == clip_id:
		Timeline.hovered_clip = null
	if pressed_clip and pressed_clip.id == clip_id:
		pressed_clip = null
	if right_click_clip and right_click_clip.id == clip_id:
		right_click_clip = null
	draw_clips.queue_redraw()


func _on_tracks_updated() -> void:
	custom_minimum_size.y = Timeline.track_total_size * TrackLogic.tracks.size()
	draw_all()


func zoom_at_mouse(factor: float) -> void:
	var old_zoom: float = Timeline.zoom
	var new_zoom: float = clamp(Timeline.zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if old_zoom == new_zoom:
		accept_event()
		return

	var old_mouse_pos_x: float = get_local_mouse_position().x
	var mouse_viewport_offset: float = old_mouse_pos_x - Timeline.scroll_x

	Timeline.zoom = new_zoom
	var zoom_ratio: float = new_zoom / old_zoom
	var new_mouse_pos_x: float = old_mouse_pos_x * zoom_ratio
	var target_scroll: int = maxi(0, int(new_mouse_pos_x - mouse_viewport_offset))
	Timeline.scroll_x = target_scroll

	_set_scroll.call_deferred(target_scroll)
	draw_all()
	accept_event()


func _set_scroll(target_scroll: int) -> void:
	if Timeline.scroll_x == target_scroll:
			scroll.scroll_horizontal = target_scroll
			Timeline.scroll_x = scroll.scroll_horizontal
			Timeline.scroll_y = scroll.scroll_vertical


func get_frame_from_mouse() -> int:
	return maxi(ceili(get_local_mouse_position().x / Timeline.zoom), 0)


func get_track_from_mouse() -> int:
	return clampi(floori(get_local_mouse_position().y / Timeline.track_total_size), 0, TrackLogic.tracks.size() - 1)


func move_playhead(frame_nr: int) -> void:
	EditorCore.set_frame(maxi(0, frame_nr))


func remove_empty_space_at(track: int, frame_nr: int) -> void:
	if TrackLogic.tracks[track].is_locked:
		return
	var clips: Array[ClipData] = TrackLogic.get_clips_after(track, frame_nr)
	var region: Vector2i = TrackLogic.get_free_region(track, frame_nr)
	var empty_size: int = region.y - region.x
	var move_requests: Array[ClipRequest] = []

	for clip: ClipData in clips:
		move_requests.append(ClipRequest.move_request(clip, 0, -empty_size))
	if !move_requests.is_empty():
		ClipLogic.move(move_requests)


func split_clip_at(clip: ClipData, frame_pos: int) -> void:
	if TrackLogic.tracks[clip.track].is_locked:
		return
	if clip.start <= frame_pos and clip.end >= frame_pos:
		ClipLogic.split([ClipRequest.split_request(clip, frame_pos - clip.start)])
	draw_clips.queue_redraw()


func split_clips_at(frame_pos: int) -> void:
	# Check if any of the clips in the tracks is in selected clips
	# if there are selected clips present, we only split the selected ones
	var requests: Array[ClipRequest] = []
	var new_clips: Array[ClipData]

	# Checking if we only want selected clips to be split.
	for clip: ClipData in ClipLogic.selected_clips:
		if clip.start < frame_pos and clip.end > frame_pos:
			requests.append(ClipRequest.split_request(clip, frame_pos - clip.start))

	if !requests.is_empty():
		new_clips = ClipLogic.split(requests)
		if new_clips.size() > 0:
			ClipLogic.selected_clips = new_clips
			ClipLogic.selected.emit(ClipLogic.selected_clips[-1])
		return draw_clips.queue_redraw()

	# No selected clips present so splitting all possible clips
	for track: int in TrackLogic.tracks.size():
		if TrackLogic.tracks[track].is_locked:
			continue
		var clip: ClipData = TrackLogic.get_clip_at_overlap(track, frame_pos)
		if !clip:
			continue
		if clip.start < frame_pos and clip.end > frame_pos:
			requests.append(ClipRequest.split_request(clip, frame_pos - clip.start))

	new_clips = ClipLogic.split(requests)
	if new_clips.size() > 0:
		ClipLogic.selected_clips = new_clips
		ClipLogic.selected.emit(ClipLogic.selected_clips[-1])
	draw_clips.queue_redraw()


func trim_clips_at(frame_pos: int, from_end: bool) -> void:
	var requests: Array[ClipRequest] = []

	for clip: ClipData in ClipLogic.selected_clips:
		if clip.start < frame_pos and clip.end > frame_pos:
			var amount: int = frame_pos - clip.end if from_end else frame_pos - clip.start
			requests.append(ClipRequest.resize_request(clip, amount, from_end))

	if requests.is_empty():
		for track: int in TrackLogic.tracks.size():
			if TrackLogic.tracks[track].is_locked:
				continue
			var clip: ClipData = TrackLogic.get_clip_at_overlap(track, frame_pos)
			if clip and clip.start < frame_pos and clip.end > frame_pos:
				var amount: int = frame_pos - clip.end if from_end else frame_pos - clip.start
				requests.append(ClipRequest.resize_request(clip, amount, from_end))

	if !requests.is_empty():
		ClipLogic.resize(requests)
		draw_clips.queue_redraw()


func draw_all() -> void:
	draw_track_lines.queue_redraw()
	draw_clips.queue_redraw()
	draw_preview.queue_redraw()
	draw_mode.queue_redraw()
	draw_playhead.queue_redraw()
	draw_box_selection.queue_redraw()
	draw_markers.queue_redraw()




class ResizeTarget:
	var clip: ClipData
	var is_end: bool
	var original_start: int = 0
	var original_duration: int = 0
	var delta: int = 0

	func _init(clip_data: ClipData, _is_end: bool, start: int, duration: int) -> void:
		clip = clip_data
		is_end = _is_end
		original_start = start
		original_duration = duration



class FadeTarget:
	var clip: ClipData
	var is_end: bool
	var is_visual: bool

	func _init(clip_data: ClipData, _is_end: bool, _is_visual: bool) -> void:
		clip = clip_data
		is_end = _is_end
		is_visual = _is_visual
