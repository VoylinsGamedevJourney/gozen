extends PanelContainer
# TODO: Look into caching the waveform data (not an issue right now, but might become one)

signal zoom_changed(new_zoom: float)


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
enum MODE { SELECT, CUT }


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

const COLOR_AUDIO_WAVE: Color = Color(0.82, 0.82, 0.82, 0.6)

const STYLE_BOX_PREVIEW: StyleBox = preload("uid://dx2v44643hfvy")
const STYLE_BOXES: Dictionary[EditorCore.TYPE, Array] = {
	EditorCore.TYPE.IMAGE: [preload(Library.STYLE_BOX_CLIP_IMAGE_NORMAL), preload(Library.STYLE_BOX_CLIP_IMAGE_FOCUS)],
	EditorCore.TYPE.AUDIO: [preload(Library.STYLE_BOX_CLIP_AUDIO_NORMAL), preload(Library.STYLE_BOX_CLIP_AUDIO_FOCUS)],
	EditorCore.TYPE.VIDEO: [preload(Library.STYLE_BOX_CLIP_VIDEO_NORMAL), preload(Library.STYLE_BOX_CLIP_VIDEO_FOCUS)],
	EditorCore.TYPE.COLOR: [preload(Library.STYLE_BOX_CLIP_COLOR_NORMAL), preload(Library.STYLE_BOX_CLIP_COLOR_FOCUS)],
	EditorCore.TYPE.TEXT:  [preload(Library.STYLE_BOX_CLIP_TEXT_NORMAL), preload(Library.STYLE_BOX_CLIP_TEXT_FOCUS)],
}
const CLIP_TEXT_OFFSET: Vector2 = Vector2(5, 12)
const CLIP_TEXT_COLOR: Color = Color.WHITE

const COLOR_BOX_SELECT_FILL: Color = Color(0.65, 0.1, 0.95, 0.2)
const COLOR_BOX_SELECT_BORDER: Color = Color(0.65, 0.1, 0.95, 0.6)

const COLOR_CUT: Color = Color(1,0,0,0.6)
const COLOR_CUT_FADE: Color = Color(1,0,0,0.3)


@export var mode_panel: PanelContainer
@export var button_select: TextureButton
@export var button_cut: TextureButton


@onready var scroll: ScrollContainer = get_parent()

@onready var draw_track_lines: Control = $TrackLinesDraw
@onready var draw_clips: Control = $ClipsDraw
@onready var draw_mode: Control = $ModeDraw
@onready var draw_playhead: Control = $PlayheadDraw
@onready var draw_box_selection: Control = $BoxSelectionDraw
@onready var draw_markers: Control = $MarkersDrawn


var zoom: float = 1.0
var selected_clip_ids: PackedInt64Array = []

var mode: MODE = MODE.SELECT
var state: STATE = STATE.CURSOR_MODE_SELECT: set = set_state
var draggable: Draggable = null

var right_click_pos: Vector2i = Vector2i.ZERO
var right_click_clip: int = -1

var box_select_start: Vector2
var box_select_end: Vector2

var resize_target: ResizeTarget = null
var fade_target: FadeTarget = null
var pressed_clip: int = -1
var hovered_clip: int = -1

var waveform_style: int = Settings.get_audio_waveform_style()
var waveform_amp: float = Settings.get_audio_waveform_amp()



func _ready() -> void:
	Project.project_ready.connect(_project_ready)
	Settings.on_waveform_update.connect(update_waveform_data)
	Settings.on_show_time_mode_bar_changed.connect(_show_hide_mode_bar)
	EditorCore.frame_changed.connect(draw_track_lines.queue_redraw)
	EditorCore.frame_changed.connect(draw_playhead.queue_redraw)
	InputManager.switch_timeline_mode_select.connect(set_state.bind(STATE.CURSOR_MODE_SELECT))
	InputManager.switch_timeline_mode_cut.connect(set_state.bind(STATE.CURSOR_MODE_CUT))
	InputManager.switch_timeline_mode_select.connect(_on_select_mode_button_pressed)
	InputManager.switch_timeline_mode_cut.connect(_on_cut_mode_button_pressed)

	scroll.get_h_scroll_bar().value_changed.connect(draw_all.unbind(1))
	scroll.get_v_scroll_bar().value_changed.connect(draw_all.unbind(1))

	set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	_show_hide_mode_bar()


func _on_project_ready() -> void:
	Project.clips.updated.connect(draw_clips.queue_redraw)
	Project.clips.selected.connect(draw_clips.queue_redraw.unbind(1))


# --- Drawing functions ---

func _draw_track_lines(control: Control) -> void:
	for i: int in Project.data.tracks_is_muted.size() - 1:
		var y: int = TRACK_TOTAL_SIZE * (i + 1)
		control.draw_dashed_line(
				Vector2(0, y), Vector2(size.x, y),
				TRACK_LINE_COLOR, TRACK_LINE_WIDTH)


