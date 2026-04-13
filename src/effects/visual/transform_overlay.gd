extends EffectVisualOverlay

var clip: ClipData
var effect: EffectVisual
var is_dragging: bool = false
var drag_start_val: Vector2 = Vector2.ZERO



func initialize(clip_data: ClipData, effect_visual: EffectVisual) -> void:
	clip = clip_data
	effect = effect_visual


func input(event: InputEvent, control: Control) -> void:
	if event is InputEventMouseButton:
		var event_mouse_button: InputEventMouseButton = event
		if event_mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if event_mouse_button.pressed:
				var position_param: EffectParam = _get_param("position")
				if position_param:
					var frame: int = EditorCore.visual_frame_nr - clip.start
					var position: Vector2 = effect.get_value(position_param, frame)
					is_dragging = true
					drag_start_val = position
					control.accept_event()
			else:
				if is_dragging:
					is_dragging = false
					var position_param: EffectParam = _get_param("position")
					if position_param:
						var frame: int = EditorCore.visual_frame_nr - clip.start
						var current_pos: Vector2 = effect.get_value(position_param, frame)
						_set_keyframe_raw(frame, drag_start_val)
						var effect_index: int = clip.effects.video.find(effect)
						EffectsHandler.update_param(clip, effect_index, true, "position", current_pos, false)
					control.accept_event()

	elif event is InputEventMouseMotion and is_dragging:
		var event_mouse_motion: InputEventMouseMotion = event
		var position_param: EffectParam = _get_param("position")
		if position_param:
			var frame: int = EditorCore.visual_frame_nr - clip.start
			var position: Vector2 = effect.get_value(position_param, frame)
			var project_delta: Vector2 = _control_to_project(event_mouse_motion.relative, control)
			position += project_delta

			_set_keyframe_raw(frame, position)
			control.queue_redraw()
			control.accept_event()


func _set_keyframe_raw(frame: int, position: Vector2) -> void:
	if not effect.keyframes.has("position"):
		effect.keyframes["position"] = {}

	var target_frame: int = frame
	var param_keyframes: Dictionary = effect.keyframes["position"]
	if param_keyframes.size() <= 1 and not param_keyframes.has(frame):
		target_frame = 0

	effect.keyframes["position"][target_frame] = position
	effect._cache_dirty = true
	EffectsHandler.effect_values_updated.emit()


func draw(control: Control) -> void:
	var position_param: EffectParam = _get_param("position")
	if position_param:
		var frame: int = EditorCore.visual_frame_nr - clip.start
		var position: Vector2 = effect.get_value(position_param, frame)
		var center: Vector2 = Vector2(Project.get_resolution_center()) + position
		var control_center: Vector2 = _project_to_control(center, control)

		control.draw_circle(control_center, 10.0, Color(1, 1, 1, 0.3))
		control.draw_arc(control_center, 10.0, 0, TAU, 32, Color.WHITE, 2.0)
		control.draw_line(control_center - Vector2(15, 0), control_center + Vector2(15, 0), Color.WHITE, 2.0)
		control.draw_line(control_center - Vector2(0, 15), control_center + Vector2(0, 15), Color.WHITE, 2.0)


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
