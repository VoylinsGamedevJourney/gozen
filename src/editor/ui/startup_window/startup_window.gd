extends ModuleStartup


var explorer: FileDialog


func _ready() -> void:
	set_recent_projects()
	#open_editor()


func open_editor() -> void:
	get_window().always_on_top = false
	get_window().unresizable = false
	get_window().transparent = false
	get_window().mode = Window.MODE_MAXIMIZED


func set_recent_projects() -> void:
	var button: PackedScene = preload("res://ui/startup_window/recent_project_button.tscn")
	for path in ProjectManager.get_recent_projects():
		if !FileAccess.file_exists(path):
			print("No project file at path: %s!" % path)
			continue
		var p_name: String = str_to_var(FileManager.load_data(path)).title
		if p_name == "":
			continue
		var new_button: Button = button.duplicate().instantiate()
		new_button.text = path
		new_button.tooltip_text = path
		new_button.pressed.connect(_on_recent_project_button_pressed.bind(path))
		new_button.visible = true
		%RecentProjectsVBox.add_child(new_button)


func _on_exit_button_mouse_entered() -> void:
	$AnimationPlayer.play("show exit button")


func _on_exit_button_mouse_exited() -> void:
	$AnimationPlayer.play("hide exit button")


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_editor_image_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")


func _on_url_clicked(meta) -> void:
	OS.shell_open(meta)


func _on_donate_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")


func _on_open_project_button_pressed() -> void:
	explorer = FileDialog.new()
	explorer.popup_centered(Vector2i(300,300))
	# TODO: Make this work!
#	explorer = ModuleManager.get_selected_module("file_explorer")
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
