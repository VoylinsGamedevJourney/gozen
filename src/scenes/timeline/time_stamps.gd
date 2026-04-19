extends PanelContainer


const COLOR_TEXT: Color = Color(0.85, 0.85, 0.85, 0.5)
const COLOR_TICK: Color = Color(0.4, 0.4, 0.4, 0.5)
const STEPS: PackedInt32Array = [1, 5, 10, 30, 60, 150, 300, 600, 1800, 3600]

const MARKER_HANDLE_HEIGHT: int = 16
const MARKER_LINE_WIDTH: int = 2
const MARKER_PADDING: int = 4
const MARKER_DRAG_THRESHOLD: int = 3

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



func _ready() -> void:
	@warning_ignore_start("return_value_discarded")
	Project.project_ready.connect(_on_project_ready)
	Project.render_region_updated.connect(queue_redraw)

	MarkerLogic.added.connect(update_stamps.unbind(1))
	MarkerLogic.updated.connect(update_stamps.unbind(1))
	MarkerLogic.removed.connect(update_stamps.unbind(1))

	Timeline.zoom_changed.connect(queue_redraw.unbind(1))
	Timeline.scroll_changed.connect(queue_redraw.unbind(1))
	@warning_ignore_restore("return_value_discarded")

	_setup_marker_style_box()


func _on_project_ready() -> void:
	update_stamps()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var event_mouse_button: InputEventMouseButton = event
		if (event_mouse_button as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_on_left_mouse_button(event_mouse_button)
	elif event is InputEventMouseMotion:
		if MarkerLogic.dragged_marker:
			queue_redraw()
		elif scrubbing:
			EditorCore.scrub_to_frame(_get_frame_on_mouse())
		else:
			_update_hovered_marker()
			_update_tooltip()


func _on_left_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		_update_hovered_marker()

		if _possible_drag != -1:
			_drag_start_pos = get_local_mouse_position()
			MarkerLogic.dragged_marker = MarkerLogic.get_marker(_possible_drag)
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			scrubbing = false
		else:
			scrubbing = true
			if EditorCore.is_playing:
				EditorCore.is_playing = false
			EditorCore.scrub_to_frame(_get_frame_on_mouse())
	else: # Mouse released.
		var marker: MarkerData = MarkerLogic.dragged_marker
		if marker:
			var new_frame_nr: int = floori(MarkerLogic.dragged_marker_offset / Timeline.zoom)
			if new_frame_nr != MarkerLogic.dragged_marker.frame_nr:
				MarkerLogic.update(new_frame_nr, marker.text, marker.type, marker)
			else:
				EditorCore.set_frame(new_frame_nr)
				PopupManager.open(PopupManager.MARKER)

			MarkerLogic.dragged_marker = null
			MarkerLogic.dragged_marker_offset = 0
			queue_redraw()
		if scrubbing:
			EditorCore.finish_scrub()
		scrubbing = false


func _get_frame_on_mouse() -> int:
	return maxi(0, floori(get_local_mouse_position().x / Timeline.zoom))


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
		if !Utils.in_rangef(x, Timeline.scroll_x - 100, Timeline.scroll_x + size.x + 100, false):
			continue

		var is_major: int = frame % major_step == 0
		var tick_h: int = 12 if is_major else 6
		if is_major:
			var label: String = Utils.format_time_str_from_frame(frame, Project.data.framerate, true)
			var label_width: float = default_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_TIME_STAMP).x
			if x - last_text_x >= label_width + 8.0:  # 8px padding between labels.
				draw_string(
					default_font,
					Vector2(x + 4, size.y - 8),
					label,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					FONT_SIZE_TIME_STAMP,
					COLOR_TEXT)
				last_text_x = x
		draw_line(
			Vector2(x, size.y),
			Vector2(x, size.y - tick_h),
			COLOR_TICK
		)

	# - Draw markers
	marker_rects.clear()

	for marker: MarkerData in MarkerLogic.markers:
		var dragged_marker: MarkerData = MarkerLogic.dragged_marker
		var is_being_dragged: bool = marker == dragged_marker
		if !is_being_dragged and !Utils.in_range(marker.frame_nr, visible_start_nr, visible_end_nr):
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
	if Project.data.use_render_region:
		var region_start: float = Project.data.render_region.x * Timeline.zoom
		var region_end: float = Project.data.render_region.y * Timeline.zoom
		var alpha: float = 0.7 if Project.data.use_render_region else 0.2
		if region_end >= region_start:
			draw_rect(Rect2(region_start, 0, region_end - region_start, 4), Color(0.65, 0.1, 0.95, alpha))


func _update_tooltip() -> void:
	var mouse_x: float = get_local_mouse_position().x
	if mouse_x < 0 or mouse_x > size.x:
		if tooltip_text != "":
			tooltip_text = ""
		return # Out of bounds

	var frame_nr: int = maxi(0, floori(mouse_x / Timeline.zoom))
	var time_str: String = Utils.format_time_str_from_frame(frame_nr, Project.data.framerate, false)
	var full_tooltip: String = "%s\n(Frame: %d)" % [time_str, frame_nr]
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


func _update_hovered_marker() -> void:
	var mouse_pos: Vector2 = get_local_mouse_position()
	var found_frame: int = -1

	for frame_nr: int in marker_rects:
		if marker_rects[frame_nr].has_point(mouse_pos):
			found_frame = frame_nr
			break

	if _possible_drag != found_frame:
		_possible_drag = found_frame
		_drag_offset = (found_frame * Timeline.zoom) - mouse_pos.x
		queue_redraw() # Redraw to show highlight if desired.

	if _possible_drag != -1:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func update_stamps() -> void:
	queue_redraw()
