class_name ColorGradient1DFile extends DefaultFile

var offsets: PackedFloat32Array
var colors: PackedColorArray
var width: int
var hdr: bool # Default should be false
var mode: Gradient.InterpolationMode # Default should be GRADIENT_INTERPOLATE_LINEAR


func get_data() -> Dictionary:
	vars.append("offsets")
	vars.append("colors")
	vars.append("width")
	vars.append("hdr")
	vars.append("mode")
	return super.get_data()
