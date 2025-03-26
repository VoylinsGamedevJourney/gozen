extends PanelContainer


const THUMB_PATH: String = "user://thumbs/"
const THUMB_INFO_PATH: String = "user://thumbs/info"

const NICKNAME_SIZE: int = 14


# Order is the same as the ENUM of File.TYPE: Image, Audio, Video, Text/Title
@export var tab_container: TabContainer
@export var tabs: Array[ItemList] = []
@export var buttons: Array[Button] = []

var loading_files: PackedInt64Array = []



func _ready() -> void:
	Toolbox.connect_func(get_window().files_dropped, _on_files_dropped)
	Toolbox.connect_func(Project.project_ready, _on_project_loaded)

	for l_list_id: int in tabs.size():
		tabs[l_list_id].set_drag_forwarding(_get_list_drag_data, Callable(), Callable())
		Toolbox.connect_func(tabs[l_list_id].item_clicked, _file_item_clicked.bind(l_list_id))


func _process(_delta: float) -> void:
	if loading_files.size() != 0:
		for i: int in loading_files:
			_process_file(Project.get_file(i), Project.get_file_data(i))


func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("ui_paste"):
		_on_image_pasted()

	
func get_thumb(a_file_id: int) -> Texture:
	# This function also creates the thumb if not existing yet.
	if !DirAccess.dir_exists_absolute(THUMB_PATH):
		if DirAccess.make_dir_absolute(THUMB_PATH):
			printerr("Couldn't create folder at %s!" % THUMB_PATH)

	var l_file: FileAccess
	var l_data: Dictionary[String, int] = {}

	if FileAccess.file_exists(THUMB_INFO_PATH):
		l_file = FileAccess.open(THUMB_INFO_PATH, FileAccess.READ)
		l_data = l_file.get_var()

	var l_path: String = Project.get_file(a_file_id).path

	# Checking if thumb already exists for file.
	if l_path in l_data.keys() and FileAccess.file_exists(THUMB_PATH + str(l_data[l_path])):
		return ImageTexture.create_from_image(Image.load_from_file(THUMB_PATH + str(l_data[l_path]) + ".webp"))

	# No thumb exists so create new one.
	var l_thumb_path: String = THUMB_PATH + str(Toolbox.get_unique_id(l_data.values())) + ".webp"
	var l_image: Image

	# TODO: Create thumbs for all types
	match Project.get_file(a_file_id).type:
		File.TYPE.IMAGE: l_image = Image.load_from_file(l_path)
		File.TYPE.AUDIO:
			printerr("No thumb for Audio files yet!")
			return preload("uid://cs5gcg8kix42x")
		File.TYPE.VIDEO:
			# TODO: Can only do this after implementing the new video playback
			# system because the way of getting the frame data will change.
			printerr("No thumb for Video files yet!")
			return preload("uid://dpg11eiuwgv38")
		_: # File.TYPE.TEXT
			printerr("No thumb for Text files yet!")
			return preload("uid://i70cmg7lfsl4")
	
	# Resizing the image with correct aspect ratio.
	var l_scale: float = min(107 / float(l_image.get_width()), 60 / float(l_image.get_height()))

	l_image.resize(
			int(l_image.get_width() * l_scale),
			int(l_image.get_height() * l_scale),
			Image.INTERPOLATE_BILINEAR)

	if l_image.save_webp(l_thumb_path):
		printerr("Something went wrong saving thumb!")

	# Saving the new entry so we don't create duplicate thumbnails
	if l_file != null:
		l_file.close()
	l_file = FileAccess.open(THUMB_INFO_PATH, FileAccess.WRITE)
	l_data[l_path] = int(l_thumb_path.split('/')[-1])

	if !l_file.store_var(l_data):
		printerr("Error happened when storing thumb data!")

	return ImageTexture.create_from_image(Image.load_from_file(l_thumb_path))


