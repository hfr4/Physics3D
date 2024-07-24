#import "Basic";
#import "File";
#import "Math";
#import "SDL";
#import "GL";
#import "Random";

#load "camera.jai";
#load "mat4.jai";

#load "physics/world.jai";
#load "physics/body.jai";
#load "physics/broadphase.jai";
#load "physics/narrowphase.jai";
#load "physics/solver.jai";
#load "physics/EPA.jai";
#load "physics/utils.jai";

#load "physics/shapes/shape.jai";
#load "physics/shapes/sphere.jai";
#load "physics/shapes/box.jai";

WINDOW_NAME   :: "Physics 3D";
WINDOW_WIDTH  :: 1600.0;
WINDOW_HEIGHT :: 900.0;

window:      *SDL_Window;
gl_context:  SDL_GLContext;

current_time: float64;

is_down_q:      bool;  
is_down_d:      bool;
is_down_z:      bool;  
is_down_s:      bool;  
is_down_1:      bool;  
is_down_2:      bool;  
is_down_LSHIFT: bool;
is_down_LCTRL:  bool;
is_down_SPACE:  bool;
is_down_mouse:  bool;

my_physics_world: World;
my_camera:        Camera;

checker_shader: GLuint;

sphere_vertices: [..] Vertex;
box_vertices:    [..] Vertex;
plane_vertices:  [..] Vertex;

sphere_vao: GLuint;
box_vao:    GLuint;
plane_vao:  GLuint;

update_physics := true;
play_one_physics_step: bool;

