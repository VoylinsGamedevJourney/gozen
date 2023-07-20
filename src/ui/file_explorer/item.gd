extends Button


func set_info(name_label: String, color: Color) -> void:
	find_child("NameLabel").text = name_label
	find_child("ColorRect").color = color
