extends PanelContainer

const MIN_VALUE: float = -100000
const MAX_VALUE: float = 100000

const COLOR_KEYFRAMING_ON: Color = Color(1, 1, 1, 1)
const COLOR_KEYFRAMING_OFF: Color = Color(1, 1, 1, 0.5)

const SIZE_EFFECT_HEADER_ICON: Vector2i = Vector2i(16, 16)


@export var section_text: VBoxContainer
@export var section_visuals: FoldableContainer
@export var section_audio: FoldableContainer


var current_clip_id: int = -1



func _ready() -> void:
	Project.project_ready.connect(_project_ready)
	EditorCore.frame_changed.connect(_on_frame_changed)
	EffectsHandler.effect_added.connect(_on_effects_updated)
	EffectsHandler.effect_removed.connect(_on_effects_updated)
	EffectsHandler.effects_updated.connect(_on_effects_updated.bind(-1))
	EffectsHandler.effect_values_updated.connect(_update_ui_values)


func _project_ready() -> void:
	Project.clips.deleted.connect(_on_clip_pressed)
	Project.clips.selected.connect(_on_clip_pressed)


func _input(event: InputEvent) -> void:
	if Project.is_loaded and event.is_action_pressed("ui_cancel"):
		_on_clip_pressed(-1)


func _get_drag_data_effect(_pos: Vector2, _container: FoldableContainer, is_visual: bool) -> void:
	# TODO: This entire system won't work thanks to the brilliant minds who
	# decided folding containers should fold on press and not release.
	# Solution will be to add a button in the title bar of each container to
	# move the effects instead. I give up for today though ...
	var drag_data: DragData = DragData.new()
	drag_data.is_visual = is_visual
	print("oi")


func _can_drop_effect() -> void:
	pass


func _drop_effect() -> void:
	pass


func _on_clip_pressed(clip_id: int) -> void:
	if !Project.clips.index_map.has(clip_id):
		section_text.visible = false
		section_visuals.visible = false
		section_audio.visible =  false
		current_clip_id = -1
		_load_effects() # To clear the ui.
	elif clip_id == current_clip_id:
		_update_ui_values()
	else:
		var clip_index: int = Project.clips.index_map[clip_id]
		var clip_type: EditorCore.TYPE = Project.data.clips_type[clip_index] as EditorCore.TYPE
		section_text.visible = clip_type == EditorCore.TYPE.TEXT
		section_visuals.visible = clip_type in EditorCore.VISUAL_TYPES
		section_audio.visible = clip_type in EditorCore.AUDIO_TYPES
		current_clip_id = clip_id
		_load_effects()


func _on_frame_changed() -> void:
	if current_clip_id != -1:
		_update_ui_values()


func _on_effects_updated(clip_id: int) -> void:
	if clip_id == current_clip_id:
		_on_clip_pressed(clip_id)


func _load_effects() -> void:
	if !Project.clips.index_map.has(current_clip_id):
		return

	# Clean UI.
	for section: FoldableContainer in [section_visuals, section_audio]:
		for child: Node in section.get_children():
			section.remove_child(child)
			child.queue_free()

	# Creating/updating new UI.
	var clip_index: int = Project.clips.index_map[current_clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]

	if section_text.visible: # Set text params.
		pass # TODO: Update text section
	for index: int in clip_effects.video.size(): # Add visual effects.
		section_visuals.add_child(_create_effect_ui(clip_effects.video[index], index, true))
	for index: int in clip_effects.audio.size(): # Add audio effects.
		section_audio.add_child(_create_effect_ui(clip_effects.audio[index], index, true))
	_update_ui_values()


