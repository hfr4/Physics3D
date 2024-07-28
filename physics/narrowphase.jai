Narrowphase_Contact :: struct {
    A:          *Body;
    B:          *Body;
    point_on_A: Vector3;
    point_on_B: Vector3;
    normal:     Vector3;  // In World Space coordinates
    depth:      float;    // positive when non-penetrating, negative when penetrating
}

get_narrowphase_contacts :: (broadphase_contacts: [..] Broadphase_Contact) -> [..] Narrowphase_Contact {
    narrowphase_contacts: [..] Narrowphase_Contact;

    for broadphase_contacts {
        contact: Narrowphase_Contact;
        ok: bool;

        if      it.A.kind == .SPHERE && it.B.kind == .SPHERE contact, ok = sphere_sphere_contact(it.A, it.B);
        else if it.A.kind == .BOX    && it.B.kind == .SPHERE contact, ok = box_sphere_contact(it.A, it.B);
        else if it.A.kind == .SPHERE && it.B.kind == .BOX    contact, ok = box_sphere_contact(it.B, it.A);
        else if it.A.kind == .BOX    && it.B.kind == .BOX    contact, ok = box_box_contact(it.A, it.B);
        
        if ok array_add(*narrowphase_contacts, contact);
    }

    return narrowphase_contacts;
}

sphere_sphere_contact :: (A: *Body, B: *Body) -> Narrowphase_Contact, bool {
    contact: Narrowphase_Contact;

    is_colliding := collision_sphere_sphere(A.position, A.sphere.radius, B.position, B.sphere.radius);
    if !is_colliding return contact, false;
    
    contact.A          = A;
    contact.B          = B;
    contact.normal     = normalize(B.position - A.position);
    contact.point_on_A = world_to_local(A, A.position + contact.normal * A.sphere.radius);
    contact.point_on_B = world_to_local(B, B.position - contact.normal * B.sphere.radius);
    contact.depth      = distance(contact.point_on_A, contact.point_on_B);

    return contact, true;
}

box_sphere_contact :: (A: *Body, B: *Body) -> Narrowphase_Contact, bool {
    contact: Narrowphase_Contact;

    obb       := OBB.{ A.position, ToMat3(A.rotation), A.box.half_size };
    is_inside := collision_point_obb(B.position, obb);
    point     := closest_point_on_obb(obb, B.position); 
    dist      := length(B.position - point);

    is_colliding := is_inside || dist <= B.sphere.radius;
    if !is_colliding return contact, false;
    
    contact.A          = A;
    contact.B          = B;
    contact.normal     = ifx is_inside then normalize(point - B.position) else normalize(B.position - point);
    contact.point_on_A = world_to_local(A, B.position - contact.normal * dist);
    contact.point_on_B = world_to_local(B, B.position - contact.normal * B.sphere.radius);
    contact.depth      = distance(contact.point_on_A, contact.point_on_B);

    return contact, true;
}

box_box_contact :: (A: *Body, B: *Body) -> Narrowphase_Contact, bool {
    contact: Narrowphase_Contact;

    world_point_on_A, world_point_on_B, is_colliding := EPA_Collision(A, B);
    if !is_colliding return contact, false;

    contact.A          = A;
    contact.B          = B;
    contact.normal     = normalize(world_point_on_B - world_point_on_A);
    contact.point_on_A = world_to_local(A, world_point_on_A);
    contact.point_on_B = world_to_local(B, world_point_on_B);
    contact.depth      = distance(contact.point_on_A, contact.point_on_B);

    return contact, true;
}

solve :: (using contact: Narrowphase_Contact) {
    world_point_on_A := local_to_world(A, point_on_A);
    world_point_on_B := local_to_world(B, point_on_B);

    ra               := world_point_on_A - get_local_center_of_mass(A);
    rb               := world_point_on_B - get_local_center_of_mass(B);

    tensor_a         := get_inv_inertia_tensor(A);
    tensor_b         := get_inv_inertia_tensor(B);

    angular_ja       := cross(tensor_a * cross(ra, normal), ra);
    angular_jb       := cross(tensor_b * cross(rb, normal), rb);
    angular_factor   := dot(angular_ja + angular_jb, normal);

    vel_a            := A.linear_velocity + cross(A.angular_velocity, ra);
    vel_b            := B.linear_velocity + cross(B.angular_velocity, rb);
    vel_ab           := vel_a - vel_b;

    elasticity       := A.elasticity * B.elasticity;
    impulse_j        := (1.0 + elasticity) * dot(vel_ab, normal) / (A.inv_mass + B.inv_mass + angular_factor);
    impulse_j_vec    := impulse_j * normal;

    apply_impulse_at_point(A, -impulse_j_vec, world_point_on_A);
    apply_impulse_at_point(B,  impulse_j_vec, world_point_on_B);

    friction         := A.friction * B.friction;
    vel_norm         := normal * dot(normal, vel_ab);
    vel_tang         := vel_ab - vel_norm;
    vel_tang_normal  := normalize(vel_tang);

    inertia_a        := cross(tensor_a * cross(ra, vel_tang_normal), ra);
    inertia_b        := cross(tensor_b * cross(rb, vel_tang_normal), rb);
    inv_inertia      := dot(inertia_a + inertia_b, vel_tang_normal);

    reduced_mass     := 1.0 / (A.inv_mass + B.inv_mass + inv_inertia);
    impulse_friction := vel_tang * reduced_mass * friction;

    apply_impulse_at_point(A, -impulse_friction, world_point_on_A);
    apply_impulse_at_point(B,  impulse_friction, world_point_on_B);

    // Move colliding objects outside of each other
    tA := A.inv_mass / (A.inv_mass + B.inv_mass);
    tB := B.inv_mass / (A.inv_mass + B.inv_mass);
    ds := world_point_on_B - world_point_on_A;

    A.position += ds * tA;
    B.position -= ds * tB;
}