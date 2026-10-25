extends VBoxContainer


enum HoverType { NONE, KEYFRAME, HANDLE_IN, HANDLE_OUT }


@export var param_option: OptionButton
@export var graph: Control
@export var scroll: ScrollContainer
@export var y_axis: Control


var clip: ClipData
var effect: Effect
var is_visual: bool

var current_param_id: String = ""
var current_component: String = ""

var current_zoom_x: float = 5.0
var current_zoom_y: float = 1.0
var graph_value_range: Vector2 = Vector2(0.0, 100.0) ## The vertical bar on the left with values.

var selected_keyframe: int = -1
var hovered_type: HoverType = HoverType.NONE
var hovered_frame: int = -1

var drag_mode: HoverType = HoverType.NONE
var drag_frame: int = -1
var drag_start_frame: int = -1
var drag_start_value: float
var drag_start_mouse_pos: Vector2
var drag_start_keyframes: Dictionary
var drag_start_keyframes_advanced: Dictionary

var _is_scrubbing: bool = false



func setup(_effect: Effect, _clip: ClipData, _is_visual: bool) -> void:
	clip = _clip
	effect = _effect
	is_visual = _is_visual

	param_option.clear()
	var index: int = 0
	for param: EffectParam in effect.params:
		if !param.keyframeable:
			continue

		var value: Variant = param.default_value
		if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_VECTOR2I:
			param_option.add_item(param.nickname + " X", index)
			param_option.set_item_metadata(index, {"id": param.id, "component": "x"})
			index += 1
			param_option.add_item(param.nickname + " Y", index)
			param_option.set_item_metadata(index, {"id": param.id, "component": "y"})
			index += 1
		else:
			param_option.add_item(param.nickname, index)
			param_option.set_item_metadata(index, {"id": param.id, "component": ""})
			index += 1
	param_option.item_selected.connect(_on_param_selected)
	EditorCore.visual_frame_changed.connect(graph.queue_redraw)
	EffectsHandler.effects_updated.connect(_on_effects_updated)
	scroll.resized.connect(_update_graph_size)

	graph.draw.connect(_on_graph_draw)
	graph.gui_input.connect(_on_graph_gui_input)
	graph.mouse_exited.connect(func() -> void:
			hovered_type = HoverType.NONE
			hovered_frame = -1
			graph.queue_redraw())
	y_axis.draw.connect(_on_y_axis_draw)

	if param_option.item_count > 0:
		_on_param_selected(0)


func _on_param_selected(index: int) -> void:
	var metadata: Dictionary = param_option.get_item_metadata(index)
	current_param_id = metadata.id
	current_component = metadata.component
	selected_keyframe = -1
	drag_mode = HoverType.NONE
	current_zoom_y = 1.0

	_update_bounds()
	_update_graph_size()
	graph.queue_redraw()


func _on_effects_updated() -> void:
	if drag_mode == HoverType.NONE:
		hovered_frame = -1
		hovered_type = HoverType.NONE
		_get_advanced_keyframes()
		_update_bounds()
		_update_graph_size()
		graph.queue_redraw()


func _update_bounds() -> void:
	var param: EffectParam = _get_current_param()
	var default_value: float = _get_component_value(param.default_value) if param else 0.0
	graph_value_range.x = default_value
	graph_value_range.y = default_value

	var advanced_keyframes: Dictionary = _get_advanced_keyframes()
	for frame_nr: int in advanced_keyframes:
		var value: float = advanced_keyframes[frame_nr]["value"]
		graph_value_range.x = minf(graph_value_range.x, value)
		graph_value_range.y = maxf(graph_value_range.y, value)

	if param.min_value != null:
		graph_value_range.x = maxf(graph_value_range.x, _get_component_value(param.min_value))
	if param.max_value != null:
		graph_value_range.y = minf(graph_value_range.y, _get_component_value(param.max_value))

	var range_diff: float = maxf(absf(graph_value_range.y - default_value), absf(graph_value_range.x - default_value))
	if range_diff == 0.0:
		range_diff = 10.0

	graph_value_range.x = default_value - range_diff * 1.2 * current_zoom_y
	graph_value_range.y = default_value + range_diff * 1.2 * current_zoom_y
	if is_instance_valid(y_axis):
		y_axis.queue_redraw()


