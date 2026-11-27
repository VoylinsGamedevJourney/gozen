extends PanelContainer

enum RenderRegion { NONE, BAR, IN, OUT }

const STEPS: PackedInt32Array = [1, 5, 10, 30, 60, 150, 300, 600, 1800, 3600]

const MARKER_HANDLE_HEIGHT: int = 16
const MARKER_LINE_WIDTH: int = 2
const MARKER_PADDING: int = 4
const MARKER_DRAG_THRESHOLD: int = 3

const RENDER_REGION_BAR_HEIGHT: float = 4.0
const RENDER_REGION_BAR_HIT_HEIGHT: float = 7.0
const RENDER_REGION_HANDLE_WIDTH: float = 6.0
const RENDER_REGION_HANDLE_HEIGHT: float = 10.0
const RENDER_REGION_HANDLE_HIT_PADDING: float = 4.0

const FONT_SIZE_MARKER: int = 10
const FONT_SIZE_TIME_STAMP: int = 10


@export var timeline_scroll: ScrollContainer


@onready var scroll: ScrollContainer = get_parent()


var scrubbing: bool = false

var marker_style_box: StyleBoxFlat
var marker_rects: Dictionary[int, Rect2] = {} # { frame_nr: hitbox }


var default_font: Font = get_theme_default_font()

var _possible_drag: int = -1
var _drag_offset: float = 0.0
var _drag_start_pos: Vector2 = Vector2.ZERO

var _region_rects: Dictionary[RenderRegion, Rect2] = {}
var _region_hover: RenderRegion = RenderRegion.NONE
var _region_drag_mode: RenderRegion = RenderRegion.NONE
var _region_drag_offset: float = 0.0
var _region_drag_duration: int = 0
var _region_bar_dragged: bool = false



