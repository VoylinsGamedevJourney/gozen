class_name DataHandler
extends Node

static func get_class_data(class_object: Node) -> Dictionary:
	var data := {}
	for x in class_object.get_property_list():
		if x.usage == 4096:
			data[x.name] = class_object.get(x.name)
	return data


static func set_class_data(empty_class:Node, class_object: Node) -> Node:
	var new_class := empty_class.duplicate()
	for x in class_object.get_property_list():
		if class_object.get(x.name) != null:
			new_class.set(x.name, class_object[x.name])
	return new_class
