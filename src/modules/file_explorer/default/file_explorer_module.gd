extends FileExplorerInterface

@onready var file_dialog := $FileDialog


func _ready() -> void:
	super._ready()
	file_dialog.visible = false
	file_dialog.exclusive = false


func open_file_explorer() -> void:
	file_dialog.title = file_explorer_title
	file_dialog.file_mode = file_mode
	file_dialog.filters = file_filters
	file_dialog.popup_centered()
	super.open_file_explorer()


func _on_cancel_button_pressed() -> void:
	close_file_explorer()


func _on_file_dialog_dir_selected(dir: String) -> void:
	close_file_explorer()
	emit_signal("on_dir_selected", dir)


func _on_file_dialog_file_selected(path: String) -> void:
	close_file_explorer()
	emit_signal("on_file_selected", path)
 

func _on_file_dialog_files_selected(paths: PackedStringArray) -> void:
	close_file_explorer()
	emit_signal("on_files_selected", paths)
