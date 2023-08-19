extends StartupModule

# TODO: Include website URL, placeholder  = WebsiteLabel
# TODO: Add icons
# TODO: Change button style, stylebox empty but color on hover + click
# TODO: Changelog button, for this we need a changelog.md file as well


func _ready() -> void:
	# Check if opened with a "*.gozen" file as argument.
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if "*.gozen" in arg:
			# TODO: Load project info and close startup
			print("Not implemented yet!")
	
	
	var recent_projects: Array = Globals.recent_projects
	var example_button = %RecentProjectsVBox
	for path in recent_projects:
		var p_name := get_project_title(path)
		if p_name == "": continue
		var new_button := example_button.duplicate()
		new_button.text = p_name
		new_button.tooltip_text = path


func _on_image_credit_meta_clicked(meta) -> void:
	OS.shell_open(meta)


func _on_donate_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")


func _on_open_project_button_pressed() -> void:
	# TODO: Open file explorer
	# TODO: Add project on top of recent projects
	# TODO: Save recent projects
#	close_startup()
	pass # Replace with function body.


func _on_new_project_button_pressed(quality: int, horizontal: bool) -> void:
	var resolution: Vector2i
	if quality == 0:   resolution = Vector2i(1920, 1080) # 1080p
	elif quality == 1: resolution = Vector2i(3840, 2160) # 4K
	if horizontal: resolution = Vector2i(resolution.y, resolution.x)
	ProjectManager.resolution = resolution
	close_startup()


func _on_recent_project_button_pressed(project_path: String) -> void:
	if !ProjectManager.check_project_file(project_path): return
	ProjectManager.load_project(project_path)
	# TODO: Add project to top of recent projects
	# TODO: Save recent projects
	close_startup()
