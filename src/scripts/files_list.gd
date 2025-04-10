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

	for list_id: int in tabs.size():
		tabs[list_id].set_drag_forwarding(_get_list_drag_data, Callable(), Callable())
		Toolbox.connect_func(tabs[list_id].item_clicked, _file_item_clicked.bind(list_id))


func _process(_delta: float) -> void:
	if loading_files.size() != 0:
		for i: int in loading_files:
			_process_file(Project.get_file(i), Project.get_file_data(i))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_paste"):
		_on_image_pasted()

	
func get_thumb(file_id: int) -> Texture:
	# This function also creates the thumb if not existing yet.
	if !DirAccess.dir_exists_absolute(THUMB_PATH):
		if DirAccess.make_dir_absolute(THUMB_PATH):
			printerr("Couldn't create folder at %s!" % THUMB_PATH)

	var file: FileAccess
	var data: Dictionary[String, int] = {}

	if FileAccess.file_exists(THUMB_INFO_PATH):
		file = FileAccess.open(THUMB_INFO_PATH, FileAccess.READ)
		data = file.get_var()

	var path: String = Project.get_file(file_id).path

	# Checking if thumb already exists for file.
	if path in data.keys() and FileAccess.file_exists(THUMB_PATH + str(data[path])):
		return ImageTexture.create_from_image(Image.load_from_file(THUMB_PATH + str(data[path]) + ".webp"))

	# No thumb exists so create new one.
	var thumb_path: String = THUMB_PATH + str(Toolbox.get_unique_id(data.values())) + ".webp"
	var image: Image

	# TODO: Create thumbs for all types
	match Project.get_file(file_id).type:
		File.TYPE.IMAGE: image = Image.load_from_file(path)
		File.TYPE.AUDIO:
			push_warning("No thumb for Audio files yet!")
			return preload("uid://cs5gcg8kix42x")
		File.TYPE.VIDEO:
			# TODO: Can only do this after implementing the new video playback
			# system because the way of getting the frame data will change.
			push_warning("No thumb for Video files yet!")
			return preload("uid://dpg11eiuwgv38")
		_: # File.TYPE.TEXT
			push_warning("No thumb for Text files yet!")
			return preload("uid://i70cmg7lfsl4")
	
	# Resizing the image with correct aspect ratio.
	var image_scale: float = min(107 / float(image.get_width()), 60 / float(image.get_height()))

	image.resize(
			int(image.get_width() * image_scale),
			int(image.get_height() * image_scale),
			Image.INTERPOLATE_BILINEAR)

	if image.save_webp(thumb_path):
		printerr("Something went wrong saving thumb!")

	# Saving the new entry so we don't create duplicate thumbnails
	if file != null:
		file.close()
	file = FileAccess.open(THUMB_INFO_PATH, FileAccess.WRITE)
	data[path] = int(thumb_path.split('/')[-1])

	if !file.store_var(data):
		printerr("Error happened when storing thumb data!")

	return ImageTexture.create_from_image(Image.load_from_file(thumb_path))


func _process_file(file: File, file_data: FileData) -> void:
	var tab_id: int = int(file.type)

	match file.type:
		File.TYPE.AUDIO:
			if file_data.audio == null or file_data.audio.data.size() == 0:
				return
		File.TYPE.VIDEO:
			if file_data.video == null:
				return

	for x: int in tabs[tab_id].item_count:
		if tabs[tab_id].get_item_metadata(x) == file.id:
			tabs[tab_id].set_item_disabled(x, false)
			loading_files.remove_at(loading_files.find(file.id))
			break


func _on_project_loaded() -> void:
	# On project loaded we want to clean up the previous entries before adding
	# the current project files.
	for list: ItemList in tabs:
		list.clear()

	for id: int in Project.get_file_ids():
		_add_file_to_list(id)


func _file_item_clicked(index: int, pos: Vector2, mouse_index: int, tab_id: int) -> void:
	if mouse_index == MOUSE_BUTTON_RIGHT:
		var file_id: int = tabs[tab_id].get_item_metadata(index)
		var file: File = Project.get_file(file_id)
		var popup: PopupMenu = PopupMenu.new()

		popup.size = Vector2i(100,0)
		popup.add_item(tr("Rename"), 0)
		popup.add_item(tr("Reload"), 1)
		popup.add_item(tr("Delete"), 2)

		match tab_id:
			File.TYPE.IMAGE:
				if file.path.contains("temp://"):
					popup.add_separator("Image options")
					popup.add_item(tr("Save as file ..."), 3)
			File.TYPE.VIDEO:
				popup.add_separator("Video options")
				popup.add_item(tr("Extract audio (WAV)"), 4)
			File.TYPE.TEXT:
				popup.add_separator("Text options")
				popup.add_item(tr("Duplicate"), 5)
				if file.path.contains("temp://"):
					popup.add_item(tr("Save as file ..."), 3)

		Toolbox.connect_func(popup.id_pressed, _on_list_popup_id_pressed.bind(index, file))

		add_child(popup)
		popup.popup()
		popup.position.x = int(pos.x + 18)
		popup.position.y = int(pos.y + (popup.size.y / 2.0))


