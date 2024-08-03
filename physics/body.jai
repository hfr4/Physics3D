Shape_Kind :: enum {
    SPHERE;
    BOX;
}

Body :: struct {
    kind: Shape_Kind;

    union {
        box:    Box_Shape;
        sphere: Sphere_Shape;
    }

    center_of_mass:   Vector3;
    position:         Vector3;
    rotation:         Quaternion = .{ 0, 0, 0, 1 };
    linear_velocity:  Vector3;
    angular_velocity: Vector3;
    inv_mass:         float;
    elasticity:       float;
    friction:         float;
}

update :: (using body: *Body, dt: float) {
    // Update position
    position += linear_velocity * dt;

    // Calculate and update angular velocity
    rotation_matrix := ToMat3(rotation);
    inertia_tensor  := rotation_matrix * get_inertia_tensor(body) * transpose(rotation_matrix);
    alpha           := inverse(inertia_tensor) * cross(angular_velocity, inertia_tensor * angular_velocity);
    angular_velocity += alpha * dt;

    // Update rotation
    angle_change := angular_velocity * dt;
    angle_change_magnitude := length(angle_change);
    rotation_change: Quaternion;
    set_from_axis_and_angle(*rotation_change, angle_change, angle_change_magnitude);
    rotation = rotation_change * rotation;
    normalize_or_identity(*rotation);

    // Update position based on new rotation
    com := get_local_center_of_mass(body);
    position = com + rotate(position - com, rotation_change);
}

is_static :: (using body: *Body) -> bool {
    return inv_mass == 0.0;
}

apply_impulse_at_point :: (using body: *Body, impulse: Vector3, point: Vector3) {
    if inv_mass == 0.0 return;

    apply_linear_impulse(body, impulse);

    angular_impulse := cross(point - get_local_center_of_mass(body), impulse);
    apply_angular_impulse(body, angular_impulse);
}

apply_linear_impulse :: (using body: *Body, impulse: Vector3) {
    if inv_mass == 0.0 return;

    linear_velocity += impulse * inv_mass;
}

apply_angular_impulse :: (using body: *Body, impulse: Vector3) {
    if inv_mass == 0.0 return;

    angular_velocity += get_inv_inertia_tensor(body) * impulse;

    MAX_ANGULAR_SPEED :: 30.0;
    if length_squared(angular_velocity) > MAX_ANGULAR_SPEED * MAX_ANGULAR_SPEED {
        normalize(*angular_velocity);
        angular_velocity *= MAX_ANGULAR_SPEED;
    }
}

get_local_center_of_mass :: (using body: Body) -> Vector3 {
    return position + rotate(center_of_mass, rotation);
}

world_to_local :: (using body: Body, point: Vector3) -> Vector3 {
    tmp              := point - get_local_center_of_mass(body);
    inverse_rotation := Inverse(rotation);
    body_space       := rotate(tmp, inverse_rotation);
    return body_space;
}

local_to_world :: (using body: Body, worldPt: Vector3) -> Vector3 {
    world_space := get_local_center_of_mass(body) + rotate(worldPt, rotation);
    return world_space;
}

get_aabb :: (using body: Body) -> AABB {
    if #complete kind == {
        case .SPHERE; return get_aabb(sphere, position, rotation);
        case .BOX;    return get_aabb(box, position, rotation);
    }
}

get_inertia_tensor :: (using body: Body) -> Matrix3 {
    if #complete kind == {
        case .SPHERE; return get_inertia_tensor(sphere);
        case .BOX;    return get_inertia_tensor(box);
    }
}

get_inv_inertia_tensor :: (using body: Body) -> Matrix3 {
    inertia_tensor  := get_inertia_tensor(body);
    rotation_matrix := ToMat3(rotation);
    return rotation_matrix * (inverse(inertia_tensor) * inv_mass) * transpose(rotation_matrix);
}
