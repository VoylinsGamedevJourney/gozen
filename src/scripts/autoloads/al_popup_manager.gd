extends Node


enum POPUP { ADD_EDITOR_LAYOUT, BUG_REPORT, PROJECT_SETTINGS_MENU, SETTINGS_MENU }


const POPUP_PATH := "res://popups/{popup}/{popup}.tscn"


var popups := {
	POPUP.ADD_EDITOR_LAYOUT : { 
		string = "add_editor_layout", 
		instance = null},
	POPUP.BUG_REPORT : { 
		string = "bug_report", 
		instance = null},
	POPUP.PROJECT_SETTINGS_MENU : { 
		string = "project_settings_menu", 
		instance = null},
	POPUP.SETTINGS_MENU : { 
		string = "settings_menu", 
		instance = null}}


func open_popup(popup: POPUP) -> void:
	if popups[popup].instance == null:
		var instance: Window = load(POPUP_PATH.format({popup = popups[popup].string})).instantiate()
		get_tree().root.add_child(instance)
		popups[popup].instance = instance
	popups[popup].instance.popup()


func close_popup(popup: POPUP) -> void:
	popups[popup].instance.visible = false
