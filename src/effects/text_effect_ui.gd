extends EffectUI


var effect: Effect
var clip: ClipData
var file: FileData
var effects_panel: EffectsPanel



func load_ui(_effect: Effect, _clip: ClipData, _is_visual: bool, _effects_panel: EffectsPanel) -> void:
	effect = _effect
	clip = _clip
	file = FileLogic.files[clip.file]
	effects_panel = _effects_panel

	var relative_frame_nr: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))
	var container: FoldableContainer = FoldableContainer.new()
	container.title = "Text Properties"
	container.add_theme_font_size_override("font_size", 11)
	container.add_theme_color_override("font_color", "#b8b8b8")

	var button_reset: TextureButton = TextureButton.new()
	button_reset.texture_normal = preload(Library.ICON_REFRESH)
	button_reset.ignore_texture_size = true
	button_reset.custom_minimum_size = EffectsPanel.SIZE_EFFECT_HEADER_ICON
	button_reset.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button_reset.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_reset.tooltip_text = tr("Reset to default")

	@warning_ignore("return_value_discarded")
	button_reset.pressed.connect(_on_reset_text_effect)
	container.add_title_bar_control(button_reset)

	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	container.add_child(content_vbox)
	for param: EffectParam in effect.params:
		var param_hbox: HBoxContainer = HBoxContainer.new()
		var param_id: String = param.id
		var param_title: Label = Label.new()
		var param_settings: Control
		var param_keyframe_button: TextureButton = TextureButton.new()

		if param_id == "text_data":
			var text_edit: TextEdit = TextEdit.new()
			text_edit.placeholder_text = "Text ..."

			@warning_ignore("return_value_discarded")
			text_edit.text_changed.connect(func() -> void: _text_param_update_call(text_edit.text, param_id))
			text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_edit.custom_minimum_size.y = 80
			text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			param_settings = text_edit
			param_title.visible = false # So we don't have trouble with indexing stuff.
		else:
			param_settings = EffectsPanel.create_param_control(param, _text_param_update_call.bind(param.id))

		param_title.text = param.nickname.replace("param_", "").capitalize()
		param_title.tooltip_text = param.tooltip
		param_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		param_title.clip_text = true

		var param_prev_button: TextureButton = TextureButton.new()
		param_prev_button.name = "PREV_KEYFRAME_" + param_id
		param_prev_button.texture_normal = load(Library.ICON_PREV_KEYFRAME)
		param_prev_button.ignore_texture_size = true
		param_prev_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_prev_button.custom_minimum_size.x = 8
		param_prev_button.visible = param.keyframeable

		@warning_ignore("return_value_discarded")
		param_prev_button.pressed.connect(effects_panel._jump_prev_keyframe.bind(effect, param_id))

		param_keyframe_button.name = "KEYFRAME_" + param_id
		param_keyframe_button.ignore_texture_size = true
		param_keyframe_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_keyframe_button.custom_minimum_size.x = 14

		@warning_ignore("return_value_discarded")
		param_keyframe_button.pressed.connect(_text_keyframe_button_pressed.bind(param_id))

		var keyframes: Dictionary = effect.keyframes[param.id]
		if keyframes.has(relative_frame_nr):
			param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
		else:
			param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)

		param_keyframe_button.visible = param.keyframeable

		var param_next_button: TextureButton = TextureButton.new()
		param_next_button.name = "NEXT_KEYFRAME_" + param_id
		param_next_button.texture_normal = load(Library.ICON_NEXT_KEYFRAME)
		param_next_button.ignore_texture_size = true
		param_next_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_next_button.custom_minimum_size.x = 8
		param_next_button.visible = param.keyframeable

		@warning_ignore("return_value_discarded")
		param_next_button.pressed.connect(effects_panel._jump_next_keyframe.bind(effect, param_id))

		var param_reset_button: TextureButton = TextureButton.new()
		param_reset_button.texture_normal = preload(Library.ICON_REFRESH)
		param_reset_button.tooltip_text = tr("Reset parameter")
		param_reset_button.ignore_texture_size = true
		param_reset_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_reset_button.custom_minimum_size = Vector2(14, 14)

		@warning_ignore("return_value_discarded")
		param_reset_button.pressed.connect(
				_text_param_update_call.bind(param.default_value, param_id))

		param_hbox.add_child(param_title)
		param_hbox.add_child(param_reset_button)
		param_hbox.add_child(param_settings)
		param_hbox.add_child(param_prev_button)
		param_hbox.add_child(param_keyframe_button)
		param_hbox.add_child(param_next_button)
		content_vbox.add_child(param_hbox)

	var track: KeyframeTrack = KeyframeTrack.new()
	var track_scroll: ScrollContainer = ScrollContainer.new()
	var track_hbox: HBoxContainer = HBoxContainer.new()
	var track_label: Label = Label.new()

	track_label.text = "Keyframes"
	track_label.custom_minimum_size.x = 80
	track_label.modulate = Color(1, 1, 1, 0.5)

	track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	track_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_scroll.custom_minimum_size.y = 32

	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track.setup(effect, clip.duration, relative_frame_nr)

	@warning_ignore_start("return_value_discarded")
	track.keyframe_moved_effect.connect(_on_text_keyframe_moved)
	track.keyframe_deleted_effect.connect(_on_text_keyframe_deleted)
	track.keyframe_dragged_to.connect(effects_panel._on_keyframe_dragged_to_effect_ui)
	@warning_ignore_restore("return_value_discarded")

	track_scroll.add_child(track)
	track_hbox.add_child(track_label)
	track_hbox.add_child(track_scroll)
	content_vbox.add_child(HSeparator.new())
	content_vbox.add_child(track_hbox)

	add_child(container)