func _draw_clips(control: Control) -> void:
	var scroll_amount: float = scroll.scroll_horizontal
	var visible_start: int = floori(scroll_amount / zoom)
	var visible_end: int = ceili(visible_start + (size.x / zoom))

	var visible_clips: PackedInt64Array = _get_visible(visible_start, visible_end)
	var handled_clips: PackedInt64Array = []

	# - Previews
	if state in [STATE.MOVING, STATE.DROPPING] and draggable != null: # Moving + Dropping preview
		if draggable.is_file:
			var preview_size: Vector2 = Vector2(draggable.duration * zoom, TRACK_HEIGHT)
			var preview_position: Vector2 = Vector2(
					(draggable.frame_offset) * zoom,
					draggable.track_offset * TRACK_TOTAL_SIZE)
			control.draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
		else:
			for clip_id: int in draggable.ids:
				var clip_index: int = Project.clips.index_map[clip_id]
				var clip_duration: int = Project.data.clips_duration[clip_index]
				var clip_start: int = Project.data.clips_start[clip_index] + draggable.frame_offset
				var clip_track: int = Project.data.clips_track[clip_index] + draggable.track_offset
				var preview_position: Vector2 = Vector2(clip_start * zoom, clip_track * TRACK_TOTAL_SIZE)
				var preview_size: Vector2 = Vector2(clip_duration * zoom, TRACK_HEIGHT)

				control.draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
				if clip_id in visible_clips:
					handled_clips.append(clip_id)
	elif state == STATE.RESIZING: # Resizing preview
		var clip_index: int = Project.clips.index_map[resize_target.clip]
		var clip_track: int = Project.data.clips_track[clip_index]
		var clip_start: int = Project.data.clips_start[clip_index]
		var clip_duration: int = Project.data.clips_duration[clip_index]
		var draw_start: float = clip_start
		var draw_length: int = clip_duration

		if !resize_target.is_end:
			draw_start += resize_target.delta * zoom
			draw_length -= resize_target.delta
		else:
			draw_length += resize_target.delta

		var preview_position: Vector2 = Vector2(draw_start, clip_track * TRACK_TOTAL_SIZE)
		var preview_size: Vector2 = Vector2(draw_length * zoom, TRACK_HEIGHT)
		var box_pos: Vector2 = Vector2(clip_start * zoom, TRACK_TOTAL_SIZE * clip_track)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip_duration * zoom, TRACK_HEIGHT))

		# Drawing the original clip box and actual resized box.
		control.draw_rect(clip_rect, Color(1.0, 1.0, 1.0, 0.3))
		control.draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))

		if resize_target.clip in visible_clips:
			handled_clips.append(resize_target.clip)

	# - Clip blocks
	for clip_id: int in visible_clips:
		if clip_id in handled_clips:
			continue
		var clip_index: int = Project.clips.index_map[clip_id]
		var clip_type: int = Project.data.clips_type[clip_index]
		var clip_start: int = Project.data.clips_start[clip_index]
		var clip_begin: int = Project.data.clips_begin[clip_index]
		var clip_duration: int = Project.data.clips_duration[clip_index]
		var clip_track: int = Project.data.clips_track[clip_index]
		var clip_file: int = Project.data.clips_file[clip_index]
		var file_index: int = Project.files.index_map[clip_file]
		var box_type: int = 1 if clip_id in selected_clip_ids else 0
		var box_pos: Vector2 = Vector2(clip_start * zoom, TRACK_TOTAL_SIZE * clip_track)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip_duration * zoom, TRACK_HEIGHT))
		var text_pos_x: float = box_pos.x
		var clip_end_x: float = box_pos.x + (clip_duration * zoom)

		if text_pos_x < scroll_amount  and text_pos_x + CLIP_TEXT_OFFSET.x <= clip_end_x:
			text_pos_x = scroll_amount

		control.draw_style_box(STYLE_BOXES[clip_type][box_type] as StyleBox, clip_rect)

		# - Audio waves (Part of clip blocks)
		_draw_wave(Project.files.get_audio_wave(clip_file), clip_begin, clip_duration, clip_rect, control)

		# - Fading handles + amount
		var show_handles: bool = hovered_clip == clip_id or (state == STATE.FADING and fade_target.clip == clip_id)
		if clip_type in EditorCore.VISUAL_TYPES:
			_draw_fade_handles(clip_index, box_pos, true, show_handles, control) # Bottom.
		if clip_type in EditorCore.AUDIO_TYPES:
			_draw_fade_handles(clip_index, box_pos, false, show_handles, control) # Top

		# - Clip nickname
		if clip_rect.size.x > 20:
			control.draw_string(
					get_theme_default_font(),
					Vector2(text_pos_x, box_pos.y) + CLIP_TEXT_OFFSET,
					Project.data.files_nickname[file_index],
					HORIZONTAL_ALIGNMENT_LEFT,
					clip_end_x - text_pos_x - CLIP_TEXT_OFFSET.x,
					11, # Font size
					CLIP_TEXT_COLOR)


func _get_visible(start: int, end: int) -> PackedInt64Array:
	var data: PackedInt64Array = []
	for track_id: int in Project.data.tracks_is_muted.size():
		data.append_array(Project.tracks.get_clip_ids_in(track_id, start, end))
	return data


func _draw_wave(wave_data: PackedFloat32Array, begin: int, duration: int, rect: Rect2, control: Control) -> void:
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
		control.draw_rect(Rect2(base_x + (i * zoom), block_pos_y, zoom, block_height), COLOR_AUDIO_WAVE)


