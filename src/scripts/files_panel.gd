class_name FilesPanel extends PanelContainer

@onready var files_list: ItemList = %FilesList



func _ready() -> void:
	if get_window().files_dropped.connect(_on_files_dropped):
		printerr("Couldn't connect to files dropped!")
	
	
func _on_files_dropped(a_files: PackedStringArray) -> void:
	for l_file_path: String in a_files:
		# Add to project
		var l_id: int = Project.add_file(l_file_path)

		if l_id == -1: # Invalid file
			continue

		# Create tree item for the file panel tree
		var l_file: File = Project.files[l_id]
		var l_item: int = files_list.add_item(l_file.nickname)

		files_list.set_item_metadata(l_item, l_id)
		files_list.set_item_tooltip(l_item, l_file.path)
		# TODO: Add thumbnail

	files_list.sort_items_by_text()

