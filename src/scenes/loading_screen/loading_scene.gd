extends Control

@export var loading_text_label: Label
@export var version_label: Label
@export var timer: Timer



func start_loading() -> void:
	var l_editor_scene: Control = preload("res://scenes/main_screen/main_scene.tscn").instantiate()

	l_editor_scene.visible = false
	get_parent().add_child(l_editor_scene)
	version_label.text = "Version: %s " % ProjectSettings.get_setting("application/config/version")

	await _loading_cycle(GoZenServer.loadables)
	GoZenServer.loadables = [] # Cleanup of memory
	timer.start(0.5)
	await timer.timeout

	await _loading_cycle(GoZenServer.after_loadables)
	GoZenServer.after_loadables = [] # Cleanup of memory
	GoZenServer.loaded = true
	loading_text_label.text = "Finalizing ..."
	timer.start(0.5)
	await timer.timeout

	self.visible = false
	get_viewport().get_window().unresizable = false
	SettingsManager.change_window_mode(Window.MODE_MAXIMIZED)

	if SettingsManager._tiling_wm:
		_disable_floating_for_tiling_wm()

	l_editor_scene.visible = true
	self.queue_free()


func _loading_cycle(a_array: Array[Loadable]) -> void:
	for l_loadable: Loadable in a_array:
		loading_text_label.text = "%s..." % l_loadable.info_text

		timer.start(0.1)
		await l_loadable.function.call()

		if !timer.is_stopped():
			await timer.timeout


func _disable_floating_for_tiling_wm() -> void:
	get_window().grab_focus()
	match SettingsManager.get_wm_name():
		"i3":
			if OS.execute("i3-msg", ["floating", "disable"]):
				printerr("Error occured when making non floating on i3!")


func _on_meta_clicked(a_meta: String) -> void:
	if OS.shell_open(a_meta):
		printerr("Error opening url! ", a_meta)


func _on_texture_rect_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton and get_window().mode == Window.MODE_WINDOWED:
		var l_event: InputEventMouseButton = a_event

		if l_event.is_pressed() and l_event.button_index == 1:
			SettingsManager._moving_window = true
			SettingsManager._move_offset = DisplayServer.mouse_get_position() -\
					DisplayServer.window_get_position(get_window().get_window_id())

