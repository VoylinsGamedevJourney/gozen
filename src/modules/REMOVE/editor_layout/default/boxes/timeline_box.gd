extends Panel


func _ready() -> void:
	add_child(ModuleManager.get_module("timeline"))
