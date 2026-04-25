extends EffectVisualOverlay


enum DragMode { NONE, POSITION, ROTATION }


var clip: ClipData
var effect: EffectVisual

var drag_mode: DragMode = DragMode.NONE
var drag_start_val: Variant
var drag_start_mouse: Vector2

# Variables for unbounded rotation tracking.
var drag_prev_angle: float = 0.0
var drag_accumulated_rot: float = 0.0



func initialize(clip_data: ClipData, effect_visual: EffectVisual) -> void:
	clip = clip_data
	effect = effect_visual


#--- Input logic ---

func input(event: InputEvent, control: Control) -> void:
	if event is InputEventMouseButton:
		_input_mouse_button(event as InputEventMouseButton, control)
	elif event is InputEventMouseMotion and drag_mode != DragMode.NONE:
		_input_mouse_motion(event as InputEventMouseMotion, control)


func _input_mouse_button(event: InputEventMouseButton, control: Control) -> void:
	var frame: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))
	var position_param: EffectParam = _get_param("position")
	var current_pos: Vector2 = effect.get_value(position_param, frame) if position_param else Vector2.ZERO
	var rotation_param: EffectParam = _get_param("rotation")
	var current_rot: float = effect.get_value(rotation_param, frame) if rotation_param else 0.0
	var center: Vector2 = Vector2(Project.get_resolution_center()) + current_pos
	var control_center: Vector2 = _project_to_control(center, control)
	var rot_handle_pos: Vector2 = control_center + Vector2(25.0, 0).rotated(deg_to_rad(current_rot))

	if event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var rotation_distance: float = event.position.distance_to(rot_handle_pos)
			if rotation_distance <= 10.0 and rotation_param:
				drag_mode = DragMode.ROTATION
				drag_start_val = current_rot
				drag_prev_angle = control_center.angle_to_point(event.position)
				drag_accumulated_rot = current_rot
				control.accept_event()
			else:
				drag_mode = DragMode.POSITION
				drag_start_val = current_pos
				drag_start_mouse = event.position
				control.accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			var pivot_param: EffectParam = _get_param("pivot")
			if pivot_param:
				var project_mouse: Vector2 = _control_to_project(event.position, control)
				var new_pivot: Vector2 = project_mouse - current_pos
				_set_keyframe_raw(frame, "pivot", Vector2i(new_pivot))
				var effect_index: int = clip.effects.video.find(effect)
				EffectsHandler.update_param(clip, effect_index, true, "pivot", Vector2i(new_pivot), false)
				control.queue_redraw()
				control.accept_event()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and !event.ctrl_pressed:
			var scale_param: EffectParam = _get_param("scale")
			if scale_param:
				var current_scale: Vector2 = effect.get_value(scale_param, frame)
				var scale_step: float = 0.05 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.05
				var new_scale: Vector2 = current_scale
				new_scale += Vector2(scale_step, scale_step)

				new_scale.x = maxf(0.01, new_scale.x) if new_scale.x >= 0 else minf(-0.01, new_scale.x)
				new_scale.y = maxf(0.01, new_scale.y) if new_scale.y >= 0 else minf(-0.01, new_scale.y)

				_set_keyframe_raw(frame, "scale", new_scale)
				var effect_index: int = clip.effects.video.find(effect)
				EffectsHandler.update_param(clip, effect_index, true, "scale", new_scale, false)
				control.queue_redraw()
				control.accept_event()
	else: # Button released.
		if drag_mode != DragMode.NONE and event.button_index == MOUSE_BUTTON_LEFT:
			var param_name: String = "position" if drag_mode == DragMode.POSITION else "rotation"
			var effect_index: int = clip.effects.video.find(effect)
			var final_val: Variant = effect.get_value(_get_param(param_name), frame)
			_set_keyframe_raw(frame, param_name, drag_start_val)
			EffectsHandler.update_param(clip, effect_index, true, param_name, final_val, false)

			drag_mode = DragMode.NONE
			control.accept_event()


