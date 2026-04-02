class_name KeyframeTrack
extends ColorRect

signal keyframe_moved_effect(old_frame: int, new_frame: int, preserve_existing: bool, is_copy: bool)
signal keyframe_deleted_effect(frame: int)
signal keyframe_dragged_to(frame: int)


const MARGIN: float = 8.0
const KEYFRAME_RADIUS: float = 6.0
const KEYFRAME_COLOR: Color = Color(0.8, 0.8, 0.8)
const SELECTED_COLOR: Color = Color(1.0, 0.6, 0.2)
const TRACK_BAR_COLOR: Color = Color(0.1, 0.1, 0.1, 0.5)


const MIN_ZOOM: float = 0.01
const MAX_ZOOM: float = 200.0


var effect: Effect
var clip_duration: int
var current_relative_frame: int = 0

var zoom: float = 1.0

var _hovered_frame: int = -1
var _dragged_frame: int = -1
var _is_dragging: bool = false
var _is_scrubbing: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO



func _init() -> void:
	color = Color("ffffff7c")


func setup(p_effect: Effect, p_duration: int, p_current_frame: int) -> void:
	effect = p_effect
	clip_duration = p_duration
	current_relative_frame = p_current_frame
	custom_minimum_size.y = 16
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action("timeline_zoom_in") and event.is_pressed():
		set_zoom(zoom * 1.2, get_local_mouse_position().x)
		accept_event()
		return
	elif event.is_action("timeline_zoom_out") and event.is_pressed():
		set_zoom(zoom / 1.2, get_local_mouse_position().x)
		accept_event()
		return

	if event is InputEventMouseMotion:
		var mouse_x: float = get_local_mouse_position().x
		var frame: int = _get_frame_at_x(mouse_x)

		if _is_dragging:
			if get_local_mouse_position().distance_to(_drag_start_pos) > 3.0:
				frame = clampi(frame, 0, clip_duration)
				keyframe_dragged_to.emit(frame)
				queue_redraw()
		elif _is_scrubbing:
			frame = clampi(frame, 0, clip_duration - 1)
			keyframe_dragged_to.emit(frame)
			queue_redraw()
		else:
			_hovered_frame = _find_closest_keyframe(frame)
			if _hovered_frame != -1:
				mouse_default_cursor_shape = CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = CURSOR_ARROW
			queue_redraw()

	if event is not InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event
	if mouse_event.pressed:
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _hovered_frame != -1:
				_is_dragging = true
				_dragged_frame = _hovered_frame
				_drag_start_pos = get_local_mouse_position()
				keyframe_dragged_to.emit(_dragged_frame)
			else:
				_is_scrubbing = true
				var mouse_x: float = get_local_mouse_position().x
				var frame: int = clampi(_get_frame_at_x(mouse_x), 0, clip_duration)
				keyframe_dragged_to.emit(frame)
				queue_redraw()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and _hovered_frame > 0:
			keyframe_deleted_effect.emit(_hovered_frame)
			_hovered_frame = -1
			mouse_default_cursor_shape = CURSOR_ARROW
			queue_redraw()

	elif not mouse_event.pressed:
		if _is_dragging and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var final_pos: Vector2 = get_local_mouse_position()
			var new_frame: int = clampi(_get_frame_at_x(final_pos.x), 0, clip_duration)

			if _dragged_frame != -1 and new_frame != _dragged_frame and final_pos.distance_to(_drag_start_pos) > 3.0:
				var preserve_existing: bool = Input.is_key_pressed(KEY_ALT)
				var is_copy: bool = Input.is_key_pressed(KEY_CTRL)
				keyframe_moved_effect.emit(_dragged_frame, new_frame, preserve_existing, is_copy)
			_is_dragging = false
			_dragged_frame = -1
			queue_redraw()
		elif _is_scrubbing and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_is_scrubbing = false
			EditorCore.finish_scrub()


