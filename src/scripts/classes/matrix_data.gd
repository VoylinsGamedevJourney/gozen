class_name MatrixData
extends Resource

enum MATRIX { NULL, TRANSFORM }
enum MATRIX_VAR { NULL, POSITION, SIZE, SCALE, ROTATION, PIVOT }


@export var type: MATRIX_VAR
@export var matrix: MATRIX



static func calculate_transform_matrix(pos: Vector2, scale: float, rotation: float, pivot: Vector2) -> PackedFloat32Array:
	#var scale_factor: float = scale / 100.0
	var transform: Transform2D = Transform2D.IDENTITY

	transform = transform.translated(pos) # move to position
	transform = transform.translated(pivot) # Move to pivot
	transform = transform.rotated(deg_to_rad(rotation))
	transform = transform.scaled(Vector2(scale, scale))
	transform = transform.translated(-pivot) # Move back from pivot
	transform = transform.affine_inverse() # Inverse the transform

	# Create mat4 usable data
	return PackedFloat32Array([
		transform.x.x,		transform.x.y,		0.0, 0.0,
		transform.y.x,		transform.y.y,		0.0, 0.0,
		0.0, 	   		 	0.0,				1.0, 0.0,
		transform.origin.x, transform.origin.y,	0.0, 1.0])


