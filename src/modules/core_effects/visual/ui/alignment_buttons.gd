extends HBoxContainer

var effect: Effect
var clip: ClipData
var is_visual: bool

const ALIGN_BUTTON_SIZE: Vector2i = Vector2i(14, 14)



func setup(_effect: Effect, _clip: ClipData, _is_visual: bool) -> void:
	effect = _effect
	clip = _clip
	is_visual = _is_visual

	var flow: FlowContainer = HFlowContainer.new()
	var horizontal_hbox: HBoxContainer = HBoxContainer.new()
	var horizontal_data: Array[Array] = [
		[HORIZONTAL_ALIGNMENT_LEFT, preload(Library.ICON_ALIGN_LEFT)],
		[HORIZONTAL_ALIGNMENT_CENTER, preload(Library.ICON_ALIGN_CENTER)],
		[HORIZONTAL_ALIGNMENT_RIGHT, preload(Library.ICON_ALIGN_RIGHT)]]
	var vertical_hbox: HBoxContainer = HBoxContainer.new()
	var vertical_data: Array[Array] = [
		[VERTICAL_ALIGNMENT_TOP + 10, preload(Library.ICON_ALIGN_TOP)],
		[VERTICAL_ALIGNMENT_CENTER + 10, preload(Library.ICON_ALIGN_CENTER)],
		[VERTICAL_ALIGNMENT_BOTTOM + 10, preload(Library.ICON_ALIGN_BOTTOM)]]

	for data: Array in horizontal_data:
		var tex_button: TextureButton = TextureButton.new()
		tex_button.texture_normal = data[1]
		tex_button.ignore_texture_size = true
		tex_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		tex_button.custom_minimum_size = ALIGN_BUTTON_SIZE
		if tex_button.pressed.connect(_align.bind(data[0])): Print.stack_connect()
		horizontal_hbox.add_child(tex_button)
	for data: Array in vertical_data:
		var tex_button: TextureButton = TextureButton.new()
		tex_button.texture_normal = data[1]
		tex_button.ignore_texture_size = true
		tex_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		tex_button.custom_minimum_size = ALIGN_BUTTON_SIZE
		if tex_button.pressed.connect(_align.bind(data[0])): Print.stack_connect()
		vertical_hbox.add_child(tex_button)

	var fill_tex_button: TextureButton = TextureButton.new()
	fill_tex_button.texture_normal = preload(Library.ICON_ALIGN_FILL)
	fill_tex_button.ignore_texture_size = true
	fill_tex_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	fill_tex_button.custom_minimum_size = ALIGN_BUTTON_SIZE
	if fill_tex_button.pressed.connect(_align.bind(HORIZONTAL_ALIGNMENT_FILL)): Print.stack_connect()

	flow.add_child(horizontal_hbox)
	flow.add_child(VSeparator.new())
	flow.add_child(fill_tex_button)
	flow.add_child(VSeparator.new())
	flow.add_child(vertical_hbox)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.4
	add_child(spacer)
	add_child(flow)


func _align(type: int) -> void:
	var res: Vector2 = Vector2(Project.get_resolution())
	var frame: int = clampi(EditorCore.frame_nr - clip.start, 0, maxi(0, clip.duration - 1))

	var position_param: EffectParam
	var scale_param: EffectParam
	var pivot_param: EffectParam
	for p: EffectParam in effect.params:
		if p.id == "position": position_param = p
		elif p.id == "scale": scale_param = p
		elif p.id == "pivot": pivot_param = p

	var current_position: Vector2 = effect.get_value(position_param, frame) if position_param else Vector2.ZERO
	var current_scale: Vector2 = effect.get_value(scale_param, frame) if scale_param else Vector2.ONE
	var current_pivot: Vector2 = effect.get_value(pivot_param, frame) if pivot_param else Vector2.ZERO

	var media_size: Vector2 = res
	var file: FileData = FileLogic.files[clip.file]
	var raw_data: Variant = FileLogic.file_data.get(file.id)
	if clip.type == EditorCore.Type.VIDEO and raw_data is Video:
		media_size = Vector2((raw_data as Video).get_resolution())
	elif clip.type == EditorCore.Type.IMAGE:
		if raw_data is Texture2D:
			media_size = (raw_data as Texture2D).get_size()
		elif not file.path.begins_with("temp://"):
			var image: Image = Image.load_from_file(file.path)
			if image:
				media_size = image.get_size()

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
		HORIZONTAL_ALIGNMENT_LEFT:
			target_pos.x = current_pivot.x * (current_scale.x - 1.0) - min_bounds.x * current_scale.x
		HORIZONTAL_ALIGNMENT_CENTER:
			target_pos.x = (res.x / 2.0) - current_pivot.x - ((res.x / 2.0) - current_pivot.x) * current_scale.x
		HORIZONTAL_ALIGNMENT_RIGHT:
			target_pos.x = res.x - current_pivot.x - (max_bounds.x - current_pivot.x) * current_scale.x
		VERTICAL_ALIGNMENT_TOP + 10:
			target_pos.y = current_pivot.y * (current_scale.y - 1.0) - min_bounds.y * current_scale.y
		VERTICAL_ALIGNMENT_CENTER + 10:
			target_pos.y = (res.y / 2.0) - current_pivot.y - ((res.y / 2.0) - current_pivot.y) * current_scale.y
		VERTICAL_ALIGNMENT_BOTTOM + 10:
			target_pos.y = res.y - current_pivot.y - (max_bounds.y - current_pivot.y) * current_scale.y
		HORIZONTAL_ALIGNMENT_FILL:
			target_pos = Vector2.ZERO
			EffectsHandler.update_param(clip, clip.effects.video.find(effect), true, "scale", Vector2.ONE, false)

	EffectsHandler.update_param(clip, clip.effects.video.find(effect), true, "position", Vector2i(target_pos), false)
