#version 430 core

/*
 * Specify the number of threads per work group
 * https://www.khronos.org/opengl/wiki/Compute_Shader#Local_size
 */
layout (local_size_x = 16, local_size_y = 8) in;

/*
 * Bind the buffer to image unit 0 and set its format
 * same as doing glUniform1i(u_Framebuffer_location, 0) on the host
 * https://www.khronos.org/opengl/wiki/Layout_Qualifier_(GLSL)#Binding_points
 */
layout(binding = 0, rgba32f) uniform image2D u_Framebuffer;

/*
 * Eye coordinates with respect to world frame
 * and the four corner rays of our camera's viewing frustum
 * as suggested in:
 * https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-%28Part-I%29#camera
 */
uniform vec3 u_Eye, u_Ray00, u_Ray01, u_Ray10, u_Ray11;
uniform float u_Time; // useful for random number generation
uniform float u_BlendingFactor; // weigth of the old average with respect to the new frame

#define NEAR 1E-3
#define FAR 1E+10

// decleare functions in random.glsl
vec3 random(vec3 f);
vec3 cos_weighted_sample_on_hemisphere(vec3 n, vec2 rand);

ivec2 pixel;

struct HitInfo {
    float t_near;
    vec3 t_vec;
    int id;
    bool isSphere;
};

/*
 * Scene, intersect algorithms taken from
 * http://kevinbeason.com/smallpt/
 * https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-%28Part-I%29
 */
const struct {
    uint diffuse, specular, refractive;
} Material = {0, 1, 2};

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
    uint material;
};

#define NUM_BOXES 6
#define NUM_SPHERES 3

float W = 6, H = 5, D = 15;  // room width, height, depth
const Box boxes[NUM_BOXES] = {
{ vec3(  W,   0,  0), vec3(W+.1,    H,    D), vec3(.75, .25, .25), 0 },  // left wall
{ vec3(-.1,   0,  0), vec3(   0,    H,    D), vec3(.25, .25, .75), 0 },  // right wall
{ vec3(  0,   0,  0), vec3(   W,    H,   .1), vec3(.75, .75, .75), 0 },  // back wall
{ vec3(  0,   0,  D), vec3(   W,    H, D+.1), vec3(.75, .75, .75), 0 },  // front wall
{ vec3(  0, -.1,  0), vec3(   W,    0,    D), vec3(.75, .75, .75), 0 },  // floor
{ vec3(  0,   H,  0), vec3(   W, H+.1,    D), vec3(.75, .75, .75), 0 }   // ceiling
};

const Sphere spheres[NUM_SPHERES] = {
{     1, vec3(4.3,  1.0,  12.5), vec3(1),    0, Material.specular   },  // left sphere
{     1, vec3(1.7,  1.0,  11.2), vec3(1),    0, Material.refractive },  // right sphere
{ 18.03, vec3(W/2, 18+H, D*3/4), vec3(1), 30.0, Material.diffuse    }   // light
};

bool intersectBox(vec3 origin, vec3 direction, const Box b, const vec2 ray_t, out vec3 t_vec, out float t) {
    vec3 tMin = (b.min - origin) / direction;
    vec3 tMax = (b.max - origin) / direction;
    vec3 t1 = min(tMin, tMax);

    float tmin = max(max(t1.x, t1.y), t1.z);
    // ray origin outside box
    if (0.0 < tmin && tmin < ray_t.y) {
        t_vec = t1;
        t = tmin;
        return true;
    }

    // FIXME: ray origin inside box not implemented
    // vec3 t2 = max(tMin, tMax);
    // float tmax = min(min(t2.x, t2.y), t2.z);

    return false;
}

bool intersectSphere(vec3 origin, vec3 direction, const Sphere s, const vec2 ray_t, out float t) {
    vec3 op = s.center - origin;
    float dop = dot(op, direction);
    float D = dop * dop - dot(op, op) + s.radius * s.radius;
    if (D < 0)
        // no intersection
        return false;

    float sqrtD = sqrt(D);

    float tmin = dop - sqrtD;
    // ray origin outside sphere
    if (ray_t.x < tmin && tmin < ray_t.y) {
        t = tmin;
        return true;
    }

    float tmax = dop + sqrtD;
    // ray origin inside sphere
    if (ray_t.x < tmax && tmax < ray_t.y) {
        t = tmax;
        return true;
    }

    // if tmax < 0 the sphere is behind
    return false;
}

/**
 * Computes the intersection between the ray and every object and returns
 * information in the 'hit' output varible.
 * @param origin the starting point of the ray
 * @param direction the direction of the ray
 * @param hit the variable in which to save intersection information
 * @return true if the ray intersects an object, false otherwise
 */
