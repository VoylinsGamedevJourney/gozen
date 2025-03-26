extends Node


const PATH: String = "user://settings"


var data: SettingsData = SettingsData.new()



func _ready() -> void:
	if data.load_data(PATH) not in [OK, ERR_FILE_NOT_FOUND]:
		printerr("Something went wrong loading settings!")
	apply_theme()
	

func save() -> void:
	if data.save_data(PATH):
		printerr("Something went wrong saving settings!")


func reset_settings() -> void:
	data = SettingsData.new()


# Appearance set/get
func set_theme(a_theme: SettingsData.THEME) -> void:
	data.theme = a_theme
	apply_theme()


func apply_theme() -> void:
	match data.theme:
		SettingsData.THEME.DARK:
			get_tree().root.theme = null  # Default is dark
		SettingsData.THEME.LIGHT:
			get_tree().root.theme = load("uid://dxq4vg1l5rwhj")


func get_theme() -> SettingsData.THEME:
	return data.theme


# Defaults set/get
func set_image_duration(a_duration: int) -> void:
	data.image_duration = a_duration


func get_image_duration() -> int:
	return data.image_duration


func set_default_project_path(a_path: String) -> void:
	data.default_project_path = a_path


func get_default_project_path() -> String:
	return data.default_project_path


func set_default_resolution(a_res: Vector2i) -> void:
	data.default_resolution = a_res


func get_default_resolution() -> Vector2i:
	return data.default_resolution


func set_default_framerate(a_framerate: float) -> void:
	data.default_framerate = a_framerate
	

func get_default_framerate() -> float:
	return data.default_framerate

