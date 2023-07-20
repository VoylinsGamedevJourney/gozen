extends Button

signal project_clicked(project_path)

var dic: Dictionary


func set_data(project_dic: Dictionary) -> void:
	dic = project_dic
	
	var p_name_label     : Label = find_child("ProjectNameLabel")
	var p_path_label     : Label = find_child("ProjectPathLabel")
	var p_creation_label : Label = find_child("CreationLabel")
	var p_edit_label     : Label = find_child("LastEditLabel")
	
	name = project_dic.p_name
	
	p_name_label.text = project_dic.p_name
	p_path_label.text = project_dic.p_path
	
	if project_dic.p_creation == 0:
		p_creation_label.text = ""
		p_edit_label.text = ""
		return
	
	p_creation_label.text = "Created on: %s" % TimeManager.int_to_date(project_dic.p_creation)
	p_edit_label.text = "Edited on: %s" % TimeManager.int_to_date(project_dic.p_edit)


func _on_pressed() -> void:
	project_clicked.emit(dic.p_path)
