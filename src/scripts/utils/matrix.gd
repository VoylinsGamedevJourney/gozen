class_name Matrix
extends Node


enum TYPE { TRANSFORM }



static func get_transform_matrix_variables() -> Array[String]:
	return ["position", "rotation", "scale", "pivot"]


static func calculate_transform_matrix(data: Dictionary[String, Variant]) -> PackedFloat32Array:
	# First check if data has the needed params.
	for key: String in data.keys():
		if data[key] != null:
			continue

		printerr("MatrixHandler: Transform: Key '%s' is missing from params! %s" % [key, data[key]])
		match key: # Rough attempt on filling in some data to avoid crash.
			"scale": data[key] = Vector2(1.0, 1.0)
			"rotation": data[key] = 0
			_: data[key] = Vector2i(0, 0)

	# Create transform.
	var pivot: Vector2 = data.pivot
	var transform: Transform2D = Transform2D.IDENTITY
	transform = transform.translated(-pivot) # Move to pivot.
	transform = transform.scaled(data.scale as Vector2)
	transform = transform.rotated(deg_to_rad(data.rotation as float))
	transform = transform.translated(pivot) # Move back from pivot.
	transform = transform.translated(data.position as Vector2) # Move to position.
	transform = transform.affine_inverse() # Inverse the transform.

	# Create mat4 usable data.
	return PackedFloat32Array([
		transform.x.x,		transform.x.y,		0.0, 0.0,
		transform.y.x,		transform.y.y,		0.0, 0.0,
		0.0, 	   		 	0.0,				1.0, 0.0,
		transform.origin.x, transform.origin.y,	0.0, 1.0])
