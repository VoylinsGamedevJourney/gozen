extends PanelContainer


func change_title(new_title: String) -> void:
	get_node("MarginContainer/LineTitle").text = new_title
