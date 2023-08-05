extends VBoxContainer


func _ready() -> void:
	add_child(ModuleManager.get_module("top_bar"))
	var main_view := Control.new()
	main_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_view.set_name("MainView")
	add_child(main_view)
	main_view.add_child(ModuleManager.get_module("editor"))
	main_view.add_child(ModuleManager.get_module("startup"))
	main_view.add_child(ModuleManager.get_module("command_bar"))
	add_child(ModuleManager.get_module("status_bar"))
