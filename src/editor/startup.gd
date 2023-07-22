extends ColorRect

# TODO: When clicking on a project, move that entry
#       to the beginning of the array and save list.
# TODO: Option to open existing project (gets added to the list as well)
# TODO: Option to delete entry from the list (Adding a delete button on the right)


const PATH_PROJECTS_LIST := "user://projects.dat"

@onready var projects_vbox := find_child("ProjectsVBox")

var projects_list := [] # Each entry is an array [title, path]


func _ready() -> void:
	Global.update_project_list.connect(_update_projects_list)
	Global.add_projects_list_entry.connect(_add_projects_list_entry)
	Global.start_editing.connect(func(_x): queue_free())
	Global.show_startup_panel.connect(func(): self.visible = true)
	_update_projects_list()
	self.visible = true


func _update_projects_list() -> void:
	for child in projects_vbox.get_children(): child.queue_free()
	_load_projects_list()
	
	for project in projects_list: # Creating + adding buttons
		var new_button := Button.new()
		new_button.theme_type_variation = "ProjectButton"
		new_button.connect("pressed", _on_project_button_pressed.bind(project))
		new_button.text = project[0]
		new_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		projects_vbox.add_child(new_button)


func _add_projects_list_entry(project: Project) -> void:
	projects_list.push_front([project.title, project.path])
	_save_projects_list()


func _save_projects_list() -> void:
	var file := FileAccess.open(PATH_PROJECTS_LIST, FileAccess.WRITE)
	file.store_var(projects_list)


func _load_projects_list() -> void:
	projects_list = []
	if !FileAccess.file_exists(PATH_PROJECTS_LIST): return
	var file := FileAccess.open(PATH_PROJECTS_LIST, FileAccess.READ)
	projects_list = file.get_var()
	print(projects_list)


func _on_new_project_button_pressed() -> void:
	Global.show_new_project_panel.emit()
	self.visible = false


func _on_project_button_pressed(project_info: Array) -> void:
	# Project info is an array [title, path]
	if projects_list.find(project_info) != 0:
		projects_list.erase(project_info)
		projects_list.push_front(project_info)
	Global.start_editing.emit(project_info)
