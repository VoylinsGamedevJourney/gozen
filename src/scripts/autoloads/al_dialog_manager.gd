extends Node
## Dialog Manager
##
## All file dialog's which need opening will be opened from here. This is
## to keep things simple and have a cleaner way of creating dialog's as
## setting all the properties of a dialog can be a lot of code.

# TODO: Use GDExtension to load up all supported extensions
const SUPPORTED_FORMATS := {
	"Videos": "*.mp4, *.mov, *.avi, *.mkv, *.webm, *.flv, *.mpeg, *.mpg, *.wmv, *.asf, *.vob, *.ts, *.m2ts, *.mts, *.3gp, *.3g2",
	"Images": "*.png, *.jpg, *.svg, *.webp, *.bmp, *.tga, *.dds, *.hdr, *.exr",
	"Audio": "*.ogg, *.wav, *.mp3" }


func _default_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.use_native_dialog = true
	dialog.always_on_top = true
	return dialog


func get_open_project_dialog() -> FileDialog:
	var dialog := _default_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dialog.add_filter("*.gozen", "GoZen project file")
	
	dialog.title = "DIALOG_TITLE_OPEN_PROJECT"
	dialog.ok_button_text = "DIALOG_BUTTON_OPEN_PROJECT"
	dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	return dialog


func get_select_path_dialog() -> FileDialog:
	var dialog := _default_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	dialog.add_filter("*.gozen", "GoZen project file")
	dialog.title = "DIALOG_TITLE_SELECT_PROJECT_PATH"
	dialog.ok_button_text = "DIALOG_BUTTON_SELECT_PATH"
	dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	return dialog


func get_file_import_dialog() -> FileDialog:
	var dialog := _default_dialog(FileDialog.FILE_MODE_OPEN_FILES)
	for key: String in SUPPORTED_FORMATS:
		dialog.add_filter(SUPPORTED_FORMATS[key], key)
	dialog.title = "DIALOG_TITLE_SELECT_FILES"
	dialog.ok_button_text = "DIALOG_BUTTON_SELECT_FILES"
	dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	return dialog


func get_layout_icon_dialog() -> FileDialog:
	var dialog := _default_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dialog.add_filter(SUPPORTED_FORMATS.Images, "Images")
	dialog.title = "DIALOG_TITLE_SELECT_LAYOUT_ICON"
	dialog.ok_button_text = "DIALOG_BUTTON_SELECT_FILE"
	dialog.cancel_button_text = "DIALOG_BUTTON_CANCEL"
	return dialog