main :: () {
    SDL_Init(SDL_INIT_EVERYTHING);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    window     = SDL_CreateWindow(WINDOW_NAME, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, xx WINDOW_WIDTH, xx WINDOW_HEIGHT, SDL_WINDOW_OPENGL|SDL_WINDOW_SHOWN);
    gl_context = SDL_GL_CreateContext(window);
    SDL_GL_MakeCurrent(window, gl_context);
    gl_load(*gl, SDL_GL_GetProcAddress);

    glEnable(GL_DEPTH_TEST);

    checker_shader  = make_shader_program("assets/shaders/checker.glsl");
    sphere_vertices = make_vertices("assets/obj/sphere.obj");
    sphere_vao      = make_vao(sphere_vertices);
    box_vertices    = make_vertices("assets/obj/box.obj");
    box_vao         = make_vao(box_vertices);
    plane_vertices  = make_vertices("assets/obj/plane.obj");
    plane_vao       = make_vao(plane_vertices);

    init(*my_camera,
        near      = 0.1, 
        far       = 1000.0, 
        fov       = PI/3.0, 
        width     = WINDOW_WIDTH, 
        height    = WINDOW_HEIGHT, 
        position  = .{ 0, 17, -8 }, 
        direction = .{ 0.17, -0.67, 0.71}, 
        up        = .{ 0, 1, 0 },
    );

    Initialize_Scene_Box();

    while true {
        dt := cast(float) (seconds_since_init() - current_time);
        current_time += dt;

        event: SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case .SDL_QUIT;
                    return;

                case .SDL_KEYDOWN; 
                    if event.key.keysym.sym == {
                        case .SDLK_q;       is_down_q      = true;
                        case .SDLK_d;       is_down_d      = true;
                        case .SDLK_z;       is_down_z      = true;
                        case .SDLK_s;       is_down_s      = true;
                        case .SDLK_LSHIFT;  is_down_LSHIFT = true;
                        case .SDLK_LCTRL;   is_down_LCTRL  = true;                 
                        case .SDLK_SPACE;   is_down_SPACE  = true; update_physics = !update_physics;  
                        case .SDLK_1;       is_down_1      = true; Add_Sphere();
                        case .SDLK_2;       is_down_2      = true; Add_Box();
                        case .SDLK_r;       Reset_Scene_Sphere();
                        case .SDLK_t;       Reset_Scene_Box();
                        case .SDLK_f;       play_one_physics_step = true;
                    }

                case .SDL_KEYUP; 
                    if event.key.keysym.sym == {
                        case .SDLK_q;       is_down_q      = false;
                        case .SDLK_d;       is_down_d      = false;
                        case .SDLK_z;       is_down_z      = false;
                        case .SDLK_s;       is_down_s      = false;
                        case .SDLK_LSHIFT;  is_down_LSHIFT = false;
                        case .SDLK_LCTRL;   is_down_LCTRL  = false;
                        case .SDLK_SPACE;   is_down_SPACE  = false;
                        case .SDLK_1;       is_down_1      = false;
                        case .SDLK_2;       is_down_2      = false;
                    }

                case .SDL_MOUSEBUTTONUP;
                    is_down_mouse = false;
                
                case .SDL_MOUSEBUTTONDOWN;
                    is_down_mouse = true;

                case .SDL_MOUSEMOTION;
                    delta := Vector2.{ xx event.motion.xrel, xx event.motion.yrel } * 0.003;
                    if is_down_mouse  look_at_delta(*my_camera, delta);
            }
        }

        {
            if is_down_q      then move_noclip(*my_camera, .LEFT  , .1);
            if is_down_d      then move_noclip(*my_camera, .RIGHT , .1);
            if is_down_z      then move_noclip(*my_camera, .TOWARD, .1);
            if is_down_s      then move_noclip(*my_camera, .BACK  , .1);
            if is_down_LSHIFT then move_noclip(*my_camera, .UP    , .1);
            if is_down_LCTRL  then move_noclip(*my_camera, .DOWN  , .1);

            update(*my_camera);

            if update_physics || play_one_physics_step {
                apply_gravity(*my_physics_world);
                update(*my_physics_world, dt);

                for my_physics_world.bodies {
                    if it.position.y < -20 {
                        deinit(it);
                        remove it;
                    }
                }

                if play_one_physics_step then play_one_physics_step = false;
            }
        }

        {
            glViewport(0, 0, xx WINDOW_WIDTH, xx WINDOW_HEIGHT);
            glClearColor(0.1, 0.2, 0.25, 1.0);
            glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

            glUseProgram(checker_shader);

            {
                loc := glGetUniformLocation(checker_shader, "proj_matrix");
                p_matrix := get_projection_matrix(my_camera);
                glUniformMatrix4fv(loc, 1, false, xx *p_matrix);
            }

            {
                loc := glGetUniformLocation(checker_shader, "view_matrix");
                v_matrix := get_view_matrix(my_camera);
                glUniformMatrix4fv(loc, 1, false, xx *v_matrix);
            }

            {
                loc := glGetUniformLocation(checker_shader, "camera_position");
                glUniform3fv(loc, 1, xx *my_camera.position);
            }

            {
                loc := glGetUniformLocation(checker_shader, "object_shineness");
                glUniform1f(loc, 128.0);
            }

            {
                color := Vector4.{ 1, 1, 1, 1 };
                loc := glGetUniformLocation(checker_shader, "color");
                glUniform4fv(loc, 1, xx *color );
            }

            for my_physics_world.bodies {
                if it.shape.kind == {
                    case .SPHERE;
                        loc_color := glGetUniformLocation(checker_shader, "color");
                        loc_mat   := glGetUniformLocation(checker_shader, "model_matrix");
                    
                        color := Vector4.{ 1, 1, 1, 1 };
                        sca := (cast(*Sphere_Shape) it.shape).radius;
                        mat := mat4_transformation_matrix(it.position, it.rotation, sca);
            
                        glBindVertexArray(sphere_vao);
                        glUniform4fv(loc_color, 1, xx *color);
                        glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
                        glDrawArrays(GL_TRIANGLES, 0, xx sphere_vertices.count);

                    case .BOX;
                        loc_color := glGetUniformLocation(checker_shader, "color");
                        loc_mat   := glGetUniformLocation(checker_shader, "model_matrix");
                    
                        color := Vector4.{ 1, 1, 1, 1 };
                        sca := (cast(*Box_Shape) it.shape).size;
                        mat := mat4_transformation_matrix(it.position, it.rotation, sca);
                
                        glBindVertexArray(box_vao);
                        glUniform4fv(loc_color, 1, xx *color );
                        glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
                        glDrawArrays(GL_TRIANGLES, 0, xx box_vertices.count);
                } 
/*
                aabb := get_aabb(it);
                glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
                draw_3d_aabb(aabb, .{ 1, 1, 0, 1});
                glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
*/
            }

/*
            quadtree: Octree;
            init(*quadtree, my_physics_world,, temp);
            glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
            for quadtree.nodes {
                draw_3d_aabb(it.aabb, .{ 1, 0, 1, 1});
            }
            glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
*/
            SDL_GL_SwapWindow(window);
        }

        SDL_Delay(10);

        reset_temporary_storage();
    }
}

