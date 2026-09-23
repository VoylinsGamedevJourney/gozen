#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUTS ---
layout(set = 0, binding = 0) uniform sampler2D input_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float angle;
	int pass_index;
} params;
layout(set = 0, binding = 3, std140) uniform Progress { float value; } progress;



void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(output_image);
	if (id.x >= size.x || id.y >= size.y) {
		return;
	}

	vec4 color = texelFetch(input_image, id, 0);
	float angle_rad = radians(params.angle);
	vec2 dir = vec2(sin(angle_rad), -cos(angle_rad));

	vec2 uv = vec2(id) / vec2(size);
	vec2 center = vec2(0.5);
	float aspect = float(size.x) / float(size.y);

	vec2 uv_aspect = (uv - center) * vec2(aspect, 1.0);
	float max_proj = 0.5 * aspect * abs(dir.x) + 0.5 * abs(dir.y);
	float p = (dot(uv_aspect, dir) / (2.0 * max_proj)) + 0.5;

	if (p > progress.value) {
		color.a = 0.0;
	}

	imageStore(output_image, id, color);
}
