extends Control


# TODO: Create an indicator to see on what tab you are on

@export var tab_container: TabContainer
@export var tab_recent_projects: VBoxContainer
@export var tab_all_projects: VBoxContainer



func _ready() -> void:
	# TODO: Load up all recent projects
	# Recent projects has space for the 6 most recent projects
	var l_recent_projects: Array[RecentProjectData] = RecentProjectsManager.get_data()
	for l_data: RecentProjectData in l_recent_projects:
		var l_project_box: ProjectBox = ProjectBox.new(l_data)
		if l_project_box._on_project_pressed.connect(_on_project_pressed):
			printerr("Couldn't connect _on_project_pressed!")
		if tab_recent_projects.get_child_count() < 6:
			tab_recent_projects.add_child(l_project_box.duplicate())
		tab_all_projects.add_child(l_project_box)



func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_recent_projects_button_pressed() -> void:
	tab_container.current_tab = 0


func _on_new_project_button_pressed() -> void:
	tab_container.current_tab = 1


func _on_all_projects_button_pressed() -> void:
	tab_container.current_tab = 2


func _on_settings_button_pressed() -> void:
	ModuleManager.open_popup(ModuleManager.MENU.SETTINGS)


func _on_support_button_pressed() -> void:
	if OS.shell_open("https://ko-fi.com/voylin"):
		printerr("Something went wrong opening support url!")


func _on_project_pressed(a_id: int) -> void:
	# TODO: Change to make this work with the load screen scene
	RecentProjectsManager.set_current_project_id(a_id)
	GoZenServer.add_loadable(Loadable.new(
			"Opening project", ProjectManager.load.bind(RecentProjectsManager.project_data[a_id][0]), 0.5))


