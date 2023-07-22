extends ColorRect

@onready var project_title_node := find_child("NewProjectTitleLineEdit")
@onready var project_path_node  := find_child("NewProjectPathLineEdit")


func _ready() -> void:
	Global.show_new_project_panel.connect(func(): visible = true)
	Global.start_editing.connect(func(): queue_free())
	self.visible = false


func _on_new_project_cancel_button_pressed() -> void:
	self.visible = false
	project_title_node.text = ""
	project_path_node.text = ""


func _on_new_project_create_button_pressed() -> void:
	self.visible = false
	if project_title_node.text.length() == 0:
		return printerr("A project title is needed!")
	if project_path_node.text.length() == 0:
		return printerr("A project path is needed!")
	
	var project := Project.new()
	project.new_project(project_title_node.text, project_path_node.text)
	
	var projects_list: Dictionary = {} 
	var file := FileAccess.open(Global.PATH_PROJECTS_LIST, FileAccess.READ)
	if file != null:
		projects_list = file.get_var()
	file = FileAccess.open(Global.PATH_PROJECTS_LIST, FileAccess.WRITE)
	projects_list[project.title] = project.path
	file.store_var(projects_list)
	Global.update_project_list.emit()

