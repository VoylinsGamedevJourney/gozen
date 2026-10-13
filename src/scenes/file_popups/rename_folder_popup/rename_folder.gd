extends PanelContainer


@export var rename_line_edit: LineEdit


var folder: String
var folder_path: String



func set_data(folder_name: String, path: String) -> void:
	folder = folder_name
	folder_path = path
	rename_line_edit.text = folder
	rename_line_edit.grab_focus()


func _input(event: InputEvent) -> void:
	# Needed as focus could be in line edit.
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_button_pressed()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_cancel_button_pressed()


func _on_save_button_pressed() -> void:
	_on_rename_folder_line_edit_text_submitted(rename_line_edit.text)


func _on_rename_folder_line_edit_text_submitted(new_nickname: String) -> void:
	var new_folder_name: String = new_nickname.strip_edges()
	if new_folder_name not in ["", "/"] and new_folder_name != folder:
		var parent_path: String = folder_path.trim_suffix("/").get_base_dir()
		var new_path: String = ""
		if parent_path == "/":
			new_path = "/" + new_folder_name + "/"
		else:
			new_path = parent_path + "/" + new_folder_name + "/"
		FolderLogic.rename(folder_path, new_path)
	_on_cancel_button_pressed()


func _on_cancel_button_pressed() -> void:
	PopupManager.close(PopupManager.FOLDER_RENAME)
