extends ItemList


var not_ready: Dictionary[int, int] = {} # { file_id: item_id}



func _ready() -> void:
	@warning_ignore_start("return_value_discarded")
	get_window().files_dropped.connect(_on_files_dropped)
	Project._on_project_loaded.connect(_on_project_loaded)


func _process(_delta: float) -> void:
	for l_file_id: int in not_ready.keys():
		if Project.files[l_file_id].type in View.AUDIO_TYPES:
			if Project._files_data[l_file_id].audio == null:
				print(Project._files_data[l_file_id].audio)
				continue
		if Project.files[l_file_id].type == File.TYPE.VIDEO:
			if Project._files_data[l_file_id].video.size() == 0:
				continue

		set_item_disabled(not_ready[l_file_id], false)
		not_ready.erase(l_file_id)


func _on_project_loaded() -> void:
	clear()

	for l_id: int in Project.files.keys():
		_add_file_to_list(l_id)
	
	
func _on_files_dropped(a_files: PackedStringArray) -> void:
	for l_file_path: String in a_files:
		var l_id: int = Project.add_file(l_file_path)

		if l_id != -1: # Check for invalid file
			_add_file_to_list(l_id)

	sort_items_by_text()


func _add_file_to_list(a_id: int) -> void:
	# Create tree item for the file panel tree
	var l_file: File = Project.files[a_id]
	var l_item: int = add_item(l_file.nickname)

	set_item_metadata(l_item, a_id)
	set_item_tooltip(l_item, l_file.path)
	set_item_disabled(l_item, true)
	# TODO: Add thumbnail

	not_ready[a_id] = l_item
	

func _get_drag_data(_pos: Vector2) -> Draggable:
	var l_draggable: Draggable = Draggable.new()

	l_draggable.files = true
	for l_item: int in get_selected_items():
		var l_file_data: FileData = Project._files_data[get_file_id(l_item)]

		if l_draggable.ids.append(get_file_id(l_item)):
			printerr("Something went wrong appending to draggable ids!")

		l_draggable.duration += l_file_data.get_duration()

	return l_draggable


func get_file_id(a_index: int) -> int:
	return get_item_metadata(a_index)
	

func _on_item_clicked(a_index: int, _pos: Vector2, a_mouse_index: int) -> void:
	if a_mouse_index == MOUSE_BUTTON_LEFT:
		EffectsPanel.instance.open_file_effects(get_file_id(a_index))