func _create_effect_ui(effect: Effect, index: int, is_visual: bool) -> FoldableContainer:
	# NOTE: We can add the position of the effect inside of the effect array
	# inside of the metadata and let the buttons check if they are at the top
	# or bottom to disable the correct buttons.
	var clip_index: int = Project.clips.index_map[current_clip_id]
	var clip_start: int = Project.data.clips_start[clip_index]
	var clip_duration: int = Project.data.clips_duration[clip_index]
	var relative_frame_nr: int = EditorCore.frame_nr - clip_start

	var button_visible: TextureButton = TextureButton.new()
	var button_delete: TextureButton = TextureButton.new()

	if effect.is_enabled:
		button_visible.texture_normal = preload(Library.ICON_VISIBLE)
	else:
		button_visible.texture_normal = preload(Library.ICON_INVISIBLE)
	button_visible.pressed.connect(_on_switch_enabled.bind(index, is_visual))
	button_delete.texture_normal = preload(Library.ICON_DELETE)
	button_delete.pressed.connect(_on_remove_effect.bind(index, is_visual))

	for button: TextureButton in [button_delete, button_visible]:
		button.ignore_texture_size = true
		button.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var content_vbox: VBoxContainer = VBoxContainer.new()
	var container: FoldableContainer = FoldableContainer.new()
	container.title = effect.nickname
	container.tooltip_text = effect.tooltip
	#container.theme_type_variation = "box" # TODO: Create specific theme (light + dark).
	container.add_theme_font_size_override("font_size", 11)
	container.add_theme_color_override("font_color", "#b8b8b8")
	container.add_title_bar_control(button_delete)
	container.add_title_bar_control(button_visible)
	container.add_child(content_vbox)

	container.set_drag_forwarding(
			_get_drag_data_effect.bind(container, is_visual),
			_can_drop_effect,
			_drop_effect)

	# Adding effect params.
	for param: EffectParam in effect.params:
		var param_hbox: HBoxContainer = HBoxContainer.new()
		var param_id: String = param.id
		var param_title: Label = Label.new()
		var param_settings: Control = _create_param_control(param, index, is_visual)

		param_title.text = param.nickname.replace("param_", "").capitalize()
		param_title.tooltip_text = param.tooltip
		param_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		param_title.clip_text = true

		param_settings.name = "PARAM_" + param_id


		param_hbox.add_child(param_title)
		param_hbox.add_child(param_settings)

		if param.keyframeable:
			var param_keyframe_button: TextureButton = TextureButton.new()
			param_keyframe_button.name = "KEYFRAME_" + param_id
			param_keyframe_button.ignore_texture_size = true
			param_keyframe_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			param_keyframe_button.custom_minimum_size.x = 14
			param_keyframe_button.pressed.connect(_keyframe_button_pressed.bind(
					current_clip_id, index, is_visual, param_id))
			if effect.keyframes.has(param.id) and (effect.keyframes[param_id] as Dictionary).has(relative_frame_nr):
				param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
			else:
				param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)
			param_hbox.add_child(param_keyframe_button)

		content_vbox.add_child(param_hbox)

	var track: KeyframeTrack = KeyframeTrack.new()
	var track_hbox: HBoxContainer = HBoxContainer.new()
	var track_label: Label = Label.new()

	track_label.text = "Keyframes"
	track_label.custom_minimum_size.x = 80
	track_label.modulate = Color(1, 1, 1, 0.5)

	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.setup(effect, clip_duration, relative_frame_nr)
	track.keyframe_moved_effect.connect(_on_keyframe_moved_effect_ui.bind(current_clip_id, index, is_visual))
	track.keyframe_deleted_effect.connect(_on_keyframe_deleted_effect_ui.bind(current_clip_id, index, is_visual))
	track.keyframe_dragged_to.connect(_on_keyframe_dragged_to_effect_ui.bind(current_clip_id))

	track_hbox.add_child(track_label)
	track_hbox.add_child(track)
	content_vbox.add_child(HSeparator.new())
	content_vbox.add_child(track_hbox)
	return container


func _on_keyframe_moved_effect_ui(old_frame: int, new_frame: int, preserve_existing: bool, clip_id: int, effect_index: int, is_visual: bool) -> void:
	EffectsHandler.move_effect_keyframe_at_frame(clip_id, effect_index, is_visual, old_frame, new_frame, preserve_existing)
	_update_ui_values()


func _on_keyframe_deleted_effect_ui(frame: int, clip_id: int, effect_index: int, is_visual: bool) -> void:
	EffectsHandler.remove_effect_keyframe_at_frame(clip_id, effect_index, is_visual, frame)
	_update_ui_values()


func _on_keyframe_dragged_to_effect_ui(relative_frame: int, clip_id: int) -> void:
	var clip_index: int = Project.clips.index_map[clip_id]
	var clip_start: int = Project.data.clips_start[clip_index]
	EditorCore.set_frame(clip_start + relative_frame)