func _update_graph_size() -> void:
	graph.custom_minimum_size.x = maxf(scroll.size.x, clip.duration * current_zoom_x)


#--- Keyframes & curve stuff ---

func _get_advanced_keyframes(component: String = current_component) -> Dictionary:
	var hidden_keyframe_id: String = "_adv_" + current_param_id + "_" + component
	if not effect.keyframes.has(hidden_keyframe_id):
		var advanced_keyframes: Dictionary = {}
		var velocities: Dictionary = {}
		if "velocities" in effect:
			velocities = effect.get("velocities")
		elif effect.has_meta("velocities"):
			velocities = effect.get_meta("velocities")

		if effect.keyframes.has(current_param_id):
			var original_keyframes: Dictionary = effect.keyframes[current_param_id]
			for frame_nr: int in original_keyframes:
				var handle_data: Vector4 = Vector4(0.33, 0.0, 0.33, 0.0)
				var velocity_key: String = current_param_id + ":" + component + ":" + str(frame_nr)
				if velocities.has(velocity_key):
					handle_data = velocities[velocity_key]
				elif velocities.has(frame_nr):
					var legacy_handle_data: Vector4 = velocities[frame_nr]
					handle_data = Vector4(legacy_handle_data.x, 0.0, legacy_handle_data.z, 0.0)

				advanced_keyframes[frame_nr] = {
					"value": _get_component_value(original_keyframes[frame_nr], component),
					"in_x": handle_data.x,
					"in_y": handle_data.y,
					"out_x": handle_data.z,
					"out_y": handle_data.w
				}
		effect.keyframes[hidden_keyframe_id] = advanced_keyframes
	return effect.keyframes[hidden_keyframe_id]


func _set_advanced_keyframes(keys: Dictionary, component: String = current_component) -> void:
	var hidden_id: String = "_adv_" + current_param_id + "_" + component
	effect.keyframes[hidden_id] = keys


func _get_y_ticks() -> Array[float]:
	var param: EffectParam = _get_current_param()
	var default_value: float = _get_component_value(param.default_value) if param else 0.0
	var range_value: float = graph_value_range.y - graph_value_range.x
	if range_value <= 0.0:
		return [default_value]

	var raw_step: float = range_value / 6.0
	var magnitude: float = pow(10.0, floorf(log(raw_step) / log(10.0)))
	var relative_step: float = raw_step / magnitude
	var step_value: float = magnitude
	if relative_step >= 5.0:
		step_value *= 5.0
	elif relative_step >= 2.0:
		step_value *= 2.0

	var ticks: Array[float] = []
	var current_value: float = default_value
	while current_value <= graph_value_range.y:
		ticks.append(current_value)
		current_value += step_value

	current_value = default_value - step_value
	while current_value >= graph_value_range.x:
		ticks.append(current_value)
		current_value -= step_value
	return ticks


func _get_sorted_advanced_keyframes() -> Array[int]:
	var advanced_keyframes: Dictionary = _get_advanced_keyframes()
	var keys: Array[int] = []
	keys.assign(advanced_keyframes.keys())
	keys.sort()
	return keys


func _build_curve2d(component: String = current_component) -> Curve2D:
	var curve: Curve2D = Curve2D.new()
	var advanced_keyframes: Dictionary = _get_advanced_keyframes(component)
	var sorted_frames: Array = advanced_keyframes.keys()
	sorted_frames.sort()

	for i: int in sorted_frames.size():
		var frame_nr: int = sorted_frames[i]
		var keyframe_data: Dictionary = advanced_keyframes[frame_nr]
		var prev_frame: int = sorted_frames[i-1] if i > 0 else frame_nr
		var next_frame: int = sorted_frames[i+1] if i < sorted_frames.size() - 1 else frame_nr

		var frame_distance_in: float = float(frame_nr - prev_frame)
		var frame_distance_out: float = float(next_frame - frame_nr)
		var handle_position_in: Vector2 = Vector2(-keyframe_data["in_x"] * frame_distance_in as float, keyframe_data["in_y"] as float)
		var handle_position_out: Vector2 = Vector2(keyframe_data["out_x"] * frame_distance_out as float, keyframe_data["out_y"] as float)
		curve.add_point(Vector2(float(frame_nr), keyframe_data["value"] as float), handle_position_in, handle_position_out)
	return curve


