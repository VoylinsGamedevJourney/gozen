class_name EffectsPanel
extends PanelContainer



static var instance: EffectsPanel

@export_group("Main nodes")
@export var button_video_effects: Button
@export var button_audio_effects: Button
@export var tab_container: TabContainer

@export_group("Video effects")
@export_subgroup("Transform effects")
@export var reset_transform_effects: TextureButton

@export var position_x_spinbox: SpinBox
@export var position_y_spinbox: SpinBox

@export var size_x_spinbox: SpinBox
@export var size_y_spinbox: SpinBox

@export var scale_spinbox: SpinBox

@export var rotation_spinbox: SpinBox

@export var alpha_spinbox: SpinBox

@export var pivot_x_spinbox: SpinBox
@export var pivot_y_spinbox: SpinBox

@export_subgroup("Fade effects")
@export var reset_fade_video_effects: TextureButton

@export var fade_in_video_spinbox: SpinBox
@export var fade_out_video_spinbox: SpinBox

@export_subgroup("Color correction")
@export var reset_color_correction_effects: TextureButton
@export var color_correction_effects_grid: GridContainer
@export var enable_color_correction: CheckButton

@export var brightness_spinbox: SpinBox
@export var contrast_spinbox: SpinBox
@export var saturation_spinbox: SpinBox

@export var red_value_spinbox: SpinBox
@export var green_value_spinbox: SpinBox
@export var blue_value_spinbox: SpinBox

@export var tint_color: ColorPickerButton
@export var tint_effect_factor: SpinBox

@export_subgroup("Chroma effects")
@export var reset_chroma_key_effects: TextureButton
@export var chroma_effects_grid: GridContainer
@export var enable_chroma_key: CheckButton

@export var chroma_key_color: ColorPickerButton
@export var chroma_key_tolerance: SpinBox
@export var chroma_key_softness: SpinBox

@export_group("Audio effects")
@export var reset_audio_basics_key_effects: TextureButton
@export var mute_button: CheckButton
@export var gain_label: Label
@export var gain_spinbox: SpinBox
@export var mono_label: Label
@export var mono_option_button: OptionButton

@export_subgroup("Fade effects")
@export var reset_fade_audio_effects: TextureButton

@export var fade_in_audio_spinbox: SpinBox
@export var fade_out_audio_spinbox: SpinBox


var current_clip_id: int = -1



func _ready() -> void:
	instance = self
	button_video_effects.visible = false
	tab_container.current_tab = 2 # Empty
	button_audio_effects.visible = false


func _on_clip_erased(clip_id: int) -> void:
	if clip_id == current_clip_id:
		on_clip_pressed(-1)


func on_clip_pressed(id: int) -> void:
	current_clip_id = id

	if Project.is_loaded() == null or id not in ClipHandler.get_clip_ids():
		tab_container.current_tab = 2 # Empty
		button_video_effects.visible = false
		button_audio_effects.visible = false
		return

	var data: ClipData = ClipHandler.get_clip(id)
	var type: FileHandler.TYPE = ClipHandler.get_clip_type(id)
	
	match type:
		FileHandler.TYPE.IMAGE:
			button_video_effects.visible = false
			button_audio_effects.visible = false
			button_video_effects.button_pressed = true
			button_video_effects.pressed.emit()
			_set_video_effect_values()
		FileHandler.TYPE.AUDIO:
			button_video_effects.visible = false
			button_audio_effects.visible = false
			button_audio_effects.button_pressed = true
			button_audio_effects.pressed.emit()
			_set_audio_effect_values()
		FileHandler.TYPE.VIDEO:
			var showing: bool = FileHandler.get_file_data(data.file_id).audio != null

			button_video_effects.visible = true
			button_audio_effects.visible = showing
			_set_video_effect_values()

			if button_audio_effects.visible:
				_set_audio_effect_values()
		FileHandler.TYPE.TEXT:
			button_video_effects.visible = true
			button_audio_effects.visible = false
			button_video_effects.button_pressed = true
			button_video_effects.pressed.emit()
			_set_video_effect_values()


func _on_video_effects_button_pressed() -> void:
	tab_container.current_tab = 0


func _on_audio_effects_button_pressed() -> void:
	tab_container.current_tab = 1


func _set_video_effect_values() -> void:
	pass
