class_name EffectCache
extends RefCounted

var effect_name: String

var shader: RID
var pipeline: RID

var buffer: RID
var buffer_size: int



func initialize(device: RenderingDevice, spirv: RDShaderSPIRV, effect: VisualEffect) -> void:
	effect_name = effect.get_effect_name()
	shader = device.shader_create_from_spirv(spirv)
	pipeline = device.compute_pipeline_create(shader)

	var test_data: PackedByteArray = effect.get_buffer_data(0)

	buffer_size = test_data.size()
	buffer = device.uniform_buffer_create(buffer_size, test_data)


func update_buffer(device: RenderingDevice, effect: VisualEffect, frame_nr: int) -> void:
	var data: PackedByteArray = effect.get_buffer_data(frame_nr)

	if data.size() != buffer_size:
		printerr("EffectCache: Buffer size mismatch. Expected %s, got %s!" % [buffer_size, data.size()])
		return

	device.buffer_update(buffer, 0, buffer_size, data)


func free_rids(device: RenderingDevice) -> void:
	pipeline = Utils.cleanup_rid(device, pipeline)
	shader = Utils.cleanup_rid(device, shader)
	buffer = Utils.cleanup_rid(device, buffer)


func _to_string() -> String:
	return "<EffectCache:%s-%s>" % [effect_name, get_instance_id()]
