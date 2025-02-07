class_name EffectAudioDefault extends EffectAudio

const MIN_VALUE: int = 45
const MAX_VALUE: int = -45


var gain: int = 0


func get_effect_name() -> String:
	return "Audio defaults"


func get_ui(a_update_callable: Callable) -> Control:
	var l_hbox: HBoxContainer = HBoxContainer.new()
	var l_label: Label = Label.new()
	var l_spinbox: SpinBox = SpinBox.new()
	
	l_label.text = tr("Gain:")
	l_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	l_spinbox.min_value = -45
	l_spinbox.max_value = 45
	l_spinbox.value = gain

	@warning_ignore("return_value_discarded")
	l_spinbox.value_changed.connect(
			_on_spinbox_value_changed.bind(a_update_callable))

	l_hbox.add_child(l_label)
	l_hbox.add_child(l_spinbox)

	return l_hbox


func get_one_shot() -> bool:
	return true


func apply_effect(a_data: PackedByteArray) -> void:
	if gain != 0:
		a_data = Audio.change_db(a_data, gain)


func _on_spinbox_value_changed(a_value: float, a_callable: Callable) -> void:
	gain = int(a_value)
	a_callable.call()

