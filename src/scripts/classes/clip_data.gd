class_name ClipData
extends Resource


@export var id: int
@export var track: int
@export var type: EditorCore.TYPE

@export var file: int # File ID.

@export var start: int ## Frame_nr.
@export var begin: int ## Only for video and audio files.
@export var speed: float = 1.0 ## x times normal speed.
@export var duration: int

@export var effects: ClipEffects

@export var end: int: ## Should never be set.
		get: return start + duration



#--- Data handling ---

func serialize() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"track": track,
		"type": type,
		"file": file,
		"start": start,
		"duration": duration,
		"effects": effects.serialize() if effects else {}}

	if begin != 0:
		data["begin"] = begin
	if speed != 1.0:
		data["speed"] = speed

	return data


func deserialize(data: Dictionary) -> void:
	id = data.get("id", -1)
	track = data.get("track", 0)
	type = data.get("type", EditorCore.TYPE.EMPTY) as EditorCore.TYPE
	file = data.get("file", -1)
	start = data.get("start", 0)
	begin = data.get("begin", 0)
	speed = data.get("speed", 1.0)
	duration = data.get("duration", 1)

	effects = ClipEffects.new()
	if data.has("effects"):
		var effect_value: Variant = data["effects"]
		if effect_value is ClipEffects:
			effects = effect_value
		else:
			effects.deserialize(effect_value as Dictionary)
