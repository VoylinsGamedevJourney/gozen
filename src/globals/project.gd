extends DataManager


#------------------------------------------------ SIGNALS
signal _on_project_saved
signal _on_project_loaded

signal _on_file_added(file_id: int)

signal _on_track_added
signal _on_track_removed(track_id: int)

signal _on_framerate_changed(value: int)


#------------------------------------------------ TEMPORARY VARIABLES
var _project_path: String = ""
var _files_data: Dictionary = {} 
var _tracks_data: Array[PackedInt64Array] = []


#------------------------------------------------ DATA VARIABLES
var title: String = ""
var resolution: Vector2i = Vector2i.ZERO
var framerate: int = 30: set = set_framerate

var files: Dictionary = {}
var tracks: Array[Dictionary] = []

var counter_file_id: int = 0
var counter_clip_id: int = 0


#------------------------------------------------ GODOT FUNCTIONS
func _ready() -> void:
	GoZenServer.add_loadables([
		Loadable.new("Setting up tracks",  Project._setup_tracks),
		Loadable.new("Loading tracks data", Project._load_files_data, 1.),
		Loadable.new("Loading tracks data", Project._load_tracks_data, 1.),
	])

	if get_window().files_dropped.connect(_on_files_dropped):
		printerr("Could not connect to files_dropped")


#------------------------------------------------ DATA HANDLING
func save_data() -> void:
	if _project_path == "":
		printerr("Project path is empty, can't save!")
	elif _save_data(_project_path) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for saving! ", _project_path)
	else:
		_on_project_saved.emit()


func load_data(a_path: String) -> void:
	if _load_data(a_path) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for loading! ", a_path)
		get_tree().quit(-1)
	else:
		_on_project_loaded.emit()


#------------------------------------------------ SETTERS
func set_framerate(a_value: int) -> void:
	framerate = a_value

	for l_id: int in files:
		if files[l_id].type == File.VIDEO:
			_calculate_duration_video(l_id)
		elif files[l_id].type == File.AUDIO:
			_calculate_duration_audio(l_id)

	_on_framerate_changed.emit(a_value)


#------------------------------------------------ FILE HANDLING
func _on_files_dropped(a_files: PackedStringArray) -> void:
	for l_path: String in a_files:
		add_file(l_path)

	
func _load_files_data() -> void:
	# Run on startup
	for l_id: int in files:
		if !add_file_data(l_id):
			printerr("Something went wrong loading file with id: %s!" % l_id)
			

func add_file(a_path: String) -> void:
	var l_file: File = File.open(a_path)
	var l_path: String = ""
	
	# Checking for duplicates
	var l_duplicate: bool = false
	for l_id: int in files:
		if files[l_id].path == l_file.path:
			l_duplicate = true
			break

		# sha256 can be the same, so also an extension check
		l_path = files[l_id].path
		if files[l_id].sha256 == l_file.sha256 and l_path.get_extension() == l_file.path.get_extension():
			l_duplicate = true
			break

	if l_duplicate:
		printerr("Files is a duplicate!")
		return
	
	l_file.id = counter_file_id
	files[l_file.id] = l_file
	if !add_file_data(l_file.id):
		if files.erase(l_file.id):
			printerr("Couldn't erase %s from files!" % l_file.id)
		printerr("File data could not be loaded!")
		return

	counter_file_id += 1
	_on_file_added.emit(l_file.id)


func add_file_data(a_id: int) -> bool:
	var l_path: String = files[a_id].path

	match files[a_id]:
		File.VIDEO: 
			var l_array: Array[Video] = []
			if l_array.resize(tracks.size()):
				printerr("Couldn't resize array for VideoData!")
				return false
			_files_data[a_id] = l_array

			for i: int in tracks.size():
				var l_data: VideoData = VideoData.new()
				if l_data.open(l_path, i == 0):
					return false
		File.TEXT: _files_data[a_id] = FileText.open(a_id)
		File.AUDIO: _files_data[a_id] = AudioImporter.load(l_path)
		File.COLOR: _files_data[a_id] = FileColor.open(a_id)
		File.IMAGE: _files_data[a_id] = ImageTexture.create_from_image(Image.load_from_file(l_path))
		File.GRADIENT: _files_data[a_id] = FileGradient.open(a_id)

	if files[a_id].duration == 0:
		match files[a_id].type:
			File.VIDEO: _calculate_duration_video(a_id)
			File.AUDIO: _calculate_duration_audio(a_id)
			File.TEXT: files[a_id].duration = SettingsManager.default_duration_text
			File.COLOR: files[a_id].duration = SettingsManager.default_duration_color
			File.IMAGE: files[a_id].duration = SettingsManager.default_duration_image
			File.GRADIENT: files[a_id].duration = SettingsManager.default_duration_gradient
	return true
	

func _calculate_duration_video(a_id: int) -> void:
	var l_video: Video = _files_data[a_id][0]
	_files_data[a_id][0].duration = round(l_video.get_frame_duration() / l_video.get_framerate() * framerate)


func _calculate_duration_audio(a_id: int) -> void:
	var l_audio_stream: AudioStream = _files_data[a_id]
	_files_data[a_id].duration = round(l_audio_stream.get_length() * framerate)


#------------------------------------------------ TRACK HANDLING
func _setup_tracks() -> void:
	if tracks == []: # If empty
		for i: int in SettingsManager.default_tracks:
			add_track()


func _load_tracks_data() -> void:
	pass


func add_track() -> void:
	tracks.append({})
	_tracks_data.append(PackedInt64Array())
	_on_track_added.emit()


func remove_track(a_id: int) -> void:
	tracks.remove_at(a_id)
	_tracks_data.remove_at(a_id)
	_on_track_removed.emit(a_id)


