extends Control


func _ready() -> void:
	add_child(ModuleManager.get_module("project_view"))
