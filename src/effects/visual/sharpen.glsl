#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float amount;
} params;


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);

	if (id.x >= out_size.x || id.y >= out_size.y) {
		return; // Boundary check
	}

	if (params.amount <= 0.0) {
		imageStore(output_image, id, texelFetch(source_image, id, 0));
		return;
	}

	vec4 center = texelFetch(source_image, id, 0);
	vec4 up     = texelFetch(source_image, clamp(id + ivec2(0, -1), ivec2(0), out_size - ivec2(1)), 0);
	vec4 down   = texelFetch(source_image, clamp(id + ivec2(0, 1), ivec2(0), out_size - ivec2(1)), 0);
	vec4 left   = texelFetch(source_image, clamp(id + ivec2(-1, 0), ivec2(0), out_size - ivec2(1)), 0);
	vec4 right  = texelFetch(source_image, clamp(id + ivec2(1, 0), ivec2(0), out_size - ivec2(1)), 0);
	vec3 rgb = center.rgb * (1.0 + 4.0 * params.amount)
			 - up.rgb * params.amount
			 - down.rgb * params.amount
			 - left.rgb * params.amount
			 - right.rgb * params.amount;
	imageStore(output_image, id, vec4(clamp(rgb, 0.0, 1.0), center.a));
}
