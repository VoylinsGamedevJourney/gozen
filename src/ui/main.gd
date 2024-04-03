extends Control


func _ready() -> void:
	if OS.get_cmdline_args().size() == 2 and Toolbox.check_extension(OS.get_cmdline_args()[1], ["gozen"]):
		ProjectManager.load_project(OS.get_cmdline_args()[1].strip_edges())
		$Startup.queue_free()
	else: 
		$Startup.visible = true
