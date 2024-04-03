class_name FileColorGradient1D extends File
# TODO: Option for saving certain gradient profiles for using in multiple projects

var offsets: PackedFloat32Array
var colors: PackedColorArray
var width: int
var hdr: bool # Default should be false
var mode: Gradient.InterpolationMode # Default should be GRADIENT_INTERPOLATE_LINEAR


func _init() -> void:
	type = TYPE.COLOR_GRADIENT_1D
	duration = 120 # TODO: Make possible to change default
