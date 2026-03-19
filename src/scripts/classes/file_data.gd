class_name FileData
extends Resource


var id: int
var path: String ## Temporary files start with "temp://".
var proxy_path: String
var modified_time: int = -1

var type: EditorCore.TYPE = EditorCore.TYPE.EMPTY
var nickname: String
var folder: String = "/" ## Folder inside the editor.
var duration: int = -1

# These variables are specific to temp files & videos.
var temp_file: TempFile

var ato_active: bool = false
var ato_offset: float
var ato_file: int
