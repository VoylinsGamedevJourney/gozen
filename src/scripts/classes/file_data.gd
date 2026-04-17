class_name FileData
extends Resource


@export var id: int
@export var path: String ## Temporary files start with "temp://".
@export var proxy_path: String
@export var modified_time: int = -1

@export var type: EditorCore.TYPE = EditorCore.TYPE.EMPTY
@export var nickname: String
@export var folder: String = "/" ## Folder inside the editor.
@export var duration: int = -1

# These variables are specific to temp files & videos.
@export var temp_file: TempFile

@export var ato_active: bool = false
@export var ato_offset: float
@export var ato_file: int



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

	if temp_file:
		@warning_ignore("unsafe_method_access")
		data["temp_file"] = temp_file.serialize()
	return data


func deserialize(data: Dictionary) -> void:
	id = data.get("id", -1)
	path = data.get("path", "")
	proxy_path = data.get("proxy_path", "")
	modified_time = data.get("modified_time", -1)
	type = data.get("type", EditorCore.TYPE.EMPTY) as EditorCore.TYPE
	nickname = data.get("nickname", "")
	folder = data.get("folder", "/")
	duration = data.get("duration", -1)
	ato_active = data.get("ato_active", false)
	ato_offset = data.get("ato_offset", 0.0)
	ato_file = data.get("ato_file", -1)

	if data.has("temp_file"):
		var tempfile_value: Variant = data["temp_file"]
		if tempfile_value is TempFile:
			temp_file = tempfile_value
		else:
			temp_file = TempFile.new()
			temp_file.deserialize(tempfile_value as Dictionary)