func _get_y_on_curve(curve: Curve2D, x: float) -> float:
	var pts: PackedVector2Array = curve.tessellate(8, 0.1)
	if pts.is_empty():
		return 0.0
	elif x <= pts[0].x:
		return pts[0].y
	elif x >= pts[-1].x:
		return pts[-1].y

	for i: int in pts.size() - 1:
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i+1]
		if x >= p1.x and x <= p2.x:
			if p1.x == p2.x:
				return p1.y
			var weight: float = (x - p1.x) / (p2.x - p1.x)
			return lerpf(p1.y, p2.y, weight)
	return pts[-1].y


func _bake_keyframes() -> void:
	var param: EffectParam = _get_current_param()
	if not param:
		return

	var components: Array[String] = [""]
	if typeof(param.default_value) in [TYPE_VECTOR2, TYPE_VECTOR2I]:
		components = ["x", "y"]

	var curves: Dictionary = {}
	var baked_keyframes: Dictionary = {}
	var advanced_keyframes_by_component: Dictionary = {}
	var frame_nr_range: Vector2i = Vector2i(9999999, -1)

	for component: String in components:
		var hidden_id: String = "_adv_" + current_param_id + "_" + component
		if not effect.keyframes.has(hidden_id):
			_get_advanced_keyframes(component)
		var advanced_keyframes: Dictionary = effect.keyframes.get(hidden_id, {})
		advanced_keyframes_by_component[component] = advanced_keyframes
		for frame_nr: int in advanced_keyframes:
			frame_nr_range.x = mini(frame_nr_range.x, frame_nr)
			frame_nr_range.y = maxi(frame_nr_range.y, frame_nr)
		curves[component] = _build_curve2d(component)

	if frame_nr_range.x > frame_nr_range.y:
		effect.keyframes[current_param_id] = {}
		effect._cache_dirty = true
		return

	for frame_nr: int in range(frame_nr_range.x, frame_nr_range.y + 1):
		var baked_value: Variant = param.default_value
		for component: String in components:
			var advanced_keyframes: Dictionary = advanced_keyframes_by_component[component]
			var evaluated_v: float = 0.0
			if advanced_keyframes.is_empty():
				evaluated_v = _get_component_value(param.default_value, component)
			elif frame_nr <= frame_nr_range.x:
				evaluated_v = _get_y_on_curve(curves[component] as Curve2D, float(frame_nr_range.x))
			elif frame_nr >= frame_nr_range.y:
				evaluated_v = _get_y_on_curve(curves[component] as Curve2D, float(frame_nr_range.y))
			else:
				evaluated_v = _get_y_on_curve(curves[component] as Curve2D, float(frame_nr))
			baked_value = _set_component_value(baked_value, evaluated_v, component)
		baked_keyframes[frame_nr] = baked_value
	effect.keyframes[current_param_id] = baked_keyframes
	effect._cache_dirty = true


#--- Mapping Helpers ---

func _frame_to_x(frame_nr: float) -> float:
	return frame_nr * current_zoom_x


func _value_to_y(value: float) -> float:
	if graph_value_range.y == graph_value_range.x:
		return graph.size.y / 2.0
	return graph.size.y - ((value - graph_value_range.x) / (graph_value_range.y - graph_value_range.x)) * graph.size.y


func _x_to_frame(x_position: float) -> float:
	return x_position / current_zoom_x


func _y_to_value(y_position: float) -> float:
	if graph_value_range.y == graph_value_range.x:
		return graph_value_range.x
	return graph_value_range.x + ((graph.size.y - y_position) / graph.size.y) * (graph_value_range.y - graph_value_range.x)


func _get_current_param() -> EffectParam:
	for param: EffectParam in effect.params:
		if param.id == current_param_id:
			return param
	return null


func _get_component_value(value: Variant, component: String = current_component) -> float:
	if component == "x":
		return value.x as float
	if component == "y":
		return value.y as float
	return value as float


