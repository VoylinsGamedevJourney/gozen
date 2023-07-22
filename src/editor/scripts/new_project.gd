extends ColorRect

@onready var project_title_node := find_child("NewProjectTitleLineEdit")
@onready var project_path_node  := find_child("NewProjectPathLineEdit")


func _ready() -> void:
	Global.show_new_project_panel.connect(func(): visible = true)
	Global.start_editing.connect(func(_x): queue_free())
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
	Global.add_projects_list_entry.emit(project)
	Global.start_editing.emit(project)

