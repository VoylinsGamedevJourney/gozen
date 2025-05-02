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
@export var mute_button: CheckButton
@export var gain_label: Label
@export var gain_spinbox: SpinBox
@export var mono_label: Label
@export var mono_option_button: OptionButton

var current_clip_id: int = -1



func _ready() -> void:
	instance = self
	on_clip_pressed(-1)


func on_clip_pressed(id: int) -> void:
	current_clip_id = id

	if Project.data == null or id not in Project.get_clip_ids():
		tab_container.current_tab = 2 # Empty
		button_video_effects.visible = false
		button_audio_effects.visible = false
		return

	var data: ClipData = Project.get_clip(id)
	var type: File.TYPE = Project.get_clip_type(id)
	
	match type:
		File.TYPE.IMAGE:
			button_video_effects.visible = false
			button_audio_effects.visible = false
			button_video_effects.button_pressed = true
			button_video_effects.pressed.emit()
			_set_video_effect_values()
		File.TYPE.AUDIO:
			button_video_effects.visible = false
			button_audio_effects.visible = false
			button_audio_effects.button_pressed = true
			button_audio_effects.pressed.emit()
			_set_audio_effect_values()
		File.TYPE.VIDEO:
			var showing: bool = Project.get_file_data(data.file_id).audio != null

			button_video_effects.visible = true
			button_audio_effects.visible = showing
			_set_video_effect_values()

			if button_audio_effects.visible:
				_set_audio_effect_values()
		File.TYPE.TEXT:
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
	var video_effects_data: EffectsVideo = Project.get_clip(current_clip_id).effects_video

	# Transform effects
	check_reset_transform_button()
	position_x_spinbox.value = video_effects_data.position.x
	position_y_spinbox.value = video_effects_data.position.y
	size_x_spinbox.value = video_effects_data.size.x
	size_y_spinbox.value = video_effects_data.size.y
	scale_spinbox.value = video_effects_data.scale
	rotation_spinbox.value = video_effects_data.rotation
	alpha_spinbox.value = video_effects_data.alpha
	pivot_x_spinbox.value = video_effects_data.pivot.x
	pivot_y_spinbox.value = video_effects_data.pivot.y

	# Color Correction Effects
	check_reset_color_correction_button()
	enable_color_correction.button_pressed = video_effects_data.enable_color_correction

	color_correction_effects_grid.visible = video_effects_data.enable_color_correction
	brightness_spinbox.value = video_effects_data.brightness
	contrast_spinbox.value = video_effects_data.contrast
	saturation_spinbox.value = video_effects_data.saturation
	
	red_value_spinbox.value = video_effects_data.red_value
	green_value_spinbox.value = video_effects_data.green_value
	blue_value_spinbox.value = video_effects_data.blue_value
	
	tint_color.color = video_effects_data.tint_color
	tint_effect_factor.value = video_effects_data.tint_effect_factor
	
	# Chroma Key Effects
	check_reset_chroma_key_button()
	enable_chroma_key.button_pressed = video_effects_data.enable_chroma_key
	chroma_effects_grid.visible = video_effects_data.enable_chroma_key
	chroma_key_color.color = video_effects_data.chroma_key_color
	chroma_key_tolerance.value = video_effects_data.chroma_key_tolerance
	chroma_key_softness.value = video_effects_data.chroma_key_softness

	if tab_container.current_tab == 2:
		tab_container.current_tab = 0


func _set_audio_effect_values() -> void:
	var audio_effects_data: EffectsAudio = Project.get_clip(current_clip_id).effects_audio

	mute_button.button_pressed = audio_effects_data.mute
	gain_spinbox.value = audio_effects_data.gain
	mono_option_button.selected = audio_effects_data.mono

	_on_mute_check_button_toggled(mute_button.button_pressed)


# Audio effects
func _on_gain_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_audio.gain = value


func _on_mono_option_button_item_selected(value: int) -> void:
	match value:
		0: Project.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.DISABLE
		1: Project.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.LEFT_CHANNEL
		2: Project.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.RIGHT_CHANNEL


func _on_mute_check_button_toggled(toggled_on: bool) -> void:
	Project.get_clip(current_clip_id).effects_audio.mute = toggled_on
	gain_label.visible = !toggled_on
	gain_spinbox.visible = !toggled_on
	mono_label.visible = !toggled_on
	mono_option_button.visible = !toggled_on


