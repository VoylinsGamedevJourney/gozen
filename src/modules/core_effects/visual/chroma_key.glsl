#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	vec4 key_color;
	float similarity;
	float smoothness;
} params;


vec3 rgb2yuv(vec3 c) {
	float y = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
	float u = -0.14713 * c.r - 0.28886 * c.g + 0.436 * c.b;
	float v = 0.615 * c.r - 0.51499 * c.g - 0.10001 * c.b;
	return vec3(y, u, v);
}


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return; // Boundary check
	}

	vec4 color = texelFetch(source_image, id, 0);
	vec3 yuv_color = rgb2yuv(color.rgb);
	vec3 yuv_key = rgb2yuv(params.key_color.rgb);
	float chroma_dist = distance(yuv_color.yz, yuv_key.yz);
	float luma_dist = abs(yuv_color.x - yuv_key.x);
	float base_dist = chroma_dist + (luma_dist * 0.2);

	float alpha_mask = smoothstep(params.similarity, params.similarity + params.smoothness + 0.0001, base_dist);
	color.a *= alpha_mask;
	if (alpha_mask < 1.0) {
		color.rgb = mix(vec3(yuv_color.x), color.rgb, alpha_mask);
	}
	imageStore(output_image, id, color);
}
