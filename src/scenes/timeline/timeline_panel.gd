extends PanelContainer


signal zoom_changed(new_zoom: float)


enum POPUP_ACTION {
	# Clip options
	CLIP_DELETE,
	CLIP_CUT,
	CLIP_AUDIO_TAKE_OVER,
	# Track options
	REMOVE_EMPTY_SPACE,
	TRACK_ADD,
	TRACK_REMOVE }
enum STATE {
	CURSOR_MODE_SELECT,
	CURSOR_MODE_CUT,
	SCRUBBING,
	MOVING,
	DROPPING,
	RESIZING,
	SPEEDING,
	FADING,
	BOX_SELECTING }
enum MODE { SELECT, CUT }


const TRACK_LINE_WIDTH: int = 1
const TRACK_LINE_COLOR: Color = Color.DIM_GRAY

const RESIZE_HANDLE_WIDTH: int = 5
const RESIZE_CLIP_MIN_WIDTH: float = 14

const FADE_HANDLE_SIZE: float = 3.5
const FADE_HANDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.7)
const FADE_LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)
const FADE_AREA_COLOR: Color = Color(0.0, 0.0, 0.0, 0.3)

const PLAYHEAD_WIDTH: int = 2
const PLAYHEAD_COLOR: Color = Color(0.4, 0.4, 0.4)

const ZOOM_MIN: float = 0.01
const ZOOM_MAX: float = 200.0
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
@onready var draw_preview: Control = $PreviewDraw
@onready var draw_mode: Control = $ModeDraw
@onready var draw_playhead: Control = $PlayheadDraw
@onready var draw_box_selection: Control = $BoxSelectionDraw
@onready var draw_markers: Control = $MarkersDrawn


var zoom: float = 1.0
var selected_clips: Array[ClipData] = []

var mode: MODE = MODE.SELECT
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

var waveform_style: int = Settings.get_audio_waveform_style()
var waveform_amp: float = Settings.get_audio_waveform_amp()

var track_height: float = 30
var track_total_size: float = track_height + TRACK_LINE_WIDTH

var _update_clips: bool = true
var _drop_valid: bool = false
var _scrub_frame: int = -1
var _last_scrub_time: int = 0



func _ready() -> void:
	Project.project_ready.connect(_project_ready)
	Settings.on_waveform_update.connect(update_waveform_data)
	Settings.on_show_time_mode_bar_changed.connect(_show_hide_mode_bar)
	Settings.on_track_height_changed.connect(_update_track_height)
	EditorCore.frame_changed.connect(draw_track_lines.queue_redraw)
	EditorCore.frame_changed.connect(draw_playhead.queue_redraw)
	InputManager.switch_timeline_mode_select.connect(set_state.bind(STATE.CURSOR_MODE_SELECT))
	InputManager.switch_timeline_mode_cut.connect(set_state.bind(STATE.CURSOR_MODE_CUT))
	InputManager.switch_timeline_mode_select.connect(_on_select_mode_button_pressed)
	InputManager.switch_timeline_mode_cut.connect(_on_cut_mode_button_pressed)

	var markers_redraw: Callable = draw_markers.queue_redraw
	MarkerLogic.added.connect(markers_redraw.unbind(1))
	MarkerLogic.removed.connect(markers_redraw.unbind(1))
	MarkerLogic.updated.connect(markers_redraw.unbind(1))
	MarkerLogic.moving.connect(markers_redraw)

	scroll.get_h_scroll_bar().value_changed.connect(draw_all.unbind(1))
	scroll.get_v_scroll_bar().value_changed.connect(draw_all.unbind(1))

	set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	_show_hide_mode_bar()


func _process(_delta: float) -> void:
	if _scrub_frame != -1:
		var current_time: int = Time.get_ticks_msec()
		if current_time - _last_scrub_time > 40:
			move_playhead(_scrub_frame)
			_scrub_frame = -1
			_last_scrub_time = current_time


# --- Drawing functions ---

func _draw_track_lines(control: Control) -> void:
	var scroll_start: float = scroll.scroll_horizontal
	var scroll_end: float = scroll_start + scroll.size.x
	for i: int in TrackLogic.tracks.size() - 1:
		var y_pos: float = track_total_size * (i + 1)
		control.draw_dashed_line(
				Vector2(scroll_start, y_pos), Vector2(scroll_end, y_pos),
				TRACK_LINE_COLOR, TRACK_LINE_WIDTH)


