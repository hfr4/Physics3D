varying vec3 fragment_position;
varying vec2 fragment_texcoord;
varying vec3 fragment_normal;
varying vec4 fragment_color;

varying vec3 initial_fragment_position;
varying vec3 initial_fragment_normal;

uniform mat4 projection_matrix;
uniform mat4 view_matrix;
uniform mat4 model_matrix;
uniform vec4 model_color;

#ifdef VERTEX_SHADER

layout (location = 0) in vec3 vertex_position;
layout (location = 1) in vec2 vertex_texcoord;
layout (location = 2) in vec3 vertex_normal;
layout (location = 3) in vec4 vertex_color;

void main() {
    initial_fragment_position = vertex_position;
    initial_fragment_normal   = vertex_normal;

    fragment_position = vertex_position * mat3(model_matrix);
    fragment_normal   = vertex_normal   * mat3(transpose(inverse(model_matrix)));
    fragment_texcoord = vertex_texcoord;
    fragment_color    = vertex_color;

    gl_Position = vec4(vertex_position, 1.0) * model_matrix * view_matrix * projection_matrix;
}

#endif

#ifdef FRAGMENT_SHADER

void main() {
    gl_FragColor = model_color * fragment_color;
}

#endif
