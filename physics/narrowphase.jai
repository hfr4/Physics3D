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
        if it.A.kind == .SPHERE && it.B.kind == .SPHERE
        {
            contact, ok := sphere_sphere_contact(it.A, it.B);
            if ok array_add(*narrowphase_contacts, contact);
        }
        else if it.A.kind == .BOX && it.B.kind == .SPHERE
        {
            contact, ok := box_sphere_contact(it.A, it.B);
            if ok array_add(*narrowphase_contacts, contact);
        }
        else if it.A.kind == .SPHERE && it.B.kind == .BOX
        {
            contact, ok := box_sphere_contact(it.B, it.A);
            if ok array_add(*narrowphase_contacts, contact);
        }
        else if it.A.kind == .BOX && it.B.kind == .BOX
        {
            contacts, count := box_box_contacts(it.A, it.B);
            for array_view(contacts, 0, count) {
                array_add(*narrowphase_contacts, it);
            }
        } 
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

    obb       := OBB.{ A.position, ToMat3(A.rotation), A.box.extents };
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

/*
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
*/

box_box_contacts :: (A: *Body, B: *Body) -> [8] Narrowphase_Contact, int {
    contacts: [8] Narrowphase_Contact;
    count: int;

    a_obb := OBB.{ A.position, ToMat3(A.rotation), A.box.extents };
    b_obb := OBB.{ B.position, ToMat3(B.rotation), B.box.extents };

    sat_depth := FLOAT32_MAX;
    sat_normal: Vector3; // Normal from A to B
    sat_index: int;

    for axis: get_sat_axes(a_obb, b_obb) {
        a_min, a_max := get_interval(a_obb, axis);
        b_min, b_max := get_interval(b_obb, axis);

        depth := (a_max - a_min + b_max - b_min) - (max(a_max, b_max) - min(a_min, b_min));
        
        if depth < 0.0 return contacts, count;
        
        if depth < sat_depth {
            sat_depth  = depth;
            sat_normal = ifx a_min < b_min then axis else -axis; 
            sat_index  = it_index;
        }
    }

    // Plane - Plane Collision
    if sat_index < 6 {
        // Reference and Incidence only matter for a Plane - Plane collision
        reference_is_A := sat_index < 3;

        reference_obb := ifx reference_is_A then a_obb else b_obb;
        incidence_obb := ifx reference_is_A then b_obb else a_obb;

        reference_to_incidence_normal := ifx reference_is_A then  sat_normal else -sat_normal;
        incidence_to_reference_normal := ifx reference_is_A then -sat_normal else  sat_normal;

        reference_quad := get_most_aligned_quad_with_axis(reference_obb, reference_to_incidence_normal);
        incidence_quad := get_most_aligned_quad_with_axis(incidence_obb, incidence_to_reference_normal);

        reference_plane := make_plane(reference_quad);
        reference_side_planes := get_side_planes(reference_quad);

        for edge: get_edges(incidence_quad) {
            // Clip the edge against the side planes pointing toward the interior of the reference quad
            clipped := edge;
            for plane: reference_side_planes {
                clipped=, ok := clip(clipped, .{ plane.position, -plane.normal });
                if !ok continue edge;
            }

            // Create contacts only if the clipped points are behind the reference plane
            for get_points(clipped) {
                depth := dot(it - reference_plane.position, reference_plane.normal);
                if depth < 0.0 {
                    point_on_incidence := it;
                    point_on_reference := point_on_incidence + incidence_to_reference_normal * depth;

                    contact: Narrowphase_Contact;
                    contact.A          = A;
                    contact.B          = B;
                    contact.point_on_A = world_to_local(A, ifx reference_is_A then point_on_reference else point_on_incidence);
                    contact.point_on_B = world_to_local(B, ifx reference_is_A then point_on_incidence else point_on_reference);
                    contact.depth      = depth;
                    contact.normal     = sat_normal;

                    contacts[count] = contact;
                    count += 1;
                }
            }
        }
    }
    // Edge - Edge Collision
    else {
        a_edge := get_most_aligned_edge_with_axis(a_obb,  sat_normal);
        b_edge := get_most_aligned_edge_with_axis(b_obb, -sat_normal);
        a_closest, b_closest := get_closest_points(a_edge, b_edge);

        contact: Narrowphase_Contact;
        contact.A          = A;
        contact.B          = B;
        contact.point_on_A = world_to_local(A, a_closest);
        contact.point_on_B = world_to_local(B, b_closest);
        contact.depth      = sat_depth;
        contact.normal     = sat_normal;

        contacts[count] = contact;
        count += 1;
    }

    return contacts, count;
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