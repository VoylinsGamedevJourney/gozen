extends EffectOverlay

var clip: ClipData
var effect: Effect

var drag_index: int = -1
var hovered_index: int = -1
var drag_start_val: PackedVector2Array

var _err: int = 0 ## Useless stuff to get rid of return warnings.



func initialize(clip_data: ClipData, effect_visual: Effect) -> void:
	clip = clip_data
	effect = effect_visual


func _get_points(frame: int) -> PackedVector2Array:
	var param: EffectParam = _get_param("points")
	return effect.get_value(param, frame) if param else PackedVector2Array()


func input(event: InputEvent, control: Control) -> void:
	var frame: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))
	var points: PackedVector2Array = _get_points(frame)

	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = (event as InputEventMouseMotion).position
		if drag_index != -1:
			var new_points: PackedVector2Array = points.duplicate()
			var normalized_pos: Vector2 = _control_to_project(mouse_pos, control) / Vector2(Project.data.resolution)
			new_points[drag_index] = normalized_pos
			_set_keyframe_raw(frame, "points", new_points)
			control.queue_redraw()
			control.accept_event()
		else:
			var new_hovered: int = -1
			for i: int in points.size():
				var screen_pt: Vector2 = _project_to_control(points[i] * Vector2(Project.data.resolution), control)
				if mouse_pos.distance_to(screen_pt) < 10.0:
					new_hovered = i
					break
			if hovered_index != new_hovered:
				hovered_index = new_hovered
				control.queue_redraw()

	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		var mouse_pos: Vector2 = mouse_event.position
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if hovered_index != -1:
					drag_index = hovered_index
					drag_start_val = points.duplicate()
					control.accept_event()
				elif points.size() < 64: # Maximum 64 points supported by uniform array
					var normalized_pos: Vector2 = _control_to_project(mouse_pos, control) / Vector2(Project.data.resolution)
					var insert_idx: int = points.size()
					if points.size() >= 3:
						insert_idx = _get_closest_segment_index(mouse_pos, points, control) + 1

					@warning_ignore_start("unsafe_method_access")
					var old_keyframes: Dictionary = effect.keyframes.get("points", {}).duplicate(true)
					var new_keyframes: Dictionary = effect.keyframes.get("points", {}).duplicate(true)
					var is_multi_keyframe: bool = new_keyframes.size() > 1
					@warning_ignore_restore("unsafe_method_access")

					var safe_insert_index: int

					if not is_multi_keyframe:
						for keyframe: int in new_keyframes:
							@warning_ignore("unsafe_method_access")
							var pts: PackedVector2Array = new_keyframes[keyframe].duplicate()
							safe_insert_index = mini(insert_idx, pts.size())
							_err = pts.insert(safe_insert_index, normalized_pos)
							new_keyframes[keyframe] = pts
						if new_keyframes.is_empty():
							var pts: PackedVector2Array = points.duplicate()
							safe_insert_index = mini(insert_idx, pts.size())
							_err = pts.insert(safe_insert_index, normalized_pos)
							new_keyframes[0] = pts
					else:
						for keyframe: int in new_keyframes:
							@warning_ignore("unsafe_method_access")
							var pts: PackedVector2Array = new_keyframes[keyframe].duplicate()
							safe_insert_index = mini(insert_idx, pts.size())
							if pts.size() < 3:
								_err = pts.insert(safe_insert_index, normalized_pos)
							else:
								var prev_idx: int = safe_insert_index - 1
								if prev_idx < 0:
									prev_idx = pts.size() - 1
								var next_idx: int = safe_insert_index % pts.size()
								var mid: Vector2 = (pts[prev_idx] + pts[next_idx]) / 2.0
								_err = pts.insert(safe_insert_index, mid)
							new_keyframes[keyframe] = pts

						var keyframe_points: PackedVector2Array = points.duplicate()
						safe_insert_index = mini(insert_idx, keyframe_points.size())
						_err = keyframe_points.insert(safe_insert_index, normalized_pos)
						new_keyframes[frame] = keyframe_points

					InputManager.undo_redo.create_action("Add Mask Point")
					InputManager.undo_redo.add_do_method(_apply_keyframes.bind("points", new_keyframes))
					InputManager.undo_redo.add_undo_method(_apply_keyframes.bind("points", old_keyframes))
					InputManager.undo_redo.commit_action()

					drag_index = insert_idx
					drag_start_val = _get_points(frame).duplicate()
					control.queue_redraw()
					control.accept_event()
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				if hovered_index != -1:
					@warning_ignore_start("unsafe_method_access")
					var old_keyframes: Dictionary = effect.keyframes.get("points", {}).duplicate(true)
					var new_keyframes: Dictionary = effect.keyframes.get("points", {}).duplicate(true)
					@warning_ignore_restore("unsafe_method_access")

					for keyframe: int in new_keyframes:
						@warning_ignore("unsafe_method_access")
						var pts: PackedVector2Array = new_keyframes[keyframe].duplicate()
						if hovered_index < pts.size():
							pts.remove_at(hovered_index)
						new_keyframes[keyframe] = pts

					if new_keyframes.is_empty():
						var pts: PackedVector2Array = points.duplicate()
						if hovered_index < pts.size():
							pts.remove_at(hovered_index)
						new_keyframes[0] = pts

					InputManager.undo_redo.create_action("Remove Mask Point")
					InputManager.undo_redo.add_do_method(_apply_keyframes.bind("points", new_keyframes))
					InputManager.undo_redo.add_undo_method(_apply_keyframes.bind("points", old_keyframes))
					InputManager.undo_redo.commit_action()

					hovered_index = -1
					control.queue_redraw()
					control.accept_event()
		else:
			if drag_index != -1 and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				var effect_index: int = clip.effects.video.find(effect)
				var final_val: PackedVector2Array = _get_points(frame)
				_set_keyframe_raw(frame, "points", drag_start_val)
				EffectsHandler.update_param(clip, effect_index, true, "points", final_val, false)
				drag_index = -1
				control.accept_event()


