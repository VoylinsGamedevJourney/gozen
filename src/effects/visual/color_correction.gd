class_name VisualEffectColorCorrection
extends VisualEffect



@export_range(-1, 1) var brightness: float = 0.0
@export_range(0, 3) var contrast: float = 1.0
@export_range(0, 3) var saturation: float = 1.0
@export var tint_color: Color = Color.BLACK
@export_range(0, 1) var tint_amount: float = 0.0
@export_range(0, 1) var red_value: float = 1.0
@export_range(0, 1) var green_value: float = 1.0
@export_range(0, 1) var blue_value: float = 1.0


func get_shader_rid() -> RID:
	return load("res://effects/visual/color_correction.glsl").get_spirv()


func get_effects_panel() -> Container:
	# TODO: Create the effects settings
	return Container.new()


func get_buffer_data(frame_nr: int, context_data: Dictionary) -> PackedByteArray:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()

	var current_brightness: float = get_value_at("brightness", brightness, frame_nr)
	var current_contrast: float = get_value_at("contrast", contrast, frame_nr)
	var current_saturation: float = get_value_at("saturation", saturation, frame_nr)
	var current_tint_color: Color = get_value_at("tint_color", tint_color, frame_nr)
	var current_tint_amount: float = get_value_at("tint_amount", tint_amount, frame_nr)
	var current_red_value: float = get_value_at("red_value", red_value, frame_nr)
	var current_green_value: float = get_value_at("green_value", green_value, frame_nr)
	var current_blue_value: float = get_value_at("blue_value", blue_value, frame_nr)

	# Shader params
	#layout(set = 0, binding = 2, std140) uniform Params {
	#    vec4 tint;
	#    float brightness;
	#    float contrast;
	#    float saturation;
	#    float tint_amount;
	#    float red_value;
	#    float green_value;
	#    float blue_value;
	#} params;
	
	push_color(stream, current_tint_color)
	push_float(stream, current_brightness)
	push_float(stream, contrast)
	push_float(stream, saturation)
	push_float(stream, tint_amount)
	push_float(stream, red_value)
	push_float(stream, green_value)
	push_float(stream, blue_value)

	return stream.data_array
