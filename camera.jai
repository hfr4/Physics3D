Camera_Plane :: struct {
    position: Vector3;
    normal:   Vector3;
}

Camera_Direction :: enum {
    LEFT;
    RIGHT;
    BACK;
    FORTH;
    AWAY_FROM;
    TOWARD;
    RIGHT_ABS;
    LEFT_ABS;
    FORTH_ABS;
    BACK_ABS;
    UP;
    DOWN;
}

Camera :: struct {
    near:         float;
    far:          float;
    fov:          float;
    width:        float;
    height:       float;
    position:     Vector3;
    direction:    Vector3;
    up:           Vector3;
    aspect_ratio: float;
    near_plane:   Camera_Plane;
    far_plane:    Camera_Plane;
}

init :: (cam: *Camera, near: float = 0.1, far: float = 1000.0, fov: float = PI/3, width: float, height: float, position: Vector3 = .{0,0,0}, direction: Vector3 = .{0,0,1}, up: Vector3 = .{0,1,0}) {
    cam.near      = near;
    cam.far       = far;
    cam.fov       = fov;
    cam.width     = width;
    cam.height    = height;
    cam.position  = position;
    cam.direction = direction;
    cam.up        = up;

    update(cam);
}

update :: (using cam: *Camera) {
    aspect_ratio = get_aspect_ratio(cam);
    near_plane   = get_near_plane(cam);
    far_plane    = get_far_plane(cam);
}

get_yaw :: (using cam: Camera) -> float {
    return -atan2(direction.z, direction.x) + PI/2;
}

get_pitch :: (using cam: Camera) -> float {
    return -atan2(direction.y, length(Vector2.{ direction.x, direction.z }));
}

get_near_plane :: (using cam: Camera) -> Camera_Plane {
    return .{ position + (direction * near), direction };
}

get_far_plane :: (using cam: Camera) -> Camera_Plane {
    return .{ position + (direction * far), direction };
}

get_aspect_ratio :: (using cam: Camera) -> float {
    return width / height;
}

get_projection_matrix :: (using cam: Camera) -> Matrix4 {
    return mat4_perspective_matrix(fov, near, far, aspect_ratio);
}

get_view_matrix :: (using cam: Camera) -> Matrix4 {
    return mat4_view_matrix(position, direction, up);
}

look_in_direction :: (using cam: *Camera, yaw: float, pitch: float) {    
    direction = .{
        sin(yaw)   * max(abs(cos(pitch)), .001),
        sin(pitch) * -1,
        cos(yaw)   * max(abs(cos(pitch)), .001)
    };
}

look_at :: (using cam: *Camera, target: Vector3) {
    dir := target - position;
    if dir.x == 0  dir.x = .001;

    yaw   := -atan2(dir.z, dir.x) + PI/2;
    pitch := -atan2(dir.y, sqrt(dir.x*dir.x + dir.z*dir.z));

    look_in_direction(cam, yaw, pitch);
}

look_at_delta :: (using cam: *Camera, delta: Vector2) {
    yaw   := get_yaw(cam)   + delta.x;
    pitch := get_pitch(cam) + delta.y;
    Clamp(*pitch, -PI/2, PI/2);

    look_in_direction(cam, yaw, pitch);
}

move_noclip :: (using cam: *Camera, dir: Camera_Direction, distance: float) {
    dx, dy, dz: float;

    if dir == {
        case .RIGHT_ABS;  position.x += distance;        
        case .LEFT_ABS;   position.x -= distance;       
        case .FORTH_ABS;  position.z += distance;        
        case .BACK_ABS;   position.z -= distance;       
        case .UP;         position.y += distance; 
        case .DOWN;       position.y -= distance;   
        case .LEFT;       dx = -1;
        case .RIGHT;      dx =  1;
        case .FORTH;      dy = -1;
        case .BACK;       dy =  1;
        case .AWAY_FROM;  dz = -1;
        case .TOWARD;     dz =  1;
    }

    yaw   := get_yaw(cam);
    pitch := get_pitch(cam);

    if dx != 0 || dy != 0 {
        angle := atan2(dy, dx);
        dir_x := cos(yaw + angle);   
        dir_z := sin(yaw + angle + PI);
        
        position.x += dir_x * distance;
        position.z += dir_z * distance;
    } else if dz != 0 {
        tx := sin(yaw) * max(abs(cos(pitch)), .001);
        ty := sin(pitch);
        tz := cos(yaw) * max(abs(cos(pitch)), .001);
        
        position.x += tx * dz * distance;
        position.y -= ty * dz * distance;
        position.z += tz * dz * distance;
    }
}
