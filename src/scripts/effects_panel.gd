class_name EffectsPanel
extends PanelContainer

# TODO: Text effects should be on top of the visual effects VBox.
# Make these effects invisible for non-text clips.


static var instance: EffectsPanel

@export_group("Main nodes")
@export var button_video_effects: Button
@export var button_audio_effects: Button
@export var tab_container: TabContainer

@export_group("Video effects")
@export var position_x_spinbox: SpinBox
@export var position_y_spinbox: SpinBox
@export var size_x_spinbox: SpinBox
@export var size_y_spinbox: SpinBox
@export var scale_spinbox: SpinBox
@export var rotation_spinbox: SpinBox
@export var pivot_x_spinbox: SpinBox
@export var pivot_y_spinbox: SpinBox

@export var alpha_spinbox: SpinBox

@export var brightness_spinbox: SpinBox
@export var contrast_spinbox: SpinBox
@export var saturation_spinbox: SpinBox

@export var red_value_spinbox: SpinBox
@export var green_value_spinbox: SpinBox
@export var blue_value_spinbox: SpinBox

@export var tint_color: ColorPickerButton
@export var tint_effect_factor: SpinBox

@export var chroma_effects_grid: GridContainer
@export var enable_chroma_key: CheckButton
@export var chroma_key_color: ColorPickerButton
@export var chroma_key_tolerance: SpinBox
@export var chroma_key_softness: SpinBox

@export_group("Audio effects")
@export var gain_spinbox: SpinBox
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

			button_video_effects.visible = showing
			button_audio_effects.visible = showing
			_set_video_effect_values()

			if button_audio_effects.visible or tab_container.current_tab == 2:
				button_video_effects.button_pressed = true
				button_video_effects.pressed.emit()
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

	position_x_spinbox.value = video_effects_data.position.x
	position_y_spinbox.value = video_effects_data.position.y
	size_x_spinbox.value = video_effects_data.size.x
	size_y_spinbox.value = video_effects_data.size.y
	scale_spinbox.value = video_effects_data.scale
	rotation_spinbox.value = video_effects_data.rotation
	alpha_spinbox.value = video_effects_data.alpha
	pivot_x_spinbox.value = video_effects_data.pivot.x
	pivot_y_spinbox.value = video_effects_data.pivot.y

	brightness_spinbox.value = video_effects_data.brightness
	contrast_spinbox.value = video_effects_data.contrast
	saturation_spinbox.value = video_effects_data.saturation
	
	red_value_spinbox.value = video_effects_data.red_value
	green_value_spinbox.value = video_effects_data.green_value
	blue_value_spinbox.value = video_effects_data.blue_value
	
	tint_color.color = video_effects_data.tint_color
	tint_effect_factor.value = video_effects_data.tint_effect_factor
	
	enable_chroma_key.button_pressed = video_effects_data.enable_chroma_key
	if video_effects_data.enable_chroma_key:
		chroma_key_color.color = video_effects_data.chroma_key_color
		chroma_key_tolerance.value = video_effects_data.chroma_key_tolerance
		chroma_key_softness.value = video_effects_data.chroma_key_softness
		chroma_effects_grid.visible = true
	else:
		chroma_effects_grid.visible = false


func _set_audio_effect_values() -> void:
	var audio_effects_data: EffectsAudio = Project.get_clip(current_clip_id).effects_audio

	gain_spinbox.value = audio_effects_data.gain
	mono_option_button.selected = audio_effects_data.mono


# Audio effects

func _on_gain_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_audio.gain = value


func _on_mono_option_button_item_selected(value: int) -> void:
	match value:
		0: Project.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.DISABLE
		1: Project.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.LEFT_CHANNEL
		2: Project.get_clip(current_clip_id).effects_audio.mono = EffectsAudio.MONO.RIGHT_CHANNEL


# Video effects

func _on_position_x_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.position.x = floor(value)
	Editor.set_frame(Editor.frame_nr)


func _on_position_y_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.position.y = floor(value)
	Editor.set_frame(Editor.frame_nr)


func _on_size_x_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.size.x = floor(value)
	Editor.set_frame(Editor.frame_nr)


func _on_size_y_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.size.y = floor(value)
	Editor.set_frame(Editor.frame_nr)


func _on_scale_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.scale = value
	Editor.set_frame(Editor.frame_nr)


func _on_rotation_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.rotation = value
	Editor.set_frame(Editor.frame_nr)


func _on_alpha_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.alpha = value
	Editor.set_frame(Editor.frame_nr)


func _on_pivot_x_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.pivot.x = floor(value)
	Editor.set_frame(Editor.frame_nr)


func _on_pivot_y_spin_box_value_changed(value:float) -> void:
	Project.get_clip(current_clip_id).effects_video.pivot.y = floor(value)
	Editor.set_frame(Editor.frame_nr)


func _on_brightness_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.brightness = value
	Editor.set_frame(Editor.frame_nr)


func _on_contrast_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.contrast = value
	Editor.set_frame(Editor.frame_nr)


func _on_saturation_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.saturation = value
	Editor.set_frame(Editor.frame_nr)


func _on_red_value_spin_box_value_changed(value: float) -> void: 
	Project.get_clip(current_clip_id).effects_video.red_value = value
	Editor.set_frame(Editor.frame_nr)


func _on_green_value_spin_box_value_changed(value: float) -> void: 
	Project.get_clip(current_clip_id).effects_video.green_value = value
	Editor.set_frame(Editor.frame_nr)


func _on_blue_value_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.blue_value = value
	Editor.set_frame(Editor.frame_nr)


func _on_tint_color_picker_button_color_changed(color: Color) -> void:
	Project.get_clip(current_clip_id).effects_video.tint_color = color
	Editor.set_frame(Editor.frame_nr)


func _on_tint_color_effect_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.tint_effect_factor = value
	Editor.set_frame(Editor.frame_nr)


func _on_enable_chroma_key_button_toggled(toggled_on: bool) -> void:
	Project.get_clip(current_clip_id).effects_video.enable_chroma_key = toggled_on
	chroma_effects_grid.visible = toggled_on
	Editor.set_frame(Editor.frame_nr)


func _on_chroma_key_color_picker_button_color_changed(color: Color) -> void:
	Project.get_clip(current_clip_id).effects_video.chroma_key_color = color
	Editor.set_frame(Editor.frame_nr)


func _on_chroma_key_tolerance_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.chroma_key_tolerance = value
	Editor.set_frame(Editor.frame_nr)


func _on_chroma_key_softness_spin_box_value_changed(value: float) -> void:
	Project.get_clip(current_clip_id).effects_video.chroma_key_softness = value
	Editor.set_frame(Editor.frame_nr)