func _draw_clips(control: Control) -> void:
	var scroll_amount: float = scroll.scroll_horizontal
	var visible_start: int = floori(scroll_amount / zoom)
	var visible_end: int = ceili(visible_start + (scroll.size.x / zoom))

	var visible_clips: Array[ClipData] = _get_visible(visible_start, visible_end)
	var handled_clips: Array[ClipData] = []

	# Remove preview from visible clips.
	if draggable != null and !draggable.is_file and state in [STATE.MOVING, STATE.DROPPING, STATE.RESIZING]:
		for clip_id: int in draggable.ids:
			var clip: ClipData = ClipLogic.clips.get(clip_id)
			if clip:
				visible_clips.erase(clip)

	# - Clip blocks
	for clip: ClipData in visible_clips:
		if clip in handled_clips:
			continue
		var box_type: int = 1 if clip in selected_clips else 0
		var box_pos: Vector2 = Vector2(clip.start * zoom, track_total_size * clip.track)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip.duration * zoom, track_height))
		var text_pos_x: float = box_pos.x
		var clip_end_x: float = box_pos.x + (clip.duration * zoom)

		if text_pos_x < scroll_amount  and text_pos_x + CLIP_TEXT_OFFSET.x <= clip_end_x:
			text_pos_x = scroll_amount

		var visible_rect: Rect2 = Rect2(scroll_amount - 100, box_pos.y, scroll.size.x + 200, track_height)
		var final_rect: Rect2 = clip_rect.intersection(visible_rect)
		if final_rect.size.x > 0:
			control.draw_style_box(STYLE_BOXES[clip.type][box_type] as StyleBox, final_rect)

		# - Audio waves (Part of clip blocks)
		var audio_wave: PackedFloat32Array = FileLogic.audio_wave.get(clip.file, [])
		if audio_wave:
			_draw_wave(audio_wave, clip.begin, clip.duration, clip_rect, control, clip.speed)

		# - Fading handles + amount
		var show_handles: bool = hovered_clip == clip or (state == STATE.FADING and fade_target.clip == clip)
		if clip.type in EditorCore.VISUAL_TYPES:
			_draw_fade_handles(clip, box_pos, true, show_handles, control) # Bottom.
		if clip.type in EditorCore.AUDIO_TYPES:
			_draw_fade_handles(clip, box_pos, false, show_handles, control) # Top.

		# - Clip nickname
		if clip_rect.size.x > 20:
			var speed: float = clip.speed
			var text: String = FileLogic.files[clip.file].nickname
			if not is_equal_approx(speed, 1.0):
				text += "  [%d%%]" % int(speed * 100)

			control.draw_string(
					get_theme_default_font(),
					Vector2(text_pos_x, box_pos.y) + CLIP_TEXT_OFFSET,
					text,
					HORIZONTAL_ALIGNMENT_LEFT,
					clip_end_x - text_pos_x - CLIP_TEXT_OFFSET.x,
					11, # Font size
					CLIP_TEXT_COLOR)


func _get_visible(start: int, end: int) -> Array[ClipData]:
	var data: Array[ClipData] = []
	for track_id: int in TrackLogic.tracks.size():
		data.append_array(TrackLogic.get_clips_in_range(track_id, start, end))
	return data


func _draw_wave(wave_data: PackedFloat32Array, begin: int, duration: int, rect: Rect2, control: Control, speed: float) -> void:
	if wave_data.is_empty():
		return
	var display_duration: int = duration
	var display_begin_offset: int = begin
	var height: float = rect.size.y
	var base_x: float = rect.position.x
	var base_y: float = rect.position.y
	var step: int = maxi(1, int(2.0 / zoom))

	var start_i: int = 0
	var end_i: int = display_duration

	var scroll_start: float = scroll.scroll_horizontal
	var scroll_end: float = scroll_start + scroll.size.x

	if base_x < scroll_start:
		start_i = floori((scroll_start - base_x) / zoom)
	if base_x + (display_duration * zoom) > scroll_end:
		end_i = ceili((scroll_end - base_x) / zoom)

	start_i -= start_i % step

	for i: int in range(start_i, end_i, step):
		var wave_index: int = display_begin_offset + int(i * speed)
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
		control.draw_rect(Rect2(base_x + (i * zoom), block_pos_y, zoom * step, block_height), COLOR_AUDIO_WAVE)


func _draw_preview(control: Control) -> void:
	if state in [STATE.MOVING, STATE.DROPPING] and draggable != null:
		if !_drop_valid:
			return
		if draggable.is_file:
			var preview_size: Vector2 = Vector2(draggable.duration * zoom, track_height)
			var preview_position: Vector2 = Vector2(
					(draggable.frame_offset) * zoom,
					draggable.track_offset * track_total_size)
			control.draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
		else:
			for clip_id: int in draggable.ids:
				var clip: ClipData = ClipLogic.clips[clip_id]
				var preview_position: Vector2 = Vector2(
						(clip.start + draggable.frame_offset) * zoom,
						(clip.track + draggable.track_offset) * track_total_size)
				var preview_size: Vector2 = Vector2(clip.duration * zoom, track_height)
				control.draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
	elif state == STATE.RESIZING or state == STATE.SPEEDING:
		var clip: ClipData = resize_target.clip
		var draw_start: float = clip.start
		var draw_length: int = clip.duration
		if !resize_target.is_end:
			draw_start += resize_target.delta
			draw_length -= resize_target.delta
		else:
			draw_length += resize_target.delta

		var preview_position: Vector2 = Vector2(draw_start * zoom, clip.track * track_total_size)
		var preview_size: Vector2 = Vector2(draw_length * zoom, track_height)
		var box_pos: Vector2 = Vector2(clip.start * zoom, track_total_size * clip.track)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip.duration * zoom, track_height))
		var color: Color = Color(1.0, 1.0, 1.0, 0.3) # Resizing color.
		if state == STATE.SPEEDING:
			color = Color(1.0, 0.5, 0.0, 0.3) # Have different color on speeding.

		# Drawing the original clip box and actual resized box.
		control.draw_rect(clip_rect, color)
		control.draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))


