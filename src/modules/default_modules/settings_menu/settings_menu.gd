extends ModuleSettingsMenu

# TODO: Add search
# TODO: Display all module settings in their own category
# TODO: Make language setting into an option button


var startup := true


func _ready() -> void:
	%LanguageLineEdit.text = TranslationServer.get_locale()
	%ZenModeCheckBox.button_pressed = SettingsManager.get_zen_mode()
	%UpdateNotificationCheckBox.button_pressed = SettingsManager.get_update_notification()
	%TimelineMaxSizeSpinBox.value = SettingsManager.get_timeline_max_size()
	startup = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()


func _on_language_line_edit_text_submitted(new_language: String) -> void:
	if startup:
		return
	SettingsManager.set_language(new_language)


func _on_zen_mode_check_box_toggled(toggle: bool) -> void:
	if startup:
		return
	SettingsManager.set_zen_mode(toggle)


func _on_update_notification_check_box_toggled(toggle: bool) -> void:
	if startup:
		return
	SettingsManager.set_update_notification(toggle)


func _on_timeline_max_size_spin_box_value_changed(value: float) -> void:
	if startup:
		return
	SettingsManager.set_timeline_max_size(value)
