extends Window
# TODO: Include log file

const URL_FORM := "https://forms.gle/fwCfAXTQ4HrkZ1J77"
const URL_REQUEST := "https://docs.google.com/forms/u/0/d/e/1FAIpQLSc05KlF6MVlT_-ImbU07XywOXWDWBMhbbJZ-8gNMTcXSoSKAQ/formResponse"
const PACKET_HEADER := [
	"Content-Type: application/x-www-form-urlencoded"]

const ID_VERSION := 1893125384
const ID_CONTACT := 529782953
const ID_DESC := 1630285445


func _on_about_to_popup() -> void:
	%ContactLineEdit.text = ""
	%DescTextEdit.text = ""


func _on_cancel_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.BUG_REPORT)


func _on_submit_button_pressed() -> void:
	if %DescTextEdit.text == "":
		_on_cancel_button_pressed()
	var l_message: String = "entry.{id_version}={version}&entry.{id_contact}={contact}&entry.{id_desc}={desc}"
	var l_data: Dictionary = {
		id_version = ID_VERSION,
		id_contact = ID_CONTACT,
		id_desc = ID_DESC,
		version = ProjectSettings.get_setting("application/config/version"),
		contact = %ContactLineEdit.text,
		desc = %DescTextEdit.text }
	var l_request := HTTPRequest.new()
	
	add_child(l_request)
	l_request.request(URL_REQUEST, PACKET_HEADER, HTTPClient.METHOD_POST, l_message.format(l_data))
	Printer.connect_error(l_request.request_completed.connect(_request_completed.bind(l_request)))
	PopupManager.close_popup(PopupManager.POPUP.BUG_REPORT)


func _request_completed(_r: int, _rc: int, _h: PackedStringArray, a_body: PackedByteArray, a_request: HTTPRequest) -> void:
	remove_child(a_request)