func draw(control: Control) -> void:
	var frame: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))
	var points: PackedVector2Array = _get_points(frame)

	if points.size() > 0:
		var screen_pts: PackedVector2Array = PackedVector2Array()
		for pt: Vector2 in points:
			_err = screen_pts.append(_project_to_control(pt * Vector2(Project.data.resolution), control))

		# Draw the lines connecting the points
		for i: int in screen_pts.size():
			var next_i: int = (i + 1) % screen_pts.size()
			if screen_pts.size() > 2 or i < screen_pts.size() - 1:
				control.draw_line(screen_pts[i], screen_pts[next_i], Color(0.8, 0.2, 0.8, 0.8), 2.0)

		# Draw the points themselves
		for i: int in screen_pts.size():
			var color: Color = Color.RED if i == hovered_index else Color.WHITE
			var radius: float = 6.0 if i == hovered_index else 4.0
			control.draw_circle(screen_pts[i], radius + 2.0, Color(0.0, 0.0, 0.0, 0.5))
			control.draw_circle(screen_pts[i], radius, color)


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


func _apply_keyframes(param_id: String, keyframes: Dictionary) -> void:
	effect.keyframes[param_id] = keyframes.duplicate(true)
	effect._cache_dirty = true
	EffectsHandler.effect_values_updated.emit()


func _get_param(id: String) -> EffectParam:
	for effect_param: EffectParam in effect.params:
		if effect_param.id == id: return effect_param
	return null


func _project_to_control(project_position: Vector2, control: Control) -> Vector2:
	var ratio: Vector2 = control.size / Vector2(Project.data.resolution)
	return project_position * ratio


func _control_to_project(control_delta: Vector2, control: Control) -> Vector2:
	var ratio: Vector2 = Vector2(Project.data.resolution) / control.size
	return control_delta * ratio


func _get_closest_segment_index(point: Vector2, points: PackedVector2Array, control: Control) -> int:
	var best_index: int = -1
	var min_distance: float = INF

	for i: int in points.size():
		var next_i: int = (i + 1) % points.size()
		var point_1: Vector2 = _project_to_control(points[i] * Vector2(Project.data.resolution), control)
		var point_2: Vector2 = _project_to_control(points[next_i] * Vector2(Project.data.resolution), control)

		var length_squared: float = point_1.distance_squared_to(point_2)
		var segment: float = 0.0
		if length_squared != 0.0:
			segment = max(0.0, min(1.0, (point - point_1).dot(point_2 - point_1) / length_squared))
		var projection: Vector2 = point_1 + segment * (point_2 - point_1)
		var distance: float = point.distance_to(projection)

		if distance < min_distance:
			min_distance = distance
			best_index = i

	return best_index