func _input_mouse_motion(event: InputEventMouseMotion, control: Control) -> void:
	var frame: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))
	if drag_mode == DragMode.POSITION:
		var project_delta: Vector2 = _control_to_project(event.position - drag_start_mouse, control)
		var new_position: Vector2 = (drag_start_val as Vector2) + project_delta
		if event.shift_pressed:
			if abs(project_delta.x) > abs(project_delta.y):
				new_position.y = (drag_start_val as Vector2).y
			else:
				new_position.x = (drag_start_val as Vector2).x
		_set_keyframe_raw(frame, "position", Vector2i(new_position))
	elif drag_mode == DragMode.ROTATION:
		var position_param: EffectParam = _get_param("position")
		var current_pos: Vector2 = effect.get_value(position_param, frame) if position_param else Vector2.ZERO
		var center: Vector2 = Vector2(Project.get_resolution_center()) + current_pos
		var control_center: Vector2 = _project_to_control(center, control)
		var current_angle: float = control_center.angle_to_point(event.position)
		var angle_delta: float = rad_to_deg(angle_difference(drag_prev_angle, current_angle))
		drag_prev_angle = current_angle
		drag_accumulated_rot += angle_delta

		var new_rotation: float = drag_accumulated_rot
		if event.shift_pressed:
			new_rotation = snappedf(new_rotation, 15.0)
		_set_keyframe_raw(frame, "rotation", new_rotation)
	control.queue_redraw()
	control.accept_event()


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


func draw(control: Control) -> void:
	var frame: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))

	# - Position.
	var position_param: EffectParam = _get_param("position")
	var current_pos: Vector2 = effect.get_value(position_param, frame) if position_param else Vector2.ZERO
	var center: Vector2 = Vector2(Project.get_resolution_center()) + current_pos
	var control_center: Vector2 = _project_to_control(center, control)

	# - Rotation Ring.
	var rotation_param: EffectParam = _get_param("rotation")
	var current_rot: float = effect.get_value(rotation_param, frame) if rotation_param else 0.0

	control.draw_arc(control_center, 27.0, 0, TAU, 64, Color(0.5, 0.5, 0.5, 0.2), 2.0) # Outline.
	control.draw_arc(control_center, 25.0, 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0)
	var rot_handle: Vector2 = control_center + Vector2(25.0, 0).rotated(deg_to_rad(current_rot))
	control.draw_circle(rot_handle, 8.0, Color.GRAY) # Outline.
	control.draw_circle(rot_handle, 6.0, Color.WHITE)

	# - Position Center.
	control.draw_circle(control_center, 12.0, Color(0.5, 0.5, 0.5, 0.5)) # Outline.
	control.draw_circle(control_center, 10.0, Color(1, 1, 1, 0.3))
	control.draw_arc(control_center, 10.0, 0, TAU, 32, Color.WHITE, 2.0)

	# - Pivot.
	var pivot_param: EffectParam = _get_param("pivot")
	if pivot_param:
		var current_pivot: Vector2 = effect.get_value(pivot_param, frame)
		var pivot_project: Vector2 = current_pivot + current_pos
		var control_pivot: Vector2 = _project_to_control(pivot_project, control)
		var color_outline: Color = Color.DARK_GREEN
		color_outline.a = 0.4

		control.draw_circle(control_pivot, 6.0, color_outline) # Outline.
		control.draw_circle(control_pivot, 4.0, Color.GREEN)
		control.draw_line(control_pivot - Vector2(8, 0), control_pivot + Vector2(8, 0), Color.GREEN, 2.0)
		control.draw_line(control_pivot - Vector2(0, 8), control_pivot + Vector2(0, 8), Color.GREEN, 2.0)


func _get_param(id: String) -> EffectParam:
	for effect_param: EffectParam in effect.params:
		if effect_param.id == id:
			return effect_param
	return null


func _project_to_control(project_position: Vector2, control: Control) -> Vector2:
	var ratio: Vector2 = control.size / Vector2(Project.data.resolution)
	return project_position * ratio


func _control_to_project(control_delta: Vector2, control: Control) -> Vector2:
	var ratio: Vector2 = Vector2(Project.data.resolution) / control.size
	return control_delta * ratio
