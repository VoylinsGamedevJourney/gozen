extends Control


func _ready() -> void:
	# Setting minimum window size
	get_window().min_size = Vector2i(600,600)
#
#	# Adding modules
#	$VBox.add_child(ModuleManager.get_module("top_bar"))
#	var main_view := Control.new()
#	main_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
#	main_view.set_name("MainView")
#	$VBox.add_child(main_view)
#	main_view.add_child(ModuleManager.get_module("editor"))
#	main_view.add_child(ModuleManager.get_module("startup"))
#	main_view.add_child(ModuleManager.get_module("command_bar"))
#	$VBox.add_child(ModuleManager.get_module("status_bar"))


func _input(event: InputEvent) -> void:
	# Switch ZenMode Shortcut
	if event.is_action_pressed("switch_zen_mode"):
		SettingsManager.zen_mode = !SettingsManager.zen_mode