func _process_file(a_file: File, a_file_data: FileData) -> void:
	var l_tab_id: int = int(a_file.type)

	match a_file.type:
		File.TYPE.AUDIO:
			if a_file_data.audio == null or a_file_data.audio.data.size() == 0:
				return
		File.TYPE.VIDEO:
			if a_file_data.videos.size() == 0:
				return

	for x: int in tabs[l_tab_id].item_count:
		if tabs[l_tab_id].get_item_metadata(x) == a_file.id:
			tabs[l_tab_id].set_item_disabled(x, false)
			loading_files.remove_at(loading_files.find(a_file.id))
			break


func _on_project_loaded() -> void:
	# On project loaded we want to clean up the previous entries before adding
	# the current project files.
	for l_list: ItemList in tabs:
		l_list.clear()

	for l_id: int in Project.get_file_ids():
		_add_file_to_list(l_id)


func _file_item_clicked(a_index: int, a_pos: Vector2, a_mouse_index: int, a_tab_id: int) -> void:
	if a_mouse_index == MOUSE_BUTTON_RIGHT:
		var l_file_id: int = tabs[a_tab_id].get_item_metadata(a_index)
		var l_file: File = Project.get_file(l_file_id)
		var l_popup: PopupMenu = PopupMenu.new()

		l_popup.size = Vector2i(100,0)
		l_popup.add_item(tr("Rename"), 0)
		l_popup.add_item(tr("Reload"), 1)
		l_popup.add_item(tr("Delete"), 2)

		match a_tab_id:
			File.TYPE.IMAGE:
				if l_file.path.contains("temp://"):
					l_popup.add_separator("Image options")
					l_popup.add_item(tr("Save as file ..."), 3)
			File.TYPE.VIDEO:
				l_popup.add_separator("Video options")
				l_popup.add_item(tr("Extract audio (WAV)"), 4)
			File.TYPE.TEXT:
				l_popup.add_separator("Text options")
				l_popup.add_item(tr("Duplicate"), 5)
				if l_file.path.contains("temp://"):
					l_popup.add_item(tr("Save as file ..."), 3)

		Toolbox.connect_func(l_popup.id_pressed, _on_list_popup_id_pressed.bind(a_index, l_file))

		add_child(l_popup)
		l_popup.popup()
		l_popup.position.x = int(a_pos.x + 18)
		l_popup.position.y = int(a_pos.y + (l_popup.size.y / 2.0))


func _on_list_popup_id_pressed(a_id: int, a_item_index: int, a_file: File) -> void:
	# For the right click presses of the file popup menu's.
	match a_id:
		0: # Rename
			var l_rename_dialog: FileRenameDialog = preload("uid://y450a2mtc4om").instantiate()

			l_rename_dialog.prepare(a_file.id)
			Toolbox.connect_func(l_rename_dialog.file_renamed, _update_file_nickname.bind(a_item_index))
			get_tree().root.add_child(l_rename_dialog)
		1: # Reload
			Project.reload_file_data(a_file.id)
		2: # Delete
			tabs[int(a_file.type)].remove_item(a_item_index)
			Project.delete_file(a_file.id)
		3: # Save as file (Only for temp files)
			if a_file.type == File.TYPE.TEXT:
				# TODO: Implement duplicating text files
				printerr("Not implemented yet!")
			elif a_file.type == File.TYPE.IMAGE:
				var l_dialog: FileDialog = Toolbox.get_file_dialog(
						tr("Save image to file"),
						FileDialog.FILE_MODE_SAVE_FILE,
						["*.png", "*.jpg", "*.webp"])

				Toolbox.connect_func(l_dialog.file_selected, _save_image_to_file.bind(a_file, a_item_index))

				add_child(l_dialog)
				l_dialog.popup_centered()
		4: # Extract audio
			var l_dialog: FileDialog = Toolbox.get_file_dialog(
					tr("Save video audio to wav"),
					FileDialog.FILE_MODE_SAVE_FILE,
					["*.wav"])

			Toolbox.connect_func(l_dialog.file_selected, _save_audio_to_wav.bind(a_file))

			add_child(l_dialog)
			l_dialog.popup_centered()
		5: # Duplicate (Only for text)
			# TODO: Implement duplicating text files
			printerr("Not implemented yet!")


func _update_file_nickname(a_file_id: int, a_index: int) -> void:
	var l_file: File = Project.get_file(a_file_id)
	var l_tab: ItemList = tabs[l_file.type]

	l_tab.set_item_text(a_index, Toolbox.format_file_nickname(l_file.nickname, NICKNAME_SIZE))
	l_tab.sort_items_by_text()