func _draw_fade_handles(clip_index: int, box_pos: Vector2, is_visual: bool, show_handles: bool, control: Control) -> void:
	var handle_radius: float = FADE_HANDLE_SIZE / 4.0
	var clip_duration: int = Project.data.clips_duration[clip_index]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var fade: Vector2 = clip_effects.fade_visual if is_visual else clip_effects.fade_audio

	var real_duration: float = (clip_duration * zoom)

	var clip_end_x: float = box_pos.x + real_duration
	var handle_y: float = box_pos.y
	if is_visual:
		handle_y += TRACK_HEIGHT - (handle_radius/2.0)
	else:
		handle_y += (handle_radius/2.0)

	fade.x = box_pos.x + (fade.x * zoom)
	fade.y = clip_end_x - (fade.y * zoom)

	if show_handles:
		handle_radius *= 2
		control.draw_circle(Vector2(fade.x, handle_y), handle_radius, FADE_HANDLE_COLOR) # Fade in handle
		control.draw_circle(Vector2(fade.y, handle_y), handle_radius, FADE_HANDLE_COLOR) # Fade out handle

	if fade.x > 0: # Draw line fade in (Top Left to Bottom Right/Handle)
		var start_y: float = box_pos.y if is_visual else (box_pos.y + TRACK_HEIGHT)
		control.draw_line(Vector2(box_pos.x, start_y), Vector2(fade.x, handle_y), FADE_LINE_COLOR, 1.0, true)
	if fade.y > 0: # Draw line fade out (Bottom Left/Handle to Top Right)
		var end_y: float = box_pos.y if is_visual else (box_pos.y + TRACK_HEIGHT)
		var from_pos: Vector2 = Vector2(fade.y, handle_y)
		var to_pos: Vector2 = Vector2(box_pos.x + real_duration, end_y)
		control.draw_line(from_pos, to_pos, FADE_LINE_COLOR, 1.0, true)


func _draw_mode(control: Control) -> void:
	var pos_x: float = get_local_mouse_position().x
	if mode == MODE.CUT:
		var fade_pos: float = pos_x + 1
		control.draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), COLOR_CUT)
		control.draw_line(Vector2(fade_pos, 0), Vector2(fade_pos, size.y), COLOR_CUT_FADE)


func _draw_playhead(control: Control) -> void:
	var playhead_pos: float = EditorCore.frame_nr * zoom
	control.draw_line(
			Vector2(playhead_pos, 0), Vector2(playhead_pos, size.y),
			PLAYHEAD_COLOR, PLAYHEAD_WIDTH)


func _draw_box_selection(control: Control) -> void:
	if state == STATE.BOX_SELECTING:
		var rect: Rect2 = Rect2(box_select_start, box_select_end - box_select_start).abs()
		control.draw_rect(rect, COLOR_BOX_SELECT_FILL)
		control.draw_rect(rect, COLOR_BOX_SELECT_BORDER, false, 1.0)


func _draw_markers(control: Control) -> void:
	for index: int in Project.data.markers_frame.size():
		var color: Color = Settings.get_marker_color(Project.data.markers_type[index])
		var frame_nr: int = Project.data.markers_frame[index]
		var pos_x: float = frame_nr * zoom
		if frame_nr == Project.markers.dragged_marker:
			pos_x = Project.markers.dragged_marker_offset

		control.draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), color * Color(1.0, 1.0, 1.0, 0.3), 1.0)
		pos_x += 1 # We want a double line with the second one slightly lighter.
		control.draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), color * Color(1.0, 1.0, 1.0, 0.1), 1.0)


# --- Notification handling ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if state == STATE.MOVING or state == STATE.DROPPING:
			state = STATE.CURSOR_MODE_SELECT
			draggable = null
			draw_clips.queue_redraw()


# --- Input handling ---

func _input(event: InputEvent) -> void:
	if !Project.is_loaded or get_window().gui_get_focus_owner() is LineEdit:
		return
	if event.is_action_pressed("delete_clips"):
		Project.clips.delete(selected_clip_ids)
	elif event.is_action_pressed("ripple_delete_clips"):
		Project.clips.ripple_delete(selected_clip_ids)
	elif event.is_action_pressed("cut_clips_at_playhead", false, true):
		cut_clips_at(EditorCore.frame_nr)
	elif event.is_action_pressed("cut_clips_at_mouse", false, true):
		cut_clips_at(get_frame_from_mouse())
	elif event.is_action_pressed("remove_empty_space"):
		var track_id: int = get_track_from_mouse()
		var frame_nr: int = get_frame_from_mouse()

		if !Project.tracks.get_clip_id_at(track_id, frame_nr):
			remove_empty_space_at(track_id, frame_nr)
	elif event.is_action_pressed("duplicate_selected_clips"):
		duplicate_selected_clips()
	elif event.is_action_pressed("ui_cancel"):
		selected_clip_ids = []
		_on_ui_cancel()


