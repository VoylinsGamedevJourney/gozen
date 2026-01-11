#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS --- (std140 requires 16 byte blocks)
// mat4 = 64 bytes
// vec2 = 8 bytes
// float = 4 bytes
layout(set = 0, binding = 2, std140) uniform Params {
	mat4 transform_matrix;	// Inverse transform matrix (offset = 0)
	vec2 texture_size;		// Source image size (offset = 64)
	ivec2 output_size;		// Project size (offset = 72)
	float alpha;			// Alpha value (offset = 80)
} params; // Ends at byte 94 (/16 = 6 blocks - 12 bytes padding)



void main() {
	// 1. Get the current pixel coordinate
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    
    // 2. Get the actual size of the input texture
    ivec2 size = textureSize(source_image, 0);

    // 3. Boundary check using the actual texture size
    if (id.x >= size.x || id.y >= size.y) {
        return; 
    }

    // 4. Fetch the exact pixel color at this integer coordinate
    // '0' is the mipmap level (base image)
    vec4 color = texelFetch(source_image, id, 0);

    // 5. Write directly to output
    imageStore(output_image, id, color);

//    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
//    
//    if (id.x >= params.output_size.x || id.y >= params.output_size.y)
//        return; // Checking boundary
//
//	vec4 target_pixel = vec4(float(id.x), float(id.y), 0.0, 1.0);
//	vec4 source_position = params.transform_matrix * target_pixel;
//	vec2 uv = source_position.xy / params.texture_size;
//
//	// UV boundary check
//	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
//		imageStore(output_image, id, vec4(0.0));
//	else {
//		vec4 color = texture(source_image, uv);
//
//		color.a *= params.alpha;
//
//		imageStore(output_image, id, color);
//	}
}
