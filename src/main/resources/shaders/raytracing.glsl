#version 430 core

/*
 * Specify the number of threads per work group
 * https://www.khronos.org/opengl/wiki/Compute_Shader#Local_size
 */
layout (local_size_x = 16, local_size_y = 8) in;

/*
 * Bind the buffer to image unit 0 and set its format
 * same thing as doing glUniform1i(u_Framebuffer_location, 0) on the host
 * https://www.khronos.org/opengl/wiki/Layout_Qualifier_(GLSL)#Binding_points
 */
layout(binding = 0, rgba32f) uniform image2D u_Framebuffer;

/*
 * Eye coordinates with respect to world frame
 * and the four corner rays of our camera's viewing frustum
 * as suggested in:
 * https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-%28Part-I%29#camera
 */
uniform vec3 eye, ray00, ray01, ray10, ray11;
uniform float time; // useful for random number generation

#define NEAR 1E-4
#define FAR 1E+10

// decleare functions in random.glsl
vec3 random(vec3 f);
vec3 cos_weighted_random_hemisphere_direction(vec3 n, vec2 rand);

ivec2 pixel;

struct hitinfo {
    float t_near;
    vec3 normal;
    int id;
    bool isSphere;
};

/*
 * Scene, intersect algorithms taken from
 * http://kevinbeason.com/smallpt/
 * https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-%28Part-I%29
 */
struct Box {
    vec3 min, max;
    vec3 color;
    float emission;
};

struct Sphere {
    float radius;
    vec3 center;
    vec3 color;
    float emission;
};

#define NUM_BOXES 6
#define NUM_SPHERES 3

float WIDTH = 6;
float HEIGHT = 5;
float DEPTH = 15;
const Box boxes[NUM_BOXES] = {
{ vec3(WIDTH,    0.0,   0.0), vec3(WIDTH+.1,    HEIGHT,    DEPTH), vec3(.75, .75, .75), 0.0 },  // left wall
{ vec3( -0.1,    0.0,   0.0), vec3(     0.0,    HEIGHT,    DEPTH), vec3(.75, .75, .75), 0.0 },  // right wall
{ vec3(  0.0,    0.0,   0.0), vec3(   WIDTH,    HEIGHT,      0.1), vec3(.25, .25, .75), 0.0 },  // back wall
{ vec3(  0.0,    0.0, DEPTH), vec3(   WIDTH,    HEIGHT, DEPTH+.1), vec3(.75, .25, .25), 0.0 },  // front wall
{ vec3(  0.0,   -0.1,   0.0), vec3(   WIDTH,       0.0,    DEPTH), vec3(.75, .75, .75), 0.0 },  // floor
{ vec3(  0.0, HEIGHT,   0.0), vec3(   WIDTH, HEIGHT+.1,    DEPTH), vec3(.75, .75, .75), 0.0 }   // ceiling
};

const Sphere spheres[NUM_SPHERES] = {
{   1.0, vec3(    4.3,      1.0,      12.5), vec3(1),  0.0 },
{   1.0, vec3(    1.7,      1.0,      11.2), vec3(1),  0.0 },
{ 18.03, vec3(WIDTH/2, 18.0+5.0, DEPTH*3/4), vec3(1), 30.0 }   // light
};

vec2 intersectBox(vec3 origin, vec3 direction, const Box b, out vec3 normal) {
    vec3 tMin = (b.min - origin) / direction;
    vec3 tMax = (b.max - origin) / direction;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tmin = max(max(t1.x, t1.y), t1.z);
    float tmax = min(min(t2.x, t2.y), t2.z);
    normal = vec3(equal(t1, vec3(tmin))) * sign(-direction);
    return vec2(tmin, tmax);
}

/**
 * Computes the value of the parameter t=(tmin,tmax) at the enter and exit point
 * of the ray = 'origin + t * direction' in the sphere.
 * If no intersection is found t=(-1,-1).
 * @param origin the starting point of the ray
 * @param direction the direction of the ray
 * @param s the sphere testing for intersection
 * @return (tmin,tmax) if intersection is found or (-1,-1) otherwise
 */
vec2 intersectSphere(vec3 origin, vec3 direction, const Sphere s, out vec3 normal) {
    vec3 op = s.center - origin;
    float dop = dot(op, direction);
    float D = dop * dop - dot(op, op) + s.radius * s.radius;
    if (D < 0)
        return vec2(-1.0);
    float sqrtD = sqrt(D);
    float tmin = dop - sqrtD;
    float tmax = dop + sqrtD;
    normal = normalize(origin + tmin * direction - s.center);
    // if tmax < 0 the sphere is behind
    if (tmin < tmax && tmax >= 0.0)
        return vec2(tmin, tmax);
    return vec2(-1.0);
}

