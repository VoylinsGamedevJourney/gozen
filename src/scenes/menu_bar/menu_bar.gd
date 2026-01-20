extends HBoxContainer
# TODO: Make a submenu popup for recent projects and make it update when the recent projects list got updated
# TODO: Make the shortcut commands next to the action update when shortcuts got changed.
# TODO: Get the shortcuts from the settings to put next to the action item.
# TODO: Add Edit option with Undo/Redo buttons (maybe add cut/copy/paste/delete)
# Also add the options to import files here.
# TODO: Add an indicator (circle or rectangle in a color) on the right which indicates when ram
# usage is getting high or CPU usage is getting too high.

@export var popup_menu_project: PopupMenu



func _ready() -> void:
	_show_menu_bar(Settings.get_show_menu_bar())
	Settings.on_show_menu_bar_changed.connect(_show_menu_bar)


func _show_menu_bar(value: bool) -> void:
	visible = value


func _open_about_gozen() -> void:
	PopupManager.open_popup(PopupManager.POPUP.CREDITS)


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
		1: PopupManager.open_popup(PopupManager.POPUP.MODULE_MANAGER)
		# Line
		3: PopupManager.open_popup(PopupManager.POPUP.COMMAND_BAR)


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
		8: Utils.open_url("support")
		9: PopupManager.open_popup(PopupManager.POPUP.CREDITS)


func _set_shortcuts() -> void:
	pass


