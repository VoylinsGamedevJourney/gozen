class_name EditorUI
extends Control


static var instance: EditorUI


@export var menu_bar: MenuBar



func _ready() -> void:
	instance = self
	print_startup_info()

	EditorCore.viewport = %ProjectViewSubViewport
	_show_menu_bar(Settings.get_show_menu_bar())

	PhysicsServer2D.set_active(false)
	PhysicsServer3D.set_active(false)
	Toolbox.connect_func(Settings.on_show_menu_bar_changed, _show_menu_bar)

	# Check if editor got opened with a project path as argument.
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower().ends_with(Project.EXTENSION):
			Project.open(arg)
			return

	# Showing Startup Screen
	add_child(preload("uid://bqlcn30hs8qp5").instantiate())
	

func print_startup_info() -> void:
	var header: Callable = (func(text: String) -> void:
			print_rich("[color=purple][b]", text))
	var info: Callable = (func(title: String, context: Variant) -> void:
			print_rich("[color=purple][b]", title, "[/b]: [color=gray]", context))

	header.call("--==  GoZen - Video Editor  ==--")
	info.call("GoZen Version", ProjectSettings.get_setting("application/config/version"))
	info.call("OS", OS.get_model_name())
	info.call("OS Version", OS.get_version())
	info.call("Distribution", OS.get_distribution_name())
	info.call("Processor", OS.get_processor_name())
	info.call("Threads", OS.get_processor_count())
	info.call("Ram", "\n\tTotal: %s GB\n\tAvailable: %s GB" % [
				  	str("%0.2f" % (OS.get_memory_info().physical/1_073_741_824)), 
				  	str("%0.2f" % (OS.get_memory_info().available/1_073_741_824))])
	info.call("Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
				  	RenderingServer.get_video_adapter_name(),
				  	RenderingServer.get_video_adapter_api_version(),
				  	RenderingServer.get_video_adapter_type()])
	info.call("Locale", OS.get_locale())
	info.call("Startup args", OS.get_cmdline_args())
	header.call("--==--================--==--")


func _show_menu_bar(value: bool) -> void:
	if menu_bar != null:
		menu_bar.visible = value


func _on_menu_bar_project_id_pressed(id: int) -> void:
	match id:
		0: # Save
			Project.save()
		1: # Save as
			Project.save_as()
		2: # Load
			Project.open_project()
		4: # Open project settings
			add_child(preload("uid://d1h5tylky47rt").instantiate())
		5: # Open render menu
			add_child(preload("uid://chdpurqhtqieq").instantiate())


func _on_menu_bar_editor_id_pressed(id: int) -> void:
	match id:
		0: # Open settings
			add_child(preload("uid://bjen0oagwidr7").instantiate())
		2: # Open GoZen site
			Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/site")))
		3: # Open manual
			Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/manual")))
		4: # Open tutorials
			Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/tutorials")))
		5: # Open Discord server
			Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/discord")))
		7: # Support GoZen
			Toolbox.open_url(str(ProjectSettings.get_setting_with_override("urls/support")))
		8: # Open "about GoZen" popup
			add_child(preload("uid://d4e5ndtm65ok3").instantiate())

