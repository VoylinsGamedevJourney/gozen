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
var background: PanelContainer = preload(Library.SCENE_POPUP_BACKGROUND).instantiate()



func _ready() -> void:
	add_child(background)
	background.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		for popup: POPUP in open_popups.keys():
			close_popup(popup)
	elif event.is_action_pressed("help"):
		show_popup(POPUP.CREDITS)

	if open_popups.size() == 0:
		background.visible = false


func show_popup(popup: POPUP) -> void:
	if popup in open_popups:
		return

	open_popups[popup] = (load(popup_uids[popup]) as PackedScene).instantiate()
	
	match popup:
		POPUP.SETTINGS: (open_popups[popup] as SettingsPanel).set_mode_project_settings()
		POPUP.PROJECT_SETTINGS: (open_popups[popup] as SettingsPanel).set_mode_project_settings()

	add_child(open_popups[popup])
	background.visible = true



func close_popup(popup: POPUP) -> void:
	if !open_popups.has(popup):
		printerr("Popup with id '%s' not open!" % popup)
	else:
		open_popups[popup].queue_free()

		if open_popups.erase(popup):
			printerr("Could not erase popup '%s' from open_popups!" % popup)


func get_popup(popup: POPUP) -> Control:
	if !open_popups.has(popup):	
		show_popup(popup)

	return open_popups[popup]

