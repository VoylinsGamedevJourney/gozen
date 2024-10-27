extends Node


signal _on_track_added
signal _on_track_removed(id: int)

signal _open_clip_effects(id: int)



func add_track() -> void:
	Project._add_track()
	_on_track_added.emit()


func remove_track(a_id: int) -> void:
	Project._remove_track(a_id)
	_on_track_removed.emit(a_id)


func add_clip(a_file_id: int, a_pts: int, a_track_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._add_clip(a_file_id, a_pts, a_track_id)


func remove_clip(a_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._remove_clip(a_id)


func resize_clip(a_id: int, a_duration: int, a_left: bool) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._resize_clip(a_id, a_duration, a_left)


func open_clip_effects(a_id: int) -> void:
	_open_clip_effects.emit(a_id)

