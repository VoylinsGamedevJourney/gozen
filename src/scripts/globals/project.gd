extends Node


signal _on_timeline_end_changed
signal _on_project_loaded


var _path: String = ""
var _unsaved_changes: bool = false
var undo_redo: UndoRedo = UndoRedo.new()

var files: Dictionary[int, File] = {} # {Unique_id (int32): File_object}
var _files_data: Dictionary[int, FileData] = {} # { Unique_id (int32): FileData }

var resolution: Vector2i = Vector2i(1920,1080)

var playhead_position: int = 0
var framerate: int = 30
var timeline_end: int = 0: set = set_timeline_end

var tracks: Array[Dictionary] = [] # [{frame_nr: clip_id}] each dic is a track
var clips: Dictionary[int, ClipData] = {} # {id: ClipData}
var _audio: Dictionary[int, PackedByteArray] = {} # { clip_id: PackedByteArray }



func _ready() -> void:
	undo_redo.max_steps = 200

	for i: int in 6:
		tracks.append({})


func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("breakpoint"):
		breakpoint

	if a_event.is_action_pressed("save_project", false, true):
		save_project(_path)
	elif a_event.is_action_pressed("save_project_as", false, true):
		save_project("")
	elif a_event.is_action_pressed("load_project", false, true):
		load_project("")

	if a_event.is_action_pressed("ui_undo", false, true) and undo_redo.has_undo():
		if !undo_redo.undo():
			printerr("Coulnd't undo action!")
	elif a_event.is_action_pressed("ui_redo", false, true) and undo_redo.has_redo():
		if !undo_redo.redo():
			printerr("Coulnd't redo action!")

	if a_event.is_action_pressed("play"):
		View._on_play_button_pressed()
		get_viewport().set_input_as_handled()


func save_project(a_path: String) -> void:
	if a_path == "":
		return _open_save_project_dialog()

	_path = a_path
	if _path.split('.')[-1] != 'gozen':
		_path = _path + '.gozen'

	# TODO: Save the data to an actual file
	OS.set_use_file_access_save_and_swap(true)
	var l_file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	@warning_ignore("return_value_discarded")
	l_file.store_string(var_to_str({
		"files": files,
		"framerate": framerate,
		"tracks": tracks,
		"clips": clips,
		"undo_redo": undo_redo,
		"playhead_position": View.frame_nr,
	} as Dictionary))

	l_file.close()
	_unsaved_changes = false
	OS.set_use_file_access_save_and_swap(false)
	

func load_project(a_path: String) -> void:
	if _unsaved_changes:
		var l_dialog: ConfirmationDialog = ConfirmationDialog.new()

		l_dialog.title = "Save project"
		l_dialog.dialog_text = "Save your project before loading a new project?"
		l_dialog.ok_button_text = "Save"
		l_dialog.cancel_button_text = "Don't save"

		if l_dialog.get_cancel_button().pressed.connect(func() -> void:
				_unsaved_changes = false
				load_project(a_path)):
			printerr("Couldn't connect cancel button!")
		elif l_dialog.get_ok_button().pressed.connect(func() -> void:
				save_project(_path)
				load_project(a_path)):
			printerr("Couldn't connect ok button!")

		add_child(l_dialog)
		l_dialog.popup_centered()
		return

	if a_path == "":
		return _open_load_project_dialog()

	_path = a_path
	print(a_path)
	print(_path)

	# Resetting all variables
	var l_new_instance: Node = (load("uid://biap2s04hs0bi") as GDScript).new()

	for l_property: Dictionary in l_new_instance.get_property_list():
		if l_property.usage == 4096 and l_property.name != "_path":
			@warning_ignore("unsafe_call_argument")
			set(l_property.name, l_new_instance.get(l_property.name))

	var l_file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	var l_data: Dictionary = str_to_var(l_file.get_as_text())

	# Reset the data to default variables first!
	_files_data = {}

	# Setting the data to the correct variables
	for l_key: String in l_data.keys():
		match l_key:
			"files": files = l_data[l_key]
			"framerate": framerate = l_data[l_key]
			"tracks": tracks = l_data[l_key]
			"clips": clips = l_data[l_key]
			"undo_redo": undo_redo = l_data[l_key]
			"playhead_position": View.frame_nr = l_data[l_key]

	l_file.close()
	await RenderingServer.frame_post_draw

	print("Loading files ...")
	for l_file_id: int in files.keys():
		_load_file_data(l_file_id)
		_files_data[l_file_id].load_wave()

	print("Loading clip audio ...")
	for l_clip_data: ClipData in clips.values():
		l_clip_data.update_audio_data()

	_on_project_loaded.emit()


func _open_save_project_dialog() -> void:
	var l_dialog: FileDialog = FileDialog.new()

	l_dialog.title = "Save project"
	l_dialog.access = FileDialog.ACCESS_FILESYSTEM
	l_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	l_dialog.filters = ["*.gozen"]
	l_dialog.use_native_dialog = true
	
	@warning_ignore("return_value_discarded")
	l_dialog.file_selected.connect(save_project)

	add_child(l_dialog)
	l_dialog.popup_centered()


func _open_load_project_dialog() -> void:
	var l_dialog: FileDialog = FileDialog.new()

	l_dialog.title = "Load project"
	l_dialog.access = FileDialog.ACCESS_FILESYSTEM
	l_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	l_dialog.filters = ["*.gozen"]
	l_dialog.use_native_dialog = true

	if l_dialog.file_selected.connect(load_project):
		printerr("Couldn't connect file_selected for save dialog!")

	add_child(l_dialog)
	l_dialog.popup_centered()


func add_file(a_file_path: String) -> int:
	var l_id: int = Utils.get_unique_id(files.keys())
	var l_file: File = File.create(a_file_path)

	if l_file == null:
		return -1

	# Check if file already exists
	for l_existing: File in files.values():
		if l_existing.path == a_file_path:
			print("File already loaded with path '%s'!" % a_file_path)
			return -1

	files[l_id] = l_file
	_load_file_data(l_id)

	return l_id


func _load_file_data(a_id: int) -> void:
	var l_file_data: FileData = FileData.new()

	l_file_data.init_data(a_id)
	_files_data[a_id] = l_file_data


func set_clip_audio(a_clip_id: int, a_data: PackedByteArray) -> void:
	_audio[a_clip_id] = a_data


func get_clip_audio(a_clip_id: int) -> PackedByteArray:
	return _audio[a_clip_id]


func set_timeline_end(a_new_value: int) -> void:
	timeline_end = a_new_value
	_on_timeline_end_changed.emit()

