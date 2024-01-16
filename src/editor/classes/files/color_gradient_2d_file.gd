class_name ColorGradient2DFile extends DefaultFile

var offsets: PackedFloat32Array
var colors: PackedColorArray
var width: int
var height: int
var hdr: bool
var mode: Gradient.InterpolationMode
var fill: GradientTexture2D.Fill
var fill_from: Vector2
var fill_to: Vector2
var repeat: GradientTexture2D.Repeat


func get_data() -> Dictionary:
	vars.append("offsets")
	vars.append("colors")
	vars.append("width")
	vars.append("height")
	vars.append("hdr")
	vars.append("mode")
	vars.append("fill")
	vars.append("fill_from")
	vars.append("fill_to")
	vars.append("repeat")
	return super.get_data()
