@tool
extends EditorPlugin


const PANEL: PackedScene = preload("res://addons/honyaku/honyaku.tscn")
var instance



func _enter_tree():
	var setting_name: StringName = "localization/honyaku/ignored_paths"
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name,["res://addons/"])
		ProjectSettings.set_initial_value(setting_name, ["res://addons/"])
		ProjectSettings.add_property_info({
			"name": setting_name,
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_ARRAY_TYPE,
			"hint_string": "String"
		})

	instance = PANEL.instantiate()
	EditorInterface.get_editor_main_screen().add_child(instance)
	_make_visible(false)


func _exit_tree():
	if instance:
		instance.queue_free()


func _has_main_screen():
	return true


func _make_visible(visible):
	if instance:
		instance.visible = visible


func _get_plugin_name():
	return "Honyaku"


func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("Translation", "EditorIcons")
