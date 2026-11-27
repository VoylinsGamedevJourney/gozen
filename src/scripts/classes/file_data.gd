class_name FileData
extends Resource


@export var id: int
@export var path: String ## Temporary files start with "temp://".
@export var proxy_path: String
@export var modified_time: int = -1

@export var type: int = Type.EMPTY
@export var nickname: String
@export var folder: String = "/" ## Folder inside the editor.
@export var duration: int = -1

@export var text_effect: Effect = null ## For text clips only!

@export var ato_active: bool = false
@export var ato_offset: float
@export var ato_file: int

@export var audio_streams: Array[int] = []



#--- Data handlers ---

func serialize() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"path": path,
		"modified_time": modified_time,
		"type": type,
		"nickname": nickname,
		"duration": duration,
		"ato_active": ato_active,
		"ato_offset": ato_offset,
		"ato_file": ato_file}

	if !proxy_path.is_empty():
		data["proxy_path"] = proxy_path
	if folder != "/":
		data["folder"] = folder
	if !audio_streams.is_empty():
		data["audio_streams"] = audio_streams

	if text_effect:
		data["text_effect"] = text_effect.serialize()
	return data


func deserialize(data: Dictionary) -> void:
	id = data.get("id", -1)
	path = data.get("path", "")
	proxy_path = data.get("proxy_path", "")
	modified_time = data.get("modified_time", -1)
	type = data.get("type", Type.EMPTY) as int
	nickname = data.get("nickname", "")
	folder = data.get("folder", "/")
	duration = data.get("duration", -1)
	ato_active = data.get("ato_active", false)
	ato_offset = data.get("ato_offset", 0.0)
	ato_file = data.get("ato_file", -1)
	audio_streams.assign(data.get("audio_streams", []) as Array[int])

	if data.has("text_effect"):
		var text_effect_value: Variant = data["text_effect"]
		if text_effect_value is Effect:
			text_effect = text_effect_value
		else:
			text_effect = (load(Library.EFFECT_TEXT) as Effect).deep_copy()
			text_effect.deserialize(text_effect_value as Dictionary)

	if data.has("temp_file") and typeof(data["temp_file"]) == TYPE_DICTIONARY:
		_migrate_temp_file(data["temp_file"] as Dictionary)


## TempFile was a system which had been around since alpha/beta but got
## switched out during the last day's before v1.0 due to performance concerns.
func _migrate_temp_file(data: Dictionary) -> void:
	if data.has("text_effect"):
		var temp_text_effect: Variant = data["text_effect"]
		if temp_text_effect is Effect:
			text_effect = temp_text_effect
		else:
			text_effect = (load(Library.EFFECT_TEXT) as Effect).deep_copy()
			text_effect.deserialize(temp_text_effect as Dictionary)

	if (type == Type.COLOR or path.begins_with("temp://color")) and not path.contains("#") and data.has("color"):
		var color_value: Variant = data.get("color", Color.WHITE)
		var legacy_color: Color = Color(color_value as String) if typeof(color_value) == TYPE_STRING else (color_value as Color)
		path = "temp://color#" + legacy_color.to_html()

	if data.has("image_png"):
		var image_data: PackedByteArray = data["image_png"] as PackedByteArray
		var image: Image = Image.new()
		if image.load_png_from_buffer(image_data) == OK:
			path = FileLogic.save_pasted_image(image)
			if type == Type.EMPTY:
				type = Type.IMAGE
			modified_time = FileAccess.get_modified_time(path)
