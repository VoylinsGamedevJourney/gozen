extends Panel


func _ready() -> void:
	get_window().set_title("GoZen - V: %s" % Global.VERSION)
	Global.start_editing.connect(open_project)


func open_project(project_info: Array) -> void:
	Global.project = Project.new()
	Global.project.load_data(project_info[1])
