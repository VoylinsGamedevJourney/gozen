class_name Toolbox extends Node


static func beautify_name(string: String) -> String:
	return string.replace('_', ' ').capitalize()
