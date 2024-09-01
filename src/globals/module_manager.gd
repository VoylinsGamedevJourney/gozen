extends Node

enum MENU {
	SETTINGS
}


var modules: Dictionary = {
	MENU.SETTINGS: "default"
}


func open_popup(menu: MENU) -> void:
	print(menu)
