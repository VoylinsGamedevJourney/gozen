extends TabBar


func _ready() -> void:
	add_child(ModuleManager.get_module("files"))
