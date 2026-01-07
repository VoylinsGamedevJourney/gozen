shader_type compute
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D input_image;
layout(rgba8, set = 0, binding = 1) uniform image2D output_image;

layout(set = 0, binding = 2, std140) uniform Params {
    float brightness;
    float contrast;
    float saturation;
    vec4 tint;
    float tint_amount;
    float red_value;
    float green_value;
    float blue_value;
} params;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = textureSize(input_image, 0);

    if (id.x >= size.x || id.y >= size.y) {
        return; // Boundary check
    }

    vec4 color = texelFetch(input_image, id, 0);
    
	// Adjust color values
    color.r *= params.red_value;
    color.g *= params.green_value;
    color.b *= params.blue_value;

    // Contrast & Brightness
    color.rgb = (color.rgb - 0.5) * params.contrast + 0.5 + params.brightness;

    const vec3 luminance_weights = vec3(0.2126, 0.7152, 0.0722);
    float gray = dot(color.rgb, luminance_weights);

    color.rgb = mix(vec3(gray), color.rgb, params.saturation); // Saturation
    color.rgb = mix(color.rgb, params.tint.rgb, params.tint_amount); // Tint
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    imageStore(output_image, id, color);
}
