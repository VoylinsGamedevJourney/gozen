extends PanelContainer
# TODO: Add extra tab for text
# TODO: Deleting, adding, updating effects should be done through EffectsHandler

const MIN_VALUE: float = -100000
const MAX_VALUE: float = 100000

const COLOR_KEYFRAMING_ON: Color = Color(1,1,1,0.5)
const COLOR_KEYFRAMING_OFF: Color = Color(1,1,1,1)

const SIZE_EFFECT_HEADER_ICON: int = 16


@export var button_video: Button
@export var button_audio: Button
@export var tab_container: TabContainer

@onready var video_container: VBoxContainer = tab_container.get_tab_control(0)
@onready var audio_container: VBoxContainer = tab_container.get_tab_control(1)

var current_clip_id: int = -1



func _ready() -> void:
	EditorCore.frame_changed.connect(_on_frame_changed)
	ClipHandler.clip_deleted.connect(_on_clip_erased)
	ClipHandler.clip_selected.connect(_on_clip_pressed)
	EffectsHandler.effect_added.connect(_on_effects_updated)
	EffectsHandler.effect_removed.connect(_on_effects_updated)
	EffectsHandler.effects_updated.connect(_on_effects_updated.bind(-1))
	EffectsHandler.effect_values_updated.connect(_update_ui_values)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_clip_pressed(-1)


func _on_clip_pressed(id: int) -> void:
	if id == current_clip_id:
		_update_ui_values()
		return

	current_clip_id = id
	_clear_ui()

	if id == -1:
		button_video.disabled = true
		button_audio.disabled = true
		return

	var type: FileHandler.TYPE = ClipHandler.get_type(id)
	var is_visual: bool = type in EditorCore.VISUAL_TYPES
	var is_audio: bool = type not in EditorCore.AUDIO_TYPES

	button_video.disabled = type not in EditorCore.VISUAL_TYPES
	button_audio.disabled = type not in EditorCore.AUDIO_TYPES

	# Auto-switch tabs
	var current_tab: int = tab_container.current_tab

	if current_tab == 0 and !is_visual:
		tab_container.current_tab = 1
	if current_tab == 1 and !is_audio:
		tab_container.current_tab = 0

	_refresh_current_tab()


func _on_frame_changed() -> void:
	if current_clip_id != -1:
		_update_ui_values()


func _on_clip_erased(clip_id: int) -> void:
	if clip_id == current_clip_id:
		_on_clip_pressed(-1)


func _on_effects_updated(clip_id: int) -> void:
	if clip_id == current_clip_id:
		_refresh_current_tab()


func _on_video_effects_button_pressed() -> void:
	tab_container.current_tab = 0
	_refresh_current_tab()


func _on_audio_effects_button_pressed() -> void:
	tab_container.current_tab = 1
	_refresh_current_tab()


func _refresh_current_tab() -> void:
	if current_clip_id == -1:
		return

	if tab_container.current_tab == 0:
		_load_video_effects()
	else:
		_load_audio_effects()


func _clear_ui() -> void:
	for child: Node in video_container.get_children():
		video_container.remove_child(child)
		child.queue_free()
	for child: Node in audio_container.get_children():
		audio_container.remove_child(child)
		child.queue_free()


