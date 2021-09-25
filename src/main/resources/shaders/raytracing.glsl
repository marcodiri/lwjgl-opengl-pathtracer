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

#define NEAR 1E-4
#define FAR 1E+10

/*
 * Sphere representation, scene, intersect algorithm taken from
 * http://kevinbeason.com/smallpt/
 */
struct sphere {
    float radius;
    vec3 center;
    float emission;
};

#define NUM_SPHERES 9
const sphere spheres[NUM_SPHERES] = {
{ 1E5 , vec3(1E5 + 1, 40.8, 81.6)  , -1.0 }, // left wall
{ 1E5 , vec3(-1E5 + 99, 40.8, 81.6), -1.0 }, // right wall
{ 1E5 , vec3(50, 40.8, 1E5)        , -1.0 }, // back wall
{ 1E5 , vec3(50, 40.8, -1E5 + 270) , -1.0 }, // front wall
{ 1E5 , vec3(50, 1E5, 81.6)        , -1.0 }, // bottom wall (floor)
{ 1E5 , vec3(50, -1E5 + 81.6, 81.6), -1.0 }, // top wall
{ 16.5, vec3(27, 16.5, 47)         , -1.0 }, // mirroring sphere (specular material)
{ 16.5, vec3(73, 16.5, 78)         , -1.0 }, // glass sphere (refractive material)
{ 600 , vec3(50, 681.6 - .27, 81.6), 10.0 }  // light
};

// decleare functions in random.glsl
vec4 random(vec2 f);
vec3 cos_weighted_random_hemisphere_direction(vec3 n, vec2 rand);

vec4 rand;

struct hitinfo {
    float t_near;
    int id;
};

/**
 * Computes the value of the parameter t=(tmin,tmax) at the enter and exit point
 * of the ray = 'origin + t * direction' in the sphere.
 * If no intersection is found t=(-1,-1).
 * @param origin the starting point of the ray
 * @param direction the direction of the ray
 * @param s the sphere testing for intersection
 * @return (tmin,tmax) if intersection is found or (-1,-1) otherwise
 */
vec2 intersect(vec3 origin, vec3 direction, const sphere s) {
    vec3 op = s.center - origin;
    float dop = dot(op, direction);
    float D = dop * dop - dot(op, op) + s.radius * s.radius;
    if (D < 0)
        return vec2(-1.0);
    float sqrtD = sqrt(D);
    float tmin = dop - sqrtD;
    float tmax = dop + sqrtD;
    // if tmax < 0 the sphere is behind
    if (tmin < tmax && tmax >= 0.0)
        return vec2(tmin, tmax);
    return vec2(-1.0);
}

/**
 * Computes the intersection between the ray and every sphere and returns
 * information in the 'info' output varible.
 * @param origin the starting point of the ray
 * @param direction the direction of the ray
 * @param info the variable in which to save intersection information
 * @return true if the ray intersects a sphere, false otherwise
 */
bool intersectAll(vec3 origin, vec3 direction, out hitinfo info) {
    vec2 ray_t = vec2(NEAR, FAR);
    bool found = false;
    for (int i = 0; i < NUM_SPHERES; i++) {
        vec2 t = intersect(origin, direction, spheres[i]);
        /*
         * if the sphere we hit is behind us, t.x and t.y are both negative,
         * otherwise:
         * t.x can be positive or negative depending on wether we are
         * outside or inside the sphere, respectively;
         * t.y will always be positive.
         */
        if (ray_t.x < t.x && t.x < ray_t.y) {
            ray_t.y = t.x;
            info.t_near = t.x;
            info.id = i;
            found = true;
        }
        if (ray_t.x < t.y && t.y < ray_t.y) {
            ray_t.y = t.y;
            info.t_near = t.y;
            info.id = i;
            found = true;
        }
    }
    return found;
}

/*
 * Compute the normal of a sphere at the given point.
 * @param p a point on the sphere
 * @param s the sphere
 * @return the unit vector normal to 's' at 'p'
 */
vec3 normalForSphere(vec3 p, const sphere s) {
    return normalize(p - s.center);
}

/**
 * For now, just return some shade of gray based on the sphere index.
 * @param origin the starting point of the ray
 * @param direction the direction of the ray
 * @return the color of the pixel intersected by the ray
 */
vec3 radiance(vec3 origin, vec3 direction) {
    vec3 albedo = vec3(1.0); // amount of incoming light that gets reflected off of the surface
    vec3 radiance = vec3(0.0);
    for (int b = 0; b < 5; b++) {
        hitinfo hit;
        vec3 normal;
        if (intersectAll(origin, direction, hit)) {
            sphere s = spheres[hit.id];
            vec3 hit_point = origin + direction * hit.t_near;
            normal = normalForSphere(hit_point, s);
            // if we are inside the sphere the normal should point inward
            normal = dot(normal, direction) > 0 ? normal : -normal;

            vec3 color = vec3(hit.id / 10.0 + 0.1);
            albedo *= color;
            if (s.emission > 0) {
                radiance += albedo * s.emission;
            }

            /*
             * Because of float precision the hit point may be a tad inside the sphere,
             * so move the origin a bit along the normal just to be sure we are out
             */
            origin = hit_point + normal * NEAR;
            direction = cos_weighted_random_hemisphere_direction(normal, rand.xy);
        } else {
            break;
        }
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
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

    // take the size of our window (same size of the texture)
    ivec2 size = imageSize(u_Framebuffer);

    /*
     * Check for boundary conditions, if this thread is assigned a pixel
     * out of our window dimension, terminate it immediately.
     */
    if (pixel.x >= size.x || pixel.y >= size.y) {
        return;
    }

    // init random values
    rand = random(vec2(pixel));

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