Reset_Scene_Sphere :: () {
    deinit(*my_physics_world);
    Initialize_Scene_Sphere();
}

Reset_Scene_Box :: () {
    deinit(*my_physics_world);
    Initialize_Scene_Box();
}

Initialize_Scene_Empty :: () {
}

Initialize_Scene_Sphere :: () {
    shape := New(Sphere_Shape);
    shape.radius = 5.0;

    body := New(Body);
    body.shape           = shape;
    body.position        = .{ 0, 0, 0 };
    body.rotation        = .{ 0, 0, 0, 1 };
    body.linear_velocity = .{}; 
    body.inv_mass = 0.0;
    body.elasticity      = 0.99;
    body.friction        = 0.5;

    array_add(*my_physics_world.bodies, body);
}

Initialize_Scene_Box :: () {
    shape := New(Box_Shape);
    init(shape, 10.0, 1.0, 10.0);

    body := New(Body);
    body.shape           = shape;
    body.position        = .{ 0, 0, 0 };
    body.rotation        = .{ 0, 0, 0, 1 };
    body.linear_velocity = .{}; 
    body.inv_mass = 0.0;
    body.elasticity      = 0.99;
    body.friction        = 0.5;

    array_add(*my_physics_world.bodies, body);
}


Add_Sphere :: () {
    sphere := New(Sphere_Shape);
    sphere.radius = 1.0;

    body := New(Body);
    body.shape           = sphere;
    body.position        = .{ random_get_within_range(-0.5, 0.5), random_get_within_range(20, 25), random_get_within_range(-0.5, 0.5) };
    body.rotation        = .{ 0, 0, 0, 1 };
    body.linear_velocity = .{};
    body.inv_mass = 1.0;
    body.elasticity      = 0.5;
    body.friction        = 0.5;

    array_add(*my_physics_world.bodies, body);
}

Add_Box :: () {
    box := New(Box_Shape);
    init(box);

    body := New(Body);
    body.shape           = box;
    body.position        = .{ random_get_within_range(-0.5, 0.5), random_get_within_range(20, 25), random_get_within_range(-0.5, 0.5) };
    body.rotation        = .{ 0, 0, 0, 1 };
    body.linear_velocity = .{};
    body.inv_mass = 1.0;
    body.elasticity      = 0.5;
    body.friction        = 0.5;

    array_add(*my_physics_world.bodies, body);
}

draw_3d_point :: (pos: Vector3, color: Vector4 = .{ 1, 1, 1, 1 }, size := .3) {
    mat := mat4_transformation_matrix(pos, Quaternion.{0, 0, 0, 1}, size);

    loc_mat   := glGetUniformLocation(checker_shader, "model_matrix");
    loc_color := glGetUniformLocation(checker_shader, "color");

    glBindVertexArray(sphere_vao);
    glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
    glUniform4fv(loc_color, 1, xx *color);
    glDrawArrays(GL_TRIANGLES, 0, xx sphere_vertices.count);
}

draw_3d_point :: (x: float, y: float, z: float, color: Vector4 = .{ 1, 1, 1, 1}, size := .3) {
    draw_3d_point(.{x, y, z}, color, size);
}

draw_3d_obb :: (obb: OBB, color: Vector4 = .{ 1, 1, 1, 1}) {
    mat := mat4_transformation_matrix(obb.position, ToQuaternion(obb.rotation), obb.half_size);

    loc_mat   := glGetUniformLocation(checker_shader, "model_matrix");
    loc_color := glGetUniformLocation(checker_shader, "color");

    glBindVertexArray(box_vao);
    glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
    glUniform4fv(loc_color, 1, xx *color);
    glDrawArrays(GL_TRIANGLES, 0, xx box_vertices.count);
}

draw_3d_aabb :: (aabb: AABB, color: Vector4 = .{ 1, 1, 1, 1}) {
    pos := aabb.min + (aabb.max - aabb.min) / 2.0;
    sca := (aabb.max - aabb.min) * .5; 
    mat := mat4_transformation_matrix(pos, Quaternion.{ 0, 0, 0, 1}, sca);

    loc_mat   := glGetUniformLocation(checker_shader, "model_matrix");
    loc_color := glGetUniformLocation(checker_shader, "color");

    glBindVertexArray(box_vao);
    glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
    glUniform4fv(loc_color, 1, xx *color);
    glDrawArrays(GL_TRIANGLES, 0, xx box_vertices.count);
}

