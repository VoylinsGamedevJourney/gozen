extends EffectUI


var hboxes: Dictionary = {}
var effect: Effect
var clip: ClipData
var is_visual: bool
var effects_panel: EffectsPanel



func get_ui(_effect: Effect, _clip: ClipData, _is_visual: bool, _effects_panel: EffectsPanel) -> Control:
	effect = _effect
	clip = _clip
	is_visual = _is_visual
	effects_panel = _effects_panel

	var vbox: VBoxContainer = VBoxContainer.new()

	# 1. Position.
	var position_hbox: HBoxContainer = effects_panel.create_effect_param_hbox(_get_param("position"), effect, is_visual)
	hboxes["position"] = position_hbox
	vbox.add_child(position_hbox)

	# 2. Scale.
	var scale_hbox: HBoxContainer = effects_panel.create_effect_param_hbox(_get_param("scale"), effect, is_visual)
	hboxes["scale"] = scale_hbox
	vbox.add_child(scale_hbox)

	# 3. Alignment Buttons.
	vbox.add_child(_create_alignment_buttons())

	# 4. Pivot.
	var pivot_hbox: HBoxContainer = effects_panel.create_effect_param_hbox(_get_param("pivot"), effect, is_visual)
	hboxes["pivot"] = pivot_hbox
	vbox.add_child(pivot_hbox)

	# 5. Rotation.
	var rotation_param: EffectParam = _get_param("rotation")
	rotation_param.has_slider = true
	var rotation_hbox: HBoxContainer = effects_panel.create_effect_param_hbox(rotation_param, effect, is_visual)
	hboxes["rotation"] = rotation_hbox
	vbox.add_child(rotation_hbox)

	# 6. Alpha.
	var alpha_param: EffectParam = _get_param("alpha")
	alpha_param.has_slider = true
	var alpha_hbox: HBoxContainer = effects_panel.create_effect_param_hbox(alpha_param, effect, is_visual)
	hboxes["alpha"] = alpha_hbox
	vbox.add_child(alpha_hbox)

	effects_panel.update_values.connect(_on_update_values)
	vbox.tree_exited.connect(func() -> void:
			if effects_panel.update_values.is_connected(_on_update_values):
				effects_panel.update_values.disconnect(_on_update_values))

	return vbox


func _get_param(id: String) -> EffectParam:
	for effect_param: EffectParam in effect.params:
		if effect_param.id == id: return effect_param
	return null


func _on_update_values(frame_nr: int) -> void:
	for param_id: String in hboxes:
		var param_hbox: HBoxContainer = hboxes[param_id]
		var param: EffectParam = _get_param(param_id)
		var reset_button: TextureButton = param_hbox.get_child(1)
		var param_settings: Control = param_hbox.get_child(2)
		var value: Variant = effect.get_value(param, frame_nr)

		effects_panel._set_param_settings_value(param_settings, value)
		reset_button.visible = not effects_panel._is_same_value(value, param.default_value)

		if param.keyframeable:
			var keyframe_button: TextureButton = param_hbox.get_node("KEYFRAME_" + param.id)
			var effect_keyframes: Dictionary = effect.keyframes[param.id]
			if effect_keyframes.has(frame_nr):
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
			else:
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)


func _create_alignment_buttons() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4

	var alignments: Array = [
		# Horizontal.
		{"text": "Left", "id": "left"},
		{"text": "Center H", "id": "center_h"},
		{"text": "Right", "id": "right"},
		# Fit.
		{"text": "Fit Screen", "id": "fit"},
		# Vertical.
		{"text": "Top", "id": "top"},
		{"text": "Center V", "id": "center_v"},
		{"text": "Bottom", "id": "bottom"}
	]

	for data: Dictionary in alignments:
		var button: Button = Button.new()
		button.text = data["text"]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_align.bind(data["id"]))
		grid.add_child(button)

	grid.add_child(Control.new())
	return grid


func _align(type: String) -> void:
	var res: Vector2 = Vector2(Project.get_resolution())
	var frame: int = EditorCore.visual_frame_nr - clip.start
	var current_position: Vector2 = effect.get_value(_get_param("position"), frame)
	var current_scale: Vector2 = effect.get_value(_get_param("scale"), frame)
	var current_pivot: Vector2 = effect.get_value(_get_param("pivot"), frame)

	var media_size: Vector2 = res
	var file: FileData = FileLogic.files[clip.file]
	var raw_data: Variant = FileLogic.file_data.get(file.id)

	if clip.type == EditorCore.TYPE.VIDEO and raw_data is Video:
		media_size = Vector2((raw_data as Video).get_resolution())
	elif clip.type == EditorCore.TYPE.IMAGE:
		var img: Image = Image.load_from_file(file.path)
		if img:
			media_size = img.get_size()

	var aspect: float = media_size.x / media_size.y
	var target_aspect: float = res.x / res.y
	var fit_scale: float = 1.0

	if aspect > target_aspect:
		fit_scale = res.x / media_size.x
	else:
		fit_scale = res.y / media_size.y

	var fitted_size: Vector2 = media_size * fit_scale
	var min_bounds: Vector2 = (res - fitted_size) / 2.0
	var max_bounds: Vector2 = (res + fitted_size) / 2.0

	var target_pos: Vector2 = current_position

	match type:
		"left":
			target_pos.x = current_pivot.x * (current_scale.x - 1.0) - min_bounds.x * current_scale.x
		"center_h":
			target_pos.x = (res.x / 2.0) - current_pivot.x - ((res.x / 2.0) - current_pivot.x) * current_scale.x
		"right":
			target_pos.x = res.x - current_pivot.x - (max_bounds.x - current_pivot.x) * current_scale.x
		"top":
			target_pos.y = current_pivot.y * (current_scale.y - 1.0) - min_bounds.y * current_scale.y
		"center_v":
			target_pos.y = (res.y / 2.0) - current_pivot.y - ((res.y / 2.0) - current_pivot.y) * current_scale.y
		"bottom":
			target_pos.y = res.y - current_pivot.y - (max_bounds.y - current_pivot.y) * current_scale.y
		"fit":
			target_pos = Vector2.ZERO
			EffectsHandler.update_param(clip, clip.effects.video.find(effect), true, "scale", Vector2.ONE, false)

	if current_position != target_pos:
		EffectsHandler.update_param(clip, clip.effects.video.find(effect), true, "position", Vector2i(target_pos), false)
