extends DataManager


#------------------------------------------------ SIGNALS
signal _on_project_saved
signal _on_project_loaded
signal _on_changes_occurred

signal _on_title_changed

signal _on_folder_added(path: String)
signal _on_folder_removed(path: String)

signal _on_file_added(file_id: int)
signal _on_file_nickname_changed(file_id: int)
signal _on_file_removed(file_id: int)

signal _on_track_added
signal _on_track_removed(track_id: int)

signal _on_clip_added(clip_id: int)
signal _on_clip_moved(track_id: int, pts: int)
signal _on_clip_removed(track_id: int, pts: int)
signal _on_clip_resized(clip_id: int)

signal _on_end_pts_changed(value: int)
signal _on_framerate_changed(value: int)
signal _on_playhead_moved(value: bool)


#------------------------------------------------ TEMPORARY VARIABLES
var _project_path: String = ""
var _files_data: Dictionary = {} 
var _tracks_data: Array[PackedInt64Array] = []
var _clip_nodes: Dictionary = {} 

var _unsaved_changes: bool = false

var _end_pts: int = 0


#------------------------------------------------ DATA VARIABLES
var title: String = "" : set = set_title
var resolution: Vector2i = Vector2i.ZERO
var framerate: int = 30: set = set_framerate

var files: Dictionary = {}
var tracks: Array[Dictionary] = []
var clips: Dictionary = {}

# NOTE: Only half implemented, core doesn't use but is here for modules
var folders: PackedStringArray = []

var counter_file_id: int = 0
var counter_clip_id: int = 0

var playhead_pos: int = 0: set = set_playhead_pos


