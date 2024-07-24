Body :: struct {
    shape:            *Shape;
    position:         Vector3;
    rotation:         Quaternion = .{ 0, 0, 0, 1 };
    linear_velocity:  Vector3;
    angular_velocity: Vector3;
    inv_mass:         float;
    elasticity:       float;
    friction:         float;
}

deinit :: (using body: *Body) {
    free(shape);
}

update :: (using body: *Body, dt: float) {
    position += linear_velocity * dt;

    position_cm := center_of_mass_local(body);
    cm_to_pos   := position - position_cm;

    rotation_matrix := ToMat3(rotation);
    inertia_tensor  := rotation_matrix * get_inertia_tensor(body) * transpose(rotation_matrix);
    alpha           := inverse(inertia_tensor) * cross(angular_velocity, inertia_tensor * angular_velocity);
    angular_velocity += alpha * dt;

    d_angle := angular_velocity * dt;
    dq: Quaternion;
    set_from_axis_and_angle(*dq, d_angle, length(d_angle));
    rotation = dq * rotation;
    normalize_or_identity(*rotation);

    position = position_cm + rotate(cm_to_pos, dq);
}

is_static :: (using body: *Body) -> bool {
    return inv_mass == 0.0;
}

apply_impulse_at_point :: (using body: *Body, impulse: Vector3, point: Vector3) {
    if inv_mass == 0.0 return;

    apply_linear_impulse(body, impulse);
    angular_impulse := cross(point - center_of_mass_local(body), impulse);
    apply_angular_impulse(body, angular_impulse);
}

apply_linear_impulse :: (using body: *Body, impulse: Vector3) {
    if inv_mass == 0.0 return;

    linear_velocity += impulse * inv_mass;
}

apply_angular_impulse :: (using body: *Body, impulse: Vector3) {
    if inv_mass == 0.0 return;

    angular_velocity += inertia_tensor_inv_world(body) * impulse;

    MAX_ANGULAR_SPEED :: 30.0;
    if length_squared(angular_velocity) > MAX_ANGULAR_SPEED * MAX_ANGULAR_SPEED {
        normalize(*angular_velocity);
        angular_velocity *= MAX_ANGULAR_SPEED;
    }
}

center_of_mass_local :: (using body: Body) -> Vector3 {
    center_of_mass := shape.center_of_mass;
    pos            := position + rotate(center_of_mass, rotation);
    return pos;
}

center_of_mass_world :: (using body: Body) -> Vector3 {
    center_of_mass := shape.center_of_mass;
    return center_of_mass;
}

world_to_local :: (using body: Body, worldPt: Vector3) -> Vector3 {
    tmp              := worldPt - center_of_mass_local(body);
    inverse_rotation := Inverse(rotation);
    body_space       := rotate(tmp, inverse_rotation);
    return body_space;
}

local_to_world :: (using body: Body, worldPt: Vector3) -> Vector3 {
    world_space := center_of_mass_local(body) + rotate(worldPt, rotation);
    return world_space;
}

get_aabb :: (using body: Body) -> AABB {
    if #complete shape.kind == {
        case .SPHERE; return get_aabb(cast(*Sphere_Shape) shape, position, rotation);
        case .BOX;    return get_aabb(cast(*Box_Shape)    shape, position, rotation);
    }
}

get_support_point :: (using body: Body, dir: Vector3, bias: float) -> Vector3 {
        if #complete shape.kind == {
        case .SPHERE; return get_support_point(cast(*Sphere_Shape) shape, dir, position, rotation, bias);
        case .BOX;    return get_support_point(cast(*Box_Shape)    shape, dir, position, rotation, bias);
    }
}

get_inertia_tensor :: (using body: Body) -> Matrix3 {
    if #complete shape.kind == {
        case .SPHERE; return get_inertia_tensor(cast(*Sphere_Shape) shape);
        case .BOX;    return get_inertia_tensor(cast(*Box_Shape)    shape);
    }
}

inertia_tensor_inv_local :: (using body: Body) -> Matrix3 {
    inertia_tensor     := get_inertia_tensor(body);
    inv_inertia_tensor := inverse(inertia_tensor) * inv_mass;
    return inv_inertia_tensor;
}

inertia_tensor_inv_world :: (using body: Body) -> Matrix3 {
    inertia_tensor     := get_inertia_tensor(body);
    inv_inertia_tensor := inverse(inertia_tensor) * inv_mass;
    rotation_matrix    := ToMat3(rotation);
    inv_inertia_tensor = rotation_matrix * inv_inertia_tensor * transpose(rotation_matrix);
    return inv_inertia_tensor;
}
