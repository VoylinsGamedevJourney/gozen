extends Control

enum { FILE, CLIP }


@export var title: Label


var type: int = -1


func _ready() -> void:
	GoZenServer.connect_err([
			GoZenServer._open_file_effects.connect(display_file_effects),
			GoZenServer._open_clip_effects.connect(display_clip_effects),
		], "Couldn't connect functions to default effects panel!")

	
func display_file_effects(a_file_id: int) -> void:
	var l_file: File = Project.files[a_file_id]
	title.text = "File effects for file: %s" % l_file.nickname
	type = FILE


func display_clip_effects(_clip_id: int) -> void:
	title.text = "Clip effects"
	type = CLIP


func clear() -> void:
	title.text = "Effects"
	type = -1


