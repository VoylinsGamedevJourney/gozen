class_name WindowResizeHandles extends Control

static var instance: WindowResizeHandles

var resizing: bool = false  ## Bool to check if currently resizing.
var resize_node: Control    ## Handle used for deciding how to resize.


func _ready() -> void:
	if instance != null:
		Printer.error("Can not have more than 1 instance of WindowResizeHandles!")
		get_tree().quit(-1)
		return
	instance = self
	get_window().min_size = Vector2i(700,600)
	
	$Right.gui_input.connect(_on_gui_input.bind($Right))
	$Bottom.gui_input.connect(_on_gui_input.bind($Bottom))
	$Corner.gui_input.connect(_on_gui_input.bind($Corner))


#region #####################  Resizing logic  #################################

func _on_gui_input(event: InputEvent, node: Control) -> void:
	if event is InputEventMouseButton and event.button_index == 1:
		if !resizing:
			resize_node = node
		resizing = event.is_pressed()


func _process(_delta: float) -> void:
	if resizing:
		var relative_mouse_pos = (
			DisplayServer.mouse_get_position()
			- DisplayServer.window_get_position(get_window().get_window_id())
		)
		if resize_node in [$Bottom, $Corner]:
			get_window().size.y = int(relative_mouse_pos.y)
		if resize_node in [$Right, $Corner]:
			get_window().size.x = int(relative_mouse_pos.x)

#endregion
