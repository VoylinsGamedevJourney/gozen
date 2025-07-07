shader_type canvas_item;


uniform sampler2D y_data;
uniform sampler2D u_data;
uniform sampler2D v_data;

uniform vec2 resolution;
uniform vec4 color_profile;
uniform float rotation;
uniform float interlaced = 1.0; // 0 = no, 1 = top first, 2 = bottom first



void fragment() {
	vec2 uv = UV;
	vec2 centered_uv = uv - vec2(0.5);
	float cos_angle = cos(rotation);
	float sin_angle = sin(rotation);
	vec2 rotated_uv = vec2(
		centered_uv.x * cos_angle - centered_uv.y * sin_angle,
		centered_uv.x * sin_angle + centered_uv.y * cos_angle
	);

	uv = rotated_uv + vec2(0.5);

	vec2 y_uv = uv * resolution / vec2(textureSize(y_data, 0));
	y_uv = clamp(y_uv, vec2(0.0), vec2(1.0));

	vec2 u_uv = uv * ((resolution / 2.0) / vec2(textureSize(u_data, 0)));
    vec2 v_uv = uv * ((resolution / 2.0) / vec2(textureSize(v_data, 0)));

    u_uv = clamp(u_uv, vec2(0.0), vec2(1.0));
    v_uv = clamp(v_uv, vec2(0.0), vec2(1.0));
	
	// Line blending deinterlacing.
	float Y;
	vec2 offset = vec2(0.0, 1.0 / resolution.y);

	vec2 y_uv_top = clamp(y_uv - offset, vec2(0.0), vec2(1.0));
	vec2 y_uv_bottom = clamp(y_uv + offset, vec2(0.0), vec2(1.0));

	float Y_center = texture(y_data, y_uv).r;
	float Y_top = texture(y_data, y_uv_top).r;
	float Y_bottom = texture(y_data, y_uv_bottom).r;

	if (interlaced == 1.0)
		Y = mix(Y_top, Y_center, 0.5);
	else
		Y = mix(Y_center, Y_bottom, 0.5);

	float U = float(texture(u_data, u_uv).r);
	float V = float(texture(v_data, v_uv).r);
	
	Y = (Y * 255. - 16.) / 219.;
	U = (U * 255. - 128.) / 224.;
	V = (V * 255. - 128.) / 224.;
	
	float R = Y + color_profile.x * V;
	float G = Y - color_profile.y * U - color_profile.z * V;
	float B = Y + color_profile.w * U;
	
	COLOR = vec4(R, G, B, 1.0);
}

