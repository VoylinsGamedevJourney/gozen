class_name EffectsPanel
extends PanelContainer
# TODO: Add extra tab for text
# TODO: Deleting, adding, updating effects should be done through EffectsHandler


@export var button_video: Button
@export var button_sound: Button
@export var tab_container: TabContainer

@onready var video_container: VBoxContainer = tab_container.get_tab_control(0)
@onready var sound_container: VBoxContainer = tab_container.get_tab_control(1)

var current_clip_id: int = -1



func _ready() -> void:
	EditorCore.frame_changed.connect(_on_frame_changed)
	ClipHandler.clip_deleted.connect(_on_clip_erased)


func on_clip_pressed(id: int) -> void:
	current_clip_id = id

	if id == -1:
		for child: Node in video_container.get_children():
			video_container.remove_child(child)
		for child: Node in sound_container.get_children():
			sound_container.remove_child(child)

	var current_tab: int = tab_container.current_tab
	var type: FileHandler.TYPE = ClipHandler.get_clip_type(id)
	var is_visual: bool = type in EditorCore.VISUAL_TYPES
	var is_sound: bool = type not in EditorCore.AUDIO_TYPES

	button_video.disabled = !is_visual
	button_sound.disabled = !is_sound

	# NOTE: It's either video of audio, if more tabs become available, this needs updating
	if ![button_video, button_sound][current_tab].visible:
		tab_container.current_tab = wrapi(current_tab + 1, 0, 1)

	if is_visual:
		_load_video_effects()
	if is_sound:
		_load_sound_effects()


func _on_frame_changed() -> void:
	if current_clip_id != -1:
		_update_ui_values()


func _on_clip_erased(clip_id: int) -> void:
	if clip_id == current_clip_id:
		on_clip_pressed(-1)


func _on_video_effects_button_pressed() -> void:
	tab_container.current_tab = 0

	if current_clip_id != -1:
		_load_video_effects()


func _on_sound_effects_button_pressed() -> void:
	tab_container.current_tab = 1

	if current_clip_id != -1:
		_load_sound_effects()


func _load_video_effects() -> void:
	for child: Node in video_container.get_children():
		video_container.remove_child(child)

	if current_clip_id != -1:
		return

	for effect: VisualEffect in ClipHandler.get_clip(current_clip_id).effects_video:
		var container: FoldableContainer = _create_container(effect.effect_name)

		video_container.add_child(container)


func _load_sound_effects() -> void:
	for child: Node in sound_container.get_children():
		sound_container.remove_child(child)

	if current_clip_id != -1:
		return

	for effect: SoundEffect in ClipHandler.get_clip(current_clip_id).effects_sound:
		var container: FoldableContainer = _create_container(effect.effect_name)

		sound_container.add_child(container)


func _update_ui_values() -> void:
	pass


func _create_container(title: String) -> FoldableContainer:
	var container: FoldableContainer = FoldableContainer.new()

	container.title = title
	container.title_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var button_move_up: TextureButton = TextureButton.new()
	var button_move_down: TextureButton = TextureButton.new()
	var button_delete: TextureButton = TextureButton.new()

	button_move_up.custom_minimum_size.x = 20
	button_move_down.custom_minimum_size.x = 20
	button_delete.custom_minimum_size.x = 20

	# NOTE: We can add the position of the effect inside of the effect array
	# inside of the metadata and let the buttons check if they are at the top
	# or bottom to disable the correct buttons.

	container.add_title_bar_control(button_move_up)
	container.add_title_bar_control(button_move_down)
	container.add_title_bar_control(button_delete)

	return container
