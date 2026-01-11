class_name VisualEffectColorCorrection
extends VisualEffect


const EFFECT_NAME: String = "visual_effect_color_correction"


var brightness: float = 0.0 # -1 to 1
var contrast: float = 1.0 # 0 to 3
var saturation: float = 1.0 # 0 to 3

var tint_color: Color = Color.BLACK
var tint_amount: float = 0.0 # 0 to 1
var red_value: float = 1.0 # 0 to 1
var green_value: float = 1.0 # 0 to 1
var blue_value: float = 1.0 # 0 to 1



func get_effect_name() -> String:
	return EFFECT_NAME


func get_effects_panel() -> Container:
	# TODO: Create the effects settings
	return Container.new()


func get_buffer_data(frame_nr: int) -> PackedByteArray:
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
	push_float(stream, current_contrast)
	push_float(stream, current_saturation)
	push_float(stream, current_tint_amount)
	push_float(stream, current_red_value)
	push_float(stream, current_green_value)
	push_float(stream, current_blue_value)

	return stream.data_array
