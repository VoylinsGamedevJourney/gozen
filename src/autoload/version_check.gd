extends Node
## Version system
##
## Here we check if the user has an up to date version or not.
## If the version numbers are not equal to the master branch, 
## then we check if the numbers are lower of higher.
## If higher, we are in a development build so version becomes:
## 0.0.0_dev-commit
## If lower, we need to notify the user that an update is available
## and version will be displayed normally: 0.0.0

signal _on_change(new_string)
signal _on_update_available


var update_available := false:
	set(x):
		update_available = x
		_on_update_available.emit()
var version_string := "0.0.0":
	set(x): 
		version_string = x
		_on_change.emit(version_string)


func _ready() -> void:
	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(
			self._version_check_response.bind(http_request))
	var error := http_request.request(
			"https://raw.githubusercontent.com/voylin/GoZen/master/src/version.json")
	if error != OK:
		print_debug("Could not get version json")


func _version_check_response(
		_result, response_code, _headers, body, http_request) -> void:
	http_request.queue_free()
	var result: String = body.get_string_from_utf8()
	if response_code == 404 or result.length() < 5: 
		print("Received version file info invalid"); return
	
	var json = JSON.new()
	json.parse(result)
	var github_version: Dictionary = json.data
	
	var file := FileAccess.open("res://version.json", FileAccess.READ)
	json.parse(file.get_as_text())
	var local_version: Dictionary = json.data
	
	for x in ["major", "minor", "patch"]:
		if github_version[x] == local_version[x]:
			continue # Up to date release build
		if github_version[x] > local_version[x]:
			update_available = true # Update available
		else: # Development build
			var output: Array = []
			var commands := [
					"log", "--abbrev-commit", "-n", "1", "--pretty=format:\"%h\""]
			OS.execute("git", commands, output)
			version_string = "%s.%s.%s_dev-%s" % [
					local_version.major, 
					local_version.minor, 
					local_version.patch, 
					output[0]]
			return
	version_string = "%s.%s.%s" % [
			local_version.major, 
			local_version.minor, 
			local_version.patch]