func _draw_fade_handles(clip: ClipData, box_pos: Vector2, is_visual: bool, show_handles: bool, control: Control) -> void:
	const BORDER_OFFSET: int = 2
	var duration: float = (clip.duration * zoom)
	var fade: Vector2 = clip.effects.fade_visual if is_visual else clip.effects.fade_audio

	# Getting the edge points of the clip.
	var fade_in_pts: PackedVector2Array = [
			box_pos + Vector2(BORDER_OFFSET, BORDER_OFFSET),
			box_pos + Vector2(BORDER_OFFSET, track_height - BORDER_OFFSET)]
	var fade_out_pts: PackedVector2Array = [
			box_pos + Vector2(duration - BORDER_OFFSET, BORDER_OFFSET),
			box_pos + Vector2(duration - BORDER_OFFSET, track_height - BORDER_OFFSET)]

	# Adding the handle point.
	var handle_offset: float = (FADE_HANDLE_SIZE / 2.0)
	if is_visual:
		fade_in_pts.append(box_pos + Vector2(fade.x * zoom, track_height - handle_offset))
		fade_out_pts.append(box_pos + Vector2(duration - (fade.y * zoom), track_height - handle_offset))
	else:
		fade_in_pts.append(box_pos + Vector2(fade.x * zoom, handle_offset))
		fade_out_pts.append(box_pos + Vector2(duration - (fade.y * zoom), handle_offset))

	# Draw background and lines. (if fade present)
	if fade.x > 0: # Draw line fade in.
		control.draw_colored_polygon(fade_in_pts, FADE_AREA_COLOR)
		control.draw_line(fade_in_pts[2], fade_in_pts[0 if is_visual else 1], FADE_LINE_COLOR, 1.0, true)
	if fade.y > 0: # Draw line fade out.
		control.draw_colored_polygon(fade_out_pts, FADE_AREA_COLOR)
		control.draw_line(fade_out_pts[2], fade_out_pts[0 if is_visual else 1], FADE_LINE_COLOR, 1.0, true)

	# Draw handles.
	if show_handles:
		control.draw_circle(fade_in_pts[2], FADE_HANDLE_SIZE, FADE_HANDLE_COLOR) # Fade in handle
		control.draw_circle(fade_out_pts[2], FADE_HANDLE_SIZE, FADE_HANDLE_COLOR) # Fade out handle


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
	var scroll_start: float = scroll.scroll_horizontal
	var scroll_end: float = scroll_start + scroll.size.x

	var dragged_marker: MarkerData = MarkerLogic.dragged_marker
	for marker: MarkerData in Project.data.markers:
		var frame_nr: int = marker.frame_nr
		var color: Color = Settings.get_marker_color(marker.type)
		var pos_x: float = frame_nr * zoom
		if dragged_marker and frame_nr == dragged_marker.frame_nr:
			pos_x = MarkerLogic.dragged_marker_offset

		if pos_x < scroll_start - 10 or pos_x > scroll_end + 10:
			continue

		control.draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), color * Color(1.0, 1.0, 1.0, 0.3), 1.0)
		pos_x += 1 # We want a double line with the second one slightly lighter.
		control.draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), color * Color(1.0, 1.0, 1.0, 0.1), 1.0)


# --- Notification handling ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and state in [STATE.MOVING, STATE.DROPPING]:
		state = STATE.CURSOR_MODE_SELECT
		draggable = null
		draw_clips.queue_redraw()
		draw_preview.queue_redraw()


# --- Input handling ---

func _unhandled_input(event: InputEvent) -> void:
	if !Project.is_loaded or get_window().gui_get_focus_owner() is LineEdit:
		return

	if event.is_action_pressed("cut_clips_at_playhead", false, true):
		cut_clips_at(EditorCore.frame_nr)
	elif event.is_action_pressed("ui_cancel"):
		if !PopupManager._open_popups.is_empty() or state in[STATE.MOVING, STATE.DROPPING]:
			return
		selected_clips =[]
		_on_ui_cancel()

	if scroll.get_global_rect().has_point(get_global_mouse_position()):
		if event.is_action_pressed("delete_clips"):
			ClipLogic.delete(selected_clips)
		elif event.is_action_pressed("ripple_delete_clips"):
			ClipLogic.ripple_delete(selected_clips)
		elif event.is_action_pressed("duplicate_selected_clips"):
			duplicate_selected_clips()
		elif event.is_action_pressed("cut_clips_at_mouse", false, true):
			cut_clips_at(get_frame_from_mouse())
		elif event.is_action_pressed("remove_empty_space"):
			var track_id: int = get_track_from_mouse()
			var frame_nr: int = get_frame_from_mouse()
			if !TrackLogic.get_clip_at_overlap(track_id, frame_nr):
				remove_empty_space_at(track_id, frame_nr)


