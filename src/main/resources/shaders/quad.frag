#version 430 core

in vec2 v_TexCoord;

/*
 * Hard bind the "color" out variable to color fragment 0
 * to avoid automatic assignment
 * https://www.khronos.org/opengl/wiki/Fragment_Shader#Outputs
 */
layout(location = 0) out vec4 color;

/*
 * Bind the sampler to texture unit 0
 * same thing as doing glUniform1i(u_Sampler_location, 0) on the host
 * https://www.khronos.org/opengl/wiki/Layout_Qualifier_(GLSL)#Binding_points
 */
layout(binding = 0) uniform sampler2D u_Sampler;

void main() {
    color = texture(u_Sampler, v_TexCoord);
}
