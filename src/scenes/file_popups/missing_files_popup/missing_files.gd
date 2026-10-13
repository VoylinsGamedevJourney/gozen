extends Control
# Non re-linked files should be made tagged as "missing" but not deleted just
# in case, people can relink files manually.


@export var vbox: VBoxContainer



## This is basically our _ready() for the popup.
func set_data(missing_files: Array[FileData]) -> void:
	for file: FileData in missing_files:
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var button_relink: Button = Button.new()
		label.text = file.nickname
		label.size_flags_horizontal = Control.SIZE_FILL
		button_relink.text = tr("Re-link file")

		hbox.add_child(label)
		hbox.add_child(button_relink)

		button_relink.pressed.connect(func() -> void:
			var file_dialog: FileDialog = PopupManager.create_file_dialog(
					tr("Relink file ..."), FileDialog.FILE_MODE_OPEN_FILE)
			file_dialog.current_dir = file.path.get_base_dir()
			file_dialog.file_selected.connect(func(path: String) -> void:
					FileLogic.relink_file(file, path)
					hbox.queue_free())
			add_child(file_dialog)
			file_dialog.popup_centered())

		vbox.add_child(hbox)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.MISSING_FILES)
