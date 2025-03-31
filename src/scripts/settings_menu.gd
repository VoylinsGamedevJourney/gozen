extends PanelContainer


# Appearance
@export var theme_option_button: OptionButton

# Defaults
@export var image_duration_spinbox: SpinBox
@export var default_resolution_x_spinbox: SpinBox
@export var default_resolution_y_spinbox: SpinBox
@export var default_framerate_spinbox: SpinBox

@export var save_info_label: Label


var changes: Dictionary[String, Callable] = {}


func _ready() -> void:
	set_values()


func set_values() -> void:
	save_info_label.visible = false

	# Appearance values
	theme_option_button.selected = Settings.get_theme()

	# Defaults values
	image_duration_spinbox.value = Settings.get_image_duration()
	default_resolution_x_spinbox.value = Settings.get_default_resolution().x
	default_resolution_y_spinbox.value = Settings.get_default_resolution().y
	default_framerate_spinbox.value = Settings.get_default_framerate()


func _on_reset_button_pressed() -> void:
	if changes.size() != 0:
		changes = {}
	else:
		Settings.reset_settings()

	set_values()


func _on_save_button_pressed() -> void:
	for change: Callable in changes.values():
		change.call()
	
	Settings.save()
	self.queue_free()


func _on_cancel_button_pressed() -> void:
	self.queue_free()


func _on_theme_option_button_item_selected(index: int) -> void:
	changes["theme"] = Settings.set_theme.bind(index)
	save_info_label.visible = true


func _on_image_duration_spin_box_value_changed(value: float) -> void:
	changes["image_duration"] = Settings.set_image_duration.bind(value)

