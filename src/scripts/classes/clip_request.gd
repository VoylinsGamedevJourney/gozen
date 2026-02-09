class_name ClipRequest
extends RefCounted


var clip_id: int
var file_id: int

var frame_nr: int
var track_id: int

var frame_offset: int
var track_offset: int

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
