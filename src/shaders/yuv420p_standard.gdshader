shader_type canvas_item;


// Displaying image
uniform sampler2D y_data;
uniform sampler2D u_data;
uniform sampler2D v_data;

uniform vec2 resolution;
uniform vec4 color_profile;

// Effects
uniform float alpha: hint_range(0.0, 1, 0.001) = 1;

uniform float brightness: hint_range(-1, 1) = 0.0;
uniform float contrast: hint_range(0, 3) = 1.0;
uniform float saturation: hint_range(0, 3) = 1.0;

uniform float red_value: hint_range(0, 1) = 1.0;
uniform float green_value: hint_range(0, 1) = 1.0;
uniform float blue_value: hint_range(0, 1) = 1.0;

uniform vec4 tint_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_effect_factor: hint_range(0, 1) = 0.0;



void fragment() {
	vec2 uv = UV;
    uv *= resolution / vec2(textureSize(y_data, 0));
    uv = clamp(uv, vec2(0.0), vec2(1.0));

    float Y = texture(y_data, uv).r;
    float U = texture(u_data, uv).r;
    float V = texture(v_data, uv).r;

	Y = (Y * 255. - 16.) / 219.;
	U = (U * 255. - 128.) / 244.;
	V = (V * 255. - 128.) / 244.;

	float R = Y + color_profile.x * V;
	float G = Y - color_profile.y * U - color_profile.z * V;
	float B = Y + color_profile.w * U;

     COLOR = vec4(R, G, B, 1.0);
//	vec4 tex = vec4(R, G, B, 1.0);
//	
//	// Brightness
//	mat4 brightness_matrix = mat4(
//		vec4(1, 0, 0, 0),
//		vec4(0, 1, 0, 0),
//		vec4(0, 0, 1, 0),
//		vec4(brightness, brightness, brightness, 1)
//	);
//
//	// Contrast
//	float contrast_value = (1.0 - contrast) / 2.0;
//	mat4 contrast_matrix = mat4(
//		vec4(contrast, 0, 0, 0),
//		vec4(0, contrast, 0, 0),
//		vec4(0, 0, contrast, 0),
//		vec4(contrast_value, contrast_value, contrast_value, 1)
//	);
//
//	// Saturation
//	vec3 luminance = vec3( 0.3086, 0.6094, 0.0820 );
//	float sat_adjust = 1.0 - saturation;
//	vec3 red = vec3(luminance.x * sat_adjust) + vec3(saturation, 0, 0) * red_value;
//	vec3 green = vec3(luminance.y * sat_adjust) + vec3(0, saturation, 0) * green_value;
//	vec3 blue = vec3(luminance.z * sat_adjust) + vec3(0, 0,saturation) * blue_value;
//	mat4 saturation_matrix = mat4(
//		vec4(red, 0),
//		vec4(green,0),
//		vec4(blue,0),
//		vec4(0, 0, 0, 1)
//	);
//	
//	// Setting correct color
//	COLOR = brightness_matrix * contrast_matrix * saturation_matrix * mix(
//			tex, tex * tint_color, tint_effect_factor);
//	
//	// Transparency
//	COLOR.a = alpha * tex.a;
}
