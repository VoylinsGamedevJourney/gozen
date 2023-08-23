class_name StartupModule extends Node
## The Startup Module Interface
##
## Still WIP

var recent_projects


func _init() -> void:
	recent_projects = ProjectManager.get_recent_projects()


func create_new_project(resolution: Vector2i) -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(resolution)


func close() -> void:
	queue_free()
