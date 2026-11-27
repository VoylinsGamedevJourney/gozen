extends HBoxContainer


const MIN_VALUE: float = -100000.0
const MAX_VALUE: float = 100000.0


@export var spinbox: SpinBox
@export var circle: Control

var param: EffectParam
var update_call: Callable
var current_value: float = 0.0

var _is_dragging: bool = false
var _drag_prev_angle_rad: float = 0.0
var _drag_accumulated_angle: float = 0.0



func setup(effect_param: EffectParam, update: Callable, value: Variant) -> void:
	param = effect_param
	update_call = update
	current_value = value as float

	spinbox.min_value = param.min_value if param.min_value != null else MIN_VALUE
	spinbox.max_value = param.max_value if param.max_value != null else MAX_VALUE
	spinbox.step = param.step if param.step > 0.0 else 1.0
	spinbox.allow_lesser = param.min_value == null
	spinbox.allow_greater = param.max_value == null
	spinbox.value = current_value

	var scroll_handler: Callable = func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				var mouse_event: InputEventMouseButton = event
				if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
					if mouse_event.pressed:
						spinbox.value += spinbox.step if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else -spinbox.step
					spinbox.accept_event()

	spinbox.gui_input.connect(scroll_handler)
	spinbox.get_line_edit().gui_input.connect(scroll_handler)
	spinbox.value_changed.connect(_on_spinbox_value_changed)
	circle.gui_input.connect(_on_circle_gui_input)
	circle.draw.connect(_on_circle_draw)


func set_value(value: Variant) -> void:
	current_value = value as float
	spinbox.set_value_no_signal(current_value)
	circle.queue_redraw()


func _on_spinbox_value_changed(value: float) -> void:
	if spinbox.get_line_edit().has_focus():
		spinbox.get_line_edit().release_focus()
	current_value = value
	circle.queue_redraw()
	if update_call.is_valid():
		update_call.call(current_value)


func _on_circle_gui_input(event: InputEvent) -> void:
	var center: Vector2 = circle.size / 2.0

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_is_dragging = true
				var pointer_offset: Vector2 = mouse_button.position - center
				if pointer_offset.length_squared() > 0.0001:
					var clicked_angle_rad: float = atan2(pointer_offset.x, -pointer_offset.y)
					var current_angle_rad: float = deg_to_rad(current_value)
					var initial_delta_deg: float = rad_to_deg(angle_difference(current_angle_rad, clicked_angle_rad))
					_drag_prev_angle_rad = clicked_angle_rad
					_drag_accumulated_angle = current_value + initial_delta_deg
					_apply_drag_angle(_drag_accumulated_angle)
				else:
					_drag_prev_angle_rad = deg_to_rad(current_value)
					_drag_accumulated_angle = current_value
				circle.accept_event()
			elif _is_dragging:
				_is_dragging = false
				circle.accept_event()
		elif mouse_button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if mouse_button.pressed:
				var step_amount: float = spinbox.step * (15.0 if mouse_button.shift_pressed else 1.0)
				var scroll_direction: float = 1.0 if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				var target_angle: float = current_value + (step_amount * scroll_direction)
				_drag_accumulated_angle = target_angle
				_apply_drag_angle(target_angle, false)
			circle.accept_event()
		return


	if event is InputEventMouseMotion and _is_dragging:
		if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_is_dragging = false
			return

		var mouse_motion: InputEventMouseMotion = event
		var pointer_offset: Vector2 = mouse_motion.position - center
		if pointer_offset.length_squared() > 0.0001:
			var current_angle_rad: float = atan2(pointer_offset.x, -pointer_offset.y)
			var angle_delta_deg: float = rad_to_deg(angle_difference(_drag_prev_angle_rad, current_angle_rad))
			_drag_prev_angle_rad = current_angle_rad
			_drag_accumulated_angle += angle_delta_deg
			_apply_drag_angle(_drag_accumulated_angle)
		circle.accept_event()


func _apply_drag_angle(target_angle: float, allow_ctrl_snap: bool = true) -> void:
	var final_angle: float = target_angle
	if allow_ctrl_snap and Input.is_key_pressed(KEY_CTRL):
		final_angle = snappedf(final_angle, 90.0)

	if param.min_value != null and param.max_value != null:
		final_angle = wrapf(final_angle, param.min_value as float, param.max_value as float)
	else:
		if param.min_value != null:
			final_angle = maxf(final_angle, param.min_value as float)
		if param.max_value != null:
			final_angle = minf(final_angle, param.max_value as float)

	if not is_equal_approx(current_value, final_angle):
		current_value = final_angle
		spinbox.value = current_value
		circle.queue_redraw()


func _on_circle_draw() -> void:
	var center: Vector2 = circle.size / 2.0
	var radius: float = min(circle.size.x, circle.size.y) / 2.0 - 2.0
	var angle_rad: float = deg_to_rad(current_value)

	circle.draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, 0.2), 2.0)
	var dot_pos: Vector2 = center + Vector2(sin(angle_rad), -cos(angle_rad)) * radius
	circle.draw_line(center, dot_pos, Color(0.8, 0.2, 0.8, 0.8), 2.0)
	circle.draw_circle(dot_pos, 4.0, Color.WHITE)