func _gui_input(event: InputEvent) -> void:
	if !Project.is_loaded:
		return

	if event is InputEventMouseButton:
		if event.is_action_pressed("timeline_zoom_in", false, true):
			zoom_at_mouse(ZOOM_STEP)
		elif event.is_action_pressed("timeline_zoom_out", false, true):
			zoom_at_mouse(1.0 / ZOOM_STEP)
		else:
			_on_gui_input_mouse_button(event as InputEventMouseButton)
			get_window().gui_release_focus()
	elif event is InputEventMouseMotion:
		_on_gui_input_mouse_motion(event as InputEventMouseMotion)


func _on_gui_input_mouse_button(event: InputEventMouseButton) -> void:
	if state == STATE.CURSOR_MODE_CUT:
		return cut_clip_at(_get_clip_on_mouse(), get_frame_from_mouse())
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
			draw_clips.queue_redraw()
		elif resize_target:
			state = STATE.RESIZING
			draw_clips.queue_redraw()
		elif pressed_clip == -1:
			if event.shift_pressed:
				state = STATE.BOX_SELECTING
				box_select_start = get_local_mouse_position()
				box_select_end = box_select_start
				draw_box_selection.queue_redraw()
			else:
				state = STATE.SCRUBBING
				move_playhead(get_frame_from_mouse())
		else:
			if event.shift_pressed:
				selected_clip_ids.append(pressed_clip)
			else:
				selected_clip_ids = [pressed_clip]
			draw_clips.queue_redraw()
			Project.clips.selected.emit(pressed_clip)
	elif event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var popup: PopupMenu = PopupManager.create_menu()
		right_click_clip = _get_clip_on_mouse()
		right_click_pos = Vector2i(get_track_from_mouse(), get_frame_from_mouse())

		if right_click_clip != -1:
			_add_popup_menu_items_clip(popup)
		else:
			popup.add_item(tr("Remove empty space"), POPUP_ACTION.REMOVE_EMPTY_SPACE)

		popup.add_item(tr("Add track"), POPUP_ACTION.TRACK_ADD)
		popup.add_item(tr("Remove track"), POPUP_ACTION.TRACK_REMOVE)
		popup.id_pressed.connect(_on_popup_menu_id_pressed)
		PopupManager.show_menu(popup)


func _on_gui_input_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		scroll.scroll_horizontal = max(scroll.scroll_horizontal - event.relative.x, 0.0)

	var clip_on_mouse: int = _get_clip_on_mouse()

	if clip_on_mouse != -1:
		var clip_id: int = Project.clips.index_map[clip_on_mouse]
		var file_id: int = Project.data.clips_file[clip_id]
		var file_index: int = Project.files.index_map[file_id]
		var clip_name: String = Project.data.files_nickname[file_index]

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
			elif clip_on_mouse != -1:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
		STATE.CURSOR_MODE_CUT: mouse_default_cursor_shape = Control.CURSOR_IBEAM # TODO: Create a better cursor shape
		STATE.FADING: _handle_fade_motion()
		STATE.SCRUBBING:
			if event.button_mask & MOUSE_BUTTON_LEFT:
				move_playhead(get_frame_from_mouse())
		STATE.BOX_SELECTING:
			box_select_end = get_local_mouse_position()
			mouse_default_cursor_shape = Control.CURSOR_CROSS
			draw_box_selection.queue_redraw()
		STATE.RESIZING:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
			_handle_resize_motion()


func _on_ui_cancel() -> void:
	pressed_clip = -1
	state = STATE.CURSOR_MODE_SELECT
	draggable = null
	fade_target = null
	resize_target = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	draw_all()


## Returns the clip_id.
func _get_clip_on_mouse() -> int:
	var track_id: int = get_track_from_mouse()
	if track_id < 0 or track_id >= Project.data.tracks_is_muted.size():
		return -1
	return Project.tracks.get_clip_id_at(track_id, get_frame_from_mouse())


func _get_resize_target() -> ResizeTarget:
	var track_id: int = get_track_from_mouse()
	if track_id < 0 or track_id >= Project.data.tracks_is_muted.size():
		return null
	var frame_pos: float = get_local_mouse_position().x
	var clip_on_mouse: int = _get_clip_on_mouse()
	if clip_on_mouse == -1:
		return null
	var index: int = Project.clips.index_map[clip_on_mouse]

	var duration: int = Project.data.clips_duration[index]
	if duration * zoom < RESIZE_CLIP_MIN_WIDTH:
		return null

	var visible_start: int = floori(scroll.scroll_horizontal / zoom)
	var visible_end: int = ceili((scroll.scroll_horizontal + size.x) / zoom)
	for clip_id: int in Project.tracks.get_clip_ids_in(track_id, visible_start, visible_end):
		var clip_index: int = Project.clips.index_map[clip_id]
		var clip_start: int = Project.data.clips_start[clip_index]
		var clip_duration: int = Project.data.clips_duration[clip_index]
		var start: float = clip_start * zoom
		var end: float = (clip_start + clip_duration) * zoom

		if abs(frame_pos - start) <= RESIZE_HANDLE_WIDTH:
			return ResizeTarget.new(clip_id, false, clip_start, clip_duration)
		elif abs(frame_pos - end) <= RESIZE_HANDLE_WIDTH:
			return ResizeTarget.new(clip_id, true, clip_start, clip_duration)
	return null


