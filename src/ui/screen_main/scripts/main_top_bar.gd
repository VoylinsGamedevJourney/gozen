extends PanelContainer

var move_window := false
var move_start: Vector2i


func _ready() -> void:
	$Margin/HBox/ProjectButton.visible = false
	ProjectManager._on_project_loaded.connect(func(): 
		$Margin/HBox/ProjectButton.visible = true)


###############################################################
#region Window Dragging  ######################################
###############################################################

func _on_top_bar_dragging(event):
	if event is InputEventMouseButton and event.button_index == 1:
		if !move_window:
			move_start = get_viewport().get_mouse_position()
		move_window = event.is_pressed()


func _process(_delta: float) -> void:
	if move_window:
		var mouse_delta = Vector2i(get_viewport().get_mouse_position()) - move_start
		get_window().position += mouse_delta

#endregion
###############################################################
#region Top Bar Window Buttons  ###############################
###############################################################

func _on_minimize_button_pressed():
	get_window().set_mode(Window.MODE_MINIMIZED)


func _on_switch_mode_button_pressed():
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().set_mode(Window.MODE_FULLSCREEN)
	elif get_window().mode == Window.MODE_FULLSCREEN:
		get_window().set_mode(Window.MODE_WINDOWED)


func _on_exit_button_pressed():
	if ProjectManager.project_path == "":
		get_tree().quit()
		return
	var dialog := ConfirmationDialog.new()
	dialog.canceled.connect(func(): get_tree().quit())
	dialog.confirmed.connect(func():
			ProjectManager.save_project()
			get_tree().quit())
	dialog.ok_button_text = tr("DIALOG_TEXT_SAVE")
	dialog.cancel_button_text = tr("DIALOG_TEXT_DONT_SAVE")
	dialog.borderless = true
	dialog.dialog_text = tr("DIALOG_TEXT_ON_EXIT")
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

#endregion
###############################################################
#region Top Bar Setting Buttons  ##############################
###############################################################

func _on_project_button_pressed():
	ScreenMain.instance.show_screen(ScreenMain.SCREENS.PROJECT_SETTINGS)


func _on_settings_button_pressed():
	ScreenMain.instance.show_screen(ScreenMain.SCREENS.SETTINGS)

#endregion
###############################################################
