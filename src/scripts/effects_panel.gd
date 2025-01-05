class_name EffectsPanel extends ScrollContainer
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
 

static var instance: EffectsPanel = self


@onready var audio_effects: VBoxContainer = get_child(0).get_child(0)
@onready var visual_effects: VBoxContainer = get_child(0).get_child(1)


@export_group("Audio")
@export var volume_slider: HSlider
@export var mono_option_button: OptionButton

@export_group("Visuals transforms")
@export var size_x: SpinBox
@export var size_y: SpinBox
@export var position_x: SpinBox
@export var position_y: SpinBox
@export var rotation_slider: HSlider
@export var scale_x: SpinBox
@export var scale_y: SpinBox
@export var pivot_x: SpinBox
@export var pivot_y: SpinBox

@export_group("Visuals effects")
@export var brightness_slider: HSlider
@export var contrast_slider: HSlider
@export var saturation_slider: HSlider
@export var alpha_slider: HSlider

@export_group("Visuals extras")
@export var red_value_slider: HSlider
@export var green_value_slider: HSlider
@export var blue_value_slider: HSlider

@export var tint_color_picker_button: ColorPickerButton
@export var tint_value_slider: HSlider


var current_clip: ClipData



func _ready() -> void:
	instance = self


func open_file_effects(a_id: int) -> void:
	print("File effects not implemented yet! file_id: ", a_id)


func open_clip_effects(a_id: int) -> void:
	current_clip = Project.clips[a_id]

	var l_type: File.TYPE = Project.files[current_clip.file_id].type

	visual_effects.visible = l_type in View.VISUAL_TYPES
	audio_effects.visible = l_type in View.AUDIO_TYPES