func _draw() -> void:
	var width: float = size.x - (MARGIN * 2)
	var mid_y: float = size.y / 2.0

	draw_rect(Rect2(MARGIN, mid_y - 2, width, 4), TRACK_BAR_COLOR)

	if clip_duration > 0:
		var line_color: Color = TRACK_BAR_COLOR
		line_color.a = 0.8
		var max_frame: float = maxf(1.0, float(clip_duration - 1))
		var pixels_per_frame: float = width / max_frame
		var step: int = maxi(1, int(5.0 / pixels_per_frame))
		for i: int in range(0, clip_duration, step):
			var frame_x: float = MARGIN + (float(i) / max_frame) * width
			var line_h: float = 6.0 if i % (step * 5) == 0 else 3.0
			draw_line(Vector2(frame_x, mid_y - 2 - line_h), Vector2(frame_x, mid_y - 2), line_color, 1.0)

		var playhead_x: float = MARGIN + (float(current_relative_frame) / max_frame) * width
		playhead_x = clamp(playhead_x, MARGIN, size.x - MARGIN)
		draw_line(Vector2(playhead_x, 2), Vector2(playhead_x, size.y - 2), Color(1, 1, 1, 0.5), 1.0)
		draw_line(Vector2(playhead_x + 1, 2), Vector2(playhead_x + 1, size.y - 2), Color(1, 1, 1, 0.3), 1.0)
	if not effect:
		return

	var unique_frames: Dictionary = {}
	for param: EffectParam in effect.params:
		if param.keyframeable and effect.keyframes.has(param.id):
			for frame: int in effect.keyframes[param.id]:
				unique_frames[int(frame)] = true

	for frame_int: int in unique_frames.keys():
		var draw_frame_val: int = frame_int

		# If dragging this specific keyframe, verify position based on mouse.
		if _is_dragging and frame_int == _dragged_frame:
			if get_local_mouse_position().distance_to(_drag_start_pos) > 3.0:
				draw_frame_val = clampi(_get_frame_at_x(get_local_mouse_position().x), 0, clip_duration)

		var max_frame: float = maxf(1.0, float(clip_duration - 1))
		var ratio: float = float(draw_frame_val) / max_frame
		var pos: Vector2 = Vector2(MARGIN + (ratio * width), mid_y)
		var keyframe_color: Color = KEYFRAME_COLOR

		if frame_int == _hovered_frame or (_is_dragging and frame_int == _dragged_frame):
			keyframe_color = SELECTED_COLOR

		var points: PackedVector2Array = [
			pos + Vector2(0, -KEYFRAME_RADIUS),
			pos + Vector2(KEYFRAME_RADIUS, 0),
			pos + Vector2(0, KEYFRAME_RADIUS),
			pos + Vector2(-KEYFRAME_RADIUS, 0)
		]
		draw_colored_polygon(points, keyframe_color)
		draw_polyline(points, keyframe_color.darkened(0.2), 1.0)


func _get_frame_at_x(x_pos: float) -> int:
	var width: float = size.x - (MARGIN * 2)
	if width <= 0:
		return 0

	var ratio: float = (x_pos - MARGIN) / width
	return int(ratio * (clip_duration - 1))


func _find_closest_keyframe(target_frame: int) -> int:
	if not effect:
		return -1

	var width: float = size.x - (MARGIN * 2)
	var pixel_per_frame: float = width / maxf(1.0, float(clip_duration - 1))
	var threshold_frames: int = int(8.0 / pixel_per_frame)
	if threshold_frames < 2:
		threshold_frames = 2

	# Check all params for closest frame.
	var found_frame: int = -1
	var min_dist: int = 9999999
	for param: EffectParam in effect.params:
		if !effect.keyframes.has(param.id) or !param.keyframeable:
			continue
		for frame: int in effect.keyframes[param.id]:
			var dist: int = abs(frame - target_frame)
			if dist <= threshold_frames and dist < min_dist:
				min_dist = dist
				found_frame = frame
	return found_frame


func set_zoom(new_zoom: float, mouse_x: float) -> void:
	var scroll: ScrollContainer = get_parent() as ScrollContainer
	if not scroll:
		return

	var old_zoom: float = zoom
	zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)

	if zoom == old_zoom:
		return

	var base_width: float = scroll.size.x
	if zoom > 1.0:
		custom_minimum_size.x = base_width * zoom
	else:
		custom_minimum_size.x = 0

	if mouse_x >= 0:
		var zoom_ratio: float = zoom / old_zoom
		var mouse_viewport_offset: float = mouse_x - scroll.scroll_horizontal
		var new_mouse_x: float = mouse_x * zoom_ratio
		_update_scroll.call_deferred(scroll, int(new_mouse_x - mouse_viewport_offset))

	queue_redraw()


func _update_scroll(scroll: ScrollContainer, val: int) -> void:
	scroll.scroll_horizontal = val
