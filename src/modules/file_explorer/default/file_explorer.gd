extends FileExplorerModule
## The Default Files Explorer Module
##
## Still WIP


func _ready() -> void:
	_on_open.connect(open)


func open(title: String) -> void:
	# Setting the window title
	$FileDialog.title = title
	$FileDialog.filters = extensions
	$FileDialog.popup_centered(Vector2i(500,500))
	
	$FileDialog.file_selected.connect(send_data)
	$FileDialog.files_selected.connect(send_data)
	$FileDialog.dir_selected.connect(send_data)