func _get_fade_target() -> FadeTarget:
	var track_id: int = get_track_from_mouse()
	if track_id < 0 or track_id >= Project.data.tracks_is_muted.size():
		return null
	var mouse_pos: Vector2 = get_local_mouse_position()
	var scroll_horizontal: float = scroll.scroll_horizontal
	var visible_start: int = floori(scroll_horizontal / zoom)
	var visible_end: int = ceili((scroll_horizontal + size.x) / zoom)

	for clip_id: int in Project.tracks.get_clip_ids_in(track_id, visible_start, visible_end):
		var clip_index: int = Project.clips.index_map[clip_id]
		var file_id: int = Project.data.clips_file[clip_index]
		var file_index: int = Project.files.index_map[file_id]
		var file_type: int = Project.data.files_type[file_index]
		var is_video: bool = file_type in EditorCore.VISUAL_TYPES
		var is_audio: bool = file_type in EditorCore.AUDIO_TYPES
		var clip_start: int = Project.data.clips_start[clip_index]
		var start_x: float = clip_start * zoom
		var end_x: float = (Project.data.clips_duration[clip_index] + start_x) * zoom
		var y_pos: float = Project.data.clips_track[clip_index] * TRACK_TOTAL_SIZE
		var tolerance: float = FADE_HANDLE_SIZE * 1.5 # Hitbox tolerance
		var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]

		# Check Video Handles (Bottom)
		if is_video:
			var fade: Vector2i = clip_effects.fade_visual
			var video_y_pos: float = y_pos + TRACK_HEIGHT - FADE_HANDLE_SIZE
			var in_pos: Vector2 = Vector2(start_x + (fade.x * zoom), video_y_pos)
			var out_pos: Vector2 = Vector2(end_x - (fade.y * zoom), video_y_pos)
			if mouse_pos.distance_to(in_pos) < tolerance:
				return FadeTarget.new(clip_id, false, true)
			if mouse_pos.distance_to(out_pos) < tolerance:
				return FadeTarget.new(clip_id, true, true)

		# Check Audio Handles (Top)
		if is_audio:
			var fade: Vector2i = clip_effects.fade_audio
			var audio_y_pos: float = y_pos + FADE_HANDLE_SIZE
			var in_pos: Vector2 = Vector2(start_x + (fade.x * zoom), audio_y_pos)
			var out_pos: Vector2 = Vector2(end_x - (fade.y * zoom), audio_y_pos)

			if mouse_pos.distance_to(in_pos) < tolerance:
				return FadeTarget.new(clip_id, false, false)
			if mouse_pos.distance_to(out_pos) < tolerance:
				return FadeTarget.new(clip_id, true, false)
	return null


func _project_ready() -> void:
	custom_minimum_size.y = TRACK_TOTAL_SIZE * Project.data.tracks_is_muted.size()
	Project.markers.added.connect(draw_markers.queue_redraw.unbind(1))
	Project.markers.updated.connect(draw_markers.queue_redraw.unbind(1))
	Project.markers.removed.connect(draw_markers.queue_redraw.unbind(1))
	Project.markers.moving.connect(draw_markers.queue_redraw)
	draw_all()


func _get_drag_data(_p: Vector2) -> Variant:
	if state != STATE.CURSOR_MODE_SELECT or pressed_clip == -1:
		return null

	var clicked_clip: int = pressed_clip
	if pressed_clip not in selected_clip_ids:
		selected_clip_ids = [pressed_clip]
		draw_clips.queue_redraw()

	var data: Draggable = Draggable.new()
	var clips: PackedInt64Array = selected_clip_ids.duplicate()
	var anchor_index: int = clips.find(clicked_clip)

	if anchor_index != -1:
		clips.remove_at(anchor_index)
		clips.insert(0, clicked_clip)

	var clip_index: int = Project.clips.index_map[clicked_clip]
	var clip_start: int = Project.data.clips_start[clip_index]
	data.ids = clips
	data.mouse_offset = get_frame_from_mouse() - clip_start
	state = STATE.MOVING
	return data


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is not Draggable:
		return false
	var result: bool
	draggable = data
	if draggable.is_file:
		state = STATE.DROPPING
		result = _can_drop_new_clips()
	else:
		result = _can_move_clips()

	draw_clips.queue_redraw()
	return result


