extends Control
## Startup Window

const GITHUB_RAW_URL := "https://raw.githubusercontent.com/VoylinsGamedevJourney/GoZen/master/%s"
const PATH_RECENT_PROJECTS: String = "user://recent_projects.dat"


# Bool to check if new projects are in landscape or portrait mode
var custom_project_landscape: bool = true


# Setting up the Startup Screen
func _ready() -> void:
	%ExitButton.modulate = Color("ffffff00")
	%UpdateAvailable.visible = false
	
	set_language()
	startup_argument_check() # Check if project got opened with an argument
	load_recent_projects()   # Populating recent projects lists
	check_version()          # Checking and setting version string


###############################################################
#region Input handler  ########################################
###############################################################

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("close_editor"):
		get_tree().quit()

#endregion
###############################################################
#region Startup logic  ########################################
###############################################################

func set_language() -> void:
	const PATH_SETTINGS := "user://settings.cfg"
	var locale := "en" # Default
	if FileAccess.file_exists(PATH_SETTINGS):
		var settings := ConfigFile.new()
		settings.load(PATH_SETTINGS)
		locale = settings.get_value("general", "language", locale)
	TranslationServer.set_locale(locale)


## Check if startup is opened with a path, else directly open the GoZen editor
func startup_argument_check() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_args()
	if arguments.size() == 2:
		if arguments[1].contains(".gozen"):
			open_editor(["--type=open", "--project_path=%s" % arguments[1]])
		else: printerr("No valid startup arguments were given!")


func check_version() -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_r, _rc, _h, body):
		var stable_version: String = body.get_string_from_utf8()
		if stable_version == "404: Not Found":
			# No internet
			return 
		elif stable_version != ProjectSettings.get_setting("application/config/version"):
			%UpdateAvailable.visible = true)
	var error := request.request(GITHUB_RAW_URL % "STABLE_VERSION")
	if error != OK:
		push_error("Error '%s' occurred in HTTP request!" % error)
	
	
	%VersionLabel.text = ProjectSettings.get_setting("application/config/version")


## Function to open the editor, also closes the startup menu
func open_editor(arg: PackedStringArray) -> void:
	if Engine.is_editor_hint(): # Editor check
		printerr("Running from Godot editor, can't start GoZen Editor!")
		get_tree().quit()
	
	# Getting executable path for editor
	var path : String = OS.get_executable_path().get_base_dir() + "/gozen_editor.%s"
	match OS.get_name():
		"Windows": path = path % "exe"
		"Linux":   path = path % "x86_64"
		"macOS":   path = path % "app"
	
	# Opens a new thread else startup menu can't close
	var thread := Thread.new()
	var x := func(): 
		OS.execute(path, [arg])
	thread.start(x)
	
	get_tree().quit()


## Loading the 5 most recently worked on projects
func load_recent_projects() -> void:
	if !FileAccess.file_exists(PATH_RECENT_PROJECTS):
		# Hiding the separator and the 'show all projects' button
		%RecentProjectsVBox.get_child(-1).visible = false
		%RecentProjectsVBox.get_child(-2).visible = false
		return
	
	# Updating the recent projects file and adding buttons
	var file_access := FileAccess.open(PATH_RECENT_PROJECTS, FileAccess.READ)
	if file_access.get_open_error():
		printerr("Error '%s' opening recent projects file!" % file_access.get_open_error())
		return
	var file_data: PackedStringArray = file_access.get_as_text().split('\n')
	var new_file_data: String = ""
	
	# Removing duplications in recent_projects file data
	var check_array: PackedStringArray = []
	# Each entry is made up like this: 'title||path||datetime'
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		var entry_check: String = "%s||%s" % [entry_data[0], entry_data[1]]
		# Title+path will be the same, but date and time can be different
		if !check_array.has(entry_check):
			check_array.append(entry_check)
		else:
			file_data.remove_at(file_data.find(entry))
	
	# Populating the short recent projects list
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		if entry_data.size() != 3: break # End of file reached!
		# If file does not exist, we do not need to go further
		if !FileAccess.file_exists(entry): continue 
		
		# We only need the first 5 existing project files.
		# We say 7 because there is a separator and a button present.
		if %RecentProjectsVBox.get_child_count() == 7: continue
		
		# Adding the recent projects button
		var button := Button.new()
		button.text = entry_data[0]
		button.tooltip_text = entry_data[1]
		button.icon = preload("res://assets/icons/video_file.png")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.connect("pressed", open_editor.bind(["--type=open", "--project_path=%s" % entry_data[1]]))
		%RecentProjectsVBox.add_child(button)
	
	if %RecentProjectsVBox.get_child_count() < 7:
		# Hiding the separator and the 'show all projects' button
		%RecentProjectsVBox.get_child(-1).visible = false
		%RecentProjectsVBox.get_child(-2).visible = false
	
	# Populating the full recent projects list
	for entry: String in file_data:
		var entry_data: PackedStringArray = entry.split('||')
		if entry_data.size() != 3: break # End of file reached!
		if FileAccess.file_exists(entry): 
			new_file_data += "%s\n" % entry
		else: continue # If file does not exist, we do not need to go further
		
		# Adding project button
		var button := Button.new()
		button.tooltip_text = entry_data[1]
		button.icon = preload("res://assets/icons/video_file.png")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.connect("pressed", open_editor.bind(["--type=open", "--project_path=%s" % entry_data[1]]))
		
		var title_label := Label.new()
		title_label.text = entry_data[0]
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var date_label := Label.new()
		date_label.text = entry_data[2]
		date_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		date_label.add_theme_color_override("font_color", Color.GRAY)
		
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(title_label)
		hbox.add_child(date_label)
		button.add_child(hbox)
		
		%AllProjectsVBox.add_child(button)
	file_access = FileAccess.open(PATH_RECENT_PROJECTS, FileAccess.WRITE)
	file_access.store_string(new_file_data)

