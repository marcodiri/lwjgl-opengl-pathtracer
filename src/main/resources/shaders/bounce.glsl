#version 330 core

#define N_OUT  1.0 // vacuum refractive index
#define N_IN   1.5 // glass refractive index

/**
 * Samples a cosine weighted random point on the hemisphere around the
 * given normal and outputs a vector passing through the point.
 * source: https://stackoverflow.com/q/24758507
 */
vec3 cos_weighted_sample_on_hemisphere(vec2 rand);

vec3 diffuse_reflect(vec3 normal, vec3 rand) {
    vec3 s = cos_weighted_sample_on_hemisphere(rand.xy);
    vec3 h = normal;
    if (abs(h.x) <= abs(h.y) && abs(h.x) <= abs(h.z))
    h.x= 1.0;
    else if (abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z))
    h.y= 1.0;
    else
    h.z= 1.0;

    vec3 u = normalize(cross(h,normal));
    vec3 v = normalize(cross(u,normal));

    vec3 direction = s.x * u + s.y * v + s.z * normal;
    return normalize(direction);
}

/**
 * Reflection of an ideally reflecting material (mirror)
 */
vec3 ideal_specular_reflect(vec3 direction, vec3 normal) {
    return direction - 2.0 * dot(direction, normal) * normal;
}

/*
 * Refraction effect of refractive material (glass)
 */
float reflectance0(float n1, float n2) {
    float sqrt_R0 = (n1 - n2) / (n1 + n2);
    return sqrt_R0 * sqrt_R0;
}

float schlick_reflectance(float n1, float n2, float c) {
    float R0 = reflectance0(n1, n2);
    return R0 + (1.0 - R0) * c * c * c * c * c;
}

vec4 ideal_specular_transmit(vec3 d, vec3 n, bool out_to_in, vec3 rand) {
    vec3 d_Re = ideal_specular_reflect(d, n);
    float nn = out_to_in ? N_OUT/N_IN : N_IN/N_OUT;
    float cos_theta = dot(d, n);
    float cos2_phi = 1.0 - nn * nn * (1.0 - cos_theta * cos_theta);

    // total internal reflection
    if (cos2_phi < 0) {
        return vec4(d_Re, 1.0);
    }

    vec3 d_Tr = normalize(nn * d - n * (nn * cos_theta + sqrt(cos2_phi)));
    float c = 1.0 - (out_to_in ? -cos_theta : dot(d_Tr, -n));

    float Re = schlick_reflectance(N_OUT, N_IN, c);
    float p_Re = 0.25 + 0.5 * Re;
    if (rand.z < p_Re){
        return vec4(d_Re, Re/p_Re);
    } else {
        float Tr = 1.0 - Re;
        float p_Tr = 1.0 - p_Re;
        return vec4(d_Tr, Tr/p_Tr);
    }
}