draw_3d_plane :: (plane: Plane, color: Vector4 = .{ 1, 1, 1, 1}) {
    q: Quaternion;
    set_from_axis_and_angle(*q, .{ plane.normal.z, plane.normal.y, plane.normal.x} , PI/2);

    mat := mat4_transformation_matrix(plane.position, q, .{ 4, 4, 4 });

    loc_mat   := glGetUniformLocation(checker_shader, "model_matrix");
    loc_color := glGetUniformLocation(checker_shader, "color");

    glBindVertexArray(plane_vao);
    glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
    glUniform4fv(loc_color, 1, xx *color);
    glDrawArrays(GL_TRIANGLES, 0, xx plane_vertices.count);
}


draw_3d_segment :: (segment: Segment, color: Vector4 = .{ 1, 1, 1, .99}) {
    draw_3d_point(segment.a, .{ 1, 0, 0, 1 }, .2);

    l := length(segment.b - segment.a);
    n := normalize(segment.b - segment.a);

    for 0.. cast(int) l {
        draw_3d_point(segment.a + cast(float) it * n, color, .1);
        draw_3d_point(segment.a + (cast(float) it + .5) * n, color, .1);
    }

    draw_3d_point(segment.b, .{ 0, 1, 0, 1 }, .2);
}

Vertex :: struct {
    position: Vector3;
    texcoord: Vector2;
    normal:   Vector3;
}

make_vertices :: (path: string) -> [..] Vertex {
    #import "String";

    string_count :: (str: string, substring: string) -> int {
        count       := 0;
        start_index := 0;

        while true {
            index := find_index_from_left(str, substring, start_index);
            if index == -1 break;
            start_index = index + substring.count;
            count += 1;
        }

        return count;
    }

    vertices: [..] Vertex;

    obj_string, ok := read_entire_file(path,, temp); 
    assert(ok);

    positions: [..] Vector3;
    texcoords: [..] Vector2;
    normals:   [..] Vector3;
    faces:     [..][3][3] int;

    positions.allocator = temp;
    texcoords.allocator = temp;
    normals.allocator   = temp;
    faces.allocator     = temp;

    lines := split(obj_string, "\n");

    for line: lines {
        words := split(line, " ");

        if words.count == 1 continue;

        if words[0] == {
            case "v";
                array_add(*positions, .{ string_to_float(words[1]), string_to_float(words[2]), string_to_float(words[3]) });
    
            case "vt";
                array_add(*texcoords, .{ string_to_float(words[1]), string_to_float(words[2]) });
    
            case "vn";
                array_add(*normals  , .{ string_to_float(words[1]), string_to_float(words[2]), string_to_float(words[3]) });
    
            case "f";
                // fan triangulation
                for 3..words.count - 1 {
                    face: [3][3] int;

                    triangulated_face_idxs := int.[1, it - 1, it];

                    for idx, j: triangulated_face_idxs {
                        dbl_slash_count := string_count(words[idx], "//");
                        slash_count     := string_count(words[idx], "/");

                        if dbl_slash_count == 1
                        {
                            idxs := split(words[idx], "//");
                            face[j][0] = string_to_int(idxs[0]) - 1;
                            face[j][1] = -1;
                            face[j][2] = string_to_int(idxs[1]) - 1;
                        } 
                        else if slash_count == 2
                        {
                            idxs := split(words[idx], "/");
                            face[j][0] = string_to_int(idxs[0]) - 1;
                            face[j][1] = string_to_int(idxs[1]) - 1;
                            face[j][2] = string_to_int(idxs[2]) - 1;
                        }
                        else if slash_count == 1
                        {
                            idxs := split(words[idx], "/");
                            face[j][0] = string_to_int(idxs[0]) - 1;
                            face[j][1] = string_to_int(idxs[1]) - 1;
                            face[j][2] = -1;
                        }
                        else if slash_count == 0
                        {
                            face[j][0] = string_to_int(words[idx]) - 1;
                            face[j][1] = -1;
                            face[j][2] = -1;
                        }
                    }

                    array_add(*faces, face);
                }
        }
    }

    for face: faces {
        v0, v1, v2: Vertex;

        if face[0][0] != -1  v0.position = positions[face[0][0]];
        if face[1][0] != -1  v1.position = positions[face[1][0]];
        if face[2][0] != -1  v2.position = positions[face[2][0]];

        if face[0][1] != -1  v0.texcoord = texcoords[face[0][1]];
        if face[1][1] != -1  v1.texcoord = texcoords[face[1][1]];
        if face[2][1] != -1  v2.texcoord = texcoords[face[2][1]];

        CALCULATE_VERTEX_NORMALS :: true;
        #if CALCULATE_VERTEX_NORMALS {
            triangle_normal :: (a: Vector3, b: Vector3, c: Vector3) -> Vector3 {
                return normalize(cross(b - a, c - b));
            }

            normal := triangle_normal(v0.position, v1.position, v2.position);
            v0.normal = normal;
            v1.normal = normal;
            v2.normal = normal;
        } else {
            if face[0][2] != -1  v0.normal = normals[face[0][2]];
            if face[1][2] != -1  v1.normal = normals[face[1][2]];
            if face[2][2] != -1  v2.normal = normals[face[2][2]];
        }

        array_add(*vertices, v0, v1, v2);
    }

    return vertices;
}

