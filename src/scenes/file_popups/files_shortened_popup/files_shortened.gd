extends Control
# Non re-linked files should be made tagged as "missing" but not deleted just
# in case, people can relink files manually.

signal confirmed


@export var vbox: VBoxContainer



## This is basically our _ready() for the popup.
func set_data(files: Array[FileData]) -> void:
	for file: FileData in files:
		var label: Label = Label.new()
		label.text = file.nickname + " (" + file.path + ")"
		label.tooltip_text = file.nickname + "\n(" + file.path + ")"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_FILL
		label.custom_minimum_size.x = 200
		vbox.add_child(label)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_shorten_button_pressed() -> void:
	confirmed.emit()
	_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close(PopupManager.FILES_SHORTENED)
