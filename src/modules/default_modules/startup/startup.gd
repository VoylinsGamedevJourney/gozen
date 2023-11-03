extends ModuleStartup
# Future TODO: Make version label clickable, bringing up a popup
#              which displays recent version changes (changelog of that version)


var recent_projects: Array
var explorer: FileDialog

var startup_images := {
	"winter": {
		"path": "clay-banks-u27Rrbs9Dwc-unsplash.jpg",
		"credit_url": "https://unsplash.com/photos/u27Rrbs9Dwc",
		"credit_name": "Clay Banks",
		"size_y": 270
	},
	"spring": {
		"path": "yusheng-deng-gNZ6MHqtsLY-unsplash.jpg",
		"credit_url": "https://unsplash.com/ja/%E5%86%99%E7%9C%9F/%E6%98%BC%E9%96%93%E3%81%AE%E6%B9%96%E3%82%84%E5%B1%B1%E3%81%AE%E8%BF%91%E3%81%8F%E3%81%AE%E8%91%89%E3%81%AE%E3%81%AA%E3%81%84%E6%9C%A8-gNZ6MHqtsLY",
		"credit_name": "Yusheng Deng",
		"size_y": 270
	},
	"summer": {
		"path": "david-edelstein-N4DbvTUDikw-unsplash.jpg",
		"credit_url": "https://unsplash.com/ja/%E5%86%99%E7%9C%9F/%E5%AF%8C%E5%A3%AB%E5%B1%B1%E6%97%A5%E6%9C%AC-N4DbvTUDikw",
		"credit_name": "Davide Edelstein",
		"size_y": 270
	},
	"autumn": {
		"path": "johannes-plenio-RwHv7LgeC7s-unsplash.jpg",
		"credit_url": "https://unsplash.com/ja/%E5%86%99%E7%9C%9F/%E5%A4%AA%E9%99%BD%E5%85%89%E7%B7%9A%E3%81%AB%E3%82%88%E3%82%8B%E6%A3%AE%E6%9E%97%E7%86%B1-RwHv7LgeC7s",
		"credit_name": "Johannes Plenio",
		"size_y": 270
	},
}
const CREDIT_TEXT := "[right][i]Image by [url=%s]%s via Unsplash[/url][/i][/right]"
const IMAGE_PATH := "res://assets/images_startup/%s"


func _ready() -> void:
	ProjectManager.get_recent_projects()
	
	# Check if opened with a "*.gozen" file as argument.
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if "*.gozen" in arg:
			ProjectManager.load_project(arg)
			queue_free()
	
	var button = %RecentProjectsVBox.get_child(0)
	
	for path in ProjectManager.get_recent_projects():
		if %RecentProjectsVBox.get_child_count() > 6:
			break # We only want the 5 most recent projects to show
		if !FileAccess.file_exists(path):
			continue
		var p_name: String = str_to_var(FileManager.load_data(path)).title
		if p_name == "":
			continue
		var new_button := button.duplicate()
		new_button.text = path
		new_button.tooltip_text = path
		new_button.pressed.connect(_on_recent_project_button_pressed.bind(path))
		new_button.visible = true
		%RecentProjectsVBox.add_child(new_button)
	
	# Setting the startup image:
	var month : int = Time.get_datetime_dict_from_system().month
	var image_data: Dictionary = startup_images["winter"]
	# TODO: Find better images for this
	#match month:
		#12,1,2:
			#image_data = startup_images["winter"]
		#3,4,5:
			#image_data = startup_images["spring"]
		#6,7,8:
			#image_data = startup_images["summer"]
		#9,10,11:
			#image_data = startup_images["spring"]
	%ImageCredit.text = CREDIT_TEXT % [image_data.credit_url, image_data.credit_name]
	%WelcomeImage.texture = load(IMAGE_PATH % image_data.path)
	%WelcomeImage.custom_minimum_size.y = image_data.size_y


func _on_url_clicked(meta) -> void:
	OS.shell_open(meta)


func _on_donate_button_pressed() -> void:
	OS.shell_open("https://github.com/voylin/GoZen")


func _on_open_project_button_pressed() -> void:
	explorer = FileDialog.new()
	explorer.popup_centered(Vector2i(300,300))
	# TODO: Make this work!
#	explorer = ModuleManager.get_selected_module("file_explorer")
	explorer.create("Save project", FileExplorer.MODE.SAVE_PROJECT)
	explorer._on_save_project_path_selected.connect(_on_open_project_file_selected)
	explorer._on_cancel_pressed.connect(_on_explorer_cancel_pressed)
	get_tree().current_scene.find_child("Content").add_child(explorer)
	explorer.open()


func _on_open_project_file_selected(path: String) -> void:
	ProjectManager.add_recent_project(path)
	ProjectManager.load_project(path)
	queue_free()


func _on_explorer_cancel_pressed() -> void:
	explorer.queue_free()
	explorer = null


func _on_recent_project_button_pressed(project_path: String) -> void:
	if !FileAccess.file_exists(project_path):
		return
	ProjectManager.load_project(project_path)
	ProjectManager.add_recent_project(project_path)
	queue_free()


# NEW PROJECT BUTTONS  #######################################

## New 1080p project horizontal
func _on_new_fhdh_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(1080,1920))
	queue_free()


# New 1080p project vertical
func _on_new_fhdv_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(1920,1080))
	queue_free()


## New 4K project horizontal
func _on_new_4kh_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(2160,3840))
	queue_free()


# New 4K project vertical
func _on_new_4kv_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(3840,2160))
	queue_free()


## New 1080p project horizontal, but opens in project manager
func _on_new_custom_button_pressed() -> void:
	ProjectManager.project = Project.new()
	ProjectManager.set_resolution(Vector2i(1080,1920))
	ProjectManager._on_open_project_settings.emit()
	queue_free()
