class_name EffectsPanel extends PanelContainer
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
# TODO: Save UI nodes from effects (with a limit) for faster loading


static var instance: EffectsPanel


@export var button_audio_effects: Button 
@export var button_visual_effects: Button
@export var effects_vbox: VBoxContainer


var clip: ClipData = null
var file: File = null
var type: File.TYPE = File.TYPE.EMPTY



func _ready() -> void:
	instance = self

	@warning_ignore("return_value_discarded")
	Project._on_project_loaded.connect(_reset)
	_reset()


func _reset() -> void:
	_clean_effects()

	button_audio_effects.disabled = true
	button_visual_effects.disabled = true

	clip = null
	file = null
	type = File.TYPE.EMPTY


func _clean_effects() -> void:
	for l_child: Control in effects_vbox.get_children():
		l_child.queue_free()


func check_type() -> void:
	button_audio_effects.disabled = type in View.AUDIO_TYPES
	button_visual_effects.disabled = type in View.VISUAL_TYPES

	if button_audio_effects.pressed and button_audio_effects.disabled:
		show_audio_effects()
	elif button_visual_effects.pressed and button_visual_effects.disabled:
		show_visual_effects()
	elif button_audio_effects.disabled:
		button_audio_effects.set_pressed(true)
		show_audio_effects()
	else:
		button_visual_effects.set_pressed(true)
		show_visual_effects()


func check_clip() -> void:
	if clip == null:
		_reset()


func check_file() -> void:
	if file == null:
		_reset()


func open_clip_effects(a_id: int) -> void:
	file = null
	clip = Project.clips[a_id]
	type = Project.files[clip.file_id].type

	check_type()


func open_file_effects(a_id: int) -> void:
	clip = null
	file = Project.files[a_id]
	type = file.type

	check_type()


func show_visual_effects() -> void:
	_clean_effects()

	# Set the clip/file effect defaults

	# Load in extra visual effects and set their values
	pass # Replace with function body.


func show_audio_effects() -> void:
	var l_separator: HSeparator = HSeparator.new()
	_clean_effects()

	# Set the clip effect defaults + load defaults
	if clip != null:
		effects_vbox.add_child(clip.default_audio_effects.get_ui())
		effects_vbox.add_child(l_separator.duplicate())

		for l_effect: EffectAudio in clip.audio_effects:
			effects_vbox.add_child(l_effect.get_ui())
			effects_vbox.add_child(l_separator.duplicate())
	else:
		# Set the file effect defaults + load defaults
		effects_vbox.add_child(file.default_audio_effects.get_ui())
		effects_vbox.add_child(l_separator.duplicate())

		# Adding all other effects
		for l_effect: EffectAudio in file.audio_effects:
			effects_vbox.add_child(l_effect.get_ui())
			effects_vbox.add_child(l_separator.duplicate())