func _load_video_effects() -> void:
	_clear_ui()

	if !ClipHandler.clips.has(current_clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(current_clip_id)	
	
	for i: int in clip_data.effects_video.size():
		var effect: GoZenEffectVisual = clip_data.effects_video[i]
		var container: FoldableContainer = _create_effect_ui(effect, i, true)

		video_container.add_child(container)

	video_container.add_child(HSeparator.new())
	video_container.add_child(_add_add_effects_button(true))
	_update_ui_values()


func _load_audio_effects() -> void:
	_clear_ui()

	if !ClipHandler.clips.has(current_clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(current_clip_id)	
	
	for i: int in clip_data.effects_video.size():
		var effect: GoZenEffectAudio = clip_data.effects_audio[i]
		var container: FoldableContainer = _create_effect_ui(effect, i, true)

		audio_container.add_child(container)

	audio_container.add_child(HSeparator.new())
	audio_container.add_child(_add_add_effects_button(false))
	_update_ui_values()


func _create_effect_ui(effect: GoZenEffect, index: int, is_visual: bool) -> FoldableContainer:
	# NOTE: We can add the position of the effect inside of the effect array
	# inside of the metadata and let the buttons check if they are at the top
	# or bottom to disable the correct buttons.

	# TODO: Replace up and down arrows with dragging behaviour

	var clip_data: ClipData = ClipHandler.get_clip(current_clip_id)
	var relative_frame_nr: int = EditorCore.frame_nr - clip_data.start_frame

	var container: FoldableContainer = FoldableContainer.new()
	var button_move_up: TextureButton = TextureButton.new()
	var button_move_down: TextureButton = TextureButton.new()
	var button_delete: TextureButton = TextureButton.new()
	var button_visible: TextureButton = TextureButton.new()
	var grid: GridContainer = GridContainer.new()

	container.title = effect.effect_name
	container.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.tooltip_text = effect.effect_tooltip
	#container.theme_type_variation = "box" # TODO: Create specific theme (light + dark)

	button_move_up.custom_minimum_size.x = SIZE_EFFECT_HEADER_ICON
	button_move_down.custom_minimum_size.x = SIZE_EFFECT_HEADER_ICON
	button_delete.custom_minimum_size.x = SIZE_EFFECT_HEADER_ICON
	button_visible.custom_minimum_size.x = SIZE_EFFECT_HEADER_ICON

	button_move_up.custom_minimum_size.y = SIZE_EFFECT_HEADER_ICON
	button_move_down.custom_minimum_size.y = SIZE_EFFECT_HEADER_ICON
	button_delete.custom_minimum_size.y = SIZE_EFFECT_HEADER_ICON
	button_visible.custom_minimum_size.y = SIZE_EFFECT_HEADER_ICON

	button_move_up.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_move_down.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_delete.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_visible.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	button_move_up.ignore_texture_size = true
	button_move_down.ignore_texture_size = true
	button_delete.ignore_texture_size = true
	button_visible.ignore_texture_size = true

	button_move_up.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button_move_down.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button_delete.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button_visible.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	button_move_up.texture_normal = preload(Library.ICON_MOVE_UP)
	button_move_down.texture_normal = preload(Library.ICON_MOVE_DOWN)
	button_delete.texture_normal = preload(Library.ICON_DELETE)

	if effect.is_enabled:
		button_visible.texture_normal = preload(Library.ICON_VISIBLE)
	else:
		button_visible.texture_normal = preload(Library.ICON_INVISIBLE)

	button_move_up.pressed.connect(_on_move_up.bind(index, is_visual))
	button_move_down.pressed.connect(_on_move_down.bind(index, is_visual))
	button_delete.pressed.connect(_on_remove_effect.bind(index, is_visual))
	button_visible.pressed.connect(_on_switch_enabled.bind(index, is_visual))

	grid.columns = 3

	container.add_title_bar_control(button_move_up)
	container.add_title_bar_control(button_move_down)
	container.add_title_bar_control(button_delete)
	container.add_title_bar_control(button_visible)
	container.add_child(grid)

	# Adding effect params
	for param: EffectParam in effect.params:
		var param_id: String = param.param_id
		var param_title: Label = Label.new()
		var param_settings: Control = _create_param_control(param, index, is_visual)
		var param_keyframe_button: TextureButton = TextureButton.new()

		param_title.text = param.param_name.replace("param_", "").capitalize()
		param_title.tooltip_text = param.param_tooltip
		param_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		param_settings.name = "PARAM_" + param_id

		param_keyframe_button.name = "KEYFRAME_" + param_id
		param_keyframe_button.ignore_texture_size = true
		param_keyframe_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_keyframe_button.custom_minimum_size.x = 14
		param_keyframe_button.pressed.connect(_keyframe_button_pressed.bind(
				current_clip_id, index, is_visual, param_id))

		if effect.keyframes.has(param.param_id) and effect.keyframes[param_id].has(relative_frame_nr):
			param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
		else:
			param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)

		grid.add_child(param_title)
		grid.add_child(param_settings)
		grid.add_child(param_keyframe_button)

	return container


func _create_param_control(param: EffectParam, index: int, is_visual: bool) -> Control:
	var value: Variant = param.default_value

	match typeof(value):
		TYPE_BOOL:
			var check_button: CheckButton = CheckButton.new()

			check_button.toggled.connect(_effect_param_update_call.bind(index, is_visual, param.param_id))
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
			spinbox.value_changed.connect(_effect_param_update_call.bind(index, is_visual, param.param_id))
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
				_effect_param_update_call.call(current_value, index, is_visual, param.param_id))
			
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
				_effect_param_update_call.call(current_value, index, is_visual, param.param_id))

			hbox.add_child(spinbox_x)
			hbox.add_child(spinbox_y)
			hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			return hbox
		TYPE_COLOR:
			var color_picker: ColorPickerButton = ColorPickerButton.new()

			color_picker.custom_minimum_size.x = 40
			color_picker.color_changed.connect(_effect_param_update_call.bind(index, is_visual, param.param_id))
			color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			return color_picker

	return Control.new() # Fallback


func _get_current_ui_value(container: HBoxContainer, type: int) -> Variant:
	var x: float = container.get_child(0).value
	var y: float = container.get_child(1).value

	if type == TYPE_VECTOR2I:
		return Vector2i(int(x), int(y))
	return Vector2(x, y)


func _get_current_ui_value_for_param(effect: GoZenEffect, param_id: String, relative_frame_nr: int) -> Variant:
	for param: EffectParam in effect.params:
		if param.param_id == param_id:
			return effect.get_value(param, relative_frame_nr)
	return null

func _on_move_up(index: int, is_visual: bool) -> void:
	EffectsHandler.move_effect(current_clip_id, index, index + 1, is_visual)


