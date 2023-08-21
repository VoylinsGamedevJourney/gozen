extends Label


# Editor signals
signal _on_open_project_settings
signal _on_open_settings

signal _on_window_mode_switch

# Project signals
signal _on_project_title_change
signal _on_project_resolution_change

signal _on_project_saved
signal _on_project_unsaved_changes

# Startup signals
signal _on_exit_startup

# Settings signals
signal _on_zen_switch


# Editor constants
signal _on_version_string_change(new_string)
signal _on_version_update_available
var version_string := "0.0.0":
	set(x): 
		version_string = x
		_on_version_string_change.emit(version_string)


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
