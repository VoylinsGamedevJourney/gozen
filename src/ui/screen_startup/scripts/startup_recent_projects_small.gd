extends VBoxContainer


func _ready():
	var file_path: String = ProjectSettings.get_setting("globals/path/recent_projects")
	if !FileAccess.file_exists(file_path):
		$Spacer2.visible = false
		$ShowAllProjectsButton.visible = false
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file.get_open_error():
		Printer.error("Could not open recent projects file: '%s'!" % file.get_open_error())
		return
	
	## Updating/Cleaning recent projects file
	# Each entry is made up like this: 'title||path||datetime'
	var file_data: PackedStringArray = file.get_as_text().split('\n')
	var check_array: PackedStringArray = []
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		var entry_check: String = "%s||%s" % [entry_data[0], entry_data[1]]
		# Title+path will be the same, but date and time can be different
		if !check_array.has(entry_check) and FileAccess.file_exists(entry_data[1]):
			check_array.append(entry_check)
		else:
			file_data.remove_at(file_data.find(entry))
	var new_file_data: String = ""
	for entry: String in file_data: 
		new_file_data += "%s\n" % entry
	file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(new_file_data)
	
	## Populating the short recent projects list
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		if entry_data.size() != 3:
			# End of file reached!
			break
		elif get_child_count() == 8: 
			# We only need the first 5 existing project files.
			# We say 8 because there is are 2 separators and a button present.
			break
		
		# Adding the recent projects button
		var button := Button.new()
		button.text = entry_data[0]
		button.tooltip_text = entry_data[1]
		button.icon = preload("res://assets/icons/video_file.png")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func():
			ProjectManager.load_project(entry_data[1])
			ScreenMain.instance.close_screen())
		add_child(button)
	
	if get_child_count() < 8:
		# Hiding the separator and the 'show all projects' button
		$Spacer2.visible = false
		$ShowAllProjectsButton.visible = false
