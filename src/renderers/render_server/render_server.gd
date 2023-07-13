class_name RenderServer
extends Node

var stream: StreamPeerTCP = StreamPeerTCP.new()
var status: int = -1

var running := false
var pid


func start_server(framerate: int = 30, host: String = "127.0.0.1", port: int = 12543) -> void:
	print("Starting server")
	pid = OS.create_process("python", ["tester.py", host, port])
	print("Python server running at pid: '%s'" % pid)
	
	print("Connecting to server")
	if stream.connect_to_host(host, port) != OK: printerr("Could not connect!")
	running = true


func _process(_delta: float) -> void:
	if !running: return
	
	stream.poll()
	var new_status: int = stream.get_status()
	if new_status != status:
		status = new_status
		match status:
			stream.STATUS_NONE:       print("Disconnected from render server!")
			stream.STATUS_CONNECTING: print("Connecting to render server!")
			stream.STATUS_ERROR:      print("Error with socket stream.")
			stream.STATUS_CONNECTED:
				print("Connected to render server!")
				render()
	
	if status == stream.STATUS_CONNECTED:
		var available_bytes: int = stream.get_available_bytes()
		if available_bytes > 0:
			# Leaving this here for debugging for now.
#			print("available bytes: ", available_bytes)
			var data: Array = stream.get_partial_data(available_bytes)
			# Check for read error.
			if data[0] != OK:
				print("Error getting data from stream: ", data[0])
			else:
				print(PackedByteArray(data[1]).get_string_from_utf8())


## TODO: THIS CODE DOES NOT BELONG HERE AND SHOULD BE PART OF THE MAIN EDITOR
##       I DON'T HAVE THE MAIN EDITOR PART FINISHED YET SO IT IS STAYING HERE
##       FOR NOW UNTIL I CAN MOVE IT TO WHERE IT BELONGS.
func render() -> void:
	print("Start rendering + sending images")
	var time_now := Time.get_time_dict_from_system()
	print(time_now)
	var frame_number := 1
	var output := []
	$AnimationPlayer.current_animation = "test"
	while true:
		if frame_number == 5*30+1:
			break
		$AnimationPlayer.seek(float(float(frame_number)/30), true)
		await RenderingServer.frame_post_draw
		send(%SubViewport.get_texture().get_image().save_jpg_to_buffer(1.0))
		send("end_image".to_ascii_buffer())
		frame_number += 1
	send("stop".to_utf8_buffer())
	print("output: %s" % str(output))
	print(Time.get_time_string_from_system())
	print("Done")
	var time_done := Time.get_time_dict_from_system()
	print("Total time taken: %s minutes and %s seconds"% [
		time_done.minute - time_now.minute, time_done.second - time_now.second 
	])


func send(data: PackedByteArray) -> bool:
	if status != stream.STATUS_CONNECTED:
		print("Error: Stream is not currently connected.")
		return false
	var error: int = stream.put_data(data)
	if error != OK:
		print("Error writing to stream: ", error)
		return false
	return true
