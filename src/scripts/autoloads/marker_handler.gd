extends Node
# TODO: Add a marker ripple (would probably need to link the marker with a
# specific clip for this to work correctly)

signal marker_added(frame_nr: int)
signal marker_updated(old_frame_nr: int, new_frame_nr: int)
signal marker_removed(frame_nr: int)
signal marker_moving


var markers: Dictionary[int, MarkerData] = {} # { Frame: Marker }
var dragged_marker: int = -1
var dragged_marker_offset: float = 0:
	set(value):
		dragged_marker_offset = value
		marker_moving.emit()



func _ready() -> void:
	Project.project_ready.connect(_project_ready)


func _project_ready() -> void:
	markers = Project.data.markers


func add_marker(frame_nr: int, marker: MarkerData) -> void:
	if markers.has(frame_nr):
		update_marker(frame_nr, frame_nr, marker)
		return

	markers[frame_nr] = marker
	marker_added.emit(frame_nr)
	Project.unsaved_changes = true


func update_marker(old_frame_nr: int, new_frame_nr: int, marker: MarkerData) -> void:
	markers[new_frame_nr] = marker
	markers.erase(old_frame_nr)

	marker_updated.emit(old_frame_nr, new_frame_nr)
	Project.unsaved_changes = true


func remove_marker(frame_nr: int) -> void:
	if !markers.has(frame_nr):
		printerr("MarkerHandler: No marker at %s!" % frame_nr)
		return

	markers.erase(frame_nr)
	marker_removed.emit(frame_nr)
	Project.unsaved_changes = true


func get_marker(frame_nr: int) -> MarkerData:
	return markers[frame_nr]


func get_frame_nrs() -> PackedInt64Array:
	var arr: PackedInt64Array = markers.keys()

	arr.sort()
	return arr


func get_marker_positions() -> PackedInt64Array:
	var project_markers: PackedInt64Array = markers.keys()

	project_markers.sort()
	return project_markers
