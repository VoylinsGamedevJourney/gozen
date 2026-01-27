class_name File
extends Node



var id: int
var path: String # Temporary files start with "temp://".
var proxy_path: String
var nickname: String
var type: FileHandler.TYPE = FileHandler.TYPE.EMPTY
var folder: String = "/" # Folder inside the editor.

var clip_only_video_ids: PackedInt32Array = []

var modified_time: int = -1

var duration: int = -1

var temp_file: TempFile = null # Only filled when file is a temp file.
