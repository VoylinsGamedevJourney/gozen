class_name MatrixData


enum TYPE { TRANSFORM }



func calculate_transform_matrix(data: Dictionary[String, Variant]) -> PackedFloat32Array:
	# First check if data has the needed params.
	var needed_params: PackedStringArray = ["position", "rotation", "size", "pivot"]
	for key: String in data.keys():
		if key not in needed_params:
			printerr("MatrixData: Transform: Key '%s' is missing from params!" % key)
			return []

	# Create transform
	var transform: Transform2D = Transform2D.IDENTITY
	var scale: Vector2 = data.size / Vector2(Project.get_resolution())
	var pos: Vector2 = data.position
	var piv: Vector2 = data.pivot
	var rot: float = data.rotation

	transform = transform.translated(pos) # move to position
	transform = transform.translated(piv) # Move to pivot
	transform = transform.rotated(deg_to_rad(rot))
	transform = transform.scaled(scale)
	transform = transform.translated(-piv) # Move back from pivot
	transform = transform.affine_inverse() # Inverse the transform

	# Create mat4 usable data
	return PackedFloat32Array([
		transform.x.x,		transform.x.y,		0.0, 0.0,
		transform.y.x,		transform.y.y,		0.0, 0.0,
		0.0, 	   		 	0.0,				1.0, 0.0,
		transform.origin.x, transform.origin.y,	0.0, 1.0])

