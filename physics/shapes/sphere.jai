Sphere_Shape :: struct {
    radius: float;
}


make_sphere_shape :: (radius: float) -> Sphere_Shape {
    sphere: Sphere_Shape;

    sphere.radius = radius;

    return sphere;
}

get_aabb :: (using sphere: Sphere_Shape, pos: Vector3, rot: Quaternion) -> AABB {
    aabb: AABB;

    aabb.min = pos + .{ -radius, -radius, -radius };
    aabb.max = pos + .{  radius,  radius,  radius };

    return aabb;
}

get_support_point :: (using sphere: Sphere_Shape, dir: Vector3, pos: Vector3, rot: Quaternion, bias: float) -> Vector3 {
    return pos + dir * ( radius + bias );
}

get_inertia_tensor :: (using sphere: Sphere_Shape) -> Matrix3 {
    tensor: Matrix3;

    tensor.coef[0][0] = 2.0 * radius * radius / 5.0;
    tensor.coef[1][1] = 2.0 * radius * radius / 5.0;
    tensor.coef[2][2] = 2.0 * radius * radius / 5.0;

    return tensor;
}
