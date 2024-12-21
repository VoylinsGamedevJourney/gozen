extends Node


func open_url(a_url: String) -> void:
	if OS.shell_open(a_url):
		print("Something went wrong opening ", a_url, " url!")

