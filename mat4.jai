mat4_transformation_matrix :: (tra: Vector3, rot: Vector3, sca: Vector3) -> Matrix4 {
    result := Matrix4_Identity;
    result *= mat4_translation_matrix(tra);
    result *= mat4_y_axis_rotation_matrix(rot.y);
    result *= mat4_x_axis_rotation_matrix(rot.x);
    result *= mat4_z_axis_rotation_matrix(rot.z);
    result *= mat4_scale_matrix(sca);

    return result;
}

mat4_transformation_matrix :: (tra: Vector3, rot: Vector3, sca: float) -> Matrix4 {
    return mat4_transformation_matrix(tra, rot, .{ sca, sca, sca });
}

mat4_transformation_matrix :: (tra: Vector3, rot: Quaternion, sca: Vector3) -> Matrix4 {
    result := Matrix4_Identity;
    result *= mat4_translation_matrix(tra);
    result *= mat4_quaternion_rotation_matrix(rot);
    result *= mat4_scale_matrix(sca);

    return result;
}

mat4_transformation_matrix :: (tra: Vector3, rot: Quaternion, sca: float) -> Matrix4 {
    return mat4_transformation_matrix(tra, rot, .{ sca, sca, sca });
}

mat4_translation_matrix :: (tra: Vector3) -> Matrix4 {
    return .{
        1, 0, 0, tra.x,
        0, 1, 0, tra.y,
        0, 0, 1, tra.z,
        0, 0, 0, 1,
    };
}

mat4_x_axis_rotation_matrix :: (rx: float) -> Matrix4 {
    return .{
        1, 0      ,  0       , 0,
        0, cos(rx), -sin(rx) , 0,
        0, sin(rx),  cos(rx) , 0,
        0, 0      ,  0       , 1,
    };
}

mat4_y_axis_rotation_matrix :: (ry: float) -> Matrix4 {
    return .{
        cos(ry), 0, sin(ry), 0,
        0      , 1, 0      , 0,
       -sin(ry), 0, cos(ry), 0,
        0      , 0, 0      , 1,
    };
}

mat4_z_axis_rotation_matrix :: (rz: float) -> Matrix4 {
    return .{
        cos(rz), -sin(rz), 0, 0,
        sin(rz), cos(rz) , 0, 0,
        0      , 0       , 1, 0,
        0      , 0       , 0, 1,
    };
}

mat4_quaternion_rotation_matrix :: (using q: Quaternion) -> Matrix4 {
    return .{
       -2*(y*y+z*z)+1,  2*(x*y-z*w)  ,  2*(x*z+y*w)  , 0,
        2*(x*y+z*w)  , -2*(x*x+z*z)+1,  2*(y*z-x*w)  , 0,
        2*(x*z-y*w)  ,  2*(y*z+x*w)  , -2*(x*x+y*y)+1, 0,
        0            ,  0            ,  0            , 1,
    };
}

mat4_scale_matrix :: (sca: Vector3) -> Matrix4 {
    return .{
        sca.x, 0    , 0    , 0,
        0    , sca.y, 0    , 0,
        0    , 0    , sca.z, 0,
        0    , 0    , 0    , 1,
    };
}

mat4_perspective_matrix :: (fov: float, near: float, far: float, aspect_ratio: float) -> Matrix4 {
    a :=  1 / (tan(fov / 2) * aspect_ratio);
    b :=  1 / (tan(fov / 2));
    c := -1 * (far + near) / (far - near);
    d := -1 * (far * near * 2) / (far - near);

    return .{
        a, 0, 0 , 0,
        0, b, 0 , 0,
        0, 0, c , d,
        0, 0, -1, 0,
    };
}

mat4_view_matrix :: (pos: Vector3, dir: Vector3, up: Vector3) -> Matrix4 {
    z := -normalize(dir);
    x := -normalize(cross(up, z));
    y := -cross(z, x);
    
    return .{
        x.x, x.y, x.z, -dot(x, pos),
        y.x, y.y, y.z, -dot(y, pos),
        z.x, z.y, z.z, -dot(z, pos),
        0  , 0  , 0  , 1
    };
}