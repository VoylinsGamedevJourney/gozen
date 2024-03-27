@tool
extends MarginContainer
# TODO: For future, have categories as people will not neceserally use default modules.
# For the modules, these should have an entry in theinfo.tres file of where language files
# are located.

const PATH_POT := "res://translations/gozen-translations/po_files/translations_template.pot"
const PATH_PO_FILES := "res://translations/gozen-translations/po_files/"
const PATH_MO_FILES := "res://translations/"

const POT_HEADERS := [
	"msgid \"\"",
	"msgstr \"\"",
	"\"Project-Id-Version: GoZen - Video Editor\\n\"",
	"\"MIME-Version: 1.0\\n\"",
	"\"Content-Type: text/plain; charset=UTF-8\\n\"",
	"\"Content-Transfer-Encoding: 8-bit\\n\""] 
const POT_HEADER_LANGUAGE := "\"Language: {language_code}\\n\""


# For easily accessing data from the UI
#var ids := []
#var first_language := []
#var second_language := []

var pot_data : Dictionary = {} # Key is 'msgid'


func _on_generate_pot_button_pressed() -> void:
	var original_pot_data: Dictionary = _get_po_data(PATH_POT)
	pass


func _on_generate_po(language_code: String, data: Dictionary) -> void:
	# First line: # LANGUAGE translation for GoZen - Video Editor for the following files:
	# After that first all file occurances make packed string array?
	# Make another packed string array with the rest of the file data
	# 
	# Put the first line and occurances, followed by the standard headers
	# Add the language header and repalce language code
	# Add empty line
	# Add all other data
	pass


func _on_generate_mo_button_pressed() -> void:
	var po_path: String = PATH_PO_FILES.replace("res://", ProjectSettings.globalize_path("res://"))
	var mo_path: String = PATH_MO_FILES.replace("res://", ProjectSettings.globalize_path("res://"))
	print("Generating mo files ...")
	for po_file: String in DirAccess.get_files_at(PATH_PO_FILES):
		if po_file.split('.')[-1] == "pot":
			continue
		OS.execute("msgfmt", [ po_path + po_file, "-o", mo_path + po_file.replace(".po", ".mo")])


func _get_po_data(file_path: String) -> Dictionary:
	# NOTE: For testing only, get all data from POT file.
	var data: Dictionary = {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	while file.get_line() != "": 
		pass # Getting to the beginning of the data
	
	while !file.eof_reached():
		var entry := Entry.new()
		while true:
			var string: String = file.get_line()
			if string == "": # expecting new entry
				data[entry.msgid] = entry
				break
			elif string[0] == "#": # String location
				entry.occurrence.append(string)
			elif string.split(' ')[0] == "msgid":
				entry.msgid = string.trim_prefix("msgid \"").trim_suffix("\"")
			elif string.split(' ')[0] == "msgstr":
				entry.msgstr = string.trim_prefix("msgstr \"").trim_suffix("\"")
	return data


func _on_load_localization_button_pressed() -> void:
	pass


class Entry:
	var msgctxt: String
	var msgid: String
	var msgstr: String
	var occurrence: PackedStringArray
