extends PanelContainer


@export var save_info_label: Label

@export_group("Appearance")
@export var theme_option_button: OptionButton
@export var show_menu_bar_button: CheckButton
@export var audio_waveform_style: OptionButton

@export_group("Defaults")
@export var image_duration_spinbox: SpinBox
@export var default_resolution_x_spinbox: SpinBox
@export var default_resolution_y_spinbox: SpinBox
@export var default_framerate_spinbox: SpinBox

@export_group("Timeline")
@export var track_amount_spinbox: SpinBox
@export var pause_after_drag: CheckButton
@export var delete_empty_modifier_button: OptionButton


var changes: Dictionary[String, Callable] = {}



func _ready() -> void:
	set_values()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_button_pressed()


func set_values() -> void:
	# Appearance values
	theme_option_button.selected = Settings.get_theme()
	show_menu_bar_button.button_pressed = Settings.get_show_menu_bar()
	audio_waveform_style.selected = Settings.get_audio_waveform_style()

	# Defaults values
	image_duration_spinbox.value = Settings.get_image_duration()
	default_resolution_x_spinbox.value = Settings.get_default_resolution().x
	default_resolution_y_spinbox.value = Settings.get_default_resolution().y
	default_framerate_spinbox.value = Settings.get_default_framerate()

	# Timeline values
	track_amount_spinbox.value = Settings.get_tracks_amount()
	pause_after_drag.button_pressed = Settings.get_pause_after_drag()
	match Settings.get_delete_empty_modifier():
		KEY_NONE: delete_empty_modifier_button.selected = 0
		KEY_CTRL: delete_empty_modifier_button.selected = 1
		KEY_SHIFT: delete_empty_modifier_button.selected = 2

	save_info_label.visible = false


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


func _on_show_menu_bar_check_button_toggled(value: bool) -> void:
	changes["show_menu_bar"] = Settings.set_show_menu_bar.bind(value)
	save_info_label.visible = true


func _on_audio_waveform_style_option_button_item_selected(index: int) -> void:
	changes["audio_waveform_style"] = Settings.set_audio_waveform_style.bind(index)
	save_info_label.visible = true


func _on_image_duration_spin_box_value_changed(value: float) -> void:
	changes["image_duration"] = Settings.set_image_duration.bind(value)
	save_info_label.visible = true


func _on_default_resolution_x_spin_box_value_changed(value: float) -> void:
	changes["set_res_x"] = Settings.set_default_resolution_x.bind(value)
	save_info_label.visible = true


func _on_default_resolution_y_spin_box_value_changed(value: float) -> void:
	changes["set_res_y"] = Settings.set_default_resolution_y.bind(value)
	save_info_label.visible = true


func _on_default_framerate_spin_box_value_changed(value:float) -> void:
	changes["default_framerate"] = Settings.set_default_framerate.bind(value)
	save_info_label.visible = true


func _on_track_amount_spin_box_value_changed(value: float) -> void:
	changes["track_amount"] = Settings.set_tracks_amount.bind(value)
	save_info_label.visible = true


func _on_pause_after_drag_check_button_toggled(value: bool) -> void:
	changes["pause_after_drag"] = Settings.set_pause_after_drag.bind(value)
	save_info_label.visible = true


func _on_delete_empty_modifier_option_button_item_selected(index: int) -> void:
	match index:
		0: changes["delete_empty_modifier"] = Settings.set_delete_empty_modifier.bind(KEY_NONE)
		1: changes["delete_empty_modifier"] = Settings.set_delete_empty_modifier.bind(KEY_CTRL)
		2: changes["delete_empty_modifier"] = Settings.set_delete_empty_modifier.bind(KEY_SHIFT)

	save_info_label.visible = true

