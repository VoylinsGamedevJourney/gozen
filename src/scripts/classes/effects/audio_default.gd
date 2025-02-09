class_name EffectAudioDefault extends EffectAudio

static var db_cache: Dictionary[int, float] = {} # { gain, value }


const MIN_VALUE: int = 45
const MAX_VALUE: int = -45


var mute: bool = false
var gain: int = 0



func get_effect_name() -> String:
	return "Audio defaults"


func get_ui() -> Control:
	# Mute effect
	var l_vbox_mute: VBoxContainer = VBoxContainer.new()
	var l_label_mute: Label = Label.new()
	var l_checkbox_mute: CheckBox = CheckBox.new()

	l_label_mute.text = tr("Mute:")
	l_checkbox_mute.set_pressed(mute)
	l_vbox_mute.add_child(l_label_mute)
	l_vbox_mute.add_child(l_checkbox_mute)

	@warning_ignore("return_value_discarded")
	l_checkbox_mute.pressed.connect(_on_mute_pressed)

	# Gain effect
	var l_label_gain: Label = Label.new()
	var l_spinbox_gain: SpinBox = SpinBox.new()
	
	l_label_gain.text = tr("Gain:")
	l_label_gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	l_spinbox_gain.min_value = -45
	l_spinbox_gain.max_value = 45
	l_spinbox_gain.value = gain

	@warning_ignore("return_value_discarded")
	l_spinbox_gain.value_changed.connect(_on_spinbox_value_changed)

	# Finishing the node
	var l_hbox: HBoxContainer = HBoxContainer.new()

	l_hbox.add_child(l_vbox_mute)
	l_hbox.add_child(l_label_gain)
	l_hbox.add_child(l_spinbox_gain)

	return l_hbox


func _on_mute_pressed() -> void:
	mute = !mute
	update_audio_effect()


func _on_spinbox_value_changed(a_value: float) -> void:
	gain = int(a_value)
	update_audio_effect()


func apply_effect(a_data: PackedByteArray) -> PackedByteArray:
	## This will be called in a thread to update the data
	if mute:
		a_data.fill(0)

	return Audio.change_db(a_data, gain)

