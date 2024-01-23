class_name StartupRecentProjectsBig extends VBoxContainer
# This script does not need to update the recent projects file,
# as this has been done already by startup_recent_projects_small.gd


func load_list():
	if !FileAccess.file_exists(ProjectSettings.get_setting("globals/path/recent_projects")):
		return
	var file := FileAccess.open(
		ProjectSettings.get_setting("globals/path/recent_projects"), 
		FileAccess.READ)
	if file == null || FileAccess.get_open_error():
		Printer.error("Could not open recent projects file: '%s'!" % FileAccess.get_open_error())
		return
	# Each entry is made up like this: 'title||path||datetime'
	var file_data: PackedStringArray = file.get_as_text().split('\n')
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		if entry_data.size() != 3:
			# End of file reached!
			break
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = entry_data[0]
		button.tooltip_text = entry_data[1]
		button.icon = preload("res://assets/icons/video_file.png")
		button.pressed.connect(func():
			ProjectManager.load_project(entry_data[1])
			ScreenMain.instance.close_screen())
		add_child(button)
