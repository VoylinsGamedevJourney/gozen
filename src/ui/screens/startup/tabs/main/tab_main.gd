extends MarginContainer
## Tab main - Startup screen
## 
## First tab which people see when starting up GoZen. Contains links to
## different GoZen related resources and a way to open/create projects.


func _ready() -> void:
	_setup_recent_projects()


func _setup_recent_projects() -> void:
	## First we update/clean the recent projects file. After that we go
	## over the cleaned up entries and populate the list.
	## Each entry is made up like this: 'title||path||datetime'
	var file_path: String = ProjectSettings.get_setting("globals/path/recent_projects")
	if !FileAccess.file_exists(file_path):
		%RecentProjectsVBox.get_node("ShowAllProjectsButton").visible = false
		%RecentProjectsVBox.get_node("Spacer2").visible = false
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if FileAccess.get_open_error():
		Printer.error("Could not open recent projects file: '%s'!" % FileAccess.get_open_error())
		return
	var file_data: PackedStringArray = file.get_as_text().split('\n')
	var new_file_data: PackedStringArray = []
	var check_array: PackedStringArray = []
	# This is our clean up loop
	for entry: String in file_data:
		if entry == "":
			break
		var entry_data: PackedStringArray = entry.split('||')
		var entry_check: String = "%s||%s" % [entry_data[0], entry_data[1]]
		# Title+path will be the same, but date and time can be different
		if !check_array.has(entry_check) and FileAccess.file_exists(entry_data[1]):
			check_array.append(entry_check)
			new_file_data.append(entry)
		else:
			file_data.remove_at(file_data.find(entry))
	var new_data: String = ""
	for entry: String in new_file_data: 
		new_data += "%s\n" % entry
	file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(new_data)
	
	# Populating the short recent projects list
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		if entry_data.size() != 3:
			break # End of file reached!
		elif get_child_count() == 8: 
			# We only need the first five existing project files. Here we say
			# eight because there is are two separators and a button present.
			break
		# Adding the recent projects button
		var button := Button.new()
		button.text = entry_data[0]
		button.tooltip_text = entry_data[1]
		button.icon = preload("res://assets/icons/video_file.png")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void:
			ProjectManager.load_project(entry_data[1])
			ScreenMain.instance.close_startup())
		%RecentProjectsVBox.add_child(button)
	
	if get_child_count() < 8:
		# Hiding the separator and the 'show all projects' button
		%RecentProjectsVBox.get_node("ShowAllProjectsButton").visible = false
		%RecentProjectsVBox.get_node("Spacer2").visible = false
	else:
		move_child(%RecentProjectsVBox.get_node("ShowAllProjectsButton"), -1)
		move_child(%RecentProjectsVBox.get_node("Spacer2"), -1)



func _on_open_project_button_pressed() -> void:
	## Opens a file dialog which allows you to open up a GoZen project.
	var dialog := DialogManager.get_open_project_dialog()
	dialog.file_selected.connect(_file_selected)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,600))


func _file_selected(path: String) -> void:
	## Open file dialog's file_selected signal.
	if path.contains(".gozen"):
		ProjectManager.load_project(path)
		ScreenMain.instance.close_startup()
	else:
		Printer.error("Can't open project as path does not have '*.gozen' extension!")


func _on_show_all_projects_button_pressed() -> void:
	## Switching tab to the existing projects overview. 
	get_parent().current_tab = 1


func _on_create_project_button_pressed() -> void:
	## Opens the tab used for creating new projects on button press.
	get_parent().current_tab = 2
