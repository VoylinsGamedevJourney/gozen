#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float left;
	float right;
	float top;
	float bottom;
} params;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);

	if (id.x >= out_size.x || id.y >= out_size.y) {
		return; // Boundary check.
	}

	vec4 color = texelFetch(source_image, id, 0);
	vec2 uv = vec2(id) / vec2(out_size);
	float l = params.left / 100.0;
	float r = 1.0 - (params.right / 100.0);
	float t = params.top / 100.0;
	float b = 1.0 - (params.bottom / 100.0);
	if (uv.x < l || uv.x > r || uv.y < t || uv.y > b) {
		color = vec4(0.0);
	}
	imageStore(output_image, id, color);
}
