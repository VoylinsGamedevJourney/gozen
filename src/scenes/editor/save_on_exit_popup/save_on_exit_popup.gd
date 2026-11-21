extends Control


var callback: Callable



func set_data(function: Callable) -> void:
	callback = function


#--- Input handling ---

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_cancel_button_pressed()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_cancel_button_pressed()


#--- Button handling ---

func _on_save_project_button_pressed() -> void:
	if Project.get_project_path().is_empty():
		var dialog: FileDialog = PopupManager.create_file_dialog(
				tr("Save project as ..."),
				FileDialog.FILE_MODE_SAVE_FILE,
				["*%s;%s" % [Project.EXTENSION, tr("GoZen project file")]])
		dialog.current_dir = Project.get_picker_path(OS.SYSTEM_DIR_MOVIES)
		dialog.file_selected.connect(func(_selected_path: String) -> void:
				_execute_callback_and_close.call_deferred(), CONNECT_ONE_SHOT)
		dialog.canceled.connect(func() -> void:
				visible = true, CONNECT_ONE_SHOT)
		add_child(dialog)
		dialog.popup_centered()
		return
	Project.save()
	_execute_callback_and_close()


func _on_dont_save_button_pressed() -> void:
	_execute_callback_and_close()


func _on_cancel_button_pressed() -> void:
	if Settings.get_auto_save() and Project.auto_save_timer != null:
		Project.auto_save_timer.paused = false
	PopupManager.close(PopupManager.SAVE_ON_EXIT)


func _execute_callback_and_close() -> void:
	if Settings.get_auto_save() and Project.auto_save_timer != null:
		Project.auto_save_timer.paused = false
	var pending_callback: Callable = callback
	PopupManager.close(PopupManager.SAVE_ON_EXIT)
	if pending_callback.is_valid():
		pending_callback.call()
