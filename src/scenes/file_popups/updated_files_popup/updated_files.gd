extends Control
# Non re-linked files should be made tagged as "missing" but not deleted just
# in case, people can relink files manually.


@export var vbox: VBoxContainer



## This is basically our _ready() for the popup.
func set_data(file_names: Array[String]) -> void:
	for file_name: String in file_names:
		var label: Label = Label.new()
		label.text = file_name
		vbox.add_child(label)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.UPDATED_FILES)
