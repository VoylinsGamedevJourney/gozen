extends Label

# Editor signals
signal _on_open_project_settings
signal _on_open_settings

signal _on_window_mode_switch

# Project signals
signal _on_project_title_change

signal _on_project_saved
signal _on_project_unsaved_changes

# Startup signals
signal _on_exit_startup

# Settings signals
signal _on_zen_switch


# Editor constants
const VERSION := "0.0.1-Alpha"

# Recent project variables/functions
const PATH_RECENT_PROJECTS := "user://recent_projects"
var recent_projects: Array :
	set(x):
		recent_projects = x
	get:
		return []
