extends Node
## Settings Manager
##
## All settings getters and setters are inside this autoload.
## All variables which are added to settings should have their
## setters and getters put here.

signal _on_open_settings
signal _on_zen_switched(value)

signal _on_version_changed(new_version)
signal _on_version_outdated


const PATH := "user://settings"


var settings: Settings = Settings.new()

var update_available: bool = false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var data: String = FileManager.load_data(PATH)
	if data == "":
		save_settings()
		return
	settings = str_to_var(data)
	for setting in settings.get_property_list():
		if setting.usage == 4096:
			call("set_%s" % setting.name, settings.get(setting.name))


func save_settings() -> void:
	FileManager.save_data(settings, PATH)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_zen_mode"):
		set_zen_mode(!get_zen_mode())


##############################################################
# Getters and setters  #######################################
##############################################################

# ZEN MODE  ##################################################
func get_zen_mode() -> bool:
	return settings.zen_mode


func set_zen_mode(value: bool) -> void:
	settings.zen_mode = value
	_on_zen_switched.emit(value)
	save_settings()


# LANGUAGE  ##################################################

func set_language(language_code: String) -> void:
	TranslationServer.set_locale(language_code)
	settings.language = language_code
	save_settings()


# VERSION  ###################################################

func get_version() -> String:
	return settings.editor_version


func check_version() -> void:
	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(
		func(_r, response, _h, body):
			var result: String = body.get_string_from_utf8()
			if response == 404:
				print("Error receiving version file!")
				return
			var json = JSON.new()
			json.parse(result)
			var g_version: Dictionary = json.data # Github version

			var file := FileAccess.open("res://version.json", FileAccess.READ)
			json.parse(file.get_as_text())
			var l_version: Dictionary = json.data # Local version

			for x in ["major","minor","patch"]:
				if g_version[x] > l_version[x]: # Outdated version
					update_available = true
					_on_version_outdated.emit()
				if g_version[x] < l_version[x]: # Development build
					var output: Array = []
					var commands := ["log", "--abbrev-commit", "-n", "1", "--pretty=format:\"%h\""]
					OS.execute("git", commands, output)
					settings.editor_version = "%s.%s.%s_dev-%s" % [
							l_version.major, l_version.minor, l_version.patch, output[0]]
					_on_version_changed.emit(settings.editor_version)
					return
			settings.editor_version = "%s.%s.%s" % [
					l_version.major, l_version.minor, l_version.patch]
			_on_version_changed.emit(settings.editor_version)
	)
	var error := http_request.request(
			"https://raw.githubusercontent.com/voylin/GoZen/master/src/version.json")
	if error != OK:
		print_debug("Could not get version json")


func set_editor_version(version: String) -> void:
	settings.editor_version = version
	check_version()
