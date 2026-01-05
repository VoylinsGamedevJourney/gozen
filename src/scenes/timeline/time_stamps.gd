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


@onready var scroll: ScrollContainer = get_parent()
@export var timeline_scroll: ScrollContainer = get_parent()


var current_zoom: float = 1.0
var scrubbing: bool = false

var marker_style_box: StyleBoxFlat
var marker_rects: Dictionary[int, Rect2] = {} # { frame_nr: hitbox }

var _possible_drag: int = -1
var _drag_offset: float = 0.0
var _drag_start_pos: Vector2 = Vector2.ZERO



func _ready() -> void:
	Project.project_ready.connect(queue_redraw)
	scroll.get_h_scroll_bar().value_changed.connect(_force_refresh)
	timeline_scroll.get_h_scroll_bar().value_changed.connect(_force_refresh)

	MarkerHandler.marker_added.connect(_force_refresh)
	MarkerHandler.marker_updated.connect(_force_refresh)
	MarkerHandler.marker_removed.connect(_force_refresh)

	_setup_marker_style_box()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_mouse_button(event)
	elif event is InputEventMouseMotion:
		if MarkerHandler.dragged_marker != -1:
			queue_redraw()
		elif scrubbing:
			_seek_to_mouse()
		else:
			_update_hovered_marker()
			_update_tooltip()


func _on_left_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		_update_hovered_marker()

		if _possible_drag != -1:
			_drag_start_pos = get_local_mouse_position()
			MarkerHandler.dragged_marker = _possible_drag
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			scrubbing = false
		else:
			scrubbing = true
			_seek_to_mouse()
	else: # Mouse released
		if MarkerHandler.dragged_marker != -1:
			var new_frame_nr: int = MarkerHandler.dragged_marker

			if MarkerHandler.dragged_marker_offset != 0:
				new_frame_nr = floori(MarkerHandler.dragged_marker_offset / current_zoom)

			if new_frame_nr != MarkerHandler.dragged_marker:
				MarkerHandler.update_marker(
						MarkerHandler.dragged_marker,
						new_frame_nr,
						MarkerHandler.get_marker(MarkerHandler.dragged_marker))
			else:
				EditorCore.set_frame(MarkerHandler.dragged_marker)
				PopupManager.open_popup(PopupManager.POPUP.MARKER)

			MarkerHandler.dragged_marker = -1
			MarkerHandler.dragged_marker_offset = 0
			queue_redraw()
		scrubbing = false


func _get_frame_on_mouse() -> int:
	return maxi(0, floori(get_local_mouse_position().x / current_zoom))


func _seek_to_mouse() -> void:
	EditorCore.set_frame(_get_frame_on_mouse())


func _draw() -> void:
	var visible_start_nr: int = int(scroll.scroll_horizontal / current_zoom)
	var visible_end_nr: int = int((scroll.scroll_horizontal + size.x) / current_zoom) + 1

	var major_step: int = _get_major_frame_step()
	var minor_step: int = int(major_step / 5.0)

	var start_frame: int = visible_start_nr - (visible_start_nr % minor_step)

	var font: Font = get_theme_default_font()

	# - Draw ticks and time text
	for frame: int in range(start_frame, visible_end_nr, minor_step):
		var x: float = frame * current_zoom

		if x < scroll.scroll_horizontal - 100 or x > scroll.scroll_horizontal + size.x + 100:
			continue

		var is_major: int = frame % major_step == 0
		var tick_h: int = 12 if is_major else 6

		if is_major:
			draw_string(
				font,
				Vector2(x + 4, size.y - 8),
				Utils.format_time_str_from_frame(frame, Project.get_framerate(), true),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				FONT_SIZE_TIME_STAMP,
				COLOR_TEXT)

		draw_line(
			Vector2(x, size.y),
			Vector2(x, size.y - tick_h),
			COLOR_TICK
		)

	# - Draw markers
	marker_rects.clear()

	for frame_nr: int in MarkerHandler.markers.keys():
		var is_being_dragged: bool = frame_nr == MarkerHandler.dragged_marker

		if !is_being_dragged and frame_nr < visible_start_nr or frame_nr > visible_end_nr:
			continue # Only visible markers and the one being dragged get drawn
			
		var marker_data: MarkerData = MarkerHandler.markers[frame_nr]
		var color: Color = Settings.get_marker_color(marker_data.type_id)
		var pos_x: float = frame_nr * current_zoom

		var text: String = marker_data.text
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_MARKER)
		var text_y_offset: float = (MARKER_HANDLE_HEIGHT - text_size.y) / 2.0 + font.get_ascent(FONT_SIZE_MARKER)

		if is_being_dragged:
			if get_local_mouse_position().distance_to(_drag_start_pos) > MARKER_DRAG_THRESHOLD:
				MarkerHandler.dragged_marker_offset = _get_frame_on_mouse() * current_zoom + _drag_offset
				pos_x = MarkerHandler.dragged_marker_offset
			else:
				MarkerHandler.dragged_marker_offset = 0
			marker_style_box.bg_color = color * Color(1.0, 1.0, 1.0, 0.2)

		var bubble_width: float = text_size.x + (MARKER_PADDING * 2)
		var bubble_rect: Rect2 = Rect2(
			pos_x + (MARKER_LINE_WIDTH / 2.0), 
			0, 
			bubble_width, 
			MARKER_HANDLE_HEIGHT)

		if !is_being_dragged:
			marker_rects[frame_nr] = bubble_rect
			marker_style_box.bg_color = color * Color(1.0, 1.0, 1.0, 0.5)
		
		draw_line(
			Vector2(pos_x, 0),
			Vector2(pos_x, size.y),
			color,
			MARKER_LINE_WIDTH)
		draw_style_box(marker_style_box, bubble_rect)
		draw_string(
			font,
			Vector2(pos_x + MARKER_PADDING, text_y_offset),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			FONT_SIZE_MARKER,
			Color.WHITE if color.get_luminance() < 0.5 else Color.BLACK)


func _update_tooltip() -> void:
	var mouse_x: float = get_local_mouse_position().x

	if mouse_x < 0 or mouse_x > size.x:
		if tooltip_text != "":
			tooltip_text = ""
		return # Out of bounds

	var frame_nr: int = maxi(0, floori(mouse_x / current_zoom))
	var time_str: String = Utils.format_time_str_from_frame(frame_nr, Project.get_framerate(), false)
	var full_tooltip: String = "%s\n(Frame: %d)" % [time_str, frame_nr]

	if tooltip_text != full_tooltip:
		tooltip_text = full_tooltip


func _force_refresh(_x: float = 0., _y: float = 0.) -> void:
	queue_redraw()


func _on_timeline_zoom_changed(new_zoom: float) -> void:
	current_zoom = new_zoom
	queue_redraw()


func _get_major_frame_step() -> int:
	# 120 pixels between major ticks
	var frames: float =  120.0 / current_zoom

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
		_drag_offset = (found_frame * current_zoom) - mouse_pos.x
		queue_redraw() # Redraw to show highlight if desired
	
	if _possible_drag != -1:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

