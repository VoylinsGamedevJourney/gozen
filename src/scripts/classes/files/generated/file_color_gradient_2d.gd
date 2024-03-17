class_name FileColorGradient2D extends File
# TODO: Option for saving certain gradient profiles for using in multiple projects

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
