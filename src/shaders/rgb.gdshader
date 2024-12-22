shader_type canvas_item;


uniform sampler2D rgb_image;



void fragment() {
    vec4 color = texture(rgb_image, UV);

    COLOR = color;
}
