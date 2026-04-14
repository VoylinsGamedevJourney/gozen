#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
	float waveAmpX;
	float waveFreqX;
  float wavePhaseX;
  float waveAmpY;
	float waveFreqY;
  float wavePhaseY;
  
} params;


void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	ivec2 out_size = imageSize(output_image);
	if (id.x >= out_size.x || id.y >= out_size.y) {
		return; // Boundary check.
	}

	vec2 uv = (vec2(id) + 0.5) / vec2(out_size);

  vec2 UVwave = uv;

  UVwave.x += sin(uv.y * waveFreqX + wavePhaseX) * waveAmpX;
  UVwave.y += cos(uv.x * waveFreqY + wavePhaseY) * waveAmpY;
	uv = UVwave;

	vec4 color = textureLod(source_image, uv, 0.0);
	imageStore(output_image, id, color);
}