func _can_drop_new_clips() -> bool:
	draggable.track_offset = get_track_from_mouse()
	var mouse_frame: int = get_frame_from_mouse()
	var target_frame: int = mouse_frame - draggable.mouse_offset
	var target_end: int = target_frame + draggable.duration
	var clip_at_pos: int = Project.tracks.get_clip_id_at(draggable.track_offset, target_frame)
	var clip_at_end: int = Project.tracks.get_clip_id_at(draggable.track_offset, target_end)
	var free_region: Vector2i

	if target_frame < 0:
		target_end += abs(target_frame)
		target_frame = 0

	if clip_at_pos == -1:
		free_region = Project.tracks.get_free_region(draggable.track_offset, target_frame)

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
	elif clip_at_end != -1:
		return false # Not possible to find space
	else:
		free_region = Project.tracks.get_free_region(draggable.track_offset, target_end)
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
	var anchor_clip_index: int = Project.clips.index_map[draggable.ids[0]]
	var mouse_track: int = get_track_from_mouse()
	var mouse_frame: int = get_frame_from_mouse()
	var target_start: int = mouse_frame - draggable.mouse_offset
	var track_difference: int = mouse_track - Project.data.clips_track[anchor_clip_index]
	var frame_difference: int = target_start - Project.data.clips_start[anchor_clip_index]

	var min_allowed_diff: int = -1000000000 # Effectively -Infinity
	var max_allowed_diff: int = 1000000000  # Effectively +Infinity

	for clip_id: int in draggable.ids:
		var clip_index: int = Project.clips.index_map[clip_id]
		var clip_start: int = Project.data.clips_start[clip_index]
		var clip_duration: int = Project.data.clips_duration[clip_index]
		var new_track: int = Project.data.clips_track[clip_index] + track_difference
		var middle_frame: int = clip_start + floori(clip_duration / 2.0)
		# First boundary check
		if new_track < 0 or new_track >= Project.data.tracks_is_muted.size():
			return false

		var free_region: Vector2i = Project.tracks.get_free_region(new_track, middle_frame + frame_difference, draggable.ids)
		if free_region == Vector2i(-1, -1):
			return false

		# Calculating clip constrains
		min_allowed_diff = max(min_allowed_diff, free_region.x - clip_start)
		max_allowed_diff = min(max_allowed_diff, free_region.y - clip_start - clip_duration)

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
	if data is not Draggable:
		return

	if state not in [STATE.DROPPING, STATE.MOVING]:
		return

	if draggable.is_file: # Creating new clips (ids are file ids!)
		var requests: Array[ClipRequest] = []
		var total_duration: int = 0

		for file_id: int in draggable.ids:
			var file_index: int = Project.files.index_map[file_id]
			var target_frame: int = draggable.frame_offset + total_duration
			requests.append(ClipRequest.add_request(file_id, draggable.track_offset, target_frame))
			total_duration += Project.data.files_duration[file_index]
		Project.clips.add(requests)
	else: # Moving clips
		var move_requests: Array[ClipRequest] = []
		for clip_id: int in draggable.ids:
			move_requests.append(ClipRequest.move_request(clip_id, draggable.track_offset, draggable.frame_offset))
		if not move_requests.is_empty():
			Project.clips.move(move_requests)
	draggable = null
	draw_clips.queue_redraw()


func _on_mouse_entered() -> void:
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_ui_cancel()
	draw_all()


func _on_mouse_exited() -> void:
	hovered_clip = -1
	draw_all()


func _commit_current_resize() -> void:
	if resize_target.delta != 0:
		Project.clips.resize([ClipRequest.resize_request(
				resize_target.clip,
				resize_target.delta if resize_target.is_end else resize_target.delta,
				resize_target.is_end)])
	resize_target = null
	draw_clips.queue_redraw()


func _commit_box_selection(is_ctrl_pressed: bool) -> void:
	var track_start: int = clampi(floori(box_select_start.y / TRACK_TOTAL_SIZE), 0, Project.data.tracks_is_muted.size())
	var track_end: int = clampi(floori(box_select_end.y / TRACK_TOTAL_SIZE), 0, Project.data.tracks_is_muted.size())
	var frame_start: int = floori(box_select_start.x / zoom)
	var frame_end: int = floori(box_select_end.x / zoom)
	var temp: int
	if not is_ctrl_pressed:
		selected_clip_ids.clear()

	if track_start > track_end:
		temp = track_start
		track_start = track_end
		track_end = temp
	if frame_start > frame_end:
		temp = frame_start
		frame_start = frame_end
		frame_end = temp

	for track_id: int in range(track_start, clamp(track_end + 1, 0, Project.data.tracks_is_muted.size())):
		for frame_index: int in Project.tracks.frames[track_id].size():
			var frame_nr: int = Project.tracks.frames[track_id][frame_index]
			if frame_nr > frame_end:
				break

			var clip_id: int = Project.tracks.clips[track_id].find(frame_index)
			if frame_nr > frame_start and frame_nr < frame_end:
				if clip_id not in selected_clip_ids:
					selected_clip_ids.append(clip_id)
				continue

			# We should also check if a clip ends inside the selection box.
			var clip_index: int = Project.clips.index_map[clip_id]
			var clip_duration: int = Project.data.clips_duration[clip_index]
			if frame_nr + clip_duration > frame_start:
				if clip_id not in selected_clip_ids:
					selected_clip_ids.append(clip_id)
	if selected_clip_ids.is_empty():
		Project.clips.selected.emit(-1)
	else:
		Project.clips.selected.emit(selected_clip_ids[-1])

	draw_box_selection.queue_redraw()
	draw_clips.queue_redraw()


