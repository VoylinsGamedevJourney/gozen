extends EditorLayoutInterface

## No path in globals as this is for the default module, not for the interface
const PATH_EDITOR_SETTINGS := "user://editor_layout_default.dat"

var _path := "res://modules/editor_layout/default/boxes/%s.tscn"
var project_view_box = load(_path % "files_box").instantiate()
var timeline_box = load(_path % "files_box").instantiate()
var library_box = load(_path % "files_box").instantiate()
var effects_box = load(_path % "files_box").instantiate()
var files_box = load(_path % "files_box").instantiate()


var settings := {
	"hsp1_offset": 200,
	"hsp2_offset": 200,
	"vsc_left_offset": 0,
	"vsc_middle_offset": 200,
	"vsc_right_offset": 0,
}



func _ready() -> void:
	load_editor_layout_settings()


func save_editor_layout_settings() -> void:
	# TODO: Saves on project save for now
	var file := FileAccess.open_compressed(PATH_EDITOR_SETTINGS, FileAccess.WRITE)
	file.store_var(settings)
	file.close()


func load_editor_layout_settings() -> void:
	if !FileAccess.file_exists(PATH_EDITOR_SETTINGS): save_editor_layout_settings()
	var file := FileAccess.open_compressed(PATH_EDITOR_SETTINGS, FileAccess.READ)
	settings.merge(file.get_var(), true)
	file.close()
	
	# First setting all the split containers split offset
	%HSP1.split_offset = settings.hsp1_offset
	%HSP2.split_offset = settings.hsp2_offset
	%VSCLeft.split_offset = settings.vsc_left_offset
	%VSCMiddle.split_offset = settings.vsc_middle_offset
	%VSCRight.split_offset = settings.vsc_right_offset
	
	# Put boxes in correct place
#	var project_view_box = load(_path % "files_box").instantiate()
#	var timeline_box = load(_path % "files_box").instantiate()
#	var library_box = load(_path % "files_box").instantiate()
#	var effects_box = load(_path % "files_box").instantiate()
#	var files_box = load(_path % "files_box").instantiate()


func _on_hsp_1_dragged(offset: int) -> void: settings.hsp1_offset = offset
func _on_hsp_2_dragged(offset: int) -> void: settings.hsp2_offset = offset