func _ready() -> void:
	Project.project_ready.connect(update_stamps)
	Project.framerate_changed.connect(update_stamps)
	Project.render_region_updated.connect(_on_render_region_updated)

	MarkerLogic.added.connect(update_stamps.unbind(1))
	MarkerLogic.updated.connect(update_stamps.unbind(1))
	MarkerLogic.removed.connect(update_stamps.unbind(1))

	Timeline.zoom_changed.connect(update_stamps.unbind(1))
	Timeline.scroll_changed.connect(update_stamps.unbind(1))

	get_viewport().size_changed.connect(update_stamps)
	mouse_exited.connect(_on_mouse_exited)

	_setup_marker_style_box()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_gui_input_mouse_button_left(event as InputEventMouseButton)
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_gui_input_mouse_button_right(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_gui_input_mouse_motion(event as InputEventMouseMotion)


func _gui_input_mouse_button_left(event: InputEventMouseButton) -> void:
	if event.pressed:
		_update_hover_state(event.position)
		_drag_start_pos = event.position

		if _region_hover in [RenderRegion.IN, RenderRegion.OUT]:
			_region_drag_mode = _region_hover
			var handle_frame: int = Project.data.render_region.x if _region_hover == RenderRegion.IN else Project.data.render_region.y
			_region_drag_offset = (handle_frame * Timeline.zoom) - event.position.x
			scrubbing = false
			queue_redraw()
		elif _possible_drag != -1:
			MarkerLogic.dragged_marker = MarkerLogic.get_marker(_possible_drag)
			MarkerLogic.dragged_marker_offset = MarkerLogic.dragged_marker.frame_nr * Timeline.zoom
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			scrubbing = false
			queue_redraw()
		elif _region_hover == RenderRegion.BAR:
			_region_drag_mode = RenderRegion.BAR
			_region_drag_offset = (Project.data.render_region.x * Timeline.zoom) - event.position.x
			_region_drag_duration = Project.data.render_region.y - Project.data.render_region.x
			_region_bar_dragged = false
			scrubbing = false
			queue_redraw()
		else:
			scrubbing = true
			if EditorCore.is_playing and Settings.get_module_setting("core_timeline_panel", "pause_after_drag", false):
				EditorCore.is_playing = false
			EditorCore.scrub_to_frame(_get_frame_on_mouse(event.position.x))
		accept_event()
	else: # Mouse released.
		if _region_drag_mode == RenderRegion.BAR:
			if not _region_bar_dragged and event.position.distance_to(_drag_start_pos) <= MARKER_DRAG_THRESHOLD:
				Project.set_render_toggle(!Project.data.use_render_region)
			_region_drag_mode = RenderRegion.NONE
			_region_bar_dragged = false
			_update_hover_state(event.position)
			_update_tooltip()
			queue_redraw()
			accept_event()
			return
		elif _region_drag_mode in [RenderRegion.IN, RenderRegion.OUT]:
			_region_drag_mode = RenderRegion.NONE
			_update_hover_state(event.position)
			_update_tooltip()
			queue_redraw()
			accept_event()
			return

		var marker: MarkerData = MarkerLogic.dragged_marker
		if marker:
			var is_dragged: bool = get_local_mouse_position().distance_to(_drag_start_pos) > MARKER_DRAG_THRESHOLD
			var new_frame_nr: int = roundi(MarkerLogic.dragged_marker_offset / Timeline.zoom)

			if is_dragged and new_frame_nr != marker.frame_nr:
				MarkerLogic.update(new_frame_nr, marker.text, marker.type, marker)
			else:
				EditorCore.set_frame(marker.frame_nr)
				PopupManager.open(PopupManager.MARKER)

			MarkerLogic.dragged_marker = null
			MarkerLogic.dragged_marker_offset = 0
			queue_redraw()

		scrubbing = false
		EditorCore.finish_scrub()
		accept_event()


func _gui_input_mouse_button_right(event: InputEventMouseButton) -> void:
	if event.pressed:
		_update_hover_state(event.position)
		if _possible_drag != -1:
			MarkerLogic.remove(_possible_drag)
			_possible_drag = -1
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			queue_redraw()
			accept_event()


func _gui_input_mouse_motion(event: InputEventMouseMotion) -> void:
	if _region_drag_mode in [RenderRegion.IN, RenderRegion.OUT]:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var target_frame: int = _get_frame_on_mouse(event.position.x + _region_drag_offset)
			var snap_delta: int = Timeline.find_snap_offset([target_frame], maxi(1, int(10.0 / Timeline.zoom)))
			target_frame += snap_delta

			if _region_drag_mode == RenderRegion.IN:
				target_frame = clampi(target_frame, 0, Project.data.render_region.y - 1)
				Project.set_render_region_in(target_frame)
			else:
				target_frame = maxi(target_frame, Project.data.render_region.x + 1)
				Project.set_render_region_out(target_frame)
			_update_tooltip()
		else:
			_region_drag_mode = RenderRegion.NONE
			_update_hover_state(event.position)
			queue_redraw()
	elif _region_drag_mode == RenderRegion.BAR:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _region_bar_dragged and event.position.distance_to(_drag_start_pos) > MARKER_DRAG_THRESHOLD:
				_region_bar_dragged = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG

			if _region_bar_dragged:
				var new_start: int = _get_frame_on_mouse(event.position.x + _region_drag_offset)
				var new_end: int = new_start + _region_drag_duration
				var snap_delta: int = Timeline.find_snap_offset([new_start, new_end], maxi(1, int(10.0 / Timeline.zoom)))
				new_start = maxi(0, new_start + snap_delta)
				Project.set_render_region(Vector2i(new_start, new_start + _region_drag_duration))
				_update_tooltip()
		else:
			_region_drag_mode = RenderRegion.NONE
			_region_bar_dragged = false
			_update_hover_state(event.position)
			queue_redraw()
	elif MarkerLogic.dragged_marker:
		queue_redraw()
	elif scrubbing:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			EditorCore.scrub_to_frame(_get_frame_on_mouse(event.position.x))
		else:
			scrubbing = false
			EditorCore.finish_scrub()
	else:
		_update_hover_state(event.position)
		_update_tooltip()


func _enter_tree() -> void:
	queue_redraw.call_deferred()


func _on_render_region_updated() -> void:
	if Project.data.render_region.y <= Project.data.render_region.x:
		_region_hover = RenderRegion.NONE
		_region_drag_mode = RenderRegion.NONE
		_region_rects.clear()
	queue_redraw()


func _on_mouse_exited() -> void:
	if _region_drag_mode == RenderRegion.NONE and not MarkerLogic.dragged_marker and not scrubbing:
		if _region_hover != RenderRegion.NONE or _possible_drag != -1:
			_region_hover = RenderRegion.NONE
			_possible_drag = -1
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			queue_redraw()


func _draw() -> void:
	var scroll_width: float = scroll.size.x
	var visible_start_nr: int = int(Timeline.scroll_x / Timeline.zoom)
	var visible_end_nr: int = int((Timeline.scroll_x + scroll_width) / Timeline.zoom) + 1

	var major_step: int = _get_major_frame_step()
	var minor_step: int = maxi(1, int(major_step / 5.0))

	var start_frame: int = visible_start_nr - (visible_start_nr % minor_step)

	# - Draw ticks and time text
	var last_text_x: float = -999.0
	for frame: int in range(start_frame, visible_end_nr, minor_step):
		var x: float = frame * Timeline.zoom
		if !Math.in_rangef(x, Timeline.scroll_x - 100, Timeline.scroll_x + size.x + 100, false):
			continue

		var is_major: int = frame % major_step == 0
		var tick_h: int = 12 if is_major else 6
		if is_major:
			var label: String = Format.time_str_from_frame(frame, Project.data.framerate, true)
			var label_width: float = default_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_TIME_STAMP).x
			if x - last_text_x >= label_width + 8.0:  # 8px padding between labels.
				draw_string(
					default_font,
					Vector2(x + 4, size.y - 8),
					label,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					FONT_SIZE_TIME_STAMP,
					get_theme_color("text_color", "TimeStamps"))
				last_text_x = x
		draw_line(
			Vector2(x, size.y),
			Vector2(x, size.y - tick_h),
			get_theme_color("tick_color", "TimeStamps"))

	# - Draw markers
	marker_rects.clear()

	for marker: MarkerData in MarkerLogic.markers:
		var dragged_marker: MarkerData = MarkerLogic.dragged_marker
		var is_being_dragged: bool = marker == dragged_marker
		if !is_being_dragged and !Math.in_range(marker.frame_nr, visible_start_nr, visible_end_nr):
			continue # Only visible markers and the one being dragged get drawn

		var marker_text: String = marker.text
		var marker_color: Color = Settings.get_marker_color(marker.type)

		var pos_x: float = marker.frame_nr * Timeline.zoom
		var text_size: Vector2 = default_font.get_string_size(
				marker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_MARKER)
		var text_y_offset: float = (MARKER_HANDLE_HEIGHT - text_size.y) / 2.0 + default_font.get_ascent(FONT_SIZE_MARKER)

		if is_being_dragged:
			if get_local_mouse_position().distance_to(_drag_start_pos) > MARKER_DRAG_THRESHOLD:
				MarkerLogic.dragged_marker_offset = _get_frame_on_mouse() * Timeline.zoom + _drag_offset
				pos_x = MarkerLogic.dragged_marker_offset
			else:
				MarkerLogic.dragged_marker_offset = marker.frame_nr * Timeline.zoom
			marker_style_box.bg_color = marker_color * Color(1.0, 1.0, 1.0, 0.2)

		var bubble_pos_x: float = pos_x + (MARKER_LINE_WIDTH / 2.0)
		var bubble_width: float = text_size.x + (MARKER_PADDING * 2)
		var bubble_rect: Rect2 = Rect2(bubble_pos_x, 0, bubble_width, MARKER_HANDLE_HEIGHT)
		var bubble_text_pos: Vector2 = Vector2(pos_x + MARKER_PADDING, text_y_offset)
		var bubble_text_color: Color = Color.WHITE if marker_color.get_luminance() < 0.5 else Color.BLACK

		if !is_being_dragged:
			marker_rects[marker.frame_nr] = bubble_rect
			marker_style_box.bg_color = marker_color * Color(1.0, 1.0, 1.0, 0.5)

		draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), marker_color, MARKER_LINE_WIDTH)
		draw_style_box(marker_style_box, bubble_rect)
		draw_string(default_font, bubble_text_pos, marker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_MARKER, bubble_text_color)

	# - Draw render region
	_region_rects.clear()
	var region_start: float = Project.data.render_region.x * Timeline.zoom
	var region_end: float = Project.data.render_region.y * Timeline.zoom
	var base_render_color: Color = get_theme_color("render_region", "TimeStamps")
	var bar_alpha: float = 0.7 if Project.data.use_render_region else 0.3
	if _region_hover == RenderRegion.BAR or _region_drag_mode == RenderRegion.BAR:
		bar_alpha = minf(1.0, bar_alpha + 0.2)

	var render_color: Color = base_render_color
	render_color.a *= bar_alpha
	if Project.data.render_region.y > Project.data.render_region.x:
		var bar_width: float = region_end - region_start
		draw_rect(Rect2(region_start, 0.0, bar_width, RENDER_REGION_BAR_HEIGHT), render_color)
		_region_rects[RenderRegion.BAR] = Rect2(region_start, 0.0, bar_width, RENDER_REGION_BAR_HIT_HEIGHT)

		var left_handle_rect: Rect2
		var right_handle_rect: Rect2
		if bar_width >= RENDER_REGION_HANDLE_WIDTH * 2.0:
			left_handle_rect = Rect2(region_start, 0.0, RENDER_REGION_HANDLE_WIDTH, RENDER_REGION_HANDLE_HEIGHT)
			right_handle_rect = Rect2(region_end - RENDER_REGION_HANDLE_WIDTH, 0.0, RENDER_REGION_HANDLE_WIDTH, RENDER_REGION_HANDLE_HEIGHT)
		else:
			left_handle_rect = Rect2(maxf(0.0, region_start - RENDER_REGION_HANDLE_WIDTH), 0.0, RENDER_REGION_HANDLE_WIDTH, RENDER_REGION_HANDLE_HEIGHT)
			right_handle_rect = Rect2(region_end, 0.0, RENDER_REGION_HANDLE_WIDTH, RENDER_REGION_HANDLE_HEIGHT)

		var default_handle_alpha: float = 0.9 if Project.data.use_render_region else 0.5
		var left_handle_color: Color = base_render_color
		left_handle_color.a *= default_handle_alpha
		if _region_hover == RenderRegion.IN or _region_drag_mode == RenderRegion.IN:
			left_handle_color = base_render_color.lightened(0.35)
			left_handle_color.a = 1.0

		var right_handle_color: Color = base_render_color
		right_handle_color.a *= default_handle_alpha
		if _region_hover == RenderRegion.OUT or _region_drag_mode == RenderRegion.OUT:
			right_handle_color = base_render_color.lightened(0.35)
			right_handle_color.a = 1.0

		draw_rect(left_handle_rect, left_handle_color)
		draw_rect(right_handle_rect, right_handle_color)
		draw_rect(Rect2(region_start, 0.0, 2.0, RENDER_REGION_HANDLE_HEIGHT), left_handle_color.lightened(0.25))
		draw_rect(Rect2(region_end - 2.0, 0.0, 2.0, RENDER_REGION_HANDLE_HEIGHT), right_handle_color.lightened(0.25))

		var left_hit_rect: Rect2 = left_handle_rect.grow(RENDER_REGION_HANDLE_HIT_PADDING)
		left_hit_rect.position.y = 0.0
		left_hit_rect.size.y = RENDER_REGION_HANDLE_HEIGHT + RENDER_REGION_HANDLE_HIT_PADDING
		_region_rects[RenderRegion.IN] = left_hit_rect

		var right_hit_rect: Rect2 = right_handle_rect.grow(RENDER_REGION_HANDLE_HIT_PADDING)
		right_hit_rect.position.y = 0.0
		right_hit_rect.size.y = RENDER_REGION_HANDLE_HEIGHT + RENDER_REGION_HANDLE_HIT_PADDING
		_region_rects[RenderRegion.OUT] = right_hit_rect


