extends Button

signal project_clicked(project_entry)

var project_entry: ProjectManagerInterface.ProjectListEntry


func set_data(project_entry_: ProjectManagerInterface.ProjectListEntry) -> void:
	self.project_entry = project_entry_
	var p_name: String = project_entry.p_name
	var p_path: String = project_entry.p_path
	var p_creation: int = project_entry.p_creation
	var p_edit: int = project_entry.p_edit
	
	var p_name_label     : Label = find_child("ProjectNameLabel")
	var p_path_label     : Label = find_child("ProjectPathLabel")
	var p_creation_label : Label = find_child("ProjectCreationDateLabel")
	var p_edit_label     : Label = find_child("ProjectEditDateLabel")
	
	name = p_name
	
	p_name_label.text = p_name
	p_path_label.text = p_path
	
	if p_creation == 0:
		p_creation_label.text = ""
		p_edit_label.text = ""
		return
	
	p_creation_label.text = "Created on: %s" % project_entry.int_to_date(p_creation)
	p_edit_label.text = "Edited on: %s" % project_entry.int_to_date(p_edit)


func _on_pressed() -> void:
	emit_signal("project_clicked", project_entry)