func _gui_input(event: InputEvent) -> void:
	if !Project.is_loaded:
		return
	elif event is InputEventMouseButton:
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
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			var target: ClipData = _get_clip_on_mouse()
			if target:
				cut_clip_at(target, get_frame_from_mouse())
		return
	elif event.is_released():
		match state:
			STATE.RESIZING: _commit_current_resize()
			STATE.SPEEDING: _commit_current_resize()
			STATE.BOX_SELECTING: _commit_box_selection(event.ctrl_pressed)
			STATE.SCRUBBING:
				if _scrub_frame != -1:
					move_playhead(_scrub_frame)
					_scrub_frame = -1
		_on_ui_cancel()

	if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if clip is pressed or not.
		state = STATE.CURSOR_MODE_SELECT
		pressed_clip = _get_clip_on_mouse()
		resize_target = _get_resize_target()
		fade_target = _get_fade_target()

		if event.double_click and !pressed_clip: # Remove empty space.
			var mod: int = Settings.get_delete_empty_modifier()
			var valid: bool = false
			if mod == KEY_NONE:
				valid = true
			elif mod == KEY_CTRL and event.ctrl_pressed:
				valid = true
			elif mod == KEY_SHIFT and event.shift_pressed:
				valid = true
			if valid:
				remove_empty_space_at(get_track_from_mouse(), get_frame_from_mouse())
				return

		if fade_target:
			state = STATE.FADING
			draw_clips.queue_redraw()
		elif resize_target:
			state = STATE.SPEEDING if event.ctrl_pressed else STATE.RESIZING
			draw_clips.queue_redraw()
		elif !pressed_clip:
			if event.shift_pressed:
				state = STATE.BOX_SELECTING
				box_select_start = get_local_mouse_position()
				box_select_end = box_select_start
				draw_box_selection.queue_redraw()
			else:
				state = STATE.SCRUBBING
				_scrub_frame = get_frame_from_mouse()
		else:
			if !event.shift_pressed:
				selected_clips = [pressed_clip]
			elif !selected_clips.has(pressed_clip):
				selected_clips.append(pressed_clip)
			draw_clips.queue_redraw()
			ClipLogic.selected.emit(pressed_clip)
	elif event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var popup: PopupMenu = PopupManager.create_menu()
		right_click_clip = _get_clip_on_mouse()
		right_click_pos = Vector2i(get_track_from_mouse(), get_frame_from_mouse())

		if right_click_clip:
			_add_popup_menu_items_clip(popup)
		else:
			popup.add_item(tr("Remove empty space"), POPUP_ACTION.REMOVE_EMPTY_SPACE)

		popup.add_item(tr("Add track"), POPUP_ACTION.TRACK_ADD)
		if TrackLogic.tracks.size() != 1:
			popup.add_item(tr("Remove track"), POPUP_ACTION.TRACK_REMOVE)
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
		if hovered_clip != clip_on_mouse:
			hovered_clip = clip_on_mouse
			draw_clips.queue_redraw()
	elif tooltip_text != "" or state != STATE.CURSOR_MODE_SELECT:
		tooltip_text = ""

	match state:
		STATE.CURSOR_MODE_SELECT:
			if _get_fade_target() != null:
				mouse_default_cursor_shape = Control.CURSOR_CROSS
			elif _get_resize_target() != null:
				mouse_default_cursor_shape = Control. CURSOR_HSIZE
			elif clip_on_mouse:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
		STATE.CURSOR_MODE_CUT:
			mouse_default_cursor_shape = Control.CURSOR_IBEAM # TODO: Create a better cursor shape
			draw_mode.queue_redraw()
		STATE.FADING:
			_handle_fade_motion()
		STATE.SCRUBBING:
			if event.button_mask & MOUSE_BUTTON_LEFT:
				_scrub_frame = get_frame_from_mouse()
		STATE.BOX_SELECTING:
			box_select_end = get_local_mouse_position()
			mouse_default_cursor_shape = Control.CURSOR_CROSS
			draw_box_selection.queue_redraw()
		STATE.RESIZING:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
			_handle_resize_motion()
			draw_preview.queue_redraw()
		STATE.SPEEDING:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
			_handle_resize_motion() # We re-use resize logic.
			draw_preview.queue_redraw()


func _on_ui_cancel() -> void:
	pressed_clip = null
	hovered_clip = null
	state = STATE.CURSOR_MODE_SELECT
	draggable = null
	fade_target = null
	resize_target = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	draw_all()


## Returns the clip.
func _get_clip_on_mouse() -> ClipData:
	return TrackLogic.get_clip_at_overlap(get_track_from_mouse(), get_frame_from_mouse())


func _get_resize_target() -> ResizeTarget:
	var track: int = get_track_from_mouse()
	var mouse_pos: float = get_local_mouse_position().x
	var visible_start: int = floori(scroll.scroll_horizontal / zoom)
	var visible_end: int = ceili((scroll.scroll_horizontal + scroll.size.x) / zoom)
	var best_target: ResizeTarget = null
	var min_distance: float = RESIZE_HANDLE_WIDTH + 1.0
	for clip: ClipData in TrackLogic.get_clips_in_range(track, visible_start, visible_end):
		if (clip.duration * zoom) < RESIZE_CLIP_MIN_WIDTH:
			continue
		var start_x: float = clip.start * zoom
		var end_x: float = clip.end * zoom
		var start_distance: float = abs(mouse_pos - start_x)
		var end_distance: float = abs(mouse_pos - end_x)
		if start_distance <= RESIZE_HANDLE_WIDTH:
			if start_distance < min_distance or (start_distance == min_distance and mouse_pos >= start_x):
				min_distance = start_distance
				best_target = ResizeTarget.new(clip, false, clip.start, clip.duration)
		if end_distance <= RESIZE_HANDLE_WIDTH:
			if end_distance < min_distance or (end_distance == min_distance and mouse_pos <= end_x):
				min_distance = end_distance
				best_target = ResizeTarget.new(clip, true, clip.start, clip.duration)
	return best_target


