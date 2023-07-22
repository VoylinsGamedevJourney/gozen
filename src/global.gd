extends Node

# Editor
signal start_editing(project)

# StartUp window
signal show_startup_panel
signal update_project_list
signal add_projects_list_entry(project)

# NewProject window
signal show_new_project_panel


const VERSION := "0.0.1-Alpha"

var project : Project
