extends StartupModule
## The Default Effects View Module
##
## Still WIP
##
## TODO: Include website URL, placeholder = WebsiteLabel
## TODO: Changelog button, for this we need a changelog.md file as well

var recent_projects: Array


func _ready() -> void:
	ProjectManager.get_recent_projects()
	
	# Check if opened with a "*.gozen" file as argument.
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if "*.gozen" in arg:
			ProjectManager.load_project(arg)
			queue_free()
	
	var button = %RecentProjectsVBox
	for path in ProjectManager.get_recent_projects():
		var p_name: String = str_to_var(FileManager.load_data(path)).title
		if p_name == "":
			continue
		var new_button := button.duplicate()
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
	queue_free()


## New project button
##
## Quality:
## - 0 = 1080p
## - 1 = 4K
## - 2 = 1080p size, but opens project settings (custom project)
func _on_new_project_button_pressed(quality: int, horizontal: bool) -> void:
	if quality == 0 or quality == 2:
		create_new_project(
				Vector2i(1080 if horizontal else 1920,1920 if horizontal else 1080))
	elif quality == 1:
		create_new_project(
				Vector2i(2160 if horizontal else 3840,3840 if horizontal else 2160))
	if quality == 2:
		ProjectManager._on_open_project_settings.emit()
	queue_free()


func _on_recent_project_button_pressed(project_path: String) -> void:
	if !ProjectManager.check_project_file(project_path): return
	ProjectManager.load_project(project_path)
	# TODO: Add project to top of recent projects
	# TODO: Save recent projects
	queue_free()


## New 1080p project horizontal
func _on_new_fhdh_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(1080,1920))
	queue_free()


# New 1080p project vertical
func _on_new_fhdv_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(1920,1080))
	queue_free()


## New 4K project horizontal
func _on_new_4kh_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(2160,3840))
	queue_free()


# New 4K project vertical
func _on_new_4kv_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(3840,2160))
	queue_free()


## New 1080p project horizontal, but opens in project manager
func _on_new_custom_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(1080,1920))
	# TODO: Open project manager
	queue_free()
