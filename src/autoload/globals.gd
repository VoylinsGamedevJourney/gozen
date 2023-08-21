extends Label

# Editor signals
signal _on_open_project_settings
signal _on_open_settings

signal _on_window_mode_switch

# Settings signals
signal _on_zen_switch


# Recent project variables/functions
const PATH_RECENT_PROJECTS := "user://recent_projects"
var recent_projects: Array :
	set(x):
		recent_projects = x
		# Save file
		var file := FileAccess.open(PATH_RECENT_PROJECTS, FileAccess.WRITE)
		file.store_var(x)
	get:
		if !FileAccess.file_exists(PATH_RECENT_PROJECTS): return []
		var file := FileAccess.open(PATH_RECENT_PROJECTS, FileAccess.READ)
		return Array(file.get_var())
