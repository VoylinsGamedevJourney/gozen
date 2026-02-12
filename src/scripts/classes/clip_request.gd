class_name ClipRequest
extends RefCounted

var clip: int = -1
var file: int = -1

var track: int = 0
var frame: int = 0

var frame_offset: int = 0
var track_offset: int = 0

var resize: int
var is_end: bool = false



static func add_request(file_id: int, track_index: int, frame_nr: int) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.file = file_id
	request.track = track_index
	request.frame = frame_nr
	return request


static func cut_request(clip_id: int, frame_cut_pos: int) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip = clip_id
	request.frame = frame_cut_pos
	return request


static func move_request(clip_id: int, offset_frame: int, offset_track: int = 0) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip = clip_id
	request.frame_offset = offset_frame
	request.track_offset = offset_track
	return request


static func resize_request(clip_id: int, resize_amount: int, end: bool) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip = clip_id
	request.resize = resize_amount
	request.is_end = end
	return request