#	var video_effects_data: EffectsVideo = ClipHandler.get_clip(current_clip_id).effects_video
#
#	if video_effects_data.clip_id == -1:
#		video_effects_data.clip_id = current_clip_id
#
#	# Transform effects
#	check_reset_transform_button()
#	position_x_spinbox.value = video_effects_data.position[0].x
#	position_y_spinbox.value = video_effects_data.position[0].y
#	size_x_spinbox.value = video_effects_data.size[0].x
#	size_y_spinbox.value = video_effects_data.size[0].y
#	scale_spinbox.value = video_effects_data.scale[0]
#	rotation_spinbox.value = video_effects_data.rotation[0]
#	alpha_spinbox.value = video_effects_data.alpha[0]
#	pivot_x_spinbox.value = video_effects_data.pivot[0].x
#	pivot_y_spinbox.value = video_effects_data.pivot[0].y
#
#	# Fade effects
#	check_reset_fade_video_button()
#	fade_in_video_spinbox.value = video_effects_data.fade_in
#	fade_out_video_spinbox.value = video_effects_data.fade_out
#
#	# Color Correction Effects
#	check_reset_color_correction_button()
#	enable_color_correction.button_pressed = video_effects_data.enable_color_correction
#
#	color_correction_effects_grid.visible = video_effects_data.enable_color_correction
#	brightness_spinbox.value = video_effects_data.brightness[0]
#	contrast_spinbox.value = video_effects_data.contrast[0]
#	saturation_spinbox.value = video_effects_data.saturation[0]
#	
#	red_value_spinbox.value = video_effects_data.red_value[0]
#	green_value_spinbox.value = video_effects_data.green_value[0]
#	blue_value_spinbox.value = video_effects_data.blue_value[0]
#	
#	tint_color.color = video_effects_data.tint_color[0]
#	tint_effect_factor.value = video_effects_data.tint_effect_factor[0]
#	
#	# Chroma Key Effects
#	check_reset_chroma_key_button()
#	enable_chroma_key.button_pressed = video_effects_data.enable_chroma_key
#	chroma_effects_grid.visible = video_effects_data.enable_chroma_key
#	chroma_key_color.color = video_effects_data.chroma_key_color[0]
#	chroma_key_tolerance.value = video_effects_data.chroma_key_tolerance[0]
#	chroma_key_softness.value = video_effects_data.chroma_key_softness[0]
#
#	if tab_container.current_tab == 2:
#		tab_container.current_tab = 0


func _set_audio_effect_values() -> void:
	pass
#	var audio_effects_data: EffectsAudio = ClipHandler.get_clip(current_clip_id).effects_audio
#
#	if audio_effects_data.clip_id == -1:
#		audio_effects_data.clip_id = current_clip_id
#
#	check_reset_basics_audio_button()
#	mute_button.button_pressed = audio_effects_data.mute
#	gain_spinbox.value = audio_effects_data.gain[0]
#	mono_option_button.selected = audio_effects_data.mono
#
#	check_reset_fade_audio_button()
#	fade_in_audio_spinbox.value = audio_effects_data.fade_in
#	fade_out_audio_spinbox.value = audio_effects_data.fade_out
#
#	var duration: int = ClipHandler.get_clip(current_clip_id).duration
#	fade_in_audio_spinbox.max_value = duration
#	fade_out_audio_spinbox.max_value = duration
#
#	_on_mute_check_button_toggled(mute_button.button_pressed)


func _change_made(check_func: Callable) -> void:
	check_func.call()
	EditorCore.set_frame(EditorCore.frame_nr)


# Audio effects
func _on_gain_spin_box_value_changed(value: float) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_audio.gain[0] = value
#	_change_made(check_reset_basics_audio_button)


func _on_mono_option_button_item_selected(value: int) -> void:
	pass
#	match value:
#		0: ClipHandler.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.DISABLE
#		1: ClipHandler.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.LEFT_CHANNEL
#		2: ClipHandler.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.RIGHT_CHANNEL
#	_change_made(check_reset_basics_audio_button)


func _on_mute_check_button_toggled(toggled_on: bool) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_audio.mute = toggled_on
#	gain_label.visible = !toggled_on
#	gain_spinbox.visible = !toggled_on
#	mono_label.visible = !toggled_on
#	mono_option_button.visible = !toggled_on
#	_change_made(check_reset_basics_audio_button)


# Video effects.
func _on_position_x_spin_box_value_changed(value: float) -> void:
	pass
