#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	vec2 factor;
} params;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec2 uv = vec2(id) / vec2(out_size);
	vec2 centered_uv = uv - 0.5;

	vec2 sheared_uv;
	sheared_uv.x = centered_uv.x - (params.factor.x * centered_uv.y);
	sheared_uv.y = centered_uv.y - (params.factor.y * centered_uv.x);
	sheared_uv += 0.5;

	vec4 color = vec4(0.0);
	if (sheared_uv.x >= 0.0 && sheared_uv.x <= 1.0 && sheared_uv.y >= 0.0 && sheared_uv.y <= 1.0) {
		color = textureLod(source_image, sheared_uv, 0.0);
	}

	imageStore(output_image, id, color);
}
