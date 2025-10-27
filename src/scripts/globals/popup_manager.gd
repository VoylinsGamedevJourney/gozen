extends Node


enum POPUP {
	SETTINGS,
	PROJECT_SETTINGS,
	CREDITS,
	COLOR,
	MARKER,
	PROGRESS,
	COMMAND_BAR,
}


var open_popups: Dictionary [POPUP, Control] = {}
var popup_uids: Dictionary [POPUP, String] = {
	POPUP.SETTINGS: Library.SCENE_SETTINGS,
	POPUP.PROJECT_SETTINGS: Library.SCENE_SETTINGS,
	POPUP.CREDITS: Library.SCENE_ABOUT_GOZEN,
	POPUP.COLOR: Library.SCENE_COLOR_PICKER_DIALOG,
	POPUP.MARKER: Library.SCENE_MARKER_DIALOG,
	POPUP.PROGRESS: Library.SCENE_PROGRESS_OVERLAY,
	POPUP.COMMAND_BAR: Library.SCENE_COMMAND_BAR,
}
var non_closeable: Array[POPUP] = [
	
]
var control: Control = Control.new()
var background: PanelContainer = preload(Library.SCENE_POPUP_BACKGROUND).instantiate()



func _ready() -> void:
	Toolbox.connect_func(get_window().size_changed, _on_size_changed)

	await get_tree().root.ready
	get_tree().root.add_child(control)
	control.add_child(background)
	control.visible = false
	control.top_level = true
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		for popup: POPUP in open_popups.keys():
			close_popup(popup)
	elif event.is_action_pressed("help"):
		show_popup(POPUP.CREDITS)

	_check_background()


func show_popup(popup: POPUP) -> void:
	if popup in open_popups:
		return

	open_popups[popup] = (load(popup_uids[popup]) as PackedScene).instantiate()
	
	match popup:
		POPUP.SETTINGS: (open_popups[popup] as SettingsPanel).set_mode_editor_settings()
		POPUP.PROJECT_SETTINGS: (open_popups[popup] as SettingsPanel).set_mode_project_settings()

	control.add_child(open_popups[popup])
	control.visible = true


func close_popup(popup: POPUP) -> void:
	if !open_popups.has(popup):
		printerr("Popup with id '%s' not open!" % popup)
	else:
		open_popups[popup].queue_free()

		if !open_popups.erase(popup):
			printerr("Could not erase popup '%s' from open_popups!" % popup)

	_check_background()


func close_popups() -> void:
	for popup: POPUP in open_popups:
		open_popups[popup].queue_free()

		if !open_popups.erase(popup):
			printerr("Could not erase popup '%s' from open_popups!" % popup)

	_check_background()


func get_popup(popup: POPUP) -> Control:
	if !open_popups.has(popup):	
		show_popup(popup)

	return open_popups[popup]


func _on_size_changed() -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _check_background() -> void:
	if open_popups.size() == 0:
		control.visible = false

