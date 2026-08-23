#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- INPUT ---
layout(set = 0, binding = 0) uniform sampler2D source_image;

// --- OUTPUT ---
layout(rgba8, set = 0, binding = 1) uniform writeonly image2D output_image;

// --- PARAMS ---
layout(set = 0, binding = 2, std140) uniform Params {
    int point_count;
    vec4 points[64];
    int invert;
    float softness;
} params;



float dist_to_segment(vec2 point, vec2 v, vec2 w) { // Returns distance to the nearest segment.
    float length_squared = pow(distance(v, w), 2.0);
    if (length_squared == 0.0) return distance(point, v);
    float segment = max(0.0, min(1.0, dot(point - v, w - v) / length_squared));
    vec2 projection = v + segment * (w - v);
    return distance(point, projection);
}


bool is_inside(vec2 point, int count) { // Ray-Casting algorithm to check if point is inside the polygon.
    bool inside = false;
    for (int i = 0, j = count - 1; i < count; j = i++) {
        vec2 vector_i = params.points[i].xy;
        vec2 vector_j = params.points[j].xy;
        if (((vector_i.y > point.y) != (vector_j.y > point.y)) &&
            (point.x < (vector_j.x - vector_i.x) * (point.y - vector_i.y) / (vector_j.y - vector_i.y) + vector_i.x)) {
            inside = !inside;
        }
    }
    return inside;
}


void main() {
    ivec2 id = ivec2(gl_GlobalInvocationID.xy);
    ivec2 out_size = imageSize(output_image);
    if (id.x >= out_size.x || id.y >= out_size.y) return;

    vec4 color = texelFetch(source_image, id, 0);

    if (params.point_count < 3) { // Not enough points to form a polygon.
        if (params.invert > 0) color.a = 0.0;
        imageStore(output_image, id, color);
        return;
    }

    vec2 uv = vec2(id) / vec2(out_size);
    float aspect = float(out_size.x) / float(out_size.y);

    bool inside = is_inside(uv, params.point_count);
    float alpha = inside ? 1.0 : 0.0;

    if (params.softness > 0.0) { // Apply Feathering / Softness using SDF distance.
        float min_distance = 100000.0;
        vec2 aspect_p = uv * vec2(aspect, 1.0);

        for (int i = 0, j = params.point_count - 1; i < params.point_count; j = i++) {
            vec2 vector_i = params.points[i].xy * vec2(aspect, 1.0);
            vec2 vector_j = params.points[j].xy * vec2(aspect, 1.0);
            min_distance = min(min_distance, dist_to_segment(aspect_p, vector_i, vector_j));
        }

        // Negative distance outside, Positive distance inside.
        float distance = inside ? min_distance : -min_distance;
        alpha = smoothstep(-params.softness, params.softness, distance);
    }

    if (params.invert > 0) alpha = 1.0 - alpha;

    color.a *= alpha;
    imageStore(output_image, id, color);
}
