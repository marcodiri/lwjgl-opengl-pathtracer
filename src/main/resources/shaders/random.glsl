#version 330 core

#define PI     3.14159265359
#define TWO_PI 6.28318530718

vec3 cos_weighted_sample_on_hemisphere(vec2 rand) {
    float cos_theta = sqrt(1.0-rand.x);
    float sin_theta = sqrt(rand.x);
    float phi = TWO_PI * rand.y;

    float xs = sin_theta * cos(phi);
    float ys = sin_theta * sin(phi);
    float zs = cos_theta;

    return vec3(xs, ys, zs);
}

/**
 * Generate random numbers in [0,1).
 * The hash function can be anything good and fast.
 * This is very important as it changes the convercence properties of the scene.
 * A long list can be found here: https://www.shadertoy.com/view/XlGcRh
 */
vec3 hashwithoutsine33(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

vec3 random(vec3 f) {
    return hashwithoutsine33(f);
}
