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
 * Hash function to be used with the random number generator.
 */
uvec3 pcg3d(uvec3 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v ^= v >> 16u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

/**
 * Generate random numbers in [0,1).
 * The hash function can be anything good and fast.
 * A long list can be found here: https://www.shadertoy.com/view/XlGcRh
 * I chose pcg4d to generate a vector of 4 random numbers at once,
 * if you use a hash returning a single float you can just call the function
 * more times (with a different input).
 * source: https://amindforeverprogramming.blogspot.com/2013/07/random-floats-in-glsl-330.html
 */
vec3 random(vec3 f) {
    const uint mantissaMask = 0x007FFFFFu;
    const uint one          = 0x3F800000u;

    uvec3 s = floatBitsToUint(f);
    uvec3 h = pcg3d(s);
    h &= mantissaMask;
    h |= one;

    vec3  r2 = uintBitsToFloat(h);
    return r2 - 1.0;
}