#	var effects_video: EffectsVideo = ClipHandler.get_clip(current_clip_id).effects_video
#	var frame: int = 0
#
#	InputManager.undo_redo.create_action("Change clip position")
#	InputManager.undo_redo.add_do_method(effects_video.set_position_x.bind(frame, floor(value)))
#
#	if effects_video.position.has(frame):
#		InputManager.undo_redo.add_undo_method(effects_video.set_position_x.bind(frame, effects_video.position[frame].x))
#	else:
#		InputManager.undo_redo.add_undo_method(effects_video.set_position_x.bind(frame, effects_video.position.erase(frame)))
#
#	InputManager.undo_redo.commit_action()
#
#	_change_made(check_reset_transform_button)


func _on_position_y_spin_box_value_changed(value: float) -> void:
	pass
#	var effects_video: EffectsVideo = ClipHandler.get_clip(current_clip_id).effects_video
#	var frame: int = 0
#
#	InputManager.undo_redo.create_action("Change clip position")
#	InputManager.undo_redo.add_do_method(effects_video.set_position_y.bind(frame, floor(value)))
#
#	if effects_video.position.has(frame):
#		InputManager.undo_redo.add_undo_method(effects_video.set_position_y.bind(frame, effects_video.position[frame].y))
#	else:
#		InputManager.undo_redo.add_undo_method(effects_video.set_position_y.bind(frame, effects_video.position.erase(frame)))
#
#	InputManager.undo_redo.commit_action()
#
#	ClipHandler.get_clip(current_clip_id).effects_video.position[0].y = floor(value)
#	_change_made(check_reset_transform_button)


func _on_size_x_spin_box_value_changed(value: float) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_video.size[0].x = floor(value)
#	_change_made(check_reset_transform_button)


func _on_size_y_spin_box_value_changed(value: float) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_video.size[0].y = floor(value)
#	_change_made(check_reset_transform_button)


func _on_scale_spin_box_value_changed(value: float) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_video.scale[0] = value
#	_change_made(check_reset_transform_button)


func _on_rotation_spin_box_value_changed(value: float) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_video.rotation[0] = value
#	_change_made(check_reset_transform_button)


func _on_alpha_spin_box_value_changed(value: float) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_video.alpha[0] = value
#	_change_made(check_reset_transform_button)


func _on_pivot_x_spin_box_value_changed(value: float) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_video.pivot[0].x = floor(value)
#	_change_made(check_reset_transform_button)


func _on_pivot_y_spin_box_value_changed(value:float) -> void:
	pass
#	ClipHandler.get_clip(current_clip_id).effects_video.pivot[0].y = floor(value)
#	_change_made(check_reset_transform_button)


#func _on_fade_in_spin_box_value_changed(value: float, video: bool) -> void:
#	var clip_button: ClipButton = Timeline.instance.clips.get_node(str(current_clip_id))
#
#	if video:
#		ClipHandler.get_clip(current_clip_id).effects_video.fade_in = floor(value)
#		check_reset_fade_video_button()
#	else: # audio
#		ClipHandler.get_clip(current_clip_id).effects_audio.fade_in = floor(value)
#		check_reset_fade_audio_button()
#
#	clip_button.on_fade_changed()
#	EditorCore.set_frame(EditorCore.frame_nr)
#
#
#func _on_fade_out_spin_box_value_changed(value: float, video: bool) -> void:
#	var clip_button: ClipButton = Timeline.instance.clips.get_node(str(current_clip_id))
#
#	if video:
#		ClipHandler.get_clip(current_clip_id).effects_video.fade_out = floor(value)
#		_change_made(check_reset_fade_video_button)
#	else: # audio
#		ClipHandler.get_clip(current_clip_id).effects_audio.fade_out = floor(value)
#		_change_made(check_reset_fade_audio_button)
#
#	clip_button.on_fade_changed()
#	EditorCore.set_frame(EditorCore.frame_nr)


