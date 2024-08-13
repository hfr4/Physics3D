Camera :: struct {
    near:         float   = 0.1;
    far:          float   = 1000.0;
    fov:          float   = PI / 3.0;
    position:     Vector3 = .{ 0, 0, 0 };
    direction:    Vector3 = .{ 0, 0, 1 };
    up:           Vector3 = .{ 0, 1, 0 };
    width:        float;
    height:       float;
    aspect_ratio: float;
    near_plane:   Plane;
    far_plane:    Plane;
    p_matrix:     Matrix4;
    v_matrix:     Matrix4;
    pv_matrix:    Matrix4;
    ip_matrix:    Matrix4;
    iv_matrix:    Matrix4;
    ipv_matrix:   Matrix4;
}

init :: (camera: *Camera, width: float, height: float) {
    camera.width  = width;
    camera.height = height;

    update(camera);
}

update :: (using camera: *Camera) {
    aspect_ratio = get_aspect_ratio(camera);
    near_plane   = get_near_plane(camera);
    far_plane    = get_far_plane(camera);
    p_matrix     = get_projection_matrix(camera);
    v_matrix     = get_view_matrix(camera);
    pv_matrix    = p_matrix * v_matrix;
    ip_matrix    = inverse(p_matrix);
    iv_matrix    = inverse(v_matrix);
    ipv_matrix   = ip_matrix * iv_matrix;
}

get_yaw :: (using camera: Camera) -> float {
    return -atan2(direction.z, direction.x) + PI / 2.0;
}

get_pitch :: (using camera: Camera) -> float {
    return -atan2(direction.y, length(Vector2.{ direction.x, direction.z }));
}

get_near_plane :: (using camera: Camera) -> Plane {
    return .{ position + (direction * near), direction };
}

get_far_plane :: (using camera: Camera) -> Plane {
    return .{ position + (direction * far), direction };
}

get_aspect_ratio :: (using camera: Camera) -> float {
    return width / height;
}

get_projection_matrix :: (using camera: Camera) -> Matrix4 {
    return make_perspective_matrix4(fov, near, far, aspect_ratio);
}

get_view_matrix :: (using camera: Camera) -> Matrix4 {
    return make_view_matrix4(position, direction, up);
}

look_in_direction :: (using camera: *Camera, yaw: float, pitch: float) {    
    direction = .{
        sin(yaw)   * max(abs(cos(pitch)), .001),
        sin(pitch) * -1,
        cos(yaw)   * max(abs(cos(pitch)), .001)
    };
}

look_at :: (using camera: *Camera, target: Vector3) {
    dir := target - position;
    if dir.x == 0  dir.x = .001;

    yaw   := -atan2(dir.z, dir.x) + PI/2;
    pitch := -atan2(dir.y, sqrt(dir.x*dir.x + dir.z*dir.z));

    look_in_direction(camera, yaw, pitch);
}

look_at_delta :: (using camera: *Camera, delta: Vector2) {
    yaw   := get_yaw(camera)   + delta.x;
    pitch := get_pitch(camera) + delta.y;
    Clamp(*pitch, -PI/2, PI/2);

    look_in_direction(camera, yaw, pitch);
}

screen_to_world :: (using camera: Camera, point: Vector2) -> Vector3 {
    ndc := (2 * point / Vector2.{ width, height }) - .{1, 1};
    ndc.y *= -1; // [0, 0] at top-left TODO: replace with cam.up
    vc  := ip_matrix * Vector4.{ ndc.x, ndc.y, -1, 1 };
    wc  := iv_matrix * Vector4.{ vc.x, vc.y, -1, 0 };

    return normalize(wc.xyz);
}

world_to_screen :: (using camera: Camera, point: Vector3) -> Vector3, bool {
    is_point_aligned_with_plane := dot(point - near_plane.position, near_plane.normal) >= 0;
    if !is_point_aligned_with_plane return .{}, false;

    ndc := pv_matrix * Vector4.{ point.x, point.y, point.z,1 } ;
    sc  := Vector2.{ (ndc.x + 1) / 2 * width, (ndc.y + 1) / 2 * height };

    return .{ sc.x, sc.y, ndc.z }, true;
}

Camera_Direction :: enum {
    LEFT;
    RIGHT;
    BACK;
    FORTH;
    AWAY_FROM;
    TOWARD;
    UP;
    DOWN;
}

move_noclip :: (using camera: *Camera, dir: Camera_Direction, distance: float) {
    dx, dy, dz: float;

    if dir == {     
        case .UP;         position.y += distance; 
        case .DOWN;       position.y -= distance;   
        case .LEFT;       dx = -1;
        case .RIGHT;      dx =  1;
        case .FORTH;      dy = -1;
        case .BACK;       dy =  1;
        case .AWAY_FROM;  dz = -1;
        case .TOWARD;     dz =  1;
    }

    yaw   := get_yaw(camera);
    pitch := get_pitch(camera);

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
