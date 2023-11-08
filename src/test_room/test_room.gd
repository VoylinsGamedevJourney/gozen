extends Control

var stop := false
var frames := [
	Vector2i(400,240),
	Vector2i(380,230),
	Vector2i(360,220),
	Vector2i(340,210),
	Vector2i(320,200),
	Vector2i(300,190),
	Vector2i(290,180),
	Vector2i(280,170),
	Vector2i(270,160),
	Vector2i(260,150),
	Vector2i(250,140),
	Vector2i(240,130),
	Vector2i(230,120),
	Vector2i(220,110),
	Vector2i(210,100),
	Vector2i(200,95),
	Vector2i(190,90),
	Vector2i(180,85),
	Vector2i(160,80),
	Vector2i(140,75),
	Vector2i(120,70),
	Vector2i(100,65),
	Vector2i(90,60),
	Vector2i(80,55),
	Vector2i(70,50),
	Vector2i(60,40),
	Vector2i(50,30),
	Vector2i(40,20),
	Vector2i(20,10),
	Vector2i(0,0)
]


func _on_button_pressed() -> void:
	var pipe_renderer: GoZenPipeRenderer = GoZenPipeRenderer.new()
	pipe_renderer.setup("/home/voylin/Documents/Programming/GoZen/src/renderers/render_server/test.webm", 5)
	print("Start sending frames")
	for frame: Vector2i in frames:
		$SubViewportContainer/SubViewport/Purple.position = frame
		await RenderingServer.frame_post_draw
		var image: Image = $SubViewportContainer/SubViewport.get_texture().get_image()
		pipe_renderer.add_frame(image)
	pipe_renderer.finish_video()