bool intersect(vec3 origin, vec3 direction, out HitInfo hit) {
    vec2 ray_t = vec2(NEAR, FAR);
    float t = FAR;
    vec3 normal;
    bool found = false;

    for (int i = 0; i < NUM_BOXES; i++) {
        vec3 t_vec;
        if (intersectBox(origin, direction, boxes[i], ray_t, t_vec, t)) {
            ray_t.y = t;
            hit.t_near = ray_t.y;
            hit.t_vec = t_vec;
            hit.id = i;
            hit.isSphere = false;
            found = true;
        }
    }

    for (int i = 0; i < NUM_SPHERES; i++) {
        if (intersectSphere(origin, direction, spheres[i], ray_t, t)) {
            ray_t.y = t;
            hit.t_near = ray_t.y;
            hit.id = i;
            hit.isSphere = true;
            found = true;
        }
    }

    return found;
}

/**
 * Samples a cosine weighted random point on the hemisphere around the
 * given normal and outputs a vector passing through the point.
 * source: https://stackoverflow.com/q/24758507
 */
vec3 diffuse_reflect(vec3 normal, vec3 rand) {
    vec3 s = cos_weighted_sample_on_hemisphere(normal, rand.xy);
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
float n_out = 1.0; // vacuum refractive index
float n_in = 1.5;  // glass refractive index

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
    float nn = out_to_in ? n_out/n_in : n_in/n_out;
    float cos_theta = dot(d, n);
    float cos2_phi = 1.0 - nn * nn * (1.0 - cos_theta * cos_theta);

    // total internal reflection
    if (cos2_phi < 0) {
        return vec4(d_Re, 1.0);
    }

    vec3 d_Tr = normalize(nn * d - n * (nn * cos_theta + sqrt(cos2_phi)));
    float c = 1.0 - (out_to_in ? -cos_theta : dot(d_Tr, -n));

    float Re = schlick_reflectance(n_out, n_in, c);
    float p_Re = 0.25 + 0.5 * Re;
    if (rand.x < p_Re){
        return vec4(d_Re, Re/p_Re);
    } else {
        float Tr = 1.0 - Re;
        float p_Tr = 1.0 - p_Re;
        return vec4(d_Tr, Tr/p_Tr);
    }

}

/**
 * Solve the rendering equation.
 * @param origin the starting point of the ray
 * @param direction the direction of the ray
 * @return the color of the pixel intersected by the ray
 */
vec3 radiance(vec3 origin, vec3 direction) {
    vec3 albedo = vec3(1.0); // amount of incoming light that gets reflected off the surface
    vec3 radiance = vec3(0.0);

    for (int bounce = 0; bounce < 6; bounce++) {
        HitInfo hit;
        if (!intersect(origin, direction, hit))
            break;

        vec3 hit_point = origin + direction * hit.t_near;
        vec3 normal;

        vec3 color = vec3(1.0);
        float emission = 0;
        uint material = Material.diffuse;
        if (hit.isSphere) {
            Sphere s = spheres[hit.id];
            normal = normalize(origin + hit.t_near * direction - s.center);
            color = s.color;
            emission = s.emission;
            material = s.material;
        } else {
            Box b = boxes[hit.id];
            normal = vec3(equal(hit.t_vec, vec3(hit.t_near))) * sign(-direction);
            color = b.color;
            emission = b.emission;
        }
        albedo *= color;
        radiance += albedo * emission;

        // flip the normal in case the ray originated inside the object
        bool out_to_in = dot(direction, normal) < 0;
        normal = out_to_in ? normal : -normal;

        /*
         * Set the hit point as the origin of the bounce ray.
         * Because of float precision the hit point may be a tad inside the sphere,
         * so move the origin a bit along the normal to be sure we are outside the object.
         */
        origin = hit_point + normal * 1E-3;

        if (material == Material.specular) {
            direction = ideal_specular_reflect(direction, normal);
        } else if (material == Material.refractive) {
            vec3 rand = random(vec3(pixel+bounce, u_Time));
            vec4 r = ideal_specular_transmit(direction, normal, out_to_in, rand);
            origin = hit_point - normal * 1E-5;
            direction = r.xyz;
            albedo *= r.w;
        } else {
            vec3 rand = random(vec3(pixel+bounce, u_Time));
            direction = diffuse_reflect(normal, rand);
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
    vec3 direction = mix(mix(u_Ray00, u_Ray01, weight.y), mix(u_Ray10, u_Ray11, weight.y), weight.x);

    // compute the pixel color shooting the ray from the eye in the calculated direction
    vec3 newColor = radiance(u_Eye, normalize(direction));

    // load the previous pixel color
    vec3 oldColor= vec3(0);
    if (u_BlendingFactor > 0)
        oldColor = imageLoad(u_Framebuffer, pixel).rgb;

    // interpolate the new color with the old one
    vec3 color = mix(newColor, oldColor, u_BlendingFactor);

    // store the color in our texture framebuffer
    imageStore(u_Framebuffer, pixel, vec4(color, 1.0));
}