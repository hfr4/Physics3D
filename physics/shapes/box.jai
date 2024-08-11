Box_Shape :: struct {
    extents: Vector3;
    points:  [8] Vector3;
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

    box.extents = .{ x, y, z };

    return box;
}

make_box_shape :: (extents: float) -> Box_Shape {
    return make_box_shape(extents, extents, extents);
}

get_aabb :: (using box: Box_Shape, pos: Vector3, rot: Quaternion) -> AABB {
    aabb: AABB;

    for points expand(*aabb, rotate(it, rot));
    aabb.min += pos;
    aabb.max += pos;

    return aabb;
}

get_inertia_tensor :: (using box: Box_Shape) -> Matrix3 {
    tensor: Matrix3;

    dx := extents.x * 2.0;
    dy := extents.y * 2.0;
    dz := extents.z * 2.0;

    tensor.coef[0][0] = ( dy * dy + dz * dz ) / 12.0;
    tensor.coef[1][1] = ( dx * dx + dz * dz ) / 12.0;
    tensor.coef[2][2] = ( dx * dx + dy * dy ) / 12.0;

    return tensor;
}
