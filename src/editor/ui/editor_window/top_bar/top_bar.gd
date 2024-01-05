extends PanelContainer
## TopBar
##
## Shortcuts to the settings and project settings menu are here,
## including buttons to change the window mode. The top bar also
## makes it possible to move the window around.
##
## TODO: Make icon open a menu to see about, donation page, changelog, ...
## TODO: Don't show save popup when no new changes have been made
## TODO: Display a star next to project title when there are 0unsaved changes


var move_window := false
var move_start: Vector2i


func _ready() -> void:
	ProjectManager._on_title_changed.connect(_on_project_title_changed)
	ProjectManager._on_unsaved_changes.connect(_on_project_unsaved_changes)
	ProjectManager._on_project_saved.connect(_on_project_changes_saved)
	
	check_zen(SettingsManager.get_zen_mode())
	SettingsManager._on_zen_switched.connect(check_zen)

###############################################################
#region Window title  #########################################
###############################################################

func _on_project_title_changed(new_title: String) -> void:
	%WindowTitle.text = new_title


func _on_project_unsaved_changes() -> void:
	if %WindowTitle.text[-1] != "*":
		%WindowTitle.text = ProjectManager.title + "*"


func _on_project_changes_saved() -> void:
	%WindowTitle.text = ProjectManager.title

#endregion
###############################################################
#region Move window logic  ####################################
###############################################################

func _process(_delta: float) -> void:
	if move_window:
		var mouse_delta = Vector2i(get_viewport().get_mouse_position()) - move_start
		get_window().position += mouse_delta


## Window has flag borderless so we can have a custom top bar
## this puts our custom top bar in charge of creating the moving 
## logic by ourselves.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		if !move_window:
			move_start = get_viewport().get_mouse_position()
		move_window = event.is_pressed()

#endregion
###############################################################
#region Zen logic  ############################################
###############################################################

func check_zen(value: bool) -> void:
	$HBox/ExitButton.visible = !value
	$HBox/MinimizeButton.visible = !value
	$HBox/SwitchModeButton.visible = !value

#endregion
###############################################################
#region Button logic  #########################################
###############################################################

## At this moment points to the github page, will be changed to
## more usefull stuff later on.
func _on_editor_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")


## Opens the project settings popup.
func _on_project_button_pressed() -> void:
	get_tree().root.add_child(
			preload("res://ui/popup_project_settings/PopupProjectSettings.tscn").instantiate())


## Opens the settings popup.
func _on_settings_button_pressed() -> void:
	get_tree().root.add_child(
			preload("res://ui/popup_settings/PopupSettings.tscn").instantiate())


## Minimizes the window if possible, 
## does nothing for tiling window managers such as i3.
func _on_minimize_button_pressed() -> void:
	get_window().set_mode(Window.MODE_MINIMIZED)
	SettingsManager._on_window_mode_switch.emit()


## Switches between window mode and fullscreen mode,
## preferably the window shoud stay in fullscreen.
func _on_switch_mode_button_pressed() -> void:
	match get_window().mode:
		Window.MODE_WINDOWED:   get_window().set_mode(Window.MODE_FULLSCREEN)
		Window.MODE_FULLSCREEN: get_window().set_mode(Window.MODE_WINDOWED)
	SettingsManager._on_window_mode_switch.emit()


## Exiting the program will ask if you want to save the project.
## This will change in the future to only show the popup when
## unsaved changes have been made
func _on_exit_button_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.canceled.connect(func(): get_tree().quit())
	dialog.confirmed.connect(func():
			ProjectManager.save_project()
			get_tree().quit())
	dialog.ok_button_text = "Save"
	dialog.cancel_button_text = "Don't save"
	dialog.borderless = true
	dialog.dialog_text = tr("POPUP_EXIT_SAVE_TEXT")
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_exit_button_pressed()

#endregion
###############################################################
