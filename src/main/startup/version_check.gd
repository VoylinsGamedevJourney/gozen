extends PanelContainer
## Version Check
##
## Runs on the startup screen to check if the user needs to be
## notified of a new GoZen version which is available to download.
##
## We use CalVer (2024.4.4)


func _ready() -> void:
	## Creating an http request, connects and sends it. 
	var l_request := HTTPRequest.new()
	add_child(l_request)
	
	l_request.request_completed.connect(_request_completed)
	
	var l_error = l_request.request(Globals.URL_VERSION_STABLE)
	if l_error != OK:
		Printer.error(Globals.ERROR_VERSION_CHECK_REQUEST % l_error)


func _request_completed(a_result: int, a_response_code: int, _h, a_body: PackedByteArray) -> void:
	## When a request has been completed, this will be checked if we could find the
	## config file, if yes, we load it in and we compare to the local config file.
	if a_result != OK or a_response_code == 404:
		return # Could not get the page, possibly no connection?
	
	var l_config := ConfigFile.new()
	l_config.parse(a_body.get_string_from_utf8())
	
	# Getting version strings
	var l_stable_version: String = l_config.get_value("application", "config/version", "2024.4.4")
	var l_local_version: String = ProjectSettings.get_setting("application/config/version")
	
	visible = get_version_int(l_stable_version) > get_version_int(l_local_version)


func get_version_int(a_version: String) -> int:
	var l_data: PackedStringArray = a_version.split(".")
	for l_i in [1,2]:
		if l_data[l_i].length() == 1:
			l_data[l_i] = '0' + l_data[l_i]
	return int(l_data[0] + l_data[1] + l_data[2])
