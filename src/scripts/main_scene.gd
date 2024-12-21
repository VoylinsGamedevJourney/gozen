extends Control


func _ready() -> void:
	for l_arg: String in OS.get_cmdline_args():
		if l_arg.ends_with(".gozen"):
			# TODO: Load project with the path found
			break


func _on_project_id_pressed(a_id: int) -> void: ## Menu bar popup button
	match a_id:
		0: pass # Save current project
		1: pass # Save current project to new location
		2: pass # Load project
	# TODO: Add a load recent projects dropdown


func _on_help_id_pressed(a_id: int) -> void: ## Menu bar popup button
	match a_id:
		0: Utils.open_url("https://voylin.com/projects/gozen/")
		1: Utils.open_url("https://ko-fi.com/voylin")

