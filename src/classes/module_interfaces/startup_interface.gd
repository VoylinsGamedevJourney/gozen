class_name StartupModule extends Node
## The Startup Module Interface
##
## Still WIP




func create_new_project(resolution: Vector2i) -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(resolution)


func close() -> void:
	queue_free()
