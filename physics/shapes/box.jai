BOX_UNIT_CORNERS :: Vector3.[
    .{ -1, -1, -1 },
    .{  1, -1, -1 },
    .{ -1,  1, -1 },
    .{  1,  1, -1 },
    .{ -1, -1,  1 },
    .{  1, -1,  1 },
    .{ -1,  1,  1 },
    .{  1,  1,  1 },
];

Box_Shape :: struct {
    using #as base: Shape;
    kind = .BOX;

    size:   Vector3;
    points: [8] Vector3;
    aabb:   AABB;
}

init :: (using box: *Box_Shape, l: float = 1.0) {
    for BOX_UNIT_CORNERS {
        pt := it * l;

        points[it_index] = pt; 
        expand(*aabb, pt);
    }
    
    center_of_mass = ( aabb.max + aabb.min ) * 0.5;
    size           = .{ l, l, l };
}

init :: (using box: *Box_Shape, x: float, y: float, z: float) {
    for BOX_UNIT_CORNERS {
        pt := it * Vector3.{ x, y, z };

        points[it_index] = pt; 
        expand(*aabb, pt);
    }

    center_of_mass = ( aabb.max + aabb.min ) * 0.5;
    size          = .{ x, y, z };
}

get_aabb :: (using box: *Box_Shape, pos: Vector3, rot: Quaternion) -> AABB {
    transformed_aabb: AABB;
    for points expand(*transformed_aabb, rotate(it, rot));

    transformed_aabb.min += pos;
    transformed_aabb.max += pos;

    return transformed_aabb;
}

get_inertia_tensor :: (using box: *Box_Shape) -> Matrix3 {
    // Inertia tensor for box centered around zero
    dx := aabb.max.x - aabb.min.x;
    dy := aabb.max.y - aabb.min.y;
    dz := aabb.max.z - aabb.min.z;

    tensor: Matrix3;
    tensor.coef[0][0] = ( dy * dy + dz * dz ) / 12.0;
    tensor.coef[1][1] = ( dx * dx + dz * dz ) / 12.0;
    tensor.coef[2][2] = ( dx * dx + dy * dy ) / 12.0;

    // Now we need to use the parallel axis theorem to get the inertia tensor for a box
    // that is not centered around the origin

    cm: Vector3;
    cm.x = (aabb.max.x + aabb.min.x) * 0.5;
    cm.y = (aabb.max.y + aabb.min.y) * 0.5;
    cm.z = (aabb.max.z + aabb.min.z) * 0.5;

    ORIGIN :: Vector3.{ 0, 0, 0 };
    r  := ORIGIN - cm;    // the displacement from center of mass to the origin
    r2 := length_squared(r);

    pat_tensor: Matrix3;
    pat_tensor.v[0] = .{ r2 - r.x * r.x, r.x * r.y     , r.x * r.z      };
    pat_tensor.v[1] = .{ r.y * r.x     , r2 - r.y * r.y, r.y * r.z      };
    pat_tensor.v[2] = .{ r.z * r.x     , r.z * r.y     , r2 - r.z * r.z };

    // Now we need to add the center of mass tensor and the parallel axis theorem tensor together;
    tensor += pat_tensor;

    return tensor;
}

get_support_point :: (using box: *Box_Shape, dir: Vector3, pos: Vector3, rot: Quaternion, bias: float) -> Vector3 {
    max_pt   := rotate(points[0], rot) + pos;
    max_dist := dot(dir, max_pt);
    
    for points {
        pt   := rotate(it, rot) + pos;
        dist := dot(dir, pt);

        if dist > max_dist {
            max_dist = dist;
            max_pt   = pt;
        }
    }

    return max_pt + normalize(dir) * bias;
}
