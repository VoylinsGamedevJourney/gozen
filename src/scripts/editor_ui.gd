extends Control


@export var menu_bar: MenuBar



func _ready() -> void:
	Editor.viewport = %ProjectViewSubViewport
	_show_menu_bar(Settings.get_show_menu_bar())

	Toolbox.connect_func(Settings.on_show_menu_bar_changed, _show_menu_bar)

	# Check if editor got opened with a project path as argument.
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower().ends_with(Project.EXTENSION):
			Project.open(arg)
			return

	# Showing Startup Screen
	add_child(preload("uid://bqlcn30hs8qp5").instantiate())
	

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

