extends Control

signal _show_project_manager
signal _start_project_loading


func _ready() -> void:

	var l_args: PackedStringArray = OS.get_cmdline_args()
	if l_args.size() < 1:
		_show_project_manager.emit()

	for l_arg: String in l_args:
		if !l_arg.ends_with(".gozen"):
			continue

		get_child(1).queue_free() # Remove the start screen and start loading

		RecentProjects.add_to_top(l_arg.split('/')[-1], l_arg)
		CoreLoader.append_to_front("Load data", Project.load_data.bind(l_arg))

		_start_project_loading.emit()
		return
	_show_project_manager.emit()

