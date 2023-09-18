extends Control
# Future TODO: Make version label clickable, bringing up a popup
#              which displays recent version changes (changelog of that version)


var recent_projects: Array
var explorer: Control


func _ready() -> void:
	
	ProjectManager.get_recent_projects()
	
	# Check if opened with a "*.gozen" file as argument.
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if "*.gozen" in arg:
			ProjectManager.load_project(arg)
			queue_free()
	
	var button = %RecentProjectsVBox.get_child(0)
	
	for path in ProjectManager.get_recent_projects():
		if %RecentProjectsVBox.get_child_count() > 6:
			break # We only want the 5 most recent projects to show
		if !FileAccess.file_exists(path):
			continue
		var p_name: String = str_to_var(FileManager.load_data(path)).title
		if p_name == "":
			continue
		var new_button := button.duplicate()
		new_button.text = path
		new_button.tooltip_text = path
		new_button.pressed.connect(_on_recent_project_button_pressed.bind(path))
		new_button.visible = true
		%RecentProjectsVBox.add_child(new_button)


func _on_url_clicked(meta) -> void:
	OS.shell_open(meta)


func _on_donate_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")


func _on_open_project_button_pressed() -> void:
	explorer = ModuleManager.get_selected_module("file_explorer")
	explorer.create("Save project", FileExplorer.MODE.SAVE_PROJECT)
	explorer._on_save_project_path_selected.connect(_on_open_project_file_selected)
	explorer._on_cancel_pressed.connect(_on_explorer_cancel_pressed)
	get_tree().current_scene.find_child("Content").add_child(explorer)
	explorer.open()


func _on_open_project_file_selected(path: String) -> void:
	ProjectManager.add_recent_project(path)
	ProjectManager.load_project(path)
	queue_free()


func _on_explorer_cancel_pressed() -> void:
	explorer.queue_free()
	explorer = null


func _on_recent_project_button_pressed(project_path: String) -> void:
	if !FileAccess.file_exists(project_path):
		return
	ProjectManager.load_project(project_path)
	ProjectManager.add_recent_project(project_path)
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
