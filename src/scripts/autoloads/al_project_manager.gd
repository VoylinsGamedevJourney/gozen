extends Node
## Project Manager


signal _on_project_loaded
signal _on_project_saved
signal _on_unsaved_changes_changed

signal _on_title_changed
signal _on_resolution_changed
signal _on_framerate_changed

signal _on_video_tracks_changed
signal _on_audio_tracks_changed


var _recent_projects: Array = [] # [[title, path], ...]
var _file_data: Dictionary = {} # "Raw" file data

var _unsaved_changes: bool = false: set = set_unsaved_changes
var _project_path: String = "": set = set_project_path

var title: String = "": set = set_title
var current_ids: PackedInt64Array = [0,0] # [ File, Clip ]

var resolution: Vector2i = Vector2i(0,0): set = set_resolution
var framerate: float = 30: set = set_framerate

var video_tracks: Array = []
var audio_tracks: Array = []

var files: Dictionary = {}
var clips: Dictionary = {}



func new_project(a_title: String, a_path: String, a_resolution: Vector2i, a_framerate: int) -> void:
	set_project_path(a_path)
	set_title(a_title)
	set_resolution(a_resolution)
	set_framerate(a_framerate)
	
	for _i: int in SettingsManager.get_default_video_track_amount():
		add_video_track()
	for _i: int in SettingsManager.get_default_audio_track_amount():
		add_audio_track()
	
	_on_project_loaded.emit()
	save_project()


func save_project() -> void:
	var l_file: FileAccess = FileAccess.open(_project_path, FileAccess.WRITE)
	var l_data: Dictionary = {}
	
	for l_dic: Dictionary in get_property_list():
		if (l_dic.usage == 4096 or l_dic.usage == 4102) and l_dic.name[0] != "_":
			l_data[l_dic.name] = get(l_dic.name)
	
	l_file.store_string(var_to_str(l_data))
	_on_project_saved.emit()
	set_unsaved_changes(false)


func load_project(a_path: String) -> void:
	if a_path.split('.')[-1].to_lower() != "gozen":
		printerr("Can't load project, path has no '*.gozen' extension!")
		return
	set_project_path(a_path)
	
	var l_file: FileAccess = FileAccess.open(_project_path, FileAccess.READ)
	var l_data: Dictionary = str_to_var(l_file.get_as_text())
	
	for l_key: String in l_data.keys():
		set(l_key, l_data[l_key])
	
	_on_project_loaded.emit()


#region #####################  Setters & Getters  ##############################

func set_unsaved_changes(a_value: bool) -> void:
	_unsaved_changes = a_value
	_on_unsaved_changes_changed.emit()


func set_project_path(a_value: String) -> void:
	if a_value.split('.')[-1].to_lower() == "gozen":
		_project_path = a_value
	else:
		_project_path = "%s.gozen" % a_value


func set_title(a_value: String) -> void:
	title = a_value
	_on_title_changed.emit()
	update_project_entry(title, _project_path)
	set_unsaved_changes(true)


func increase_current_file_id() -> void:
	current_ids[0] += 1


func increase_current_clip_id() -> void:
	current_ids[1] += 1


func get_current_file_id() -> int:
	return current_ids[0]


func get_current_clip_id() -> int:
	return current_ids[1]


func set_resolution(a_value: Vector2i) -> void:
	resolution = a_value
	_on_resolution_changed.emit()
	set_unsaved_changes(true)


func set_framerate(a_value: float) -> void:
	framerate = a_value
	_on_framerate_changed.emit()
	set_unsaved_changes(true)


func add_video_track() -> void:
	video_tracks.append({})
	_on_video_tracks_changed.emit()
	set_unsaved_changes(true)


func add_audio_track() -> void:
	audio_tracks.append({})
	_on_audio_tracks_changed.emit()
	set_unsaved_changes(true)


func remove_video_track(a_position: int) -> void:
	video_tracks.remove_at(a_position)
	_on_video_tracks_changed.emit()
	set_unsaved_changes(true)


func remove_audio_track(a_position: int) -> void:
	audio_tracks.remove_at(a_position)
	_on_audio_tracks_changed.emit()
	set_unsaved_changes(true)


func add_file(a_data: Dictionary) -> void:
	files[get_current_file_id()] = a_data
	increase_current_file_id()
	set_unsaved_changes(true)


func add_clip(a_data: Dictionary) -> void:
	files[get_current_clip_id()] = a_data
	increase_current_clip_id()
	set_unsaved_changes(true)


#endregion
#region #####################  Recent Projects  ################################


func _init() -> void:
	if !FileAccess.file_exists("user://recent_projects"):
		return
	
	var l_file: FileAccess = FileAccess.open("user://recent_projects", FileAccess.READ)
	_recent_projects = str_to_var(l_file.get_as_text())
	
	# Check data
	var l_clean_data: Array = []
	var l_existing_paths: PackedStringArray = []
	
	for l_entry: Array in get_recent_projects():
		if FileAccess.file_exists(l_entry[1]) and not l_entry[1] in l_existing_paths:
			l_clean_data.append(l_entry)
			l_existing_paths.append(l_entry[1])
	if get_recent_projects() != l_clean_data:
		_recent_projects = l_clean_data
		save_recent_projects_data()


func update_project_entry(a_title: String, a_path: String) -> void:
	var l_clean_data : Array = []
	var l_found: bool = false
	
	for l_entry: Array in _recent_projects:
		if l_entry[1] == a_path:
			l_found = true
			l_entry[0] = a_title
			l_clean_data.insert(0, l_entry)
		l_clean_data.append(l_entry)
	
	if !l_found:
		_recent_projects.insert(0, [a_title, a_path])
	save_recent_projects_data()


func save_recent_projects_data() -> void:
	var l_file: FileAccess = FileAccess.open("user://recent_projects", FileAccess.WRITE)
	l_file.store_string(var_to_str(get_recent_projects()))

#endregion
