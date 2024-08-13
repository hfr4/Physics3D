

Triangle :: struct {
    a, b, c: Vector3;
}

Sphere :: struct {
    position: Vector3;
    radius:   float;
}

Contact :: struct {
    on_A:   Vector3;
    on_B:   Vector3;
    depth:  float;
    normal: Vector3;
}

get_normal :: (using triangle: Triangle) -> Vector3 {
    return normalize(cross(b - a, c - b));
}

get_center :: (using quad: Quad) -> Vector3 {
    return (a + b + c + d) / 4.0;
}

make_transformation_matrix4 :: (tra: Vector3, rot: Quaternion, sca: Vector3) -> Matrix4 {
    result := Matrix4_Identity;
    result *= make_translation_matrix4(tra);
    result *= rotation_matrix(Matrix4, rot);
    result *= make_scale_matrix4(sca);

    return result;
}

make_transformation_matrix4 :: (tra: Vector3, rot: Quaternion, sca: float) -> Matrix4 {
    return make_transformation_matrix4(tra, rot, .{ sca, sca, sca });
}

make_perspective_matrix4 :: (fov: float, near: float, far: float, aspect_ratio: float) -> Matrix4 {
    a :=  1 / (tan(fov / 2) * aspect_ratio);
    b :=  1 / tan(fov / 2);
    c := -1 * (far + near)     / (far - near);
    d := -1 * (far * near * 2) / (far - near);

    return .{
        a, 0, 0 , 0,
        0, b, 0 , 0,
        0, 0, c , d,
        0, 0, -1, 0,
    };
}

make_view_matrix4 :: (pos: Vector3, dir: Vector3, up: Vector3) -> Matrix4 {
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