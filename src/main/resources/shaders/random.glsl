#version 330 core

#define PI     3.14159265359
#define TWO_PI 6.28318530718

/**
 * Samples a cosine weighted random point on the hemisphere around the
 * given normal 'n' and outputs a vector passing through the point.
 * source: https://stackoverflow.com/q/24758507
 */
vec3 cos_weighted_random_hemisphere_direction(vec3 n, vec2 rand) {
    float cos_theta = sqrt(1.0-rand.x);
    float sin_theta = sqrt(rand.x);
    float phi = TWO_PI * rand.y;

    float xs = sin_theta * cos(phi);
    float ys = sin_theta * sin(phi);
    float zs = cos_theta;

    vec3 h = n;
    if (abs(h.x) <= abs(h.y) && abs(h.x) <= abs(h.z))
        h.x= 1.0;
    else if (abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z))
        h.y= 1.0;
    else
        h.z= 1.0;

    vec3 u = normalize(cross(h,n));
    vec3 v = normalize(cross(u,n));

    vec3 direction = xs * u + ys * v + zs * n;
    return normalize(direction);
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
