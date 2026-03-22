class_name FileData
extends Resource


@export var id: int
@export var path: String ## Temporary files start with "temp://".
@export var proxy_path: String
@export var modified_time: int = -1

@export var type: EditorCore.TYPE = EditorCore.TYPE.EMPTY
@export var nickname: String
@export var folder: String = "/" ## Folder inside the editor.
@export var duration: int = -1

# These variables are specific to temp files & videos.
@export var temp_file: TempFile

@export var ato_active: bool = false
@export var ato_offset: float
@export var ato_file: int
