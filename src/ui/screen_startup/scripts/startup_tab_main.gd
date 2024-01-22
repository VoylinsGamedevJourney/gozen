extends MarginContainer


func _on_show_all_projects_button_pressed():
	get_parent().current_tab = 1


func _on_open_project_button_pressed():
	var file_dialog := FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.gozen", "GoZen project file")
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	
	file_dialog.use_native_dialog = true
	file_dialog.always_on_top = true
	
	file_dialog.title = tr("DIALOG_TITLE_OPEN_PROJECT")
	file_dialog.ok_button_text = tr("DIALOG_BUTTON_OPEN_PROJECT")
	file_dialog.cancel_button_text = tr("DIALOG_BUTTON_CANCEL")
	
	file_dialog.file_selected.connect(func(path: String):
		if path.contains(".gozen"):
			ProjectManager.load_project(path)
			ScreenMain.instance.close_screen()
		else:
			Printer.error("Can't open project as path does not have '*.gozen' extension!")
		)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(500,600))


func _on_create_project_button_pressed():
	get_parent().current_tab = 2
