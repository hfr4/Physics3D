Box_Shape :: struct {
    half_size: Vector3;
    points:    [8] Vector3;
}

make_box_shape :: (x: float, y: float, z: float) -> Box_Shape {
    box: Box_Shape;

    CORNERS :: Vector3.[
        .{ -1, -1, -1 },
        .{  1, -1, -1 },
        .{ -1,  1, -1 },
        .{  1,  1, -1 },
        .{ -1, -1,  1 },
        .{  1, -1,  1 },
        .{ -1,  1,  1 },
        .{  1,  1,  1 },
    ];

    for CORNERS {
        box.points[it_index] = it * Vector3.{ x, y, z }; 
    }

    box.half_size = .{ x, y, z };

    return box;
}

make_box_shape :: (half_size: float) -> Box_Shape {
    return make_box_shape(half_size, half_size, half_size);
}

get_aabb :: (using box: Box_Shape, pos: Vector3, rot: Quaternion) -> AABB {
    transformed_aabb: AABB;
    for points expand(*transformed_aabb, rotate(it, rot));

    transformed_aabb.min += pos;
    transformed_aabb.max += pos;

    return transformed_aabb;
}

get_inertia_tensor :: (using box: Box_Shape) -> Matrix3 {
    dx := half_size.x * 2.0;
    dy := half_size.y * 2.0;
    dz := half_size.z * 2.0;

    inertia_tensor: Matrix3;
    inertia_tensor.coef[0][0] = ( dy * dy + dz * dz ) / 12.0;
    inertia_tensor.coef[1][1] = ( dx * dx + dz * dz ) / 12.0;
    inertia_tensor.coef[2][2] = ( dx * dx + dy * dy ) / 12.0;

    return inertia_tensor;
}

get_support_point :: (using box: Box_Shape, dir: Vector3, pos: Vector3, rot: Quaternion, bias: float) -> Vector3 {
    max_point := rotate(points[0], rot) + pos;
    max_dist  := dot(dir, max_point);
    
    for points {
        point := rotate(it, rot) + pos;
        dist  := dot(dir, point);

        if dist > max_dist {
            max_dist  = dist;
            max_point = point;
        }
    }

    return max_point + normalize(dir) * bias;
}
