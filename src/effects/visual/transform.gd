class_name VisualEffectTransform
extends VisualEffect

const EFFECT_NAME: String = "visual_effect_transform"


var position: Vector2i = Vector2i.ZERO
var size: Vector2 = Project.get_resolution()
var rotation: float = 0.0 # -360 to 360
var pivot: Vector2i = Project.get_resolution() / 2
var alpha: float = 1.0 # 0 to 1



func get_effect_name() -> String:
	return EFFECT_NAME


func get_effects_panel() -> Container:
	# TODO: Create the effects settings
	return Container.new()


func get_buffer_data(frame_nr: int) -> PackedByteArray:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()

	var current_position: Vector2i = get_value_at("position", position, frame_nr)
	var current_scale: Vector2 = Vector2(get_value_at("size", size, frame_nr)) / Vector2(Project.get_resolution())
	var current_rotation: float = get_value_at("rotation", rotation, frame_nr)
	var current_pivot: Vector2i = get_value_at("pivot", pivot, frame_nr)
	var current_alpha: float = get_value_at("alpha", alpha, frame_nr)

	var transform_matrix: PackedFloat32Array = calculate_transform_matrix(
			current_position, current_scale, current_rotation, current_pivot)

	# Shader params
	#layout(set = 0, binding = 2, std140) uniform Params {
	#layout(set = 0, binding = 2, std140) uniform Params {
	#	mat4 transform_matrix;	// Inverse transform matrix (offset = 0)
	#	float alpha;			// Alpha value (offset = 80)
	#} params; // Ends at byte 94 (/16 = 6 blocks - 12 bytes padding)

	push_mat4(stream, transform_matrix)
	push_float(stream, current_alpha)

	return stream.data_array


func calculate_transform_matrix(pos: Vector2, scale: Vector2, rot: float, piv: Vector2) -> PackedFloat32Array:
	#var scale_factor: float = scale / 100.0
	var transform: Transform2D = Transform2D.IDENTITY

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

