extends DataManager

# TODO: Bind to project saved to automatically update the creation date for the current project
# TODO: Add thumb data


const PATH: String = "user://recent_projects"


var _current_project_id: int = -1
var project_data: Array[PackedStringArray] = [] # [Path, title, creation_date, last_edited]



func _ready() -> void:
	if ProjectManager._on_project_saved.connect(update_project_last_edited):
		printerr("Couldn't connect to ProjectManager!")

	if load_data(PATH) == ERR_FILE_CANT_OPEN:
		printerr("Recent projects file unreadable! ", PATH)
	else:
		_update_data()
		

func save() -> void:
	if save_data(PATH) == ERR_FILE_CANT_OPEN:
		printerr("Can't open recent projects file for saving! ", PATH)


func _update_data() -> void:
	var l_project_data: Array[PackedStringArray] = []
	for l_entry: PackedStringArray in project_data:
		if l_entry != PackedStringArray([]) and FileAccess.file_exists(l_entry[0]):
			l_project_data.append(l_entry)
	
	project_data = l_project_data
	save()


func add_project(a_path: String, a_title: String) -> void:
	var l_creation_date: String = get_date_string()
	project_data.append([a_path, a_title, l_creation_date, l_creation_date])


func remove_project(a_id: int) -> void:
	project_data[a_id] = PackedStringArray([])


func update_project_last_edited(a_id: int = _current_project_id) -> void:
	if a_id < 0 or a_id > project_data.size():
		printerr("Recent project id is invalid! ", a_id)

	project_data[a_id][3] = get_date_string()
	save()


func get_data() -> Array[RecentProjectData]:
	var l_dates: PackedInt32Array = []
	var l_data: Array[RecentProjectData] = []
	var l_dic: Dictionary = {}

	for i: int in project_data.size():
		if l_dates.append(int(project_data[i][3])):
			printerr("Could not append data to l_dates! ", int(project_data[i][3]))
			continue

		var l_project_data: RecentProjectData = RecentProjectData.new()
		l_project_data.id = i
		l_project_data.path = project_data[i][0]
		l_project_data.title = project_data[i][1]
		l_project_data.creation_date = project_data[i][2]
		l_project_data.last_edited = project_data[i][3]
		l_dic[int(project_data[i][3])] = l_project_data
	
	l_dates.sort()
	for l_date: int in l_dates:
		l_data.append(l_dic[l_date])

	return l_data


func set_current_project_id(a_id: int) -> void:
	if a_id < 0 or a_id > project_data.size():
		printerr("Invalid id for setting current project id! ", a_id)
		return

	_current_project_id = a_id

func get_date_string(a_datetime: Dictionary = Time.get_datetime_dict_from_system()) -> String:
	return "%s%s%s%s%s%s" % [a_datetime.year,   "%02d" % a_datetime.month,
		"%02d" % a_datetime.day, "%02d" % a_datetime.hour,
		"%02d" % a_datetime.minute, "%02d" % a_datetime.second]
