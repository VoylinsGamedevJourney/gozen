class_name FileColorGradient extends File


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


func _init() -> void:
	type = FILE_COLOR_GRADIENT
	duration = SettingsManager.get_default_color_gradient_duration()


static func create(
		a_offsets: PackedFloat32Array,
		a_colors: PackedColorArray,
		a_width: int,
		a_height: int,
		a_hdr: bool,
		a_mode: Gradient.InterpolationMode,
		a_fill: GradientTexture2D.Fill,
		a_fill_from: Vector2,
		a_fill_to: Vector2,
		a_repeat: GradientTexture2D.Repeat) -> FileColorGradient:
	var l_file: FileColorGradient = FileColorGradient.new()
	l_file.offsets = a_offsets
	l_file.colors = a_colors
	l_file.width = a_width
	l_file.height = a_height
	l_file.hdr = a_hdr
	l_file.mode = a_mode
	l_file.fill = a_fill
	l_file.fill_from = a_fill_from
	l_file.fill_to = a_fill_to
	l_file.repeat = a_repeat
	return l_file
