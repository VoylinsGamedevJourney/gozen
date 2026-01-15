extends Node

enum TYPE { TRANSFORM }



func get_transform_matrix_variables() -> PackedStringArray:
	return ["position", "rotation", "size", "pivot"]


func calculate_transform_matrix(data: Dictionary[String, Variant], resolution: Vector2) -> PackedFloat32Array:
	# First check if data has the needed params.
	for key: String in data.keys():
		if data[key] != null:
			continue

		printerr("MatrixHandler: Transform: Key '%s' is missing from params! %s" % [key, data[key]])
		match key: # Attempt on filling in some data to avoid crash.
			"size": data[key] = resolution
			"rotation": data[key] = 0
			_: data[key] = Vector2i(0, 0)

	# Create transform
	var transform: Transform2D = Transform2D.IDENTITY
	var scale: Vector2 = Vector2(data.size) / resolution
	var position: Vector2 = Vector2(data.position)
	var pivot: Vector2 = Vector2(data.pivot)
	var rotation: float = deg_to_rad(data.rotation)

	transform = transform.translated(position) # move to position
	transform = transform.translated(-pivot) # Move to pivot
	transform = transform.rotated(rotation)
	transform = transform.scaled(scale)
	transform = transform.translated(pivot) # Move back from pivot
	transform = transform.affine_inverse() # Inverse the transform

	# Create mat4 usable data
	return PackedFloat32Array([
		transform.x.x,		transform.x.y,		0.0, 0.0,
		transform.y.x,		transform.y.y,		0.0, 0.0,
		0.0, 	   		 	0.0,				1.0, 0.0,
		transform.origin.x, transform.origin.y,	0.0, 1.0])

