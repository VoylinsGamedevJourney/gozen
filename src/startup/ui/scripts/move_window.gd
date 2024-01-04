extends TextureRect
## Moving window
##
## The logic which allows the window to be moved when dragging from the
## "WelcomeImage" node.


var move_window := false
var move_start: Vector2i


func _process(_delta: float) -> void:
	if move_window:
		var mouse_delta = Vector2i(get_viewport().get_mouse_position()) - move_start
		get_window().position += mouse_delta


func _on_welcome_image_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		if !move_window:
			move_start = get_viewport().get_mouse_position()
		move_window = event.is_pressed()
