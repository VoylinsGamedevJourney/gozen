class_name MarkerLogic
extends RefCounted
# TODO: Add a marker ripple (would probably need to link the marker with a
# specific clip for this to work correctly)

signal added(index: int)
signal updated(index: int)
signal removed(index: int)
signal moving


var dragged_marker: int = -1
var dragged_marker_offset: float = 0:
	set(value):
		dragged_marker_offset = value
		moving.emit()

var project_data: ProjectData


# --- Main ---

func _init(data: ProjectData) -> void:
	project_data = data


# --- Handling ---

func add(frame_nr: int, text: String, type: int) -> void:
	var index: int = project_data.markers_frame.find(frame_nr)
	if index != -1:
		return update(index, frame_nr, text, type)

	InputManager.undo_redo.create_action("Add marker")
	InputManager.undo_redo.add_do_method(_add.bind(frame_nr, text, type))
	InputManager.undo_redo.add_undo_method(_remove.bind(frame_nr))
	InputManager.undo_redo.commit_action()
	index = project_data.markers_frame.size()


func _add(frame_nr: int, text: String, type: int) -> void:
	var index: int = project_data.markers_frame.size()

	project_data.markers_frame.append(frame_nr)
	project_data.markers_text.append(text)
	project_data.markers_type.append(type)
	Project.unsaved_changes = true
	added.emit(index)


func update(index: int, frame_nr: int, text: String, type: int) -> void:
	var old_frame_nr: int = project_data.markers_frame[index]
	var old_text: String = project_data.markers_text[index]
	var old_type: int = project_data.markers_type[index]

	InputManager.undo_redo.create_action("update marker")
	InputManager.undo_redo.add_do_method(_update.bind(index, frame_nr, text, type))
	InputManager.undo_redo.add_undo_method(_update.bind(index, old_frame_nr, old_text, old_type))
	InputManager.undo_redo.commit_action()


func _update(index: int, frame_nr: int, text: String, type: int) -> void:
	project_data.markers_frame[index] = frame_nr
	project_data.markers_text[index] = text
	project_data.markers_type[index] = type
	Project.unsaved_changes = true
	updated.emit(index)


func remove(index: int) -> void:
	var frame_nr: int = project_data.markers_frame[index]
	var text: String = project_data.markers_text[index]
	var type: int = project_data.markers_type[index]

	InputManager.undo_redo.create_action("Remove marker")
	InputManager.undo_redo.add_do_method(_remove.bind(frame_nr))
	InputManager.undo_redo.add_undo_method(_add.bind(frame_nr, text, type))
	InputManager.undo_redo.commit_action()


func _remove(frame_nr: int) -> void:
	var index: int = project_data.markers_frame.find(frame_nr)

	project_data.markers_frame.remove_at(index)
	project_data.markers_text.remove_at(index)
	project_data.markers_type.remove_at(index)
	Project.unsaved_changes = true
	removed.emit(index)


# --- Getters ---

## Get a sorted array of the index numbers according to frame_nr.
func get_sorted() -> PackedInt64Array:
	var indexes: Array[int] = range(project_data.markers_frame.size())
	indexes.sort_custom(_sort)
	return PackedInt64Array(indexes)


func get_previous(frame_nr: int) -> int:
	var sorted: PackedInt64Array = get_sorted()
	if project_data.markers_frame.has(frame_nr):
		var index: int = project_data.markers_frame[frame_nr]
		return sorted[max(index - 1, 0)]

	var previous: int = 0
	for i: int in sorted:
		var current: int = project_data.markers_frame[i]
		if current > frame_nr:
			return previous
		previous = current
	return 0


func get_next(frame_nr: int) -> int:
	var sorted: PackedInt64Array = get_sorted()
	if project_data.markers_frame.has(frame_nr):
		var index: int = project_data.markers_frame[frame_nr]
		return sorted[min(index + 1, project_data.markers_frame.size())]

	sorted.reverse()
	var previous: int = 0
	for i: int in sorted:
		var current: int = project_data.markers_frame[i]
		if current < frame_nr:
			return previous
		previous = current
	return project_data.timeline_end


# --- Helper functions ---

func _sort(a: int, b: int) -> int:
	return project_data.markers_frame[a] < project_data.markers_frame[b]
