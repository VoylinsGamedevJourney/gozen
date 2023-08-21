extends Node

const RELEASE_VERSION_URL := "https://raw.githubusercontent.com/voylin/GoZen/master/src/version.json"
const DEV_VERSION_URL := "https://raw.githubusercontent.com/voylin/GoZen/development/src/version.json"


func _ready() -> void:
	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._version_check_response.bind(http_request))
	if http_request.request(RELEASE_VERSION_URL) != OK:
		print_debug("Could not get version json")


func _version_check_response(_result, response_code, _headers, body, http_request, dev_build = false) -> void:
	var result: String = body.get_string_from_utf8()
	if response_code == 404 or result.length() < 5: 
		print("Received version file info invalid"); return
	
	var json = JSON.new()
	json.parse(result)
	var github_version: Dictionary = json.data
	
	var file := FileAccess.open("res://version.json", FileAccess.READ)
	json.parse(file.get_as_text())
	var local_version: Dictionary = json.data
	
	if dev_build:
		check_dev_version(github_version, local_version, http_request)
	else:
		check_release_version(github_version, local_version, http_request)


func check_release_version(github_version, local_version, http_request: HTTPRequest) -> void:
	var update_available := false
	for x in ["major", "minor", "patch"]:
		if github_version[x] == local_version[x]: continue # Up to date release build
		if github_version[x] > local_version[x]:  update_available = true # Update available
		else: # Development build
			http_request.request_completed.disconnect(self._version_check_response)
			http_request.request_completed.connect(self._version_check_response.bind(http_request, true))
			if http_request.request(DEV_VERSION_URL) != OK:
				print_debug("Could not get version json")
			return
	if update_available: Globals._on_version_update_available.emit()
	Globals.version_string = "%s.%s.%s" % [local_version.major, local_version.minor, local_version.patch]
	http_request.queue_free()


func check_dev_version(github_version, local_version, http_request) -> void:
	var output: Array
	OS.execute("git", ["log", "--abbrev-commit", "-n", "1", "--pretty=format:\"%h\""], output)
	Globals.version_string = "%s.%s.%s_dev-%s" % [
		local_version.major, local_version.minor, local_version.patch, output[0]]
	http_request.queue_free()
