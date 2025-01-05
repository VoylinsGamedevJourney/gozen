extends Node


signal _on_timeline_scale_changed
signal _on_timeline_end_changed


var _path: String = ""
var _unsaved_changes: bool = false
var undo_redo: UndoRedo = UndoRedo.new()

var files: Dictionary = {} # {Unique_id (int32): File_object}
var _files_data: Dictionary = {} # { Unique_id (int32): FileData }

var resolution: Vector2i = Vector2i(1920,1080)

var framerate: int = 30
var timeline_scale: float = 1.0 : set = set_timeline_scale # How many pixels 1 frame takes 
var timeline_end: int = 0: set = set_timeline_end

var tracks: Array[Dictionary] = [] # [{frame_nr: clip_id}] each dic is a track
var clips: Dictionary = {} # {id: ClipData}
var _audio: Dictionary = {} # { clip_id: PackedByteArray }



func _ready() -> void:
	undo_redo.max_steps = 200

	for i: int in 6:
		tracks.append({})


func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("ui_undo") and undo_redo.has_undo():
		if !undo_redo.undo():
			printerr("Coulnd't undo action!")
	elif a_event.is_action_pressed("ui_redo") and undo_redo.has_redo():
		if !undo_redo.redo():
			printerr("Coulnd't redo action!")

	if a_event.is_action_pressed("play"):
		View._on_play_button_pressed()
		get_viewport().set_input_as_handled()
	elif a_event.is_action("open_render_menu"):
		var l_render_menu: Window = preload("res://scenes/render_menu.tscn").instantiate()

		add_child(l_render_menu)
		l_render_menu.popup_centered()

	if a_event.is_action_pressed("timeline_zoom_in"):
		timeline_scale += 0.1
		get_viewport().set_input_as_handled()
	elif a_event.is_action_pressed("timeline_zoom_out"):
		timeline_scale -= 0.1
		get_viewport().set_input_as_handled()


func save(a_path: String = _path) -> void:
	if a_path == "":
		var l_dialog: FileDialog = FileDialog.new()

		l_dialog.title = "Save project"
		l_dialog.access = FileDialog.ACCESS_FILESYSTEM
		l_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		l_dialog.filters = ["*.gozen"]
		l_dialog.use_native_dialog = true

		if l_dialog.file_selected.connect(save):
			printerr("Couldn't connect file_selected for save dialog!")

		add_child(l_dialog)
		l_dialog.popup_centered()
		return

	_path = a_path

	# TODO: Save the data to an actual file
	OS.set_use_file_access_save_and_swap(true)
	var l_file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	l_file.store_string(var_to_str({
		"files": files,
		"framerate": framerate,
		"timeline_scale": timeline_scale,
		"tracks": tracks,
		"clips": clips,
		"undo_redo": undo_redo
	}))

	l_file.close()
	_unsaved_changes = false
	OS.set_use_file_access_save_and_swap(false)
	

func load(a_path: String) -> void:
	if _unsaved_changes:
		var l_dialog: ConfirmationDialog = ConfirmationDialog.new()

		l_dialog.title = "Save project"
		l_dialog.dialog_text = "Save your project before loading a new project?"
		l_dialog.ok_button_text = "Save"
		l_dialog.cancel_button_text = "Don't save"

		if l_dialog.get_cancel_button().pressed.connect(func() -> void:
				_unsaved_changes = false
				load(a_path)):
			printerr("Couldn't connect cancel button!")
		elif l_dialog.get_ok_button().pressed.connect(func() -> void:
				save()
				load(a_path)):
			printerr("Couldn't connect ok button!")

		add_child(l_dialog)
		l_dialog.popup_centered()
		return

	if a_path == "":
		var l_dialog: FileDialog = FileDialog.new()

		l_dialog.title = "Save project"
		l_dialog.access = FileDialog.ACCESS_FILESYSTEM
		l_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		l_dialog.filters = ["*.gozen"]
		l_dialog.use_native_dialog = true

		if l_dialog.file_selected.connect(load):
			printerr("Couldn't connect file_selected for save dialog!")

		add_child(l_dialog)
		l_dialog.popup_centered()
		return

	_path = a_path

	var l_file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	var l_data: Dictionary = str_to_var(l_file.get_as_text())

	# Reset the data to default variables first!
	_files_data = {}

	# Setting the data to the correct variables
	for l_key: String in l_data.keys():
		match l_key:
			"files": files = l_data[l_key]
			"framerate": framerate = l_data[l_key]
			"timeline_scale": timeline_scale = l_data[l_key]
			"tracks": tracks = l_data[l_key]
			"clips": clips = l_data[l_key]
			"undo_redo": undo_redo = l_data[l_key]

	l_file.close()


func add_file(a_file_path: String) -> int:
	var l_id: int = Utils.get_unique_id(files.keys())
	var l_file: File = File.create(a_file_path)
	var l_file_data: FileData = FileData.new()

	if l_file == null:
		return -1

	# Check if file already exists
	for l_existing: File in files.values():
		if l_existing.path == a_file_path:
			print("File already loaded with path '%s'!" % a_file_path)
			return -1

	files[l_id] = l_file

	l_file_data.id = l_id
	l_file_data.init_data()
	_files_data[l_id] = l_file_data

	return l_id


func get_clip_data(a_track_id: int, a_frame_nr: int) -> ClipData:
	return clips[tracks[a_track_id][a_frame_nr]]


func set_clip_audio(a_clip_id: int, a_data: PackedByteArray) -> void:
	_audio[a_clip_id] = a_data


func get_clip_audio(a_clip_id: int) -> PackedByteArray:
	return _audio[a_clip_id]


func set_timeline_scale(a_new_value: float) -> void:
	a_new_value = clampf(a_new_value, 0.1, 2.0)

	if a_new_value == timeline_scale:
		return

	timeline_scale = a_new_value
	_on_timeline_scale_changed.emit()


func set_timeline_end(a_new_value: int) -> void:
	timeline_end = a_new_value
	_on_timeline_end_changed.emit()

