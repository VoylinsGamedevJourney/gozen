shader_type canvas_item;


// Image
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

uniform bool apply_chroma_key = false;
uniform vec4 key_color: source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float key_tolerance: hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float key_softness: hint_range(0.0, 0.5, 0.01) = 0.05;



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

	vec3 rgb = vec3(R, G, B);

	// Brightness + Contrast
	rgb = rgb + vec3(brightness);
	rgb = (rgb - 0.5) * contrast + 0.5;

	// Saturation
	float grey = dot(rgb, vec3(0.3086, 0.6094, 0.0820)); // Luminance
	rgb = mix(vec3(grey), rgb, saturation);

	// Color adjustments
	rgb.r *= red_value;
	rgb.g *= green_value;
	rgb.b *= blue_value;

	// Apply tint
	rgb = mix(rgb, rgb * tint_color.rgb, tint_effect_factor);

	rgb = clamp(rgb, 0.0, 1.0);

	// Chroma key
	float chroma_alpha_multiplier = 1.0;

	if (apply_chroma_key) {
		float dist = distance(rgb, key_color.rgb);

		chroma_alpha_multiplier = smoothstep(key_tolerance, key_tolerance + key_softness, dist);
	}

	// Set RGB + alpha
	COLOR = vec4(rgb, alpha * chroma_alpha_multiplier);
}

