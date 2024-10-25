extends Control

signal _show_project_manager
signal _start_project_loading


func _ready() -> void:

	var l_args: PackedStringArray = OS.get_cmdline_args()
	if l_args.size() >= 1:
		for l_arg: String in l_args:
			if l_arg.ends_with(".gozen"):
				get_child(1).queue_free()
				var l_path: String = l_arg.trim_suffix(l_arg.split("/")[-1])
				RecentProjectsManager.add_project(l_path, l_arg.split("/")[-1].trim_suffix(".gozen"))

				var l_id: int = RecentProjectsManager.project_data.size() - 1

				CoreLoader.append_to_front("Opening project", Project.load_data.bind(RecentProjectsManager.project_data[l_id][0]))
				CoreLoader.append_to_front("Setting current project id", RecentProjectsManager.set_current_project_id.bind(l_id))

				_start_project_loading.emit()
				return
	_show_project_manager.emit()

