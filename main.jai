#import "Basic";
#import "File";
#import "Math";
#import "SDL";
#import "GL";
#import "Random";

#load "camera.jai";
#load "utils.jai";
#load "opengl.jai";
#load "draw.jai";

#load "physics/world.jai";
#load "physics/body.jai";
#load "physics/broadphase.jai";
#load "physics/narrowphase.jai";
#load "physics/utils.jai";

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
    glLineWidth(2.0);

    init_draw_stuff();

    init(*my_camera, WINDOW_WIDTH, WINDOW_HEIGHT);
    my_camera.position  = .{ 0, 17, -8 };
    my_camera.direction = .{ 0.17, -0.67, 0.71};

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
                        case .SDLK_r;        Reset_Scene_Sphere();
                        case .SDLK_t;        Reset_Scene_Box();
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
        }

        draw_one_frame(dt);

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
    body := New(Body);
    body.kind            = .SPHERE; 
    body.sphere          = make_sphere_shape(5.0);
    body.position        = .{ 0, 0, 0 };
    body.rotation        = .{ 0, 0, 0, 1 };
    body.linear_velocity = .{}; 
    body.inv_mass        = 0.0;
    body.elasticity      = 0.99;
    body.friction        = 0.5;

    array_add(*my_physics_world.bodies, body);
}

Initialize_Scene_Box :: () {
    body := New(Body);
    body.kind            = .BOX; 
    body.box             = make_box_shape(10.0, 1.0, 10.0);
    body.position        = .{ 0, 0, 0 };
    body.rotation        = .{ 0, 0, 0, 1 };
    body.linear_velocity = .{}; 
    body.inv_mass        = 0.0;
    body.elasticity      = 0.99;
    body.friction        = 0.5;

    array_add(*my_physics_world.bodies, body);
}

Add_Sphere :: () {
    body := New(Body);
    body.kind            = .SPHERE; 
    body.sphere          = make_sphere_shape(1.0);
    body.position        = .{ random_get_within_range(-0.5, 0.5), random_get_within_range(20, 25), random_get_within_range(-0.5, 0.5) };
    body.rotation        = .{ 0, 0, 0, 1 };
    body.linear_velocity = .{};
    body.inv_mass        = 1.0;
    body.elasticity      = 0.5;
    body.friction        = 0.5;

    array_add(*my_physics_world.bodies, body);
}

Add_Box :: () {
    body := New(Body);
    body.kind            = .BOX;
    body.box             = make_box_shape(1.0);
    body.position        = .{ random_get_within_range(-0.5, 0.5), random_get_within_range(20, 25), random_get_within_range(-0.5, 0.5) };
    body.rotation        = .{ 0, 0, 0, 1 };
    body.linear_velocity = .{};
    body.inv_mass        = 1.0;
    body.elasticity      = 0.5;
    body.friction        = 0.5;

    array_add(*my_physics_world.bodies, body);
}

draw_one_frame :: (dt: float) {
    glViewport(0, 0, xx WINDOW_WIDTH, xx WINDOW_HEIGHT);
    glClearColor(0.1, 0.2, 0.25, 1.0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

    {
        glUseProgram(default_shader);

        loc: GLint;
        loc = glGetUniformLocation(default_shader, "projection_matrix");
        glUniformMatrix4fv(loc, 1, false, xx *my_camera.p_matrix);

        loc = glGetUniformLocation(default_shader, "view_matrix");
        glUniformMatrix4fv(loc, 1, false, xx *my_camera.v_matrix);

        loc = glGetUniformLocation(default_shader, "camera_position");
        glUniform3fv(loc, 1, xx *my_camera.position);

        color := Vector4.{ 1, 1, 1, 1 };
        loc = glGetUniformLocation(default_shader, "color");
        glUniform4fv(loc, 1, xx *color);
    }

    if update_physics || play_one_physics_step {
        apply_gravity(*my_physics_world);
        update(*my_physics_world, dt);

        for my_physics_world.bodies {
            if it.position.y < -20 {
                remove it;
            }
        }

        if play_one_physics_step then play_one_physics_step = false;
    }

    for my_physics_world.bodies {
        if it.kind == {
            case .SPHERE;
                loc_color := glGetUniformLocation(default_shader, "color");
                loc_mat   := glGetUniformLocation(default_shader, "model_matrix");
            
                color := Vector4.{ 1, 1, 1, 1 };
                sca := it.sphere.radius;
                mat := make_transformation_matrix4(it.position, it.rotation, sca);
    
                glBindVertexArray(bo_sphere.vao);
                glUniform4fv(loc_color, 1, xx *color);
                glUniformMatrix4fv(loc_mat, 1, false, xx *mat);
                glDrawArrays(GL_TRIANGLES, 0, xx vertices_sphere.count);

            case .BOX;
                obb := OBB.{ it.position, ToMat3(it.rotation), it.box.extents };
                for get_edges(obb) {
                    draw_3d_segment(it);
                }
        } 
    }

    draw_3d_buffer();

    SDL_GL_SwapWindow(window);
}
