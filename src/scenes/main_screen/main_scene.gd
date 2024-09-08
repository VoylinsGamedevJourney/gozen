extends Control

# TODO: Window title
@export var window_title: Label
@export var side_panel_vbox: VBoxContainer
@export var main_tab_container: TabContainer

@export var top_bar_buttons: HBoxContainer





func _ready() -> void:
	var err: int = 0
	err += Project._on_title_changed.connect(_update_window_title)
	err += Project._on_project_saved.connect(_update_window_title)
	err += Project._on_changes_occurred.connect(_update_window_title)
	if err:
		printerr("Couldn't connect functions to project!")

	GoZenServer.add_loadable(Loadable.new("Initializing main panels", _load_main_panels))

	get_window().min_size = Vector2i(700, 500)
	if SettingsManager._tiling_wm:
		# Hiding buttons as tiling wm's don't need them
		top_bar_buttons.remove_child(top_bar_buttons.get_child(-2))
		top_bar_buttons.remove_child(top_bar_buttons.get_child(-2))
		



func _update_window_title() -> void:
	window_title.text = Project.title + (" " if !Project._unsaved_changes else "*")


func _load_main_panels() -> void:
	pass
#	for l_panel_id: int in ModuleManager.main_panels.size(): 
#		var l_panel: MainPanel = ModuleManager.main_panels[l_panel_id]
#		var l_button: TextureButton = TextureButton.new()
#		l_button.texture_normal = l_panel.icon
#		l_button.tooltip_text = l_panel.title
#		side_panel_vbox.add_child(l_button)
		#main_tab_container.add_child()


func _on_exit_button_pressed() -> void:
	if Project._unsaved_changes:
		var l_popup: PopupPanel = preload("res://scenes/main_screen/exit_popup.tscn").instantiate()
		add_child(l_popup)
		l_popup.popup_centered()
		return
	get_tree().quit()


func _on_maximize_button_pressed() -> void:
	SettingsManager.change_window_mode(Window.MODE_MAXIMIZED)


func _on_minimize_button_pressed() -> void:
	SettingsManager.change_window_mode(Window.MODE_MINIMIZED)


func _on_project_settings_button_pressed() -> void:
	ModuleManager.open_popup(ModuleManager.MENU.SETTINGS_PROJECT)


func _on_editor_settings_button_pressed() -> void:
	ModuleManager.open_popup(ModuleManager.MENU.SETTINGS_EDITOR)


func _on_main_menu_button_pressed() -> void:
	pass # Replace with function body.


#------------------------------------------------ WINDOW HANDLING
func _on_resize_handle_gui_input(a_event: InputEvent, a_side: int) -> void:
	if a_event is InputEventMouseButton:
		var l_event: InputEventMouseButton = a_event
		if l_event.is_pressed():
			SettingsManager._resize_node = a_side


func _on_top_bar_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton and get_window().mode == Window.MODE_WINDOWED:
		var l_event: InputEventMouseButton = a_event
		if l_event.is_pressed() and l_event.button_index == 1:
			SettingsManager._moving_window = true
			SettingsManager._move_offset = DisplayServer.mouse_get_position() -\
					DisplayServer.window_get_position(get_window().get_window_id())