make_vao :: (vertices: [] Vertex) -> GLuint {
    vao: GLuint;
    vbo: GLuint; 

    glGenVertexArrays(1, *vao);
    glGenBuffers(1, *vbo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    defer glBindVertexArray(0); 
    defer glBindBuffer(GL_ARRAY_BUFFER, 0);

    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * vertices.count, vertices.data, GL_STREAM_DRAW);

    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glEnableVertexAttribArray(2);

    offset: *Vertex;
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, xx size_of(Vertex), xx *offset.position);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, xx size_of(Vertex), xx *offset.texcoord);
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, xx size_of(Vertex), xx *offset.normal);

    return vao;
}

create_texture :: (filename: string) -> GLuint {
    stbi :: #import "stb_image";

    texture_w, texture_h, channels: s32;
    texture_data := stbi.stbi_load(temp_c_string(filename), *texture_w, *texture_h, *channels, 0);
    defer stbi.stbi_image_free(texture_data);

    texture: GLuint;
    glGenTextures(1, *texture);

    glBindTexture(GL_TEXTURE_2D, texture);
    defer glBindTexture(GL_TEXTURE_2D, 0);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture_w, xx texture_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, texture_data);

    return texture;
}

make_shader_program :: (filename: string) -> GLuint {
    LOG_BUFFER_SIZE :: 512;

    shader_text := read_entire_file(filename);
    defer free(shader_text.data);

    make_shader_object :: (shader: string, prefix: string, shader_type : GLenum) -> GLuint {
        shader_object := glCreateShader(shader_type);

        shaders: [2] *u8;
        lengths: [2] s32;

        shaders[0] = prefix.data;
        shaders[1] = shader.data;
        lengths[0] = xx prefix.count;
        lengths[1] = xx shader.count;

        glShaderSource(shader_object, 2, shaders.data, lengths.data);

        glCompileShader(shader_object);

        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success then {
            log_data: [LOG_BUFFER_SIZE]u8;
            glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
            assert(false, to_string(log_data.data));
            return 0;
        }

        return shader_object;
    }

    PREFIX_V :: #string END
    #version 330 core
    #define VERTEX_SHADER
    END

    PREFIX_F :: #string END
    #version 330 core
    #define FRAGMENT_SHADER
    END
    
    shader_v := make_shader_object(shader_text, PREFIX_V, GL_VERTEX_SHADER);
    shader_f := make_shader_object(shader_text, PREFIX_F, GL_FRAGMENT_SHADER);
    defer glDeleteShader(shader_v);
    defer glDeleteShader(shader_f);

    shader_p := glCreateProgram();

    glAttachShader(shader_p, shader_v);
    glAttachShader(shader_p, shader_f);
    glLinkProgram(shader_p);

    success: GLint;
    glGetProgramiv(shader_p, GL_LINK_STATUS, *success);

    if !success then {
        log_data: [LOG_BUFFER_SIZE] u8;
        glGetProgramInfoLog(shader_p, log_data.count, null, log_data.data);
        assert(false, to_string(log_data.data));
        return 0;
    } 

    return shader_p;
}