#------------------------------------------------ GODOT FUNCTIONS
func _ready() -> void:
	GoZenServer.add_loadables([
		Loadable.new("Setting up tracks",  Project._setup_tracks),
		Loadable.new("Loading files data", Project._load_files_data),
		Loadable.new("Loading tracks data", Project._load_tracks_data),
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
	_unsaved_changes = false


func load_data(a_path: String) -> void:
	if _load_data(a_path) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for loading! ", a_path)
		get_tree().quit(-1)
	else:
		_project_path = a_path
		_on_project_loaded.emit()
	
	
func _changes_occurred() -> void:
	_unsaved_changes = true
	_on_changes_occurred.emit()


#------------------------------------------------ SETTERS
func set_title(a_title: String) -> void:
	title = a_title
	_on_title_changed.emit()


func set_framerate(a_value: int) -> void:
	framerate = a_value

	for l_id: int in files:
		if files[l_id].type == File.VIDEO:
			_calculate_duration_video(l_id)
		elif files[l_id].type == File.AUDIO:
			_calculate_duration_audio(l_id)
	
	# TODO: Change all the clip durations so the timeline doesn't get messed up
	_on_framerate_changed.emit(a_value)


func set_playhead_pos(a_value: int) -> void:
	playhead_pos = a_value
	_on_playhead_moved.emit(true)


#------------------------------------------------ FILE HANDLING
func _on_files_dropped(a_files: PackedStringArray) -> void:
	for l_path: String in a_files:
		add_file(l_path)
		_changes_occurred()

	
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
		if !files.erase(l_file.id):
			printerr("Couldn't erase %s from files!" % l_file.id)
		printerr("File data could not be loaded!")
		return

	counter_file_id += 1
	_on_file_added.emit(l_file.id)


func add_file_data(a_id: int) -> bool:
	var l_path: String = files[a_id].path

	match files[a_id].type:
		File.TEXT: _files_data[a_id] = FileText.open(a_id)
		File.COLOR: _files_data[a_id] = FileColor.open(a_id)
		File.IMAGE: _files_data[a_id] = ImageTexture.create_from_image(Image.load_from_file(l_path))
		File.AUDIO: _files_data[a_id] = AudioImporter.load(l_path)
		File.VIDEO: 
			var l_array: Array[VideoData] = []
			if l_array.resize(tracks.size()):
				printerr("Couldn't resize array for VideoData!")
				return false

			for i: int in tracks.size():
				var l_data: VideoData = VideoData.new()
				if !l_data.open(l_path, i == 0):
					return false
				l_array[i] = l_data
			_files_data[a_id] = l_array

	if files[a_id].duration == 0:
		match files[a_id].type:
			File.TEXT: files[a_id].duration = SettingsManager.default_duration_text
			File.COLOR: files[a_id].duration = SettingsManager.default_duration_color
			File.IMAGE: files[a_id].duration = SettingsManager.default_duration_image
			File.AUDIO: _calculate_duration_audio(a_id)
			File.VIDEO: _calculate_duration_video(a_id)
	return true


func change_file_nickname(a_file_id: int, a_new_nickname: String) -> void:
	files[a_file_id].nickname = a_new_nickname
	_on_file_nickname_changed.emit(a_file_id)
	

func remove_file(a_id: int) -> void:
	if !files.erase(a_id):
		printerr("Couldn't remove file id %s from project files!" % a_id)
	if _files_data.erase(a_id):
		printerr("Couldn't remove file data id %s from project files!" % a_id)
	_on_file_removed.emit(a_id)


func _calculate_duration_video(a_id: int) -> void:
	var l_video: Video = _files_data[a_id][0].data
	files[a_id].duration = round(l_video.get_frame_duration() / l_video.get_framerate() * framerate)


func _calculate_duration_audio(a_id: int) -> void:
	var l_audio_stream: AudioStream = _files_data[a_id]
	files[a_id].duration = round(l_audio_stream.get_length() * framerate)


#------------------------------------------------ FOLDER HANDLING
func add_folder(a_path: String) -> void:
	if !folders.append(a_path):
		printerr("Error happend appending folder!")
	_on_folder_added.emit(a_path)


func remove_folder(a_path: String) -> void:
	folders.remove_at(folders.find(a_path))
	_on_folder_removed.emit(a_path)


#------------------------------------------------ TRACK HANDLING
func _setup_tracks() -> void:
	if tracks == []: # If empty
		for i: int in SettingsManager.default_tracks:
			_add_track()


func _load_tracks_data() -> void:
	pass


func _add_track() -> void:
	tracks.append({})
	_tracks_data.append(PackedInt64Array())
	_on_track_added.emit()
	_changes_occurred()


func _remove_track(a_id: int) -> void:
	# Removing tracks is destructive and can't be recovered with ctrl+z
	for l_clip_id: int in tracks[a_id].keys():
		_remove_clip(l_clip_id)

	tracks.remove_at(a_id)
	_tracks_data.remove_at(a_id)
	_on_track_removed.emit(a_id)

	_update_end_pts()
	_changes_occurred()


#------------------------------------------------ CLIP HANDLING
func _add_clip(a_file_id: int, a_pts: int, a_track_id: int) -> void:
	counter_clip_id += 1
	var clip_id: int = counter_clip_id

	clips[clip_id] = ClipData.new()
	clips[clip_id].id = clip_id
	clips[clip_id].file_id = a_file_id
	clips[clip_id].pts = a_pts
	clips[clip_id].duration = files[a_file_id].duration
	clips[clip_id].start = 0
	clips[clip_id].end = files[a_file_id].duration
	clips[clip_id].track_id = a_track_id
	tracks[a_track_id][a_pts] = clip_id

	_on_clip_added.emit(clip_id)
	_clip_nodes[clip_id] = []

	_update_end_pts()
	_changes_occurred()


func _move_clip(a_clip_id: int, a_new_pts: int, a_new_track_id: int) -> void:
	if !tracks[clips[a_clip_id].track_id].erase(clips[a_clip_id].pts):
		printerr("Couldn't remove clip id %s with pts %s from tracks!" % [a_clip_id, clips[a_clip_id].pts])

	tracks[a_new_track_id][a_new_pts] = a_clip_id
	clips[a_clip_id].pts = a_new_pts

	_on_clip_moved.emit(a_new_track_id, a_clip_id)
	_update_end_pts()
	_changes_occurred()


func _remove_clip(a_id: int) -> void:
	if !tracks[clips[a_id].track_id].erase(clips[a_id].pts):
		printerr("Couldn't remove clip id %s with pts %s from tracks!" % [a_id, clips[a_id].pts])
	if !clips.erase(a_id):
		printerr("Couln't remove clip id %s from clips!" % a_id)	
	_on_clip_removed.emit(clips[a_id].track_id, clips[a_id].pts)

	for l_node: Control in _clip_nodes[a_id]:
		l_node.queue_free()

	_update_end_pts()
	_changes_occurred()


func _resize_clip(a_id: int, a_duration: int, a_left: bool) -> void:
	if !tracks[clips[a_id].track_id].erase(clips[a_id].pts):
		printerr("Couldn't remove clip id %s with pts %s from tracks!" % [a_id, clips[a_id].pts])

	var l_old_duration: int = clips[a_id].duration
	var l_difference: int = a_duration - l_old_duration
	clips[a_id].duration = a_duration
	
	if a_left:
		clips[a_id].pts = clips[a_id].pts - l_difference

	if files[clips[a_id].file_id].type in [File.AUDIO, File.VIDEO]:
		if a_left:
			clips[a_id].start -= l_difference
		else:
			clips[a_id].end += l_difference

	_on_clip_resized.emit(a_id)
	_update_end_pts()
	_changes_occurred()


func get_clip_pts(a_id: int) -> int:
	var l_clip: ClipData = clips[a_id]
	return l_clip.pts


func get_clip_duration(a_id: int) -> int:
	var l_clip: ClipData = clips[a_id]
	return l_clip.duration


func get_clip_file_id(a_id: int) -> int:
	var l_clip: ClipData = clips[a_id]
	return l_clip.file_id


func get_clip_track(a_id: int) -> int:
	var l_clip: ClipData = clips[a_id]
	return l_clip.track_id


#------------------------------------------------ MISC
func _update_end_pts() -> void:
	var l_pts: int = 0
	for l_track_data: Dictionary in tracks:
		if l_track_data.size() == 0:
			continue 

		var l_clip: ClipData = clips[l_track_data[l_track_data.keys().max()]]

		if l_pts < l_clip.get_end_pts():
			l_pts = l_clip.get_end_pts()

	if l_pts != _end_pts:
		_end_pts = l_pts
		_on_end_pts_changed.emit(_end_pts)

