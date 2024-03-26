extends Control


func _ready() -> void:
	var arguments := OS.get_cmdline_args()
	if arguments.size() == 2 and Toolbox.check_extension(arguments[1], ["gozen"]):
		ProjectManager.load_project(arguments[1].strip_edges())
		$Startup.queue_free()
	else: 
		$Startup.visible = true