func _get_fade_target() -> FadeTarget:
	var track_id: int = get_track_from_mouse()
	var mouse_pos: Vector2 = get_local_mouse_position()
	var scroll_horizontal: float = scroll.scroll_horizontal
	var visible_start: int = floori(scroll_horizontal / zoom)
	var visible_end: int = ceili((scroll_horizontal + scroll.size.x) / zoom)

	for clip: ClipData in TrackLogic.get_clips_in_range(track_id, visible_start, visible_end):
		var start_x: float = clip.start * zoom
		var end_x: float = clip.end * zoom
		var y_pos: float = clip.track * track_total_size

		# Check Video Handles (Bottom).
		if clip.type in EditorCore.VISUAL_TYPES:
			var fade: Vector2i = clip.effects.fade_visual * zoom
			var video_y_pos: float = y_pos + track_height - (FADE_HANDLE_SIZE / 2.0)
			if mouse_pos.distance_to(Vector2(start_x + fade.x, video_y_pos)) < FADE_HANDLE_SIZE:
				return FadeTarget.new(clip, false, true)
			if mouse_pos.distance_to(Vector2(end_x - fade.y, video_y_pos)) < FADE_HANDLE_SIZE:
				return FadeTarget.new(clip, true, true)

		# Check Audio Handles (Top).
		if clip.type in EditorCore.AUDIO_TYPES:
			var fade: Vector2i = clip.effects.fade_audio * zoom
			var audio_y_pos: float = y_pos + (FADE_HANDLE_SIZE / 2.0)
			if mouse_pos.distance_to(Vector2(start_x + fade.x, audio_y_pos)) < FADE_HANDLE_SIZE:
				return FadeTarget.new(clip, false, false)
			if mouse_pos.distance_to(Vector2(end_x - fade.y, audio_y_pos)) < FADE_HANDLE_SIZE:
				return FadeTarget.new(clip, true, false)
	return null


func _project_ready() -> void:
	ClipLogic.added.connect(draw_clips.queue_redraw.unbind(1))
	ClipLogic.deleted.connect(_on_clip_deleted)
	ClipLogic.updated.connect(draw_clips.queue_redraw)
	TrackLogic.updated.connect(_on_tracks_updated)
	_update_track_height(Settings.get_track_height())
	draw_all()


func _get_drag_data(_p: Vector2) -> Variant:
	if state != STATE.CURSOR_MODE_SELECT or !pressed_clip:
		return null
	if pressed_clip not in selected_clips:
		selected_clips = [pressed_clip]
		draw_clips.queue_redraw()

	var data: Draggable = Draggable.new()
	var clips: Array[ClipData] = selected_clips.duplicate()
	var anchor_index: int = clips.find(pressed_clip)
	if anchor_index != -1:
		clips.remove_at(anchor_index)
		clips.insert(0, pressed_clip)
	for clip: ClipData in clips:
		data.ids.append(clip.id)
	data.mouse_offset = get_frame_from_mouse() - pressed_clip.start
	state = STATE.MOVING
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
	draggable = data
	if draggable.is_file:
		state = STATE.DROPPING
		result = _can_drop_new_clips()
	else:
		state = STATE.MOVING
		result = _can_move_clips()
		draw_clips.queue_redraw()

	if _update_clips:
		draw_clips.queue_redraw()
		_update_clips = false
	elif !result:
		draw_clips.queue_redraw()
		_update_clips = true
	_drop_valid = result
	draw_preview.queue_redraw()
	return result


func _can_drop_new_clips() -> bool:
	draggable.track_offset = get_track_from_mouse()
	var mouse_frame: int = get_frame_from_mouse()
	var target_frame: int = mouse_frame - draggable.mouse_offset
	var target_end: int = target_frame + draggable.duration
	var clip_at_pos: ClipData = TrackLogic.get_clip_at_overlap(draggable.track_offset, target_frame)
	var clip_at_end: ClipData = TrackLogic.get_clip_at_overlap(draggable.track_offset, target_end)
	var free_region: Vector2i

	if target_frame < 0:
		target_end += abs(target_frame)
		target_frame = 0

	if !clip_at_pos:
		free_region = TrackLogic.get_free_region(draggable.track_offset, target_frame)

		if free_region.y > target_end:
			draggable.frame_offset = target_frame
			return true # Space fully available from target_frame to target_end.
		elif free_region.y - free_region.x < draggable.duration:
			return false # No space.

		# Check what space is needed on right side and if within snapping
		# Possible with snapping so checking if enough space on left side.
		var distance_necessary: int = target_end - free_region.y

		if distance_necessary > SNAPPING or target_frame - free_region.x < distance_necessary:
			return false

		draggable.frame_offset = target_frame - distance_necessary
		return true
	elif !clip_at_end:
		free_region = TrackLogic.get_free_region(draggable.track_offset, target_end)
		if free_region.y - free_region.x < draggable.duration:
			return false # No space

		# Check what space is needed on left side and if within snapping.
		# Possible with snapping so checking if enough space on left side.
		var distance_necessary: int = target_frame - free_region.x
		if distance_necessary > SNAPPING or target_end - free_region.y > distance_necessary:
			return false

		draggable.frame_offset = target_frame - distance_necessary
		return true
	return false # Not possible to find space.


