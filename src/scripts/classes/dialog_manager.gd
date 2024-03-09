class_name DialogManager extends Node
## Dialog Manager
##
## All file dialog's which need opening will be opened from here. This is
## to keep things simple and have a cleaner way of creating dialog's as
## setting all the properties of a dialog can be a lot of code.

static func _default_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.use_native_dialog = true
	dialog.always_on_top = true
	return dialog


static func get_open_project_dialog() -> FileDialog:
	var dialog := _default_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dialog.add_filter("*.gozen", "GoZen project file")
	
	dialog.title = "DIALOG_TITLE_OPEN_PROJECT"
	dialog.ok_button_text = "DIALOG_BUTTON_OPEN_PROJECT"
	dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	return dialog


static func get_select_path_dialog() -> FileDialog:
	var dialog := _default_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	dialog.add_filter("*.gozen", "GoZen project file")
	dialog.title = "DIALOG_TITLE_SELECT_PROJECT_PATH"
	dialog.ok_button_text = "DIALOG_BUTTON_SELECT_PATH"
	dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	return dialog
