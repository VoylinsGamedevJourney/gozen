shader_type canvas_item;


uniform sampler2D y_data;
uniform sampler2D u_data;
uniform sampler2D v_data;

uniform vec2 resolution;
uniform vec4 color_profile;



void fragment() {
	vec2 uv = UV;
    uv *= resolution / vec2(textureSize(y_data, 0));
    uv = clamp(uv, vec2(0.0), vec2(1.0));

    float Y = texture(y_data, uv).r;
    float U = texture(u_data, uv).r - 0.5;
    float V = texture(v_data, uv).r - 0.5;

	float R = Y + color_profile.x * V;
	float G = Y - color_profile.y * U - color_profile.z * V;
	float B = Y + color_profile.w * U;

    COLOR = vec4(R, G, B, 1.0);
}

