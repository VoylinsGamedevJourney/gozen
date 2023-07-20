extends Button

signal project_clicked(project_path)

var project: Project


func set_data(project_object: Project) -> void:
	project = project_object
	
	name = project.project_name
	find_child("ProjectNameLabel").text = project.project_name
	find_child("ProjectPathLabel").text = project.project_path
	
	var creation_label: Label = find_child("CreationLabel")
	var edit_label: Label = find_child("LastEditLabel")
	if project.project_creation == 0:
		creation_label.text = ""
		edit_label.text = ""
		return
	var creation_time := TimeManager.int_to_date(project.project_creation)
	var edit_time := TimeManager.int_to_date(project.project_edit)
	creation_label.text = "Created on: %s" % creation_time
	edit_label.text = "Edited on: %s" % edit_time


func _on_pressed() -> void:
	project_clicked.emit(project.project_path)