func _create_param_control(param: EffectParam, index: int, is_visual: bool) -> Control:
	var value: Variant = param.default_value
	match typeof(value):
		TYPE_BOOL:
			var check_button: CheckButton = CheckButton.new()
			check_button.toggled.connect(_effect_param_update_call.bind(index, is_visual, param.id))
			check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return check_button
		TYPE_INT, TYPE_FLOAT:
			var spinbox: SpinBox = SpinBox.new()
			spinbox.min_value = param.min_value if param.min_value != null else MIN_VALUE
			spinbox.max_value = param.max_value if param.max_value != null else MAX_VALUE
			spinbox.step = 0.01 if typeof(value) == TYPE_FLOAT else 1.0
			spinbox.allow_lesser = param.min_value == null
			spinbox.allow_greater = param.max_value == null
			spinbox.custom_arrow_step = spinbox.step
			spinbox.value_changed.connect(_effect_param_update_call.bind(index, is_visual, param.id))
			spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return spinbox
		TYPE_VECTOR2, TYPE_VECTOR2I:
			var hbox: HBoxContainer = HBoxContainer.new()
			var spinbox_x: SpinBox = SpinBox.new()
			var spinbox_y: SpinBox = SpinBox.new()
			# X
			spinbox_x.min_value = param.min_value.x if param.min_value != null else MIN_VALUE
			spinbox_x.max_value = param.max_value.x if param.max_value != null else MAX_VALUE
			spinbox_x.step = 0.01 if typeof(value) == TYPE_FLOAT else 1.0
			spinbox_x.allow_lesser = param.min_value == null
			spinbox_x.allow_greater = param.max_value == null
			spinbox_x.custom_arrow_step = spinbox_x.step
			spinbox_x.value_changed.connect(func(val: float) -> void:
				var current_value: Variant = _get_current_ui_value(hbox, typeof(val))
				current_value.x = val
				_effect_param_update_call.call(current_value, index, is_visual, param.id))
			# Y
			spinbox_y.min_value = param.min_value.y if param.min_value != null else MIN_VALUE
			spinbox_y.max_value = param.max_value.y if param.max_value != null else MAX_VALUE
			spinbox_y.step = 0.01 if typeof(value) == TYPE_FLOAT else 1.0
			spinbox_y.allow_lesser = param.min_value == null
			spinbox_y.allow_greater = param.max_value == null
			spinbox_y.custom_arrow_step = spinbox_y.step
			spinbox_y.value_changed.connect(func(val: float) -> void:
				var current_value: Variant = _get_current_ui_value(hbox, typeof(val))
				current_value.y = val
				_effect_param_update_call.call(current_value, index, is_visual, param.id))

			hbox.add_child(spinbox_x)
			hbox.add_child(spinbox_y)
			hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return hbox
		TYPE_COLOR:
			var color_picker: ColorPickerButton = ColorPickerButton.new()
			color_picker.custom_minimum_size.x = 40
			color_picker.color_changed.connect(_effect_param_update_call.bind(index, is_visual, param.id))
			color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return color_picker
	return Control.new() # Fallback.


## For Spinbox.
func _get_current_ui_value(container: HBoxContainer, type: int) -> Variant:
	var x: float = (container.get_child(0) as SpinBox).value
	var y: float = (container.get_child(1) as SpinBox).value
	if type == TYPE_VECTOR2I:
		return Vector2i(int(x), int(y))
	return Vector2(x, y)


func _get_current_ui_value_for_param(effect: Effect, param_id: String, relative_frame_nr: int) -> Variant:
	for param: EffectParam in effect.params:
		if param.id == param_id:
			return effect.get_value(param, relative_frame_nr)
	return null


func _on_remove_effect(index: int, is_visual: bool) -> void:
	EffectsHandler.remove_effect(current_clip_id, index, is_visual)


func _update_ui_values() -> void:
	if current_clip_id == -1 or !Project.clips.index_map.has(current_clip_id):
		return
	var clip_index: int = Project.clips.index_map[current_clip_id]
	var clip_start: int = Project.data.clips_start[clip_index]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var frame_nr: int = EditorCore.frame_nr - clip_start

	for i: int in clip_effects.video.size():
		_update_ui_values_effect(clip_effects.video, i, frame_nr)
	for i: int in clip_effects.audio.size():
		_update_ui_values_effect(clip_effects.audio, i, frame_nr)


