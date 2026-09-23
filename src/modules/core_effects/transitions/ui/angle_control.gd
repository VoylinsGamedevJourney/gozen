extends HBoxContainer


@export var spinbox: SpinBox
@export var circle: Control

var param: EffectParam
var update_call: Callable
var current_value: float = 0.0



func setup(effect_param: EffectParam, update: Callable, value: Variant) -> void:
	param = effect_param
	update_call = update
	current_value = value as float

	spinbox.min_value = param.min_value if param.min_value != null else 0.0
	spinbox.max_value = param.max_value if param.max_value != null else 360.0
	spinbox.step = param.step if param.step > 0.0 else 1.0
	spinbox.allow_lesser = param.min_value == null
	spinbox.allow_greater = param.max_value == null
	spinbox.value = current_value

	spinbox.value_changed.connect(_on_spinbox_value_changed)
	circle.gui_input.connect(_on_circle_gui_input)
	circle.draw.connect(_on_circle_draw)


func set_value(value: Variant) -> void:
	current_value = value as float
	spinbox.set_value_no_signal(current_value)
	circle.queue_redraw()


func _on_spinbox_value_changed(value: float) -> void:
	current_value = value
	circle.queue_redraw()
	if update_call.is_valid():
		update_call.call(current_value)


func _on_circle_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseMotion:
		return

	var mouse_event: InputEventMouse = event
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if event is not InputEventMouseButton:
			return

		var mouse_button: InputEventMouseButton = event
		if !(mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed):
			return

	var center: Vector2 = circle.size / 2.0
	var dir: Vector2 = (mouse_event.position - center).normalized()
	var angle: float = rad_to_deg(atan2(dir.x, -dir.y))

	if angle < 0:
		angle += 360.0

	if Input.is_key_pressed(KEY_CTRL):
		angle = snappedf(angle, 90.0)

	if current_value != angle:
		current_value = angle
		spinbox.value = current_value
		circle.queue_redraw()
	circle.accept_event()


func _on_circle_draw() -> void:
	var center: Vector2 = circle.size / 2.0
	var radius: float = min(circle.size.x, circle.size.y) / 2.0 - 2.0
	var angle_rad: float = deg_to_rad(current_value)

	circle.draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, 0.2), 2.0)
	var dot_pos: Vector2 = center + Vector2(sin(angle_rad), -cos(angle_rad)) * radius
	circle.draw_line(center, dot_pos, Color(0.8, 0.2, 0.8, 0.8), 2.0)
	circle.draw_circle(dot_pos, 4.0, Color.WHITE)
