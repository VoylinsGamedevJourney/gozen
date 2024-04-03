extends Node
## Dialog Manager
##
## All file dialog's which need opening will be opened from here. This is
## to keep things simple and have a cleaner way of creating dialog's as
## setting all the properties of a dialog can be a lot of code.


func _default_dialog(a_mode: FileDialog.FileMode) -> FileDialog:
	var l_dialog: FileDialog = FileDialog.new()
	
	l_dialog.access = FileDialog.ACCESS_FILESYSTEM
	l_dialog.file_mode = a_mode
	#l_dialog.use_native_dialog = true # NOTE: Buggy mess on Linux
	l_dialog.always_on_top = true
	
	return l_dialog


func get_open_project_dialog() -> FileDialog:
	var l_dialog: FileDialog = _default_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	
	l_dialog.add_filter("*.gozen", "GoZen project file")
	l_dialog.title = "DIALOG_TITLE_OPEN_PROJECT"
	l_dialog.ok_button_text = "DIALOG_BUTTON_OPEN_PROJECT"
	l_dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	
	return l_dialog


func get_select_path_dialog() -> FileDialog:
	var l_dialog: FileDialog = _default_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	
	l_dialog.add_filter("*.gozen", "GoZen project file")
	l_dialog.title = "DIALOG_TITLE_SELECT_PROJECT_PATH"
	l_dialog.ok_button_text = "DIALOG_BUTTON_SELECT_PATH"
	l_dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	
	return l_dialog


func get_file_import_dialog() -> FileDialog:
	var l_dialog: FileDialog = _default_dialog(FileDialog.FILE_MODE_OPEN_FILES)
	
	for l_value: String in File.SUPPORTED_FORMATS[File.TYPE.VIDEO]:
		l_dialog.add_filter("*.%s" % l_value, "Videos")
	for l_value: String in File.SUPPORTED_FORMATS[File.TYPE.IMAGE]:
		l_dialog.add_filter("*.%s" % l_value, "Images")
	for l_value: String in File.SUPPORTED_FORMATS[File.TYPE.AUDIO]:
		l_dialog.add_filter("*.%s" % l_value, "Audio")
	
	l_dialog.title = "DIALOG_TITLE_SELECT_FILES"
	l_dialog.ok_button_text = "DIALOG_BUTTON_SELECT_FILES"
	l_dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	
	return l_dialog


func get_layout_icon_dialog() -> FileDialog:
	var l_dialog: FileDialog = _default_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	
	for l_value: String in File.SUPPORTED_FORMATS[File.TYPE.IMAGE]:
		l_dialog.add_filter("*.%s" % l_value, "Images")
	
	l_dialog.title = "DIALOG_TITLE_SELECT_LAYOUT_ICON"
	l_dialog.ok_button_text = "DIALOG_BUTTON_SELECT_FILE"
	l_dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	
	return l_dialog