func _set_component_value(original_value: Variant, new_component_value: float, component: String = current_component) -> Variant:
	if component == "x":
		if typeof(original_value) == TYPE_VECTOR2I:
			return Vector2i(int(new_component_value), original_value.y as int)
		return Vector2(new_component_value, original_value.y as int)
	elif component == "y":
		if typeof(original_value) == TYPE_VECTOR2I:
			return Vector2i(original_value.x as int, int(new_component_value))
		return Vector2(original_value.x as float, new_component_value)

	if typeof(original_value) == TYPE_INT:
		return int(new_component_value)
	return new_component_value


#--- Input handling ---

func _on_graph_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_graph_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_graph_mouse_motion(event as InputEventMouseMotion)


func _on_graph_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		_on_graph_mouse_button_left(event)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if hovered_type == HoverType.KEYFRAME and hovered_frame > 0:
			_on_graph_mouse_button_right()
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if event.ctrl_pressed:
			if event.shift_pressed:
				_zoom_y_axis(1.0 / 1.1)
			else:
				_zoom_at_mouse(1.1, event.position.x)
			graph.accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if event.ctrl_pressed:
			if event.shift_pressed:
				_zoom_y_axis(1.1)
			else:
				_zoom_at_mouse(1.0 / 1.1, event.position.x)
			graph.accept_event()


func _on_graph_mouse_button_left(event: InputEventMouseButton) -> void:
	if event.double_click:
		if hovered_type != HoverType.NONE:
			return

		var frame_nr: int = clampi(roundi(_x_to_frame(event.position.x)), 0, clip.duration)
		var param: EffectParam = _get_current_param()
		if param:
			var old_advanced_keyframes: Dictionary = _get_advanced_keyframes().duplicate(true)

			@warning_ignore("unsafe_method_access")
			var old_baked_keyframes: Dictionary = effect.keyframes.get(current_param_id, {}).duplicate(true)
			var new_advanced_keyframes: Dictionary = old_advanced_keyframes.duplicate(true)
			var new_keyframe_value: float = _get_component_value(effect.get_value(param, frame_nr))
			new_advanced_keyframes[frame_nr] = {
				"value": new_keyframe_value,
				"in_x": 0.33, "in_y": 0.0,
				"out_x": 0.33, "out_y": 0.0
			}
			_set_advanced_keyframes(new_advanced_keyframes)
			_bake_keyframes()

			@warning_ignore("unsafe_method_access")
			var new_baked_keyframes: Dictionary = effect.keyframes.get(current_param_id, {}).duplicate(true)

			_set_advanced_keyframes(old_advanced_keyframes)
			effect.keyframes[current_param_id] = old_baked_keyframes

			UndoManager.create_action("Add Keyframe")
			UndoManager.add_do(_swap_state.bind(
					current_param_id, current_component, new_advanced_keyframes, new_baked_keyframes))
			UndoManager.add_undo(_swap_state.bind(
					current_param_id, current_component, old_advanced_keyframes, old_baked_keyframes))
			UndoManager.commit_action()

			selected_keyframe = frame_nr
			drag_mode = HoverType.NONE
			_is_scrubbing = false
			graph.queue_redraw()
			graph.accept_event()
	elif event.pressed:
		if hovered_type != HoverType.NONE:
			drag_mode = hovered_type
			drag_frame = hovered_frame
			drag_start_frame = hovered_frame
			drag_start_mouse_pos = event.position
			drag_start_keyframes_advanced = _get_advanced_keyframes().duplicate(true)
			if drag_mode == HoverType.KEYFRAME:
				selected_keyframe = drag_frame
				drag_start_value = drag_start_keyframes_advanced[drag_frame]["value"]
			@warning_ignore("unsafe_method_access")
			drag_start_keyframes = effect.keyframes.get(current_param_id, {}).duplicate(true)
		else:
			drag_mode = HoverType.NONE
			selected_keyframe = -1
			_is_scrubbing = true
			var frame_nr: int = clampi(roundi(_x_to_frame(event.position.x)), 0, clip.duration)
			EditorCore.scrub_to_frame(clip.start + frame_nr)
		graph.queue_redraw()
	else: # Released.
		if drag_mode in [HoverType.KEYFRAME, HoverType.HANDLE_IN, HoverType.HANDLE_OUT]:
			var new_advanced_keyframes: Dictionary = _get_advanced_keyframes().duplicate(true)

			@warning_ignore("unsafe_method_access")
			var new_baked_keyframes: Dictionary = effect.keyframes.get(current_param_id, {}).duplicate(true)
			_set_advanced_keyframes(drag_start_keyframes_advanced)
			effect.keyframes[current_param_id] = drag_start_keyframes

			UndoManager.create_action("Edit Keyframe Curve")
			UndoManager.add_do(_swap_state.bind(
					current_param_id, current_component, new_advanced_keyframes, new_baked_keyframes))
			UndoManager.add_undo(_swap_state.bind(
					current_param_id, current_component, drag_start_keyframes_advanced, drag_start_keyframes))
			UndoManager.commit_action()
		elif _is_scrubbing:
			EditorCore.finish_scrub()
		drag_mode = HoverType.NONE
		hovered_frame = -1
		hovered_type = HoverType.NONE
		_is_scrubbing = false


