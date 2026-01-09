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
// int/float = 4 bytes
layout(set = 0, binding = 5, std140) uniform Params {
	mat4 color_matrix;	// Offset 0
	ivec2 resolution;	// Offset 64
	int interlaced;		// Offset 72
} params; // Ends at byte 80 (/16 = 5 blocks)



void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    
    if (id.x >= params.resolution.x || id.y >= params.resolution.y)
        return; // Checking boundary

	vec2 texture_uv = (vec2(id) + 0.5) / params.resolution;
	vec3 yuv = vec3(
		texture(y_data, texture_uv).r,
		texture(u_data, texture_uv).r,
		texture(v_data, texture_uv).r
	);

	if (params.interlaced > 0) {
		float pixel_height = 1.0 / params.resolution.y;
		float offset_direction = (params.interlaced == 1) ? -pixel_height: pixel_height;
		vec2 offset_uv = clamp(texture_uv + vec2(0.0, offset_direction), 0.0, 1.0);
		vec3 yuv_neighbor = vec3(
			texture(y_data, offset_uv).r,
			texture(u_data, offset_uv).r,
			texture(v_data, offset_uv).r
		);

		yuv = mix(yuv, yuv_neighbor, 0.5);
	}

	vec3 rgb = (params.color_matrix * vec4(yuv, 1.0)).rgb;
    imageStore(output_image, id, vec4(rgb, texture(a_data, texture_uv).r));
}