func _update_ui_values_effect(effects: Array, index: int, frame_nr: int) -> void:
	var effect: Effect = effects[index]
	var section: FoldableContainer
	if effects == Project.data.clips_effects[Project.clips.index_map[current_clip_id]].video:
		section = section_visuals
	else:
		section = section_audio
	var effect_container: FoldableContainer = section.get_child(index)
	var content_vbox: VBoxContainer = effect_container.get_child(0)
	if !effect.is_enabled:
		effect_container.folded = true

	for i: int in effect.params.size():
		var param: EffectParam = effect.params[i]
		var param_id: String = param.id
		var param_hbox: HBoxContainer = content_vbox.get_child(i)
		var param_settings: Control = param_hbox.get_child(1)
		var value: Variant = effect.get_value(param, frame_nr)
		_set_param_settings_value(param_settings, value)

		var effect_keyframes: Dictionary = effect.keyframes[param_id]
		if param.keyframeable:
			var keyframe_button: TextureButton = param_hbox.get_child(2)
			if effect_keyframes.has(frame_nr):
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
			else:
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)

	var track_hbox: HBoxContainer = content_vbox.get_child(-1)
	if track_hbox:
		var track: KeyframeTrack = track_hbox.get_child(1)
		track.current_relative_frame = frame_nr
		track.queue_redraw()


func _set_param_settings_value(param_settings: Control, value: Variant) -> void:
	if param_settings is SpinBox:
		var spinbox: SpinBox = param_settings
		spinbox.set_value_no_signal(value as float)
	elif param_settings is CheckButton:
		var check_button: CheckButton = param_settings
		check_button.set_pressed_no_signal(value as bool)
	elif param_settings is HBoxContainer:
		if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_VECTOR2I:
			var spinbox_x: SpinBox = param_settings.get_child(0)
			var spinbox_y: SpinBox = param_settings.get_child(1)
			spinbox_x.set_value_no_signal(value.x as float)
			spinbox_y.set_value_no_signal(value.y as float)
	elif param_settings is ColorPickerButton:
		var color_picker: ColorPickerButton = param_settings
		color_picker.color = value
	else:
		printerr("EffectsPanel: Invalid param settings control! %s" % param_settings)


func _on_switch_enabled(index: int, is_visual: bool) -> void:
	EffectsHandler.switch_enabled(current_clip_id, index, is_visual)

	var clip_index: int = Project.clips.index_map[current_clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var section: FoldableContainer = section_visuals if is_visual else section_audio
	var effect_container: FoldableContainer = section.get_child(index)
	var visible_button: TextureButton = effect_container.get_child(1, true)
	var is_enabled: bool

	if is_visual:
		effect_container.folded = !clip_effects.video[index].is_enabled
	else:
		effect_container.folded =!clip_effects.audio[index].is_enabled

	if effect_container.folded:
		visible_button.texture_normal = load(Library.ICON_INVISIBLE)
	else:
		visible_button.texture_normal = load(Library.ICON_VISIBLE)


func _add_add_effects_button(is_visual: bool) -> Button:
	var button: Button = Button.new()
	button.text = tr("Add effects")
	button.custom_minimum_size.y = 30
	button.pressed.connect(_open_add_effects_popup.bind(is_visual))
	return button


func _open_add_effects_popup(is_visual: bool) -> void:
	var popup: Control = PopupManager.get_popup(PopupManager.ADD_EFFECTS)
	popup.call("load_effects", is_visual, current_clip_id)


func _effect_param_update_call(value: Variant, index: int, is_visual: bool, param_id: String) -> void:
	EffectsHandler.update_param(current_clip_id, index, is_visual, param_id, value, false)


func _keyframe_button_pressed(clip_id: int, index: int, is_visual: bool, param_id: String) -> void:
	var clip_index: int = Project.clips.index_map[clip_id]
	var clip_start: int = Project.data.clips_start[clip_index]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var relative_frame_nr: int = EditorCore.frame_nr - clip_start
	var effect: Effect
	if is_visual:
		effect = clip_effects.video[index]
	else:
		effect = clip_effects.audio[index]

	var effect_keyframes: Dictionary = effect.keyframes[param_id]
	if effect_keyframes.has(relative_frame_nr):
		if relative_frame_nr != 0:
			EffectsHandler.remove_keyframe(clip_id, index, is_visual, param_id, relative_frame_nr)
	else:
		var value: Variant = _get_current_ui_value_for_param(effect, param_id, relative_frame_nr)
		EffectsHandler.update_param(clip_id, index, is_visual, param_id, value, true)
	_update_ui_values()



class DragData:
	var is_visual: bool
	var effect_index: int
