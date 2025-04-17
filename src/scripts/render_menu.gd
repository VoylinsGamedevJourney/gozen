extends PanelContainer

# TODO: Create a way to save custom render profiles
# TODO: Make path button work
# TODO: Fill path with current project path (Change extension depending on selected profile
# TODO: Fill render profiles option button with defaults
# TODO: Make saving of custom render profiles work
# TODO: Only highlight/enable the "save profile" button when changes have been made
# TODO: Check if audio/video only
# TODO: Hide "Speed" when the selected codec isn't H264
# WARN: Quality uses a negative value, make positive before passing to Renderer!!


const RENDER_PROFILES_PATH: String = "user://render_profiles/"



func _ready() -> void:
	if !DirAccess.dir_exists_absolute(RENDER_PROFILES_PATH):
		if DirAccess.make_dir_recursive_absolute(RENDER_PROFILES_PATH):
			printerr("Couldn't create folder at %s!" % RENDER_PROFILES_PATH)

	# TODO: Load custom render profiles.


func _process(_delta: float) -> void:
	pass