func _get_frame_on_mouse(mouse_x: float = get_local_mouse_position().x) -> int:
	return maxi(0, roundi(mouse_x / Timeline.zoom))


func _update_tooltip() -> void:
	var mouse_x: float = get_local_mouse_position().x
	if mouse_x < 0 or mouse_x > size.x:
		if tooltip_text != "":
			tooltip_text = ""
		return # Out of bounds.

	var frame_nr: int = maxi(0, floori(mouse_x / Timeline.zoom))
	var time_str: String = Format.time_str_from_frame(frame_nr, Project.data.framerate, false)
	var full_tooltip: String = "%s\n(Frame: %d)" % [time_str, frame_nr]

	if _region_drag_mode == RenderRegion.IN or _region_hover == RenderRegion.IN:
		var in_frame: int = Project.data.render_region.x
		var in_time: String = Format.time_str_from_frame(in_frame, Project.data.framerate, false)
		full_tooltip = tr("Render region start") + ": %s (Frame: %d)\n" % [in_time, in_frame] + tr("Drag to adjust")
	elif _region_drag_mode == RenderRegion.OUT or _region_hover == RenderRegion.OUT:
		var out_frame: int = Project.data.render_region.y
		var out_time: String = Format.time_str_from_frame(out_frame, Project.data.framerate, false)
		full_tooltip = tr("Render region end") + ": %s (Frame: %d)\n" % [out_time, out_frame] + tr("Drag to adjust")
	elif _region_drag_mode == RenderRegion.BAR or _region_hover == RenderRegion.BAR:
		var status: String = tr("Active") if Project.data.use_render_region else tr("In-active")
		var action: String = tr("Click to deactivate, drag to move") if Project.data.use_render_region else tr("Click to activate, drag to move")
		full_tooltip = "%s\n(Frame: %d)\n%s (%s) - %s" % [time_str, frame_nr, tr("Render region"), status, action]

	if tooltip_text != full_tooltip:
		tooltip_text = full_tooltip


