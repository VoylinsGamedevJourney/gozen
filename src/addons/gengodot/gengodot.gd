@tool
extends EditorPlugin


const MAIN_PANEL := preload("res://addons/gengodot/gengodot.tscn")


var instance: Control


func _enter_tree() -> void:
	instance = MAIN_PANEL.instantiate()
	EditorInterface.get_editor_main_screen().add_child(instance)
	_make_visible(false) # NOTE: This is required!


func _exit_tree() -> void:
	if instance:
		instance.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible) -> void:
	if instance:
		instance.visible = visible


func _get_plugin_name() -> String:
	return "Localization"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Translation", "EditorIcons")
