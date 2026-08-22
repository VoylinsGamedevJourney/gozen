#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float temperature;
	float tint;
} params;


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return; // Boundary check
	}

	vec4 color = texelFetch(source_image, id, 0);
	float r_adjust = 1.0 + (params.temperature * 0.3) + (params.tint * 0.1);
	float g_adjust = 1.0 - (params.tint * 0.3);
	float b_adjust = 1.0 - (params.temperature * 0.3) + (params.tint * 0.1);

	color.r = clamp(color.r * r_adjust, 0.0, 1.0);
	color.g = clamp(color.g * g_adjust, 0.0, 1.0);
	color.b = clamp(color.b * b_adjust, 0.0, 1.0);

	imageStore(output_image, id, color);
}