func _handle_resize_motion() -> void:
	var clip_index: int = Project.clips.index_map[resize_target.clip]
	var clip_begin: int = Project.data.clips_begin[clip_index]
	var track: int = Project.data.clips_track[clip_index]
	var file_id: int = Project.data.clips_file[clip_index]
	var file_index: int = Project.files.index_map[file_id]
	var file_duration: int = Project.data.files_duration[file_index]
	var current_frame: int = get_frame_from_mouse()

	if resize_target.is_end: # Resizing end
		var new_duration: int = current_frame - resize_target.original_start
		var max_allowed_duration: int = file_duration - clip_begin

		if new_duration < 1:
			new_duration = 1
		if new_duration > max_allowed_duration:
			new_duration = max_allowed_duration

		# Collision detection
		var free_region: Vector2i = Project.tracks.get_free_region(
			track, resize_target.original_start + 1, [resize_target.clip])

		if (resize_target.original_start + new_duration) > free_region.y:
			new_duration = free_region.y - resize_target.original_start
		resize_target.delta = new_duration - resize_target.original_duration
	else: # Resizing beginning
		var new_start: int = current_frame
		var min_allowed_duration: int = resize_target.original_start - clip_begin

		if new_start > (resize_target.original_start + resize_target.original_duration - 1):
			new_start = (resize_target.original_start + resize_target.original_duration - 1)
		if new_start < min_allowed_duration:
			new_start = min_allowed_duration

		# Collision detection
		var free_region: Vector2i = Project.tracks.get_free_region(
				track,
				resize_target.original_start + resize_target.original_duration - 1,
				[resize_target.clip])

		if new_start < free_region.x:
			new_start = free_region.x
		resize_target.delta = new_start - resize_target.original_start
	draw_clips.queue_redraw()


func _handle_fade_motion() -> void:
	var mouse_x: float = get_local_mouse_position().x
	var clip_index: int = Project.clips.index_map[fade_target.clip]
	var clip_start: int = Project.data.clips_start[clip_index]
	var clip_duration: int = Project.data.clips_duration[clip_index] + clip_start
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var clip_fade_visual: Vector2i = clip_effects.fade_visual
	var clip_fade_audio: Vector2i = clip_effects.fade_audio
	var start_x: float = clip_start * zoom
	var end_x: float = (clip_start + clip_duration) * zoom
	var drag_frames: int = 0 # Convert pixel drag to frame amount

	if not fade_target.is_end: # Fade In
		drag_frames = floori((mouse_x - start_x) / zoom)
		drag_frames = clamp(drag_frames, 0, clip_duration / 2.0)

		if fade_target.is_visual:
			clip_fade_visual.x = drag_frames
		else:
			clip_fade_audio.x = drag_frames
	else: # Fade Out
		drag_frames = floori((end_x - mouse_x) / zoom)
		drag_frames = clamp(drag_frames, 0, clip_duration / 2.0)

		if fade_target.is_visual:
			clip_fade_visual.y = drag_frames
		else:
			clip_fade_audio.y = drag_frames

	draw_clips.queue_redraw()
	EditorCore.update_frame()


func _add_popup_menu_items_clip(popup: PopupMenu) -> void:
	if right_click_clip == -1:
		return
	var clip_index: int = Project.clips.index_map[right_click_clip]
	var file_id: int = Project.data.clips_file[clip_index]
	var file_index: int = Project.files.index_map[file_id]
	var clip_type: EditorCore.TYPE = Project.data.files_type[file_index] as EditorCore.TYPE
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	if right_click_clip not in selected_clip_ids:
		selected_clip_ids = [right_click_clip]
		Project.clips.selected.emit(right_click_clip)

	# TODO: Set icons and shortcuts
	popup.add_item(tr("Delete clip"), POPUP_ACTION.CLIP_DELETE)
	popup.add_item(tr("Cut clip"), POPUP_ACTION.CLIP_CUT)

	if clip_type == EditorCore.TYPE.VIDEO:
		popup.add_separator(tr("Video options"))
		popup.add_item(tr("Add clip only video isntance"), POPUP_ACTION.CLIP_VIDEO_ONLY)
		popup.add_item(tr("Clip audio-take-over"), POPUP_ACTION.CLIP_AUDIO_TAKE_OVER)
	if clip_effects.ato_id != -1: # Can only be not -1 if clip is video
		if clip_effects.ato_active:
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
	draw_all()


func _on_popup_action_clip_delete() -> void: Project.clips.delete(selected_clip_ids)
func _on_popup_action_clip_cut() -> void: cut_clips_at(right_click_pos.y)
func _on_popup_action_remove_empty_space() -> void: remove_empty_space_at(right_click_pos.x, right_click_pos.y)


func _on_popup_action_clip_ato() -> void:
	var popup: Control = PopupManager.get_popup(PopupManager.AUDIO_TAKE_OVER)
	@warning_ignore("unsafe_method_access") # NOTE: Audio take over doesn't have a class.
	popup.load_data(right_click_clip, false)


func _on_popup_action_clip_only_video() -> void:
	var clip_index: int = Project.clips.index_map[right_click_clip]
	var file_id: int = Project.data.clips_file[clip_index]
	Project.files.switch_clip_video_instance(file_id, right_click_clip)


func _on_popup_action_clip_ato_enable() -> void:
	Project.clips.set_ato_active(right_click_clip, true)


func _on_popup_action_clip_ato_disable() -> void:
	Project.clips.set_ato_active(right_click_clip, false)


func _on_popup_action_track_add() -> void:
	Project.tracks.add_track(right_click_pos.x)


func _on_popup_action_track_remove() -> void:
	Project.tracks.remove_track(right_click_pos.x)


func _show_hide_mode_bar(value: bool = Settings.get_show_time_mode_bar()) -> void:
	mode_panel.visible = value


