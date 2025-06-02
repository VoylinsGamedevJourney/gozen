class_name LoadingProjectOverlay
extends PanelContainer


@export var progress_bar: ProgressBar
@export var progress_hint: Label



func _ready() -> void:
	update_progress(0, "status_project_loading_init")


func update_progress(value: int, text: String) -> void:
	update_progress_bar(value)
	update_progress_hint(text)
	await RenderingServer.frame_post_draw


func update_progress_bar(value: int, wait_frame: bool = false) -> void:
	progress_bar.value = value
	if wait_frame:
		await RenderingServer.frame_post_draw


func update_progress_hint(text: String) -> void:
	progress_hint.text = tr(text)


func increment_progress_bar(value: float) -> void:
	progress_bar.value += value