#func _on_enable_color_correction_button_toggled(toggled_on: bool) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.enable_color_correction = toggled_on
#	color_correction_effects_grid.visible = toggled_on
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_brightness_spin_box_value_changed(value: float) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.brightness[0] = value
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_contrast_spin_box_value_changed(value: float) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.contrast[0] = value
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_saturation_spin_box_value_changed(value: float) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.saturation[0] = value
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_red_value_spin_box_value_changed(value: float) -> void: 
#	ClipHandler.get_clip(current_clip_id).effects_video.red_value[0] = value
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_green_value_spin_box_value_changed(value: float) -> void: 
#	ClipHandler.get_clip(current_clip_id).effects_video.green_value[0] = value
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_blue_value_spin_box_value_changed(value: float) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.blue_value[0] = value
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_tint_color_picker_button_color_changed(color: Color) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.tint_color[0] = color
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_tint_color_effect_spin_box_value_changed(value: float) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.tint_effect_factor[0] = value
#	_change_made(check_reset_color_correction_button)
#
#
#func _on_enable_chroma_key_button_toggled(toggled_on: bool) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.enable_chroma_key = toggled_on
#	chroma_effects_grid.visible = toggled_on
#	_change_made(check_reset_chroma_key_button)
#
#
#func _on_chroma_key_color_picker_button_color_changed(color: Color) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.chroma_key_color[0] = color
#	_change_made(check_reset_chroma_key_button)
#
#
#func _on_chroma_key_tolerance_spin_box_value_changed(value: float) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.chroma_key_tolerance[0] = value
#	_change_made(check_reset_chroma_key_button)
#
#
#func _on_chroma_key_softness_spin_box_value_changed(value: float) -> void:
#	ClipHandler.get_clip(current_clip_id).effects_video.chroma_key_softness[0] = value
#	_change_made(check_reset_chroma_key_button)
#
#
## Reset buttons.
#func _on_reset_transform_effects_button_pressed() -> void:
#	_change_made(ClipHandler.get_clip(current_clip_id).effects_video.reset_transform)
#	reset_transform_effects.visible = false
#	on_clip_pressed(current_clip_id)
#
#
#func _on_reset_fade_video_effects_button_pressed() -> void:
#	_change_made(ClipHandler.get_clip(current_clip_id).effects_video.reset_fade)
#	reset_fade_video_effects.visible = false
#	on_clip_pressed(current_clip_id)
#
#
#func _on_reset_fade_audio_effects_button_pressed() -> void:
#	_change_made(ClipHandler.get_clip(current_clip_id).effects_audio.reset_fade)
#	reset_fade_audio_effects.visible = false
#	on_clip_pressed(current_clip_id)
#
#
#func _on_reset_color_correction_effects_button_pressed() -> void:
#	_change_made(ClipHandler.get_clip(current_clip_id).effects_video.reset_color_correction)
#	reset_color_correction_effects.visible = false
#	on_clip_pressed(current_clip_id)
#
#
#func _on_reset_chroma_key_effects_button_pressed() -> void:
#	_change_made(ClipHandler.get_clip(current_clip_id).effects_video.reset_chroma_key)
#	reset_chroma_key_effects.visible = false
#	on_clip_pressed(current_clip_id)
#
#
## Reset button visibility.
#func check_reset_transform_button() -> void:
#	reset_transform_effects.visible = !ClipHandler.get_clip(
#			current_clip_id).effects_video.transforms_equal_to_defaults()
#
#
#func check_reset_fade_video_button() -> void:
#	reset_transform_effects.visible = !ClipHandler.get_clip(
#			current_clip_id).effects_video.fade_equal_to_defaults()
#
#
#func check_reset_fade_audio_button() -> void:
#	reset_transform_effects.visible = !ClipHandler.get_clip(
#			current_clip_id).effects_audio.fade_equal_to_defaults()
#
#
#func check_reset_color_correction_button() -> void:
#	if !ClipHandler.get_clip(current_clip_id).effects_video.enable_color_correction:
#		reset_color_correction_effects.visible = false
#		return
#	reset_color_correction_effects.visible = !ClipHandler.get_clip(
#			current_clip_id).effects_video.color_correction_equal_to_defaults()
#
#
#func check_reset_chroma_key_button() -> void:
#	if !ClipHandler.get_clip(current_clip_id).effects_video.enable_chroma_key:
#		reset_chroma_key_effects.visible = false
#		return
#	reset_chroma_key_effects.visible = !ClipHandler.get_clip(
#			current_clip_id).effects_video.chroma_key_equal_to_defaults()
#
#
#func check_reset_basics_audio_button() -> void:
#	reset_audio_basics_key_effects.visible = !ClipHandler.get_clip(
#			current_clip_id).effects_audio.basics_equal_to_defaults()
#