func _on_list_popup_id_pressed(id: int, item_index: int, file: File) -> void:
	# For the right click presses of the file popup menu's.
	match id:
		0: # Rename
			var rename_dialog: FileRenameDialog = preload("uid://y450a2mtc4om").instantiate()

			rename_dialog.prepare(file.id)
			Toolbox.connect_func(rename_dialog.file_renamed, _update_file_nickname.bind(item_index))
			get_tree().root.add_child(rename_dialog)
		1: # Reload
			Project.reload_file_data(file.id)
		2: # Delete
			tabs[int(file.type)].remove_item(item_index)
			Project.delete_file(file.id)
		3: # Save as file (Only for temp files)
			if file.type == File.TYPE.TEXT:
				# TODO: Implement duplicating text files
				printerr("Not implemented yet!")
			elif file.type == File.TYPE.IMAGE:
				var dialog: FileDialog = Toolbox.get_file_dialog(
						tr("Save image to file"),
						FileDialog.FILE_MODE_SAVE_FILE,
						["*.png", "*.jpg", "*.webp"])

				Toolbox.connect_func(dialog.file_selected, _save_image_to_file.bind(file, item_index))

				add_child(dialog)
				dialog.popup_centered()
		4: # Extract audio
			var dialog: FileDialog = Toolbox.get_file_dialog(
					tr("Save video audio to wav"),
					FileDialog.FILE_MODE_SAVE_FILE,
					["*.wav"])

			Toolbox.connect_func(dialog.file_selected, _save_audio_to_wav.bind(file))

			add_child(dialog)
			dialog.popup_centered()
		5: # Duplicate (Only for text)
			# TODO: Implement duplicating text files
			printerr("Not implemented yet!")


func _update_file_nickname(file_id: int, index: int) -> void:
	var file: File = Project.get_file(file_id)
	var tab: ItemList = tabs[file.type]

	tab.set_item_text(index, Toolbox.format_file_nickname(file.nickname, NICKNAME_SIZE))
	tab.sort_items_by_text()


func _save_audio_to_wav(path: String, file: File) -> void:
	if Project.get_file_data(file.id).audio.save_to_wav(path):
		printerr("Error occured when saving to WAV!")


func _save_image_to_file(path: String, file: File, item_index: int) -> void:
	match path.get_extension().to_lower():
		"png":
			if file.temp_file.image_data.get_image().save_png(path):
				printerr("Couldn't save image to png!\n", get_stack())
				return
		"webp":
			if file.temp_file.image_data.get_image().save_webp(path, false, 1.0):
				printerr("Couldn't save image to webp!\n", get_stack())
				return
		_: 
			if file.temp_file.image_data.get_image().save_jpg(path, 1.0):
				printerr("Couldn't save image to jpg!\n", get_stack())
				return

	file.path = path
	file.temp_file.free()
	file.temp_file = null
	tabs[file.type].set_item_tooltip(item_index, path)

	Project.load_file_data(file.id)

	
func _on_files_dropped(files: PackedStringArray) -> void:
	if Project.data == null:
		return

	var last_type: int = -1

	for file_path: String in files:
		var id: int = add_file(file_path)

		if id != -1: # Check for invalid file
			_add_file_to_list(id)

		last_type = int(Project.get_file(id).type)

	for list: ItemList in tabs:
		list.sort_items_by_text()

	buttons[last_type].button_pressed = true
	buttons[last_type].pressed.emit()


func _on_image_pasted() -> void:
	if !DisplayServer.clipboard_has_image():
		return

	print("Adding image from clipboard ...")

	var image: Image = DisplayServer.clipboard_get_image()
	var file: File = File.create("temp://image")

	file.temp_file = TempFile.new()
	file.temp_file.image_data = ImageTexture.create_from_image(image)

	Project.set_file(file.id, file)
	Project.load_file_data(file.id)
	_add_file_to_list(file.id)

	tabs[File.TYPE.IMAGE].sort_items_by_text()
	buttons[File.TYPE.IMAGE].button_pressed = true
	buttons[File.TYPE.IMAGE].pressed.emit()


func _add_file_to_list(id: int) -> void:
	# Create tree item for the file panel tree
	var file: File = Project.get_file(id)
	var list_id: int = int(file.type)
	var item: int = tabs[list_id].add_item(Toolbox.format_file_nickname(file.nickname, NICKNAME_SIZE))

	tabs[list_id].set_item_metadata(item, id)
	tabs[list_id].set_item_tooltip(item, file.path)
	tabs[list_id].set_item_icon(item, get_thumb(id) as Texture2D)

	if loading_files.append(id):
		Toolbox.print_append_error()
	

func _get_list_drag_data(_pos: Vector2) -> Draggable:
	var draggable: Draggable = Draggable.new()
	var tab_id: int = tab_container.current_tab

	draggable.files = true
	for item: int in tabs[tab_id].get_selected_items():
		var file_id: int = tabs[tab_id].get_item_metadata(item)
		var file: File = Project.get_file(file_id)
		var file_data: FileData = Project.get_file_data(file_id)

		if draggable.ids.append(file_id):
			printerr("Something went wrong appending to draggable ids!")

		if file.duration <= 0:
			file_data._update_duration()

		draggable.duration += file.duration

	return draggable


func _on_files_list_item_clicked(_index: int, _pos: Vector2, mouse_index: int) -> void:
	if mouse_index == MOUSE_BUTTON_LEFT:
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
	var dialog: FileDialog = Toolbox.get_file_dialog(
			tr("Add files to project"), FileDialog.FILE_MODE_OPEN_FILES, [])

	Toolbox.connect_func(dialog.files_selected, _on_files_dropped)

	add_child(dialog)
	dialog.popup_centered()


func add_file(file_path: String) -> int:
	var file: File = File.create(file_path)

	if file == null:
		return -1

	# Check if file already exists
	for existing: File in Project.get_files().values():
		if existing.path == file_path:
			print("File already loaded with path '%s'!" % file_path)

	Project.set_file(file.id, file)
	Project.load_file_data(file.id)

	return file.id

