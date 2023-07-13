extends FileExplorerInterface

@onready var popup := $ExplorerPopup


func _ready() -> void:
	popup.exclusive = false


func open_file_explorer() -> void:
	popup.title = title
	popup.file_mode = mode
	popup.filters = filters
	popup.popup_centered()
	super.open_file_explorer()


func _on_cancel_button_pressed() -> void:
	self.queue_free()


func _on_file_dialog_dir_selected(dir: String) -> void:
	emit_signal("on_dir_selected", dir)
	self.queue_free()


func _on_file_dialog_file_selected(path: String) -> void:
	emit_signal("on_file_selected", path)
	self.queue_free()
 

func _on_file_dialog_files_selected(paths: PackedStringArray) -> void:
	emit_signal("on_files_selected", paths)
	self.queue_free()