func _save_audio_to_wav(a_path: String, a_file: File) -> void:
	if Project.get_file_data(a_file.id).audio.save_to_wav(a_path):
		printerr("Error occured when saving to WAV!")


func _save_image_to_file(a_path: String, a_file: File, a_item_index: int) -> void:
	match a_path.get_extension().to_lower():
		"png":
			if a_file.temp_file.image_data.get_image().save_png(a_path):
				printerr("Couldn't save image to png!\n", get_stack())
				return
		"webp":
			if a_file.temp_file.image_data.get_image().save_webp(a_path, false, 1.0):
				printerr("Couldn't save image to webp!\n", get_stack())
				return
		_: 
			if a_file.temp_file.image_data.get_image().save_jpg(a_path, 1.0):
				printerr("Couldn't save image to jpg!\n", get_stack())
				return

	a_file.path = a_path
	a_file.temp_file.free()
	a_file.temp_file = null
	tabs[a_file.type].set_item_tooltip(a_item_index, a_path)

	Project.load_file_data(a_file.id)

	
func _on_files_dropped(a_files: PackedStringArray) -> void:
	if Project.data == null:
		return

	var l_last_type: int = -1

	for l_file_path: String in a_files:
		var l_id: int = add_file(l_file_path)

		if l_id != -1: # Check for invalid file
			_add_file_to_list(l_id)

		l_last_type = int(Project.get_file(l_id).type)

	for l_list: ItemList in tabs:
		l_list.sort_items_by_text()

	buttons[l_last_type].button_pressed = true
	buttons[l_last_type].pressed.emit()


func _on_image_pasted() -> void:
	if !DisplayServer.clipboard_has_image():
		return

	print("Adding image from clipboard ...")

	var l_image: Image = DisplayServer.clipboard_get_image()
	var l_file: File = File.create("temp://image")

	l_file.temp_file = TempFile.new()
	l_file.temp_file.image_data = ImageTexture.create_from_image(l_image)

	Project.get_files()[l_file.id] = l_file
	Project.load_file_data(l_file.id)
	_add_file_to_list(l_file.id)

	tabs[File.TYPE.IMAGE].sort_items_by_text()
	buttons[File.TYPE.IMAGE].button_pressed = true
	buttons[File.TYPE.IMAGE].pressed.emit()


func _add_file_to_list(a_id: int) -> void:
	# Create tree item for the file panel tree
	var l_file: File = Project.get_file(a_id)
	var l_list_id: int = int(l_file.type)
	var l_item: int = tabs[l_list_id].add_item(Toolbox.format_file_nickname(l_file.nickname, NICKNAME_SIZE))

	tabs[l_list_id].set_item_metadata(l_item, a_id)
	tabs[l_list_id].set_item_tooltip(l_item, l_file.path)
	tabs[l_list_id].set_item_icon(l_item, get_thumb(a_id) as Texture2D)

	if loading_files.append(a_id):
		Toolbox.print_append_error()
	

func _get_list_drag_data(_pos: Vector2) -> Draggable:
	var l_draggable: Draggable = Draggable.new()
	var l_tab_id: int = tab_container.current_tab

	l_draggable.files = true
	for l_item: int in tabs[l_tab_id].get_selected_items():
		var l_file_id: int = tabs[l_tab_id].get_item_metadata(l_item)
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


func _on_image_files_button_pressed() -> void:
	tab_container.current_tab = 0


func _on_audio_files_button_pressed() -> void:
	tab_container.current_tab = 1


func _on_video_files_button_pressed() -> void:
	tab_container.current_tab = 2


func _on_text_files_button_pressed() -> void:
	tab_container.current_tab = 3


func _on_add_files_button_pressed() -> void:
	var l_dialog: FileDialog = Toolbox.get_file_dialog(
			tr("Add files to project"), FileDialog.FILE_MODE_OPEN_FILES, [])

	Toolbox.connect_func(l_dialog.files_selected, _on_files_dropped)

	add_child(l_dialog)
	l_dialog.popup_centered()


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

