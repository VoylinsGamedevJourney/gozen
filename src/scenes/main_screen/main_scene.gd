extends Control

# TODO: Window title
@export var window_title: Label
@export var side_panel_vbox: VBoxContainer
@export var side_panel_indicator: Panel
@export var main_tab_container: TabContainer
@export var top_bar_buttons: HBoxContainer
@export var resize_handles: Control



func _ready() -> void:
	var err: int = 0
	err += Project._on_title_changed.connect(_update_window_title)
	err += Project._on_project_saved.connect(_update_window_title)
	err += Project._on_changes_occurred.connect(_update_window_title)
	err += SettingsManager._on_window_moved.connect(_update_window_handles)
	err += SettingsManager._on_window_resized.connect(_update_window_handles)
	err += SettingsManager._on_window_mode_changed.connect(_update_window_handles)
	if err:
		printerr("Couldn't connect functions to project!")

	get_window().min_size = Vector2i(700, 500)
	if SettingsManager._tiling_wm:
		# Hiding buttons as tiling wm's don't need them
		top_bar_buttons.remove_child(top_bar_buttons.get_child(-2))
		top_bar_buttons.remove_child(top_bar_buttons.get_child(-2))
		resize_handles.queue_free()
	
	_update_window_handles()
	_load_layouts()


func _update_window_title() -> void:
	window_title.text = Project.title + (" " if !Project._unsaved_changes else "*")


func _update_window_handles() -> void:
	if !SettingsManager._tiling_wm:
		resize_handles.visible = get_window().mode == Window.MODE_WINDOWED


func _load_layouts() -> void:
	for l_layout_id: int in ModuleManager.layouts.size(): 
		var l_layout: Control = ModuleManager.get_layout_scene(l_layout_id).instantiate()
		main_tab_container.add_child(l_layout)

		var l_button: TextureButton = TextureButton.new()
		l_button.custom_minimum_size = Vector2i(30, 30)
		l_button.ignore_texture_size = true
		l_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		l_button.texture_normal = ModuleManager.get_layout_icon(l_layout_id)
		l_button.tooltip_text = ModuleManager.get_layout_title(l_layout_id)
		if l_button.pressed.connect(switch_layout.bind(l_layout_id)):
			printerr("Couldn't connect side panel button! ", l_layout_id)
		side_panel_vbox.add_child(l_button)



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

#------------------------------------------------ LAYOUT HANDLER
func switch_layout(l_id: int) -> void:
	if main_tab_container.current_tab == l_id:
		return

	var tween: Tween = get_tree().create_tween()
	var l_button: TextureButton = side_panel_vbox.get_child(l_id)
	if !tween.set_trans(Tween.TRANS_CIRC) or !tween.set_speed_scale(3):
		printerr("Something went wrong configuring tween!")
	if !tween.tween_property(side_panel_indicator, "position", Vector2(0., l_button.position.y), 0.4):
		printerr("Couldn't set tween property!")

	main_tab_container.current_tab = l_id

