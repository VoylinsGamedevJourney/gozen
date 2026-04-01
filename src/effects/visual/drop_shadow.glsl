#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    float offset_x;
    float offset_y;
    float fade;
    vec4 color;
} params;



void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);
    if (id.x >= out_size.x || id.y >= out_size.y) {
		return;
	}

	vec4 fg_color = texelFetch(source_image, id, 0);
    ivec2 shadow_id = id - ivec2(params.offset_x, params.offset_y);
    vec4 shadow_color = vec4(0.0);
    float shadow_alpha = 0.0;
    if (params.fade > 0.0) { // Probably not great to have an if statement here.
        float weight_sum = 0.0;
        int NUM_SAMPLES = 32;

        for (int i = 0; i < NUM_SAMPLES; i++) {
            float theta = float(i) * 2.39996323;
            float r = (sqrt(float(i) + 0.5) / sqrt(float(NUM_SAMPLES))) * params.fade;
            ivec2 s_id = shadow_id + ivec2(round(cos(theta) * r), round(sin(theta) * r));

            if (s_id.x >= 0 && s_id.y >= 0 && s_id.x < out_size.x && s_id.y < out_size.y) {
                shadow_alpha += texelFetch(source_image, s_id, 0).a;
            }
            weight_sum += 1.0;
        }
        shadow_alpha /= weight_sum;
    } else {
        if (shadow_id.x >= 0 && shadow_id.y >= 0 && shadow_id.x < out_size.x && shadow_id.y < out_size.y) {
            shadow_alpha = texelFetch(source_image, shadow_id, 0).a;
        }
    }
    shadow_color = vec4(params.color.rgb, params.color.a * shadow_alpha);

    float out_a = fg_color.a + shadow_color.a * (1.0 - fg_color.a);
    vec3 out_rgb = vec3(0.0);
    if (out_a > 0.0) {
        out_rgb = (fg_color.rgb * fg_color.a + shadow_color.rgb * shadow_color.a * (1.0 - fg_color.a)) / out_a;
    }
    imageStore(output_image, id, vec4(out_rgb, out_a));
}
