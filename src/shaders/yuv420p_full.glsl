#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Input data
layout(set = 0, binding = 0)uniform sampler2D y_data;
layout(set = 0, binding = 1)uniform sampler2D u_data;
layout(set = 0, binding = 2)uniform sampler2D v_data;

// Output image
layout(rgba8, set = 0, binding = 3) uniform writeonly image2D out_image;

// Params
layout(set = 0, binding = 4, std140) uniform Params {
	ivec2 resolution;
	vec4 color_profile;
	float rotation;
	float interlaced;
} params;



void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

	if (pixel.x >= params.resolution.x || pixel.y >= params.resolution.y) {
        return;
    }

    // Normalized UV
    vec2 uv = (vec2(pixel) + 0.5) / vec2(params.resolution);

    // Rotation
    vec2 centered = uv - vec2(0.5);
    float c = cos(params.rotation);
    float s = sin(params.rotation);
    vec2 rotated = vec2(
        centered.x * c - centered.y * s,
        centered.x * s + centered.y * c
    );
    uv = rotated + vec2(0.5);

    // YUV sampling
    vec2 y_uv = clamp(
        uv * vec2(params.resolution) / vec2(textureSize(y_data, 0)),
        vec2(0.0), vec2(1.0)
    );

    vec2 uv_half = params.resolution / 2;
    vec2 u_uv = clamp(
        uv * uv_half / vec2(textureSize(u_data, 0)),
        vec2(0.0), vec2(1.0)
    );
    vec2 v_uv = clamp(
        uv * uv_half / vec2(textureSize(v_data, 0)),
        vec2(0.0), vec2(1.0)
    );

    float Y = texture(y_data, y_uv).r;
    float U = texture(u_data, u_uv).r - 0.5;
    float V = texture(v_data, v_uv).r - 0.5;

    // YUV to RGB
    vec3 rgb;
    rgb.r = Y + params.color_profile.x * V;
    rgb.g = Y - params.color_profile.y * U - params.color_profile.z * V;
    rgb.b = Y + params.color_profile.w * U;

    rgb = clamp(rgb, 0.0, 1.0);

	// Storing final RGBA image
    imageStore(out_image, pixel, vec4(rgb, 1.0));
}