func _can_move_clips() -> bool:
	var anchor_clip: ClipData = ClipLogic.clips[draggable.ids[0]]
	var mouse_track: int = get_track_from_mouse()
	var mouse_frame: int = get_frame_from_mouse()
	var target_start: int = mouse_frame - draggable.mouse_offset
	var track_difference: int = mouse_track - anchor_clip.track
	var frame_difference: int = target_start - anchor_clip.start

	var ignore_ids: Array[int] =[]
	ignore_ids.assign(draggable.ids)

	var candidates: Array[int] = [frame_difference]

	for clip_id: int in draggable.ids:
		var clip: ClipData = ClipLogic.clips[clip_id]
		var new_track: int = clip.track + track_difference
		if new_track < 0 or new_track >= TrackLogic.tracks.size():
			return false

		candidates.append(0 - clip.start)

		for other: ClipData in TrackLogic.track_clips[new_track].clips:
			if other.id in ignore_ids:
				continue
			candidates.append(other.start - clip.end)
			candidates.append(other.end - clip.start)

	var best_frame_difference: int = frame_difference
	var best_dist: int = 2147483647
	var valid_found: bool = false
	for difference: int in candidates:
		var dist: int = abs(difference - frame_difference)
		if dist <= SNAPPING and dist < best_dist:
			var is_valid: bool = true
			for clip_id: int in draggable.ids:
				var clip: ClipData = ClipLogic.clips[clip_id]
				var new_track: int = clip.track + track_difference
				var new_start: int = clip.start + difference
				var new_end: int = clip.end + difference
				if new_start < 0:
					is_valid = false
					break
				for other: ClipData in TrackLogic.track_clips[new_track].clips:
					if other.id in ignore_ids:
						continue
					if new_start < other.end and new_end > other.start:
						is_valid = false
						break
				if not is_valid:
					break
			if is_valid:
				best_dist = dist
				best_frame_difference = difference
				valid_found = true
	if not valid_found:
		return false
	draggable.track_offset = track_difference
	draggable.frame_offset = best_frame_difference
	return true


func _drop_data(_p: Vector2, data: Variant) -> void:
	if data is EffectsPanel.DragData:
		var drag_data: EffectsPanel.DragData = data
		var clip: ClipData = _get_clip_on_mouse()
		if clip:
			var new_effect: Effect = drag_data.effect.duplicate(true)
			new_effect.keyframes = drag_data.effect.keyframes.duplicate(true)
			new_effect._cache_dirty = true
			EffectsHandler.add_effect(clip, new_effect, drag_data.is_visual)
		return
	elif data is not Draggable or state not in[STATE.DROPPING, STATE.MOVING]:
		return
	elif draggable.is_file: # Creating new clips (ids are file ids!)
		var requests: Array[ClipRequest] = []
		var total_duration: int = 0
		for file_id: int in draggable.ids:
			var file: FileData = FileLogic.files[file_id]
			var target_frame: int = draggable.frame_offset + total_duration
			requests.append(ClipRequest.add_request(file, draggable.track_offset, target_frame))
			total_duration += file.duration
		ClipLogic.add(requests)
	else: # Moving clips
		var move_requests: Array[ClipRequest] = []
		for clip_id: int in draggable.ids:
			var clip: ClipData = ClipLogic.clips[clip_id]
			move_requests.append(ClipRequest.move_request(clip, draggable.track_offset, draggable.frame_offset))
		if not move_requests.is_empty():
			ClipLogic.move(move_requests)
	draggable = null
	_update_clips = true
	draw_clips.queue_redraw()
	draw_preview.queue_redraw()


func _on_mouse_entered() -> void:
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_ui_cancel()
	draw_all()


func _on_mouse_exited() -> void:
	hovered_clip = null
	await RenderingServer.frame_pre_draw
	draw_all()


## This function is also used to handle speeding.
func _commit_current_resize() -> void:
	if resize_target.delta != 0:
		if state == STATE.SPEEDING:
			ClipLogic.change_speed([ClipRequest.resize_request(
				resize_target.clip, resize_target.delta, resize_target.is_end)])
		else:
			ClipLogic.resize([ClipRequest.resize_request(
					resize_target.clip, resize_target.delta, resize_target.is_end)])
	resize_target = null
	draw_clips.queue_redraw()


func _commit_box_selection(is_ctrl_pressed: bool) -> void:
	var max_track: int = TrackLogic.tracks.size()
	var track_start: int = clampi(floori(box_select_start.y / track_total_size), 0, max_track)
	var track_end: int = clampi(floori(box_select_end.y / track_total_size), 0, max_track)
	var frame_start: int = floori(box_select_start.x / zoom)
	var frame_end: int = floori(box_select_end.x / zoom)
	var temp: int
	if not is_ctrl_pressed:
		selected_clips.clear()

	if track_start > track_end:
		temp = track_start
		track_start = track_end
		track_end = temp
	if frame_start > frame_end:
		temp = frame_start
		frame_start = frame_end
		frame_end = temp

	for track_id: int in range(track_start, clamp(track_end + 1, 0, max_track)):
		for clip: ClipData in TrackLogic.track_clips[track_id].clips:
			if clip.start > frame_end:
				break

			if clip.start > frame_start and clip.start < frame_end:
				if clip not in selected_clips:
					selected_clips.append(clip)
				continue

			# We should also check if a clip ends inside the selection box.
			if clip.end > frame_start:
				if clip not in selected_clips:
					selected_clips.append(clip)
	if selected_clips.is_empty():
		ClipLogic.selected.emit(null)
	else:
		ClipLogic.selected.emit(selected_clips[-1])

	draw_box_selection.queue_redraw()
	draw_clips.queue_redraw()