#endregion
###############################################################
#region Welcome Image buttons  ################################
###############################################################

## Make link to image clickable
func _on_image_credit_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(meta)


## Make 'Update available!' notification clickable
func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(meta)


## Open the github page when editor button is pressed
func _on_editor_button_pressed() -> void:
	OS.shell_open("https://github.com/VoylinsGamedevJourney/GoZen")


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_exit_button_mouse_entered() -> void:
	$AnimationPlayer.play("show_exit_button")


func _on_exit_button_mouse_exited() -> void:
	$AnimationPlayer.play("hide_exit_button")

#endregion
###############################################################
#region Custom project  #######################################
###############################################################

func change_res(res: Vector2i) -> void:
	%SizeXSpinBox.value = res.x if custom_project_landscape else res.y
	%SizeYSpinBox.value = res.y if custom_project_landscape else res.x


func _on_horizontal_button_pressed() -> void:
	custom_project_landscape = true
	if %SizeYSpinBox.value > %SizeXSpinBox.value:
		var x: int = %SizeYSpinBox.value
		var y: int = %SizeXSpinBox.value
		%SizeYSpinBox.value = y
		%SizeXSpinBox.value = x


func _on_vertical_button_pressed() -> void:
	custom_project_landscape = false
	if %SizeYSpinBox.value < %SizeXSpinBox.value:
		var x: int = %SizeYSpinBox.value
		var y: int = %SizeXSpinBox.value
		%SizeYSpinBox.value = y
		%SizeXSpinBox.value = x


func _on_create_project_button_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.add_filter("*.gozen", "GoZen project")
	add_child(dialog)
	dialog.popup_centered(Vector2i(600,500))
	pass


func create_project(project_path: String) -> void:
	print(project_path)
	return
	print("Creating new project ...")
	var title: String = "%TitleLineEdit.text"
	if title == "":
		title = tr("TEXT_UNTITLED_PROJECT_TITLE")
	open_editor([
		"--type=new", 
		"--title=%s" % title, 
		"--project-path=%s" % project_path,
		"--resolution=%sx%s" % [%SizeXSpinBox.value, %SizeYSpinBox.value]])

#endregion
###############################################################
#region Open project explorer  ################################
###############################################################

func _on_open_project_button_pressed() -> void:
	# TODO: Change out the FileDialog to something more robust. (Native or custom)
	var explorer := FileDialog.new()
	explorer.title = tr("EXPLORER_OPEN_PROJECT")
	explorer.add_filter("*.gozen")
	explorer.show_hidden_files = true
	explorer.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	explorer.file_selected.connect(func(path):
			open_editor(["--type=open", "--project_path=%s" % path]))
	explorer.canceled.connect(func(): explorer.queue_free())
	add_child(explorer)
	explorer.popup_centered(Vector2i(600,500))

#endregion
###############################################################
#region Support button  #######################################
###############################################################

func _on_support_project_button_pressed() -> void:
	OS.shell_open("https://ko-fi.com/voylin")

#endregion
###############################################################