func _on_graph_mouse_button_right() -> void:
	var old_advanced_keyframes: Dictionary = _get_advanced_keyframes().duplicate(true)

	@warning_ignore("unsafe_method_access")
	var old_baked_keyframes: Dictionary = effect.keyframes.get(current_param_id, {}).duplicate(true)
	var new_advanced_keyframes: Dictionary = old_advanced_keyframes.duplicate(true)
	new_advanced_keyframes.erase(hovered_frame)
	_set_advanced_keyframes(new_advanced_keyframes)
	_bake_keyframes()

	@warning_ignore("unsafe_method_access")
	var new_baked_keyframes: Dictionary = effect.keyframes.get(current_param_id, {}).duplicate(true)
	_set_advanced_keyframes(old_advanced_keyframes)
	effect.keyframes[current_param_id] = old_baked_keyframes

	UndoManager.create_action("Delete Keyframe")
	UndoManager.add_do(_swap_state.bind(
			current_param_id, current_component, new_advanced_keyframes, new_baked_keyframes))
	UndoManager.add_undo(_swap_state.bind(
			current_param_id, current_component, old_advanced_keyframes, old_baked_keyframes))
	UndoManager.commit_action()

	if selected_keyframe == hovered_frame:
		selected_keyframe = -1
	hovered_type = HoverType.NONE
	hovered_frame = -1
	graph.queue_redraw()