## This function is also used to handle speeding.
func _handle_resize_motion() -> void:
	var clip: ClipData = resize_target.clip
	var file: FileData = FileLogic.files[clip.file]
	var current_frame: int = get_frame_from_mouse()
	var is_fixed_duration: bool = file.type in [EditorCore.TYPE.AUDIO, EditorCore.TYPE.VIDEO]

	if resize_target.is_end: # Resizing end.
		var new_duration: int = current_frame - resize_target.original_start
		var max_allowed_duration: int = file.duration - clip.begin

		if new_duration < 1:
			new_duration = 1
		if state != STATE.SPEEDING and is_fixed_duration and new_duration > max_allowed_duration:
			new_duration = max_allowed_duration

		# Collision detection.
		var free_region: Vector2i = TrackLogic.get_free_region(
				clip.track, resize_target.original_start + 1, [clip.id])

		if (resize_target.original_start + new_duration) > free_region.y:
			new_duration = free_region.y - resize_target.original_start
		resize_target.delta = new_duration - resize_target.original_duration
	else: # Resizing beginning.
		var new_start: int = current_frame

		if new_start > (resize_target.original_start + resize_target.original_duration - 1):
			new_start = (resize_target.original_start + resize_target.original_duration - 1)
		if state != STATE.SPEEDING and is_fixed_duration:
			var min_allowed_duration: int = resize_target.original_start - clip.begin
			if new_start < min_allowed_duration:
				new_start = min_allowed_duration

		# Collision detection.
		var free_region: Vector2i = TrackLogic.get_free_region(
				clip.track,
				resize_target.original_start + resize_target.original_duration - 1,
				[clip.id])

		if new_start < free_region.x:
			new_start = free_region.x
		resize_target.delta = new_start - resize_target.original_start
	draw_clips.queue_redraw()


func _handle_fade_motion() -> void:
	var clip: ClipData = fade_target.clip
	var mouse_x: float = get_local_mouse_position().x
	var start_x: float = clip.start * zoom
	var end_x: float = clip.end * zoom
	var drag_frames: int = 0 ## Convert pixel drag to frame amount

	if not fade_target.is_end: # Fade In
		drag_frames = clamp(floori((mouse_x - start_x) / zoom), 0, clip.duration)
		if fade_target.is_visual:
			clip.effects.fade_visual.x = drag_frames
		else:
			clip.effects.fade_audio.x = drag_frames
	else: # Fade Out
		drag_frames = clamp(floori((end_x - mouse_x) / zoom), 0, clip.duration)
		if fade_target.is_visual:
			clip.effects.fade_visual.y = drag_frames
		else:
			clip.effects.fade_audio.y = drag_frames
	draw_clips.queue_redraw()
	EditorCore.update_frame()


func _add_popup_menu_items_clip(popup: PopupMenu) -> void:
	if !right_click_clip:
		return
	if right_click_clip not in selected_clips:
		selected_clips = [right_click_clip]
		ClipLogic.selected.emit(right_click_clip)

	# TODO: Set shortcuts.
	popup.add_theme_constant_override("icon_max_width", 20)
	popup.add_icon_item(preload(Library.ICON_DELETE), tr("Delete clip"), POPUP_ACTION.CLIP_DELETE)
	popup.add_icon_item(preload(Library.ICON_TIMELINE_MODE_CUT), tr("Cut clip"), POPUP_ACTION.CLIP_CUT)

	if right_click_clip.type == EditorCore.TYPE.VIDEO:
		popup.add_separator(tr("Video options"))
		popup.add_item(tr("Clip audio-take-over"), POPUP_ACTION.CLIP_AUDIO_TAKE_OVER)

	popup.add_separator(tr("Track options"))
	popup.add_icon_item(preload(Library.ICON_ADD), tr("Add track"), POPUP_ACTION.TRACK_ADD)
	if TrackLogic.tracks.size() != 1:
		popup.add_icon_item(preload(Library.ICON_DELETE), tr("Remove track"), POPUP_ACTION.TRACK_REMOVE)


func _on_popup_menu_id_pressed(id: POPUP_ACTION) -> void:
	match id:
		# Clip options
		POPUP_ACTION.CLIP_DELETE: _on_popup_action_clip_delete()
		POPUP_ACTION.CLIP_CUT: _on_popup_action_clip_cut()
		# Video options
		POPUP_ACTION.CLIP_AUDIO_TAKE_OVER: _on_popup_action_clip_ato()
		# Track options
		POPUP_ACTION.REMOVE_EMPTY_SPACE: _on_popup_action_remove_empty_space()
		POPUP_ACTION.TRACK_ADD: _on_popup_action_track_add()
		POPUP_ACTION.TRACK_REMOVE: _on_popup_action_track_remove()
	draw_all()


func _on_popup_action_clip_delete() -> void:
	ClipLogic.delete(selected_clips)


func _on_popup_action_clip_cut() -> void:
	cut_clips_at(right_click_pos.y)


func _on_popup_action_remove_empty_space() -> void:
	remove_empty_space_at(right_click_pos.x, right_click_pos.y)


func _on_popup_action_clip_ato() -> void:
	var popup: Control = PopupManager.get_popup(PopupManager.AUDIO_TAKE_OVER)
	@warning_ignore("unsafe_method_access") # NOTE: Audio take over doesn't have a class.
	popup.load_data(right_click_clip.id, false)


func _on_popup_action_track_add() -> void:
	TrackLogic.add_track(right_click_pos.x)


