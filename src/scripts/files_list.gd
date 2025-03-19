extends ItemList


# NOTE: Image, Audio, Video, Text/Title  ( Add "add file(s)" button )
var loading_files: PackedInt64Array = []



func _ready() -> void:
	@warning_ignore_start("return_value_discarded")
	get_window().files_dropped.connect(_on_files_dropped)
	Project.project_ready.connect(_on_project_loaded)
	@warning_ignore_restore("return_value_discarded")


func _process(_delta: float) -> void:
	if loading_files.size() != 0:
		for i: int in loading_files:
			var l_file: File = Project.get_file(i)
			var l_file_data: FileData = Project.get_file_data(i)

			if l_file.type in Editor.AUDIO_TYPES:
				if l_file_data.audio == null:
					continue
				elif l_file_data.audio.data.size() == 0:
					continue

			if l_file.type == File.TYPE.VIDEO:
				if l_file_data.videos.size() == 0:
					continue

			for x: int in item_count:
				if get_item_metadata(x) == i:
					set_item_disabled(x, false)
					loading_files.remove_at(loading_files.find(i))
					break


func _on_project_loaded() -> void:
	clear()

	for l_id: int in Project.get_file_ids():
		_add_file_to_list(l_id)
	
	
func _on_files_dropped(a_files: PackedStringArray) -> void:
	if Project.data == null:
		return

	for l_file_path: String in a_files:
		var l_id: int = add_file(l_file_path)

		if l_id != -1: # Check for invalid file
			_add_file_to_list(l_id)

	sort_items_by_text()


func _add_file_to_list(a_id: int) -> void:
	# Create tree item for the file panel tree
	var l_file: File = Project.get_file(a_id)
	var l_item: int = add_item(l_file.nickname)

	set_item_metadata(l_item, a_id)
	set_item_tooltip(l_item, l_file.path)
	set_item_disabled(l_item, true)
	# TODO: Add thumbnail

	@warning_ignore("return_value_discarded")
	loading_files.append(a_id)
	

func _get_drag_data(_pos: Vector2) -> Draggable:
	var l_draggable: Draggable = Draggable.new()

	l_draggable.files = true
	for l_item: int in get_selected_items():
		var l_file_id: int = get_item_metadata(l_item)
		var l_file: File = Project.get_file(l_file_id)
		var l_file_data: FileData = Project.get_file_data(l_file_id)

		if l_draggable.ids.append(l_file_id):
			printerr("Something went wrong appending to draggable ids!")

		if l_file.duration <= 0:
			l_file_data._update_duration()

		l_draggable.duration += l_file.duration

	return l_draggable


func _on_files_list_item_clicked(_index: int, _pos: Vector2, a_mouse_index: int) -> void:
	if a_mouse_index == MOUSE_BUTTON_LEFT:
		# TODO: Open effects panel
		pass


func add_file(a_file_path: String) -> int:
	var l_file: File = File.create(a_file_path)

	if l_file == null:
		return -1

	# Check if file already exists
	for l_existing: File in Project.get_files().values():
		if l_existing.path == a_file_path:
			print("File already loaded with path '%s'!" % a_file_path)

	Project.get_files()[l_file.id] = l_file
	Project.load_file_data(l_file.id)

	return l_file.id