func _get_major_frame_step() -> int:
	# 120 pixels between major ticks.
	var frames: float =  120.0 / Timeline.zoom
	for step: int in STEPS:
		if step >= frames:
			return step
	return STEPS[-1]


func _setup_marker_style_box() -> void:
	marker_style_box = StyleBoxFlat.new()
	marker_style_box.corner_radius_top_right = 5
	marker_style_box.corner_radius_bottom_right = 5
	marker_style_box.corner_radius_top_left = 0
	marker_style_box.corner_radius_bottom_left = 0


func _update_hover_state(mouse_pos: Vector2 = get_local_mouse_position()) -> void:
	var new_region_hover: RenderRegion = RenderRegion.NONE
	var found_marker: int = -1

	var in_rect: Rect2 = _region_rects.get(RenderRegion.IN, Rect2())
	var out_rect: Rect2 = _region_rects.get(RenderRegion.OUT, Rect2())
	var hit_in: bool = in_rect.has_point(mouse_pos)
	var hit_out: bool = out_rect.has_point(mouse_pos)

	if hit_in and hit_out:
		var region_start: float = Project.data.render_region.x * Timeline.zoom
		var region_end: float = Project.data.render_region.y * Timeline.zoom
		if absf(mouse_pos.x - region_start) <= absf(mouse_pos.x - region_end):
			new_region_hover = RenderRegion.IN
		else:
			new_region_hover = RenderRegion.OUT
	elif hit_in:
		new_region_hover = RenderRegion.IN
	elif hit_out:
		new_region_hover = RenderRegion.OUT
	else:
		for frame_nr: int in marker_rects:
			if marker_rects[frame_nr].has_point(mouse_pos):
				found_marker = frame_nr

		if found_marker == -1:
			var bar_rect: Rect2 = _region_rects.get(RenderRegion.BAR, Rect2())
			if bar_rect.has_point(mouse_pos):
				new_region_hover = RenderRegion.BAR

	if _region_hover != new_region_hover or _possible_drag != found_marker:
		_region_hover = new_region_hover
		_possible_drag = found_marker
		if _possible_drag != -1:
			_drag_offset = (_possible_drag * Timeline.zoom) - mouse_pos.x
		queue_redraw()

	if _region_hover in [RenderRegion.IN, RenderRegion.OUT]:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif _region_hover == RenderRegion.BAR or _possible_drag != -1:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func update_stamps() -> void:
	# Helper function as called `queue_redraw` from a connect fails sometimes.
	queue_redraw()
