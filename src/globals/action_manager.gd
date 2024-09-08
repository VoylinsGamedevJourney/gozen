extends Node

var _enabled: bool = false


func _ready() -> void:
	GoZenServer.add_loadable(Loadable.new("Enabling ActionManager", func() -> void: _enabled = true))


func _input(a_event: InputEvent) -> void:
	if !_enabled:
		return

	if Input.is_action_pressed("save_project"):
		Project.save_data()
	if Input.is_action_pressed("fullscreen"):
		SettingsManager.change_window_mode(Window.MODE_FULLSCREEN)
