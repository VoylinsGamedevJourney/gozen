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

    float Y = float(texture(y_data, uv).r);
    float U = float(texture(u_data, uv).r);
    float V = float(texture(v_data, uv).r);

	Y = (Y * 255. - 16.) / 219.;
	U = (U * 255. - 128.) / 224.;
	V = (V * 255. - 128.) / 224.;

	float R = Y + color_profile.x * V;
	float G = Y - color_profile.y * U - color_profile.z * V;
	float B = Y + color_profile.w * U;

    COLOR = vec4(R, G, B, 1.0);
}

