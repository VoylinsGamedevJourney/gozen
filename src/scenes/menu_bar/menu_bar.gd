extends HBoxContainer


@export var popup_menu_project: PopupMenu

# TODO: Make a submenu popup for recent projects and make it update when the recent projects list got updated
#4: menu_bar_project_recent_projects", Project.open_project, preload(Library.ICON_OPEN)),


func _ready() -> void:
	_show_menu_bar(Settings.get_show_menu_bar())
	Utils.connect_func(Settings.on_show_menu_bar_changed, _show_menu_bar)


func _show_menu_bar(value: bool) -> void:
	visible = value

#	_add_popup_menu("menu_bar_editor", [
#		MenuItem.new("menu_bar_editor_open_settings", Settings.open_settings_menu, preload(Library.ICON_PROJECT_SETTINGS)),
#		MenuItem.new("line"),
#		MenuItem.new("menu_bar_editor_open_url_site", Utils.open_url.bind("site"), preload(Library.ICON_LINK)),
#		MenuItem.new("menu_bar_editor_open_url_manual", Utils.open_url.bind("manual"), preload(Library.ICON_MANUAL)),
#		MenuItem.new("menu_bar_editor_open_url_tutorials", Utils.open_url.bind("tutorials"), preload(Library.ICON_TUTORIALS)),
#		MenuItem.new("menu_bar_editor_open_url_discord", Utils.open_url.bind("discord"), preload(Library.ICON_LINK)),
#		MenuItem.new("line"),
#		MenuItem.new("menu_bar_editor_open_url_support", Utils.open_url.bind("support"), preload(Library.ICON_SUPPORT)),
#		MenuItem.new("menu_bar_editor_open_about_gozen", _open_about_gozen, preload(Library.ICON_ABOUT_GOZEN)),
#	])


func _open_about_gozen() -> void:
	get_tree().root.add_child(preload(Library.SCENE_ABOUT_GOZEN).instantiate())


func _on_editor_screen_button_pressed() -> void:
	InputManager.show_editor_screen()


func _on_render_screen_button_pressed() -> void:
	InputManager.show_render_screen()


func _on_project_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Project.save()
		1: Project.save_as()
		# Line
		3: Project.open_project()
		4: PopupManager.open_popup(PopupManager.POPUP.RECENT_PROJECTS)
		# Line
		6: Project.open_settings_menu()
		# Line
		8: get_tree().quit()


func _on_preferences_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Settings.open_settings_menu()
		1: PopupManager.open_popup(PopupManager.POPUP.SHORTCUT_MANAGER)
		2: PopupManager.open_popup(PopupManager.POPUP.MODULE_MANAGER)
		# Line
		4: PopupManager.open_popup(PopupManager.POPUP.COMMAND_BAR)


func _on_help_popup_menu_id_pressed(id: int) -> void:
	match id:
		0: Utils.open_url("support")
		1: PopupManager.open_popup(PopupManager.POPUP.VERSION_CHECK)
		# Line
		3: Utils.open_url("manual")
		4: Utils.open_url("tutorials")
		5: Utils.open_url("discord")
		# Line
		7: Utils.open_url("site")
		8: PopupManager.open_popup(PopupManager.POPUP.CREDITS)
		9: Utils.open_url("support")

