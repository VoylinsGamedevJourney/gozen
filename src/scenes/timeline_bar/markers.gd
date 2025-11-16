extends Control


var markers: Dictionary [int, Button] = {}



func _on_project_ready() -> void:
	var project_markers: Dictionary[int, MarkerData] = Project.get_markers()

	for frame_nr: int in project_markers:
		_on_marker_added(frame_nr, project_markers[frame_nr])


func _on_marker_added(frame_nr: int, marker: MarkerData) -> void:
	if frame_nr in markers:
		printerr("Adding marker in postition of different marker! Switching to update marker...")
		_on_marker_updated(frame_nr, frame_nr, marker)
		return

	markers[frame_nr] = preload(Library.BUTTON_MARKER).instantiate()
	markers[frame_nr].text = marker.text
	add_child(markers[frame_nr])


func _on_marker_updated(old_frame_nr: int, new_frame_nr: int, marker: MarkerData) -> void:
	var button: Button = markers[old_frame_nr]

	if markers.erase(old_frame_nr):
		Print.erase_error()

	markers[new_frame_nr] = button
	button.text = marker.text


func _on_marker_removed(frame_nr: int) -> void:
	markers[frame_nr].queue_free()

	if markers.erase(frame_nr):
		Print.erase_error()

