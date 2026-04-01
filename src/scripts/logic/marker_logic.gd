extends Node
# TODO: Add a marker ripple (would probably need to link the marker with a
# specific clip for this to work correctly)

signal added(data: MarkerData)
signal updated(data: MarkerData)
signal removed(frame_nr: int)
signal moving


var dragged_marker: MarkerData = null
var dragged_marker_offset: float = 0:
	set(value):
		dragged_marker_offset = value
		moving.emit()

var markers: Array[MarkerData]



# --- Handling ---

func add(frame_nr: int, text: String, type: int) -> void:
	var marker_index: int = get_marker_index(frame_nr)
	if marker_index != -1:
		return update(frame_nr, text, type, markers[marker_index])

	InputManager.undo_redo.create_action("Add marker")
	InputManager.undo_redo.add_do_method(_add.bind(frame_nr, text, type))
	InputManager.undo_redo.add_undo_method(_remove.bind(frame_nr))
	InputManager.undo_redo.commit_action()


func _add(frame_nr: int, text: String, type: int) -> void:
	var marker_data: MarkerData = MarkerData.new()
	marker_data.frame_nr = frame_nr
	marker_data.text = text
	marker_data.type = type
	markers.append(marker_data)

	Project.unsaved_changes = true
	markers.sort_custom(_sort)
	added.emit(marker_data)


func update(frame_nr: int, text: String, type: int, marker: MarkerData = null) -> void:
	if marker == null:
		marker = get_marker(frame_nr)

	InputManager.undo_redo.create_action("Update marker")
	InputManager.undo_redo.add_do_method(_update.bind(frame_nr, text, type, marker))
	InputManager.undo_redo.add_undo_method(_update.bind(
			marker.frame_nr, marker.text, marker.type, marker))
	InputManager.undo_redo.commit_action()


func _update(frame_nr: int, text: String, type: int, marker: MarkerData) -> void:
	marker.frame_nr = frame_nr
	marker.text = text
	marker.type = type

	Project.unsaved_changes = true
	markers.sort_custom(_sort)
	updated.emit(marker)


func remove(frame_nr: int) -> void:
	var marker: MarkerData = get_marker(frame_nr)

	InputManager.undo_redo.create_action("Remove marker")
	InputManager.undo_redo.add_do_method(_remove.bind(frame_nr))
	InputManager.undo_redo.add_undo_method(_add.bind(frame_nr, marker.text, marker.type))
	InputManager.undo_redo.commit_action()


func _remove(frame_nr: int) -> void:
	markers.remove_at(get_marker_index(frame_nr))

	Project.unsaved_changes = true
	markers.sort_custom(_sort)
	removed.emit(frame_nr)


# --- Helper functions ---

func _find(marker: MarkerData, frame_nr: int) -> bool: return marker.frame_nr == frame_nr
func _sort(a: MarkerData, b: MarkerData) -> bool: return a.frame_nr < b.frame_nr


func get_marker_index(frame_nr: int) -> int:
	return markers.find_custom(_find.bind(frame_nr))


func get_marker(frame_nr: int) -> MarkerData:
	var index: int = get_marker_index(frame_nr)
	return markers[index] if index != -1 else null


func get_next(frame_nr: int) -> MarkerData:
	for marker_data: MarkerData in markers:
		if marker_data.frame_nr > frame_nr:
			return marker_data
	return null


func get_prev(frame_nr: int) -> MarkerData:
	var last_marker: MarkerData = null
	for marker_data: MarkerData in markers:
		if marker_data.frame_nr > frame_nr:
			return last_marker
		last_marker = marker_data
	return last_marker
