extends PanelContainer

enum STATE { PROJECT, GLOBAL }

var state: STATE
var icon_folder := preload("res://assets/icons/folder.png")


func _ready() -> void:
	# Starting with project files
	_on_switch_project_button_pressed()


#region #####################  Top area  #######################################

func _on_switch_project_button_pressed() -> void:
	$VBox/ProjectPanelScroll.visible = true
	$VBox/GlobalPanelScroll.visible = false
	state = STATE.PROJECT


func _on_switch_global_button_pressed() -> void:
	$VBox/ProjectPanelScroll.visible = false
	$VBox/GlobalPanelScroll.visible = true
	state = STATE.GLOBAL


func _on_search_line_edit_text_changed(_new_text: String) -> void:
	pass # TODO: Make this work (Just hide all files which don't include the search
	# word in the file name. All folders with all files hidden should also get hidden)

#endregion
