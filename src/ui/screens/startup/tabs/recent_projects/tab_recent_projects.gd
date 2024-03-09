extends MarginContainer
## Tab Recent Projects - Startup screen
##
## Has some very basic functions to handle the recent projects tab and contains
## the code to load in the big Recent Projects list.


func _on_return_button_pressed() -> void:
	## Returning to the main tab when button is pressed.
	get_parent().current_tab = 0


func _on_visibility_changed() -> void:
	## This function does not need to update the recent projects file,
	## as this has been done already by recent_projects_small.gd in tab main.
	## We want to wait to load in the recent projects until we are certain
	## that recent_projects_small has cleaned up the code for us
	if !visible:
		return
	if %RecentProjectsVBox.get_child_count() != 0:
		return
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
		button.pressed.connect(func() -> void:
			ProjectManager.load_project(entry_data[1])
			ScreenMain.instance.close_startup())
		%RecentProjectsVBox.add_child(button)