func _on_graph_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		scroll.scroll_horizontal = maxi(0, scroll.scroll_horizontal - int(event.relative.x))
		scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - int(event.relative.y))
		graph.accept_event()
		return

	if drag_mode == HoverType.NONE and not _is_scrubbing:
		_hit_test(event.position)
	elif _is_scrubbing:
		var frame_nr: int = clampi(roundi(_x_to_frame(event.position.x)), 0, clip.duration)
		EditorCore.scrub_to_frame(clip.start + frame_nr)
	elif drag_mode == HoverType.KEYFRAME:
		var new_frame: int = roundi(_x_to_frame(event.position.x))
		if drag_start_frame == 0:
			new_frame = 0
		if Input.is_key_pressed(KEY_CTRL):
			new_frame = drag_start_frame

		var sorted_frames: Array[int] = _get_sorted_advanced_keyframes()
		if drag_frame not in sorted_frames:
			sorted_frames.append(drag_frame)
			sorted_frames.sort()

		var index: int = sorted_frames.find(drag_frame)
		new_frame = clampi(new_frame,
				sorted_frames[index-1] + 1 if index > 0 else 0,
				sorted_frames[index+1] - 1 if index < sorted_frames.size()-1 else clip.duration)

		var new_value: float = _y_to_value(event.position.y)
		var param: EffectParam = _get_current_param()
		if param.min_value != null:
			new_value = maxf(new_value, _get_component_value(param.min_value))
		if param.max_value != null:
			new_value = minf(new_value, _get_component_value(param.max_value))

		var advanced_keyframes: Dictionary = _get_advanced_keyframes()
		var keyframe_data: Dictionary = advanced_keyframes[drag_frame]
		advanced_keyframes.erase(drag_frame)
		keyframe_data["value"] = new_value
		advanced_keyframes[new_frame] = keyframe_data

		drag_frame = new_frame
		selected_keyframe = new_frame
		_set_advanced_keyframes(advanced_keyframes)
		_bake_keyframes()
		graph.queue_redraw()
		EffectsHandler.effects_updated.emit()
	elif drag_mode in [HoverType.HANDLE_IN, HoverType.HANDLE_OUT]:
		var sorted_keyframes: Array[int] = _get_sorted_advanced_keyframes()
		var index: int = sorted_keyframes.find(drag_frame)
		var frame_nr: int = drag_frame
		var advanced_keyframes: Dictionary = _get_advanced_keyframes()
		var keyframe_data: Dictionary = advanced_keyframes[frame_nr]
		var value: float = keyframe_data["value"]

		if drag_mode == HoverType.HANDLE_OUT and index < sorted_keyframes.size() - 1:
			var next_frame: int = sorted_keyframes[index+1]
			var frame_distance: float = float(next_frame - frame_nr)
			var mouse_frame: float = _x_to_frame(event.position.x)
			var mouse_value: float = _y_to_value(event.position.y)
			var out_handle_x: float = (mouse_frame - frame_nr) / frame_distance if frame_distance != 0 else 0.33
			var out_handle_y: float = mouse_value - value
			keyframe_data["out_x"] = clampf(out_handle_x, 0.0, 1.0)
			keyframe_data["out_y"] = out_handle_y
		elif drag_mode == HoverType.HANDLE_IN and index > 0:
			var prev_frame: int = sorted_keyframes[index-1]
			var frame_distance: float = float(frame_nr - prev_frame)
			var mouse_frame: float = _x_to_frame(event.position.x)
			var mouse_value: float = _y_to_value(event.position.y)
			var in_handle_x: float = (frame_nr - mouse_frame) / frame_distance if frame_distance != 0 else 0.33
			var in_handle_y: float = mouse_value - value
			keyframe_data["in_x"] = clampf(in_handle_x, 0.0, 1.0)
			keyframe_data["in_y"] = in_handle_y
		advanced_keyframes[frame_nr] = keyframe_data
		_set_advanced_keyframes(advanced_keyframes)
		_bake_keyframes()
		graph.queue_redraw()
		EffectsHandler.effects_updated.emit()


func _hit_test(mouse_pos: Vector2) -> void:
	var best_distance: float = 12.0
	var best_type: HoverType = HoverType.NONE
	var best_frame: int = -1

	var keys: Array[int] = _get_sorted_advanced_keyframes()
	var advanced_keyframes: Dictionary = _get_advanced_keyframes()
	for i: int in keys.size():
		var frame_nr: int = keys[i]
		var keyframe_data: Dictionary = advanced_keyframes[frame_nr]
		var value: float = keyframe_data["value"]
		var keyframe_position: Vector2 = Vector2(_frame_to_x(frame_nr), _value_to_y(value))

		if frame_nr == selected_keyframe:
			if i > 0:
				var prev_frame: int = keys[i-1]
				var frame_distance: float = float(frame_nr - prev_frame)
				var handle_position: Vector2 = Vector2(
						_frame_to_x(frame_nr - keyframe_data["in_x"] * frame_distance as float),
						_value_to_y(value + keyframe_data["in_y"] as float))
				var handle_distance_in: float = mouse_pos.distance_to(handle_position)
				if handle_distance_in < best_distance:
					best_distance = handle_distance_in
					best_type = HoverType.HANDLE_IN
					best_frame = frame_nr
			if i < keys.size() - 1:
				var next_frame: int = keys[i+1]
				var frame_distance: float = float(next_frame - frame_nr)
				var handle_position: Vector2 = Vector2(
						_frame_to_x(frame_nr + keyframe_data["out_x"] * frame_distance as float),
						_value_to_y(value + keyframe_data["out_y"] as float))
				var handle_distance_out: float = mouse_pos.distance_to(handle_position)
				if handle_distance_out < best_distance:
					best_distance = handle_distance_out
					best_type = HoverType.HANDLE_OUT
					best_frame = frame_nr
		var handle_distance: float = mouse_pos.distance_to(keyframe_position)
		if handle_distance < best_distance:
			best_distance = handle_distance
			best_type = HoverType.KEYFRAME
			best_frame = frame_nr
	if hovered_type != best_type or hovered_frame != best_frame:
		hovered_type = best_type
		hovered_frame = best_frame
		graph.queue_redraw()
		if hovered_type != HoverType.NONE:
			graph.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			graph.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _swap_state(param_id: String, component: String, advanced_keyframes: Dictionary, baked_keys: Dictionary) -> void:
	var hidden_id: String = "_adv_" + param_id + "_" + component
	effect.keyframes[hidden_id] = advanced_keyframes.duplicate(true)
	if baked_keys.is_empty():
		effect.keyframes.erase(param_id)
	else:
		effect.keyframes[param_id] = baked_keys.duplicate(true)
	effect._cache_dirty = true
	_update_bounds()
	graph.queue_redraw()
	EffectsHandler.effects_updated.emit()