func _on_move_down(index: int, is_visual: bool) -> void:
	EffectsHandler.move_effect(current_clip_id, index, index - 1, is_visual)


func _on_remove_effect(index: int, is_visual: bool) -> void:
	EffectsHandler.remove_effect(current_clip_id, index, is_visual)


func _update_ui_values() -> void:
	if current_clip_id == -1 or !ClipHandler.clips.has(current_clip_id): return
	var clip_data: ClipData = ClipHandler.get_clip(current_clip_id)
	var frame_nr: int = EditorCore.frame_nr - clip_data.start_frame
	var container: VBoxContainer
	var effects: Array

	if tab_container.current_tab == 0:
		container = video_container
		effects = clip_data.effects_video
	else:
		container = audio_container
		effects = clip_data.effects_audio

	for i: int in container.get_child_count() - 2: # - 2 because of separator + add_effects button
		var effect: GoZenEffect = effects[i]
		var foldable_container: FoldableContainer = container.get_child(i)
		var grid: GridContainer = foldable_container.get_child(0)

		if !effect.is_enabled:
			foldable_container.folded = true

		for param: EffectParam in effect.params:
			var param_id: String = param.param_id
			var param_settings: Control = grid.get_node_or_null("PARAM_" + param_id)

			if param_settings:
				var value: Variant = effect.get_value(param, frame_nr)
				_set_param_settings_value(param_settings, value)
			
			var keyframe_button: TextureButton = grid.get_node_or_null("KEYFRAME_" + param_id)
			if !keyframe_button: continue
			if effect.keyframes[param_id].has(frame_nr):
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
			else:
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)
			if effect.keyframes[param_id].size() <= 1:
				keyframe_button.modulate = COLOR_KEYFRAMING_OFF
			else:
				keyframe_button.modulate = COLOR_KEYFRAMING_ON


func _set_param_settings_value(param_settings: Control, value: Variant) -> void:
	if param_settings is SpinBox:
		if param_settings.value != value:
			param_settings.set_value_no_signal(value)
	elif param_settings is CheckButton:
		if param_settings.value != value:
			(param_settings as CheckButton).set_pressed_no_signal(value)
	elif param_settings is HBoxContainer:
		if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_VECTOR2I:
			var spinbox_x: SpinBox = param_settings.get_child(0)
			var spinbox_y: SpinBox = param_settings.get_child(1)

			if spinbox_x.value != value.x:
				spinbox_x.set_value_no_signal(value.x)
			if spinbox_y.value != value.y:
				spinbox_y.set_value_no_signal(value.y)
	elif param_settings is ColorPickerButton:
		if param_settings.color != value:
			(param_settings as ColorPickerButton).color = value
	else:
		printerr("EffectsPanel: Invalid param settings control! %s" % param_settings)


func _on_switch_enabled(index: int, is_visual: bool) -> void:
	EffectsHandler.switch_enabled(current_clip_id, index, is_visual)


	var container: FoldableContainer = tab_container.get_current_tab_control().get_child(index)
	var visible_button: TextureButton = container.get_child(-2, true)
	var is_enabled: bool

	if is_visual:
		is_enabled = ClipHandler.get_clip(current_clip_id).effects_video[index].is_enabled
	else:
		is_enabled = ClipHandler.get_clip(current_clip_id).effects_audio[index].is_enabled

	container.folded = !is_enabled

	if is_enabled:
		visible_button.texture_normal = load(Library.ICON_VISIBLE)
	else:
		visible_button.texture_normal = load(Library.ICON_INVISIBLE)


func _add_add_effects_button(is_visual: bool) -> Button:
	var button: Button = Button.new()

	button.text = tr("button_add_effects")
	button.tooltip_text = tr("button_tooltip_add_effects")
	button.custom_minimum_size.y = 30
	button.pressed.connect(_open_add_effects_popup.bind(is_visual))

	return button


func _open_add_effects_popup(is_visual: bool) -> void:
	var popup: Control = PopupManager.get_popup(PopupManager.POPUP.ADD_EFFECTS)

	popup.load_effects(is_visual, current_clip_id)


func _effect_param_update_call(value: Variant, index: int, is_visual: bool, param_id: String) -> void:
	EffectsHandler.update_param(current_clip_id, index, is_visual, param_id, value, false)


func _keyframe_button_pressed(clip_id: int, index: int, is_visual: bool, param_id: String) -> void:
	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var relative_frame_nr: int = EditorCore.frame_nr - clip_data.start_frame
	var effect: GoZenEffect
	if is_visual: effect = clip_data.effects_video[index]
	else: effect = clip_data.effects_audio[index]

	if effect.keyframes[param_id].has(relative_frame_nr):
		EffectsHandler.remove_keyframe(clip_id, index, is_visual, param_id, relative_frame_nr)
	else:
		var value: Variant = _get_current_ui_value_for_param(effect, param_id, relative_frame_nr)
		EffectsHandler.update_param(clip_id, index, is_visual, param_id, value, true)

	_update_ui_values()
