#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D y_data;
layout(set = 0, binding = 1) uniform sampler2D u_data;
layout(set = 0, binding = 2) uniform sampler2D v_data;
layout(set = 0, binding = 3) uniform sampler2D a_data;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 4) uniform writeonly image2D output_image;

// --- PARAMS --- (std140 requires 16 byte blocks)
// mat4 = 64 bytes
// ivec2 = 8 bytes
// int = 4 bytes
layout(set = 0, binding = 5, std140) uniform Params {
	mat4 color_matrix;	// Offset 0
	ivec2 resolution;	// Offset 64 (Display resolution)
	int interlaced;		// Offset 72
	int y_width;
	int uv_width;
	int source_width;
} params; // Ends at byte 80 (/16 = 5 blocks)



void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    
    if (id.x >= params.resolution.x || id.y >= params.resolution.y)
        return; // Checking boundary

	float source_x = (float(id.x) + 0.5) * (float(params.source_width) / float(params.resolution.x));

	vec2 y_uv = vec2(
		source_x / float(params.y_width),
		(float(id.y) + 0.5) / float(params.resolution.y));
	vec2 uv_uv = vec2(
		(source_x * 0.5) / float(params.uv_width),
		(float(id.y) * 0.5 + 0.5) / (float(params.resolution.y) * 0.5));

	vec3 yuv = vec3(
		texture(y_data, y_uv).r,
		texture(u_data, uv_uv).r,
		texture(v_data, uv_uv).r);

	if (params.interlaced > 0) {
		float pixel_height = 1.0 / params.resolution.y;
		float offset_direction = (params.interlaced == 1) ? -pixel_height: pixel_height;
		vec2 y_offset_uv = clamp(y_uv + vec2(0.0, offset_direction), 0.0, 1.0);
		vec2 uv_offset_uv = clamp(uv_uv + vec2(0.0, offset_direction), 0.0, 1.0);
		vec3 yuv_neighbor = vec3(
			texture(y_data, y_offset_uv).r,
			texture(u_data, uv_offset_uv).r,
			texture(v_data, uv_offset_uv).r);

		yuv = mix(yuv, yuv_neighbor, 0.5);
	}

	vec3 rgb = (params.color_matrix * vec4(yuv, 1.0)).rgb;

    imageStore(output_image, id, vec4(rgb, texture(a_data, y_uv).r));
}
