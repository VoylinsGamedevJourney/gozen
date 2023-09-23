extends Node

signal _on_version_updated
signal _on_version_outdated


const PROPERTY_MAJOR := "config/version_major"
const PROPERTY_MINOR := "config/version_minor"
const PROPERTY_PATCH := "config/version_patch"


var version: String = "0.0.0"


func _ready() -> void:
	version = "%s.%s.%s" % [
		ProjectSettings.get_setting("application/%s" % PROPERTY_MAJOR),
		ProjectSettings.get_setting("application/%s" % PROPERTY_MINOR),
		ProjectSettings.get_setting("application/%s" % PROPERTY_PATCH)]
	if !OS.has_feature("standalone"): # Run from editor
		version += "-dev"
		return # No version check
	
	var path := "https://raw.githubusercontent.com/voylin/GoZen/%s/src/project.godot"
	if OS.is_debug_build(): # Test build else Release build
		version += "-test"
		path = path % "testing"
	else: 
		path = path % "master"
	_on_version_updated.emit()
	
	# Running version check
	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_version_check_received)
	var error := http_request.request(path)
	if error != OK:
		print_debug("Could not get version json")


func _version_check_received(_r, response, _h, body):
	print(body.get_string_from_utf8())
	if response == 404:
		print_debug("Could not retrieve version file, 404")
		return
	var branch_settings: ConfigFile = ConfigFile.new()
	if branch_settings.parse(body.get_string_from_utf8()):
		print_debug("Could not parse branch settings")
	
	if (branch_settings.get_value("application",PROPERTY_MAJOR) >
			ProjectSettings.get_setting("application/%s" % PROPERTY_MAJOR)):
		_on_version_outdated.emit()
	elif (branch_settings.get_value("application",PROPERTY_MINOR) >
			ProjectSettings.get_setting("application/%s" % PROPERTY_MINOR)):
		_on_version_outdated.emit()
	elif (branch_settings.get_value("application",PROPERTY_PATCH) >
			ProjectSettings.get_setting("application/%s" % PROPERTY_PATCH)):
		_on_version_outdated.emit()
