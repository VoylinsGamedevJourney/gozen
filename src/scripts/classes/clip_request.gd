class_name ClipRequest
extends RefCounted


var clip: ClipData = null
var file: FileData = null

var track: int = 0
var frame: int = 0

var frame_offset: int = 0
var track_offset: int = 0

var resize: int
var is_end: bool = false



static func add_request(file_data: FileData, track_index: int, frame_nr: int) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.file = file_data
	request.track = track_index
	request.frame = frame_nr
	return request


static func split_request(clip_data: ClipData, frame_split_pos: int) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip = clip_data
	request.frame = frame_split_pos
	return request


static func move_request(clip_data: ClipData, offset_track: int, offset_frame: int) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip = clip_data
	request.frame_offset = offset_frame
	request.track_offset = offset_track
	return request


static func resize_request(clip_data: ClipData, resize_amount: int, end: bool) -> ClipRequest:
	var request: ClipRequest = ClipRequest.new()
	request.clip = clip_data
	request.resize = resize_amount
	request.is_end = end
	return request
