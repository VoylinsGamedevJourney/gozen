extends Control
## Mainly for handling the window itself

var resizing: bool = false
var new_size: Vector2i = Vector2i.ZERO



func _ready() -> void:
	for l_arg: String in OS.get_cmdline_args():
		if l_arg.ends_with(".gozen"):
			# TODO: Load project with the path found
			break


func _process(_delta: float) -> void:
	if resizing:
		get_window().size = new_size


# 1 = Right, 2 = Bottom, 3 = Corner
func _on_resize_handle_gui_input(a_event: InputEvent, a_handle: int) -> void:
	if a_event is InputEventMouseButton and a_event.get("button_index") == 1:
		if !resizing and a_event.is_pressed():
			resizing = true
			new_size = get_window().size
		elif !a_event.is_pressed():
			resizing = false

	if resizing:
		# Right + corner handling
		if a_handle & 1:
			new_size.x = int(get_global_mouse_position().x)
		
		# Bottom + corner handling
		if a_handle & 2:
			new_size.y = int(get_global_mouse_position().y)

