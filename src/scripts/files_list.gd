extends ItemList



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
		var l_item: int = add_item(l_file.nickname)

		set_item_metadata(l_item, l_id)
		set_item_tooltip(l_item, l_file.path)
		# TODO: Add thumbnail

	sort_items_by_text()


func _get_drag_data(_pos: Vector2) -> Draggable:
	var l_draggable: Draggable = Draggable.new()

	l_draggable.files = true
	for l_item: int in get_selected_items():
		var l_file_id: int = get_item_metadata(l_item)
		var l_file_data: FileData = Project._files_data[l_file_id]

		if l_draggable.ids.append(l_file_id):
			printerr("Something went wrong appending to draggable ids!")

		l_draggable.duration += l_file_data.get_duration()

	return l_draggable

