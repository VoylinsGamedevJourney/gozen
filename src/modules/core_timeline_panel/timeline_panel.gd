extends PanelContainer


enum PopupAction {
	# Clip options.
	CLIP_DELETE, CLIP_SPLIT, CLIP_REPLACE_AUDIO,
	CLIP_CHANGE_SPEED, CLIP_RESET_SPEED,
	CLIP_TOGGLE_VISIBLE, CLIP_TOGGLE_MUTE,
	# Track options.
	REMOVE_EMPTY_SPACE, TRACK_ADD, TRACK_REMOVE, TRACK_TOGGLE_VISIBLE,
	TRACK_TOGGLE_MUTE, TRACK_TOGGLE_LOCK }


const TRACK_HEIGHT_LIMIT: Vector2i = Vector2i(34, 100)

const RESIZE_HANDLE_WIDTH: int = 5
const RESIZE_CLIP_MIN_WIDTH: float = 14

const ZOOM_MIN: float = 0.001
const ZOOM_MAX: float = 200.0
const ZOOM_STEP: float = 1.1

const SAFE_ZONE: int = 200
# How many px does the mouse need to move to treat it as a drag?
const DRAG_START_THRESHOLD_PX: float = 10.0


@export var mode_panel: PanelContainer
@export var button_select: TextureButton
@export var button_split: TextureButton
@export var button_snap: TextureButton
@export var button_group: TextureButton


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

var _last_press_pos: Vector2 = Vector2()

var _update_clips: bool = true
var _last_mouse_button: int = MOUSE_BUTTON_NONE

var _drop_track_idx: int = -1
var _drop_frame_nr: int = -1



