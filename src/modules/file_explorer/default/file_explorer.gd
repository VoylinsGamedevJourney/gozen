extends FileExplorerModule
## The Default Files Explorer Module
##
## Every file explorer should have an open function, see Module Manager.
## Still WIP


func _ready() -> void:
	_on_open.connect(open)


func open(mode: ModuleManager.FE_MODES, title: String, extensions: Array) -> void:
	
	
	# Setting the window title
	$FileDialog.title = title
	$FileDialog.filters = extensions
	$FileDialog.popup_centered(Vector2i(500,500))
	
	$FileDialog.file_selected.connect(send_data)
	$FileDialog.files_selected.connect(send_data)
	$FileDialog.dir_selected.connect(send_data)


func _on_cancel_pressed() -> void:
	ModuleManager._on_file_explorer_cancel
	queue_free()