func _on_popup_action_track_remove() -> void:
	TrackLogic.remove_track(right_click_pos.x)


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


func _update_track_height(new_height: float) -> void:
	track_height = new_height
	track_total_size = track_height + TRACK_LINE_WIDTH
	_on_tracks_updated()


func _on_clip_deleted(clip_id: int) -> void:
	for i: int in selected_clips.size():
		if selected_clips[i].id == clip_id:
			selected_clips.remove_at(i)
			break
	if hovered_clip and hovered_clip.id == clip_id:
		hovered_clip = null
	if pressed_clip and pressed_clip.id == clip_id:
		pressed_clip = null
	if right_click_clip and right_click_clip.id == clip_id:
		right_click_clip = null
	draw_clips.queue_redraw()
	draw_clips.queue_redraw()


func _on_tracks_updated() -> void:
	custom_minimum_size.y = track_total_size * TrackLogic.tracks.size()
	draw_all()


func zoom_at_mouse(factor: float) -> void:
	var old_zoom: float = zoom
	var old_mouse_pos_x: float = get_local_mouse_position().x
	var mouse_viewport_offset: float = old_mouse_pos_x - scroll.scroll_horizontal

	zoom = clamp(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if old_zoom == zoom:
		accept_event()
		return

	var zoom_ratio: float = zoom / old_zoom
	var new_mouse_pos_x: float = old_mouse_pos_x * zoom_ratio

	scroll.scroll_horizontal = int(new_mouse_pos_x - mouse_viewport_offset)
	zoom_changed.emit(zoom)
	draw_all()
	accept_event()


func get_frame_from_mouse() -> int:
	return maxi(ceili(get_local_mouse_position().x / zoom), 0)


func get_track_from_mouse() -> int:
	return clampi(floori(get_local_mouse_position().y / track_total_size), 0, TrackLogic.tracks.size() - 1)


func move_playhead(frame_nr: int) -> void:
	EditorCore.set_frame(maxi(0, frame_nr))
	draw_playhead.queue_redraw()


func remove_empty_space_at(track_id: int, frame_nr: int) -> void:
	var clips: Array[ClipData] = TrackLogic.get_clips_after(track_id, frame_nr)
	var region: Vector2i = TrackLogic.get_free_region(track_id, frame_nr)
	var empty_size: int = region.y - region.x
	var move_requests: Array[ClipRequest] = []

	for clip: ClipData in clips:
		move_requests.append(ClipRequest.move_request(clip, 0, -empty_size))
	if !move_requests.is_empty():
		ClipLogic.move(move_requests)


func cut_clip_at(clip: ClipData, frame_pos: int) -> void:
	if clip.start <= frame_pos and clip.end >= frame_pos:
		ClipLogic.cut([ClipRequest.cut_request(clip, frame_pos - clip.start)])
	draw_clips.queue_redraw()


func cut_clips_at(frame_pos: int) -> void:
	# Check if any of the clips in the tracks is in selected clips
	# if there are selected clips present, we only cut the selected ones
	var requests: Array[ClipRequest] = []

	# Checking if we only want selected clips to be cut.
	for clip: ClipData in selected_clips:
		if clip.start < frame_pos and clip.end > frame_pos:
			requests.append(ClipRequest.cut_request(clip, frame_pos - clip.start))

	if !requests.is_empty():
		ClipLogic.cut(requests)
		return draw_clips.queue_redraw()

	# No selected clips present so cutting all possible clips
	for track_id: int in TrackLogic.tracks.size():
		var clip: ClipData = TrackLogic.get_clip_at_overlap(track_id, frame_pos)
		if !clip:
			continue
		if clip.start < frame_pos and clip.end > frame_pos:
			requests.append(ClipRequest.cut_request(clip, frame_pos - clip.start))

	ClipLogic.cut(requests)
	draw_clips.queue_redraw()


func duplicate_selected_clips() -> void:
	if selected_clips.is_empty():
		return

	var requests: Array[ClipRequest] = []
	var failed_duplicates: int = 0
	for clip: ClipData in selected_clips:
		if !clip:
			continue
		var target_frame: int = clip.end
		var free_region: Vector2i = TrackLogic.get_free_region(clip.track, target_frame)

		if free_region.y - target_frame >= clip.duration:
			var file: FileData = FileLogic.files[clip.file]
			requests.append(ClipRequest.add_request(file, clip.track, target_frame))
		else:
			failed_duplicates += 1
	if not requests.is_empty():
		ClipLogic.add(requests)
	if failed_duplicates != 0:
		var dialog: AcceptDialog = PopupManager.create_accept_dialog(tr("Duplication failed"))
		dialog.dialog_text = tr("Could not duplicate %d clip(s) because there was not enough empty space.") % failed_duplicates
		add_child(dialog)
		dialog.popup_centered()


func set_state(new_state: STATE) -> void:
	state = new_state


func draw_all() -> void:
	draw_track_lines.queue_redraw()
	draw_clips.queue_redraw()
	draw_preview.queue_redraw()
	draw_mode.queue_redraw()
	draw_playhead.queue_redraw()
	draw_box_selection.queue_redraw()
	draw_markers.queue_redraw()


func update_waveform_data() -> void:
	waveform_style = Settings.get_audio_waveform_style()
	waveform_amp = Settings.get_audio_waveform_amp()
	draw_clips.queue_redraw()



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