# Video effects

func _on_position_x_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.position.x = floor(value)
	reset_transform_effects.visible = !Project.get_clip(current_clip_id).effects_video.transforms_equal_to_defaults()
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_position_y_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.position.y = floor(value)
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_size_x_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.size.x = floor(value)
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_size_y_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.size.y = floor(value)
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_scale_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.scale = value
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_rotation_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.rotation = value
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_alpha_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.alpha = value
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_pivot_x_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.pivot.x = floor(value)
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_pivot_y_spin_box_value_changed(value:float) -> void:
	Project.get_clip(current_clip_id).effects_video.pivot.y = floor(value)
	check_reset_transform_button()
	Editor.set_frame(Editor.frame_nr)


func _on_enable_color_correction_button_toggled(toggled_on: bool) -> void:
	Project.get_clip(current_clip_id).effects_video.enable_color_correction = toggled_on
	color_correction_effects_grid.visible = toggled_on
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_brightness_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.brightness = value
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_contrast_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.contrast = value
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_saturation_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.saturation = value
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_red_value_spin_box_value_changed(value: float) -> void: 
	Project.get_clip(current_clip_id).effects_video.red_value = value
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_green_value_spin_box_value_changed(value: float) -> void: 
	Project.get_clip(current_clip_id).effects_video.green_value = value
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_blue_value_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.blue_value = value
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_tint_color_picker_button_color_changed(color: Color) -> void:
	Project.get_clip(current_clip_id).effects_video.tint_color = color
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_tint_color_effect_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.tint_effect_factor = value
	check_reset_color_correction_button()
	Editor.set_frame(Editor.frame_nr)


func _on_enable_chroma_key_button_toggled(toggled_on: bool) -> void:
	Project.get_clip(current_clip_id).effects_video.enable_chroma_key = toggled_on
	chroma_effects_grid.visible = toggled_on
	check_reset_chroma_key_button()
	Editor.set_frame(Editor.frame_nr)


func _on_chroma_key_color_picker_button_color_changed(color: Color) -> void:
	Project.get_clip(current_clip_id).effects_video.chroma_key_color = color
	check_reset_chroma_key_button()
	Editor.set_frame(Editor.frame_nr)


func _on_chroma_key_tolerance_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.chroma_key_tolerance = value
	check_reset_chroma_key_button()
	Editor.set_frame(Editor.frame_nr)


func _on_chroma_key_softness_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.chroma_key_softness = value
	check_reset_chroma_key_button()
	Editor.set_frame(Editor.frame_nr)


# Reset buttons

func _on_reset_transform_effects_button_pressed() -> void:
	Project.get_clip(current_clip_id).effects_video.reset_transform()
	Editor.set_frame(Editor.frame_nr)
	reset_transform_effects.visible = false
	on_clip_pressed(current_clip_id)


func _on_reset_color_correction_effects_button_pressed() -> void:
	Project.get_clip(current_clip_id).effects_video.reset_color_correction()
	Editor.set_frame(Editor.frame_nr)
	reset_color_correction_effects.visible = false
	on_clip_pressed(current_clip_id)


func _on_reset_chroma_key_effects_button_pressed() -> void:
	Project.get_clip(current_clip_id).effects_video.reset_chroma_key()
	Editor.set_frame(Editor.frame_nr)
	reset_chroma_key_effects.visible = false
	on_clip_pressed(current_clip_id)


# Reset button visibility

func check_reset_transform_button() -> void:
	reset_transform_effects.visible = !Project.get_clip(
			current_clip_id).effects_video.transforms_equal_to_defaults()


func check_reset_color_correction_button() -> void:
	if !Project.get_clip(current_clip_id).effects_video.enable_color_correction:
		reset_color_correction_effects.visible = false
		return
	reset_color_correction_effects.visible = !Project.get_clip(
			current_clip_id).effects_video.color_correction_equal_to_defaults()


func check_reset_chroma_key_button() -> void:
	if !Project.get_clip(current_clip_id).effects_video.enable_chroma_key:
		reset_chroma_key_effects.visible = false
		return
	reset_chroma_key_effects.visible = !Project.get_clip(
			current_clip_id).effects_video.chroma_key_equal_to_defaults()

