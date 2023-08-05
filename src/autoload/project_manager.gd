extends Node


var title := "Untitled project": 
	set(new_title): 
		# TODO: Remove invalid chars
		# TODO: Change file path + file name
		title = new_title 
		Globals._on_project_title_change.emit()
var path: String # user://project_folder


func get_full_path() -> String:
	return "%s/%s.gozen" % [path, title]
