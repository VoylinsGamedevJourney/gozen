extends Control


var callback: Callable



func set_data(function: Callable) -> void:
	callback = function


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_cancel_button_pressed()


func _on_save_project_button_pressed() -> void:
	Project.save()
	callback.call()
	_on_dont_save_button_pressed()


func _on_dont_save_button_pressed() -> void:
	callback.call()
	get_tree().quit()


func _on_cancel_button_pressed() -> void:
	if Settings.get_auto_save() and Project.auto_save_timer != null:
		Project.auto_save_timer.paused = false
	PopupManager.close(PopupManager.SAVE_ON_EXIT)
