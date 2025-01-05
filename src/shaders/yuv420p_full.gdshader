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
    float U = texture(u_data, uv).r - 0.5;
    float V = texture(v_data, uv).r - 0.5;

	float R = Y + color_profile.x * V;
	float G = Y - color_profile.y * U - color_profile.z * V;
	float B = Y + color_profile.w * U;

    // COLOR = vec4(R, G, B, 1.0);

	R = clamp(R, 0.0, 1.0);
    G = clamp(G, 0.0, 1.0);
    B = clamp(B, 0.0, 1.0);

	// Setting the alpha correctly
	vec4 color = vec4(R, G, B, alpha * COLOR.a);
	
	// Brightness + constrast
	color.rgb = color.rgb + vec3(brightness);
	color.rgb = (color.rgb - 0.5) * contrast + 0.5;

	// Saturation
	float grey = dot(color.rgb, vec3(0.3086, 0.6094, 0.0820)); // Luminance
	color.rgb = mix(vec3(grey), color.rgb, saturation);

	// Color adjustments
	color.r *= red_value;
	color.g *= green_value;
	color.b *= blue_value;

	// Apply tint
	color.rgb = mix(color.rgb, color.rgb * tint_color.rgb, tint_effect_factor);

	COLOR = clamp(color, 0.0, 1.0);
}
