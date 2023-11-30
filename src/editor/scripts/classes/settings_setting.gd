class_name SettingsSetting extends Node

enum TYPE { BOOL, STRING, INT, FLOAT, LIST }


var setting_name: String
var setting_type
var setting_func
var setting_args


func _init(s_name: String, s_type: TYPE, s_func, s_args) -> void:
	setting_name = s_name
	setting_type = s_type
	setting_func = s_func
	setting_args = s_args