func _on_select_mode_button_pressed() -> void:
	button_select.set_pressed_no_signal(true)
	mode = MODE.SELECT
	draw_mode.queue_redraw()


func _on_cut_mode_button_pressed() -> void:
	button_cut.set_pressed_no_signal(true)
	mode = MODE.CUT
	draw_mode.queue_redraw()


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
	draw_all()
	accept_event()


func get_frame_from_mouse() -> int:
	return floori(get_local_mouse_position().x / zoom)


func get_track_from_mouse() -> int:
	return clampi(floori(get_local_mouse_position().y / TRACK_TOTAL_SIZE), 0, Project.data.tracks_is_muted.size())


func move_playhead(frame_nr: int) -> void:
	EditorCore.set_frame(maxi(0, frame_nr))
	draw_playhead.queue_redraw()


func remove_empty_space_at(track_id: int, frame_nr: int) -> void:
	var clips: PackedInt64Array = Project.tracks.get_clips_after(track_id, frame_nr)
	var region: Vector2i = Project.tracks.get_free_region(track_id, frame_nr)
	var empty_size: int = region.y - region.x
	var move_requests: Array[ClipRequest] = []

	for clip_id: int in clips:
		move_requests.append(ClipRequest.move_request(clip_id, 0, -empty_size))
	if !move_requests.is_empty():
		Project.clips.move(move_requests)


func cut_clip_at(clip_id: int, frame_pos: int) -> void:
	var clip_index: int = Project.clips.index_map[clip_id]
	var clip_start: int = Project.data.clips_start[clip_index]
	var clip_end: int = Project.data.clips_duration[clip_index] + clip_start
	if clip_start <= frame_pos and clip_end >= frame_pos:
		Project.clips.cut([ClipRequest.cut_request(clip_id, frame_pos - clip_start)])
	draw_clips.queue_redraw()


func cut_clips_at(frame_pos: int) -> void:
	# Check if any of the clips in the tracks is in selected clips
	# if there are selected clips present, we only cut the selected ones
	var requests: Array[ClipRequest] = []

	# Checking if we only want selected clips to be cut.
	for clip_id: int in selected_clip_ids:
		var clip_index: int = Project.clips.index_map[clip_id]
		var clip_start: int = Project.data.clips_start[clip_index]
		var clip_end: int = Project.data.clips_duration[clip_index] + clip_start

		if clip_start < frame_pos and clip_end > frame_pos:
			requests.append(ClipRequest.cut_request(clip_id, frame_pos - clip_start))

	if !requests.is_empty():
		Project.clips.cut(requests)
		return draw_clips.queue_redraw()

	# No selected clips present so cutting all possible clips
	for track_id: int in Project.data.tracks_is_muted.size():
		var clip_id: int = Project.tracks.get_clip_id_at(track_id, frame_pos)
		if clip_id == -1:
			continue
		var clip_index: int = Project.clips.index_map[clip_id]
		var clip_start: int = Project.data.clips_start[clip_index]
		var clip_end: int = Project.data.clips_duration[clip_index] + clip_start

		if clip_start < frame_pos and clip_end > frame_pos:
			requests.append(ClipRequest.cut_request(clip_id, frame_pos - clip_start))

	Project.clips.cut(requests)
	draw_clips.queue_redraw()


func duplicate_selected_clips() -> void:
	if selected_clip_ids.is_empty():
		return

	var requests: Array[ClipRequest] = []
	for clip_id: int in selected_clip_ids:
		var clip_index: int = Project.clips.index_map[clip_id]
		if clip_index == -1:
			return # Invalid clip id
		var clip_start: int = Project.data.clips_start[clip_index]
		var clip_duration: int = Project.data.clips_duration[clip_index]
		var clip_track: int = Project.data.clips_track[clip_index]
		var target_frame: int = clip_start + clip_duration
		var free_region: Vector2i = Project.tracks.get_free_region(clip_track, target_frame)

		if free_region.y - target_frame >= clip_duration:
			var file_id: int = Project.data.clips_file[clip_index]
			requests.append(ClipRequest.add_request(file_id, clip_track, target_frame))
	if not requests.is_empty():
		Project.clips.add(requests)


func set_state(new_state: STATE) -> void:
	state = new_state


func draw_all() -> void:
	draw_track_lines.queue_redraw()
	draw_clips.queue_redraw()
	draw_mode.queue_redraw()
	draw_playhead.queue_redraw()
	draw_box_selection.queue_redraw()
	draw_markers.queue_redraw()


func update_waveform_data() -> void:
	waveform_style = Settings.get_audio_waveform_style()
	waveform_amp = Settings.get_audio_waveform_amp()
	draw_clips.queue_redraw()



class ResizeTarget:
	var clip: int
	var is_end: bool
	var original_start: int = 0
	var original_duration: int = 0
	var delta: int = 0

	func _init(clip_id: int, _is_end: bool, start: int, duration: int) -> void:
		clip = clip_id
		is_end = _is_end
		original_start = start
		original_duration = duration



class FadeTarget:
	var clip: int
	var is_end: bool
	var is_visual: bool

	func _init(clip_id: int, _is_end: bool, _is_visual: bool) -> void:
		clip = clip_id
		is_end = _is_end
		is_visual = _is_visual
