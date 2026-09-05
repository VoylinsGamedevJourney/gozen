@tool
class_name Icon
extends ImageTexture

# TODO: Implement custom assets path: Settings.get_theme().get_constant_list()
#		This function can be used on the `icons` theme setting. If empty, we use
#		the default list, if not empty, it is the path. We replace the svg_path
#		only if there is a replacement of that asset file, else we use the
#		default paths. Kind of "hacky", but probably the best way.
#		The asset folder inside of the module should be identical with identical
#		naming so we can replace the icons ... but this TODO is for later in
#		development as I can't be bothered to spend any more time on this now.
#		Or we use GoZenModuleTheme to define a different icons path? Probably
#		better and less hacky.


const BASE_SVG_COLOR: Color = Color.WHITE
# Main theme: #808080
# Light theme: #000000
# Dark theme: #ffffff


@export_file("*.svg") var base_svg_path: String: set = set_base
@export var is_static: bool = false: set = set_static ## For SVG's which should not change color!

@export_file("*.svg") var svg_path: String: set = set_svg



func _init() -> void:
	call_deferred("_setup")


func _setup() -> void:
	if not Engine.is_editor_hint():
		if not Settings.on_theme_updated.is_connected(_update_texture):
			if Settings.on_theme_updated.connect(_update_texture): Print.stack_connect()


func _update_texture() -> void:
	if base_svg_path.is_empty():
		return push_error("Icon: No svg set for '%s'!" % self)

	var file: FileAccess
	var svg_text: String
	var temp_image: Image = Image.new()
	var target_color: Color = BASE_SVG_COLOR

	if svg_path.is_empty() or !FileAccess.file_exists(svg_path):
		file = FileAccess.open(base_svg_path.trim_suffix(".remap"), FileAccess.READ)
	else:
		file = FileAccess.open(svg_path.trim_suffix(".remap"), FileAccess.READ)
	svg_text = file.get_as_text()
	file.close()

	if Settings and Settings.has_method("get_theme") and !Engine.is_editor_hint(): # Due to loading stuff on startup.
		if Settings.get_theme().has_color("color", "icons"):
			target_color = Settings.get_theme().get_color("color", "icons")

	if !is_static and BASE_SVG_COLOR != target_color:
		svg_text = svg_text.replace(BASE_SVG_COLOR.to_html(false), target_color.to_html(false))

	if temp_image.load_svg_from_string(svg_text) != OK:
		printerr("Couldn't load svg from string!")

	if get_width() == 0: set_image(temp_image)
	else: update(temp_image)
	emit_changed()


func set_base(value: String) -> void:
	if base_svg_path != value:
		base_svg_path = value
		_update_texture()


func set_static(value: bool) -> void:
	if is_static != value:
		is_static = value
		_update_texture()


func set_svg(value: String) -> void:
	if svg_path != value:
		svg_path = value
		_update_texture()
