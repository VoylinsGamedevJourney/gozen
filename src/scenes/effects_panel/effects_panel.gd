class_name EffectsPanel
extends PanelContainer


@export var button_video: Button
@export var button_sound: Button
@export var tab_container: TabContainer


var current_clip_id: int = -1



func _on_clip_erased(clip_id: int) -> void:
	if clip_id == current_clip_id:
		on_clip_pressed(-1)


func on_clip_pressed(id: int) -> void:
	var current_tab: int = tab_container.current_tab
	var type: FileHandler.TYPE = ClipHandler.get_clip_type(id)

	current_clip_id = id
	button_video.visible = type in EditorCore.VISUAL_TYPES
	button_sound.visible = type in EditorCore.AUDIO_TYPES

	# NOTE: It's either video of audio, if more tabs become available, this needs updating
	if ![button_video, button_sound][current_tab].visible:
		tab_container.current_tab = wrapi(current_tab + 1, 0, 1)


func _on_video_effects_button_pressed() -> void:
	tab_container.current_tab = 0
	_load_video_effects()


func _on_sound_effects_button_pressed() -> void:
	tab_container.current_tab = 1
	_load_sound_effects()


func _load_video_effects() -> void:
	pass


func _load_sound_effects() -> void:
	pass
