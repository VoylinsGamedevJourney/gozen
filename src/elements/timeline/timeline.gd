extends PanelContainer

var empty_header := preload("res://elements/timeline/line_header/line_header.tscn")
var empty_data := preload("res://elements/timeline/line_data/line_data.tscn")


func _ready() -> void:
	# On startup, add an empty video line and an empty audio line
	add_line(Types.LINE_TYPE.VIDEO)
	add_line(Types.LINE_TYPE.AUDIO)


func add_line(type: Types.LINE_TYPE, line_name: String = "") -> void:
	var new_header: Node = empty_header.duplicate().instantiate()
	var new_data: Node = empty_data.duplicate().instantiate()
	
	# Changing the title of the line header
	if line_name == "":
		if type == Types.LINE_TYPE.VIDEO:   line_name = "video"
		elif type == Types.LINE_TYPE.AUDIO: line_name = "audio"
	new_header.change_title(line_name)
	
	%LineHeaders.add_child(new_header)
	%LineHeaders.move_child(new_header, 0)
	%LineDataHolders.add_child(new_data)
	%LineDataHolders.move_child(new_data, 0)
