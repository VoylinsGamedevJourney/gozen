extends Control

var mode: ModuleManager.FE_MODES
var filters : Array # extensions


func open(_mode: ModuleManager.FE_MODES, title: String, extensions: Array) -> void:
	mode = _mode
	filters = extensions
	find_child("TitleLabel").text = title
	
	
	
#	$FileDialog.filters = extensions
#	$FileDialog.popup_centered(Vector2i(500,500))
#
#	$FileDialog.file_selected.connect(send_data)
#	$FileDialog.files_selected.connect(send_data)
#	$FileDialog.dir_selected.connect(send_data)


func _on_cancel_pressed() -> void:
	ModuleManager._on_file_explorer_cancel
	queue_free()


func _on_entry_pressed(folder: bool) -> void:
	# if folder and double pressed, open folder
	pass


func _on_ok_pressed() -> void:
	# TODO: Send data as array, even when file
	pass
