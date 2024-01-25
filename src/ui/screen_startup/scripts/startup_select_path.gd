extends Button

# IF path is selected but name is not entered, CamelCase the name of the file
# and put as title


func pressed() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.gozen", "GoZen project file")
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	
	file_dialog.use_native_dialog = true
	file_dialog.always_on_top = true
	
	file_dialog.title = tr("DIALOG_TITLE_SELECT_PROJECT_PATH")
	file_dialog.ok_button_text = tr("DIALOG_BUTTON_SELECT_PATH")
	file_dialog.cancel_button_text = tr("DIALOG_BUTTON_CANCEL")
	
	file_dialog.file_selected.connect(func(path: String):
		if %TitleLineEdit.text == "":
			%TitleLineEdit.text = path.split('/')[-1].to_pascal_case()
		if !path.contains(".gozen"):
			%PathLineEdit.text = path + ".gozen"
		else:
			%PathLineEdit.text = path)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(500,600))
