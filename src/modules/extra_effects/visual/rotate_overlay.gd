extends EffectOverlay


enum DragMode { NONE, XY, Z }


const RADIUS_INNER: float = 60.0
const RADIUS_OUTER: float = 80.0


var clip: ClipData
var effect: Effect

var drag_mode: DragMode = DragMode.NONE
var drag_start: Vector3
var drag_start_mouse: Vector2

var drag_prev_angle: float = 0.0
var drag_accumulated_rot: float = 0.0



func initialize(clip_data: ClipData, effect_visual: Effect) -> void:
	clip = clip_data
	effect = effect_visual


func input(event: InputEvent, control: Control) -> void:
	if event is InputEventMouseButton:
		_input_mouse_button(event as InputEventMouseButton, control)
	elif event is InputEventMouseMotion and drag_mode != DragMode.NONE:
		_input_mouse_motion(event as InputEventMouseMotion, control)


func _input_mouse_button(event: InputEventMouseButton, control: Control) -> void:
	var frame: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))
	var x_param: EffectParam = _get_param("x_rotation")
	var y_param: EffectParam = _get_param("y_rotation")
	var z_param: EffectParam = _get_param("z_rotation")

	var current_x: float = effect.get_value(x_param, frame) if x_param else 0.0
	var current_y: float = effect.get_value(y_param, frame) if y_param else 0.0
	var current_z: float = effect.get_value(z_param, frame) if z_param else 0.0

	var center: Vector2 = Vector2(Project.get_resolution_center())
	var control_center: Vector2 = _project_to_control(center, control)

	if event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var dist: float = event.position.distance_to(control_center)
			if dist <= RADIUS_INNER:
				drag_mode = DragMode.XY
				drag_start = Vector3(current_x, current_y, 0.0)
				drag_start_mouse = event.position
				control.accept_event()
			elif dist > RADIUS_INNER and dist <= RADIUS_OUTER + 15.0:
				drag_mode = DragMode.Z
				drag_start = Vector3(0.0, 0.0, current_z)
				drag_prev_angle = control_center.angle_to_point(event.position)
				drag_accumulated_rot = current_z
				control.accept_event()
	else:
		if drag_mode != DragMode.NONE and event.button_index == MOUSE_BUTTON_LEFT:
			var effect_index: int = clip.effects.video.find(effect)

			if drag_mode == DragMode.XY:
				var final_x: float = effect.get_value(x_param, frame)
				var final_y: float = effect.get_value(y_param, frame)
				_set_keyframe_raw(frame, "x_rotation", drag_start.x)
				_set_keyframe_raw(frame, "y_rotation", drag_start.y)

				EffectsHandler.update_param(clip, effect_index, true, "x_rotation", final_x, false)
				EffectsHandler.update_param(clip, effect_index, true, "y_rotation", final_y, false)
			elif drag_mode == DragMode.Z:
				var final_val_z: float = effect.get_value(z_param, frame)
				_set_keyframe_raw(frame, "z_rotation", drag_start.z)
				EffectsHandler.update_param(clip, effect_index, true, "z_rotation", final_val_z, false)
			drag_mode = DragMode.NONE
			control.accept_event()


func _input_mouse_motion(event: InputEventMouseMotion, control: Control) -> void:
	var frame: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))

	if drag_mode == DragMode.XY:
		var delta: Vector2 = event.position - drag_start_mouse
		var new_x: float = drag_start.x - delta.y * 0.5
		var new_y: float = drag_start.y + delta.x * 0.5

		if event.shift_pressed:
			new_x = snappedf(new_x, 15.0)
			new_y = snappedf(new_y, 15.0)

		_set_keyframe_raw(frame, "x_rotation", new_x)
		_set_keyframe_raw(frame, "y_rotation", new_y)

	elif drag_mode == DragMode.Z:
		var center: Vector2 = Vector2(Project.get_resolution_center())
		var control_center: Vector2 = _project_to_control(center, control)
		var current_angle: float = control_center.angle_to_point(event.position)
		var angle_delta: float = rad_to_deg(angle_difference(drag_prev_angle, current_angle))
		drag_prev_angle = current_angle
		drag_accumulated_rot += angle_delta

		var new_z: float = drag_accumulated_rot
		if event.shift_pressed:
			new_z = snappedf(new_z, 15.0)
		_set_keyframe_raw(frame, "z_rotation", new_z)

	control.queue_redraw()
	control.accept_event()


func draw(control: Control) -> void:
	var frame: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))

	var x_param: EffectParam = _get_param("x_rotation")
	var y_param: EffectParam = _get_param("y_rotation")
	var z_param: EffectParam = _get_param("z_rotation")

	var current_x: float = effect.get_value(x_param, frame) if x_param else 0.0
	var current_y: float = effect.get_value(y_param, frame) if y_param else 0.0
	var current_z: float = effect.get_value(z_param, frame) if z_param else 0.0

	var center: Vector2 = Vector2(Project.get_resolution_center())
	var control_center: Vector2 = _project_to_control(center, control)

	control.draw_arc(control_center, RADIUS_OUTER, 0, TAU, 64, Color(0.2, 0.4, 1.0, 0.5), 3.0)

	var z_handle: Vector2 = control_center + Vector2(RADIUS_OUTER, 0).rotated(deg_to_rad(current_z))
	control.draw_circle(z_handle, 8.0, Color(0.2, 0.4, 1.0, 0.8)) # Outline
	control.draw_circle(z_handle, 6.0, Color.WHITE)

	control.draw_circle(control_center, RADIUS_INNER, Color(1, 1, 1, 0.05))
	control.draw_arc(control_center, RADIUS_INNER, 0, TAU, 64, Color(1, 1, 1, 0.2), 1.0)

	var x_axis_dir: Vector2 = Vector2(1, 0).rotated(deg_to_rad(current_z))
	var y_axis_dir: Vector2 = Vector2(0, 1).rotated(deg_to_rad(current_z))

	control.draw_line(control_center - x_axis_dir * RADIUS_INNER, control_center + x_axis_dir * RADIUS_INNER, Color(1.0, 0.2, 0.2, 0.4), 2.0)
	control.draw_line(control_center - y_axis_dir * RADIUS_INNER, control_center + y_axis_dir * RADIUS_INNER, Color(0.2, 1.0, 0.2, 0.4), 2.0)


func _set_keyframe_raw(frame: int, param_id: String, value: Variant) -> void:
	if not effect.keyframes.has(param_id):
		effect.keyframes[param_id] = {}

	var target_frame: int = frame
	var param_keyframes: Dictionary = effect.keyframes[param_id]
	if param_keyframes.size() <= 1 and not param_keyframes.has(frame):
		target_frame = 0

	effect.keyframes[param_id][target_frame] = value
	effect._cache_dirty = true
	EffectsHandler.effect_values_updated.emit()


func _get_param(id: String) -> EffectParam:
	for effect_param: EffectParam in effect.params:
		if effect_param.id == id: return effect_param
	return null


func _project_to_control(project_position: Vector2, control: Control) -> Vector2:
	var ratio: Vector2 = control.size / Vector2(Project.data.resolution)
	return project_position * ratio
