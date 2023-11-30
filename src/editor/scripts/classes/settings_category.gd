class_name SettingsCategory extends Node

var category_name: String
var settings := []


func _init(cat_name: String) -> void:
	category_name = cat_name


func append(setting: SettingsSetting) -> void:
	settings.append(setting)
