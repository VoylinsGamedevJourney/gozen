class_name ProjectBox
extends PanelContainer


signal _on_project_pressed(recent_id: int)


@export var title_label: Label
@export var creation_date_label: Label
@export var last_edited_date_label: Label
@export var path_label: Label


var recent_id: int = -1



func _on_gui_input(a_event:InputEvent) -> void:
	if a_event is InputEventMouseButton:
		var l_event: InputEventMouseButton = a_event
		if l_event.button_index == 0 and l_event.is_pressed():
			_on_project_pressed.emit(recent_id)


func _init(a_data: RecentProjectData) -> void:
	set_id(a_data.id)
	set_title(a_data.title)
	set_path(a_data.path)
	set_creation_date(a_data.creation_date)
	set_last_edited_date(a_data.last_edited)
	

func set_id(a_id: int) -> void:
	recent_id = a_id


func set_title(a_title: String) -> void:
	title_label.text = a_title
	title_label.tooltip_text = a_title


func set_creation_date(a_creation_date: String) -> void:
	creation_date_label.text = a_creation_date + "  Creation date"


func set_last_edited_date(a_last_edited_date: String) -> void:
	last_edited_date_label.text = a_last_edited_date + "  Last edited"


func set_path(a_path: String) -> void:
	path_label.text = "Path: " + a_path	
	path_label.tooltip_text = a_path

