#version 430 core

in vec2 a_Position;

out vec2 v_TexCoord;

void main() {
    gl_Position = vec4(a_Position, 0.0, 1.0);

    /*
     * Convert normalized-device-coordinates [-1, 1]
     * to texture coordinates [0, 1].
     * Just scale and translate by 0.5.
     */
    v_TexCoord = a_Position * 0.5 + vec2(0.5, 0.5);
}