func _on_text_keyframe_moved(old_frame: int, new_frame: int, preserve: bool, is_copy: bool) -> void:
	var text_effect: EffectVisual = file.temp_file.text_effect
	var keyframes: Dictionary = text_effect.keyframes

	InputManager.undo_redo.create_action("Move/Copy Text Keyframes")
	for param: EffectParam in text_effect.params:
		var param_id: String = param.id
		var param_keyframes: Dictionary = keyframes[param_id]
		if not param_keyframes.has(old_frame):
			continue

		var value_move: Variant = param_keyframes[old_frame]
		var has_target: Variant = param_keyframes.has(new_frame)
		var value_target: Variant = param_keyframes[new_frame] if has_target else null
		var value_final: Variant = value_target if (has_target and preserve) else value_move
		if old_frame != 0 and not is_copy:
			InputManager.undo_redo.add_do_method(FileLogic.remove_text_keyframe.bind(file, param_id, old_frame))
			InputManager.undo_redo.add_undo_method(FileLogic._set_text_keyframe.bind(file, param_id, old_frame, value_move))

		if not (has_target and preserve):
			InputManager.undo_redo.add_do_method(FileLogic._set_text_keyframe.bind(file, param_id, new_frame, value_final))
			if has_target:
				InputManager.undo_redo.add_undo_method(FileLogic._set_text_keyframe.bind(file, param_id, new_frame, value_target))
			else:
				InputManager.undo_redo.add_undo_method(FileLogic.remove_text_keyframe.bind(file, param_id, new_frame))
	InputManager.undo_redo.commit_action()
	effects_panel._update_ui_values()


func _on_text_keyframe_deleted(frame_nr: int) -> void:
	if frame_nr == 0:
		return
	var text_effect: EffectVisual = file.temp_file.text_effect
	var keyframes: Dictionary = text_effect.keyframes

	InputManager.undo_redo.create_action("Delete Text Keyframes")
	for param: EffectParam in text_effect.params:
		var param_keyframes: Dictionary = keyframes[param.id]
		if param_keyframes.has(frame_nr):
			var old_value: Variant = param_keyframes[frame_nr]
			InputManager.undo_redo.add_do_method(FileLogic.remove_text_keyframe.bind(file, param.id, frame_nr))
			InputManager.undo_redo.add_undo_method(FileLogic._set_text_keyframe.bind(file, param.id, frame_nr, old_value))
	InputManager.undo_redo.commit_action()
	effects_panel._update_ui_values()


func _text_param_update_call(value: Variant, param_id: String) -> void:
	var frame_nr: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))
	var text_effect: EffectVisual = file.temp_file.text_effect
	var keyframes: Dictionary = text_effect.keyframes

	var param_obj: EffectParam
	for param: EffectParam in text_effect.params:
		if param.id == param_id:
			param_obj = param
			break

	var is_keyframeable: bool = param_obj.keyframeable if param_obj else false
	var param_keyframes: Dictionary = keyframes[param_id]

	if param_keyframes.size() <= 1 or not is_keyframeable:
		var base_frame: int = param_keyframes.keys()[0] if param_keyframes.size() > 0 else 0
		var old_value: Variant = param_keyframes.get(base_frame, param_obj.default_value)
		FileLogic.update_text_param(file, param_id, base_frame, value, old_value, false)
	else:
		var is_new: bool = not param_keyframes.has(frame_nr)
		var old_value: Variant = param_keyframes[frame_nr] if not is_new else text_effect.get_value(param_obj, frame_nr)
		FileLogic.update_text_param(file, param_id, frame_nr, value, old_value, is_new)
	effects_panel._update_ui_values()


func _text_keyframe_button_pressed(param_id: String) -> void:
	var frame_nr: int = clampi(EditorCore.visual_frame_nr - clip.start, 0, maxi(0, clip.duration - 1))
	var text_effect: EffectVisual = file.temp_file.text_effect
	var keyframes: Dictionary = text_effect.keyframes
	var param_keyframes: Dictionary = keyframes[param_id]

	if !param_keyframes.has(frame_nr):
		var param_obj: EffectParam
		for param: EffectParam in text_effect.params:
			if param.id == param_id:
				param_obj = param
				break
		var value: Variant = text_effect.get_value(param_obj, frame_nr)
		FileLogic.update_text_param(file, param_id, frame_nr, value, null, true)
	elif frame_nr != 0:
		FileLogic.remove_text_keyframe(file, param_id, frame_nr)
	effects_panel._update_ui_values()


func _on_reset_text_effect() -> void:
	var text_effect: EffectVisual = file.temp_file.text_effect
	var old_keyframes: Dictionary = Effect.duplicate_keyframes(text_effect.keyframes)

	InputManager.undo_redo.create_action("Reset text effect")
	InputManager.undo_redo.add_do_method(_reset_text_effect)
	InputManager.undo_redo.add_undo_method(_restore_text_effect_keyframes.bind(old_keyframes))
	InputManager.undo_redo.commit_action()


func _reset_text_effect() -> void:
	var text_effect: EffectVisual = file.temp_file.text_effect
	text_effect.keyframes.clear()
	text_effect.set_default_keyframe()
	Project.unsaved_changes = true
	ClipLogic.updated.emit()
	EffectsHandler.effect_values_updated.emit()


func _restore_text_effect_keyframes(old_keyframes: Dictionary) -> void:
	var text_effect: EffectVisual = file.temp_file.text_effect
	text_effect.keyframes = Effect.duplicate_keyframes(old_keyframes)
	text_effect._cache_dirty = true
	Project.unsaved_changes = true
	ClipLogic.updated.emit()
	EffectsHandler.effect_values_updated.emit()
