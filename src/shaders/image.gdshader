shader_type canvas_item;


// Effects
uniform float alpha: hint_range(0.0, 1, 0.001) = 1.0;

uniform float brightness: hint_range(-1, 1) = 0.0;
uniform float contrast: hint_range(0, 3) = 1.0;
uniform float saturation: hint_range(0, 3) = 1.0;

uniform float red_value: hint_range(0, 1) = 1.0;
uniform float green_value: hint_range(0, 1) = 1.0;
uniform float blue_value: hint_range(0, 1) = 1.0;

uniform vec4 tint_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_effect_factor: hint_range(0, 1) = 0.0;

uniform bool apply_chroma_key = false;
uniform vec4 key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float key_tolerance : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float key_softness : hint_range(0.0, 0.5, 0.01) = 0.05;



void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 original_tex = tex;
	
	// Brightness
	mat4 brightness_matrix = mat4(
		vec4(1, 0, 0, 0),
		vec4(0, 1, 0, 0),
		vec4(0, 0, 1, 0),
		vec4(brightness, brightness, brightness, 1)
	);

	// Contrast
	float contrast_value = (1.0 - contrast) / 2.0;
	mat4 contrast_matrix = mat4(
		vec4(contrast, 0, 0, 0),
		vec4(0, contrast, 0, 0),
		vec4(0, 0, contrast, 0),
		vec4(contrast_value, contrast_value, contrast_value, 1)
	);

	// Saturation
	vec3 luminance = vec3( 0.3086, 0.6094, 0.0820 );
	float sat_adjust = 1.0 - saturation;
	vec3 red = vec3(luminance.x * sat_adjust) + vec3(saturation, 0, 0) * red_value;
	vec3 green = vec3(luminance.y * sat_adjust) + vec3(0, saturation, 0) * green_value;
	vec3 blue = vec3(luminance.z * sat_adjust) + vec3(0, 0,saturation) * blue_value;
	mat4 saturation_matrix = mat4(
		vec4(red, 0),
		vec4(green,0),
		vec4(blue,0),
		vec4(0, 0, 0, 1)
	);

	// Setting correct color
	COLOR = brightness_matrix * contrast_matrix * saturation_matrix * mix(
			tex, tex * tint_color, tint_effect_factor);
	
	// Chroma key
	float chroma_alpha_multiplier = 1.0;

	if (apply_chroma_key) {
		float dist = distance(tex.rgb, key_color.rgb);

		chroma_alpha_multiplier = smoothstep(key_tolerance, key_tolerance + key_softness, dist);
	}

	// Combine transparency values
	COLOR.a = original_tex.a * alpha * chroma_alpha_multiplier;
}

