#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS --- (std140 requires 16 byte blocks)
// mat4 = 64 bytes
// float = 4 bytes
layout(set = 0, binding = 2, std140) uniform Params {
	mat4 transform_matrix;	// offset = 0
	float alpha;			// offset = 64
} params; // 68 bytes



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy); // Target pixel id
	ivec2 out_size = imageSize(output_image);

	if (id.x >= out_size.x || id.y >= out_size.y) return; // Boundary check

	vec4 target_pixel = vec4(float(id.x), float(id.y), 0.0, 1.0);
	vec4 source_position = params.transform_matrix * target_pixel;
	vec2 src_size = vec2(textureSize(source_image, 0));
	vec2 uv = source_position.xy / src_size;
	vec4 color;

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		color = vec4(0.0);
	} else {
		color = textureLod(source_image, uv, 0.0);
		color.a *= params.alpha;
	}

	imageStore(output_image, id, color);
}
