class_name ClipRequest
extends RefCounted

var clip_id: int = -1
var file_id: int = -1

var frame_nr: int = 0
var track_id: int = 0

var frame_offset: int = 0
var track_offset: int = 0

var resize_amount: int
var from_end: bool = false


static func add_request(file: int, track: int, frame: int) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.file_id = file
	request.track_id = track
	request.frame_nr = frame
	return request


static func cut_request(id: int, frame_cut_pos: int) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip_id = id
	request.frame_nr = frame_cut_pos
	return request


static func move_request(id: int, _frame_offset: int, _track_offset: int) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip_id = id
	request.frame_offset = _frame_offset
	request.track_offset = _track_offset
	return request


static func resize_request(id: int, amount: int, end: bool) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip_id = id
	request.resize_amount = amount
	request.from_end = end
	return request
