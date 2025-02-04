class_name EffectsPanel extends TabContainer
# We should use the view textures themself for transform effects.
# We can resize the placeholder for sizing. For rotation we need to set the
# pivot as well
#
# Size = Placeholder texture size
# Scaling = Scale property
# Rotation = Rotation (Pivot needs to be set)
# Pivot = Used for size + scaling + rotation (Should be center by default)
#
# WARNING: Set the PIVOT by default in the center!! Maybe have pivot being a %
# instead of the pixel position
#
# Extra want to have effects:
# Trimming edges
# Rounding corners
#
# These effects will need to be implemented on a shader level
 
# TODO: Resize the tabs to take the entire space
# TODO: Hide scrollbar? or add extra spacing


static var instance: EffectsPanel


@onready var audio_effects: ScrollContainer = %AudioEffectsTab
@onready var visual_effects: ScrollContainer = %VisualEffectsTab


# Audio effects
@onready var volume_slider: HSlider = %EffectVolumeHSlider
@onready var volume_spinbox: SpinBox = %EffectVolumeSpinBox
@onready var mono_option_button: OptionButton = %EffectMonoOptionButton

# Visual effects
@onready var size_x: SpinBox = %EffectSizeXSpinBox
@onready var size_y: SpinBox = %EffectSizeYSpinBox
@onready var position_x: SpinBox = %EffectPositionXSpinBox
@onready var position_y: SpinBox = %EffectPositionYSpinBox
@onready var rotation_slider: HSlider = %EffectRotationHSlider
@onready var scale_x: SpinBox = %EffectScaleXSpinBox
@onready var scale_y: SpinBox = %EffectScaleYSpinBox
@onready var pivot_x: SpinBox = %EffectPivotXSpinBox
@onready var pivot_y: SpinBox = %EffectPivotYSpinBox

# Visual effects
@onready var brightness_slider: HSlider = %EffectBrightnessHSlider
@onready var contrast_slider: HSlider = %EffectContrastHSlider
@onready var saturation_slider: HSlider = %EffectSaturationHSlider
@onready var alpha_slider: HSlider = %EffectAlphaHSlider

# Visual effects extra's
@onready var red_value_slider: HSlider = %EffectRedValueHSlider
@onready var green_value_slider: HSlider = %EffectGreenValueHSlider
@onready var blue_value_slider: HSlider = %EffectBlueValueHSlider

@onready var tint_color_button: ColorPickerButton = %EffectTintColorPickerButton
@onready var tint_value_slider: HSlider = %EffectTintEffectFactorHSlider


var current_file: File
var current_clip: ClipData



func _ready() -> void:
	instance = self

	@warning_ignore("return_value_discarded")
	Project._on_project_loaded.connect(_reset)
	_reset()


func _reset() -> void:
	set_tab_hidden(0, true) # Audio
	set_tab_hidden(1, true) # Visuals
	set_tab_hidden(2, false) # Nothing selected

	set_tab_title(0, "Audio")
	set_tab_title(1, "Visuals")
	set_tab_title(2, "No clip/file")
	set_tab_tooltip(0, "Audio effects panel")
	set_tab_tooltip(1, "Visual effects panel")
	set_tab_tooltip(2, "Nothing is selected, select a clip or file.")

	current_tab = 2


func check_clip() -> void:
	if current_clip == null:
		_reset()


func open_file_effects(a_id: int) -> void:
	print("File effects not implemented yet! file_id: ", a_id)
	current_file = Project.files[a_id]
	current_clip = null


func open_clip_effects(a_id: int) -> void:
	current_clip = Project.clips[a_id]
	current_file = null

	var l_type: File.TYPE = Project.files[current_clip.file_id].type

	set_tab_hidden(0, l_type not in View.AUDIO_TYPES)
	set_tab_hidden(1, l_type not in View.VISUAL_TYPES)
	set_tab_hidden(2, true) # Nothing selected

	# Set audio effect values
	volume_slider.value = current_clip.effects_audio.db
	mono_option_button.selected = current_clip.effects_audio.mono as int


func _on_effect_volume_spin_box_value_changed(a_value: float) -> void:
	volume_slider.value = a_value

	if a_value < 0:
		volume_spinbox.prefix = ''
	else:
		volume_spinbox.prefix = '+'


func _on_effect_volume_h_slider_value_changed(a_value:float) -> void:
	volume_spinbox.value = a_value
	current_clip.effects_audio.db = a_value as int
	current_clip.update_audio_data()


func _on_effect_mono_option_button_item_selected(a_index: int) -> void:
	match a_index:
		0: current_clip.effects_audio.mono = EffectsAudio.MONO.OFF
		1: current_clip.effects_audio.mono = EffectsAudio.MONO.LEFT_CHANNEL
		2: current_clip.effects_audio.mono = EffectsAudio.MONO.RIGHT_CHANNEL
	current_clip.update_audio_data()

