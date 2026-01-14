class_name EffectsPanel
extends PanelContainer
# TODO: Add extra tab for text
# TODO: Deleting, adding, updating effects should be done through EffectsHandler

const MIN_VALUE: float = -100000
const MAX_VALUE: float = 100000


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
	EffectsHandler.effects_updated.connect(_on_effects_updated)


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

	button_video.disabled = !is_visual
	button_audio.disabled = !is_audio

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
		child.queue_free()
	for child: Node in audio_container.get_children():
		child.queue_free()


func _load_video_effects() -> void:
	_clear_ui()

	if !ClipHandler.has_clip(current_clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(current_clip_id)	
	
	for i: int in clip_data.effects_video.size():
		var effect: GoZenEffectVisual = clip_data.effects_video[i]
		var container: FoldableContainer = _create_effect_ui(effect, i, true)

		video_container.add_child(container)

	_update_ui_values()


func _load_audio_effects() -> void:
	_clear_ui()

	if !ClipHandler.has_clip(current_clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(current_clip_id)	
	
	for i: int in clip_data.effects_video.size():
		var effect: GoZenEffectAudio = clip_data.effects_audio[i]
		var container: FoldableContainer = _create_effect_ui(effect, i, true)

		audio_container.add_child(container)

	_update_ui_values()


func _create_effect_ui(effect: GoZenEffect, index: int, is_visual: bool) -> FoldableContainer:
	# NOTE: We can add the position of the effect inside of the effect array
	# inside of the metadata and let the buttons check if they are at the top
	# or bottom to disable the correct buttons.

	var container: FoldableContainer = FoldableContainer.new()
	var button_move_up: TextureButton = TextureButton.new()
	var button_move_down: TextureButton = TextureButton.new()
	var button_delete: TextureButton = TextureButton.new()
	var grid: GridContainer = GridContainer.new()

	container.title = effect.effect_name
	container.title_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#container.theme_type_variation = "box" # TODO: Create specific theme (light + dark)

	button_move_up.custom_minimum_size.x = 20
	button_move_down.custom_minimum_size.x = 20
	button_delete.custom_minimum_size.x = 20

	button_move_up.custom_minimum_size.y = 20
	button_move_down.custom_minimum_size.y = 20
	button_delete.custom_minimum_size.y = 20

	button_move_up.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_move_down.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_delete.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	button_move_up.ignore_texture_size = true
	button_move_down.ignore_texture_size = true
	button_delete.ignore_texture_size = true

	button_move_up.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button_move_down.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button_delete.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	button_move_up.texture_normal = preload(Library.ICON_MOVE_UP)
	button_move_down.texture_normal = preload(Library.ICON_MOVE_DOWN)
	button_delete.texture_normal = preload(Library.ICON_DELETE)

	button_move_up.pressed.connect(_on_move_up.bind(index, is_visual))
	button_move_down.pressed.connect(_on_move_down.bind(index, is_visual))
	button_delete.pressed.connect(_on_remove_effect.bind(index, is_visual))

	grid.columns = 2

	container.add_title_bar_control(button_move_up)
	container.add_title_bar_control(button_move_down)
	container.add_title_bar_control(button_delete)
	container.add_child(grid)

	# Adding effect params
	for param: EffectParam in effect.params:
		var param_title: Label = Label.new()
		var param_settings: Control = _create_param_control(param, index, is_visual)

		param_title.text = param.param_name.replace("param_", "").capitalize() # TODO: Localize this
		param_title.tooltip_text = param.param_id # TODO: Create better descriptions
		param_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		param_settings.name = "PARAM_" + param.param_id

		grid.add_child(param_title)
		grid.add_child(param_settings)

	return container


func _create_param_control(param: EffectParam, index: int, is_visual: bool) -> Control:
	var value: Variant = param.default_value
	var update_call: Callable = func(val: Variant) -> void:
		EffectsHandler.update_param(current_clip_id, index, is_visual, param.param_id, val)

	match typeof(value):
		TYPE_BOOL:
			var check_button: CheckButton = CheckButton.new()

			check_button.toggled.connect(update_call)
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
			spinbox.value_changed.connect(update_call)
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
				update_call.call(current_value))
			
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
				update_call.call(current_value))

			hbox.add_child(spinbox_x)
			hbox.add_child(spinbox_y)
			hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			return hbox
		TYPE_COLOR:
			var color_picker: ColorPickerButton = ColorPickerButton.new()

			color_picker.custom_minimum_size.x = 40
			color_picker.color_changed.connect(update_call)
			color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			return color_picker

	return Control.new() # Fallback


func _get_current_ui_value(container: HBoxContainer, type: int) -> Variant:
	var x: float = container.get_child(0).value
	var y: float = container.get_child(1).value

	if type == TYPE_VECTOR2I:
		Vector2i(int(x), int(y))
	return Vector2(x, y)


func _on_move_up(index: int, is_visual: bool) -> void:
	EffectsHandler.move_effect(current_clip_id, index, index + 1, is_visual)


func _on_move_down(index: int, is_visual: bool) -> void:
	EffectsHandler.move_effect(current_clip_id, index, index - 1, is_visual)


func _on_remove_effect(index: int, is_visual: bool) -> void:
	EffectsHandler.remove_effect(current_clip_id, index, is_visual)


func _update_ui_values() -> void:
	if current_clip_id == -1 or !ClipHandler.has_clip(current_clip_id):
		return

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

	for i: int in container.get_child_count():
		var effect: GoZenEffect = effects[i]
		var grid: GridContainer = container.get_child(i).get_child(0)

		for param: EffectParam in effect.params:
			var param_settings: Control = grid.get_node_or_null("PARAM_" + param.param_id)

			if param_settings:
				var value: Variant = effect.get_value(param, frame_nr)

				_set_param_settings_value(param_settings, value)


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
