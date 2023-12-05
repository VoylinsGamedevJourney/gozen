extends Control
## Startup Window
##
## This is the startup window for GoZen. Here you can select one of your
## previous projects or choose to create a new project with some basic
## presets. Not much logic going on for now.
##
## TODO: Change out the FileDialog to something more robust. (Native or custom)


var explorer : FileDialog


###############################################################
#region Basic logic  ##########################################
###############################################################

# Setting up the Startup Screen
func _ready() -> void:
	%VersionLabel.text = ProjectSettings.get_setting("application/config/version")
	load_recent_projects()


# Function to open the editor, also closes the startup menu
func open_editor(arg: PackedStringArray) -> void:
	# Editor check
	if Engine.is_editor_hint():
		print("Running from editor, can't start GoZen Editor")
		get_tree().quit()
	
	# Getting executable path for editor
	var path : String = OS.get_executable_path().get_base_dir()+  "/gozen_editor.%s"
	match OS.get_name():
		"Windows": path = path % "exe"
		"Linux":   path = path % "x86_64"
		_: 
			printerr("On this moment '%s' is not supported!" % OS.get_name())
			get_tree().quit()
	
	# Opens a new thread else startup menu can't close
	var thread := Thread.new()
	var x := func(): 
		OS.execute(path, [arg])
	thread.start(x)
	get_tree().quit()


# Loading the 5 most recently worked on projects
func load_recent_projects() -> void:
	const PATH: String = "user://recent_projects.dat"
	if !FileAccess.file_exists(PATH):
		print("No recent projects yet")
		return
	
	# Updating the recent projects file and adding buttons
	var file_access := FileAccess.open(PATH, FileAccess.READ)
	var file_data: PackedStringArray = file_access.get_as_text().split('\n')
	
	var new_file_data: String = ""
	
	# Making certain no duplicated are in recent_projects file data
	# each entry is made up like this: 'title||path||datetime'
	# Date and time may be different but title+path will be the same.
	var check_array: PackedStringArray
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		var entry_check: String = "%s||%s" % [entry_data[0], entry_data[1]]
		if !check_array.has(entry_check):
			check_array.append(entry_check)
		else:
			file_data.remove_at(file_data.find(entry))
	
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		if entry_data.size() != 3: break # End of file reached!
		if FileAccess.file_exists(entry):
			new_file_data += "%s\n" % entry
		else: continue # If file does not exist, we do not need to go further
		
		# We only need the first 5 existing project files, so we
		# skip the next part of adding a button can be "" = empty 
		# so we need to check for this
		if %RecentProjectsVBox.get_child_count() == 5: continue
		
		# Adding the recent projects button
		var button := Button.new()
		button.text = entry_data[0]
		button.tooltip_text = entry_data[1]
		button.icon = preload("res://assets/icons/video_file.png")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.connect("pressed", open_editor.bind(["--type=open", "--project_path=%s" % entry_data[1]]))
		%RecentProjectsVBox.add_child(button)
	
	file_access.open(PATH, FileAccess.WRITE)
	file_access.store_string(new_file_data)

#endregion
###############################################################
#region Upper area  ###########################################
###############################################################

# Make link to image clickable
func _on_image_credit_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(meta)


# Open the github page when editor button is pressed
func _on_editor_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")


# Close startup when exit is pressed
func _on_exit_button_pressed() -> void:
	get_tree().quit()


# Play show animation
func _on_exit_button_mouse_entered() -> void:
	$AnimationPlayer.play("show_exit_button")


# Play hide animation for exit button
func _on_exit_button_mouse_exited() -> void:
	$AnimationPlayer.play("hide_exit_button")

#endregion
###############################################################
#region Bottom area  ##########################################
###############################################################

func _on_new_fhd_button_pressed(horizontal: bool) -> void:
	if horizontal: open_editor(["--type=new", "--title=%s" % tr("UNTITLED_PROJECT_TITLE"), "--resolution=1920x1080"])
	else:          open_editor(["--type=new", "--title=%s" % tr("UNTITLED_PROJECT_TITLE"), "--resolution=1080x1920"])


func _on_new_4k_button_pressed(horizontal: bool) -> void:
	if horizontal: open_editor(["--type=new", "--title=%s" % tr("UNTITLED_PROJECT_TITLE"), "--resolution=1920x1080"])
	else:          open_editor(["--type=new", "--title=%s" % tr("UNTITLED_PROJECT_TITLE"), "--resolution=1080x1920"])


func _on_new_custom_button_pressed() -> void:
	$NewCustomWindow.visible = true


func _on_open_project_button_pressed() -> void:
	explorer = FileDialog.new()
	explorer.title = tr("EXPLORER_OPEN_PROJECT")
	explorer.add_filter("*.gozen")
	explorer.show_hidden_files = true
	explorer.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	explorer.file_selected.connect(_on_open_project_file_selected)
	explorer.canceled.connect(_on_open_project_cancel)
	add_child(explorer)
	explorer.popup_centered(Vector2i(600,500))


func _on_support_project_button_pressed() -> void:
	OS.shell_open("https://ko-fi.com/voylin")

#endregion
###############################################################
#region Custom project  #######################################
###############################################################

func _on_new_custom_cancel_button_pressed() -> void:
	%NewProjectTitleLineEdit.text = ""
	%XSpinBox.value = 1920
	%YSpinBox.value = 1080
	$NewCustomWindow.visible = false


func _on_new_custom_confirm_button_pressed() -> void:
	var title: String = %NewProjectTitleLineEdit.text
	if title == "":
		title = tr("UNTITLED_PROJECT_TITLE")
	open_editor(["--type=new", "--title=%s" % title, "--resolution=%sx%s" % [%XSpinBox.value, %YSpinBox.value]])

#endregion
###############################################################
#region Open project explorer  ###############################
###############################################################

func _on_open_project_cancel() -> void:
	explorer.queue_free()


func _on_open_project_file_selected(path: String) -> void:
	open_editor(["--type=open", "--project_path=%s" % path])

#endregion
###############################################################