func _ready() -> void:
	if Project.project_ready.connect(_project_ready): Print.stack_connect()
	if Project.framerate_changed.connect(draw_all): Print.stack_connect()

	if Timeline.draw_requested.connect(draw_all): Print.stack_connect()
	if Timeline.state_changed.connect(_on_state_changed): Print.stack_connect()
	if Timeline.scroll_changed.connect(draw_all.unbind(1)): Print.stack_connect()
	if Timeline.zoom_changed.connect(draw_all.unbind(1)): Print.stack_connect()

	if Settings.on_module_setting_changed.connect(_on_module_setting_changed): Print.stack_connect()

	if EditorCore.visual_frame_changed.connect(draw_playhead.queue_redraw): Print.stack_connect()

	if FileLogic.files_dropped_and_loaded.connect(_on_files_dropped_and_loaded): Print.stack_connect()
	if FileLogic.request_drop_folder.connect(_on_request_drop_folder): Print.stack_connect()

	if MarkerLogic.added.connect(draw_markers.queue_redraw.unbind(1)): Print.stack_connect()
	if MarkerLogic.removed.connect(draw_markers.queue_redraw.unbind(1)): Print.stack_connect()
	if MarkerLogic.updated.connect(draw_markers.queue_redraw.unbind(1)): Print.stack_connect()
	if MarkerLogic.moving.connect(draw_markers.queue_redraw): Print.stack_connect()

	if ClipLogic.added.connect(draw_clips.queue_redraw.unbind(1)): Print.stack_connect()
	if ClipLogic.deleted.connect(_on_clip_deleted): Print.stack_connect()
	if ClipLogic.updated.connect(draw_clips.queue_redraw): Print.stack_connect()
	if TrackLogic.updated.connect(_on_tracks_updated): Print.stack_connect()

	if EffectsHandler.effects_updated.connect(draw_clips.queue_redraw): Print.stack_connect()
	if EffectsHandler.effect_values_updated.connect(draw_clips.queue_redraw): Print.stack_connect()

	if get_window().size_changed.connect(_redraw_on_change): Print.stack_connect()

	set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	_show_hide_mode_bar()
	_on_state_changed(Timeline.current_state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and Timeline.current_state in [Timeline.State.MOVING, Timeline.State.DROPPING]:
		Timeline.current_state = Timeline.State.SELECT
		Timeline.draggable = null
		draw_clips.queue_redraw()
		draw_preview.queue_redraw()


func _enter_tree() -> void:
	_sync_and_redraw.call_deferred()


func _sync_and_redraw() -> void:
	if Project.is_loaded:
		_update_track_height(Settings.get_module_setting("core_timeline_panel", "track_height", 25.0) as float)
		draw_all()


#--- INPUT HANDLING ---

func _gui_input(event: InputEvent) -> void:
	if !Project.is_loaded: return
	elif event is InputEventMouseButton: _on_gui_input_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion: _on_gui_input_mouse_motion(event as InputEventMouseMotion)
	_unhandled_input(event)


func _unhandled_input(event: InputEvent) -> void:
	var focus: Control = get_window().gui_get_focus_owner()
	if !is_visible_in_tree() and !Project.is_loaded: return
	if focus is LineEdit or focus is TextEdit:       return

	if event.is_action_pressed("split_clips_at_playhead", false, true):
		Timeline.split_clips_at(EditorCore.frame_nr)
	elif event.is_action_pressed("ui_cancel"):
		if !PopupManager._open_popups.is_empty(): return
		if Timeline.current_state in [Timeline.State.MOVING, Timeline.State.DROPPING]: return
		ClipLogic.clear_selection()
		Timeline.current_state = Timeline.State.SELECT
		_on_ui_cancel()

	if scroll.get_global_rect().has_point(get_global_mouse_position()):
		if event.is_action_pressed("ui_copy", false, true):
			ClipLogic.copy_selected_clips()
			accept_event()
		elif event.is_action_pressed("ui_cut", false, true):
			ClipLogic.cut_selected_clips()
			accept_event()
		elif event.is_action_pressed("ripple_delete_clips", false, true):
			ClipLogic.ripple_delete(ClipLogic.selected_clips)
		elif event.is_action_pressed("delete_clips", false, true):
			ClipLogic.delete(ClipLogic.selected_clips)
		elif event.is_action_pressed("duplicate_selected_clips", false, false):
			var duplicate_files: bool = (event as InputEventKey).shift_pressed
			var failed_dupes: int = ClipLogic.duplicate_clips(ClipLogic.selected_clips, duplicate_files)
			if failed_dupes > 0:
				var dialog: AcceptDialog = PopupManager.create_accept_dialog(tr("Duplication failed"))
				dialog.dialog_text = tr("Could not duplicate %d clip(s) because there was not enough empty space.") % failed_dupes
				add_child(dialog)
				dialog.popup_centered()
			draw_clips.queue_redraw()
		elif event.is_action_pressed("split_clips_at_mouse", false, true): Timeline.split_clips_at(get_frame_from_mouse())
		elif event.is_action_pressed("trim_to_clip_start", false, true):   Timeline.trim_clips_to_start()
		elif event.is_action_pressed("trim_to_clip_end", false, true):     Timeline.trim_clips_to_end()
		elif event.is_action_pressed("remove_empty_space"):
			var track: int = get_track_from_mouse()
			var frame_nr: int = get_frame_from_mouse()
			if !TrackLogic.get_clip_at_overlap(track, frame_nr):
				remove_empty_space_at(track, frame_nr)
		elif event.is_action_pressed("group_clips", false, true):
			ClipLogic.group_clips(ClipLogic.selected_clips)
			accept_event()
		elif event.is_action_pressed("ungroup_clips", false, true):
			ClipLogic.ungroup_clips(ClipLogic.selected_clips)
			accept_event()


func _on_gui_input_mouse_button(event: InputEventMouseButton) -> void:
	_last_mouse_button = event.button_index
	if event.ctrl_pressed and event.shift_pressed and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_height: float = Settings.get_module_setting("core_timeline_panel", "track_height", 25.0) + 2.0
			Settings.set_module_setting("core_timeline_panel", "track_height", clampf(new_height, TRACK_HEIGHT_LIMIT.x, TRACK_HEIGHT_LIMIT.y))
			return accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_height: float = Settings.get_module_setting("core_timeline_panel", "track_height", 25.0) - 2.0
			Settings.set_module_setting("core_timeline_panel", "track_height", clampf(new_height, TRACK_HEIGHT_LIMIT.x, TRACK_HEIGHT_LIMIT.y))
			return accept_event()

	if event.is_action_pressed("timeline_zoom_in", false, true):    return zoom_at_mouse(ZOOM_STEP)
	elif event.is_action_pressed("timeline_zoom_out", false, true): return zoom_at_mouse(1.0 / ZOOM_STEP)

	if Timeline.current_state == Timeline.State.SPLIT:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			var target: ClipData = _get_clip_on_mouse(event.position)
			if target: Timeline.split_clip_at(target, get_frame_from_mouse(event.position))
			accept_event()
		return
	elif event.is_released():
		match Timeline.current_state:
			Timeline.State.SELECT:    _commit_select(event.shift_pressed)
			Timeline.State.FADING:    _commit_current_fade()
			Timeline.State.RESIZING:  _commit_current_resize()
			Timeline.State.SPEEDING:  _commit_current_resize()
			Timeline.State.SCRUBBING: EditorCore.finish_scrub()
			Timeline.State.BOX_SELECTING: _commit_box_selection(event.ctrl_pressed)
		_on_ui_cancel()
		accept_event()

	if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		pressed_clip = _get_clip_on_mouse(event.position)
		_last_press_pos = event.position

		Timeline.current_state = Timeline.State.SELECT
		Timeline.fade_target =   _get_fade_target(event.position)
		Timeline.resize_target = _get_resize_target(event.position)

		if Timeline.fade_target:
			Timeline.current_state = Timeline.State.FADING
			draw_clips.queue_redraw()
		elif Timeline.resize_target:
			Timeline.current_state = Timeline.State.SPEEDING if event.ctrl_pressed else Timeline.State.RESIZING
			draw_clips.queue_redraw()
		elif _last_mouse_button == MOUSE_BUTTON_LEFT and event.double_click and !pressed_clip:
			var mod: int = Settings.get_module_setting("core_timeline_panel", "delete_empty_modifier", KEY_NONE)
			if mod == KEY_NONE or (mod == KEY_CTRL and event.ctrl_pressed) or (mod == KEY_SHIFT and event.shift_pressed):
				remove_empty_space_at(get_track_from_mouse(event.position), get_frame_from_mouse(event.position))
				return
		elif !pressed_clip:
			if event.shift_pressed:
				var mouse_pos: Vector2 = event.position
				_start_box_select(mouse_pos, mouse_pos)
			else:
				var action: int = Settings.get_module_setting("core_timeline_panel", "empty_space_click_action", 0)
				match action:
					0: # SEEK.
						Timeline.current_state = Timeline.State.SCRUBBING
						if EditorCore.is_playing: # Setting is_playing triggers a setter.
							EditorCore.is_playing = false
						EditorCore.scrub_to_frame(get_frame_from_mouse(event.position))
					1: # CLEAR_SELECTION.
						ClipLogic.selected_clips.clear()
						ClipLogic.selected.emit(null)
		elif pressed_clip not in ClipLogic.selected_clips:
			var clips_to_select: Array[ClipData] = ClipLogic.get_clips_to_select(pressed_clip)

			if !event.shift_pressed:
				ClipLogic.selected_clips = clips_to_select
			else:
				for clip: ClipData in clips_to_select:
					if clip in ClipLogic.selected_clips: continue
					ClipLogic.selected_clips.append(clip)
			draw_clips.queue_redraw()
			ClipLogic.selected.emit(pressed_clip)
	elif event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var popup: PopupMenu = PopupManager.create_menu()
		right_click_clip = _get_clip_on_mouse(event.position)
		right_click_track = get_track_from_mouse(event.position)
		right_click_frame = get_frame_from_mouse(event.position)

		var target_menu: PopupMenu = popup
		if right_click_clip:
			_add_popup_menu_items_clip(popup)
			popup.add_separator()
			var track_submenu: PopupMenu = PopupMenu.new()
			track_submenu.name = "TrackSubMenu"
			track_submenu.add_theme_constant_override("icon_max_width", 20)
			popup.add_child(track_submenu)
			popup.add_submenu_node_item(tr("Track options"), track_submenu)
			target_menu = track_submenu
			if track_submenu.id_pressed.connect(_on_popup_menu_id_pressed): Print.stack_connect()
		else:
			popup.add_item(tr("Remove empty space"), PopupAction.REMOVE_EMPTY_SPACE)
			popup.add_separator(tr("Track options"))

		var track_data: TrackData = TrackLogic.tracks[right_click_track]

		target_menu.add_icon_item(preload(Library.ICON_ADD), tr("Add track"), PopupAction.TRACK_ADD)
		if TrackLogic.tracks.size() != 1:
			target_menu.add_icon_item(preload(Library.ICON_DELETE), tr("Remove track"), PopupAction.TRACK_REMOVE)

		target_menu.add_separator()

		target_menu.add_check_item(tr("Show track"), PopupAction.TRACK_TOGGLE_VISIBLE)
		target_menu.set_item_checked(target_menu.get_item_index(PopupAction.TRACK_TOGGLE_VISIBLE), track_data.is_visible)

		target_menu.add_check_item(tr("Mute track"), PopupAction.TRACK_TOGGLE_MUTE)
		target_menu.set_item_checked(target_menu.get_item_index(PopupAction.TRACK_TOGGLE_MUTE), track_data.is_muted)

		if not OS.has_feature("demo"):
			target_menu.add_check_item(tr("Lock track"), PopupAction.TRACK_TOGGLE_LOCK)
			target_menu.set_item_checked(target_menu.get_item_index(PopupAction.TRACK_TOGGLE_LOCK), track_data.is_locked)

		if popup.id_pressed.connect(_on_popup_menu_id_pressed): Print.stack_connect()
		PopupManager.show_menu(popup)

	if event.is_pressed() and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		accept_event()
	get_window().gui_release_focus()


func _on_gui_input_mouse_motion(event: InputEventMouseMotion) -> void:
	Timeline.mouse_track = get_track_from_mouse(event.position)
	Timeline.mouse_frame = get_frame_from_mouse(event.position)

	if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		scroll.scroll_horizontal = max(scroll.scroll_horizontal - event.relative.x, 0.0)

	var clip_on_mouse: ClipData = _get_clip_on_mouse(event.position)
	if clip_on_mouse:
		var nickname: String = FileLogic.files[clip_on_mouse.file].nickname
		if tooltip_text != nickname:
			tooltip_text = nickname
		if Timeline.hovered_clip != clip_on_mouse:
			Timeline.hovered_clip = clip_on_mouse
			draw_clips.queue_redraw()
	else:
		if tooltip_text != "" or Timeline.current_state != Timeline.State.SELECT:
			tooltip_text = ""
		if Timeline.hovered_clip != null:
			Timeline.hovered_clip = null
			draw_clips.queue_redraw()

	match Timeline.current_state:
		Timeline.State.SELECT:
			if Input.is_key_pressed(KEY_SHIFT) \
				and event.button_mask & MOUSE_BUTTON_MASK_LEFT \
				and event.position.distance_to(_last_press_pos) > DRAG_START_THRESHOLD_PX:
					_start_box_select(_last_press_pos, event.position)
			elif _get_fade_target(event.position) != null:
				mouse_default_cursor_shape = Control.CURSOR_CROSS
			elif _get_resize_target(event.position) != null:
				mouse_default_cursor_shape = Control.CURSOR_HSIZE
			elif clip_on_mouse:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
		Timeline.State.SPLIT:
			mouse_default_cursor_shape = Control.CURSOR_IBEAM
			draw_mode.set("mouse_pos_x", event.position.x)
			draw_mode.queue_redraw()
		Timeline.State.FADING:
			_handle_fade_motion(event.position)
		Timeline.State.SCRUBBING:
			if event.button_mask & MOUSE_BUTTON_LEFT:
				EditorCore.scrub_to_frame(get_frame_from_mouse(event.position))
		Timeline.State.BOX_SELECTING:
			Timeline.box_select_end = event.position
			mouse_default_cursor_shape = Control.CURSOR_CROSS
			draw_box_selection.queue_redraw()
		Timeline.State.RESIZING, Timeline.State.SPEEDING:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
			_handle_resize_motion(event.position)
			draw_preview.queue_redraw()


func _on_ui_cancel() -> void:
	pressed_clip = null
	Timeline.hovered_clip = null
	if Timeline.current_state not in [Timeline.State.SELECT, Timeline.State.SPLIT]:
		Timeline.current_state = Timeline.State.SELECT
	Timeline.draggable = null
	Timeline.fade_target = null
	Timeline.resize_target = null
	if Timeline.current_state == Timeline.State.SPLIT:
		mouse_default_cursor_shape = Control.CURSOR_IBEAM
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	draw_all()


func _get_clip_on_mouse(mouse_pos: Vector2 = get_local_mouse_position()) -> ClipData:
	if mouse_pos.y >= TrackLogic.tracks.size() * Timeline.track_total_size:
		return null
	return TrackLogic.get_clip_at_overlap(get_track_from_mouse(mouse_pos), clampi(get_frame_from_mouse(mouse_pos) - 1, 0, Project.data.timeline_end))


func _get_resize_target(mouse_pos: Vector2 = get_local_mouse_position()) -> Timeline.ResizeTarget:
	if mouse_pos.y >= TrackLogic.tracks.size() * Timeline.track_total_size:
		return null
	var track: int = get_track_from_mouse(mouse_pos)
	if TrackLogic.tracks[track].is_locked:
		return null

	var zoom: float = Timeline.zoom
	var mouse_x: float = mouse_pos.x
	var handle_width: float = RESIZE_HANDLE_WIDTH
	for clip: ClipData in TrackLogic.track_clips[track].clips:
		if (clip.duration * zoom) < 20.0:
			continue
		var start_x: float = clip.start * zoom
		var end_x: float = (clip.end - 1) * zoom
		var start_distance: float = abs(mouse_x - start_x)
		var end_distance: float = abs(mouse_x - end_x)
		if start_distance <= handle_width and start_distance < end_distance:
			return Timeline.ResizeTarget.new(clip, false, clip.start, clip.duration)
		if end_distance <= handle_width and end_distance <= start_distance:
			return Timeline.ResizeTarget.new(clip, true, clip.start, clip.duration)
	return null


func _get_fade_target(mouse_pos: Vector2 = get_local_mouse_position()) -> Timeline.FadeTarget:
	if mouse_pos.y >= TrackLogic.tracks.size() * Timeline.track_total_size:
		return null
	var track: int = get_track_from_mouse(mouse_pos)
	if TrackLogic.tracks[track].is_locked:
		return null

	var zoom: float = Timeline.zoom
	var handle_size: float = 3.5 # FADE_HANDLE_SIZE
	for clip: ClipData in TrackLogic.track_clips[track].clips:
		if (clip.duration * zoom) < 20.0:
			continue

		var start_x: float = clip.start * zoom
		var end_x: float = clip.end * zoom
		var y_pos: float = clip.track * Timeline.track_total_size
		if clip.type in EditorCore.VISUAL_TYPES:
			var corner_y: float = y_pos + Timeline.track_height
			var in_x: float = start_x + clip.effects.fade_visual.x * zoom
			var out_x: float = end_x - clip.effects.fade_visual.y * zoom - handle_size * 2
			var in_rect: Rect2 = Rect2(in_x, corner_y - handle_size * 2, handle_size * 2, handle_size * 2)
			var out_rect: Rect2 = Rect2(out_x, corner_y - handle_size * 2, handle_size * 2, handle_size * 2)
			if in_rect.grow(handle_size).has_point(mouse_pos):
				return Timeline.FadeTarget.new(clip, false, true)
			if out_rect.grow(handle_size).has_point(mouse_pos):
				return Timeline.FadeTarget.new(clip, true, true)

		if clip.type in EditorCore.AUDIO_TYPES:
			var corner_y: float = y_pos
			var in_x: float = start_x + clip.effects.fade_audio.x * zoom
			var out_x: float = end_x - clip.effects.fade_audio.y * zoom - handle_size * 2
			var in_rect: Rect2 = Rect2(in_x, corner_y, handle_size * 2, handle_size * 2)
			var out_rect: Rect2 = Rect2(out_x, corner_y, handle_size * 2, handle_size * 2)
			if in_rect.grow(handle_size).has_point(mouse_pos):
				return Timeline.FadeTarget.new(clip, false, false)
			if out_rect.grow(handle_size).has_point(mouse_pos):
				return Timeline.FadeTarget.new(clip, true, false)
	return null


func _project_ready() -> void:
	_update_track_height(Settings.get_module_setting("core_timeline_panel", "track_height", 25.0) as float)
	draw_all()


func _get_drag_data(_p: Vector2) -> Variant:
	if Timeline.current_state != Timeline.State.SELECT or !pressed_clip or TrackLogic.tracks[pressed_clip.track].is_locked or Input.is_key_pressed(KEY_SHIFT):
		return null
	if pressed_clip not in ClipLogic.selected_clips:
		ClipLogic.selected_clips = ClipLogic.get_clips_to_select(pressed_clip)
		draw_clips.queue_redraw()

	var data: Draggable = Draggable.new()
	var clips: Array[ClipData] = ClipLogic.selected_clips.duplicate()
	var anchor_index: int = clips.find(pressed_clip)
	if anchor_index != -1:
		clips.remove_at(anchor_index)
		if clips.insert(0, pressed_clip):
			printerr("TimelinePanel: Couldn't insert '%s' into clips!" % pressed_clip.id)
	for clip: ClipData in clips:
		data.ids.append(clip.id)
	data.mouse_offset = get_frame_from_mouse() - pressed_clip.start
	Timeline.current_state = Timeline.State.MOVING
	return data


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is RequestEffectDrag:
		var drag_data: RequestEffectDrag = data
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
		Timeline.current_state = Timeline.State.DROPPING
		var split_audio: bool = Input.is_key_pressed(KEY_SHIFT)
		var split_extra_audio: bool = Input.is_key_pressed(KEY_CTRL) and not split_audio
		result = Timeline.can_drop_new_clips(get_track_from_mouse(), get_frame_from_mouse(), SAFE_ZONE, split_audio, split_extra_audio)
	else:
		Timeline.current_state = Timeline.State.MOVING
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
	if data is RequestEffectDrag:
		var drag_data: RequestEffectDrag = data
		var clip: ClipData = _get_clip_on_mouse()
		if clip:
			var new_effect: Effect = drag_data.effect.deep_copy()
			EffectsHandler.add_effect([clip], new_effect, drag_data.is_visual)
		return
	elif data is not Draggable or Timeline.current_state not in [Timeline.State.DROPPING, Timeline.State.MOVING]:
		return
	elif Timeline.draggable.is_file: # Creating new clips (ids are file ids!)
		var requests: Array[RequestClipAdd] = []
		var total_duration: int = 0
		var split_audio: bool = Input.is_key_pressed(KEY_SHIFT)
		var split_extra_audio: bool = Input.is_key_pressed(KEY_CTRL) and not split_audio
		var existing_group_ids: Array[int] = ClipLogic._get_all_group_ids()

		for file_id: int in Timeline.draggable.ids:
			var file: FileData = FileLogic.files[file_id]
			var target_frame: int = Timeline.draggable.frame_offset + total_duration
			var is_split: bool = split_audio or split_extra_audio

			var video_request: RequestClipAdd = RequestClipAdd.new()
			video_request.file = file
			video_request.frame = target_frame
			video_request.track = Timeline.draggable.track_offset
			video_request.type =  FileLogic.files[file.id].type

			if is_split and file.type == EditorCore.Type.VIDEO and file.audio_streams.size() > 0:
				var group_id: int = Utils.get_unique_id(existing_group_ids)
				existing_group_ids.append(group_id)

				video_request.type = EditorCore.Type.VIDEO
				video_request.group_id = group_id
				video_request.is_muted = split_audio
				if split_extra_audio:
					video_request.audio_index = file.audio_streams[0]

				requests.append(video_request)

				var start_i: int = 0 if split_audio else 1
				for i: int in range(start_i, file.audio_streams.size()):
					var audio_track_idx: int = Timeline.draggable.track_offset + 1 + (i - start_i)
					var audio_request: RequestClipAdd = RequestClipAdd.new()
					audio_request.file = file
					audio_request.group_id = group_id
					audio_request.track = audio_track_idx
					audio_request.frame = target_frame
					audio_request.audio_index = file.audio_streams[i]
					audio_request.type = EditorCore.Type.AUDIO
					requests.append(audio_request)
			else: requests.append(video_request)
			total_duration += file.duration
		ClipLogic.add(requests)
	else: # Moving clips.
		var move_requests: Array[RequestClipMove] = []
		for clip_id: int in Timeline.draggable.ids:
			var clip: ClipData = ClipLogic.clips[clip_id]
			var request: RequestClipMove = RequestClipMove.new()
			request.clip = clip
			request.offset_frame = Timeline.draggable.frame_offset
			request.offset_track = Timeline.draggable.track_offset
			move_requests.append(request)
		ClipLogic.move(move_requests)
	Timeline.draggable = null
	_update_clips = true
	draw_clips.queue_redraw()
	draw_preview.queue_redraw()


func _on_mouse_entered() -> void:
	Timeline.is_mouse_over = true
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_ui_cancel()
	draw_all()


func _on_mouse_exited() -> void:
	Timeline.is_mouse_over = false
	Timeline.hovered_clip = null
	await RenderingServer.frame_pre_draw
	draw_all()


func _on_snap_button_toggled(toggled: bool) -> void:
	button_snap.texture_normal = load(Library.ICON_SNAP_ON if toggled else Library.ICON_SNAP_OFF)
	Timeline.snap_enabled = toggled


func _on_group_button_toggled(toggled: bool) -> void:
	button_group.texture_normal = load(Library.ICON_LINK_ON if toggled else Library.ICON_LINK_OFF)
	Timeline.group_enabled = toggled


## This function is also used to handle speeding.
func _commit_current_resize() -> void:
	if Timeline.resize_target.delta != 0:
		var request: RequestClipResize = RequestClipResize.new()
		request.clip = Timeline.resize_target.clip
		request.resize_amount = Timeline.resize_target.delta
		request.from_end = Timeline.resize_target.is_end

		if Timeline.current_state == Timeline.State.SPEEDING:
			ClipLogic.change_speed([request])
		else:
			ClipLogic.resize([request])
	Timeline.resize_target = null
	draw_clips.queue_redraw()


func _commit_select(shift_pressed: bool) -> void:
	if pressed_clip and pressed_clip == _get_clip_on_mouse() and not shift_pressed:
		var group_clips: Array[ClipData] = ClipLogic.get_clips_to_select(pressed_clip)
		var different: bool = false
		if ClipLogic.selected_clips.size() != group_clips.size():
			different = true
		else:
			for clip: ClipData in group_clips:
				if clip in ClipLogic.selected_clips: continue
				different = true
				break
		if different:
			ClipLogic.selected_clips = group_clips
			draw_clips.queue_redraw()
		ClipLogic.selected.emit(pressed_clip)


func _commit_current_fade() -> void:
	if Timeline.fade_target == null:
		return

	var clip: ClipData = Timeline.fade_target.clip
	var is_visual: bool = Timeline.fade_target.is_visual
	var new_fade: Vector2i = clip.effects.fade_visual if is_visual else clip.effects.fade_audio
	var old_fade: Vector2i = Timeline.fade_target.original_fade
	if new_fade == old_fade:
		var closest_dist: int = Utils.INT_32_MAX
		var target_frames: int = 0

		for track_data: TrackLogic.TrackClips in TrackLogic.track_clips:
			for other_clip: ClipData in track_data.clips:
				if other_clip == clip: continue
				if not Timeline.fade_target.is_end: # Fade In.
					if other_clip.start > clip.start and other_clip.start <= clip.end:
						var dist: int = other_clip.start - clip.start
						if dist < closest_dist:
							closest_dist = dist
							target_frames = dist
					if other_clip.end > clip.start and other_clip.end <= clip.end:
						var dist: int = other_clip.end - clip.start
						if dist < closest_dist:
							closest_dist = dist
							target_frames = dist
				else: # Fade Out.
					if other_clip.start >= clip.start and other_clip.start < clip.end:
						var dist: int = clip.end - other_clip.start
						if dist < closest_dist:
							closest_dist = dist
							target_frames = dist
					if other_clip.end >= clip.start and other_clip.end < clip.end:
						var dist: int = clip.end - other_clip.end
						if dist < closest_dist:
							closest_dist = dist
							target_frames = dist

		var max_frames: int = clip.duration - (old_fade.y if not Timeline.fade_target.is_end else old_fade.x)
		if target_frames > max_frames:
			target_frames = max_frames

		if not Timeline.fade_target.is_end:
			new_fade.x = target_frames if target_frames > 0 and old_fade.x != target_frames else 0
		else:
			new_fade.y = target_frames if target_frames > 0 and old_fade.y != target_frames else 0

	if new_fade != old_fade:
		if is_visual:
			clip.effects.fade_visual = old_fade
		else:
			clip.effects.fade_audio = old_fade

		InputManager.undo_redo.create_action("Change fade")
		InputManager.undo_redo.add_do_method(EffectsHandler._set_fade.bind(clip, is_visual, new_fade))
		InputManager.undo_redo.add_undo_method(EffectsHandler._set_fade.bind(clip, is_visual, old_fade))
		InputManager.undo_redo.commit_action()
	Timeline.fade_target = null
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

			if not (clip.start > frame_start or clip.end > frame_start):
				continue

			if clip in ClipLogic.selected_clips: continue

			var clips_to_select: Array[ClipData] = ClipLogic.get_clips_to_select(clip)
			for group_clip: ClipData in clips_to_select:
				if group_clip in ClipLogic.selected_clips: continue
				ClipLogic.selected_clips.append(group_clip)

	if ClipLogic.selected_clips.is_empty():
		ClipLogic.selected.emit(null)
	else:
		ClipLogic.selected.emit(ClipLogic.selected_clips[-1])

	draw_box_selection.queue_redraw()
	draw_clips.queue_redraw()


func _start_box_select(start_pos: Vector2, end_pos: Vector2) -> void:
	Timeline.current_state = Timeline.State.BOX_SELECTING
	Timeline.box_select_start = start_pos
	Timeline.box_select_end = end_pos
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	draw_box_selection.queue_redraw()


## This function is also used to handle speeding.
func _handle_resize_motion(mouse_pos: Vector2) -> void:
	var clip: ClipData = Timeline.resize_target.clip
	var file: FileData = FileLogic.files[clip.file]
	var current_frame: int = get_frame_from_mouse(mouse_pos)
	var is_fixed_duration: bool = file.type in [EditorCore.Type.AUDIO, EditorCore.Type.VIDEO]
	if file.path.to_lower().get_extension() == "gif":
		is_fixed_duration = false

	var snap_delta: int = Timeline.find_snap_offset([current_frame], maxi(1, int(10.0 / Timeline.zoom)), [clip.id])
	current_frame += snap_delta

	if Timeline.resize_target.is_end: # Resizing end.
		var new_duration: int = current_frame - Timeline.resize_target.original_start
		var max_allowed_duration: int = file.duration - clip.begin

		if new_duration < 1:
			new_duration = 1
		if Timeline.current_state != Timeline.State.SPEEDING and is_fixed_duration and new_duration > max_allowed_duration:
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
		if Timeline.current_state != Timeline.State.SPEEDING and is_fixed_duration:
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


func _handle_fade_motion(mouse_pos: Vector2) -> void:
	var zoom: float = Timeline.zoom
	var clip: ClipData = Timeline.fade_target.clip
	var mouse_x: float = mouse_pos.x
	var start_x: float = clip.start * zoom
	var end_x: float = clip.end * zoom
	var drag_frames: int = 0 ## Convert pixel drag to frame amount.

	if not Timeline.fade_target.is_end: # Fade In.
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
	EditorCore.set_frame(EditorCore.frame_nr)


func _add_popup_menu_items_clip(popup: PopupMenu) -> void:
	if !right_click_clip:
		return
	if right_click_clip not in ClipLogic.selected_clips:
		ClipLogic.selected_clips = [right_click_clip]
		ClipLogic.selected.emit(right_click_clip)

	# TODO: Set shortcuts.
	popup.add_theme_constant_override("icon_max_width", 20)
	popup.add_icon_item(preload(Library.ICON_DELETE), tr("Delete clip"), PopupAction.CLIP_DELETE)
	popup.add_icon_item(preload(Library.ICON_TIMELINE_MODE_SPLIT), tr("Split clip"), PopupAction.CLIP_SPLIT)

	popup.add_separator()
	if right_click_clip.type in EditorCore.VISUAL_TYPES:
		popup.add_check_item(tr("Show clip"), PopupAction.CLIP_TOGGLE_VISIBLE)
		popup.set_item_checked(popup.get_item_index(PopupAction.CLIP_TOGGLE_VISIBLE), right_click_clip.effects.is_showing)
	if right_click_clip.type in EditorCore.AUDIO_TYPES:
		popup.add_check_item(tr("Mute clip"), PopupAction.CLIP_TOGGLE_MUTE)
		popup.set_item_checked(popup.get_item_index(PopupAction.CLIP_TOGGLE_MUTE), right_click_clip.effects.is_muted)

	if right_click_clip.type in [EditorCore.Type.VIDEO, EditorCore.Type.AUDIO]:
		# TODO: Add icons
		popup.add_icon_item(preload(Library.ICON_SPEED), tr("Change speed"), PopupAction.CLIP_CHANGE_SPEED)
		if right_click_clip.speed != 1.0:
			popup.add_icon_item(preload(Library.ICON_SPEED_RESET), tr("Reset speed"), PopupAction.CLIP_RESET_SPEED)

	if right_click_clip.type == EditorCore.Type.VIDEO:
		popup.add_separator(tr("Video options"))

		if not OS.has_feature("demo"):
			popup.add_item(tr("Clip replace audio"), PopupAction.CLIP_REPLACE_AUDIO)

		var file: FileData = FileLogic.files[right_click_clip.file]
		if file.audio_streams.size() > 1:
			var audio_submenu: PopupMenu = PopupMenu.new()
			audio_submenu.name = "AudioStreamsSubMenu"
			for i: int in file.audio_streams.size():
				var stream_index: int = file.audio_streams[i]
				audio_submenu.add_radio_check_item("Audio Track %d" % (i + 1), stream_index)
				var current_index: int = right_click_clip.effects.audio_stream_index
				if current_index == -1: current_index = file.audio_streams[0]
				audio_submenu.set_item_checked(i, stream_index == current_index)
			popup.add_child(audio_submenu)
			popup.add_submenu_node_item("Select Audio Track", audio_submenu)
			if audio_submenu.id_pressed.connect(func(id: int) -> void:
					InputManager.undo_redo.create_action("Change audio track")
					InputManager.undo_redo.add_do_method(ClipLogic._set_audio_stream.bind(right_click_clip.effects, id))
					InputManager.undo_redo.add_undo_method(ClipLogic._set_audio_stream.bind(right_click_clip.effects, right_click_clip.effects.audio_stream_index))
					InputManager.undo_redo.commit_action()): Print.stack_connect()


func _on_popup_menu_id_pressed(id: PopupAction) -> void:
	match id:
		PopupAction.CLIP_DELETE: _on_popup_action_clip_delete()
		PopupAction.CLIP_SPLIT: _on_popup_action_clip_split()
		PopupAction.CLIP_REPLACE_AUDIO: _on_popup_action_clip_ato()
		PopupAction.CLIP_CHANGE_SPEED: _on_popup_action_clip_change_speed()
		PopupAction.CLIP_RESET_SPEED: _on_popup_action_clip_reset_speed()
		PopupAction.CLIP_TOGGLE_VISIBLE:
			ClipLogic.toggle_clip_visible(right_click_clip, not right_click_clip.effects.is_showing)
		PopupAction.CLIP_TOGGLE_MUTE:
			ClipLogic.toggle_clip_mute(right_click_clip, not right_click_clip.effects.is_muted)
		PopupAction.REMOVE_EMPTY_SPACE: _on_popup_action_remove_empty_space()
		PopupAction.TRACK_ADD: _on_popup_action_track_add()
		PopupAction.TRACK_REMOVE: _on_popup_action_track_remove()
		PopupAction.TRACK_TOGGLE_VISIBLE: _on_popup_action_track_toggle("is_visible")
		PopupAction.TRACK_TOGGLE_MUTE: _on_popup_action_track_toggle("is_muted")
		PopupAction.TRACK_TOGGLE_LOCK: _on_popup_action_track_toggle("is_locked")
	draw_all()


func _on_popup_action_clip_delete() -> void:
	ClipLogic.delete(ClipLogic.selected_clips)


func _on_popup_action_clip_split() -> void:
	Timeline.split_clips_at(right_click_frame)


func _on_popup_action_remove_empty_space() -> void:
	remove_empty_space_at(right_click_track, right_click_frame)


func _on_popup_action_clip_ato() -> void:
	var popup: Control = PopupManager.get_popup(PopupManager.REPLACE_AUDIO)
	@warning_ignore("unsafe_method_access") # NOTE: Audio take over doesn't have a class.
	popup.load_data(right_click_clip.id, false)


func _on_popup_action_clip_change_speed() -> void:
	var dialog: ConfirmationDialog = PopupManager.create_confirmation_dialog(tr("Change speed"), "")
	var spinbox: SpinBox = SpinBox.new()
	spinbox.min_value = 0.01
	spinbox.max_value = 100.0
	spinbox.step = 0.01
	spinbox.value = right_click_clip.speed
	spinbox.suffix = "x"
	dialog.add_child(spinbox)

	if dialog.confirmed.connect(func() -> void:
			var new_speed: float = spinbox.value
			var new_duration: int = maxi(1, int((right_click_clip.duration * right_click_clip.speed) / new_speed))

			var free_region: Vector2i = TrackLogic.get_free_region(right_click_clip.track, right_click_clip.start + 1, [right_click_clip.id])
			if right_click_clip.start + new_duration > free_region.y:
				new_duration = free_region.y - right_click_clip.start

			var request: RequestClipResize = RequestClipResize.new()
			var delta: int = new_duration - right_click_clip.duration
			request.clip = right_click_clip
			request.resize_amount = delta
			request.from_end = true
			ClipLogic.change_speed([request])
			dialog.queue_free()): Print.stack_connect()
	dialog.popup_centered(Vector2i(200, 80))


func _on_popup_action_clip_reset_speed() -> void:
	var new_speed: float = 1.0
	var new_duration: int = maxi(1, int((right_click_clip.duration * right_click_clip.speed) / new_speed))

	var free_region: Vector2i = TrackLogic.get_free_region(right_click_clip.track, right_click_clip.start + 1, [right_click_clip.id])
	if right_click_clip.start + new_duration > free_region.y:
		new_duration = free_region.y - right_click_clip.start

	var request: RequestClipResize = RequestClipResize.new()
	request.clip = right_click_clip
	request.resize_amount = new_duration - right_click_clip.duration
	request.from_end = true
	ClipLogic.change_speed([request])


func _on_popup_action_track_add() -> void:    TrackLogic.add_track(right_click_track)
func _on_popup_action_track_remove() -> void: TrackLogic.remove_track(right_click_track)


func _on_popup_action_track_toggle(property: String) -> void:
	var track_data: TrackData = TrackLogic.tracks[right_click_track]
	track_data.set(property, !track_data.get(property))
	if property in ["is_visible", "is_muted"]:
		EditorCore.set_frame_nr(EditorCore.frame_nr)
	Project.unsaved_changes = true
	TrackLogic.updated.emit()


func _show_hide_mode_bar(value: bool = Settings.get_module_setting("core_timeline_panel", "show_time_mode_bar", true)) -> void:
	mode_panel.visible = value


func _on_select_mode_button_pressed() -> void:
	button_select.set_pressed_no_signal(true)
	button_split.set_pressed_no_signal(false)
	Timeline.current_state = Timeline.State.SELECT


func _on_split_mode_button_pressed() -> void:
	button_select.set_pressed_no_signal(false)
	button_split.set_pressed_no_signal(true)
	Timeline.current_state = Timeline.State.SPLIT
	draw_mode.set("mouse_pos_x", get_local_mouse_position().x)
	draw_mode.queue_redraw()


func _on_module_setting_changed(module_folder: String, setting_id: String, value: Variant) -> void:
	if module_folder != "core_timeline_panel": return

	if setting_id == "show_time_mode_bar":
		_show_hide_mode_bar(value as bool)
	elif setting_id == "track_height":
		_update_track_height(value as float)


func _on_state_changed(new_state: Timeline.State) -> void:
	match new_state:
		Timeline.State.SELECT: _on_select_mode_button_pressed()
		Timeline.State.SPLIT:  _on_split_mode_button_pressed()

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

	var mouse_viewport_offset: float = get_global_mouse_position().x - scroll.global_position.x
	var absolute_x: float = Timeline.scroll_x + mouse_viewport_offset
	var zoom_ratio: float = new_zoom / old_zoom
	var new_absolute_x: float = absolute_x * zoom_ratio
	var target_scroll: int = maxi(0, int(new_absolute_x - mouse_viewport_offset))
	var timestamp_scroll: ScrollContainer = scroll.get("timestamp_scroll")
	if new_zoom < old_zoom:
		if timestamp_scroll: timestamp_scroll.scroll_horizontal = target_scroll
		scroll.scroll_horizontal = target_scroll

	Timeline.zoom = new_zoom
	Timeline.scroll_x = target_scroll
	Timeline.scroll_y = scroll.scroll_vertical
	draw_all()
	accept_event()
	if new_zoom >= old_zoom:
		_update_scroll.call_deferred(timestamp_scroll, target_scroll)


func _update_scroll(timestamp_scroll: ScrollContainer, target_scroll: int) -> void:
	timestamp_scroll.scroll_horizontal = target_scroll
	scroll.scroll_horizontal = target_scroll


func get_frame_from_mouse(mouse_pos: Vector2 = get_local_mouse_position()) -> int:
	return maxi(roundi(mouse_pos.x / Timeline.zoom), 0)


func get_track_from_mouse(mouse_pos: Vector2 = get_local_mouse_position()) -> int:
	return clampi(floori(mouse_pos.y / Timeline.track_total_size), 0, TrackLogic.tracks.size() - 1)


func move_playhead(frame_nr: int) -> void:
	EditorCore.set_frame(maxi(0, frame_nr))


func remove_empty_space_at(track: int, frame_nr: int) -> void:
	if TrackLogic.tracks[track].is_locked: return

	var clips: Array[ClipData] = TrackLogic.get_clips_after(track, frame_nr)
	var region: Vector2i = TrackLogic.get_free_region(track, frame_nr)
	var empty_size: int = region.y - region.x
	var move_requests: Array[RequestClipMove] = []

	var clips_to_move: Array[ClipData] = []
	for clip: ClipData in clips:
		if clip in clips_to_move: continue
		clips_to_move.append(clip)

		if !Timeline.group_enabled: continue
		for group_clip: ClipData in ClipLogic.get_group_clips(clip):
			if not group_clip in clips_to_move:
				clips_to_move.append(group_clip)

	for clip: ClipData in clips_to_move:
		var request: RequestClipMove = RequestClipMove.new()
		request.clip = clip
		request.offset_frame = -empty_size
		move_requests.append(request)
	ClipLogic.move(move_requests)


func _on_request_drop_folder(screen_pos: Vector2) -> void:
	if is_visible_in_tree() and scroll.get_global_rect().has_point(screen_pos):
		var local_mouse: Vector2 = get_global_transform().affine_inverse() * screen_pos
		_drop_track_idx = clampi(floori(local_mouse.y / Timeline.track_total_size), 0, TrackLogic.tracks.size() - 1)
		_drop_frame_nr = maxi(roundi(local_mouse.x / Timeline.zoom), 0)
	else:
		_drop_track_idx = -1
		_drop_frame_nr = -1


func _on_files_dropped_and_loaded(files: Array[FileData], screen_pos: Vector2) -> void:
	var track_idx: int = -1
	var frame_nr: int = -1

	if _drop_track_idx != -1 and _drop_frame_nr != -1:
		track_idx = _drop_track_idx
		frame_nr = _drop_frame_nr
		_drop_track_idx = -1
		_drop_frame_nr = -1
	elif is_visible_in_tree() and scroll.get_global_rect().has_point(screen_pos):
		var local_mouse: Vector2 = get_global_transform().affine_inverse() * screen_pos
		track_idx = clampi(floori(local_mouse.y / Timeline.track_total_size), 0, TrackLogic.tracks.size() - 1)
		frame_nr = maxi(roundi(local_mouse.x / Timeline.zoom), 0)

	if track_idx != -1 and frame_nr != -1:
		var drag_data: Draggable = Draggable.new()
		drag_data.is_file = true
		for file: FileData in files:
			drag_data.ids.append(file.id)
			drag_data.duration += file.duration
		drag_data.mouse_offset = 0

		Timeline.draggable = drag_data
		Timeline.draggable = drag_data
		var split_audio: bool = Input.is_key_pressed(KEY_SHIFT)
		var split_extra_audio: bool = Input.is_key_pressed(KEY_CTRL) and not split_audio
		if Timeline.can_drop_new_clips(track_idx, frame_nr, SAFE_ZONE, split_audio, split_extra_audio):
			var requests: Array[RequestClipAdd] = []
			var total_duration: int = 0
			var existing_group_ids: Array[int] = ClipLogic._get_all_group_ids()

			for file: FileData in files:
				var target_frame: int = Timeline.draggable.frame_offset + total_duration
				var video_request: RequestClipAdd = RequestClipAdd.new()
				video_request.file = file
				video_request.track = track_idx
				video_request.frame = target_frame
				video_request.type =  FileLogic.files[file.id].type

				if (split_audio or split_extra_audio) and file.type == EditorCore.Type.VIDEO and file.audio_streams.size() > 0:
					var group_id: int = Utils.get_unique_id(existing_group_ids)
					existing_group_ids.append(group_id)

					video_request.group_id = group_id
					video_request.is_muted = split_audio
					if split_extra_audio:
						video_request.audio_index = file.audio_streams[0]
					requests.append(video_request)

					var start_i: int = 0 if split_audio else 1
					for i: int in range(start_i, file.audio_streams.size()):
						var audio_track_idx: int = track_idx + 1 + (i - start_i)
						var audio_request: RequestClipAdd = RequestClipAdd.new()
						audio_request.file = file
						audio_request.track = audio_track_idx
						audio_request.frame = target_frame
						audio_request.group_id = group_id
						audio_request.audio_index = file.audio_streams[i]
						audio_request.is_muted = (i != start_i)
						audio_request.type = EditorCore.Type.AUDIO
						requests.append(audio_request)
				else: requests.append(video_request)
				total_duration += file.duration
			ClipLogic.add(requests)
		Timeline.draggable = null
		Timeline.current_state = Timeline.State.SELECT


func draw_all() -> void:
	draw_track_lines.queue_redraw()
	draw_clips.queue_redraw()
	draw_preview.queue_redraw()
	draw_mode.queue_redraw()
	draw_playhead.queue_redraw()
	draw_box_selection.queue_redraw()
	draw_markers.queue_redraw()


func _redraw_on_change() -> void:
	if is_visible_in_tree():
		await get_tree().process_frame
		draw_all()