func _zoom_at_mouse(factor: float, local_mouse_x: float) -> void:
	var old_zoom: float = current_zoom_x
	var new_zoom: float = clampf(current_zoom_x * factor, 1.0, 50.0)
	if old_zoom != new_zoom:
		var zoom_ratio: float = new_zoom / old_zoom
		var new_local_x: float = local_mouse_x * zoom_ratio

		var mouse_viewport_offset: float = local_mouse_x - scroll.scroll_horizontal
		var target_scroll: int = maxi(0, int(new_local_x - mouse_viewport_offset))
		current_zoom_x = new_zoom
		_update_graph_size()

		scroll.scroll_horizontal = target_scroll
		graph.queue_redraw()
		_update_scroll.call_deferred(target_scroll)


func _zoom_y_axis(factor: float) -> void:
	current_zoom_y = clampf(current_zoom_y * factor, 0.01, 100.0)
	_update_bounds()
	graph.queue_redraw()


func _update_scroll(target_scroll: int) -> void:
	scroll.scroll_horizontal = target_scroll


#--- Drawing logic ---

func _on_y_axis_draw() -> void:
	y_axis.draw_rect(Rect2(Vector2.ZERO, y_axis.size), Color(0.1, 0.1, 0.1))
	y_axis.draw_line(Vector2(y_axis.size.x - 1, 0), Vector2(y_axis.size.x - 1, y_axis.size.y), Color(1, 1, 1, 0.3), 1.0)
	if graph_value_range.y > graph_value_range.x:
		var param: EffectParam = _get_current_param()
		var default_value: float = _get_component_value(param.default_value) if param else 0.0
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 10
		for value: float in _get_y_ticks():
			var y: float = _value_to_y(value)
			var text: String = str(snappedf(value, 0.01))
			var draw_y: float = clampf(y + 4, font_size, y_axis.size.y - 2)

			var is_default_value: bool = is_equal_approx(value, default_value)
			var color: Color = Color.WHITE if is_default_value else Color(1, 1, 1, 0.6)
			y_axis.draw_string(font, Vector2(2, draw_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			y_axis.draw_line(Vector2(y_axis.size.x - 6, y), Vector2(y_axis.size.x, y), color, 1.0)


func _on_graph_draw() -> void:
	# - Background.
	graph.draw_rect(Rect2(Vector2.ZERO, graph.size), Color(0.05, 0.05, 0.05))

	# - Grid lines.
	var fps: float = Project.data.framerate
	for frame_nr: int in clip.duration + 1:
		var x: float = _frame_to_x(float(frame_nr))
		if frame_nr % int(fps) == 0:
			graph.draw_line(Vector2(x, 0), Vector2(x, graph.size.y), Color(1, 1, 1, 0.2), 2.0)
		elif frame_nr % int(fps / 5) == 0:
			graph.draw_line(Vector2(x, 0), Vector2(x, graph.size.y), Color(1, 1, 1, 0.05), 1.0)

	# - Y-axis grid lines.
	var param: EffectParam = _get_current_param()
	var default_value: float = _get_component_value(param.default_value) if param else 0.0
	for value: float in _get_y_ticks():
		var is_default_value: bool = is_equal_approx(value, default_value)
		var color: Color = Color(1, 1, 1, 0.3) if is_default_value else Color(1, 1, 1, 0.05)
		var thickness: float = 2.0 if is_default_value else 1.0
		var y: float = _value_to_y(value)
		graph.draw_line(Vector2(0, y), Vector2(graph.size.x, y), color, thickness)

	# - Curve.
	var keys: Array[int] = _get_sorted_advanced_keyframes()
	var advanced_keyframes: Dictionary = _get_advanced_keyframes()
	if keys.size() > 0:
		var first_frame: int = keys[0]
		var first_value: float = advanced_keyframes[first_frame]["value"]
		graph.draw_line(
				Vector2(0, _value_to_y(first_value)),
				Vector2(_frame_to_x(first_frame),
				_value_to_y(first_value)),
				Color(0.4, 0.6, 1.0, 0.5),
				2.0)

		var curve: Curve2D = _build_curve2d()
		var curve_points: PackedVector2Array = curve.tessellate(8, 0.1)
		var screen_points: PackedVector2Array = PackedVector2Array()
		for curve_point: Vector2 in curve_points:
			screen_points.append(Vector2(_frame_to_x(curve_point.x), _value_to_y(curve_point.y)))
		if screen_points.size() >= 2:
			graph.draw_polyline(screen_points, Color(0.4, 0.6, 1.0), 2.0)

		var last_frame: int = keys[-1]
		var last_value: float = advanced_keyframes[last_frame]["value"]
		graph.draw_line(
				Vector2(_frame_to_x(last_frame),
				_value_to_y(last_value)),
				Vector2(_frame_to_x(clip.duration),
				_value_to_y(last_value)),
				Color(0.4, 0.6, 1.0, 0.5),
				2.0)

	# - Keyframes & handles.
	for keyframe_index: int in keys.size():
		var frame_nr: int = keys[keyframe_index]
		var keyframe_data: Dictionary = advanced_keyframes[frame_nr]
		var value: float = keyframe_data["value"]
		var pos: Vector2 = Vector2(_frame_to_x(frame_nr), _value_to_y(value))

		if frame_nr == selected_keyframe:
			if keyframe_index > 0:
				var previous_frame: int = keys[keyframe_index-1]
				var frame_distance: float = float(frame_nr - previous_frame)
				var handle_position: Vector2 = Vector2(
						_frame_to_x(frame_nr - keyframe_data["in_x"] * frame_distance as float),
						_value_to_y(value + keyframe_data["in_y"] as float))
				graph.draw_line(pos, handle_position, Color.YELLOW, 1.0)
				graph.draw_circle(handle_position, 4.0, Color.YELLOW if (hovered_frame == frame_nr and hovered_type == HoverType.HANDLE_IN) else Color.WHITE)

			if keyframe_index < keys.size() - 1:
				var next_frame: int = keys[keyframe_index+1]
				var frame_distance: float = float(next_frame - frame_nr)
				var handle_position: Vector2 = Vector2(
						_frame_to_x(frame_nr + keyframe_data["out_x"] * frame_distance as float),
						_value_to_y(value + keyframe_data["out_y"] as float))
				graph.draw_line(pos, handle_position, Color.YELLOW, 1.0)
				graph.draw_circle(handle_position, 4.0, Color.YELLOW if (hovered_frame == frame_nr and hovered_type == HoverType.HANDLE_OUT) else Color.WHITE)
		var color: Color = Color.RED if frame_nr == selected_keyframe else Color.WHITE
		if hovered_frame == frame_nr and hovered_type == HoverType.KEYFRAME:
			color = Color.ORANGE
		graph.draw_circle(pos, 5.0, color)

	# - Playhead.
	var playhead_frame_nr: float = EditorCore.visual_frame_nr - clip.start
	if playhead_frame_nr >= 0 and playhead_frame_nr <= clip.duration:
		var pixels: float = _frame_to_x(playhead_frame_nr)
		graph.draw_line(Vector2(pixels, 0), Vector2(pixels, graph.size.y), Color(1, 0.2, 0.2, 0.8), 2.0)
