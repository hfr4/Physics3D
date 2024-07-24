varying vec3 fragment_position;
varying vec2 fragment_texcoord;
varying vec3 fragment_normal;

varying vec3 initial_fragment_position;
varying vec3 initial_fragment_normal;

uniform mat4 proj_matrix;
uniform mat4 view_matrix;
uniform mat4 model_matrix;
uniform vec4 color;

#ifdef VERTEX_SHADER

layout (location = 0) in vec3 vertex_position;
layout (location = 1) in vec2 vertex_texcoord;
layout (location = 2) in vec3 vertex_normal;

void main() {
    initial_fragment_position = vertex_position;
    initial_fragment_normal   = vertex_normal;

    fragment_position = vertex_position * mat3(model_matrix);
    fragment_texcoord = vertex_texcoord;
    fragment_normal   = vertex_normal   * mat3(transpose(inverse(model_matrix)));

    gl_Position = vec4(vertex_position, 1.0) * model_matrix * view_matrix * proj_matrix;
}

#endif

#ifdef FRAGMENT_SHADER

vec3 get_color_from_position_and_normal(vec3 worldPosition, vec3 normal ) {
    const float pi = 3.141519;

    vec3 scaledPos1 = worldPosition.xyz * pi * 2.0;
    vec3 scaledPos2 = worldPosition.xyz * pi * 2.0 / 10.0 + vec3( pi / 4.0 );
    
    float s = cos( scaledPos2.x ) * cos( scaledPos2.y ) * cos( scaledPos2.z );  // [-1,1] range
    float t = cos( scaledPos1.x ) * cos( scaledPos1.y ) * cos( scaledPos1.z );  // [-1,1] range

    vec3 color_multiplier = vec3( 0.5, 0.5, 1.0 );

    if (abs( normal.x ) > abs( normal.y ) && abs( normal.x ) > abs( normal.z )) {
        color_multiplier = vec3( 1.0, 0.5, 0.5 );
    } else if (abs( normal.y ) > abs( normal.x ) && abs( normal.y ) > abs( normal.z )) {
        color_multiplier = vec3( 0.5, 1.0, 0.5 );
    }

    t =  ceil( t * 0.9 );
    s = (ceil( s * 0.9 ) + 3.0) * 0.25;

    vec3 colorB  = vec3( 0.85, 0.85, 0.85 );
    vec3 colorA  = vec3( 1.00, 1.00, 1.00 );
    vec3 colorAB = mix( colorA, colorB, t ) * s;

    return color_multiplier * colorAB;
}

void main() {
    vec4 final_color = vec4(0.0, 0.0, 0.0, 1.0);

    if (color == vec4(1.0, 1.0, 1.0, 1.0)) {
        float dx = 0.25;
        float dy = 0.25;
        vec3 color_multiplier = vec3( 0.0, 0.0, 0.0 );
        for ( float y = 0.0; y < 1.0; y += dy ) {
            for ( float x = 0.0; x < 1.0; x += dx ) {
                vec3 samplePos = initial_fragment_position + dFdx( initial_fragment_position ) * x + dFdy( initial_fragment_position ) * y;
                color_multiplier += get_color_from_position_and_normal( samplePos, initial_fragment_normal ) * dx * dy;
            }
        }
        
        final_color.rgb = color_multiplier.rgb;


        gl_FragColor = final_color * color;
    } else {
        gl_FragColor = color;
    }
}

#endif
