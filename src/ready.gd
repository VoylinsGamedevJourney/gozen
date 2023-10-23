extends Control

func _ready() -> void:
	get_tree().change_scene_to_file(ModuleManager.get_selected_module_path("main_window"))