/**
 * Computes the intersection between the ray and every object and returns
 * information in the 'info' output varible.
 * @param origin the starting point of the ray
 * @param direction the direction of the ray
 * @param info the variable in which to save intersection information
 * @return true if the ray intersects an object, false otherwise
 */
bool intersect(vec3 origin, vec3 direction, out hitinfo info) {
    vec2 ray_t = vec2(NEAR, FAR);
    bool found = false;
    vec3 normal;

    for (int i = 0; i < NUM_BOXES; i++) {
        vec2 t = intersectBox(origin, direction, boxes[i], normal);
        if (t.y >= 0.0 && t.x < t.y && t.x < ray_t.y) {
            ray_t.y = t.x;
            info.t_near = t.x;
            info.normal = normal;
            info.id = i;
            info.isSphere = false;
            found = true;
        }
    }

    for (int i = 0; i < NUM_SPHERES; i++) {
        vec2 t = intersectSphere(origin, direction, spheres[i], normal);
        if (t.y >= 0.0 && t.x < t.y && t.x < ray_t.y) {
            ray_t.y = t.x;
            info.t_near = t.x;
            info.normal = normal;
            info.id = i;
            info.isSphere = true;
            found = true;
        }
    }
    return found;
}

/**
 * For now, just return some shade of gray based on the sphere index.
 * @param origin the starting point of the ray
 * @param direction the direction of the ray
 * @return the color of the pixel intersected by the ray
 */
vec3 radiance(vec3 origin, vec3 direction) {
    vec3 albedo = vec3(1.0); // amount of incoming light that gets reflected off the surface
    vec3 radiance = vec3(0.0);

    for (int bounce = 0; bounce < 3; bounce++) {
        hitinfo hit;
        vec3 normal;

        if (!intersect(origin, direction, hit))
            break;

        vec3 hit_point = origin + direction * hit.t_near;
        normal = hit.normal;

        vec3 color = vec3(1.0);
        float emission = 0;
        if (hit.isSphere) {
            Sphere s = spheres[hit.id];
            color = s.color;
            emission = s.emission;
        } else {
            Box b = boxes[hit.id];
            color = b.color;
            emission = b.emission;
        }
        albedo *= color;
        radiance += albedo * emission;

        /*
         * Because of float precision the hit point may be a tad inside the sphere,
         * so move the origin a bit along the normal just to be sure we are out
         */
        origin = hit_point + normal * NEAR;

        vec3 rand = random(vec3(pixel+bounce, time));
        direction = cos_weighted_random_hemisphere_direction(normal, rand.xy);
    }
    // the ray did not hit any light source => the ray does not transport any light to the eye
    return radiance;
}

void main(void) {
    /*
     * The variable gl_GlobalInvocationID gives us this thread position
     * in the threads matrix. Since we assigned a pixel to each thread
     * we'll call this a pixel.
     */
    pixel = ivec2(gl_GlobalInvocationID.xy);

    // take the size of our window (same size of the texture)
    ivec2 size = imageSize(u_Framebuffer);

    /*
     * Check for boundary conditions, if this thread is assigned a pixel
     * out of our window dimension, terminate it immediately.
     */
    if (pixel.x >= size.x || pixel.y >= size.y) {
        return;
    }

    /*
     * As explaned in
     * https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-%28Part-I%29#camera
     * to compute the direction of our ray, firstly we linearly interpolate
     * the corner rays vertically with weight the vertical position of the current pixel,
     * then we linearly interpolate the results horizontally with weight the horizontal
     * position of the current pixel.
     */

    // normalize the pixel position in in [0, 1]
    vec2 weight = vec2(pixel) / vec2(size.x-1, size.y-1);

    /*
     * mix(x,y,a) = x * (1-a) + y * a
     * Suppose the current pixel is the bottom-right corner of the window
     * => weight = (1,0)
     * => mix(ray00, ray01, weight.y) = mix(ray00, ray01, 0) = ray00
     * => mix(ray10, ray11, weight.y) = mix(ray10, ray11, 0) = ray10
     * => direction = mix(ray00, ray10, weight.x) = mix(ray00, ray10, 1) = ray10
     * which is in fact the ray passing through the bottom-right corner.
     */
    vec3 direction = mix(mix(ray00, ray01, weight.y), mix(ray10, ray11, weight.y), weight.x);

    // compute the color shooting the ray from the eye in the calculated direction
    vec3 color = radiance(eye, normalize(direction));

    // store the color in our texture framebuffer
    imageStore(u_Framebuffer, pixel, vec4(color, 1.0));
}