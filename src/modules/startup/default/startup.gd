extends Control
# TODO: Include website URL, placeholder = WebsiteLabel
# TODO: Changelog button, for this we need a changelog.md file as well

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
	return # TODO
	for path in ProjectManager.get_recent_projects():
		var p_name: String = str_to_var(FileManager.load_data(path)).title
		if p_name == "":
			continue
		var new_button := button.duplicate()
		new_button.text = p_name
		new_button.tooltip_text = path
		new_button.pressed.connect(_on_recent_project_button_pressed.bind(path))


func _on_url_clicked(meta) -> void:
	OS.shell_open(meta)


func _on_donate_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")


func _on_open_project_button_pressed() -> void:
	# TODO: Open file explorer
	# TODO: Add project on top of recent projects
	# TODO: Save recent projects
	queue_free()


func _on_recent_project_button_pressed(project_path: String) -> void:
	if !ProjectManager.check_project_file(project_path):
		return
	ProjectManager.load_project(project_path)
	# TODO: Add project to top of recent projects
	# TODO: Save recent projects
	queue_free()


# NEW PROJECT BUTTONS  #######################################

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
	ProjectManager._on_open_project_settings.emit()
	queue_free()
