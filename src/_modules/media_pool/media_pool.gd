extends PanelContainer
# TODO: Handle global file data separately, maybe have a global media pool or something
# or find a better way of handling data11


var icon_folder := preload("res://assets/icons/folder.png")


func _on_project_tree_button_pressed() -> void:
	%ProjectScroll.visible = true
	%GlobalScroll.visible = false


func _on_global_tree_button_pressed() -> void:
	%ProjectScroll.visible = false
	%GlobalScroll.visible = true
